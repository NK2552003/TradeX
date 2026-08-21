import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified primitive import for feature UI.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/affiliate_program/data/affiliate_application_repository.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_application_model.dart';
import 'package:tradex/features/auth/widgets/auth_step_icon.dart';

/// Shared affiliate application used after affiliate signup and when an
/// existing trader chooses to add the affiliate capability.
class AffiliateApplicationPage extends StatefulWidget {
  const AffiliateApplicationPage({
    super.key,
    required this.userId,
    required this.email,
    required this.displayName,
    this.isExistingCustomer = false,
    this.repository,
    this.onSubmitted,
    this.onDone,
    this.onCancel,
  });

  final String userId;
  final String email;
  final String displayName;
  final bool isExistingCustomer;
  final AffiliateApplicationRepository? repository;
  final ValueChanged<AffiliateApplicationModel>? onSubmitted;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  @override
  State<AffiliateApplicationPage> createState() =>
      _AffiliateApplicationPageState();
}

class _AffiliateApplicationPageState extends State<AffiliateApplicationPage> {
  late final AffiliateApplicationRepository _repository;
  int _step = 0;
  int _furthestStep = 0;
  bool _loadingExistingApplication = true;
  bool _phoneVerified = false;
  final bool _emailVerified = true;
  bool _termsAccepted = false;
  bool _submitting = false;
  AffiliateApplicationModel? _submitted;
  String? _error;

  late final TextEditingController _name;
  late final TextEditingController _email;
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _state = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;

  List<String> _platforms = <String>[];
  String? _primaryPlatform;
  final TextEditingController _channel = TextEditingController();
  String? _audienceReach;
  List<String> _niches = <String>[];
  final TextEditingController _sampleLink = TextEditingController();

  final TextEditingController _accountHolder = TextEditingController();
  String? _bankName;
  final TextEditingController _accountNumber = TextEditingController();
  final TextEditingController _confirmAccountNumber = TextEditingController();
  final TextEditingController _ifsc = TextEditingController();
  String? _accountType;
  final TextEditingController _pan = TextEditingController();
  final TextEditingController _upi = TextEditingController();

  static const List<String> _platformOptions = <String>[
    'Instagram',
    'YouTube',
    'X / Twitter',
    'Telegram',
    'Discord',
    'Blog / Website',
    'Offline community',
  ];
  static const List<String> _nicheOptions = <String>[
    'Trading education',
    'Technical analysis',
    'Personal finance',
    'Fintech',
    'Creator community',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? AffiliateApplicationRepositoryImpl.instance;
    _name = TextEditingController(text: widget.displayName);
    _email = TextEditingController(text: widget.email);
    _seedDesignPreviewIfRequested();
    _loadExistingApplication();
  }

  void _seedDesignPreviewIfRequested() {
    if (!kDebugMode) return;
    final int? requestedStep = int.tryParse(
      Uri.base.queryParameters['applicationStep'] ?? '',
    );
    if (requestedStep == null || requestedStep < 0 || requestedStep > 3) return;
    _phone.text = '9876543210';
    _phoneVerified = true;
    _city.text = 'Mumbai';
    _state.text = 'Maharashtra';
    _dateOfBirth = DateTime(1996, 4, 18);
    _gender = 'Prefer not to say';
    _platforms = <String>['YouTube', 'Instagram'];
    _primaryPlatform = 'YouTube';
    _channel.text = '@designtrades';
    _audienceReach = '10,000 – 100,000';
    _niches = <String>['Trading education', 'Personal finance'];
    _sampleLink.text = 'https://example.com/designtrades';
    _accountHolder.text = widget.displayName;
    _bankName = 'HDFC Bank';
    _accountNumber.text = '123456789012';
    _confirmAccountNumber.text = '123456789012';
    _ifsc.text = 'HDFC0001234';
    _accountType = 'Savings';
    _pan.text = 'ABCDE1234F';
    _upi.text = 'design@upi';
    _termsAccepted = requestedStep == 3;
    _step = requestedStep;
    _furthestStep = requestedStep;
  }

