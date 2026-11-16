"""Angular and radial dimensions behave as the Dart reference's tests pin."""

import math

import pytest

from conftest import (
    TOLERANCE,
    assert_close,
    billboards_of,
    fake_text_resolver,
    lines_of,
    texts_of,
)
from tech_vis import (
    CameraBasis,
    CoordinateConvention,
    CoplanarOrientation,
    DecimalMarker,
    DimensionStyle,
    DisplayFormat,
    DraftingConvention,
    Handedness,
    LinePrimitive,
    NumberFormatting,
    Primitive,
    RadialMeasure,
    SpatialAxis,
    UnitSystem,
    Vector2,
    Vector3,
    ViewerFacingOrientation,
    create_angular_dimension,
    create_radial_dimension,
    tokens,
)
from tech_vis._vec import ORIGIN, dot, length, normalized, scale, sub

Z_UP = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.RIGHT)
FOV = math.pi / 3
VIEWPORT: Vector2 = (1000.0, 1000.0)
DEPTH = 400.0

# A top view of the Z-up XY plane: screen right is +X and screen up is +Y,
# and every point on the plane sits at one depth, so pixel lengths on the
# plane measure exactly.
TOP_VIEW = CameraBasis.look_at(position=(0, 0, DEPTH), target=ORIGIN, convention=Z_UP)

# World units per pixel everywhere on the plane of the top view.
PIXEL = 2 * DEPTH * math.tan(FOV / 2) / VIEWPORT[1]
RADIUS = tokens.DIMENSION_ARC_RADIUS_PIXELS * PIXEL

X: Vector3 = (1.0, 0.0, 0.0)
Y: Vector3 = (0.0, 1.0, 0.0)
Z: Vector3 = (0.0, 0.0, 1.0)

# Tolerance on whether a point lies on the arc, looser than the vector
# tolerance because arc points come through sine and cosine.
ON_ARC = 1e-6

DEFAULT_STYLE = DimensionStyle()
DEFAULT_NUMBERS = NumberFormatting()


def _at(degrees: float) -> Vector3:
    """Returns the unit vector in the XY plane at ``degrees`` from +X."""
    r = degrees * math.pi / 180
    return (math.cos(r), math.sin(r), 0.0)


def _neg(v: Vector3) -> Vector3:
    return scale(v, -1.0)


def _angular(
    first: Vector3,
    second: Vector3,
    *,
    vertex: Vector3 = ORIGIN,
    drafting: DraftingConvention = DraftingConvention.ISO_ORIENTED,
    numbers: NumberFormatting = DEFAULT_NUMBERS,
    style: DimensionStyle = DEFAULT_STYLE,
    key: object = None,
    opacity: float = 1.0,
) -> list[Primitive]:
    return create_angular_dimension(
        vertex=vertex,
        first=first,
        second=second,
        drafting=drafting,
        camera=TOP_VIEW,
        vertical_fov_radians=FOV,
        viewport_size=VIEWPORT,
        resolve_text=fake_text_resolver,
        key=key,
        numbers=numbers,
        style=style,
        opacity=opacity,
    )


def _radial(
    radius: float,
    *,
    center: Vector3 = ORIGIN,
    normal: Vector3 = Z,
    measure: RadialMeasure = RadialMeasure.RADIUS,
    drafting: DraftingConvention = DraftingConvention.ISO_ORIENTED,
    display_format: DisplayFormat = DisplayFormat.METRIC,
    world_units: UnitSystem = UnitSystem.METRIC,
    direction: Vector3 | None = None,
    key: object = None,
    opacity: float = 1.0,
) -> list[Primitive]:
    return create_radial_dimension(
        center=center,
        radius=radius,
        normal=normal,
        measure=measure,
        drafting=drafting,
        display_format=display_format,
        world_units=world_units,
        camera=TOP_VIEW,
        vertical_fov_radians=FOV,
        viewport_size=VIEWPORT,
        resolve_text=fake_text_resolver,
        key=key,
        direction=direction,
        opacity=opacity,
    )


def _arc(primitives: list[Primitive], radius: float) -> list[LinePrimitive]:
    """Returns the arc's lines: those with both ends ``radius`` from the
    origin."""
    return [
        ln
        for ln in lines_of(primitives)
        if abs(length(ln.start) - radius) < ON_ARC
        and abs(length(ln.end) - radius) < ON_ARC
    ]


def test_value_rounds_to_the_style_resolution_with_the_app_numbers() -> None:
    texts = texts_of(
        _angular(
            X,
            _at(22.5),
            numbers=NumberFormatting(decimal_marker=DecimalMarker.COMMA),
            style=DimensionStyle(angle_resolution_degrees=0.5),
        )
    )
    assert texts == ["22,5°"]


