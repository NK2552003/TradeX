import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/affiliate_program/data/repositories/affiliate_portal_repository.dart';

/// Media kit: the tracked-link builder, the creative library, ready-to-send
/// copy and the brand rules. Every snippet is generated from the partner's own
/// link, so changing the slug or the campaign tag rewrites the whole page.
class AffiliateMarketingPage extends StatefulWidget {
  const AffiliateMarketingPage({
    super.key,
    this.repository,
    this.onOpenReferrals,
    this.onOpenPayouts,
  });

  final AffiliatePortalRepository? repository;
  final VoidCallback? onOpenReferrals;
  final VoidCallback? onOpenPayouts;

  @override
  State<AffiliateMarketingPage> createState() => _AffiliateMarketingPageState();
}

class _AffiliateMarketingPageState extends State<AffiliateMarketingPage> {
  late final AffiliatePortalRepository _repo =
      widget.repository ?? AffiliatePortalRepositoryImpl();

  List<Creative> _creatives = const <Creative>[];
  List<String> _channels = const <String>[];
  List<ChannelPerformance> _performance = const <ChannelPerformance>[];
  String _link = '';
  String? _channel;
  String _campaign = '';
  String? _format;
  int _tab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getCreatives(),
      _repo.getChannels(),
      _repo.getReferralLink(),
      _repo.getSnapshot(),
    ]);
    if (!mounted) return;
    setState(() {
      _creatives = results[0]! as List<Creative>;
      _channels = results[1]! as List<String>;
      _link = results[2]! as String;
      _performance = (results[3]! as AffiliatePortalSnapshot).channels;
      _loading = false;
    });
  }

  /// Formats come from the assets themselves, so a new creative format shows
  /// up as a filter chip without touching this page.
  List<String> get _formats {
    final Set<String> seen = <String>{
      for (final Creative creative in _creatives) creative.format,
    };
    return seen.toList()..sort();
  }

  List<Creative> get _visibleCreatives => _format == null
      ? _creatives
      : _creatives
            .where((Creative creative) => creative.format == _format)
            .toList(growable: false);

  static String _slugify(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// The link every snippet on this page embeds. UTM tags are what make the
  /// referrals table able to say which placement paid.
  String get _trackedLink {
    final List<String> params = <String>[
      if (_channel != null) 'utm_source=${_slugify(_channel!)}',
      if (_campaign.trim().isNotEmpty) 'utm_campaign=${_slugify(_campaign)}',
    ];
    return params.isEmpty ? _link : '$_link?${params.join('&')}';
  }

  bool get _tagged => _channel != null || _campaign.trim().isNotEmpty;

  void _resetTags() => setState(() {
    _channel = null;
    _campaign = '';
  });

  Future<void> _copy(String label, String body) async {
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    UiToast.show(
      context,
      title: 'Copied $label',
      message: 'Paste it anywhere — your tracked link is already inside.',
      intent: UiIntent.success,
    );
  }

  /// Asset delivery is a backend concern; the button keeps its call site so
  /// wiring a signed download URL later is a one-line change.
  void _download(Creative creative) => UiToast.show(
    context,
    title: creative.title,
    message:
        '${creative.format} · ${creative.dimensions} · ${creative.sizeLabel} '
        'will download once asset storage is connected.',
    intent: UiIntent.info,
  );

  /// Copy templates are built from the tracked link and the commission rate,
  /// never pasted in as finished strings, so they cannot drift out of date.
  List<_Snippet> get _snippets => <_Snippet>[
    _Snippet(
      title: 'X / Twitter post',
      description: 'Leads with the habit, not the product. Room for a chart.',
      icon: Icons.tag_rounded,
      body:
          'I stopped guessing why my week was red and started logging every '
          'entry, exit and the reason behind both.\n\n'
          'TradeX does the journal, the stats and the AI review in one place. '
          'Free tier is enough to see whether it changes anything:\n'
          '$_trackedLink',
    ),
    _Snippet(
      title: 'Direct message',
      description: 'Short, personal, no pitch. Best conversion per send.',
      icon: Icons.chat_bubble_outline_rounded,
      body:
          'Hey — you mentioned you keep your trades in a spreadsheet. This is '
          'the journal I switched to: it tags setups, scores the psychology '
          'and shows which playbook actually makes money.\n\n'
          '$_trackedLink',
    ),
    _Snippet(
      title: 'Newsletter blurb',
      description: 'Two paragraphs plus the disclosure your list expects.',
      icon: Icons.mail_outline_rounded,
      body:
          'Most traders review their P&L. Very few review their decisions. '
          'TradeX is a trading journal built around the second one: every '
          'trade carries its setup, its risk and a written reason, then the '
          'analyzer tells you which of those habits pays.\n\n'
          'Start on the free plan, upgrade only when the numbers justify it:\n'
          '$_trackedLink\n\n'
          'Disclosure: the link above is an affiliate link. I earn a '
          'commission if you subscribe, at no extra cost to you.',
    ),
    _Snippet(
      title: 'YouTube description',
      description: 'Timestamp-friendly, with the disclosure up top.',
      icon: Icons.play_circle_outline_rounded,
      body:
          '📓 The journal I use in this video: $_trackedLink\n'
          '(affiliate link — I earn a commission, you pay the same price)\n\n'
          'What it does: trade journal, playbook stats, risk limits, AI trade '
          'review and a community feed of real executions.',
    ),
    _Snippet(
      title: 'HTML embed',
      description: 'Drop-in button for a blog post or a sidebar.',
      icon: Icons.code_rounded,
      body:
          '<a href="$_trackedLink" rel="sponsored noopener" '
          'target="_blank">Track your trades with TradeX</a>',
    ),
  ];

  @override
  Widget build(BuildContext context) => AppPageBlock(
    title: 'Media kit',
    subtitle: _loading
        ? 'Loading creatives and copy…'
        : '${_creatives.length} creative${_creatives.length == 1 ? '' : 's'} · '
              '${_snippets.length} copy templates · '
              '${_formats.length} format${_formats.length == 1 ? '' : 's'}',
    actions: <Widget>[
      UiButton(
        label: 'Copy link',
        leadingIcon: Icons.link_rounded,
        variant: UiVariant.outline,
        size: UiSize.sm,
        hideLabelOnMobile: true,
        onPressed: _link.isEmpty
            ? null
            : () => _copy('your link', _trackedLink),
      ),
      UiButton(
        label: 'Referrals',
        leadingIcon: Icons.trending_up_rounded,
        size: UiSize.sm,
        hideLabelOnMobile: true,
        onPressed: widget.onOpenReferrals,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppFadeIn(child: _linkBuilder()),
        UiGap.v(context.ui.spacing.lg),
        AppFadeIn(delay: AppMotion.step, child: _tabs()),
      ],
    ),
  );

  Widget _tabs() => UiTabs(
    index: _tab,
    onChanged: (int index) => setState(() => _tab = index),
    variant: UiTabsVariant.segmented,
    stretch: context.uiRes.isMobile,
    items: <UiTabItem>[
      UiTabItem(
        label: 'Creatives',
        icon: Icons.collections_bookmark_outlined,
        count: _creatives.length,
        content: _creativesTab(),
      ),
      UiTabItem(
        label: 'Copy',
        icon: Icons.short_text_rounded,
        count: _snippets.length,
        content: _copyTab(),
      ),
      UiTabItem(
        label: 'Brand',
        icon: Icons.verified_outlined,
        content: _brandTab(),
      ),
    ],
  );

  Widget _linkBuilder() {
    final Widget channel = UiField(
      label: 'Placement',
      helper: 'Becomes utm_source',
      child: UiSelect<String?>(
        value: _channel,
        hintText: 'Untagged',
        leadingIcon: Icons.campaign_outlined,
        onChanged: (String? value) => setState(() => _channel = value),
        options: <UiOption<String?>>[
          const UiOption<String?>(value: null, label: 'Untagged'),
          for (final String option in _channels)
            UiOption<String?>(value: option, label: option),
        ],
      ),
    );
    final Widget campaign = UiField(
      label: 'Campaign tag',
      helper: 'Becomes utm_campaign',
      child: UiInput(
        value: _campaign,
        hintText: 'october-review',
        leadingIcon: Icons.local_offer_outlined,
        onChanged: (String value) => setState(() => _campaign = value),
      ),
    );

    return UiCard(
      title: 'Tracked link builder',
      subtitle:
          'Tag each placement so the referrals table can tell you which one '
          'actually pays',
      trailing: UiBadge(
        label: _tagged ? 'Tagged' : 'Base link',
        intent: _tagged ? UiIntent.success : UiIntent.neutral,
      ),
      actions: <Widget>[
        UiButton(
          label: 'Copy link',
          leadingIcon: Icons.copy_rounded,
          size: UiSize.sm,
          expandOnMobile: false,
          onPressed: _link.isEmpty
              ? null
              : () => _copy('your link', _trackedLink),
        ),
        UiButton(
          label: 'Clear tags',
          leadingIcon: Icons.backspace_outlined,
          variant: UiVariant.ghost,
          size: UiSize.sm,
          expandOnMobile: false,
          onPressed: _tagged ? _resetTags : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (context.uiRes.isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                channel,
                UiGap.v(context.ui.spacing.sm),
                campaign,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: channel),
                UiGap.h(context.ui.spacing.md),
                Expanded(child: campaign),
              ],
            ),
          UiGap.v(context.ui.spacing.md),
          _linkPreview(),
        ],
      ),
    );
  }

  /// Selectable rather than a disabled input: partners copy this by hand more
  /// often than they press the button.
  Widget _linkPreview() => Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.sp(context.ui.spacing.md),
      vertical: context.sp(context.ui.spacing.sm),
    ),
    decoration: BoxDecoration(
      color: context.uiColors.surfaceMuted,
      borderRadius: context.radius(context.ui.radii.md),
      border: Border.all(color: context.uiColors.border),
    ),
    child: Row(
      children: <Widget>[
        Icon(
          Icons.link_rounded,
          size: context.sz(context.ui.sizes.iconSm),
          color: context.uiColors.foregroundMuted,
        ),
        UiGap.h(context.ui.spacing.sm),
        Expanded(
          child: _loading
              ? UiSkeleton(height: context.sz(16))
              : SelectableText(
                  _trackedLink,
                  style: context.uiText.body.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _creativesTab() {
    final List<Creative> rows = _visibleCreatives;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        UiToggleGroup<String?>(
          value: _format,
          expand: context.uiRes.isMobile,
          onChanged: (String? value) => setState(() => _format = value),
          options: <UiToggleOption<String?>>[
            const UiToggleOption<String?>(value: null, label: 'All'),
            for (final String format in _formats)
              UiToggleOption<String?>(value: format, label: format),
          ],
        ),
        UiGap.v(context.ui.spacing.md),
        if (_loading)
          UiSkeleton(height: context.sz(220))
        else if (rows.isEmpty)
          UiEmptyState(
            title: 'No assets in this format',
            message: 'Clear the format filter to see the whole library.',
            icon: Icons.image_not_supported_outlined,
            action: UiButton(
              label: 'Show all',
              variant: UiVariant.outline,
              size: UiSize.sm,
              expandOnMobile: false,
              onPressed: () => setState(() => _format = null),
            ),
          )
        else
          _creativeGrid(rows),
        UiGap.v(context.ui.spacing.lg),
        _performanceCard(),
      ],
    );
  }

  /// Cards size themselves to their content, so a `Wrap` over a measured
  /// column count beats a fixed-aspect grid here.
  Widget _creativeGrid(List<Creative> rows) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double gap = context.sp(context.ui.spacing.md);
      final int columns = constraints.maxWidth >= 1100
          ? 3
          : (constraints.maxWidth >= 620 ? 2 : 1);
      final double width =
          (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            SizedBox(
              width: columns == 1 ? constraints.maxWidth : width,
              child: AppFadeIn(
                delay: AppMotion.step * (i > 8 ? 8 : i),
                child: _creativeCard(rows[i]),
              ),
            ),
        ],
      );
    },
  );

  Widget _creativeCard(Creative creative) => UiCard(
    variant: UiCardVariant.outlined,
    title: creative.title,
    subtitle: '${creative.format} · ${creative.dimensions}',
    trailing: UiBadge(label: creative.sizeLabel, intent: UiIntent.neutral),
    actions: <Widget>[
      UiButton(
        label: 'Download',
        leadingIcon: Icons.download_rounded,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: () => _download(creative),
      ),
      UiButton(
        label: 'Copy embed',
        leadingIcon: Icons.code_rounded,
        variant: UiVariant.ghost,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: () =>
            _copy('${creative.title} embed', _embedFor(creative)),
      ),
    ],
    child: _creativePreview(creative),
  );

  /// Dimensions arrive as display strings (`1080 × 1920`), so read the numbers
  /// out instead of splitting on a separator that could change.
  static List<int> _dimensionsOf(String raw) => RegExp(r'\d+')
      .allMatches(raw)
      .map((RegExpMatch match) => int.parse(match.group(0)!))
      .toList(growable: false);

  static const Set<String> _imageFormats = <String>{
    'PNG',
    'JPG',
    'JPEG',
    'GIF',
    'SVG',
    'WEBP',
  };

  /// Only still images get an `<img>` wrapper; video assets get a plain
  /// sponsored link, because an image tag around an MP4 renders nothing.
  String _embedFor(Creative creative) {
    final String href =
        '<a href="$_trackedLink" rel="sponsored noopener" target="_blank">';
    if (!_imageFormats.contains(creative.format.toUpperCase())) {
      return '$href${creative.title} — TradeX</a>';
    }
    final List<int> dims = _dimensionsOf(creative.dimensions);
    final String size = dims.length >= 2
        ? ' width="${dims[0]}" height="${dims[1]}"'
        : '';
    return '$href<img src="{{${creative.id}}}" '
        'alt="TradeX — ${creative.title}"$size /></a>';
  }

  /// The placeholder mirrors the real asset's aspect ratio so a partner can see
  /// how it will sit in a feed before storage is wired up.
  Widget _creativePreview(Creative creative) {
    final List<int> dims = _dimensionsOf(creative.dimensions);
    final double ratio = dims.length >= 2 && dims[1] != 0
        ? (dims[0] / dims[1]).clamp(0.5, 3.0)
        : 16 / 9;
    return AspectRatio(
      aspectRatio: ratio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: context.radius(context.ui.radii.md),
          border: Border.all(color: context.uiColors.border),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              context.uiColors.surfaceMuted,
              context.uiColors.primary.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              creative.icon,
              size: context.sz(context.ui.sizes.iconLg),
              color: context.uiColors.primary,
            ),
            UiGap.v(context.ui.spacing.xs),
            Text(
              creative.dimensions,
              style: context.uiText.caption.copyWith(
                color: context.uiColors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Which channels convert is the only guidance that beats taste when picking
  /// a creative, so it lives next to the library.
  Widget _performanceCard() {
    final List<ChannelPerformance> rows =
        List<ChannelPerformance>.from(_performance)..sort(
          (ChannelPerformance a, ChannelPerformance b) =>
              b.revenue.compareTo(a.revenue),
        );
    return UiCard(
      title: 'Where your traffic converts',
      subtitle: 'Revenue by placement — put your best creative here first',
      child: _loading
          ? UiSkeleton(height: context.sz(120))
          : rows.isEmpty
          ? const UiEmptyState(
              title: 'No attributed traffic yet',
              message: 'Share a tagged link and this fills in automatically.',
              icon: Icons.insights_outlined,
            )
          : UiBarList(
              valueFormatter: AppTokens.money,
              items: <UiBarListItem>[
                for (final ChannelPerformance row in rows)
                  UiBarListItem(
                    label:
                        '${row.channel} · ${AppTokens.percent(row.conversionPercent)} conv.',
                    value: row.revenue,
                    icon: Icons.campaign_outlined,
                    onTap: () => setState(() {
                      _channel = row.channel;
                      _tab = 0;
                    }),
                  ),
              ],
            ),
    );
  }

  Widget _copyTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      UiCallout(
        title: 'Every template already carries your link',
        message: _tagged
            ? 'Snippets use the tagged link above, so the referrals table will '
                  'attribute the signups to this placement.'
            : 'Pick a placement above to tag these snippets before you send '
                  'them — untagged signups still pay, they just cannot be '
                  'traced back to a channel.',
        intent: _tagged ? UiIntent.success : UiIntent.info,
        icon: Icons.auto_fix_high_outlined,
      ),
      UiGap.v(context.ui.spacing.md),
      for (int i = 0; i < _snippets.length; i++) ...<Widget>[
        AppFadeIn(
          delay: AppMotion.step * (i > 6 ? 6 : i),
          child: _snippetCard(_snippets[i]),
        ),
        if (i != _snippets.length - 1) UiGap.v(context.ui.spacing.md),
      ],
    ],
  );

  Widget _snippetCard(_Snippet snippet) => UiCard(
    variant: UiCardVariant.outlined,
    title: snippet.title,
    subtitle: snippet.description,
    leading: Icon(
      snippet.icon,
      size: context.sz(context.ui.sizes.iconMd),
      color: context.uiColors.primary,
    ),
    actions: <Widget>[
      UiButton(
        label: 'Copy',
        leadingIcon: Icons.copy_rounded,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: () => _copy(snippet.title.toLowerCase(), snippet.body),
      ),
      UiButton(
        label: '${snippet.body.length} chars',
        variant: UiVariant.ghost,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: null,
      ),
    ],
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      decoration: BoxDecoration(
        color: context.uiColors.surfaceMuted,
        borderRadius: context.radius(context.ui.radii.md),
      ),
      child: SelectableText(snippet.body, style: context.uiText.body),
    ),
  );

  Widget _brandTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const UiCallout(
        title: 'Promote the tool, never the returns',
        message:
            'TradeX is journalling and analytics software. Do not promise '
            'profits, publish signals as ours, or imply we are a broker or an '
            'advisor. Accounts that do are removed from the programme and lose '
            'unpaid commission.',
        intent: UiIntent.warning,
        icon: Icons.gavel_rounded,
      ),
      UiGap.v(context.ui.spacing.md),
      UiCard(
        title: 'Brand rules',
        subtitle: 'The short version of the partner agreement',
        child: UiAccordion(
          allowMultiple: true,
          items: <UiAccordionItem>[
            UiAccordionItem(
              title: 'Name and logo',
              subtitle: 'How to write it',
              leadingIcon: Icons.abc_rounded,
              content: _rules(<String>[
                'Write it TradeX — one word, capital T, capital X.',
                'Never lock the logo into another mark or add a tagline to it.',
                'Leave clear space around the logo of at least the X height.',
                'Do not recolour the logo; use the light or dark asset.',
              ]),
            ),
            UiAccordionItem(
              title: 'Claims you can make',
              subtitle: 'Safe language',
              leadingIcon: Icons.check_circle_outline_rounded,
              content: _rules(<String>[
                'Describe features: journal, playbook stats, AI review, risk '
                    'limits, community feed.',
                'Share your own screenshots and your own numbers.',
                'Say the free tier exists and what it includes.',
              ]),
            ),
            UiAccordionItem(
              title: 'Claims you cannot make',
              subtitle: 'Instant removal',
              leadingIcon: Icons.block_rounded,
              content: _rules(<String>[
                'Guaranteed, expected or typical returns of any size.',
                'Calling TradeX a broker, a fund, a signal service or an '
                    'advisor.',
                'Paid ads bidding on the TradeX brand name.',
                'Coupon or "discount code" pages we did not authorise.',
              ]),
            ),
            UiAccordionItem(
              title: 'Disclosure',
              subtitle: 'Required on every placement',
              leadingIcon: Icons.campaign_outlined,
              content: _rules(<String>[
                'State that the link is an affiliate link, before the link.',
                'Keep the disclosure visible without expanding a description.',
                'Use rel="sponsored" on web embeds — the embed snippets '
                    'already do.',
              ]),
            ),
          ],
        ),
      ),
      UiGap.v(context.ui.spacing.md),
      AppFadeIn(delay: AppMotion.step, child: _payoutHint()),
    ],
  );

  Widget _rules(List<String> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final String line in lines)
        Padding(
          padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xs)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: context.sp(context.ui.spacing.xs)),
                child: Icon(
                  Icons.circle,
                  size: context.sz(6),
                  color: context.uiColors.foregroundSubtle,
                ),
              ),
              UiGap.h(context.ui.spacing.sm),
              Expanded(child: Text(line, style: context.uiText.body)),
            ],
          ),
        ),
    ],
  );

  Widget _payoutHint() => UiCard(
    variant: UiCardVariant.ghost,
    title: 'Commission is paid on cleared subscriptions',
    subtitle:
        'Signups appear in referrals immediately; commission moves to your '
        'balance once the first payment clears.',
    actions: <Widget>[
      UiButton(
        label: 'Payout ledger',
        leadingIcon: Icons.account_balance_wallet_outlined,
        variant: UiVariant.outline,
        size: UiSize.sm,
        expandOnMobile: false,
        onPressed: widget.onOpenPayouts,
      ),
    ],
    child: const SizedBox.shrink(),
  );
}

/// One ready-to-send piece of copy. Held as a value type so the list can be
/// generated from the tracked link rather than written out per placement.
@immutable
class _Snippet {
  const _Snippet({
    required this.title,
    required this.description,
    required this.icon,
    required this.body,
  });

  final String title;
  final String description;
  final IconData icon;
  final String body;
}
