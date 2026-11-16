"""Measurement units and the display formats that label them, ported from the
Dart reference.

``UnitSystem`` converts between millimeters and inches. ``DisplayFormat``
decides how a measurement reads: its scale-bar and grid steps and the text of
its labels, and ``format_degrees_label`` writes an angle's. Every query here
agrees with ``vectors/unit_formats.json``.
"""

import math
import re
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal, localcontext
from enum import StrEnum


class UnitSystem(StrEnum):
    """Names the metric (mm) and imperial (in) unit systems.

    Each value is the system's name in the Dart package.
    """

    METRIC = "metric"
    IMPERIAL = "imperial"

    @property
    def abbreviation(self) -> str:
        """Returns the short unit abbreviation: ``"mm"`` or ``"in"``."""
        return _UNIT_SYSTEMS[self].abbreviation

    @property
    def base_unit(self) -> str:
        """Returns the base unit's name, the same as the abbreviation."""
        return _UNIT_SYSTEMS[self].abbreviation

    @property
    def label(self) -> str:
        """Returns the human-readable label, such as ``"Metric (mm)"``."""
        return _UNIT_SYSTEMS[self].label

    def convert_to(self, value: float, target: "UnitSystem") -> float:
        """Returns ``value``, in this system's base unit, in ``target``'s."""
        if self is target:
            return value
        # Through millimeters, so each system needs only its own factor.
        mm = value * _UNIT_SYSTEMS[self].to_mm_factor
        return mm / _UNIT_SYSTEMS[target].to_mm_factor


@dataclass(frozen=True, slots=True)
class _UnitSystemSpec:
    abbreviation: str
    label: str
    to_mm_factor: float


_MM_PER_INCH = 25.4

_UNIT_SYSTEMS = {
    UnitSystem.METRIC: _UnitSystemSpec("mm", "Metric (mm)", 1.0),
    UnitSystem.IMPERIAL: _UnitSystemSpec("in", "Imperial (in)", _MM_PER_INCH),
}


class DecimalMarker(StrEnum):
    """Names the character between a label's whole part and its decimals.

    Each value is the marker's name in the golden vectors and in the Dart
    package, so ``DecimalMarker("comma")`` parses a fixture entry.
    """

    POINT = "point"
    COMMA = "comma"

    @property
    def symbol(self) -> str:
        """Returns the marker's character: ``"."`` or ``","``."""
        return "." if self is DecimalMarker.POINT else ","


@dataclass(frozen=True, slots=True)
class NumberFormatting:
    """Holds the app's choices for writing a decimal number in a label.

    These are independent of the display format and of the drafting
    convention, because they vary by locale and shop. The defaults write
    ``0.5``.
    """

    decimal_marker: DecimalMarker = DecimalMarker.POINT
    """The character between the whole part and the decimals."""

    show_leading_zero: bool = True
    """Whether a value below one shows its leading zero: ``0.5`` or ``.5``."""


# A default argument is built once; the formatting is frozen, so sharing it is
# safe.
_DEFAULT_NUMBERS = NumberFormatting()


