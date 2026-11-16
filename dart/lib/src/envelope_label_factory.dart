import 'package:vector_math/vector_math_64.dart' as vm;

import 'bounding_box.dart';
import 'primitives.dart';

/// Factory for text labels attached to bounding box corners and edges.
///
/// Each label is a [BillboardPrimitive] whose content answers a
/// [TextRequest] for the label text at a pixel height. The app's
/// [TextResolver] sets the text in its own typeface and reports its pixel
/// size. The app key passes through to the label untouched.
class EnvelopeLabelFactory {
  /// Default pixel height of an envelope label.
  static const double defaultPixelSize = 20.0;

  /// Default screen-space pixel offset from a bounding box corner.
  static const double defaultOffsetPixels = 8.0;

  /// Returns a viewer-facing label at [corner] of the top face of
  /// [bounds].
  ///
  /// The label is [pixelSize] pixels tall and sits [offsetPixels] pixels
  /// from the corner on screen, outward from the box.
  static BillboardPrimitive createEnvelopeLabel({
    required String text,
    required BoundingBox bounds,
    required LabelCorner corner,
    required TextResolver resolveText,
    required Object? key,
    double pixelSize = defaultPixelSize,
    double offsetPixels = defaultOffsetPixels,
  }) {
    return BillboardPrimitive(
      content: resolveText(TextRequest(text: text, heightPixels: pixelSize)),
      anchor: _cornerPosition(bounds, corner),
      offset: ScreenOffset(
        direction: _anchorDirection(corner),
        pixels: offsetPixels,
      ),
      key: key,
    );
  }

  /// Returns a label at [position] that lies flat in the plane with normal
  /// [surfaceNormal], its text running along [textDirection].
  ///
  /// The label is [pixelSize] pixels tall when viewed along the normal and
  /// foreshortens with perspective at oblique angles. [anchorAlignment] is
  /// the point of the label that sits on [position], and defaults to its
  /// center.
  static BillboardPrimitive createCoplanarBillboardLabel({
    required String text,
    required vm.Vector3 position,
    required TextResolver resolveText,
    required Object? key,
    double pixelSize = defaultPixelSize,
    vm.Vector3? surfaceNormal,
    vm.Vector3? textDirection,
    vm.Vector2? anchorAlignment,
  }) {
    return BillboardPrimitive(
      content: resolveText(TextRequest(text: text, heightPixels: pixelSize)),
      anchor: position,
      orientation: CoplanarOrientation(
        normal: surfaceNormal ?? vm.Vector3(0, 0, 1),
        right: textDirection ?? vm.Vector3(1, 0, 0),
      ),
      alignment: anchorAlignment,
      key: key,
    );
  }

  /// Returns a coplanar label on [edge] of the top face of [bounds], like a
  /// tab attached to the envelope boundary.
  ///
  /// The label's edge, not its center, sits on the boundary, so the tab
  /// extends outward from the box.
  static BillboardPrimitive createEdgeTabLabel({
    required String text,
    required BoundingBox bounds,
    required LabelEdge edge,
    required LabelAlignment alignment,
    required TextResolver resolveText,
    required Object? key,
    double pixelSize = defaultPixelSize,
  }) {
    return createCoplanarBillboardLabel(
      text: text,
      position: _edgeTabPosition(bounds, edge, alignment),
      resolveText: resolveText,
      key: key,
      pixelSize: pixelSize,
      anchorAlignment: _anchorAlignmentForEdgeTab(edge, alignment),
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
