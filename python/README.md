# tech_vis

Technical visualization primitives for annotated 3D scenes. This is the
Python package; a Dart package of the same name and version shares its
style tokens. Both come from
[one repository](https://github.com/repentsinner/tech_vis).

## Installation

```bash
uv add tech_vis
```

## Usage

```python
from tech_vis import tokens

gap_px = tokens.CALLOUT_GAP_PIXELS
every_token = tokens.ALL
```

`tokens.STYLE_VERSION` identifies the token set. Two implementations that
report the same style version produce the same layout.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
