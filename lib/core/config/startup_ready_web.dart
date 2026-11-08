import 'dart:js_interop';

@JS('globalThis.alphajournalReady')
external JSFunction? get _onReady;

void finishWebStartup() => _onReady?.callAsFunction();
