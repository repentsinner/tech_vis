import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_convention.dart';
import 'primitives.dart';
import 'screen_space_utils.dart';
import 'style_tokens.g.dart';
import 'unit_system.dart';

/// The center line and one line either side: the fewest lines a grid
/// with a step can draw across a patch.
const int _fewestLinesPerAxis = 3;

/// Bottom-left corner of a label's content, which sits on its anchor so
/// the label reads up and to the right of the line crossing it marks.
final vm.Vector2 _labelAlignment = vm.Vector2.zero();

/// The area of the ground plane, centered on the plane's origin.
///
/// The patch sets where the grid's lines end and how far its [GroundFade]
/// reaches.
sealed class GroundPatch {
  const GroundPatch();
}

/// A rectangle with half extents along the plane's two axes, `u` and `v`
/// of [CoordinateConvention.planeAxes].
final class RectangularGroundPatch extends GroundPatch {
  const RectangularGroundPatch({
    required this.halfExtentU,
    required this.halfExtentV,
  });

  /// Half the patch's length along the plane's `u` axis, in world units.
  final double halfExtentU;

  /// Half the patch's length along the plane's `v` axis, in world units.
  final double halfExtentV;
}

/// A disc of [radius] around the plane's origin.
final class CircularGroundPatch extends GroundPatch {
  const CircularGroundPatch({required this.radius});

  /// Radius of the disc, in world units.
  final double radius;
}

/// The fade of a ground grid from its patch center to the patch edge.
///
/// Labels carry the fade at their anchors. A renderer fading lines per
/// pixel evaluates [opacityAt], or the same formula in a shader from
/// [center], [u], [v], and [patch], so lines and labels agree.
final class GroundFade {
  /// Creates the fade over [patch] around [center], in the plane along the
  /// unit axes [u] and [v].
  GroundFade({
    required vm.Vector3 center,
    required vm.Vector3 u,
    required vm.Vector3 v,
    required this.patch,
  }) : center = center.clone(),
       u = u.clone(),
       v = v.clone();

  /// World-space center of the patch, where the fade is at full opacity.
  final vm.Vector3 center;

  /// Unit vector along the plane's `u` axis, which a rectangle's
  /// [RectangularGroundPatch.halfExtentU] runs along.
  final vm.Vector3 u;

  /// Unit vector along the plane's `v` axis, which a rectangle's
  /// [RectangularGroundPatch.halfExtentV] runs along.
  final vm.Vector3 v;

  /// The patch whose extents set the fade's reach.
  final GroundPatch patch;

  /// Returns the fade's opacity at [worldPoint], one at [center] and zero
  /// from the patch edge out.
  ///
  /// The point projects onto the plane to `a = (p - center) · u` and
  /// `b = (p - center) · v`. Its reach `r` is `sqrt(a² + b²) / radius` on a
  /// circular patch and `max(|a| / halfExtentU, |b| / halfExtentV)` on a
  /// rectangular one. The opacity is `1 - smoothstep(0, 1, r)`, where
  /// `smoothstep(0, 1, r) = t² (3 - 2t)` with `t` the reach clamped to
  /// `[0, 1]`.
  double opacityAt(vm.Vector3 worldPoint) {
    final d = worldPoint - center;
    final a = d.dot(u);
    final b = d.dot(v);
    final reach = switch (patch) {
      RectangularGroundPatch(:final halfExtentU, :final halfExtentV) =>
        math.max(a.abs() / halfExtentU, b.abs() / halfExtentV),
      CircularGroundPatch(:final radius) => math.sqrt(a * a + b * b) / radius,
    };
    final t = reach.clamp(0.0, 1.0);
    return 1 - t * t * (3 - 2 * t);
  }
}

/// The look of a ground grid. Every default comes from the style tokens.
final class GroundGridStyle {
  /// Creates a grid style. Each value left out takes its token default.
  const GroundGridStyle({
    this.minLineSpacingPixels = StyleTokens.groundGridMinLineSpacingPixels,
    this.stepMargin = StyleTokens.groundGridStepMargin,
    int? maxLinesPerAxis,
    this.minorLineWidth = StyleTokens.groundGridMinorLineWidth,
    this.majorLineWidth = StyleTokens.groundGridMajorLineWidth,
    this.labelPixelSize = StyleTokens.groundGridLabelPixelSize,
  }) : _maxLinesPerAxis = maxLinesPerAxis;

  /// Smallest screen distance between neighboring minor lines at the
  /// camera target, in pixels.
  final double minLineSpacingPixels;

  /// Fraction by which the spacing passes a step boundary before the step
  /// changes.
  final double stepMargin;

  final int? _maxLinesPerAxis;

  /// Most lines across the patch in each direction.
  int get maxLinesPerAxis =>
      _maxLinesPerAxis ?? StyleTokens.groundGridMaxLinesPerAxis.toInt();

  /// Width of a minor line, in screen pixels.
  final double minorLineWidth;

  /// Width of a major line, in screen pixels.
  final double majorLineWidth;

