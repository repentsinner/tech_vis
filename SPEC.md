# tech_vis — Specification

`tech_vis` is a renderer-agnostic toolkit for technical visualization:
annotated 3D scenes with leader-line callouts, coordinate frames, and
labeled bounding boxes. It ships as a Dart package and a Python package
that share one style.

## Repository layout §spec:layout

*Status: complete*

One repository holds the style and every implementation of it.

- `style/tokens.json` is the source of truth for the style.
- `dart/` is the Dart package root. `python/` is the Python package root.
- `tools/` holds repository tooling. It ships in neither package.
- Governance documents sit at the repository root and cover both packages.

Each package directory shall be self-contained: a published archive
cannot read outside its own root. Each therefore carries its own copy of
`LICENSE` and its own `README.md`.

*Why one repository*: the style is the product. Two repositories would
version the token file in one and consume it in the other, and the two
implementations would drift between releases.

## Style tokens §spec:style-tokens

*Status: complete*

The style is data. `style/tokens.json` names every constant that shapes
the look: leader-line geometry, line widths, label sizes, and the callout
opacity ramp.

- Each token has a `doc`, a `unit`, and exactly one of `value` and `alias`.
  An `alias` names another token and takes its value.
- `styleVersion` is an integer. Two implementations that report the same
  `styleVersion` shall produce the same layout from the same input.
- `tools/gen_tokens.py` generates `dart/lib/src/style_tokens.g.dart` and
  `python/src/tech_vis/tokens.py`. The generated modules are committed.
- CI shall fail when a generated module differs from the generator's output.
- Each package's tests compare its generated module against
  `style/tokens.json`. The tests skip where the file is absent, as it is in
  a published archive.

*Why generate, not load*: the Dart constants are `const` and appear as
default values in `const` constructors. A value read from JSON at runtime
cannot be `const`. A published package also cannot reach `style/` from
inside its archive.

*Why commit the output*: a consumer installs a package, not the
repository. The generator never runs on a consumer's machine.

## Golden vectors §spec:golden-vectors

*Status: in progress*

Layout functions are ported by hand between languages. A shared set of
language-neutral fixtures shall pin the ports to each other: each fixture
records a function's inputs and its expected outputs, and each package
tests its implementation against every fixture (§req:success-criteria).

- Fixtures live in `vectors/` at the repository root, outside both
  package roots. Each package's fixture tests skip where the directory
  is absent, as it is in a published archive.
- The Dart implementation is the reference. `dart/tool/gen_vectors.dart`
  runs it over each fixture's inputs and writes the expected outputs.
  The fixtures are committed, and a change to them is reviewed like code.
- The generator is repository tooling, so `dart/.pubignore` keeps it out
  of the published archive.
- Every public layout function in either package has fixtures. A
  function that exists in only one package still has fixtures, so the
  port inherits a finished test suite.
- Numeric outputs compare within an absolute tolerance of 1e-9 in the
  function's own units. Label text compares exactly.
- CI shall fail when a committed fixture differs from the tool's output.

*Why the generator lives in `dart/`*: it imports the package it runs,
and a Dart script resolves a package import only from inside a package
root. A script in `tools/` would need a package of its own.

*Why Dart is the reference*: Dart is the first implementation of every
primitive, and Python ports from it (§req:priorities). An independent
third implementation would catch bugs in Dart too, but it triples the
work for every primitive. Review of the committed fixtures is the check
on the reference.

*Why a tolerance on numbers but not on text*: two languages evaluating
the same double-precision math can differ in the last bits of a
trigonometric result. Label text is formatted from rounded values, so
a mismatch there is a real defect.

*Why compare numbers, not pictures*: matching geometry and text is
testable from data alone, without a GPU (§req:quality-attributes).
Comparing rendered output across engines is deferred.

## Dart package §spec:dart-package

*Status: complete*

Pure Dart. No Flutter dependency, so it runs in any Dart program.
It provides typed annotation primitives (§spec:scene-model), coordinate
frames, bounding boxes, leader-line callout geometry, and screen-space
conversions.

A generic toolkit shall name nothing from a consumer's domain.
`dart/test/generic_vocabulary_test.dart` enforces this: it fails when a
source file under `dart/lib/` matches the vocabulary of the application
the package was extracted from.

Vectors and matrices in the public API are 64-bit, from
`package:vector_math/vector_math_64.dart`. Mesh vertex buffers stay
32-bit, because that is the precision a GPU consumes.

*Why 64-bit*: Python floats are 64-bit. A 32-bit Dart result near 100
world units differs from the same Python computation by about 1e-5, so
the two packages could not agree within the tolerance of
§spec:golden-vectors. Flutter's own transforms use the 64-bit types
too, which spares a Flutter-based renderer a conversion per transform.

## Primitive output §spec:scene-model

*Status: complete*

The package emits annotations as a closed set of typed primitives and
never renders them. Each app maps the primitives into its own scene
graph and draws them with its own engine (§req:constraints).

| Primitive | Carries |
|---|---|
| Line | Two world endpoints and a width in screen pixels |
| Quad | Four world corners of a filled face |
| Billboard | 2D content that the app prepares, the content's size in screen pixels, a world anchor, an orientation mode, an anchor alignment, and an optional screen offset |
| Marker | A world position, a diameter in screen pixels, and its generated mesh |
| Mesh | Triangle positions, normals, and indices, in the declared convention of §spec:coordinate-convention |

- Every primitive carries an opacity, which the package computes, and an
  app key. The key is an opaque value that the package passes through
  and never inspects. The app resolves color and any other meaning from
  it.
- A Billboard's content is opaque to the package: text, an icon, a
  video frame, or anything else the app can draw, alpha included. The
  package places the content by its pixel size and never inspects it.
- Text that the package composes for its own annotations, such as a
  dimension value, a grid coordinate, or an axis letter, reaches the app
  as a text request: the string and a pixel height. The app turns the
  request into content in its own typeface and reports the content's
  pixel size, and layout places the Billboard by that size.
- Factories return primitives: `BoundingBoxFactory`,
  `CoordinateFrameFactory`, `EnvelopeLabelFactory`,
  `FilledRectangleFactory`, `MarkerFactory`, §spec:callout-layout, and
  §spec:annotation-primitives. A factory emits every line it draws, so a
  renderer draws lines and never derives one. `BoundingBoxFactory`
  emits a box's twelve edges once each, plus six faces only when the box
  has a fill. `FilledRectangleFactory.createOutline` emits a lone
  rectangle's perimeter, and `createCalloutLeaderLines` a callout
  leader's two segments.
