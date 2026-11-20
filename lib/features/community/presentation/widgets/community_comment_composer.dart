import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';
import '../../models/community_models.dart';
import 'community_composer_pickers.dart';
import 'community_emoji_picker.dart';
import 'community_quote_card.dart';

/// Independent draft state keeps root comments and replies from replacing each other.
class CommunityCommentComposer extends StatefulWidget {
  const CommunityCommentComposer({
    super.key,
    required this.author,
    required this.onSubmit,
    this.repository,
    this.currentPostId,
    this.replyTo,
    this.onCancel,
    this.onSubmitted,
    this.focusNode,
    this.hintText,
  });
  final FocusNode? focusNode;
  final String? hintText;
  final CommunityAuthor author;
  final CommunityRepository? repository;
  final String? currentPostId;
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
  CommunityPost? _linkedPost;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    if (widget.replyTo != null) {
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
    final String rawBody = _controller.text.trim();
    if (_sending || (rawBody.isEmpty && _linkedPost == null)) {
      return;
    }
    final String encoded = CommunityCommentLinkCodec.encode(
      rawBody,
      _linkedPost,
    );
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(encoded);
      if (!mounted) return;
      _controller.clear();
      setState(() => _linkedPost = null);
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

  Future<void> _pickMention() async {
    final CommunityRepository? repo = widget.repository;
    if (repo == null || _sending) return;
    final CommunityAuthor? trader = await showCommunityTraderTagPicker(
      context,
      repository: repo,
    );
    if (trader == null || !mounted) return;
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : start;
    final prefix =
        start > 0 && !_controller.text.substring(0, start).endsWith(' ')
        ? ' '
        : '';
    final insert = '$prefix${trader.displayHandle} ';
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(start, end, insert),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _focus.requestFocus();
  }

  Future<void> _pickLinkedPost() async {
    final CommunityRepository? repo = widget.repository;
    if (repo == null || _sending) return;
    final CommunityPostLinkPickResult? res = await showCommunityPostLinkPicker(
      context,
      repository: repo,
      excludePostId: widget.currentPostId,
      selectedPostId: _linkedPost?.id,
      allowUnlink: _linkedPost != null,
    );
    if (res == null || !mounted) return;
    setState(() {
      _linkedPost = res.unlink ? null : res.post;
    });
  }

  Widget _buildLinkedPostPreview(UiTheme theme) {
    final CommunityPost post = _linkedPost!;
    return Padding(
      padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
      child: Stack(
        children: <Widget>[
          CommunityQuoteCard(post: post),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: theme.colors.surface.withValues(alpha: 0.9),
              shape: CircleBorder(
                side: BorderSide(color: theme.colors.border),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending
                    ? null
                    : () => setState(() => _linkedPost = null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final replying = widget.replyTo != null;
    final bool hasRepo = widget.repository != null;
    final bool expandedCard = replying || _linkedPost != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: expandedCard
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: expandedCard ? context.sp(theme.spacing.xs) : 0,
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
                  expandedCard ? theme.radii.xl : theme.radii.pill,
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
                        (value.text.trim().isNotEmpty || _linkedPost != null);
                    final emoji = CommunityEmojiPicker(
                      forComposer: true,
                      enabled: !_sending,
                      onSelected: _insertEmoji,
                    );
                    final Widget? mentionBtn = hasRepo
                        ? UiIconButton(
                            icon: Icons.alternate_email_rounded,
                            tooltip: 'Tag someone',
                            size: UiSize.xs,
                            variant: UiVariant.ghost,
                            onPressed: _sending ? null : _pickMention,
                          )
                        : null;
                    final Widget? linkPostBtn = hasRepo
                        ? UiIconButton(
                            icon: Icons.format_quote_rounded,
                            tooltip: _linkedPost != null
                                ? 'Change linked post'
                                : 'Link a post',
                            size: UiSize.xs,
                            variant: _linkedPost != null
                                ? UiVariant.soft
                                : UiVariant.ghost,
                            intent: _linkedPost != null
                                ? UiIntent.primary
                                : null,
                            onPressed: _sending ? null : _pickLinkedPost,
                          )
                        : null;
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
                                ?mentionBtn,
                                ?linkPostBtn,
                                emoji,
                                if (canSend || _sending)
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
                    if (!replying) {
                      if (_linkedPost == null) return input;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          input,
                          _buildLinkedPostPreview(theme),
                        ],
                      );
                    }
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
                        if (_linkedPost != null) _buildLinkedPostPreview(theme),
                        Row(
                          children: [
                            ?mentionBtn,
                            ?linkPostBtn,
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
