import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Two research panels: comparative columns on desktop/tablet with sticky
/// companion panels, and an ordered responsive stack on mobile.
class MarketTwoPanel extends StatelessWidget {
  const MarketTwoPanel({
    super.key,
    required this.primary,
    required this.secondary,
    this.header,
    this.secondaryFirstOnMobile = false,
    this.equal = false,
  });
  final Widget? header;
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
        final stacked = Column(
          key: const ValueKey('market-stacked-panels'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?header,
            pane(secondaryFirstOnMobile ? secondary : primary),
            UiGap.v(context.ui.spacing.md),
            pane(secondaryFirstOnMobile ? primary : secondary),
          ],
        );
        return box.hasBoundedHeight
            ? SingleChildScrollView(child: stacked)
            : stacked;
      }

      Widget buildScrollable(Widget child) {
        return box.hasBoundedHeight
            ? Scrollbar(
                child: SingleChildScrollView(
                  primary: false,
                  child: pane(child),
                ),
              )
            : pane(child);
      }

      final panels = Row(
        key: const ValueKey('market-side-by-side-panels'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: equal ? 1 : (box.maxWidth >= 1100 ? 7 : 3),
            child: buildScrollable(primary),
          ),
          UiGap.h(context.ui.spacing.md),
          Expanded(
            flex: equal ? 1 : (box.maxWidth >= 1100 ? 3 : 2),
            child: buildScrollable(secondary),
          ),
        ],
      );

      if (header != null) {
        return box.hasBoundedHeight
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header!,
                  Expanded(child: panels),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header!, panels],
              );
      }

      return panels;
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
