import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';
import 'input_showcase.dart';
import 'selection_showcase.dart';
import 'state_gallery.dart';

/// Numbered showcase of the kit. Every entry renders one component with a
/// full matrix of its states (variants x intents x sizes x interaction and
/// data states) so nothing has to be discovered by reading source.
///
/// Batch 1 covers the reworked foundation: actions, feedback chips, surfaces
/// and the async state wrapper. Later batches append sections here.
class ComponentShowcasePage extends StatefulWidget {
  const ComponentShowcasePage({super.key});

  @override
  State<ComponentShowcasePage> createState() => _ComponentShowcasePageState();
}

class _ComponentShowcasePageState extends State<ComponentShowcasePage> {
  UiShowcaseConfig _config = const UiShowcaseConfig();

  @override
  Widget build(BuildContext context) {
    return UiApp(
      theme: _config.dark ? UiTheme.dark() : UiTheme.light(),
      builder: (BuildContext ctx) => UiShowcaseScope(
        config: _config,
        onChanged: (UiShowcaseConfig c) => setState(() => _config = c),
        child: Builder(builder: _body),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final theme = context.ui;
    final double gap = context.sp(theme.spacing.xl);

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext ctx, BoxConstraints c) {
            final double maxWidth = c.maxWidth > 1280 ? 1280 : c.maxWidth;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: ctx.sp(
                  ctx.uiRes.isMobile ? theme.spacing.lg : theme.spacing.xxl,
                ),
                vertical: ctx.sp(theme.spacing.xl),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const _ShowcaseHeader(),
                      SizedBox(height: gap),
                      const UiShowcaseControlBar(),
                      SizedBox(height: gap),
                      const UiShowcaseSection(
                        title: 'Actions',
                        subtitle:
                            'Trigger components: every variant, intent, size, '
                            'density and interaction state.',
                      ),
                      _gap(ctx),
                      const _ButtonGallery(index: 1),
                      _gap(ctx),
                      const UiShowcaseSection(
                        title: 'Feedback & status',
                        subtitle:
                            'Chips, deltas, counters and live indicators.',
                      ),
                      _gap(ctx),
                      const _BadgeGallery(index: 2),
                      _gap(ctx),
                      const UiShowcaseSection(
                        title: 'Surfaces',
                        subtitle:
                            'The card primitive behind every panel, tile and '
                            'block in the app.',
                      ),
                      _gap(ctx),
                      const _CardGallery(index: 3),
                      _gap(ctx),
                      const UiShowcaseSection(
                        title: 'Data states',
                        subtitle:
                            'Loading, empty, error and content — one wrapper '
                            'reused by every data-backed screen.',
                      ),
                      _gap(ctx),
                      const _AsyncGallery(index: 4),
                      _gap(ctx),
                      const InputShowcaseSection(startIndex: 5),
                      SizedBox(height: gap),
                      const SelectionShowcaseSection(startIndex: 11),
                      SizedBox(height: gap * 2),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget _gap(BuildContext ctx) =>
      SizedBox(height: ctx.sp(ctx.ui.spacing.lg));
}

class _ShowcaseHeader extends StatelessWidget {
  const _ShowcaseHeader();

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UiBadge.status('Design system v2', intent: UiIntent.primary),
        SizedBox(height: context.sp(theme.spacing.sm)),
        Text(
          'TraderHub UI Kit',
          style: context.uiText.display
              .copyWith(color: theme.colors.foreground),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          'Every component, every state, in one place. Nothing here is '
          'hardcoded: each preview is driven by the same tokens, sizes, '
          'intents and density controls your screens use.',
          style: context.uiText.body
              .copyWith(color: theme.colors.foregroundMuted),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- actions

class _ButtonGallery extends StatelessWidget {
  const _ButtonGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    void noop() {}

    return UiStateGallery(
      index: index,
      name: 'UiButton',
      description:
          'Variants, intents, sizes, icon slots, loading, badge counters, '
          'split actions and disabled state.',
      tags: const <String>['action', 'responsive', 'keyboard'],
      minCaseWidth: 260,
      codeSnippet:
          "UiButton(\n  label: 'Place order',\n  variant: UiVariant.primary,\n"
          "  intent: UiIntent.bullish,\n  size: UiSize.md,\n  leadingIcon: Icons.bolt,\n"
          "  badgeCount: 3,\n  onPressed: submit,\n)",
      cases: <UiStateCase>[
        for (final UiVariant v in UiVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            builder: (BuildContext _) => UiButton(
              label: 'Place order',
              variant: v,
              density: density,
              expandOnMobile: false,
              onPressed: noop,
            ),
          ),
        for (final UiIntent i in UiIntent.values)
          UiStateCase(
            'intent · ${i.name}',
            builder: (BuildContext _) => UiButton(
              label: i.name,
              intent: i,
              density: density,
              expandOnMobile: false,
              onPressed: noop,
            ),
          ),
        UiStateCase(
          'sizes',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            runSpacing: ctx.sp(ctx.ui.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final UiSize s in UiSize.values)
                UiButton(
                  label: s.name,
                  size: s,
                  density: density,
                  expandOnMobile: false,
                  onPressed: noop,
                ),
            ],
          ),
          span: 2,
        ),
        UiStateCase(
          'with icons',
          builder: (BuildContext _) => UiButton(
            label: 'Export report',
            leadingIcon: Icons.download,
            trailingIcon: Icons.arrow_forward,
            variant: UiVariant.outline,
            density: density,
            expandOnMobile: false,
            onPressed: noop,
          ),
        ),
        UiStateCase(
          'icon only',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            children: <Widget>[
              UiButton.icon(icon: Icons.star, label: 'Watch', onPressed: noop),
              UiButton.icon(
                icon: Icons.notifications,
                label: 'Alerts',
                variant: UiVariant.soft,
                onPressed: noop,
              ),
              UiButton.icon(
                icon: Icons.more_horiz,
                label: 'More',
                variant: UiVariant.outline,
                onPressed: noop,
              ),
            ],
          ),
        ),
        UiStateCase(
          'loading',
          note: 'Label swaps to loadingLabel, taps are ignored.',
          builder: (BuildContext _) => UiButton(
            label: 'Submitting',
            loading: true,
            loadingLabel: 'Submitting…',
            density: density,
            expandOnMobile: false,
            onPressed: noop,
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => const UiButton(
            label: 'Unavailable',
            expandOnMobile: false,
          ),
        ),
        UiStateCase(
          'selected',
          builder: (BuildContext _) => UiButton(
            label: 'Chart view',
            selected: true,
            variant: UiVariant.outline,
            leadingIcon: Icons.candlestick_chart,
            expandOnMobile: false,
            onPressed: noop,
          ),
        ),
        UiStateCase(
          'badge counter',
          builder: (BuildContext _) => UiButton(
            label: 'Inbox',
            leadingIcon: Icons.mail_outline,
            badgeCount: 12,
            variant: UiVariant.soft,
            expandOnMobile: false,
            onPressed: noop,
          ),
        ),
        UiStateCase(
          'split action',
          builder: (BuildContext _) => UiButton(
            label: 'Buy AAPL',
            intent: UiIntent.bullish,
            splitAction: noop,
            expandOnMobile: false,
            onPressed: noop,
          ),
        ),
        UiStateCase(
          'rounded + tooltip',
          builder: (BuildContext _) => UiButton(
            label: 'Boost',
            rounded: true,
            leadingIcon: Icons.rocket_launch,
            tooltip: 'Promote this idea',
            variant: UiVariant.soft,
            intent: UiIntent.warning,
            expandOnMobile: false,
            onPressed: noop,
          ),
        ),
        UiStateCase(
          'full width',
          fill: true,
          builder: (BuildContext _) => UiButton(
            label: 'Continue to checkout',
            expand: true,
            trailingIcon: Icons.arrow_forward,
            onPressed: noop,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- feedback

class _BadgeGallery extends StatelessWidget {
  const _BadgeGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    void noop() {}
    return UiStateGallery(
      index: index,
      name: 'UiBadge',
      description:
          'Shape variants, intents, sizes, market deltas, counters, live '
          'status dots and removable filter chips.',
      tags: const <String>['status', 'chip', 'delta'],
      minCaseWidth: 220,
      codeSnippet:
          "UiBadge.delta(2.43)\nUiBadge.count(12)\n"
          "UiBadge.status('Live', intent: UiIntent.bullish)",
      cases: <UiStateCase>[
        for (final UiBadgeVariant v in UiBadgeVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            builder: (BuildContext _) =>
                UiBadge(label: 'Momentum', variant: v, intent: UiIntent.primary),
          ),
        UiStateCase(
          'intents',
          span: 2,
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            runSpacing: ctx.sp(ctx.ui.spacing.xs),
            children: <Widget>[
              for (final UiIntent i in UiIntent.values)
                UiBadge(label: i.name, intent: i),
            ],
          ),
        ),
        UiStateCase(
          'sizes',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            runSpacing: ctx.sp(ctx.ui.spacing.xs),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final UiSize s in UiSize.values)
                UiBadge(label: s.name, size: s, intent: UiIntent.info),
            ],
          ),
        ),
        UiStateCase(
          'deltas',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            children: <Widget>[
              UiBadge.delta(2.43),
              UiBadge.delta(-1.1),
              UiBadge.delta(0),
            ],
          ),
        ),
        UiStateCase(
          'counters',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            children: <Widget>[
              UiBadge.count(3),
              UiBadge.count(42, intent: UiIntent.danger),
              UiBadge.count(1240),
            ],
          ),
        ),
        UiStateCase(
          'live status',
          builder: (BuildContext ctx) => Wrap(
            spacing: ctx.sp(ctx.ui.spacing.xs),
            children: <Widget>[
              UiBadge.status('Market open'),
              UiBadge.status('Delayed', intent: UiIntent.warning),
              UiBadge.status('Closed', intent: UiIntent.neutral, pulse: false),
            ],
          ),
        ),
        UiStateCase(
          'with icon',
          builder: (BuildContext _) => const UiBadge(
            label: 'Verified',
            icon: Icons.verified,
            intent: UiIntent.info,
          ),
        ),
        UiStateCase(
          'uppercase',
          builder: (BuildContext _) => const UiBadge(
            label: 'Pre-market',
            uppercase: true,
            intent: UiIntent.warning,
          ),
        ),
        UiStateCase(
          'removable filter',
          builder: (BuildContext _) => UiBadge(
            label: 'Sector: Tech',
            variant: UiBadgeVariant.outline,
            onRemove: noop,
          ),
        ),
        UiStateCase(
          'tappable',
          builder: (BuildContext _) => UiBadge(
            label: 'Add filter',
            icon: Icons.add,
            variant: UiBadgeVariant.ghost,
            onTap: noop,
          ),
        ),
        UiStateCase(
          'truncating',
          builder: (BuildContext _) => const UiBadge(
            label: 'A very long tag label that must ellipsize gracefully',
            maxWidth: 180,
            tooltip: 'Full label shown on hover',
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- surfaces

class _CardGallery extends StatelessWidget {
  const _CardGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    void noop() {}
    Widget body(BuildContext ctx, [String? text]) => Text(
          text ??
              'Slots for media, header, content, actions and footer. Padding '
              'and gaps follow the active density.',
          style: ctx.uiText.body.copyWith(color: ctx.uiColors.foregroundMuted),
        );

    return UiStateGallery(
      index: index,
      name: 'UiCard',
      description:
          'Surface variants, intent accents, selection, hover lift, '
          'collapsible headers, loading skeleton and slot composition.',
      tags: const <String>['surface', 'slots', 'collapsible'],
      minCaseWidth: 300,
      padded: false,
      background: Colors.transparent,
      codeSnippet:
          "UiCard(\n  variant: UiCardVariant.gradient,\n  intent: UiIntent.primary,\n"
          "  title: 'Portfolio',\n  subtitle: 'Updated 2m ago',\n  actions: [...],\n"
          "  child: content,\n)",
      cases: <UiStateCase>[
        for (final UiCardVariant v in UiCardVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            builder: (BuildContext ctx) => UiCard(
              variant: v,
              title: 'Portfolio value',
              subtitle: '\$182,430.22',
              child: body(ctx, 'Surface treatment: ${v.name}.'),
            ),
          ),
        UiStateCase(
          'intent accent',
          builder: (BuildContext ctx) => UiCard(
            intent: UiIntent.bullish,
            title: 'Position opened',
            subtitle: 'AAPL · 25 shares',
            child: body(ctx, 'Accent stripe and border follow the intent.'),
          ),
        ),
        UiStateCase(
          'selected',
          builder: (BuildContext ctx) => UiCard(
            selected: true,
            title: 'Selected card',
            onTap: noop,
            child: body(ctx, 'Selection thickens the border with the tint.'),
          ),
        ),
        UiStateCase(
          'interactive (hover lift)',
          builder: (BuildContext ctx) => UiCard(
            variant: UiCardVariant.elevated,
            title: 'Tappable',
            onTap: noop,
            child: body(ctx, 'Hover / focus lifts the surface.'),
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext ctx) => UiCard(
            enabled: false,
            title: 'Locked',
            subtitle: 'Upgrade to unlock',
            onTap: noop,
            child: body(ctx, 'Dimmed and non-interactive.'),
          ),
        ),
        UiStateCase(
          'loading',
          builder: (BuildContext ctx) => UiCard(
            loading: true,
            title: 'Fetching',
            child: body(ctx),
          ),
        ),
        UiStateCase(
          'collapsible',
          builder: (BuildContext ctx) => UiCard(
            collapsible: true,
            initiallyExpanded: false,
            title: 'Advanced settings',
            subtitle: 'Tap the chevron to expand',
            child: body(ctx),
          ),
        ),
        UiStateCase(
          'header slots + actions',
          span: 2,
          builder: (BuildContext ctx) => UiCard(
            variant: UiCardVariant.gradient,
            intent: UiIntent.primary,
            leading: const UiBadge(
              label: 'AAPL',
              variant: UiBadgeVariant.solid,
              intent: UiIntent.primary,
            ),
            title: 'Apple Inc.',
            subtitle: 'NASDAQ · Technology',
            trailing: UiBadge.delta(1.82),
            headerDivider: true,
            actions: <Widget>[
              UiButton(
                label: 'Buy',
                intent: UiIntent.bullish,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: noop,
              ),
              UiButton(
                label: 'Sell',
                intent: UiIntent.bearish,
                variant: UiVariant.outline,
                size: UiSize.sm,
                expandOnMobile: false,
                onPressed: noop,
              ),
            ],
            footer: Text(
              'Last trade 16:00 EST',
              style: ctx.uiText.caption
                  .copyWith(color: ctx.uiColors.foregroundSubtle),
            ),
            child: body(ctx, 'Full slot composition in one surface.'),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ data states

class _AsyncGallery extends StatelessWidget {
  const _AsyncGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiAsyncView / UiAsyncViewStateCard',
      description:
          'One wrapper for loading, empty, error and content. The card below '
          'is interactive — switch states to preview each branch.',
      tags: const <String>['data', 'states'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'interactive state switcher',
          fill: true,
          builder: (BuildContext ctx) => UiAsyncViewStateCard(
            title: 'Watchlist',
            subtitle: 'Preview each data state of the same view.',
            contentBuilder: (BuildContext c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final List<Object> row in <List<Object>>[
                  <Object>['AAPL', 1.82],
                  <Object>['TSLA', -2.14],
                  <Object>['NVDA', 4.05],
                ])
                  Padding(
                    padding:
                        EdgeInsets.only(bottom: c.sp(c.ui.spacing.sm)),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            row[0] as String,
                            style: c.uiText.bodyStrong
                                .copyWith(color: c.uiColors.foreground),
                          ),
                        ),
                        UiBadge.delta(row[1] as num),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Public wrapper for showcase entries 1-4 (actions, feedback chips,
/// surfaces and the async state wrapper) so the numbered page can compose
/// them alongside every other section.
class FoundationShowcaseSection extends StatelessWidget {
  const FoundationShowcaseSection({super.key, this.startIndex = 1});

  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Foundation',
          subtitle:
              'Actions, status chips, surfaces and the async state wrapper '
              'every other component builds on.',
        ),
        SizedBox(height: gap),
        _ButtonGallery(index: startIndex),
        SizedBox(height: gap),
        _BadgeGallery(index: startIndex + 1),
        SizedBox(height: gap),
        _CardGallery(index: startIndex + 2),
        SizedBox(height: gap),
        _AsyncGallery(index: startIndex + 3),
      ],
    );
  }
}

const int kFoundationGalleryCount = 4;
const int kInputGalleryCount = 6;
const int kSelectionGalleryCount = 9;
