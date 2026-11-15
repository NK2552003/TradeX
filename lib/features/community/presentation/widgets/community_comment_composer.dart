import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../../models/community_models.dart';
import 'community_emoji_picker.dart';

/// Independent draft state keeps root comments and replies from replacing each other.
class CommunityCommentComposer extends StatefulWidget {
  const CommunityCommentComposer({
    super.key,
    required this.author,
    required this.onSubmit,
    this.replyTo,
    this.onCancel,
    this.onSubmitted,
    this.focusNode,
    this.hintText,
  });
  final FocusNode? focusNode;
  final String? hintText;
  final CommunityAuthor author;
  final CommunityAuthor? replyTo;
  final Future<void> Function(String body) onSubmit;
  final VoidCallback? onCancel;
  final VoidCallback? onSubmitted;

  @override
  State<CommunityCommentComposer> createState() =>
      _CommunityCommentComposerState();
}

class _CommunityCommentComposerState extends State<CommunityCommentComposer> {
  final _controller = TextEditingController();
  late final FocusNode _focus;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    if (widget.replyTo != null) {
      _controller.text = '${widget.replyTo!.displayHandle} ';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focus.requestFocus();
        Scrollable.ensureVisible(
          context,
          alignment: .7,
          duration: const Duration(milliseconds: 180),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (_sending || body.isEmpty || body == widget.replyTo?.displayHandle) {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(body);
      if (!mounted) return;
      _controller.clear();
      widget.onSubmitted?.call();
    } catch (error) {
      if (mounted) {
        final String msg = error is StateError
            ? error.message
            : 'Could not publish. Your comment is saved here; please try again.';
        setState(() => _error = msg);
        if (error is StateError &&
            CustomerLimitations.isQuotaErrorMessage(error.message)) {
          await CustomerLimitations.showPlanUpgradeDialog(
            context,
            featureTitle: 'Daily Comment Limit Reached',
            reason: error.message,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final replying = widget.replyTo != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: replying
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: replying ? context.sp(theme.spacing.xs) : 0,
              ),
              child: UiAvatar(
                name: widget.author.displayName,
                imageUrl: widget.author.avatarUrl,
                size: UiSize.sm,
              ),
            ),
            UiGap.h(theme.spacing.sm),
            Expanded(
              child: UiCard(
                key: ValueKey(
                  replying
                      ? 'inline-reply-composer'
                      : 'compact-comment-composer',
                ),
                variant: UiCardVariant.outlined,
                borderRadius: context.radius(
                  replying ? theme.radii.xl : theme.radii.pill,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final canSend =
                        !_sending &&
                        value.text.trim().isNotEmpty &&
                        value.text.trim() != widget.replyTo?.displayHandle;
                    final emoji = CommunityEmojiPicker(
                      forComposer: true,
                      enabled: !_sending,
                      onSelected: _insertEmoji,
                    );
                    final input = UiInput(
                      controller: _controller,
                      focusNode: _focus,
                      hintText:
                          widget.hintText ??
                          (replying ? 'Write a reply…' : 'Add a comment…'),
                      variant: UiInputVariant.ghost,
                      density: UiDensity.compact,
                      size: UiSize.md,
                      minLines: 1,
                      maxLines: replying ? 5 : 1,
                      enabled: !_sending,
                      textInputAction: replying
                          ? TextInputAction.newline
                          : TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      trailing: replying
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                emoji,
                                if (value.text.trim().isNotEmpty || _sending)
                                  UiButton.icon(
                                    icon: Icons.arrow_upward_rounded,
                                    label: 'Comment',
                                    size: UiSize.sm,
                                    variant: UiVariant.solid,
                                    loading: _sending,
                                    onPressed: canSend ? _submit : null,
                                  ),
                              ],
                            ),
                    );
                    if (!replying) return input;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to ${widget.replyTo!.displayName}',
                                style: context.uiText.caption,
                              ),
                            ),
                            UiIconButton(
                              icon: Icons.close,
                              tooltip: 'Cancel reply',
                              size: UiSize.xs,
                              onPressed: _sending ? null : widget.onCancel,
                            ),
                          ],
                        ),
                        input,
                        Row(
                          children: [
                            emoji,
                            const Spacer(),
                            UiButton(
                              label: 'Reply',
                              size: UiSize.sm,
                              rounded: true,
                              loading: _sending,
                              onPressed: canSend ? _submit : null,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          UiGap.v(theme.spacing.xs),
          UiCallout(
            title: 'Comment not published',
            message: _error!,
            intent: UiIntent.danger,
          ),
        ],
      ],
    );
  }
}
