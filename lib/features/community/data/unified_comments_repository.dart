import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:uuid/uuid.dart';

abstract class UnifiedCommentsRepository {
  Future<List<CommunityComment>> fetchComments({
    required String entityType,
    required String entityId,
  });

  Stream<List<CommunityComment>> watchComments({
    required String entityType,
    required String entityId,
  });

  Future<CommunityComment> addComment({
    required String entityType,
    required String entityId,
    required String body,
    String? parentCommentId,
    String? sentiment,
  });

  Future<void> toggleReaction({
    required String commentId,
    String reaction = '👍',
  });

  Future<void> deleteComment(String commentId);

  CommunityAuthor getCurrentAuthor();
}

class UnifiedCommentsRepositoryImpl implements UnifiedCommentsRepository {
  UnifiedCommentsRepositoryImpl._();
  static final UnifiedCommentsRepositoryImpl instance =
      UnifiedCommentsRepositoryImpl._();

  String _resolveUserId() {
    if (SupabaseConfig.isConfigured) {
      final user = SupabaseConfig.client?.auth.currentUser;
      if (user != null && user.id.isNotEmpty) return user.id;
    }
    final stored =
        SupabaseAuthBackendService.instance.currentUserProfile?.id ??
        AuthBackendService.instance.currentUserProfile?.id;
    if (stored != null && stored.isNotEmpty) return stored;
    return '';
  }

  @override
  CommunityAuthor getCurrentAuthor() {
    final profile =
        SupabaseAuthBackendService.instance.currentUserProfile ??
        AuthBackendService.instance.currentUserProfile;
    final user = SupabaseConfig.client?.auth.currentUser;
    final uid = _resolveUserId();

    return CommunityAuthor(
      id: uid,
      handle:
          profile?.handle ??
          (user?.userMetadata?['handle'] as String?) ??
          'trader',
      displayName:
          profile?.displayName ??
          (user?.userMetadata?['display_name'] as String?) ??
          'Trader',
      userRole: profile?.role ?? UserRole.customer,
      avatarUrl:
          profile?.avatarUrl ?? (user?.userMetadata?['avatar_url'] as String?),
      verified: profile?.status == ProfileStatus.active,
      tier: AppTier.values.firstWhere(
        (t) =>
            t.name.toLowerCase() ==
            (profile?.subscriptionTier.toLowerCase() ?? 'free'),
        orElse: () => AppTier.free,
      ),
    );
  }

  @override
  Future<List<CommunityComment>> fetchComments({
    required String entityType,
    required String entityId,
  }) async {
    if (!SupabaseConfig.isConfigured) return const <CommunityComment>[];

    try {
      final client = SupabaseConfig.client;
      if (client == null) return const <CommunityComment>[];

      final currentUserId = _resolveUserId();

      final res = await client
          .from('unified_comments')
          .select('''
            id,
            entity_type,
            entity_id,
            author_id,
            parent_id,
            body,
            sentiment,
            likes_count,
            reply_count,
            is_pinned,
            created_at,
            updated_at,
            profiles!author_id (
              id,
              handle,
              display_name,
              avatar_url,
              role,
              verified,
              subscription_tier
            ),
            unified_comment_likes (
              user_id,
              reaction
            )
          ''')
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .order('created_at', ascending: true);

      final rawList = res as List<dynamic>;
      final topLevel = <CommunityComment>[];
      final repliesByParent = <String, List<CommunityComment>>{};

      for (final item in rawList) {
        final row = item as Map<String, dynamic>;
        final commentId = row['id']?.toString() ?? '';
        final parentId = row['parent_id']?.toString();
        final body = row['body'] as String? ?? '';
        final sentiment = row['sentiment'] as String?;
        final likesCount = (row['likes_count'] as num?)?.toInt() ?? 0;
        final createdAtStr = row['created_at']?.toString() ?? '';
        final createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

        final profile = row['profiles'] as Map<String, dynamic>?;
        final authorId = row['author_id']?.toString() ?? '';
        final handle = profile?['handle'] as String? ?? 'trader';
        final displayName = profile?['display_name'] as String? ?? handle;
        final avatarUrl = profile?['avatar_url'] as String?;
        final roleStr = profile?['role'] as String?;
        final userRole = switch (roleStr) {
          'user_admin' => UserRole.userAdmin,
          'affiliate' => UserRole.affiliate,
          _ => UserRole.customer,
        };

        final subTier = (profile?['subscription_tier'] as String?)?.toLowerCase().trim() ?? 'free';
        final author = CommunityAuthor(
          id: authorId,
          handle: handle,
          displayName: displayName,
          userRole: userRole,
          avatarUrl: avatarUrl,
          verified: profile?['verified'] as bool? ?? false,
          subscriptionTier: subTier,
          tier: switch (subTier) {
            'enterprise' => AppTier.enterprise,
            'pro' || 'premium' => AppTier.premium,
            _ => AppTier.free,
          },
        );

        final likesList = row['unified_comment_likes'] as List<dynamic>? ?? [];
        String? myReaction;
        final reactionsSet = <String>{};
        for (final l in likesList) {
          final likeRow = l as Map<String, dynamic>;
          final uId = likeRow['user_id']?.toString();
          final reaction = likeRow['reaction']?.toString() ?? '👍';
          reactionsSet.add(reaction);
          if (uId == currentUserId) {
            myReaction = reaction;
          }
        }

        final comment = CommunityComment(
          id: commentId,
          postId: entityId,
          author: author,
          body: body,
          createdAt: createdAt,
          likes: likesCount > 0 ? likesCount : likesList.length,
          liked: myReaction != null,
          userReaction: myReaction,
          reactions: reactionsSet.toList(),
          sentiment: sentiment,
          parentCommentId: parentId,
        );

        if (parentId == null || parentId.isEmpty) {
          topLevel.add(comment);
        } else {
          (repliesByParent[parentId] ??= <CommunityComment>[]).add(comment);
        }
      }

      // Assemble reply trees
      final assembled = topLevel.map((c) {
        final replies = repliesByParent[c.id] ?? const <CommunityComment>[];
        return c.copyWith(replies: replies);
      }).toList();

      return assembled;
    } catch (e) {
      debugPrint('[UnifiedCommentsRepository] fetchComments error: $e');
      return const <CommunityComment>[];
    }
  }

