import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';

/// Modal dialog displaying in-depth voter analytics and demographic breakdown
/// for a community poll.
class CommunityPollAnalyticsDialog extends StatelessWidget {
  const CommunityPollAnalyticsDialog({
    super.key,
    required this.poll,
    this.onAuthorTap,
  });

  final CommunityPoll poll;
  final ValueChanged<String>? onAuthorTap;

  static Future<void> show(
    BuildContext context, {
    required CommunityPoll poll,
    ValueChanged<String>? onAuthorTap,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          CommunityPollAnalyticsDialog(poll: poll, onAuthorTap: onAuthorTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int total = poll.totalVotes;

    return UiDialog(
      title: 'Poll Insights & Demographics',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Question summary card
            UiCard(
              variant: UiCardVariant.surface,
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    poll.question,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Row(
                    children: <Widget>[
                      UiBadge(
                        label: '${uiCompactNumber(total)} total votes',
                        intent: UiIntent.primary,
                        variant: UiBadgeVariant.soft,
                        size: UiSize.xs,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      if (poll.allowMultiple)
                        UiBadge(
                          label: 'Multiple Choice',
                          intent: UiIntent.neutral,
                          variant: UiBadgeVariant.outline,
                          size: UiSize.xs,
                        ),
                      const Spacer(),
                      Text(
                        poll.isExpired ? 'Status: Closed' : 'Status: Live',
                        style: context.uiText.caption.copyWith(
                          color: poll.isExpired
                              ? theme.colors.warning
                              : theme.colors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),

            // Section 1: Vote distribution by option
            Text(
              'Vote Distribution',
              style: context.uiText.bodyStrong.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            for (int i = 0; i < poll.options.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: context.sp(theme.spacing.xs)),
              _buildOptionRow(context, theme, i, total),
            ],
            SizedBox(height: context.sp(theme.spacing.md)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.md)),

            // Section 2: Voter Trading Styles
            Text(
              'Voter Breakdown by Trading Style',
              style: context.uiText.bodyStrong.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            _buildDemographicsSection(context, theme, poll.voterTradingStyles),
            SizedBox(height: context.sp(theme.spacing.md)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.md)),

            // Section 3: Voter Win-Rate Demographics
            Text(
              'Voter Breakdown by Verified Win-Rate',
              style: context.uiText.bodyStrong.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            _buildDemographicsSection(context, theme, poll.voterWinRateTiers),
            SizedBox(height: context.sp(theme.spacing.md)),

            // Author Profile Card Link
            if (poll.authorDisplayName != null ||
                poll.authorId != null) ...<Widget>[
              const UiDivider(),
              SizedBox(height: context.sp(theme.spacing.sm)),
              Row(
                children: <Widget>[
                  UiAvatar(
                    name: poll.authorDisplayName ?? 'Trader',
                    imageUrl: poll.authorAvatarUrl,
                    size: UiSize.sm,
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Created by ${poll.authorDisplayName ?? 'Trader'}',
                          style: context.uiText.bodyStrong.copyWith(
                            fontSize: context.fs(13),
                          ),
                        ),
                        Text(
                          'View verified strategy portfolio & signals',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onAuthorTap != null && poll.authorId != null)
                    UiButton(
                      label: 'View Profile',
                      size: UiSize.xs,
                      variant: UiVariant.outline,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onAuthorTap!(poll.authorId!);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Done',
          variant: UiVariant.primary,
          size: UiSize.sm,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildOptionRow(
    BuildContext context,
    UiTheme theme,
    int index,
    int total,
  ) {
    final opt = poll.options[index];
    final double pct = poll.percentageFor(index);
    final bool hasVoted = poll.hasVotedFor(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (hasVoted) ...<Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: context.sz(14),
                color: theme.colors.primary,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                opt.text,
                style: context.uiText.body.copyWith(
                  fontWeight: hasVoted ? FontWeight.w700 : FontWeight.w500,
                  fontSize: context.fs(13),
                  color: theme.colors.foreground,
                ),
              ),
            ),
            Text(
              '${opt.votes} votes (${pct.toStringAsFixed(1)}%)',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: hasVoted
                    ? theme.colors.primary
                    : theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        UiProgressBar(
          value: pct / 100.0,
          intent: hasVoted ? UiIntent.primary : UiIntent.neutral,
          thickness: 6,
        ),
      ],
    );
  }

  Widget _buildDemographicsSection(
    BuildContext context,
    UiTheme theme,
    Map<String, int> data,
  ) {
    final int sum = data.values.fold(0, (a, b) => a + b);
    if (sum == 0) {
      return Text(
        'No voter demographic data yet.',
        style: context.uiText.caption.copyWith(
          color: theme.colors.foregroundSubtle,
        ),
      );
    }

    return Column(
      children: data.entries.map((e) {
        final double ratio = e.value / sum;
        final double pct = ratio * 100.0;
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(theme.spacing.xxs),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: context.sz(140),
                child: Text(
                  e.key,
                  style: context.uiText.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colors.foreground,
                  ),
                ),
              ),
              Expanded(
                child: UiProgressBar(
                  value: ratio,
                  intent: UiIntent.primary,
                  thickness: 5,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              SizedBox(
                width: context.sz(64),
                child: Text(
                  '${pct.toStringAsFixed(0)}% (${e.value})',
                  textAlign: TextAlign.end,
                  style: context.uiText.caption.copyWith(
                    fontSize: context.fs(11),
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
