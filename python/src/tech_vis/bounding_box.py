"""Axis-aligned boxes and the primitives that draw them."""

from dataclasses import dataclass

from tech_vis import _vec
from tech_vis._vec import Vector3
from tech_vis.filled_rectangle import RectanglePlane, create_filled_rectangle
from tech_vis.primitives import LinePrimitive, Primitive, QuadPrimitive


@dataclass(frozen=True, slots=True, kw_only=True)
class BoundingBox:
    """Holds an axis-aligned box by its minimum and maximum corners."""

    min_bounds: Vector3
    max_bounds: Vector3

    @property
    def center(self) -> Vector3:
        return _vec.scale(_vec.add(self.min_bounds, self.max_bounds), 0.5)

    @property
    def size(self) -> Vector3:
        return _vec.sub(self.max_bounds, self.min_bounds)


def create_bounding_box(
    bounds: BoundingBox,
    *,
    key: object,
    fill_opacity: float = 1.0,
    edge_width: float = 1.0,
) -> list[Primitive]:
    """Returns the primitives that draw ``bounds``.

    Emits each of the box's twelve edges once, as a line ``edge_width`` screen
    pixels wide. When ``fill_opacity`` is above zero, first emits the six faces
    as quads at that opacity. The faces carry no edges, because a box outlined
    from its faces would draw every edge twice. ``key`` passes through to every
    primitive.
    """
    faces = _faces(bounds, key, fill_opacity) if fill_opacity > 0 else []
    return [*faces, *_edges(bounds, key, edge_width)]


def _edges(bounds: BoundingBox, key: object, width: float) -> list[LinePrimitive]:
    (lx, ly, lz), (hx, hy, hz) = bounds.min_bounds, bounds.max_bounds
    segments = [
        # Four edges along X, at each Y-Z corner.
        *(((lx, y, z), (hx, y, z)) for y in (ly, hy) for z in (lz, hz)),
        # Four along Y, at each X-Z corner.
        *(((x, ly, z), (x, hy, z)) for x in (lx, hx) for z in (lz, hz)),
        # Four along Z, at each X-Y corner.
        *(((x, y, lz), (x, y, hz)) for x in (lx, hx) for y in (ly, hy)),
    ]
    return [
        LinePrimitive(start=start, end=end, width_pixels=width, key=key)
        for start, end in segments
    ]


def _faces(bounds: BoundingBox, key: object, opacity: float) -> list[QuadPrimitive]:
    center = bounds.center
    sx, sy, sz = bounds.size
    # Each pair of opposite faces lies in one plane, at the low and high bound
    # of the axis normal to it.
    planes = (
        (RectanglePlane.XY, 2, sx, sy),
        (RectanglePlane.XZ, 1, sx, sz),
        (RectanglePlane.YZ, 0, sy, sz),
    )
    faces = []
    for plane, normal, width, height in planes:
        for bound in (bounds.min_bounds, bounds.max_bounds):
            face_center = list(center)
            face_center[normal] = bound[normal]
            x, y, z = face_center
            faces.append(
                create_filled_rectangle(
                    center=(x, y, z),
                    width=abs(width),
                    height=abs(height),
                    plane=plane,
                    key=key,
                    opacity=opacity,
                )
            )
    return faces
