"""Unit systems and display formats behave as the Dart reference's tests pin."""

import math
from collections.abc import Callable

import pytest

from conftest import TOLERANCE
from tech_vis import (
    DecimalMarker,
    DisplayFormat,
    NumberFormatting,
    UnitSystem,
    format_degrees_label,
    format_number_label,
    nice_step_at_least,
)

METRIC = DisplayFormat.METRIC
DECIMAL_INCH = DisplayFormat.DECIMAL_INCH
FRACTIONAL_INCH = DisplayFormat.FRACTIONAL_INCH
DECIMAL_FORMATS = (METRIC, DECIMAL_INCH)

NO_LEADING_ZERO = NumberFormatting(show_leading_zero=False)
COMMA = NumberFormatting(decimal_marker=DecimalMarker.COMMA)

NOT_POSITIVE_AND_FINITE = (0.0, -1.0, math.nan, math.inf)


def _expect_steps(
    cases: list[tuple[DisplayFormat, float, float | None]],
    query: Callable[[DisplayFormat, float], float | None],
) -> None:
    for display_format, length, step in cases:
        reason = f"{display_format.value} at {length}"
        actual = query(display_format, length)
        if step is None:
            assert actual is None, reason
        else:
            assert actual == pytest.approx(step, abs=TOLERANCE), reason


# UnitSystem


def test_unit_systems_are_metric_and_imperial() -> None:
    assert list(UnitSystem) == [UnitSystem.METRIC, UnitSystem.IMPERIAL]


def test_unit_system_names_its_base_unit() -> None:
    assert UnitSystem.METRIC.abbreviation == "mm"
    assert UnitSystem.IMPERIAL.abbreviation == "in"
    assert UnitSystem.METRIC.base_unit == "mm"
    assert UnitSystem.IMPERIAL.base_unit == "in"
    assert UnitSystem.METRIC.label == "Metric (mm)"
    assert UnitSystem.IMPERIAL.label == "Imperial (in)"


@pytest.mark.parametrize(
    ("source", "value", "target", "want"),
    [
        (UnitSystem.METRIC, 25.4, UnitSystem.IMPERIAL, 1.0),
        (UnitSystem.IMPERIAL, 1.0, UnitSystem.METRIC, 25.4),
        (UnitSystem.METRIC, -25.4, UnitSystem.IMPERIAL, -1.0),
        (UnitSystem.METRIC, 42.0, UnitSystem.METRIC, 42.0),
        (UnitSystem.IMPERIAL, 0.0, UnitSystem.METRIC, 0.0),
    ],
)
def test_convert_to(
    source: UnitSystem, value: float, target: UnitSystem, want: float
) -> None:
    assert source.convert_to(value, target) == pytest.approx(want, abs=TOLERANCE)


# DisplayFormat


def test_display_formats() -> None:
    assert list(DisplayFormat) == [METRIC, DECIMAL_INCH, FRACTIONAL_INCH]


def test_display_format_measures_in_its_unit_system() -> None:
    assert METRIC.unit_system is UnitSystem.METRIC
    assert DECIMAL_INCH.unit_system is UnitSystem.IMPERIAL
    assert FRACTIONAL_INCH.unit_system is UnitSystem.IMPERIAL


def test_scale_bar_step_at_most_returns_the_largest_step_that_fits() -> None:
    decimal = [
        (7, 5),
        (10, 10),
        (19.99, 10),
        (2000, 2000),
        (0.7, 0.5),
        (0.03, 0.02),
        (3e-7, 2e-7),
        (6e9, 5e9),
    ]
    fractional = [
        (0.01, None),
        (1 / 64, 1 / 64),
        (0.1, 1 / 16),
        (0.5, 0.5),
        (3, 1),
        (11.9, 6),
        (12, 12),
        (23, 12),
        (59, 24),
        (60, 60),
        (130, 120),
        (1300, 1200),
    ]
    _expect_steps(
        [(f, x, s) for f in DECIMAL_FORMATS for x, s in decimal]
        + [(FRACTIONAL_INCH, x, s) for x, s in fractional],
        lambda f, x: f.scale_bar_step_at_most(x),
    )


