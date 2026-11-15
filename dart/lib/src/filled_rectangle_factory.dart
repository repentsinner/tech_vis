import 'package:vector_math/vector_math.dart' as vm;

import 'scene_object.dart';

/// Factory for creating filled rectangle [SceneObject]s in 3D space.
///
/// Provides methods for creating rectangles in each cardinal plane (XY, XZ,
/// YZ). The [lineCategory] parameter accepts any domain-specific semantic
/// category type — each consumer passes its own category enum.
class FilledRectangleFactory {
  /// Create a filled rectangle in the XY plane.
  static SceneObject createXYFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Object? lineCategory,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: .filledRectangle,
      lineCategory: lineCategory,
      id: id ?? 'filled_rectangle_xy_${center.hashCode}',
      center: center,
      width: width,
      height: height,
      plane: .xy,
      rotation: rotation,
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }

  /// Create a filled rectangle in the XZ plane.
  static SceneObject createXZFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Object? lineCategory,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: .filledRectangle,
      lineCategory: lineCategory,
      id: id ?? 'filled_rectangle_xz_${center.hashCode}',
      center: center,
      width: width,
      height: height,
      plane: .xz,
      rotation: rotation,
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }

  /// Create a filled rectangle in the YZ plane.
  static SceneObject createYZFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Object? lineCategory,
    double edgeWidth = 1.0,
    double opacity = 1.0,
    double rotation = 0.0,
    String? id,
  }) {
    return SceneObject(
      type: .filledRectangle,
      lineCategory: lineCategory,
      id: id ?? 'filled_rectangle_yz_${center.hashCode}',
      center: center,
      width: width,
      height: height,
      plane: .yz,
      rotation: rotation,
      edgeWidth: edgeWidth,
      opacity: opacity,
    );
  }
}
