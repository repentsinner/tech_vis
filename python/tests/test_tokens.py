"""The generated token module agrees with style/tokens.json."""

import json
from pathlib import Path

import pytest

from tech_vis import tokens

# The source of truth sits outside the package, so it exists in a repository
# checkout and is absent from an installed or unpacked distribution.
TOKENS_JSON = Path(__file__).resolve().parents[2] / "style" / "tokens.json"

pytestmark = pytest.mark.skipif(
    not TOKENS_JSON.exists(), reason="style/tokens.json is outside the sdist"
)


def _source() -> dict:
    return json.loads(TOKENS_JSON.read_text())


def _resolve(entries: dict, name: str) -> float:
    entry = entries[name]
    return _resolve(entries, entry["alias"]) if "alias" in entry else entry["value"]


def test_style_version_matches():
    assert tokens.STYLE_VERSION == _source()["styleVersion"]


def test_every_token_is_generated_with_its_value():
    entries = _source()["tokens"]
    assert tokens.ALL.keys() == entries.keys()
    for name in entries:
        assert tokens.ALL[name] == _resolve(entries, name)


def test_constants_mirror_the_all_map():
    assert tokens.CALLOUT_GAP_PIXELS == tokens.ALL["calloutGapPixels"]
    assert tokens.CALLOUT_BORDER_THICKNESS == tokens.CALLOUT_LEADER_LINE_WIDTH
