import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_create_sheet.dart';
import 'package:tradex/features/ai_assistant/presentation/overlays/ai_persona_dialog.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';
import 'package:tradex/features/messages/data/messages_repository.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

/// Contextual bottom sheet overlay for the AI Copilot.
///
/// Can be summoned over ANY feature screen (Notes, Journal, Strategies, Messages,
/// Community, Workspace) with optional pre-populated context (record title,
/// initial prompt, and links). Eliminates blank screens and provides immediate,
/// in-place interactive quantitative AI assistance without navigating away.
///
/// The conversation itself is rendered by the shared [AppAiChatBlock], so the
/// bubbles, markdown, sources, prompt chips and composer read identically to
/// the full-screen Copilot. Per-answer create actions (Save note / Log trade /
/// Strategy / Post) are injected through [AppAiChatBlock.messageActionsBuilder].
class AiAssistantOverlaySheet extends StatefulWidget {
  const AiAssistantOverlaySheet({
    super.key,
    required this.repository,
    this.initialPrompt,
    this.contextTitle,
    this.contextSubtitle,
    this.contextIcon,
    this.contextRef,
    this.onOpenRef,
    this.onOpenFullScreen,
  });

  final AiAssistantRepository repository;
  final String? initialPrompt;
  final String? contextTitle;
  final String? contextSubtitle;
  final IconData? contextIcon;
  final AppLinkRef? contextRef;
  final void Function(AppLinkRef ref)? onOpenRef;
  final VoidCallback? onOpenFullScreen;

  /// Shows the AI Assistant as an interactive bottom sheet over any feature.
  static Future<void> show(
    BuildContext context, {
    required AiAssistantRepository repository,
    String? initialPrompt,
    String? contextTitle,
    String? contextSubtitle,
    IconData? contextIcon,
    AppLinkRef? contextRef,
    void Function(AppLinkRef ref)? onOpenRef,
    VoidCallback? onOpenFullScreen,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => AiAssistantOverlaySheet(
        repository: repository,
        initialPrompt: initialPrompt,
        contextTitle: contextTitle,
        contextSubtitle: contextSubtitle,
        contextIcon: contextIcon,
        contextRef: contextRef,
        onOpenRef: onOpenRef,
        onOpenFullScreen: onOpenFullScreen,
      ),
    );
  }

  @override
  State<AiAssistantOverlaySheet> createState() =>
      _AiAssistantOverlaySheetState();
}

