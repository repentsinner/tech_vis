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
  /// Creates a filled rectangle of [width] by [height] centered on
  /// [center] in [plane], turned [rotation] radians within the plane.
  static QuadPrimitive createFilledRectangle({
    required vm.Vector3 center,
    required double width,
    required double height,
    required RectanglePlane plane,
    required Object? key,
    double opacity = 1.0,
    double rotation = 0.0,
  }) => QuadPrimitive(
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
  /// Each line runs from one corner to the next and carries the quad's key
  /// and opacity.
  static List<LinePrimitive> createOutline(
    QuadPrimitive quad, {
    required double widthPixels,
  }) {
    final corners = quad.corners;
    return [
      for (var i = 0; i < corners.length; i++)
        LinePrimitive(
          start: corners[i],
          end: corners[(i + 1) % corners.length],
          widthPixels: widthPixels,
          key: quad.key,
          opacity: quad.opacity,
        ),
    ];
  }
}
