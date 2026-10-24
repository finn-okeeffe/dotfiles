#!/usr/bin/env python3
"""Make subtle, low-contrast terminal backgrounds in the Gruvbox Dark Hard palette.

    gruvbox-bg.py generate [--outdir DIR] [--strength N]
        Draw the built-in designs (moon, cat, sun, contours).

    gruvbox-bg.py convert INPUT OUTPUT [--strength N] [--tint NAME] [--invert]
        Turn any picture into a faint, Gruvbox-tinted background.

Every image is pre-blended onto the terminal background (#1d2021), so Rio can
show it at opacity 1.0 and the strength argument alone controls the contrast.
"""

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

WIDTH, HEIGHT = 2560, 1440
SS = 2  # Supersampling factor for anti-aliased shapes.

BG = (0x1D, 0x20, 0x21)
SHADOW = (0x0A, 0x0B, 0x0B)
TINTS = {
    # Darkens instead of lightening, so text keeps full contrast over the image.
    # Needs a higher --strength (around 4-6) to show, as there is little room below BG.
    "shadow": SHADOW,
    "fg": (0xD5, 0xC4, 0xA1),
    "yellow": (0xFA, 0xBD, 0x2F),
    "orange": (0xFE, 0x80, 0x19),
    "aqua": (0x8E, 0xC0, 0x7C),
    "blue": (0x83, 0xA5, 0x98),
    "purple": (0xD3, 0x86, 0x9B),
}


def mix(colour, amount, base=BG):
    """Blend `amount` of `colour` into `base`."""
    return tuple(round(b + (c - b) * amount) for b, c in zip(base, colour))


def canvas():
    return Image.new("RGB", (WIDTH * SS, HEIGHT * SS), BG)


def finish(img):
    """Downsample and add faint grain so flat areas and gradients do not band."""
    img = img.resize((WIDTH, HEIGHT), Image.LANCZOS)
    noise = Image.effect_noise((WIDTH, HEIGHT), 1.0).convert("RGB")
    return ImageChops.add(img, noise, scale=1.0, offset=-128)


def disc(draw, cx, cy, r, fill):
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=fill)


def moon_disc(img, cx, cy, r, s, rng):
    """A pale disc with a few soft craters, returned with its mask for clipping."""
    draw = ImageDraw.Draw(img)
    disc(draw, cx, cy, r, mix(TINTS["fg"], 0.06 * s))
    for _ in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.15, 0.8) * r
        cr = rng.uniform(0.04, 0.11) * r
        disc(draw, cx + d * math.cos(a), cy + d * math.sin(a) * 0.7 - 0.2 * r, cr,
             mix(TINTS["fg"], 0.035 * s))
    mask = Image.new("L", img.size, 0)
    disc(ImageDraw.Draw(mask), cx, cy, r, 255)
    return mask


def ridge(rng, x0, x1, base_y, height, steps):
    """A jagged mountain outline from x0 to x1."""
    pts = []
    for i in range(steps + 1):
        x = x0 + (x1 - x0) * i / steps
        y = base_y - height * (0.35 + 0.65 * abs(math.sin(i * 1.7 + rng.uniform(-0.4, 0.4))))
        pts.append((x, y))
    return pts


def pine(draw, x, ground, h, fill):
    w = h * 0.38
    for tier in range(4):
        top = ground - h + tier * h * 0.18
        bottom = top + h * 0.42
        half = w * (0.45 + tier * 0.18)
        draw.polygon([(x, top), (x - half, bottom), (x + half, bottom)], fill=fill)
    draw.rectangle((x - w * 0.06, ground - h * 0.12, x + w * 0.06, ground), fill=fill)


def design_moon(s, rng):
    img = canvas()
    cx, cy, r = WIDTH * SS * 0.5, HEIGHT * SS * 0.46, 420 * SS
    mask = moon_disc(img, cx, cy, r, s, rng)

    # Paint the landscape on a copy, then keep only the part inside the moon.
    scene = img.copy()
    draw = ImageDraw.Draw(scene)
    far = ridge(rng, cx - r, cx + r, cy + r * 0.35, r * 0.45, 9)
    draw.polygon(far + [(cx + r, cy + r), (cx - r, cy + r)], fill=mix(TINTS["blue"], 0.03 * s))
    near = ridge(rng, cx - r, cx + r, cy + r * 0.65, r * 0.3, 7)
    draw.polygon(near + [(cx + r, cy + r), (cx - r, cy + r)], fill=mix(SHADOW, 0.25 * s))
    for i in range(11):
        x = cx - r + (i + rng.uniform(0.2, 0.8)) * (2 * r / 11)
        pine(draw, x, cy + r, rng.uniform(0.22, 0.42) * r, mix(SHADOW, 0.4 * s))
    img.paste(scene, mask=mask)
    return finish(img)


