import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_convention.dart';
import 'screen_space_utils.dart';
import 'viewport_overlay.dart';

/// At or below this cosine between a face normal and the view axis, a face
/// is edge-on or turned away and is not drawn.
const double _minFacing = 1e-9;

/// Facings closer than this count as equal when ordering faces, the
/// tolerance golden vectors compare numbers within.
const double _facingTieTolerance = 1e-9;

/// A face of the navigation cube, named for the orthographic view it shows.
enum NavigationCubeFace {
  top,
  bottom,
  front,
  back,
  left,
  right;

  /// Text the face carries, in capitals as CAD view cubes print it.
  String get label => name.toUpperCase();
}

/// One face of the navigation cube as the camera sees it, in viewport
/// pixels.
final class NavigationCubeFaceView {
  const NavigationCubeFaceView({
    required this.face,
    required this.corners,
    required this.facing,
  });

  /// The face shown.
  final NavigationCubeFace face;

  /// The face's four corners in the screen coordinates of
  /// `worldToScreen`, ordered as the label's bottom-left, bottom-right,
  /// top-right, and top-left corners.
  ///
  /// The projection is orthographic, so the corners form a parallelogram
  /// and an affine map draws the label onto it.
  final List<vm.Vector2> corners;

  /// Cosine between the face normal and the axis toward the viewer, in
  /// (0, 1]. A face seen straight on has 1.
  final double facing;
}

/// A passive orientation indicator: a cube whose labeled faces show which
/// side of the scene faces the viewer.
///
/// Top is the convention's up axis. Front faces away from the convention's
/// fallback axis unless the app names another [front], so the top view of
/// `CameraBasis.lookAt` shows Top upright with Front along its bottom edge.
class NavigationCube {
  /// Creates the cube for a space in [convention], with the Front face's
  /// outward normal along [front].
  ///
  /// Throws an [ArgumentError] when [front] is not a signed unit world axis
  /// perpendicular to the up axis.
  factory NavigationCube({
    required CoordinateConvention convention,
    vm.Vector3? front,
  }) {
    final up = convention.up.unitVector;
    final frontNormal = front ?? -convention.fallbackAxis.unitVector;
    final components = frontNormal.storage;
    final isSignedAxis =
        components.where((c) => c == 0).length == 2 &&
        components.where((c) => c.abs() == 1).length == 1;
    if (!isSignedAxis || frontNormal.dot(up) != 0) {
      throw ArgumentError.value(
        front,
        'front',
        'not a signed world axis perpendicular to ${convention.up.label}',
      );
    }
    return NavigationCube._(convention, frontNormal.clone());
  }

  NavigationCube._(this.convention, this.front);

  /// Convention of the space the cube orients in.
  final CoordinateConvention convention;

  /// Outward normal of the Front face.
  final vm.Vector3 front;

  /// Returns the outward unit normal of [face] in world space.
  ///
  /// Right is the face a viewer of Front sees to their right, so it follows
  /// the declared hand rule.
  vm.Vector3 normal(NavigationCubeFace face) {
    final up = convention.up.unitVector;
    final right = convention.cross(up, front);
    return switch (face) {
      NavigationCubeFace.top => up,
      NavigationCubeFace.bottom => -up,
      NavigationCubeFace.front => front.clone(),
      NavigationCubeFace.back => -front,
      NavigationCubeFace.right => right,
      NavigationCubeFace.left => -right,
    };
  }

  /// Returns the world direction in which [face]'s label text points up.
  ///
  /// Side labels stand upright. Top and Bottom labels point away from
  /// Front, which is how the top and bottom views of `CameraBasis.lookAt`
  /// hold them.
  vm.Vector3 textUp(NavigationCubeFace face) => switch (face) {
    NavigationCubeFace.top || NavigationCubeFace.bottom => -front,
    _ => convention.up.unitVector,
  };

  /// Returns the world direction in which [face]'s label text runs.
  ///
  /// Text right crossed with text up gives the face normal by the declared
  /// hand rule, so a label reads left to right from outside the cube.
  vm.Vector3 textRight(NavigationCubeFace face) =>
      convention.cross(textUp(face), normal(face));

  /// Returns the faces that face the viewer of [camera], drawn in [rect].
  ///
  /// The cube turns with the camera's rotation only and projects
  /// orthographically about the rectangle's center. Its edge is
  /// min(width, height) / sqrt(3), so no corner leaves the rectangle at
  /// any rotation. Faces come least direct first, so drawing them in order
  /// draws the most direct face last. Ties keep face order.
  List<NavigationCubeFaceView> visibleFaces(
    CameraBasis camera,
    ViewportRect rect,
  ) {
    final halfEdge =
        math.min(rect.right - rect.left, rect.bottom - rect.top) /
        (2 * math.sqrt(3));
    final centerX = (rect.left + rect.right) / 2;
    final centerY = (rect.top + rect.bottom) / 2;
    vm.Vector2 project(vm.Vector3 p) => vm.Vector2(
      centerX + p.dot(camera.right) * halfEdge,
      centerY - p.dot(camera.up) * halfEdge,
    );

    final views = <NavigationCubeFaceView>[];
    for (final face in NavigationCubeFace.values) {
      final n = normal(face);
      final facing = n.dot(camera.toViewer);
      if (facing <= _minFacing) continue;
      final r = textRight(face);
      final u = textUp(face);
      views.add(
        NavigationCubeFaceView(
          face: face,
          corners: [
            project(n - r - u),
            project(n + r - u),
            project(n + r + u),
            project(n - r + u),
          ],
          facing: facing,
        ),
      );
    }
    // Ties, as in a view along a cube diagonal, break by face order so
    // both packages list the faces alike. Facings within the fixture
    // tolerance tie, because another language's trigonometry can differ
    // from this one in the last bits.
    return views..sort(
      (a, b) => (a.facing - b.facing).abs() <= _facingTieTolerance
          ? a.face.index.compareTo(b.face.index)
          : a.facing.compareTo(b.facing),
    );
  }
}
