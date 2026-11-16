"""Adaptive ground grid (§spec:ground-plane), ported from the Dart reference.

A patch of minor and major lines lies in the plane across the declared up
axis, with coordinate labels on the major lines. The minor step adapts to the
camera, so minor lines keep a minimum pixel spacing at the camera target at
any zoom. Every function here agrees with ``vectors/ground_plane.json``.
"""

import math
from dataclasses import dataclass

from tech_vis import _vec, tokens
from tech_vis._vec import ORIGIN, Vector2, Vector3
from tech_vis.coordinate_convention import CoordinateConvention
from tech_vis.primitives import (
    BillboardPrimitive,
    LinePrimitive,
    Primitive,
    TextRequest,
    TextResolver,
)
from tech_vis.screen_space import CameraBasis, world_units_per_pixel_at
from tech_vis.unit_system import (
    DisplayFormat,
    NumberFormatting,
    UnitSystem,
    _round_half_away,
)

# The center line and one line either side: the fewest lines a grid with a
# step can draw across a patch.
_FEWEST_LINES_PER_AXIS = 3

# Bottom-left corner of a label's content, which sits on its anchor so the
# label reads up and to the right of the line crossing it marks.
_LABEL_ALIGNMENT: Vector2 = (0.0, 0.0)


@dataclass(frozen=True, slots=True, kw_only=True)
class RectangularGroundPatch:
    """Holds a rectangle centered on the plane's origin.

    Its half extents run along the plane's two axes, ``u`` and ``v`` of
    ``CoordinateConvention.plane_axes``.
    """

    half_extent_u: float
    """Half the patch's length along the plane's ``u`` axis, in world units."""

    half_extent_v: float
    """Half the patch's length along the plane's ``v`` axis, in world units."""


@dataclass(frozen=True, slots=True, kw_only=True)
class CircularGroundPatch:
    """Holds a disc around the plane's origin."""

    radius: float
    """Radius of the disc, in world units."""


type GroundPatch = RectangularGroundPatch | CircularGroundPatch
"""The area of the ground plane, centered on the plane's origin.

The patch sets where the grid's lines end and how far its ``GroundFade``
reaches.
"""


@dataclass(frozen=True, slots=True, kw_only=True)
class GroundFade:
    """Holds the fade of a ground grid from its patch center to the patch edge.

    Labels carry the fade at their anchors. A renderer fading lines per pixel
    evaluates ``opacity_at``, or the same formula in a shader from ``center``,
    ``u``, ``v``, and ``patch``, so lines and labels agree.
    """

    center: Vector3
    """World-space center of the patch, where the fade is at full opacity."""

    u: Vector3
    """Unit vector along the plane's ``u`` axis, which a rectangle's
    ``half_extent_u`` runs along."""

    v: Vector3
    """Unit vector along the plane's ``v`` axis, which a rectangle's
    ``half_extent_v`` runs along."""

    patch: GroundPatch
    """The patch whose extents set the fade's reach."""

    def opacity_at(self, world_point: Vector3) -> float:
        """Returns the fade's opacity at ``world_point``.

        The opacity is one at ``center`` and zero from the patch edge out. The
        point projects onto the plane to ``a = (p - center) · u`` and
        ``b = (p - center) · v``. Its reach ``r`` is ``sqrt(a² + b²) / radius``
        on a circular patch and ``max(|a| / half_extent_u, |b| /
        half_extent_v)`` on a rectangular one. The opacity is
        ``1 - smoothstep(0, 1, r)``, where ``smoothstep(0, 1, r) = t² (3 - 2t)``
        with ``t`` the reach clamped to ``[0, 1]``.
        """
        d = _vec.sub(world_point, self.center)
        a = _vec.dot(d, self.u)
        b = _vec.dot(d, self.v)
        patch = self.patch
        if isinstance(patch, RectangularGroundPatch):
            reach = max(abs(a) / patch.half_extent_u, abs(b) / patch.half_extent_v)
        else:
            reach = math.sqrt(a * a + b * b) / patch.radius
        t = min(max(reach, 0.0), 1.0)
        return 1 - t * t * (3 - 2 * t)


@dataclass(frozen=True, slots=True, kw_only=True)
class GroundGridStyle:
    """Holds the look of a ground grid. Every default is a style token."""

    min_line_spacing_pixels: float = tokens.GROUND_GRID_MIN_LINE_SPACING_PIXELS
    """Smallest screen distance between neighboring minor lines at the camera
    target, in pixels."""

    step_margin: float = tokens.GROUND_GRID_STEP_MARGIN
    """Fraction by which the spacing passes a step boundary before the step
    changes."""

    max_lines_per_axis: int = int(tokens.GROUND_GRID_MAX_LINES_PER_AXIS)
    """Most lines across the patch in each direction."""

    minor_line_width: float = tokens.GROUND_GRID_MINOR_LINE_WIDTH
    """Width of a minor line, in screen pixels."""

    major_line_width: float = tokens.GROUND_GRID_MAJOR_LINE_WIDTH
    """Width of a major line, in screen pixels."""

    label_pixel_size: float = tokens.GROUND_GRID_LABEL_PIXEL_SIZE
    """Pixel height of a coordinate label."""


