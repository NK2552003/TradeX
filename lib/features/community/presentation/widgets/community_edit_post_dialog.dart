import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';

/// Modal dialog for editing an existing published post.
class CommunityEditPostDialog extends StatefulWidget {
  const CommunityEditPostDialog({
    super.key,
    required this.post,
    required this.repository,
  });

  final CommunityPost post;
  final CommunityRepository repository;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    required CommunityRepository repository,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ctx.sz(520)),
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
            child: CommunityEditPostDialog(
              post: post,
              repository: repository,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityEditPostDialog> createState() =>
      _CommunityEditPostDialogState();
}

class _CommunityEditPostDialogState extends State<CommunityEditPostDialog> {
  late String _body;

  @override
  void initState() {
    super.initState();
    _body = widget.post.body;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final int remainingChars = 500 - _body.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header
        Row(
          children: <Widget>[
            Text(
              'Edit Post',
              style: context.uiText.heading.copyWith(fontWeight: FontWeight.w700),
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

        // Textarea
        UiTextarea(
          value: _body,
          rows: 4,
          maxRows: 8,
          onChanged: (val) => setState(() => _body = val),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),

        // Character counter
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$remainingChars characters remaining',
            style: context.uiText.caption.copyWith(
              color: remainingChars < 20
                  ? theme.colors.danger
                  : theme.colors.foregroundSubtle,
              fontSize: context.fs(11),
            ),
          ),
        ),

        SizedBox(height: context.sp(theme.spacing.md)),

        // Action Buttons
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
              label: 'Save Changes',
              variant: UiVariant.primary,
              onPressed: (_body.trim().isEmpty || _body == widget.post.body)
                  ? null
                  : () {
                      widget.repository.editPost(widget.post.id, _body.trim());
                      Navigator.of(context).pop();
                      UiToast.show(
                        context,
                        title: 'Post Updated',
                        message: 'Your post edits have been saved.',
                        intent: UiIntent.success,
                      );
                    },
            ),
          ],
        ),
      ],
    );
  }
}
