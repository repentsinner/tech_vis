import 'style_tokens.g.dart';

/// Generic layout constants for technical visualization scenes.
///
/// Contains domain-agnostic geometry values (sizes in mm/pixels, opacities,
/// edge widths) for axes, callout billboards, and leader lines.
///
/// Values come from [StyleTokens], generated from `style/tokens.json`, so
/// every implementation of the style shares them. Domain-specific constants
/// belong to the consuming package.
class SceneLayoutConstants {
  SceneLayoutConstants._();

  // ==================== AXIS SETTINGS ====================

  /// Default axis length in world units (mm).
  static const double axisLength = StyleTokens.axisLength;

  /// Default axis line thickness (screen-space logical pixels).
  static const double defaultAxisLineThickness =
      StyleTokens.defaultAxisLineThickness;

  /// Secondary-frame axis thickness scale factor relative to world axis
  /// thickness.
  static const double secondaryAxisThicknessScale =
      StyleTokens.secondaryAxisThicknessScale;

  /// Default axis label height in screen pixels.
  static const double defaultAxisLabelSize = StyleTokens.defaultAxisLabelSize;

  /// Screen-space offset in pixels from axis endpoint to label center.
  static const double axisLabelOffsetPixels = StyleTokens.axisLabelOffsetPixels;

  // ==================== CALLOUT BILLBOARD SETTINGS ====================

  /// Gap between anchor point and start of angled leader line segment (px).
  static const double calloutGapPixels = StyleTokens.calloutGapPixels;

  /// Length of the angled leader line segment (px).
  static const double calloutAngledLengthPixels =
      StyleTokens.calloutAngledLengthPixels;

  /// Length of the horizontal leader line segment (px).
  static const double calloutHorizontalLengthPixels =
      StyleTokens.calloutHorizontalLengthPixels;

  /// Angle of the angled leader line segment from horizontal (degrees).
  static const double calloutAngleDegrees = StyleTokens.calloutAngleDegrees;

  /// Line width for the callout leader line (screen-space logical pixels).
  static const double calloutLeaderLineWidth =
      StyleTokens.calloutLeaderLineWidth;

  /// Line width for the callout billboard border (screen-space logical pixels).
  /// Matches [calloutLeaderLineWidth] to avoid sub-pixel rendering artifacts
  /// at thinner widths where horizontal/vertical lines AA differently.
  static const double calloutBorderThickness =
      StyleTokens.calloutBorderThickness;

  /// Screen-pixel size for the callout label billboard.
  static const double calloutLabelPixelSize = StyleTokens.calloutLabelPixelSize;

  // ==================== CALLOUT OPACITY SETTINGS ====================

  /// Distance (world units) at or below which callouts are fully opaque.
  static const double calloutOpacityNearDistance =
      StyleTokens.calloutOpacityNearDistance;

  /// Distance (world units) at or above which callouts reach minimum opacity.
  static const double calloutOpacityFarDistance =
      StyleTokens.calloutOpacityFarDistance;

  /// Maximum callout opacity (at near distance).
  static const double calloutOpacityMax = StyleTokens.calloutOpacityMax;

  /// Minimum callout opacity (at far distance).
  static const double calloutOpacityMin = StyleTokens.calloutOpacityMin;
}
