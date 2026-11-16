import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// The golden-vector tolerance of §spec:golden-vectors.
const _tolerance = 1e-9;

Matcher _closeToVector(vm.Vector3 expected) => predicate<vm.Vector3>(
  (actual) => (actual - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

final _conventions = [
  for (final up in SpatialAxis.values)
    for (final handedness in Handedness.values)
      CoordinateConvention(up: up, handedness: handedness),
];

void main() {
  group('CoordinateConvention', () {
    test('fallbackAxis is a different axis from up', () {
      for (final convention in _conventions) {
        expect(
          convention.fallbackAxis,
          isNot(convention.up),
          reason: '$convention',
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

    test('cross follows the declared hand rule', () {
      final expected = {
        Handedness.right: vm.Vector3(0, 0, 1),
        Handedness.left: vm.Vector3(0, 0, -1),
      };
      for (final MapEntry(key: handedness, value: z) in expected.entries) {
        final convention = CoordinateConvention(
          up: SpatialAxis.y,
          handedness: handedness,
        );
        expect(
          convention.cross(vm.Vector3(1, 0, 0), vm.Vector3(0, 1, 0)),
          _closeToVector(z),
          reason: '$convention',
        );
      }
    });

    test('describes itself by up axis and handedness', () {
      const convention = CoordinateConvention(
        up: SpatialAxis.z,
        handedness: Handedness.left,
      );
      expect('$convention', 'Z-up left-handed');
    });
  });
}
