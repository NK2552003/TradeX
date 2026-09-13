import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/linking/record_link_picker.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/features/linking/link_graph_service.dart';
import 'package:tradex/features/notes/data/note_ai_refactor.dart';

import '../data/strategies_repository.dart';
import '../data/strategy_attachments.dart';
import 'revision_note_prompt.dart';

enum StrategyEditorMode {
  write,
  read,
  split;

  String get label => switch (this) {
    StrategyEditorMode.write => 'Write',
    StrategyEditorMode.read => 'Read',
    StrategyEditorMode.split => 'Split',
  };

  IconData get icon => switch (this) {
    StrategyEditorMode.write => Icons.edit_outlined,
    StrategyEditorMode.read => Icons.menu_book_outlined,
    StrategyEditorMode.split => Icons.vertical_split_rounded,
  };
}

/// The playbook authoring surface: the rules, and who they apply to.
///
/// Where the journal editor pairs prose with a trade's numbers, this one pairs
/// prose with a *contract* — status, reach, instruments, and the records the
/// playbook answers to. None of the performance figures are editable here, by
/// design: they are derived from the journal entries filed under the playbook,
/// and a hand-typed win rate is the one number a trader must never be allowed
/// to write.
///
/// Saving has two shapes, and the difference matters. A plain save updates the
/// live revision in place — thirty keystrokes are one edit, not thirty entries
/// in the history. "Save revision" cuts a new numbered revision with a changelog
/// line, which is what makes "what was I actually following in March" an
/// answerable question.
class StrategyEditorScreen extends StatefulWidget {
  const StrategyEditorScreen({
    super.key,
    required this.strategy,
    required this.onClose,
    this.onDeleted,
    this.detailsOnly = false,
    this.initialMode = StrategyEditorMode.write,
  });

  /// The playbook being edited. An empty [AppStrategy.id] is an unsaved draft,
  /// created on first save rather than up front, so opening the editor and
  /// backing out leaves nothing behind.
  final AppStrategy strategy;

  /// Back to wherever the editor was opened from, carrying the saved playbook so
  /// the caller shows the fresh copy instead of the draft it handed in. Null when
  /// nothing was written.
  final ValueChanged<AppStrategy?> onClose;

  /// Back to the library after the playbook was deleted. Falls back to
  /// [onClose].
  final VoidCallback? onDeleted;

  final StrategyEditorMode initialMode;

  /// Production record routes use focused forms; writing lives in Notes.
  final bool detailsOnly;

  @override
  State<StrategyEditorScreen> createState() => StrategyEditorScreenState();
}

class StrategyEditorScreenState extends State<StrategyEditorScreen> {
  // ── The document ───────────────────────────────────────────────────────────

  final TextEditingController _name = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _summary = TextEditingController();

  final GlobalKey<RichMarkdownEditorFieldState> _editorKey =
      GlobalKey<RichMarkdownEditorFieldState>();
  final FocusNode _bodyFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final MarkdownOutlineController _outline = MarkdownOutlineController();
  final SpeechToText _speech = SpeechToText();
  final ScrollController _editorScrollController = ScrollController();

  /// Bumped on every keystroke so the command bar, counters and derived hints
  /// rebuild without dragging the whole editor through `setState`.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// The parsed body, updated a few times a second rather than per character.
  final ValueNotifier<String> _preview = ValueNotifier<String>('');

  final ValueNotifier<String?> _slash = ValueNotifier<String?>(null);
  final ValueNotifier<TextSelection?> _selection =
      ValueNotifier<TextSelection?>(null);

  Timer? _previewDebounce;

  // ── The contract ───────────────────────────────────────────────────────────

  late AppStrategy _strategy;
  late StrategyEditorMode _mode;
  late AppStrategyStatus _status;
  late bool _isPublic;
  late List<String> _tags;
  late List<String> _tickers;
  late List<String> _linkedNoteIds;
  late List<String> _linkedJournalIds;
  String? _category;

  final AppLinkGraphService _links = AppLinkGraphScope.service;
  late AppLinkGraph _graph = _links.current;
  StreamSubscription<AppLinkGraph>? _graphSub;

  bool _saving = false;
  bool _listening = false;
  bool _refactoring = false;
  bool _detailsOpen = false;
  String _voiceBase = '';

