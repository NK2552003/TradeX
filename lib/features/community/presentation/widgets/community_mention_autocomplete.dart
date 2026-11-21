import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';

/// Autocomplete suggestion box for @mentions, $cashtags, and #hashtags in community composers.
class CommunityMentionAutocomplete extends StatelessWidget {
  const CommunityMentionAutocomplete({
    super.key,
    required this.query,
    required this.traders,
    required this.onSelectTrader,
    required this.onSelectTicker,
    this.onSelectTag,
    this.popularTickers = const <String>[
      'NIFTY',
      'BANKNIFTY',
      'RELIANCE',
      'HDFCBANK',
      'TCS',
      'INFY',
      'AAPL',
      'NVDA',
      'BTC',
      'ETH',
    ],
    this.popularTags = const <String>[
      'Breakout',
      'PriceAction',
      'SwingTrading',
      'OptionsTrading',
      'RiskReward',
      'Nifty50',
      'Crypto',
      'Scalping',
    ],
  });

  final String query;
  final List<CommunityAuthor> traders;
  final ValueChanged<CommunityAuthor> onSelectTrader;
  final ValueChanged<String> onSelectTicker;
  final ValueChanged<String>? onSelectTag;
  final List<String> popularTickers;
  final List<String> popularTags;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMention = query.startsWith('@');
    final bool isCashtag = query.startsWith('\$');
    final bool isHashtag = query.startsWith('#');

    if (!isMention && !isCashtag && !isHashtag) return const SizedBox.shrink();

    final cleanQuery = query.substring(1).toLowerCase();

    // 1. @ Mentions
    if (isMention) {
      final matches = traders
          .where((t) {
            return t.handle.toLowerCase().contains(cleanQuery) ||
                t.displayName.toLowerCase().contains(cleanQuery);
          })
          .take(4)
          .toList();

      if (matches.isEmpty) return const SizedBox.shrink();

      return UiCard(
        variant: UiCardVariant.surface,
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final trader in matches)
              InkWell(
                onTap: () => onSelectTrader(trader),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.sm),
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  child: Row(
                    children: <Widget>[
                      UiAvatar(
                        name: trader.displayName,
                        imageUrl: trader.avatarUrl,
                        size: UiSize.xs,
                        verified: trader.verified,
                        verifiedColor: trader.verifiedColor(theme),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                trader.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colors.foreground,
                                ),
                              ),
                            ),
                            if (trader.verified) ...<Widget>[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.verified_rounded,
                                size: context.sz(13),
                                color: trader.verifiedColor(theme),
                              ),
                            ],
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                trader.displayHandle,
                                maxLines: 1,
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
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 2. # Hashtags
    if (isHashtag) {
      final tagMatches = popularTags
          .where((t) {
            return t.toLowerCase().contains(cleanQuery);
          })
          .take(4)
          .toList();

      if (tagMatches.isEmpty) return const SizedBox.shrink();

      return UiCard(
        variant: UiCardVariant.surface,
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final tag in tagMatches)
              InkWell(
                onTap: () => onSelectTag?.call(tag),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.sm),
                    vertical: context.sp(theme.spacing.xs),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.tag_rounded,
                        size: context.sz(14),
                        color: theme.colors.primary,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Text(
                        '#$tag',
                        style: context.uiText.bodyStrong.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 3. $ Cashtags
    final tickerMatches = popularTickers
        .where((t) {
          return t.toLowerCase().contains(cleanQuery);
        })
        .take(4)
        .toList();

    if (tickerMatches.isEmpty) return const SizedBox.shrink();

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final ticker in tickerMatches)
            InkWell(
              onTap: () => onSelectTicker(ticker),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.sm),
                  vertical: context.sp(theme.spacing.xs),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.currency_exchange_rounded,
                      size: context.sz(14),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      '\$$ticker',
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
