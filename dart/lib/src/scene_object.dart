import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

import 'leader_line.dart';
import 'scene_theme.dart';

/// Orientation mode for text labels in 3D space.
///
/// - [billboard]: Camera-facing label with constant screen-pixel size (default).
/// - [worldAligned]: Fixed world-space orientation, scales with perspective.
/// - [coplanarBillboard]: Lies flat on the envelope surface (perspective
///   foreshortening at oblique angles) but maintains a constant screen-pixel
///   height when viewed head-on along the surface normal.
enum TextLabelMode {
  billboard,
  worldAligned,
  coplanarBillboard,
  calloutBillboard,
}

/// Individual object in the 3D scene.
///
/// Carries semantic meaning only — the [lineCategory] describes *what* this
/// object represents. The infrastructure rendering layer resolves semantic
/// categories to visual properties (colors, line weights) via theme interfaces.
///
/// Generic base class. Domain-specific subclasses (e.g. `CncSceneObject`)
/// add properties like feedRate, spindleMode, and violation flags.
class SceneObject {
  final SceneObjectType type;

  /// Semantic category describing what this object represents.
  ///
  /// The concrete type is domain-specific (e.g. `LineCategory` for CNC).
  /// Infrastructure resolvers cast to the expected type for color resolution.
  final Object? lineCategory;

  final String id;

  // Line segment properties (for SceneObjectType.line)
  final vm.Vector3? startPoint;
  final vm.Vector3? endPoint;
  final double? thickness;

  // Filled rectangle properties (for SceneObjectType.filledRectangle)
  final vm.Vector3? center;
  final double? width;
  final double? height;
  final RectanglePlane? plane;
  final double? rotation;
  final double? edgeWidth;
  final double? opacity;

  // Text billboard properties (for SceneObjectType.textBillboard)
  final String? text;

  /// Semantic label type for theme resolution.
  ///
  /// The concrete type is domain-specific (e.g. `LabelType` for CNC).
  final Object? labelType;
  final double? worldSize;

  // World-aligned label properties (for SceneObjectType.textBillboard)
  final TextLabelMode? labelMode;
  final vm.Vector3? worldNormal;
  final vm.Vector3? worldRight;

  // Coplanar label anchor alignment.
  final vm.Vector2? anchorAlignment;

  // Callout billboard quadrant.
  final CalloutQuadrant? calloutQuadrant;

  // Billboard anchor offset (for SceneObjectType.textBillboard)
  final vm.Vector3? billboardAnchorDirection;
  final double? billboardOffsetPixels;

  // Machine position properties (for SceneObjectType.machinePosition)
  final vm.Vector3? position;

  // 3D Model properties (for SceneObjectType.model)
  final String? modelAssetPath;
  final double? modelScale;

  // Procedural mesh properties (for SceneObjectType.proceduralMesh)
  final ProceduralMesh? proceduralMesh;

  /// Pre-resolved per-vertex RGBA color.
  ///
  /// When set, the rendering backend uses this color directly instead of
  /// resolving from [lineCategory] via the theme. The composition layer
  /// sets this after applying domain-specific color logic (violation
  /// overrides, feedrate encoding, spindle opacity).
  final SceneColor? resolvedColor;

  const SceneObject({
    required this.type,
    required this.lineCategory,
    required this.id,
    this.startPoint,
    this.endPoint,
    this.thickness,
    this.center,
    this.width,
    this.height,
    this.plane,
    this.rotation,
    this.edgeWidth,
    this.opacity,
    this.text,
    this.labelType,
    this.worldSize,
    this.labelMode,
    this.worldNormal,
    this.worldRight,
    this.anchorAlignment,
    this.calloutQuadrant,
    this.billboardAnchorDirection,
    this.billboardOffsetPixels,
    this.position,
    this.modelAssetPath,
    this.modelScale,
    this.proceduralMesh,
    this.resolvedColor,
  });
}

enum SceneObjectType {
  line,
  toolpathLine,
  cube,
  filledRectangle,
  textBillboard,
  machinePosition,
  model,
  marker,
  proceduralMesh,
}

/// Renderer-agnostic triangle mesh for procedurally generated geometry.
class ProceduralMesh {
  const ProceduralMesh({
    required this.positions,
    required this.normals,
    required this.indices,
  });

  /// Interleaved XYZ vertex positions in mm (Z-up coordinates).
  final Float32List positions;

  /// Interleaved XYZ unit normals, one per vertex.
  final Float32List normals;

  /// Triangle indices (CCW winding).
  final Uint16List indices;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

enum RectanglePlane { xy, xz, yz }

/// Object-based scene data for factory methods.
class SceneData {
  final List<SceneObject> objects;
  final CameraConfiguration camera;

  const SceneData({required this.objects, required this.camera});
}

/// Camera configuration for the scene.
class CameraConfiguration {
  final vm.Vector3 position;
  final vm.Vector3 target;
  final vm.Vector3 up;
  final double fov;

  const CameraConfiguration({
    required this.position,
    required this.target,
    required this.up,
    required this.fov,
  });
}
