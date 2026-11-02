import 'package:tradex/core/widgets/publication_confirmation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_limitations.dart';
// Required unified UI surfaces for feature pages.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/admin_console/data/admin_console_repository.dart';
import 'package:tradex/features/linking/record_link_picker.dart';
import 'package:tradex/core/markdown_kit/markdown_kit.dart';
import 'package:tradex/features/linking/link_graph_service.dart';
import 'package:tradex/features/notes/data/note_ai_refactor.dart';

import '../data/journal_attachments.dart';
import '../data/journal_repository.dart';

/// Which surface the trader is looking at, named for what they are doing.
enum JournalEditorMode {
  write,
  read,
  split;

  String get label => switch (this) {
    JournalEditorMode.write => 'Write',
    JournalEditorMode.read => 'Read',
    JournalEditorMode.split => 'Split',
  };

  IconData get icon => switch (this) {
    JournalEditorMode.write => Icons.edit_outlined,
    JournalEditorMode.read => Icons.menu_book_outlined,
    JournalEditorMode.split => Icons.vertical_split_rounded,
  };
}

/// The journal authoring surface: the numbers and the write-up on one screen.
///
/// This is where the journal differs from trader notes. A note is prose; a
/// journal entry is prose **plus** a trade, and the two have to be captured
/// together or the entry is worthless — prices with no reasoning are a broker
/// statement, reasoning with no prices cannot be ranked or reviewed. So the
/// fields and the markdown canvas share one page, one save and one dirty flag.
///
/// Nothing derived is typed. Result, percentage, R multiple and outcome are
/// computed from entry, exit, stop and size every time a character changes, and
/// the live panel renders them through the same block the reader uses — so what
/// the trader sees while typing is literally what the entry will look like.
class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({
    super.key,
    required this.entry,
    required this.onClose,
    this.onDeleted,
    this.detailsOnly = false,
    this.initialMode = JournalEditorMode.write,
    this.onOpenLink,
  });

  /// The entry being edited. An empty [AppTrade.id] is an unsaved draft, created
  /// on first save rather than up front, so opening the editor and backing out
  /// leaves nothing behind.
  final AppTrade entry;

  /// Back to wherever the editor was opened from, carrying the saved entry so
  /// the caller shows the fresh copy instead of the draft it handed in. Null when
  /// nothing was written.
  final ValueChanged<AppTrade?> onClose;

  /// Back to the index after the entry was deleted. Falls back to [onClose].
  final VoidCallback? onDeleted;

  final JournalEditorMode initialMode;

  /// Production record routes use focused forms; writing lives in Notes.
  final bool detailsOnly;

  /// Follows a record/ticker link tapped in the preview tab or linked notes list.
  final void Function(AppLinkRef ref)? onOpenLink;

  @override
  State<JournalEditorScreen> createState() => JournalEditorScreenState();
}

class JournalEditorScreenState extends State<JournalEditorScreen> {
  // ── The write-up ───────────────────────────────────────────────────────────
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final TextEditingController _summary = TextEditingController();

  // ── The trade ──────────────────────────────────────────────────────────────
  final TextEditingController _ticker = TextEditingController();
  final TextEditingController _entryPrice = TextEditingController();
  final TextEditingController _exitPrice = TextEditingController();
  final TextEditingController _stop = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _size = TextEditingController();

  final GlobalKey<RichMarkdownEditorFieldState> _editorKey =
      GlobalKey<RichMarkdownEditorFieldState>();
  final FocusNode _bodyFocus = FocusNode();
  final FocusNode _tickerFocus = FocusNode();
  final MarkdownOutlineController _outline = MarkdownOutlineController();
  final SpeechToText _speech = SpeechToText();
  final ScrollController _editorScrollController = ScrollController();

  /// Bumped on every edit. The command bar, the live numbers and the footer
  /// counters listen; the markdown canvas does not, so a keystroke never
  /// re-parses the document.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Debounced copy of the body, so the split preview re-parses a few times a
  /// second instead of on every character.
  final ValueNotifier<String> _preview = ValueNotifier<String>('');

  /// The live `/query`, or null when the palette is closed.
  final ValueNotifier<String?> _slash = ValueNotifier<String?>(null);

  /// The current selection, for the AI rewrite bar.
  final ValueNotifier<TextSelection?> _selection =
      ValueNotifier<TextSelection?>(null);

  late AppTrade _entry;
  late JournalEditorMode _mode;
  late AppSide _side;
  late List<String> _tags;
  late List<String> _linkedNoteIds;
  late bool _isPublic;
  late DateTime _openedAt;
  DateTime? _closedAt;
  String? _strategyId;
  int? _discipline;

  /// Whether the position is finished. Drives whether an exit is collected at
  /// all, which is what decides [AppOutcome.open] versus a real result.
  late bool _closed;

  final AppLinkGraphService _links = AppLinkGraphScope.service;
  StreamSubscription<AppLinkGraph>? _graphSub;
  late AppLinkGraph _graph = _links.current;

