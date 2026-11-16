"""Text labels attached to the top face of a bounding box.

Directions come from the declared coordinate convention. The top face is the
box's maximum along the up axis. Back is the convention's fallback axis, the
direction a top view keeps up on screen, and right is the text direction,
back cross up by the declared hand rule, so a label reads left to right in a
top view.
"""

from dataclasses import dataclass
from enum import StrEnum

from tech_vis import _vec
from tech_vis._vec import Vector2, Vector3
from tech_vis.bounding_box import BoundingBox
from tech_vis.coordinate_convention import CoordinateConvention
from tech_vis.primitives import (
    BillboardPrimitive,
    CoplanarOrientation,
    ScreenOffset,
    TextRequest,
    TextResolver,
)
from tech_vis.screen_space import CameraBasis

ENVELOPE_LABEL_PIXEL_SIZE = 20.0
"""Default pixel height of an envelope label."""

ENVELOPE_LABEL_OFFSET_PIXELS = 8.0
"""Default screen-space offset of an envelope label from its corner, in pixels."""

_ORIGIN: Vector3 = (0.0, 0.0, 0.0)
_CENTERED: Vector2 = (0.5, 0.5)


class LabelCorner(StrEnum):
    """Names a corner of a box's top face, as seen in a top view."""

    TOP_FRONT_LEFT = "topFrontLeft"
    TOP_FRONT_RIGHT = "topFrontRight"
    TOP_BACK_LEFT = "topBackLeft"
    TOP_BACK_RIGHT = "topBackRight"


class LabelEdge(StrEnum):
    """Names the top-face edge a label tab attaches to, as seen in a top view."""

    FRONT = "front"
    """Edge nearest the bottom of a top view."""

    BACK = "back"
    """Edge nearest the top of a top view."""


class LabelAlignment(StrEnum):
    """Names a label's position along its edge, in its text direction."""

    LEFT = "left"
    CENTER = "center"
    RIGHT = "right"


# (right sign, back sign) of each corner.
_CORNER_SIGNS = {
    LabelCorner.TOP_FRONT_LEFT: (-1.0, -1.0),
    LabelCorner.TOP_FRONT_RIGHT: (1.0, -1.0),
    LabelCorner.TOP_BACK_LEFT: (-1.0, 1.0),
    LabelCorner.TOP_BACK_RIGHT: (1.0, 1.0),
}
_ALIGNMENT_SIGNS = {
    LabelAlignment.LEFT: -1.0,
    LabelAlignment.CENTER: 0.0,
    LabelAlignment.RIGHT: 1.0,
}
_EDGE_SIGNS = {LabelEdge.FRONT: -1.0, LabelEdge.BACK: 1.0}

# Where a tab's content meets the edge: its edge, not its center, sits on the
# boundary, so the tab extends outward from the box.
_TAB_ANCHOR_X = {
    LabelAlignment.LEFT: 0.0,
    LabelAlignment.CENTER: 0.5,
    LabelAlignment.RIGHT: 1.0,
}
_TAB_ANCHOR_Y = {LabelEdge.FRONT: 1.0, LabelEdge.BACK: 0.0}


@dataclass(frozen=True, slots=True)
class _LabelFrame:
    """Unit directions of a label on a top face.

    They are the axes of the package's own top-view camera, so a label reads
    left to right in the same top view that ``CameraBasis.look_at`` builds.
    """

    up: Vector3
    back: Vector3
    right: Vector3

    @classmethod
    def of(cls, convention: CoordinateConvention) -> "_LabelFrame":
        top_view = CameraBasis.look_at(
            position=convention.up.unit_vector, target=_ORIGIN, convention=convention
        )
        return cls(up=top_view.to_viewer, back=top_view.up, right=top_view.right)

    def toward(self, *, right: float, back: float) -> Vector3:
        """Returns the top-face direction ``right`` and ``back`` steps along."""
        return _vec.add(
            _vec.add(self.up, _vec.scale(self.right, right)),
            _vec.scale(self.back, back),
        )


