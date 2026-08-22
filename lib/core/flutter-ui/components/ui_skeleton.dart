import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Polished, low-contrast loading placeholder with a restrained light sweep
/// and complete suite of pre-built layout skeletons.
class UiSkeleton extends StatefulWidget {
  const UiSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.circle = false,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool circle;

  /// Text skeleton (single line or multi-line paragraphs).
  static Widget text({
    Key? key,
    double? width,
    double height = 14,
    int lines = 1,
    double spacing = 8,
  }) {
    if (lines <= 1) {
      return UiSkeleton(key: key, width: width, height: height);
    }
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < lines; i++) ...<Widget>[
          if (i > 0) SizedBox(height: spacing),
          UiSkeleton(
            width: i == lines - 1 && width == null
                ? null
                : (i == lines - 1 ? width! * 0.65 : width),
            height: height,
          ),
        ],
      ],
    );
  }

  /// Heading skeleton.
  static Widget heading({
    Key? key,
    double? width = 180,
    double height = 24,
  }) {
    return UiSkeleton(key: key, width: width, height: height);
  }

  /// Circular avatar skeleton.
  static Widget avatar({Key? key, double size = 40}) {
    return UiSkeleton(key: key, width: size, height: size, circle: true);
  }

  /// Button skeleton.
  static Widget button({
    Key? key,
    double? width = 120,
    double height = 40,
    double radius = 10,
  }) {
    return UiSkeleton(
      key: key,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// Pill badge skeleton.
  static Widget badge({
    Key? key,
    double width = 64,
    double height = 22,
  }) {
    return UiSkeleton(
      key: key,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(height / 2),
    );
  }

  /// Tab bar / segmented switch skeleton.
  static Widget tabs({
    Key? key,
    int count = 3,
    double height = 38,
    double spacing = 8,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Container(
          height: context.sz(height),
          padding: EdgeInsets.all(context.sp(theme.spacing.xxs)),
          decoration: BoxDecoration(
            color: theme.colors.surfaceMuted.withValues(alpha: 0.5),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < count; i++) ...<Widget>[
                if (i > 0) SizedBox(width: spacing),
                Expanded(
                  child: UiSkeleton(
                    height: height - 8,
                    borderRadius: context.radius(theme.radii.sm),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Card container skeleton.
  static Widget card({
    Key? key,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    Widget? child,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Container(
          width: width,
          height: height != null ? context.sz(height) : null,
          padding: padding ?? EdgeInsets.all(context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: child ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      UiSkeleton(width: context.sz(120), height: 16),
                      UiSkeleton.badge(width: 50, height: 20),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  UiSkeleton.text(lines: 2, spacing: 6),
                ],
              ),
        );
      },
    );
  }

  /// Metric stat tile skeleton.
  static Widget metricCard({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Container(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  UiSkeleton(width: context.sz(80), height: 12),
                  UiSkeleton(width: context.sz(18), height: 18, circle: true),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiSkeleton(width: context.sz(130), height: 26),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Row(
                children: <Widget>[
                  UiSkeleton.badge(width: 54, height: 18),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiSkeleton(width: context.sz(60), height: 10),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Chart area skeleton.
  static Widget chart({Key? key, double height = 180}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Container(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        UiSkeleton(width: context.sz(110), height: 14),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        UiSkeleton(width: context.sz(160), height: 22),
                      ],
                    ),
                  ),
                  UiSkeleton(width: context.sz(100), height: 28),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSkeleton(
                height: height,
                borderRadius: context.radius(theme.radii.md),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Data table / row list skeleton.
  static Widget table({Key? key, int rows = 4, int columns = 3}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Column(
            children: <Widget>[
              // Header
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                child: Row(
                  children: <Widget>[
                    for (int c = 0; c < columns; c++)
                      Expanded(
                        child: UiSkeleton(
                          width: context.sz(60),
                          height: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: theme.colors.border,
                thickness: theme.borders.hairline,
              ),
              for (int r = 0; r < rows; r++) ...<Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.sm),
                  ),
                  child: Row(
                    children: <Widget>[
                      for (int c = 0; c < columns; c++)
                        Expanded(
                          child: UiSkeleton(
                            width: c == 0 ? context.sz(90) : context.sz(50),
                            height: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                if (r < rows - 1)
                  Divider(
                    height: 1,
                    color: theme.colors.border.withValues(alpha: 0.5),
                    thickness: theme.borders.hairline,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// List item row skeleton.
  static Widget listItem({
    Key? key,
    bool showLeading = true,
    bool showTrailing = true,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Container(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          decoration: BoxDecoration(
            color: theme.colors.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: theme.colors.border,
              width: theme.borders.hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              if (showLeading) ...<Widget>[
                UiSkeleton.avatar(size: 38),
                SizedBox(width: context.sp(theme.spacing.sm)),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    UiSkeleton(width: context.sz(140), height: 14),
                    SizedBox(height: context.sp(theme.spacing.xxs)),
                    UiSkeleton(width: context.sz(200), height: 11),
                  ],
                ),
              ),
              if (showTrailing) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.sm)),
                UiSkeleton.badge(width: 58, height: 22),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Complete general page skeleton with header, subtitle, tabs, metrics, and content.
  static Widget page({
    Key? key,
    String? title,
    String? subtitle,
    bool showTabs = true,
    bool showMetrics = true,
    bool showChart = true,
    int cardCount = 2,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header & Subtitle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (title != null)
                          Text(
                            title,
                            style: context.uiText.heading.copyWith(
                              color: theme.colors.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else
                          UiSkeleton.heading(width: context.sz(160)),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundMuted,
                            ),
                          )
                        else
                          UiSkeleton.text(width: context.sz(240), height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiSkeleton.button(width: context.sz(90), height: 36),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Optional Tab Bar
              if (showTabs) ...<Widget>[
                UiSkeleton.tabs(count: 3),
                SizedBox(height: context.sp(theme.spacing.md)),
              ],

              // Optional Metrics Grid
              if (showMetrics) ...<Widget>[
                if (mobile) ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: UiSkeleton.metricCard()),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(child: UiSkeleton.metricCard()),
                    ],
                  ),
                ] else ...<Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: UiSkeleton.metricCard()),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(child: UiSkeleton.metricCard()),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(child: UiSkeleton.metricCard()),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(child: UiSkeleton.metricCard()),
                    ],
                  ),
                ],
                SizedBox(height: context.sp(theme.spacing.md)),
              ],

              // Optional Chart
              if (showChart) ...<Widget>[
                UiSkeleton.chart(height: mobile ? 160 : 200),
                SizedBox(height: context.sp(theme.spacing.md)),
              ],

              // List Items
              for (int i = 0; i < cardCount; i++) ...<Widget>[
                UiSkeleton.listItem(),
                SizedBox(height: context.sp(theme.spacing.sm)),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Specialized Full Domain Skeletons
  // ---------------------------------------------------------------------------

  /// Dashboard skeleton with KPI grid, portfolio chart, and positions list.
  static Widget dashboard({Key? key}) {
    return page(
      key: key,
      title: 'Dashboard',
      subtitle: 'Real-time market analytics & active portfolio metrics',
      showTabs: false,
      showMetrics: true,
      showChart: true,
      cardCount: 2,
    );
  }

  /// Journal skeleton with filter tabs, calendar heat-strip, and trade rows.
  static Widget journal({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Trade Journal',
                          style: context.uiText.heading.copyWith(
                            color: theme.colors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Executions, trade notes, and performance stats',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiSkeleton.button(width: context.sz(96), height: 36),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Filter Tabs
              UiSkeleton.tabs(count: 4, height: 36),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Calendar Heat Strip
              UiSkeleton.card(
                height: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List<Widget>.generate(
                    7,
                    (_) => UiSkeleton(
                      width: context.sz(32),
                      height: 48,
                      borderRadius: context.radius(theme.radii.sm),
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Trade Rows
              for (int i = 0; i < 4; i++) ...<Widget>[
                UiSkeleton.listItem(),
                SizedBox(height: context.sp(theme.spacing.sm)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Strategies skeleton with playbook cards & win-rate bars.
  static Widget strategies({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Trading Strategies',
                          style: context.uiText.heading.copyWith(
                            color: theme.colors.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        Text(
                          'Backtested playbooks, Sharpe ratios, and win-rates',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiSkeleton.button(width: context.sz(110), height: 36),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Strategy KPI Cards
              Row(
                children: <Widget>[
                  Expanded(child: UiSkeleton.metricCard()),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(child: UiSkeleton.metricCard()),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Strategy Cards
              for (int i = 0; i < 3; i++) ...<Widget>[
                UiSkeleton.card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          UiSkeleton(width: context.sz(140), height: 16),
                          UiSkeleton.badge(width: 60, height: 22),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      UiSkeleton.text(lines: 2, spacing: 6),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          UiSkeleton(width: context.sz(80), height: 12),
                          UiSkeleton(width: context.sz(80), height: 12),
                          UiSkeleton(width: context.sz(80), height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Watchlists skeleton with market scanner, sparklines, and ticker list.
  static Widget watchlists({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header & Search
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Watchlists & Markets',
                      style: context.uiText.heading.copyWith(
                        color: theme.colors.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  UiSkeleton.button(width: context.sz(80), height: 36),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Sector Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    UiSkeleton.badge(width: 64, height: 28),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiSkeleton.badge(width: 80, height: 28),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiSkeleton.badge(width: 72, height: 28),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiSkeleton.badge(width: 60, height: 28),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Ticker Cards with Sparklines
              for (int i = 0; i < 4; i++) ...<Widget>[
                UiSkeleton.card(
                  child: Row(
                    children: <Widget>[
                      UiSkeleton.avatar(size: 32),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            UiSkeleton(width: context.sz(60), height: 14),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                            UiSkeleton(width: context.sz(100), height: 11),
                          ],
                        ),
                      ),
                      UiSkeleton(
                        width: context.sz(64),
                        height: 24,
                        borderRadius: context.radius(theme.radii.sm),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          UiSkeleton(width: context.sz(56), height: 14),
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          UiSkeleton.badge(width: 48, height: 18),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Portfolio skeleton with asset allocation donut and holdings matrix.
  static Widget portfolio({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header
              Text(
                'Portfolio & Risk',
                style: context.uiText.heading.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                'Asset breakdown, sector exposure, and risk matrix',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Donut Chart Card
              UiSkeleton.card(
                height: 180,
                child: Row(
                  children: <Widget>[
                    UiSkeleton(
                      width: context.sz(110),
                      height: 110,
                      circle: true,
                    ),
                    SizedBox(width: context.sp(theme.spacing.lg)),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          UiSkeleton(width: context.sz(100), height: 12),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          UiSkeleton(width: context.sz(130), height: 12),
                          SizedBox(height: context.sp(theme.spacing.xs)),
                          UiSkeleton(width: context.sz(90), height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Holdings Table
              UiSkeleton.table(rows: 4, columns: 3),
            ],
          ),
        );
      },
    );
  }

  /// Community feed skeleton.
  static Widget community({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Composer Bar
              UiSkeleton.card(
                child: Row(
                  children: <Widget>[
                    UiSkeleton.avatar(size: 36),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: UiSkeleton(
                        height: 36,
                        borderRadius: context.radius(theme.radii.md),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // Community Posts
              for (int i = 0; i < 3; i++) ...<Widget>[
                UiSkeleton.card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          UiSkeleton.avatar(size: 34),
                          SizedBox(width: context.sp(theme.spacing.sm)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              UiSkeleton(width: context.sz(110), height: 13),
                              SizedBox(height: context.sp(theme.spacing.xxs)),
                              UiSkeleton(width: context.sz(70), height: 10),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      UiSkeleton.text(lines: 3, spacing: 6),
                      SizedBox(height: context.sp(theme.spacing.sm)),
                      UiSkeleton(
                        height: 110,
                        borderRadius: context.radius(theme.radii.sm),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Messages chat skeleton.
  static Widget messages({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: <Widget>[
              UiSkeleton(
                height: 40,
                borderRadius: context.radius(theme.radii.md),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              for (int i = 0; i < 5; i++) ...<Widget>[
                UiSkeleton.listItem(showTrailing: true),
                SizedBox(height: context.sp(theme.spacing.xs)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// AI Assistant copilot skeleton.
  static Widget ai({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header
              Text(
                'AI Trading Copilot',
                style: context.uiText.heading.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                'Quantitative pattern detection & smart trade assistant',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // AI Prompt Input Box
              UiSkeleton.card(
                height: 72,
                child: Row(
                  children: <Widget>[
                    UiSkeleton(width: context.sz(20), height: 20, circle: true),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: UiSkeleton(width: context.sz(180), height: 14),
                    ),
                    UiSkeleton.button(width: context.sz(60), height: 32),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),

              // AI Insights
              for (int i = 0; i < 3; i++) ...<Widget>[
                UiSkeleton.card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          UiSkeleton(width: context.sz(130), height: 14),
                          UiSkeleton.badge(width: 70, height: 20),
                        ],
                      ),
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      UiSkeleton.text(lines: 2, spacing: 6),
                    ],
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.sm)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Notifications feed skeleton.
  static Widget notifications({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Notifications & Alerts',
                style: context.uiText.heading.copyWith(
                  color: theme.colors.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSkeleton.tabs(count: 3, height: 34),
              SizedBox(height: context.sp(theme.spacing.md)),
              for (int i = 0; i < 5; i++) ...<Widget>[
                UiSkeleton.listItem(),
                SizedBox(height: context.sp(theme.spacing.xs)),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Search screen skeleton.
  static Widget search({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + (mobile ? 108.0 : context.sp(theme.spacing.lg)),
          ),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              UiSkeleton(
                height: 44,
                borderRadius: context.radius(theme.radii.lg),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              Text(
                'Trending Searches',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    UiSkeleton.badge(width: 72, height: 28),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiSkeleton.badge(width: 84, height: 28),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiSkeleton.badge(width: 60, height: 28),
                  ],
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              for (int i = 0; i < 4; i++) ...<Widget>[
                UiSkeleton.listItem(showTrailing: true),
                SizedBox(height: context.sp(theme.spacing.xs)),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  State<UiSkeleton> createState() => _UiSkeletonState();
}

class _UiSkeletonState extends State<UiSkeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    final bool inTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (inTest) {
      _controller?.value = 0.5;
    } else {
      _controller?.repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double height = context.sz(widget.height ?? 14);
    final BorderRadius radius = widget.borderRadius ??
        context.radius(
          height >= context.sz(44) ? theme.radii.md : theme.radii.sm,
        );

    final controller = _controller;

    return SizedBox(
      width: widget.circle
          ? context.sz(widget.width ?? widget.height ?? 14)
          : widget.width,
      height: widget.circle
          ? context.sz(widget.width ?? widget.height ?? 14)
          : height,
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          Widget buildShimmer(double progress) {
            final double travel = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : context.sz(240);
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(
                  color: theme.colors.surfaceMuted.withValues(alpha: 0.82),
                ),
                Transform.translate(
                  offset: Offset(
                    ((progress * 2.4) - 1.2) * travel,
                    0,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.42,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            theme.colors.foreground.withValues(alpha: 0.055),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final Widget shimmer = controller != null
              ? AnimatedBuilder(
                  animation: controller,
                  builder: (BuildContext context, Widget? child) {
                    return buildShimmer(controller.value);
                  },
                )
              : buildShimmer(0.5);

          return widget.circle
              ? ClipOval(child: shimmer)
              : ClipRRect(borderRadius: radius, child: shimmer);
        },
      ),
    );
  }
}
