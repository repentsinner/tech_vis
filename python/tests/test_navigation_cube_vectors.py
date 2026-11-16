"""The navigation cube agrees with ``vectors/navigation_cube.json``."""

from typing import Any

import pytest

from conftest import (
    TOLERANCE,
    assert_close,
    json_convention,
    json_vector3,
    load_vectors,
)
from tech_vis import (
    CameraBasis,
    NavigationCube,
    NavigationCubeFace,
    SignedAxis,
    SpatialAxis,
    ViewportRect,
    tokens,
)

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return load_vectors("navigation_cube.json")


def _cube(given: Json) -> NavigationCube:
    front = given["front"]
    return NavigationCube(
        convention=json_convention(given["convention"]),
        front=SignedAxis(SpatialAxis(front["axis"]), negative=front["negative"]),
    )


def test_generated_from_the_current_style_version(fixture: Json) -> None:
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_faces(fixture: Json) -> None:
    cases = fixture["NavigationCube.faces"]
    assert cases, "no NavigationCube.faces cases"
    for c in cases:
        cube = _cube(c["input"])
        output = c["output"]
        assert list(output) == [f.value for f in NavigationCubeFace]
        for face in NavigationCubeFace:
            want = output[face.value]
            reason = f"{c['name']}, {face.value}"
            assert face.label == want["label"], reason
            assert_close(cube.normal(face), want["normal"], f"{reason} normal")
            assert_close(
                cube.text_right(face), want["textRight"], f"{reason} text_right"
            )
            assert_close(cube.text_up(face), want["textUp"], f"{reason} text_up")


def test_visible_faces(fixture: Json) -> None:
    cases = fixture["NavigationCube.visibleFaces"]
    assert cases, "no NavigationCube.visibleFaces cases"
    for c in cases:
        given, name = c["input"], c["name"]
        camera = CameraBasis.look_at(
            position=json_vector3(given["cameraPosition"]),
            target=json_vector3(given["cameraTarget"]),
            convention=json_convention(given["convention"]),
        )
        seen = _cube(given).visible_faces(camera, ViewportRect(*given["rect"]))
        want = c["output"]["faces"]
        assert [v.face.value for v in seen] == [w["face"] for w in want], name
        for view, w in zip(seen, want, strict=True):
            reason = f"{name}, {view.face.value}"
            assert view.face.label == w["label"], reason
            assert view.facing == pytest.approx(w["facing"], rel=0, abs=TOLERANCE), (
                reason
            )
            assert_close(
                [n for p in view.corners for n in p],
                [n for p in w["corners"] for n in p],
                reason,
            )
