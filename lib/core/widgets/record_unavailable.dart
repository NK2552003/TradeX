import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class RecordUnavailable extends StatelessWidget {
  const RecordUnavailable({
    super.key,
    required this.message,
    this.title = 'Record unavailable',
    required this.onBack,
  });

  final String message;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: double.infinity,
      height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
      child: UiCard(
        padding: EdgeInsets.zero,
        child: Center(
          child: UiEmptyState(
            icon: Icons.article_outlined,
            title: title,
            message: message,
            action: UiButton(
              label: 'Go back',
              leadingIcon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
          ),
        ),
      ),
    ),
  );
}
