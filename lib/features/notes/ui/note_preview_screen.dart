import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.onOpenLink,
    this.onAttachToPost,
    this.canEdit = true,
  });

  final AppNote note;

  /// Unwinds the host's list/preview switch.
  final VoidCallback onClose;

  /// Hands the note to the editor.
  final VoidCallback onEdit;

  /// Follows a link out of this note. Null renders the links as plain rows,
  /// which is how a preview embedded somewhere without a navigator behaves.
  final void Function(AppLinkRef ref)? onOpenLink;

  /// Future social composer seam. Null keeps the current Writing Desk UI free
  /// of social-post controls until that feature exists.
  final AppWritingPostAttachmentHandler? onAttachToPost;
  final bool canEdit;

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
  String _commentDraft = '';

  @override
  void initState() {
    super.initState();
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
    _notesSub = _repo.watchAll().listen((List<AppNote> notes) {
      final AppNote? match =
          notes.where((AppNote n) => n.id == _activeNote.id).firstOrNull;
      if (match != null && mounted) {
        setState(() => _activeNote = match);
      }
    });
    if (widget.note.isPublic && widget.note.id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _repo.recordView(widget.note.id);
      });
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

  /// Everything this note connects to, resolved through the link graph rather
  /// than read out of the note's own id lists: a trade that cites this note is
  /// just as much a link as one this note cites, and only the graph sees both
  /// directions.
  AppLinkBundle get _bundle =>
      _note.id.isEmpty ? AppLinkBundle.empty : _graph.bundleForNote(_note);

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
    final String shareUrl = 'https://tradex.app/p/notes/${_note.id}';
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    UiToast.success(
      context,
      title: 'Link copied',
      message: 'Share URL copied to clipboard',
    );
  }

  Future<void> _toggleSaveNote() async {
    final bool wasFavorite = _note.isFavorite;
    await _repo.toggleFavorite(_note.id);
    if (!mounted) return;
    UiToast.success(
      context,
      title: wasFavorite ? 'Removed from saved' : 'Saved note',
      message: wasFavorite
          ? 'Note removed from bookmarks'
          : 'Note saved to your bookmarks',
    );
  }

  String get _title =>
      _note.title.trim().isEmpty ? 'Untitled note' : _note.title.trim();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);

    return UiPage(
      maxWidth: 1200,
      scrollable: false,
      child: Stack(
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
    final bool isMobile = context.uiRes.isMobile;
    // Inside the desktop workbench the shell already draws the note title and a
    // back control; a second title and back button here would read as two
    // headers stacked. Off the workbench (a phone, a future full window) we own
    // that chrome and draw it ourselves.
    final bool inWorkbench = AppWorkbenchScope.of(context);
    final bool showChrome = !isMobile && !inWorkbench;
    return Row(
      children: <Widget>[
        if (showChrome) ...<Widget>[
          UiIconButton(
            icon: Icons.arrow_back_rounded,
            variant: UiVariant.ghost,
            tooltip: 'Back to notes',
            onPressed: widget.onClose,
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showChrome)
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
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
                  Text(
                    '${AppTokens.fullDate(_note.updatedAt)} · ${_note.wordCount} words · $_readMinutes min read',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        if (widget.canEdit) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.xs)),
          UiButton(
            label: 'Edit',
            leadingIcon: Icons.edit_outlined,
            size: UiSize.sm,
            hideLabelOnMobile: true,
            onPressed: widget.onEdit,
          ),
        ],
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
          ),
          if (_bundle.isNotEmpty) ...<Widget>[
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
        if (_note.isPublic) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          _publicConversation(context),
        ],
      ],
    );
  }

  Widget _publicConversation(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Conversation',
      subtitle:
          '${_note.viewCount} views · ${_note.likeCount} likes · ${_note.comments.length} comments',
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
                  onPressed: () => _repo.toggleLike(_note.id),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: UiButton(
                  label: _note.isFavorite ? 'Saved' : 'Save',
                  leadingIcon: _note.isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  variant:
                      _note.isFavorite ? UiVariant.soft : UiVariant.outline,
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
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiField(
            label: 'Add a comment',
            child: UiInput(
              value: _commentDraft,
              hintText: 'Join the conversation',
              onChanged: (String value) =>
                  setState(() => _commentDraft = value),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Align(
            alignment: Alignment.centerRight,
            child: UiButton(
              label: 'Comment',
              size: UiSize.sm,
              onPressed: _commentDraft.trim().isEmpty
                  ? null
                  : () async {
                      await _repo.addComment(_note.id, _commentDraft);
                      if (mounted) setState(() => _commentDraft = '');
                    },
            ),
          ),
          if (_note.comments.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.sm)),
            for (final AppNoteComment comment in _note.comments)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(comment.authorName, style: context.uiText.label),
                    Text(comment.body, style: context.uiText.body),
                    Text(
                      AppTokens.relativeTime(comment.createdAt),
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
          ),
        for (final String ticker in _note.linkedTickers)
          UiBadge(
            label: '\$$ticker',
            intent: UiIntent.info,
            variant: UiBadgeVariant.outline,
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
          showEmptyKinds: false,
          onOpen: widget.onOpenLink,
        ),
      ],
    );
  }
}
