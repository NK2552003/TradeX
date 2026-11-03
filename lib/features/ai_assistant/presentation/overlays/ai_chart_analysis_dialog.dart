import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_create_sheet.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

class AiChartAnalysisDialog extends StatefulWidget {
  final AiAssistantRepository repository;
  final AiChartSetup setup;
  final void Function(AppLinkRef ref)? onOpenRef;

  const AiChartAnalysisDialog({
    super.key,
    required this.repository,
    required this.setup,
    this.onOpenRef,
  });

  static Future<void> show(
    BuildContext context, {
    required AiAssistantRepository repository,
    required AiChartSetup setup,
    void Function(AppLinkRef ref)? onOpenRef,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AiChartAnalysisDialog(
        repository: repository,
        setup: setup,
        onOpenRef: onOpenRef,
      ),
    );
  }

  @override
  State<AiChartAnalysisDialog> createState() => _AiChartAnalysisDialogState();
}

class _AiChartAnalysisDialogState extends State<AiChartAnalysisDialog> {
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _runStages();
  }

  Future<void> _runStages() async {
    if (!mounted) return;
    setState(() => _stage = 1);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _stage = 2);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _stage = 3);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _stage = 4);
  }

  void _openCreateSheet(AiCreateTarget target) {
    Navigator.of(context).pop();
    AiCreateSheet.show(
      context,
      repository: widget.repository,
      target: target,
      setup: widget.setup,
      onOpenRef: widget.onOpenRef,
    );
  }

  void _shareToDm() {
    Navigator.of(context).pop();
    final AppLinkRef ref = AppLinkRef(
      id: widget.setup.id,
      kind: AppLinkKind.ticker,
      title: '${widget.setup.symbol} ${widget.setup.direction.label} Setup',
      subtitle:
          '${widget.setup.pattern} · Target \$${widget.setup.target1.toStringAsFixed(2)}',
      meta: '${widget.setup.confidence}% CONF',
      intent: widget.setup.direction.intent,
    );
    ShareToConversationDialog.show(
      context,
      repository: MessagesRepositoryScope.repository,
      reference: ref,
      onShared: (String threadId) {
        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Setup Shared',
            message: 'Trade setup was sent to the conversation.',
            intent: UiIntent.success,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;

    return AiDensityScope(
      child: UiDialog(
        title: '${setup.symbol} - ${setup.timeframe}',
        actions: _stage >= 4
            ? [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: UiButton(
                            label: 'Save Note',
                            icon: Icons.sticky_note_2_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: () =>
                                _openCreateSheet(AiCreateTarget.note),
                          ),
                        ),
                        SizedBox(width: context.sp(context.ui.spacing.xs)),
                        Expanded(
                          child: UiButton(
                            label: 'Log Trade',
                            icon: Icons.menu_book_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: () =>
                                _openCreateSheet(AiCreateTarget.journal),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.xs)),
                    Row(
                      children: [
                        Expanded(
                          child: UiButton(
                            label: 'Playbook',
                            icon: Icons.account_tree_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: () =>
                                _openCreateSheet(AiCreateTarget.strategy),
                          ),
                        ),
                        SizedBox(width: context.sp(context.ui.spacing.xs)),
                        Expanded(
                          child: UiButton(
                            label: 'Community',
                            icon: Icons.forum_outlined,
                            variant: UiVariant.outline,
                            size: UiSize.sm,
                            onPressed: () =>
                                _openCreateSheet(AiCreateTarget.post),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.xs)),
                    UiButton(
                      label: 'Send setup in DM',
                      icon: Icons.send_rounded,
                      variant: UiVariant.solid,
                      intent: UiIntent.primary,
                      size: UiSize.sm,
                      onPressed: _shareToDm,
                    ),
                  ],
                ),
              ]
            : [],
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_stage < 2)
              Padding(
                padding: EdgeInsets.symmetric(
                  vertical: context.sp(context.ui.spacing.xl),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Center(child: UiTypingIndicator()),
                    SizedBox(height: context.sp(context.ui.spacing.md)),
                    Center(
                      child: Text(
                        'Analyzing chart patterns...',
                        style: context.uiText.body,
                      ),
                    ),
                  ],
                ),
              ),
            // Stage 2: Pattern
            if (_stage >= 2)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(context.ui.spacing.md),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Pattern: ${setup.pattern}',
                        style: context.uiText.title,
                      ),
                      const Spacer(),
                      UiBadge(label: 'Confidence: ${setup.confidence}%'),
                    ],
                  ),
                ),
              ),

            // Stage 3: Trade plan
            if (_stage >= 3)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: UiCard(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            setup.direction.icon,
                            color: setup.direction.intent.color(context),
                          ),
                          SizedBox(width: context.sp(context.ui.spacing.sm)),
                          Text(
                            setup.direction.label,
                            style: context.uiText.title.copyWith(
                              color: setup.direction.intent.color(context),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'R:R ${setup.rrRatio.toStringAsFixed(1)}',
                            style: context.uiText.label,
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(context.ui.spacing.md)),
                      _buildPriceRow('Entry', setup.entry),
                      _buildPriceRow('Stop Loss', setup.stopLoss),
                      _buildPriceRow('Target 1', setup.target1),
                      _buildPriceRow('Target 2', setup.target2),
                      SizedBox(height: context.sp(context.ui.spacing.md)),
                      Text('Confidence', style: context.uiText.label),
                      SizedBox(height: context.sp(context.ui.spacing.xs)),
                      UiProgressBar(
                        value: setup.confidence / 100.0,
                        intent: setup.direction.intent,
                      ),
                    ],
                  ),
                ),
              ),

            // Stage 4: Rationale
            if (_stage >= 4)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: context.sp(context.ui.spacing.lg),
                  ),
                  child: UiCallout(
                    title: 'Rationale',
                    message: setup.rationale,
                    icon: Icons.lightbulb_outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double price) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xs)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.uiText.body),
          Text(AppTokens.price(price), style: context.uiText.bodyStrong),
        ],
      ),
    );
  }
}
