import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiCreateSheet extends StatefulWidget {
  final AiAssistantRepository repository;
  final AiCreateTarget target;
  final AiChartSetup? setup;
  final void Function(AppLinkRef ref)? onOpenRef;

  const AiCreateSheet({
    super.key,
    required this.repository,
    required this.target,
    this.setup,
    this.onOpenRef,
  });

  static Future<void> show(
    BuildContext context, {
    required AiAssistantRepository repository,
    required AiCreateTarget target,
    AiChartSetup? setup,
    void Function(AppLinkRef ref)? onOpenRef,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiCreateSheet(
        repository: repository,
        target: target,
        setup: setup,
        onOpenRef: onOpenRef,
      ),
    );
  }

  @override
  State<AiCreateSheet> createState() => _AiCreateSheetState();
}

class _AiCreateSheetState extends State<AiCreateSheet> {
  late AiCreateDraft _draft;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    if (widget.setup != null) {
      _draft = widget.repository.draftFromSetup(widget.setup!, widget.target);
    } else {
      _draft = widget.repository.draftFromChat(widget.target);
    }
    _titleController = TextEditingController(text: _draft.title);
    _bodyController = TextEditingController(text: _draft.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    setState(() => _isCreating = true);
    final updatedDraft = _draft.copyWith(
      title: _titleController.text,
      body: _bodyController.text,
    );
    try {
      final ref = await widget.repository.create(updatedDraft);
      if (mounted) {
        Navigator.of(context).pop();
        UiToastScope.maybeOf(context)?.show(UiToastData(title: 'Created: ${updatedDraft.title}', intent: UiIntent.success));
        if (ref != null && widget.onOpenRef != null) {
          widget.onOpenRef!(ref);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AiDensityScope(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: context.ui.colors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(context.sz(context.ui.radii.lg))),
            ),
            child: Column(
              children: [
                const AiSheetGrabber(),
                Padding(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.lg)),
                  child: Row(
                    children: [
                      Icon(widget.target.icon, color: widget.target.intent.color(context)),
                      SizedBox(width: context.sp(context.ui.spacing.md)),
                      Expanded(
                        child: Text(
                          widget.target.label,
                          style: context.uiText.title,
                        ),
                      ),
                      UiIconButton(
                        icon: Icons.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const UiDivider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(context.sp(context.ui.spacing.lg)),
                    children: [
                      UiInput(
                        label: 'Title',
                        controller: _titleController,
                      ),
                      SizedBox(height: context.sp(context.ui.spacing.lg)),
                      UiTextarea(
                        label: 'Content',
                        controller: _bodyController,
                        rows: 8,
                        maxRows: 16,
                      ),
                      SizedBox(height: context.sp(context.ui.spacing.lg)),
                      if (_draft.tickers.isNotEmpty) ...[
                        Text('Tickers', style: context.uiText.label),
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        Wrap(
                          spacing: context.sp(context.ui.spacing.sm),
                          children: _draft.tickers.map((t) => UiBadge(label: t)).toList(),
                        ),
                        SizedBox(height: context.sp(context.ui.spacing.lg)),
                      ],
                      if (_draft.tags.isNotEmpty) ...[
                        Text('Tags', style: context.uiText.label),
                        SizedBox(height: context.sp(context.ui.spacing.sm)),
                        Wrap(
                          spacing: context.sp(context.ui.spacing.sm),
                          children: _draft.tags.map((t) => UiBadge(label: t, intent: UiIntent.neutral)).toList(),
                        ),
                        SizedBox(height: context.sp(context.ui.spacing.lg)),
                      ],
                    ],
                  ),
                ),
                const UiDivider(),
                Padding(
                  padding: EdgeInsets.all(context.sp(context.ui.spacing.lg)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      UiButton(
                        label: 'Cancel',
                        variant: UiVariant.outline,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: context.sp(context.ui.spacing.md)),
                      UiButton(
                        label: widget.target.actionLabel,
                        intent: UiIntent.primary,
                        loading: _isCreating,
                        onPressed: _handleCreate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
