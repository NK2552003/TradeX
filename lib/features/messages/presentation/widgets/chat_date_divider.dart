import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';

/// A centred "Today / Yesterday / 12 Mar" chip that separates message runs by
/// day inside a thread. The label is derived from [date] against [now] — no
/// literal date strings live in the thread view.
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.date, this.now});

  final DateTime date;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sz(3),
          ),
          decoration: BoxDecoration(
            color: theme.colors.surfaceMuted,
            borderRadius: BorderRadius.circular(context.sz(999)),
          ),
          child: Text(
            _label(date, now ?? DateTime.now()),
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
              fontWeight: FontWeight.w700,
              fontSize: context.fs(10.5),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _label(DateTime date, DateTime now) {
    final DateTime d = DateTime(date.year, date.month, date.day);
    final DateTime today = DateTime(now.year, now.month, now.day);
    final int diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const List<String> days = <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[d.weekday - 1];
    }
    final String month = _months[d.month - 1];
    return d.year == today.year
        ? '${d.day} $month'
        : '${d.day} $month ${d.year}';
  }
}