def _extreme_point(bounds: BoundingBox, direction: Vector3) -> Vector3:
    """Returns the point of ``bounds`` farthest along ``direction``.

    An axis that ``direction`` leaves at zero takes the center, so a sum of
    signed unit axes picks a corner, an edge midpoint, or a face center.
    """
    lo, hi = bounds.min_bounds, bounds.max_bounds

    def pick(i: int) -> float:
        if direction[i] > 0:
            return hi[i]
        if direction[i] < 0:
            return lo[i]
        return (lo[i] + hi[i]) / 2

    return (pick(0), pick(1), pick(2))


def create_envelope_label(
    *,
    text: str,
    bounds: BoundingBox,
    corner: LabelCorner,
    convention: CoordinateConvention,
    resolve_text: TextResolver,
    key: object,
    pixel_size: float = ENVELOPE_LABEL_PIXEL_SIZE,
    offset_pixels: float = ENVELOPE_LABEL_OFFSET_PIXELS,
) -> BillboardPrimitive:
    """Returns a viewer-facing label at ``corner`` of the top face of ``bounds``.

    The label is ``pixel_size`` pixels tall and sits ``offset_pixels`` pixels
    from the corner on screen, outward from the box.
    """
    right_sign, back_sign = _CORNER_SIGNS[corner]
    outward = _LabelFrame.of(convention).toward(right=right_sign, back=back_sign)
    return BillboardPrimitive(
        content=resolve_text(TextRequest(text=text, height_pixels=pixel_size)),
        anchor=_extreme_point(bounds, outward),
        offset=ScreenOffset(direction=_vec.normalized(outward), pixels=offset_pixels),
        key=key,
    )


def create_coplanar_billboard_label(
    *,
    text: str,
    position: Vector3,
    convention: CoordinateConvention,
    resolve_text: TextResolver,
    key: object,
    pixel_size: float = ENVELOPE_LABEL_PIXEL_SIZE,
    surface_normal: Vector3 | None = None,
    text_direction: Vector3 | None = None,
    anchor_alignment: Vector2 = _CENTERED,
) -> BillboardPrimitive:
    """Returns a label at ``position`` lying flat in the plane of ``surface_normal``.

    The normal defaults to the up axis of ``convention`` and the text direction
    to its right direction, so the label lies on a top face. The label is
    ``pixel_size`` pixels tall viewed along the normal and foreshortens with
    perspective at oblique angles. ``anchor_alignment`` is the point of the
    label that sits on ``position``.
    """
    if surface_normal is None or text_direction is None:
        frame = _LabelFrame.of(convention)
        if surface_normal is None:
            surface_normal = frame.up
        if text_direction is None:
            text_direction = frame.right
    return BillboardPrimitive(
        content=resolve_text(TextRequest(text=text, height_pixels=pixel_size)),
        anchor=position,
        orientation=CoplanarOrientation(normal=surface_normal, right=text_direction),
        alignment=anchor_alignment,
        key=key,
    )


def create_edge_tab_label(
    *,
    text: str,
    bounds: BoundingBox,
    edge: LabelEdge,
    alignment: LabelAlignment,
    convention: CoordinateConvention,
    resolve_text: TextResolver,
    key: object,
    pixel_size: float = ENVELOPE_LABEL_PIXEL_SIZE,
) -> BillboardPrimitive:
    """Returns a coplanar label on ``edge`` of the top face of ``bounds``.

    The label's edge, not its center, sits on the boundary, like a tab
    attached to the envelope.
    """
    frame = _LabelFrame.of(convention)
    direction = frame.toward(right=_ALIGNMENT_SIGNS[alignment], back=_EDGE_SIGNS[edge])
    return create_coplanar_billboard_label(
        text=text,
        position=_extreme_point(bounds, direction),
        convention=convention,
        resolve_text=resolve_text,
        key=key,
        pixel_size=pixel_size,
        surface_normal=frame.up,
        text_direction=frame.right,
        anchor_alignment=(_TAB_ANCHOR_X[alignment], _TAB_ANCHOR_Y[edge]),
    )
