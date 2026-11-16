import 'dart:typed_data';

import 'package:tech_vis/tech_vis.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// One triangle, enough geometry to stand in for a generated mesh.
TriangleMesh _triangle() => TriangleMesh(
  positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
  normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]),
  indices: Uint16List.fromList([0, 1, 2]),
);

/// A renderer's dispatch: the sealed set leaves exactly five cases.
String _kindOf(Primitive primitive) => switch (primitive) {
  LinePrimitive() => 'line',
  QuadPrimitive() => 'quad',
  BillboardPrimitive() => 'billboard',
  MarkerPrimitive() => 'marker',
  MeshPrimitive() => 'mesh',
};

void main() {
  final key = Object();
  final primitives = <(String, Primitive)>[
    (
      'line',
      LinePrimitive(
        start: vm.Vector3.zero(),
        end: vm.Vector3(1, 0, 0),
        widthPixels: 1,
        key: key,
        opacity: 0.5,
      ),
    ),
    (
      'quad',
      QuadPrimitive(
        corners: [
          vm.Vector3(0, 0, 0),
          vm.Vector3(1, 0, 0),
          vm.Vector3(1, 1, 0),
          vm.Vector3(0, 1, 0),
        ],
        key: key,
        opacity: 0.5,
      ),
    ),
    (
      'billboard',
      BillboardPrimitive(
        content: BillboardContent(
          value: key,
          widthPixels: 32,
          heightPixels: 16,
        ),
        anchor: vm.Vector3.zero(),
        key: key,
        opacity: 0.5,
      ),
    ),
    (
      'marker',
      MarkerPrimitive(
        position: vm.Vector3.zero(),
        diameterPixels: 8,
        mesh: _triangle(),
        key: key,
        opacity: 0.5,
      ),
    ),
    ('mesh', MeshPrimitive(mesh: _triangle(), key: key, opacity: 0.5)),
  ];

  group('Primitive', () {
    for (final (kind, primitive) in primitives) {
      test('a $kind passes its key through untouched', () {
        expect(_kindOf(primitive), kind);
        expect(primitive.key, same(key));
        expect(primitive.opacity, 0.5);
      });
    }

    test('is opaque unless given an opacity', () {
      final line = LinePrimitive(
        start: vm.Vector3.zero(),
        end: vm.Vector3(1, 0, 0),
        widthPixels: 1,
        key: null,
      );
      expect(line.opacity, 1.0);
    });

    test('rejects an opacity outside 0 to 1', () {
      expect(
        () => MeshPrimitive(mesh: _triangle(), key: null, opacity: 1.5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects a quad without four corners', () {
      expect(
        () => QuadPrimitive(corners: [vm.Vector3.zero()], key: null),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('BillboardPrimitive', () {
    test('faces the viewer, centered on its anchor, by default', () {
      final billboard = BillboardPrimitive(
        content: const BillboardContent(
          value: 'icon',
          widthPixels: 24,
          heightPixels: 16,
        ),
        anchor: vm.Vector3.zero(),
        key: null,
      );
      expect(billboard.orientation, isA<ViewerFacingOrientation>());
      expect(billboard.alignment, vm.Vector2(0.5, 0.5));
      expect(billboard.offset, isNull);
    });

    test('carries the app content and its pixel size untouched', () {
      final handle = Object();
      final billboard = BillboardPrimitive(
        content: BillboardContent(
          value: handle,
          widthPixels: 24,
          heightPixels: 16,
        ),
        anchor: vm.Vector3.zero(),
        key: null,
      );
      expect(billboard.content.value, same(handle));
      expect(billboard.content.widthPixels, 24);
      expect(billboard.content.heightPixels, 16);
    });
  });

  group('BillboardContent', () {
    test('rejects a negative pixel size', () {
      expect(
        () => BillboardContent(value: null, widthPixels: -1, heightPixels: 1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('TextRequest', () {
    test('compares by text and pixel height', () {
      expect(
        const TextRequest(text: 'X', heightPixels: 12),
        const TextRequest(text: 'X', heightPixels: 12),
      );
      expect(
        const TextRequest(text: 'X', heightPixels: 12),
        isNot(const TextRequest(text: 'X', heightPixels: 14)),
      );
    });
  });

  group('TriangleMesh', () {
    test('counts vertices and triangles from its buffers', () {
      final mesh = _triangle();
      expect(mesh.vertexCount, 3);
      expect(mesh.triangleCount, 1);
    });
  });
}
