import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// The golden-vector tolerance of §spec:golden-vectors.
const _tolerance = 1e-9;

Matcher _closeToVector(vm.Vector3 expected) => predicate<vm.Vector3>(
  (actual) => (actual - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

const _conventions = [
  CoordinateConvention(up: SpatialAxis.y, handedness: Handedness.right),
  CoordinateConvention(up: SpatialAxis.y, handedness: Handedness.left),
  CoordinateConvention(up: SpatialAxis.z, handedness: Handedness.right),
  CoordinateConvention(up: SpatialAxis.z, handedness: Handedness.left),
  CoordinateConvention(up: SpatialAxis.x, handedness: Handedness.right),
  CoordinateConvention(up: SpatialAxis.x, handedness: Handedness.left),
];

String _describe(CoordinateConvention c) =>
    '${c.up.label}-up ${c.handedness.name}-handed';

void main() {
  group('CoordinateConvention', () {
    test('upVector is the unit vector of the declared up axis', () {
      for (final convention in _conventions) {
        expect(
          convention.upVector,
          _closeToVector(convention.up.unitVector),
          reason: _describe(convention),
        );
      }
    });

    test('fallbackAxis is a different axis from up', () {
      for (final convention in _conventions) {
        expect(
          convention.fallbackAxis,
          isNot(convention.up),
          reason: _describe(convention),
        );
      }
    });

    test('a Z-up fallback is Y, so a top view keeps +Y up on screen', () {
      const zUp = CoordinateConvention(
        up: SpatialAxis.z,
        handedness: Handedness.right,
      );
      expect(zUp.fallbackAxis, SpatialAxis.y);
    });

    test('cross follows the right-hand rule when right-handed', () {
      const rightHanded = CoordinateConvention(
        up: SpatialAxis.y,
        handedness: Handedness.right,
      );
      expect(
        rightHanded.cross(vm.Vector3(1, 0, 0), vm.Vector3(0, 1, 0)),
        _closeToVector(vm.Vector3(0, 0, 1)),
      );
    });

    test('cross reverses its sign when left-handed', () {
      const leftHanded = CoordinateConvention(
        up: SpatialAxis.y,
        handedness: Handedness.left,
      );
      expect(
        leftHanded.cross(vm.Vector3(1, 0, 0), vm.Vector3(0, 1, 0)),
        _closeToVector(vm.Vector3(0, 0, -1)),
      );
    });
  });

  group('CoordinateConvention.windOutward', () {
    // One face of a unit cube, on the plane z = 1, whose outward normal is
    // +Z. Listed counter-clockwise when read with the right-hand rule.
    final positions = [
      vm.Vector3(0, 0, 1),
      vm.Vector3(1, 0, 1),
      vm.Vector3(0, 1, 1),
    ];
    final outward = vm.Vector3(0, 0, 1);

    test('keeps an already outward order unchanged when right-handed', () {
      const convention = CoordinateConvention(
        up: SpatialAxis.y,
        handedness: Handedness.right,
      );
      expect(convention.windOutward(positions, 0, 1, 2, outward), (0, 1, 2));
      expect(convention.windOutward(positions, 0, 2, 1, outward), (0, 1, 2));
    });

    test('reverses the order when left-handed', () {
      const convention = CoordinateConvention(
        up: SpatialAxis.y,
        handedness: Handedness.left,
      );
      expect(convention.windOutward(positions, 0, 1, 2, outward), (0, 2, 1));
      expect(convention.windOutward(positions, 0, 2, 1, outward), (0, 2, 1));
    });

    test('the handed normal of the wound triangle points outward', () {
      for (final convention in _conventions) {
        for (final normal in [outward, -outward]) {
          final (a, b, c) = convention.windOutward(positions, 0, 1, 2, normal);
          final faceNormal = convention.cross(
            positions[b] - positions[a],
            positions[c] - positions[a],
          );
          expect(
            faceNormal.dot(normal),
            greaterThan(0),
            reason: '${_describe(convention)}, outward $normal',
          );
        }
      }
    });
  });
}
