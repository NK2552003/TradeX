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
    final bool isChecking = _loading && _access == null;

    if (isChecking) {
      return _buildCheckingState(context);
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    return _buildRestrictedState(context, isSuspended);
  }

  // ── 1. Checking Session / Verification State ────────────────────────────────
  Widget _buildCheckingState(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Security Status Pill
          UiBadge(
            label: 'TERMINAL SECURITY GATE',
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
            size: UiSize.sm,
          ),
          UiGap.v(theme.spacing.lg),

          // Animated Glowing Core Shield
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: context.sz(92),
                height: context.sz(92),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.28),
                    width: theme.borders.hairline,
                  ),
                ),
              ),
              Container(
                width: context.sz(72),
                height: context.sz(72),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: context.sz(36),
                  color: colors.primary,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.border,
                      width: theme.borders.hairline,
                    ),
                  ),
                  child: UiProgressCircle(
                    size: context.sz(18),
                    thickness: 2,
                    showLabel: false,
                  ),
                ),
              ),
            ],
          ),
          UiGap.v(theme.spacing.lg),

          // Titles
          Text(
            'Verifying Terminal Session',
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.xs),
          Text(
            'Establishing authenticated handshake with TraderHub security perimeter and validating user clearance for ${widget.destination}.',
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
            ),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.lg),

          // Verification checklist
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            decoration: BoxDecoration(
              color: colors.surfaceMuted.withValues(alpha: 0.5),
              borderRadius: context.radius(theme.radii.md),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.5),
                width: theme.borders.hairline,
              ),
            ),
            child: Column(
              children: <Widget>[
                _buildVerificationRow(
                  context,
                  title: 'Cryptographic Auth Token',
                  status: 'Active',
                  isDone: true,
                ),
                const UiDivider(spacing: 8),
                _buildVerificationRow(
                  context,
                  title: 'Trading Clearance & Permissions',
                  status: 'Validating',
                  isDone: false,
                  inProgress: true,
                ),
                const UiDivider(spacing: 8),
                _buildVerificationRow(
                  context,
                  title: 'Destination Session Gate',
                  status: widget.destination,
                  isDone: false,
                ),
              ],
            ),
          ),
          UiGap.v(theme.spacing.lg),

          // Indeterminate progress bar
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                backgroundColor: colors.surfaceMuted,
                color: colors.primary,
                minHeight: 4,
              ),
            ),
          ),
          UiGap.v(theme.spacing.md),

          if (widget.onLogout != null)
            UiButton(
              label: 'Cancel & Sign out',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              onPressed: widget.onLogout,
            ),
        ],
      ),
    );
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
                ? 'Your TraderHub terminal credentials have been suspended by the compliance desk. Contact support for investigation or remediation.'
                : 'Your trader profile is currently pending approval by an administrator before access to private workspace tools is granted.',
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
            ),
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
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          UiGap.v(theme.spacing.xs),
          Text(
            _error ??
                'Unable to verify account access. Check your connection and retry.',
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
            ),
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

  Widget _buildVerificationRow(
    BuildContext context, {
    required String title,
    required String status,
    required bool isDone,
    bool inProgress = false,
  }) {
    final colors = context.uiColors;
    return Row(
      children: <Widget>[
        Icon(
          isDone
              ? Icons.check_circle_rounded
              : (inProgress ? Icons.hourglass_top_rounded : Icons.radio_button_unchecked),
          size: context.sz(16),
          color: isDone
              ? colors.bullish
              : (inProgress ? colors.primary : colors.foregroundSubtle),
        ),
        UiGap.h(context.ui.spacing.xs),
        Expanded(
          child: Text(
            title,
            style: context.uiText.body.copyWith(
              fontSize: context.fs(13),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          status,
          style: context.uiText.caption.copyWith(
            color: isDone
                ? colors.bullish
                : (inProgress ? colors.primary : colors.foregroundMuted),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
          style: context.uiText.caption.copyWith(
            color: colors.foregroundMuted,
          ),
        ),
        Text(
          value,
          style: context.uiText.caption.copyWith(
            color: color ?? colors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
