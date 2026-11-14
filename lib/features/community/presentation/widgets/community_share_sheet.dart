
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/navigation/share_links.dart';
import 'package:tradex/core/utils/share_actions.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_send_dm_dialog.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

/// Bottom-sheet overlay presenting real social, external, workspace, and DM
/// sharing actions for a community post.
class CommunityShareSheet extends StatefulWidget {
  const CommunityShareSheet({
    super.key,
    required this.post,
    this.repository,
    this.onSendDm,
    this.onRepost,
    this.onQuote,
    this.onShared,
  });

  final CommunityPost post;
  final CommunityRepository? repository;
  final VoidCallback? onSendDm;
  final VoidCallback? onRepost;
  final ValueChanged<CommunityPost>? onQuote;
  final VoidCallback? onShared;

  /// Canonical public deep link. Resolves to the in-app post view; visitors who
  /// are signed out are asked to sign in and are returned to the post.
  static String postUrl(CommunityPost post) =>
      AppShareLinks.record(AppLinkRef(kind: AppLinkKind.communityPost,
        id: post.id, title: post.body, isPublicContext: true));

  static String _excerpt(String body, {int max = 280}) {
    final String clean = body.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n');
    if (clean.length <= max) return clean;
    return '${clean.substring(0, max).trimRight()}…';
  }

  static String formattedShareText(CommunityPost post) {
    final StringBuffer buffer = StringBuffer();
    final String handle = post.author.cleanHandle.isNotEmpty
        ? ' (@${post.author.cleanHandle})'
        : '';
    buffer.writeln('${post.author.displayName}$handle on alphajournal');
    buffer.writeln();
    buffer.writeln('“${_excerpt(post.body)}”');

    final CommunityTradeSetup? setup = post.tradeSetup;
    if (setup != null) {
      buffer.writeln();
      final String dir = setup.isBullish ? 'LONG' : 'SHORT';
      final List<String> parts = <String>[
        '$dir \$${setup.ticker}',
        if (setup.entry.isNotEmpty) 'Entry ${setup.entry}',
        if (setup.target != null) 'Target ${setup.target}',
        if (setup.stopLoss != null) 'Stop ${setup.stopLoss}',
        if (setup.rMultiple != null) '${setup.rMultiple}',
      ];
      buffer.writeln('Trade setup: ${parts.join(' · ')}');
    }

    final List<String> tags = <String>[
      ...post.tickers.map((t) => t.startsWith('\$') ? t : '\$$t'),
      ...post.tags.map((t) => t.startsWith('#') ? t : '#$t'),
    ];
    if (tags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(tags.take(8).join(' '));
    }

    buffer.writeln();
    buffer.writeln('Read the full post (sign in required):');
    buffer.write(postUrl(post));
    return buffer.toString();
  }

  static Future<bool> launchExternalShare(
    BuildContext context, {
    required Uri uri,
    required String fallbackText,
    required String platformLabel,
  }) => ShareActions.external(context, uri: uri, text: fallbackText,
      platform: platformLabel);

  static Future<void> triggerNativeShare(
    BuildContext context,
    CommunityPost post, {
    CommunityRepository? repository,
    VoidCallback? onShared,
  }) async {
    if (await ShareActions.system(context,
        text: formattedShareText(post),
        subject: 'Post by @${post.author.cleanHandle} on alphajournal')) {
      repository?.recordShare(post.id);
      onShared?.call();
    }
  }

