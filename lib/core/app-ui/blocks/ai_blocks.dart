import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../cards/ai_cards.dart';
import '../models/app_models.dart';
import '../models/app_models_extra.dart';
import '../motion/app_motion.dart';

/// Full AI assistant surface: scrolling thread, suggested prompts and a
/// composer with send / attach / stop-generation controls.
class AppAiChatBlock extends StatefulWidget {
  const AppAiChatBlock({
    super.key,
    required this.messages,
    required this.onSend,
    this.prompts = const <AppAiPrompt>[],
    this.generating = false,
    this.onStop,
    this.onAttach,
    this.onRetry,
    this.onCopy,
    this.onShare,
    this.onOpenRef,
    this.messageActionsBuilder,
    this.messageBuilder,
    this.emptyTitle = 'Ask about your trading',
    this.emptyMessage =
        'Summarise this week, review a setup, or stress-test a strategy.',
    this.emptyState,
    this.composer,
    this.composerController,
    this.composerHint = 'Message your AI trading coach',
    this.canSend = true,
  });

  final List<AppAiMessage> messages;
  final ValueChanged<String> onSend;
  final List<AppAiPrompt> prompts;
  final bool generating;
  final VoidCallback? onStop;
  final VoidCallback? onAttach;
  final ValueChanged<AppAiMessage>? onRetry;
  final ValueChanged<AppAiMessage>? onCopy;
  final ValueChanged<AppAiMessage>? onShare;
  final void Function(AppLinkRef ref)? onOpenRef;

  /// Per-message extra actions (e.g. "Save note", "Log trade") rendered under
  /// each settled answer. Null by default — existing callers are unaffected.
  final List<Widget>? Function(AppAiMessage message)? messageActionsBuilder;

  /// Optional feature-specific renderer for a complete message row.
  final Widget Function(BuildContext context, AppAiMessage message)?
  messageBuilder;
  final String emptyTitle;
  final String emptyMessage;
  final Widget? emptyState;
  final Widget? composer;
  final TextEditingController? composerController;
  final String composerHint;
  final bool canSend;

  @override
  State<AppAiChatBlock> createState() => _AppAiChatBlockState();
}

class _AppAiChatBlockState extends State<AppAiChatBlock> {
  late final TextEditingController _controller =
      widget.composerController ?? TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _followEnd();
  }

  @override
  void didUpdateWidget(AppAiChatBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length ||
        oldWidget.messages.lastOrNull?.body !=
            widget.messages.lastOrNull?.body) {
      if (!_scroll.hasClients || _scroll.position.extentAfter < 100) {
        _followEnd();
      }
    }
  }

  void _followEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    if (widget.composerController == null) _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (!widget.canSend || widget.generating) return;
    final String text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      children: <Widget>[
        Expanded(
          child: widget.messages.isEmpty
              ? widget.emptyState ??
                    UiEmptyState(
                      title: widget.emptyTitle,
                      message: widget.emptyMessage,
                      icon: Icons.auto_awesome,
                    )
              : ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.symmetric(
                    vertical: context.sp(theme.spacing.md),
                  ),
                  itemCount: widget.messages.length,
                  itemBuilder: (BuildContext ctx, int i) => AppFadeIn(
                    child:
                        widget.messageBuilder?.call(ctx, widget.messages[i]) ??
                        AppAiMessageBubble(
                          message: widget.messages[i],
                          onCopy: widget.onCopy == null
                              ? null
                              : () => widget.onCopy!(widget.messages[i]),
                          onRetry: widget.onRetry == null
                              ? null
                              : () => widget.onRetry!(widget.messages[i]),
                          onShare: widget.onShare == null
                              ? null
                              : () => widget.onShare!(widget.messages[i]),
                          onOpenRef: widget.onOpenRef,
                          actionsBuilder: widget.messageActionsBuilder,
                        ),
                  ),
                ),
        ),
        if (widget.prompts.isNotEmpty) ...<Widget>[
          AppAiPromptChips(
            prompts: widget.prompts,
            onSelect: (AppAiPrompt p) {
              _controller.text = p.prompt;
              _send();
            },
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
        ],
        widget.composer ??
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (widget.onAttach != null)
                  UiIconButton(
                    icon: Icons.add_photo_alternate_outlined,
                    tooltip: 'Attach chart',
                    onPressed: widget.onAttach,
                  ),
                Expanded(
                  child: UiInput(
                    controller: _controller,
                    hintText: widget.composerHint,
                    enabled: widget.canSend && !widget.generating,
                    maxLines: 4,
                    minLines: 1,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.sm)),
                if (widget.generating)
                  UiIconButton(
                    icon: Icons.stop_circle_outlined,
                    variant: UiVariant.outline,
                    tooltip: 'Stop',
                    onPressed: widget.onStop,
                  )
                else
                  UiIconButton(
                    icon: Icons.arrow_upward,
                    variant: UiVariant.primary,
                    tooltip: 'Send',
                    onPressed: widget.canSend ? _send : null,
                  ),
              ],
            ),
      ],
    );
  }
}

