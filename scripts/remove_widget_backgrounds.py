#!/usr/bin/env python3
"""
Turn the green-screen widget screenshots into per-widget transparent PNGs.

`scripts/screenshots.sh` (fastlane snapshot) captures two widget-gallery screens
per locale against a pure chroma-key green backdrop (WidgetGalleryView renders
sRGB (0,1,0) because a device screen capture has no alpha channel):

    <device>-06-Widget-Schedule.png   Schedule widget: medium (top) + large (bottom)
    <device>-07-Widget-Today.png      Today's Page widget: small (top) + large (bottom)

This script keys out the green, crops each widget tight, and writes transparent
PNGs to a sibling folder so they survive fastlane's clear_previous_screenshots:

    screenshots-widgets/<locale>/Widget-Schedule-medium.png
    screenshots-widgets/<locale>/Widget-Schedule-large.png
    screenshots-widgets/<locale>/Widget-Today-small.png
    screenshots-widgets/<locale>/Widget-Today-large.png
    screenshots-widgets/<locale>/_preview.png   (cutouts over a checkerboard)

It is standalone and re-runnable — run it any time against an existing
screenshots/ tree, no re-shooting required:

    python3 scripts/remove_widget_backgrounds.py
    python3 scripts/remove_widget_backgrounds.py --locales en-US
    python3 scripts/remove_widget_backgrounds.py --source screenshots --out screenshots-widgets

Requires Pillow and numpy (`pip3 install Pillow numpy`).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment guard
    sys.exit(
        f"Missing dependency: {exc.name}. Install with: pip3 install Pillow numpy"
    )

DEFAULT_LOCALES = ["en-US", "zh-Hans", "zh-Hant", "ja", "ko"]

# (filename suffix, [size name per VStack band, top→bottom], [expected w/h per band])
# Band order and aspect ratios mirror WidgetGalleryView's VStack + chrome(width:height:).
SOURCES = [
    ("-06-Widget-Schedule.png", "Widget-Schedule", ["medium", "large"], [364 / 170, 364 / 382]),
    ("-07-Widget-Today.png", "Widget-Today", ["small", "large"], [170 / 170, 364 / 382]),
]

# Chroma-key feather: greenness = g - max(r, b). Interior content is < LO
# (opaque); pure green is 255 (transparent); anti-aliased rounded corners feather
# between. LO is set high enough that the pastel mint/sea event chips (the content
# colours nearest green, greenness ~25) stay fully opaque, while the rounded edges
# still feather — any faint green left on a kept edge pixel is removed by despill.
GREEN_LO = 28
GREEN_HI = 255
# A row/column counts as "content" if any pixel's alpha exceeds this (0..255).
CONTENT_ALPHA = 12
# Drop bands thinner than this (keying noise, not a widget).
MIN_BAND_PX = 24
# Warn (don't mislabel) if a band's aspect ratio is off from expected by more.
ASPECT_TOLERANCE = 0.30


def key_green(rgb: np.ndarray) -> np.ndarray:
    """RGB uint8 (H,W,3) → RGBA uint8 with green keyed out and despilled."""
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)

    greenness = g - np.maximum(r, b)

    # Feathered straight-alpha: opaque where greenness <= LO, transparent at HI.
    alpha = 1.0 - (greenness - GREEN_LO) / float(GREEN_HI - GREEN_LO)
    alpha = np.clip(alpha, 0.0, 1.0)

    # Despill: pull green down to the larger of red/blue so no green fringe
    # survives on the kept rounded edges.
    g_despilled = np.minimum(g, np.maximum(r, b))

    out = np.empty((*rgb.shape[:2], 4), dtype=np.uint8)
    out[:, :, 0] = r
    out[:, :, 1] = g_despilled
    out[:, :, 2] = b
    out[:, :, 3] = (alpha * 255.0).round().astype(np.uint8)
    return out


def find_bands(alpha: np.ndarray, keep: int) -> list[tuple[int, int]]:
    """The `keep` widest content bands (top→bottom), separated by the VStack gap.

    Maximal runs of content rows are detected, then the `keep` bands with the
    most opaque pixels are kept and re-sorted top→bottom. Selecting by content
    area drops the simulator status bar (09:41 clock + battery), which also sits
    opaque over the green but is small and sparse.
    """
    content = alpha > CONTENT_ALPHA
    row_has_content = content.any(axis=1)
    runs: list[tuple[int, int]] = []
    start = None
    for y, present in enumerate(row_has_content):
        if present and start is None:
            start = y
        elif not present and start is not None:
            if y - start >= MIN_BAND_PX:
                runs.append((start, y))
            start = None
    if start is not None and len(row_has_content) - start >= MIN_BAND_PX:
        runs.append((start, len(row_has_content)))

    if len(runs) > keep:
        runs.sort(key=lambda yr: int(content[yr[0] : yr[1]].sum()), reverse=True)
        runs = runs[:keep]
    runs.sort(key=lambda yr: yr[0])
    return runs


def tight_crop(rgba: np.ndarray, y0: int, y1: int) -> np.ndarray:
    """Crop a row band, then trim its left/right transparent margins."""
    band = rgba[y0:y1]
    col_has_content = (band[:, :, 3] > CONTENT_ALPHA).any(axis=0)
    cols = np.nonzero(col_has_content)[0]
    if len(cols) == 0:
        return band
    return band[:, cols[0] : cols[-1] + 1]


def checkerboard(width: int, height: int, square: int = 24) -> np.ndarray:
    """Magenta/white checkerboard so any residual green fringe is glaring."""
    ys, xs = np.mgrid[0:height, 0:width]
    mask = ((xs // square) + (ys // square)) % 2 == 0
    bg = np.empty((height, width, 3), dtype=np.uint8)
    bg[mask] = (255, 0, 255)
    bg[~mask] = (255, 255, 255)
    return bg


def composite_over(rgba: np.ndarray, bg_rgb: np.ndarray) -> np.ndarray:
    a = rgba[:, :, 3:4].astype(np.float32) / 255.0
    return (rgba[:, :, :3].astype(np.float32) * a + bg_rgb.astype(np.float32) * (1 - a)).astype(np.uint8)


def build_preview(cutouts: list[Image.Image], pad: int = 40) -> Image.Image:
    """Lay the cutouts out in a row over a checkerboard for visual review."""
    height = max(im.height for im in cutouts) + pad * 2
    width = sum(im.width for im in cutouts) + pad * (len(cutouts) + 1)
    canvas = Image.fromarray(checkerboard(width, height)).convert("RGBA")
    x = pad
    for im in cutouts:
        y = (height - im.height) // 2
        canvas.alpha_composite(im, (x, y))
        x += im.width + pad
    return canvas


def assert_transparent(im: Image.Image, label: str) -> None:
    """Structural sanity checks: alpha present, corners cut, centre kept."""
    assert im.mode == "RGBA", f"{label}: expected RGBA, got {im.mode}"
    arr = np.asarray(im)
    h, w = arr.shape[:2]
    corners = [arr[0, 0, 3], arr[0, w - 1, 3], arr[h - 1, 0, 3], arr[h - 1, w - 1, 3]]
    assert max(corners) == 0, f"{label}: corners not transparent (alpha {corners})"
    assert arr[h // 2, w // 2, 3] == 255, f"{label}: centre is not opaque"


def process_source(src: Path, base_name: str, sizes: list[str], expected_ratios: list[float]):
    """Key + split one green-screen screenshot. Returns list of (name, PIL.Image)."""
    rgb = np.asarray(Image.open(src).convert("RGB"))
    rgba = key_green(rgb)
    bands = find_bands(rgba[:, :, 3], keep=len(sizes))

    results: list[tuple[str, Image.Image]] = []
    if len(bands) != len(sizes):
        print(
            f"    ⚠ {src.name}: found {len(bands)} widget band(s), expected {len(sizes)} "
            f"— naming by index instead.",
            file=sys.stderr,
        )
        names = [f"{base_name}-{i + 1}" for i in range(len(bands))]
        ratios = [None] * len(bands)
    else:
        names = [f"{base_name}-{s}" for s in sizes]
        ratios = expected_ratios

    for (y0, y1), name, expected in zip(bands, names, ratios):
        cut = tight_crop(rgba, y0, y1)
        im = Image.fromarray(cut)
        if expected is not None:
            actual = im.width / im.height
            if abs(actual - expected) / expected > ASPECT_TOLERANCE:
                print(
                    f"    ⚠ {name}: aspect {actual:.2f} differs from expected "
                    f"{expected:.2f} — band→size mapping may be wrong.",
                    file=sys.stderr,
                )
        results.append((name, im))
    return results


def process_locale(source_root: Path, out_root: Path, locale: str, make_preview: bool) -> int:
    src_dir = source_root / locale
    if not src_dir.is_dir():
        print(f"  – {locale}: no source folder, skipping.", file=sys.stderr)
        return 0

    out_dir = out_root / locale
    cutouts: list[tuple[str, Image.Image]] = []
    for suffix, base_name, sizes, ratios in SOURCES:
        matches = sorted(src_dir.glob(f"*{suffix}"))
        if not matches:
            print(f"  – {locale}: no '*{suffix}' source, skipping.", file=sys.stderr)
            continue
        cutouts.extend(process_source(matches[0], base_name, sizes, ratios))

    if not cutouts:
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    for name, im in cutouts:
        assert_transparent(im, f"{locale}/{name}")
        im.save(out_dir / f"{name}.png")

    if make_preview:
        preview = build_preview([im for _, im in cutouts])
        preview.save(out_dir / "_preview.png")

    print(f"  ✓ {locale}: {len(cutouts)} widget(s) → {out_dir}/")
    return len(cutouts)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", default="screenshots", help="input root (default: screenshots)")
    parser.add_argument("--out", default="screenshots-widgets", help="output root (default: screenshots-widgets)")
    parser.add_argument("--locales", default=",".join(DEFAULT_LOCALES), help="comma-separated locale list")
    parser.add_argument("--no-preview", action="store_true", help="skip the _preview.png composites")
    args = parser.parse_args()

    source_root = (repo_root / args.source).resolve() if not Path(args.source).is_absolute() else Path(args.source)
    out_root = (repo_root / args.out).resolve() if not Path(args.out).is_absolute() else Path(args.out)
    locales = [l.strip() for l in args.locales.split(",") if l.strip()]

    if not source_root.is_dir():
        sys.exit(f"Source folder not found: {source_root} (run scripts/screenshots.sh first)")

    print(f"Extracting transparent widgets from {source_root} → {out_root}")
    total = 0
    for locale in locales:
        total += process_locale(source_root, out_root, locale, make_preview=not args.no_preview)

    if total == 0:
        sys.exit("No widgets extracted — check that the source screenshots exist.")
    print(f"Done. {total} widget PNG(s) written to {out_root}/.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
