"""The color ramp legend agrees with the Dart reference's unit tests."""

import math
from dataclasses import dataclass, field

import pytest

from conftest import TOLERANCE, assert_close
from tech_vis import (
    ColorRampLegendLayout,
    ColorRampOrientation,
    ColorRampStop,
    DecimalMarker,
    NumberFormatting,
    ViewportCorner,
    ViewportOverlayKind,
    ViewportOverlayPlacement,
    format_number_label,
    tokens,
)

_VIEWPORT = (1280.0, 720.0)

_STOPS = (
    ColorRampStop(position=0, key="cold"),
    ColorRampStop(position=0.5, key="mild"),
    ColorRampStop(position=1, key="hot"),
)

_COMMA = NumberFormatting(decimal_marker=DecimalMarker.COMMA, show_leading_zero=False)

_WIDE_BOTTOM_LEFT = ViewportOverlayPlacement(
    corner=ViewportCorner.BOTTOM_LEFT,
    offset_x_pixels=16,
    offset_y_pixels=16,
    width_pixels=200,
    height_pixels=40,
)

# The default placement resolves to (1216, 504, 1264, 704) in a 1280 x 720
# viewport, so the vertical bar stands 200 px tall on its right edge.
_DEFAULT_BAR = (1252.0, 504.0, 1264.0, 704.0)


@dataclass(frozen=True)
class _Case:
    name: str
    min_value: float
    max_value: float
    interval: float
    values: list[float]
    labels: list[str]
    first_anchor: list[float]
    orientation: ColorRampOrientation = ColorRampOrientation.VERTICAL
    placement: ViewportOverlayPlacement | None = None
    tick_interval: float | None = None
    unit: str | None = None
    numbers: NumberFormatting = field(default_factory=NumberFormatting)
    bar_rect: tuple[float, ...] = _DEFAULT_BAR
    alignment: tuple[float, float] = (1.0, 0.5)


