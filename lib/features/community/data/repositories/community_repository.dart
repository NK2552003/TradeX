import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Feed scopes offered by the community tab bar.
enum CommunityFeedScope { forYou, following, trending, saved }

String communityFeedScopeLabel(CommunityFeedScope scope) => switch (scope) {
  CommunityFeedScope.forYou => 'For you',
  CommunityFeedScope.following => 'Following',
  CommunityFeedScope.trending => 'Trending',
  CommunityFeedScope.saved => 'Saved',
};

/// A hashtag/ticker trending row in the community sidebar.
@immutable
class TrendingTopic {
  const TrendingTopic({
    required this.label,
    required this.posts,
    required this.changePercent,
  });

  final String label;
  final int posts;
  final double changePercent;
}

abstract class CommunityRepository {
  Future<List<AppPost>> getFeed(CommunityFeedScope scope, {String? query});
  Future<AppPost?> getPost(String id);
  Future<List<AppComment>> getComments(String postId);
  Future<AppPost> toggleLike(String postId);
  Future<AppPost> toggleSave(String postId);
  Future<AppPost> createPost(AppPost post);
  Future<void> deletePost(String id);
  Future<AppComment> addComment(String postId, AppComment comment);
  Future<List<AppTrader>> getSuggestedTraders();
  Future<List<AppTrader>> getFollowers();
  Future<List<AppTrader>> getFollowing();
  Future<AppTrader> toggleFollow(String traderId);
  Future<List<MapEntry<AppTrader, double>>> getLeaderboard(String period);
  Future<List<TrendingTopic>> getTrending();
}

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance {
    _posts = List<AppPost>.from(_source.posts());
    _traders = List<AppTrader>.from(_source.traders());
  }

  final DemoDataSource _source;
  late List<AppPost> _posts;
  late List<AppTrader> _traders;

  AppPost _copy(
    AppPost post, {
    bool? liked,
    bool? saved,
    int? likes,
    int? comments,
  }) => AppPost(
    id: post.id,
    author: post.author,
    body: post.body,
    createdAt: post.createdAt,
    type: post.type,
    tickers: post.tickers,
    imageUrl: post.imageUrl,
    attachments: post.attachments,
    likes: likes ?? post.likes,
    comments: comments ?? post.comments,
    liked: liked ?? post.liked,
    saved: saved ?? post.saved,
  );

  @override
  Future<List<AppPost>> getFeed(
    CommunityFeedScope scope, {
    String? query,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final String needle = (query ?? '').trim().toLowerCase();
    Iterable<AppPost> rows = _posts;
    switch (scope) {
      case CommunityFeedScope.forYou:
        break;
      case CommunityFeedScope.following:
        rows = rows.where((AppPost p) => p.author.isFollowing);
      case CommunityFeedScope.trending:
        rows = List<AppPost>.from(_posts)
          ..sort((AppPost a, AppPost b) => b.likes.compareTo(a.likes));
      case CommunityFeedScope.saved:
        rows = rows.where((AppPost p) => p.saved);
    }
    if (needle.isNotEmpty) {
      rows = rows.where(
        (AppPost p) =>
            p.body.toLowerCase().contains(needle) ||
            p.author.handle.toLowerCase().contains(needle) ||
            p.tickers.any((String t) => t.toLowerCase().contains(needle)),
      );
    }
    return rows.toList(growable: false);
  }

  @override
  Future<AppPost?> getPost(String id) async {
    for (final AppPost post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  @override
  Future<List<AppComment>> getComments(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<AppComment>.from(
      _extraComments[postId] ?? const <AppComment>[],
    )..addAll(_source.comments(postId));
  }

  final Map<String, List<AppComment>> _extraComments =
      <String, List<AppComment>>{};

  @override
  Future<AppPost> toggleLike(String postId) async {
    final int index = _posts.indexWhere((AppPost p) => p.id == postId);
    if (index < 0) throw StateError('Post $postId not found');
    final AppPost current = _posts[index];
    final AppPost updated = _copy(
      current,
      liked: !current.liked,
      likes: current.likes + (current.liked ? -1 : 1),
    );
    _posts[index] = updated;
    return updated;
  }

  @override
  Future<AppPost> toggleSave(String postId) async {
    final int index = _posts.indexWhere((AppPost p) => p.id == postId);
    if (index < 0) throw StateError('Post $postId not found');
    final AppPost updated = _copy(_posts[index], saved: !_posts[index].saved);
    _posts[index] = updated;
    return updated;
  }

  @override
  Future<AppPost> createPost(AppPost post) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    _posts = <AppPost>[post, ..._posts];
    return post;
  }

  @override
  Future<void> deletePost(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    _posts = _posts.where((AppPost p) => p.id != id).toList();
  }

  @override
  Future<AppComment> addComment(String postId, AppComment comment) async {
    await Future<void>.delayed(const Duration(milliseconds: 380));
    _extraComments
        .putIfAbsent(postId, () => <AppComment>[])
        .insert(0, comment);
    final int index = _posts.indexWhere((AppPost p) => p.id == postId);
    if (index >= 0) {
      _posts[index] = _copy(_posts[index], comments: _posts[index].comments + 1);
    }
    return comment;
  }

  @override
  Future<List<AppTrader>> getSuggestedTraders() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _traders
        .where((AppTrader t) => !t.isFollowing)
        .toList(growable: false);
  }

  @override
  Future<List<AppTrader>> getFollowers() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _traders.reversed.toList(growable: false);
  }

  @override
  Future<List<AppTrader>> getFollowing() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _traders
        .where((AppTrader t) => t.isFollowing)
        .toList(growable: false);
  }

  @override
  Future<AppTrader> toggleFollow(String traderId) async {
    final int index = _traders.indexWhere((AppTrader t) => t.id == traderId);
    if (index < 0) throw StateError('Trader $traderId not found');
    final AppTrader current = _traders[index];
    final AppTrader updated = AppTrader(
      id: current.id,
      handle: current.handle,
      displayName: current.displayName,
      avatarUrl: current.avatarUrl,
      bio: current.bio,
      tier: current.tier,
      followers: current.followers + (current.isFollowing ? -1 : 1),
      following: current.following,
      winRate: current.winRate,
      verified: current.verified,
      isFollowing: !current.isFollowing,
      tradingStyle: current.tradingStyle,
    );
    _traders[index] = updated;
    return updated;
  }

  @override
  Future<List<MapEntry<AppTrader, double>>> getLeaderboard(
    String period,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return _source.leaderboard(period);
  }

  @override
  Future<List<TrendingTopic>> getTrending() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final Map<String, int> counts = <String, int>{};
    for (final AppPost post in _posts) {
      for (final String ticker in post.tickers) {
        counts[ticker] = (counts[ticker] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> entries = counts.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    return <TrendingTopic>[
      for (final MapEntry<String, int> e in entries.take(6))
        TrendingTopic(
          label: e.key,
          posts: e.value * 37,
          changePercent: _source.tickerFor(e.key).changePercent,
        ),
    ];
  }
}
