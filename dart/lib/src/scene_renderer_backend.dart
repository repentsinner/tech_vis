import 'package:vector_math/vector_math_64.dart' as vm;

import 'renderer_types.dart';
import 'scene_description.dart';

/// Renderer-agnostic backend interface for technical visualization.
///
/// Implementations consume [SceneDescription] data and produce rendered output.
/// The abstraction uses [ViewportSize] and [RenderMode] to avoid Flutter
/// framework dependencies in the domain layer. Infrastructure implementations
/// bridge to Flutter's Widget/Canvas/Size types.
///
/// Domain-specific subinterfaces add methods for domain-specific concerns
/// like travel limits and segment management.
abstract class SceneRendererBackend {
  /// Initialize the rendering backend.
  Future<bool> initialize();

  /// Update a single category's scene objects in the backend.
  Future<void> updateCategory(String name, SceneCategory? category);

  /// Set camera position and target.
  void setCameraState({
    required vm.Vector3 position,
    required vm.Vector3 target,
  });

  /// Prepare the frame for rendering (billboard updates, material params, etc.)
  void prepareFrame(FrameContext context);

  /// The rendering mode this backend uses.
  RenderMode get renderMode;

  /// Build the platform widget for this backend's rendered output.
  ///
  /// Returns an `Object` to avoid Flutter framework dependencies in the
  /// domain layer. Callers in the UI layer cast to `Widget`. Only valid
  /// when [renderMode] is [RenderMode.widget].
  Object buildWidget();

  /// Push updated visualization theme data into the rendering pipeline.
  ///
  /// [themeData] is an `Object` to avoid Flutter framework dependencies.
  /// Concrete implementations downcast to their expected theme type
  /// (e.g. `VisualizerThemeData`).
  void setVisualizerTheme(Object themeData);

  /// Release resources.
  void dispose();

  /// Whether the backend has been initialized.
  bool get isInitialized;

  /// AABB center of the idle-mode model in visualization coordinates.
  ///
  /// Non-null after the background category has been processed and contains
  /// a model with a computed AABB. Used for idle-mode camera targeting and
  /// callout billboard anchoring.
  vm.Vector3? get idleModelCenter;
}
