"""Point-to-point dimensions behave as the Dart reference's tests pin."""

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
    CalloutQuadrant,
    CameraBasis,
    CoordinateConvention,
    CoplanarOrientation,
    DecimalMarker,
    DimensionStyle,
    DimensionTextPlacement,
    DisplayFormat,
    DraftingConvention,
    DraftingStandard,
    Handedness,
    LeaderLineStyle,
    MultiAxisDimension,
    NumberFormatting,
    Primitive,
    SpatialAxis,
    TextRequest,
    UnitSystem,
    Vector2,
    Vector3,
    ViewerFacingOrientation,
    callout_anchor_alignment,
    compute_callout_leader_geometry,
    create_dimension,
    tokens,
    world_units_per_pixel_at,
)
from tech_vis._vec import ORIGIN, dot, normalized, sub

Z_UP = CoordinateConvention(up=SpatialAxis.Z, handedness=Handedness.RIGHT)
FOV = math.pi / 3
VIEWPORT: Vector2 = (1000.0, 1000.0)

# A top view of the Z-up XY plane: screen right is +X and screen up is +Y,
# and every point on the plane sits at one depth, so pixel lengths on the
# plane measure exactly.
TOP_VIEW = CameraBasis.look_at(
    position=(50.0, 0.0, 400.0), target=(50.0, 0.0, 0.0), convention=Z_UP
)

DEFAULT_STYLE = DimensionStyle()
DEFAULT_NUMBERS = NumberFormatting()


def _dimension(
    start: Vector3,
    end: Vector3,
    *,
    drafting: DraftingConvention = DraftingConvention.ISO_ORIENTED,
    display_format: DisplayFormat = DisplayFormat.METRIC,
    world_units: UnitSystem = UnitSystem.METRIC,
    camera: CameraBasis = TOP_VIEW,
    multi_axis: MultiAxisDimension = MultiAxisDimension.COMPONENTS,
    offset_direction: Vector3 | None = None,
    numbers: NumberFormatting = DEFAULT_NUMBERS,
    style: DimensionStyle = DEFAULT_STYLE,
    key: object = None,
    opacity: float = 1.0,
) -> list[Primitive]:
    return create_dimension(
        start=start,
        end=end,
        drafting=drafting,
        display_format=display_format,
        world_units=world_units,
        camera=camera,
        vertical_fov_radians=FOV,
        viewport_size=VIEWPORT,
        resolve_text=fake_text_resolver,
        key=key,
        multi_axis=multi_axis,
        offset_direction=offset_direction,
        numbers=numbers,
        style=style,
        opacity=opacity,
    )


def _px(point: Vector3) -> Vector2:
    """Projects ``point`` through an independent pinhole camera, y up."""
    focal = (VIEWPORT[1] / 2) / math.tan(FOV / 2)
    relative = sub(point, TOP_VIEW.position)
    depth = dot(relative, TOP_VIEW.forward)
    return (
        dot(relative, TOP_VIEW.right) * focal / depth,
        dot(relative, TOP_VIEW.up) * focal / depth,
    )


def _px_length(a: Vector3, b: Vector3) -> float:
    (ax, ay), (bx, by) = _px(a), _px(b)
    return math.hypot(ax - bx, ay - by)


def _midpoint(a: Vector3, b: Vector3) -> Vector3:
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)


def _pixel_at_plane() -> float:
    pixel = world_units_per_pixel_at(ORIGIN, TOP_VIEW, FOV, VIEWPORT[1])
    assert pixel is not None
    return pixel


@pytest.mark.parametrize(
    ("drafting", "standard", "placement"),
    [
        (
            DraftingConvention.ISO_ORIENTED,
            DraftingStandard.ISO,
            DimensionTextPlacement.ORIENTED,
        ),
        (
            DraftingConvention.ISO_REFERENCING,
            DraftingStandard.ISO,
            DimensionTextPlacement.REFERENCING,
        ),
        (
            DraftingConvention.ASME_INLINED,
            DraftingStandard.ASME,
            DimensionTextPlacement.INLINED,
        ),
        (
            DraftingConvention.ASME_REFERENCING,
            DraftingStandard.ASME,
            DimensionTextPlacement.REFERENCING,
        ),
    ],
)
def test_drafting_convention(
    drafting: DraftingConvention,
    standard: DraftingStandard,
    placement: DimensionTextPlacement,
) -> None:
    assert drafting.standard is standard
    assert drafting.placement is placement


