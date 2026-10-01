import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import 'markdown_editor_field.dart';
import 'markdown_snippets.dart';

/// Always-visible formatting ribbon for the desktop editor.
///
/// Wraps [UiEditorToolbar] for the actions that primitive already knows about
/// and adds the markdown-only ones (checklist, highlight, table, math, the
/// trading templates) in the trailing slot, so the design-system component stays
/// the source of truth for the button styling.
class MarkdownFormatRibbon extends StatelessWidget {
  const MarkdownFormatRibbon({
    super.key,
    required this.editorKey,
    this.onPickImage,
    this.onPickDocument,
    this.onInsertTicker,
    this.onInsertStrategy,
    this.onInsertJournal,
    this.onInsertRecord,
    this.onToggleVoice,
    this.listening = false,
  });

  final GlobalKey<RichMarkdownEditorFieldState> editorKey;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickDocument;
  final VoidCallback? onInsertTicker;
  final VoidCallback? onInsertStrategy;

  /// Cites a filed trade. The mirror of [onInsertStrategy]: a journal entry
  /// links up to the playbook it followed, a playbook links down to the trades
  /// that prove or disprove it.
  final VoidCallback? onInsertJournal;
  final VoidCallback? onInsertRecord;
  final VoidCallback? onToggleVoice;
  final bool listening;

  RichMarkdownEditorFieldState? get _editor => editorKey.currentState;

  void _dispatch(UiEditorAction action) {
    final RichMarkdownEditorFieldState? editor = _editor;
    if (editor == null) return;
    switch (action) {
      case UiEditorAction.undo:
        editor.undoController.undo();
      case UiEditorAction.redo:
        editor.undoController.redo();
      case UiEditorAction.bold:
        editor.wrapSelection('**', '**');
      case UiEditorAction.italic:
        editor.wrapSelection('*', '*');
      case UiEditorAction.strikethrough:
        editor.wrapSelection('~~', '~~');
      case UiEditorAction.underline:
        // Markdown has no underline; the closest honest equivalent is a
        // highlight, which the preview does render.
        editor.wrapSelection('==', '==');
      case UiEditorAction.heading:
        editor.prefixCurrentLine('## ');
      case UiEditorAction.quote:
        editor.prefixCurrentLine('> ');
      case UiEditorAction.bulletList:
        editor.prefixCurrentLine('- ');
      case UiEditorAction.numberedList:
        editor.prefixCurrentLine('1. ');
      case UiEditorAction.codeBlock:
        editor.insertBlock(MarkdownSnippets.codeTemplate);
      case UiEditorAction.link:
        if (onInsertRecord != null) {
          onInsertRecord!();
        } else {
          editor.wrapSelection('[', '](url)');
        }
      case UiEditorAction.image:
        onPickImage?.call();
      case UiEditorAction.chart:
        editor.insertBlock(MarkdownSnippets.chartTemplate);
      case UiEditorAction.attachment:
        onPickDocument?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiEditorToolbar(
      onAction: _dispatch,
      actions: <UiEditorAction>[
        UiEditorAction.undo,
        UiEditorAction.redo,
        UiEditorAction.link,
        UiEditorAction.bold,
        UiEditorAction.italic,
        UiEditorAction.strikethrough,
        UiEditorAction.heading,
        UiEditorAction.quote,
        UiEditorAction.bulletList,
        UiEditorAction.numberedList,
        UiEditorAction.codeBlock,
        if (onPickImage != null) UiEditorAction.image,
        if (onPickDocument != null) UiEditorAction.attachment,
      ],
      activeActions: <UiEditorAction>{},
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          UiIconButton(
            icon: Icons.checklist_rounded,
            tooltip: 'Checklist item',
            size: UiSize.sm,
            onPressed: () => _editor?.prefixCurrentLine('- [ ] '),
          ),
          UiIconButton(
            icon: Icons.border_color_outlined,
            tooltip: 'Highlight',
            size: UiSize.sm,
            onPressed: () => _editor?.wrapSelection('==', '=='),
          ),
          if (onToggleVoice != null)
            UiIconButton(
              icon: listening
                  ? Icons.stop_circle_outlined
                  : Icons.mic_none_rounded,
              tooltip: listening ? 'Stop dictation' : 'Dictate',
              size: UiSize.sm,
              onPressed: onToggleVoice,
            ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          PopupMenuButton<MarkdownSnippet>(
            tooltip: 'Insert a block',
            position: PopupMenuPosition.under,
            onSelected: (MarkdownSnippet snippet) {
              final RichMarkdownEditorFieldState? editor = _editor;
              if (editor != null) snippet.applyTo(editor);
            },
            itemBuilder: (BuildContext ctx) =>
                <PopupMenuEntry<MarkdownSnippet>>[
                  for (final String group in <String>[
                    MarkdownSnippets.groupBlocks,
                    MarkdownSnippets.groupTrading,
                  ]) ...<PopupMenuEntry<MarkdownSnippet>>[
                    PopupMenuItem<MarkdownSnippet>(
                      enabled: false,
                      height: context.sz(30),
                      child: Text(
                        group.toUpperCase(),
                        style: ctx.uiText.caption.copyWith(
                          color: ctx.uiColors.foregroundSubtle,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final MarkdownSnippet snippet
                        in MarkdownSnippets.inGroup(group))
                      PopupMenuItem<MarkdownSnippet>(
                        value: snippet,
                        child: Row(
                          children: <Widget>[
                            Icon(
                              snippet.icon,
                              size: ctx.sz(theme.sizes.iconSm),
                              color: ctx.uiColors.foregroundMuted,
                            ),
                            SizedBox(width: ctx.sp(theme.spacing.sm)),
                            Text(snippet.label),
                          ],
                        ),
                      ),
                  ],
                ],
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.sm),
                vertical: context.sp(theme.spacing.xxs),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.add_box_outlined,
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.foregroundMuted,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    'Insert',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: context.sz(theme.sizes.iconXs),
                    color: theme.colors.foregroundSubtle,
                  ),
                ],
              ),
            ),
          ),
          if (onInsertTicker != null)
            UiIconButton(
              icon: Icons.sell_outlined,
              tooltip: 'Insert a ticker',
              size: UiSize.sm,
              onPressed: onInsertTicker,
            ),
          if (onInsertStrategy != null)
            UiIconButton(
              icon: Icons.account_tree_outlined,
              tooltip: 'Link a strategy',
              size: UiSize.sm,
              onPressed: onInsertStrategy,
            ),
          if (onInsertJournal != null)
            UiIconButton(
              icon: Icons.candlestick_chart_outlined,
              tooltip: 'Cite a trade',
              size: UiSize.sm,
              onPressed: onInsertJournal,
            ),
        ],
      ),
    );
  }
}
