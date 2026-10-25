import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_editor_field.dart';
import 'package:tradex/core/markdown_kit/markdown_snippets.dart';

/// Floating formatting bar for [RichMarkdownEditorField]. Meant to be
/// positioned above the larger of the keyboard inset and the app's dock-safe
/// bottom padding, like an input accessory view.
class MarkdownEditorToolbar extends StatelessWidget {
  const MarkdownEditorToolbar({
    super.key,
    required this.editorKey,
    this.onPickImage,
    this.onPickDocument,
    this.onToggleVoice,
    this.onInsertTicker,
    this.onInsertStrategy,
    this.onInsertJournal,
    this.onInsertRecord,
    this.listening = false,
  });

  final GlobalKey<RichMarkdownEditorFieldState> editorKey;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickDocument;
  final VoidCallback? onToggleVoice;

  /// Opens the symbol picker. Interactive, so it stays a callback rather than a
  /// static entry in [MarkdownSnippets].
  final VoidCallback? onInsertTicker;

  /// Opens the strategy picker, which writes a `tradex://strategy/<id>` link.
  final VoidCallback? onInsertStrategy;

  /// Opens the trade picker, which writes a `tradex://journal/<id>` link. A
  /// playbook cites the trades that tested it; an entry cites the playbook it
  /// followed. Both directions of the same edge.
  final VoidCallback? onInsertJournal;
  final VoidCallback? onInsertRecord;
  final bool listening;

  RichMarkdownEditorFieldState? get _editor => editorKey.currentState;

  void _showMore(BuildContext context) {
    final UiColors colors = context.uiColors;
    UiDialog.show<void>(
      context,
      maxWidth: 620,
      child: Builder(
        builder: (BuildContext sheetContext) => UiDialog(
          title: 'Insert',
          description: 'Pick a block — the markdown is written for you.',
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.72,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final String group in <String>[
                    MarkdownSnippets.groupBlocks,
                    MarkdownSnippets.groupTrading,
                  ]) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        group.toUpperCase(),
                        style: sheetContext.uiText.caption.copyWith(
                          color: colors.foregroundSubtle,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 12,
                      children: <Widget>[
                        for (final MarkdownSnippet snippet
                            in MarkdownSnippets.inGroup(group))
                          _MoreTile(
                            icon: snippet.icon,
                            label: snippet.label,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              final RichMarkdownEditorFieldState? editor =
                                  _editor;
                              if (editor != null) snippet.applyTo(editor);
                            },
                          ),
                        if (group == MarkdownSnippets.groupTrading) ...<Widget>[
                          if (onInsertRecord != null)
                            _MoreTile(
                              icon: Icons.add_link_rounded,
                              label: 'Link a record',
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onInsertRecord!();
                              },
                            ),
                          if (onInsertTicker != null)
                            _MoreTile(
                              icon: Icons.sell_outlined,
                              label: 'Ticker',
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onInsertTicker?.call();
                              },
                            ),
                          if (onInsertStrategy != null)
                            _MoreTile(
                              icon: Icons.account_tree_outlined,
                              label: 'Strategy link',
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onInsertStrategy?.call();
                              },
                            ),
                          if (onInsertJournal != null)
                            _MoreTile(
                              icon: Icons.candlestick_chart_outlined,
                              label: 'Trade link',
                              onTap: () {
                                Navigator.pop(sheetContext);
                                onInsertJournal?.call();
                              },
                            ),
                        ],
                        if (group == MarkdownSnippets.groupBlocks &&
                            onPickDocument != null)
                          _MoreTile(
                            icon: Icons.upload_file_outlined,
                            label: 'Import file',
                            onTap: () {
                              Navigator.pop(sheetContext);
                              onPickDocument?.call();
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xDC1A1817)
            : colors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            if (_editor != null)
              ValueListenableBuilder<UndoHistoryValue>(
                valueListenable: _editor!.undoController,
                builder: (context, value, _) => Row(
                  children: [
                    _ToolbarButton(
                      icon: Icons.undo,
                      hint: 'Undo',
                      onTap: value.canUndo
                          ? () => _editor?.undoController.undo()
                          : null,
                    ),
                    _ToolbarButton(
                      icon: Icons.redo,
                      hint: 'Redo',
                      onTap: value.canRedo
                          ? () => _editor?.undoController.redo()
                          : null,
                    ),
                  ],
                ),
              ),
            _ToolbarDivider(),
            PopupMenuButton<String>(
              tooltip: 'Heading',
              icon: Icon(Icons.title, size: 20, color: colors.foregroundMuted),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              onSelected: (value) => _editor?.prefixCurrentLine(value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: '# ', child: Text('Heading 1')),
                PopupMenuItem(value: '## ', child: Text('Heading 2')),
                PopupMenuItem(value: '### ', child: Text('Heading 3')),
              ],
            ),
            _ToolbarButton(
              icon: Icons.format_bold,
              hint: 'Bold',
              onTap: () => _editor?.wrapSelection('**', '**'),
            ),
            _ToolbarButton(
              icon: Icons.format_italic,
              hint: 'Italic',
              onTap: () => _editor?.wrapSelection('*', '*'),
            ),
            _ToolbarButton(
              icon: Icons.format_strikethrough,
              hint: 'Strikethrough',
              onTap: () => _editor?.wrapSelection('~~', '~~'),
            ),
            _ToolbarButton(
              icon: Icons.code,
              hint: 'Inline code',
              onTap: () => _editor?.wrapSelection('`', '`'),
            ),
            _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.format_list_bulleted,
              hint: 'Bulleted list',
              onTap: () => _editor?.prefixCurrentLine('- '),
            ),
            _ToolbarButton(
              icon: Icons.format_list_numbered,
              hint: 'Numbered list',
              onTap: () => _editor?.prefixCurrentLine('1. '),
            ),
            _ToolbarButton(
              icon: Icons.checklist,
              hint: 'Checklist item',
              onTap: () => _editor?.prefixCurrentLine('- [ ] '),
            ),
            _ToolbarButton(
              icon: Icons.format_quote,
              hint: 'Quote',
              onTap: () => _editor?.prefixCurrentLine('> '),
            ),
            _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.link,
              hint: 'Link a record',
              onTap:
                  onInsertRecord ?? () => _editor?.wrapSelection('[', '](url)'),
            ),
            if (onPickImage != null)
              _ToolbarButton(
                icon: Icons.image_outlined,
                hint: 'Add image',
                onTap: onPickImage,
              ),
            if (onToggleVoice != null)
              _ToolbarButton(
                icon: listening
                    ? Icons.stop_circle_outlined
                    : Icons.mic_none_rounded,
                hint: listening ? 'Stop dictation' : 'Dictate with voice',
                onTap: onToggleVoice,
                active: listening,
              ),
            _ToolbarDivider(),
            _ToolbarButton(
              icon: Icons.add_box_outlined,
              hint: 'Insert table, math, flowchart, chart…',
              onTap: () => _showMore(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.hint,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? hint;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return IconButton(
      icon: Icon(icon, size: 20),
      color: active
          ? colors.destructive
          : (onTap == null
                ? colors.disabledForeground
                : colors.foregroundMuted),
      onPressed: onTap,
      splashRadius: 20,
      tooltip: hint,
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      color: context.uiColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: colors.foreground),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.foregroundMuted),
            ),
          ],
        ),
      ),
    );
  }
}