def test_style_defaults_come_from_the_style_tokens() -> None:
    style = DimensionStyle()
    assert style.line_width == tokens.DIMENSION_LINE_WIDTH
    assert style.witness_extension_pixels == tokens.DIMENSION_WITNESS_EXTENSION_PIXELS
    assert style.offset_pixels == tokens.DIMENSION_OFFSET_PIXELS
    assert style.arrow_length_pixels == tokens.DIMENSION_ARROW_LENGTH_PIXELS
    assert style.arrow_width_pixels == tokens.DIMENSION_ARROW_WIDTH_PIXELS
    assert style.text_pixel_size == tokens.DIMENSION_TEXT_PIXEL_SIZE
    assert style.text_gap_pixels == tokens.DIMENSION_TEXT_GAP_PIXELS
    assert style.alignment_tolerance == tokens.DIMENSION_ALIGNMENT_TOLERANCE
    assert style.leader == LeaderLineStyle()
    assert style.arc_radius_pixels == tokens.DIMENSION_ARC_RADIUS_PIXELS
    assert style.arc_segment_pixels == tokens.DIMENSION_ARC_SEGMENT_PIXELS
    assert style.angle_resolution_degrees == tokens.DIMENSION_ANGLE_RESOLUTION_DEGREES


@pytest.mark.parametrize(
    ("style", "standard", "gap"),
    [
        (DimensionStyle(), DraftingStandard.ISO, 2.0),
        (DimensionStyle(), DraftingStandard.ASME, 4.0),
        (DimensionStyle(witness_gap_pixels=7), DraftingStandard.ISO, 7.0),
        (DimensionStyle(witness_gap_pixels=7), DraftingStandard.ASME, 7.0),
    ],
)
def test_witness_gap_for(
    style: DimensionStyle, standard: DraftingStandard, gap: float
) -> None:
    assert style.witness_gap_for(standard) == gap


def test_the_per_standard_gaps_are_the_tokens() -> None:
    style = DimensionStyle()
    gap_iso = style.witness_gap_for(DraftingStandard.ISO)
    gap_asme = style.witness_gap_for(DraftingStandard.ASME)
    assert gap_iso == tokens.DIMENSION_WITNESS_GAP_ISO_PIXELS
    assert gap_asme == tokens.DIMENSION_WITNESS_GAP_ASME_PIXELS


COMPONENTS = MultiAxisDimension.COMPONENTS
DIRECT = MultiAxisDimension.DIRECT


@pytest.mark.parametrize(
    ("end", "multi_axis", "style", "texts"),
    [
        pytest.param((100, 0, 0), COMPONENTS, DEFAULT_STYLE, ["100 mm"], id="one"),
        pytest.param((0, -30, 0), DIRECT, DEFAULT_STYLE, ["30 mm"], id="negative"),
        pytest.param(
            (100, 0.05, 0), DIRECT, DEFAULT_STYLE, ["100 mm"], id="noise in tolerance"
        ),
        pytest.param(
            (100, 0.2, 0),
            COMPONENTS,
            DEFAULT_STYLE,
            ["100 mm", "0.2 mm"],
            id="offset past the tolerance",
        ),
        pytest.param(
            (100, 0.2, 0),
            COMPONENTS,
            DimensionStyle(alignment_tolerance=0.01),
            ["100 mm"],
            id="a wider tolerance",
        ),
        pytest.param(
            (30, 40, 0), COMPONENTS, DEFAULT_STYLE, ["30 mm", "40 mm"], id="2 parts"
        ),
        pytest.param((30, 40, 0), DIRECT, DEFAULT_STYLE, ["50 mm"], id="2 direct"),
        pytest.param(
            (-3, 4, -12),
            COMPONENTS,
            DEFAULT_STYLE,
            ["3 mm", "4 mm", "12 mm"],
            id="3 parts in X, Y, Z order",
        ),
        pytest.param((-3, 4, -12), DIRECT, DEFAULT_STYLE, ["13 mm"], id="3 direct"),
    ],
)
def test_what_a_dimension_measures(
    end: Vector3,
    multi_axis: MultiAxisDimension,
    style: DimensionStyle,
    texts: list[str],
) -> None:
    primitives = _dimension(
        ORIGIN,
        end,
        multi_axis=multi_axis,
        style=style,
        drafting=DraftingConvention.ISO_REFERENCING,
    )
    assert texts_of(primitives) == texts


