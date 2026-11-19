import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/affiliate_workspace_repository.dart';
import '../../models/affiliate_workspace.dart';

class AffiliateWorkspaceView extends StatefulWidget {
  const AffiliateWorkspaceView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.repository,
    this.onNavigate,
    this.actions,
  });
  final String title, subtitle;
  final AffiliateWorkspaceRepository? repository;
  final ValueChanged<String>? onNavigate;
  final List<Widget> Function(
    BuildContext,
    AffiliateWorkspace,
    AffiliateWorkspaceActions,
  )?
  actions;
  final Widget Function(
    BuildContext,
    AffiliateWorkspace,
    AffiliateWorkspaceActions,
  )
  builder;
  @override
  State<AffiliateWorkspaceView> createState() => _AffiliateWorkspaceViewState();
}

class AffiliateWorkspaceActions {
  const AffiliateWorkspaceActions(
    this.repository,
    this.run,
    this.busy, [
    this.reload,
  ]);
  final AffiliateWorkspaceRepository repository;
  final Future<void> Function(Future<void> Function(), String) run;
  final bool busy;
  final VoidCallback? reload;

  void call() => reload?.call();
}

class _AffiliateWorkspaceViewState extends State<AffiliateWorkspaceView> {
  late Future<AffiliateWorkspace> _future;
  bool _busy = false;
  String? _error;
  AffiliateWorkspaceRepository get repository =>
      widget.repository ?? AffiliateWorkspaceRepository.instance;
  Future<AffiliateWorkspace> _loadFuture() {
    final future = repository.load();
    // A retry can fail before the next frame attaches its FutureBuilder.
    future.ignore();
    return future;
  }

  @override
  void initState() {
    super.initState();
    _future = _loadFuture();
  }

  Future<void> _run(Future<void> Function() operation, String message) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      setState(() {
        _future = _loadFuture();
      });
      UiToast.show(context, title: message, intent: UiIntent.success);
    } catch (e) {
      if (mounted) setState(() => _error = 'Unable to save. ${e.toString()}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AffiliateWorkspace>(
      future: _future,
      builder: (context, snapshot) {
        final w = snapshot.data;
        final actionsHolder = w != null
            ? AffiliateWorkspaceActions(
                repository,
                _run,
                _busy,
                () => setState(() {
                  _future = _loadFuture();
                }),
              )
            : null;

        final List<Widget> headerActions = [
          if (w != null && widget.actions != null && actionsHolder != null)
            ...widget.actions!(context, w, actionsHolder),
          UiIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh workspace',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _future = _loadFuture();
                  }),
          ),
        ];

        return UiPage(
          maxWidth: 1440,
          title: widget.title,
          subtitle: widget.subtitle,
          actions: headerActions,
          child: Builder(
            builder: (context) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Column(
                  children: [
                    UiSkeleton(height: 100),
                    UiGap.v(16),
                    UiSkeleton(height: 280),
                  ],
                );
              }
              if (snapshot.hasError) {
                return UiEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Workspace unavailable',
                  message:
                      'Your partner data could not be loaded. Check your connection and database setup.',
                  action: UiButton(
                    label: 'Try again',
                    onPressed: () => setState(() {
                      _future = _loadFuture();
                    }),
                  ),
                );
              }
              final currentW = snapshot.requireData;
              if (!currentW.enrolled) {
                return const UiEmptyState(
                  icon: Icons.handshake_outlined,
                  title: 'Partner approval required',
                  message:
                      'Submit an affiliate application from your account menu. Your workspace unlocks after approval.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (currentW.isDemo) ...[
                    const UiCallout(
                      title: 'Partner preview',
                      message:
                          'Sample data. Changes are saved on this device; payout requests do not transfer money.',
                    ),
                    const UiGap.v(16),
                  ],
                  if (currentW.profile.text('status') != 'active') ...[
                    const UiCallout(
                      title: 'Partner account restricted',
                      message:
                          'Campaign changes and payouts require an active partner account.',
                      intent: UiIntent.warning,
                    ),
                    const UiGap.v(16),
                  ],
                  if (_error != null) ...[
                    UiCallout(
                      title: 'Action could not be completed',
                      message: _error,
                      intent: UiIntent.danger,
                    ),
                    const UiGap.v(16),
                  ],
                  widget.builder(context, currentW, actionsHolder!),
                  SizedBox(height: context.uiDockInset),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class AffiliatePanel extends StatelessWidget {
  const AffiliatePanel({
    super.key,
    required this.title,
    this.description,
    required this.child,
  });
  final String title;
  final String? description;
  final Widget child;
  @override
  Widget build(BuildContext context) => UiCard(
    title: title,
    subtitle: description,
    headerDivider: true,
    child: child,
  );
}

class AffiliateColumns extends StatelessWidget {
  const AffiliateColumns({super.key, required this.main, required this.side});
  final Widget main, side;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 960) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [main, const UiGap.v(16), side],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: main),
          const UiGap.h(16),
          Expanded(child: side),
        ],
      );
    },
  );
}

Future<void> copyAffiliateText(
  BuildContext context,
  String title,
  String text,
) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      UiToast.show(context, title: '$title copied', intent: UiIntent.success);
    }
  } catch (_) {
    if (context.mounted) {
      UiToast.show(
        context,
        title: 'Clipboard unavailable',
        intent: UiIntent.danger,
      );
    }
  }
}

String affiliateDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
UiIntent affiliateStatusIntent(String status) => switch (status) {
  'converted' || 'paid' || 'active' => UiIntent.success,
  'pending' || 'processing' => UiIntent.warning,
  'failed' || 'churned' => UiIntent.danger,
  _ => UiIntent.neutral,
};
