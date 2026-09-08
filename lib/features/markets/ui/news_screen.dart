import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/market_repository.dart';

String marketDate(DateTime? date) {
  if (date == null) return 'Time unavailable';
  final utc = date.toUtc();
  return '${utc.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][utc.month - 1]} ${utc.year}';
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({
    super.key,
    this.compact = false,
    this.symbol,
    this.onOpenSymbol,
    this.onOpenRef,
  });
  final bool compact;
  final String? symbol;
  final ValueChanged<String>? onOpenSymbol;
  final ValueChanged<AppLinkRef>? onOpenRef;
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final store = MarketWorkspaceStore.instance;
  String query = '';
  String filter = 'all';
  @override
  void initState() {
    super.initState();
    store.initialize();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final stories = (store.snapshot?.news ?? <MarketStory>[]).where((story) {
        if (widget.symbol != null && !story.symbols.contains(widget.symbol)) {
          return false;
        }
        if (filter == 'saved' && !store.bookmarks.contains(story.id)) {
          return false;
        }
        if (filter == 'watchlist' &&
            !story.symbols.any(store.watched.contains)) {
          return false;
        }
        if ((filter == 'US' || filter == 'IN') && story.market != filter) {
          return false;
        }
        return '${story.title} ${story.summary} ${story.publisher} ${story.symbols.join(' ')}'
            .toLowerCase()
            .contains(query.toLowerCase());
      }).toList();
      return ListView(
        key: PageStorageKey('news_${widget.compact}_${widget.symbol}'),
        padding: EdgeInsets.all(context.sp(widget.compact ? 12 : 24)),
        children: [
          if (!widget.compact) ...[
            AppWorkspaceHeading(
              eyebrow: 'The research desk',
              title: 'News & catalysts',
              description: 'Read the story. Connect it to your trading thesis.',
              actions: [
                UiIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh news',
                  onPressed: store.loading ? null : store.refresh,
                ),
              ],
            ),
            const UiGap.v(20),
          ],
          UiInput.search(
            value: query,
            hintText: 'Search news, symbols, sources',
            onChanged: (v) => setState(() => query = v),
          ),
          const UiGap.v(12),
          UiSelect<String>(
            value: filter,
            expand: true,
            onChanged: (v) => setState(() => filter = v),
            options: const [
              UiOption(value: 'all', label: 'All headlines'),
              UiOption(value: 'watchlist', label: 'My watchlist'),
              UiOption(value: 'saved', label: 'Saved stories'),
              UiOption(value: 'US', label: 'United States'),
              UiOption(value: 'IN', label: 'India'),
            ],
          ),
          const UiGap.v(12),
          Text(
            '${stories.length} stories · ${widget.symbol ?? 'Latest available snapshot'}',
            style: context.uiText.caption,
          ),
          const UiGap.v(12),
          if (store.loading && store.snapshot == null)
            ...List.generate(
              3,
              (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: UiSkeleton(height: 120),
              ),
            ),
          if (store.error != null)
            UiCallout(
              title: 'News unavailable',
              message: store.error!,
              intent: UiIntent.warning,
            ),
          if (!store.loading && stories.isEmpty)
            UiEmptyState(
              icon: Icons.newspaper_outlined,
              title: 'No stories here yet',
              message: 'Try another source, symbol or collection.',
            ),
          for (final story in stories)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(12)),
              child: AppNewsStoryCard(
                title: story.title,
                publisher: story.publisher,
                timestamp: marketDate(story.publishedAt),
                thumbnailUrl: story.thumbnailUrl,
                contentType: story.contentType,

                summary: story.summary,
                symbols: story.symbols,
                demo: story.demo,
                compact: widget.compact,
                saved: store.bookmarks.contains(story.id),
                onSave: () => store.toggleBookmark(story.id),
                onSymbol: widget.onOpenSymbol,
                onOpen: () => showMarketStory(
                  context,
                  story,
                  onOpenRef: widget.onOpenRef,
                  onOpenSymbol: widget.onOpenSymbol,
                ),
              ),
            ),
          SizedBox(height: context.uiPageBottomInset),
        ],
      );
    },
  );
}

Future<void> showMarketStory(
  BuildContext context,
  MarketStory story, {
  ValueChanged<AppLinkRef>? onOpenRef,
  ValueChanged<String>? onOpenSymbol,
}) => UiDrawer.show<void>(
  context,
  title: 'Research brief',
  child: _StoryReader(
    story: story,
    onOpenRef: onOpenRef,
    onOpenSymbol: onOpenSymbol,
  ),
);

class _StoryReader extends StatefulWidget {
  const _StoryReader({required this.story, this.onOpenRef, this.onOpenSymbol});
  final MarketStory story;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onOpenSymbol;
  @override
  State<_StoryReader> createState() => _StoryReaderState();
}

class _StoryReaderState extends State<_StoryReader> {
  bool saving = false;
  AppNote? created;

