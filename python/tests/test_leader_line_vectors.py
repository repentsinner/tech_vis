"""The leader-line functions agree with the Dart reference's golden vectors."""

import json
from collections.abc import Sequence
from pathlib import Path
from typing import Any

import pytest

from tech_vis import (
    CalloutQuadrant,
    LeaderLineStyle,
    Vector3,
    callout_anchor_alignment,
    compute_callout_leader_geometry,
    compute_callout_opacity,
    tokens,
)

# The fixtures sit outside the package, so they exist in a repository checkout
# and are absent from an installed or unpacked distribution.
FIXTURE = Path(__file__).resolve().parents[2] / "vectors" / "leader_line.json"

# Absolute tolerance on every numeric output, in the function's own units.
TOLERANCE = 1e-9

pytestmark = pytest.mark.skipif(
    not FIXTURE.exists(), reason="vectors/ is outside the sdist"
)

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return json.loads(FIXTURE.read_text())


def _cases(fixture: Json, function: str) -> list[Json]:
    cases = fixture[function]
    assert cases, f"no {function} cases"
    return cases


def _vector3(json_value: Sequence[float]) -> Vector3:
    x, y, z = (float(c) for c in json_value)
    return (x, y, z)


def _style(s: Json) -> LeaderLineStyle:
    return LeaderLineStyle(
        line_width=s["lineWidth"],
        gap_pixels=s["gapPixels"],
        angled_length_pixels=s["angledLengthPixels"],
        horizontal_length_pixels=s["horizontalLengthPixels"],
        angle_degrees=s["angleDegrees"],
    )


def _assert_vector(
    actual: Sequence[float], expected: Sequence[float], reason: str
) -> None:
    assert len(actual) == len(expected), reason
    for i, (got, want) in enumerate(zip(actual, expected, strict=True)):
        assert got == pytest.approx(want, rel=0, abs=TOLERANCE), f"{reason}[{i}]"


def test_generated_from_the_current_style_version(fixture: Json):
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_compute_callout_leader_geometry(fixture: Json):
    for case in _cases(fixture, "computeCalloutLeaderGeometry"):
        name, given, want = case["name"], case["input"], case["output"]
        result = compute_callout_leader_geometry(
            anchor=_vector3(given["anchor"]),
            camera_right=_vector3(given["cameraRight"]),
            camera_up=_vector3(given["cameraUp"]),
            world_units_per_pixel=given["worldUnitsPerPixel"],
            quadrant=CalloutQuadrant(given["quadrant"]),
            style=_style(given["style"]),
        )
        _assert_vector(result.gap_end, want["gapEnd"], f"{name} gap_end")
        _assert_vector(result.elbow, want["elbow"], f"{name} elbow")
        _assert_vector(result.label_edge, want["labelEdge"], f"{name} label_edge")


def test_callout_anchor_alignment(fixture: Json):
    cases = _cases(fixture, "calloutAnchorAlignment")
    assert {c["input"]["quadrant"] for c in cases} == {q.value for q in CalloutQuadrant}
    for case in cases:
        _assert_vector(
            callout_anchor_alignment(CalloutQuadrant(case["input"]["quadrant"])),
            case["output"]["alignment"],
            case["name"],
        )


def test_compute_callout_opacity(fixture: Json):
    for case in _cases(fixture, "computeCalloutOpacity"):
        assert compute_callout_opacity(case["input"]["distance"]) == pytest.approx(
            case["output"]["opacity"], rel=0, abs=TOLERANCE
        ), case["name"]