def design_cat(s, rng):
    img = canvas()
    cx, cy, r = WIDTH * SS * 0.5, HEIGHT * SS * 0.45, 430 * SS
    mask = moon_disc(img, cx, cy, r, s, rng)
    cat = mix(SHADOW, 0.4 * s)

    # A rounded hilltop, clipped to the moon.
    scene = img.copy()
    ImageDraw.Draw(scene).ellipse((cx - r * 1.6, cy + r * 0.55, cx + r * 1.6, cy + r * 2.2), fill=cat)
    img.paste(scene, mask=mask)

    cat_from_behind(ImageDraw.Draw(img), cx - r * 0.08, cy + r * 0.6, r, cat)
    return finish(img)


def cat_from_behind(draw, gx, gy, r, fill):
    """A sitting cat seen from behind, its feet at (gx, gy); `r` sets the scale."""
    draw.ellipse((gx - r * 0.25, gy - r * 0.36, gx + r * 0.25, gy + r * 0.02), fill=fill)  # haunches
    draw.ellipse((gx - r * 0.17, gy - r * 0.6, gx + r * 0.17, gy - r * 0.12), fill=fill)  # chest
    hx, hy, hr = gx + r * 0.01, gy - r * 0.68, r * 0.135
    draw.ellipse((hx - hr * 1.1, hy - hr, hx + hr * 1.1, hy + hr), fill=fill)
    for side in (-1, 1):
        draw.polygon([(hx + side * hr * 0.2, hy - hr * 0.7),
                      (hx + side * hr * 1.05, hy - hr * 0.25),
                      (hx + side * hr * 0.8, hy - hr * 1.6)], fill=fill)
    # Tail curling out along the ground and up at the tip.
    tail = []
    for i in range(25):
        t = i / 24
        tail.append((gx + r * (0.18 + 0.3 * t), gy - r * (0.03 + 0.25 * t ** 3)))
    draw.line(tail, fill=fill, width=int(r * 0.055), joint="curve")
    disc(draw, *tail[-1], r * 0.0275, fill)


