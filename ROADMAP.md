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

### Python leader-line layout §road:python-leader-line

Port the leader-line functions to Python. Test them against
`vectors/leader_line.json`.

## Renderer contract §road:renderer-contract

Closes §spec:scene-model.

### Callout leader lines §road:callout-leader-lines

Emit a callout's leader as two `LinePrimitive`s at the style's line width,
so a renderer draws its lines rather than deriving them from leader
points, in `dart/lib/src/leader_line.dart` (§spec:scene-model).

**Verify:** In `dart/`, build a callout's leader and label for a camera
and confirm the leader comes back as two lines whose endpoints are the
leader's gap end, elbow and label edge, at the style's pixel width.

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives.

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
axis (§spec:navigation-cube).
