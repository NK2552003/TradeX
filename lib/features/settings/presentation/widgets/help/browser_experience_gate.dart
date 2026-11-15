import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/cross_subdomain_storage.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/platform/browser_install.dart';
import 'package:tradex/core/privacy/consent_preferences.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_attribution.dart';
import 'cookie_preferences_dialog.dart';
import 'install_app_card.dart';

/// A route-local host provides Navigator context for the shared web dialogs.
class BrowserExperienceGate extends StatefulWidget {
  const BrowserExperienceGate({
    super.key,
    required this.child,
    this.suggestInstall = true,
  });
  final Widget child;
  final bool suggestInstall;

  @override
  State<BrowserExperienceGate> createState() => _BrowserExperienceGateState();
}

class _BrowserExperienceGateState extends State<BrowserExperienceGate> {
  static bool _noticePresented = false;
  static bool _dialogOpen = false;
  bool _ready = false;
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    BrowserInstall.instance.addListener(_suggestInstall);
    _delay = Timer(const Duration(seconds: 2), _start);
  }

  Future<void> _start() async {
    await ConsentController.instance.initialize();
    if (!mounted) return;
    final noticeAlreadyDismissed =
        CrossSubdomainState.getFlag(ConsentController.dismissedNoticeKey) ==
        '1';
    if (ConsentController.instance.needsChoice &&
        !noticeAlreadyDismissed &&
        !_noticePresented &&
        !_dialogOpen) {
      _noticePresented = true;
      _dialogOpen = true;
      try {
        await CookiePreferencesDialog.show(context, manage: false);
        if (ConsentController.instance.needsChoice) {
          CrossSubdomainState.setFlag(
            ConsentController.dismissedNoticeKey,
            '1',
            maxAgeDays: 7,
          );
        }
      } finally {
        _dialogOpen = false;
      }
    }
    if (!mounted) return;
    // A referral in the current URL is captured only after affirmative choice.
    final referral = Uri.base.queryParameters['ref'];
    if (referral != null && ConsentController.instance.value.affiliate) {
      await AffiliateAttribution.capture(
        referral,
        Uri.base.queryParameters['utm_campaign'],
      );
    }
    _ready = true;
    BrowserInstall.instance.refresh();
    _suggestInstall();
  }

  void _suggestInstall() {
    if (!_ready ||
        !mounted ||
        !widget.suggestInstall ||
        _dialogOpen ||
        ConsentController.instance.needsChoice ||
        !BrowserInstall.instance.canSuggest ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      var shown = false;
      try {
        BrowserInstall.instance.refresh();
        if (mounted &&
            widget.suggestInstall &&
            !ConsentController.instance.needsChoice &&
            BrowserInstall.instance.canSuggest) {
          shown = true;
          await UiDialog.show<void>(
            context,
            child: const InstallAppCard(prompt: true),
          );
        }
      } finally {
        if (shown) {
          BrowserInstall.instance.dismiss();
        }
        _dialogOpen = false;
      }
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    if (kIsWeb) BrowserInstall.instance.removeListener(_suggestInstall);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
