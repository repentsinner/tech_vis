"""The typed primitives and the factories that emit them."""

import math

import pytest

from conftest import (
    TOLERANCE,
    Y_UP_LEFT,
    Y_UP_RIGHT,
    Z_UP_LEFT,
    Z_UP_RIGHT,
    assert_close,
    fake_text_resolver,
)
from tech_vis import (
    BillboardContent,
    BillboardPrimitive,
    BoundingBox,
    CameraBasis,
    CoordinateFrameDescriptor,
    CoplanarOrientation,
    LabelAlignment,
    LabelCorner,
    LabelEdge,
    LinePrimitive,
    MarkerPrimitive,
    MeshPrimitive,
    QuadPrimitive,
    RectanglePlane,
    SpatialAxis,
    TextRequest,
    TriangleMesh,
    Vector3,
    ViewerFacingOrientation,
    create_bounding_box,
    create_coordinate_frame,
    create_coplanar_billboard_label,
    create_edge_tab_label,
    create_envelope_label,
    create_filled_rectangle,
    create_marker,
    create_rectangle_outline,
    marker_sphere_mesh,
    marker_transform,
    rectangle_corners,
    tokens,
    world_to_screen,
)
from tech_vis._vec import dot, length, sub

# A mesh buffer holds 32-bit floats.
FLOAT32_TOLERANCE = 1e-6


class TestPrimitives:
    def test_are_opaque_unless_given_an_opacity(self):
        line = LinePrimitive(start=(0, 0, 0), end=(1, 0, 0), width_pixels=1, key="k")
        assert line.opacity == 1.0
        assert line.key == "k"

    @pytest.mark.parametrize("opacity", [-0.1, 1.5])
    def test_reject_an_opacity_outside_0_to_1(self, opacity):
        with pytest.raises(ValueError):
            LinePrimitive(
                start=(0, 0, 0),
                end=(1, 0, 0),
                width_pixels=1,
                key=None,
                opacity=opacity,
            )

    def test_reject_a_quad_without_four_corners(self):
        with pytest.raises(ValueError):
            QuadPrimitive(corners=((0, 0, 0), (1, 0, 0), (1, 1, 0)), key=None)

    def test_reject_a_negative_content_size(self):
        with pytest.raises(ValueError):
            BillboardContent(value=None, width_pixels=-1, height_pixels=1)

    def test_billboards_face_the_viewer_centered_by_default(self):
        billboard = BillboardPrimitive(
            content=fake_text_resolver(TextRequest(text="A", height_pixels=10)),
            anchor=(1, 2, 3),
            key=None,
        )
        assert billboard.orientation == ViewerFacingOrientation()
        assert billboard.alignment == (0.5, 0.5)
        assert billboard.offset is None

    def test_meshes_count_vertices_and_triangles(self):
        mesh = marker_sphere_mesh(Y_UP_RIGHT)
        assert (
            MeshPrimitive(mesh=mesh, key=None).mesh.vertex_count
            == len(mesh.positions) // 3
        )
        assert mesh.triangle_count == len(mesh.indices) // 3


class TestRectangles:
    def test_walk_the_xy_rectangle_counterclockwise_from_min_min(self):
        corners = rectangle_corners(
            center=(0, 0, 5), width=4, height=2, plane=RectanglePlane.XY
        )
        expected = [(-2, -1, 5), (2, -1, 5), (2, 1, 5), (-2, 1, 5)]
        for got, want in zip(corners, expected, strict=True):
            assert_close(got, want)

    def test_rotate_about_the_center_within_the_plane(self):
        corners = rectangle_corners(
            center=(0, 0, 0),
            width=2,
            height=2,
            plane=RectanglePlane.XZ,
            rotation=math.pi / 2,
        )
        assert_close(corners[0], (1, 0, -1))

    def test_outline_a_quad_with_four_lines(self):
        quad = create_filled_rectangle(
            center=(0, 0, 0),
            width=2,
            height=1,
            plane=RectanglePlane.YZ,
            key="r",
            opacity=0.5,
        )
        lines = create_rectangle_outline(quad, width_pixels=2)
        assert len(lines) == 4
        for i, line in enumerate(lines):
            assert line.start == quad.corners[i]
            assert line.end == quad.corners[(i + 1) % 4]
            assert (line.width_pixels, line.key, line.opacity) == (2, "r", 0.5)


