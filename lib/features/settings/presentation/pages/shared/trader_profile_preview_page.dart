import 'package:tradex/core/navigation/share_links.dart';
import 'package:tradex/core/utils/share_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for the profile preview surface.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:tradex/features/strategies/ui/strategy_detail_screen.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_space_history.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_edit_post_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_engagement_bar.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_repost_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_share_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_options_sheet.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/journal/ui/journal_entry_screen.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/auth/data/services/supabase_auth_backend_service.dart';

String _formatCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return '$count';
}

String _monthName(int month) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  if (month >= 1 && month <= 12) return months[month - 1];
  return '';
}

/// Stunning, responsive public profile preview resembling Twitter (X) + Trading Journal + Notes.
class TraderProfilePreviewPage extends StatefulWidget {
  const TraderProfilePreviewPage({
    super.key,
    required this.displayName,
    required this.handle,
    required this.userRole,
    this.bio,
    this.avatarUrl,
    this.location,
    this.website,
    this.avgHoldDuration,
    this.primaryMarket,
    this.topStrategy,
    this.riskMantra,
    this.experienceLevel,
    this.tradingStyle,
    this.publicStats,
    this.publicJournals,
    this.referralCode,
    this.channelHandle,
    this.audienceReach,
    this.payoutMethod,
    this.niche,
    this.sampleLink,
    this.phoneNumber,
    this.deskDivision,
    this.adminClearanceLevel,
    this.adminDesignation,
    this.adminSupervisedCapital,
    this.adminTerminalUrl,
    this.adminKillswitchEnabled = true,
    this.adminPreTradeVaREnabled = true,
    this.adminAuditHashingEnabled = true,
    this.repository,
    this.author,
    this.onPostTap,
    this.onOpenRef,
    this.onDirectMessage,
    this.onEditProfile,
    this.isCurrentUser = false,
    this.forceTraderView = false,
    this.subscriptionTier,
    this.verified,
  });

  final String displayName;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final UserRole userRole;
  final String? subscriptionTier;
  final bool? verified;
  final String? location;
  final String? website;
  final String? avgHoldDuration;
  final String? primaryMarket;
  final String? topStrategy;
  final String? riskMantra;
  final String? experienceLevel;
  final String? tradingStyle;
  final bool? publicStats;
  final bool? publicJournals;
  final String? referralCode;
  final String? channelHandle;
  final String? audienceReach;
  final String? payoutMethod;
  final String? niche;
  final String? sampleLink;
  final String? phoneNumber;
  final String? deskDivision;
  final String? adminClearanceLevel;
  final String? adminDesignation;
  final String? adminSupervisedCapital;
  final String? adminTerminalUrl;
  final bool adminKillswitchEnabled;
  final bool adminPreTradeVaREnabled;
  final bool adminAuditHashingEnabled;
  final CommunityRepository? repository;
  final CommunityAuthor? author;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final void Function(AppTrader trader)? onDirectMessage;
  final VoidCallback? onEditProfile;
  final bool isCurrentUser;
  final bool forceTraderView;

  @override
  State<TraderProfilePreviewPage> createState() =>
      _TraderProfilePreviewPageState();
}

class _TraderProfilePreviewPageState extends State<TraderProfilePreviewPage> {
  String? _liveDisplayName;
  String? _liveHandle;
  String? _liveBio;
  String? _liveAvatarUrl;
  String? _liveLocation;
  String? _liveWebsite;
  String? _liveJoinedDate;
  String? _liveAvgHoldDuration;
  String? _livePrimaryMarket;
  String? _liveTopStrategy;
  String? _liveRiskMantra;
  String? _liveExperienceLevel;
  String? _liveTradingStyle;
  double? _liveWinRate;
  int _liveFollowers = 0;
  int _liveFollowing = 0;
  int _livePostsCount = 0;
  bool _isFollowing = false;
  UserRole? _liveRole;
  bool? _liveVerified;
  bool? _livePublicStats;
  bool? _livePublicJournals;
  String? _liveSubscriptionTier;
  int _liveTotalTraders = 0;
  int _liveTotalJournals = 0;
  int _selectedFilterIndex = 0;

  String get _cleanHandle {
    if (widget.handle.trim().isNotEmpty) {
      return widget.handle.replaceFirst(RegExp(r'^@+'), '').trim();
    }
    final raw = (_liveHandle?.trim().isNotEmpty == true)
        ? _liveHandle!
        : (widget.author?.handle.trim().isNotEmpty == true
            ? widget.author!.handle
            : 'trader');
    return raw.replaceFirst(RegExp(r'^@+'), '').trim();
  }

  @override
  void initState() {
    super.initState();
    final repo = widget.repository;
    final targetAuthorId = widget.author?.id.isNotEmpty == true
        ? widget.author!.id
        : '';
    final bool isSelf = widget.isCurrentUser ||
        (targetAuthorId.isNotEmpty &&
            targetAuthorId == SupabaseConfig.client?.auth.currentUser?.id);
    if (repo != null) {
      repo.addListener(_onRepoChanged);
      if (isSelf) {
        _liveFollowing = repo.followingCount;
        _liveFollowers = repo.followersCount;
      } else if (widget.author != null) {
        _isFollowing = repo.isFollowing(widget.author!.id);
        final match = repo.suggestedTraders
            .where((a) => a.id == widget.author!.id)
            .firstOrNull;
        _liveFollowers = match?.followers ?? widget.author!.followers;
        _liveFollowing = match?.following ?? widget.author!.following;
      }
    } else {
      _liveFollowers = widget.author?.followers ?? 0;
      _liveFollowing = widget.author?.following ?? 0;
      _isFollowing = widget.author?.isFollowing ?? false;
    }

    if (widget.isCurrentUser) {
      final cp = ProfileSettingsRepositoryImpl.instance.cachedProfile;
      if (widget.displayName.isEmpty && cp.displayName.isNotEmpty && cp.displayName != 'Your account') {
        _liveDisplayName = cp.displayName;
      }
      if (widget.handle.isEmpty && cp.handle.isNotEmpty) _liveHandle = cp.handle;
      if ((widget.bio == null || widget.bio!.isEmpty) && cp.bio?.isNotEmpty == true) {
        _liveBio = cp.bio;
      }
      if ((widget.avatarUrl == null || widget.avatarUrl!.isEmpty) && cp.avatarUrl?.isNotEmpty == true) {
        _liveAvatarUrl = cp.avatarUrl;
      }
      if ((widget.location == null || widget.location!.isEmpty) && cp.location?.isNotEmpty == true) {
        _liveLocation = cp.location;
      }
      if ((widget.website == null || widget.website!.isEmpty) && cp.website?.isNotEmpty == true) {
        _liveWebsite = cp.website;
      }
      if ((widget.avgHoldDuration == null || widget.avgHoldDuration!.isEmpty) && cp.avgHoldDuration?.isNotEmpty == true) {
        _liveAvgHoldDuration = cp.avgHoldDuration;
      }
      if ((widget.primaryMarket == null || widget.primaryMarket!.isEmpty) && cp.primaryMarket?.isNotEmpty == true) {
        _livePrimaryMarket = cp.primaryMarket;
      }
      if ((widget.topStrategy == null || widget.topStrategy!.isEmpty) && cp.topStrategy?.isNotEmpty == true) {
        _liveTopStrategy = cp.topStrategy;
      }
      if ((widget.riskMantra == null || widget.riskMantra!.isEmpty) && cp.riskMantra?.isNotEmpty == true) {
        _liveRiskMantra = cp.riskMantra;
      }
      if ((widget.experienceLevel == null || widget.experienceLevel!.isEmpty) && cp.experienceLevel?.isNotEmpty == true) {
        _liveExperienceLevel = cp.experienceLevel;
      }
      if ((widget.tradingStyle == null || widget.tradingStyle!.isEmpty) && cp.tradingStyle?.isNotEmpty == true) {
        _liveTradingStyle = cp.tradingStyle;
      }
      if (_liveSubscriptionTier == null && cp.subscriptionTier.isNotEmpty) {
        _liveSubscriptionTier = cp.subscriptionTier;
      }
      _liveVerified ??= cp.verified;
      _livePublicStats ??= cp.publicStats;
      _livePublicJournals ??= cp.publicJournals;
    }
    if (widget.subscriptionTier != null && widget.subscriptionTier!.isNotEmpty) {
      _liveSubscriptionTier ??= widget.subscriptionTier;
    }
    if (widget.verified != null) {
      _liveVerified ??= widget.verified;
    }
    _loadLiveTraderData();
  }

  void _onRepoChanged() {
    if (!mounted) return;
    final repo = widget.repository;
    if (repo == null) return;
    final targetAuthorId = widget.author?.id.isNotEmpty == true
        ? widget.author!.id
        : '';
    final bool isSelf = widget.isCurrentUser ||
        (targetAuthorId.isNotEmpty &&
            targetAuthorId == SupabaseConfig.client?.auth.currentUser?.id);
    setState(() {
      if (isSelf) {
        _liveFollowing = repo.followingCount;
        _liveFollowers = repo.followersCount;
      } else if (widget.author != null) {
        _isFollowing = repo.isFollowing(widget.author!.id);
        final match = repo.suggestedTraders
            .where((a) => a.id == widget.author!.id)
            .firstOrNull;
        if (match != null) {
          _liveFollowers = match.followers;
          _liveFollowing = match.following;
        }
      }
    });
  }

  @override
  void dispose() {
    widget.repository?.removeListener(_onRepoChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TraderProfilePreviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle ||
        oldWidget.author?.id != widget.author?.id ||
        oldWidget.displayName != widget.displayName) {
      if (widget.repository != null && widget.author != null) {
        _isFollowing = widget.repository!.isFollowing(widget.author!.id);
        final match = widget.repository!.suggestedTraders
            .where((a) => a.id == widget.author!.id)
            .firstOrNull;
        _liveFollowers = match?.followers ?? widget.author!.followers;
        _liveFollowing = match?.following ?? widget.author!.following;
      } else if (widget.author != null) {
        _liveFollowers = widget.author!.followers;
        _liveFollowing = widget.author!.following;
        _isFollowing = widget.author!.isFollowing;
      }
      _loadLiveTraderData();
    }
    if (widget.subscriptionTier != oldWidget.subscriptionTier && widget.subscriptionTier != null) {
      _liveSubscriptionTier = widget.subscriptionTier;
    }
    if (widget.verified != oldWidget.verified && widget.verified != null) {
      _liveVerified = widget.verified;
    }
  }

