import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Modal dialog for reporting a post or trader for moderation review.
class CommunityReportDialog extends StatefulWidget {
  const CommunityReportDialog({
    super.key,
    required this.postId,
    required this.repository,
  });

  final String postId;
  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required String postId,
    required CommunityRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ctx.sz(480)),
          child: Container(
            padding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
            decoration: BoxDecoration(
              color: ctx.uiColors.surface,
              borderRadius: ctx.radius(ctx.ui.radii.lg),
              border: Border.all(
                color: ctx.uiColors.border,
                width: ctx.ui.borders.hairline,
              ),
            ),
            child: CommunityReportDialog(
              postId: postId,
              repository: repository,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityReportDialog> createState() => _CommunityReportDialogState();
}

class _CommunityReportDialogState extends State<CommunityReportDialog> {
  CommunityReportReason _selectedReason = CommunityReportReason.spam;
  String _notes = '';

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header
        Row(
          children: <Widget>[
            Icon(
              Icons.flag_rounded,
              color: theme.colors.danger,
              size: context.sz(20),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Text(
              'Report Post',
              style: context.uiText.heading.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            UiIconButton(
              icon: Icons.close_rounded,
              size: UiSize.xs,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Text(
          'Moderation delivery is not connected yet. Reports cannot be submitted from this screen.',
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
            height: 1.4,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Reason radio options
        UiRadioGroup<CommunityReportReason>(
          value: _selectedReason,
          options: CommunityReportReason.values
              .map((r) => UiOption(label: r.label, value: r))
              .toList(),
          size: UiSize.sm,
          onChanged: (val) => setState(() => _selectedReason = val),
        ),

        SizedBox(height: context.sp(theme.spacing.sm)),

        // Additional notes
        UiTextarea(
          value: _notes,
          hintText: 'Additional details (optional)...',
          rows: 2,
          maxRows: 4,
          onChanged: (val) => setState(() => _notes = val),
        ),

        SizedBox(height: context.sp(theme.spacing.md)),

        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.ghost,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiButton(
              label: 'Submit Report',
              variant: UiVariant.destructive,
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }
}
