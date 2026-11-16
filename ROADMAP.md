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

### Python overlay annotations §road:python-overlay-annotations

Port the scale bar and the navigation cube (§spec:scale-bar,
§spec:navigation-cube), tested against `vectors/scale_bar.json` and
`vectors/navigation_cube.json`.

### Python world annotations §road:python-world-annotations

Port the ground plane and smart dimensions (§spec:ground-plane,
§spec:smart-dimensions), tested against `vectors/ground_plane.json` and
`vectors/smart_dimensions.json`.

**Verify:** In `python/`, run `uv run pytest` and confirm every fixture
family in `vectors/` has a passing Python test, with the same tolerance
as its Dart test.

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives.

### Color ramp legend §road:color-ramp-legend

Gradient bar for scalar-to-color mappings (§spec:color-ramp-legend).
Blocked: how the gradient reaches the renderer is an open question in
§spec:color-ramp-legend. Unblocked when the spec settles it.
