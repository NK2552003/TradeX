import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unused_import, unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/journal/ui/journal_editor_screen.dart';

/// Opens a reviewable unsaved entry; no trade is submitted or logged on open.
Future<void> openCalculatorJournalDraft(
  BuildContext context, {
  required String symbol,
  required double entry,
  required double stopLoss,
  required double quantity,
  double? target,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (routeContext) => Scaffold(
      body: JournalEditorScreen(
        detailsOnly: true,
        entry: AppTrade(
          id: '',
          ticker: symbol,
          side: entry >= stopLoss ? AppSide.long : AppSide.short,
          entry: entry,
          exit: null,
          openedAt: DateTime.now(),
          stopLoss: stopLoss,
          target: target,
          size: quantity,
          title: 'Calculator draft · $symbol',
        ),
        onClose: (_) => Navigator.of(routeContext).pop(),
      ),
    ),
  ),
);
