import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/data/app_session.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/update/app_update.dart';

import 'help_support_card.dart';

typedef HelpIssueUrlLauncher = Future<bool> Function(Uri uri);

/// Issue types aligned with `.github/ISSUE_TEMPLATE/` and `.github/ISSUE_GUIDE.md`.
enum HelpIssueCategory {
  bugReport(
    label: 'Bug report',
    description: 'General reproducible defect, crash, or unexpected behavior.',
    templateFile: 'bug.yml',
    titlePrefix: '[Bug]: ',
  ),
  frontendUi(
    label: 'UI, layout & accessibility',
    description: 'Mobile/desktop layout, dock, theme, or accessibility defect.',
    templateFile: 'frontend_ui.yml',
    titlePrefix: '[UI]: ',
  ),
  authIdentity(
    label: 'Account & sign-in',
    description: 'Login, OTP, session restore, or cross-subdomain sign-in.',
    templateFile: 'auth_identity.yml',
    titlePrefix: '[Auth]: ',
  ),
  billingEntitlements(
    label: 'Plans & billing',
    description: 'Free, Basic, or Pro subscriptions, checkout, or plan access.',
    templateFile: 'billing_entitlements.yml',
    titlePrefix: '[Billing]: ',
  ),
  marketData(
    label: 'Market data',
    description: 'World Indices, Assets, quotes, screeners, or news feeds.',
    templateFile: 'market_data.yml',
    titlePrefix: '[Market]: ',
  ),
  aiCopilot(
    label: 'AI & copilot',
    description: 'Unified AI responses, research tools, or streaming errors.',
    templateFile: 'ai_copilot.yml',
    titlePrefix: '[AI]: ',
  ),
  communityMessages(
    label: 'Community & messages',
    description: 'Community posts, profiles, comments, or private messaging.',
    templateFile: 'community_messages.yml',
    titlePrefix: '[Community]: ',
  ),
  mobileLinks(
    label: 'Mobile, PWA & links',
    description: 'Android/iOS/PWA install, deep links, or push notifications.',
    templateFile: 'mobile_links.yml',
    titlePrefix: '[Mobile]: ',
  ),
  performance(
    label: 'Performance',
    description: 'Slow loading, scroll jank, memory usage, or repeated calls.',
    templateFile: 'performance.yml',
    titlePrefix: '[Perf]: ',
  ),
  featureRequest(
    label: 'Feature request',
    description: 'Suggest a new capability or product improvement.',
    templateFile: 'feature_request.yml',
    titlePrefix: '[Feature]: ',
    isFeatureOrDocs: true,
  ),
  documentation(
    label: 'Documentation',
    description: 'Report missing, unclear, or outdated help guides or policies.',
    templateFile: 'documentation.yml',
    titlePrefix: '[Docs]: ',
    isFeatureOrDocs: true,
  ),
  securityVulnerability(
    label: 'Security vulnerability (Private)',
    description:
        'Exploitable vulnerability, auth/payment bypass, or data exposure.',
    templateFile: null,
    titlePrefix: '[Security]: ',
    isPrivateSecurity: true,
  );

  const HelpIssueCategory({
    required this.label,
    required this.description,
    required this.templateFile,
    required this.titlePrefix,
    this.isFeatureOrDocs = false,
    this.isPrivateSecurity = false,
  });

  final String label;
  final String description;
  final String? templateFile;
  final String titlePrefix;
  final bool isFeatureOrDocs;
  final bool isPrivateSecurity;
}

/// Sanitized runtime context safe to include in a public bug report.
///
/// Intentionally excludes user IDs, emails, handles, auth tokens, cookies,
/// payment details, and private user records.
@immutable
class SanitizedIssueEnvironment {
  const SanitizedIssueEnvironment({
    required this.surface,
    required this.version,
    required this.viewport,
    required this.themeSummary,
    required this.tierLabel,
  });

