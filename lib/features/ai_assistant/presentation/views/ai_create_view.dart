import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiCreateView extends StatefulWidget {
  final AiAssistantRepository repository;
  final void Function(AiCreateTarget? target, {String? prompt}) onCreateTarget;

  const AiCreateView({
    super.key,
    required this.repository,
    required this.onCreateTarget,
  });

  @override
  State<AiCreateView> createState() => _AiCreateViewState();
}

class _AiCreateViewState extends State<AiCreateView> {
  late AiAssistantRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void didUpdateWidget(AiCreateView oldWidget) {
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
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AiDensityScope(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiSectionHeader(
              title: 'Create with AI',
              icon: Icons.auto_awesome,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.sp(context.ui.spacing.md)),
              child: Column(
                children: AiCreateTarget.values.map((target) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xs)),
                    child: AiCreateActionCard(
                      target: target,
                      onTap: () => widget.onCreateTarget(target),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: context.sp(context.ui.spacing.md)),
            const AiSectionHeader(
              title: 'Prompt Library',
              icon: Icons.library_books,
            ),
            ..._buildPromptLibrary(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPromptLibrary() {
    final library = _repository.promptLibrary;
    if (library.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
          child: Text('No prompts available.', style: context.uiText.body),
        ),
      ];
    }

    final widgets = <Widget>[];
    
    library.forEach((category, prompts) {
      widgets.add(
        AiSectionHeader(
          title: category,
          icon: Icons.category_outlined,
        ),
      );
      widgets.add(
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: context.sp(context.ui.spacing.md)),
          child: AppAiPromptChips(
            prompts: prompts,
            onSelect: (prompt) {
              widget.onCreateTarget(null, prompt: prompt.prompt);
            },
          ),
        ),
      );
      widgets.add(SizedBox(height: context.sp(context.ui.spacing.md)));
    });
    
    return widgets;
  }
}
