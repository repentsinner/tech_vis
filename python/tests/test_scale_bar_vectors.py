"""The scale bar agrees with ``vectors/scale_bar.json``."""

from typing import Any

import pytest

from conftest import (
    TOLERANCE,
    assert_close,
    json_number_formatting,
    json_placement,
    json_vector3,
    load_vectors,
)
from tech_vis import CameraBasis, DisplayFormat, ScaleBarLayout, UnitSystem, tokens

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return load_vectors("scale_bar.json")


def _camera(c: Json) -> CameraBasis:
    return CameraBasis(
        position=json_vector3(c["position"]),
        forward=json_vector3(c["forward"]),
        right=json_vector3(c["right"]),
        up=json_vector3(c["up"]),
    )


def test_generated_from_the_current_style_version(fixture: Json) -> None:
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_at_target(fixture: Json) -> None:
    cases = fixture["ScaleBarLayout.atTarget"]
    assert cases, "no ScaleBarLayout.atTarget cases"
    for c in cases:
        name, given, want = c["name"], c["input"], c["output"]
        width, height = given["viewport"]
        bar = ScaleBarLayout.at_target(
            camera=_camera(given["camera"]),
            target=json_vector3(given["target"]),
            vertical_fov_radians=given["verticalFovRadians"],
            viewport_size=(float(width), float(height)),
            world_units=UnitSystem(given["worldUnits"]),
            display_format=DisplayFormat(given["format"]),
            placement=json_placement(given["placement"]),
            previous_step=given["previousStep"],
            numbers=json_number_formatting(given["numbers"]),
            min_tick_spacing_pixels=given["minTickSpacingPixels"],
            hysteresis=given["hysteresis"],
            label_height_pixels=given["labelHeightPixels"],
        )
        if want is None:
            assert bar is None, name
            continue
        assert bar is not None, name
        assert_close(bar.rect, want["rect"], f"{name} rect")
        assert_close(
            [bar.step, bar.tick_step, bar.start_x, bar.end_x, bar.baseline_y],
            [
                want["step"],
                want["tickStep"],
                want["startX"],
                want["endX"],
                want["baselineY"],
            ],
            f"{name} step, tick_step, start_x, end_x, baseline_y",
        )
        assert_close(bar.tick_xs, want["tickXs"], f"{name} tick_xs")
        assert bar.label.text == want["label"]["text"], f"{name} label"
        assert bar.label.height_pixels == pytest.approx(
            want["label"]["heightPixels"], rel=0, abs=TOLERANCE
        ), f"{name} label height"
        assert_close(bar.label_anchor, want["labelAnchor"], f"{name} label_anchor")
