import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class CalendarExampleView extends StatefulWidget {
  const CalendarExampleView({super.key});

  @override
  State<CalendarExampleView> createState() => _CalendarExampleViewState();
}

class _CalendarExampleViewState extends State<CalendarExampleView> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCalendar, UiDatePicker & UiDateRangePicker', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCalendar(
            selected: _selectedDate,
            onDateSelected: (d) => setState(() => _selectedDate = d),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiDatePicker(
            value: _selectedDate,
            onChanged: (d) => setState(() => _selectedDate = d),
          ),
        ],
      ),
    );
  }
}
