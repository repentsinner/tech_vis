import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

const _tolerance = 1e-9;

Matcher _closeToVector(vm.Vector3 expected) => predicate<vm.Vector3>(
  (actual) => (actual - expected).length < _tolerance,
  'within $_tolerance of $expected',
);

/// An edge as an order-independent pair of rounded endpoints.
String _edgeKey(SceneObject line) {
  String point(vm.Vector3 p) =>
      '${p.x.toStringAsFixed(6)},${p.y.toStringAsFixed(6)},'
      '${p.z.toStringAsFixed(6)}';
  final ends = [point(line.startPoint!), point(line.endPoint!)]..sort();
  return ends.join('|');
}

void main() {
  group('rectangleCorners', () {
    test('walks the XY rectangle counterclockwise from min-min', () {
      final corners = rectangleCorners(
        center: vm.Vector3(1, 2, 3),
        width: 4,
        height: 2,
        plane: RectanglePlane.xy,
      );
      expect(corners, hasLength(4));
      expect(corners[0], _closeToVector(vm.Vector3(-1, 1, 3)));
      expect(corners[1], _closeToVector(vm.Vector3(3, 1, 3)));
      expect(corners[2], _closeToVector(vm.Vector3(3, 3, 3)));
      expect(corners[3], _closeToVector(vm.Vector3(-1, 3, 3)));
    });

    test('lays width and height along the plane axes', () {
      final xz = rectangleCorners(
        center: vm.Vector3.zero(),
        width: 4,
        height: 2,
        plane: RectanglePlane.xz,
      );
      expect(xz[2], _closeToVector(vm.Vector3(2, 0, 1)));
      final yz = rectangleCorners(
        center: vm.Vector3.zero(),
        width: 4,
        height: 2,
        plane: RectanglePlane.yz,
      );
      expect(yz[2], _closeToVector(vm.Vector3(0, 2, 1)));
    });

    test('rotates about the center within the plane, in radians', () {
      final corners = rectangleCorners(
        center: vm.Vector3.zero(),
        width: 4,
        height: 2,
        plane: RectanglePlane.xy,
        rotation: math.pi / 2,
      );
      // A quarter turn carries the (+2, +1) corner to (-1, +2).
      expect(corners[2], _closeToVector(vm.Vector3(-1, 2, 0)));
    });
  });

  group('FilledRectangleFactory.createOutline', () {
    final rectangle = FilledRectangleFactory.createXYFilledRectangle(
      center: vm.Vector3.zero(),
      width: 4,
      height: 2,
      lineCategory: 'edge',
      edgeWidth: 0.5,
      id: 'r',
    );

    test('emits the four perimeter lines with the edge width', () {
      final outline = FilledRectangleFactory.createOutline(rectangle);
      expect(outline, hasLength(4));
      for (final line in outline) {
        expect(line.type, SceneObjectType.line);
        expect(line.thickness, 0.5);
        expect(line.lineCategory, 'edge');
      }
      expect(outline.map((l) => l.id), [
        'r_edge_0',
        'r_edge_1',
        'r_edge_2',
        'r_edge_3',
      ]);
      expect(outline[0].startPoint, _closeToVector(vm.Vector3(-2, -1, 0)));
      expect(outline[3].endPoint, _closeToVector(vm.Vector3(-2, -1, 0)));
    });

    test('emits nothing for a rectangle without an edge', () {
      final bare = FilledRectangleFactory.createXYFilledRectangle(
        center: vm.Vector3.zero(),
        width: 4,
        height: 2,
        lineCategory: 'edge',
        edgeWidth: 0,
      );
      expect(FilledRectangleFactory.createOutline(bare), isEmpty);
    });

    test('emits nothing for an object that is not a filled rectangle', () {
      const line = SceneObject(
        type: SceneObjectType.line,
        lineCategory: null,
        id: 'l',
        edgeWidth: 1,
      );
      expect(FilledRectangleFactory.createOutline(line), isEmpty);
    });
  });

  group('BoundingBoxFactory.createCube', () {
    final bounds = BoundingBox(
      minBounds: vm.Vector3(0, 0, 0),
      maxBounds: vm.Vector3(4, 2, 1),
    );
    final cube = BoundingBoxFactory.createCube(
      bounds: bounds,
      lineCategory: 'box',
      opacity: 0.25,
      edgeWidth: 0.3,
      idPrefix: 'b',
    );
    final faces = cube.where((o) => o.type == SceneObjectType.filledRectangle);
    final edges = cube.where((o) => o.type == SceneObjectType.line).toList();

    test('emits six faces carrying the opacity and no edge of their own', () {
      expect(faces, hasLength(6));
      for (final face in faces) {
        expect(face.opacity, 0.25);
        expect(face.edgeWidth, 0);
        expect(FilledRectangleFactory.createOutline(face), isEmpty);
      }
    });

    test('emits each of the twelve box edges exactly once', () {
      expect(edges, hasLength(12));
      expect(edges.map(_edgeKey).toSet(), hasLength(12));
      for (final edge in edges) {
        expect(edge.thickness, 0.3);
        expect(edge.lineCategory, 'box');
        expect(edge.id, startsWith('b_edge_'));
      }
    });

    test('runs every edge between two corners of the box', () {
      final corners = <String>{
        for (final x in [0.0, 4.0])
          for (final y in [0.0, 2.0])
            for (final z in [0.0, 1.0]) '$x,$y,$z',
      };
      String key(vm.Vector3 p) => '${p.x},${p.y},${p.z}';
      for (final edge in edges) {
        expect(corners, contains(key(edge.startPoint!)));
        expect(corners, contains(key(edge.endPoint!)));
        // An edge runs along exactly one axis.
        final d = edge.endPoint! - edge.startPoint!;
        final axesMoved = [d.x, d.y, d.z].where((c) => c != 0).length;
        expect(axesMoved, 1);
      }
    });

    test('omits the faces when the box has no fill', () {
      final wire = BoundingBoxFactory.createCube(
        bounds: bounds,
        lineCategory: 'box',
        opacity: 0,
      );
      expect(wire.every((o) => o.type == SceneObjectType.line), isTrue);
      expect(wire, hasLength(12));
    });
  });
}