  final String surface;
  final String version;
  final String viewport;
  final String themeSummary;
  final String tierLabel;

  String get singleLineSummary =>
      '$surface · $viewport · Theme: $themeSummary · Tier: $tierLabel';

  String get markdownBlock =>
      '- Surface: $surface\n'
      '- Version: $version\n'
      '- Viewport: $viewport\n'
      '- Theme: $themeSummary\n'
      '- Account tier: $tierLabel';
}

/// Utilities for building sanitized GitHub issue URLs, email reports, and
/// secret-leak checks in line with `.github/ISSUE_GUIDE.md`.
class HelpIssueReportBuilder {
  HelpIssueReportBuilder._();

  static const String repositorySlug = 'NK2552003/TradeX';

  static final Uri issueChooserUri = Uri.https(
    'github.com',
    '/$repositorySlug/issues/new/choose',
  );

  static final Uri privateSecurityAdvisoryUri = Uri.https(
    'github.com',
    '/$repositorySlug/security/advisories/new',
  );

  static const List<String> frequencyOptions = <String>[
    'Always',
    'Often',
    'Intermittent',
    'Once',
    'Unknown',
  ];

  static final List<RegExp> _sensitivePatterns = <RegExp>[
    // JWT tokens (header.payload.signature)
    RegExp(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),
    // Authorization bearer headers
    RegExp(r'bearer\s+[A-Za-z0-9._~+/-]{12,}', caseSensitive: false),
    // Common API / secret key prefixes
    RegExp(r'\b(?:sk-|rzp_live_|sbp_|ghp_|gho_|github_pat_)[A-Za-z0-9_-]{8,}'),
    // Explicit password or OTP credentials
    RegExp(r'\b(?:password|passwd|otp|passcode)\s*[:=]\s*\S{4,}', caseSensitive: false),
  ];

  /// Returns true if [text] looks like it contains raw tokens or credentials.
  static bool containsPotentialSecret(String text) {
    if (text.trim().isEmpty) return false;
    return _sensitivePatterns.any((RegExp pattern) => pattern.hasMatch(text));
  }