@pytest.mark.parametrize(
    ("first", "second", "want"),
    [
        pytest.param(X, scale(Y, 3), "90°", id="right angle"),
        pytest.param(scale(X, 2), _at(45), "45°", id="acute"),
        pytest.param(_at(10), _at(145.25), "135.3°", id="obtuse"),
        pytest.param(X, (0, 1, 1), "90°", id="out of the plane"),
        pytest.param(_at(60), X, "60°", id="clockwise order"),
    ],
)
def test_angular_value(first: Vector3, second: Vector3, want: str) -> None:
    assert texts_of(_angular(first, second)) == [want]


@pytest.mark.parametrize(
    ("first", "second", "vertex"),
    [
        pytest.param(ORIGIN, Y, ORIGIN, id="a zero first vector"),
        pytest.param(X, ORIGIN, ORIGIN, id="a zero second vector"),
        pytest.param(X, scale(X, 4), ORIGIN, id="parallel vectors"),
        pytest.param(X, _neg(X), ORIGIN, id="opposed vectors"),
        pytest.param(X, Y, (0, 0, 2 * DEPTH), id="a vertex behind the camera"),
    ],
)
def test_angular_emits_nothing(
    first: Vector3, second: Vector3, vertex: Vector3
) -> None:
    assert _angular(first, second, vertex=vertex) == []


@pytest.mark.parametrize(
    ("second", "angle"),
    [
        pytest.param(Y, math.pi / 2, id="quarter turn"),
        pytest.param(_at(45), math.pi / 4, id="eighth turn"),
        pytest.param(_at(170), 170 * math.pi / 180, id="near a half turn"),
    ],
)
def test_arc_runs_at_the_radius_token_one_line_per_segment(
    second: Vector3, angle: float
) -> None:
    arc = _arc(
        _angular(
            scale(X, 100),
            scale(second, 100),
            drafting=DraftingConvention.ISO_REFERENCING,
        ),
        RADIUS,
    )
    segments = math.ceil(
        tokens.DIMENSION_ARC_RADIUS_PIXELS * angle / tokens.DIMENSION_ARC_SEGMENT_PIXELS
    )
    assert len(arc) == segments
    assert_close(arc[0].start, scale(X, RADIUS), "starts on the first leg")
    assert_close(arc[-1].end, scale(second, RADIUS), "ends on the second leg")
    for i in range(1, len(arc)):
        assert_close(arc[i].start, arc[i - 1].end, f"segment {i} joins")
    for line in arc:
        assert line.width_pixels == tokens.DIMENSION_LINE_WIDTH


def test_an_inlined_arc_breaks_around_its_midpoint_for_the_text() -> None:
    primitives = _angular(
        scale(X, 100), scale(Y, 100), drafting=DraftingConvention.ASME_INLINED
    )
    arc = _arc(primitives, RADIUS)
    (label,) = billboards_of(primitives)
    assert_close(label.anchor, scale(_at(45), RADIUS), "text at the midpoint")
    assert isinstance(label.orientation, ViewerFacingOrientation)
    # The break sits where consecutive arc lines no longer join.
    breaks = [
        i
        for i in range(1, len(arc))
        if length(sub(arc[i].start, arc[i - 1].end)) > ON_ARC
    ]
    assert len(breaks) == 1
    before = arc[breaks[0] - 1].end
    after = arc[breaks[0]].start
    # At 45 degrees on screen the text extent is its box projected onto the
    # arc's tangent.
    content = label.content
    extent = (content.width_pixels + content.height_pixels) * math.sqrt(0.5)
    half_degrees = math.degrees(
        (extent / 2 + tokens.DIMENSION_TEXT_GAP_PIXELS)
        / tokens.DIMENSION_ARC_RADIUS_PIXELS
    )
    assert_close(before, scale(_at(45 - half_degrees), RADIUS), "before")
    assert_close(after, scale(_at(45 + half_degrees), RADIUS), "after")


def test_witness_line_extends_a_leg_that_ends_short_of_the_arc() -> None:
    leg = RADIUS / 2
    witness = lines_of(
        _angular(
            scale(X, leg), scale(Y, 100), drafting=DraftingConvention.ISO_REFERENCING
        )
    )[0]
    gap = tokens.DIMENSION_WITNESS_GAP_ISO_PIXELS * PIXEL
    extension = tokens.DIMENSION_WITNESS_EXTENSION_PIXELS * PIXEL
    assert_close(witness.start, scale(X, leg + gap), "starts past the gap")
    assert_close(witness.end, scale(X, RADIUS + extension), "runs past the arc")


