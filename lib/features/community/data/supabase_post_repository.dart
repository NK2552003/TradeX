import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/config/supabase_storage_egress.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:uuid/uuid.dart';

abstract class SupabasePostRepository {
  Future<List<AppPost>> getPosts();
  Future<AppPost> createPost({
    required String content,
    String? ticker,
    String? imageUrl,
  });
  Future<void> likePost(String postId);
  Future<List<AppComment>> getComments(String postId);
  Future<void> commentPost(String postId, String commentText);
  Future<void> savePost(String postId);
  Future<void> incrementView(String postId);
  Future<void> blockUser(String userIdToBlock);
}

class SupabasePostRepositoryImpl implements SupabasePostRepository {
  SupabasePostRepositoryImpl._();

  static final SupabasePostRepositoryImpl instance =
      SupabasePostRepositoryImpl._();

  factory SupabasePostRepositoryImpl() => instance;

  final DemoDataSource _demo = DemoDataSource.instance;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  String _resolveUserId() {
    if (SupabaseConfig.isConfigured) {
      final user = SupabaseConfig.client?.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
      final profileId =
          SupabaseAuthBackendService.instance.currentUserProfile?.id;
      if (profileId != null && profileId.isNotEmpty) {
        return profileId;
      }
    }
    return '';
  }

  bool _isUuid(String? id) => id != null && _uuidRegex.hasMatch(id);

