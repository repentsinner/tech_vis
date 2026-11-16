import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/vectors.dart';

final _viewport = vm.Vector2(1280, 720);

const _stops = [
  ColorRampStop(position: 0, key: 'cold'),
  ColorRampStop(position: 0.5, key: 'mild'),
  ColorRampStop(position: 1, key: 'hot'),
];

const _numbers = NumberFormatting();

const _wideBottomLeft = ViewportOverlayPlacement(
  corner: ViewportCorner.bottomLeft,
  offsetXPixels: 16,
  offsetYPixels: 16,
  widthPixels: 200,
  heightPixels: 40,
);

typedef _Case = ({
  String name,
  double minValue,
  double maxValue,
  ColorRampOrientation orientation,
  ViewportOverlayPlacement? placement,
  double? tickInterval,
  String? unit,
  NumberFormatting numbers,
  List<double> barRect,
  double interval,
  List<double> values,
  List<String> labels,
  List<double> firstAnchor,
  List<double> alignment,
});

/// The default placement resolves to (1216, 504, 1264, 704) in a 1280 x 720
/// viewport, so the vertical bar stands 200 px tall on its right edge.
final _cases = <_Case>[
  (
    name: 'default vertical legend snaps 0 to 100 to steps of 20',
    minValue: 0,
    maxValue: 100,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: null,
    unit: '°C',
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 20,
    values: [0, 20, 40, 60, 80, 100],
    labels: ['0 °C', '20', '40', '60', '80', '100 °C'],
    firstAnchor: [1248, 704],
    alignment: [1, 0.5],
  ),
  (
    name: 'a range off the interval ticks only its multiples',
    minValue: -12.5,
    maxValue: 37.5,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: null,
    unit: 'm/s',
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 10,
    values: [-10, 0, 10, 20, 30],
    labels: ['-10 m/s', '0', '10', '20', '30 m/s'],
    firstAnchor: [1248, 694],
    alignment: [1, 0.5],
  ),
  (
    name: 'an app interval replaces the automatic one',
    minValue: 0,
    maxValue: 100,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: 25,
    unit: null,
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 25,
    values: [0, 25, 50, 75, 100],
    labels: ['0', '25', '50', '75', '100'],
    firstAnchor: [1248, 704],
    alignment: [1, 0.5],
  ),
  (
    name: 'fractional values share the interval decimals',
    minValue: 0,
    maxValue: 1,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: null,
    unit: null,
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 0.2,
    values: [0, 0.2, 0.4, 0.6000000000000001, 0.8, 1],
    labels: ['0', '0.2', '0.4', '0.6', '0.8', '1'],
    firstAnchor: [1248, 704],
    alignment: [1, 0.5],
  ),
  (
    name: 'comma and no leading zero',
    minValue: 0,
    maxValue: 1,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: null,
    unit: null,
    numbers: const NumberFormatting(
      decimalMarker: DecimalMarker.comma,
      showLeadingZero: false,
    ),
    barRect: [1252, 504, 1264, 704],
    interval: 0.2,
    values: [0, 0.2, 0.4, 0.6000000000000001, 0.8, 1],
    labels: ['0', ',2', ',4', ',6', ',8', '1'],
    firstAnchor: [1248, 704],
    alignment: [1, 0.5],
  ),
  (
    name: 'a range end just short of a multiple keeps its tick',
    minValue: 0,
    maxValue: 0.3,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: 0.1,
    unit: null,
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 0.1,
    values: [0, 0.1, 0.2, 0.30000000000000004],
    labels: ['0', '0.1', '0.2', '0.3'],
    firstAnchor: [1248, 704],
    alignment: [1, 0.5],
  ),
  (
    name: 'an interval longer than the range leaves no ticks',
    minValue: 0.1,
    maxValue: 0.9,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: 1,
    unit: 'K',
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 1,
    values: [],
    labels: [],
    firstAnchor: [],
    alignment: [1, 0.5],
  ),
  (
    name: 'a lone tick carries the unit once',
    minValue: 15,
    maxValue: 35,
    orientation: ColorRampOrientation.vertical,
    placement: null,
    tickInterval: 20,
    unit: 'kPa',
    numbers: _numbers,
    barRect: [1252, 504, 1264, 704],
    interval: 20,
    values: [20],
    labels: ['20 kPa'],
    firstAnchor: [1248, 654],
    alignment: [1, 0.5],
  ),
  (
    name: 'vertical in a left corner labels the bar right side',
    minValue: 0,
    maxValue: 100,
    orientation: ColorRampOrientation.vertical,
    placement: ViewportOverlayPlacement.of(
      ViewportOverlayKind.colorRampLegend,
      corner: ViewportCorner.topLeft,
    ),
    tickInterval: null,
    unit: null,
    numbers: _numbers,
    barRect: [16, 16, 28, 216],
    interval: 20,
    values: [0, 20, 40, 60, 80, 100],
    labels: ['0', '20', '40', '60', '80', '100'],
    firstAnchor: [32, 216],
    alignment: [0, 0.5],
  ),
  (
    name: 'horizontal in a bottom corner labels above the bar',
    minValue: 0,
    maxValue: 100,
    orientation: ColorRampOrientation.horizontal,
    placement: _wideBottomLeft,
    tickInterval: null,
    unit: '%',
    numbers: _numbers,
    barRect: [16, 692, 216, 704],
    interval: 20,
    values: [0, 20, 40, 60, 80, 100],
    labels: ['0 %', '20', '40', '60', '80', '100 %'],
    firstAnchor: [16, 688],
    alignment: [0.5, 0],
  ),
  (
    name: 'horizontal in a top corner labels below the bar',
    minValue: 0,
    maxValue: 100,
    orientation: ColorRampOrientation.horizontal,
    placement: ViewportOverlayPlacement.of(
      ViewportOverlayKind.colorRampLegend,
      corner: ViewportCorner.topRight,
      widthPixels: 200,
      heightPixels: 40,
    ),
    tickInterval: null,
    unit: null,
    numbers: _numbers,
    barRect: [1064, 16, 1264, 28],
    interval: 20,
    values: [0, 20, 40, 60, 80, 100],
    labels: ['0', '20', '40', '60', '80', '100'],
    firstAnchor: [1064, 32],
    alignment: [0.5, 1],
  ),
];

