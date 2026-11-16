"""World axes and the app's declared convention (§spec:coordinate-convention)."""

from dataclasses import dataclass
from enum import StrEnum

from tech_vis import _vec
from tech_vis._vec import Vector3


class SpatialAxis(StrEnum):
    """Names a world coordinate axis.

    Each value is the axis's name in the golden vectors and in the Dart
    package, so ``SpatialAxis("z")`` parses a fixture entry.
    """

    X = "x"
    Y = "y"
    Z = "z"

    @property
    def unit_vector(self) -> Vector3:
        return _UNIT_VECTORS[self]

    @property
    def label(self) -> str:
        """Returns the single-character uppercase label, such as ``"X"``."""
        return self.value.upper()


_UNIT_VECTORS: dict[SpatialAxis, Vector3] = {
    SpatialAxis.X: (1.0, 0.0, 0.0),
    SpatialAxis.Y: (0.0, 1.0, 0.0),
    SpatialAxis.Z: (0.0, 0.0, 1.0),
}


@dataclass(frozen=True, slots=True)
class SignedAxis:
    """Holds a world axis and the direction along it, such as -Y."""

    axis: SpatialAxis
    negative: bool = False

    @property
    def unit_vector(self) -> Vector3:
        v = self.axis.unit_vector
        return _vec.scale(v, -1.0) if self.negative else v

    def __neg__(self) -> "SignedAxis":
        return SignedAxis(self.axis, negative=not self.negative)

    def __str__(self) -> str:
        return f"{'-' if self.negative else '+'}{self.axis.label}"


class Handedness(StrEnum):
    """Names the rule that relates the three world axes to one another.

    Each value is the name in the golden vectors and in the Dart package.
    """

    RIGHT = "right"
    """X cross Y gives +Z by the right-hand rule."""

    LEFT = "left"
    """X cross Y gives +Z by the left-hand rule."""


# The axis before each up axis in the cycle X, Y, Z.
_FALLBACK = {
    SpatialAxis.X: SpatialAxis.Z,
    SpatialAxis.Y: SpatialAxis.X,
    SpatialAxis.Z: SpatialAxis.Y,
}

# The two axes after each up axis in the cycle X, Y, Z.
_PLANE_AXES = {
    SpatialAxis.X: (SpatialAxis.Y, SpatialAxis.Z),
    SpatialAxis.Y: (SpatialAxis.Z, SpatialAxis.X),
    SpatialAxis.Z: (SpatialAxis.X, SpatialAxis.Y),
}


@dataclass(frozen=True, slots=True, kw_only=True)
class CoordinateConvention:
    """Holds which world axis points up, and the handedness of the axes.

    Every input and output of the package is in this space. The convention
    has no default, because a wrong default fails silently: a Y-up scene read
    as Z-up stands its floor on end.
    """

    up: SpatialAxis
    handedness: Handedness

    @property
    def fallback_axis(self) -> SpatialAxis:
        """Returns the axis that replaces ``up`` when a view looks along it.

        It is the axis before ``up`` in the cycle X, Y, Z, so a Z-up top view
        keeps +Y up on screen, as a plan view does.
        """
        return _FALLBACK[self.up]

    @property
    def plane_axes(self) -> tuple[SpatialAxis, SpatialAxis]:
        """Returns the two axes after ``up`` in the cycle X, Y, Z.

        They span the plane across ``up`` and both point the positive way.
        """
        return _PLANE_AXES[self.up]

    def cross(self, u: Vector3, v: Vector3) -> Vector3:
        """Returns ``u`` cross ``v`` by the declared hand rule.

        A left-handed space mirrors one axis, which reverses the sign of the
        textbook formula.
        """
        if self.handedness is Handedness.RIGHT:
            return _vec.cross(u, v)
        return _vec.cross(v, u)

    def __str__(self) -> str:
        return f"{self.up.label}-up {self.handedness.value}-handed"
