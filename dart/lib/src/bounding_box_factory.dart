import 'package:vector_math/vector_math_64.dart' as vm;

import 'bounding_box.dart';
import 'filled_rectangle_factory.dart';
import 'scene_object.dart';

/// Factory for axis-aligned boxes drawn around an object.
///
/// A box is twelve edge lines and, when it has a fill, six face
/// rectangles. The [lineCategory] parameter accepts any domain-specific
/// semantic category type; each consumer passes its own category enum.
class BoundingBoxFactory {
  /// Create the scene objects that draw [bounds].
  ///
  /// Emits each of the box's twelve edges once, as a line of thickness
  /// [edgeWidth]. When [opacity] is above zero, also emits the six faces at
  /// that opacity. The faces carry no edge of their own, so a renderer
  /// that outlines filled rectangles does not draw any box edge twice.
  ///
  /// [idPrefix] prefixes every object's id: `<prefix>_edge_<n>` for edges
  /// and `<prefix>_<plane>_<side>` for faces.
  static List<SceneObject> createCube({
    required BoundingBox bounds,
    required Object? lineCategory,
    double opacity = 1.0,
    double edgeWidth = 1.0,
    String idPrefix = 'cube',
  }) {
    return [
      if (opacity > 0)
        ..._faces(
          bounds: bounds,
          lineCategory: lineCategory,
          opacity: opacity,
          idPrefix: idPrefix,
        ),
      ..._edges(
        bounds: bounds,
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        idPrefix: idPrefix,
      ),
    ];
  }

  static List<SceneObject> _edges({
    required BoundingBox bounds,
    required Object? lineCategory,
    required double edgeWidth,
    required String idPrefix,
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
      for (var i = 0; i < segments.length; i++)
        SceneObject(
          type: .line,
          lineCategory: lineCategory,
          id: '${idPrefix}_edge_$i',
          startPoint: segments[i].$1,
          endPoint: segments[i].$2,
          thickness: edgeWidth,
        ),
    ];
  }

  static List<SceneObject> _faces({
    required BoundingBox bounds,
    required Object? lineCategory,
    required double opacity,
    required String idPrefix,
  }) {
    final lo = bounds.minBounds;
    final hi = bounds.maxBounds;
    final center = bounds.center;
    final size = bounds.size;
    return [
      // XY plane faces (bottom and top)
      for (final (z, side) in [(lo.z, 'bottom'), (hi.z, 'top')])
        FilledRectangleFactory.createXYFilledRectangle(
          center: vm.Vector3(center.x, center.y, z),
          width: size.x.abs(),
          height: size.y.abs(),
          lineCategory: lineCategory,
          edgeWidth: 0,
          opacity: opacity,
          id: '${idPrefix}_xy_$side',
        ),
      // XZ plane faces (front and back)
      for (final (y, side) in [(lo.y, 'front'), (hi.y, 'back')])
        FilledRectangleFactory.createXZFilledRectangle(
          center: vm.Vector3(center.x, y, center.z),
          width: size.x.abs(),
          height: size.z.abs(),
          lineCategory: lineCategory,
          edgeWidth: 0,
          opacity: opacity,
          id: '${idPrefix}_xz_$side',
        ),
      // YZ plane faces (left and right)
      for (final (x, side) in [(lo.x, 'left'), (hi.x, 'right')])
        FilledRectangleFactory.createYZFilledRectangle(
          center: vm.Vector3(x, center.y, center.z),
          width: size.y.abs(),
          height: size.z.abs(),
          lineCategory: lineCategory,
          edgeWidth: 0,
          opacity: opacity,
          id: '${idPrefix}_yz_$side',
        ),
    ];
  }
}
