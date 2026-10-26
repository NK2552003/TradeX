import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

// ---------------------------------------------------------------------------
// Author
// ---------------------------------------------------------------------------

/// A community user — trader, affiliate partner, or superadmin desk officer.
@immutable
class CommunityAuthor {
  const CommunityAuthor({
    required this.id,
    required this.handle,
    required this.displayName,
    required this.userRole,
    this.avatarUrl,
    this.bio,
    this.tier = AppTier.free,
    this.verified = false,
    this.isFollowing = false,
    this.followers = 0,
    this.following = 0,
    this.winRate,
    this.tradingStyle,
    this.primaryMarket,
    this.joinedDate,
    this.mutualFollowers = const <String>[],
    this.postsCount = 0,
    this.referralCode,
    this.channelHandle,
    this.audienceReach,
    this.location,
    this.website,
    this.avgHoldDuration,
    this.riskMantra,
  });

  final String id;
  final String handle;
  final String displayName;
  final UserRole userRole;
  final String? avatarUrl;
  final String? bio;
  final AppTier tier;
  final bool verified;
  final bool isFollowing;
  final int followers;
  final int following;
  final double? winRate;
  final String? tradingStyle;
  final String? primaryMarket;
  final String? joinedDate;

  /// Display names of people the current user also follows who follow this author.
  final List<String> mutualFollowers;
  final int postsCount;

  // Affiliate-specific
  final String? referralCode;
  final String? channelHandle;
  final String? audienceReach;

  // Profile meta
  final String? location;
  final String? website;
  final String? avgHoldDuration;
  final String? riskMantra;

  CommunityAuthor copyWith({bool? isFollowing, int? followers}) =>
      CommunityAuthor(
        id: id,
        handle: handle,
        displayName: displayName,
        userRole: userRole,
        avatarUrl: avatarUrl,
        bio: bio,
        tier: tier,
        verified: verified,
        isFollowing: isFollowing ?? this.isFollowing,
        followers: followers ?? this.followers,
        following: following,
        winRate: winRate,
        tradingStyle: tradingStyle,
        primaryMarket: primaryMarket,
        joinedDate: joinedDate,
        mutualFollowers: mutualFollowers,
        postsCount: postsCount,
        referralCode: referralCode,
        channelHandle: channelHandle,
        audienceReach: audienceReach,
        location: location,
        website: website,
        avgHoldDuration: avgHoldDuration,
        riskMantra: riskMantra,
      );

  Color verifiedColor(UiTheme theme) => switch (userRole) {
    UserRole.customer => theme.colors.primary,
    UserRole.affiliate => theme.colors.warning,
    UserRole.userAdmin => theme.colors.destructive,
  };

  String get roleBadgeText => switch (userRole) {
    UserRole.customer => 'PRO TRADER',
    UserRole.affiliate => 'OFFICIAL PARTNER',
    UserRole.userAdmin => 'DESK SUPERADMIN',
  };
}

// ---------------------------------------------------------------------------
// Trade Setup Snippet
// ---------------------------------------------------------------------------

/// Embedded trade execution block within a post.
@immutable
class CommunityTradeSetup {
  const CommunityTradeSetup({
    required this.ticker,
    required this.side,
    required this.entry,
    this.exit,
    this.stopLoss,
    this.target,
    this.rMultiple,
    this.pnl,
    this.isWin,
    this.candles = const <UiCandle>[],
  });

  final String ticker;

  /// 'LONG' or 'SHORT'
  final String side;
  final String entry;
  final String? exit;
  final String? stopLoss;
  final String? target;
  final String? rMultiple;
  final String? pnl;
  final bool? isWin;
  final List<UiCandle> candles;

  bool get isBullish => side.toUpperCase() == 'LONG';

  CommunityTradeSetup copyWith({
    String? ticker,
    String? side,
    String? entry,
    String? exit,
    String? stopLoss,
    String? target,
    String? rMultiple,
    String? pnl,
    bool? isWin,
    List<UiCandle>? candles,
  }) {
    return CommunityTradeSetup(
      ticker: ticker ?? this.ticker,
      side: side ?? this.side,
      entry: entry ?? this.entry,
      exit: exit ?? this.exit,
      stopLoss: stopLoss ?? this.stopLoss,
      target: target ?? this.target,
      rMultiple: rMultiple ?? this.rMultiple,
      pnl: pnl ?? this.pnl,
      isWin: isWin ?? this.isWin,
      candles: candles ?? this.candles,
    );
  }
}

