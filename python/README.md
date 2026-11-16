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

A `DisplayFormat` labels measurements and picks scale-bar and grid steps.
Every length it takes or returns is in its unit system's base unit, so
convert a world length with `UnitSystem.convert_to` first:

```python
from tech_vis import DisplayFormat, NumberFormatting, DecimalMarker

DisplayFormat.METRIC.format_labels([0, 5000, 10000], step=5000)
# ['0 m', '5 m', '10 m']
DisplayFormat.DECIMAL_INCH.format_labels(
    [2.5], numbers=NumberFormatting(decimal_marker=DecimalMarker.COMMA)
)
# ['2,5 in']
DisplayFormat.FRACTIONAL_INCH.grid_step_above(1)  # 12.0
```

`tokens.STYLE_VERSION` identifies the token set. Two implementations that
report the same style version produce the same layout.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
