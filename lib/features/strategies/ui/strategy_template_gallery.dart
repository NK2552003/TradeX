import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../data/strategy_templates.dart';

/// Asks which shape a new playbook should start from.
///
/// Returns null if the trader backs out. Same gallery on both surfaces —
/// [UiDialog.show] puts it in a bottom sheet on a phone and a centred modal on a
/// desktop, which is the only difference the two need.
Future<AppStrategyTemplate?> showStrategyTemplateGallery(
  BuildContext context,
) => UiDialog.show<AppStrategyTemplate>(
  context,
  maxWidth: 760,
  child: const _StrategyTemplateGallery(),
);

class _StrategyTemplateGallery extends StatelessWidget {
  const _StrategyTemplateGallery();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.68;

    return UiDialog(
      title: 'New playbook',
      description:
          'Pick a starting point. Every template asks the same questions, so '
          'thirty playbooks stay readable side by side.',
      icon: Icons.auto_awesome_mosaic_outlined,
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Scrollbar(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double gap = context.sp(theme.spacing.sm);
                final int columns = constraints.maxWidth >= context.sz(560)
                    ? 2
                    : 1;
                final double width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final AppStrategyTemplate template
                        in StrategyTemplates.all)
                      SizedBox(
                        width: width,
                        height: columns == 2 ? context.sz(175) : null,
                        child: _TemplateTile(
                          template: template,
                          fixedHeight: columns == 2,
                          onTap: () => Navigator.of(context).pop(template),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.fixedHeight,
    required this.onTap,
  });

  final AppStrategyTemplate template;
  final bool fixedHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      variant: UiCardVariant.outlined,
      hoverLift: false,
      motion: false,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      onTap: onTap,
      minHeight: context.sz(108),
      child: Column(
        mainAxisSize: fixedHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                template.icon,
                size: context.sz(theme.sizes.iconMd),
                color: template.intent.color(context),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Text(
                  template.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.subheading,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Icon(
                Icons.arrow_forward_rounded,
                size: context.sz(theme.sizes.iconSm),
                color: theme.colors.foregroundMuted,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Text(
            template.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
          if (fixedHeight)
            const Spacer()
          else
            SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              if (template.id == StrategyTemplates.blank.id)
                const UiBadge(
                  label: 'Start fresh',
                  icon: Icons.add_rounded,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                )
              else ...<Widget>[
                if (template.category != null)
                  UiBadge(
                    label: template.category!,
                    intent: template.intent,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                for (final String tag in template.tags)
                  UiBadge(
                    label: tag,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