- The closed set covers world-space output. A viewport overlay is a
  second, pixel-space output beside it, placed by
  §spec:viewport-overlays, and is not a primitive.
- The package defines no scene container, no renderer interface, and no
  type for scene content such as a loaded model.
- A primitive or factory belongs in the package when a visualizer in an
  unrelated domain would need it. One that makes sense in only one
  domain belongs in that domain's app.

*Why typed primitives*: a single object type with every field optional
admits any combination of fields, and leaves each renderer to guess
which ones apply. A closed set states each primitive's meaning once,
and a renderer handles exactly five cases. A slimmed single type was
rejected because it still mixes kinds in one type. A shared type that
apps subclass was rejected because it puts the package's scene graph
inside every app.

*Why a billboard, not a text label*: the placement math needs only the
content's pixel size and anchor. Text is one kind of content, and an
icon or a video frame places the same way. A text-only primitive would
force each other kind of content through a second path. Composed text
goes through the same billboard, so one mechanism places everything.

*Why no renderer interface*: a renderer interface carries engine and app
concerns, such as building a widget, a frame callback, or an app's
camera targeting. The package's boundary is the data it emits.

*Why no scene content*: a model of the object being annotated is the
app's content, and drawing it needs an asset loader that annotations do
not (§req:constraints).

*Why an opaque key*: what a line means, and therefore its color, belongs
to the app's domain. The key lets the app carry that meaning through the
package without the package naming it.

*Why boxes emit their own edges*: a box outlined from its six face
perimeters draws every edge twice, once for each face that shares it.
The doubled line darkens a translucent edge and z-fights with itself.

## Color §spec:scene-color

*Status: complete*

The package performs no color conversion and holds no palette. The app
resolves each primitive's color from its key, in whatever color space
its renderer needs. The package's only color output is opacity, a value
from 0 to 1 that fades and the callout opacity ramp produce.

Where a feature would blend two colors, such as a gradient in
§spec:color-ramp-legend, the app supplies the blend.

*Why no conversion*: every color comes from the app's theme, and the
space a renderer wants, sRGB for a texture or linear for a shader
input, is the engine's choice. A conversion in the package would encode
one engine's needs. A package color type with a linear conversion was
rejected for that reason.

## Screen-space placement §spec:screen-space-placement

*Status: complete*

A label, callout, or leader that sits at a world-space point but draws
at a fixed pixel size needs the world size of one pixel at that point.
The package computes it, along with the transforms that turn a quad to
face the viewer, so every renderer places these elements the same way.

- `CameraBasis` holds a camera's position and its forward, right, and up
  axes. When the view direction nearly parallels the up axis of
  §spec:coordinate-convention, it builds the axes from a fallback axis
  that the convention gives.
- `worldUnitsPerPixelAt` sizes by the point's depth along the view axis.
  A screen-space element therefore keeps its pixel size anywhere in the
  view. It returns null for a point on or behind the camera plane.
- `worldToScreen` projects a world point through the same perspective
  camera to pixel coordinates, with the origin at the viewport's top-left
  corner and y running down. It returns null where
  `worldUnitsPerPixelAt` does. The reference fixtures of
  §spec:renderer-contract are in these coordinates.
- Billboard helpers return a viewer-facing rotation and model transform,
  a pixel offset along a screen-projected direction, and the corners of a
  callout's label quad.
- `lineSegmentTransform` maps one canonical unit segment onto any world
  segment, so a renderer reuses one line mesh.
- `drawRanksByDistance` orders callouts so nearer ones draw over farther
  ones, with ties broken by id. The renderer supplies its own rank range.

*Why depth, not distance*: perspective divides by depth along the view
axis. Straight-line distance exceeds depth by 1/cos of the angle off the
axis, so sizing by it grows an element toward the edges of the view, by
26% at the edge of a 46° view and more beyond it. A callout whose anchor
moves off screen while its label stays visible shows the error most.
Straight-line distance still suits distance-based effects such as the
callout opacity ramp and draw order.

*Why the package owns this*: the size of a pixel at a point is the same
math in every engine. Left to each renderer, it is the kind of constant
and formula that drifts between copies (§req:problem-statement).

## Coordinate convention §spec:coordinate-convention

*Status: in progress*

The app declares the convention of the space it hands the package:
which world axis points up, and whether the axes are right- or
left-handed. Every input and output of the package is in that space.
The convention has no default, and the package exports no converter
between conventions.

The declared convention decides:

- the fallback up axis of `CameraBasis.lookAt` when the view looks
  straight along the up axis;
- the plane a ground plane lies in;
- which navigation cube face is Top;
- the top face of a box that an envelope label sits on, and the
  direction its text runs;
- mesh triangle winding, so that faces point outward in either
  handedness.

The fallback axis is the axis before the up axis in the cycle X, Y, Z,
so a Z-up top view keeps +Y up on screen. Screen axes, face normals,
and label text directions take their cross products by the declared hand
rule. A label's text runs along the fallback axis crossed with the up
axis, so it reads left to right in a top view.

*Why declare, not convert*: without a declaration the package either
assumes one convention, or ships a converter that every app calls on
every point. Declaring once lets each orientation decision use the
app's own space, and the app never converts its data for the package
(§req:constraints). A converter helper was rejected for that reason.

*Why no default*: a wrong default fails silently. A Y-up scene treated
as Z-up draws its ground plane as a wall.

## Renderer contract §spec:renderer-contract

*Status: complete*

A renderer reproduces the style when it honors what each primitive
means. The package guarantees placement: where a primitive lands on
screen and how big it is. Pixel fidelity, such as anti-aliasing, glyph
rasterization, and blending quality, is the renderer's
(§req:constraints).

A renderer shall:

- draw with a perspective camera whose position, target, vertical field
  of view, and viewport size match those it passed to the package for
  the same frame;
- draw a Line at its width in screen pixels, constant along its length
  at any depth;
- draw a Billboard's content at its pixel size and anchor alignment,
  facing the viewer in a viewer-facing mode, with the content's own
  alpha multiplied by the primitive's opacity;
