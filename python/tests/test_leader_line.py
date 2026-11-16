"""Leader-line behavior the golden vectors leave implicit."""

from tech_vis import (
    CalloutQuadrant,
    LeaderLineStyle,
    compute_callout_leader_geometry,
    tokens,
)


def test_default_style_comes_from_the_style_tokens():
    assert LeaderLineStyle().gap_pixels == tokens.CALLOUT_GAP_PIXELS


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
