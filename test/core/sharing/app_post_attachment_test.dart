import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/linking/link_graph.dart';

void main() {
  final DateTime now = DateTime(2026, 9, 9);
  final AppNote note = AppNote(
    id: 'note-1',
    title: 'Opening range notes',
    content: '## Rule\nWait for the **retest** before entry.',
    createdAt: now,
    updatedAt: now,
    isPublic: true,
    tags: const <String>['opening-range'],
  );
  final AppTrade journal = AppTrade(
    id: 'journal-1',
    ticker: 'NIFTY',
    side: AppSide.long,
    entry: 100,
    exit: 104,
    openedAt: now,
    closedAt: now,
    outcome: AppOutcome.win,
    title: 'NIFTY retest',
    content: 'Stayed patient.',
  );
  final AppStrategy strategy = AppStrategy(
    id: 'strategy-1',
    name: 'Opening range breakout',
    content: 'Trade the first clean retest.',
    updatedAt: now,
    isPublic: true,
  );
  final AppLinkGraph graph = AppLinkGraph(
    notes: <AppNote>[note],
    journal: <AppTrade>[journal],
    strategies: <AppStrategy>[strategy],
  );
  final AppWritingPostAttachmentCatalog catalog =
      AppWritingPostAttachmentCatalog(graph);

  test('resolves every Writing Desk source but never a ticker', () {
    expect(catalog.resolve(AppLinkKind.note, note.id)?.sourceId, note.id);
    expect(
      catalog.resolve(AppLinkKind.journal, journal.id)?.sourceId,
      journal.id,
    );
    expect(
      catalog.resolve(AppLinkKind.strategy, strategy.id)?.sourceId,
      strategy.id,
    );
    expect(catalog.resolve(AppLinkKind.ticker, 'NIFTY'), isNull);
  });

  test('marks private records before a public post can accept them', () {
    final AppWritingPostAttachment attachment =
        AppWritingPostAttachment.journal(journal);

    expect(attachment.isPublic, isFalse);
    expect(attachment.requiresPublication, isTrue);
  });

  test('a post exposes one dedicated Writing Desk attachment slot', () {
    final AppWritingPostAttachment attachment = AppWritingPostAttachment.note(
      note,
    );
    final AppPost post = AppPost(
      id: 'post-1',
      author: const AppTrader(id: 'user-1', handle: 'trader'),
      body: 'The retest mattered more than the breakout.',
      createdAt: now,
      writingAttachment: attachment,
    );

    expect(post.writingAttachment, same(attachment));
    expect(post.attachments, isEmpty);
  });

  test('public-only search returns one-source attachment candidates', () {
    final List<AppWritingPostAttachment> results = catalog.search(
      query: 'opening',
      publicOnly: true,
    );

    expect(results.map((item) => item.kind), <AppLinkKind>[
      AppLinkKind.note,
      AppLinkKind.strategy,
    ]);
    expect(results.every((item) => item.isPublic), isTrue);
  });

  test('preview strips markdown rather than leaking raw editor syntax', () {
    final AppWritingPostAttachment attachment = AppWritingPostAttachment.note(
      note,
    );

    expect(attachment.excerpt, contains('Wait for the retest'));
    expect(attachment.excerpt, isNot(contains('**')));
    expect(attachment.excerpt, isNot(contains('##')));
  });
}
