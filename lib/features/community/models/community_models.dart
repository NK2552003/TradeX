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

  CommunityPollOption copyWith({int? votes}) => CommunityPollOption(
    id: id,
    text: text,
    votes: votes ?? this.votes,
  );
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
    this.voterTradingStyles = const <String, int>{
      'Scalper': 42,
      'Day Trader': 118,
      'Swing Trader': 204,
      'Positional / Macro': 76,
    },
    this.voterWinRateTiers = const <String, int>{
      '> 70% Win Rate': 112,
      '50% - 70% Win Rate': 195,
      '< 50% Win Rate': 133,
    },
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
  bool get hasVoted => votedOptionIndex != null || votedOptionIndices.isNotEmpty;
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

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

  CommunityPost copyWith({
    String? body,
    int? likes,
    int? comments,
    int? reposts,
    int? views,
    bool? liked,
    bool? reposted,
    bool? bookmarked,
    bool? isPinned,
    String? repostedBy,
    AppWritingPostAttachment? attachment,
    CommunityPoll? poll,
    CommunitySentiment? sentiment,
    CommunityReplyAudience? replyAudience,
    bool? isEdited,
    DateTime? editedAt,
    List<String>? imageUrls,
  }) => CommunityPost(
    id: id,
    author: author,
    body: body ?? this.body,
    createdAt: createdAt,
    isPinned: isPinned ?? this.isPinned,
    repostedBy: repostedBy ?? this.repostedBy,
    tickers: tickers,
    tags: tags,
    tradeSetup: tradeSetup,
    linkPreview: linkPreview,
    imageUrl: imageUrl,
    imageUrls: imageUrls ?? this.imageUrls,
    likes: likes ?? this.likes,
    comments: comments ?? this.comments,
    reposts: reposts ?? this.reposts,
    views: views ?? this.views,
    liked: liked ?? this.liked,
    reposted: reposted ?? this.reposted,
    bookmarked: bookmarked ?? this.bookmarked,
    quoted: quoted,
    attachment: attachment ?? this.attachment,
    poll: poll ?? this.poll,
    videoUrl: videoUrl,
    gifUrl: gifUrl,
    sentiment: sentiment ?? this.sentiment,
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

  bool get isLiked => liked;

  CommunityComment copyWith({
    int? likes,
    bool? liked,
    List<CommunityComment>? replies,
    String? sentiment,
    String? parentCommentId,
    String? userReaction,
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
    userReaction: userReaction ?? this.userReaction,
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
}

@immutable
class CommunityNotificationItem {
  const CommunityNotificationItem({
    required this.id,
    required this.actor,
    required this.type,
    required this.createdAt,
    this.postSnippet,
    this.read = false,
  });

  final String id;
  final CommunityAuthor actor;
  final CommunityNotificationType type;
  final DateTime createdAt;
  final String? postSnippet;
  final bool read;

  IconData get icon => switch (type) {
    CommunityNotificationType.like => Icons.favorite_rounded,
    CommunityNotificationType.comment || CommunityNotificationType.reply => Icons.chat_bubble_rounded,
    CommunityNotificationType.repost => Icons.repeat_rounded,
    CommunityNotificationType.follow => Icons.person_add_rounded,
    CommunityNotificationType.mention => Icons.alternate_email_rounded,
    CommunityNotificationType.signal => Icons.auto_graph_rounded,
  };

  String get label => switch (type) {
    CommunityNotificationType.like => 'liked your post',
    CommunityNotificationType.comment || CommunityNotificationType.reply => 'replied to your post',
    CommunityNotificationType.repost => 'reposted your setup',
    CommunityNotificationType.follow => 'followed you',
    CommunityNotificationType.mention => 'mentioned you',
    CommunityNotificationType.signal => 'published a new signal',
  };
}
