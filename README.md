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

## Installation

```bash
dart pub add tech_vis      # Dart
uv add tech_vis            # Python
```

## Usage

Dart:

```dart
import 'package:tech_vis/tech_vis.dart';

final camera = CameraBasis.lookAt(position: eye, target: target);
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
from tech_vis import tokens

gap_px = tokens.CALLOUT_GAP_PIXELS
```

The Python package carries the tokens today. Layout functions follow; see
[ROADMAP.md](ROADMAP.md).

## Changing the style

Edit `style/tokens.json`, then regenerate and commit the token modules:

```bash
python3 tools/gen_tokens.py
```

CI fails when a generated module is stale (§spec:style-tokens).

## License

BSD 3-Clause. See [LICENSE](LICENSE).
