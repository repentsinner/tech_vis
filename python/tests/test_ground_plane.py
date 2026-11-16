"""The ground grid behaves as the Dart reference's tests pin."""

import math

import pytest

from conftest import (
    TOLERANCE,
    Y_UP_LEFT,
    Y_UP_RIGHT,
    Z_UP_LEFT,
    Z_UP_RIGHT,
    billboards_of,
    fake_text_resolver,
    lines_of,
    texts_of,
)
from tech_vis import (
    BillboardPrimitive,
    CameraBasis,
    CircularGroundPatch,
    CoordinateConvention,
    DisplayFormat,
    GroundGrid,
    GroundGridStyle,
    GroundPatch,
    Handedness,
    LinePrimitive,
    RectangularGroundPatch,
    SpatialAxis,
    TextRequest,
    UnitSystem,
    Vector3,
    ViewerFacingOrientation,
    create_ground_grid,
    ground_minor_step,
    tokens,
    world_units_per_pixel_at,
)
from tech_vis._vec import ORIGIN, add, normalized, scale

Z_UP = Z_UP_RIGHT
CONVENTIONS = [
    Z_UP_RIGHT,
    Z_UP_LEFT,
    Y_UP_RIGHT,
    Y_UP_LEFT,
    CoordinateConvention(up=SpatialAxis.X, handedness=Handedness.RIGHT),
]

FOV = math.pi / 4
VIEWPORT_HEIGHT = 720.0

# Keys that let a test tell each kind of primitive apart.
MINOR = "minor"
MAJOR = "major"
LABEL = "label"

DEFAULT_PATCH = RectangularGroundPatch(half_extent_u=500, half_extent_v=300)
DEFAULT_STYLE = GroundGridStyle()


def _camera(
    convention: CoordinateConvention, target: Vector3, distance: float
) -> CameraBasis:
    """Returns a camera ``distance`` from ``target``, up the declared up axis and
    off to one side, so the view is oblique to the plane."""
    u, v = convention.plane_axes
    direction = normalized(
        add(
            add(scale(convention.up.unit_vector, 2), scale(u.unit_vector, 0.5)),
            scale(v.unit_vector, -1),
        )
    )
    return CameraBasis.look_at(
        position=add(target, scale(direction, distance)),
        target=target,
        convention=convention,
    )


def _grid(
    *,
    convention: CoordinateConvention = Z_UP,
    patch: GroundPatch = DEFAULT_PATCH,
    display_format: DisplayFormat = DisplayFormat.METRIC,
    origin: Vector3 = ORIGIN,
    distance: float = 150,
    previous_minor_step: float | None = None,
    style: GroundGridStyle = DEFAULT_STYLE,
) -> GroundGrid:
    return create_ground_grid(
        convention=convention,
        patch=patch,
        display_format=display_format,
        world_units=UnitSystem.METRIC,
        camera=_camera(convention, ORIGIN, distance),
        target=ORIGIN,
        vertical_fov_radians=FOV,
        viewport_height=VIEWPORT_HEIGHT,
        resolve_text=fake_text_resolver,
        minor_key=MINOR,
        major_key=MAJOR,
        label_key=LABEL,
        origin=origin,
        previous_minor_step=previous_minor_step,
        style=style,
    )


def _lines(grid: GroundGrid, key: str | None = None) -> list[LinePrimitive]:
    return [p for p in lines_of(grid.primitives) if key is None or p.key == key]


def _labels(grid: GroundGrid) -> list[BillboardPrimitive]:
    return billboards_of(grid.primitives)


def _texts(grid: GroundGrid) -> list[str]:
    return texts_of(grid.primitives)


def _index(axis: SpatialAxis) -> int:
    return list(SpatialAxis).index(axis)


