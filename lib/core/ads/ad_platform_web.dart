import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'ad_config.dart';

@JS('globalThis.AlphaJournalAds')
external JSObject? get _adsBridge;

@JS('AlphaJournalAds.configure')
external void _configure(JSString json);
@JS('AlphaJournalAds.updateAccess')
external void _access(JSString json);
@JS('AlphaJournalAds.suspend')
external void _suspend();
@JS('AlphaJournalAds.mount')
external void _mount(
  JSObject element,
  JSString placement,
  JSNumber width,
  JSNumber height,
  JSFunction callback,
  JSString instanceId,
);
@JS('AlphaJournalAds.unmount')
external void _unmount(JSObject element);

bool _hasBridgeMethod(String method) {
  try {
    final JSObject? bridge = _adsBridge;
    return bridge != null && bridge.has(method);
  } catch (_) {
    return false;
  }
}

void configureAds(AdConfig config) {
  if (!_hasBridgeMethod('configure')) return;
  try {
    _configure(jsonEncode(config.toJson()).toJS);
  } catch (_) {}
}

void updateAdAccess(Map<String, Object> access) {
  if (!_hasBridgeMethod('updateAccess')) return;
  try {
    _access(jsonEncode(access).toJS);
  } catch (_) {}
}

void suspendAds() {
  if (!_hasBridgeMethod('suspend')) return;
  try {
    _suspend();
  } catch (_) {}
}
Widget adPlatformView({
  required AdPlacement placement,
  required int occurrence,
  required double width,
  required double height,
  required ValueChanged<String> onState,
}) => _AdView(
  key: ValueKey(
    '${placement.id}-$occurrence-${placement.isFeed ? 'responsive' : '$width-$height'}',
  ),
  placement: placement,
  instanceId: '${placement.id}:$occurrence',
  width: width,
  height: height,
  onState: onState,
);

class _AdView extends StatefulWidget {
  const _AdView({
    super.key,
    required this.placement,
    required this.instanceId,
    required this.width,
    required this.height,
    required this.onState,
  });
  final AdPlacement placement;
  final String instanceId;
  final double width, height;
  final ValueChanged<String> onState;
  @override
  State<_AdView> createState() => _AdViewState();
}

class _AdViewState extends State<_AdView> {
  web.HTMLDivElement? _element;
  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'div',
    onElementCreated: (element) {
      final div = element as web.HTMLDivElement;
      _element = div;
      if (!_hasBridgeMethod('mount')) {
        if (mounted) widget.onState('error');
        return;
      }
      try {
        _mount(
          div,
          widget.placement.id.toJS,
          widget.width.toJS,
          widget.height.toJS,
          ((JSString status) {
            if (mounted) widget.onState(status.toDart);
          }).toJS,
          widget.instanceId.toJS,
        );
      } catch (_) {
        if (mounted) widget.onState('error');
      }
    },
  );
  @override
  void dispose() {
    if (_element != null && _hasBridgeMethod('unmount')) {
      try {
        _unmount(_element!);
      } catch (_) {}
    }
    super.dispose();
  }
}
