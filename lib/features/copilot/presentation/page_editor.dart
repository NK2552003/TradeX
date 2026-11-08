import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/markdown_kit/markdown_editor_field.dart';
import 'package:tradex/core/markdown_kit/markdown_editor_toolbar.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';
import 'package:tradex/core/markdown_kit/markdown_slash_palette.dart';
import 'package:tradex/core/markdown_kit/markdown_snippets.dart';

import '../data/copilot_controller.dart';
import '../models/workspace.dart';
import 'visual_page_editor.dart';

class CopilotPageEditor extends StatefulWidget {
  const CopilotPageEditor({
    super.key,
    required this.controller,
    required this.page,
    required this.onClose,
    required this.onDiscuss,
  });
  final CopilotController controller;
  final WorkspacePage page;
  final VoidCallback onClose;
  final ValueChanged<WorkspacePage> onDiscuss;
  @override
  State<CopilotPageEditor> createState() => _CopilotPageEditorState();
}

class _CopilotPageEditorState extends State<CopilotPageEditor> {
  static Future<void> _draftWrites = Future.value();
  late final _title = TextEditingController(text: widget.page.title);
  late final _body = TextEditingController(text: widget.page.body);
  final _editor = GlobalKey<RichMarkdownEditorFieldState>();
  late int _revision = widget.page.revision;
  late String _space = widget.page.spaceId;
  late String? _parent = widget.page.parentId;
  late final String _draftKey =
      'copilot.draft.${SupabaseConfig.client?.auth.currentUser?.id ?? 'local-owner'}.${widget.page.id}';
  Timer? _debounce;
  Future<void>? _saving;
  bool _dirty = false;
  bool _restoring = true;
  int _tab = 0;
  String? _slash;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    await _draftWrites;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (!mounted) return;
    if (raw != null) {
      try {
        final draft = jsonDecode(raw) as Json;
        if (draft['title'] == widget.page.title &&
            draft['body'] == widget.page.body &&
            (draft['spaceId'] ?? widget.page.spaceId) == widget.page.spaceId &&
            draft['parentId'] == widget.page.parentId) {
          await _writeDraft(null);
          if (mounted) setState(() => _restoring = false);
          return;
        }
        _title.text = draft['title'];
        _body.text = draft['body'];
        _revision = draft['revision'];
        _space = draft['spaceId'] ?? _space;
        _parent = draft['parentId'];
        _dirty = true;
        _error = 'Recovered an unsaved draft. Review it and save when ready.';
      } catch (_) {
        /* Keep the server version if a local draft is unreadable. */
      }
    }
    setState(() => _restoring = false);
  }

  Json get _draft => {
    'title': _title.text,
    'body': _body.text,
    'revision': _revision,
    'spaceId': _space,
    'parentId': _parent,
  };
  void _changed() {
    if (_restoring) return;
    setState(() => _dirty = true);
    _debounce?.cancel();
    unawaited(_keepDraft());
    _debounce = Timer(
      const Duration(milliseconds: 900),
      () => unawaited(_save()),
    );
  }

  Future<void> _keepDraft() => _writeDraft(jsonEncode(_draft));

  Future<void> _writeDraft(String? draft) =>
      _draftWrites = _draftWrites.then((_) async {
        final prefs = await SharedPreferences.getInstance();
        if (draft == null) {
          await prefs.remove(_draftKey);
        } else {
          await prefs.setString(_draftKey, draft);
        }
      });

  Future<void> _save() async {
    if (_saving != null) {
      await _saving;
      if (_dirty && _error == null) await _save();
      return;
    }
    if (!_dirty) return;
    final draft = _draft;
    final operation = _performSave(draft);
    _saving = operation;
    await operation;
    _saving = null;
    if (mounted) setState(() {});
  }

  Future<void> _performSave(Json draft) async {
    try {
      await _keepDraft();
      final result = await widget.controller.action({
        'action': 'page.save',
        'id': widget.page.id,
        ...draft,
      }, reportError: false);
      if (!mounted || result == null) return;
      _revision = result['revision'] as int;
      _dirty =
          _title.text != draft['title'] ||
          _body.text != draft['body'] ||
          _space != draft['spaceId'] ||
          _parent != draft['parentId'];
      _error = null;
      if (_dirty) {
        await _keepDraft();
      } else {
        await _writeDraft(null);
      }
    } catch (error) {
      if (mounted) _error = '$error';
    }
  }

  Future<void> _close() async {
    _debounce?.cancel();
    await _save();
    if (!mounted) return;
    if (_dirty) {
      final leave = await UiDialog.confirm(
        context,
        title: 'Keep this draft and close?',
        description:
            'Your edits are saved on this device. Reopen this page to recover them.',
      );
      if (!leave) return;
    }
    widget.onClose();
  }

  Future<void> _reloadSaved() async {
    final discard = await UiDialog.confirm(
      context,
      title: 'Load the saved version?',
      description:
          'This replaces your local draft. Export it first if you want to keep both versions.',
    );
    if (!discard || !mounted) return;
    _debounce?.cancel();
    await _saving;
    await widget.controller.reload(quiet: true);
    final page = widget.controller.workspace.pages
        .where((p) => p.id == widget.page.id)
        .firstOrNull;
    if (!mounted || page == null) return;
    setState(() {
      _title.text = page.title;
      _body.text = page.body;
      _revision = page.revision;
      _space = page.spaceId;
      _parent = page.parentId;
      _dirty = false;
      _error = null;
    });
    await _writeDraft(null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) unawaited(_keepDraft());
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          UiIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Back to pages',
            onPressed: _close,
          ),
          Expanded(
            child: Text(
              _saving != null
                  ? 'Saving…'
                  : _dirty
                  ? 'Draft on this device'
                  : 'All changes saved',
              style: context.uiText.caption.copyWith(
                color: context.ui.colors.foregroundMuted,
              ),
            ),
          ),
          UiIconButton(
            icon: Icons.drive_file_move_outline,
            tooltip: 'Move page',
            onPressed: _move,
          ),
          UiIconButton(
            icon: Icons.ios_share_outlined,
            tooltip: 'Export Markdown',
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile.fromData(
                    utf8.encode('# ${_title.text}\n\n${_body.text}'),
                    name: 'page.md',
                    mimeType: 'text/markdown',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      UiInput(
        controller: _title,
        label: 'Page title',
        variant: UiInputVariant.ghost,
        onChanged: (_) => _changed(),
      ),
      UiGap.v(context.ui.spacing.sm),
      Row(
        children: [
          Expanded(
            child: UiTabs(
              tabs: const ['Write', 'Markdown', 'Read'],
              selectedIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          UiButton(
            label: 'Discuss',
            icon: Icons.chat_bubble_outline,
            variant: UiVariant.ghost,
            size: UiSize.sm,
            onPressed: widget.controller.conversationLocked
                ? null
                : () async {
                    await _save();
                    if (!mounted || _dirty) return;
                    widget.onDiscuss(
                      WorkspacePage.fromJson({...widget.page.json, ..._draft}),
                    );
                  },
          ),
        ],
      ),
      if (_error != null) ...[
        UiGap.v(context.ui.spacing.sm),
        UiCallout(
          title: 'Your draft is safe',
          message: _error!,
          intent: UiIntent.warning,
          action: Wrap(
            spacing: context.sp(context.ui.spacing.xs),
            runSpacing: context.sp(context.ui.spacing.xs),
            children: [
              UiButton(label: 'Save again', size: UiSize.sm, onPressed: _save),
              UiButton(
                label: 'Load saved',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                onPressed: _reloadSaved,
              ),
            ],
          ),
        ),
        UiGap.v(context.ui.spacing.sm),
      ],
      Expanded(
        child: _restoring
            ? const UiSkeleton(height: 160)
            : _tab == 0
            ? CopilotVisualPageEditor(source: _body, onChanged: _changed)
            : _tab == 2
            ? SingleChildScrollView(
                child: RichMarkdownPreview(data: _body.text),
              )
            : Stack(
                children: [
                  RichMarkdownEditorField(
                    key: _editor,
                    controller: _body,
                    expands: true,
                    minLines: 1,
                    onChanged: _changed,
                    hintText:
                        'Make room for an idea. Type / to insert a block.',
                    onSlashQuery: (q) => setState(() => _slash = q),
                    onSlashSubmit: () {
                      final snippet = MarkdownSlashPalette.topMatch(
                        _slash ?? '',
                      );
                      if (snippet != null) _insert(snippet);
                    },
                  ),
                  if (_slash != null)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: MarkdownSlashPalette(
                        query: _slash!,
                        onSelect: _insert,
                        onDismiss: () => setState(() => _slash = null),
                      ),
                    ),
                ],
              ),
      ),
      if (_tab == 1) MarkdownEditorToolbar(editorKey: _editor),
    ],
  );

  Future<void> _move() async {
    var space = _space;
    var parent = _parent ?? '';
    final apply = await UiDialog.show<bool>(
      context,
      child: StatefulBuilder(
        builder: (context, update) => UiDialog(
          title: 'Move page',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UiSelect<String>(
                label: 'Space',
                value: space,
                expand: true,
                options: [
                  for (final item in widget.controller.workspace.spaces)
                    UiOption(
                      label: textOf(item, 'name'),
                      value: textOf(item, 'id'),
                    ),
                ],
                onChanged: (value) => update(() {
                  space = value;
                  parent = '';
                }),
              ),
              UiGap.v(context.ui.spacing.md),
              UiSelect<String>(
                label: 'Parent page',
                value: parent,
                expand: true,
                options: [
                  const UiOption(label: 'Top level', value: ''),
                  for (final page in widget.controller.workspace.pages.where(
                    (p) => p.spaceId == space && p.id != widget.page.id,
                  ))
                    UiOption(label: page.title, value: page.id),
                ],
                onChanged: (value) => update(() => parent = value),
              ),
            ],
          ),
          actions: [
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              onPressed: () => Navigator.pop(context, false),
            ),
            UiButton(
              label: 'Move',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (apply != true || !mounted) return;
    _space = space;
    _parent = parent.isEmpty ? null : parent;
    _changed();
  }

  void _insert(MarkdownSnippet snippet) {
    final editor = _editor.currentState;
    editor?.consumeSlashQuery();
    switch (snippet.kind) {
      case MarkdownSnippetKind.block:
        editor?.insertBlock(snippet.body);
      case MarkdownSnippetKind.wrap:
        editor?.wrapSelection(snippet.prefix, snippet.suffix);
      case MarkdownSnippetKind.line:
        editor?.prefixCurrentLine(snippet.prefix);
    }
    setState(() => _slash = null);
    _changed();
  }
}
