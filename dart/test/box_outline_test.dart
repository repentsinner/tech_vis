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
String _edgeKey(LinePrimitive line) {
  String point(vm.Vector3 p) =>
      '${p.x.toStringAsFixed(6)},${p.y.toStringAsFixed(6)},'
      '${p.z.toStringAsFixed(6)}';
  final ends = [point(line.start), point(line.end)]..sort();
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

  group('FilledRectangleFactory', () {
    final thirdCorners = {
      RectanglePlane.xy: vm.Vector3(2, 1, 0),
      RectanglePlane.xz: vm.Vector3(2, 0, 1),
      RectanglePlane.yz: vm.Vector3(0, 2, 1),
    };
    for (final MapEntry(key: plane, value: thirdCorner)
        in thirdCorners.entries) {
      test('creates a ${plane.name} quad carrying its key and opacity', () {
        final quad = FilledRectangleFactory.createFilledRectangle(
          center: vm.Vector3.zero(),
          width: 4,
          height: 2,
          plane: plane,
          key: 'fill',
          opacity: 0.5,
        );
        expect(quad.key, 'fill');
        expect(quad.opacity, 0.5);
        expect(quad.corners, hasLength(4));
        expect(quad.corners[2], _closeToVector(thirdCorner));
      });
    }
  });

  group('FilledRectangleFactory.createOutline', () {
    final rectangle = FilledRectangleFactory.createFilledRectangle(
      center: vm.Vector3.zero(),
      width: 4,
      height: 2,
      plane: RectanglePlane.xy,
      key: 'fill',
      opacity: 0.5,
    );

    test('emits the four perimeter lines at the width in pixels', () {
      final outline = FilledRectangleFactory.createOutline(
        rectangle,
        widthPixels: 0.5,
      );
      expect(outline, hasLength(4));
      for (final line in outline) {
        expect(line.widthPixels, 0.5);
        expect(line.key, 'fill');
        expect(line.opacity, 0.5);
      }
      expect(outline[0].start, _closeToVector(vm.Vector3(-2, -1, 0)));
      expect(outline[0].end, _closeToVector(vm.Vector3(2, -1, 0)));
      expect(outline[3].end, _closeToVector(vm.Vector3(-2, -1, 0)));
    });
  });

  group('BoundingBoxFactory.createCube', () {
    final bounds = BoundingBox(
      minBounds: vm.Vector3(0, 0, 0),
      maxBounds: vm.Vector3(4, 2, 1),
    );
    final cube = BoundingBoxFactory.createCube(
      bounds: bounds,
      key: 'box',
      fillOpacity: 0.25,
      edgeWidth: 0.3,
    );
    final faces = cube.whereType<QuadPrimitive>().toList();
    final edges = cube.whereType<LinePrimitive>().toList();

    test('emits only lines and quads', () {
      expect(cube, hasLength(faces.length + edges.length));
    });

    test('emits six faces carrying the fill opacity and key', () {
      expect(faces, hasLength(6));
      for (final face in faces) {
        expect(face.opacity, 0.25);
        expect(face.key, 'box');
      }
    });

    test('emits each of the twelve box edges exactly once', () {
      expect(edges, hasLength(12));
      expect(edges.map(_edgeKey).toSet(), hasLength(12));
      for (final edge in edges) {
        expect(edge.widthPixels, 0.3);
        expect(edge.key, 'box');
        expect(edge.opacity, 1.0);
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
        expect(corners, contains(key(edge.start)));
        expect(corners, contains(key(edge.end)));
        // An edge runs along exactly one axis.
        final d = edge.end - edge.start;
        final axesMoved = [d.x, d.y, d.z].where((c) => c != 0).length;
        expect(axesMoved, 1);
      }
    });

    test('puts every face corner on a corner of the box', () {
      for (final face in faces) {
        for (final corner in face.corners) {
          expect(bounds.contains(corner), isTrue);
          expect(bounds.closestPointTo(corner), _closeToVector(corner));
        }
      }
    });

    test('omits the faces when the box has no fill', () {
      final wire = BoundingBoxFactory.createCube(
        bounds: bounds,
        key: 'box',
        fillOpacity: 0,
      );
      expect(wire, everyElement(isA<LinePrimitive>()));
      expect(wire, hasLength(12));
    });
  });
}
