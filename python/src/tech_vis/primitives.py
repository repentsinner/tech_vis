"""Typed annotation primitives (§spec:scene-model).

Every primitive is a ``LinePrimitive``, ``QuadPrimitive``,
``BillboardPrimitive``, ``MarkerPrimitive``, or ``MeshPrimitive``, so a
renderer that matches on a ``Primitive`` handles exactly five cases. The
package emits primitives and never renders them.
"""

from collections.abc import Callable
from dataclasses import dataclass, field

from tech_vis._vec import Vector2, Vector3

# A billboard's content sits centered on its anchor unless told otherwise.
_CENTERED: Vector2 = (0.5, 0.5)

_QUAD_CORNERS = 4


@dataclass(frozen=True, slots=True, kw_only=True)
class Primitive:
    """Holds what every primitive carries: an app key and an opacity.

    The primitives are in the app's declared coordinate convention.
    """

    key: object
    """App value that the package passes through and never inspects.

    The app resolves the primitive's color, and any other meaning, from it.
    """

    opacity: float = 1.0
    """Opacity from 0 to 1, which the package computes."""

    def __post_init__(self) -> None:
        if not 0 <= self.opacity <= 1:
            raise ValueError(f"opacity must lie between 0 and 1: {self.opacity!r}")


@dataclass(frozen=True, slots=True, kw_only=True)
class LinePrimitive(Primitive):
    """Holds a straight line drawn at a constant pixel width at any depth."""

    start: Vector3
    end: Vector3
    width_pixels: float
    """Width in screen pixels."""


@dataclass(frozen=True, slots=True, kw_only=True)
class QuadPrimitive(Primitive):
    """Holds a filled four-cornered face."""

    corners: tuple[Vector3, Vector3, Vector3, Vector3]
    """World corners in order around the face's perimeter."""

    def __post_init__(self) -> None:
        super(QuadPrimitive, self).__post_init__()
        if len(self.corners) != _QUAD_CORNERS:
            raise ValueError(f"a quad has four corners, got {len(self.corners)}")
        object.__setattr__(self, "corners", tuple(self.corners))


@dataclass(frozen=True, slots=True)
class ViewerFacingOrientation:
    """Marks billboard content that always faces the viewer, upright on screen."""


@dataclass(frozen=True, slots=True, kw_only=True)
class CoplanarOrientation:
    """Lays billboard content flat in the plane through its anchor.

    The content keeps its pixel size when viewed along ``normal`` and
    foreshortens with perspective at oblique angles. Its vertical axis is
    ``normal`` cross ``right`` by the declared hand rule.
    """

    normal: Vector3
    """Unit normal of the plane the content lies in."""

    right: Vector3
    """Unit world direction of the content's horizontal axis."""


type BillboardOrientation = ViewerFacingOrientation | CoplanarOrientation


@dataclass(frozen=True, slots=True, kw_only=True)
class ScreenOffset:
    """Holds a billboard's offset from its anchor, in screen pixels."""

    direction: Vector3
    """World direction of the offset, followed as it appears on screen."""

    pixels: float
    """Length of the offset in screen pixels."""


@dataclass(frozen=True, slots=True, kw_only=True)
class TextRequest:
    """Holds text the package composes, at the pixel height it is drawn at.

    The package never measures or rasterizes text. The app answers each
    request with a ``TextResolver``, which sets the text in its own typeface
    and reports the result's pixel size.
    """

    text: str
    height_pixels: float


@dataclass(frozen=True, slots=True, kw_only=True)
class BillboardContent:
    """Holds content the app prepared for a billboard, with its pixel size.

    ``value`` is any handle the app's renderer draws: a text layout, a texture,
    an icon, or a video frame. The package places the content by its size and
    never inspects ``value``.
    """

    value: object
    width_pixels: float
    height_pixels: float

    def __post_init__(self) -> None:
        if self.width_pixels < 0 or self.height_pixels < 0:
            raise ValueError("a pixel size is never negative")


type TextResolver = Callable[[TextRequest], BillboardContent]
"""Answers a ``TextRequest`` with the app's content and its pixel size.

The resolver runs synchronously, so every factory result follows from its
inputs alone.
"""


@dataclass(frozen=True, slots=True, kw_only=True)
class BillboardPrimitive(Primitive):
    """Holds 2D app content placed at a world anchor and sized in pixels."""

    content: BillboardContent
    anchor: Vector3
    orientation: BillboardOrientation = field(default_factory=ViewerFacingOrientation)
    alignment: Vector2 = _CENTERED
    """Point of the content on the anchor, as a fraction of its width and
    height from its bottom-left corner."""

    offset: ScreenOffset | None = None
    """Screen-space offset from the anchor, or None for none."""


@dataclass(frozen=True, slots=True, eq=False)
class TriangleMesh:
    """Holds triangle geometry in 32-bit buffers, the precision a GPU consumes.

    Each buffer is a read-only ``memoryview``: positions and normals of format
    ``"f"``, interleaved XYZ, and indices of format ``"H"``, three per
    triangle. Triangles wind so that each face's normal, by the declared hand
    rule, points outward.
    """

    positions: memoryview
    normals: memoryview
    indices: memoryview

    @property
    def vertex_count(self) -> int:
        return len(self.positions) // 3

    @property
    def triangle_count(self) -> int:
        return len(self.indices) // 3


@dataclass(frozen=True, slots=True, kw_only=True)
class MarkerPrimitive(Primitive):
    """Holds a sphere that keeps its pixel diameter at any distance."""

    position: Vector3
    diameter_pixels: float
    mesh: TriangleMesh
    """The unit sphere, drawn at the transform ``marker_transform`` returns."""


@dataclass(frozen=True, slots=True, kw_only=True)
class MeshPrimitive(Primitive):
    """Holds triangle geometry drawn as is."""

    mesh: TriangleMesh
