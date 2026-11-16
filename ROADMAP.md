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

### Python renderer contract §road:python-renderer-contract

Port the typed primitives, the coordinate convention, the camera basis,
`world_to_screen`, markers, and the box, frame, envelope, and callout
factories, with the callout leader's line width (§spec:scene-model,
§spec:coordinate-convention, §spec:renderer-contract), tested against
`vectors/reference_screen_geometry.json`. Depends on
§road:python-leader-line.

### Python overlay annotations §road:python-overlay-annotations

Port the scale bar and the navigation cube (§spec:scale-bar,
§spec:navigation-cube), tested against `vectors/scale_bar.json` and
`vectors/navigation_cube.json`. Depends on
§road:python-renderer-contract.

### Python world annotations §road:python-world-annotations

Port the ground plane and smart dimensions (§spec:ground-plane,
§spec:smart-dimensions), tested against `vectors/ground_plane.json` and
`vectors/smart_dimensions.json`. Depends on
§road:python-renderer-contract.

**Verify:** In `python/`, run `uv run pytest` and confirm every fixture
family in `vectors/` has a passing Python test, with the same tolerance
as its Dart test.

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives.

### Angular and radial dimensions §road:angular-radial-dimensions

The angular and radial cases of §spec:smart-dimensions, under the same
drafting convention as the point-to-point dimensions.

### Color ramp legend §road:color-ramp-legend

Gradient bar for scalar-to-color mappings (§spec:color-ramp-legend).
Blocked: how the gradient reaches the renderer is an open question in
§spec:color-ramp-legend. Unblocked when the spec settles it.
