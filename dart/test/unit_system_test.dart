import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';

const _tolerance = 1e-9;

const _metric = DisplayFormat.metric;
const _decimalInch = DisplayFormat.decimalInch;
const _fractionalInch = DisplayFormat.fractionalInch;

const _noLeadingZero = NumberFormatting(showLeadingZero: false);
const _comma = NumberFormatting(decimalMarker: DecimalMarker.comma);

/// A step query: the format, the requested length in its base unit, and
/// the step expected back.
typedef _StepCase = ({DisplayFormat format, double length, double? step});

typedef _LabelCase = ({
  String name,
  DisplayFormat format,
  List<double> values,
  double? step,
  NumberFormatting numbers,
  List<String> labels,
});

_LabelCase _labels(
  String name,
  DisplayFormat format,
  List<double> values,
  List<String> labels, {
  double? step,
  NumberFormatting numbers = const NumberFormatting(),
}) => (
  name: name,
  format: format,
  values: values,
  step: step,
  numbers: numbers,
  labels: labels,
);

void _expectSteps(
  List<_StepCase> cases,
  double? Function(DisplayFormat format, double length) query,
) {
  for (final (:format, :length, :step) in cases) {
    final reason = '${format.name} at $length';
    final actual = query(format, length);
    if (step == null) {
      expect(actual, isNull, reason: reason);
    } else {
      expect(actual, closeTo(step, _tolerance), reason: reason);
    }
  }
}

