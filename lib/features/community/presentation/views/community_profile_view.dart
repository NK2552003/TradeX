import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/settings/presentation/pages/shared/trader_profile_preview_page.dart';

/// Twitter-style profile page for any trader in the community.
///
/// Seamlessly integrates the comprehensive [TraderProfilePreviewPage] from
/// settings, presenting role-specific dashboards, journals, playbooks, and
/// partner portals for Customers, Affiliates, and Desk Admins.
class CommunityProfileView extends StatefulWidget {
  const CommunityProfileView({
    super.key,
    required this.author,
    required this.repository,
    this.isCurrentUser = false,
    this.onBack,
    this.showHeader = true,
    this.onFollow,
    this.onPostTap,
    this.onOpenRef,
    this.onDirectMessage,
  });

  final CommunityAuthor author;
  final CommunityRepository repository;
  final bool isCurrentUser;
  final VoidCallback? onBack;
  final bool showHeader;
  final ValueChanged<CommunityAuthor>? onFollow;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final void Function(AppTrader trader)? onDirectMessage;

  /// Opens a clean right-side profile overlay without a header bar — only a
  /// sleek floating `×` close button over the profile content.
  static Future<void> showOverlay(
    BuildContext context, {
    required CommunityAuthor author,
    required CommunityRepository repository,
    bool isCurrentUser = false,
    ValueChanged<CommunityPost>? onPostTap,
    ValueChanged<AppLinkRef>? onOpenRef,
    void Function(AppTrader trader)? onDirectMessage,
  }) => UiDrawer.show<void>(
    context,
    title: author.displayName,
    width: 640,
    fromRight: true,
    scrollable: false,
    showHeader: false,
    contentPadding: EdgeInsets.zero,
    child: LayoutBuilder(
      builder: (BuildContext drawerCtx, BoxConstraints constraints) {
        final UiTheme theme = drawerCtx.ui;
        return MediaQuery(
          data: MediaQuery.of(drawerCtx).copyWith(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            padding: MediaQuery.paddingOf(drawerCtx).copyWith(top: 0),
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: CommunityProfileView(
                  author: author,
                  repository: repository,
                  isCurrentUser: isCurrentUser,
                  showHeader: false,
                  onPostTap: onPostTap,
                  onOpenRef: onOpenRef,
                  onDirectMessage: onDirectMessage,
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: theme.colors.surface.withValues(alpha: 0.86),
                  shape: CircleBorder(
                    side: BorderSide(color: theme.colors.border),
                  ),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(drawerCtx).pop(),
                    child: Tooltip(
                      message: 'Close',
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colors.foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  @override
  State<CommunityProfileView> createState() => _CommunityProfileViewState();
}

class _CommunityProfileViewState extends State<CommunityProfileView> {
  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    final bool showAppBar =
        widget.showHeader && !widget.isCurrentUser && widget.onBack != null;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: theme.colors.surface,
              elevation: 0,
              leading: UiIconButton(
                icon: Icons.arrow_back_rounded,
                size: UiSize.sm,
                tooltip: 'Back',
                onPressed: widget.onBack,
              ),
              title: Row(
                children: <Widget>[
                  Text(
                    widget.author.displayName,
                    style: context.uiText.heading.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.author.verified) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xxs)),
                    Icon(
                      Icons.verified_rounded,
                      color: widget.author.verifiedColor(theme),
                      size: context.sz(16),
                    ),
                  ],
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: theme.colors.border.withValues(alpha: 0.6),
                  height: theme.borders.hairline,
                ),
              ),
            )
          : null,
      body: TraderProfilePreviewPage(
        displayName: widget.author.displayName,
        handle: widget.author.handle,
        userRole: widget.author.userRole,
        forceTraderView: true,
        bio: widget.author.bio,
        avatarUrl: widget.author.avatarUrl,
        location: widget.author.location,
        website: widget.author.website,
        primaryMarket: widget.author.primaryMarket,
        topStrategy: widget.author.tradingStyle,
        avgHoldDuration: widget.author.avgHoldDuration,
        riskMantra: widget.author.riskMantra,
        referralCode: widget.author.referralCode,
        channelHandle: widget.author.channelHandle,
        audienceReach: widget.author.audienceReach,
        repository: widget.repository,
        author: widget.author,
        subscriptionTier: widget.author.subscriptionTier,
        verified: widget.author.verified,
        onPostTap: widget.onPostTap,
        onOpenRef: widget.onOpenRef,
        isCurrentUser: widget.isCurrentUser,
      ),
    );
  }
}
