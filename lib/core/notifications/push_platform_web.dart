import 'dart:js_interop';

@JS('tradexPushSubscription')
external JSPromise<JSString> _subscription();
Future<String> currentSubscription() async =>
    (await _subscription().toDart).toDart;

@JS('tradexPushStatus')
external JSPromise<JSString> _status();
@JS('tradexPushEnable')
external JSPromise<JSString> _enable(JSString key);
@JS('tradexPushDisable')
external JSPromise<JSString> _disable();

Future<String> pushStatus() async => (await _status().toDart).toDart;
Future<String> enablePush(String key) async =>
    (await _enable(key.toJS).toDart).toDart;
Future<String> disablePush() async => (await _disable().toDart).toDart;

Stream<String> get tokenChanges => const Stream.empty();
