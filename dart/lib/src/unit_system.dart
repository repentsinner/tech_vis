/// Measurement units and the display formats that label them.
///
/// [UnitSystem] converts between millimeters and inches. [DisplayFormat]
/// decides how a measurement reads: its scale-bar and grid steps and the
/// text of its labels.
library;

import 'dart:math' as math;

/// The metric (mm) and imperial (in) unit systems.
enum UnitSystem {
  /// Metric system — base unit is millimeters.
  metric(
    abbreviation: 'mm',
    baseUnit: 'mm',
    label: 'Metric (mm)',
    toMmFactor: 1.0,
  ),

  /// Imperial system — base unit is inches.
  imperial(
    abbreviation: 'in',
    baseUnit: 'in',
    label: 'Imperial (in)',
    toMmFactor: 25.4,
  );

  const UnitSystem({
    required this.abbreviation,
    required this.baseUnit,
    required this.label,
    required double toMmFactor,
  }) : _toMmFactor = toMmFactor;

  /// Short unit abbreviation (e.g. "mm", "in").
  final String abbreviation;

  /// Base unit name (same as [abbreviation] for these systems).
  final String baseUnit;

  /// Human-readable label (e.g. "Metric (mm)").
  final String label;

  /// Conversion factor: 1 base-unit = [_toMmFactor] mm.
  final double _toMmFactor;

  /// Converts [value] from this unit system to [target].
  double convertTo(double value, UnitSystem target) {
    if (this == target) return value;
    // Convert to mm first, then to target.
    final mm = value * _toMmFactor;
    return mm / target._toMmFactor;
  }
}

/// The character that separates a label's whole part from its decimals.
enum DecimalMarker {
  /// A point: `0.5`.
  point('.'),

  /// A comma: `0,5`.
  comma(',');

  const DecimalMarker(this.symbol);

  /// The marker's character.
  final String symbol;
}

/// The app's choices for writing a decimal number in a label.
///
/// These are independent of the display format and of the drafting
/// convention, because they vary by locale and shop.
final class NumberFormatting {
  /// Creates number formatting. The defaults write `0.5`.
  const NumberFormatting({
    this.decimalMarker = DecimalMarker.point,
    this.showLeadingZero = true,
  });

  /// The character between the whole part and the decimals.
  final DecimalMarker decimalMarker;

  /// Whether a value below one shows its leading zero: `0.5` or `.5`.
  final bool showLeadingZero;
}

/// How a measurement displays: metric, decimal inch, or fractional inch.
///
/// Every length a format takes or returns is in the base unit of its
/// [unitSystem]: millimeters for [metric], inches for [decimalInch] and
/// [fractionalInch]. Convert a world length with [UnitSystem.convertTo]
/// first.
enum DisplayFormat {
  /// Millimeters, promoted to meters at 10 m and above.
  metric(
    unitSystem: UnitSystem.metric,
    scaleBarSteps: _StepSequence(mantissas: [1, 2, 5]),
    gridSteps: _StepSequence(mantissas: [1]),
    resolution: 0.001,
  ),

  /// Inches with decimal places, never promoted to feet.
  decimalInch(
    unitSystem: UnitSystem.imperial,
    scaleBarSteps: _StepSequence(mantissas: [1, 2, 5]),
    gridSteps: _StepSequence(mantissas: [1]),
    resolution: 0.0001,
  ),

  /// Inches with binary fractions down to 1/64, promoted to feet and
  /// inches at 12 in and above: `3' 4 1/2"`.
  fractionalInch(
    unitSystem: UnitSystem.imperial,
    scaleBarSteps: _StepSequence(
      leading: [1 / 64, 1 / 32, 1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 6, 12],
      mantissas: [1, 2, 5],
      decadeUnit: _inchesPerFoot,
      minExponent: 0,
    ),
    gridSteps: _StepSequence(
      leading: [1 / 16, 1 / 4, 1, 12],
      mantissas: [1],
      decadeUnit: _inchesPerFoot,
      minExponent: 0,
    ),
    resolution: 1 / _finestDenominator,
  );

  const DisplayFormat({
    required this.unitSystem,
    required _StepSequence scaleBarSteps,
    required _StepSequence gridSteps,
    required double resolution,
  }) : _scaleBarSteps = scaleBarSteps,
       _gridSteps = gridSteps,
       _resolution = resolution;

  /// The unit system whose base unit this format's lengths are in.
  final UnitSystem unitSystem;

  final _StepSequence _scaleBarSteps;
  final _StepSequence _gridSteps;

  /// The step labels round to when the caller names none.
  final double _resolution;

