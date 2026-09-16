import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';
import 'package:tradex/features/community/data/community_repository.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, this.repository});

  final CommunityRepository? repository;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late final CommunityRepository _repo;
  bool _loading = true;
  List<AppPost> _posts = [];
  String _postDraft = '';

  final AppTrader _me = const AppTrader(
    id: 'usr_me',
    handle: 'nitish_trader',
    displayName: 'Nitish Kumar',
  );

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? CommunityRepositoryImpl();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _loading = true);
    try {
      final feed = await _repo.getPosts();
      if (mounted) {
        setState(() {
          _posts = feed;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('CommunityPage error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCreatePost() async {
    final text = _postDraft.trim();
    if (text.isEmpty) return;

    setState(() => _postDraft = '');
    try {
      final post = await _repo.createPost(content: text);
      if (mounted) {
        setState(() {
          _posts = [post, ..._posts];
        });
        UiToast.show(
          context,
          title: 'Post Published',
          message: 'Your post is now visible on the trader feed.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        UiToast.show(
          context,
          title: 'Error',
          message: 'Could not publish post: $e',
          intent: UiIntent.danger,
        );
      }
    }
  }

  Future<void> _handleLikePost(AppPost post) async {
    try {
      await _repo.likePost(post.id);
      final updatedPosts = _posts.map((p) {
        if (p.id == post.id) {
          final isLiked = p.liked;
          return AppPost(
            id: p.id,
            author: p.author,
            body: p.body,
            createdAt: p.createdAt,
            likes: isLiked ? p.likes - 1 : p.likes + 1,
            comments: p.comments,
            views: p.views,
            liked: !isLiked,
            saved: p.saved,
            imageUrl: p.imageUrl,
            tickers: p.tickers,
            attachments: p.attachments,
          );
        }
        return p;
      }).toList();
      setState(() => _posts = updatedPosts);
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  Future<void> _handleSavePost(AppPost post) async {
    try {
      await _repo.savePost(post.id);
      final isSaved = post.saved;
      setState(() {
        _posts = _posts.map((p) {
          if (p.id == post.id) {
            return AppPost(
              id: p.id,
              author: p.author,
              body: p.body,
              createdAt: p.createdAt,
              likes: p.likes,
              comments: p.comments,
              views: p.views,
              liked: p.liked,
              saved: !isSaved,
              imageUrl: p.imageUrl,
              tickers: p.tickers,
              attachments: p.attachments,
            );
          }
          return p;
        }).toList();
      });
      if (!mounted) return;
      UiToast.show(
        context,
        title: isSaved ? 'Bookmark Removed' : 'Post Saved',
        message: isSaved ? 'Post removed from saved bookmarks.' : 'Post saved to your bookmarks.',
        intent: UiIntent.success,
      );
    } catch (e) {
      debugPrint('Save post error: $e');
    }
  }

  void _handleSharePost(AppPost post) {
    UiToast.show(
      context,
      title: 'Post Shared',
      message: 'Post link copied to clipboard.',
      intent: UiIntent.info,
    );
  }

  Future<void> _handleOpenPost(AppPost post) async {
    await _repo.incrementView(post.id);
    if (!mounted) return;
    setState(() {
      _posts = _posts.map((p) {
        if (p.id == post.id) {
          return AppPost(
            id: p.id,
            author: p.author,
            body: p.body,
            createdAt: p.createdAt,
            likes: p.likes,
            comments: p.comments,
            views: p.views + 1,
            liked: p.liked,
            saved: p.saved,
            imageUrl: p.imageUrl,
            tickers: p.tickers,
            attachments: p.attachments,
          );
        }
        return p;
      }).toList();
    });
  }

  Future<void> _handleCommentPost(AppPost post) async {
    final comments = await _repo.getComments(post.id);
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ui.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sp(context.ui.radii.xl)),
        ),
      ),
      builder: (ctx) {
        String commentText = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
                left: context.sp(context.ui.spacing.lg),
                right: context.sp(context.ui.spacing.lg),
                top: context.sp(context.ui.spacing.lg),
              ),
              child: SizedBox(
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('Discussion & Replies', style: context.uiText.bodyStrong),
                        const Spacer(),
                        UiIconButton(
                          icon: Icons.close,
                          size: UiSize.sm,
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.sm)),
                    UiDivider(),
                    Expanded(
                      child: comments.isEmpty
                          ? const UiEmptyState(
                              title: 'No replies yet',
                              message: 'Be the first trader to join the discussion.',
                              icon: Icons.forum_outlined,
                            )
                          : ListView.separated(
                              itemCount: comments.length,
                              separatorBuilder: (cCtx, iIdx) => UiDivider(),
                              itemBuilder: (_, idx) {
                                final c = comments[idx];
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: context.sp(context.ui.spacing.sm),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      UiAvatar(
                                        name: c.author.displayName ?? c.author.handle,
                                        imageUrl: c.author.avatarUrl,
                                      ),
                                      SizedBox(width: context.sp(context.ui.spacing.sm)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '@${c.author.handle}',
                                              style: context.uiText.bodyStrong,
                                            ),
                                            Text(c.body, style: context.uiText.body),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    UiDivider(),
                    Row(
                      children: [
                        Expanded(
                          child: UiInput(
                            hintText: 'Add a reply...',
                            value: commentText,
                            onChanged: (v) => setModalState(() => commentText = v),
                          ),
                        ),
                        SizedBox(width: context.sp(context.ui.spacing.sm)),
                        UiButton(
                          label: 'Reply',
                          size: UiSize.sm,
                          onPressed: commentText.trim().isEmpty
                              ? null
                              : () async {
                                  final text = commentText.trim();
                                  setModalState(() => commentText = '');
                                  await _repo.commentPost(post.id, text);
                                  final newComment = AppComment(
                                    id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                                    author: _me,
                                    body: text,
                                    createdAt: DateTime.now(),
                                  );
                                  setModalState(() {
                                    comments.add(newComment);
                                  });
                                  if (mounted) {
                                    setState(() {
                                      _posts = _posts.map((p) {
                                        if (p.id == post.id) {
                                          return AppPost(
                                            id: p.id,
                                            author: p.author,
                                            body: p.body,
                                            createdAt: p.createdAt,
                                            likes: p.likes,
                                            comments: p.comments + 1,
                                            views: p.views,
                                            liked: p.liked,
                                            saved: p.saved,
                                            imageUrl: p.imageUrl,
                                            tickers: p.tickers,
                                            attachments: p.attachments,
                                          );
                                        }
                                        return p;
                                      }).toList();
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                    SizedBox(height: context.sp(context.ui.spacing.md)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    if (_loading) {
      return UiSkeleton.community();
    }

    return AppPageBlock(
      title: 'Trader Community',
      subtitle: 'Share setups, debate quant hypotheses, and follow top performers',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppComposerBlock(
                    me: _me,
                    value: _postDraft,
                    onChanged: (v) => setState(() => _postDraft = v),
                    onSubmit: _handleCreatePost,
                  ),
                  UiGap.v(context.sp(theme.spacing.lg)),
                  AppFeedBlock(
                    posts: _posts,
                    onLike: _handleLikePost,
                    onComment: _handleCommentPost,
                    onSave: _handleSavePost,
                    onShare: _handleSharePost,
                    onOpen: _handleOpenPost,
                  ),
                ],
              ),
            ),
            if (!context.uiRes.isMobile) ...[
              UiGap.h(context.sp(theme.spacing.lg)),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppLeaderboardBlock(
                      entries: DemoDataSource.instance.leaderboard('week'),
                      period: 'Week',
                    ),
                    UiGap.v(context.sp(theme.spacing.lg)),
                    AppSuggestedTradersBlock(
                      traders: DemoDataSource.instance.traders(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
