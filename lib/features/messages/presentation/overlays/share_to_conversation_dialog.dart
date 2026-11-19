import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/customer_limitations.dart';
import 'package:alphajournal/core/data/app_entitlements.dart';
import 'package:alphajournal/core/data/app_session.dart';
// Required unified primitive import for application UI.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/messages/models/messages_models.dart';
import 'package:alphajournal/features/messages/presentation/widgets/messages_widgets.dart';
import 'package:alphajournal/core/navigation/share_links.dart';
import 'package:alphajournal/core/utils/share_actions.dart';

/// Sends a Writing-Desk record ([AppLinkRef]) into a direct conversation.
///
/// The universal "share to a chat" entry point: any feature (community post,
/// journal entry, strategy, note) can call [show] with the record to share and
/// the user picks a thread and adds an optional note. Threads come from the
/// repository; the reference is passed in.
class ShareToConversationDialog extends StatefulWidget {
  const ShareToConversationDialog({
    super.key,
    required this.repository,
    this.reference,
    this.message,
    this.initialText,
    this.onShared,
  }) : assert(
         reference != null || message != null || initialText != null,
         'Either reference, message, or initialText must be provided',
       );

  final MessagesRepository repository;
  final AppLinkRef? reference;
  final ChatMessage? message;
  final String? initialText;

  /// Called with the destination thread id after sending.
  final void Function(String threadId)? onShared;

  static Future<void> show(
    BuildContext context, {
    MessagesRepository? repository,
    AppLinkRef? reference,
    String? initialText,
    void Function(String threadId)? onShared,
  }) async {
    if (!AppEntitlement.messages.allows(AppSession.instance.tier.value)) {
      await CustomerLimitations.showPlanUpgradeDialog(
        context,
        featureTitle: 'Messages · Basic or Pro',
        reason: AppEntitlement.messages.reason,
      );
      return;
    }
    final MessagesRepository repo =
        repository ?? MessagesRepositoryScope.repository;
    return UiDialog.show<void>(
      context,
      child: MessagesDensityScope(
        child: ShareToConversationDialog(
          repository: repo,
          reference: reference,
          initialText: initialText,
          onShared: onShared,
        ),
      ),
    );
  }

  static Future<void> forwardMessage(
    BuildContext context, {
    required MessagesRepository repository,
    required ChatMessage message,
    void Function(String threadId)? onForwarded,
  }) async {
    if (!AppEntitlement.messages.allows(AppSession.instance.tier.value)) {
      await CustomerLimitations.showPlanUpgradeDialog(
        context,
        featureTitle: 'Messages · Basic or Pro',
        reason: AppEntitlement.messages.reason,
      );
      return;
    }
    return UiDialog.show<void>(
      context,
      child: MessagesDensityScope(
        child: ShareToConversationDialog(
          repository: repository,
          message: message,
          onShared: onForwarded,
        ),
      ),
    );
  }

