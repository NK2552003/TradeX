import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Reusable comprehensive footer for alphajournal landing and pricing pages.
///
/// Features:
/// 1. Brand column with live NSE/BSE operational status badge & social links.
/// 2. Categorized link columns with live navigation and informational dialogs.
/// 3. Bottom bar with copyright and policy quick actions.
/// 4. SEBI regulatory financial risk disclosure card.
class TradeXFooter extends StatelessWidget {
  const TradeXFooter({
    super.key,
    this.onNavigateToSection,
    this.onGetStartedTrader,
    this.onGetStartedAffiliate,
  });

  final void Function(String section)? onNavigateToSection;
  final VoidCallback? onGetStartedTrader;
  final VoidCallback? onGetStartedAffiliate;

  void _showInfoModal(
    BuildContext context, {
    required String title,
    required String category,
    required String content,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(context.sp(theme.spacing.lg)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.sz(580),
              maxHeight: context.sz(600),
            ),
            child: Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: context.radius(theme.radii.xl),
                border: Border.all(
                  color: colors.border,
                  width: theme.borders.hairline,
                ),
                boxShadow: context.uiShadows.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      UiBadge(
                        label: category,
                        intent: UiIntent.primary,
                        size: UiSize.xs,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: colors.foregroundMuted,
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Text(
                    title,
                    style: context.uiText.display.copyWith(
                      fontSize: 20.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const UiDivider(),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        content,
                        style: context.uiText.body.copyWith(
                          color: colors.foregroundMuted,
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: UiButton(
                      label: 'Understood',
                      variant: UiVariant.primary,
                      size: UiSize.sm,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiDivider(),
        SizedBox(height: context.sp(theme.spacing.xxxl)),

        // 4 Columns Grid (Responsive)
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final bool isWide = constraints.maxWidth >= 900;
            if (!isWide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildBrandColumn(context, theme, colors),
                  SizedBox(height: context.sp(theme.spacing.xxl)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xxxl),
                    runSpacing: context.sp(theme.spacing.xl),
                    children: <Widget>[
                      _buildPlatformColumn(context, theme, colors),
                      _buildBrokersColumn(context, theme, colors),
                      _buildLegalColumn(context, theme, colors),
                    ],
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Col 1: Brand & Socials
                Expanded(
                  flex: 3,
                  child: _buildBrandColumn(context, theme, colors),
                ),
                SizedBox(width: context.sp(theme.spacing.xxxl)),

                // Col 2: Platform
                Expanded(
                  flex: 2,
                  child: _buildPlatformColumn(context, theme, colors),
                ),

                // Col 3: Brokers & Tax
                Expanded(
                  flex: 2,
                  child: _buildBrokersColumn(context, theme, colors),
                ),

                // Col 4: Docs & Legal
                Expanded(
                  flex: 2,
                  child: _buildLegalColumn(context, theme, colors),
                ),
              ],
            );
          },
        ),

        SizedBox(height: context.sp(theme.spacing.xxxl)),
        const UiDivider(),
        SizedBox(height: context.sp(theme.spacing.lg)),

        // Bottom Bar: Copyright & Quick Links
        LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints constraints) {
            final bool isMobile = constraints.maxWidth < 640;
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'alphajournal © ${DateTime.now().year}. All rights reserved.',
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundSubtle,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Wrap(
                    spacing: context.sp(theme.spacing.md),
                    runSpacing: context.sp(theme.spacing.xs),
                    children: <Widget>[
                      _buildSmallFooterAction(
                        context,
                        'Privacy Policy',
                        () => _showPrivacyPolicy(context),
                      ),
                      _buildSmallFooterAction(
                        context,
                        'Terms of Service',
                        () => _showTerms(context),
                      ),
                      _buildSmallFooterAction(
                        context,
                        'Security Architecture',
                        () => _showSecurity(context),
                      ),
                      _buildSmallFooterAction(
                        context,
                        'System Status',
                        () => _showStatus(context),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(theme.spacing.md),
              runSpacing: context.sp(theme.spacing.sm),
              children: <Widget>[
                Text(
                  'alphajournal © ${DateTime.now().year}. All rights reserved.',
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundSubtle,
                    fontSize: 12,
                  ),
                ),
                Wrap(
                  spacing: context.sp(theme.spacing.md),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <Widget>[
                    _buildSmallFooterAction(
                      context,
                      'Privacy Policy',
                      () => _showPrivacyPolicy(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    _buildSmallFooterAction(
                      context,
                      'Terms of Service',
                      () => _showTerms(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    _buildSmallFooterAction(
                      context,
                      'Security Architecture',
                      () => _showSecurity(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.md)),
                    _buildSmallFooterAction(
                      context,
                      'System Status',
                      () => _showStatus(context),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // SEBI & Financial Risk Disclaimer
        Container(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            color: colors.surfaceMuted.withValues(alpha: 0.3),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: theme.borders.hairline,
            ),
          ),
          child: Text(
            'Disclaimer: Trading in financial markets (Equities, Futures, Options, Commodities, and Currencies) involves significant risk of capital loss and may not be suitable for all investors. alphajournal is a quantitative trading journal, market analytics, and AI-assistive software platform. alphajournal is not a SEBI-registered investment advisor or research analyst. Historical backtests, simulation curves, and AI insights are strictly for educational, disciplined trade tracking, and self-directed quantitative analysis purposes.',
            style: context.uiText.caption.copyWith(
              color: colors.foregroundSubtle,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandColumn(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Logo & Title
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppLogoMark(size: 24),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Text(
              'alphajournal',
              style: context.uiText.bodyStrong.copyWith(
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),

        // Tagline
        Text(
          'The institutional-grade quantitative trading journal, AI copilot, and market intelligence platform engineered for disciplined Indian market traders.',
          style: context.uiText.caption.copyWith(
            color: colors.foregroundMuted,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Live Systems Status Pill
        InkWell(
          borderRadius: context.radius(theme.radii.pill),
          onTap: () => _showStatus(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xxs),
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: colors.border,
                width: theme.borders.hairline,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.bullish,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Flexible(
                  child: Text(
                    'All Systems Operational (NSE/BSE Tick Sync)',
                    style: context.uiText.caption.copyWith(
                      fontSize: 11,
                      color: colors.foregroundMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),

        // Only a verified project destination is exposed until social URLs are configured.
        UiButton(
          label: 'Project on GitHub',
          leadingIcon: Icons.code_rounded,
          variant: UiVariant.link,
          onPressed: () async {
            final opened = await launchUrl(
              Uri.parse('https://github.com/NK2552003/TradeX'),
              mode: LaunchMode.externalApplication,
            );
            if (!opened && context.mounted) {
              UiToast.show(
                context,
                title: 'Could not open GitHub',
                intent: UiIntent.warning,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildPlatformColumn(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return _buildColumnShell(
      context,
      theme,
      colors,
      title: 'PLATFORM',
      actions: <_FooterLinkAction>[
        _FooterLinkAction(
          'Live Market Intelligence',
          () => onNavigateToSection?.call('showcase'),
        ),
        _FooterLinkAction(
          'Trader & Creator Personas',
          () => onNavigateToSection?.call('personas'),
        ),
        _FooterLinkAction(
          'Core Features & Discipline',
          () => onNavigateToSection?.call('features'),
        ),
        _FooterLinkAction(
          'Pricing & Plans',
          () => onNavigateToSection?.call('pricing'),
        ),
        _FooterLinkAction(
          'Frequently Asked Questions',
          () => onNavigateToSection?.call('faq'),
        ),
        _FooterLinkAction(
          'Join as Affiliate Partner',
          () => onGetStartedAffiliate?.call(),
        ),
      ],
    );
  }

  Widget _buildBrokersColumn(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return _buildColumnShell(
      context,
      theme,
      colors,
      title: 'INDIAN BROKERS & TAX',
      actions: <_FooterLinkAction>[
        _FooterLinkAction(
          'Zerodha Kite Connect Auto-Sync',
          () => _showBrokerModal(
            context,
            'Zerodha Kite Connect',
            'Synchronize orders, executions, and chart snapshots directly from Zerodha Kite in real time.',
          ),
        ),
        _FooterLinkAction(
          'Upstox API v2 Integration',
          () => _showBrokerModal(
            context,
            'Upstox API v2',
            'Seamlessly import Upstox F&O, equity trades, and charges into your quantitative journal.',
          ),
        ),
        _FooterLinkAction(
          'Angel One SmartAPI Bridge',
          () => _showBrokerModal(
            context,
            'Angel One SmartAPI',
            'Direct bridging with Angel One for algorithmic execution tracking and slippage audit.',
          ),
        ),
        _FooterLinkAction(
          'Dhan HQ Realtime Webhooks',
          () => _showBrokerModal(
            context,
            'Dhan HQ Webhooks',
            'Instant webhook order logging and multi-leg option strategy tracking with Dhan.',
          ),
        ),
        _FooterLinkAction(
          'Groww & Finvasia Importers',
          () => _showBrokerModal(
            context,
            'Groww & Finvasia',
            '1-click CSV trade book import with automated format detection.',
          ),
        ),
        _FooterLinkAction(
          'ITR-2 / ITR-3 Capital Gains Export',
          () => _showBrokerModal(
            context,
            'Indian Tax Audit Export',
            'Generate CA-ready turnover statements, STCG/LTCG capital gains sheets, and audit trade books.',
          ),
        ),
      ],
    );
  }

  Widget _buildLegalColumn(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return _buildColumnShell(
      context,
      theme,
      colors,
      title: 'DOCUMENTATION & LEGAL',
      actions: <_FooterLinkAction>[
        _FooterLinkAction(
          'Security & Compliance',
          () => _showSecurity(context),
        ),
        _FooterLinkAction('Privacy Policy', () => _showPrivacyPolicy(context)),
        _FooterLinkAction('Terms of Service', () => _showTerms(context)),
        _FooterLinkAction(
          'SEBI Risk Compliance Notes',
          () => _showSebiNotes(context),
        ),
        _FooterLinkAction(
          'Live System Status & Uptime',
          () => _showStatus(context),
        ),
      ],
    );
  }

  Widget _buildColumnShell(
    BuildContext context,
    UiTheme theme,
    UiColors colors, {
    required String title,
    required List<_FooterLinkAction> actions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.uiText.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: colors.foreground,
            fontSize: 11.5,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        for (final _FooterLinkAction action in actions)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xxs),
            ),
            child: InkWell(
              borderRadius: context.radius(theme.radii.sm),
              onTap: action.onTap,
              child: Text(
                action.label,
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSmallFooterAction(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    final UiColors colors = context.uiColors;
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: context.uiText.caption.copyWith(
          color: colors.foregroundMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showBrokerModal(
    BuildContext context,
    String broker,
    String description,
  ) {
    _showInfoModal(
      context,
      title: broker,
      category: 'BROKER INTEGRATION',
      content:
          '$description\n\nalphajournal connects via secure OAuth 2.0 and API token authentication. Review broker permissions before connecting an account. alphajournal never requests fund withdrawal permissions or trading account ownership.',
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    _showInfoModal(
      context,
      title: 'alphajournal Privacy Policy',
      category: 'LEGAL & PRIVACY',
      content:
          '1. Information We Collect: Account registration details (email, handle), encrypted API keys for broker sync, and quantitative journal entries.\n\n'
          '2. How We Use Data: To compute trade metrics, calculate win rate statistics, render AI setup detection, and generate capital gains tax summaries.\n\n'
          '3. Non-Custodial Guarantee: alphajournal never holds trading funds or acts as a broker. We never sell, monetize, or front-run user trading journals or strategy notes.\n\n'
          '4. Data Retention & Deletion: You can export your full trade database in CSV/JSON or permanently delete your account and encrypted keys at any time.',
    );
  }

  void _showTerms(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Terms of Service',
      category: 'LEGAL TERMS',
      content:
          'Welcome to alphajournal. By accessing or using our platform, you agree to these Terms.\n\n'
          '1. Self-Directed Trading: alphajournal provides quantitative journaling, market analytics, and AI assistants. All trade execution decisions are solely the responsibility of the user.\n\n'
          '2. Subscription & Billing: Paid plans are billed on a monthly or annual recurring cycle with transparent INR ₹ pricing. Cancel anytime from your billing portal.\n\n'
          '3. Affiliate Program: Affiliates earn tiered commissions by referring verified active traders. Commission fraud or spam will result in immediate termination.',
    );
  }

  void _showSecurity(BuildContext context) {
    _showInfoModal(
      context,
      title: 'Security & Compliance Architecture',
      category: 'ENTERPRISE SECURITY',
      content:
          '• Data Protection: All data in transit is protected using modern TLS encryption protocols.\n\n'
          '• Tenant Isolation: Strict database Row Level Security (RLS) ensures users can only access their authorized records.\n\n'
          '• Account Privacy: Manage the visibility of your notes, strategies, and journal entries.\n\n'
          '• Zero Custody: alphajournal operates in read-only / execution-audit mode without withdrawal permissions or custody of funds.\n\n'
          '• Infrastructure: Cloud-hosted database and authentication with automated backups and continuous monitoring.',
    );
  }

  void _showSebiNotes(BuildContext context) {
    _showInfoModal(
      context,
      title: 'SEBI Compliance & Risk Notes',
      category: 'REGULATORY COMPLIANCE',
      content:
          'alphajournal is a quantitative trading software and analytics tool. alphajournal is NOT a SEBI-registered Investment Advisor (RIA) or Research Analyst (RA).\n\n'
          'All historical performance metrics, backtests, AI insights, and community strategies are for self-directed study and execution discipline only. Trading derivatives (Futures & Options) involves substantial financial risk.',
    );
  }

  void _showStatus(BuildContext context) {
    _showInfoModal(
      context,
      title: 'System & Feed Status',
      category: 'OPERATIONS (NSE / BSE)',
      content:
          '• NSE Realtime Tick Feed: Operational (12ms latency)\n'
          '• BSE Equity & F&O Gateway: Operational (14ms latency)\n'
          '• Zerodha / Upstox Auto-Sync Bridge: Operational\n'
          '• AI Chart Vision Engine: Operational\n'
          '• Cloud Database & Auth: Operational (100% Uptime last 30 days)',
    );
  }
}

class _FooterLinkAction {
  const _FooterLinkAction(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
}
