import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/fake_text_resolver.dart';

const _tolerance = 1e-9;

const _conventions = [
  CoordinateConvention(up: SpatialAxis.z, handedness: Handedness.right),
  CoordinateConvention(up: SpatialAxis.z, handedness: Handedness.left),
  CoordinateConvention(up: SpatialAxis.y, handedness: Handedness.right),
  CoordinateConvention(up: SpatialAxis.y, handedness: Handedness.left),
  CoordinateConvention(up: SpatialAxis.x, handedness: Handedness.right),
];

const _fov = math.pi / 4;
const _viewportHeight = 720.0;

/// Keys that let a test tell each kind of primitive apart.
const _minorKey = 'minor';
const _majorKey = 'major';
const _labelKey = 'label';

/// A camera at [distance] from [target], up the declared up axis and off
/// to one side, so the view is oblique to the plane.
CameraBasis _camera(
  CoordinateConvention convention,
  vm.Vector3 target,
  double distance,
) {
  final axes = GroundPlaneFactory.planeAxes(convention);
  final direction =
      (convention.up.unitVector * 2 +
              axes.u.unitVector * 0.5 +
              axes.v.unitVector * -1)
          .normalized();
  return CameraBasis.lookAt(
    position: target + direction * distance,
    target: target,
    convention: convention,
  );
}

GroundGrid _grid({
  CoordinateConvention convention = const CoordinateConvention(
    up: SpatialAxis.z,
    handedness: Handedness.right,
  ),
  GroundPatch patch = const RectangularGroundPatch(
    halfExtentU: 500,
    halfExtentV: 300,
  ),
  DisplayFormat format = DisplayFormat.metric,
  UnitSystem worldUnits = UnitSystem.metric,
  vm.Vector3? origin,
  vm.Vector3? target,
  double distance = 150,
  double? previousMinorStep,
  GroundGridStyle style = const GroundGridStyle(),
}) {
  final at = target ?? vm.Vector3.zero();
  return GroundPlaneFactory.create(
    convention: convention,
    patch: patch,
    format: format,
    worldUnits: worldUnits,
    camera: _camera(convention, at, distance),
    target: at,
    verticalFovRadians: _fov,
    viewportHeight: _viewportHeight,
    resolveText: fakeTextResolver,
    minorKey: _minorKey,
    majorKey: _majorKey,
    labelKey: _labelKey,
    origin: origin,
    previousMinorStep: previousMinorStep,
    style: style,
  );
}

List<LinePrimitive> _lines(GroundGrid grid, [Object? key]) => [
  for (final p in grid.primitives)
    if (p is LinePrimitive && (key == null || p.key == key)) p,
];

List<BillboardPrimitive> _labels(GroundGrid grid) =>
    grid.primitives.whereType<BillboardPrimitive>().toList();

double _along(vm.Vector3 point, SpatialAxis axis) => point[axis.index];

