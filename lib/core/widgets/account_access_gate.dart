import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/data/account_access_repository.dart';

/// Suspended accounts never render cached private screens. Access is refreshed
/// on resume and periodically; database checks also protect every request.
class AccountAccessGate extends StatefulWidget {
  const AccountAccessGate({
    super.key,
    required this.repository,
    required this.destination,
    required this.onAccess,
    required this.builder,
    this.onLogout,
  });
  final AccountAccessRepository repository;
  final String destination;
  final ValueChanged<AccountAccess> onAccess;
  final WidgetBuilder builder;
  final VoidCallback? onLogout;

  @override
  State<AccountAccessGate> createState() => _AccountAccessGateState();
}

class _AccountAccessGateState extends State<AccountAccessGate>
    with WidgetsBindingObserver {
  AccountAccess? _access;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant AccountAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _generation++;
      _access = null;
      _loading = false;
      _refresh();
    } else if (oldWidget.destination != widget.destination) {
      _recordDestination();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final access = await widget.repository.load();
      if (!mounted || generation != _generation) return;
      widget.onAccess(access);
      setState(() {
        _access = access;
        _error = null;
      });
      _recordDestination();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Unable to verify account access. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _recordDestination() {
    if (_access?.isActive != true) return;
    // Telemetry must not interrupt navigation; the server deduplicates events.
    unawaited(
      widget.repository
          .recordDestination(widget.destination)
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null && _access?.isActive == true) {
      return widget.builder(context);
    }
    return UiPage(
      title: _access?.status == 'suspended'
          ? 'Account suspended'
          : 'Account access',
      actions: [
        if (widget.onLogout != null)
          UiButton(
            label: 'Sign out',
            variant: UiVariant.outline,
            onPressed: widget.onLogout,
          ),
      ],
      child: UiAsyncView<AccountAccess>(
        loading: _loading && _access == null,
        error: _error,
        data: _access,
        onRetry: _refresh,
        loadingMessage: 'Checking account access…',
        dataBuilder: (context, access) => UiEmptyState(
          icon: Icons.lock_outline,
          title: access.status == 'suspended'
              ? 'Access has been suspended'
              : 'Account approval required',
          message:
              'Contact support for help with your account. You can check again after an administrator restores access.',
          actionLabel: 'Check access',
          onActionPressed: _loading ? null : _refresh,
        ),
      ),
    );
  }
}
