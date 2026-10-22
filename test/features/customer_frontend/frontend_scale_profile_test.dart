import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';

void main() {
  test('profile graph rebuilds and Markdown extraction at increasing sizes', () {
    for (final count in [100, 1000, 5000]) {
      final notes = List.generate(
        count,
        (index) => AppNote(
          id: 'n$index',
          title: 'Note $index',
          content:
              '## Trade plan\nLinked [next](tradex://note/n${(index + 1) % count}) and \$AAPL.\n',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final clock = Stopwatch()..start();
      final graph = AppLinkGraph(notes: notes);
      final buildMicros = clock.elapsedMicroseconds;
      expect(
        graph.hasInlineConnection(
          AppLinkKind.note,
          'n0',
          AppLinkKind.note,
          'n1',
        ),
        isTrue,
      );
      final indexMicros = clock.elapsedMicroseconds - buildMicros;
      clock.reset();
      expect(
        graph.hasInlineConnection(
          AppLinkKind.note,
          'n0',
          AppLinkKind.ticker,
          'AAPL',
        ),
        isTrue,
      );
      final repeatedClock = Stopwatch()..start();
      final repeated = AppLinkGraph(notes: notes);
      expect(
        repeated.hasInlineConnection(
          AppLinkKind.note,
          'n0',
          AppLinkKind.note,
          'n1',
        ),
        isTrue,
      );
      final repeatMicros = repeatedClock.elapsedMicroseconds;
      // Report measurements without machine-dependent timing assertions.
      // ignore: avoid_print
      print(
        'PROFILE graph records=$count construct_us=$buildMicros first_index_us=$indexMicros rebuild_index_us=$repeatMicros',
      );
    }
    final original = AppNote(
      id: 'source',
      title: 'Source',
      content: '[old](tradex://note/old)',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final before = AppLinkGraph(notes: [original]);
    expect(
      before.hasInlineConnection(
        AppLinkKind.note,
        'source',
        AppLinkKind.note,
        'old',
      ),
      isTrue,
    );
    final after = AppLinkGraph(
      notes: [original.copyWith(content: '[new](tradex://note/new)')],
    );
    expect(
      after.hasInlineConnection(
        AppLinkKind.note,
        'source',
        AppLinkKind.note,
        'old',
      ),
      isFalse,
    );
    expect(
      after.hasInlineConnection(
        AppLinkKind.note,
        'source',
        AppLinkKind.note,
        'new',
      ),
      isTrue,
    );
    expect(
      before.hasInlineConnection(
        AppLinkKind.note,
        'source',
        AppLinkKind.note,
        'old',
      ),
      isTrue,
    );
    final document = List.filled(
      5000,
      '## Research\n- [x] Reviewed \$AAPL [thesis](tradex://note/plan)\n',
    ).join();
    final clock = Stopwatch()..start();
    final stats = AppMarkdownStats.of(document);
    final excerpt = AppMarkdownStats.excerpt(document);
    expect(stats.checklistDone, 5000);
    expect(excerpt, isNotEmpty);
    // ignore: avoid_print
    print(
      'PROFILE markdown chars=${document.length} stats_excerpt_us=${clock.elapsedMicroseconds}',
    );
  });
}
