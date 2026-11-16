import 'package:vector_math/vector_math_64.dart' as vm;

import 'style_tokens.g.dart';

/// A corner of the viewport that an overlay anchors to.
///
/// The declaration order gives each corner's style token code, so the
/// order shall not change.
enum ViewportCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight;

  /// Returns the corner whose style token code is [code].
  ///
  /// Throws an [ArgumentError] when [code] is not 0, 1, 2, or 3.
  static ViewportCorner fromToken(double code) {
    // A code is a corner's index; NaN and fractions fail the round trip.
    final index = code.isFinite ? code.toInt() : -1;
    if (index != code || index < 0 || index >= values.length) {
      throw ArgumentError.value(code, 'code', 'not a viewport corner code');
    }
    return values[index];
  }

  /// Whether the corner is on the viewport's right edge.
  bool get isRight => this == topRight || this == bottomRight;

  /// Whether the corner is on the viewport's bottom edge.
  bool get isBottom => this == bottomLeft || this == bottomRight;
}

/// An overlay whose default placement the style holds.
enum ViewportOverlayKind { scaleBar, colorRampLegend, navigationCube }

/// A rectangle in viewport pixels, with the origin at the viewport's
/// top-left corner and y running down, as `worldToScreen` reports.
typedef ViewportRect = ({double left, double top, double right, double bottom});

/// Where an overlay sits in the viewport: a corner, an offset from it, and
/// a size, all in pixels.
///
/// The offset points from the corner toward the viewport center, so the
/// same offset keeps an overlay the same distance from its edges in any
/// corner.
class ViewportOverlayPlacement {
  const ViewportOverlayPlacement({
    required this.corner,
    required this.offsetXPixels,
    required this.offsetYPixels,
    required this.widthPixels,
    required this.heightPixels,
  });

  /// Returns the style's placement for [kind], with each given value in
  /// place of its token default.
  factory ViewportOverlayPlacement.of(
    ViewportOverlayKind kind, {
    ViewportCorner? corner,
    double? offsetXPixels,
    double? offsetYPixels,
    double? widthPixels,
    double? heightPixels,
  }) {
    final d = _defaults(kind);
    return ViewportOverlayPlacement(
      corner: corner ?? ViewportCorner.fromToken(d.corner),
      offsetXPixels: offsetXPixels ?? d.offsetX,
      offsetYPixels: offsetYPixels ?? d.offsetY,
      widthPixels: widthPixels ?? d.width,
      heightPixels: heightPixels ?? d.height,
    );
  }

  /// The viewport corner the overlay anchors to.
  final ViewportCorner corner;

  /// Horizontal distance from the corner to the overlay's nearer edge.
  final double offsetXPixels;

  /// Vertical distance from the corner to the overlay's nearer edge.
  final double offsetYPixels;

  /// The overlay's width.
  final double widthPixels;

  /// The overlay's height.
  final double heightPixels;

  /// Returns the overlay's rectangle in a viewport of [viewportSize]
  /// pixels.
  ///
  /// The rectangle is not clipped, so it extends past the viewport when
  /// the viewport is too small to hold it.
  ViewportRect rect(vm.Vector2 viewportSize) {
    final left = corner.isRight
        ? viewportSize.x - offsetXPixels - widthPixels
        : offsetXPixels;
    final top = corner.isBottom
        ? viewportSize.y - offsetYPixels - heightPixels
        : offsetYPixels;
    return (
      left: left,
      top: top,
      right: left + widthPixels,
      bottom: top + heightPixels,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportOverlayPlacement &&
          other.corner == corner &&
          other.offsetXPixels == offsetXPixels &&
          other.offsetYPixels == offsetYPixels &&
          other.widthPixels == widthPixels &&
          other.heightPixels == heightPixels;

  @override
  int get hashCode => Object.hash(
    corner,
    offsetXPixels,
    offsetYPixels,
    widthPixels,
    heightPixels,
  );
}

typedef _Defaults = ({
  double corner,
  double offsetX,
  double offsetY,
  double width,
  double height,
});

_Defaults _defaults(ViewportOverlayKind kind) => switch (kind) {
  ViewportOverlayKind.scaleBar => (
    corner: StyleTokens.scaleBarCorner,
    offsetX: StyleTokens.scaleBarOffsetXPixels,
    offsetY: StyleTokens.scaleBarOffsetYPixels,
    width: StyleTokens.scaleBarWidthPixels,
    height: StyleTokens.scaleBarHeightPixels,
  ),
  ViewportOverlayKind.colorRampLegend => (
    corner: StyleTokens.colorRampLegendCorner,
    offsetX: StyleTokens.colorRampLegendOffsetXPixels,
    offsetY: StyleTokens.colorRampLegendOffsetYPixels,
    width: StyleTokens.colorRampLegendWidthPixels,
    height: StyleTokens.colorRampLegendHeightPixels,
  ),
  ViewportOverlayKind.navigationCube => (
    corner: StyleTokens.navigationCubeCorner,
    offsetX: StyleTokens.navigationCubeOffsetXPixels,
    offsetY: StyleTokens.navigationCubeOffsetYPixels,
    width: StyleTokens.navigationCubeWidthPixels,
    height: StyleTokens.navigationCubeHeightPixels,
  ),
};
