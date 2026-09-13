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

import '../data/journal_attachments.dart';
import '../data/journal_repository.dart';

/// Read-only view of one journal entry: the write-up, then the numbers behind
/// it, then everything it is attached to.
///
/// Reading order is deliberate and is the opposite of a trade log. A log leads
/// with P/L because it exists to be totalled; a journal leads with the words
/// because it exists to be re-read. The arithmetic sits underneath as evidence
/// the story can be checked against.
///
/// Separate from the editor rather than a mode of it, for the same reason the
/// notes feature splits them: the editor optimises for reach — toolbars, panels,
/// a ribbon — and a document being re-read six weeks later wants none of that.
class JournalEntryScreen extends StatefulWidget {
  const JournalEntryScreen({
    super.key,
    required this.entry,
    required this.onClose,
    required this.onEdit,
    this.onOpenLink,
    this.onEditWriting,
    this.onAttachToPost,
    this.canEdit = true,
  });

  final AppTrade entry;

  /// Unwinds the host's index/document switch.
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback? onEditWriting;

  /// Cross-navigation into another record. Null renders links as plain text,
  /// which is how a preview embedded somewhere without a navigator behaves.
  final void Function(AppLinkRef ref)? onOpenLink;
  final AppWritingPostAttachmentHandler? onAttachToPost;
  final bool canEdit;

  @override
  State<JournalEntryScreen> createState() => _JournalEntryScreenState();
}

class _JournalEntryScreenState extends State<JournalEntryScreen> {
  final MarkdownOutlineController _outline = MarkdownOutlineController();
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final JournalRepository _repo = JournalRepositoryScope.repository;

