import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/record_access.dart';
// Required unified UI surfaces for feature layouts.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/journal/ui/journal_entry_screen.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/ui/note_preview_screen.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:tradex/features/strategies/ui/strategy_detail_screen.dart';

/// Reads a shared Writing Desk record inside Community using the same detail
/// screen as its real Notes, Journal, or Strategies workspace.
class PublicRecordDetailModal extends StatefulWidget {
  const PublicRecordDetailModal({
    super.key,
    required this.ref,
    this.initialNote,
    this.initialTrade,
    this.initialStrategy,
    this.initialLinkGraph,
    this.onOpenEditor,
    this.onOpenRef,
    this.initiallySaved = false,
    this.onSaveChanged,
  });

  final AppLinkRef ref;
  final AppNote? initialNote;
  final AppTrade? initialTrade;
  final AppStrategy? initialStrategy;
  final AppLinkGraph? initialLinkGraph;

  /// Leaves Community and opens the owner's real Workspace editor.
  final VoidCallback? onOpenEditor;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final bool initiallySaved;
  final Future<void> Function(bool saved)? onSaveChanged;

  static Future<void> show(
    BuildContext context, {
    required AppLinkRef ref,
    AppNote? initialNote,
    AppTrade? initialTrade,
    AppStrategy? initialStrategy,
    AppLinkGraph? initialLinkGraph,
    VoidCallback? onOpenEditor,
    ValueChanged<AppLinkRef>? onOpenRef,
    bool initiallySaved = false,
    Future<void> Function(bool saved)? onSaveChanged,
  }) {
    return showSettingsSideSheet<void>(
      context,
      title: ref.title,
      showHeader: false,
      desktopWidthRatio: 0.82,
      minDesktopWidth: 760,
      maxWidth: 1280,
      child: PublicRecordDetailModal(
        ref: ref,
        initialNote: initialNote,
        initialTrade: initialTrade,
        initialStrategy: initialStrategy,
        initialLinkGraph: initialLinkGraph,
        onOpenEditor: onOpenEditor,
        onOpenRef: onOpenRef,
        initiallySaved: initiallySaved,
        onSaveChanged: onSaveChanged,
      ),
    );
  }

  @override
  State<PublicRecordDetailModal> createState() =>
      _PublicRecordDetailModalState();
}

class _PublicRecordDetailModalState extends State<PublicRecordDetailModal> {
  bool _isLoading = true;
  String? _errorMessage;
  AppNote? _note;
  AppTrade? _trade;
  AppStrategy? _strategy;
  AppLinkGraph? _publicGraph;
  late bool _isSaved = widget.initiallySaved;

  @override
  void initState() {
    super.initState();
    _setInitialRecord();
    _loadRecord();
  }