  static Future<void> show(
    BuildContext context, {
    required CommunityPost post,
    CommunityRepository? repository,
    VoidCallback? onSendDm,
    VoidCallback? onRepost,
    ValueChanged<CommunityPost>? onQuote,
    VoidCallback? onShared,
  }) {
    final CommunityRepository resolvedRepo =
        repository ?? CommunityRepository();
    return showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: UiDialog.sheetAnimationStyle(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ctx.sz(540),
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
          ),
          child: Container(
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
              top: false,
              child: CommunityShareSheet(
                post: post,
                repository: resolvedRepo,
                onSendDm: onSendDm,
                onRepost: onRepost,
                onQuote: onQuote,
                onShared: onShared,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CommunityShareSheet> createState() => _CommunityShareSheetState();
}

class _CommunityShareSheetState extends State<CommunityShareSheet> {
  bool _linkCopied = false;

  CommunityRepository get _repo => widget.repository ?? CommunityRepository();

  void _recordShare() {
    _repo.recordShare(widget.post.id);
    widget.onShared?.call();
  }

  Future<void> _copyLink({bool closeSheet = false}) async {
    final copied = await ShareActions.copy(context, CommunityShareSheet.postUrl(widget.post));
    if (!copied) return;
    _recordShare();
    if (!mounted) return;
    if (closeSheet) {
      Navigator.of(context).pop();
    } else {
      setState(() => _linkCopied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final CommunityPost post = widget.post;
    final String url = CommunityShareSheet.postUrl(post);
    final String fullShareText = CommunityShareSheet.formattedShareText(post);
    final int totalShares = post.reposts + _repo.shareCountFor(post.id);

    return SingleChildScrollView(
      child: Column(
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

          // Header row with title & live share count
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Text(
                      'Share Post',
                      style: context.uiText.heading.copyWith(
                        fontSize: context.fs(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (totalShares > 0) ...<Widget>[
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      UiBadge(
                        label: '$totalShares shared',
                        size: UiSize.xs,
                        intent: UiIntent.primary,
                        variant: UiBadgeVariant.soft,
                      ),
                    ],
                  ],
                ),
              ),
              UiIconButton(
                icon: Icons.close_rounded,
                size: UiSize.xs,
                variant: UiVariant.ghost,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Compact Post Preview Card
          UiCard(
            variant: UiCardVariant.outlined,
            density: UiDensity.compact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UiAvatar(
                      name: post.author.displayName,
                      imageUrl: post.author.avatarUrl,
                      size: UiSize.xs,
                      verified: post.author.verified,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(
                      child: Text(
                        '${post.author.displayName} · ${post.author.displayHandle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (post.tradeSetup != null)
                      UiBadge(
                        label:
                            '${post.tradeSetup!.isBullish ? 'LONG' : 'SHORT'} \$${post.tradeSetup!.ticker}',
                        size: UiSize.xs,
                        intent: post.tradeSetup!.isBullish
                            ? UiIntent.success
                            : UiIntent.danger,
                        variant: UiBadgeVariant.soft,
                      ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),

          // Direct Copy Link Bar
          UiCard(
            variant: UiCardVariant.surface,
            density: UiDensity.compact,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.link_rounded,
                  size: context.sz(16),
                  color: theme.colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Expanded(
                  child: Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.mono.copyWith(
                      fontSize: context.fs(11.5),
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiButton(
                  key: const ValueKey('share-sheet-copy-link-btn'),
                  label: _linkCopied ? 'Copied' : 'Copy Link',
                  icon: _linkCopied
                      ? Icons.check_rounded
                      : Icons.content_copy_rounded,
                  size: UiSize.xs,
                  variant: _linkCopied ? UiVariant.solid : UiVariant.soft,
                  intent: _linkCopied ? UiIntent.success : UiIntent.primary,
                  onPressed: _copyLink,
                ),
              ],
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Quick External Social & System Share Strip
          Text(
            'SHARE TO EXTERNAL APPS',
            style: context.uiText.label.copyWith(
              fontSize: context.fs(10.5),
              color: theme.colors.foregroundSubtle,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              UiButton(
                key: const ValueKey('share-sheet-whatsapp'),
                label: 'WhatsApp',
                icon: Icons.chat_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext hostContext =
                      Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final Uri waUri = Uri.parse(
                    'https://wa.me/?text=${Uri.encodeComponent(fullShareText)}',
                  );
                  final shared = await CommunityShareSheet.launchExternalShare(
                    hostContext,
                    uri: waUri,
                    fallbackText: fullShareText,
                    platformLabel: 'WhatsApp',
                  );
                  if (shared) _recordShare();
                },
              ),
              UiButton(
                key: const ValueKey('share-sheet-x'),
                label: 'X / Twitter',
                icon: Icons.alternate_email_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext hostContext =
                      Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final String snippet = post.body.length > 200
                      ? '${post.body.substring(0, 197)}...'
                      : post.body;
                  final String tweetText =
                      '$snippet — via @${post.author.cleanHandle}';
                  final Uri xUri = Uri.parse(
                    'https://x.com/intent/tweet?text=${Uri.encodeComponent(tweetText)}&url=${Uri.encodeComponent(url)}',
                  );
                  final shared = await CommunityShareSheet.launchExternalShare(
                    hostContext,
                    uri: xUri,
                    fallbackText: fullShareText,
                    platformLabel: 'X / Twitter',
                  );
                  if (shared) _recordShare();
                },
              ),
              UiButton(
                key: const ValueKey('share-sheet-telegram'),
                label: 'Telegram',
                icon: Icons.near_me_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext hostContext =
                      Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final Uri tgUri = Uri.parse(
                    'https://t.me/share/url?url=${Uri.encodeComponent(url)}&text=${Uri.encodeComponent(post.body)}',
                  );
                  final shared = await CommunityShareSheet.launchExternalShare(
                    hostContext,
                    uri: tgUri,
                    fallbackText: fullShareText,
                    platformLabel: 'Telegram',
                  );
                  if (shared) _recordShare();
                },
              ),
              UiButton(
                key: const ValueKey('share-sheet-linkedin'),
                label: 'LinkedIn',
                icon: Icons.business_center_outlined,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext hostContext =
                      Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final Uri liUri = Uri.parse(
                    'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(url)}',
                  );
                  final shared = await CommunityShareSheet.launchExternalShare(
                    hostContext,
                    uri: liUri,
                    fallbackText: fullShareText,
                    platformLabel: 'LinkedIn',
                  );
                  if (shared) _recordShare();
                },
              ),
              UiButton(
                key: const ValueKey('share-sheet-email'),
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                size: UiSize.xs,
                variant: UiVariant.outline,
                onPressed: () async {
                  final BuildContext hostContext =
                      Navigator.of(context).context;
                  Navigator.of(context).pop();
                  final String subject =
                      'alphajournal Post by ${post.author.displayName} (@${post.author.cleanHandle})';
                  final Uri mailUri = Uri.parse(
                    'mailto:?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(fullShareText)}',
                  );
                  final shared = await CommunityShareSheet.launchExternalShare(
                    hostContext,
                    uri: mailUri,
                    fallbackText: fullShareText,
                    platformLabel: 'Email',
                  );
                  if (shared) _recordShare();
                },
              ),
              UiButton(
                key: const ValueKey('share-sheet-native'),
                label: 'System Share...',
                icon: Icons.ios_share_rounded,
                size: UiSize.xs,
                variant: UiVariant.soft,
                intent: UiIntent.primary,
                onPressed: () async {
                  final BuildContext hostContext =
                      Navigator.of(context).context;
                  Navigator.of(context).pop();
                  await CommunityShareSheet.triggerNativeShare(
                    hostContext,
                    post,
                    repository: _repo,
                    onShared: widget.onShared,
                  );
                },
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.xs)),

          // Option 1: Send via Direct Message
          _shareOption(
            context,
            key: const ValueKey('share-sheet-dm'),
            icon: Icons.send_rounded,
            title: 'Send via Direct Message',
            subtitle: 'Share privately with a fellow trader',
            onTap: () {
              final BuildContext hostContext = Navigator.of(context).context;
              _recordShare();
              Navigator.of(context).pop();
              if (widget.onSendDm != null) {
                widget.onSendDm!();
              } else {
                CommunitySendDmDialog.show(
                  hostContext,
                  post: post,
                  repository: _repo,
                );
              }
            },
          ),

          // Option 2: Share to Trader Conversation (Messages Thread)
          _shareOption(
            context,
            key: const ValueKey('share-sheet-conversation'),
            icon: Icons.forum_outlined,
            title: 'Share to Conversation Thread',
            subtitle: 'Post into an active alphajournal Messages thread',
            onTap: () {
              final BuildContext hostContext = Navigator.of(context).context;
              _recordShare();
              Navigator.of(context).pop();
              final AppLinkRef ref = AppLinkRef(
                id: post.id,
                kind: AppLinkKind.communityPost,
                title: 'Post by @${post.author.cleanHandle}',
                subtitle: post.body.length > 80
                    ? '${post.body.substring(0, 80)}...'
                    : post.body,
                icon: Icons.public_rounded,
              );
              ShareToConversationDialog.show(
                hostContext,
                reference: ref,
                initialText: 'Check out this post by @${post.author.cleanHandle}',
                onShared: (_) {
                  if (hostContext.mounted) {
                    UiToast.show(
                      hostContext,
                      title: 'Shared to Conversation',
                      message: 'Post sent to your trader chat thread.',
                      intent: UiIntent.success,
                    );
                  }
                },
              );
            },
          ),

          // Option 3: Instant Repost to Community Feed
          _shareOption(
            context,
            key: const ValueKey('share-sheet-repost'),
            icon: Icons.repeat_rounded,
            title: post.reposted ? 'Undo Repost' : 'Repost to Community Feed',
            subtitle: 'Broadcast immediately to your followers',
            onTap: () {
              final BuildContext hostContext = Navigator.of(context).context;
              _recordShare();
              Navigator.of(context).pop();
              if (widget.onRepost != null) {
                widget.onRepost!();
              } else {
                _repo.toggleRepost(post.id);
              }
              if (hostContext.mounted) {
                UiToast.show(
                  hostContext,
                  title: post.reposted ? 'Repost Removed' : 'Reposted to Feed',
                  message: post.reposted
                      ? 'Removed repost from your profile feed.'
                      : 'Shared @${post.author.cleanHandle}\'s post with your followers.',
                  intent: UiIntent.success,
                );
              }
            },
          ),

          // Option 4: Quote Post on Feed
          _shareOption(
            context,
            key: const ValueKey('share-sheet-quote'),
            icon: Icons.format_quote_rounded,
            title: 'Quote Post on Feed',
            subtitle: 'Add your own thesis, chart, or commentary',
            onTap: () {
              final BuildContext hostContext = Navigator.of(context).context;
              _recordShare();
              Navigator.of(context).pop();
              if (widget.onQuote != null) {
                widget.onQuote!(post);
              } else if (hostContext.mounted) {
                UiDialog.show<void>(
                  hostContext,
                  maxWidth: 620,
                  child: CommunityComposerCard(
                    author: _repo.currentAuthor,
                    repository: _repo,
                    quotedPost: post,
                    onPostCreated: () => Navigator.of(hostContext).pop(),
                    onClose: () => Navigator.of(hostContext).pop(),
                  ),
                );
              }
            },
          ),

          // Option 5: Save Post to Trader Notes
          _shareOption(
            context,
            key: const ValueKey('share-sheet-save-note'),
            icon: Icons.note_add_outlined,
            title: 'Save Post to Trader Notes',
            subtitle: 'Clip post, tickers, and setup into your Notes library',
            onTap: () async {
              final BuildContext hostContext = Navigator.of(context).context;
              _recordShare();
              Navigator.of(context).pop();
              final saved = await CopilotFeatureConnector.saveAsNote(
                title:
                    'Community Post · ${post.author.displayName} (@${post.author.cleanHandle})',
                body: fullShareText,
                tags: <String>[
                  ...post.tickers.map((t) => t.replaceAll('\$', '')),
                  ...post.tags.map((t) => t.replaceAll('#', '')),
                  'community-clip',
                ],
              );
              if (hostContext.mounted) {
                UiToast.show(
                  hostContext,
                  title: 'Saved to Trader Notes',
                  message: 'Created note "${saved.note.title}".',
                  intent: UiIntent.success,
                );
              }
            },
          ),

          // Option 6: Analyze with AI Copilot
          _shareOption(
            context,
            key: const ValueKey('share-sheet-copilot'),
            icon: Icons.auto_awesome_rounded,
            title: 'Analyze with AI Copilot',
            subtitle: 'Validate thesis, sentiment, and setups',
            onTap: () {
              final BuildContext hostContext = Navigator.of(context).context;
              _recordShare();
              Navigator.of(context).pop();
              final String prompt =
                  'Analyze community post by @${post.author.cleanHandle}:\n\n'
                  '"${post.body}"\n\n'
                  'Provide sentiment breakdown, technical setup validity, and potential counter-thesis risks.';

              CopilotSheet.show(
                hostContext,
                repository: CopilotScope.repository,
                initialPrompt: prompt,
                contextTitle: 'Post by @${post.author.cleanHandle}',
                contextSubtitle: post.body.length > 50
                    ? '${post.body.substring(0, 50)}...'
                    : post.body,
                contextIcon: Icons.public_rounded,
                contextRef: AppLinkRef(
                  id: post.id,
                  kind: AppLinkKind.communityPost,
                  title: 'Post by @${post.author.cleanHandle}',
                  subtitle: post.body,
                ),
              );
            },
          ),

          // Option 7: Copy Formatted Post & Setup Text
          _shareOption(
            context,
            key: const ValueKey('share-sheet-copy-text'),
            icon: Icons.copy_rounded,
            title: 'Copy Formatted Post & Setup',
            subtitle: 'Copy full post body, setup metrics, and link',
            onTap: () async {
              final hostContext = Navigator.of(context).context;
              Navigator.of(context).pop();
              if (await ShareActions.copy(hostContext, fullShareText,
                  title: 'Copied to Clipboard')) {
                _recordShare();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _shareOption(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final UiTheme theme = context.ui;

    return UiInteractive(
      key: key,
      onTap: onTap,
      borderRadius: context.radius(theme.radii.md),
      builder: (BuildContext ctx, UiInteractiveState state) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: ctx.sp(theme.spacing.xs),
            vertical: ctx.sp(theme.spacing.xs),
          ),
          decoration: BoxDecoration(
            color: state.hovered || state.pressed
                ? theme.colors.surfaceHover
                : Colors.transparent,
            borderRadius: ctx.radius(theme.radii.md),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: ctx.sz(36),
                height: ctx.sz(36),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colors.surfaceMuted,
                  borderRadius: ctx.radius(theme.radii.sm),
                ),
                child: Icon(
                  icon,
                  size: ctx.sz(18),
                  color: theme.colors.foreground,
                ),
              ),
              SizedBox(width: ctx.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: ctx.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: ctx.fs(13),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ctx.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                        fontSize: ctx.fs(11),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: ctx.sz(16),
                color: theme.colors.foregroundSubtle,
              ),
            ],
          ),
        );
      },
    );
  }
}