class TestBoundingBox:
    bounds = BoundingBox(min_bounds=(-1, -2, 0), max_bounds=(3, 2, 1))

    def test_emits_six_faces_then_twelve_edges(self):
        primitives = create_bounding_box(
            self.bounds, key="box", fill_opacity=0.25, edge_width=1.5
        )
        quads, lines = primitives[:6], primitives[6:]
        assert all(isinstance(q, QuadPrimitive) for q in quads)
        assert all(isinstance(line, LinePrimitive) for line in lines)
        assert len(lines) == 12
        assert {q.opacity for q in quads} == {0.25}
        assert {p.key for p in primitives} == {"box"}
        edges = {frozenset((line.start, line.end)) for line in lines}
        assert len(edges) == 12

    def test_puts_every_face_corner_on_a_box_corner(self):
        lo, hi = self.bounds.min_bounds, self.bounds.max_bounds
        for quad in create_bounding_box(self.bounds, key=None)[:6]:
            for corner in quad.corners:
                for i in range(3):
                    assert min(abs(corner[i] - lo[i]), abs(corner[i] - hi[i])) < (
                        TOLERANCE
                    )

    def test_omits_the_faces_without_a_fill(self):
        primitives = create_bounding_box(self.bounds, key=None, fill_opacity=0)
        assert len(primitives) == 12
        assert all(isinstance(p, LinePrimitive) for p in primitives)


class TestCoordinateFrame:
    def test_emits_three_axes_then_three_offset_labels(self):
        frame = CoordinateFrameDescriptor(origin=(1, 2, 3), length=10)
        primitives = create_coordinate_frame(
            frame, key_for=lambda axis: axis.label, resolve_text=fake_text_resolver
        )
        lines, labels = primitives[:3], primitives[3:]
        assert [line.key for line in lines] == ["X", "Y", "Z"]
        assert_close(lines[1].end, (1, 12, 3))
        assert {line.width_pixels for line in lines} == {
            tokens.DEFAULT_AXIS_LINE_THICKNESS
        }
        for label, axis in zip(labels, SpatialAxis, strict=True):
            assert isinstance(label, BillboardPrimitive)
            assert label.content.value == TextRequest(
                text=axis.label, height_pixels=tokens.DEFAULT_AXIS_LABEL_SIZE
            )
            assert label.offset is not None
            assert label.offset.direction == axis.unit_vector
            assert label.offset.pixels == tokens.AXIS_LABEL_OFFSET_PIXELS

    def test_omits_labels_and_keys_them_separately(self):
        hidden = CoordinateFrameDescriptor(show_labels=False)
        assert (
            len(
                create_coordinate_frame(
                    hidden, key_for=lambda _: None, resolve_text=fake_text_resolver
                )
            )
            == 3
        )
        shown = create_coordinate_frame(
            CoordinateFrameDescriptor(),
            key_for=lambda _: "line",
            label_key_for=lambda _: "label",
            resolve_text=fake_text_resolver,
        )
        assert [p.key for p in shown] == ["line"] * 3 + ["label"] * 3


# Up, text direction, and top-face corners of a 4 x 2 x 1 box per convention.
ENVELOPE_CASES = [
    (
        Z_UP_RIGHT,
        (0, 0, 1),
        (1, 0, 0),
        {
            LabelCorner.TOP_FRONT_LEFT: ((0, 0, 1), (-1, -1, 1)),
            LabelCorner.TOP_BACK_RIGHT: ((4, 2, 1), (1, 1, 1)),
        },
        [
            (LabelEdge.FRONT, LabelAlignment.CENTER, (2, 0, 1), (0.5, 1)),
            (LabelEdge.BACK, LabelAlignment.RIGHT, (4, 2, 1), (1, 0)),
        ],
    ),
    (
        Y_UP_RIGHT,
        (0, 1, 0),
        (0, 0, 1),
        {
            LabelCorner.TOP_FRONT_RIGHT: ((0, 2, 1), (-1, 1, 1)),
            LabelCorner.TOP_BACK_LEFT: ((4, 2, 0), (1, 1, -1)),
        },
        [(LabelEdge.FRONT, LabelAlignment.CENTER, (0, 2, 0.5), (0.5, 1))],
    ),
    (
        Z_UP_LEFT,
        (0, 0, 1),
        (-1, 0, 0),
        {LabelCorner.TOP_FRONT_LEFT: ((4, 0, 1), (1, -1, 1))},
        [(LabelEdge.FRONT, LabelAlignment.LEFT, (4, 0, 1), (0, 1))],
    ),
]