- draw a Marker's mesh at the transform the package returns for the
  frame;
- apply each primitive's opacity;
- draw a primitive that carries a draw rank over scene geometry
  regardless of depth, and a higher rank over a lower one;
- update per-frame transforms in every frame in which the camera or an
  anchor moves;
- draw each viewport overlay inside the pixel rectangle its placement
  gives, in a 2D layer above the scene (§spec:viewport-overlays);
- take every annotation's geometry from its primitives, with no asset
  file (§req:constraints).

A renderer should anti-alias a line narrower than one pixel.

The app prepares each Billboard's content, including the content for
the package's text requests, and reports its pixel size. The package
never measures or rasterizes content.

The renderer guide in `dart/README.md` states this contract for renderer
authors, and the root README points to it.

*Why placement, not pixels*: the package controls where an element lands
and how big it is, and nothing about how an engine fills its pixels. A
contract on pixels would bind every engine to one rasterizer
(§req:problem-statement).

### Reference screen geometry

Fixtures of §spec:golden-vectors cover a set of sample scenes. For each
camera and viewport, a fixture records every primitive's expected screen
position and pixel size: billboard boxes, line endpoints and widths, and
marker diameters. A renderer author renders the sample scene, measures
the frame, and compares the measurements with the fixture within a
tolerance that the renderer records. A renderer's recorded tolerance
only tightens (§req:quality-attributes).

- `vectors/reference_screen_geometry.json` holds the sample scenes, in
  the screen coordinates of `worldToScreen`
  (§spec:screen-space-placement).
- A Billboard's anchor, alignment, and text request hold for any
  typeface. Its recorded box follows from the generator's stand-in
  typeface, so a renderer places the box from its own measured size.
- The sample scenes cover Y-up and Z-up conventions, both handednesses,
  off-axis cameras, and a view along the up axis.

*Why record the stand-in size*: a box depends on the typeface, so no
fixed box holds for a real one. The anchor and alignment fix where any
content sits, and the recorded size shows the box arithmetic.

*Why numbers, not reference images*: an image fixes one typeface, one
rasterizer, and one anti-aliasing filter, so no second engine could
match it. Screen positions and sizes hold for any engine and any
typeface.

*Why the renderer owns its images and tolerance*: fidelity varies by
engine. The package states where things land; each renderer proves how
closely it draws them, and ratchets that proof.

### Markers

A marker is a sphere with a diameter in screen pixels, centered on a
world point. The package generates the sphere's mesh and, each frame,
its transform, so the marker keeps its pixel diameter at any distance.

*Why pixel size*: every other annotation keeps a pixel size. A marker
sized in world units vanishes when the camera pulls back.

*Why generated geometry*: a model file makes every renderer load an
asset format to draw a dot (§req:constraints).

The mesh is an icosphere whose subdivision level is a style token.

*Why an icosphere*: its triangles are close to equal in size and shape,
so a low subdivision level reads as round at marker sizes. A UV sphere
crowds thin triangles at its poles and spends its vertices there.

## Unit system §spec:unit-system

*Status: complete*

`UnitSystem` names the metric (mm) and imperial (in) systems and
converts between them. A `DisplayFormat` decides how a measurement
displays, and the app selects it. Every length a format takes or
returns is in its unit system's base unit.

- **Metric**: millimeters, promoted to meters at 10 m and above.
- **Decimal inch**: inches with decimal places. No promotion to feet.
- **Fractional inch**: inches with binary fractions down to 1/64,
  promoted to feet and inches at 12 in and above (`3' 4 1/2"`).

Each format supplies two ascending sequences of clean steps. The scale
bar snaps to the fine sequence. The grid snaps to the coarse sequence,
where each step is a whole multiple of the one before it, so a major
line is always also a minor line.

| Format | Scale bar steps | Grid steps |
|---|---|---|
| Metric | 1, 2, 5 × every power of ten | every power of ten |
| Decimal inch | 1, 2, 5 × every power of ten | every power of ten |
| Fractional inch | 1/64, 1/32, 1/16, 1/8, 1/4, 1/2, 1, 6, 12 in; then 1, 2, 5 × every power of ten ft | 1/16, 1/4, 1, 12 in; then every power of ten ft |

A format answers step queries instead of listing its sequences: the
largest scale bar step that fits a length, the smallest grid step that
covers one, and the grid step above a given step. These are what
§spec:scale-bar and §spec:ground-plane consume.

- A set of labels displayed together, such as a grid's or a scale
  bar's, uses one unit for every label in the set. The largest rounded
  magnitude in the set decides whether the set promotes.
- A label rounds to its step and shows the fewest decimal places, or the
  smallest binary fraction, that represent the step exactly, with no
  trailing zeros. A label with no step, such as a single measured
  value, rounds to 0.001 mm, 0.0001 in, or 1/64 in.
- A fractional-inch set whose step is a whole number of feet omits the
  inches (`2'`).
- The app sets the decimal marker (point or comma) and whether a value
  below one shows its leading zero. The defaults are a point and a
  leading zero shown. Fractional inch has no decimals, so neither
  applies to it.

*Why query steps, not list them*: the sequences run over every power
of ten. A finite list would cut off a scene larger or finer than its
ends.

*Why a default rounding*: a dimension measures one value and has no
step. Each default is finer than its format's readers work to, so it
hides floating-point noise without hiding a real digit.

*Why three formats, not two systems*: imperial readers split. Machinists
read thousandths of an inch, and router and woodworking users read
fractions and feet (§req:user-stories). The conversion factor is the
same; the display is not.

*Why promote metric only at 10 m*: millimeters are the working unit on
a machine up to room scale. Promotion exists so that no label carries a
five-digit millimeter value (§req:user-stories).

*Why one unit per label set*: a grid labeled `900`, `1 m`, `1100` reads
as three different quantities.

## Callout layout §spec:callout-layout

*Status: not started*

A leader-line callout sits at a world-space anchor and draws in screen
space. When several crowd one area, their labels cover each other, and
an operator cannot tell which matters (§req:success-criteria). Callout
layout decides, every frame, where each callout's label goes, whether
it shows, and how opaque it is.

Layout is a pure function. Each frame the app passes in:

- each callout's stable id, anchor, measured label size in pixels,
  priority, and preferred quadrant;
