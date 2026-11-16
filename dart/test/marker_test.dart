import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/pinhole.dart';

// The golden-vector tolerance of §spec:golden-vectors.
const _tolerance = 1e-9;

// Mesh buffers are 32-bit, so a stored coordinate sits within one
// single-precision rounding of the 64-bit value it was generated from.
const _float32Tolerance = 1e-6;

const _fov = math.pi / 4;
const _viewportHeight = 1080.0;

// The sphere looks the same about any up axis, so only the handedness
// changes the mesh.
final _oneConventionPerHand = [
  for (final handedness in Handedness.values)
    CoordinateConvention(up: SpatialAxis.y, handedness: handedness),
];

const _yUpRightHanded = CoordinateConvention(
  up: SpatialAxis.y,
  handedness: Handedness.right,
);

vm.Vector3 _vertex(List<double> buffer, int index) =>
    vm.Vector3(buffer[index * 3], buffer[index * 3 + 1], buffer[index * 3 + 2]);

vm.Vector2 _project(vm.Vector3 point, CameraBasis camera) => projectPinhole(
  point,
  camera,
  verticalFovRadians: _fov,
  viewportHeight: _viewportHeight,
);

void main() {
  group('MarkerFactory.sphereMesh', () {
    for (final convention in _oneConventionPerHand) {
      group('$convention', () {
        final mesh = MarkerFactory.sphereMesh(convention);

        test('places every vertex at unit radius', () {
          for (var i = 0; i < mesh.vertexCount; i++) {
            expect(
              _vertex(mesh.positions, i).length,
              closeTo(1.0, _float32Tolerance),
              reason: 'vertex $i',
            );
          }
        });

        test('uses each unit position as its outward normal', () {
          expect(mesh.normals, orderedEquals(mesh.positions));
        });

        test('winds every triangle outward by the declared hand rule', () {
          final indices = mesh.indices;
          expect(indices.every((i) => i < mesh.vertexCount), isTrue);
          for (var t = 0; t < mesh.triangleCount; t++) {
            final a = _vertex(mesh.positions, indices[t * 3]);
            final b = _vertex(mesh.positions, indices[t * 3 + 1]);
            final c = _vertex(mesh.positions, indices[t * 3 + 2]);
            final faceNormal = convention.cross(b - a, c - a);
            final centroid = (a + b + c) / 3.0;
            expect(faceNormal.dot(centroid), greaterThan(0), reason: 'tri $t');
          }
        });
      });
    }

    test('uses the style token level of detail', () {
      final subdivisions = StyleTokens.markerSubdivisions.toInt();
      final faces = 20 * math.pow(4, subdivisions);
      final mesh = MarkerFactory.sphereMesh(_yUpRightHanded);
      expect(mesh.triangleCount, faces);
      expect(mesh.vertexCount, faces ~/ 2 + 2);
    });

    test('shares one mesh per convention', () {
      expect(
        identical(
          MarkerFactory.sphereMesh(_yUpRightHanded),
          MarkerFactory.sphereMesh(_yUpRightHanded),
        ),
        isTrue,
      );
    });
  });

  group('MarkerFactory.create', () {
    test('builds a marker with the generated mesh and the app key', () {
      final marker = MarkerFactory.create(
        position: vm.Vector3(1, 2, 3),
        convention: _yUpRightHanded,
        key: 'probe',
        diameterPixels: 12,
        opacity: 0.5,
      );
      expect(marker.position, vm.Vector3(1, 2, 3));
      expect(marker.diameterPixels, 12);
      expect(marker.key, 'probe');
      expect(marker.opacity, 0.5);
      expect(
        identical(marker.mesh, MarkerFactory.sphereMesh(_yUpRightHanded)),
        isTrue,
      );
    });

    test('defaults to the style token diameter', () {
      final marker = MarkerFactory.create(
        position: vm.Vector3.zero(),
        convention: _yUpRightHanded,
        key: null,
      );
      expect(marker.diameterPixels, StyleTokens.markerDiameterPixels);
    });
  });

  group('MarkerFactory.transform', () {
    final camera = CameraBasis.lookAt(
      position: vm.Vector3.zero(),
      target: vm.Vector3(0, 0, -1),
      convention: _yUpRightHanded,
    );

    for (final depth in [10.0, 1000.0]) {
      test('keeps the pixel diameter at depth $depth', () {
        const diameterPixels = 9.0;
        // Off the view axis, where sizing by distance would oversize it.
        final center = vm.Vector3(depth * 0.3, -depth * 0.2, -depth);
        final marker = MarkerFactory.create(
          position: center,
          convention: _yUpRightHanded,
          key: null,
          diameterPixels: diameterPixels,
        );
        final transform = MarkerFactory.transform(
          marker,
          camera,
          _fov,
          _viewportHeight,
        )!;

        // The sphere's screen-aligned extremes, through the transform.
        final right = transform.transformed3(camera.right.clone());
        final left = transform.transformed3(-camera.right);
        final top = transform.transformed3(camera.up.clone());
        final bottom = transform.transformed3(-camera.up);

        expect(
          (transform.transformed3(vm.Vector3.zero()) - center).length,
          closeTo(0.0, _tolerance),
        );
        // A sphere's silhouette is wider than the projection of its
        // screen-aligned diameter by a second-order term, so measure in
        // the plane through its center that faces the camera.
        expect(
          (_project(right, camera) - _project(left, camera)).length,
          closeTo(diameterPixels, _tolerance),
        );
        expect(
          (_project(top, camera) - _project(bottom, camera)).length,
          closeTo(diameterPixels, _tolerance),
        );
      });
    }

    test('returns null on or behind the camera plane', () {
      for (final z in [0.0, 5.0]) {
        final marker = MarkerFactory.create(
          position: vm.Vector3(1, 0, z),
          convention: _yUpRightHanded,
          key: null,
        );
        expect(
          MarkerFactory.transform(marker, camera, _fov, _viewportHeight),
          isNull,
        );
      }
    });
  });
}
