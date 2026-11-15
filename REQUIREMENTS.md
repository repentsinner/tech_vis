# tech_vis — Requirements

## Problem statement §req:problem-statement

**Target users** are developers who annotate 3D scenes in a technical
drawing style: a point in space, a thin leader line, a label that stays
legible at any camera distance. Their renderers differ — different
engines, different languages — and the look should not.

**The problem** is that the style lives in constants and layout math
scattered through each renderer. A second renderer copies the numbers,
and the copies drift.

**Success** is one style, defined once, that renderers in more than one
language reproduce and can prove they reproduce.

The first applications are desktop- to room-scale machines: 3D printers,
CNC mills, and CNC routers. Their readers check sizes, clearances, and
travel in a 3D view, and they read those numbers the way they read a shop
drawing. Later applications may sit far outside that range, such as
geographic data or micron-scale specimens.

## Success criteria §req:success-criteria

- Given the same scene, camera, and viewport, the Dart and Python packages
  produce the same geometry and label text, within a stated tolerance, for
  every layout both packages offer. A tester can check this without a GPU.
- A dimension reads in the drafting convention the app selects, ISO 129 or
  ASME Y14.5, and an inch value reads in the format the app selects,
  decimal or fractional.
- While the camera zooms across the supported size range, the ground plane
  grid and the scale bar stay legible. Lines are neither a dense mesh nor
  absent, and every label lands on a clean value in the active unit.
- A viewer glancing at the navigation cube can tell which side of the
  scene faces them.
- An app that adds a corner overlay gets the standard size, position, and
  padding without configuring them, and can override each one.

## User stories §req:user-stories

### App developer

- As an app developer, I want to hand the library two points and get back
  a dimension that reads like a technical drawing, so that my users see
  distances the way they expect without my learning drafting conventions.
- As an app developer, I want a ground plane under my scene, anchored to a
  coordinate frame I name, so that floating geometry has a visible scale
  and orientation.
- As an app developer, I want a scale bar in a viewport corner, so that my
  users know real-world size at the current zoom.
- As an app developer, I want a legend for my own color mapping, so that
  my users can read a color-coded value such as speed or temperature.
- As an app developer, I want a navigation cube that tracks the camera, so
  that my users stay oriented while they orbit the scene.
- As an app developer, I want to choose the drafting convention and inch
  format once, so that every annotation in my app agrees with my audience.
- As an app developer writing a Python renderer, I want the same
  annotations the Dart package offers, so that a scene reads the same in
  both. Python may trail Dart, but the two shall agree wherever both exist.

### Scene reader

- As a machinist working in inches, I want dimensions and grid labels in
  decimal inches, so that they match the thousandths I set on the machine.
- As a router or woodworking user, I want fractional inches and feet, so
  that labels match my tape measure.
- As a metric user, I want millimeter labels that switch to meters on a
  large machine, so that I never read a five-digit millimeter value.
- As any reader, I want two points that differ along one axis to show that
  axis's distance, so that I read X travel or Z depth directly.
- As any reader, I want a dimension's text to stay readable at any zoom
  and camera angle, so that I never have to rotate the view to read it.

## Quality attributes §req:quality-attributes

- **Stable at boundaries.** When the camera rests near a point where the
  grid step or scale bar value changes, the display does not flicker
  between the two values.
- **Checkable without rendering.** Every layout result can be tested from
  data alone, in CI, with no display or GPU.
- **Readable at any angle.** Labels stay legible across camera distance and
  orientation, including oblique views of the ground plane.
- **Engine-neutral.** Nothing in either package assumes a particular
  rendering engine, UI framework, or input system.

## Constraints §req:constraints

- The library describes annotations as data. The consuming app renders
  them, handles input, and owns any animation.
- The Dart package runs in any Dart program, with no Flutter dependency.
- The Python package carries no runtime dependencies.
- Both packages share one style and one version, and release together.
- The packages name nothing from any one consumer's domain.
- The supported size range runs from about 0.01 mm to tens of meters.
  Labels cover mm, m, decimal inches, fractional inches, and feet.

## Priorities §req:priorities

**Required first, in Dart:**

1. Smart dimensions. Reading distances is the core task in the first
   applications.
2. Ground plane. Without it, the scene has no perceptible floor or scale.
3. Scale bar. It answers "how big is this?" at a glance.

The unit formatting these three share comes with them, because each one
displays a real-world measurement.

**Wanted next:**

- Color ramp legend.
- Navigation cube as a passive orientation indicator: it shows labeled
  faces and edges and tracks the camera, but does not respond to clicks.
- Python versions of every primitive above, agreeing with Dart within
  tolerance.

**Later:**

- Visual comparison of rendered output across engines, beyond matching
  numbers.
- An interactive navigation cube (see §req:open-questions).
- Size ranges beyond desktop-to-room scale, and the units they need.

## Open questions §req:open-questions

- **Navigation cube interaction.** The model is a Fusion-style cube where
  a click on a face, edge, or corner snaps the view. The split of work is
  undecided. The app might hit-test and report what was clicked, with the
  library returning the target view, or the app might pass input data to
  library-side trackball logic.
- **Scales outside the first applications.** Geographic and micron-scale
  scenes may need units, label precision, and grid behavior that the
  supported range does not cover.