// ---------------------------------------------------------------------------
// Link Preview
// ---------------------------------------------------------------------------

@immutable
class CommunityLinkPreview {
  const CommunityLinkPreview({
    required this.title,
    required this.domain,
    this.imageUrl,
    this.description,
  });

  final String title;
  final String domain;
  final String? imageUrl;
  final String? description;
}

// ---------------------------------------------------------------------------
// Enums & Sentiment
// ---------------------------------------------------------------------------

/// Sentiment tag for trading posts and market theses.
enum CommunitySentiment {
  bullish,
  bearish,
  neutral;

  String get label => switch (this) {
    CommunitySentiment.bullish => 'Bullish',
    CommunitySentiment.bearish => 'Bearish',
    CommunitySentiment.neutral => 'Neutral',
  };

  IconData get icon => switch (this) {
    CommunitySentiment.bullish => Icons.trending_up_rounded,
    CommunitySentiment.bearish => Icons.trending_down_rounded,
    CommunitySentiment.neutral => Icons.trending_flat_rounded,
  };
}

/// Audience reply permissions for posts.
enum CommunityReplyAudience {
  everyone,
  following,
  mentioned;

  String get label => switch (this) {
    CommunityReplyAudience.everyone => 'Everyone can reply',
    CommunityReplyAudience.following => 'Accounts you follow can reply',
    CommunityReplyAudience.mentioned => 'Only accounts you mention can reply',
  };
}

/// Reasons for reporting a community post or trader.
enum CommunityReportReason {
  spam,
  misleading,
  hateful,
  violence,
  nudity,
  financialScam,
  other;

  String get label => switch (this) {
    CommunityReportReason.spam => 'Spam or automated content',
    CommunityReportReason.misleading =>
      'Misleading trade claims or false returns',
    CommunityReportReason.hateful => 'Hate speech or harassment',
    CommunityReportReason.violence => 'Threats or dangerous activities',
    CommunityReportReason.nudity => 'Explicit or inappropriate imagery',
    CommunityReportReason.financialScam =>
      'Financial fraud, phishing or pump-and-dump',
    CommunityReportReason.other => 'Other issue',
  };
}

// ---------------------------------------------------------------------------
// Polls
// ---------------------------------------------------------------------------

/// A single selectable option within an interactive community poll.
@immutable
class CommunityPollOption {
  const CommunityPollOption({
    required this.id,
    required this.text,
    this.votes = 0,
  });

  final String id;
  final String text;
  final int votes;

  CommunityPollOption copyWith({int? votes}) =>
      CommunityPollOption(id: id, text: text, votes: votes ?? this.votes);
}

/// An interactive poll attached to a community post.
@immutable
class CommunityPoll {
  const CommunityPoll({
    required this.id,
    required this.question,
    required this.options,
    this.expiresAt,
    this.votedOptionIndex,
    this.votedOptionIndices = const <int>[],
    this.allowMultiple = false,
    this.authorId,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.voterTradingStyles = const <String, int>{},
    this.voterWinRateTiers = const <String, int>{},
  });

  final String id;
  final String question;
  final List<CommunityPollOption> options;
  final DateTime? expiresAt;
  final int? votedOptionIndex;
  final List<int> votedOptionIndices;
  final bool allowMultiple;
  final String? authorId;
  final String? authorDisplayName;
  final String? authorAvatarUrl;
  final Map<String, int> voterTradingStyles;
  final Map<String, int> voterWinRateTiers;

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votes);
  bool get hasVoted =>
      votedOptionIndex != null || votedOptionIndices.isNotEmpty;
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  bool hasVotedFor(int index) =>
      votedOptionIndex == index || votedOptionIndices.contains(index);

  double percentageFor(int index) {
    final total = totalVotes;
    if (total == 0) return 0.0;
    return (options[index].votes / total) * 100.0;
  }

  CommunityPoll copyWith({
    List<CommunityPollOption>? options,
    int? votedOptionIndex,
    List<int>? votedOptionIndices,
    bool? allowMultiple,
    String? authorId,
    String? authorDisplayName,
    String? authorAvatarUrl,
    Map<String, int>? voterTradingStyles,
    Map<String, int>? voterWinRateTiers,
  }) => CommunityPoll(
    id: id,
    question: question,
    options: options ?? this.options,
    expiresAt: expiresAt,
    votedOptionIndex: votedOptionIndex ?? this.votedOptionIndex,
    votedOptionIndices: votedOptionIndices ?? this.votedOptionIndices,
    allowMultiple: allowMultiple ?? this.allowMultiple,
    authorId: authorId ?? this.authorId,
    authorDisplayName: authorDisplayName ?? this.authorDisplayName,
    authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    voterTradingStyles: voterTradingStyles ?? this.voterTradingStyles,
    voterWinRateTiers: voterWinRateTiers ?? this.voterWinRateTiers,
  );
}

