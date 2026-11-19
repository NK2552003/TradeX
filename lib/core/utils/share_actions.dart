import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app-ui/app_ui.dart';
// ignore: unnecessary_import
import '../flutter-ui/flutter_ui.dart';

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

  /// Branded multi-channel bottom sheet for sharing any canonical subdomain URL
  /// (trader profile, affiliate referral link, or feature URL) across Copy,
  /// WhatsApp, X, Telegram, LinkedIn, Email, and OS System Share.
  static Future<void> showLinkShareSheet(
    BuildContext context, {
    required String title,
    required String url,
    String? subtitle,
    String? shareMessage,
    String copyToastTitle = 'Link copied',
    VoidCallback? onSendDm,
  }) {
    final Uri? parsed = Uri.tryParse(url);
    final String hostLabel = parsed != null && parsed.host.isNotEmpty
        ? parsed.host
        : 'alphajournal.in';
    final String cleanHeadline = subtitle != null && subtitle.trim().isNotEmpty
        ? '$title — $subtitle'
        : title;
    final String fullShareText = shareMessage ?? '$cleanHeadline\n\n$url';

    return showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: UiDialog.sheetAnimationStyle(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final UiTheme theme = ctx.ui;
        final c = theme.colors;
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ctx.sz(520),
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.84,
            ),
            child: UiCard(
              variant: UiCardVariant.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ctx.sp(theme.radii.lg)),
              ),
              padding: EdgeInsets.fromLTRB(
                ctx.sp(theme.spacing.md),
                ctx.sp(theme.spacing.md),
                ctx.sp(theme.spacing.md),
                ctx.sp(theme.spacing.lg),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  title,
                                  style: ctx.uiText.heading.copyWith(
                                    fontSize: ctx.fs(16),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle.trim().isNotEmpty)
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ctx.uiText.caption.copyWith(
                                      color: c.foregroundMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          UiBadge(
                            label: hostLabel,
                            size: UiSize.xs,
                            variant: UiBadgeVariant.soft,
                            intent: UiIntent.primary,
                          ),
                          UiGap.h(theme.spacing.xs),
                          UiIconButton(
                            icon: Icons.close_rounded,
                            size: UiSize.xs,
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      UiGap.v(theme.spacing.sm),
                      UiCard(
                        variant: UiCardVariant.outlined,
                        density: UiDensity.compact,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.link_rounded,
                              size: ctx.sz(16),
                              color: c.primary,
                            ),
                            UiGap.h(theme.spacing.xs),
                            Expanded(
                              child: Text(
                                url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ctx.uiText.mono.copyWith(
                                  fontSize: ctx.fs(11.5),
                                  color: c.foregroundMuted,
                                ),
                              ),
                            ),
                            UiGap.h(theme.spacing.xs),
                            UiButton(
                              label: 'Copy Link',
                              icon: Icons.content_copy_rounded,
                              size: UiSize.xs,
                              variant: UiVariant.soft,
                              intent: UiIntent.primary,
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                copy(context, url, title: copyToastTitle);
                              },
                            ),
                          ],
                        ),
                      ),
                      UiGap.v(theme.spacing.sm),
                      Text(
                        'SHARE TO EXTERNAL APPS',
                        style: ctx.uiText.label.copyWith(
                          fontSize: ctx.fs(10.5),
                          color: c.foregroundSubtle,
                          letterSpacing: 0.6,
                        ),
                      ),
                      UiGap.v(theme.spacing.xs),
                      Wrap(
                        spacing: ctx.sp(theme.spacing.xs),
                        runSpacing: ctx.sp(theme.spacing.xs),
                        children: <Widget>[
                          UiButton(
                            label: 'WhatsApp',
                            icon: Icons.chat_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              external(
                                context,
                                uri: Uri.https('wa.me', '/', {
                                  'text': fullShareText,
                                }),
                                text: fullShareText,
                                platform: 'WhatsApp',
                              );
                            },
                          ),
                          UiButton(
                            label: 'X / Twitter',
                            icon: Icons.alternate_email_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              external(
                                context,
                                uri: Uri.https('x.com', '/intent/tweet', {
                                  'text': cleanHeadline,
                                  'url': url,
                                }),
                                text: fullShareText,
                                platform: 'X / Twitter',
                              );
                            },
                          ),
                          UiButton(
                            label: 'Telegram',
                            icon: Icons.near_me_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              external(
                                context,
                                uri: Uri.https('t.me', '/share/url', {
                                  'url': url,
                                  'text': cleanHeadline,
                                }),
                                text: fullShareText,
                                platform: 'Telegram',
                              );
                            },
                          ),
                          UiButton(
                            label: 'LinkedIn',
                            icon: Icons.business_center_outlined,
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              external(
                                context,
                                uri: Uri.https(
                                  'www.linkedin.com',
                                  '/sharing/share-offsite/',
                                  {'url': url},
                                ),
                                text: fullShareText,
                                platform: 'LinkedIn',
                              );
                            },
                          ),
                          UiButton(
                            label: 'Email',
                            icon: Icons.mail_outline_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.outline,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              external(
                                context,
                                uri: Uri(
                                  scheme: 'mailto',
                                  query:
                                      'subject=${Uri.encodeComponent(title)}&body=${Uri.encodeComponent(fullShareText)}',
                                ),
                                text: fullShareText,
                                platform: 'Email',
                              );
                            },
                          ),
                          UiButton(
                            label: 'System Share...',
                            icon: Icons.ios_share_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.soft,
                            intent: UiIntent.primary,
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              system(
                                context,
                                text: fullShareText,
                                subject: title,
                              );
                            },
                          ),
                        ],
                      ),
                      if (onSendDm != null) ...[
                        UiGap.v(theme.spacing.sm),
                        const UiDivider(),
                        UiGap.v(theme.spacing.xs),
                        UiButton(
                          label: 'Send via AlphaJournal Messages',
                          icon: Icons.send_rounded,
                          variant: UiVariant.outline,
                          expand: true,
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onSendDm();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