class DisplayFormat(StrEnum):
    """Names how a measurement displays: metric, decimal inch, or fractional
    inch.

    Every length a format takes or returns is in the base unit of its
    ``unit_system``: millimeters for metric, inches for decimal and
    fractional inch. Convert a world length with ``UnitSystem.convert_to``
    first. Each value is the format's name in the golden vectors and in the
    Dart package, so ``DisplayFormat("decimalInch")`` parses a fixture entry.
    """

    METRIC = "metric"
    """Millimeters, promoted to meters at 10 m and above."""

    DECIMAL_INCH = "decimalInch"
    """Inches with decimal places, never promoted to feet."""

    FRACTIONAL_INCH = "fractionalInch"
    """Inches with binary fractions down to 1/64, promoted to feet and inches
    at 12 in and above: ``3' 4 1/2"``."""

    @property
    def unit_system(self) -> UnitSystem:
        """Returns the unit system whose base unit this format's lengths are
        in."""
        return _FORMATS[self].unit_system

    def scale_bar_step_at_most(self, length: float) -> float | None:
        """Returns the largest scale-bar step no longer than ``length``, or
        ``None`` when even the smallest step is longer.

        Scale-bar steps are 1, 2, and 5 times every power of ten, except
        fractional inch, which steps through binary fractions to 1 in, then 6
        and 12 in, then 1, 2, and 5 times every power of ten feet.

        Raises ``ValueError`` when ``length`` is not positive and finite.
        """
        return _FORMATS[self].scale_bar_steps.at_most(_positive(length, "length"))

    def scale_bar_step_below(self, step: float) -> float | None:
        """Returns the largest scale-bar step shorter than ``step``, or
        ``None`` when ``step`` is the smallest.

        Raises ``ValueError`` when ``step`` is not positive and finite.
        """
        return _FORMATS[self].scale_bar_steps.below(_positive(step, "step"))

    def is_scale_bar_step(self, length: float) -> bool:
        """Returns whether ``length`` is one of the scale-bar steps.

        Returns ``False`` for a ``length`` that is not positive and finite.
        """
        if not math.isfinite(length) or length <= 0:
            return False
        step = _FORMATS[self].scale_bar_steps.at_most(length)
        return step is not None and abs(step - length) <= length * _RELATIVE_SLACK

    def grid_step_at_least(self, length: float) -> float:
        """Returns the smallest grid step at least ``length`` long.

        Grid steps are every power of ten, except fractional inch, which steps
        1/16, 1/4, 1, and 12 in, then every power of ten feet. Each grid step
        is a whole multiple of the one before it, so a major line is always
        also a minor line.

        Raises ``ValueError`` when ``length`` is not positive and finite.
        """
        return _FORMATS[self].grid_steps.at_least(_positive(length, "length"))

    def is_grid_step(self, length: float) -> bool:
        """Returns whether ``length`` is one of the grid steps.

        Returns ``False`` for a ``length`` that is not positive and finite.
        """
        if not math.isfinite(length) or length <= 0:
            return False
        step = _FORMATS[self].grid_steps.at_least(length)
        return abs(step - length) <= length * _RELATIVE_SLACK

    def grid_step_above(self, step: float) -> float:
        """Returns the smallest grid step longer than ``step``: the major step
        over a minor ``step``.

        Raises ``ValueError`` when ``step`` is not positive and finite.
        """
        return _FORMATS[self].grid_steps.above(_positive(step, "step"))

    def format_labels(
        self,
        values: Sequence[float],
        *,
        step: float | None = None,
        numbers: NumberFormatting = _DEFAULT_NUMBERS,
    ) -> list[str]:
        """Returns the labels for a set of ``values`` displayed together, one
        per value, in order.

        Every label in the set shares one unit, and the set's largest
        magnitude decides whether it promotes to meters or to feet and inches.
        Each label rounds to ``step`` and shows the fewest decimal places, or
        the smallest binary fraction, that represent ``step`` exactly, with no
        trailing zeros. A fractional-inch set whose ``step`` is a whole number
        of feet drops the inches: ``2'``. Without a ``step``, labels round to
        0.001 mm, 0.0001 in, or 1/64 in. ``numbers`` sets the decimal marker
        and leading zero; fractional inch has no decimals and ignores it.

        Raises ``ValueError`` when ``step`` is not positive and finite.
        """
        spec = _FORMATS[self]
        rounding = _positive(spec.resolution if step is None else step, "step")
        if self is DisplayFormat.METRIC:
            return _decimal_labels(
                values, rounding, numbers, unit="mm", promotion=_METERS
            )
        if self is DisplayFormat.DECIMAL_INCH:
            return _decimal_labels(values, rounding, numbers, unit="in")
        return _fractional_labels(values, rounding)


def format_degrees_label(
    degrees: float, *, step: float, numbers: NumberFormatting = _DEFAULT_NUMBERS
) -> str:
    """Returns ``degrees`` as a decimal-degree label: ``45°`` or ``30.5°``.

    The label rounds to ``step`` and shows the fewest decimal places that
    represent ``step`` exactly, with no trailing zeros, as a length label
    does. ``numbers`` sets the decimal marker and leading zero. An angle has
    no display format, so the label is the same in every unit system.

    Raises ``ValueError`` when ``step`` is not positive and finite.
    """
    places = _decimals_for(_positive(step, "step"))
    rounded = float(_to_fixed(_round_half_away(degrees / step) * step, places))
    return f"{_decimal(rounded, places, numbers)}°"


_INCHES_PER_FOOT = 12

# Fractional inch reads to 1/64 in and no finer.
_FINEST_DENOMINATOR = 64

# Decimal places allowed before a step counts as unrepresentable.
_MAX_DECIMALS = 12

# Relative slack in comparisons between a step and a requested length, so a
# length computed as 0.1 + 0.2 still admits the step 0.3.
_RELATIVE_SLACK = 1e-9


