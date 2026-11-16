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

A billboard places 2D content that the app prepares, such as text, an
icon, or a video frame, by the content's size in screen pixels. The
package never measures or draws the content. When a factory composes text
of its own, such as an axis letter or an envelope label, it sends a
`TextRequest` (the string and a pixel height) to a resolver that the app
supplies. The resolver sets the text in the app's typeface and returns the
content with its measured size, so every billboard arrives sized.

```dart
BillboardContent resolveText(TextRequest request) {
  final layout = myTextLayout(request.text, request.heightPixels);
  return BillboardContent(
    value: layout,
    widthPixels: layout.width,
    heightPixels: layout.height,
  );
}

final frame = CoordinateFrameFactory.create(
  CoordinateFrameDescriptor(origin: origin),
  keyFor: (axis) => MyStyle.axis(axis),
  resolveText: resolveText,
);

final envelope = EnvelopeLabelFactory.createEnvelopeLabel(
  text: '120 × 80 × 40',
  bounds: bounds,
  corner: LabelCorner.topFrontLeft,
  convention: convention,
  resolveText: resolveText,
  key: MyStyle.envelope,
);

// A callout's label sits at the end of its leader, extending away from it.
final label = createCalloutLabel(
  leader: leader,
  quadrant: CalloutQuadrant.topRight,
  content: resolveText(
    const TextRequest(
      text: 'Datum A',
      heightPixels: SceneLayoutConstants.calloutLabelPixelSize,
    ),
  ),
  key: MyStyle.callout,
  opacity: opacity,
);
```

A marker is a sphere that keeps its diameter in screen pixels at any
distance. The package generates the sphere's mesh, so there is no model
file to load. Every marker in one convention shares that mesh, and its
triangles face outward in either handedness. Each frame, ask for the
marker's transform and draw the mesh with it.

```dart
final marker = MarkerFactory.create(
  position: point,
  convention: convention,
  key: MyStyle.probe,
  diameterPixels: 10,
);

// Null when the marker is on or behind the camera plane.
final transform = MarkerFactory.transform(
  marker,
  camera,
  verticalFovRadians,
  viewportHeight,
);
if (transform != null) drawMesh(marker.mesh, transform, colorFor(marker.key));
```

`StyleTokens` holds every style constant, generated from the repository's
`style/tokens.json`. `StyleTokens.styleVersion` identifies the token set.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
