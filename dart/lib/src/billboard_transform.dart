import 'package:vector_math/vector_math.dart' as vm;

import 'leader_line.dart';
import 'screen_space_utils.dart';

/// Below this |direction.x|, a segment is not treated as running along
/// the X axis when [lineSegmentTransform] picks a perpendicular.
const double _alongXThreshold = 0.9;

/// Below this length, a projected offset direction is treated as zero.
const double _minProjectedLength = 1e-6;

/// Rotation that turns a +Z-facing quad to face the viewer, with its local
/// X along screen right and local Y along screen up.
///
/// Every billboard shares this rotation, so text reads horizontally on
/// screen at any camera angle.
vm.Matrix4 screenAlignedRotation(CameraBasis camera) {
  final right = camera.right;
  final up = camera.up;
  final toViewer = camera.toViewer;
  return vm.Matrix4.zero()
    ..setColumn(0, vm.Vector4(right.x, right.y, right.z, 0))
    ..setColumn(1, vm.Vector4(up.x, up.y, up.z, 0))
    ..setColumn(2, vm.Vector4(toViewer.x, toViewer.y, toViewer.z, 0))
    ..setColumn(3, vm.Vector4(0, 0, 0, 1));
}

/// Model transform for a viewer-facing billboard at [position], with its
/// unit quad scaled by [scale] world units.
vm.Matrix4 billboardTransform({
  required vm.Vector3 position,
  required CameraBasis camera,
  required double scale,
}) {
  return vm.Matrix4.translation(position)
    ..multiply(screenAlignedRotation(camera))
    ..scaleByDouble(scale, scale, scale, 1.0);
}

/// [direction] with its component along the view axis removed.
///
/// A direction pointing straight at the viewer projects to zero.
vm.Vector3 projectOntoScreenPlane(vm.Vector3 direction, CameraBasis camera) {
  final forward = camera.forward;
  return direction - forward.scaled(direction.dot(forward));
}

/// Position of a billboard offset [offsetPixels] screen pixels from
/// [anchor] along [direction] as it appears on screen.
///
/// When [direction] points along the view axis it has no on-screen extent,
/// so the billboard sits at the anchor.
vm.Vector3 billboardOffsetPosition({
  required vm.Vector3 anchor,
  required vm.Vector3 direction,
  required double offsetPixels,
  required double worldUnitsPerPixel,
  required CameraBasis camera,
}) {
  final projected = projectOntoScreenPlane(direction, camera);
  if (projected.length <= _minProjectedLength) return anchor.clone();
  return anchor + projected.normalized() * (offsetPixels * worldUnitsPerPixel);
}

/// World-space corners of a callout label quad.
class CalloutLabelCorners {
  const CalloutLabelCorners({
    required this.bottomLeft,
    required this.bottomRight,
    required this.topRight,
    required this.topLeft,
  });

  final vm.Vector3 bottomLeft;
  final vm.Vector3 bottomRight;
  final vm.Vector3 topRight;
  final vm.Vector3 topLeft;
}

/// Corners of the label quad a callout draws at [labelEdge].
///
/// The quad is [scale] world units tall and [aspectRatio] times as wide,
/// anchored by [calloutAnchorAlignment] for [quadrant], so it extends away
/// from the leader. [towardViewer] lifts the corners off the label plane,
/// in units of [scale], so a border drawn on them does not z-fight with
/// the label.
CalloutLabelCorners calloutLabelCorners({
  required vm.Vector3 labelEdge,
  required CalloutQuadrant quadrant,
  required double aspectRatio,
  required double scale,
  required CameraBasis camera,
  double towardViewer = 0,
}) {
  final alignment = calloutAnchorAlignment(quadrant);
  final xMin = -alignment.x * aspectRatio;
  final xMax = (1.0 - alignment.x) * aspectRatio;
  final yMin = -alignment.y;
  final yMax = 1.0 - alignment.y;
  final transform = billboardTransform(
    position: labelEdge,
    camera: camera,
    scale: scale,
  );
  vm.Vector3 corner(double x, double y) =>
      transform.transformed3(vm.Vector3(x, y, towardViewer));
  return CalloutLabelCorners(
    bottomLeft: corner(xMin, yMin),
    bottomRight: corner(xMax, yMin),
    topRight: corner(xMax, yMax),
    topLeft: corner(xMin, yMax),
  );
}

/// Transform that maps the unit segment (0,0,0)→(1,0,0) onto [from]→[to].
///
/// Lets a renderer keep one canonical line segment and place every copy
/// with a matrix. Only the X column carries length; the other two are
/// arbitrary unit perpendiculars, since a line has no up.
vm.Matrix4 lineSegmentTransform(vm.Vector3 from, vm.Vector3 to) {
  final x = to - from;
  final y = x.x.abs() < _alongXThreshold
      ? x.cross(vm.Vector3(1, 0, 0)).normalized()
      : x.cross(vm.Vector3(0, 1, 0)).normalized();
  final z = x.normalized().cross(y);
  return vm.Matrix4.zero()
    ..setColumn(0, vm.Vector4(x.x, x.y, x.z, 0))
    ..setColumn(1, vm.Vector4(y.x, y.y, y.z, 0))
    ..setColumn(2, vm.Vector4(z.x, z.y, z.z, 0))
    ..setColumn(3, vm.Vector4(from.x, from.y, from.z, 1));
}

/// Draw ranks for callouts by distance from the camera, keyed by id.
///
/// The farthest callout gets [minRank], and each nearer one the next rank
/// up, so nearer callouts draw over farther ones. Ranks clamp at
/// [maxRank], where the nearest extras share a rank. Equal distances break
/// by id, so the order is deterministic.
Map<String, int> drawRanksByDistance(
  Map<String, double> distances, {
  int minRank = 1,
  required int maxRank,
}) {
  final farthestFirst = distances.entries.toList()
    ..sort((a, b) {
      final byDistance = b.value.compareTo(a.value);
      return byDistance != 0 ? byDistance : a.key.compareTo(b.key);
    });
  return {
    for (var i = 0; i < farthestFirst.length; i++)
      farthestFirst[i].key: (minRank + i).clamp(minRank, maxRank),
  };
}
