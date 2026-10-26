import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Detailed analytics sheet displaying performance and engagement metrics for a post.
class CommunityPostInsightsSheet extends StatelessWidget {
  CommunityPostInsightsSheet({
    super.key,
    required this.post,
    CommunityRepository? repository,
  }) : repository = repository ?? CommunityRepository();

  final CommunityPost post;
  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    CommunityRepository? repository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: Container(
          decoration: BoxDecoration(
            color: ctx.uiColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ctx.sp(ctx.ui.radii.lg)),
            ),
            border: Border.all(
              color: ctx.uiColors.border,
              width: ctx.ui.borders.hairline,
            ),
          ),
          padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
          child: SafeArea(
            child: CommunityPostInsightsSheet(
              post: post,
              repository: repository,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final insights = repository.getPostInsights(post.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Drag handle
        Center(
          child: Container(
            width: context.sz(36),
            height: context.sz(4),
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Row(
          children: <Widget>[
            Icon(
              Icons.insights_rounded,
              color: theme.colors.primary,
              size: context.sz(20),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Text(
              'Post Analytics & Insights',
              style: context.uiText.heading.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          'Detailed impression and engagement telemetry for your trading post.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Big Numbers Grid
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Hero Row: Impressions & Engagements
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _metricTile(
                        context,
                        title: 'Total Impressions',
                        value: uiCompactNumber(insights.impressions),
                        subtitle: 'Views in trader feeds',
                        icon: Icons.visibility_outlined,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: _metricTile(
                        context,
                        title: 'Total Engagements',
                        value: uiCompactNumber(insights.engagements),
                        subtitle:
                            '${insights.engagementRate.toStringAsFixed(1)}% engagement rate',
                        icon: Icons.touch_app_outlined,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),

                // Secondary metrics
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _metricTile(
                        context,
                        title: 'Detail Expands',
                        value: uiCompactNumber(insights.detailExpands),
                        subtitle: 'Taps to view full thread',
                        icon: Icons.unfold_more_rounded,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: _metricTile(
                        context,
                        title: 'Profile Visits',
                        value: uiCompactNumber(insights.profileVisits),
                        subtitle: 'Visits from this post',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),

                Row(
                  children: <Widget>[
                    Expanded(
                      child: _metricTile(
                        context,
                        title: 'Link & Setup Clicks',
                        value: uiCompactNumber(insights.linkClicks),
                        subtitle: 'Attachment views',
                        icon: Icons.link_rounded,
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: _metricTile(
                        context,
                        title: 'Shares',
                        value: uiCompactNumber(insights.shares),
                        subtitle: 'Via DM & external apps',
                        icon: Icons.ios_share_rounded,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.md)),

                // Reactions Bar
                UiCard(
                  variant: UiCardVariant.surface,
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Reactions Breakdown',
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          _reactionCount(
                            context,
                            icon: Icons.favorite_rounded,
                            label: 'Likes',
                            count: post.likes,
                            color: theme.colors.danger,
                          ),
                          _reactionCount(
                            context,
                            icon: Icons.repeat_rounded,
                            label: 'Reposts',
                            count: post.reposts,
                            color: theme.colors.success,
                          ),
                          _reactionCount(
                            context,
                            icon: Icons.chat_bubble_rounded,
                            label: 'Replies',
                            count: post.comments,
                            color: theme.colors.primary,
                          ),
                          _reactionCount(
                            context,
                            icon: Icons.bookmark_rounded,
                            label: 'Saves',
                            count: post.bookmarked ? 1 : 0,
                            color: theme.colors.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final UiTheme theme = context.ui;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: context.sz(16),
                color: theme.colors.foregroundMuted,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontSize: context.fs(11),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            value,
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: context.fs(20),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reactionCount(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    final UiTheme theme = context.ui;
    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: context.sz(18)),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          '$count',
          style: context.uiText.bodyStrong.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: context.fs(10),
          ),
        ),
      ],
    );
  }
}
