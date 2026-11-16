import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'support/vectors.dart';

const _yUpRight = CoordinateConvention(
  up: SpatialAxis.y,
  handedness: Handedness.right,
);
const _yUpLeft = CoordinateConvention(
  up: SpatialAxis.y,
  handedness: Handedness.left,
);
const _zUpRight = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.right,
);
const _zUpLeft = CoordinateConvention(
  up: SpatialAxis.z,
  handedness: Handedness.left,
);

const _conventions = [_yUpRight, _yUpLeft, _zUpRight, _zUpLeft];

/// The default placement's rectangle in a 1280 x 720 viewport.
final _rect = ViewportOverlayPlacement.of(
  ViewportOverlayKind.navigationCube,
).rect(vm.Vector2(1280, 720));

typedef _Normals = ({
  CoordinateConvention convention,
  vm.Vector3 front,
  vm.Vector3 right,
});

final _normals = <_Normals>[
  (
    convention: _yUpRight,
    front: vm.Vector3(-1, 0, 0),
    right: vm.Vector3(0, 0, 1),
  ),
  (
    convention: _yUpLeft,
    front: vm.Vector3(-1, 0, 0),
    right: vm.Vector3(0, 0, -1),
  ),
  (
    convention: _zUpRight,
    front: vm.Vector3(0, -1, 0),
    right: vm.Vector3(1, 0, 0),
  ),
  (
    convention: _zUpLeft,
    front: vm.Vector3(0, -1, 0),
    right: vm.Vector3(-1, 0, 0),
  ),
];

void _expectVector(vm.Vector3 actual, vm.Vector3 expected, String reason) =>
    expectNumbers(List.of(actual.storage), List.of(expected.storage), reason);

CameraBasis _camera(CoordinateConvention c, vm.Vector3 offset) =>
    CameraBasis.lookAt(
      position: offset,
      target: vm.Vector3.zero(),
      convention: c,
    );

typedef _View = ({
  String name,
  vm.Vector3 offset,
  List<NavigationCubeFace> faces,
});

vm.Vector2 _center(List<vm.Vector2> corners) =>
    corners.fold(vm.Vector2.zero(), (sum, p) => sum + p) /
    corners.length.toDouble();

