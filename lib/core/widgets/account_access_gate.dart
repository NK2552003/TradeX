import 'dart:async';

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/data/account_access_repository.dart';
import 'package:alphajournal/core/config/startup_ready.dart';
import 'package:alphajournal/core/utils/app_visibility.dart';

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
    this.loadTimeout = const Duration(seconds: 12),
  });
  final AccountAccessRepository repository;
  final String destination;
  final ValueChanged<AccountAccess> onAccess;
  final WidgetBuilder builder;
  final VoidCallback? onLogout;
  final Duration loadTimeout;

  @override
  State<AccountAccessGate> createState() => _AccountAccessGateState();
}

class _AccountAccessGateState extends State<AccountAccessGate> {
  static const Duration _basePollInterval = Duration(seconds: 60);
  static const int _maxPollFailures = 4;

  AccountAccess? _access;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  int _generation = 0;
  int _consecutiveFailures = 0;

  @override
  void initState() {
    super.initState();
    AppVisibility.instance.addListener(_onVisibilityChanged);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant AccountAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _timer?.cancel();
      _generation++;
      _consecutiveFailures = 0;
      _access = null;
      _error = null;
      _loading = false;
      _refresh();
    } else if (oldWidget.destination != widget.destination) {
      _recordDestination();
    }
  }

  void _onVisibilityChanged(bool isVisible) {
    if (!mounted) return;
    if (!isVisible) {
      _timer?.cancel();
      _timer = null;
    } else {
      _consecutiveFailures = 0;
      _refresh();
    }
  }

  void _scheduleNextPoll() {
    _timer?.cancel();
    _timer = null;
    if (!mounted || !AppVisibility.instance.isVisible) return;
    if (_consecutiveFailures >= _maxPollFailures) return;
    final int multiplier = _consecutiveFailures == 0
        ? 1
        : (1 << (_consecutiveFailures - 1));
    _timer = Timer(_basePollInterval * multiplier, _refresh);
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _timer?.cancel();
    final generation = ++_generation;
    setState(() => _loading = true);
    try {
      final access = await widget.repository.load().timeout(
        widget.loadTimeout,
        onTimeout: () => throw TimeoutException(
          'Account access verification timed out.',
          widget.loadTimeout,
        ),
      );
      if (!mounted || generation != _generation) return;
      _consecutiveFailures = 0;
      widget.onAccess(access);
      setState(() {
        _access = access;
        _error = null;
      });
      _recordDestination();
    } catch (_) {
      if (mounted && generation == _generation) {
        _consecutiveFailures++;
        setState(
          () => _error =
              'Unable to verify account access. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
        _scheduleNextPoll();
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
    AppVisibility.instance.removeListener(_onVisibilityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) finishWebStartup();
      });
    }
    if (_loading && _access == null && _error == null) {
      return Scaffold(
        backgroundColor: context.uiColors.background,
        body: SafeArea(
          child: UiSkeleton.page(
            title: 'Loading workspace',
            subtitle: 'Verifying your account access',
            showMetrics: true,
            cardCount: 3,
          ),
        ),
      );
    }
    if (_error == null && _access?.isActive == true) {
      return widget.builder(context);
    }

    final bool isSuspended = _access?.status == 'suspended';

    return Scaffold(
      backgroundColor: context.uiColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(context.ui.spacing.md),
              vertical: context.sp(context.ui.spacing.lg),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: _buildSurface(context, isSuspended),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurface(BuildContext context, bool isSuspended) {
    if (_error != null) {
      return _buildErrorState(context);
    }

    return _buildRestrictedState(context, isSuspended);
  }

  // ── 2. Restricted / Suspended State ────────────────────────────────────────
  Widget _buildRestrictedState(BuildContext context, bool isSuspended) {
    final theme = context.ui;
    final colors = theme.colors;
    final Color accent = isSuspended ? colors.destructive : colors.warning;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          UiBadge(
            label: isSuspended ? 'ACCOUNT SUSPENDED' : 'APPROVAL REQUIRED',
            intent: isSuspended ? UiIntent.danger : UiIntent.warning,
            variant: UiBadgeVariant.solid,
            size: UiSize.sm,
          ),
          UiGap.v(theme.spacing.lg),

          // Locked shield
          Container(
            width: context.sz(80),
            height: context.sz(80),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: theme.borders.hairline,
              ),
            ),
            child: Icon(
              isSuspended ? Icons.block_rounded : Icons.lock_outline_rounded,
              size: context.sz(40),
              color: accent,
            ),
          ),
          UiGap.v(theme.spacing.lg),

          Text(
            isSuspended
                ? 'Terminal Access Suspended'
                : 'Workspace Access Restricted',
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.xs),
          Text(
            isSuspended
                ? 'Your AlphaJournal terminal credentials have been suspended by the compliance desk. Contact support for investigation or remediation.'
                : 'Your trader profile is currently pending approval by an administrator before access to private workspace tools is granted.',
            style: context.uiText.body.copyWith(color: colors.foregroundMuted),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.lg),

          // Security metadata box
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.4),
              borderRadius: context.radius(theme.radii.md),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.5),
                width: theme.borders.hairline,
              ),
            ),
            child: Column(
              children: <Widget>[
                _buildMetadataRow(
                  context,
                  label: 'Account Status',
                  value: _access?.status.toUpperCase() ?? 'INACTIVE',
                  color: accent,
                ),
                const UiDivider(spacing: 8),
                _buildMetadataRow(
                  context,
                  label: 'Assigned Role',
                  value: _access?.role.label ?? 'Standard Trader',
                ),
                const UiDivider(spacing: 8),
                _buildMetadataRow(
                  context,
                  label: 'Requested Surface',
                  value: widget.destination,
                ),
              ],
            ),
          ),
          UiGap.v(theme.spacing.xl),

          // Action Buttons
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: _loading ? 'Verifying...' : 'Check Access Again',
                  leadingIcon: Icons.refresh_rounded,
                  variant: UiVariant.solid,
                  intent: UiIntent.primary,
                  onPressed: _loading ? null : _refresh,
                ),
              ),
              if (widget.onLogout != null) ...<Widget>[
                UiGap.h(theme.spacing.sm),
                UiButton(
                  label: 'Sign Out',
                  variant: UiVariant.outline,
                  onPressed: widget.onLogout,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Connection / Verification Error State ───────────────────────────────
  Widget _buildErrorState(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          UiBadge(
            label: 'SESSION ERROR',
            intent: UiIntent.danger,
            variant: UiBadgeVariant.soft,
            size: UiSize.sm,
          ),
          UiGap.v(theme.spacing.lg),

          Container(
            width: context.sz(72),
            height: context.sz(72),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.destructive.withValues(alpha: 0.12),
              border: Border.all(
                color: colors.destructive.withValues(alpha: 0.3),
                width: theme.borders.hairline,
              ),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: context.sz(34),
              color: colors.destructive,
            ),
          ),
          UiGap.v(theme.spacing.lg),

          Text(
            'Verification Interrupted',
            style: context.uiText.heading.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.xs),
          Text(
            _error ??
                'Unable to verify account access. Check your connection and retry.',
            style: context.uiText.body.copyWith(color: colors.foregroundMuted),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.xl),

          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: _loading ? 'Retrying...' : 'Retry Handshake',
                  leadingIcon: Icons.refresh_rounded,
                  variant: UiVariant.solid,
                  intent: UiIntent.primary,
                  onPressed: _loading ? null : _refresh,
                ),
              ),
              if (widget.onLogout != null) ...<Widget>[
                UiGap.h(theme.spacing.sm),
                UiButton(
                  label: 'Sign Out',
                  variant: UiVariant.outline,
                  onPressed: widget.onLogout,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
  }) {
    final colors = context.uiColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(color: colors.foregroundMuted),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: color ?? colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
