import 'package:flutter/material.dart';
import '../app-ui/app_ui.dart';

Future<bool> confirmRecordPublication(
  BuildContext context,
  String kind,
) => UiDialog.confirm(
  context,
  title: 'Publish this $kind?',
  description:
      'Saving will make the complete $kind readable to other people. Review personal information and trading details first. Linked private records remain private.',
  confirmLabel: 'Make public',
);
