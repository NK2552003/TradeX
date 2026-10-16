import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:tradex/features/market_data/data/asset_market_repository.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/linking/entity_ticker_links_repository.dart';
import 'package:uuid/uuid.dart';

/// Reactive repository backing the community platform with live Supabase sync
/// and offline resilience.
class CommunityRepository extends ChangeNotifier {
  CommunityRepository() {
    _initSeedData();
    if (SupabaseConfig.isConfigured) {
      unawaited(init());
    }
  }

  static const String _demoUserId = '00000000-0000-0000-0000-000000000001';
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _initialized = false;
  bool _subscribedToRealtime = false;
  RealtimeChannel? _realtimeChannel;

  RealtimeChannel? get realtimeChannel => _realtimeChannel;

  String _resolveUserId() {
    if (SupabaseConfig.isConfigured) {
      final user = SupabaseConfig.client?.auth.currentUser;
      if (user != null && user.id.isNotEmpty) {
        return user.id;
      }
    }
    return _demoUserId;
  }

  bool _isUuid(String? id) => id != null && _uuidRegex.hasMatch(id);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (SupabaseConfig.isConfigured) {
      _initRealtime();
      await fetchFromSupabase();
    }
  }

  void _initRealtime() {
    if (_subscribedToRealtime || !SupabaseConfig.isConfigured) return;
    _subscribedToRealtime = true;

    try {
      final client = SupabaseConfig.client!;
      _realtimeChannel = client
          .channel('public:community_posts_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'community_posts',
            callback: (PostgresChangePayload payload) {
              fetchFromSupabase();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'community_comments',
            callback: (PostgresChangePayload payload) {
              fetchFromSupabase();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'community_post_attachments',
            callback: (PostgresChangePayload payload) {
              fetchFromSupabase();
            },
          )
        ..subscribe();
    } catch (e) {
      debugPrint('[CommunityRepository] Realtime subscription error: $e');
    }
  }

  Future<void> fetchFromSupabase() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final client = SupabaseConfig.client!;
      final targetUserId = _resolveUserId();

      final Set<String> likedPostIds = <String>{};
      final Set<String> bookmarkedPostIds = <String>{};
      final Set<String> followedAuthorIds = <String>{};

      try {
        final likesRes = await client
            .from('community_likes')
            .select('post_id')
            .eq('user_id', targetUserId);
        for (final item in likesRes as List) {
          final id = item['post_id']?.toString();
          if (id != null) likedPostIds.add(id);
        }
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching likes: $e');
      }

      try {
        final bookmarksRes = await client
            .from('community_bookmarks')
            .select('post_id')
            .eq('user_id', targetUserId);
        for (final item in bookmarksRes as List) {
          final id = item['post_id']?.toString();
          if (id != null) bookmarkedPostIds.add(id);
        }
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching bookmarks: $e');
      }

      try {
        final followsRes = await client
            .from('community_follows')
            .select('following_id')
            .eq('follower_id', targetUserId);
        for (final item in followsRes as List) {
          final id = item['following_id']?.toString();
          if (id != null) followedAuthorIds.add(id);
        }
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching follows: $e');
      }

      final res = await client
          .from('community_posts')
          .select(
            '*, profiles(id, username, display_name, avatar_url, bio, role, win_rate, trading_style, verified, followers_count, following_count, posts_count), community_post_trade_setups(*), community_post_attachments(*)',
          )
          .order('created_at', ascending: false);

      final List<CommunityPost> allPosts = [];
      for (final item in res as List) {
        final row = item as Map<String, dynamic>;
        final postId = row['id']?.toString() ?? '';
        final authorProfile = row['profiles'] as Map<String, dynamic>?;
        final authorId = row['author_id']?.toString() ?? '';

        final author = CommunityAuthor(
          id: authorId,
          handle: authorProfile?['username'] as String? ?? 'trader',
          displayName: authorProfile?['display_name'] as String? ??
              authorProfile?['username'] as String? ??
              'Trader',
          userRole: _parseUserRole(authorProfile?['role'] as String?),
          avatarUrl: authorProfile?['avatar_url'] as String?,
          bio: authorProfile?['bio'] as String?,
          verified: authorProfile?['verified'] as bool? ?? false,
          isFollowing: followedAuthorIds.contains(authorId),
          followers:
              (authorProfile?['followers_count'] as num?)?.toInt() ?? 0,
          following:
              (authorProfile?['following_count'] as num?)?.toInt() ?? 0,
          winRate: (authorProfile?['win_rate'] as num?)?.toDouble(),
          tradingStyle: authorProfile?['trading_style'] as String?,
          postsCount:
              (authorProfile?['posts_count'] as num?)?.toInt() ?? 0,
        );

        CommunityTradeSetup? setup;
        final setupsList = row['community_post_trade_setups'];
        if (setupsList != null && setupsList is List && setupsList.isNotEmpty) {
          final s = setupsList.first as Map<String, dynamic>;
          setup = CommunityTradeSetup(
            ticker: s['ticker'] as String? ?? '',
            side: (s['side']?.toString().toUpperCase() == 'SHORT') ? 'SHORT' : 'LONG',
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
              final img = url ?? refId;
              if (img.isNotEmpty && !imageUrls.contains(img)) {
                imageUrls.add(img);
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
            }
          }
        }

        final post = CommunityPost(
          id: postId,
          author: author,
          body: row['body'] as String? ?? '',
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
          isPinned: row['is_pinned'] as bool? ?? false,
          isPublic: row['is_public'] as bool? ?? true,
          tickers: (row['tickers'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          tags: (row['tags'] as List?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          tradeSetup: setup,
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
          imageUrls: imageUrls,
          attachment: attachment,
          likes: (row['likes_count'] as num?)?.toInt() ?? 0,
          comments: (row['comments_count'] as num?)?.toInt() ?? 0,
          reposts: (row['reposts_count'] as num?)?.toInt() ?? 0,
          views: (row['views_count'] as num?)?.toInt() ?? 0,
          liked: likedPostIds.contains(postId),
          bookmarked: bookmarkedPostIds.contains(postId),
        );

        allPosts.add(post);
      }

      if (_disposed) return;
      _forYouPosts = allPosts;
      _followingPosts = allPosts
          .where((p) => followedAuthorIds.contains(p.author.id))
          .toList();
      _signalPosts = allPosts.where((p) => p.tradeSetup != null).toList();
      _rebuildBookmarks();

      try {
        final commentsRes = await client
            .from('community_comments')
            .select(
              '*, profiles(id, username, display_name, avatar_url, role)',
            )
            .order('created_at', ascending: true);

        final Map<String, List<CommunityComment>> newComments = {};
        for (final item in commentsRes as List) {
          final row = item as Map<String, dynamic>;
          final postId = row['post_id']?.toString();
          if (postId == null) continue;

          final profile = row['profiles'] as Map<String, dynamic>?;
          final commentAuthor = CommunityAuthor(
            id: row['author_id']?.toString() ?? '',
            handle: profile?['username'] as String? ?? 'trader',
            displayName: profile?['display_name'] as String? ?? 'Trader',
            userRole: _parseUserRole(profile?['role'] as String?),
            avatarUrl: profile?['avatar_url'] as String?,
          );

          final comment = CommunityComment(
            id: row['id']?.toString() ?? '',
            postId: postId,
            author: commentAuthor,
            body: row['body'] as String? ?? '',
            createdAt:
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                    DateTime.now(),
            likes: (row['likes_count'] as num?)?.toInt() ?? 0,
            parentCommentId: row['parent_id']?.toString(),
          );

          (newComments[postId] ??= <CommunityComment>[]).add(comment);
        }
        _commentsByPost = newComments;
      } catch (e) {
        debugPrint('[CommunityRepository] Error fetching comments: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[CommunityRepository] fetchFromSupabase error: $e');
    }
  }

  UserRole _parseUserRole(String? roleStr) {
    if (roleStr == null) return UserRole.customer;
    final lower = roleStr.toLowerCase();
    if (lower.contains('admin')) return UserRole.userAdmin;
    if (lower.contains('affiliate')) return UserRole.affiliate;
    return UserRole.customer;
  }

  bool _disposed = false;
  Future<void>? _marketLoad;
  String? marketDataError;
  MarketSnapshot? marketSnapshot;
  Future<void> loadMarketData({AssetMarketRepository? source}) =>
      _marketLoad ??= _loadMarketData(source ?? AssetMarketRepository());
  Future<void> _loadMarketData(AssetMarketRepository source) async {
    try {
      final snapshot = await source.snapshot();
      if (_disposed) return;
      marketSnapshot = snapshot;
      _news = snapshot.articles
          .map(
            (a) => CommunityNewsItem(
              id: a.link.isEmpty ? a.title : a.link,
              headline: a.title,
              source: a.publisher,
              publishedAt: a.publishedAt ?? DateTime(1970),
              summary: a.summary,
              articleUrl: a.link,
              thumbnail: a.thumbnailUrl,
              relatedTickers: a.tickers,
            ),
          )
          .toList();
      notifyListeners();
    } catch (_) {
      if (!_disposed) {
        marketDataError = 'Market assets unavailable';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Seed Authors
  // -------------------------------------------------------------------------

  late final CommunityAuthor _alexVance;
  late final CommunityAuthor _marcoSilva;
  late final CommunityAuthor _elenaRostova;
  late final CommunityAuthor _priyaSharma;
  late final CommunityAuthor _tradexWire;
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
  List<CommunityNewsItem> _news = <CommunityNewsItem>[];
  List<CommunityTrendItem> _trending = <CommunityTrendItem>[];
  List<CommunityNotificationItem> _notifications =
      <CommunityNotificationItem>[];
  bool _pushNotificationsPromptVisible = true;
  List<AppWritingPostAttachment> _attachableRecords =
      <AppWritingPostAttachment>[];

  final Set<String> _mutedUsers = <String>{};
  final Set<String> _blockedUsers = <String>{};
  final List<String> _customFeedTabs = <String>['Crypto', 'Options'];
  List<CommunityConversation> _conversations = <CommunityConversation>[];
  final Map<String, List<CommunityChatMessage>> _messagesByConversation =
      <String, List<CommunityChatMessage>>{};
  final Map<String, CommunityPostInsights> _insightsByPost =
      <String, CommunityPostInsights>{};
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
            !_mutedUsers.contains(p.author.id) &&
            !_blockedUsers.contains(p.author.id),
      )
      .toList();
  List<CommunityPost> get followingPosts => _followingPosts
      .where(
        (p) =>
            !_mutedUsers.contains(p.author.id) &&
            !_blockedUsers.contains(p.author.id),
      )
      .toList();
  List<CommunityPost> get signalPosts => _signalPosts
      .where(
        (p) =>
            !_mutedUsers.contains(p.author.id) &&
            !_blockedUsers.contains(p.author.id),
      )
      .toList();
  List<CommunityPost> get bookmarkedPosts => _bookmarkedPosts;
  List<CommunityAuthor> get suggestedTraders =>
      _suggestedTraders.where((a) => !_blockedUsers.contains(a.id)).toList();
  List<MapEntry<CommunityAuthor, double>> get leaderboard => _leaderboard;
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
  List<CommunityPost> get feedPosts => forYouPosts;
  List<CommunityAuthor> get topTraders => suggestedTraders;

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
    id: 'usr_nitish_trader',
    handle: 'nitish_trader',
    displayName: 'Nitish Kumar',
    userRole: UserRole.customer,
    verified: true,
    tier: AppTier.premium,
    followers: 12400,
    following: 234,
    winRate: 84.0,
    tradingStyle: 'Swing Trading',
    primaryMarket: 'Indian Equities & F&O',
    postsCount: 892,
  );

  CommunityAuthor? _currentAuthorOverride;
  CommunityAuthor get currentAuthor =>
      _currentAuthorOverride ?? _defaultCurrentUser;
  set currentAuthor(CommunityAuthor author) {
    _currentAuthorOverride = author;
    notifyListeners();
  }

  void updateCurrentAuthor(CommunityAuthor author) {
    if (_currentAuthorOverride?.id != author.id ||
        _currentAuthorOverride?.handle != author.handle ||
        _currentAuthorOverride?.displayName != author.displayName) {
      _currentAuthorOverride = author;
      Future<void>.microtask(notifyListeners);
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
    return _blockedUsers
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

  void addAttachableRecord(AppWritingPostAttachment record) {
    _attachableRecords = <AppWritingPostAttachment>[
      record,
      ..._attachableRecords,
    ];
    notifyListeners();
  }

  List<CommunityComment> commentsForPost(String postId) =>
      _commentsByPost[postId] ?? const <CommunityComment>[];

  List<CommunityPost> postsForAuthor(String authorId) {
    final seen = <String>{};
    final all = <CommunityPost>[
      ..._forYouPosts,
      ..._signalPosts,
      ..._followingPosts,
    ];
    return all.where((p) => p.author.id == authorId && seen.add(p.id)).toList();
  }

  CommunityAuthor? authorById(String id) {
    if (id == currentAuthor.id) return currentAuthor;
    final all = <CommunityAuthor>[
      _defaultCurrentUser,
      _alexVance,
      _marcoSilva,
      _elenaRostova,
      _priyaSharma,
      _tradexWire,
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

  /// @backend POST /api/v1/community/posts/{postId}/like
  /// Auth: Bearer token required
  /// Returns: { "liked": bool, "likes": int }
  void toggleLike(String postId) {
    _forYouPosts = _toggleLikeInList(_forYouPosts, postId);
    _followingPosts = _toggleLikeInList(_followingPosts, postId);
    _signalPosts = _toggleLikeInList(_signalPosts, postId);
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final post = _forYouPosts.cast<CommunityPost?>().firstWhere(
              (p) => p?.id == postId,
              orElse: () => null,
            );
        final isLikedNow = post?.liked ?? false;

        if (isLikedNow) {
          unawaited(client.from('community_likes').insert({
            'post_id': postId,
            'user_id': targetUserId,
          }).catchError((e) {
            debugPrint('[CommunityRepository] like insert error: $e');
          }));
        } else {
          unawaited(client
              .from('community_likes')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', targetUserId)
              .catchError((e) {
            debugPrint('[CommunityRepository] like delete error: $e');
          }));
        }
      } catch (e) {
        debugPrint('[CommunityRepository] toggleLike error: $e');
      }
    }
  }

  List<CommunityPost> _toggleLikeInList(List<CommunityPost> list, String id) {
    return list.map((p) {
      if (p.id != id) return p;
      return p.copyWith(
        liked: !p.liked,
        likes: p.liked ? p.likes - 1 : p.likes + 1,
      );
    }).toList();
  }

  /// @backend POST /api/v1/community/posts/{postId}/repost
  /// Auth: Bearer token required
  /// Returns: { "reposted": bool, "reposts": int }
  void toggleRepost(String postId) {
    _forYouPosts = _toggleRepostInList(_forYouPosts, postId);
    _followingPosts = _toggleRepostInList(_followingPosts, postId);
    _signalPosts = _toggleRepostInList(_signalPosts, postId);
    notifyListeners();
  }

  List<CommunityPost> _toggleRepostInList(List<CommunityPost> list, String id) {
    return list.map((p) {
      if (p.id != id) return p;
      return p.copyWith(
        reposted: !p.reposted,
        reposts: p.reposted ? p.reposts - 1 : p.reposts + 1,
      );
    }).toList();
  }

  /// @backend POST /api/v1/community/posts/{postId}/bookmark
  /// Auth: Bearer token required
  /// Returns: { "bookmarked": bool }
  void toggleBookmark(String postId) {
    CommunityPost? target;
    _forYouPosts = _forYouPosts.map((p) {
      if (p.id != postId) return p;
      target = p.copyWith(bookmarked: !p.bookmarked);
      return target!;
    }).toList();
    _followingPosts = _followingPosts.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(bookmarked: !p.bookmarked);
    }).toList();
    _signalPosts = _signalPosts.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(bookmarked: !p.bookmarked);
    }).toList();
    _rebuildBookmarks();
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final post = _forYouPosts.cast<CommunityPost?>().firstWhere(
              (p) => p?.id == postId,
              orElse: () => null,
            );
        final isBookmarkedNow = post?.bookmarked ?? false;

        if (isBookmarkedNow) {
          unawaited(client.from('community_bookmarks').insert({
            'post_id': postId,
            'user_id': targetUserId,
          }).catchError((e) {
            debugPrint('[CommunityRepository] bookmark insert error: $e');
          }));
        } else {
          unawaited(client
              .from('community_bookmarks')
              .delete()
              .eq('post_id', postId)
              .eq('user_id', targetUserId)
              .catchError((e) {
            debugPrint('[CommunityRepository] bookmark delete error: $e');
          }));
        }
      } catch (e) {
        debugPrint('[CommunityRepository] toggleBookmark error: $e');
      }
    }
  }

  void _rebuildBookmarks() {
    final all = <CommunityPost>[..._forYouPosts, ..._signalPosts];
    final seen = <String>{};
    _bookmarkedPosts = all.where((p) => p.bookmarked && seen.add(p.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// @backend POST /api/v1/community/posts/{postId}/comments
  /// Body: { "body": String, "parent_comment_id": String?, "sentiment": String? }
  /// Returns: CommunityComment JSON
  void addComment(
    String postId,
    String body, {
    CommunityAuthor? author,
    String? parentId,
    String? sentiment,
  }) {
    final a = author ?? _alexVance;
    final comment = CommunityComment(
      id: 'cmt_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      author: a,
      body: body,
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
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      try {
        final client = SupabaseConfig.client!;
        final targetUserId = _resolveUserId();
        final commentId = const Uuid().v4();
        unawaited(client.from('community_comments').insert({
          'id': commentId,
          'post_id': postId,
          'author_id': targetUserId,
          'body': body.trim(),
          if (parentId != null && _isUuid(parentId)) 'parent_id': parentId,
        }).catchError((e) {
          debugPrint('[CommunityRepository] addComment error: $e');
        }));
      } catch (e) {
        debugPrint('[CommunityRepository] addComment error: $e');
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
  void likeComment(String postId, String commentId, {String? reaction}) {
    final list = List<CommunityComment>.from(_commentsByPost[postId] ?? []);

    CommunityComment? updateRecursively(CommunityComment c) {
      if (c.id == commentId) {
        final bool wasLiked = c.liked;
        final String? currentReaction = c.userReaction;

        if (reaction != null && reaction.trim().isNotEmpty) {
          final targetReaction = reaction.trim();
          if (wasLiked && currentReaction == targetReaction) {
            // Tapped same reaction again: toggle off
            return c.copyWith(
              liked: false,
              likes: (c.likes - 1).clamp(0, 99999),
              userReaction: null,
            );
          } else {
            // New reaction or changing from one reaction to another
            return c.copyWith(
              liked: true,
              likes: wasLiked ? c.likes : c.likes + 1,
              userReaction: targetReaction,
            );
          }
        } else {
          // Direct Like button tapped
          if (wasLiked) {
            return c.copyWith(
              liked: false,
              likes: (c.likes - 1).clamp(0, 99999),
              userReaction: null,
            );
          } else {
            return c.copyWith(
              liked: true,
              likes: c.likes + 1,
              userReaction: '👍',
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
    }
  }

  /// @backend POST /api/v1/community/users/{traderId}/follow
  /// Returns: { "is_following": bool, "followers": int }
  void toggleFollow(String traderId) {
    _suggestedTraders = _suggestedTraders.map((a) {
      if (a.id != traderId) return a;
      return a.copyWith(
        isFollowing: !a.isFollowing,
        followers: a.isFollowing ? a.followers - 1 : a.followers + 1,
      );
    }).toList();
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(traderId)) {
      try {
        final client = SupabaseConfig.client!;
        final currentUserId = _resolveUserId();
        final trader = _suggestedTraders.cast<CommunityAuthor?>().firstWhere(
              (a) => a?.id == traderId,
              orElse: () => null,
            );
        final isFollowingNow = trader?.isFollowing ?? false;
        if (isFollowingNow) {
          unawaited(client.from('community_follows').insert({
            'follower_id': currentUserId,
            'following_id': traderId,
          }).catchError((e) {
            debugPrint('[CommunityRepository] toggleFollow insert error: $e');
          }));
        } else {
          unawaited(client
              .from('community_follows')
              .delete()
              .eq('follower_id', currentUserId)
              .eq('following_id', traderId)
              .catchError((e) {
            debugPrint('[CommunityRepository] toggleFollow delete error: $e');
          }));
        }
      } catch (e) {
        debugPrint('[CommunityRepository] toggleFollow error: $e');
      }
    }
  }

  /// @backend POST /api/v1/community/posts
  /// Body: Post create schema
  /// Returns: CommunityPost JSON
  void createPost({
    required String body,
    List<String> tickers = const <String>[],
    List<String> tags = const <String>[],
    CommunityTradeSetup? tradeSetup,
    String? imageUrl,
    List<String> imageUrls = const <String>[],
    AppWritingPostAttachment? attachment,
    CommunityPoll? poll,
    CommunityPost? quoted,
    CommunitySentiment? sentiment,
    CommunityReplyAudience replyAudience = CommunityReplyAudience.everyone,
    bool isDeskAlert = false,
    DateTime? scheduledFor,
    required CommunityAuthor author,
  }) {
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
      attachment: attachment,
      poll: poll,
      quoted: quoted,
      sentiment: sentiment,
      replyAudience: replyAudience,
      isDeskAlert: isDeskAlert,
      scheduledFor: scheduledFor,
      views: 1,
    );
    _forYouPosts = <CommunityPost>[post, ..._forYouPosts];
    _followingPosts = <CommunityPost>[post, ..._followingPosts];
    if (tradeSetup != null) {
      _signalPosts = <CommunityPost>[post, ..._signalPosts];
    }
    notifyListeners();

    if (SupabaseConfig.isConfigured) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          final userId = _resolveUserId();
          await client.from('community_posts').insert({
            'id': post.id,
            'author_id': userId,
            'title': tickers.isNotEmpty ? tickers.first : 'Post',
            'body': post.body,
            'kind': tradeSetup != null ? 'setup' : (isDeskAlert ? 'alert' : 'general'),
            'tickers': tickers,
            'tags': tags,
            'is_public': true,
            'visibility': 'public',
            'created_at': post.createdAt.toIso8601String(),
          });
          if (tradeSetup != null) {
            await client.from('community_post_trade_setups').insert({
              'post_id': post.id,
              'ticker': tradeSetup.ticker,
              'side': tradeSetup.side.toLowerCase(),
              'entry': double.tryParse(tradeSetup.entry) ?? 0.0,
              if (tradeSetup.stopLoss != null)
                'stop_loss': double.tryParse(tradeSetup.stopLoss!),
              if (tradeSetup.target != null)
                'target1': double.tryParse(tradeSetup.target!),
            });
          }
          for (final imgUrl in post.effectiveImageUrls) {
            await client.from('community_post_attachments').insert({
              'post_id': post.id,
              'kind': 'image',
              'ref_id': imgUrl,
              'title': 'Chart Image',
              'url': imgUrl,
            });
          }
          if (post.attachment != null) {
            final att = post.attachment!;
            await client.from('community_post_attachments').insert({
              'post_id': post.id,
              'kind': att.source.kind.name,
              'ref_id': att.source.id,
              'title': att.source.title,
              'url': att.source.subtitle,
            });
          }
        } catch (e) {
          debugPrint('[CommunityRepository] createPost Supabase error: $e');
        }
      }());
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
        final ext = filename != null && filename.contains('.')
            ? filename.split('.').last
            : (file != null && file.path.contains('.') ? file.path.split('.').last : 'png');
        final cleanName = '${const Uuid().v4()}.$ext';
        final storagePath = '$postId/$cleanName';

        if (bytes != null) {
          await client.storage.from('community-attachments').uploadBinary(
                storagePath,
                bytes,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
              );
        } else if (file != null) {
          final fileBytes = await file.readAsBytes();
          await client.storage.from('community-attachments').uploadBinary(
                storagePath,
                fileBytes,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
              );
        }
        return client.storage.from('community-attachments').getPublicUrl(storagePath);
      } catch (e) {
        debugPrint('[CommunityRepository] uploadAttachment error: $e');
      }
    }
    return file?.path ?? filename ?? '';
  }

  /// Resolves an attachment reference or storage path to a usable URL.
  Future<String> resolveAttachmentUrl(String ref) async {
    if (SupabaseConfig.isConfigured &&
        !ref.startsWith('http') &&
        !ref.contains(':\\') &&
        !ref.startsWith('file:') &&
        !ref.startsWith('data:')) {
      try {
        final client = SupabaseConfig.client!;
        return client.storage.from('community-attachments').getPublicUrl(ref);
      } catch (e) {
        debugPrint('[CommunityRepository] resolveAttachmentUrl error: $e');
      }
    }
    return ref;
  }

  /// @backend DELETE /api/v1/community/posts/{postId}
  /// Returns: { "success": true }
  void deletePost(String postId) {
    _forYouPosts = _forYouPosts.where((p) => p.id != postId).toList();
    _followingPosts = _followingPosts.where((p) => p.id != postId).toList();
    _signalPosts = _signalPosts.where((p) => p.id != postId).toList();
    _bookmarkedPosts = _bookmarkedPosts.where((p) => p.id != postId).toList();
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          await client.from('community_posts').delete().eq('id', postId);
        } catch (e) {
          debugPrint('[CommunityRepository] deletePost Supabase error: $e');
        }
      }());
    }

    unawaited(
      EntityTickerLinksRepository.instance.removeLinks(
        entityType: 'community_post',
        entityId: postId,
      ),
    );
  }

  /// @backend PATCH /api/v1/community/posts/{postId}
  /// Body: { "body": String, ... }
  /// Returns: CommunityPost JSON
  void editPost(
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
    CommunityReplyAudience? replyAudience,
    List<String>? imageUrls,
  }) {
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
      replyAudience: replyAudience,
      imageUrls: imageUrls,
    );
    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          await client.from('community_posts').update({
            'body': newBody,
            'tickers': ?tickers,
            'tags': ?tags,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', postId);

          if (imageUrls != null) {
            await client
                .from('community_post_attachments')
                .delete()
                .eq('post_id', postId)
                .eq('kind', 'image');
            for (final imgUrl in imageUrls) {
              await client.from('community_post_attachments').insert({
                'post_id': postId,
                'kind': 'image',
                'ref_id': imgUrl,
                'title': 'Chart Image',
                'url': imgUrl,
              });
            }
          }
          if (attachment != null) {
            await client
                .from('community_post_attachments')
                .delete()
                .eq('post_id', postId)
                .neq('kind', 'image');
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
                .neq('kind', 'image');
          }
        } catch (e) {
          debugPrint('[CommunityRepository] editPost Supabase error: $e');
        }
      }());
    }

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

  CommunityPost? setPostVisibility(String postId, bool isPublic) {
    CommunityPost? updated;
    CommunityPost update(CommunityPost p) {
      if (p.id == postId) {
        updated = p.copyWith(isPublic: isPublic);
        return updated!;
      }
      return p;
    }

    _forYouPosts = _forYouPosts.map(update).toList();
    _followingPosts = _followingPosts.map(update).toList();
    _signalPosts = _signalPosts.map(update).toList();
    _bookmarkedPosts = _bookmarkedPosts.map(update).toList();

    notifyListeners();

    if (SupabaseConfig.isConfigured && _isUuid(postId)) {
      unawaited(() async {
        try {
          final client = SupabaseConfig.client!;
          await client.from('community_posts').update({
            'is_public': isPublic,
            'visibility': isPublic ? 'public' : 'private',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', postId);
        } catch (e) {
          debugPrint('[CommunityRepository] setPostVisibility Supabase error: $e');
        }
      }());
    }

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
        return p.copyWith(
          poll: poll.copyWith(
            options: updatedOptions,
            votedOptionIndices: currentIndices,
            votedOptionIndex: currentIndices.isEmpty
                ? null
                : currentIndices.first,
          ),
        );
      } else {
        if (poll.hasVoted) return p;
        final opt = updatedOptions[optionIndex];
        updatedOptions[optionIndex] = opt.copyWith(votes: opt.votes + 1);
        return p.copyWith(
          poll: poll.copyWith(
            options: updatedOptions,
            votedOptionIndex: optionIndex,
            votedOptionIndices: [optionIndex],
          ),
        );
      }
    }).toList();
    notifyListeners();
  }

  /// @backend POST /api/v1/community/reports
  /// Body: { "target_id": String, "reason": String, "notes": String? }
  /// Returns: { "report_id": String, "status": "received" }
  void reportPost(
    String postId,
    CommunityReportReason reason, {
    String? notes,
  }) {
    // Dispatched to moderation queue.
    notifyListeners();
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
  void blockUser(String userId) {
    _blockedUsers.add(userId);
    notifyListeners();
  }

  /// @backend POST /api/v1/community/moderation/unblock
  /// Body: { "user_id": String }
  /// Returns: { "blocked": false }
  void unblockUser(String userId) {
    _blockedUsers.remove(userId);
    notifyListeners();
  }

  /// @backend GET /api/v1/community/posts/{postId}
  /// Returns: CommunityPost JSON
  CommunityPost? loadPostById(String postId) {
    final all = <CommunityPost>[
      ..._forYouPosts,
      ..._signalPosts,
      ..._followingPosts,
    ];
    try {
      return all.firstWhere((p) => p.id == postId);
    } catch (_) {
      return null;
    }
  }

  /// @backend GET /api/v1/community/posts/{postId}/insights
  /// Returns: CommunityPostInsights JSON
  CommunityPostInsights getPostInsights(String postId) {
    final existing = _insightsByPost[postId];
    if (existing != null) return existing;
    final post = loadPostById(postId);
    final insights = CommunityPostInsights(
      postId: postId,
      impressions: math.max(post?.views ?? 240, 320),
      engagements:
          (post?.likes ?? 12) +
          (post?.reposts ?? 4) +
          (post?.comments ?? 3) * 2,
      detailExpands: ((post?.views ?? 200) * 0.18).round(),
      profileVisits: ((post?.views ?? 200) * 0.05).round(),
      linkClicks: ((post?.views ?? 200) * 0.08).round(),
      shares: (post?.reposts ?? 2) * 2,
    );
    _insightsByPost[postId] = insights;
    return insights;
  }

  /// @backend GET /api/v1/community/search
  /// Query: q=..., category=...
  /// Returns: `List<CommunityPost>` JSON
  List<CommunityPost> searchPosts(String query, {String? category}) {
    if (query.trim().isEmpty) return _forYouPosts;
    final q = query.toLowerCase();
    return _forYouPosts.where((p) {
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
      _alexVance,
      _marcoSilva,
      _elenaRostova,
      _priyaSharma,
      _tradexWire,
      _arisThorne,
      _rajeshPatel,
      _sarahWong,
    ];
    return all.where((a) {
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

  void markAllNotificationsRead() {
    _notifications = _notifications.map((n) {
      if (n.read) return n;
      return CommunityNotificationItem(
        id: n.id,
        actor: n.actor,
        type: n.type,
        createdAt: n.createdAt,
        postSnippet: n.postSnippet,
        read: true,
      );
    }).toList();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Live Audio Spaces Controls
  // -------------------------------------------------------------------------

  void tuneIntoRoom(String roomId) {
    if (_tunedRoomId == roomId) return;
    _tunedRoomId = roomId;
    final index = _liveRooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _liveRooms[index];
      _liveRooms[index] = room.copyWith(listenerCount: room.listenerCount + 1);
    }
    notifyListeners();
  }

  void leaveRoom() {
    if (_tunedRoomId == null) return;
    final index = _liveRooms.indexWhere((r) => r.id == _tunedRoomId);
    if (index != -1) {
      final room = _liveRooms[index];
      _liveRooms[index] = room.copyWith(
        listenerCount: (room.listenerCount - 1).clamp(0, 999999),
      );
    }
    _tunedRoomId = null;
    _isHandRaised = false;
    notifyListeners();
  }

  void toggleMute() {
    _isAudioMuted = !_isAudioMuted;
    notifyListeners();
  }

  void toggleHandRaised() {
    _isHandRaised = !_isHandRaised;
    notifyListeners();
  }

  void toggleRoomReminder(String roomId) {
    final index = _liveRooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _liveRooms[index];
      _liveRooms[index] = room.copyWith(hasReminder: !room.hasReminder);
      notifyListeners();
    }
  }

  /// Keeps a completed host session available to public profile history.
  void endLiveRoom(String roomId) {
    final index = _liveRooms.indexWhere((room) => room.id == roomId);
    if (index < 0 || _liveRooms[index].host.id != currentAuthor.id) return;
    _liveRooms[index] = _liveRooms[index].copyWith(
      status: LiveRoomStatus.ended,
      endedAt: DateTime.now(),
    );
    if (_tunedRoomId == roomId) {
      _tunedRoomId = null;
      _isAudioMuted = true;
      _isHandRaised = false;
    }
    notifyListeners();
  }

  LiveAudioRoom createLiveRoom({
    required String title,
    required String topic,
    required String category,
    LivePinnedSetup? pinnedSetup,
    bool startNow = true,
    DateTime? scheduledFor,
    List<String> tags = const <String>[],
  }) {
    final id = 'room_${DateTime.now().millisecondsSinceEpoch}';
    final room = LiveAudioRoom(
      id: id,
      title: title,
      topic: topic,
      host: currentAuthor,
      category: category,
      status: startNow ? LiveRoomStatus.live : LiveRoomStatus.scheduled,
      listenerCount: startNow ? 1 : 0,
      speakers: <String>[currentAuthor.displayName],
      pinnedSetup: pinnedSetup,
      scheduledFor: scheduledFor,
      startedAt: startNow ? DateTime.now() : null,
      isRecording: true,
      tags: tags,
    );
    _liveRooms.insert(0, room);
    if (startNow) {
      _tunedRoomId = id;
    }
    notifyListeners();
    return room;
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
          'Official TradeX Partner & trading educator. Sharing setups, execution blueprints, and exclusive member discounts. 50K+ community members.',
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
      referralCode: 'TRADEX-MARCO-2026',
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

    _tradexWire = const CommunityAuthor(
      id: 'usr_tradex_wire',
      handle: 'tradex_wire',
      displayName: 'TradeX Market Wire',
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

    _attachableRecords = _buildAttachableRecords();
    _seedPosts();
    _seedComments();

    _seedTrending();
    _seedNotifications();
    _seedDirectMessages();
    _suggestedTraders = <CommunityAuthor>[
      _marcoSilva,
      _priyaSharma,
      _arisThorne,
      _rajeshPatel,
      _sarahWong,
      _tradexWire,
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
        .where((a) => a.kind == AppLinkKind.note)
        .firstOrNull;
    final AppWritingPostAttachment? journalAttachment = _attachableRecords
        .where((a) => a.kind == AppLinkKind.journal)
        .firstOrNull;
    final AppWritingPostAttachment? strategyAttachment = _attachableRecords
        .where((a) => a.kind == AppLinkKind.strategy)
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
          '🚀 New module just dropped for TradeX members: "Earnings Season Playbook" — how I trade pre-earnings IV expansion and post-earnings crush. 47 real trades, video walkthroughs, Q&A session this weekend.\n\nUse code TRADEX-MARCO-2026 for 30% off.',
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
      author: _tradexWire,
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
        id: 'n1',
        actor: _priyaSharma,
        type: CommunityNotificationType.like,
        createdAt: now.subtract(const Duration(minutes: 5)),
        postSnippet: 'NIFTY reclaimed the opening range…',
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n2',
        actor: _marcoSilva,
        type: CommunityNotificationType.follow,
        createdAt: now.subtract(const Duration(minutes: 20)),
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n3',
        actor: _arisThorne,
        type: CommunityNotificationType.repost,
        createdAt: now.subtract(const Duration(hours: 1)),
        postSnippet: 'RELIANCE broke out of a 3-week base…',
        read: false,
      ),
      CommunityNotificationItem(
        id: 'n4',
        actor: _tradexWire,
        type: CommunityNotificationType.signal,
        createdAt: now.subtract(const Duration(hours: 2)),
        read: true,
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

    // Seed Live Audio Spaces
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
