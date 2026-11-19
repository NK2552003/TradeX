import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// Shared editorial heading: restrained desktop chrome, a larger phone title.
class AppWorkspaceHeading extends StatelessWidget {
  const AppWorkspaceHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.actions = const [],
  });
  final String eyebrow, title, description;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: uiOverline(context, color: context.ui.colors.primary),
          ),
          const UiGap.v(6),
          Text(title, style: context.uiText.heading),
          const UiGap.v(6),
          Text(
            description,
            style: context.uiText.caption.copyWith(
              color: context.ui.colors.foregroundMuted,
            ),
          ),
        ],
      );
      if (box.maxWidth < context.sz(650)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            text,
            if (actions.isNotEmpty) ...[
              const UiGap.v(12),
              Wrap(
                spacing: context.sp(8),
                runSpacing: context.sp(8),
                children: actions,
              ),
            ],
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: text),
          const UiGap.h(16),
          ...actions,
        ],
      );
    },
  );
}

class AppMarketQuoteTile extends StatelessWidget {
  const AppMarketQuoteTile({
    super.key,
    required this.symbol,
    required this.name,
    required this.price,
    required this.change,
    required this.positive,
    this.selected = false,
    this.onTap,
    this.trailing,
    this.market,
  });
  final String symbol, name, price, change;
  final String? market;
  final bool positive, selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => AppIndexRow(
    title: symbol,
    subtitle: name,
    selected: selected,
    onTap: onTap,
    accent: selected ? context.ui.colors.primary : null,
    badges: [
      if (market != null)
        UiBadge(
          label: market!,
          size: UiSize.xs,
          variant: UiBadgeVariant.outline,
        ),
    ],
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: context.uiText.body.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              change,
              style: context.uiText.caption.copyWith(
                color: positive
                    ? context.ui.colors.bullish
                    : context.ui.colors.bearish,
              ),
            ),
          ],
        ),
        if (trailing != null) ...[const UiGap.h(4), trailing!],
      ],
    ),
  );
}

class AppNewsStoryCard extends StatelessWidget {
  const AppNewsStoryCard({
    super.key,
    required this.title,
    required this.publisher,
    required this.timestamp,
    required this.summary,
    this.symbols = const [],
    this.saved = false,
    this.demo = false,
    this.compact = false,
    this.thumbnailUrl,
    this.contentType = 'STORY',
    this.onOpen,
    this.onSave,
    this.onSymbol,
  });
  final String title, publisher, timestamp, summary, contentType;
  final String? thumbnailUrl;
  final List<String> symbols;
  final bool saved, demo, compact;
  final VoidCallback? onOpen, onSave;
  final ValueChanged<String>? onSymbol;
  @override
  Widget build(BuildContext context) => UiCard(
    onTap: onOpen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (contentType == 'VIDEO') ...[
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 16,
                      color: context.ui.colors.foregroundMuted,
                    ),
                    const UiGap.h(4),
                  ],
                  Expanded(
                    child: Text(
                      publisher.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiOverline(context),
                    ),
                  ),
                ],
              ),
            ),
            if (onSave != null)
              UiIconButton(
                icon: saved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: saved ? 'Unsave story' : 'Save story',
                size: UiSize.sm,
                onPressed: onSave,
              ),
          ],
        ),
        const UiGap.v(8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compact ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.body.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  if (summary.trim().isNotEmpty) ...[
                    const UiGap.v(6),
                    Text(
                      summary.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: context.ui.colors.foregroundMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (thumbnailUrl != null) ...[
              const UiGap.h(12),
              ClipRRect(
                borderRadius: BorderRadius.circular(context.ui.radii.sm),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: UiRemoteImage(
                    url: thumbnailUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ],
        ),
        const UiGap.v(12),
        Wrap(
          spacing: context.sp(6),
          runSpacing: context.sp(6),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final symbol in symbols.take(3))
              UiBadge(
                label: symbol,
                variant: UiBadgeVariant.soft,
                size: UiSize.xs,
                onTap: onSymbol == null ? null : () => onSymbol!(symbol),
              ),
            if (demo)
              const UiBadge(
                label: 'Demo story',
                size: UiSize.xs,
                intent: UiIntent.warning,
              ),
            Text(
              timestamp,
              style: context.uiText.caption.copyWith(
                color: context.ui.colors.foregroundSubtle,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
