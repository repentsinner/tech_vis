import 'dart:convert';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

final _fixture = vectorFixture('unit_formats.json');

/// Expects [query] to return each recorded step, per format and length.
void _expectSteps(
  Object? recorded,
  double? Function(DisplayFormat format, double length) query,
) {
  final byFormat = recorded! as Json;
  expect(
    byFormat.keys.toSet(),
    DisplayFormat.values.map((f) => f.name).toSet(),
  );
  for (final MapEntry(key: name, value: cases) in byFormat.entries) {
    final format = DisplayFormat.values.byName(name);
    for (final c in jsonList(cases)) {
      final length = jsonNumber(c['length']);
      final actual = query(format, length);
      final reason = '$name at $length';
      if (c['step'] == null) {
        expect(actual, isNull, reason: reason);
      } else {
        expect(
          actual,
          closeTo(jsonNumber(c['step']), vectorTolerance),
          reason: reason,
        );
      }
    }
  }
}

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('unit format golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('scaleBarStepAtMost', () {
      _expectSteps(
        fixture['scaleBarStepAtMost'],
        (f, length) => f.scaleBarStepAtMost(length),
      );
    });

    test('gridStepAtLeast', () {
      _expectSteps(
        fixture['gridStepAtLeast'],
        (f, length) => f.gridStepAtLeast(length),
      );
    });

    test('gridStepAbove', () {
      _expectSteps(
        fixture['gridStepAbove'],
        (f, length) => f.gridStepAbove(length),
      );
    });

    test('formatLabels', () {
      final cases = jsonList(fixture['formatLabels']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final input = c['input'] as Json;
        final numbers = input['numbers'] as Json;
        final step = input['step'];
        expect(
          DisplayFormat.values
              .byName(input['format'] as String)
              .formatLabels(
                jsonNumbers(input['values']),
                step: step == null ? null : jsonNumber(step),
                numbers: NumberFormatting(
                  decimalMarker: DecimalMarker.values.byName(
                    numbers['decimalMarker'] as String,
                  ),
                  showLeadingZero: numbers['showLeadingZero'] as bool,
                ),
              ),
          (c['output'] as Json)['labels'],
          reason: c['name'] as String,
        );
      }
    });
  }, skip: skip);
}