def test_component_labels_form_one_set_and_share_a_unit() -> None:
    primitives = _dimension(
        ORIGIN, (12000, 500, 0), drafting=DraftingConvention.ISO_REFERENCING
    )
    assert texts_of(primitives) == ["12 m", "0.5 m"]


def test_coincident_points_have_no_dimension() -> None:
    assert _dimension((1, 2, 3), (1, 2, 3)) == []


def test_a_point_behind_the_camera_hides_the_dimension() -> None:
    assert _dimension(ORIGIN, (0, 0, 500)) == []


@pytest.mark.parametrize(
    ("world_units", "display_format", "length", "numbers", "text"),
    [
        pytest.param(
            UnitSystem.IMPERIAL,
            DisplayFormat.METRIC,
            1.0,
            DEFAULT_NUMBERS,
            "25.4 mm",
            id="inches in a metric format",
        ),
        pytest.param(
            UnitSystem.METRIC,
            DisplayFormat.METRIC,
            12500.0,
            DEFAULT_NUMBERS,
            "12.5 m",
            id="metric promotes to meters",
        ),
        pytest.param(
            UnitSystem.METRIC,
            DisplayFormat.FRACTIONAL_INCH,
            1028.7,
            DEFAULT_NUMBERS,
            "3' 4 1/2\"",
            id="millimeters in fractional inch",
        ),
        pytest.param(
            UnitSystem.IMPERIAL,
            DisplayFormat.DECIMAL_INCH,
            0.125,
            NumberFormatting(
                decimal_marker=DecimalMarker.COMMA, show_leading_zero=False
            ),
            ",125 in",
            id="decimal inch, comma, no leading zero",
        ),
    ],
)
def test_labels(
    world_units: UnitSystem,
    display_format: DisplayFormat,
    length: float,
    numbers: NumberFormatting,
    text: str,
) -> None:
    primitives = _dimension(
        ORIGIN,
        (length, 0, 0),
        world_units=world_units,
        display_format=display_format,
        numbers=numbers,
    )
    assert texts_of(primitives) == [text]
    (label,) = billboards_of(primitives)
    assert isinstance(label.content.value, TextRequest)
    assert label.content.value.height_pixels == tokens.DIMENSION_TEXT_PIXEL_SIZE


@pytest.mark.parametrize(
    ("end", "axis"),
    [
        pytest.param((100, 0, 0), (1, 0, 0), id="X"),
        pytest.param((0, 80, 0), (0, 1, 0), id="Y"),
        pytest.param((0, 0, -60), (0, 0, 1), id="Z"),
        pytest.param((100, 30, 0), (1, 0, 0), id="X with a Y offset"),
    ],
)
def test_witness_lines_are_perpendicular_to_the_measured_axis(
    end: Vector3, axis: Vector3
) -> None:
    oblique = CameraBasis.look_at(
        position=(300, -250, 200), target=(20, 10, -10), convention=Z_UP
    )
    witness_start, witness_end, *_ = lines_of(_dimension(ORIGIN, end, camera=oblique))
    for w in (witness_start, witness_end):
        assert dot(normalized(sub(w.end, w.start)), axis) == pytest.approx(
            0, abs=TOLERANCE
        )