def _positive(value: float, name: str) -> float:
    if not math.isfinite(value) or value <= 0:
        raise ValueError(f"{name} must be positive and finite, got {value!r}")
    return value


@dataclass(frozen=True, slots=True)
class _StepSequence:
    """An unbounded ascending sequence of clean steps: an optional run of
    ``leading`` steps, then ``mantissas`` times every power of ten
    ``decade_unit``s from 10^``min_exponent`` up, skipping any not past the
    leading run. With no ``min_exponent`` the decades run down without end.
    """

    mantissas: tuple[float, ...]
    leading: tuple[float, ...] = ()
    decade_unit: float = 1
    min_exponent: int | None = None

    def _near(self, length: float) -> Iterator[float]:
        """Yields every leading step, and the decades either side of
        ``length``'s own, which bracket it from below and above."""
        yield from (float(step) for step in self.leading)
        own = math.floor(math.log(length / self.decade_unit) / math.log(10))
        minimum = self.min_exponent
        low = max(own - 1, own - 1 if minimum is None else minimum)
        high = max(own + 1, own + 1 if minimum is None else minimum)
        for exponent in range(low, high + 1):
            for mantissa in self.mantissas:
                step = float(_decade(mantissa, exponent) * self.decade_unit)
                if not self.leading or step > self.leading[-1] * (1 + _RELATIVE_SLACK):
                    yield step

    def at_most(self, length: float) -> float | None:
        best: float | None = None
        for step in self._near(length):
            if step <= length * (1 + _RELATIVE_SLACK) and step > (best or 0):
                best = step
        return best

    def below(self, step: float) -> float | None:
        bound = step * (1 - _RELATIVE_SLACK)
        best: float | None = None
        for candidate in self._near(bound):
            if candidate < bound and candidate > (best or 0):
                best = candidate
        return best

    def at_least(self, length: float) -> float:
        return self._smallest_from(length * (1 - _RELATIVE_SLACK))

    def above(self, step: float) -> float:
        return self._smallest_from(step * (1 + _RELATIVE_SLACK))

    def _smallest_from(self, bound: float) -> float:
        """Returns the smallest step at or past ``bound``, which already
        carries the slack."""
        best = math.inf
        for step in self._near(bound):
            if bound <= step < best:
                best = step
        return best


def _decade(mantissa: float, exponent: int) -> float:
    """Returns ``mantissa`` times 10^``exponent``, dividing for negative
    exponents so that 10^-3 is the float nearest 0.001."""
    if exponent >= 0:
        return mantissa * 10**exponent
    return mantissa / 10**-exponent


@dataclass(frozen=True, slots=True)
class _FormatSpec:
    unit_system: UnitSystem
    scale_bar_steps: _StepSequence
    grid_steps: _StepSequence
    # The step labels round to when the caller names none.
    resolution: float


_FORMATS = {
    DisplayFormat.METRIC: _FormatSpec(
        unit_system=UnitSystem.METRIC,
        scale_bar_steps=_StepSequence(mantissas=(1, 2, 5)),
        grid_steps=_StepSequence(mantissas=(1,)),
        resolution=0.001,
    ),
    DisplayFormat.DECIMAL_INCH: _FormatSpec(
        unit_system=UnitSystem.IMPERIAL,
        scale_bar_steps=_StepSequence(mantissas=(1, 2, 5)),
        grid_steps=_StepSequence(mantissas=(1,)),
        resolution=0.0001,
    ),
    DisplayFormat.FRACTIONAL_INCH: _FormatSpec(
        unit_system=UnitSystem.IMPERIAL,
        scale_bar_steps=_StepSequence(
            leading=(1 / 64, 1 / 32, 1 / 16, 1 / 8, 1 / 4, 1 / 2, 1, 6, 12),
            mantissas=(1, 2, 5),
            decade_unit=_INCHES_PER_FOOT,
            min_exponent=0,
        ),
        grid_steps=_StepSequence(
            leading=(1 / 16, 1 / 4, 1, 12),
            mantissas=(1,),
            decade_unit=_INCHES_PER_FOOT,
            min_exponent=0,
        ),
        resolution=1 / _FINEST_DENOMINATOR,
    ),
}


@dataclass(frozen=True, slots=True)
class _Promotion:
    """A larger unit a decimal label set switches to at ``at_least``."""

    at_least: float
    unit: str
    factor: float
    # The decimal places a value gains when it reads in the larger unit.
    decimals: int


_MM_PER_METER = 1000
_METERS_DECIMALS = 3

# Metric labels promote to meters at and above 10 m.
_METRIC_PROMOTION_MM = 10000

