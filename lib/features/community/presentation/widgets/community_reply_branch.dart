import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// A shared thread guide for existing replies and the editor beneath a comment.
class CommunityReplyBranch extends StatelessWidget {
  const CommunityReplyBranch({
    super.key,
    required this.children,
    this.depth = 0,
  });
  final List<Widget> children;
  final int depth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: context.sp(
        depth < 2 ? context.ui.spacing.sm : context.ui.spacing.xxs,
      ),
    ),
    child: Stack(
      children: [
        const Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          child: UiDivider(vertical: true, height: double.infinity, spacing: 0),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: context.sp(
              depth < 2 ? context.ui.spacing.md : context.ui.spacing.xs,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}
