import 'package:tradex/core/config/record_access.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/core/utils/export_progress.dart';
import 'package:tradex/core/utils/markdown_pdf_export.dart';
import 'package:tradex/core/utils/pdf_export_options.dart';
import 'package:tradex/features/linking/link_graph_service.dart';

import '../data/strategies_repository.dart';
import '../data/strategy_attachments.dart';
import 'revision_note_prompt.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/community/data/unified_comments_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

/// Read-only view of one strategy playbook: the rules, the track record they
/// produced, the revisions they went through, and everything attached.
///
/// Four faces of one document, so they are tabs rather than a single long scroll.
/// A trader opening a playbook is doing one of four separate jobs — checking the
/// rules before an entry, auditing whether the rules work, finding out what the
/// rules used to say, or walking to a linked trade — and stacking all four
/// vertically means three of them start with a scroll.
///
/// Separate from the editor for the same reason the notes and journal features
/// split them: the editor optimises for reach, and a rule being checked at the
/// open wants nothing but the rule.
/// The four faces of a playbook document, addressable from outside the screen —
/// guide actions and next-best-action chips land on a specific tab, not just the
/// first one.
enum StrategyDetailTab { playbook, history, links }

class StrategyDetailScreen extends StatefulWidget {
  const StrategyDetailScreen({
    super.key,
    required this.strategy,
    required this.onClose,
    required this.onEdit,
    this.onOpenLink,
    this.onEditWriting,
    this.onAttachToPost,
    this.linkGraph,
    this.canEdit = true,
    this.isPublicContext = false,
    this.initialTab = StrategyDetailTab.playbook,
    this.savedOverride,
    this.onToggleSaved,
  });

  final AppStrategy strategy;

  /// Unwinds the host's index/document switch.
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback? onEditWriting;

  /// Cross-navigation into another record. Null renders links as plain rows,
  /// which is how a preview embedded somewhere without a navigator behaves.
  final void Function(AppLinkRef ref)? onOpenLink;
  final AppWritingPostAttachmentHandler? onAttachToPost;
  final AppLinkGraph? linkGraph;
  final bool canEdit;
  final bool isPublicContext;
  final bool? savedOverride;
  final Future<void> Function()? onToggleSaved;

  /// Which tab is selected when the document first opens. Additive — callers
  /// that do not care leave it at the default and get the playbook body.
  final StrategyDetailTab initialTab;

  @override
  State<StrategyDetailScreen> createState() => _StrategyDetailScreenState();
}

/// The four jobs a playbook is opened for.
enum _StrategyTab { playbook, history, links }

class _StrategyDetailScreenState extends State<StrategyDetailScreen> {
  final MarkdownOutlineController _outline = MarkdownOutlineController();
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final StrategiesRepository _repo = StrategiesRepositoryScope.repository;

  StreamSubscription<AppLinkGraph>? _graphSub;
  late AppLinkGraph _graph;

  List<AppStrategyVersion> _versions = const <AppStrategyVersion>[];
  bool _loadingVersions = true;
  bool _busy = false;
  _StrategyTab _tab = _StrategyTab.playbook;

  List<CommunityComment> _strategyComments = const <CommunityComment>[];

  Future<void> _loadStrategyComments() async {
    final list = await UnifiedCommentsRepositoryImpl.instance.fetchComments(
      entityType: 'strategy',
      entityId: widget.strategy.id,
    );
    if (mounted) {
      setState(() => _strategyComments = list);
    }
  }

  Future<void> _handleAddStrategyComment(
    String text, {
    String? parentCommentId,
    String? sentiment,
  }) async {
    try {
      await UnifiedCommentsRepositoryImpl.instance.addComment(
        entityType: 'strategy',
        entityId: widget.strategy.id,
        body: text,
        parentCommentId: parentCommentId,
        sentiment: sentiment,
      );
      await _loadStrategyComments();
      if (mounted) {
        UiToast.success(
          context,
          title: 'Review Posted',
          message: 'Your critique has been attached to this playbook.',
        );
      }
    } catch (e) {
      if (mounted) {
        UiToast.error(context, title: 'Could not post comment', message: '$e');
      }
      rethrow;
    }
  }

