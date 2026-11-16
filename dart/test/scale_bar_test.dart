import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/vectors.dart';

/// A field of view whose half-angle tangent is 0.5, so one pixel at depth
/// d in a viewport h pixels tall spans d / h world units.
final _fov = 2 * math.atan(0.5);

final _viewport = vm.Vector2(1280, 720);

/// A camera on +Z looking at the origin, [depth] away, so one pixel at
/// the origin spans depth / 720 world units.
CameraBasis _camera(double depth) => CameraBasis(
  position: vm.Vector3(0, 0, depth),
  forward: vm.Vector3(0, 0, -1),
  right: vm.Vector3(1, 0, 0),
  up: vm.Vector3(0, 1, 0),
);

/// Depth at which one pixel at the origin spans [worldUnitsPerPixel].
double _depthFor(double worldUnitsPerPixel) => worldUnitsPerPixel * _viewport.y;

typedef _Case = ({
  String name,
  double worldUnitsPerPixel,
  UnitSystem worldUnits,
  DisplayFormat format,
  ViewportOverlayPlacement? placement,
  double? previousStep,
  NumberFormatting numbers,
  double step,
  double tickStep,
  double startX,
  String label,
});

const _numbers = NumberFormatting();

final _cases = <_Case>[
  (
    name: 'one mm per pixel fits 100 mm in 20 mm parts',
    worldUnitsPerPixel: 1,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: null,
    numbers: _numbers,
    step: 100,
    tickStep: 20,
    startX: 16,
    label: '100 mm',
  ),
  (
    name: 'ten mm per pixel fits 1000 mm below the meter promotion',
    worldUnitsPerPixel: 10,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: null,
    numbers: _numbers,
    step: 1000,
    tickStep: 200,
    startX: 16,
    label: '1000 mm',
  ),
  (
    name: 'mm world in fractional inch fits 6 in in 1 in parts',
    worldUnitsPerPixel: 1,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.fractionalInch,
    placement: null,
    previousStep: null,
    numbers: _numbers,
    step: 6,
    tickStep: 1,
    startX: 16,
    label: '6"',
  ),
  (
    name: 'a part that does not divide the step is skipped',
    worldUnitsPerPixel: 0.005,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: null,
    numbers: const NumberFormatting(decimalMarker: DecimalMarker.comma),
    step: 0.5,
    tickStep: 0.1,
    startX: 16,
    label: '0,5 mm',
  ),
  (
    name: 'a right corner grows the bar from the right edge',
    worldUnitsPerPixel: 1,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: ViewportOverlayPlacement.of(
      ViewportOverlayKind.scaleBar,
      corner: ViewportCorner.bottomRight,
    ),
    previousStep: null,
    numbers: _numbers,
    step: 100,
    tickStep: 20,
    startX: 1280 - 16 - 100,
    label: '100 mm',
  ),
  (
    name: 'keeps a shorter previous step until a longer one clears the margin',
    worldUnitsPerPixel: 1.3,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: 100,
    numbers: _numbers,
    step: 100,
    tickStep: 50,
    startX: 16,
    label: '100 mm',
  ),
  (
    name: 'adopts a longer step once it clears the margin',
    worldUnitsPerPixel: 1.4,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: 100,
    numbers: _numbers,
    step: 200,
    tickStep: 50,
    startX: 16,
    label: '200 mm',
  ),
  (
    name: 'keeps a longer previous step while it still fits',
    worldUnitsPerPixel: 1.3,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: 200,
    numbers: _numbers,
    step: 200,
    tickStep: 50,
    startX: 16,
    label: '200 mm',
  ),
  (
    name: 'drops a previous step that no longer fits',
    worldUnitsPerPixel: 1.2,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: 200,
    numbers: _numbers,
    step: 100,
    tickStep: 20,
    startX: 16,
    label: '100 mm',
  ),
  (
    name: 'ignores a previous value that is not a step of the format',
    worldUnitsPerPixel: 1.3,
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    placement: null,
    previousStep: 150,
    numbers: _numbers,
    step: 200,
    tickStep: 50,
    startX: 16,
    label: '200 mm',
  ),
];