  @override
  void initState() {
    super.initState();
    _strategy = widget.strategy;
    _mode = widget.initialMode;
    _name.text = _strategy.name;
    _body.text = _strategy.content;
    _preview.value = _strategy.content;
    _summary.text = _strategy.summary ?? '';
    _status = _strategy.status;
    _isPublic = _strategy.isPublic;
    _category = _strategy.category;
    _tags = List<String>.of(_strategy.tags);
    _tickers = List<String>.of(_strategy.linkedTickers);
    _linkedNoteIds = List<String>.of(_strategy.linkedNoteIds);
    _linkedJournalIds = List<String>.of(_strategy.linkedJournalIds);
    _detailsOpen = false;

    _body.addListener(_onBodyChanged);
    _name.addListener(_bumpRevision);
    _summary.addListener(_bumpRevision);
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    if (_listening) _speech.stop();
    _graphSub?.cancel();
    _body.removeListener(_onBodyChanged);
    _name.removeListener(_bumpRevision);
    _summary.removeListener(_bumpRevision);
    for (final TextEditingController c in <TextEditingController>[
      _name,
      _body,
      _summary,
    ]) {
      c.dispose();
    }
    _bodyFocus.dispose();
    _nameFocus.dispose();
    _outline.dispose();
    _revision.dispose();
    _preview.dispose();
    _slash.dispose();
    _selection.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  // ── Change tracking ────────────────────────────────────────────────────────

  void _bumpRevision() => _revision.value++;

  void _onBodyChanged() {
    _bumpRevision();
    final TextSelection selection = _body.selection;
    final TextSelection? tracked = selection.isValid && !selection.isCollapsed
        ? selection
        : null;
    if (tracked != _selection.value) _selection.value = tracked;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 260), () {
      if (mounted) _preview.value = _body.text;
    });
  }

  /// What would be written if the trader saved right now.
  ///
  /// Built by hand rather than through `copyWith` so clearing the summary or the
  /// category actually clears it — `copyWith` reads a null argument as "leave it
  /// alone", which is right everywhere else and wrong in an editor.
  ///
  /// Every derived number is carried across untouched. Trades, win rate, average
  /// R, net P/L and the equity curve belong to the journal entries filed under
  /// the playbook, and this screen has no business inventing them.
  AppStrategy get _draft {
    final String summary = _summary.text.trim();
    final String? category = (_category ?? '').trim().isEmpty
        ? null
        : _category!.trim();
    return AppStrategy(
      id: _strategy.id,
      name: _name.text.trim(),
      summary: summary.isEmpty ? null : summary,
      category: category,
      isPublic: _isPublic,
      isFavorite: _strategy.isFavorite,
      trades: _strategy.trades,
      winRate: _strategy.winRate,
      avgR: _strategy.avgR,
      netPnl: _strategy.netPnl,
      updatedAt: _strategy.updatedAt,
      versionCount: _strategy.versionCount,
      equityCurve: _strategy.equityCurve,
      userId: _strategy.userId,
      content: _body.text,
      status: _status,
      tags: List<String>.unmodifiable(_tags),
      linkedTickers: List<String>.unmodifiable(_tickers),
      linkedNoteIds: List<String>.unmodifiable(_linkedNoteIds),
      linkedJournalIds: List<String>.unmodifiable(_linkedJournalIds),
      createdAt: _strategy.createdAt,
    ).withDerivedCounts();
  }

  /// Whether anything the editor owns differs from what is stored. Drives the
  /// save button and the silent save on the way out.
  bool get _dirty {
    final AppStrategy draft = _draft;
    return draft.name != _strategy.name ||
        draft.summary != _strategy.summary ||
        draft.category != _strategy.category ||
        draft.content != _strategy.content ||
        draft.status != _strategy.status ||
        draft.isPublic != _strategy.isPublic ||
        !listEquals(draft.tags, _strategy.tags) ||
        !listEquals(draft.linkedTickers, _strategy.linkedTickers) ||
        !listEquals(draft.linkedNoteIds, _strategy.linkedNoteIds) ||
        !listEquals(draft.linkedJournalIds, _strategy.linkedJournalIds);
  }

  /// Nothing worth keeping. Backing out of an untouched draft leaves no record.
  bool get _isBlank =>
      _name.text.trim().isEmpty &&
      _body.text.trim().isEmpty &&
      _summary.text.trim().isEmpty &&
      _tags.isEmpty &&
      _tickers.isEmpty;

  /// Gaps worth naming but never worth refusing a save over. A playbook is
  /// written over weeks, and blocking the save would lose the paragraph the
  /// trader just typed.
  List<String> get _gaps => <String>[
    if (_body.text.trim().isEmpty) 'rules',
    if (_summary.text.trim().isEmpty) 'summary',
    if (_tickers.isEmpty) 'instruments',
    if (_tags.isEmpty) 'tags',
  ];

  /// Live rules with no trades filed under them is the state most worth warning
  /// about: it is the shape of a playbook that was promoted and then never
  /// followed, and the performance panel will read as a blank rather than a
  /// failure.
  bool get _liveButUntraded =>
      _status == AppStrategyStatus.live && _linkedJournalIds.isEmpty;

  // ── Saving ─────────────────────────────────────────────────────────────────

  /// Persists the draft and returns the stored playbook, or null if nothing was
  /// written or the write failed.
  ///
  /// The one hard requirement is a name: a playbook is filed, searched and linked
  /// by it, and an unnamed one cannot be found again or referenced from a trade.
  ///
  /// [versionNote] non-null cuts a numbered revision as part of the same save —
  /// an empty string means "cut one, but the trader chose not to name it", which
  /// is a different answer from null.
  Future<AppStrategy?> _save({bool silent = false, String? versionNote}) async {
    if (_saving) return null;
    if (_name.text.trim().isEmpty) {
      if (!silent && mounted) {
        UiToast.info(
          context,
          title: 'Name the playbook',
          message: 'A playbook is filed under its name. Add one to save.',
        );
        _nameFocus.requestFocus();
      }
      return null;
    }
    final AppStrategy before = _strategy;
    final AppStrategy draft = _draft;
    setState(() => _saving = true);
    try {
      final StrategiesRepository repo = StrategiesRepositoryScope.repository;
      AppStrategy saved = draft.id.isEmpty
          ? await repo.create(draft)
          : await repo.update(draft, versionNote: versionNote);
      saved = await _reconcileLinks(saved, before: before);
      if (!mounted) return saved;
      setState(() {
        _strategy = saved;
        _saving = false;
      });
      if (!silent) {
        final List<String> gaps = _gaps;
        UiToast.success(
          context,
          title: versionNote == null ? 'Playbook saved' : 'Revision saved',
          message: gaps.isEmpty ? null : 'Still missing: ${gaps.join(', ')}.',
        );
      }
      return saved;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _saving = false);
      UiToast.error(
        context,
        title: 'Could not save the playbook',
        message: '$error',
      );
      return null;
    }
  }

  /// Saves and cuts a numbered revision, asking for the changelog line first.
  ///
  /// The line is asked for here rather than inferred because only the trader
  /// knows *why* a rule moved, and that is the whole value of the history.
  Future<void> _saveRevision() async {
    if (_name.text.trim().isEmpty) {
      UiToast.info(
        context,
        title: 'Name the playbook',
        message: 'A revision is filed against a named playbook.',
      );
      _nameFocus.requestFocus();
      return;
    }
    final String? note = await showRevisionNotePrompt(context);
    if (note == null || !mounted) return;
    await _save(versionNote: note);
  }

  /// Writes the far end of every link the trader changed, then re-reads the
  /// playbook.
  ///
  /// The playbook row already carries `linkedNoteIds` and `linkedJournalIds` —
  /// the save above persisted them. What is missing is the other side: the note's
  /// `strategyId` and the trade's. That work happens after the save rather than
  /// before it because [AppLinkGraphService] resolves a playbook id against the
  /// store, and a draft has no id to resolve.
  ///
  /// Instruments are deliberately absent. A ticker has no row of its own — the
  /// playbook's `linkedTickers` *is* where that edge lives, and the save wrote it.
  Future<AppStrategy> _reconcileLinks(
    AppStrategy saved, {
    required AppStrategy before,
  }) async {
    // A draft's far ends cannot already exist, so every current link is new.
    final bool fresh = before.id.isEmpty;
    bool complete = true;

    Future<void> edge(Future<void> Function() write) async {
      try {
        await write();
      } catch (_) {
        // The playbook itself is saved; a half-written edge is a display
        // problem, not lost work. Reported once, below.
        complete = false;
      }
    }

    Future<void> sync(
      AppLinkKind kind,
      List<String> was,
      List<String> now,
    ) async {
      final Set<String> before = fresh ? const <String>{} : was.toSet();
      final Set<String> after = now.toSet();
      for (final String id in after.difference(before)) {
        await edge(
          () => _links.link(
            fromKind: AppLinkKind.strategy,
            fromId: saved.id,
            toKind: kind,
            toId: id,
          ),
        );
      }
      for (final String id in before.difference(after)) {
        await edge(
          () => _links.unlink(
            fromKind: AppLinkKind.strategy,
            fromId: saved.id,
            toKind: kind,
            toId: id,
          ),
        );
      }
    }

    await sync(AppLinkKind.note, before.linkedNoteIds, saved.linkedNoteIds);
    await sync(
      AppLinkKind.journal,
      before.linkedJournalIds,
      saved.linkedJournalIds,
    );

    if (!complete && mounted) {
      UiToast.warning(
        context,
        title: 'Playbook saved',
        message: 'Some links did not update. Reopen the playbook to retry.',
      );
    }
    // The service mutates the playbook as it writes both ends, so the copy
    // returned by the save above is already stale.
    return await StrategiesRepositoryScope.repository.getById(saved.id) ??
        saved;
  }

  /// Leave the editor from outside — the shell's app-bar back button on a phone,
  /// where the host drew the chrome and this screen did not. Routed through the
  /// same path as the editor's own back button so both behave identically.
  Future<void> close() => _closeAndSave();

  /// Leaving the editor saves silently, into the live revision rather than a new
  /// one. Losing a rewritten rule set because a back gesture was read as
  /// "discard" is the worst thing this screen could do; an unwanted save is one
  /// tap from being deleted, and the history is untouched either way.
  ///
  /// The one case that cannot save is a playbook with no name, and that is worth
  /// a dialog rather than a silent drop — the trader has written rules by then,
  /// and only they can say what to call them.
  Future<void> _closeAndSave() async {
    if (_isBlank) {
      widget.onClose(_strategy.id.isEmpty ? null : _strategy);
      return;
    }
    if (_name.text.trim().isEmpty) {
      final bool discard = await UiDialog.confirm(
        context,
        title: 'This playbook has no name',
        description:
            'A playbook is filed and linked by name, so it needs one before it '
            'can be saved. Discard what you have written?',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        confirmVariant: UiVariant.destructive,
      );
      if (!mounted) return;
      if (!discard) {
        _nameFocus.requestFocus();
        return;
      }
      widget.onClose(_strategy.id.isEmpty ? null : _strategy);
      return;
    }
    if (_saving) return;
    final needsSave = _dirty;
    final AppStrategy? saved = needsSave
        ? await _save(silent: true)
        : (_strategy.id.isEmpty ? null : _strategy);
    if (needsSave && saved == null) return;
    if (mounted) widget.onClose(saved);
  }

  /// Deleting a playbook is the one destructive act here, and it is worse than
  /// deleting a note: the trades filed under it lose the plan that explains them.
  /// The confirm says so, with the count.
  Future<void> _delete() async {
    final int trades = _linkedJournalIds.length;
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete this playbook?',
      description: trades == 0
          ? 'The rules and every revision of them go away. This cannot be '
                'undone.'
          : 'The rules and every revision of them go away, and $trades '
                '${trades == 1 ? 'trade' : 'trades'} '
                '${trades == 1 ? 'loses' : 'lose'} the plan that explains '
                '${trades == 1 ? 'it' : 'them'}. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    try {
      if (_strategy.id.isNotEmpty) {
        await StrategiesRepositoryScope.repository.delete(_strategy.id);
      }
      if (!mounted) return;
      UiToast.success(context, title: 'Playbook deleted');
      if (widget.onDeleted != null) {
        widget.onDeleted!();
      } else {
        widget.onClose(null);
      }
    } catch (error) {
      if (!mounted) return;
      UiToast.error(context, title: 'Could not delete', message: '$error');
    }
  }

  // ── Composing ──────────────────────────────────────────────────────────────

  void _setMode(StrategyEditorMode next) {
    // The preview is debounced, so entering a mode that shows it has to pull the
    // current text across immediately or the first frame renders stale markdown.
    _previewDebounce?.cancel();
    _preview.value = _body.text;
    setState(() => _mode = next);
    if (next == StrategyEditorMode.write || next == StrategyEditorMode.split) {
      _bodyFocus.requestFocus();
    }
  }

  void _applySnippet(MarkdownSnippet snippet) {
    final RichMarkdownEditorFieldState? editor = _editorKey.currentState;
    if (editor == null) return;
    // Remove the `/query` first so the block replaces what was typed instead of
    // landing after it.
    editor.consumeSlashQuery();
    snippet.applyTo(editor);
    _slash.value = null;
    _bodyFocus.requestFocus();
  }

  void _submitSlash() {
    final String? query = _slash.value;
    if (query == null) return;
    final MarkdownSnippet? top = MarkdownSlashPalette.topMatch(query);
    if (top != null) _applySnippet(top);
  }

  void _dismissSlash() {
    _editorKey.currentState?.dismissSlashQuery();
    _slash.value = null;
  }

  /// A searchable one-shot picker. [UiSelect] already renders as a sheet on
  /// phones and an anchored menu elsewhere, so this only has to host it.
  Future<String?> _pickOne({
    required String title,
    required String hint,
    required List<UiOption<String>> options,
  }) => UiDialog.show<String>(
    context,
    child: Builder(
      builder: (BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: ctx.uiText.subheading),
          SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
          UiSelect<String>(
            options: options,
            hintText: hint,
            searchable: true,
            onChanged: (String value) => Navigator.of(ctx).pop(value),
          ),
        ],
      ),
    ),
  );

  /// References an instrument inside the rules — "only when the index is above
  /// its 20-day". The playbook's own instrument list is the rail field, not this.
  Future<void> _insertTicker() async {
    final String? symbol = await _pickOne(
      title: 'Reference an instrument',
      hint: 'Search symbols',
      options: <UiOption<String>>[
        for (final AppLinkRef ref in _graph.options(AppLinkKind.ticker))
          UiOption<String>(
            value: ref.id,
            label: ref.id,
            description: ref.subtitle,
            trailingLabel: ref.meta,
          ),
      ],
    );
    if (symbol == null || !mounted) return;
    _editorKey.currentState?.insertInline(
      '${AppDeepLink.markdown(kind: AppLinkKind.ticker, id: symbol, label: '\$$symbol')} ',
    );
    // Naming a symbol in the rules is a statement about what the playbook is
    // for, so it joins the instrument list unless it is already there.
    final String upper = symbol.toUpperCase();
    if (!_tickers.any((String t) => t.toUpperCase() == upper)) {
      setState(() => _tickers = <String>[..._tickers, upper]);
    }
  }

  /// References a trade inside the rules — "the RELIANCE entry is what this rule
  /// is for". Linking it in the rail is the filing; this is the citation.
  Future<void> _insertJournal() async {
    final String? id = await _pickOne(
      title: 'Cite a trade',
      hint: 'Search journal entries',
      options: <UiOption<String>>[
        for (final AppLinkRef ref in _graph.options(AppLinkKind.journal))
          UiOption<String>(
            value: ref.id,
            label: ref.title,
            description: ref.subtitle,
            trailingLabel: ref.meta,
          ),
      ],
    );
    if (id == null || !mounted) return;
    final AppLinkRef ref = _graph.refFor(AppLinkKind.journal, id);
    _editorKey.currentState?.insertInline(
      '${AppDeepLink.markdown(kind: AppLinkKind.journal, id: id, label: ref.title)} ',
    );
  }

  // ── Links ──────────────────────────────────────────────────────────────────

  /// Attaches trader notes — the research that produced these rules.
  ///
  /// Held in local state until the save. The far end — the note's own playbook
  /// field — is written by [_reconcileLinks], because a draft has no id for the
  /// link service to resolve.
  Future<void> _pickNotes() async {
    final List<AppLinkRef> options = _graph.options(
      AppLinkKind.note,
      exclude: _linkedNoteIds,
    );
    if (options.isEmpty) {
      UiToast.info(
        context,
        title: _graph.noteList.isEmpty
            ? 'No trader notes yet'
            : 'Every note is already linked',
      );
      return;
    }
    final List<String>? chosen = await showAppLinkPicker(
      context,
      kind: AppLinkKind.note,
      options: options,
      title: 'Link trader notes',
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(() => _linkedNoteIds = <String>[..._linkedNoteIds, ...chosen]);
  }

  /// Files trades under this playbook. Multi-select, because the question a
  /// playbook has to answer — does this setup work for me — needs six trades, not
  /// one.
  ///
  /// A trade belongs to exactly one playbook, so filing one here takes it off
  /// whichever plan it was on. The derived figures follow the trade, which is why
  /// the win rate on the old playbook drops when this saves.
  Future<void> _pickJournal() async {
    final List<AppLinkRef> options = _graph.options(
      AppLinkKind.journal,
      exclude: _linkedJournalIds,
    );
    if (options.isEmpty) {
      UiToast.info(
        context,
        title: _graph.journalList.isEmpty
            ? 'No journal entries yet'
            : 'Every entry is already filed here',
      );
      return;
    }
    final List<String>? chosen = await showAppLinkPicker(
      context,
      kind: AppLinkKind.journal,
      options: options,
      title: 'File trades under this playbook',
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    setState(
      () => _linkedJournalIds = <String>[..._linkedJournalIds, ...chosen],
    );
  }

  void _unlink(AppLinkRef ref) {
    switch (ref.kind) {
      case AppLinkKind.note:
        setState(
          () => _linkedNoteIds = _linkedNoteIds
              .where((String id) => id != ref.id)
              .toList(growable: false),
        );
      case AppLinkKind.journal:
        setState(
          () => _linkedJournalIds = _linkedJournalIds
              .where((String id) => id != ref.id)
              .toList(growable: false),
        );
      case AppLinkKind.ticker:
        setState(
          () => _tickers = _tickers
              .where(
                (String symbol) => symbol.toUpperCase() != ref.id.toUpperCase(),
              )
              .toList(growable: false),
        );
      case AppLinkKind.strategy:
        // A playbook is never linked to another playbook.
        return;
    }
  }

  /// Categories are picked from what the library already uses, because the point
  /// of them is comparison — two playbooks in "Momentum" and "momentum trades"
  /// are two categories of one. Typing a new one is one extra tap, deliberately.
  Future<void> _pickCategory() async {
    const String newValue = '__new__';
    final List<String> known =
        <String>{
          for (final AppStrategy s in _graph.strategyList)
            if ((s.category ?? '').trim().isNotEmpty) s.category!.trim(),
          if ((_category ?? '').trim().isNotEmpty) _category!.trim(),
        }.toList()..sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
        );
    final String? picked = await _pickOne(
      title: 'Category',
      hint: 'Search categories',
      options: <UiOption<String>>[
        const UiOption<String>(
          value: '',
          label: 'No category',
          description: 'Leave it uncategorised',
        ),
        for (final String c in known) UiOption<String>(value: c, label: c),
        const UiOption<String>(
          value: newValue,
          label: 'New category…',
          icon: Icons.add_rounded,
          description: 'Type one the library does not have yet',
        ),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked != newValue) {
      setState(() => _category = picked.isEmpty ? null : picked);
      return;
    }
    final String? typed = await showSingleLinePrompt(
      context,
      title: 'New category',
      description:
          'Categories group playbooks in the library and on the community '
          'feed. Broad beats specific: "Momentum" sorts, "Momentum breakouts on '
          'gap days" does not.',
      fieldLabel: 'Category',
      fieldHelper: 'One or two words.',
      hintText: 'Mean reversion',
      confirmLabel: 'Use category',
      icon: Icons.folder_outlined,
      maxLength: 32,
    );
    if (typed == null || !mounted) return;
    setState(() => _category = typed.isEmpty ? null : typed);
  }

  // ── AI, attachments, dictation ─────────────────────────────────────────────

  /// Rewrites the selection. A playbook is a set of instructions the trader has
  /// to follow at speed, so the service is asked for the trade-plan voice —
  /// imperative and unambiguous — rather than the reflective journal one.
  Future<void> _refactor({String? instruction}) async {
    final TextSelection? selection = _selection.value;
    if (selection == null || _refactoring) return;
    final String selected = selection.textInside(_body.text);
    if (selected.trim().isEmpty) return;

    setState(() => _refactoring = true);
    try {
      final String enhanced = await NoteAiScope.service.enhance(
        selectedText: selected,
        noteType: AppNoteType.plan,
        contextTitle: _name.text.trim().isEmpty
            ? 'Untitled playbook'
            : _name.text.trim(),
        instruction: instruction,
      );
      if (!mounted) return;
      _body.value = TextEditingValue(
        text: _body.text.replaceRange(selection.start, selection.end, enhanced),
        selection: TextSelection.collapsed(
          offset: selection.start + enhanced.length,
        ),
      );
      _selection.value = null;
      UiToast.success(
        context,
        title: NoteAiScope.isDemo ? 'Rewritten on device' : 'Rewritten',
        message: 'Undo restores the original.',
      );
    } catch (error) {
      if (!mounted) return;
      UiToast.error(
        context,
        title: 'Could not rewrite that',
        message: '$error',
      );
    } finally {
      if (mounted) setState(() => _refactoring = false);
    }
  }

  /// Share the floating, keyboard-aware dialog used by all editor overlays.
  Future<void> _customPrompt() async {
    final TextSelection? selection = _selection.value;
    if (selection == null) return;
    await UiDialog.show<void>(
      context,
      maxWidth: 600,
      child: AiCustomPromptSheet(
        selectedText: selection.textInside(_body.text),
        onApply: (String prompt) => _refactor(instruction: prompt),
      ),
    );
  }

  /// The annotated example — this is what the setup looks like when it is valid,
  /// and this is what it looks like when it is not. Usually the most-read part of
  /// a playbook.
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      await _attach(File(picked.path), filename: picked.name);
    } catch (error) {
      if (!mounted) return;
      UiToast.error(
        context,
        title: 'Could not open the gallery',
        message: '$error',
      );
    }
  }

  /// Text-ish imports land as content; anything else is attached by reference.
  Future<void> _pickDocument() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['md', 'txt', 'pdf', 'png', 'jpg', 'jpeg'],
      );
      final String? path = result?.files.first.path;
      if (path == null) return;
      final String name = result!.files.first.name;
      final String ext = p.extension(path).toLowerCase();
      if (ext == '.md' || ext == '.txt') {
        final String text = await File(path).readAsString();
        if (!mounted) return;
        _editorKey.currentState?.insertBlock('$text\n');
        UiToast.success(context, title: 'Imported $name');
        return;
      }
      await _attach(File(path), filename: name);
      if (ext == '.pdf' && mounted) {
        UiToast.info(
          context,
          title: 'PDF attached as a link',
          message: 'Its text is not pulled into the playbook.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      UiToast.error(
        context,
        title: 'Could not import that file',
        message: '$error',
      );
    }
  }

  /// Attachments belong to a saved playbook, so a draft is written first —
  /// otherwise the file would be stored against an id that does not exist yet,
  /// and the playbook bucket is keyed by playbook.
  Future<void> _attach(File source, {required String filename}) async {
    final AppStrategy? owner = _strategy.id.isEmpty
        ? await _save(silent: true)
        : _strategy;
    if (!mounted) return;
    if (owner == null) {
      UiToast.info(
        context,
        title: 'Name the playbook first',
        message: 'Attachments are stored against a saved playbook.',
      );
      return;
    }
    try {
      final String markdown = await StrategyAttachments.attach(
        strategyId: owner.id,
        source: source,
        filename: filename,
      );
      if (!mounted) return;
      _editorKey.currentState?.insertBlock(markdown);
    } catch (error) {
      if (!mounted) return;
      UiToast.error(context, title: 'Could not attach that', message: '$error');
    }
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final bool available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        UiToast.warning(
          context,
          title: 'Dictation is not available',
          message: 'Check the microphone permission for TradeX.',
        );
      }
      return;
    }
    // `recognizedWords` is the whole phrase since listen() began, not a delta, so
    // every result replaces the dictated tail instead of appending to it.
    _voiceBase = _body.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final String spoken = result.recognizedWords.trim();
        if (spoken.isEmpty) return;
        final String next = _voiceBase.trimRight().isEmpty
            ? spoken
            : '${_voiceBase.trimRight()} $spoken';
        _body.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  // ── Layout ─────────────────────────────────────────────────────────────────

  /// One line under the name: what state the playbook is in, how much has been
  /// written, and whether it is safe to walk away.
  String get _statusLine {
    final AppStrategy draft = _draft;
    final int words = draft.wordCount;
    final String state = _saving
        ? 'Saving…'
        : _dirty
        ? 'Unsaved changes'
        : _strategy.id.isEmpty
        ? 'Not saved yet'
        : 'Saved';
    return <String>[
      _status.label,
      _isPublic ? 'Public' : 'Private',
      '$words ${words == 1 ? 'word' : 'words'}',
      if (_strategy.id.isNotEmpty) 'v${_strategy.versionCount}',
      state,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Material(
      color: theme.colors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.detailsOnly) {
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _closeAndSave();
              },
              child: AppRecordDetailsForm(
                title: 'Strategy details',
                description:
                    'Status, instruments and classification. Write the playbook from Notes.',
                saving: _saving,
                onBack: _closeAndSave,
                onSave: () async {
                  final saved = await _save();
                  if (saved != null && mounted) widget.onClose(saved);
                },
                onDelete: _strategy.id.isEmpty ? null : _delete,
                fields: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nameField(context),
                    const UiGap.v(16),
                    _contractFields(
                      context,
                      twoColumn: constraints.maxWidth >= context.sz(580),
                    ),
                  ],
                ),
              ),
            );
          }

          // The rail and the split preview need real working room. Tablets use the
          // same scrollable composition as phones instead of squeezing three
          // independently scrolling regions into one short viewport.
          final bool wide = constraints.maxWidth >= context.sz(980);

          return PopScope(
            // Back is a save, not a discard, and it has to unwind the host's own
            // list/editor switch rather than the enclosing route.
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? _) {
              if (!didPop) _closeAndSave();
            },
            child: Stack(
              children: <Widget>[
                UiPage(
                  maxWidth: 1440,
                  scrollable: !wide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _commandBar(context, wide: wide),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      if (wide)
                        Expanded(child: _wideBody(context))
                      else
                        _narrowBody(context),
                    ],
                  ),
                ),
                ..._overlays(context, wide: wide),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Back, the mode switch, the two saves and the overflow — everything that is
  /// true of the whole screen. Wrapped in the revision listener so the save
  /// button enables itself as soon as a character lands anywhere.
  Widget _commandBar(BuildContext context, {required bool wide}) {
    final UiTheme theme = context.ui;
    return ValueListenableBuilder<int>(
      valueListenable: _revision,
      builder: (BuildContext ctx, int _, Widget? _) {
        final bool isMobile = context.uiRes.isMobile;
        final bool savable = !_saving && (_dirty || _strategy.id.isEmpty);
        final Widget? back = isMobile
            ? null
            : UiIconButton(
                icon: Icons.arrow_back_rounded,
                variant: UiVariant.ghost,
                tooltip: 'Back to the strategy',
                onPressed: _closeAndSave,
              );
        final Widget modes = UiToggleGroup<StrategyEditorMode>(
          options: <UiToggleOption<StrategyEditorMode>>[
            for (final StrategyEditorMode mode in StrategyEditorMode.values)
              if (mode != StrategyEditorMode.split || wide)
                UiToggleOption<StrategyEditorMode>(
                  value: mode,
                  label: mode.label,
                  icon: mode.icon,
                  tooltip: mode.label,
                ),
          ],
          value: _mode,
          onChanged: _setMode,
          size: UiSize.sm,
          expand: !wide,
          allowEmpty: false,
        );
        // Cutting a revision, publishing and deleting are all rare and all
        // consequential, so they share one menu instead of three buttons a
        // thumb can hit by accident.
        final Widget more = UiDropdownMenu(
          alignRight: true,
          width: 280,
          items: <UiMenuItem>[
            UiMenuItem(
              label: 'Save as revision…',
              icon: Icons.history_rounded,
              description: 'Cut a numbered version with a changelog line',
              enabled: !_saving,
              onTap: _saveRevision,
            ),
            UiMenuItem(
              label: _isPublic ? 'Make private' : 'Share to the feed',
              icon: _isPublic
                  ? Icons.lock_outline_rounded
                  : Icons.public_rounded,
              description: _isPublic
                  ? 'Only you can read it'
                  : 'Rules only — your trades and P/L stay private',
              enabled: !_saving,
              onTap: () => setState(() => _isPublic = !_isPublic),
            ),
            const UiMenuItem.divider(),
            UiMenuItem(
              label: 'Delete playbook',
              icon: Icons.delete_outline_rounded,
              destructive: true,
              enabled: !_saving,
              onTap: _delete,
            ),
          ],
          child: UiIconButton(
            icon: Icons.more_horiz_rounded,
            variant: UiVariant.ghost,
            tooltip: 'More',
            onPressed: null,
          ),
        );
        final Widget save = UiButton(
          label: 'Save',
          leadingIcon: Icons.check_rounded,
          size: UiSize.sm,
          loading: _saving,
          loadingLabel: 'Saving',
          expandOnMobile: false,
          onPressed: savable ? () => _save() : null,
        );
        final Widget identity = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMobile)
                Text(
                  _name.text.trim().isEmpty
                      ? 'Untitled playbook'
                      : _name.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong,
                ),
              Text(
                _statusLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ),
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (back != null) ...<Widget>[
                    back,
                    SizedBox(width: context.sp(theme.spacing.xs)),
                  ],
                  identity,
                  more,
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  save,
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              modes,
            ],
          );
        }

        return Row(
          children: <Widget>[
            if (back != null) ...<Widget>[
              back,
              SizedBox(width: context.sp(theme.spacing.sm)),
            ],
            identity,
            modes,
            SizedBox(width: context.sp(theme.spacing.sm)),
            UiButton(
              label: 'Save revision',
              leadingIcon: Icons.history_rounded,
              variant: UiVariant.secondary,
              size: UiSize.sm,
              onPressed: _saving ? null : _saveRevision,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            more,
            SizedBox(width: context.sp(theme.spacing.xs)),
            save,
          ],
        );
      },
    );
  }

  /// The phone layout: name, the collapsible contract, then one surface. A
  /// playbook is written in the same posture a note is, so the writing canvas
  /// gets the whole width and the contract folds away once it is filled in.
  Widget _narrowBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _nameField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _contractPanel(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (_mode == StrategyEditorMode.read)
          _pane(
            context,
            label: 'Reading preview',
            icon: Icons.menu_book_outlined,
            child: _previewPane(context, scrollable: false),
          )
        else
          _pane(
            context,
            label: 'Writing canvas',
            icon: Icons.edit_note_rounded,
            child: _editorPane(context, expands: false),
          ),
        // Clearance for the toolbar docked over the page.
        SizedBox(height: context.sp(150)),
      ],
    );
  }

  /// Desktop keeps one focused column. The playbook contract is a collapsible
  /// section above the writing canvas instead of a permanent sidebar.
  Widget _wideBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _nameField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _contractPanel(context),
        if (_mode != StrategyEditorMode.read) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          MarkdownFormatRibbon(
            editorKey: _editorKey,
            onPickImage: _pickImage,
            onPickDocument: _pickDocument,
            onInsertTicker: _insertTicker,
            onInsertRecord: () async {
              final ref = await showRecordLinkPicker(
                context,
                sourceKind: AppLinkKind.strategy,
                sourceId: _strategy.id,
              );
              if (ref != null && mounted) {
                _editorKey.currentState?.insertInline(
                  AppDeepLink.markdown(
                    kind: ref.kind,
                    id: ref.id,
                    label: ref.title,
                  ),
                );
              }
            },
            onInsertJournal: _insertJournal,
            onToggleVoice: _toggleVoice,
            listening: _listening,
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.sm)),
        Expanded(child: _wideArea(context)),
      ],
    );
  }

  Widget _wideArea(BuildContext context) => switch (_mode) {
    StrategyEditorMode.write => _pane(
      context,
      label: 'Writing canvas',
      icon: Icons.edit_note_rounded,
      expands: true,
      scrollbarController: _editorScrollController,
      child: _editorPane(context, expands: true),
    ),
    StrategyEditorMode.read => _pane(
      context,
      label: 'Reading preview',
      icon: Icons.menu_book_outlined,
      expands: true,
      child: _previewPane(context, scrollable: true),
    ),
    StrategyEditorMode.split => UiSplitPane(
      primary: _pane(
        context,
        label: 'Writing canvas',
        icon: Icons.edit_note_rounded,
        expands: true,
        scrollbarController: _editorScrollController,
        child: _editorPane(context, expands: true),
      ),
      detail: Padding(
        padding: EdgeInsets.only(left: context.sp(context.ui.spacing.md)),
        child: _pane(
          context,
          label: 'Live preview',
          icon: Icons.visibility_outlined,
          expands: true,
          child: _previewPane(context, scrollable: true),
        ),
      ),
      initialRatio: 0.5,
      minRatio: 0.3,
      maxRatio: 0.7,
      splitFrom: UiDeviceType.tablet,
    ),
  };

  /// Chrome-less, so it reads as the playbook's own first line rather than as a
  /// form field above it. The one required value on the screen.
  Widget _nameField(BuildContext context) => UiInput(
    controller: _name,
    focusNode: _nameFocus,
    hintText: 'Name this playbook — "Opening range break", "Gap fill fade"',
    variant: UiInputVariant.ghost,
    size: UiSize.lg,
    readOnly: _mode == StrategyEditorMode.read,
    textInputAction: TextInputAction.next,
  );

  /// The phone panel. Open while the playbook is new, folded away once it is set
  /// up, because the reason somebody opens this screen on a phone is to write a
  /// rule down before they forget it.
  Widget _contractPanel(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (BuildContext ctx, int _, Widget? _) => UiAccordion(
      variant: UiAccordionVariant.contained,
      openIndices: _detailsOpen ? const <int>{0} : const <int>{},
      onChanged: (Set<int> open) =>
          setState(() => _detailsOpen = open.contains(0)),
      items: <UiAccordionItem>[
        UiAccordionItem(
          title: 'The playbook',
          subtitle: _contractSummary,
          leadingIcon: _status.icon,
          intent: _gaps.isEmpty ? UiIntent.success : _status.intent,
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: ctx.sz(320)),
            child: SingleChildScrollView(
              child: _contractFields(ctx, twoColumn: true),
            ),
          ),
        ),
      ],
    ),
  );

  /// The one-line version for the collapsed phone panel.
  String get _contractSummary => <String>[
    _status.label,
    if ((_category ?? '').trim().isNotEmpty) _category!.trim(),
    if (_tickers.isNotEmpty)
      _tickers.take(3).map((String t) => t.toUpperCase()).join(' ')
    else
      'No instruments',
    if (_linkedJournalIds.isNotEmpty)
      '${_linkedJournalIds.length} trade${_linkedJournalIds.length == 1 ? '' : 's'}',
    if (_isPublic) 'Public',
  ].join(' · ');

  /// Everything about the playbook that is not the rules themselves. Identical on
  /// both layouts apart from [twoColumn], which pairs the short fields up on the
  /// phone panel where the width is there but the height is not.
  Widget _contractFields(BuildContext context, {required bool twoColumn}) {
    final UiTheme theme = context.ui;
    final bool readOnly = _mode == StrategyEditorMode.read;

    final Widget statusField = UiField(
      label: 'Status',
      helper: 'Draft → Testing → Live is the honest order',
      child: UiSelect<AppStrategyStatus>(
        expand: true,
        enabled: !readOnly,
        options: <UiOption<AppStrategyStatus>>[
          for (final AppStrategyStatus status in AppStrategyStatus.values)
            UiOption<AppStrategyStatus>(
              value: status,
              label: status.label,
              icon: status.icon,
              description: switch (status) {
                AppStrategyStatus.draft => 'Still being written',
                AppStrategyStatus.testing => 'Being traded small, on purpose',
                AppStrategyStatus.live => 'Trading it at full size',
                AppStrategyStatus.retired => 'Kept for the record, not traded',
              },
            ),
        ],
        value: _status,
        onChanged: (AppStrategyStatus next) => setState(() => _status = next),
      ),
    );

    final Widget categoryField = UiField(
      label: 'Category',
      helper: 'Groups playbooks that compete for the same capital',
      child: UiButton(
        label: (_category ?? '').trim().isEmpty
            ? 'No category'
            : _category!.trim(),
        leadingIcon: Icons.folder_outlined,
        variant: UiVariant.outline,
        size: UiSize.sm,
        expand: true,
        onPressed: readOnly ? null : _pickCategory,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiField(
          label: 'One-line summary',
          helper: 'What the library card shows. The setup in a sentence.',
          child: UiInput.multiline(
            controller: _summary,
            hintText:
                'Buy the first pullback after a gap-and-go, stop under the '
                'opening range',
            minLines: 2,
            maxLines: 3,
            maxLength: 180,
            readOnly: readOnly,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (twoColumn)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: statusField),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(child: categoryField),
            ],
          )
        else ...<Widget>[
          statusField,
          SizedBox(height: context.sp(theme.spacing.sm)),
          categoryField,
        ],
        if (_liveButUntraded) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiCallout(
            intent: UiIntent.warning,
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Live, but nothing filed under it',
            message:
                'Performance stays blank until trades reference this playbook. '
                'File the trades you took on it, or set it back to Testing.',
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.sm)),
        _instrumentsField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _tagsField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _visibilityField(context),
        SizedBox(height: context.sp(theme.spacing.md)),
        _linkedNotesField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _filedTradesField(context),
      ],
    );
  }

  /// Instruments are the one link a playbook owns outright: there is no ticker
  /// row to write to, so this list *is* the edge. Symbols are upper-cased on the
  /// way in, because `nifty` and `NIFTY` are one instrument.
  Widget _instrumentsField(BuildContext context) => UiField(
    label: 'Instruments',
    helper: 'What this playbook is allowed to trade',
    child: UiTagInput(
      tags: _tickers,
      prefix: '\$',
      intent: UiIntent.info,
      hintText: 'Add a symbol',
      suggestions: <String>[
        for (final AppLinkRef ref
            in _graph
                .options(
                  AppLinkKind.ticker,
                  exclude: _tickers.map((String t) => t.toUpperCase()),
                )
                .take(8))
          ref.id,
      ],
      onChanged: (List<String> next) => setState(
        () => _tickers = <String>{
          for (final String symbol in next)
            if (symbol.trim().isNotEmpty) symbol.trim().toUpperCase(),
        }.toList(growable: false),
      ),
    ),
  );

  Widget _tagsField(BuildContext context) => UiField(
    label: 'Tags',
    helper: 'How you will find this again',
    child: UiTagInput(
      tags: _tags,
      prefix: '#',
      hintText: 'Add a tag',
      suggestions: StrategiesQuery.tagsOf(
        _graph.strategyList,
      ).where((String t) => !_tags.contains(t)).take(8).toList(),
      onChanged: (List<String> next) => setState(() => _tags = next),
    ),
  );

  /// Sharing a playbook shares the rules, not the account. Saying so here is the
  /// difference between a trader publishing a setup and a trader accidentally
  /// publishing their P/L.
  Widget _visibilityField(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      UiSwitch(
        value: _isPublic,
        label: 'Share to the community feed',
        description: 'Rules and instruments only — your trades stay private',
        enabled: _mode != StrategyEditorMode.read,
        onChanged: (bool value) => setState(() => _isPublic = value),
      ),
      if (_isPublic) ...<Widget>[
        SizedBox(height: context.sp(context.ui.spacing.sm)),
        UiCallout(
          intent: UiIntent.info,
          icon: Icons.public_rounded,
          title: 'Readers see the playbook, not the account',
          message:
              'The rules, instruments and tags are public once this saves. '
              'Filed trades, P/L and linked private notes are not.',
        ),
      ],
    ],
  );

  /// Research that belongs to this playbook. Kept separate from the filed trades
  /// below because a note is *why* a rule exists and a trade is *whether it
  /// worked*, and a playbook needs both to be worth keeping.
  Widget _linkedNotesField(BuildContext context) => _linkList(
    context,
    label: 'Linked trader notes',
    helper: 'The research this playbook came out of',
    addLabel: 'Link a note',
    emptyLabel: 'No notes linked yet',
    kind: AppLinkKind.note,
    ids: _linkedNoteIds,
    onAdd: _pickNotes,
  );

  /// The trades filed under these rules — the only source of every performance
  /// figure on the playbook. Adding one here moves it off whatever plan it was
  /// on, which is why the count is worth showing next to the label.
  Widget _filedTradesField(BuildContext context) => _linkList(
    context,
    label: 'Filed trades',
    helper: 'Every number on this playbook is derived from these',
    addLabel: 'File a trade',
    emptyLabel: 'No trades filed — performance will read as untested',
    kind: AppLinkKind.journal,
    ids: _linkedJournalIds,
    onAdd: _pickJournal,
  );

  Widget _linkList(
    BuildContext context, {
    required String label,
    required String helper,
    required String addLabel,
    required String emptyLabel,
    required AppLinkKind kind,
    required List<String> ids,
    required Future<void> Function() onAdd,
  }) {
    final UiTheme theme = context.ui;
    final bool readOnly = _mode == StrategyEditorMode.read;
    final List<AppLinkRef> refs = <AppLinkRef>[
      for (final String id in ids) _graph.refFor(kind, id),
    ];
    return UiField(
      label: ids.isEmpty ? label : '$label (${ids.length})',
      helper: helper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiButton(
            label: addLabel,
            leadingIcon: Icons.add_link_rounded,
            variant: UiVariant.outline,
            size: UiSize.sm,
            expand: true,
            onPressed: readOnly ? null : onAdd,
          ),
          if (refs.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
              child: Text(
                emptyLabel,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            )
          else
            for (final AppLinkRef ref in refs)
              Padding(
                padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
                child: AppLinkRefTile(
                  ref: ref,
                  dense: true,
                  onRemove: readOnly ? null : () => _unlink(ref),
                ),
              ),
        ],
      ),
    );
  }

  /// A labelled writing or reading surface. [expands] is true only when an
  /// ancestor gives it a bounded height (the wide layout's [Expanded]).
  Widget _pane(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget child,
    bool expands = false,
    ScrollController? scrollbarController,
  }) {
    final UiTheme theme = context.ui;
    final EdgeInsets padding = EdgeInsets.all(context.sp(theme.spacing.md));
    final Widget cardChild = scrollbarController == null
        ? Padding(padding: padding, child: child)
        : Scrollbar(
            controller: scrollbarController,
            interactive: true,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: Padding(padding: padding, child: child),
            ),
          );
    final Widget card = UiCard(
      variant: UiCardVariant.outlined,
      hoverLift: false,
      padding: EdgeInsets.zero,
      child: cardChild,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: UiBadge(
            label: label,
            icon: icon,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (expands) Expanded(child: card) else card,
      ],
    );
  }

  /// No card frame: the rules are the page. The hint names the four questions a
  /// playbook has to answer, because "write your strategy" is the prompt that
  /// produces a blank document.
  Widget _editorPane(
    BuildContext context, {
    required bool expands,
  }) => RichMarkdownEditorField(
    key: _editorKey,
    controller: _body,
    focusNode: _bodyFocus,
    autofocus: _strategy.id.isEmpty && _body.text.isEmpty,
    hintText:
        'What is the setup, when is it valid, where does the stop go, and '
        'when do you stand aside? Type / for checklists and blocks.',
    minLines: expands ? 1 : 14,
    expands: expands,
    scrollController: expands ? _editorScrollController : null,
    // The field owns detection ('/' at the start of a word); the screen owns
    // where the palette floats, and Enter picks its top match.
    onSlashQuery: (String? query) => _slash.value = query,
    onSlashSubmit: _submitSlash,
    style: context.uiText.body.copyWith(height: 1.6),
  );

  Widget _previewPane(BuildContext context, {required bool scrollable}) {
    final Widget preview = ValueListenableBuilder<String>(
      valueListenable: _preview,
      builder: (BuildContext ctx, String source, Widget? _) =>
          RichMarkdownPreview(
            data: source,
            outlineController: _outline,
            imageResolver: StrategyAttachments.resolve,
            emptyPlaceholder: 'No rules written yet — switch to Write.',
          ),
    );
    // In the narrow layout UiPage already scrolls; nesting another one would
    // fight it for the gesture.
    return scrollable
        ? SingleChildScrollView(
            padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xl)),
            child: preview,
          )
        : preview;
  }

  /// Everything that floats over the page: the AI bar, the slash palette, the
  /// mobile toolbar and the outline jump button. They sit in a [Stack] because
  /// [UiPage] has no FAB slot, and they are ordered so the toolbar is on top.
  List<Widget> _overlays(BuildContext context, {required bool wide}) {
    final UiTheme theme = context.ui;
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    final double safeBottom = MediaQuery.paddingOf(context).bottom;
    final double baseBottom = inset > 0 ? inset : safeBottom;
    final double gutter = context.sp(theme.spacing.md);
    final bool editing = _mode != StrategyEditorMode.read;
    // The mobile toolbar is docked at the bottom, so anything else that floats
    // has to clear it.
    final double toolbarClearance = wide || !editing ? 0 : context.sz(64);

    return <Widget>[
      if (_mode != StrategyEditorMode.write)
        Positioned(
          right: gutter,
          bottom: baseBottom + toolbarClearance + gutter,
          child: MarkdownOutlineFab(controller: _outline),
        ),
      if (editing)
        ValueListenableBuilder<TextSelection?>(
          valueListenable: _selection,
          builder: (BuildContext ctx, TextSelection? selection, Widget? _) {
            if (selection == null) return const SizedBox.shrink();
            return Positioned(
              left: gutter,
              right: gutter,
              bottom: baseBottom + toolbarClearance + gutter,
              child: AiRefactorBar(
                refactoring: _refactoring,
                selectedCharCount: (selection.end - selection.start).abs(),
                onQuickRefactor: () => _refactor(),
                onCustomPrompt: _customPrompt,
                onDismiss: () {
                  _selection.value = null;
                  _bodyFocus.requestFocus();
                },
              ),
            );
          },
        ),
      if (editing)
        ValueListenableBuilder<String?>(
          valueListenable: _slash,
          builder: (BuildContext ctx, String? query, Widget? _) {
            if (query == null) return const SizedBox.shrink();
            return Positioned(
              left: gutter,
              bottom: baseBottom + toolbarClearance + gutter,
              child: MarkdownSlashPalette(
                query: query,
                onSelect: _applySnippet,
                onDismiss: _dismissSlash,
              ),
            );
          },
        ),
      // Phones and small tablets get the compact scrolling toolbar pinned above
      // the keyboard; wide layouts already have the always-on ribbon.
      if (editing && !wide)
        Positioned(
          left: 0,
          right: 0,
          bottom: baseBottom + gutter,
          child: MarkdownEditorToolbar(
            editorKey: _editorKey,
            onPickImage: _pickImage,
            onPickDocument: _pickDocument,
            onToggleVoice: _toggleVoice,
            onInsertTicker: _insertTicker,
            onInsertRecord: () async {
              final ref = await showRecordLinkPicker(
                context,
                sourceKind: AppLinkKind.strategy,
                sourceId: _strategy.id,
              );
              if (ref != null && mounted) {
                _editorKey.currentState?.insertInline(
                  AppDeepLink.markdown(
                    kind: ref.kind,
                    id: ref.id,
                    label: ref.title,
                  ),
                );
              }
            },
            onInsertJournal: _insertJournal,
            listening: _listening,
          ),
        ),
    ];
  }
}