- the camera, the viewport size, the camera focus point, and the pointer
  position when there is one;
- the time elapsed since the previous frame;
- the layout the function returned for the previous frame.

It returns, per callout, the quadrant, the label position, and the
opacity. A callout with zero opacity is hidden.

### Relevance

Each callout has a relevance score. The score is a weighted sum of the
app's priority and three nearness terms (§req:user-stories):

- nearness on screen to the camera focus point;
- nearness in depth to the viewer;
- nearness on screen to the pointer, when the app passes one.

The weights are style tokens, and the app may override them.

*Why a blend, not priority tiers*: a strict tier lets a far-off callout
of higher priority hide one the operator is looking straight at. A blend
lets attention outweigh a small priority difference.

*Tradeoff accepted*: no callout is guaranteed to survive crowding. An
app that needs a callout to win against any nearby one gives it a
priority large enough to outweigh every nearness term.

### Placement

- Callouts place in descending relevance. Equal scores break by id, so
  placement is the same in every language.
- Each callout tries its quadrant from the previous frame first, then
  its preferred quadrant, then the rest in a fixed order. It takes the
  first whose label box overlaps no label already placed.
- A callout that fits in no quadrant fades out. A less relevant callout
  therefore never covers a more relevant one's text.
- Layout runs every frame, including while the camera moves. A placed
  callout keeps its quadrant until that quadrant is blocked. A hidden
  callout returns only when its relevance exceeds the callout blocking it
  by a token-set margin, so two callouts of near-equal relevance do not
  trade places every frame (§req:quality-attributes).
- Grouping crowded callouts into one marker or list is outside this
  section until §req:open-questions settles what a group shows.

*Why greedy by relevance*: it places the most relevant callout first,
which is what guarantees no lesser callout covers it. Optimizing methods
such as force fields or simulated annealing iterate floating-point
math, so their results drift between Dart and Python, and the golden
vectors of §spec:golden-vectors would not hold. About 20 callouts on
screen, each trying four quadrants, is a small per-frame cost
(§req:quality-attributes).

*Why the previous quadrant first*: a callout that holds its position
until forced to move reads as calm. Temporal stability matters more to
the operator than the best position in any one frame
(§req:quality-attributes).

*Why continuous, not frozen during camera motion*: freezing lets labels
overlap for the length of an orbit. Re-placing every frame with a dead
band keeps text clear while the previous-quadrant rule keeps it calm.

*Why the app measures labels*: text size depends on the renderer's font
and metrics. The package never measures text.

### Motion and fades

- When the camera is still and an anchor moves, the label lags behind
  its anchor with a time constant held as a style token. The leader's
  anchor end stays exactly on the anchor, so the leader stretches and
  the callout stays attached (§req:success-criteria).
- While the camera moves, labels follow their anchors without lag.
- A callout that appears, whether added by the app or uncovered, fades
  in. One that disappears, whether removed by the app or crowded out,
  fades out. The fade duration is a style token.
- A callout's opacity is its fade level times the distance opacity of
  the callout opacity ramp.
- The camera counts as moving when its pose differs from the previous
  frame's.

*Why lag only the label*: the anchor is the fact. A lagging anchor end
would point at where the object was. A lagging label end keeps the text
still enough to read while the leader still points at the object.

*Why no lag while the camera moves*: when the camera moves, every label
moves on screen. A lag there makes the whole layout swim behind the
scene.

*Why the package computes fades and lag*: two engines animating the
same transition differently would break the one-look promise. The app
owns the clock and passes elapsed time, so each frame's result is still
a function of its inputs and is testable from data
(§req:constraints).

### Verification

Callout layout fixtures in §spec:golden-vectors are sequences of
frames, not single frames, because stability, hysteresis, lag, and fades
show only across frames. Each frame's expected output is the input to
the next.

## Annotation primitives §spec:annotation-primitives

*Status: complete*

The package provides annotation primitives for engineering 3D scenes.
Each primitive produces data, pure geometry and labels, without
rendering it. Consumers map annotations to their renderer's scene graph
and handle all input and animation (§req:constraints).

Every primitive that displays a real-world measurement formats its
labels and subdivides through §spec:unit-system, and follows the
drafting convention of §spec:drafting-convention.

Dart provides each primitive first. Python provides the same primitive
later, and the two agree on every fixture of §spec:golden-vectors
(§req:priorities). A primitive's Python port does not block its Dart
release.

### Drafting convention §spec:drafting-convention

The app selects one drafting convention for a scene
(§req:success-criteria). A convention is a standard, ISO 129 or
ASME Y14.5, and a style within it. The convention decides where a
dimension's text sits and which way it reads:

| Convention | Text orientation on screen | Text placement |
|---|---|---|
| ISO oriented | Parallel to the dimension line, turned to stay upright | Above the dimension line, offset by a token-set gap |
| ISO referencing | Horizontal | On a reference line led off the dimension line |
| ASME inlined | Horizontal | In a break in the dimension line |
| ASME referencing | Horizontal | On a reference line led off the dimension line |

- A referencing style places its text on the side where the leader does
  not cover it, preferring the outer side of the dimension line.
- When a dimension's text does not fit between its witness lines on
  screen, an oriented or inlined dimension falls back to its standard's
  referencing style.
- The gap between a measured point and the start of its witness line is
  a style token per standard.
- The convention is independent of the display format and number
  formatting of §spec:unit-system. A metric scene may follow ASME, and a
  decimal-inch scene may follow ISO.
- Text fits when its extent along the dimension line on screen, plus an
  arrowhead length and a text gap at each end, is no longer than the
  on-screen distance between the witness lines. Oriented text's extent is
  its width. Horizontal text's extent is its box projected onto the
  line's screen direction. A line seen end-on never fits.
- Oriented text reads left to right, or bottom to top on a line that is
  vertical on screen. It lies in the screen plane, lifted off the line
  by the text gap along its own vertical axis.
- Inlined text sits centered on the dimension line's midpoint. The break
  spans the text's extent plus a text gap at each side.
- On an angular dimension's arc, the text sits at the arc's midpoint and
  measures against the arc's tangent there. The fit compares it with the
  arc's length on screen, and the arc's outer side is the angle's
  bisector. A radial dimension line's outer side is the perpendicular
  that faces the viewer, turned toward screen up.
