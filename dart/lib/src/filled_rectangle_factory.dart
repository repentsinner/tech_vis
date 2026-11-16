import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'primitives.dart';

/// Cardinal plane a rectangle lies in.
enum RectanglePlane {
  /// The plane of the X and Y axes.
  xy,

  /// The plane of the X and Z axes.
  xz,

  /// The plane of the Y and Z axes.
  yz,
}

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

/// Factory for filled rectangles in the cardinal planes (XY, XZ, YZ).
///
/// Each rectangle is a [QuadPrimitive]. The app key passes through to the
/// quad untouched.
class FilledRectangleFactory {
  /// Creates a filled rectangle in the XY plane.
  static QuadPrimitive createXYFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Object? key,
    double opacity = 1.0,
    double rotation = 0.0,
  }) => _create(center, width, height, .xy, key, opacity, rotation);

  /// Creates a filled rectangle in the XZ plane.
  static QuadPrimitive createXZFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Object? key,
    double opacity = 1.0,
    double rotation = 0.0,
  }) => _create(center, width, height, .xz, key, opacity, rotation);

  /// Creates a filled rectangle in the YZ plane.
  static QuadPrimitive createYZFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required Object? key,
    double opacity = 1.0,
    double rotation = 0.0,
  }) => _create(center, width, height, .yz, key, opacity, rotation);

  static QuadPrimitive _create(
    vm.Vector3 center,
    double width,
    double height,
    RectanglePlane plane,
    Object? key,
    double opacity,
    double rotation,
  ) => QuadPrimitive(
    corners: rectangleCorners(
      center: center,
      width: width,
      height: height,
      plane: plane,
      rotation: rotation,
    ),
    key: key,
    opacity: opacity,
  );

  /// Returns the perimeter of [quad] as four lines, [widthPixels] wide.
  ///
  /// Each line runs from one corner to the next. The lines carry [key], or
  /// the quad's key when [key] is omitted, and the given [opacity].
  static List<LinePrimitive> createOutline(
    QuadPrimitive quad, {
    required double widthPixels,
    Object? key,
    double opacity = 1.0,
  }) {
    final corners = quad.corners;
    return [
      for (var i = 0; i < corners.length; i++)
        LinePrimitive(
          start: corners[i],
          end: corners[(i + 1) % corners.length],
          widthPixels: widthPixels,
          key: key ?? quad.key,
          opacity: opacity,
        ),
    ];
  }
}
