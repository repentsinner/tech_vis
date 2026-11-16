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

final camera = CameraBasis.lookAt(position: eye, target: target);

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

`StyleTokens` holds every style constant, generated from the repository's
`style/tokens.json`. `StyleTokens.styleVersion` identifies the token set.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
