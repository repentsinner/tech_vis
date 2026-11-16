"""Scenes rebuilt through the package land where the Dart reference says."""

import math
from collections.abc import Iterator
from typing import Any

import pytest

from conftest import (
    FAKE_CHARACTER_ASPECT,
    TOLERANCE,
    assert_close,
    fake_text_resolver,
    json_convention,
    json_leader_style,
    json_vector3,
    load_vectors,
)
from tech_vis import (
    BillboardPrimitive,
    BoundingBox,
    CalloutQuadrant,
    CameraBasis,
    CoordinateConvention,
    CoordinateFrameDescriptor,
    Handedness,
    LinePrimitive,
    MarkerPrimitive,
    Primitive,
    QuadPrimitive,
    TextRequest,
    Vector2,
    Vector3,
    billboard_offset_position,
    compute_callout_leader_geometry,
    create_bounding_box,
    create_callout_label,
    create_callout_leader_lines,
    create_coordinate_frame,
    create_marker,
    marker_transform,
    tokens,
    world_to_screen,
    world_units_per_pixel_at,
)
from tech_vis._vec import along

type Json = dict[str, Any]


@pytest.fixture(scope="module")
def fixture() -> Json:
    return load_vectors("reference_screen_geometry.json")


class _Frame:
    """One camera and viewport, read from a fixture view."""

    def __init__(self, camera: Json, convention: CoordinateConvention) -> None:
        self.camera = CameraBasis.look_at(
            position=json_vector3(camera["position"]),
            target=json_vector3(camera["target"]),
            convention=convention,
        )
        self.fov_radians = math.radians(camera["verticalFovDegrees"])
        width, height = camera["viewport"]
        self.viewport: Vector2 = (float(width), float(height))

    def screen(self, point: Vector3) -> Vector2:
        result = world_to_screen(point, self.camera, self.fov_radians, self.viewport)
        assert result is not None
        return result

    def world_units_per_pixel_at(self, point: Vector3) -> float:
        result = world_units_per_pixel_at(
            point, self.camera, self.fov_radians, self.viewport[1]
        )
        assert result is not None
        return result


def _build(build: Json, convention: CoordinateConvention, frame: _Frame) -> list:
    """Rebuilds a scene's primitives through the public factories."""
    match build["factory"]:
        case "BoundingBoxFactory.createCube":
            return create_bounding_box(
                BoundingBox(
                    min_bounds=json_vector3(build["minBounds"]),
                    max_bounds=json_vector3(build["maxBounds"]),
                ),
                key=None,
                fill_opacity=build["fillOpacity"],
                edge_width=build["edgeWidth"],
            )
        case "CoordinateFrameFactory.create":
            return create_coordinate_frame(
                CoordinateFrameDescriptor(
                    origin=json_vector3(build["origin"]),
                    length=build["length"],
                    line_thickness=build["lineThickness"],
                    label_pixel_size=build["labelPixelSize"],
                    label_offset_pixels=build["labelOffsetPixels"],
                ),
                key_for=lambda _axis: None,
                resolve_text=fake_text_resolver,
            )
        case "createCalloutLabel":
            style = json_leader_style(build["style"])
            primitives: list[Primitive] = []
            for c in build["callouts"]:
                anchor = json_vector3(c["anchor"])
                quadrant = CalloutQuadrant(c["quadrant"])
                leader = compute_callout_leader_geometry(
                    anchor=anchor,
                    camera_right=frame.camera.right,
                    camera_up=frame.camera.up,
                    world_units_per_pixel=frame.world_units_per_pixel_at(anchor),
                    quadrant=quadrant,
                    style=style,
                )
                primitives += create_callout_leader_lines(leader, key=None, opacity=1)
                primitives.append(
                    create_callout_label(
                        leader,
                        quadrant,
                        content=fake_text_resolver(
                            TextRequest(
                                text=c["text"], height_pixels=c["textHeightPixels"]
                            )
                        ),
                        key=None,
                        opacity=1,
                    )
                )
            return primitives
        case "MarkerFactory.create":
            return [
                create_marker(
                    json_vector3(m["position"]),
                    convention,
                    key=None,
                    diameter_pixels=m["diameterPixels"],
                )
                for m in build["markers"]
            ]
        case other:
            raise ValueError(f"unknown factory {other!r}")


