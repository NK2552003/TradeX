import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';

import '../data/copilot_feature_connector.dart';

/// Opens a multi-tab modal allowing the user to attach Notes, Journal trades,
/// Strategy playbooks, Community posts, or Watchlist symbols directly into the
/// AI Copilot conversation.
Future<void> showCopilotConnectDialog(
  BuildContext context, {
  required ValueChanged<CopilotConnectedItem> onAttach,
}) => UiDialog.show<void>(
  context,
  maxWidth: 680,
  child: _CopilotConnectModal(onAttach: onAttach),
);

class _CopilotConnectModal extends StatefulWidget {
  const _CopilotConnectModal({required this.onAttach});
  final ValueChanged<CopilotConnectedItem> onAttach;

  @override
  State<_CopilotConnectModal> createState() => _CopilotConnectModalState();
}

class _CopilotConnectModalState extends State<_CopilotConnectModal> {
  CopilotFeatureCategory _category = CopilotFeatureCategory.notes;
  String _query = '';
  bool _loading = true;
  List<CopilotConnectedItem> _items = const <CopilotConnectedItem>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final List<CopilotConnectedItem> loaded =
        await CopilotFeatureConnector.fetchConnectableItems();
    if (!mounted) return;
    setState(() {
      _items = loaded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<CopilotConnectedItem> filtered = _items.where((
      CopilotConnectedItem item,
    ) {
      if (item.category != _category) return false;
      if (_query.trim().isEmpty) return true;
      final String q = _query.toLowerCase();
      return item.title.toLowerCase().contains(q) ||
          item.subtitle.toLowerCase().contains(q) ||
          item.markdownContext.toLowerCase().contains(q);
    }).toList();

    return UiDialog(
      title: 'Connect workspace context',
      description:
          'Attach Notes, Journal trades, Strategy playbooks, Community posts, or Watchlist symbols into your AI Copilot conversation.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiTabs(
            tabs: <String>[
              for (final CopilotFeatureCategory c
                  in CopilotFeatureCategory.values)
                c.label,
            ],
            selectedIndex: CopilotFeatureCategory.values.indexOf(_category),
            onChanged: (int index) => setState(
              () => _category = CopilotFeatureCategory.values[index],
            ),
          ),
          UiGap.v(theme.spacing.sm),
          UiInput.search(
            value: _query,
            hintText: 'Search ${_category.label.toLowerCase()}…',
            onChanged: (String v) => setState(() => _query = v),
            onClear: () => setState(() => _query = ''),
          ),
          UiGap.v(theme.spacing.sm),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: context.sz(220),
              maxHeight: context.sz(340),
            ),
            child: _loading
                ? const Center(child: UiSkeleton(width: 240, height: 48))
                : filtered.isEmpty
                ? UiEmptyState(
                    icon: _category.icon,
                    title: 'No ${_category.label.toLowerCase()} found',
                    message:
                        'Create a ${_category.label.toLowerCase()} item or switch tabs to attach other workspace records.',
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => UiGap.v(theme.spacing.xs),
                    itemBuilder: (BuildContext context, int index) {
                      final CopilotConnectedItem item = filtered[index];
                      return UiCard(
                        variant: UiCardVariant.subtle,
                        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                        title: item.title,
                        subtitle: item.subtitle,
                        leading: Icon(
                          item.category.icon,
                          size: context.sz(theme.sizes.iconMd),
                          color: theme.colors.primary,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (item.badge != null) ...<Widget>[
                              UiBadge(
                                label: item.badge!,
                                intent: item.intent,
                                size: UiSize.xs,
                              ),
                              UiGap.h(theme.spacing.xs),
                            ],
                            UiButton(
                              label: 'Attach',
                              icon: Icons.add_link_rounded,
                              size: UiSize.xs,
                              variant: UiVariant.soft,
                              onPressed: () {
                                widget.onAttach(item);
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                        child: const SizedBox.shrink(),
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: <Widget>[
        UiButton(
          label: 'Done',
          variant: UiVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Opens a modal dialog to save or publish an AI Copilot response directly into
/// Notes, Journal, Strategies, or Community Posts.
Future<void> showSaveToFeatureDialog(
  BuildContext context, {
  required CopilotFeatureTarget initialTarget,
  required String markdownBody,
  ValueChanged<AppLinkRef>? onOpenRef,
}) => UiDialog.show<void>(
  context,
  maxWidth: 680,
  child: _SaveToFeatureModal(
    initialTarget: initialTarget,
    markdownBody: markdownBody,
    onOpenRef: onOpenRef,
  ),
);

class _SaveToFeatureModal extends StatefulWidget {
  const _SaveToFeatureModal({
    required this.initialTarget,
    required this.markdownBody,
    this.onOpenRef,
  });

  final CopilotFeatureTarget initialTarget;
  final String markdownBody;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  State<_SaveToFeatureModal> createState() => _SaveToFeatureModalState();
}

class _SaveToFeatureModalState extends State<_SaveToFeatureModal> {
  late CopilotFeatureTarget _target = widget.initialTarget;
  late String _title = CopilotFeatureConnector.deriveTitle(widget.markdownBody);
  late String _ticker = () {
    final List<String> found = CopilotFeatureConnector.extractTickers(
      widget.markdownBody,
    );
    return found.isNotEmpty ? found.first : 'NVDA';
  }();
  AppSide _side = AppSide.long;
  String _entry = '125.00';
  String _exit = '134.50';
  String _pnl = '950.00';
  String _category = 'Momentum & Breakout';
  AppNoteType _noteType = AppNoteType.analysis;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      late final AppLinkRef createdRef;
      late final String successTitle;
      switch (_target) {
        case CopilotFeatureTarget.note:
          final res = await CopilotFeatureConnector.saveAsNote(
            body: widget.markdownBody,
            title: _title,
            noteType: _noteType,
          );
          createdRef = res.ref;
          successTitle = 'Saved to Notes';
        case CopilotFeatureTarget.journal:
          final res = await CopilotFeatureConnector.logAsJournalTrade(
            body: widget.markdownBody,
            title: _title,
            ticker: _ticker,
            side: _side,
            entry: double.tryParse(_entry) ?? 100.0,
            exit: double.tryParse(_exit) ?? 108.0,
            pnl: double.tryParse(_pnl) ?? 800.0,
          );
          createdRef = res.ref;
          successTitle = 'Logged to Trade Journal';
        case CopilotFeatureTarget.strategy:
          final res = await CopilotFeatureConnector.saveAsStrategy(
            body: widget.markdownBody,
            name: _title,
            category: _category,
          );
          createdRef = res.ref;
          successTitle = 'Saved to Strategy Playbooks';
        case CopilotFeatureTarget.community:
          final res = await CopilotFeatureConnector.publishCommunityPost(
            body: widget.markdownBody,
            title: _title,
            tickers: <String>[_ticker],
          );
          createdRef = res.ref;
          successTitle = 'Shared to Community Feed';
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      UiToast.success(
        context,
        title: successTitle,
        message: createdRef.title,
      );
      widget.onOpenRef?.call(createdRef);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiDialog(
      title: _target.label,
      description:
          'Send this AI Copilot response directly into your connected TradeX workspace.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiTabs(
            tabs: const <String>['Note', 'Journal', 'Strategy', 'Community'],
            selectedIndex: CopilotFeatureTarget.values.indexOf(_target),
            onChanged: (int index) => setState(
              () => _target = CopilotFeatureTarget.values[index],
            ),
          ),
          UiGap.v(theme.spacing.md),
          UiInput(
            label: _target == CopilotFeatureTarget.strategy
                ? 'Playbook name'
                : (_target == CopilotFeatureTarget.community
                      ? 'Post headline'
                      : 'Title'),
            value: _title,
            onChanged: (String v) => _title = v,
          ),
          UiGap.v(theme.spacing.sm),
          if (_target == CopilotFeatureTarget.note)
            UiSelect<AppNoteType>(
              label: 'Note type',
              value: _noteType,
              expand: true,
              options: <UiOption<AppNoteType>>[
                for (final AppNoteType t in AppNoteType.values)
                  UiOption<AppNoteType>(
                    label: t.label,
                    value: t,
                    icon: t.icon,
                  ),
              ],
              onChanged: (AppNoteType v) => setState(() => _noteType = v),
            ),
          if (_target == CopilotFeatureTarget.journal) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: UiInput(
                    label: 'Symbol',
                    value: _ticker,
                    onChanged: (String v) => _ticker = v,
                  ),
                ),
                UiGap.h(theme.spacing.sm),
                Expanded(
                  child: UiToggleGroup<AppSide>(
                    label: 'Direction',
                    value: _side,
                    expand: true,
                    options: const <UiToggleOption<AppSide>>[
                      UiToggleOption<AppSide>(
                        value: AppSide.long,
                        label: 'Long',
                      ),
                      UiToggleOption<AppSide>(
                        value: AppSide.short,
                        label: 'Short',
                      ),
                    ],
                    onChanged: (AppSide v) => setState(() => _side = v),
                  ),
                ),
              ],
            ),
            UiGap.v(theme.spacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: UiInput(
                    label: 'Entry',
                    value: _entry,
                    onChanged: (String v) => _entry = v,
                  ),
                ),
                UiGap.h(theme.spacing.sm),
                Expanded(
                  child: UiInput(
                    label: 'Exit',
                    value: _exit,
                    onChanged: (String v) => _exit = v,
                  ),
                ),
                UiGap.h(theme.spacing.sm),
                Expanded(
                  child: UiInput(
                    label: 'Net PnL',
                    value: _pnl,
                    onChanged: (String v) => _pnl = v,
                  ),
                ),
              ],
            ),
          ],
          if (_target == CopilotFeatureTarget.strategy)
            UiInput(
              label: 'Strategy category',
              value: _category,
              onChanged: (String v) => _category = v,
            ),
          if (_target == CopilotFeatureTarget.community)
            UiInput(
              label: 'Primary ticker',
              value: _ticker,
              onChanged: (String v) => _ticker = v,
            ),
          UiGap.v(theme.spacing.md),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: context.sz(200)),
            child: SingleChildScrollView(
              child: RichMarkdownPreview(data: widget.markdownBody),
            ),
          ),
          if (_error != null) ...<Widget>[
            UiGap.v(theme.spacing.sm),
            UiCallout(
              title: 'Could not save',
              message: _error!,
              intent: UiIntent.warning,
            ),
          ],
        ],
      ),
      actions: <Widget>[
        UiButton(
          label: 'Cancel',
          variant: UiVariant.ghost,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
        UiButton(
          label: _target.label,
          icon: _target.icon,
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
