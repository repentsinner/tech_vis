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
tests its implementation against every fixture.

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

*Status: complete*

`UnitSystem` names the metric (mm) and imperial (in) systems. It
converts between them, formats measurement labels, and supplies the step
sequences that grid subdivisions and scale bar ticks snap to.

## Annotation primitives §spec:annotation-primitives

*Status: not started*

The package provides annotation primitives for engineering 3D scenes.
Each primitive produces `SceneObject` data, pure geometry and labels,
without rendering it. Consumers map annotations to their renderer's
scene graph.

Every primitive that displays a real-world measurement formats its
labels and subdivides through §spec:unit-system.

### Ground plane §spec:ground-plane

A reference surface anchored to a named coordinate frame origin.
The ground plane provides spatial context. Without it, floating
geometry has no perceptible scale or orientation.

The ground plane is a rectangular or circular patch with
radial or rectangular fade-to-transparent at its edges. It displays an
adaptive grid with a major/minor line hierarchy. The grid step snaps to
the unit system's powers-of-ten sequence at the current zoom level
(mm: 0.1 → 1 → 10 → 100; inch: 1/16 → 1/8 → 1 → 12). Major
divisions carry coordinate labels in the active unit.

*Why an adaptive grid*: a fixed grid spacing is too coarse when zoomed
in and an illegible mesh when zoomed out. Snapping to the unit system's
natural steps keeps grid density perceptually constant across zoom
levels.

*Why fade at the edges*: a hard-clipped ground plane creates a visual
boundary that implies a physical constraint. Fade-to-transparent
communicates a reference surface without implying a wall.

### Scale bar §spec:scale-bar

A screen-space ruler showing real-world distance at the current
zoom level. It sits in a viewport corner and stays readable at any
camera orientation.

The scale bar subdivides with the same unit system step sequence as
the ground plane grid. As the camera zooms, the bar snaps to the
nearest clean unit increment and updates its label.

*Why screen-space*: a world-space ruler changes apparent size with
camera distance, which defeats its purpose. A fixed screen-space element
with an adaptive label communicates scale at any zoom.

### Smart dimensions §spec:smart-dimensions

Point-to-point dimension annotations following ISO 129 / ASME Y14.5
conventions, with screen-space-stable text and witness lines.

When two points share N−1 axis values within tolerance, the dimension
aligns to the varying axis's measurement plane, with witness lines
perpendicular to that axis. A difference along several axes shows
either per-axis component dimensions or the direct distance with an
angled leader. Variants are linear, angular (between two vectors), and
radial (arc or circle diameter).

*Why detect axis alignment*: a reader of a technical drawing thinks in
per-axis distances, such as X travel or Z depth. Showing the single
varying axis matches that reading. Direct distance with components
handles the general case.

### Color ramp legend §spec:color-ramp-legend

A labeled gradient bar for a scalar-to-color mapping such as speed,
temperature, stress, or altitude. The consumer provides the color map
and the value range. The legend handles layout and formats labels
through §spec:unit-system.

Position, orientation (horizontal or vertical), tick marks at value
intervals, and unit-labeled endpoints are configurable.

*Why a consumer-provided color map*: the legend is a display primitive,
not a data interpreter. Keeping the scalar-to-color mapping outside lets
any domain reuse the same legend.

### Navigation cube §spec:navigation-cube

An orientation indicator drawn as a small overlay in a viewport corner.
A cube with labeled faces (Top, Front, Right, and so on) tracks the
camera's orientation relative to the world axes. It builds on the
package's coordinate frame descriptors.

Clicking a part of the cube snaps the view:

- **Face**: an orthographic view (top, front, right).
- **Edge**: a two-axis view (front-right, top-front).
- **Corner**: an isometric view (top-front-right, and so on).

Every transition animates the camera smoothly.

*Why a cube*: its six labeled faces map directly to the six orthographic
views, and its edges and corners give two-axis and three-axis views
without a menu. Clicking "Top" does what the label says.

## Python package §spec:python-package

*Status: in progress*

Pure Python, no runtime dependencies. It provides the style tokens.
Layout functions arrive with §spec:golden-vectors, which is what makes a
port checkable.

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