_METERS = _Promotion(
    at_least=_METRIC_PROMOTION_MM,
    unit="m",
    factor=_MM_PER_METER,
    decimals=_METERS_DECIMALS,
)

# Dart's toStringAsFixed switches to exponential notation at this magnitude.
_FIXED_NOTATION_LIMIT = 1e21

# Enough significant digits to write any float below the fixed-notation limit
# to the most decimals a label takes, exactly.
_EXACT_PRECISION = 64


def _round_half_away(value: float) -> int:
    """Returns ``value`` rounded to an integer, ties away from zero.

    Mirrors Dart's ``num.round()``; Python's ``round()`` rounds ties to even.
    """
    return int(Decimal(value).to_integral_value(rounding=ROUND_HALF_UP))


def _to_fixed(value: float, places: int) -> str:
    """Returns ``value`` written with ``places`` decimals.

    Mirrors Dart's ``toStringAsFixed``: it rounds the exact binary value, ties
    away from zero, where Python's ``f"{value:.{places}f}"`` rounds ties to
    even.
    """
    if abs(value) >= _FIXED_NOTATION_LIMIT:
        return repr(value)
    with localcontext(prec=_EXACT_PRECISION):
        exact = Decimal(value).quantize(Decimal(1).scaleb(-places), ROUND_HALF_UP)
    return f"{exact:f}"


def _is_whole(x: float) -> bool:
    """Returns whether ``x`` is a whole number, within the relative slack."""
    return abs(x - _round_half_away(x)) <= abs(x) * _RELATIVE_SLACK


def _decimals_for(step: float) -> int:
    """Returns the fewest decimal places that write ``step`` exactly."""
    for places in range(_MAX_DECIMALS):
        if _is_whole(step * 10**places):
            return places
    return _MAX_DECIMALS


def _decimal_labels(
    values: Sequence[float],
    step: float,
    numbers: NumberFormatting,
    *,
    unit: str,
    promotion: _Promotion | None = None,
) -> list[str]:
    places = _decimals_for(step)
    rounded = [float(_to_fixed(v, places)) for v in values]
    largest = max((abs(v) for v in rounded), default=0.0)
    if promotion is not None and largest >= promotion.at_least:
        return [
            f"{_decimal(v / promotion.factor, places + promotion.decimals, numbers)}"
            f" {promotion.unit}"
            for v in rounded
        ]
    return [f"{_decimal(v, places, numbers)} {unit}" for v in rounded]


_TRAILING_ZEROS = re.compile(r"\.?0+$")


def _decimal(value: float, places: int, numbers: NumberFormatting) -> str:
    """Writes ``value`` to ``places`` decimals, without trailing zeros."""
    text = _to_fixed(abs(value), places)
    if "." in text:
        text = _TRAILING_ZEROS.sub("", text, count=1)
    if text == "0":
        return text
    if not numbers.show_leading_zero and text.startswith("0."):
        text = text[1:]
    text = text.replace(".", numbers.decimal_marker.symbol, 1)
    return f"-{text}" if value < 0 else text


def _denominator_for(step: float) -> int:
    """Returns the smallest binary fraction denominator, up to 1/64, that
    writes ``step`` exactly."""
    denominator = 1
    while denominator < _FINEST_DENOMINATOR:
        if _is_whole(step * denominator):
            return denominator
        denominator *= 2
    return _FINEST_DENOMINATOR


def _fractional_labels(values: Sequence[float], step: float) -> list[str]:
    denominator = _denominator_for(step)
    foot = _INCHES_PER_FOOT * denominator
    # Each value as a whole count of 1/denominator inches.
    counts = [_round_half_away(v * denominator) for v in values]
    largest = max((abs(c) for c in counts), default=0)
    promote = largest >= foot
    # A step of whole feet never needs the inches, so its labels drop them.
    whole_feet = promote and _is_whole(step / _INCHES_PER_FOOT)

    def inches(count: int) -> str:
        whole, remainder = divmod(count, denominator)
        if remainder == 0:
            return f'{whole}"'
        divisor = math.gcd(remainder, denominator)
        fraction = f"{remainder // divisor}/{denominator // divisor}"
        return f'{fraction}"' if whole == 0 else f'{whole} {fraction}"'

    def label(count: int) -> str:
        n = abs(count)
        if whole_feet:
            text = f"{n // foot}'"
        elif promote:
            text = f"{n // foot}' {inches(n % foot)}"
        else:
            text = inches(n)
        return f"-{text}" if count < 0 else text

    return [label(c) for c in counts]