def test_style_defaults_come_from_the_style_tokens() -> None:
    style = GroundGridStyle()
    assert style.min_line_spacing_pixels == tokens.GROUND_GRID_MIN_LINE_SPACING_PIXELS
    assert style.step_margin == tokens.GROUND_GRID_STEP_MARGIN
    assert style.max_lines_per_axis == int(tokens.GROUND_GRID_MAX_LINES_PER_AXIS)
    assert style.minor_line_width == tokens.GROUND_GRID_MINOR_LINE_WIDTH
    assert style.major_line_width == tokens.GROUND_GRID_MAJOR_LINE_WIDTH
    assert style.label_pixel_size == tokens.GROUND_GRID_LABEL_PIXEL_SIZE


# Metric grid steps are powers of ten; the boundary sits at 10.
@pytest.mark.parametrize(
    ("spacing", "previous", "step"),
    [
        pytest.param(7.0, None, 10.0, id="no previous step"),
        pytest.param(7.0, 10.0, 10.0, id="previous step still fits"),
        pytest.param(10 * 1.2, 10.0, 10.0, id="just past the boundary holds"),
        pytest.param(10 * 1.3, 10.0, 100.0, id="past by the margin coarsens"),
        pytest.param(10 / 1.2, 100.0, 100.0, id="just back under holds"),
        pytest.param(10 / 1.3, 100.0, 10.0, id="back under by the margin refines"),
        pytest.param(3000.0, 10.0, 10000.0, id="a jump ignores the previous step"),
        pytest.param(7.0, 30.0, 10.0, id="an off-sequence previous is ignored"),
    ],
)
def test_minor_step(spacing: float, previous: float | None, step: float) -> None:
    actual = ground_minor_step(
        display_format=DisplayFormat.METRIC,
        minimum_spacing=spacing,
        previous_step=previous,
        margin=0.25,
    )
    assert actual == pytest.approx(step, rel=0, abs=TOLERANCE)


def test_minor_step_in_fractional_inch_steps_through_its_leading_run() -> None:
    step = ground_minor_step(
        display_format=DisplayFormat.FRACTIONAL_INCH, minimum_spacing=0.2
    )
    assert step == 0.25


@pytest.mark.parametrize("margin", [-0.1, math.nan, math.inf])
def test_minor_step_rejects_a_margin_not_zero_or_more(margin: float) -> None:
    with pytest.raises(ValueError):
        ground_minor_step(
            display_format=DisplayFormat.METRIC, minimum_spacing=1, margin=margin
        )


@pytest.mark.parametrize("convention", CONVENTIONS, ids=str)
def test_lies_in_the_plane_through_the_origin(
    convention: CoordinateConvention,
) -> None:
    origin = (3.0, -4.0, 5.0)
    grid = _grid(convention=convention, origin=origin)
    up = _index(convention.up)
    for line in _lines(grid):
        assert line.start[up] == pytest.approx(origin[up], abs=TOLERANCE)
        assert line.end[up] == pytest.approx(origin[up], abs=TOLERANCE)
    for label in _labels(grid):
        assert label.anchor[up] == pytest.approx(origin[up], abs=TOLERANCE)


@pytest.mark.parametrize("convention", CONVENTIONS, ids=str)
def test_each_line_runs_along_one_plane_axis(
    convention: CoordinateConvention,
) -> None:
    u, v = (_index(a) for a in convention.plane_axes)
    for line in _lines(_grid(convention=convention, origin=(3.0, -4.0, 5.0))):
        along_u = line.end[u] != line.start[u]
        along_v = line.end[v] != line.start[v]
        assert along_u != along_v, line


@pytest.mark.parametrize("distance", [200.0, 1500.0, 9000.0])
def test_minor_lines_keep_the_minimum_spacing_at_the_target(distance: float) -> None:
    grid = _grid(
        distance=distance,
        patch=RectangularGroundPatch(half_extent_u=1e4, half_extent_v=1e4),
        style=GroundGridStyle(max_lines_per_axis=10001),
    )
    per_pixel = world_units_per_pixel_at(
        ORIGIN, _camera(Z_UP, ORIGIN, distance), FOV, VIEWPORT_HEIGHT
    )
    assert per_pixel is not None
    spacing = grid.minor_step / per_pixel
    minimum = GroundGridStyle().min_line_spacing_pixels
    assert spacing >= minimum
    # The next finer step would fall below the minimum.
    assert spacing / 10 < minimum
    assert grid.major_step == pytest.approx(grid.minor_step * 10, abs=TOLERANCE)


