import 'package:flutter/widgets.dart';
import 'ad_config.dart';

void configureAds(AdConfig config) {}
void updateAdAccess(Map<String, Object> access) {}
void suspendAds() {}
Widget adPlatformView({
  required AdPlacement placement,
  required int occurrence,
  required double width,
  required double height,
  required ValueChanged<String> onState,
}) => const SizedBox.shrink();
