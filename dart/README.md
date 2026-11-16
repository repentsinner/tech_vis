# tech_vis

Technical visualization primitives for annotated 3D scenes: leader-line
callouts, coordinate frames, labeled bounding boxes, and the style tokens
that give them one look. Pure Dart, renderer-agnostic: the package
computes geometry and layout, and a renderer of your choice draws it.

A Python package of the same name and version shares the style tokens.
Both come from [one repository](https://github.com/repentsinner/tech_vis).

## Installation

```bash
dart pub add tech_vis
```

## Usage

```dart
import 'package:tech_vis/tech_vis.dart';

// The app's own space: which axis points up, and its handedness. There is
// no default, and every input and output is in this space.
const convention = CoordinateConvention(
  up: SpatialAxis.y,
  handedness: Handedness.right,
);

final camera = CameraBasis.lookAt(
  position: eye,
  target: target,
  convention: convention,
);

// The world size of one pixel at the anchor, by its depth along the view
// axis. Null when the anchor is behind the camera.
final worldUnitsPerPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
  anchor,
  camera,
  verticalFovRadians,
  viewportHeight,
);

// A gap, an angled segment, then a horizontal segment, sized in pixels
// and returned in world space on the camera's screen plane.
final leader = computeCalloutLeaderGeometry(
  anchor: anchor,
  cameraRight: camera.right,
  cameraUp: camera.up,
  worldUnitsPerPixel: worldUnitsPerPixel!,
  quadrant: CalloutQuadrant.topRight,
);

final opacity = computeCalloutOpacity(distanceToCamera);
```

Factories return typed primitives, which a renderer maps into its own
scene graph. The set is closed, so a `switch` over a `Primitive` has
exactly five cases. Each primitive carries an opacity and the app's key,
passed through untouched. The package holds no palette, so the app
resolves each primitive's color from its key.

```dart
final box = BoundingBoxFactory.createCube(
  bounds: bounds,
  key: MyStyle.selection,
  fillOpacity: 0.2,
);

for (final primitive in box) {
  switch (primitive) {
    case LinePrimitive(:final start, :final end, :final widthPixels):
      drawLine(start, end, widthPixels, colorFor(primitive.key));
    case QuadPrimitive(:final corners):
      fillQuad(corners, colorFor(primitive.key), primitive.opacity);
    case BillboardPrimitive() || MarkerPrimitive() || MeshPrimitive():
      break; // A box emits only lines and quads.
  }
}
```

`StyleTokens` holds every style constant, generated from the repository's
`style/tokens.json`. `StyleTokens.styleVersion` identifies the token set.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