  /// Pixel height of a coordinate label.
  final double labelPixelSize;
}

/// A ground grid for one frame: its steps, its fade, and the primitives
/// that draw it.
final class GroundGrid {
  const GroundGrid({
    required this.minorStep,
    required this.majorStep,
    required this.fade,
    required this.primitives,
  });

  /// Distance between minor lines, in the display format's base unit.
  ///
  /// Pass it back as the previous step of the next frame, so the grid
  /// holds its step near a step boundary.
  final double minorStep;

  /// Distance between major lines, in the display format's base unit.
  final double majorStep;

  /// The fade toward the patch edge, which the renderer applies to the
  /// lines and the labels already carry.
  final GroundFade fade;

  /// Minor lines, then major lines, then coordinate labels.
  final List<Primitive> primitives;
}

/// Factory for an adaptive ground grid: a patch of minor and major lines
/// in the plane across the declared up axis, with coordinate labels on
/// the major lines.
///
/// The minor step adapts to the camera, so minor lines keep a minimum
/// pixel spacing at the camera target at any zoom.
abstract final class GroundPlaneFactory {
  /// Returns the minor grid step for lines at least [minimumSpacing]
  /// apart, both in the base unit of [format].
  ///
  /// Without a [previousStep], returns the smallest grid step of [format]
  /// at least [minimumSpacing] long. With one, keeps [previousStep] while
  /// the spacing stays within [margin] of the boundary it last crossed:
  /// the step coarsens only once [minimumSpacing] passes [previousStep] by
  /// the fraction [margin], and refines only once the finer step clears
  /// [minimumSpacing] by the same fraction. A [previousStep] that is not a
  /// grid step of [format] is ignored.
  static double minorStep({
    required DisplayFormat format,
    required double minimumSpacing,
    double? previousStep,
    double margin = StyleTokens.groundGridStepMargin,
  }) {
    if (!margin.isFinite || margin < 0) {
      throw ArgumentError.value(margin, 'margin', 'must be zero or more');
    }
    final ideal = format.gridStepAtLeast(minimumSpacing);
    if (previousStep == null || !format.isGridStep(previousStep)) {
      return ideal;
    }
    // Every value compared is a step the format returned, so each
    // comparison is exact.
    final held = format.gridStepAtLeast(previousStep);
    final finest = format.gridStepAtLeast(minimumSpacing / (1 + margin));
    final coarsest = format.gridStepAtLeast(minimumSpacing * (1 + margin));
    return held >= finest && held <= coarsest ? held : ideal;
  }

  /// Returns the ground grid over [patch], centered on [origin], for a
  /// [camera] looking at [target].
  ///
  /// The grid lies in the plane through [origin] across the up axis of
  /// [convention]. One world unit is one base unit of [worldUnits]: a
  /// millimeter or an inch. The minor step is the [minorStep] for
  /// [GroundGridStyle.minLineSpacingPixels] at [target], held by
  /// [previousMinorStep] within the style's margin, and coarsened so no
  /// more than [GroundGridStyle.maxLinesPerAxis] lines cross the patch in
  /// either direction. The major step is the grid step of [format] above
  /// the minor step.
  ///
  /// Each line is one Line across the whole chord of the patch, at full
  /// opacity, and a line whose chord is empty is left out. A renderer
  /// fades the lines toward the patch edge per pixel with [GroundGrid.fade].
  /// Each major line carries one coordinate label where it crosses the
  /// perpendicular line through [origin], and [origin] carries one label
  /// for zero. The labels form one set in [format], written with
  /// [numbers], and face the viewer. Each label's opacity is
  /// [GroundFade.opacityAt] its anchor, and a label at zero opacity is left
  /// out.
  ///
  /// Throws an [ArgumentError] when [target] lies on or behind the camera
  /// plane.
  static GroundGrid create({
    required CoordinateConvention convention,
    required GroundPatch patch,
    required DisplayFormat format,
    required UnitSystem worldUnits,
    required CameraBasis camera,
    required vm.Vector3 target,
    required double verticalFovRadians,
    required double viewportHeight,
    required TextResolver resolveText,
    required Object? minorKey,
    required Object? majorKey,
    required Object? labelKey,
    vm.Vector3? origin,
    double? previousMinorStep,
    NumberFormatting numbers = const NumberFormatting(),
    GroundGridStyle style = const GroundGridStyle(),
  }) {
    final perPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
      target,
      camera,
      verticalFovRadians,
      viewportHeight,
    );
    if (perPixel == null) {
      throw ArgumentError.value(
        target,
        'target',
        'must lie in front of the camera',
      );
    }
    if (style.maxLinesPerAxis < _fewestLinesPerAxis) {
      throw ArgumentError.value(
        style.maxLinesPerAxis,
        'style.maxLinesPerAxis',
        'must be at least $_fewestLinesPerAxis',
      );
    }
    final shape = _PatchShape(patch);
    double toFormat(double world) =>
        worldUnits.convertTo(world, format.unitSystem);
    double toWorld(double length) =>
        format.unitSystem.convertTo(length, worldUnits);