// ---------------------------------------------------------------------------
// Post Insights & Moderation
// ---------------------------------------------------------------------------

/// Detailed post analytics metrics.
@immutable
class CommunityPostInsights {
  const CommunityPostInsights({
    required this.postId,
    required this.impressions,
    required this.engagements,
    required this.detailExpands,
    required this.profileVisits,
    required this.linkClicks,
    this.shares = 0,
  });

  final String postId;
  final int impressions;
  final int engagements;
  final int detailExpands;
  final int profileVisits;
  final int linkClicks;
  final int shares;

  double get engagementRate =>
      impressions == 0 ? 0.0 : (engagements / impressions) * 100.0;
}

/// Record of a muted user.
@immutable
class CommunityMuteEntry {
  const CommunityMuteEntry({required this.userId, required this.mutedAt});
  final String userId;
  final DateTime mutedAt;
}

/// Record of a blocked user.
@immutable
class CommunityBlockEntry {
  const CommunityBlockEntry({required this.userId, required this.blockedAt});
  final String userId;
  final DateTime blockedAt;
}

// ---------------------------------------------------------------------------
// Direct Messaging Models
// ---------------------------------------------------------------------------

/// Direct message conversation thread.
@immutable
class CommunityConversation {
  const CommunityConversation({
    required this.id,
    required this.peer,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  final String id;
  final CommunityAuthor peer;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
}

/// A single chat message in a direct message conversation.
@immutable
class CommunityChatMessage {
  const CommunityChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.isMine = false,
    this.sharedPost,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isMine;
  final CommunityPost? sharedPost;
}

/// Type alias for pagination cursors.
typedef FeedCursor = String?;

// ---------------------------------------------------------------------------
// Post
// ---------------------------------------------------------------------------

@immutable
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.isPinned = false,
    this.isPublic = true,
    this.repostedBy,
    this.tickers = const <String>[],
    this.tags = const <String>[],
    this.tradeSetup,
    this.linkPreview,
    this.imageUrl,
    this.imageUrls = const <String>[],
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.views = 0,
    this.liked = false,
    this.userReaction,
    this.reactions = const <String>[],
    this.reposted = false,
    this.bookmarked = false,
    this.quoted,
    this.attachment,
    this.poll,
    this.videoUrl,
    this.gifUrl,
    this.sentiment,
    this.replyAudience = CommunityReplyAudience.everyone,
    this.isDeskAlert = false,
    this.isEdited = false,
    this.editedAt,
    this.scheduledFor,
  });

  final String id;
  final CommunityAuthor author;
  final String body;
  final DateTime createdAt;
  final bool isPinned;
  final bool isPublic;

  /// When non-null this post appears as a repost with a banner.
  final String? repostedBy;

  final List<String> tickers;
  final List<String> tags;
  final CommunityTradeSetup? tradeSetup;
  final CommunityLinkPreview? linkPreview;
  final String? imageUrl;
  final List<String> imageUrls;
  final int likes;
  final int comments;
  final int reposts;
  final int views;
  final bool liked;
  final String? userReaction;
  final List<String> reactions;
  final bool reposted;
  final bool bookmarked;

  /// A post this one is quoting.
  final CommunityPost? quoted;

  /// An attached Writing Desk record.
  final AppWritingPostAttachment? attachment;

  /// Optional attached poll.
  final CommunityPoll? poll;

  /// Optional attached video / screen recording URL.
  final String? videoUrl;

  /// Optional GIF attachment URL.
  final String? gifUrl;

  /// Bullish / Bearish sentiment tag.
  final CommunitySentiment? sentiment;

  /// Allowed reply audience.
  final CommunityReplyAudience replyAudience;

  /// Whether this is a desk superadmin broadcast alert.
  final bool isDeskAlert;

  /// Whether the post was edited after publication.
  final bool isEdited;
  final DateTime? editedAt;

  /// If scheduled, the planned publish timestamp.
  final DateTime? scheduledFor;

  List<String> get effectiveImageUrls {
    if (imageUrls.isNotEmpty) return imageUrls;
    if (imageUrl != null && imageUrl!.isNotEmpty) return <String>[imageUrl!];
    return const <String>[];
  }

  static const Object _postSentinel = Object();

  CommunityPost copyWith({
    String? body,
    int? likes,
    int? comments,
    int? reposts,
    int? views,
    bool? liked,
    Object? userReaction = _postSentinel,
    List<String>? reactions,
    bool? reposted,
    bool? bookmarked,
    bool? isPinned,
    bool? isPublic,
    String? repostedBy,
    AppWritingPostAttachment? attachment,
    bool clearAttachment = false,
    CommunityPoll? poll,
    bool clearPoll = false,
    CommunitySentiment? sentiment,
    bool clearSentiment = false,
    CommunityReplyAudience? replyAudience,
    bool? isEdited,
    DateTime? editedAt,
    List<String>? imageUrls,
    List<String>? tickers,
    List<String>? tags,
    CommunityTradeSetup? tradeSetup,
    bool clearTradeSetup = false,
  }) => CommunityPost(
    id: id,
    author: author,
    body: body ?? this.body,
    createdAt: createdAt,
    isPinned: isPinned ?? this.isPinned,
    isPublic: isPublic ?? this.isPublic,
    repostedBy: repostedBy ?? this.repostedBy,
    tickers: tickers ?? this.tickers,

    tags: tags ?? this.tags,
    tradeSetup: clearTradeSetup ? null : (tradeSetup ?? this.tradeSetup),
    linkPreview: linkPreview,
    imageUrl: imageUrl,
    imageUrls: imageUrls ?? this.imageUrls,
    likes: likes ?? this.likes,
    comments: comments ?? this.comments,
    reposts: reposts ?? this.reposts,
    views: views ?? this.views,
    liked: liked ?? this.liked,
    userReaction: identical(userReaction, _postSentinel)
        ? this.userReaction
        : userReaction as String?,
    reactions: reactions ?? this.reactions,
    reposted: reposted ?? this.reposted,
    bookmarked: bookmarked ?? this.bookmarked,
    quoted: quoted,
    attachment: clearAttachment ? null : (attachment ?? this.attachment),
    poll: clearPoll ? null : (poll ?? this.poll),
    videoUrl: videoUrl,
    gifUrl: gifUrl,
    sentiment: clearSentiment ? null : (sentiment ?? this.sentiment),
    replyAudience: replyAudience ?? this.replyAudience,
    isDeskAlert: isDeskAlert,
    isEdited: isEdited ?? this.isEdited,
    editedAt: editedAt ?? this.editedAt,
    scheduledFor: scheduledFor,
  );
}