def test_witness_lines_are_omitted_where_the_legs_reach_the_arc() -> None:
    primitives = _angular(
        scale(X, 100), scale(Y, 100), drafting=DraftingConvention.ISO_REFERENCING
    )
    assert lines_of(primitives)[0] is _arc(primitives, RADIUS)[0]


def test_witness_line_uses_the_asme_gap_under_asme() -> None:
    leg = RADIUS / 4
    witness = lines_of(
        _angular(
            scale(X, leg), scale(Y, 100), drafting=DraftingConvention.ASME_REFERENCING
        )
    )[0]
    gap = tokens.DIMENSION_WITNESS_GAP_ASME_PIXELS * PIXEL
    assert_close(witness.start, scale(X, leg + gap), "starts past the gap")


def test_arrowheads_point_along_the_arc_into_it_at_each_end() -> None:
    primitives = _angular(
        scale(X, 100), scale(Y, 100), drafting=DraftingConvention.ISO_REFERENCING
    )
    arc_count = len(_arc(primitives, RADIUS))
    barbs = lines_of(primitives)[arc_count : arc_count + 4]
    arrow_length = tokens.DIMENSION_ARROW_LENGTH_PIXELS * PIXEL
    half_width = tokens.DIMENSION_ARROW_WIDTH_PIXELS / 2 * PIXEL
    for b in barbs[:2]:
        assert_close(b.start, scale(X, RADIUS), "first tip")
        assert b.end[1] == pytest.approx(arrow_length, abs=TOLERANCE)
    for b in barbs[2:]:
        assert_close(b.start, scale(Y, RADIUS), "second tip")
        assert b.end[0] == pytest.approx(arrow_length, abs=TOLERANCE)
    # The arc runs +Y from its first end, with one barb either side of it.
    assert sorted(b.end[0] for b in barbs[:2]) == pytest.approx(
        [RADIUS - half_width, RADIUS + half_width], abs=TOLERANCE
    )


def test_oriented_text_lies_along_the_tangent_at_the_arc_midpoint() -> None:
    (label,) = billboards_of(_angular(scale(X, 100), scale(Y, 100)))
    assert_close(label.anchor, scale(_at(45), RADIUS), "at the midpoint")
    assert isinstance(label.orientation, CoplanarOrientation)
    # The tangent at 45 degrees runs toward -X, +Y; read left to right.
    assert_close(label.orientation.right, _at(-45), "reads along the tangent")
    assert label.offset is not None
    assert_close(label.offset.direction, _at(45), "lifted outward")


@pytest.mark.parametrize(
    "drafting",
    [DraftingConvention.ISO_REFERENCING, DraftingConvention.ASME_REFERENCING],
)
def test_referencing_leads_the_text_off_the_arc_midpoint(
    drafting: DraftingConvention,
) -> None:
    primitives = _angular(scale(X, 100), scale(Y, 100), drafting=drafting)
    (label,) = billboards_of(primitives)
    angled, horizontal = lines_of(primitives)[-2:]
    assert isinstance(label.orientation, ViewerFacingOrientation)
    assert_close(horizontal.end, label.anchor, "label at leader end")
    # The bisector points to top-right on screen: the leader leaves there.
    middle = scale(_at(45), RADIUS)
    assert angled.start[0] > middle[0]
    assert angled.start[1] > middle[1]


@pytest.mark.parametrize(
    "drafting", [DraftingConvention.ISO_ORIENTED, DraftingConvention.ASME_INLINED]
)
def test_angular_falls_back_to_referencing_on_a_small_angle(
    drafting: DraftingConvention,
) -> None:
    primitives = _angular(scale(X, 100), scale(_at(5), 100), drafting=drafting)
    # Arc, four barbs, two leader lines.
    assert len(lines_of(primitives)) == len(_arc(primitives, RADIUS)) + 6
    (label,) = billboards_of(primitives)
    assert isinstance(label.orientation, ViewerFacingOrientation)


def test_angular_carries_the_key_and_opacity() -> None:
    primitives = _angular(X, Y, key="angle", opacity=0.4)
    assert primitives
    for p in primitives:
        assert p.key == "angle"
        assert p.opacity == 0.4


RIM = scale(_at(45), 50)


