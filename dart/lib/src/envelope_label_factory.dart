import 'package:vector_math/vector_math_64.dart' as vm;

import 'bounding_box.dart';
import 'scene_layout_constants.dart';
import 'scene_object.dart';

/// Factory for creating camera-facing text labels attached to bounding box
/// corners and edges.
///
/// Labels use [SceneObjectType.textBillboard] and are positioned at a
/// selected corner or edge of the top face of a bounding box.
///
/// The [lineCategory] and [labelType] parameters accept domain-specific
/// semantic types defined by the consumer. Infrastructure resolvers
/// cast to the expected type for color/style resolution.
class EnvelopeLabelFactory {
  /// Creates a text billboard [SceneObject] positioned at a corner of the
  /// given bounding box top face.
  ///
  /// - [text]: Label content (e.g., a device name or filename).
  /// - [bounds]: The bounding box whose corner hosts the label.
  /// - [corner]: Which corner of the top face to use.
  /// - [lineCategory]: Semantic category for background color resolution.
  /// - [idPrefix]: Unique ID prefix for the scene object.
  /// - [pixelSize]: Billboard pixel size for the label.
  /// - [offsetPixels]: Screen-space offset from the corner.
  /// Default billboard pixel size for envelope labels.
  static const double defaultPixelSize = 20.0;

  /// Default screen-space pixel offset from bounding box corner.
  static const double defaultOffsetPixels = 8.0;

  static SceneObject createEnvelopeLabel({
    required String text,
    required BoundingBox bounds,
    required LabelCorner corner,
    required Object? lineCategory,
    required String idPrefix,
    double pixelSize = defaultPixelSize,
    double offsetPixels = defaultOffsetPixels,
    Object? labelType,
  }) {
    final position = _cornerPosition(bounds, corner);
    final anchorDirection = _anchorDirection(corner);

    return SceneObject(
      type: .textBillboard,
      lineCategory: lineCategory,
      id: '${idPrefix}_label',
      center: position,
      text: text,
      labelType: labelType,
      worldSize: pixelSize,
      billboardAnchorDirection: anchorDirection,
      billboardOffsetPixels: offsetPixels,
    );
  }

  /// Creates a world-aligned text label [SceneObject] positioned at the given
  /// world coordinate, lying flat on the plane defined by [surfaceNormal].
  ///
  /// Unlike [createEnvelopeLabel], the label follows perspective distortion
  /// naturally (Fusion 360-style) rather than always facing the camera.
  static SceneObject createWorldAlignedLabel({
    required String text,
    required vm.Vector3 position,
    required Object? lineCategory,
    required String idPrefix,
    double? worldHeight,
    vm.Vector3? surfaceNormal,
    vm.Vector3? textDirection,
    Object? labelType,
  }) {
    final normal = surfaceNormal ?? vm.Vector3(0, 0, 1);
    final right = textDirection ?? vm.Vector3(1, 0, 0);
    final height =
        worldHeight ?? SceneLayoutConstants.worldAlignedLabelHeightMm;

    return SceneObject(
      type: .textBillboard,
      lineCategory: lineCategory,
      id: '${idPrefix}_label',
      center: position,
      text: text,
      labelType: labelType,
      worldSize: height,
      labelMode: .worldAligned,
      worldNormal: normal,
      worldRight: right,
    );
  }

  /// Creates a coplanar billboard text label [SceneObject] positioned at the
  /// given world coordinate, lying flat on the plane defined by
  /// [surfaceNormal].
  ///
  /// Maintains a constant screen-pixel height when viewed head-on along the
  /// surface normal but foreshortens naturally via perspective projection at
  /// oblique viewing angles.
  static SceneObject createCoplanarBillboardLabel({
    required String text,
    required vm.Vector3 position,
    required Object? lineCategory,
    required String idPrefix,
    double pixelSize = defaultPixelSize,
    vm.Vector3? surfaceNormal,
    vm.Vector3? textDirection,
    vm.Vector2? anchorAlignment,
    Object? labelType,
  }) {
    final normal = surfaceNormal ?? vm.Vector3(0, 0, 1);
    final right = textDirection ?? vm.Vector3(1, 0, 0);

    return SceneObject(
      type: .textBillboard,
      lineCategory: lineCategory,
      id: '${idPrefix}_label',
      center: position,
      text: text,
      labelType: labelType,
      worldSize: pixelSize,
      labelMode: .coplanarBillboard,
      worldNormal: normal,
      worldRight: right,
      anchorAlignment: anchorAlignment,
    );
  }