  @override
  void didUpdateWidget(PublicRecordDetailModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ref.kind == widget.ref.kind &&
        oldWidget.ref.id == widget.ref.id) {
      return;
    }
    _setInitialRecord();
    _loadRecord();
  }

  void _setInitialRecord() {
    _note = widget.initialNote;
    _trade = widget.initialTrade;
    _strategy = widget.initialStrategy;
    _publicGraph = widget.initialLinkGraph;
    _errorMessage = null;
    _isLoading = true;
  }

  Future<void> _loadRecord() async {
    try {
      switch (widget.ref.kind) {
        case AppLinkKind.note:
          _note ??= await NotesRepositoryScope.repository.getById(
            widget.ref.id,
          );
          if (!_canRead(_note?.userId, _note?.isPublic)) {
            _note = null;
            _errorMessage =
                'This research note is private or has been removed.';
          }
        case AppLinkKind.journal:
          _trade ??= await JournalRepositoryScope.repository.getById(
            widget.ref.id,
          );
          if (!_canRead(_trade?.userId, _trade?.isPublic)) {
            _trade = null;
            _errorMessage =
                'This journal entry is private or has been removed.';
          }
        case AppLinkKind.strategy:
          _strategy ??= await StrategiesRepositoryScope.repository.getById(
            widget.ref.id,
          );
          if (!_canRead(_strategy?.userId, _strategy?.isPublic)) {
            _strategy = null;
            _errorMessage = 'This strategy is private or has been removed.';
          }
        default:
          _errorMessage = 'This record type cannot be opened here.';
      }
      if (_errorMessage == null && _publicGraph == null) {
        await _loadPublicGraph();
      }
    } catch (error) {
      _errorMessage = 'This record could not be loaded. Please try again.';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  bool _canRead(String? ownerId, bool? isPublic) {
    if (ownerId == null || isPublic == null) return false;
    return RecordAccess.canRead(ownerId, isPublic, publicContext: true);
  }

  Future<void> _loadPublicGraph() async {
    try {
      final List<Object> records = await Future.wait<Object>(<Future<Object>>[
        NotesRepositoryScope.repository.fetchPublicNotes(),
        JournalRepositoryScope.repository.fetchPublicEntries(),
        StrategiesRepositoryScope.repository.fetchPublicStrategies(),
      ]);
      _publicGraph = _graphWithCurrentRecords(
        notes: records[0] as List<AppNote>,
        journal: records[1] as List<AppTrade>,
        strategies: records[2] as List<AppStrategy>,
      );
    } catch (_) {
      _publicGraph = _graphWithCurrentRecords();
    }
  }

  AppLinkGraph _graphWithCurrentRecords({
    List<AppNote> notes = const <AppNote>[],
    List<AppTrade> journal = const <AppTrade>[],
    List<AppStrategy> strategies = const <AppStrategy>[],
  }) {
    final Map<String, AppNote> notesById = <String, AppNote>{
      for (final AppNote note in notes) note.id: note,
    };
    final Map<String, AppTrade> journalById = <String, AppTrade>{
      for (final AppTrade entry in journal) entry.id: entry,
    };
    final Map<String, AppStrategy> strategiesById = <String, AppStrategy>{
      for (final AppStrategy strategy in strategies) strategy.id: strategy,
    };
    if (_note case final AppNote note) notesById[note.id] = note;
    if (_trade case final AppTrade entry) journalById[entry.id] = entry;
    if (_strategy case final AppStrategy strategy) {
      strategiesById[strategy.id] = strategy;
    }
    return AppLinkGraph(
      notes: notesById.values.toList(growable: false),
      journal: journalById.values.toList(growable: false),
      strategies: strategiesById.values.toList(growable: false),
    );
  }

  void _close() {
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _openEditor() {
    final VoidCallback? openEditor = widget.onOpenEditor;
    if (openEditor == null) return;
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => openEditor());
  }

  bool get _canOpenEditor {
    if (widget.onOpenEditor == null) return false;
    final String? ownerId = switch (widget.ref.kind) {
      AppLinkKind.note => _note?.userId,
      AppLinkKind.journal => _trade?.userId,
      AppLinkKind.strategy => _strategy?.userId,
      _ => null,
    };
    return ownerId != null && RecordAccess.owns(ownerId);
  }

  Future<void> _toggleSaved() async {
    final callback = widget.onSaveChanged;
    if (callback == null) return;
    final bool next = !_isSaved;
    setState(() => _isSaved = next);
    try {
      await callback(next);
      if (!mounted) return;
      UiToast.show(
        context,
        title: next ? 'Saved to bookmarks' : 'Removed from bookmarks',
        message: next
            ? 'This shared record is now available from your Community bookmarks.'
            : 'This shared record was removed from your Community bookmarks.',
        intent: next ? UiIntent.success : UiIntent.neutral,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaved = !next);
      UiToast.error(
        context,
        title: 'Bookmark was not saved',
        message: '$error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _PublicRecordLoadingView();
    if (_errorMessage case final String message) {
      return Center(
        child: UiEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Unavailable',
          message: message,
          action: UiButton(
            label: 'Back to Community',
            variant: UiVariant.outline,
            onPressed: _close,
          ),
        ),
      );
    }

    return switch (widget.ref.kind) {
      AppLinkKind.note => NotePreviewScreen(
        key: ValueKey<String>('community-note-${widget.ref.id}'),
        note: _note!,
        onClose: _close,
        onEdit: _openEditor,
        onEditWriting: _canOpenEditor ? _openEditor : null,
        onOpenLink: widget.onOpenRef,
        linkGraph: _publicGraph,
        canEdit: false,
        isPublicContext: true,
        savedOverride: _isSaved,
        onToggleSaved: widget.onSaveChanged == null ? null : _toggleSaved,
      ),
      AppLinkKind.journal => JournalEntryScreen(
        key: ValueKey<String>('community-journal-${widget.ref.id}'),
        entry: _trade!,
        onClose: _close,
        onEdit: _openEditor,
        onEditWriting: _canOpenEditor ? _openEditor : null,
        onOpenLink: widget.onOpenRef,
        linkGraph: _publicGraph,
        canEdit: false,
        isPublicContext: true,
        savedOverride: _isSaved,
        onToggleSaved: widget.onSaveChanged == null ? null : _toggleSaved,
      ),
      AppLinkKind.strategy => StrategyDetailScreen(
        key: ValueKey<String>('community-strategy-${widget.ref.id}'),
        strategy: _strategy!,
        onClose: _close,
        onEdit: _openEditor,
        onEditWriting: _canOpenEditor ? _openEditor : null,
        onOpenLink: widget.onOpenRef,
        linkGraph: _publicGraph,
        canEdit: false,
        isPublicContext: true,
        savedOverride: _isSaved,
        onToggleSaved: widget.onSaveChanged == null ? null : _toggleSaved,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PublicRecordLoadingView extends StatelessWidget {
  const _PublicRecordLoadingView();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Padding(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          UiSkeleton(width: 240, height: 32),
          SizedBox(height: 16),
          UiSkeleton(height: 72),
          SizedBox(height: 16),
          Expanded(child: UiSkeleton()),
        ],
      ),
    );
  }
}
