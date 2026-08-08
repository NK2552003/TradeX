import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';
import 'state_gallery.dart';

/// Batch 4 — selection & navigation. Select, toggles, radios, accordion,
/// menus and tab navigation, each across its full state matrix.
class SelectionShowcaseSection extends StatelessWidget {
  const SelectionShowcaseSection({super.key, this.startIndex = 11});

  final int startIndex;

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Selection',
          subtitle:
              'Pickers and choice controls: variants, multi-select, search, '
              'validation and disabled states.',
        ),
        SizedBox(height: gap),
        _SelectGallery(index: startIndex),
        SizedBox(height: gap),
        _ToggleGallery(index: startIndex + 1),
        SizedBox(height: gap),
        _ToggleGroupGallery(index: startIndex + 2),
        SizedBox(height: gap),
        _RadioGroupGallery(index: startIndex + 3),
        SizedBox(height: gap),
        _RadioCardGallery(index: startIndex + 4),
        SizedBox(height: gap),
        const UiShowcaseSection(
          title: 'Navigation & disclosure',
          subtitle:
              'Accordions, menus, tabs and app navigation across variants, '
              'badges and adaptive layouts.',
        ),
        SizedBox(height: gap),
        _AccordionGallery(index: startIndex + 5),
        SizedBox(height: gap),
        _MenuGallery(index: startIndex + 6),
        SizedBox(height: gap),
        _TabsGallery(index: startIndex + 7),
        SizedBox(height: gap),
        _NavigationGallery(index: startIndex + 8),
      ],
    );
  }
}

const List<UiOption<String>> _markets = <UiOption<String>>[
  UiOption<String>(
    value: 'aapl',
    label: 'Apple',
    description: 'NASDAQ · Technology',
    trailingLabel: '227.10',
    icon: Icons.phone_iphone,
  ),
  UiOption<String>(
    value: 'msft',
    label: 'Microsoft',
    description: 'NASDAQ · Software',
    trailingLabel: '418.60',
    icon: Icons.window,
  ),
  UiOption<String>(
    value: 'btc',
    label: 'Bitcoin',
    description: 'Crypto · Spot',
    trailingLabel: '64,120',
    icon: Icons.currency_bitcoin,
    badge: '24/7',
  ),
  UiOption<String>(
    value: 'tsla',
    label: 'Tesla',
    description: 'Halted',
    icon: Icons.electric_car,
    enabled: false,
  ),
];