// ---------------------------------------------------------------------------
// Comment
// ---------------------------------------------------------------------------

@immutable
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.author,
    required this.body,
    required this.createdAt,
    this.likes = 0,
    this.liked = false,
    this.replies = const <CommunityComment>[],
    this.sentiment,
    this.parentCommentId,
    this.userReaction,
    this.reactions = const <String>[],
  });

  final String id;
  final String postId;
  final CommunityAuthor author;
  final String body;
  final DateTime createdAt;
  final int likes;
  final bool liked;
  final List<CommunityComment> replies;
  final String? sentiment;
  final String? parentCommentId;
  final String? userReaction;
  final List<String> reactions;

  bool get isLiked => liked;

  /// Returns the unique ordered list of emoji reactions to display on the badge.
  /// If the current user has reacted, that emoji is guaranteed to appear first.
  List<String> get displayReactions {
    final result = <String>[];
    if (userReaction != null && userReaction!.trim().isNotEmpty) {
      result.add(userReaction!.trim());
    }
    for (final r in reactions) {
      final clean = r.trim();
      if (clean.isNotEmpty && !result.contains(clean)) {
        result.add(clean);
      }
    }
    if (result.isEmpty && likes > 0) {
      result.add('👍');
    }
    return result;
  }

  static const Object _sentinel = Object();

  CommunityComment copyWith({
    int? likes,
    bool? liked,
    List<CommunityComment>? replies,
    String? sentiment,
    String? parentCommentId,
    Object? userReaction = _sentinel,
    List<String>? reactions,
  }) => CommunityComment(
    id: id,
    postId: postId,
    author: author,
    body: body,
    createdAt: createdAt,
    likes: likes ?? this.likes,
    liked: liked ?? this.liked,
    replies: replies ?? this.replies,
    sentiment: sentiment ?? this.sentiment,
    parentCommentId: parentCommentId ?? this.parentCommentId,
    userReaction: identical(userReaction, _sentinel)
        ? this.userReaction
        : userReaction as String?,
    reactions: reactions ?? this.reactions,
  );
}

