import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../privacy/consent_preferences.dart';
import 'ad_config.dart';
import 'ad_platform.dart';

class AdSenseScope extends StatefulWidget {
  const AdSenseScope({
    super.key,
    required this.eligible,
    this.previewEligible,
    required this.child,
    this.config,
    this.consent,
  });
  final bool eligible;

  /// Development placeholders may be shown to an admin or demo account, but
  /// only on an eligible public surface. This never authorizes live requests.
  final bool? previewEligible;
  final Widget child;
  final AdConfig? config;
  final ConsentController? consent;
  static AdSenseState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AdInherited>()?.state;
  @override
  State<AdSenseScope> createState() => _AdSenseScopeState();
}

class AdSenseState {
  const AdSenseState(this.config, this.eligible, this.consentAllowed);
  final AdConfig config;
  final bool eligible, consentAllowed;
  bool shows(AdPlacement placement) =>
      eligible &&
      (config.preview ||
          (kIsWeb && consentAllowed && config.configured(placement)));
}

class _AdSenseScopeState extends State<AdSenseScope> {
  late final AdConfig _config = widget.config ?? AdConfig.environment();
  late final ConsentController _consent =
      widget.consent ?? ConsentController.instance;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    _consent.addListener(_changed);
    if (!_config.preview) configureAds(_config);
    _sync();
    unawaited(_consent.initialize());
  }

  void _changed() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  void _sync() {
    _expiry?.cancel();
    final saved = _consent.value.savedAt;
    if (saved != null) {
      final remaining = saved
          .add(ConsentPreferences.lifetime)
          .difference(DateTime.now());
      if (remaining > Duration.zero) {
        _expiry = Timer(remaining, _changed);
      }
    }
    if (!_config.preview) {
      updateAdAccess({
        'eligible': widget.eligible,
        'advertising': AdEligibility.consentAllows(_consent),
        'personalized': _consent.value.personalizedAds,
        'expiresAt':
            saved?.add(ConsentPreferences.lifetime).millisecondsSinceEpoch ?? 0,
      });
    }
  }

  @override
  void didUpdateWidget(covariant AdSenseScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eligible != widget.eligible) _sync();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _consent.removeListener(_changed);
    if (!_config.preview) suspendAds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AdInherited(
    state: AdSenseState(
      _config,
      _config.preview
          ? (widget.previewEligible ?? widget.eligible)
          : widget.eligible,
      AdEligibility.consentAllows(_consent),
    ),
    child: widget.child,
  );
}

class _AdInherited extends InheritedWidget {
  const _AdInherited({required this.state, required super.child});
  final AdSenseState state;
  @override
  bool updateShouldNotify(_AdInherited oldWidget) => true;
}
