import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/supabase_config.dart';

class SupabaseConfigModal extends StatefulWidget {
  const SupabaseConfigModal({super.key, this.onConfigSaved});

  final VoidCallback? onConfigSaved;

  static void show(BuildContext context, {VoidCallback? onConfigSaved}) {
    showDialog(
      context: context,
      builder: (ctx) => SupabaseConfigModal(onConfigSaved: onConfigSaved),
    );
  }

  @override
  State<SupabaseConfigModal> createState() => _SupabaseConfigModalState();
}

class _SupabaseConfigModalState extends State<SupabaseConfigModal> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: SupabaseConfig.supabaseUrl.contains('placeholder')
          ? ''
          : SupabaseConfig.supabaseUrl,
    );
    _keyController = TextEditingController(
      text: SupabaseConfig.supabaseAnonKey.contains('placeholder')
          ? ''
          : SupabaseConfig.supabaseAnonKey,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || !url.startsWith('https://')) {
      UiToast.show(
        context,
        title: 'Invalid URL',
        message:
            'Please enter a valid Supabase project URL (https://xxxx.supabase.co)',
        intent: UiIntent.danger,
      );
      return;
    }
    if (key.isEmpty || key.length < 20) {
      UiToast.show(
        context,
        title: 'Invalid Key',
        message: 'Please enter a valid Supabase Anon API Key',
        intent: UiIntent.danger,
      );
      return;
    }

    await SupabaseConfig.initialize(customUrl: url, customKey: key);

    if (mounted) {
      Navigator.of(context).pop();
      widget.onConfigSaved?.call();
      UiToast.show(
        context,
        title: 'Supabase Connected',
        message: 'Supabase backend authentication is active!',
        intent: UiIntent.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = SupabaseConfig.isConfigured;

    return UiDialog(
      title: 'Supabase Cloud Backend Setup',
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiCallout(
              title: isConnected
                  ? 'Supabase Connected'
                  : 'Local Mock Backend Mode Active',
              message: isConnected
                  ? 'AlphaJournal is connected to the live Supabase backend instance.'
                  : 'Currently operating in local mock mode. Enter your Supabase Project URL & Anon Key below to connect live authentication.',
              intent: isConnected ? UiIntent.success : UiIntent.info,
            ),
            const SizedBox(height: 16),
            UiField(
              label: 'Supabase Project URL',
              helper: 'e.g. https://your-project.supabase.co',
              child: UiInput(
                value: _urlController.text,
                hintText: 'https://xxxx.supabase.co',
                leadingIcon: Icons.link,
                onChanged: (v) => _urlController.text = v,
              ),
            ),
            const SizedBox(height: 12),
            UiField(
              label: 'Supabase Anon API Key',
              helper: 'Found in Supabase Console -> Project Settings -> API',
              child: UiInput(
                value: _keyController.text,
                hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                leadingIcon: Icons.key_outlined,
                onChanged: (v) => _keyController.text = v,
              ),
            ),
          ],
        ),
      ),
      actions: [
        UiButton(
          label: 'Cancel',
          variant: UiVariant.outline,
          intent: UiIntent.neutral,
          onPressed: () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: 'Save & Connect Supabase',
          variant: UiVariant.primary,
          intent: UiIntent.primary,
          leadingIcon: Icons.cloud_done,
          onPressed: _saveConfig,
        ),
      ],
    );
  }
}
