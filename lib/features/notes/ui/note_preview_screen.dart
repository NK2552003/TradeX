import 'package:tradex/core/config/record_access.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/core/utils/export_progress.dart';
import 'package:tradex/core/utils/markdown_pdf_export.dart';
import 'package:tradex/core/utils/pdf_export_options.dart';
import 'package:tradex/features/linking/link_graph_service.dart';

import '../data/note_attachments.dart';
import '../data/notes_repository.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/community/data/unified_comments_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

/// Read-only view of one note.
///
/// This is the shape a note is *shared* in — a clean document with its metadata
/// stated once at the top, no editing chrome, and a PDF export that produces the
/// same layout on paper. It is a separate screen from the editor rather than a
/// mode of it because the two want opposite defaults: the editor optimises for
/// reach (toolbars, panels, a ribbon), this optimises for reading measure.
class NotePreviewScreen extends StatefulWidget {
  const NotePreviewScreen({
    super.key,
    required this.note,
    required this.onClose,
    required this.onEdit,
    this.onEditWriting,
    this.onOpenLink,
    this.onAttachToPost,
    this.canEdit = true,
    this.isPublicContext = false,
  });

  final AppNote note;

  /// Unwinds the host's list/preview switch.
  final VoidCallback onClose;

  /// Hands the note to the editor.
  final VoidCallback onEdit;
  final VoidCallback? onEditWriting;

  /// Follows a link out of this note. Null renders the links as plain rows,
  /// which is how a preview embedded somewhere without a navigator behaves.
  final void Function(AppLinkRef ref)? onOpenLink;

  /// Future social composer seam. Null keeps the current Writing Desk UI free
  /// of social-post controls until that feature exists.
  final AppWritingPostAttachmentHandler? onAttachToPost;
  final bool canEdit;
  final bool isPublicContext;

  @override
  State<NotePreviewScreen> createState() => _NotePreviewScreenState();
}

class _NotePreviewScreenState extends State<NotePreviewScreen> {
  final MarkdownOutlineController _outline = MarkdownOutlineController();
  final NotesRepository _repo = NotesRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;

  late AppNote _activeNote = widget.note;
  late AppLinkGraph _graph = _links.current;
  StreamSubscription<AppLinkGraph>? _graphSub;
  StreamSubscription<List<AppNote>>? _notesSub;

