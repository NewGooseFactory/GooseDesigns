#!/usr/bin/env python3
"""Build the GooseDesigns montage banner (1280x640) from the newest mock PNGs.

Used as the README hero and as a drop-in social-preview / Open Graph card.
Idempotent: overwrites assets/banner.png each run with the latest mocks.
"""
import argparse
import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageOps

W, H = 1280, 640
BG = (11, 14, 20)          # near-black
PANEL = (16, 20, 28)
BORDER = (35, 42, 54)
INK = (233, 237, 243)
MUTED = (150, 160, 174)
ACCENT = (94, 234, 212)     # restrained teal, one accent

FONT_DIRS = [r"C:\Windows\Fonts", "/usr/share/fonts", "/Library/Fonts"]
BOLD_CANDIDATES = ["segoeuib.ttf", "SegoeUI-Bold.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf", "Arial Bold.ttf"]
REG_CANDIDATES = ["segoeui.ttf", "SegoeUI.ttf", "arial.ttf", "DejaVuSans.ttf", "Arial.ttf"]
MONO_CANDIDATES = ["consola.ttf", "Consolas.ttf", "cour.ttf", "DejaVuSansMono.ttf"]


def find_font(cands, size):
    for d in FONT_DIRS:
        for c in cands:
            p = os.path.join(d, c)
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    pass
    try:
        return ImageFont.truetype(cands[0], size)
    except Exception:
        return ImageFont.load_default()


def slug_of(stem):
    parts = stem.split("-")
    return "-".join(parts[4:]) if len(parts) > 4 else stem


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--attachments", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--count", type=int, default=6)
    args = ap.parse_args()

    pngs = [f for f in os.listdir(args.attachments) if f.lower().endswith(".png")]
    pngs = sorted(pngs, reverse=True)[: args.count]
    if not pngs:
        print("no pngs found", file=sys.stderr)
        return 1

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    f_title = find_font(BOLD_CANDIDATES, 70)
    f_tag = find_font(REG_CANDIDATES, 27)
    f_kick = find_font(BOLD_CANDIDATES, 19)
    f_label = find_font(MONO_CANDIDATES, 17)

    pad = 40
    band_h = 196

    # kicker
    kick = "DAILY DESIGN MONTAGE"
    d.text((pad, 40), kick, font=f_kick, fill=ACCENT)
    # title
    d.text((pad - 2, 66), "GooseDesigns", font=f_title, fill=INK)
    # tagline
    tag = "Hero & landing UIs for trending GitHub repos \u2014 AI, agents, dev tools \u2014 reimagined every morning."
    d.text((pad, 150), tag, font=f_tag, fill=MUTED)

    # grid 3x2
    cols, rows = 3, 2
    gap = 16
    grid_top = band_h
    grid_w = W - 2 * pad
    grid_h = H - band_h - pad
    cw = (grid_w - (cols - 1) * gap) // cols
    ch = (grid_h - (rows - 1) * gap) // rows

    for i, fn in enumerate(pngs):
        r, c = divmod(i, cols)
        x = pad + c * (cw + gap)
        y = grid_top + r * (ch + gap)
        try:
            thumb = Image.open(os.path.join(args.attachments, fn)).convert("RGB")
            thumb = ImageOps.fit(thumb, (cw, ch), method=Image.LANCZOS, centering=(0.5, 0.0))
        except Exception:
            thumb = Image.new("RGB", (cw, ch), PANEL)
        img.paste(thumb, (x, y))
        # border
        d.rectangle([x, y, x + cw - 1, y + ch - 1], outline=BORDER, width=1)
        # label strip
        label = slug_of(os.path.splitext(fn)[0])
        strip_h = 30
        strip = Image.new("RGBA", (cw, strip_h), (8, 10, 14, 205))
        img.paste(strip, (x, y + ch - strip_h), strip)
        d.text((x + 12, y + ch - strip_h + 7), label, font=f_label, fill=(206, 214, 224))

    # accent hairline under band
    d.line([(pad, band_h - 6), (W - pad, band_h - 6)], fill=BORDER, width=1)
    d.line([(pad, band_h - 6), (pad + 120, band_h - 6)], fill=ACCENT, width=2)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    img.save(args.out, "PNG", optimize=True)
    print(f"banner -> {args.out} ({W}x{H}) from {len(pngs)} mocks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
