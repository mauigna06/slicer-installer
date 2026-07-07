# 3D Slicer ASCII logo

[3d-slicer-logo.ans](3d-slicer-logo.ans) is colored ANSI ASCII art of the
central 3D Slicer logo icon with a "3D Slicer" label below. It is generated
from [../resources/3dSlicerLogoStackedWeb-1.png](../resources/3dSlicerLogoStackedWeb-1.png)
(at the repo root) by [make_ascii_logo.py](make_ascii_logo.py).

All commands below assume you run them from the **repo root**. The script
resolves its input/output paths relative to its own location, so it also works
from any other working directory.

## View it

```bash
cat ascii_art/3d-slicer-logo.ans
```

The file contains 24-bit ANSI color codes; the white padding of the original
image is rendered as empty (transparent) terminal background, not white.

## Regenerate it

Deterministic given the pinned versions. The script carries PEP 723 inline
metadata, so [uv](https://docs.astral.sh/uv/) installs the exact dependencies
into an isolated environment automatically. `make_ascii_logo.py.lock` pins the
**full transitive dependency tree**; `--locked` fails rather than silently
re-resolving if anything drifts:

```bash
uv run --locked ascii_art/make_ascii_logo.py
```

(Plain `uv run ascii_art/make_ascii_logo.py` also works and uses the lock if present.)

Optional first argument sets the character width (default `63`):

```bash
uv run --locked ascii_art/make_ascii_logo.py 90
```

### Without uv

`asciify-them` pins `contourpy==1.3.3`, which requires **Python >= 3.11**
(this is why `pip install asciify-them` fails on Python 3.10):

```bash
python3.11 -m venv .venv
.venv/bin/pip install asciify-them==1.1.1 pillow==12.3.0 numpy==2.2.6
.venv/bin/python ascii_art/make_ascii_logo.py
```

## Dependencies (pinned)

Direct dependencies (declared in the script's PEP 723 metadata):

| Package        | Version |
|----------------|---------|
| Python         | >= 3.11 |
| asciify-them   | 1.1.1   |
| pillow         | 12.3.0  |
| numpy          | 2.2.6   |

The full transitive tree — the above plus `contourpy 1.3.3`, `opencv-python
4.12.0.88`, `fonttools`, `kiwisolver`, `cycler`, `pyparsing`, `python-dateutil`,
`six`, `packaging` — is pinned in `make_ascii_logo.py.lock` (generated with
`uv lock --script ascii_art/make_ascii_logo.py`).

## How it works

1. Crop the source PNG to the logo icon bounding box `(197, 124, 406, 334)`
   (+4 px margin), excluding the outer white padding and the original text band.
2. Set near-white pixels (`min(R,G,B) >= 235`) to black at full resolution.
   `asciify` maps black to the space character, so the padding becomes empty
   ("transparent") instead of solid white — done before downscaling to avoid
   bright halo specks.
3. Downsample to a 63-char-wide grid (height halved for the ~2:1 terminal cell
   aspect) and asciify in color (`asciify` reads via `cv2.imread`, which drops
   alpha, so a real intermediate file is written).
4. Append a centered `3D Slicer` label in the logo's blue-gray text color
   `RGB(175, 184, 210)`, sampled from the source image.
