import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'scene_object.dart';

/// Corners of a [width] by [height] rectangle centered on [center] in
/// [plane], counterclockwise from the corner at the plane's two minimum
/// axes.
///
/// Width runs along the plane's first axis and height along its second:
/// X and Y for XY, X and Z for XZ, Y and Z for YZ. [rotation] turns the
/// rectangle about its center within the plane, in radians, counterclockwise
/// from the first axis toward the second.
List<vm.Vector3> rectangleCorners({
  required vm.Vector3 center,
  required double width,
  required double height,
  required RectanglePlane plane,
  double rotation = 0,
}) {
  final halfW = width / 2;
  final halfH = height / 2;
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  vm.Vector3 corner(double u, double v) {
    final ru = u * cos - v * sin;
    final rv = u * sin + v * cos;
    return switch (plane) {
      RectanglePlane.xy => vm.Vector3(center.x + ru, center.y + rv, center.z),
      RectanglePlane.xz => vm.Vector3(center.x + ru, center.y, center.z + rv),
      RectanglePlane.yz => vm.Vector3(center.x, center.y + ru, center.z + rv),
    };
  }

  return [
    corner(-halfW, -halfH),
    corner(halfW, -halfH),
    corner(halfW, halfH),
    corner(-halfW, halfH),
  ];
}

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

  /// The perimeter of a filled [rectangle] as four line [SceneObject]s.
  ///
  /// Each line has the rectangle's edge width as its thickness and the
  /// rectangle's line category. Returns an empty list when [rectangle] is
  /// not a filled rectangle or has no edge.
  static List<SceneObject> createOutline(SceneObject rectangle) {
    final center = rectangle.center;
    final width = rectangle.width;
    final height = rectangle.height;
    final edgeWidth = rectangle.edgeWidth ?? 0;
    if (rectangle.type != .filledRectangle ||
        center == null ||
        width == null ||
        height == null ||
        edgeWidth <= 0) {
      return const [];
    }
    final corners = rectangleCorners(
      center: center,
      width: width,
      height: height,
      plane: rectangle.plane ?? .xy,
      rotation: rectangle.rotation ?? 0,
    );
    return [
      for (var i = 0; i < corners.length; i++)
        SceneObject(
          type: .line,
          lineCategory: rectangle.lineCategory,
          id: '${rectangle.id}_edge_$i',
          startPoint: corners[i],
          endPoint: corners[(i + 1) % corners.length],
          thickness: edgeWidth,
        ),
    ];
  }
}
