import 'package:flutter/material.dart';
import 'package:tradex/features/market_data/presentation/market_movers_panel.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_article_sheet.dart';
import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_advisor_disclosure_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_guidelines_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_live_room_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_trader_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

// ---------------------------------------------------------------------------
// Main Sidebar Orchestrator
// ---------------------------------------------------------------------------

/// Desktop sticky right sidebar matching Twitter/X's layout for traders.
class CommunitySidebar extends StatefulWidget {
  const CommunitySidebar({
    super.key,
    required this.repository,
    this.onFollow,
    this.onAuthorTap,
    this.onShowMore,
    this.onExplore,
    this.onNewsShowMore,
    this.onPostTap,
    this.onSearchTap,
    this.onSearchSubmitted,
    this.showWhoToFollow = true,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityAuthor>? onFollow;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onShowMore;
  final VoidCallback? onExplore;
  final VoidCallback? onNewsShowMore;
  final ValueChanged<CommunityPost>? onPostTap;
  final VoidCallback? onSearchTap;
  final ValueChanged<String>? onSearchSubmitted;

  /// When false, the "Who to Follow" section is hidden.
  /// Set to false on tablet to keep the narrow sidebar lighter.
  final bool showWhoToFollow;

  @override
  State<CommunitySidebar> createState() => _CommunitySidebarState();
}

class _CommunitySidebarState extends State<CommunitySidebar> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final gap = context.ui.spacing.sm;
    Widget deferred(WidgetBuilder builder, double height) => Padding(
      padding: EdgeInsets.only(bottom: context.sp(gap)),
      child: UiDeferred(builder: builder, estimatedHeight: height),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onSearchTap != null) ...[
          CommunitySearchWidget(
            value: '',
            onChanged: (_) {},
            onTap: widget.onSearchTap,
            onSubmitted: widget.onSearchSubmitted,
          ),
          UiGap.v(gap),
        ],
        if (widget.repository.liveRooms.isNotEmpty)
          CommunityLiveRoomWidget(
            room: widget.repository.liveRooms.first,
            repository: widget.repository,
          ),
        UiGap.v(gap),
        deferred((_) => const CommunityPremiumCard(), 200),
        deferred((_) => const MarketMoversPanel(), 650),
        deferred(
          (_) => CommunityNewsWidget(
            items: widget.repository.news,
            snapshot: widget.repository.marketSnapshot,
            onShowMore: widget.onNewsShowMore,
          ),
          300,
        ),
        deferred(
          (_) => CommunityTrendingWidget(
            items: widget.repository.trending,
            onShowMore: widget.onExplore,
          ),
          300,
        ),
        if (widget.showWhoToFollow)
          deferred(
            (_) => CommunityWhoToFollowCard(
              traders: widget.repository.suggestedTraders
                  .where(
                    (author) => author.id != widget.repository.currentAuthor.id,
                  )
                  .toList(),
              onFollow: (author) => widget.onFollow?.call(author),
              onAuthorTap: widget.onAuthorTap,
              onShowMore: widget.onShowMore,
            ),
            300,
          ),
        if (widget.repository.pushNotificationsPromptVisible)
          deferred(
            (_) => CommunityPushNotificationsCard(
              onDismiss: widget.repository.dismissPushNotificationsPrompt,
            ),
            200,
          ),
        deferred((_) => const CommunityDisclaimerCard(), 200),
        deferred((_) => const CommunityFooterLinks(), 80),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Search Widget
// ---------------------------------------------------------------------------

class CommunitySearchWidget extends StatelessWidget {
  const CommunitySearchWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTap,
    this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: IgnorePointer(
          child: UiSearchField(
            value: value,
            hintText: 'Search signals, traders, \$tickers...',
            onChanged: onChanged,
          ),
        ),
      );
    }
    return UiSearchField(
      value: value,
      hintText: 'Search signals, traders, \$tickers...',
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

// ---------------------------------------------------------------------------
// 1b. Live Trading Floor / Audio Space Card
// ---------------------------------------------------------------------------

class CommunityLiveRoomWidget extends StatelessWidget {
  const CommunityLiveRoomWidget({
    super.key,
    this.title = '',
    this.host = '',
    this.listeners = 0,
    this.room,
    this.repository,
  });

  final String title;
  final String host;
  final int listeners;
  final LiveAudioRoom? room;
  final CommunityRepository? repository;

  @override
  Widget build(BuildContext context) {
    final displayTitle = room?.title ?? title;
    final displayHost = room?.host.displayName ?? host;
    final displayListeners = room?.listenerCount ?? listeners;

    if (displayTitle.isEmpty) {
      return const SizedBox.shrink();
    }

    final UiTheme theme = context.ui;

    return UiCard(
      accentColor: theme.colors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: context.sz(8),
                height: context.sz(8),
                decoration: BoxDecoration(
                  color: theme.colors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Flexible(
                child: UiBadge(
                  label: 'AUDIO PREVIEW',
                  intent: UiIntent.danger,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.headphones_rounded,
                    size: context.sz(12),
                    color: theme.colors.foregroundMuted,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    AppTokens.count(displayListeners),
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: context.fs(11),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: context.fs(13),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Hosted by $displayHost',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              fontSize: context.fs(11),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'Tune in Live',
            icon: Icons.mic_rounded,
            variant: UiVariant.outline,
            size: UiSize.xs,
            expandOnMobile: true,
            onPressed: () {
              CommunityLiveRoomSheet.show(
                context,
                roomId: room?.id,
                roomTitle: displayTitle,
                hostName: displayHost,
                listenerCount: displayListeners,
                pinnedSetup: room?.pinnedSetup,
                repository: repository,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Premium Card
// ---------------------------------------------------------------------------

class CommunityPremiumCard extends StatelessWidget {
  const CommunityPremiumCard({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Subscribe to Premium',
            style: context.uiText.heading.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'Get real-time level 2 signals, priority copilot tokens, verified checkmark, and zero ads.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              height: 1.4,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'Subscribe',
            variant: UiVariant.primary,
            size: UiSize.sm,
            expand: true,
            onPressed: () {
              UiToast.show(
                context,
                title: 'alphajournal Pro',
                message: 'Opening subscription tier upgrades...',
                intent: UiIntent.primary,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. News Widget (Matches Screenshot 4 "Today's News")
// ---------------------------------------------------------------------------

class CommunityNewsWidget extends StatelessWidget {
  const CommunityNewsWidget({
    super.key,
    required this.items,
    this.onShowMore,
    this.snapshot,
    this.onDismiss,
  });

  final List<CommunityNewsItem> items;
  final MarketSnapshot? snapshot;
  final VoidCallback? onShowMore;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CommunitySectionHeader(
            title: "Today's Market Wire",
            trailing: onDismiss == null
                ? null
                : UiIconButton(
                    icon: Icons.close_rounded,
                    size: UiSize.xs,
                    tooltip: 'Dismiss',
                    onPressed: onDismiss,
                  ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          for (int i = 0; i < items.length && i < 3; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: UiDivider(),
              ),
            UiCard(
              variant: UiCardVariant.ghost,
              borderless: true,
              padding: EdgeInsets.zero,
              onTap: () => CommunityArticleSheet.show(
                context,
                article: items[i],
                snapshot: snapshot,
              ),
              child: _newsRow(context, items[i]),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'Show more',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expand: true,
            onPressed: onShowMore,
          ),
        ],
      ),
    );
  }

  Widget _newsRow(BuildContext context, CommunityNewsItem item) {
    final UiTheme theme = context.ui;
    final UiIntent sentimentIntent = item.sentimentScore > 0.3
        ? UiIntent.success
        : (item.sentimentScore < -0.2 ? UiIntent.danger : UiIntent.info);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.uiText.bodyStrong.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: context.fs(13),
          ),
        ),
        if (item.summary != null && item.summary!.trim().isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            item.summary!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              fontSize: context.fs(12),
              height: 1.35,
            ),
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.xs)),
        Row(
          children: <Widget>[
            Flexible(
              child: UiBadge(
                label: item.category,
                intent: sentimentIntent,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
                maxWidth: context.sz(110),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Expanded(
              child: Text(
                '${item.source} · ${AppTokens.relativeTime(item.publishedAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundSubtle,
                  fontSize: context.fs(11),
                ),
              ),
            ),
            if (item.postCount != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Text(
                item.postCount!,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontSize: context.fs(11),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Trending Widget (Matches Screenshot 4 "What's happening")
// ---------------------------------------------------------------------------

class CommunityTrendingWidget extends StatelessWidget {
  const CommunityTrendingWidget({
    super.key,
    required this.items,
    this.onShowMore,
  });

  final List<CommunityTrendItem> items;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CommunitySectionHeader(title: "What's happening"),
          SizedBox(height: context.sp(theme.spacing.sm)),
          for (int i = 0; i < items.length && i < 4; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: UiDivider(),
              ),
            _trendRow(context, items[i]),
          ],
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'Show more',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expand: true,
            onPressed: onShowMore,
          ),
        ],
      ),
    );
  }

  Widget _trendRow(BuildContext context, CommunityTrendItem item) {
    final UiTheme theme = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.category,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontSize: context.fs(11),
                ),
              ),
              Text(
                item.topic,
                style: context.uiText.bodyStrong.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.postCount != null)
                Text(
                  item.postCount!,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                    fontSize: context.fs(11),
                  ),
                ),
            ],
          ),
        ),
        UiIconButton(
          icon: Icons.more_horiz_rounded,
          size: UiSize.xs,
          tooltip: 'Options',
          onPressed: () => UiToast.show(
            context,
            title: item.topic,
            message: 'Topic controls are available from the community feed.',
            intent: UiIntent.neutral,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Who to Follow Widget (Matches Screenshot 2 & 3)
// ---------------------------------------------------------------------------

class CommunityWhoToFollowCard extends StatelessWidget {
  const CommunityWhoToFollowCard({
    super.key,
    required this.traders,
    required this.onFollow,
    this.onAuthorTap,
    this.onShowMore,
  });

  final List<CommunityAuthor> traders;
  final ValueChanged<CommunityAuthor> onFollow;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const CommunitySectionHeader(title: 'Who to follow'),
          SizedBox(height: context.sp(theme.spacing.sm)),
          for (int i = 0; i < traders.length && i < 3; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: UiDivider(),
              ),
            CommunityTraderRow(
              trader: traders[i],
              onTap: () => onAuthorTap?.call(traders[i]),
              onFollow: () => onFollow(traders[i]),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiButton(
            label: 'Show more',
            variant: UiVariant.ghost,
            size: UiSize.sm,
            expand: true,
            onPressed: onShowMore,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Push Notifications Card (Matches Screenshot 2)
// ---------------------------------------------------------------------------

class CommunityPushNotificationsCard extends StatelessWidget {
  const CommunityPushNotificationsCard({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CommunitySectionHeader(
            title: 'Push notifications',
            trailing: UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Dismiss',
              onPressed: onDismiss,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            "Never miss market breakouts, price alerts, or setups by enabling push notifications.",
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              height: 1.4,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiButton(
            label: 'Turn on notifications',
            variant: UiVariant.outline,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () {
              UiToast.show(
                context,
                title: 'Notifications Enabled',
                message: 'You will receive breakout alerts and replies.',
                intent: UiIntent.success,
              );
              onDismiss();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6b. Regulatory Disclaimer Card
// ---------------------------------------------------------------------------

class CommunityDisclaimerCard extends StatelessWidget {
  const CommunityDisclaimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.gavel_rounded,
                size: context.sz(16),
                color: theme.colors.foregroundMuted,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  'Regulatory Disclaimer',
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(12),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'alphajournal Community posts, charts, trade setups, and comments are strictly for educational purposes and do not constitute financial advice or investment recommendations under SEBI/SEC regulations.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(11),
              height: 1.4,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              UiButton(
                label: 'Advisors',
                variant: UiVariant.ghost,
                size: UiSize.xs,
                expandOnMobile: false,
                onPressed: () {
                  CommunityAdvisorDisclosureSheet.show(context);
                },
              ),
              UiButton(
                label: 'Guidelines',
                variant: UiVariant.ghost,
                size: UiSize.xs,
                expandOnMobile: false,
                onPressed: () {
                  CommunityGuidelinesDialog.show(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Footer Links (Matches Screenshot 3)
// ---------------------------------------------------------------------------

class CommunityFooterLinks extends StatelessWidget {
  const CommunityFooterLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    final List<String> links = <String>[
      'Terms',
      'Privacy',
      'Cookies',
      'Accessibility',
      'Ads Info',
      'More…',
      '© 2026 alphajournal Corp.',
    ];

    return Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: context.sp(theme.spacing.xxs),
      children: links.map((String text) {
        return Text(
          text,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: context.fs(11),
          ),
        );
      }).toList(),
    );
  }
}
