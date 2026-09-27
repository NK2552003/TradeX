import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiChatView extends StatefulWidget {
  final AiAssistantRepository repository;
  final void Function(AppLinkRef)? onOpenRef;
  final void Function(AiSuggestedAction) onCreateFromChat;

  const AiChatView({
    super.key,
    required this.repository,
    this.onOpenRef,
    required this.onCreateFromChat,
  });

  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> {
  late AiAssistantRepository _repository;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
    // Auto-scroll on new messages
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
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
                  onTap: () {
                    // Could open persona selector
                  },
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
              ],
            ),
          ),
          const UiDivider(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780), // kAiChatMaxWidth
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How can I help you today?',
            style: context.uiText.heading.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: context.sp(context.ui.spacing.xl)),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.uiRes.isMobile ? 1 : 2,
              crossAxisSpacing: context.sp(context.ui.spacing.md),
              mainAxisSpacing: context.sp(context.ui.spacing.md),
              childAspectRatio: 3,
            ),
            itemCount: _repository.capabilities.length,
            itemBuilder: (context, index) {
              final capability = _repository.capabilities[index];
              return AiCapabilityCard(
                capability: capability,
                onTap: () {
                  _repository.sendPrompt(capability.promptSeed);
                },
              );
            },
          ),
          SizedBox(height: context.sp(context.ui.spacing.xxl)),
          AppAiChatBlock(
            messages: const [],
            onSend: (text) => _repository.sendPrompt(text),
            prompts: _repository.quickPrompts,
            generating: false,
            onStop: () {},
            emptyTitle: '',
            emptyMessage: '',
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
    return Column(
      children: [
        Expanded(
          child: AppAiChatBlock(
            messages: messages,
            onSend: (text) => _repository.sendPrompt(text),
            prompts: const [],
            generating: generating,
            onStop: () => _repository.stop(),
            onRetry: (msg) => _repository.regenerate(msg),
            emptyTitle: '',
            emptyMessage: '',
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: actions.map((action) {
                  return Padding(
                    padding: EdgeInsets.only(right: context.sp(context.ui.spacing.xs)),
                    child: UiBadge(
                      label: action.effectiveLabel,
                      icon: action.icon,
                      onTap: () => widget.onCreateFromChat(action),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}
