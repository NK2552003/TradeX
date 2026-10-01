import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// The raw multi-line text input for a markdown editor. Deliberately split
/// from the formatting toolbar (see [MarkdownEditorToolbar]) so the toolbar
/// can float in its own [Positioned] layer, pinned just above the on-screen
/// keyboard, while this field lives inline in the scrolling page content —
/// exactly like the accessory bar in Notes-style apps.
///
/// The toolbar drives this field through [RichMarkdownEditorFieldState]'s
/// public methods (reach it via the [GlobalKey] passed as `key`).
///
/// Two behaviours here exist for people who do not write markdown by hand:
/// pressing Enter inside a list continues the list ([smartLists]), and typing
/// `/` at the start of a word opens the block palette ([onSlashQuery]).
class RichMarkdownEditorField extends StatefulWidget {
  const RichMarkdownEditorField({
    super.key,
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.autofocus = false,
    this.onChanged,
    this.style,
    this.minLines = 10,
    this.smartLists = true,
    this.shortcuts = true,
    this.onSlashQuery,
    this.onSlashSubmit,
    this.expands = false,
    this.scrollController,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final bool autofocus;
  final VoidCallback? onChanged;
  final TextStyle? style;
  final int minLines;

  /// Continue bullets, numbers, checkboxes and quotes when Enter is pressed,
  /// and end the list when Enter is pressed on an empty item.
  final bool smartLists;

  /// Bind Cmd/Ctrl+B, +I, +K, +E and Cmd/Ctrl+Shift+7/8/9.
  final bool shortcuts;

  /// Fires with the text typed after a `/` at a word boundary, and with `null`
  /// the moment that context ends. The screen owns the palette widget so it can
  /// place it where it fits the layout.
  final ValueChanged<String?>? onSlashQuery;

  /// Enter pressed while a slash query is active — accept the top result.
  /// Only bound while [onSlashQuery] last reported a non-null value, so Enter
  /// keeps inserting newlines the rest of the time.
  final VoidCallback? onSlashSubmit;

  /// Fill the available height instead of growing with the content. Used by the
  /// split-pane layout, where the editor pane scrolls on its own.
  final bool expands;
  final ScrollController? scrollController;

  @override
  State<RichMarkdownEditorField> createState() =>
      RichMarkdownEditorFieldState();
}

class RichMarkdownEditorFieldState extends State<RichMarkdownEditorField> {
  final UndoHistoryController undoController = UndoHistoryController();

  /// Where the live `/query` sits in the source, so it can be removed when a
  /// snippet is chosen.
  ({int start, int end, String query})? _slash;

  String _lastText = '';

  static final RegExp _bulletLine = RegExp(r'^(\s*)([-*+])\s+(.*)$');
  static final RegExp _checkLine = RegExp(
    r'^(\s*)([-*+])\s+\[( |x|X)\]\s*(.*)$',
  );
  static final RegExp _orderedLine = RegExp(r'^(\s*)(\d+)([.)])\s+(.*)$');
  static final RegExp _quoteLine = RegExp(r'^(\s*)>\s?(.*)$');

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
  }

  @override
  void dispose() {
    undoController.dispose();
    super.dispose();
  }

  bool get hasSlashQuery => _slash != null;

  /// Wraps the current selection with [prefix]/[suffix] (e.g. `**`/`**` for
  /// bold). With nothing selected, inserts both and leaves the cursor
  /// between them so typing continues right inside the markers.
  void wrapSelection(String prefix, String suffix) {
    final TextEditingController controller = widget.controller;
    final String text = controller.text;
    final TextSelection selection = controller.selection;

    if (!selection.isValid) {
      final String newText = '$text$prefix$suffix';
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newText.length - suffix.length,
        ),
      );
    } else {
      final String selected = selection.textInside(text);
      final String newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selected$suffix',
      );
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + prefix.length + selected.length,
        ),
      );
    }
    _afterProgrammaticEdit();
  }

  /// Inserts [prefix] at the very start of the current line — for line-level
  /// markers like `## `, `- `, `1. `, `> `, `- [ ] `.
  void prefixCurrentLine(String prefix) {
    final TextEditingController controller = widget.controller;
    final String text = controller.text;
    final TextSelection selection = controller.selection;
    final int cursor = selection.isValid ? selection.start : text.length;

    int lineStart = cursor == 0 ? -1 : text.lastIndexOf('\n', cursor - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    final String newText = text.replaceRange(lineStart, lineStart, prefix);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
    _afterProgrammaticEdit();
  }

  /// Inserts a standalone block (table, mermaid fence, math fence, `---`...)
  /// at the cursor, adding a leading newline first if the cursor isn't
  /// already at the start of a line so the block doesn't run into existing
  /// text.
  void insertBlock(String block) {
    final TextEditingController controller = widget.controller;
    final String text = controller.text;
    final TextSelection selection = controller.selection;
    final int insertAt = selection.isValid ? selection.start : text.length;
    final int removeEnd = selection.isValid ? selection.end : insertAt;
    final bool needsLeadingNewline = insertAt > 0 && text[insertAt - 1] != '\n';
    final String content = '${needsLeadingNewline ? '\n' : ''}$block';

    final String newText = text.replaceRange(insertAt, removeEnd, content);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + content.length),
    );
    _afterProgrammaticEdit();
  }

  /// Inserts plain text at the cursor without any block framing — used by the
  /// ticker and strategy pickers, which produce inline markup.
  void insertInline(String text) {
    final TextEditingController controller = widget.controller;
    final String source = controller.text;
    final TextSelection selection = controller.selection;
    final int start = selection.isValid ? selection.start : source.length;
    final int end = selection.isValid ? selection.end : start;
    final String newText = source.replaceRange(start, end, text);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _afterProgrammaticEdit();
  }

  /// Deletes the live `/query` so a chosen snippet replaces what was typed
  /// rather than landing after it.
  void consumeSlashQuery() {
    final ({int start, int end, String query})? slash = _slash;
    if (slash == null) return;
    final TextEditingController controller = widget.controller;
    final String text = controller.text;
    if (slash.end > text.length) {
      _setSlash(null);
      return;
    }
    controller.value = TextEditingValue(
      text: text.replaceRange(slash.start, slash.end, ''),
      selection: TextSelection.collapsed(offset: slash.start),
    );
    _lastText = controller.text;
    _setSlash(null);
  }

  void dismissSlashQuery() => _setSlash(null);

  void _afterProgrammaticEdit() {
    _lastText = widget.controller.text;
    _setSlash(null);
    widget.onChanged?.call();
  }

  void _setSlash(({int start, int end, String query})? next) {
    final bool wasActive = _slash != null;
    final String? previousQuery = _slash?.query;
    _slash = next;
    if (next?.query != previousQuery || wasActive != (next != null)) {
      widget.onSlashQuery?.call(next?.query);
      if (mounted && wasActive != (next != null)) setState(() {});
    }
  }

  void _handleChanged(String value) {
    final String previous = _lastText;
    _lastText = value;

    final bool insertedNewline =
        widget.smartLists &&
        value.length == previous.length + 1 &&
        widget.controller.selection.isCollapsed &&
        widget.controller.selection.start > 0 &&
        value[widget.controller.selection.start - 1] == '\n';

    if (insertedNewline && _continueList()) return;

    _detectSlash();
    widget.onChanged?.call();
  }

  /// Reads the line above the cursor and, if it is a list item, repeats its
  /// marker on the new line. An empty item ends the list instead, which is what
  /// every note app does and what people expect without being told.
  bool _continueList() {
    final TextEditingController controller = widget.controller;
    final String text = controller.text;
    final int cursor = controller.selection.start;
    // The newline just inserted sits at cursor - 1.
    final int previousLineEnd = cursor - 1;
    if (previousLineEnd <= 0) return false;
    int previousLineStart = text.lastIndexOf('\n', previousLineEnd - 1);
    previousLineStart = previousLineStart == -1 ? 0 : previousLineStart + 1;
    final String line = text.substring(previousLineStart, previousLineEnd);

    final RegExpMatch? check = _checkLine.firstMatch(line);
    final RegExpMatch? ordered = _orderedLine.firstMatch(line);
    final RegExpMatch? bullet = check == null
        ? _bulletLine.firstMatch(line)
        : null;
    final RegExpMatch? quote = _quoteLine.firstMatch(line);

    String marker;
    String content;
    if (check != null) {
      marker = '${check.group(1)}${check.group(2)} [ ] ';
      content = check.group(4) ?? '';
    } else if (ordered != null) {
      final int n = int.tryParse(ordered.group(2) ?? '') ?? 0;
      marker = '${ordered.group(1)}${n + 1}${ordered.group(3)} ';
      content = ordered.group(4) ?? '';
    } else if (bullet != null) {
      marker = '${bullet.group(1)}${bullet.group(2)} ';
      content = bullet.group(3) ?? '';
    } else if (quote != null) {
      marker = '${quote.group(1)}> ';
      content = quote.group(2) ?? '';
    } else {
      return false;
    }

    if (content.trim().isEmpty) {
      // Enter on an empty item: strip the marker and leave a blank line, which
      // closes the list rather than growing it forever.
      controller.value = TextEditingValue(
        text: text.replaceRange(previousLineStart, cursor, '\n'),
        selection: TextSelection.collapsed(offset: previousLineStart + 1),
      );
    } else {
      controller.value = TextEditingValue(
        text: text.replaceRange(cursor, cursor, marker),
        selection: TextSelection.collapsed(offset: cursor + marker.length),
      );
    }
    _lastText = controller.text;
    _setSlash(null);
    widget.onChanged?.call();
    return true;
  }

  /// A slash context is a `/` that starts a word, with no whitespace between it
  /// and the caret. Anything longer than 24 characters is prose, not a command.
  void _detectSlash() {
    if (widget.onSlashQuery == null) {
      _slash = null;
      return;
    }
    final TextEditingController controller = widget.controller;
    final TextSelection selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      _setSlash(null);
      return;
    }
    final String text = controller.text;
    final int cursor = selection.start;
    int at = -1;
    for (int i = cursor - 1; i >= 0 && cursor - i <= 25; i--) {
      final String ch = text[i];
      if (ch == '/') {
        at = i;
        break;
      }
      if (ch == '\n' || ch == ' ' || ch == '\t') break;
    }
    if (at == -1) {
      _setSlash(null);
      return;
    }
    final bool atWordStart =
        at == 0 || const <String>['\n', ' ', '\t'].contains(text[at - 1]);
    if (!atWordStart) {
      _setSlash(null);
      return;
    }
    _setSlash((start: at, end: cursor, query: text.substring(at + 1, cursor)));
  }

  Map<ShortcutActivator, VoidCallback> _bindings() {
    final Map<ShortcutActivator, VoidCallback> map =
        <ShortcutActivator, VoidCallback>{};
    if (widget.shortcuts) {
      void bind(
        LogicalKeyboardKey key,
        VoidCallback action, {
        bool shift = false,
      }) {
        map[SingleActivator(key, meta: true, shift: shift)] = action;
        map[SingleActivator(key, control: true, shift: shift)] = action;
      }

      bind(LogicalKeyboardKey.keyB, () => wrapSelection('**', '**'));
      bind(LogicalKeyboardKey.keyI, () => wrapSelection('*', '*'));
      bind(LogicalKeyboardKey.keyK, () => wrapSelection('[', '](url)'));
      bind(LogicalKeyboardKey.keyE, () => wrapSelection('`', '`'));
      bind(
        LogicalKeyboardKey.digit8,
        () => prefixCurrentLine('- '),
        shift: true,
      );
      bind(
        LogicalKeyboardKey.digit7,
        () => prefixCurrentLine('1. '),
        shift: true,
      );
      bind(
        LogicalKeyboardKey.digit9,
        () => prefixCurrentLine('- [ ] '),
        shift: true,
      );
    }
    if (_slash != null) {
      // Bound only while the palette is open, so Enter still makes a new line
      // the rest of the time.
      if (widget.onSlashSubmit != null) {
        map[const SingleActivator(LogicalKeyboardKey.enter)] =
            widget.onSlashSubmit!;
      }
      map[const SingleActivator(LogicalKeyboardKey.escape)] = dismissSlashQuery;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = widget.style ?? context.uiText.body;
    Widget field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      undoController: undoController,
      autofocus: widget.autofocus,
      maxLines: null,
      minLines: widget.expands ? null : widget.minLines,
      expands: widget.expands,
      scrollController: widget.scrollController,
      textAlignVertical: TextAlignVertical.top,
      style: style,
      onChanged: _handleChanged,
      decoration: InputDecoration.collapsed(
        hintText: widget.hintText,
        hintStyle: style.copyWith(color: context.uiColors.foregroundMuted),
      ),
    );
    if (widget.scrollController != null) {
      // EditableText installs its own desktop scrollbar for multiline fields.
      // A bounded editor already has a scrollbar at the pane edge, so hide
      // this inset duplicate while leaving the outer scrollbar untouched.
      field = ScrollbarTheme(
        data: const ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll<Color>(Colors.transparent),
          trackColor: WidgetStatePropertyAll<Color>(Colors.transparent),
          thickness: WidgetStatePropertyAll<double>(0),
        ),
        child: field,
      );
    }
    final Map<ShortcutActivator, VoidCallback> bindings = _bindings();
    if (bindings.isEmpty) return field;
    return CallbackShortcuts(bindings: bindings, child: field);
  }
}
