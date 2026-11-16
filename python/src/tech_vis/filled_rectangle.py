"""Filled rectangles in the cardinal planes, and their outlines."""

import math
from enum import StrEnum

from tech_vis._vec import Vector3
from tech_vis.primitives import LinePrimitive, QuadPrimitive


class RectanglePlane(StrEnum):
    """Names the cardinal plane a rectangle lies in."""

    XY = "xy"
    XZ = "xz"
    YZ = "yz"


def rectangle_corners(
    *,
    center: Vector3,
    width: float,
    height: float,
    plane: RectanglePlane,
    rotation: float = 0.0,
) -> tuple[Vector3, Vector3, Vector3, Vector3]:
    """Returns the corners of a ``width`` by ``height`` rectangle in ``plane``.

    The corners run counterclockwise from the one at the plane's two minimum
    axes. Width runs along the plane's first axis and height along its second:
    X and Y for XY, X and Z for XZ, Y and Z for YZ. ``rotation`` turns the
    rectangle about ``center`` within the plane, in radians, from the first
    axis toward the second.
    """
    half_w = width / 2
    half_h = height / 2
    cos = math.cos(rotation)
    sin = math.sin(rotation)
    cx, cy, cz = center

    def corner(u: float, v: float) -> Vector3:
        ru = u * cos - v * sin
        rv = u * sin + v * cos
        match plane:
            case RectanglePlane.XY:
                return (cx + ru, cy + rv, cz)
            case RectanglePlane.XZ:
                return (cx + ru, cy, cz + rv)
            case RectanglePlane.YZ:
                return (cx, cy + ru, cz + rv)

    return (
        corner(-half_w, -half_h),
        corner(half_w, -half_h),
        corner(half_w, half_h),
        corner(-half_w, half_h),
    )


def create_filled_rectangle(
    *,
    center: Vector3,
    width: float,
    height: float,
    plane: RectanglePlane,
    key: object,
    opacity: float = 1.0,
    rotation: float = 0.0,
) -> QuadPrimitive:
    """Returns a filled rectangle as a quad, laid out by ``rectangle_corners``."""
    return QuadPrimitive(
        corners=rectangle_corners(
            center=center, width=width, height=height, plane=plane, rotation=rotation
        ),
        key=key,
        opacity=opacity,
    )


def create_rectangle_outline(
    quad: QuadPrimitive, *, width_pixels: float
) -> list[LinePrimitive]:
    """Returns the perimeter of ``quad`` as four lines, ``width_pixels`` wide.

    Each line runs from one corner to the next and carries the quad's key and
    opacity.
    """
    corners = quad.corners
    return [
        LinePrimitive(
            start=corners[i],
            end=corners[(i + 1) % len(corners)],
            width_pixels=width_pixels,
            key=quad.key,
            opacity=quad.opacity,
        )
        for i in range(len(corners))
    ]
