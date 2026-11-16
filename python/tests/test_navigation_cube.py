"""The navigation cube agrees with the Dart reference's unit tests."""

import math

import pytest

from conftest import TOLERANCE, assert_close
from tech_vis import (
    CameraBasis,
    CoordinateConvention,
    Handedness,
    NavigationCube,
    NavigationCubeFace,
    SignedAxis,
    SpatialAxis,
    Vector2,
    Vector3,
    ViewportOverlayKind,
    ViewportOverlayPlacement,
)
from tech_vis._vec import add, scale

Y_UP_RIGHT = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.RIGHT)
Y_UP_LEFT = CoordinateConvention(up=SpatialAxis.Y, handedness=Handedness.LEFT)
Z_UP_RIGHT = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.RIGHT)
Z_UP_LEFT = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.LEFT)

# The default placement's rectangle in a 1280 x 720 viewport.
RECT = ViewportOverlayPlacement.of(ViewportOverlayKind.NAVIGATION_CUBE).rect(
    (1280.0, 720.0)
)
RECT_CENTER = ((RECT.left + RECT.right) / 2, (RECT.top + RECT.bottom) / 2)
EDGE = min(RECT.right - RECT.left, RECT.bottom - RECT.top) / math.sqrt(3)

MINUS_X = SignedAxis(SpatialAxis.X, negative=True)
MINUS_Y = SignedAxis(SpatialAxis.Y, negative=True)

# Each convention with Front opposite its fallback axis, and the Right normal
# the hand rule gives it.
NORMALS = [
    pytest.param(Y_UP_RIGHT, MINUS_X, (0.0, 0.0, 1.0), id=str(Y_UP_RIGHT)),
    pytest.param(Y_UP_LEFT, MINUS_X, (0.0, 0.0, -1.0), id=str(Y_UP_LEFT)),
    pytest.param(Z_UP_RIGHT, MINUS_Y, (1.0, 0.0, 0.0), id=str(Z_UP_RIGHT)),
    pytest.param(Z_UP_LEFT, MINUS_Y, (-1.0, 0.0, 0.0), id=str(Z_UP_LEFT)),
]

F = NavigationCubeFace


def _camera(convention: CoordinateConvention, offset: Vector3) -> CameraBasis:
    return CameraBasis.look_at(
        position=offset, target=(0.0, 0.0, 0.0), convention=convention
    )


def _center(corners: tuple[Vector2, ...]) -> Vector2:
    n = len(corners)
    return (sum(p[0] for p in corners) / n, sum(p[1] for p in corners) / n)


@pytest.mark.parametrize(("convention", "front", "right"), NORMALS)
def test_top_is_the_up_axis_and_front_is_the_named_front(convention, front, right):
    cube = NavigationCube(convention=convention, front=front)
    up = convention.up.unit_vector
    front_normal = front.unit_vector
    expected = {
        F.TOP: up,
        F.BOTTOM: scale(up, -1),
        F.FRONT: front_normal,
        F.BACK: scale(front_normal, -1),
        F.RIGHT: right,
        F.LEFT: scale(right, -1),
    }
    for face, normal in expected.items():
        assert_close(cube.normal(face), normal, face.value)


@pytest.mark.parametrize(("convention", "front", "right"), NORMALS)
def test_each_face_text_frame_follows_the_hand_rule(convention, front, right):
    cube = NavigationCube(convention=convention, front=front)
    for face in F:
        assert_close(
            convention.cross(cube.text_right(face), cube.text_up(face)),
            cube.normal(face),
            face.value,
        )
    assert_close(cube.text_up(F.FRONT), convention.up.unit_vector, "front")
    assert_close(cube.text_up(F.TOP), scale(front.unit_vector, -1), "top")


def test_face_labels_name_the_faces():
    assert [f.label for f in F] == ["TOP", "BOTTOM", "FRONT", "BACK", "LEFT", "RIGHT"]


