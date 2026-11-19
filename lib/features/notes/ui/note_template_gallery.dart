import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

import '../data/note_templates.dart';

/// Asks which template a new note should start from.
///
/// Returns null if the writer backs out. The gallery is the answer to "I do not
/// know markdown": every option lands a finished, correctly formatted document
/// the writer only has to fill in, so the syntax is learned by editing rather
/// than by being taught.
Future<AppNoteTemplate?> showNoteTemplateGallery(BuildContext context) =>
    UiDialog.show<AppNoteTemplate>(
      context,
      maxWidth: 720,
      child: const _NoteTemplateGallery(),
    );

class _NoteTemplateGallery extends StatelessWidget {
  const _NoteTemplateGallery();

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.68;

    return UiDialog(
      title: 'Create a new note',
      description: 'Choose a starting point. Everything stays fully editable.',
      icon: Icons.edit_note_rounded,
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
                    for (final AppNoteTemplate template in NoteTemplates.all)
                      SizedBox(
                        width: width,
                        height: columns == 2 ? context.sz(132) : null,
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

  final AppNoteTemplate template;
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
                color: template.noteType.intent.color(context),
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
            maxLines: 2,
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
              UiBadge(
                label: template.noteType.label,
                icon: template.noteType.icon,
                intent: template.noteType.intent,
                size: UiSize.xs,
              ),
              if (template.id == NoteTemplates.blank.id)
                const UiBadge(
                  label: 'Start fresh',
                  icon: Icons.add_rounded,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
