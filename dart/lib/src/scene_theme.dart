/// Flutter-free RGBA color for scene objects.
///
/// Components are normalized to [0.0, 1.0].
/// Used as the return type of [SceneTheme.resolveLineColor] so that
/// color resolution stays Flutter-free in the `tech_vis` layer.
class SceneColor {
  final double r;
  final double g;
  final double b;
  final double a;

  const SceneColor(this.r, this.g, this.b, this.a);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneColor &&
          other.r == r &&
          other.g == g &&
          other.b == b &&
          other.a == a;

  @override
  int get hashCode => Object.hash(r, g, b, a);

  @override
  String toString() => 'SceneColor($r, $g, $b, $a)';
}

/// Domain-facing interface for scene visualization theme data.
///
/// Contains generic line-weight properties and color resolution for
/// technical visualization. Domain-specific extensions in a domain
/// package narrow the [lineCategory] parameter type and add properties
/// like line weights for the consumer's own line categories.
///
/// Colors are resolved via semantic types — the concrete type of
/// [lineCategory] is domain-specific (e.g. a semantic line category enum
/// defined by the consumer).
abstract interface class SceneTheme {
  /// Line thickness for coordinate axes.
  double get axisLineThickness;

  /// World-space size for axis labels (mm).
  double get axisLabelSize;

  /// Resolve a semantic line category to a Flutter-free RGBA color.
  ///
  /// The [lineCategory] type is domain-specific — an implementation
  /// expects the category type its domain package defines.
  SceneColor resolveLineColor(Object lineCategory);
}
