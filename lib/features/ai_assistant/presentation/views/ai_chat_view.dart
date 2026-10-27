import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Required explicit UI library import for feature widgets.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';

class AiChatView extends StatefulWidget {
  final AiAssistantRepository repository;
  final void Function(AppLinkRef)? onOpenRef;
  final void Function(AiSuggestedAction) onCreateFromChat;
  final VoidCallback? onOpenPersona;
  final VoidCallback? onOpenHistory;

  const AiChatView({
    super.key,
    required this.repository,
    this.onOpenRef,
    required this.onCreateFromChat,
    this.onOpenPersona,
    this.onOpenHistory,
  });

  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> {
  late AiAssistantRepository _repository;
  final TextEditingController _emptyComposerController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void didUpdateWidget(AiChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onRepositoryChanged);
      _repository = widget.repository;
      _repository.addListener(_onRepositoryChanged);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    _emptyComposerController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  void _showAttachmentPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          _AiAttachmentSheet(repository: _repository),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: _repository.activeThread.title,
    );
    UiDialog.show<void>(
      context,
      child: UiDialog(
        title: 'Rename Thread',
        content: Padding(
          padding: EdgeInsets.symmetric(
            vertical: context.sp(context.ui.spacing.sm),
          ),
          child: UiInput(
            label: 'Thread title',
            controller: controller,
            autofocus: true,
          ),
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          UiButton(
            label: 'Save',
            intent: UiIntent.primary,
            onPressed: () {
              final String val = controller.text.trim();
              if (val.isNotEmpty) {
                _repository.renameThread(_repository.activeThreadId, val);
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  void _exportConversation(BuildContext context) {
    final List<AppAiMessage> msgs = _repository.messages;
    if (msgs.isEmpty) {
      UiToastScope.maybeOf(context)?.show(
        UiToastData(
          title: 'Empty conversation',
          message: 'No messages to export.',
          intent: UiIntent.neutral,
        ),
      );
      return;
    }
    final StringBuffer sb = StringBuffer();
    sb.writeln('# ${_repository.activeThread.title}');
    sb.writeln('Persona: ${_repository.persona.label}');
    sb.writeln('---');
    for (final m in msgs) {
      final role = m.role == AppAiRole.user ? 'You' : 'AI Copilot';
      sb.writeln('### $role');
      sb.writeln(m.body);
      sb.writeln();
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    UiToastScope.maybeOf(context)?.show(
      UiToastData(
        title: 'Conversation Exported',
        message: 'Markdown transcript copied to clipboard.',
        intent: UiIntent.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeThread = _repository.activeThread;
    final persona = _repository.persona;
    final messages = _repository.messages;
    final generating = _repository.generating;
    final isEmpty = _repository.isActiveEmpty;
    final actions = _repository.latestActions;

    return AiDensityScope(
      child: Column(
        children: [
          UiBadge(
            label: CustomerDataPolicy.allowDemo && !_repository.usesLiveService
                ? 'Demo assistant · Responses are simulated'
                : (_repository.serviceAvailable
                      ? 'Connected assistant service'
                      : 'Assistant service unavailable'),
            intent: UiIntent.info,
          ),
          // Header area
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(context.ui.spacing.md),
              vertical: context.sp(context.ui.spacing.xs),
            ),
            child: Row(
              children: [
                AiPersonaChip(
                  persona: persona,
                  onTap: widget.onOpenPersona,
                  dense: true,
                ),
                SizedBox(width: context.sp(context.ui.spacing.sm)),
                Expanded(
                  child: Text(
                    activeThread.title,
                    style: context.uiText.title.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                UiIconButton(
                  icon: Icons.add_comment_outlined,
                  tooltip: 'New chat',
                  size: UiSize.sm,
                  onPressed: () => _repository.newThread(),
                ),
                UiDropdownMenu(
                  alignRight: true,
                  items: <UiMenuItem>[
                    UiMenuItem(
                      label: 'Share to Messages',
                      icon: Icons.send_outlined,
                      onPressed: () {
                        final msgs = _repository.messages;
                        if (msgs.isNotEmpty) {
                          final last =
                              msgs
                                  .where((m) => m.role == AppAiRole.assistant)
                                  .lastOrNull ??
                              msgs.last;
                          ShareToConversationDialog.show(
                            context,
                            initialText:
                                '🤖 alphajournal AI Copilot (${_repository.activeThread.title}):\n\n${last.body}',
                          );
                        }
                      },
                    ),
                    UiMenuItem(
                      label: 'Export transcript',
                      icon: Icons.copy_all_outlined,
                      onPressed: () => _exportConversation(context),
                    ),
                    UiMenuItem(
                      label: 'Rename chat',
                      icon: Icons.edit_outlined,
                      onPressed: () => _showRenameDialog(context),
                    ),
                    const UiMenuItem.divider(),
                    UiMenuItem(
                      label: 'Clear messages',
                      icon: Icons.delete_sweep_outlined,
                      intent: UiIntent.warning,
                      onPressed: () {
                        _repository.clearActiveThread();
                        UiToastScope.maybeOf(context)?.show(
                          UiToastData(
                            title: 'Chat Cleared',
                            message: 'Conversation messages cleared.',
                            intent: UiIntent.neutral,
                          ),
                        );
                      },
                    ),
                  ],
                  child: UiIconButton(
                    icon: Icons.more_vert_rounded,
                    tooltip: 'Options',
                    size: UiSize.sm,
                    onPressed: null,
                  ),
                ),
                if (widget.onOpenHistory != null)
                  UiIconButton(
                    icon: Icons.history_rounded,
                    tooltip: 'History',
                    size: UiSize.sm,
                    onPressed: widget.onOpenHistory,
                  ),
              ],
            ),
          ),
          const UiDivider(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kAiChatMaxWidth),
                child: isEmpty
                    ? _buildEmptyState()
                    : _buildChatBlock(messages, generating, actions),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final UiTheme theme = context.ui;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can I help you today?',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  'Select a trading capability or ask anything about setups, risk, and strategies.',
                  style: context.uiText.body.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.md)),
                UiCardGrid(
                  minTileWidth: 230,
                  intrinsicHeight: true,
                  desktopColumns: 2,
                  largeColumns: 2,
                  children: <Widget>[
                    for (final capability in _repository.capabilities)
                      AiCapabilityCard(
                        capability: capability,
                        onTap: () {
                          final AiCreateTarget? target = capability.target;
                          if (target != null) {
                            widget.onCreateFromChat(
                              AiSuggestedAction(target: target),
                            );
                            return;
                          }
                          _repository.sendPrompt(capability.promptSeed);
                        },
                      ),
                  ],
                ),
                if (_repository.quickPrompts.isNotEmpty) ...[
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Text('Quick Questions', style: context.uiText.subheading),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xs),
                    children: _repository.quickPrompts.map((p) {
                      return UiBadge(
                        label: p.label,
                        variant: UiBadgeVariant.outline,
                        onTap: () => _repository.sendPrompt(p.prompt),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildComposerBar(context),
      ],
    );
  }

  Widget _buildComposerBar(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          UiIconButton(
            icon: Icons.add_photo_alternate_outlined,
            tooltip: 'Attach chart setup',
            onPressed: () => _showAttachmentPicker(context),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: UiInput(
              controller: _emptyComposerController,
              enabled: _repository.serviceAvailable && !_repository.generating,
              hintText: 'Message your AI trading coach…',
              maxLines: 4,
              minLines: 1,
              onSubmitted: (text) {
                final trimmed = text.trim();
                if (trimmed.isNotEmpty &&
                    _repository.serviceAvailable &&
                    !_repository.generating) {
                  _emptyComposerController.clear();
                  _repository.sendPrompt(trimmed);
                }
              },
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.sm)),
          UiIconButton(
            icon: Icons.arrow_upward,
            intent: UiIntent.primary,
            variant: UiVariant.solid,
            tooltip: 'Send',
            onPressed: () {
              final trimmed = _emptyComposerController.text.trim();
              if (trimmed.isNotEmpty &&
                  _repository.serviceAvailable &&
                  !_repository.generating) {
                _emptyComposerController.clear();
                _repository.sendPrompt(trimmed);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatBlock(
    List<AppAiMessage> messages,
    bool generating,
    List<AiSuggestedAction> actions,
  ) {
    if (!_repository.serviceAvailable) {
      return const UiEmptyState(
        title: 'Assistant service unavailable',
        message:
            'AI responses require a configured service. No simulated answers are shown in your account.',
      );
    }
    final bool hasAssistantMsg = messages.any(
      (m) => m.role == AppAiRole.assistant && !m.pending,
    );

    return Column(
      children: [
        Expanded(
          child: AppAiChatBlock(
            messages: messages,
            onSend: (text) => _repository.sendPrompt(text),
            prompts: const [],
            generating: generating,
            onStop: () => _repository.stop(),
            onAttach: () => _showAttachmentPicker(context),
            onRetry: (msg) => _repository.regenerate(msg),
            onCopy: (msg) {
              Clipboard.setData(ClipboardData(text: msg.body));
              UiToastScope.maybeOf(context)?.show(
                UiToastData(
                  title: 'Copied',
                  message: 'Message copied to clipboard.',
                  intent: UiIntent.neutral,
                ),
              );
            },
            onShare: (msg) {
              ShareToConversationDialog.show(
                context,
                initialText: '🤖 alphajournal AI Copilot:\n\n${msg.body}',
              );
            },
            onOpenRef: widget.onOpenRef,
            emptyTitle: '',
            emptyMessage: '',
          ),
        ),
        if (actions.isNotEmpty || hasAssistantMsg)
          Padding(
            padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...actions.map((action) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: context.sp(context.ui.spacing.xs),
                      ),
                      child: UiBadge(
                        label: action.effectiveLabel,
                        icon: action.icon,
                        onTap: () => widget.onCreateFromChat(action),
                      ),
                    );
                  }),
                  if (hasAssistantMsg)
                    Padding(
                      padding: EdgeInsets.only(
                        right: context.sp(context.ui.spacing.xs),
                      ),
                      child: UiBadge(
                        label: 'Send in DM',
                        icon: Icons.send_outlined,
                        intent: UiIntent.primary,
                        onTap: () {
                          final last =
                              messages
                                  .where(
                                    (m) =>
                                        m.role == AppAiRole.assistant &&
                                        !m.pending,
                                  )
                                  .lastOrNull ??
                              messages.last;
                          ShareToConversationDialog.show(
                            context,
                            initialText:
                                '🤖 alphajournal AI Copilot (${_repository.activeThread.title}):\n\n${last.body}',
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AiAttachmentSheet extends StatefulWidget {
  const _AiAttachmentSheet({required this.repository});
  final AiAssistantRepository repository;

  @override
  State<_AiAttachmentSheet> createState() => _AiAttachmentSheetState();
}

class _AiAttachmentSheetState extends State<_AiAttachmentSheet> {
  int _selectedTab = 0;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  List<AppTrade>? _trades;
  List<AppNote>? _notes;
  List<AppStrategy>? _strategies;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final List<AppTrade> trades = await JournalRepositoryScope.repository
          .fetchAll();
      final List<AppNote> notes = await NotesRepositoryScope.repository
          .fetchAll();
      final List<AppStrategy> strats = await StrategiesRepositoryScope
          .repository
          .fetchAll();
      if (!mounted) return;
      setState(() {
        _trades = trades;
        _notes = notes;
        _strategies = strats;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _attachPrompt(String prompt, String label) {
    Navigator.of(context).pop();
    widget.repository.sendPrompt(prompt);
    UiToastScope.maybeOf(context)?.show(
      UiToastData(
        title: 'Attached $label',
        message: 'Prompt sent to AI Copilot for analysis.',
        intent: UiIntent.info,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final String q = _query.trim().toLowerCase();

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(context.sp(theme.spacing.sm)),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: context.radius(theme.radii.xl),
          border: Border.all(
            color: colors.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Sheet grabber
            Center(
              child: Container(
                width: context.sz(36),
                height: context.sz(4),
                margin: EdgeInsets.only(
                  top: context.sp(theme.spacing.sm),
                  bottom: context.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: colors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: context.sz(20),
                    color: colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Attach Context to Copilot',
                          style: context.uiText.heading,
                        ),
                        Text(
                          'Feed a technical setup, trade, thesis, or playbook into chat',
                          style: context.uiText.caption.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiIconButton(
                    icon: Icons.close_rounded,
                    size: UiSize.xs,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiTabs(
                variant: UiTabsVariant.segmented,
                tabs: const <String>['Setups', 'Trades', 'Notes', 'Playbooks'],
                selectedIndex: _selectedTab,
                onChanged: (int idx) => setState(() => _selectedTab = idx),
              ),
            ),

            // Search
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiInput.search(
                controller: _searchController,
                hintText: 'Search items…',
                onChanged: (String val) => setState(() => _query = val),
                onClear: () => setState(() {
                  _query = '';
                  _searchController.clear();
                }),
              ),
            ),

            // List of items
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: context.sz(340)),
              child: _loading
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                        child: Text(
                          'Loading records…',
                          style: context.uiText.body.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ),
                    )
                  : _buildTabContent(context, q),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, String q) {
    return switch (_selectedTab) {
      0 => _buildSetupsList(context, q),
      1 => _buildTradesList(context, q),
      2 => _buildNotesList(context, q),
      3 => _buildStrategiesList(context, q),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSetupsList(BuildContext context, String q) {
    final UiTheme theme = context.ui;
    final List<AiChartSetup> setups = widget.repository.chartSetups.where((s) {
      if (q.isEmpty) return true;
      return s.symbol.toLowerCase().contains(q) ||
          s.pattern.toLowerCase().contains(q) ||
          s.rationale.toLowerCase().contains(q);
    }).toList();

    if (setups.isEmpty) {
      return const UiEmptyState(
        icon: Icons.candlestick_chart_outlined,
        title: 'No setups found',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
      itemCount: setups.length,
      itemBuilder: (BuildContext ctx, int i) {
        final AiChartSetup s = setups[i];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          child: UiInteractive(
            onTap: () => _attachPrompt(
              'Analyze technical setup on ${s.symbol} (${s.timeframe}, ${s.pattern}). '
                  'Direction: ${s.direction.label}. Entry: \$${s.entry.toStringAsFixed(2)}, '
                  'Stop: \$${s.stopLoss.toStringAsFixed(2)}, Target: \$${s.target1.toStringAsFixed(2)} '
                  '(R:R ${s.rrRatio.toStringAsFixed(1)}). Rationale: ${s.rationale}. '
                  'Validate thesis, support/resistance levels, and order book confirmation.',
              '${s.symbol} Setup',
            ),
            builder: (BuildContext c, UiInteractiveState state) => Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: state.hovered
                    ? theme.colors.surfaceHover
                    : theme.colors.surface,
                borderRadius: context.radius(theme.radii.md),
                border: Border.all(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.candlestick_chart_rounded,
                    size: context.sz(20),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${s.symbol} • ${s.timeframe}',
                          style: context.uiText.bodyStrong,
                        ),
                        Text(
                          s.pattern,
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: '${s.confidence}% conf',
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTradesList(BuildContext context, String q) {
    final UiTheme theme = context.ui;
    final List<AppTrade> trades = (_trades ?? const <AppTrade>[]).where((t) {
      if (q.isEmpty) return true;
      return t.ticker.toLowerCase().contains(q) ||
          (t.strategy != null && t.strategy!.toLowerCase().contains(q)) ||
          (t.notes != null && t.notes!.toLowerCase().contains(q));
    }).toList();

    if (trades.isEmpty) {
      return const UiEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No journal trades found',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
      itemCount: trades.length,
      itemBuilder: (BuildContext ctx, int i) {
        final AppTrade t = trades[i];
        final bool isWin = t.pnl >= 0;
        final String rStr = t.rMultiple != null
            ? '${t.rMultiple!.toStringAsFixed(1)}R'
            : '1.0R';
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          child: UiInteractive(
            onTap: () => _attachPrompt(
              'Analyze my journal trade: ${t.side.name.toUpperCase()} ${t.ticker} '
                  '(Entry: \$${t.entry.toStringAsFixed(2)}, Exit: ${t.exit != null ? '\$${t.exit!.toStringAsFixed(2)}' : 'Open'}, '
                  'PnL: ${isWin ? '+' : ''}\$${t.pnl.toStringAsFixed(2)}, R:R: $rStr). '
                  'Strategy: ${t.strategy ?? 'Discretionary'}. Notes: ${t.notes ?? 'None'}. '
                  'Provide feedback on execution discipline, trade management, and rule adherence.',
              '${t.ticker} Trade',
            ),
            builder: (BuildContext c, UiInteractiveState state) => Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: state.hovered
                    ? theme.colors.surfaceHover
                    : theme.colors.surface,
                borderRadius: context.radius(theme.radii.md),
                border: Border.all(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.receipt_long_rounded,
                    size: context.sz(20),
                    color: isWin ? theme.colors.bullish : theme.colors.bearish,
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${t.side.name.toUpperCase()} ${t.ticker}',
                          style: context.uiText.bodyStrong,
                        ),
                        Text(
                          '${t.strategy} • Entry: \$${t.entry.toStringAsFixed(2)}',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: '${isWin ? '+' : ''}\$${t.pnl.toStringAsFixed(0)}',
                    intent: isWin ? UiIntent.success : UiIntent.danger,
                    size: UiSize.xs,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesList(BuildContext context, String q) {
    final UiTheme theme = context.ui;
    final List<AppNote> notes = (_notes ?? const <AppNote>[]).where((n) {
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
    }).toList();

    if (notes.isEmpty) {
      return const UiEmptyState(
        icon: Icons.description_outlined,
        title: 'No notes found',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
      itemCount: notes.length,
      itemBuilder: (BuildContext ctx, int i) {
        final AppNote n = notes[i];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          child: UiInteractive(
            onTap: () => _attachPrompt(
              'Review my trade thesis from Note "${n.title}":\n\n'
                  '"${n.content}"\n\n'
                  'Evaluate thesis logic, identify potential macroeconomic or sector headwinds, '
                  'and formulate specific confirmation milestones.',
              'Note "${n.title}"',
            ),
            builder: (BuildContext c, UiInteractiveState state) => Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: state.hovered
                    ? theme.colors.surfaceHover
                    : theme.colors.surface,
                borderRadius: context.radius(theme.radii.md),
                border: Border.all(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.description_outlined,
                    size: context.sz(20),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.bodyStrong,
                        ),
                        Text(
                          '${n.noteType.label} • ${n.wordCount} words',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: n.noteType.label,
                    variant: UiBadgeVariant.soft,
                    intent: UiIntent.neutral,
                    size: UiSize.xs,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStrategiesList(BuildContext context, String q) {
    final UiTheme theme = context.ui;
    final List<AppStrategy> strategies = (_strategies ?? const <AppStrategy>[])
        .where((s) {
          if (q.isEmpty) return true;
          return s.name.toLowerCase().contains(q) ||
              (s.category != null && s.category!.toLowerCase().contains(q)) ||
              (s.summary != null && s.summary!.toLowerCase().contains(q));
        })
        .toList();

    if (strategies.isEmpty) {
      return const UiEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No playbooks found',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.md)),
      itemCount: strategies.length,
      itemBuilder: (BuildContext ctx, int i) {
        final AppStrategy s = strategies[i];
        final String categoryText = s.category ?? 'Playbook';
        final String summaryText = (s.summary != null && s.summary!.isNotEmpty)
            ? s.summary!
            : categoryText;
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
          child: UiInteractive(
            onTap: () => _attachPrompt(
              'Audit my trading playbook "${s.name}" ($categoryText, status: ${s.status.name}). '
                  'Summary: $summaryText. Content: ${s.content}. '
                  'Suggest quantitative edge optimizations, win-rate improvements, and strict risk-management parameters.',
              'Playbook "${s.name}"',
            ),
            builder: (BuildContext c, UiInteractiveState state) => Container(
              padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
              decoration: BoxDecoration(
                color: state.hovered
                    ? theme.colors.surfaceHover
                    : theme.colors.surface,
                borderRadius: context.radius(theme.radii.md),
                border: Border.all(
                  color: theme.colors.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.menu_book_rounded,
                    size: context.sz(20),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.bodyStrong,
                        ),
                        Text(
                          summaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge(
                    label: s.status.name.toUpperCase(),
                    variant: UiBadgeVariant.soft,
                    intent: UiIntent.primary,
                    size: UiSize.xs,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
