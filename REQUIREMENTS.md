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

The core of the style is placement. A label, leader, or marker sits in
world space so that it moves with the scene, yet it reads as if drawn on
the screen: a fixed pixel size, upright, at a predictable offset. The
library owns that placement. How finely a renderer draws the result, its
anti-aliasing, glyph rasterization, and blending, belongs to the
renderer.

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
- When callouts crowd one area, the operator can still tell which callouts
  are nearest and most relevant, and no callout's text is covered by a
  less relevant one.
- With the camera still, a callout attached to a fast-moving object stays
  readable while the object moves.
- When the app switches mode and a set of callouts appears or disappears,
  the change fades in or out instead of popping.
- Before adopting the library, an app developer can read what every piece
  of scene data means to a renderer, such as which sizes are screen
  pixels and which are world units, and which camera the placement
  assumes, and can check an engine against that list.
- From one rendered frame, a renderer's author can measure that labels,
  leaders, and lines land at the screen positions and pixel sizes the
  library computed, within a stated tolerance, whatever the font or
  anti-aliasing.
- Annotations draw without any asset file: no model, no bundled texture,
  no font.

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
- As an app developer, I want to mark some callouts as more important than
  others, so that the ones my operator depends on survive when the view
  gets crowded.
- As an app developer, I want to show and hide whole sets of callouts as my
  app changes mode, so that each mode shows only what matters to it.
- As an app developer, I want labels in my app's own typeface, so that
  annotations match the rest of my interface.

### Renderer author

- As a renderer author, I want each kind of scene data's meaning stated
  plainly, such as screen-pixel widths and sRGB colors, so that my engine
  places every annotation where the library intended.
- As a renderer author, I want reference screen positions and sizes for
  sample scenes, so that I can test my rendered output against them and
  tighten my tolerance over time.
- As a renderer author, I want to draw indicator markers from generated
  geometry, so that my engine needs no model loader for annotations.

### Machine operator

- As an operator watching a job, I want the toolhead's callout to follow
  the toolhead smoothly enough to read, so that I can read its value
  without stopping the machine.
- As an operator, I want axis travel shown from the home position along
  the machine's axes, updating as the toolhead moves, so that I see how
  far each axis has traveled.
- As an operator orbiting the view, I want callouts to stay attached and
  recognizable while the camera moves, so that I keep my bearings, even if
  I only read them once the camera stops.
- As an operator, I want callouts near where I am looking or pointing to
  come forward, and distant ones to recede, so that I bring an area into
  focus by looking at it.
- As an operator viewing a small part from across the machine, I want a
  cluster of callouts to stay legible as a group, so that the view does
  not turn into overlapping text.

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
- **Keeps up with motion.** Callout placement keeps pace with the app's
  frame rate while the camera and anchors move, for up to about 20
  callouts on screen at once.
- **Fidelity only improves.** Once a renderer meets a placement tolerance
  against the reference positions and sizes, a later change does not
  loosen it.
- **Calm, not jumpy.** A callout does not jump between positions frame to
  frame. Stability matters more than the best position in every frame.

## Constraints §req:constraints

- The library describes annotations as data. The consuming app renders
  them, handles input, and owns the clock. The library computes
  time-dependent values, such as how far a fade has progressed, from the
  elapsed time the app passes in.
- The Dart package runs in any Dart program, with no Flutter dependency.
- The Python package carries no runtime dependencies.
- Both packages share one style and one version, and release together.
- The packages name nothing from any one consumer's domain.
- The supported size range runs from about 0.01 mm to tens of meters.
  Labels cover mm, m, decimal inches, fractional inches, and feet.
- The library targets 3D scene renderers in any language: GPU engines,
  Python 3D and plotting tools, and web viewers.
- The library guarantees placement, not pixels. Visual fidelity beyond
  where things land and how big they are is the renderer's.
- Annotations depend on no asset file. Scene content, such as a model of
  the object being annotated, is the app's to load and draw.
- The typeface is the app's choice. The style sets label sizes, not a
  font.

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
- Callout crowding: relevance from app-set priority combined with
  nearness to the camera focus, the viewer, and the pointer; hiding of
  low-relevance callouts; readable motion for callouts on moving objects;
  and fades when sets of callouts change.
- Python versions of every primitive above, agreeing with Dart within
  tolerance.
- The renderer contract: what each piece of scene data means to a
  renderer, reference screen positions and sizes to measure against, and
  markers drawn from generated geometry.

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
- **Overlapping callouts.** Today the callout nearer the viewer reads
  clearly and the farther one recedes behind it. Whether an overlapped
  callout should instead move aside, or whether priority should outrank
  nearness, needs a prototype and eyes on it.
- **Grouped callouts.** Whether the operator has to tell which feature
  each label in a group belongs to without zooming in is undecided. The
  answer chooses between a single grouped marker and leaders that each
  run to their own point.
- **2D renderers.** Whether a renderer with no 3D scene, such as a 2D
  canvas that projects the scene itself, is a supported target is
  undecided.
- **Motion damping.** How strongly a moving object's callout lags behind
  it, to stay readable without seeming detached, needs tuning by eye.
