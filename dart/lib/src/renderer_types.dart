/// Rendering mode supported by a backend.
enum RenderMode {
  /// Backend renders to a Canvas via CustomPaint.
  canvas,

  /// Backend provides its own Widget (e.g., a Texture widget).
  widget,
}

/// Viewport dimensions (Flutter-free alternative to Size).
class ViewportSize {
  final double width;
  final double height;

  const ViewportSize(this.width, this.height);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Per-frame context passed to the backend before rendering.
///
/// Contains generic viewport information. Domain-specific subclasses in
/// a domain package add fields like a tracked position and playback
/// progress.
class FrameContext {
  final ViewportSize viewportSize;
  final double devicePixelRatio;

  const FrameContext({
    required this.viewportSize,
    required this.devicePixelRatio,
  });
}