  /// Resolves the GitHub issue form `surface` dropdown label for the current platform.
  static String currentSurfaceLabel() {
    if (kIsWeb) return 'Web/PWA';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Multiple platforms',
    };
  }

  /// Builds a safe, PII-free environment snapshot from context and build info.
  static SanitizedIssueEnvironment captureEnvironment(
    BuildContext context, {
    AppBuildIdentity? identity,
  }) {
    final Size size = MediaQuery.sizeOf(context);
    final UiResponsive r = context.uiRes;
    final String deviceClass = r.isMobile
        ? 'Mobile'
        : (r.isTablet ? 'Tablet' : 'Desktop');
    final String viewport =
        '$deviceClass (${size.width.round()}x${size.height.round()})';
    final AppThemeController? themeController = AppThemeController.maybeOf(
      context,
    );
    final String modeName = (themeController?.mode ?? ThemeMode.system).name;
    final String brightnessName =
        context.ui.brightness == Brightness.dark ? 'dark' : 'light';
    final AppTier tier = AppSession.instance.tier.value;
    final String tierLabel = switch (tier) {
      AppTier.free => 'Free',
      AppTier.premium => 'Basic',
      AppTier.enterprise => 'Pro',
    };
    return SanitizedIssueEnvironment(
      surface: currentSurfaceLabel(),
      version: identity?.displayVersion ?? 'Unknown',
      viewport: viewport,
      themeSummary: '$modeName ($brightnessName)',
      tierLabel: tierLabel,
    );
  }

  static String _truncate(String value, int maxLength) {
    final String trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength - 1)}…';
  }

  /// Builds a pre-filled GitHub Issue Form URI or the Private Security Advisory URI.
  static Uri buildGitHubIssueUri({
    required HelpIssueCategory category,
    required String summary,
    required String details,
    String expected = '',
    String actual = '',
    String frequency = 'Always',
    SanitizedIssueEnvironment? environment,
  }) {
    if (category.isPrivateSecurity || category.templateFile == null) {
      return privateSecurityAdvisoryUri;
    }

    final Map<String, String> params = <String, String>{
      'template': category.templateFile!,
      'title': _truncate('${category.titlePrefix}${summary.trim()}', 140),
    };

    if (category == HelpIssueCategory.featureRequest) {
      if (details.trim().isNotEmpty) {
        params['problem'] = _truncate(details, 600);
      }
      if (expected.trim().isNotEmpty) {
        params['outcome'] = _truncate(expected, 500);
      }
    } else if (category == HelpIssueCategory.documentation) {
      if (summary.trim().isNotEmpty) {
        params['summary'] = _truncate(summary, 200);
      }
      if (details.trim().isNotEmpty) {
        params['details'] = _truncate(details, 700);
      }
    } else {
      if (summary.trim().isNotEmpty) {
        params['summary'] = _truncate(summary, 200);
      }
      if (environment != null) {
        params['surface'] = environment.surface;
        params['version'] = environment.version;
        params['environment'] = environment.singleLineSummary;
      }
      if (details.trim().isNotEmpty) {
        params['steps'] = _truncate(details, 600);
      }
      if (expected.trim().isNotEmpty) {
        params['expected'] = _truncate(expected, 350);
      }
      if (actual.trim().isNotEmpty) {
        params['actual'] = _truncate(actual, 350);
      }
      if (frequencyOptions.contains(frequency)) {
        params['frequency'] = frequency;
      }
    }

    return Uri.https(
      'github.com',
      '/$repositorySlug/issues/new',
      params,
    );
  }

  /// Formats a clean Markdown report suitable for clipboard copy or email support.
  static String buildMarkdownReport({
    required HelpIssueCategory category,
    required String summary,
    required String details,
    String expected = '',
    String actual = '',
    String frequency = 'Always',
    SanitizedIssueEnvironment? environment,
  }) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('### ${category.label}')
      ..writeln('**Summary:** ${summary.trim()}')
      ..writeln();
    if (environment != null) {
      buffer
        ..writeln('**Environment (sanitized):**')
        ..writeln(environment.markdownBlock)
        ..writeln();
    }
    buffer
      ..writeln(
        category.isFeatureOrDocs
            ? '**Details / Problem:**'
            : '**Steps to reproduce:**',
      )
      ..writeln(details.trim())
      ..writeln();
    if (expected.trim().isNotEmpty) {
      buffer
        ..writeln(
          category.isFeatureOrDocs
              ? '**Proposed outcome:**'
              : '**Expected behavior:**',
        )
        ..writeln(expected.trim())
        ..writeln();
    }
    if (!category.isFeatureOrDocs && actual.trim().isNotEmpty) {
      buffer
        ..writeln('**Actual behavior:**')
        ..writeln(actual.trim())
        ..writeln();
    }
    if (!category.isFeatureOrDocs && !category.isPrivateSecurity) {
      buffer.writeln('**Frequency:** $frequency');
    }
    return buffer.toString().trim();
  }

  /// Builds a pre-filled `mailto:` URI targeting AlphaJournal support.
  static Uri buildEmailReportUri({
    required HelpIssueCategory category,
    required String summary,
    required String details,
    String expected = '',
    String actual = '',
    String frequency = 'Always',
    SanitizedIssueEnvironment? environment,
  }) {
    final String subject =
        'AlphaJournal ${category.label}: ${summary.trim()}';
    final String body = buildMarkdownReport(
      category: category,
      summary: summary,
      details: details,
      expected: expected,
      actual: actual,
      frequency: frequency,
      environment: environment,
    );
    return Uri(
      scheme: 'mailto',
      path: HelpSupportCard.email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
  }
}

