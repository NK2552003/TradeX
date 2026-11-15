import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('globalThis.alphajournalInstall')
external JSObject? get _bridge;
@JS('globalThis.alphajournalInstall.snapshot')
external JSString _snapshot();
@JS('globalThis.alphajournalInstall.subscribe')
external void _subscribe(JSFunction callback);
@JS('globalThis.alphajournalInstall.prompt')
external JSPromise<JSString> _prompt();
@JS('globalThis.alphajournalInstall.dismiss')
external void _dismiss();

class BrowserInstall extends ChangeNotifier {
  BrowserInstall() {
    if (_bridge != null) {
      _refresh();
      _subscribe(_refresh.toJS);
    }
  }
  static final instance = BrowserInstall();
  bool available = false;
  bool installed = false;
  bool canSuggest = false;
  bool get supported => _bridge != null;

  void _refresh() {
    final state = jsonDecode(_snapshot().toDart) as Map<String, dynamic>;
    available = state['available'] == true;
    installed = state['installed'] == true;
    canSuggest = state['canSuggest'] == true;
    notifyListeners();
  }

  Future<String> prompt() async {
    if (!available) return 'unavailable';
    // Call synchronously before awaiting to preserve browser user activation.
    final pending = _prompt();
    return (await pending.toDart).toDart;
  }

  void dismiss() {
    if (_bridge != null) _dismiss();
  }

  void refresh() {
    if (_bridge != null) _refresh();
  }
}
