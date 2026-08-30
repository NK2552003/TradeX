import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  static Widget heading({Key? key, double? width = 180, double height = 24}) {
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
  static Widget badge({Key? key, double width = 64, double height = 22}) {
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
          child:
              child ??
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
                        child: UiSkeleton(width: context.sz(60), height: 12),
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
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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

  /// One settings section: eyebrow title, description line, then a stack of
  /// setting rows. Mirrors the real section block so the swap in is invisible.
  static Widget settingsSection({
    Key? key,
    int rows = 3,
    bool showDescription = true,
    double? titleWidth,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            UiSkeleton(width: titleWidth ?? context.sz(190), height: 15),
            if (showDescription) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              UiSkeleton(width: context.sz(280), height: 11),
            ],
            SizedBox(height: context.sp(theme.spacing.md)),
            for (int i = 0; i < rows; i++) ...<Widget>[
              if (i > 0) SizedBox(height: context.sp(theme.spacing.sm)),
              UiSkeleton.settingRow(),
            ],
          ],
        );
      },
    );
  }

  /// A single settings row card: icon, title, helper line, trailing control.
  static Widget settingRow({Key? key, bool showControl = true}) {
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
              UiSkeleton(
                width: context.sz(32),
                height: 32,
                borderRadius: context.radius(theme.radii.md),
              ),
              SizedBox(width: context.sp(theme.spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    UiSkeleton(height: 13, width: context.sz(150)),
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    const UiSkeleton(height: 10),
                  ],
                ),
              ),
              if (showControl) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.md)),
                UiSkeleton(
                  width: context.sz(40),
                  height: 22,
                  borderRadius: context.radius(theme.radii.pill),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Settings detail skeleton — what a settings sub-page shows while it loads.
  ///
  /// [showIdentity] adds the avatar + name header the profile pages open with.
  static Widget settingsDetail({
    Key? key,
    int sections = 2,
    int rowsPerSection = 3,
    bool showIdentity = false,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final double pad = context.sp(theme.spacing.lg);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, context.uiDockInset),
          physics: const NeverScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(980)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showIdentity) ...<Widget>[
                    UiSkeleton.identityCard(),
                    SizedBox(height: context.sp(theme.spacing.lg)),
                  ],
                  for (int i = 0; i < sections; i++) ...<Widget>[
                    if (i > 0) SizedBox(height: context.sp(theme.spacing.xl)),
                    UiSkeleton.settingsSection(rows: rowsPerSection),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Settings sub-page whose body is a list rather than a form — blocked
  /// accounts, desk members, past invoices.
  ///
  /// [showHeader] draws the "N items" plus action strip those pages put above
  /// the list; [showSummary] draws the wide card the billing pages lead with.
  static Widget settingsList({
    Key? key,
    int rows = 4,
    bool showHeader = true,
    bool showSummary = false,
  }) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final double pad = context.sp(theme.spacing.lg);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, context.uiDockInset),
          physics: const NeverScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(980)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showSummary) ...<Widget>[
                    UiSkeleton.card(height: 104),
                    SizedBox(height: context.sp(theme.spacing.lg)),
                  ],
                  if (showHeader) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(child: UiSkeleton(width: context.sz(140), height: 13)),
                        SizedBox(width: context.sp(theme.spacing.sm)),
                        UiSkeleton.button(width: context.sz(104), height: 28),
                      ],
                    ),
                    SizedBox(height: context.sp(theme.spacing.md)),
                  ],
                  for (int i = 0; i < rows; i++) ...<Widget>[
                    if (i > 0) SizedBox(height: context.sp(theme.spacing.sm)),
                    UiSkeleton.listItem(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Plan picker skeleton — the billing-cycle toggle above a row of plan cards,
  /// which stack on a phone the way the real comparison does.
  static Widget plans({Key? key, int count = 3}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final double pad = context.sp(theme.spacing.lg);
        final bool mobile = context.uiRes.isMobile;
        final Widget planCard = UiSkeleton.card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiSkeleton(width: context.sz(90), height: 14),
              SizedBox(height: context.sp(theme.spacing.sm)),
              UiSkeleton(width: context.sz(130), height: 26),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSkeleton.text(lines: 4, spacing: 8),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSkeleton.button(width: null, height: 34),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, context.uiDockInset),
          physics: const NeverScrollableScrollPhysics(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(1180)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.center,
                    child: UiSkeleton(
                      width: context.sz(240),
                      height: 36,
                      borderRadius: context.radius(theme.radii.pill),
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),
                  if (mobile)
                    for (int i = 0; i < count; i++) ...<Widget>[
                      if (i > 0) SizedBox(height: context.sp(theme.spacing.md)),
                      planCard,
                    ]
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (int i = 0; i < count; i++) ...<Widget>[
                          if (i > 0)
                            SizedBox(width: context.sp(theme.spacing.md)),
                          Expanded(child: planCard),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Avatar + name + actions header used by the profile settings pages.
  static Widget identityCard({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final bool mobile = context.uiRes.isMobile;
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UiSkeleton.avatar(size: theme.sizes.avatarLg),
                  SizedBox(width: context.sp(theme.spacing.md)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        UiSkeleton(height: 18, width: context.sz(170)),
                        SizedBox(height: context.sp(theme.spacing.xs)),
                        UiSkeleton(height: 11, width: context.sz(110)),
                      ],
                    ),
                  ),
                  if (!mobile) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.md)),
                    Column(
                      children: <Widget>[
                        UiSkeleton.button(width: context.sz(172), height: 32),
                        SizedBox(height: context.sp(theme.spacing.xs)),
                        UiSkeleton.button(width: context.sz(172), height: 32),
                      ],
                    ),
                  ],
                ],
              ),
              if (mobile) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.md)),
                UiSkeleton.button(width: null, height: 32),
                SizedBox(height: context.sp(theme.spacing.xs)),
                UiSkeleton.button(width: null, height: 32),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Settings overview skeleton — the grouped drill-in list on mobile.
  static Widget settings({Key? key, int groups = 3, int rowsPerGroup = 3}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final double pad = context.sp(theme.spacing.lg);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, context.uiDockInset),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiSkeleton.identityCard(),
              SizedBox(height: context.sp(theme.spacing.lg)),
              for (int g = 0; g < groups; g++) ...<Widget>[
                if (g > 0) SizedBox(height: context.sp(theme.spacing.lg)),
                UiSkeleton(width: context.sz(120), height: 11),
                SizedBox(height: context.sp(theme.spacing.sm)),
                for (int i = 0; i < rowsPerGroup; i++) ...<Widget>[
                  if (i > 0) SizedBox(height: context.sp(theme.spacing.xs)),
                  UiSkeleton.settingRow(showControl: false),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  /// Public profile / partner portal preview skeleton.
  static Widget profilePreview({Key? key}) {
    return Builder(
      key: key,
      builder: (BuildContext context) {
        final theme = context.ui;
        final double pad = context.sp(theme.spacing.lg);
        final bool mobile = context.uiRes.isMobile;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, context.uiDockInset),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              UiSkeleton.identityCard(),
              SizedBox(height: context.sp(theme.spacing.md)),
              Wrap(
                spacing: context.sp(theme.spacing.xs),
                runSpacing: context.sp(theme.spacing.xs),
                children: <Widget>[
                  UiSkeleton.badge(width: 78, height: 22),
                  UiSkeleton.badge(width: 96, height: 22),
                  UiSkeleton.badge(width: 64, height: 22),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.md)),
              if (mobile)
                Column(
                  children: <Widget>[
                    UiSkeleton.metricCard(),
                    SizedBox(height: context.sp(theme.spacing.sm)),
                    UiSkeleton.metricCard(),
                  ],
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(child: UiSkeleton.metricCard()),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(child: UiSkeleton.metricCard()),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(child: UiSkeleton.metricCard()),
                  ],
                ),
              SizedBox(height: context.sp(theme.spacing.md)),
              UiSkeleton.chart(height: mobile ? 150 : 200),
              SizedBox(height: context.sp(theme.spacing.md)),
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0) SizedBox(height: context.sp(theme.spacing.xs)),
                UiSkeleton.listItem(),
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
        final double pad = context.sp(theme.spacing.md);

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            pad,
            pad,
            pad,
            pad + context.uiDockInset,
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

class _UiSkeletonState extends State<UiSkeleton> {
  @override
  void initState() {
    super.initState();
    _UiShimmerDriver.instance.acquire();
  }

  @override
  void dispose() {
    _UiShimmerDriver.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double height = context.sz(widget.height ?? 14);
    final BorderRadius radius =
        widget.borderRadius ??
        context.radius(
          height >= context.sz(44) ? theme.radii.md : theme.radii.sm,
        );
    final double diameter = context.sz(widget.width ?? widget.height ?? 14);

    return SizedBox(
      width: widget.circle ? diameter : widget.width,
      height: widget.circle ? diameter : height,
      // The sweep is painted, not rebuilt: the painter listens to the shared
      // driver directly, so an animating page costs one repaint per frame
      // instead of one widget rebuild per placeholder box.
      child: CustomPaint(
        painter: _UiShimmerPainter(
          progress: _UiShimmerDriver.instance.progress,
          base: theme.colors.surfaceMuted.withValues(alpha: 0.82),
          highlight: theme.colors.foreground.withValues(alpha: 0.055),
          radius: widget.circle ? null : radius,
        ),
      ),
    );
  }
}

/// One ticker for every skeleton on screen.
///
/// Each [UiSkeleton] used to own an [AnimationController]; a single page
/// skeleton spins up dozens, and every one of them schedules frames and drives
/// its own rebuild. This shares a single [Ticker], reference-counted by the
/// mounted placeholders, and stops it as soon as the last one goes away.
class _UiShimmerDriver {
  _UiShimmerDriver._();

  static final _UiShimmerDriver instance = _UiShimmerDriver._();

  static const int _periodMicros = 1500 * 1000;

  final ValueNotifier<double> progress = ValueNotifier<double>(0.5);

  Ticker? _ticker;
  int _refs = 0;

  static bool get _inTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  void acquire() {
    _refs++;
    if (_inTest || _ticker != null) return;
    _ticker = Ticker(_onTick)..start();
  }

  void release() {
    _refs--;
    if (_refs > 0) return;
    _refs = 0;
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    progress.value = (elapsed.inMicroseconds % _periodMicros) / _periodMicros;
  }
}

class _UiShimmerPainter extends CustomPainter {
  _UiShimmerPainter({
    required this.progress,
    required this.base,
    required this.highlight,
    required this.radius,
  }) : super(repaint: progress);

  final ValueNotifier<double> progress;
  final Color base;
  final Color highlight;

  /// `null` paints a circle (avatar placeholders).
  final BorderRadius? radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final BorderRadius? r = radius;
    final Path clip = Path();
    if (r == null) {
      clip.addOval(rect);
    } else {
      clip.addRRect(r.toRRect(rect));
    }

    canvas.save();
    canvas.clipPath(clip);
    canvas.drawRect(rect, Paint()..color = base);

    // A soft band sweeping left to right, sized to 42% of the box.
    final double bandWidth = size.width * 0.42;
    final double travel = size.width;
    final double dx = ((progress.value * 2.4) - 1.2) * travel;
    final Rect band = Rect.fromLTWH(dx, 0, bandWidth, size.height);
    if (!band.isEmpty && band.overlaps(rect)) {
      canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            colors: <Color>[Colors.transparent, highlight, Colors.transparent],
          ).createShader(band),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UiShimmerPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.highlight != highlight ||
      oldDelegate.radius != radius ||
      oldDelegate.progress != progress;
}
