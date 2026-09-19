import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Reusable polling tile for community posts.
///
/// Displays options as selectable buttons prior to voting, and renders animated
/// percentage progress bars with checkmark badges after a vote has been placed.
class CommunityPollTile extends StatelessWidget {
  const CommunityPollTile({
    super.key,
    required this.poll,
    this.onVote,
  });

  final CommunityPoll poll;
  final ValueChanged<int>? onVote;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool showResults = poll.hasVoted || poll.isExpired;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Question header
          Text(
            poll.question,
            style: context.uiText.bodyStrong.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colors.foreground,
            ),
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

          // Footer meta: total votes + expiry
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoteButton(BuildContext context, UiTheme theme, int index) {
    final option = poll.options[index];
    return UiButton(
      label: option.text,
      variant: UiVariant.outline,
      size: UiSize.sm,
      expand: true,
      onPressed: onVote == null ? null : () => onVote!(index),
    );
  }

  Widget _buildResultRow(BuildContext context, UiTheme theme, int index) {
    final option = poll.options[index];
    final double pct = poll.percentageFor(index);
    final bool isMyVote = poll.votedOptionIndex == index;

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
                color: isMyVote ? theme.colors.primary : theme.colors.foregroundMuted,
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