class TestEnvelopeLabels:
    bounds = BoundingBox(min_bounds=(0, 0, 0), max_bounds=(4, 2, 1))

    @pytest.mark.parametrize(
        ("convention", "up", "right", "corners", "tabs"), ENVELOPE_CASES
    )
    def test_anchor_viewer_facing_labels_at_top_corners(
        self, convention, up, right, corners, tabs
    ):
        for corner, (anchor, outward) in corners.items():
            label = create_envelope_label(
                text="W",
                bounds=self.bounds,
                corner=corner,
                convention=convention,
                resolve_text=fake_text_resolver,
                key="envelope",
            )
            assert label.key == "envelope"
            assert label.orientation == ViewerFacingOrientation()
            assert_close(label.anchor, anchor, f"{convention} {corner}")
            norm = length(outward)
            assert label.offset is not None
            assert_close(label.offset.direction, [c / norm for c in outward])
            assert label.offset.pixels == 8.0
            assert label.content.height_pixels == 20.0

    @pytest.mark.parametrize(
        ("convention", "up", "right", "corners", "tabs"), ENVELOPE_CASES
    )
    def test_set_edge_tabs_flat_on_the_top_face(
        self, convention, up, right, corners, tabs
    ):
        for edge, alignment, anchor, anchor_alignment in tabs:
            label = create_edge_tab_label(
                text="T",
                bounds=self.bounds,
                edge=edge,
                alignment=alignment,
                convention=convention,
                resolve_text=fake_text_resolver,
                key=None,
            )
            assert_close(label.anchor, anchor)
            assert label.alignment == anchor_alignment
            assert isinstance(label.orientation, CoplanarOrientation)
            assert_close(label.orientation.normal, up)
            assert_close(label.orientation.right, right)

    def test_lay_a_coplanar_label_in_the_given_plane(self):
        label = create_coplanar_billboard_label(
            text="P",
            position=(1, 2, 3),
            convention=Z_UP_RIGHT,
            resolve_text=fake_text_resolver,
            key=None,
            pixel_size=12,
            surface_normal=(0, 1, 0),
            text_direction=(1, 0, 0),
            anchor_alignment=(0, 1),
        )
        assert label.orientation == CoplanarOrientation(
            normal=(0, 1, 0), right=(1, 0, 0)
        )
        assert label.alignment == (0, 1)
        assert label.content.height_pixels == 12
        assert label.offset is None


class TestMarker:
    @pytest.mark.parametrize("convention", [Y_UP_RIGHT, Y_UP_LEFT])
    def test_sphere_mesh_winds_outward_by_the_hand_rule(self, convention):
        mesh = marker_sphere_mesh(convention)
        p = mesh.positions

        def vertex(i: int) -> Vector3:
            return (p[3 * i], p[3 * i + 1], p[3 * i + 2])

        for i in range(mesh.vertex_count):
            v = vertex(i)
            assert length(v) == pytest.approx(1.0, abs=FLOAT32_TOLERANCE)
        assert list(mesh.normals) == list(mesh.positions)
        idx = mesh.indices
        assert max(idx) < mesh.vertex_count
        for t in range(mesh.triangle_count):
            a, b, c = (vertex(idx[3 * t + k]) for k in range(3))
            normal = convention.cross(sub(b, a), sub(c, a))
            centroid = tuple((a[k] + b[k] + c[k]) / 3 for k in range(3))
            assert dot(normal, centroid) > 0, f"triangle {t}"

    def test_sphere_mesh_uses_the_token_level_of_detail(self):
        mesh = marker_sphere_mesh(Y_UP_RIGHT)
        assert isinstance(mesh, TriangleMesh)
        assert mesh.triangle_count == 20 * 4 ** int(tokens.MARKER_SUBDIVISIONS)

    def test_sphere_mesh_is_shared_and_read_only(self):
        mesh = marker_sphere_mesh(Z_UP_RIGHT)
        assert marker_sphere_mesh(Y_UP_RIGHT) is mesh
        with pytest.raises(TypeError):
            mesh.positions[0] = 2.0

    def test_creates_a_marker_with_the_shared_mesh(self):
        marker = create_marker((1, 2, 3), Y_UP_RIGHT, key="m")
        assert isinstance(marker, MarkerPrimitive)
        assert marker.mesh is marker_sphere_mesh(Y_UP_RIGHT)
        assert marker.diameter_pixels == tokens.MARKER_DIAMETER_PIXELS
        assert marker.key == "m"

    @pytest.mark.parametrize("depth", [10.0, 1000.0])
    def test_transform_keeps_the_pixel_diameter(self, depth):
        camera = CameraBasis.look_at(
            position=(0, 0, 0), target=(0, 0, -1), convention=Y_UP_RIGHT
        )
        fov, viewport = math.radians(45), (1280.0, 720.0)
        center = (depth * 0.3, -depth * 0.2, -depth)
        marker = create_marker(center, Y_UP_RIGHT, key=None, diameter_pixels=9)
        m = marker_transform(marker, camera, fov, viewport[1])
        assert m is not None
        radius = m[0][0]
        assert (m[0][3], m[1][3], m[2][3]) == center
        assert m[1][1] == m[2][2] == radius
        left = world_to_screen((center[0] - radius, *center[1:]), camera, fov, viewport)
        right = world_to_screen(
            (center[0] + radius, *center[1:]), camera, fov, viewport
        )
        assert right[0] - left[0] == pytest.approx(9, abs=TOLERANCE)

    @pytest.mark.parametrize("z", [0.0, 5.0])
    def test_transform_is_none_on_or_behind_the_camera(self, z):
        camera = CameraBasis.look_at(
            position=(0, 0, 0), target=(0, 0, -1), convention=Y_UP_RIGHT
        )
        marker = create_marker((1, 0, z), Y_UP_RIGHT, key=None)
        assert marker_transform(marker, camera, math.radians(45), 720) is None