class _SelectGallery extends StatelessWidget {
  const _SelectGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiSelect',
      description:
          'Chrome variants, sizes, single and multi-select with chips, '
          'searchable overlay, validation, loading and disabled states.',
      tags: const <String>['form', 'overlay', 'validation'],
      minCaseWidth: 280,
      codeSnippet:
          "UiSelect<String>(\n  options: markets,\n  value: symbol,\n"
          "  searchable: true,\n  label: 'Instrument',\n  onChanged: setSymbol,\n)",
      cases: <UiStateCase>[
        for (final UiInputVariant v in UiInputVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            builder: (BuildContext _) => UiSelect<String>(
              variant: v,
              density: density,
              options: _markets,
              value: 'aapl',
              hintText: 'Pick instrument',
              onChanged: (_) {},
            ),
          ),
        for (final UiSize s in UiSize.values)
          UiStateCase(
            'size · ${s.name}',
            builder: (BuildContext _) => UiSelect<String>(
              size: s,
              density: density,
              options: _markets,
              value: 'msft',
              onChanged: (_) {},
            ),
          ),
        UiStateCase(
          'with label + helper',
          builder: (BuildContext _) => UiSelect<String>(
            density: density,
            label: 'Instrument',
            helperText: 'Search by ticker or name',
            options: _markets,
            value: 'btc',
            searchable: true,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'multiple + chips',
          builder: (BuildContext _) => UiSelect<String>(
            density: density,
            multiple: true,
            label: 'Watchlist',
            options: _markets,
            values: const <String>['aapl', 'msft', 'btc'],
            maxVisibleChips: 2,
            onValuesChanged: (_) {},
          ),
        ),
        UiStateCase(
          'invalid',
          builder: (BuildContext _) => UiSelect<String>(
            density: density,
            label: 'Instrument',
            errorText: 'Select an instrument to continue',
            options: _markets,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'loading',
          builder: (BuildContext _) => UiSelect<String>(
            density: density,
            loading: true,
            hintText: 'Loading markets…',
            options: const <UiOption<String>>[],
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => UiSelect<String>(
            density: density,
            enabled: false,
            options: _markets,
            value: 'aapl',
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

class _ToggleGallery extends StatelessWidget {
  const _ToggleGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiToggle',
      description:
          'Standalone on/off chip: variants, intents, sizes, counts, '
          'icon-only, loading and disabled.',
      tags: const <String>['action', 'filter'],
      minCaseWidth: 200,
      codeSnippet:
          "UiToggle(\n  label: 'Only alerts',\n  selected: onlyAlerts,\n"
          "  count: 4,\n  onChanged: setOnlyAlerts,\n)",
      cases: <UiStateCase>[
        for (final UiToggleVariant v in UiToggleVariant.values)
          UiStateCase(
            'variant · ${v.name} (on)',
            builder: (BuildContext _) => UiToggle(
              variant: v,
              density: density,
              label: 'Alerts',
              icon: Icons.notifications_active,
              selected: true,
              onChanged: (_) {},
            ),
          ),
        for (final UiToggleVariant v in UiToggleVariant.values)
          UiStateCase(
            'variant · ${v.name} (off)',
            builder: (BuildContext _) => UiToggle(
              variant: v,
              density: density,
              label: 'Alerts',
              icon: Icons.notifications_none,
              selected: false,
              onChanged: (_) {},
            ),
          ),
        for (final UiSize s in UiSize.values)
          UiStateCase(
            'size · ${s.name}',
            builder: (BuildContext _) => UiToggle(
              size: s,
              density: density,
              label: 'Bullish',
            icon: Icons.trending_up,
              selected: true,
              activeIntent: UiIntent.bullish,
              onChanged: (_) {},
            ),
          ),
        UiStateCase(
          'with count',
          builder: (BuildContext _) => UiToggle(
            density: density,
            label: 'Open orders',
            icon: Icons.receipt_long,
            count: 12,
            selected: true,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'active label swap',
          builder: (BuildContext _) => UiToggle(
            density: density,
            label: 'Follow',
            icon: Icons.person_add_alt,
            activeLabel: 'Following',
            selected: true,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'icon only',
          builder: (BuildContext _) => UiToggle(
            density: density,
            icon: Icons.star_border,
            activeIcon: Icons.star,
            selected: true,
            activeIntent: UiIntent.warning,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'loading',
          builder: (BuildContext _) => UiToggle(
            density: density,
            label: 'Syncing',
            icon: Icons.sync,
            loading: true,
            selected: true,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => UiToggle(
            density: density,
            label: 'Locked',
            icon: Icons.lock_outline,
            selected: false,
            enabled: false,
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

class _ToggleGroupGallery extends StatelessWidget {
  const _ToggleGroupGallery({required this.index});

  final int index;

  static const List<UiToggleOption<String>> _ranges = <UiToggleOption<String>>[
    UiToggleOption<String>(value: '1d', label: '1D', icon: Icons.today),
    UiToggleOption<String>(value: '1w', label: '1W'),
    UiToggleOption<String>(value: '1m', label: '1M'),
    UiToggleOption<String>(value: '1y', label: '1Y', badge: 'new'),
  ];

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiToggleGroup',
      description:
          'Segmented, pill, joined and underline variants; single or multi '
          'select, orientation, badges and disabled options.',
      tags: const <String>['filter', 'segmented', 'responsive'],
      minCaseWidth: 260,
      codeSnippet:
          "UiToggleGroup<String>(\n  options: ranges,\n  value: range,\n"
          "  variant: UiToggleGroupVariant.segmented,\n  onChanged: setRange,\n)",
      cases: <UiStateCase>[
        for (final UiToggleGroupVariant v in UiToggleGroupVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            builder: (BuildContext _) => UiToggleGroup<String>(
              variant: v,
              density: density,
              options: _ranges,
              value: '1w',
              onChanged: (_) {},
            ),
          ),
        for (final UiSize s in UiSize.values)
          UiStateCase(
            'size · ${s.name}',
            builder: (BuildContext _) => UiToggleGroup<String>(
              size: s,
              density: density,
              options: _ranges,
              value: '1m',
              onChanged: (_) {},
            ),
          ),
        UiStateCase(
          'multiple',
          builder: (BuildContext _) => UiToggleGroup<String>(
            density: density,
            multiple: true,
            options: _ranges,
            values: const <String>['1d', '1y'],
            onValuesChanged: (_) {},
          ),
        ),
        UiStateCase(
          'vertical',
          builder: (BuildContext _) => UiToggleGroup<String>(
            density: density,
            orientation: UiOrientation.vertical,
            options: _ranges,
            value: '1d',
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => UiToggleGroup<String>(
            density: density,
            enabled: false,
            options: _ranges,
            value: '1w',
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

class _RadioGroupGallery extends StatelessWidget {
  const _RadioGroupGallery({required this.index});

  final int index;

  static const List<UiOption<String>> _types = <UiOption<String>>[
    UiOption<String>(
      value: 'market',
      label: 'Market',
      description: 'Fills immediately at best available price',
      icon: Icons.bolt,
    ),
    UiOption<String>(
      value: 'limit',
      label: 'Limit',
      description: 'Fills at your price or better',
      icon: Icons.price_check,
      trailingLabel: 'GTC',
    ),
    UiOption<String>(
      value: 'stop',
      label: 'Stop',
      description: 'Requires margin approval',
      icon: Icons.shield_outlined,
      enabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiRadioGroup',
      description:
          'Single choice with descriptions, sizes, intents, orientation, '
          'dividers, reversed layout, validation and disabled options.',
      tags: const <String>['form', 'validation'],
      minCaseWidth: 280,
      codeSnippet:
          "UiRadioGroup<String>(\n  label: 'Order type',\n  options: types,\n"
          "  value: type,\n  onChanged: setType,\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          builder: (BuildContext _) => UiRadioGroup<String>(
            density: density,
            label: 'Order type',
            options: _types,
            value: 'limit',
            onChanged: (_) {},
          ),
        ),
        for (final UiSize s in <UiSize>[UiSize.xs, UiSize.sm, UiSize.md, UiSize.lg])
          UiStateCase(
            'size · ${s.name}',
            builder: (BuildContext _) => UiRadioGroup<String>(
              size: s,
              density: density,
              options: _types,
              value: 'market',
              onChanged: (_) {},
            ),
          ),
        UiStateCase(
          'horizontal',
          builder: (BuildContext _) => UiRadioGroup<String>(
            density: density,
            orientation: UiOrientation.horizontal,
            options: _types,
            value: 'market',
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'dividers + reversed',
          builder: (BuildContext _) => UiRadioGroup<String>(
            density: density,
            dividers: true,
            reverse: true,
            options: _types,
            value: 'limit',
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'intent · bullish',
          builder: (BuildContext _) => UiRadioGroup<String>(
            density: density,
            intent: UiIntent.bullish,
            options: _types,
            value: 'market',
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'invalid',
          builder: (BuildContext _) => UiRadioGroup<String>(
            density: density,
            label: 'Order type',
            required: true,
            errorText: 'Choose an order type',
            options: _types,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => UiRadioGroup<String>(
            density: density,
            enabled: false,
            options: _types,
            value: 'limit',
          ),
        ),
      ],
    );
  }
}

class _RadioCardGallery extends StatelessWidget {
  const _RadioCardGallery({required this.index});

  final int index;

  static const List<UiOption<String>> _plans = <UiOption<String>>[
    UiOption<String>(
      value: 'cash',
      label: 'Cash',
      description: 'Settled funds only, no leverage',
      icon: Icons.savings_outlined,
      trailingLabel: '0%',
    ),
    UiOption<String>(
      value: 'margin',
      label: 'Margin',
      description: 'Up to 4x intraday buying power',
      icon: Icons.trending_up,
      trailingLabel: '6.4% APR',
      badge: 'popular',
    ),
    UiOption<String>(
      value: 'pro',
      label: 'Pro',
      description: 'Portfolio margin, requires review',
      icon: Icons.workspace_premium_outlined,
      trailingLabel: '5.1% APR',
      enabled: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiRadioCardGroup',
      description:
          'Card picker with responsive columns, badges, footers, intents, '
          'hidden radio glyph, validation and disabled cards.',
      tags: const <String>['form', 'responsive'],
      minCaseWidth: 320,
      codeSnippet:
          "UiRadioCardGroup<String>(\n  label: 'Account type',\n  options: plans,\n"
          "  value: plan,\n  onChanged: setPlan,\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'default',
          fill: true,
          builder: (BuildContext _) => UiRadioCardGroup<String>(
            density: density,
            label: 'Account type',
            helperText: 'You can change this later in settings',
            options: _plans,
            value: 'margin',
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'two columns · no radio · footer',
          fill: true,
          builder: (BuildContext ctx) => UiRadioCardGroup<String>(
            density: density,
            desktopColumns: 2,
            tabletColumns: 2,
            showRadio: false,
            intent: UiIntent.bullish,
            options: _plans,
            value: 'cash',
            onChanged: (_) {},
            footerBuilder: (BuildContext c, UiOption<String> o, bool sel) => Text(
              sel ? 'Selected' : 'Tap to select',
              style: c.uiText.caption
                  .copyWith(color: c.ui.colors.foregroundSubtle),
            ),
          ),
        ),
        UiStateCase(
          'invalid',
          fill: true,
          builder: (BuildContext _) => UiRadioCardGroup<String>(
            density: density,
            label: 'Account type',
            required: true,
            errorText: 'Pick an account type',
            options: _plans,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'disabled',
          fill: true,
          builder: (BuildContext _) => UiRadioCardGroup<String>(
            density: density,
            enabled: false,
            options: _plans,
            value: 'margin',
          ),
        ),
      ],
    );
  }
}

class _AccordionGallery extends StatelessWidget {
  const _AccordionGallery({required this.index});

  final int index;

  static List<UiAccordionItem> _items(BuildContext context) => <UiAccordionItem>[
        UiAccordionItem(
          title: 'Order details',
          subtitle: 'Type, quantity, time in force',
          leadingIcon: Icons.receipt_long,
          badge: '3',
          initiallyOpen: true,
          content: const Text(
            'Limit buy · 120 shares · GTC · routed to primary exchange.',
          ),
        ),
        const UiAccordionItem(
          title: 'Risk checks',
          subtitle: 'All passed',
          leadingIcon: Icons.verified_outlined,
          intent: UiIntent.bullish,
          content: Text('Buying power, position limits and PDT checks passed.'),
        ),
        const UiAccordionItem(
          title: 'Margin warning',
          leadingIcon: Icons.warning_amber_rounded,
          intent: UiIntent.warning,
          content: Text('This order uses 2.1x leverage on settled cash.'),
        ),
        const UiAccordionItem(
          title: 'Locked section',
          leadingIcon: Icons.lock_outline,
          enabled: false,
          content: Text('Requires elevated permissions.'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiAccordion',
      description:
          'Contained, separated and ghost variants; single or multiple open '
          'sections, leading chevron, badges, intents and disabled items.',
      tags: const <String>['disclosure', 'layout'],
      minCaseWidth: 320,
      codeSnippet:
          "UiAccordion(\n  items: items,\n  allowMultiple: true,\n"
          "  variant: UiAccordionVariant.separated,\n)",
      cases: <UiStateCase>[
        for (final UiAccordionVariant v in UiAccordionVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            fill: true,
            builder: (BuildContext ctx) => UiAccordion(
              variant: v,
              density: density,
              items: _items(ctx),
            ),
          ),
        UiStateCase(
          'multiple open + leading chevron',
          fill: true,
          builder: (BuildContext ctx) => UiAccordion(
            density: density,
            allowMultiple: true,
            chevronLeading: true,
            initiallyOpen: const <int>{0, 1},
            items: _items(ctx),
          ),
        ),
        UiStateCase(
          'compact · no dividers',
          fill: true,
          builder: (BuildContext ctx) => UiAccordion(
            density: UiDensity.compact,
            dividers: false,
            items: _items(ctx),
          ),
        ),
        UiStateCase(
          'disabled',
          fill: true,
          builder: (BuildContext ctx) => UiAccordion(
            density: density,
            enabled: false,
            items: _items(ctx),
          ),
        ),
      ],
    );
  }
}

class _MenuGallery extends StatelessWidget {
  const _MenuGallery({required this.index});

  final int index;

  static const List<UiMenuItem> _items = <UiMenuItem>[
    UiMenuItem.section('Order'),
    UiMenuItem(label: 'Buy', icon: Icons.add, shortcut: 'B'),
    UiMenuItem(label: 'Sell', icon: Icons.remove, shortcut: 'S'),
    UiMenuItem(
      label: 'Advanced',
      icon: Icons.tune,
      children: <UiMenuItem>[
        UiMenuItem(label: 'Bracket order'),
        UiMenuItem(label: 'Trailing stop'),
      ],
    ),
    UiMenuItem.divider(),
    UiMenuItem.section('View'),
    UiMenuItem(
      label: 'Candles',
      icon: Icons.candlestick_chart,
      selected: true,
    ),
    UiMenuItem(
      label: 'Depth of market',
      icon: Icons.stacked_bar_chart,
      description: 'Pro plan only',
      enabled: false,
    ),
    UiMenuItem.divider(),
    UiMenuItem(
      label: 'Close position',
      icon: Icons.close,
      intent: UiIntent.bearish,
      shortcut: '⌘W',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiDropdownMenu',
      description:
          'Anchored menu with sections, dividers, shortcuts, descriptions, '
          'selection checkmarks, nested groups, intents and header/footer '
          'slots. Tap a trigger to open.',
      tags: const <String>['overlay', 'menu', 'keyboard'],
      minCaseWidth: 240,
      codeSnippet:
          "UiDropdownMenu(\n  items: items,\n  child: UiButton(label: 'Actions'),\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'button trigger',
          builder: (BuildContext _) => UiDropdownMenu(
            items: _items,
            child: UiButton(
              label: 'Actions',
              trailingIcon: Icons.keyboard_arrow_down,
              onPressed: () {},
            ),
          ),
        ),
        UiStateCase(
          'icon trigger · right aligned',
          builder: (BuildContext _) => UiDropdownMenu(
            items: _items,
            alignRight: true,
            child: UiIconButton(icon: Icons.more_horiz, onPressed: () {}),
          ),
        ),
        UiStateCase(
          'with header + footer',
          builder: (BuildContext ctx) => UiDropdownMenu(
            items: _items,
            width: 280,
            header: Text('AAPL · 120 shares', style: ctx.uiText.label),
            footer: Text(
              'Shortcuts available',
              style: ctx.uiText.caption
                  .copyWith(color: ctx.ui.colors.foregroundSubtle),
            ),
            child: UiButton(label: 'Position', onPressed: () {}),
          ),
        ),
        UiStateCase(
          'compact density',
          builder: (BuildContext _) => UiDropdownMenu(
            items: _items,
            density: UiDensity.compact,
            size: UiSize.sm,
            child: UiButton(
              label: 'Compact',
              size: UiSize.sm,
              onPressed: () {},
            ),
          ),
        ),
        UiStateCase(
          'disabled trigger',
          builder: (BuildContext _) => UiDropdownMenu(
            items: _items,
            enabled: false,
            child: UiButton(label: 'Unavailable', onPressed: () {}),
          ),
        ),
      ],
    );
  }
}

class _TabsGallery extends StatelessWidget {
  const _TabsGallery({required this.index});

  final int index;

  static const List<UiTabItem> _tabs = <UiTabItem>[
    UiTabItem(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      content: Text('Key metrics, chart and news for the selected symbol.'),
    ),
    UiTabItem(
      label: 'Positions',
      icon: Icons.pie_chart_outline,
      count: 8,
      content: Text('Open positions with unrealised P&L.'),
    ),
    UiTabItem(
      label: 'Orders',
      icon: Icons.list_alt,
      badge: 'new',
      content: Text('Working, filled and cancelled orders.'),
    ),
    UiTabItem(
      label: 'Reports',
      icon: Icons.description_outlined,
      enabled: false,
      content: Text('Statements and tax documents.'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiTabs',
      description:
          'Underline, pill, segmented and ghost variants; sizes, stretch, '
          'scrollable, counts, badges, trailing actions and panels.',
      tags: const <String>['navigation', 'responsive'],
      minCaseWidth: 320,
      codeSnippet:
          "UiTabs(\n  items: tabs,\n  variant: UiTabsVariant.segmented,\n"
          "  onChanged: setTab,\n)",
      cases: <UiStateCase>[
        for (final UiTabsVariant v in UiTabsVariant.values)
          UiStateCase(
            'variant · ${v.name}',
            fill: true,
            builder: (BuildContext _) => UiTabs(
              variant: v,
              density: density,
              items: _tabs,
              showPanel: false,
            ),
          ),
        for (final UiSize s in <UiSize>[UiSize.sm, UiSize.md, UiSize.lg])
          UiStateCase(
            'size · ${s.name}',
            fill: true,
            builder: (BuildContext _) => UiTabs(
              size: s,
              density: density,
              items: _tabs,
              showPanel: false,
            ),
          ),
        UiStateCase(
          'stretch + trailing action',
          fill: true,
          builder: (BuildContext _) => UiTabs(
            density: density,
            variant: UiTabsVariant.segmented,
            stretch: true,
            items: _tabs,
            showPanel: false,
            trailing: UiIconButton(icon: Icons.tune, onPressed: () {}),
          ),
        ),
        UiStateCase(
          'with panel',
          fill: true,
          builder: (BuildContext _) => UiTabs(
            density: density,
            items: _tabs,
            initialIndex: 1,
          ),
        ),
        UiStateCase(
          'disabled',
          fill: true,
          builder: (BuildContext _) => UiTabs(
            density: density,
            enabled: false,
            items: _tabs,
            showPanel: false,
          ),
        ),
      ],
    );
  }
}

class _NavigationGallery extends StatelessWidget {
  const _NavigationGallery({required this.index});

  final int index;

  static const List<UiNavItem> _items = <UiNavItem>[
    UiNavItem(
      label: 'Markets',
      icon: Icons.show_chart,
      activeIcon: Icons.candlestick_chart,
    ),
    UiNavItem(label: 'Portfolio', icon: Icons.pie_chart_outline, count: 3),
    UiNavItem(label: 'Alerts', icon: Icons.notifications_none, dot: true),
    UiNavItem(label: 'Inbox', icon: Icons.mail_outline, count: 128),
    UiNavItem(label: 'Locked', icon: Icons.lock_outline, enabled: false),
  ];

  @override
  Widget build(BuildContext context) {
    final UiDensity density = UiShowcaseScope.configOf(context).density;
    return UiStateGallery(
      index: index,
      name: 'UiTabNavigation',
      description:
          'App navigation that adapts between bottom bar and side rail, with '
          'badges, dots, floating style, extended rail and header/footer slots.',
      tags: const <String>['navigation', 'responsive', 'adaptive'],
      minCaseWidth: 320,
      codeSnippet:
          "UiTabNavigation(\n  items: navItems,\n  index: tab,\n"
          "  style: UiNavStyle.adaptive,\n  onChanged: setTab,\n)",
      cases: <UiStateCase>[
        UiStateCase(
          'bottom bar',
          fill: true,
          builder: (BuildContext _) => UiTabNavigation(
            items: _items,
            index: 0,
            density: density,
            style: UiNavStyle.bar,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'bottom bar · floating · no labels',
          fill: true,
          builder: (BuildContext _) => UiTabNavigation(
            items: _items,
            index: 2,
            density: density,
            style: UiNavStyle.bar,
            floating: true,
            showLabels: false,
            onChanged: (_) {},
          ),
        ),
        UiStateCase(
          'rail',
          builder: (BuildContext _) => SizedBox(
            height: 320,
            child: UiTabNavigation(
              items: _items,
              index: 1,
              density: density,
              style: UiNavStyle.rail,
              onChanged: (_) {},
            ),
          ),
        ),
        UiStateCase(
          'rail · extended + slots',
          builder: (BuildContext ctx) => SizedBox(
            height: 320,
            child: UiTabNavigation(
              items: _items,
              index: 3,
              density: density,
              style: UiNavStyle.rail,
              extendedRail: true,
              header: Text('TraderHub', style: ctx.uiText.label),
              footer: UiIconButton(icon: Icons.settings, onPressed: () {}),
              onChanged: (_) {},
            ),
          ),
        ),
        UiStateCase(
          'disabled',
          fill: true,
          builder: (BuildContext _) => UiTabNavigation(
            items: _items,
            index: 0,
            density: density,
            style: UiNavStyle.bar,
            enabled: false,
          ),
        ),
      ],
    );
  }
}
