import 'dart:convert';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

final _fixture = vectorFixture('viewport_overlays.json');

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('viewport-overlay golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('ViewportOverlayPlacement.of', () {
      final cases = jsonList(fixture['ViewportOverlayPlacement.of']);
      expect(
        cases.map((c) => (c['input'] as Json)['kind']).toSet(),
        ViewportOverlayKind.values.map((k) => k.name).toSet(),
      );
      for (final c in cases) {
        final kind = ViewportOverlayKind.values.byName(
          (c['input'] as Json)['kind'] as String,
        );
        expect(
          ViewportOverlayPlacement.of(kind),
          jsonPlacement(c['output']),
          reason: c['name'] as String,
        );
      }
    });

    test('ViewportOverlayPlacement.rect', () {
      final cases = jsonList(fixture['ViewportOverlayPlacement.rect']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final input = c['input'] as Json;
        final rect = jsonPlacement(
          input['placement'],
        ).rect(jsonVector2(input['viewport']));
        expectNumbers(
          [rect.left, rect.top, rect.right, rect.bottom],
          (c['output'] as Json)['rect'],
          c['name'] as String,
        );
      }
    });
  }, skip: skip);
}
