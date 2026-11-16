"""Smart dimensions (§spec:smart-dimensions), ported from the Dart reference.

A dimension measures between points the app supplies: a length between two
points, an angle between two legs, or the radius or diameter of a circle. It
is sized in screen pixels, so the app rebuilds it each frame the camera
moves. Its look follows a drafting convention (§spec:drafting-convention).
Every function here agrees with ``vectors/smart_dimensions.json``.
"""

import math
from dataclasses import dataclass
from enum import StrEnum

from tech_vis import _vec, tokens
from tech_vis._vec import Vector2, Vector3
from tech_vis.coordinate_convention import SpatialAxis
from tech_vis.leader_line import (
    CalloutQuadrant,
    LeaderLineStyle,
    callout_leader_direction,
    compute_callout_leader_geometry,
    create_callout_label,
    create_callout_leader_lines,
)
from tech_vis.primitives import (
    BillboardContent,
    BillboardPrimitive,
    CoplanarOrientation,
    LinePrimitive,
    Primitive,
    ScreenOffset,
    TextRequest,
    TextResolver,
)
from tech_vis.screen_space import (
    CameraBasis,
    world_to_screen,
    world_units_per_pixel_at,
)
from tech_vis.unit_system import (
    DisplayFormat,
    NumberFormatting,
    UnitSystem,
    format_degrees_label,
)

# Below this length, a vector counts as zero.
_EPSILON = 1e-9

# Alignment of oriented text: the middle of its bottom edge on the anchor.
_BOTTOM_CENTER: Vector2 = (0.5, 0.0)


class DraftingStandard(StrEnum):
    """Names a drafting standard: the rules a dimension's look follows."""

    ISO = "iso"
    """ISO 129."""

    ASME = "asme"
    """ASME Y14.5."""


class DimensionTextPlacement(StrEnum):
    """Names where a dimension's text sits relative to its dimension line."""

    ORIENTED = "oriented"
    """Parallel to the dimension line, above it, turned to stay upright."""

    INLINED = "inlined"
    """Horizontal, in a break in the dimension line."""

    REFERENCING = "referencing"
    """Horizontal, on a reference line led off the dimension line."""


class DraftingConvention(StrEnum):
    """Names a drafting standard and a style within it.

    Together they decide where a dimension's text sits and which way it
    reads. The app selects one for a scene. It is independent of the display
    format and of number formatting, so a metric scene may follow ASME. Each
    value is the convention's name in the golden vectors and in the Dart
    package, so ``DraftingConvention("asmeInlined")`` parses a fixture entry.
    """

    ISO_ORIENTED = "isoOriented"
    """ISO, with text parallel to the dimension line, above it, turned to stay
    upright."""

    ISO_REFERENCING = "isoReferencing"
    """ISO, with horizontal text on a reference line led off the dimension
    line."""

    ASME_INLINED = "asmeInlined"
    """ASME, with horizontal text in a break in the dimension line."""

    ASME_REFERENCING = "asmeReferencing"
    """ASME, with horizontal text on a reference line led off the dimension
    line."""

    @property
    def standard(self) -> DraftingStandard:
        """Returns the standard this convention belongs to."""
        return _CONVENTIONS[self][0]

    @property
    def placement(self) -> DimensionTextPlacement:
        """Returns where this convention puts a dimension's text.

        Oriented and inlined text that does not fit between its witness lines
        on screen falls back to referencing, under the same standard.
        """
        return _CONVENTIONS[self][1]


_CONVENTIONS: dict[
    DraftingConvention, tuple[DraftingStandard, DimensionTextPlacement]
] = {
    DraftingConvention.ISO_ORIENTED: (
        DraftingStandard.ISO,
        DimensionTextPlacement.ORIENTED,
    ),
    DraftingConvention.ISO_REFERENCING: (
        DraftingStandard.ISO,
        DimensionTextPlacement.REFERENCING,
    ),
    DraftingConvention.ASME_INLINED: (
        DraftingStandard.ASME,
        DimensionTextPlacement.INLINED,
    ),
    DraftingConvention.ASME_REFERENCING: (
        DraftingStandard.ASME,
        DimensionTextPlacement.REFERENCING,
    ),
}


class RadialMeasure(StrEnum):
    """Names what a radial dimension measures."""

    RADIUS = "radius"
    """The radius, from the center to the rim, written after ``R``."""

    DIAMETER = "diameter"
    """The diameter, from rim to rim through the center, written after
    ``⌀``."""