def test_converts_world_units_to_the_display_format() -> None:
    # 12 px at the target spans 2.07 mm, or 0.082 in.
    patch = RectangularGroundPatch(half_extent_u=50, half_extent_v=30)
    mm = _grid(patch=patch)
    inches = _grid(patch=patch, display_format=DisplayFormat.DECIMAL_INCH)
    assert mm.minor_step == pytest.approx(10, abs=TOLERANCE)
    assert inches.minor_step == pytest.approx(0.1, abs=TOLERANCE)
    offsets = sorted({ln.start[0] for ln in _lines(inches) if ln.start[0] == ln.end[0]})
    assert offsets[1] - offsets[0] == pytest.approx(2.54, abs=TOLERANCE)


@pytest.mark.parametrize(
    ("key", "is_major", "width"),
    [
        (MAJOR, True, tokens.GROUND_GRID_MAJOR_LINE_WIDTH),
        (MINOR, False, tokens.GROUND_GRID_MINOR_LINE_WIDTH),
    ],
)
def test_major_lines_fall_on_every_major_step(
    key: str, is_major: bool, width: float
) -> None:
    grid = _grid()
    lines = _lines(grid, key)
    assert lines
    for line in lines:
        offset = line.start[0] if line.start[0] == line.end[0] else line.start[1]
        ratio = offset / grid.major_step
        assert (abs(ratio - round(ratio)) < TOLERANCE) == is_major, offset
        assert line.width_pixels == width


def test_minor_lines_draw_before_major_lines_and_labels_last() -> None:
    keys = [p.key for p in _grid().primitives]
    last_minor = len(keys) - 1 - keys[::-1].index(MINOR)
    last_major = len(keys) - 1 - keys[::-1].index(MAJOR)
    assert last_minor < keys.index(MAJOR)
    assert last_major < keys.index(LABEL)


def test_caps_the_lines_across_the_patch() -> None:
    grid = _grid(distance=50, style=GroundGridStyle(max_lines_per_axis=21))
    offsets = {ln.start[0] for ln in _lines(grid) if ln.start[0] == ln.end[0]}
    assert len(offsets) <= 21
    assert grid.minor_step == pytest.approx(100, abs=TOLERANCE)


def test_rectangular_patch_draws_each_line_whole_at_full_opacity() -> None:
    origin = (3.0, -4.0, 0.0)
    grid = _grid(origin=origin)
    center = [
        ln
        for ln in _lines(grid, MAJOR)
        if ln.start[0] == origin[0] and ln.end[0] == origin[0]
    ]
    assert len(center) == 1
    assert center[0].start[1] == pytest.approx(origin[1] - 300, abs=TOLERANCE)
    assert center[0].end[1] == pytest.approx(origin[1] + 300, abs=TOLERANCE)
    for line in _lines(grid):
        assert line.opacity == 1
        along_v = line.start[0] == line.end[0]
        length = math.dist(line.start, line.end)
        assert length == pytest.approx(600 if along_v else 1000, abs=TOLERANCE)


def test_circular_patch_draws_each_line_as_one_whole_chord() -> None:
    radius = 400.0
    grid = _grid(patch=CircularGroundPatch(radius=radius))
    for line in _lines(grid):
        assert line.opacity == 1
        along_v = line.start[0] == line.end[0]
        offset, low, high = (
            (line.start[0], line.start[1], line.end[1])
            if along_v
            else (line.start[1], line.start[0], line.end[0])
        )
        half = math.sqrt(radius * radius - offset * offset)
        assert low == pytest.approx(-half, abs=TOLERANCE)
        assert high == pytest.approx(half, abs=TOLERANCE)