  Future<Set<String>> _fetchBlockedUserIds(
    SupabaseClient client,
    String currentUserId,
  ) async {
    final blockedIds = <String>{};
    if (currentUserId.isEmpty) return blockedIds;
    try {
      final blockedRes = await client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);
      for (final b in (blockedRes as List)) {
        final id = b['blocked_id']?.toString();
        if (id != null && id.isNotEmpty && id != currentUserId) {
          blockedIds.add(id);
        }
      }
    } catch (e) {
      debugPrint('[SupabasePostRepository] Failed to fetch blocked user IDs: ');
    }
    return blockedIds;
  }

  @override
  Future<List<AppPost>> getPosts() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final currentUserId = _resolveUserId();

        final blockedIds = await _fetchBlockedUserIds(client, currentUserId);

        final res = await client
            .from('community_posts')
            .select(
              '*, profiles!community_posts_author_id_fkey(handle, display_name, avatar_url), community_post_attachments(*)',
            )
            .or('is_public.eq.true,author_id.eq.$currentUserId')
            .order('created_at', ascending: false);

        final filtered = (res as List).where((row) {
          final authorId = row['author_id']?.toString();
          if (blockedIds.contains(authorId)) return false;
          final moderationStatus =
              row['moderation_status']?.toString().toLowerCase() ?? 'approved';
          if (moderationStatus == 'rejected' && authorId != currentUserId) {
            return false;
          }
          return true;
        }).toList();

        return filtered.map((row) {
          final profile = row['profiles'] as Map<String, dynamic>?;
          final handle =
              (profile?['handle'] ?? profile?['username']) as String? ??
              'trader';
          final name = profile?['display_name'] as String? ?? handle;

          final tickersList = row['tickers'] as List?;
          final List<String> tickers = tickersList != null
              ? tickersList.map((e) => e.toString()).toList()
              : const <String>[];

          final attachments = row['community_post_attachments'] as List?;
          String? postImageUrl;
          if (attachments != null) {
            for (final a in attachments) {
              final att = a as Map<String, dynamic>;
              if (att['kind'] == 'image') {
                final rawImg =
                    att['url']?.toString() ?? att['ref_id']?.toString();
                if (rawImg != null && rawImg.isNotEmpty) {
                  try {
                    postImageUrl = SupabaseStorageEgress.resolvePublicCdnUrl(
                      client: client,
                      bucket:
                          SupabaseStorageEgress.communityAttachments.bucketId,
                      ref: rawImg,
                    );
                  } catch (_) {
                    postImageUrl = rawImg;
                  }
                }
                break;
              }
            }
          }

          final rawAvatarUrl = profile?['avatar_url'] as String?;
          final resolvedAvatarUrl =
              rawAvatarUrl != null && rawAvatarUrl.isNotEmpty
              ? SupabaseStorageEgress.resolvePublicCdnUrl(
                  client: client,
                  bucket: SupabaseStorageEgress.avatars.bucketId,
                  ref: rawAvatarUrl,
                )
              : null;

          return AppPost(
            id: row['id']?.toString() ?? '',
            author: AppTrader(
              id: row['author_id']?.toString() ?? 'usr_trader',
              handle: handle,
              displayName: name,
              avatarUrl: resolvedAvatarUrl,
            ),
            body: row['body'] as String? ?? '',
            createdAt: row['created_at'] != null
                ? DateTime.tryParse(row['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now(),
            likes: (row['likes_count'] as num?)?.toInt() ?? 0,
            comments: (row['comments_count'] as num?)?.toInt() ?? 0,
            tickers: tickers,
            imageUrl: postImageUrl,
            moderationStatus:
                row['moderation_status']?.toString() ?? 'approved',
          );
        }).toList();
      } catch (e) {
        debugPrint('[SupabasePostRepository] getPosts error: $e');
      }
    }
    if (CustomerDataPolicy.allowDemo) {
      return _demo.posts();
    }
    return const <AppPost>[];
  }

  @override
  Future<AppPost> createPost({
    required String content,
    String? ticker,
    String? imageUrl,
  }) async {
    await CustomerLimitations.assertCanCreateCommunityPost();
    final now = DateTime.now();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        final postId = const Uuid().v4();

        final row = {
          'id': postId,
          'author_id': userId,
          'title': '',
          'body': content,
          'tickers': ticker != null ? [ticker] : <String>[],
          'tags': <String>[],
          'is_public': true,
          'visibility': 'public',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        dynamic res;
        try {
          res = await client
              .from('community_posts')
              .insert({...row, 'moderation_status': 'approved'})
              .select(
                '*, profiles!community_posts_author_id_fkey(handle, display_name, avatar_url)',
              )
              .single();
        } catch (_) {
          res = await client
              .from('community_posts')
              .insert(row)
              .select(
                '*, profiles!community_posts_author_id_fkey(handle, display_name, avatar_url)',
              )
              .single();
        }

        if (imageUrl != null && imageUrl.isNotEmpty) {
          await client.from('community_post_attachments').insert({
            'post_id': postId,
            'kind': 'image',
            'ref_id': imageUrl,
            'title': 'Chart Image',
            'url': imageUrl,
          });
        }

        final profile = res['profiles'] as Map<String, dynamic>?;
        final handle =
            (profile?['handle'] ?? profile?['username']) as String? ?? 'trader';
        final name = profile?['display_name'] as String? ?? handle;

        return AppPost(
          id: res['id']?.toString() ?? postId,
          author: AppTrader(
            id: userId,
            handle: handle,
            displayName: name,
            avatarUrl: profile?['avatar_url'] as String?,
          ),
          body: res['body'] as String? ?? content,
          createdAt: now,
          likes: 0,
          comments: 0,
          tickers: ticker != null ? [ticker] : const [],
          imageUrl: imageUrl,
          moderationStatus: res['moderation_status']?.toString() ?? 'approved',
        );
      } catch (e) {
        debugPrint('[SupabasePostRepository] createPost error: $e');
        rethrow;
      }
    }

    final currentProf = SupabaseAuthBackendService.instance.currentUserProfile;
    final handle = currentProf?.handle ?? '@trader';
    final name = currentProf?.displayName ?? 'Trader';

    return AppPost(
      id: 'pst_${now.millisecondsSinceEpoch}',
      author: AppTrader(
        id: currentProf?.id ?? 'usr_me',
        handle: handle,
        displayName: name,
        avatarUrl: currentProf?.avatarUrl,
      ),
      body: content,
      createdAt: now,
      likes: 0,
      comments: 0,
      tickers: ticker != null ? [ticker] : const [],
      imageUrl: imageUrl,
    );
  }

  @override
  Future<void> likePost(String postId) async {
    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        final existing = await client
            .from('community_likes')
            .select('post_id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();

        if (existing != null) {
          await client
              .from('community_likes')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', userId);
        } else {
          await client.from('community_likes').insert({
            'user_id': userId,
            'post_id': postId,
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] likePost error: $e');
      }
    }
  }

  @override
  Future<void> commentPost(String postId, String commentText) async {
    await CustomerLimitations.assertCanCreateCommunityComment();
    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        try {
          await client.from('community_comments').insert({
            'id': const Uuid().v4(),
            'post_id': postId,
            'author_id': userId,
            'body': commentText.trim(),
            'moderation_status': 'approved',
          });
        } catch (_) {
          await client.from('community_comments').insert({
            'id': const Uuid().v4(),
            'post_id': postId,
            'author_id': userId,
            'body': commentText.trim(),
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] commentPost error: $e');
        rethrow;
      }
    }
  }

  @override
  Future<List<AppComment>> getComments(String postId) async {
    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final currentUserId = _resolveUserId();
        final blockedIds = await _fetchBlockedUserIds(client, currentUserId);

        final res = await client
            .from('community_comments')
            .select(
              '*, profiles!community_comments_author_id_fkey(handle, display_name, avatar_url)',
            )
            .eq('post_id', postId)
            .order('created_at', ascending: true);

        final filtered = (res as List)
            .where((row) => !blockedIds.contains(row['author_id']?.toString()))
            .toList();

        return filtered.map((row) {
          final profile = row['profiles'] as Map<String, dynamic>?;
          final handle =
              (profile?['handle'] ?? profile?['username']) as String? ??
              'trader';
          final name = profile?['display_name'] as String? ?? handle;

          return AppComment(
            id: row['id']?.toString() ?? '',
            author: AppTrader(
              id: row['author_id']?.toString() ?? 'usr_trader',
              handle: handle,
              displayName: name,
              avatarUrl: profile?['avatar_url'] as String?,
            ),
            body: row['body'] as String? ?? '',
            createdAt: row['created_at'] != null
                ? DateTime.tryParse(row['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now(),
            likes: (row['likes_count'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      } catch (e) {
        debugPrint('[SupabasePostRepository] getComments error: $e');
      }
    }
    return CustomerDataPolicy.allowDemo
        ? _demo.comments(postId)
        : const <AppComment>[];
  }

  @override
  Future<void> savePost(String postId) async {
    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        final existing = await client
            .from('community_bookmarks')
            .select('post_id')
            .eq('post_id', postId)
            .eq('user_id', userId)
            .maybeSingle();

        if (existing != null) {
          await client
              .from('community_bookmarks')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', userId);
        } else {
          await client.from('community_bookmarks').insert({
            'user_id': userId,
            'post_id': postId,
          });
        }
      } catch (e) {
        debugPrint('[SupabasePostRepository] savePost error: $e');
      }
    }
  }

  @override
  Future<void> incrementView(String postId) async {
    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc('increment_post_views', params: {'p_post_id': postId});
      } catch (e) {
        debugPrint('[SupabasePostRepository] incrementView error: $e');
      }
    }
  }

  @override
  Future<void> blockUser(String userIdToBlock) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        await client.from('blocks').upsert({
          'blocker_id': userId,
          'blocked_id': userIdToBlock,
        });
      } catch (e) {
        debugPrint('[SupabasePostRepository] blockUser error: $e');
      }
    }
  }
}