- A referencing leader leaves the dimension line's midpoint as a callout
  leader (§spec:callout-layout). Its quadrant is the one whose angled
  segment points to the outer side, the side the dimension line was
  offset toward, at the widest angle from the line on screen. When no
  quadrant points to the outer side, all four compete. Ties go to the
  earlier of top-right, top-left, bottom-right, bottom-left.

These four conventions follow FreeCAD TechDraw's "Standard and style"
setting, which drafting users already know.

*Why the app chooses*: the first applications serve audiences on both
sides of the split, and one app's readers may follow either standard
(§req:user-stories). Tying the convention to the unit system would
force every metric reader onto ISO.

*Why a style within the standard*: each standard permits more than one
text placement, and the choice changes the geometry. Inlined text
breaks the dimension line, oriented text sits above it, and referencing
text adds a leader.

*Why fall back to referencing*: a 3D dimension shrinks on screen as the
camera pulls back, so text that fits at one zoom overlaps its arrows at
another. A referencing leader keeps the value readable at any zoom
without changing the standard the reader expects.

*Why number formatting is not part of the convention*: the decimal
marker and leading-zero rule vary by locale and shop more than by
standard, and drafting tools set them separately.

*Why count the arrowheads and gaps in the fit*: text that only just
clears the witness lines still collides with the arrowheads. Counting
them keeps the fallback rule one inequality, with no per-standard
clearance.

*Why bottom to top on a vertical line*: aligned dimensioning reads a
vertical dimension from the drawing's right side, which turns the text a
quarter turn counterclockwise.

*Why the widest angle*: a leader that leaves along the dimension line
hides it. The widest angle from the line is the simplest rule that
keeps the two apart, and it needs no knowledge of other annotations.

### Viewport overlays §spec:viewport-overlays

The scale bar, the color ramp legend, and the navigation cube are
overlays. An overlay is described in viewport pixels, not world
coordinates, and the app draws it in a 2D layer above the scene.

- An overlay anchors to one viewport corner, with an offset from that
  corner in pixels. The offset points toward the viewport center, so one
  offset keeps an overlay equally far from its two edges in any corner.
- A placement is a corner, an offset, and a size. It resolves to a pixel
  rectangle for a viewport size, in the screen coordinates of
  `worldToScreen` (§spec:screen-space-placement). The rectangle is not
  clipped to the viewport.
- Each overlay kind has a default corner, offset, and size, held as style
  tokens. The app may override each one, and an override changes only
  that value (§req:success-criteria). A corner token holds a numeric
  code, because every token is a number.
- The default corners are distinct, so the three overlays share no
  corner by default. The navigation cube sits top-right, where CAD tools
  place a view cube. The scale bar sits bottom-left, and the color ramp
  legend bottom-right. Top-left stays free for the app.
- An overlay's content, such as a scale bar's ticks or a legend's
  labels, is described in pixels inside its rectangle. It is a separate
  output from the primitives of §spec:scene-model, which stay
  world-space.
- Given the same camera, viewport size, and settings, an overlay's
  description is identical in both packages.
  `vectors/viewport_overlays.json` pins each kind's defaults and the
  rectangles placements resolve to (§spec:golden-vectors).

*Why pixels, not world geometry*: an overlay's job is to hold still
while the scene moves. Placing it as world geometry near the camera
ties it to the projection, so it shifts with field of view and clips
against scene depth. A pixel description is also checkable as data,
with no camera math in the test.

*Tradeoff accepted*: the package has two kinds of output, a world-space
scene and a pixel-space overlay. A renderer handles both.

*Why not primitives with pixel coordinates*: every primitive's points are
world points, and a renderer projects them. A Line or Billboard that held
pixels in one use and world points in another would make each renderer
check which it had, which is the ambiguity the closed set exists to
remove (§spec:scene-model).

*Why the offset points inward*: an offset measured along the viewport's
axes would have to change sign with the corner. Measuring toward the
center lets one default offset serve every corner, so overriding only
the corner keeps the margin.

### Ground plane §spec:ground-plane

A reference surface anchored to the origin of a coordinate frame. The
ground plane provides spatial context. Without it, floating geometry has
no perceptible scale or orientation (§req:user-stories).
`GroundPlaneFactory` emits it as Lines and Billboards.

- The ground plane is a rectangular or circular patch, sized by the app
  and centered on the origin, in the plane through the origin across the
  up axis of §spec:coordinate-convention. The plane lies along the two
  axes after the up axis in the cycle X, Y, Z, each pointing the positive
  way, so a coordinate label reads the world coordinate in either
  handedness. A rectangle takes a half extent along each.
- The app states which base unit of §spec:unit-system one world unit is.
  The grid converts its spacing into the display format's base unit, and
  reports its steps in that unit.
- It displays a grid with minor and major lines. The minor step is the
  smallest grid step of §spec:unit-system that keeps minor lines at
  least a token-set number of pixels apart at the camera target. The
  major step is the next grid step.
- At most a token-set number of lines crosses the patch in each
  direction. Where the pixel rule gives more, the minor step coarsens to
  the smallest grid step that fits.
- Line opacity falls linearly with distance from the patch center,
  reaching zero at the patch edge. The fade is radial for a circular
  patch and rectangular, by the larger fraction of either half extent,
  for a rectangular one. Each line splits into a token-set number of
  equal segments, each with the opacity at its midpoint, and a segment at
  zero opacity is left out.
- Each major line carries one coordinate label where it crosses the
  perpendicular line through the origin, and the origin carries one
  label for zero. The labels form one label set of §spec:unit-system in
  the active display format. They face the viewer, with their content's
  bottom-left corner on the crossing (§req:quality-attributes), and fade
  like the lines at their anchors. A label at zero opacity is left out
  of the set, so an invisible edge label cannot promote the others.
- When the camera rests near a step boundary, the grid does not flicker.
  The step changes only once the spacing passes the boundary by a
  token-set margin, and changes back only once it passes back by the
  same margin. The app passes the previous frame's minor step back in,
  so the grid stays a pure function of its inputs.
- Minor line segments come first, then major ones, then labels. Minor and
  major lines take token-set widths, and the app keys each kind.
- `vectors/ground_plane.json` pins the minor-step choice and whole grids
  under Y-up and Z-up conventions in both handednesses
  (§spec:golden-vectors).