def test_circular_patch_omits_the_tangent_lines() -> None:
    # A 10 mm minor step puts lines at the radius, where the chord has no length.
    grid = _grid(patch=CircularGroundPatch(radius=400))
    assert grid.minor_step == pytest.approx(10, abs=TOLERANCE)
    for line in _lines(grid):
        assert math.dist(line.start, line.end) > 0


FADE_ORIGIN = (3.0, -4.0, 5.0)
FADE_CONVENTIONS = [Z_UP_RIGHT, Y_UP_RIGHT]
CIRCLE = CircularGroundPatch(radius=400)


@pytest.mark.parametrize("convention", FADE_CONVENTIONS, ids=str)
def test_fade_centers_on_the_origin_along_the_plane_axes(
    convention: CoordinateConvention,
) -> None:
    fade = _grid(convention=convention, origin=FADE_ORIGIN).fade
    u, v = convention.plane_axes
    assert fade.center == FADE_ORIGIN
    assert fade.u == u.unit_vector
    assert fade.v == v.unit_vector


@pytest.mark.parametrize("convention", FADE_CONVENTIONS, ids=str)
def test_fade_holds_the_patch(convention: CoordinateConvention) -> None:
    fade = _grid(convention=convention, patch=CIRCLE, origin=FADE_ORIGIN).fade
    assert fade.patch is CIRCLE


@pytest.mark.parametrize("patch", [DEFAULT_PATCH, CIRCLE], ids=["rectangle", "circle"])
@pytest.mark.parametrize("convention", FADE_CONVENTIONS, ids=str)
def test_each_label_carries_the_fade_at_its_anchor(
    convention: CoordinateConvention, patch: GroundPatch
) -> None:
    grid = _grid(convention=convention, patch=patch, origin=FADE_ORIGIN)
    labels = _labels(grid)
    assert labels
    for label in labels:
        want = grid.fade.opacity_at(label.anchor)
        assert label.opacity == pytest.approx(want, abs=TOLERANCE), label.anchor


@pytest.mark.parametrize(
    ("patch", "at", "opacity"),
    [
        pytest.param(DEFAULT_PATCH, (0.0, 0.0), 1.0, id="rectangle, center"),
        pytest.param(DEFAULT_PATCH, (200.0, 0.0), 0.648, id="rectangle, 0.4 of u"),
        pytest.param(DEFAULT_PATCH, (-400.0, 0.0), 0.104, id="rectangle, 0.8 of u"),
        pytest.param(DEFAULT_PATCH, (0.0, 200.0), 7 / 27, id="rectangle, 2/3 of v"),
        pytest.param(
            DEFAULT_PATCH, (200.0, -200.0), 7 / 27, id="rectangle, larger fraction"
        ),
        pytest.param(DEFAULT_PATCH, (600.0, 0.0), 0.0, id="rectangle, past the edge"),
        pytest.param(CIRCLE, (100.0, 0.0), 0.84375, id="circle, 0.25"),
        pytest.param(CIRCLE, (0.0, -300.0), 0.15625, id="circle, 0.75"),
        pytest.param(CIRCLE, (120.0, 160.0), 0.5, id="circle, 0.5 off both axes"),
        pytest.param(CIRCLE, (300.0, 300.0), 0.0, id="circle, past the edge"),
    ],
)
@pytest.mark.parametrize("convention", FADE_CONVENTIONS, ids=str)
def test_opacity_at_is_one_minus_smoothstep_of_the_reach(
    convention: CoordinateConvention,
    patch: GroundPatch,
    at: tuple[float, float],
    opacity: float,
) -> None:
    fade = _grid(convention=convention, patch=patch, origin=FADE_ORIGIN).fade
    u, v = convention.plane_axes
    a, b = at
    point = add(add(FADE_ORIGIN, scale(u.unit_vector, a)), scale(v.unit_vector, b))
    assert fade.opacity_at(point) == pytest.approx(opacity, abs=TOLERANCE)
    # A point off the plane takes the fade of its projection.
    above = add(point, scale(convention.up.unit_vector, 50))
    assert fade.opacity_at(above) == pytest.approx(opacity, abs=TOLERANCE)


