import 'dart:js_interop';

@JS('globalThis.addEventListener')
external void _listen(JSString name, JSFunction callback);

extension type _StorageChange(JSObject _) implements JSObject {
  external JSString? get key;
}

/// Attached once by the application-scoped controller, never by a dialog.
void watchConsentStorage(void Function() refresh) {
  _listen(
    'storage'.toJS,
    ((JSObject event) {
      final key = _StorageChange(event).key?.toDart;
      if (key == null || key.endsWith('alphajournal_consent_v1')) refresh();
    }).toJS,
  );
  _listen('focus'.toJS, ((JSObject _) => refresh()).toJS);
}