def test_grid_step_at_least_returns_the_smallest_step_that_covers() -> None:
    decimal = [
        (7, 10),
        (10, 10),
        (101, 1000),
        (0.03, 0.1),
        (0.001, 0.001),
        (4e-8, 1e-7),
    ]
    fractional = [
        (0.001, 1 / 16),
        (1 / 16, 1 / 16),
        (0.1, 0.25),
        (0.5, 1),
        (2, 12),
        (12, 12),
        (13, 120),
        (200, 1200),
    ]
    _expect_steps(
        [(f, x, s) for f in DECIMAL_FORMATS for x, s in decimal]
        + [(FRACTIONAL_INCH, x, s) for x, s in fractional],
        lambda f, x: f.grid_step_at_least(x),
    )


def test_grid_step_above_returns_the_next_grid_step() -> None:
    decimal = [(10, 100), (0.1, 1), (0.001, 0.01)]
    fractional = [(1 / 16, 0.25), (0.25, 1), (1, 12), (12, 120), (120, 1200)]
    _expect_steps(
        [(f, x, s) for f in DECIMAL_FORMATS for x, s in decimal]
        + [(FRACTIONAL_INCH, x, s) for x, s in fractional],
        lambda f, x: f.grid_step_above(x),
    )


def test_scale_bar_step_below_returns_the_next_shorter_step() -> None:
    decimal = [(10, 5), (5, 2), (2, 1), (1, 0.5), (7, 5)]
    fractional = [
        (1 / 64, None),
        (1 / 32, 1 / 64),
        (1, 0.5),
        (6, 1),
        (12, 6),
        (24, 12),
        (60, 24),
    ]
    _expect_steps(
        [(f, x, s) for f in DECIMAL_FORMATS for x, s in decimal]
        + [(FRACTIONAL_INCH, x, s) for x, s in fractional],
        lambda f, x: f.scale_bar_step_below(x),
    )


@pytest.mark.parametrize(
    ("display_format", "length", "expected"),
    [
        *[
            (f, x, e)
            for f in DECIMAL_FORMATS
            for x, e in [
                (5, True),
                (0.2, True),
                (0.1 + 0.2, False),
                (3, False),
                (2000, True),
            ]
        ],
        (FRACTIONAL_INCH, 1 / 64, True),
        (FRACTIONAL_INCH, 1 / 128, False),
        (FRACTIONAL_INCH, 0.375, False),
        (FRACTIONAL_INCH, 6, True),
        (FRACTIONAL_INCH, 60, True),
        (FRACTIONAL_INCH, 36, False),
    ],
)
def test_is_scale_bar_step(
    display_format: DisplayFormat, length: float, expected: bool
) -> None:
    assert display_format.is_scale_bar_step(length) is expected


@pytest.mark.parametrize(
    ("display_format", "length", "expected"),
    [
        *[
            (f, x, e)
            for f in DECIMAL_FORMATS
            for x, e in [
                (1, True),
                (0.01, True),
                (1000, True),
                (5, False),
                (2, False),
            ]
        ],
        (FRACTIONAL_INCH, 1 / 16, True),
        (FRACTIONAL_INCH, 0.25, True),
        (FRACTIONAL_INCH, 12, True),
        (FRACTIONAL_INCH, 120, True),
        (FRACTIONAL_INCH, 0.5, False),
        (FRACTIONAL_INCH, 6, False),
    ],
)
def test_is_grid_step(
    display_format: DisplayFormat, length: float, expected: bool
) -> None:
    assert display_format.is_grid_step(length) is expected


@pytest.mark.parametrize("display_format", list(DisplayFormat))
@pytest.mark.parametrize("length", NOT_POSITIVE_AND_FINITE)
def test_step_membership_rejects_a_length_not_positive_and_finite(
    display_format: DisplayFormat, length: float
) -> None:
    assert display_format.is_scale_bar_step(length) is False
    assert display_format.is_grid_step(length) is False


