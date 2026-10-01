import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tradex/core/app-ui/models/app_models.dart';

/// Metadata for a community/social post linked to a Writing Desk record.
@immutable
class AppPostLinkInfo {
  const AppPostLinkInfo({
    required this.postId,
    required this.postTitle,
    required this.authorName,
    required this.authorHandle,
    required this.recordKind,
    required this.recordId,
    required this.publishedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.status = 'published',
  });

  final String postId;
  final String postTitle;
  final String authorName;
  final String authorHandle;
  final AppLinkKind recordKind;
  final String recordId;
  final DateTime publishedAt;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final String status;

  AppPostLinkInfo copyWith({
    String? postId,
    String? postTitle,
    String? authorName,
    String? authorHandle,
    AppLinkKind? recordKind,
    String? recordId,
    DateTime? publishedAt,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    String? status,
  }) {
    return AppPostLinkInfo(
      postId: postId ?? this.postId,
      postTitle: postTitle ?? this.postTitle,
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
      recordKind: recordKind ?? this.recordKind,
      recordId: recordId ?? this.recordId,
      publishedAt: publishedAt ?? this.publishedAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      status: status ?? this.status,
    );
  }
}

/// Dynamic, un-hardcoded service providing social post linking and engagement
/// analytics for notes, attached journal entries, and strategies.
class WorkspacePostService {
  WorkspacePostService._() {
    _seedDefaultMockData();
  }

  static final WorkspacePostService instance = WorkspacePostService._();

  final List<AppPostLinkInfo> _links = <AppPostLinkInfo>[];
  final StreamController<List<AppPostLinkInfo>> _controller =
      StreamController<List<AppPostLinkInfo>>.broadcast();

  Stream<List<AppPostLinkInfo>> watchLinks() => _controller.stream;

  List<AppPostLinkInfo> get allLinks =>
      List<AppPostLinkInfo>.unmodifiable(_links);

  void _seedDefaultMockData() {
    final DateTime now = DateTime.now();
    _links.addAll(<AppPostLinkInfo>[
      AppPostLinkInfo(
        postId: 'post-101',
        postTitle: 'NVDA Q3 Earnings Playbook & Volatility Review',
        authorName: 'Alex Trader',
        authorHandle: '@alextrader',
        recordKind: AppLinkKind.strategy,
        recordId: 'strat-1',
        publishedAt: now.subtract(const Duration(days: 1)),
        likesCount: 142,
        commentsCount: 28,
        sharesCount: 19,
      ),
      AppPostLinkInfo(
        postId: 'post-102',
        postTitle: 'Morning Market Prep & Key Levels to Watch',
        authorName: 'Alex Trader',
        authorHandle: '@alextrader',
        recordKind: AppLinkKind.note,
        recordId: 'note-1',
        publishedAt: now.subtract(const Duration(hours: 6)),
        likesCount: 89,
        commentsCount: 14,
        sharesCount: 7,
      ),
      AppPostLinkInfo(
        postId: 'post-103',
        postTitle: 'Trade Recap: AAPL Breakout Execution with +3.2R Gain',
        authorName: 'Alex Trader',
        authorHandle: '@alextrader',
        recordKind: AppLinkKind.journal,
        recordId: 'trade-1',
        publishedAt: now.subtract(const Duration(days: 2)),
        likesCount: 215,
        commentsCount: 36,
        sharesCount: 24,
      ),
      AppPostLinkInfo(
        postId: 'post-104',
        postTitle: 'Weekly Quant Journal: Execution Mistakes & Wins',
        authorName: 'Alex Trader',
        authorHandle: '@alextrader',
        recordKind: AppLinkKind.note,
        recordId: 'note-2',
        publishedAt: now.subtract(const Duration(days: 3)),
        likesCount: 64,
        commentsCount: 9,
        sharesCount: 5,
      ),
      AppPostLinkInfo(
        postId: 'post-105',
        postTitle: 'Mean Reversion Setup on TSLA Pullback',
        authorName: 'Alex Trader',
        authorHandle: '@alextrader',
        recordKind: AppLinkKind.strategy,
        recordId: 'strat-2',
        publishedAt: now.subtract(const Duration(days: 4)),
        likesCount: 97,
        commentsCount: 18,
        sharesCount: 11,
      ),
    ]);
  }

  /// Checks whether a specific record (note, trade, or strategy) is linked to a post.
  bool isLinked(AppLinkKind kind, String recordId) {
    if (recordId.isEmpty) return false;
    return _links.any(
      (AppPostLinkInfo p) =>
          p.recordKind == kind &&
          (p.recordId == recordId || recordId.contains(p.recordId)),
    );
  }

  /// Returns all posts linked to the specified record.
  List<AppPostLinkInfo> getLinksForRecord(AppLinkKind kind, String recordId) {
    if (recordId.isEmpty) return const <AppPostLinkInfo>[];
    return _links
        .where(
          (AppPostLinkInfo p) =>
              p.recordKind == kind &&
              (p.recordId == recordId || recordId.contains(p.recordId)),
        )
        .toList(growable: false);
  }

  /// Returns the first post linked to this record, if any.
  AppPostLinkInfo? getPrimaryLink(AppLinkKind kind, String recordId) {
    final List<AppPostLinkInfo> matches = getLinksForRecord(kind, recordId);
    return matches.isNotEmpty ? matches.first : null;
  }

  /// Total count of records linked to posts, optionally filtered by record kind.
  int totalLinkedPosts({AppLinkKind? kind}) {
    if (kind == null) return _links.length;
    return _links.where((AppPostLinkInfo p) => p.recordKind == kind).length;
  }

  /// Total social likes across linked posts.
  int totalLikes({AppLinkKind? kind}) {
    final Iterable<AppPostLinkInfo> filtered =
        kind == null ? _links : _links.where((p) => p.recordKind == kind);
    return filtered.fold<int>(0, (sum, p) => sum + p.likesCount);
  }

  /// Total comments across linked posts.
  int totalComments({AppLinkKind? kind}) {
    final Iterable<AppPostLinkInfo> filtered =
        kind == null ? _links : _links.where((p) => p.recordKind == kind);
    return filtered.fold<int>(0, (sum, p) => sum + p.commentsCount);
  }

  /// Total shares across linked posts.
  int totalShares({AppLinkKind? kind}) {
    final Iterable<AppPostLinkInfo> filtered =
        kind == null ? _links : _links.where((p) => p.recordKind == kind);
    return filtered.fold<int>(0, (sum, p) => sum + p.sharesCount);
  }

  /// Links a record to a new community post.
  void linkRecord({
    required AppLinkKind kind,
    required String recordId,
    required String postTitle,
    String authorName = 'Trader',
    String authorHandle = '@trader',
  }) {
    final String postId = 'post-${DateTime.now().millisecondsSinceEpoch}';
    final AppPostLinkInfo post = AppPostLinkInfo(
      postId: postId,
      postTitle: postTitle,
      authorName: authorName,
      authorHandle: authorHandle,
      recordKind: kind,
      recordId: recordId,
      publishedAt: DateTime.now(),
    );
    _links.add(post);
    _controller.add(allLinks);
  }

  /// Removes a link.
  void unlinkRecord(String postId) {
    _links.removeWhere((AppPostLinkInfo p) => p.postId == postId);
    _controller.add(allLinks);
  }
}
