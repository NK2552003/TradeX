import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';

/// Encodes and extracts an optional linked community post reference inside a
/// comment body (`[[post:<id>]]`) so comments can embed quoted posts without
/// requiring a separate schema migration.
class CommunityCommentLinkCodec {
  static final RegExp _tokenPattern = RegExp(
    r'\s*\[\[post:([A-Za-z0-9_\-]+)\]\]\s*',
  );

  static String encode(String body, CommunityPost? linkedPost) {
    final String clean = strip(body);
    if (linkedPost == null) return clean;
    final String marker = '[[post:${linkedPost.id}]]';
    return clean.isEmpty ? marker : '$clean\n$marker';
  }

  static String? extractPostId(String body) {
    final match = _tokenPattern.firstMatch(body);
    return match?.group(1);
  }

  static String strip(String body) => body.replaceAll(_tokenPattern, ' ').trim();
}

/// Result returned by [showCommunityPostLinkPicker].
class CommunityPostLinkPickResult {
  const CommunityPostLinkPickResult({this.post, this.unlink = false});
  final CommunityPost? post;
  final bool unlink;
}

/// Opens a searchable picker to tag (`@mention`) a trader in a post or comment.
Future<CommunityAuthor?> showCommunityTraderTagPicker(
  BuildContext context, {
  required CommunityRepository repository,
}) async {
  final List<CommunityAuthor> allTraders = repository.allKnownAuthors;
  final TextEditingController searchCtrl = TextEditingController();

  final CommunityAuthor? picked = await UiDialog.show<CommunityAuthor>(
    context,
    maxWidth: 460,
    child: StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setDialogState) {
        final UiTheme theme = ctx.ui;
        final String q = searchCtrl.text.trim();
        final List<CommunityAuthor> filtered = q.isEmpty
            ? allTraders
            : repository.searchUsers(q);

        return UiDialog(
          title: 'Tag Someone',
          description: 'Mention a trader with @handle in your post or reply.',
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  style: ctx.uiText.body,
                  decoration: InputDecoration(
                    hintText: 'Search traders by name or @handle…',
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      size: 18,
                      color: theme.colors.foregroundMuted,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colors.surfaceMuted.withValues(
                      alpha: 0.45,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: ctx.radius(theme.radii.md),
                      borderSide: BorderSide(color: theme.colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: ctx.radius(theme.radii.md),
                      borderSide: BorderSide(color: theme.colors.border),
                    ),
                  ),
                ),
                SizedBox(height: ctx.sp(theme.spacing.sm)),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No matching traders found.',
                            textAlign: TextAlign.center,
                            style: ctx.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              SizedBox(height: ctx.sp(theme.spacing.xxs)),
                          itemBuilder: (_, int i) {
                            final CommunityAuthor trader = filtered[i];
                            final Color verifiedColor = trader.verifiedColor(
                              theme,
                            );
                            return InkWell(
                              borderRadius: ctx.radius(theme.radii.md),
                              onTap: () => Navigator.of(ctx).pop(trader),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: ctx.sp(theme.spacing.sm),
                                  vertical: ctx.sp(theme.spacing.xs),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    UiAvatar(
                                      name: trader.displayName,
                                      imageUrl: trader.avatarUrl,
                                      size: UiSize.sm,
                                      verified: trader.verified,
                                      verifiedColor: verifiedColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Flexible(
                                                child: Text(
                                                  trader.displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: ctx.uiText.bodyStrong
                                                      .copyWith(
                                                        fontSize: 13.5,
                                                        color: theme
                                                            .colors
                                                            .foreground,
                                                      ),
                                                ),
                                              ),
                                              if (trader.verified) ...<Widget>[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.verified_rounded,
                                                  size: 14,
                                                  color: verifiedColor,
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            trader.displayHandle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ctx.uiText.caption.copyWith(
                                              color:
                                                  theme.colors.foregroundMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: theme.colors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            UiButton(
              label: 'Cancel',
              variant: UiVariant.outline,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    ),
  );
  searchCtrl.dispose();
  return picked;
}

/// Opens a searchable picker to link/embed a public community post inside a
/// post or comment.
Future<CommunityPostLinkPickResult?> showCommunityPostLinkPicker(
  BuildContext context, {
  required CommunityRepository repository,
  String? excludePostId,
  String? selectedPostId,
  bool allowUnlink = false,
}) async {
  final Map<String, CommunityPost> unique = <String, CommunityPost>{};
  for (final p in <CommunityPost>[
    ...repository.forYouPosts,
    ...repository.followingPosts,
    ...repository.signalPosts,
    ...repository.bookmarkedPosts,
  ]) {
    if (p.isPublic && p.id != excludePostId) {
      unique.putIfAbsent(p.id, () => p);
    }
  }
  final List<CommunityPost> candidates = unique.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final TextEditingController searchCtrl = TextEditingController();
  final CommunityPostLinkPickResult? result =
      await UiDialog.show<CommunityPostLinkPickResult>(
        context,
        maxWidth: 560,
        child: StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            final UiTheme theme = ctx.ui;
            final String q = searchCtrl.text.trim().toLowerCase();
            final List<CommunityPost> filtered = q.isEmpty
                ? candidates
                : candidates.where((p) {
                    return p.body.toLowerCase().contains(q) ||
                        p.author.displayName.toLowerCase().contains(q) ||
                        p.author.handle.toLowerCase().contains(q) ||
                        p.tickers.any((t) => t.toLowerCase().contains(q)) ||
                        p.tags.any((t) => t.toLowerCase().contains(q));
                  }).toList();

            return UiDialog(
              title: 'Link a Community Post',
              description: 'Embed a public post as a live quote card.',
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setDialogState(() {}),
                      style: ctx.uiText.body,
                      decoration: InputDecoration(
                        hintText: 'Search by author, @handle, ticker, or text…',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: theme.colors.foregroundMuted,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: theme.colors.surfaceMuted.withValues(
                          alpha: 0.45,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: ctx.radius(theme.radii.md),
                          borderSide: BorderSide(color: theme.colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: ctx.radius(theme.radii.md),
                          borderSide: BorderSide(color: theme.colors.border),
                        ),
                      ),
                    ),
                    SizedBox(height: ctx.sp(theme.spacing.sm)),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 28),
                              child: Text(
                                candidates.isEmpty
                                    ? 'No public community posts loaded yet.'
                                    : 'No matching posts found.',
                                textAlign: TextAlign.center,
                                style: ctx.uiText.caption.copyWith(
                                  color: theme.colors.foregroundMuted,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  SizedBox(height: ctx.sp(theme.spacing.xs)),
                              itemBuilder: (_, int i) {
                                final CommunityPost post = filtered[i];
                                final bool isSelected =
                                    selectedPostId == post.id;
                                return InkWell(
                                  borderRadius: ctx.radius(theme.radii.md),
                                  onTap: () => Navigator.of(
                                    ctx,
                                  ).pop(CommunityPostLinkPickResult(post: post)),
                                  child: Container(
                                    padding: EdgeInsets.all(
                                      ctx.sp(theme.spacing.sm),
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colors.primary.withValues(
                                              alpha: 0.1,
                                            )
                                          : theme.colors.surfaceMuted
                                                .withValues(alpha: 0.35),
                                      borderRadius: ctx.radius(theme.radii.md),
                                      border: Border.all(
                                        color: isSelected
                                            ? theme.colors.primary.withValues(
                                                alpha: 0.55,
                                              )
                                            : theme.colors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Row(
                                          children: <Widget>[
                                            UiAvatar(
                                              name: post.author.displayName,
                                              imageUrl: post.author.avatarUrl,
                                              size: UiSize.xs,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${post.author.displayName} · ${post.author.displayHandle}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: ctx.uiText.caption
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: theme
                                                          .colors
                                                          .foreground,
                                                    ),
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 16,
                                                color: theme.colors.primary,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          post.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: ctx.uiText.caption.copyWith(
                                            color: theme.colors.foregroundMuted,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (post
                                            .tickers
                                            .isNotEmpty) ...<Widget>[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 4,
                                            children: <Widget>[
                                              for (final t in post.tickers.take(
                                                4,
                                              ))
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
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                if (allowUnlink)
                  UiButton(
                    label: 'Unlink Post',
                    variant: UiVariant.ghost,
                    intent: UiIntent.danger,
                    onPressed: () => Navigator.of(
                      ctx,
                    ).pop(const CommunityPostLinkPickResult(unlink: true)),
                  ),
                UiButton(
                  label: 'Cancel',
                  variant: UiVariant.outline,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            );
          },
        ),
      );
  searchCtrl.dispose();
  return result;
}