@pytest.mark.parametrize("display_format", list(DisplayFormat))
def test_each_grid_step_is_a_whole_multiple_of_the_one_before(
    display_format: DisplayFormat,
) -> None:
    step = display_format.grid_step_at_least(1e-3)
    for _ in range(12):
        following = display_format.grid_step_above(step)
        ratio = following / step
        assert ratio == pytest.approx(round(ratio), abs=TOLERANCE)
        assert round(ratio) > 1
        step = following


@pytest.mark.parametrize("display_format", list(DisplayFormat))
@pytest.mark.parametrize("length", NOT_POSITIVE_AND_FINITE)
def test_step_queries_reject_a_length_not_positive_and_finite(
    display_format: DisplayFormat, length: float
) -> None:
    with pytest.raises(ValueError):
        display_format.scale_bar_step_at_most(length)
    with pytest.raises(ValueError):
        display_format.grid_step_at_least(length)
    with pytest.raises(ValueError):
        display_format.grid_step_above(length)
    with pytest.raises(ValueError):
        display_format.scale_bar_step_below(length)


_INCHES_1500_MM = UnitSystem.METRIC.convert_to(1500, UnitSystem.IMPERIAL)
_MM_FROM_EIGHTH = UnitSystem.IMPERIAL.convert_to(0.125, UnitSystem.METRIC)
_MM_FROM_40_HALF = UnitSystem.IMPERIAL.convert_to(40.5, UnitSystem.METRIC)

_DEFAULT = NumberFormatting()