# Default arguments are built once; both are frozen, so sharing them is safe.
_DEFAULT_STYLE = GroundGridStyle()
_DEFAULT_NUMBERS = NumberFormatting()


@dataclass(frozen=True, slots=True, kw_only=True)
class GroundGrid:
    """Holds a ground grid for one frame: its steps, fade, and primitives."""

    minor_step: float
    """Distance between minor lines, in the display format's base unit.

    Pass it back as the previous step of the next frame, so the grid holds its
    step near a step boundary.
    """

    major_step: float
    """Distance between major lines, in the display format's base unit."""

    fade: GroundFade
    """The fade toward the patch edge, which the renderer applies to the lines
    and the labels already carry."""

    primitives: tuple[Primitive, ...]
    """Minor lines, then major lines, then coordinate labels."""


def ground_minor_step(
    *,
    display_format: DisplayFormat,
    minimum_spacing: float,
    previous_step: float | None = None,
    margin: float = tokens.GROUND_GRID_STEP_MARGIN,
) -> float:
    """Returns the minor grid step for lines at least ``minimum_spacing`` apart.

    Both lengths are in the base unit of ``display_format``. Without a
    ``previous_step``, returns the smallest grid step at least
    ``minimum_spacing`` long. With one, keeps ``previous_step`` while the
    spacing stays within ``margin`` of the boundary it last crossed: the step
    coarsens only once ``minimum_spacing`` passes ``previous_step`` by the
    fraction ``margin``, and refines only once the finer step clears
    ``minimum_spacing`` by the same fraction. A ``previous_step`` that is not
    a grid step of ``display_format`` is ignored.

    Raises ``ValueError`` when ``margin`` is negative or not finite.
    """
    if not math.isfinite(margin) or margin < 0:
        raise ValueError(f"margin must be zero or more, got {margin!r}")
    ideal = display_format.grid_step_at_least(minimum_spacing)
    if previous_step is None or not display_format.is_grid_step(previous_step):
        return ideal
    # Every value compared is a step the format returned, so each comparison
    # is exact.
    held = display_format.grid_step_at_least(previous_step)
    finest = display_format.grid_step_at_least(minimum_spacing / (1 + margin))
    coarsest = display_format.grid_step_at_least(minimum_spacing * (1 + margin))
    return held if finest <= held <= coarsest else ideal


