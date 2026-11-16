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

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives.

### Smart dimensions §road:smart-dimensions

Point-to-point dimensions under the app's drafting convention
(§spec:smart-dimensions, §spec:drafting-convention).

### Color ramp legend §road:color-ramp-legend

Gradient bar for scalar-to-color mappings (§spec:color-ramp-legend).
Blocked: how the gradient reaches the renderer is an open question in
§spec:color-ramp-legend. Unblocked when the spec settles it.
