import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/record_access.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/markdown_kit/markdown_preview.dart';
import 'package:tradex/features/affiliate_program/models/affiliate_workspace.dart'
    show formatInrAmount;
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/unified_comments_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_author_header.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Interactive modal window presenting a public Writing Desk record (Note, Trade, Strategy)
/// as a rich community post open window with author stats, financial metrics, engagement bar,
/// and discussion comments thread.
class PublicRecordDetailModal extends StatefulWidget {
  const PublicRecordDetailModal({
    super.key,
    required this.ref,
    this.initialNote,
    this.initialTrade,
    this.initialStrategy,
    this.onOpenAuthor,
    this.onOpenEditor,
    this.onOpenRef,
  });

  final AppLinkRef ref;
  final AppNote? initialNote;
  final AppTrade? initialTrade;
  final AppStrategy? initialStrategy;
  final ValueChanged<CommunityAuthor>? onOpenAuthor;
  final VoidCallback? onOpenEditor;
  final ValueChanged<AppLinkRef>? onOpenRef;

  /// Shows the public record open window responsively.
  static Future<void> show(
    BuildContext context, {
    required AppLinkRef ref,
    AppNote? initialNote,
    AppTrade? initialTrade,
    AppStrategy? initialStrategy,
    ValueChanged<CommunityAuthor>? onOpenAuthor,
    VoidCallback? onOpenEditor,
    ValueChanged<AppLinkRef>? onOpenRef,
  }) async {
    final isDesktop = Navigator.of(
      context,
      rootNavigator: true,
    ).context.uiRes.isDesktop;
    if (isDesktop) {
      await showSettingsSideSheet<void>(
        context,
        title: ref.title,
        showHeader: false,
        desktopWidthRatio: 0.48,
        minDesktopWidth: 540,
        maxWidth: 760,
        child: PublicRecordDetailModal(
          ref: ref,
          initialNote: initialNote,
          initialTrade: initialTrade,
          initialStrategy: initialStrategy,
          onOpenAuthor: onOpenAuthor,
          onOpenEditor: onOpenEditor,
          onOpenRef: onOpenRef,
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final theme = ctx.ui;
          return ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(ctx.sp(theme.radii.xl)),
            ),
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.92,
              child: PublicRecordDetailModal(
                ref: ref,
                initialNote: initialNote,
                initialTrade: initialTrade,
                initialStrategy: initialStrategy,
                onOpenAuthor: onOpenAuthor,
                onOpenEditor: onOpenEditor,
                onOpenRef: onOpenRef,
              ),
            ),
          );
        },
      );
    }
  }

  @override
  State<PublicRecordDetailModal> createState() =>
      _PublicRecordDetailModalState();
}

class _PublicRecordDetailModalState extends State<PublicRecordDetailModal> {
  final UnifiedCommentsRepository _commentsRepo =
      UnifiedCommentsRepositoryImpl.instance;
  StreamSubscription<List<CommunityComment>>? _commentsSub;

  bool _loading = true;
  String? _errorMessage;

  AppNote? _note;
  AppTrade? _trade;
  AppStrategy? _strategy;

