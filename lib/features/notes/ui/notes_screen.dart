import 'package:tradex/core/widgets/record_unavailable.dart';
import 'package:tradex/core/config/customer_limitations.dart';
import 'package:tradex/core/config/record_access.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
/// Fully responsive writing desk notebook matching alphajournal design standards.
/// Uses pre-built alphajournal components, dynamic real-time data from repositories,
/// interactive category tabs, ticker and playbook filters, and spotlight guide keys.
class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    this.onSubpageChanged,
    this.onReturnToOrigin,
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

  final VoidCallback? onReturnToOrigin;

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  /// The saved record currently displayed, for browser history and sharing.
  AppLinkRef? get openedRef {
    final record = _active;
    if (_view == _NotesView.list || record == null || record.id.isEmpty) {
      return null;
    }
    return AppLinkRef(
      kind: AppLinkKind.note,
      id: record.id,
      title: record.title,
      isPublicContext:
          _isPublicContext || _collection == _NotesCollection.public,
    );
  }

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

  // Spotlight Guide Keys
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _bannerKey = GlobalKey();
  final GlobalKey _filterBarKey = GlobalKey();
  final GlobalKey _tabsKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();

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
  String? _ticker;
  String? _strategyId;
  bool _onlyWithJournal = false;
  bool _isGridView = true;

  AppNoteSort _sort = AppNoteSort.recentlyUpdated;
  AppNoteDensity _density = AppNoteDensity.comfortable;
  int _currentPage = 1;
  bool _dismissedBanner = false;
  _NotesCollection _collection = _NotesCollection.mine;

  _NotesView _view = _NotesView.list;
  AppNote? _active;
  AppLinkOpenRequest? _appliedRequest;
  bool _isPublicContext = false;
  RecordWritingDocument? _sourceWriting;
  bool _openingWriting = false;
  String? _accessError;
  int _accessRevision = 0;

  NoteEditorMode _editorMode = NoteEditorMode.write;
  bool _editorDetailsOnly = false;

  bool _revalidatingPublicRecord = false;

  /// True while a deep-linked record is being fetched, so the list/dashboard
  /// is never flashed before the record opens.
  bool _resolvingRequest = false;

  Future<void> _revalidatePublicRecord(String id) async {
    if (_revalidatingPublicRecord) return;
    _revalidatingPublicRecord = true;
    try {
      final record = await _repo.getById(id);
      if (!mounted || !_isPublicContext || _active?.id != id) return;
      setState(() {
        if (record == null || !record.isPublic) {
          _accessError = 'This record is private, deleted, or unavailable.';
        } else {
          _active = record;
          _accessError = null;
        }
      });
    } catch (_) {
      if (mounted && _isPublicContext) {
        setState(
          () => _accessError =
              'Could not verify this record. Please reopen it to retry.',
        );
      }
    } finally {
      _revalidatingPublicRecord = false;
    }
  }

  @override
  void initState() {
    super.initState();
    final AppLinkOpenRequest? initialRequest = widget.openRequest;
    _resolvingRequest =
        initialRequest != null &&
        initialRequest.id.isNotEmpty &&
        initialRequest.id.isNotEmpty;
    _sub = _repo.watchAll().listen(
      (List<AppNote> notes) {
        if (!mounted) return;
        setState(() {
          if (_active != null && _view == _NotesView.preview) {
            final latest = notes
                .where((note) => note.id == _active!.id)
                .firstOrNull;
            if (latest != null) _active = latest;
            if (_isPublicContext && latest != null && !latest.isPublic) {
              _accessError = 'This note is no longer public.';
            }
          }
          _notes = notes
              .where((note) => RecordAccess.owns(note.userId))
              .toList();
          _loading = false;
        });
        if (_isPublicContext && _active != null) {
          unawaited(_revalidatePublicRecord(_active!.id));
        }
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply(request));
    }
  }

  @override
  void didUpdateWidget(NotesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final AppLinkOpenRequest? request = widget.openRequest;
    if (request != null && request != oldWidget.openRequest) {
      if (request.id.isNotEmpty) _resolvingRequest = true;
      _apply(request);
    }
  }

  Future<void> _apply(AppLinkOpenRequest request) async {
    try {
      await _applyRequest(request);
    } finally {
      if (mounted && _resolvingRequest) {
        setState(() => _resolvingRequest = false);
      }
    }
  }

  Future<void> _applyRequest(AppLinkOpenRequest request) async {
    if (request == _appliedRequest) return;
    _isPublicContext = request.publicContext;
    if (request.editWriting && request.kind != AppLinkKind.note) {
      _appliedRequest = request;
      _openSourceWriting(
        AppLinkRef(
          kind: request.kind,
          id: request.id,
          title: request.id,
          isPublicContext: request.publicContext,
        ),
      );
      return;
    }
    if (request.kind == AppLinkKind.communityPost ||
        request.id.startsWith('post_') ||
        request.id.startsWith('pst_') ||
        request.id.startsWith('community')) {
      _appliedRequest = request;
      widget.onOpenRef?.call(
        AppLinkRef(
          kind: AppLinkKind.communityPost,
          id: request.id,
          title: request.id,
          isPublicContext: request.publicContext,
        ),
      );
      return;
    }
    if (request.kind == AppLinkKind.journal ||
        request.id.startsWith('trade_') ||
        request.id.startsWith('entry_') ||
        request.id.startsWith('trn_') ||
        request.id.startsWith('trd_') ||
        request.id.startsWith('journal_')) {
      _appliedRequest = request;
      widget.onOpenRef?.call(
        AppLinkRef(
          kind: AppLinkKind.journal,
          id: request.id,
          title: request.id,
          isPublicContext: request.publicContext,
        ),
      );
      return;
    }
    if (request.kind == AppLinkKind.strategy ||
        request.id.startsWith('strat_') ||
        request.id.startsWith('stg_') ||
        request.id.startsWith('strategy_')) {
      _appliedRequest = request;
      widget.onOpenRef?.call(
        AppLinkRef(
          kind: AppLinkKind.strategy,
          id: request.id,
          title: request.id,
          isPublicContext: request.publicContext,
        ),
      );
      return;
    }
    if (request.kind != AppLinkKind.note) return;
    _appliedRequest = request;
    if (request.id.isEmpty) {
      if (request.editWriting) {
        _newNote();
      }
      return;
    }
    final revision = ++_accessRevision;
    try {
      final note = await _repo.getById(request.id);
      if (!mounted || revision != _accessRevision) return;
      if (note == null ||
          !RecordAccess.canRead(
            note.userId,
            note.isPublic,
            publicContext: request.publicContext,
          )) {
        setState(
          () => _accessError = 'This note is private, deleted, or unavailable.',
        );
        return;
      }
      if (request.editWriting &&
          (request.publicContext || !RecordAccess.owns(note.userId))) {
        setState(
          () => _accessError =
              'Only the owner can edit this note in their workspace.',
        );
        return;
      }
      setState(() {
        _accessError = null;
        _isPublicContext =
            request.publicContext || !RecordAccess.owns(note.userId);
      });
      if (request.editWriting) {
        _edit(note);
      } else {
        setState(() {
          _active = note;
          _view = _NotesView.preview;
        });
        _notifySubpage();
      }
    } catch (error) {
      if (mounted && revision == _accessRevision) {
        setState(
          () => _accessError = 'Could not open this note. Please retry.',
        );
      }
    }
  }

  Future<void> _openSourceWriting(AppLinkRef ref) async {
    if (ref.isPublicContext) {
      setState(
        () => _accessError = 'Open the owner workspace to edit this record.',
      );
      return;
    }
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
    super.dispose();
  }

  List<AppNote> get _visible {
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;
    final List<AppNote> baseFiltered = NotesQuery.apply(
      pool,
      query: _query,
      type: _type,
      tag: _tag,
      sort: _sort,
    );

    return baseFiltered
        .where((AppNote n) {
          if (_ticker != null && !n.linkedTickers.contains(_ticker)) {
            return false;
          }
          if (_strategyId != null && n.strategyId != _strategyId) return false;
          if (_onlyWithJournal && n.linkedJournalIds.isEmpty) return false;
          return true;
        })
        .toList(growable: false);
  }

  int get _totalPages => (_visible.length / _pageSize).ceil().clamp(1, 999999);

  List<AppNote> get _visibleBatch {
    final int start = (_currentPage - 1) * _pageSize;
    if (start >= _visible.length) return const <AppNote>[];
    final int end = (start + _pageSize).clamp(0, _visible.length);
    return _visible.sublist(start, end);
  }

  void _updateFilter(VoidCallback update) => setState(() {
    update();
    _currentPage = 1;
  });

  bool get _filtered =>
      _query.trim().isNotEmpty ||
      _type != null ||
      _tag != null ||
      _ticker != null ||
      _strategyId != null ||
      _onlyWithJournal;

  void _clearFilters() => _updateFilter(() {
    _query = '';
    _type = null;
    _tag = null;
    _ticker = null;
    _strategyId = null;
    _onlyWithJournal = false;
  });

  List<String> get _availableTickers {
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;
    final Set<String> tickers = <String>{};
    for (final AppNote n in pool) {
      tickers.addAll(n.linkedTickers);
    }
    final List<String> sorted = tickers.toList()..sort();
    return sorted;
  }

  List<({String id, String name})> get _availableStrategies {
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;
    final Map<String, String> map = <String, String>{};
    for (final AppNote n in pool) {
      if (n.strategyId != null && n.strategyName != null) {
        map[n.strategyId!] = n.strategyName!;
      }
    }
    for (final AppStrategy s in _graph.strategyList) {
      map[s.id] = s.name;
    }
    return map.entries
        .map((MapEntry<String, String> e) => (id: e.key, name: e.value))
        .toList(growable: false);
  }

  String _strategyNameFor(String id) {
    for (final (id: recordId, :name) in _availableStrategies) {
      if (recordId == id) return name;
    }
    return id;
  }

  int _countForType(AppNoteType? type) {
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;
    if (type == null) return pool.length;
    return pool.where((AppNote n) => n.noteType == type).length;
  }

  AppNoteFilterBlock _noteFilterBlock({
    bool showSearch = true,
    bool showFilterControl = true,
    VoidCallback? onNew,
  }) => AppNoteFilterBlock(
    key: _filterBarKey,
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
    onDensityChanged: (AppNoteDensity density) =>
        _updateFilter(() => _density = density),
    onNew: onNew,
  );

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
    final bool canCreate = await CustomerLimitations.checkCanCreateNote(
      context,
      currentNoteCount: _notes.where((n) => RecordAccess.owns(n.userId)).length,
    );
    if (!canCreate || !mounted) return;
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
    _accessError = null;
    _isPublicContext =
        _collection == _NotesCollection.public ||
        !RecordAccess.owns(note.userId);
    if (!RecordAccess.canRead(
      note.userId,
      note.isPublic,
      publicContext: _isPublicContext,
    )) {
      setState(() => _accessError = 'This note is no longer public.');
      return;
    }
    setState(() {
      _active = note;
      _view = _NotesView.preview;
    });
    _notifySubpage();
  }

  void _edit(
    AppNote note, {
    NoteEditorMode mode = NoteEditorMode.write,
    bool detailsOnly = false,
  }) {
    if (note.id.isNotEmpty && !RecordAccess.owns(note.userId)) return;
    setState(() {
      _active = note;
      _editorMode = mode;
      _editorDetailsOnly = detailsOnly;
      _view = _NotesView.editor;
    });
    _notifySubpage();
  }

  void _closeEditor(AppNote? saved) {
    setState(() {
      _active = saved;
      _view = saved == null ? _NotesView.list : _NotesView.preview;
    });
    _notifySubpage();
  }

  void _backToList() {
    _accessError = null;
    _isPublicContext = false;
    _accessRevision++;
    if (widget.onReturnToOrigin != null) {
      widget.onReturnToOrigin!();
      return;
    }
    setState(() {
      _active = null;
      _view = _NotesView.list;
    });
    _notifySubpage();
  }

  void _openRef(AppLinkRef ref) {
    if (ref.missing) {
      UiToast.info(
        context,
        title: 'That record is gone',
        message: 'The link is kept so you can see it broke.',
      );
      return;
    }
    if (ref.id == 'ai_copilot' || ref.kind == AppLinkKind.aiCopilot) {
      widget.onOpenRef?.call(ref);
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
    final bool isPublic =
        ref.isPublicContext ||
        _isPublicContext ||
        _collection == _NotesCollection.public;
    final AppLinkRef targetRef = isPublic
        ? ref.copyWith(isPublicContext: true)
        : ref;
    final void Function(AppLinkRef ref)? jump = widget.onOpenRef;
    if (jump == null) {
      UiToast.info(
        context,
        title: ref.title,
        message: '${ref.kind.label} — not available from here.',
      );
      return;
    }
    jump(targetRef);
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

  void _showGuide() {
    FeatureGuideSpotlight.show(
      context,
      feature: FeatureId.notes,
      steps: FeatureGuideSteps.notes,
      targets: <GlobalKey>[
        _fabKey,
        _bannerKey,
        _filterBarKey,
        _tabsKey,
        _gridKey,
      ],
      onStepAction: _onGuideStepAction,
    );
  }

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

  void _reviewWeekly() {
    _backToList();
    _updateFilter(() {
      _collection = _NotesCollection.mine;
      _type = AppNoteType.review;
      _tag = null;
    });
  }

  AppNote? _firstNoteWhere(bool Function(AppNote n) test) {
    for (final AppNote n in _notes) {
      if (test(n)) return n;
    }
    return null;
  }

  // ── SubNavbar & Tabs ───────────────────────────────────────────────────────

  Widget _buildCollectionToggle() => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: context.sz(320)),
    child: UiTabs(
      items: [
        UiTabItem(
          label: 'My Notes',
          icon: Icons.folder_outlined,
          count: _notes.length,
        ),
        UiTabItem(
          label: 'Public Notes',
          icon: Icons.public_rounded,
          count: _publicNotes.length,
        ),
      ],
      selectedIndex: _collection == _NotesCollection.mine ? 0 : 1,
      onChanged: (index) => _updateFilter(
        () => _collection = index == 0
            ? _NotesCollection.mine
            : _NotesCollection.public,
      ),
      variant: UiTabsVariant.segmented,
      size: UiSize.sm,
      scrollable: true,
      showPanel: false,
    ),
  );

  Widget _buildCategorySegmentButton({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    return InkWell(
      borderRadius: context.radius(theme.radii.sm),
      onTap: onTap,
      child: Container(
        height: context.sz(28),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: isSelected ? colors.foreground : Colors.transparent,
          borderRadius: context.radius(theme.radii.sm),
        ),
        child: Text(
          '$label ($count)',
          style: context.uiText.caption.copyWith(
            color: isSelected ? colors.background : colors.foregroundMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // ── Notification Banner & Executive KPIs ───────────────────────────────────

  Widget _notificationBanner(BuildContext context) {
    if (_dismissedBanner) return const SizedBox.shrink();
    final List<AppTrade> unreviewed = _graph.journalList
        .where((AppTrade t) => _graph.bundleForJournal(t).notes.isEmpty)
        .toList(growable: false);
    final List<AppNote> unlinked = _notes
        .where(
          (AppNote n) =>
              _graph.bundleForNote(n).strategies.isEmpty &&
              _graph.bundleForNote(n).journal.isEmpty,
        )
        .toList(growable: false);

    final List<DeskNotificationAction> actions = <DeskNotificationAction>[
      if (unreviewed.isNotEmpty)
        DeskNotificationAction(
          label: unreviewed.length == 1
              ? '1 trade still without a review note'
              : '${unreviewed.length} trades still without a review note',
          icon: Icons.edit_note_rounded,
          intent: UiIntent.warning,
          badge: 'Audit',
          onTap: () => _openSourceWriting(_graph.journalRef(unreviewed.first)),
        ),
      if (unlinked.isNotEmpty)
        DeskNotificationAction(
          label: unlinked.length == 1
              ? '1 note not linked to any trade or playbook'
              : '${unlinked.length} notes not linked to any trade or playbook',
          icon: Icons.link_off_rounded,
          intent: UiIntent.info,
          badge: 'Unlinked',
          onTap: () => _edit(unlinked.first),
        ),
    ];

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      key: _bannerKey,
      child: DeskNotificationBanner(
        actions: actions,
        onDismiss: () => setState(() => _dismissedBanner = true),
      ),
    );
  }

  Widget _executiveKpis(BuildContext context, {required double maxWidth}) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;

    final List<AppTrade> unreviewed = _graph.journalList
        .where((AppTrade t) => _graph.bundleForJournal(t).notes.isEmpty)
        .toList(growable: false);
    final int totalTrades = _graph.journalList.length;
    final int completionRate = totalTrades > 0
        ? (((totalTrades - unreviewed.length) / totalTrades) * 100).round()
        : 100;

    final int plansCount = _countForType(AppNoteType.plan);
    final int reviewsCount = _countForType(AppNoteType.review);

    final DateTime now = DateTime.now();
    final int thisMonthCount = _notes
        .where(
          (AppNote n) =>
              n.updatedAt.year == now.year && n.updatedAt.month == now.month,
        )
        .length;

    final int linkedCount = pool
        .where(
          (AppNote n) => n.linkedJournalIds.isNotEmpty || n.strategyId != null,
        )
        .length;

    final List<DeskStatCardData> stats = <DeskStatCardData>[
      DeskStatCardData(
        title: 'NOTEBOOK INVENTORY',
        value: '${pool.length} Notes',
        valueColor: colors.foreground,
        secondary: _collection == _NotesCollection.mine ? 'Personal' : 'Public',
        secondaryColor: colors.foregroundMuted,
        subtitle:
            '${_notes.length} Personal · ${_publicNotes.length} Public notes',
      ),
      DeskStatCardData(
        title: 'TRADE PREP & PLANS',
        value: '$plansCount Plans',
        valueColor: colors.success,
        secondary: 'Execution',
        secondaryColor: colors.success,
        subtitle: 'Pre-market theses & trade plans',
      ),
      DeskStatCardData(
        title: 'POST-TRADE REVIEWS',
        value: '$completionRate%',
        valueColor: completionRate >= 80 ? colors.success : colors.warning,
        secondary: '$reviewsCount Written',
        secondaryColor: colors.foregroundMuted,
        subtitle: unreviewed.isNotEmpty
            ? '${unreviewed.length} trades missing audit note'
            : 'All trades documented in graph',
      ),
      DeskStatCardData(
        title: 'MONTHLY VELOCITY',
        value: '$thisMonthCount Notes',
        valueColor: colors.foreground,
        secondary: '$linkedCount Linked',
        secondaryColor: colors.info,
        subtitle: 'Updated this month across setups',
      ),
    ];

    return DeskStatsOverview(stats: stats, maxWidth: maxWidth);
  }

  // ── SubNavbar & Tabs ───────────────────────────────────────────────────────

  Widget _buildSubNavbar(BuildContext context, {required double maxWidth}) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;

    final Widget categories = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        height: context.sz(32),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildCategorySegmentButton(
              label: 'All Notes',
              count: pool.length,
              isSelected: _type == null,
              onTap: () => _updateFilter(() => _type = null),
            ),
            _buildCategorySegmentButton(
              label: 'Trade Plans',
              count: _countForType(AppNoteType.plan),
              isSelected: _type == AppNoteType.plan,
              onTap: () => _updateFilter(() => _type = AppNoteType.plan),
            ),
            _buildCategorySegmentButton(
              label: 'Reviews',
              count: _countForType(AppNoteType.review),
              isSelected: _type == AppNoteType.review,
              onTap: () => _updateFilter(() => _type = AppNoteType.review),
            ),
            _buildCategorySegmentButton(
              label: 'Analysis',
              count: _countForType(AppNoteType.analysis),
              isSelected: _type == AppNoteType.analysis,
              onTap: () => _updateFilter(() => _type = AppNoteType.analysis),
            ),
            _buildCategorySegmentButton(
              label: 'Ideas',
              count: _countForType(AppNoteType.idea),
              isSelected: _type == AppNoteType.idea,
              onTap: () => _updateFilter(() => _type = AppNoteType.idea),
            ),
            _buildCategorySegmentButton(
              label: 'Cheat Sheets',
              count: _countForType(AppNoteType.cheatSheet),
              isSelected: _type == AppNoteType.cheatSheet,
              onTap: () => _updateFilter(() => _type = AppNoteType.cheatSheet),
            ),
          ],
        ),
      ),
    );

    final bool isDesktop = maxWidth >= 900;

    return Container(
      key: _tabsKey,
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(child: categories),
                SizedBox(width: context.sp(theme.spacing.md)),
                _buildCollectionToggle(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildCollectionToggle(),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                categories,
              ],
            ),
    );
  }
  // ── Filter Toolbar ─────────────────────────────────────────────────────────

  Widget _buildFilterBar(
    BuildContext context, {
    required double maxWidth,
    required List<AppNote> visible,
    required List<AppNote> visibleBatch,
    required int poolCount,
  }) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    final Widget tickerDropdown = DeskFilterDropdown(
      label: _ticker == null ? 'Ticker: All' : 'Ticker: $_ticker',
      icon: Icons.candlestick_chart_outlined,
      isActive: _ticker != null,
      items: <UiMenuItem>[
        UiMenuItem(
          label: 'Ticker: All',
          icon: Icons.candlestick_chart_outlined,
          onPressed: () => _updateFilter(() => _ticker = null),
        ),
        for (final String t in _availableTickers)
          UiMenuItem(
            label: t,
            icon: Icons.show_chart_rounded,
            onPressed: () => _updateFilter(() => _ticker = t),
          ),
      ],
    );

    final Widget playbookDropdown = DeskFilterDropdown(
      label: _strategyId == null
          ? 'Playbook: Any'
          : 'Playbook: ${_strategyNameFor(_strategyId!)}',
      icon: Icons.auto_stories_outlined,
      isActive: _strategyId != null,
      items: <UiMenuItem>[
        UiMenuItem(
          label: 'Playbook: Any',
          icon: Icons.auto_stories_outlined,
          onPressed: () => _updateFilter(() => _strategyId = null),
        ),
        for (final item in _availableStrategies)
          UiMenuItem(
            label: item.name,
            icon: Icons.book_outlined,
            onPressed: () => _updateFilter(() => _strategyId = item.id),
          ),
      ],
    );

    final Widget journalLinkToggle = InkWell(
      borderRadius: context.radius(theme.radii.md),
      onTap: () => _updateFilter(() => _onlyWithJournal = !_onlyWithJournal),
      child: Container(
        height: context.sz(32),
        padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: _onlyWithJournal
              ? colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: _onlyWithJournal ? colors.primary : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _onlyWithJournal ? Icons.check_rounded : Icons.link_rounded,
              size: 13,
              color: _onlyWithJournal ? colors.primary : colors.foregroundMuted,
            ),
            const SizedBox(width: 4),
            Text(
              'With Journal Link',
              style: context.uiText.caption.copyWith(
                color: _onlyWithJournal
                    ? colors.foreground
                    : colors.foregroundMuted,
                fontWeight: _onlyWithJournal
                    ? FontWeight.bold
                    : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );

    final Widget quickTickers = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final String t in _availableTickers.take(3)) ...<Widget>[
          const SizedBox(width: 4),
          InkWell(
            borderRadius: context.radius(theme.radii.sm),
            onTap: () => _updateFilter(() {
              _ticker = _ticker == t ? null : t;
            }),
            child: Container(
              height: context.sz(32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _ticker == t ? colors.foreground : Colors.transparent,
                borderRadius: context.radius(theme.radii.sm),
                border: Border.all(
                  color: _ticker == t
                      ? colors.foreground
                      : colors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                t,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _ticker == t
                      ? colors.background
                      : colors.foregroundSubtle,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final Widget countBadge = UiBadge(
      label: '${visible.length} of $poolCount',
      icon: Icons.layers_rounded,
      variant: UiBadgeVariant.outline,
      size: UiSize.xs,
    );

    final Widget sortDropdown = DeskFilterDropdown(
      label: 'Sort: ${_sort.label.split(' ').first}',
      icon: Icons.sort_rounded,
      isActive: false,
      items: <UiMenuItem>[
        for (final AppNoteSort s in AppNoteSort.values)
          UiMenuItem(
            label: s.label,
            icon: Icons.sort_rounded,
            onPressed: () => _updateFilter(() => _sort = s),
          ),
      ],
    );

    final Widget viewToggle = DeskViewToggle(
      isGrid: _isGridView,
      onChanged: (bool grid) => setState(() => _isGridView = grid),
      gridTooltip: 'Grid view (G)',
      secondaryTooltip: 'List view (G)',
    );

    final bool isDesktop = maxWidth >= 1024;

    return Container(
      key: _filterBarKey,
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        tickerDropdown,
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        playbookDropdown,
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        journalLinkToggle,
                        if (_availableTickers.isNotEmpty) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          quickTickers,
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    countBadge,
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    sortDropdown,
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    viewToggle,
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: context.sp(theme.spacing.xs),
                  children: <Widget>[
                    countBadge,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        sortDropdown,
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        viewToggle,
                      ],
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      tickerDropdown,
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      playbookDropdown,
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      journalLinkToggle,
                      if (_availableTickers.isNotEmpty) ...<Widget>[
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        quickTickers,
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ── Section Title ──────────────────────────────────────────────────────────

  Widget _buildSectionTitle(BuildContext context, {required double maxWidth}) {
    final String title = _collection == _NotesCollection.mine
        ? 'Your Notes'
        : 'Public Notes';
    final List<AppNote> pool = _collection == _NotesCollection.mine
        ? _notes
        : _publicNotes;

    return DeskSectionHeader(
      title: title,
      countLabel: '${_visible.length} of ${pool.length}',
      showDivider: true,
      accentColor: context.uiColors.primary,
    );
  }

  // ── Main Content Grid/List ─────────────────────────────────────────────────

  Widget _buildNotesContent(
    BuildContext context, {
    required double maxWidth,
    required int columns,
    required List<AppNote> visibleBatch,
    required List<AppNote> visible,
    required int poolCount,
  }) {
    final UiTheme theme = context.ui;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xl)),
        child: const Center(
          child: UiSkeleton(width: double.infinity, height: 200),
        ),
      );
    }

    if (visibleBatch.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xl)),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.sz(460)),
            child: poolCount > 0
                ? UiEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No notes match',
                    message:
                        'Nothing here matches the current search and filters.',
                    actionLabel: 'Clear filters',
                    onActionPressed: _filtered ? _clearFilters : null,
                  )
                : UiEmptyState(
                    icon: Icons.edit_note_rounded,
                    title: 'Your notebook is empty',
                    message:
                        'Capture the plan before a trade and the lesson after it.',
                    actionLabel: 'Write your first note',
                    onActionPressed: _newNote,
                  ),
          ),
        ),
      );
    }

    final double gap = context.sp(theme.spacing.md);

    if (!_isGridView) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AppNote note in visibleBatch)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: AppNoteCard(
                key: ValueKey<String>(note.id),
                note: note,
                density: _density,
                highlight: _query,
                selected: note.id == _active?.id,
                onTap: () => _open(note),
                onDelete: _collection == _NotesCollection.mine
                    ? () => _delete(note)
                    : null,
              ),
            ),
        ],
      );
    }

    return _buildNoteCardGrid(
      context,
      visibleBatch,
      columns: columns,
      gap: gap,
    );
  }

  Widget _buildNoteCardGrid(
    BuildContext context,
    List<AppNote> items, {
    required int columns,
    required double gap,
  }) {
    if (columns == 1) {
      return Column(
        children: <Widget>[
          for (final AppNote note in items)
            Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: AppNoteCard(
                key: ValueKey<String>(note.id),
                note: note,
                density: _density,
                highlight: _query,
                selected: note.id == _active?.id,
                onTap: () => _open(note),
                onDelete: _collection == _NotesCollection.mine
                    ? () => _delete(note)
                    : null,
              ),
            ),
        ],
      );
    }

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < items.length; i += columns) {
      final List<AppNote> rowItems = items.sublist(
        i,
        (i + columns).clamp(0, items.length),
      );
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int j = 0; j < columns; j++) ...<Widget>[
                  if (j > 0) SizedBox(width: gap),
                  Expanded(
                    child: j < rowItems.length
                        ? AppNoteCard(
                            key: ValueKey<String>(rowItems[j].id),
                            note: rowItems[j],
                            density: _density,
                            highlight: _query,
                            selected: rowItems[j].id == _active?.id,
                            onTap: () => _open(rowItems[j]),
                            onDelete: _collection == _NotesCollection.mine
                                ? () => _delete(rowItems[j])
                                : null,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ── Footer Status Bar ──────────────────────────────────────────────────────

  Widget _buildFooterStatusBar(
    BuildContext context, {
    required double maxWidth,
  }) {
    return const DeskStatusBarFooter(
      syncLabel: 'Notes, journal and strategies share linked records',
      shortcutHints: <String>[
        'Press N for New note',
        '/ for Search',
        'Esc to Clear',
        'G switch view',
      ],
    );
  }

  // ── Body & List Surfaces ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_resolvingRequest && _accessError == null && _view == _NotesView.list) {
      return RecordOpeningBanner(
        title: 'Opening note...',
        subtitle: 'Fetching research note and linked records',
        badgeLabel: 'Note',
        icon: Icons.note_alt_outlined,
        onBack: widget.onReturnToOrigin ?? _backToList,
      );
    }
    if (_accessError != null) {
      return RecordUnavailable(
        title: 'Note unavailable',
        message: _accessError!,
        onBack: _backToList,
      );
    }
    if (_sourceWriting case final source?) {
      return NoteEditorScreen(
        key: ValueKey<String>(
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

    if (_view == _NotesView.editor) return _notesBody(context);

    return _notesBody(context);
  }

  Widget _notesBody(BuildContext context) {
    final AppNote? active = _active;

    final Widget page = switch (_view) {
      _NotesView.list => _list(context),
      _NotesView.preview when active != null => NotePreviewScreen(
        key: ValueKey<String>('note_preview_${active.id}'),
        note: _freshest(active),
        onClose: _backToList,
        onEdit: () => _edit(_freshest(active), detailsOnly: true),
        onEditWriting: () {
          if (widget.onOpenWriting != null) {
            widget.onOpenWriting!(
              AppLinkRef(
                kind: AppLinkKind.note,
                id: active.id,
                title: active.title,
              ),
            );
          } else {
            _edit(_freshest(active), detailsOnly: false);
          }
        },
        onOpenLink: _openRef,
        onAttachToPost: widget.onAttachToPost,
        canEdit: !_isPublicContext && RecordAccess.owns(active.userId),
        isPublicContext:
            _isPublicContext || _collection == _NotesCollection.public,
      ),
      _NotesView.editor when active != null => NoteEditorScreen(
        key: ValueKey<String>('note_editor_${active.id}'),
        note: active,
        initialMode: _editorMode,
        detailsOnly: _editorDetailsOnly,
        onClose: _closeEditor,
        onDeleted: _backToList,
      ),
      _ => _list(context),
    };

    return page;
  }

  AppNote _freshest(AppNote note) => <AppNote>[
    ..._notes,
    ..._publicNotes,
  ].firstWhere((AppNote n) => n.id == note.id, orElse: () => note);

  Widget _list(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<AppNote> visible = _visible;
    final List<AppNote> visibleBatch = _visibleBatch;
    final int poolCount =
        (_collection == _NotesCollection.mine ? _notes : _publicNotes).length;
    final double gutter = context.sp(theme.spacing.md);
    final double dockSafeBottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      key: const ValueKey<String>('notes_list'),
      children: <Widget>[
        UiPage(
          scrollable: true,
          maxWidth: double.infinity,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyN): _newNote,
              const SingleActivator(LogicalKeyboardKey.escape): _clearFilters,
              const SingleActivator(LogicalKeyboardKey.keyG): () =>
                  setState(() => _isGridView = !_isGridView),
            },
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double maxWidth = constraints.maxWidth;
                  final int columns = maxWidth >= 1024
                      ? 3
                      : (maxWidth >= 640 ? 2 : 1);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: context.sp(theme.spacing.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // 1. Notification Banner
                        _notificationBanner(context),
                        SizedBox(height: context.sp(theme.spacing.sm)),

                        // 2. 4-Card Executive KPI Overview
                        _executiveKpis(context, maxWidth: maxWidth),
                        SizedBox(height: context.sp(theme.spacing.md)),

                        // 3. SubNavbar with collection toggle & note types
                        _buildSubNavbar(context, maxWidth: maxWidth),
                        SizedBox(height: context.sp(theme.spacing.xs)),

                        // 4. Filter & View Toolbar
                        _buildFilterBar(
                          context,
                          maxWidth: maxWidth,
                          visible: visible,
                          visibleBatch: visibleBatch,
                          poolCount: poolCount,
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),

                        // 5. Section Title Area
                        _buildSectionTitle(context, maxWidth: maxWidth),
                        SizedBox(height: context.sp(theme.spacing.sm)),

                        // 6. Main Content Notes Grid/List
                        Container(
                          key: _gridKey,
                          child: _buildNotesContent(
                            context,
                            maxWidth: maxWidth,
                            columns: columns,
                            visibleBatch: visibleBatch,
                            visible: visible,
                            poolCount: poolCount,
                          ),
                        ),

                        // 7. Lazy-Loaded Pagination Bar
                        if (visible.isNotEmpty) ...<Widget>[
                          SizedBox(height: context.sp(theme.spacing.md)),
                          DeskPaginationBar(
                            currentPage: _currentPage,
                            totalPages: _totalPages,
                            totalItems: visible.length,
                            pageSize: _pageSize,
                            itemLabel: 'notes',
                            onPageChanged: (int page) =>
                                setState(() => _currentPage = page),
                          ),
                        ],

                        SizedBox(height: context.sp(theme.spacing.xl)),

                        // 8. Footer status bar
                        _buildFooterStatusBar(context, maxWidth: maxWidth),

                        SizedBox(
                          height: context.uiPageBottomInset + context.sz(72),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Floating Action Button on Bottom Right across all screen sizes
        Positioned(
          right: gutter,
          bottom: dockSafeBottom + gutter,
          child: UiIconButton(
            key: _fabKey,
            icon: Icons.add_rounded,
            variant: UiVariant.primary,
            size: UiSize.lg,
            tooltip: 'New note',
            onPressed: _newNote,
          ),
        ),
      ],
    );
  }
}
