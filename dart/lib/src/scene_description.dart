import 'scene_object.dart';

/// Renderer-agnostic description of the complete 3D scene.
///
/// Organizes scene objects into named categories that can be independently
/// updated. Each category is nullable — null means that category has no
/// content.
///
/// Generic base class. Domain-specific subclasses add domain-specific
/// category slots.
class SceneDescription {
  final SceneCategory? staticCategory;
  final SceneCategory? backgroundCategory;

  /// Domain-specific categories keyed by name.
  ///
  /// Subclasses expose typed accessors for their categories and populate
  /// this map. The rendering backend iterates all categories generically.
  final Map<String, SceneCategory?> additionalCategories;

  const SceneDescription({
    this.staticCategory,
    this.backgroundCategory,
    this.additionalCategories = const {},
  });

  /// All categories (including nulls) for generic iteration.
  Iterable<MapEntry<String, SceneCategory?>> get allCategories sync* {
    yield MapEntry('static', staticCategory);
    yield MapEntry('background', backgroundCategory);
    yield* additionalCategories.entries;
  }
}

/// A named category of scene objects.
///
/// Generic base class. Domain-specific subclasses add domain-specific
/// properties like per-segment data or dimming state.
class SceneCategory {
  final String name;
  final List<SceneObject> objects;

  const SceneCategory({required this.name, required this.objects});
}
