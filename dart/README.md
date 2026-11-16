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

Each frame, `createCalloutLeaderLines` turns the leader into the two
lines a renderer draws: the angled segment from the gap end to the elbow,
and the horizontal segment from the elbow to the label edge, both at the
style's line width in pixels.

```dart
final leaderLines = createCalloutLeaderLines(
  leader: leader,
  key: MyStyle.callout,
  opacity: opacity,
);
```

The rest of this page is the renderer guide. It states what each piece
of output means to the engine that draws it. A renderer author reads it
to judge whether an engine can honor the package's placement, then
measures a rendered frame to show that it does.

## Placement and pixel fidelity

The package guarantees placement: where each annotation lands on screen
and how big it is there. A label 16 pixels tall is 16 pixels tall at any
distance, and a leader starts the same few pixels from its anchor in
every engine.

Pixel fidelity belongs to the renderer. Anti-aliasing, glyph
rasterization, blending, and shading are the engine's choice, so two
engines can draw the same scene with different edges and still agree on
placement. The reference geometry described below measures placement
only, for that reason.

## Coordinate convention

The app declares the convention of its own space with a
`CoordinateConvention`: which world axis points up, and whether the axes
are right- or left-handed. The convention has no default, because a
wrong guess fails silently. A Y-up scene read as Z-up draws its floor as
a wall.

Every input and output is in that declared space. The package never
converts a point between conventions, so the app hands over its own
coordinates and draws the results as they come back. The convention
decides orientation details such as the camera's fallback up axis in a
top view, the top face an envelope label sits on, and the winding of
generated triangles.

## Camera

Placement assumes one perspective camera. To draw a frame, use a
perspective camera whose position, target, vertical field of view, and
viewport size match the values passed to the package for that frame.
The view axis passes through the viewport center, and pixels are
square.

`CameraBasis.lookAt` builds the camera's forward, right, and up axes
from the position, the target, and the convention. Pass the same basis,
field of view, and viewport to every call for one frame, so sizes and
positions agree. An orthographic camera, or a camera that differs from
the one the package saw, lands annotations in the wrong place.

## Primitives

Factories return typed primitives, which a renderer maps into its own
scene graph. The set is closed, so a `switch` over a `Primitive` has
exactly five cases. Each primitive carries an opacity from 0 to 1 and
the app's key, passed through untouched.

A renderer handles each primitive as follows:

- **Line**: draw the segment between its two world endpoints at
  `widthPixels` screen pixels, constant along its length at any depth.
  The width never scales with distance. Anti-alias a line narrower than
  one pixel, so it fades instead of breaking up.
- **Quad**: fill the face through its four world corners, which run in
  order around the perimeter.
- **Billboard**: draw the app's content at its size in screen pixels,
  with the content's `alignment` point on the anchor. Alignment is a
  fraction of the content's width and height, counted from its
  bottom-left corner. A viewer-facing billboard stays upright and faces
  the viewer. A coplanar one lies in its plane and foreshortens at
  oblique angles. Multiply the content's own alpha by the primitive's
  opacity.
- **Marker**: draw the shared unit-sphere mesh at the transform that
  `MarkerFactory.transform` returns for the frame. The transform keeps
  the sphere at its diameter in screen pixels.
- **Mesh**: draw the triangles as given. Each face winds outward by the
  declared hand rule, so back-face culling set to that handedness keeps
  the outside.

Three rules hold for every primitive:

- Apply its opacity.
- Recompute its per-frame placement in every frame in which the camera or
  an anchor moves. Pixel sizes, billboard rotations, screen offsets, and
  marker transforms all depend on the camera.
- Take its geometry from the primitive itself. Annotations need no
  model, texture, or font file, so a renderer loads no asset to draw
  them.

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

A billboard with a `ScreenOffset` moves from its anchor by a number of
pixels along a world direction, as that direction appears on screen.
Each frame, size the pixel at the anchor, apply the offset, and turn the
content to face the viewer:

