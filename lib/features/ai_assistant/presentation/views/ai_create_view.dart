import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
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
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;
    final library = _repository.promptLibrary;
    final List<String> categories = ['All', ...library.keys];

    return AiDensityScope(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Studio Hero Banner
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.sm),
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: context.radius(theme.radii.lg),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.8),
                    width: theme.borders.hairline,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.sz(36),
                      height: context.sz(36),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: context.radius(theme.radii.md),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colors.primary,
                        size: context.sz(20),
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Creation Studio',
                            style: context.uiText.subheading.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Turn market observations into structured journals, notes, & playbooks.',
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const AiSectionHeader(
              title: 'Creation Pipelines',
              icon: Icons.dashboard_customize_rounded,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
              ),
              child: Column(
                children: AiCreateTarget.values.map((target) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: context.sp(theme.spacing.xs),
                    ),
                    child: AiCreateActionCard(
                      target: target,
                      onTap: () => widget.onCreateTarget(target),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: context.sp(theme.spacing.md)),
            const AiSectionHeader(
              title: 'Prompt Library',
              icon: Icons.library_books_rounded,
            ),

            // Search Bar for Prompts
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiInput.search(
                controller: _searchController,
                hintText: 'Search prompt templates…',
                onChanged: (val) => setState(() => _searchQuery = val),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),

            // Prompt Filter Tabs
            if (categories.length > 1)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                  vertical: context.sp(theme.spacing.xxs),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
                        child: UiBadge(
                          label: cat,
                          variant: isSelected
                              ? UiBadgeVariant.solid
                              : UiBadgeVariant.outline,
                          intent: isSelected ? UiIntent.primary : UiIntent.neutral,
                          size: UiSize.sm,
                          onTap: () => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            ..._buildPromptLibrary(library),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPromptLibrary(Map<String, List<AppAiPrompt>> library) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    if (library.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          child: Text('No prompts available.', style: context.uiText.body),
        ),
      ];
    }

    final filteredSections = library.keys.where((section) {
      if (_selectedCategory == 'All') return true;
      return section == _selectedCategory;
    }).toList();

    return [
      Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int s = 0; s < filteredSections.length; s++) ...[
              if (s > 0) SizedBox(height: context.sp(theme.spacing.sm)),
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: context.sz(14),
                    color: colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    filteredSections[s],
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.foregroundMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: library[filteredSections[s]]!.where((p) {
                  if (_searchQuery.trim().isEmpty) return true;
                  final q = _searchQuery.trim().toLowerCase();
                  return p.label.toLowerCase().contains(q) ||
                      p.prompt.toLowerCase().contains(q);
                }).map((p) {
                  return UiCard(
                    variant: UiCardVariant.surface,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.sm),
                      vertical: context.sp(theme.spacing.xs),
                    ),
                    onTap: () => widget.onCreateTarget(null, prompt: p.prompt),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          p.icon ?? Icons.auto_awesome_rounded,
                          size: context.sz(14),
                          color: colors.primary,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        Text(
                          p.label,
                          style: context.uiText.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}
