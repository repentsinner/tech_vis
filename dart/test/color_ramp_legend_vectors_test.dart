import 'dart:convert';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

final _fixture = vectorFixture('color_ramp_legend.json');

ColorRampStop _stop(Json s) =>
    ColorRampStop(position: jsonNumber(s['position']), key: s['key']);

void main() {
  final skip = skipUnlessPresent(_fixture);

  group('color-ramp-legend golden vectors', () {
    late Json fixture;

    setUpAll(() {
      fixture = jsonDecode(_fixture.readAsStringSync()) as Json;
    });

    test('are generated from the current style version', () {
      expect(fixture['styleVersion'], StyleTokens.styleVersion);
    });

    test('ColorRampLegendLayout.forRange', () {
      final cases = jsonList(fixture['ColorRampLegendLayout.forRange']);
      expect(cases, isNotEmpty);
      for (final c in cases) {
        final name = c['name'] as String;
        final input = c['input'] as Json;
        final interval = input['tickInterval'];
        final legend = ColorRampLegendLayout.forRange(
          minValue: jsonNumber(input['minValue']),
          maxValue: jsonNumber(input['maxValue']),
          stops: [for (final s in jsonList(input['stops'])) _stop(s)],
          viewportSize: jsonVector2(input['viewport']),
          orientation: ColorRampOrientation.values.byName(
            input['orientation'] as String,
          ),
          placement: jsonPlacement(input['placement']),
          tickInterval: interval == null ? null : jsonNumber(interval),
          unit: input['unit'] as String?,
          numbers: jsonNumberFormatting(input['numbers']),
          barThicknessPixels: jsonNumber(input['barThicknessPixels']),
          minTickSpacingPixels: jsonNumber(input['minTickSpacingPixels']),
          labelGapPixels: jsonNumber(input['labelGapPixels']),
          labelHeightPixels: jsonNumber(input['labelHeightPixels']),
        );
        final want = c['output'] as Json;
        final ViewportRect(:left, :top, :right, :bottom) = legend.rect;
        expectNumbers([left, top, right, bottom], want['rect'], '$name rect');
        final bar = legend.barRect;
        expectNumbers(
          [bar.left, bar.top, bar.right, bar.bottom],
          want['barRect'],
          '$name barRect',
        );
        expect(legend.orientation.name, want['orientation'], reason: name);
        final stops = jsonList(want['stops']);
        expect(legend.stops, [for (final s in stops) _stop(s)], reason: name);
        expect(
          legend.tickInterval,
          closeTo(jsonNumber(want['tickInterval']), vectorTolerance),
          reason: '$name tickInterval',
        );
        expectNumbers(
          legend.labelAlignment.storage,
          want['labelAlignment'],
          '$name labelAlignment',
        );
        final ticks = jsonList(want['ticks']);
        expect(legend.ticks, hasLength(ticks.length), reason: '$name ticks');
        for (var i = 0; i < ticks.length; i++) {
          final tick = legend.ticks[i];
          final t = ticks[i];
          final label = t['label'] as Json;
          expectNumbers(
            [tick.value, tick.position, tick.label.heightPixels],
            [t['value'], t['position'], label['heightPixels']],
            '$name tick $i value, position, label height',
          );
          expect(tick.label.text, label['text'], reason: '$name tick $i');
          expectNumbers(
            tick.labelAnchor.storage,
            t['labelAnchor'],
            '$name tick $i labelAnchor',
          );
        }
      }
    });
  }, skip: skip);
}
