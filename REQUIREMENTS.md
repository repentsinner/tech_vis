# tech_vis — Requirements

## Problem statement §req:problem-statement

**Target users** are developers who annotate 3D scenes in a technical
drawing style: a point in space, a thin leader line, a label that stays
legible at any camera distance. Their renderers differ — different
engines, different languages — and the look should not.

**The problem** is that the style lives in constants and layout math
scattered through each renderer. A second renderer copies the numbers,
and the copies drift.

**Success** is one style, defined once, that renderers in more than one
language reproduce and can prove they reproduce.
