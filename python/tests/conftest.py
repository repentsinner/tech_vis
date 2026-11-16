"""Shared test helpers."""

import json
from collections.abc import Sequence
from pathlib import Path

import pytest

# Absolute tolerance on a golden-vector number, in the function's own units
# (§spec:golden-vectors).
TOLERANCE = 1e-9

# The golden vectors sit outside the package, so they exist in a repository
# checkout and are absent from an installed or unpacked distribution.
VECTORS_DIR = Path(__file__).resolve().parents[2] / "vectors"


def load_vectors(name: str) -> dict:
    """Returns the parsed vector file ``name``, or skips when it is absent."""
    path = VECTORS_DIR / name
    if not path.exists():
        pytest.skip(f"{path.name} is outside the sdist")
    return json.loads(path.read_text())


def assert_close(
    actual: Sequence[float],
    expected: Sequence[float],
    reason: str = "",
    tolerance: float = TOLERANCE,
) -> None:
    """Asserts that two sequences of numbers agree within ``tolerance``."""
    assert len(actual) == len(expected), reason
    for i, (got, want) in enumerate(zip(actual, expected, strict=True)):
        assert got == pytest.approx(want, rel=0, abs=tolerance), f"{reason}[{i}]"
