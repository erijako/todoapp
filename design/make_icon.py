"""Onestep app icon: "the warm stone" (brand concept C1). A stepping stone with a warm
light inside, on calm water. Writes light and dark 1024px icons.
Run: python3 design/make_icon.py"""
import numpy as np
from PIL import Image, ImageDraw

S = 2048            # render size (downsampled to 1024)
K = S / 180         # design grid is 180x180 (same as the canvas mockup)
DIR = "TodoApp/Assets.xcassets/AppIcon.appiconset/"

def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)

def cubic(p0, p1, p2, p3, n=60):
    t = np.linspace(0, 1, n)[:, None]
    return ((1 - t) ** 3) * p0 + 3 * ((1 - t) ** 2) * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3

def stone_polygon():
    P = lambda x, y: np.array([x, y], dtype=float)
    segs = [
        (P(48, 104), P(48, 80), P(67, 64), P(91, 64)),
        (P(91, 64), P(115, 64), P(132, 79), P(132, 100)),
        (P(132, 100), P(132, 115), P(115, 121), P(91, 121)),
        (P(91, 121), P(67, 121), P(48, 119), P(48, 104)),
    ]
    pts = np.vstack([cubic(*s) for s in segs]) * K
    return [tuple(p) for p in pts]

yy, xx = np.mgrid[0:S, 0:S].astype(float)

def vertical(top, bottom):
    t = (yy / (S - 1))[..., None]
    return hexc(top) * (1 - t) + hexc(bottom) * t

def radial(cx, cy, rx, ry, stops):
    """Elliptical gradient. stops: [(offset, hex, alpha)] -> (rgb, alpha)."""
    d = np.clip(np.sqrt(((xx - cx * K) / (rx * K)) ** 2 + ((yy - cy * K) / (ry * K)) ** 2), 0, 1)
    rgb = np.zeros((S, S, 3)); a = np.zeros((S, S))
    for (o0, c0, a0), (o1, c1, a1) in zip(stops, stops[1:]):
        m = (d >= o0) & (d <= o1)
        t = ((d - o0) / max(o1 - o0, 1e-6))[m][:, None]
        rgb[m] = hexc(c0) * (1 - t) + hexc(c1) * t
        a[m] = a0 * (1 - t[:, 0]) + a1 * t[:, 0]
    return rgb, a

def blend(base, rgb, alpha):
    return base * (1 - alpha[..., None]) + rgb * alpha[..., None]

def mask(draw_fn):
    m = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(m))
    return np.asarray(m, dtype=float) / 255

def ripple(d):
    w = 3 * K
    d.ellipse([(90 - 62) * K, (116 - 15) * K, (90 + 62) * K, (116 + 15) * K], outline=255, width=round(w))

stone = mask(lambda d: d.polygon(stone_polygon(), fill=255))
ring = mask(ripple)
# Core light: centred at 45%/45% of the stone's bounding box (48..132 x 64..121)
cx, cy, rx, ry = 48 + 0.45 * 84, 64 + 0.45 * 57, 42, 28.5

def light():
    img = vertical("8C97EE", "4F5FCC")
    img = blend(img, hexc("FFFFFF"), ring * 0.22)
    core, _ = radial(cx, cy, rx, ry, [(0, "F6B58C", 1), (0.55, "FCE3D2", 1), (1, "FFFFFF", 1)])
    return blend(img, core, stone)

def dark():
    img = vertical("2B3050", "141622")
    glow, ga = radial(90, 96, 76, 52, [(0, "F6B58C", 0.45), (1, "F6B58C", 0)])
    img = blend(img, glow, ga)
    img = blend(img, hexc("9AA5F2"), ring * 0.25)
    core, _ = radial(cx, cy, rx, ry, [(0, "F6B58C", 1), (0.6, "FCE3D2", 1), (1, "FFF6EF", 1)])
    return blend(img, core, stone)

for name, fn in (("AppIcon.png", light), ("AppIcon-Dark.png", dark)):
    out = Image.fromarray(np.clip(fn(), 0, 255).astype("uint8"), "RGB")
    out.resize((1024, 1024), Image.LANCZOS).save(DIR + name)
    print("wrote", DIR + name)