  /// Creates a coplanar billboard label positioned on a specific edge of the
  /// top face of [bounds], like a colored tab attached to the envelope
  /// boundary.
  ///
  /// The label's edge (not its center) aligns with the bounding-box boundary,
  /// so the tab extends outward from the plane — matching Fusion 360 style.
  static SceneObject createEdgeTabLabel({
    required String text,
    required BoundingBox bounds,
    required LabelEdge edge,
    required LabelAlignment alignment,
    required Object? lineCategory,
    required String idPrefix,
    double? pixelSize,
    Object? labelType,
  }) {
    final position = _edgeTabPosition(bounds, edge, alignment);
    final anchor = _anchorAlignmentForEdgeTab(edge, alignment);

    return createCoplanarBillboardLabel(
      text: text,
      position: position,
      lineCategory: lineCategory,
      idPrefix: idPrefix,
      pixelSize: pixelSize ?? 20.0,
      anchorAlignment: anchor,
      labelType: labelType,
    );
  }

  /// Computes the world position for a label at the given [corner] of the
  /// bounding box top face (maxBounds.z).
  static vm.Vector3 _cornerPosition(BoundingBox bounds, LabelCorner corner) {
    final min = bounds.minBounds;
    final max = bounds.maxBounds;
    final topZ = max.z;

    return switch (corner) {
      .topFrontLeft => vm.Vector3(min.x, min.y, topZ),
      .topFrontRight => vm.Vector3(max.x, min.y, topZ),
      .topBackLeft => vm.Vector3(min.x, max.y, topZ),
      .topBackRight => vm.Vector3(max.x, max.y, topZ),
    };
  }

  /// Computes the world position on a top-face edge of [bounds] for the given
  /// [edge] and [alignment].
  static vm.Vector3 _edgeTabPosition(
    BoundingBox bounds,
    LabelEdge edge,
    LabelAlignment alignment,
  ) {
    final min = bounds.minBounds;
    final max = bounds.maxBounds;

    final x = switch (alignment) {
      .left => min.x,
      .center => (min.x + max.x) / 2,
      .right => max.x,
    };

    final y = switch (edge) {
      .front => min.y,
      .back => max.y,
    };

    return vm.Vector3(x, y, max.z);
  }

  /// Computes the anchor alignment for an edge tab label so the quad's edge
  /// (not its center) sits at the bounding-box boundary.
  static vm.Vector2 _anchorAlignmentForEdgeTab(
    LabelEdge edge,
    LabelAlignment alignment,
  ) {
    final anchorX = switch (alignment) {
      .left => 0.0,
      .center => 0.5,
      .right => 1.0,
    };

    final anchorY = switch (edge) {
      .front => 1.0,
      .back => 0.0,
    };

    return vm.Vector2(anchorX, anchorY);
  }

  /// Returns a normalized direction vector pointing outward from the bounding
  /// box center for the given corner.
  static vm.Vector3 _anchorDirection(LabelCorner corner) {
    final direction = switch (corner) {
      .topFrontLeft => vm.Vector3(-1, -1, 1),
      .topFrontRight => vm.Vector3(1, -1, 1),
      .topBackLeft => vm.Vector3(-1, 1, 1),
      .topBackRight => vm.Vector3(1, 1, 1),
    };

    return direction.normalized();
  }
}

/// Corner position for a label on the top face of a bounding box.
enum LabelCorner {
  /// Min X, Min Y, Max Z
  topFrontLeft,

  /// Max X, Min Y, Max Z
  topFrontRight,

  /// Min X, Max Y, Max Z
  topBackLeft,

  /// Max X, Max Y, Max Z
  topBackRight,
}

/// Which horizontal edge of the top face the label tab attaches to.
enum LabelEdge {
  /// MinY edge.
  front,

  /// MaxY edge.
  back,
}

/// Horizontal alignment of a label along its attachment edge.
enum LabelAlignment {
  /// MinX end of the edge.
  left,

  /// Midpoint of the edge.
  center,

  /// MaxX end of the edge.
  right,
}
