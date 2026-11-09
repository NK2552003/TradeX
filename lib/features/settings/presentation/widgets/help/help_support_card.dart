import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

typedef HelpTicketSubmit =
    Future<void> Function(String category, String subject, String message);

class HelpSupportCard extends StatefulWidget {
  const HelpSupportCard({super.key, this.submitTicket});
  final HelpTicketSubmit? submitTicket;
  static const email = 'h82292245@gmail.com';

  @override
  State<HelpSupportCard> createState() => _HelpSupportCardState();
}

class _HelpSupportCardState extends State<HelpSupportCard> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'Technical support';
  bool _sending = false;
  String? _feedback;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _feedback = 'Please provide a subject and message.');
      return;
    }
    setState(() {
      _sending = true;
      _feedback = null;
    });
    try {
      await widget.submitTicket!(
        _category,
        _subject.text.trim(),
        _message.text.trim(),
      );
      if (!mounted) return;
      _subject.clear();
      _message.clear();
      setState(() => _feedback = 'Your support message was accepted.');
    } catch (_) {
      if (mounted) {
        setState(
          () => _feedback =
              'Ticket not sent. Your message has been kept; please retry or email support.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _email() async {
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: HelpSupportCard.email,
        query: 'subject=${Uri.encodeComponent('Alphajournal support')}',
      );
      if (!await launchUrl(uri)) throw StateError('Email unavailable');
      if (mounted) {
        setState(
          () => _feedback = 'Review and send your message in your email app.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _feedback =
              'An email app could not be opened. Copy the address and send your message from your mailbox.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppSettingsSectionBlock(
    title: 'Contact and support',
    description:
        'For account questions, billing, privacy requests or unsafe ads. Never include passwords, one-time codes or full payment details.',
    children: [
      UiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              HelpSupportCard.email,
              style: context.uiText.bodyStrong,
            ),
            UiGap.v(context.ui.spacing.sm),
            Wrap(
              spacing: context.sp(context.ui.spacing.sm),
              children: [
                UiButton(
                  label: 'Email support',
                  variant: UiVariant.outline,
                  onPressed: _email,
                ),
                UiButton(
                  label: 'Copy email address',
                  variant: UiVariant.ghost,
                  onPressed: () async {
                    try {
                      await Clipboard.setData(
                        const ClipboardData(text: HelpSupportCard.email),
                      );
                      if (mounted) {
                        setState(() => _feedback = 'Email address copied.');
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => _feedback =
                              'Copy unavailable. Select the address above to copy it manually.',
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            if (widget.submitTicket != null) ...[
              UiGap.v(context.ui.spacing.md),
              UiSelect<String>(
                value: _category,
                options: [
                  for (final value in [
                    'Technical support',
                    'Billing and subscriptions',
                    'Privacy request',
                    'Advertising report',
                    'Bug report',
                    'Feature request',
                  ])
                    UiOption(label: value, value: value),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
              UiGap.v(context.ui.spacing.sm),
              UiInput(
                controller: _subject,
                label: 'Subject',
                hintText: 'Brief summary',
                enabled: !_sending,
              ),
              UiGap.v(context.ui.spacing.sm),
              UiInput(
                controller: _message,
                label: 'Message',
                hintText: 'What happened and what did you expect?',
                maxLines: 5,
                enabled: !_sending,
              ),
              UiGap.v(context.ui.spacing.sm),
              UiButton(
                label: 'Send support ticket',
                loading: _sending,
                onPressed: _sending ? null : _send,
              ),
            ],
            if (_feedback != null) ...[
              UiGap.v(context.ui.spacing.sm),
              UiCallout(title: 'Support', message: _feedback!),
            ],
          ],
        ),
      ),
    ],
  );
}
