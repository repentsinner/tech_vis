import 'coordinate_frame.dart';
import 'primitives.dart';

/// Factory for the primitives that draw a coordinate frame: an axis
/// indicator at any origin, such as a world, part, or fixture origin.
///
/// The [CoordinateFrameDescriptor] holds the geometry. This factory turns
/// it into lines and labels. Each app keys the axes itself, so the package
/// names no domain.
class CoordinateFrameFactory {
  /// Returns the primitives that draw [frame].
  ///
  /// Emits one line per axis, from the origin to the axis end, in X, Y, Z
  /// order. When the frame shows labels, also emits one viewer-facing
  /// billboard per axis end, offset along the axis on screen by the frame's
  /// label offset. Each label requests the axis letter at the frame's label
  /// pixel height, and [resolveText] answers with the app's content for it.
  ///
  /// [keyFor] gives each axis line its app key. [labelKeyFor] gives each
  /// label its key, and defaults to [keyFor].
  static List<Primitive> create(
    CoordinateFrameDescriptor frame, {
    required Object? Function(SpatialAxis axis) keyFor,
    required TextResolver resolveText,
    Object? Function(SpatialAxis axis)? labelKeyFor,
  }) {
    final axes = frame.axes;
    final labelKey = labelKeyFor ?? keyFor;
    return [
      for (final axisLine in axes)
        LinePrimitive(
          start: axisLine.start,
          end: axisLine.end,
          widthPixels: axisLine.thickness,
          key: keyFor(axisLine.axis),
        ),
      if (frame.showLabels)
        for (final axisLine in axes)
          BillboardPrimitive(
            content: resolveText(
              TextRequest(
                text: axisLine.label,
                heightPixels: frame.labelPixelSize,
              ),
            ),
            anchor: axisLine.end,
            offset: ScreenOffset(
              direction: axisLine.direction,
              pixels: frame.labelOffsetPixels,
            ),
            key: labelKey(axisLine.axis),
          ),
    ];
  }
}
