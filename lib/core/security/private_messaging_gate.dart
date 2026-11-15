import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'private_message_service.dart';

/// Keeps private screens closed until their account's encryption key is ready.
class PrivateMessagingGate extends StatefulWidget {
  const PrivateMessagingGate({super.key, required this.builder, this.onLogout});
  final WidgetBuilder builder;
  final VoidCallback? onLogout;
  @override
  State<PrivateMessagingGate> createState() => _PrivateMessagingGateState();
}

class _PrivateMessagingGateState extends State<PrivateMessagingGate> {
  bool _ready = false, _loading = true;
  String _passphrase = '', _confirmation = '', _error = '';
  bool _exists = false;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final ready =
          !SupabaseConfig.isConfigured ||
          await PrivateMessageService.instance.isUnlocked();
      final exists =
          SupabaseConfig.isConfigured &&
          await PrivateMessageService.instance.hasIdentity();
      if (mounted) {
        setState(() {
          _ready = ready;
          _exists = exists;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Encrypted storage is unavailable. Check your connection and the encryption database deployment.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlock() async {
    if (!_exists && _passphrase != _confirmation) {
      setState(() => _error = 'The passphrases do not match.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await PrivateMessageService.instance.unlock(_passphrase);
      if (mounted) {
        setState(() {
          _ready = true;
          _passphrase = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Unable to unlock encrypted storage. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.builder(context);
    return UiPage(
      title: 'Private messaging',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiCallout(
            title: 'Your recovery passphrase',
            message:
                'On your first device, choose a unique passphrase of at least 16 characters and save it in a password manager. On another device, enter that same passphrase. We cannot recover it for you. New messages and AI workspace saves are encrypted before storage. Earlier history may be unencrypted. The AI service still reads prompts while generating replies.',
          ),
          UiGap.v(context.ui.spacing.md),
          UiPasswordField(
            label: 'Recovery passphrase',
            value: _passphrase,
            onChanged: (value) => _passphrase = value,
          ),
          if (!_exists) ...[
            UiGap.v(context.ui.spacing.md),
            UiPasswordField(
              label: 'Confirm recovery passphrase',
              value: _confirmation,
              onChanged: (value) => _confirmation = value,
            ),
          ],
          UiGap.v(context.ui.spacing.md),
          if (_error.isNotEmpty)
            UiCallout(
              title: 'Unable to continue',
              message: _error,
              intent: UiIntent.danger,
            ),
          UiButton(
            label: _loading
                ? 'Please wait…'
                : _exists
                ? 'Unlock history'
                : 'Create encrypted identity',
            onPressed: _loading ? null : _unlock,
          ),
          if (widget.onLogout != null)
            UiButton(
              label: 'Sign out',
              variant: UiVariant.ghost,
              onPressed: widget.onLogout,
            ),
          UiButton(
            label: 'Retry connection',
            variant: UiVariant.ghost,
            onPressed: _loading ? null : _check,
          ),
        ],
      ),
    );
  }
}
