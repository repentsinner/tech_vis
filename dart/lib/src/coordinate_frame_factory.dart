import 'coordinate_frame.dart';
import 'scene_object.dart';

/// Factory for the scene objects that draw a coordinate frame: an axis
/// indicator at any origin, such as a world, part, or fixture origin.
///
/// The [CoordinateFrameDescriptor] holds the geometry. This factory turns
/// it into lines and labels. Each consumer maps axes to its own semantic
/// line categories, so the package names no domain.
class CoordinateFrameFactory {
  /// Create the scene objects that draw [frame].
  ///
  /// Emits one line per axis, from the origin to the axis end, with
  /// `<idPrefix>_<axis>` ids. When the frame shows labels, also emits one
  /// billboard per axis end, offset along the axis on screen by the frame's
  /// label offset, with `<idPrefix>_label_<axis>` ids.
  ///
  /// [lineCategoryFor] gives each axis its line category, which the
  /// consumer's theme resolves to a color. [labelType] is the consumer's
  /// label type for the theme to size and style the labels.
  static List<SceneObject> create(
    CoordinateFrameDescriptor frame, {
    required Object? Function(SpatialAxis axis) lineCategoryFor,
    Object? labelType,
    String idPrefix = 'frame',
  }) {
    final axes = frame.axes;
    return [
      for (final axisLine in axes)
        SceneObject(
          type: .line,
          lineCategory: lineCategoryFor(axisLine.axis),
          id: '${idPrefix}_${axisLine.axis.name}',
          startPoint: axisLine.start,
          endPoint: axisLine.end,
          thickness: axisLine.thickness,
        ),
      if (frame.showLabels)
        for (final axisLine in axes)
          SceneObject(
            type: .textBillboard,
            lineCategory: lineCategoryFor(axisLine.axis),
            id: '${idPrefix}_label_${axisLine.axis.name}',
            center: axisLine.end,
            text: axisLine.label,
            labelType: labelType,
            worldSize: frame.labelPixelSize,
            billboardAnchorDirection: axisLine.direction,
            billboardOffsetPixels: frame.labelOffsetPixels,
          ),
    ];
  }
}
