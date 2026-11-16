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

## Measurement and overlays §road:measurement-and-overlays

Closes §spec:unit-system and §spec:viewport-overlays. Both are consumed by
§road:annotation-primitives, whose workstreams name the dependency.

### Measurement formats §road:measurement-formats

Format measurements in the metric, decimal-inch, and fractional-inch
display formats, with each format's scale-bar and grid step sequences,
one unit per label set, and the app's decimal marker and leading-zero
choice, in `dart/lib/src/unit_system.dart` (§spec:unit-system).

### Viewport overlays §road:viewport-overlays

Describe an overlay in viewport pixels, anchored to a corner with an
offset, its default corner, offset, and size held as style tokens the
app may override, in a new `dart/lib/src/viewport_overlay.dart`
(§spec:viewport-overlays).

**Verify:** In `dart/`, format 1500 mm, 0.125 in, and 40.5 in in each
display format and confirm the labels match §spec:unit-system, including
`3' 4 1/2"` for fractional inch. Build an overlay with no overrides and
confirm its corner, offset, and size are the token defaults, then
override each and confirm only that value changes.

## Annotation primitives §road:annotation-primitives

Closes §spec:annotation-primitives. Every workstream here emits the
typed primitives.

### Smart dimensions §road:smart-dimensions

Point-to-point dimensions under the app's drafting convention
(§spec:smart-dimensions, §spec:drafting-convention). Depends on
§road:measurement-formats.

### Ground plane §road:ground-plane

Adaptive grid with a major/minor hierarchy (§spec:ground-plane). Depends
on §road:measurement-formats.

### Scale bar §road:scale-bar

Screen-space ruler with adaptive subdivision (§spec:scale-bar). Depends
on §road:measurement-formats and §road:viewport-overlays.

### Color ramp legend §road:color-ramp-legend

Gradient bar for scalar-to-color mappings (§spec:color-ramp-legend).
Depends on §road:viewport-overlays. Blocked: how the gradient reaches the
renderer is an open question in §spec:color-ramp-legend. Unblocked when
the spec settles it.

### Navigation cube §road:nav-cube

Passive orientation indicator whose Top face follows the declared up
axis (§spec:navigation-cube). Depends on §road:viewport-overlays.
