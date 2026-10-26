import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/ai_assistant.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_send_dm_dialog.dart';

/// Bottom-sheet overlay presenting social sharing and DM actions for a post.
class CommunityShareSheet extends StatelessWidget {
  const CommunityShareSheet({super.key, required this.post, this.onSendDm});

  final CommunityPost post;
  final VoidCallback? onSendDm;

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    VoidCallback? onSendDm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.uiColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ctx.sp(ctx.ui.radii.lg)),
          ),
          border: Border.all(
            color: ctx.uiColors.border,
            width: ctx.ui.borders.hairline,
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          ctx.sp(ctx.ui.spacing.md),
          ctx.sp(ctx.ui.spacing.sm),
          ctx.sp(ctx.ui.spacing.md),
          ctx.sp(ctx.ui.spacing.lg),
        ),
        child: SafeArea(
          child: CommunityShareSheet(
            post: post,
            onSendDm: () {
              Navigator.of(ctx).pop();
              if (onSendDm != null) {
                onSendDm();
              } else {
                CommunitySendDmDialog.show(context, post: post);
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Drag handle
        Center(
          child: Container(
            width: context.sz(36),
            height: context.sz(4),
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: Text(
            'Share Post',
            style: context.uiText.heading.copyWith(
              fontSize: context.fs(16),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Option: Send via Direct Message
        _shareOption(
          context,
          icon: Icons.send_rounded,
          title: 'Send via Direct Message',
          subtitle: 'Share privately with a fellow trader',
          onTap:
              onSendDm ?? () => CommunitySendDmDialog.show(context, post: post),
        ),

        // Option: Analyze with AI Copilot
        _shareOption(
          context,
          icon: Icons.auto_awesome_rounded,
          title: 'Analyze with AI Copilot',
          subtitle: 'Validate thesis, sentiment, and setups',
          onTap: () {
            Navigator.of(context).pop();
            final String prompt =
                'Analyze community post by @${post.author.handle}:\n\n'
                '"${post.body}"\n\n'
                'Provide sentiment breakdown, technical setup validity, and potential counter-thesis risks.';

            AiAssistantOverlaySheet.show(
              context,
              repository: AiAssistantRepositoryScope.repository,
              initialPrompt: prompt,
              contextTitle: 'Post by @${post.author.handle}',
              contextSubtitle: post.body.length > 50
                  ? '${post.body.substring(0, 50)}...'
                  : post.body,
              contextIcon: Icons.public_rounded,
              contextRef: AppLinkRef(
                id: post.id,
                kind: AppLinkKind.communityPost,
                title: 'Post by @${post.author.handle}',
                subtitle: post.body,
              ),
            );
          },
        ),

        // Option: Copy Link
        _shareOption(
          context,
          icon: Icons.link_rounded,
          title: 'Copy Link to Post',
          subtitle: 'https://hejournal.in/post/${post.id}',
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: 'https://hejournal.in/post/${post.id}'),
            );
            Navigator.of(context).pop();
            UiToast.show(
              context,
              title: 'Link Copied',
              message: 'Post link copied to clipboard.',
              intent: UiIntent.success,
            );
          },
        ),

        // Option: Copy Post Text
        _shareOption(
          context,
          icon: Icons.copy_rounded,
          title: 'Copy Text',
          subtitle: 'Copy the post body to clipboard',
          onTap: () {
            Clipboard.setData(ClipboardData(text: post.body));
            Navigator.of(context).pop();
            UiToast.show(
              context,
              title: 'Copied',
              message: 'Post text copied to clipboard.',
              intent: UiIntent.info,
            );
          },
        ),

        // Option: Share to WhatsApp
        _shareOption(
          context,
          icon: Icons.chat_rounded,
          title: 'Share via WhatsApp',
          subtitle: 'Send to trade channels & groups',
          onTap: () async {
            Navigator.of(context).pop();
            await SharePlus.instance.share(ShareParams(text: _shareText(post)));
          },
        ),

        // Option: Share to Twitter/X
        _shareOption(
          context,
          icon: Icons.share_rounded,
          title: 'Share on X / Twitter',
          subtitle: 'Broadcast to external audience',
          onTap: () async {
            Navigator.of(context).pop();
            await SharePlus.instance.share(ShareParams(text: _shareText(post)));
          },
        ),
      ],
    );
  }

  Widget _shareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;

    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.md),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.xs),
          vertical: context.sp(theme.spacing.xs),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: context.sz(38),
              height: context.sz(38),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colors.surfaceMuted,
                borderRadius: context.radius(theme.radii.sm),
              ),
              child: Icon(
                icon,
                size: context.sz(18),
                color: theme.colors.foreground,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: context.fs(13),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                      fontSize: context.fs(11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _shareText(CommunityPost post) =>
      '${post.body}\n\nShared from hejournal.in • @${post.author.handle}';
}
