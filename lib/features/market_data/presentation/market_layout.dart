import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Two research panels: comparative columns on desktop/tablet and an ordered
/// stack on phones. Each panel resolves library controls against its own width.
class MarketTwoPanel extends StatelessWidget {
  const MarketTwoPanel({
    super.key,
    required this.primary,
    required this.secondary,
    this.secondaryFirstOnMobile = false,
    this.equal = false,
  });
  final Widget primary, secondary;
  final bool secondaryFirstOnMobile, equal;

  static Widget pane(Widget child) => LayoutBuilder(
    builder: (context, box) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(size: Size(box.maxWidth, MediaQuery.sizeOf(context).height)),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 680) {
        return Column(
          key: const ValueKey('market-stacked-panels'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pane(secondaryFirstOnMobile ? secondary : primary),
            UiGap.v(context.ui.spacing.md),
            pane(secondaryFirstOnMobile ? primary : secondary),
          ],
        );
      }
      return Row(
        key: const ValueKey('market-side-by-side-panels'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: equal ? 1 : (box.maxWidth >= 1100 ? 7 : 3),
            child: pane(primary),
          ),
          UiGap.h(context.ui.spacing.md),
          Expanded(
            flex: equal ? 1 : (box.maxWidth >= 1100 ? 3 : 2),
            child: pane(secondary),
          ),
        ],
      );
    },
  );
}

class MarketPageHeading extends StatelessWidget {
  const MarketPageHeading({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });
  final String title, description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.lg)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.uiText.heading),
        UiGap.v(context.ui.spacing.xs),
        Text(
          description,
          style: context.uiText.caption.copyWith(
            color: context.ui.colors.foregroundMuted,
          ),
        ),
        if (action != null) ...[UiGap.v(context.ui.spacing.sm), action!],
      ],
    ),
  );
}
