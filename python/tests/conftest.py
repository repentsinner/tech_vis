"""Shared test helpers."""

import json
from pathlib import Path

import pytest

# The golden vectors sit outside the package, so they exist in a repository
# checkout and are absent from an installed or unpacked distribution.
VECTORS_DIR = Path(__file__).resolve().parents[2] / "vectors"


def load_vectors(name: str) -> dict:
    """Returns the parsed vector file ``name``, or skips when it is absent."""
    path = VECTORS_DIR / name
    if not path.exists():
        pytest.skip(f"{path.name} is outside the sdist")
    return json.loads(path.read_text())
