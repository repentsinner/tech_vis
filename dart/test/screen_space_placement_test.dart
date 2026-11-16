import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// The golden-vector tolerance of §spec:golden-vectors.
const _tolerance = 1e-9;
const _pixelTolerance = 1e-9;
const _fov = math.pi / 4;
const _viewportHeight = 1080.0;

/// Projects [point] through a pinhole camera and returns its pixel
/// position relative to the viewport center, y up.
vm.Vector2 _project(vm.Vector3 point, CameraBasis camera) {
  final focalPixels = (_viewportHeight / 2.0) / math.tan(_fov / 2.0);
  final relative = point - camera.position;
  final depth = relative.dot(camera.forward);
  return vm.Vector2(
    relative.dot(camera.right) * focalPixels / depth,
    relative.dot(camera.up) * focalPixels / depth,
  );
}

Matcher _closeToVector(vm.Vector3 expected) => predicate<vm.Vector3>(
  (actual) => (actual - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

const _yUpRightHanded = CoordinateConvention(
  up: SpatialAxis.y,
  handedness: Handedness.right,
);

const _zUpRightHanded = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.right,
);

void _expectOrthonormal(CameraBasis basis) {
  expect(basis.right.length, closeTo(1.0, _tolerance));
  expect(basis.up.length, closeTo(1.0, _tolerance));
  expect(basis.right.dot(basis.forward), closeTo(0.0, _tolerance));
  expect(basis.up.dot(basis.forward), closeTo(0.0, _tolerance));
  expect(basis.right.dot(basis.up), closeTo(0.0, _tolerance));
}

void main() {
  final camera = CameraBasis.lookAt(
    position: vm.Vector3.zero(),
    target: vm.Vector3(0, 0, -100),
    convention: _yUpRightHanded,
  );

  group('CameraBasis.lookAt', () {
    test('forms a right-handed orthonormal basis facing the target', () {
      expect(camera.forward, _closeToVector(vm.Vector3(0, 0, -1)));
      expect(camera.right, _closeToVector(vm.Vector3(1, 0, 0)));
      expect(camera.up, _closeToVector(vm.Vector3(0, 1, 0)));
      expect(camera.toViewer, _closeToVector(vm.Vector3(0, 0, 1)));
    });

    test('falls back to the fallback axis when looking along world up', () {
      final down = CameraBasis.lookAt(
        position: vm.Vector3(0, 100, 0),
        target: vm.Vector3.zero(),
        convention: _yUpRightHanded,
      );
      _expectOrthonormal(down);
      expect(
        down.up.cross(_yUpRightHanded.fallbackAxis.unitVector).length,
        closeTo(0.0, _tolerance),
      );
    });

    test('orients a Z-up camera with +Z up on screen', () {
      final front = CameraBasis.lookAt(
        position: vm.Vector3(0, -100, 0),
        target: vm.Vector3.zero(),
        convention: _zUpRightHanded,
      );
      expect(front.forward, _closeToVector(vm.Vector3(0, 1, 0)));
      expect(front.right, _closeToVector(vm.Vector3(1, 0, 0)));
      expect(front.up, _closeToVector(vm.Vector3(0, 0, 1)));
    });

    test('a Z-up top view keeps +Y up on screen', () {
      final top = CameraBasis.lookAt(
        position: vm.Vector3(0, 0, 100),
        target: vm.Vector3.zero(),
        convention: _zUpRightHanded,
      );
      _expectOrthonormal(top);
      expect(top.up, _closeToVector(vm.Vector3(0, 1, 0)));
      expect(top.right, _closeToVector(vm.Vector3(1, 0, 0)));
    });

    test('a left-handed camera puts screen right by the left-hand rule', () {
      // Y up, looking down +Z: screen right is +X in a left-handed space.
      const leftHanded = CoordinateConvention(
        up: SpatialAxis.y,
        handedness: Handedness.left,
      );
      final basis = CameraBasis.lookAt(
        position: vm.Vector3.zero(),
        target: vm.Vector3(0, 0, 100),
        convention: leftHanded,
      );
      expect(basis.forward, _closeToVector(vm.Vector3(0, 0, 1)));
      expect(basis.right, _closeToVector(vm.Vector3(1, 0, 0)));
      expect(basis.up, _closeToVector(vm.Vector3(0, 1, 0)));
      // right, up, forward follow the declared hand rule.
      expect(
        leftHanded.cross(basis.right, basis.up),
        _closeToVector(basis.toViewer),
      );
    });

    test('right, up, toward-viewer follow the declared hand rule', () {
      final target = vm.Vector3(3, -2, 5);
      final eye = vm.Vector3(40, 25, -30);
      for (final up in SpatialAxis.values) {
        for (final handedness in Handedness.values) {
          final convention = CoordinateConvention(
            up: up,
            handedness: handedness,
          );
          final reason = '$convention';
          final basis = CameraBasis.lookAt(
            position: eye,
            target: target,
            convention: convention,
          );
          _expectOrthonormal(basis);
          expect(
            convention.cross(basis.right, basis.up),
            _closeToVector(basis.toViewer),
            reason: reason,
          );
          expect(
            basis.up.dot(convention.up.unitVector),
            greaterThan(0),
            reason: reason,
          );
        }
      }
    });

    test('depthOf measures along the view axis, not straight-line', () {
      // 40° off axis at depth 100: straight-line distance is 100/cos(40°).
      final offAxis = vm.Vector3(100 * math.tan(40 * math.pi / 180), 0, -100);
      expect(camera.depthOf(offAxis), closeTo(100.0, _tolerance));
    });
  });

  group('ScreenSpaceUtils.worldUnitsPerPixelAt', () {
    test('matches pixelSizeToWorldSize for a point on the view axis', () {
      final scale = ScreenSpaceUtils.worldUnitsPerPixelAt(
        vm.Vector3(0, 0, -100),
        camera,
        _fov,
        _viewportHeight,
      );
      final expected = ScreenSpaceUtils.pixelSizeToWorldSize(
        1,
        100,
        _fov,
        vm.Vector2(1920, _viewportHeight),
      );
      expect(scale, closeTo(expected, _tolerance));
    });

    test('keeps a callout leader the same pixel length off axis', () {
      // An 80 px leader drawn at the screen center and 40° off to the
      // side measures 80 px on screen at both places.
      for (final degrees in const [0.0, 20.0, 40.0, 60.0]) {
        final anchor = vm.Vector3(
          100 * math.tan(degrees * math.pi / 180),
          0,
          -100,
        );
        final scale = ScreenSpaceUtils.worldUnitsPerPixelAt(
          anchor,
          camera,
          _fov,
          _viewportHeight,
        )!;
        final leaderEnd = anchor + camera.right * (80 * scale);
        final drawn = _project(leaderEnd, camera) - _project(anchor, camera);
        expect(
          drawn.length,
          closeTo(80.0, _pixelTolerance),
          reason: '$degrees°',
        );
      }
    });

    test('returns null for a point at or behind the camera plane', () {
      for (final point in [vm.Vector3(5, 0, 0), vm.Vector3(0, 0, 10)]) {
        expect(
          ScreenSpaceUtils.worldUnitsPerPixelAt(
            point,
            camera,
            _fov,
            _viewportHeight,
          ),
          isNull,
        );
      }
    });
  });

  group('billboard transforms', () {
    test('screenAlignedRotation maps quad axes to camera axes', () {
      final rotation = screenAlignedRotation(camera);
      expect(
        rotation.transformed3(vm.Vector3(1, 0, 0)),
        _closeToVector(camera.right),
      );
      expect(
        rotation.transformed3(vm.Vector3(0, 1, 0)),
        _closeToVector(camera.up),
      );
      expect(
        rotation.transformed3(vm.Vector3(0, 0, 1)),
        _closeToVector(camera.toViewer),
      );
    });

    test('billboardTransform scales, faces the viewer, and translates', () {
      final position = vm.Vector3(10, 20, -100);
      final transform = billboardTransform(
        position: position,
        camera: camera,
        scale: 2,
      );
      expect(
        transform.transformed3(vm.Vector3(1, 0, 0)),
        _closeToVector(position + camera.right * 2),
      );
    });

    test('projectOntoScreenPlane removes the view-axis component', () {
      final projected = projectOntoScreenPlane(vm.Vector3(1, 2, 3), camera);
      expect(projected, _closeToVector(vm.Vector3(1, 2, 0)));
    });

    test('billboardOffsetPosition offsets by pixels along the screen', () {
      final anchor = vm.Vector3(0, 0, -100);
      final offset = billboardOffsetPosition(
        anchor: anchor,
        direction: vm.Vector3(0, 1, 5),
        offsetPixels: 10,
        worldUnitsPerPixel: 0.5,
        camera: camera,
      );
      expect(offset, _closeToVector(vm.Vector3(0, 5, -100)));
    });

    test('billboardOffsetPosition stays at the anchor along the view axis', () {
      final anchor = vm.Vector3(0, 0, -100);
      final offset = billboardOffsetPosition(
        anchor: anchor,
        direction: vm.Vector3(0, 0, 1),
        offsetPixels: 10,
        worldUnitsPerPixel: 0.5,
        camera: camera,
      );
      expect(offset, _closeToVector(anchor));
    });
  });

  group('calloutLabelCorners', () {
    test('a right-hand label extends right of its edge, centered on it', () {
      final edge = vm.Vector3(0, 0, -100);
      final corners = calloutLabelCorners(
        labelEdge: edge,
        quadrant: CalloutQuadrant.topRight,
        aspectRatio: 3,
        scale: 2,
        camera: camera,
      );
      expect(corners.bottomLeft, _closeToVector(vm.Vector3(0, -1, -100)));
      expect(corners.bottomRight, _closeToVector(vm.Vector3(6, -1, -100)));
      expect(corners.topRight, _closeToVector(vm.Vector3(6, 1, -100)));
      expect(corners.topLeft, _closeToVector(vm.Vector3(0, 1, -100)));
    });

    test('a left-hand label extends left of its edge', () {
      final corners = calloutLabelCorners(
        labelEdge: vm.Vector3(0, 0, -100),
        quadrant: CalloutQuadrant.bottomLeft,
        aspectRatio: 3,
        scale: 2,
        camera: camera,
      );
      expect(corners.bottomLeft, _closeToVector(vm.Vector3(-6, -1, -100)));
      expect(corners.topRight, _closeToVector(vm.Vector3(0, 1, -100)));
    });

    test('towardViewer lifts every corner off the label plane', () {
      final corners = calloutLabelCorners(
        labelEdge: vm.Vector3(0, 0, -100),
        quadrant: CalloutQuadrant.topRight,
        aspectRatio: 1,
        scale: 1,
        camera: camera,
        towardViewer: 0.5,
      );
      expect(corners.topLeft.z, closeTo(-99.5, _tolerance));
    });
  });

  group('lineSegmentTransform', () {
    test('maps the unit X segment onto the world segment', () {
      final from = vm.Vector3(1, 2, 3);
      final to = vm.Vector3(4, 6, 3);
      final transform = lineSegmentTransform(from, to);
      expect(transform.transformed3(vm.Vector3.zero()), _closeToVector(from));
      expect(transform.transformed3(vm.Vector3(1, 0, 0)), _closeToVector(to));
    });

    test('handles a segment along the X axis', () {
      final transform = lineSegmentTransform(
        vm.Vector3.zero(),
        vm.Vector3(5, 0, 0),
      );
      expect(
        transform.transformed3(vm.Vector3(1, 0, 0)),
        _closeToVector(vm.Vector3(5, 0, 0)),
      );
    });
  });

  group('drawRanksByDistance', () {
    test('ranks the farthest lowest and the nearest highest', () {
      final ranks = drawRanksByDistance(const {
        'near': 10,
        'mid': 50,
        'far': 90,
      }, maxRank: 7);
      expect(ranks, {'far': 1, 'mid': 2, 'near': 3});
    });

    test('breaks distance ties by id', () {
      final ranks = drawRanksByDistance(const {'b': 5, 'a': 5}, maxRank: 7);
      expect(ranks, {'a': 1, 'b': 2});
    });

    test('clamps to maxRank, so extras share the top rank', () {
      final ranks = drawRanksByDistance(const {
        'a': 4,
        'b': 3,
        'c': 2,
        'd': 1,
      }, maxRank: 2);
      expect(ranks, {'a': 1, 'b': 2, 'c': 2, 'd': 2});
    });

    test('starts at minRank', () {
      final ranks = drawRanksByDistance(
        const {'a': 2, 'b': 1},
        minRank: 0,
        maxRank: 7,
      );
      expect(ranks, {'a': 0, 'b': 1});
    });

    test('returns an empty map for no callouts', () {
      expect(drawRanksByDistance(const {}, maxRank: 7), isEmpty);
    });
  });
}