  @override
  void initState() {
    super.initState();
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
    _notesSub = _repo.watchAll().listen((List<AppNote> notes) {
      final AppNote? match = notes
          .where((AppNote n) => n.id == _activeNote.id)
          .firstOrNull;
      if (match != null && mounted) {
        setState(() => _activeNote = match);
      }
    });
    if (widget.note.isPublic && widget.note.id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _repo.recordView(widget.note.id).ignore();
      });
    }
    _loadNoteComments();
  }

  List<CommunityComment> _noteComments = const <CommunityComment>[];

  Future<void> _loadNoteComments() async {
    final list = await UnifiedCommentsRepositoryImpl.instance.fetchComments(
      entityType: 'note',
      entityId: _note.id,
    );
    if (mounted) {
      setState(() => _noteComments = list);
    }
  }

  @override
  void didUpdateWidget(NotePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _activeNote = widget.note;
    }
  }

  @override
  void dispose() {
    _graphSub?.cancel();
    _notesSub?.cancel();
    _outline.dispose();
    super.dispose();
  }

  AppNote get _note => _activeNote;

  /// Roughly 220 words a minute, floored at a minute so a two-line note does
  /// not claim to take zero.
  int get _readMinutes => (_note.wordCount / 220).ceil().clamp(1, 999);

  bool get _canEdit =>
      widget.canEdit &&
      !widget.isPublicContext &&
      RecordAccess.owns(_note.userId);

  bool get _isPublicViewer => widget.isPublicContext || !_canEdit;

  void _handleOpenLink(AppLinkRef ref) {
    if (widget.onOpenLink == null) return;
    final AppLinkRef target = _isPublicViewer
        ? ref.copyWith(isPublicContext: true)
        : ref;
    widget.onOpenLink!(target);
  }

  /// Everything this note connects to, resolved through the link graph rather
  /// than read out of the note's own id lists: a trade that cites this note is
  /// just as much a link as one this note cites, and only the graph sees both
  /// directions.
  AppLinkBundle get _bundle => _note.id.isEmpty
      ? AppLinkBundle.empty
      : _graph.bundleForNote(_note, onlyPublic: _isPublicViewer);

  /// Ask for paper size and whether diagrams travel, then export behind a
  /// blocking overlay — rendering flowcharts off-screen takes seconds and an
  /// unguarded second tap would start a duplicate export.
  Future<void> _exportPdf() async {
    final PdfExportOptions? options = await showPdfExportOptions(context);
    if (options == null || !mounted) return;

    final bool? ok = await runWithProgressOverlay<bool>(
      context,
      task: (void Function(String step) setStep) =>
          MarkdownPdfExporter.exportAndShare(
            markdown: _note.content,
            title: _title,
            subtitle:
                '${_note.noteType.label} · ${AppTokens.fullDate(_note.updatedAt)}',
            context: context,
            options: options,
            imageResolver: NoteAttachments.bytesFor,
            onStep: setStep,
          ),
    );
    if (!mounted || ok == null) return;
    if (ok) {
      UiToast.success(
        context,
        title: 'PDF ready',
        message: 'Shared as $_title',
      );
    } else {
      UiToast.error(
        context,
        title: 'Export failed',
        message: 'The note could not be turned into a PDF',
      );
    }
  }

  Future<void> _shareNote() async {
    final AppLinkRef ref = AppLinkRef(
      kind: AppLinkKind.note,
      id: _note.id,
      isPublicContext: true,
      title: _title,
      subtitle: _note.noteType.label,
    );
    await ShareToConversationDialog.showShareMenu(
      context,
      reference: ref,
      isPublic: _note.isPublic,
      onPublish: _canEdit ? () async {
        await _toggleVisibility();
        if (mounted && _note.isPublic) await _shareNote();
      } : null,
      onExportPdf: _exportPdf,
    );
  }

  Future<void> _noteAction(Future<AppNote> Function() action) async {
    try {
      final updated = await action();
      if (mounted) setState(() => _activeNote = updated);
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Change was not saved',
          message: '$error',
        );
      }
    }
  }

  void _showCommentError(Object e) {
    if (!mounted) return;
    UiToast.error(context, title: 'Could not post comment', message: '$e');
  }

  Future<void> _toggleSaveNote() =>
      _noteAction(() => _repo.toggleFavorite(_note.id));

  Future<void> _toggleVisibility() async {
    final bool next = !_note.isPublic;
    if (next) {
      final bool ok = await UiDialog.confirm(
        context,
        title: 'Publish this note?',
        description:
            'This note will become readable to the community. You can change it back to private at any time.',
        confirmLabel: 'Make Public',
      );
      if (!ok || !mounted) return;
    }
    try {
      final updated = await _repo.setVisibility(_note.id, next);
      if (mounted) {
        setState(() => _activeNote = updated);
        UiToast.show(
          context,
          title: next ? 'Note Published' : 'Note Made Private',
          message: next
              ? 'The note is now public and open for discussion.'
              : 'The note is now private to your account.',
          intent: next ? UiIntent.success : UiIntent.warning,
        );
      }
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Visibility was not changed',
          message: '$error',
        );
      }
    }
  }

  void _analyzeWithAi() {
    final String prompt =
        'Analyze this trade note "${_note.title}":\n\n'
        '${_note.content}\n\n'
        'Tags: ${_note.tags.join(', ')}\n'
        'Instruments: ${_note.linkedTickers.join(', ')}\n\n'
        'Provide a critical review, key takeaways, and suggested trade setups or risk warnings.';

    CopilotSheet.show(
      context,
      repository: CopilotScope.repository,
      initialPrompt: prompt,
      contextTitle: _note.title.isNotEmpty ? _note.title : 'Untitled Note',
      contextSubtitle: _note.noteType.label,
      contextIcon: _note.noteType.icon,
      contextRef: AppLinkRef(
        id: _note.id,
        kind: AppLinkKind.note,
        title: _note.title,
        subtitle: _note.noteType.label,
      ),
      onOpenRef: widget.onOpenLink,
      onOpenFullScreen: () {
        if (widget.onOpenLink != null) {
          widget.onOpenLink!(
            const AppLinkRef(
              id: 'ai_copilot',
              kind: AppLinkKind.aiCopilot,
              title: 'AI Copilot',
              subtitle: 'Note Analysis',
            ),
          );
        }
      },
    );
  }

  String get _title =>
      _note.title.trim().isEmpty ? 'Untitled note' : _note.title.trim();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);

    return UiPage(
      maxWidth: double.infinity,
      scrollable: false,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _previewCommandBar(context),
              SizedBox(height: context.sp(theme.spacing.md)),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool stacked = constraints.maxWidth < context.sz(860);
                    if (stacked) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _document(context),
                            SizedBox(height: context.sp(theme.spacing.lg)),
                            _readerDetails(context),
                            SizedBox(height: context.sz(96)),
                          ],
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: SingleChildScrollView(
                            child: _document(context),
                          ),
                        ),
                        SizedBox(width: context.sp(theme.spacing.lg)),
                        SizedBox(
                          width: context.sz(320),
                          child: SingleChildScrollView(
                            child: _readerDetails(context),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: gutter,
            bottom: gutter,
            child: MarkdownOutlineFab(controller: _outline),
          ),
        ],
      ),
    );
  }

  Widget _previewCommandBar(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<Widget> actions = <Widget>[
      UiIconButton(
        icon: Icons.auto_awesome_rounded,
        variant: UiVariant.ghost,
        intent: UiIntent.primary,
        tooltip: 'Analyze note with AI Copilot',
        onPressed: _analyzeWithAi,
      ),
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: _note.isFavorite
            ? Icons.bookmark_rounded
            : Icons.bookmark_outline_rounded,
        variant: _note.isFavorite ? UiVariant.soft : UiVariant.ghost,
        intent: _note.isFavorite ? UiIntent.primary : UiIntent.neutral,
        tooltip: _note.isFavorite ? 'Remove from saved' : 'Save note',
        onPressed: _toggleSaveNote,
      ),
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: Icons.share_outlined,
        variant: UiVariant.ghost,
        tooltip: 'Share note',
        onPressed: _shareNote,
      ),
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: _note.isPublic
            ? Icons.public_rounded
            : Icons.lock_outline_rounded,
        variant: _note.isPublic ? UiVariant.soft : UiVariant.ghost,
        intent: _note.isPublic ? UiIntent.success : UiIntent.warning,
        tooltip: _note.isPublic
            ? 'Public note (tap to make private)'
            : 'Private note (tap to make public)',
        onPressed: _canEdit ? _toggleVisibility : null,
      ),
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: Icons.picture_as_pdf_outlined,
        variant: UiVariant.ghost,
        tooltip: 'Export as PDF',
        onPressed: _exportPdf,
      ),
      if (widget.onAttachToPost != null) ...<Widget>[
        SizedBox(width: context.sp(theme.spacing.xs)),
        UiIconButton(
          icon: Icons.add_comment_outlined,
          variant: UiVariant.ghost,
          tooltip: 'Attach note to a post',
          onPressed: () =>
              widget.onAttachToPost!(AppWritingPostAttachment.note(_note)),
        ),
      ],
      if (_canEdit) ...<Widget>[
        SizedBox(width: context.sp(theme.spacing.xs)),
        UiIconButton(
          icon: Icons.edit_note_rounded,
          tooltip: 'Edit note',
          size: UiSize.sm,
          variant: UiVariant.outline,
          onPressed: widget.onEditWriting ?? widget.onEdit,
        ),
        SizedBox(width: context.sp(theme.spacing.xs)),
        UiIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit details',
          size: UiSize.sm,
          variant: UiVariant.primary,
          onPressed: widget.onEdit,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiHeader(
          title: _title,
          leading: UiIconButton(
            icon: Icons.arrow_back_rounded,
            variant: UiVariant.ghost,
            tooltip: 'Back to notes',
            onPressed: widget.onClose,
          ),
          actions: actions,
        ),
        UiGap.v(context.uiSpace.sm),
        Wrap(
          spacing: context.sp(theme.spacing.xs),
          runSpacing: context.sp(theme.spacing.xxs),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            UiBadge(
              label: _note.noteType.label,
              size: UiSize.xs,
              variant: UiBadgeVariant.soft,
              intent: UiIntent.primary,
            ),
            UiBadge(
              label: _note.isPublic ? 'Public' : 'Private',
              size: UiSize.xs,
              variant: UiBadgeVariant.soft,
              intent: _note.isPublic ? UiIntent.success : UiIntent.warning,
              icon: _note.isPublic
                  ? Icons.public_rounded
                  : Icons.lock_outline_rounded,
            ),
            Text(
              '${AppTokens.fullDate(_note.updatedAt)} · ${_note.wordCount} words · $_readMinutes min read',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _document(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      variant: UiCardVariant.ghost,
      borderless: true,
      hoverLift: false,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RichMarkdownPreview(
            data: _note.content,
            outlineController: _outline,
            imageResolver: NoteAttachments.resolve,
            emptyPlaceholder: 'This note has no body yet.',
            onOpenRef: _handleOpenLink,
          ),
          if (_bundle.isNotEmpty || _canEdit) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xl)),
            _linkedRecords(context),
          ],
        ],
      ),
    );
  }

  Widget _readerDetails(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCard(
          title: 'Note details',
          subtitle: 'Updated ${AppTokens.relativeTime(_note.updatedAt)}',
          variant: UiCardVariant.outlined,
          hoverLift: false,
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _metaWrap(context),
              SizedBox(height: context.sp(theme.spacing.md)),
              const UiDivider(),
              SizedBox(height: context.sp(theme.spacing.md)),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _readerMetric(
                      context,
                      icon: Icons.text_fields_rounded,
                      label: 'Words',
                      value: AppTokens.count(_note.wordCount),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: _readerMetric(
                      context,
                      icon: Icons.schedule_rounded,
                      label: 'Read time',
                      value: '$_readMinutes min',
                    ),
                  ),
                ],
              ),
              if (_note.hasChecklist) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.md)),
                _checklistProgress(context),
              ],
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _publicConversation(context),
      ],
    );
  }

  Widget _publicConversation(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Conversation',
      subtitle: _note.isPublic
          ? '${_note.viewCount} views · ${_note.likeCount} likes · ${_note.comments.length} comments'
          : 'Private Note · ${_note.comments.length} comments · Only visible to you',
      variant: UiCardVariant.outlined,
      hoverLift: false,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: _note.liked ? 'Liked' : 'Like',
                  leadingIcon: _note.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  variant: _note.liked ? UiVariant.soft : UiVariant.outline,
                  intent: UiIntent.danger,
                  size: UiSize.sm,
                  onPressed: () =>
                      _noteAction(() => _repo.toggleLike(_note.id)),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: UiButton(
                  label: _note.isFavorite ? 'Saved' : 'Save',
                  leadingIcon: _note.isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  variant: _note.isFavorite
                      ? UiVariant.soft
                      : UiVariant.outline,
                  intent: UiIntent.primary,
                  size: UiSize.sm,
                  onPressed: _toggleSaveNote,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: UiButton(
                  label: 'Share',
                  leadingIcon: Icons.share_outlined,
                  variant: UiVariant.outline,
                  intent: UiIntent.neutral,
                  size: UiSize.sm,
                  onPressed: _shareNote,
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UniversalCommentsSection(
            targetId: _activeNote.id,
            targetType: 'note',
            title: 'Technical Note Discussion',
            comments: _noteComments,
            isPublic: _note.isPublic,
            canToggleVisibility: _canEdit,
            onToggleVisibility: (v) => _toggleVisibility(),
            currentUser: UnifiedCommentsRepositoryImpl.instance
                .getCurrentAuthor(),
            onAddComment: (text, {parentCommentId, sentiment}) async {
              try {
                await UnifiedCommentsRepositoryImpl.instance.addComment(
                  entityType: 'note',
                  entityId: _activeNote.id,
                  body: text,
                  parentCommentId: parentCommentId,
                  sentiment: sentiment,
                );
                await _loadNoteComments();
              } catch (e) {
                _showCommentError(e);
                rethrow;
              }
            },
            onLikeComment: (commentId, {reaction}) async {
              try {
                await UnifiedCommentsRepositoryImpl.instance.toggleReaction(
                  commentId: commentId,
                  reaction: reaction ?? '👍',
                );
                await _loadNoteComments();
              } catch (e) {
                debugPrint('[NotePreviewScreen] Like error: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _readerMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              icon,
              size: context.sz(theme.sizes.iconXs),
              color: theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Expanded(
              child: Text(
                label,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xxs)),
        Text(value, style: context.uiText.subheading),
      ],
    );
  }

  /// Everything the note is filed under, stated once. A [Wrap] rather than a
  /// row because a note with six tickers must not clip on a phone.
  Widget _metaWrap(BuildContext context) {
    final UiTheme theme = context.ui;
    return Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: context.sp(theme.spacing.xs),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        UiBadge(
          label: _note.noteType.label,
          icon: _note.noteType.icon,
          intent: _note.noteType.intent,
        ),
        if (_note.strategyName case final String name)
          UiBadge(
            label: name,
            icon: Icons.auto_graph_rounded,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.outline,
            onTap:
                widget.onOpenLink == null ||
                    (_note.strategyId?.trim().isEmpty ?? true)
                ? null
                : () => _handleOpenLink(
                    _graph.refFor(AppLinkKind.strategy, _note.strategyId!),
                  ),
          ),
        for (final String ticker in _note.linkedTickers)
          UiBadge(
            label: '\$$ticker',
            intent: UiIntent.info,
            variant: UiBadgeVariant.outline,
            onTap: widget.onOpenLink == null
                ? null
                : () => _handleOpenLink(_graph.tickerRef(ticker)),
          ),
        for (final String tag in _note.tags)
          UiBadge(label: '#$tag', variant: UiBadgeVariant.ghost),
        if (_note.isPublic)
          const UiBadge(
            label: 'Public',
            icon: Icons.public_rounded,
            intent: UiIntent.success,
          ),
      ],
    );
  }

  Widget _checklistProgress(BuildContext context) => UiProgressBar(
    value: _note.checklistDone / _note.checklistTotal,
    label: 'Checklist',
    valueFormatter: (num _) =>
        '${_note.checklistDone} of ${_note.checklistTotal} done',
    intent: _note.checklistDone == _note.checklistTotal
        ? UiIntent.success
        : UiIntent.primary,
  );

  Future<void> _pickLinks(AppLinkKind targetKind) async {
    if (_note.id.isEmpty) return;
    final Set<String> current = switch (targetKind) {
      AppLinkKind.strategy => <String>{
        if (_note.strategyId != null && _note.strategyId!.isNotEmpty)
          _note.strategyId!,
      },
      AppLinkKind.journal => _note.linkedJournalIds.toSet(),
      AppLinkKind.ticker => _note.linkedTickers.toSet(),
      _ => const <String>{},
    };
    final List<String>? chosen = await showAppLinkPicker(
      context,
      kind: targetKind,
      options: _graph.options(
        targetKind,
        exclude: <String>[_note.id, ...current],
      ),
      multiSelect: targetKind != AppLinkKind.strategy,
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    try {
      if (targetKind == AppLinkKind.strategy) {
        for (final String oldId in current) {
          await _links.unlink(
            fromKind: AppLinkKind.note,
            fromId: _note.id,
            toKind: AppLinkKind.strategy,
            toId: oldId,
          );
        }
      }
      for (final String added in chosen) {
        await _links.link(
          fromKind: AppLinkKind.note,
          fromId: _note.id,
          toKind: targetKind,
          toId: added,
        );
      }
      final AppNote? refreshed = await _repo.getById(_note.id);
      if (refreshed != null && mounted) {
        setState(() => _activeNote = refreshed);
      }
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Link was not updated',
          message: '$error',
        );
      }
    }
  }

  Future<void> _removeLink(AppLinkRef target) async {
    if (_note.id.isEmpty) return;
    try {
      await _links.unlink(
        fromKind: AppLinkKind.note,
        fromId: _note.id,
        toKind: target.kind,
        toId: target.id,
      );
      final AppNote? refreshed = await _repo.getById(_note.id);
      if (refreshed != null && mounted) {
        setState(() => _activeNote = refreshed);
      }
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Link was not removed',
          message: '$error',
        );
      }
    }
  }

  /// What this note connects to: the trades it was written about, the playbook
  /// it belongs to, the other notes it cites and the instruments it names.
  ///
  /// One panel for all four kinds rather than a bespoke list per kind — the same
  /// component the journal entry and the playbook use, so a link looks and
  /// behaves the same wherever the reader meets it.
  Widget _linkedRecords(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiDivider(),
        SizedBox(height: context.sp(theme.spacing.md)),
        AppLinkedRecordsPanel(
          bundle: _bundle,
          title: 'Linked records',
          subtitle: 'What this note was written about',
          card: false,
          dense: true,
          showEmptyKinds: _canEdit,
          onOpen: _handleOpenLink,
          onRemove: _canEdit ? _removeLink : null,
          onAddJournal: _canEdit ? () => _pickLinks(AppLinkKind.journal) : null,
          onAddStrategy: _canEdit
              ? () => _pickLinks(AppLinkKind.strategy)
              : null,
          onAddTicker: _canEdit ? () => _pickLinks(AppLinkKind.ticker) : null,
        ),
      ],
    );
  }
}
