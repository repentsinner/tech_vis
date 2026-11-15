import 'package:vector_math/vector_math.dart' as vm;

import 'bounding_box.dart';
import 'filled_rectangle_factory.dart';
import 'scene_object.dart';

/// Factory for creating bounding box cubes from six filled rectangles.
///
/// Produces axis-aligned wireframe cubes by composing [FilledRectangleFactory]
/// rectangles for each face. The [lineCategory] parameter accepts any
/// domain-specific semantic category type — CNC callers pass `LineCategory`,
/// other domains pass their own category enum.
class BoundingBoxFactory {
  /// Create a cube from 6 filled rectangles using [FilledRectangleFactory].
  ///
  /// [bounds] - The bounding box to visualize
  /// [lineCategory] - Semantic category for color resolution
  /// [opacity] - Opacity for the entire cube (0.0 = invisible, 1.0 = solid)
  /// [edgeWidth] - Width of the rectangle edges
  /// [idPrefix] - Prefix for the rectangle IDs
  static List<SceneObject> createCube({
    required BoundingBox bounds,
    required Object? lineCategory,
    double opacity = 1.0,
    double edgeWidth = 1.0,
    String idPrefix = 'cube',
  }) {
    final rectangles = <SceneObject>[];

    final minBounds = bounds.minBounds;
    final maxBounds = bounds.maxBounds;
    final center = bounds.center;
    final size = bounds.size;

    // XY plane faces (top and bottom)
    rectangles.add(
      FilledRectangleFactory.createXYFilledRectangle(
        center: vm.Vector3(center.x, center.y, minBounds.z),
        width: size.x.abs(),
        height: size.y.abs(),
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        opacity: opacity,
        id: '${idPrefix}_xy_bottom',
      ),
    );
    rectangles.add(
      FilledRectangleFactory.createXYFilledRectangle(
        center: vm.Vector3(center.x, center.y, maxBounds.z),
        width: size.x.abs(),
        height: size.y.abs(),
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        opacity: opacity,
        id: '${idPrefix}_xy_top',
      ),
    );

    // XZ plane faces (front and back)
    rectangles.add(
      FilledRectangleFactory.createXZFilledRectangle(
        center: vm.Vector3(center.x, minBounds.y, center.z),
        width: size.x.abs(),
        height: size.z.abs(),
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        opacity: opacity,
        id: '${idPrefix}_xz_front',
      ),
    );
    rectangles.add(
      FilledRectangleFactory.createXZFilledRectangle(
        center: vm.Vector3(center.x, maxBounds.y, center.z),
        width: size.x.abs(),
        height: size.z.abs(),
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        opacity: opacity,
        id: '${idPrefix}_xz_back',
      ),
    );

    // YZ plane faces (left and right)
    rectangles.add(
      FilledRectangleFactory.createYZFilledRectangle(
        center: vm.Vector3(minBounds.x, center.y, center.z),
        width: size.y.abs(),
        height: size.z.abs(),
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        opacity: opacity,
        id: '${idPrefix}_yz_left',
      ),
    );
    rectangles.add(
      FilledRectangleFactory.createYZFilledRectangle(
        center: vm.Vector3(maxBounds.x, center.y, center.z),
        width: size.y.abs(),
        height: size.z.abs(),
        lineCategory: lineCategory,
        edgeWidth: edgeWidth,
        opacity: opacity,
        id: '${idPrefix}_yz_right',
      ),
    );

    return rectangles;
  }
}
