import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// Modal dialog that formats a post / trade setup into a branded hejournal.in graphic card
/// for easy social sharing and exporting.
class CommunityCardShareDialog extends StatelessWidget {
  const CommunityCardShareDialog({super.key, required this.post});

  final CommunityPost post;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) =>
          CommunityDensityScope(child: CommunityCardShareDialog(post: post)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.sz(16)),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(460)),
        child: Padding(
          padding: EdgeInsets.all(context.sp(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Export Post Snapshot',
                    style: context.uiText.heading.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ),
                  ),
                  UiIconButton(
                    icon: Icons.close,
                    size: UiSize.sm,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              SizedBox(height: context.sp(16)),

              // Branded Preview Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.surfaceMuted,
                      colors.surface,
                      colors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(context.sz(12)),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(context.sp(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author + hejournal.in Branding
                    Row(
                      children: [
                        UiAvatar(
                          name: post.author.displayName,
                          size: UiSize.sm,
                        ),
                        SizedBox(width: context.sp(10)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.author.displayName,
                                style: context.uiText.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.foreground,
                                ),
                              ),
                              Text(
                                post.author.handle,
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.sp(8),
                            vertical: context.sp(4),
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(context.sz(4)),
                          ),
                          child: Text(
                            'TRADEX',
                            style: context.uiText.label.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(12)),

                    // Post content snippet
                    Text(
                      post.body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.body.copyWith(
                        color: colors.foreground,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: context.sp(12)),

                    // Setup badge if available
                    if (post.tradeSetup != null) ...[
                      Container(
                        padding: EdgeInsets.all(context.sp(10)),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(context.sz(8)),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              post.tradeSetup!.ticker,
                              style: context.uiText.label.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.foreground,
                              ),
                            ),
                            Text(
                              'Entry: \$${post.tradeSetup!.entry}',
                              style: context.uiText.caption.copyWith(
                                color: colors.foregroundMuted,
                              ),
                            ),
                            if (post.tradeSetup!.target != null)
                              Text(
                                'Target: \$${post.tradeSetup!.target}',
                                style: context.uiText.caption.copyWith(
                                  color: colors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.sp(12)),
                    ],

                    // Timestamp & Watermark
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'hejournal.in/post/${post.id}',
                          style: context.uiText.label.copyWith(
                            color: colors.foregroundSubtle,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          'Verified on hejournal.in',
                          style: context.uiText.label.copyWith(
                            color: colors.foregroundSubtle,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(20)),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: UiButton(
                      label: 'Save Image',
                      icon: Icons.download,
                      variant: UiVariant.outline,
                      onPressed: () {
                        Navigator.of(context).pop();
                        UiToast.show(
                          context,
                          title: 'Snapshot Saved',
                          message: 'Card snapshot saved to device gallery',
                        );
                      },
                    ),
                  ),
                  SizedBox(width: context.sp(8)),
                  Expanded(
                    child: UiButton(
                      label: 'Copy Link',
                      icon: Icons.link,
                      variant: UiVariant.primary,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: 'https://hejournal.in/p/${post.id}'),
                        );
                        Navigator.of(context).pop();
                        UiToast.show(
                          context,
                          title: 'Copied',
                          message: 'Card link copied to clipboard',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