// ---------------------------------------------------------------------------
// News Item
// ---------------------------------------------------------------------------

@immutable
class CommunityNewsItem {
  const CommunityNewsItem({
    required this.id,
    required this.headline,
    required this.source,
    required this.publishedAt,
    this.summary,
    this.category = 'News',
    this.sentimentScore = 0.0,
    this.articleUrl,
    this.thumbnail,
    this.relatedTickers = const <String>[],
    this.postCount,
  });

  final String id;
  final String headline;
  final String source;
  final DateTime publishedAt;
  final String? summary;
  final String category;
  final double sentimentScore;
  final String? articleUrl;
  final String? thumbnail;
  final List<String> relatedTickers;
  final String? postCount;
}

// ---------------------------------------------------------------------------
// Trending Item
// ---------------------------------------------------------------------------

@immutable
class CommunityTrendItem {
  const CommunityTrendItem({
    required this.id,
    required this.topic,
    required this.category,
    this.postCount,
  });

  final String id;
  final String topic;
  final String category;
  final String? postCount;
}

// ---------------------------------------------------------------------------
// Notification Entry
// ---------------------------------------------------------------------------

enum CommunityNotificationType {
  like,
  comment,
  reply,
  repost,
  follow,
  mention,
  signal,
  system,
  security,
  tradeExecution,
  marginAlert,
  message,
}

@immutable
class CommunityNotificationItem {
  const CommunityNotificationItem({
    required this.id,
    this.actor,
    required this.type,
    required this.createdAt,
    this.title,
    this.body,
    this.postSnippet,
    this.postId,
    this.postImageUrl,
    this.data = const <String, dynamic>{},
    this.read = false,
    this.isFollowingBack = false,
  });

  final String id;
  final CommunityAuthor? actor;
  final CommunityNotificationType type;
  final DateTime createdAt;
  final String? title;
  final String? body;
  final String? postSnippet;
  final String? postId;
  final String? postImageUrl;
  final Map<String, dynamic> data;
  final bool read;
  final bool isFollowingBack;

  CommunityNotificationItem copyWith({
    String? id,
    CommunityAuthor? actor,
    CommunityNotificationType? type,
    DateTime? createdAt,
    String? title,
    String? body,
    String? postSnippet,
    String? postId,
    String? postImageUrl,
    Map<String, dynamic>? data,
    bool? read,
    bool? isFollowingBack,
  }) {
    return CommunityNotificationItem(
      id: id ?? this.id,
      actor: actor ?? this.actor,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      postSnippet: postSnippet ?? this.postSnippet,
      postId: postId ?? this.postId,
      postImageUrl: postImageUrl ?? this.postImageUrl,
      data: data ?? this.data,
      read: read ?? this.read,
      isFollowingBack: isFollowingBack ?? this.isFollowingBack,
    );
  }

  IconData get icon => switch (type) {
    CommunityNotificationType.like => Icons.favorite_rounded,
    CommunityNotificationType.comment ||
    CommunityNotificationType.reply => Icons.chat_bubble_rounded,
    CommunityNotificationType.repost => Icons.repeat_rounded,
    CommunityNotificationType.follow => Icons.person_add_rounded,
    CommunityNotificationType.mention => Icons.alternate_email_rounded,
    CommunityNotificationType.signal => Icons.auto_graph_rounded,
    CommunityNotificationType.system => Icons.info_outline_rounded,
    CommunityNotificationType.security => Icons.phone_android_rounded,
    CommunityNotificationType.tradeExecution =>
      Icons.check_circle_outline_rounded,
    CommunityNotificationType.marginAlert => Icons.shield_outlined,
    CommunityNotificationType.message => Icons.mark_chat_unread_rounded,
  };

