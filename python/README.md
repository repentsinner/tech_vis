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

`tokens.STYLE_VERSION` identifies the token set. Two implementations that
report the same style version produce the same layout.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
