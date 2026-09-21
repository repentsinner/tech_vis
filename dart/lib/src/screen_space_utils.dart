import 'dart:math' as math;
import 'package:vector_math/vector_math.dart' as vm;

/// Utility class for screen-space calculations shared between renderers.
///
/// Provides methods for converting between pixel sizes and world sizes
/// based on camera parameters, similar to how Three.js handles screen-space
/// calculations. Pure math — no Flutter dependency.
class ScreenSpaceUtils {
  /// Convert a target pixel size to world size based on camera distance and
  /// field of view.
  ///
  /// worldSize = pixelSize * (2 * cameraDistance * tan(fov/2)) / viewportHeight
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

  /// Convert pixel coordinates to Normalized Device Coordinates (NDC).
  ///
  /// NDC range is [-1, 1] for both X and Y axes.
  static double pixelToNDC(double pixelSize, vm.Vector2 screenResolution) {
    return 2.0 * pixelSize / screenResolution.y;
  }

  /// Calculate camera distance to a 3D point.
  static double calculateCameraDistance(
    vm.Vector3 cameraPosition,
    vm.Vector3 targetPosition,
  ) {
    return (cameraPosition - targetPosition).length;
  }
}
