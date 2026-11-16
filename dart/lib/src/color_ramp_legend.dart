import 'package:vector_math/vector_math_64.dart' as vm;

import 'primitives.dart';
import 'style_tokens.g.dart';
import 'unit_system.dart';
import 'viewport_overlay.dart';

/// Relative slack when testing whether a tick falls inside the value range,
/// so a range end computed as 0.1 + 0.2 still keeps the tick at 0.3.
const _rangeSlack = 1e-9;

/// The direction a color ramp legend's bar runs.
enum ColorRampOrientation {
  /// The bar runs left to right, from the range's minimum to its maximum.
  horizontal,

  /// The bar runs bottom to top, from the range's minimum to its maximum.
  vertical,
}

/// One color stop of a legend's gradient: a position along the bar and the
/// app's key for the color there.
///
/// The package holds no color. The app resolves [key] to a color and
/// interpolates between neighboring stops in the color space its renderer
/// needs.
final class ColorRampStop {
  const ColorRampStop({required this.position, required this.key});

  /// Where the stop sits along the bar, from 0 at the range's minimum to 1
  /// at its maximum.
  final double position;

  /// App key for the stop's color, passed through untouched.
  final Object? key;

  @override
  bool operator ==(Object other) =>
      other is ColorRampStop && other.position == position && other.key == key;

  @override
  int get hashCode => Object.hash(position, key);

  @override
  String toString() => 'ColorRampStop($position, $key)';
}

/// One tick of a legend: a value on the bar and the request for its label.
final class ColorRampTick {
  const ColorRampTick({
    required this.value,
    required this.position,
    required this.label,
    required this.labelAnchor,
  });

  /// The value the tick marks, in the app's value unit.
  final double value;

  /// Where the tick sits along the bar, from 0 at the range's minimum to 1
  /// at its maximum.
  final double position;

  /// The tick's label, as text for the app to set.
  final TextRequest label;

  /// The viewport pixel the label's alignment point sits on.
  final vm.Vector2 labelAnchor;
}

/// A color ramp legend described in viewport pixels, for the app to draw in
/// its 2D layer above the scene.
///
/// Every x and y is in the screen coordinates of
/// `worldToScreen`: pixels from the viewport's top-left
/// corner, y down. Every value is in the app's value unit.
final class ColorRampLegendLayout {
  const ColorRampLegendLayout({
    required this.rect,
    required this.barRect,
    required this.orientation,
    required this.stops,
    required this.tickInterval,
    required this.ticks,
    required this.labelAlignment,
  });

