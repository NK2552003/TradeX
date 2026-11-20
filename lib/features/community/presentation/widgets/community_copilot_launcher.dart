import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/copilot/copilot.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';

Future<void> showCommunityCopilot(
  BuildContext context, {
  String? initialPrompt,
  bool autoSendInitialPrompt = false,
  Widget? contextCard,
  ValueChanged<AppLinkRef>? onOpenRef,
}) => CopilotSheet.show(
  context,
  repository: CopilotScope.repository,
  contextTitle: 'Copilot',
  initialPrompt: initialPrompt,
  autoSendInitialPrompt: autoSendInitialPrompt,
  contextCard: contextCard,
  onOpenRef: onOpenRef,
);

Future<String> _resolveAttachmentBody(
  AppWritingPostAttachment attachment,
) async {
  final AppLinkRef src = attachment.source;
  String? full;
  try {
    switch (src.kind) {
      case AppLinkKind.note:
        final note = await NotesRepositoryScope.repository.getById(src.id);
        if (note != null && note.content.trim().isNotEmpty) {
          full = note.content.trim();
        }
        break;
      case AppLinkKind.journal:
        final trade = await JournalRepositoryScope.repository.getById(src.id);
        if (trade != null) {
          final String bodyText = trade.content.trim().isNotEmpty
              ? trade.content.trim()
              : (trade.notes?.trim() ?? '');
          final parts = <String>[
            '${trade.displayTitle} (${trade.isOpen ? 'Open trade' : 'Closed trade'})',
            if (bodyText.isNotEmpty) bodyText,
          ];
          full = parts.join('\n');
        }
        break;
      case AppLinkKind.strategy:
        final strat = await StrategiesRepositoryScope.repository.getById(
          src.id,
        );
        if (strat != null) {
          final String sum = strat.summary?.trim() ?? '';
          final parts = <String>[
            if (sum.isNotEmpty) sum,
            if (strat.content.trim().isNotEmpty) strat.content.trim(),
          ];
          full = parts.join('\n');
        }
        break;
      default:
        break;
    }
  } catch (_) {}

  final String text = (full != null && full.isNotEmpty)
      ? full
      : attachment.excerpt.trim();
  if (text.length > 2200) {
    return '${text.substring(0, 2200)}…';
  }
  return text;
}

