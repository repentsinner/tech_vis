"""Smart dimensions agree with the Dart reference's golden vectors."""

import math
from collections.abc import Callable
from typing import Any

import pytest

from conftest import (
    FAKE_CHARACTER_ASPECT,
    assert_world_primitive,
    fake_text_resolver,
    json_convention,
    json_leader_style,
    json_number_formatting,
    json_vector3,
    load_vectors,
)
from tech_vis import (
    CameraBasis,
    DimensionStyle,
    DisplayFormat,
    DraftingConvention,
    MultiAxisDimension,
    Primitive,
    RadialMeasure,
    UnitSystem,
    create_angular_dimension,
    create_dimension,
    create_radial_dimension,
    tokens,
)

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return load_vectors("smart_dimensions.json")


def _style(s: Json) -> DimensionStyle:
    return DimensionStyle(
        line_width=s["lineWidth"],
        witness_gap_pixels=s["witnessGapPixels"],
        witness_extension_pixels=s["witnessExtensionPixels"],
        offset_pixels=s["offsetPixels"],
        arrow_length_pixels=s["arrowLengthPixels"],
        arrow_width_pixels=s["arrowWidthPixels"],
        text_pixel_size=s["textPixelSize"],
        text_gap_pixels=s["textGapPixels"],
        alignment_tolerance=s["alignmentTolerance"],
        leader=json_leader_style(s["leader"]),
        arc_radius_pixels=s["arcRadiusPixels"],
        arc_segment_pixels=s["arcSegmentPixels"],
        angle_resolution_degrees=s["angleResolutionDegrees"],
    )


def _view(given: Json) -> dict[str, Any]:
    """Returns the camera arguments every factory shares, from a case input."""
    camera = given["camera"]
    width, height = camera["viewport"]
    return {
        "camera": CameraBasis.look_at(
            position=json_vector3(camera["position"]),
            target=json_vector3(camera["target"]),
            convention=json_convention(given["convention"]),
        ),
        "vertical_fov_radians": math.radians(camera["verticalFovDegrees"]),
        "viewport_size": (float(width), float(height)),
        "resolve_text": fake_text_resolver,
        "key": None,
        "drafting": DraftingConvention(given["drafting"]),
        "numbers": json_number_formatting(given["numbers"]),
        "style": _style(given["style"]),
    }


def _optional_vector(json_value: list[float] | None) -> Any:
    return None if json_value is None else json_vector3(json_value)


def _linear(given: Json) -> list[Primitive]:
    return create_dimension(
        start=json_vector3(given["from"]),
        end=json_vector3(given["to"]),
        display_format=DisplayFormat(given["format"]),
        world_units=UnitSystem(given["worldUnits"]),
        multi_axis=MultiAxisDimension(given["multiAxis"]),
        offset_direction=_optional_vector(given["offsetDirection"]),
        **_view(given),
    )


def _angular(given: Json) -> list[Primitive]:
    return create_angular_dimension(
        vertex=json_vector3(given["vertex"]),
        first=json_vector3(given["first"]),
        second=json_vector3(given["second"]),
        **_view(given),
    )


def _radial(given: Json) -> list[Primitive]:
    return create_radial_dimension(
        center=json_vector3(given["center"]),
        radius=float(given["radius"]),
        normal=json_vector3(given["normal"]),
        measure=RadialMeasure(given["measure"]),
        display_format=DisplayFormat(given["format"]),
        world_units=UnitSystem(given["worldUnits"]),
        direction=_optional_vector(given["direction"]),
        **_view(given),
    )


def test_generated_from_the_current_style_version(fixture: Json) -> None:
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_recorded_with_the_same_text_resolver(fixture: Json) -> None:
    aspect = fixture["textResolver"]["characterWidthPerHeight"]
    assert aspect == FAKE_CHARACTER_ASPECT


@pytest.mark.parametrize(
    ("family", "build"),
    [
        ("SmartDimensionFactory.create", _linear),
        ("SmartDimensionFactory.createAngular", _angular),
        ("SmartDimensionFactory.createRadial", _radial),
    ],
)
def test_family(
    fixture: Json, family: str, build: Callable[[Json], list[Primitive]]
) -> None:
    cases = fixture[family]
    assert cases, f"no {family} cases"
    conventions = {" ".join(c["input"]["convention"].values()) for c in cases}
    assert {"z right", "z left", "y right"} <= conventions
    drafting = {c["input"]["drafting"] for c in cases}
    assert drafting == {d.value for d in DraftingConvention}
    for c in cases:
        name = c["name"]
        primitives = build(c["input"])
        expected = c["output"]["primitives"]
        assert expected, f"{name} records no primitives"
        assert len(primitives) == len(expected), name
        for i, (actual, want) in enumerate(zip(primitives, expected, strict=True)):
            assert_world_primitive(actual, want, f"{name} [{i}]")
