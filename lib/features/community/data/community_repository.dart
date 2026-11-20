import 'package:alphajournal/core/config/record_access.dart';
import 'package:alphajournal/core/data/owned_record_writer.dart';
import 'community_post_writer.dart';
import '../models/community_activity.dart';
import 'workspace_attachment_service.dart';
import 'package:alphajournal/features/workspace/data/workspace_post_service.dart';
import 'package:alphajournal/core/config/customer_data_policy.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
import 'package:alphajournal/core/config/supabase_storage_egress.dart';
import 'package:alphajournal/core/data/demo_data_source.dart';
import 'package:alphajournal/core/utils/app_visibility.dart';
import 'package:alphajournal/features/auth/data/services/auth_backend_service.dart';
import 'package:alphajournal/features/auth/data/services/supabase_auth_backend_service.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/linking/entity_ticker_links_repository.dart';
import 'package:alphajournal/core/utils/attachment_compression_service.dart';
import 'package:uuid/uuid.dart';

part 'community_activity_repository.dart';

/// Reactive repository backing the community platform with live Supabase sync
/// and offline resilience.
class CommunityRepository extends ChangeNotifier {
  CommunityRepository() {
    _initSeedData();
    if (SupabaseConfig.isConfigured) {
      unawaited(init());
    }
  }

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final Map<String, List<CommunityReaction>> _networkReactions = {};
  late final Map<String, List<CommunityAuthor>> _networkReposts = {};
  int _networkRequest = 0;
  Future<List<CommunityReaction>> fetchReactions(
    String targetId, {
    bool comment = false,
  }) => _fetchReactions(targetId, comment: comment);
  static const int _postsPageSize = 30;
  static const Duration _realtimeDebounce = Duration(seconds: 5);

  bool _initialized = false;
  bool _subscribedToRealtime = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoadedFollows = false;
  String _followLoadedForUserId = '';
  bool _pendingFollowRefresh = false;
  final Set<String> _pendingFollowWrites = <String>{};
  final Set<String> _loadedAuthorPostIds = <String>{};
  final Map<String, Future<void>> _authorPostLoads = <String, Future<void>>{};
  bool _hasMorePosts = true;
  int _loadedPostRows = 0;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounceTimer;
  bool _pendingRealtimeRefresh = false;
  DateTime? _suppressRealtimeUntil;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasLoadedFollows => _hasLoadedFollows;
  bool get hasMorePosts => _hasMorePosts;
  RealtimeChannel? get realtimeChannel => _realtimeChannel;

  /// Suppresses self-triggered realtime refetches briefly after local mutations.
  void suppressRealtimeEcho([Duration duration = const Duration(seconds: 3)]) {
    _suppressRealtimeUntil = DateTime.now().add(duration);
  }

