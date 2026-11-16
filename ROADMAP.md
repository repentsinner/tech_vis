# tech_vis — Roadmap

## Release plumbing §road:release-plumbing

Closes §spec:release.

### First publish §road:first-publish

Both registries need a first step that automation cannot take.

- Publish `dart/` to pub.dev by hand once, then enable automated
  publishing for this repository with tag pattern `v{{version}}` and
  environment `pub.dev`. Automated publishing can be enabled only on a
  package that exists.
- Register the PyPI pending publisher for `publish-pypi.yml`, environment
  `pypi`.

Done when a merged `feat:` PR publishes both packages with no manual step.

## Shared layout §road:shared-layout

Closes §spec:golden-vectors and the layout half of §spec:python-package.

### Leader-line golden vectors §road:leader-vectors

Record fixtures for leader-line callout geometry, anchor alignment, and
the opacity ramp. Test the Dart implementation against them.

### Python leader-line layout §road:python-leader-line

Port the leader-line functions to Python. Test them against the same
fixtures. Depends on §road:leader-vectors.

## Renderer contract §road:renderer-contract

Closes §spec:scene-model, §spec:scene-color, §spec:coordinate-convention,
and §spec:renderer-contract.

### Coordinate convention §road:coordinate-convention

Add the declared up axis and handedness, required by `CameraBasis.lookAt`
and by every mesh the package generates, in
`dart/lib/src/screen_space_utils.dart` and a new convention type
(§spec:coordinate-convention).

### Typed primitives §road:typed-primitives

Replace `SceneObject`, its containers, `SceneTheme`, `SceneColor`, and
`SceneRendererBackend` with the Line, Quad, Billboard, Marker, and Mesh
primitives, and return them from `BoundingBoxFactory`,
`FilledRectangleFactory`, and `CoordinateFrameFactory`
(§spec:scene-model, §spec:scene-color). Depends on
§road:coordinate-convention.

### Billboard text requests §road:billboard-text-requests

Emit composed text as text requests that come back as sized Billboards,
and move `EnvelopeLabelFactory` and callout labels onto them, in
`dart/lib/src/envelope_label_factory.dart` and
`dart/lib/src/leader_line.dart` (§spec:scene-model). Depends on
§road:typed-primitives.

### Generated markers §road:generated-markers

Generate the Marker's sphere mesh and its per-frame transform for a pixel
diameter, in a new `dart/lib/src/marker.dart`
(§spec:renderer-contract). Depends on §road:typed-primitives.

### Reference screen geometry §road:reference-screen-geometry

Record sample scenes with each primitive's expected screen position and
pixel size as fixtures under `vectors/`, with the generating tool in
`tools/` (§spec:renderer-contract, §spec:golden-vectors). Depends on
§road:leader-vectors, §road:billboard-text-requests, and
§road:generated-markers.

### Renderer guide §road:renderer-guide

Document what each primitive means to a renderer, the declared
convention, and how to measure a frame against the reference fixtures,
in `dart/README.md` and the root `README.md`
(§spec:renderer-contract). Depends on §road:reference-screen-geometry.

**Verify:** In `dart/`, run `dart test`, and confirm `grep -rn SceneObject
lib/` finds nothing. Build the same box and coordinate frame under a
Y-up and a Z-up convention, and confirm every output is one of the five
primitives, each carrying its opacity and the app key passed in, and
that mesh faces point outward in both. Place a marker at depths 10 and
1000 and confirm its projected diameter matches its pixel diameter at
both. Run the reference-geometry tool and confirm it reproduces the
committed fixtures unchanged. Read the renderer guide and confirm it
names every primitive with what a renderer shall do with it.

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives, so this section depends on §road:typed-primitives.

### Smart dimensions §road:smart-dimensions

Point-to-point dimensions following ISO 129 / ASME Y14.5
(§spec:smart-dimensions).

### Ground plane §road:ground-plane

Adaptive grid with a major/minor hierarchy (§spec:ground-plane).

### Scale bar §road:scale-bar

Screen-space ruler with adaptive subdivision (§spec:scale-bar).

### Color ramp legend §road:color-ramp-legend

Gradient bar for scalar-to-color mappings (§spec:color-ramp-legend).

### Navigation cube §road:nav-cube

Passive orientation indicator whose Top face follows the declared up
axis (§spec:navigation-cube). Depends on §road:coordinate-convention.
