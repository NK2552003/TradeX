import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/settings/data/repositories/affiliate_settings_repository.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_subpage_scope.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    super.key,
    this.userRole = UserRole.customer,
    this.repository,
    this.onOpenRef,
    this.communityRepository,
  });

  final UserRole userRole;
  final CommunityRepository? communityRepository;
  final ProfileSettingsRepository? repository;
  final void Function(AppLinkRef ref)? onOpenRef;

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
  late TextEditingController _locationController;
  late TextEditingController _websiteController;
  late TextEditingController _riskMantraController;

  // Affiliate specific fields
  late TextEditingController _phoneController;
  late TextEditingController _channelHandleController;
  late TextEditingController _sampleLinkController;
  late TextEditingController _accountHolderController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _panController;
  late TextEditingController _upiController;
  late TextEditingController _referralCodeController;

  String _selectedExperience = 'Advanced (3-5 years)';
  String _selectedStyle = 'Swing Trading (Days to Weeks)';
  String _selectedMarket = 'Equities & Index Options';
  String _selectedHoldDuration = '45 mins (Intraday)';
  String _selectedTopStrategy = 'ORB Breakout';
  String _selectedChannelSource = 'YouTube & Video Streaming';
  String _selectedAudienceReach = '10,000 – 100,000';
  String _selectedNiche = 'Trading education';
  String _selectedPayoutMethod = 'UPI Instant Transfer';
  String _selectedDeskDivision = 'Proprietary Trading Desk';

  bool _publicStatsEnabled = true;
  bool _publicJournalsEnabled = true;
  bool _autoPayoutEnabled = true;
  bool _adminKillswitchEnabled = true;
  bool _adminPreTradeVaREnabled = true;
  bool _adminAuditHashingEnabled = true;

  late final TextEditingController _adminClearanceLevelController;
  late final TextEditingController _adminDesignationController;
  late final TextEditingController _adminSupervisedCapitalController;
  late final TextEditingController _adminTerminalUrlController;

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

  final List<String> _marketOptions = const <String>[
    'Equities & Index Options',
    'Index Futures & Options (NIFTY/BANKNIFTY)',
    'Crypto & Digital Assets',
    'Forex & Commodities',
    'Global Equities & ETFs',
  ];

  final List<String> _holdDurations = const <String>[
    '< 15 mins (Scalping)',
    '45 mins (Intraday)',
    '1-3 Days (Swing)',
    '1-2 Weeks (Multi-Day)',
    'Position (Months)',
  ];

  final List<String> _topStrategies = const <String>[
    'ORB Breakout',
    'VWAP Bounce & Retest',
    'Supply & Demand Reversals',
    'Momentum Trend Continuation',
    'Options Delta Neutral / Straddles',
  ];

  final List<String> _affiliateChannels = const <String>[
    'YouTube & Video Streaming',
    'X (Twitter) & Social Media',
    'Discord / Telegram Community',
    'Financial Newsletter / Blog',
    'Trading Academy / Education',
  ];

  final List<String> _audienceReachOptions = const <String>[
    '< 1,000 Traders',
    '1,000 – 10,000 Traders',
    '10,000 – 100,000 Traders',
    '100,000+ Traders',
  ];

  final List<String> _nicheOptions = const <String>[
    'Trading education',
    'Technical analysis',
    'Personal finance',
    'Fintech & Prop Trading',
    'Options & Futures Strategies',
  ];

  final List<String> _payoutMethods = const <String>[
    'UPI Instant Transfer',
    'Bank Wire Transfer (NEFT/RTGS)',
    'Bank IMPS Instant Settlement (INR)',
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
    _locationController = TextEditingController();
    _websiteController = TextEditingController();
    _riskMantraController = TextEditingController();

    _phoneController = TextEditingController(text: '+91 98765 43210');
    _channelHandleController = TextEditingController(text: '@designtrades');
    _sampleLinkController = TextEditingController(
      text: 'https://youtube.com/@designtrades',
    );
    _accountHolderController = TextEditingController();
    _bankNameController = TextEditingController(text: 'HDFC Bank');
    _accountNumberController = TextEditingController(text: '123456789012');
    _ifscController = TextEditingController(text: 'HDFC0001234');
    _panController = TextEditingController(text: 'ABCDE1234F');
    _upiController = TextEditingController(text: 'design@upi');
    _referralCodeController = TextEditingController(
      text: 'TRADEX-PARTNER-2026',
    );

    _adminClearanceLevelController = TextEditingController(
      text: 'Level 5 Root Superadmin',
    );
    _adminDesignationController = TextEditingController(
      text: 'Chief Risk Officer & Managing Partner',
    );
    _adminSupervisedCapitalController = TextEditingController(
      text: '₹148.2 Cr',
    );
    _adminTerminalUrlController = TextEditingController(
      text: 'tradex.internal/root',
    );

    _applyProfile(_repo.cachedProfile);
    _loadProfile();
  }

  void _applyProfile(UserProfileModel profile) {
    _profile = profile;
    _displayNameController.text = profile.displayName;
    _accountHolderController.text = profile.displayName;
    _bioController.text = profile.bio ?? '';
    _locationController.text = profile.location ?? '';
    _websiteController.text = profile.website ?? '';
    _riskMantraController.text = profile.riskMantra ?? '';
    _referralCodeController.text = profile.referralCode ?? '';

    if (profile.experienceLevel != null &&
        profile.experienceLevel!.isNotEmpty) {
      _selectedExperience = profile.experienceLevel!;
    }
    if (profile.tradingStyle != null && profile.tradingStyle!.isNotEmpty) {
      _selectedStyle = profile.tradingStyle!;
    }
    if (profile.primaryMarket != null && profile.primaryMarket!.isNotEmpty) {
      _selectedMarket = profile.primaryMarket!;
    }
    if (profile.avgHoldDuration != null &&
        profile.avgHoldDuration!.isNotEmpty) {
      _selectedHoldDuration = profile.avgHoldDuration!;
    }
    if (profile.topStrategy != null && profile.topStrategy!.isNotEmpty) {
      _selectedTopStrategy = profile.topStrategy!;
    }

    _publicStatsEnabled = profile.publicJournals;
    _publicJournalsEnabled = profile.publicJournals;
  }

  bool get _verified =>
      appTierFromId(_profile?.subscriptionTier ?? '') != AppTier.free;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    _riskMantraController.dispose();

    _phoneController.dispose();
    _channelHandleController.dispose();
    _sampleLinkController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _panController.dispose();
    _upiController.dispose();
    _referralCodeController.dispose();

    _adminClearanceLevelController.dispose();
    _adminDesignationController.dispose();
    _adminSupervisedCapitalController.dispose();
    _adminTerminalUrlController.dispose();

    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final p = await _repo.getProfile();
      if (widget.userRole == UserRole.affiliate) {
        try {
          final aff = await AffiliateSettingsRepositoryImpl()
              .getAffiliateSettings();
          _accountHolderController.text = aff.accountHolderName.isNotEmpty
              ? aff.accountHolderName
              : p.displayName;
          _bankNameController.text = aff.bankName;
          _accountNumberController.text = aff.accountNumber;
          _ifscController.text = aff.ifscCode;
          _panController.text = aff.panNumber;
          _upiController.text = aff.upiVpa;
          _autoPayoutEnabled = aff.autoPayout;
          if (aff.payoutMethod == 'upi') {
            _selectedPayoutMethod = 'UPI Instant Transfer';
          } else if (aff.payoutMethod == 'bank_imps') {
            _selectedPayoutMethod = 'Bank IMPS Instant Settlement (INR)';
          } else {
            _selectedPayoutMethod = 'Bank Wire Transfer (NEFT/RTGS)';
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _applyProfile(p);
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
        avatarUrl: _profile?.avatarUrl,
        location: _locationController.text.trim(),
        website: _websiteController.text.trim(),
        avgHoldDuration: _selectedHoldDuration,
        primaryMarket: widget.userRole == UserRole.affiliate
            ? _selectedNiche
            : _selectedMarket,
        topStrategy: widget.userRole == UserRole.affiliate
            ? _selectedChannelSource
            : _selectedTopStrategy,
        riskMantra: _riskMantraController.text.trim(),
        experienceLevel: widget.userRole == UserRole.customer
            ? _selectedExperience
            : (widget.userRole == UserRole.affiliate
                  ? _selectedChannelSource
                  : _selectedDeskDivision),
        tradingStyle: _selectedStyle,
        publicStatsEnabled: _publicStatsEnabled,
      );
      if (widget.userRole == UserRole.affiliate) {
        try {
          final String method = _selectedPayoutMethod.startsWith('UPI')
              ? 'upi'
              : _selectedPayoutMethod.contains('IMPS')
              ? 'bank_imps'
              : 'bank_neft';
          await AffiliateSettingsRepositoryImpl().updatePayoutSettings(
            payoutMethod: method,
            payoutAccount: method == 'upi'
                ? _upiController.text.trim()
                : '${_bankNameController.text.trim()} • ${_accountNumberController.text.trim()}',
            minimumThreshold: 1000.0,
            autoPayout: _autoPayoutEnabled,
            accountHolderName: _accountHolderController.text.trim(),
            bankName: _bankNameController.text.trim(),
            accountNumber: _accountNumberController.text.trim(),
            ifscCode: _ifscController.text.trim().toUpperCase(),
            upiVpa: _upiController.text.trim(),
            panNumber: _panController.text.trim().toUpperCase(),
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _profile = updated;
          _saving = false;
        });
        UiToast.show(
          context,
          title: widget.userRole == UserRole.affiliate
              ? 'Partner Profile Updated'
              : 'Profile Updated',
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

  Future<void> _handleImageSelection({
    required ImageSource source,
    BuildContext? dialogContext,
  }) async {
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    try {
      Uint8List? imageBytes;
      String contentType = 'image/jpeg';

      try {
        final ImagePicker picker = ImagePicker();
        final XFile? picked = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 90,
        );
        if (picked != null) {
          imageBytes = await picked.readAsBytes();
          final String ext = picked.name.split('.').last.toLowerCase();
          contentType = ext == 'png'
              ? 'image/png'
              : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
        }
      } catch (pickerError) {
        debugPrint('[ProfileSettingsPage] ImagePicker error: $pickerError');
        if (source == ImageSource.gallery) {
          final FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            withData: true,
          );
          if (result != null && result.files.isNotEmpty) {
            final PlatformFile file = result.files.first;
            imageBytes = file.bytes;
            final String ext = (file.extension ?? '').toLowerCase();
            contentType = ext == 'png'
                ? 'image/png'
                : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
          }
        } else {
          if (mounted) {
            UiToast.show(
              context,
              title: 'Camera Unavailable',
              message:
                  'Camera could not be accessed on this device. Please select an image from your files.',
              intent: UiIntent.warning,
            );
          }
          return;
        }
      }

      if (imageBytes == null || imageBytes.isEmpty) {
        // User cancelled picker
        return;
      }

      setState(() => _saving = true);
      if (mounted) {
        UiToast.show(
          context,
          title: 'Uploading Photo',
          message: 'Saving your profile picture...',
          intent: UiIntent.info,
        );
      }

      final String newUrl = await _repo.uploadAvatar(imageBytes, contentType);

      if (mounted) {
        setState(() {
          _profile = _profile?.copyWith(avatarUrl: newUrl);
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Photo Updated',
          message: 'Your profile picture has been updated.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      debugPrint('[ProfileSettingsPage] _handleImageSelection error: $e');
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Upload Failed',
          message: 'Could not update profile photo: $e',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _handleRemovePhoto(BuildContext dialogContext) async {
    Navigator.of(dialogContext).pop();
    setState(() => _saving = true);
    try {
      await _repo.removeAvatar();
      if (mounted) {
        setState(() {
          _profile = _profile?.copyWith(avatarUrl: '');
          _saving = false;
        });
        UiToast.show(
          context,
          title: 'Photo Removed',
          message: 'Profile photo has been reset.',
          intent: UiIntent.neutral,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Error',
          message: 'Failed to remove profile photo.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  void _showAvatarEditDialog() {
    final bool hasCustomAvatar =
        _profile?.avatarUrl != null && _profile!.avatarUrl!.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Update Profile Photo',
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
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
                          : (_profile?.displayName ?? ''),
                      imageUrl: _profile?.avatarUrl,
                      size: UiSize.xl,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.ui.colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.ui.colors.surface,
                          width: 2,
                        ),
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
              SizedBox(height: context.sp(context.ui.spacing.md)),
              Text(
                'Upload a photo from your device or capture a new one using your camera. JPG, PNG, or WEBP supported.',
                style: context.uiText.caption.copyWith(
                  color: context.ui.colors.foregroundMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.sp(context.ui.spacing.lg)),

              // Primary Actions: Choose from Device / Take Photo
              Row(
                children: [
                  Expanded(
                    child: UiButton(
                      label: 'Choose File',
                      leadingIcon: Icons.photo_library_outlined,
                      variant: UiVariant.solid,
                      intent: UiIntent.primary,
                      onPressed: () => _handleImageSelection(
                        source: ImageSource.gallery,
                        dialogContext: ctx,
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(context.ui.spacing.sm)),
                  Expanded(
                    child: UiButton(
                      label: 'Take Photo',
                      leadingIcon: Icons.camera_alt_outlined,
                      variant: UiVariant.outline,
                      onPressed: () => _handleImageSelection(
                        source: ImageSource.camera,
                        dialogContext: ctx,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(context.ui.spacing.md)),

              // Drag & Drop / Clickable dropzone
              UiDropzone(
                title: 'Drop image here',
                message: 'or click to browse local files',
                icon: Icons.cloud_upload_outlined,
                onPick: () => _handleImageSelection(
                  source: ImageSource.gallery,
                  dialogContext: ctx,
                ),
              ),

              if (hasCustomAvatar) ...[
                SizedBox(height: context.sp(context.ui.spacing.sm)),
                Center(
                  child: UiButton(
                    label: 'Remove current photo',
                    leadingIcon: Icons.delete_outline,
                    variant: UiVariant.ghost,
                    intent: UiIntent.danger,
                    onPressed: () => _handleRemovePhoto(ctx),
                  ),
                ),
              ],
            ],
          ),
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

  static String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  void _showProfilePreview() {
    double? liveWinRate = _profile?.winRate;
    if (liveWinRate == null) {
      try {
        final journalStats = JournalRepositoryScope.repository.stats;
        if (journalStats.total > 0) {
          liveWinRate = journalStats.winRate * 100;
        }
      } catch (_) {}
    }

    final int livePosts =
        widget.communityRepository?.postsForAuthor(_profile?.id ?? '').length ??
        _profile?.postsCount ??
        0;

    final String? joined = _profile?.createdAt != null
        ? 'Joined ${_monthName(_profile!.createdAt!.month)} ${_profile!.createdAt!.year}'
        : null;

    final String? activeLocation = _locationController.text.trim().isNotEmpty
        ? _locationController.text.trim()
        : _profile?.location;
    final String? activeWebsite = _websiteController.text.trim().isNotEmpty
        ? _websiteController.text.trim()
        : _profile?.website;
    final String? activeHoldDuration = _selectedHoldDuration.trim().isNotEmpty
        ? _selectedHoldDuration
        : _profile?.avgHoldDuration;
    final String? activeMarket =
        (widget.userRole == UserRole.affiliate
                ? _selectedNiche
                : _selectedMarket)
            .trim()
            .isNotEmpty
        ? (widget.userRole == UserRole.affiliate
              ? _selectedNiche
              : _selectedMarket)
        : _profile?.primaryMarket;
    final String? activeTopStrategy =
        (widget.userRole == UserRole.affiliate
                ? _selectedChannelSource
                : _selectedTopStrategy)
            .trim()
            .isNotEmpty
        ? (widget.userRole == UserRole.affiliate
              ? _selectedChannelSource
              : _selectedTopStrategy)
        : _profile?.topStrategy;
    final String? activeRiskMantra =
        _riskMantraController.text.trim().isNotEmpty
        ? _riskMantraController.text.trim()
        : _profile?.riskMantra;

    openSettingsSubpage(
      context,
      title: widget.userRole == UserRole.affiliate
          ? 'Affiliate Partner Portal Preview'
          : 'Public Profile Preview',
      subtitle: widget.userRole == UserRole.affiliate
          ? 'Preview how referred traders see your partner portal & campaigns'
          : 'Preview how other traders see your public presence',
      icon: Icons.visibility_outlined,
      desktopWidthRatio: 0.60,
      page: TraderProfilePreviewPage(
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : (_profile?.displayName ?? ''),
        handle: _profile?.handle ?? '',
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : _profile?.bio,
        avatarUrl: _profile?.avatarUrl,
        userRole: widget.userRole,
        location: activeLocation,
        website: activeWebsite,
        avgHoldDuration: activeHoldDuration,
        primaryMarket: activeMarket,
        topStrategy: activeTopStrategy,
        riskMantra: activeRiskMantra,
        referralCode: _referralCodeController.text.trim(),
        channelHandle: _channelHandleController.text.trim(),
        audienceReach: _selectedAudienceReach,
        payoutMethod: _selectedPayoutMethod,
        isCurrentUser: true,
        repository: widget.communityRepository,
        author: CommunityAuthor(
          id: _profile?.id ?? '',
          handle: _profile?.handle ?? '',
          displayName:
              (_displayNameController.text.trim().isNotEmpty
                  ? _displayNameController.text.trim()
                  : _profile?.displayName) ??
              '',
          userRole: widget.userRole,
          avatarUrl: _profile?.avatarUrl,
          bio: _bioController.text.trim().isNotEmpty
              ? _bioController.text.trim()
              : _profile?.bio,
          location: activeLocation,
          website: activeWebsite,
          avgHoldDuration: activeHoldDuration,
          primaryMarket: activeMarket,
          tradingStyle: activeTopStrategy,
          riskMantra: activeRiskMantra,
          joinedDate: joined,
          followers: _profile?.followers ?? 0,
          following: _profile?.following ?? 0,
          winRate: liveWinRate,
          postsCount: livePosts,
          verified: _profile?.verified ?? false,
          tier: _profile != null
              ? appTierFromId(_profile!.subscriptionTier)
              : AppTier.free,
        ),
        onOpenRef: widget.onOpenRef,
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

    // Shaped like the loaded page — identity header, then the form sections —
    // so nothing jumps when the data lands.
    if (_loading) {
      return UiSkeleton.settingsDetail(
        showIdentity: true,
        sections: 3,
        rowsPerSection: 3,
      );
    }

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
                                  name: _displayNameController.text.isNotEmpty
                                      ? _displayNameController.text
                                      : (_profile?.displayName ?? ''),
                                  imageUrl: _profile?.avatarUrl,
                                  size: UiSize.lg,
                                  verified: _verified,
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
                                        _displayNameController.text.isNotEmpty
                                            ? _displayNameController.text
                                            : (_profile?.displayName ?? ''),
                                        style: context.uiText.heading,
                                      ),
                                      if (_verified)
                                        UiTooltip(
                                          message:
                                              widget.userRole ==
                                                  UserRole.affiliate
                                              ? 'Verified Affiliate Partner'
                                              : 'Verified trader',
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
                                    '@${_profile?.handle ?? ''}',
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
                                    width: context.sz(172),
                                    child: UiButton(
                                      label:
                                          widget.userRole == UserRole.affiliate
                                          ? 'Preview Portal'
                                          : 'Preview Profile',
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
                                    width: context.sz(172),
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
                            label: widget.userRole == UserRole.affiliate
                                ? 'Preview Partner Portal'
                                : 'Preview Public Profile',
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

              // ===============================================================
              // 1. TRADER PROFILE EDIT SECTIONS
              // ===============================================================
              if (widget.userRole == UserRole.customer) ...[
                AppSettingsSectionBlock(
                  title: 'Trader Profile Details & Identity',
                  description:
                      'Public trader alias, presence, links, and trading background.',
                  children: [
                    UiField(
                      label: 'Display Name / Alias',
                      child: UiInput(
                        value: _displayNameController.text,
                        hintText: 'Your name or alias',
                        onChanged: (v) => _displayNameController.text = v,
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiField(
                                label: 'Location / City',
                                child: UiInput(
                                  value: _locationController.text,
                                  hintText: 'e.g. Mumbai, IN or New York, US',
                                  leadingIcon: Icons.location_on_outlined,
                                  onChanged: (v) =>
                                      _locationController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              UiField(
                                label: 'Website / Profile Link',
                                child: UiInput(
                                  value: _websiteController.text,
                                  hintText:
                                      'e.g. hejournal.in/@${_profile?.handle ?? "trader"}',
                                  leadingIcon: Icons.link_rounded,
                                  onChanged: (v) => _websiteController.text = v,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: UiField(
                                label: 'Location / City',
                                child: UiInput(
                                  value: _locationController.text,
                                  hintText: 'e.g. Mumbai, IN or New York, US',
                                  leadingIcon: Icons.location_on_outlined,
                                  onChanged: (v) =>
                                      _locationController.text = v,
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: UiField(
                                label: 'Website / Profile Link',
                                child: UiInput(
                                  value: _websiteController.text,
                                  hintText:
                                      'e.g. hejournal.in/@${_profile?.handle ?? "trader"}',
                                  leadingIcon: Icons.link_rounded,
                                  onChanged: (v) => _websiteController.text = v,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiField(
                      label: 'Trader Bio',
                      helper:
                          'Displayed on your public profile, shared playbooks, and verified track record.',
                      child: UiTextarea(
                        value: _bioController.text,
                        hintText:
                            'Share your background, markets traded, or strategy style...',
                        rows: 3,
                        onChanged: (v) => _bioController.text = v,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                AppSettingsSectionBlock(
                  title: 'Trading Experience, Style & Focus',
                  description:
                      'Configures your public preview statistics, strategy badges, and trade classifications.',
                  children: [
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Experience Level',
                                    child: UiSelect<String>(
                                      value: _selectedExperience,
                                      options: _experienceOptions
                                          .map(
                                            (e) => UiOption<String>(
                                              label: e,
                                              value: e,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedExperience = v,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Primary Trading Style',
                                    child: UiSelect<String>(
                                      value: _selectedStyle,
                                      options: _tradingStyles
                                          .map(
                                            (s) => UiOption<String>(
                                              label: s,
                                              value: s,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _selectedStyle = v),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Experience Level',
                                    child: UiSelect<String>(
                                      value: _selectedExperience,
                                      options: _experienceOptions
                                          .map(
                                            (e) => UiOption<String>(
                                              label: e,
                                              value: e,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedExperience = v,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Primary Trading Style',
                                    child: UiSelect<String>(
                                      value: _selectedStyle,
                                      options: _tradingStyles
                                          .map(
                                            (s) => UiOption<String>(
                                              label: s,
                                              value: s,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _selectedStyle = v),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Primary Traded Market',
                                    child: UiSelect<String>(
                                      value: _selectedMarket,
                                      options: _marketOptions
                                          .map(
                                            (m) => UiOption<String>(
                                              label: m,
                                              value: m,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _selectedMarket = v),
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Average Trade Hold Duration',
                                    child: UiSelect<String>(
                                      value: _selectedHoldDuration,
                                      options: _holdDurations
                                          .map(
                                            (h) => UiOption<String>(
                                              label: h,
                                              value: h,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedHoldDuration = v,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Primary Traded Market',
                                    child: UiSelect<String>(
                                      value: _selectedMarket,
                                      options: _marketOptions
                                          .map(
                                            (m) => UiOption<String>(
                                              label: m,
                                              value: m,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _selectedMarket = v),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Average Trade Hold Duration',
                                    child: UiSelect<String>(
                                      value: _selectedHoldDuration,
                                      options: _holdDurations
                                          .map(
                                            (h) => UiOption<String>(
                                              label: h,
                                              value: h,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedHoldDuration = v,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiField(
                                label: 'Top Strategy / Playbook Focus',
                                child: UiSelect<String>(
                                  value: _selectedTopStrategy,
                                  options: _topStrategies
                                      .map(
                                        (t) => UiOption<String>(
                                          label: t,
                                          value: t,
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedTopStrategy = v),
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              UiField(
                                label: 'Risk Philosophy / Mantra',
                                child: UiInput(
                                  value: _riskMantraController.text,
                                  hintText:
                                      'e.g. Focus on risk management over FOMO',
                                  leadingIcon: Icons.shield_outlined,
                                  onChanged: (v) =>
                                      _riskMantraController.text = v,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: UiField(
                                label: 'Top Strategy / Playbook Focus',
                                child: UiSelect<String>(
                                  value: _selectedTopStrategy,
                                  options: _topStrategies
                                      .map(
                                        (t) => UiOption<String>(
                                          label: t,
                                          value: t,
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedTopStrategy = v),
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: UiField(
                                label: 'Risk Philosophy / Mantra',
                                child: UiInput(
                                  value: _riskMantraController.text,
                                  hintText:
                                      'e.g. Focus on risk management over FOMO',
                                  leadingIcon: Icons.shield_outlined,
                                  onChanged: (v) =>
                                      _riskMantraController.text = v,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                AppSettingsSectionBlock(
                  title: 'Public Statistics & Journal Visibility',
                  description:
                      'Controls which metrics and trade logs are publicly shared with other verified traders.',
                  children: [
                    AppSettingCard(
                      title: 'Show win-rate and public stats on profile',
                      description:
                          'Allow other verified traders to view your aggregated performance metrics and discipline scores.',
                      icon: Icons.insights_rounded,
                      control: UiSwitch(
                        value: _publicStatsEnabled,
                        onChanged: (val) =>
                            setState(() => _publicStatsEnabled = val),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    AppSettingCard(
                      title: 'Show verified trade logs in public journal',
                      description:
                          'Display broker-hashed executed trades in your public journal tab.',
                      icon: Icons.auto_stories_outlined,
                      control: UiSwitch(
                        value: _publicJournalsEnabled,
                        onChanged: (val) =>
                            setState(() => _publicJournalsEnabled = val),
                      ),
                    ),
                  ],
                ),
              ]
              // ===============================================================
              // 2. AFFILIATE PARTNER 4-STEP PROFILE EDIT ARCHITECTURE
              // ===============================================================
              else if (widget.userRole == UserRole.affiliate) ...[
                // STEP 1: Partner Identity & Personal Contact
                AppSettingsSectionBlock(
                  title: 'Step 1: Partner Identity & Contact Details',
                  description:
                      'Official partner alias, verified contact information, and public promotional presence.',
                  children: [
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Partner / Channel Name',
                                    child: UiInput(
                                      value: _displayNameController.text,
                                      hintText:
                                          'e.g. Nitish Kumar or DesignTrades',
                                      leadingIcon: Icons.badge_outlined,
                                      onChanged: (v) =>
                                          _displayNameController.text = v,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Verified Phone Number',
                                    child: UiInput(
                                      value: _phoneController.text,
                                      hintText: '+91 98765 43210',
                                      leadingIcon: Icons.phone_outlined,
                                      onChanged: (v) =>
                                          _phoneController.text = v,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Partner / Channel Name',
                                    child: UiInput(
                                      value: _displayNameController.text,
                                      hintText:
                                          'e.g. Nitish Kumar or DesignTrades',
                                      leadingIcon: Icons.badge_outlined,
                                      onChanged: (v) =>
                                          _displayNameController.text = v,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Verified Phone Number',
                                    child: UiInput(
                                      value: _phoneController.text,
                                      hintText: '+91 98765 43210',
                                      leadingIcon: Icons.phone_outlined,
                                      onChanged: (v) =>
                                          _phoneController.text = v,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiField(
                                label: 'Location / State',
                                child: UiInput(
                                  value: _locationController.text,
                                  hintText: 'e.g. Mumbai, Maharashtra',
                                  leadingIcon: Icons.location_on_outlined,
                                  onChanged: (v) =>
                                      _locationController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              UiField(
                                label: 'Primary Channel / Website URL',
                                child: UiInput(
                                  value: _websiteController.text,
                                  hintText:
                                      'e.g. https://youtube.com/@designtrades',
                                  leadingIcon: Icons.link_rounded,
                                  onChanged: (v) => _websiteController.text = v,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: UiField(
                                label: 'Location / State',
                                child: UiInput(
                                  value: _locationController.text,
                                  hintText: 'e.g. Mumbai, Maharashtra',
                                  leadingIcon: Icons.location_on_outlined,
                                  onChanged: (v) =>
                                      _locationController.text = v,
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: UiField(
                                label: 'Primary Channel / Website URL',
                                child: UiInput(
                                  value: _websiteController.text,
                                  hintText:
                                      'e.g. https://youtube.com/@designtrades',
                                  leadingIcon: Icons.link_rounded,
                                  onChanged: (v) => _websiteController.text = v,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiField(
                      label: 'Partner & Creator Bio',
                      helper:
                          'Displayed on your public partner landing page and referral campaigns.',
                      child: UiTextarea(
                        value: _bioController.text,
                        hintText:
                            'Describe your audience, channels, and trading education focus...',
                        rows: 3,
                        onChanged: (v) => _bioController.text = v,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),

                // STEP 2: Digital Presence & Audience Channels
                AppSettingsSectionBlock(
                  title: 'Step 2: Digital Presence & Audience Channels',
                  description:
                      'Primary distribution platforms where you share referral codes, setups, and webinars.',
                  children: [
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Primary Promotion Channel',
                                    child: UiSelect<String>(
                                      value: _selectedChannelSource,
                                      options: _affiliateChannels
                                          .map(
                                            (c) => UiOption<String>(
                                              label: c,
                                              value: c,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedChannelSource = v,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Channel Handle / Username',
                                    child: UiInput(
                                      value: _channelHandleController.text,
                                      hintText: 'e.g. @designtrades',
                                      leadingIcon:
                                          Icons.alternate_email_rounded,
                                      onChanged: (v) =>
                                          _channelHandleController.text = v,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Primary Promotion Channel',
                                    child: UiSelect<String>(
                                      value: _selectedChannelSource,
                                      options: _affiliateChannels
                                          .map(
                                            (c) => UiOption<String>(
                                              label: c,
                                              value: c,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedChannelSource = v,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Channel Handle / Username',
                                    child: UiInput(
                                      value: _channelHandleController.text,
                                      hintText: 'e.g. @designtrades',
                                      leadingIcon:
                                          Icons.alternate_email_rounded,
                                      onChanged: (v) =>
                                          _channelHandleController.text = v,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Estimated Audience Reach',
                                    child: UiSelect<String>(
                                      value: _selectedAudienceReach,
                                      options: _audienceReachOptions
                                          .map(
                                            (a) => UiOption<String>(
                                              label: a,
                                              value: a,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedAudienceReach = v,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Primary Content Niche',
                                    child: UiSelect<String>(
                                      value: _selectedNiche,
                                      options: _nicheOptions
                                          .map(
                                            (n) => UiOption<String>(
                                              label: n,
                                              value: n,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _selectedNiche = v),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Estimated Audience Reach',
                                    child: UiSelect<String>(
                                      value: _selectedAudienceReach,
                                      options: _audienceReachOptions
                                          .map(
                                            (a) => UiOption<String>(
                                              label: a,
                                              value: a,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedAudienceReach = v,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Primary Content Niche',
                                    child: UiSelect<String>(
                                      value: _selectedNiche,
                                      options: _nicheOptions
                                          .map(
                                            (n) => UiOption<String>(
                                              label: n,
                                              value: n,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _selectedNiche = v),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiField(
                      label: 'Sample Video / Content Portfolio Link',
                      child: UiInput(
                        value: _sampleLinkController.text,
                        hintText:
                            'e.g. https://youtube.com/watch?v=sample_workshop',
                        leadingIcon: Icons.smart_display_outlined,
                        onChanged: (v) => _sampleLinkController.text = v,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),

                // STEP 3: Payout & Banking Configuration
                AppSettingsSectionBlock(
                  title: 'Step 3: Payout & Tax Configuration',
                  description:
                      'Secure banking, UPI, and tax ID information for monthly automated commission disbursements.',
                  children: [
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Preferred Payout Method',
                                    child: UiSelect<String>(
                                      value: _selectedPayoutMethod,
                                      options: _payoutMethods
                                          .map(
                                            (p) => UiOption<String>(
                                              label: p,
                                              value: p,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedPayoutMethod = v,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Account Holder Full Name',
                                    child: UiInput(
                                      value: _accountHolderController.text,
                                      hintText: 'Must match government ID',
                                      leadingIcon: Icons.person_outline_rounded,
                                      onChanged: (v) =>
                                          _accountHolderController.text = v,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Preferred Payout Method',
                                    child: UiSelect<String>(
                                      value: _selectedPayoutMethod,
                                      options: _payoutMethods
                                          .map(
                                            (p) => UiOption<String>(
                                              label: p,
                                              value: p,
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _selectedPayoutMethod = v,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Account Holder Full Name',
                                    child: UiInput(
                                      value: _accountHolderController.text,
                                      hintText: 'Must match government ID',
                                      leadingIcon: Icons.person_outline_rounded,
                                      onChanged: (v) =>
                                          _accountHolderController.text = v,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'Bank Name',
                                    child: UiInput(
                                      value: _bankNameController.text,
                                      hintText: 'e.g. HDFC Bank, ICICI Bank',
                                      leadingIcon:
                                          Icons.account_balance_outlined,
                                      onChanged: (v) =>
                                          _bankNameController.text = v,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'Account Number',
                                    child: UiInput(
                                      value: _accountNumberController.text,
                                      hintText: '123456789012',
                                      leadingIcon: Icons.numbers_rounded,
                                      onChanged: (v) =>
                                          _accountNumberController.text = v,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'Bank Name',
                                    child: UiInput(
                                      value: _bankNameController.text,
                                      hintText: 'e.g. HDFC Bank, ICICI Bank',
                                      leadingIcon:
                                          Icons.account_balance_outlined,
                                      onChanged: (v) =>
                                          _bankNameController.text = v,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'Account Number',
                                    child: UiInput(
                                      value: _accountNumberController.text,
                                      hintText: '123456789012',
                                      leadingIcon: Icons.numbers_rounded,
                                      onChanged: (v) =>
                                          _accountNumberController.text = v,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  UiField(
                                    label: 'IFSC Code',
                                    child: UiInput(
                                      value: _ifscController.text,
                                      hintText: 'e.g. HDFC0001234',
                                      leadingIcon: Icons.pin_outlined,
                                      onChanged: (v) =>
                                          _ifscController.text = v,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'PAN / Tax ID',
                                    child: UiInput(
                                      value: _panController.text,
                                      hintText: 'e.g. ABCDE1234F',
                                      leadingIcon: Icons.credit_card_outlined,
                                      onChanged: (v) => _panController.text = v,
                                    ),
                                  ),
                                  SizedBox(
                                    height: context.sp(theme.spacing.sm),
                                  ),
                                  UiField(
                                    label: 'UPI Virtual ID (VPA)',
                                    child: UiInput(
                                      value: _upiController.text,
                                      hintText: 'e.g. design@upi',
                                      leadingIcon: Icons.qr_code_2_rounded,
                                      onChanged: (v) => _upiController.text = v,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: UiField(
                                    label: 'IFSC Code',
                                    child: UiInput(
                                      value: _ifscController.text,
                                      hintText: 'e.g. HDFC0001234',
                                      leadingIcon: Icons.pin_outlined,
                                      onChanged: (v) =>
                                          _ifscController.text = v,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'PAN / Tax ID',
                                    child: UiInput(
                                      value: _panController.text,
                                      hintText: 'e.g. ABCDE1234F',
                                      leadingIcon: Icons.credit_card_outlined,
                                      onChanged: (v) => _panController.text = v,
                                    ),
                                  ),
                                ),
                                SizedBox(width: context.sp(theme.spacing.md)),
                                Expanded(
                                  child: UiField(
                                    label: 'UPI Virtual ID (VPA)',
                                    child: UiInput(
                                      value: _upiController.text,
                                      hintText: 'e.g. design@upi',
                                      leadingIcon: Icons.qr_code_2_rounded,
                                      onChanged: (v) => _upiController.text = v,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),

                // STEP 4: Referral Portal, Terms & Visibility
                AppSettingsSectionBlock(
                  title: 'Step 4: Referral Portal, Terms & Visibility',
                  description:
                      'Referral code branding, automated payouts, and public leaderboard badges.',
                  children: [
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiField(
                                label: 'Custom Referral Code',
                                helper:
                                    'Used in your direct signup links (e.g. hejournal.in/join/CODE)',
                                child: UiInput(
                                  value: _referralCodeController.text,
                                  hintText: 'TRADEX-PARTNER-2026',
                                  leadingIcon: Icons.vpn_key_rounded,
                                  onChanged: (v) =>
                                      _referralCodeController.text = v,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              UiField(
                                label: 'Commission Tier Status',
                                helper:
                                    'Gold Partner: 30% lifetime recurring commission',
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.sp(theme.spacing.md),
                                    vertical: context.sp(theme.spacing.sm),
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: context.radius(
                                      theme.radii.md,
                                    ),
                                    border: Border.all(color: colors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        color: colors.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tier 2 · Gold Partner (30%)',
                                          overflow: TextOverflow.ellipsis,
                                          style: context.uiText.bodyStrong
                                              .copyWith(color: colors.warning),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: UiField(
                                label: 'Custom Referral Code',
                                helper:
                                    'Used in your direct signup links (e.g. hejournal.in/join/CODE)',
                                child: UiInput(
                                  value: _referralCodeController.text,
                                  hintText: 'TRADEX-PARTNER-2026',
                                  leadingIcon: Icons.vpn_key_rounded,
                                  onChanged: (v) =>
                                      _referralCodeController.text = v,
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: UiField(
                                label: 'Commission Tier Status',
                                helper:
                                    'Gold Partner: 30% lifetime recurring commission',
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: context.sp(theme.spacing.md),
                                    vertical: context.sp(theme.spacing.sm),
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: context.radius(
                                      theme.radii.md,
                                    ),
                                    border: Border.all(color: colors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_rounded,
                                        color: colors.warning,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Tier 2 · Gold Partner (30%)',
                                          overflow: TextOverflow.ellipsis,
                                          style: context.uiText.bodyStrong
                                              .copyWith(color: colors.warning),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    AppSettingCard(
                      title: 'Automated Monthly Payouts (₹2,500 Threshold)',
                      description:
                          'Automatically process payout to your registered bank / UPI on the 1st of every month once threshold is met.',
                      icon: Icons.autorenew_rounded,
                      control: UiSwitch(
                        value: _autoPayoutEnabled,
                        onChanged: (val) =>
                            setState(() => _autoPayoutEnabled = val),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
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
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    AppSettingCard(
                      title: 'Show Verified Referral Volume & Conversion Stats',
                      description:
                          'Allow potential subscribers to see your total referral count and partner reliability score.',
                      icon: Icons.insights_rounded,
                      control: UiSwitch(
                        value: _publicJournalsEnabled,
                        onChanged: (val) =>
                            setState(() => _publicJournalsEnabled = val),
                      ),
                    ),
                  ],
                ),
              ]
              // ===============================================================
              // 3. ADMIN IDENTITY & ROOT GOVERNANCE SECTION
              // ===============================================================
              else if (widget.userRole == UserRole.userAdmin) ...[
                AppSettingsSectionBlock(
                  title: 'Step 1: Root Authority & Institutional Clearance',
                  description:
                      'Desk classification, clearance level, and capital supervision boundaries.',
                  children: [
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiField(
                                label: 'Clearance Level',
                                helper:
                                    'Unrestricted execution & risk engine override',
                                child: UiInput(
                                  controller: _adminClearanceLevelController,
                                  leadingIcon: Icons.shield_rounded,
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              UiField(
                                label: 'Designated Firm Role',
                                helper:
                                    'Title displayed on compliance disclosures',
                                child: UiInput(
                                  controller: _adminDesignationController,
                                  leadingIcon: Icons.badge_outlined,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: UiField(
                                label: 'Clearance Level',
                                helper:
                                    'Unrestricted execution & risk engine override',
                                child: UiInput(
                                  controller: _adminClearanceLevelController,
                                  leadingIcon: Icons.shield_rounded,
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: UiField(
                                label: 'Designated Firm Role',
                                helper:
                                    'Title displayed on compliance disclosures',
                                child: UiInput(
                                  controller: _adminDesignationController,
                                  leadingIcon: Icons.badge_outlined,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final bool isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              UiField(
                                label: 'Primary Desk Division',
                                child: UiSelect<String>(
                                  value: _selectedDeskDivision,
                                  options: _deskDivisions
                                      .map(
                                        (d) => UiOption<String>(
                                          label: d,
                                          value: d,
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedDeskDivision = v),
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.sm)),
                              UiField(
                                label: 'Supervised Capital Allocation Pool',
                                helper:
                                    'Aggregate firm capital monitored across 8 desks',
                                child: UiInput(
                                  controller: _adminSupervisedCapitalController,
                                  leadingIcon:
                                      Icons.account_balance_wallet_outlined,
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: UiField(
                                label: 'Primary Desk Division',
                                child: UiSelect<String>(
                                  value: _selectedDeskDivision,
                                  options: _deskDivisions
                                      .map(
                                        (d) => UiOption<String>(
                                          label: d,
                                          value: d,
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedDeskDivision = v),
                                ),
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.md)),
                            Expanded(
                              child: UiField(
                                label: 'Supervised Capital Allocation Pool',
                                helper:
                                    'Aggregate firm capital monitored across 8 desks',
                                child: UiInput(
                                  controller: _adminSupervisedCapitalController,
                                  leadingIcon:
                                      Icons.account_balance_wallet_outlined,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.lg)),
                AppSettingsSectionBlock(
                  title: 'Step 2: Platform Risk Safeguards & Audit Ledger',
                  description:
                      'Emergency execution authority and cryptographic governance controls.',
                  children: [
                    AppSettingCard(
                      title: 'One-Click Emergency Killswitch Authorization',
                      description:
                          'Arm your admin session with instant trading halt authority across all broker routing gateways.',
                      icon: Icons.crisis_alert_rounded,
                      control: UiSwitch(
                        value: _adminKillswitchEnabled,
                        onChanged: (val) =>
                            setState(() => _adminKillswitchEnabled = val),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    AppSettingCard(
                      title: 'Sub-Millisecond Pre-Trade VaR Margin Checks',
                      description:
                          'Enforce sub-millisecond credit and margin calculations before order dissemination.',
                      icon: Icons.speed_rounded,
                      control: UiSwitch(
                        value: _adminPreTradeVaREnabled,
                        onChanged: (val) =>
                            setState(() => _adminPreTradeVaREnabled = val),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    AppSettingCard(
                      title: 'Cryptographic SHA-256 Audit Trail Hashing',
                      description:
                          'Generate immutable cryptographic audit packages for SEBI and exchange regulatory reviews.',
                      icon: Icons.security_rounded,
                      control: UiSwitch(
                        value: _adminAuditHashingEnabled,
                        onChanged: (val) =>
                            setState(() => _adminAuditHashingEnabled = val),
                      ),
                    ),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    AppSettingCard(
                      title: 'Public Desk Governance & Uptime Telemetry',
                      description:
                          'Display verified desk health, latency stats, and risk matrix on your public admin preview.',
                      icon: Icons.visibility_outlined,
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
                    label: widget.userRole == UserRole.affiliate
                        ? 'Save Partner Settings'
                        : 'Save Changes',
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