void main() {
  group('GroundGridStyle', () {
    test('defaults come from the style tokens', () {
      const style = GroundGridStyle();
      expect(
        style.minLineSpacingPixels,
        StyleTokens.groundGridMinLineSpacingPixels,
      );
      expect(style.stepMargin, StyleTokens.groundGridStepMargin);
      expect(
        style.maxLinesPerAxis,
        StyleTokens.groundGridMaxLinesPerAxis.toInt(),
      );
      expect(style.fadeSegments, StyleTokens.groundGridFadeSegments.toInt());
      expect(style.minorLineWidth, StyleTokens.groundGridMinorLineWidth);
      expect(style.majorLineWidth, StyleTokens.groundGridMajorLineWidth);
      expect(style.labelPixelSize, StyleTokens.groundGridLabelPixelSize);
    });
  });

  group('GroundPlaneFactory.planeAxes', () {
    for (final (up, u, v) in [
      (SpatialAxis.z, SpatialAxis.x, SpatialAxis.y),
      (SpatialAxis.y, SpatialAxis.z, SpatialAxis.x),
      (SpatialAxis.x, SpatialAxis.y, SpatialAxis.z),
    ]) {
      for (final hand in Handedness.values) {
        test('${up.label}-up ${hand.name}-handed lies in $u, $v', () {
          final axes = GroundPlaneFactory.planeAxes(
            CoordinateConvention(up: up, handedness: hand),
          );
          expect(axes.u, u);
          expect(axes.v, v);
        });
      }
    }
  });

  group('GroundPlaneFactory.minorStep', () {
    // Metric grid steps are powers of ten; the boundary sits at 10.
    const margin = 0.25;
    for (final c in [
      (name: 'no previous step', spacing: 7.0, previous: null, step: 10.0),
      (
        name: 'previous step still fits',
        spacing: 7.0,
        previous: 10.0,
        step: 10.0,
      ),
      (
        name: 'spacing just past the boundary keeps the finer step',
        spacing: 10 * 1.2,
        previous: 10.0,
        step: 10.0,
      ),
      (
        name: 'spacing past the boundary by the margin coarsens',
        spacing: 10 * 1.3,
        previous: 10.0,
        step: 100.0,
      ),
      (
        name: 'spacing just back under the boundary keeps the coarser step',
        spacing: 10 / 1.2,
        previous: 100.0,
        step: 100.0,
      ),
      (
        name: 'spacing back under the boundary by the margin refines',
        spacing: 10 / 1.3,
        previous: 100.0,
        step: 10.0,
      ),
      (
        name: 'a jump of several steps ignores the previous step',
        spacing: 3000.0,
        previous: 10.0,
        step: 10000.0,
      ),
      (
        name: 'a previous value off the step sequence is ignored',
        spacing: 7.0,
        previous: 30.0,
        step: 10.0,
      ),
    ]) {
      test(c.name, () {
        expect(
          GroundPlaneFactory.minorStep(
            format: DisplayFormat.metric,
            minimumSpacing: c.spacing,
            previousStep: c.previous,
            margin: margin,
          ),
          closeTo(c.step, _tolerance),
        );
      });
    }

    test('fractional inch steps through its leading run', () {
      expect(
        GroundPlaneFactory.minorStep(
          format: DisplayFormat.fractionalInch,
          minimumSpacing: 0.2,
        ),
        0.25,
      );
    });

    test('rejects a negative margin', () {
      expect(
        () => GroundPlaneFactory.minorStep(
          format: DisplayFormat.metric,
          minimumSpacing: 1,
          margin: -0.1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('GroundPlaneFactory.create', () {
    for (final convention in _conventions) {
      group('$convention', () {
        late GroundGrid grid;
        final origin = vm.Vector3(3, -4, 5);

        setUp(() {
          grid = _grid(convention: convention, origin: origin);
        });

        test('lies in the plane through the origin across the up axis', () {
          for (final line in _lines(grid)) {
            expect(
              _along(line.start, convention.up),
              closeTo(origin[convention.up.index], _tolerance),
            );
            expect(
              _along(line.end, convention.up),
              closeTo(origin[convention.up.index], _tolerance),
            );
          }
          for (final label in _labels(grid)) {
            expect(
              _along(label.anchor, convention.up),
              closeTo(origin[convention.up.index], _tolerance),
            );
          }
        });

        test('each line runs along one plane axis', () {
          final axes = GroundPlaneFactory.planeAxes(convention);
          for (final line in _lines(grid)) {
            final d = line.end - line.start;
            final alongU = d[axes.u.index].abs() > 0;
            final alongV = d[axes.v.index].abs() > 0;
            expect(alongU != alongV, isTrue, reason: '$d');
          }
        });
      });
    }

    test(
      'minor lines sit at least the minimum spacing apart at the target',
      () {
        const style = GroundGridStyle();
        for (final distance in [200.0, 1500.0, 9000.0]) {
          final grid = _grid(
            distance: distance,
            patch: const RectangularGroundPatch(
              halfExtentU: 1e4,
              halfExtentV: 1e4,
            ),
            style: const GroundGridStyle(
              maxLinesPerAxis: 10001,
              fadeSegments: 1,
            ),
          );
          final perPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
            vm.Vector3.zero(),
            _camera(_conventionZ, vm.Vector3.zero(), distance),
            _fov,
            _viewportHeight,
          )!;
          final spacing = grid.minorStep / perPixel;
          expect(spacing, greaterThanOrEqualTo(style.minLineSpacingPixels));
          // The next finer step would fall below the minimum.
          expect(spacing / 10, lessThan(style.minLineSpacingPixels));
          expect(grid.majorStep, closeTo(grid.minorStep * 10, _tolerance));
        }
      },
    );

    test('converts world units to the display format', () {
      // 12 px at the target spans 2.07 mm, or 0.082 in.
      const patch = RectangularGroundPatch(halfExtentU: 50, halfExtentV: 30);
      final mm = _grid(patch: patch);
      final inches = _grid(patch: patch, format: DisplayFormat.decimalInch);
      expect(mm.minorStep, closeTo(10, _tolerance));
      expect(inches.minorStep, closeTo(0.1, _tolerance));
      final minorOffsets = {
        for (final l in _lines(inches))
          if (l.start.x == l.end.x) l.start.x,
      }.toList()..sort();
      expect(minorOffsets[1] - minorOffsets[0], closeTo(2.54, _tolerance));
    });

    test('major lines fall on every major step, minor lines between', () {
      final grid = _grid();
      for (final (key, isMajor) in [(_majorKey, true), (_minorKey, false)]) {
        final lines = _lines(grid, key);
        expect(lines, isNotEmpty);
        for (final l in lines) {
          final offset = l.start.x == l.end.x ? l.start.x : l.start.y;
          final ratio = offset / grid.majorStep;
          expect(
            (ratio - ratio.roundToDouble()).abs() < _tolerance,
            isMajor,
            reason: '$key at $offset',
          );
          expect(
            l.widthPixels,
            isMajor
                ? StyleTokens.groundGridMajorLineWidth
                : StyleTokens.groundGridMinorLineWidth,
          );
        }
      }
    });

    test('minor lines draw before major lines, and labels last', () {
      final keys = [for (final p in _grid().primitives) p.key];
      final lastMinor = keys.lastIndexOf(_minorKey);
      final firstMajor = keys.indexOf(_majorKey);
      final lastMajor = keys.lastIndexOf(_majorKey);
      final firstLabel = keys.indexOf(_labelKey);
      expect(lastMinor, lessThan(firstMajor));
      expect(lastMajor, lessThan(firstLabel));
    });

    test('caps the lines across the patch', () {
      final grid = _grid(
        distance: 50,
        style: const GroundGridStyle(maxLinesPerAxis: 21),
      );
      final offsets = {
        for (final l in _lines(grid))
          if (l.start.x == l.end.x) l.start.x,
      };
      expect(offsets.length, lessThanOrEqualTo(21));
      expect(grid.minorStep, closeTo(100, _tolerance));
    });

    group('rectangular fade', () {
      final grid = _grid(style: const GroundGridStyle(fadeSegments: 4));
      const hu = 500.0;
      const hv = 300.0;

      test('splits each line into equal segments across the patch', () {
        final centerLine = [
          for (final l in _lines(grid, _majorKey))
            if (l.start.x == 0 && l.end.x == 0) l,
        ];
        expect(centerLine, hasLength(4));
        expect(centerLine.first.start.y, closeTo(-hv, _tolerance));
        expect(centerLine.last.end.y, closeTo(hv, _tolerance));
      });

      test('opacity falls linearly to the edge, evaluated mid-segment', () {
        for (final l in _lines(grid)) {
          final mid = (l.start + l.end) * 0.5;
          final expected = 1 - math.max(mid.x.abs() / hu, mid.y.abs() / hv);
          expect(l.opacity, closeTo(expected, _tolerance));
          expect(l.opacity, greaterThan(0));
        }
      });

      test('lines stay inside the patch', () {
        for (final l in _lines(grid)) {
          for (final p in [l.start, l.end]) {
            expect(p.x.abs(), lessThanOrEqualTo(hu + _tolerance));
            expect(p.y.abs(), lessThanOrEqualTo(hv + _tolerance));
          }
        }
      });
    });

    group('circular fade', () {
      const radius = 400.0;
      final grid = _grid(
        patch: const CircularGroundPatch(radius: radius),
        style: const GroundGridStyle(fadeSegments: 4),
      );

      test('each line is a chord of the circle', () {
        for (final l in _lines(grid)) {
          final first = l.start;
          if (first.x == l.end.x) {
            final half = math.sqrt(radius * radius - first.x * first.x);
            expect(first.y, greaterThanOrEqualTo(-half - _tolerance));
            expect(l.end.y, lessThanOrEqualTo(half + _tolerance));
          }
        }
      });

      test('opacity falls radially, evaluated mid-segment', () {
        for (final l in _lines(grid)) {
          final mid = (l.start + l.end) * 0.5;
          expect(
            l.opacity,
            closeTo(
              1 - math.sqrt(mid.x * mid.x + mid.y * mid.y) / radius,
              _tolerance,
            ),
          );
        }
      });
    });

    group('labels', () {
      final grid = _grid();

      test('mark each major line where it crosses the origin axes', () {
        final labels = _labels(grid);
        final anchors = [for (final l in labels) (l.anchor.x, l.anchor.y)];
        // Major step 100 inside 500 x 300 half extents: -400..400 on U,
        // -200..200 on V, and one origin label.
        expect(anchors, hasLength(1 + 8 + 4));
        expect(anchors.first, (0.0, 0.0));
        expect(anchors, contains((-400.0, 0.0)));
        expect(anchors, contains((0.0, 200.0)));
      });

      test('read in the display format, one unit for the set', () {
        final texts = [
          for (final l in _labels(grid)) (l.content.value! as TextRequest).text,
        ];
        expect(texts.first, '0 mm');
        expect(texts, contains('-400 mm'));
        expect(texts, contains('200 mm'));
      });

      test('face the viewer at the label pixel height and fade', () {
        for (final l in _labels(grid)) {
          expect(l.orientation, isA<ViewerFacingOrientation>());
          expect(
            (l.content.value! as TextRequest).heightPixels,
            StyleTokens.groundGridLabelPixelSize,
          );
          expect(l.alignment.x, 0);
          expect(l.alignment.y, 0);
          expect(
            l.opacity,
            closeTo(
              1 - math.max(l.anchor.x.abs() / 500, l.anchor.y.abs() / 300),
              _tolerance,
            ),
          );
        }
      });

      test('promote with the set', () {
        final far = _grid(
          distance: 2e5,
          patch: const RectangularGroundPatch(
            halfExtentU: 5e5,
            halfExtentV: 5e5,
          ),
        );
        final texts = [
          for (final l in _labels(far)) (l.content.value! as TextRequest).text,
        ];
        expect(texts, everyElement(endsWith(' m')));
      });
    });

    test('keeps the previous step inside the margin', () {
      // 12 px spans 10 mm at a distance near 724.
      final fresh = _grid(distance: 700);
      final kept = _grid(distance: 770, previousMinorStep: fresh.minorStep);
      final moved = _grid(distance: 770);
      expect(kept.minorStep, fresh.minorStep);
      expect(moved.minorStep, isNot(fresh.minorStep));
    });

    test('rejects a target on or behind the camera plane', () {
      const convention = _conventionZ;
      expect(
        () => GroundPlaneFactory.create(
          convention: convention,
          patch: const CircularGroundPatch(radius: 10),
          format: DisplayFormat.metric,
          worldUnits: UnitSystem.metric,
          camera: _camera(convention, vm.Vector3.zero(), 10),
          target: _camera(convention, vm.Vector3.zero(), 20).position,
          verticalFovRadians: _fov,
          viewportHeight: _viewportHeight,
          resolveText: fakeTextResolver,
          minorKey: null,
          majorKey: null,
          labelKey: null,
        ),
        throwsArgumentError,
      );
    });
  });
}

const _conventionZ = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.right,
);
