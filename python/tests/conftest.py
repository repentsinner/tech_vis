"""Shared test helpers."""

import json
from collections.abc import Iterable, Sequence
from pathlib import Path

import pytest

from tech_vis import (
    BillboardContent,
    BillboardPrimitive,
    CoordinateConvention,
    CoplanarOrientation,
    DecimalMarker,
    Handedness,
    LeaderLineStyle,
    LinePrimitive,
    NumberFormatting,
    Primitive,
    SpatialAxis,
    TextRequest,
    Vector3,
    ViewerFacingOrientation,
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


def json_convention(c: dict) -> CoordinateConvention:
    """Decodes a fixture's ``{up, handedness}`` convention record."""
    return CoordinateConvention(
        up=SpatialAxis(c["up"]), handedness=Handedness(c["handedness"])
    )


Y_UP_RIGHT = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.RIGHT)
Y_UP_LEFT = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.LEFT)
Z_UP_RIGHT = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.RIGHT)
Z_UP_LEFT = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.LEFT)


def assert_world_primitive(actual: Primitive, want: dict, reason: str) -> None:
    """Asserts that a world-space line or billboard matches its fixture record.

    The ground-plane and smart-dimension families record their primitives
    this way: numbers within ``TOLERANCE``, keys and text exactly.
    """
    assert actual.key == want["key"], f"{reason} key"
    assert actual.opacity == pytest.approx(want["opacity"], rel=0, abs=TOLERANCE), (
        f"{reason} opacity"
    )
    if isinstance(actual, LinePrimitive):
        assert want["type"] == "line", reason
        assert_close(actual.start, want["start"], f"{reason} start")
        assert_close(actual.end, want["end"], f"{reason} end")
        assert_close([actual.width_pixels], [want["widthPixels"]], f"{reason} width")
        return
    assert isinstance(actual, BillboardPrimitive), f"{reason}: {actual!r}"
    assert want["type"] == "billboard", reason
    assert_close(actual.anchor, want["anchor"], f"{reason} anchor")
    assert_close(actual.alignment, want["alignment"], f"{reason} alignment")
    orientation = want["orientation"]
    if isinstance(actual.orientation, CoplanarOrientation):
        assert orientation["type"] == "coplanar", reason
        assert_close(actual.orientation.normal, orientation["normal"], f"{reason} n")
        assert_close(actual.orientation.right, orientation["right"], f"{reason} r")
    else:
        assert isinstance(actual.orientation, ViewerFacingOrientation), reason
        assert orientation["type"] == "viewerFacing", reason
    offset = want["offset"]
    if offset is None:
        assert actual.offset is None, f"{reason} offset"
    else:
        assert actual.offset is not None, f"{reason} offset"
        assert_close(
            actual.offset.direction, offset["direction"], f"{reason} offset direction"
        )
        assert_close(
            [actual.offset.pixels], [offset["pixels"]], f"{reason} offset pixels"
        )
    request = want["textRequest"]
    assert actual.content.value == TextRequest(
        text=request["text"], height_pixels=request["heightPixels"]
    ), f"{reason} text"
    assert_close(
        [actual.content.width_pixels, actual.content.height_pixels],
        want["contentSize"],
        f"{reason} content size",
    )


def lines_of(primitives: Iterable[Primitive]) -> list[LinePrimitive]:
    """Returns the lines among ``primitives``, in order."""
    return [p for p in primitives if isinstance(p, LinePrimitive)]


def billboards_of(primitives: Iterable[Primitive]) -> list[BillboardPrimitive]:
    """Returns the billboards among ``primitives``, in order."""
    return [p for p in primitives if isinstance(p, BillboardPrimitive)]


def texts_of(primitives: Iterable[Primitive]) -> list[str]:
    """Returns the text of each text-request billboard among ``primitives``."""
    texts = []
    for b in billboards_of(primitives):
        assert isinstance(b.content.value, TextRequest)
        texts.append(b.content.value.text)
    return texts