/// Help & Support section entry point for reporting bugs, requesting features,
/// and routing sensitive vulnerabilities to private security advisories.
class HelpIssueReportCard extends StatefulWidget {
  const HelpIssueReportCard({
    super.key,
    this.onLaunchUrl,
    this.updateService,
  });

  final HelpIssueUrlLauncher? onLaunchUrl;
  final AppUpdateService? updateService;

  @override
  State<HelpIssueReportCard> createState() => _HelpIssueReportCardState();
}

class _HelpIssueReportCardState extends State<HelpIssueReportCard> {
  String? _feedback;

  Future<bool> _launchExternal(Uri uri) async {
    if (widget.onLaunchUrl != null) {
      return widget.onLaunchUrl!(uri);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openIssueChooser() async {
    try {
      final bool launched = await _launchExternal(
        HelpIssueReportBuilder.issueChooserUri,
      );
      if (!launched) throw StateError('Unable to launch issue chooser');
      if (mounted) {
        setState(
          () => _feedback =
              'Opened the AlphaJournal issue template chooser in your browser.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _feedback =
              'Could not open a browser window. Use "Report a bug or issue" above to copy a sanitized report.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiSpacing spacing = context.ui.spacing;
    return AppSettingsSectionBlock(
      title: 'Report a bug or issue',
      description:
          'File a reproducible bug report, suggest a feature, or report a security issue confidentially.',
      children: <Widget>[
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Reports automatically attach sanitized version, platform, viewport, and theme context so bugs can be reproduced quickly — never account secrets or private data.',
                style: context.uiText.body,
              ),
              UiGap.v(spacing.md),
              UiButton(
                label: 'Report a bug or issue',
                leadingIcon: Icons.bug_report_outlined,
                expand: true,
                onPressed: () => ReportIssueDialog.show(
                  context,
                  initialCategory: HelpIssueCategory.bugReport,
                  onLaunchUrl: widget.onLaunchUrl,
                  updateService: widget.updateService,
                ),
              ),
              UiGap.v(spacing.sm),
              UiButton(
                label: 'Request a feature',
                leadingIcon: Icons.lightbulb_outline_rounded,
                variant: UiVariant.outline,
                expand: true,
                onPressed: () => ReportIssueDialog.show(
                  context,
                  initialCategory: HelpIssueCategory.featureRequest,
                  onLaunchUrl: widget.onLaunchUrl,
                  updateService: widget.updateService,
                ),
              ),
              UiGap.v(spacing.sm),
              UiButton(
                label: 'Report a security vulnerability',
                leadingIcon: Icons.shield_outlined,
                variant: UiVariant.outline,
                expand: true,
                onPressed: () => ReportIssueDialog.show(
                  context,
                  initialCategory: HelpIssueCategory.securityVulnerability,
                  onLaunchUrl: widget.onLaunchUrl,
                  updateService: widget.updateService,
                ),
              ),
              UiGap.v(spacing.sm),
              UiButton(
                label: 'Browse all issue templates',
                leadingIcon: Icons.open_in_new_rounded,
                variant: UiVariant.ghost,
                expand: true,
                onPressed: _openIssueChooser,
              ),
              if (_feedback != null) ...<Widget>[
                UiGap.v(spacing.sm),
                UiCallout(title: 'Issue tracker', message: _feedback!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Interactive dialog for creating sanitized bug reports, feature requests,
/// or opening a private security advisory.
class ReportIssueDialog extends StatefulWidget {
  const ReportIssueDialog({
    super.key,
    this.initialCategory = HelpIssueCategory.bugReport,
    this.onLaunchUrl,
    this.updateService,
  });

  final HelpIssueCategory initialCategory;
  final HelpIssueUrlLauncher? onLaunchUrl;
  final AppUpdateService? updateService;

  static Future<void> show(
    BuildContext context, {
    HelpIssueCategory initialCategory = HelpIssueCategory.bugReport,
    HelpIssueUrlLauncher? onLaunchUrl,
    AppUpdateService? updateService,
  }) async {
    await UiDialog.show<void>(
      context,
      maxWidth: 560,
      pinFooter: true,
      blurBackdrop: true,
      child: ReportIssueDialog(
        initialCategory: initialCategory,
        onLaunchUrl: onLaunchUrl,
        updateService: updateService,
      ),
    );
  }

  @override
  State<ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<ReportIssueDialog> {
  final TextEditingController _summary = TextEditingController();
  final TextEditingController _details = TextEditingController();
  final TextEditingController _expected = TextEditingController();
  final TextEditingController _actual = TextEditingController();

  late HelpIssueCategory _category = widget.initialCategory;
  String _frequency = 'Always';
  bool _includeEnvironment = true;
  bool _submitting = false;
  AppBuildIdentity? _identity;
  String? _feedback;
  UiIntent _feedbackIntent = UiIntent.info;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    try {
      final AppUpdateService service =
          widget.updateService ?? AppUpdateService.instance;
      final AppBuildIdentity identity = await service.currentIdentity();
      if (mounted) setState(() => _identity = identity);
    } catch (_) {
      // Keep fallback version when build identity is unavailable.
    }
  }

  @override
  void dispose() {
    _summary.dispose();
    _details.dispose();
    _expected.dispose();
    _actual.dispose();
    super.dispose();
  }

  Future<bool> _launch(Uri uri) async {
    if (widget.onLaunchUrl != null) {
      return widget.onLaunchUrl!(uri);
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _validateForm({required bool checkPublicSecrets}) {
    if (_summary.text.trim().isEmpty || _details.text.trim().isEmpty) {
      setState(() {
        _feedbackIntent = UiIntent.warning;
        _feedback = _category.isFeatureOrDocs
            ? 'Please enter a summary and details before continuing.'
            : 'Please enter a concise summary and steps to reproduce before continuing.';
      });
      return false;
    }
    if (checkPublicSecrets) {
      final String combined =
          '${_summary.text}\n${_details.text}\n${_expected.text}\n${_actual.text}';
      if (HelpIssueReportBuilder.containsPotentialSecret(combined)) {
        setState(() {
          _feedbackIntent = UiIntent.warning;
          _feedback =
              'Possible secret, token, or password detected. Remove sensitive credentials before submitting a public issue, or switch to Security vulnerability (Private).';
        });
        return false;
      }
    }
    return true;
  }

  SanitizedIssueEnvironment? _resolveEnvironment(BuildContext context) {
    if (!_includeEnvironment) return null;
    return HelpIssueReportBuilder.captureEnvironment(
      context,
      identity: _identity,
    );
  }

  Future<void> _openSecurityAdvisory() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _feedback = null;
    });
    try {
      final bool launched = await _launch(
        HelpIssueReportBuilder.privateSecurityAdvisoryUri,
      );
      if (!launched) throw StateError('Security advisory unavailable');
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.success;
          _feedback =
              'Opened the private GitHub Security Advisory form. Submit confidential details there.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.warning;
          _feedback =
              'Could not open a browser window. Visit github.com/${HelpIssueReportBuilder.repositorySlug}/security/advisories/new directly.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openGitHubIssue(BuildContext context) async {
    if (_submitting) return;
    if (!_validateForm(checkPublicSecrets: true)) return;
    setState(() {
      _submitting = true;
      _feedback = null;
    });
    try {
      final Uri uri = HelpIssueReportBuilder.buildGitHubIssueUri(
        category: _category,
        summary: _summary.text,
        details: _details.text,
        expected: _expected.text,
        actual: _actual.text,
        frequency: _frequency,
        environment: _resolveEnvironment(context),
      );
      final bool launched = await _launch(uri);
      if (!launched) throw StateError('Browser unavailable');
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.success;
          _feedback =
              'Opened a pre-filled GitHub issue form. Review the fields and submit it in your browser.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.warning;
          _feedback =
              'Could not open GitHub in a browser. Your report has been kept — copy or email it instead.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _emailReport(BuildContext context) async {
    if (_submitting) return;
    if (!_validateForm(checkPublicSecrets: false)) return;
    setState(() {
      _submitting = true;
      _feedback = null;
    });
    try {
      final Uri uri = HelpIssueReportBuilder.buildEmailReportUri(
        category: _category,
        summary: _summary.text,
        details: _details.text,
        expected: _expected.text,
        actual: _actual.text,
        frequency: _frequency,
        environment: _resolveEnvironment(context),
      );
      final bool launched = await _launch(uri);
      if (!launched) throw StateError('Email unavailable');
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.success;
          _feedback = 'Opened your email app with the sanitized report draft.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.warning;
          _feedback =
              'Could not open an email app. Use "Copy sanitized report" and send it to ${HelpSupportCard.email}.';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copyReport(BuildContext context) async {
    if (!_validateForm(checkPublicSecrets: true)) return;
    final String report = HelpIssueReportBuilder.buildMarkdownReport(
      category: _category,
      summary: _summary.text,
      details: _details.text,
      expected: _expected.text,
      actual: _actual.text,
      frequency: _frequency,
      environment: _resolveEnvironment(context),
    );
    try {
      await Clipboard.setData(ClipboardData(text: report));
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.success;
          _feedback = 'Sanitized report copied to clipboard.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedbackIntent = UiIntent.warning;
          _feedback = 'Clipboard copy is unavailable on this device.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiSpacing spacing = theme.spacing;
    final SanitizedIssueEnvironment env =
        HelpIssueReportBuilder.captureEnvironment(
          context,
          identity: _identity,
        );
    final bool isPrivateSecurity = _category.isPrivateSecurity;
    final bool isFeatureOrDocs = _category.isFeatureOrDocs;

    return UiDialog(
      icon: isPrivateSecurity
          ? Icons.shield_outlined
          : Icons.bug_report_outlined,
      intent: isPrivateSecurity ? UiIntent.warning : UiIntent.primary,
      title: isPrivateSecurity
          ? 'Report a security vulnerability'
          : (isFeatureOrDocs ? _category.label : 'Report a bug or issue'),
      description: _category.description,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiSelect<HelpIssueCategory>(
            key: const ValueKey<String>('report-issue-category'),
            label: 'Issue type',
            value: _category,
            options: <UiOption<HelpIssueCategory>>[
              for (final HelpIssueCategory option in HelpIssueCategory.values)
                UiOption<HelpIssueCategory>(
                  label: option.label,
                  value: option,
                ),
            ],
            onChanged: (HelpIssueCategory value) => setState(() {
              _category = value;
              _feedback = null;
            }),
          ),
          UiGap.v(spacing.md),
          if (isPrivateSecurity)
            const UiCallout(
              intent: UiIntent.warning,
              title: 'Confidential disclosure required',
              message:
                  'Do not post exploitable vulnerabilities, leaked credentials, authorization or payment bypasses, or private-data exposure in public issues. Submit them privately through a GitHub Security Advisory.',
            )
          else ...<Widget>[
            const UiCallout(
              intent: UiIntent.info,
              title: 'Keep reports sanitized',
              message:
                  'Never include passwords, OTPs, auth tokens, cookies, payment details, or private messages.',
            ),
            UiGap.v(spacing.md),
            UiInput(
              key: const ValueKey<String>('report-issue-summary'),
              controller: _summary,
              label: 'Summary',
              hintText: isFeatureOrDocs
                  ? 'Short title for your suggestion or doc fix'
                  : 'What is broken?',
              enabled: !_submitting,
            ),
            UiGap.v(spacing.sm),
            UiInput(
              key: const ValueKey<String>('report-issue-details'),
              controller: _details,
              label: isFeatureOrDocs ? 'Details' : 'Steps to reproduce',
              hintText: isFeatureOrDocs
                  ? 'Describe the problem or improvement and why it helps.'
                  : '1. Open…\n2. Tap…\n3. Observe…',
              maxLines: 4,
              enabled: !_submitting,
            ),
            UiGap.v(spacing.sm),
            UiInput(
              key: const ValueKey<String>('report-issue-expected'),
              controller: _expected,
              label: isFeatureOrDocs ? 'Proposed outcome' : 'Expected behavior',
              hintText: isFeatureOrDocs
                  ? 'What should the user see or be able to do?'
                  : 'What did you expect to happen?',
              maxLines: 2,
              enabled: !_submitting,
            ),
            if (!isFeatureOrDocs) ...<Widget>[
              UiGap.v(spacing.sm),
              UiInput(
                key: const ValueKey<String>('report-issue-actual'),
                controller: _actual,
                label: 'Actual behavior',
                hintText: 'What happened instead?',
                maxLines: 2,
                enabled: !_submitting,
              ),
              UiGap.v(spacing.sm),
              UiSelect<String>(
                key: const ValueKey<String>('report-issue-frequency'),
                label: 'Frequency',
                value: _frequency,
                options: <UiOption<String>>[
                  for (final String value
                      in HelpIssueReportBuilder.frequencyOptions)
                    UiOption<String>(label: value, value: value),
                ],
                onChanged: (String value) => setState(() => _frequency = value),
              ),
            ],
            UiGap.v(spacing.md),
            UiSwitch(
              key: const ValueKey<String>('report-issue-include-env'),
              label: 'Include sanitized device & app info',
              description:
                  'Adds app version, platform, viewport size, theme mode, and plan tier (no account ID or email).',
              value: _includeEnvironment,
              onChanged: _submitting
                  ? null
                  : (bool value) => setState(() => _includeEnvironment = value),
            ),
            if (_includeEnvironment) ...<Widget>[
              UiGap.v(spacing.xs),
              UiCard(
                variant: UiCardVariant.subtle,
                padding: EdgeInsets.all(context.sp(spacing.sm)),
                child: Text(
                  env.markdownBlock,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ],
          if (_feedback != null) ...<Widget>[
            UiGap.v(spacing.sm),
            UiCallout(
              title: isPrivateSecurity ? 'Security disclosure' : 'Report',
              message: _feedback!,
              intent: _feedbackIntent,
            ),
          ],
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiDivider(spacing: spacing.sm),
          if (isPrivateSecurity)
            UiButton(
              key: const ValueKey<String>('report-issue-security-submit'),
              label: 'Open private security advisory',
              leadingIcon: Icons.shield_outlined,
              expand: true,
              loading: _submitting,
              onPressed: _submitting ? null : _openSecurityAdvisory,
            )
          else ...<Widget>[
            UiButton(
              key: const ValueKey<String>('report-issue-github-submit'),
              label: 'Open GitHub issue',
              leadingIcon: Icons.open_in_new_rounded,
              expand: true,
              loading: _submitting,
              onPressed: _submitting ? null : () => _openGitHubIssue(context),
            ),
            UiGap.v(spacing.xs),
            UiButton(
              key: const ValueKey<String>('report-issue-email-submit'),
              label: 'Email report to support',
              leadingIcon: Icons.mail_outline_rounded,
              variant: UiVariant.outline,
              expand: true,
              onPressed: _submitting ? null : () => _emailReport(context),
            ),
            UiGap.v(spacing.xs),
            UiButton(
              key: const ValueKey<String>('report-issue-copy-submit'),
              label: 'Copy sanitized report',
              leadingIcon: Icons.copy_rounded,
              variant: UiVariant.ghost,
              expand: true,
              onPressed: _submitting ? null : () => _copyReport(context),
            ),
          ],
        ],
      ),
    );
  }
}
