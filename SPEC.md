# tech_vis — Specification

`tech_vis` is a renderer-agnostic toolkit for technical visualization:
annotated 3D scenes with leader-line callouts, coordinate frames, and
labeled bounding boxes. It ships as a Dart package and a Python package
that share one style.

## Repository layout §spec:layout

*Status: complete*

One repository holds the style and every implementation of it.

- `style/tokens.json` is the source of truth for the style.
- `dart/` is the Dart package root. `python/` is the Python package root.
- `tools/` holds repository tooling. It ships in neither package.
- Governance documents sit at the repository root and cover both packages.

Each package directory shall be self-contained: a published archive
cannot read outside its own root. Each therefore carries its own copy of
`LICENSE` and its own `README.md`.

*Why one repository*: the style is the product. Two repositories would
version the token file in one and consume it in the other, and the two
implementations would drift between releases.

## Style tokens §spec:style-tokens

*Status: complete*

The style is data. `style/tokens.json` names every constant that shapes
the look: leader-line geometry, line widths, label sizes, and the callout
opacity ramp.

- Each token has a `doc`, a `unit`, and exactly one of `value` and `alias`.
  An `alias` names another token and takes its value.
- `styleVersion` is an integer. Two implementations that report the same
  `styleVersion` shall produce the same layout from the same input.
- `tools/gen_tokens.py` generates `dart/lib/src/style_tokens.g.dart` and
  `python/src/tech_vis/tokens.py`. The generated modules are committed.
- CI shall fail when a generated module differs from the generator's output.
- Each package's tests compare its generated module against
  `style/tokens.json`. The tests skip where the file is absent, as it is in
  a published archive.

*Why generate, not load*: the Dart constants are `const` and appear as
default values in `const` constructors. A value read from JSON at runtime
cannot be `const`. A published package also cannot reach `style/` from
inside its archive.

*Why commit the output*: a consumer installs a package, not the
repository. The generator never runs on a consumer's machine.

## Golden vectors §spec:golden-vectors

*Status: not started*

Layout functions are ported by hand between languages. A shared set of
language-neutral fixtures shall pin the ports to each other: each fixture
records a function's inputs and its expected outputs, and each package
tests its implementation against every fixture.

## Dart package §spec:dart-package

*Status: in progress*

Pure Dart. No Flutter dependency, so it runs in any Dart program.
It provides scene object types, coordinate frames, bounding boxes,
leader-line callout geometry, and screen-space conversions.

The public API still carries vocabulary from the application it was
extracted from. A generic toolkit shall name nothing from a consumer's
domain.

## Python package §spec:python-package

*Status: in progress*

Pure Python, no runtime dependencies. It provides the style tokens.
Layout functions arrive with §spec:golden-vectors, which is what makes a
port checkable.

## Versioning and release §spec:release

*Status: in progress*

Both packages share one version and release together.

- Flywheel cuts one `v<version>` tag per release from conventional-commit
  PR titles, and writes the version into `dart/pubspec.yaml`,
  `python/pyproject.toml`, and `dart/CHANGELOG.md`. pub.dev requires the
  package changelog to name the published version; the release notes
  themselves live in the root `CHANGELOG.md`.
- The tag push triggers both publish workflows. pub.dev and PyPI each
  authenticate the workflow through OIDC. No registry token is stored.
- `styleVersion` is independent of the package version. It changes only
  when a token change alters layout.

*Why lockstep*: Flywheel has one tag namespace per repository. A shared
version also states the intent — a style change is one release of both
packages.

*Tradeoff accepted*: a change to one package releases the other with no
difference in content.
