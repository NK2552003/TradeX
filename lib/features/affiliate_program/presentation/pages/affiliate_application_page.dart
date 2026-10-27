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
    this.onOpenPartnerHub,
  });

  final String userId;
  final String email;
  final String displayName;
  final bool isExistingCustomer;
  final AffiliateApplicationRepository? repository;
  final ValueChanged<AffiliateApplicationModel>? onSubmitted;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenPartnerHub;

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
  bool _loadFailed = false;
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
    _loadFailed = false;
    try {
      final existing = await _repository.getForUser(widget.userId);
      if (!mounted) return;
      setState(() {
        if (existing != null) {
          if (existing.status != AffiliateApplicationStatus.draft &&
              existing.status != AffiliateApplicationStatus.rejected) {
            _submitted = existing;
          } else {
            _name.text = existing.fullName;
            _email.text = existing.email;
            _phone.text = existing.phone;
            _city.text = existing.city;
            _state.text = existing.state;
            _dateOfBirth = existing.dateOfBirth;
            _gender = existing.gender.isEmpty ? null : existing.gender;
            _platforms
              ..clear()
              ..addAll(existing.platforms);
            _primaryPlatform = existing.primaryPlatform.isEmpty
                ? null
                : existing.primaryPlatform;
            _channel.text = existing.channelHandle;
            _audienceReach = existing.audienceReach.isEmpty
                ? null
                : existing.audienceReach;
            _niches
              ..clear()
              ..addAll(existing.niches);
            _sampleLink.text = existing.sampleLink ?? '';
            _accountHolder.text = existing.accountHolder;
            _bankName = existing.bankName.isEmpty ? null : existing.bankName;
            _accountNumber.text = existing.accountNumber;
            _ifsc.text = existing.ifsc;
            _accountType = existing.accountType.isEmpty
                ? null
                : existing.accountType;
            _pan.text = existing.pan;
            _upi.text = existing.upiId ?? '';
            if (existing.status == AffiliateApplicationStatus.rejected) {
              _error =
                  'Changes requested: ${existing.reviewNotes ?? 'Review your details and resubmit.'}';
            }
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _error =
              'Your application status could not be loaded. Please retry before submitting.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingExistingApplication = false);
    }
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

  void _showPhoneOtpDialog(BuildContext context) {
    String otp = '';
    String? otpError;
    UiDialog.show<void>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) => UiDialog(
          title: 'Verify +91 ${_phone.text.trim()}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Enter the 6-digit verification code sent to +91 ${_phone.text.trim()}.',
                style: ctx.uiText.body,
              ),
              SizedBox(height: ctx.sp(ctx.ui.spacing.sm)),
              if (otpError != null) ...<Widget>[
                UiCallout(
                  title: 'Invalid code',
                  message: otpError,
                  intent: UiIntent.danger,
                ),
                SizedBox(height: ctx.sp(ctx.ui.spacing.sm)),
              ],
              UiField(
                label: '6-Digit Verification OTP',
                helper: 'Enter your 6-digit mobile verification code',
                child: UiInput(
                  value: otp,
                  hintText: '123456',
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  onChanged: (String v) => setDialogState(() {
                    otp = v.trim();
                    otpError = null;
                  }),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            UiButton(
              label: 'Verify Mobile',
              intent: UiIntent.primary,
              onPressed: () {
                if (otp.length != 6) {
                  setDialogState(
                    () => otpError = 'Please enter a 6-digit numeric code.',
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                setState(() => _phoneVerified = true);
                UiToast.show(
                  context,
                  title: 'Mobile Number Verified',
                  message: '+91 ${_phone.text.trim()} is verified for KYC.',
                  intent: UiIntent.success,
                );
              },
            ),
          ],
        ),
      ),
    );
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
    if (_submitting) return;
    if (!_personalValid || !_presenceValid || !_payoutValid) {
      setState(() {
        _step = !_personalValid
            ? 0
            : !_presenceValid
            ? 1
            : 2;
        _error =
            'Review the required details before submitting your application.';
      });
      return;
    }

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
    final responsive = context.uiRes;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = responsive.isMobile
        ? (keyboardInset > 0
              ? keyboardInset + 24.0
              : (context.uiDockInset < 100.0 ? 100.0 : context.uiDockInset))
        : context.sp(theme.spacing.xl);

    // No Scaffold and no background of its own: this page renders inside the
    // app shell, which already owns both. Painting `colors.background` here
    // covered the shell's rounded content surface on desktop, and a nested
    // `resizeToAvoidBottomInset` re-applied a keyboard inset the shell has
    // already zeroed for its subtree.
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          context.sp(responsive.isMobile ? theme.spacing.md : theme.spacing.lg),
          context.sp(theme.spacing.md),
          context.sp(responsive.isMobile ? theme.spacing.md : theme.spacing.lg),
          bottomInset,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(860)),
            child: const _ApplicationPageSkeleton(),
          ),
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
    if (_loadFailed) {
      return UiPage(
        title: 'Affiliate application',
        child: UiEmptyState(
          title: 'Application status unavailable',
          message: _error,
          action: UiButton(
            label: 'Retry application',
            onPressed: () async {
              setState(() => _loadingExistingApplication = true);
              await _loadExistingApplication();
            },
          ),
        ),
      );
    }
    if (_submitted != null) return _buildPending(context, _submitted!);

    final (IconData stepIcon, UiIntent stepIntent) = switch (_step) {
      0 => (Icons.person_outline_rounded, UiIntent.primary),
      1 => (Icons.campaign_outlined, UiIntent.info),
      2 => (Icons.account_balance_outlined, UiIntent.warning),
      _ => (Icons.fact_check_outlined, UiIntent.primary),
    };

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = responsive.isMobile
        ? (keyboardInset > 0
              ? keyboardInset + 24.0
              : (context.uiDockInset < 100.0 ? 100.0 : context.uiDockInset))
        : context.sp(theme.spacing.xl);

    // The shell owns the page background and the keyboard inset (see
    // `_buildLoading`), so this returns bare content.
    return SafeArea(
      bottom: false,
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            context.sp(
              responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
            ),
            context.sp(theme.spacing.md),
            context.sp(
              responsive.isMobile ? theme.spacing.md : theme.spacing.lg,
            ),
            bottomInset,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(860)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UiCard(
                    variant: UiCardVariant.surface,
                    padding: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(
                        context.sp(
                          responsive.isMobile
                              ? theme.spacing.md
                              : theme.spacing.xl,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Unified Header inside Card: Back Button, Logo, alphajournal & Step Badge
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: context.sp(theme.spacing.sm),
                            runSpacing: context.sp(theme.spacing.sm),
                            children: [
                              if (widget.onCancel != null)
                                UiButton(
                                  label: widget.isExistingCustomer
                                      ? 'Back to workspace'
                                      : 'Back to sign in',
                                  leadingIcon: Icons.arrow_back_rounded,
                                  variant: UiVariant.ghost,
                                  size: UiSize.sm,
                                  onPressed: widget.onCancel,
                                ),
                              UiBadge(
                                label: 'Step ${_step + 1} of 4',
                                intent: UiIntent.primary,
                              ),
                            ],
                          ),
                          UiGap.v(theme.spacing.md),
                          LayoutBuilder(
                            builder: (context, constraints) =>
                                constraints.maxWidth < context.sz(600)
                                ? UiProgressBar(
                                    value: (_step + 1) / 4,
                                    label: [
                                      'Personal details',
                                      'Audience & channels',
                                      'Payout & tax details',
                                      'Review application',
                                    ][_step],
                                  )
                                : UiStepper(
                                    steps: const [
                                      UiStepperStep(title: 'Personal'),
                                      UiStepperStep(title: 'Presence'),
                                      UiStepperStep(title: 'Payout'),
                                      UiStepperStep(title: 'Review'),
                                    ],
                                    currentIndex: _step,
                                    onStepTap: (index) {
                                      if (index <= _furthestStep) {
                                        setState(() {
                                          _step = index;
                                          _error = null;
                                        });
                                      }
                                    },
                                  ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.lg)),
                          AuthStepIcon(icon: stepIcon, intent: stepIntent),
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          Text(
                            widget.isExistingCustomer
                                ? 'Add affiliate access'
                                : 'Affiliate application',
                            textAlign: TextAlign.left,
                            style: context.uiText.heading,
                          ),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Text(
                            'Share your details for partner review. You can keep using your trading account.',
                            textAlign: TextAlign.left,
                            style: context.uiText.body.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                          SizedBox(height: context.sp(theme.spacing.md)),
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
                                    size: responsive.isMobile
                                        ? UiSize.md
                                        : UiSize.lg,
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
                                            : 'Submit Application')
                                      : 'Continue',
                                  trailingIcon: _step == 3
                                      ? null
                                      : Icons.arrow_forward_rounded,
                                  variant: UiVariant.primary,
                                  intent: UiIntent.primary,
                                  size: responsive.isMobile
                                      ? UiSize.md
                                      : UiSize.lg,
                                  onPressed: _submitting
                                      ? null
                                      : (_step == 3 ? _submit : _next),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: context.sp(theme.spacing.sm)),
                          Text(
                            'Approval adds affiliate tools to your existing account. Your trading workspace and customer access remain unchanged.',
                            textAlign: TextAlign.center,
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
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
                          'Manage your account and privacy settings in alphajournal',
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
            success: _phoneVerified ? 'Phone verified (+91)' : null,
            helper: _phoneVerified
                ? null
                : 'Enter a 10-digit Indian mobile number and tap verify.',
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
                variant: _phoneVerified ? UiVariant.success : UiVariant.outline,
                tooltip: _phoneVerified
                    ? 'Phone verified'
                    : 'Verify +91 mobile via OTP',
                onPressed: _phone.text.trim().length >= 10
                    ? () => _showPhoneOtpDialog(context)
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
              onChanged: (DateTime date) => setState(() => _dateOfBirth = date),
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
          'Tell reviewers where and how you plan to introduce alphajournal.',
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
          'Used for affiliate payout processing after approval.',
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
              onChanged: (String value) => setState(() => _accountType = value),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildReviewCards(context),
        SizedBox(height: context.sp(theme.spacing.md)),
        const UiCallout(
          title: 'Review and access policy',
          message:
              'Submitting does not grant immediate Partner Hub access. An administrator must approve the application first. You can continue using alphajournal as a customer/trader while it is pending.',
          intent: UiIntent.warning,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        UiCheckbox(
          value: _termsAccepted,
          asCard: true,
          label:
              'I confirm these details are accurate and accept the alphajournal Affiliate Program terms.',
          description:
              'I understand that approval can be refused or suspended for policy violations.',
          onChanged: (bool value) => setState(() => _termsAccepted = value),
        ),
      ],
    );
  }

  Widget _buildReviewCards(BuildContext context) {
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

    return UiCardGrid(
      minTileWidth: 220,
      largeColumns: 3,
      children: [
        for (final section in sections)
          UiCard(
            title: section.title,
            leading: Icon(
              section.icon,
              color: colors.primary,
              size: context.sz(20),
            ),
            trailing: UiButton(
              label: 'Edit',
              leadingIcon: Icons.edit_outlined,
              variant: UiVariant.ghost,
              size: UiSize.sm,
              onPressed: section.onEdit,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final value in section.values.where(
                  (value) => value.trim().isNotEmpty,
                ))
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: context.sp(theme.spacing.xs),
                    ),
                    child: Text(value, style: context.uiText.body),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPending(
    BuildContext context,
    AffiliateApplicationModel application,
  ) {
    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = responsive.isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : context.uiDockInset)
        : context.sp(theme.spacing.xl);

    // Shell-owned background and keyboard inset (see `_buildLoading`).
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          context.sp(responsive.isMobile ? theme.spacing.md : theme.spacing.lg),
          context.sp(theme.spacing.md),
          context.sp(responsive.isMobile ? theme.spacing.md : theme.spacing.lg),
          bottomInset,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(860)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogoMark(size: 20),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'alphajournal',
                      style: context.uiText.bodyStrong.copyWith(
                        fontSize: 16,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                UiCard(
                  variant: UiCardVariant.surface,
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(
                      context.sp(
                        responsive.isMobile
                            ? theme.spacing.md
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
                          application.status ==
                                  AffiliateApplicationStatus.approved
                              ? 'Application approved'
                              : application.status ==
                                    AffiliateApplicationStatus.suspended
                              ? 'Partner access suspended'
                              : 'Application Submitted!',
                          textAlign: TextAlign.center,
                          style: context.uiText.heading,
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
                        SizedBox(height: context.sp(theme.spacing.md)),
                        UiCallout(
                          title:
                              application.status ==
                                  AffiliateApplicationStatus.approved
                              ? 'Partner Hub is ready'
                              : application.status ==
                                    AffiliateApplicationStatus.suspended
                              ? 'Contact partner support'
                              : 'Awaiting administrator review',
                          message:
                              application.status ==
                                  AffiliateApplicationStatus.approved
                              ? 'Your referral links, campaign analytics, and payout tools are available in Partner Hub.'
                              : application.status ==
                                    AffiliateApplicationStatus.suspended
                              ? (application.reviewNotes ??
                                    'Partner tools are restricted. Your trader account remains available.')
                              : 'Partner links, payouts, and referral analytics remain locked until administrator approval.',
                          intent:
                              application.status ==
                                  AffiliateApplicationStatus.approved
                              ? UiIntent.success
                              : UiIntent.warning,
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        Text(
                          'Your journal, portfolio, subscription, community profile, and all customer/trader tools remain available.',
                          textAlign: TextAlign.center,
                          style: context.uiText.body.copyWith(
                            color: theme.colors.foregroundMuted,
                            fontSize: 13.0,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.lg)),
                        UiButton(
                          label: 'Refresh application status',
                          variant: UiVariant.outline,
                          onPressed: () async {
                            setState(() => _loadingExistingApplication = true);
                            await _loadExistingApplication();
                          },
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiButton(
                          label:
                              application.status ==
                                      AffiliateApplicationStatus.approved &&
                                  widget.onOpenPartnerHub != null
                              ? 'Open Partner Hub'
                              : 'Continue to alphajournal',
                          trailingIcon: Icons.arrow_forward_rounded,
                          variant: UiVariant.primary,
                          intent: UiIntent.primary,
                          size: responsive.isMobile ? UiSize.md : UiSize.lg,
                          onPressed:
                              application.status ==
                                      AffiliateApplicationStatus.approved &&
                                  widget.onOpenPartnerHub != null
                              ? widget.onOpenPartnerHub
                              : widget.onDone ?? widget.onCancel,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.md)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: context.sz(14),
                      color: colors.foregroundSubtle,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Flexible(
                      child: Text(
                        'Manage your account and privacy settings in alphajournal',
                        textAlign: TextAlign.center,
                        style: context.uiText.caption.copyWith(
                          color: colors.foregroundSubtle,
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
  }

  Widget _responsivePair(BuildContext context, Widget first, Widget second) {
    return UiCardGrid(
      minTileWidth: 260,
      largeColumns: 2,
      children: [first, second],
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
