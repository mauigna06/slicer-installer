#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "asciify-them==1.1.1",
#     "pillow==12.3.0",
#     "numpy==2.2.6",
# ]
# ///
"""
Generate 3d-slicer-logo.ans: colored ANSI ASCII art of the central 3D Slicer
logo icon, with a centered "3D Slicer" label below.

WHAT IT DOES
------------
1. Crops ../resources/3dSlicerLogoStackedWeb-1.png (repo root) to just the logo
   icon (the sphere + stacked colored blocks), excluding the surrounding white
   padding and the original "3D Slicer" text band.
2. Turns the white padding "transparent": every near-white pixel
   (min(R,G,B) >= WHITE_THRESHOLD) is set to black. asciify maps black to the
   space character (the first char of its charset), so the padding renders as
   empty terminal background instead of a solid block of white characters.
   This is done at full resolution *before* downscaling so the padding blends
   toward black (empty) and leaves no bright halo specks.
3. Downsamples to a fixed WIDTH-char grid (height adjusted for the ~2:1
   height:width aspect of terminal cells) and asciifies it in color.
4. Appends a blank line and a centered "3D Slicer" label in the logo's own
   blue-gray text color, sampled from the source PNG.

REPRODUCIBILITY
---------------
The output is deterministic given the pinned dependency versions above.
Easiest run, from the repo root (uv installs the exact deps into an isolated
env automatically, and uses ascii_art/make_ascii_logo.py.lock):

    uv run --locked ascii_art/make_ascii_logo.py

Result is written next to this script at ascii_art/3d-slicer-logo.ans
(view it with: cat ascii_art/3d-slicer-logo.ans). The output path is resolved
relative to this file, so the command works from any working directory.

Without uv (needs Python >= 3.11, because asciify-them pins contourpy==1.3.3
which requires 3.11+):

    python3.11 -m venv .venv
    .venv/bin/pip install asciify-them==1.1.1 pillow==12.3.0 numpy==2.2.6
    .venv/bin/python ascii_art/make_ascii_logo.py

Optional: pass a target width as the first argument, e.g.

    uv run --locked ascii_art/make_ascii_logo.py 90        # larger
    uv run --locked ascii_art/make_ascii_logo.py 63 out.ans
"""

import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from asciify import asciify

# --- Configuration (these constants reproduce the committed 3d-slicer-logo.ans) ---
HERE = Path(__file__).resolve().parent
# The source image lives in resources/ at the repo root, one level above this folder.
SRC = HERE.parent / "resources" / "3dSlicerLogoStackedWeb-1.png"

# Bounding box of the logo icon within the 600x525 source (left, top, right, bottom).
# Found by locating the non-white content band that is the icon (the "3D Slicer"
# text lives in a separate band lower down and is intentionally excluded).
ICON_BBOX = (197, 124, 406, 334)
MARGIN = 4                       # a few px of breathing room around the icon
WHITE_THRESHOLD = 235            # min(R,G,B) >= this  ->  treated as transparent padding
DEFAULT_WIDTH = 63               # output width in characters
LABEL = "3D Slicer"
LABEL_RGB = (175, 184, 210)      # median color of the "3D Slicer" text in the source


def main() -> None:
    width = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_WIDTH
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "3d-slicer-logo.ans"

    im = Image.open(SRC).convert("RGB")
    w0, h0 = im.size
    l, t, r, b = ICON_BBOX
    box = (max(0, l - MARGIN), max(0, t - MARGIN),
           min(w0, r + 1 + MARGIN), min(h0, b + 1 + MARGIN))
    icon = im.crop(box)
    iw, ih = icon.size

    # White padding -> black (=> space => transparent), at full resolution first.
    full = np.array(icon).astype(np.int16)
    full[full.min(axis=2) >= WHITE_THRESHOLD] = 0
    icon = Image.fromarray(full.astype(np.uint8))

    # Terminal char cells are ~2:1 (h:w); halve the row count to keep true aspect.
    height = max(1, round(width * (ih / iw) / 2.0))
    grid = icon.resize((width, height), Image.LANCZOS)

    # asciify reads via cv2.imread (drops alpha), so we hand it a real file.
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        tmp_path = tmp.name
    grid.save(tmp_path)

    try:
        art = asciify(tmp_path, color_mode="color", width=width, height=height,
                      keep_aspect_ratio=False, output_format="text")
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    # Centered "3D Slicer" label below, in the logo's blue-gray color.
    pad = max(0, (width - len(LABEL)) // 2)
    tr, tg, tb = LABEL_RGB
    label_line = " " * pad + f"\033[38;2;{tr};{tg};{tb}m{LABEL}"
    art = art + "\033[0m\n\n" + label_line + "\033[0m\n"

    out_path.write_text(art)
    sys.stderr.write(f"[grid {width}x{height}] wrote {out_path}\n")


if __name__ == "__main__":
    main()
