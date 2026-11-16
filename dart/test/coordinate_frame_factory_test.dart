import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

import 'support/fake_text_resolver.dart';

void main() {
  group('CoordinateFrameFactory.create', () {
    final frame = CoordinateFrameDescriptor(
      origin: Vector3(10, 20, 30),
      length: 5,
      lineThickness: 0.4,
      labelPixelSize: 18,
      labelOffsetPixels: 6,
    );
    String axisKey(SpatialAxis axis) => 'axis_${axis.name}';
    String labelKey(SpatialAxis axis) => 'label_${axis.name}';
    final primitives = CoordinateFrameFactory.create(
      frame,
      keyFor: axisKey,
      labelKeyFor: labelKey,
      resolveText: fakeTextResolver,
    );
    final lines = primitives.whereType<LinePrimitive>().toList();
    final labels = primitives.whereType<BillboardPrimitive>().toList();

    test('emits only lines and billboards', () {
      expect(primitives, hasLength(6));
      expect(lines, hasLength(3));
      expect(labels, hasLength(3));
    });

    test('draws one line per axis from the origin', () {
      for (final (i, axis) in SpatialAxis.values.indexed) {
        expect(lines[i].start, Vector3(10, 20, 30));
        expect(lines[i].end, Vector3(10, 20, 30) + axis.unitVector * 5);
        expect(lines[i].widthPixels, 0.4);
        expect(lines[i].key, axisKey(axis));
      }
    });

    test('labels each axis end, offset in pixels along the axis', () {
      expect(labels.map((l) => l.content.value), const [
        TextRequest(text: 'X', heightPixels: 18),
        TextRequest(text: 'Y', heightPixels: 18),
        TextRequest(text: 'Z', heightPixels: 18),
      ]);
      for (final (i, axis) in SpatialAxis.values.indexed) {
        final label = labels[i];
        expect(label.anchor, lines[i].end);
        expect(label.orientation, isA<ViewerFacingOrientation>());
        expect(label.offset!.direction, axis.unitVector);
        expect(label.offset!.pixels, 6);
        expect(label.content.heightPixels, 18);
        expect(label.content.widthPixels, 18 * fakeCharacterAspect);
        expect(label.key, labelKey(axis));
      }
    });

    test('keys labels by their axis key when given no label key', () {
      final keyed = CoordinateFrameFactory.create(
        frame,
        keyFor: axisKey,
        resolveText: fakeTextResolver,
      );
      final keys = keyed.whereType<BillboardPrimitive>().map((l) => l.key);
      expect(keys, ['axis_x', 'axis_y', 'axis_z']);
    });

    test('omits labels when the frame hides them', () {
      final bare = CoordinateFrameFactory.create(
        CoordinateFrameDescriptor(showLabels: false),
        keyFor: axisKey,
        resolveText: fakeTextResolver,
      );
      expect(bare, hasLength(3));
      expect(bare, everyElement(isA<LinePrimitive>()));
    });

    test('places a frame at any origin', () {
      final at = CoordinateFrameFactory.create(
        CoordinateFrameDescriptor(origin: Vector3(-1, -2, -3), length: 1),
        keyFor: axisKey,
        resolveText: fakeTextResolver,
      );
      final first = at.first as LinePrimitive;
      expect(first.start, Vector3(-1, -2, -3));
      expect(first.end, Vector3(0, -2, -3));
    });
  });
}
