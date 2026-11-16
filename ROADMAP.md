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

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives.

### Color ramp legend §road:color-ramp-legend

Gradient bar for scalar-to-color mappings, its stops keyed by the app,
in `dart/lib/src/color_ramp_legend.dart` and its Python port
(§spec:color-ramp-legend).