  Timer? _previewDebounce;
  bool _saving = false;
  bool _listening = false;
  bool _refactoring = false;
  bool _detailsOpen = false;
  String _voiceBase = '';

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _mode = widget.initialMode;
    _title.text = _entry.title;
    _body.text = _entry.content;
    _preview.value = _entry.content;
    final String entryNotes = (_entry.notes ?? '').trim();
    final String entryContent = _entry.content.trim();
    _summary.text = (entryNotes.isNotEmpty && entryNotes != entryContent)
        ? entryNotes
        : '';
    _ticker.text = _entry.ticker;
    // A zero entry price is what a template hands over, and '0' in the field
    // reads as a price somebody meant. Blank reads as "not filled in yet".
    _entryPrice.text = _entry.entry == 0 ? '' : _plain(_entry.entry);
    _exitPrice.text = _entry.exit == null ? '' : _plain(_entry.exit!);
    _stop.text = _entry.stopLoss == null ? '' : _plain(_entry.stopLoss!);
    _target.text = _entry.target == null ? '' : _plain(_entry.target!);
    _size.text = _plain(_entry.size);
    _side = _entry.side;
    _tags = List<String>.of(_entry.tags);
    _linkedNoteIds = List<String>.of(_entry.linkedNoteIds);
    _isPublic = _entry.isPublic;
    _openedAt = _entry.openedAt;
    _closedAt = _entry.closedAt;
    _strategyId = _entry.strategyId;
    _discipline = _entry.psychologyScore;
    _closed = _entry.exit != null;
    _detailsOpen = false;

    _body.addListener(_onBodyChanged);
    for (final TextEditingController c in _numericControllers) {
      c.addListener(_bumpRevision);
    }
    _title.addListener(_bumpRevision);
    _summary.addListener(_bumpRevision);
    _ticker.addListener(_bumpRevision);
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
    for (final TextEditingController c in _numericControllers) {
      c.removeListener(_bumpRevision);
    }
    _title.removeListener(_bumpRevision);
    _summary.removeListener(_bumpRevision);
    _ticker.removeListener(_bumpRevision);
    for (final TextEditingController c in <TextEditingController>[
      _title,
      _body,
      _summary,
      _ticker,
      ..._numericControllers,
    ]) {
      c.dispose();
    }
    _bodyFocus.dispose();
    _tickerFocus.dispose();
    _outline.dispose();
    _revision.dispose();
    _preview.dispose();
    _slash.dispose();
    _selection.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  List<TextEditingController> get _numericControllers =>
      <TextEditingController>[_entryPrice, _exitPrice, _stop, _target, _size];

  // ── Derivation ─────────────────────────────────────────────────────────────