  @override
  Stream<List<CommunityComment>> watchComments({
    required String entityType,
    required String entityId,
  }) async* {
    yield await fetchComments(entityType: entityType, entityId: entityId);

    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      if (client != null) {
        final stream = client
            .from('unified_comments')
            .stream(primaryKey: ['id'])
            .eq('entity_id', entityId);

        await for (final _ in stream) {
          yield await fetchComments(entityType: entityType, entityId: entityId);
        }
      }
    }
  }

  @override
  Future<CommunityComment> addComment({
    required String entityType,
    required String entityId,
    required String body,
    String? parentCommentId,
    String? sentiment,
  }) async {
    await CustomerLimitations.assertCanCreateCommunityComment();
    final client = SupabaseConfig.client;
    final currentUserId = _resolveUserId();
    final author = getCurrentAuthor();
    final commentId = const Uuid().v4();
    final now = DateTime.now();

    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final row = <String, dynamic>{
          'id': commentId,
          'entity_type': entityType,
          'entity_id': entityId,
          'author_id': currentUserId,
          'body': body.trim(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
        if (parentCommentId != null && parentCommentId.isNotEmpty) {
          row['parent_id'] = parentCommentId;
        }
        if (sentiment != null && sentiment.isNotEmpty) {
          row['sentiment'] = sentiment.toUpperCase();
        }

        await client.from('unified_comments').insert(row);
      } catch (e) {
        debugPrint('[UnifiedCommentsRepository] addComment error: $e');
        rethrow;
      }
    }

    return CommunityComment(
      id: commentId,
      postId: entityId,
      author: author,
      body: body.trim(),
      createdAt: now,
      likes: 0,
      liked: false,
      sentiment: sentiment?.toUpperCase(),
      parentCommentId: parentCommentId,
    );
  }

  @override
  Future<void> toggleReaction({
    required String commentId,
    String reaction = '👍',
  }) async {
    final client = SupabaseConfig.client;
    final currentUserId = _resolveUserId();

    if (client != null && SupabaseConfig.isConfigured) {
      bool synced = false;
      try {
        final existing = await client
            .from('unified_comment_likes')
            .select('reaction')
            .eq('comment_id', commentId)
            .eq('user_id', currentUserId)
            .maybeSingle();

        if (existing != null) {
          final curReaction = existing['reaction']?.toString();
          if (curReaction == reaction) {
            await client
                .from('unified_comment_likes')
                .delete()
                .eq('comment_id', commentId)
                .eq('user_id', currentUserId);
          } else {
            await client
                .from('unified_comment_likes')
                .update({'reaction': reaction})
                .eq('comment_id', commentId)
                .eq('user_id', currentUserId);
          }
        } else {
          await client.from('unified_comment_likes').insert({
            'comment_id': commentId,
            'user_id': currentUserId,
            'reaction': reaction,
          });
        }
        synced = true;
      } catch (e) {
        debugPrint('[UnifiedCommentsRepository] unified_comment_likes error: $e');
      }

      if (!synced) {
        try {
          final existing = await client
              .from('community_comment_likes')
              .select('reaction')
              .eq('comment_id', commentId)
              .eq('user_id', currentUserId)
              .maybeSingle();

          if (existing != null) {
            final curReaction = existing['reaction']?.toString();
            if (curReaction == reaction) {
              await client
                  .from('community_comment_likes')
                  .delete()
                  .eq('comment_id', commentId)
                  .eq('user_id', currentUserId);
            } else {
              await client
                  .from('community_comment_likes')
                  .update({'reaction': reaction})
                  .eq('comment_id', commentId)
                  .eq('user_id', currentUserId);
            }
          } else {
            await client.from('community_comment_likes').insert({
              'comment_id': commentId,
              'user_id': currentUserId,
              'reaction': reaction,
            });
          }
        } catch (e2) {
          debugPrint('[UnifiedCommentsRepository] community_comment_likes fallback error: $e2');
        }
      }
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final client = SupabaseConfig.client;
    final currentUserId = _resolveUserId();

    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client
            .from('unified_comments')
            .delete()
            .eq('id', commentId)
            .eq('author_id', currentUserId);
      } catch (e) {
        debugPrint('[UnifiedCommentsRepository] deleteComment error: $e');
        rethrow;
      }
    }
  }
}