    final spaced = minorStep(
      format: format,
      minimumSpacing: toFormat(style.minLineSpacingPixels * perPixel),
      previousStep: previousMinorStep,
      margin: style.stepMargin,
    );
    // Lines at every multiple of the step within the larger half extent
    // number 2 * floor(extent / step) + 1, which this spacing bounds.
    final fits = format.gridStepAtLeast(
      toFormat(2 * shape.maxExtent / (style.maxLinesPerAxis - 1)),
    );
    final minor = math.max(spaced, fits);
    final major = format.gridStepAbove(minor);
    final minorWorld = toWorld(minor);
    final linesPerMajor = (major / minor).round();

    final axes = convention.planeAxes;
    final u = axes.u.unitVector;
    final v = axes.v.unitVector;
    final center = origin ?? vm.Vector3.zero();
    vm.Vector3 at(double a, double b) => center + u * a + v * b;
    final fade = GroundFade(center: center, u: u, v: v, patch: patch);

    final minorLines = <Primitive>[];
    final majorLines = <Primitive>[];
    for (final alongV in [true, false]) {
      final extent = alongV ? shape.extentU : shape.extentV;
      final count = (extent / minorWorld).floor();
      for (var k = -count; k <= count; k++) {
        final offset = k * minorWorld;
        final span = shape.span(offset, alongV: alongV);
        if (span <= 0) continue;
        final isMajor = k % linesPerMajor == 0;
        (isMajor ? majorLines : minorLines).add(
          LinePrimitive(
            start: alongV ? at(offset, -span) : at(-span, offset),
            end: alongV ? at(offset, span) : at(span, offset),
            widthPixels: isMajor ? style.majorLineWidth : style.minorLineWidth,
            key: isMajor ? majorKey : minorKey,
          ),
        );
      }
    }

    // Labels on the u axis, then the v axis, each a whole number of major
    // steps from the origin, which carries the one zero label. A label at
    // the patch edge is invisible, so it stays out of the set and cannot
    // promote the others.
    final majorWorld = toWorld(major);
    double labelOpacity(int k, {required bool onU}) =>
        fade.opacityAt(onU ? at(k * majorWorld, 0) : at(0, k * majorWorld));
    final marks = <({int k, bool onU})>[
      (k: 0, onU: true),
      for (final onU in [true, false])
        for (final k in _majorIndices(
          onU ? shape.extentU : shape.extentV,
          majorWorld,
        ))
          if (k != 0 && labelOpacity(k, onU: onU) > 0) (k: k, onU: onU),
    ];
    final texts = format.formatLabels(
      [for (final m in marks) m.k * major],
      step: major,
      numbers: numbers,
    );
    final labels = <Primitive>[];
    for (var i = 0; i < marks.length; i++) {
      final (:k, :onU) = marks[i];
      final offset = k * majorWorld;
      labels.add(
        BillboardPrimitive(
          content: resolveText(
            TextRequest(text: texts[i], heightPixels: style.labelPixelSize),
          ),
          anchor: onU ? at(offset, 0) : at(0, offset),
          alignment: _labelAlignment.clone(),
          key: labelKey,
          opacity: labelOpacity(k, onU: onU),
        ),
      );
    }

    return GroundGrid(
      minorStep: minor,
      majorStep: major,
      fade: fade,
      primitives: [...minorLines, ...majorLines, ...labels],
    );
  }

  static Iterable<int> _majorIndices(double extent, double step) {
    final count = (extent / step).floor();
    return [for (var k = -count; k <= count; k++) k];
  }
}

/// A patch's extents and chord lengths, in plane coordinates relative to
/// its center.
final class _PatchShape {
  factory _PatchShape(GroundPatch patch) {
    final (extentU, extentV) = switch (patch) {
      RectangularGroundPatch(:final halfExtentU, :final halfExtentV) => (
        halfExtentU,
        halfExtentV,
      ),
      CircularGroundPatch(:final radius) => (radius, radius),
    };
    if (!_positive(extentU) || !_positive(extentV)) {
      throw ArgumentError.value(patch, 'patch', 'needs a positive size');
    }
    return _PatchShape._(patch, extentU, extentV);
  }

  _PatchShape._(this.patch, this.extentU, this.extentV);

  final GroundPatch patch;

  /// Half extent along the plane's `u` axis: the radius of a disc.
  final double extentU;

  /// Half extent along the plane's `v` axis: the radius of a disc.
  final double extentV;

  static bool _positive(double x) => x.isFinite && x > 0;

  double get maxExtent => math.max(extentU, extentV);

  /// Half the length of the line at [offset], running along `v` when
  /// [alongV] and along `u` otherwise.
  double span(double offset, {required bool alongV}) => switch (patch) {
    RectangularGroundPatch(:final halfExtentU, :final halfExtentV) =>
      alongV ? halfExtentV : halfExtentU,
    CircularGroundPatch(:final radius) => math.sqrt(
      math.max(0, radius * radius - offset * offset),
    ),
  };
}