  /// A price as it belongs in a field: no currency symbol, no separators, and no
  /// `.0` tail the trader would have to delete before typing.
  static String _plain(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  /// Null means the field is empty or unparseable, which is different from zero —
  /// an empty stop is "no stop", a stop of 0 is a stop at zero.
  static double? _parse(TextEditingController controller) {
    final String raw = controller.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double get _entryValue => _parse(_entryPrice) ?? 0;

  /// Only read when the position is marked closed, so unticking the switch
  /// reopens the trade without the trader having to clear the field.
  double? get _exitValue => _closed ? _parse(_exitPrice) : null;

  double get _sizeValue {
    final double? typed = _parse(_size);
    return typed == null || typed <= 0 ? 1 : typed;
  }

  /// The entry as it would be saved right now.
  ///
  /// Built field by field rather than through `copyWith` on purpose: `copyWith`
  /// cannot put a stop or an R multiple *back* to null, and clearing a stop is
  /// something a trader does. Everything the editor does not own — id, user,
  /// legacy screenshot — is carried across explicitly.
  AppTrade get _draft {
    final double entryPrice = _entryValue;
    final double? exitPrice = _exitValue;
    final double size = _sizeValue;
    final double? stop = _parse(_stop);
    // Short positions make money when price falls, so every signed number flips.
    final int direction = _side == AppSide.long ? 1 : -1;
    final double pnl = exitPrice == null
        ? 0
        : (exitPrice - entryPrice) * size * direction;
    final double pnlPercent = exitPrice == null || entryPrice == 0
        ? 0
        : ((exitPrice - entryPrice) / entryPrice) * 100 * direction;
    final double? riskPerUnit = stop == null ? null : (entryPrice - stop).abs();
    // R is the only number that says whether a win was earned or lucky, and it
    // needs a stop. No stop, no R — inventing one would flatter the record.
    final double? rMultiple =
        exitPrice == null || riskPerUnit == null || riskPerUnit == 0
        ? null
        : pnl / (riskPerUnit * size);

    return AppTrade(
      id: _entry.id,
      ticker: _ticker.text.trim().toUpperCase(),
      side: _side,
      entry: entryPrice,
      exit: exitPrice,
      openedAt: _openedAt,
      closedAt: exitPrice == null ? null : (_closedAt ?? _openedAt),
      stopLoss: stop,
      target: _parse(_target),
      size: size,
      pnl: pnl,
      pnlPercent: pnlPercent,
      rMultiple: rMultiple,
      outcome: _outcomeOf(pnl: pnl, exit: exitPrice),
      strategy: _strategyNameFor(_strategyId),
      tags: _tags,
      notes: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
      screenshotUrl: _entry.screenshotUrl,
      psychologyScore: _discipline,
      userId: _entry.userId,
      title: _title.text.trim(),
      content: _body.text,
      strategyId: _strategyId,
      linkedNoteIds: _linkedNoteIds,
      isPublic: _isPublic,
      updatedAt: _entry.updatedAt,
    ).withDerivedCounts();
  }

  /// Never chosen by hand. A trader picking "win" on a losing trade is exactly
  /// the self-deception a journal exists to remove.
  static AppOutcome _outcomeOf({required double pnl, required double? exit}) {
    if (exit == null) return AppOutcome.open;
    if (pnl > 0) return AppOutcome.win;
    if (pnl < 0) return AppOutcome.loss;
    return AppOutcome.breakeven;
  }

  /// The playbook name denormalised onto the entry, so a list row can print it
  /// without walking the graph. Resolved off the graph rather than a repository
  /// so the editor keeps one source of truth for links.
  String? _strategyNameFor(String? id) =>
      id == null || id.isEmpty ? null : _graph.strategy(id)?.name;

  // ── Change tracking ────────────────────────────────────────────────────────

  void _bumpRevision() => _revision.value++;

  /// The body drives two things at different rates: the counters and command bar
  /// every keystroke, the parsed preview a few times a second.
  void _onBodyChanged() {
    _bumpRevision();
    // A live selection is what the AI bar hangs off, and the controller is the
    // only place it is reported.
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

  /// Whether anything the editor owns differs from what is stored. Drives the
  /// save button and the silent save on the way out.
  bool get _dirty {
    final AppTrade draft = _draft;
    return draft.ticker != _entry.ticker ||
        draft.side != _entry.side ||
        draft.entry != _entry.entry ||
        draft.exit != _entry.exit ||
        draft.stopLoss != _entry.stopLoss ||
        draft.target != _entry.target ||
        draft.size != _entry.size ||
        draft.openedAt != _entry.openedAt ||
        draft.closedAt != _entry.closedAt ||
        draft.title != _entry.title ||
        draft.content != _entry.content ||
        draft.notes != _entry.notes ||
        draft.strategyId != _entry.strategyId ||
        draft.psychologyScore != _entry.psychologyScore ||
        !listEquals(draft.tags, _entry.tags) ||
        !listEquals(draft.linkedNoteIds, _entry.linkedNoteIds);
  }

  /// Nothing worth keeping. Backing out of an untouched draft leaves no record.
  bool get _isBlank =>
      _ticker.text.trim().isEmpty &&
      _title.text.trim().isEmpty &&
      _body.text.trim().isEmpty &&
      _parse(_entryPrice) == null;

  // ── Saving ─────────────────────────────────────────────────────────────────

  /// Gaps worth flagging but not worth refusing a save over. An open position
  /// legitimately has no exit; a price the trader has not looked up yet is a
  /// half-finished entry, not a broken one, and blocking the save would lose the
  /// paragraph they just wrote.
  List<String> get _gaps => <String>[
    if (_parse(_entryPrice) == null) 'entry price',
    if (_closed && _parse(_exitPrice) == null) 'exit price',
    if (_parse(_stop) == null) 'stop',
    if (_body.text.trim().isEmpty) 'write-up',
  ];

  /// Persists the draft and returns the stored entry, or null if nothing was
  /// written or the write failed.
  ///
  /// The one hard requirement is an instrument: the journal is filed by ticker,
  /// and an entry without one cannot be found again or grouped with its siblings.
  Future<AppTrade?> _save({bool silent = false}) async {
    if (_saving) return null;
    if (_ticker.text.trim().isEmpty) {
      if (!silent && mounted) {
        UiToast.info(
          context,
          title: 'Which instrument?',
          message:
              'A journal entry is filed under its ticker. Add one to save.',
        );
        _tickerFocus.requestFocus();
      }
      return null;
    }
    final AppTrade before = _entry;
    final AppTrade draft = _draft;
    if (!silent && draft.entry > 0 && draft.size > 0) {
      final CustomerLimitEvaluation eval =
          await CustomerLimitations.evaluateTradeRisk(
            symbol: draft.ticker,
            entryPrice: draft.entry,
            quantity: draft.size,
            stopLoss: draft.stopLoss,
          );
      if (!mounted) return null;
      if (eval.isCircuitBreakerHalted) {
        UiToast.error(
          context,
          title: eval.title ?? 'Desk Execution Halted',
          message: eval.message ?? 'New trades are temporarily halted.',
        );
        return null;
      }
      if (eval.exceedsPositionCap) {
        final risk = await AdminConsoleRepository.instance.getDeskRiskConfig();
        await AdminConsoleRepository.instance.recordRiskBreach(
          symbol: draft.ticker,
          breachType: 'Position Size Cap Breach',
          metricValueInr: draft.entry * draft.size,
          thresholdValueInr: risk.maxPositionPerTrader,
          description: eval.message ?? 'Order notional exceeded position cap.',
          severity: 'critical',
        );
        if (!mounted) return null;
        UiToast.error(
          context,
          title: eval.title ?? 'Position Cap Breach',
          message:
              '${eval.message ?? ''} Logged to Admin Risk & Compliance incident queue.',
        );
        return null;
      }
      if (eval.requiresManagerApproval) {
        await AdminConsoleRepository.instance.submitOrderForApproval(
          symbol: draft.ticker,
          side: draft.side == AppSide.long ? 'BUY' : 'SELL',
          quantity: draft.size.round().clamp(1, 1000000),
          orderPriceInr: draft.entry,
          notionalValueInr: draft.entry * draft.size,
          stopLossInr: draft.stopLoss ?? 0,
          targetPriceInr: draft.target ?? 0,
          strategyName: draft.strategy ?? 'Discretionary Setup',
          reasonFlagged: eval.message ?? 'Exceeds approval threshold',
        );
        if (mounted) {
          UiToast.info(
            context,
            title: eval.title ?? 'Queued for Desk Approval',
            message:
                eval.message ?? 'Order sent to Admin Pre-Trade Approval Queue.',
          );
        }
      }
    }
    setState(() => _saving = true);
    try {
      final JournalRepository repo = JournalRepositoryScope.repository;
      AppTrade saved = draft.id.isEmpty
          ? await repo.create(draft)
          : await repo.update(draft);
      saved = await _reconcileLinks(saved, before: before);
      if (!mounted) return saved;
      setState(() {
        _entry = saved;
        _saving = false;
      });
      if (!silent) UiToast.success(context, title: 'Entry saved');
      return saved;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _saving = false);
      UiToast.error(
        context,
        title: 'Could not save the entry',
        message: '$error',
      );
      return null;
    }
  }

  /// Writes the far end of every link the trader changed, then re-reads the
  /// entry.
  ///
  /// The journal row already carries `linkedNoteIds` and `strategyId` — the save
  /// above persisted them. What is missing is the other side: the note's
  /// `linkedJournalIds` and the playbook's. That work happens after the save
  /// rather than before it because [AppLinkGraphService] resolves a journal id
  /// against the store, and a draft has no id to resolve.
  Future<AppTrade> _reconcileLinks(
    AppTrade saved, {
    required AppTrade before,
  }) async {
    // A draft's far ends cannot already exist, so every current link is new.
    final bool fresh = before.id.isEmpty;
    final Set<String> was = fresh
        ? const <String>{}
        : before.linkedNoteIds.toSet();
    final Set<String> now = saved.linkedNoteIds.toSet();
    final String? wasStrategy = fresh ? null : before.strategyId;
    bool complete = true;

    Future<void> edge(Future<void> Function() write) async {
      try {
        await write();
      } catch (_) {
        // The entry itself is saved; a half-written edge is a display problem,
        // not lost work. Reported once, below.
        complete = false;
      }
    }

    for (final String id in now.difference(was)) {
      await edge(
        () => _links.link(
          fromKind: AppLinkKind.journal,
          fromId: saved.id,
          toKind: AppLinkKind.note,
          toId: id,
        ),
      );
    }
    for (final String id in was.difference(now)) {
      await edge(
        () => _links.unlink(
          fromKind: AppLinkKind.journal,
          fromId: saved.id,
          toKind: AppLinkKind.note,
          toId: id,
        ),
      );
    }
    if (wasStrategy != _strategyId) {
      if (wasStrategy != null && wasStrategy.isNotEmpty) {
        await edge(
          () => _links.unlink(
            fromKind: AppLinkKind.journal,
            fromId: saved.id,
            toKind: AppLinkKind.strategy,
            toId: wasStrategy,
          ),
        );
      }
      final String? next = _strategyId;
      if (next != null && next.isNotEmpty) {
        await edge(
          () => _links.link(
            fromKind: AppLinkKind.journal,
            fromId: saved.id,
            toKind: AppLinkKind.strategy,
            toId: next,
          ),
        );
      }
    }
    if (!complete && mounted) {
      UiToast.warning(
        context,
        title: 'Entry saved',
        message: 'Some links did not update. Reopen the entry to retry.',
      );
    }
    // The service mutates the entry as it writes both ends, so the copy returned
    // by the save above is already stale.
    return await JournalRepositoryScope.repository.getById(saved.id) ?? saved;
  }

  /// Leave the editor from outside — the shell's app-bar back button on a phone,
  /// where the host drew the chrome and this screen did not. Routed through the
  /// same path as the editor's own back button so both behave identically.
  Future<void> close() => _closeAndSave();

  /// Leaving the editor saves silently. Losing a trade review because a back
  /// gesture was read as "discard" is the worst thing this screen could do, and
  /// an unwanted save is one tap away from being deleted.
  ///
  /// The one case that cannot save is an entry with no instrument, and that is
  /// worth a dialog rather than a silent drop — the trader has written prose by
  /// then, and only they can say which symbol it belongs to.
  Future<void> _closeAndSave() async {
    if (_isBlank) {
      widget.onClose(_entry.id.isEmpty ? null : _entry);
      return;
    }
    if (_ticker.text.trim().isEmpty) {
      final bool discard = await UiDialog.confirm(
        context,
        title: 'This entry has no instrument',
        description:
            'The journal is filed by ticker, so an entry needs one before it '
            'can be saved. Discard what you have written?',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        confirmVariant: UiVariant.destructive,
      );
      if (!mounted) return;
      if (!discard) {
        _tickerFocus.requestFocus();
        return;
      }
      widget.onClose(_entry.id.isEmpty ? null : _entry);
      return;
    }
    if (_saving) return;
    final needsSave =
        _dirty ||
        (widget.detailsOnly &&
            _entry.id.isEmpty &&
            _ticker.text.trim().isNotEmpty &&
            _entryValue > 0);
    final AppTrade? saved = needsSave
        ? await _save(silent: !widget.detailsOnly)
        : (_entry.id.isEmpty ? null : _entry);
    if (needsSave && saved == null) return;
    if (mounted) widget.onClose(saved);
  }

  Future<void> _delete() async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete this entry?',
      description:
          'The trade, the write-up and every link to it go away. This cannot '
          'be undone.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    try {
      if (_entry.id.isNotEmpty) {
        await JournalRepositoryScope.repository.delete(_entry.id);
      }
      if (!mounted) return;
      UiToast.success(context, title: 'Entry deleted');
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

  void _setMode(JournalEditorMode next) {
    // The preview is debounced, so entering a mode that shows it has to pull the
    // current text across immediately or the first frame renders stale markdown.
    _previewDebounce?.cancel();
    _preview.value = _body.text;
    setState(() => _mode = next);
    if (next == JournalEditorMode.write || next == JournalEditorMode.split) {
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

  /// References another instrument inside the write-up — "led the sector", "the
  /// index was weak". The trade's own symbol is the ticker field, not this.
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
    // An empty ticker field means "not filled in yet", and the trader has just
    // named a symbol. Adopting it saves a retype; a filled field is left alone.
    if (_ticker.text.trim().isEmpty) _ticker.text = symbol;
  }

  Future<void> _insertStrategy() async {
    final String? id = await _pickOne(
      title: 'Reference a playbook',
      hint: 'Search playbooks',
      options: <UiOption<String>>[
        for (final AppStrategy s in _graph.strategyList)
          UiOption<String>(
            value: s.id,
            label: s.name,
            description: s.category,
            trailingLabel: '${s.trades} trades',
          ),
      ],
    );
    if (id == null || !mounted) return;
    _editorKey.currentState?.insertInline(
      '${AppDeepLink.markdown(kind: AppLinkKind.strategy, id: id, label: 'Playbook: ${_strategyNameFor(id) ?? 'strategy'}')} ',
    );
    // Same rule as the ticker: naming a playbook in the body is a statement about
    // which plan the trade came from, so an unfiled entry adopts it.
    if (_strategyId == null || _strategyId!.isEmpty) {
      setState(() => _strategyId = id);
    }
  }

  // ── Links ──────────────────────────────────────────────────────────────────

  /// Files the entry under a playbook, or clears it.
  ///
  /// Held in local state until the save. The far end — the playbook's own list of
  /// entries — is written by [_reconcileLinks], because a draft has no id for the
  /// link service to resolve.
  Future<void> _pickStrategy() async {
    final String? id = await _pickOne(
      title: 'File under a playbook',
      hint: 'Search playbooks',
      options: <UiOption<String>>[
        const UiOption<String>(
          value: '',
          label: 'No playbook',
          description: 'Leave the entry unfiled',
        ),
        for (final AppStrategy s in _graph.strategyList)
          UiOption<String>(
            value: s.id,
            label: s.name,
            description: s.category,
            trailingLabel: '${s.trades} trades',
          ),
      ],
    );
    if (id == null || !mounted) return;
    setState(() => _strategyId = id.isEmpty ? null : id);
  }

  /// Attaches trader notes — the thesis written before the trade, the review
  /// written after it. Multi-select, because a trade usually has both.
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

  void _unlinkNote(String id) => setState(
    () => _linkedNoteIds = _linkedNoteIds
        .where((String linked) => linked != id)
        .toList(growable: false),
  );

  // ── AI, attachments, dictation ─────────────────────────────────────────────

  /// Rewrites the selection. A journal entry *is* a trade review, so the service
  /// is asked for review prose rather than the general note voice.
  Future<void> _refactor({String? instruction}) async {
    final TextSelection? selection = _selection.value;
    if (selection == null || _refactoring) return;
    final String selected = selection.textInside(_body.text);
    if (selected.trim().isEmpty) return;

    setState(() => _refactoring = true);
    try {
      final String enhanced = await NoteAiScope.service.enhance(
        selectedText: selected,
        noteType: AppNoteType.review,
        contextTitle: _draft.displayTitle,
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

  /// A marked-up chart is half of what a review is worth, so the gallery is the
  /// journal's most-used attachment path.
  Future<void> _pickImage() async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      await _attachBytes(bytes, filename: picked.name);
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
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final PlatformFile pickedFile = result.files.first;
      final String name = pickedFile.name;
      Uint8List? bytes = pickedFile.bytes;
      if (bytes == null && !kIsWeb) {
        final String? filePath = pickedFile.path;
        if (filePath != null) {
          bytes = await File(filePath).readAsBytes();
        }
      }
      if (bytes == null) {
        throw StateError('Could not read file data.');
      }
      final String ext = p.extension(name).toLowerCase();
      if (ext == '.md' || ext == '.txt') {
        final String text = utf8.decode(bytes);
        if (!mounted) return;
        _editorKey.currentState?.insertBlock('$text\n');
        UiToast.success(context, title: 'Imported $name');
        return;
      }
      await _attachBytes(bytes, filename: name);
      if (ext == '.pdf' && mounted) {
        UiToast.info(
          context,
          title: 'PDF attached as a link',
          message: 'Its text is not pulled into the entry.',
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

  /// Attachments belong to a saved entry, so a draft is written first —
  /// otherwise the file would be stored against an id that does not exist yet,
  /// and the journal's bucket is keyed by entry.
  Future<void> _attachBytes(Uint8List bytes, {required String filename}) async {
    final AppTrade? owner = _entry.id.isEmpty
        ? await _save(silent: true)
        : _entry;
    if (!mounted) return;
    if (owner == null) {
      UiToast.info(
        context,
        title: 'Add an instrument first',
        message: 'Attachments are stored against a saved entry.',
      );
      return;
    }
    try {
      final String markdown = await JournalAttachments.attachBytes(
        entryId: owner.id,
        bytes: bytes,
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
          message: 'Check the microphone permission for alphajournal.',
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

  /// One line under the title: what the trade did, how much has been written, and
  /// whether it is safe to walk away.
  String get _statusLine {
    final AppTrade draft = _draft;
    final int words = draft.wordCount;
    final double? r = draft.rMultiple;
    final String state = _saving
        ? 'Saving…'
        : _dirty
        ? 'Unsaved changes'
        : _entry.id.isEmpty
        ? 'Not saved yet'
        : 'Saved';
    return <String>[
      draft.isOpen ? 'Open position' : AppTokens.outcomeLabel(draft.outcome),
      if (!draft.isOpen) AppTokens.signedMoney(draft.pnl),
      if (r != null) AppTokens.rr(r),
      '$words ${words == 1 ? 'word' : 'words'}',
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
                title: 'Trade details',
                description:
                    'Execution, risk and classification. Write the review from Notes.',
                saving: _saving,
                onBack: _closeAndSave,
                onSave: () async {
                  final saved = await _save();
                  if (saved != null && mounted) widget.onClose(saved);
                },
                onDelete: _entry.id.isEmpty ? null : _delete,
                fields: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleField(context),
                    const UiGap.v(16),
                    _tradeFields(
                      context,
                      twoColumn: constraints.maxWidth >= context.sz(580),
                    ),
                    const UiGap.v(16),
                    _liveNumbers(context),
                  ],
                ),
              ),
            );
          }

          // The trade rail and the split preview need real working room. Tablets use
          // the same scrollable composition as phones instead of squeezing three
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

  /// Back, the mode switch, delete and save — everything that is true of the
  /// whole screen. Wrapped in the revision listener so the save button enables
  /// itself as soon as a character lands anywhere.
  Widget _commandBar(BuildContext context, {required bool wide}) {
    final UiTheme theme = context.ui;
    return ValueListenableBuilder<int>(
      valueListenable: _revision,
      builder: (BuildContext ctx, int _, Widget? _) {
        final bool isMobile = context.uiRes.isMobile;
        final Widget? back = isMobile
            ? null
            : UiIconButton(
                icon: Icons.arrow_back_rounded,
                variant: UiVariant.ghost,
                tooltip: 'Back to the journal',
                onPressed: _closeAndSave,
              );
        final Widget modes = UiToggleGroup<JournalEditorMode>(
          options: <UiToggleOption<JournalEditorMode>>[
            for (final JournalEditorMode mode in JournalEditorMode.values)
              if (mode != JournalEditorMode.split || wide)
                UiToggleOption<JournalEditorMode>(
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
        final Widget remove = UiIconButton(
          icon: Icons.delete_outline_rounded,
          variant: UiVariant.ghost,
          tooltip: 'Delete entry',
          onPressed: _delete,
        );
        final Widget save = UiButton(
          label: 'Save',
          leadingIcon: Icons.check_rounded,
          size: UiSize.sm,
          loading: _saving,
          loadingLabel: 'Saving',
          expandOnMobile: false,
          onPressed: _saving || (!_dirty && _entry.id.isNotEmpty)
              ? null
              : () => _save(),
        );
        final Widget identity = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMobile)
                Text(
                  _draft.displayTitle,
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
                  remove,
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
            remove,
            SizedBox(width: context.sp(theme.spacing.xs)),
            save,
          ],
        );
      },
    );
  }

  /// Phones get one column and a collapsible trade panel: the write-up is what
  /// the screen is for, and the numbers are eight short fields behind one tap.
  /// The panel opens itself while the trade is still incomplete.
  Widget _narrowBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _titleField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _tradePanel(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        if (_mode == JournalEditorMode.read)
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

  /// Desktop keeps one focused column. Trade details are available in the same
  /// collapsible panel used on smaller screens, never in a permanent sidebar.
  Widget _wideBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _titleField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _tradePanel(context),
        if (_mode != JournalEditorMode.read) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          MarkdownFormatRibbon(
            editorKey: _editorKey,
            onPickImage: _pickImage,
            onPickDocument: _pickDocument,
            onInsertTicker: _insertTicker,
            onInsertRecord: () async {
              final ref = await showRecordLinkPicker(
                context,
                sourceKind: AppLinkKind.journal,
                sourceId: _entry.id,
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
            onInsertStrategy: _insertStrategy,
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
    JournalEditorMode.write => _pane(
      context,
      label: 'Writing canvas',
      icon: Icons.edit_note_rounded,
      expands: true,
      scrollbarController: _editorScrollController,
      child: _editorPane(context, expands: true),
    ),
    JournalEditorMode.read => _pane(
      context,
      label: 'Reading preview',
      icon: Icons.menu_book_outlined,
      expands: true,
      child: _previewPane(context, scrollable: true),
    ),
    JournalEditorMode.split => UiSplitPane(
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

  /// Deliberately chrome-less: it should read as the top line of the document,
  /// not as a form field above it. The hint shows the name the journal will
  /// derive — `RELIANCE Long` — so leaving it blank is an informed choice.
  Widget _titleField(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (BuildContext ctx, int _, Widget? _) {
      final String symbol = _ticker.text.trim().toUpperCase();
      return UiInput(
        controller: _title,
        hintText: symbol.isEmpty
            ? 'Name this entry'
            : '$symbol ${AppTokens.sideLabel(_side)}',
        variant: UiInputVariant.ghost,
        size: UiSize.lg,
        readOnly: _mode == JournalEditorMode.read,
        textInputAction: TextInputAction.next,
      );
    },
  );

  /// The phone panel. Collapsed once the trade is filled in, because the reason
  /// somebody opens this screen on a phone is to write, and open while anything
  /// is still missing, because a half-entered trade cannot be reviewed.
  Widget _tradePanel(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (BuildContext ctx, int _, Widget? _) => UiAccordion(
      variant: UiAccordionVariant.contained,
      openIndices: _detailsOpen ? const <int>{0} : const <int>{},
      onChanged: (Set<int> open) =>
          setState(() => _detailsOpen = open.contains(0)),
      items: <UiAccordionItem>[
        UiAccordionItem(
          title: 'The trade',
          subtitle: _tradeSummary,
          leadingIcon: Icons.candlestick_chart_outlined,
          intent: _gaps.isEmpty ? UiIntent.success : UiIntent.warning,
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: ctx.sz(320)),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _tradeFields(ctx, twoColumn: true),
                  SizedBox(height: ctx.sp(ctx.ui.spacing.md)),
                  _liveNumbers(ctx),
                  SizedBox(height: ctx.sp(ctx.ui.spacing.sm)),
                  CustomerTradeRiskBanner(
                    symbol: _ticker.text.trim(),
                    entryPrice: _parse(_entryPrice),
                    quantity: _parse(_size),
                    stopLoss: _parse(_stop),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// The one-line version for the collapsed phone panel.
  String get _tradeSummary {
    final String symbol = _ticker.text.trim().toUpperCase();
    if (symbol.isEmpty) return 'No instrument yet';
    final AppTrade draft = _draft;
    final double? exit = draft.exit;
    final double? r = draft.rMultiple;
    return <String>[
      '$symbol ${AppTokens.sideLabel(draft.side)}',
      exit == null
          ? '${AppTokens.price(draft.entry)} · open'
          : '${AppTokens.price(draft.entry)} → ${AppTokens.price(exit)}',
      '${AppTokens.count(draft.size)} units',
      if (r != null) AppTokens.rr(r),
    ].join(' · ');
  }

  /// The result, the percentage and the R multiple as they stand — rendered
  /// through the same block the reader uses, fed the draft. What the trader sees
  /// while typing is literally what the saved entry will look like.
  Widget _liveNumbers(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: _revision,
    builder: (BuildContext ctx, int _, Widget? _) {
      final List<String> gaps = _gaps;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: UiBadge(
              label: 'Live numbers',
              icon: Icons.functions_rounded,
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
            ),
          ),
          SizedBox(height: ctx.sp(ctx.ui.spacing.sm)),
          AppJournalNoteMetrics(entry: _draft, card: false),
          if (gaps.isNotEmpty) ...<Widget>[
            SizedBox(height: ctx.sp(ctx.ui.spacing.sm)),
            UiCallout(
              title: 'Still to fill in',
              message:
                  '${gaps.join(', ')}. The entry saves without them — the '
                  'numbers just stay incomplete until they are there.',
              intent: UiIntent.warning,
              icon: Icons.pending_outlined,
            ),
          ],
        ],
      );
    },
  );

  /// The eight things a trader actually types. [twoColumn] pairs them side by
  /// side — true on phones, where the screen is wider than the desktop rail.
  Widget _tradeFields(BuildContext context, {required bool twoColumn}) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);
    final bool reading = _mode == JournalEditorMode.read;

    Widget pair(Widget first, Widget second) => twoColumn
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: first),
              SizedBox(width: gap),
              Expanded(child: second),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              first,
              SizedBox(height: gap),
              second,
            ],
          );

    final Widget instrument = UiField(
      label: 'Instrument',
      required: true,
      child: UiInput(
        controller: _ticker,
        focusNode: _tickerFocus,
        hintText: 'RELIANCE',
        readOnly: reading,
        trailingIcon: Icons.search_rounded,
        onTrailingTap: reading ? null : _pickSymbol,
        textInputAction: TextInputAction.next,
      ),
    );

    final Widget side = UiField(
      label: 'Direction',
      child: UiToggleGroup<AppSide>(
        options: <UiToggleOption<AppSide>>[
          for (final AppSide value in AppSide.values)
            UiToggleOption<AppSide>(
              value: value,
              label: AppTokens.sideLabel(value),
              icon: value == AppSide.long
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              intent: value == AppSide.long
                  ? UiIntent.bullish
                  : UiIntent.bearish,
            ),
        ],
        value: _side,
        onChanged: (AppSide value) => setState(() => _side = value),
        size: UiSize.sm,
        expand: true,
        allowEmpty: false,
        enabled: !reading,
      ),
    );

    final Widget closedSwitch = UiSwitch(
      value: _closed,
      label: 'Position closed',
      description: _closed
          ? 'Result, percentage and R are computed from the exit'
          : 'An open position has no result yet — only an unrealised number',
      enabled: !reading,
      onChanged: (bool value) => setState(() {
        _closed = value;
        // Marking a trade closed without a date would leave "held" unanswerable,
        // so today stands in until the trader says otherwise.
        if (value) _closedAt ??= DateTime.now();
      }),
    );

    final Widget opened = UiField(
      label: 'Opened',
      child: UiDatePicker(
        value: _openedAt,
        enabled: !reading,
        lastDate: DateTime.now(),
        onChanged: (DateTime date) => setState(() => _openedAt = date),
      ),
    );

    final Widget closedOn = UiField(
      label: 'Closed',
      child: UiDatePicker(
        value: _closedAt,
        enabled: !reading && _closed,
        firstDate: _openedAt,
        lastDate: DateTime.now(),
        onChanged: (DateTime date) => setState(() => _closedAt = date),
      ),
    );

    final Widget discipline = UiField(
      label: 'Discipline',
      helper: 'How well the plan was followed, not how the trade went',
      child: UiSlider(
        value: (_discipline ?? 0).toDouble(),
        min: 0,
        max: 10,
        divisions: 10,
        enabled: !reading,
        valueFormatter: (num value) =>
            value == 0 ? 'Not rated' : '${value.round()}/10',
        onChanged: (double value) =>
            setState(() => _discipline = value == 0 ? null : value.round()),
      ),
    );

    final Widget takeaway = UiField(
      label: 'Takeaway',
      helper:
          'The one sentence worth re-reading before the next trade like this',
      child: UiInput(
        controller: _summary,
        hintText: 'Waited for the retest instead of chasing the break',
        readOnly: reading,
        maxLines: 3,
        minLines: 2,
      ),
    );

    final Widget playbook = UiField(
      label: 'Playbook',
      helper: 'Which plan this trade came from',
      child: UiButton(
        label: _strategyNameFor(_strategyId) ?? 'File under a playbook',
        leadingIcon: Icons.auto_awesome_mosaic_outlined,
        trailingIcon: _strategyId == null
            ? Icons.add_rounded
            : Icons.swap_horiz_rounded,
        variant: UiVariant.outline,
        size: UiSize.sm,
        expand: true,
        onPressed: reading ? null : _pickStrategy,
      ),
    );

    final Widget tags = UiField(
      label: 'Tags',
      helper: 'Group entries that share a mistake or a setup',
      child: UiTagInput(
        tags: _tags,
        prefix: '#',
        suggestions: JournalQuery.tagsOf(
          _graph.journalList,
        ).take(8).toList(growable: false),
        onChanged: (List<String> next) => setState(() => _tags = next),
      ),
    );

    final List<AppLinkRef> linkedNotes = <AppLinkRef>[
      for (final String id in _linkedNoteIds)
        _graph.refFor(AppLinkKind.note, id),
    ];
    final Widget notes = UiField(
      label: 'Trader notes',
      helper: 'The thesis written before, the review written after',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiButton(
            label: 'Link a note',
            leadingIcon: Icons.add_link_rounded,
            variant: UiVariant.outline,
            size: UiSize.sm,
            expand: true,
            onPressed: reading ? null : _pickNotes,
          ),
          for (final AppLinkRef ref in linkedNotes) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            AppLinkRefTile(
              ref: ref,
              dense: true,
              onTap: widget.onOpenLink == null
                  ? null
                  : () => widget.onOpenLink!(ref),
              onRemove: reading ? null : () => _unlinkNote(ref.id),
            ),
          ],
        ],
      ),
    );

    final Widget visibility = UiSwitch(
      value: _isPublic,
      label: 'Public journal entry',
      description: _isPublic
          ? 'This entry can be attached to a public post'
          : 'Only you can read this entry',
      enabled: !reading,
      onChanged: (bool value) async {
        if (value &&
            !await confirmRecordPublication(context, 'trade journal')) {
          return;
        }
        if (mounted) setState(() => _isPublic = value);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        pair(instrument, side),
        SizedBox(height: gap),
        pair(
          _numberField(label: 'Entry', controller: _entryPrice, hint: '0.00'),
          _numberField(
            label: 'Size',
            controller: _size,
            hint: '1',
            helper: 'Quantity, lots or contracts',
          ),
        ),
        SizedBox(height: gap),
        pair(
          _numberField(
            label: 'Stop',
            controller: _stop,
            hint: 'None',
            helper: 'Sets the risk — no stop, no R multiple',
          ),
          _numberField(label: 'Target', controller: _target, hint: 'None'),
        ),
        SizedBox(height: gap),
        closedSwitch,
        SizedBox(height: gap),
        if (_closed) ...<Widget>[
          pair(
            _numberField(label: 'Exit', controller: _exitPrice, hint: '0.00'),
            closedOn,
          ),
          SizedBox(height: gap),
        ],
        opened,
        SizedBox(height: gap),
        discipline,
        SizedBox(height: gap),
        takeaway,
        SizedBox(height: gap),
        playbook,
        SizedBox(height: gap),
        tags,
        SizedBox(height: gap),
        notes,
        SizedBox(height: gap),
        visibility,
        if (_isPublic) ...<Widget>[
          SizedBox(height: gap),
          UiCallout(
            title: 'Only this entry becomes public',
            message:
                'Linked notes and strategies keep their own visibility. '
                'A future social post can reference this entry without '
                'publishing the rest of your Writing Desk.',
            intent: UiIntent.info,
            icon: Icons.public_rounded,
          ),
        ],
      ],
    );
  }

  /// Prices and sizes: a decimal keypad, digits and one dot only, right-aligned
  /// so decimal points line up down the rail.
  Widget _numberField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? helper,
  }) => UiField(
    label: label,
    helper: helper,
    child: UiInput(
      controller: controller,
      hintText: hint ?? '0',
      readOnly: _mode == JournalEditorMode.read,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      textAlign: TextAlign.end,
    ),
  );

  Future<void> _pickSymbol() async {
    final String? symbol = await _pickOne(
      title: 'Which instrument?',
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
    _ticker.text = symbol;
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

  /// No card frame: the write-up is the page. The numbers live in the rail, so
  /// the hint points at what only the trader can supply — why.
  Widget _editorPane(
    BuildContext context, {
    required bool expands,
  }) => RichMarkdownEditorField(
    key: _editorKey,
    controller: _body,
    focusNode: _bodyFocus,
    autofocus: _entry.id.isEmpty && _body.text.isEmpty,
    hintText:
        'What was the setup, and what did you actually do? '
        'Type / for headings, checklists and blocks.',
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
            imageResolver: JournalAttachments.resolve,
            emptyPlaceholder: 'Nothing to read yet — switch to Write.',
            onOpenRef: widget.onOpenLink,
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
    // The host Scaffold already removes the keyboard from our constraints.
    final double baseBottom = inset > 0 ? 0 : safeBottom;
    final double gutter = context.sp(theme.spacing.md);
    final bool editing = _mode != JournalEditorMode.read;
    // The mobile toolbar is docked at the bottom, so anything else that floats
    // has to clear it.
    final double toolbarClearance = wide || !editing ? 0 : context.sz(64);

    return <Widget>[
      if (_mode != JournalEditorMode.write)
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
                sourceKind: AppLinkKind.journal,
                sourceId: _entry.id,
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
            onInsertStrategy: _insertStrategy,
            listening: _listening,
          ),
        ),
    ];
  }
}
