"""Color ramp legend overlay (§spec:color-ramp-legend), ported from the Dart
reference."""

import math
from collections.abc import Sequence
from dataclasses import dataclass
from enum import Enum
from typing import Self

from tech_vis import tokens
from tech_vis._vec import Vector2
from tech_vis.primitives import TextRequest
from tech_vis.unit_system import (
    NumberFormatting,
    format_number_label,
    nice_step_at_least,
)
from tech_vis.viewport_overlay import (
    ViewportOverlayKind,
    ViewportOverlayPlacement,
    ViewportRect,
)

# Relative slack when testing whether a tick falls inside the value range, so
# a range end computed as 0.1 + 0.2 still keeps the tick at 0.3.
_RANGE_SLACK = 1e-9

_MIN_STOPS = 2

# A default argument is built once; the formatting is frozen, so sharing it is
# safe.
_DEFAULT_NUMBERS = NumberFormatting()


class ColorRampOrientation(Enum):
    """The direction a color ramp legend's bar runs, from the range's minimum
    to its maximum."""

    HORIZONTAL = "horizontal"
    """Left to right."""

    VERTICAL = "vertical"
    """Bottom to top."""


@dataclass(frozen=True, slots=True, kw_only=True)
class ColorRampStop:
    """Holds one color stop of a legend's gradient: a position along the bar
    and the app's key for the color there.

    The package holds no color. The app resolves ``key`` to a color and
    interpolates between neighboring stops in the color space its renderer
    needs.
    """

    position: float
    """Where the stop sits along the bar, from 0 at the range's minimum to 1
    at its maximum."""

    key: object
    """App key for the stop's color, passed through untouched."""


@dataclass(frozen=True, slots=True, kw_only=True)
class ColorRampTick:
    """Holds one tick of a legend: a value on the bar and the request for its
    label."""

    value: float
    """The value the tick marks, in the app's value unit."""

    position: float
    """Where the tick sits along the bar, from 0 at the range's minimum to 1
    at its maximum."""

    label: TextRequest
    """The tick's label, as text for the app to set."""

    label_anchor: Vector2
    """The viewport pixel the label's alignment point sits on."""


