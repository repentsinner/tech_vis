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

*Status: not started*

Layout functions are ported by hand between languages. A shared set of
language-neutral fixtures shall pin the ports to each other: each fixture
records a function's inputs and its expected outputs, and each package
tests its implementation against every fixture (§req:success-criteria).

- Fixtures live in `vectors/` at the repository root, outside both
  package roots. Each package's fixture tests skip where the directory
  is absent, as it is in a published archive.
- The Dart implementation is the reference. A tool in `tools/` runs it
  over each fixture's inputs and writes the expected outputs. The
  fixtures are committed, and a change to them is reviewed like code.
- Every public layout function in either package has fixtures. A
  function that exists in only one package still has fixtures, so the
  port inherits a finished test suite.
- Numeric outputs compare within an absolute tolerance of 1e-9 in the
  function's own units. Label text compares exactly.
- CI shall fail when a committed fixture differs from the tool's output.

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
It provides scene object types, coordinate frames, bounding boxes,
leader-line callout geometry, and screen-space conversions.

A generic toolkit shall name nothing from a consumer's domain.
`dart/test/generic_vocabulary_test.dart` enforces this: it fails when a
source file under `dart/lib/` matches the vocabulary of the application
the package was extracted from.

## Scene model §spec:scene-model

*Status: complete*

The package produces scenes as data and never renders them. A renderer
implements `SceneRendererBackend` and maps each `SceneObject` in a
`SceneDescription` to its engine's draw calls. Factories such as
`BoundingBoxFactory`, `EnvelopeLabelFactory`, and
`FilledRectangleFactory` compose scene objects from geometry.

- `SceneObject` is a generic base. A consumer that needs its own object
  types subclasses it. No type in the package shall reference a
  subclass.
- A type belongs in the package when a visualizer in an unrelated domain
  would need it. A type that makes sense in only one domain belongs in
  that domain's consumer.

*Why data, not rendering*: one scene description drives any engine, and
a scene can be tested without a GPU.

## Scene color resolution §spec:scene-color

*Status: complete*

`SceneTheme.resolveLineColor(Object)` returns a `SceneColor`, an RGBA
value with no Flutter dependency. A consumer's theme narrows the
parameter to its own line category type.

The composition layer resolves each object's color and stores it on
`SceneObject.resolvedColor`. A backend reads `resolvedColor` and makes
no color decision of its own.

*Why resolve upstream*: the color a line takes depends on what the line
means. The composition layer holds that meaning; the backend holds only
geometry.

## Unit system §spec:unit-system

*Status: in progress*

`UnitSystem` names the metric (mm) and imperial (in) systems and
converts between them. A measurement displays in one of three formats,
which the app selects:

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

- A set of labels displayed together, such as a grid's or a scale
  bar's, uses one unit for every label in the set. The largest value in
  the set decides whether the set promotes.
- A label shows the fewest decimal places that represent its step
  exactly, with no trailing zeros.
- The app sets the decimal marker (point or comma) and whether a value
  below one shows its leading zero. The defaults are a point and a
  leading zero shown.

*Why three formats, not two systems*: imperial readers split. Machinists
read thousandths of an inch, and router and woodworking users read
fractions and feet (§req:user-stories). The conversion factor is the
same; the display is not.

*Why promote metric only at 10 m*: millimeters are the working unit on
a machine up to room scale. Promotion exists so that no label carries a
five-digit millimeter value (§req:user-stories).

*Why one unit per label set*: a grid labeled `900`, `1 m`, `1100` reads
as three different quantities.

## Annotation primitives §spec:annotation-primitives

*Status: not started*

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

### Viewport overlays §spec:viewport-overlays

The scale bar, the color ramp legend, and the navigation cube are
overlays. An overlay is described in viewport pixels, not world
coordinates, and the app draws it in a 2D layer above the scene.

- An overlay anchors to one viewport corner, with an offset from that
  corner in pixels.
- Each overlay has a default corner, offset, and size, held as style
  tokens. The app may override each one (§req:success-criteria).
- Given the same camera, viewport size, and settings, an overlay's
  description is identical in both packages.

*Why pixels, not world geometry*: an overlay's job is to hold still
while the scene moves. Placing it as world geometry near the camera
ties it to the projection, so it shifts with field of view and clips
against scene depth. A pixel description is also checkable as data,
with no camera math in the test.

*Tradeoff accepted*: the package has two kinds of output, a world-space
scene and a pixel-space overlay. A renderer handles both.

### Ground plane §spec:ground-plane

A reference surface anchored to the origin of a named coordinate frame.
The ground plane provides spatial context. Without it, floating
geometry has no perceptible scale or orientation (§req:user-stories).

- The ground plane is a rectangular or circular patch, sized by the app,
  lying in a plane of its coordinate frame.
- It displays a grid with minor and major lines. The minor step is the
  smallest grid step of §spec:unit-system that keeps minor lines at
  least a token-set number of pixels apart at the camera target. The
  major step is the next grid step.
- Line opacity falls with distance from the patch center, reaching zero
  at the patch edge. The fade is radial for a circular patch and
  rectangular for a rectangular one.
- Major lines carry coordinate labels in the active display format,
  billboarded so they stay readable at oblique camera angles
  (§req:quality-attributes).
