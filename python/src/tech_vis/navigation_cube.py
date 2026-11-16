"""Navigation cube overlay (§spec:navigation-cube), ported from the Dart
reference."""

import math
from collections.abc import Callable
from dataclasses import dataclass, field
from enum import StrEnum
from typing import NamedTuple

from tech_vis import _vec
from tech_vis._vec import Vector2, Vector3
from tech_vis.coordinate_convention import CoordinateConvention, SignedAxis
from tech_vis.screen_space import CameraBasis
from tech_vis.viewport_overlay import ViewportRect

# At or below this cosine between a face normal and the view axis, a face is
# edge-on or turned away and is not drawn.
_MIN_FACING = 1e-9

# Facings closer than this count as equal when ordering faces, the tolerance
# golden vectors compare numbers within.
_FACING_TIE_TOLERANCE = 1e-9


class NavigationCubeFace(StrEnum):
    """Names a face of the navigation cube for the orthographic view it shows.

    Each value is the face's name in the golden vectors and in the Dart
    package.
    """

    TOP = "top"
    BOTTOM = "bottom"
    FRONT = "front"
    BACK = "back"
    LEFT = "left"
    RIGHT = "right"

    @property
    def label(self) -> str:
        """Returns the text the face carries, in capitals as CAD view cubes
        print it."""
        return self.value.upper()


# Each face's position in face order, which breaks ties between facings.
_FACE_ORDER = {face: i for i, face in enumerate(NavigationCubeFace)}


class _Frame(NamedTuple):
    """A face's outward normal and the directions its label text runs and
    points up, in world space."""

    normal: Vector3
    text_right: Vector3
    text_up: Vector3


@dataclass(frozen=True, slots=True)
class NavigationCubeFaceView:
    """Holds one face of the navigation cube as the camera sees it, in
    viewport pixels."""

    face: NavigationCubeFace

    corners: tuple[Vector2, Vector2, Vector2, Vector2]
    """The face's corners in the screen coordinates of ``world_to_screen``,
    ordered as the label's bottom-left, bottom-right, top-right, and top-left
    corners.

    The projection is orthographic, so the corners form a parallelogram and an
    affine map draws the label onto it."""

    facing: float
    """Cosine between the face normal and the axis toward the viewer, in
    (0, 1]. A face seen straight on has 1."""


@dataclass(frozen=True, slots=True, kw_only=True)
class NavigationCube:
    """Holds a passive orientation indicator: a cube whose labeled faces show
    which side of the scene faces the viewer.

    Top is the convention's up axis, and Front faces along the ``front`` the
    app names. A top view shows Top upright with Front along its bottom edge,
    as ``CameraBasis.look_at`` holds a top view, when ``front`` is the
    opposite of the convention's fallback axis.

    Raises ``ValueError`` when ``front`` runs along the up axis.
    """

    convention: CoordinateConvention
    """Convention of the space the cube orients in."""

    front: SignedAxis
    """Direction of the Front face's outward normal."""

    _frames: dict[NavigationCubeFace, _Frame] = field(
        init=False, repr=False, compare=False
    )

    def __post_init__(self) -> None:
        convention = self.convention
        if self.front.axis is convention.up:
            raise ValueError(
                f"front {self.front} runs along the up axis {convention.up.label}"
            )
        up = convention.up.unit_vector
        front = self.front.unit_vector
        right = convention.cross(up, front)

        def frame(normal: Vector3, text_up: Vector3) -> _Frame:
            return _Frame(normal, convention.cross(text_up, normal), text_up)

        def neg(v: Vector3) -> Vector3:
            return _vec.scale(v, -1.0)

        # Side labels stand upright. Top and Bottom labels point away from
        # Front, which is how the top and bottom views of
        # ``CameraBasis.look_at`` hold them.
        frames = {
            NavigationCubeFace.TOP: frame(up, neg(front)),
            NavigationCubeFace.BOTTOM: frame(neg(up), neg(front)),
            NavigationCubeFace.FRONT: frame(front, up),
            NavigationCubeFace.BACK: frame(neg(front), up),
            NavigationCubeFace.LEFT: frame(neg(right), up),
            NavigationCubeFace.RIGHT: frame(right, up),
        }
        object.__setattr__(self, "_frames", frames)

    def normal(self, face: NavigationCubeFace) -> Vector3:
        """Returns the outward unit normal of ``face`` in world space.

        Right is the face a viewer of Front sees to their right, so it follows
        the declared hand rule.
        """
        return self._frames[face].normal

    def text_up(self, face: NavigationCubeFace) -> Vector3:
        """Returns the world direction in which ``face``'s label text points
        up."""
        return self._frames[face].text_up

    def text_right(self, face: NavigationCubeFace) -> Vector3:
        """Returns the world direction in which ``face``'s label text runs.

        Text right crossed with text up gives the face normal by the declared
        hand rule, so a label reads left to right from outside the cube.
        """
        return self._frames[face].text_right

    def visible_faces(
        self, camera: CameraBasis, rect: ViewportRect
    ) -> list[NavigationCubeFaceView]:
        """Returns the faces that face the viewer of ``camera``, drawn in
        ``rect``.

        The cube turns with the camera's rotation only and projects
        orthographically about the rectangle's center. Its edge is
        min(width, height) / sqrt(3), so no corner leaves the rectangle at any
        rotation. Faces come least direct first, so drawing them in order
        draws the most direct face last. Ties keep face order.
        """
        half_edge = min(rect.right - rect.left, rect.bottom - rect.top) / (
            2 * math.sqrt(3)
        )
        center_x = (rect.left + rect.right) / 2
        center_y = (rect.top + rect.bottom) / 2

        def project(p: Vector3) -> Vector2:
            return (
                center_x + _vec.dot(p, camera.right) * half_edge,
                center_y - _vec.dot(p, camera.up) * half_edge,
            )

        to_viewer = camera.to_viewer
        views: list[NavigationCubeFaceView] = []
        for face, (n, r, u) in self._frames.items():
            facing = _vec.dot(n, to_viewer)
            if facing <= _MIN_FACING:
                continue
            views.append(
                NavigationCubeFaceView(
                    face=face,
                    corners=(
                        project(_vec.sub(_vec.sub(n, r), u)),
                        project(_vec.sub(_vec.add(n, r), u)),
                        project(_vec.add(_vec.add(n, r), u)),
                        project(_vec.add(_vec.sub(n, r), u)),
                    ),
                    facing=facing,
                )
            )
        _insertion_sort(views, _compare_views)
        return views


def _compare_views(a: NavigationCubeFaceView, b: NavigationCubeFaceView) -> int:
    """Orders ``a`` and ``b`` least direct first, with ties in face order.

    Facings within the fixture tolerance tie, because another language's
    trigonometry can differ from this one in the last bits.
    """
    if abs(a.facing - b.facing) <= _FACING_TIE_TOLERANCE:
        return _FACE_ORDER[a.face] - _FACE_ORDER[b.face]
    return -1 if a.facing < b.facing else 1


def _insertion_sort[T](items: list[T], compare: Callable[[T, T], int]) -> None:
    """Sorts ``items`` in place by the straight insertion sort Dart's
    ``List.sort`` runs on short lists.

    A tolerance tie is not transitive, so the order depends on which pairs a
    sort compares. Comparing the same pairs as the Dart reference keeps both
    packages listing faces alike.
    """
    for i in range(1, len(items)):
        item = items[i]
        j = i
        while j > 0 and compare(items[j - 1], item) > 0:
            items[j] = items[j - 1]
            j -= 1
        items[j] = item