  /// Returns the largest scale-bar step no longer than [length], or null
  /// when even the smallest step is longer.
  ///
  /// Scale-bar steps are 1, 2, and 5 times every power of ten, except
  /// fractional inch, which steps through binary fractions to 1 in, then
  /// 6 and 12 in, then 1, 2, and 5 times every power of ten feet.
  double? scaleBarStepAtMost(double length) =>
      _scaleBarSteps.atMost(_positive(length, 'length'));

  /// Returns the largest scale-bar step shorter than [step], or null when
  /// [step] is the smallest.
  double? scaleBarStepBelow(double step) =>
      _scaleBarSteps.below(_positive(step, 'step'));

  /// Whether [length] is one of the scale-bar steps.
  ///
  /// Returns false for a [length] that is not positive and finite.
  bool isScaleBarStep(double length) {
    if (!length.isFinite || length <= 0) return false;
    final step = _scaleBarSteps.atMost(length);
    return step != null && (step - length).abs() <= length * _relativeSlack;
  }

  /// Returns the smallest grid step at least [length] long.
  ///
  /// Grid steps are every power of ten, except fractional inch, which
  /// steps 1/16, 1/4, 1, and 12 in, then every power of ten feet. Each
  /// grid step is a whole multiple of the one before it, so a major line
  /// is always also a minor line.
  double gridStepAtLeast(double length) =>
      _gridSteps.atLeast(_positive(length, 'length'));

  /// Whether [length] is one of the grid steps.
  ///
  /// Returns false for a [length] that is not positive and finite.
  bool isGridStep(double length) {
    if (!length.isFinite || length <= 0) return false;
    final step = _gridSteps.atLeast(length);
    return (step - length).abs() <= length * _relativeSlack;
  }

  /// Returns the smallest grid step longer than [step]: the major step
  /// over a minor [step].
  double gridStepAbove(double step) =>
      _gridSteps.above(_positive(step, 'step'));

  /// Returns the labels for a set of [values] displayed together, one per
  /// value, in order.
  ///
  /// Every label in the set shares one unit, and the set's largest
  /// magnitude decides whether it promotes to meters or to feet and
  /// inches. Each label rounds to [step] and shows the fewest decimal
  /// places, or the smallest binary fraction, that represent [step]
  /// exactly, with no trailing zeros. A fractional-inch set whose [step] is
  /// a whole number of feet drops the inches: `2'`. Without a [step],
  /// labels round to 0.001 mm, 0.0001 in, or 1/64 in. [numbers] sets the
  /// decimal marker and leading zero; fractional inch has no decimals and
  /// ignores it.
  List<String> formatLabels(
    List<double> values, {
    double? step,
    NumberFormatting numbers = const NumberFormatting(),
  }) {
    final rounding = _positive(step ?? _resolution, 'step');
    return switch (this) {
      metric => _decimalLabels(
        values,
        rounding,
        numbers,
        unit: 'mm',
        promotion: (
          atLeast: _metricPromotionMm,
          unit: 'm',
          factor: _mmPerMeter,
          decimals: _metersDecimals,
        ),
      ),
      decimalInch => _decimalLabels(values, rounding, numbers, unit: 'in'),
      fractionalInch => _fractionalLabels(values, rounding),
    };
  }
}

const _inchesPerFoot = 12;
const _mmPerMeter = 1000;

/// The decimal places a millimeter value gains when it reads in meters.
const _metersDecimals = 3;

/// Metric labels promote to meters at and above 10 m.
const _metricPromotionMm = 10000;

/// Fractional inch reads to 1/64 in and no finer.
const _finestDenominator = 64;

/// Decimal places allowed before a step counts as unrepresentable.
const _maxDecimals = 12;

/// Relative slack in comparisons between a step and a requested length,
/// so a length computed as 0.1 + 0.2 still admits the step 0.3.
const _relativeSlack = 1e-9;

double _positive(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'must be positive and finite');
  }
  return value;
}

/// An unbounded ascending sequence of clean steps: an optional run of
/// [leading] steps, then [mantissas] times every power of ten
/// [decadeUnit]s from 10^[minExponent] up, skipping any not past the
/// leading run. With no [minExponent] the decades run down without end.
final class _StepSequence {
  const _StepSequence({
    required this.mantissas,
    this.leading = const [],
    this.decadeUnit = 1,
    this.minExponent,
  });

  final List<double> leading;
  final List<double> mantissas;
  final num decadeUnit;
  final int? minExponent;

  /// The steps near [length]: every leading step, and the decades either
  /// side of [length]'s own, which bracket it from below and above.
  Iterable<double> _near(double length) sync* {
    yield* leading;
    final own = (math.log(length / decadeUnit) / math.ln10).floor();
    final low = math.max(own - 1, minExponent ?? own - 1);
    final high = math.max(own + 1, minExponent ?? own + 1);
    for (var exponent = low; exponent <= high; exponent++) {
      for (final mantissa in mantissas) {
        final step = _decade(mantissa, exponent) * decadeUnit;
        if (leading.isEmpty || step > leading.last * (1 + _relativeSlack)) {
          yield step;
        }
      }
    }
  }