def test_labels_mark_each_major_line_where_it_crosses_the_origin_axes() -> None:
    anchors = [(b.anchor[0], b.anchor[1]) for b in _labels(_grid())]
    # Major step 100 inside 500 x 300 half extents: -400..400 on U, -200..200
    # on V, and one origin label.
    assert len(anchors) == 1 + 8 + 4
    assert anchors[0] == (0.0, 0.0)
    assert (-400.0, 0.0) in anchors
    assert (0.0, 200.0) in anchors


def test_labels_read_in_the_display_format() -> None:
    texts = _texts(_grid())
    assert texts[0] == "0 mm"
    assert "-400 mm" in texts
    assert "200 mm" in texts


def test_labels_face_the_viewer() -> None:
    for label in _labels(_grid()):
        assert isinstance(label.orientation, ViewerFacingOrientation)
        assert isinstance(label.content.value, TextRequest)
        height = label.content.value.height_pixels
        assert height == tokens.GROUND_GRID_LABEL_PIXEL_SIZE
        assert label.alignment == (0.0, 0.0)


def test_labels_promote_with_the_set() -> None:
    far = _grid(
        distance=2e5,
        patch=RectangularGroundPatch(half_extent_u=5e5, half_extent_v=5e5),
    )
    assert all(t.endswith(" m") for t in _texts(far))


def test_an_invisible_edge_label_stays_out_of_the_set() -> None:
    # Major lines every 1 m reach the 10 m edge, where opacity is zero, so the
    # set tops out at 9 m and stays in millimeters.
    grid = _grid(
        distance=2000,
        patch=RectangularGroundPatch(half_extent_u=1e4, half_extent_v=1e4),
        style=GroundGridStyle(max_lines_per_axis=201),
    )
    assert grid.major_step == pytest.approx(1000, abs=TOLERANCE)
    texts = _texts(grid)
    assert "9000 mm" in texts
    assert all(t.endswith(" mm") for t in texts)


def test_keeps_the_previous_step_inside_the_margin() -> None:
    # 12 px spans 10 mm at a distance near 724.
    fresh = _grid(distance=700)
    kept = _grid(distance=770, previous_minor_step=fresh.minor_step)
    moved = _grid(distance=770)
    assert kept.minor_step == fresh.minor_step
    assert moved.minor_step != fresh.minor_step


def _create(**overrides: object) -> GroundGrid:
    arguments: dict = {
        "convention": Z_UP,
        "patch": CircularGroundPatch(radius=10),
        "display_format": DisplayFormat.METRIC,
        "world_units": UnitSystem.METRIC,
        "camera": _camera(Z_UP, ORIGIN, 10),
        "target": ORIGIN,
        "vertical_fov_radians": FOV,
        "viewport_height": VIEWPORT_HEIGHT,
        "resolve_text": fake_text_resolver,
        "minor_key": None,
        "major_key": None,
        "label_key": None,
    }
    arguments.update(overrides)
    return create_ground_grid(**arguments)


@pytest.mark.parametrize(
    "overrides",
    [
        pytest.param(
            {"target": _camera(Z_UP, ORIGIN, 20).position}, id="target behind"
        ),
        pytest.param({"style": GroundGridStyle(max_lines_per_axis=2)}, id="2 lines"),
        pytest.param({"patch": CircularGroundPatch(radius=0)}, id="empty disc"),
        pytest.param(
            {"patch": RectangularGroundPatch(half_extent_u=1, half_extent_v=math.inf)},
            id="infinite rectangle",
        ),
    ],
)
def test_create_rejects_invalid_input(overrides: dict) -> None:
    with pytest.raises(ValueError):
        _create(**overrides)
