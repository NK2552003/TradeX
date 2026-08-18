import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for the profile preview surface.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';

class TraderProfilePreviewPage extends StatelessWidget {
  const TraderProfilePreviewPage({
    super.key,
    required this.displayName,
    required this.handle,
    required this.userRole,
    this.bio,
    this.avatarUrl,
  });

  final String displayName;
  final String handle;
  final String? bio;
  final String? avatarUrl;
  final UserRole userRole;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color verifiedColor = switch (userRole) {
      UserRole.customer => theme.colors.primary,
      UserRole.affiliate => theme.colors.warning,
      UserRole.userAdmin => theme.colors.destructive,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(760)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiCallout(
                title: 'Public profile preview',
                message:
                    'This is how verified traders see your identity, shared research, and public activity.',
                intent: UiIntent.info,
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiCard(
                elevated: true,
                accentColor: theme.colors.primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        UiAvatar(
                          name: displayName,
                          imageUrl: avatarUrl,
                          size: UiSize.xl,
                          verified: true,
                          verifiedColor: verifiedColor,
                        ),
                        SizedBox(width: context.sp(theme.spacing.md)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.uiText.heading,
                                    ),
                                  ),
                                  SizedBox(
                                    width: context.sp(theme.spacing.xxs),
                                  ),
                                  UiTooltip(
                                    message: 'Verified trader',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      color: verifiedColor,
                                      size: context.sz(18),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '@$handle',
                                style: context.uiText.caption.copyWith(
                                  color: theme.colors.foregroundMuted,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              Text(
                                bio?.trim().isNotEmpty == true
                                    ? bio!
                                    : 'Disciplined swing trader sharing execution notes, market structure, and reviewed playbooks.',
                                style: context.uiText.body,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),
                    Wrap(
                      spacing: context.sp(theme.spacing.lg),
                      runSpacing: context.sp(theme.spacing.sm),
                      children: const <Widget>[
                        _ProfileStat(value: '2.4K', label: 'Followers'),
                        _ProfileStat(value: '186', label: 'Following'),
                        _ProfileStat(value: '64%', label: 'Win rate'),
                        _ProfileStat(value: '1.82', label: 'Profit factor'),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiTabs(
                stretch: true,
                variant: UiTabsVariant.underline,
                items: <UiTabItem>[
                  UiTabItem(
                    label: 'Posts',
                    icon: Icons.dynamic_feed_outlined,
                    content: _PostsPreview(displayName: displayName),
                  ),
                  UiTabItem(
                    label: 'Journal',
                    icon: Icons.lock_outline_rounded,
                    content: AppTierGateCard(
                      requiredTier: AppTier.premium,
                      title: 'Private trade journal',
                      message:
                          'Journal entries stay locked unless the trader explicitly publishes a reviewed trade.',
                    ),
                  ),
                  const UiTabItem(
                    label: 'Notes',
                    icon: Icons.note_alt_outlined,
                    content: _NotesPreview(),
                  ),
                  const UiTabItem(
                    label: 'Dashboard',
                    icon: Icons.space_dashboard_outlined,
                    content: _DashboardPreview(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(value, style: context.uiText.bodyStrong),
      const SizedBox(width: 4),
      Text(
        label,
        style: context.uiText.caption.copyWith(
          color: context.ui.colors.foregroundMuted,
        ),
      ),
    ],
  );
}

class _PostsPreview extends StatelessWidget {
  const _PostsPreview({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      children: <Widget>[
        _ThreadPost(
          displayName: displayName,
          timestamp: '18m',
          body:
              'NIFTY reclaimed the opening range with improving breadth. Waiting for the retest instead of chasing the first expansion candle.',
          reactions: '128',
          replies: '19',
          tags: const <String>['NIFTY', 'Market structure'],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _ThreadPost(
          displayName: displayName,
          timestamp: 'Yesterday',
          body:
              'Weekly review: best trades came from following the plan. The two avoidable losses both happened after moving stops without new information.',
          reactions: '94',
          replies: '11',
          tags: const <String>['Weekly review', 'Discipline'],
        ),
      ],
    );
  }
}

class _ThreadPost extends StatelessWidget {
  const _ThreadPost({
    required this.displayName,
    required this.timestamp,
    required this.body,
    required this.reactions,
    required this.replies,
    required this.tags,
  });

  final String displayName;
  final String timestamp;
  final String body;
  final String reactions;
  final String replies;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              UiAvatar(name: displayName, size: UiSize.sm),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.bodyStrong,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.verified_rounded,
                      color: theme.colors.primary,
                      size: context.sz(15),
                    ),
                  ],
                ),
              ),
              Text(
                timestamp,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(body, style: context.uiText.body.copyWith(height: 1.45)),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: tags
                .map(
                  (String tag) => UiBadge(
                    label: tag,
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                )
                .toList(),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              Icon(
                Icons.favorite_border_rounded,
                size: context.sz(16),
                color: theme.colors.foregroundMuted,
              ),
              const SizedBox(width: 5),
              Text(reactions, style: context.uiText.caption),
              SizedBox(width: context.sp(theme.spacing.lg)),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: context.sz(16),
                color: theme.colors.foregroundMuted,
              ),
              const SizedBox(width: 5),
              Text(replies, style: context.uiText.caption),
              const Spacer(),
              Icon(
                Icons.bookmark_border_rounded,
                size: context.sz(17),
                color: theme.colors.foregroundMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesPreview extends StatelessWidget {
  const _NotesPreview();

  @override
  Widget build(BuildContext context) => Column(
    children: const <Widget>[
      UiCard(
        title: 'Opening range playbook',
        subtitle: 'Updated 2 days ago · 8 linked trades',
        child: Text(
          'Conditions, invalidation rules, and review questions for high-volume opening range setups.',
        ),
      ),
      SizedBox(height: 12),
      UiCard(
        title: 'Risk reset checklist',
        subtitle: 'Updated last week · Public note',
        child: Text(
          'A five-minute reset used after two consecutive losses or a process violation.',
        ),
      ),
    ],
  );
}

class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();

  @override
  Widget build(BuildContext context) => const UiCardGrid(
    children: <Widget>[
      UiMetricCard(
        label: '30D return',
        value: '+7.8%',
        delta: 7.8,
        icon: Icons.trending_up_rounded,
      ),
      UiMetricCard(
        label: 'Avg. R multiple',
        value: '1.42R',
        icon: Icons.analytics_outlined,
      ),
      UiMetricCard(
        label: 'Plan adherence',
        value: '91%',
        delta: 3.2,
        icon: Icons.fact_check_outlined,
      ),
      UiMetricCard(
        label: 'Public playbooks',
        value: '6',
        icon: Icons.menu_book_outlined,
      ),
    ],
  );
}