# Each case: name, format, values, step, number formatting, expected labels.
_LABEL_CASES = [
    # The roadmap's verification values, in each display format.
    ("1500 mm, metric", METRIC, [1500], None, _DEFAULT, ["1500 mm"]),
    (
        "1500 mm, decimal inch",
        DECIMAL_INCH,
        [_INCHES_1500_MM],
        None,
        _DEFAULT,
        ["59.0551 in"],
    ),
    (
        "1500 mm, fractional inch",
        FRACTIONAL_INCH,
        [_INCHES_1500_MM],
        None,
        _DEFAULT,
        ["4' 11 1/16\""],
    ),
    ("0.125 in, metric", METRIC, [_MM_FROM_EIGHTH], None, _DEFAULT, ["3.175 mm"]),
    ("0.125 in, decimal inch", DECIMAL_INCH, [0.125], None, _DEFAULT, ["0.125 in"]),
    ("0.125 in, fractional inch", FRACTIONAL_INCH, [0.125], None, _DEFAULT, ['1/8"']),
    ("40.5 in, metric", METRIC, [_MM_FROM_40_HALF], None, _DEFAULT, ["1028.7 mm"]),
    ("40.5 in, decimal inch", DECIMAL_INCH, [40.5], None, _DEFAULT, ["40.5 in"]),
    (
        "40.5 in, fractional inch",
        FRACTIONAL_INCH,
        [40.5],
        None,
        _DEFAULT,
        ["3' 4 1/2\""],
    ),
    # Metric promotes at 10 m, decided by the set's largest value.
    ("below 10 m", METRIC, [9000, 9500], None, _DEFAULT, ["9000 mm", "9500 mm"]),
    (
        "a set reaching 10 m",
        METRIC,
        [0, 5000, 10000],
        5000,
        _DEFAULT,
        ["0 m", "5 m", "10 m"],
    ),
    ("a lone value past 10 m", METRIC, [12345.6], None, _DEFAULT, ["12.3456 m"]),
    (
        "negative values promote by magnitude",
        METRIC,
        [-10500, 500],
        None,
        _DEFAULT,
        ["-10.5 m", "0.5 m"],
    ),
    # Decimal inch never promotes.
    (
        "decimal inch past a foot",
        DECIMAL_INCH,
        [120, 1200],
        None,
        _DEFAULT,
        ["120 in", "1200 in"],
    ),
    # Decimal places follow the step, with no trailing zeros.
    (
        "quarter steps",
        METRIC,
        [0, 0.25, 0.5, 0.75],
        0.25,
        _DEFAULT,
        ["0 mm", "0.25 mm", "0.5 mm", "0.75 mm"],
    ),
    (
        "a coarse step rounds",
        DECIMAL_INCH,
        [0.04, 0.16],
        0.1,
        _DEFAULT,
        ["0 in", "0.2 in"],
    ),
    ("default rounding, metric", METRIC, [1.23456], None, _DEFAULT, ["1.235 mm"]),
    (
        "default rounding, decimal inch",
        DECIMAL_INCH,
        [1.234567],
        None,
        _DEFAULT,
        ["1.2346 in"],
    ),
    (
        "rounds away floating-point noise",
        METRIC,
        [0.1 + 0.2],
        None,
        _DEFAULT,
        ["0.3 mm"],
    ),
    ("negative zero shows as zero", METRIC, [-0.0001], None, _DEFAULT, ["0 mm"]),
    # The app's decimal marker and leading zero.
    (
        "leading zero hidden",
        METRIC,
        [0.5, -0.5, 1.5],
        None,
        NO_LEADING_ZERO,
        [".5 mm", "-.5 mm", "1.5 mm"],
    ),
    (
        "decimal comma",
        DECIMAL_INCH,
        [0.125, 2.5],
        None,
        COMMA,
        ["0,125 in", "2,5 in"],
    ),
    ("decimal comma in meters", METRIC, [12500], None, COMMA, ["12,5 m"]),
    # Fractional inch: binary fractions, feet and inches from 12 in.
    (
        "fractions below an inch",
        FRACTIONAL_INCH,
        [0, 0.25, 0.5, 1 / 64],
        None,
        _DEFAULT,
        ['0"', '1/4"', '1/2"', '1/64"'],
    ),
    (
        "whole and fractional inches",
        FRACTIONAL_INCH,
        [3, 4.75],
        None,
        _DEFAULT,
        ['3"', '4 3/4"'],
    ),
    (
        "a set reaching a foot",
        FRACTIONAL_INCH,
        [0, 6, 12, 18],
        6,
        _DEFAULT,
        ["0' 0\"", "0' 6\"", "1' 0\"", "1' 6\""],
    ),
    (
        "whole feet drop the inches",
        FRACTIONAL_INCH,
        [0, 12, 24],
        12,
        _DEFAULT,
        ["0'", "1'", "2'"],
    ),
    (
        "a sixteenth step rounds",
        FRACTIONAL_INCH,
        [0.1, 0.2],
        1 / 16,
        _DEFAULT,
        ['1/8"', '3/16"'],
    ),
    (
        "rounding up to a foot promotes",
        FRACTIONAL_INCH,
        [11.999],
        None,
        _DEFAULT,
        ["1' 0\""],
    ),
    (
        "negative feet and inches",
        FRACTIONAL_INCH,
        [-40.5],
        None,
        _DEFAULT,
        ["-3' 4 1/2\""],
    ),
    (
        "fractional inch ignores the decimal marker",
        FRACTIONAL_INCH,
        [0.5],
        None,
        COMMA,
        ['1/2"'],
    ),
    # Ties round half away from zero on the binary value, as Dart's
    # toStringAsFixed and num.round() do. Python's own rounding is
    # half-to-even, which would write 0.12 and 0" for these.
    ("a decimal tie rounds up", METRIC, [0.125], 0.01, _DEFAULT, ["0.13 mm"]),
    ("a negative decimal tie", METRIC, [-0.125], 0.01, _DEFAULT, ["-0.13 mm"]),
    ("a fractional tie rounds up", FRACTIONAL_INCH, [0.5], 1, _DEFAULT, ['1"']),
    ("a negative fractional tie", FRACTIONAL_INCH, [-2.5], 1, _DEFAULT, ['-3"']),
]


@pytest.mark.parametrize(
    ("display_format", "values", "step", "numbers", "labels"),
    [pytest.param(*c[1:], id=c[0]) for c in _LABEL_CASES],
)
def test_format_labels(
    display_format: DisplayFormat,
    values: list[float],
    step: float | None,
    numbers: NumberFormatting,
    labels: list[str],
) -> None:
    assert display_format.format_labels(values, step=step, numbers=numbers) == labels