class MultiAxisDimension(StrEnum):
    """Names what a dimension between points that differ along more than one
    axis measures."""

    COMPONENTS = "components"
    """One dimension per axis along which the points differ."""

    DIRECT = "direct"
    """One dimension of the straight-line distance, its dimension line
    parallel to the segment between the points."""


@dataclass(frozen=True, slots=True, kw_only=True)
class DimensionStyle:
    """Holds the pixel sizes and the alignment tolerance of a dimension.

    Every default is a style token.
    """

    line_width: float = tokens.DIMENSION_LINE_WIDTH
    """Width of witness, dimension, and arrowhead lines in screen pixels."""

    witness_gap_pixels: float | None = None
    """Gap between a measured point and the start of its witness line, or
    None for the standard's token."""

    witness_extension_pixels: float = tokens.DIMENSION_WITNESS_EXTENSION_PIXELS
    """Length a witness line runs past the dimension line."""

    offset_pixels: float = tokens.DIMENSION_OFFSET_PIXELS
    """Distance from the measured points to the dimension line."""

    arrow_length_pixels: float = tokens.DIMENSION_ARROW_LENGTH_PIXELS
    """Length of an arrowhead along the dimension line."""

    arrow_width_pixels: float = tokens.DIMENSION_ARROW_WIDTH_PIXELS
    """Width of an arrowhead across its barbs."""

    text_pixel_size: float = tokens.DIMENSION_TEXT_PIXEL_SIZE
    """Pixel height of the value text."""

    text_gap_pixels: float = tokens.DIMENSION_TEXT_GAP_PIXELS
    """Gap between the text and the dimension line."""

    alignment_tolerance: float = tokens.DIMENSION_ALIGNMENT_TOLERANCE
    """Largest offset along any other axis, as a fraction of the distance
    between the points, at which a dimension still measures one axis."""

    leader: LeaderLineStyle = LeaderLineStyle()
    """Leader of a referencing dimension, the same as a callout's."""

    arc_radius_pixels: float = tokens.DIMENSION_ARC_RADIUS_PIXELS
    """Radius of an angular dimension's arc, from its vertex."""

    arc_segment_pixels: float = tokens.DIMENSION_ARC_SEGMENT_PIXELS
    """Longest segment of an angular dimension's arc, along the arc at the
    vertex's depth."""

    angle_resolution_degrees: float = tokens.DIMENSION_ANGLE_RESOLUTION_DEGREES
    """Step an angular dimension's value rounds to, in degrees."""

    def witness_gap_for(self, standard: DraftingStandard) -> float:
        """Returns the witness line gap under ``standard``:
        ``witness_gap_pixels`` when set, else the standard's token."""
        if self.witness_gap_pixels is not None:
            return self.witness_gap_pixels
        if standard is DraftingStandard.ISO:
            return tokens.DIMENSION_WITNESS_GAP_ISO_PIXELS
        return tokens.DIMENSION_WITNESS_GAP_ASME_PIXELS


# Default arguments are built once; both are frozen, so sharing them is safe.
_DEFAULT_STYLE = DimensionStyle()
_DEFAULT_NUMBERS = NumberFormatting()