class _AiAssistantOverlaySheetState extends State<AiAssistantOverlaySheet> {
  late final AiAssistantRepository _repo = widget.repository;
  bool _contextDismissed = false;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChange);

    // Fire an initial prompt (if provided and not already the last message) so
    // the reader sees a real answer the moment the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialPrompt != null &&
          widget.initialPrompt!.trim().isNotEmpty) {
        final String prompt = widget.initialPrompt!.trim();
        final bool alreadySent =
            _repo.messages.isNotEmpty && _repo.messages.last.body == prompt;
        if (!alreadySent) _repo.sendPrompt(prompt);
      }
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChange);
    super.dispose();
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  void _openPersonaChooser() async {
    final AiPersona? picked = await AiPersonaDialog.show(
      context,
      current: _repo.persona,
    );
    if (picked != null && mounted) {
      _repo.setPersona(picked);
    }
  }

  void _openCreateSheet(AiCreateTarget target, {AiChartSetup? setup}) {
    Navigator.of(context).pop();
    AiCreateSheet.show(
      context,
      repository: _repo,
      target: target,
      setup: setup,
      onOpenRef: widget.onOpenRef,
    );
  }

  void _copyMessage(AppAiMessage message) {
    Clipboard.setData(ClipboardData(text: message.body));
    UiToastScope.maybeOf(context)?.show(
      UiToastData(
        title: 'Copied',
        message: 'Analysis copied to clipboard.',
        intent: UiIntent.info,
      ),
    );
  }

  void _shareToDm(AppAiMessage message) {
    Navigator.of(context).pop();
    final AppLinkRef ref = AppLinkRef(
      id: message.id,
      kind: AppLinkKind.aiCopilot,
      title: 'AI Copilot Insight',
      subtitle: message.body.length > 60
          ? '${message.body.substring(0, 60)}...'
          : message.body,
      intent: UiIntent.primary,
    );
    ShareToConversationDialog.show(
      context,
      repository: MessagesRepositoryScope.repository,
      reference: ref,
      onShared: (String threadId) {
        UiToastScope.maybeOf(context)?.show(
          UiToastData(
            title: 'Copilot Insight Shared',
            message: 'Analysis shared with conversation.',
            intent: UiIntent.success,
          ),
        );
      },
    );
  }

  /// Per-answer "turn this into…" actions, surfaced beneath each settled
  /// assistant message through [AppAiChatBlock.messageActionsBuilder]. Copy /
  /// regenerate / share come from the shared bubble's own action row.
  List<Widget> _createActions(AppAiMessage message) {
    if (message.role != AppAiRole.assistant || message.pending) {
      return const <Widget>[];
    }
    return <Widget>[
      UiButton(
        label: 'Copy',
        leadingIcon: Icons.copy_all_outlined,
        size: UiSize.xs,
        variant: UiVariant.ghost,
        onPressed: () => _copyMessage(message),
      ),
      UiButton(
        label: 'Save Note',
        leadingIcon: Icons.sticky_note_2_outlined,
        size: UiSize.xs,
        variant: UiVariant.soft,
        onPressed: () => _openCreateSheet(AiCreateTarget.note),
      ),
      UiButton(
        label: 'Log Trade',
        leadingIcon: Icons.menu_book_outlined,
        size: UiSize.xs,
        variant: UiVariant.soft,
        onPressed: () => _openCreateSheet(AiCreateTarget.journal),
      ),
      UiButton(
        label: 'Strategy',
        leadingIcon: Icons.account_tree_outlined,
        size: UiSize.xs,
        variant: UiVariant.soft,
        onPressed: () => _openCreateSheet(AiCreateTarget.strategy),
      ),
      UiButton(
        label: 'Post',
        leadingIcon: Icons.forum_outlined,
        size: UiSize.xs,
        variant: UiVariant.soft,
        onPressed: () => _openCreateSheet(AiCreateTarget.post),
      ),
      UiButton(
        label: 'Share',
        leadingIcon: Icons.send_outlined,
        size: UiSize.xs,
        variant: UiVariant.ghost,
        onPressed: () => _shareToDm(message),
      ),
    ];
  }

  List<String> get _contextualChips {
    final String? title = widget.contextTitle?.toLowerCase();
    if (title != null &&
        (title.contains('trade') || title.contains('journal'))) {
      return <String>[
        'Evaluate execution discipline & R:R',
        'Suggest Stop Loss & Take Profit adjustments',
        'Check for emotional trade patterns',
        'How could this trade be managed better?',
      ];
    }
    if (title != null &&
        (title.contains('strategy') || title.contains('playbook'))) {
      return <String>[
        'Stress-test this playbook in high volatility',
        'Calculate optimal position sizing formula',
        'Identify common false breakout traps',
        'Recommend key risk guardrails',
      ];
    }
    if (title != null && title.contains('note')) {
      return <String>[
        'Summarize key insights & action items',
        'Extract high-conviction trade setups',
        'Convert note into a formalized Strategy Playbook',
        'Highlight potential confirmation biases',
      ];
    }
    if (title != null &&
        (title.contains('community') ||
            title.contains('market') ||
            title.contains('alpha') ||
            title.contains('pulse'))) {
      return <String>[
        'Scan community sentiment on BankNifty & Top F&O movers',
        'Generate swing trade setup with entry, stop loss, and targets',
        'Draft an institutional macro thesis post for the community feed',
        'Evaluate peer breakout setups & risk/reward ratio',
        'Check FII / DII net institutional flow bias',
      ];
    }
    return <String>[
      'Analyze current market structure',
      'Review risk-to-reward parameters',
      'Generate trade setup plan',
      'Audit sizing and exposure limits',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final double sheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.radius(theme.radii.xl).topLeft.x),
        ),
        border: Border.all(color: colors.border, width: theme.borders.hairline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 6),
            const Center(child: AiSheetGrabber()),
            _buildHeader(context, theme, colors),
            UiDivider(spacing: theme.spacing.xxs),
            if (!_contextDismissed && widget.contextTitle != null)
              _buildContextBar(context, theme, colors),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: AppAiChatBlock(
                  messages: _repo.messages,
                  generating: _repo.generating,
                  prompts: <AppAiPrompt>[
                    for (final String chip in _contextualChips)
                      AppAiPrompt(label: chip, prompt: chip),
                  ],
                  onSend: (String text) => _repo.sendPrompt(text),
                  onStop: _repo.stop,
                  onCopy: _copyMessage,
                  onRetry: _repo.regenerate,
                  onShare: _shareToDm,
                  onOpenRef: widget.onOpenRef,
                  messageActionsBuilder: _createActions,
                  emptyTitle: 'How can Copilot assist you?',
                  emptyMessage:
                      'Ask about position sizing, technical structure, '
                      'execution auditing, or stress-test this setup.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UiTheme theme, UiColors colors) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xs),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: context.radius(theme.radii.sm),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colors.primary,
              size: context.sz(18),
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'alphajournal AI Copilot',
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(15),
                  ),
                ),
                Text(
                  'Institutional Market Intelligence',
                  style: context.uiText.caption.copyWith(
                    color: colors.foregroundMuted,
                    fontSize: context.fs(11),
                  ),
                ),
              ],
            ),
          ),
          UiButton(
            label: _repo.persona.label,
            leadingIcon: _repo.persona.icon,
            size: UiSize.xs,
            variant: UiVariant.soft,
            intent: UiIntent.primary,
            onPressed: _openPersonaChooser,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          if (widget.onOpenFullScreen != null) ...<Widget>[
            UiIconButton(
              icon: Icons.fullscreen_rounded,
              size: UiSize.sm,
              variant: UiVariant.ghost,
              tooltip: 'Open Full Copilot',
              onPressed: () {
                Navigator.of(context).pop();
                widget.onOpenFullScreen!();
              },
            ),
          ],
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.sm,
            variant: UiVariant.ghost,
            tooltip: 'Close Copilot',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContextBar(
    BuildContext context,
    UiTheme theme,
    UiColors colors,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.md),
        vertical: context.sp(theme.spacing.xxs),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xxs),
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.md),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
          width: theme.borders.hairline,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            widget.contextIcon ?? Icons.attachment_rounded,
            size: context.sz(14),
            color: colors.primary,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Text(
              'Attached Context: ${widget.contextTitle!}${widget.contextSubtitle != null ? " • ${widget.contextSubtitle}" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          UiIconButton(
            icon: Icons.close_rounded,
            size: UiSize.xs,
            variant: UiVariant.ghost,
            tooltip: 'Detach Context',
            onPressed: () => setState(() => _contextDismissed = true),
          ),
        ],
      ),
    );
  }
}
