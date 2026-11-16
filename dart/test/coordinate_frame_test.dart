import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('SpatialAxis', () {
    test('has three values', () {
      expect(SpatialAxis.values, hasLength(3));
    });

    test('unitVector returns correct directions', () {
      expect(SpatialAxis.x.unitVector, Vector3(1, 0, 0));
      expect(SpatialAxis.y.unitVector, Vector3(0, 1, 0));
      expect(SpatialAxis.z.unitVector, Vector3(0, 0, 1));
    });

    test('label returns uppercase axis letter', () {
      expect(SpatialAxis.x.label, 'X');
      expect(SpatialAxis.y.label, 'Y');
      expect(SpatialAxis.z.label, 'Z');
    });
  });

  group('SignedAxis', () {
    for (final axis in SpatialAxis.values) {
      test('${axis.label} runs along its axis, both ways', () {
        expect(SignedAxis(axis).unitVector, axis.unitVector);
        expect(SignedAxis(axis, negative: true).unitVector, -axis.unitVector);
      });

      test('negating ${axis.label} flips it and flips back', () {
        expect(-SignedAxis(axis), SignedAxis(axis, negative: true));
        expect(-(-SignedAxis(axis)), SignedAxis(axis));
      });
    }

    test('names its sign and axis', () {
      expect('${const SignedAxis(SpatialAxis.y, negative: true)}', '-Y');
      expect('${const SignedAxis(SpatialAxis.z)}', '+Z');
    });
  });

  group('CoordinateFrameDescriptor', () {
    test('default constructor creates standard frame', () {
      final frame = CoordinateFrameDescriptor();
      expect(frame.origin, Vector3.zero());
      expect(frame.length, SceneLayoutConstants.axisLength);
      expect(
        frame.lineThickness,
        SceneLayoutConstants.defaultAxisLineThickness,
      );
      expect(frame.showLabels, isTrue);
      expect(frame.axes, hasLength(3));
    });

    test('custom origin is stored', () {
      final origin = Vector3(10, 20, 30);
      final frame = CoordinateFrameDescriptor(origin: origin);
      expect(frame.origin, origin);
    });

    test('custom length and thickness', () {
      final frame = CoordinateFrameDescriptor(
        length: 100.0,
        lineThickness: 2.0,
      );
      expect(frame.length, 100.0);
      expect(frame.lineThickness, 2.0);
    });

    test('labels can be disabled', () {
      final frame = CoordinateFrameDescriptor(showLabels: false);
      expect(frame.showLabels, isFalse);
    });

    test('axes returns descriptors for all three axes', () {
      final frame = CoordinateFrameDescriptor(
        origin: Vector3(5, 5, 5),
        length: 30.0,
      );

      final axes = frame.axes;
      expect(axes, hasLength(3));

      // Each axis starts at origin
      for (final axis in axes) {
        expect(axis.start, Vector3(5, 5, 5));
      }

      // Endpoints extend along the correct direction
      expect(axes[0].end, Vector3(35, 5, 5)); // X
      expect(axes[1].end, Vector3(5, 35, 5)); // Y
      expect(axes[2].end, Vector3(5, 5, 35)); // Z
    });

    test('axes carry correct axis identity', () {
      final frame = CoordinateFrameDescriptor();
      final axes = frame.axes;
      expect(axes[0].axis, SpatialAxis.x);
      expect(axes[1].axis, SpatialAxis.y);
      expect(axes[2].axis, SpatialAxis.z);
    });

    test('labelPixelSize defaults from SceneLayoutConstants', () {
      final frame = CoordinateFrameDescriptor();
      expect(frame.labelPixelSize, SceneLayoutConstants.defaultAxisLabelSize);
    });

    test('labelOffsetPixels defaults from SceneLayoutConstants', () {
      final frame = CoordinateFrameDescriptor();
      expect(
        frame.labelOffsetPixels,
        SceneLayoutConstants.axisLabelOffsetPixels,
      );
    });
  });

  group('AxisLineDescriptor', () {
    test('stores axis, start, end, thickness', () {
      final desc = AxisLineDescriptor(
        axis: SpatialAxis.x,
        start: Vector3.zero(),
        end: Vector3(50, 0, 0),
        thickness: 1.0,
      );
      expect(desc.axis, SpatialAxis.x);
      expect(desc.start, Vector3.zero());
      expect(desc.end, Vector3(50, 0, 0));
      expect(desc.thickness, 1.0);
    });

    test('label returns axis label', () {
      final desc = AxisLineDescriptor(
        axis: SpatialAxis.z,
        start: Vector3.zero(),
        end: Vector3(0, 0, 50),
        thickness: 1.0,
      );
      expect(desc.label, 'Z');
    });

    test('direction returns unit vector', () {
      final desc = AxisLineDescriptor(
        axis: SpatialAxis.y,
        start: Vector3.zero(),
        end: Vector3(0, 50, 0),
        thickness: 1.0,
      );
      expect(desc.direction, Vector3(0, 1, 0));
    });
  });
}
