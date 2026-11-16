import 'package:vector_math/vector_math_64.dart' as vm;

import 'primitives.dart';
import 'screen_space_utils.dart';
import 'style_tokens.g.dart';
import 'unit_system.dart';
import 'viewport_overlay.dart';

/// Relative slack when comparing steps, so a step computed one way still
/// matches the same step computed another.
const _relativeSlack = 1e-9;

/// Factor below a step that reaches only steps strictly shorter than it,
/// well clear of the step queries' own slack.
const _belowStep = 1 - 1e-6;

/// A scale bar described in viewport pixels, for the app to draw in its 2D
/// layer above the scene.
///
/// Every x and y is in the screen coordinates of
/// [ScreenSpaceUtils.worldToScreen]: pixels from the viewport's top-left
/// corner, y down. Every length is in the base unit of the display
/// format's unit system.
final class ScaleBarLayout {
  const ScaleBarLayout({
    required this.rect,
    required this.step,
    required this.tickStep,
    required this.startX,
    required this.endX,
    required this.baselineY,
    required this.tickXs,
    required this.label,
    required this.labelAnchor,
  });

  /// Returns the scale bar for a [camera] looking at [target], or null when
  /// the bar has no length to show.
  ///
  /// The bar measures at [target], the point the reader is looking at.
  /// Its value is the longest scale-bar step of [format] whose length at
  /// [target] fits within the width of [placement]'s rectangle. World
  /// lengths are in [worldUnits].
  ///
  /// Pass the [step] of the previous frame's layout as [previousStep] to
  /// keep the value from flickering at a step boundary: the bar keeps that
  /// step while it fits, and adopts a longer step only once the longer
  /// step fits within the width less a [hysteresis] fraction of it. A
  /// [previousStep] that is not a step of [format] is ignored.
  ///
  /// The bar subdivides into the most equal parts, each itself a scale-bar
  /// step of [format], whose ticks stay at least [minTickSpacingPixels]
  /// apart. Its label requests [step]'s text at [labelHeightPixels], in
  /// [format] with [numbers].
  ///
  /// Returns null when [target] is on or behind the camera plane, or when
  /// even the shortest step of [format] is longer than the width. Throws
  /// an [ArgumentError] when [minTickSpacingPixels] is not positive, or
  /// when [hysteresis] is not in [0, 1), or when [previousStep] is not
  /// positive.
  static ScaleBarLayout? atTarget({
    required CameraBasis camera,
    required vm.Vector3 target,
    required double verticalFovRadians,
    required vm.Vector2 viewportSize,
    required UnitSystem worldUnits,
    required DisplayFormat format,
    ViewportOverlayPlacement? placement,
    double? previousStep,
    NumberFormatting numbers = const NumberFormatting(),
    double minTickSpacingPixels = StyleTokens.scaleBarMinTickSpacingPixels,
    double hysteresis = StyleTokens.scaleBarStepHysteresis,
    double labelHeightPixels = StyleTokens.scaleBarLabelHeightPixels,
  }) {
    if (!minTickSpacingPixels.isFinite || minTickSpacingPixels <= 0) {
      throw ArgumentError.value(
        minTickSpacingPixels,
        'minTickSpacingPixels',
        'must be positive and finite',
      );
    }
    if (!(hysteresis >= 0 && hysteresis < 1)) {
      throw ArgumentError.value(
        hysteresis,
        'hysteresis',
        'must be at least 0 and less than 1',
      );
    }
    final worldPerPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
      target,
      camera,
      verticalFovRadians,
      viewportSize.y,
    );
    if (worldPerPixel == null) return null;
    final unitsPerPixel = worldUnits.convertTo(
      worldPerPixel,
      format.unitSystem,
    );

    final p =
        placement ?? ViewportOverlayPlacement.of(ViewportOverlayKind.scaleBar);
    final rect = p.rect(viewportSize);
    final maxLength = (rect.right - rect.left) * unitsPerPixel;
    final fitting = format.scaleBarStepAtMost(maxLength);
    if (fitting == null) return null;

    final step = _keepsPrevious(format, previousStep, maxLength, hysteresis)
        ? previousStep!
        : fitting;
    final tickStep = _tickStep(
      format,
      step,
      minTickSpacingPixels * unitsPerPixel,
    );

    final lengthPixels = step / unitsPerPixel;
    final startX = p.corner.isRight ? rect.right - lengthPixels : rect.left;
    final parts = (step / tickStep).round();
    final label = format.formatLabels([step], step: step, numbers: numbers);
    return ScaleBarLayout(
      rect: rect,
      step: step,
      tickStep: tickStep,
      startX: startX,
      endX: startX + lengthPixels,
      baselineY: rect.bottom,
      tickXs: List.unmodifiable([
        for (var i = 0; i <= parts; i++) startX + i * lengthPixels / parts,
      ]),
      label: TextRequest(text: label.single, heightPixels: labelHeightPixels),
      labelAnchor: vm.Vector2(startX + lengthPixels / 2, rect.top),
    );
  }

  /// The overlay's rectangle, from its placement.
  final ViewportRect rect;

  /// The length the bar represents.
  final double step;

  /// The length between adjacent ticks; equal to [step] when the bar has
  /// no subdivision.
  final double tickStep;

  /// The x of the bar's left end. The bar starts at the rectangle's edge
  /// nearer its corner: the left edge for a left corner, the right edge
  /// for a right corner.
  final double startX;

  /// The x of the bar's right end.
  final double endX;

  /// The y the bar and its ticks stand on: the rectangle's bottom edge.
  final double baselineY;

  /// The x of every tick, from [startX] to [endX] inclusive, ascending.
  final List<double> tickXs;

  /// The bar's value label, as text for the app to set.
  final TextRequest label;

  /// Where the label's top center sits: above the bar's midpoint, on the
  /// rectangle's top edge.
  final vm.Vector2 labelAnchor;
}

/// Whether the bar keeps [previous]: it is a step of [format], it fits
/// within [maxLength], and no longer step fits with the [hysteresis]
/// margin to spare.
bool _keepsPrevious(
  DisplayFormat format,
  double? previous,
  double maxLength,
  double hysteresis,
) {
  if (previous == null) return false;
  final asStep = format.scaleBarStepAtMost(previous);
  if (asStep == null || (asStep - previous).abs() > previous * _relativeSlack) {
    return false;
  }
  if (previous > maxLength * (1 + _relativeSlack)) return false;
  final clearing = format.scaleBarStepAtMost(maxLength * (1 - hysteresis));
  return clearing == null || clearing <= previous * (1 + _relativeSlack);
}

/// The shortest scale-bar step of [format] that divides [step] into whole
/// parts at least [minSpacing] long, or [step] when none does.
double _tickStep(DisplayFormat format, double step, double minSpacing) {
  var best = step;
  for (
    var part = format.scaleBarStepAtMost(step * _belowStep);
    part != null && part >= minSpacing;
    part = format.scaleBarStepAtMost(part * _belowStep)
  ) {
    final ratio = step / part;
    if ((ratio - ratio.roundToDouble()).abs() <= ratio * _relativeSlack) {
      best = part;
    }
  }
  return best;
}
