import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';
import 'state_gallery.dart';

/// Number of galleries rendered by [LayoutShowcaseSection].
const int kLayoutGalleryCount = 11;

/// Batch — layout & structure primitives: grids, page scaffolding, split
/// panes, dividers, gaps, labels, breadcrumbs, pagination, steppers,
/// timelines and the app navigation shell.
class LayoutShowcaseSection extends StatelessWidget {
  const LayoutShowcaseSection({super.key, this.startIndex = 0});

  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Layout',
          subtitle:
              'Structural primitives: grids, page scaffolding, split panes, '
              'separators, labels, breadcrumbs, pagination, steppers, '
              'timelines and the adaptive navigation shell.',
        ),
        SizedBox(height: gap),
        _CardGridGallery(index: startIndex),
        SizedBox(height: gap),
        _PageGallery(index: startIndex + 1),
        SizedBox(height: gap),
        _SplitPaneGallery(index: startIndex + 2),
        SizedBox(height: gap),
        _DividerGallery(index: startIndex + 3),
        SizedBox(height: gap),
        _GapGallery(index: startIndex + 4),
        SizedBox(height: gap),
        _LabelGallery(index: startIndex + 5),
        SizedBox(height: gap),
        _BreadcrumbsGallery(index: startIndex + 6),
        SizedBox(height: gap),
        _PaginationGallery(index: startIndex + 7),
        SizedBox(height: gap),
        _StepperGallery(index: startIndex + 8),
        SizedBox(height: gap),
        _TimelineGallery(index: startIndex + 9),
        SizedBox(height: gap),
        _NavShellGallery(index: startIndex + 10),
      ],
    );
  }
}

/// Forces a subtree to lay out as if the viewport had [width]x[height],
/// used to preview mobile/desktop breakpoints side by side in a gallery.
Widget _forcedViewport(
  BuildContext context, {
  required double width,
  required double height,
  required Widget child,
}) {
  final MediaQueryData base = MediaQuery.of(context);
  return MediaQuery(
    data: base.copyWith(size: Size(width, height)),
    child: SizedBox(
      width: width,
      height: height,
      child: child,
    ),
  );
}

Widget _tile(BuildContext context, String label) {
  final theme = context.ui;
  return Container(
    padding: EdgeInsets.all(context.sp(theme.spacing.md)),
    decoration: BoxDecoration(
      color: theme.colors.surface,
      borderRadius: context.radius(theme.radii.lg),
      border: Border.all(color: theme.colors.border, width: theme.borders.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.show_chart, color: theme.colors.primary, size: context.sz(theme.sizes.iconMd)),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Text(label, style: context.uiText.bodyStrong.copyWith(color: theme.colors.foreground)),
      ],
    ),
  );
}

class _CardGridGallery extends StatelessWidget {
  const _CardGridGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiCardGrid',
      description:
          'Responsive column count (mobile/tablet/desktop/large) and '
          'configurable card aspect ratio.',
      tags: const <String>['layout', 'responsive', 'grid'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'mobile · 1 column',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 360,
            height: 320,
            child: UiCardGrid(
              mobileColumns: 1,
              tabletColumns: 2,
              desktopColumns: 3,
              largeColumns: 4,
              children: <Widget>[for (int i = 0; i < 3; i++) _tile(ctx, 'Card $i')],
            ),
          ),
        ),
        UiStateCase(
          'desktop · 3 columns',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 1200,
            height: 220,
            child: UiCardGrid(
              mobileColumns: 1,
              tabletColumns: 2,
              desktopColumns: 3,
              largeColumns: 4,
              children: <Widget>[for (int i = 0; i < 6; i++) _tile(ctx, 'Card $i')],
            ),
          ),
        ),
        UiStateCase(
          'large desktop · 4 columns',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 1600,
            height: 200,
            child: UiCardGrid(
              largeColumns: 4,
              childAspectRatio: 2.0,
              children: <Widget>[for (int i = 0; i < 8; i++) _tile(ctx, 'Card $i')],
            ),
          ),
        ),
      ],
    );
  }
}

