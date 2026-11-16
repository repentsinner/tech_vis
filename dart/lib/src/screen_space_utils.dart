import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_convention.dart';

/// Above this |forward · up|, the view is treated as looking along the
/// declared up axis and [CameraBasis.lookAt] switches to its fallback.
const double _gimbalThreshold = 0.99;

/// Depth at or below which a point is treated as on or behind the camera
/// plane, where it has no finite screen size.
const double _minVisibleDepth = 1e-9;

/// A camera's position and orthonormal view axes in world space.
///
/// Screen-space sizing and billboard orientation both read from one basis,
/// so a label's size and its facing always agree with the camera that
/// draws it.
class CameraBasis {
  const CameraBasis({
    required this.position,
    required this.forward,
    required this.right,
    required this.up,
  });

  /// Builds the basis of a camera at [position] looking at [target], in
  /// the space that [convention] declares.
  ///
  /// The declared up axis orients the camera. When the view direction is
  /// nearly parallel to it, the cross product degenerates, so the
  /// convention's fallback axis takes its place to keep the basis well
  /// defined. The handedness decides which way screen right points, so
  /// right, up, and toward-viewer follow the declared hand rule.
  factory CameraBasis.lookAt({
    required vm.Vector3 position,
    required vm.Vector3 target,
    required CoordinateConvention convention,
  }) {
    final forward = (target - position).normalized();
    final preferredUp = convention.up.unitVector;
    final upReference = forward.dot(preferredUp).abs() > _gimbalThreshold
        ? convention.fallbackAxis.unitVector
        : preferredUp;
    final right = convention.cross(forward, upReference).normalized();
    final up = convention.cross(right, forward).normalized();
    return CameraBasis(
      position: position.clone(),
      forward: forward,
      right: right,
      up: up,
    );
  }

  /// Camera position in world space.
  final vm.Vector3 position;

  /// Unit view direction, from the camera toward what it looks at.
  final vm.Vector3 forward;

  /// Unit screen-right axis.
  final vm.Vector3 right;

  /// Unit screen-up axis.
  final vm.Vector3 up;

  /// Unit axis from the screen plane toward the viewer.
  vm.Vector3 get toViewer => -forward;

  /// Distance of [point] in front of the camera, along the view axis.
  ///
  /// Perspective scales a point by this depth, not by its straight-line
  /// distance from the camera.
  double depthOf(vm.Vector3 point) => (point - position).dot(forward);
}

/// Screen-space math that every renderer shares: the world size of a
/// pixel at a point, and where a point lands in the viewport.
///
/// Every method assumes one perspective camera model, so a size and a
/// position computed for the same frame agree.
class ScreenSpaceUtils {
  /// Convert a target pixel size to world size based on camera distance and
  /// field of view.
  ///
  /// worldSize = pixelSize * (2 * cameraDistance * tan(fov/2)) / viewportHeight
  ///
  /// [cameraDistance] is depth along the view axis. A straight-line
  /// distance from [calculateCameraDistance] oversizes everything off the
  /// view axis by 1/cos of its angle. To size at a point, use
  /// [worldUnitsPerPixelAt].
  static double pixelSizeToWorldSize(
    double targetPixelSize,
    double cameraDistance,
    double fieldOfViewRadians,
    vm.Vector2 screenResolution,
  ) {
    final worldHeightAtDistance =
        2.0 * cameraDistance * math.tan(fieldOfViewRadians / 2.0);
    return targetPixelSize * worldHeightAtDistance / screenResolution.y;
  }

  /// World units that span one screen pixel at [point] under a perspective
  /// [camera] with vertical field of view [verticalFovRadians].
  ///
  /// Uses the point's depth along the view axis, so a screen-space element
  /// keeps the same pixel size anywhere in the view. Returns null for a
  /// point on or behind the camera plane, which has no finite screen size.
  static double? worldUnitsPerPixelAt(
    vm.Vector3 point,
    CameraBasis camera,
    double verticalFovRadians,
    double viewportHeight,
  ) {
    final depth = camera.depthOf(point);
    if (depth <= _minVisibleDepth) return null;
    return 2.0 * depth * math.tan(verticalFovRadians / 2.0) / viewportHeight;
  }

  /// Pixel position of [point] in a [viewportSize] viewport, seen by a
  /// perspective [camera] with vertical field of view [verticalFovRadians].
  ///
  /// The origin is the viewport's top-left corner, x runs right and y runs
  /// down, and (width, height) is the bottom-right corner. Pixels are
  /// square and the view axis passes through the viewport center, the
  /// projection [worldUnitsPerPixelAt] assumes. A renderer measures a frame
  /// in these coordinates to compare it with the reference fixtures.
  /// Returns null for a point on or behind the camera plane, which has no
  /// screen position.
  static vm.Vector2? worldToScreen(
    vm.Vector3 point,
    CameraBasis camera,
    double verticalFovRadians,
    vm.Vector2 viewportSize,
  ) {
    // One pixel spans worldUnitsPerPixelAt at the point's depth, so the
    // projection and the pixel scale agree, and null the same, by
    // construction.
    final worldUnitsPerPixel = worldUnitsPerPixelAt(
      point,
      camera,
      verticalFovRadians,
      viewportSize.y,
    );
    if (worldUnitsPerPixel == null) return null;
    final relative = point - camera.position;
    return vm.Vector2(
      viewportSize.x / 2.0 + relative.dot(camera.right) / worldUnitsPerPixel,
      viewportSize.y / 2.0 - relative.dot(camera.up) / worldUnitsPerPixel,
    );
  }

  /// Convert pixel coordinates to Normalized Device Coordinates (NDC).
  ///
  /// NDC range is [-1, 1] for both X and Y axes.
  static double pixelToNDC(double pixelSize, vm.Vector2 screenResolution) {
    return 2.0 * pixelSize / screenResolution.y;
  }

  /// Calculate the straight-line distance from the camera to a 3D point.
  ///
  /// Suits distance-based effects such as an opacity fade or draw order.
  /// It is not the depth that perspective scales by, so do not size
  /// screen-space elements with it; use [worldUnitsPerPixelAt] instead.
  static double calculateCameraDistance(
    vm.Vector3 cameraPosition,
    vm.Vector3 targetPosition,
  ) {
    return (cameraPosition - targetPosition).length;
  }
}