void main() {
  group('UnitSystem', () {
    test('metric and imperial are the two variants', () {
      expect(UnitSystem.values, [UnitSystem.metric, UnitSystem.imperial]);
    });

    test('names its base unit', () {
      expect(UnitSystem.metric.abbreviation, 'mm');
      expect(UnitSystem.imperial.abbreviation, 'in');
      expect(UnitSystem.metric.baseUnit, 'mm');
      expect(UnitSystem.imperial.baseUnit, 'in');
      expect(UnitSystem.metric.label, 'Metric (mm)');
      expect(UnitSystem.imperial.label, 'Imperial (in)');
    });

    test('converts between systems', () {
      final cases = [
        (
          from: UnitSystem.metric,
          value: 25.4,
          to: UnitSystem.imperial,
          want: 1.0,
        ),
        (
          from: UnitSystem.imperial,
          value: 1.0,
          to: UnitSystem.metric,
          want: 25.4,
        ),
        (
          from: UnitSystem.metric,
          value: -25.4,
          to: UnitSystem.imperial,
          want: -1.0,
        ),
        (
          from: UnitSystem.metric,
          value: 42.0,
          to: UnitSystem.metric,
          want: 42.0,
        ),
        (
          from: UnitSystem.imperial,
          value: 0.0,
          to: UnitSystem.metric,
          want: 0.0,
        ),
      ];
      for (final (:from, :value, :to, :want) in cases) {
        expect(
          from.convertTo(value, to),
          closeTo(want, _tolerance),
          reason: '$value ${from.abbreviation} to ${to.abbreviation}',
        );
      }
    });
  });

  group('DisplayFormat', () {
    test('metric, decimal inch, and fractional inch are the formats', () {
      expect(DisplayFormat.values, [_metric, _decimalInch, _fractionalInch]);
    });

    test('measures in its unit system', () {
      expect(_metric.unitSystem, UnitSystem.metric);
      expect(_decimalInch.unitSystem, UnitSystem.imperial);
      expect(_fractionalInch.unitSystem, UnitSystem.imperial);
    });

    test('scaleBarStepAtMost returns the largest step that fits', () {
      _expectSteps([
        for (final format in [_metric, _decimalInch]) ...[
          (format: format, length: 7, step: 5),
          (format: format, length: 10, step: 10),
          (format: format, length: 19.99, step: 10),
          (format: format, length: 2000, step: 2000),
          (format: format, length: 0.7, step: 0.5),
          (format: format, length: 0.03, step: 0.02),
          (format: format, length: 3e-7, step: 2e-7),
          (format: format, length: 6e9, step: 5e9),
        ],
        (format: _fractionalInch, length: 0.01, step: null),
        (format: _fractionalInch, length: 1 / 64, step: 1 / 64),
        (format: _fractionalInch, length: 0.1, step: 1 / 16),
        (format: _fractionalInch, length: 0.5, step: 0.5),
        (format: _fractionalInch, length: 3, step: 1),
        (format: _fractionalInch, length: 11.9, step: 6),
        (format: _fractionalInch, length: 12, step: 12),
        (format: _fractionalInch, length: 23, step: 12),
        (format: _fractionalInch, length: 59, step: 24),
        (format: _fractionalInch, length: 60, step: 60),
        (format: _fractionalInch, length: 130, step: 120),
        (format: _fractionalInch, length: 1300, step: 1200),
      ], (format, length) => format.scaleBarStepAtMost(length));
    });

    test('gridStepAtLeast returns the smallest step that covers', () {
      _expectSteps([
        for (final format in [_metric, _decimalInch]) ...[
          (format: format, length: 7, step: 10),
          (format: format, length: 10, step: 10),
          (format: format, length: 101, step: 1000),
          (format: format, length: 0.03, step: 0.1),
          (format: format, length: 0.001, step: 0.001),
          (format: format, length: 4e-8, step: 1e-7),
        ],
        (format: _fractionalInch, length: 0.001, step: 1 / 16),
        (format: _fractionalInch, length: 1 / 16, step: 1 / 16),
        (format: _fractionalInch, length: 0.1, step: 0.25),
        (format: _fractionalInch, length: 0.5, step: 1),
        (format: _fractionalInch, length: 2, step: 12),
        (format: _fractionalInch, length: 12, step: 12),
        (format: _fractionalInch, length: 13, step: 120),
        (format: _fractionalInch, length: 200, step: 1200),
      ], (format, length) => format.gridStepAtLeast(length));
    });

    test('gridStepAbove returns the next grid step', () {
      _expectSteps([
        for (final format in [_metric, _decimalInch]) ...[
          (format: format, length: 10, step: 100),
          (format: format, length: 0.1, step: 1),
          (format: format, length: 0.001, step: 0.01),
        ],
        (format: _fractionalInch, length: 1 / 16, step: 0.25),
        (format: _fractionalInch, length: 0.25, step: 1),
        (format: _fractionalInch, length: 1, step: 12),
        (format: _fractionalInch, length: 12, step: 120),
        (format: _fractionalInch, length: 120, step: 1200),
      ], (format, length) => format.gridStepAbove(length));
    });

    test('scaleBarStepBelow returns the next shorter scale-bar step', () {
      _expectSteps([
        for (final format in [_metric, _decimalInch]) ...[
          (format: format, length: 10, step: 5),
          (format: format, length: 5, step: 2),
          (format: format, length: 2, step: 1),
          (format: format, length: 1, step: 0.5),
          (format: format, length: 7, step: 5),
        ],
        (format: _fractionalInch, length: 1 / 64, step: null),
        (format: _fractionalInch, length: 1 / 32, step: 1 / 64),
        (format: _fractionalInch, length: 1, step: 0.5),
        (format: _fractionalInch, length: 6, step: 1),
        (format: _fractionalInch, length: 12, step: 6),
        (format: _fractionalInch, length: 24, step: 12),
        (format: _fractionalInch, length: 60, step: 24),
      ], (format, length) => format.scaleBarStepBelow(length));
    });

    test('isScaleBarStep accepts exactly the scale-bar steps', () {
      final cases = <(DisplayFormat, double, bool)>[
        for (final format in [_metric, _decimalInch]) ...[
          (format, 5, true),
          (format, 0.2, true),
          (format, 0.1 + 0.2, false),
          (format, 3, false),
          (format, 2000, true),
        ],
        (_fractionalInch, 1 / 64, true),
        (_fractionalInch, 1 / 128, false),
        (_fractionalInch, 0.375, false),
        (_fractionalInch, 6, true),
        (_fractionalInch, 60, true),
        (_fractionalInch, 36, false),
      ];
      for (final (format, length, expected) in cases) {
        expect(
          format.isScaleBarStep(length),
          expected,
          reason: '${format.name} at $length',
        );
      }
    });

    test('isScaleBarStep rejects a length that is not positive and finite', () {
      for (final format in DisplayFormat.values) {
        for (final length in [0.0, -5.0, double.nan, double.infinity]) {
          expect(format.isScaleBarStep(length), isFalse, reason: '$length');
        }
      }
    });

    test('isGridStep accepts exactly the grid steps', () {
      final cases = <(DisplayFormat, double, bool)>[
        for (final format in [_metric, _decimalInch]) ...[
          (format, 1, true),
          (format, 0.01, true),
          (format, 1000, true),
          (format, 5, false),
          (format, 2, false),
        ],
        (_fractionalInch, 1 / 16, true),
        (_fractionalInch, 0.25, true),
        (_fractionalInch, 12, true),
        (_fractionalInch, 120, true),
        (_fractionalInch, 0.5, false),
        (_fractionalInch, 6, false),
      ];
      for (final (format, length, expected) in cases) {
        expect(
          format.isGridStep(length),
          expected,
          reason: '${format.name} at $length',
        );
      }
    });

    test('isGridStep rejects a length that is not positive and finite', () {
      for (final format in DisplayFormat.values) {
        for (final length in [0.0, -1.0, double.nan, double.infinity]) {
          expect(format.isGridStep(length), isFalse, reason: '$length');
        }
      }
    });

    test('each grid step is a whole multiple of the one before', () {
      for (final format in DisplayFormat.values) {
        var step = format.gridStepAtLeast(1e-3);
        for (var i = 0; i < 12; i++) {
          final next = format.gridStepAbove(step);
          final ratio = next / step;
          expect(
            ratio,
            closeTo(ratio.roundToDouble(), _tolerance),
            reason: '${format.name}: $next over $step',
          );
          expect(ratio.round(), greaterThan(1));
          step = next;
        }
      }
    });

    test('step queries reject a length that is not positive and finite', () {
      for (final format in DisplayFormat.values) {
        for (final length in [0.0, -1.0, double.nan, double.infinity]) {
          expect(() => format.scaleBarStepAtMost(length), throwsArgumentError);
          expect(() => format.gridStepAtLeast(length), throwsArgumentError);
          expect(() => format.gridStepAbove(length), throwsArgumentError);
          expect(() => format.scaleBarStepBelow(length), throwsArgumentError);
        }
      }
    });

    test('formatLabels', () {
      final inches1500mm = UnitSystem.metric.convertTo(
        1500,
        UnitSystem.imperial,
      );
      final mmFromEighth = UnitSystem.imperial.convertTo(
        0.125,
        UnitSystem.metric,
      );
      final mmFrom40Half = UnitSystem.imperial.convertTo(
        40.5,
        UnitSystem.metric,
      );
      final cases = [
        // The roadmap's verification values, in each display format.
        _labels('1500 mm, metric', _metric, [1500], ['1500 mm']),
        _labels(
          '1500 mm, decimal inch',
          _decimalInch,
          [inches1500mm],
          ['59.0551 in'],
        ),
        _labels(
          '1500 mm, fractional inch',
          _fractionalInch,
          [inches1500mm],
          ['4\' 11 1/16"'],
        ),
        _labels('0.125 in, metric', _metric, [mmFromEighth], ['3.175 mm']),
        _labels('0.125 in, decimal inch', _decimalInch, [0.125], ['0.125 in']),
        _labels(
          '0.125 in, fractional inch',
          _fractionalInch,
          [0.125],
          ['1/8"'],
        ),
        _labels('40.5 in, metric', _metric, [mmFrom40Half], ['1028.7 mm']),
        _labels('40.5 in, decimal inch', _decimalInch, [40.5], ['40.5 in']),
        _labels(
          '40.5 in, fractional inch',
          _fractionalInch,
          [40.5],
          ['3\' 4 1/2"'],
        ),
        // Metric promotes at 10 m, decided by the set's largest value.
        _labels('below 10 m', _metric, [9000, 9500], ['9000 mm', '9500 mm']),
        _labels(
          'a set reaching 10 m',
          _metric,
          [0, 5000, 10000],
          ['0 m', '5 m', '10 m'],
          step: 5000,
        ),
        _labels('a lone value past 10 m', _metric, [12345.6], ['12.3456 m']),
        _labels(
          'negative values promote by magnitude',
          _metric,
          [-10500, 500],
          ['-10.5 m', '0.5 m'],
        ),
        // Decimal inch never promotes.
        _labels(
          'decimal inch past a foot',
          _decimalInch,
          [120, 1200],
          ['120 in', '1200 in'],
        ),
        // Decimal places follow the step, with no trailing zeros.
        _labels(
          'quarter steps',
          _metric,
          [0, 0.25, 0.5, 0.75],
          ['0 mm', '0.25 mm', '0.5 mm', '0.75 mm'],
          step: 0.25,
        ),
        _labels(
          'a coarse step rounds',
          _decimalInch,
          [0.04, 0.16],
          ['0 in', '0.2 in'],
          step: 0.1,
        ),
        _labels('default rounding, metric', _metric, [1.23456], ['1.235 mm']),
        _labels(
          'default rounding, decimal inch',
          _decimalInch,
          [1.234567],
          ['1.2346 in'],
        ),
        _labels(
          'rounds away floating-point noise',
          _metric,
          [0.1 + 0.2],
          ['0.3 mm'],
        ),
        _labels('negative zero shows as zero', _metric, [-0.0001], ['0 mm']),
        // The app's decimal marker and leading zero.
        _labels(
          'leading zero hidden',
          _metric,
          [0.5, -0.5, 1.5],
          ['.5 mm', '-.5 mm', '1.5 mm'],
          numbers: _noLeadingZero,
        ),
        _labels(
          'decimal comma',
          _decimalInch,
          [0.125, 2.5],
          ['0,125 in', '2,5 in'],
          numbers: _comma,
        ),
        _labels(
          'decimal comma in meters',
          _metric,
          [12500],
          ['12,5 m'],
          numbers: _comma,
        ),
        // Fractional inch: binary fractions, feet and inches from 12 in.
        _labels(
          'fractions below an inch',
          _fractionalInch,
          [0, 0.25, 0.5, 1 / 64],
          ['0"', '1/4"', '1/2"', '1/64"'],
        ),
        _labels(
          'whole and fractional inches',
          _fractionalInch,
          [3, 4.75],
          ['3"', '4 3/4"'],
        ),
        _labels(
          'a set reaching a foot',
          _fractionalInch,
          [0, 6, 12, 18],
          ['0\' 0"', '0\' 6"', '1\' 0"', '1\' 6"'],
          step: 6,
        ),
        _labels(
          'whole feet drop the inches',
          _fractionalInch,
          [0, 12, 24],
          ['0\'', '1\'', '2\''],
          step: 12,
        ),
        _labels(
          'a sixteenth step rounds',
          _fractionalInch,
          [0.1, 0.2],
          ['1/8"', '3/16"'],
          step: 1 / 16,
        ),
        _labels(
          'rounding up to a foot promotes',
          _fractionalInch,
          [11.999],
          ['1\' 0"'],
        ),
        _labels(
          'negative feet and inches',
          _fractionalInch,
          [-40.5],
          ['-3\' 4 1/2"'],
        ),
        _labels(
          'fractional inch ignores the decimal marker',
          _fractionalInch,
          [0.5],
          ['1/2"'],
          numbers: _comma,
        ),
      ];
      for (final c in cases) {
        expect(
          c.format.formatLabels(c.values, step: c.step, numbers: c.numbers),
          c.labels,
          reason: c.name,
        );
      }
    });

    test('formatLabels rejects a step that is not positive and finite', () {
      for (final format in DisplayFormat.values) {
        for (final step in [0.0, -1.0, double.nan, double.infinity]) {
          expect(
            () => format.formatLabels([1], step: step),
            throwsArgumentError,
          );
        }
      }
    });

    test('formatLabels returns no labels for no values', () {
      for (final format in DisplayFormat.values) {
        expect(format.formatLabels([]), isEmpty);
      }
    });
  });
}
