# tech_vis

Technical visualization primitives for annotated 3D scenes. This is the
Python package; a Dart package of the same name and version shares its
style tokens. Both come from
[one repository](https://github.com/repentsinner/tech_vis).

## Installation

```bash
uv add tech_vis
```

## Usage

A callout is a label tied to a point in the scene by a leader line. The
line leaves the anchor at an angle, bends, and runs horizontally to the
label. `compute_callout_leader_geometry` lays that line out in the camera's
screen plane and returns its three points in world space:

```python
from tech_vis import (
    CalloutQuadrant,
    callout_anchor_alignment,
    compute_callout_leader_geometry,
    compute_callout_opacity,
)

leader = compute_callout_leader_geometry(
    anchor=(1.5, -2.25, 3.0),
    camera_right=(1.0, 0.0, 0.0),
    camera_up=(0.0, 1.0, 0.0),
    world_units_per_pixel=0.125,
    quadrant=CalloutQuadrant.TOP_RIGHT,
)
leader.gap_end, leader.elbow, leader.label_edge  # (x, y, z) tuples

alignment = callout_anchor_alignment(CalloutQuadrant.TOP_RIGHT)  # label UV
opacity = compute_callout_opacity(distance_to_camera)
```

Points are plain tuples of floats, so the package needs no vector library.
Pass a `LeaderLineStyle` to override the segment lengths and angle.

### Primitives

The factories return typed primitives for a renderer to draw:
`LinePrimitive`, `QuadPrimitive`, `BillboardPrimitive`, `MarkerPrimitive`,
and `MeshPrimitive`. Each carries an opacity and an app key that the package
passes through untouched, so the app resolves color from the key. A
`CoordinateConvention` declares which axis points up and the handedness of
the app's space. The camera, markers, and envelope labels read it:

```python
import math

from tech_vis import (
    BillboardContent,
    BoundingBox,
    CalloutQuadrant,
    CameraBasis,
    CoordinateConvention,
    Handedness,
    SpatialAxis,
    compute_callout_leader_geometry,
    create_bounding_box,
    create_callout_label,
    create_callout_leader_lines,
    create_marker,
    world_to_screen,
    world_units_per_pixel_at,
)

z_up = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.RIGHT)
camera = CameraBasis.look_at(position=(7, -9, 5), target=(0, 0, 0.75), convention=z_up)
fov, viewport = math.radians(45), (1280.0, 720.0)

box = create_bounding_box(
    BoundingBox(min_bounds=(-2, -1, 0), max_bounds=(2, 1, 1.5)),
    key="part",
    fill_opacity=0.25,
)
marker = create_marker((0, 0, 1.5), z_up, key="probe")

anchor = (2.0, 1.0, 1.5)
leader = compute_callout_leader_geometry(
    anchor=anchor,
    camera_right=camera.right,
    camera_up=camera.up,
    world_units_per_pixel=world_units_per_pixel_at(anchor, camera, fov, viewport[1]),
    quadrant=CalloutQuadrant.TOP_RIGHT,
)
lines = create_callout_leader_lines(leader, key="note", opacity=1.0)
label = create_callout_label(
    leader,
    CalloutQuadrant.TOP_RIGHT,
    content=BillboardContent(value=my_text_layout, width_pixels=56, height_pixels=14),
    key="note",
    opacity=1.0,
)

x, y = world_to_screen(anchor, camera, fov, viewport)  # pixels, y down
```

Text the package composes, such as an axis letter, reaches the app as a
`TextRequest`. A factory that sets text takes a `resolve_text` function,
which sets the request in the app's typeface and returns a
`BillboardContent` with the pixel size the renderer draws it at.
`marker_transform` returns the per-frame matrix that keeps a marker at its
pixel diameter, and `world_to_screen` places any world point in viewport
pixels, which is how a renderer measures a frame against the reference
screen geometry.

The style defaults come from `tech_vis.tokens`:

```python
from tech_vis import tokens

gap_px = tokens.CALLOUT_GAP_PIXELS
every_token = tokens.ALL
```

A `DisplayFormat` labels measurements and picks scale-bar and grid steps.
Every length it takes or returns is in its unit system's base unit, so
convert a world length with `UnitSystem.convert_to` first:

```python
from tech_vis import DisplayFormat, NumberFormatting, DecimalMarker

DisplayFormat.METRIC.format_labels([0, 5000, 10000], step=5000)
# ['0 m', '5 m', '10 m']
DisplayFormat.DECIMAL_INCH.format_labels(
    [2.5], numbers=NumberFormatting(decimal_marker=DecimalMarker.COMMA)
)
# ['2,5 in']
DisplayFormat.FRACTIONAL_INCH.grid_step_above(1)  # 12.0
```

### Viewport overlays

The scale bar and the navigation cube sit in the 2D layer above the
scene. Each is laid out in viewport pixels, origin top-left with y down,
inside the rectangle its `ViewportOverlayPlacement` gives it.
`ScaleBarLayout.at_target` measures the scene at the point the camera
looks at and picks the longest clean step that fits the bar's rectangle.
Passing the previous frame's `step` as `previous_step` keeps the value
from flickering as the camera zooms. `NavigationCube` lists the faces
that face the viewer, least direct first, each as four pixel corners for
an affine map of its label:

```python
from tech_vis import (
    DisplayFormat,
    NavigationCube,
    ScaleBarLayout,
    SignedAxis,
    SpatialAxis,
    UnitSystem,
    ViewportOverlayKind,
    ViewportOverlayPlacement,
)

bar = ScaleBarLayout.at_target(
    camera=camera,
    target=(0, 0, 0.75),
    vertical_fov_radians=fov,
    viewport_size=viewport,
    world_units=UnitSystem.METRIC,
    display_format=DisplayFormat.METRIC,
    previous_step=None,  # last frame's bar.step
)
if bar is not None:
    bar.label.text, bar.start_x, bar.end_x, bar.tick_xs

cube = NavigationCube(convention=z_up, front=SignedAxis(SpatialAxis.Y, negative=True))
rect = ViewportOverlayPlacement.of(ViewportOverlayKind.NAVIGATION_CUBE).rect(viewport)
for view in cube.visible_faces(camera, rect):
    view.face.label, view.corners  # "TOP", four (x, y) tuples
```

`tokens.STYLE_VERSION` identifies the token set. Two implementations that
report the same style version produce the same layout.

### Ground grid and dimensions

A ground grid lies in the plane across the declared up axis. Its minor
lines keep a minimum pixel spacing at the camera target, so the step
changes with zoom, and its lines fade toward the patch edge. A dimension
measures between points the app supplies: a length, an angle, or a radius
or diameter. Both are sized in screen pixels, so the app rebuilds them each
frame the camera moves:

```python
from tech_vis import (
    CircularGroundPatch,
    DraftingConvention,
    RadialMeasure,
    create_angular_dimension,
    create_dimension,
    create_ground_grid,
    create_radial_dimension,
)

grid = create_ground_grid(
    convention=z_up,
    patch=CircularGroundPatch(radius=500),
    display_format=DisplayFormat.METRIC,
    world_units=UnitSystem.METRIC,
    camera=camera,
    target=(0.0, 0.0, 0.0),
    vertical_fov_radians=fov,
    viewport_height=viewport[1],
    resolve_text=resolve_text,
    minor_key="grid-minor",
    major_key="grid-major",
    label_key="grid-label",
)
grid.primitives  # minor lines, major lines, then coordinate labels

view = {"camera": camera, "vertical_fov_radians": fov, "viewport_size": viewport}
length = create_dimension(
    start=(0, 0, 0),
    end=(120, 0, 0),
    drafting=DraftingConvention.ISO_ORIENTED,
    display_format=DisplayFormat.METRIC,
    world_units=UnitSystem.METRIC,
    resolve_text=resolve_text,
    key="dimension",
    **view,
)  # reads "120 mm"
angle = create_angular_dimension(
    vertex=(0, 0, 0),
    first=(120, 0, 0),
    second=(0, 80, 0),
    drafting=DraftingConvention.ISO_ORIENTED,
    resolve_text=resolve_text,
    key="dimension",
    **view,
)  # reads "90°"
bore = create_radial_dimension(
    center=(60, 40, 0),
    radius=15,
    normal=(0, 0, 1),
    measure=RadialMeasure.DIAMETER,
    drafting=DraftingConvention.ISO_ORIENTED,
    display_format=DisplayFormat.METRIC,
    world_units=UnitSystem.METRIC,
    resolve_text=resolve_text,
    key="dimension",
    **view,
)  # reads "⌀30 mm"
```

Pass `grid.minor_step` back as the next frame's `previous_minor_step`, so
the step holds near a step boundary instead of flickering between two
steps. A `DraftingConvention` picks ISO or ASME and where the text sits.
Oriented or inlined text that doesn't fit between the arrowheads moves to
a leader, as a referencing dimension's does.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
