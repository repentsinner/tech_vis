"""Vector arithmetic on plain float tuples, shared by the layout modules."""

import math

type Vector2 = tuple[float, float]
type Vector3 = tuple[float, float, float]

# The world origin.
ORIGIN: Vector3 = (0.0, 0.0, 0.0)

# A billboard alignment at the middle of its content.
CENTERED: Vector2 = (0.5, 0.5)


def add(a: Vector3, b: Vector3) -> Vector3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a: Vector3, b: Vector3) -> Vector3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scale(v: Vector3, k: float) -> Vector3:
    return (v[0] * k, v[1] * k, v[2] * k)


def along(origin: Vector3, direction: Vector3, distance: float) -> Vector3:
    """Returns ``origin`` moved ``distance`` times ``direction``."""
    return (
        origin[0] + direction[0] * distance,
        origin[1] + direction[1] * distance,
        origin[2] + direction[2] * distance,
    )


def dot(a: Vector3, b: Vector3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a: Vector3, b: Vector3) -> Vector3:
    """Returns the textbook (right-handed component) cross product."""
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def length(v: Vector3) -> float:
    return math.sqrt(dot(v, v))


def normalized(v: Vector3) -> Vector3:
    """Returns ``v`` scaled to unit length, or ``v`` itself when it is zero."""
    n = length(v)
    # vector_math leaves a zero vector unchanged; agree with it.
    return v if n == 0 else scale(v, 1.0 / n)