  Future<void> _loadExistingApplication() async {
    final AffiliateApplicationModel? existing = await _repository.getForUser(
      widget.userId,
    );
    if (!mounted) return;
    setState(() {
      if (existing != null &&
          existing.status != AffiliateApplicationStatus.draft &&
          existing.status != AffiliateApplicationStatus.rejected) {
        _submitted = existing;
      }
      _loadingExistingApplication = false;
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _email,
      _phone,
      _city,
      _state,
      _channel,
      _sampleLink,
      _accountHolder,
      _accountNumber,
      _confirmAccountNumber,
      _ifsc,
      _pan,
      _upi,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _personalValid {
    if (_name.text.trim().isEmpty ||
        !_emailVerified ||
        !_phoneVerified ||
        _phone.text.trim().length < 10 ||
        _city.text.trim().isEmpty ||
        _state.text.trim().isEmpty ||
        _dateOfBirth == null ||
        _gender == null) {
      return false;
    }
    final DateTime adultCutoff = DateTime(
      DateTime.now().year - 18,
      DateTime.now().month,
      DateTime.now().day,
    );
    return !_dateOfBirth!.isAfter(adultCutoff);
  }

  bool get _presenceValid =>
      _platforms.isNotEmpty &&
      _primaryPlatform != null &&
      _channel.text.trim().isNotEmpty &&
      _audienceReach != null &&
      _niches.isNotEmpty;

  bool get _payoutValid =>
      _accountHolder.text.trim().isNotEmpty &&
      _bankName != null &&
      _accountNumber.text.trim().length >= 8 &&
      _accountNumber.text.trim() == _confirmAccountNumber.text.trim() &&
      RegExp(
        r'^[A-Z]{4}0[A-Z0-9]{6}$',
      ).hasMatch(_ifsc.text.trim().toUpperCase()) &&
      _accountType != null &&
      RegExp(
        r'^[A-Z]{5}[0-9]{4}[A-Z]$',
      ).hasMatch(_pan.text.trim().toUpperCase()) &&
      (_upi.text.trim().isEmpty || _upi.text.contains('@'));

  void _next() {
    final bool valid = switch (_step) {
      0 => _personalValid,
      1 => _presenceValid,
      2 => _payoutValid,
      _ => true,
    };
    if (!valid) {
      setState(() {
        _error = switch (_step) {
          0 =>
            'Complete every required field, verify phone and email, and confirm that you are at least 18.',
          1 =>
            'Select your channels, primary audience, reach, and at least one content niche.',
          2 =>
            'Enter matching bank details, a valid IFSC and PAN, and review the optional UPI format.',
          _ => null,
        };
      });
      return;
    }
    setState(() {
      _error = null;
      _step = math.min(3, _step + 1);
      _furthestStep = math.max(_furthestStep, _step);
    });
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      setState(() => _error = 'Accept the Affiliate Program terms to submit.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final String id =
        'aff_app_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}';
    final AffiliateApplicationModel draft = AffiliateApplicationModel(
      id: id,
      userId: widget.userId,
      fullName: _name.text.trim(),
      email: _email.text.trim().toLowerCase(),
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      dateOfBirth: _dateOfBirth!,
      gender: _gender!,
      platforms: List<String>.unmodifiable(_platforms),
      primaryPlatform: _primaryPlatform!,
      channelHandle: _channel.text.trim(),
      audienceReach: _audienceReach!,
      niches: List<String>.unmodifiable(_niches),
      sampleLink: _sampleLink.text.trim().isEmpty
          ? null
          : _sampleLink.text.trim(),
      accountHolder: _accountHolder.text.trim(),
      bankName: _bankName!,
      accountNumber: _accountNumber.text.trim(),
      ifsc: _ifsc.text.trim().toUpperCase(),
      accountType: _accountType!,
      pan: _pan.text.trim().toUpperCase(),
      upiId: _upi.text.trim().isEmpty ? null : _upi.text.trim(),
    );
    try {
      final AffiliateApplicationModel submitted = await _repository.submit(
        draft,
      );
      if (!mounted) return;
      setState(() {
        _submitted = submitted;
        _submitting = false;
      });
      widget.onSubmitted?.call(submitted);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            'We could not submit the application. Your entries are still here—please try again.';
      });
    }
  }

  Widget _buildLoading(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(
                  responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
                ),
                vertical: context.sp(theme.spacing.xl),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight -
                      context.sp(theme.spacing.xl) * 2,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sz(680)),
                    child: const _ApplicationPageSkeleton(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;

    if (_loadingExistingApplication) {
      return _buildLoading(context);
    }
    if (_submitted != null) return _buildPending(context, _submitted!);

    final (IconData stepIcon, UiIntent stepIntent) = switch (_step) {
      0 => (Icons.person_outline_rounded, UiIntent.primary),
      1 => (Icons.campaign_outlined, UiIntent.info),
      2 => (Icons.account_balance_outlined, UiIntent.warning),
      _ => (Icons.fact_check_outlined, UiIntent.primary),
    };

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(
                  responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
                ),
                vertical: context.sp(theme.spacing.xl),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (viewportConstraints.maxHeight -
                          context.sp(theme.spacing.xl) * 2)
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sz(680)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UiCard(
                          variant: UiCardVariant.surface,
                          child: Padding(
                            padding: EdgeInsets.all(
                              context.sp(
                                responsive.isMobile
                                    ? theme.spacing.lg
                                    : theme.spacing.xl,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Unified Header inside Card: Back Button, Logo, TradeX & Step Badge
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget.onCancel != null)
                                            UiIconButton(
                                              icon: Icons.arrow_back_rounded,
                                              size: UiSize.sm,
                                              tooltip: widget.isExistingCustomer
                                                  ? 'Back to Workspace'
                                                  : 'Back to Sign in',
                                              onPressed: widget.onCancel,
                                            ),
                                          if (widget.onCancel != null)
                                            SizedBox(
                                              width: context.sp(theme.spacing.xs),
                                            ),
                                          const AppLogoMark(size: 20),
                                          if (!responsive.isMobile) ...[
                                            SizedBox(
                                              width: context.sp(theme.spacing.xs),
                                            ),
                                            Text(
                                              'TradeX',
                                              style: context.uiText.bodyStrong
                                                  .copyWith(
                                                fontSize: 16,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    UiBadge(
                                      label: 'STEP ${_step + 1} OF 4',
                                      intent: UiIntent.primary,
                                      variant: UiBadgeVariant.soft,
                                      size: UiSize.sm,
                                    ),
                                  ],
                                ),
                                if (!responsive.isMobile) ...[
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  UiStepper(
                                    steps: const [
                                      UiStepperStep(
                                        title: 'Personal',
                                        subtitle: 'Basic info',
                                      ),
                                      UiStepperStep(
                                        title: 'Presence',
                                        subtitle: 'Channels',
                                      ),
                                      UiStepperStep(
                                        title: 'Payout',
                                        subtitle: 'Bank details',
                                      ),
                                      UiStepperStep(
                                        title: 'Review',
                                        subtitle: 'Confirm',
                                      ),
                                    ],
                                    currentIndex: _step.clamp(0, 3),
                                  ),
                                ] else ...[
                                  SizedBox(
                                    height: context.sp(theme.spacing.lg),
                                  ),
                                  // Minimal Modern Segmented Step Indicator inside card on mobile
                                  Row(
                                    children: [
                                      for (int i = 0; i < 4; i++)
                                        Expanded(
                                          child: Container(
                                            height: 3.5,
                                            margin: EdgeInsets.only(
                                              right: i < 3 ? 6.0 : 0.0,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              color: i <= _step
                                                  ? colors.primary
                                                  : colors.borderStrong
                                                      .withValues(
                                                          alpha: 0.5),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                SizedBox(height: context.sp(theme.spacing.xl)),
                                AuthStepIcon(
                                  icon: stepIcon,
                                  intent: stepIntent,
                                ),
                                SizedBox(height: context.sp(theme.spacing.md)),
                                Text(
                                  widget.isExistingCustomer
                                      ? 'Add Affiliate Access'
                                      : 'Complete Affiliate Application',
                                  textAlign: TextAlign.center,
                                  style: context.uiText.display.copyWith(
                                    fontSize: 28.0,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.5,
                                  ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            'Your trading account remains active while the TradeX team reviews this application.',
                            textAlign: TextAlign.center,
                            style: context.uiText.body.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.lg)),
                          if (_error != null) ...[
                            UiCallout(
                              title: 'Check this step',
                              message: _error!,
                              intent: UiIntent.danger,
                            ),
                            SizedBox(height: context.sp(theme.spacing.md)),
                          ],
                          AnimatedSwitcher(
                            duration: theme.motion.normal,
                            child: KeyedSubtree(
                              key: ValueKey<int>(_step),
                              child: switch (_step) {
                                0 => _buildPersonal(context),
                                1 => _buildPresence(context),
                                2 => _buildPayout(context),
                                _ => _buildReview(context),
                              },
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.lg)),
                          Row(
                            children: <Widget>[
                              if (_step > 0)
                                Expanded(
                                  child: UiButton(
                                    label: 'Back',
                                    leadingIcon: Icons.arrow_back_rounded,
                                    variant: UiVariant.outline,
                                    intent: UiIntent.neutral,
                                    size: UiSize.lg,
                                    onPressed: () => setState(() {
                                      _error = null;
                                      _step--;
                                    }),
                                  ),
                                ),
                              if (_step > 0)
                                SizedBox(width: context.sp(theme.spacing.sm)),
                              Expanded(
                                child: UiButton(
                                  label: _step == 3
                                      ? (_submitting
                                          ? 'Submitting…'
                                          : 'Submit for Review')
                                      : 'Continue',
                                  trailingIcon: _step == 3
                                      ? null
                                      : Icons.arrow_forward_rounded,
                                  variant: UiVariant.primary,
                                  intent: UiIntent.primary,
                                  size: UiSize.lg,
                                  onPressed: _submitting
                                      ? null
                                      : (_step == 3 ? _submit : _next),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.md)),
                          Text(
                            'Approval adds affiliate tools to your existing account. Your trading workspace and customer access remain unchanged.',
                            textAlign: TextAlign.center,
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: context.sz(14),
                        color: colors.foregroundSubtle,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Flexible(
                        child: Text(
                          'Your data is encrypted end-to-end',
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundSubtle,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  },
),
),
);
  }

  Widget _buildPersonal(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Personal information',
          style: context.uiText.bodyStrong.copyWith(fontSize: 16),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          'Confirm the identity and contact details used for review.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'Full name',
            required: true,
            child: UiInput(
              controller: _name,
              hintText: 'Name on government ID',
            ),
          ),
          UiField(
            label: 'Email address',
            required: true,
            success: _emailVerified ? 'Verified during account setup' : null,
            child: UiInput(
              controller: _email,
              readOnly: true,
              validation: UiValidationState.valid,
              trailingIcon: Icons.verified_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'Phone number',
            required: true,
            success: _phoneVerified ? 'Phone verified' : null,
            child: UiInput(
              controller: _phone,
              prefixText: '+91 ',
              keyboardType: TextInputType.phone,
              maxLength: 10,
              onChanged: (_) => setState(() {
                if (_phoneVerified) _phoneVerified = false;
              }),
              trailing: UiIconButton(
                icon: _phoneVerified
                    ? Icons.verified_rounded
                    : Icons.sms_outlined,
                size: UiSize.xs,
                variant: _phoneVerified
                    ? UiVariant.success
                    : UiVariant.outline,
                tooltip: _phoneVerified
                    ? 'Phone verified'
                    : 'Send verification code',
                onPressed: _phone.text.trim().length == 10
                    ? () => setState(() => _phoneVerified = true)
                    : null,
              ),
            ),
          ),
          UiField(
            label: 'Date of birth',
            required: true,
            helper: 'Applicants must be at least 18 years old.',
            child: UiDatePicker(
              value: _dateOfBirth,
              firstDate: DateTime(1940),
              lastDate: DateTime.now(),
              onChanged: (DateTime date) =>
                  setState(() => _dateOfBirth = date),
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'City',
            required: true,
            child: UiInput(controller: _city, hintText: 'Mumbai'),
          ),
          UiField(
            label: 'State / region',
            required: true,
            child: UiInput(controller: _state, hintText: 'Maharashtra'),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiField(
          label: 'Gender',
          required: true,
          child: UiSelect<String>(
            value: _gender,
            hintText: 'Select an option',
            options: const <UiOption<String>>[
              UiOption<String>(value: 'Woman', label: 'Woman'),
              UiOption<String>(value: 'Man', label: 'Man'),
              UiOption<String>(value: 'Non-binary', label: 'Non-binary'),
              UiOption<String>(
                value: 'Prefer not to say',
                label: 'Prefer not to say',
              ),
            ],
            onChanged: (String value) => setState(() => _gender = value),
          ),
        ),
      ],
    );
  }

  Widget _buildPresence(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Audience and content presence',
          style: context.uiText.bodyStrong.copyWith(fontSize: 16),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          'Tell reviewers where and how you plan to introduce TradeX.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiField(
          label: 'Promotion channels',
          required: true,
          helper: 'Select all that apply.',
          child: UiToggleGroup<String>(
            options: _platformOptions
                .map(
                  (String item) =>
                      UiToggleOption<String>(value: item, label: item),
                )
                .toList(),
            multiple: true,
            values: _platforms,
            intent: UiIntent.primary,
            variant: UiToggleGroupVariant.pill,
            onValuesChanged: (List<String> values) => setState(() {
              _platforms = values;
              if (!_platforms.contains(_primaryPlatform)) {
                _primaryPlatform = values.isEmpty ? null : values.first;
              }
            }),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiField(
          label: 'Primary platform',
          required: true,
          child: UiSelect<String>(
            value: _primaryPlatform,
            hintText: _platforms.isEmpty
                ? 'Select promotion channels first'
                : 'Select primary channel',
            enabled: _platforms.isNotEmpty,
            options: _platforms
                .map(
                  (String item) => UiOption<String>(value: item, label: item),
                )
                .toList(),
            onChanged: (String value) =>
                setState(() => _primaryPlatform = value),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'Handle or channel URL',
            required: true,
            child: UiInput(
              controller: _channel,
              hintText: '@handle or https://channel.example',
            ),
          ),
          UiField(
            label: 'Audience size / reach',
            required: true,
            child: UiSelect<String>(
              value: _audienceReach,
              options: const <UiOption<String>>[
                UiOption<String>(value: 'Under 1,000', label: 'Under 1,000'),
                UiOption<String>(
                  value: '1,000 – 10,000',
                  label: '1,000 – 10,000',
                ),
                UiOption<String>(
                  value: '10,000 – 100,000',
                  label: '10,000 – 100,000',
                ),
                UiOption<String>(
                  value: 'More than 100,000',
                  label: 'More than 100,000',
                ),
              ],
              onChanged: (String value) =>
                  setState(() => _audienceReach = value),
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiField(
          label: 'Content niches',
          required: true,
          child: UiToggleGroup<String>(
            options: _nicheOptions
                .map(
                  (String item) =>
                      UiToggleOption<String>(value: item, label: item),
                )
                .toList(),
            multiple: true,
            values: _niches,
            intent: UiIntent.primary,
            variant: UiToggleGroupVariant.pill,
            onValuesChanged: (List<String> values) =>
                setState(() => _niches = values),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiField(
          label: 'Sample content link',
          optionalLabel: 'Optional',
          helper: 'A representative post, video, article, or community link.',
          child: UiInput(
            controller: _sampleLink,
            hintText: 'https://',
            keyboardType: TextInputType.url,
          ),
        ),
      ],
    );
  }

  Widget _buildPayout(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Payout and tax details',
          style: context.uiText.bodyStrong.copyWith(fontSize: 16),
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(
          'Used only after approval and encrypted by the backend.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        const UiCallout(
          title: 'Secure payout verification',
          message:
              'Bank and PAN details are collected for commission settlement and tax compliance. They are never shown on your public profile.',
          intent: UiIntent.info,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'Account holder name',
            required: true,
            child: UiInput(
              controller: _accountHolder,
              hintText: 'Name on bank account',
            ),
          ),
          UiField(
            label: 'Bank',
            required: true,
            child: UiSelect<String>(
              value: _bankName,
              searchable: true,
              options: const <UiOption<String>>[
                UiOption<String>(
                  value: 'State Bank of India',
                  label: 'State Bank of India',
                ),
                UiOption<String>(value: 'HDFC Bank', label: 'HDFC Bank'),
                UiOption<String>(value: 'ICICI Bank', label: 'ICICI Bank'),
                UiOption<String>(value: 'Axis Bank', label: 'Axis Bank'),
                UiOption<String>(
                  value: 'Kotak Mahindra',
                  label: 'Kotak Mahindra',
                ),
                UiOption<String>(value: 'Other bank', label: 'Other bank'),
              ],
              onChanged: (String value) => setState(() => _bankName = value),
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'Account number',
            required: true,
            child: UiInput(
              controller: _accountNumber,
              obscure: true,
              keyboardType: TextInputType.number,
            ),
          ),
          UiField(
            label: 'Confirm account number',
            required: true,
            error:
                _confirmAccountNumber.text.isNotEmpty &&
                    _confirmAccountNumber.text != _accountNumber.text
                ? 'Account numbers do not match.'
                : null,
            child: UiInput(
              controller: _confirmAccountNumber,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'IFSC code',
            required: true,
            helper: 'Example: HDFC0001234',
            child: UiInput(controller: _ifsc, maxLength: 11),
          ),
          UiField(
            label: 'Account type',
            required: true,
            child: UiSelect<String>(
              value: _accountType,
              options: const <UiOption<String>>[
                UiOption<String>(value: 'Savings', label: 'Savings'),
                UiOption<String>(value: 'Current', label: 'Current'),
              ],
              onChanged: (String value) =>
                  setState(() => _accountType = value),
            ),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _responsivePair(
          context,
          UiField(
            label: 'PAN number',
            required: true,
            helper: 'Example: ABCDE1234F',
            child: UiInput(controller: _pan, maxLength: 10),
          ),
          UiField(
            label: 'UPI ID',
            optionalLabel: 'Optional',
            child: UiInput(controller: _upi, hintText: 'name@upi'),
          ),
        ),
      ],
    );
  }

  Widget _buildReview(BuildContext context) {
    final UiTheme theme = context.ui;
    final responsive = context.uiRes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (responsive.isMobile)
          _buildMobileReviewTiles(context)
        else
          _buildDesktopReviewCards(context),
        SizedBox(height: context.sp(theme.spacing.md)),
        const UiCallout(
          title: 'Review and access policy',
          message:
              'Submitting does not grant immediate Partner Hub access. An administrator must approve the application first. You can continue using TradeX as a customer/trader while it is pending.',
          intent: UiIntent.warning,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCheckbox(
          value: _termsAccepted,
          asCard: true,
          label:
              'I confirm these details are accurate and accept the TradeX Affiliate Program terms.',
          description:
              'I understand that approval can be refused or suspended for policy violations.',
          onChanged: (bool value) => setState(() => _termsAccepted = value),
        ),
      ],
    );
  }

  Widget _buildMobileReviewTiles(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final sections = [
      (
        title: 'Personal',
        icon: Icons.badge_outlined,
        values: <String>[
          _name.text,
          _email.text,
          if (_phone.text.isNotEmpty) '+91 ${_phone.text}',
          if (_city.text.isNotEmpty || _state.text.isNotEmpty)
            '${_city.text}, ${_state.text}',
        ],
        onEdit: () => setState(() => _step = 0),
      ),
      (
        title: 'Presence',
        icon: Icons.campaign_outlined,
        values: <String>[
          _primaryPlatform ?? '',
          _channel.text,
          _audienceReach ?? '',
          if (_niches.isNotEmpty) _niches.join(', '),
        ],
        onEdit: () => setState(() => _step = 1),
      ),
      (
        title: 'Payout',
        icon: Icons.account_balance_outlined,
        values: <String>[
          _accountHolder.text,
          _bankName ?? '',
          if (_accountNumber.text.isNotEmpty)
            '•••• ${_accountNumber.text.length >= 4 ? _accountNumber.text.substring(_accountNumber.text.length - 4) : _accountNumber.text}',
          if (_ifsc.text.isNotEmpty)
            '${_ifsc.text.toUpperCase()} · ${_accountType ?? ''}',
        ],
        onEdit: () => setState(() => _step = 2),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(alpha: 0.35),
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: colors.border, width: theme.borders.hairline),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: colors.border,
              ),
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding:
                                EdgeInsets.all(context.sp(theme.spacing.xxs)),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.12),
                              borderRadius: context.radius(theme.radii.sm),
                            ),
                            child: Icon(
                              sections[i].icon,
                              size: context.sz(16),
                              color: colors.primary,
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Text(
                            sections[i].title,
                            style: context.uiText.bodyStrong.copyWith(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      UiButton(
                        label: 'Edit',
                        leadingIcon: Icons.edit_outlined,
                        variant: UiVariant.ghost,
                        size: UiSize.xs,
                        expandOnMobile: false,
                        onPressed: sections[i].onEdit,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Text(
                    sections[i]
                        .values
                        .where((v) => v.trim().isNotEmpty)
                        .join(' · '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: colors.foregroundMuted,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopReviewCards(BuildContext context) {
    final UiTheme theme = context.ui;

    final Widget personalCard = _reviewCard(
      context,
      'Personal',
      Icons.badge_outlined,
      <String>[
        _name.text,
        _email.text,
        '+91 ${_phone.text}',
        '${_city.text}, ${_state.text}',
      ],
      () => setState(() => _step = 0),
    );

    final Widget presenceCard = _reviewCard(
      context,
      'Presence',
      Icons.campaign_outlined,
      <String>[
        _primaryPlatform ?? '',
        _channel.text,
        _audienceReach ?? '',
        _niches.join(', '),
      ],
      () => setState(() => _step = 1),
    );

    final Widget payoutCard = _reviewCard(
      context,
      'Payout',
      Icons.account_balance_outlined,
      <String>[
        _accountHolder.text,
        _bankName ?? '',
        '•••• ${_accountNumber.text.length >= 4 ? _accountNumber.text.substring(_accountNumber.text.length - 4) : _accountNumber.text}',
        '${_ifsc.text.toUpperCase()} · ${_accountType ?? ''}',
      ],
      () => setState(() => _step = 2),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: personalCard),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(child: presenceCard),
        SizedBox(width: context.sp(theme.spacing.sm)),
        Expanded(child: payoutCard),
      ],
    );
  }

  Widget _reviewCard(
    BuildContext context,
    String title,
    IconData icon,
    List<String> values,
    VoidCallback onEdit,
  ) {
    final theme = context.ui;
    final colors = theme.colors;
    return UiCard(
      variant: UiCardVariant.surface,
      child: Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: context.sz(17), color: colors.primary),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    title,
                    style: context.uiText.bodyStrong.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                UiIconButton(
                  icon: Icons.edit_outlined,
                  size: UiSize.xs,
                  tooltip: 'Edit $title',
                  onPressed: onEdit,
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            for (final String value
                in values.where((String v) => v.trim().isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPending(
    BuildContext context,
    AffiliateApplicationModel application,
  ) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(
                  responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
                ),
                vertical: context.sp(theme.spacing.xl),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight -
                      context.sp(theme.spacing.xl) * 2,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: context.sz(680)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppLogoMark(size: 20),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        'TradeX',
                        style: context.uiText.bodyStrong.copyWith(
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.xl)),
                  UiCard(
                    variant: UiCardVariant.surface,
                    child: Padding(
                      padding: EdgeInsets.all(
                        context.sp(
                          responsive.isMobile
                              ? theme.spacing.lg
                              : theme.spacing.xl,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const AuthStepIcon(
                            icon: Icons.hourglass_top_rounded,
                            intent: UiIntent.warning,
                            large: true,
                          ),
                          SizedBox(height: context.sp(theme.spacing.md)),
                          Text(
                            'Application Submitted!',
                            textAlign: TextAlign.center,
                            style: context.uiText.display.copyWith(
                              fontSize: 28.0,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            'Reference ${application.id}',
                            textAlign: TextAlign.center,
                            style: context.uiText.body.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.lg)),
                          const UiCallout(
                            title: 'Awaiting administrator review',
                            message:
                                'Most applications are reviewed within 48 hours. Partner links, payouts, and referral analytics remain locked until approval.',
                            intent: UiIntent.warning,
                          ),
                          SizedBox(height: context.sp(theme.spacing.md)),
                          Text(
                            'Your journal, portfolio, subscription, community profile, and all customer/trader tools remain available.',
                            textAlign: TextAlign.center,
                            style: context.uiText.body.copyWith(
                              color: theme.colors.foregroundMuted,
                              fontSize: 13.5,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.xl)),
                          UiButton(
                            label: 'Continue to TradeX',
                            trailingIcon: Icons.arrow_forward_rounded,
                            variant: UiVariant.primary,
                            intent: UiIntent.primary,
                            size: UiSize.lg,
                            onPressed: widget.onDone ?? widget.onCancel,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: context.sz(14),
                        color: colors.foregroundSubtle,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        'Your data is encrypted end-to-end',
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundSubtle,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
),
);
  }

  Widget _responsivePair(BuildContext context, Widget first, Widget second) {
    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          first,
          SizedBox(height: context.sp(context.ui.spacing.md)),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: first),
        SizedBox(width: context.sp(context.ui.spacing.md)),
        Expanded(child: second),
      ],
    );
  }
}

class _ApplicationPageSkeleton extends StatelessWidget {
  const _ApplicationPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const UiSkeleton(width: 28, height: 28),
            SizedBox(width: context.sp(theme.spacing.sm)),
            const UiSkeleton(width: 80, height: 24),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xl)),
        const UiSkeleton(width: double.infinity, height: 60),
        SizedBox(height: context.sp(theme.spacing.lg)),
        const UiSkeleton(width: double.infinity, height: 420),
      ],
    );
  }
}
