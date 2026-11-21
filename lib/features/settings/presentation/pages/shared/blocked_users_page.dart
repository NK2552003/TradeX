import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/settings/data/repositories/privacy_repository.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key, this.repository});

  final PrivacyRepository? repository;

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  late final PrivacyRepository _repo;
  List<AppTrader> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PrivacyRepositoryImpl();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUnblockDialog(AppTrader trader) {
    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Unblock @${trader.handle}?',
        content: Text(
          'They will once again be able to view your public profile, posts, and send you direct messages.',
          style: context.uiText.body,
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Unblock Trader',
            intent: UiIntent.primary,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _repo.unblockUser(trader.id);
              if (mounted) {
                setState(() {
                  _blockedUsers.removeWhere((u) => u.id == trader.id);
                });
                UiToast.show(
                  context,
                  title: 'User Unblocked',
                  message: '@${trader.handle} has been unblocked.',
                  intent: UiIntent.info,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    // The page renders inside the shell, and on a phone the dock floats over the
    // bottom of it, so the last row needs to be able to scroll clear of it.
    final bool isMobile = context.uiRes.isMobile;
    final double pagePad = context.sp(
      isMobile ? theme.spacing.md : theme.spacing.lg,
    );
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      pagePad,
      MediaQuery.paddingOf(context).top + pagePad,
      pagePad,
      isMobile ? context.uiPageBottomInset : pagePad,
    );

    if (_loading) {
      return UiSkeleton.settingsList(showHeader: false, rows: 4);
    }

    if (_blockedUsers.isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'No Blocked Users',
          message:
              'You have not blocked any users. Blocked accounts will appear here.',
        ),
      );
    }

    return ListView.separated(
      padding: padding,
      itemCount: _blockedUsers.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: context.sp(theme.spacing.sm)),
      itemBuilder: (context, index) {
        final trader = _blockedUsers[index];
        return UiCard(
          child: Row(
            children: [
              UiAvatar(
                name: trader.displayName ?? trader.handle,
                imageUrl: trader.avatarUrl,
                size: UiSize.md,
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trader.displayName ?? trader.handle,
                      style: context.uiText.bodyStrong,
                    ),
                    Text(
                      '@${trader.handle}',
                      style: context.uiText.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              UiButton(
                label: 'Unblock',
                variant: UiVariant.outline,
                size: UiSize.sm,
                onPressed: () => _showUnblockDialog(trader),
              ),
            ],
          ),
        );
      },
    );
  }
}
