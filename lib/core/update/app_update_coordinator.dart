import 'package:flutter/material.dart';

import 'app_update_models.dart';
import 'app_update_preferences.dart';
import 'app_update_prompt.dart';
import 'app_update_service.dart';

class AppUpdateCoordinator extends StatefulWidget {
  const AppUpdateCoordinator({
    super.key,
    required this.navigatorKey,
    required this.child,
    required this.enabled,
    this.service,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool enabled;
  final AppUpdateService? service;

  @override
  State<AppUpdateCoordinator> createState() => _AppUpdateCoordinatorState();
}

class _AppUpdateCoordinatorState extends State<AppUpdateCoordinator>
    with WidgetsBindingObserver {
  bool _isChecking = false;
  bool _isShowingPrompt = false;

  AppUpdateService get _service => widget.service ?? AppUpdateService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void didUpdateWidget(covariant AppUpdateCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled) _check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.enabled && state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted || _isChecking || _isShowingPrompt) return;
    _isChecking = true;
    late final AppUpdateStatus status;
    try {
      status = await _service.check();
    } finally {
      _isChecking = false;
    }
    if (!mounted || !status.checkedSuccessfully || !status.hasUpdate) {
      return;
    }
    final shouldPrompt = await AppUpdatePreferences.shouldPrompt(status);
    if (!mounted || !shouldPrompt) return;
    final promptContext = widget.navigatorKey.currentContext;
    if (promptContext == null || !promptContext.mounted) return;
    _isShowingPrompt = true;
    AppUpdatePromptResult? result;
    try {
      result = await showAppUpdatePrompt(promptContext, status);
    } finally {
      _isShowingPrompt = false;
    }
    if (result != AppUpdatePromptResult.updated) {
      await AppUpdatePreferences.skip(status);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
