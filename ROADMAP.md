# tech_vis — Roadmap

## Release plumbing §road:release-plumbing

Closes §spec:release.

### First publish §road:first-publish

Both registries need a first step that automation cannot take.

- Push a baseline `v0.1.0` tag before the tag ruleset exists. With no tag,
  the first release computes `1.0.0`. Push it before registering either
  publisher: the tag matches the publish trigger, and both manifests
  already say `0.1.0`.
- Publish `dart/` to pub.dev by hand once. Automated publishing can be
  enabled only on a package that exists.
- Register the PyPI pending publisher for `publish-pypi.yml`.
- Install the Flywheel App, store its id and key, and add the branch and
  tag rulesets.

Done when a merged `feat:` PR publishes both packages with no manual step.

## Shared layout §road:shared-layout

Closes §spec:golden-vectors and the layout half of §spec:python-package.

### Leader-line golden vectors §road:leader-vectors

Record fixtures for leader-line callout geometry, anchor alignment, and
the opacity ramp. Test the Dart implementation against them.

### Python leader-line layout §road:python-leader-line

Port the leader-line functions to Python. Test them against the same
fixtures. Depends on §road:leader-vectors.
