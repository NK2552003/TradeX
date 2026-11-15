import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/features/auth/widgets/auth_carousel_panel.dart';
import 'private_message_service.dart';

typedef PrivateMessagingStatusCheck =
    Future<({bool unlocked, bool hasIdentity})> Function();
typedef PrivateMessagingUnlockAction = Future<void> Function(String passphrase);

/// Keeps private screens closed until their account's encryption key is ready.
class PrivateMessagingGate extends StatefulWidget {
  const PrivateMessagingGate({
    super.key,
    required this.builder,
    this.onLogout,
    this.checkStatus,
    this.unlockWithPassphrase,
  });

  final WidgetBuilder builder;
  final VoidCallback? onLogout;
  final PrivateMessagingStatusCheck? checkStatus;
  final PrivateMessagingUnlockAction? unlockWithPassphrase;

  @override
  State<PrivateMessagingGate> createState() => _PrivateMessagingGateState();
}

class _PrivateMessagingGateState extends State<PrivateMessagingGate> {
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  bool _ready = false;
  bool _initializing = true;
  bool _loading = true;
  bool _exists = false;
  bool _checkFailed = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _check(initial: true);
  }

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String _describeError(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }
    if (error is UnsupportedError) {
      return 'Secure browser storage requires HTTPS (or localhost). Open AlphaJournal over HTTPS to unlock private messaging.';
    }
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      final code = error.code;
      if (code == '42P01' || code == 'PGRST205') {
        return 'Encrypted messaging tables are not deployed on the backend yet. Run the database migration and retry.';
      }
      if (code == '42501') {
        return 'Your session does not have permission to access encrypted storage. Try signing out and back in.';
      }
      return 'Could not reach encrypted storage (${code ?? 'database error'}). Check your connection and retry.';
    }
    return 'Encrypted storage is unavailable. Check your connection and try again.';
  }

  Future<void> _check({bool initial = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
        if (!initial) {
          _checkFailed = false;
        }
      });
    }
    try {
      final statusCheck = widget.checkStatus;
      if (statusCheck == null && !SupabaseConfig.isConfigured) {
        if (mounted) {
          setState(() {
            _ready = true;
            _exists = false;
            _checkFailed = false;
            _initializing = false;
          });
        }
        return;
      }

      final status = await (statusCheck != null
          ? statusCheck()
          : PrivateMessageService.instance.checkStatus());

      if (mounted) {
        setState(() {
          _ready = status.unlocked;
          _exists = status.hasIdentity;
          _checkFailed = false;
          _initializing = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[PrivateMessagingGate] Status check failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _checkFailed = true;
          _initializing = false;
          _error = _describeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unlock() async {
    if (_loading || _checkFailed) return;
    final passphrase = _passphraseController.text;
    final confirmation = _confirmationController.text;

    if (!_exists && passphrase.trim().length < 16) {
      setState(
        () => _error =
            'Choose a recovery passphrase of at least 16 characters and save it in your password manager.',
      );
      return;
    }
    if (!_exists && passphrase != confirmation) {
      setState(() => _error = 'The passphrases do not match.');
      return;
    }
    if (_exists && passphrase.isEmpty) {
      setState(() => _error = 'Please enter your recovery passphrase.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final action = widget.unlockWithPassphrase;
      if (action != null) {
        await action(passphrase);
      } else {
        await PrivateMessageService.instance.unlock(passphrase);
      }
      if (mounted) {
        _passphraseController.clear();
        _confirmationController.clear();
        setState(() {
          _ready = true;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('[PrivateMessagingGate] Unlock failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _error = error is StateError
              ? error.message.toString()
              : _describeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.builder(context);

    final theme = context.ui;
    final colors = theme.colors;
    final responsive = context.uiRes;
    final bool showSidePanel = responsive.width >= 900;
    final double maxWidth = showSidePanel ? context.sz(940) : context.sz(440);

    return Scaffold(
      backgroundColor: colors.background,
      body: AlphaThreadBackdrop.auth(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 360
                              ? context.sp(theme.spacing.sm)
                              : context.sp(theme.spacing.md),
                          vertical: context.sp(theme.spacing.xl),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              UiCard(
                                variant: UiCardVariant.surface,
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                            context.sp(
                                              constraints.maxWidth < 360
                                                  ? theme.spacing.md
                                                  : (responsive.isMobile
                                                        ? theme.spacing.lg
                                                        : theme.spacing.xl),
                                            ),
                                          ),
                                          child: _buildFormColumn(
                                            context,
                                            isMobile: responsive.isMobile,
                                          ),
                                        ),
                                      ),
                                      if (showSidePanel)
                                        Expanded(
                                          child: SizedBox(
                                            height: 640,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                    color: colors.border,
                                                    width:
                                                        theme.borders.hairline,
                                                  ),
                                                ),
                                              ),
                                              child: const AuthCarouselPanel(),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: context.sp(theme.spacing.md)),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: constraints.maxWidth < 360
                                      ? context.sp(theme.spacing.sm)
                                      : context.sp(theme.spacing.md),
                                ),
                                child: Text(
                                  'End-to-end encrypted with X25519 & AES-256-GCM. Private keys stay on your device.',
                                  textAlign: TextAlign.center,
                                  style: context.uiText.caption.copyWith(
                                    color: colors.foregroundSubtle,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isMobile}) {
    final theme = context.ui;
    final String badgeLabel = _initializing
        ? 'VERIFYING'
        : _checkFailed
        ? 'CONNECTION ISSUE'
        : _exists
        ? 'DEVICE UNLOCK'
        : 'FIRST-TIME SETUP';
    final UiIntent badgeIntent = _checkFailed
        ? UiIntent.danger
        : _exists
        ? UiIntent.info
        : UiIntent.primary;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.sp(theme.spacing.sm),
      runSpacing: context.sp(theme.spacing.sm),
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppLogoMark(size: 20),
            if (!isMobile) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                'AlphaJournal',
                style: context.uiText.bodyStrong.copyWith(
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
        UiBadge(
          label: badgeLabel,
          intent: badgeIntent,
          variant: UiBadgeVariant.soft,
          size: UiSize.sm,
        ),
      ],
    );
  }

  Widget _buildFormColumn(BuildContext context, {required bool isMobile}) {
    final theme = context.ui;
    final colors = theme.colors;

    if (_initializing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHeader(context, isMobile: isMobile),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text(
            'Private messaging',
            style: context.uiText.display.copyWith(
              fontSize: 28.0,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            'Checking your encrypted messaging identity…',
            style: context.uiText.body.copyWith(
              color: colors.foregroundMuted,
              fontSize: 13.5,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          UiSkeleton.text(lines: 2, spacing: 10),
          SizedBox(height: context.sp(theme.spacing.lg)),
          const UiSkeleton(height: 44),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiSkeleton(height: 44),
        ],
      );
    }

    final int trimmedLength = _passphraseController.text.trim().length;
    final bool hasConfirmationMismatch =
        !_exists &&
        _confirmationController.text.isNotEmpty &&
        _passphraseController.text != _confirmationController.text;

    final String heading = _checkFailed
        ? 'Encrypted storage unavailable'
        : _exists
        ? 'Unlock private messages'
        : 'Secure private messaging';
    final String subtitle = _checkFailed
        ? 'We could not check your encryption identity right now.'
        : _exists
        ? 'Enter your recovery passphrase to restore your messaging key on this device.'
        : 'Set a recovery passphrase to protect your direct messages and AI workspace.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildHeader(context, isMobile: isMobile),
        SizedBox(height: context.sp(theme.spacing.xl)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              heading,
              textAlign: TextAlign.left,
              style: context.uiText.display.copyWith(
                fontSize: 28.0,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              subtitle,
              textAlign: TextAlign.left,
              style: context.uiText.body.copyWith(
                color: colors.foregroundMuted,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.lg)),
        if (_error.isNotEmpty) ...<Widget>[
          UiCallout(
            title: 'Unable to continue',
            message: _error,
            intent: UiIntent.danger,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
        ],
        if (_checkFailed) ...<Widget>[
          UiCallout(
            title: 'What you can try',
            message:
                'Verify your internet connection, ensure you are on HTTPS, or retry the check below. If the problem persists, sign out and back in.',
            intent: UiIntent.info,
            icon: Icons.wifi_tethering_error_rounded,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiButton(
            label: _loading ? 'Retrying…' : 'Retry connection',
            leadingIcon: Icons.refresh_rounded,
            variant: UiVariant.primary,
            intent: UiIntent.primary,
            size: UiSize.lg,
            expand: true,
            loading: _loading,
            onPressed: _loading ? null : () => _check(),
          ),
          if (widget.onLogout != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiButton(
              label: 'Sign out',
              leadingIcon: Icons.logout_rounded,
              variant: UiVariant.outline,
              intent: UiIntent.neutral,
              size: UiSize.lg,
              expand: true,
              onPressed: _loading ? null : widget.onLogout,
            ),
          ],
        ] else ...<Widget>[
          UiCallout(
            title: _exists ? 'Restore on this device' : 'Your recovery passphrase',
            message: _exists
                ? 'Enter the same recovery passphrase you created on your first device. Your unlocked key stays encrypted locally.'
                : 'Choose a unique passphrase of at least 16 characters and save it in a password manager. We cannot reset or recover it for you. New messages and AI workspace saves are encrypted before upload; AI replies still read prompts server-side.',
            intent: UiIntent.info,
            icon: Icons.lock_outline_rounded,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiField(
            label: 'Recovery passphrase',
            required: true,
            helper: !_exists
                ? '${trimmedLength.clamp(0, 16)}/16 minimum characters'
                : null,
            child: UiPasswordField(
              controller: _passphraseController,
              hintText: _exists
                  ? 'Enter recovery passphrase'
                  : 'At least 16 characters',
              showStrength: !_exists,
              textInputAction: _exists
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: _exists ? (_) => _unlock() : null,
              onChanged: (_) => setState(() {
                if (_error.isNotEmpty) _error = '';
              }),
            ),
          ),
          if (!_exists) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiField(
              label: 'Confirm recovery passphrase',
              required: true,
              error: hasConfirmationMismatch
                  ? 'Passphrases do not match'
                  : null,
              child: UiPasswordField(
                controller: _confirmationController,
                hintText: 'Re-enter recovery passphrase',
                showStrength: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _unlock(),
                onChanged: (_) => setState(() {
                  if (_error.isNotEmpty) _error = '';
                }),
              ),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiButton(
            label: _loading
                ? (_exists ? 'Unlocking…' : 'Creating identity…')
                : (_exists ? 'Unlock history' : 'Create encrypted identity'),
            leadingIcon: _exists
                ? Icons.lock_open_rounded
                : Icons.enhanced_encryption_outlined,
            variant: UiVariant.primary,
            intent: UiIntent.primary,
            size: UiSize.lg,
            expand: true,
            loading: _loading,
            onPressed: _loading ? null : _unlock,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          const UiDivider(label: 'Need another option?'),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: 'Refresh status',
                  leadingIcon: Icons.refresh_rounded,
                  variant: UiVariant.outline,
                  intent: UiIntent.neutral,
                  size: UiSize.md,
                  expand: true,
                  onPressed: _loading ? null : () => _check(),
                ),
              ),
              if (widget.onLogout != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: UiButton(
                    label: 'Sign out',
                    leadingIcon: Icons.logout_rounded,
                    variant: UiVariant.outline,
                    intent: UiIntent.neutral,
                    size: UiSize.md,
                    expand: true,
                    onPressed: _loading ? null : widget.onLogout,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
