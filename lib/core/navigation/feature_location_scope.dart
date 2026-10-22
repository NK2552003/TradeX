import 'package:flutter/widgets.dart';

/// Synchronizes shareable feature selections with the app's existing router.
class FeatureLocationScope extends InheritedWidget {
  const FeatureLocationScope({
    super.key,
    required this.location,
    required this.onNavigate,
    required super.child,
  });
  final Uri location;
  final ValueChanged<Uri> onNavigate;

  static FeatureLocationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeatureLocationScope>();

  bool _matches(String destination) =>
      location.path == '/$destination' ||
      (destination == 'community_feed' && location.path == '/community');

  int? selection(
    String destination,
    List<String> names, {
    String parameter = 'tab',
  }) {
    if (!_matches(destination)) return null;
    final index = names.indexOf(
      location.queryParameters[parameter] ?? names.first,
    );
    return index < 0 ? 0 : index;
  }

  void select(String destination, String name, {String parameter = 'tab'}) {
    if (!_matches(destination)) return;
    final target = location.replace(
      path: '/$destination',
      queryParameters: {...location.queryParameters, parameter: name},
    );
    if (target != location) onNavigate(target);
  }

  @override
  bool updateShouldNotify(FeatureLocationScope oldWidget) =>
      oldWidget.location != location;
}