_CASES = [
    _Case(
        name="default vertical legend snaps 0 to 100 to steps of 20",
        min_value=0,
        max_value=100,
        unit="°C",
        interval=20,
        values=[0, 20, 40, 60, 80, 100],
        labels=["0 °C", "20", "40", "60", "80", "100 °C"],
        first_anchor=[1248, 704],
    ),
    _Case(
        name="a range off the interval ticks only its multiples",
        min_value=-12.5,
        max_value=37.5,
        unit="m/s",
        interval=10,
        values=[-10, 0, 10, 20, 30],
        labels=["-10 m/s", "0", "10", "20", "30 m/s"],
        first_anchor=[1248, 694],
    ),
    _Case(
        name="an app interval replaces the automatic one",
        min_value=0,
        max_value=100,
        tick_interval=25,
        interval=25,
        values=[0, 25, 50, 75, 100],
        labels=["0", "25", "50", "75", "100"],
        first_anchor=[1248, 704],
    ),
    _Case(
        name="fractional values share the interval decimals",
        min_value=0,
        max_value=1,
        interval=0.2,
        values=[0, 0.2, 0.4, 0.6000000000000001, 0.8, 1],
        labels=["0", "0.2", "0.4", "0.6", "0.8", "1"],
        first_anchor=[1248, 704],
    ),
    _Case(
        name="comma and no leading zero",
        min_value=0,
        max_value=1,
        numbers=_COMMA,
        interval=0.2,
        values=[0, 0.2, 0.4, 0.6000000000000001, 0.8, 1],
        labels=["0", ",2", ",4", ",6", ",8", "1"],
        first_anchor=[1248, 704],
    ),
    _Case(
        name="a range end just short of a multiple keeps its tick",
        min_value=0,
        max_value=0.3,
        tick_interval=0.1,
        interval=0.1,
        values=[0, 0.1, 0.2, 0.30000000000000004],
        labels=["0", "0.1", "0.2", "0.3"],
        first_anchor=[1248, 704],
    ),
    _Case(
        name="an interval longer than the range leaves no ticks",
        min_value=0.1,
        max_value=0.9,
        tick_interval=1,
        unit="K",
        interval=1,
        values=[],
        labels=[],
        first_anchor=[],
    ),
    _Case(
        name="a lone tick carries the unit once",
        min_value=15,
        max_value=35,
        tick_interval=20,
        unit="kPa",
        interval=20,
        values=[20],
        labels=["20 kPa"],
        first_anchor=[1248, 654],
    ),
    _Case(
        name="vertical in a left corner labels the bar right side",
        min_value=0,
        max_value=100,
        placement=ViewportOverlayPlacement.of(
            ViewportOverlayKind.COLOR_RAMP_LEGEND, corner=ViewportCorner.TOP_LEFT
        ),
        bar_rect=(16, 16, 28, 216),
        interval=20,
        values=[0, 20, 40, 60, 80, 100],
        labels=["0", "20", "40", "60", "80", "100"],
        first_anchor=[32, 216],
        alignment=(0.0, 0.5),
    ),
    _Case(
        name="horizontal in a bottom corner labels above the bar",
        min_value=0,
        max_value=100,
        orientation=ColorRampOrientation.HORIZONTAL,
        placement=_WIDE_BOTTOM_LEFT,
        unit="%",
        bar_rect=(16, 692, 216, 704),
        interval=20,
        values=[0, 20, 40, 60, 80, 100],
        labels=["0 %", "20", "40", "60", "80", "100 %"],
        first_anchor=[16, 688],
        alignment=(0.5, 0.0),
    ),
    _Case(
        name="horizontal in a top corner labels below the bar",
        min_value=0,
        max_value=100,
        orientation=ColorRampOrientation.HORIZONTAL,
        placement=ViewportOverlayPlacement.of(
            ViewportOverlayKind.COLOR_RAMP_LEGEND,
            corner=ViewportCorner.TOP_RIGHT,
            width_pixels=200,
            height_pixels=40,
        ),
        bar_rect=(1064, 16, 1264, 28),
        interval=20,
        values=[0, 20, 40, 60, 80, 100],
        labels=["0", "20", "40", "60", "80", "100"],
        first_anchor=[1064, 32],
        alignment=(0.5, 1.0),
    ),
]


def _legend(**kwargs) -> ColorRampLegendLayout:
    kwargs.setdefault("min_value", 0)
    kwargs.setdefault("max_value", 100)
    kwargs.setdefault("stops", _STOPS)
    return ColorRampLegendLayout.for_range(viewport_size=_VIEWPORT, **kwargs)


@pytest.mark.parametrize("c", _CASES, ids=lambda c: c.name)
def test_for_range(c: _Case) -> None:
    legend = ColorRampLegendLayout.for_range(
        min_value=c.min_value,
        max_value=c.max_value,
        stops=_STOPS,
        viewport_size=_VIEWPORT,
        orientation=c.orientation,
        placement=c.placement,
        tick_interval=c.tick_interval,
        unit=c.unit,
        numbers=c.numbers,
    )
    assert_close(legend.bar_rect, c.bar_rect, "bar_rect")
    assert legend.orientation is c.orientation
    assert legend.tick_interval == pytest.approx(c.interval, rel=0, abs=TOLERANCE)
    assert_close([t.value for t in legend.ticks], c.values, "values")
    assert [t.label.text for t in legend.ticks] == c.labels
    assert_close(legend.label_alignment, c.alignment, "alignment")
    if legend.ticks:
        assert_close(legend.ticks[0].label_anchor, c.first_anchor, "first anchor")


def test_a_tick_position_runs_from_the_minimum_end_of_the_bar() -> None:
    legend = _legend(min_value=-12.5, max_value=37.5)
    assert_close(
        [t.position for t in legend.ticks], [0.05, 0.25, 0.45, 0.65, 0.85], "positions"
    )
    assert_close(
        [t.label_anchor[1] for t in legend.ticks],
        [694, 654, 614, 574, 534],
        "anchor ys",
    )


