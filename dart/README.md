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

## Measurements

A `DisplayFormat` decides how a real-world length reads. The app picks
one of three: `metric` writes millimeters and switches to meters at
10 m, `decimalInch` writes inches with decimal places at any size, and
`fractionalInch` writes binary fractions down to 1/64 in and switches to
feet and inches at 12 in. Every length a format takes is in the base
unit of its `unitSystem`, millimeters or inches, so convert a world
length with `UnitSystem.convertTo` first.

Each format supplies clean steps for a scale bar and a grid. The steps
run over every power of ten, so the format answers a query rather than
listing them:

```dart
const format = DisplayFormat.metric;

// The longest scale bar that fits in 37 mm of world length.
final bar = format.scaleBarStepAtMost(37); // 20

// The finest grid whose lines sit at least 3 mm apart, and its major step.
final minor = format.gridStepAtLeast(3); // 10
final major = format.gridStepAbove(minor); // 100
```

Each grid step is a whole multiple of the one before it, so every major
line is also a minor line.

`formatLabels` writes a set of values that display together, such as a
grid's coordinates, in one unit. The set's largest value decides whether
the whole set switches unit, so a grid never reads `9000 mm`, `10 m`.
Each label rounds to the step passed in and shows only the decimals that
step needs:

```dart
DisplayFormat.metric.formatLabels([0, 5000, 10000], step: 5000);
// ['0 m', '5 m', '10 m']

DisplayFormat.fractionalInch.formatLabels([40.5]); // ["3' 4 1/2\""]
```

Without a step, labels round to 0.001 mm, 0.0001 in, or 1/64 in. The
app sets the decimal marker and whether a value below one keeps its
leading zero, with `NumberFormatting`:

```dart
DisplayFormat.decimalInch.formatLabels(
  [0.125],
  numbers: const NumberFormatting(
    decimalMarker: DecimalMarker.comma,
    showLeadingZero: false,
  ),
); // [',125 in']
```

## Ground plane

A ground plane gives floating geometry a sense of scale and orientation.
`GroundPlaneFactory.create` draws a grid of minor and major lines on a
patch centered on an origin, in the plane across the declared up axis.
The plane lies along the two axes after the up axis in the cycle X, Y,
Z, which `CoordinateConvention.planeAxes` names: X and Y for Z-up, Z and
X for Y-up. A `RectangularGroundPatch` takes a half extent along each of
those axes, and a `CircularGroundPatch` takes a radius.

The grid adapts to the camera. Its minor step is the finest grid step of
the display format whose lines sit at least
`StyleTokens.groundGridMinLineSpacingPixels` apart at the camera target,
and its major step is the next grid step. Pass the returned minor step
back on the next frame, so a camera resting near a step boundary does not
flicker between two steps:

```dart
GroundGrid? grid;

void onFrame(CameraBasis camera, Vector3 target) {
  grid = GroundPlaneFactory.create(
    convention: convention,
    patch: const RectangularGroundPatch(halfExtentU: 600, halfExtentV: 400),
    format: DisplayFormat.metric,
    worldUnits: UnitSystem.metric, // one world unit is 1 mm
    camera: camera,
    target: target,
    verticalFovRadians: fov,
    viewportHeight: viewport.y,
    resolveText: myTextResolver,
    minorKey: MyStyle.gridMinor,
    majorKey: MyStyle.gridMajor,
    labelKey: MyStyle.gridLabel,
    previousMinorStep: grid?.minorStep,
  );
  scene.replaceGrid(grid!.primitives);
}
```

Each line arrives as a run of `LinePrimitive` segments whose opacity
falls from one at the patch center to zero at its edge, so the grid fades
out without a hard border. The fade is rectangular on a rectangular patch
and radial on a circular one. Each major line carries a viewer-facing
coordinate label where it crosses the perpendicular line through the
origin, and the origin carries one label for zero. The labels form one
set in the display format, so they share a unit. Minor segments come
first, then major segments, then labels, so drawing them in order puts
major lines over minor ones.

The grid never draws more than `StyleTokens.groundGridMaxLinesPerAxis`
lines across the patch in either direction. When the camera closes in on
a large patch, the minor step coarsens to stay within that count.
`GroundGridStyle` overrides any of the grid's tokens.

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

### Navigation cube

A `NavigationCube` shows which side of the scene faces the viewer. Top
is the convention's up axis, and Front faces along the horizontal
world axis the app names. Right is the face a viewer of Front sees on
their right. Naming the axis opposite the convention's fallback axis
puts FRONT along the bottom edge of TOP in a top view:

```dart
final cube = NavigationCube(
  convention: convention,
  front: -SignedAxis(convention.fallbackAxis),
);
final rect = ViewportOverlayPlacement.of(
  ViewportOverlayKind.navigationCube,
).rect(Vector2(1280, 720));

for (final view in cube.visibleFaces(camera, rect)) {
  // Corners run bottom-left, bottom-right, top-right, top-left of the
  // label, in viewport pixels.
  drawFace(view.corners, label: view.face.label);
}
```

`visibleFaces` turns the cube with the camera's rotation and projects it
orthographically about the rectangle's center, sized so that no corner
leaves the rectangle. It returns only the faces turned toward the
viewer, least direct first, so drawing them in order puts the face seen
most squarely on top. The projected faces are parallelograms, so an
affine map draws each label onto its face. The cube is a passive
indicator and doesn't respond to input.

### Scale bar

`ScaleBarLayout.atTarget` describes a scale bar for one frame. It
measures at the camera target, the point the reader looks at, and picks
the longest scale-bar step of the display format that fits the width of
the scale bar's rectangle. The bar then subdivides into the most clean
parts whose ticks stay a style-set distance apart:

```dart
ScaleBarLayout? bar;

void onFrame() {
  bar = ScaleBarLayout.atTarget(
    camera: camera,
    target: orbitTarget,
    verticalFovRadians: fov,
    viewportSize: Vector2(1280, 720),
    worldUnits: UnitSystem.metric,
    format: DisplayFormat.metric,
    previousStep: bar?.step,
  );
  if (bar case final bar?) {
    drawLine(bar.startX, bar.baselineY, bar.endX, bar.baselineY);
    for (final x in bar.tickXs) {
      drawTick(x, bar.baselineY);
    }
    // bar.label is a TextRequest: '100 mm' at a style-set pixel height.
    drawTextTopCenter(bar.label, bar.labelAnchor);
  }
}
```

Every coordinate is in viewport pixels, in the same coordinates as
`worldToScreen`. The bar starts at the rectangle's edge nearer its
corner and stands on the rectangle's bottom edge, and the label's top
center sits on the rectangle's top edge above the bar's midpoint.

Passing the previous frame's step keeps the value steady at a step
boundary. The bar keeps that step while it fits, and moves to a longer
step only once the longer step fits with a style-set margin to spare.
`atTarget` returns null when the target is behind the camera, or when
even the format's shortest step is longer than the bar's rectangle.

## Style tokens

`StyleTokens` holds every style constant, generated from the repository's
`style/tokens.json`. `StyleTokens.styleVersion` identifies the token set.

## Design documents

The design decisions behind this guide, with the reasoning for each, are
in the repository's
[SPEC.md](https://github.com/repentsinner/tech_vis/blob/main/SPEC.md).

## License

BSD 3-Clause. See [LICENSE](LICENSE).