  StreamSubscription<AppLinkGraph>? _graphSub;
  late AppLinkGraph _graph = _links.current;
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Subscribed rather than read once: linking a note from this screen mutates
    // the graph, and so does an edit made in another pane of the workbench.
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
  }

  @override
  void dispose() {
    _graphSub?.cancel();
    _outline.dispose();
    super.dispose();
  }

  AppTrade get _entry => widget.entry;

  AppLinkBundle get _bundle => _graph.bundleForJournal(_entry);

  List<AppLinkRef> get _siblings => _graph.siblingEntries(_entry);

  /// Roughly 220 words a minute, floored at a minute.
  int get _readMinutes => (_entry.wordCount / 220).ceil().clamp(1, 999);

  // ── Linking ────────────────────────────────────────────────────────────────

  /// Opens the picker for [kind], then writes every chosen edge from both ends.
  ///
  /// The picker returns the full selection rather than a delta, so unticking an
  /// already-linked record unlinks it. That is what makes one sheet do both jobs.
  Future<void> _pickLinks(AppLinkKind kind) async {
    final List<AppLinkRef> linked = switch (kind) {
      AppLinkKind.note => _bundle.notes,
      AppLinkKind.strategy => _bundle.strategies,
      AppLinkKind.journal || AppLinkKind.ticker => const <AppLinkRef>[],
    };
    final Set<String> before = <String>{
      for (final AppLinkRef ref in linked) ref.id,
    };
    // The picker only offers what is not linked yet — unlinking is the panel's
    // job, not a deselection buried in a sheet.
    final List<String>? chosen = await showAppLinkPicker(
      context,
      kind: kind,
      options: _graph.options(kind, exclude: <String>[_entry.id, ...before]),
      // One trade, one plan. Notes are many.
      multiSelect: kind != AppLinkKind.strategy,
      title: kind == AppLinkKind.strategy
          ? 'File this trade under a playbook'
          : null,
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      if (kind == AppLinkKind.strategy) {
        // Replaces rather than adds: re-filing means the old plan is wrong.
        for (final AppLinkRef old in linked) {
          await _links.unlink(
            fromKind: AppLinkKind.journal,
            fromId: _entry.id,
            toKind: AppLinkKind.strategy,
            toId: old.id,
          );
        }
      }
      for (final String id in chosen) {
        await _links.link(
          fromKind: AppLinkKind.journal,
          fromId: _entry.id,
          toKind: kind,
          toId: id,
        );
      }
      if (mounted) {
        UiToast.success(
          context,
          title: 'Linked',
          message: chosen.length == 1
              ? 'One ${kind.label.toLowerCase()} attached to this entry'
              : '${chosen.length} ${kind.plural.toLowerCase()} attached',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLink(AppLinkRef ref) async {
    if (_graph.hasInlineConnection(
      AppLinkKind.journal,
      _entry.id,
      ref.kind,
      ref.id,
    )) {
      UiToast.info(
        context,
        title: 'Linked in the document',
        message:
            'Remove the citation in the source editor to remove this automatic backlink.',
      );
      return;
    }

    // A trade's instrument is not an edge the trader adds, so it is not one they
    // can drop. Saying so beats a confirm dialog that quietly does nothing.
    if (ref.kind == AppLinkKind.ticker) {
      UiToast.info(
        context,
        title: 'Part of the trade',
        message: 'Change the instrument by editing the entry itself.',
      );
      return;
    }
    final bool ok = await UiDialog.confirm(
      context,
      title: 'Unlink ${ref.title}?',
      description:
          'The ${ref.kind.label.toLowerCase()} itself is kept — only the '
          'connection to this entry goes away.',
      confirmLabel: 'Unlink',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _links.unlink(
        fromKind: AppLinkKind.journal,
        fromId: _entry.id,
        toKind: ref.kind,
        toId: ref.id,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Ask for paper size and whether diagrams travel, then export behind a
  /// blocking overlay — rendering flowcharts off-screen takes seconds, and an
  /// unguarded second tap would start a duplicate export.
  Future<void> _exportPdf() async {
    final PdfExportOptions? options = await showPdfExportOptions(context);
    if (options == null || !mounted) return;

    final bool? ok = await runWithProgressOverlay<bool>(
      context,
      task: (void Function(String step) setStep) =>
          MarkdownPdfExporter.exportAndShare(
            markdown: _pdfMarkdown,
            title: _entry.displayTitle,
            subtitle:
                '${_entry.ticker} · ${AppTokens.sideLabel(_entry.side)} · '
                '${AppTokens.fullDate(_entry.sortDate)}',
            context: context,
            options: options,
            imageResolver: JournalAttachments.bytesFor,
            onStep: setStep,
          ),
    );
    if (!mounted || ok == null) return;
    if (ok) {
      UiToast.success(
        context,
        title: 'PDF ready',
        message: 'Shared as ${_entry.displayTitle}',
      );
    } else {
      UiToast.error(
        context,
        title: 'Export failed',
        message: 'The entry could not be turned into a PDF',
      );
    }
  }

  Future<void> _toggleFavorite() =>
      _guard(() => _repo.toggleFavorite(_entry.id));

  Future<void> _shareTrade() async {
    final String shareUrl = 'https://tradex.app/p/journal/${_entry.id}';
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    UiToast.success(
      context,
      title: 'Link copied',
      message: 'Share URL copied to clipboard',
    );
  }

  /// The entry as one self-contained markdown document.
  ///
  /// The body alone is not a record of a trade — six months later a page of
  /// prose with no prices proves nothing — so the numbers are appended as a
  /// table the exporter already knows how to typeset.
  String get _pdfMarkdown {
    final AppTrade e = _entry;
    final StringBuffer out = StringBuffer();
    if (e.content.trim().isNotEmpty) {
      out
        ..writeln(e.content.trim())
        ..writeln();
    }
    out
      ..writeln('## The trade')
      ..writeln()
      ..writeln('| Field | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Instrument | ${e.ticker} |')
      ..writeln('| Side | ${AppTokens.sideLabel(e.side)} |')
      ..writeln('| Opened | ${AppTokens.fullDate(e.openedAt)} |');
    if (e.closedAt != null) {
      out.writeln('| Closed | ${AppTokens.fullDate(e.closedAt!)} |');
    }
    out.writeln('| Entry | ${AppTokens.price(e.entry)} |');
    if (e.exit != null) {
      out.writeln('| Exit | ${AppTokens.price(e.exit!)} |');
    }
    if (e.stopLoss != null) {
      out.writeln('| Stop | ${AppTokens.price(e.stopLoss!)} |');
    }
    if (e.target != null) {
      out.writeln('| Target | ${AppTokens.price(e.target!)} |');
    }
    out
      ..writeln('| Size | ${AppTokens.count(e.size)} |')
      ..writeln(
        '| ${e.isOpen ? 'Unrealised' : 'Result'} | '
        '${AppTokens.signedMoney(e.pnl)} '
        '(${AppTokens.signedPercent(e.pnlPercent)}) |',
      );
    if (e.rMultiple != null) {
      out.writeln('| R multiple | ${AppTokens.rr(e.rMultiple!)} |');
    }
    if (e.psychologyScore != null) {
      out.writeln('| Discipline | ${e.psychologyScore}/10 |');
    }
    out.writeln('| Playbook | ${e.strategy ?? 'Unfiled'} |');
    if (e.tags.isNotEmpty) {
      out.writeln('| Tags | ${e.tags.join(', ')} |');
    }
    return out.toString();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gutter = context.sp(theme.spacing.md);
    final AppLinkBundle bundle = _bundle;

    return UiPage(
      maxWidth: double.infinity,
      scrollable: false,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppJournalNoteHeader(
                entry: _entry,
                onBack: widget.onClose,
                onToggleFavorite: _busy ? null : _toggleFavorite,
                onOpenStrategy:
                    widget.onOpenLink == null || bundle.strategies.isEmpty
                    ? null
                    : () => widget.onOpenLink!(bundle.strategies.first),
                onOpenTicker: widget.onOpenLink == null
                    ? null
                    : () => widget.onOpenLink!(_graph.tickerRef(_entry.ticker)),
                actions: _headerActions(context),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // Under ~860 dp the aside would squeeze the body to the
                    // point where a markdown table wraps every cell, so the two
                    // columns become one.
                    final bool stacked = constraints.maxWidth < context.sz(860);
                    if (stacked) {
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _document(context),
                            SizedBox(height: context.sp(theme.spacing.lg)),
                            _aside(context),
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
                          child: SingleChildScrollView(child: _aside(context)),
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

  List<Widget> _headerActions(BuildContext context) {
    final UiTheme theme = context.ui;
    return <Widget>[
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: Icons.share_outlined,
        variant: UiVariant.ghost,
        tooltip: 'Share trade',
        onPressed: _busy ? null : _shareTrade,
      ),
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: Icons.picture_as_pdf_outlined,
        variant: UiVariant.ghost,
        tooltip: 'Export as PDF',
        onPressed: _busy ? null : _exportPdf,
      ),
      if (widget.onAttachToPost != null) ...<Widget>[
        SizedBox(width: context.sp(theme.spacing.xs)),
        UiIconButton(
          icon: Icons.add_comment_outlined,
          variant: UiVariant.ghost,
          tooltip: 'Attach journal entry to a post',
          onPressed: _busy
              ? null
              : () => widget.onAttachToPost!(
                  AppWritingPostAttachment.journal(_entry),
                ),
        ),
      ],
      if (widget.canEdit) ...<Widget>[
        if (widget.onEditWriting != null)
          UiIconButton(
            icon: Icons.edit_note_rounded,
            tooltip: 'Edit review',
            size: UiSize.sm,
            variant: UiVariant.outline,
            onPressed: widget.onEditWriting,
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
  }

  Widget _document(BuildContext context) {
    final UiTheme theme = context.ui;
    final String summary = (_entry.notes ?? '').trim();

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
          if (summary.isNotEmpty) ...<Widget>[
            Text(
              summary,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.md)),
          ],
          if (_entry.hasStory)
            RichMarkdownPreview(
              data: _entry.content,
              outlineController: _outline,
              imageResolver: JournalAttachments.resolve,
              emptyPlaceholder: 'This entry has no write-up yet.',
            )
          else
            UiCallout(
              intent: UiIntent.warning,
              icon: Icons.edit_note_rounded,
              title: 'No write-up yet',
              message:
                  'The numbers are logged but not the reasoning. Ten honest '
                  'lines now are worth more than an hour of analytics in six '
                  'months.',
              action: widget.canEdit
                  ? UiButton(
                      label: 'Write review in Notes',
                      leadingIcon: Icons.edit_outlined,
                      variant: UiVariant.secondary,
                      size: UiSize.sm,
                      onPressed: widget.onEditWriting,
                    )
                  : null,
            ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          AppJournalNoteMetrics(entry: _entry),
        ],
      ),
    );
  }

  Widget _aside(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _facts(context),
        SizedBox(height: gap),
        AppLinkedRecordsPanel(
          bundle: _bundle,
          title: 'Linked',
          subtitle: 'The plan, the research, the instrument',
          dense: true,
          emptyMessages: const <AppLinkKind, String>{
            AppLinkKind.strategy:
                'Not filed under a playbook. Unfiled trades cannot be rolled '
                'up into a win rate.',
            AppLinkKind.note: 'No research attached to this trade.',
          },
          onOpen: widget.onOpenLink,
          onRemove: _busy ? null : _removeLink,
          onAddNote: _busy ? null : () => _pickLinks(AppLinkKind.note),
          onAddStrategy: _busy ? null : () => _pickLinks(AppLinkKind.strategy),
        ),
        if (_siblings.isNotEmpty) ...<Widget>[
          SizedBox(height: gap),
          _siblingsCard(context),
        ],
      ],
    );
  }

  /// Everything the entry is filed under, plus how much of it was written.
  Widget _facts(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Entry details',
      subtitle: 'Edited ${AppTokens.relativeTime(_entry.editedAt)}',
      variant: UiCardVariant.outlined,
      hoverLift: false,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              UiBadge(
                label: AppTokens.outcomeLabel(_entry.outcome),
                intent: AppTokens.outcomeIntent(_entry.outcome),
                size: UiSize.xs,
              ),
              if (_entry.rMultiple != null)
                UiBadge(
                  label: AppTokens.rr(_entry.rMultiple!),
                  intent: AppTokens.plIntent(_entry.rMultiple!),
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              for (final String tag in _entry.tags)
                UiBadge(
                  label: '#$tag',
                  variant: UiBadgeVariant.ghost,
                  size: UiSize.xs,
                ),
              if (!_entry.hasStory)
                const UiBadge(
                  label: 'Needs write-up',
                  icon: Icons.edit_note_rounded,
                  intent: UiIntent.warning,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              Expanded(
                child: _metric(
                  context,
                  icon: Icons.text_fields_rounded,
                  label: 'Words',
                  value: AppTokens.count(_entry.wordCount),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: _metric(
                  context,
                  icon: Icons.schedule_rounded,
                  label: 'Read time',
                  value: _entry.hasStory ? '$_readMinutes min' : '—',
                ),
              ),
            ],
          ),
          if (_entry.hasChecklist) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiProgressBar(
              value: _entry.checklistDone / _entry.checklistTotal,
              label: 'Checklist',
              valueFormatter: (num _) =>
                  '${_entry.checklistDone} of ${_entry.checklistTotal} done',
              intent: _entry.checklistDone == _entry.checklistTotal
                  ? UiIntent.success
                  : UiIntent.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(
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

  /// Other trades taken on the same plan.
  ///
  /// This is the whole point of filing entries under a playbook: the question
  /// "does this setup actually work for me" is unanswerable from one trade and
  /// obvious from six.
  Widget _siblingsCard(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      titleWidget: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Same playbook',
              style: context.uiText.heading.copyWith(
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xxs)),
            Text(
              'Other trades filed under ${_entry.strategy ?? 'this plan'}',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
      semanticLabel: 'Same playbook',
      variant: UiCardVariant.outlined,
      hoverLift: false,
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AppLinkRef ref in _siblings)
            AppLinkRefTile(
              ref: ref,
              dense: true,
              onTap: widget.onOpenLink == null
                  ? null
                  : () => widget.onOpenLink!(ref),
            ),
        ],
      ),
    );
  }
}
