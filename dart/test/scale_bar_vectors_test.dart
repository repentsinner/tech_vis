import 'dart:convert';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

final _fixture = vectorFixture('scale_bar.json');

ViewportOverlayPlacement _placement(Object? json) {
  final p = json! as Json;
  return ViewportOverlayPlacement(
    corner: ViewportCorner.values.byName(p['corner'] as String),
    offsetXPixels: jsonNumber(p['offsetXPixels']),
    offsetYPixels: jsonNumber(p['offsetYPixels']),
    widthPixels: jsonNumber(p['widthPixels']),
    heightPixels: jsonNumber(p['heightPixels']),
  );
}

CameraBasis _camera(Object? json) {
  final c = json! as Json;
  return CameraBasis(
    position: jsonVector3(c['position']),
    forward: jsonVector3(c['forward']),
    right: jsonVector3(c['right']),
    up: jsonVector3(c['up']),
  );
}

NumberFormatting _numbers(Object? json) {
  final n = json! as Json;
  return NumberFormatting(
    decimalMarker: DecimalMarker.values.byName(n['decimalMarker'] as String),
    showLeadingZero: n['showLeadingZero'] as bool,
  );
}

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('scale-bar golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('ScaleBarLayout.atTarget', () {
      final cases = jsonList(fixture['ScaleBarLayout.atTarget']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final name = c['name'] as String;
        final input = c['input'] as Json;
        final previous = input['previousStep'];
        final bar = ScaleBarLayout.atTarget(
          camera: _camera(input['camera']),
          target: jsonVector3(input['target']),
          verticalFovRadians: jsonNumber(input['verticalFovRadians']),
          viewportSize: jsonVector2(input['viewport']),
          worldUnits: UnitSystem.values.byName(input['worldUnits'] as String),
          format: DisplayFormat.values.byName(input['format'] as String),
          placement: _placement(input['placement']),
          previousStep: previous == null ? null : jsonNumber(previous),
          numbers: _numbers(input['numbers']),
          minTickSpacingPixels: jsonNumber(input['minTickSpacingPixels']),
          hysteresis: jsonNumber(input['hysteresis']),
          labelHeightPixels: jsonNumber(input['labelHeightPixels']),
        );
        final want = c['output'] as Json?;
        if (want == null) {
          expect(bar, isNull, reason: name);
          continue;
        }
        expect(bar, isNotNull, reason: name);
        bar!;
        expectNumbers(
          [bar.rect.left, bar.rect.top, bar.rect.right, bar.rect.bottom],
          want['rect'],
          '$name rect',
        );
        expectNumbers(
          [bar.step, bar.tickStep, bar.startX, bar.endX, bar.baselineY],
          [
            want['step'],
            want['tickStep'],
            want['startX'],
            want['endX'],
            want['baselineY'],
          ],
          '$name step, tickStep, startX, endX, baselineY',
        );
        expectNumbers(bar.tickXs, want['tickXs'], '$name tickXs');
        final label = want['label'] as Json;
        expect(bar.label.text, label['text'], reason: '$name label');
        expect(
          bar.label.heightPixels,
          closeTo(jsonNumber(label['heightPixels']), vectorTolerance),
          reason: '$name label height',
        );
        expectNumbers(
          [bar.labelAnchor.x, bar.labelAnchor.y],
          want['labelAnchor'],
          '$name labelAnchor',
        );
      }
    });
  }, skip: skip);
}