```dart
void placeBillboard(BillboardPrimitive billboard) {
  final worldUnitsPerPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
    billboard.anchor,
    camera,
    verticalFovRadians,
    viewportHeight,
  );
  if (worldUnitsPerPixel == null) return; // Behind the camera.

  final offset = billboard.offset;
  final position = offset == null
      ? billboard.anchor
      : billboardOffsetPosition(
          anchor: billboard.anchor,
          direction: offset.direction,
          offsetPixels: offset.pixels,
          worldUnitsPerPixel: worldUnitsPerPixel,
          camera: camera,
        );

  // A +Z-facing quad turned to face the viewer, upright on screen.
  final rotation = screenAlignedRotation(camera);
  final width = billboard.content.widthPixels * worldUnitsPerPixel;
  final height = billboard.content.heightPixels * worldUnitsPerPixel;
  drawContent(billboard, position, rotation, width, height);
}
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

## Draw order

Callouts read best when nearer ones draw over farther ones.
`drawRanksByDistance` turns each callout's distance from the camera into
a draw rank inside a range the renderer supplies, with ties broken by
id. Draw a ranked primitive over scene geometry regardless of depth, and
a higher rank over a lower one. Scene geometry never hides a ranked
callout, so a label stays legible behind the part it annotates.

## Color

The package converts no color and holds no palette. Its only color
output is opacity. The app resolves each primitive's color from its key,
in whatever color space its renderer needs, such as sRGB for a texture
or linear for a shader input. Where a feature blends two colors, the app
supplies the blend.

## Text

A billboard places 2D content that the app prepares, such as text, an
icon, or a video frame, by the content's size in screen pixels. The
package never measures or draws the content. When a factory composes text
of its own, such as an axis letter or an envelope label, it sends a
`TextRequest` (the string and a pixel height) to a resolver that the app
supplies. The resolver sets the text in the app's typeface and returns the
content with its measured size, so every billboard arrives sized. Draw
the content at the size the resolver reported.

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

## Measure a frame against the reference geometry

The repository's
[`vectors/reference_screen_geometry.json`](https://github.com/repentsinner/tech_vis/blob/main/vectors/reference_screen_geometry.json)
records where every primitive of a set of sample scenes lands on screen.
The scenes cover Y-up and Z-up conventions, both handednesses, off-axis
cameras, and a view straight down the up axis. Each scene records its
convention and factory inputs. Each view records a camera, a vertical
field of view in degrees, a viewport, and the expected screen geometry.

Screen points are in the coordinates of `ScreenSpaceUtils.worldToScreen`.
The origin is the viewport's top-left corner, x runs right, y runs down,
and the bottom-right corner is (width, height). The fixture records:

- a line's two endpoints and its width in pixels, including the two
  lines of each callout leader;
- a quad's four corners;
- a marker's center and its diameter in pixels;
- a billboard's placed anchor, alignment, text request, content size,
  and box as `[left, top, right, bottom]`.

Every value except a billboard's content size and box holds for any
typeface. The generator sets text with a stand-in typeface in which each
character is half as wide as the text is tall. Your typeface gives a
different size, so recompute each billboard's box from your own measured
content size before you compare it. Alignment counts up from the
bottom-left corner while screen y runs down, so for an anchor (x, y) and
content size (w, h):

```dart
final left = x - alignment.x * w;
final top = y - (1 - alignment.y) * h;
final box = [left, top, left + w, top + h];
```

To check a renderer:

1. Build each sample scene from its recorded convention and factory
   inputs, and set your text resolver to your own typeface.
2. Render each view with its recorded camera, field of view, and
   viewport.
3. Measure the frame: line endpoints and widths, quad corners, marker
   centers and diameters, and billboard boxes.
4. Compare each measurement with the fixture, using your recomputed
   billboard boxes.
5. Record the largest difference as your renderer's tolerance, in
   pixels.

Keep the recorded tolerance with your renderer's tests, and let it only
tighten. A change that needs a looser tolerance has moved an annotation,
which is a regression in placement rather than a matter of style.

## Viewport overlays

An overlay is an element that holds still while the scene moves, such as
a scale bar, a color ramp legend, or a navigation cube. The package
describes an overlay in viewport pixels rather than world coordinates,
and the renderer draws it in a 2D layer above the scene. Overlays are a
second kind of output beside the primitives, so a `switch` over a
`Primitive` never meets one.

An overlay anchors to one corner of the viewport, with an offset from
that corner and a size, all in pixels. The offset points toward the
viewport center, so the same offset keeps an overlay the same distance
from its two edges in any corner. `ViewportOverlayPlacement.of` returns
the style's default placement for an overlay kind, and each named
argument replaces one default:

```dart
final cube = ViewportOverlayPlacement.of(ViewportOverlayKind.navigationCube);
final legend = ViewportOverlayPlacement.of(
  ViewportOverlayKind.colorRampLegend,
  corner: ViewportCorner.topLeft,
);

// Pixels from the viewport's top-left corner, y down, as worldToScreen.
final rect = legend.rect(Vector2(1280, 720));
drawLegend(left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom);
```

By default the navigation cube sits top-right, the scale bar
bottom-left, and the color ramp legend bottom-right, so the three never
share a corner. The rectangle is not clipped to the viewport.

## Style tokens

`StyleTokens` holds every style constant, generated from the repository's
`style/tokens.json`. `StyleTokens.styleVersion` identifies the token set.

## Design documents

The design decisions behind this guide, with the reasoning for each, are
in the repository's
[SPEC.md](https://github.com/repentsinner/tech_vis/blob/main/SPEC.md).

## License

BSD 3-Clause. See [LICENSE](LICENSE).
