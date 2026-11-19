import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_poll_analytics_dialog.dart';

/// Reusable polling tile for community posts.
///
/// Displays options as selectable buttons prior to voting, and renders animated
/// percentage progress bars with checkmark badges after a vote has been placed.
/// Supports both single-choice and multiple-choice polls, plus interactive
/// demographics & analytics breakdown modals.
class CommunityPollTile extends StatelessWidget {
  const CommunityPollTile({
    super.key,
    required this.poll,
    this.onVote,
    this.onAuthorTap,
  });

  final CommunityPoll poll;
  final ValueChanged<int>? onVote;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool showResults = poll.hasVoted || poll.isExpired;

    return CommunityTile(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Question header & Multi-choice badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  poll.question,
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colors.foreground,
                  ),
                ),
              ),
              if (poll.allowMultiple) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xs)),
                const UiBadge(
                  label: 'Select all that apply',
                  intent: UiIntent.neutral,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
              ],
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Options
          for (int i = 0; i < poll.options.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: context.sp(theme.spacing.xs)),
            if (showResults)
              _buildResultRow(context, theme, i)
            else
              _buildVoteButton(context, theme, i),
          ],

          // Footer meta: total votes + expiry + Analytics button
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '${uiCompactNumber(poll.totalVotes)} votes',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundSubtle,
                  fontSize: context.fs(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '·',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundSubtle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                poll.isExpired
                    ? 'Final results'
                    : (poll.expiresAt != null
                          ? '${_timeRemaining(poll.expiresAt!)} left'
                          : 'Open'),
                style: context.uiText.caption.copyWith(
                  color: poll.isExpired
                      ? theme.colors.warning
                      : theme.colors.foregroundSubtle,
                  fontSize: context.fs(11),
                ),
              ),

              UiButton(
                label: 'Analytics',
                leadingIcon: Icons.insights_rounded,
                variant: UiVariant.ghost,
                size: UiSize.xs,
                onPressed: () => CommunityPollAnalyticsDialog.show(
                  context,
                  poll: poll,
                  onAuthorTap: onAuthorTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteButton(BuildContext context, UiTheme theme, int index) {
    final option = poll.options[index];
    final bool isSelected = poll.hasVotedFor(index);

    return UiButton(
      label: option.text,
      variant: isSelected ? UiVariant.soft : UiVariant.outline,
      intent: isSelected ? UiIntent.primary : UiIntent.neutral,
      leadingIcon: poll.allowMultiple
          ? (isSelected
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded)
          : null,
      size: UiSize.sm,
      expand: true,
      onPressed: onVote == null ? null : () => onVote!(index),
    );
  }

  Widget _buildResultRow(BuildContext context, UiTheme theme, int index) {
    final option = poll.options[index];
    final double pct = poll.percentageFor(index);
    final bool isMyVote = poll.hasVotedFor(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (isMyVote) ...<Widget>[
              Icon(
                Icons.check_circle_rounded,
                size: context.sz(14),
                color: theme.colors.primary,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                option.text,
                style: context.uiText.body.copyWith(
                  fontWeight: isMyVote ? FontWeight.w700 : FontWeight.w500,
                  fontSize: context.fs(13),
                  color: theme.colors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: isMyVote
                    ? theme.colors.primary
                    : theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        UiProgressBar(
          value: pct / 100.0,
          intent: isMyVote ? UiIntent.primary : UiIntent.neutral,
          thickness: 6,
        ),
      ],
    );
  }

  String _timeRemaining(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'ending soon';
  }
}