@pytest.mark.parametrize(
    ("drafting", "gap"),
    [
        (DraftingConvention.ISO_ORIENTED, tokens.DIMENSION_WITNESS_GAP_ISO_PIXELS),
        (DraftingConvention.ASME_INLINED, tokens.DIMENSION_WITNESS_GAP_ASME_PIXELS),
    ],
)
def test_witness_lines_leave_the_standard_gap_and_overshoot(
    drafting: DraftingConvention, gap: float
) -> None:
    start, end = ORIGIN, (100.0, 0.0, 0.0)
    witness_start, witness_end, *_ = lines_of(_dimension(start, end, drafting=drafting))
    assert _px_length(start, witness_start.start) == pytest.approx(gap, abs=TOLERANCE)
    assert _px_length(end, witness_end.start) == pytest.approx(gap, abs=TOLERANCE)
    overshoot = (
        tokens.DIMENSION_OFFSET_PIXELS + tokens.DIMENSION_WITNESS_EXTENSION_PIXELS
    )
    assert _px_length(start, witness_start.end) == pytest.approx(
        overshoot, abs=TOLERANCE
    )


@pytest.mark.parametrize(
    ("offset_direction", "expected"),
    [
        pytest.param((0.5, -1, 0), (0, -1, 0), id="the app's offset direction"),
        pytest.param(None, (0, 1, 0), id="screen up by default"),
    ],
)
def test_witness_line_direction(
    offset_direction: Vector3 | None, expected: Vector3
) -> None:
    witness, *_ = lines_of(
        _dimension(ORIGIN, (100, 0, 0), offset_direction=offset_direction)
    )
    assert_close(normalized(sub(witness.end, witness.start)), expected, "witness")


def test_arrowheads_sit_inside_the_witness_lines_at_their_pixel_size() -> None:
    lines = lines_of(_dimension(ORIGIN, (100, 0, 0)))
    dimension_line = lines[2]
    arrows = lines[3:7]
    for i, tip in enumerate((dimension_line.start, dimension_line.end)):
        a, b = arrows[2 * i : 2 * i + 2]
        assert_close(a.start, tip, f"arrow {i} tip")
        assert_close(b.start, tip, f"arrow {i} tip")
        base = _midpoint(a.end, b.end)
        assert _px_length(tip, base) == pytest.approx(
            tokens.DIMENSION_ARROW_LENGTH_PIXELS, abs=TOLERANCE
        )
        assert _px_length(a.end, b.end) == pytest.approx(
            tokens.DIMENSION_ARROW_WIDTH_PIXELS, abs=TOLERANCE
        )
        # The base lies between the tips, toward the other end.
        inward = 1.0 if i == 0 else -1.0
        assert (base[0] - tip[0]) * inward > 0
    for line in lines:
        assert line.width_pixels == tokens.DIMENSION_LINE_WIDTH


LONG: Vector3 = (100.0, 0.0, 0.0)
SHORT: Vector3 = (10.0, 0.0, 0.0)


def test_iso_oriented_text_sits_above_the_line_parallel_and_upright() -> None:
    primitives = _dimension(ORIGIN, LONG)
    (label,) = billboards_of(primitives)
    orientation = label.orientation
    assert isinstance(orientation, CoplanarOrientation)
    assert_close(orientation.normal, TOP_VIEW.to_viewer, "normal")
    assert_close(orientation.right, (1, 0, 0), "right")
    assert label.alignment == (0.5, 0.0)
    assert label.offset is not None
    assert label.offset.pixels == tokens.DIMENSION_TEXT_GAP_PIXELS
    assert_close(label.offset.direction, (0, 1, 0), "up")
    # The text lifts off the line along its own vertical axis.
    text_up = Z_UP.cross(orientation.normal, orientation.right)
    assert_close(text_up, label.offset.direction, "text up")
    assert len(lines_of(primitives)) == 7


@pytest.mark.parametrize(
    ("end", "right"),
    [
        pytest.param((-100, 0, 0), (1, 0, 0), id="right to left"),
        pytest.param((0, -100, 0), (0, 1, 0), id="vertical"),
    ],
)
def test_iso_oriented_text_stays_upright(end: Vector3, right: Vector3) -> None:
    (label,) = billboards_of(_dimension(ORIGIN, end))
    assert isinstance(label.orientation, CoplanarOrientation)
    assert_close(label.orientation.right, right, "right")


