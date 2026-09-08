import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';

AppNote note(String id, String body) => AppNote(
  id: id,
  title: id,
  content: body,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('note-to-note links create backlinks and survive title edits', () {
    final a = note(
      'a',
      '[My thesis](tradex://note/b) and [AAPL](tradex://ticker/AAPL)',
    );
    final b = note('b', '').copyWith(title: 'Renamed thesis');
    final graph = AppLinkGraph(notes: [a, b]);
    expect(graph.bundleForNote(a).notes.single.title, 'Renamed thesis');
    expect(graph.bundleForNote(b).notes.single.id, 'a');
    expect(graph.bundleForTicker('AAPL').notes.single.id, 'a');
  });

  test(
    'examples in code never produce links; duplicates and self links disappear',
    () {
      final a = note(
        'a',
        '`[example](tradex://note/b)`\n\n'
            '```md\n[example](tradex://note/b)\n```\n\n'
            '[self](tradex://note/a)\n[x](tradex://note/c) [again](tradex://note/c)',
      );
      final graph = AppLinkGraph(notes: [a, note('b', ''), note('c', '')]);
      expect(graph.bundleForNote(a).notes.map((r) => r.id), ['c']);
      expect(graph.bundleForNote(graph.note('b')!).isEmpty, isTrue);
    },
  );

  test(
    'deleting target keeps a visible broken link and editing removes backlink',
    () {
      final a = note('a', '[deleted](tradex://note/missing)');
      expect(
        AppLinkGraph(notes: [a]).bundleForNote(a).notes.single.missing,
        isTrue,
      );
      final b = note('b', '');
      final graph = AppLinkGraph(
        notes: [
          a.copyWith(content: ''),
          b,
        ],
      );
      expect(graph.bundleForNote(b).isEmpty, isTrue);
    },
  );
}