def design_sun(s, rng):
    img = canvas()
    cx, cy, r = WIDTH * SS * 0.5, HEIGHT * SS * 0.48, 400 * SS

    sun = canvas()
    draw = ImageDraw.Draw(sun)
    top, bottom = mix(TINTS["yellow"], 0.06 * s), mix(TINTS["orange"], 0.055 * s)
    for y in range(int(cy - r), int(cy + r) + 1):
        t = (y - (cy - r)) / (2 * r)
        draw.line((0, y, WIDTH * SS, y), fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    mask = Image.new("L", img.size, 0)
    mdraw = ImageDraw.Draw(mask)
    disc(mdraw, cx, cy, r, 255)
    # Horizontal cuts that thicken towards the horizon.
    y, gap = cy + r * 0.08, r * 0.02
    while y < cy + r:
        mdraw.rectangle((0, y, WIDTH * SS, y + gap), fill=0)
        y += gap + r * 0.11
        gap *= 1.45
    img.paste(sun, mask=mask)

    draw = ImageDraw.Draw(img)
    line = mix(TINTS["fg"], 0.03 * s)
    horizon = cy + r * 0.98
    draw.line((cx - r * 1.9, horizon, cx + r * 1.9, horizon), fill=line, width=2 * SS)
    for i in range(1, 6):
        y = horizon + (i ** 1.6) * r * 0.05
        half = r * (1.9 + i * 0.25)
        draw.line((cx - half, y, cx + half, y), fill=line, width=SS)
    return finish(img)


def design_contours(s, rng):
    # Smooth height field: a sum of random Gaussian hills, sampled coarsely.
    gw, gh = 320, 180
    hills = [(rng.uniform(-0.1, 1.1), rng.uniform(-0.1, 1.1),
              rng.uniform(0.08, 0.3), rng.uniform(-1, 1)) for _ in range(16)]
    field = Image.new("F", (gw, gh))
    field.putdata([
        sum(a * math.exp(-((x / gw - hx) ** 2 + ((y / gh - hy) * 0.5625) ** 2) / (2 * w * w))
            for hx, hy, w, a in hills)
        for y in range(gh) for x in range(gw)
    ])
    mw, mh = WIDTH // 2, HEIGHT // 2
    values = list(field.resize((mw, mh), Image.BICUBIC).get_flattened_data())

    # Draw iso lines with an even width: the distance to the nearest level is
    # its offset in level units divided by the local gradient. Every fifth is heavier.
    lines = 32
    lo, hi = min(values), max(values)
    t = [(v - lo) / (hi - lo) * lines for v in values]
    maj, mnr = [0] * len(t), [0] * len(t)
    for i, ti in enumerate(t):
        x, y = i % mw, i // mw
        gx = t[i + 1] - ti if x < mw - 1 else ti - t[i - 1]
        gy = t[i + mw] - ti if y < mh - 1 else ti - t[i - mw]
        level = round(ti)
        dist = abs(ti - level) / max(math.hypot(gx, gy), 1e-6)
        heavy = level % 5 == 0
        ink = round(255 * min(1.0, max(0.0, (1.1 if heavy else 0.75) - dist)))
        (maj if heavy else mnr)[i] = ink
    major = Image.new("L", (mw, mh))
    minor = Image.new("L", (mw, mh))
    major.putdata(maj)
    minor.putdata(mnr)

    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    for layer, amount in ((minor, 0.035), (major, 0.06)):
        mask = layer.resize((WIDTH, HEIGHT), Image.BICUBIC).filter(ImageFilter.GaussianBlur(0.6))
        img.paste(Image.new("RGB", img.size, mix(TINTS["fg"], amount * s)), mask=mask)
    return finish(img.resize((WIDTH * SS, HEIGHT * SS)))


DESIGNS = {
    "moon": design_moon,
    "cat": design_cat,
    "sun": design_sun,
    "contours": design_contours,
}


def generate(args):
    outdir = Path(args.outdir).expanduser()
    outdir.mkdir(parents=True, exist_ok=True)
    for name, fn in DESIGNS.items():
        if args.only and name not in args.only:
            continue
        path = outdir / f"gruvbox-{name}.png"
        fn(args.strength, random.Random(args.seed)).save(path, optimize=True)
        print(path)


def convert(args):
    src = ImageOps.exif_transpose(Image.open(args.input)).convert("RGB")
    src = ImageOps.fit(src, (WIDTH, HEIGHT), Image.LANCZOS)
    if args.blur:
        src = src.filter(ImageFilter.GaussianBlur(args.blur))

    # Fade towards the edges so the picture sits behind the middle of the screen.
    vignette = Image.radial_gradient("L").resize((WIDTH, HEIGHT))
    vignette = ImageOps.invert(vignette).point(lambda v: min(255, v * 1.6))
    out = Image.new("RGB", (WIDTH, HEIGHT), BG)

    if args.color:
        # Keep the picture's own hues, muted, and lay the whole thing faintly over BG.
        src = ImageEnhance.Color(src).enhance(args.saturation)
        out.paste(src, mask=vignette.point(lambda v: round(v * 0.09 * args.strength)))
    else:
        lum = ImageOps.autocontrast(src.convert("L"), cutoff=1)
        if args.invert:
            lum = ImageOps.invert(lum)
        alpha = ImageChops.multiply(lum, vignette).point(lambda v: round(v * 0.1 * args.strength))
        out.paste(Image.new("RGB", out.size, TINTS[args.tint]), mask=alpha)
    finish(out.resize((WIDTH * SS, HEIGHT * SS))).save(args.output, optimize=True)
    print(args.output)


def main():
    global WIDTH, HEIGHT
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--size", default=f"{WIDTH}x{HEIGHT}", help="output size, WxH")
    sub = parser.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("generate", help="draw the built-in designs")
    g.add_argument("--outdir", default=Path(__file__).parent)
    g.add_argument("--strength", type=float, default=1.0, help="contrast multiplier (1.0 = default)")
    g.add_argument("--seed", type=int, default=7)
    g.add_argument("--only", nargs="*", choices=DESIGNS)
    g.set_defaults(func=generate)

    c = sub.add_parser("convert", help="make any image into a subtle background")
    c.add_argument("input")
    c.add_argument("output")
    c.add_argument("--strength", type=float, default=1.0, help="contrast multiplier (1.0 = default)")
    c.add_argument("--tint", default="fg", choices=TINTS)
    c.add_argument("--invert", action="store_true", help="use for dark subjects on light backgrounds")
    c.add_argument("--blur", type=float, default=0, help="soften fine detail (pixels)")
    c.add_argument("--color", action="store_true", help="keep the picture's own colours instead of one tint")
    c.add_argument("--saturation", type=float, default=0.6, help="with --color: 0 = grey, 1 = original")
    c.set_defaults(func=convert)

    args = parser.parse_args()
    WIDTH, HEIGHT = map(int, args.size.lower().split("x"))
    args.func(args)


if __name__ == "__main__":
    main()
