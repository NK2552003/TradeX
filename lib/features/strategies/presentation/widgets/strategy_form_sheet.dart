import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// Create/edit form for a playbook. Sheet on phones, dialog on desktop.
///
/// Performance fields (trades, win rate, R, equity) are owned by the journal,
/// so they are carried over from [initial] untouched and never edited here.
Future<AppStrategy?> showStrategyFormSheet(
  BuildContext context, {
  AppStrategy? initial,
  required List<String> categories,
}) => UiDialog.show<AppStrategy>(
  context,
  child: _StrategyForm(initial: initial, categories: categories),
);

const String _newCategory = '__new__';

class _StrategyForm extends StatefulWidget {
  const _StrategyForm({required this.categories, this.initial});

  final AppStrategy? initial;
  final List<String> categories;

  @override
  State<_StrategyForm> createState() => _StrategyFormState();
}

class _StrategyFormState extends State<_StrategyForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _summary = TextEditingController(
    text: widget.initial?.summary ?? '',
  );
  late final TextEditingController _newCategoryName = TextEditingController();
  late String _category = widget.initial?.category ?? '';
  late bool _isPublic = widget.initial?.isPublic ?? false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _summary.dispose();
    _newCategoryName.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the playbook a name.');
      return;
    }
    String? category = _category.isEmpty ? null : _category;
    if (_category == _newCategory) {
      final String custom = _newCategoryName.text.trim();
      if (custom.isEmpty) {
        setState(() => _error = 'Name the new category or pick an existing one.');
        return;
      }
      category = custom;
    }

    final AppStrategy? initial = widget.initial;
    Navigator.of(context).pop(
      AppStrategy(
        id: initial?.id ?? 'stg_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        summary: _summary.text.trim().isEmpty ? null : _summary.text.trim(),
        category: category,
        isPublic: _isPublic,
        isFavorite: initial?.isFavorite ?? false,
        trades: initial?.trades ?? 0,
        winRate: initial?.winRate ?? 0,
        avgR: initial?.avgR ?? 0,
        netPnl: initial?.netPnl ?? 0,
        updatedAt: DateTime.now(),
        versionCount: (initial?.versionCount ?? 0) + 1,
        equityCurve: initial?.equityCurve ?? const <double>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.initial != null;
    final double gap = context.ui.spacing.md;

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
                  Text(
                    editing ? 'Edit playbook' : 'New playbook',
                    style: context.uiText.heading,
                  ),
                  UiGap.v(context.ui.spacing.xs),
                  Text(
                    'Rules you can hold yourself to — the journal scores them for you.',
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
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  UiCallout(
                    title: _error!,
                    intent: UiIntent.danger,
                    onClose: () => setState(() => _error = null),
                  ),
                  UiGap.v(gap),
                ],
                UiField(
                  label: 'Name',
                  required: true,
                  child: UiInput(
                    controller: _name,
                    hintText: 'Opening range breakout',
                    leadingIcon: Icons.account_tree_outlined,
                  ),
                ),
                UiGap.v(gap),
                UiField(
                  label: 'Category',
                  child: UiSelect<String>(
                    options: <UiOption<String>>[
                      const UiOption<String>(value: '', label: 'Uncategorised'),
                      for (final String category in widget.categories)
                        UiOption<String>(value: category, label: category),
                      const UiOption<String>(
                        value: _newCategory,
                        label: 'New category…',
                        icon: Icons.add_rounded,
                      ),
                    ],
                    value: _category,
                    onChanged: (String value) =>
                        setState(() => _category = value),
                  ),
                ),
                if (_category == _newCategory) ...<Widget>[
                  UiGap.v(gap),
                  UiField(
                    label: 'New category name',
                    required: true,
                    child: UiInput(
                      controller: _newCategoryName,
                      hintText: 'Momentum',
                      autofocus: true,
                    ),
                  ),
                ],
                UiGap.v(gap),
                UiTextarea(
                  controller: _summary,
                  label: 'Rules and thesis',
                  rows: 5,
                  maxRows: 10,
                  maxLength: 800,
                  hintText:
                      'Entry trigger, invalidation, position sizing and the market regime it needs.',
                ),
                UiGap.v(gap),
                UiSwitch(
                  value: _isPublic,
                  asCard: true,
                  label: 'Share with the community',
                  description:
                      'Public playbooks appear on your profile and in the leaderboard.',
                  onChanged: (bool value) => setState(() => _isPublic = value),
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
            UiGap.h(gap),
            Expanded(
              child: UiButton(
                label: editing ? 'Save playbook' : 'Create playbook',
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
