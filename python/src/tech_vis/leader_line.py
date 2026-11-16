"""Leader-line callout layout, ported from the Dart reference.

A leader line connects an anchor point to a label through a gap, an angled
segment, and a horizontal segment, laid out in the camera's screen plane.
Every function here agrees with ``vectors/leader_line.json``.
"""

import math
from dataclasses import dataclass
from enum import StrEnum

from tech_vis import tokens
from tech_vis._vec import Vector2, Vector3, along, scale
from tech_vis.primitives import (
    BillboardContent,
    BillboardPrimitive,
    LinePrimitive,
)


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

    width_pixels: float
    """Width of the leader's lines in screen pixels, from its style."""


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


def callout_leader_direction(
    quadrant: CalloutQuadrant, *, style: LeaderLineStyle = _DEFAULT_STYLE
) -> Vector2:
    """Returns the unit screen direction, y up, in which a leader leaves its anchor.

    The direction lies ``style.angle_degrees`` above or below the horizontal,
    toward the corner of ``quadrant``.
    """
    angle = math.radians(style.angle_degrees)
    h_sign, v_sign = _QUADRANT_SIGNS[quadrant]
    return (math.cos(angle) * h_sign, math.sin(angle) * v_sign)


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
    h_sign, _ = _QUADRANT_SIGNS[quadrant]
    right_scale, up_scale = callout_leader_direction(quadrant, style=style)

    angled = along(scale(camera_right, right_scale), camera_up, up_scale)
    horizontal = scale(camera_right, h_sign)

    gap_end = along(anchor, angled, style.gap_pixels * world_units_per_pixel)
    elbow = along(gap_end, angled, style.angled_length_pixels * world_units_per_pixel)
    label_edge = along(
        elbow, horizontal, style.horizontal_length_pixels * world_units_per_pixel
    )
    return CalloutLeaderGeometry(
        gap_end=gap_end,
        elbow=elbow,
        label_edge=label_edge,
        width_pixels=style.line_width,
    )


def callout_anchor_alignment(quadrant: CalloutQuadrant) -> Vector2:
    """Returns where a callout label anchors to its leader line's end.

    The result is a UV coordinate on the label, from (0, 0) to (1, 1).
    """
    h_sign, _ = _QUADRANT_SIGNS[quadrant]
    return _LEFT_EDGE_MIDDLE if h_sign > 0 else _RIGHT_EDGE_MIDDLE


def create_callout_leader_lines(
    leader: CalloutLeaderGeometry, *, key: object, opacity: float
) -> list[LinePrimitive]:
    """Returns the two lines a renderer draws for ``leader``.

    The angled segment runs from the gap end to the elbow, then the horizontal
    segment from the elbow to the label edge. Both take the leader's own pixel
    width and carry ``key`` and ``opacity``. The leader moves with the camera,
    so the lines are rebuilt each frame with it.
    """
    return [
        LinePrimitive(
            start=start,
            end=end,
            width_pixels=leader.width_pixels,
            key=key,
            opacity=opacity,
        )
        for start, end in (
            (leader.gap_end, leader.elbow),
            (leader.elbow, leader.label_edge),
        )
    ]


def create_callout_label(
    leader: CalloutLeaderGeometry,
    quadrant: CalloutQuadrant,
    *,
    content: BillboardContent,
    key: object,
    opacity: float,
) -> BillboardPrimitive:
    """Returns the callout's label, a viewer-facing billboard at the leader's end.

    ``callout_anchor_alignment`` of ``quadrant`` aligns ``content`` so it extends
    away from the leader. ``content`` is the app's, sized in pixels, such as the
    answer to a ``TextRequest``. ``opacity`` is typically
    ``compute_callout_opacity`` of the anchor's distance.
    """
    return BillboardPrimitive(
        content=content,
        anchor=leader.label_edge,
        alignment=callout_anchor_alignment(quadrant),
        key=key,
        opacity=opacity,
    )


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
