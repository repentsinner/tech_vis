import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('CoordinateFrameFactory.create', () {
    final frame = CoordinateFrameDescriptor(
      origin: Vector3(10, 20, 30),
      length: 5,
      lineThickness: 0.4,
      labelPixelSize: 18,
      labelOffsetPixels: 6,
    );
    String category(SpatialAxis axis) => 'axis_${axis.name}';
    final objects = CoordinateFrameFactory.create(
      frame,
      lineCategoryFor: category,
      labelType: 'axisLabel',
      idPrefix: 'work',
    );
    final lines = objects.where((o) => o.type == SceneObjectType.line).toList();
    final labels = objects
        .where((o) => o.type == SceneObjectType.textBillboard)
        .toList();

    test('draws one line per axis from the origin', () {
      expect(lines.map((l) => l.id), ['work_x', 'work_y', 'work_z']);
      for (final (i, axis) in SpatialAxis.values.indexed) {
        expect(lines[i].startPoint, Vector3(10, 20, 30));
        expect(lines[i].endPoint, Vector3(10, 20, 30) + axis.unitVector * 5);
        expect(lines[i].thickness, 0.4);
        expect(lines[i].lineCategory, category(axis));
      }
    });

    test('labels each axis end, offset in pixels along the axis', () {
      expect(labels.map((l) => l.text), ['X', 'Y', 'Z']);
      expect(labels.map((l) => l.id), [
        'work_label_x',
        'work_label_y',
        'work_label_z',
      ]);
      for (final (i, axis) in SpatialAxis.values.indexed) {
        expect(labels[i].center, lines[i].endPoint);
        expect(labels[i].billboardAnchorDirection, axis.unitVector);
        expect(labels[i].billboardOffsetPixels, 6);
        expect(labels[i].worldSize, 18);
        expect(labels[i].labelType, 'axisLabel');
        expect(labels[i].lineCategory, category(axis));
      }
    });

    test('omits labels when the frame hides them', () {
      final bare = CoordinateFrameFactory.create(
        CoordinateFrameDescriptor(showLabels: false),
        lineCategoryFor: category,
      );
      expect(bare, hasLength(3));
      expect(bare.every((o) => o.type == SceneObjectType.line), isTrue);
      expect(bare.first.id, 'frame_x');
    });

    test('places a frame at any origin', () {
      final at = CoordinateFrameFactory.create(
        CoordinateFrameDescriptor(origin: Vector3(-1, -2, -3), length: 1),
        lineCategoryFor: category,
      );
      expect(at.first.startPoint, Vector3(-1, -2, -3));
      expect(at.first.endPoint, Vector3(0, -2, -3));
    });
  });
}
