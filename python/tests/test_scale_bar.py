"""The scale bar agrees with the Dart reference's unit tests."""

import math
from dataclasses import dataclass

import pytest

from conftest import TOLERANCE
from tech_vis import (
    CameraBasis,
    DecimalMarker,
    DisplayFormat,
    NumberFormatting,
    ScaleBarLayout,
    TextRequest,
    UnitSystem,
    Vector3,
    ViewportCorner,
    ViewportOverlayKind,
    ViewportOverlayPlacement,
    tokens,
)

# A field of view whose half-angle tangent is 0.5, so one pixel at depth d in
# a viewport h pixels tall spans d / h world units.
_FOV = 2 * math.atan(0.5)

_VIEWPORT = (1280.0, 720.0)

_ORIGIN: Vector3 = (0.0, 0.0, 0.0)


def _camera(depth: float) -> CameraBasis:
    """Returns a camera on +Z looking at the origin, ``depth`` away."""
    return CameraBasis(
        position=(0.0, 0.0, depth),
        forward=(0.0, 0.0, -1.0),
        right=(1.0, 0.0, 0.0),
        up=(0.0, 1.0, 0.0),
    )


def _depth_for(world_units_per_pixel: float) -> float:
    """Returns the depth at which one pixel at the origin spans the size."""
    return world_units_per_pixel * _VIEWPORT[1]


def _bar(world_units_per_pixel: float, **kwargs) -> ScaleBarLayout | None:
    kwargs.setdefault("world_units", UnitSystem.METRIC)
    kwargs.setdefault("display_format", DisplayFormat.METRIC)
    return ScaleBarLayout.at_target(
        camera=_camera(_depth_for(world_units_per_pixel)),
        target=_ORIGIN,
        vertical_fov_radians=_FOV,
        viewport_size=_VIEWPORT,
        **kwargs,
    )


@dataclass(frozen=True)
class _Case:
    name: str
    world_units_per_pixel: float
    step: float
    tick_step: float
    start_x: float
    label: str
    world_units: UnitSystem = UnitSystem.METRIC
    display_format: DisplayFormat = DisplayFormat.METRIC
    placement: ViewportOverlayPlacement | None = None
    previous_step: float | None = None
    numbers: NumberFormatting = NumberFormatting()


_CASES = [
    _Case("one mm per pixel fits 100 mm in 20 mm parts", 1, 100, 20, 16, "100 mm"),
    _Case(
        "ten mm per pixel fits 1000 mm below the meter promotion",
        10,
        1000,
        200,
        16,
        "1000 mm",
    ),
    _Case(
        "mm world in fractional inch fits 6 in in 1 in parts",
        1,
        6,
        1,
        16,
        '6"',
        display_format=DisplayFormat.FRACTIONAL_INCH,
    ),
    _Case(
        "a part that does not divide the step is skipped",
        0.005,
        0.5,
        0.1,
        16,
        "0,5 mm",
        numbers=NumberFormatting(decimal_marker=DecimalMarker.COMMA),
    ),
    _Case(
        "a right corner grows the bar from the right edge",
        1,
        100,
        20,
        1280 - 16 - 100,
        "100 mm",
        placement=ViewportOverlayPlacement.of(
            ViewportOverlayKind.SCALE_BAR, corner=ViewportCorner.BOTTOM_RIGHT
        ),
    ),
    _Case(
        "keeps a shorter previous step until a longer one clears the margin",
        1.3,
        100,
        50,
        16,
        "100 mm",
        previous_step=100,
    ),
    _Case(
        "adopts a longer step once it clears the margin",
        1.4,
        200,
        50,
        16,
        "200 mm",
        previous_step=100,
    ),
    _Case(
        "keeps a longer previous step while it still fits",
        1.3,
        200,
        50,
        16,
        "200 mm",
        previous_step=200,
    ),
    _Case(
        "drops a previous step that no longer fits",
        1.2,
        100,
        20,
        16,
        "100 mm",
        previous_step=200,
    ),
    _Case(
        "ignores a previous value that is not a step of the format",
        1.3,
        200,
        50,
        16,
        "200 mm",
        previous_step=150,
    ),
]


@pytest.mark.parametrize("c", _CASES, ids=[c.name for c in _CASES])
def test_at_target(c: _Case) -> None:
    placement = c.placement or ViewportOverlayPlacement.of(
        ViewportOverlayKind.SCALE_BAR
    )
    bar = _bar(
        c.world_units_per_pixel,
        world_units=c.world_units,
        display_format=c.display_format,
        placement=c.placement,
        previous_step=c.previous_step,
        numbers=c.numbers,
    )
    assert bar is not None
    rect = placement.rect(_VIEWPORT)
    pixels_per_unit = 1 / c.world_units.convert_to(
        c.world_units_per_pixel, c.display_format.unit_system
    )
    length = c.step * pixels_per_unit
    parts = round(c.step / c.tick_step)

    def close(x: float) -> object:
        return pytest.approx(x, rel=0, abs=TOLERANCE)

    assert bar.rect == rect
    assert bar.step == close(c.step)
    assert bar.tick_step == close(c.tick_step)
    assert bar.start_x == close(c.start_x)
    assert bar.end_x == close(c.start_x + length)
    assert bar.baseline_y == rect.bottom
    assert len(bar.tick_xs) == parts + 1
    for i, x in enumerate(bar.tick_xs):
        assert x == close(c.start_x + i * length / parts)
    assert bar.label == TextRequest(
        text=c.label, height_pixels=tokens.SCALE_BAR_LABEL_HEIGHT_PIXELS
    )
    assert bar.label_anchor[0] == close(c.start_x + length / 2)
    assert bar.label_anchor[1] == rect.top
    assert length <= rect.right - rect.left + TOLERANCE


def test_is_none_for_a_target_behind_the_camera() -> None:
    bar = ScaleBarLayout.at_target(
        camera=_camera(1),
        target=(0.0, 0.0, 2.0),
        vertical_fov_radians=_FOV,
        viewport_size=_VIEWPORT,
        world_units=UnitSystem.METRIC,
        display_format=DisplayFormat.METRIC,
    )
    assert bar is None


def test_is_none_when_even_the_smallest_step_is_longer_than_the_bar() -> None:
    assert _bar(0.001, display_format=DisplayFormat.FRACTIONAL_INCH) is None


def test_a_wider_tick_spacing_coarsens_the_parts() -> None:
    bar = _bar(1, min_tick_spacing_pixels=40)
    assert bar is not None
    assert bar.tick_step == pytest.approx(50, rel=0, abs=TOLERANCE)


def test_a_bar_too_short_for_any_part_keeps_only_its_end_ticks() -> None:
    bar = _bar(1, min_tick_spacing_pixels=200)
    assert bar is not None
    assert bar.tick_step == pytest.approx(100, rel=0, abs=TOLERANCE)
    assert len(bar.tick_xs) == 2


@pytest.mark.parametrize(
    ("spacing", "hysteresis"),
    [
        pytest.param(0.0, 0.1, id="zero tick spacing"),
        pytest.param(math.inf, 0.1, id="infinite tick spacing"),
        pytest.param(16.0, -0.1, id="negative hysteresis"),
        pytest.param(16.0, 1.0, id="hysteresis of one"),
        pytest.param(16.0, math.nan, id="NaN hysteresis"),
    ],
)
def test_rejects_invalid_settings(spacing: float, hysteresis: float) -> None:
    with pytest.raises(ValueError):
        _bar(1, min_tick_spacing_pixels=spacing, hysteresis=hysteresis)
