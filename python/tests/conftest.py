"""Shared test helpers."""

import json
from collections.abc import Sequence
from pathlib import Path

import pytest

from tech_vis import (
    BillboardContent,
    DecimalMarker,
    LeaderLineStyle,
    NumberFormatting,
    TextRequest,
    Vector3,
    ViewportCorner,
    ViewportOverlayPlacement,
)

# Absolute tolerance on a golden-vector number, in the function's own units
# (§spec:golden-vectors).
TOLERANCE = 1e-9

# The golden vectors sit outside the package, so they exist in a repository
# checkout and are absent from an installed or unpacked distribution.
VECTORS_DIR = Path(__file__).resolve().parents[2] / "vectors"


def load_vectors(name: str) -> dict:
    """Returns the parsed vector file ``name``, or skips when it is absent."""
    path = VECTORS_DIR / name
    if not path.exists():
        pytest.skip(f"{path.name} is outside the sdist")
    return json.loads(path.read_text())


def assert_close(
    actual: Sequence[float],
    expected: Sequence[float],
    reason: str = "",
    tolerance: float = TOLERANCE,
) -> None:
    """Asserts that two sequences of numbers agree within ``tolerance``."""
    assert len(actual) == len(expected), reason
    for i, (got, want) in enumerate(zip(actual, expected, strict=True)):
        assert got == pytest.approx(want, rel=0, abs=tolerance), f"{reason}[{i}]"


# Width of one stand-in character, as a fraction of the requested height. The
# Dart reference sizes text with the same stand-in, so content sizes agree.
FAKE_CHARACTER_ASPECT = 0.5


def fake_text_resolver(request: TextRequest) -> BillboardContent:
    """Sizes each character at half its height, and hands back the request."""
    return BillboardContent(
        value=request,
        width_pixels=len(request.text) * FAKE_CHARACTER_ASPECT * request.height_pixels,
        height_pixels=request.height_pixels,
    )


def json_vector3(json_value: Sequence[float]) -> Vector3:
    """Decodes a fixture's three-number vector."""
    x, y, z = (float(c) for c in json_value)
    return (x, y, z)


def json_leader_style(s: dict) -> LeaderLineStyle:
    """Decodes a fixture's leader-line style record."""
    return LeaderLineStyle(
        line_width=s["lineWidth"],
        gap_pixels=s["gapPixels"],
        angled_length_pixels=s["angledLengthPixels"],
        horizontal_length_pixels=s["horizontalLengthPixels"],
        angle_degrees=s["angleDegrees"],
    )


# Fixtures name viewport corners as the Dart enum does.
JSON_CORNERS = {
    "topLeft": ViewportCorner.TOP_LEFT,
    "topRight": ViewportCorner.TOP_RIGHT,
    "bottomLeft": ViewportCorner.BOTTOM_LEFT,
    "bottomRight": ViewportCorner.BOTTOM_RIGHT,
}


def json_placement(p: dict) -> ViewportOverlayPlacement:
    """Decodes a fixture's overlay placement record."""
    return ViewportOverlayPlacement(
        corner=JSON_CORNERS[p["corner"]],
        offset_x_pixels=p["offsetXPixels"],
        offset_y_pixels=p["offsetYPixels"],
        width_pixels=p["widthPixels"],
        height_pixels=p["heightPixels"],
    )


def json_number_formatting(n: dict) -> NumberFormatting:
    """Decodes a fixture's number-formatting record."""
    return NumberFormatting(
        decimal_marker=DecimalMarker(n["decimalMarker"]),
        show_leading_zero=n["showLeadingZero"],
    )
