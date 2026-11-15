import 'package:flutter/widgets.dart';

import 'app_visibility_stub.dart'
    if (dart.library.js_interop) 'app_visibility_web.dart';

/// Tracks whether the app/browser tab is currently visible and active.
///
/// Combines Flutter [WidgetsBindingObserver] lifecycle states with web
/// `document.visibilitychange` events so polling timers pause when hidden and
/// perform one immediate refresh when the user returns.
class AppVisibility with WidgetsBindingObserver {
  AppVisibility._() {
    _attach();
  }

  static final AppVisibility instance = AppVisibility._();

  final Set<ValueChanged<bool>> _listeners = <ValueChanged<bool>>{};
  bool _attached = false;
  bool _lifecycleVisible = true;
  bool _webVisible = true;
  bool _lastNotified = true;
  void Function()? _disposeWebListener;

  bool get isVisible => _lifecycleVisible && _webVisible;

  void _attach() {
    if (_attached) return;
    _attached = true;
    try {
      final binding = WidgetsBinding.instance;
      binding.addObserver(this);
      final state = binding.lifecycleState;
      if (state != null) {
        _lifecycleVisible = state == AppLifecycleState.resumed;
      }
    } catch (_) {
      // Allow usage in pure Dart tests without WidgetsBinding.
    }
    try {
      _webVisible = readWebDocumentVisible();
      _disposeWebListener = registerWebVisibilityListener((bool visible) {
        if (_webVisible == visible) return;
        _webVisible = visible;
        _notifyIfChanged();
      });
    } catch (_) {}
    _lastNotified = isVisible;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool next = state == AppLifecycleState.resumed;
    if (_lifecycleVisible == next) return;
    _lifecycleVisible = next;
    _notifyIfChanged();
  }

  void _notifyIfChanged() {
    final bool current = isVisible;
    if (current == _lastNotified) return;
    _lastNotified = current;
    for (final ValueChanged<bool> listener in List<ValueChanged<bool>>.of(
      _listeners,
    )) {
      listener(current);
    }
  }

  void addListener(ValueChanged<bool> listener) {
    _attach();
    _listeners.add(listener);
  }

  void removeListener(ValueChanged<bool> listener) {
    _listeners.remove(listener);
  }

  @visibleForTesting
  void setVisibleForTest(bool visible) {
    _lifecycleVisible = visible;
    _webVisible = visible;
    _notifyIfChanged();
  }

  @visibleForTesting
  void disposeForTest() {
    _disposeWebListener?.call();
    _disposeWebListener = null;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _listeners.clear();
    _attached = false;
  }
}