def create_dimension(
    *,
    start: Vector3,
    end: Vector3,
    drafting: DraftingConvention,
    display_format: DisplayFormat,
    world_units: UnitSystem,
    camera: CameraBasis,
    vertical_fov_radians: float,
    viewport_size: Vector2,
    resolve_text: TextResolver,
    key: object,
    multi_axis: MultiAxisDimension = MultiAxisDimension.COMPONENTS,
    offset_direction: Vector3 | None = None,
    numbers: NumberFormatting = _DEFAULT_NUMBERS,
    style: DimensionStyle = _DEFAULT_STYLE,
    opacity: float = 1.0,
) -> list[Primitive]:
    """Returns the primitives of a dimension from ``start`` to ``end``.

    The dimension is seen by ``camera`` with vertical field of view
    ``vertical_fov_radians`` in a ``viewport_size`` viewport. When the points
    differ along one world axis only, within ``style.alignment_tolerance``,
    the dimension measures that axis. Otherwise ``multi_axis`` decides between
    one dimension per varying axis, in X, Y, Z order, and one of the direct
    distance.

    Each dimension emits, in order: the witness lines from ``start`` and from
    ``end``, perpendicular to the measured direction; the dimension line, as
    two segments when inlined text breaks it; two lines per arrowhead, at the
    ``start`` end and then the ``end`` end; the two leader lines of a
    referencing dimension; and the text billboard.

    The dimension line sits ``style.offset_pixels`` from the points along
    ``offset_direction``, less its component along the measured direction.
    Without one, it sits toward screen up, along the perpendicular that faces
    the viewer.

    The text is the measured length, converted from ``world_units`` and
    written by ``display_format`` with ``numbers``, and ``resolve_text``
    answers its request. ``drafting`` places it. An oriented or inlined
    dimension whose text and arrowheads do not fit between its witness lines
    on screen falls back to its standard's referencing style.

    Returns an empty list for coincident points, or when a point the
    dimension needs lies on or behind the camera plane.
    """
    delta = _vec.sub(end, start)
    distance = _vec.length(delta)
    if distance <= _EPSILON:
        return []

    varying = [
        _vec.scale(axis.unit_vector, math.copysign(1.0, component))
        for axis, component in zip(SpatialAxis, delta, strict=True)
        if abs(component) > style.alignment_tolerance * distance
    ]
    directions = (
        varying
        if len(varying) == 1
        or (varying and multi_axis is MultiAxisDimension.COMPONENTS)
        else [_vec.scale(delta, 1.0 / distance)]
    )

    # The dimensions of one call show together, so their labels form one set
    # and share a unit.
    target_system = display_format.unit_system
    labels = display_format.format_labels(
        [
            world_units.convert_to(_vec.dot(delta, direction), target_system)
            for direction in directions
        ],
        numbers=numbers,
    )

    builder = _DimensionBuilder(
        camera=camera,
        vertical_fov_radians=vertical_fov_radians,
        viewport_size=viewport_size,
        drafting=drafting,
        style=style,
        resolve_text=resolve_text,
        key=key,
        opacity=opacity,
    )
    primitives: list[Primitive] = []
    for direction, label in zip(directions, labels, strict=True):
        dimension = builder.linear(start, end, direction, offset_direction, label)
        if dimension is None:
            return []
        primitives.extend(dimension)
    return primitives


def create_angular_dimension(
    *,
    vertex: Vector3,
    first: Vector3,
    second: Vector3,
    drafting: DraftingConvention,
    camera: CameraBasis,
    vertical_fov_radians: float,
    viewport_size: Vector2,
    resolve_text: TextResolver,
    key: object,
    numbers: NumberFormatting = _DEFAULT_NUMBERS,
    style: DimensionStyle = _DEFAULT_STYLE,
    opacity: float = 1.0,
) -> list[Primitive]:
    """Returns the primitives of the angle at ``vertex`` between two legs.

    The legs ``first`` and ``second`` are vectors from ``vertex`` to the far
    end of each, seen by ``camera`` with vertical field of view
    ``vertical_fov_radians`` in a ``viewport_size`` viewport.

    The dimension line is an arc in the legs' plane, centered on ``vertex``,
    ``style.arc_radius_pixels`` from it, from ``first`` to ``second`` the
    short way round. It draws as straight lines no longer than
    ``style.arc_segment_pixels`` along the arc.

    The dimension emits, in order: a witness line along each leg that ends
    short of the arc, extending it past the arc; the arc's lines, in two runs
    when inlined text breaks it; two lines per arrowhead, at the ``first`` end
    and then the ``second`` end; the two leader lines of a referencing
    dimension; and the text billboard.

    The text is the angle in decimal degrees, rounded to
    ``style.angle_resolution_degrees`` and written with ``numbers``, and
    ``resolve_text`` answers its request. ``drafting`` places it at the arc's
    midpoint, along the arc's tangent there, and falls back to referencing
    when it does not fit along the arc on screen.

    Returns an empty list when a leg is zero, when the legs are parallel or
    opposed, or when a point the dimension needs lies on or behind the camera
    plane.
    """
    first_length = _vec.length(first)
    second_length = _vec.length(second)
    if first_length <= _EPSILON or second_length <= _EPSILON:
        return []
    along = _vec.scale(first, 1.0 / first_length)
    toward = _vec.scale(second, 1.0 / second_length)
    sine = _vec.length(_vec.cross(along, toward))
    # Parallel legs span no angle, and opposed legs span no plane.
    if sine <= _EPSILON:
        return []
    cosine = _vec.dot(along, toward)
    angle = math.atan2(sine, cosine)
    across = _vec.normalized(_vec.sub(toward, _vec.scale(along, cosine)))

    builder = _DimensionBuilder(
        camera=camera,
        vertical_fov_radians=vertical_fov_radians,
        viewport_size=viewport_size,
        drafting=drafting,
        style=style,
        resolve_text=resolve_text,
        key=key,
        opacity=opacity,
    )
    # Degrees as Dart computes them, so a value on a rounding boundary rounds
    # the same way.
    label = format_degrees_label(
        angle * 180 / math.pi, step=style.angle_resolution_degrees, numbers=numbers
    )
    return (
        builder.angular(
            vertex, along, across, angle, first_length, second_length, label
        )
        or []
    )