  double? atMost(double length) {
    double? best;
    for (final step in _near(length)) {
      if (step <= length * (1 + _relativeSlack) && step > (best ?? 0)) {
        best = step;
      }
    }
    return best;
  }

  double? below(double step) {
    final bound = step * (1 - _relativeSlack);
    double? best;
    for (final candidate in _near(bound)) {
      if (candidate < bound && candidate > (best ?? 0)) best = candidate;
    }
    return best;
  }

  double atLeast(double length) => _smallestFrom(length * (1 - _relativeSlack));

  double above(double step) => _smallestFrom(step * (1 + _relativeSlack));

  /// The smallest step at or past [bound], which already carries the slack.
  double _smallestFrom(double bound) {
    var best = double.infinity;
    for (final step in _near(bound)) {
      if (step >= bound && step < best) best = step;
    }
    return best;
  }
}

/// [mantissa] times 10^[exponent], dividing for negative exponents so
/// that 10^-3 is the double nearest 0.001.
double _decade(double mantissa, int exponent) => exponent >= 0
    ? mantissa * math.pow(10.0, exponent)
    : mantissa / math.pow(10.0, -exponent);

/// Whether [x] is a whole number, within the relative slack.
bool _isWhole(double x) =>
    (x - x.roundToDouble()).abs() <= x.abs() * _relativeSlack;

/// The fewest decimal places that write [step] exactly.
int _decimalsFor(double step) {
  for (var places = 0; places < _maxDecimals; places++) {
    if (_isWhole(step * math.pow(10.0, places))) return places;
  }
  return _maxDecimals;
}

List<String> _decimalLabels(
  List<double> values,
  double step,
  NumberFormatting numbers, {
  required String unit,
  ({int atLeast, String unit, int factor, int decimals})? promotion,
}) {
  final places = _decimalsFor(step);
  final rounded = [
    for (final v in values) double.parse(v.toStringAsFixed(places)),
  ];
  final largest = rounded.fold(0.0, (m, v) => math.max(m, v.abs()));
  if (promotion != null && largest >= promotion.atLeast) {
    final (atLeast: _, unit: promotedUnit, :factor, :decimals) = promotion;
    return [
      for (final v in rounded)
        '${_decimal(v / factor, places + decimals, numbers)} $promotedUnit',
    ];
  }
  return [for (final v in rounded) '${_decimal(v, places, numbers)} $unit'];
}

final _trailingZeros = RegExp(r'\.?0+$');

/// Writes [value] to [places] decimals, without trailing zeros.
String _decimal(double value, int places, NumberFormatting numbers) {
  var text = value.abs().toStringAsFixed(places);
  if (text.contains('.')) text = text.replaceFirst(_trailingZeros, '');
  if (text == '0') return text;
  if (!numbers.showLeadingZero && text.startsWith('0.')) {
    text = text.substring(1);
  }
  text = text.replaceFirst('.', numbers.decimalMarker.symbol);
  return value < 0 ? '-$text' : text;
}

/// The smallest binary fraction denominator, up to 1/64, that writes
/// [step] exactly.
int _denominatorFor(double step) {
  for (
    var denominator = 1;
    denominator < _finestDenominator;
    denominator *= 2
  ) {
    if (_isWhole(step * denominator)) return denominator;
  }
  return _finestDenominator;
}

List<String> _fractionalLabels(List<double> values, double step) {
  final denominator = _denominatorFor(step);
  final foot = _inchesPerFoot * denominator;
  // Each value as a whole count of 1/denominator inches.
  final counts = [for (final v in values) (v * denominator).round()];
  final largest = counts.fold(0, (m, c) => math.max(m, c.abs()));
  final promote = largest >= foot;
  // A step of whole feet never needs the inches, so its labels drop them.
  final wholeFeet = promote && _isWhole(step / _inchesPerFoot);

  String inches(int count) {
    final whole = count ~/ denominator;
    final remainder = count % denominator;
    if (remainder == 0) return '$whole"';
    final divisor = remainder.gcd(denominator);
    final fraction = '${remainder ~/ divisor}/${denominator ~/ divisor}';
    return whole == 0 ? '$fraction"' : '$whole $fraction"';
  }

  return [
    for (final c in counts)
      (c < 0 ? '-' : '') +
          switch (c.abs()) {
            final n when wholeFeet => "${n ~/ foot}'",
            final n when promote => "${n ~/ foot}' ${inches(n % foot)}",
            final n => inches(n),
          },
  ];
}