/// Stack of AI insight cards (dashboard "AI review" rail).
class AppAiInsightsBlock extends StatelessWidget {
  const AppAiInsightsBlock({
    super.key,
    required this.insights,
    this.loading = false,
    this.onAsk,
    this.onDismiss,
    this.onGenerate,
  });

  final List<AppAiInsight> insights;
  final bool loading;
  final ValueChanged<AppAiInsight>? onAsk;
  final ValueChanged<AppAiInsight>? onDismiss;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiAsyncView(
      loading: loading,
      isEmpty: insights.isEmpty,
      emptyTitle: 'No AI insights yet',
      emptyMessage: 'Generate a review of your recent trades.',
      emptyIcon: Icons.auto_awesome,
      emptyAction: UiButton(
        label: 'Generate review',
        leadingIcon: Icons.auto_awesome,
        expandOnMobile: false,
        onPressed: onGenerate,
      ),
      builder: (BuildContext ctx) => Column(
        children: <Widget>[
          for (int i = 0; i < insights.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: ctx.sp(theme.spacing.md)),
              child: AppFadeIn(
                delay: Duration(milliseconds: 50 * i),
                child: AppAiAnalysisCard(
                  insight: insights[i],
                  onAsk: onAsk == null ? null : () => onAsk!(insights[i]),
                  onDismiss: onDismiss == null
                      ? null
                      : () => onDismiss!(insights[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Strategy relationship graph with legend and detail pane hook.
class AppStrategyGraphBlock extends StatelessWidget {
  const AppStrategyGraphBlock({
    super.key,
    required this.nodes,
    required this.links,
    this.selectedId,
    this.onSelect,
    this.height,
  });

  final List<AppGraphNode> nodes;
  final List<AppGraphLink> links;
  final String? selectedId;
  final ValueChanged<String?>? onSelect;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Map<String, UiIntent> groups = <String, UiIntent>{
      for (final AppGraphNode n in nodes)
        if (n.group != null) n.group!: n.intent,
    };
    return UiCard(
      title: 'Relationship graph',
      subtitle: 'How strategies, tickers and setups connect',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          UiGraphCanvas(
            height: height,
            selectedId: selectedId,
            onSelect: onSelect == null
                ? null
                : (UiGraphNode? node) => onSelect!(node?.id),
            nodes: <UiGraphNode>[
              for (final AppGraphNode n in nodes)
                UiGraphNode(
                  id: n.id,
                  label: n.label,
                  group: n.group,
                  intent: n.intent,
                  weight: n.weight,
                ),
            ],
            edges: <UiGraphEdge>[
              for (final AppGraphLink l in links)
                UiGraphEdge(
                  from: l.source,
                  to: l.target,
                  label: l.label,
                  strength: l.strength,
                ),
            ],
          ),
          if (groups.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiGraphLegend(vertical: false, entries: groups),
          ],
        ],
      ),
    );
  }
}