def create_radial_dimension(
    *,
    center: Vector3,
    radius: float,
    normal: Vector3,
    measure: RadialMeasure,
    drafting: DraftingConvention,
    display_format: DisplayFormat,
    world_units: UnitSystem,
    camera: CameraBasis,
    vertical_fov_radians: float,
    viewport_size: Vector2,
    resolve_text: TextResolver,
    key: object,
    direction: Vector3 | None = None,
    numbers: NumberFormatting = _DEFAULT_NUMBERS,
    style: DimensionStyle = _DEFAULT_STYLE,
    opacity: float = 1.0,
) -> list[Primitive]:
    """Returns the primitives of a radial dimension of a circle or arc.

    The circle is centered on ``center`` with ``radius``, in the plane through
    ``center`` perpendicular to ``normal``, seen by ``camera`` with vertical
    field of view ``vertical_fov_radians`` in a ``viewport_size`` viewport.

    The dimension line lies in the plane along ``direction``, less its
    component along ``normal``. Without one, it runs toward the screen's
    top-right corner, or toward screen right when that corner lies along
    ``normal``. For an arc, give a ``direction`` that points into the arc.
    ``measure`` decides whether the line runs from ``center`` to the rim, or
    across the circle through ``center`` from rim to rim.

    The dimension emits, in order: the dimension line, as two segments when
    inlined text breaks it; two lines per arrowhead, at the rim along
    ``direction`` and then, for a diameter, at the opposite rim; the two
    leader lines of a referencing dimension; and the text billboard.

    The text is ``R`` before a radius and ``⌀`` before a diameter, then the
    length converted from ``world_units`` and written by ``display_format``
    with ``numbers``. ``resolve_text`` answers its request, and ``drafting``
    places it at the dimension line's midpoint, falling back to referencing
    as a linear dimension does.

    Returns an empty list for a radius that is not positive, a zero
    ``normal``, or when a point the dimension needs lies on or behind the
    camera plane.
    """
    if not radius > _EPSILON or _vec.length(normal) <= _EPSILON:
        return []
    axis = _vec.normalized(normal)

    def in_plane(v: Vector3 | None) -> Vector3 | None:
        if v is None:
            return None
        projected = _vec.sub(v, _vec.scale(axis, _vec.dot(v, axis)))
        return _vec.normalized(projected) if _vec.length(projected) > _EPSILON else None

    # Screen right projects to zero only along the normal, and then the
    # top-right corner does not.
    along = (
        in_plane(direction)
        or in_plane(_vec.add(camera.right, camera.up))
        or in_plane(camera.right)
    )
    assert along is not None
    diameter = measure is RadialMeasure.DIAMETER
    length = 2 * radius if diameter else radius
    (value,) = display_format.format_labels(
        [world_units.convert_to(length, display_format.unit_system)], numbers=numbers
    )

    builder = _DimensionBuilder(
        camera=camera,
        vertical_fov_radians=vertical_fov_radians,
        viewport_size=viewport_size,
        drafting=drafting,
        style=style,
        resolve_text=resolve_text,
        key=key,
        opacity=opacity,
    )
    return (
        builder.radial(
            _vec.along(center, along, -radius) if diameter else center,
            _vec.along(center, along, radius),
            along,
            diameter=diameter,
            label=f"{'⌀' if diameter else 'R'}{value}",
        )
        or []
    )


def _length2(v: Vector2) -> float:
    return math.sqrt(v[0] * v[0] + v[1] * v[1])


