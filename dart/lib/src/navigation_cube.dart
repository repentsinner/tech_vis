import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_convention.dart';
import 'coordinate_frame.dart';
import 'screen_space_utils.dart';
import 'viewport_overlay.dart';

/// At or below this cosine between a face normal and the view axis, a face
/// is edge-on or turned away and is not drawn.
const double _minFacing = 1e-9;

/// Facings closer than this count as equal when ordering faces, the
/// tolerance golden vectors compare numbers within.
const double _facingTieTolerance = 1e-9;

/// A face's outward normal and the directions its label text runs and
/// points up, in world space.
typedef _Frame = ({vm.Vector3 normal, vm.Vector3 textRight, vm.Vector3 textUp});

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
/// Top is the convention's up axis, and Front faces along the [front] the
/// app names. A top view shows Top upright with Front along its bottom
/// edge, as `CameraBasis.lookAt` holds a top view, when [front] is the
/// opposite of the convention's fallback axis.
class NavigationCube {
  /// Creates the cube for a space in [convention], with the Front face's
  /// outward normal along [front].
  ///
  /// Throws an [ArgumentError] when [front] runs along the up axis.
  factory NavigationCube({
    required CoordinateConvention convention,
    required SignedAxis front,
  }) {
    if (front.axis == convention.up) {
      throw ArgumentError.value(
        front,
        'front',
        'runs along the up axis ${convention.up.label}',
      );
    }
    final up = convention.up.unitVector;
    final frontNormal = front.unitVector;
    final right = convention.cross(up, frontNormal);
    _Frame frame(vm.Vector3 normal, vm.Vector3 textUp) => (
      normal: normal,
      textUp: textUp,
      textRight: convention.cross(textUp, normal),
    );
    // Side labels stand upright. Top and Bottom labels point away from
    // Front, which is how the top and bottom views of `CameraBasis.lookAt`
    // hold them.
    final frames = [
      for (final face in NavigationCubeFace.values)
        switch (face) {
          NavigationCubeFace.top => frame(up, -frontNormal),
          NavigationCubeFace.bottom => frame(-up, -frontNormal),
          NavigationCubeFace.front => frame(frontNormal, up),
          NavigationCubeFace.back => frame(-frontNormal, up),
          NavigationCubeFace.left => frame(-right, up),
          NavigationCubeFace.right => frame(right, up),
        },
    ];
    return NavigationCube._(convention, front, frames);
  }

  NavigationCube._(this.convention, this.front, this._frames);

  /// Convention of the space the cube orients in.
  final CoordinateConvention convention;

  /// Direction of the Front face's outward normal.
  final SignedAxis front;

  /// Each face's world frame, indexed by the face's index.
  final List<_Frame> _frames;

  /// Returns the outward unit normal of [face] in world space.
  ///
  /// Right is the face a viewer of Front sees to their right, so it follows
  /// the declared hand rule.
  vm.Vector3 normal(NavigationCubeFace face) =>
      _frames[face.index].normal.clone();

  /// Returns the world direction in which [face]'s label text points up.
  ///
  /// Side labels stand upright. Top and Bottom labels point away from
  /// Front, which is how the top and bottom views of `CameraBasis.lookAt`
  /// hold them.
  vm.Vector3 textUp(NavigationCubeFace face) =>
      _frames[face.index].textUp.clone();

  /// Returns the world direction in which [face]'s label text runs.
  ///
  /// Text right crossed with text up gives the face normal by the declared
  /// hand rule, so a label reads left to right from outside the cube.
  vm.Vector3 textRight(NavigationCubeFace face) =>
      _frames[face.index].textRight.clone();

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
      final (normal: n, textRight: r, textUp: u) = _frames[face.index];
      final facing = n.dot(camera.toViewer);
      if (facing <= _minFacing) continue;
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
    // Ties, as in a view along a cube diagonal, break by face order.
    // Facings within the fixture tolerance tie, because another language's
    // trigonometry can differ from this one in the last bits. Pairwise
    // tolerance is not transitive, so the faces are grouped instead: each
    // group holds the faces within the tolerance of its least direct one,
    // in face order. Both packages then list the faces alike, whatever
    // sort algorithm they run.
    views.sort((a, b) => a.facing.compareTo(b.facing));
    final ordered = <NavigationCubeFaceView>[];
    var start = 0;
    while (start < views.length) {
      var end = start + 1;
      while (end < views.length &&
          views[end].facing - views[start].facing <= _facingTieTolerance) {
        end++;
      }
      ordered.addAll(
        views.sublist(start, end)
          ..sort((a, b) => a.face.index.compareTo(b.face.index)),
      );
      start = end;
    }
    return ordered;
  }
}
