import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Reads browser tab visibility (`true` when not `hidden`).
bool readWebDocumentVisible() => web.document.visibilityState != 'hidden';

/// Subscribes to `document.visibilitychange` and returns a cleanup callback.
void Function() registerWebVisibilityListener(
  void Function(bool isVisible) onChanged,
) {
  final web.EventListener listener = ((web.Event _) {
    onChanged(readWebDocumentVisible());
  }).toJS;
  web.document.addEventListener('visibilitychange', listener);
  return () {
    web.document.removeEventListener('visibilitychange', listener);
  };
}
