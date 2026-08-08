import 'package:flutter/material.dart';

import '../flutter-ui/flutter_ui.dart';
import 'state_gallery.dart';

/// Number of galleries rendered by [FeedbackShowcaseSection].
const int kFeedbackGalleryCount = 14;

/// Batch — feedback & overlays: banners, empty states, identity, hints,
/// menus, modals, panels, transient messages and busy indicators.
class FeedbackShowcaseSection extends StatefulWidget {
  const FeedbackShowcaseSection({super.key, required this.startIndex});

  final int startIndex;

  @override
  State<FeedbackShowcaseSection> createState() => _FeedbackShowcaseSectionState();
}

class _FeedbackShowcaseSectionState extends State<FeedbackShowcaseSection> {
  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(context.ui.spacing.lg);
    final int i = widget.startIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const UiShowcaseSection(
          title: 'Feedback',
          subtitle:
              'Banners, empty states, identity, hints, menus, modals, '
              'panels, transient messages and busy indicators.',
        ),
        SizedBox(height: gap),
        _CalloutGallery(index: i),
        SizedBox(height: gap),
        _EmptyStateGallery(index: i + 1),
        SizedBox(height: gap),
        _AvatarGallery(index: i + 2),
        SizedBox(height: gap),
        _AvatarGroupGallery(index: i + 3),
        SizedBox(height: gap),
        _TooltipGallery(index: i + 4),
        SizedBox(height: gap),
        _PopoverGallery(index: i + 5),
        SizedBox(height: gap),
        _DialogGallery(index: i + 6),
        SizedBox(height: gap),
        _DrawerGallery(index: i + 7),
        SizedBox(height: gap),
        _ToastGallery(index: i + 8),
        SizedBox(height: gap),
        _ToasterGallery(index: i + 9),
        SizedBox(height: gap),
        _LightboxGallery(index: i + 10),
        SizedBox(height: gap),
        _TypingIndicatorGallery(index: i + 11),
        SizedBox(height: gap),
        _IconButtonGallery(index: i + 12),
        SizedBox(height: gap),
        _ToggleGallery(index: i + 13),
      ],
    );
  }
}

Widget _previewBox(BuildContext context, Widget child, {double? width}) {
  final theme = context.ui;
  return Container(
    width: width,
    padding: EdgeInsets.all(context.sp(theme.spacing.md)),
    decoration: BoxDecoration(
      color: theme.colors.background,
      borderRadius: context.radius(theme.radii.lg),
      border: Border.all(color: theme.colors.border, width: theme.borders.hairline),
    ),
    child: child,
  );
}

class _CalloutGallery extends StatelessWidget {
  const _CalloutGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiCallout',
      description: 'Inline informational banner across all intents, with icon override, action slot and dismiss.',
      tags: const <String>['feedback', 'banner'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        for (final UiIntent intent in UiIntent.values)
          UiStateCase(
            intent.name,
            fill: true,
            builder: (BuildContext _) => UiCallout(
              title: '${intent.name[0].toUpperCase()}${intent.name.substring(1)} notice',
              message: 'Market data may be delayed by up to 15 minutes.',
              intent: intent,
            ),
          ),
        UiStateCase(
          'dismissible',
          fill: true,
          builder: (BuildContext _) => UiCallout(
            title: 'Position at risk',
            message: 'Margin usage above 80%.',
            intent: UiIntent.danger,
            onClose: () {},
          ),
        ),
        UiStateCase(
          'with action + custom icon',
          fill: true,
          builder: (BuildContext _) => UiCallout(
            title: 'Verify your identity',
            message: 'Required to withdraw funds.',
            intent: UiIntent.warning,
            icon: Icons.verified_user_outlined,
            action: UiButton(label: 'Verify now', size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
          ),
        ),
      ],
    );
  }
}

class _EmptyStateGallery extends StatelessWidget {
  const _EmptyStateGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiEmptyState',
      description: 'Empty feed/watchlist/search block with icon, message and optional action.',
      tags: const <String>['feedback', 'empty'],
      minCaseWidth: 280,
      cases: <UiStateCase>[
        const UiStateCase.of(
          'title only',
          UiEmptyState(title: 'No results'),
        ),
        const UiStateCase.of(
          'with message',
          UiEmptyState(
            title: 'No open positions',
            message: 'Positions you open will appear here.',
          ),
        ),
        UiStateCase(
          'with icon + action',
          builder: (BuildContext _) => UiEmptyState(
            title: 'Your watchlist is empty',
            message: 'Add symbols to track their price.',
            icon: Icons.star_outline,
            action: UiButton(label: 'Add symbol', size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
          ),
        ),
      ],
    );
  }
}