def create_ground_grid(
    *,
    convention: CoordinateConvention,
    patch: GroundPatch,
    display_format: DisplayFormat,
    world_units: UnitSystem,
    camera: CameraBasis,
    target: Vector3,
    vertical_fov_radians: float,
    viewport_height: float,
    resolve_text: TextResolver,
    minor_key: object,
    major_key: object,
    label_key: object,
    origin: Vector3 = ORIGIN,
    previous_minor_step: float | None = None,
    numbers: NumberFormatting = _DEFAULT_NUMBERS,
    style: GroundGridStyle = _DEFAULT_STYLE,
) -> GroundGrid:
    """Returns the ground grid over ``patch``, centered on ``origin``.

    The grid lies in the plane through ``origin`` across the up axis of
    ``convention``, for a ``camera`` looking at ``target``. One world unit is
    one base unit of ``world_units``: a millimeter or an inch. The minor step
    is the ``ground_minor_step`` for ``style.min_line_spacing_pixels`` at
    ``target``, held by ``previous_minor_step`` within the style's margin, and
    coarsened so no more than ``style.max_lines_per_axis`` lines cross the
    patch in either direction. The major step is the grid step of
    ``display_format`` above the minor step.

    Each line is one Line across the whole chord of the patch, at full
    opacity, and a line whose chord is empty is left out. A renderer fades the
    lines toward the patch edge per pixel with ``GroundGrid.fade``. Each major
    line carries one coordinate label where it crosses the perpendicular line
    through ``origin``, and ``origin`` carries one label for zero. The labels
    form one set in ``display_format``, written with ``numbers``, and face the
    viewer. Each label's opacity is ``GroundFade.opacity_at`` its anchor, and
    a label at zero opacity is left out.

    Raises ``ValueError`` when ``target`` lies on or behind the camera plane,
    when the patch has no positive size, or when the style allows fewer than
    three lines per axis.
    """
    per_pixel = world_units_per_pixel_at(
        target, camera, vertical_fov_radians, viewport_height
    )
    if per_pixel is None:
        raise ValueError(f"target must lie in front of the camera, got {target!r}")
    if style.max_lines_per_axis < _FEWEST_LINES_PER_AXIS:
        raise ValueError(
            f"style.max_lines_per_axis must be at least {_FEWEST_LINES_PER_AXIS},"
            f" got {style.max_lines_per_axis!r}"
        )
    shape = _PatchShape(patch)
    to_format = world_units.convert_to
    target_system = display_format.unit_system

    spaced = ground_minor_step(
        display_format=display_format,
        minimum_spacing=to_format(
            style.min_line_spacing_pixels * per_pixel, target_system
        ),
        previous_step=previous_minor_step,
        margin=style.step_margin,
    )
    # Lines at every multiple of the step within the larger half extent number
    # 2 * floor(extent / step) + 1, which this spacing bounds.
    fits = display_format.grid_step_at_least(
        to_format(2 * shape.max_extent / (style.max_lines_per_axis - 1), target_system)
    )
    minor = max(spaced, fits)
    major = display_format.grid_step_above(minor)
    minor_world = target_system.convert_to(minor, world_units)
    lines_per_major = _round_half_away(major / minor)

    u_axis, v_axis = convention.plane_axes
    u = u_axis.unit_vector
    v = v_axis.unit_vector

    def at(a: float, b: float) -> Vector3:
        return _vec.add(_vec.add(origin, _vec.scale(u, a)), _vec.scale(v, b))

    fade = GroundFade(center=origin, u=u, v=v, patch=patch)

    minor_lines: list[Primitive] = []
    major_lines: list[Primitive] = []
    for along_v in (True, False):
        extent = shape.extent_u if along_v else shape.extent_v
        count = math.floor(extent / minor_world)
        for k in range(-count, count + 1):
            offset = k * minor_world
            span = shape.span(offset, along_v=along_v)
            if span <= 0:
                continue
            is_major = k % lines_per_major == 0
            (major_lines if is_major else minor_lines).append(
                LinePrimitive(
                    start=at(offset, -span) if along_v else at(-span, offset),
                    end=at(offset, span) if along_v else at(span, offset),
                    width_pixels=(
                        style.major_line_width if is_major else style.minor_line_width
                    ),
                    key=major_key if is_major else minor_key,
                )
            )

    # Labels on the u axis, then the v axis, each a whole number of major
    # steps from the origin, which carries the one zero label. A label at the
    # patch edge is invisible, so it stays out of the set and cannot promote
    # the others.
    major_world = target_system.convert_to(major, world_units)

    def mark(k: int, on_u: bool) -> tuple[int, Vector3, float]:
        offset = k * major_world
        anchor = at(offset, 0) if on_u else at(0, offset)
        return k, anchor, fade.opacity_at(anchor)

    marks = [mark(0, True)]
    for on_u in (True, False):
        count = math.floor((shape.extent_u if on_u else shape.extent_v) / major_world)
        marks.extend(
            m
            for m in (mark(k, on_u) for k in range(-count, count + 1) if k != 0)
            if m[2] > 0
        )
    texts = display_format.format_labels(
        [k * major for k, _, _ in marks], step=major, numbers=numbers
    )
    labels: list[Primitive] = [
        BillboardPrimitive(
            content=resolve_text(
                TextRequest(text=text, height_pixels=style.label_pixel_size)
            ),
            anchor=anchor,
            alignment=_LABEL_ALIGNMENT,
            key=label_key,
            opacity=opacity,
        )
        for (_, anchor, opacity), text in zip(marks, texts, strict=True)
    ]

    return GroundGrid(
        minor_step=minor,
        major_step=major,
        fade=fade,
        primitives=(*minor_lines, *major_lines, *labels),
    )


class _PatchShape:
    """A patch's extents and chord lengths, in plane coordinates relative to
    its center."""

    __slots__ = ("extent_u", "extent_v", "patch")

    def __init__(self, patch: GroundPatch) -> None:
        if isinstance(patch, RectangularGroundPatch):
            extent_u, extent_v = patch.half_extent_u, patch.half_extent_v
        else:
            extent_u = extent_v = patch.radius
        if not (_positive(extent_u) and _positive(extent_v)):
            raise ValueError(f"patch needs a positive size, got {patch!r}")
        self.patch = patch
        # Half extent along each plane axis: the radius of a disc.
        self.extent_u = extent_u
        self.extent_v = extent_v

    @property
    def max_extent(self) -> float:
        return max(self.extent_u, self.extent_v)

    def span(self, offset: float, *, along_v: bool) -> float:
        """Returns half the length of the line at ``offset``, running along
        ``v`` when ``along_v`` and along ``u`` otherwise."""
        if isinstance(self.patch, RectangularGroundPatch):
            return self.extent_v if along_v else self.extent_u
        radius = self.extent_u
        return math.sqrt(max(0.0, radius * radius - offset * offset))


def _positive(x: float) -> bool:
    return math.isfinite(x) and x > 0
