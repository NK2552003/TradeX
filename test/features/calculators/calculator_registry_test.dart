import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/calculators/calculator_registry.dart';

void main() {
  group('kAllCalculators', () {
    test('lists 22 calculators', () {
      expect(kAllCalculators, hasLength(22));
    });

    test('ids are unique', () {
      final Set<String> ids = kAllCalculators
          .map((AppCalculatorMeta m) => m.id)
          .toSet();
      expect(ids, hasLength(kAllCalculators.length));
    });

    test('every entry is presentable', () {
      for (final AppCalculatorMeta m in kAllCalculators) {
        expect(m.id.trim(), isNotEmpty, reason: 'id');
        expect(m.name.trim(), isNotEmpty, reason: '${m.id} name');
        expect(m.description.trim(), isNotEmpty, reason: '${m.id} description');
        expect(m.tags, isNotEmpty, reason: '${m.id} tags');
        // The card shows at most three tags; more is dead weight in the model.
        expect(m.tags.length, lessThanOrEqualTo(6), reason: '${m.id} tags');
      }
    });

    test('ids are snake_case so they can key a switch and a URL alike', () {
      final RegExp snake = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final AppCalculatorMeta m in kAllCalculators) {
        expect(snake.hasMatch(m.id), isTrue, reason: m.id);
      }
    });

    test('every category is represented and grouped contiguously', () {
      final List<AppCalculatorCategory> order = kAllCalculators
          .map((AppCalculatorMeta m) => m.category)
          .toList();

      for (final AppCalculatorCategory c in AppCalculatorCategory.values) {
        expect(order, contains(c), reason: c.name);
        final int first = order.indexOf(c);
        final int last = order.lastIndexOf(c);
        expect(
          order.sublist(first, last + 1).every((AppCalculatorCategory x) => x == c),
          isTrue,
          reason: '${c.name} entries are interleaved with another category',
        );
      }
    });

    test('the trading category carries the most tools', () {
      final int trading = kAllCalculators
          .where(
            (AppCalculatorMeta m) =>
                m.category == AppCalculatorCategory.trading,
          )
          .length;
      expect(trading, 7);
    });
  });

  group('calculatorMetaById', () {
    test('finds every registered id', () {
      for (final AppCalculatorMeta m in kAllCalculators) {
        expect(calculatorMetaById(m.id).name, m.name);
      }
    });

    test('throws on an unknown id rather than returning a placeholder', () {
      expect(() => calculatorMetaById('nope'), throwsStateError);
    });
  });

  group('AppCalculatorCategory', () {
    test('each category has a label, an icon and an intent', () {
      for (final AppCalculatorCategory c in AppCalculatorCategory.values) {
        expect(c.label.trim(), isNotEmpty, reason: c.name);
        expect(c.icon, isNotNull, reason: c.name);
        expect(c.intent, isNotNull, reason: c.name);
      }
    });

    test('labels are unique so the filter chips never read the same', () {
      final Set<String> labels = AppCalculatorCategory.values
          .map((AppCalculatorCategory c) => c.label)
          .toSet();
      expect(labels, hasLength(AppCalculatorCategory.values.length));
    });
  });
}