  CommunityAuthor? _author;
  List<CommunityComment> _comments = const <CommunityComment>[];
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
    _trade = widget.initialTrade;
    _strategy = widget.initialStrategy;
    _loadRecord();
    _initComments();
  }

  @override
  void dispose() {
    _commentsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRecord() async {
    final ref = widget.ref;
    try {
      switch (ref.kind) {
        case AppLinkKind.note:
          _note ??= await NotesRepositoryScope.repository.getById(ref.id);
          if (_note != null) {
            _likeCount = _note!.likeCount;
            _isLiked = _note!.liked;
            _isBookmarked = _note!.isFavorite;
            await _resolveAuthor(_note!.userId);
          } else {
            _errorMessage =
                'This research note is private or has been removed.';
          }
          break;
        case AppLinkKind.journal:
          _trade ??= await JournalRepositoryScope.repository.getById(ref.id);
          if (_trade != null) {
            _isBookmarked = _trade!.isFavorite;
            await _resolveAuthor(_trade!.userId);
          } else {
            _errorMessage =
                'This journal trade is private or has been removed.';
          }
          break;
        case AppLinkKind.strategy:
          _strategy ??= await StrategiesRepositoryScope.repository.getById(
            ref.id,
          );
          if (_strategy != null) {
            _isBookmarked = _strategy!.isFavorite;
            await _resolveAuthor(_strategy!.userId);
          } else {
            _errorMessage =
                'This playbook strategy is private or has been removed.';
          }
          break;
        default:
          _errorMessage = 'Unsupported record type.';
      }
    } catch (e) {
      _errorMessage = 'Could not load record: $e';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _resolveAuthor(String userId) async {
    if (!SupabaseConfig.isConfigured || userId.isEmpty) {
      _author = CommunityAuthor(
        id: userId,
        handle: 'trader',
        displayName: 'Verified Trader',
        userRole: UserRole.customer,
        verified: true,
      );
      return;
    }

    try {
      final client = SupabaseConfig.client!;
      final res = await client
          .from('profiles')
          .select(
            'id, display_name, handle, role, avatar_url, subscription_tier',
          )
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        final tierStr =
            (res['subscription_tier'] as String?)?.toLowerCase() ?? 'free';
        final tier = AppTier.values.firstWhere(
          (t) => t.name.toLowerCase() == tierStr,
          orElse: () => AppTier.free,
        );
        _author = CommunityAuthor(
          id: userId,
          handle: (res['handle'] as String?) ?? 'trader',
          displayName: (res['display_name'] as String?) ?? 'Trader',
          userRole: UserRole.values.firstWhere(
            (r) =>
                r.name.toLowerCase() ==
                ((res['role'] as String?)?.toLowerCase() ?? 'customer'),
            orElse: () => UserRole.customer,
          ),
          avatarUrl: res['avatar_url'] as String?,
          verified: true,
          tier: tier,
        );
        return;
      }
    } catch (e) {
      debugPrint('[PublicRecordDetailModal] _resolveAuthor error: $e');
    }

    _author = CommunityAuthor(
      id: userId,
      handle: 'trader',
      displayName: 'Trader',
      userRole: UserRole.customer,
      verified: true,
    );
  }

  void _initComments() {
    final entityType = widget.ref.kind.name;
    final entityId = widget.ref.id;

    _commentsSub = _commentsRepo
        .watchComments(entityType: entityType, entityId: entityId)
        .listen((comments) {
          if (mounted) setState(() => _comments = comments);
        });

    unawaited(
      _commentsRepo.fetchComments(entityType: entityType, entityId: entityId),
    );
  }

  Future<void> _handleToggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (widget.ref.kind == AppLinkKind.note) {
        await NotesRepositoryScope.repository.toggleLike(widget.ref.id);
      } else if (widget.ref.kind == AppLinkKind.journal) {
        await JournalRepositoryScope.repository.toggleFavorite(widget.ref.id);
      } else if (widget.ref.kind == AppLinkKind.strategy) {
        await StrategiesRepositoryScope.repository.toggleFavorite(
          widget.ref.id,
        );
      }
    } catch (e) {
      debugPrint('[PublicRecordDetailModal] toggleLike error: $e');
    }
  }

  Future<void> _handleToggleBookmark() async {
    setState(() => _isBookmarked = !_isBookmarked);
    try {
      if (widget.ref.kind == AppLinkKind.note) {
        await NotesRepositoryScope.repository.toggleFavorite(widget.ref.id);
      } else if (widget.ref.kind == AppLinkKind.journal) {
        await JournalRepositoryScope.repository.toggleFavorite(widget.ref.id);
      } else if (widget.ref.kind == AppLinkKind.strategy) {
        await StrategiesRepositoryScope.repository.toggleFavorite(
          widget.ref.id,
        );
      }
      if (mounted) {
        UiToast.info(
          context,
          title: _isBookmarked ? 'Bookmarked' : 'Bookmark removed',
          message: _isBookmarked ? 'Saved to your personal collection.' : null,
        );
      }
    } catch (e) {
      debugPrint('[PublicRecordDetailModal] toggleBookmark error: $e');
    }
  }

  void _copyShareLink() {
    final url =
        'https://hejournal.in/community/${widget.ref.kind.name}/${widget.ref.id}';
    Clipboard.setData(ClipboardData(text: url));
    UiToast.success(
      context,
      title: 'Link copied',
      message: 'Post link copied to clipboard.',
    );
  }

  bool get _isAuthor {
    final userId = _note?.userId ?? _trade?.userId ?? _strategy?.userId ?? '';
    return RecordAccess.owns(userId);
  }

  DateTime get _createdAt {
    return _note?.createdAt ??
        _trade?.openedAt ??
        _strategy?.createdAt ??
        DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final isMobile = context.uiRes.isMobile;

    return UiCard(
      variant: UiCardVariant.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Top Navigation / Window Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.sm),
              context.sp(theme.spacing.sm),
              context.sp(theme.spacing.xs),
            ),
            child: Row(
              children: <Widget>[
                UiBadge(
                  label: switch (widget.ref.kind) {
                    AppLinkKind.note => 'Research Note',
                    AppLinkKind.journal => 'Trade Journal',
                    AppLinkKind.strategy => 'Strategy Playbook',
                    _ => 'Community Record',
                  },
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                const UiBadge(
                  label: 'Public',
                  intent: UiIntent.success,
                  variant: UiBadgeVariant.soft,
                ),
                const Spacer(),
                if (_isAuthor && widget.onOpenEditor != null) ...[
                  UiButton(
                    label: isMobile ? 'Edit' : 'Edit in Writing Desk',
                    icon: Icons.edit_outlined,
                    size: UiSize.xs,
                    variant: UiVariant.outline,
                    intent: UiIntent.primary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onOpenEditor!();
                    },
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                ],
                UiIconButton(
                  icon: Icons.share_outlined,
                  size: UiSize.xs,
                  tooltip: 'Share',
                  onPressed: _copyShareLink,
                ),
                UiIconButton(
                  icon: Icons.close_rounded,
                  size: UiSize.xs,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const UiDivider(),

          // Main Scrollable Area
          Expanded(
            child: _loading
                ? Padding(
                    padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        UiSkeleton(width: 180, height: 28),
                        SizedBox(height: 16),
                        UiSkeleton(height: 72),
                        SizedBox(height: 16),
                        UiSkeleton(height: 180),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: UiEmptyState(
                      icon: Icons.lock_outline_rounded,
                      title: 'Unavailable',
                      message: _errorMessage!,
                      action: UiButton(
                        label: 'Back',
                        variant: UiVariant.outline,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.md),
                      vertical: context.sp(theme.spacing.sm),
                    ),
                    children: <Widget>[
                      // Author Header
                      if (_author != null) ...[
                        CommunityAuthorHeader(
                          author: _author!,
                          createdAt: _createdAt,
                          onAuthorTap: widget.onOpenAuthor,
                          onShare: _copyShareLink,
                          onBookmark: _handleToggleBookmark,
                          bookmarked: _isBookmarked,
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                      ],

                      // Specific Record Layout
                      if (widget.ref.kind == AppLinkKind.note && _note != null)
                        _buildNoteBody(_note!, theme)
                      else if (widget.ref.kind == AppLinkKind.journal &&
                          _trade != null)
                        _buildTradeBody(_trade!, theme)
                      else if (widget.ref.kind == AppLinkKind.strategy &&
                          _strategy != null)
                        _buildStrategyBody(_strategy!, theme),

                      SizedBox(height: context.sp(theme.spacing.md)),

                      // Action & Engagement Bar
                      _buildEngagementBar(theme),

                      SizedBox(height: context.sp(theme.spacing.md)),
                      const UiDivider(),
                      SizedBox(height: context.sp(theme.spacing.md)),

                      // Universal LinkedIn-Grade Comments Thread
                      UniversalCommentsSection(
                        targetId: widget.ref.id,
                        targetType: widget.ref.kind.name,
                        comments: _comments,
                        currentUser: _commentsRepo.getCurrentAuthor(),
                        onAuthorTap: widget.onOpenAuthor,
                        onAddComment:
                            (text, {parentCommentId, sentiment}) async {
                              await _commentsRepo.addComment(
                                entityType: widget.ref.kind.name,
                                entityId: widget.ref.id,
                                body: text,
                                parentCommentId: parentCommentId,
                                sentiment: sentiment,
                              );
                            },
                        onLikeComment: (commentId, {reaction}) {
                          _commentsRepo.toggleReaction(
                            commentId: commentId,
                            reaction: reaction ?? '👍',
                          );
                        },
                      ),
                      SizedBox(height: context.sp(theme.spacing.xl)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Note Layout
  // ---------------------------------------------------------------------------
  Widget _buildNoteBody(AppNote note, UiTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Title
        Text(
          note.title.trim().isNotEmpty ? note.title : 'Untitled research note',
          style: context.uiText.title,
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),

        // Meta tags row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            UiBadge(
              label: note.noteType.label,
              intent: UiIntent.primary,
              variant: UiBadgeVariant.soft,
            ),
            if (note.wordCount > 0)
              Text(
                '${note.wordCount} words',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            if (note.checklistTotal > 0)
              Text(
                '✓ ${note.checklistDone}/${note.checklistTotal} items',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            for (final ticker in note.linkedTickers)
              UiBadge(
                label: ticker.startsWith(r'$') ? ticker : '\$$ticker',
                intent: UiIntent.info,
                variant: UiBadgeVariant.soft,
              ),
            for (final tag in note.tags)
              UiBadge(
                label: '#$tag',
                intent: UiIntent.neutral,
                variant: UiBadgeVariant.soft,
              ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Full Content Body
        UiCard(
          variant: UiCardVariant.surface,
          child: RichMarkdownPreview(
            data: note.content,
            onOpenRef: widget.onOpenRef,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Trade Journal Layout
  // ---------------------------------------------------------------------------
  Widget _buildTradeBody(AppTrade trade, UiTheme theme) {
    final isWin = trade.outcome == AppOutcome.win;
    final isLoss = trade.outcome == AppOutcome.loss;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Ticker & Outcome Header
        Row(
          children: <Widget>[
            Text(
              trade.ticker.isNotEmpty
                  ? '\$${trade.ticker.toUpperCase()}'
                  : 'Trade Setup',
              style: context.uiText.title.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            UiBadge(
              label: trade.side == AppSide.short ? 'SHORT' : 'LONG',
              intent: trade.side == AppSide.short
                  ? UiIntent.warning
                  : UiIntent.info,
              variant: UiBadgeVariant.solid,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiBadge(
              label: trade.outcome.name.toUpperCase(),
              intent: isWin
                  ? UiIntent.success
                  : isLoss
                  ? UiIntent.danger
                  : UiIntent.neutral,
              variant: UiBadgeVariant.soft,
            ),
          ],
        ),
        if (trade.title.isNotEmpty) ...[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(trade.title, style: context.uiText.title),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),

        // Key Financial Metrics Grid
        UiCardGrid(
          mainAxisExtent: 180,
          mobileColumns: 2,
          tabletColumns: 4,
          desktopColumns: 4,
          children: <Widget>[
            UiMetricCard(
              title: 'Net PnL',
              value: trade.pnl != 0 ? formatInrAmount(trade.pnl) : '—',
              change: trade.pnlPercent != 0
                  ? '${trade.pnlPercent > 0 ? '+' : ''}${trade.pnlPercent.toStringAsFixed(1)}%'
                  : null,
              isPositive: trade.pnl >= 0,
            ),
            UiMetricCard(
              title: 'R-Multiple',
              value: trade.rMultiple != null
                  ? '${trade.rMultiple! >= 0 ? '+' : ''}${trade.rMultiple!.toStringAsFixed(2)}R'
                  : '—',
              isPositive: (trade.rMultiple ?? 0) >= 0,
            ),
            UiMetricCard(
              title: 'Entry Price',
              value: trade.entry > 0 ? formatInrAmount(trade.entry) : '—',
            ),
            UiMetricCard(
              title: 'Exit Price',
              value: trade.exit != null && trade.exit! > 0
                  ? formatInrAmount(trade.exit!)
                  : 'Open',
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Trade Content & Journal Notes
        if (trade.content.isNotEmpty || (trade.notes?.isNotEmpty ?? false)) ...[
          UiCard(
            variant: UiCardVariant.surface,
            child: RichMarkdownPreview(
              data: trade.content.isNotEmpty
                  ? trade.content
                  : (trade.notes ?? ''),
              onOpenRef: widget.onOpenRef,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
        ],

        // Tags
        if (trade.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in trade.tags)
                UiBadge(
                  label: '#$tag',
                  intent: UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                ),
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Strategy Playbook Layout
  // ---------------------------------------------------------------------------
  Widget _buildStrategyBody(AppStrategy strategy, UiTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Name & Status
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                strategy.name.isNotEmpty ? strategy.name : 'Untitled Playbook',
                style: context.uiText.title,
              ),
            ),
            UiBadge(
              label: strategy.status.label.toUpperCase(),
              intent: strategy.status == AppStrategyStatus.live
                  ? UiIntent.success
                  : strategy.status == AppStrategyStatus.testing
                  ? UiIntent.warning
                  : UiIntent.neutral,
              variant: UiBadgeVariant.soft,
            ),
          ],
        ),
        if (strategy.category != null && strategy.category!.isNotEmpty) ...[
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiBadge(
            label: strategy.category!,
            intent: UiIntent.primary,
            variant: UiBadgeVariant.soft,
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),

        // Strategy Performance Metric Row
        UiCardGrid(
          mainAxisExtent: 180,
          mobileColumns: 2,
          tabletColumns: 4,
          desktopColumns: 4,
          children: <Widget>[
            UiMetricCard(
              title: 'Win Rate',
              value: strategy.winRate > 0
                  ? '${strategy.winRate.toStringAsFixed(1)}%'
                  : '—',
              isPositive: strategy.winRate >= 50,
            ),
            UiMetricCard(
              title: 'Avg R',
              value: strategy.avgR != 0
                  ? '${strategy.avgR > 0 ? '+' : ''}${strategy.avgR.toStringAsFixed(2)}R'
                  : '—',
              isPositive: strategy.avgR >= 0,
            ),
            UiMetricCard(title: 'Logged Trades', value: '${strategy.trades}'),
            UiMetricCard(
              title: 'Net Return',
              value: strategy.netPnl != 0
                  ? formatInrAmount(strategy.netPnl)
                  : '—',
              isPositive: strategy.netPnl >= 0,
            ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Strategy Content / Rules
        UiCard(
          variant: UiCardVariant.surface,
          child: RichMarkdownPreview(
            data: strategy.content,
            onOpenRef: widget.onOpenRef,
          ),
        ),
        SizedBox(height: context.sp(theme.spacing.md)),

        // Tags & Tickers
        if (strategy.linkedTickers.isNotEmpty || strategy.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ticker in strategy.linkedTickers)
                UiBadge(
                  label: ticker.startsWith(r'$') ? ticker : '\$$ticker',
                  intent: UiIntent.info,
                  variant: UiBadgeVariant.soft,
                ),
              for (final tag in strategy.tags)
                UiBadge(
                  label: '#$tag',
                  intent: UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                ),
            ],
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action & Engagement Bar
  // ---------------------------------------------------------------------------
  Widget _buildEngagementBar(UiTheme theme) {
    return Row(
      children: <Widget>[
        UiButton(
          label: _likeCount > 0 ? '$_likeCount' : 'Like',
          icon: _isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          variant: _isLiked ? UiVariant.soft : UiVariant.ghost,
          intent: _isLiked ? UiIntent.danger : UiIntent.neutral,
          size: UiSize.sm,
          onPressed: _handleToggleLike,
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        UiButton(
          label: '${_comments.length}',
          icon: Icons.chat_bubble_outline_rounded,
          variant: UiVariant.ghost,
          intent: UiIntent.neutral,
          size: UiSize.sm,
          onPressed: () {},
        ),
        SizedBox(width: context.sp(theme.spacing.sm)),
        UiButton(
          label: _isBookmarked ? 'Saved' : 'Bookmark',
          icon: _isBookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          variant: _isBookmarked ? UiVariant.soft : UiVariant.ghost,
          intent: _isBookmarked ? UiIntent.primary : UiIntent.neutral,
          size: UiSize.sm,
          onPressed: _handleToggleBookmark,
        ),
        const Spacer(),
        UiButton(
          label: 'Share',
          icon: Icons.share_outlined,
          variant: UiVariant.ghost,
          intent: UiIntent.neutral,
          size: UiSize.sm,
          onPressed: _copyShareLink,
        ),
      ],
    );
  }
}
