import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

import 'scene_layout_constants.dart';

/// Quadrant placement for leader line callouts.
///
/// Determines the direction of the angled leader line segment relative
/// to the anchor point. The label is positioned at the end of a
/// gap -> angled segment -> horizontal segment leader line.
enum CalloutQuadrant { topRight, topLeft, bottomRight, bottomLeft }

/// Visual style parameters for a leader line.
///
/// A leader line connects an anchor point to a label via two segments:
/// an angled segment departing the anchor, followed by a horizontal
/// segment ending at the label position. An optional gap separates
/// the anchor from the start of the angled segment.
class LeaderLineStyle {
  const LeaderLineStyle({
    this.lineWidth = SceneLayoutConstants.calloutLeaderLineWidth,
    this.gapPixels = SceneLayoutConstants.calloutGapPixels,
    this.angledLengthPixels = SceneLayoutConstants.calloutAngledLengthPixels,
    this.horizontalLengthPixels =
        SceneLayoutConstants.calloutHorizontalLengthPixels,
    this.angleDegrees = SceneLayoutConstants.calloutAngleDegrees,
  });

  /// Line width in screen-space logical pixels.
  final double lineWidth;

  /// Gap between anchor point and start of angled segment (px).
  final double gapPixels;

  /// Length of the angled segment (px).
  final double angledLengthPixels;

  /// Length of the horizontal segment (px).
  final double horizontalLengthPixels;

  /// Angle of the angled segment from horizontal (degrees).
  final double angleDegrees;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderLineStyle &&
          other.lineWidth == lineWidth &&
          other.gapPixels == gapPixels &&
          other.angledLengthPixels == angledLengthPixels &&
          other.horizontalLengthPixels == horizontalLengthPixels &&
          other.angleDegrees == angleDegrees;

  @override
  int get hashCode => Object.hash(
    lineWidth,
    gapPixels,
    angledLengthPixels,
    horizontalLengthPixels,
    angleDegrees,
  );
}

/// Result of computing callout leader line geometry.
///
/// Contains the three control points of the leader line polyline
/// (gap end, elbow, label edge) in world-space coordinates, aligned
/// to the camera's screen plane via basis vectors.
class CalloutLeaderGeometry {
  /// Start of visible leader line (after gap from anchor).
  final vm.Vector3 gapEnd;

  /// Bend point where angled segment meets horizontal segment.
  final vm.Vector3 elbow;

  /// End of leader line where the label billboard is centered.
  final vm.Vector3 labelEdge;

  const CalloutLeaderGeometry({
    required this.gapEnd,
    required this.elbow,
    required this.labelEdge,
  });
}

/// Compute leader line geometry in camera-aligned world space.
///
/// Projects a 2D screen-space leader line (gap → angled → horizontal)
/// into 3D world coordinates using [cameraRight] and [cameraUp] basis
/// vectors. The [worldUnitsPerPixel] factor converts pixel dimensions
/// from [style] into world-space distances.
///
/// Both rendering backends use this to compute the three-point leader
/// line from an anchor in camera-aligned screen space.
CalloutLeaderGeometry computeCalloutLeaderGeometry({
  required vm.Vector3 anchor,
  required vm.Vector3 cameraRight,
  required vm.Vector3 cameraUp,
  required double worldUnitsPerPixel,
  required CalloutQuadrant quadrant,
  LeaderLineStyle style = const LeaderLineStyle(),
}) {
  final angleRad = style.angleDegrees * math.pi / 180.0;

  final double hSign;
  final double vSign;
  switch (quadrant) {
    case CalloutQuadrant.topRight:
      hSign = 1.0;
      vSign = 1.0;
    case CalloutQuadrant.topLeft:
      hSign = -1.0;
      vSign = 1.0;
    case CalloutQuadrant.bottomRight:
      hSign = 1.0;
      vSign = -1.0;
    case CalloutQuadrant.bottomLeft:
      hSign = -1.0;
      vSign = -1.0;
  }

  final angledDir =
      cameraRight * (math.cos(angleRad) * hSign) +
      cameraUp * (math.sin(angleRad) * vSign);
  final horizontalDir = cameraRight * hSign;

  final gapEnd = anchor + angledDir * (style.gapPixels * worldUnitsPerPixel);
  final elbow =
      gapEnd + angledDir * (style.angledLengthPixels * worldUnitsPerPixel);
  final labelEdge =
      elbow +
      horizontalDir * (style.horizontalLengthPixels * worldUnitsPerPixel);

  return CalloutLeaderGeometry(
    gapEnd: gapEnd,
    elbow: elbow,
    labelEdge: labelEdge,
  );
}

/// Returns the billboard anchor alignment for a callout quadrant.
///
/// The alignment is a UV coordinate (0–1) indicating where the billboard
/// should be anchored relative to the label edge point.
vm.Vector2 calloutAnchorAlignment(CalloutQuadrant quadrant) {
  switch (quadrant) {
    case CalloutQuadrant.topRight:
    case CalloutQuadrant.bottomRight:
      return vm.Vector2(0.0, 0.5);
    case CalloutQuadrant.topLeft:
    case CalloutQuadrant.bottomLeft:
      return vm.Vector2(1.0, 0.5);
  }
}

/// Compute callout opacity based on anchor-to-camera distance.
///
/// Returns [SceneLayoutConstants.calloutOpacityMax] when [distance] is at or
/// below [SceneLayoutConstants.calloutOpacityNearDistance], linearly
/// interpolating to [SceneLayoutConstants.calloutOpacityMin] at or above
/// [SceneLayoutConstants.calloutOpacityFarDistance].
double computeCalloutOpacity(double distance) {
  const near = SceneLayoutConstants.calloutOpacityNearDistance;
  const far = SceneLayoutConstants.calloutOpacityFarDistance;
  const maxOpacity = SceneLayoutConstants.calloutOpacityMax;
  const minOpacity = SceneLayoutConstants.calloutOpacityMin;

  if (distance <= near) return maxOpacity;
  if (distance >= far) return minOpacity;

  // Linear interpolation: near→max, far→min
  final t = (distance - near) / (far - near);
  return maxOpacity + t * (minOpacity - maxOpacity);
}