  /// Returns the legend for values from [minValue] to [maxValue], whose
  /// gradient the app keys by [stops].
  ///
  /// The bar runs along [orientation] for the full length of [placement]'s
  /// rectangle, [barThicknessPixels] thick, on the rectangle's edge nearer
  /// its corner. Its labels sit [labelGapPixels] off the bar's other side,
  /// toward the viewport center.
  ///
  /// A tick marks every whole multiple of the tick interval inside the
  /// range. The interval is [tickInterval] when given, or else the smallest
  /// of 1, 2, and 5 times a power of ten that keeps adjacent ticks at least
  /// [minTickSpacingPixels] apart. Each label requests its value's text at
  /// [labelHeightPixels], rounded to the interval and written with
  /// [numbers]. A non-null [unit] follows the first and last labels after a
  /// space.
  ///
  /// Throws an [ArgumentError] when the range is not finite with [minValue]
  /// below [maxValue], when [stops] has fewer than two stops, does not run
  /// from 0 to 1, or descends, when [tickInterval] is given and is not
  /// positive and finite, when [minTickSpacingPixels] is not positive and
  /// finite, or when the placement leaves the bar no length.
  static ColorRampLegendLayout forRange({
    required double minValue,
    required double maxValue,
    required List<ColorRampStop> stops,
    required vm.Vector2 viewportSize,
    ColorRampOrientation orientation = ColorRampOrientation.vertical,
    ViewportOverlayPlacement? placement,
    double? tickInterval,
    String? unit,
    NumberFormatting numbers = const NumberFormatting(),
    double barThicknessPixels = StyleTokens.colorRampLegendBarThicknessPixels,
    double minTickSpacingPixels =
        StyleTokens.colorRampLegendMinTickSpacingPixels,
    double labelGapPixels = StyleTokens.colorRampLegendLabelGapPixels,
    double labelHeightPixels = StyleTokens.colorRampLegendLabelHeightPixels,
  }) {
    if (!minValue.isFinite || !maxValue.isFinite || !(minValue < maxValue)) {
      throw ArgumentError(
        'the value range must be finite with minValue below maxValue, '
        'got $minValue to $maxValue',
      );
    }
    _checkStops(stops);
    if (tickInterval != null && !_isPositive(tickInterval)) {
      throw ArgumentError.value(
        tickInterval,
        'tickInterval',
        'must be positive and finite',
      );
    }
    if (!_isPositive(minTickSpacingPixels)) {
      throw ArgumentError.value(
        minTickSpacingPixels,
        'minTickSpacingPixels',
        'must be positive and finite',
      );
    }

    final p =
        placement ??
        ViewportOverlayPlacement.of(ViewportOverlayKind.colorRampLegend);
    final rect = p.rect(viewportSize);
    final vertical = orientation == ColorRampOrientation.vertical;
    final ViewportRect bar = vertical
        ? (p.corner.isRight
              ? (
                  left: rect.right - barThicknessPixels,
                  top: rect.top,
                  right: rect.right,
                  bottom: rect.bottom,
                )
              : (
                  left: rect.left,
                  top: rect.top,
                  right: rect.left + barThicknessPixels,
                  bottom: rect.bottom,
                ))
        : (p.corner.isBottom
              ? (
                  left: rect.left,
                  top: rect.bottom - barThicknessPixels,
                  right: rect.right,
                  bottom: rect.bottom,
                )
              : (
                  left: rect.left,
                  top: rect.top,
                  right: rect.right,
                  bottom: rect.top + barThicknessPixels,
                ));
    final lengthPixels = vertical ? bar.bottom - bar.top : bar.right - bar.left;
    if (!(lengthPixels > 0)) {
      throw ArgumentError.value(
        placement,
        'placement',
        'must give the bar a positive length',
      );
    }

    final span = maxValue - minValue;
    final interval =
        tickInterval ??
        niceStepAtLeast(minTickSpacingPixels * span / lengthPixels);
    final values = _tickValues(minValue, maxValue, interval);
    final texts = [
      for (final v in values)
        formatNumberLabel(v, step: interval, numbers: numbers),
    ];
    if (unit != null && texts.isNotEmpty) {
      texts[0] = '${texts[0]} $unit';
      // A lone tick is both endpoints, and carries the unit once.
      if (texts.length > 1) texts[texts.length - 1] = '${texts.last} $unit';
    }

    vm.Vector2 anchor(double position) {
      final along = position * lengthPixels;
      return vertical
          ? vm.Vector2(
              p.corner.isRight
                  ? bar.left - labelGapPixels
                  : bar.right + labelGapPixels,
              bar.bottom - along,
            )
          : vm.Vector2(
              bar.left + along,
              p.corner.isBottom
                  ? bar.top - labelGapPixels
                  : bar.bottom + labelGapPixels,
            );
    }

    final ticks = <ColorRampTick>[];
    for (var i = 0; i < values.length; i++) {
      // A tick admitted by the range slack stays on the bar.
      final position = ((values[i] - minValue) / span).clamp(0.0, 1.0);
      ticks.add(
        ColorRampTick(
          value: values[i],
          position: position,
          label: TextRequest(text: texts[i], heightPixels: labelHeightPixels),
          labelAnchor: anchor(position),
        ),
      );
    }
    return ColorRampLegendLayout(
      rect: rect,
      barRect: bar,
      orientation: orientation,
      stops: List.unmodifiable(stops),
      tickInterval: interval,
      ticks: List.unmodifiable(ticks),
      labelAlignment: vertical
          ? vm.Vector2(p.corner.isRight ? 1 : 0, 0.5)
          : vm.Vector2(0.5, p.corner.isBottom ? 0 : 1),
    );
  }

  /// The overlay's rectangle, from its placement.
  final ViewportRect rect;

  /// The gradient bar's rectangle. It spans [rect]'s full length along
  /// [orientation] and sits on [rect]'s edge nearer its corner.
  final ViewportRect barRect;

  /// The direction the bar runs, from the range's minimum to its maximum.
  final ColorRampOrientation orientation;

  /// The gradient's stops, in order along the bar, as the app gave them.
  final List<ColorRampStop> stops;

  /// The value between adjacent ticks.
  final double tickInterval;

  /// Every tick, from the range's minimum end of the bar to its maximum
  /// end.
  final List<ColorRampTick> ticks;

  /// The point of each label's content that sits on its anchor, as a
  /// fraction of its width and height from its bottom-left corner, as
  /// [BillboardPrimitive.alignment] measures it.
  ///
  /// It puts each label beside the bar, on the side toward the viewport
  /// center, centered on its tick.
  final vm.Vector2 labelAlignment;
}

bool _isPositive(double value) => value.isFinite && value > 0;

void _checkStops(List<ColorRampStop> stops) {
  if (stops.length < 2) {
    throw ArgumentError.value(stops, 'stops', 'must hold at least two stops');
  }
  if (stops.first.position != 0 || stops.last.position != 1) {
    throw ArgumentError.value(stops, 'stops', 'must run from 0 to 1');
  }
  for (var i = 1; i < stops.length; i++) {
    if (!(stops[i].position >= stops[i - 1].position)) {
      throw ArgumentError.value(stops, 'stops', 'must not descend');
    }
  }
}

/// Every whole multiple of [interval] from [minValue] to [maxValue],
/// ascending.
List<double> _tickValues(double minValue, double maxValue, double interval) {
  double slack(double ratio) =>
      _rangeSlack * (ratio.abs() < 1 ? 1 : ratio.abs());
  final low = minValue / interval;
  final high = maxValue / interval;
  final first = (low - slack(low)).ceil();
  final last = (high + slack(high)).floor();
  return [for (var k = first; k <= last; k++) k.toDouble() * interval];
}
