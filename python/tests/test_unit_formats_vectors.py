"""The display formats agree with the Dart reference's golden vectors."""

import json
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

from tech_vis import DecimalMarker, DisplayFormat, NumberFormatting, tokens

# The fixtures sit outside the package, so they exist in a repository checkout
# and are absent from an installed or unpacked distribution.
FIXTURE = Path(__file__).resolve().parents[2] / "vectors" / "unit_formats.json"

# Absolute tolerance on every numeric output, in the format's base unit.
TOLERANCE = 1e-9

pytestmark = pytest.mark.skipif(
    not FIXTURE.exists(), reason="vectors/ is outside the sdist"
)

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return json.loads(FIXTURE.read_text())


def _expect_steps(
    recorded: Json, query: Callable[[DisplayFormat, float], float | None]
) -> None:
    assert set(recorded) == {f.value for f in DisplayFormat}
    for name, cases in recorded.items():
        display_format = DisplayFormat(name)
        assert cases, f"no {name} cases"
        for c in cases:
            length = float(c["length"])
            actual = query(display_format, length)
            reason = f"{name} at {length}"
            if c["step"] is None:
                assert actual is None, reason
            else:
                assert actual == pytest.approx(c["step"], abs=TOLERANCE), reason


def test_generated_from_the_current_style_version(fixture: Json) -> None:
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_scale_bar_step_at_most(fixture: Json) -> None:
    _expect_steps(
        fixture["scaleBarStepAtMost"], lambda f, x: f.scale_bar_step_at_most(x)
    )


def test_grid_step_at_least(fixture: Json) -> None:
    _expect_steps(fixture["gridStepAtLeast"], lambda f, x: f.grid_step_at_least(x))


def test_grid_step_above(fixture: Json) -> None:
    _expect_steps(fixture["gridStepAbove"], lambda f, x: f.grid_step_above(x))


def test_format_labels(fixture: Json) -> None:
    cases = fixture["formatLabels"]
    assert cases, "no formatLabels cases"
    for c in cases:
        given = c["input"]
        numbers = NumberFormatting(
            decimal_marker=DecimalMarker(given["numbers"]["decimalMarker"]),
            show_leading_zero=given["numbers"]["showLeadingZero"],
        )
        step = given["step"]
        labels = DisplayFormat(given["format"]).format_labels(
            [float(v) for v in given["values"]],
            step=None if step is None else float(step),
            numbers=numbers,
        )
        assert labels == c["output"]["labels"], c["name"]