*Why an adaptive grid*: a fixed grid spacing is too coarse when zoomed
in and an illegible mesh when zoomed out. Snapping to the unit system's
grid steps keeps grid density perceptually constant across zoom levels
(§req:success-criteria).

*Why fade at the edges*: a hard-clipped ground plane creates a visual
boundary that implies a physical constraint. Fade-to-transparent
communicates a reference surface without implying a wall.

*Why segments*: a primitive carries one opacity, so a single Line cannot
fade along its length. A per-vertex opacity was rejected because it adds
a field to the closed set of §spec:scene-model for one annotation. A
fixed segment count bounds the output per line at any zoom.

*Why cap the line count*: the patch is a world size and the minor step
follows the camera, so closing in on a large patch would otherwise emit
lines without bound. Coarsening keeps every line at least the minimum
spacing apart, so the cap thins the grid instead of crowding it.

*Why the caller holds the previous step*: hysteresis needs one value of
state. Holding it in the app keeps the factory stateless, so a fixture
reproduces any frame from its inputs alone.

*Why billboard the labels*: a label lying flat on the plane becomes
unreadable as the view approaches edge-on, which is the view a reader
uses to judge height above the floor.

*Why label at the origin's lines*: those crossings name each major line
once, at the coordinate it marks. Labeling every crossing repeats each
value across the patch.

### Scale bar §spec:scale-bar

A viewport overlay (§spec:viewport-overlays) showing real-world
distance at the current zoom (§req:user-stories).
`ScaleBarLayout.atTarget` describes it for one frame.

- The bar's value is the largest scale bar step of §spec:unit-system
  whose length at the camera target fits within the width of the scale
  bar's placement rectangle. The placement's width token is therefore the
  maximum pixel length. The app states its world unit system, and the
  world size of a pixel converts to the display format's base unit.
- The bar starts at the rectangle's edge nearer its corner, so it grows
  toward the viewport center, and stands on the rectangle's bottom edge.
- The bar subdivides into the most equal parts that keep adjacent ticks
  at least a token-set number of pixels apart, where each part is itself
  a scale bar step. A bar too short for any part keeps only its two end
  ticks.
- The bar carries one label, a text request for its value at a
  token-set pixel height, in the active display format and the app's
  number formatting. The label's top center sits on the rectangle's top
  edge, above the bar's midpoint.
- The bar's value does not flicker at a step boundary. The app passes
  the previous frame's step. The bar keeps it while it fits, and adopts
  a longer step only once that step fits within the maximum length less
  a token-set fraction of it.
- The layout is null when the camera target is on or behind the camera
  plane, or when even the format's smallest step is longer than the
  maximum length.
- `vectors/scale_bar.json` pins layouts across every display format,
  both world unit systems, a right corner, the null cases, and each side
  of the margin (§spec:golden-vectors).

*Why screen-space*: a world-space ruler changes apparent size with
camera distance, which defeats its purpose. A fixed screen-space element
with an adaptive label communicates scale at any zoom.

*Why measure at the camera target*: under perspective, scale varies
across the view. The camera target is the point the reader is looking
at, so its scale is the one they want.

*Why the placement width is the maximum*: the bar's rectangle already
holds the space the app gives the overlay. A second length token could
disagree with it and push the bar out of its own rectangle.

*Why the margin applies only to a longer step*: a step that no longer
fits drops at once, so the bar never leaves its rectangle. The margin
sits on the way up, between a step that fits and the next one, which is
where a slow zoom would otherwise flip the value back and forth. A
symmetric band around each boundary was rejected because it lets the
bar overrun its rectangle by the margin.

*Why the app carries the previous step*: the package holds no state
between frames, so the hysteresis input is the step the last layout
returned.

*Why parts are scale bar steps*: a tick at 2.5 mm reads as noise. Parts
that are themselves clean steps put every tick on a value a reader can
name.

### Smart dimensions §spec:smart-dimensions

Point-to-point dimension annotations with witness lines, arrowheads, and
text that keeps a constant screen size at any zoom (§req:user-stories).
The app supplies the measured points; the package decides how the
dimension reads.

- **Linear.** When two points differ along one world axis only, within
  an alignment tolerance, the dimension measures that axis. Its witness
  lines are perpendicular to that axis. The tolerance is the largest
  offset along any other axis, as a fraction of the distance between
  the points. It defaults to a style token, and the app may override it.
- **Several axes.** When the points differ along more than one axis,
  the app chooses between per-axis component dimensions, in X, Y, Z
  order, and the direct distance. A direct dimension is aligned: its
  dimension line runs parallel to the segment between the points.
- **Angular.** The angle between two vectors from a common vertex, drawn
  as an arc. Each vector runs from the vertex to the far end of its leg.
  The arc lies in the legs' plane, a token-set number of pixels from the
  vertex, and spans the angle under 180°. Parallel or opposed legs emit
  nothing.
- **Radial.** The radius or diameter of a circle or arc, given its
  center, radius, and plane. The app chooses radius or diameter. A
  radius line runs from the center to the rim, with one arrowhead on the
  rim; a diameter line runs rim to rim through the center, with an
  arrowhead on each rim. The line lies in the circle's plane, along a
  direction the app may give. By default it runs toward the screen's
  top-right corner, or toward screen right when that corner lies along
  the plane's normal.
- Witness line gap and extension, arrowhead size, and text size are
  style tokens, all in pixels. The witness line gap has one token per
  standard.
- Text orientation and placement follow §spec:drafting-convention. A
  referencing dimension's leader uses the same geometry and style tokens
  as a leader-line callout.
- Number formatting follows §spec:unit-system. The app names the unit
  system of its world coordinates, and the label is the measured length
  written by the display format with no step. The component dimensions of one
  pair of points form one label set, so they share a unit.
- A radial label prefixes the length with `R` for a radius and `⌀` for a
  diameter, with no space: `R12 mm`, `⌀24 mm`.
- An angular label is the angle in decimal degrees: `37.5°`. It rounds to
  a token-set step, 0.1° by default, and shows the fewest decimals that
  write the step, with the app's number formatting of
  §spec:unit-system. The label is the same under every display format.
- An angular arc draws as Lines. Its segment count is the arc's length
  in pixels at the vertex's depth, divided by a token-set segment length
  and rounded up. An inlined break splits the arc into two runs, each
  counted the same way.
