import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/linking/link_graph_service.dart';

import '../data/note_templates.dart';
import '../data/notes_repository.dart';
import '../data/record_writing_repository.dart';
import 'note_editor_screen.dart';
import 'note_preview_screen.dart';
import 'note_template_gallery.dart';

/// Which of the three surfaces the notes destination is showing.
enum _NotesView { list, preview, editor }

enum _NotesCollection { mine, public }

/// The notes destination, for every role.
///
/// There is no router in this app — the shell swaps a single widget per sidebar
/// id — so this screen owns the list ⇄ read ⇄ write transition itself. The list
/// is driven by [NotesRepository.watchAll], which means a save made in the
/// editor, a delete made in the preview and an import made anywhere else all
class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    this.onSubpageChanged,
    this.onOpenRef,
    this.onOpenWriting,
    this.onAttachToPost,
    this.openRequest,
  });

  /// Lets the shell draw the open note's title and back button on mobile.
  final void Function(String? title, IconData? icon, VoidCallback? onBack)?
  onSubpageChanged;

  /// Follows a link into another destination. Null when the shell cannot reach
  /// it for this role, in which case cross-kind links stay inert rather than
  /// pretending to navigate.
  final void Function(AppLinkRef ref)? onOpenRef;
  final ValueChanged<AppLinkRef>? onOpenWriting;
  final AppWritingPostAttachmentHandler? onAttachToPost;

  /// A note the shell wants opened — how a link from a trade or a playbook lands
  /// on the right note.
  final AppLinkOpenRequest? openRequest;

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  /// Public entry point so host workspaces (like Writing Desk) can trigger
  /// new note creation.
  void newNote() => _newNote();

  /// Public entry point for the unified Writing Desk help action.
  void showGuide() => _showGuide();

  void showGuideWithTargets(List<GlobalKey> targets) =>
      FeatureGuideSpotlight.show(
        context,
        feature: FeatureId.notes,
        steps: FeatureGuideSteps.notes,
        targets: targets,
        onStepAction: _onGuideStepAction,
      );

  void setSearchQuery(String value) {
    if (_query == value || !mounted) return;
    _updateFilter(() => _query = value);
  }

  void showFilters() => _noteFilterBlock().showFilters(context);

  void performGuideStep(FeatureGuideStep step) => _onGuideStepAction(step);

  static const int _pageSize = 12;

  final NotesRepository _repo = NotesRepositoryScope.repository;
  final AppLinkGraphService _links = AppLinkGraphScope.service;
  final ScrollController _notesScrollController = ScrollController();

  final GlobalKey _guideFilterKey = GlobalKey();
  StreamSubscription<List<AppNote>>? _sub;
  StreamSubscription<List<AppNote>>? _publicSub;
  StreamSubscription<AppLinkGraph>? _graphSub;

  List<AppNote> _notes = const <AppNote>[];
  List<AppNote> _publicNotes = const <AppNote>[];
  late AppLinkGraph _graph = _links.current;
  bool _loading = true;

  String _query = '';
  AppNoteType? _type;
  String? _tag;
  AppNoteSort _sort = AppNoteSort.recentlyUpdated;
  AppNoteDensity _density = AppNoteDensity.comfortable;
  int _visibleLimit = _pageSize;
  _NotesCollection _collection = _NotesCollection.mine;

  _NotesView _view = _NotesView.list;
  AppNote? _active;
  AppLinkOpenRequest? _appliedRequest;
  RecordWritingDocument? _sourceWriting;
  bool _openingWriting = false;

  NoteEditorMode _editorMode = NoteEditorMode.write;

  @override
  void initState() {
    super.initState();
    _notesScrollController.addListener(_loadMoreNearBottom);
    _sub = _repo.watchAll().listen(
      (List<AppNote> notes) {
        if (!mounted) return;
        setState(() {
          _notes = notes;
          _loading = false;
        });
        if (widget.openRequest != null) _apply(widget.openRequest!);
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _loading = false);
        UiToast.error(
          context,
          title: 'Could not load notes',
          message: '$error',
        );
      },
    );
    _publicSub = _repo.watchPublic().listen((List<AppNote> notes) {
      if (mounted) {
        setState(() => _publicNotes = notes);
        if (widget.openRequest != null) _apply(widget.openRequest!);
      }
    });
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null) {
      // Deferred: the shell mounts this screen and hands over the request in the
      // same frame, before the first stream event has arrived.
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(request));
    }
  }

  @override
  void didUpdateWidget(NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null && request != oldWidget.openRequest) _apply(request);
  }

  /// Applies a request from the shell. A request for another kind can only mean
  /// the shell routed it here by mistake, and an unknown id can only mean the
  /// note was deleted between the click and the switch, so both degrade to
  /// leaving the list alone.
  void _apply(AppLinkOpenRequest request) {
    if (request == _appliedRequest) return;
    if (request.editWriting && request.kind != AppLinkKind.note) {
      _appliedRequest = request;
      _openSourceWriting(
        AppLinkRef(kind: request.kind, id: request.id, title: request.id),
      );
      return;
    }
    if (request.kind != AppLinkKind.note) return;
    for (final AppNote note in <AppNote>[..._notes, ..._publicNotes]) {
      if (note.id == request.id) {
        _appliedRequest = request;
        // A public note opened by link belongs to the public collection, or the
        // list behind the preview would not contain what the reader is reading.
        if (!_notes.any((AppNote n) => n.id == note.id)) {
          setState(() => _collection = _NotesCollection.public);
        }
        if (request.editWriting) {
          _edit(note);
        } else {
          _open(note);
        }
        return;
      }
    }
  }

  Future<void> _openSourceWriting(AppLinkRef ref) async {
    if (_openingWriting) return;
    setState(() => _openingWriting = true);
    try {
      final source = await RecordWritingRepository().open(ref.kind, ref.id);
      if (!mounted) return;
      setState(() => _sourceWriting = source);
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not open writing',
          message: '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _openingWriting = false);
    }
  }

  void _closeSourceWriting(AppNote? saved) {
    final ref = _sourceWriting!.source;
    setState(() => _sourceWriting = null);
    widget.onOpenRef?.call(ref);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _publicSub?.cancel();
    _graphSub?.cancel();
    _notesScrollController
      ..removeListener(_loadMoreNearBottom)
      ..dispose();
    super.dispose();
  }

  List<AppNote> get _visible => NotesQuery.apply(
    _collection == _NotesCollection.mine ? _notes : _publicNotes,
    query: _query,
    type: _type,
    tag: _tag,
    sort: _sort,
  );

  List<AppNote> get _visibleBatch =>
      _visible.take(_visibleLimit).toList(growable: false);

  void _loadMoreNearBottom() {
    if (!_notesScrollController.hasClients ||
        _visibleLimit >= _visible.length) {
      return;
    }
    if (_notesScrollController.position.extentAfter > context.sz(480)) return;
    setState(() => _visibleLimit += _pageSize);
  }

  void _updateFilter(VoidCallback update) => setState(() {
    update();
    _visibleLimit = _pageSize;
  });

  bool get _filtered =>
      _query.trim().isNotEmpty || _type != null || _tag != null;

  void _clearFilters() => _updateFilter(() {
    _query = '';
    _type = null;
    _tag = null;
  });

  AppNoteFilterBlock _noteFilterBlock({
    bool showSearch = true,
    bool showFilterControl = true,
    VoidCallback? onNew,
  }) => AppNoteFilterBlock(
    key: _guideFilterKey,
    showSearch: showSearch,
    showFilterControl: showFilterControl,
    query: _query,
    type: _type,
    tag: _tag,
    sort: _sort,
    density: _density,
    availableTags: NotesQuery.tagsOf(_notes),
    onQueryChanged: (String q) => _updateFilter(() => _query = q),
    onTypeChanged: (AppNoteType? t) => _updateFilter(() => _type = t),
    onTagChanged: (String? t) => _updateFilter(() => _tag = t),
    onSortChanged: (AppNoteSort s) => _updateFilter(() => _sort = s),
    onDensityChanged: (AppNoteDensity d) => setState(() => _density = d),
    onNew: onNew,
  );

  /// New notes start from the gallery rather than a blank page: a template is
  /// the fastest way to learn the syntax, and the fastest way to start writing
  /// for someone who never will.
  void _notifySubpage() {
    if (!mounted) return;
    switch (_view) {
      case _NotesView.preview when _active != null:
        final String title = _active!.title.trim().isEmpty
            ? 'Untitled note'
            : _active!.title.trim();
        widget.onSubpageChanged?.call(
          title,
          Icons.note_alt_outlined,
          _backToList,
        );
        break;
      case _NotesView.editor:
        final String title = _active == null || _active!.title.trim().isEmpty
            ? 'New note'
            : _active!.title.trim();
        widget.onSubpageChanged?.call(title, Icons.edit_outlined, _backToList);
        break;
      case _NotesView.list:
      default:
        widget.onSubpageChanged?.call(null, null, null);
        break;
    }
  }

  Future<void> _newNote() async {
    final AppNoteTemplate? template = await showNoteTemplateGallery(context);
    if (template == null || !mounted) return;
    setState(() {
      _collection = _NotesCollection.mine;
      _active = template.toDraft();
      _editorMode = NoteEditorMode.write;
      _view = _NotesView.editor;
    });
    _notifySubpage();
  }

  void _open(AppNote note) {
    setState(() {
      _active = note;
      _view = _NotesView.preview;
    });
    _notifySubpage();
  }

  void _edit(AppNote note, {NoteEditorMode mode = NoteEditorMode.write}) {
    setState(() {
      _active = note;
      _editorMode = mode;
      _view = _NotesView.editor;
    });
    _notifySubpage();
  }

  /// The editor hands back what it saved, so closing it lands on the note the
  /// writer just wrote — including one created from a draft, whose id the host
  /// never saw. Nothing saved means there is nothing to read: back to the list.
  void _closeEditor(AppNote? saved) {
    setState(() {
      _active = saved;
      _view = saved == null ? _NotesView.list : _NotesView.preview;
    });
    _notifySubpage();
  }

  void _backToList() {
    setState(() {
      _active = null;
      _view = _NotesView.list;
    });
    _notifySubpage();
  }

  /// Follows a link out of a note. Note → note stays here; a trade or a playbook
  /// belongs to another destination and goes back through the shell.
  void _openRef(AppLinkRef ref) {
    if (ref.missing) {
      UiToast.info(
        context,
        title: 'That record is gone',
        message: 'The link is kept so you can see it broke.',
      );
      return;
    }
    if (ref.kind == AppLinkKind.note) {
      for (final AppNote note in <AppNote>[..._notes, ..._publicNotes]) {
        if (note.id == ref.id) {
          _open(note);
          return;
        }
      }
      return;
    }
    final void Function(AppLinkRef ref)? jump = widget.onOpenRef;
    if (jump == null) {
      UiToast.info(
        context,
        title: ref.title,
        message: '${ref.kind.label} — not available from here.',
      );
      return;
    }
    jump(ref);
  }

  Future<void> _delete(AppNote note) async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete this note?',
      description:
          '"${note.title.trim().isEmpty ? 'Untitled note' : note.title.trim()}" '
          'and everything in it goes away. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    try {
      await _repo.delete(note.id);
      if (!mounted) return;
      UiToast.success(context, title: 'Note deleted');
      if (_active?.id == note.id) _backToList();
    } catch (error) {
      if (!mounted) return;
      UiToast.error(context, title: 'Could not delete', message: '$error');
    }
  }

  // ── Guide ──────────────────────────────────────────────────────────────────

  /// Opens the notes walkthrough, at any time, from the header help action or
  /// the banner's "Show guide" button. The owning screen resolves each step's
  /// action into real navigation below.
  void _showGuide() {
    FeatureGuideSpotlight.show(
      context,
      feature: FeatureId.notes,
      steps: FeatureGuideSteps.notes,
      targets: <GlobalKey>[_guideFilterKey],
      onStepAction: _onGuideStepAction,
    );
  }

  /// Maps a guide step to the real surface it describes. The sheet already marks
  /// the step done when its action button is pressed; this only navigates — it
  /// never fakes completion, and a step with nothing to act on navigates nowhere
  /// and says so.
  void _onGuideStepAction(FeatureGuideStep step) {
    switch (step.id) {
      case 'review':
        _newNote();
      case 'link':
        _linkNote();
      case 'tags':
        _tagNote();
      case 'refactor':
        _refactorNote();
      case 'weekly':
        _reviewWeekly();
      default:
        break;
    }
  }

  /// "Link it to the trade and the playbook" — linking happens in the note
  /// editor's details panel, so the step lands on the note most in need of one:
  /// the newest note with neither a playbook nor a journal entry attached.
  void _linkNote() {
    final AppNote? target = _firstNoteWhere(
      (AppNote n) =>
          _graph.bundleForNote(n).strategies.isEmpty &&
          _graph.bundleForNote(n).journal.isEmpty,
    );
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to link',
        message: 'Write a note first, then link it to a trade and a playbook.',
      );
      return;
    }
    _edit(target);
  }

  /// "Tag it" — tags are the note editor's tag field, so the step lands on the
  /// newest note that has none.
  void _tagNote() {
    final AppNote? target = _firstNoteWhere((AppNote n) => n.tags.isEmpty);
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to tag',
        message: 'Every note already has a tag.',
      );
      return;
    }
    _edit(target);
  }

  /// "Use the AI refactor" — the AI surface lives in the editor, so the step
  /// lands on the newest note, ready for a selection to be rewritten.
  void _refactorNote() {
    final AppNote? target = _firstNoteWhere((AppNote _) => true);
    if (target == null) {
      UiToast.info(
        context,
        title: 'Nothing to refactor',
        message: 'Write a note first, then tighten it with the AI.',
      );
      return;
    }
    _edit(target);
  }

  /// "Revisit weekly using tag filters" — the weekly review is the landing with
  /// the review notes pulled to the front, via the existing type filter rather
  /// than a new surface.
  void _reviewWeekly() {
    _backToList();
    _updateFilter(() {
      _collection = _NotesCollection.mine;
      _type = AppNoteType.review;
      _tag = null;
    });
  }

  /// First mine-note matching [test], in the repository's recently-edited order
  /// — so "first" means "most recent", which is the one the trader is most
  /// likely to mean.
  AppNote? _firstNoteWhere(bool Function(AppNote n) test) {
    for (final AppNote n in _notes) {
      if (test(n)) return n;
    }
    return null;
  }

  // ── Next-best action ───────────────────────────────────────────────────────

  /// The pipeline nudges shown as compact chips between the filter bar and the
  /// grid.
  ///
  /// Derived from the **whole notebook** (`_notes`) plus the link graph — never
  /// from the filtered slice, because "2 trades without a review" is true of the
  /// workspace even while a search narrows what is on screen. Ordered
  /// Review-first:
  ///
  ///  1. Journal entries whose linked-note set is empty → open the record
  ///     writing flow, which is how a review is written back into the trade.
  ///  2. Mine-notes with no tags → open the newest in the editor, where tags
  ///     are edited.
  ///
  /// Empty while the stream is still loading or when there is nothing to act on,
  /// so the row never advertises a zero. A chip whose action cannot be wired
  /// honestly is simply not emitted.
  List<_NextAction> get _nextActions {
    if (_loading) return const <_NextAction>[];
    final List<AppTrade> unreviewed = _graph.journalList
        .where((AppTrade t) => _graph.bundleForJournal(t).notes.isEmpty)
        .toList(growable: false);
    final List<AppNote> untagged = _notes
        .where((AppNote n) => n.tags.isEmpty)
        .toList(growable: false);

    return <_NextAction>[
      if (unreviewed.isNotEmpty)
        _NextAction(
          label: unreviewed.length == 1
              ? '1 trade still without a review note'
              : '${unreviewed.length} trades still without a review note',
          icon: Icons.edit_note_rounded,
          intent: UiIntent.warning,
          onTap: () => _openSourceWriting(_graph.journalRef(unreviewed.first)),
        ),
      if (untagged.isNotEmpty)
        _NextAction(
          label: untagged.length == 1
              ? '1 untagged recent note'
              : '${untagged.length} untagged recent notes',
          icon: Icons.sell_outlined,
          intent: UiIntent.info,
          onTap: () => _edit(untagged.first),
        ),
    ];
  }

  Widget _nextActionChips(BuildContext context) {
    final List<_NextAction> actions = _nextActions;
    if (actions.isEmpty) return const SizedBox.shrink();
    final UiTheme theme = context.ui;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: context.sp(theme.spacing.xs)),
            UiButton(
              label: actions[i].label,
              leadingIcon: actions[i].icon,
              variant: UiVariant.soft,
              intent: actions[i].intent,
              size: UiSize.xs,
              onPressed: actions[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sourceWriting case final source?) {
      return NoteEditorScreen(
        key: ValueKey(
          'source_writing_${source.source.kind.name}_${source.source.id}',
        ),
        note: source.note,
        sourceDocument: source,
        onClose: _closeSourceWriting,
      );
    }
    if (_openingWriting) {
      return const UiSkeleton(width: double.infinity, height: 240);
    }

    // The editor is a full-surface step on every width: it owns its own
    // save-or-discard decision and must not share the workbench's pane.
    if (_view == _NotesView.editor) return _notesBody(context);

    // Reading and editing are focused full-page steps at every width. Linked
    // records remain inside the reader; no permanent index/sidebar competes
    // with the writing surface.
    return _notesBody(context);
  }

  Widget _notesBody(BuildContext context) {
    final AppNote? active = _active;

    // Keyed so switching surfaces builds fresh controllers instead of trying to
    // re-seed the editor's text fields from a different note.
    final Widget page = switch (_view) {
      _NotesView.list => _list(context),
      _NotesView.preview when active != null => NotePreviewScreen(
        key: ValueKey<String>('note_preview_${active.id}'),
        note: _freshest(active),
        onClose: _backToList,
        onEdit: () => _edit(_freshest(active)),
        onOpenLink: _openRef,
        onAttachToPost: widget.onAttachToPost,
        canEdit: _collection == _NotesCollection.mine,
      ),
      _NotesView.editor when active != null => NoteEditorScreen(
        key: ValueKey<String>('note_editor_${active.id}'),
        note: active,
        initialMode: _editorMode,
        onClose: _closeEditor,
        onDeleted: _backToList,
      ),
      // Defensive: an active-note view with nothing active can only happen if a
      // delete raced the switch, and the list is always a valid answer.
      _ => _list(context),
    };

    return page;
  }

  /// The stream's copy of a note, so the preview never shows a stale body after
  /// an edit made somewhere else.
  AppNote _freshest(AppNote note) => <AppNote>[
    ..._notes,
    ..._publicNotes,
  ].firstWhere((AppNote n) => n.id == note.id, orElse: () => note);

  Widget _list(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppNote> visible = _visible;
    final List<AppNote> visibleBatch = _visibleBatch;

    final double gutter = context.sp(theme.spacing.md);
    final double dockSafeBottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      key: const ValueKey<String>('notes_list'),
      children: <Widget>[
        Scrollbar(
          controller: _notesScrollController,
          interactive: true,
          child: UiPage(
            maxWidth: 1440,
            scrollable: false,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: CustomScrollView(
                controller: _notesScrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: <Widget>[
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _NotesStickyHeaderDelegate(
                      extent: context.sz(
                        AppWritingDeskScope.isHosted(context) ? 64 : 104,
                      ),
                      background: theme.colors.background,
                      child: _stickyControls(context),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        if (_nextActions.isNotEmpty) ...<Widget>[
                          _nextActionChips(context),
                          SizedBox(height: context.sp(theme.spacing.sm)),
                        ],
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _collection == _NotesCollection.mine
                                    ? 'Your notes'
                                    : 'Public notes',
                                style: context.uiText.subheading,
                              ),
                            ),
                            UiBadge(
                              label: visibleBatch.length == visible.length
                                  ? '${visible.length} shown'
                                  : '${visibleBatch.length} of ${visible.length}',
                              icon: Icons.notes_rounded,
                              variant: UiBadgeVariant.outline,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                      ],
                    ),
                  ),
                  AppNoteLazyGridSliver(
                    notes: visibleBatch,
                    loading: _loading,
                    hasAnyNotes:
                        (_collection == _NotesCollection.mine
                                ? _notes
                                : _publicNotes)
                            .isNotEmpty,
                    density: _density,
                    highlight: _query,
                    onOpen: _open,
                    onDelete: _collection == _NotesCollection.mine
                        ? _delete
                        : null,
                    onNew: _collection == _NotesCollection.mine
                        ? _newNote
                        : null,
                    onClearFilters: _filtered ? _clearFilters : null,
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: context.sz(96))),
                ],
              ),
            ),
          ),
        ),
        if (!context.uiRes.isDesktop && !AppWritingDeskScope.isHosted(context))
          Positioned(
            right: gutter,
            bottom: dockSafeBottom + gutter,
            child: UiIconButton(
              key: const ValueKey<String>('new_note_fab'),
              icon: Icons.add_rounded,
              onPressed: _newNote,
              variant: UiVariant.primary,
              size: UiSize.lg,
              tooltip: 'New note',
            ),
          ),
      ],
    );
  }

  Widget _stickyControls(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiTabs(
          stretch: context.uiRes.isMobile,
          items: const <UiTabItem>[
            UiTabItem(label: 'My notes', icon: Icons.note_outlined),
            UiTabItem(label: 'Public notes', icon: Icons.public_rounded),
          ],
          selectedIndex: _collection == _NotesCollection.mine ? 0 : 1,
          onChanged: (int index) => _updateFilter(() {
            _collection = index == 0
                ? _NotesCollection.mine
                : _NotesCollection.public;
          }),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),
        _noteFilterBlock(
          showSearch: !AppWritingDeskScope.isHosted(context),
          showFilterControl: !AppWritingDeskScope.isHosted(context),
        ),
      ],
    );
  }
}

class _NotesStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NotesStickyHeaderDelegate({
    required this.extent,
    required this.background,
    required this.child,
  });

  final double extent;
  final Color background;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: background, child: child);

  @override
  bool shouldRebuild(_NotesStickyHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent ||
      background != oldDelegate.background ||
      child != oldDelegate.child;
}

/// One pipeline nudge in the "next best action" chip row. Private data, computed
/// by [_NotesScreenState._nextActions] from the live repository stream and link
/// graph — nothing here is hardcoded.
class _NextAction {
  const _NextAction({
    required this.label,
    required this.icon,
    required this.intent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final UiIntent intent;
  final VoidCallback onTap;
}