  void _handleLikeStrategyComment(String commentId, {String? reaction}) async {
    try {
      await UnifiedCommentsRepositoryImpl.instance.toggleReaction(
        commentId: commentId,
        reaction: reaction ?? '👍',
      );
      await _loadStrategyComments();
    } catch (e) {
      debugPrint('[StrategyDetailScreen] Like error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _graph = widget.linkGraph ?? _links.current;
    _tab = switch (widget.initialTab) {
      StrategyDetailTab.playbook => _StrategyTab.playbook,
      StrategyDetailTab.history => _StrategyTab.history,
      StrategyDetailTab.links => _StrategyTab.links,
    };
    // Subscribed rather than read once: filing a trade under this playbook from
    // anywhere in the app changes both its links and its win rate.
    if (widget.linkGraph == null) {
      _graphSub = _links.watch().listen((AppLinkGraph graph) {
        if (mounted) setState(() => _graph = graph);
      });
    }
    _loadVersions();
    _loadStrategyComments();
  }

  @override
  void didUpdateWidget(StrategyDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new playbook, or the same one saved again — either way the revision list
    // on screen is stale.
    if (oldWidget.strategy.id != widget.strategy.id ||
        oldWidget.strategy.versionCount != widget.strategy.versionCount) {
      _loadVersions();
    }
    if (widget.linkGraph != null && oldWidget.linkGraph != widget.linkGraph) {
      _graph = widget.linkGraph!;
    }
  }

  @override
  void dispose() {
    _graphSub?.cancel();
    _outline.dispose();
    super.dispose();
  }

  AppStrategy get _strategy => widget.strategy;
  bool get _isSaved => widget.savedOverride ?? _strategy.isFavorite;

  bool get _canEdit =>
      widget.canEdit &&
      !widget.isPublicContext &&
      RecordAccess.owns(_strategy.userId);

  bool get _canOpenWorkspaceEditor =>
      widget.onEditWriting != null && RecordAccess.owns(_strategy.userId);

  bool get _isPublicViewer => widget.isPublicContext || !_canEdit;

  AppLinkBundle get _bundle =>
      _graph.bundleForStrategy(_strategy, onlyPublic: _isPublicViewer);

  void _handleOpenLink(AppLinkRef ref) {
    if (widget.onOpenLink == null) return;
    if (_isPublicViewer && !ref.isPublicContext) {
      widget.onOpenLink!(ref.copyWith(isPublicContext: true));
    } else {
      widget.onOpenLink!(ref);
    }
  }

  /// Roughly 220 words a minute, floored at a minute.
  int get _readMinutes => (_strategy.wordCount / 220).ceil().clamp(1, 999);

  /// Journal entries filed under this playbook that were never written up.
  ///
  /// Surfaced next to the win rate because they are the reason to distrust it: a
  /// playbook whose record is built from rows of numbers nobody explained cannot
  /// tell the trader *why* it works.
  int get _unwrittenCount => _bundle.journal
      .where((AppLinkRef ref) => _graph.entry(ref.id)?.hasStory == false)
      .length;

  // ── Playbook state ─────────────────────────────────────────────────────────

  Future<void> _loadVersions() async {
    final String id = _strategy.id;
    if (id.isEmpty) {
      setState(() {
        _versions = const <AppStrategyVersion>[];
        _loadingVersions = false;
      });
      return;
    }
    setState(() => _loadingVersions = true);
    try {
      final List<AppStrategyVersion> found = await _repo.versions(id);
      // The await outlived the widget, or the trader moved to another playbook
      // while it was in flight.
      if (!mounted || _strategy.id != id) return;
      setState(() {
        _versions = found;
        _loadingVersions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingVersions = false);
      UiToast.error(
        context,
        title: 'Could not load the revision history',
        message: 'The playbook itself is fine — try again in a moment.',
      );
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Change was not saved',
          message: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Promoting a playbook is the most consequential edit there is, so going live
  /// asks first — and says what it means, which is that the next trade will be
  /// sized as though these rules are proven.
  Future<void> _setStatus(AppStrategyStatus status) async {
    if (status == _strategy.status) return;
    if (status == AppStrategyStatus.live && _strategy.trades == 0) {
      final bool ok = await UiDialog.confirm(
        context,
        title: 'Go live with no trades behind it?',
        description:
            'Nothing has been filed under this playbook yet, so there is no '
            'record saying it works. Testing keeps it in the library at reduced '
            'size until there is.',
        confirmLabel: 'Go live anyway',
      );
      if (!ok || !mounted) return;
    }
    await _guard(() async {
      await _repo.setStatus(_strategy.id, status);
      if (mounted) {
        UiToast.success(
          context,
          title: '${_strategy.name} is ${status.label.toLowerCase()}',
        );
      }
    });
  }

  Future<void> _toggleFavorite() => _guard(() async {
    final callback = widget.onToggleSaved;
    if (callback != null) {
      await callback();
      return;
    }
    await _repo.toggleFavorite(_strategy.id);
  });

  /// Publishing shares the rules, not the trader's record. Saying so at the
  /// moment of the decision is the only place it will be read.
  Future<void> _toggleVisibility() async {
    final bool next = !_strategy.isPublic;
    if (next) {
      final bool ok = await UiDialog.confirm(
        context,
        title: 'Publish these rules?',
        description:
            'The playbook body and its tags become visible in the community '
            'feed. Your journal entries, P/L and linked notes stay private.',
        confirmLabel: 'Publish',
      );
      if (!ok || !mounted) return;
    }
    await _guard(() => _repo.setVisibility(_strategy.id, next));
  }
  // ── Linking ────────────────────────────────────────────────────────────────

  /// Opens the picker for [kind] and writes every chosen edge from both ends.
  ///
  /// Everything is multi-select here: a playbook legitimately has many notes,
  /// many trades and many instruments. That is the asymmetry with the journal,
  /// where one trade files under exactly one plan.
  Future<void> _pickLinks(AppLinkKind kind) async {
    final List<AppLinkRef> linked = switch (kind) {
      AppLinkKind.note => _bundle.notes,
      AppLinkKind.journal => _bundle.journal,
      AppLinkKind.ticker => _bundle.tickers,
      AppLinkKind.strategy || _ => const <AppLinkRef>[],
    };
    final List<String>? chosen = await showAppLinkPicker(
      context,
      kind: kind,
      // Only what is not linked yet — unlinking is the panel's job, not a
      // deselection buried in a sheet.
      options: _graph.options(
        kind,
        exclude: <String>[
          _strategy.id,
          for (final AppLinkRef ref in linked) ref.id,
        ],
      ),
      title: switch (kind) {
        AppLinkKind.journal => 'File trades under this playbook',
        AppLinkKind.note => 'Attach research to this playbook',
        AppLinkKind.ticker => 'Instruments this playbook trades',
        AppLinkKind.strategy || _ => null,
      },
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;

    await _guard(() async {
      for (final String id in chosen) {
        await _links.link(
          fromKind: AppLinkKind.strategy,
          fromId: _strategy.id,
          toKind: kind,
          toId: id,
        );
      }
      if (mounted) {
        UiToast.success(
          context,
          title: 'Linked',
          message: chosen.length == 1
              ? 'One ${kind.label.toLowerCase()} attached to this playbook'
              : '${chosen.length} ${kind.plural.toLowerCase()} attached',
        );
      }
    });
  }

  /// Unfiling a trade rewrites the playbook's track record, so it says so.
  Future<void> _removeLink(AppLinkRef ref) async {
    if (_graph.hasInlineConnection(
      AppLinkKind.strategy,
      _strategy.id,
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

    final bool ok = await UiDialog.confirm(
      context,
      title: 'Unlink ${ref.title}?',
      description: ref.kind == AppLinkKind.journal
          ? 'The trade is kept, but it stops counting towards this playbook\'s '
                'win rate, average R and equity curve.'
          : 'The ${ref.kind.label.toLowerCase()} itself is kept — only the '
                'connection to this playbook goes away.',
      confirmLabel: 'Unlink',
    );
    if (!ok || !mounted) return;
    await _guard(
      () => _links.unlink(
        fromKind: AppLinkKind.strategy,
        fromId: _strategy.id,
        toKind: ref.kind,
        toId: ref.id,
      ),
    );
  }

  // ── Revisions ──────────────────────────────────────────────────────────────

  Future<void> _viewVersion(AppStrategyVersion version) => UiDialog.show<void>(
    context,
    maxWidth: 820,
    child: _VersionDialog(
      version: version,
      current: null,
      onRestore: version.isCurrent || !_canEdit
          ? null
          : () => _restoreVersion(version),
      onOpenLink: _handleOpenLink,
    ),
  );

  Future<void> _compareVersion(AppStrategyVersion version) =>
      UiDialog.show<void>(
        context,
        maxWidth: 1080,
        child: _VersionDialog(
          version: version,
          current: _strategy,
          onRestore: version.isCurrent || !_canEdit
              ? null
              : () => _restoreVersion(version),
          onOpenLink: _handleOpenLink,
        ),
      );

  /// Restoring cuts a revision first, so the rules being replaced are still
  /// readable afterwards. The confirm says that, because "restore" sounds
  /// destructive and here it is not.
  Future<void> _restoreVersion(AppStrategyVersion version) async {
    final bool ok = await UiDialog.confirm(
      context,
      title: 'Restore ${version.label}?',
      description:
          'The current rules are saved as a new revision first, so nothing is '
          'lost either way. The playbook then reads exactly as it did on '
          '${AppTokens.fullDate(version.savedAt)}.',
      confirmLabel: 'Restore ${version.label}',
    );
    if (!ok || !mounted) return;
    await _guard(() async {
      await _repo.restoreVersion(_strategy.id, version.id);
      await _loadVersions();
      if (mounted) {
        UiToast.success(
          context,
          title: 'Restored ${version.label}',
          message: 'The revision it replaced is in the history.',
        );
      }
    });
  }

  /// Snapshots the current rules with a changelog line.
  ///
  /// Asks for the line rather than saving silently: a revision list of eight
  /// untitled entries is only marginally better than no history, and the line is
  /// what makes "what changed after that bad week" answerable.
  Future<void> _saveRevision() async {
    final String? note = await showRevisionNotePrompt(context);
    if (note == null || !mounted) return;
    await _guard(() async {
      await _repo.saveVersion(_strategy.id, note: note.isEmpty ? null : note);
      await _loadVersions();
      if (mounted) UiToast.success(context, title: 'Revision saved');
    });
  }
  // ── Export ─────────────────────────────────────────────────────────────────

  /// Ask for paper size and whether diagrams travel, then export behind a
  /// blocking overlay — rendering flowcharts off-screen takes seconds, and an
  /// unguarded second tap would start a duplicate export.
  Future<void> _exportPdf() async {
    final allowed = await CustomerLimitations.checkCanExportPdf(
      context,
      featureLabel: 'Strategy Playbook PDF Export',
    );
    if (!allowed || !mounted) return;
    final PdfExportOptions? options = await showPdfExportOptions(context);
    if (options == null || !mounted) return;

    final bool? ok = await runWithProgressOverlay<bool>(
      context,
      task: (void Function(String step) setStep) =>
          MarkdownPdfExporter.exportAndShare(
            markdown: _pdfMarkdown,
            title: _strategy.name,
            subtitle:
                '${_strategy.status.label} playbook · v'
                '${_strategy.versionCount} · '
                '${AppTokens.fullDate(_strategy.updatedAt ?? DateTime.now())}',
            context: context,
            options: options,
            imageResolver: StrategyAttachments.bytesFor,
            onStep: setStep,
          ),
    );
    if (!mounted || ok == null) return;
    if (ok) {
      UiToast.success(
        context,
        title: 'PDF ready',
        message: 'Shared as ${_strategy.name}',
      );
    } else {
      UiToast.error(
        context,
        title: 'Export failed',
        message: 'The playbook could not be turned into a PDF',
      );
    }
  }

  Future<void> _shareStrategy() async {
    final AppLinkRef ref = AppLinkRef(
      kind: AppLinkKind.strategy,
      id: _strategy.id,
      isPublicContext: true,
      title: _strategy.name,
      subtitle: _strategy.category,
      meta: _strategy.status.name.toUpperCase(),
      intent: UiIntent.bullish,
    );
    await ShareToConversationDialog.showShareMenu(
      context,
      reference: ref,
      isPublic: _strategy.isPublic,
      onPublish: _canEdit
          ? () async {
              await _toggleVisibility();
              if (mounted && _strategy.isPublic) await _shareStrategy();
            }
          : null,
      onExportPdf: _exportPdf,
    );
  }

  /// The playbook as one self-contained markdown document.
  ///
  /// The rules alone are not the whole picture: a printed playbook handed to
  /// someone else, or read back in a year, needs to say what it is worth. So the
  /// record it earned is appended as a table the exporter already typesets, with
  /// "untested" spelled out rather than rendered as a row of zeros.
  String get _pdfMarkdown {
    final AppStrategy s = _strategy;
    final StringBuffer out = StringBuffer();
    if ((s.summary ?? '').trim().isNotEmpty) {
      out
        ..writeln('> ${s.summary!.trim()}')
        ..writeln();
    }
    if (s.hasPlaybook) {
      out
        ..writeln(s.content.trim())
        ..writeln();
    }
    out
      ..writeln('## Track record')
      ..writeln()
      ..writeln('| Field | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Status | ${s.status.label} |')
      ..writeln('| Revision | v${s.versionCount} |');
    if (s.trades == 0) {
      out.writeln('| Trades filed | None yet — untested |');
    } else {
      out
        ..writeln('| Trades filed | ${AppTokens.count(s.trades)} |')
        ..writeln('| Win rate | ${AppTokens.percent(s.winRate)} |')
        ..writeln('| Average R | ${AppTokens.rr(s.avgR)} |')
        ..writeln('| Net P/L | ${AppTokens.signedMoney(s.netPnl)} |');
    }
    if (s.linkedTickers.isNotEmpty) {
      out.writeln('| Instruments | ${s.linkedTickers.join(', ')} |');
    }
    if (s.tags.isNotEmpty) {
      out.writeln('| Tags | ${s.tags.join(', ')} |');
    }
    if (s.createdAt != null) {
      out.writeln('| Written | ${AppTokens.fullDate(s.createdAt!)} |');
    }
    return out.toString();
  }
  // ── Build ──────────────────────────────────────────────────────────────────

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
              AppStrategyNoteHeader(
                strategy: _strategy.copyWith(isFavorite: _isSaved),
                onBack: widget.onClose,
                onStatusChanged: _canEdit && !_busy ? _setStatus : null,
                onToggleFavorite: _busy ? null : _toggleFavorite,
                onToggleVisibility: _canEdit && !_busy
                    ? _toggleVisibility
                    : null,
                actions: _headerActions(context),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // Under ~900 dp the aside would squeeze the rules to the
                    // point where a markdown table wraps every cell, so the
                    // links move into a fourth tab instead.
                    final bool stacked = constraints.maxWidth < context.sz(900);
                    return stacked
                        ? _stackedBody(context)
                        : _splitBody(context);
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

  void _analyzeWithAi() {
    final String prompt =
        'Critique and optimize quantitative strategy "${_strategy.name}" (${_strategy.category ?? 'General'}):\n\n'
        'Status: ${_strategy.status.label}, Revisions: ${_strategy.versionCount}\n'
        'Win Rate: ${AppTokens.percent(_strategy.winRate)}, Average R: ${AppTokens.rr(_strategy.avgR)}, Total Trades: ${_strategy.trades}, Net PnL: ${AppTokens.signedMoney(_strategy.netPnl)}\n\n'
        'Playbook Rules:\n${_strategy.content}\n\n'
        'Provide mathematical risk analysis, edge evaluation, failure modes to protect against, and proposed rule enhancements.';

    CopilotSheet.show(
      context,
      repository: CopilotScope.repository,
      initialPrompt: prompt,
      contextTitle: _strategy.name,
      contextSubtitle:
          'Win Rate: ${AppTokens.percent(_strategy.winRate)} · ${_strategy.trades} Trades',
      contextIcon: Icons.account_tree_outlined,
      contextRef: AppLinkRef(
        id: _strategy.id,
        kind: AppLinkKind.strategy,
        title: _strategy.name,
        subtitle: _strategy.category,
      ),
      onOpenRef: _handleOpenLink,
      onOpenFullScreen: () {
        if (widget.onOpenLink != null) {
          _handleOpenLink(
            const AppLinkRef(
              id: 'ai_copilot',
              kind: AppLinkKind.aiCopilot,
              title: 'AI Copilot',
              subtitle: 'Strategy Critique',
            ),
          );
        }
      },
    );
  }

  List<Widget> _headerActions(BuildContext context) {
    final UiTheme theme = context.ui;
    return <Widget>[
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: Icons.auto_awesome_rounded,
        variant: UiVariant.ghost,
        intent: UiIntent.primary,
        tooltip: 'Critique and optimize strategy with AI',
        onPressed: _busy ? null : _analyzeWithAi,
      ),
      SizedBox(width: context.sp(theme.spacing.xs)),
      UiIconButton(
        icon: Icons.share_outlined,
        variant: UiVariant.ghost,
        tooltip: 'Share strategy',
        onPressed: _busy ? null : _shareStrategy,
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
          tooltip: 'Attach strategy to a post',
          onPressed: _busy
              ? null
              : () => widget.onAttachToPost!(
                  AppWritingPostAttachment.strategy(_strategy),
                ),
        ),
      ],
      if (_canEdit) ...<Widget>[
        if (widget.onEditWriting != null)
          UiIconButton(
            icon: Icons.edit_note_rounded,
            tooltip: 'Edit playbook',
            size: UiSize.sm,
            variant: UiVariant.outline,
            onPressed: widget.onEditWriting,
          ),

        UiIconButton(
          icon: Icons.bookmark_add_outlined,
          variant: UiVariant.ghost,
          tooltip: 'Save a revision',
          onPressed: _busy ? null : _saveRevision,
        ),
        SizedBox(width: context.sp(theme.spacing.xs)),
        UiIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit details',
          size: UiSize.sm,
          variant: UiVariant.primary,
          onPressed: _busy ? null : widget.onEdit,
        ),
      ] else if (_canOpenWorkspaceEditor) ...<Widget>[
        SizedBox(width: context.sp(theme.spacing.xs)),
        UiIconButton(
          icon: Icons.edit_note_rounded,
          tooltip: 'Edit in Writing Desk',
          size: UiSize.sm,
          variant: UiVariant.primary,
          onPressed: _busy ? null : widget.onEditWriting,
        ),
      ],
    ];
  }

  /// Desktop: three tabs beside a permanent links aside.
  ///
  /// Links stay on screen because on a playbook they are the point — the trades
  /// filed under it are the evidence for every number in the Performance tab, and
  /// hiding them behind a tab would make the two impossible to read together.
  Widget _splitBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: _tabbedBody(context, showLinksTab: false)),
        SizedBox(width: context.sp(theme.spacing.lg)),
        SizedBox(
          width: context.sz(320),
          child: SingleChildScrollView(child: _aside(context, withFacts: true)),
        ),
      ],
    );
  }

  /// Phone and narrow tablet: links become the fourth tab.
  Widget _stackedBody(BuildContext context) =>
      _tabbedBody(context, showLinksTab: true);
  Widget _tabbedBody(BuildContext context, {required bool showLinksTab}) {
    final UiTheme theme = context.ui;
    final List<_StrategyTab> tabs = <_StrategyTab>[
      _StrategyTab.playbook,
      _StrategyTab.history,
      if (showLinksTab) _StrategyTab.links,
    ];
    // The links tab disappears when the aside appears, so a selection made on a
    // phone cannot survive a rotation into the split layout.
    final int index = tabs.contains(_tab) ? tabs.indexOf(_tab) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiTabs(
          items: <UiTabItem>[
            for (final _StrategyTab t in tabs)
              UiTabItem(
                label: _tabLabel(t),
                icon: _tabIcon(t),
                count: _tabCount(t),
              ),
          ],
          index: index,
          showPanel: false,
          scrollable: showLinksTab,
          stretch: !showLinksTab,
          onChanged: (int i) => setState(() => _tab = tabs[i]),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(bottom: context.uiPageBottomInset),
              child: switch (tabs[index]) {
                // The facts card rides with the playbook only when there is no
                // aside to hold it, so the split layout never shows it twice.
                _StrategyTab.playbook => _playbookTab(
                  context,
                  showFacts: showLinksTab,
                ),
                _StrategyTab.history => _historyTab(context),
                _StrategyTab.links => _aside(context, withFacts: false),
              },
            ),
          ),
        ),
      ],
    );
  }

  String _tabLabel(_StrategyTab tab) => switch (tab) {
    _StrategyTab.playbook => 'Playbook',
    _StrategyTab.history => 'History',
    _StrategyTab.links => 'Links',
  };

  IconData _tabIcon(_StrategyTab tab) => switch (tab) {
    _StrategyTab.playbook => Icons.menu_book_outlined,
    _StrategyTab.history => Icons.history_rounded,
    _StrategyTab.links => Icons.link_rounded,
  };

  /// Counts on tabs, not decoration: they answer "is there anything in there"
  /// before the trader spends a tap finding out.
  int? _tabCount(_StrategyTab tab) => switch (tab) {
    _StrategyTab.playbook => null,
    _StrategyTab.history => _loadingVersions ? null : _versions.length,
    _StrategyTab.links => _bundle.length == 0 ? null : _bundle.length,
  };

  // ── Playbook tab ───────────────────────────────────────────────────────────

  Widget _playbookTab(BuildContext context, {required bool showFacts}) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_strategy.hasPlaybook)
          RichMarkdownPreview(
            data: _strategy.content,
            outlineController: _outline,
            imageResolver: StrategyAttachments.resolve,
            emptyPlaceholder: 'This playbook has no rules written yet.',
            onOpenRef: _handleOpenLink,
          )
        else
          UiCallout(
            intent: UiIntent.warning,
            icon: Icons.edit_note_rounded,
            title: 'No rules written yet',
            message:
                'A playbook with no body cannot be checked against a trade. '
                'Write the trigger, where the stop goes, and what would make '
                'you stand aside.',
            action: _canEdit
                ? UiButton(
                    label: 'Write playbook in Notes',
                    leadingIcon: Icons.edit_outlined,
                    variant: UiVariant.secondary,
                    size: UiSize.sm,
                    onPressed: widget.onEditWriting,
                  )
                : null,
          ),
        if (showFacts) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.lg)),
          _factsCard(context),
        ],
        SizedBox(height: context.sp(theme.spacing.xl)),
        UniversalCommentsSection(
          targetId: widget.strategy.id,
          targetType: 'strategy',
          title: 'Playbook Discussion & Peer Critique',
          comments: _strategyComments,
          isPublic: _strategy.isPublic,
          canToggleVisibility: _canEdit,
          onToggleVisibility: (v) => _toggleVisibility(),
          currentUser: UnifiedCommentsRepositoryImpl.instance
              .getCurrentAuthor(),
          onAddComment: _handleAddStrategyComment,
          onLikeComment: _handleLikeStrategyComment,
        ),
      ],
    );
  }
  // ── Performance tab ────────────────────────────────────────────────────────

  /// The record, then the trades it came from.
  ///
  /// In that order and never separated: every figure above is a claim, and the
  /// list below is the evidence. A trader who disagrees with the win rate can tap
  /// straight through to the trade that produced it.
  // The overview owns analytics; retained for downstream read-only embedders.
  // ignore: unused_element
  Widget _performanceTab(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.md);
    final List<AppLinkRef> filed = _bundle.journal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppStrategyNotePerformance(strategy: _strategy),
        if (_unwrittenCount > 0) ...<Widget>[
          SizedBox(height: gap),
          UiCallout(
            intent: UiIntent.warning,
            icon: Icons.edit_note_rounded,
            title: _unwrittenCount == 1
                ? 'One filed trade has no write-up'
                : '$_unwrittenCount filed trades have no write-up',
            message:
                'The numbers above are complete, but they cannot say why this '
                'playbook works. Entries without a story are the ones that get '
                'repeated by accident.',
          ),
        ],
        SizedBox(height: gap),
        UiCard(
          title: 'Trades filed under this playbook',
          subtitle: filed.isEmpty
              ? 'Nothing yet — the record above fills itself in as entries are '
                    'filed'
              : '${filed.length} ${filed.length == 1 ? 'entry' : 'entries'}, '
                    'newest first',
          variant: UiCardVariant.outlined,
          hoverLift: false,
          padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.sm)),
          child: filed.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(gap),
                  child: UiEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No trades filed',
                    message:
                        'File an entry under this playbook from the journal, or '
                        'link one here.',
                    action: _canEdit
                        ? UiButton(
                            label: 'Link trades',
                            leadingIcon: Icons.add_link_rounded,
                            variant: UiVariant.secondary,
                            size: UiSize.sm,
                            onPressed: _busy
                                ? null
                                : () => _pickLinks(AppLinkKind.journal),
                          )
                        : null,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final AppLinkRef ref in filed)
                      AppLinkRefTile(
                        ref: ref,
                        dense: true,
                        // Flags the entry whose numbers count but whose
                        // reasoning is missing.
                        trailing: _graph.entry(ref.id)?.hasStory == false
                            ? const UiBadge(
                                label: 'No write-up',
                                icon: Icons.edit_note_rounded,
                                intent: UiIntent.warning,
                                variant: UiBadgeVariant.soft,
                                size: UiSize.xs,
                              )
                            : null,
                        onTap: widget.onOpenLink == null
                            ? null
                            : () => _handleOpenLink(ref),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
  // ── History tab ────────────────────────────────────────────────────────────

  Widget _historyTab(BuildContext context) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.md);

    if (_loadingVersions) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < 3; i++) ...<Widget>[
            UiSkeleton(height: context.sz(76)),
            SizedBox(height: gap),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiCallout(
          intent: UiIntent.info,
          icon: Icons.history_rounded,
          title: 'Why the history matters',
          message:
              'A win rate is only meaningful next to the rules that were in '
              'force while it was earned. Every revision keeps its full body, so '
              'a run of results can always be read against the plan behind it.',
          action: _canEdit
              ? UiButton(
                  label: 'Save a revision',
                  leadingIcon: Icons.bookmark_add_outlined,
                  variant: UiVariant.secondary,
                  size: UiSize.sm,
                  onPressed: _busy ? null : _saveRevision,
                )
              : null,
        ),
        SizedBox(height: gap),
        AppStrategyNoteVersionList(
          versions: _versions,
          onView: _viewVersion,
          onCompare: _compareVersion,
          onRestore: _canEdit && !_busy ? _restoreVersion : null,
        ),
      ],
    );
  }
  // ── Links aside / tab ──────────────────────────────────────────────────────

  Widget _aside(BuildContext context, {required bool withFacts}) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppLinkedRecordsPanel(
          bundle: _bundle,
          title: 'Linked',
          subtitle: 'The trades, the research, the instruments',
          dense: true,
          emptyMessages: const <AppLinkKind, String>{
            AppLinkKind.journal:
                'No trades filed under this playbook yet, so it has no record '
                'of its own.',
            AppLinkKind.note:
                'No research attached. Link the note that made you write these '
                'rules.',
            AppLinkKind.ticker:
                'No instruments named. A playbook that applies to everything '
                'usually applies to nothing.',
          },
          onOpen: _handleOpenLink,
          onRemove: _canEdit && !_busy ? _removeLink : null,
          onAddNote: _canEdit && !_busy
              ? () => _pickLinks(AppLinkKind.note)
              : null,
          onAddJournal: _canEdit && !_busy
              ? () => _pickLinks(AppLinkKind.journal)
              : null,
          onAddTicker: _canEdit && !_busy
              ? () => _pickLinks(AppLinkKind.ticker)
              : null,
        ),
        if (withFacts) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          _factsCard(context),
        ],
      ],
    );
  }
  // ── Facts ──────────────────────────────────────────────────────────────────

  /// Status, reach and shape of the document itself.
  ///
  /// Deliberately separate from the Performance tab: this card answers "what am
  /// I looking at and who can see it", which is a different question from "does
  /// it make money", and mixing the two is how a draft gets mistaken for a
  /// proven edge.
  Widget _factsCard(BuildContext context) {
    final UiTheme theme = context.ui;
    final AppStrategy s = _strategy;
    return UiCard(
      title: 'Playbook details',
      subtitle: s.updatedAt == null
          ? 'Not saved yet'
          : 'Edited ${AppTokens.relativeTime(s.updatedAt!)}',
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
                label: s.status.label,
                icon: s.status.icon,
                intent: s.status.intent,
                size: UiSize.xs,
              ),
              UiBadge(
                label: s.isPublic ? 'Public' : 'Private',
                icon: s.isPublic
                    ? Icons.public_rounded
                    : Icons.lock_outline_rounded,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
              ),
              if (s.category != null)
                UiBadge(
                  label: s.category!,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
              for (final String tag in s.tags)
                UiBadge(
                  label: '#$tag',
                  variant: UiBadgeVariant.ghost,
                  size: UiSize.xs,
                ),
              if (s.isFavorite)
                const UiBadge(
                  label: 'Pinned',
                  icon: Icons.star_rounded,
                  intent: UiIntent.warning,
                  variant: UiBadgeVariant.soft,
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
                  value: AppTokens.count(s.wordCount),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: _metric(
                  context,
                  icon: Icons.schedule_rounded,
                  label: 'Read time',
                  value: s.hasPlaybook ? '$_readMinutes min' : '—',
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              Expanded(
                child: _metric(
                  context,
                  icon: Icons.history_rounded,
                  label: 'Revisions',
                  value: AppTokens.count(
                    _loadingVersions ? s.versionCount : _versions.length,
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: _metric(
                  context,
                  icon: Icons.link_rounded,
                  label: 'Linked',
                  value: AppTokens.count(_bundle.length),
                ),
              ),
            ],
          ),
          // A rules checklist is the one part of a playbook that gets read at
          // speed, so its completeness is worth a bar rather than a number.
          if (s.hasChecklist) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiProgressBar(
              value: s.checklistDone / s.checklistTotal,
              label: 'Rules checked off',
              valueFormatter: (num _) =>
                  '${s.checklistDone} of ${s.checklistTotal}',
              intent: s.checklistDone == s.checklistTotal
                  ? UiIntent.success
                  : UiIntent.primary,
            ),
          ],
          if (s.linkedTickers.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(
              'Instruments',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final String symbol in s.linkedTickers)
                  UiBadge(
                    label: symbol.toUpperCase(),
                    icon: Icons.candlestick_chart_outlined,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                    onTap: widget.onOpenLink == null
                        ? null
                        : () => _handleOpenLink(
                            AppLinkRef(
                              kind: AppLinkKind.ticker,
                              id: symbol.toUpperCase(),
                              title: symbol.toUpperCase(),
                            ),
                          ),
                  ),
              ],
            ),
          ],
          if (s.createdAt != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(
              'Created ${AppTokens.fullDate(s.createdAt!)}',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
}

/// One revision, on its own or beside the live rules.
///
/// Two modes rather than two widgets: reading an old revision and comparing it
/// with today's are the same act a second apart, and a trader who opens the
/// wrong one should not have to close a dialog to switch. [current] null means
/// read; non-null means compare.
class _VersionDialog extends StatelessWidget {
  const _VersionDialog({
    required this.version,
    required this.current,
    required this.onRestore,
    this.onOpenLink,
  });

  final AppStrategyVersion version;
  final AppStrategy? current;
  final VoidCallback? onRestore;
  final void Function(AppLinkRef ref)? onOpenLink;

  bool get _isCompare => current != null;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.62;
    return UiDialog(
      title: _isCompare
          ? '${version.label} vs. live rules'
          : '${version.label}${version.isCurrent ? ' — live' : ''}',
      description: _describe(),
      icon: _isCompare ? Icons.compare_arrows_rounded : Icons.history_rounded,
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (!_isCompare) return _pane(context, version.content);
            // Side by side only when each column still has room to read; below
            // that the two bodies stack, which beats two 140 dp gutters.
            return constraints.maxWidth >= context.sz(720)
                ? _sideBySide(context)
                : _stacked(context);
          },
        ),
      ),
      actions: <Widget>[
        UiButton(
          label: 'Close',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (onRestore != null)
          UiButton(
            label: 'Restore ${version.label}',
            leadingIcon: Icons.restore_rounded,
            variant: UiVariant.secondary,
            onPressed: () {
              Navigator.of(context).pop();
              onRestore!();
            },
          ),
      ],
    );
  }

  /// The changelog line if there is one, the timestamp either way.
  ///
  /// The note comes first because it is the only part a trader wrote on purpose.
  String _describe() {
    final String when = AppTokens.fullDate(version.savedAt);
    final String by = version.author == null ? '' : ' by ${version.author}';
    final String words = '${AppTokens.count(version.wordCount)} words';
    final String note = (version.note ?? '').trim();
    return note.isEmpty
        ? 'Saved $when$by · $words. No changelog line was written.'
        : '$note\n\nSaved $when$by · $words.';
  }

  Widget _sideBySide(BuildContext context) {
    final UiTheme theme = context.ui;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _labelledPane(
            context,
            label: version.label,
            sublabel: AppTokens.relativeTime(version.savedAt),
            body: version.content,
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.md)),
        Expanded(
          child: _labelledPane(
            context,
            label: 'Live rules',
            sublabel: current!.updatedAt == null
                ? 'Unsaved'
                : AppTokens.relativeTime(current!.updatedAt!),
            body: current!.content,
            intent: UiIntent.primary,
          ),
        ),
      ],
    );
  }

  Widget _stacked(BuildContext context) {
    final UiTheme theme = context.ui;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _labelledPane(
            context,
            label: version.label,
            sublabel: AppTokens.relativeTime(version.savedAt),
            body: version.content,
            scrollable: false,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          _labelledPane(
            context,
            label: 'Live rules',
            sublabel: current!.updatedAt == null
                ? 'Unsaved'
                : AppTokens.relativeTime(current!.updatedAt!),
            body: current!.content,
            intent: UiIntent.primary,
            scrollable: false,
          ),
        ],
      ),
    );
  }

  Widget _labelledPane(
    BuildContext context, {
    required String label,
    required String sublabel,
    required String body,
    UiIntent? intent,
    bool scrollable = true,
  }) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            UiBadge(
              label: label,
              intent: intent ?? UiIntent.neutral,
              variant: intent == null
                  ? UiBadgeVariant.outline
                  : UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Expanded(
              child: Text(
                sublabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (scrollable)
          Expanded(child: _pane(context, body))
        else
          _pane(context, body, scrollable: false),
      ],
    );
  }

  /// A revision body renders through the same pipeline as the live playbook, so
  /// a table or a chart block reads the same in history as it did the day it was
  /// written. Images resolve too: an annotated chart is often the whole reason a
  /// rule changed.
  Widget _pane(BuildContext context, String body, {bool scrollable = true}) {
    final UiTheme theme = context.ui;
    final Widget content = Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: RichMarkdownPreview(
        data: body,
        imageResolver: StrategyAttachments.resolve,
        emptyPlaceholder: 'This revision has no rules written.',
        onOpenRef: onOpenLink,
      ),
    );
    return UiCard(
      variant: UiCardVariant.outlined,
      hoverLift: false,
      motion: false,
      padding: EdgeInsets.zero,
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}