void main() {
  group('NavigationCube faces', () {
    for (final (:convention, :front, :right) in _normals) {
      final cube = NavigationCube(convention: convention);
      final up = convention.up.unitVector;

      test('$convention: Top is the up axis, Front faces away from the '
          'fallback axis', () {
        final expected = {
          NavigationCubeFace.top: up,
          NavigationCubeFace.bottom: -up,
          NavigationCubeFace.front: front,
          NavigationCubeFace.back: -front,
          NavigationCubeFace.right: right,
          NavigationCubeFace.left: -right,
        };
        for (final MapEntry(key: face, value: normal) in expected.entries) {
          _expectVector(cube.normal(face), normal, face.name);
        }
      });

      test('$convention: each face text frame follows the hand rule', () {
        for (final face in NavigationCubeFace.values) {
          _expectVector(
            convention.cross(cube.textRight(face), cube.textUp(face)),
            cube.normal(face),
            face.name,
          );
        }
        _expectVector(cube.textUp(NavigationCubeFace.front), up, 'front');
        _expectVector(cube.textUp(NavigationCubeFace.top), -front, 'top');
      });
    }
  });

  test('face labels name the faces', () {
    expect(NavigationCubeFace.values.map((f) => f.label), [
      'TOP',
      'BOTTOM',
      'FRONT',
      'BACK',
      'LEFT',
      'RIGHT',
    ]);
  });

  group('NavigationCube.visibleFaces', () {
    for (final convention in _conventions) {
      final cube = NavigationCube(convention: convention);
      final up = convention.up.unitVector;
      final front = cube.normal(NavigationCubeFace.front);
      final right = cube.normal(NavigationCubeFace.right);
      final rectCenter = vm.Vector2(
        (_rect.left + _rect.right) / 2,
        (_rect.top + _rect.bottom) / 2,
      );

      final views = <_View>[
        (name: 'top', offset: up * 10, faces: [NavigationCubeFace.top]),
        (name: 'bottom', offset: -up * 10, faces: [NavigationCubeFace.bottom]),
        (name: 'front', offset: front * 10, faces: [NavigationCubeFace.front]),
        (name: 'right', offset: right * 10, faces: [NavigationCubeFace.right]),
        (
          name: 'front-right-top, top most direct',
          offset: front * 2 + right * 3 + up * 4,
          faces: [
            NavigationCubeFace.front,
            NavigationCubeFace.right,
            NavigationCubeFace.top,
          ],
        ),
        (
          name: 'back-left-top diagonal, tied faces in face order',
          offset: (-front - right + up) * 3,
          faces: [
            NavigationCubeFace.top,
            NavigationCubeFace.back,
            NavigationCubeFace.left,
          ],
        ),
      ];

      for (final (:name, :offset, :faces) in views) {
        test('$convention, $name view: faces facing the viewer, least '
            'direct first', () {
          final seen = cube.visibleFaces(_camera(convention, offset), _rect);
          expect(seen.map((v) => v.face), faces);
          for (var i = 1; i < seen.length; i++) {
            expect(
              seen[i].facing,
              greaterThan(seen[i - 1].facing - vectorTolerance),
            );
          }
        });
      }

      test('$convention: an axis view shows its face as an upright square '
          'filling the inscribed size', () {
        for (final face in NavigationCubeFace.values) {
          final camera = _camera(convention, cube.normal(face) * 10);
          final [view] = cube.visibleFaces(camera, _rect);
          final [bl, br, tr, tl] = view.corners;
          final edge =
              2 *
              math.min(_rect.right - _rect.left, _rect.bottom - _rect.top) /
              (2 * math.sqrt(3));
          expect(view.facing, closeTo(1, vectorTolerance), reason: face.name);
          expectNumbers([br.x - bl.x, br.y - bl.y], [edge, 0], face.name);
          expectNumbers([tl.x - bl.x, tl.y - bl.y], [0, -edge], face.name);
          expectNumbers([tr.x - tl.x, tr.y - tl.y], [edge, 0], face.name);
          expectNumbers(
            List.of(_center(view.corners).storage),
            List.of(rectCenter.storage),
            face.name,
          );
        }
      });

      test('$convention: the top view puts Front along the bottom edge', () {
        final camera = _camera(convention, up * 10);
        final [top] = cube.visibleFaces(camera, _rect);
        final [bl, br, _, _] = top.corners;
        // The bottom edge of the Top label is the edge Top shares with
        // Front: both its corners lie on the Front side of the cube.
        expect(bl.y, closeTo(br.y, vectorTolerance));
        expect(bl.y, greaterThan(rectCenter.y));
      });

      test('$convention: every corner stays inside the rectangle', () {
        for (final offset in [
          vm.Vector3(1, 1, 1),
          vm.Vector3(-3, 0.5, 2),
          vm.Vector3(0.2, -4, -1),
          up * 5 + front * 0.01,
        ]) {
          for (final view in cube.visibleFaces(
            _camera(convention, offset),
            _rect,
          )) {
            for (final p in view.corners) {
              expect(p.x, inInclusiveRange(_rect.left, _rect.right));
              expect(p.y, inInclusiveRange(_rect.top, _rect.bottom));
            }
          }
        }
      });
    }
  });

  group('NavigationCube front', () {
    test('an app-named front replaces the derived one', () {
      final cube = NavigationCube(
        convention: _yUpRight,
        front: vm.Vector3(0, 0, 1),
      );
      _expectVector(
        cube.normal(NavigationCubeFace.front),
        vm.Vector3(0, 0, 1),
        'front',
      );
      _expectVector(
        cube.normal(NavigationCubeFace.right),
        vm.Vector3(1, 0, 0),
        'right',
      );
      _expectVector(
        cube.textUp(NavigationCubeFace.top),
        vm.Vector3(0, 0, -1),
        'top text up',
      );
    });

    for (final (name, front) in [
      ('along the up axis', vm.Vector3(0, 1, 0)),
      ('against the up axis', vm.Vector3(0, -1, 0)),
      ('off every axis', vm.Vector3(0.6, 0, 0.8)),
      ('not unit length', vm.Vector3(2, 0, 0)),
      ('zero', vm.Vector3.zero()),
    ]) {
      test('a front $name throws', () {
        expect(
          () => NavigationCube(convention: _yUpRight, front: front),
          throwsArgumentError,
        );
      });
    }
  });
}
