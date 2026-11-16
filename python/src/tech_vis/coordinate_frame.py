"""Coordinate frames: an axis indicator at any origin, as lines and labels."""

from collections.abc import Callable
from dataclasses import dataclass

from tech_vis import _vec, tokens
from tech_vis._vec import Vector3
from tech_vis.coordinate_convention import SpatialAxis
from tech_vis.primitives import (
    BillboardPrimitive,
    LinePrimitive,
    Primitive,
    ScreenOffset,
    TextRequest,
    TextResolver,
)

_ORIGIN: Vector3 = (0.0, 0.0, 0.0)


@dataclass(frozen=True, slots=True, kw_only=True)
class AxisLineDescriptor:
    """Holds one axis line of a coordinate frame."""

    axis: SpatialAxis
    start: Vector3
    end: Vector3
    thickness: float
    """Line thickness in screen-space logical pixels."""

    @property
    def label(self) -> str:
        return self.axis.label

    @property
    def direction(self) -> Vector3:
        return self.axis.unit_vector


@dataclass(frozen=True, slots=True, kw_only=True)
class CoordinateFrameDescriptor:
    """Describes a coordinate frame: an origin with three axis lines and labels.

    The defaults are the style tokens.
    """

    origin: Vector3 = _ORIGIN
    length: float = tokens.AXIS_LENGTH
    """Length of each axis line in world units."""

    line_thickness: float = tokens.DEFAULT_AXIS_LINE_THICKNESS
    """Line thickness in screen-space logical pixels."""

    show_labels: bool = True
    label_pixel_size: float = tokens.DEFAULT_AXIS_LABEL_SIZE
    label_offset_pixels: float = tokens.AXIS_LABEL_OFFSET_PIXELS
    """Screen-space offset from an axis end to its label center, in pixels."""

    @property
    def axes(self) -> list[AxisLineDescriptor]:
        """Returns the X, Y, and Z axis lines, each ``length`` from the origin."""
        return [
            AxisLineDescriptor(
                axis=axis,
                start=self.origin,
                end=_vec.along(self.origin, axis.unit_vector, self.length),
                thickness=self.line_thickness,
            )
            for axis in SpatialAxis
        ]


def create_coordinate_frame(
    frame: CoordinateFrameDescriptor,
    *,
    key_for: Callable[[SpatialAxis], object],
    resolve_text: TextResolver,
    label_key_for: Callable[[SpatialAxis], object] | None = None,
) -> list[Primitive]:
    """Returns the primitives that draw ``frame``.

    Emits one line per axis, from the origin to the axis end, in X, Y, Z
    order. When the frame shows labels, then emits one viewer-facing billboard
    per axis end, offset along the axis on screen by the frame's label offset.
    Each label requests the axis letter at the frame's label pixel height, and
    ``resolve_text`` answers with the app's content for it.

    ``key_for`` gives each axis line its app key. ``label_key_for`` gives each
    label its key, and defaults to ``key_for``.
    """
    axes = frame.axes
    label_key = label_key_for or key_for
    primitives: list[Primitive] = [
        LinePrimitive(
            start=a.start, end=a.end, width_pixels=a.thickness, key=key_for(a.axis)
        )
        for a in axes
    ]
    if frame.show_labels:
        primitives += [
            BillboardPrimitive(
                content=resolve_text(
                    TextRequest(text=a.label, height_pixels=frame.label_pixel_size)
                ),
                anchor=a.end,
                offset=ScreenOffset(
                    direction=a.direction, pixels=frame.label_offset_pixels
                ),
                key=label_key(a.axis),
            )
            for a in axes
        ]
    return primitives