- A leg that ends short of the arc gets a witness line along it, from
  the witness gap past the leg's end to the extension past the arc. A leg
  that reaches the arc needs none.
- The dimension line sits a token-set number of pixels from the
  measured points, along a direction perpendicular to the measured one.
  The app may give the direction. By default it is the perpendicular
  that lies in the screen plane, turned toward screen up, or toward
  screen right when it lies level.
- Both witness lines are perpendicular to the measured direction. The
  second point's witness line takes up any offset between the points
  across the measured direction, so the dimension line stays parallel
  to it.
- Arrowheads are open: two lines from the tip, inside the witness lines,
  with a token-set length and width. They stay inside when text falls
  back to referencing.
- Each pixel size converts to world units at the depth where it is
  drawn: the witness gap at its measured point, the extension and
  arrowheads at the dimension line's ends, the offset at the midpoint of
  the measured points, and the break and leader at the dimension line's
  midpoint. An arc's radius converts at its vertex, and an angular
  witness gap at the leg's end.
- A dimension with any of those points, or any point of an arc, on or
  behind the camera plane emits nothing, and so do coincident points, a
  zero leg, and a radius that is not positive.
- `vectors/smart_dimensions.json` pins the emitted primitives of the
  linear, angular, and radial dimensions in world space, and
  `vectors/unit_formats.json` pins the degree labels
  (§spec:golden-vectors).

*Why detect axis alignment*: a reader of a technical drawing thinks in
per-axis distances, such as X travel or Z depth. Showing the single
varying axis matches that reading. Direct distance with components
handles the general case.

*Why a relative tolerance*: world units differ between apps, so an
absolute tolerance would mean a micron in one scene and a meter in
another. A fraction of the measured distance holds at any scale.

*Why default to the viewer-facing perpendicular*: a dimension in 3D has
no drawing plane, and a perpendicular along the view axis collapses the
witness lines to points on screen. The perpendicular in the screen plane
always shows them at full length.

*Why open arrowheads*: an open arrowhead is two Lines, so it needs no new
primitive and keeps its pixel size by the Line contract. A filled
triangle would need a Quad with a repeated corner or a per-frame Mesh,
and neither is a clean fit for a pixel-sized shape (§spec:scene-model).

*Why the arrowheads stay inside*: the fallback moves the text, which is
what collides. Flipping the arrowheads outside as well would add a
second layout case for little gain in readability.

*Why the app supplies the points*: what is worth measuring depends on
the app's domain. A generic toolkit that guessed would name concepts
from one consumer (§spec:dart-package).

*Why a pixel radius for the arc*: every other offset of a dimension is in
pixels, so the arc keeps its size on screen and its text stays as likely
to fit at any zoom. A radius taken from the legs would shrink the arc
with the scene and send every distant angle to the referencing fallback.

*Why decimal degrees*: decimal degrees read the same in every display
format and take the app's decimal marker, with no unit system to
choose. Degrees, minutes, and seconds were rejected because they need a
second rounding rule and a second label layout. A step token sets the
precision, as the display formats' default rounding does for lengths.

*Why count segments at the vertex's depth*: the count then depends on the
style and the angle alone, so it is stable from frame to frame. The
unforeshortened length is the longest the arc can appear, so no segment
exceeds the token-set length on screen. Counting from the projected arc
would change the line count as the camera moves.

*Why the top-right corner for a radial line*: a diagonal line keeps clear
of the horizontal and vertical edges that dominate engineering views, and
it points the text away from the circle's center. It is the simplest rule
that needs nothing but the camera.

*Why `R` and `⌀`*: ISO 129 and ASME Y14.5 both write a radius after `R`
and a diameter after `⌀`, so the prefix needs no per-standard rule.

*Why reuse the fit and fallback*: the same inequality and the same
referencing leader keep every dimension shape under one drafting
convention. An arc's fit compares the text with the arc's length on
screen, and a radial dimension counts an arrowhead at each end, as a
linear one does, even when a radius has one arrowhead.

### Color ramp legend §spec:color-ramp-legend

A viewport overlay (§spec:viewport-overlays) that keys a color-coded
value, such as speed, temperature, stress, or altitude, to its colors.
The app provides the scalar-to-color mapping and the value range, in its
own value unit. The legend handles layout, ticks, and labels.
`ColorRampLegendLayout.forRange` describes it.

Orientation (horizontal or vertical), tick intervals, and unit-labeled
endpoints are configurable. The orientation defaults to vertical, which
the default placement's tall rectangle suits.

- The gradient reaches the renderer as ordered color stops: each stop
  has a position from 0 to 1 along the bar and the app's key. The app
  resolves each key to a color and interpolates between neighboring
  stops, in the color space its renderer needs. The stops run from 0 to
  1 without descending, so two stops at one position make a hard edge.
- The legend describes the bar's rectangle in viewport pixels, its
  stops, and its ticks, each tick with a position along the bar and a
  label request. Position 0 is the range's minimum, at the bar's bottom
  when vertical and its left when horizontal.
- The bar spans the placement rectangle's full length and a token-set
  thickness, on the rectangle's edge nearer its corner. Labels sit a
  token-set gap off the bar's other side, toward the viewport center,
  centered on their ticks, with one anchor alignment for the set.
- A tick marks every whole multiple of the tick interval inside the
  range, within a relative slack of 1e-9. The app may set the interval.
  By default it is the smallest of 1, 2, and 5 times a power of ten that
  keeps adjacent ticks a token-set number of pixels apart.
- The labels form one label set of §spec:unit-system: plain decimals
  rounded to the interval, with the app's number formatting.
  `formatNumberLabel` writes each one. When the app names a unit, the
  first and last labels carry it after a space; a lone tick carries it
  once.
- `vectors/color_ramp_legend.json` pins legends in every corner, both
  orientations, app intervals, the range slack, and a lone tick
  (§spec:golden-vectors).

*Why stops by key*: the package holds no color and converts none
(§spec:scene-color), so a stop names the app's color by key, as every
primitive does. Interpolating in the renderer lets each app blend in
the space it draws in. Pre-sampled bands were rejected: they fix the
band count in the package and still need a color per band from the
app.