def test_a_range_end_inside_the_slack_clamps_its_tick_to_the_bar() -> None:
    assert _legend(max_value=0.3, tick_interval=0.1).ticks[-1].position == 1


@pytest.mark.parametrize(
    ("spacing", "interval"),
    [(32, 20), (40, 20), (41, 50), (100, 50), (101, 100), (8, 5)],
)
def test_the_automatic_interval_keeps_ticks_the_minimum_spacing_apart(
    spacing: float, interval: float
) -> None:
    assert _legend(min_tick_spacing_pixels=spacing).tick_interval == interval


def test_labels_request_the_label_height_token() -> None:
    for t in _legend().ticks:
        assert t.label.height_pixels == tokens.COLOR_RAMP_LEGEND_LABEL_HEIGHT_PIXELS


def test_the_rect_is_the_placement_rect() -> None:
    assert tuple(_legend().rect) == (1216, 504, 1264, 704)


def test_passes_the_stops_and_their_keys_through_in_order() -> None:
    assert _legend(stops=list(_STOPS)).stops == _STOPS


def test_equal_neighboring_stops_make_a_hard_edge() -> None:
    stops = (
        ColorRampStop(position=0, key="low"),
        ColorRampStop(position=0.5, key="low"),
        ColorRampStop(position=0.5, key="high"),
        ColorRampStop(position=1, key="high"),
    )
    assert _legend(stops=stops).stops == stops


@pytest.mark.parametrize(
    "kwargs",
    [
        pytest.param({"min_value": 5, "max_value": 5}, id="an empty range"),
        pytest.param({"min_value": 10, "max_value": 0}, id="a reversed range"),
        pytest.param({"max_value": math.inf}, id="a non-finite range"),
        pytest.param({"min_value": math.nan}, id="a NaN range"),
        pytest.param({"stops": _STOPS[:1]}, id="one stop"),
        pytest.param(
            {
                "stops": (
                    ColorRampStop(position=0.1, key="a"),
                    ColorRampStop(position=1, key="b"),
                )
            },
            id="stops that start past 0",
        ),
        pytest.param(
            {
                "stops": (
                    ColorRampStop(position=0, key="a"),
                    ColorRampStop(position=0.9, key="b"),
                )
            },
            id="stops that end short of 1",
        ),
        pytest.param(
            {
                "stops": (
                    ColorRampStop(position=0, key="a"),
                    ColorRampStop(position=0.6, key="b"),
                    ColorRampStop(position=0.4, key="c"),
                    ColorRampStop(position=1, key="d"),
                )
            },
            id="descending stops",
        ),
        pytest.param({"tick_interval": 0}, id="a zero interval"),
        pytest.param({"tick_interval": math.nan}, id="a NaN interval"),
        pytest.param({"min_tick_spacing_pixels": 0}, id="a zero tick spacing"),
        pytest.param(
            {
                "placement": ViewportOverlayPlacement.of(
                    ViewportOverlayKind.COLOR_RAMP_LEGEND, height_pixels=0
                )
            },
            id="a bar with no length",
        ),
    ],
)
def test_rejects(kwargs: dict) -> None:
    with pytest.raises(ValueError):  # noqa: PT011 - each case names its cause
        _legend(**kwargs)


@pytest.mark.parametrize(
    ("value", "step", "numbers", "label"),
    [
        (45, 1, NumberFormatting(), "45"),
        (0.25, 0.05, NumberFormatting(), "0.25"),
        (12.345, 0.01, NumberFormatting(), "12.35"),
        (-0.04, 0.1, NumberFormatting(), "0"),
        (7, 5, NumberFormatting(), "5"),
        (0.5, 0.1, _COMMA, ",5"),
    ],
)
def test_format_number_label(
    value: float, step: float, numbers: NumberFormatting, label: str
) -> None:
    assert format_number_label(value, step=step, numbers=numbers) == label


def test_format_number_label_rejects_a_step_that_is_not_positive() -> None:
    with pytest.raises(ValueError, match="step"):
        format_number_label(1, step=0)