  String get label => switch (type) {
    CommunityNotificationType.like => 'liked your post',
    CommunityNotificationType.comment ||
    CommunityNotificationType.reply => 'replied to your post',
    CommunityNotificationType.repost => 'reposted your setup',
    CommunityNotificationType.follow => 'followed you',
    CommunityNotificationType.mention => 'mentioned you',
    CommunityNotificationType.signal => 'published a new signal',
    CommunityNotificationType.system => 'hejournal.in System Alert',
    CommunityNotificationType.security => 'Security Alert',
    CommunityNotificationType.tradeExecution => 'Trade Execution',
    CommunityNotificationType.marginAlert => 'Margin Alert',
    CommunityNotificationType.message => 'sent you a direct message',
  };
}

// ---------------------------------------------------------------------------
// Live Audio Space / Room
// ---------------------------------------------------------------------------

enum LiveRoomStatus { live, scheduled, ended }

@immutable
class LivePinnedSetup {
  const LivePinnedSetup({
    required this.ticker,
    required this.side,
    required this.entry,
    required this.stopLoss,
    required this.target,
    required this.note,
  });

  final String ticker;
  final String side; // 'LONG' or 'SHORT'
  final double entry;
  final double stopLoss;
  final double target;
  final String note;

  double get risk => (entry - stopLoss).abs();
  double get reward => (target - entry).abs();
  double get rrRatio => risk > 0 ? (reward / risk) : 1.0;
}

@immutable
class LiveAudioRoom {
  const LiveAudioRoom({
    required this.id,
    required this.title,
    required this.topic,
    required this.host,
    required this.category,
    this.status = LiveRoomStatus.live,
    this.listenerCount = 0,
    this.speakers = const <String>[],
    this.speakerCount = 1,
    this.pinnedSetup,
    this.scheduledFor,
    this.startedAt,
    this.endedAt,
    this.isRecording = false,
    this.tags = const <String>[],
    this.hasReminder = false,
    this.pollBullishVotes = 0,
    this.pollBearishVotes = 0,
  });

  final String id;
  final String title;
  final String topic;
  final CommunityAuthor host;
  final String category;
  final LiveRoomStatus status;
  final int listenerCount;
  final List<String> speakers;
  final int speakerCount;
  final LivePinnedSetup? pinnedSetup;
  final DateTime? scheduledFor;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool isRecording;
  final List<String> tags;
  final bool hasReminder;
  final int pollBullishVotes;
  final int pollBearishVotes;

  bool get isLive => status == LiveRoomStatus.live;
  bool get isScheduled => status == LiveRoomStatus.scheduled;
  bool get isEnded => status == LiveRoomStatus.ended;

  int get totalPollVotes => pollBullishVotes + pollBearishVotes;
  double get bullishPercentage =>
      totalPollVotes == 0 ? 0.5 : pollBullishVotes / totalPollVotes;
  double get bearishPercentage =>
      totalPollVotes == 0 ? 0.5 : pollBearishVotes / totalPollVotes;

