import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
  });

  final UserRole userRole;
  final ProfileSettingsRepository? repository;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late final ProfileSettingsRepository _repo;
  UserProfileModel? _profile;
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _customFieldController;
  String _selectedExperience = 'Advanced (3-5 years)';
  String _selectedStyle = 'Swing Trading';
  String _selectedChannelSource = 'YouTube & X (Twitter)';
  String _selectedDeskDivision = 'Proprietary Trading Desk';
  bool _publicStatsEnabled = false;

  final List<String> _experienceOptions = const <String>[
    'Beginner (< 1 year)',
    'Intermediate (1-3 years)',
    'Advanced (3-5 years)',
    'Professional (5+ years)',
  ];

  final List<String> _tradingStyles = const <String>[
    'Scalping (Seconds to Minutes)',
    'Day Trading (Intraday)',
    'Swing Trading (Days to Weeks)',
    'Position Trading (Months)',
    'Algorithmic / Quantitative',
  ];

  final List<String> _affiliateChannels = const <String>[
    'YouTube & Video Streaming',
    'X (Twitter) & Social Media',
    'Discord / Telegram Community',
    'Financial Newsletter / Blog',
    'Trading Academy / Education',
  ];

  final List<String> _deskDivisions = const <String>[
    'Proprietary Trading Desk',
    'Quantitative Hedge Fund',
    'Commodities & Futures Desk',
    'Family Office Asset Management',
    'Retail Brokerage & Risk',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ProfileSettingsRepositoryImpl();
    _displayNameController = TextEditingController();
    _bioController = TextEditingController();
    _customFieldController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _customFieldController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final p = await _repo.getProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          _displayNameController.text = p.displayName;
          _bioController.text = p.bio ?? '';
          _selectedExperience = p.experienceLevel ?? _experienceOptions[2];
          _selectedStyle = p.tradingStyle ?? _tradingStyles[2];
          _publicStatsEnabled = p.publicJournals;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        UiToast.show(
          context,
          title: 'Error',
          message: 'Failed to load profile details.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
        experienceLevel: widget.userRole == UserRole.customer
            ? _selectedExperience
            : (widget.userRole == UserRole.affiliate
                  ? _selectedChannelSource
                  : _selectedDeskDivision),
        tradingStyle: _selectedStyle,
        publicStatsEnabled: _publicStatsEnabled,
      );
      if (mounted) {
        setState(() {
          _profile = updated;
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Profile Updated',
          message: 'Your profile changes have been saved successfully.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Save Failed',
          message: 'Unable to update profile. Please try again.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  void _showAvatarEditDialog() {
    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Update Profile Photo',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  UiAvatar(
                    name: _displayNameController.text.isNotEmpty
                        ? _displayNameController.text
                        : 'Nitish Kumar',
                    imageUrl: _profile?.avatarUrl,
                    size: UiSize.xl,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.ui.colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: context.sz(14),
                      color: context.ui.colors.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.sp(context.ui.spacing.lg)),
            Text(
              'Choose an image from your device. Recommended resolution is 400x400px (JPG or PNG).',
              style: context.uiText.caption.copyWith(
                color: context.ui.colors.foregroundMuted,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.sp(context.ui.spacing.md)),
            UiDropzone(
              message: 'Drag & drop avatar here, or click to browse',
              onPick: () async {
                Navigator.of(ctx).pop();
                setState(() => _saving = true);
                try {
                  final newUrl = await _repo.uploadAvatar(
                    Uint8List.fromList([0, 1, 2, 3]),
                    'image/png',
                  );
                  if (mounted) {
                    setState(() {
                      _profile = _profile?.copyWith(avatarUrl: newUrl);
                      _saving = false;
                    });
                    UiToast.show(
                      context,
                      title: 'Avatar Updated',
                      message: 'Your new avatar image has been uploaded.',
                      intent: UiIntent.success,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _saving = false);
                    UiToast.show(
                      context,
                      title: 'Upload Failed',
                      message: 'Could not upload avatar photo.',
                      intent: UiIntent.danger,
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  void _showProfilePreview() {
    showSettingsSideSheet<void>(
      context,
      title: 'Public Profile Preview',
      subtitle: 'Preview how other traders see your public presence',
      desktopWidthRatio: 0.58,
      child: TraderProfilePreviewPage(
        displayName: _profile?.displayName ?? 'Nitish Kumar',
        handle: _profile?.handle ?? 'nitish_trader',
        bio: _profile?.bio,
        avatarUrl: _profile?.avatarUrl,
        userRole: widget.userRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final Color verifiedColor = switch (widget.userRole) {
      UserRole.customer => colors.primary,
      UserRole.affiliate => colors.warning,
      UserRole.userAdmin => colors.destructive,
    };
    final isMobile = context.uiRes.isMobile;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            UiSkeleton(height: 120),
            SizedBox(height: 16),
            UiSkeleton(height: 140),
            SizedBox(height: 16),
            UiSkeleton(height: 100),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card with Avatar and Badges
              UiCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 480;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                UiAvatar(
                                  name: _profile?.displayName ?? 'Nitish Kumar',
                                  imageUrl: _profile?.avatarUrl,
                                  size: UiSize.lg,
                                  verified: true,
                                  verifiedColor: verifiedColor,
                                ),
                                InkWell(
                                  onTap: _showAvatarEditDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colors.surface,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      size: context.sz(10),
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: context.sp(theme.spacing.xs),
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        _profile?.displayName ?? 'Nitish Kumar',
                                        style: context.uiText.heading,
                                      ),
                                      UiTooltip(
                                        message: 'Verified trader',
                                        child: Icon(
                                          Icons.verified_rounded,
                                          color: verifiedColor,
                                          size: context.sz(18),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xxs),
                                  ),
                                  Text(
                                    '@${_profile?.handle ?? 'nitish_trader'}',
                                    style: context.uiText.caption.copyWith(
                                      color: colors.foregroundMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isNarrow) ...[
                              SizedBox(width: context.sp(theme.spacing.md)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  SizedBox(
                                    width: context.sz(156),
                                    child: UiButton(
                                      label: 'Preview Profile',
                                      leadingIcon: Icons.visibility_outlined,
                                      variant: UiVariant.soft,
                                      size: UiSize.sm,
                                      expandOnMobile: false,
                                      onPressed: _showProfilePreview,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.xs),
                                  ),
                                  SizedBox(
                                    width: context.sz(156),
                                    child: UiButton(
                                      label: 'Change Photo',
                                      variant: UiVariant.outline,
                                      size: UiSize.sm,
                                      expandOnMobile: false,
                                      onPressed: _showAvatarEditDialog,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        if (isNarrow) ...[
                          SizedBox(height: context.sp(theme.spacing.md)),
                          UiButton(
                            label: 'Preview Public Profile',
                            leadingIcon: Icons.visibility_outlined,
                            variant: UiVariant.soft,
                            size: UiSize.sm,
                            onPressed: _showProfilePreview,
                          ),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          UiButton(
                            label: 'Change Photo',
                            leadingIcon: Icons.camera_alt_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: _showAvatarEditDialog,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Role-tailored personal details
              AppSettingsSectionBlock(
                title: widget.userRole == UserRole.customer
                    ? 'Trader Profile Details'
                    : (widget.userRole == UserRole.affiliate
                          ? 'Affiliate Partner Identity'
                          : 'Institutional Admin Identity'),
                description: widget.userRole == UserRole.customer
                    ? 'Public trader alias, strategy bio, and background.'
                    : (widget.userRole == UserRole.affiliate
                          ? 'Creator alias and promotional bio shown on your referral portal.'
                          : 'Administrative credentials and firm division overview.'),
                children: [
                  UiField(
                    label: widget.userRole == UserRole.customer
                        ? 'Display Name / Alias'
                        : (widget.userRole == UserRole.affiliate
                              ? 'Partner / Channel Name'
                              : 'Administrator Full Name'),
                    child: UiInput(
                      value: _displayNameController.text,
                      hintText: 'Your name or organization alias',
                      onChanged: (v) => _displayNameController.text = v,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiField(
                    label: widget.userRole == UserRole.customer
                        ? 'Trader Bio'
                        : (widget.userRole == UserRole.affiliate
                              ? 'Audience & Channel Bio'
                              : 'Desk & Role Description'),
                    helper:
                        'Displayed on your public profile and verified shared playbooks.',
                    child: UiTextarea(
                      value: _bioController.text,
                      hintText: widget.userRole == UserRole.customer
                          ? 'Share your background, markets traded, or strategy style...'
                          : (widget.userRole == UserRole.affiliate
                                ? 'Describe your audience, media channels, or trading community...'
                                : 'Describe your desk coverage, asset classes, and risk mandates...'),
                      rows: 3,
                      onChanged: (v) => _bioController.text = v,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Role-specific categorization
              if (widget.userRole == UserRole.customer) ...[
                AppSettingsSectionBlock(
                  title: 'Trading Experience & Focus',
                  description:
                      'Helps personalize analytics, AI insights, and peer matching.',
                  children: [
                    UiField(
                      label: 'Experience Level',
                      child: UiSelect<String>(
                        value: _selectedExperience,
                        options: _experienceOptions
                            .map((e) => UiOption<String>(label: e, value: e))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedExperience = v);
                        },
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiField(
                      label: 'Primary Trading Style',
                      child: UiSelect<String>(
                        value: _selectedStyle,
                        options: _tradingStyles
                            .map((s) => UiOption<String>(label: s, value: s))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedStyle = v);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                AppSettingsSectionBlock(
                  title: 'Public Statistics Visibility',
                  children: [
                    AppSettingCard(
                      title: 'Show win-rate and public stats on profile',
                      description:
                          'Allow other verified traders to view your aggregated performance metrics.',
                      icon: Icons.insights_rounded,
                      control: UiSwitch(
                        value: _publicStatsEnabled,
                        onChanged: (val) =>
                            setState(() => _publicStatsEnabled = val),
                      ),
                    ),
                  ],
                ),
              ] else if (widget.userRole == UserRole.affiliate) ...[
                AppSettingsSectionBlock(
                  title: 'Audience & Promotion Channels',
                  description:
                      'Primary platforms where you share TradeX referral codes and playbooks.',
                  children: [
                    UiField(
                      label: 'Primary Promotion Channel',
                      child: UiSelect<String>(
                        value: _selectedChannelSource,
                        options: _affiliateChannels
                            .map((c) => UiOption<String>(label: c, value: c))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedChannelSource = v);
                        },
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    AppSettingCard(
                      title: 'Public Partner Badge on Leaderboards',
                      description:
                          'Display an official verified affiliate badge next to your handle in community discussions.',
                      icon: Icons.verified_rounded,
                      control: UiSwitch(
                        value: _publicStatsEnabled,
                        onChanged: (val) =>
                            setState(() => _publicStatsEnabled = val),
                      ),
                    ),
                  ],
                ),
              ] else if (widget.userRole == UserRole.userAdmin) ...[
                AppSettingsSectionBlock(
                  title: 'Institutional Desk Mandate',
                  description: 'Firm classification and trading division.',
                  children: [
                    UiField(
                      label: 'Desk Division',
                      child: UiSelect<String>(
                        value: _selectedDeskDivision,
                        options: _deskDivisions
                            .map((d) => UiOption<String>(label: d, value: d))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedDeskDivision = v);
                        },
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    AppSettingCard(
                      title: 'Admin Activity Privacy',
                      description:
                          'Keep administrative risk actions and desk management activity private from standard traders.',
                      icon: Icons.admin_panel_settings_rounded,
                      control: UiSwitch(
                        value: _publicStatsEnabled,
                        onChanged: (val) =>
                            setState(() => _publicStatsEnabled = val),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Submit button
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: UiButton(
                    label: 'Save Changes',
                    intent: UiIntent.primary,
                    variant: UiVariant.primary,
                    loading: _saving,
                    onPressed: _saveProfile,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
