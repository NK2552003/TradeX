import 'package:flutter/widgets.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openInstrumentLink(
  BuildContext context,
  Uri uri, {
  required String failureTitle,
}) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } on Exception {
    // Report blocked and unsupported links through the same feedback.
  }
  if (context.mounted) UiToast.error(context, title: failureTitle);
}
