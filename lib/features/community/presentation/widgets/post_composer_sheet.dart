import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Kinds of post the composer can publish. Stored on [AppPost.type] as the
/// lowercase enum name so the backend keeps a stable vocabulary.
enum PostKind { idea, analysis, lesson, question }

String postKindLabel(PostKind kind) => switch (kind) {
  PostKind.idea => 'Idea',
  PostKind.analysis => 'Analysis',
  PostKind.lesson => 'Lesson',
  PostKind.question => 'Question',
};

IconData postKindIcon(PostKind kind) => switch (kind) {
  PostKind.idea => Icons.lightbulb_outline_rounded,
  PostKind.analysis => Icons.insights_rounded,
  PostKind.lesson => Icons.school_outlined,
  PostKind.question => Icons.help_outline_rounded,
};

/// Composer sheet: body, kind, tagged instruments and an optional playbook
/// attachment, with a live preview of the card the feed will render.
///
/// Returns the post to publish, or `null` when dismissed.
Future<AppPost?> showPostComposerSheet(
  BuildContext context, {
  required AppTrader me,
  required List<String> symbols,
  String? initialBody,
  List<String> initialTickers = const <String>[],
  List<String> playbooks = const <String>[],
}) => UiDialog.show<AppPost>(
  context,
  child: _PostComposer(
    me: me,
    symbols: symbols,
    initialBody: initialBody,
    initialTickers: initialTickers,
    playbooks: playbooks,
  ),
);

class _PostComposer extends StatefulWidget {
  const _PostComposer({
    required this.me,
    required this.symbols,
    required this.initialTickers,
    required this.playbooks,
    this.initialBody,
  });

  final AppTrader me;
  final List<String> symbols;
  final String? initialBody;
  final List<String> initialTickers;
  final List<String> playbooks;

  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  static const int _maxLength = 600;

  late final TextEditingController _body = TextEditingController(
    text: widget.initialBody ?? '',
  );
  late List<String> _tickers = <String>[...widget.initialTickers];
  PostKind _kind = PostKind.idea;
  String? _playbook;
  bool _preview = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _body.addListener(_onBodyChanged);
  }

  @override
  void dispose() {
    _body.removeListener(_onBodyChanged);
    _body.dispose();
    super.dispose();
  }

  void _onBodyChanged() => setState(() {});

  /// Instruments mentioned as `$SYMBOL` in the body get tagged automatically so
  /// the trader never has to duplicate the work.
  List<String> get _mentioned {
    final String text = _body.text.toUpperCase();
    return widget.symbols
        .where((String s) => text.contains('\$$s'))
        .where((String s) => !_tickers.contains(s))
        .toList(growable: false);
  }

  List<String> get _allTickers =>
      <String>{..._tickers, ..._mentioned}.toList(growable: false);

  int get _remaining => _maxLength - _body.text.characters.length;

  AppPost _draft() => AppPost(
    id: 'post_${DateTime.now().microsecondsSinceEpoch}',
    author: widget.me,
    body: _body.text.trim(),
    createdAt: DateTime.now(),
    type: _kind.name,
    tickers: _allTickers,
    attachments: <AppPostAttachment>[
      if (_playbook != null) AppPostStrategyAttachment(_playbook!),
    ],
  );

  void _submit() {
    final String body = _body.text.trim();
    if (body.length < 8) {
      setState(() => _error = 'Write at least a sentence before posting.');
      return;
    }
    if (_remaining < 0) {
      setState(
        () => _error = 'Trim ${-_remaining} characters to fit the limit.',
      );
      return;
    }
    Navigator.of(context).pop(_draft());
  }

  @override
  Widget build(BuildContext context) {
    final List<String> mentioned = _mentioned;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Compose', style: context.uiText.heading),
            ),
            UiIconButton(
              icon: _preview
                  ? Icons.edit_outlined
                  : Icons.visibility_outlined,
              tooltip: _preview ? 'Back to editing' : 'Preview',
              onPressed: () => setState(() => _preview = !_preview),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        Flexible(
          child: SingleChildScrollView(
            child: _preview ? _previewBody() : _editBody(mentioned),
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          children: <Widget>[
            Text(
              '$_remaining left',
              style: context.uiText.caption.copyWith(
                color: _remaining < 0
                    ? context.uiColors.bearish
                    : context.uiColors.foregroundMuted,
              ),
            ),
            const Spacer(),
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              expandOnMobile: false,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            UiGap.h(context.ui.spacing.sm),
            UiButton(
              label: 'Publish',
              leadingIcon: Icons.send_rounded,
              expandOnMobile: false,
              onPressed: _body.text.trim().isEmpty ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _editBody(List<String> mentioned) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (_error != null) ...<Widget>[
        UiCallout(
          title: _error!,
          intent: UiIntent.danger,
          onClose: () => setState(() => _error = null),
        ),
        UiGap.v(context.ui.spacing.md),
      ],
      AppTraderRow(
        trader: widget.me,
        trailingLabel: postKindLabel(_kind).toLowerCase(),
      ),
      UiGap.v(context.ui.spacing.md),
      UiToggleGroup<PostKind>(
        options: <UiToggleOption<PostKind>>[
          for (final PostKind kind in PostKind.values)
            UiToggleOption<PostKind>(
              value: kind,
              label: postKindLabel(kind),
              icon: postKindIcon(kind),
            ),
        ],
        value: _kind,
        expand: context.uiRes.isMobile,
        onChanged: (PostKind kind) => setState(() => _kind = kind),
      ),
      UiGap.v(context.ui.spacing.md),
      UiTextarea(
        controller: _body,
        label: 'Your take',
        required: true,
        hintText:
            'What is the setup, what invalidates it, and how are you sizing it?',
        rows: 5,
        maxRows: 12,
        maxLength: _maxLength,
        autofocus: true,
        helper: r'Type $SYMBOL to tag an instrument inline.',
      ),
      UiGap.v(context.ui.spacing.md),
      UiField(
        label: 'Instruments',
        helper: 'Tagged posts show up in those instrument feeds.',
        child: UiTagInput(
          tags: _tickers,
          prefix: r'$',
          suggestions: widget.symbols,
          maxTags: 6,
          hintText: 'Add a ticker',
          onChanged: (List<String> tags) => setState(
            () => _tickers = tags
                .map((String t) => t.toUpperCase())
                .toList(growable: false),
          ),
        ),
      ),
      if (mentioned.isNotEmpty) ...<Widget>[
        UiGap.v(context.ui.spacing.sm),
        UiCallout(
          title: 'Detected ${mentioned.join(', ')} in your text',
          message: 'They will be tagged automatically when you publish.',
          intent: UiIntent.info,
        ),
      ],
      if (widget.playbooks.isNotEmpty) ...<Widget>[
        UiGap.v(context.ui.spacing.md),
        UiField(
          label: 'Attach a playbook',
          helper: 'Optional — links the post to one of your strategies.',
          child: UiSelect<String>(
            options: <UiOption<String>>[
              const UiOption<String>(value: '', label: 'No attachment'),
              for (final String name in widget.playbooks)
                UiOption<String>(value: name, label: name),
            ],
            value: _playbook ?? '',
            leadingIcon: Icons.auto_graph_rounded,
            onChanged: (String value) =>
                setState(() => _playbook = value.isEmpty ? null : value),
          ),
        ),
      ],
    ],
  );

  Widget _previewBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        'This is exactly how the feed will render it.',
        style: context.uiText.caption.copyWith(
          color: context.uiColors.foregroundMuted,
        ),
      ),
      UiGap.v(context.ui.spacing.md),
      AppPostCard(post: _draft()),
    ],
  );
}