@pytest.mark.parametrize("display_format", list(DisplayFormat))
@pytest.mark.parametrize("step", NOT_POSITIVE_AND_FINITE)
def test_format_labels_rejects_a_step_not_positive_and_finite(
    display_format: DisplayFormat, step: float
) -> None:
    with pytest.raises(ValueError):
        display_format.format_labels([1], step=step)


@pytest.mark.parametrize("display_format", list(DisplayFormat))
@pytest.mark.parametrize("length", [1.0, 6.0, 12.0, 130.0])
def test_step_queries_return_floats(
    display_format: DisplayFormat, length: float
) -> None:
    assert type(display_format.scale_bar_step_at_most(length)) is float
    assert type(display_format.scale_bar_step_below(length)) is float
    assert type(display_format.grid_step_at_least(length)) is float
    assert type(display_format.grid_step_above(length)) is float


@pytest.mark.parametrize("display_format", list(DisplayFormat))
def test_format_labels_returns_no_labels_for_no_values(
    display_format: DisplayFormat,
) -> None:
    assert display_format.format_labels([]) == []


@pytest.mark.parametrize(
    ("degrees", "step", "numbers", "label"),
    [
        (45.0, 0.1, NumberFormatting(), "45°"),
        (30.04, 0.1, NumberFormatting(), "30°"),
        (30.06, 0.1, NumberFormatting(), "30.1°"),
        (12.345, 0.01, NumberFormatting(), "12.35°"),
        (89.6, 1.0, NumberFormatting(), "90°"),
        (179.96, 0.1, NumberFormatting(), "180°"),
        (0.25, 0.05, NO_LEADING_ZERO, ".25°"),
        (0.5, 0.1, COMMA, "0,5°"),
        (22.5, 0.1, COMMA, "22,5°"),
    ],
)
def test_format_degrees_label(
    degrees: float, step: float, numbers: NumberFormatting, label: str
) -> None:
    assert format_degrees_label(degrees, step=step, numbers=numbers) == label


def test_format_degrees_label_rounds_ties_away_from_zero() -> None:
    # Dart's roundToDouble rounds a tie away from zero; Python's round() would
    # write 2° and -2°.
    assert format_degrees_label(2.5, step=1.0) == "3°"
    assert format_degrees_label(-2.5, step=1.0) == "-3°"


@pytest.mark.parametrize("step", NOT_POSITIVE_AND_FINITE)
def test_format_degrees_label_rejects_a_step_not_positive_and_finite(
    step: float,
) -> None:
    with pytest.raises(ValueError):
        format_degrees_label(1.0, step=step)


@pytest.mark.parametrize(
    ("length", "step"),
    [
        (0.3, 0.5),
        (1.0, 1.0),
        (1.2, 2.0),
        (3.0, 5.0),
        (7.0, 10.0),
        (0.1 + 0.2, 0.5),
        (2e-7, 2e-7),
        (3e19, 5e19),
    ],
)
def test_nice_step_at_least(length: float, step: float) -> None:
    assert nice_step_at_least(length) == pytest.approx(step, rel=1e-12)


@pytest.mark.parametrize("length", [0.0, -1.0, math.nan, math.inf])
def test_nice_step_at_least_rejects_a_length_that_is_not_positive(
    length: float,
) -> None:
    with pytest.raises(ValueError, match="length"):
        nice_step_at_least(length)


def test_format_number_label_snaps_to_a_multiple_of_the_step() -> None:
    assert format_number_label(7, step=5) == "5"


def test_format_number_label_writes_the_app_decimal_marker() -> None:
    numbers = NumberFormatting(
        decimal_marker=DecimalMarker.COMMA, show_leading_zero=False
    )
    assert format_number_label(0.5, step=0.1, numbers=numbers) == ",5"


def test_format_number_label_rejects_a_step_that_is_not_positive() -> None:
    with pytest.raises(ValueError, match="step"):
        format_number_label(1, step=0)
