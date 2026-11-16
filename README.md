# tech_vis

Technical visualization primitives for annotated 3D scenes: leader-line
callouts, coordinate frames, labeled bounding boxes, and the style tokens
that give them one look. Renderer-agnostic. Published for Dart and Python
from one repository, so both draw the same style from the same data.

| Path | What | Published as |
|---|---|---|
| `style/tokens.json` | Style tokens — the source of truth | — |
| `dart/` | Pure Dart package | [`tech_vis` on pub.dev](https://pub.dev/packages/tech_vis) |
| `python/` | Pure Python package | [`tech_vis` on PyPI](https://pypi.org/project/tech_vis/) |
| `tools/gen_tokens.py` | Generates each package's token module | — |
| `vectors/` | Golden vectors — inputs and expected outputs every port tests against | — |
| `dart/tool/gen_vectors.dart` | Generates `vectors/` from the Dart reference | — |

## Installation

```bash
dart pub add tech_vis      # Dart
uv add tech_vis            # Python
```

## Usage

Dart:

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
final worldUnitsPerPixel = ScreenSpaceUtils.worldUnitsPerPixelAt(
  anchor,
  camera,
  verticalFovRadians,
  viewportHeight,
)!;

final leader = computeCalloutLeaderGeometry(
  anchor: anchor,
  cameraRight: camera.right,
  cameraUp: camera.up,
  worldUnitsPerPixel: worldUnitsPerPixel,
  quadrant: CalloutQuadrant.topRight,
);
```

Python:

```python
from tech_vis import DisplayFormat, UnitSystem, tokens

gap_px = tokens.CALLOUT_GAP_PIXELS

# Display formats take lengths in their unit system's base unit.
inches = UnitSystem.METRIC.convert_to(1500, UnitSystem.IMPERIAL)
DisplayFormat.FRACTIONAL_INCH.format_labels([inches])  # ['4\' 11 1/16"']
step = DisplayFormat.METRIC.scale_bar_step_at_most(130)  # 100.0
```

```python
from tech_vis import ViewportOverlayKind, ViewportOverlayPlacement

cube = ViewportOverlayPlacement.of(ViewportOverlayKind.NAVIGATION_CUBE)
left, top, right, bottom = cube.rect((1280.0, 720.0))
```

```python
from tech_vis import CalloutQuadrant, compute_callout_leader_geometry

leader = compute_callout_leader_geometry(
    anchor=anchor,
    camera_right=camera_right,
    camera_up=camera_up,
    world_units_per_pixel=world_units_per_pixel,
    quadrant=CalloutQuadrant.TOP_RIGHT,
)
```

The Python package takes and returns points as plain `(x, y, z)` tuples of
floats, so it needs no vector library. It carries the style tokens, the
display formats, overlay placement, the scale bar, the color ramp legend,
the navigation cube, the camera projection, and the typed primitives with
their box, coordinate-frame, envelope-label, marker, callout, ground-grid,
and dimension factories. It trails the Dart package, and the rest follows; see
[ROADMAP.md](ROADMAP.md).

## Renderer guide

Both packages emit annotations as data and draw nothing. The
[renderer guide](dart/README.md#placement-and-pixel-fidelity) in the Dart
package's README states what each primitive means to the engine that
draws it and which camera the placement assumes. It also shows how to
measure a rendered frame against the reference screen geometry in
`vectors/`, whichever language the renderer is written in.

## Changing the style

Edit `style/tokens.json`, then regenerate and commit the token modules.
A token that shapes layout also changes the golden vectors, so regenerate
those too:

```bash
python3 tools/gen_tokens.py
(cd dart && dart run tool/gen_vectors.dart)
```

CI fails when a generated module or a golden vector is stale
(§spec:style-tokens, §spec:golden-vectors).

## License

BSD 3-Clause. See [LICENSE](LICENSE).
