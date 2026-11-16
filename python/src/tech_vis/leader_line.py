"""Leader-line callout layout, ported from the Dart reference.

A leader line connects an anchor point to a label through a gap, an angled
segment, and a horizontal segment, laid out in the camera's screen plane.
Every function here agrees with ``vectors/leader_line.json``.
"""

import math
from dataclasses import dataclass
from enum import StrEnum

from tech_vis import tokens

type Vector2 = tuple[float, float]
type Vector3 = tuple[float, float, float]


class CalloutQuadrant(StrEnum):
    """Names the screen quadrant a callout's leader line heads into.

    Each value is the quadrant's name in the golden vectors and in the Dart
    package, so ``CalloutQuadrant("topRight")`` parses a fixture entry.
    """

    TOP_RIGHT = "topRight"
    TOP_LEFT = "topLeft"
    BOTTOM_RIGHT = "bottomRight"
    BOTTOM_LEFT = "bottomLeft"


@dataclass(frozen=True, slots=True)
class LeaderLineStyle:
    """Holds the visual parameters of a leader line.

    Lengths are screen-space logical pixels. The defaults are the style tokens.
    """

    line_width: float = tokens.CALLOUT_LEADER_LINE_WIDTH
    gap_pixels: float = tokens.CALLOUT_GAP_PIXELS
    angled_length_pixels: float = tokens.CALLOUT_ANGLED_LENGTH_PIXELS
    horizontal_length_pixels: float = tokens.CALLOUT_HORIZONTAL_LENGTH_PIXELS
    angle_degrees: float = tokens.CALLOUT_ANGLE_DEGREES


# A default argument is built once; the style is frozen, so sharing it is safe.
_DEFAULT_STYLE = LeaderLineStyle()


@dataclass(frozen=True, slots=True)
class CalloutLeaderGeometry:
    """Holds the three world-space control points of a leader-line polyline."""

    gap_end: Vector3
    """Start of the visible leader line, after the gap from the anchor."""

    elbow: Vector3
    """Bend where the angled segment meets the horizontal segment."""

    label_edge: Vector3
    """End of the leader line, where the label is anchored."""


# Horizontal and vertical direction signs for each quadrant.
_QUADRANT_SIGNS: dict[CalloutQuadrant, tuple[float, float]] = {
    CalloutQuadrant.TOP_RIGHT: (1.0, 1.0),
    CalloutQuadrant.TOP_LEFT: (-1.0, 1.0),
    CalloutQuadrant.BOTTOM_RIGHT: (1.0, -1.0),
    CalloutQuadrant.BOTTOM_LEFT: (-1.0, -1.0),
}

# A label to the right of its leader hangs from its left edge, and vice versa.
_LEFT_EDGE_MIDDLE: Vector2 = (0.0, 0.5)
_RIGHT_EDGE_MIDDLE: Vector2 = (1.0, 0.5)


def _along(origin: Vector3, direction: Vector3, distance: float) -> Vector3:
    return (
        origin[0] + direction[0] * distance,
        origin[1] + direction[1] * distance,
        origin[2] + direction[2] * distance,
    )


def compute_callout_leader_geometry(
    *,
    anchor: Vector3,
    camera_right: Vector3,
    camera_up: Vector3,
    world_units_per_pixel: float,
    quadrant: CalloutQuadrant,
    style: LeaderLineStyle = _DEFAULT_STYLE,
) -> CalloutLeaderGeometry:
    """Returns the leader line for a callout at ``anchor``, in world space.

    The line is laid out in the screen plane that ``camera_right`` and
    ``camera_up`` span. ``world_units_per_pixel`` converts the pixel lengths
    in ``style`` to world distances at the anchor's depth.
    """
    angle = math.radians(style.angle_degrees)
    h_sign, v_sign = _QUADRANT_SIGNS[quadrant]
    right_scale = math.cos(angle) * h_sign
    up_scale = math.sin(angle) * v_sign

    angled: Vector3 = (
        camera_right[0] * right_scale + camera_up[0] * up_scale,
        camera_right[1] * right_scale + camera_up[1] * up_scale,
        camera_right[2] * right_scale + camera_up[2] * up_scale,
    )
    horizontal: Vector3 = (
        camera_right[0] * h_sign,
        camera_right[1] * h_sign,
        camera_right[2] * h_sign,
    )

    gap_end = _along(anchor, angled, style.gap_pixels * world_units_per_pixel)
    elbow = _along(gap_end, angled, style.angled_length_pixels * world_units_per_pixel)
    label_edge = _along(
        elbow, horizontal, style.horizontal_length_pixels * world_units_per_pixel
    )
    return CalloutLeaderGeometry(gap_end=gap_end, elbow=elbow, label_edge=label_edge)


def callout_anchor_alignment(quadrant: CalloutQuadrant) -> Vector2:
    """Returns where a callout label anchors to its leader line's end.

    The result is a UV coordinate on the label, from (0, 0) to (1, 1).
    """
    h_sign, _ = _QUADRANT_SIGNS[quadrant]
    return _LEFT_EDGE_MIDDLE if h_sign > 0 else _RIGHT_EDGE_MIDDLE


def compute_callout_opacity(distance: float) -> float:
    """Returns a callout's opacity for its anchor's distance from the camera.

    The opacity holds at ``tokens.CALLOUT_OPACITY_MAX`` up to the near
    distance, falls linearly, and holds at ``tokens.CALLOUT_OPACITY_MIN``
    from the far distance on.
    """
    near = tokens.CALLOUT_OPACITY_NEAR_DISTANCE
    far = tokens.CALLOUT_OPACITY_FAR_DISTANCE
    if distance <= near:
        return tokens.CALLOUT_OPACITY_MAX
    if distance >= far:
        return tokens.CALLOUT_OPACITY_MIN
    t = (distance - near) / (far - near)
    return tokens.CALLOUT_OPACITY_MAX + t * (
        tokens.CALLOUT_OPACITY_MIN - tokens.CALLOUT_OPACITY_MAX
    )