def _unit2(v: Vector2) -> Vector2:
    """Returns ``v`` scaled to unit length, or zero when it has no length."""
    n = _length2(v)
    if n <= _EPSILON:
        return (0.0, 0.0)
    return (v[0] * (1.0 / n), v[1] * (1.0 / n))


def _distance2(a: Vector2, b: Vector2) -> float:
    return _length2((a[0] - b[0], a[1] - b[1]))


def _dot2(a: Vector2, b: Vector2) -> float:
    return a[0] * b[0] + a[1] * b[1]


@dataclass(frozen=True, slots=True, kw_only=True)
class _DimensionBuilder:
    camera: CameraBasis
    vertical_fov_radians: float
    viewport_size: Vector2
    drafting: DraftingConvention
    style: DimensionStyle
    resolve_text: TextResolver
    key: object
    opacity: float

    def _screen(self, point: Vector3) -> Vector2 | None:
        return world_to_screen(
            point, self.camera, self.vertical_fov_radians, self.viewport_size
        )

    def _pixel(self, point: Vector3) -> float | None:
        return world_units_per_pixel_at(
            point, self.camera, self.vertical_fov_radians, self.viewport_size[1]
        )

    def _on_screen(self, v: Vector3) -> Vector2:
        """Returns ``v`` in screen coordinates: its components along screen
        right and up."""
        return (_vec.dot(v, self.camera.right), _vec.dot(v, self.camera.up))

    def _line(self, start: Vector3, end: Vector3) -> LinePrimitive:
        return LinePrimitive(
            start=start,
            end=end,
            width_pixels=self.style.line_width,
            key=self.key,
            opacity=self.opacity,
        )

    def _content(self, label: str) -> BillboardContent:
        return self.resolve_text(
            TextRequest(text=label, height_pixels=self.style.text_pixel_size)
        )

    def _viewer_perpendicular(self, direction: Vector3) -> Vector3:
        """Returns a unit vector perpendicular to ``direction`` that faces the
        viewer, turned toward screen up, or toward screen right when it lies
        level on screen."""
        camera = self.camera
        perpendicular = _vec.cross(direction, camera.to_viewer)
        if _vec.length(perpendicular) <= _EPSILON:
            # The direction runs along the view axis, so screen up is already
            # perpendicular to it.
            perpendicular = _vec.sub(
                camera.up, _vec.scale(direction, _vec.dot(camera.up, direction))
            )
        perpendicular = _vec.normalized(perpendicular)
        upward = _vec.dot(perpendicular, camera.up)
        flip = (
            upward < 0
            if abs(upward) > _EPSILON
            else _vec.dot(perpendicular, camera.right) < 0
        )
        return _vec.negated(perpendicular) if flip else perpendicular

    def _offset_direction(
        self, direction: Vector3, requested: Vector3 | None
    ) -> Vector3:
        if requested is not None:
            perpendicular = _vec.sub(
                requested, _vec.scale(direction, _vec.dot(requested, direction))
            )
            if _vec.length(perpendicular) > _EPSILON:
                return _vec.normalized(perpendicular)
        return self._viewer_perpendicular(direction)

    def linear(
        self,
        start: Vector3,
        end: Vector3,
        direction: Vector3,
        requested_offset: Vector3 | None,
        label: str,
    ) -> list[Primitive] | None:
        style = self.style
        measured = _vec.dot(_vec.sub(end, start), direction)
        points_pixel = self._pixel(_vec.midpoint(start, end))
        start_pixel = self._pixel(start)
        end_pixel = self._pixel(end)
        if points_pixel is None or start_pixel is None or end_pixel is None:
            return None

        offset = self._offset_direction(direction, requested_offset)
        foot_start = _vec.along(start, offset, style.offset_pixels * points_pixel)
        foot_end = _vec.along(foot_start, direction, measured)
        middle = _vec.midpoint(foot_start, foot_end)
        foot_start_pixel = self._pixel(foot_start)
        foot_end_pixel = self._pixel(foot_end)
        middle_pixel = self._pixel(middle)
        screen_start = self._screen(foot_start)
        screen_end = self._screen(foot_end)
        if (
            foot_start_pixel is None
            or foot_end_pixel is None
            or middle_pixel is None
            or screen_start is None
            or screen_end is None
        ):
            return None

        gap = style.witness_gap_for(self.drafting.standard)

        def witness(
            point: Vector3, foot: Vector3, point_pixel: float, foot_pixel: float
        ) -> LinePrimitive:
            span = _vec.sub(foot, point)
            length = _vec.length(span)
            along = _vec.scale(span, 1.0 / length) if length > _EPSILON else offset
            return self._line(
                _vec.along(point, along, min(gap * point_pixel, length)),
                _vec.along(foot, along, style.witness_extension_pixels * foot_pixel),
            )

        content = self._content(label)
        line_on_screen = self._on_screen(direction)
        placement, extent = self._fit(
            content, line_on_screen, _distance2(screen_end, screen_start)
        )
        return [
            witness(start, foot_start, start_pixel, foot_start_pixel),
            witness(end, foot_end, end_pixel, foot_end_pixel),
            *self._straight_line(
                foot_start,
                foot_end,
                direction,
                placement,
                extent,
                middle_pixel,
                line_on_screen,
            ),
            *self._arrowhead(foot_start, direction, foot_start_pixel),
            *self._arrowhead(foot_end, _vec.negated(direction), foot_end_pixel),
            *self._text(
                placement, content, middle, line_on_screen, offset, middle_pixel
            ),
        ]

    def angular(
        self,
        vertex: Vector3,
        along: Vector3,
        across: Vector3,
        angle: float,
        first_length: float,
        second_length: float,
        label: str,
    ) -> list[Primitive] | None:
        """Returns an arc of ``angle`` radians from the leg ``along`` toward
        ``across``, the unit perpendicular to it in the legs' plane, centered
        on ``vertex``. The legs end ``first_length`` and ``second_length``
        from ``vertex``."""
        style = self.style
        vertex_pixel = self._pixel(vertex)
        if vertex_pixel is None:
            return None
        radius = style.arc_radius_pixels * vertex_pixel

        def radial(t: float) -> Vector3:
            return _vec.add(
                _vec.scale(along, math.cos(t)), _vec.scale(across, math.sin(t))
            )

        def point(t: float) -> Vector3:
            return _vec.along(vertex, radial(t), radius)

        def tangent(t: float) -> Vector3:
            return _vec.add(
                _vec.scale(along, -math.sin(t)), _vec.scale(across, math.cos(t))
            )

        # Segments are counted from the arc's length at the vertex's depth,
        # which no view foreshortens, so the count depends on the style and
        # the angle alone.
        def segments(span: float) -> int:
            return max(
                1, math.ceil(style.arc_radius_pixels * span / style.arc_segment_pixels)
            )

        count = segments(angle)
        # Each point of the whole arc once: projected for the fit test, and
        # joined directly when no inlined break splits the arc.
        points = [point(angle * i / count) for i in range(count + 1)]
        screen = [self._screen(p) for p in points]
        half = angle / 2
        middle = point(half)
        first_end = points[0]
        second_end = points[-1]
        middle_pixel = self._pixel(middle)
        first_end_pixel = self._pixel(first_end)
        second_end_pixel = self._pixel(second_end)
        first_tip_pixel = self._pixel(_vec.along(vertex, along, first_length))
        second_tip_pixel = self._pixel(_vec.along(vertex, radial(angle), second_length))
        visible = [s for s in screen if s is not None]
        if (
            len(visible) != len(screen)
            or middle_pixel is None
            or first_end_pixel is None
            or second_end_pixel is None
            or first_tip_pixel is None
            or second_tip_pixel is None
        ):
            return None
        screen_length = 0.0
        for i in range(1, count + 1):
            screen_length += _distance2(visible[i], visible[i - 1])

        gap = style.witness_gap_for(self.drafting.standard)
        primitives: list[Primitive] = []

        def witness(
            leg: Vector3, length: float, tip_pixel: float, end_pixel: float
        ) -> None:
            begin = length + gap * tip_pixel
            if begin >= radius:
                return
            primitives.append(
                self._line(
                    _vec.along(vertex, leg, begin),
                    _vec.along(
                        vertex, leg, radius + style.witness_extension_pixels * end_pixel
                    ),
                )
            )

        witness(along, first_length, first_tip_pixel, first_end_pixel)
        witness(radial(angle), second_length, second_tip_pixel, second_end_pixel)

        content = self._content(label)
        line_on_screen = self._on_screen(tangent(half))
        placement, extent = self._fit(content, line_on_screen, screen_length)

        def run(start: float, end: float) -> None:
            n = segments(end - start)
            primitives.extend(
                self._line(
                    point(start + (end - start) * i / n),
                    point(start + (end - start) * (i + 1) / n),
                )
                for i in range(n)
            )

        if placement is DimensionTextPlacement.INLINED:
            half_break = min(
                self._half_break(extent, middle_pixel, line_on_screen) / radius, half
            )
            run(0, half - half_break)
            run(half + half_break, angle)
        else:
            primitives.extend(
                self._line(points[i], points[i + 1]) for i in range(count)
            )

        primitives.extend(self._arrowhead(first_end, tangent(0), first_end_pixel))
        primitives.extend(
            self._arrowhead(second_end, _vec.negated(tangent(angle)), second_end_pixel)
        )
        primitives.extend(
            self._text(
                placement, content, middle, line_on_screen, radial(half), middle_pixel
            )
        )
        return primitives

    def radial(
        self,
        start: Vector3,
        rim: Vector3,
        direction: Vector3,
        *,
        diameter: bool,
        label: str,
    ) -> list[Primitive] | None:
        """Returns a radial dimension line from ``start`` to ``rim`` along the
        unit ``direction``, with an arrowhead on ``rim``, and on ``start`` too
        for a ``diameter``."""
        middle = _vec.midpoint(start, rim)
        start_pixel = self._pixel(start)
        rim_pixel = self._pixel(rim)
        middle_pixel = self._pixel(middle)
        screen_start = self._screen(start)
        screen_rim = self._screen(rim)
        if (
            start_pixel is None
            or rim_pixel is None
            or middle_pixel is None
            or screen_start is None
            or screen_rim is None
        ):
            return None

        content = self._content(label)
        line_on_screen = self._on_screen(direction)
        placement, extent = self._fit(
            content, line_on_screen, _distance2(screen_rim, screen_start)
        )
        return [
            *self._straight_line(
                start, rim, direction, placement, extent, middle_pixel, line_on_screen
            ),
            *self._arrowhead(rim, _vec.negated(direction), rim_pixel),
            *(self._arrowhead(start, direction, start_pixel) if diameter else []),
            *self._text(
                placement,
                content,
                middle,
                line_on_screen,
                self._viewer_perpendicular(direction),
                middle_pixel,
            ),
        ]

    def _straight_line(
        self,
        start: Vector3,
        end: Vector3,
        direction: Vector3,
        placement: DimensionTextPlacement,
        extent: float,
        middle_pixel: float,
        line_on_screen: Vector2,
    ) -> list[LinePrimitive]:
        """Returns a straight dimension line from ``start`` to ``end`` along the
        unit ``direction``: one line, or two either side of the break that
        inlined text of ``extent`` pixels makes at its midpoint."""
        if placement is not DimensionTextPlacement.INLINED:
            return [self._line(start, end)]
        middle = _vec.midpoint(start, end)
        half_break = self._half_break(extent, middle_pixel, line_on_screen)
        return [
            self._line(start, _vec.along(middle, direction, -half_break)),
            self._line(_vec.along(middle, direction, half_break), end),
        ]

    def _fit(
        self,
        content: BillboardContent,
        line_on_screen: Vector2,
        screen_length: float,
    ) -> tuple[DimensionTextPlacement, float]:
        """Returns the placement of ``content`` on a dimension line, and the
        text's extent along it in pixels.

        The line's unit direction shows on screen as ``line_on_screen``, with
        ``screen_length`` pixels between its ends. Oriented and inlined text
        that does not fit, with an arrowhead and a text gap at each end, falls
        back to referencing.
        """
        style = self.style
        placement = self.drafting.placement
        screen_direction = _unit2(line_on_screen)
        extent = (
            content.width_pixels
            if placement is DimensionTextPlacement.ORIENTED
            else content.width_pixels * abs(screen_direction[0])
            + content.height_pixels * abs(screen_direction[1])
        )
        # A line seen end-on has no screen direction to set text along.
        fits = (
            _length2(line_on_screen) > _EPSILON
            and extent + 2 * (style.arrow_length_pixels + style.text_gap_pixels)
            <= screen_length
        )
        return (placement if fits else DimensionTextPlacement.REFERENCING, extent)

    def _half_break(
        self, extent: float, middle_pixel: float, line_on_screen: Vector2
    ) -> float:
        """Returns half the break inlined text of ``extent`` pixels makes, in
        world units along a dimension line whose unit direction shows on
        screen as ``line_on_screen``, at ``middle_pixel`` world units per
        pixel."""
        return (
            (extent / 2 + self.style.text_gap_pixels)
            * middle_pixel
            / _length2(line_on_screen)
        )

    def _text(
        self,
        placement: DimensionTextPlacement,
        content: BillboardContent,
        middle: Vector3,
        line_on_screen: Vector2,
        outward: Vector3,
        middle_pixel: float,
    ) -> list[Primitive]:
        """Returns the text of a dimension at ``middle`` of its dimension line,
        under ``placement``: a billboard, led off the line by a callout leader
        toward ``outward`` when referencing."""
        if placement is DimensionTextPlacement.ORIENTED:
            return [self._oriented_text(content, middle, line_on_screen)]
        if placement is DimensionTextPlacement.INLINED:
            return [
                BillboardPrimitive(
                    content=content, anchor=middle, key=self.key, opacity=self.opacity
                )
            ]
        quadrant = self._reference_quadrant(
            _unit2(line_on_screen), self._on_screen(outward)
        )
        leader = compute_callout_leader_geometry(
            anchor=middle,
            camera_right=self.camera.right,
            camera_up=self.camera.up,
            world_units_per_pixel=middle_pixel,
            quadrant=quadrant,
            style=self.style.leader,
        )
        return [
            *create_callout_leader_lines(leader, key=self.key, opacity=self.opacity),
            create_callout_label(
                leader, quadrant, content=content, key=self.key, opacity=self.opacity
            ),
        ]

    def _arrowhead(
        self, tip: Vector3, inward: Vector3, pixel: float
    ) -> list[LinePrimitive]:
        """Returns the two barbs of an open arrowhead whose tip is ``tip``, its
        shaft running along ``inward``."""
        style = self.style
        across = _vec.cross(inward, self.camera.to_viewer)
        across = (
            _vec.normalized(across)
            if _vec.length(across) > _EPSILON
            else self.camera.up
        )
        base = _vec.along(tip, inward, style.arrow_length_pixels * pixel)
        half_width = _vec.scale(across, style.arrow_width_pixels / 2 * pixel)
        return [
            self._line(tip, _vec.add(base, half_width)),
            self._line(tip, _vec.sub(base, half_width)),
        ]

    def _oriented_text(
        self, content: BillboardContent, middle: Vector3, line_on_screen: Vector2
    ) -> BillboardPrimitive:
        """Returns text parallel to the line on screen, read left to right, or
        bottom to top on a vertical line, and lifted off the line by the text
        gap."""
        camera = self.camera
        n = _length2(line_on_screen)
        x, y = line_on_screen[0] * (1.0 / n), line_on_screen[1] * (1.0 / n)
        backward = x < 0 if abs(x) > _EPSILON else y < 0
        if backward:
            x, y = -x, -y
        right = _vec.add(_vec.scale(camera.right, x), _vec.scale(camera.up, y))
        # A quarter turn counterclockwise on screen: the text's own up.
        up = _vec.add(_vec.scale(camera.right, -y), _vec.scale(camera.up, x))
        return BillboardPrimitive(
            content=content,
            anchor=middle,
            orientation=CoplanarOrientation(normal=camera.to_viewer, right=right),
            alignment=_BOTTOM_CENTER,
            offset=ScreenOffset(direction=up, pixels=self.style.text_gap_pixels),
            key=self.key,
            opacity=self.opacity,
        )

    def _reference_quadrant(self, along: Vector2, outward: Vector2) -> CalloutQuadrant:
        """Returns the callout quadrant whose leader leaves the line on its
        outer side, ``outward``, at the widest angle from the line's screen
        direction ``along``.

        When no quadrant leaves on the outer side, every quadrant competes.
        Ties go to the earlier quadrant.
        """
        leader = self.style.leader

        def leaving(q: CalloutQuadrant) -> Vector2:
            return callout_leader_direction(q, style=leader)

        outer = [q for q in CalloutQuadrant if _dot2(leaving(q), outward) > _EPSILON]
        candidates = outer or list(CalloutQuadrant)
        best = candidates[0]
        best_overlap = abs(_dot2(leaving(best), along))
        for q in candidates[1:]:
            overlap = abs(_dot2(leaving(q), along))
            if overlap < best_overlap - _EPSILON:
                best, best_overlap = q, overlap
        return best
