"""Overlay placement agrees with the Dart reference and its golden vectors."""

import math

import pytest

from conftest import JSON_CORNERS, TOLERANCE, json_placement, load_vectors
from tech_vis import (
    ViewportCorner,
    ViewportOverlayKind,
    ViewportOverlayPlacement,
    ViewportRect,
)

VECTORS = "viewport_overlays.json"


@pytest.mark.parametrize(
    ("code", "corner"),
    [(0.0, "topLeft"), (1.0, "topRight"), (2.0, "bottomLeft"), (3.0, "bottomRight")],
)
def test_from_token_maps_codes(code, corner):
    assert ViewportCorner.from_token(code) is JSON_CORNERS[corner]


@pytest.mark.parametrize("code", [-1.0, 4.0, 0.5, math.nan, math.inf])
def test_from_token_rejects_non_codes(code):
    with pytest.raises(ValueError):
        ViewportCorner.from_token(code)


@pytest.mark.parametrize(
    ("corner", "is_right", "is_bottom"),
    [
        (ViewportCorner.TOP_LEFT, False, False),
        (ViewportCorner.TOP_RIGHT, True, False),
        (ViewportCorner.BOTTOM_LEFT, False, True),
        (ViewportCorner.BOTTOM_RIGHT, True, True),
    ],
)
def test_corner_edges(corner, is_right, is_bottom):
    assert (corner.is_right, corner.is_bottom) == (is_right, is_bottom)


def test_of_replaces_only_the_given_values():
    default = ViewportOverlayPlacement.of(ViewportOverlayKind.SCALE_BAR)
    got = ViewportOverlayPlacement.of(
        ViewportOverlayKind.SCALE_BAR,
        corner=ViewportCorner.TOP_LEFT,
        width_pixels=10.0,
    )
    assert got.corner is ViewportCorner.TOP_LEFT
    assert got.width_pixels == 10.0
    assert got.offset_x_pixels == default.offset_x_pixels
    assert got.offset_y_pixels == default.offset_y_pixels
    assert got.height_pixels == default.height_pixels


def test_vectors_of():
    for case in load_vectors(VECTORS)["ViewportOverlayPlacement.of"]:
        kind = ViewportOverlayKind(case["input"]["kind"])
        want = json_placement(case["output"])
        assert ViewportOverlayPlacement.of(kind) == want, case["name"]


def test_vectors_rect():
    for case in load_vectors(VECTORS)["ViewportOverlayPlacement.rect"]:
        placement = json_placement(case["input"]["placement"])
        got = placement.rect(tuple(case["input"]["viewport"]))
        assert isinstance(got, ViewportRect)
        want = case["output"]["rect"]
        assert got == pytest.approx(want, abs=TOLERANCE), case["name"]
