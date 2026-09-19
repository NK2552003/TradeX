import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Modal dialog allowing traders to schedule a post for market open, pre-market, or custom time.
class CommunityScheduleDialog extends StatefulWidget {
  const CommunityScheduleDialog({
    super.key,
    required this.onSchedule,
    this.initialDateTime,
  });

  final ValueChanged<DateTime> onSchedule;
  final DateTime? initialDateTime;

  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDateTime,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => CommunityScheduleDialog(
        initialDateTime: initialDateTime,
        onSchedule: (dt) => Navigator.of(ctx).pop(dt),
      ),
    );
  }

  @override
  State<CommunityScheduleDialog> createState() => _CommunityScheduleDialogState();
}

class _CommunityScheduleDialogState extends State<CommunityScheduleDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.initialDateTime ?? now.add(const Duration(hours: 1));
    _selectedTime = TimeOfDay.fromDateTime(_selectedDate);
  }

  void _applyPreset(int hour, int minute) {
    setState(() {
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.sz(16)),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(420)),
        child: Padding(
          padding: EdgeInsets.all(context.sp(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.sp(8)),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.schedule, color: colors.primary, size: context.sz(20)),
                  ),
                  SizedBox(width: context.sp(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Post',
                          style: context.uiText.heading.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colors.foreground,
                          ),
                        ),
                        Text(
                          'Post will be published automatically',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiIconButton(
                    icon: Icons.close,
                    size: UiSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: context.sp(20)),

              Text(
                'Market Timing Presets',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.foregroundMuted,
                ),
              ),
              SizedBox(height: context.sp(8)),
              Wrap(
                spacing: context.sp(8),
                runSpacing: context.sp(8),
                children: [
                  _PresetChip(
                    label: 'Pre-Market (08:30 AM)',
                    isSelected: _selectedTime.hour == 8 && _selectedTime.minute == 30,
                    onTap: () => _applyPreset(8, 30),
                  ),
                  _PresetChip(
                    label: 'Market Open (09:15 AM)',
                    isSelected: _selectedTime.hour == 9 && _selectedTime.minute == 15,
                    onTap: () => _applyPreset(9, 15),
                  ),
                  _PresetChip(
                    label: 'Mid-Session (01:00 PM)',
                    isSelected: _selectedTime.hour == 13 && _selectedTime.minute == 0,
                    onTap: () => _applyPreset(13, 0),
                  ),
                  _PresetChip(
                    label: 'Closing Bell (03:15 PM)',
                    isSelected: _selectedTime.hour == 15 && _selectedTime.minute == 15,
                    onTap: () => _applyPreset(15, 15),
                  ),
                ],
              ),
              SizedBox(height: context.sp(20)),

              // Date & Time pickers
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(context.sz(8)),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(12),
                          vertical: context.sp(10),
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(context.sz(8)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: context.sz(16), color: colors.foregroundMuted),
                            SizedBox(width: context.sp(8)),
                            Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: context.uiText.body.copyWith(color: colors.foreground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(12)),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _selectedTime,
                        );
                        if (picked != null) {
                          setState(() => _selectedTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(context.sz(8)),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(12),
                          vertical: context.sp(10),
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.border),
                          borderRadius: BorderRadius.circular(context.sz(8)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time_outlined, size: context.sz(16), color: colors.foregroundMuted),
                            SizedBox(width: context.sp(8)),
                            Text(
                              _selectedTime.format(context),
                              style: context.uiText.body.copyWith(color: colors.foreground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(24)),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  UiButton(
                    label: 'Cancel',
                    variant: UiVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: context.sp(8)),
                  UiButton(
                    label: 'Confirm Schedule',
                    variant: UiVariant.primary,
                    icon: Icons.check,
                    onPressed: () {
                      widget.onSchedule(scheduledDateTime);
                    },
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

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ui.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.sz(20)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: context.sp(10), vertical: context.sp(6)),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(context.sz(20)),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: context.uiText.caption.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colors.primary : colors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}
