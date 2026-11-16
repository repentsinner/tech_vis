"""Leader-line behavior the golden vectors leave implicit."""

import math

from conftest import assert_close
from tech_vis import (
    BillboardContent,
    CalloutQuadrant,
    LeaderLineStyle,
    ViewerFacingOrientation,
    callout_leader_direction,
    compute_callout_leader_geometry,
    create_callout_label,
    create_callout_leader_lines,
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


class TestCallouts:
    def test_leader_carries_its_style_width(self):
        leader = compute_callout_leader_geometry(
            anchor=(0, 0, 0),
            camera_right=(1, 0, 0),
            camera_up=(0, 1, 0),
            world_units_per_pixel=1,
            quadrant=CalloutQuadrant.TOP_RIGHT,
            style=LeaderLineStyle(line_width=2.5),
        )
        assert leader.width_pixels == 2.5

    def test_leader_direction_heads_into_the_quadrant(self):
        style = LeaderLineStyle(angle_degrees=30)
        x, y = callout_leader_direction(CalloutQuadrant.BOTTOM_LEFT, style=style)
        assert_close((x, y), (-math.cos(math.pi / 6), -0.5))

    def test_emits_the_angled_then_the_horizontal_segment(self):
        leader = compute_callout_leader_geometry(
            anchor=(0, 0, 0),
            camera_right=(1, 0, 0),
            camera_up=(0, 1, 0),
            world_units_per_pixel=1,
            quadrant=CalloutQuadrant.TOP_LEFT,
        )
        angled, horizontal = create_callout_leader_lines(leader, key="c", opacity=0.5)
        assert (angled.start, angled.end) == (leader.gap_end, leader.elbow)
        assert (horizontal.start, horizontal.end) == (leader.elbow, leader.label_edge)
        for line in (angled, horizontal):
            assert line.width_pixels == tokens.CALLOUT_LEADER_LINE_WIDTH
            assert (line.key, line.opacity) == ("c", 0.5)

    def test_hangs_the_label_from_the_leader_end(self):
        leader = compute_callout_leader_geometry(
            anchor=(0, 0, 0),
            camera_right=(1, 0, 0),
            camera_up=(0, 1, 0),
            world_units_per_pixel=1,
            quadrant=CalloutQuadrant.TOP_LEFT,
        )
        content = BillboardContent(value="Note", width_pixels=28, height_pixels=14)
        label = create_callout_label(
            leader, CalloutQuadrant.TOP_LEFT, content=content, key="n", opacity=0.75
        )
        assert label.anchor == leader.label_edge
        assert label.alignment == (1.0, 0.5)
        assert label.content is content
        assert (label.key, label.opacity) == ("n", 0.75)
        assert label.orientation == ViewerFacingOrientation()
