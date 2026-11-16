import 'dart:math' as math;

import 'package:tech_vis/tech_vis.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Projects [point] through a pinhole camera with vertical field of view
/// [verticalFovRadians] onto a viewport [viewportHeight] pixels tall.
///
/// Returns the pixel position relative to the viewport center, y up. Tests
/// measure screen-space sizes against this independent projection.
vm.Vector2 projectPinhole(
  vm.Vector3 point,
  CameraBasis camera, {
  required double verticalFovRadians,
  required double viewportHeight,
}) {
  final focalPixels =
      (viewportHeight / 2.0) / math.tan(verticalFovRadians / 2.0);
  final relative = point - camera.position;
  final depth = relative.dot(camera.forward);
  return vm.Vector2(
    relative.dot(camera.right) * focalPixels / depth,
    relative.dot(camera.up) * focalPixels / depth,
  );
}