- When the camera rests near a step boundary, the grid does not flicker.
  The step changes only once the spacing passes the boundary by a
  token-set margin, and changes back only once it passes back by the
  same margin.

*Why an adaptive grid*: a fixed grid spacing is too coarse when zoomed
in and an illegible mesh when zoomed out. Snapping to the unit system's
grid steps keeps grid density perceptually constant across zoom levels
(§req:success-criteria).

*Why fade at the edges*: a hard-clipped ground plane creates a visual
boundary that implies a physical constraint. Fade-to-transparent
communicates a reference surface without implying a wall.

*Why billboard the labels*: a label lying flat on the plane becomes
unreadable as the view approaches edge-on, which is the view a reader
uses to judge height above the floor.

### Scale bar §spec:scale-bar

A viewport overlay (§spec:viewport-overlays) showing real-world
distance at the current zoom (§req:user-stories).

- The bar's length represents the largest scale bar step of
  §spec:unit-system that fits within a token-set maximum pixel length,
  measured at the camera target.
- The bar subdivides into ticks and carries a label for the value it
  represents, in the active display format.
- The bar's value does not flicker at a step boundary, by the same
  margin rule as §spec:ground-plane.

*Why screen-space*: a world-space ruler changes apparent size with
camera distance, which defeats its purpose. A fixed screen-space element
with an adaptive label communicates scale at any zoom.

*Why measure at the camera target*: under perspective, scale varies
across the view. The camera target is the point the reader is looking
at, so its scale is the one they want.

### Smart dimensions §spec:smart-dimensions

Point-to-point dimension annotations with witness lines, arrowheads, and
text that keeps a constant screen size at any zoom (§req:user-stories).
The app supplies the measured points; the package decides how the
dimension reads.

- **Linear.** When two points differ along one axis only, within an
  alignment tolerance, the dimension measures that axis. Its witness
  lines are perpendicular to that axis. The tolerance defaults to a
  style token, and the app may override it.
- **Several axes.** When the points differ along more than one axis,
  the app chooses between per-axis component dimensions and the direct
  distance with an angled leader.
- **Angular.** The angle between two vectors from a common vertex, drawn
  as an arc.
- **Radial.** The radius or diameter of a circle or arc, given its
  center, radius, and plane.
- Witness line gap and extension, arrowhead size, and text size are
  style tokens, all in pixels. The witness line gap has one token per
  standard.
- Text orientation and placement follow §spec:drafting-convention. A
  referencing dimension's leader uses the same geometry and style tokens
  as a leader-line callout.
- Number formatting follows §spec:unit-system.

*Why detect axis alignment*: a reader of a technical drawing thinks in
per-axis distances, such as X travel or Z depth. Showing the single
varying axis matches that reading. Direct distance with components
handles the general case.

*Why the app supplies the points*: what is worth measuring depends on
the app's domain. A generic toolkit that guessed would name concepts
from one consumer (§spec:dart-package).

### Color ramp legend §spec:color-ramp-legend

A viewport overlay (§spec:viewport-overlays) that keys a color-coded
value, such as speed, temperature, stress, or altitude, to its colors.
The app provides the scalar-to-color mapping and the value range. The
legend handles layout, ticks, and labels, and formats them through
§spec:unit-system.

Orientation (horizontal or vertical), tick intervals, and unit-labeled
endpoints are configurable.

*Open*: how the gradient itself reaches the renderer is undecided. The
choice is between color stops that the renderer interpolates and
pre-sampled solid bands.

*Why an app-provided color map*: the legend is a display primitive,
not a data interpreter. Keeping the scalar-to-color mapping outside lets
any domain reuse the same legend.

### Navigation cube §spec:navigation-cube

A viewport overlay (§spec:viewport-overlays) that shows the camera's
orientation relative to the world axes. It is a passive indicator: it
helps a viewer see which side of the scene faces them, and does not
respond to input (§req:priorities).

- The package describes a cube with labeled faces (Top, Front, Right,
  and so on) and its rotation for the current camera. The app renders
  it with its own fixed camera in its corner.
- The app names the world up axis and front axis. The defaults are
  Z up, with the Front face's normal along −Y.
- The cube's labels and orientation build on the package's coordinate
  frame descriptors.

*Why a cube*: its six labeled faces map directly to the six orthographic
views. A viewer reads the visible face labels to know where they are
looking from.

*Why the app names the axes*: Z-up is the convention of the first
applications and of the package's meshes, but many engines are Y-up. A
fixed convention would label a Y-up scene's floor as its front.

*Why no click-to-snap*: snapping to a clicked face, edge, or corner
needs hit-testing and camera animation, which belong to the app. How
the work splits between app and package is an open question
(§req:open-questions), so the cube's first form commits to none of it.

## Python package §spec:python-package

*Status: in progress*

Pure Python, no runtime dependencies (§req:constraints). It provides
the style tokens and, in time, every layout function and annotation
primitive the Dart package provides (§req:user-stories).

- A Python function may trail its Dart counterpart by any number of
  releases. Where both exist, they agree on every fixture of
  §spec:golden-vectors.
- A function arrives in Python only with its fixtures passing, which is
  what makes a port checkable.

*Why let Python trail*: the first applications are Dart apps, and the
primitives they need first should not wait on a second port
(§req:priorities). The fixtures keep a late port honest.

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