def _views(up: Vector3, front: Vector3, right: Vector3):
    """Yields each view's name, camera offset, and faces least direct first."""
    yield "top", scale(up, 10), [F.TOP]
    yield "bottom", scale(up, -10), [F.BOTTOM]
    yield "front", scale(front, 10), [F.FRONT]
    yield "right", scale(right, 10), [F.RIGHT]
    yield (
        "front-right-top, top most direct",
        add(add(scale(front, 2), scale(right, 3)), scale(up, 4)),
        [F.FRONT, F.RIGHT, F.TOP],
    )
    yield (
        "back-left-top diagonal, tied faces in face order",
        add(add(scale(front, -3), scale(right, -3)), scale(up, 3)),
        [F.TOP, F.BACK, F.LEFT],
    )


@pytest.mark.parametrize(("convention", "front", "right"), NORMALS)
def test_visible_faces_face_the_viewer_least_direct_first(convention, front, right):
    cube = NavigationCube(convention=convention, front=front)
    for name, offset, faces in _views(
        convention.up.unit_vector, front.unit_vector, right
    ):
        seen = cube.visible_faces(_camera(convention, offset), RECT)
        assert [v.face for v in seen] == faces, name
        for a, b in zip(seen, seen[1:], strict=False):
            assert b.facing > a.facing - TOLERANCE, name


@pytest.mark.parametrize(("convention", "front", "right"), NORMALS)
def test_an_axis_view_shows_an_upright_square_filling_the_inscribed_size(
    convention, front, right
):
    cube = NavigationCube(convention=convention, front=front)
    for face in F:
        camera = _camera(convention, scale(cube.normal(face), 10))
        (view,) = cube.visible_faces(camera, RECT)
        bl, br, tr, tl = view.corners
        assert view.facing == pytest.approx(1, rel=0, abs=TOLERANCE), face.value
        assert_close((br[0] - bl[0], br[1] - bl[1]), (EDGE, 0), face.value)
        assert_close((tl[0] - bl[0], tl[1] - bl[1]), (0, -EDGE), face.value)
        assert_close((tr[0] - tl[0], tr[1] - tl[1]), (EDGE, 0), face.value)
        assert_close(_center(view.corners), RECT_CENTER, face.value)


@pytest.mark.parametrize(("convention", "front", "right"), NORMALS)
def test_the_top_view_puts_front_along_the_bottom_edge(convention, front, right):
    cube = NavigationCube(convention=convention, front=front)
    camera = _camera(convention, scale(convention.up.unit_vector, 10))
    (top,) = cube.visible_faces(camera, RECT)
    bl, br, _, _ = top.corners
    # The bottom edge of the Top label is the edge Top shares with Front:
    # both its corners lie on the Front side of the cube.
    assert bl[1] == pytest.approx(br[1], rel=0, abs=TOLERANCE)
    assert bl[1] > RECT_CENTER[1]


@pytest.mark.parametrize(("convention", "front", "right"), NORMALS)
def test_every_corner_stays_inside_the_rectangle(convention, front, right):
    cube = NavigationCube(convention=convention, front=front)
    up = convention.up.unit_vector
    for offset in [
        (1.0, 1.0, 1.0),
        (-3.0, 0.5, 2.0),
        (0.2, -4.0, -1.0),
        add(scale(up, 5), scale(front.unit_vector, 0.01)),
    ]:
        for view in cube.visible_faces(_camera(convention, offset), RECT):
            for x, y in view.corners:
                assert RECT.left <= x <= RECT.right
                assert RECT.top <= y <= RECT.bottom


def test_a_front_along_another_horizontal_axis_turns_the_side_faces():
    cube = NavigationCube(convention=Y_UP_RIGHT, front=SignedAxis(SpatialAxis.Z))
    assert_close(cube.normal(F.FRONT), (0, 0, 1), "front")
    assert_close(cube.normal(F.RIGHT), (1, 0, 0), "right")
    assert_close(cube.text_up(F.TOP), (0, 0, -1), "top text up")


@pytest.mark.parametrize(
    "front",
    [
        pytest.param(SignedAxis(SpatialAxis.Y), id="along the up axis"),
        pytest.param(MINUS_Y, id="against the up axis"),
    ],
)
def test_a_front_along_the_up_axis_raises(front):
    with pytest.raises(ValueError):
        NavigationCube(convention=Y_UP_RIGHT, front=front)
