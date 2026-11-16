"""Scale bar overlay (§spec:scale-bar), ported from the Dart reference."""

import math
from dataclasses import dataclass
from typing import Self

from tech_vis import tokens
from tech_vis._vec import Vector2, Vector3
from tech_vis.primitives import TextRequest
from tech_vis.screen_space import CameraBasis, world_units_per_pixel_at
from tech_vis.unit_system import DisplayFormat, NumberFormatting, UnitSystem
from tech_vis.viewport_overlay import (
    ViewportOverlayKind,
    ViewportOverlayPlacement,
    ViewportRect,
)

# Relative slack when testing whether a step divides another into whole
# parts, since a ratio such as 0.5 / 0.1 lands off a whole number.
_RATIO_SLACK = 1e-9

# A default argument is built once; the formatting is frozen, so sharing it is
# safe.
_DEFAULT_NUMBERS = NumberFormatting()


@dataclass(frozen=True, slots=True, kw_only=True)
class ScaleBarLayout:
    """Holds a scale bar in viewport pixels, for the app to draw in its 2D
    layer above the scene.

    Every x and y is in the screen coordinates of ``world_to_screen``: pixels
    from the viewport's top-left corner, y down. Every length is in the base
    unit of the display format's unit system.
    """

    rect: ViewportRect
    """The overlay's rectangle, from its placement."""

    step: float
    """The length the bar represents."""

    tick_step: float
    """The length between adjacent ticks; equal to ``step`` when the bar has
    no subdivision."""

    start_x: float
    """The x of the bar's left end, on the rectangle's edge nearer its
    corner."""

    end_x: float
    """The x of the bar's right end."""

    baseline_y: float
    """The y the bar and its ticks stand on: the rectangle's bottom edge."""

    tick_xs: tuple[float, ...]
    """The x of every tick, from ``start_x`` to ``end_x`` inclusive,
    ascending."""

    label: TextRequest
    """The bar's value label, as text for the app to set."""

    label_anchor: Vector2
    """Where the label's top center sits: above the bar's midpoint, on the
    rectangle's top edge."""

    @classmethod
    def at_target(
        cls,
        *,
        camera: CameraBasis,
        target: Vector3,
        vertical_fov_radians: float,
        viewport_size: Vector2,
        world_units: UnitSystem,
        display_format: DisplayFormat,
        placement: ViewportOverlayPlacement | None = None,
        previous_step: float | None = None,
        numbers: NumberFormatting = _DEFAULT_NUMBERS,
        min_tick_spacing_pixels: float = tokens.SCALE_BAR_MIN_TICK_SPACING_PIXELS,
        hysteresis: float = tokens.SCALE_BAR_STEP_HYSTERESIS,
        label_height_pixels: float = tokens.SCALE_BAR_LABEL_HEIGHT_PIXELS,
    ) -> Self | None:
        """Returns the scale bar for ``camera`` looking at ``target``, or None
        when the bar has no length to show.

        The bar measures at ``target``. Its value is the longest scale-bar
        step of ``display_format`` whose length at ``target`` fits within the
        width of ``placement``'s rectangle. World lengths are in
        ``world_units``.

        Pass the previous frame's ``step`` as ``previous_step`` to keep the
        value from flickering at a step boundary: the bar keeps that step
        while it fits, and adopts a longer step only once it fits within the
        width less a ``hysteresis`` fraction of it. A ``previous_step`` that
        is not a step of ``display_format`` is ignored.

        The bar subdivides into the most equal parts, each itself a scale-bar
        step, whose ticks stay at least ``min_tick_spacing_pixels`` apart. Its
        label requests ``step``'s text at ``label_height_pixels``.

        Returns None when ``target`` is on or behind the camera plane, or when
        even the shortest step is longer than the width. Raises
        ``ValueError`` when ``min_tick_spacing_pixels`` is not positive and
        finite, or when ``hysteresis`` is not in [0, 1).
        """
        if not math.isfinite(min_tick_spacing_pixels) or min_tick_spacing_pixels <= 0:
            raise ValueError(
                "min_tick_spacing_pixels must be positive and finite, "
                f"got {min_tick_spacing_pixels!r}"
            )
        if not 0 <= hysteresis < 1:
            raise ValueError(
                f"hysteresis must be at least 0 and less than 1, got {hysteresis!r}"
            )
        world_per_pixel = world_units_per_pixel_at(
            target, camera, vertical_fov_radians, viewport_size[1]
        )
        if world_per_pixel is None:
            return None
        units_per_pixel = world_units.convert_to(
            world_per_pixel, display_format.unit_system
        )

        p = placement or ViewportOverlayPlacement.of(ViewportOverlayKind.SCALE_BAR)
        rect = p.rect(viewport_size)
        max_length = (rect.right - rect.left) * units_per_pixel
        fitting = display_format.scale_bar_step_at_most(max_length)
        if fitting is None:
            return None

        kept = _kept(display_format, previous_step, fitting, max_length, hysteresis)
        step = fitting if kept is None else kept
        tick_step = _tick_step(
            display_format, step, min_tick_spacing_pixels * units_per_pixel
        )

        length_pixels = step / units_per_pixel
        start_x = rect.right - length_pixels if p.corner.is_right else rect.left
        parts = round(step / tick_step)
        (label,) = display_format.format_labels([step], step=step, numbers=numbers)
        return cls(
            rect=rect,
            step=step,
            tick_step=tick_step,
            start_x=start_x,
            end_x=start_x + length_pixels,
            baseline_y=rect.bottom,
            tick_xs=tuple(
                start_x + i * length_pixels / parts for i in range(parts + 1)
            ),
            label=TextRequest(text=label, height_pixels=label_height_pixels),
            label_anchor=(start_x + length_pixels / 2, rect.top),
        )


def _kept(
    display_format: DisplayFormat,
    previous: float | None,
    fitting: float,
    max_length: float,
    hysteresis: float,
) -> float | None:
    """Returns the step the bar keeps from ``previous``, or None when it moves
    to ``fitting``, the longest step within ``max_length``.

    Every comparison is between steps the step queries return exactly, so
    none needs slack.
    """
    if previous is None or not display_format.is_scale_bar_step(previous):
        return None
    step = display_format.scale_bar_step_at_most(previous)
    if step is None or step > fitting:
        return None
    clearing = display_format.scale_bar_step_at_most(max_length * (1 - hysteresis))
    return step if clearing is None or clearing <= step else None


def _tick_step(display_format: DisplayFormat, step: float, min_spacing: float) -> float:
    """Returns the shortest scale-bar step that divides ``step`` into whole
    parts at least ``min_spacing`` long, or ``step`` when none does."""
    best = step
    part = display_format.scale_bar_step_below(step)
    while part is not None and part >= min_spacing:
        ratio = step / part
        if abs(ratio - round(ratio)) <= ratio * _RATIO_SLACK:
            best = part
        part = display_format.scale_bar_step_below(part)
    return best