def test_asme_inlined_breaks_the_line_around_horizontal_text() -> None:
    primitives = _dimension(ORIGIN, LONG, drafting=DraftingConvention.ASME_INLINED)
    (label,) = billboards_of(primitives)
    assert isinstance(label.orientation, ViewerFacingOrientation)
    assert label.alignment == (0.5, 0.5)
    assert label.offset is None
    lines = lines_of(primitives)
    assert len(lines) == 8
    first, second = lines[2], lines[3]
    assert_close(label.anchor, _midpoint(first.start, second.end), "center")
    expected = label.content.width_pixels + 2 * tokens.DIMENSION_TEXT_GAP_PIXELS
    assert _px_length(first.end, second.start) == pytest.approx(expected, abs=TOLERANCE)


@pytest.mark.parametrize(
    "drafting",
    [DraftingConvention.ISO_REFERENCING, DraftingConvention.ASME_REFERENCING],
)
def test_referencing_leads_the_text_off_the_line(
    drafting: DraftingConvention,
) -> None:
    primitives = _dimension(ORIGIN, LONG, drafting=drafting)
    lines = lines_of(primitives)
    assert len(lines) == 9
    (label,) = billboards_of(primitives)
    assert isinstance(label.orientation, ViewerFacingOrientation)
    dimension_line, leader = lines[2], lines[7]
    expected = compute_callout_leader_geometry(
        anchor=_midpoint(dimension_line.start, dimension_line.end),
        camera_right=TOP_VIEW.right,
        camera_up=TOP_VIEW.up,
        world_units_per_pixel=_pixel_at_plane(),
        quadrant=CalloutQuadrant.TOP_RIGHT,
    )
    assert_close(leader.start, expected.gap_end, "leader start")
    assert label.alignment == (0.0, 0.5)


@pytest.mark.parametrize(
    "drafting", [DraftingConvention.ISO_ORIENTED, DraftingConvention.ASME_INLINED]
)
def test_falls_back_to_referencing_when_cramped(drafting: DraftingConvention) -> None:
    primitives = _dimension(ORIGIN, SHORT, drafting=drafting)
    assert len(lines_of(primitives)) == 9
    (label,) = billboards_of(primitives)
    assert isinstance(label.orientation, ViewerFacingOrientation)


@pytest.mark.parametrize(
    ("end", "offset", "quadrant"),
    [
        pytest.param((100, 0, 0), None, CalloutQuadrant.TOP_RIGHT, id="outer side up"),
        pytest.param(
            (100, 0, 0), (0, -1, 0), CalloutQuadrant.BOTTOM_RIGHT, id="outer side down"
        ),
        pytest.param(
            (100 * math.cos(math.pi / 6), 100 * math.sin(math.pi / 6), 0),
            None,
            CalloutQuadrant.TOP_LEFT,
            id="line at the leader angle",
        ),
    ],
)
def test_a_referencing_leader_avoids_the_line(
    end: Vector3, offset: Vector3 | None, quadrant: CalloutQuadrant
) -> None:
    primitives = _dimension(
        ORIGIN,
        end,
        drafting=DraftingConvention.ISO_REFERENCING,
        multi_axis=DIRECT,
        offset_direction=offset,
    )
    (label,) = billboards_of(primitives)
    assert label.alignment == callout_anchor_alignment(quadrant)
    lines = lines_of(primitives)
    dimension_line, angled = lines[2], lines[7]
    expected = compute_callout_leader_geometry(
        anchor=_midpoint(dimension_line.start, dimension_line.end),
        camera_right=TOP_VIEW.right,
        camera_up=TOP_VIEW.up,
        world_units_per_pixel=_pixel_at_plane(),
        quadrant=quadrant,
    )
    assert_close(angled.end, expected.elbow, "elbow")


def test_every_primitive_carries_the_key_and_opacity() -> None:
    primitives = _dimension(
        ORIGIN,
        (30, 40, 5),
        drafting=DraftingConvention.ASME_REFERENCING,
        key="dimension",
        opacity=0.4,
    )
    assert primitives
    for p in primitives:
        assert p.key == "dimension"
        assert p.opacity == 0.4
