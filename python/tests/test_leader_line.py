"""Leader-line behavior the golden vectors leave implicit."""

from tech_vis import (
    CalloutQuadrant,
    LeaderLineStyle,
    compute_callout_leader_geometry,
    tokens,
)


def test_default_style_comes_from_the_style_tokens():
    assert LeaderLineStyle() == LeaderLineStyle(
        line_width=tokens.CALLOUT_LEADER_LINE_WIDTH,
        gap_pixels=tokens.CALLOUT_GAP_PIXELS,
        angled_length_pixels=tokens.CALLOUT_ANGLED_LENGTH_PIXELS,
        horizontal_length_pixels=tokens.CALLOUT_HORIZONTAL_LENGTH_PIXELS,
        angle_degrees=tokens.CALLOUT_ANGLE_DEGREES,
    )


def test_quadrant_values_are_the_fixture_names():
    assert [q.value for q in CalloutQuadrant] == [
        "topRight",
        "topLeft",
        "bottomRight",
        "bottomLeft",
    ]


def test_geometry_points_are_plain_tuples():
    result = compute_callout_leader_geometry(
        anchor=(0.0, 0.0, 0.0),
        camera_right=(1.0, 0.0, 0.0),
        camera_up=(0.0, 1.0, 0.0),
        world_units_per_pixel=1.0,
        quadrant=CalloutQuadrant.TOP_RIGHT,
    )
    for point in (result.gap_end, result.elbow, result.label_edge):
        assert type(point) is tuple
        assert len(point) == 3