class _PageGallery extends StatelessWidget {
  const _PageGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiPage',
      description:
          'Max-width scaffold with responsive padding, optional sticky '
          'header, scrollable or fixed body.',
      tags: const <String>['layout', 'scaffold', 'responsive'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'with header + scrollable',
          fill: true,
          builder: (BuildContext ctx) => SizedBox(
            height: 320,
            child: UiPage(
              header: UiHeader(
                title: 'Journal',
                subtitle: 'June 2026',
                actions: <Widget>[
                  UiButton(label: 'New entry', size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
                ],
              ),
              child: Column(children: <Widget>[for (int i = 0; i < 4; i++) _tile(ctx, 'Row $i')]),
            ),
          ),
        ),
        UiStateCase(
          'no header · fixed width',
          fill: true,
          builder: (BuildContext ctx) => SizedBox(
            height: 220,
            child: UiPage(
              maxWidth: 480,
              scrollable: false,
              child: _tile(ctx, 'Constrained content'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplitPaneGallery extends StatelessWidget {
  const _SplitPaneGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiSplitPane',
      description:
          'Resizable two-pane layout: single pane on phones (primary or '
          'detail), draggable divider from tablet up.',
      tags: const <String>['layout', 'responsive', 'desktop'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'mobile · primary only',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 360,
            height: 220,
            child: UiSplitPane(
              primary: _tile(ctx, 'List'),
              detail: _tile(ctx, 'Detail'),
              detailVisible: false,
            ),
          ),
        ),
        UiStateCase(
          'mobile · detail visible',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 360,
            height: 220,
            child: UiSplitPane(
              primary: _tile(ctx, 'List'),
              detail: _tile(ctx, 'Detail'),
              detailVisible: true,
            ),
          ),
        ),
        UiStateCase(
          'desktop · split + resizable',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 900,
            height: 220,
            child: UiSplitPane(
              primary: _tile(ctx, 'List'),
              detail: _tile(ctx, 'Detail'),
              initialRatio: 0.3,
              resizable: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DividerGallery extends StatelessWidget {
  const _DividerGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiDivider',
      description: 'Horizontal/vertical separators with optional centered label and custom spacing.',
      tags: const <String>['layout'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        const UiStateCase.of('horizontal', UiDivider()),
        const UiStateCase.of('horizontal · labeled', UiDivider(label: 'OR')),
        UiStateCase(
          'horizontal · custom spacing',
          builder: (BuildContext ctx) => UiDivider(spacing: ctx.ui.spacing.xxl),
        ),
        UiStateCase(
          'vertical',
          builder: (BuildContext _) => const SizedBox(
            height: 48,
            child: Row(
              children: <Widget>[
                Text('Left'),
                UiDivider(vertical: true),
                Text('Right'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GapGallery extends StatelessWidget {
  const _GapGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiGap',
      description: 'Vertical/horizontal spacer driven by the spacing scale (xs → xxl).',
      tags: const <String>['layout', 'spacing'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'vertical gaps',
          builder: (BuildContext ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('xs', style: ctx.uiText.caption),
              UiGap.v(ctx.ui.spacing.xs),
              Text('lg', style: ctx.uiText.caption),
              UiGap.v(ctx.ui.spacing.lg),
              Text('xxl', style: ctx.uiText.caption),
            ],
          ),
        ),
        UiStateCase(
          'horizontal gaps',
          builder: (BuildContext ctx) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('A', style: ctx.uiText.caption),
              UiGap.h(ctx.ui.spacing.md),
              Text('B', style: ctx.uiText.caption),
              UiGap.h(ctx.ui.spacing.xxl),
              Text('C', style: ctx.uiText.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabelGallery extends StatelessWidget {
  const _LabelGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiLabel',
      description: 'Form label with optional required marker, helper text and disabled state.',
      tags: const <String>['form', 'layout'],
      minCaseWidth: 260,
      cases: const <UiStateCase>[
        UiStateCase.of('default', UiLabel(text: 'Order quantity')),
        UiStateCase.of('required', UiLabel(text: 'Limit price', required: true)),
        UiStateCase.of(
          'with helper',
          UiLabel(text: 'Take profit', helper: 'Triggered as a market order.'),
        ),
        UiStateCase.of('disabled', UiLabel(text: 'Account tier', disabled: true)),
      ],
    );
  }
}

class _BreadcrumbsGallery extends StatelessWidget {
  const _BreadcrumbsGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiBreadcrumbs',
      description: 'Desktop breadcrumb trail with optional leading icons and tap targets.',
      tags: const <String>['navigation', 'desktop'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        UiStateCase(
          'two levels',
          builder: (BuildContext _) => UiBreadcrumbs(
            crumbs: <UiCrumb>[
              UiCrumb(label: 'Journal', onTap: () {}),
              const UiCrumb(label: 'June 2026'),
            ],
          ),
        ),
        UiStateCase(
          'with icons',
          builder: (BuildContext _) => UiBreadcrumbs(
            crumbs: <UiCrumb>[
              UiCrumb(label: 'Home', icon: Icons.home_outlined, onTap: () {}),
              UiCrumb(label: 'Journal', icon: Icons.book_outlined, onTap: () {}),
              const UiCrumb(label: 'AAPL long'),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaginationGallery extends StatelessWidget {
  const _PaginationGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiPagination',
      description: 'Ellipsized page navigation with previous/next controls and total label.',
      tags: const <String>['navigation'],
      minCaseWidth: 300,
      cases: <UiStateCase>[
        UiStateCase(
          'first page',
          builder: (BuildContext _) => UiPagination(page: 0, pageCount: 12, onPageChanged: (_) {}),
        ),
        UiStateCase(
          'middle page + total',
          builder: (BuildContext _) => UiPagination(
            page: 6,
            pageCount: 12,
            totalLabel: '120 results',
            onPageChanged: (_) {},
          ),
        ),
        UiStateCase(
          'last page',
          builder: (BuildContext _) =>
              UiPagination(page: 11, pageCount: 12, onPageChanged: (_) {}),
        ),
      ],
    );
  }
}

class _StepperGallery extends StatelessWidget {
  const _StepperGallery({required this.index});

  final int index;

  static const List<UiStepperStep> _steps = <UiStepperStep>[
    UiStepperStep(title: 'Account', subtitle: 'Verify identity', icon: Icons.person_outline),
    UiStepperStep(title: 'Funding', subtitle: 'Link a bank account'),
    UiStepperStep(title: 'Preferences'),
    UiStepperStep(title: 'Review'),
  ];

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiStepper',
      description: 'Onboarding/checkout progress: horizontal on wide screens, vertical on phones.',
      tags: const <String>['navigation', 'responsive'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'horizontal',
          fill: true,
          builder: (BuildContext _) =>
              UiStepper(steps: _steps, currentIndex: 1, onStepTap: (_) {}),
        ),
        UiStateCase(
          'vertical (forced)',
          fill: true,
          builder: (BuildContext _) => UiStepper(
            steps: _steps,
            currentIndex: 2,
            forceVertical: true,
            onStepTap: (_) {},
          ),
        ),
        UiStateCase(
          'no tap handler',
          fill: true,
          builder: (BuildContext _) =>
              const UiStepper(steps: _steps, currentIndex: 0),
        ),
      ],
    );
  }
}

class _TimelineGallery extends StatelessWidget {
  const _TimelineGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiTimeline',
      description: 'Vertical activity log with per-entry intent color, timestamp and trailing slot.',
      tags: const <String>['layout', 'history'],
      minCaseWidth: 340,
      cases: <UiStateCase>[
        UiStateCase(
          'mixed intents',
          fill: true,
          builder: (BuildContext _) => UiTimeline(
            entries: <UiTimelineEntry>[
              const UiTimelineEntry(
                title: 'Position opened',
                subtitle: 'AAPL · 10 shares',
                timestamp: '09:31',
                icon: Icons.trending_up,
                intent: UiIntent.bullish,
              ),
              const UiTimelineEntry(
                title: 'Stop moved',
                subtitle: 'Trailing stop tightened',
                timestamp: '11:02',
                icon: Icons.shield_outlined,
                intent: UiIntent.warning,
              ),
              UiTimelineEntry(
                title: 'Position closed',
                subtitle: 'AAPL · +4.2%',
                timestamp: '15:58',
                icon: Icons.check_circle_outline,
                intent: UiIntent.success,
                trailing: UiBadge.delta(4.2),
              ),
            ],
            onTap: (_) {},
          ),
        ),
      ],
    );
  }
}

class _NavShellGallery extends StatelessWidget {
  const _NavShellGallery({required this.index});

  final int index;

  static final List<UiTabItem> _items = <UiTabItem>[
    const UiTabItem(label: 'Home', icon: Icons.home_outlined),
    const UiTabItem(label: 'Journal', icon: Icons.book_outlined),
    const UiTabItem(label: 'Alerts', icon: Icons.notifications_none, count: 3),
    const UiTabItem(label: 'Profile', icon: Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiNavShell',
      description:
          'App shell: bottom navigation on phones, side rail (icon-only on '
          'tablet, labelled on desktop) with an optional floating action.',
      tags: const <String>['navigation', 'responsive', 'shell'],
      minCaseWidth: 340,
      cases: <UiStateCase>[
        UiStateCase(
          'mobile · bottom nav',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 360,
            height: 260,
            child: UiNavShell(
              items: _items,
              selectedIndex: 1,
              onChanged: (_) {},
              body: _tile(ctx, 'Body'),
            ),
          ),
        ),
        UiStateCase(
          'desktop · labelled rail + FAB',
          fill: true,
          builder: (BuildContext ctx) => _forcedViewport(
            ctx,
            width: 1200,
            height: 260,
            child: UiNavShell(
              items: _items,
              selectedIndex: 2,
              onChanged: (_) {},
              body: _tile(ctx, 'Body'),
              floatingAction: UiIconButton(icon: Icons.add, variant: UiVariant.primary, onPressed: () {}),
            ),
          ),
        ),
      ],
    );
  }
}