class _AvatarGallery extends StatelessWidget {
  const _AvatarGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiAvatar',
      description: 'Initials/image avatar across sizes, with presence dot, verified badge and tap target.',
      tags: const <String>['identity'],
      minCaseWidth: 160,
      cases: <UiStateCase>[
        for (final UiSize size in UiSize.values)
          UiStateCase.of(size.name, UiAvatar(name: 'Ada Lovelace', size: size)),
        const UiStateCase.of('online', UiAvatar(name: 'John Doe', online: true)),
        const UiStateCase.of('verified', UiAvatar(name: 'Grace Hopper', verified: true)),
        UiStateCase(
          'image + tap',
          builder: (BuildContext _) => UiAvatar(
            name: 'Alan Turing',
            imageUrl: 'https://picsum.photos/seed/avatar/200',
            onTap: () {},
          ),
        ),
        const UiStateCase.of('no name fallback', UiAvatar()),
      ],
    );
  }
}

class _AvatarGroupGallery extends StatelessWidget {
  const _AvatarGroupGallery({required this.index});

  final int index;

  static List<UiAvatar> _avatars(int n) => <UiAvatar>[
        for (int i = 0; i < n; i++) UiAvatar(name: 'Trader $i'),
      ];

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiAvatarGroup',
      description: 'Overlapping avatar stack with configurable max and overflow counter.',
      tags: const <String>['identity'],
      minCaseWidth: 240,
      cases: <UiStateCase>[
        UiStateCase.of('sm · under max', UiAvatarGroup(avatars: _avatars(3), size: UiSize.sm)),
        UiStateCase.of('sm · overflow', UiAvatarGroup(avatars: _avatars(9), max: 4, size: UiSize.sm)),
        UiStateCase.of('md · overflow', UiAvatarGroup(avatars: _avatars(7), max: 3, size: UiSize.md)),
      ],
    );
  }
}

class _TooltipGallery extends StatelessWidget {
  const _TooltipGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiTooltip',
      description: 'Hover-triggered tooltip wrapper; renders bare child on touch layouts (no hover).',
      tags: const <String>['feedback', 'hint'],
      minCaseWidth: 220,
      cases: <UiStateCase>[
        UiStateCase(
          'short message',
          builder: (BuildContext ctx) => UiTooltip(
            message: 'Add to watchlist',
            child: UiIconButton(icon: Icons.star_outline, onPressed: () {}),
          ),
        ),
        UiStateCase(
          'long message',
          builder: (BuildContext ctx) => UiTooltip(
            message: 'This order type executes immediately at the best available price.',
            child: UiButton(label: 'Market order', size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
          ),
        ),
        UiStateCase(
          'over label',
          builder: (BuildContext ctx) => UiTooltip(
            message: 'Unrealized profit and loss',
            child: Text('PnL', style: ctx.uiText.bodyStrong),
          ),
        ),
      ],
    );
  }
}

class _PopoverGallery extends StatelessWidget {
  const _PopoverGallery({required this.index});

  final int index;

  Widget _content(BuildContext ctx, String title) {
    final theme = ctx.ui;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: ctx.uiText.bodyStrong.copyWith(color: theme.colors.foreground)),
        SizedBox(height: ctx.sp(theme.spacing.xs)),
        Text('Converts to a bottom sheet on mobile.', style: ctx.uiText.caption.copyWith(color: theme.colors.foregroundMuted)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiPopover',
      description: 'Anchored menu/popover with a custom trigger and content builder; sheet on phones.',
      tags: const <String>['overlay', 'menu'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'button trigger',
          builder: (BuildContext ctx) => UiPopover(
            trigger: UiButton(label: 'Filters', size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
            content: (BuildContext c) => _content(c, 'Filter results'),
          ),
        ),
        UiStateCase(
          'icon trigger + fixed width',
          builder: (BuildContext ctx) => UiPopover(
            trigger: UiIconButton(icon: Icons.more_vert, onPressed: () {}),
            width: 220,
            content: (BuildContext c) => _content(c, 'Options'),
          ),
        ),
        UiStateCase(
          'inline preview of content',
          fill: true,
          builder: (BuildContext ctx) => _previewBox(ctx, _content(ctx, 'Sort by'), width: 260),
        ),
      ],
    );
  }
}

