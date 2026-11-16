"""Camera basis and screen-space math (§spec:screen-space-placement).

Every function assumes one perspective camera model, so a size and a position
computed for the same frame agree.
"""

import math
from dataclasses import dataclass
from typing import Self

from tech_vis import _vec
from tech_vis._vec import Vector2, Vector3
from tech_vis.coordinate_convention import CoordinateConvention

# Above this |forward . up|, the view looks along the declared up axis and
# ``CameraBasis.look_at`` switches to the fallback axis.
_GIMBAL_THRESHOLD = 0.99

# Depth at or below which a point is on or behind the camera plane, where it
# has no finite screen size.
_MIN_VISIBLE_DEPTH = 1e-9

# Below this length, a projected offset direction counts as zero.
_MIN_PROJECTED_LENGTH = 1e-6


@dataclass(frozen=True, slots=True, kw_only=True)
class CameraBasis:
    """Holds a camera's position and orthonormal view axes in world space."""

    position: Vector3
    forward: Vector3
    """Unit view direction, from the camera toward what it looks at."""

    right: Vector3
    """Unit screen-right axis."""

    up: Vector3
    """Unit screen-up axis."""

    @classmethod
    def look_at(
        cls,
        *,
        position: Vector3,
        target: Vector3,
        convention: CoordinateConvention,
    ) -> Self:
        """Returns the basis of a camera at ``position`` looking at ``target``.

        The declared up axis orients the camera. When the view direction
        nearly parallels it, the convention's fallback axis takes its place,
        so the basis stays well defined. The handedness decides which way
        screen right points.
        """
        forward = _vec.normalized(_vec.sub(target, position))
        preferred_up = convention.up.unit_vector
        up_reference = (
            convention.fallback_axis.unit_vector
            if abs(_vec.dot(forward, preferred_up)) > _GIMBAL_THRESHOLD
            else preferred_up
        )
        right = _vec.normalized(convention.cross(forward, up_reference))
        up = _vec.normalized(convention.cross(right, forward))
        return cls(position=position, forward=forward, right=right, up=up)

    @property
    def to_viewer(self) -> Vector3:
        """Returns the unit axis from the screen plane toward the viewer."""
        return _vec.scale(self.forward, -1.0)

    def depth_of(self, point: Vector3) -> float:
        """Returns the distance of ``point`` in front of the camera.

        Perspective scales a point by this depth along the view axis, not by
        its straight-line distance from the camera.
        """
        return _vec.dot(_vec.sub(point, self.position), self.forward)


def world_units_per_pixel_at(
    point: Vector3,
    camera: CameraBasis,
    vertical_fov_radians: float,
    viewport_height: float,
) -> float | None:
    """Returns the world size of one screen pixel at ``point``.

    Sizing by depth along the view axis keeps a screen-space element at the
    same pixel size anywhere in the view. Returns None for a point on or
    behind the camera plane.
    """
    depth = camera.depth_of(point)
    if depth <= _MIN_VISIBLE_DEPTH:
        return None
    return 2.0 * depth * math.tan(vertical_fov_radians / 2.0) / viewport_height


def world_to_screen(
    point: Vector3,
    camera: CameraBasis,
    vertical_fov_radians: float,
    viewport_size: Vector2,
) -> Vector2 | None:
    """Returns the pixel position of ``point`` in a ``viewport_size`` viewport.

    The origin is the viewport's top-left corner, x runs right and y runs
    down. A renderer measures a frame in these coordinates to compare it with
    the reference fixtures. Returns None for a point on or behind the camera
    plane.
    """
    width, height = viewport_size
    # One pixel spans world_units_per_pixel_at at the point's depth, so the
    # projection and the pixel scale agree, and return None together.
    size = world_units_per_pixel_at(point, camera, vertical_fov_radians, height)
    if size is None:
        return None
    relative = _vec.sub(point, camera.position)
    return (
        width / 2.0 + _vec.dot(relative, camera.right) / size,
        height / 2.0 - _vec.dot(relative, camera.up) / size,
    )


def project_onto_screen_plane(direction: Vector3, camera: CameraBasis) -> Vector3:
    """Returns ``direction`` with its component along the view axis removed."""
    forward = camera.forward
    return _vec.sub(direction, _vec.scale(forward, _vec.dot(direction, forward)))


def billboard_offset_position(
    *,
    anchor: Vector3,
    direction: Vector3,
    offset_pixels: float,
    world_units_per_pixel: float,
    camera: CameraBasis,
) -> Vector3:
    """Returns ``anchor`` offset by pixels along ``direction`` as seen on screen.

    A ``direction`` along the view axis has no on-screen extent, so the
    billboard then stays at ``anchor``.
    """
    projected = project_onto_screen_plane(direction, camera)
    if _vec.length(projected) <= _MIN_PROJECTED_LENGTH:
        return anchor
    return _vec.along(
        anchor, _vec.normalized(projected), offset_pixels * world_units_per_pixel
    )
