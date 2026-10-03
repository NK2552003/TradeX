import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_repository.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key, this.repository, this.onOpenRef});

  final AiRepository? repository;
  final void Function(AppLinkRef ref)? onOpenRef;

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  late final AiRepository _repo;
  bool _loading = true;
  List<AppAiInsight> _insights = [];
  final List<AppAiMessage> _aiMessages = [
    AppAiMessage(
      id: 'msg_001',
      role: AppAiRole.assistant,
      body: 'Hello Nitish! I am your TradeX AI Copilot. Ask me about your journal performance, active setups, or risk parameters.',
      sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AiRepositoryImpl();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() => _loading = true);
    try {
      final list = await _repo.getInsights();
      if (mounted) {
        setState(() {
          _insights = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('AiPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = AppAiMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      role: AppAiRole.user,
      body: text,
      sentAt: DateTime.now(),
    );

    setState(() {
      _aiMessages.add(userMsg);
    });

    final insight = await _repo.requestInsight(kind: 'chat_prompt', ticker: 'NIFTY50');
    final assistantMsg = AppAiMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      role: AppAiRole.assistant,
      body: insight.body,
      sentAt: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _aiMessages.add(assistantMsg);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.ai();
    }

    return AppPageBlock(
      title: 'AI Trading Copilot',
      subtitle: 'Quant pattern recognition, risk scanning, and setup analysis',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppAiChatBlock(
                messages: _aiMessages,
                onSend: _handleSendMessage,
                onOpenRef: widget.onOpenRef,
              ),
            ),
            if (!context.uiRes.isMobile) ...[
              UiGap.h(context.sp(theme.spacing.lg)),
              Expanded(
                flex: 2,
                child: AppAiInsightsBlock(insights: _insights),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