void main() {
  group('ScaleBarLayout.atTarget', () {
    for (final c in _cases) {
      test(c.name, () {
        final placement =
            c.placement ??
            ViewportOverlayPlacement.of(ViewportOverlayKind.scaleBar);
        final bar = ScaleBarLayout.atTarget(
          camera: _camera(_depthFor(c.worldUnitsPerPixel)),
          target: vm.Vector3.zero(),
          verticalFovRadians: _fov,
          viewportSize: _viewport,
          worldUnits: c.worldUnits,
          format: c.format,
          placement: c.placement,
          previousStep: c.previousStep,
          numbers: c.numbers,
        )!;
        final rect = placement.rect(_viewport);
        final pixelsPerUnit =
            1 /
            c.worldUnits.convertTo(c.worldUnitsPerPixel, c.format.unitSystem);
        final length = c.step * pixelsPerUnit;
        final parts = (c.step / c.tickStep).round();

        expect(bar.rect, rect);
        expect(bar.step, closeTo(c.step, vectorTolerance));
        expect(bar.tickStep, closeTo(c.tickStep, vectorTolerance));
        expect(bar.startX, closeTo(c.startX, vectorTolerance));
        expect(bar.endX, closeTo(c.startX + length, vectorTolerance));
        expect(bar.baselineY, rect.bottom);
        expect(bar.tickXs, hasLength(parts + 1));
        for (var i = 0; i <= parts; i++) {
          expect(
            bar.tickXs[i],
            closeTo(c.startX + i * length / parts, vectorTolerance),
          );
        }
        expect(
          bar.label,
          TextRequest(
            text: c.label,
            heightPixels: StyleTokens.scaleBarLabelHeightPixels,
          ),
        );
        expect(bar.labelAnchor.x, closeTo(c.startX + length / 2, 1e-9));
        expect(bar.labelAnchor.y, rect.top);
        expect(length, lessThanOrEqualTo(rect.right - rect.left + 1e-9));
      });
    }

    test('is null for a target behind the camera', () {
      expect(
        ScaleBarLayout.atTarget(
          camera: _camera(1),
          target: vm.Vector3(0, 0, 2),
          verticalFovRadians: _fov,
          viewportSize: _viewport,
          worldUnits: UnitSystem.metric,
          format: DisplayFormat.metric,
        ),
        isNull,
      );
    });

    test('is null when even the smallest step is longer than the bar', () {
      expect(
        ScaleBarLayout.atTarget(
          camera: _camera(_depthFor(0.001)),
          target: vm.Vector3.zero(),
          verticalFovRadians: _fov,
          viewportSize: _viewport,
          worldUnits: UnitSystem.metric,
          format: DisplayFormat.fractionalInch,
        ),
        isNull,
      );
    });

    test('a wider tick spacing coarsens the parts', () {
      final bar = ScaleBarLayout.atTarget(
        camera: _camera(_depthFor(1)),
        target: vm.Vector3.zero(),
        verticalFovRadians: _fov,
        viewportSize: _viewport,
        worldUnits: UnitSystem.metric,
        format: DisplayFormat.metric,
        minTickSpacingPixels: 40,
      )!;
      expect(bar.tickStep, closeTo(50, vectorTolerance));
    });

    test('a bar too short for any part keeps only its end ticks', () {
      final bar = ScaleBarLayout.atTarget(
        camera: _camera(_depthFor(1)),
        target: vm.Vector3.zero(),
        verticalFovRadians: _fov,
        viewportSize: _viewport,
        worldUnits: UnitSystem.metric,
        format: DisplayFormat.metric,
        minTickSpacingPixels: 200,
      )!;
      expect(bar.tickStep, closeTo(100, vectorTolerance));
      expect(bar.tickXs, hasLength(2));
    });
    for (final (:name, :spacing, :hysteresis) in const [
      (name: 'zero tick spacing', spacing: 0.0, hysteresis: 0.1),
      (
        name: 'infinite tick spacing',
        spacing: double.infinity,
        hysteresis: 0.1,
      ),
      (name: 'negative hysteresis', spacing: 16.0, hysteresis: -0.1),
      (name: 'hysteresis of one', spacing: 16.0, hysteresis: 1.0),
      (name: 'NaN hysteresis', spacing: 16.0, hysteresis: double.nan),
    ]) {
      test('rejects $name', () {
        expect(
          () => ScaleBarLayout.atTarget(
            camera: _camera(_depthFor(1)),
            target: vm.Vector3.zero(),
            verticalFovRadians: _fov,
            viewportSize: _viewport,
            worldUnits: UnitSystem.metric,
            format: DisplayFormat.metric,
            minTickSpacingPixels: spacing,
            hysteresis: hysteresis,
          ),
          throwsArgumentError,
        );
      });
    }
  });
}