def _distance(a: Vector2, b: Vector2) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _check_billboard(
    billboard: BillboardPrimitive, record: Json, frame: _Frame, reason: str
) -> None:
    offset = billboard.offset
    placed = (
        billboard.anchor
        if offset is None
        else billboard_offset_position(
            anchor=billboard.anchor,
            direction=offset.direction,
            offset_pixels=offset.pixels,
            world_units_per_pixel=frame.world_units_per_pixel_at(billboard.anchor),
            camera=frame.camera,
        )
    )
    anchor = frame.screen(placed)
    assert_close(anchor, record["anchor"], f"{reason} anchor")
    if offset is not None:
        # The label sits its offset in pixels from the axis end on screen.
        assert _distance(anchor, frame.screen(billboard.anchor)) == pytest.approx(
            offset.pixels, rel=0, abs=TOLERANCE
        ), f"{reason} offset"
    assert_close(billboard.alignment, record["alignment"], f"{reason} alignment")

    asked = billboard.content.value
    assert isinstance(asked, TextRequest), reason
    assert record["textRequest"]["text"] == asked.text, reason
    assert record["textRequest"]["heightPixels"] == pytest.approx(
        asked.height_pixels, rel=0, abs=TOLERANCE
    ), reason
    size = record["contentSize"]
    assert_close(
        (billboard.content.width_pixels, billboard.content.height_pixels),
        size,
        f"{reason} contentSize",
    )

    # The box follows from the font-independent anchor and alignment and the
    # recorded content size, so a renderer can rebuild it from its own.
    width, height = size
    left = anchor[0] - billboard.alignment[0] * width
    top = anchor[1] - (1 - billboard.alignment[1]) * height
    assert_close(
        (left, top, left + width, top + height), record["box"], f"{reason} box"
    )


def _check_marker(
    marker: MarkerPrimitive, record: Json, frame: _Frame, reason: str
) -> None:
    assert_close(frame.screen(marker.position), record["center"], f"{reason} center")
    transform = marker_transform(
        marker, frame.camera, frame.fov_radians, frame.viewport[1]
    )
    assert transform is not None, reason
    radius = transform[0][0]
    right = frame.camera.right
    left_x = frame.screen(along(marker.position, right, -radius))[0]
    right_x = frame.screen(along(marker.position, right, radius))[0]
    assert record["diameterPixels"] == pytest.approx(
        right_x - left_x, rel=0, abs=TOLERANCE
    ), f"{reason} diameter"
    # A marker draws at its pixel diameter at any depth.
    assert record["diameterPixels"] == pytest.approx(
        marker.diameter_pixels, rel=0, abs=TOLERANCE
    ), f"{reason} diameter"


def _check_primitive(
    primitive: Primitive, record: Json, frame: _Frame, reason: str
) -> None:
    match primitive:
        case LinePrimitive():
            assert record["type"] == "line", reason
            assert_close(frame.screen(primitive.start), record["start"], reason)
            assert_close(frame.screen(primitive.end), record["end"], reason)
            assert record["widthPixels"] == pytest.approx(
                primitive.width_pixels, rel=0, abs=TOLERANCE
            ), reason
        case QuadPrimitive():
            assert record["type"] == "quad", reason
            assert len(record["corners"]) == len(primitive.corners), reason
            for corner, want in zip(primitive.corners, record["corners"], strict=True):
                assert_close(frame.screen(corner), want, reason)
        case BillboardPrimitive():
            assert record["type"] == "billboard", reason
            _check_billboard(primitive, record, frame, reason)
        case MarkerPrimitive():
            assert record["type"] == "marker", reason
            _check_marker(primitive, record, frame, reason)
        case _:
            pytest.fail(f"{reason}: no sample scene emits {type(primitive).__name__}")


