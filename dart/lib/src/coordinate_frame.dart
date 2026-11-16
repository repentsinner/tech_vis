import 'package:vector_math/vector_math_64.dart' as vm;

import 'scene_layout_constants.dart';

/// Spatial axis in a right-handed coordinate system.
enum SpatialAxis {
  /// X axis (typically right).
  x,

  /// Y axis (typically forward/up depending on convention).
  y,

  /// Z axis (typically up/forward depending on convention).
  z;

  /// Unit vector along this axis.
  vm.Vector3 get unitVector => switch (this) {
    x => vm.Vector3(1, 0, 0),
    y => vm.Vector3(0, 1, 0),
    z => vm.Vector3(0, 0, 1),
  };

  /// Single-character uppercase label.
  String get label => name.toUpperCase();
}

/// Describes a single axis line within a coordinate frame.
///
/// Renderer-agnostic — carries geometry and identity only.
/// The rendering layer maps [axis] to a semantic color category.
class AxisLineDescriptor {
  const AxisLineDescriptor({
    required this.axis,
    required this.start,
    required this.end,
    required this.thickness,
  });

  /// Which axis this line represents.
  final SpatialAxis axis;

  /// Line start point (typically the frame origin).
  final vm.Vector3 start;

  /// Line end point (origin + length * unitVector).
  final vm.Vector3 end;

  /// Line thickness in screen-space logical pixels.
  final double thickness;

  /// Single-character label for this axis ("X", "Y", or "Z").
  String get label => axis.label;

  /// Unit direction vector along this axis.
  vm.Vector3 get direction => axis.unitVector;
}

/// Renderer-agnostic description of a coordinate frame (origin marker
/// with colored axis lines and labels).
///
/// Produces [AxisLineDescriptor]s that the scene composition layer
/// converts to renderer-specific primitives (e.g. [SceneObject]).
class CoordinateFrameDescriptor {
  CoordinateFrameDescriptor({
    vm.Vector3? origin,
    this.length = SceneLayoutConstants.axisLength,
    this.lineThickness = SceneLayoutConstants.defaultAxisLineThickness,
    this.showLabels = true,
    this.labelPixelSize = SceneLayoutConstants.defaultAxisLabelSize,
    this.labelOffsetPixels = SceneLayoutConstants.axisLabelOffsetPixels,
  }) : origin = origin ?? vm.Vector3.zero();

  /// Origin point of the coordinate frame in world coordinates.
  final vm.Vector3 origin;

  /// Length of each axis line in world units.
  final double length;

  /// Line thickness in screen-space logical pixels.
  final double lineThickness;

  /// Whether to include axis labels at endpoints.
  final bool showLabels;

  /// Pixel size for axis labels.
  final double labelPixelSize;

  /// Screen-space offset from axis endpoint to label center (px).
  final double labelOffsetPixels;

  /// Axis line descriptors for all three axes.
  ///
  /// Returns [x, y, z] in order, each starting at [origin] and
  /// extending [length] units along the axis direction.
  List<AxisLineDescriptor> get axes => [
    for (final axis in SpatialAxis.values)
      AxisLineDescriptor(
        axis: axis,
        start: origin,
        end: origin + axis.unitVector * length,
        thickness: lineThickness,
      ),
  ];
}
