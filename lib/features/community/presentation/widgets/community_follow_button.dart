import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import '../../data/community_repository.dart';

class CommunityFollowButton extends StatefulWidget {
  const CommunityFollowButton({
    super.key,
    required this.repository,
    required this.authorId,
    this.size = UiSize.sm,
  });
  final CommunityRepository repository;
  final String authorId;
  final UiSize size;
  @override
  State<CommunityFollowButton> createState() => _CommunityFollowButtonState();
}

class _CommunityFollowButtonState extends State<CommunityFollowButton> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final following = widget.repository.isFollowing(widget.authorId);
      return UiButton(
        label: following ? 'Following' : 'Follow',
        leadingIcon: following ? Icons.check : Icons.add,
        variant: UiVariant.ghost,
        size: widget.size,
        loading: _saving,
        onPressed: _saving
            ? null
            : () async {
                setState(() => _saving = true);
                final saved = await widget.repository.toggleFollow(
                  widget.authorId,
                );
                if (!mounted) return;
                setState(() => _saving = false);
                if (!saved) {
                  UiToast.show(
                    this.context,
                    title: 'Could not update follow',
                    message: 'Please sign in and try again.',
                    intent: UiIntent.warning,
                  );
                }
              },
      );
    },
  );
}