  factory LiveAudioRoom.fromMap(
    Map<String, dynamic> map, {
    CommunityAuthor? host,
  }) {
    final statusStr = map['status']?.toString().toLowerCase() ?? 'live';
    final status = switch (statusStr) {
      'scheduled' => LiveRoomStatus.scheduled,
      'ended' => LiveRoomStatus.ended,
      _ => LiveRoomStatus.live,
    };

    LivePinnedSetup? setup;
    final ticker = map['pinned_ticker']?.toString();
    if (ticker != null && ticker.isNotEmpty) {
      setup = LivePinnedSetup(
        ticker: ticker,
        side: (map['pinned_side']?.toString().toUpperCase() == 'SHORT')
            ? 'SHORT'
            : 'LONG',
        entry: (map['pinned_entry'] as num?)?.toDouble() ?? 0.0,
        stopLoss: (map['pinned_stop_loss'] as num?)?.toDouble() ?? 0.0,
        target: (map['pinned_target'] as num?)?.toDouble() ?? 0.0,
        note: map['pinned_note']?.toString() ?? '',
      );
    }

    final rawTags = map['tags'];
    final List<String> tags = [];
    if (rawTags is List) {
      tags.addAll(rawTags.map((e) => e.toString()));
    }

    final author =
        host ??
        CommunityAuthor(
          id: map['host_id']?.toString() ?? '',
          handle: 'host',
          displayName: 'Space Host',
          userRole: UserRole.customer,
        );

    return LiveAudioRoom(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Live Audio Space',
      topic: map['topic']?.toString() ?? '',
      host: author,
      category: map['category']?.toString() ?? 'Options Trading',
      status: status,
      listenerCount: (map['listener_count'] as num?)?.toInt() ?? 1,
      speakerCount: (map['speaker_count'] as num?)?.toInt() ?? 1,
      speakers: <String>[author.displayName],
      pinnedSetup: setup,
      scheduledFor: map['scheduled_for'] != null
          ? DateTime.tryParse(map['scheduled_for'].toString())
          : null,
      startedAt: map['started_at'] != null
          ? DateTime.tryParse(map['started_at'].toString())
          : null,
      endedAt: map['ended_at'] != null
          ? DateTime.tryParse(map['ended_at'].toString())
          : null,
      isRecording: map['recording_available'] as bool? ?? true,
      tags: tags,
      hasReminder: map['has_reminder'] as bool? ?? false,
      pollBullishVotes: (map['poll_bullish_votes'] as num?)?.toInt() ?? 0,
      pollBearishVotes: (map['poll_bearish_votes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'host_id': host.id,
      'title': title,
      'topic': topic,
      'category': category,
      'status': status.name,
      'listener_count': listenerCount,
      'speaker_count': speakerCount,
      'started_at': startedAt?.toIso8601String(),
      'scheduled_for': scheduledFor?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'recording_available': isRecording,
      'tags': tags,
      'pinned_ticker': pinnedSetup?.ticker,
      'pinned_side': pinnedSetup?.side,
      'pinned_entry': pinnedSetup?.entry,
      'pinned_stop_loss': pinnedSetup?.stopLoss,
      'pinned_target': pinnedSetup?.target,
      'pinned_note': pinnedSetup?.note,
      'poll_bullish_votes': pollBullishVotes,
      'poll_bearish_votes': pollBearishVotes,
    };
  }

  LiveAudioRoom copyWith({
    String? id,
    String? title,
    String? topic,
    CommunityAuthor? host,
    String? category,
    LiveRoomStatus? status,
    int? listenerCount,
    List<String>? speakers,
    int? speakerCount,
    LivePinnedSetup? pinnedSetup,
    DateTime? scheduledFor,
    DateTime? startedAt,
    DateTime? endedAt,
    bool? isRecording,
    List<String>? tags,
    bool? hasReminder,
    int? pollBullishVotes,
    int? pollBearishVotes,
  }) {
    return LiveAudioRoom(
      id: id ?? this.id,
      title: title ?? this.title,
      topic: topic ?? this.topic,
      host: host ?? this.host,
      category: category ?? this.category,
      status: status ?? this.status,
      listenerCount: listenerCount ?? this.listenerCount,
      speakers: speakers ?? this.speakers,
      speakerCount: speakerCount ?? this.speakerCount,
      pinnedSetup: pinnedSetup ?? this.pinnedSetup,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      isRecording: isRecording ?? this.isRecording,
      tags: tags ?? this.tags,
      hasReminder: hasReminder ?? this.hasReminder,
      pollBullishVotes: pollBullishVotes ?? this.pollBullishVotes,
      pollBearishVotes: pollBearishVotes ?? this.pollBearishVotes,
    );
  }

  bool get recordingAvailable => isRecording;
}

// ---------------------------------------------------------------------------
// Live Audio Space Participants, Messages, and Q&A
// ---------------------------------------------------------------------------

@immutable
class LiveRoomParticipant {
  const LiveRoomParticipant({
    required this.roomId,
    required this.userId,
    required this.displayName,
    this.handle = 'trader',
    this.avatarUrl,
    this.role = 'listener',
    this.isMuted = true,
    this.isHandRaised = false,
    this.handRaisedAt,
    required this.joinedAt,
    this.lastSeenAt,
    this.talkSeconds = 0,
  });

  final String roomId;
  final String userId;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final String role; // 'host', 'cohost', 'speaker', 'listener'
  final bool isMuted;
  final bool isHandRaised;
  final DateTime? handRaisedAt;
  final DateTime joinedAt;
  final DateTime? lastSeenAt;
  final int talkSeconds;

  bool get isHost => role == 'host';
  bool get isCoHost => role == 'cohost' || role == 'co_host';
  bool get isSpeaker => role == 'speaker' || isHost || isCoHost;
  bool get isStage => isSpeaker;
  bool get isListener => role == 'listener';

  factory LiveRoomParticipant.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return LiveRoomParticipant(
      roomId: map['room_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      displayName:
          profile?['display_name'] as String? ??
          profile?['username'] as String? ??
          map['display_name'] as String? ??
          'Trader',
      handle:
          profile?['username'] as String? ??
          map['handle'] as String? ??
          'trader',
      avatarUrl:
          profile?['avatar_url'] as String? ?? map['avatar_url'] as String?,
      role: map['role']?.toString().toLowerCase() ?? 'listener',
      isMuted: map['is_muted'] as bool? ?? true,
      isHandRaised: map['is_hand_raised'] as bool? ?? false,
      handRaisedAt: map['hand_raised_at'] != null
          ? DateTime.tryParse(map['hand_raised_at'].toString())
          : null,
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'].toString())
          : null,
    );
  }

  LiveRoomParticipant copyWith({
    String? roomId,
    String? userId,
    String? displayName,
    String? handle,
    String? avatarUrl,
    String? role,
    bool? isMuted,
    bool? isHandRaised,
    DateTime? handRaisedAt,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    int? talkSeconds,
  }) {
    return LiveRoomParticipant(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      handRaisedAt: handRaisedAt ?? this.handRaisedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      talkSeconds: talkSeconds ?? this.talkSeconds,
    );
  }
}

@immutable
class LiveRoomMessage {
  const LiveRoomMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.senderRole = 'listener',
    required this.message,
    this.isPinned = false,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String senderRole;
  final String message;
  final bool isPinned;
  final DateTime createdAt;

  bool get isHost => senderRole == 'host';
  bool get isSpeaker =>
      senderRole == 'speaker' || isHost || senderRole == 'cohost';

  factory LiveRoomMessage.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return LiveRoomMessage(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      senderId: map['sender_id']?.toString() ?? '',
      senderName:
          profile?['display_name'] as String? ??
          profile?['username'] as String? ??
          map['sender_name'] as String? ??
          'Trader',
      senderAvatarUrl:
          profile?['avatar_url'] as String? ??
          map['sender_avatar_url'] as String?,
      senderRole: map['sender_role']?.toString() ?? 'listener',
      message: map['message']?.toString() ?? '',
      isPinned: map['is_pinned'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

@immutable
class LiveRoomQuestion {
  const LiveRoomQuestion({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.question,
    this.upvotesCount = 0,
    this.isAnswered = false,
    this.hasUpvoted = false,
    this.answeredAt,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String question;
  final int upvotesCount;
  final bool isAnswered;
  final bool hasUpvoted;
  final DateTime? answeredAt;
  final DateTime createdAt;

  factory LiveRoomQuestion.fromMap(
    Map<String, dynamic> map, {
    bool hasUpvoted = false,
  }) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return LiveRoomQuestion(
      id: map['id']?.toString() ?? '',
      roomId: map['room_id']?.toString() ?? '',
      authorId: map['author_id']?.toString() ?? '',
      authorName:
          profile?['display_name'] as String? ??
          profile?['username'] as String? ??
          map['author_name'] as String? ??
          'Trader',
      authorAvatarUrl:
          profile?['avatar_url'] as String? ??
          map['author_avatar_url'] as String?,
      question: map['question']?.toString() ?? '',
      upvotesCount: (map['upvotes_count'] as num?)?.toInt() ?? 0,
      isAnswered: map['is_answered'] as bool? ?? false,
      hasUpvoted: hasUpvoted,
      answeredAt: map['answered_at'] != null
          ? DateTime.tryParse(map['answered_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  LiveRoomQuestion copyWith({
    String? id,
    String? roomId,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? question,
    int? upvotesCount,
    bool? isAnswered,
    bool? hasUpvoted,
    DateTime? answeredAt,
    DateTime? createdAt,
  }) {
    return LiveRoomQuestion(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      question: question ?? this.question,
      upvotesCount: upvotesCount ?? this.upvotesCount,
      isAnswered: isAnswered ?? this.isAnswered,
      hasUpvoted: hasUpvoted ?? this.hasUpvoted,
      answeredAt: answeredAt ?? this.answeredAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Category of social activity performed by a user in the community.
enum CommunityActivityType { like, comment, repost, post, pollVote }

/// An Instagram-style user activity record (likes, comments, reposts, trades shared).
@immutable
class CommunityActivityItem {
  const CommunityActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.timestamp,
    this.subtitle,
    this.targetPostId,
    this.post,
    this.metadata,
  });

  final String id;
  final CommunityActivityType type;
  final String title;
  final String? subtitle;
  final String? targetPostId;
  final CommunityPost? post;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}
