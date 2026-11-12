import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'ad_config.dart';

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
void configureAds(AdConfig config) =>
    _configure(jsonEncode(config.toJson()).toJS);
void updateAdAccess(Map<String, Object> access) =>
    _access(jsonEncode(access).toJS);
void suspendAds() => _suspend();
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
    },
  );
  @override
  void dispose() {
    if (_element != null) _unmount(_element!);
    super.dispose();
  }
}
