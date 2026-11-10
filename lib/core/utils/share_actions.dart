import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app-ui/app_ui.dart';

/// Keep browser share/launch calls in the original tap's activation window.
/// Clipboard is a fallback, never an awaited prerequisite to opening an app.
class ShareActions {
  const ShareActions._();

  static Future<bool> copy(
    BuildContext context,
    String text, {
    String title = 'Link copied',
  }) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        UiToast.success(context, title: title, message: text);
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        await UiDialog.show<void>(
          context,
          child: UiDialog(
            title: 'Copy link manually',
            content: SelectableText(text),
          ),
        );
      }
      return false;
    }
  }

  static Future<bool> external(
    BuildContext context, {
    required Uri uri,
    required String text,
    required String platform,
  }) async {
    try {
      if (await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      )) {
        if (context.mounted) {
          UiToast.info(context, title: 'Opening $platform');
        }
        return true;
      }
    } catch (_) {
      // A blocked popup or missing application must still leave a usable link.
    }
    return context.mounted
        ? copy(context, text, title: 'Copied for sharing')
        : false;
  }

  static Rect? origin(BuildContext context) {
    final renderObject = context.findRenderObject();
    return renderObject is RenderBox &&
            renderObject.hasSize &&
            !renderObject.size.isEmpty
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
  }

  static Future<bool> system(
    BuildContext context, {
    required String text,
    String? subject,
  }) async {
    final position = origin(context);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: position,
        ),
      );
      // Closing the system sheet is not a successful share or a copy request.
      if (result.status == ShareResultStatus.dismissed) return false;
      if (context.mounted) {
        UiToast.info(
          context,
          title: result.status == ShareResultStatus.success
              ? 'Shared'
              : 'Share sheet opened',
        );
      }
      return true;
    } catch (_) {
      return context.mounted
          ? copy(context, text, title: 'Copied for sharing')
          : false;
    }
  }
}