def _views(fixture: Json) -> Iterator[tuple[Json, Json, CoordinateConvention]]:
    for scene in fixture["scenes"]:
        convention = json_convention(scene["convention"])
        for view in scene["views"]:
            yield scene, view, convention


def test_generated_from_the_current_style_version(fixture: Json):
    assert fixture["styleVersion"] == tokens.STYLE_VERSION


def test_records_the_stand_in_typeface(fixture: Json):
    resolver = fixture["textResolver"]
    assert resolver["characterWidthPerHeight"] == FAKE_CHARACTER_ASPECT


def test_covers_every_factory_two_up_axes_and_both_handednesses(fixture: Json):
    conventions = {json_convention(s["convention"]) for s in fixture["scenes"]}
    assert len({c.up for c in conventions}) == 2
    assert {c.handedness for c in conventions} == set(Handedness)
    assert {s["build"]["factory"] for s in fixture["scenes"]} == {
        "BoundingBoxFactory.createCube",
        "CoordinateFrameFactory.create",
        "createCalloutLabel",
        "MarkerFactory.create",
    }
    types = {p["type"] for _, view, _ in _views(fixture) for p in view["primitives"]}
    assert types == {"line", "quad", "billboard", "marker"}


def test_matches_each_scene_rebuilt_and_projected(fixture: Json):
    assert fixture["scenes"]
    for scene, view, convention in _views(fixture):
        reason = f"{scene['name']} / {view['name']}"
        frame = _Frame(view["camera"], convention)
        primitives = _build(scene["build"], convention, frame)
        records = view["primitives"]
        assert len(records) == len(primitives), reason
        for i, (primitive, record) in enumerate(zip(primitives, records, strict=True)):
            _check_primitive(primitive, record, frame, f"{reason} #{i}")


def test_callout_leaders_keep_their_style_lengths_on_screen(fixture: Json):
    callout_views = [
        (scene, view, convention)
        for scene, view, convention in _views(fixture)
        if scene["build"]["factory"] == "createCalloutLabel"
    ]
    assert callout_views
    for scene, view, convention in callout_views:
        style = json_leader_style(scene["build"]["style"])
        frame = _Frame(view["camera"], convention)
        primitives = _build(scene["build"], convention, frame)
        lines = [p for p in primitives if isinstance(p, LinePrimitive)]
        assert len(lines) % 2 == 0
        # Each callout emits its angled segment, then its horizontal one.
        for i in range(0, len(lines), 2):
            for line, pixels in (
                (lines[i], style.angled_length_pixels),
                (lines[i + 1], style.horizontal_length_pixels),
            ):
                length = _distance(frame.screen(line.end), frame.screen(line.start))
                assert length == pytest.approx(pixels, rel=0, abs=TOLERANCE), (
                    f"{scene['name']} leader {i}"
                )


def _pinhole(point: Vector3, frame: _Frame) -> Vector2:
    """Projects ``point`` through an independent pinhole camera."""
    camera = frame.camera
    width, height = frame.viewport
    focal = (height / 2) / math.tan(frame.fov_radians / 2)
    rel = tuple(p - c for p, c in zip(point, camera.position, strict=True))

    def dot(axis: Vector3) -> float:
        return sum(r * a for r, a in zip(rel, axis, strict=True))

    depth = dot(camera.forward)
    return (
        width / 2 + dot(camera.right) * focal / depth,
        height / 2 - dot(camera.up) * focal / depth,
    )


def test_lines_agree_with_an_independent_pinhole_projection(fixture: Json):
    for scene, view, convention in _views(fixture):
        frame = _Frame(view["camera"], convention)
        primitives = _build(scene["build"], convention, frame)
        for i, primitive in enumerate(primitives):
            if not isinstance(primitive, LinePrimitive):
                continue
            record = view["primitives"][i]
            for point, key in ((primitive.start, "start"), (primitive.end, "end")):
                assert_close(
                    _pinhole(point, frame),
                    record[key],
                    f"{scene['name']} / {view['name']} #{i} {key}",
                )