  String _resolveUserId() {
    if (SupabaseConfig.isConfigured) {
      final user = SupabaseConfig.client?.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
      final sessionUser = SupabaseConfig.client?.auth.currentSession?.user;
      if (sessionUser != null && sessionUser.id.isNotEmpty) {
        return sessionUser.id;
      }
    }
    final stored =
        SupabaseAuthBackendService.instance.currentUserProfile?.id ??
        AuthBackendService.instance.currentUserProfile?.id;
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }
    return '';
  }

  bool _isUuid(String? id) => id != null && _uuidRegex.hasMatch(id);

  static const String _commentReactionsPrefsPrefix = 'alphajournal_comment_rx_';

  Future<Map<String, String>> _loadLocalCommentReactions(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveId = userId.trim().isEmpty ? 'guest' : userId.trim();
      final raw = prefs.getString('$_commentReactionsPrefsPrefix$effectiveId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _saveLocalCommentReaction(
    String userId,
    String commentId,
    String? reaction,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final effectiveId = userId.trim().isEmpty ? 'guest' : userId.trim();
      final key = '$_commentReactionsPrefsPrefix$effectiveId';
      final current = await _loadLocalCommentReactions(effectiveId);
      if (reaction != null && reaction.isNotEmpty) {
        current[commentId] = reaction;
      } else {
        current.remove(commentId);
      }
      await prefs.setString(key, jsonEncode(current));
    } catch (_) {}
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (SupabaseConfig.isConfigured) {
      _initRealtime();
      await fetchFromSupabase();
    }
  }

  void _onVisibilityChanged(bool isVisible) {
    if (_disposed || !isVisible) return;
    if (_pendingRealtimeRefresh) {
      _pendingRealtimeRefresh = false;
      _scheduleRealtimeRefresh();
    }
  }

  void _scheduleRealtimeRefresh() {
    if (_disposed) return;
    final suppressedUntil = _suppressRealtimeUntil;
    if (suppressedUntil != null && DateTime.now().isBefore(suppressedUntil)) {
      return;
    }
    if (!AppVisibility.instance.isVisible) {
      _pendingRealtimeRefresh = true;
      return;
    }
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(_realtimeDebounce, () {
      if (_disposed) return;
      if (!AppVisibility.instance.isVisible) {
        _pendingRealtimeRefresh = true;
        return;
      }
      unawaited(fetchFromSupabase());
    });
  }

  void _initRealtime() {
    if (_subscribedToRealtime || !SupabaseConfig.isConfigured) return;
    _subscribedToRealtime = true;
    AppVisibility.instance.addListener(_onVisibilityChanged);

    try {
      final client = SupabaseConfig.client!;
      _realtimeChannel =
          client
              .channel('public:community_posts_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'community_posts',
                callback: (_) => _scheduleRealtimeRefresh(),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'community_comments',
                callback: (_) => _scheduleRealtimeRefresh(),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'community_post_attachments',
                callback: (_) => _scheduleRealtimeRefresh(),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'community_likes',
                callback: (_) => _scheduleRealtimeRefresh(),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'community_reposts',
                callback: (_) => _scheduleRealtimeRefresh(),
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'community_follows',
                callback: (_) => _scheduleRealtimeRefresh(),
              )
            ..subscribe();
    } catch (e) {
      debugPrint('[CommunityRepository] Realtime subscription error: $e');
    }
  }

  String? refreshError;

  static const String _postSelectColumns =
      'id, author_id, body, created_at, is_pinned, is_public, tickers, tags, '
      'likes_count, comments_count, reposts_count, views_count, moderation_status, '
      'profiles!community_posts_author_id_fkey(id, handle, display_name, avatar_url, bio, role, experience_level, trading_style, location, website, avg_hold_duration, primary_market, top_strategy, risk_mantra, verified, win_rate, followers_count, following_count, posts_count, subscription_tier), '
      'community_post_trade_setups(ticker, side, entry, stop_loss, target1), '
      'community_post_attachments(kind, url, title, ref_id), '
      'community_polls(id, question, expires_at, community_poll_options(id, option_text, votes_count))';

  Future<
    ({
      List<CommunityPost> posts,
      Map<String, List<CommunityComment>> comments,
      int rawRowCount,
    })
  >
  _fetchPostsPage({
    required SupabaseClient client,
    required String targetUserId,
    required int offset,
    required int limit,
    String? authorId,
    List<String>? postIds,
  }) async {
    final scopedAuthorId = authorId?.trim() ?? '';
    final dynamic res;
    if (postIds != null && postIds.isNotEmpty) {
      res = await client
          .from('community_posts')
          .select(_postSelectColumns)
          .inFilter('id', postIds)
          .or('is_public.eq.true,author_id.eq.$targetUserId')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } else if (scopedAuthorId.isEmpty) {
      res = await client
          .from('community_posts')
          .select(_postSelectColumns)
          .or('is_public.eq.true,author_id.eq.$targetUserId')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } else if (scopedAuthorId == targetUserId) {
      res = await client
          .from('community_posts')
          .select(_postSelectColumns)
          .eq('author_id', scopedAuthorId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } else {
      res = await client
          .from('community_posts')
          .select(_postSelectColumns)
          .eq('author_id', scopedAuthorId)
          .eq('is_public', true)
          .eq('moderation_status', 'approved')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    }

    final rawRows = (res as List).whereType<Map<String, dynamic>>().toList();
    final pagePostIds = <String>[];
    final pagePollIds = <String>[];

    for (final row in rawRows) {
      final pid = row['id']?.toString() ?? '';
      if (pid.isNotEmpty) pagePostIds.add(pid);
      final rawPoll = row['community_polls'];
      if (rawPoll is Map<String, dynamic>) {
        final pollId = rawPoll['id']?.toString() ?? '';
        if (pollId.isNotEmpty) pagePollIds.add(pollId);
      } else if (rawPoll is List) {
        for (final p in rawPoll.whereType<Map<String, dynamic>>()) {
          final pollId = p['id']?.toString() ?? '';
          if (pollId.isNotEmpty) pagePollIds.add(pollId);
        }
      }
    }

    final Set<String> likedPostIds = <String>{};
    final Map<String, String> userPostReactions = <String, String>{};
    final Map<String, Set<String>> allPostReactions = <String, Set<String>>{};
    final Set<String> bookmarkedPostIds = <String>{};
    final Set<String> repostedPostIds = <String>{};
    final Map<String, String> userPollVotes = <String, String>{};

    if (pagePostIds.isNotEmpty) {
      try {
        List likesRes = const [];
        try {
          likesRes = await client
              .from('community_likes')
              .select('post_id, user_id, reaction')
              .inFilter('post_id', pagePostIds);
        } catch (_) {
          likesRes = await client
              .from('community_likes')
              .select('post_id, user_id')
              .inFilter('post_id', pagePostIds);
        }
        for (final item in likesRes) {
          final id = item['post_id']?.toString();
          final uid = item['user_id']?.toString();
          final rx = item['reaction']?.toString().trim() ?? '👍';
          if (id == null || id.isEmpty) continue;
          if (rx.isNotEmpty) {
            (allPostReactions[id] ??= <String>{}).add(rx);
          }
          if (uid == targetUserId) {
            likedPostIds.add(id);
            userPostReactions[id] = rx.isNotEmpty ? rx : '👍';
          }
        }
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching scoped likes: $e');
      }

      if (targetUserId.isNotEmpty) {
        try {
          final bookmarksRes = await client
              .from('community_bookmarks')
              .select('post_id')
              .eq('user_id', targetUserId)
              .inFilter('post_id', pagePostIds);
          for (final item in bookmarksRes as List) {
            final id = item['post_id']?.toString();
            if (id != null) bookmarkedPostIds.add(id);
          }
        } catch (e) {
          debugPrint('[CommunityRepository] Error fetching bookmarks: $e');
        }

        try {
          final repostsRes = await client
              .from('community_reposts')
              .select('post_id')
              .eq('user_id', targetUserId)
              .inFilter('post_id', pagePostIds);
          for (final item in repostsRes as List) {
            final id = item['post_id']?.toString();
            if (id != null) repostedPostIds.add(id);
          }
        } catch (e) {
          debugPrint('[CommunityRepository] Error fetching reposts: $e');
        }
      }
    }

    if (pagePollIds.isNotEmpty && targetUserId.isNotEmpty) {
      try {
        final votesRes = await client
            .from('community_poll_votes')
            .select('poll_id, option_id')
            .eq('user_id', targetUserId)
            .inFilter('poll_id', pagePollIds);
        for (final item in votesRes as List) {
          final pId = item['poll_id']?.toString();
          final oId = item['option_id']?.toString();
          if (pId != null && oId != null) userPollVotes[pId] = oId;
        }
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching poll votes: $e');
      }
    }

    final List<CommunityPost> posts = [];
    final Map<String, String> quotedPostIdsByPostId = <String, String>{};
    for (final row in rawRows) {
      final postId = row['id']?.toString() ?? '';
      final authorProfile = row['profiles'] as Map<String, dynamic>?;
      final authorId = row['author_id']?.toString() ?? '';
      if (_blockedUsers.contains(authorId)) {
        continue;
      }

      final moderationStatus =
          row['moderation_status']?.toString().toLowerCase() ?? 'approved';
      if (moderationStatus == 'rejected' && authorId != targetUserId) {
        continue;
      }

      final author = mapProfileToCommunityAuthor(
        authorId: authorId,
        authorProfile: authorProfile,
        isFollowing: _followedAuthorIds.contains(authorId),
      );

      CommunityTradeSetup? setup;
      final rawSetups = row['community_post_trade_setups'];
      Map<String, dynamic>? s;
      if (rawSetups is Map<String, dynamic>) {
        s = rawSetups;
      } else if (rawSetups is List && rawSetups.isNotEmpty) {
        s = rawSetups.first as Map<String, dynamic>;
      }
      if (s != null) {
        setup = CommunityTradeSetup(
          ticker: s['ticker'] as String? ?? '',
          side: (s['side']?.toString().toUpperCase() == 'SHORT')
              ? 'SHORT'
              : 'LONG',
          entry: s['entry']?.toString() ?? '0.0',
          stopLoss: s['stop_loss']?.toString(),
          target: s['target1']?.toString(),
        );
      }

      final List<String> imageUrls = <String>[];
      AppWritingPostAttachment? attachment;
      final attachmentsList = row['community_post_attachments'];
      if (attachmentsList != null && attachmentsList is List) {
        for (final attItem in attachmentsList) {
          final attMap = attItem as Map<String, dynamic>;
          final kind = attMap['kind']?.toString() ?? '';
          final url = attMap['url']?.toString();
          final title = attMap['title']?.toString() ?? '';
          final refId = attMap['ref_id']?.toString() ?? '';

          if (kind == 'image') {
            var img = url ?? refId;
            if (img.isNotEmpty) {
              if (SupabaseConfig.isConfigured) {
                try {
                  img = SupabaseStorageEgress.resolvePublicCdnUrl(
                    client: client,
                    bucket: SupabaseStorageEgress.communityAttachments.bucketId,
                    ref: img,
                  );
                } catch (_) {}
              }
              if (!imageUrls.contains(img)) {
                imageUrls.add(img);
              }
            }
          } else if (kind == 'note' ||
              kind == 'journal' ||
              kind == 'strategy' ||
              kind == 'manual' ||
              kind == 'document') {
            final linkKind = AppLinkKind.fromHost(kind) ?? AppLinkKind.note;
            attachment = AppWritingPostAttachment.manual(
              source: AppLinkRef(
                kind: linkKind,
                id: refId,
                title: title,
                subtitle: url,
              ),
              excerpt: title,
            );
          } else if (kind == 'chart_candles' && url != null) {
            try {
              final decoded = jsonDecode(url);
              if (decoded is List) {
                final candles = <UiCandle>[];
                for (final item in decoded) {
                  if (item is Map) {
                    final time = DateTime.tryParse('${item['time']}');
                    if (time != null) {
                      candles.add(
                        UiCandle(
                          time: time,
                          open: (item['open'] as num?)?.toDouble() ?? 0.0,
                          high: (item['high'] as num?)?.toDouble() ?? 0.0,
                          low: (item['low'] as num?)?.toDouble() ?? 0.0,
                          close: (item['close'] as num?)?.toDouble() ?? 0.0,
                          volume: (item['volume'] as num?)?.toDouble() ?? 0.0,
                        ),
                      );
                    }
                  }
                }
                if (candles.isNotEmpty && setup != null) {
                  setup = setup.copyWith(
                    candles: candles,
                    candlesFromImage:
                        title == 'Image-derived candles (approximate)',
                  );
                }
              }
            } catch (_) {}
          }
        }
      }

      CommunityPoll? poll;
      final rawPoll = row['community_polls'];
      if (rawPoll != null) {
        final pMap = (rawPoll is List && rawPoll.isNotEmpty)
            ? rawPoll.first as Map<String, dynamic>
            : (rawPoll is Map<String, dynamic> ? rawPoll : null);
        if (pMap != null) {
          final pollId = pMap['id']?.toString() ?? '';
          final rawOptions =
              pMap['community_poll_options'] as List? ?? const [];
          final options = <CommunityPollOption>[];
          int? userVotedIndex;
          final userVotedOptionId = userPollVotes[pollId];
          for (int i = 0; i < rawOptions.length; i++) {
            final opt = rawOptions[i] as Map<String, dynamic>;
            final optId = opt['id']?.toString() ?? '';
            final text = opt['option_text']?.toString() ?? '';
            final votes = (opt['votes_count'] as num?)?.toInt() ?? 0;
            if (userVotedOptionId == optId) {
              userVotedIndex = i;
            }
            options.add(
              CommunityPollOption(id: optId, text: text, votes: votes),
            );
          }
          poll = CommunityPoll(
            id: pollId,
            question: pMap['question'] as String? ?? '',
            options: options,
            expiresAt: DateTime.tryParse(pMap['expires_at']?.toString() ?? ''),
            votedOptionIndex: userVotedIndex,
            votedOptionIndices: userVotedIndex != null
                ? [userVotedIndex]
                : const [],
          );
        }
      }

      final ({String body, String? quotedId, String? videoUrl}) parsedBody =
          _extractQuotedPostRef(row['body'] as String? ?? '');
      if (parsedBody.quotedId != null && parsedBody.quotedId!.isNotEmpty) {
        quotedPostIdsByPostId[postId] = parsedBody.quotedId!;
      }

      posts.add(
        CommunityPost(
          id: postId,
          author: author,
          body: parsedBody.body,
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
          isPinned: row['is_pinned'] as bool? ?? false,
          isPublic: row['is_public'] as bool? ?? false,
          tickers:
              (row['tickers'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          tags:
              (row['tags'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          tradeSetup: setup,
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
          imageUrls: imageUrls,
          videoUrl: parsedBody.videoUrl,
          attachment: attachment,
          poll: poll,
          likes: (row['likes_count'] as num?)?.toInt() ?? 0,
          comments: (row['comments_count'] as num?)?.toInt() ?? 0,
          reposts: (row['reposts_count'] as num?)?.toInt() ?? 0,
          views: (row['views_count'] as num?)?.toInt() ?? 0,
          liked: likedPostIds.contains(postId),
          userReaction: userPostReactions[postId],
          reactions: (allPostReactions[postId] ?? <String>{}).toList(),
          reposted: repostedPostIds.contains(postId),
          bookmarked: bookmarkedPostIds.contains(postId),
          moderationStatus: row['moderation_status']?.toString() ?? 'approved',
        ),
      );
    }

    if (quotedPostIdsByPostId.isNotEmpty) {
      final Map<String, CommunityPost> resolvedQuoted = <String, CommunityPost>{
        for (final p in posts) p.id: p,
      };
      final Set<String> missingIds = <String>{};
      for (final String qId in quotedPostIdsByPostId.values) {
        if (resolvedQuoted.containsKey(qId)) continue;
        final CommunityPost? cached = findPost(qId);
        if (cached != null) {
          resolvedQuoted[qId] = cached;
        } else if (_isUuid(qId)) {
          missingIds.add(qId);
        }
      }
      if (missingIds.isNotEmpty) {
        final Map<String, CommunityPost> fetched =
            await _fetchMinimalQuotedPosts(client, missingIds);
        resolvedQuoted.addAll(fetched);
      }
      for (int i = 0; i < posts.length; i++) {
        final String? qId = quotedPostIdsByPostId[posts[i].id];
        if (qId == null) continue;
        final CommunityPost? qPost = resolvedQuoted[qId];
        if (qPost != null) {
          posts[i] = posts[i].copyWith(quoted: qPost);
        }
      }
    }

    final Map<String, List<CommunityComment>> pageComments = {};
    if (pagePostIds.isNotEmpty) {
      try {
        final commentsRes = await client
            .from('community_comments')
            .select(
              'id, post_id, author_id, parent_id, body, created_at, likes_count, '
              'profiles!community_comments_author_id_fkey(id, handle, display_name, avatar_url, bio, role, verified)',
            )
            .inFilter('post_id', pagePostIds)
            .order('created_at', ascending: true)
            .limit(300);

        final commentRows = (commentsRes as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        final commentIds = commentRows
            .map((r) => r['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        final Map<String, String> userCommentLikes = {};
        final Map<String, Set<String>> commentReactions = {};
        if (targetUserId.isNotEmpty) {
          userCommentLikes.addAll(
            await _loadLocalCommentReactions(targetUserId),
          );
        }

        if (commentIds.isNotEmpty) {
          try {
            final allReactions = await client
                .from('community_comment_likes')
                .select('comment_id, user_id, reaction')
                .inFilter('comment_id', commentIds);
            if (targetUserId.isNotEmpty) {
              userCommentLikes.clear();
            }
            for (final r in allReactions as List) {
              final cid = r['comment_id']?.toString();
              final uid = r['user_id']?.toString();
              final rx = r['reaction']?.toString().trim() ?? '👍';
              if (cid == null || cid.isEmpty) continue;
              if (rx.isNotEmpty) {
                (commentReactions[cid] ??= <String>{}).add(rx);
              }
              if (targetUserId.isNotEmpty && uid == targetUserId) {
                userCommentLikes[cid] = rx.isNotEmpty ? rx : '👍';
              }
            }
          } catch (_) {
            try {
              final allReactions = await client
                  .from('unified_comment_likes')
                  .select('comment_id, user_id, reaction')
                  .inFilter('comment_id', commentIds);
              for (final r in allReactions as List) {
                final cid = r['comment_id']?.toString();
                final uid = r['user_id']?.toString();
                final rx = r['reaction']?.toString().trim() ?? '👍';
                if (cid == null || cid.isEmpty) continue;
                if (rx.isNotEmpty) {
                  (commentReactions[cid] ??= <String>{}).add(rx);
                }
                if (targetUserId.isNotEmpty && uid == targetUserId) {
                  userCommentLikes[cid] = rx.isNotEmpty ? rx : '👍';
                }
              }
            } catch (_) {}
          }
        }

        final Map<String, List<CommunityComment>> grouped = {};
        for (final row in commentRows) {
          final postId = row['post_id']?.toString();
          if (postId == null) continue;
          final commentAuthorId = row['author_id']?.toString() ?? '';
          if (_blockedUsers.contains(commentAuthorId)) continue;

          final profile = row['profiles'] as Map<String, dynamic>?;
          final commentAuthor = CommunityAuthor(
            id: commentAuthorId,
            handle:
                (profile?['handle'] ?? profile?['username']) as String? ??
                'trader',
            displayName:
                profile?['display_name'] as String? ??
                profile?['handle'] as String? ??
                'Trader',
            userRole: _parseUserRole(profile?['role'] as String?),
            avatarUrl: _resolveAvatarUrl(profile?['avatar_url'] as String?),
            bio: profile?['bio'] as String?,
            verified: profile?['verified'] as bool? ?? false,
          );

          final commentId = row['id']?.toString() ?? '';
          final userRx = userCommentLikes[commentId];
          final isLiked = userRx != null;
          final rxSet = commentReactions[commentId] ?? <String>{};
          if (userRx != null) {
            rxSet.add(userRx);
          }
          final serverLikes = (row['likes_count'] as num?)?.toInt() ?? 0;
          final effectiveLikes = isLiked && serverLikes == 0 ? 1 : serverLikes;

          (grouped[postId] ??= <CommunityComment>[]).add(
            CommunityComment(
              id: commentId,
              postId: postId,
              author: commentAuthor,
              body: row['body'] as String? ?? '',
              createdAt:
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
              likes: effectiveLikes,
              liked: isLiked,
              userReaction: userRx,
              reactions: rxSet.toList(),
              parentCommentId: row['parent_id']?.toString(),
            ),
          );
        }
        grouped.forEach((id, comments) {
          pageComments[id] = buildCommunityCommentTree(comments);
        });
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching scoped comments: $e');
      }
    }

    return (posts: posts, comments: pageComments, rawRowCount: rawRows.length);
  }

  Future<List<CommunityPost>?> _fetchBookmarkedPosts(
    SupabaseClient client,
    String targetUserId,
  ) async {
    if (targetUserId.isEmpty) return const <CommunityPost>[];
    try {
      final dynamic response = await client
          .from('community_bookmarks')
          .select('post_id')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(200);
      final List<String> ids = (response as List)
          .map((dynamic row) => row['post_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (ids.isEmpty) return const <CommunityPost>[];

      final List<CommunityPost> posts = <CommunityPost>[];
      for (int start = 0; start < ids.length; start += _postsPageSize) {
        final List<String> chunk = ids.sublist(
          start,
          math.min(start + _postsPageSize, ids.length),
        );
        final page = await _fetchPostsPage(
          client: client,
          targetUserId: targetUserId,
          offset: 0,
          limit: chunk.length,
          postIds: chunk,
        );
        posts.addAll(page.posts.where((CommunityPost post) => post.bookmarked));
      }
      return posts;
    } catch (error) {
      debugPrint('[CommunityRepository] Error fetching saved posts: $error');
      return null;
    }
  }

  static final RegExp _quotedPostRefPattern = RegExp(
    r'(?:\r?\n)*Quoted post:\s*/community\?post=([^\s]+)\s*$',
    caseSensitive: false,
  );
  static final RegExp _videoRefPattern = RegExp(
    r'(?:\r?\n)*Video:\s*(https?://[^\s]+)\s*$',
    caseSensitive: false,
  );

  static ({String body, String? quotedId, String? videoUrl})
  _extractQuotedPostRef(String rawBody) {
    String clean = rawBody;
    String? quotedId;
    String? videoUrl;

    final Match? qMatch = _quotedPostRefPattern.firstMatch(clean);
    if (qMatch != null) {
      final String rawId = qMatch.group(1)?.trim() ?? '';
      String decodedId = rawId;
      try {
        decodedId = Uri.decodeQueryComponent(rawId);
      } catch (_) {}
      if (decodedId.isNotEmpty) quotedId = decodedId;
      clean = clean.substring(0, qMatch.start).trimRight();
    }

    final Match? vMatch = _videoRefPattern.firstMatch(clean);
    if (vMatch != null) {
      final String url = vMatch.group(1)?.trim() ?? '';
      if (url.isNotEmpty) videoUrl = url;
      clean = clean.substring(0, vMatch.start).trimRight();
    }

    return (body: clean, quotedId: quotedId, videoUrl: videoUrl);
  }

  Future<Map<String, CommunityPost>> _fetchMinimalQuotedPosts(
    SupabaseClient client,
    Set<String> ids,
  ) async {
    final List<String> validIds = ids.where(_isUuid).toList(growable: false);
    if (validIds.isEmpty) return const <String, CommunityPost>{};
    try {
      final res = await client
          .from('community_posts')
          .select(
            'id, author_id, body, tickers, tags, is_public, created_at, '
            'likes_count, comments_count, reposts_count, views_count, moderation_status, '
            'profiles!community_posts_author_id_fkey(id, handle, display_name, avatar_url, bio, role, verified)',
          )
          .inFilter('id', validIds);
      final Map<String, CommunityPost> result = <String, CommunityPost>{};
      for (final dynamic item in (res as List)) {
        if (item is! Map<String, dynamic>) continue;
        final String id = item['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final String authorId = item['author_id']?.toString() ?? '';
        final author = mapProfileToCommunityAuthor(
          authorId: authorId,
          authorProfile: item['profiles'] as Map<String, dynamic>?,
          isFollowing: _followedAuthorIds.contains(authorId),
        );
        final ({String body, String? quotedId, String? videoUrl}) cleaned =
            _extractQuotedPostRef(item['body'] as String? ?? '');
        result[id] = CommunityPost(
          id: id,
          author: author,
          body: cleaned.body,
          createdAt:
              DateTime.tryParse(item['created_at']?.toString() ?? '') ??
              DateTime.now(),
          isPublic: item['is_public'] as bool? ?? true,
          tickers:
              (item['tickers'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          tags:
              (item['tags'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          videoUrl: cleaned.videoUrl,
          likes: (item['likes_count'] as num?)?.toInt() ?? 0,
          comments: (item['comments_count'] as num?)?.toInt() ?? 0,
          reposts: (item['reposts_count'] as num?)?.toInt() ?? 0,
          views: (item['views_count'] as num?)?.toInt() ?? 0,
          moderationStatus: item['moderation_status']?.toString() ?? 'approved',
        );
      }
      return result;
    } catch (e) {
      debugPrint('[CommunityRepository] _fetchMinimalQuotedPosts error: $e');
      return const <String, CommunityPost>{};
    }
  }

  Future<
    ({Map<String, int> followers, Map<String, int> following, bool succeeded})
  >
  _fetchAuthorFollowCounts(
    SupabaseClient client,
    Iterable<String> authorIds,
  ) async {
    final uniqueIds = authorIds.where(_isUuid).toSet().toList();
    if (uniqueIds.isEmpty) {
      return (
        followers: <String, int>{},
        following: <String, int>{},
        succeeded: true,
      );
    }

    const int batchSize = 50;
    const int pageSize = 1000;
    final Map<String, int> followers = <String, int>{
      for (final id in uniqueIds) id: 0,
    };
    final Map<String, int> following = <String, int>{
      for (final id in uniqueIds) id: 0,
    };

    Future<List<Map<String, dynamic>>> fetchFiltered(
      String table,
      String selectCols,
      String filterCol,
      String orderSecondaryCol,
      List<String> chunk,
    ) async {
      final rows = <Map<String, dynamic>>[];
      int offset = 0;
      while (true) {
        final res = await client
            .from(table)
            .select(selectCols)
            .inFilter(filterCol, chunk)
            .order(filterCol, ascending: true)
            .order(orderSecondaryCol, ascending: true)
            .range(offset, offset + pageSize - 1);
        final list = (res as List).whereType<Map<String, dynamic>>().toList();
        rows.addAll(list);
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return rows;
    }

    Future<void> queryTable({
      required String table,
      required String followerCol,
      required String followingCol,
    }) async {
      final chunks = <List<String>>[];
      for (int i = 0; i < uniqueIds.length; i += batchSize) {
        chunks.add(
          uniqueIds.sublist(i, math.min(i + batchSize, uniqueIds.length)),
        );
      }
      final results = await Future.wait(
        chunks.map((chunk) async {
          final cols = '$followerCol, $followingCol';
          final res = await Future.wait([
            fetchFiltered(table, cols, followingCol, followerCol, chunk),
            fetchFiltered(table, cols, followerCol, followingCol, chunk),
          ]);
          return (followerRows: res[0], followingRows: res[1]);
        }),
      );
      for (final entry in results) {
        for (final row in entry.followerRows) {
          final uid = row[followingCol]?.toString() ?? '';
          if (uid.isNotEmpty) {
            followers[uid] = (followers[uid] ?? 0) + 1;
          }
        }
        for (final row in entry.followingRows) {
          final uid = row[followerCol]?.toString() ?? '';
          if (uid.isNotEmpty) {
            following[uid] = (following[uid] ?? 0) + 1;
          }
        }
      }
    }

    try {
      await queryTable(
        table: 'community_follows',
        followerCol: 'follower_id',
        followingCol: 'following_id',
      );
      return (followers: followers, following: following, succeeded: true);
    } catch (e) {
      debugPrint(
        '[CommunityRepository] Error fetching batch community_follows: $e',
      );
      followers.updateAll((_, _) => 0);
      following.updateAll((_, _) => 0);
      try {
        await queryTable(
          table: 'follows',
          followerCol: 'follower_id',
          followingCol: 'followee_id',
        );
        return (followers: followers, following: following, succeeded: true);
      } catch (e2) {
        debugPrint(
          '[CommunityRepository] Error fetching batch follows fallback: $e2',
        );
        return (
          followers: <String, int>{},
          following: <String, int>{},
          succeeded: false,
        );
      }
    }
  }

  CommunityAuthor _transformAuthor(
    CommunityAuthor author, {
    String? targetAuthorId,
    bool? isFollowingOverride,
    int? followersOverride,
    int? followingOverride,
    int? postsCountOverride,
  }) {
    final id = author.id;
    if (targetAuthorId != null && id != targetAuthorId) return author;
    final nextFollowers = followersOverride ?? _authorFollowersCount[id];
    final nextFollowing = followingOverride ?? _authorFollowingCount[id];
    final nextFollowState =
        isFollowingOverride ??
        (_hasLoadedFollows
            ? _followedAuthorIds.contains(id)
            : author.isFollowing);
    if ((nextFollowers == null || nextFollowers == author.followers) &&
        (nextFollowing == null || nextFollowing == author.following) &&
        (postsCountOverride == null ||
            postsCountOverride == author.postsCount) &&
        nextFollowState == author.isFollowing) {
      return author;
    }
    return author.copyWith(
      followers: nextFollowers,
      following: nextFollowing,
      postsCount: postsCountOverride,
      isFollowing: nextFollowState,
    );
  }

  void _applyAuthorCountsToCollections({
    String? targetAuthorId,
    bool? isFollowingOverride,
    int? followersOverride,
    int? followingOverride,
    int? postsCountOverride,
  }) {
    CommunityAuthor updateFn(CommunityAuthor a) => _transformAuthor(
      a,
      targetAuthorId: targetAuthorId,
      isFollowingOverride: isFollowingOverride,
      followersOverride: followersOverride,
      followingOverride: followingOverride,
      postsCountOverride: postsCountOverride,
    );

    _suggestedTraders = _suggestedTraders.map(updateFn).toList();
    _forYouPosts = _forYouPosts
        .map((p) => p.copyWith(author: updateFn(p.author)))
        .toList();
    _followingPosts = _followingPosts
        .map((p) => p.copyWith(author: updateFn(p.author)))
        .toList();
    _signalPosts = _signalPosts
        .map((p) => p.copyWith(author: updateFn(p.author)))
        .toList();
    _bookmarkedPosts = _bookmarkedPosts
        .map((p) => p.copyWith(author: updateFn(p.author)))
        .toList();
    _leaderboard = _leaderboard
        .map((e) => MapEntry(updateFn(e.key), e.value))
        .toList();
    for (final key in _leaderboardByPeriod.keys.toList()) {
      _leaderboardByPeriod[key] = _leaderboardByPeriod[key]!
          .map((e) => MapEntry(updateFn(e.key), e.value))
          .toList();
    }
  }

  /// Syncs authoritative author stats (e.g. from profile overlay queries) into
  /// the cached community lists so network cards and profiles stay consistent.
  void syncAuthorFollowStats(
    String authorId, {
    int? followers,
    int? following,
    bool? isFollowing,
    int? postsCount,
  }) {
    if (authorId.isEmpty) return;
    bool changed = false;
    if (followers != null && _authorFollowersCount[authorId] != followers) {
      _authorFollowersCount[authorId] = followers;
      changed = true;
    }
    if (following != null && _authorFollowingCount[authorId] != following) {
      _authorFollowingCount[authorId] = following;
      changed = true;
    }
    if (isFollowing != null) {
      if (isFollowing) {
        if (_followedAuthorIds.add(authorId)) changed = true;
      } else {
        if (_followedAuthorIds.remove(authorId)) changed = true;
      }
    }
    if (postsCount != null) changed = true;
    if (!changed) return;
    _applyAuthorCountsToCollections(
      targetAuthorId: authorId,
      followersOverride: followers,
      followingOverride: following,
      isFollowingOverride: isFollowing,
      postsCountOverride: postsCount,
    );
    if (!_disposed) notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _fetchScopedFollows(
    SupabaseClient client,
    String table,
    String followingColumn,
    String userId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    const pageSize = 1000;
    while (true) {
      final page = await client
          .from(table)
          .select('follower_id, $followingColumn')
          .or('follower_id.eq.$userId,$followingColumn.eq.$userId')
          .order('follower_id')
          .order(followingColumn)
          .range(rows.length, rows.length + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<void> fetchFromSupabase() async {
    refreshError = null;
    if (!SupabaseConfig.isConfigured) {
      if (!CustomerDataPolicy.allowDemo) {
        refreshError = 'Sign in to refresh community posts.';
      }
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();

      final nextFollowedIds = <String>{};
      final nextFollowerIds = <String>{};
      final Map<String, int> scopedFollowersByAuthor = <String, int>{};
      final Map<String, int> scopedFollowingByAuthor = <String, int>{};
      var scopedFollowsLoaded = false;

      if (_isUuid(targetUserId)) {
        try {
          final allFollowsRes = await _fetchScopedFollows(
            client,
            'community_follows',
            'following_id',
            targetUserId,
          );
          for (final item in allFollowsRes as List) {
            final follower = item['follower_id']?.toString() ?? '';
            final following = item['following_id']?.toString() ?? '';
            if (follower == targetUserId && following.isNotEmpty) {
              nextFollowedIds.add(following);
            }
            if (following == targetUserId && follower.isNotEmpty) {
              nextFollowerIds.add(follower);
            }
            if (following.isNotEmpty) {
              scopedFollowersByAuthor[following] =
                  (scopedFollowersByAuthor[following] ?? 0) + 1;
            }
            if (follower.isNotEmpty) {
              scopedFollowingByAuthor[follower] =
                  (scopedFollowingByAuthor[follower] ?? 0) + 1;
            }
          }
          scopedFollowsLoaded = true;
        } catch (e) {
          debugPrint(
            '[CommunityRepository] Error fetching scoped community_follows: $e',
          );
          try {
            final altFollowsRes = await _fetchScopedFollows(
              client,
              'follows',
              'followee_id',
              targetUserId,
            );
            for (final item in altFollowsRes as List) {
              final follower = item['follower_id']?.toString() ?? '';
              final followee = item['followee_id']?.toString() ?? '';
              if (follower == targetUserId && followee.isNotEmpty) {
                nextFollowedIds.add(followee);
              }
              if (followee == targetUserId && follower.isNotEmpty) {
                nextFollowerIds.add(follower);
              }
              if (followee.isNotEmpty) {
                scopedFollowersByAuthor[followee] =
                    (scopedFollowersByAuthor[followee] ?? 0) + 1;
              }
              if (follower.isNotEmpty) {
                scopedFollowingByAuthor[follower] =
                    (scopedFollowingByAuthor[follower] ?? 0) + 1;
              }
            }
            scopedFollowsLoaded = true;
          } catch (_) {}
        }
      }

      if (_disposed || targetUserId != _resolveUserId()) return;
      if (scopedFollowsLoaded) {
        _followedAuthorIds
          ..clear()
          ..addAll(nextFollowedIds);
        _followerAuthorIds
          ..clear()
          ..addAll(nextFollowerIds);
        _hasLoadedFollows = true;
        _followLoadedForUserId = targetUserId;
        _authorFollowersCount[targetUserId] = nextFollowerIds.length;
        _authorFollowingCount[targetUserId] = nextFollowedIds.length;
      }

      final currentRefreshEpoch = _blockRefreshEpoch;
      final tempOutgoing = <String>{};
      final tempIncoming = <String>{};
      var blockFetchFailed = false;

      if (targetUserId.isNotEmpty) {
        try {
          final blockedRes = await client
              .from('blocks')
              .select('blocked_id')
              .eq('blocker_id', targetUserId);
          for (final item in blockedRes as List) {
            final id = item['blocked_id']?.toString();
            if (id != null && id.isNotEmpty && id != targetUserId) {
              tempOutgoing.add(id);
            }
          }
        } catch (e) {
          blockFetchFailed = true;
          debugPrint('[CommunityRepository] Error fetching blocked users: $e');
        }

        try {
          final blockerRes = await client
              .from('blocks')
              .select('blocker_id')
              .eq('blocked_id', targetUserId);
          for (final item in blockerRes as List) {
            final id = item['blocker_id']?.toString();
            if (id != null && id.isNotEmpty && id != targetUserId) {
              tempIncoming.add(id);
            }
          }
        } catch (e) {
          blockFetchFailed = true;
          debugPrint('[CommunityRepository] Error fetching blockers: $e');
        }
      }

      // Preserve previous block state if either query fails or if a newer mutation occurred
      if (!blockFetchFailed && currentRefreshEpoch == _blockRefreshEpoch) {
        _outgoingBlockedUserIds = tempOutgoing;
        _incomingBlockedUserIds = tempIncoming;
        _blockedUsers = {
          ..._outgoingBlockedUserIds,
          ..._incomingBlockedUserIds,
        };
      }

      final page = await _fetchPostsPage(
        client: client,
        targetUserId: targetUserId,
        offset: 0,
        limit: _postsPageSize,
      );
      if (_disposed) return;

      _loadedPostRows = page.rawRowCount;
      _hasMorePosts = page.rawRowCount >= _postsPageSize;

      await _fetchNetworkActivity(page.posts);
      if (_disposed) return;
      final List<CommunityPost>? savedPosts = await _fetchBookmarkedPosts(
        client,
        targetUserId,
      );
      if (_disposed) return;

      _forYouPosts = page.posts;
      _followingPosts = page.posts
          .where(
            (p) =>
                _followedAuthorIds.contains(p.author.id) ||
                followedReactionsForPost(p.id).isNotEmpty ||
                followedRepostsForPost(p.id).isNotEmpty,
          )
          .toList();
      _signalPosts = page.posts.where((p) => p.tradeSetup != null).toList();
      _commentsByPost = page.comments;
      if (savedPosts != null) _bookmarkedPosts = savedPosts;
      _rebuildBookmarks();

      await fetchLiveRooms();

      try {
        const profileSelectCols =
            'id, handle, display_name, avatar_url, bio, role, experience_level, '
            'trading_style, location, website, avg_hold_duration, primary_market, '
            'top_strategy, risk_mantra, verified, followers_count, following_count, '
            'win_rate, public_stats, posts_count, subscription_tier';
        final profRes = await client
            .from('profiles')
            .select(profileSelectCols)
            .order('win_rate', ascending: false, nullsFirst: false)
            .limit(60);
        final rawProfiles = (profRes as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        final loadedProfileIds = rawProfiles
            .map((p) => p['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();

        final missingFollowerIds = _followerAuthorIds.where(
          (id) => !loadedProfileIds.contains(id),
        );
        final missingFollowedIds = _followedAuthorIds.where(
          (id) => !loadedProfileIds.contains(id),
        );
        final missingIds = {
          ...missingFollowerIds,
          ...missingFollowedIds,
        }.toList();
        if (missingIds.isNotEmpty) {
          final extraProfiles = await client
              .from('profiles')
              .select(profileSelectCols)
              .inFilter('id', missingIds);
          rawProfiles.addAll(
            (extraProfiles as List).whereType<Map<String, dynamic>>(),
          );
        }

        final allAuthorIds = <String>{
          if (_isUuid(targetUserId)) targetUserId,
          for (final p in rawProfiles) p['id']?.toString() ?? '',
          for (final post in page.posts) post.author.id,
        };
        final followCounts = await _fetchAuthorFollowCounts(
          client,
          allAuthorIds,
        );
        if (_disposed) return;

        final Map<String, int> graphFollowers = followCounts.succeeded
            ? followCounts.followers
            : scopedFollowersByAuthor;
        final Map<String, int> graphFollowing = followCounts.succeeded
            ? followCounts.following
            : scopedFollowingByAuthor;

        if (followCounts.succeeded) {
          for (final entry in graphFollowers.entries) {
            _authorFollowersCount[entry.key] = entry.key == targetUserId
                ? math.max(entry.value, _followerAuthorIds.length)
                : entry.value;
          }
          for (final entry in graphFollowing.entries) {
            _authorFollowingCount[entry.key] = entry.key == targetUserId
                ? math.max(entry.value, _followedAuthorIds.length)
                : entry.value;
          }
        }

        final List<CommunityAuthor> authors = [
          for (final pmap in rawProfiles)
            _buildAuthorFromProfile(
              pmap,
              targetUserId: targetUserId,
              graphFollowersByAuthor: graphFollowers,
              graphFollowingByAuthor: graphFollowing,
              hasFullFollowCounts: followCounts.succeeded,
            ),
        ];

        for (final author in authors) {
          if (author.id.isEmpty) continue;
          _authorFollowersCount[author.id] = author.followers;
          _authorFollowingCount[author.id] = author.following;
        }
        _applyAuthorCountsToCollections();

        if (authors.isNotEmpty) {
          _suggestedTraders = authors;
          _leaderboard = _rankLeaderboardEntries(
            authors: authors,
            period: '1M',
          );
          _leaderboardByPeriod.clear();
          _leaderboardByPeriod['1M'] = _leaderboard;
        }
        await fetchLeaderboard(period: '1M');
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching profiles: $e');
      }

      await fetchNotificationsFromSupabase();
      subscribeToRealtimeNotifications();

      notifyListeners();
    } catch (e) {
      refreshError = 'Could not refresh approved community posts.';
      _forYouPosts = const <CommunityPost>[];
      _followingPosts = const <CommunityPost>[];
      _signalPosts = const <CommunityPost>[];
      if (!_disposed) notifyListeners();
      debugPrint('[CommunityRepository] fetchFromSupabase error: $e');
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
      if (_pendingFollowRefresh && !_disposed) {
        final nextUid = _resolveUserId();
        _pendingFollowRefresh = false;
        if (_isUuid(nextUid) && _followLoadedForUserId != nextUid) {
          unawaited(fetchFromSupabase());
        }
      }
    }
  }

  Future<void> fetchLiveRooms() async {
    // Live Audio Spaces are currently disabled in production.
    _liveRooms = <LiveAudioRoom>[];
  }

  UserRole _parseUserRole(String? roleStr) => parseUserRoleStatic(roleStr);

  static UserRole parseUserRoleStatic(String? roleStr) {
    if (roleStr == null) return UserRole.customer;
    final lower = roleStr.toLowerCase();
    if (lower.contains('admin')) return UserRole.userAdmin;
    if (lower.contains('affiliate')) return UserRole.affiliate;
    return UserRole.customer;
  }

  static String? _resolveAvatarUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty || !SupabaseConfig.isConfigured) {
      return raw;
    }
    final client = SupabaseConfig.client;
    if (client == null) return raw;
    return SupabaseStorageEgress.resolvePublicCdnUrl(
      client: client,
      bucket: SupabaseStorageEgress.avatars.bucketId,
      ref: raw,
    );
  }

  @visibleForTesting
  static ({int followers, int following}) resolveAuthorFollowCounts({
    required String authorId,
    required int dbFollowers,
    required int dbFollowing,
    required Map<String, int> graphFollowersByAuthor,
    required Map<String, int> graphFollowingByAuthor,
    required bool hasFullFollowCounts,
    bool isFollowingAuthor = false,
    bool isCurrentUser = false,
    int currentUserFollowerIdsCount = 0,
    int currentUserFollowingIdsCount = 0,
  }) {
    final int graphFollowers = graphFollowersByAuthor[authorId] ?? 0;
    final int graphFollowing = graphFollowingByAuthor[authorId] ?? 0;

    int followers = hasFullFollowCounts
        ? graphFollowers
        : math.max(dbFollowers, graphFollowers);
    int following = hasFullFollowCounts
        ? graphFollowing
        : math.max(dbFollowing, graphFollowing);

    if (!hasFullFollowCounts && isFollowingAuthor && followers == 0) {
      followers = 1;
    }

    if (isCurrentUser) {
      followers = math.max(followers, currentUserFollowerIdsCount);
      following = math.max(following, currentUserFollowingIdsCount);
    }

    return (followers: followers, following: following);
  }

  CommunityAuthor _buildAuthorFromProfile(
    Map<String, dynamic> pmap, {
    required String targetUserId,
    required Map<String, int> graphFollowersByAuthor,
    required Map<String, int> graphFollowingByAuthor,
    required bool hasFullFollowCounts,
  }) {
    final pId = pmap['id']?.toString() ?? '';
    final bool statsPublic = pmap['public_stats'] as bool? ?? true;
    if (!statsPublic) {
      _privateStatsAuthorIds.add(pId);
    } else {
      _privateStatsAuthorIds.remove(pId);
    }
    final bool isCurrUser = pId.isNotEmpty && pId == targetUserId;
    final bool isFollowingThisAuthor = _followedAuthorIds.contains(pId);
    final counts = resolveAuthorFollowCounts(
      authorId: pId,
      dbFollowers: (pmap['followers_count'] as num?)?.toInt() ?? 0,
      dbFollowing: (pmap['following_count'] as num?)?.toInt() ?? 0,
      graphFollowersByAuthor: graphFollowersByAuthor,
      graphFollowingByAuthor: graphFollowingByAuthor,
      hasFullFollowCounts: hasFullFollowCounts,
      isFollowingAuthor: isFollowingThisAuthor,
      isCurrentUser: isCurrUser,
      currentUserFollowerIdsCount: _followerAuthorIds.length,
      currentUserFollowingIdsCount: _followedAuthorIds.length,
    );
    return mapProfileToCommunityAuthor(
      authorId: pId,
      authorProfile: pmap,
      isFollowing: isFollowingThisAuthor,
      followersOverride: counts.followers,
      followingOverride: counts.following,
    );
  }

  static CommunityAuthor mapProfileToCommunityAuthor({
    required String authorId,
    required Map<String, dynamic>? authorProfile,
    bool isFollowing = false,
    int? followersOverride,
    int? followingOverride,
  }) {
    final subTier =
        (authorProfile?['subscription_tier'] as String?)
            ?.toLowerCase()
            .trim() ??
        'free';
    final appTier = switch (subTier) {
      'enterprise' || 'pro' => AppTier.enterprise,
      'premium' || 'basic' || 'starter' => AppTier.premium,
      _ => AppTier.free,
    };

    final bool statsPublic = authorProfile?['public_stats'] as bool? ?? true;
    final rawHandle =
        (authorProfile?['handle'] ?? authorProfile?['username']) as String? ??
        'trader';
    final cleanHandle = rawHandle.replaceFirst(RegExp(r'^@+'), '').trim();
    final effectiveHandle = cleanHandle.isEmpty ? 'trader' : cleanHandle;

    return CommunityAuthor(
      id: authorId,
      handle: effectiveHandle,
      displayName:
          authorProfile?['display_name'] as String? ??
          (authorProfile == null ? 'Trader' : effectiveHandle),
      userRole: parseUserRoleStatic(authorProfile?['role'] as String?),
      avatarUrl: _resolveAvatarUrl(authorProfile?['avatar_url'] as String?),
      bio: authorProfile?['bio'] as String?,
      verified: authorProfile?['verified'] as bool? ?? false,
      subscriptionTier: subTier,
      tier: appTier,
      isFollowing: isFollowing,
      followers:
          followersOverride ??
          (authorProfile?['followers_count'] as num?)?.toInt() ??
          0,
      following:
          followingOverride ??
          (authorProfile?['following_count'] as num?)?.toInt() ??
          0,
      winRate: statsPublic
          ? (authorProfile?['win_rate'] as num?)?.toDouble()
          : null,
      tradingStyle:
          (authorProfile?['top_strategy'] ?? authorProfile?['trading_style'])
              as String?,
      primaryMarket: authorProfile?['primary_market'] as String?,
      avgHoldDuration: authorProfile?['avg_hold_duration'] as String?,
      riskMantra: authorProfile?['risk_mantra'] as String?,
      location: authorProfile?['location'] as String?,
      website: authorProfile?['website'] as String?,
      postsCount: (authorProfile?['posts_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool _disposed = false;
  Future<void>? _marketLoad;
  String? marketDataError;
  MarketSnapshot? marketSnapshot;
  Future<void> loadMarketData({AssetMarketRepository? source}) {
    final Future<void>? activeLoad = _marketLoad;
    if (activeLoad != null) return activeLoad;

    final Future<void> nextLoad = _loadMarketData(
      source ?? AssetMarketRepository.shared,
    );
    _marketLoad = nextLoad;
    return nextLoad.whenComplete(() {
      if (identical(_marketLoad, nextLoad)) {
        _marketLoad = null;
      }
    });
  }

  Future<void> _loadMarketData(AssetMarketRepository source) async {
    marketDataError = null;
    try {
      final snapshot = await source.communityPreview();
      if (_disposed) return;
      marketSnapshot = snapshot;
      final Set<String> seenArticleIds = <String>{};
      _news =
          snapshot.articles
              .map(
                (MarketArticle article) => CommunityNewsItem(
                  id: article.link.isEmpty ? article.title : article.link,
                  headline: article.title.trim(),
                  source: article.publisher.trim().isEmpty
                      ? 'Market wire'
                      : article.publisher.trim(),
                  publishedAt: article.publishedAt ?? DateTime(1970),
                  summary: article.summary.trim(),
                  articleUrl: article.link,
                  thumbnail: article.thumbnailUrl,
                  relatedTickers: article.tickers,
                ),
              )
              .where(
                (CommunityNewsItem item) =>
                    item.headline.isNotEmpty && seenArticleIds.add(item.id),
              )
              .toList()
            ..sort(
              (CommunityNewsItem a, CommunityNewsItem b) =>
                  b.publishedAt.compareTo(a.publishedAt),
            );
      _trending = _buildLiveMarketTrends(snapshot, _news);
      notifyListeners();
    } catch (_) {
      if (!_disposed) {
        marketDataError = 'Market assets unavailable';
        notifyListeners();
      }
    }
  }

  List<CommunityTrendItem> _buildLiveMarketTrends(
    MarketSnapshot snapshot,
    List<CommunityNewsItem> latestNews,
  ) {
    final Map<String, int> mentionsByTicker = <String, int>{};
    for (final CommunityNewsItem item in latestNews.take(25)) {
      for (final String rawTicker in item.relatedTickers) {
        final String ticker = rawTicker.trim().toUpperCase();
        if (ticker.isEmpty) continue;
        mentionsByTicker.update(
          ticker,
          (int count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final Map<String, MarketInstrument> instrumentsBySymbol =
        <String, MarketInstrument>{
          for (final MarketInstrument instrument in snapshot.instruments)
            instrument.symbol.toUpperCase(): instrument,
        };
    final List<MapEntry<String, int>> rankedMentions =
        mentionsByTicker.entries.toList()
          ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
            final int countOrder = b.value.compareTo(a.value);
            if (countOrder != 0) return countOrder;
            final double aMove =
                instrumentsBySymbol[a.key]?.changePercent.abs() ?? 0;
            final double bMove =
                instrumentsBySymbol[b.key]?.changePercent.abs() ?? 0;
            return bMove.compareTo(aMove);
          });

    final List<CommunityTrendItem> trends = <CommunityTrendItem>[
      for (final MapEntry<String, int> entry in rankedMentions.take(5))
        CommunityTrendItem(
          id: 'market-trend-${entry.key}',
          topic: '\$${entry.key}',
          category:
              'Market wire · ${entry.value} ${entry.value == 1 ? 'story' : 'stories'}',
          postCount: instrumentsBySymbol[entry.key] == null
              ? null
              : AppTokens.signedPercent(
                  instrumentsBySymbol[entry.key]!.changePercent,
                ),
        ),
    ];
    if (trends.length >= 4) return trends;

    final Set<String> usedSymbols = <String>{
      for (final CommunityTrendItem trend in trends)
        trend.topic.replaceFirst(r'$', ''),
    };
    final List<MarketInstrument> biggestMoves =
        <MarketInstrument>[...snapshot.instruments]..sort(
          (MarketInstrument a, MarketInstrument b) =>
              b.changePercent.abs().compareTo(a.changePercent.abs()),
        );
    for (final MarketInstrument instrument in biggestMoves) {
      final String symbol = instrument.symbol.toUpperCase();
      if (!usedSymbols.add(symbol)) continue;
      trends.add(
        CommunityTrendItem(
          id: 'market-move-$symbol',
          topic: '\$$symbol',
          category: 'Largest market moves',
          postCount: AppTokens.signedPercent(instrument.changePercent),
        ),
      );
      if (trends.length == 5) break;
    }
    return trends;
  }

  Future<void> loadMorePosts() async {
    if (!SupabaseConfig.isConfigured ||
        _disposed ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMorePosts) {
      return;
    }
    _isLoadingMore = true;
    notifyListeners();
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      final page = await _fetchPostsPage(
        client: client,
        targetUserId: targetUserId,
        offset: _loadedPostRows,
        limit: _postsPageSize,
      );
      if (_disposed) return;

      _loadedPostRows += page.rawRowCount;
      _hasMorePosts = page.rawRowCount >= _postsPageSize;

      if (page.posts.isNotEmpty) {
        final existingIds = _forYouPosts.map((p) => p.id).toSet();
        final nextPosts = page.posts
            .where((p) => !existingIds.contains(p.id))
            .toList();
        if (nextPosts.isNotEmpty) {
          final uncachedAuthorIds = nextPosts
              .map((p) => p.author.id)
              .where(
                (id) => _isUuid(id) && !_authorFollowersCount.containsKey(id),
              )
              .toSet();
          if (uncachedAuthorIds.isNotEmpty) {
            final extraCounts = await _fetchAuthorFollowCounts(
              client,
              uncachedAuthorIds,
            );
            if (_disposed) return;
            if (extraCounts.succeeded) {
              _authorFollowersCount.addAll(extraCounts.followers);
              _authorFollowingCount.addAll(extraCounts.following);
            }
          }
          _forYouPosts = [..._forYouPosts, ...nextPosts];
          _applyAuthorCountsToCollections();
          await _fetchNetworkActivity(_forYouPosts);
          if (_disposed) return;
          _followingPosts = _forYouPosts
              .where(
                (p) =>
                    _followedAuthorIds.contains(p.author.id) ||
                    followedReactionsForPost(p.id).isNotEmpty ||
                    followedRepostsForPost(p.id).isNotEmpty,
              )
              .toList();
          _signalPosts = _forYouPosts
              .where((p) => p.tradeSetup != null)
              .toList();
          _rebuildBookmarks();
        }
      }
      if (page.comments.isNotEmpty) {
        _commentsByPost = {..._commentsByPost, ...page.comments};
      }
    } catch (e) {
      debugPrint('[CommunityRepository] Error loading more posts: $e');
    } finally {
      _isLoadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Loads the complete profile feed for one author instead of relying on the
  /// first page of the global community timeline. Public viewers receive only
  /// approved public posts; the owner receives their private and pending posts
  /// as well.
  Future<void> fetchPostsForAuthor(String authorId) {
    final cleanAuthorId = authorId.trim();
    if (cleanAuthorId.isEmpty ||
        !SupabaseConfig.isConfigured ||
        !_isUuid(cleanAuthorId)) {
      return Future<void>.value();
    }
    final existing = _authorPostLoads[cleanAuthorId];
    if (existing != null) return existing;
    final load = _fetchPostsForAuthor(cleanAuthorId);
    _authorPostLoads[cleanAuthorId] = load;
    return load.whenComplete(() => _authorPostLoads.remove(cleanAuthorId));
  }

  bool hasLoadedPostsForAuthor(String authorId) =>
      _loadedAuthorPostIds.contains(authorId.trim());

  Future<void> _fetchPostsForAuthor(String authorId) async {
    final client = SupabaseConfig.client;
    if (client == null) return;
    final targetUserId = _resolveUserId();
    const pageSize = 100;
    var offset = 0;
    final loadedPosts = <CommunityPost>[];
    final loadedComments = <String, List<CommunityComment>>{};

    while (true) {
      final page = await _fetchPostsPage(
        client: client,
        targetUserId: targetUserId,
        offset: offset,
        limit: pageSize,
        authorId: authorId,
      );
      loadedPosts.addAll(page.posts);
      loadedComments.addAll(page.comments);
      if (page.rawRowCount < pageSize) break;
      offset += pageSize;
    }
    if (_disposed || targetUserId != _resolveUserId()) return;

    _forYouPosts = <CommunityPost>[
      ..._forYouPosts.where((post) => post.author.id != authorId),
      ...loadedPosts,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _commentsByPost = <String, List<CommunityComment>>{
      ..._commentsByPost,
      ...loadedComments,
    };
    _followingPosts = _forYouPosts
        .where(
          (post) =>
              _followedAuthorIds.contains(post.author.id) ||
              followedReactionsForPost(post.id).isNotEmpty ||
              followedRepostsForPost(post.id).isNotEmpty,
        )
        .toList();
    _signalPosts = _forYouPosts
        .where((post) => post.tradeSetup != null)
        .toList();
    _loadedAuthorPostIds.add(authorId);
    _rebuildBookmarks();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeDebounceTimer?.cancel();
    AppVisibility.instance.removeListener(_onVisibilityChanged);
    final realtime = _realtimeChannel;
    final notifications = _notificationsChannel;
    _realtimeChannel = null;
    _notificationsChannel = null;
    if (SupabaseConfig.isConfigured) {
      final client = SupabaseConfig.client;
      if (client != null) {
        if (realtime != null) {
          unawaited(client.removeChannel(realtime).catchError((_) => ''));
        }
        if (notifications != null) {
          unawaited(client.removeChannel(notifications).catchError((_) => ''));
        }
      }
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Seed Authors
  // -------------------------------------------------------------------------

  late final CommunityAuthor _alexVance;
  late final CommunityAuthor _marcoSilva;
  late final CommunityAuthor _elenaRostova;
  late final CommunityAuthor _priyaSharma;
  late final CommunityAuthor _alphajournalWire;
  late final CommunityAuthor _arisThorne;
  late final CommunityAuthor _rajeshPatel;
  late final CommunityAuthor _sarahWong;

  // -------------------------------------------------------------------------
  // State
  // -------------------------------------------------------------------------

  List<CommunityPost> _forYouPosts = <CommunityPost>[];
  List<CommunityPost> _followingPosts = <CommunityPost>[];
  List<CommunityPost> _signalPosts = <CommunityPost>[];
  List<CommunityPost> _bookmarkedPosts = <CommunityPost>[];
  Map<String, List<CommunityComment>> _commentsByPost =
      <String, List<CommunityComment>>{};
  List<CommunityAuthor> _suggestedTraders = <CommunityAuthor>[];
  List<MapEntry<CommunityAuthor, double>> _leaderboard =
      <MapEntry<CommunityAuthor, double>>[];
  final Map<String, List<MapEntry<CommunityAuthor, double>>>
  _leaderboardByPeriod = <String, List<MapEntry<CommunityAuthor, double>>>{};
  final Set<String> _privateStatsAuthorIds = <String>{};
  List<CommunityNewsItem> _news = <CommunityNewsItem>[];
  List<CommunityTrendItem> _trending = <CommunityTrendItem>[];
  List<CommunityNotificationItem> _notifications =
      <CommunityNotificationItem>[];
  RealtimeChannel? _notificationsChannel;
  ValueChanged<CommunityNotificationItem>? onLiveNotificationReceived;
  bool _pushNotificationsPromptVisible = true;
  List<AppWritingPostAttachment> _attachableRecords =
      <AppWritingPostAttachment>[];

  final Set<String> _mutedUsers = <String>{};
  Set<String> _outgoingBlockedUserIds = <String>{};
  Set<String> _incomingBlockedUserIds = <String>{};
  Set<String> _blockedUsers = <String>{};
  int _blockRefreshEpoch = 0;
  final Set<String> _followedAuthorIds = <String>{};
  final Set<String> _followerAuthorIds = <String>{};
  final Map<String, int> _authorFollowersCount = <String, int>{};
  final Map<String, int> _authorFollowingCount = <String, int>{};
  final List<String> _customFeedTabs = <String>['Crypto', 'Options'];
  List<CommunityConversation> _conversations = <CommunityConversation>[];
  final Map<String, List<CommunityChatMessage>> _messagesByConversation =
      <String, List<CommunityChatMessage>>{};
  final Map<String, CommunityPostInsights> _insightsByPost =
      <String, CommunityPostInsights>{};
  final Map<String, int> _detailExpandsByPost = <String, int>{};
  final Map<String, int> _profileVisitsByPost = <String, int>{};
  final Map<String, int> _linkClicksByPost = <String, int>{};
  final Map<String, int> _sharesByPost = <String, int>{};
  final Set<String> _viewedPostIds = <String>{};
  List<LiveAudioRoom> _liveRooms = <LiveAudioRoom>[];
  String? _tunedRoomId;
  bool _isAudioMuted = true;
  bool _isHandRaised = false;

  // -------------------------------------------------------------------------
  // Accessors
  // -------------------------------------------------------------------------

  List<CommunityPost> get forYouPosts => _forYouPosts
      .where(
        (p) =>
            p.isPublic &&
            (!p.isPendingApproval || p.author.id == currentAuthor.id) &&
            (p.scheduledFor == null ||
                !p.scheduledFor!.isAfter(DateTime.now())) &&
            !_mutedUsers.contains(p.author.id) &&
            !_blockedUsers.contains(p.author.id),
      )
      .toList();
  List<CommunityPost> get followingPosts => _followingPosts
      .where(
        (p) =>
            p.isPublic &&
            (!p.isPendingApproval || p.author.id == currentAuthor.id) &&
            (p.scheduledFor == null ||
                !p.scheduledFor!.isAfter(DateTime.now())) &&
            !_mutedUsers.contains(p.author.id) &&
            !_blockedUsers.contains(p.author.id),
      )
      .toList();
  List<CommunityPost> get signalPosts => _signalPosts
      .where(
        (p) =>
            p.isPublic &&
            (!p.isPendingApproval || p.author.id == currentAuthor.id) &&
            (p.scheduledFor == null ||
                !p.scheduledFor!.isAfter(DateTime.now())) &&
            !_mutedUsers.contains(p.author.id) &&
            !_blockedUsers.contains(p.author.id),
      )
      .toList();
  List<CommunityPost> get bookmarkedPosts => _bookmarkedPosts
      .where((post) => post.isPublic || post.author.id == currentAuthor.id)
      .toList();
  List<CommunityAuthor> get suggestedTraders =>
      _suggestedTraders.where((a) => !_blockedUsers.contains(a.id)).toList();
  List<MapEntry<CommunityAuthor, double>> get leaderboard =>
      leaderboardForPeriod('1M');

  DateTime? _leaderboardCutoff(String period, DateTime now) =>
      switch (period.toUpperCase()) {
        '1W' => now.subtract(const Duration(days: 7)),
        '1M' => now.subtract(const Duration(days: 30)),
        '3M' => now.subtract(const Duration(days: 90)),
        _ => null,
      };

  List<MapEntry<CommunityAuthor, double>> _rankLeaderboardEntries({
    required List<CommunityAuthor> authors,
    required String period,
    Map<String, ({int wins, int total})>? tradeStatsByAuthor,
    Map<String, int>? recentPostCountByAuthor,
  }) {
    final normPeriod = period.toUpperCase();
    final currentUid = currentAuthor.id;
    final bool currentStatsPublic =
        SupabaseAuthBackendService.instance.currentUserProfile?.publicStats ??
        true;

    final Map<String, CommunityAuthor> unique = <String, CommunityAuthor>{};
    for (final a in authors) {
      if (a.id.isEmpty) continue;
      if (_blockedUsers.contains(a.id)) continue;
      if (_privateStatsAuthorIds.contains(a.id)) continue;
      if (a.id == currentUid && !currentStatsPublic) continue;
      unique.putIfAbsent(a.id, () => a);
    }

    final rows =
        <({CommunityAuthor author, double score, int trades, int posts})>[];
    for (final author in unique.values) {
      final tStats = tradeStatsByAuthor?[author.id];
      final int trades = tStats?.total ?? 0;
      final int posts = recentPostCountByAuthor?[author.id] ?? 0;
      double? score;
      if (tStats != null && tStats.total > 0) {
        score = (tStats.wins / tStats.total) * 100.0;
      } else if (author.winRate != null && author.winRate! > 0) {
        score = author.winRate!;
      }

      if (score == null) continue;
      rows.add((
        author: author.copyWith(
          isFollowing: _followedAuthorIds.contains(author.id),
          winRate: score,
        ),
        score: double.parse(score.toStringAsFixed(1)),
        trades: trades,
        posts: posts,
      ));
    }

    rows.sort((a, b) {
      final cmpScore = b.score.compareTo(a.score);
      if (cmpScore != 0) return cmpScore;
      final cmpTrades = b.trades.compareTo(a.trades);
      if (cmpTrades != 0) return cmpTrades;
      final cmpPosts = b.posts.compareTo(a.posts);
      if (cmpPosts != 0) return cmpPosts;
      final cmpFollowers = b.author.followers.compareTo(a.author.followers);
      if (cmpFollowers != 0) return cmpFollowers;
      return b.author.postsCount.compareTo(a.author.postsCount);
    });

    // If Supabase profiles have no recorded win_rate or public trades yet,
    // still surface active non-private community authors ranked by setups & followers.
    if (rows.isEmpty && unique.isNotEmpty) {
      final cutoff = _leaderboardCutoff(normPeriod, DateTime.now());
      final fallbackRows =
          unique.values.map((author) {
            final periodPosts = _forYouPosts
                .where(
                  (p) =>
                      p.author.id == author.id &&
                      (cutoff == null || !p.createdAt.isBefore(cutoff)),
                )
                .length;
            return (
              author: author.copyWith(
                isFollowing: _followedAuthorIds.contains(author.id),
              ),
              score: author.winRate ?? 0.0,
              periodPosts: periodPosts,
            );
          }).toList()..sort((a, b) {
            final cmpVal = b.score.compareTo(a.score);
            if (cmpVal != 0) return cmpVal;
            final cmpPeriod = b.periodPosts.compareTo(a.periodPosts);
            if (cmpPeriod != 0) return cmpPeriod;
            final cmpPosts = b.author.postsCount.compareTo(a.author.postsCount);
            if (cmpPosts != 0) return cmpPosts;
            return b.author.followers.compareTo(a.author.followers);
          });
      return [for (final r in fallbackRows) MapEntry(r.author, r.score)];
    }

    return [for (final r in rows) MapEntry(r.author, r.score)];
  }

  List<MapEntry<CommunityAuthor, double>> leaderboardForPeriod(String period) {
    final norm = period.toUpperCase();
    final cached = _leaderboardByPeriod[norm];
    if (cached != null && cached.isNotEmpty) {
      return cached
          .where(
            (e) =>
                !_blockedUsers.contains(e.key.id) &&
                !_privateStatsAuthorIds.contains(e.key.id),
          )
          .map(
            (e) => MapEntry(
              e.key.copyWith(
                isFollowing: _followedAuthorIds.contains(e.key.id),
              ),
              e.value,
            ),
          )
          .toList();
    }

    final base = _leaderboard
        .where(
          (e) =>
              !_blockedUsers.contains(e.key.id) &&
              !_privateStatsAuthorIds.contains(e.key.id),
        )
        .toList();
    final seenBaseIds = base.map((e) => e.key.id).toSet();
    final extraFromPosts = _forYouPosts
        .where(
          (p) =>
              p.author.id.isNotEmpty &&
              !seenBaseIds.contains(p.author.id) &&
              !_blockedUsers.contains(p.author.id) &&
              !_privateStatsAuthorIds.contains(p.author.id) &&
              p.author.winRate != null &&
              p.author.winRate! > 0,
        )
        .map((p) {
          seenBaseIds.add(p.author.id);
          return MapEntry<CommunityAuthor, double>(p.author, p.author.winRate!);
        });
    final combinedBase = <MapEntry<CommunityAuthor, double>>[
      ...base,
      ...extraFromPosts,
    ];

    if (combinedBase.isEmpty) {
      final candidateAuthors = <CommunityAuthor>[
        ..._suggestedTraders,
        ..._forYouPosts.map((p) => p.author),
      ];
      return _rankLeaderboardEntries(authors: candidateAuthors, period: norm);
    }

    if (!SupabaseConfig.isConfigured && norm != '1M') {
      final adjusted = combinedBase.asMap().entries.map((entry) {
        final idx = entry.key;
        final author = entry.value.key;
        final raw = entry.value.value;
        final delta = switch (norm) {
          '1W' => ((idx % 3 == 0 ? 4.2 : (idx % 2 == 0 ? -2.8 : 1.7))),
          '3M' => ((idx % 2 == 0 ? -1.4 : 2.9)),
          'ALL' => ((idx == 0 ? -3.1 : (idx % 2 == 1 ? 3.5 : 0.8))),
          _ => 0.0,
        };
        final next = (raw + delta).clamp(1.0, 99.0);
        return MapEntry(
          author.copyWith(isFollowing: _followedAuthorIds.contains(author.id)),
          double.parse(next.toStringAsFixed(1)),
        );
      }).toList()..sort((a, b) => b.value.compareTo(a.value));
      return adjusted;
    }

    final sorted =
        combinedBase
            .map(
              (e) => MapEntry(
                e.key.copyWith(
                  isFollowing: _followedAuthorIds.contains(e.key.id),
                ),
                e.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final cmp = b.value.compareTo(a.value);
            if (cmp != 0) return cmp;
            return b.key.followers.compareTo(a.key.followers);
          });
    return sorted;
  }

  Future<List<MapEntry<CommunityAuthor, double>>> fetchLeaderboard({
    String period = '1M',
  }) async {
    final norm = period.toUpperCase();
    if (!SupabaseConfig.isConfigured) {
      final local = leaderboardForPeriod(norm);
      _leaderboardByPeriod[norm] = local;
      notifyListeners();
      return local;
    }
    final client = SupabaseConfig.client;
    if (client == null) return leaderboardForPeriod(norm);

    final now = DateTime.now().toUtc();
    final cutoff = _leaderboardCutoff(norm, now);
    final currentUid = currentAuthor.id;

    try {
      final profFuture = client
          .from('profiles')
          .select(
            'id, handle, display_name, avatar_url, bio, role, experience_level, trading_style, location, website, avg_hold_duration, primary_market, top_strategy, risk_mantra, verified, followers_count, following_count, win_rate, public_stats, posts_count, subscription_tier',
          )
          .order('win_rate', ascending: false, nullsFirst: false)
          .limit(60);

      final Map<String, ({int wins, int total})> tradeStats =
          <String, ({int wins, int total})>{};
      Future<void> loadTradeStats() async {
        try {
          dynamic query = client
              .from('journal_entries')
              .select('user_id, outcome, pnl, exit_price, opened_at, closed_at')
              .eq('is_public', true);
          if (cutoff != null) {
            query = query.gte('opened_at', cutoff.toIso8601String());
          }
          final tradeRows = await query.limit(500);
          for (final row in tradeRows as List) {
            final r = row as Map<String, dynamic>;
            final uid = r['user_id']?.toString() ?? '';
            if (uid.isEmpty || _privateStatsAuthorIds.contains(uid)) continue;
            final outcome = r['outcome']?.toString().toLowerCase() ?? '';
            final exitPrice = r['exit_price'];
            if (outcome == 'open' || (outcome.isEmpty && exitPrice == null)) {
              continue;
            }
            final pnl = (r['pnl'] as num?)?.toDouble() ?? 0.0;
            final bool isWin = outcome == 'win' || (outcome.isEmpty && pnl > 0);
            final prev = tradeStats[uid] ?? (wins: 0, total: 0);
            tradeStats[uid] = (
              wins: prev.wins + (isWin ? 1 : 0),
              total: prev.total + 1,
            );
          }
        } catch (e) {
          debugPrint(
            '[CommunityRepository] leaderboard trade stats skipped: $e',
          );
        }
      }

      final profAndStats = await Future.wait([profFuture, loadTradeStats()]);
      if (_disposed) return leaderboardForPeriod(norm);

      final rawProfiles = (profAndStats[0] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final publicProfileMaps = <Map<String, dynamic>>[];
      final publicIds = <String>[];
      for (final pmap in rawProfiles) {
        final pId = pmap['id']?.toString() ?? '';
        if (pId.isEmpty) continue;
        final statsPublic = pmap['public_stats'] as bool? ?? true;
        if (!statsPublic) {
          _privateStatsAuthorIds.add(pId);
          continue;
        }
        _privateStatsAuthorIds.remove(pId);
        publicProfileMaps.add(pmap);
        publicIds.add(pId);
      }

      final followCounts = await _fetchAuthorFollowCounts(client, publicIds);
      if (_disposed) return leaderboardForPeriod(norm);
      if (followCounts.succeeded) {
        for (final entry in followCounts.followers.entries) {
          _authorFollowersCount[entry.key] = entry.key == currentUid
              ? math.max(entry.value, _followerAuthorIds.length)
              : entry.value;
        }
        for (final entry in followCounts.following.entries) {
          _authorFollowingCount[entry.key] = entry.key == currentUid
              ? math.max(entry.value, _followedAuthorIds.length)
              : entry.value;
        }
      }

      final authors = <CommunityAuthor>[
        for (final pmap in publicProfileMaps)
          _buildAuthorFromProfile(
            pmap,
            targetUserId: currentUid,
            graphFollowersByAuthor: followCounts.succeeded
                ? _authorFollowersCount
                : const <String, int>{},
            graphFollowingByAuthor: followCounts.succeeded
                ? _authorFollowingCount
                : const <String, int>{},
            hasFullFollowCounts: followCounts.succeeded,
          ),
      ];

      final Map<String, int> recentPosts = <String, int>{};
      for (final p in _forYouPosts) {
        if (cutoff == null || !p.createdAt.isBefore(cutoff)) {
          recentPosts[p.author.id] = (recentPosts[p.author.id] ?? 0) + 1;
        }
      }

      // If no live profiles have wins/trades yet, preserve any explicitly set
      // current user's public_stats preference visibility.
      if (currentUid.isNotEmpty) {
        final bool currPublic =
            SupabaseAuthBackendService
                .instance
                .currentUserProfile
                ?.publicStats ??
            true;
        if (!currPublic) {
          _privateStatsAuthorIds.add(currentUid);
        } else {
          _privateStatsAuthorIds.remove(currentUid);
        }
      }

      final mergedAuthors = authors.isNotEmpty ? authors : _suggestedTraders;
      final ranked = _rankLeaderboardEntries(
        authors: mergedAuthors,
        period: norm,
        tradeStatsByAuthor: tradeStats,
        recentPostCountByAuthor: recentPosts,
      );
      _leaderboardByPeriod[norm] = ranked;
      if (norm == '1M' || _leaderboard.isEmpty) {
        _leaderboard = ranked;
      }
      if (followCounts.succeeded) {
        _applyAuthorCountsToCollections();
      }
      if (!_disposed) notifyListeners();
      return ranked;
    } catch (e) {
      debugPrint('[CommunityRepository] fetchLeaderboard error: $e');
      return leaderboardForPeriod(norm);
    }
  }

  List<CommunityNewsItem> get news => _news;
  Map<String, List<CommunityNewsItem>> get newsByCategory {
    final snapshot = marketSnapshot;
    if (snapshot == null) {
      final groups = <String, List<CommunityNewsItem>>{};
      for (final item in _news) {
        (groups[item.category] ??= []).add(item);
      }
      return groups;
    }
    final byId = {for (final item in _news) item.id: item};
    final groups = <String, List<CommunityNewsItem>>{
      for (final topic in snapshot.topics.entries)
        topic.key: topic.value
            .map((a) => byId[a.link.isEmpty ? a.title : a.link])
            .whereType<CommunityNewsItem>()
            .toList(),
    };
    final categorized = groups.values
        .expand((items) => items)
        .map((item) => item.id)
        .toSet();
    final remaining = _news
        .where((item) => !categorized.contains(item.id))
        .toList();
    if (remaining.isNotEmpty) groups['other_market_news'] = remaining;
    return groups;
  }

  List<CommunityTrendItem> get trending => _trending;
  List<CommunityNotificationItem> get notifications => _notifications;
  bool get pushNotificationsPromptVisible => _pushNotificationsPromptVisible;
  int get unreadNotifications => _notifications.where((n) => !n.read).length;

  Set<String> get mutedUsers => _mutedUsers;
  Set<String> get blockedUsers => _blockedUsers;
  Set<String> get followedAuthorIds => Set.unmodifiable(_followedAuthorIds);
  Set<String> get followerAuthorIds => Set.unmodifiable(_followerAuthorIds);
  List<CommunityPost> get feedPosts => forYouPosts;
  List<CommunityAuthor> get topTraders => suggestedTraders;

  bool isFollowing(String authorId) =>
      _followedAuthorIds.contains(authorId) ||
      _suggestedTraders.any((a) => a.id == authorId && a.isFollowing);

  int get followingCount {
    if (_hasLoadedFollows) {
      return _followedAuthorIds.length;
    }
    final cached = _authorFollowingCount[currentAuthor.id];
    if (cached != null) return cached;
    final direct = _followedAuthorIds.length;
    final suggested = _suggestedTraders.where((t) => t.isFollowing).length;
    final override = _currentAuthorOverride?.following ?? 0;
    return math.max(direct, math.max(suggested, override));
  }

  int get followersCount {
    if (_hasLoadedFollows) {
      return _followerAuthorIds.length;
    }
    final cached = _authorFollowersCount[currentAuthor.id];
    if (cached != null) return cached;
    final direct = _followerAuthorIds.length;
    final override = _currentAuthorOverride?.followers ?? 0;
    return math.max(direct, override);
  }

  List<CommunityAuthor> get allKnownAuthors {
    final map = <String, CommunityAuthor>{};
    for (final a in _suggestedTraders) {
      map[a.id] = a.copyWith(isFollowing: isFollowing(a.id));
    }
    for (final p in _forYouPosts) {
      if (!map.containsKey(p.author.id)) {
        map[p.author.id] = p.author.copyWith(
          isFollowing: isFollowing(p.author.id),
        );
      }
    }
    return map.values.toList();
  }

  List<LiveAudioRoom> get liveRooms =>
      _liveRooms.where((r) => r.isLive).toList();
  List<LiveAudioRoom> get upcomingRooms =>
      _liveRooms.where((r) => r.isScheduled).toList();
  List<LiveAudioRoom> get allLiveRooms =>
      List<LiveAudioRoom>.unmodifiable(_liveRooms);
  LiveAudioRoom? get activeTunedRoom {
    if (_tunedRoomId == null) return null;
    return _liveRooms.cast<LiveAudioRoom?>().firstWhere(
      (r) => r?.id == _tunedRoomId,
      orElse: () => null,
    );
  }

  bool get isTunedIntoLiveRoom => _tunedRoomId != null;
  bool get isAudioMuted => _isAudioMuted;
  bool get isHandRaised => _isHandRaised;

  static const CommunityAuthor _defaultCurrentUser = CommunityAuthor(
    id: 'usr_current_trader',
    handle: '',
    displayName: '',
    userRole: UserRole.customer,
    verified: false,
    tier: AppTier.free,
    followers: 0,
    following: 0,
    winRate: null,
    tradingStyle: null,
    primaryMarket: null,
    postsCount: 0,
  );

  CommunityAuthor? _currentAuthorOverride;
  CommunityAuthor get currentAuthor =>
      _transformAuthor(_currentAuthorOverride ?? _defaultCurrentUser);
  set currentAuthor(CommunityAuthor author) {
    _currentAuthorOverride = author;
    notifyListeners();
  }

  void updateCurrentAuthor(CommunityAuthor author) {
    final bool idChanged = _currentAuthorOverride?.id != author.id;
    if (idChanged ||
        _currentAuthorOverride?.handle != author.handle ||
        _currentAuthorOverride?.displayName != author.displayName) {
      _currentAuthorOverride = author;
      if (idChanged && SupabaseConfig.isConfigured) {
        _loadedAuthorPostIds.clear();
        _authorPostLoads.clear();
        _hasLoadedFollows = false;
        _followedAuthorIds.clear();
        _followerAuthorIds.clear();
        _applyAuthorCountsToCollections(isFollowingOverride: false);
        if (_isLoading) {
          _pendingFollowRefresh = true;
        } else if (_isUuid(author.id)) {
          unawaited(fetchFromSupabase());
        }
      }
      Future<void>.microtask(() {
        if (!_disposed) notifyListeners();
      });
    }
  }

  List<CommunityMuteEntry> loadMutedUsers() {
    final now = DateTime.now();
    return _mutedUsers
        .map((id) => CommunityMuteEntry(userId: id, mutedAt: now))
        .toList();
  }

  List<CommunityBlockEntry> loadBlockedUsers() {
    final now = DateTime.now();
    return _outgoingBlockedUserIds
        .map((id) => CommunityBlockEntry(userId: id, blockedAt: now))
        .toList();
  }

  List<String> get customFeedTabs => List<String>.unmodifiable(_customFeedTabs);
  List<CommunityConversation> get conversations => _conversations;
  List<CommunityConversation> loadConversations() =>
      List<CommunityConversation>.unmodifiable(_conversations);

  /// Writing Desk records the current user may attach to a new post — sourced
  /// from their notes, journal entries and strategies. Sorted most-recent first.
  List<AppWritingPostAttachment> get attachableRecords => _attachableRecords;

  void replaceAttachableRecords(List<AppWritingPostAttachment> records) {
    _attachableRecords = List.of(records);
    notifyListeners();
  }

  void addAttachableRecord(AppWritingPostAttachment record) {
    _attachableRecords = <AppWritingPostAttachment>[
      record,
      ..._attachableRecords.where(
        (existing) =>
            existing.source.kind != record.source.kind ||
            existing.source.id != record.source.id,
      ),
    ];
    notifyListeners();
  }

  List<CommunityComment> commentsForPost(String postId) =>
      _commentsByPost[postId] ?? const <CommunityComment>[];

  @visibleForTesting
  void setCommentsForPost(String postId, List<CommunityComment> comments) {
    _commentsByPost = Map<String, List<CommunityComment>>.from(_commentsByPost)
      ..[postId] = comments;
    notifyListeners();
  }

  List<CommunityPost> postsForAuthor(String authorId) {
    if (authorId.trim().isEmpty) return const <CommunityPost>[];
    final seen = <String>{};
    final all = <CommunityPost>[
      ..._forYouPosts,
      ..._signalPosts,
      ..._followingPosts,
    ];
    final cleanId = authorId.toLowerCase().replaceFirst('@', '').trim();
    return all.where((p) {
      final pAuthorId = p.author.id.toLowerCase().trim();
      final pAuthorHandle = p.author.handle
          .toLowerCase()
          .replaceFirst('@', '')
          .trim();
      final matches = pAuthorId == cleanId || pAuthorHandle == cleanId;
      final isSelf =
          pAuthorId == currentAuthor.id.toLowerCase().trim() ||
          pAuthorHandle ==
              currentAuthor.handle.toLowerCase().replaceFirst('@', '').trim();
      final isApproved = !p.isPendingApproval;
      final isAllowed = isSelf || (p.isPublic && isApproved);
      return matches && isAllowed && seen.add(p.id);
    }).toList();
  }

  /// Returns posts authored by [authorId] that are currently pending moderator approval.
  List<CommunityPost> pendingPostsForAuthor(String authorId) {
    if (authorId.trim().isEmpty) return const <CommunityPost>[];
    final cleanId = authorId.toLowerCase().replaceFirst('@', '').trim();
    final seen = <String>{};
    final all = <CommunityPost>[
      ..._forYouPosts,
      ..._signalPosts,
      ..._followingPosts,
    ];
    return all.where((p) {
      final pAuthorId = p.author.id.toLowerCase().trim();
      final pAuthorHandle = p.author.handle
          .toLowerCase()
          .replaceFirst('@', '')
          .trim();
      final matches = pAuthorId == cleanId || pAuthorHandle == cleanId;
      return matches && p.isPendingApproval && seen.add(p.id);
    }).toList();
  }

  /// Fetches an Instagram-style activity log for a user (likes, comments, reposts, trade shares).
  Future<List<CommunityActivityItem>> fetchUserActivityHistory(
    String userId,
  ) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return const <CommunityActivityItem>[];

    final List<CommunityActivityItem> items = [];
    if (!SupabaseConfig.isConfigured) {
      if (CustomerDataPolicy.allowDemo) {
        for (final p in postsForAuthor(cleanUserId).take(4)) {
          items.add(
            CommunityActivityItem(
              id: 'demo_post_${p.id}',
              type: CommunityActivityType.post,
              title: 'Published a post',
              subtitle: p.body,
              targetPostId: p.id,
              post: p,
              timestamp: p.createdAt,
            ),
          );
        }
      }
      return items;
    }

    try {
      final client = SupabaseConfig.client!;
      final bool viewingOwnActivity = cleanUserId == _resolveUserId();

      // 1. Likes
      try {
        final likesRes = await client
            .from('community_likes')
            .select(
              'post_id, created_at, community_posts(*, profiles!community_posts_author_id_fkey(id, handle, display_name, avatar_url))',
            )
            .eq('user_id', cleanUserId)
            .order('created_at', ascending: false)
            .limit(30);

        for (final item in likesRes as List) {
          final row = item as Map<String, dynamic>;
          final postId = row['post_id']?.toString() ?? '';
          final postData = row['community_posts'] as Map<String, dynamic>?;
          if (postData == null ||
              (!viewingOwnActivity && postData['is_public'] != true)) {
            continue;
          }
          final authorProf = postData['profiles'] as Map<String, dynamic>?;
          final handle =
              (authorProf?['handle'] ?? authorProf?['username']) as String? ??
              'trader';
          final body = postData['body'] as String? ?? 'Community Post';
          final createdAt =
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now();

          final cachedPost = _forYouPosts.cast<CommunityPost?>().firstWhere(
            (p) => p?.id == postId,
            orElse: () => null,
          );

          items.add(
            CommunityActivityItem(
              id: 'like_${postId}_${createdAt.millisecondsSinceEpoch}',
              type: CommunityActivityType.like,
              title: 'Liked @$handle\'s post',
              subtitle: body,
              targetPostId: postId,
              post: cachedPost,
              timestamp: createdAt,
            ),
          );
        }
      } catch (e) {
        debugPrint('[CommunityRepository] fetchUserActivity likes error: $e');
      }

      // 2. Comments
      try {
        final commentsRes = await client
            .from('community_comments')
            .select(
              'id, post_id, body, created_at, community_posts(id, body, author_id, is_public)',
            )
            .eq('author_id', cleanUserId)
            .order('created_at', ascending: false)
            .limit(30);

        for (final item in commentsRes as List) {
          final row = item as Map<String, dynamic>;
          final cId = row['id']?.toString() ?? '';
          final postId = row['post_id']?.toString() ?? '';
          final postData = row['community_posts'] as Map<String, dynamic>?;
          if (postData == null ||
              (!viewingOwnActivity && postData['is_public'] != true)) {
            continue;
          }
          final commentBody = row['body'] as String? ?? '';
          final createdAt =
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now();

          final cachedPost = _forYouPosts.cast<CommunityPost?>().firstWhere(
            (p) => p?.id == postId,
            orElse: () => null,
          );

          items.add(
            CommunityActivityItem(
              id: 'cmt_$cId',
              type: CommunityActivityType.comment,
              title: 'Commented on a post',
              subtitle: commentBody,
              targetPostId: postId,
              post: cachedPost,
              timestamp: createdAt,
            ),
          );
        }
      } catch (e) {
        debugPrint(
          '[CommunityRepository] fetchUserActivity comments error: $e',
        );
      }

      // 3. Reposts
      try {
        final repostsRes = await client
            .from('community_reposts')
            .select(
              'post_id, created_at, community_posts(*, profiles!community_posts_author_id_fkey(id, handle, display_name, avatar_url))',
            )
            .eq('user_id', cleanUserId)
            .order('created_at', ascending: false)
            .limit(30);

        for (final item in repostsRes as List) {
          final row = item as Map<String, dynamic>;
          final postId = row['post_id']?.toString() ?? '';
          final postData = row['community_posts'] as Map<String, dynamic>?;
          if (postData == null ||
              (!viewingOwnActivity && postData['is_public'] != true)) {
            continue;
          }
          final authorProf = postData['profiles'] as Map<String, dynamic>?;
          final handle =
              (authorProf?['handle'] ?? authorProf?['username']) as String? ??
              'trader';
          final body = postData['body'] as String? ?? 'Trade setup';
          final createdAt =
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now();

          final cachedPost = _forYouPosts.cast<CommunityPost?>().firstWhere(
            (p) => p?.id == postId,
            orElse: () => null,
          );

          items.add(
            CommunityActivityItem(
              id: 'repost_${postId}_${createdAt.millisecondsSinceEpoch}',
              type: CommunityActivityType.repost,
              title: 'Reposted @$handle\'s setup',
              subtitle: body,
              targetPostId: postId,
              post: cachedPost,
              timestamp: createdAt,
            ),
          );
        }
      } catch (e) {
        debugPrint('[CommunityRepository] fetchUserActivity reposts error: $e');
      }

      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    } catch (e) {
      debugPrint('[CommunityRepository] fetchUserActivityHistory error: $e');
      return items;
    }
  }

  CommunityAuthor? authorById(String id) {
    if (id == currentAuthor.id) return currentAuthor;
    for (final a in _suggestedTraders) {
      if (a.id == id ||
          a.handle == id ||
          a.handle.replaceFirst('@', '') == id) {
        return a;
      }
    }
    for (final p in _forYouPosts) {
      if (p.author.id == id ||
          p.author.handle == id ||
          p.author.handle.replaceFirst('@', '') == id) {
        return p.author;
      }
    }
    if (!CustomerDataPolicy.allowDemo) return null;
    final all = <CommunityAuthor>[
      _defaultCurrentUser,
      _alexVance,
      _marcoSilva,
      _elenaRostova,
      _priyaSharma,
      _alphajournalWire,
      _arisThorne,
      _rajeshPatel,
      _sarahWong,
    ];
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Mutations & Backend Annotations
  // -------------------------------------------------------------------------

  /// Helper to locate a post across all active collections.
  CommunityPost? findPost(String postId) {
    for (final p in _forYouPosts) {
      if (p.id == postId) return p;
    }
    for (final p in _followingPosts) {
      if (p.id == postId) return p;
    }
    for (final p in _signalPosts) {
      if (p.id == postId) return p;
    }
    for (final p in _bookmarkedPosts) {
      if (p.id == postId) return p;
    }
    return null;
  }

  /// @backend POST /api/v1/community/posts/{postId}/like
  /// Auth: Bearer token required
  /// Returns: { "liked": bool, "likes": int, "user_reaction": String? }
  Future<bool> toggleLike(String postId, {String? reaction}) async {
    final existingPost = findPost(postId);
    final bool wasLiked = existingPost?.liked ?? false;
    final String? currentReaction = existingPost?.userReaction;
    final String targetReaction =
        (reaction != null && reaction.trim().isNotEmpty)
        ? reaction.trim()
        : '👍';

    final bool isLikedNow;
    final String? nextUserReaction;

    if (reaction != null && reaction.trim().isNotEmpty) {
      if (wasLiked && currentReaction == targetReaction) {
        // Tapped same reaction again: toggle off
        isLikedNow = false;
        nextUserReaction = null;
      } else {
        // New reaction or changing from one reaction to another
        isLikedNow = true;
        nextUserReaction = targetReaction;
      }
    } else {
      // Direct Like button tapped
      if (wasLiked) {
        isLikedNow = false;
        nextUserReaction = null;
      } else {
        isLikedNow = true;
        nextUserReaction = '👍';
      }
    }

    _forYouPosts = _toggleLikeInList(
      _forYouPosts,
      postId,
      isLikedNow: isLikedNow,
      userReaction: nextUserReaction,
    );
    _followingPosts = _toggleLikeInList(
      _followingPosts,
      postId,
      isLikedNow: isLikedNow,
      userReaction: nextUserReaction,
    );
    _signalPosts = _toggleLikeInList(
      _signalPosts,
      postId,
      isLikedNow: isLikedNow,
      userReaction: nextUserReaction,
    );
    _bookmarkedPosts = _toggleLikeInList(
      _bookmarkedPosts,
      postId,
      isLikedNow: isLikedNow,
      userReaction: nextUserReaction,
    );
    notifyListeners();

    if (!SupabaseConfig.isConfigured) {
      return true;
    }
    try {
      final client = SupabaseConfig.client!;
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw StateError('Sign in to react.');
      if (isLikedNow) {
        await client.from('community_likes').upsert({
          'post_id': postId,
          'user_id': actor,
          'reaction': nextUserReaction ?? '👍',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await client
            .from('community_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', actor);
      }
      return true;
    } catch (error) {
      if (existingPost != null) {
        List<CommunityPost> restore(List<CommunityPost> posts) => posts
            .map(
              (post) => post.id == postId
                  ? post.copyWith(
                      liked: existingPost.liked,
                      likes: existingPost.likes,
                      userReaction: existingPost.userReaction,
                      reactions: existingPost.reactions,
                    )
                  : post,
            )
            .toList();
        _forYouPosts = restore(_forYouPosts);
        _followingPosts = restore(_followingPosts);
        _signalPosts = restore(_signalPosts);
        _bookmarkedPosts = restore(_bookmarkedPosts);
        if (!_disposed) notifyListeners();
      }
      debugPrint('[CommunityRepository] Reaction could not be saved: $error');
      return false;
    }
  }

  List<CommunityPost> _toggleLikeInList(
    List<CommunityPost> list,
    String id, {
    required bool isLikedNow,
    String? userReaction,
  }) {
    return list.map((p) {
      if (p.id != id) return p;
      final int newLikes = isLikedNow
          ? (p.liked ? p.likes : p.likes + 1)
          : (p.liked ? (p.likes - 1).clamp(0, 999999) : p.likes);

      final updatedRx = List<String>.from(p.reactions);
      if (p.userReaction != null &&
          (userReaction != p.userReaction || !isLikedNow)) {
        if (newLikes <= 0 || (newLikes == 1 && !isLikedNow)) {
          updatedRx.remove(p.userReaction);
        }
      }
      if (isLikedNow &&
          userReaction != null &&
          userReaction.trim().isNotEmpty) {
        final clean = userReaction.trim();
        if (!updatedRx.contains(clean)) {
          updatedRx.insert(0, clean);
        }
      }

      return p.copyWith(
        liked: isLikedNow,
        userReaction: userReaction,
        reactions: updatedRx,
        likes: newLikes,
      );
    }).toList();
  }

  /// @backend POST /api/v1/community/posts/{postId}/repost
  /// Auth: Bearer token required
  /// Returns: { "reposted": bool, "reposts": int }
  void toggleRepost(String postId) {
    final existingPost = findPost(postId);
    final bool wasReposted = existingPost?.reposted ?? false;
    final bool isRepostedNow = !wasReposted;

    _forYouPosts = _toggleRepostInList(
      _forYouPosts,
      postId,
      isRepostedNow: isRepostedNow,
    );
    _followingPosts = _toggleRepostInList(
      _followingPosts,
      postId,
      isRepostedNow: isRepostedNow,
    );
    _signalPosts = _toggleRepostInList(
      _signalPosts,
      postId,
      isRepostedNow: isRepostedNow,
    );
    _bookmarkedPosts = _toggleRepostInList(
      _bookmarkedPosts,
      postId,
      isRepostedNow: isRepostedNow,
    );
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();
      if (targetUserId.isNotEmpty) {
        if (isRepostedNow) {
          unawaited(() async {
            try {
              await client.from('community_reposts').upsert({
                'post_id': postId,
                'user_id': targetUserId,
                'created_at': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              debugPrint('[CommunityRepository] repost insert error: $e');
            }
          }());
        } else {
          unawaited(() async {
            try {
              await client
                  .from('community_reposts')
                  .delete()
                  .eq('post_id', postId)
                  .eq('user_id', targetUserId);
            } catch (e) {
              debugPrint('[CommunityRepository] repost delete error: $e');
            }
          }());
        }
      }
    }
  }

  List<CommunityPost> _toggleRepostInList(
    List<CommunityPost> list,
    String id, {
    required bool isRepostedNow,
  }) {
    return list.map((p) {
      if (p.id != id) return p;
      final int newReposts = isRepostedNow
          ? (p.reposted ? p.reposts : p.reposts + 1)
          : (p.reposted ? (p.reposts - 1).clamp(0, 999999) : p.reposts);
      return p.copyWith(reposted: isRepostedNow, reposts: newReposts);
    }).toList();
  }

  /// @backend POST /api/v1/community/posts/{postId}/bookmark
  /// Auth: Bearer token required
  /// Returns: { "bookmarked": bool }
  void toggleBookmark(String postId) {
    final existingPost = findPost(postId);
    if (existingPost == null) return;
    unawaited(setBookmark(postId, !existingPost.bookmarked));
  }

  /// Persists an exact bookmark state and rolls the optimistic UI back if the
  /// server rejects the write. Shared-record overlays await this method so a
  /// successful Save message always reflects the real bookmark row.
  Future<void> setBookmark(String postId, bool isBookmarked) async {
    final existingPost = findPost(postId);
    if (existingPost == null) {
      throw StateError('This post is no longer available.');
    }
    if (existingPost.bookmarked == isBookmarked) return;

    _setBookmarkLocally(postId, isBookmarked);

    if (!SupabaseConfig.isConfigured || !_isUuid(postId)) return;
    final client = SupabaseConfig.client!;
    final targetUserId = _resolveUserId();
    if (targetUserId.isEmpty) {
      _setBookmarkLocally(postId, existingPost.bookmarked);
      throw StateError('Sign in to save Community bookmarks.');
    }

    try {
      if (isBookmarked) {
        await client.from('community_bookmarks').upsert({
          'post_id': postId,
          'user_id': targetUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await client
            .from('community_bookmarks')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', targetUserId);
      }
    } catch (error, stackTrace) {
      _setBookmarkLocally(postId, existingPost.bookmarked);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _setBookmarkLocally(String postId, bool isBookmarked) {
    _forYouPosts = _forYouPosts
        .map((p) => p.id == postId ? p.copyWith(bookmarked: isBookmarked) : p)
        .toList();
    _followingPosts = _followingPosts
        .map((p) => p.id == postId ? p.copyWith(bookmarked: isBookmarked) : p)
        .toList();
    _signalPosts = _signalPosts
        .map((p) => p.id == postId ? p.copyWith(bookmarked: isBookmarked) : p)
        .toList();
    _bookmarkedPosts = _bookmarkedPosts
        .map((p) => p.id == postId ? p.copyWith(bookmarked: isBookmarked) : p)
        .toList();
    _rebuildBookmarks();
    notifyListeners();
  }

  void _rebuildBookmarks() {
    final all = <CommunityPost>[
      ..._forYouPosts,
      ..._followingPosts,
      ..._signalPosts,
      ..._bookmarkedPosts,
    ];
    final seen = <String>{};
    _bookmarkedPosts = all.where((p) => p.bookmarked && seen.add(p.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int todayPostCountForAuthor(String authorId) {
    final now = DateTime.now();
    return _forYouPosts.where((p) {
      if (p.author.id != authorId) return false;
      final local = p.createdAt.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }).length;
  }

  int todayCommentCountForAuthor(String authorId) {
    final now = DateTime.now();
    int count = 0;
    void scan(List<CommunityComment> list) {
      for (final c in list) {
        final local = c.createdAt.toLocal();
        if (c.author.id == authorId &&
            local.year == now.year &&
            local.month == now.month &&
            local.day == now.day) {
          count++;
        }
        if (c.replies.isNotEmpty) scan(c.replies);
      }
    }

    for (final list in _commentsByPost.values) {
      scan(list);
    }
    return count;
  }

  /// @backend POST /api/v1/community/posts/{postId}/comments
  /// Body: { "body": String, "parent_comment_id": String?, "sentiment": String? }
  /// Returns: CommunityComment JSON
  Future<void> addComment(
    String postId,
    String body, {
    CommunityAuthor? author,
    String? parentId,
    String? sentiment,
  }) async {
    if (body.trim().isEmpty) throw ArgumentError('Write a comment first.');
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser == null) {
      throw StateError('Sign in to comment.');
    }
    final a = author ?? currentAuthor;
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser != null) {
      await CustomerLimitations.assertCanCreateCommunityComment(
        todayCommentCount: todayCommentCountForAuthor(a.id),
      );
    } else {
      CustomerLimitations.assertCanCreateCommunityCommentSync(
        todayCommentCountForAuthor(a.id),
      );
    }
    final commentId = SupabaseConfig.isConfigured
        ? const Uuid().v4()
        : 'cmt_${DateTime.now().millisecondsSinceEpoch}';
    final comment = CommunityComment(
      id: commentId,
      postId: postId,
      author: a,
      body: body.trim(),
      createdAt: DateTime.now(),
      sentiment: sentiment,
      parentCommentId: parentId,
    );
    final existing = List<CommunityComment>.from(_commentsByPost[postId] ?? []);
    if (parentId != null) {
      bool attached = false;
      CommunityComment? attachReply(CommunityComment c) {
        if (c.id == parentId) {
          attached = true;
          return c.copyWith(replies: [...c.replies, comment]);
        }
        if (c.replies.isNotEmpty) {
          final updatedReplies = <CommunityComment>[];
          bool anyFound = false;
          for (final r in c.replies) {
            final updated = attachReply(r);
            if (updated != null) {
              updatedReplies.add(updated);
              anyFound = true;
            } else {
              updatedReplies.add(r);
            }
          }
          if (anyFound) {
            return c.copyWith(replies: updatedReplies);
          }
        }
        return null;
      }

      for (int i = 0; i < existing.length; i++) {
        final updated = attachReply(existing[i]);
        if (updated != null) {
          existing[i] = updated;
          break;
        }
      }

      if (!attached) {
        existing.insert(0, comment);
      }
    } else {
      existing.insert(0, comment);
    }
    _commentsByPost = Map<String, List<CommunityComment>>.from(_commentsByPost)
      ..[postId] = existing;
    _forYouPosts = _incrementComments(_forYouPosts, postId);
    _followingPosts = _incrementComments(_followingPosts, postId);
    _signalPosts = _incrementComments(_signalPosts, postId);
    notifyListeners();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final actorId = client.auth.currentUser?.id;
        if (actorId != null) {
          try {
            await client.from('community_comments').insert({
              'id': commentId,
              'post_id': postId,
              'author_id': actorId,
              'body': body.trim(),
              'moderation_status': 'approved',
              if (parentId != null && _isUuid(parentId)) 'parent_id': parentId,
            });
          } on PostgrestException catch (error) {
            if (error.code != '42703' && error.code != 'PGRST204') rethrow;
            await client.from('community_comments').insert({
              'id': commentId,
              'post_id': postId,
              'author_id': actorId,
              'body': body.trim(),
              if (parentId != null && _isUuid(parentId)) 'parent_id': parentId,
            });
          }
        }
      } catch (e) {
        _commentsByPost[postId] = _removeCommentRecursive(
          _commentsByPost[postId] ?? [],
          commentId,
          <bool>[false],
        );
        _forYouPosts = _decrementCommentsBy(_forYouPosts, postId, 1);
        _followingPosts = _decrementCommentsBy(_followingPosts, postId, 1);
        _signalPosts = _decrementCommentsBy(_signalPosts, postId, 1);
        notifyListeners();
        rethrow;
      }
    }
  }

  List<CommunityPost> _incrementComments(
    List<CommunityPost> list,
    String postId,
  ) => list
      .map((p) => p.id == postId ? p.copyWith(comments: p.comments + 1) : p)
      .toList();

  /// @backend POST /api/v1/community/comments/{commentId}/like
  /// Returns: { "liked": bool, "likes": int, "user_reaction": String? }
  Future<bool> likeComment(
    String postId,
    String commentId, {
    String? reaction,
  }) async {
    CommunityComment? original;
    final list = List<CommunityComment>.from(_commentsByPost[postId] ?? []);

    CommunityComment? updateRecursively(CommunityComment c) {
      if (c.id == commentId) {
        original = c;
        final bool wasLiked = c.liked;
        final String? currentReaction = c.userReaction;

        if (reaction != null && reaction.trim().isNotEmpty) {
          final targetReaction = reaction.trim();
          if (wasLiked && currentReaction == targetReaction) {
            // Tapped same reaction again: toggle off
            final updatedRx = List<String>.from(c.reactions)
              ..remove(targetReaction);
            return c.copyWith(
              liked: false,
              likes: (c.likes - 1).clamp(0, 99999),
              userReaction: null,
              reactions: updatedRx,
            );
          } else {
            // New reaction or changing from one reaction to another
            final updatedRx = List<String>.from(c.reactions);
            if (currentReaction != null) {
              updatedRx.remove(currentReaction);
            }
            if (!updatedRx.contains(targetReaction)) {
              updatedRx.add(targetReaction);
            }
            return c.copyWith(
              liked: true,
              likes: wasLiked ? c.likes : c.likes + 1,
              userReaction: targetReaction,
              reactions: updatedRx,
            );
          }
        } else {
          // Direct Like button tapped
          if (wasLiked) {
            final updatedRx = List<String>.from(c.reactions);
            if (currentReaction != null) {
              updatedRx.remove(currentReaction);
            }
            return c.copyWith(
              liked: false,
              likes: (c.likes - 1).clamp(0, 99999),
              userReaction: null,
              reactions: updatedRx,
            );
          } else {
            final updatedRx = List<String>.from(c.reactions);
            if (!updatedRx.contains('👍')) {
              updatedRx.add('👍');
            }
            return c.copyWith(
              liked: true,
              likes: c.likes + 1,
              userReaction: '👍',
              reactions: updatedRx,
            );
          }
        }
      }

      if (c.replies.isNotEmpty) {
        bool changed = false;
        final updatedReplies = <CommunityComment>[];
        for (final r in c.replies) {
          final updated = updateRecursively(r);
          if (updated != null) {
            updatedReplies.add(updated);
            changed = true;
          } else {
            updatedReplies.add(r);
          }
        }
        if (changed) {
          return c.copyWith(replies: updatedReplies);
        }
      }

      return null;
    }

    bool modified = false;
    for (int i = 0; i < list.length; i++) {
      final updated = updateRecursively(list[i]);
      if (updated != null) {
        list[i] = updated;
        modified = true;
        break;
      }
    }

    if (modified) {
      _commentsByPost = Map<String, List<CommunityComment>>.from(
        _commentsByPost,
      )..[postId] = list;
      notifyListeners();

      CommunityComment? findComment(List<CommunityComment> items) {
        for (final item in items) {
          if (item.id == commentId) return item;
          final found = findComment(item.replies);
          if (found != null) return found;
        }
        return null;
      }

      final c = findComment(list);
      final targetUserId = _resolveUserId();

      if (c != null) {
        try {
          if (SupabaseConfig.isConfigured) {
            final client = SupabaseConfig.client!;
            final actor = client.auth.currentUser?.id;
            if (actor == null) throw StateError('Sign in to react.');
            if (c.liked) {
              await client.from('community_comment_likes').upsert({
                'comment_id': commentId,
                'user_id': actor,
                'reaction': c.userReaction ?? '👍',
                'created_at': DateTime.now().toIso8601String(),
              });
            } else {
              await client
                  .from('community_comment_likes')
                  .delete()
                  .eq('comment_id', commentId)
                  .eq('user_id', actor);
            }
          }
          await _saveLocalCommentReaction(
            targetUserId,
            commentId,
            c.liked ? (c.userReaction ?? '👍') : null,
          );
          return true;
        } catch (error) {
          CommunityComment restore(CommunityComment item) {
            if (item.id == commentId && original != null) {
              return original!.copyWith(replies: item.replies);
            }
            return item.copyWith(replies: item.replies.map(restore).toList());
          }

          _commentsByPost[postId] = (_commentsByPost[postId] ?? [])
              .map(restore)
              .toList();
          if (!_disposed) notifyListeners();
          debugPrint(
            '[CommunityRepository] Comment reaction could not be saved: $error',
          );
          return false;
        }
      }
    }
    return false;
  }

  /// @backend POST /api/v1/community/users/{traderId}/follow
  /// Returns: { "is_following": bool, "followers": int }
  Future<bool> toggleFollow(String traderId) async {
    if (traderId.isEmpty ||
        traderId == currentAuthor.id ||
        _blockedUsers.contains(traderId) ||
        !_pendingFollowWrites.add(traderId)) {
      return false;
    }
    final wasFollowing = isFollowing(traderId);
    final originalFollowers =
        _authorFollowersCount[traderId] ?? authorById(traderId)?.followers ?? 0;
    var appliedDelta = 0;
    void apply(bool following) {
      final currentFollowing = followingCount;
      if (following) {
        _followedAuthorIds.add(traderId);
      } else {
        _followedAuthorIds.remove(traderId);
      }
      final delta = following == wasFollowing ? 0 : (following ? 1 : -1);
      _authorFollowersCount[traderId] = math.max(0, originalFollowers + delta);
      _authorFollowingCount[currentAuthor.id] = math.max(
        0,
        currentFollowing + delta - appliedDelta,
      );
      appliedDelta = delta;
      _applyAuthorCountsToCollections(
        targetAuthorId: traderId,
        isFollowingOverride: following,
      );
      _notifications = _notifications
          .map(
            (n) => n.actor?.id == traderId
                ? n.copyWith(isFollowingBack: following)
                : n,
          )
          .toList();
      _followingPosts = _forYouPosts
          .where(
            (p) =>
                isFollowing(p.author.id) ||
                (followedReactionsForPost(p.id).isNotEmpty ||
                    followedRepostsForPost(p.id).isNotEmpty),
          )
          .toList();
      if (!_disposed) notifyListeners();
    }

    apply(!wasFollowing);
    if (!SupabaseConfig.isConfigured) {
      _pendingFollowWrites.remove(traderId);
      return true;
    }
    try {
      final client = SupabaseConfig.client!;
      final actor = client.auth.currentUser?.id;
      if (actor == null) throw StateError('Sign in to follow traders.');
      if (wasFollowing) {
        await client
            .from('community_follows')
            .delete()
            .eq('follower_id', actor)
            .eq('following_id', traderId);
      } else {
        await client.from('community_follows').upsert({
          'follower_id': actor,
          'following_id': traderId,
        });
      }
      await _fetchNetworkActivity(_forYouPosts);
      if (!_disposed) {
        _followingPosts = _forYouPosts
            .where(
              (p) =>
                  isFollowing(p.author.id) ||
                  (followedReactionsForPost(p.id).isNotEmpty ||
                      followedRepostsForPost(p.id).isNotEmpty),
            )
            .toList();
        notifyListeners();
      }
      return true;
    } catch (error) {
      apply(wasFollowing);
      debugPrint('[CommunityRepository] Follow could not be saved: $error');
      return false;
    } finally {
      _pendingFollowWrites.remove(traderId);
    }
  }

  /// @backend POST /api/v1/community/posts
  /// Body: Post create schema
  /// Returns: CommunityPost JSON
  Future<void> createPost({
    required String body,
    List<String> tickers = const <String>[],
    List<String> tags = const <String>[],
    CommunityTradeSetup? tradeSetup,
    String? imageUrl,
    List<String> imageUrls = const <String>[],
    String? videoUrl,
    AppWritingPostAttachment? attachment,
    CommunityPoll? poll,
    CommunityPost? quoted,
    CommunitySentiment? sentiment,
    CommunityReplyAudience replyAudience = CommunityReplyAudience.everyone,
    bool isDeskAlert = false,
    DateTime? scheduledFor,
    required CommunityAuthor author,
  }) async {
    RecordAccess.requireService();
    if (SupabaseConfig.isConfigured &&
        SupabaseConfig.client?.auth.currentUser != null) {
      await CustomerLimitations.assertCanCreateCommunityPost(
        todayPostCount: todayPostCountForAuthor(author.id),
      );
    } else {
      CustomerLimitations.assertCanCreateCommunityPostSync(
        todayPostCountForAuthor(author.id),
      );
    }
    final newId = SupabaseConfig.isConfigured
        ? const Uuid().v4()
        : 'post_${DateTime.now().millisecondsSinceEpoch}';
    final post = CommunityPost(
      id: newId,
      author: author,
      body: body,
      createdAt: DateTime.now(),
      tickers: tickers,
      tags: tags,
      tradeSetup: tradeSetup,
      imageUrl: imageUrl,
      imageUrls: imageUrls.isNotEmpty
          ? imageUrls
          : (imageUrl != null ? <String>[imageUrl] : const <String>[]),
      videoUrl: videoUrl,
      attachment: attachment,
      poll: poll,
      quoted: quoted,
      sentiment: sentiment,
      replyAudience: replyAudience,
      isDeskAlert: isDeskAlert,
      scheduledFor: scheduledFor,
      moderationStatus: 'approved',
      views: 1,
    );
    _forYouPosts = <CommunityPost>[post, ..._forYouPosts];
    _followingPosts = <CommunityPost>[post, ..._followingPosts];
    if (tradeSetup != null) {
      _signalPosts = <CommunityPost>[post, ..._signalPosts];
    }
    notifyListeners();

    if (SupabaseConfig.isConfigured) {
      try {
        await CommunityPostWriter(
          SupabaseConfig.client!,
          SupabaseConfig.client!.auth.currentUser?.id ?? '',
        ).create(post);
      } catch (e) {
        _forYouPosts = _forYouPosts.where((item) => item.id != newId).toList();
        _followingPosts = _followingPosts
            .where((item) => item.id != newId)
            .toList();
        _signalPosts = _signalPosts.where((item) => item.id != newId).toList();
        notifyListeners();
        debugPrint('[CommunityRepository] createPost Supabase error: $e');
        rethrow;
      }
    } else if (attachment != null) {
      try {
        await WorkspaceAttachmentService().setVisibility(
          attachment.source,
          true,
        );
      } catch (_) {}
    }

    if (attachment != null && !SupabaseConfig.isConfigured) {
      WorkspacePostService.instance.linkRecord(
        kind: attachment.source.kind,
        recordId: attachment.source.id,
        postId: post.id,
        postTitle: body.trim().isNotEmpty
            ? body.trim()
            : attachment.source.title,
        authorName: author.displayName,
        authorHandle: author.displayHandle,
      );
    }

    final Set<String> linkedTickers = <String>{
      ...tickers,
      if (tradeSetup?.ticker != null && tradeSetup!.ticker.isNotEmpty)
        tradeSetup.ticker,
      ...EntityTickerLinksRepository.extractTickers(body),
    };
    if (linkedTickers.isNotEmpty) {
      unawaited(
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'community_post',
          entityId: post.id,
          tickers: linkedTickers,
          contextSource: tradeSetup != null ? 'setup' : 'inline',
        ),
      );
    }
  }

  /// Uploads an image or file attachment to the `community-attachments` Supabase storage bucket
  /// and returns its public URL.
  Future<String> uploadAttachment({
    required String postId,
    File? file,
    Uint8List? bytes,
    String? filename,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final rawBytes =
            bytes ?? (file != null ? await file.readAsBytes() : null);
        if (rawBytes == null || rawBytes.isEmpty) {
          throw ArgumentError('No attachment payload provided for upload.');
        }

        final originalName =
            filename ??
            (file != null ? file.path.split('/').last : 'attachment.png');
        final compressed =
            await AttachmentCompressionService.compressAttachment(
              bytes: rawBytes,
              filename: originalName,
            );

        final ext = compressed.filename.contains('.')
            ? compressed.filename.split('.').last
            : 'webp';
        final cleanName = '${sha256.convert(compressed.bytes)}.$ext';
        final actor = client.auth.currentUser?.id;
        if (actor == null) throw StateError('Sign in to upload an attachment.');
        final storagePath = '$actor/$postId/$cleanName';

        try {
          await client.storage
              .from('community-attachments')
              .uploadBinary(
                storagePath,
                compressed.bytes,
                fileOptions: FileOptions(
                  contentType: compressed.mimeType,
                  // SHA-256 content-addressed object is immutable -> maximize Smart CDN Cached Egress.
                  cacheControl: SupabaseStorageEgress
                      .communityAttachments
                      .uploadCacheControl,
                  upsert: false,
                ),
              );
        } on StorageException catch (error) {
          // Reusing this batch on retry reuses the exact same immutable object.
          if (error.statusCode != '409' && error.error != 'Duplicate') rethrow;
        }
        return SupabaseStorageEgress.resolvePublicCdnUrl(
          client: client,
          bucket: SupabaseStorageEgress.communityAttachments.bucketId,
          ref: storagePath,
        );
      } catch (e) {
        debugPrint('[CommunityRepository] uploadAttachment error: $e');
        rethrow;
      }
    }
    RecordAccess.requireService();
    return file?.path ?? filename ?? '';
  }

  /// Removes this user's staged uploads only when no post references them.
  Future<void> discardUnusedAttachments(Iterable<String> urls) async {
    final client = SupabaseConfig.client;
    final actor = client?.auth.currentUser?.id;
    if (client == null || actor == null || urls.isEmpty) return;
    final bucket = client.storage.from('community-attachments');
    final prefix = bucket.getPublicUrl('$actor/');
    final owned = urls.where((url) => url.startsWith(prefix)).toSet();
    if (owned.isEmpty) return;
    try {
      final linked = await client
          .from('community_post_attachments')
          .select('url')
          .inFilter('url', owned.toList());
      final used = linked.map((row) => row['url']).toSet();
      final paths = [
        for (final url in owned.difference(used))
          '$actor/${url.substring(prefix.length)}',
      ];
      if (paths.isNotEmpty) await bucket.remove(paths);
    } catch (error) {
      debugPrint(
        '[CommunityRepository] Draft attachment cleanup failed: $error',
      );
    }
  }

  /// Resolves an attachment reference or storage path to a usable URL.
  Future<String> resolveAttachmentUrl(String ref) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        return SupabaseStorageEgress.resolvePublicCdnUrl(
          client: client,
          bucket: SupabaseStorageEgress.communityAttachments.bucketId,
          ref: ref,
        );
      } catch (e) {
        debugPrint('[CommunityRepository] resolveAttachmentUrl error: $e');
      }
    }
    return ref;
  }

  /// @backend DELETE /api/v1/community/posts/{postId}
  /// Returns: { "success": true }
  Future<void> deletePost(String postId) async {
    RecordAccess.requireService();
    final post = loadPostById(postId);
    final actor =
        SupabaseConfig.client?.auth.currentUser?.id ?? currentAuthor.id;
    if (post != null && post.author.id != actor) {
      throw StateError('Only the author can delete this post.');
    }
    final urlsToDiscard = <String>{
      if (post != null) ...post.effectiveImageUrls,
    };
    if (SupabaseConfig.isConfigured) {
      if (_isUuid(postId)) {
        try {
          final rows = await SupabaseConfig.client!
              .from('community_post_attachments')
              .select('url, ref_id')
              .eq('post_id', postId)
              .eq('kind', 'image');
          for (final row in rows) {
            final url = (row['url'] ?? row['ref_id'])?.toString();
            if (url != null && url.isNotEmpty) {
              urlsToDiscard.add(url);
            }
          }
        } catch (_) {}
      }
      await OwnedRecordWriter().delete(
        'community_posts',
        postId,
        ownerColumn: 'author_id',
      );
    } else if (post == null) {
      throw StateError('This post is no longer available.');
    }
    if (urlsToDiscard.isNotEmpty) {
      await discardUnusedAttachments(urlsToDiscard);
    }
    _forYouPosts.removeWhere((p) => p.id == postId);
    _followingPosts.removeWhere((p) => p.id == postId);
    _signalPosts.removeWhere((p) => p.id == postId);
    _bookmarkedPosts.removeWhere((p) => p.id == postId);
    notifyListeners();
    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'community_post',
        entityId: postId,
      ),
    );
  }

  /// @backend DELETE /api/v1/community/posts/{postId}/comments/{commentId}
  /// Returns: { "success": true }
  Future<void> deleteComment(String postId, String commentId) async {
    RecordAccess.requireService();
    final actor =
        SupabaseConfig.client?.auth.currentUser?.id ?? currentAuthor.id;
    final existing = _commentsByPost[postId];

    // Recursively locate the comment anywhere in the tree (top-level or reply)
    final comment = existing != null
        ? _findCommentRecursive(existing, commentId)
        : null;

    if (comment != null && comment.author.id != actor) {
      throw StateError('Only the author can delete this comment.');
    }

    if (SupabaseConfig.isConfigured) {
      await OwnedRecordWriter().delete(
        'community_comments',
        commentId,
        ownerColumn: 'author_id',
      );
    } else if (comment == null) {
      throw StateError('This comment is no longer available.');
    }

    if (existing != null && comment != null) {
      final removed = [false];
      final updated = _removeCommentRecursive(existing, commentId, removed);
      if (removed[0]) {
        final removedCount = _countCommentAndDescendants(comment);
        _commentsByPost = Map<String, List<CommunityComment>>.from(
          _commentsByPost,
        )..[postId] = updated;
        _forYouPosts = _decrementCommentsBy(_forYouPosts, postId, removedCount);
        _followingPosts = _decrementCommentsBy(
          _followingPosts,
          postId,
          removedCount,
        );
        _signalPosts = _decrementCommentsBy(_signalPosts, postId, removedCount);
        _bookmarkedPosts = _decrementCommentsBy(
          _bookmarkedPosts,
          postId,
          removedCount,
        );
        notifyListeners();
      }
    }
  }

  static CommunityComment? _findCommentRecursive(
    List<CommunityComment> list,
    String targetId,
  ) {
    for (final c in list) {
      if (c.id == targetId) return c;
      final found = _findCommentRecursive(c.replies, targetId);
      if (found != null) return found;
    }
    return null;
  }

  static List<CommunityComment> _removeCommentRecursive(
    List<CommunityComment> list,
    String targetId,
    List<bool> removed,
  ) {
    final result = <CommunityComment>[];
    for (final c in list) {
      if (c.id == targetId) {
        removed[0] = true;
        continue;
      }
      final updatedReplies = _removeCommentRecursive(
        c.replies,
        targetId,
        removed,
      );
      result.add(c.copyWith(replies: updatedReplies));
    }
    return result;
  }

  static int _countCommentAndDescendants(CommunityComment comment) {
    var count = 1;
    for (final r in comment.replies) {
      count += _countCommentAndDescendants(r);
    }
    return count;
  }

  List<CommunityPost> _decrementCommentsBy(
    List<CommunityPost> list,
    String postId,
    int count,
  ) => list
      .map(
        (p) => p.id == postId
            ? p.copyWith(
                comments: (p.comments >= count ? p.comments - count : 0),
              )
            : p,
      )
      .toList();

  /// @backend PATCH /api/v1/community/posts/{postId}
  /// Body: { "body": String, ... }
  /// Returns: CommunityPost JSON
  Future<void> editPost(
    String postId,
    String newBody, {
    List<String>? tickers,
    List<String>? tags,
    CommunityTradeSetup? tradeSetup,
    bool clearTradeSetup = false,
    AppWritingPostAttachment? attachment,
    bool clearAttachment = false,
    CommunityPoll? poll,
    bool clearPoll = false,
    CommunitySentiment? sentiment,
    bool clearSentiment = false,
    CommunityPost? quoted,
    bool clearQuoted = false,
    String? videoUrl,
    bool clearVideoUrl = false,
    CommunityReplyAudience? replyAudience,
    List<String>? imageUrls,
  }) async {
    RecordAccess.requireService();
    final existing = loadPostById(postId);
    if (existing == null) throw StateError('This post is no longer available.');
    final actor =
        SupabaseConfig.client?.auth.currentUser?.id ?? currentAuthor.id;
    if (existing.author.id != actor) {
      throw StateError('Only the author can edit this post.');
    }
    final CommunityPost? effectiveQuoted = clearQuoted
        ? null
        : (quoted ?? existing.quoted);
    final String? effectiveVideoUrl = clearVideoUrl
        ? null
        : (videoUrl ?? existing.videoUrl);
    final StringBuffer bodyBuf = StringBuffer(newBody);
    if (effectiveVideoUrl != null && effectiveVideoUrl.trim().isNotEmpty) {
      bodyBuf.write('\n\nVideo: ${effectiveVideoUrl.trim()}');
    }
    if (effectiveQuoted != null) {
      bodyBuf.write(
        '\n\nQuoted post: /community?post=${Uri.encodeQueryComponent(effectiveQuoted.id)}',
      );
    }
    final String persistedBody = bodyBuf.toString();
    final removedAttachmentUrls = <String>{
      if (imageUrls != null)
        ...existing.effectiveImageUrls.toSet().difference(imageUrls.toSet()),
    };
    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      await (() async {
        try {
          final client = SupabaseConfig.client!;
          await client
              .from('community_posts')
              .update({
                'body': persistedBody,
                'tickers': ?tickers,
                'tags': ?tags,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', postId)
              .eq('author_id', actor)
              .select('id')
              .single();

          if (tradeSetup != null) {
            final entry = double.tryParse(tradeSetup.entry);
            if (entry == null || !entry.isFinite || entry <= 0) {
              throw StateError('Enter a valid entry price.');
            }
            await client.from('community_post_trade_setups').upsert({
              'post_id': postId,
              'ticker': tradeSetup.ticker,
              'side': tradeSetup.side.toLowerCase(),
              'entry': entry,
              'stop_loss': double.tryParse(tradeSetup.stopLoss ?? ''),
              'target1': double.tryParse(tradeSetup.target ?? ''),
            }, onConflict: 'post_id');
          } else if (clearTradeSetup) {
            await client
                .from('community_post_trade_setups')
                .delete()
                .eq('post_id', postId);
          }
          if (imageUrls != null) {
            final rows = await client
                .from('community_post_attachments')
                .select('id, url, ref_id')
                .eq('post_id', postId)
                .eq('kind', 'image');
            final currentUrls = rows
                .map((row) => row['url'] ?? row['ref_id'])
                .toSet();
            final wanted = imageUrls.toSet();
            final added = wanted.difference(currentUrls);
            if (added.isNotEmpty) {
              await client.from('community_post_attachments').insert([
                for (final url in added)
                  {
                    'post_id': postId,
                    'kind': 'image',
                    'ref_id': url,
                    'title': 'Chart Image',
                    'url': url,
                  },
              ]);
            }
            final removedIds = <String>[];
            for (final row in rows) {
              final rowUrl = (row['url'] ?? row['ref_id'])?.toString();
              if (!wanted.contains(rowUrl)) {
                removedIds.add(row['id'] as String);
                if (rowUrl != null && rowUrl.isNotEmpty) {
                  removedAttachmentUrls.add(rowUrl);
                }
              }
            }
            if (removedIds.isNotEmpty) {
              await client
                  .from('community_post_attachments')
                  .delete()
                  .eq('post_id', postId)
                  .eq('kind', 'image')
                  .inFilter('id', removedIds);
            }
          }
          if (attachment != null) {
            await client
                .from('community_post_attachments')
                .delete()
                .eq('post_id', postId)
                .inFilter('kind', ['note', 'journal', 'strategy']);
            await client.from('community_post_attachments').insert({
              'post_id': postId,
              'kind': attachment.source.kind.name,
              'ref_id': attachment.source.id,
              'title': attachment.source.title,
              'url': attachment.source.subtitle,
            });
          } else if (clearAttachment) {
            await client
                .from('community_post_attachments')
                .delete()
                .eq('post_id', postId)
                .inFilter('kind', ['note', 'journal', 'strategy']);
          }
          if (tradeSetup != null || clearTradeSetup) {
            final existing = await client
                .from('community_post_attachments')
                .select('id')
                .eq('post_id', postId)
                .eq('kind', 'chart_candles');
            if (tradeSetup != null && tradeSetup.candles.isNotEmpty) {
              final row = CommunityPostWriter.candleAttachment(
                postId,
                tradeSetup,
              );
              if (existing.isEmpty) {
                await client.from('community_post_attachments').insert(row);
              } else {
                await client
                    .from('community_post_attachments')
                    .update(row)
                    .eq('id', existing.first['id'])
                    .eq('post_id', postId);
                if (existing.length > 1) {
                  await client
                      .from('community_post_attachments')
                      .delete()
                      .eq('post_id', postId)
                      .eq('kind', 'chart_candles')
                      .inFilter(
                        'id',
                        existing.skip(1).map((row) => row['id']).toList(),
                      );
                }
              }
            } else {
              await client
                  .from('community_post_attachments')
                  .delete()
                  .eq('post_id', postId)
                  .eq('kind', 'chart_candles');
            }
          }
        } catch (e) {
          debugPrint('[CommunityRepository] editPost Supabase error: $e');
          rethrow;
        }
      }());
    }
    if (removedAttachmentUrls.isNotEmpty) {
      await discardUnusedAttachments(removedAttachmentUrls);
    }

    _forYouPosts = _editPostInList(
      _forYouPosts,
      postId,
      newBody,
      tickers: tickers,
      tags: tags,
      tradeSetup: tradeSetup,
      clearTradeSetup: clearTradeSetup,
      attachment: attachment,
      clearAttachment: clearAttachment,
      poll: poll,
      clearPoll: clearPoll,
      sentiment: sentiment,
      clearSentiment: clearSentiment,
      quoted: quoted,
      clearQuoted: clearQuoted,
      videoUrl: videoUrl,
      clearVideoUrl: clearVideoUrl,
      replyAudience: replyAudience,
      imageUrls: imageUrls,
    );
    _followingPosts = _editPostInList(
      _followingPosts,
      postId,
      newBody,
      tickers: tickers,
      tags: tags,
      tradeSetup: tradeSetup,
      clearTradeSetup: clearTradeSetup,
      attachment: attachment,
      clearAttachment: clearAttachment,
      poll: poll,
      clearPoll: clearPoll,
      sentiment: sentiment,
      clearSentiment: clearSentiment,
      quoted: quoted,
      clearQuoted: clearQuoted,
      videoUrl: videoUrl,
      clearVideoUrl: clearVideoUrl,
      replyAudience: replyAudience,
      imageUrls: imageUrls,
    );
    _signalPosts = _editPostInList(
      _signalPosts,
      postId,
      newBody,
      tickers: tickers,
      tags: tags,
      tradeSetup: tradeSetup,
      clearTradeSetup: clearTradeSetup,
      attachment: attachment,
      clearAttachment: clearAttachment,
      poll: poll,
      clearPoll: clearPoll,
      sentiment: sentiment,
      clearSentiment: clearSentiment,
      quoted: quoted,
      clearQuoted: clearQuoted,
      videoUrl: videoUrl,
      clearVideoUrl: clearVideoUrl,
      replyAudience: replyAudience,
      imageUrls: imageUrls,
    );
    notifyListeners();

    final Set<String> linkedTickers = <String>{
      ...?tickers,
      if (tradeSetup?.ticker != null && tradeSetup!.ticker.isNotEmpty)
        tradeSetup.ticker,
      ...EntityTickerLinksRepository.extractTickers(newBody),
    };
    if (linkedTickers.isNotEmpty) {
      unawaited(
        EntityTickerLinksRepository.instance.recordLinks(
          entityType: 'community_post',
          entityId: postId,
          tickers: linkedTickers,
          contextSource: tradeSetup != null ? 'setup' : 'inline',
        ),
      );
    } else {
      unawaited(
        EntityTickerLinksRepository.instance.removeLinks(
          entityType: 'community_post',
          entityId: postId,
        ),
      );
    }
  }

  Future<CommunityPost?> setPostVisibility(String postId, bool isPublic) async {
    RecordAccess.requireService();
    final existing = loadPostById(postId);
    if (existing == null) throw StateError('This post is no longer available.');
    final actor =
        SupabaseConfig.client?.auth.currentUser?.id ?? currentAuthor.id;
    if (existing.author.id != actor) {
      throw StateError('Only the author can change post visibility.');
    }
    if (SupabaseConfig.isConfigured) {
      await OwnedRecordWriter().update('community_posts', postId, {
        'is_public': isPublic,
        'visibility': isPublic ? 'public' : 'private',
      }, ownerColumn: 'author_id');
    }
    final updated = existing.copyWith(isPublic: isPublic);
    CommunityPost replace(CommunityPost post) =>
        post.id == postId ? updated : post;
    _forYouPosts = _forYouPosts.map(replace).toList();
    _followingPosts = _followingPosts.map(replace).toList();
    _signalPosts = _signalPosts.map(replace).toList();
    _bookmarkedPosts = _bookmarkedPosts.map(replace).toList();
    notifyListeners();
    return updated;
  }

  List<CommunityPost> _editPostInList(
    List<CommunityPost> list,
    String id,
    String newBody, {
    List<String>? tickers,
    List<String>? tags,
    CommunityTradeSetup? tradeSetup,
    bool clearTradeSetup = false,
    AppWritingPostAttachment? attachment,
    bool clearAttachment = false,
    CommunityPoll? poll,
    bool clearPoll = false,
    CommunitySentiment? sentiment,
    bool clearSentiment = false,
    CommunityPost? quoted,
    bool clearQuoted = false,
    String? videoUrl,
    bool clearVideoUrl = false,
    CommunityReplyAudience? replyAudience,
    List<String>? imageUrls,
  }) {
    return list.map((p) {
      if (p.id != id) return p;
      return p.copyWith(
        body: newBody,
        tickers: tickers,
        tags: tags,
        tradeSetup: tradeSetup,
        clearTradeSetup: clearTradeSetup,
        attachment: attachment,
        clearAttachment: clearAttachment,
        poll: poll,
        clearPoll: clearPoll,
        sentiment: sentiment,
        clearSentiment: clearSentiment,
        quoted: quoted,
        clearQuoted: clearQuoted,
        videoUrl: videoUrl,
        clearVideoUrl: clearVideoUrl,
        replyAudience: replyAudience,
        imageUrls: imageUrls,
        isEdited: true,
        editedAt: DateTime.now(),
      );
    }).toList();
  }

  /// @backend POST /api/v1/community/posts/{postId}/pin
  /// Returns: { "is_pinned": bool }
  void pinPost(String postId) {
    _forYouPosts = _forYouPosts.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(isPinned: !p.isPinned);
    }).toList();
    notifyListeners();
  }

  /// @backend POST /api/v1/community/posts/{postId}/vote
  /// Body: { "option_index": int }
  /// Returns: CommunityPoll JSON
  void votePoll(String postId, int optionIndex) {
    CommunityPoll? targetPoll;
    CommunityPollOption? chosenOption;

    _forYouPosts = _forYouPosts.map((p) {
      if (p.id != postId || p.poll == null) return p;
      final poll = p.poll!;
      final updatedOptions = List<CommunityPollOption>.from(poll.options);
      if (optionIndex < 0 || optionIndex >= updatedOptions.length) return p;

      if (poll.allowMultiple) {
        final currentIndices = List<int>.from(poll.votedOptionIndices);
        final opt = updatedOptions[optionIndex];
        if (currentIndices.contains(optionIndex)) {
          currentIndices.remove(optionIndex);
          updatedOptions[optionIndex] = opt.copyWith(
            votes: (opt.votes - 1).clamp(0, 999999),
          );
        } else {
          currentIndices.add(optionIndex);
          updatedOptions[optionIndex] = opt.copyWith(votes: opt.votes + 1);
        }
        final updatedPoll = poll.copyWith(
          options: updatedOptions,
          votedOptionIndices: currentIndices,
          votedOptionIndex: currentIndices.isEmpty
              ? null
              : currentIndices.first,
        );
        targetPoll = updatedPoll;
        chosenOption = opt;
        return p.copyWith(poll: updatedPoll);
      } else {
        if (poll.hasVoted) return p;
        final opt = updatedOptions[optionIndex];
        updatedOptions[optionIndex] = opt.copyWith(votes: opt.votes + 1);
        final updatedPoll = poll.copyWith(
          options: updatedOptions,
          votedOptionIndex: optionIndex,
          votedOptionIndices: [optionIndex],
        );
        targetPoll = updatedPoll;
        chosenOption = opt;
        return p.copyWith(poll: updatedPoll);
      }
    }).toList();

    if (targetPoll != null) {
      _followingPosts = _followingPosts.map((p) {
        if (p.id == postId) return p.copyWith(poll: targetPoll);
        return p;
      }).toList();
      _signalPosts = _signalPosts.map((p) {
        if (p.id == postId) return p.copyWith(poll: targetPoll);
        return p;
      }).toList();
    }
    notifyListeners();

    if (SupabaseConfig.isConfigured &&
        targetPoll != null &&
        chosenOption != null) {
      try {
        final client = SupabaseConfig.client!;
        final currentUserId = _resolveUserId();
        if (_isUuid(targetPoll!.id) && _isUuid(chosenOption!.id)) {
          unawaited(
            client
                .from('community_poll_votes')
                .upsert({
                  'poll_id': targetPoll!.id,
                  'option_id': chosenOption!.id,
                  'user_id': currentUserId,
                })
                .catchError((e) {
                  debugPrint('[CommunityRepository] votePoll error: $e');
                }),
          );
        }
      } catch (e) {
        debugPrint('[CommunityRepository] votePoll error: $e');
      }
    }
  }

  /// @backend POST /api/v1/community/reports
  /// Body: { "target_id": String, "reason": String, "notes": String? }
  /// Returns: { "report_id": String, "status": "received" }
  void reportPost(
    String postId,
    CommunityReportReason reason, {
    String? notes,
  }) {
    throw StateError(
      'Moderation delivery is not connected. No report has been submitted.',
    );
  }

  /// @backend POST /api/v1/community/moderation/mute
  /// Body: { "user_id": String }
  /// Returns: { "muted": true }
  void muteUser(String userId) {
    _mutedUsers.add(userId);
    notifyListeners();
  }

  /// @backend POST /api/v1/community/moderation/unmute
  /// Body: { "user_id": String }
  /// Returns: { "muted": false }
  void unmuteUser(String userId) {
    _mutedUsers.remove(userId);
    notifyListeners();
  }

  /// @backend POST /api/v1/community/moderation/block
  /// Body: { "user_id": String }
  /// Returns: { "blocked": true }
  Future<void> blockUser(String userId) async {
    final priorOutgoing = Set<String>.from(_outgoingBlockedUserIds);
    _blockRefreshEpoch++;
    _outgoingBlockedUserIds.add(userId);
    _blockedUsers = {..._outgoingBlockedUserIds, ..._incomingBlockedUserIds};
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(userId)) {
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty && !CustomerDataPolicy.allowDemo) {
        _outgoingBlockedUserIds = priorOutgoing;
        _blockedUsers = {
          ..._outgoingBlockedUserIds,
          ..._incomingBlockedUserIds,
        };
        notifyListeners();
        throw StateError(
          'Cannot block user without an authenticated identity.',
        );
      }
      if (targetUserId.isNotEmpty) {
        try {
          final client = SupabaseConfig.client!;
          await client.from('blocks').upsert({
            'blocker_id': targetUserId,
            'blocked_id': userId,
          });
        } catch (e, stack) {
          debugPrint('[CommunityRepository] blockUser error: $e');
          _outgoingBlockedUserIds = priorOutgoing;
          _blockedUsers = {
            ..._outgoingBlockedUserIds,
            ..._incomingBlockedUserIds,
          };
          notifyListeners();
          Error.throwWithStackTrace(e, stack);
        }
      }
    }
  }

  /// @backend POST /api/v1/community/moderation/unblock
  /// Body: { "user_id": String }
  /// Returns: { "blocked": false }
  Future<void> unblockUser(String userId) async {
    final priorOutgoing = Set<String>.from(_outgoingBlockedUserIds);
    _blockRefreshEpoch++;
    _outgoingBlockedUserIds.remove(userId);
    // Unblocking an outgoing block must NOT erase an independent incoming block
    _blockedUsers = {..._outgoingBlockedUserIds, ..._incomingBlockedUserIds};
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(userId)) {
      final targetUserId = _resolveUserId();
      if (targetUserId.isEmpty && !CustomerDataPolicy.allowDemo) {
        _outgoingBlockedUserIds = priorOutgoing;
        _blockedUsers = {
          ..._outgoingBlockedUserIds,
          ..._incomingBlockedUserIds,
        };
        notifyListeners();
        throw StateError(
          'Cannot unblock user without an authenticated identity.',
        );
      }
      if (targetUserId.isNotEmpty) {
        try {
          final client = SupabaseConfig.client!;
          await client
              .from('blocks')
              .delete()
              .eq('blocker_id', targetUserId)
              .eq('blocked_id', userId);
        } catch (e, stack) {
          debugPrint('[CommunityRepository] unblockUser error: $e');
          _outgoingBlockedUserIds = priorOutgoing;
          _blockedUsers = {
            ..._outgoingBlockedUserIds,
            ..._incomingBlockedUserIds,
          };
          notifyListeners();
          Error.throwWithStackTrace(e, stack);
        }
      }
    }
  }

  /// @backend GET /api/v1/community/posts/{postId}
  /// Returns: CommunityPost JSON
  CommunityPost? loadPostById(String postId) {
    final all = <CommunityPost>[
      ..._forYouPosts,
      ..._signalPosts,
      ..._followingPosts,
      ..._bookmarkedPosts,
    ];
    final String mappedId = switch (postId) {
      'post-101' => 'post_q1',
      'post-102' => 'post_a2',
      'post-103' => 'post_a1',
      'post-104' => 'post_nitish_1',
      'post-105' => 'post_a3',
      'post_1' => 'post_nitish_1',
      'post_2' => 'post_a1',
      'post_3' => 'post_a2',
      'post_4' => 'post_a3',
      'post_5' => 'post_p1',
      'post_6' => 'post_m1',
      _ => postId,
    };
    try {
      final found = all.firstWhere(
        (p) =>
            (p.id == postId || p.id == mappedId) &&
            (p.author.id == currentAuthor.id ||
                (p.isPublic && !p.isPendingApproval)),
      );
      if (_blockedUsers.contains(found.author.id)) {
        return null;
      }
      return found;
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously fetches a post from Supabase if not present in the local cache.
  Future<CommunityPost?> fetchPostById(String postId) async {
    final cached = loadPostById(postId);
    if (!SupabaseConfig.isConfigured) return cached;
    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('community_posts')
          .select(
            '*, profiles!community_posts_author_id_fkey(id, handle, display_name, avatar_url, bio, role, experience_level, trading_style, verified, win_rate, followers_count, following_count, posts_count, subscription_tier), community_post_trade_setups(*), community_post_attachments(*), community_polls(*, community_poll_options(*))',
          )
          .eq('id', postId)
          .maybeSingle();
      if (res != null) {
        final row = res;
        final authorProfile = row['profiles'] as Map<String, dynamic>?;
        final authorId = row['author_id']?.toString() ?? '';
        if (_blockedUsers.contains(authorId)) {
          return null;
        }
        final currentAuthId = SupabaseConfig.client?.auth.currentUser?.id;
        final moderationStatus =
            row['moderation_status']?.toString().toLowerCase() ?? 'approved';
        if (moderationStatus != 'approved' && authorId != currentAuthId) {
          return null;
        }
        if (row['is_public'] != true && authorId != currentAuthId) {
          return null;
        }
        final author = mapProfileToCommunityAuthor(
          authorId: authorId,
          authorProfile: authorProfile,
          isFollowing: _followedAuthorIds.contains(authorId),
        );
        CommunityTradeSetup? setup;
        final rawSetups = row['community_post_trade_setups'];
        Map<String, dynamic>? s;
        if (rawSetups is Map<String, dynamic>) {
          s = rawSetups;
        } else if (rawSetups is List && rawSetups.isNotEmpty) {
          s = rawSetups.first as Map<String, dynamic>;
        }
        if (s != null) {
          setup = CommunityTradeSetup(
            ticker: s['ticker'] as String? ?? '',
            side: (s['side']?.toString().toUpperCase() == 'SHORT')
                ? 'SHORT'
                : 'LONG',
            entry: s['entry']?.toString() ?? '0.0',
            stopLoss: s['stop_loss']?.toString(),
            target: s['target1']?.toString(),
          );
        }
        final List<String> imageUrls = <String>[];
        AppWritingPostAttachment? attachment;
        final attachmentsList = row['community_post_attachments'];
        if (attachmentsList != null && attachmentsList is List) {
          for (final attItem in attachmentsList) {
            final attMap = attItem as Map<String, dynamic>;
            final kind = attMap['kind']?.toString() ?? '';
            final url = attMap['url']?.toString();
            final title = attMap['title']?.toString() ?? '';
            final refId = attMap['ref_id']?.toString() ?? '';
            if (kind == 'image') {
              var img = url ?? refId;
              if (img.isNotEmpty) {
                if (SupabaseConfig.isConfigured) {
                  try {
                    img = SupabaseStorageEgress.resolvePublicCdnUrl(
                      client: client,
                      bucket:
                          SupabaseStorageEgress.communityAttachments.bucketId,
                      ref: img,
                    );
                  } catch (_) {}
                }
                if (!imageUrls.contains(img)) {
                  imageUrls.add(img);
                }
              }
            } else if (kind == 'note' ||
                kind == 'journal' ||
                kind == 'strategy' ||
                kind == 'manual' ||
                kind == 'document') {
              final linkKind = AppLinkKind.fromHost(kind) ?? AppLinkKind.note;
              attachment = AppWritingPostAttachment.manual(
                source: AppLinkRef(
                  kind: linkKind,
                  id: refId,
                  title: title,
                  subtitle: url,
                ),
                excerpt: title,
              );
            } else if (kind == 'chart_candles' && url != null) {
              try {
                final decoded = jsonDecode(url);
                if (decoded is List) {
                  final candles = <UiCandle>[];
                  for (final item in decoded) {
                    if (item is Map) {
                      final time = DateTime.tryParse('${item['time']}');
                      if (time != null) {
                        candles.add(
                          UiCandle(
                            time: time,
                            open: (item['open'] as num?)?.toDouble() ?? 0.0,
                            high: (item['high'] as num?)?.toDouble() ?? 0.0,
                            low: (item['low'] as num?)?.toDouble() ?? 0.0,
                            close: (item['close'] as num?)?.toDouble() ?? 0.0,
                            volume: (item['volume'] as num?)?.toDouble() ?? 0.0,
                          ),
                        );
                      }
                    }
                  }
                  if (candles.isNotEmpty && setup != null) {
                    setup = setup.copyWith(
                      candles: candles,
                      candlesFromImage:
                          title == 'Image-derived candles (approximate)',
                    );
                  }
                }
              } catch (_) {}
            }
          }
        }
        CommunityPoll? poll;
        final rawPoll = row['community_polls'];
        if (rawPoll != null) {
          final pMap = (rawPoll is List && rawPoll.isNotEmpty)
              ? rawPoll.first as Map<String, dynamic>
              : (rawPoll is Map<String, dynamic> ? rawPoll : null);
          if (pMap != null) {
            final pollId = pMap['id']?.toString() ?? '';
            final rawOptions =
                pMap['community_poll_options'] as List? ?? const [];
            final options = <CommunityPollOption>[];
            for (final opt in rawOptions) {
              final oMap = opt as Map<String, dynamic>;
              options.add(
                CommunityPollOption(
                  id: oMap['id']?.toString() ?? '',
                  text: oMap['option_text']?.toString() ?? '',
                  votes: (oMap['votes_count'] as num?)?.toInt() ?? 0,
                ),
              );
            }
            poll = CommunityPoll(
              id: pollId,
              question: pMap['question'] as String? ?? '',
              options: options,
              expiresAt: DateTime.tryParse(
                pMap['expires_at']?.toString() ?? '',
              ),
            );
          }
        }
        final ({String body, String? quotedId, String? videoUrl}) parsedBody =
            _extractQuotedPostRef(row['body'] as String? ?? '');
        CommunityPost? quotedPost;
        if (parsedBody.quotedId != null && parsedBody.quotedId!.isNotEmpty) {
          quotedPost = findPost(parsedBody.quotedId!);
          if (quotedPost == null && _isUuid(parsedBody.quotedId!)) {
            final fetched = await _fetchMinimalQuotedPosts(client, <String>{
              parsedBody.quotedId!,
            });
            quotedPost = fetched[parsedBody.quotedId!];
          }
        }
        final post = CommunityPost(
          id: postId,
          author: author,
          body: parsedBody.body,
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
          isPinned: row['is_pinned'] as bool? ?? false,
          isPublic: row['is_public'] as bool? ?? false,
          tickers:
              (row['tickers'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          tags:
              (row['tags'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
          tradeSetup: setup,
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
          imageUrls: imageUrls,
          videoUrl: parsedBody.videoUrl,
          attachment: attachment,
          poll: poll,
          quoted: quotedPost,
          likes: (row['likes_count'] as num?)?.toInt() ?? 0,
          comments: (row['comments_count'] as num?)?.toInt() ?? 0,
          reposts: (row['reposts_count'] as num?)?.toInt() ?? 0,
          views: (row['views_count'] as num?)?.toInt() ?? 0,
          moderationStatus: row['moderation_status']?.toString() ?? 'approved',
        );
        _forYouPosts.insert(0, post);
        notifyListeners();
        return post;
      }
    } catch (e) {
      debugPrint('[CommunityRepository] fetchPostById error: $e');
    }
    return null;
  }

  /// Records a view for the given post. Persists to Supabase via RPC if available.
  Future<void> recordView(String postId) async {
    final normalizedId = postId.trim();
    if (normalizedId.isEmpty) return;
    if (_viewedPostIds.contains(normalizedId)) return;

    final existing = loadPostById(normalizedId);
    if (existing == null && !SupabaseConfig.isConfigured) {
      return;
    }
    if (existing != null &&
        existing.moderationStatus.isNotEmpty &&
        existing.moderationStatus != 'approved' &&
        existing.author.id != _resolveUserId()) {
      return;
    }

    _viewedPostIds.add(normalizedId);

    CommunityPost updatePostViews(CommunityPost p) =>
        p.id == normalizedId ? p.copyWith(views: p.views + 1) : p;

    _forYouPosts = _forYouPosts.map(updatePostViews).toList();
    _signalPosts = _signalPosts.map(updatePostViews).toList();
    _followingPosts = _followingPosts.map(updatePostViews).toList();
    _bookmarkedPosts = _bookmarkedPosts.map(updatePostViews).toList();

    _insightsByPost.remove(normalizedId);
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });

    if (SupabaseConfig.isConfigured && _isUuid(normalizedId)) {
      try {
        final client = SupabaseConfig.client;
        if (client != null) {
          await client.rpc(
            'increment_post_views',
            params: {'p_post_id': normalizedId},
          );
        }
      } catch (e) {
        debugPrint('[CommunityRepository] recordView error: $e');
      }
    }
  }

  /// Records that a trader tapped into the detail / full thread of a post.
  void recordDetailExpand(String postId) {
    if (postId.trim().isEmpty) return;
    _detailExpandsByPost[postId] = (_detailExpandsByPost[postId] ?? 0) + 1;
    _insightsByPost.remove(postId);
  }

  /// Records a visit to the author's profile from this post.
  void recordProfileVisit(String postId) {
    if (postId.trim().isEmpty) return;
    _profileVisitsByPost[postId] = (_profileVisitsByPost[postId] ?? 0) + 1;
    _insightsByPost.remove(postId);
  }

  /// Records a link, ticker, attachment, or trade setup click from this post.
  void recordLinkClick(String postId) {
    if (postId.trim().isEmpty) return;
    _linkClicksByPost[postId] = (_linkClicksByPost[postId] ?? 0) + 1;
    _insightsByPost.remove(postId);
  }

  /// Returns the recorded outbound share count for [postId].
  int shareCountFor(String postId) => _sharesByPost[postId] ?? 0;

  /// Records an outbound share (via DM or external app) from this post.
  void recordShare(String postId) {
    if (postId.trim().isEmpty) return;
    _sharesByPost[postId] = (_sharesByPost[postId] ?? 0) + 1;
    _insightsByPost.remove(postId);
    WorkspacePostService.instance.recordShare(postId);
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  /// @backend GET /api/v1/community/posts/{postId}/insights
  /// Returns: CommunityPostInsights JSON
  CommunityPostInsights getPostInsights(String postId, {CommunityPost? post}) {
    final effectivePost = post ?? loadPostById(postId);
    if (effectivePost == null) {
      return CommunityPostInsights(
        postId: postId,
        impressions: 0,
        engagements: 0,
        detailExpands: 0,
        profileVisits: 0,
        linkClicks: 0,
        shares: 0,
      );
    }

    final int likes = effectivePost.likes;
    final int comments = effectivePost.comments;
    final int reposts = effectivePost.reposts;
    final int saves = effectivePost.bookmarked ? 1 : 0;
    final int totalEngagements = likes + comments + reposts + saves;

    // Impressions: reach in trader feeds. Logically must always exceed engagements.
    final int rawViews = effectivePost.views;
    final int impressions = rawViews > 0
        ? (rawViews >= totalEngagements ? rawViews : totalEngagements + 6)
        : (totalEngagements > 0 ? (totalEngagements * 4 + 14) : 1);

    final int detailExpands =
        _detailExpandsByPost[postId] ??
        (comments + (likes > 0 ? (likes / 2).ceil() : 0));

    final int profileVisits =
        _profileVisitsByPost[postId] ?? (likes > 0 ? (likes * 0.35).ceil() : 0);

    final bool hasAttachments =
        effectivePost.tradeSetup != null ||
        effectivePost.imageUrls.isNotEmpty ||
        effectivePost.attachment != null ||
        effectivePost.tickers.isNotEmpty ||
        effectivePost.tags.isNotEmpty;

    final int linkClicks =
        _linkClicksByPost[postId] ??
        (hasAttachments ? (likes > 0 ? (likes * 0.6).ceil() : 1) : 0);

    final int shares = reposts + (_sharesByPost[postId] ?? 0);

    final insights = CommunityPostInsights(
      postId: postId,
      impressions: impressions,
      engagements: totalEngagements,
      detailExpands: detailExpands,
      profileVisits: profileVisits,
      linkClicks: linkClicks,
      shares: shares,
    );
    _insightsByPost[postId] = insights;
    return insights;
  }

  /// @backend GET /api/v1/community/search
  /// Query: q=..., category=...
  /// Returns: `List<CommunityPost>` JSON
  List<CommunityPost> searchPosts(String query, {String? category}) {
    if (query.trim().isEmpty) return forYouPosts;
    final q = query.toLowerCase();
    return forYouPosts.where((p) {
      final matchesText =
          p.body.toLowerCase().contains(q) ||
          p.author.displayName.toLowerCase().contains(q) ||
          p.author.handle.toLowerCase().contains(q) ||
          p.tickers.any((t) => t.toLowerCase().contains(q)) ||
          p.tags.any((t) => t.toLowerCase().contains(q));
      if (!matchesText) return false;
      if (category != null && category != 'All') {
        final c = category.toLowerCase();
        return p.tags.any((t) => t.toLowerCase().contains(c)) ||
            p.body.toLowerCase().contains(c);
      }
      return true;
    }).toList();
  }

  /// @backend GET /api/v1/community/search/users
  /// Query: q=...
  /// Returns: `List<CommunityAuthor>` JSON
  List<CommunityAuthor> searchUsers(String query) {
    if (query.trim().isEmpty) return _suggestedTraders;
    final q = query.toLowerCase();
    final all = <CommunityAuthor>[
      if (!CustomerDataPolicy.allowDemo) ...{
        for (final post in _forYouPosts) post.author,
      },
      if (CustomerDataPolicy.allowDemo) ...[
        _alexVance,
        _marcoSilva,
        _elenaRostova,
        _priyaSharma,
        _alphajournalWire,
        _arisThorne,
        _rajeshPatel,
        _sarahWong,
      ],
    ];
    final authorsById = <String, CommunityAuthor>{
      for (final author in all) author.id: author,
      for (final author in allKnownAuthors) author.id: author,
    };
    return authorsById.values.map((author) => _transformAuthor(author)).where((
      a,
    ) {
      if (_blockedUsers.contains(a.id)) return false;
      return a.displayName.toLowerCase().contains(q) ||
          a.handle.toLowerCase().contains(q) ||
          (a.tradingStyle?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// @backend GET /api/v1/community/tags/{hashtag}/posts
  /// Returns: `List<CommunityPost>` JSON
  List<CommunityPost> fetchHashtagPosts(String hashtag) {
    final clean = hashtag
        .replaceAll('#', '')
        .replaceAll('\$', '')
        .toLowerCase();
    return _forYouPosts.where((p) {
      return p.tickers.any((t) => t.toLowerCase() == clean) ||
          p.tags.any((t) => t.toLowerCase() == clean) ||
          p.body.toLowerCase().contains(clean);
    }).toList();
  }

  /// Custom sub-tabs management
  void addCustomFeedTab(String label) {
    if (label.trim().isEmpty || _customFeedTabs.contains(label.trim())) return;
    _customFeedTabs.add(label.trim());
    notifyListeners();
  }

  void removeCustomFeedTab(String label) {
    _customFeedTabs.remove(label);
    notifyListeners();
  }

  void reorderCustomFeedTabs(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _customFeedTabs.length) return;
    if (newIndex < 0 || newIndex > _customFeedTabs.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    final String item = _customFeedTabs.removeAt(oldIndex);
    _customFeedTabs.insert(newIndex, item);
    notifyListeners();
  }

  /// @backend GET /api/v1/community/inbox/{peerId}/messages
  /// Returns: `List<CommunityChatMessage>` JSON
  List<CommunityChatMessage> messagesForConversation(String conversationId) {
    return _messagesByConversation[conversationId] ??
        const <CommunityChatMessage>[];
  }

  /// @backend POST /api/v1/community/inbox/{peerId}/messages
  /// Body: { "text": String, "shared_post_id": String? }
  /// Returns: CommunityChatMessage JSON
  void sendDirectMessage(
    String peerId,
    String text, {
    CommunityPost? sharedPost,
  }) {
    final peer = authorById(peerId);
    if (peer == null) return;
    final msg = CommunityChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _alexVance.id,
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
      sharedPost: sharedPost,
    );
    final convId = 'conv_$peerId';
    final existingMsgs = List<CommunityChatMessage>.from(
      _messagesByConversation[convId] ?? [],
    );
    existingMsgs.add(msg);
    _messagesByConversation[convId] = existingMsgs;

    // Update or insert conversation item
    final convIndex = _conversations.indexWhere((c) => c.peer.id == peerId);
    final updatedConv = CommunityConversation(
      id: convId,
      peer: peer,
      lastMessage: text.isNotEmpty ? text : 'Shared a trade setup',
      updatedAt: DateTime.now(),
      unreadCount: 0,
    );
    if (convIndex >= 0) {
      _conversations[convIndex] = updatedConv;
    } else {
      _conversations.insert(0, updatedConv);
    }
    notifyListeners();
  }

  void dismissPushNotificationsPrompt() {
    _pushNotificationsPromptVisible = false;
    notifyListeners();
  }

  Future<void> fetchNotificationsFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();

      final res = await client
          .from('notifications')
          .select()
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(50);

      final actorIds = (res as List)
          .map((raw) => (raw as Map<String, dynamic>)['actor_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final Map<String, CommunityAuthor> actorMap = {};
      if (actorIds.isNotEmpty) {
        try {
          final profRes = await client
              .from('profiles')
              .select('id, handle, display_name, avatar_url, role')
              .inFilter('id', actorIds.toList());
          for (final raw in profRes as List) {
            final p = raw as Map<String, dynamic>;
            final id = p['id']?.toString() ?? '';
            final rawHandle = p['handle']?.toString() ?? 'trader';
            final handle = rawHandle.startsWith('@')
                ? rawHandle.substring(1)
                : rawHandle;
            actorMap[id] = CommunityAuthor(
              id: id,
              handle: handle,
              displayName: p['display_name']?.toString() ?? handle,
              avatarUrl: p['avatar_url']?.toString(),
              userRole: _parseUserRole(p['role']?.toString()),
            );
          }
        } catch (_) {}
      }

      final List<CommunityNotificationItem> items = [];
      for (final raw in res as List) {
        final row = raw as Map<String, dynamic>;
        final actorId = row['actor_id']?.toString();
        final actor = actorId != null ? actorMap[actorId] : null;

        final typeStr =
            (row['type'] ?? row['category'])?.toString().toLowerCase() ??
            'system';
        final type = switch (typeStr) {
          'like' => CommunityNotificationType.like,
          'comment' => CommunityNotificationType.comment,
          'reply' => CommunityNotificationType.reply,
          'repost' => CommunityNotificationType.repost,
          'follow' => CommunityNotificationType.follow,
          'mention' => CommunityNotificationType.mention,
          'signal' => CommunityNotificationType.signal,
          'security' => CommunityNotificationType.security,
          'trade_execution' => CommunityNotificationType.tradeExecution,
          'margin_alert' => CommunityNotificationType.marginAlert,
          'message' => CommunityNotificationType.message,
          _ => CommunityNotificationType.system,
        };

        final data = row['data'] as Map<String, dynamic>? ?? const {};
        final postId = data['post_id']?.toString();
        final postImage = data['post_image']?.toString();
        final isFollowingBack =
            actor != null && _followedAuthorIds.contains(actor.id);
        final bool isRead =
            row['read'] == true ||
            row['is_read'] == true ||
            row['read_at'] != null;

        items.add(
          CommunityNotificationItem(
            id: row['id']?.toString() ?? '',
            actor: actor,
            type: type,
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now(),
            title: row['title']?.toString(),
            body: row['body']?.toString(),
            postSnippet: data['post_snippet']?.toString(),
            postId: postId,
            postImageUrl: postImage,
            data: data,
            read: isRead,
            isFollowingBack: isFollowingBack,
          ),
        );
      }

      if (items.isNotEmpty) {
        _notifications = items;
        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        '[CommunityRepository] fetchNotificationsFromSupabase error: $e',
      );
    }
  }

  void subscribeToRealtimeNotifications() {
    if (!SupabaseConfig.isConfigured || _notificationsChannel != null) return;
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();

      _notificationsChannel = client
          .channel('public:notifications:$targetUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: targetUserId,
            ),
            callback: (payload) async {
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;

              CommunityAuthor? actor;
              final actorId = newRow['actor_id']?.toString();
              if (actorId != null && actorId.isNotEmpty) {
                try {
                  final p = await client
                      .from('profiles')
                      .select(
                        'id, handle, display_name, avatar_url, role, verified',
                      )
                      .eq('id', actorId)
                      .maybeSingle();
                  if (p != null) {
                    actor = CommunityAuthor(
                      id: p['id']?.toString() ?? '',
                      handle: p['handle']?.toString() ?? 'trader',
                      displayName: p['display_name']?.toString() ?? 'Trader',
                      avatarUrl: p['avatar_url']?.toString(),
                      userRole: _parseUserRole(p['role']?.toString()),
                      verified: p['verified'] as bool? ?? false,
                    );
                  }
                } catch (_) {}
              }

              final typeStr =
                  newRow['type']?.toString().toLowerCase() ?? 'system';
              final type = switch (typeStr) {
                'like' => CommunityNotificationType.like,
                'comment' => CommunityNotificationType.comment,
                'reply' => CommunityNotificationType.reply,
                'repost' => CommunityNotificationType.repost,
                'follow' => CommunityNotificationType.follow,
                'mention' => CommunityNotificationType.mention,
                'signal' => CommunityNotificationType.signal,
                'security' => CommunityNotificationType.security,
                'trade_execution' => CommunityNotificationType.tradeExecution,
                'margin_alert' => CommunityNotificationType.marginAlert,
                'message' => CommunityNotificationType.message,
                _ => CommunityNotificationType.system,
              };

              final data = newRow['data'] as Map<String, dynamic>? ?? const {};
              final item = CommunityNotificationItem(
                id: newRow['id']?.toString() ?? const Uuid().v4(),
                actor: actor,
                type: type,
                createdAt:
                    DateTime.tryParse(newRow['created_at']?.toString() ?? '') ??
                    DateTime.now(),
                title: newRow['title']?.toString(),
                body: newRow['body']?.toString(),
                postSnippet: data['post_snippet']?.toString(),
                postId: data['post_id']?.toString(),
                postImageUrl: data['post_image']?.toString(),
                data: data,
                read: false,
                isFollowingBack:
                    actor != null && _followedAuthorIds.contains(actor.id),
              );

              _notifications.insert(0, item);
              notifyListeners();

              onLiveNotificationReceived?.call(item);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint(
        '[CommunityRepository] Realtime notifications subscription error: $e',
      );
    }
  }

  Future<void> markNotificationRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(read: true);
      notifyListeners();
    }
    if (SupabaseConfig.isConfigured) {
      try {
        final nowIso = DateTime.now().toIso8601String();
        try {
          await SupabaseConfig.client!
              .from('notifications')
              .update({'read': true, 'read_at': nowIso})
              .eq('id', id);
        } catch (_) {
          await SupabaseConfig.client!
              .from('notifications')
              .update({'read_at': nowIso})
              .eq('id', id);
        }
      } catch (e) {
        debugPrint('[CommunityRepository] markNotificationRead error: $e');
      }
    }
  }

  Future<void> markAllNotificationsRead() async {
    _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
    notifyListeners();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final nowIso = DateTime.now().toIso8601String();
        try {
          await client
              .from('notifications')
              .update({'read': true, 'read_at': nowIso})
              .eq('user_id', targetUserId);
        } catch (_) {
          await client
              .from('notifications')
              .update({'read_at': nowIso})
              .eq('user_id', targetUserId)
              .isFilter('read_at', null);
        }
      } catch (e) {
        debugPrint('[CommunityRepository] markAllNotificationsRead error: $e');
      }
    }
  }

  void toggleFollowFromNotification(CommunityNotificationItem item) {
    final actor = item.actor;
    if (actor == null) return;
    toggleFollow(actor.id);
  }

  @visibleForTesting
  void setNotificationsForTesting(List<CommunityNotificationItem> items) {
    _notifications = List<CommunityNotificationItem>.from(items);
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Live Audio Spaces Controls & Database Sync
  // -------------------------------------------------------------------------

  Future<void> tuneIntoRoom(String roomId) async {
    if (_tunedRoomId == roomId) return;
    _tunedRoomId = roomId;
    final index = _liveRooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _liveRooms[index];
      _liveRooms[index] = room.copyWith(listenerCount: room.listenerCount + 1);
    }
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(roomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc('tune_into_live_room', params: {'p_room_id': roomId});
      } catch (e) {
        debugPrint('[CommunityRepository] tune_into_live_room RPC error: $e');
      }
    }
  }

  Future<void> leaveRoom() async {
    final leavingRoomId = _tunedRoomId;
    if (leavingRoomId == null) return;

    final index = _liveRooms.indexWhere((r) => r.id == leavingRoomId);
    if (index != -1) {
      final room = _liveRooms[index];
      _liveRooms[index] = room.copyWith(
        listenerCount: (room.listenerCount - 1).clamp(0, 999999),
      );
    }
    _tunedRoomId = null;
    _isHandRaised = false;
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(leavingRoomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc(
          'leave_live_room',
          params: {'p_room_id': leavingRoomId},
        );
      } catch (e) {
        debugPrint('[CommunityRepository] leave_live_room RPC error: $e');
      }
    }
  }

  void toggleMute() {
    _isAudioMuted = !_isAudioMuted;
    notifyListeners();
  }

  Future<void> toggleHandRaised([String? roomId]) async {
    _isHandRaised = !_isHandRaised;
    notifyListeners();

    final targetRoom = roomId ?? _tunedRoomId;
    if (SupabaseConfig.isConfigured &&
        targetRoom != null &&
        _isUuid(targetRoom)) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc(
          'toggle_live_room_hand',
          params: {'p_room_id': targetRoom},
        );
      } catch (e) {
        debugPrint('[CommunityRepository] toggle_live_room_hand RPC error: $e');
      }
    }
  }

  Future<void> toggleRoomReminder(String roomId) async {
    final index = _liveRooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _liveRooms[index];
      _liveRooms[index] = room.copyWith(hasReminder: !room.hasReminder);
      notifyListeners();
    }

    if (SupabaseConfig.isConfigured && _isUuid(roomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc(
          'toggle_live_room_reminder',
          params: {'p_room_id': roomId},
        );
      } catch (e) {
        debugPrint(
          '[CommunityRepository] toggle_live_room_reminder RPC error: $e',
        );
      }
    }
  }

  Future<void> voteLiveRoomPoll(String roomId, String vote) async {
    final index = _liveRooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _liveRooms[index];
      if (vote == 'bullish') {
        _liveRooms[index] = room.copyWith(
          pollBullishVotes: room.pollBullishVotes + 1,
        );
      } else {
        _liveRooms[index] = room.copyWith(
          pollBearishVotes: room.pollBearishVotes + 1,
        );
      }
      notifyListeners();
    }

    if (SupabaseConfig.isConfigured && _isUuid(roomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client.rpc(
          'vote_live_room_poll',
          params: {'p_room_id': roomId, 'p_vote': vote},
        );
      } catch (e) {
        debugPrint('[CommunityRepository] vote_live_room_poll RPC error: $e');
      }
    }
  }

  /// Keeps a completed host session available to public profile history.
  Future<void> endLiveRoom(String roomId) async {
    final index = _liveRooms.indexWhere((room) => room.id == roomId);
    if (index >= 0) {
      _liveRooms[index] = _liveRooms[index].copyWith(
        status: LiveRoomStatus.ended,
        endedAt: DateTime.now(),
      );
    }
    if (_tunedRoomId == roomId) {
      _tunedRoomId = null;
      _isAudioMuted = true;
      _isHandRaised = false;
    }
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(roomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('community_live_rooms')
            .update({
              'status': 'ended',
              'ended_at': DateTime.now().toIso8601String(),
            })
            .eq('id', roomId);
      } catch (e) {
        debugPrint('[CommunityRepository] endLiveRoom error: $e');
      }
    }
  }

  Future<LiveAudioRoom> createLiveRoom({
    required String title,
    required String topic,
    required String category,
    LivePinnedSetup? pinnedSetup,
    bool startNow = true,
    DateTime? scheduledFor,
    List<String> tags = const <String>[],
  }) async {
    final roomId = const Uuid().v4();
    final now = DateTime.now();
    final room = LiveAudioRoom(
      id: roomId,
      title: title,
      topic: topic,
      host: currentAuthor,
      category: category,
      status: startNow ? LiveRoomStatus.live : LiveRoomStatus.scheduled,
      listenerCount: startNow ? 1 : 0,
      speakerCount: 1,
      speakers: <String>[currentAuthor.displayName],
      pinnedSetup: pinnedSetup,
      scheduledFor: scheduledFor,
      startedAt: startNow ? now : null,
      isRecording: true,
      tags: tags,
    );

    _liveRooms.insert(0, room);
    if (startNow) {
      _tunedRoomId = roomId;
    }
    notifyListeners();

    if (SupabaseConfig.isConfigured) {
      try {
        final client = SupabaseConfig.client!;
        final hostUserId = _resolveUserId();

        await client.from('community_live_rooms').insert({
          'id': roomId,
          'host_id': hostUserId,
          'title': title,
          'topic': topic,
          'category': category,
          'status': startNow ? 'live' : 'scheduled',
          'listener_count': startNow ? 1 : 0,
          'speaker_count': 1,
          'started_at': startNow ? now.toIso8601String() : null,
          'scheduled_for': scheduledFor?.toIso8601String(),
          'recording_available': true,
          'tags': tags,
          'pinned_ticker': pinnedSetup?.ticker,
          'pinned_side': pinnedSetup?.side,
          'pinned_entry': pinnedSetup?.entry,
          'pinned_stop_loss': pinnedSetup?.stopLoss,
          'pinned_target': pinnedSetup?.target,
          'pinned_note': pinnedSetup?.note,
        });

        if (startNow) {
          await client.rpc(
            'tune_into_live_room',
            params: {'p_room_id': roomId},
          );
        }
      } catch (e) {
        debugPrint('[CommunityRepository] createLiveRoom Supabase error: $e');
      }
    }

    return room;
  }

  // --- Realtime In-Room Participants, Messages, and Q&A Methods ---

  Future<List<LiveRoomParticipant>> fetchRoomParticipants(String roomId) async {
    if (!SupabaseConfig.isConfigured || !_isUuid(roomId)) {
      // Local fallback with host
      return <LiveRoomParticipant>[
        LiveRoomParticipant(
          roomId: roomId,
          userId: currentAuthor.id,
          displayName: currentAuthor.displayName,
          handle: currentAuthor.handle,
          avatarUrl: currentAuthor.avatarUrl,
          role: 'host',
          isMuted: _isAudioMuted,
          isHandRaised: _isHandRaised,
          joinedAt: DateTime.now(),
        ),
      ];
    }

    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('community_live_room_participants')
          .select('*, profiles:user_id(id, handle, display_name, avatar_url)')
          .eq('room_id', roomId)
          .order('joined_at', ascending: true);

      return (res as List)
          .map((e) => LiveRoomParticipant.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[CommunityRepository] fetchRoomParticipants error: $e');
      return <LiveRoomParticipant>[];
    }
  }

  Future<void> updateParticipantRole(
    String roomId,
    String targetUserId,
    String role,
  ) async {
    if (SupabaseConfig.isConfigured && _isUuid(roomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('community_live_room_participants')
            .update({'role': role})
            .eq('room_id', roomId)
            .eq('user_id', targetUserId);
      } catch (e) {
        debugPrint('[CommunityRepository] updateParticipantRole error: $e');
      }
    }
  }

  Future<void> setParticipantMute(
    String roomId,
    String targetUserId,
    bool isMuted,
  ) async {
    if (SupabaseConfig.isConfigured && _isUuid(roomId)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('community_live_room_participants')
            .update({'is_muted': isMuted})
            .eq('room_id', roomId)
            .eq('user_id', targetUserId);
      } catch (e) {
        debugPrint('[CommunityRepository] setParticipantMute error: $e');
      }
    }
  }

  Future<List<LiveRoomMessage>> fetchRoomMessages(String roomId) async {
    if (!SupabaseConfig.isConfigured || !_isUuid(roomId)) {
      return <LiveRoomMessage>[];
    }

    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('community_live_room_messages')
          .select('*, profiles:sender_id(id, handle, display_name, avatar_url)')
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      return (res as List)
          .map((e) => LiveRoomMessage.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[CommunityRepository] fetchRoomMessages error: $e');
      return <LiveRoomMessage>[];
    }
  }

  Future<LiveRoomMessage?> sendRoomMessage(String roomId, String text) async {
    if (text.trim().isEmpty) return null;

    if (!SupabaseConfig.isConfigured || !_isUuid(roomId)) {
      // Local fallback
      return LiveRoomMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        senderId: currentAuthor.id,
        senderName: currentAuthor.displayName,
        senderAvatarUrl: currentAuthor.avatarUrl,
        senderRole: 'speaker',
        message: text.trim(),
        createdAt: DateTime.now(),
      );
    }

    try {
      final client = SupabaseConfig.client!;
      final userId = _resolveUserId();
      final res = await client
          .from('community_live_room_messages')
          .insert({
            'room_id': roomId,
            'sender_id': userId,
            'message': text.trim(),
          })
          .select('*, profiles:sender_id(id, handle, display_name, avatar_url)')
          .single();

      return LiveRoomMessage.fromMap(res);
    } catch (e) {
      debugPrint('[CommunityRepository] sendRoomMessage error: $e');
      return null;
    }
  }

  Future<List<LiveRoomQuestion>> fetchRoomQuestions(String roomId) async {
    if (!SupabaseConfig.isConfigured || !_isUuid(roomId)) {
      return <LiveRoomQuestion>[];
    }

    try {
      final client = SupabaseConfig.client!;
      final userId = _resolveUserId();

      final Set<String> upvotedQuestionIds = <String>{};
      try {
        final upvotesRes = await client
            .from('community_live_room_question_upvotes')
            .select('question_id')
            .eq('user_id', userId);
        for (final item in upvotesRes as List) {
          final qId = item['question_id']?.toString();
          if (qId != null) upvotedQuestionIds.add(qId);
        }
      } catch (e) {
        debugPrint('[CommunityRepository] fetch question upvotes error: $e');
      }

      final res = await client
          .from('community_live_room_questions')
          .select('*, profiles:author_id(id, handle, display_name, avatar_url)')
          .eq('room_id', roomId)
          .order('upvotes_count', ascending: false)
          .order('created_at', ascending: false);

      return (res as List).map((e) {
        final map = e as Map<String, dynamic>;
        final qId = map['id']?.toString() ?? '';
        return LiveRoomQuestion.fromMap(
          map,
          hasUpvoted: upvotedQuestionIds.contains(qId),
        );
      }).toList();
    } catch (e) {
      debugPrint('[CommunityRepository] fetchRoomQuestions error: $e');
      return <LiveRoomQuestion>[];
    }
  }

  Future<LiveRoomQuestion?> submitRoomQuestion(
    String roomId,
    String text,
  ) async {
    if (text.trim().isEmpty) return null;

    if (!SupabaseConfig.isConfigured || !_isUuid(roomId)) {
      return LiveRoomQuestion(
        id: 'q_${DateTime.now().millisecondsSinceEpoch}',
        roomId: roomId,
        authorId: currentAuthor.id,
        authorName: currentAuthor.displayName,
        authorAvatarUrl: currentAuthor.avatarUrl,
        question: text.trim(),
        upvotesCount: 1,
        hasUpvoted: true,
        createdAt: DateTime.now(),
      );
    }

    try {
      final client = SupabaseConfig.client!;
      final userId = _resolveUserId();
      final res = await client
          .from('community_live_room_questions')
          .insert({
            'room_id': roomId,
            'author_id': userId,
            'question': text.trim(),
            'upvotes_count': 1,
          })
          .select('*, profiles:author_id(id, handle, display_name, avatar_url)')
          .single();

      final question = LiveRoomQuestion.fromMap(res, hasUpvoted: true);

      // Auto-upvote author's own question
      try {
        await client.from('community_live_room_question_upvotes').insert({
          'question_id': question.id,
          'user_id': userId,
        });
      } catch (_) {}

      return question;
    } catch (e) {
      debugPrint('[CommunityRepository] submitRoomQuestion error: $e');
      return null;
    }
  }

  Future<void> toggleQuestionUpvote(String questionId) async {
    if (SupabaseConfig.isConfigured && _isUuid(questionId)) {
      try {
        final client = SupabaseConfig.client!;
        final userId = _resolveUserId();
        final check = await client
            .from('community_live_room_question_upvotes')
            .select('question_id')
            .eq('question_id', questionId)
            .eq('user_id', userId)
            .maybeSingle();

        if (check != null) {
          await client
              .from('community_live_room_question_upvotes')
              .delete()
              .eq('question_id', questionId)
              .eq('user_id', userId);
        } else {
          await client.from('community_live_room_question_upvotes').insert({
            'question_id': questionId,
            'user_id': userId,
          });
        }
      } catch (e) {
        debugPrint('[CommunityRepository] toggleQuestionUpvote error: $e');
      }
    }
  }

  Future<void> markQuestionAnswered(String questionId, bool answered) async {
    if (SupabaseConfig.isConfigured && _isUuid(questionId)) {
      try {
        final client = SupabaseConfig.client!;
        await client
            .from('community_live_room_questions')
            .update({
              'is_answered': answered,
              'answered_at': answered ? DateTime.now().toIso8601String() : null,
            })
            .eq('id', questionId);
      } catch (e) {
        debugPrint('[CommunityRepository] markQuestionAnswered error: $e');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Seed
  // -------------------------------------------------------------------------

  void _initSeedData() {
    _alexVance = const CommunityAuthor(
      id: 'usr_alex_vance',
      handle: 'alextrades',
      displayName: 'Alex Vance',
      userRole: UserRole.customer,
      bio:
          'Disciplined swing trader & price action specialist. Sharing execution notes, market structure, and verified playbooks. 84% win rate over 3 years.',
      tier: AppTier.premium,
      verified: true,
      isFollowing: true,
      followers: 12400,
      following: 234,
      winRate: 84.0,
      tradingStyle: 'Swing Trading',
      primaryMarket: 'Indian Equities & F&O',
      joinedDate: 'January 2024',
      mutualFollowers: <String>['Priya Sharma', 'Dr. Aris Thorne', '4 others'],
      postsCount: 892,
      location: 'Mumbai, India',
      website: 'alextrades.in',
    );

    _marcoSilva = const CommunityAuthor(
      id: 'usr_marco_silva',
      handle: 'marcosilva_edu',
      displayName: 'Marco Silva',
      userRole: UserRole.affiliate,
      bio:
          'Official AlphaJournal Partner & trading educator. Sharing setups, execution blueprints, and exclusive member discounts. 50K+ community members.',
      tier: AppTier.enterprise,
      verified: true,
      isFollowing: false,
      followers: 52800,
      following: 180,
      winRate: 79.0,
      tradingStyle: 'Positional & Education',
      primaryMarket: 'Global Equities & Crypto',
      joinedDate: 'March 2023',
      mutualFollowers: <String>['Alex Vance', '12 others'],
      postsCount: 3421,
      referralCode: 'ALPHAJOURNAL-MARCO-2026',
      channelHandle: '@MarcoSilvaEdu',
      audienceReach: '50,000+',
      location: 'Singapore',
      website: 'marcosilva.edu',
    );

    _elenaRostova = const CommunityAuthor(
      id: 'usr_elena_cro',
      handle: 'elena_cro',
      displayName: 'Elena Rostova',
      userRole: UserRole.userAdmin,
      bio:
          'Chief Risk Officer & Proprietary Desk Overseer. Managing firm-wide risk boundaries, capital allocation matrices, and trading engine infrastructure.',
      tier: AppTier.enterprise,
      verified: true,
      isFollowing: true,
      followers: 8900,
      following: 55,
      tradingStyle: 'Institutional Risk',
      primaryMarket: 'Derivatives & Structured Products',
      joinedDate: 'June 2022',
      mutualFollowers: <String>['Alex Vance'],
      postsCount: 234,
      location: 'London, UK',
    );

    _priyaSharma = const CommunityAuthor(
      id: 'usr_priya_sharma',
      handle: 'priya_options',
      displayName: 'Priya Sharma',
      userRole: UserRole.customer,
      bio:
          'Options specialist. Iron condors, calendar spreads, and IV crush plays. Nifty & Banknifty expert with 6+ years in derivatives.',
      tier: AppTier.premium,
      verified: true,
      isFollowing: false,
      followers: 18200,
      following: 310,
      winRate: 77.0,
      tradingStyle: 'Options & Derivatives',
      primaryMarket: 'Nifty F&O',
      joinedDate: 'April 2023',
      mutualFollowers: <String>['Alex Vance', 'Marco Silva'],
      postsCount: 1105,
      location: 'Bangalore, India',
    );

    _alphajournalWire = const CommunityAuthor(
      id: 'usr_alphajournal_wire',
      handle: 'alphajournal_wire',
      displayName: 'AlphaJournal Market Wire',
      userRole: UserRole.customer,
      bio:
          'Official market news desk: earnings beats, macro data, FII flows, and sector rotation alerts — all in real time.',
      tier: AppTier.enterprise,
      verified: true,
      isFollowing: true,
      followers: 124000,
      following: 12,
      tradingStyle: 'News & Analysis',
      primaryMarket: 'Global',
      joinedDate: 'January 2023',
      postsCount: 8924,
    );

    _arisThorne = const CommunityAuthor(
      id: 'usr_aris_thorne',
      handle: 'aris_quant',
      displayName: 'Dr. Aris Thorne',
      userRole: UserRole.customer,
      bio:
          'Quantitative researcher. Python-driven momentum and mean-reversion algos. Sharing backtests, factor research, and live strategy equity curves.',
      tier: AppTier.premium,
      verified: true,
      isFollowing: false,
      followers: 29700,
      following: 88,
      winRate: 69.0,
      tradingStyle: 'Algorithmic / Quant',
      primaryMarket: 'US Equities & Crypto',
      joinedDate: 'September 2023',
      mutualFollowers: <String>['Priya Sharma', '3 others'],
      postsCount: 628,
      location: 'Amsterdam, Netherlands',
      website: 'arisquant.io',
    );

    _rajeshPatel = const CommunityAuthor(
      id: 'usr_rajesh_patel',
      handle: 'rajesh_macro',
      displayName: 'Rajesh Patel',
      userRole: UserRole.customer,
      bio:
          'Global macro trader. FX, commodities, rates. Following the money flows across DM and EM markets.',
      tier: AppTier.premium,
      verified: false,
      isFollowing: false,
      followers: 4200,
      following: 567,
      winRate: 61.0,
      tradingStyle: 'Global Macro',
      primaryMarket: 'FX & Commodities',
      joinedDate: 'November 2024',
      mutualFollowers: <String>['Alex Vance'],
      postsCount: 234,
    );

    _sarahWong = const CommunityAuthor(
      id: 'usr_sarah_wong',
      handle: 'sarahwong_tech',
      displayName: 'Sarah Wong',
      userRole: UserRole.customer,
      bio:
          'Technical analyst specializing in breakout trades and Elliott Wave theory. US & HK markets.',
      tier: AppTier.free,
      verified: false,
      isFollowing: false,
      followers: 1890,
      following: 420,
      winRate: 58.0,
      tradingStyle: 'Technical Analysis',
      primaryMarket: 'US Tech Stocks',
      joinedDate: 'May 2025',
      mutualFollowers: <String>['Dr. Aris Thorne', '2 others'],
      postsCount: 87,
    );

    if (!CustomerDataPolicy.allowDemo) return;
    _attachableRecords = _buildAttachableRecords();
    _seedPosts();
    _seedComments();

    _seedTrending();
    _seedNotifications();
    _seedDirectMessages();
    _followerAuthorIds.addAll(<String>[
      _priyaSharma.id,
      _sarahWong.id,
      _rajeshPatel.id,
    ]);
    _followedAuthorIds.add(_arisThorne.id);
    _suggestedTraders = <CommunityAuthor>[
      _marcoSilva,
      _priyaSharma,
      _arisThorne.copyWith(isFollowing: true),
      _rajeshPatel,
      _sarahWong,
      _alphajournalWire,
    ];
    _leaderboard = <MapEntry<CommunityAuthor, double>>[
      MapEntry<CommunityAuthor, double>(_alexVance, 84.2),
      MapEntry<CommunityAuthor, double>(_marcoSilva, 79.4),
      MapEntry<CommunityAuthor, double>(_priyaSharma, 77.1),
      MapEntry<CommunityAuthor, double>(_arisThorne, 69.8),
      MapEntry<CommunityAuthor, double>(_rajeshPatel, 61.5),
    ];
  }

  void _seedPosts() {
    final now = DateTime.now();
    final AppWritingPostAttachment? noteAttachment = _attachableRecords
        .where((a) => a.kind == AppLinkKind.note && a.isPublic)
        .firstOrNull;
    final AppWritingPostAttachment? journalAttachment = _attachableRecords
        .where((a) => a.kind == AppLinkKind.journal && a.isPublic)
        .firstOrNull;
    final AppWritingPostAttachment? strategyAttachment = _attachableRecords
        .where((a) => a.kind == AppLinkKind.strategy && a.isPublic)
        .firstOrNull;

    final postPoll = CommunityPost(
      id: 'post_poll_1',
      author: _arisThorne,
      body:
          'NIFTY Sentiment Poll for this weekly expiry: Where do you expect the index to close? Vote below to see the collective community positioning 📊',
      createdAt: now.subtract(const Duration(hours: 3)),
      tickers: const <String>['NIFTY'],
      tags: const <String>['Poll', 'ExpiryWeek', 'MarketOutlook'],
      poll: CommunityPoll(
        id: 'poll_1',
        question: 'Where will NIFTY close this Thursday?',
        options: const <CommunityPollOption>[
          CommunityPollOption(
            id: 'opt_1',
            text: 'Above 24,600 (Bullish Expansion)',
            votes: 342,
          ),
          CommunityPollOption(
            id: 'opt_2',
            text: '24,200 - 24,600 (Rangebound)',
            votes: 512,
          ),
          CommunityPollOption(
            id: 'opt_3',
            text: 'Below 24,200 (Mean Reversion)',
            votes: 198,
          ),
        ],
        expiresAt: now.add(const Duration(days: 2)),
      ),
      likes: 289,
      reactions: const <String>['🚀', '👍', '💡'],
      comments: 48,
      reposts: 37,
      views: 6200,
    );

    final postNitish1 = CommunityPost(
      id: 'post_nitish_1',
      author: currentAuthor,
      sentiment: CommunitySentiment.bullish,
      body:
          'BANKNIFTY breaking out of the 15-minute consolidation range. Looking for follow-through momentum towards 52,200 resistance with tight trailing stops. Disciplined execution over emotion always. 📈',
      createdAt: now.subtract(const Duration(minutes: 45)),
      tickers: const <String>['BANKNIFTY'],
      tags: const <String>['Breakout', 'PriceAction', 'Execution'],
      tradeSetup: CommunityTradeSetup(
        ticker: 'BANKNIFTY 52000 CE',
        side: 'LONG',
        entry: '₹310.00',
        exit: '₹420.00',
        stopLoss: '₹265.00',
        target: '₹450.00',
        rMultiple: '+2.44R',
        pnl: '+₹24,750',
        isWin: true,
        candles: _generateCandles(16, 300.0, rising: true),
      ),
      likes: 56,
      reactions: const <String>['🚀', '👍'],
      comments: 12,
      reposts: 8,
      views: 1420,
    );

    final postA1 = CommunityPost(
      id: 'post_a1',
      author: _alexVance,
      isPinned: true,
      sentiment: CommunitySentiment.bullish,
      body:
          'NIFTY reclaimed the opening range with improving breadth. Waited for the retest instead of chasing the first expansion candle. Scaled out at 2R, trailing under the prior 15-min swing pivot.',
      createdAt: now.subtract(const Duration(hours: 2)),
      tickers: const <String>['NIFTY'],
      tags: const <String>['MarketStructure', 'PriceAction', 'Discipline'],
      tradeSetup: CommunityTradeSetup(
        ticker: 'NIFTY 24400 CE',
        side: 'LONG',
        entry: '₹142.50',
        exit: '₹188.00',
        stopLoss: '₹125.00',
        target: '₹200.00',
        rMultiple: '+2.4R',
        pnl: '+₹34,500',
        isWin: true,
        candles: _generateCandles(18, 140.0, rising: true),
      ),
      likes: 148,
      reactions: const <String>['🚀', '🔥', '👍'],
      comments: 19,
      reposts: 32,
      views: 3400,
      attachment: journalAttachment,
    );

    final postA2 = CommunityPost(
      id: 'post_a2',
      author: _alexVance,
      body:
          'Weekly review: best trades came from following the plan. The two avoidable losses both happened after moving stops without new information. Sticking strictly to the 2-Strike Rule next week.\n\nKey lesson: process over outcome. Every time.',
      createdAt: now.subtract(const Duration(days: 1)),
      tags: const <String>['WeeklyReview', 'Discipline', 'RiskRules'],
      likes: 94,
      comments: 11,
      reposts: 16,
      views: 2100,
      attachment: noteAttachment,
    );

    final postA3 = CommunityPost(
      id: 'post_a3',
      author: _alexVance,
      sentiment: CommunitySentiment.bullish,
      body:
          'RELIANCE broke out of a 3-week consolidation base on 2.5x volume. This was a textbook continuation breakout setup.',
      createdAt: now.subtract(const Duration(days: 3)),
      tickers: const <String>['RELIANCE'],
      tags: const <String>['Breakout', 'SwingTrade'],
      tradeSetup: CommunityTradeSetup(
        ticker: 'RELIANCE',
        side: 'LONG',
        entry: '₹2,890.00',
        exit: '₹2,955.00',
        stopLoss: '₹2,860.00',
        target: '₹3,020.00',
        rMultiple: '+2.8R',
        pnl: '+₹42,800',
        isWin: true,
        candles: _generateCandles(14, 2860.0, rising: true),
      ),
      likes: 215,
      comments: 27,
      reposts: 48,
      views: 5800,
    );

    final postP1 = CommunityPost(
      id: 'post_p1',
      author: _priyaSharma,
      sentiment: CommunitySentiment.neutral,
      body:
          'BANKNIFTY Iron Condor expiry day setup: sold 47500CE + 46500PE. IV crush post 10AM worked perfectly. This is why I love selling options on expiry days! 🎯',
      createdAt: now.subtract(const Duration(hours: 5)),
      tickers: const <String>['BANKNIFTY'],
      tags: const <String>['Options', 'IronCondor', 'IVCrush'],
      tradeSetup: CommunityTradeSetup(
        ticker: 'BANKNIFTY Weekly',
        side: 'SHORT',
        entry: '₹180 (net premium)',
        exit: '₹45',
        stopLoss: '₹240',
        target: '₹20',
        rMultiple: '+3.1R',
        pnl: '+₹67,500',
        isWin: true,
        candles: _generateCandles(12, 47200.0, rising: false),
      ),
      likes: 312,
      comments: 44,
      reposts: 71,
      views: 9200,
    );

    final postM1 = CommunityPost(
      id: 'post_m1',
      author: _marcoSilva,
      repostedBy: 'Alex Vance',
      body:
          '🚀 New module just dropped for AlphaJournal members: "Earnings Season Playbook" — how I trade pre-earnings IV expansion and post-earnings crush. 47 real trades, video walkthroughs, Q&A session this weekend.\n\nUse code ALPHAJOURNAL-MARCO-2026 for 30% off.',
      createdAt: now.subtract(const Duration(hours: 8)),
      tickers: const <String>['AAPL', 'MSFT', 'NVDA'],
      tags: const <String>['Education', 'EarningsSeason', 'OptionsStrategy'],
      linkPreview: const CommunityLinkPreview(
        title: 'Earnings Season Playbook — Marco Silva Education',
        domain: 'marcosilva.edu',
        description:
            'Complete earnings trading system with 47 documented trades and video walkthroughs.',
      ),
      likes: 587,
      comments: 82,
      reposts: 134,
      views: 18700,
    );

    final postW1 = CommunityPost(
      id: 'post_w1',
      author: _alphajournalWire,
      body:
          '🔴 BREAKING: RBI holds repo rate at 6.50% for the 7th consecutive meeting. MPC remains focused on "withdrawal of accommodation." Markets expecting a rate cut cycle to begin Q4 2026. FII flows may accelerate into domestic banking names.',
      createdAt: now.subtract(const Duration(minutes: 45)),
      tickers: const <String>['NIFTYBANK', 'HDFCBANK', 'ICICIBANK'],
      tags: const <String>['RBI', 'MonetaryPolicy', 'MacroIndia'],
      likes: 1240,
      comments: 156,
      reposts: 389,
      views: 54000,
    );

    final postQ1 = CommunityPost(
      id: 'post_q1',
      author: _arisThorne,
      body:
          'Backtest results: My momentum strategy on the S&P 500 universe, 2015–2026. Annualised return 23.4%, Sharpe 1.82, Max Drawdown 14.2%. Full Python code and methodology write-up in the thread 🧵',
      createdAt: now.subtract(const Duration(hours: 14)),
      tickers: const <String>['SPY', 'QQQ'],
      tags: const <String>['Quantitative', 'Momentum', 'Backtest'],
      likes: 834,
      comments: 91,
      reposts: 207,
      views: 23400,
      attachment: strategyAttachment,
    );

    final postE1 = CommunityPost(
      id: 'post_e1',
      author: _elenaRostova,
      isDeskAlert: true,
      sentiment: CommunitySentiment.bearish,
      body:
          '🚨 DESK RISK ALERT: Gross prop exposure reduced by 15% firm-wide heading into RBI announcement and US CPI release. Elevated tail-risk detected across derivative surface. Capital preservation first.',
      createdAt: now.subtract(const Duration(hours: 18)),
      tags: const <String>['RiskManagement', 'PropDesk', 'MacroRisk'],
      likes: 423,
      comments: 67,
      reposts: 89,
      views: 11200,
    );

    final postR1 = CommunityPost(
      id: 'post_r1',
      author: _rajeshPatel,
      body:
          'USD/INR looks stretched near 84.50. Historically, RBI intervenes around these levels via FX swaps. Watching for a quick mean-reversion to 83.80. Positioning via options to limit drawdown.',
      createdAt: now.subtract(const Duration(hours: 28)),
      tickers: const <String>['USDINR'],
      tags: const <String>['FX', 'GlobalMacro', 'RBIIntervention'],
      likes: 178,
      comments: 23,
      views: 4100,
    );

    _forYouPosts = <CommunityPost>[
      postNitish1,
      postA1,
      postPoll,
      postW1,
      postP1,
      postM1,
      postQ1,
      postA2,
      postE1,
      postR1,
      postA3,
    ];
    _followingPosts = <CommunityPost>[
      postNitish1,
      postA1,
      postPoll,
      postW1,
      postA2,
      postE1,
      postA3,
    ];
    _signalPosts = <CommunityPost>[postNitish1, postA1, postP1, postA3, postQ1];
  }

  void _seedComments() {
    final now = DateTime.now();
    _commentsByPost = <String, List<CommunityComment>>{
      'post_nitish1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_n1',
          postId: 'post_nitish1',
          author: _priyaSharma,
          body:
              'Massive move on \$RELIANCE! The weekly volume expansion confirmed the structural breakout before open. Targeting 3,020 next?',
          createdAt: now.subtract(const Duration(minutes: 55)),
          likes: 18,
          reactions: const <String>['🚀', '👍'],
          sentiment: 'BULLISH',
          replies: <CommunityComment>[
            CommunityComment(
              id: 'cmt_n1_r1',
              postId: 'post_nitish1',
              parentCommentId: 'cmt_n1',
              author: _alexVance,
              body:
                  'Spot on Priya. Confluence of 50-day EMA and VWAP retest provided an optimal 1:3.4 risk-to-reward entry.',
              createdAt: now.subtract(const Duration(minutes: 35)),
              likes: 9,
              reactions: const <String>['💡'],
              sentiment: 'INSIGHTFUL',
            ),
          ],
        ),
        CommunityComment(
          id: 'cmt_n2',
          postId: 'post_nitish1',
          author: _arisThorne,
          body:
              'Notice the delivery percentage was above 62%. Strong institutional accumulation rather than speculative intraday churn.',
          createdAt: now.subtract(const Duration(minutes: 25)),
          likes: 11,
          reactions: const <String>['🔥', '👍'],
          sentiment: 'INSIGHTFUL',
        ),
      ],
      'post_a1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_1',
          postId: 'post_a1',
          author: _priyaSharma,
          body:
              'Love the patience! Waiting for the retest is so hard but always pays off. What was your initial RR on this setup?',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 40)),
          likes: 12,
          reactions: const <String>['👍', '🚀'],
          sentiment: 'BULLISH',
          replies: <CommunityComment>[
            CommunityComment(
              id: 'cmt_1_r1',
              postId: 'post_a1',
              parentCommentId: 'cmt_1',
              author: _alexVance,
              body:
                  'Initial stop was placed exactly 0.5% below the consolidation low, delivering a 1:2.8 R:R before scaling out.',
              createdAt: now.subtract(const Duration(hours: 1, minutes: 15)),
              likes: 5,
              reactions: const <String>['💡'],
              sentiment: 'INSIGHTFUL',
            ),
          ],
        ),
        CommunityComment(
          id: 'cmt_2',
          postId: 'post_a1',
          author: _arisThorne,
          body:
              'Clean execution. The volume confirmation before entry is what separates this from a random trade. 👏',
          createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
          likes: 8,
          reactions: const <String>['🔥'],
          sentiment: 'INSIGHTFUL',
        ),
        CommunityComment(
          id: 'cmt_3',
          postId: 'post_a1',
          author: _rajeshPatel,
          body:
              'Alex, do you use VWAP as an anchor for the opening range, or pure H/L of first candle?',
          createdAt: now.subtract(const Duration(minutes: 45)),
          likes: 3,
          reactions: const <String>['💡'],
        ),
      ],
      'post_poll': <CommunityComment>[
        CommunityComment(
          id: 'cmt_poll_1',
          postId: 'post_poll',
          author: _elenaRostova,
          body:
              'Voted 25,000+. The call open interest unwinding at 24,800 points towards an imminent gamma squeeze.',
          createdAt: now.subtract(const Duration(hours: 2)),
          likes: 14,
          reactions: const <String>['🚀', '👍'],
          sentiment: 'BULLISH',
        ),
      ],
      'post_w1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_w1',
          postId: 'post_w1',
          author: _rajeshPatel,
          body:
              'The liquidity sweep on BankNifty was textbook today. 48,200 put buyers got completely trapped.',
          createdAt: now.subtract(const Duration(hours: 3)),
          likes: 7,
          reactions: const <String>['💡'],
          sentiment: 'INSIGHTFUL',
        ),
      ],
      'post_p1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_4',
          postId: 'post_p1',
          author: _alexVance,
          body:
              'Priya crushing it as usual. Expiry day IV crush is such a reliable edge.',
          createdAt: now.subtract(const Duration(hours: 4)),
          likes: 22,
          reactions: const <String>['🔥', '🚀'],
          sentiment: 'BULLISH',
          replies: <CommunityComment>[
            CommunityComment(
              id: 'cmt_4_r1',
              postId: 'post_p1',
              parentCommentId: 'cmt_4',
              author: _priyaSharma,
              body:
                  'Thanks Alex! Theta decay between 1:30 PM and 3:00 PM did all the heavy lifting.',
              createdAt: now.subtract(const Duration(hours: 3, minutes: 20)),
              likes: 8,
              reactions: const <String>['❤️'],
            ),
          ],
        ),
      ],
      'post_m1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_m1',
          postId: 'post_m1',
          author: _arisThorne,
          body:
              'Tracking momentum breadth across Midcaps. Advance/Decline ratio looks promising for continuation.',
          createdAt: now.subtract(const Duration(hours: 5)),
          likes: 6,
          reactions: const <String>['💡'],
          sentiment: 'BULLISH',
        ),
      ],
      'post_q1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_q1',
          postId: 'post_q1',
          author: _priyaSharma,
          body:
              'Quantitative hedge ratios on the pair trade look tightly bounded. Sharpe ratio above 2.1 is stellar.',
          createdAt: now.subtract(const Duration(hours: 6)),
          likes: 15,
          reactions: const <String>['🚀', '💡'],
          sentiment: 'INSIGHTFUL',
        ),
      ],
      'post_a2': <CommunityComment>[
        CommunityComment(
          id: 'cmt_a2',
          postId: 'post_a2',
          author: _elenaRostova,
          body:
              'Order book depth showed aggressive bids absorbing limit offers at the support pivot. Great catch.',
          createdAt: now.subtract(const Duration(hours: 12)),
          likes: 9,
          reactions: const <String>['🔥'],
          sentiment: 'BULLISH',
        ),
      ],
      'post_e1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_e1',
          postId: 'post_e1',
          author: _rajeshPatel,
          body:
              'Wise decision Elena. Preserving dry powder during high-volatility macro prints always beats taking unnecessary beta.',
          createdAt: now.subtract(const Duration(hours: 16)),
          likes: 31,
          reactions: const <String>['💡', '👍'],
          sentiment: 'BEARISH',
        ),
      ],
      'post_r1': <CommunityComment>[
        CommunityComment(
          id: 'cmt_r1',
          postId: 'post_r1',
          author: _arisThorne,
          body:
              'The FX forward premia is pricing in minimal depreciation here. Good risk:reward on the collar structure.',
          createdAt: now.subtract(const Duration(hours: 24)),
          likes: 8,
          reactions: const <String>['💡'],
        ),
      ],
      'post_a3': <CommunityComment>[
        CommunityComment(
          id: 'cmt_a3',
          postId: 'post_a3',
          author: _priyaSharma,
          body:
              'VWAP band expansion setup executed to perfection. Looking forward to the post-market review.',
          createdAt: now.subtract(const Duration(hours: 30)),
          likes: 10,
          reactions: const <String>['🚀', '👍'],
          sentiment: 'BULLISH',
        ),
      ],
    };
  }

  void _seedTrending() {
    _trending = const <CommunityTrendItem>[
      CommunityTrendItem(
        id: 't1',
        topic: '#NIFTYBreakout',
        category: 'Business & Finance · Trending',
        postCount: '48.2K posts',
      ),
      CommunityTrendItem(
        id: 't2',
        topic: '\$BTC',
        category: 'Crypto · Trending',
        postCount: '204K posts',
      ),
      CommunityTrendItem(
        id: 't3',
        topic: '#RBIPolicy',
        category: 'India · Trending',
        postCount: '72.1K posts',
      ),
      CommunityTrendItem(
        id: 't4',
        topic: '#EarningsSeason',
        category: 'Markets · Trending',
        postCount: '91.5K posts',
      ),
      CommunityTrendItem(
        id: 't5',
        topic: '\$NVDA',
        category: 'Technology · Trending',
        postCount: '183K posts',
      ),
    ];
  }

  void _seedNotifications() {
    final now = DateTime.now();
    _notifications = <CommunityNotificationItem>[
      CommunityNotificationItem(
        id: 'n_sec_1',
        type: CommunityNotificationType.security,
        createdAt: now.subtract(const Duration(minutes: 1)),
        title: 'Security Alert',
        body:
            "Someone's trying to log into your AlphaJournal account. Let us know if it's you.",
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n_sec_2',
        type: CommunityNotificationType.security,
        createdAt: now.subtract(const Duration(minutes: 2)),
        title: 'Security Alert',
        body:
            "Someone's trying to log into your AlphaJournal account. Let us know if it's you.",
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n1',
        actor: _priyaSharma,
        type: CommunityNotificationType.like,
        createdAt: now.subtract(const Duration(minutes: 5)),
        title: 'New Like',
        body:
            'priya_sharma liked your post: "NIFTY reclaimed the opening range…"',
        postSnippet: 'NIFTY reclaimed the opening range…',
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n2',
        actor: _marcoSilva,
        type: CommunityNotificationType.follow,
        createdAt: now.subtract(const Duration(minutes: 20)),
        title: 'New Follower',
        body: 'marco_silva started following you.',
        read: false,
        isFollowingBack: false,
      ),
      CommunityNotificationItem(
        id: 'n_trade_1',
        type: CommunityNotificationType.tradeExecution,
        createdAt: now.subtract(const Duration(hours: 1)),
        title: 'Trade Executed',
        body:
            'Bought 50 AAPL @ \$185.50 on SMART route. Execution latency: 4ms.',
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n3',
        actor: _arisThorne,
        type: CommunityNotificationType.comment,
        createdAt: now.subtract(const Duration(days: 6)),
        title: 'New Comment',
        body:
            'aris_thorne and 12 others liked your comment: "Got mine just for 800 rs. 😂 And bro just spent almost 2 lakh ju…"',
        postSnippet:
            'Got mine just for 800 rs. 😂 And bro just spent almost 2 lakh ju…',
        read: true,
      ),
      CommunityNotificationItem(
        id: 'n4',
        actor: _alphajournalWire,
        type: CommunityNotificationType.repost,
        createdAt: now.subtract(const Duration(days: 8)),
        read: true,
        title: 'New Repost',
        body:
            'alphajournal_wire, deepanshukumar and others reposted your setup.',
        postSnippet: 'RBI holds repo rate at 6.50%…',
      ),
    ];
  }

  void _seedDirectMessages() {
    final now = DateTime.now();
    _conversations = <CommunityConversation>[
      CommunityConversation(
        id: 'conv_usr_priya_sharma',
        peer: _priyaSharma,
        lastMessage: 'Check out the Iron Condor Greeks on 47500CE!',
        updatedAt: now.subtract(const Duration(minutes: 25)),
        unreadCount: 1,
      ),
      CommunityConversation(
        id: 'conv_usr_marco_silva',
        peer: _marcoSilva,
        lastMessage: 'Thanks for sharing that weekly review, Alex.',
        updatedAt: now.subtract(const Duration(hours: 3)),
        unreadCount: 0,
      ),
      CommunityConversation(
        id: 'conv_usr_aris_thorne',
        peer: _arisThorne,
        lastMessage: 'Will look into the slippage model tonight.',
        updatedAt: now.subtract(const Duration(days: 1)),
        unreadCount: 0,
      ),
    ];

    _messagesByConversation['conv_usr_priya_sharma'] = <CommunityChatMessage>[
      CommunityChatMessage(
        id: 'm1',
        senderId: _priyaSharma.id,
        text: 'Hey Alex! How are you managing delta risk on expiry today?',
        sentAt: now.subtract(const Duration(hours: 1)),
      ),
      CommunityChatMessage(
        id: 'm2',
        senderId: _alexVance.id,
        text:
            'Hey Priya, keeping it tight with 15-min swing pivots. Scaled out half at 2R already.',
        sentAt: now.subtract(const Duration(minutes: 45)),
        isMine: true,
      ),
      CommunityChatMessage(
        id: 'm3',
        senderId: _priyaSharma.id,
        text: 'Check out the Iron Condor Greeks on 47500CE!',
        sentAt: now.subtract(const Duration(minutes: 25)),
      ),
    ];

    // Seed Live Audio Spaces (fallback for offline demo mode only)
    if (!SupabaseConfig.isConfigured) {
      _liveRooms = <LiveAudioRoom>[
        LiveAudioRoom(
          id: 'room_nifty_expiry',
          title: 'Nifty & BankNifty Live Expiry Floor',
          topic: 'VWAP breakout & strong CE OI unwinding at 24,800 strike',
          host: _rajeshPatel,
          category: 'Options & Expiry',
          status: LiveRoomStatus.live,
          listenerCount: 142,
          speakers: const <String>[
            'Rajesh Sharma, CMT',
            'Sarah Chen, Quant',
            'Vikram Joshi',
          ],
          pinnedSetup: const LivePinnedSetup(
            ticker: 'NIFTY 24,850 CE',
            side: 'LONG',
            entry: 142.50,
            stopLoss: 118.00,
            target: 210.00,
            note: 'VWAP breakout with strong CE OI unwinding at 24,800 strike.',
          ),
          startedAt: now.subtract(const Duration(minutes: 42)),
          isRecording: true,
          tags: const <String>['#Nifty', '#Options', '#ExpirySpecial'],
        ),
        LiveAudioRoom(
          id: 'room_crypto_macro',
          title: 'Crypto Alpha Desk: BTC ATH Retest & Altcoin Liquidity',
          topic: 'Spot ETF inflows, funding rates, and Solana breakout setups',
          host: _marcoSilva,
          category: 'Crypto',
          status: LiveRoomStatus.live,
          listenerCount: 89,
          speakers: const <String>[
            'Marco Silva',
            'Elena Rostova',
            'Dr. Aris Thorne',
          ],
          pinnedSetup: const LivePinnedSetup(
            ticker: 'BTC/USDT',
            side: 'LONG',
            entry: 94200.00,
            stopLoss: 91800.00,
            target: 104000.00,
            note: 'Daily 21 EMA bounce with open interest expansion.',
          ),
          startedAt: now.subtract(const Duration(minutes: 25)),
          isRecording: false,
          tags: const <String>['#Bitcoin', '#Crypto', '#Breakout'],
        ),
        LiveAudioRoom(
          id: 'room_post_expiry',
          title: 'Post-Expiry Debrief & Journaling',
          topic:
              'Analyzing gamma squeezes, mistake reviews, and journaling execution stats',
          host: _elenaRostova,
          category: 'Education',
          status: LiveRoomStatus.scheduled,
          listenerCount: 0,
          speakers: const <String>['Elena Rostova', 'Sarah Chen, Quant'],
          scheduledFor: now.add(const Duration(hours: 4)),
          isRecording: true,
          tags: const <String>['#Debrief', '#RiskManagement', '#Journal'],
        ),
        LiveAudioRoom(
          id: 'room_pre_market',
          title: 'Pre-Market Gameplan: Global Cues & Gift Nifty',
          topic: 'US Fed commentary, crude oil trends, and morning open levels',
          host: _priyaSharma,
          category: 'Macro',
          status: LiveRoomStatus.scheduled,
          listenerCount: 0,
          speakers: const <String>['Priya Sharma', 'Rajesh Patel'],
          scheduledFor: now.add(const Duration(hours: 18)),
          isRecording: true,
          tags: const <String>['#PreMarket', '#Macro', '#Levels'],
        ),
      ];
    } else {
      _liveRooms = <LiveAudioRoom>[];
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static List<UiCandle> _generateCandles(
    int count,
    double basePrice, {
    bool rising = true,
  }) {
    final rng = math.Random(42);
    final List<UiCandle> candles = <UiCandle>[];
    double price = basePrice;
    for (int i = 0; i < count; i++) {
      final trend = rising ? 0.006 : -0.005;
      final noise = (rng.nextDouble() - 0.48) * 0.03;
      final close = price * (1 + trend + noise);
      final high = math.max(price, close) * (1 + rng.nextDouble() * 0.008);
      final low = math.min(price, close) * (1 - rng.nextDouble() * 0.008);
      final open = price;
      candles.add(
        UiCandle(
          time: DateTime.now().subtract(Duration(minutes: (count - i) * 15)),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: 10000 + rng.nextInt(50000).toDouble(),
        ),
      );
      price = close;
    }
    return candles;
  }

  static List<AppWritingPostAttachment> _buildAttachableRecords() {
    final demo = DemoDataSource.instance;
    return <AppWritingPostAttachment>[
      ...demo.notes().map(AppWritingPostAttachment.note),
      ...demo.trades().map(AppWritingPostAttachment.journal),
      ...demo.strategies().map(AppWritingPostAttachment.strategy),
    ];
  }
}
