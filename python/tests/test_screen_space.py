"""The coordinate convention, the camera basis, and screen projection."""

import math

import pytest

from conftest import TOLERANCE, assert_close
from tech_vis import (
    CameraBasis,
    CoordinateConvention,
    Handedness,
    SignedAxis,
    SpatialAxis,
    Vector3,
    billboard_offset_position,
    project_onto_screen_plane,
    world_to_screen,
    world_units_per_pixel_at,
)

Y_UP_RIGHT = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.RIGHT)
Z_UP_RIGHT = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.RIGHT)
ALL_CONVENTIONS = [
    CoordinateConvention(up=up, handedness=hand)
    for up in SpatialAxis
    for hand in Handedness
]

FOV = math.radians(45)
VIEWPORT = (1280.0, 720.0)


def _dot(a: Vector3, b: Vector3) -> float:
    return sum(x * y for x, y in zip(a, b, strict=True))


def _assert_orthonormal(basis: CameraBasis) -> None:
    for axis in (basis.forward, basis.right, basis.up):
        assert _dot(axis, axis) == pytest.approx(1.0, abs=TOLERANCE)
    assert _dot(basis.right, basis.forward) == pytest.approx(0.0, abs=TOLERANCE)
    assert _dot(basis.up, basis.forward) == pytest.approx(0.0, abs=TOLERANCE)
    assert _dot(basis.right, basis.up) == pytest.approx(0.0, abs=TOLERANCE)


class TestCoordinateConvention:
    def test_parses_fixture_names(self):
        assert SpatialAxis("z") is SpatialAxis.Z
        assert Handedness("left") is Handedness.LEFT

    def test_falls_back_to_a_different_axis_from_up(self):
        for convention in ALL_CONVENTIONS:
            assert convention.fallback_axis is not convention.up, convention

    def test_z_up_falls_back_to_y(self):
        assert Z_UP_RIGHT.fallback_axis is SpatialAxis.Y

    def test_crosses_by_the_declared_hand_rule(self):
        left = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.LEFT)
        assert_close(Y_UP_RIGHT.cross((1, 0, 0), (0, 1, 0)), (0, 0, 1))
        assert_close(left.cross((1, 0, 0), (0, 1, 0)), (0, 0, -1))

    @pytest.mark.parametrize(
        ("up", "plane"),
        [
            (SpatialAxis.X, (SpatialAxis.Y, SpatialAxis.Z)),
            (SpatialAxis.Y, (SpatialAxis.Z, SpatialAxis.X)),
            (SpatialAxis.Z, (SpatialAxis.X, SpatialAxis.Y)),
        ],
    )
    def test_spans_the_plane_across_up_with_the_next_two_axes(self, up, plane):
        convention = CoordinateConvention(up=up, handedness=Handedness.LEFT)
        assert convention.plane_axes == plane

    def test_describes_itself(self):
        convention = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.LEFT)
        assert str(convention) == "Z-up left-handed"

    def test_signed_axis_negates_and_points(self):
        minus_y = -SignedAxis(SpatialAxis.Y)
        assert minus_y == SignedAxis(SpatialAxis.Y, negative=True)
        assert minus_y.unit_vector == (0.0, -1.0, 0.0)
        assert str(minus_y) == "-Y"
        assert SpatialAxis.X.label == "X"


class TestCameraBasis:
    def test_faces_its_target_with_y_up(self):
        camera = CameraBasis.look_at(
            position=(0, 0, 0), target=(0, 0, -100), convention=Y_UP_RIGHT
        )
        assert_close(camera.forward, (0, 0, -1))
        assert_close(camera.right, (1, 0, 0))
        assert_close(camera.up, (0, 1, 0))
        assert_close(camera.to_viewer, (0, 0, 1))

    def test_uses_the_fallback_axis_looking_along_up(self):
        top = CameraBasis.look_at(
            position=(0, 0, 100), target=(0, 0, 0), convention=Z_UP_RIGHT
        )
        _assert_orthonormal(top)
        assert_close(top.up, (0, 1, 0))
        assert_close(top.right, (1, 0, 0))

    def test_puts_screen_right_by_the_left_hand_rule(self):
        left = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.LEFT)
        camera = CameraBasis.look_at(
            position=(0, 0, 0), target=(0, 0, 100), convention=left
        )
        assert_close(camera.right, (1, 0, 0))
        assert_close(left.cross(camera.right, camera.up), camera.to_viewer)

    def test_follows_the_declared_hand_rule_in_every_convention(self):
        for convention in ALL_CONVENTIONS:
            camera = CameraBasis.look_at(
                position=(40, 25, -30), target=(3, -2, 5), convention=convention
            )
            _assert_orthonormal(camera)
            assert_close(
                convention.cross(camera.right, camera.up),
                camera.to_viewer,
                str(convention),
            )
            assert _dot(camera.up, convention.up.unit_vector) > 0, convention

    def test_measures_depth_along_the_view_axis(self):
        camera = CameraBasis.look_at(
            position=(0, 0, 0), target=(0, 0, -1), convention=Y_UP_RIGHT
        )
        assert camera.depth_of((30, 40, -10)) == pytest.approx(10)


class TestProjection:
    camera = CameraBasis.look_at(
        position=(0, 0, 0), target=(0, 0, -100), convention=Y_UP_RIGHT
    )

    def test_sizes_a_pixel_by_depth(self):
        size = world_units_per_pixel_at((25, 0, -100), self.camera, FOV, 720)
        assert size == pytest.approx(2 * 100 * math.tan(FOV / 2) / 720)

    @pytest.mark.parametrize("z", [0.0, 5.0])
    def test_has_no_size_or_position_on_or_behind_the_camera(self, z):
        point = (1.0, 0.0, z)
        assert world_units_per_pixel_at(point, self.camera, FOV, 720) is None
        assert world_to_screen(point, self.camera, FOV, VIEWPORT) is None

    def test_puts_the_target_at_the_viewport_center(self):
        assert_close(
            world_to_screen((0, 0, -100), self.camera, FOV, VIEWPORT), (640, 360)
        )

    def test_runs_x_right_and_y_down(self):
        x, y = world_to_screen((1, 1, -100), self.camera, FOV, VIEWPORT)
        assert x > 640
        assert y < 360

    def test_projects_a_direction_onto_the_screen_plane(self):
        assert_close(project_onto_screen_plane((1, 2, 3), self.camera), (1, 2, 0))

    def test_offsets_a_billboard_by_pixels_along_the_screen(self):
        anchor = (0.0, 0.0, -100.0)
        size = world_units_per_pixel_at(anchor, self.camera, FOV, 720)
        placed = billboard_offset_position(
            anchor=anchor,
            direction=(3, 0, 5),
            offset_pixels=12,
            world_units_per_pixel=size,
            camera=self.camera,
        )
        x, y = world_to_screen(placed, self.camera, FOV, VIEWPORT)
        assert_close((x, y), (652, 360))

    def test_keeps_a_billboard_on_its_anchor_along_the_view_axis(self):
        anchor = (1.0, 2.0, -50.0)
        placed = billboard_offset_position(
            anchor=anchor,
            direction=(0, 0, 1),
            offset_pixels=12,
            world_units_per_pixel=0.1,
            camera=self.camera,
        )
        assert placed == anchor
