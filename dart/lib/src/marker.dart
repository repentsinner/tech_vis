import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_convention.dart';
import 'primitives.dart';
import 'screen_space_utils.dart';
import 'style_tokens.g.dart';

/// Default opacity of a marker: fully opaque.
const double _opaque = 1.0;

/// Largest vertex count that a 16-bit index buffer can address.
const int _maxUint16Vertices = 1 << 16;

/// Golden ratio, which places an icosahedron's twelve vertices.
final double _phi = (1 + math.sqrt(5)) / 2;

/// Corners of a golden rectangle, which three orthogonal copies of give an
/// icosahedron's twelve vertices.
final List<(double, double)> _rectangleCorners = [
  (-1, _phi),
  (1, _phi),
  (-1, -_phi),
  (1, -_phi),
];

/// The icosahedron's faces, each wound so that its right-hand normal
/// points away from the center.
const List<List<int>> _icosahedronFaces = [
  [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], //
  [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], //
  [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], //
  [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1], //
];

/// Builds a [MarkerPrimitive] and, each frame, the transform that keeps it
/// at its diameter in screen pixels.
abstract final class MarkerFactory {
  static final Map<Handedness, TriangleMesh> _meshes = {};

  /// Returns the unit sphere mesh that every marker in [convention] shares.
  ///
  /// The mesh is an icosphere: its triangles are close to equal in size
  /// and shape, with no crowded poles, so a small subdivision level reads
  /// as round at marker sizes. `StyleTokens.markerSubdivisions` sets the
  /// level. Positions lie on the unit sphere and double as the outward
  /// normals.
  ///
  /// A sphere looks the same about any up axis, so only the handedness
  /// shapes the mesh: it decides the triangle winding, so that each face's
  /// normal by the declared hand rule points outward. The package
  /// generates one mesh per handedness and hands out read-only views of it.
  static TriangleMesh sphereMesh(CoordinateConvention convention) =>
      _meshes.putIfAbsent(
        convention.handedness,
        () => _icosphere(
          StyleTokens.markerSubdivisions.toInt(),
          convention.handedness,
        ),
      );

  /// Returns a marker centered on [position] with a diameter of
  /// [diameterPixels] screen pixels, carrying the shared sphere mesh of
  /// [convention].
  static MarkerPrimitive create({
    required vm.Vector3 position,
    required CoordinateConvention convention,
    required Object? key,
    double diameterPixels = StyleTokens.markerDiameterPixels,
    double opacity = _opaque,
  }) => MarkerPrimitive(
    position: position.clone(),
    diameterPixels: diameterPixels,
    mesh: sphereMesh(convention),
    key: key,
    opacity: opacity,
  );

  /// Returns the model transform that draws [marker]'s unit sphere at its
  /// pixel diameter for one frame.
  ///
  /// The transform translates to the marker's position and scales
  /// uniformly by its radius in world units, which the marker's depth
  /// along [camera]'s view axis sets through
  /// [ScreenSpaceUtils.worldUnitsPerPixelAt]. Returns null when the marker
  /// lies on or behind the camera plane, where it has no finite size.
  static vm.Matrix4? transform(
    MarkerPrimitive marker,
    CameraBasis camera,
    double verticalFovRadians,
    double viewportHeight,
  ) {
    final worldUnitsPerPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
      marker.position,
      camera,
      verticalFovRadians,
      viewportHeight,
    );
    if (worldUnitsPerPixel == null) return null;
    final radius = marker.diameterPixels * worldUnitsPerPixel / 2;
    return vm.Matrix4.translation(marker.position)
      ..scaleByDouble(radius, radius, radius, 1.0);
  }

  /// Subdivides an icosahedron [subdivisions] times onto the unit sphere.
  static TriangleMesh _icosphere(int subdivisions, Handedness handedness) {
    // Three orthogonal golden rectangles, in the order the face table
    // indexes them.
    final vertices = [
      for (final (a, b) in _rectangleCorners) vm.Vector3(a, b, 0),
      for (final (a, b) in _rectangleCorners) vm.Vector3(0, a, b),
      for (final (a, b) in _rectangleCorners) vm.Vector3(b, 0, a),
    ].map((v) => v.normalized()).toList();
    var faces = _icosahedronFaces;

    for (var level = 0; level < subdivisions; level++) {
      final midpoints = <(int, int), int>{};
      int midpoint(int a, int b) =>
          midpoints.putIfAbsent(a < b ? (a, b) : (b, a), () {
            vertices.add((vertices[a] + vertices[b]).normalized());
            return vertices.length - 1;
          });
      faces = [
        for (final [a, b, c] in faces) ...[
          // Each child keeps its parent's winding, so it faces outward too.
          [a, midpoint(a, b), midpoint(c, a)],
          [b, midpoint(b, c), midpoint(a, b)],
          [c, midpoint(c, a), midpoint(b, c)],
          [midpoint(a, b), midpoint(b, c), midpoint(c, a)],
        ],
      ];
    }
    assert(
      vertices.length <= _maxUint16Vertices,
      'subdivision level $subdivisions overflows a 16-bit index buffer',
    );

    final positions = Float32List(vertices.length * 3);
    for (final (i, v) in vertices.indexed) {
      v.copyIntoArray(positions, i * 3);
    }
    final indices = Uint16List(faces.length * 3);
    for (final (t, [a, b, c]) in faces.indexed) {
      // Swapping two corners reverses a face's normal under the left-hand
      // rule back to outward.
      indices.setAll(t * 3, switch (handedness) {
        Handedness.right => [a, b, c],
        Handedness.left => [a, c, b],
      });
    }
    return TriangleMesh(
      positions: positions.asUnmodifiableView(),
      // A unit sphere's outward normal at a vertex is the vertex itself.
      normals: positions.asUnmodifiableView(),
      indices: indices.asUnmodifiableView(),
    );
  }
}
