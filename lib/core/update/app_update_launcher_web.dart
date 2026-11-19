import 'dart:js_interop';

@JS('globalThis.alphajournalUpdate')
external JSObject? get _updateBridge;

@JS('globalThis.alphajournalUpdate.reload')
external JSPromise<JSBoolean> _reload();

Future<bool> installAppUpdate(Uri? updateUri) async {
  if (_updateBridge == null) return false;
  try {
    return (await _reload().toDart).toDart;
  } on Object {
    return false;
  }
}
