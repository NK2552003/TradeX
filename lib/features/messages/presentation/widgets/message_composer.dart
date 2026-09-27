import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/messages/models/messages_models.dart';

/// The thread composer.
///
/// Owns its text controller and focus, persists the draft back to the caller,
/// and emits a fully-formed intent (text, an attachment or a shared record).
/// The attach menu, quick-share suggestions and quick-reaction row are all fed
/// from data — the attachment kinds come from [MessageAttachmentKind], the
/// shareable records from [shareableRefs], the emoji from [quickReactions].
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.threadId,
    this.initialDraft = '',
    this.shareableRefs = const <AppLinkRef>[],
    this.quickReactions = const <String>[],
    this.onSendText,
    this.onSendAttachment,
    this.onSendRef,
    this.onQuickReaction,
    this.onDraftChanged,
    this.autofocus = false,
  });

  final String threadId;
  final String initialDraft;
  final List<AppLinkRef> shareableRefs;
  final List<String> quickReactions;

  final void Function(String body)? onSendText;
  final void Function(MessageAttachmentKind kind)? onSendAttachment;
  final void Function(AppLinkRef ref)? onSendRef;
  final void Function(String emoji)? onQuickReaction;
  final void Function(String draft)? onDraftChanged;
  final bool autofocus;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();
  bool _hasText = false;
  bool _showQuickBar = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDraft);
    _hasText = widget.initialDraft.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching threads swaps in that thread's saved draft.
    if (oldWidget.threadId != widget.threadId) {
      _controller.value = TextEditingValue(
        text: widget.initialDraft,
        selection: TextSelection.collapsed(offset: widget.initialDraft.length),
      );
      _showQuickBar = false;
      _hasText = widget.initialDraft.trim().isNotEmpty;
    }
  }

  void _onChanged() {
    final bool has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    widget.onDraftChanged?.call(_controller.text);
  }

  void _send() {
    final String body = _controller.text.trim();
    if (body.isEmpty) return;
    widget.onSendText?.call(body);
    _controller.clear();
    widget.onDraftChanged?.call('');
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: theme.borders.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.sm),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_showQuickBar) _quickBar(context),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _attachButton(context),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Expanded(
                    child: UiInput(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      hintText: 'Message…',
                      minLines: 1,
                      maxLines: 5,
                      variant: UiInputVariant.filled,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      trailing: _emojiToggle(context),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  _sendButton(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachButton(BuildContext context) {
    return UiDropdownMenu(
      alignRight: false,
      items: <UiMenuItem>[
        const UiMenuItem.section('Attach'),
        for (final MessageAttachmentKind kind in MessageAttachmentKind.values)
          UiMenuItem(
            label: kind.label,
            icon: kind.icon,
            onPressed: () => widget.onSendAttachment?.call(kind),
          ),
        if (widget.shareableRefs.isNotEmpty) ...<UiMenuItem>[
          const UiMenuItem.divider(),
          const UiMenuItem.section('Share a record'),
          for (final AppLinkRef ref in widget.shareableRefs)
            UiMenuItem(
              label: ref.title,
              icon: ref.effectiveIcon,
              description: ref.subtitle,
              onPressed: () => widget.onSendRef?.call(ref),
            ),
        ],
      ],
      child: UiIconButton(
        icon: Icons.add_circle_outline_rounded,
        tooltip: 'Attach or share',
        size: UiSize.md,
      ),
    );
  }

  Widget _emojiToggle(BuildContext context) {
    return UiIconButton(
      icon: _showQuickBar
          ? Icons.keyboard_arrow_down_rounded
          : Icons.mood_outlined,
      tooltip: 'Quick reactions',
      size: UiSize.sm,
      onPressed: () => setState(() => _showQuickBar = !_showQuickBar),
    );
  }

  Widget _sendButton(BuildContext context) {
    if (_hasText) {
      return UiIconButton(
        icon: Icons.send_rounded,
        tooltip: 'Send',
        variant: UiVariant.solid,
        intent: UiIntent.primary,
        size: UiSize.md,
        onPressed: _send,
      );
    }
    // Nothing typed → a mic affordance, matching common chat UX. It shares an
    // attachment of the voice kind so the flow stays data-driven.
    return UiIconButton(
      icon: Icons.mic_none_rounded,
      tooltip: 'Voice message',
      size: UiSize.md,
      onPressed: () =>
          widget.onSendAttachment?.call(MessageAttachmentKind.voice),
    );
  }

  Widget _quickBar(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final String emoji in widget.quickReactions)
                  _QuickEmoji(
                    emoji: emoji,
                    onTap: () {
                      widget.onQuickReaction?.call(emoji);
                      setState(() => _showQuickBar = false);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickEmoji extends StatelessWidget {
  const _QuickEmoji({required this.emoji, this.onTap});

  final String emoji;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Container(
        width: context.sz(34),
        height: context.sz(34),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colors.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: TextStyle(fontSize: context.fs(18))),
      ),
    );
  }
}