/// Opens the floating Community Copilot sheet preloaded with an embedded
/// preview of [post] (including attached notes/records and linked posts) and
/// immediately asks Copilot to explain that post.
Future<void> showCommunityCopilotForPost(
  BuildContext context, {
  required CommunityPost post,
  ValueChanged<AppLinkRef>? onOpenRef,
}) async {
  final StringBuffer prompt = StringBuffer(
    'Explain this community post clearly — break down the thesis, any attached note/record or linked post, key tickers or setup details, potential catalysts, and risks:\n\n'
    'Author: ${post.author.displayName} (${post.author.displayHandle})\n'
    'Post link: /community?post=${Uri.encodeQueryComponent(post.id)}\n'
    'Post:\n${post.body.trim()}',
  );
  if (post.tickers.isNotEmpty) {
    prompt.write('\nTickers: ${post.tickers.map((t) => '\$$t').join(', ')}');
  }
  if (post.tags.isNotEmpty) {
    prompt.write('\nTags: ${post.tags.map((t) => '#$t').join(', ')}');
  }
  if (post.tradeSetup != null) {
    final s = post.tradeSetup!;
    prompt.write(
      '\nTrade setup: ${s.side} \$${s.ticker} | Entry: ${s.entry}'
      '${s.stopLoss != null ? ' | SL: ${s.stopLoss}' : ''}'
      '${s.target != null ? ' | Target: ${s.target}' : ''}',
    );
  }
  if (post.attachment != null) {
    final AppWritingPostAttachment att = post.attachment!;
    final String attBody = await _resolveAttachmentBody(att);
    final String kindLabel = switch (att.source.kind) {
      AppLinkKind.note => 'Note',
      AppLinkKind.journal => 'Trade Journal',
      AppLinkKind.strategy => 'Strategy',
      _ => att.source.kind.name,
    };
    prompt.write(
      '\n\nAttached $kindLabel: ${att.source.title}'
      '\nAttachment link: /${att.source.kind.name}/${att.source.id}',
    );
    if (att.tags.isNotEmpty) {
      prompt.write(
        '\nAttachment tags: ${att.tags.map((t) => '#$t').join(', ')}',
      );
    }
    if (attBody.isNotEmpty) {
      prompt.write('\nAttached $kindLabel content:\n$attBody');
    }
  }
  if (post.quoted != null) {
    final CommunityPost q = post.quoted!;
    prompt.write(
      '\n\nLinked/Quoted Post by ${q.author.displayName} (${q.author.displayHandle})'
      '\nLinked post link: /community?post=${Uri.encodeQueryComponent(q.id)}'
      '\nLinked post text:\n${q.body.trim()}',
    );
    if (q.tickers.isNotEmpty) {
      prompt.write(
        '\nLinked post tickers: ${q.tickers.map((t) => '\$$t').join(', ')}',
      );
    }
    if (q.attachment != null) {
      final String qAttBody = await _resolveAttachmentBody(q.attachment!);
      prompt.write(
        '\nLinked post attachment: ${q.attachment!.source.title}'
        '\nLinked attachment link: /${q.attachment!.source.kind.name}/${q.attachment!.source.id}'
        '${qAttBody.isNotEmpty ? '\n$qAttBody' : ''}',
      );
    }
  }
  if (post.linkPreview != null) {
    final lp = post.linkPreview!;
    prompt.write(
      '\n\nAttached Link: ${lp.title} (${lp.domain})'
      '${lp.description != null && lp.description!.trim().isNotEmpty ? '\n${lp.description!.trim()}' : ''}',
    );
  }
  if (post.videoUrl != null && post.videoUrl!.trim().isNotEmpty) {
    prompt.write('\n\nAttached Video: ${post.videoUrl!.trim()}');
  }
  if (post.poll != null) {
    final poll = post.poll!;
    prompt.write(
      '\n\nPoll: ${poll.question}\nOptions: ${poll.options.map((o) => o.text).join(' | ')}',
    );
  }

  if (!context.mounted) return;
  await showCommunityCopilot(
    context,
    initialPrompt: prompt.toString(),
    autoSendInitialPrompt: true,
    onOpenRef: onOpenRef,
    contextCard: _CommunityCopilotPostCard(post: post, onOpenRef: onOpenRef),
  );
}

class _CommunityCopilotPostCard extends StatelessWidget {
  const _CommunityCopilotPostCard({required this.post, this.onOpenRef});
  final CommunityPost post;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final String? thumb = post.effectiveImageUrls.isNotEmpty
        ? post.effectiveImageUrls.first
        : null;
    final Color verifiedColor = post.author.verifiedColor(theme);
    final AppWritingPostAttachment? att = post.attachment;
    final CommunityPost? quoted = post.quoted;
    final CommunityLinkPreview? linkPreview = post.linkPreview;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted.withValues(alpha: 0.45),
        borderRadius: context.radius(theme.radii.lg),
        border: Border.all(color: theme.colors.border),
      ),
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
                verifiedColor: verifiedColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  post.author.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.bodyStrong.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colors.foreground,
                  ),
                ),
              ),
              if (post.author.verified) ...<Widget>[
                const SizedBox(width: 4),
                Icon(Icons.verified_rounded, size: 14, color: verifiedColor),
              ],
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${post.author.displayHandle} · ${AppTokens.relativeTime(post.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    fontSize: 12,
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (thumb != null) ...<Widget>[
                ClipRRect(
                  borderRadius: context.radius(theme.radii.md),
                  child: Image.network(
                    thumb,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  post.body.trim(),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.body.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.colors.foreground,
                  ),
                ),
              ),
            ],
          ),
          if (att != null) ...<Widget>[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: context.radius(theme.radii.md),
              onTap: onOpenRef == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onOpenRef!(att.source.copyWith(isPublicContext: true));
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colors.surface,
                  borderRadius: context.radius(theme.radii.md),
                  border: Border.all(color: theme.colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      att.source.icon ?? Icons.description_outlined,
                      size: 15,
                      color: theme.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            att.source.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colors.foreground,
                            ),
                          ),
                          if (att.excerpt.trim().isNotEmpty)
                            Text(
                              att.excerpt.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                fontSize: 11,
                                color: theme.colors.foregroundMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onOpenRef != null)
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: theme.colors.foregroundMuted,
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (quoted != null) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colors.surface,
                borderRadius: context.radius(theme.radii.md),
                border: Border.all(color: theme.colors.border),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.format_quote_rounded,
                    size: 15,
                    color: theme.colors.foregroundMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${quoted.author.displayHandle}: ${quoted.body.trim()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (linkPreview != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: theme.colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    linkPreview.title.isNotEmpty
                        ? linkPreview.title
                        : linkPreview.domain,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (post.tickers.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final t in post.tickers.take(5))
                  UiBadge(
                    label: '\$$t',
                    size: UiSize.xs,
                    variant: UiBadgeVariant.soft,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class CommunityCopilotLauncher extends StatefulWidget {
  const CommunityCopilotLauncher({
    super.key,
    this.onCompose,
    this.showCompose = false,
    this.syncWithMobileDock = false,
  });
  final VoidCallback? onCompose;
  final bool showCompose;
  final bool syncWithMobileDock;

  @override
  State<CommunityCopilotLauncher> createState() =>
      _CommunityCopilotLauncherState();
}

class _CommunityCopilotLauncherState extends State<CommunityCopilotLauncher> {
  bool _open = false;

  Widget _glassPillButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final theme = context.ui;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool narrowMobile =
        context.uiRes.isMobile && MediaQuery.sizeOf(context).width < 430;
    final double size = narrowMobile ? 48.0 : 56.0;
    final BorderRadius radius = BorderRadius.circular(size / 2);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.36 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(
                alpha: isDark ? 0.62 : 0.74,
              ),
              borderRadius: radius,
              border: Border.all(
                color: theme.colors.borderStrong.withValues(
                  alpha: isDark ? 0.65 : 0.75,
                ),
                width: 1.2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: tooltip,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onPressed,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCompose = widget.showCompose && widget.onCompose != null;
    final VoidCallback? onCopilot = _open
        ? null
        : () async {
            setState(() => _open = true);
            try {
              await showCommunityCopilot(context);
            } finally {
              if (mounted) setState(() => _open = false);
            }
          };

    Widget wrapSynced(Widget child, {Duration delay = Duration.zero}) {
      if (!widget.syncWithMobileDock) return child;
      return AppDockSyncedFab(
        edge: AppDockRevealEdge.right,
        delay: delay,
        child: child,
      );
    }

    if (!hasCompose) {
      return wrapSynced(
        _glassPillButton(
          context: context,
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Ask copilot',
          onPressed: onCopilot,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        wrapSynced(
          _glassPillButton(
            context: context,
            icon: Icons.edit_outlined,
            tooltip: 'Create post',
            onPressed: widget.onCompose,
          ),
          delay: const Duration(milliseconds: 70),
        ),
        const SizedBox(height: 10),
        wrapSynced(
          _glassPillButton(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Ask copilot',
            onPressed: onCopilot,
          ),
        ),
      ],
    );
  }
}
