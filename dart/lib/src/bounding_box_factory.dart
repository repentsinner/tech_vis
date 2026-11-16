import 'package:vector_math/vector_math_64.dart' as vm;

import 'bounding_box.dart';
import 'filled_rectangle_factory.dart';
import 'primitives.dart';

/// Factory for axis-aligned boxes drawn around an object.
///
/// A box is twelve edge lines and, when it has a fill, six face quads. The
/// app key passes through to every primitive untouched.
class BoundingBoxFactory {
  /// Returns the primitives that draw [bounds].
  ///
  /// Emits each of the box's twelve edges once, as a line [edgeWidth]
  /// screen pixels wide. When [fillOpacity] is above zero, also emits the
  /// six faces as quads at that opacity. A box outlined from its faces
  /// would draw every edge twice, so the faces carry no edges.
  static List<Primitive> createCube({
    required BoundingBox bounds,
    required Object? key,
    double fillOpacity = 1.0,
    double edgeWidth = 1.0,
  }) {
    return [
      if (fillOpacity > 0)
        ..._faces(bounds: bounds, key: key, opacity: fillOpacity),
      ..._edges(bounds: bounds, key: key, edgeWidth: edgeWidth),
    ];
  }

  static List<LinePrimitive> _edges({
    required BoundingBox bounds,
    required Object? key,
    required double edgeWidth,
  }) {
    final lo = bounds.minBounds;
    final hi = bounds.maxBounds;
    final segments = <(vm.Vector3, vm.Vector3)>[
      // Four edges along X, at each Y–Z corner.
      for (final y in [lo.y, hi.y])
        for (final z in [lo.z, hi.z])
          (vm.Vector3(lo.x, y, z), vm.Vector3(hi.x, y, z)),
      // Four along Y, at each X–Z corner.
      for (final x in [lo.x, hi.x])
        for (final z in [lo.z, hi.z])
          (vm.Vector3(x, lo.y, z), vm.Vector3(x, hi.y, z)),
      // Four along Z, at each X–Y corner.
      for (final x in [lo.x, hi.x])
        for (final y in [lo.y, hi.y])
          (vm.Vector3(x, y, lo.z), vm.Vector3(x, y, hi.z)),
    ];
    return [
      for (final (start, end) in segments)
        LinePrimitive(start: start, end: end, widthPixels: edgeWidth, key: key),
    ];
  }

  static List<QuadPrimitive> _faces({
    required BoundingBox bounds,
    required Object? key,
    required double opacity,
  }) {
    final lo = bounds.minBounds;
    final hi = bounds.maxBounds;
    final center = bounds.center;
    final size = bounds.size;
    return [
      // XY plane faces (bottom and top)
      for (final z in [lo.z, hi.z])
        FilledRectangleFactory.createXYFilledRectangle(
          center: vm.Vector3(center.x, center.y, z),
          width: size.x.abs(),
          height: size.y.abs(),
          key: key,
          opacity: opacity,
        ),
      // XZ plane faces (front and back)
      for (final y in [lo.y, hi.y])
        FilledRectangleFactory.createXZFilledRectangle(
          center: vm.Vector3(center.x, y, center.z),
          width: size.x.abs(),
          height: size.z.abs(),
          key: key,
          opacity: opacity,
        ),
      // YZ plane faces (left and right)
      for (final x in [lo.x, hi.x])
        FilledRectangleFactory.createYZFilledRectangle(
          center: vm.Vector3(x, center.y, center.z),
          width: size.y.abs(),
          height: size.z.abs(),
          key: key,
          opacity: opacity,
        ),
    ];
  }
}
