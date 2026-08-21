import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Prompts for a watchlist name. Returns the trimmed name, or `null` on cancel.
Future<String?> showWatchlistNameSheet(
  BuildContext context, {
  String? initialName,
  required List<String> takenNames,
}) => UiDialog.show<String>(
  context,
  child: _WatchlistNameForm(initialName: initialName, takenNames: takenNames),
);

class _WatchlistNameForm extends StatefulWidget {
  const _WatchlistNameForm({required this.takenNames, this.initialName});

  final String? initialName;
  final List<String> takenNames;

  @override
  State<_WatchlistNameForm> createState() => _WatchlistNameFormState();
}

class _WatchlistNameFormState extends State<_WatchlistNameForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the list a name.');
      return;
    }
    final bool clash = widget.takenNames.any(
      (String taken) =>
          taken.toLowerCase() == name.toLowerCase() &&
          taken != widget.initialName,
    );
    if (clash) {
      setState(() => _error = 'You already have a list called "$name".');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.initialName != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                editing ? 'Rename list' : 'New watchlist',
                style: context.uiText.heading,
              ),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        if (_error != null) ...<Widget>[
          UiCallout(
            title: _error!,
            intent: UiIntent.danger,
            onClose: () => setState(() => _error = null),
          ),
          UiGap.v(context.ui.spacing.md),
        ],
        UiField(
          label: 'Name',
          required: true,
          helper: 'Group by strategy, session or conviction.',
          child: UiInput(
            controller: _name,
            hintText: 'Breakout candidates',
            autofocus: true,
            leadingIcon: Icons.playlist_add_check_rounded,
            onSubmitted: (String _) => _submit(),
          ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Cancel',
                variant: UiVariant.ghost,
                expand: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            UiGap.h(context.ui.spacing.md),
            Expanded(
              child: UiButton(
                label: editing ? 'Rename' : 'Create list',
                leadingIcon: editing ? Icons.check_rounded : Icons.add_rounded,
                expand: true,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Multi-select symbol picker. Returns every symbol that should be added.
Future<List<String>?> showAddSymbolsSheet(
  BuildContext context, {
  required String listName,
  required List<String> symbols,
  required List<String> alreadyIn,
}) => UiDialog.show<List<String>>(
  context,
  child: _AddSymbols(
    listName: listName,
    symbols: symbols,
    alreadyIn: alreadyIn,
  ),
);

class _AddSymbols extends StatefulWidget {
  const _AddSymbols({
    required this.listName,
    required this.symbols,
    required this.alreadyIn,
  });

  final String listName;
  final List<String> symbols;
  final List<String> alreadyIn;

  @override
  State<_AddSymbols> createState() => _AddSymbolsState();
}

class _AddSymbolsState extends State<_AddSymbols> {
  final Set<String> _picked = <String>{};
  String _search = '';

  List<String> get _available => widget.symbols
      .where((String s) => !widget.alreadyIn.contains(s))
      .where(
        (String s) =>
            _search.isEmpty || s.toLowerCase().contains(_search.toLowerCase()),
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final List<String> available = _available;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Add symbols', style: context.uiText.heading),
                  UiGap.v(context.ui.spacing.xs),
                  Text(
                    'Into ${widget.listName}',
                    style: context.uiText.caption.copyWith(
                      color: context.uiColors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            UiIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        UiGap.v(context.ui.spacing.lg),
        UiSearchField(
          value: _search,
          hintText: 'Search instruments',
          onChanged: (String value) => setState(() => _search = value),
        ),
        UiGap.v(context.ui.spacing.md),
        Flexible(
          child: available.isEmpty
              ? UiEmptyState(
                  title: _search.isEmpty
                      ? 'Everything is already tracked'
                      : 'No match for "$_search"',
                  message: 'Try another ticker or clear the search.',
                  icon: Icons.search_off_rounded,
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final String symbol in available)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: context.sp(context.ui.spacing.xs),
                          ),
                          child: UiCheckbox(
                            value: _picked.contains(symbol),
                            label: symbol,
                            onChanged: (bool value) => setState(() {
                              if (value) {
                                _picked.add(symbol);
                              } else {
                                _picked.remove(symbol);
                              }
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        UiGap.v(context.ui.spacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: UiButton(
                label: 'Cancel',
                variant: UiVariant.ghost,
                expand: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            UiGap.h(context.ui.spacing.md),
            Expanded(
              child: UiButton(
                label: _picked.isEmpty
                    ? 'Add symbols'
                    : 'Add ${_picked.length} symbol${_picked.length == 1 ? '' : 's'}',
                leadingIcon: Icons.add_rounded,
                expand: true,
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(_picked.toList(growable: false)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
