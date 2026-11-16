import 'package:vector_math/vector_math_64.dart' as vm;

import 'bounding_box.dart';
import 'coordinate_convention.dart';
import 'primitives.dart';
import 'screen_space_utils.dart';

/// Factory for text labels attached to bounding box corners and edges.
///
/// Each label is a [BillboardPrimitive] whose content answers a
/// [TextRequest] for the label text at a pixel height. The app's
/// [TextResolver] sets the text in its own typeface and reports its pixel
/// size. The app key passes through to the label untouched.
///
/// Directions come from the declared [CoordinateConvention]. The top face
/// is the box's maximum along the up axis. Back is the convention's
/// fallback axis, the direction a top view keeps up on screen, and right
/// is the text direction, back cross up by the declared hand rule, so a
/// label reads left to right in a top view.
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
    required CoordinateConvention convention,
    required TextResolver resolveText,
    required Object? key,
    double pixelSize = defaultPixelSize,
    double offsetPixels = defaultOffsetPixels,
  }) {
    final frame = _LabelFrame(convention);
    final (rightSign, backSign) = switch (corner) {
      .topFrontLeft => (-1.0, -1.0),
      .topFrontRight => (1.0, -1.0),
      .topBackLeft => (-1.0, 1.0),
      .topBackRight => (1.0, 1.0),
    };
    final outward = frame.toward(right: rightSign, back: backSign);
    return BillboardPrimitive(
      content: resolveText(TextRequest(text: text, heightPixels: pixelSize)),
      anchor: _extremePoint(bounds, outward),
      offset: ScreenOffset(
        direction: outward.normalized(),
        pixels: offsetPixels,
      ),
      key: key,
    );
  }

  /// Returns a label at [position] that lies flat in the plane with normal
  /// [surfaceNormal], its text running along [textDirection].
  ///
  /// The normal defaults to the up axis of [convention] and the text
  /// direction to its right direction, so the label lies on a top face.
  /// The label is [pixelSize] pixels tall when viewed along the normal and
  /// foreshortens with perspective at oblique angles. [anchorAlignment] is
  /// the point of the label that sits on [position], and defaults to its
  /// center.
  static BillboardPrimitive createCoplanarBillboardLabel({
    required String text,
    required vm.Vector3 position,
    required CoordinateConvention convention,
    required TextResolver resolveText,
    required Object? key,
    double pixelSize = defaultPixelSize,
    vm.Vector3? surfaceNormal,
    vm.Vector3? textDirection,
    vm.Vector2? anchorAlignment,
  }) {
    // Built only when a default is needed.
    late final frame = _LabelFrame(convention);
    return BillboardPrimitive(
      content: resolveText(TextRequest(text: text, heightPixels: pixelSize)),
      anchor: position,
      orientation: CoplanarOrientation(
        normal: surfaceNormal ?? frame.up,
        right: textDirection ?? frame.right,
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
    required CoordinateConvention convention,
    required TextResolver resolveText,
    required Object? key,
    double pixelSize = defaultPixelSize,
  }) {
    final frame = _LabelFrame(convention);
    final rightSign = switch (alignment) {
      .left => -1.0,
      .center => 0.0,
      .right => 1.0,
    };
    final backSign = switch (edge) {
      .front => -1.0,
      .back => 1.0,
    };
    return createCoplanarBillboardLabel(
      text: text,
      position: _extremePoint(
        bounds,
        frame.toward(right: rightSign, back: backSign),
      ),
      convention: convention,
      resolveText: resolveText,
      key: key,
      pixelSize: pixelSize,
      surfaceNormal: frame.up,
      textDirection: frame.right,
      anchorAlignment: _anchorAlignmentForEdgeTab(edge, alignment),
    );
  }

  /// Returns the point of [bounds] farthest along [direction], taking the
  /// center on any axis [direction] leaves at zero.
  ///
  /// The label directions are signed unit axes, so their sum picks a
  /// corner, edge midpoint, or face center of the box.
  static vm.Vector3 _extremePoint(BoundingBox bounds, vm.Vector3 direction) {
    final min = bounds.minBounds;
    final max = bounds.maxBounds;
    double pick(int i) => direction[i] > 0
        ? max[i]
        : direction[i] < 0
        ? min[i]
        : (min[i] + max[i]) / 2;
    return vm.Vector3(pick(0), pick(1), pick(2));
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
}

/// Unit directions of a label on a top face, in the declared convention.
///
/// They are the axes of the package's own top-view camera, so a label
/// reads left to right in the same top view that [CameraBasis.lookAt]
/// builds, from one derivation of the fallback axis and the hand rule.
class _LabelFrame {
  factory _LabelFrame(CoordinateConvention convention) {
    final up = convention.up.unitVector;
    final topView = CameraBasis.lookAt(
      position: up,
      target: vm.Vector3.zero(),
      convention: convention,
    );
    return _LabelFrame._(topView.toViewer, topView.up, topView.right);
  }

  const _LabelFrame._(this.up, this.back, this.right);

  /// Normal of the top face.
  final vm.Vector3 up;

  /// Direction a top view keeps up on screen.
  final vm.Vector3 back;

  /// Direction text runs, left to right in a top view.
  final vm.Vector3 right;

  /// Returns the top-face direction [right] and [back] steps along each
  /// axis, as a sum of signed unit axes.
  vm.Vector3 toward({required double right, required double back}) =>
      up + this.right * right + this.back * back;
}

/// Corner of the top face of a bounding box, named as seen in a top view
/// of the declared convention.
enum LabelCorner {
  /// Front left corner.
  topFrontLeft,

  /// Front right corner.
  topFrontRight,

  /// Back left corner.
  topBackLeft,

  /// Back right corner.
  topBackRight,
}

/// Edge of the top face that a label tab attaches to, as seen in a top
/// view of the declared convention.
enum LabelEdge {
  /// Edge nearest the bottom of a top view.
  front,

  /// Edge nearest the top of a top view.
  back,
}

/// Position of a label along its attachment edge, in the label's text
/// direction.
enum LabelAlignment {
  /// Start of the edge.
  left,

  /// Midpoint of the edge.
  center,

  /// End of the edge.
  right,
}