@pytest.mark.parametrize(
    ("measure", "display_format", "world_units", "text", "start"),
    [
        pytest.param(
            RadialMeasure.RADIUS,
            DisplayFormat.METRIC,
            UnitSystem.METRIC,
            "R50 mm",
            ORIGIN,
            id="radius",
        ),
        pytest.param(
            RadialMeasure.DIAMETER,
            DisplayFormat.METRIC,
            UnitSystem.METRIC,
            "⌀100 mm",
            _neg(RIM),
            id="diameter",
        ),
        pytest.param(
            RadialMeasure.DIAMETER,
            DisplayFormat.FRACTIONAL_INCH,
            UnitSystem.IMPERIAL,
            "⌀8' 4\"",
            _neg(RIM),
            id="diameter in fractional inch",
        ),
    ],
)
def test_radial_runs_toward_screen_top_right(
    measure: RadialMeasure,
    display_format: DisplayFormat,
    world_units: UnitSystem,
    text: str,
    start: Vector3,
) -> None:
    primitives = _radial(
        50,
        measure=measure,
        display_format=display_format,
        world_units=world_units,
        drafting=DraftingConvention.ISO_REFERENCING,
    )
    assert texts_of(primitives) == [text]
    lines = lines_of(primitives)
    assert_close(lines[0].start, start, "start")
    assert_close(lines[0].end, RIM, "ends on the rim")
    barbs = lines[1:-2]
    arrows = 1 if measure is RadialMeasure.RADIUS else 2
    assert len(barbs) == 2 * arrows
    arrow_length = tokens.DIMENSION_ARROW_LENGTH_PIXELS * PIXEL
    for b in barbs[:2]:
        assert_close(b.start, RIM, "tip on the rim")
        # The base sits an arrowhead length back toward the center.
        back = dot(sub(b.end, RIM), _neg(_at(45)))
        assert back == pytest.approx(arrow_length, abs=TOLERANCE)
    for b in barbs[2:]:
        assert_close(b.start, _neg(RIM), "tip on the far rim")


def test_radial_lies_along_the_in_plane_part_of_the_app_direction() -> None:
    line = lines_of(
        _radial(50, direction=(0, -1, 5), drafting=DraftingConvention.ISO_REFERENCING)
    )[0]
    assert_close(line.end, scale(Y, -50), "rim")


def test_radial_falls_back_to_screen_right_when_up_right_is_the_normal() -> None:
    line = lines_of(
        _radial(
            50,
            normal=normalized((1, 1, 0)),
            drafting=DraftingConvention.ISO_REFERENCING,
        )
    )[0]
    assert_close(line.end, scale(normalized((1, -1, 0)), 50), "rim")


def test_an_inlined_radial_line_breaks_around_its_midpoint() -> None:
    primitives = _radial(50, drafting=DraftingConvention.ASME_INLINED)
    lines = lines_of(primitives)
    (label,) = billboards_of(primitives)
    middle = scale(RIM, 0.5)
    assert_close(label.anchor, middle, "text at the midpoint")
    content = label.content
    extent = (content.width_pixels + content.height_pixels) * math.sqrt(0.5)
    half_break = (extent / 2 + tokens.DIMENSION_TEXT_GAP_PIXELS) * PIXEL
    assert_close(lines[0].start, ORIGIN, "from the center")
    assert_close(lines[0].end, sub(middle, scale(_at(45), half_break)), "to the break")
    assert_close(lines[1].start, sub(middle, scale(_at(45), -half_break)), "past it")
    assert_close(lines[1].end, RIM, "to the rim")


def test_radial_oriented_text_lies_along_the_line() -> None:
    (label,) = billboards_of(_radial(50))
    assert isinstance(label.orientation, CoplanarOrientation)
    assert_close(label.orientation.right, _at(45), "reads along the line")


@pytest.mark.parametrize(
    "drafting", [DraftingConvention.ISO_ORIENTED, DraftingConvention.ASME_INLINED]
)
def test_radial_falls_back_to_referencing_on_a_small_circle(
    drafting: DraftingConvention,
) -> None:
    primitives = _radial(5, drafting=drafting)
    # Line, two barbs, two leader lines.
    assert len(lines_of(primitives)) == 5
    (label,) = billboards_of(primitives)
    assert isinstance(label.orientation, ViewerFacingOrientation)


@pytest.mark.parametrize(
    ("radius", "normal", "center"),
    [
        pytest.param(0.0, Z, ORIGIN, id="a zero radius"),
        pytest.param(math.nan, Z, ORIGIN, id="a radius that is not a number"),
        pytest.param(50.0, ORIGIN, ORIGIN, id="a zero normal"),
        pytest.param(50.0, Z, (0, 0, 2 * DEPTH), id="a center behind the camera"),
    ],
)
def test_radial_emits_nothing(radius: float, normal: Vector3, center: Vector3) -> None:
    assert _radial(radius, normal=normal, center=center) == []


def test_radial_carries_the_key_and_opacity() -> None:
    primitives = _radial(50, key="radius", opacity=0.3)
    assert primitives
    for p in primitives:
        assert p.key == "radius"
        assert p.opacity == 0.3
