import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/app_constants.dart';

class HelpAboutPage extends StatefulWidget {
  const HelpAboutPage({super.key, this.submitTicket});

  final Future<void> Function(String category, String subject, String message)?
  submitTicket;

  @override
  State<HelpAboutPage> createState() => _HelpAboutPageState();
}

class _HelpAboutPageState extends State<HelpAboutPage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();
  String _category = 'Technical Support';
  bool _sending = false;

  final List<String> _categories = const <String>[
    'Technical Support',
    'Billing & Subscriptions',
    'Feature Request',
    'Broker Integration',
    'Bug Report',
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _showChangelogDialog() {
    final theme = context.ui;
    final colors = theme.colors;

    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: "What's New in hejournal.in",
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Version 1.0.0 Banner Card
                Container(
                  padding: EdgeInsets.all(ctx.sp(theme.spacing.md)),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: ctx.radius(theme.radii.lg),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                      width: theme.borders.hairline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.16),
                          borderRadius: ctx.radius(theme.radii.md),
                        ),
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          color: colors.primary,
                          size: ctx.sz(20),
                        ),
                      ),
                      SizedBox(width: ctx.sp(theme.spacing.sm)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: ctx.sp(theme.spacing.xs),
                              runSpacing: ctx.sp(theme.spacing.xxs),
                              children: [
                                Text(
                                  'v1.0.0 (Production GA)',
                                  style: ctx.uiText.bodyStrong,
                                ),
                                const UiBadge(
                                  label: 'Latest',
                                  intent: UiIntent.success,
                                  size: UiSize.xs,
                                ),
                              ],
                            ),
                            Text(
                              'Released August 2026 • Full Production Terminal',
                              style: ctx.uiText.caption.copyWith(
                                color: colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: ctx.sp(theme.spacing.md)),

                // Changes list
                _buildChangelogItem(
                  ctx,
                  icon: Icons.auto_awesome_rounded,
                  iconColor: colors.primary,
                  title: 'Next-Gen Trading & Settings Engine',
                  description:
                      'Granular multi-role workspaces, desktop command palette, and reactive theme & layout density control.',
                ),
                SizedBox(height: ctx.sp(theme.spacing.xs)),
                _buildChangelogItem(
                  ctx,
                  icon: Icons.candlestick_chart_rounded,
                  iconColor: colors.bullish,
                  title: 'Real-Time Market Depth & Live Scanners',
                  description:
                      'Sub-millisecond order book streaming with automated playbook pattern recognition.',
                ),
                SizedBox(height: ctx.sp(theme.spacing.xs)),
                _buildChangelogItem(
                  ctx,
                  icon: Icons.shield_outlined,
                  iconColor: colors.warning,
                  title: 'Institutional Risk & Audit Ledger',
                  description:
                      'Real-time hard stop gates, multi-seat trader permissions, and GDPR data export.',
                ),
                SizedBox(height: ctx.sp(theme.spacing.md)),

                // Previous Version
                Container(
                  padding: EdgeInsets.all(ctx.sp(theme.spacing.sm)),
                  decoration: BoxDecoration(
                    color: colors.surfaceHover,
                    borderRadius: ctx.radius(theme.radii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: ctx.sz(16),
                        color: colors.foregroundMuted,
                      ),
                      SizedBox(width: ctx.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          'v0.9.4 Beta: Pre-trade checklists, journal calendar heatmaps & execution logs.',
                          style: ctx.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          UiButton(
            label: 'Close',
            variant: UiVariant.outline,
            intent: UiIntent.neutral,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogItem(
    BuildContext ctx, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final theme = ctx.ui;
    final colors = theme.colors;
    return Container(
      padding: EdgeInsets.all(ctx.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: ctx.radius(theme.radii.md),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.6),
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: ctx.sz(16), color: iconColor),
          SizedBox(width: ctx.sp(theme.spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ctx.uiText.bodyStrong.copyWith(fontSize: 13.0),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: ctx.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog(String title, String content) {
    final theme = context.ui;
    final colors = theme.colors;

    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: title,
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(ctx.sp(theme.spacing.md)),
              decoration: BoxDecoration(
                color: colors.surfaceHover,
                borderRadius: ctx.radius(theme.radii.lg),
                border: Border.all(
                  color: colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Text(
                content,
                style: ctx.uiText.body.copyWith(
                  height: 1.6,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
        ),
        actions: [
          UiButton(
            label: 'Acknowledge & Close',
            intent: UiIntent.primary,
            variant: UiVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSupport() async {
    if (_sending) return;
    final sub = _subjectController.text.trim();
    final msg = _msgController.text.trim();
    if (sub.isEmpty || msg.isEmpty) {
      UiToast.show(
        context,
        title: 'Missing Fields',
        message: 'Please provide both subject and message.',
        intent: UiIntent.warning,
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final submit = widget.submitTicket;
      if (submit == null) {
        throw StateError('Support ticket service is unavailable.');
      }
      await submit(_category, sub, msg);
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        UiToast.show(
          context,
          title: 'Ticket not sent',
          message:
              'Your message has been kept. Please retry when support is available.',
          intent: UiIntent.warning,
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _subjectController.clear();
        _msgController.clear();
        _sending = false;
      });
      UiToast.show(
        context,
        title: 'Message Sent',
        message: 'Your support message was accepted.',
        intent: UiIntent.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final isMobile = context.uiRes.isMobile;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contact Support Form
              AppSettingsSectionBlock(
                title: 'Contact Support & Desk Assistance',
                description: widget.submitTicket == null
                    ? 'Ticket delivery is not connected in this environment. Support messages cannot be sent yet.'
                    : 'Have a question or encountering an issue? Send a direct message to our support team.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        UiField(
                          label: 'Inquiry Category',
                          child: UiSelect<String>(
                            value: _category,
                            options: _categories
                                .map(
                                  (c) => UiOption<String>(label: c, value: c),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _category = v);
                            },
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiField(
                          label: 'Subject',
                          child: UiInput(
                            value: _subjectController.text,
                            hintText: 'Brief summary of your question...',
                            onChanged: (v) => _subjectController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiField(
                          label: 'Message',
                          child: UiTextarea(
                            value: _msgController.text,
                            hintText:
                                'Detailed description of the issue or feature inquiry...',
                            rows: 4,
                            onChanged: (v) => _msgController.text = v,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: isMobile ? double.infinity : null,
                            child: UiButton(
                              label: widget.submitTicket == null
                                  ? 'Support unavailable'
                                  : 'Send Support Ticket',
                              intent: UiIntent.primary,
                              loading: _sending,
                              onPressed: widget.submitTicket == null
                                  ? null
                                  : _submitSupport,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Product Info & Links
              AppSettingsSectionBlock(
                title: 'Product Information & Legal',
                children: [
                  AppSettingCard(
                    title: 'Release Notes & Changelog',
                    description:
                        'See latest product features, market feed upgrades, and bug fixes.',
                    icon: Icons.history_edu_rounded,
                    control: UiButton(
                      label: 'View What\'s New',
                      variant: UiVariant.outline,
                      size: UiSize.sm,
                      onPressed: _showChangelogDialog,
                    ),
                  ),
                  AppSettingCard(
                    title: 'Terms of Service',
                    description:
                        'Review hejournal.in trading agreement and platform terms.',
                    icon: Icons.gavel_rounded,
                    control: UiButton(
                      label: 'Read Terms',
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      onPressed: () => _showLegalDialog(
                        'Terms of Service',
                        'hejournal.in is a financial analytics, journaling, and market simulation platform. All charts and signals are for educational and analysis purposes only and do not constitute registered investment advice.',
                      ),
                    ),
                  ),
                  AppSettingCard(
                    title: 'Privacy Policy',
                    description:
                        'Learn how hejournal.in encrypts and secures your financial trade logs.',
                    icon: Icons.privacy_tip_outlined,
                    control: UiButton(
                      label: 'Read Policy',
                      variant: UiVariant.ghost,
                      size: UiSize.sm,
                      onPressed: () => _showLegalDialog(
                        'Privacy Policy',
                        'Review your data visibility and export preferences in Privacy Settings. Only publish records you intend to share.',
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Version & Environment Info Card
              UiCard(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: context.sz(20),
                      color: colors.foregroundMuted,
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: context.uiText.bodyStrong,
                          ),
                          Text(
                            'Version 1.0.0 (Build 2026.08.1) · Production',
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'STABLE',
                      intent: UiIntent.bullish,
                      size: UiSize.xs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
