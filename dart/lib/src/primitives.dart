import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart' as vm;

/// Default opacity of a primitive: fully opaque.
const double _opaque = 1.0;

/// Default anchor alignment of a billboard: its content's center.
const double _centered = 0.5;

/// One element of an annotation, in the app's declared coordinate
/// convention.
///
/// The set is closed: every primitive is a [LinePrimitive],
/// [QuadPrimitive], [BillboardPrimitive], [MarkerPrimitive], or
/// [MeshPrimitive], so a renderer that switches over a [Primitive] handles
/// exactly five cases. The package emits primitives and never renders them.
sealed class Primitive {
  const Primitive({required this.key, this.opacity = _opaque})
    : assert(opacity >= 0 && opacity <= 1, 'opacity must lie between 0 and 1');

  /// App value that the package passes through and never inspects.
  ///
  /// The app resolves the primitive's color, and any other meaning, from
  /// its key.
  final Object? key;

  /// Opacity from 0 to 1, which the package computes.
  final double opacity;
}

/// A straight line between two world points, drawn at a constant width in
/// screen pixels at any depth.
final class LinePrimitive extends Primitive {
  const LinePrimitive({
    required this.start,
    required this.end,
    required this.widthPixels,
    required super.key,
    super.opacity,
  });

  /// World start point.
  final vm.Vector3 start;

  /// World end point.
  final vm.Vector3 end;

  /// Width in screen pixels.
  final double widthPixels;
}

/// A filled four-cornered face.
final class QuadPrimitive extends Primitive {
  QuadPrimitive({
    required List<vm.Vector3> corners,
    required super.key,
    super.opacity,
  }) : assert(corners.length == 4, 'a quad has four corners'),
       corners = List.unmodifiable(corners);

  /// World corners in order around the face's perimeter.
  final List<vm.Vector3> corners;
}

/// How a billboard's content faces the camera.
sealed class BillboardOrientation {
  const BillboardOrientation();
}

/// Content that always faces the viewer, upright on screen.
final class ViewerFacingOrientation extends BillboardOrientation {
  const ViewerFacingOrientation();
}

/// Content that lies flat in the plane through its anchor with normal
/// [normal], its horizontal axis along [right].
///
/// The content keeps its pixel size when viewed along the normal and
/// foreshortens with perspective at oblique angles.
final class CoplanarOrientation extends BillboardOrientation {
  const CoplanarOrientation({required this.normal, required this.right});

  /// Unit normal of the plane the content lies in.
  final vm.Vector3 normal;

  /// Unit world direction of the content's horizontal axis.
  final vm.Vector3 right;
}

/// A screen-space offset of a billboard from its anchor.
final class ScreenOffset {
  const ScreenOffset({required this.direction, required this.pixels});

  /// World direction of the offset. The billboard moves along this
  /// direction as it appears on screen.
  final vm.Vector3 direction;

  /// Length of the offset in screen pixels.
  final double pixels;
}

/// Text that the package composes for an annotation, such as an axis
/// letter or a label, at the pixel height it is drawn at.
///
/// The package never measures or rasterizes text. The app answers each
/// request with a [TextResolver], which sets the text in its own typeface
/// and reports the result's pixel size.
final class TextRequest {
  const TextRequest({required this.text, required this.heightPixels});

  /// Text to set.
  final String text;

  /// Height to set the text at, in screen pixels.
  final double heightPixels;

  @override
  bool operator ==(Object other) =>
      other is TextRequest &&
      other.text == text &&
      other.heightPixels == heightPixels;

  @override
  int get hashCode => Object.hash(text, heightPixels);

  @override
  String toString() => 'TextRequest($text, $heightPixels px)';
}

/// Content that the app prepared for a billboard, with its size in screen
/// pixels.
///
/// The app owns content creation. [value] is any handle the app's renderer
/// draws: a text layout, a texture, an icon, or a video frame. The package
/// places the content by [widthPixels] and [heightPixels] and never
/// inspects [value].
final class BillboardContent {
  const BillboardContent({
    required this.value,
    required this.widthPixels,
    required this.heightPixels,
  }) : assert(
         widthPixels >= 0 && heightPixels >= 0,
         'a pixel size is never negative',
       );

  /// App handle for the content, passed through untouched.
  final Object? value;

  /// Width of the content in screen pixels.
  final double widthPixels;

  /// Height of the content in screen pixels.
  final double heightPixels;
}

/// Answers a [TextRequest] with the app's content for it and the content's
/// pixel size.
///
/// The resolver runs synchronously, so every factory result follows from
/// its inputs alone. An app measures text with its own layout pass, and
/// may rasterize the content later, as long as the size it reports is the
/// size it draws.
typedef TextResolver = BillboardContent Function(TextRequest request);

/// 2D content that the app prepares, placed at a world anchor and sized in
/// screen pixels.
///
/// The content is opaque to the package: text, an icon, a video frame, or
/// anything else the app can draw. The package places it by its pixel size
/// and never inspects it.
final class BillboardPrimitive extends Primitive {
  BillboardPrimitive({
    required this.content,
    required this.anchor,
    this.orientation = const ViewerFacingOrientation(),
    vm.Vector2? alignment,
    this.offset,
    required super.key,
    super.opacity,
  }) : alignment = alignment ?? vm.Vector2.all(_centered);

  /// Content for the app to draw, with its size in screen pixels.
  final BillboardContent content;

  /// World point the content is placed at.
  final vm.Vector3 anchor;

  /// How the content faces the camera.
  final BillboardOrientation orientation;

  /// Point of the content that sits on the anchor, as a fraction of its
  /// width and height from its bottom-left corner.
  ///
  /// (0.5, 0.5) centers the content on the anchor.
  final vm.Vector2 alignment;

  /// Screen-space offset from the anchor, or null for none.
  final ScreenOffset? offset;
}

/// Triangle geometry with 32-bit vertex buffers, the precision a GPU
/// consumes.
///
/// Positions are in the app's declared coordinate convention. Triangles
/// wind so that each face's normal, by the declared hand rule, points
/// outward.
final class TriangleMesh {
  const TriangleMesh({
    required this.positions,
    required this.normals,
    required this.indices,
  });

  /// Interleaved XYZ vertex positions in world units.
  final Float32List positions;

  /// Interleaved XYZ unit normals, one per vertex.
  final Float32List normals;

  /// Vertex indices, three per triangle.
  final Uint16List indices;

  /// Number of vertices.
  int get vertexCount => positions.length ~/ 3;

  /// Number of triangles.
  int get triangleCount => indices.length ~/ 3;
}

/// A sphere centered on a world point that keeps its diameter in screen
/// pixels at any distance.
final class MarkerPrimitive extends Primitive {
  const MarkerPrimitive({
    required this.position,
    required this.diameterPixels,
    required this.mesh,
    required super.key,
    super.opacity,
  });

  /// World center of the marker.
  final vm.Vector3 position;

  /// Diameter in screen pixels.
  final double diameterPixels;

  /// The sphere's mesh, drawn at the transform the package returns for the
  /// frame.
  final TriangleMesh mesh;
}

/// Triangle geometry drawn as is.
final class MeshPrimitive extends Primitive {
  const MeshPrimitive({required this.mesh, required super.key, super.opacity});

  /// The triangles to draw.
  final TriangleMesh mesh;
}
