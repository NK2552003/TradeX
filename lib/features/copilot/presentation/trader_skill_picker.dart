import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../models/trader_skill.dart';

Future<TraderSkill?> pickTraderSkill(BuildContext context) => UiDialog.show(
  context,
  child: Builder(
    builder: (context) => UiDialog(
      title: 'Trader skills',
      description: 'Choose a command, then add your question.',
      content: Column(
        children: [
          for (final skill in TraderSkill.values)
            AppIndexRow(
              title: skill.command,
              subtitle: skill.description,
              onTap: () => Navigator.of(context).pop(skill),
            ),
        ],
      ),
    ),
  ),
);

String traderSkillDraft(TraderSkill skill, String draft) {
  final text = draft.trimLeft();
  final question = text.startsWith('/')
      ? text.replaceFirst(RegExp(r'^/\S*\s*'), '')
      : text;
  return '${skill.command} $question';
}
