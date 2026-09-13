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

import '../data/record_writing_repository.dart';
import '../data/note_ai_refactor.dart';
import '../data/note_attachments.dart';
import '../data/notes_repository.dart';

/// Which surface the writer is looking at. Named for what the writer is doing,
/// not for the widget behind it.
enum NoteEditorMode {
  write,
  read,
  split;

  String get label => switch (this) {
    NoteEditorMode.write => 'Write',
    NoteEditorMode.read => 'Read',
    NoteEditorMode.split => 'Split',
  };

  IconData get icon => switch (this) {
    NoteEditorMode.write => Icons.edit_outlined,
    NoteEditorMode.read => Icons.menu_book_outlined,
    NoteEditorMode.split => Icons.vertical_split_rounded,
  };
}

/// The note authoring surface.
///
/// Built for someone who has never written markdown: the formatting ribbon, the
/// `/` block palette, smart list continuation and the template a note starts
/// from all mean the syntax can be learned by looking at what appears, and never
/// has to be typed from memory. Everything is still plain markdown underneath,
/// so nothing here is a proprietary format.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.note,
    required this.onClose,
    this.onDeleted,
    this.sourceDocument,
    this.initialMode = NoteEditorMode.write,
    this.detailsOnly = false,
  });

  /// The note being edited. An empty [AppNote.id] means an unsaved draft, which
  /// is created on the first save rather than up front — so opening the editor
  /// and backing out leaves nothing behind.
  final AppNote note;

  /// Uses this editor to write the original review/playbook, without a note copy.
  final RecordWritingDocument? sourceDocument;

  /// Back to wherever the editor was opened from, carrying the saved note so the
  /// caller can show the fresh copy instead of the one it handed in. Null when
  /// nothing was written — an untouched draft, or a note deleted meanwhile.
  final ValueChanged<AppNote?> onClose;

  /// Back to the list after the note was deleted. Falls back to [onClose].
  final VoidCallback? onDeleted;

  final NoteEditorMode initialMode;
  final bool detailsOnly;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  final GlobalKey<RichMarkdownEditorFieldState> _editorKey =
      GlobalKey<RichMarkdownEditorFieldState>();
  final FocusNode _bodyFocus = FocusNode();
  final MarkdownOutlineController _outline = MarkdownOutlineController();
  final SpeechToText _speech = SpeechToText();
  final ScrollController _editorScrollController = ScrollController();

  /// Bumped on every edit. Only the header and the footer counters listen, so a
  /// keystroke never rebuilds the metadata panel or re-parses the preview.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Debounced copy of the body, so the split-pane preview re-parses a few times
  /// a second instead of on every character.
  final ValueNotifier<String> _preview = ValueNotifier<String>('');

  /// The live `/query`, or null when the palette is closed.
  final ValueNotifier<String?> _slash = ValueNotifier<String?>(null);

  /// The current selection, for the AI refactor bar.
  final ValueNotifier<TextSelection?> _selection =
      ValueNotifier<TextSelection?>(null);

  late AppNote _note;
  late NoteEditorMode _mode;
  late AppNoteType _type;
  late List<String> _tags;
  late List<String> _tickers;
  late List<String> _linkedJournalIds;
  late bool _isPublic;
  String? _strategyId;

  final AppLinkGraphService _links = AppLinkGraphScope.service;
  late AppLinkGraph _graph = _links.current;
  StreamSubscription<AppLinkGraph>? _graphSub;

  Timer? _previewDebounce;
  bool _saving = false;
  bool _listening = false;
  bool _refactoring = false;
  bool _detailsOpen = false;
  String _voiceBase = '';

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _mode = widget.initialMode;
    _title.text = _note.title;
    _body.text = _note.content;
    _preview.value = _note.content;
    _type = _note.noteType;
    _tags = List<String>.of(_note.tags);
    _tickers = List<String>.of(_note.linkedTickers);
    _linkedJournalIds = List<String>.of(_note.linkedJournalIds);
    _isPublic = _note.isPublic;
    _strategyId = _note.strategyId;
    // A trade filed or a playbook written while this note is open should show up
    // in the pickers without the writer closing and reopening the editor.
    _graphSub = _links.watch().listen((AppLinkGraph graph) {
      if (mounted) setState(() => _graph = graph);
    });
    // One listener covers typing, programmatic inserts from the toolbar and
    // caret moves, because all three land on the controller.
    _body.addListener(_onBodyChanged);
    _title.addListener(_bumpRevision);
  }

  @override
  void dispose() {
    _graphSub?.cancel();
    _previewDebounce?.cancel();
    if (_listening) _speech.stop();
    _body.removeListener(_onBodyChanged);
    _title.removeListener(_bumpRevision);
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    _outline.dispose();
    _revision.dispose();
    _preview.dispose();
    _slash.dispose();
    _selection.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  void _bumpRevision() => _revision.value++;

  void _onBodyChanged() {
    _bumpRevision();
    final TextSelection selection = _body.selection;
    final TextSelection? tracked = selection.isValid && !selection.isCollapsed
        ? selection
        : null;
    if (tracked != _selection.value) _selection.value = tracked;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 320), () {
      if (mounted) _preview.value = _body.text;
    });
  }

  /// Derived rather than tracked, so no edit path can forget to set a flag. A
  /// note that has never been saved counts as dirty the moment it has content.
  bool get _dirty =>
      _title.text != _note.title ||
      _body.text != _note.content ||
      _type != _note.noteType ||
      _isPublic != _note.isPublic ||
      _strategyId != _note.strategyId ||
      !listEquals(_tags, _note.tags) ||
      !listEquals(_tickers, _note.linkedTickers) ||
      !listEquals(_linkedJournalIds, _note.linkedJournalIds);

  bool get _isBlank => _title.text.trim().isEmpty && _body.text.trim().isEmpty;

  int get _wordCount => _body.text
      .split(RegExp(r'\s+'))
      .where((String w) => w.trim().isNotEmpty)
      .length;

  /// What the note is called in the list. An untitled note takes its name from
  /// its first heading or first line — the same trick Obsidian and Notes use, so
  /// nobody has to fill in a title field to stay organised.
  String get _effectiveTitle {
    final String typed = _title.text.trim();
    if (typed.isNotEmpty) return typed;
    for (final String raw in _body.text.split('\n')) {
      final String line = raw.trim();
      if (line.isEmpty) continue;
      final String stripped = line
          .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
          .replaceFirst(RegExp(r'^[-*+]\s+(\[( |x|X)\]\s*)?'), '')
          .replaceFirst(RegExp(r'^>\s*'), '')
          .trim();
      if (stripped.isEmpty) continue;
      return stripped.length <= 72 ? stripped : '${stripped.substring(0, 71)}…';
    }
    return 'Untitled note';
  }

  /// Playbooks and trades a note can be linked to, read from the workspace link
  /// graph rather than from a data source directly — the same list the journal
  /// and strategy editors pick from, so a record created in one is immediately
  /// linkable from the others.
  List<AppStrategy> get _strategies => _graph.strategyList;

  List<AppTrade> get _journalTrades => _graph.journalList;

  List<AppTrade> get _linkedJournalTrades => <AppTrade>[
    for (final String id in _linkedJournalIds)
      ..._journalTrades.where((AppTrade trade) => trade.id == id),
  ];

  String? _strategyNameFor(String? id) {
    if (id == null) return null;
    for (final AppStrategy s in _strategies) {
      if (s.id == id) return s.name;
    }
    return _note.strategyName;
  }

  /// Persists the draft and returns the stored note, or null if nothing was
  /// written or the write failed.
  Future<AppNote?> _save({bool silent = false}) async {
    if (_saving) return null;
    if (_isBlank) {
      if (!silent) {
        UiToast.info(
          context,
          title: 'Nothing to save yet',
          message: 'Give the note a title or write something first.',
        );
      }
      return null;
    }
    final AppNote draft = _note.copyWith(
      title: _effectiveTitle,
      content: _body.text,
      noteType: _type,
      tags: _tags,
      linkedTickers: _tickers,
      isPublic: _isPublic,
      strategyId: _strategyId,
      strategyName: _strategyNameFor(_strategyId),
      clearStrategy: _strategyId == null,
      linkedJournalIds: _linkedJournalIds,
    );
    setState(() => _saving = true);
    try {
      final NotesRepository repo = NotesRepositoryScope.repository;
      final AppNote saved = widget.sourceDocument != null
          ? await widget.sourceDocument!.save(draft)
          : _note.id.isEmpty
          ? await repo.create(draft)
          : await repo.update(draft);
      if (!mounted) return saved;
      setState(() {
        _note = saved;
        _saving = false;
      });
      // The title field mirrors the derived name so the next save does not read
      // as a change when nothing was typed.
      if (_title.text != saved.title) _title.text = saved.title;
      if (!silent) {
        UiToast.success(
          context,
          title: widget.sourceDocument == null
              ? 'Note saved'
              : 'Writing saved to ${widget.sourceDocument!.source.kind.label.toLowerCase()}',
        );
      }
      return saved;
    } catch (error) {
      if (!mounted) return null;
      setState(() => _saving = false);
      UiToast.error(
        context,
        title: 'Could not save the note',
        message: '$error',
      );
      return null;
    }
  }

  /// Leaving the editor saves silently. Losing a paragraph because a back
  /// gesture was read as "discard" is the worst thing a notes app can do, and an
  /// unwanted save is one tap away from being deleted.
  Future<void> _closeAndSave() async {
    if (_saving) return;
    final needsSave = _dirty && !_isBlank;
    final AppNote? saved = needsSave
        ? await _save(silent: true)
        : (_note.id.isEmpty ? null : _note);
    // A failed save must keep the draft mounted so the writer can retry.
    if (needsSave && saved == null) return;
    if (mounted) widget.onClose(saved);
  }

  Future<void> _delete() async {
    final bool confirmed = await UiDialog.confirm(
      context,
      title: 'Delete this note?',
      description:
          'The note and everything in it goes away. This cannot be '
          'undone.',
      confirmLabel: 'Delete',
      confirmVariant: UiVariant.destructive,
    );
    if (!confirmed || !mounted) return;
    try {
      if (_note.id.isNotEmpty) {
        await NotesRepositoryScope.repository.delete(_note.id);
      }
      if (!mounted) return;
      UiToast.success(context, title: 'Note deleted');
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

  void _setMode(NoteEditorMode next) {
    // The preview is debounced, so entering a mode that shows it has to pull the
    // current text across immediately or the first frame renders stale markdown.
    _previewDebounce?.cancel();
    _preview.value = _body.text;
    setState(() => _mode = next);
    if (next == NoteEditorMode.write || next == NoteEditorMode.split) {
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

  Future<void> _insertTicker() async {
    final String? symbol = await _pickOne(
      title: 'Link a ticker',
      hint: 'Search symbols',
      options: <UiOption<String>>[
        for (final AppLinkRef ref in _graph.options(AppLinkKind.ticker))
          UiOption<String>(
            value: ref.id,
            label: ref.id,
            description: ref.subtitle,
          ),
      ],
    );
    if (symbol == null || !mounted) return;
    _editorKey.currentState?.insertInline(
      '[\$$symbol](tradex://ticker/$symbol) ',
    );
    // Linking a symbol in the body is also a statement about what the note is
    // about, so it joins the note's ticker list unless it is already there.
    if (!_tickers.contains(symbol)) {
      setState(() => _tickers = <String>[..._tickers, symbol]);
    }
  }

  Future<void> _insertStrategy() async {
    final List<AppStrategy> strategies = _strategies;
    final String? id = await _pickOne(
      title: 'Link a strategy',
      hint: 'Search strategies',
      options: <UiOption<String>>[
        for (final AppStrategy s in strategies)
          UiOption<String>(
            value: s.id,
            label: s.name,
            description: s.category,
            trailingLabel: '${s.trades} trades',
          ),
      ],
    );
    if (id == null || !mounted) return;
    final String name = _strategyNameFor(id) ?? 'Strategy';
    _editorKey.currentState?.insertInline(
      '[Strategy: $name](tradex://strategy/$id) ',
    );
    if (_strategyId == null) setState(() => _strategyId = id);
  }

  Future<void> _linkJournalEntry() async {
    final List<AppTrade> available = _journalTrades
        .where((AppTrade trade) => !_linkedJournalIds.contains(trade.id))
        .toList(growable: false);
    if (available.isEmpty) {
      UiToast.info(context, title: 'Every journal entry is already linked');
      return;
    }
    final String? id = await _pickOne(
      title: 'Link a journal entry',
      hint: 'Search journal entries',
      options: <UiOption<String>>[
        for (final AppTrade trade in available)
          UiOption<String>(
            value: trade.id,
            label: '${trade.ticker} · ${AppTokens.sideLabel(trade.side)}',
            description: <String>[
              AppTokens.fullDate(trade.openedAt),
              if (trade.strategy case final String strategy) strategy,
            ].join(' · '),
            trailingLabel: AppTokens.signedMoney(trade.pnl),
          ),
      ],
    );
    if (id == null || !mounted) return;
    setState(() => _linkedJournalIds = <String>[..._linkedJournalIds, id]);
  }

  Future<void> _refactor({String? instruction}) async {
    final TextSelection? selection = _selection.value;
    if (selection == null || _refactoring) return;
    final String selected = selection.textInside(_body.text);
    if (selected.trim().isEmpty) return;

    setState(() => _refactoring = true);
    try {
      final String enhanced = await NoteAiScope.service.enhance(
        selectedText: selected,
        noteType: _type,
        contextTitle: _effectiveTitle,
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
    final String selected = selection.textInside(_body.text);
    await UiDialog.show<void>(
      context,
      maxWidth: 600,
      child: AiCustomPromptSheet(
        selectedText: selected,
        onApply: (String prompt) => _refactor(instruction: prompt),
      ),
    );
  }

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
  /// PDFs are not text-extracted — see the pubspec note on `syncfusion_flutter_pdf`.
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
          message: 'Its text is not pulled into the note.',
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

  /// Attachments belong to a saved note, so a draft is written first — otherwise
  /// the file would be uploaded against an id that does not exist yet.
  Future<void> _attach(File source, {required String filename}) async {
    final AppNote? owner = _note.id.isEmpty ? await _save(silent: true) : _note;
    if (owner == null || !mounted) return;
    try {
      final File staged = await NoteAttachments.stage(source);
      final String ref = widget.sourceDocument != null
          ? await widget.sourceDocument!.upload(staged)
          : await NotesRepositoryScope.repository.uploadAttachment(
              owner.id,
              staged,
            );
      if (!mounted) return;
      _editorKey.currentState?.insertBlock(
        NoteAttachments.markdownFor(
          ref: ref,
          filename: filename,
          isImage: NoteAttachments.isImageFile(staged.path),
        ),
      );
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

  String get _statusLine {
    final int words = _wordCount;
    final String state = _saving
        ? 'Saving…'
        : _dirty
        ? 'Unsaved changes'
        : _note.id.isEmpty
        ? 'Not saved yet'
        : 'Saved';
    return '${widget.sourceDocument == null
        ? _type.label
        : widget.sourceDocument!.source.kind == AppLinkKind.journal
        ? 'Trade review'
        : 'Strategy playbook'} · $words ${words == 1 ? 'word' : 'words'} · $state';
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
              onPopInvokedWithResult: (bool didPop, Object? _) {
                if (!didPop) _closeAndSave();
              },
              child: AppRecordDetailsForm(
                title: 'Note details',
                description:
                    'Type, tags, tickers and visibility. Write the note content from Notes.',
                saving: _saving,
                onBack: _closeAndSave,
                onSave: () async {
                  final saved = await _save();
                  if (saved != null && mounted) widget.onClose(saved);
                },
                onDelete: widget.note.id.isEmpty ? null : _delete,
                fields: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleField(context),
                    const UiGap.v(16),
                    _detailsFields(
                      context,
                      twoColumn: constraints.maxWidth >= context.sz(580),
                    ),
                  ],
                ),
              ),
            );
          }

          // The metadata rail and split preview need real working room. Tablets use
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
                      _editorCommandBar(context, wide: wide),
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

  Widget _editorCommandBar(BuildContext context, {required bool wide}) {
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
                tooltip: widget.sourceDocument == null
                    ? 'Back to notes'
                    : 'Back to source',
                onPressed: _closeAndSave,
              );
        final Widget modes = UiToggleGroup<NoteEditorMode>(
          options: <UiToggleOption<NoteEditorMode>>[
            for (final NoteEditorMode mode in NoteEditorMode.values)
              if (mode != NoteEditorMode.split || wide)
                UiToggleOption<NoteEditorMode>(
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
        final Widget remove = widget.sourceDocument != null
            ? const SizedBox.shrink()
            : UiIconButton(
                icon: Icons.delete_outline_rounded,
                variant: UiVariant.ghost,
                tooltip: 'Delete note',
                onPressed: _delete,
              );
        final Widget save = UiButton(
          label: 'Save',
          leadingIcon: Icons.check_rounded,
          size: UiSize.sm,
          loading: _saving,
          loadingLabel: 'Saving',
          expandOnMobile: false,
          onPressed: _saving || (!_dirty && _note.id.isNotEmpty)
              ? null
              : () => _save(),
        );
        final Widget identity = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!isMobile)
                Text(
                  _effectiveTitle,
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

  Widget _narrowBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _titleField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _detailsPanel(context, twoColumn: false),
        SizedBox(height: context.sp(theme.spacing.md)),
        if (_mode == NoteEditorMode.read)
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

  Widget _wideBody(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _titleField(context),
        SizedBox(height: context.sp(theme.spacing.sm)),
        _detailsPanel(context, twoColumn: true),
        if (_mode != NoteEditorMode.read) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          MarkdownFormatRibbon(
            editorKey: _editorKey,
            onPickImage: _pickImage,
            onPickDocument: _pickDocument,
            onInsertTicker: _insertTicker,
            onInsertRecord: () async {
              final ref = await showRecordLinkPicker(
                context,
                sourceKind:
                    widget.sourceDocument?.source.kind ?? AppLinkKind.note,
                sourceId: _note.id,
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
    NoteEditorMode.write => _pane(
      context,
      label: 'Writing canvas',
      icon: Icons.edit_note_rounded,
      expands: true,
      scrollbarController: _editorScrollController,
      child: _editorPane(context, expands: true),
    ),
    NoteEditorMode.read => _pane(
      context,
      label: 'Reading preview',
      icon: Icons.menu_book_outlined,
      expands: true,
      child: _previewPane(context, scrollable: true),
    ),
    NoteEditorMode.split => UiSplitPane(
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

  /// The title is deliberately chrome-less: it should read as the top line of
  /// the document, not as a form field above it.
  Widget _titleField(BuildContext context) => UiInput(
    controller: _title,
    hintText: 'Untitled note',
    variant: UiInputVariant.ghost,
    size: UiSize.lg,
    readOnly: _mode == NoteEditorMode.read,
    textInputAction: TextInputAction.next,
  );

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
    final List<Widget> children = <Widget>[
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
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// Type, strategy, tags, tickers and visibility — collapsed by default so the
  /// page opens on the writing, and reachable in one tap when it matters.
  Widget _detailsPanel(BuildContext context, {required bool twoColumn}) {
    return UiAccordion(
      variant: UiAccordionVariant.contained,
      openIndices: _detailsOpen ? const <int>{0} : const <int>{},
      onChanged: (Set<int> open) =>
          setState(() => _detailsOpen = open.contains(0)),
      items: <UiAccordionItem>[
        UiAccordionItem(
          title: widget.sourceDocument == null
              ? 'Note details'
              : 'Source record',
          subtitle: _detailsSummary,
          leadingIcon: _type.icon,
          intent: _type.intent,
          content: _detailsFields(context, twoColumn: twoColumn),
        ),
      ],
    );
  }

  Widget _detailsFields(BuildContext context, {required bool twoColumn}) {
    if (widget.sourceDocument case final source?) {
      return UiCallout(
        title: source.source.kind == AppLinkKind.journal
            ? 'Review for this trade'
            : 'Rules for this strategy',
        message:
            '${source.source.title}\nSaved to the original record. Edit numbers, instruments and classification from its details page.',
        icon: source.source.kind.icon,
      );
    }
    final UiTheme theme = context.ui;
    final List<AppStrategy> strategies = _strategies;
    final List<AppTrade> linkedTrades = _linkedJournalTrades;

    final Widget typeField = UiField(
      label: 'Type',
      child: UiSelect<AppNoteType>(
        expand: true,
        options: <UiOption<AppNoteType>>[
          for (final AppNoteType type in AppNoteType.values)
            UiOption<AppNoteType>(
              value: type,
              label: type.label,
              icon: type.icon,
            ),
        ],
        value: _type,
        onChanged: (AppNoteType type) => setState(() => _type = type),
      ),
    );

    final Widget strategyField = UiField(
      label: 'Linked strategy',
      helper: 'Keep the playbook attached to this note',
      child: UiSelect<String>(
        expand: true,
        options: <UiOption<String>>[
          const UiOption<String>(value: '', label: 'No strategy'),
          for (final AppStrategy strategy in strategies)
            UiOption<String>(
              value: strategy.id,
              label: strategy.name,
              description: strategy.category,
              trailingLabel: '${strategy.trades} trades',
            ),
        ],
        value: _strategyId ?? '',
        searchable: strategies.length > 6,
        onChanged: (String id) =>
            setState(() => _strategyId = id.isEmpty ? null : id),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (twoColumn)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: typeField),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(child: strategyField),
            ],
          )
        else ...<Widget>[
          typeField,
          SizedBox(height: context.sp(theme.spacing.sm)),
          strategyField,
        ],
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiField(
          label: 'Linked journal entries',
          helper: 'Connect the executions this note was written about',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiButton(
                label: 'Link journal entry',
                leadingIcon: Icons.add_link_rounded,
                variant: UiVariant.outline,
                size: UiSize.sm,
                expand: true,
                onPressed: _linkJournalEntry,
              ),
              if (linkedTrades.isNotEmpty) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.sm)),
                for (
                  int index = 0;
                  index < linkedTrades.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) SizedBox(height: context.sp(theme.spacing.xs)),
                  AppLinkedJournalCard(
                    trade: linkedTrades[index],
                    onRemove: () => setState(
                      () => _linkedJournalIds = _linkedJournalIds
                          .where((String id) => id != linkedTrades[index].id)
                          .toList(growable: false),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiField(
          label: 'Tags',
          helper: 'Group notes that belong together',
          child: UiTagInput(
            tags: _tags,
            prefix: '#',
            suggestions: NotesQuery.tagsOf(
              _graph.noteList,
            ).take(8).toList(growable: false),
            onChanged: (List<String> next) => setState(() => _tags = next),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiField(
          label: 'Tickers',
          child: UiTagInput(
            tags: _tickers,
            prefix: '\$',
            intent: UiIntent.info,
            suggestions: <String>[
              for (final AppLinkRef ref
                  in _graph.options(AppLinkKind.ticker).take(8))
                ref.id,
            ],
            onChanged: (List<String> next) => setState(() => _tickers = next),
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        UiSwitch(
          value: _isPublic,
          label: 'Share publicly',
          description: 'Anyone with the link can read this note',
          onChanged: (bool value) => setState(() => _isPublic = value),
        ),
        if (_isPublic) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          UiCallout(
            title: 'Public engagement',
            message:
                '${_note.viewCount} views · ${_note.likeCount} likes · '
                '${_note.comments.length} comments. Readers can view, like, '
                'and join the conversation after this note is saved publicly.',
            intent: UiIntent.info,
          ),
        ],
      ],
    );
  }

  String get _detailsSummary {
    final List<String> parts = <String>[
      _type.label,
      if (_strategyNameFor(_strategyId) case final String name) name,
      if (_tags.isNotEmpty)
        '${_tags.length} tag${_tags.length == 1 ? '' : 's'}',
      if (_tickers.isNotEmpty) _tickers.map((String t) => '\$$t').join(' '),
      if (_linkedJournalIds.isNotEmpty)
        '${_linkedJournalIds.length} journal ${_linkedJournalIds.length == 1 ? 'entry' : 'entries'}',
      if (_isPublic) 'Public',
    ];
    return parts.join(' · ');
  }

  /// No card frame: the writing surface is the page. [expands] is true only when
  /// an ancestor gives it a bounded height (the wide layout's [Expanded]).
  Widget _editorPane(
    BuildContext context, {
    required bool expands,
  }) => RichMarkdownEditorField(
    key: _editorKey,
    controller: _body,
    focusNode: _bodyFocus,
    autofocus: _note.id.isEmpty && _body.text.isEmpty,
    hintText:
        'Write freely. Type / for headings, tables, checklists and blocks.',
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
            imageResolver: (context, uri) => NoteAttachments.resolve(
              context,
              uri,
              using: widget.sourceDocument?.resolveImage,
            ),
            emptyPlaceholder: 'Nothing to read yet — switch to Write.',
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
    final bool editing = _mode != NoteEditorMode.read;
    // The mobile toolbar is docked at the bottom, so anything else that floats
    // has to clear it.
    final double toolbarClearance = wide || !editing ? 0 : context.sz(64);

    return <Widget>[
      if (_mode != NoteEditorMode.write)
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
                sourceKind:
                    widget.sourceDocument?.source.kind ?? AppLinkKind.note,
                sourceId: _note.id,
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