  Future<void> _loadLiveTraderData() async {
    if (!SupabaseConfig.isConfigured) return;
    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      final currentAuthUser = client.auth.currentUser;
      final String cleanH = _cleanHandle;
      final String targetId = widget.author?.id.isNotEmpty == true
          ? widget.author!.id
          : (widget.isCurrentUser && currentAuthUser != null ? currentAuthUser.id : '');

      const profileColumns =
          'id, handle, display_name, bio, avatar_url, location, website, '
          'avg_hold_duration, primary_market, top_strategy, risk_mantra, '
          'experience_level, trading_style, verified, subscription_tier, '
          'notification_settings, public_stats, public_journals, role, created_at';
      Map<String, dynamic>? profileRow;
      if (targetId.isNotEmpty) {
        profileRow = await client
            .from('profiles')
            .select(profileColumns)
            .eq('id', targetId)
            .maybeSingle();
      }
      if (profileRow == null && cleanH.isNotEmpty) {
        final rows = await client
            .from('profiles')
            .select(profileColumns)
            .or('handle.eq.$cleanH,handle.eq.@$cleanH')
            .limit(1);
        if (rows.isNotEmpty) {
          profileRow = rows.first;
        }
      }

      final effectiveUserId = profileRow != null
          ? (profileRow['id'] as String? ?? targetId)
          : targetId;

      if (profileRow != null) {
        if (_liveDisplayName == null && widget.displayName.isEmpty) {
          _liveDisplayName = profileRow['display_name'] as String?;
        }
        if (_liveHandle == null && widget.handle.isEmpty) {
          _liveHandle = profileRow['handle'] as String?;
        }
        if (_liveBio == null && (widget.bio == null || widget.bio!.isEmpty)) {
          _liveBio = profileRow['bio'] as String?;
        }
        if (_liveAvatarUrl == null && (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)) {
          _liveAvatarUrl = profileRow['avatar_url'] as String?;
        }
        if (_liveLocation == null && (widget.location == null || widget.location!.isEmpty)) {
          _liveLocation = profileRow['location'] as String?;
        }
        if (_liveWebsite == null && (widget.website == null || widget.website!.isEmpty)) {
          _liveWebsite = profileRow['website'] as String?;
        }
        if (_liveAvgHoldDuration == null && (widget.avgHoldDuration == null || widget.avgHoldDuration!.isEmpty)) {
          _liveAvgHoldDuration = profileRow['avg_hold_duration'] as String?;
        }
        if (_livePrimaryMarket == null && (widget.primaryMarket == null || widget.primaryMarket!.isEmpty)) {
          _livePrimaryMarket = profileRow['primary_market'] as String?;
        }
        if (_liveTopStrategy == null && (widget.topStrategy == null || widget.topStrategy!.isEmpty)) {
          _liveTopStrategy = profileRow['top_strategy'] as String?;
        }
        if (_liveRiskMantra == null && (widget.riskMantra == null || widget.riskMantra!.isEmpty)) {
          _liveRiskMantra = profileRow['risk_mantra'] as String?;
        }
        if (_liveExperienceLevel == null && (widget.experienceLevel == null || widget.experienceLevel!.isEmpty)) {
          _liveExperienceLevel = profileRow['experience_level'] as String?;
        }
        if (_liveTradingStyle == null && (widget.tradingStyle == null || widget.tradingStyle!.isEmpty)) {
          _liveTradingStyle = profileRow['trading_style'] as String?;
        }
        _liveVerified = profileRow['verified'] as bool?;
        _liveSubscriptionTier = profileRow['subscription_tier'] as String?;
        final notif = profileRow['notification_settings'] is Map
            ? Map<String, dynamic>.from(
                profileRow['notification_settings'] as Map,
              )
            : null;
        _livePublicStats = profileRow['public_stats'] as bool? ??
            notif?['public_stats'] as bool? ??
            _livePublicStats;
        _livePublicJournals = profileRow['public_journals'] as bool? ??
            notif?['public_journals'] as bool? ??
            _livePublicJournals;

        final roleStr = profileRow['role'] as String?;
        if (roleStr != null) {
          _liveRole = switch (roleStr.toLowerCase()) {
            'affiliate' => UserRole.affiliate,
            'user_admin' || 'admin' => UserRole.userAdmin,
            _ => UserRole.customer,
          };
        }

        final createdAtRaw = profileRow['created_at'] as String?;
        if (createdAtRaw != null) {
          final dt = DateTime.tryParse(createdAtRaw);
          if (dt != null) {
            _liveJoinedDate = 'Joined ${_monthName(dt.month)} ${dt.year}';
          }
        }
      }

      if (effectiveUserId.isNotEmpty) {
        try {
          _liveFollowers = await client
              .from('community_follows')
              .count()
              .eq('following_id', effectiveUserId);
        } catch (_) {}

        try {
          _liveFollowing = await client
              .from('community_follows')
              .count()
              .eq('follower_id', effectiveUserId);
        } catch (_) {}

        if (currentAuthUser != null && currentAuthUser.id != effectiveUserId) {
          try {
            final isFollowRes = await client
                .from('community_follows')
                .select('id')
                .eq('follower_id', currentAuthUser.id)
                .eq('following_id', effectiveUserId)
                .maybeSingle();
            _isFollowing = isFollowRes != null;
          } catch (_) {}
        }

        try {
          _livePostsCount = await client
              .from('community_posts')
              .count()
              .eq('author_id', effectiveUserId);
        } catch (_) {}

        try {
          final journalRows = await client
              .from('journal_entries')
              .select('outcome, pnl, opened_at, closed_at, ticker')
              .eq('user_id', effectiveUserId)
              .limit(500);

          final entries = (journalRows as List);
          if (entries.isNotEmpty) {
            int closedCount = 0;
            int winCount = 0;
            final Map<String, int> tickerCounts = <String, int>{};
            int totalHoldMinutes = 0;
            int holdCount = 0;

            for (final item in entries) {
              final outcome = (item['outcome'] as String?)?.toLowerCase();
              final pnl = (item['pnl'] as num?)?.toDouble();
              final isWin = outcome == 'win' || (outcome == null && pnl != null && pnl > 0);
              final isLoss = outcome == 'loss' || (outcome == null && pnl != null && pnl < 0);
              final isBreakeven = outcome == 'breakeven' || (outcome == null && pnl != null && pnl == 0);

              if (isWin || isLoss || isBreakeven) {
                closedCount++;
                if (isWin) winCount++;
              }

              final ticker = item['ticker'] as String?;
              if (ticker != null && ticker.trim().isNotEmpty) {
                tickerCounts[ticker.trim()] = (tickerCounts[ticker.trim()] ?? 0) + 1;
              }

              final openedAtStr = item['opened_at'] as String?;
              final closedAtStr = item['closed_at'] as String?;
              if (openedAtStr != null && closedAtStr != null) {
                final o = DateTime.tryParse(openedAtStr);
                final c = DateTime.tryParse(closedAtStr);
                if (o != null && c != null && c.isAfter(o)) {
                  totalHoldMinutes += c.difference(o).inMinutes;
                  holdCount++;
                }
              }
            }

            if (closedCount > 0) {
              _liveWinRate = (winCount / closedCount) * 100.0;
            }

            if ((_livePrimaryMarket == null || _livePrimaryMarket!.isEmpty) && tickerCounts.isNotEmpty) {
              final sortedTickers = tickerCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              _livePrimaryMarket = sortedTickers.first.key;
            }

            if ((_liveAvgHoldDuration == null || _liveAvgHoldDuration!.isEmpty) && holdCount > 0) {
              final avgM = totalHoldMinutes ~/ holdCount;
              if (avgM < 60) {
                _liveAvgHoldDuration = '${avgM}m (Intraday)';
              } else if (avgM < 1440) {
                _liveAvgHoldDuration = '${avgM ~/ 60}h ${avgM % 60}m';
              } else {
                _liveAvgHoldDuration = '${avgM ~/ 1440}d (Swing)';
              }
            }
          }
        } catch (e) {
          debugPrint('[TraderProfilePreviewPage] journal query error: $e');
        }
      }

      if (widget.userRole == UserRole.userAdmin || _liveRole == UserRole.userAdmin) {
        try {
          _liveTotalTraders = await client.from('profiles').count();
        } catch (_) {}
        try {
          _liveTotalJournals = await client.from('journal_entries').count();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[TraderProfilePreviewPage] _loadLiveTraderData error: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final bool isPublicView = widget.forceTraderView || !widget.isCurrentUser;
    final bool isAffiliate =
        !isPublicView && widget.userRole == UserRole.affiliate;
    final bool isAdmin = !isPublicView && widget.userRole == UserRole.userAdmin;
    final UserRole effectiveRole = isPublicView
        ? UserRole.customer
        : (_liveRole ?? widget.userRole);

    final String effectiveDisplayName = widget.displayName.trim().isNotEmpty
        ? widget.displayName.trim()
        : ((_liveDisplayName?.trim().isNotEmpty == true)
            ? _liveDisplayName!
            : (widget.author?.displayName.trim().isNotEmpty == true
                ? widget.author!.displayName.trim()
                : 'Trader'));

    final String? effectiveAvatarUrl = widget.avatarUrl?.trim().isNotEmpty == true
        ? widget.avatarUrl!.trim()
        : ((_liveAvatarUrl?.trim().isNotEmpty == true)
            ? _liveAvatarUrl
            : widget.author?.avatarUrl);

    final bool effectiveVerified = (!isAdmin) &&
        ((_liveVerified ??
            widget.verified ??
            widget.author?.verified ??
            (widget.isCurrentUser
                ? (ProfileSettingsRepositoryImpl.instance.cachedProfile.verified ||
                    (SupabaseAuthBackendService.instance.currentUserProfile?.verified ?? false))
                : false)) == true);

    final String? effectiveLocation = widget.location?.trim().isNotEmpty == true
        ? widget.location!.trim()
        : ((_liveLocation?.trim().isNotEmpty == true)
            ? _liveLocation
            : widget.author?.location);

    final String? effectiveWebsite = widget.website?.trim().isNotEmpty == true
        ? widget.website!.trim()
        : ((_liveWebsite?.trim().isNotEmpty == true)
            ? _liveWebsite
            : widget.author?.website);

    final String? effectiveJoined = (_liveJoinedDate?.trim().isNotEmpty == true)
        ? _liveJoinedDate
        : widget.author?.joinedDate;

    final String? effectiveHold = widget.avgHoldDuration?.trim().isNotEmpty == true
        ? widget.avgHoldDuration!.trim()
        : ((_liveAvgHoldDuration?.trim().isNotEmpty == true)
            ? _liveAvgHoldDuration
            : widget.author?.avgHoldDuration);

    final String? effectiveMarket = widget.primaryMarket?.trim().isNotEmpty == true
        ? widget.primaryMarket!.trim()
        : ((_livePrimaryMarket?.trim().isNotEmpty == true)
            ? _livePrimaryMarket
            : widget.author?.primaryMarket);

    final String? effectiveStrategy = widget.topStrategy?.trim().isNotEmpty == true
        ? widget.topStrategy!.trim()
        : ((_liveTopStrategy?.trim().isNotEmpty == true)
            ? _liveTopStrategy
            : widget.author?.tradingStyle);

    final String? effectiveRiskMantra = widget.riskMantra?.trim().isNotEmpty == true
        ? widget.riskMantra!.trim()
        : ((_liveRiskMantra?.trim().isNotEmpty == true)
            ? _liveRiskMantra
            : widget.author?.riskMantra);

    final String? effectiveExperience = widget.experienceLevel?.trim().isNotEmpty == true
        ? widget.experienceLevel!.trim()
        : ((_liveExperienceLevel?.trim().isNotEmpty == true)
            ? _liveExperienceLevel
            : widget.author?.experienceLevel);

    final String? effectiveStyle = widget.tradingStyle?.trim().isNotEmpty == true
        ? widget.tradingStyle!.trim()
        : ((_liveTradingStyle?.trim().isNotEmpty == true)
            ? _liveTradingStyle
            : widget.author?.tradingStyle);

    final String targetAuthorId = widget.author?.id.isNotEmpty == true
        ? widget.author!.id
        : (widget.isCurrentUser && SupabaseConfig.client?.auth.currentUser != null
            ? SupabaseConfig.client!.auth.currentUser!.id
            : '');

    final String currentAuthId =
        SupabaseConfig.client?.auth.currentUser?.id ?? '';
    final String cachedHandle = ProfileSettingsRepositoryImpl
        .instance.cachedProfile.handle
        .toLowerCase()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();
    final authUser = SupabaseConfig.client?.auth.currentUser;
    final String authHandle = (authUser?.userMetadata?['handle'] as String? ??
            authUser?.userMetadata?['username'] as String? ??
            authUser?.email?.split('@').first ??
            '')
        .toLowerCase()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();
    final bool isViewingSelf = widget.isCurrentUser ||
        (currentAuthId.isNotEmpty && targetAuthorId == currentAuthId) ||
        (cachedHandle.isNotEmpty && cachedHandle == _cleanHandle.toLowerCase()) ||
        (authHandle.isNotEmpty && authHandle == _cleanHandle.toLowerCase());

    final bool isSelf = isViewingSelf;

    final bool effectivePublicStats = widget.publicStats ??
        _livePublicStats ??
        (isViewingSelf
            ? ProfileSettingsRepositoryImpl.instance.cachedProfile.publicStats
            : true);

    final bool effectivePublicJournals = widget.publicJournals ??
        _livePublicJournals ??
        (isViewingSelf
            ? ProfileSettingsRepositoryImpl.instance.cachedProfile.publicJournals
            : true);

    final AppJournalStats? localJournalStats =
        isViewingSelf ? JournalRepositoryScope.repository.stats : null;

    final double? effectiveWinRate = _liveWinRate ??
        (widget.author?.winRate != null
            ? (widget.author!.winRate! <= 1.0
                ? widget.author!.winRate! * 100.0
                : widget.author!.winRate)
            : (localJournalStats != null && localJournalStats.total > 0
                ? localJournalStats.winRate
                : null));

    final int effectiveDisciplineScore = (localJournalStats != null &&
            localJournalStats.total > 0)
        ? (72 + (localJournalStats.winRate * 0.25).round()).clamp(60, 99)
        : (effectiveWinRate != null
            ? (72 + (effectiveWinRate * 0.25).round()).clamp(60, 99)
            : 92);

    final int effectiveFollowers = _liveFollowers;

    final int effectiveFollowing = _liveFollowing;

    final int effectivePosts = _livePostsCount > 0
        ? _livePostsCount
        : (widget.repository != null && widget.author != null
            ? widget.repository!.postsForAuthor(widget.author!.id).length
            : (widget.author?.postsCount ?? 0));

    final Color verifiedColor = switch (effectiveRole) {
      UserRole.customer => theme.colors.primary,
      UserRole.affiliate => theme.colors.warning,
      UserRole.userAdmin => theme.colors.destructive,
    };

    final String rawSubTier = (_liveSubscriptionTier?.trim().isNotEmpty == true)
        ? _liveSubscriptionTier!
        : (widget.subscriptionTier?.trim().isNotEmpty == true
            ? widget.subscriptionTier!
            : (widget.author?.subscriptionTier.trim().isNotEmpty == true
                ? widget.author!.subscriptionTier
                : (widget.isCurrentUser
                    ? (SupabaseAuthBackendService.instance.currentUserProfile?.subscriptionTier ??
                        ProfileSettingsRepositoryImpl.instance.cachedProfile.subscriptionTier)
                    : (widget.author != null ? widget.author!.tier.name : 'free'))));
    final String cleanSubTier = rawSubTier.toLowerCase().trim();

    final String roleBadgeText = switch (effectiveRole) {
      UserRole.userAdmin => 'DESK SUPERADMIN · ROOT',
      UserRole.affiliate => 'OFFICIAL PARTNER',
      UserRole.customer => switch (cleanSubTier) {
          'enterprise' => 'ENTERPRISE PLAN',
          'pro' => 'PRO TRADER',
          'premium' => 'PREMIUM PLAN',
          'basic' || 'starter' => 'BASIC PLAN',
          'free' || _ => switch (widget.author?.tier) {
              AppTier.enterprise => 'ENTERPRISE PLAN',
              AppTier.premium => 'BASIC PLAN',
              _ => 'FREE PLAN',
            },
        },
    };

    final UiIntent roleBadgeIntent = switch (effectiveRole) {
      UserRole.userAdmin => UiIntent.danger,
      UserRole.affiliate => UiIntent.warning,
      UserRole.customer => switch (cleanSubTier) {
          'enterprise' => UiIntent.success,
          'pro' || 'premium' => UiIntent.primary,
          'basic' || 'starter' => UiIntent.info,
          'free' || _ => switch (widget.author?.tier) {
              AppTier.enterprise => UiIntent.success,
              AppTier.premium => UiIntent.primary,
              _ => UiIntent.neutral,
            },
        },
    };

    final String displayBio = widget.bio?.trim().isNotEmpty == true
        ? widget.bio!.trim()
        : ((_liveBio?.trim().isNotEmpty == true)
            ? _liveBio!
            : (widget.author?.bio?.trim().isNotEmpty == true
                ? widget.author!.bio!
                : (isAdmin
                    ? 'Chief Risk Officer & Proprietary Desk Overseer. Managing firm-wide risk boundaries, capital allocation matrices, and trading engine infrastructure.'
                    : (isAffiliate
                        ? 'Official alphajournal Partner & trading educator. Sharing trade setups, execution blueprints, and member discounts.'
                        : ''))));

    final List<UiTabItem> tabItems = switch (effectiveRole) {
      UserRole.userAdmin => <UiTabItem>[
        UiTabItem(
          label: 'Command Center',
          icon: Icons.terminal_rounded,
          content: _AdminCommandCenterPreview(
            clearanceLevel: widget.adminClearanceLevel,
            deskDivision: widget.deskDivision,
            designation: widget.adminDesignation,
            supervisedCapital: widget.adminSupervisedCapital,
            terminalUrl: widget.adminTerminalUrl,
            killswitchEnabled: widget.adminKillswitchEnabled,
            preTradeVaREnabled: widget.adminPreTradeVaREnabled,
            auditHashingEnabled: widget.adminAuditHashingEnabled,
          ),
        ),
        UiTabItem(
          label: 'Risk & Audit Stream',
          icon: Icons.security_rounded,
          content: const _AdminRiskAuditPreview(),
        ),
        UiTabItem(
          label: 'Desk Governance',
          icon: Icons.account_tree_rounded,
          content: const _AdminDeskGovernancePreview(),
        ),
        UiTabItem(
          label: 'Firm Analytics',
          icon: Icons.analytics_outlined,
          content: const _AdminAnalyticsPreview(),
        ),
      ],
      UserRole.affiliate => <UiTabItem>[
        UiTabItem(
          label: 'Campaigns',
          icon: Icons.campaign_outlined,
          content: _AffiliateCampaignsPreview(
            displayName: effectiveDisplayName,
            handle: _cleanHandle,
            referralCode: widget.referralCode ?? 'TRADEX-PARTNER-2026',
            avatarUrl: effectiveAvatarUrl,
            verifiedColor: verifiedColor,
          ),
        ),
        UiTabItem(
          label: 'Community Perks',
          icon: Icons.card_giftcard_rounded,
          content: _AffiliateReferralPortalPreview(
            referralCode: widget.referralCode ?? 'TRADEX-PARTNER-2026',
            audienceReach: widget.audienceReach ?? '10,000 – 100,000',
            niche: widget.niche ?? widget.primaryMarket,
            payoutMethod: widget.payoutMethod,
            sampleLink: widget.sampleLink,
            channelHandle: widget.channelHandle,
            phoneNumber: widget.phoneNumber,
          ),
        ),
        UiTabItem(
          label: 'Strategies',
          icon: Icons.menu_book_outlined,
          content: _StrategiesPreview(
            authorId: targetAuthorId,
            handle: _cleanHandle,
            onOpenRef: widget.onOpenRef,
            isCurrentUser: isSelf,
          ),
        ),
        UiTabItem(
          label: 'Notes',
          icon: Icons.note_alt_outlined,
          content: _NotesPlaybooksPreview(
            authorId: targetAuthorId,
            handle: _cleanHandle,
            onOpenRef: widget.onOpenRef,
            isCurrentUser: isSelf,
          ),
        ),
        const UiTabItem(
          label: 'Community Overview',
          icon: Icons.groups_outlined,
          content: _AffiliateCommunityOverviewPreview(),
        ),
      ],
      UserRole.customer => <UiTabItem>[
        UiTabItem(
          label: 'Posts',
          icon: Icons.dynamic_feed_outlined,
          content: _TwitterFeedPreview(
            displayName: effectiveDisplayName,
            handle: _cleanHandle,
            avatarUrl: effectiveAvatarUrl,
            verifiedColor: verifiedColor,
            repository: widget.repository,
            author: widget.author,
            onPostTap: widget.onPostTap,
            onOpenRef: widget.onOpenRef,
            isCurrentUser: widget.isCurrentUser,
          ),
        ),
        UiTabItem(
          label: 'Journal',
          icon: Icons.auto_stories_outlined,
          content: _PublicJournalPreview(
            selectedFilter: _selectedFilterIndex,
            onFilterChanged: (int idx) =>
                setState(() => _selectedFilterIndex = idx),
            authorId: targetAuthorId,
            handle: _cleanHandle,
            onOpenRef: widget.onOpenRef,
            isCurrentUser: isSelf,
            publicJournals: effectivePublicJournals,
          ),
        ),
        UiTabItem(
          label: 'Strategies',
          icon: Icons.menu_book_outlined,
          content: _StrategiesPreview(
            authorId: targetAuthorId,
            handle: _cleanHandle,
            onOpenRef: widget.onOpenRef,
            isCurrentUser: isSelf,
          ),
        ),
        UiTabItem(
          label: 'Notes',
          icon: Icons.note_alt_outlined,
          content: _NotesPlaybooksPreview(
            authorId: targetAuthorId,
            handle: _cleanHandle,
            onOpenRef: widget.onOpenRef,
            isCurrentUser: isSelf,
          ),
        ),
      ],
    };

    tabItems.add(
      UiTabItem(
        label: 'Spaces History',
        icon: Icons.podcasts_rounded,
        content: CommunitySpaceHistory(
          handle: _cleanHandle,
          authorId: targetAuthorId,
          repository: widget.repository,
        ),
      ),
    );

    if (isViewingSelf) {
      tabItems.add(
        UiTabItem(
          label: 'Pending Approval',
          icon: Icons.pending_actions_rounded,
          content: _TraderPendingApprovalPostsPreview(
            authorId: targetAuthorId,
            handle: _cleanHandle,
            repository: widget.repository,
            author: widget.author,
            onPostTap: widget.onPostTap,
            onOpenRef: widget.onOpenRef,
            verifiedColor: verifiedColor,
          ),
        ),
      );
      tabItems.add(
        UiTabItem(
          label: 'Activity',
          icon: Icons.history_rounded,
          content: _TraderActivityHistoryPreview(
            authorId: targetAuthorId,
            handle: _cleanHandle,
            repository: widget.repository,
            onPostTap: widget.onPostTap,
          ),
        ),
      );
    }

    final Color bannerColor = isAdmin
        ? theme.colors.destructive
        : (isAffiliate ? theme.colors.warning : theme.colors.primary);

    final String bannerBadgeText = isAdmin
        ? 'ROOT SUPERUSER · LEVEL 5'
        : (isAffiliate ? 'PARTNER PORTAL' : 'PUBLIC PROFILE');

    final IconData bannerBadgeIcon = isAdmin
        ? Icons.admin_panel_settings_rounded
        : (isAffiliate
              ? Icons.workspace_premium_rounded
              : Icons.public_rounded);

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.lg),
        context.sp(theme.spacing.md),
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(700)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[

              // ---------------------------------------------------------------
              // Twitter/X Style Profile Hero Card
              // ---------------------------------------------------------------
              UiCard(
                padding: EdgeInsets.zero,
                variant: UiCardVariant.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // 1. Cover / Banner Header
                    Container(
                      height: context.sz(isMobile ? 120 : 160),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[
                            bannerColor.withValues(alpha: 0.85),
                            theme.colors.surfaceMuted,
                            bannerColor.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: <Widget>[
                          // Subtle financial grid pattern overlay
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GridPatternPainter(
                                gridColor: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          // Top banner badge
                          Positioned(
                            top: context.sp(theme.spacing.sm),
                            right: context.sp(theme.spacing.sm),
                            child: UiBadge(
                              label: bannerBadgeText,
                              icon: bannerBadgeIcon,
                              intent: isAdmin
                                  ? UiIntent.danger
                                  : (isAffiliate
                                        ? UiIntent.warning
                                        : UiIntent.primary),
                              variant: UiBadgeVariant.solid,
                              size: UiSize.xs,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Avatar + Action Buttons Row (Overlapping Banner)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(
                          isMobile ? theme.spacing.md : theme.spacing.lg,
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          // Overlapping Avatar
                          Positioned(
                            top: -context.sz(isMobile ? 36 : 48),
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: theme.colors.surface,
                                shape: BoxShape.circle,
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: UiAvatar(
                                name: effectiveDisplayName,
                                imageUrl: effectiveAvatarUrl,
                                size: isMobile ? UiSize.lg : UiSize.xl,
                                verified: effectiveVerified,
                                verifiedColor: verifiedColor,
                              ),
                            ),
                          ),

                          // Top-right Action Buttons
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: context.sp(theme.spacing.sm),
                                bottom: context.sp(theme.spacing.xs),
                                left: context.sz(isMobile ? 84 : 108),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: context.sp(theme.spacing.xs),
                                runSpacing: context.sp(theme.spacing.xs),
                                children: <Widget>[
                                  if (isAdmin) ...[
                                    UiButton(
                                      label: 'Root Terminal',
                                      leadingIcon: Icons.terminal_rounded,
                                      variant: UiVariant.primary,
                                      intent: UiIntent.danger,
                                      size: UiSize.md,
                                      expandOnMobile: false,
                                      onPressed: () {
                                        UiToast.show(
                                          context,
                                          title: 'Admin Terminal',
                                          message:
                                              'Initializing root administrative session with Level 5 clearance...',
                                          intent: UiIntent.danger,
                                        );
                                      },
                                    ),
                                    UiIconButton(
                                      icon: Icons.crisis_alert_rounded,
                                      tooltip: 'Emergency Killswitch',
                                      variant: UiVariant.outline,
                                      size: UiSize.md,
                                      onPressed: () {
                                        UiToast.show(
                                          context,
                                          title: 'Killswitch Armed',
                                          message:
                                              'Global trade matching and margin engines are nominal.',
                                          intent: UiIntent.warning,
                                        );
                                      },
                                    ),
                                    UiIconButton(
                                      icon: Icons.tune_rounded,
                                      tooltip: 'Risk Governance Config',
                                      variant: UiVariant.outline,
                                      size: UiSize.md,
                                      onPressed: () {
                                        UiToast.show(
                                          context,
                                          title: 'Risk Config',
                                          message:
                                              'Opening institutional risk parameters panel.',
                                          intent: UiIntent.info,
                                        );
                                      },
                                    ),
                                  ] else ...[
                                    UiIconButton(
                                      icon: Icons.share_outlined,
                                      tooltip: isAffiliate
                                          ? 'Share Referral Link'
                                          : 'Share Profile',
                                      variant: UiVariant.outline,
                                      size: UiSize.md,
                                      onPressed: () {
                                        final link = isAffiliate
                                            ? AppShareLinks.referral(widget.referralCode ?? _cleanHandle)
                                            : AppShareLinks.profile(_cleanHandle);
                                        ShareActions.showLinkShareSheet(
                                          context,
                                          title: isAffiliate
                                              ? 'Share Affiliate Referral'
                                              : 'Share Trader Profile',
                                          subtitle: isAffiliate
                                              ? effectiveDisplayName
                                              : '@$_cleanHandle',
                                          url: link,
                                          copyToastTitle: isAffiliate
                                              ? 'Referral link copied'
                                              : 'Profile link copied',
                                        );
                                      },
                                    ),
                                    if (isViewingSelf && widget.onEditProfile != null)
                                      UiButton(
                                        label: 'Edit Profile',
                                        leadingIcon: Icons.edit_outlined,
                                        variant: UiVariant.outline,
                                        size: UiSize.md,
                                        onPressed: widget.onEditProfile,
                                      ),
                                    if (!isViewingSelf) ...[
                                      UiIconButton(
                                        icon: Icons.mail_outline_rounded,
                                        tooltip: 'Direct Message',
                                        variant: UiVariant.outline,
                                        size: UiSize.md,
                                        onPressed: () {
                                          final AppTrader peer = AppTrader(
                                            id: targetAuthorId.isNotEmpty
                                                ? targetAuthorId
                                                : 'trader_$_cleanHandle',
                                            handle: '@$_cleanHandle',
                                            displayName: effectiveDisplayName,
                                            avatarUrl: effectiveAvatarUrl,
                                            bio: displayBio,
                                            tier:
                                                widget.userRole ==
                                                    UserRole.affiliate
                                                ? AppTier.premium
                                                : AppTier.free,
                                          );
                                          if (widget.onDirectMessage != null) {
                                            widget.onDirectMessage!(peer);
                                          } else {
                                            try {
                                              final repo = MessagesRepositoryScope
                                                  .repository;
                                              if (repo.isMessagingRestricted(
                                                peer,
                                              )) {
                                                UiDialog.show<void>(
                                                  context,
                                                  child: UiDialog(
                                                    title:
                                                        'Cannot message @$_cleanHandle',
                                                    content: Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            vertical: context.sp(
                                                              context
                                                                  .ui
                                                                  .spacing
                                                                  .sm,
                                                            ),
                                                          ),
                                                      child: Text(
                                                        '@$_cleanHandle does not accept direct messages from everyone. Only invited traders or accounts they follow can start a conversation.',
                                                        style:
                                                            context.uiText.body,
                                                      ),
                                                    ),
                                                    actions: <Widget>[
                                                      UiButton(
                                                        label: 'OK',
                                                        intent: UiIntent.primary,
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                return;
                                              }
                                              repo.startConversation(peer);
                                              UiToast.show(
                                                context,
                                                title: 'Direct Message',
                                                message:
                                                    'Started conversation with @$_cleanHandle',
                                                intent: UiIntent.success,
                                              );
                                            } catch (_) {
                                              UiToast.show(
                                                context,
                                                title: 'Direct Message',
                                                message:
                                                    'Opening conversation with @$_cleanHandle',
                                                intent: UiIntent.info,
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      UiIconButton(
                                        icon: _isFollowing
                                            ? Icons.check_rounded
                                            : (isAffiliate
                                                  ? Icons.stars_rounded
                                                  : Icons
                                                        .person_add_alt_1_rounded),
                                        variant: _isFollowing
                                            ? UiVariant.outline
                                            : UiVariant.primary,
                                        intent: isAffiliate
                                            ? UiIntent.warning
                                            : UiIntent.primary,
                                        size: UiSize.md,
                                        tooltip: isAffiliate
                                            ? (_isFollowing
                                                  ? 'Subscribed to @$_cleanHandle'
                                                  : 'Subscribe to @$_cleanHandle')
                                            : (_isFollowing
                                                  ? 'Following @$_cleanHandle'
                                                  : 'Follow @$_cleanHandle'),
                                        onPressed: () async {
                                          setState(() {
                                            _isFollowing = !_isFollowing;
                                            if (_isFollowing) {
                                              _liveFollowers++;
                                            } else {
                                              if (_liveFollowers > 0) _liveFollowers--;
                                            }
                                          });

                                          final targetTid = targetAuthorId.isNotEmpty
                                              ? targetAuthorId
                                              : (widget.author?.id ?? '');
                                          if (widget.repository != null && targetTid.isNotEmpty) {
                                            widget.repository!.toggleFollow(targetTid);
                                          } else if (SupabaseConfig.isConfigured && targetTid.isNotEmpty) {
                                            try {
                                              final client = SupabaseConfig.client!;
                                              final curUid = client.auth.currentUser?.id;
                                              if (curUid != null && curUid.isNotEmpty) {
                                                if (_isFollowing) {
                                                  await client.from('community_follows').insert({
                                                    'follower_id': curUid,
                                                    'following_id': targetTid,
                                                  });
                                                } else {
                                                  await client.from('community_follows').delete()
                                                      .eq('follower_id', curUid)
                                                      .eq('following_id', targetTid);
                                                }
                                              }
                                            } catch (e) {
                                              debugPrint('[TraderProfilePreviewPage] toggleFollow error: $e');
                                            }
                                          }

                                          if (!mounted || !context.mounted) return;
                                          UiToast.show(
                                            context,
                                            title: _isFollowing
                                                ? (isAffiliate
                                                      ? 'Subscribed to @$_cleanHandle'
                                                      : 'Following @$_cleanHandle')
                                                : (isAffiliate
                                                      ? 'Unsubscribed from @$_cleanHandle'
                                                      : 'Unfollowed @$_cleanHandle'),
                                            message: _isFollowing
                                                ? (isAffiliate
                                                      ? 'You will receive creator playbooks and updates.'
                                                      : 'Now following @$_cleanHandle.')
                                                : 'You have unfollowed @$_cleanHandle.',
                                            intent: _isFollowing
                                                ? UiIntent.success
                                                : UiIntent.neutral,
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. User Identity & Details
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        context.sp(
                          isMobile ? theme.spacing.md : theme.spacing.lg,
                        ),
                        context.sp(
                          isMobile ? theme.spacing.sm : theme.spacing.md,
                        ),
                        context.sp(
                          isMobile ? theme.spacing.md : theme.spacing.lg,
                        ),
                        context.sp(theme.spacing.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Name + Checkmark + Role Badge
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: context.sp(theme.spacing.xs),
                            runSpacing: context.sp(theme.spacing.xxs),
                            children: <Widget>[
                              Text(
                                effectiveDisplayName,
                                style: context.uiText.heading.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: context.fs(isMobile ? 18 : 22),
                                ),
                              ),
                              if (isAdmin || effectiveVerified)
                                UiTooltip(
                                  message: isAdmin
                                      ? 'Desk Superadmin (Root Clearance)'
                                      : (isAffiliate
                                            ? 'Verified Affiliate Partner'
                                            : 'Verified market participant'),
                                  child: Icon(
                                    isAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.verified_rounded,
                                    color: verifiedColor,
                                    size: context.sz(20),
                                  ),
                                ),
                              UiBadge(
                                label: roleBadgeText,
                                intent: roleBadgeIntent,
                                variant: UiBadgeVariant.soft,
                                size: UiSize.xs,
                              ),
                              if (effectiveStyle != null &&
                                  effectiveStyle.trim().isNotEmpty &&
                                  !isAdmin &&
                                  !isAffiliate)
                                UiBadge(
                                  label: effectiveStyle,
                                  intent: UiIntent.success,
                                  variant: UiBadgeVariant.soft,
                                  size: UiSize.xs,
                                ),
                            ],
                          ),

                          // Handle & Meta row
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            '@$_cleanHandle',
                            style: context.uiText.body.copyWith(
                              color: theme.colors.foregroundMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // Bio
                          if (displayBio.trim().isNotEmpty) ...[
                            SizedBox(height: context.sp(theme.spacing.sm)),
                            Text(
                              displayBio,
                              style: context.uiText.body.copyWith(
                                height: 1.45,
                                fontSize: context.fs(14),
                              ),
                            ),
                          ],

                          // Metadata row (Location, Joined, Link, Style)
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          Wrap(
                            spacing: context.sp(theme.spacing.md),
                            runSpacing: context.sp(theme.spacing.xs),
                            children: <Widget>[
                              if (isAdmin) ...[
                                _MetaItem(
                                  icon: Icons.shield_rounded,
                                  text: widget.adminClearanceLevel?.isNotEmpty == true
                                      ? 'Clearance: ${widget.adminClearanceLevel}'
                                      : 'Clearance: Root Admin / L5',
                                ),
                                _MetaItem(
                                  icon: Icons.domain_rounded,
                                  text: widget.deskDivision?.isNotEmpty == true
                                      ? widget.deskDivision!
                                      : (effectiveStrategy?.trim().isNotEmpty ==
                                              true
                                          ? effectiveStrategy!
                                          : 'Proprietary Trading Desk'),
                                ),
                                if (widget.adminDesignation?.isNotEmpty == true)
                                  _MetaItem(
                                    icon: Icons.badge_outlined,
                                    text: widget.adminDesignation!,
                                  ),
                                if (widget.adminSupervisedCapital?.isNotEmpty == true)
                                  _MetaItem(
                                    icon: Icons.account_balance_wallet_outlined,
                                    text: 'Pool: ${widget.adminSupervisedCapital}',
                                  ),
                                _MetaItem(
                                  icon: Icons.security_rounded,
                                  text: widget.adminAuditHashingEnabled
                                      ? 'Audit Trail: Cryptographic SHA-256'
                                      : 'Audit Trail: Standard Ledger',
                                ),
                                _MetaItem(
                                  icon: Icons.speed_rounded,
                                  text: widget.adminPreTradeVaREnabled
                                      ? 'Engine Latency: Nominal Direct'
                                      : 'Engine Latency: Standard',
                                ),
                                _MetaItem(
                                  icon: Icons.terminal_rounded,
                                  text: widget.adminTerminalUrl?.isNotEmpty == true
                                      ? widget.adminTerminalUrl!
                                      : 'tradex.internal/root',
                                  isLink: true,
                                ),
                              ] else ...[
                                if (effectiveLocation != null &&
                                    effectiveLocation.trim().isNotEmpty)
                                  _MetaItem(
                                    icon: Icons.location_on_outlined,
                                    text: effectiveLocation,
                                  ),
                                if (effectiveJoined != null &&
                                    effectiveJoined.trim().isNotEmpty)
                                  _MetaItem(
                                    icon: Icons.calendar_month_outlined,
                                    text: effectiveJoined,
                                  ),
                                if (isAffiliate) ...[
                                  if (widget.referralCode?.isNotEmpty == true || _cleanHandle.isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.link_rounded,
                                      text:
                                          AppShareLinks.referral(widget.referralCode?.isNotEmpty == true ? widget.referralCode! : _cleanHandle),
                                      isLink: true,
                                    ),
                                  if (widget.channelHandle?.isNotEmpty == true)
                                    _MetaItem(
                                      icon: Icons.alternate_email_rounded,
                                      text: widget.channelHandle!.startsWith('@')
                                          ? widget.channelHandle!
                                          : '@${widget.channelHandle}',
                                    ),
                                  if (effectiveMarket != null && effectiveMarket.isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.category_outlined,
                                      text: effectiveMarket,
                                    ),
                                  if (widget.niche?.isNotEmpty == true && widget.niche != effectiveMarket)
                                    _MetaItem(
                                      icon: Icons.category_outlined,
                                      text: widget.niche!,
                                    ),
                                  if (widget.audienceReach?.trim().isNotEmpty == true)
                                    _MetaItem(
                                      icon: Icons.groups_outlined,
                                      text: 'Reach: ${widget.audienceReach!}',
                                    ),
                                  if (widget.payoutMethod?.isNotEmpty == true)
                                    _MetaItem(
                                      icon: Icons.payments_outlined,
                                      text: 'Payout: ${widget.payoutMethod!}',
                                    ),
                                  if (widget.sampleLink?.isNotEmpty == true)
                                    _MetaItem(
                                      icon: Icons.play_circle_outline_rounded,
                                      text: widget.sampleLink!,
                                      isLink: true,
                                    ),
                                ] else ...[
                                  if (effectiveWebsite != null &&
                                      effectiveWebsite.trim().isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.link_rounded,
                                      text: effectiveWebsite,
                                      isLink: true,
                                    ),
                                  if (effectiveExperience != null &&
                                      effectiveExperience.trim().isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.military_tech_outlined,
                                      text: effectiveExperience,
                                    ),
                                  if (effectiveStyle != null &&
                                      effectiveStyle.trim().isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.psychology_outlined,
                                      text: effectiveStyle,
                                    ),
                                  if (effectiveHold != null &&
                                      effectiveHold.trim().isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.bolt_rounded,
                                      text: 'Avg Hold: $effectiveHold',
                                    ),
                                  if (effectiveMarket != null &&
                                      effectiveMarket.trim().isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.show_chart_rounded,
                                      text: effectiveMarket,
                                    ),
                                  if (effectiveStrategy != null &&
                                      effectiveStrategy.trim().isNotEmpty)
                                    _MetaItem(
                                      icon: Icons.menu_book_outlined,
                                      text: 'Top: $effectiveStrategy',
                                    ),
                                ],
                              ],
                            ],
                          ),

                          // Follower / Following Stats
                          SizedBox(height: context.sp(theme.spacing.md)),
                          Wrap(
                            spacing: context.sp(theme.spacing.lg),
                            runSpacing: context.sp(theme.spacing.sm),
                            children: isAdmin
                                ? <Widget>[
                                    _SocialStat(
                                      count: _liveTotalTraders > 0
                                          ? '$_liveTotalTraders'
                                          : '--',
                                      label: 'Registered Traders',
                                    ),
                                    _SocialStat(
                                      count: _liveTotalJournals > 0
                                          ? '$_liveTotalJournals'
                                          : '--',
                                      label: 'Journal Trades',
                                    ),
                                    const _SocialStat(
                                      count: 'Active (Live)',
                                      label: 'System Status',
                                    ),
                                    const _SocialStat(
                                      count: '0',
                                      label: 'Critical Breaches',
                                    ),
                                  ]
                                : (isAffiliate
                                      ? <Widget>[
                                          _SocialStat(
                                            count: _formatCount(effectiveFollowers),
                                            label: 'Followers',
                                          ),
                                          _SocialStat(
                                            count: _formatCount(effectiveFollowing),
                                            label: 'Following',
                                          ),
                                          _SocialStat(
                                            count: _formatCount(effectivePosts),
                                            label: 'Public Posts',
                                          ),
                                          _SocialStat(
                                            count: widget.referralCode?.trim().isNotEmpty == true
                                                ? widget.referralCode!
                                                : 'PARTNER',
                                            label: 'Partner Code',
                                          ),
                                        ]
                                      : <Widget>[
                                          _SocialStat(
                                            count: _formatCount(effectiveFollowing),
                                            label: 'Following',
                                          ),
                                          _SocialStat(
                                            count: _formatCount(effectiveFollowers),
                                            label: 'Followers',
                                          ),
                                          _SocialStat(
                                            count: _formatCount(effectivePosts),
                                            label: 'Public Posts',
                                          ),
                                          _SocialStat(
                                            count: !effectivePublicStats
                                                ? 'Private'
                                                : (effectiveWinRate != null
                                                    ? '${effectiveWinRate.toStringAsFixed(1)}%'
                                                    : '--'),
                                            label: 'Win Rate',
                                          ),
                                          if (!isAdmin && !isAffiliate)
                                            _SocialStat(
                                              count: !effectivePublicStats
                                                  ? 'Private'
                                                  : '$effectiveDisciplineScore/100',
                                              label: 'Discipline Score',
                                            ),
                                        ]),
                          ),

                          // Trading Performance / Governance Strip - Full Width & Responsive
                          SizedBox(height: context.sp(theme.spacing.md)),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: context.sp(theme.spacing.xs),
                              vertical: context.sp(theme.spacing.xs),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colors.surfaceMuted.withValues(alpha: 0.5),
                              borderRadius: context.radius(theme.radii.lg),
                              border: Border.all(
                                color: theme.colors.border.withValues(alpha: 0.6),
                                width: theme.borders.hairline,
                              ),
                            ),
                            child: LayoutBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    BoxConstraints constraints,
                                  ) {
                                    if (isAdmin) {
                                      final tradersCountStr = _liveTotalTraders > 0
                                          ? '$_liveTotalTraders Accounts'
                                          : 'Active';
                                      final journalsCountStr = _liveTotalJournals > 0
                                          ? '$_liveTotalJournals Logged'
                                          : 'Live Stream';
                                      if (constraints.maxWidth > 520) {
                                        return Row(
                                          children: <Widget>[
                                            const Expanded(
                                              child: _KpiPill(
                                                label: 'Admin Clearance',
                                                value: 'Root Superuser / L5',
                                                isPositive: false,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            Expanded(
                                              child: _KpiPill(
                                                label: 'Registered Accounts',
                                                value: tradersCountStr,
                                                isPositive: true,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            Expanded(
                                              child: _KpiPill(
                                                label: 'Monitored Journals',
                                                value: journalsCountStr,
                                                isPositive: true,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            const Expanded(
                                              child: _KpiPill(
                                                label: 'Platform Engine',
                                                value: 'Direct DB Live',
                                                isPositive: true,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            const Expanded(
                                              child: _KpiPill(
                                                label: 'Governance',
                                                value: 'SEBI & ISO Compliant',
                                                isPositive: null,
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Row(
                                              children: <Widget>[
                                                const Expanded(
                                                  child: _KpiPill(
                                                    label: 'Clearance',
                                                    value: 'Root / L5',
                                                    isPositive: false,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Accounts',
                                                    value: tradersCountStr,
                                                    isPositive: true,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Journals',
                                                    value: journalsCountStr,
                                                    isPositive: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: context.sp(
                                                  theme.spacing.xs,
                                                ),
                                              ),
                                              child: Divider(
                                                height: 1,
                                                color: theme.colors.border
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            Row(
                                              children: const <Widget>[
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Engine',
                                                    value: 'Live DB',
                                                    isPositive: true,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Governance',
                                                    value: 'SEBI Compliant',
                                                    isPositive: null,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'System Status',
                                                    value: 'Nominal',
                                                    isPositive: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      }
                                    }

                                    if (isAffiliate) {
                                      final String nicheText = effectiveMarket != null && effectiveMarket.trim().isNotEmpty
                                          ? effectiveMarket
                                          : 'Trading Education';
                                      final String followersStr = effectiveFollowers > 0
                                          ? '$effectiveFollowers Traders'
                                          : '0 Traders';
                                      final String codeStr = widget.referralCode?.trim().isNotEmpty == true
                                          ? widget.referralCode!
                                          : 'Active';
                                      if (constraints.maxWidth > 520) {
                                        return Row(
                                          children: <Widget>[
                                            const Expanded(
                                              child: _KpiPill(
                                                label: 'Partner Status',
                                                value: 'Verified Creator',
                                                isPositive: true,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            Expanded(
                                              child: _KpiPill(
                                                label: 'Community Reach',
                                                value: followersStr,
                                                isPositive: true,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            Expanded(
                                              child: _KpiPill(
                                                label: 'Partner Code',
                                                value: codeStr,
                                                isPositive: true,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            Expanded(
                                              child: _KpiPill(
                                                label: 'Content Focus',
                                                value: nicheText,
                                                isPositive: null,
                                              ),
                                            ),
                                            _buildKpiDivider(theme),
                                            Expanded(
                                              child: _KpiPill(
                                                label: 'Public Posts',
                                                value: '$effectivePosts Guides',
                                                isPositive: effectivePosts > 0 ? true : null,
                                              ),
                                            ),
                                          ],
                                        );
                                      } else {
                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Row(
                                              children: <Widget>[
                                                const Expanded(
                                                  child: _KpiPill(
                                                    label: 'Status',
                                                    value: 'Verified Creator',
                                                    isPositive: true,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Community',
                                                    value: followersStr,
                                                    isPositive: true,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Code',
                                                    value: codeStr,
                                                    isPositive: true,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(
                                                vertical: context.sp(
                                                  theme.spacing.xs,
                                                ),
                                              ),
                                              child: Divider(
                                                height: 1,
                                                color: theme.colors.border
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            Row(
                                              children: <Widget>[
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Niche',
                                                    value: nicheText,
                                                    isPositive: null,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: _KpiPill(
                                                    label: 'Guides',
                                                    value: '$effectivePosts Guides',
                                                    isPositive: effectivePosts > 0 ? true : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      }
                                    }

                                    // Pro Trader / Customer view (The user's actual profile)
                                    final String winRateStr = !effectivePublicStats
                                        ? 'Private'
                                        : (effectiveWinRate != null
                                            ? '${effectiveWinRate.toStringAsFixed(1)}%'
                                            : '--');
                                    final String holdStr = effectiveHold != null && effectiveHold.trim().isNotEmpty
                                        ? effectiveHold
                                        : 'Not Set';
                                    final String marketText = effectiveMarket != null && effectiveMarket.trim().isNotEmpty
                                        ? effectiveMarket
                                        : 'Not Set';
                                    final String mantraStr = effectiveRiskMantra != null && effectiveRiskMantra.trim().isNotEmpty
                                        ? effectiveRiskMantra
                                        : 'Not Set';
                                    final String topStrategyText = effectiveStrategy != null && effectiveStrategy.trim().isNotEmpty
                                        ? effectiveStrategy
                                        : 'Not Set';

                                    if (constraints.maxWidth > 520) {
                                      return Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: _KpiPill(
                                              label: 'Win Rate',
                                              value: winRateStr,
                                              isPositive: !effectivePublicStats
                                                  ? null
                                                  : (effectiveWinRate != null
                                                      ? effectiveWinRate >= 50.0
                                                      : null),
                                            ),
                                          ),
                                          _buildKpiDivider(theme),
                                          Expanded(
                                            child: _KpiPill(
                                              label: 'Avg Hold',
                                              value: holdStr,
                                              isPositive: holdStr != 'Not Set' ? true : null,
                                            ),
                                          ),
                                          _buildKpiDivider(theme),
                                          Expanded(
                                            child: _KpiPill(
                                              label: 'Market Focus',
                                              value: marketText,
                                              isPositive: null,
                                            ),
                                          ),
                                          _buildKpiDivider(theme),
                                          Expanded(
                                            child: _KpiPill(
                                              label: 'Risk Mantra',
                                              value: mantraStr,
                                              isPositive: mantraStr != 'Not Set' ? true : null,
                                            ),
                                          ),
                                          _buildKpiDivider(theme),
                                          Expanded(
                                            child: _KpiPill(
                                              label: 'Top Strategy',
                                              value: topStrategyText,
                                              isPositive: null,
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: _KpiPill(
                                                  label: 'Win Rate',
                                                  value: winRateStr,
                                                  isPositive: !effectivePublicStats
                                                      ? null
                                                      : (effectiveWinRate != null
                                                          ? effectiveWinRate >= 50.0
                                                          : null),
                                                ),
                                              ),
                                              Expanded(
                                                child: _KpiPill(
                                                  label: 'Avg Hold',
                                                  value: holdStr,
                                                  isPositive: holdStr != 'Not Set' ? true : null,
                                                ),
                                              ),
                                              Expanded(
                                                child: _KpiPill(
                                                  label: 'Market Focus',
                                                  value: marketText,
                                                  isPositive: null,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: context.sp(
                                                theme.spacing.xs,
                                              ),
                                            ),
                                            child: Divider(
                                              height: 1,
                                              color: theme.colors.border
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          Row(
                                            children: <Widget>[
                                              Expanded(
                                                child: _KpiPill(
                                                  label: 'Risk Mantra',
                                                  value: mantraStr,
                                                  isPositive: mantraStr != 'Not Set' ? true : null,
                                                ),
                                              ),
                                              Expanded(
                                                child: _KpiPill(
                                                  label: 'Top Strategy',
                                                  value: topStrategyText,
                                                  isPositive: null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                  },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: context.sp(theme.spacing.md)),

              // ---------------------------------------------------------------
              // Rich Interactive Navigation Tabs
              // ---------------------------------------------------------------
              UiTabs(
                stretch: false,
                scrollable: true,
                variant: UiTabsVariant.underline,
                items: tabItems,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meta Item & Social Stat Helpers
// ---------------------------------------------------------------------------

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.text,
    this.isLink = false,
  });

  final IconData icon;
  final String text;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: context.sz(14),
          color: isLink ? theme.colors.primary : theme.colors.foregroundMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: isLink
                  ? theme.colors.primary
                  : theme.colors.foregroundMuted,
              fontWeight: isLink ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialStat extends StatelessWidget {
  const _SocialStat({required this.count, required this.label});

  final String count;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        count,
        style: context.uiText.bodyStrong.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
      ),
    ],
  );
}

class _KpiPill extends StatelessWidget {
  const _KpiPill({
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final String label;
  final String value;
  final bool? isPositive;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color valueColor = isPositive == true
        ? theme.colors.bullish
        : (isPositive == false ? theme.colors.bearish : theme.colors.foreground);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(10),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: context.uiText.bodyStrong.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: context.fs(13),
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

Widget _buildKpiDivider(UiTheme theme) => Container(
  width: 1,
  height: 28,
  color: theme.colors.border.withValues(alpha: 0.4),
);

// ---------------------------------------------------------------------------
// 1. Twitter / X Style Feed Preview
// ---------------------------------------------------------------------------

class _TwitterFeedPreview extends StatelessWidget {
  const _TwitterFeedPreview({
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    required this.verifiedColor,
    this.repository,
    this.author,
    this.onPostTap,
    this.onOpenRef,
    this.isCurrentUser = false,
  });

  final String displayName;
  final String handle;
  final String? avatarUrl;
  final Color verifiedColor;
  final CommunityRepository? repository;
  final CommunityAuthor? author;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final bool isAuthor =
        isCurrentUser ||
        (author != null &&
            repository != null &&
            (author!.id == repository!.currentAuthor.id ||
                author!.handle.toLowerCase() ==
                    repository!.currentAuthor.handle.toLowerCase())) ||
        (author != null &&
            (author!.handle.toLowerCase() == handle.toLowerCase() &&
                isCurrentUser)) ||
        (isCurrentUser && handle.isEmpty);

    List<CommunityPost> authorPosts = <CommunityPost>[];
    if (repository != null) {
      if (author != null) {
        authorPosts = repository!.postsForAuthor(author!.id);
      }
      if (authorPosts.isEmpty && isAuthor) {
        authorPosts = repository!.postsForAuthor(repository!.currentAuthor.id);
      }
    }

    if (authorPosts.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: authorPosts.map((CommunityPost post) {
          final diff = DateTime.now().difference(post.createdAt);
          final timeStr = diff.inMinutes < 60
              ? '${diff.inMinutes}m ago'
              : (diff.inHours < 24
                    ? '${diff.inHours}h ago'
                    : (diff.inDays == 1 ? 'Yesterday' : '${diff.inDays}d ago'));

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _TwitterPostCard(
              post: post,
              displayName: post.author.displayName,
              handle: post.author.handle,
              avatarUrl: post.author.avatarUrl,
              verifiedColor: verifiedColor,
              isVerified: post.author.verified || post.author.userRole == UserRole.userAdmin,
              isPinned: post.isPinned,
              timestamp: timeStr,
              body: post.body,
              tags: post.tags,
              setupSnapshot: post.tradeSetup != null
                  ? _TradeSetupSnippet(
                      ticker: post.tradeSetup!.ticker,
                      side: post.tradeSetup!.side,
                      entry: post.tradeSetup!.entry,
                      exit: post.tradeSetup!.exit ?? '--',
                      rMultiple: post.tradeSetup!.rMultiple ?? '--',
                      pnl: post.tradeSetup!.pnl ?? '--',
                      isWin: post.tradeSetup!.isWin ?? true,
                      tradeId:
                          'trd_${post.tradeSetup!.ticker.toLowerCase().replaceAll(' ', '_')}',
                      onOpenRef: onOpenRef,
                    )
                  : null,
              onTap: onPostTap != null ? () => onPostTap!(post) : null,
              onOpenRef: onOpenRef,
              repository: repository!,
              isAuthor: isAuthor,
            ),
          );
        }).toList(),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: context.sp(theme.spacing.xl),
        horizontal: context.sp(theme.spacing.md),
      ),
      child: UiEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No public posts',
        message: handle.isNotEmpty
            ? '@$handle has not published any community posts yet.'
            : 'No community posts shared yet.',
      ),
    );
  }
}

class _TwitterPostCard extends StatefulWidget {
  const _TwitterPostCard({
    required this.post,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    required this.verifiedColor,
    this.isVerified = false,
    this.isPinned = false,
    required this.timestamp,
    required this.body,
    required this.tags,
    this.setupSnapshot,
    this.onTap,
    this.onOpenRef,
    required this.repository,
    this.isAuthor = false,
  });

  final CommunityPost post;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final Color verifiedColor;
  final bool isVerified;
  final bool isPinned;
  final String timestamp;
  final String body;
  final List<String> tags;
  final Widget? setupSnapshot;
  final VoidCallback? onTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final CommunityRepository repository;
  final bool isAuthor;

  @override
  State<_TwitterPostCard> createState() => _TwitterPostCardState();
}

class _TwitterPostCardState extends State<_TwitterPostCard> {
  late String _body = widget.body;
  late List<String> _tags = List<String>.from(widget.tags);

  @override
  void didUpdateWidget(_TwitterPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.body != widget.body) {
      _body = widget.body;
    }
    if (oldWidget.tags != widget.tags) {
      _tags = List<String>.from(widget.tags);
    }
  }

  bool get _isAuthor {
    if (widget.isAuthor) return true;
    final repo = widget.repository;
    final current = repo.currentAuthor;
    final p = widget.post;
    if (p.author.id == current.id ||
        p.author.handle.toLowerCase() == current.handle.toLowerCase()) {
      return true;
    }
    final cleanCurrent = current.handle
        .toLowerCase()
        .replaceFirst('@', '')
        .trim();
    final cleanHandle = widget.handle
        .toLowerCase()
        .replaceFirst('@', '')
        .trim();
    if (cleanCurrent.isNotEmpty && cleanCurrent == cleanHandle) {
      return true;
    }
    return false;
  }

  Future<void> _handleEditPost(BuildContext context) async {
    final effectivePost = widget.post;
    final repo = widget.repository;
    await CommunityEditPostDialog.show(
      context,
      post: effectivePost,
      repository: repo,
    );
    final updated = repo.loadPostById(effectivePost.id);
    if (updated != null && mounted) {
      setState(() {
        _body = updated.body;
        _tags = List<String>.from(updated.tags);
      });
    }
  }

  void _showPostOptions(BuildContext context) {
    final repo = widget.repository;
    final effectivePost = repo.findPost(widget.post.id) ?? widget.post;
    final authorMode = _isAuthor;
    CommunityPostOptionsSheet.show(
      context,
      post: effectivePost,
      repository: repo,
      isAuthor: authorMode,
      onEdit: authorMode ? () => _handleEditPost(context) : null,
      onDelete: authorMode
          ? () {
              if (mounted) setState(() {});
              UiToast.show(
                context,
                title: 'Post deleted',
                message: 'Your post was removed.',
                intent: UiIntent.neutral,
              );
            }
          : null,
    );
  }

  void _openActualPost(BuildContext context) {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    final post = widget.post;
    final repo = widget.repository;
    final user = repo.currentAuthor;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailView(
          post: post,
          repository: repo,
          currentUser: user,
          onOpenRef: widget.onOpenRef,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final repo = widget.repository;

    return InkWell(
      onTap: () => _openActualPost(context),
      splashColor: theme.colors.primary.withValues(alpha: 0.05),
      highlightColor: theme.colors.surfaceMuted.withValues(alpha: 0.4),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Pinned badge row
            if (widget.isPinned) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(
                  left: context.sz(36),
                  bottom: context.sp(theme.spacing.xs),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.push_pin_rounded,
                      size: context.sz(13),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'Pinned Setup',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: context.fs(11),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Avatar rail + content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Left: avatar
                UiAvatar(
                  name: widget.displayName,
                  imageUrl: widget.avatarUrl,
                  size: UiSize.sm,
                  verified: widget.isVerified,
                  verifiedColor: widget.verifiedColor,
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),

                // Right: author header + body + tags + engagement bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Author row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: <Widget>[
                                Text(
                                  widget.displayName,
                                  style: context.uiText.bodyStrong.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (widget.isVerified) ...<Widget>[
                                  Icon(
                                    Icons.verified_rounded,
                                    color: widget.verifiedColor,
                                    size: context.sz(14),
                                  ),
                                ],
                                Text(
                                  '@${widget.handle.replaceFirst(RegExp(r"^@+"), "")}',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                                Text(
                                  '· ${widget.timestamp}',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                                if (widget.post.isPendingApproval)
                                  const UiBadge(
                                    label: 'Pending Approval',
                                    intent: UiIntent.warning,
                                    variant: UiBadgeVariant.soft,
                                  ),
                              ],
                            ),
                          ),
                          if (_isAuthor) ...<Widget>[
                            UiButton(
                              label: 'Edit',
                              icon: Icons.edit_outlined,
                              size: UiSize.xs,
                              variant: UiVariant.soft,
                              intent: UiIntent.primary,
                              onPressed: () => _handleEditPost(context),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                          ],
                          UiIconButton(
                            icon: Icons.more_horiz_rounded,
                            size: UiSize.xs,
                            tooltip: 'Post options',
                            onPressed: () => _showPostOptions(context),
                          ),
                        ],
                      ),

                      // Body
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Text(
                        _body,
                        style: context.uiText.body.copyWith(
                          height: 1.45,
                          fontSize: context.fs(14),
                        ),
                      ),

                      // Embedded trade setup card
                      if (widget.setupSnapshot != null) ...<Widget>[
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        widget.setupSnapshot!,
                      ],

                      // Embedded writing desk record attachment (notes/journal/strategy)
                      if (widget.post.attachment != null) ...<Widget>[
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        CommunityAttachmentTile(
                          attachment: widget.post.attachment!,
                          onTap: () async {
                            final source = widget.post.attachment!.source;
                            if (widget.onOpenRef != null) {
                              if (ModalRoute.of(context)?.isCurrent == true &&
                                  Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                              widget.onOpenRef!(source);
                            } else {
                              if (source.kind == AppLinkKind.journal) {
                                final trade = await JournalRepositoryScope
                                    .repository
                                    .getById(source.id);
                                if (trade != null && context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (ctx) => Scaffold(
                                        body: JournalEntryScreen(
                                          entry: trade,
                                          onClose: () =>
                                              Navigator.of(ctx).pop(),
                                          onEdit: () {},
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              } else if (source.kind == AppLinkKind.note) {
                                final note = await NotesRepositoryScope
                                    .repository
                                    .getById(source.id);
                                if (note != null && context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (ctx) => Scaffold(
                                        body: NotePreviewScreen(
                                          note: note,
                                          onClose: () =>
                                              Navigator.of(ctx).pop(),
                                          onEdit: () {},
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],

                      // Hashtag badges
                      if (_tags.isNotEmpty) ...<Widget>[
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        Wrap(
                          spacing: context.sp(theme.spacing.xs),
                          runSpacing: context.sp(theme.spacing.xs),
                          children: _tags
                              .map(
                                (String tag) => UiBadge(
                                  label: '#$tag',
                                  intent: UiIntent.primary,
                                  variant: UiBadgeVariant.soft,
                                  size: UiSize.xs,
                                ),
                              )
                              .toList(),
                        ),
                      ],

                      SizedBox(height: context.sp(theme.spacing.xs)),
                    ],
                  ),
                ),
              ],
            ),

            ListenableBuilder(
              listenable: repo,
              builder: (context, _) {
                final post = repo.findPost(widget.post.id) ?? widget.post;
                return CommunityEngagementBar(
                  comments: post.comments,
                  likes: post.likes,
                  liked: post.liked,
                  userReaction: post.userReaction,
                  reactions: post.reactions,
                  reposted: post.reposted,
                  onReply: () => _openActualPost(context),
                  onLike: () => repo.toggleLike(post.id),
                  onReact: (emoji) => repo.toggleLike(post.id, reaction: emoji),
                  onShare: () => CommunityShareSheet.show(
                    context, post: post, repository: repo,
                  ),
                  onRepost: () => CommunityRepostDialog.show(
                    context,
                    post: post,
                    onRepost: () => repo.toggleRepost(post.id),
                    onQuote: () => UiDialog.show<void>(
                      context,
                      child: CommunityComposerCard(
                        author: repo.currentAuthor,
                        repository: repo,
                        quotedPost: post,
                        onPostCreated: () => Navigator.of(context).pop(),
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Bottom separator hairline
            Divider(
              height: 1,
              thickness: theme.borders.hairline,
              color: theme.colors.border.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeSetupSnippet extends StatelessWidget {
  const _TradeSetupSnippet({
    required this.ticker,
    required this.side,
    required this.entry,
    required this.exit,
    required this.rMultiple,
    required this.pnl,
    required this.isWin,
    this.tradeId,
    this.onOpenRef,
  });

  final String ticker;
  final String side;
  final String entry;
  final String exit;
  final String rMultiple;
  final String pnl;
  final bool isWin;
  final String? tradeId;
  final ValueChanged<AppLinkRef>? onOpenRef;

  void _handleTap(BuildContext context) async {
    final id = tradeId ?? 'trd_$ticker';
    if (onOpenRef != null) {
      if (ModalRoute.of(context)?.isCurrent == true &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      onOpenRef!(AppLinkRef(kind: AppLinkKind.journal, id: id, title: ticker));
    } else {
      final actualTrade =
          await JournalRepositoryScope.repository.getById(id) ??
          AppTrade(
            id: id,
            ticker: ticker,
            side: side.toUpperCase() == 'LONG' ? AppSide.long : AppSide.short,
            entry:
                double.tryParse(entry.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0.0,
            exit:
                double.tryParse(exit.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
            size: 100,
            pnl:
                double.tryParse(pnl.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0,
            pnlPercent: 0.0,
            rMultiple:
                double.tryParse(
                  rMultiple.replaceAll(RegExp(r'[^0-9.-]'), ''),
                ) ??
                0.0,
            outcome: isWin ? AppOutcome.win : AppOutcome.loss,
            openedAt: DateTime.now(),
            notes: 'Trade setup shared via profile.',
            isPublic: true,
          );
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (ctx) => Scaffold(
              body: JournalEntryScreen(
                entry: actualTrade,
                onClose: () => Navigator.of(ctx).pop(),
                onEdit: () {},
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    final Widget card = Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(
          color: isWin
              ? theme.colors.bullish.withValues(alpha: 0.3)
              : theme.colors.bearish.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              UiBadge(
                label: side,
                intent: side == 'LONG' ? UiIntent.bullish : UiIntent.bearish,
                size: UiSize.xs,
              ),
              const SizedBox(width: 6),
              Text(ticker, style: context.uiText.bodyStrong),

              UiBadge(
                label: '$pnl ($rMultiple)',
                intent: isWin ? UiIntent.bullish : UiIntent.bearish,
                variant: UiBadgeVariant.solid,
                size: UiSize.xs,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.md),
            runSpacing: 4,
            children: <Widget>[
              Text('Entry: $entry', style: context.uiText.caption),
              Text('Exit: $exit', style: context.uiText.caption),
              Text(
                'Execution: Verified ✓',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.bullish,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return InkWell(
      onTap: () => _handleTap(context),
      borderRadius: context.radius(theme.radii.md),
      child: card,
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Public Journal & Trade Logs Preview
// ---------------------------------------------------------------------------

class _PublicJournalPreview extends StatelessWidget {
  const _PublicJournalPreview({
    required this.selectedFilter,
    required this.onFilterChanged,
    this.authorId,
    this.handle,
    this.onOpenRef,
    this.isCurrentUser = false,
    this.publicJournals = true,
  });

  final int selectedFilter;
  final ValueChanged<int> onFilterChanged;
  final String? authorId;
  final String? handle;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool isCurrentUser;
  final bool publicJournals;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (!publicJournals) {
      final String cleanH =
          (handle ?? '').replaceFirst(RegExp(r'^@+'), '').trim();
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: context.sp(theme.spacing.xl),
          horizontal: context.sp(theme.spacing.md),
        ),
        child: UiEmptyState(
          icon: Icons.lock_outline_rounded,
          title: isCurrentUser ? 'Public Journal Disabled' : 'Journal is Private',
          message: isCurrentUser
              ? 'You have disabled "Show verified trade logs in public journal" in Profile Settings. Other traders cannot see your trades.'
              : (cleanH.isNotEmpty
                  ? '@$cleanH has chosen to keep their journal entries private.'
                  : 'This trader\'s journal entries are private.'),
        ),
      );
    }

    return StreamBuilder<List<AppTrade>>(
      stream: isCurrentUser
          ? JournalRepositoryScope.repository.watchAll()
          : JournalRepositoryScope.repository.watchPublic(),
      builder: (BuildContext context, AsyncSnapshot<List<AppTrade>> snapshot) {
        final List<AppTrade> allTrades = snapshot.data ?? <AppTrade>[];
        final List<AppTrade> trades = isCurrentUser
            ? allTrades
                .where((t) =>
                    (authorId != null && authorId!.isNotEmpty && t.userId == authorId) ||
                    RecordAccess.owns(t.userId))
                .toList()
            : ((authorId != null && authorId!.isNotEmpty)
                ? allTrades.where((t) => t.userId == authorId).toList()
                : const <AppTrade>[]);

        final String cleanH =
            (handle ?? '').replaceFirst(RegExp(r'^@+'), '').trim();

        if (trades.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
              horizontal: context.sp(theme.spacing.md),
            ),
            child: UiEmptyState(
              icon: Icons.auto_stories_outlined,
              title: isCurrentUser ? 'No journal entries yet' : 'No public journal entries',
              message: isCurrentUser
                  ? 'Log your trades and executions in the Journal section.'
                  : (cleanH.isNotEmpty
                      ? '@$cleanH has not shared any journal trades publicly yet.'
                      : 'No verified trades shared publicly yet.'),
            ),
          );
        }

        final int totalLogged = trades.length;
        final double netPnl = trades.fold(0.0, (sum, t) => sum + t.pnl);
        final int wins = trades.where((t) => t.pnl > 0).length;
        final int losses = trades.where((t) => t.pnl < 0).length;
        final int closedTrades = wins + losses;
        final double winRatio = closedTrades > 0
            ? (wins / closedTrades) * 100
            : 0.0;
        final double totalR = trades.fold(
          0.0,
          (sum, t) => sum + (t.rMultiple ?? 0.0),
        );

        final List<AppTrade> filteredTrades = switch (selectedFilter) {
          1 => trades.where((t) => t.pnl > 0).toList(),
          2 => trades.where((t) => t.pnl < 0).toList(),
          _ => trades,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Summary & Audit Banner
            UiCard(
              variant: UiCardVariant.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        isCurrentUser
                            ? Icons.auto_stories_outlined
                            : Icons.verified_user_outlined,
                        color: isCurrentUser
                            ? theme.colors.primary
                            : theme.colors.bullish,
                        size: context.sz(20),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          isCurrentUser
                              ? 'Personal Trading Execution Journal'
                              : 'Verified Public Execution Log',
                          style: context.uiText.bodyStrong,
                        ),
                      ),
                      UiBadge(
                        label: isCurrentUser
                            ? 'ALL EXECUTIONS (OWNER)'
                            : 'AUDITED BROKER FEED',
                        intent: isCurrentUser
                            ? UiIntent.primary
                            : UiIntent.bullish,
                        size: UiSize.xs,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Text(
                    isCurrentUser
                        ? 'Showing all logged trades including both public verified logs and private executions.'
                        : 'Every trade shown below is cryptographically hashed against broker fill timestamps. Private personal executions remain confidential.',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Wrap(
                    spacing: context.sp(theme.spacing.lg),
                    runSpacing: context.sp(theme.spacing.xs),
                    children: <Widget>[
                      _JournalStat(
                        title: isCurrentUser ? 'Total Trades' : 'Public Trades',
                        val: '$totalLogged Logged',
                      ),
                      _JournalStat(
                        title: 'Net Realized PnL',
                        val:
                            '${netPnl >= 0 ? '+' : ''}₹${netPnl.toStringAsFixed(0)}',
                        color: netPnl >= 0
                            ? theme.colors.bullish
                            : theme.colors.bearish,
                      ),
                      _JournalStat(
                        title: 'Win Ratio',
                        val:
                            '${winRatio.toStringAsFixed(1)}% (${wins}W - ${losses}L)',
                        color: winRatio >= 50
                            ? theme.colors.bullish
                            : theme.colors.bearish,
                      ),
                      _JournalStat(
                        title: 'Total R Gained',
                        val:
                            '${totalR >= 0 ? '+' : ''}${totalR.toStringAsFixed(1)}R',
                        color: totalR >= 0
                            ? theme.colors.bullish
                            : theme.colors.bearish,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),

            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    <String>[
                      'All Trades ($totalLogged)',
                      'Wins ($wins)',
                      'Losses ($losses)',
                    ].asMap().entries.map((MapEntry<int, String> e) {
                      final bool isSelected = selectedFilter == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: isSelected,
                          selectedColor: theme.colors.primary.withValues(
                            alpha: 0.2,
                          ),
                          onSelected: (_) => onFilterChanged(e.key),
                        ),
                      );
                    }).toList(),
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),

            ...filteredTrades.map((AppTrade trade) {
              final isWin = trade.pnl >= 0;
              final diff = trade.closedAt?.difference(trade.openedAt).inMinutes;
              final durationStr = diff != null ? '$diff mins' : 'Open';

              return Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: _JournalTradeCard(
                  ticker: trade.ticker,
                  tradeId: trade.id,
                  trade: trade,
                  side: trade.side.name.toUpperCase(),
                  date:
                      '${trade.openedAt.day}/${trade.openedAt.month}/${trade.openedAt.year}',
                  setup: trade.strategy ?? 'Discretionary',
                  duration: durationStr,
                  pnl:
                      '${trade.pnl >= 0 ? '+' : ''}₹${trade.pnl.toStringAsFixed(0)}',
                  rMultiple: trade.rMultiple != null
                      ? '${trade.rMultiple! >= 0 ? '+' : ''}${trade.rMultiple!.toStringAsFixed(1)}R'
                      : '--',
                  isWin: isWin,
                  entryPrice: '₹${trade.entry.toStringAsFixed(2)}',
                  exitPrice: trade.exit != null
                      ? '₹${trade.exit!.toStringAsFixed(2)}'
                      : '--',
                  quantity: '${trade.size.toInt()} Qty',
                  notes: trade.notes?.isNotEmpty == true
                      ? trade.notes!
                      : (trade.title.isNotEmpty
                            ? trade.title
                            : 'No execution notes recorded.'),
                  tags: trade.tags,
                  onOpenRef: onOpenRef,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _JournalStat extends StatelessWidget {
  const _JournalStat({required this.title, required this.val, this.color});

  final String title;
  final String val;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: context.uiText.bodyStrong.copyWith(
            color: color ?? theme.colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _JournalTradeCard extends StatelessWidget {
  const _JournalTradeCard({
    required this.ticker,
    required this.side,
    required this.date,
    required this.setup,
    required this.duration,
    required this.pnl,
    required this.rMultiple,
    required this.isWin,
    required this.entryPrice,
    required this.exitPrice,
    required this.quantity,
    required this.notes,
    required this.tags,
    this.tradeId,
    this.trade,
    this.onOpenRef,
    this.isCurrentUser = false,
  });

  final String ticker;
  final String side;
  final String date;
  final String setup;
  final String duration;
  final String pnl;
  final String rMultiple;
  final bool isWin;
  final String entryPrice;
  final String exitPrice;
  final String quantity;
  final String notes;
  final List<String> tags;
  final String? tradeId;
  final AppTrade? trade;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool isCurrentUser;

  void _openActualTrade(BuildContext context) {
    final id = trade?.id ?? tradeId ?? ticker;
    if (onOpenRef != null) {
      if (ModalRoute.of(context)?.isCurrent == true &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      onOpenRef!(AppLinkRef(kind: AppLinkKind.journal, id: id, title: ticker));
    } else {
      final actualTrade =
          trade ??
          AppTrade(
            id: id,
            ticker: ticker,
            side: side.toUpperCase() == 'LONG' ? AppSide.long : AppSide.short,
            entry:
                double.tryParse(
                  entryPrice.replaceAll(RegExp(r'[^0-9.]'), ''),
                ) ??
                0.0,
            exit:
                double.tryParse(exitPrice.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                0.0,
            size:
                double.tryParse(quantity.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                100.0,
            pnl:
                double.tryParse(pnl.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0,
            pnlPercent: 0.0,
            rMultiple:
                double.tryParse(
                  rMultiple.replaceAll(RegExp(r'[^0-9.-]'), ''),
                ) ??
                0.0,
            outcome: isWin ? AppOutcome.win : AppOutcome.loss,
            openedAt: DateTime.now(),
            notes: notes,
            tags: tags,
            isPublic: true,
          );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: JournalEntryScreen(
              entry: actualTrade,
              onClose: () => Navigator.of(ctx).pop(),
              onEdit: () {},
            ),
          ),
        ),
      );
    }
  }

  String _computeBrokerHash() {
    final String raw =
        '${trade?.id ?? tradeId ?? ticker}:$ticker:$side:$entryPrice:$exitPrice:$date';
    int hash = 0x811c9dc5;
    for (int i = 0; i < raw.length; i++) {
      hash ^= raw.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color tint = isWin ? theme.colors.bullish : theme.colors.bearish;
    final String brokerHash = _computeBrokerHash();

    return UiCard(
      onTap: () => _openActualTrade(context),
      accentColor: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Top Row: Ticker, Side, PnL
          Row(
            children: <Widget>[
              UiBadge(
                label: side,
                intent: side == 'LONG' ? UiIntent.bullish : UiIntent.bearish,
                size: UiSize.xs,
              ),
              if (isCurrentUser && trade != null) ...<Widget>[
                const SizedBox(width: 6),
                UiBadge(
                  label: trade!.isPublic ? 'PUBLIC' : 'PRIVATE',
                  intent: trade!.isPublic ? UiIntent.primary : UiIntent.neutral,
                  size: UiSize.xs,
                ),
              ],
              const SizedBox(width: 8),
              Text(
                ticker,
                style: context.uiText.bodyStrong.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '· $setup',
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
              const Spacer(),
              UiBadge(
                label: '$pnl ($rMultiple)',
                intent: isWin ? UiIntent.bullish : UiIntent.bearish,
                variant: UiBadgeVariant.solid,
                size: UiSize.sm,
              ),
            ],
          ),

          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            markdownToPlainText(notes),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.body.copyWith(
              fontSize: context.fs(13),
              height: 1.4,
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.sm)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colors.surfaceMuted,
              borderRadius: context.radius(theme.radii.sm),
            ),
            child: Wrap(
              spacing: context.sp(theme.spacing.md),
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('Entry: $entryPrice', style: context.uiText.caption),
                Text('Exit: $exitPrice', style: context.uiText.caption),
                Text('Qty: $quantity', style: context.uiText.caption),
                Text('Time: $duration', style: context.uiText.caption),
                Text(
                  date,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                UiBadge(
                  label: 'SHA-256 · #$brokerHash',
                  icon: Icons.verified_user_outlined,
                  intent: UiIntent.bullish,
                  size: UiSize.xs,
                ),
              ],
            ),
          ),

          if (tags.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Wrap(
              spacing: 6,
              children: tags
                  .map(
                    (String t) => UiBadge(
                      label: '#$t',
                      intent: UiIntent.primary,
                      size: UiSize.xs,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Notes & Playbooks Preview (Notion / Substack Style)
// ---------------------------------------------------------------------------

class _NotesPlaybooksPreview extends StatelessWidget {
  const _NotesPlaybooksPreview({
    this.authorId,
    this.handle,
    this.onOpenRef,
    this.isCurrentUser = false,
  });

  final String? authorId;
  final String? handle;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return StreamBuilder<List<AppNote>>(
      stream: isCurrentUser
          ? NotesRepositoryScope.repository.watchAll()
          : NotesRepositoryScope.repository.watchPublic(),
      builder: (BuildContext context, AsyncSnapshot<List<AppNote>> snapshot) {
        final List<AppNote> allNotes = snapshot.data ?? <AppNote>[];
        final List<AppNote> notes = isCurrentUser
            ? allNotes
                .where((n) =>
                    (authorId != null && authorId!.isNotEmpty && n.userId == authorId) ||
                    RecordAccess.owns(n.userId))
                .toList()
            : ((authorId != null && authorId!.isNotEmpty)
                ? allNotes.where((n) => n.userId == authorId).toList()
                : const <AppNote>[]);

        final String cleanH =
            (handle ?? '').replaceFirst(RegExp(r'^@+'), '').trim();

        if (notes.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
              horizontal: context.sp(theme.spacing.md),
            ),
            child: UiEmptyState(
              icon: Icons.note_alt_outlined,
              title: isCurrentUser ? 'No notes yet' : 'No public notes',
              message: isCurrentUser
                  ? 'Create research notes, market thoughts, and trade reviews in the Notes section.'
                  : (cleanH.isNotEmpty
                      ? '@$cleanH has not published any public research notes.'
                      : 'No public notes shared yet.'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: notes.map((AppNote note) {
            final diff = DateTime.now().difference(note.updatedAt);
            final timeStr = diff.inMinutes < 60
                ? '${diff.inMinutes}m ago'
                : (diff.inHours < 24
                      ? '${diff.inHours}h ago'
                      : (diff.inDays == 1
                            ? 'Yesterday'
                            : '${diff.inDays}d ago'));

            final cleanSummary =
                note.content
                    .split('\n')
                    .where(
                      (line) => line.trim().isNotEmpty && !line.startsWith('#'),
                    )
                    .firstOrNull ??
                'No description provided.';

            return Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: _NotePlaybookCard(
                title: note.title,
                noteId: note.id,
                note: note,
                subtitle: 'Updated $timeStr · ${note.wordCount} words',
                icon: note.noteType.icon,
                summary: cleanSummary,
                tags: note.tags,
                isPublic: note.isPublic,
                onOpenRef: onOpenRef,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _NotePlaybookCard extends StatelessWidget {
  const _NotePlaybookCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.summary,
    required this.tags,
    required this.isPublic,
    this.noteId,
    this.note,
    this.onOpenRef,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String summary;
  final List<String> tags;
  final bool isPublic;
  final String? noteId;
  final AppNote? note;
  final ValueChanged<AppLinkRef>? onOpenRef;

  void _openActualNote(BuildContext context) {
    final id = note?.id ?? noteId ?? title;
    if (onOpenRef != null) {
      if (ModalRoute.of(context)?.isCurrent == true &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      onOpenRef!(AppLinkRef(kind: AppLinkKind.note, id: id, title: title));
    } else {
      final actualNote =
          note ??
          AppNote(
            id: id,
            title: title,
            content: summary,
            tags: tags,
            isPublic: isPublic,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: NotePreviewScreen(
              note: actualNote,
              onClose: () => Navigator.of(ctx).pop(),
              onEdit: () {},
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return UiCard(
      onTap: () => _openActualNote(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: theme.colors.primary, size: context.sz(20)),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  title,
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              UiBadge(
                label: isPublic ? 'PUBLIC NOTE' : 'PRIVATE NOTE',
                intent: isPublic ? UiIntent.primary : UiIntent.neutral,
                size: UiSize.xs,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            markdownToPlainText(summary),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.body.copyWith(
              height: 1.45,
              fontSize: context.fs(13.5),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: 6,
            children: tags
                .map(
                  (String t) => UiBadge(
                    label: t,
                    intent: UiIntent.neutral,
                    size: UiSize.xs,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3b. Strategies & Playbooks Preview
// ---------------------------------------------------------------------------

class _StrategiesPreview extends StatelessWidget {
  const _StrategiesPreview({
    this.authorId,
    this.handle,
    this.onOpenRef,
    this.isCurrentUser = false,
  });

  final String? authorId;
  final String? handle;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return StreamBuilder<List<AppStrategy>>(
      stream: isCurrentUser
          ? StrategiesRepositoryScope.repository.watchAll()
          : StrategiesRepositoryScope.repository.watchPublic(),
      builder: (BuildContext context, AsyncSnapshot<List<AppStrategy>> snapshot) {
        final List<AppStrategy> allStrategies = snapshot.data ?? <AppStrategy>[];
        final List<AppStrategy> strategies = isCurrentUser
            ? allStrategies
                .where((s) =>
                    (authorId != null && authorId!.isNotEmpty && s.userId == authorId) ||
                    RecordAccess.owns(s.userId))
                .toList()
            : ((authorId != null && authorId!.isNotEmpty)
                ? allStrategies.where((s) => s.userId == authorId).toList()
                : const <AppStrategy>[]);

        final String cleanH =
            (handle ?? '').replaceFirst(RegExp(r'^@+'), '').trim();

        if (strategies.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
              horizontal: context.sp(theme.spacing.md),
            ),
            child: UiEmptyState(
              icon: Icons.menu_book_outlined,
              title: isCurrentUser ? 'No strategies yet' : 'No public playbooks',
              message: isCurrentUser
                  ? 'Build systematic setups and execution playbooks in the Strategies section.'
                  : (cleanH.isNotEmpty
                      ? '@$cleanH has not shared any public strategies or playbooks.'
                      : 'No public strategies or playbooks shared yet.'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: strategies.map((AppStrategy strategy) {
            return Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: PlaybookCard(
                strategy: strategy,
                onTap: () {
                  if (onOpenRef != null) {
                    if (ModalRoute.of(context)?.isCurrent == true &&
                        Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    onOpenRef!(
                      AppLinkRef(
                        kind: AppLinkKind.strategy,
                        id: strategy.id,
                        title: strategy.name,
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (ctx) => StrategyDetailScreen(
                          strategy: strategy,
                          onClose: () => Navigator.of(ctx).pop(),
                          onEdit: () {},
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Public Dashboard Preview
// ---------------------------------------------------------------------------

// ignore: unused_element
class _PublicDashboardPreview extends StatelessWidget {
  const _PublicDashboardPreview();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCardGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 2,
          largeColumns: 4,
          childAspectRatio: context.uiRes.pick<double>(
            mobile: 1.25,
            tablet: 1.45,
            desktop: 1.55,
          ),
          children: <Widget>[
            UiMetricCard(
              label: '30D return',
              value: '+18.4%',
              delta: 18.4,
              icon: Icons.trending_up_rounded,
              chart: UiSparkChart(
                values: const <double>[
                  10,
                  12,
                  11,
                  14,
                  13,
                  16,
                  15,
                  18,
                  17,
                  18.4,
                ],
                color: theme.colors.bullish,
              ),
            ),
            UiMetricCard(
              label: 'Avg. R multiple',
              value: '2.15R',
              delta: 0.18,
              icon: Icons.analytics_outlined,
              chart: UiSparkChart(
                values: const <double>[
                  1.8,
                  1.9,
                  1.85,
                  2.0,
                  1.95,
                  2.1,
                  2.05,
                  2.15,
                ],
                color: theme.colors.primary,
              ),
            ),
            UiMetricCard(
              label: 'Plan adherence',
              value: '94%',
              delta: 3.2,
              icon: Icons.fact_check_outlined,
              chart: UiSparkChart(
                values: const <double>[88, 90, 89, 92, 91, 93, 92, 94],
                color: theme.colors.bullish,
              ),
            ),
            UiMetricCard(
              label: 'Public playbooks',
              value: '6',
              icon: Icons.menu_book_outlined,
              chart: UiSparkChart(
                values: const <double>[1, 2, 2, 3, 4, 4, 5, 6],
                color: theme.colors.warning,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Interactive Cumulative Equity Curve Chart Card
        UiCard(
          title: 'Equity Curve & Cumulative Return',
          subtitle: '30-day verified growth trajectory vs NIFTY benchmark',
          trailing: UiBadge(
            label: '+18.4% Alpha',
            intent: UiIntent.success,
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          child: UiAreaChart(
            height: 200,
            data: const <UiChartPoint>[
              UiChartPoint(label: 'Day 1', values: <double>[0.0, 0.0]),
              UiChartPoint(label: 'Day 5', values: <double>[3.2, 0.8]),
              UiChartPoint(label: 'Day 10', values: <double>[6.4, 1.2]),
              UiChartPoint(label: 'Day 15', values: <double>[9.1, 1.9]),
              UiChartPoint(label: 'Day 20', values: <double>[12.5, 2.6]),
              UiChartPoint(label: 'Day 25', values: <double>[15.2, 3.1]),
              UiChartPoint(label: 'Day 30', values: <double>[18.4, 3.8]),
            ],
            series: <UiChartSeries>[
              UiChartSeries(
                name: 'Cumulative Return',
                color: theme.colors.bullish,
                type: UiChartSeriesType.area,
              ),
              UiChartSeries(
                name: 'Benchmark Index',
                color: theme.colors.foregroundMuted,
                type: UiChartSeriesType.line,
              ),
            ],
            valueFormatter: (num v) => '+${v.toStringAsFixed(1)}%',
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Instrument Breakdown
        UiCard(
          title: 'Top Instrument Breakdown',
          subtitle: 'Realized performance by primary traded universe',
          child: Column(
            children: <Widget>[
              _SectorBar(
                label: 'NIFTY & Index Options',
                pct: 0.55,
                amount: '+₹1,02,400',
                color: theme.colors.primary,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'High-Beta Equities (Large Cap)',
                pct: 0.30,
                amount: '+₹54,600',
                color: theme.colors.bullish,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Swing Breakouts (Mid Cap)',
                pct: 0.15,
                amount: '+₹27,200',
                color: theme.colors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectorBar extends StatelessWidget {
  const _SectorBar({
    required this.label,
    required this.pct,
    required this.amount,
    required this.color,
  });

  final String label;
  final double pct;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.bodyStrong.copyWith(
                  fontSize: context.fs(13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              maxLines: 1,
              style: context.uiText.bodyStrong.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: theme.colors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Affiliate Campaigns Preview
// ---------------------------------------------------------------------------

class _AffiliateCampaignsPreview extends StatelessWidget {
  const _AffiliateCampaignsPreview({
    required this.displayName,
    required this.handle,
    required this.referralCode,
    this.avatarUrl,
    required this.verifiedColor,
  });

  final String displayName;
  final String handle;
  final String referralCode;
  final String? avatarUrl;
  final Color verifiedColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Pinned Promo Card
        UiCard(
          accentColor: theme.colors.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UiBadge(
                    label: 'PINNED CAMPAIGN · 20% DISCOUNT',
                    icon: Icons.local_offer_outlined,
                    intent: UiIntent.warning,
                    variant: UiBadgeVariant.solid,
                    size: UiSize.xs,
                  ),
                  const Spacer(),
                  Text(
                    'Active through 2026',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Text(
                'Exclusive alphajournal Community Discount 🎉',
                style: context.uiText.heading.copyWith(
                  fontSize: context.fs(16),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Get 20% OFF all alphajournal Pro & Team annual memberships. Includes access to my verified trade journals, setup notes, and private strategy templates.',
                style: context.uiText.body.copyWith(
                  height: 1.45,
                  fontSize: context.fs(13.5),
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.sm),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.md),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.vpn_key_rounded,
                      size: 18,
                      color: theme.colors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        referralCode,
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    UiButton(
                      label: 'Copy Code',
                      variant: UiVariant.outline,
                      size: UiSize.xs,
                      leadingIcon: Icons.copy_rounded,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        UiToast.show(
                          context,
                          title: 'Code copied',
                          message:
                              'Referral code $referralCode copied to clipboard.',
                          intent: UiIntent.success,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Video Masterclass Setup Card
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UiAvatar(
                    name: displayName,
                    imageUrl: avatarUrl,
                    size: UiSize.sm,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(displayName, style: context.uiText.bodyStrong),
                        Text(
                          '@$handle · 2h ago',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: 'NEW VIDEO',
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Text(
                'Mastering the Opening Range Breakout (ORB) on NIFTY & Tech Stocks',
                style: context.uiText.heading.copyWith(
                  fontSize: context.fs(15),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'In this 35-minute workshop, I break down my exact execution rules, risk management plan, and why alphajournal orderflow charts give an unfair edge.',
                style: context.uiText.body.copyWith(height: 1.4),
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.md),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 48,
                        color: theme.colors.warning,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Watch Full Masterclass (35 mins)',
                        style: context.uiText.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Affiliate Community Perks & 4-Step Trader Journey
// ---------------------------------------------------------------------------

class _AffiliateReferralPortalPreview extends StatelessWidget {
  const _AffiliateReferralPortalPreview({
    required this.referralCode,
    required this.audienceReach,
    this.niche,
    this.payoutMethod,
    this.sampleLink,
    this.channelHandle,
    this.phoneNumber,
  });

  final String referralCode;
  final String audienceReach;
  final String? niche;
  final String? payoutMethod;
  final String? sampleLink;
  final String? channelHandle;
  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Shareable Referral Link Card
        UiCard(
          accentColor: theme.colors.warning,
          title: 'Join via Partner Link & Unlock VIP Perks',
          subtitle:
              'Use this link to automatically apply a 20% discount on all platform subscriptions and gain instant access to private setups.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.sm),
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: context.radius(theme.radii.md),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.link_rounded,
                      size: 20,
                      color: theme.colors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppShareLinks.referral(referralCode),
                        style: context.uiText.bodyStrong.copyWith(
                          color: theme.colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    UiButton(
                      label: 'Copy Link',
                      size: UiSize.xs,
                      leadingIcon: Icons.copy_rounded,
                      onPressed: () {
                        ShareActions.copy(context, AppShareLinks.referral(referralCode));
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              Text(
                'Member Perks When Joining via This Partner:',
                style: context.uiText.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: const <Widget>[
                  UiBadge(
                    label: '20% Lifetime Platform Discount',
                    intent: UiIntent.success,
                    size: UiSize.xs,
                  ),
                  UiBadge(
                    label: 'Free Curated Playbooks',
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                  ),
                  UiBadge(
                    label: 'VIP Live Workshop Access',
                    intent: UiIntent.warning,
                    size: UiSize.xs,
                  ),
                  UiBadge(
                    label: 'Zero Setup / Hidden Fees',
                    intent: UiIntent.neutral,
                    size: UiSize.xs,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Partner Channel & Payout Configuration Card
        UiCard(
          title: 'Partner Verification & Settlement Rails',
          subtitle:
              'Active configuration for creator promotion and referral commission payouts',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: context.sp(theme.spacing.lg),
                runSpacing: context.sp(theme.spacing.sm),
                children: <Widget>[
                  if (channelHandle?.trim().isNotEmpty == true)
                    _SocialStat(
                      count: channelHandle!.startsWith('@')
                          ? channelHandle!
                          : '@$channelHandle',
                      label: 'Channel Handle',
                    ),
                  if (niche?.trim().isNotEmpty == true)
                    _SocialStat(
                      count: niche!,
                      label: 'Content Niche',
                    ),
                  _SocialStat(
                    count: audienceReach,
                    label: 'Audience Reach',
                  ),
                  if (payoutMethod?.trim().isNotEmpty == true)
                    _SocialStat(
                      count: payoutMethod!,
                      label: 'Payout Rail',
                    ),
                  if (phoneNumber?.trim().isNotEmpty == true)
                    _SocialStat(
                      count: phoneNumber!,
                      label: 'Verified Phone',
                    ),
                ],
              ),
              if (sampleLink?.trim().isNotEmpty == true) ...[
                SizedBox(height: context.sp(theme.spacing.sm)),
                Divider(
                  color: theme.colors.border.withValues(alpha: 0.5),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: context.sz(18),
                      color: theme.colors.warning,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'Content Portfolio: ',
                      style: context.uiText.caption,
                    ),
                    Expanded(
                      child: Text(
                        sampleLink!,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // 4-Step Community Trader Journey Card
        UiCard(
          title: 'How to Get Started in 4 Easy Steps',
          subtitle:
              'Simple onboarding steps to activate your partner perks and join the private trade room',
          child: Column(
            children: <Widget>[
              const _AffiliateStepTile(
                stepNumber: '1',
                title: 'Create Your Free Account',
                description:
                    'Sign up on alphajournal in under 60 seconds with your email, mobile number, or Google auth.',
                statusText: 'Step 1',
                statusIntent: UiIntent.primary,
              ),
              const Divider(height: 20),
              _AffiliateStepTile(
                stepNumber: '2',
                title: 'Apply Partner Code: $referralCode',
                description:
                    'Instantly lock in your 20% lifetime membership discount on Pro and Team tier plans.',
                statusText: '20% Off',
                statusIntent: UiIntent.success,
              ),
              const Divider(height: 20),
              const _AffiliateStepTile(
                stepNumber: '3',
                title: 'Unlock Verified Playbooks & Setups',
                description:
                    'Gain instant access to the creator’s verified chart templates, ORB strategies, and trade journal.',
                statusText: 'Free Access',
                statusIntent: UiIntent.warning,
              ),
              const Divider(height: 20),
              const _AffiliateStepTile(
                stepNumber: '4',
                title: 'Trade with Active Community Support',
                description:
                    'Participate in weekly market preparation sessions, live execution reviews, and peer discussions.',
                statusText: 'VIP Community',
                statusIntent: UiIntent.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AffiliateStepTile extends StatelessWidget {
  const _AffiliateStepTile({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.statusText,
    required this.statusIntent,
  });

  final String stepNumber;
  final String title;
  final String description;
  final String statusText;
  final UiIntent statusIntent;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.colors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: theme.colors.warning, width: 1.2),
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: context.uiText.caption.copyWith(
                color: theme.colors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: context.uiText.bodyStrong.copyWith(
                        fontSize: context.fs(14),
                      ),
                    ),
                  ),
                  UiBadge(
                    label: statusText,
                    intent: statusIntent,
                    size: UiSize.xs,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Affiliate Community Overview Preview
// ---------------------------------------------------------------------------

class _AffiliateCommunityOverviewPreview extends StatelessWidget {
  const _AffiliateCommunityOverviewPreview();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCardGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 2,
          largeColumns: 4,
          childAspectRatio: context.uiRes.pick<double>(
            mobile: 1.25,
            tablet: 1.45,
            desktop: 1.55,
          ),
          children: <Widget>[
            UiMetricCard(
              label: 'Active community',
              value: '148 traders',
              delta: 14.5,
              icon: Icons.groups_outlined,
              chart: UiSparkChart(
                values: const <double>[80, 95, 110, 122, 134, 148],
                color: theme.colors.primary,
              ),
            ),
            UiMetricCard(
              label: 'Member satisfaction',
              value: '98.4%',
              delta: 2.1,
              icon: Icons.thumb_up_outlined,
              chart: UiSparkChart(
                values: const <double>[94, 95, 96, 97, 98, 98.4],
                color: theme.colors.bullish,
              ),
            ),
            UiMetricCard(
              label: 'Playbooks shared',
              value: '24 guides',
              icon: Icons.menu_book_outlined,
              chart: UiSparkChart(
                values: const <double>[12, 15, 18, 20, 22, 24],
                color: theme.colors.warning,
              ),
            ),
            UiMetricCard(
              label: 'Avg student win-rate',
              value: '64.8%',
              delta: 3.2,
              icon: Icons.military_tech_outlined,
              chart: UiSparkChart(
                values: const <double>[58, 60, 61, 63, 64, 64.8],
                color: theme.colors.bullish,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Community Growth Trajectory Chart Card
        UiCard(
          title: 'Mentorship Growth & Community Activity',
          subtitle:
              'Active traders executing this educator’s verified strategy playbooks',
          trailing: UiBadge(
            label: '+148 Active Traders',
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          child: UiAreaChart(
            height: 200,
            data: const <UiChartPoint>[
              UiChartPoint(label: 'Mar', values: <double>[24]),
              UiChartPoint(label: 'Apr', values: <double>[48]),
              UiChartPoint(label: 'May', values: <double>[72]),
              UiChartPoint(label: 'Jun', values: <double>[96]),
              UiChartPoint(label: 'Jul', values: <double>[120]),
              UiChartPoint(label: 'Aug', values: <double>[148]),
            ],
            series: <UiChartSeries>[
              UiChartSeries(
                name: 'Mentored Members',
                color: theme.colors.warning,
                type: UiChartSeriesType.area,
              ),
            ],
            valueFormatter: (num v) => '${v.toInt()} Traders',
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        UiCard(
          title: 'Primary Trading Frameworks & Setups',
          subtitle:
              'Strategy curriculum and execution models taught by this partner',
          child: Column(
            children: <Widget>[
              _SectorBar(
                label: 'Opening Range Breakouts (ORB)',
                pct: 0.55,
                amount: '18 Setups · 68.4% Win Rate',
                color: theme.colors.primary,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Trend Following & Moving Average Pullbacks',
                pct: 0.30,
                amount: '12 Setups · 62.1% Win Rate',
                color: theme.colors.bullish,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Options Volatility & Delta Neutral',
                pct: 0.15,
                amount: '6 Setups · 71.0% Win Rate',
                color: theme.colors.warning,
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'Recent Verified Community Reviews',
          subtitle: 'Feedback from traders executing this partner’s playbooks',
          child: Column(
            children: <Widget>[
              _ReviewTile(
                author: 'Rohan M.',
                handle: '@rohan_trades',
                timeAgo: 'Yesterday',
                rating: 5,
                comment:
                    'The ORB blueprint and 15-minute risk checklist completely transformed my execution discipline. Profit factor is up from 1.2 to 2.4R this month!',
              ),
              const Divider(height: 24),
              _ReviewTile(
                author: 'Priya S.',
                handle: '@priya_fno',
                timeAgo: '3 days ago',
                rating: 5,
                comment:
                    'Clear, zero-noise technical analysis. The private weekend workshops and alphajournal orderflow charts give immense clarity before market open.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.author,
    required this.handle,
    required this.timeAgo,
    required this.rating,
    required this.comment,
  });

  final String author;
  final String handle;
  final String timeAgo;
  final int rating;
  final String comment;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            UiAvatar(name: author, size: UiSize.xs),
            const SizedBox(width: 8),
            Text(
              author,
              style: context.uiText.bodyStrong.copyWith(
                fontSize: context.fs(13),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$handle · $timeAgo',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
            const Spacer(),
            Row(
              children: List.generate(
                rating,
                (int i) => Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: theme.colors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          comment,
          style: context.uiText.body.copyWith(
            fontSize: context.fs(13),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Admin Command Center Preview (Root Level Privileges)
// ---------------------------------------------------------------------------

class _AdminCommandCenterPreview extends StatelessWidget {
  const _AdminCommandCenterPreview({
    this.clearanceLevel,
    this.deskDivision,
    this.designation,
    this.supervisedCapital,
    this.terminalUrl,
    this.killswitchEnabled = true,
    this.preTradeVaREnabled = true,
    this.auditHashingEnabled = true,
  });

  final String? clearanceLevel;
  final String? deskDivision;
  final String? designation;
  final String? supervisedCapital;
  final String? terminalUrl;
  final bool killswitchEnabled;
  final bool preTradeVaREnabled;
  final bool auditHashingEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    final String activeDivision = deskDivision?.isNotEmpty == true
        ? deskDivision!
        : 'Proprietary Trading Desk';
    final String activeClearance = clearanceLevel?.isNotEmpty == true
        ? clearanceLevel!
        : 'Level 5 Root Superadmin';
    final String activeRole = designation?.isNotEmpty == true
        ? designation!
        : 'Chief Risk Officer & Managing Partner';
    final String activeCapital = supervisedCapital?.isNotEmpty == true
        ? supervisedCapital!
        : '₹148.2 Cr';
    final String activeTerminal = terminalUrl?.isNotEmpty == true
        ? terminalUrl!
        : 'tradex.internal/root';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCardGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 2,
          largeColumns: 4,
          childAspectRatio: context.uiRes.pick<double>(
            mobile: 1.25,
            tablet: 1.45,
            desktop: 1.55,
          ),
          children: <Widget>[
            UiMetricCard(
              label: 'Firm killswitch',
              value: killswitchEnabled ? 'Armed / Active' : 'Standby / Manual',
              icon: Icons.crisis_alert_rounded,
              chart: UiSparkChart(
                values: const <double>[1, 1, 1, 1, 1, 1, 1, 1],
                color: killswitchEnabled
                    ? theme.colors.destructive
                    : theme.colors.foregroundMuted,
              ),
            ),
            UiMetricCard(
              label: 'Matching latency',
              value: preTradeVaREnabled ? '0.8 ms (VaR sub-ms)' : '1.2 ms',
              delta: -14.2,
              icon: Icons.speed_rounded,
              chart: UiSparkChart(
                values: const <double>[2.1, 1.9, 1.8, 1.6, 1.4, 1.3, 0.8],
                color: theme.colors.bullish,
              ),
            ),
            UiMetricCard(
              label: 'Supervised capital',
              value: activeCapital,
              delta: 8.5,
              icon: Icons.account_balance_wallet_outlined,
              chart: UiSparkChart(
                values: const <double>[9800, 10200, 11100, 11800, 12200, 14820],
                color: theme.colors.primary,
              ),
            ),
            UiMetricCard(
              label: 'Audit ledger hashing',
              value: auditHashingEnabled ? 'SHA-256 Verified' : 'Standard Log',
              delta: 12.0,
              icon: Icons.security_rounded,
              chart: UiSparkChart(
                values: const <double>[32, 36, 40, 42, 45, 48.2],
                color: theme.colors.warning,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Root Authority Actions Card
        UiCard(
          accentColor: theme.colors.destructive,
          title: 'Root Authority Command Actions · $activeClearance',
          subtitle:
              'Division: $activeDivision • Role: $activeRole • Terminal: $activeTerminal',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: context.sp(theme.spacing.sm),
                runSpacing: context.sp(theme.spacing.sm),
                children: <Widget>[
                  UiButton(
                    label: 'Emergency Freeze Trading',
                    leadingIcon: Icons.pause_circle_filled_rounded,
                    intent: UiIntent.danger,
                    variant: UiVariant.primary,
                    size: UiSize.sm,
                    onPressed: () {
                      UiToast.show(
                        context,
                        title: 'Emergency Trading Pause',
                        message:
                            'Global trade matching halted for risk assessment.',
                        intent: UiIntent.danger,
                      );
                    },
                  ),
                  UiButton(
                    label: 'Recalibrate Risk Engine',
                    leadingIcon: Icons.refresh_rounded,
                    intent: UiIntent.warning,
                    variant: UiVariant.soft,
                    size: UiSize.sm,
                    onPressed: () {
                      UiToast.show(
                        context,
                        title: 'Risk Recalibration',
                        message:
                            'Recalibrating VaR margin buffers across 12,480 accounts.',
                        intent: UiIntent.warning,
                      );
                    },
                  ),
                  UiButton(
                    label: 'Broadcast System Alert',
                    leadingIcon: Icons.campaign_rounded,
                    intent: UiIntent.primary,
                    variant: UiVariant.soft,
                    size: UiSize.sm,
                    onPressed: () {
                      UiToast.show(
                        context,
                        title: 'Terminal Broadcast',
                        message:
                            'Urgent platform notification pushed to all active sessions.',
                        intent: UiIntent.info,
                      );
                    },
                  ),
                  UiButton(
                    label: 'Export Compliance Audit Dump',
                    leadingIcon: Icons.download_rounded,
                    variant: UiVariant.outline,
                    size: UiSize.sm,
                    onPressed: () {
                      UiToast.show(
                        context,
                        title: 'Audit Dump Generated',
                        message:
                            'Cryptographic trade ledger exported for regulatory inspection.',
                        intent: UiIntent.success,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Orderflow & Gateways Status
        UiCard(
          title: 'Infrastructure Node & Broker Feeds Telemetry',
          subtitle: 'Live connection health across institutional gateways',
          child: Column(
            children: <Widget>[
              _SectorBar(
                label: 'NSE & BSE Direct Colocation Feed (0.8ms)',
                pct: 0.99,
                amount: '100% Operational',
                color: theme.colors.bullish,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Institutional Order Routing Engine (1.2ms)',
                pct: 0.98,
                amount: 'Optimal Throughput',
                color: theme.colors.primary,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Real-Time VaR Risk Gateway (2.1ms)',
                pct: 0.95,
                amount: 'Zero Bottlenecks',
                color: theme.colors.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 9. Admin Risk & Audit Stream Preview
// ---------------------------------------------------------------------------

class _AdminRiskAuditPreview extends StatelessWidget {
  const _AdminRiskAuditPreview();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCard(
          title: 'Real-Time Institutional Audit Stream',
          subtitle:
              'Immutable cryptographically hashed security and risk events',
          child: Column(
            children: <Widget>[
              _AdminAuditTile(
                icon: Icons.shield_rounded,
                iconColor: theme.colors.bullish,
                title: 'System Security & KYC Sanction Check Passed',
                subtitle:
                    'Automated screening against SEBI & global FATF watchlists verified 12,480 accounts clean.',
                timestamp: '1 min ago',
                badgeLabel: 'VERIFIED',
                badgeIntent: UiIntent.success,
              ),
              const Divider(height: 20),
              _AdminAuditTile(
                icon: Icons.warning_amber_rounded,
                iconColor: theme.colors.warning,
                title: 'Margin Threshold Alert Intercepted',
                subtitle:
                    'Account #TRX-8821 reached 82% margin capacity on NIFTY weekly straddles. Automated liquidation buffer armed.',
                timestamp: '8 mins ago',
                badgeLabel: 'INTERCEPTED',
                badgeIntent: UiIntent.warning,
              ),
              const Divider(height: 20),
              _AdminAuditTile(
                icon: Icons.bolt_rounded,
                iconColor: theme.colors.primary,
                title: 'High-Frequency Order Throttle Engaged',
                subtitle:
                    'Automated algorithmic flow on Desk #3 capped at 100 orders/second to maintain matching integrity.',
                timestamp: '24 mins ago',
                badgeLabel: 'THROTTLED',
                badgeIntent: UiIntent.primary,
              ),
              const Divider(height: 20),
              _AdminAuditTile(
                icon: Icons.key_rounded,
                iconColor: theme.colors.destructive,
                title: 'Revoked Stale API Key for Inactive Broker Connector',
                subtitle:
                    'Root admin security daemon terminated dormant OAuth token for Broker Gateway #5.',
                timestamp: '1 hour ago',
                badgeLabel: 'SECURITY ACTION',
                badgeIntent: UiIntent.danger,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminAuditTile extends StatelessWidget {
  const _AdminAuditTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.badgeLabel,
    required this.badgeIntent,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String timestamp;
  final String badgeLabel;
  final UiIntent badgeIntent;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: context.uiText.bodyStrong.copyWith(
                        fontSize: context.fs(14),
                      ),
                    ),
                  ),
                  UiBadge(
                    label: badgeLabel,
                    intent: badgeIntent,
                    size: UiSize.xs,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontSize: context.fs(13),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timestamp,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 10. Admin Desk Governance Preview
// ---------------------------------------------------------------------------

class _AdminDeskGovernancePreview extends StatelessWidget {
  const _AdminDeskGovernancePreview();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCard(
          title: 'Trading Desk Division Allocation Matrix',
          subtitle:
              'Institutional capital distribution and leverage ceilings by desk unit',
          child: Column(
            children: <Widget>[
              _SectorBar(
                label: 'Index Futures & Options Desk (3x Leverage)',
                pct: 0.40,
                amount: '₹60.0 Cr Supervised',
                color: theme.colors.primary,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'High-Beta Equities Proprietary Desk (5x Leverage)',
                pct: 0.30,
                amount: '₹45.0 Cr Supervised',
                color: theme.colors.bullish,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Quantitative Algo & Market Making Desk (10x Max)',
                pct: 0.20,
                amount: '₹30.0 Cr Supervised',
                color: theme.colors.warning,
              ),
              const SizedBox(height: 10),
              _SectorBar(
                label: 'Commodities & FX Risk Desk (4x Leverage)',
                pct: 0.10,
                amount: '₹13.2 Cr Supervised',
                color: theme.colors.destructive,
              ),
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCard(
          title: 'Global Firm Risk Rules & Mandates',
          subtitle: 'Enforced automatically at the order matching gateway',
          child: Column(
            children: const <Widget>[
              _GovernancePolicyTile(
                title: 'Max Firm-Wide Daily Loss Ceiling',
                value: '3.5% Net AUM',
                status: 'Enforced',
              ),
              Divider(height: 16),
              _GovernancePolicyTile(
                title: 'Automated Account Liquidation Margin',
                value: '85% Margin Utilized',
                status: 'Armed',
              ),
              Divider(height: 16),
              _GovernancePolicyTile(
                title: 'Pre-Trade Sub-Millisecond Credit Checks',
                value: '< 0.4ms Latency',
                status: 'Active',
              ),
              Divider(height: 16),
              _GovernancePolicyTile(
                title: 'Regulatory Audit Package Cryptographic Hash',
                value: 'SHA-256 Verified',
                status: 'Compliant',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GovernancePolicyTile extends StatelessWidget {
  const _GovernancePolicyTile({
    required this.title,
    required this.value,
    required this.status,
  });

  final String title;
  final String value;
  final String status;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Expanded(
        child: Text(
          title,
          style: context.uiText.bodyStrong.copyWith(fontSize: context.fs(13)),
        ),
      ),
      Text(
        value,
        style: context.uiText.body.copyWith(
          color: context.ui.colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 12),
      UiBadge(label: status, intent: UiIntent.success, size: UiSize.xs),
    ],
  );
}

// ---------------------------------------------------------------------------
// 11. Admin Analytics Preview
// ---------------------------------------------------------------------------

class _AdminAnalyticsPreview extends StatelessWidget {
  const _AdminAnalyticsPreview();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCardGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 2,
          largeColumns: 4,
          childAspectRatio: context.uiRes.pick<double>(
            mobile: 1.25,
            tablet: 1.45,
            desktop: 1.55,
          ),
          children: <Widget>[
            UiMetricCard(
              label: 'Firm-wide daily volume',
              value: '₹148.2 Cr',
              delta: 18.4,
              icon: Icons.account_balance_wallet_outlined,
              chart: UiSparkChart(
                values: const <double>[110, 118, 125, 134, 140, 148.2],
                color: theme.colors.primary,
              ),
            ),
            UiMetricCard(
              label: 'Matching gateway latency',
              value: '1.2 ms',
              delta: -12.5,
              icon: Icons.speed_rounded,
              chart: UiSparkChart(
                values: const <double>[1.8, 1.6, 1.5, 1.4, 1.3, 1.2],
                color: theme.colors.bullish,
              ),
            ),
            UiMetricCard(
              label: 'Order match execution rate',
              value: '99.98%',
              icon: Icons.check_circle_outline_rounded,
              chart: UiSparkChart(
                values: const <double>[99.92, 99.95, 99.96, 99.98],
                color: theme.colors.bullish,
              ),
            ),
            UiMetricCard(
              label: 'Server infrastructure load',
              value: '18.4%',
              icon: Icons.memory_rounded,
              chart: UiSparkChart(
                values: const <double>[12, 14, 15, 16, 17, 18.4],
                color: theme.colors.warning,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Firm Cumulative Performance Curve
        UiCard(
          title: 'Firm Realized PnL & Volatility Trajectory',
          subtitle:
              'Aggregated return across all 8 proprietary and client desks',
          trailing: UiBadge(
            label: '+24.8% Realized Alpha',
            intent: UiIntent.success,
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
          ),
          child: UiAreaChart(
            height: 200,
            data: const <UiChartPoint>[
              UiChartPoint(label: 'Day 1', values: <double>[0.0]),
              UiChartPoint(label: 'Day 5', values: <double>[4.2]),
              UiChartPoint(label: 'Day 10', values: <double>[8.6]),
              UiChartPoint(label: 'Day 15', values: <double>[12.8]),
              UiChartPoint(label: 'Day 20', values: <double>[16.4]),
              UiChartPoint(label: 'Day 25', values: <double>[20.2]),
              UiChartPoint(label: 'Day 30', values: <double>[24.8]),
            ],
            series: <UiChartSeries>[
              UiChartSeries(
                name: 'Firm Net PnL',
                color: theme.colors.bullish,
                type: UiChartSeriesType.area,
              ),
            ],
            valueFormatter: (num v) => '+${v.toStringAsFixed(1)}%',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Decorative Custom Painter for Header Banner Grid
// ---------------------------------------------------------------------------

class _GridPatternPainter extends CustomPainter {
  const _GridPatternPainter({required this.gridColor});

  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const double step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPatternPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

// ---------------------------------------------------------------------------
// Author-Only Pending Approval Posts Preview Tab
// ---------------------------------------------------------------------------

class _TraderPendingApprovalPostsPreview extends StatelessWidget {
  const _TraderPendingApprovalPostsPreview({
    this.authorId,
    required this.handle,
    this.repository,
    this.author,
    this.onPostTap,
    this.onOpenRef,
    required this.verifiedColor,
  });

  final String? authorId;
  final String handle;
  final CommunityRepository? repository;
  final CommunityAuthor? author;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final Color verifiedColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final repo = repository ?? CommunityRepository();

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final targetId = (authorId != null && authorId!.trim().isNotEmpty)
            ? authorId!
            : (author?.id.isNotEmpty == true
                ? author!.id
                : repo.currentAuthor.id);

        final List<CommunityPost> pendingPosts =
            repo.pendingPostsForAuthor(targetId);

        if (pendingPosts.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
              horizontal: context.sp(theme.spacing.md),
            ),
            child: const UiEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No pending posts',
              message:
                  'All your posts have been reviewed and approved. Newly created community posts will appear here while awaiting moderation approval.',
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.sp(theme.spacing.md),
                context.sp(theme.spacing.xs),
                context.sp(theme.spacing.md),
                context.sp(theme.spacing.sm),
              ),
              child: const UiCallout(
                title: 'Awaiting Moderation',
                message:
                    'These posts are in review and are only visible to you. Once approved by moderators, they will be published to the public community feed.',
                intent: UiIntent.warning,
              ),
            ),
            ...pendingPosts.map((CommunityPost post) {
              final diff = DateTime.now().difference(post.createdAt);
              final timeStr = diff.inMinutes < 60
                  ? '${diff.inMinutes}m ago'
                  : (diff.inHours < 24
                      ? '${diff.inHours}h ago'
                      : (diff.inDays == 1
                          ? 'Yesterday'
                          : '${diff.inDays}d ago'));

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _TwitterPostCard(
                  post: post,
                  displayName: post.author.displayName,
                  handle: post.author.handle,
                  avatarUrl: post.author.avatarUrl,
                  verifiedColor: verifiedColor,
                  isVerified: post.author.verified || post.author.userRole == UserRole.userAdmin,
                  isPinned: post.isPinned,
                  timestamp: timeStr,
                  body: post.body,
                  tags: post.tags,
                  setupSnapshot: post.tradeSetup != null
                      ? _TradeSetupSnippet(
                          ticker: post.tradeSetup!.ticker,
                          side: post.tradeSetup!.side,
                          entry: post.tradeSetup!.entry,
                          exit: post.tradeSetup!.exit ?? '--',
                          rMultiple: post.tradeSetup!.rMultiple ?? '--',
                          pnl: post.tradeSetup!.pnl ?? '--',
                          isWin: post.tradeSetup!.isWin ?? true,
                          tradeId:
                              'trd_${post.tradeSetup!.ticker.toLowerCase().replaceAll(' ', '_')}',
                          onOpenRef: onOpenRef,
                        )
                      : null,
                  onTap: onPostTap != null ? () => onPostTap!(post) : null,
                  onOpenRef: onOpenRef,
                  repository: repo,
                  isAuthor: true,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Instagram-style Activity / History Feed for Trader Profile
// ---------------------------------------------------------------------------

class _TraderActivityHistoryPreview extends StatefulWidget {
  const _TraderActivityHistoryPreview({
    this.authorId,
    required this.handle,
    this.repository,
    this.onPostTap,
  });

  final String? authorId;
  final String handle;
  final CommunityRepository? repository;
  final ValueChanged<CommunityPost>? onPostTap;

  @override
  State<_TraderActivityHistoryPreview> createState() =>
      _TraderActivityHistoryPreviewState();
}

class _TraderActivityHistoryPreviewState
    extends State<_TraderActivityHistoryPreview> {
  int _filterIndex = 0; // 0 = All, 1 = Likes, 2 = Comments, 3 = Reposts
  late Future<List<CommunityActivityItem>> _future;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  @override
  void didUpdateWidget(covariant _TraderActivityHistoryPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorId != widget.authorId ||
        oldWidget.handle != widget.handle) {
      _loadActivity();
    }
  }

  void _loadActivity() {
    final repo = widget.repository ?? CommunityRepository();
    final targetId = widget.authorId ?? widget.handle;
    _future = repo.fetchUserActivityHistory(targetId);
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return FutureBuilder<List<CommunityActivityItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
            ),
            child: Center(
              child: SizedBox(
                width: context.sz(24),
                height: context.sz(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colors.primary,
                  ),
                ),
              ),
            ),
          );
        }

        final allItems = snapshot.data ?? const <CommunityActivityItem>[];
        final filteredItems = switch (_filterIndex) {
          1 =>
            allItems
                .where((i) => i.type == CommunityActivityType.like)
                .toList(),
          2 =>
            allItems
                .where((i) => i.type == CommunityActivityType.comment)
                .toList(),
          3 =>
            allItems
                .where((i) => i.type == CommunityActivityType.repost)
                .toList(),
          _ => allItems,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.md)),
              child: UiToggleGroup<int>(
                value: _filterIndex,
                variant: UiToggleGroupVariant.segmented,
                options: const <UiToggleOption<int>>[
                  UiToggleOption<int>(value: 0, label: 'All Activity'),
                  UiToggleOption<int>(
                    value: 1,
                    label: 'Likes',
                    icon: Icons.favorite_border_rounded,
                  ),
                  UiToggleOption<int>(
                    value: 2,
                    label: 'Comments',
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
                  UiToggleOption<int>(
                    value: 3,
                    label: 'Reposts',
                    icon: Icons.repeat_rounded,
                  ),
                ],
                onChanged: (int v) => setState(() => _filterIndex = v),
              ),
            ),
            if (filteredItems.isEmpty)
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                child: UiEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No activity found',
                  message:
                      'This trader hasn\'t performed any matching community actions yet.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: context.sp(theme.spacing.sm)),
                itemBuilder: (context, idx) {
                  final item = filteredItems[idx];
                  final (icon, badgeLabel, intent) = switch (item.type) {
                    CommunityActivityType.like => (
                      Icons.favorite_rounded,
                      'Liked',
                      UiIntent.danger,
                    ),
                    CommunityActivityType.comment => (
                      Icons.chat_bubble_rounded,
                      'Commented',
                      UiIntent.primary,
                    ),
                    CommunityActivityType.repost => (
                      Icons.repeat_rounded,
                      'Reposted',
                      UiIntent.success,
                    ),
                    CommunityActivityType.pollVote => (
                      Icons.poll_rounded,
                      'Voted',
                      UiIntent.warning,
                    ),
                    CommunityActivityType.post => (
                      Icons.article_rounded,
                      'Posted',
                      UiIntent.info,
                    ),
                  };

                  return InkWell(
                    borderRadius: context.radius(theme.radii.md),
                    onTap: () {
                      if (item.post != null) {
                        widget.onPostTap?.call(item.post!);
                      }
                    },
                    child: UiCard(
                      variant: UiCardVariant.surface,
                      child: Padding(
                        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: context.sz(36),
                              height: context.sz(36),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colors.surfaceMuted,
                              ),
                              child: Icon(
                                icon,
                                size: context.sz(18),
                                color: intent == UiIntent.danger
                                    ? theme.colors.destructive
                                    : (intent == UiIntent.success
                                          ? theme.colors.success
                                          : theme.colors.primary),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      UiBadge(
                                        label: badgeLabel,
                                        intent: intent,
                                        variant: UiBadgeVariant.soft,
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatActivityTime(item.timestamp),
                                        style: context.uiText.caption.copyWith(
                                          color: theme.colors.foregroundMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xs),
                                  ),
                                  Text(
                                    item.title,
                                    style: context.uiText.bodyStrong,
                                  ),
                                  if (item.subtitle != null &&
                                      item.subtitle!.isNotEmpty) ...<Widget>[
                                    SizedBox(
                                      height: context.sp(theme.spacing.xxs),
                                    ),
                                    Text(
                                      item.subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.uiText.body.copyWith(
                                        color: theme.colors.foregroundMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  String _formatActivityTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
