"""Overlay placement in the viewport (§spec:viewport-overlays)."""

from __future__ import annotations

import math
from dataclasses import dataclass, replace
from enum import Enum
from typing import NamedTuple

from tech_vis import tokens


class ViewportCorner(Enum):
    """A corner of the viewport that an overlay anchors to.

    Each value is the corner's style token code.
    """

    TOP_LEFT = 0
    TOP_RIGHT = 1
    BOTTOM_LEFT = 2
    BOTTOM_RIGHT = 3

    @classmethod
    def from_token(cls, code: float) -> ViewportCorner:
        """Returns the corner whose style token code is ``code``.

        Raises ``ValueError`` when ``code`` is not 0, 1, 2, or 3.
        """
        # A code is a corner's index; NaN and fractions fail the round trip.
        index = int(code) if math.isfinite(code) else -1
        if index != code or index not in range(len(cls)):
            raise ValueError(f"not a viewport corner code: {code!r}")
        return cls(index)

    @property
    def is_right(self) -> bool:
        """Whether the corner is on the viewport's right edge."""
        return self in (ViewportCorner.TOP_RIGHT, ViewportCorner.BOTTOM_RIGHT)

    @property
    def is_bottom(self) -> bool:
        """Whether the corner is on the viewport's bottom edge."""
        return self in (ViewportCorner.BOTTOM_LEFT, ViewportCorner.BOTTOM_RIGHT)


class ViewportOverlayKind(Enum):
    """An overlay whose default placement the style holds."""

    SCALE_BAR = "scaleBar"
    COLOR_RAMP_LEGEND = "colorRampLegend"
    NAVIGATION_CUBE = "navigationCube"


class ViewportRect(NamedTuple):
    """A rectangle in viewport pixels, origin top-left, y running down."""

    left: float
    top: float
    right: float
    bottom: float


@dataclass(frozen=True, slots=True)
class ViewportOverlayPlacement:
    """Where an overlay sits: a corner, an offset from it, and a size, in pixels.

    The offset points from the corner toward the viewport center, so the same
    offset keeps an overlay the same distance from its edges in any corner.
    """

    corner: ViewportCorner
    offset_x_pixels: float
    offset_y_pixels: float
    width_pixels: float
    height_pixels: float

    @classmethod
    def of(
        cls,
        kind: ViewportOverlayKind,
        *,
        corner: ViewportCorner | None = None,
        offset_x_pixels: float | None = None,
        offset_y_pixels: float | None = None,
        width_pixels: float | None = None,
        height_pixels: float | None = None,
    ) -> ViewportOverlayPlacement:
        """Returns the style's placement for ``kind``.

        Each given value takes the place of its token default.
        """
        overrides = {
            "corner": corner,
            "offset_x_pixels": offset_x_pixels,
            "offset_y_pixels": offset_y_pixels,
            "width_pixels": width_pixels,
            "height_pixels": height_pixels,
        }
        return replace(
            _DEFAULTS[kind],
            **{name: value for name, value in overrides.items() if value is not None},
        )

    def rect(self, viewport_size: tuple[float, float]) -> ViewportRect:
        """Returns the overlay's rectangle in a viewport of (width, height) pixels.

        The rectangle is not clipped, so it extends past the viewport when the
        viewport is too small to hold it.
        """
        width, height = viewport_size
        left = (
            width - self.offset_x_pixels - self.width_pixels
            if self.corner.is_right
            else self.offset_x_pixels
        )
        top = (
            height - self.offset_y_pixels - self.height_pixels
            if self.corner.is_bottom
            else self.offset_y_pixels
        )
        return ViewportRect(
            left, top, left + self.width_pixels, top + self.height_pixels
        )


def _default(
    corner: float, offset_x: float, offset_y: float, width: float, height: float
) -> ViewportOverlayPlacement:
    return ViewportOverlayPlacement(
        corner=ViewportCorner.from_token(corner),
        offset_x_pixels=offset_x,
        offset_y_pixels=offset_y,
        width_pixels=width,
        height_pixels=height,
    )


_DEFAULTS: dict[ViewportOverlayKind, ViewportOverlayPlacement] = {
    ViewportOverlayKind.SCALE_BAR: _default(
        tokens.SCALE_BAR_CORNER,
        tokens.SCALE_BAR_OFFSET_XPIXELS,
        tokens.SCALE_BAR_OFFSET_YPIXELS,
        tokens.SCALE_BAR_WIDTH_PIXELS,
        tokens.SCALE_BAR_HEIGHT_PIXELS,
    ),
    ViewportOverlayKind.COLOR_RAMP_LEGEND: _default(
        tokens.COLOR_RAMP_LEGEND_CORNER,
        tokens.COLOR_RAMP_LEGEND_OFFSET_XPIXELS,
        tokens.COLOR_RAMP_LEGEND_OFFSET_YPIXELS,
        tokens.COLOR_RAMP_LEGEND_WIDTH_PIXELS,
        tokens.COLOR_RAMP_LEGEND_HEIGHT_PIXELS,
    ),
    ViewportOverlayKind.NAVIGATION_CUBE: _default(
        tokens.NAVIGATION_CUBE_CORNER,
        tokens.NAVIGATION_CUBE_OFFSET_XPIXELS,
        tokens.NAVIGATION_CUBE_OFFSET_YPIXELS,
        tokens.NAVIGATION_CUBE_WIDTH_PIXELS,
        tokens.NAVIGATION_CUBE_HEIGHT_PIXELS,
    ),
}