class _DialogGallery extends StatelessWidget {
  const _DialogGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiDialog',
      description: 'Modal dialog (bottom sheet on phones): icon, description, content slot, actions and confirm helper.',
      tags: const <String>['overlay', 'modal'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'title only · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open dialog',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiDialog.show<void>(
              ctx,
              child: const UiDialog(title: 'Session expired'),
            ),
          ),
        ),
        UiStateCase(
          'confirm helper (destructive)',
          builder: (BuildContext ctx) => UiButton(
            label: 'Close position',
            variant: UiVariant.destructive,
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiDialog.confirm(
              ctx,
              title: 'Close position?',
              description: 'This will realize the current profit or loss.',
              confirmLabel: 'Close',
              confirmVariant: UiVariant.destructive,
            ),
          ),
        ),
        UiStateCase(
          'non-dismissible · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Required action',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiDialog.show<void>(
              ctx,
              dismissible: false,
              child: UiDialog(
                title: 'Accept terms',
                description: 'You must accept to continue.',
                icon: Icons.gavel_outlined,
                actions: <Widget>[
                  UiButton(label: 'Accept', size: UiSize.sm, expandOnMobile: false, onPressed: () => Navigator.of(ctx).maybePop()),
                ],
              ),
            ),
          ),
        ),
        UiStateCase(
          'inline preview · full body',
          fill: true,
          builder: (BuildContext ctx) => _previewBox(
            ctx,
            UiDialog(
              title: 'Delete alert',
              description: 'This cannot be undone.',
              icon: Icons.delete_outline,
              intent: UiIntent.danger,
              actions: <Widget>[
                UiButton(label: 'Cancel', variant: UiVariant.secondary, size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
                UiButton(label: 'Delete', variant: UiVariant.destructive, size: UiSize.sm, expandOnMobile: false, onPressed: () {}),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerGallery extends StatelessWidget {
  const _DrawerGallery({required this.index});

  final int index;

  Widget _body(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: ctx.sp(ctx.ui.spacing.sm)),
              child: Text('Filter option $i', style: ctx.uiText.body),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiDrawer',
      description: 'Side panel (full-height sheet on phones) with header, scrollable body and optional footer.',
      tags: const <String>['overlay', 'panel'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'from right · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open filters',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiDrawer.show<void>(ctx, title: 'Filters', child: _body(ctx)),
          ),
        ),
        UiStateCase(
          'from left · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open account panel',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiDrawer.show<void>(ctx, title: 'Account', fromRight: false, child: _body(ctx)),
          ),
        ),
        UiStateCase(
          'with footer · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open with footer',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiDrawer.show<void>(
              ctx,
              title: 'Filters',
              child: _body(ctx),
              footer: UiButton(label: 'Apply', expandOnMobile: false, onPressed: () {}),
            ),
          ),
        ),
        UiStateCase(
          'inline preview · full body',
          fill: true,
          builder: (BuildContext ctx) => SizedBox(
            height: 260,
            child: _previewBox(
              ctx,
              UiDrawer(
                title: 'Filters',
                footer: UiButton(label: 'Apply', expandOnMobile: false, onPressed: () {}),
                child: _body(ctx),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastGallery extends StatelessWidget {
  const _ToastGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiToast',
      description: 'Transient message card across intents, with icon, message and action; static preview + trigger.',
      tags: const <String>['overlay', 'transient'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        for (final UiIntent intent in <UiIntent>[UiIntent.neutral, UiIntent.success, UiIntent.warning, UiIntent.danger])
          UiStateCase(
            intent.name,
            fill: true,
            builder: (BuildContext _) => UiToast(
              data: UiToastData(
                title: '${intent.name[0].toUpperCase()}${intent.name.substring(1)} toast',
                message: 'Order #4821 update.',
                intent: intent,
                icon: Icons.notifications_outlined,
              ),
              onDismiss: () {},
            ),
          ),
        UiStateCase(
          'with action',
          fill: true,
          builder: (BuildContext _) => UiToast(
            data: UiToastData(
              title: 'Trade executed',
              message: 'Bought 10 AAPL @ 189.20',
              intent: UiIntent.success,
              actionLabel: 'View',
              onAction: () {},
            ),
            onDismiss: () {},
          ),
        ),
        UiStateCase(
          'trigger via UiToast.show',
          builder: (BuildContext ctx) => UiButton(
            label: 'Show toast',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => UiToast.show(
              ctx,
              title: 'Price alert',
              message: 'TSLA crossed \$250',
              intent: UiIntent.info,
              icon: Icons.trending_up,
            ),
          ),
        ),
      ],
    );
  }
}

class _ToasterGallery extends StatelessWidget {
  const _ToasterGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiToastScope',
      description: 'App-level toast host: wraps content, queues stacked toasts bottom-right (bottom-full-width on mobile).',
      tags: const <String>['overlay', 'host'],
      minCaseWidth: 320,
      cases: <UiStateCase>[
        UiStateCase(
          'single trigger',
          fill: true,
          builder: (BuildContext ctx) => SizedBox(
            height: 160,
            child: UiToastScope(
              child: Center(
                child: UiButton(
                  label: 'Queue toast',
                  size: UiSize.sm,
                  expandOnMobile: false,
                  onPressed: () => UiToast.show(ctx, title: 'Saved', intent: UiIntent.success),
                ),
              ),
            ),
          ),
        ),
        UiStateCase(
          'stacked queue',
          fill: true,
          builder: (BuildContext ctx) => SizedBox(
            height: 200,
            child: UiToastScope(
              child: Center(
                child: UiButton(
                  label: 'Queue 3 toasts',
                  size: UiSize.sm,
                  expandOnMobile: false,
                  onPressed: () {
                    UiToast.show(ctx, title: 'Order filled', intent: UiIntent.success);
                    UiToast.show(ctx, title: 'Margin warning', intent: UiIntent.warning);
                    UiToast.show(ctx, title: 'Connection lost', intent: UiIntent.danger);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LightboxGallery extends StatelessWidget {
  const _LightboxGallery({required this.index});

  final int index;

  static const List<String> _images = <String>[
    'https://picsum.photos/seed/lightbox1/800',
    'https://picsum.photos/seed/lightbox2/800',
    'https://picsum.photos/seed/lightbox3/800',
  ];

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiLightbox',
      description: 'Full-screen zoomable image viewer with swipe navigation, caption and optional share/download.',
      tags: const <String>['overlay', 'media'],
      minCaseWidth: 260,
      cases: <UiStateCase>[
        UiStateCase(
          'single image · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open image',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => showUiLightbox(ctx, imageUrls: _images.take(1).toList()),
          ),
        ),
        UiStateCase(
          'gallery + caption · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open gallery',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => showUiLightbox(
              ctx,
              imageUrls: _images,
              initialIndex: 1,
              caption: 'Trade screenshot 2 of 3',
            ),
          ),
        ),
        UiStateCase(
          'with share + download · trigger',
          builder: (BuildContext ctx) => UiButton(
            label: 'Open with actions',
            size: UiSize.sm,
            expandOnMobile: false,
            onPressed: () => showUiLightbox(
              ctx,
              imageUrls: _images,
              onShare: () {},
              onDownload: () {},
            ),
          ),
        ),
        UiStateCase(
          'inline preview',
          fill: true,
          builder: (BuildContext ctx) => SizedBox(
            height: 220,
            child: UiLightbox(imageUrls: _images, caption: 'Preview'),
          ),
        ),
      ],
    );
  }
}

class _TypingIndicatorGallery extends StatelessWidget {
  const _TypingIndicatorGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiTypingIndicator',
      description: 'Animated three-dot indicator for chat/assistant loading, with optional label and custom color.',
      tags: const <String>['feedback', 'loading'],
      minCaseWidth: 200,
      cases: <UiStateCase>[
        const UiStateCase.of('bare', UiTypingIndicator()),
        const UiStateCase.of('with label', UiTypingIndicator(label: 'Assistant is typing…')),
        UiStateCase(
          'custom color',
          builder: (BuildContext ctx) => UiTypingIndicator(
            label: 'Analyzing…',
            color: ctx.ui.colors.primary,
          ),
        ),
      ],
    );
  }
}

class _IconButtonGallery extends StatelessWidget {
  const _IconButtonGallery({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return UiStateGallery(
      index: index,
      name: 'UiIconButton',
      description: 'Square icon-only action across variants, sizes, disabled/badge states and tooltip.',
      tags: const <String>['action', 'control'],
      minCaseWidth: 160,
      cases: <UiStateCase>[
        for (final UiVariant v in <UiVariant>[
          UiVariant.primary,
          UiVariant.secondary,
          UiVariant.ghost,
          UiVariant.outline,
          UiVariant.destructive,
          UiVariant.success,
        ])
          UiStateCase(
            v.name,
            builder: (BuildContext _) => UiIconButton(icon: Icons.favorite_border, variant: v, onPressed: () {}),
          ),
        for (final UiSize size in UiSize.values)
          UiStateCase(
            'size · ${size.name}',
            builder: (BuildContext _) => UiIconButton(icon: Icons.share_outlined, size: size, onPressed: () {}),
          ),
        const UiStateCase.of('disabled', UiIconButton(icon: Icons.delete_outline)),
        UiStateCase(
          'with badge',
          builder: (BuildContext _) => UiIconButton(icon: Icons.notifications_outlined, badgeCount: 4, onPressed: () {}),
        ),
        UiStateCase(
          'with tooltip',
          builder: (BuildContext _) => UiIconButton(icon: Icons.info_outline, tooltip: 'More information', onPressed: () {}),
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
    return UiStateGallery(
      index: index,
      name: 'UiToggle',
      description: 'Single on/off action (bookmark/like/follow) across variants, sizes, densities, count badge and states.',
      tags: const <String>['action', 'control'],
      minCaseWidth: 200,
      cases: <UiStateCase>[
        for (final UiToggleVariant v in UiToggleVariant.values) ...<UiStateCase>[
          UiStateCase(
            '${v.name} · off',
            builder: (BuildContext _) => UiToggle(value: false, icon: Icons.favorite_border, activeIcon: Icons.favorite, variant: v, label: 'Like', onChanged: (_) {}),
          ),
          UiStateCase(
            '${v.name} · on',
            builder: (BuildContext _) => UiToggle(value: true, icon: Icons.favorite_border, activeIcon: Icons.favorite, variant: v, label: 'Like', activeLabel: 'Liked', onChanged: (_) {}),
          ),
        ],
        for (final UiSize size in UiSize.values)
          UiStateCase(
            'size · ${size.name}',
            builder: (BuildContext _) => UiToggle(value: true, icon: Icons.bookmark_border, activeIcon: Icons.bookmark, size: size, showLabel: false, onChanged: (_) {}),
          ),
        for (final UiDensity d in UiDensity.values)
          UiStateCase(
            'density · ${d.name}',
            builder: (BuildContext _) => UiToggle(value: true, icon: Icons.star_border, activeIcon: Icons.star, density: d, label: 'Watch', onChanged: (_) {}),
          ),
        UiStateCase(
          'with count',
          builder: (BuildContext _) => UiToggle(value: false, icon: Icons.thumb_up_outlined, activeIcon: Icons.thumb_up, label: 'Upvote', count: 128, onChanged: (_) {}),
        ),
        UiStateCase(
          'loading',
          builder: (BuildContext _) => UiToggle(value: false, icon: Icons.notifications_none, loading: true, label: 'Notify', onChanged: (_) {}),
        ),
        UiStateCase(
          'disabled',
          builder: (BuildContext _) => const UiToggle(value: true, icon: Icons.mic_off_outlined, activeIcon: Icons.mic_off, label: 'Muted', enabled: false, onChanged: null),
        ),
        UiStateCase(
          'label on left',
          builder: (BuildContext _) => UiToggle(value: true, icon: Icons.check_circle_outline, activeIcon: Icons.check_circle, label: 'Done', labelOnRight: false, onChanged: (_) {}),
        ),
      ],
    );
  }
}
