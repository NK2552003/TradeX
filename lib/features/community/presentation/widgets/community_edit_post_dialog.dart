import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Modal dialog / drawer for editing an existing published post with all options.
class CommunityEditPostDialog extends StatelessWidget {
  const CommunityEditPostDialog({
    super.key,
    required this.post,
    required this.repository,
    this.onSaved,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final VoidCallback? onSaved;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    required CommunityRepository repository,
  }) {
    final bool isMobile = context.uiRes.isMobile;
    if (isMobile) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: context.uiColors.overlay,
        builder: (BuildContext ctx) => CommunityDensityScope(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              child: CommunityComposerCard(
                author: post.author,
                repository: repository,
                postToEdit: post,
                isDrawerTile: true,
                onClose: () => Navigator.of(ctx).pop(),
                onPostCreated: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: context.uiColors.overlay,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ctx.sp(ctx.ui.spacing.md)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ctx.sz(760)),
          child: SingleChildScrollView(
            child: CommunityComposerCard(
              author: post.author,
              repository: repository,
              postToEdit: post,
              onClose: () => Navigator.of(ctx).pop(),
              onPostCreated: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CommunityComposerCard(
      author: post.author,
      repository: repository,
      postToEdit: post,
      onClose: onSaved,
      onPostCreated: onSaved,
    );
  }
}
