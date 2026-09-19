import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Floating pill indicating new real-time posts are available above the current scroll position.
class CommunityNewPostsPill extends StatelessWidget {
  const CommunityNewPostsPill({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final UiTheme theme = context.ui;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.sz(20)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.xs),
            ),
            decoration: BoxDecoration(
              color: theme.colors.primary,
              borderRadius: BorderRadius.circular(context.sz(20)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: theme.colors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.arrow_upward_rounded,
                  size: context.sz(14),
                  color: Colors.white,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  '$count new ${count == 1 ? 'post' : 'posts'}',
                  style: context.uiText.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
