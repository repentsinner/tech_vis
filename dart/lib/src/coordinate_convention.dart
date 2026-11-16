import 'package:vector_math/vector_math_64.dart' as vm;

import 'coordinate_frame.dart';

/// Rule that relates the three world axes to one another.
enum Handedness {
  /// X cross Y gives +Z by the right-hand rule.
  right,

  /// X cross Y gives +Z by the left-hand rule.
  left,
}

/// Convention of the space an app hands the package: which world axis
/// points up, and the handedness of the axes.
///
/// Every input and output of the package is in this space. The convention
/// has no default, because a wrong default fails silently: a Y-up scene
/// read as Z-up stands its floor on end. The package converts no data
/// between conventions; each orientation decision reads the app's own
/// space instead.
class CoordinateConvention {
  /// Creates the convention of a space whose [up] axis points up and whose
  /// axes follow [handedness].
  const CoordinateConvention({required this.up, required this.handedness});

  /// World axis that points up.
  final SpatialAxis up;

  /// Handedness of the world axes.
  final Handedness handedness;

  /// Axis that takes the place of [up] when a view looks straight along it.
  ///
  /// Returns the axis before [up] in the cycle X, Y, Z. A Z-up top view
  /// then keeps +Y up on screen, as a plan view does, and a Y-up top view
  /// keeps +X up.
  SpatialAxis get fallbackAxis => switch (up) {
    SpatialAxis.x => SpatialAxis.z,
    SpatialAxis.y => SpatialAxis.x,
    SpatialAxis.z => SpatialAxis.y,
  };

  /// Returns the two axes after [up] in the cycle X, Y, Z, which span the
  /// plane across it.
  ///
  /// A Z-up plane lies along X and Y, a Y-up plane along Z and X. Both
  /// axes point the positive way, so a coordinate read along either is
  /// the world coordinate in either handedness.
  ({SpatialAxis u, SpatialAxis v}) get planeAxes => switch (up) {
    SpatialAxis.x => (u: SpatialAxis.y, v: SpatialAxis.z),
    SpatialAxis.y => (u: SpatialAxis.z, v: SpatialAxis.x),
    SpatialAxis.z => (u: SpatialAxis.x, v: SpatialAxis.y),
  };

  /// Returns the cross product of [u] and [v] by the declared hand rule.
  ///
  /// The components of a right-handed space satisfy the textbook formula.
  /// A left-handed space mirrors one axis, which reverses the sign, so
  /// screen axes and face normals built from this agree with the app's
  /// space in either handedness.
  vm.Vector3 cross(vm.Vector3 u, vm.Vector3 v) => switch (handedness) {
    Handedness.right => u.cross(v),
    Handedness.left => v.cross(u),
  };

  @override
  String toString() => '${up.label}-up ${handedness.name}-handed';
}
