"""Markers: spheres that keep their diameter in screen pixels."""

import functools
import math
from array import array

from tech_vis import _vec, tokens
from tech_vis._vec import Vector3
from tech_vis.coordinate_convention import CoordinateConvention, Handedness
from tech_vis.primitives import MarkerPrimitive, TriangleMesh
from tech_vis.screen_space import CameraBasis, world_units_per_pixel_at

type Matrix4 = tuple[
    tuple[float, float, float, float],
    tuple[float, float, float, float],
    tuple[float, float, float, float],
    tuple[float, float, float, float],
]

# Largest vertex count that a 16-bit index buffer can address.
_MAX_UINT16_VERTICES = 1 << 16

# The golden ratio places an icosahedron's twelve vertices.
_PHI = (1 + math.sqrt(5)) / 2

# Corners of a golden rectangle; three orthogonal copies give the vertices.
_RECTANGLE_CORNERS = ((-1.0, _PHI), (1.0, _PHI), (-1.0, -_PHI), (1.0, -_PHI))

# The icosahedron's faces, each wound so its right-hand normal points outward.
_ICOSAHEDRON_FACES = (
    (0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11),
    (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6), (7, 1, 8),
    (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9),
    (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1),
)  # fmt: skip


def marker_sphere_mesh(convention: CoordinateConvention) -> TriangleMesh:
    """Returns the unit sphere mesh that every marker in ``convention`` shares.

    The mesh is an icosphere, subdivided ``tokens.MARKER_SUBDIVISIONS`` times:
    its triangles are close to equal, with no crowded poles, so a low level
    reads as round at marker sizes. Positions lie on the unit sphere and
    double as the outward normals.

    Only the handedness shapes the mesh, because it decides the triangle
    winding. The package builds one mesh per handedness and shares it.
    """
    return _sphere_mesh(convention.handedness)


@functools.cache
def _sphere_mesh(handedness: Handedness) -> TriangleMesh:
    return _icosphere(int(tokens.MARKER_SUBDIVISIONS), handedness)


def create_marker(
    position: Vector3,
    convention: CoordinateConvention,
    *,
    key: object,
    diameter_pixels: float = tokens.MARKER_DIAMETER_PIXELS,
    opacity: float = 1.0,
) -> MarkerPrimitive:
    """Returns a marker on ``position`` carrying the shared sphere mesh."""
    return MarkerPrimitive(
        position=position,
        diameter_pixels=diameter_pixels,
        mesh=marker_sphere_mesh(convention),
        key=key,
        opacity=opacity,
    )


def marker_transform(
    marker: MarkerPrimitive,
    camera: CameraBasis,
    vertical_fov_radians: float,
    viewport_height: float,
) -> Matrix4 | None:
    """Returns the model transform that draws the marker's unit sphere this frame.

    The result is a row-major 4x4 matrix that scales uniformly by the marker's
    radius in world units, then translates to its position: ``m[row][col]``,
    with the translation in the last column. The marker's depth along the
    view axis sets the radius through ``world_units_per_pixel_at``. Returns
    None when the marker lies on or behind the camera plane.
    """
    size = world_units_per_pixel_at(
        marker.position, camera, vertical_fov_radians, viewport_height
    )
    if size is None:
        return None
    r = marker.diameter_pixels * size / 2
    x, y, z = marker.position
    return (
        (r, 0.0, 0.0, x),
        (0.0, r, 0.0, y),
        (0.0, 0.0, r, z),
        (0.0, 0.0, 0.0, 1.0),
    )


def _midpoint(
    vertices: list[Vector3], midpoints: dict[tuple[int, int], int], a: int, b: int
) -> int:
    """Returns the index of the unit vertex between ``a`` and ``b``.

    Adds it to ``vertices`` on first use, so faces that share an edge share
    its midpoint.
    """
    edge = (a, b) if a < b else (b, a)
    if edge not in midpoints:
        vertices.append(_vec.normalized(_vec.add(vertices[a], vertices[b])))
        midpoints[edge] = len(vertices) - 1
    return midpoints[edge]


def _icosphere(subdivisions: int, handedness: Handedness) -> TriangleMesh:
    """Subdivides an icosahedron ``subdivisions`` times onto the unit sphere."""
    # Three orthogonal golden rectangles, in the order the face table indexes.
    vertices: list[Vector3] = [
        _vec.normalized(v)
        for v in (
            *((a, b, 0.0) for a, b in _RECTANGLE_CORNERS),
            *((0.0, a, b) for a, b in _RECTANGLE_CORNERS),
            *((b, 0.0, a) for a, b in _RECTANGLE_CORNERS),
        )
    ]
    faces: list[tuple[int, int, int]] = list(_ICOSAHEDRON_FACES)

    for _ in range(subdivisions):
        midpoints: dict[tuple[int, int], int] = {}
        next_faces = []
        for a, b, c in faces:
            # The Dart reference adds midpoints in this order, so the vertex
            # buffers agree index for index.
            ab = _midpoint(vertices, midpoints, a, b)
            ca = _midpoint(vertices, midpoints, c, a)
            bc = _midpoint(vertices, midpoints, b, c)
            # Each child keeps its parent's winding, so it faces outward too.
            next_faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = next_faces
    if len(vertices) > _MAX_UINT16_VERTICES:
        raise ValueError(f"{subdivisions} subdivisions overflow 16-bit indices")

    positions = array("f", (c for v in vertices for c in v))
    indices = array("H")
    for a, b, c in faces:
        # Swapping two corners turns a face's left-hand normal back outward.
        indices.extend((a, b, c) if handedness is Handedness.RIGHT else (a, c, b))
    view = memoryview(positions).toreadonly()
    # A unit sphere's outward normal at a vertex is the vertex itself.
    return TriangleMesh(
        positions=view, normals=view, indices=memoryview(indices).toreadonly()
    )