  Future<void> _saveNote() async {

    setState(() => saving = true);
    try {
      final story = widget.story;
      final now = DateTime.now();
      final content =
          '# ${story.title}\n\n${story.demo ? '> Demo research content\n\n' : ''}'
          '${story.summary}\n\nSource: ${story.publisher} · ${marketDate(story.publishedAt)}\n'
          '${story.url.isEmpty ? '' : '\n[Read original](${story.url})\n'}\n'
          '${story.symbols.map((s) => AppDeepLink.markdown(kind: AppLinkKind.ticker, id: s, label: s)).join(' · ')}\n\n'
          '## My thesis\n\nWhat changes for my setup?\n\n## Evidence to check\n\n- [ ] Verify the catalyst\n- [ ] Review price and volume\n- [ ] Define invalidation\n';
      final note = await NotesRepositoryScope.repository.create(
        AppNote(
          id: '',
          title: story.title,
          content: content,
          createdAt: now,
          updatedAt: now,
          linkedTickers: story.symbols,
          tags: const ['news', 'research'],
        ).withDerivedCounts(),
      );
      if (!mounted) return;
      setState(() => created = note);
      UiToast.success(
        context,
        title: 'Research note created',
        message: 'The source and ticker links are included.',
      );
    } catch (_) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Could not create note',
          message: 'Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final uri = Uri.tryParse(story.url);
    final canOpen =
        uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(story.publisher.toUpperCase(), style: uiOverline(context)),
        const UiGap.v(12),
        Text(story.title, style: context.uiText.heading),
        const UiGap.v(12),
        Text(
          '${marketDate(story.publishedAt)} · ${story.demo ? 'Demo story' : 'Publisher summary'}',
          style: context.uiText.caption,
        ),
        const UiGap.v(20),
        SelectableText(
          story.summary.isEmpty
              ? 'No summary supplied. Open the original article for the full story.'
              : story.summary,
          style: context.uiText.body.copyWith(height: 1.7),
        ),
        const UiGap.v(20),
        Wrap(
          spacing: context.sp(8),
          runSpacing: context.sp(8),
          children: [
            for (final symbol in story.symbols)
              UiBadge(
                label: symbol,
                onTap: widget.onOpenSymbol == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onOpenSymbol!(symbol);
                      },
              ),
          ],
        ),
        const UiGap.v(24),
        UiButton(
          label: saving
              ? 'Creating note…'
              : created == null
              ? 'Create research note'
              : 'Research note created',
          leadingIcon: Icons.note_add_outlined,
          expand: true,
          onPressed: saving || created != null
              ? null
              : _saveNote,
        ),
        if (canOpen) ...[
          const UiGap.v(10),
          UiButton(
            label: 'Read original article',
            variant: UiVariant.outline,
            leadingIcon: Icons.open_in_new_rounded,
            onPressed: () async {
              try {
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  UiToast.error(context, title: 'Could not open article');
                }
              } catch (_) {
                if (context.mounted) {
                  UiToast.error(context, title: 'Could not open article');
                }
              }
            },
          ),
          const UiGap.v(10),
          UiButton(
            label: 'Copy article link',
            variant: UiVariant.ghost,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: story.url));
              if (context.mounted) {
                UiToast.success(context, title: 'Article link copied');
              }
            },
          ),
        ],
      ],
    );
  }
}

/// Research content shared by the shell companion pane and floating drawer.
class ResearchRail extends StatefulWidget {
  const ResearchRail({
    super.key,
    this.onOpenSymbol,
    this.onOpenRef,
    this.onClose,
  });
  final VoidCallback? onClose;
  final ValueChanged<String>? onOpenSymbol;
  final ValueChanged<AppLinkRef>? onOpenRef;
  @override
  State<ResearchRail> createState() => _ResearchRailState();
}

class _ResearchRailState extends State<ResearchRail> {
  int tab = 0;
  final store = MarketWorkspaceStore.instance;
  @override
  void initState() {
    super.initState();
    store.initialize();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.ui.colors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(context.sp(12)),
          child: Row(
            children: [
              Expanded(
                child: Text('Research desk', style: context.uiText.subheading),
              ),
              UiIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh research',
                size: UiSize.sm,
                onPressed: store.refresh,
              ),
              if (widget.onClose != null)
                UiIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close research desk',
                  size: UiSize.sm,
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ),
        UiTabs(
          index: tab,
          onChanged: (v) => setState(() => tab = v),
          stretch: true,
          items: const [
            UiTabItem(label: 'Headlines', icon: Icons.newspaper_outlined),
            UiTabItem(label: 'Watchlist', icon: Icons.star_outline_rounded),
          ],
        ),
        Expanded(
          child: tab == 0
              ? NewsScreen(
                  compact: true,
                  onOpenSymbol: widget.onOpenSymbol,
                  onOpenRef: widget.onOpenRef,
                )
              : ListenableBuilder(
                  listenable: store,
                  builder: (context, _) => ListView(
                    padding: EdgeInsets.all(context.sp(12)),
                    children: [
                      UiSelect<String>(
                        value: store.activeList,
                        expand: true,
                        onChanged: store.selectList,
                        options: store.watchlists.keys
                            .map((name) => UiOption(value: name, label: name))
                            .toList(),
                      ),
                      const UiGap.v(12),
                      for (final symbol in store.watched)
                        for (final q
                            in (store.snapshot?.instruments ??
                                    <MarketInstrument>[])
                                .where((q) => q.symbol == symbol))
                          AppMarketQuoteTile(
                            symbol: q.symbol,
                            name: q.name,
                            price: q.priceLabel,
                            change: q.changeLabel,
                            positive: q.positive,
                            market: q.demo ? 'Demo' : q.currency,
                            onTap: widget.onOpenSymbol == null
                                ? null
                                : () => widget.onOpenSymbol!(q.symbol),
                          ),
                      if (store.watched.isEmpty)
                        const UiEmptyState(
                          title: 'A fresh watchlist',
                          message: 'Add symbols from Markets.',
                        ),
                      const UiGap.v(16),
                      Text(
                        'Daily snapshots · Prices may be delayed',
                        style: context.uiText.caption,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
