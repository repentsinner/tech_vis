"""The color ramp legend agrees with ``vectors/color_ramp_legend.json``."""

from typing import Any

import pytest

from conftest import (
    TOLERANCE,
    assert_close,
    json_number_formatting,
    json_placement,
    load_vectors,
)
from tech_vis import (
    ColorRampLegendLayout,
    ColorRampOrientation,
    ColorRampStop,
    tokens,
)

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return load_vectors("color_ramp_legend.json")


def _stops(stops: list[Json]) -> tuple[ColorRampStop, ...]:
    return tuple(ColorRampStop(position=s["position"], key=s["key"]) for s in stops)


def test_generated_from_the_current_style_version(fixture: Json) -> None:
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_for_range(fixture: Json) -> None:
    cases = fixture["ColorRampLegendLayout.forRange"]
    assert cases, "no ColorRampLegendLayout.forRange cases"
    for c in cases:
        name, given, want = c["name"], c["input"], c["output"]
        width, height = given["viewport"]
        legend = ColorRampLegendLayout.for_range(
            min_value=given["minValue"],
            max_value=given["maxValue"],
            stops=_stops(given["stops"]),
            viewport_size=(float(width), float(height)),
            orientation=ColorRampOrientation(given["orientation"]),
            placement=json_placement(given["placement"]),
            tick_interval=given["tickInterval"],
            unit=given["unit"],
            numbers=json_number_formatting(given["numbers"]),
            bar_thickness_pixels=given["barThicknessPixels"],
            min_tick_spacing_pixels=given["minTickSpacingPixels"],
            label_gap_pixels=given["labelGapPixels"],
            label_height_pixels=given["labelHeightPixels"],
        )
        assert_close(legend.rect, want["rect"], f"{name} rect")
        assert_close(legend.bar_rect, want["barRect"], f"{name} bar_rect")
        assert legend.orientation.value == want["orientation"], name
        assert legend.stops == _stops(want["stops"]), f"{name} stops"
        assert legend.tick_interval == pytest.approx(
            want["tickInterval"], rel=0, abs=TOLERANCE
        ), f"{name} tick_interval"
        assert_close(
            legend.label_alignment, want["labelAlignment"], f"{name} label_alignment"
        )
        assert len(legend.ticks) == len(want["ticks"]), f"{name} ticks"
        for i, (tick, t) in enumerate(zip(legend.ticks, want["ticks"], strict=True)):
            assert_close(
                [tick.value, tick.position, tick.label.height_pixels],
                [t["value"], t["position"], t["label"]["heightPixels"]],
                f"{name} tick {i} value, position, label height",
            )
            assert tick.label.text == t["label"]["text"], f"{name} tick {i}"
            assert_close(
                tick.label_anchor, t["labelAnchor"], f"{name} tick {i} label_anchor"
            )