  /// Universal share menu sheet providing options to send via AlphaJournal chat,
  /// copy public web link, or export as PDF.
  static Future<void> showShareMenu(
    BuildContext context, {
    required AppLinkRef reference,
    bool isPublic = true,
    VoidCallback? onPublish,
    VoidCallback? onExportPdf,
    MessagesRepository? repository,
  }) {
    final theme = context.ui;
    final colors = theme.colors;
    final repo = repository ?? MessagesRepositoryScope.repository;

    final shareUrl = AppShareLinks.record(
      reference.copyWith(isPublicContext: true),
    );
    final String fullShareText =
        '${reference.title}${reference.subtitle != null && reference.subtitle!.isNotEmpty ? '\n${reference.subtitle}' : ''}\n\n$shareUrl';

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ctx.sz(520),
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(ctx.sp(theme.radii.lg)),
              ),
              border: Border.all(
                color: colors.border,
                width: theme.borders.hairline,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              ctx.sp(theme.spacing.md),
              ctx.sp(theme.spacing.sm),
              ctx.sp(theme.spacing.md),
              ctx.sp(theme.spacing.lg),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: ctx.sz(36),
                        height: ctx.sz(4),
                        margin: EdgeInsets.only(
                          bottom: ctx.sp(theme.spacing.sm),
                        ),
                        decoration: BoxDecoration(
                          color: colors.borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Share ${reference.kind.label}',
                            style: ctx.uiText.heading.copyWith(
                              fontSize: ctx.fs(16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        UiIconButton(
                          icon: Icons.close_rounded,
                          size: UiSize.xs,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: ctx.sp(theme.spacing.sm)),

                    if (!isPublic) ...[
                      const UiCallout(
                        title: 'This record is private',
                        message:
                            'Publish it before sharing a link so other traders can read it. You can also export a copy as PDF.',
                        intent: UiIntent.info,
                      ),
                      if (onPublish != null)
                        UiButton(
                          label: 'Publish to share',
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onPublish();
                          },
                        ),
                    ],
                    if (isPublic) ...[
                      _buildShareAction(
                        ctx,
                        icon: Icons.send_rounded,
                        title: 'Send via AlphaJournal Messages',
                        subtitle: 'Share privately into trader conversation',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareToConversationDialog.show(
                            context,
                            repository: repo,
                            reference: reference,
                            onShared: (threadId) {
                              UiToast.show(
                                context,
                                title: 'Sent to conversation',
                                message: 'Shared ${reference.title}',
                                intent: UiIntent.success,
                              );
                            },
                          );
                        },
                      ),

                      _buildShareAction(
                        ctx,
                        icon: Icons.link_rounded,
                        title: 'Copy Public Link',
                        subtitle: shareUrl,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.copy(context, shareUrl);
                        },
                      ),
                      _buildShareAction(
                        ctx,
                        icon: Icons.chat_rounded,
                        title: 'Share via WhatsApp',
                        subtitle: 'Send to trading channels & groups',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.external(
                            context,
                            uri: Uri.https('wa.me', '/', {
                              'text': fullShareText,
                            }),
                            text: fullShareText,
                            platform: 'WhatsApp',
                          );
                        },
                      ),
                      _buildShareAction(
                        ctx,
                        icon: Icons.alternate_email_rounded,
                        title: 'Share on X / Twitter',
                        subtitle: 'Broadcast to external audience',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.external(
                            context,
                            uri: Uri.https('x.com', '/intent/tweet', {
                              'text': reference.title,
                              'url': shareUrl,
                            }),
                            text: fullShareText,
                            platform: 'X',
                          );
                        },
                      ),
                      _buildShareAction(
                        ctx,
                        icon: Icons.near_me_rounded,
                        title: 'Share via Telegram',
                        subtitle: 'Post to trading groups & channels',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.external(
                            context,
                            uri: Uri.https('t.me', '/share/url', {
                              'url': shareUrl,
                              'text': reference.title,
                            }),
                            text: fullShareText,
                            platform: 'Telegram',
                          );
                        },
                      ),
                      _buildShareAction(
                        ctx,
                        icon: Icons.business_center_outlined,
                        title: 'Share on LinkedIn',
                        subtitle: 'Share market thesis & insights',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.external(
                            context,
                            uri: Uri.https(
                              'www.linkedin.com',
                              '/sharing/share-offsite/',
                              {'url': shareUrl},
                            ),
                            text: fullShareText,
                            platform: 'LinkedIn',
                          );
                        },
                      ),
                      _buildShareAction(
                        ctx,
                        icon: Icons.mail_outline_rounded,
                        title: 'Share via Email',
                        subtitle: 'Send formatted link over email',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.external(
                            context,
                            uri: Uri(
                              scheme: 'mailto',
                              query:
                                  'subject=${Uri.encodeComponent(reference.title)}&body=${Uri.encodeComponent(fullShareText)}',
                            ),
                            text: fullShareText,
                            platform: 'Email',
                          );
                        },
                      ),
                      _buildShareAction(
                        ctx,
                        icon: Icons.ios_share_rounded,
                        title: 'System Share...',
                        subtitle: 'Share via OS share sheet',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ShareActions.system(
                            context,
                            text: fullShareText,
                            subject: reference.title,
                          );
                        },
                      ),
                    ],

                    if (onExportPdf != null)
                      _buildShareAction(
                        ctx,
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Export as PDF',
                        subtitle: 'Save a publication-grade PDF file',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onExportPdf();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildShareAction(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: ctx.sp(theme.spacing.sm),
            vertical: ctx.sp(theme.spacing.xs),
          ),
          margin: EdgeInsets.only(bottom: ctx.sp(theme.spacing.xxs)),
          decoration: BoxDecoration(
            color: state.hovered
                ? theme.colors.surfaceHover
                : Colors.transparent,
            borderRadius: ctx.radius(theme.radii.md),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: ctx.sz(38),
                height: ctx.sz(38),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.1),
                  borderRadius: ctx.radius(theme.radii.sm),
                ),
                child: Icon(
                  icon,
                  size: ctx.sz(20),
                  color: theme.colors.primary,
                ),
              ),
              SizedBox(width: ctx.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: ctx.uiText.bodyStrong.copyWith(
                        fontSize: ctx.fs(14),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ctx.uiText.caption.copyWith(
                        fontSize: ctx.fs(11),
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: ctx.sz(18),
                color: theme.colors.foregroundSubtle,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  State<ShareToConversationDialog> createState() =>
      _ShareToConversationDialogState();
}

class _ShareToConversationDialogState extends State<ShareToConversationDialog> {
  final TextEditingController _note = TextEditingController();
  String _query = '';
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      _note.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  List<MessageThread> get _results {
    final List<MessageThread> threads = widget.repository.threads;
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return threads;
    return threads
        .where(
          (MessageThread t) =>
              t.title.toLowerCase().contains(q) ||
              t.peer.handle.toLowerCase().contains(q),
        )
        .toList();
  }

  void _share() {
    final String? id = _selectedId;
    if (id == null) return;
    if (widget.reference != null) {
      widget.repository.sendSharedRef(
        id,
        widget.reference!,
        note: _note.text.trim(),
      );
    } else if (widget.message != null) {
      widget.repository.sendMessage(
        id,
        body: widget.message!.body,
        attachment: widget.message!.attachment,
        sharedRef: widget.message!.sharedRef,
      );
      if (_note.text.trim().isNotEmpty) {
        widget.repository.sendMessage(id, body: _note.text.trim());
      }
    } else if (_note.text.trim().isNotEmpty) {
      widget.repository.sendMessage(id, body: _note.text.trim());
    }
    widget.onShared?.call(id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<MessageThread> results = _results;
    final String dialogTitle = widget.message != null
        ? 'Forward to chat'
        : (widget.reference != null ? 'Share to chat' : 'Send in message');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(dialogTitle, style: context.uiText.subheading),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              size: UiSize.sm,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (widget.reference != null)
          AppLinkRefTile(ref: widget.reference!)
        else if (widget.message != null)
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.surfaceHover,
              borderRadius: context.radius(theme.radii.md),
              border: Border.all(
                color: theme.colors.border,
                width: theme.borders.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.forward_rounded,
                  size: context.sz(18),
                  color: theme.colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    widget.message!.hasText
                        ? widget.message!.body
                        : (widget.message!.attachment != null
                              ? 'Attachment: ${widget.message!.attachment!.title}'
                              : 'Shared item'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.body,
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiInput.search(
          hintText: 'Search conversations',
          value: _query,
          onChanged: (String v) => setState(() => _query = v),
          onClear: () => setState(() => _query = ''),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(260)),
          child: results.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                  child: const UiEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No conversations',
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: results.length,
                  itemBuilder: (BuildContext context, int i) {
                    final MessageThread t = results[i];
                    return _PickerRow(
                      thread: t,
                      selected: t.id == _selectedId,
                      onTap: () => setState(() => _selectedId = t.id),
                    );
                  },
                ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiInput(
          label: widget.reference != null || widget.message != null
              ? 'Add a note (optional)'
              : 'Message',
          controller: _note,
          hintText: 'Say something about this…',
          minLines: 1,
          maxLines: 4,
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Cancel',
                variant: UiVariant.soft,
                intent: UiIntent.neutral,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: UiButton(
                label: 'Send',
                icon: Icons.send_rounded,
                intent: UiIntent.primary,
                onPressed: _selectedId == null ? null : _share,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.thread,
    required this.selected,
    required this.onTap,
  });

  final MessageThread thread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return UiInteractive(
      onTap: onTap,
      builder: (BuildContext context, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.xs),
            vertical: context.sp(theme.spacing.xs),
          ),
          margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xxs)),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.10)
                : (state.hovered ? colors.surfaceHover : Colors.transparent),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(
              color: selected ? colors.primary : Colors.transparent,
              width: theme.borders.hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              MessagesThreadAvatar(
                thread: thread,
                size: UiSize.sm,
                showPresence: false,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: context.sz(theme.sizes.iconSm),
                  color: colors.primary,
                ),
            ],
          ),
        );
      },
    );
  }
}