@dataclass(frozen=True, slots=True, kw_only=True)
class ColorRampLegendLayout:
    """Holds a color ramp legend in viewport pixels, for the app to draw in its
    2D layer above the scene.

    Every x and y is in the screen coordinates of ``world_to_screen``: pixels
    from the viewport's top-left corner, y down. Every value is in the app's
    value unit.
    """

    rect: ViewportRect
    """The overlay's rectangle, from its placement."""

    bar_rect: ViewportRect
    """The gradient bar's rectangle. It spans ``rect``'s full length along
    ``orientation`` and sits on ``rect``'s edge nearer its corner."""

    orientation: ColorRampOrientation
    """The direction the bar runs, from the range's minimum to its maximum."""

    stops: tuple[ColorRampStop, ...]
    """The gradient's stops, in order along the bar, as the app gave them."""

    tick_interval: float
    """The value between adjacent ticks."""

    ticks: tuple[ColorRampTick, ...]
    """Every tick, from the range's minimum end of the bar to its maximum
    end."""

    label_alignment: Vector2
    """The point of each label's content that sits on its anchor, as a fraction
    of its width and height from its bottom-left corner, as
    ``BillboardPrimitive.alignment`` measures it. It puts each label beside
    the bar, on the side toward the viewport center, centered on its tick."""

    @classmethod
    def for_range(
        cls,
        *,
        min_value: float,
        max_value: float,
        stops: Sequence[ColorRampStop],
        viewport_size: Vector2,
        orientation: ColorRampOrientation = ColorRampOrientation.VERTICAL,
        placement: ViewportOverlayPlacement | None = None,
        tick_interval: float | None = None,
        unit: str | None = None,
        numbers: NumberFormatting = _DEFAULT_NUMBERS,
        bar_thickness_pixels: float = tokens.COLOR_RAMP_LEGEND_BAR_THICKNESS_PIXELS,
        min_tick_spacing_pixels: float = (
            tokens.COLOR_RAMP_LEGEND_MIN_TICK_SPACING_PIXELS
        ),
        label_gap_pixels: float = tokens.COLOR_RAMP_LEGEND_LABEL_GAP_PIXELS,
        label_height_pixels: float = tokens.COLOR_RAMP_LEGEND_LABEL_HEIGHT_PIXELS,
    ) -> Self:
        """Returns the legend for values from ``min_value`` to ``max_value``,
        whose gradient the app keys by ``stops``.

        The bar runs along ``orientation`` for the full length of
        ``placement``'s rectangle, ``bar_thickness_pixels`` thick, on the
        rectangle's edge nearer its corner. Its labels sit
        ``label_gap_pixels`` off the bar's other side, toward the viewport
        center.

        A tick marks every whole multiple of the tick interval inside the
        range. The interval is ``tick_interval`` when given, or else the
        smallest of 1, 2, and 5 times a power of ten that keeps adjacent ticks
        at least ``min_tick_spacing_pixels`` apart. Each label requests its
        value's text at ``label_height_pixels``, rounded to the interval and
        written with ``numbers``. A ``unit`` follows the first and last labels
        after a space.

        Raises ``ValueError`` when the range is not finite with ``min_value``
        below ``max_value``, when ``stops`` has fewer than two stops, does not
        run from 0 to 1, or descends, when ``tick_interval`` is given and is
        not positive and finite, when ``min_tick_spacing_pixels`` is not
        positive and finite, or when the placement leaves the bar no length.
        """
        if not (
            math.isfinite(min_value)
            and math.isfinite(max_value)
            and min_value < max_value
        ):
            raise ValueError(
                "the value range must be finite with min_value below max_value, "
                f"got {min_value!r} to {max_value!r}"
            )
        _check_stops(stops)
        if tick_interval is not None and not _is_positive(tick_interval):
            raise ValueError(
                f"tick_interval must be positive and finite, got {tick_interval!r}"
            )
        if not _is_positive(min_tick_spacing_pixels):
            raise ValueError(
                "min_tick_spacing_pixels must be positive and finite, "
                f"got {min_tick_spacing_pixels!r}"
            )

        p = placement or ViewportOverlayPlacement.of(
            ViewportOverlayKind.COLOR_RAMP_LEGEND
        )
        rect = p.rect(viewport_size)
        vertical = orientation is ColorRampOrientation.VERTICAL
        bar = _bar_rect(rect, p, vertical=vertical, thickness=bar_thickness_pixels)
        length_pixels = bar.bottom - bar.top if vertical else bar.right - bar.left
        if not length_pixels > 0:
            raise ValueError(
                f"placement must give the bar a positive length, got {placement!r}"
            )

        span = max_value - min_value
        interval = (
            nice_step_at_least(min_tick_spacing_pixels * span / length_pixels)
            if tick_interval is None
            else tick_interval
        )
        values = _tick_values(min_value, max_value, interval)
        texts = [format_number_label(v, step=interval, numbers=numbers) for v in values]
        if unit is not None and texts:
            texts[0] = f"{texts[0]} {unit}"
            # A lone tick is both endpoints, and carries the unit once.
            if len(texts) > 1:
                texts[-1] = f"{texts[-1]} {unit}"

        def anchor(position: float) -> Vector2:
            along = position * length_pixels
            if vertical:
                x = (
                    bar.left - label_gap_pixels
                    if p.corner.is_right
                    else bar.right + label_gap_pixels
                )
                return (x, bar.bottom - along)
            y = (
                bar.top - label_gap_pixels
                if p.corner.is_bottom
                else bar.bottom + label_gap_pixels
            )
            return (bar.left + along, y)

        ticks = []
        for value, text in zip(values, texts, strict=True):
            # A tick admitted by the range slack stays on the bar.
            position = min(max((value - min_value) / span, 0.0), 1.0)
            ticks.append(
                ColorRampTick(
                    value=value,
                    position=position,
                    label=TextRequest(text=text, height_pixels=label_height_pixels),
                    label_anchor=anchor(position),
                )
            )
        if vertical:
            alignment = (1.0 if p.corner.is_right else 0.0, 0.5)
        else:
            alignment = (0.5, 0.0 if p.corner.is_bottom else 1.0)
        return cls(
            rect=rect,
            bar_rect=bar,
            orientation=orientation,
            stops=tuple(stops),
            tick_interval=interval,
            ticks=tuple(ticks),
            label_alignment=alignment,
        )


def _is_positive(value: float) -> bool:
    return math.isfinite(value) and value > 0


def _check_stops(stops: Sequence[ColorRampStop]) -> None:
    if len(stops) < _MIN_STOPS:
        raise ValueError(f"stops must hold at least two stops, got {stops!r}")
    if stops[0].position != 0 or stops[-1].position != 1:
        raise ValueError(f"stops must run from 0 to 1, got {stops!r}")
    for before, after in zip(stops, stops[1:], strict=False):
        if not after.position >= before.position:
            raise ValueError(f"stops must not descend, got {stops!r}")


def _bar_rect(
    rect: ViewportRect,
    placement: ViewportOverlayPlacement,
    *,
    vertical: bool,
    thickness: float,
) -> ViewportRect:
    """Returns the bar's strip of ``rect``, on its edge nearer the corner."""
    if vertical:
        if placement.corner.is_right:
            return ViewportRect(
                rect.right - thickness, rect.top, rect.right, rect.bottom
            )
        return ViewportRect(rect.left, rect.top, rect.left + thickness, rect.bottom)
    if placement.corner.is_bottom:
        return ViewportRect(rect.left, rect.bottom - thickness, rect.right, rect.bottom)
    return ViewportRect(rect.left, rect.top, rect.right, rect.top + thickness)


def _tick_values(min_value: float, max_value: float, interval: float) -> list[float]:
    """Returns every whole multiple of ``interval`` from ``min_value`` to
    ``max_value``, ascending."""

    def slack(ratio: float) -> float:
        return _RANGE_SLACK * max(1.0, abs(ratio))

    low = min_value / interval
    high = max_value / interval
    first = math.ceil(low - slack(low))
    last = math.floor(high + slack(high))
    return [k * interval for k in range(first, last + 1)]
