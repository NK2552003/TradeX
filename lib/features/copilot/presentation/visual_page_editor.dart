import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/core/markdown_kit/markdown_preview.dart';

class CopilotVisualPageEditor extends StatefulWidget {
  const CopilotVisualPageEditor({
    super.key,
    required this.source,
    required this.onChanged,
  });
  final TextEditingController source;
  final VoidCallback onChanged;

  @override
  State<CopilotVisualPageEditor> createState() =>
      _CopilotVisualPageEditorState();
}

class _CopilotVisualPageEditorState extends State<CopilotVisualPageEditor> {
  final _fromMarkdown = MarkdownToDelta(
    markdownDocument: md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      blockSyntaxes: const [EmbeddableTableSyntax()],
    ),
    customElementToEmbeddable: {
      EmbeddableTable.tableType: EmbeddableTable.fromMdSyntax,
    },
  );
  final _toMarkdown = DeltaToMarkdown(
    customEmbedHandlers: {
      EmbeddableTable.tableType: EmbeddableTable.toMdSyntax,
    },
  );
  late final _controller = quill.QuillController(
    document: quill.Document.fromDelta(
      _fromMarkdown.convert(widget.source.text),
    ),
    selection: const TextSelection.collapsed(offset: 0),
  );
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late String _lastDelta;
  bool _syncing = false;
  String? _slash;

  static final _formats = <UiEditorAction, quill.Attribute>{
    UiEditorAction.bold: quill.Attribute.bold,
    UiEditorAction.italic: quill.Attribute.italic,
    UiEditorAction.strikethrough: quill.Attribute.strikeThrough,
    UiEditorAction.heading: quill.Attribute.h2,
    UiEditorAction.quote: quill.Attribute.blockQuote,
    UiEditorAction.bulletList: quill.Attribute.ul,
    UiEditorAction.numberedList: quill.Attribute.ol,
    UiEditorAction.codeBlock: quill.Attribute.codeBlock,
  };

  @override
  void initState() {
    super.initState();
    _lastDelta = jsonEncode(_controller.document.toDelta().toJson());
    _controller.addListener(_changed);
    widget.source.addListener(_sourceChanged);
  }

  void _sourceChanged() {
    if (_syncing) return;
    _syncing = true;
    _controller.document = quill.Document.fromDelta(
      _fromMarkdown.convert(widget.source.text),
    );
    _lastDelta = jsonEncode(_controller.document.toDelta().toJson());
    _syncing = false;
  }

  void _changed() {
    if (_syncing) return;
    final delta = _controller.document.toDelta();
    final serialized = jsonEncode(delta.toJson());
    if (serialized != _lastDelta) {
      _lastDelta = serialized;
      _syncing = true;
      widget.source.text = _toMarkdown.convert(delta);
      _syncing = false;
      widget.onChanged();
    }
    final text = _controller.document.toPlainText();
    final offset = _controller.selection.baseOffset.clamp(0, text.length);
    final prefix = text.substring(0, offset).split('\n').last;
    final match = RegExp(r'^/([a-z ]*)$').firstMatch(prefix);
    if (mounted) setState(() => _slash = match?[1]);
  }

  void _format(UiEditorAction action) {
    if (action == UiEditorAction.undo) {
      _controller.undo();
    } else if (action == UiEditorAction.redo) {
      _controller.redo();
    } else if (action == UiEditorAction.link) {
      _link();
    } else {
      final attribute = _formats[action];
      if (attribute == null) return;
      final active =
          _controller.getSelectionStyle().attributes[attribute.key]?.value ==
          attribute.value;
      _controller.formatSelection(
        active ? quill.Attribute.clone(attribute, null) : attribute,
      );
    }
    _focus.requestFocus();
  }

  Future<void> _link() async {
    var url = '';
    final selection = _controller.selection;
    final result = await UiDialog.show<bool>(
      context,
      child: UiDialog(
        title: 'Insert link',
        content: UiInput(
          label: 'Web address',
          onChanged: (value) => url = value,
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
          UiButton(
            label: 'Insert',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      UiToast.error(context, title: 'Enter an HTTP or HTTPS link');
      return;
    }
    if (selection.isCollapsed) {
      _controller.replaceText(
        selection.baseOffset,
        0,
        url,
        TextSelection(
          baseOffset: selection.baseOffset,
          extentOffset: selection.baseOffset + url.length,
        ),
      );
    } else {
      _controller.updateSelection(selection, quill.ChangeSource.local);
    }
    _controller.formatSelection(quill.LinkAttribute(url));
    _focus.requestFocus();
  }

  @override
  void dispose() {
    widget.source.removeListener(_sourceChanged);
    _controller.removeListener(_changed);
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    quill.DefaultTextBlockStyle block(TextStyle style) =>
        quill.DefaultTextBlockStyle(
          style,
          const quill.HorizontalSpacing(0, 0),
          quill.VerticalSpacing(0, context.sp(context.ui.spacing.sm)),
          const quill.VerticalSpacing(0, 0),
          null,
        );
    final active = _controller.getSelectionStyle().attributes;
    return Localizations.override(
      context: context,
      delegates: const [quill.FlutterQuillLocalizations.delegate],
      child: Column(
        children: [
          Expanded(
            child: quill.QuillEditor(
              controller: _controller,
              focusNode: _focus,
              scrollController: _scroll,
              config: quill.QuillEditorConfig(
                expands: true,
                embedBuilders: const [
                  _PageEmbed('image'),
                  _PageEmbed(EmbeddableTable.tableType),
                  _PageEmbed('divider'),
                ],
                unknownEmbedBuilder: const _PageEmbed('unknown'),
                placeholder: 'Make room for an idea. Type / to insert a block.',
                customStyles: quill.DefaultStyles(
                  paragraph: block(context.uiText.body),
                  h1: block(context.uiText.display),
                  h2: block(context.uiText.heading),
                  h3: block(context.uiText.title),
                  placeHolder: block(
                    context.uiText.body.copyWith(
                      color: context.ui.colors.foregroundSubtle,
                    ),
                  ),
                  link: context.uiText.body.copyWith(
                    color: context.ui.colors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
          if (_slash != null &&
              const [
                UiEditorAction.heading,
                UiEditorAction.quote,
                UiEditorAction.bulletList,
                UiEditorAction.numberedList,
                UiEditorAction.codeBlock,
              ].any((a) => a.label.toLowerCase().contains(_slash!)))
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: context.sz(200)),
              child: UiCard(
                variant: UiCardVariant.outlined,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final action in [
                      UiEditorAction.heading,
                      UiEditorAction.quote,
                      UiEditorAction.bulletList,
                      UiEditorAction.numberedList,
                      UiEditorAction.codeBlock,
                    ])
                      if (action.label.toLowerCase().contains(_slash!))
                        UiButton(
                          label: action.label,
                          icon: action.icon,
                          variant: UiVariant.ghost,
                          onPressed: () {
                            final length = _slash!.length + 1;
                            final start =
                                _controller.selection.baseOffset - length;
                            _controller.replaceText(
                              start,
                              length,
                              '',
                              TextSelection.collapsed(offset: start),
                            );
                            _format(action);
                            setState(() => _slash = null);
                          },
                        ),
                  ],
                ),
              ),
            ),
          UiEditorToolbar(
            actions: [
              ..._formats.keys,
              UiEditorAction.link,
              UiEditorAction.undo,
              UiEditorAction.redo,
            ],
            activeActions: {
              for (final entry in _formats.entries)
                if (active[entry.value.key]?.value == entry.value.value)
                  entry.key,
            },
            onAction: _format,
          ),
        ],
      ),
    );
  }
}

class _PageEmbed extends quill.EmbedBuilder {
  const _PageEmbed(this.key);
  @override
  final String key;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final type = embedContext.node.value.type;
    final data = embedContext.node.value.data.toString();
    if (type == 'divider') return const UiDivider();
    if (type == EmbeddableTable.tableType) {
      return RichMarkdownPreview(data: data);
    }
    if (type == 'image') {
      final uri = Uri.tryParse(data);
      if (uri != null && ['http', 'https'].contains(uri.scheme)) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: context.sz(280)),
          child: RichMarkdownPreview(data: '![]($data)'),
        );
      }
    }
    return const UiCallout(
      title: 'Embedded content',
      message: 'Open Markdown mode to edit this block.',
      intent: UiIntent.neutral,
    );
  }
}
