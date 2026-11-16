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
    // Each pair of opposite faces lies in one plane, at the low and high
    // bound of the axis normal to it.
    final planes = [
      (plane: RectanglePlane.xy, normal: 2, width: size.x, height: size.y),
      (plane: RectanglePlane.xz, normal: 1, width: size.x, height: size.z),
      (plane: RectanglePlane.yz, normal: 0, width: size.y, height: size.z),
    ];
    return [
      for (final (:plane, :normal, :width, :height) in planes)
        for (final bound in [lo, hi])
          FilledRectangleFactory.createFilledRectangle(
            center: center.clone()..[normal] = bound[normal],
            width: width.abs(),
            height: height.abs(),
            plane: plane,
            key: key,
            opacity: opacity,
          ),
    ];
  }
}
