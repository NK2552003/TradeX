import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
    this.onShowMore,
    this.onPostTap,
    this.onSearchTap,
    this.onSearchSubmitted,
    this.showWhoToFollow = true,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityAuthor>? onFollow;
  final VoidCallback? onShowMore;
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
    final UiTheme theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 1. Live Trading Floor / Audio Space Card
        const CommunityLiveRoomWidget(),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // 2. Subscribe to Premium Card
        const CommunityPremiumCard(),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // 3. Today's Market News Card
        CommunityNewsWidget(
          items: widget.repository.news,
          onShowMore: widget.onShowMore,
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // 4. What's Happening / Trending in Markets
        CommunityTrendingWidget(
          items: widget.repository.trending,
          onShowMore: widget.onShowMore,
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // 5. Who to Follow Card (hidden on tablet to save space)
        if (widget.showWhoToFollow) ...<Widget>[
          CommunityWhoToFollowCard(
            traders: widget.repository.suggestedTraders,
            onFollow: (author) => widget.onFollow?.call(author),
            onShowMore: widget.onShowMore,
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],

        // 6. Push Notifications Card (dismissible)
        if (widget.repository.pushNotificationsPromptVisible) ...<Widget>[
          CommunityPushNotificationsCard(
            onDismiss: widget.repository.dismissPushNotificationsPrompt,
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],

        // 6b. Regulatory & Compliance Disclaimer Card
        const CommunityDisclaimerCard(),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // 7. Footer Links
        const CommunityFooterLinks(),
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
    this.title = 'Nifty & BankNifty Live Expiry Floor',
    this.host = 'Rajesh Sharma, CMT',
    this.listeners = 142,
  });

  final String title;
  final String host;
  final int listeners;

  @override
  Widget build(BuildContext context) {
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
              UiBadge(
                label: 'LIVE AUDIO SPACE',
                intent: UiIntent.danger,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
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
                    '$listeners listening',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                      fontSize: context.fs(10),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.bodyStrong.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: context.fs(13),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Hosted by $host',
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
                roomTitle: title,
                hostName: host,
                listenerCount: listeners,
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
                title: 'TradeX Pro',
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
    this.onDismiss,
  });

  final List<CommunityNewsItem> items;
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
            _newsRow(context, items[i]),
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
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Row(
          children: <Widget>[
            UiBadge(
              label: item.category,
              intent: sentimentIntent,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
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
            if (item.postCount != null)
              Text(
                item.postCount!,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                  fontSize: context.fs(11),
                ),
              ),
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
          onPressed: () {},
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
    this.onShowMore,
  });

  final List<CommunityAuthor> traders;
  final ValueChanged<CommunityAuthor> onFollow;
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
              Text(
                'Regulatory Disclaimer',
                style: context.uiText.bodyStrong.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.fs(12),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            'TradeX Community posts, charts, trade setups, and comments are strictly for educational purposes and do not constitute financial advice or investment recommendations under SEBI/SEC regulations.',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(11),
              height: 1.4,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
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
              SizedBox(width: context.sp(theme.spacing.xs)),
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
      '© 2026 TradeX Corp.',
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