*Why an app-provided color map*: the legend is a display primitive,
not a data interpreter. Keeping the scalar-to-color mapping outside lets
any domain reuse the same legend.

*Why plain decimals, not a display format*: a display format labels
lengths, and most legend values, such as a temperature or a stress, are
not lengths. The app knows its value's unit, so it names it. A
length-valued legend names its base unit the same way and forgoes
promotion. An app-supplied formatter was rejected, because the label
text would then escape the fixtures that keep both packages equal.

*Why ticks only on multiples*: a tick at an arbitrary range end, such as
23.7, would need its own rounding and break the one-set rule. An app
that wants its ends ticked picks a range on the interval.

*Why 1, 2, and 5*: they are the decimal formats' scale-bar steps, so a
legend's ticks read as clean as a scale bar's. The grid steps' powers of
ten were rejected, because a range such as 20 to 80 holds no tick of 100
and too few of 10 at the spacing.

*Why the unit only at the ends*: every label shares the unit, and a
narrow bar has no room to repeat it. The ends are where a reader looks
for the range.

*Why the bar spans the rectangle*: the package does not measure text, so
it cannot inset the bar by an end label's width. An end label may
overhang the rectangle by half its extent, which the unclipped
rectangle of §spec:viewport-overlays allows.

### Navigation cube §spec:navigation-cube

A viewport overlay (§spec:viewport-overlays) that shows the camera's
orientation relative to the world axes. It is a passive indicator: it
helps a viewer see which side of the scene faces them, and does not
respond to input (§req:priorities).

- `NavigationCube` names six faces, TOP, BOTTOM, FRONT, BACK, LEFT, and
  RIGHT, each with a world normal and a label frame: the directions its
  text runs and points up.
- Top is the up axis of §spec:coordinate-convention. The app names the
  front axis as a signed world axis other than up, such as -Y, and it
  has no default. Right
  is the face a viewer of Front sees on their right, by the declared
  hand rule.
- Side labels stand upright. Top and Bottom labels point away from
  Front, as the top and bottom views of `CameraBasis.lookAt` hold them,
  so a top view shows TOP upright with FRONT along its bottom edge.
- `visibleFaces` describes the cube in the overlay's pixel rectangle
  for a camera. The cube turns with the camera's rotation only and
  projects orthographically about the rectangle's center, with an edge
  of min(width, height)/√3, so no corner leaves the rectangle.
- It returns only the faces turned toward the viewer, least direct
  first, each as four pixel corners in label order (bottom-left,
  bottom-right, top-right, top-left) and the cosine it faces the viewer
  by. Faces whose facings lie within 1e-9 of the least direct face of
  their group tie, and ties keep face order. The app draws each label
  onto its face with an affine map.
- `vectors/navigation_cube.json` pins face frames and visible faces in
  Y-up and Z-up, both handednesses, and an app-named front
  (§spec:golden-vectors).

*Why a cube*: its six labeled faces map directly to the six orthographic
views. A viewer reads the visible face labels to know where they are
looking from.

*Why the convention gives Top*: many engines are Y-up and others Z-up. A
fixed up axis would label a scene's floor as its front in the other
convention.

*Why the app names the front*: no rule picks a front that suits every
scene. Facing away from the fallback axis gives -Y in Z-up, as plan
views use, but -X in Y-up, where many scenes face +Z. A default would
fail silently there, as a default up axis would, so the app names
Front. Naming the axis opposite the fallback axis puts Front at the
bottom of TOP in a top view, where CAD view cubes put it.

*Why the overlay owns the projection*: the overlay is pixel output
(§spec:viewport-overlays). Handing the app a rotation and leaving it a
second camera would let each renderer pick its own projection and size.
Orthographic projection keeps the cube's size fixed as the scene camera
changes field of view, and keeps each face a parallelogram.

*Why only facing faces*: the cube is convex and opaque, so a face turned
away is always hidden. Facing faces overlap only along shared edges, and
least-direct-first order draws those edges consistently.

*Why the app sets label text*: text on a face is skewed by the face's
projection, so it is not a Billboard. The package gives the label string
and its frame. The app fits its own typeface into the face.

*Why no click-to-snap*: snapping to a clicked face, edge, or corner
needs hit-testing and camera animation, which belong to the app. How
the work splits between app and package is an open question
(§req:open-questions), so the cube's first form commits to none of it.

## Python package §spec:python-package

*Status: in progress*

Pure Python, no runtime dependencies (§req:constraints). It provides
the style tokens, the typed primitives of §spec:scene-model with the
factories and screen-space math of §spec:renderer-contract, the scale
bar, color ramp legend, and navigation cube of §spec:viewport-overlays,
the ground plane of
§spec:ground-plane, the smart dimensions of §spec:smart-dimensions, and,
in time, every layout function and annotation primitive the Dart package
provides (§req:user-stories).

- Points cross the API as plain tuples of floats. Mesh buffers are
  read-only 32-bit memoryviews, matching the Dart package's buffers.
- A Python function may trail its Dart counterpart by any number of
  releases. Where both exist, they agree on every fixture of
  §spec:golden-vectors.
- A function arrives in Python only with its fixtures passing, which is
  what makes a port checkable.

*Why let Python trail*: the first applications are Dart apps, and the
primitives they need first should not wait on a second port
(§req:priorities). The fixtures keep a late port honest.

*Why tuples*: a vector library would be a runtime dependency
(§req:constraints). A tuple of floats passes unchanged into whatever
numeric library a caller already uses. A small vector class was rejected
because callers would convert it at every boundary.

## Versioning and release §spec:release

*Status: in progress*

Both packages share one version and release together.

- Flywheel cuts one `v<version>` tag per release from conventional-commit
  PR titles, and writes the version into `dart/pubspec.yaml`,
  `python/pyproject.toml`, and `dart/CHANGELOG.md`. pub.dev requires the
  package changelog to name the published version; the release notes
  themselves live in the root `CHANGELOG.md`.
- The tag push triggers both publish workflows. pub.dev and PyPI each
  authenticate the workflow through OIDC. No registry token is stored.
- `styleVersion` is independent of the package version. It changes only
  when a token change alters layout.

*Why lockstep*: Flywheel has one tag namespace per repository. A shared
version also states the intent — a style change is one release of both
packages.

*Tradeoff accepted*: a change to one package releases the other with no
difference in content.