ColorRampLegendLayout _legend({
  double minValue = 0,
  double maxValue = 100,
  List<ColorRampStop> stops = _stops,
  ViewportOverlayPlacement? placement,
  double? tickInterval,
  double minTickSpacingPixels = StyleTokens.colorRampLegendMinTickSpacingPixels,
}) => ColorRampLegendLayout.forRange(
  minValue: minValue,
  maxValue: maxValue,
  stops: stops,
  viewportSize: _viewport,
  placement: placement,
  tickInterval: tickInterval,
  minTickSpacingPixels: minTickSpacingPixels,
);

void main() {
  group('ColorRampLegendLayout.forRange', () {
    for (final c in _cases) {
      test(c.name, () {
        final legend = ColorRampLegendLayout.forRange(
          minValue: c.minValue,
          maxValue: c.maxValue,
          stops: _stops,
          viewportSize: _viewport,
          orientation: c.orientation,
          placement: c.placement,
          tickInterval: c.tickInterval,
          unit: c.unit,
          numbers: c.numbers,
        );
        final bar = legend.barRect;
        expectNumbers(
          [bar.left, bar.top, bar.right, bar.bottom],
          c.barRect,
          'barRect',
        );
        expect(legend.orientation, c.orientation);
        expect(legend.tickInterval, closeTo(c.interval, vectorTolerance));
        expectNumbers(
          [for (final t in legend.ticks) t.value],
          c.values,
          'values',
        );
        expect([for (final t in legend.ticks) t.label.text], c.labels);
        expectNumbers(legend.labelAlignment.storage, c.alignment, 'alignment');
        if (legend.ticks.isNotEmpty) {
          final first = legend.ticks.first.labelAnchor;
          expectNumbers([first.x, first.y], c.firstAnchor, 'first anchor');
        }
      });
    }

    test('a tick position runs from the minimum end of the bar', () {
      final legend = _legend(minValue: -12.5, maxValue: 37.5);
      expectNumbers(
        [for (final t in legend.ticks) t.position],
        [0.05, 0.25, 0.45, 0.65, 0.85],
        'positions',
      );
      expectNumbers(
        [for (final t in legend.ticks) t.labelAnchor.y],
        [694, 654, 614, 574, 534],
        'anchor ys',
      );
    });

    test('a range end inside the slack clamps its tick to the bar', () {
      final legend = _legend(maxValue: 0.3, tickInterval: 0.1);
      expect(legend.ticks.last.position, 1);
    });

    test('the automatic interval keeps ticks the minimum spacing apart', () {
      for (final (spacing, interval) in const [
        (32.0, 20.0),
        (40.0, 20.0),
        (41.0, 50.0),
        (100.0, 50.0),
        (101.0, 100.0),
        (8.0, 5.0),
      ]) {
        expect(
          _legend(minTickSpacingPixels: spacing).tickInterval,
          interval,
          reason: '$spacing px',
        );
      }
    });

    test('labels request the label height token', () {
      for (final t in _legend().ticks) {
        expect(
          t.label.heightPixels,
          StyleTokens.colorRampLegendLabelHeightPixels,
        );
      }
    });

    test('the rect is the placement rect', () {
      final rect = _legend().rect;
      expect(
        [rect.left, rect.top, rect.right, rect.bottom],
        [1216, 504, 1264, 704],
      );
    });

    test('passes the stops and their keys through in order', () {
      final legend = _legend();
      expect(legend.stops, _stops);
      expect(
        () => legend.stops.add(const ColorRampStop(position: 1, key: 'x')),
        throwsUnsupportedError,
      );
    });

    test('equal neighboring stops make a hard edge', () {
      const stops = [
        ColorRampStop(position: 0, key: 'low'),
        ColorRampStop(position: 0.5, key: 'low'),
        ColorRampStop(position: 0.5, key: 'high'),
        ColorRampStop(position: 1, key: 'high'),
      ];
      expect(_legend(stops: stops).stops, stops);
    });

    for (final (name, build) in <(String, ColorRampLegendLayout Function())>[
      ('an empty range', () => _legend(minValue: 5, maxValue: 5)),
      ('a reversed range', () => _legend(minValue: 10, maxValue: 0)),
      ('a non-finite range', () => _legend(maxValue: double.infinity)),
      ('a NaN range', () => _legend(minValue: double.nan)),
      (
        'one stop',
        () => _legend(stops: const [ColorRampStop(position: 0, key: 'a')]),
      ),
      (
        'stops that start past 0',
        () => _legend(
          stops: const [
            ColorRampStop(position: 0.1, key: 'a'),
            ColorRampStop(position: 1, key: 'b'),
          ],
        ),
      ),
      (
        'stops that end short of 1',
        () => _legend(
          stops: const [
            ColorRampStop(position: 0, key: 'a'),
            ColorRampStop(position: 0.9, key: 'b'),
          ],
        ),
      ),
      (
        'descending stops',
        () => _legend(
          stops: const [
            ColorRampStop(position: 0, key: 'a'),
            ColorRampStop(position: 0.6, key: 'b'),
            ColorRampStop(position: 0.4, key: 'c'),
            ColorRampStop(position: 1, key: 'd'),
          ],
        ),
      ),
      ('a zero interval', () => _legend(tickInterval: 0)),
      ('a NaN interval', () => _legend(tickInterval: double.nan)),
      ('a zero tick spacing', () => _legend(minTickSpacingPixels: 0)),
      (
        'a bar with no length',
        () => _legend(
          placement: ViewportOverlayPlacement.of(
            ViewportOverlayKind.colorRampLegend,
            heightPixels: 0,
          ),
        ),
      ),
    ]) {
      test('rejects $name', () {
        expect(build, throwsArgumentError);
      });
    }
  });

  group('formatNumberLabel', () {
    for (final (value, step, numbers, label) in const [
      (45.0, 1.0, _numbers, '45'),
      (0.25, 0.05, _numbers, '0.25'),
      (12.345, 0.01, _numbers, '12.35'),
      (-0.04, 0.1, _numbers, '0'),
      (7.0, 5.0, _numbers, '5'),
      (
        0.5,
        0.1,
        NumberFormatting(
          decimalMarker: DecimalMarker.comma,
          showLeadingZero: false,
        ),
        ',5',
      ),
    ]) {
      test('writes $value at step $step as $label', () {
        expect(formatNumberLabel(value, step: step, numbers: numbers), label);
      });
    }

    test('rejects a step that is not positive', () {
      expect(() => formatNumberLabel(1, step: 0), throwsArgumentError);
    });
  });
}
