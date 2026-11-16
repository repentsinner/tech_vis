"""The ground grid agrees with the Dart reference's golden vectors."""

import math
from typing import Any

import pytest

from conftest import (
    TOLERANCE,
    assert_close,
    assert_world_primitive,
    fake_text_resolver,
    json_convention,
    json_vector3,
    load_vectors,
)
from tech_vis import (
    CameraBasis,
    CircularGroundPatch,
    DisplayFormat,
    GroundGrid,
    GroundGridStyle,
    GroundPatch,
    RectangularGroundPatch,
    UnitSystem,
    create_ground_grid,
    ground_minor_step,
    tokens,
)

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return load_vectors("ground_plane.json")


def _optional(value: float | None) -> float | None:
    return None if value is None else float(value)


def _patch(p: Json) -> GroundPatch:
    if p["shape"] == "rectangle":
        return RectangularGroundPatch(
            half_extent_u=p["halfExtentU"], half_extent_v=p["halfExtentV"]
        )
    assert p["shape"] == "circle", p
    return CircularGroundPatch(radius=p["radius"])


def _assert_patch(actual: GroundPatch, want: Json, reason: str) -> None:
    """Asserts that ``actual`` matches the recorded patch ``want``."""
    if isinstance(actual, RectangularGroundPatch):
        assert want["shape"] == "rectangle", reason
        assert_close(
            (actual.half_extent_u, actual.half_extent_v),
            (want["halfExtentU"], want["halfExtentV"]),
            f"{reason} half extents",
        )
    else:
        assert want["shape"] == "circle", reason
        assert_close((actual.radius,), (want["radius"],), f"{reason} radius")


def _style(s: Json) -> GroundGridStyle:
    return GroundGridStyle(
        min_line_spacing_pixels=s["minLineSpacingPixels"],
        step_margin=s["stepMargin"],
        max_lines_per_axis=s["maxLinesPerAxis"],
        minor_line_width=s["minorLineWidth"],
        major_line_width=s["majorLineWidth"],
        label_pixel_size=s["labelPixelSize"],
    )


def _build(given: Json) -> GroundGrid:
    convention = json_convention(given["convention"])
    camera = given["camera"]
    target = json_vector3(camera["target"])
    return create_ground_grid(
        convention=convention,
        patch=_patch(given["patch"]),
        display_format=DisplayFormat(given["format"]),
        world_units=UnitSystem(given["worldUnits"]),
        camera=CameraBasis.look_at(
            position=json_vector3(camera["position"]),
            target=target,
            convention=convention,
        ),
        target=target,
        vertical_fov_radians=math.radians(camera["verticalFovDegrees"]),
        viewport_height=camera["viewportHeight"],
        resolve_text=fake_text_resolver,
        minor_key="minor",
        major_key="major",
        label_key="label",
        origin=json_vector3(given["origin"]),
        previous_minor_step=_optional(given["previousMinorStep"]),
        style=_style(given["style"]),
    )


def test_generated_from_the_current_style_version(fixture: Json) -> None:
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_minor_step(fixture: Json) -> None:
    cases = fixture["GroundPlaneFactory.minorStep"]
    assert cases, "no minorStep cases"
    for c in cases:
        given = c["input"]
        step = ground_minor_step(
            display_format=DisplayFormat(given["format"]),
            minimum_spacing=float(given["minimumSpacing"]),
            previous_step=_optional(given["previousStep"]),
            margin=float(given["margin"]),
        )
        want = c["output"]["step"]
        assert step == pytest.approx(want, rel=0, abs=TOLERANCE), c["name"]


def test_create(fixture: Json) -> None:
    cases = fixture["GroundPlaneFactory.create"]
    conventions = {" ".join(c["input"]["convention"].values()) for c in cases}
    assert {"z right", "z left", "y right", "y left"} <= conventions
    for c in cases:
        name = c["name"]
        grid = _build(c["input"])
        output = c["output"]
        assert grid.minor_step == pytest.approx(
            output["minorStep"], rel=0, abs=TOLERANCE
        ), f"{name} minorStep"
        assert grid.major_step == pytest.approx(
            output["majorStep"], rel=0, abs=TOLERANCE
        ), f"{name} majorStep"
        expected = output["primitives"]
        assert len(grid.primitives) == len(expected), name
        for i, (actual, want) in enumerate(zip(grid.primitives, expected, strict=True)):
            assert_world_primitive(actual, want, f"{name} [{i}]")
        fade = output["fade"]
        assert_close(grid.fade.center, fade["center"], f"{name} center")
        assert_close(grid.fade.u, fade["u"], f"{name} u")
        assert_close(grid.fade.v, fade["v"], f"{name} v")
        _assert_patch(grid.fade.patch, fade["patch"], f"{name} patch")
