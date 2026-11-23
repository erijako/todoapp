"""Generates the Onestep app icon (1024x1024, opaque). Run: python3 design/make_icon.py"""
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # draw large, downsample for smooth edges
OUT = "TodoApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))

top, bottom = (0x8C, 0x97, 0xEE), (0x4F, 0x5F, 0xCC)  # soft periwinkle -> accent
img = Image.new("RGB", (S, S))
px = ImageDraw.Draw(img)
for y in range(S):
    px.line([(0, y), (S, y)], fill=lerp(top, bottom, y / (S - 1)))

cx, cy, r = S / 2, S * 0.49, S * 0.29

# Soft shadow under the circle
shadow = Image.new("L", (S, S), 0)
ImageDraw.Draw(shadow).ellipse([cx - r, cy - r + S * 0.035, cx + r, cy + r + S * 0.035], fill=90)
shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.03))
img.paste((0x2E, 0x36, 0x8C), mask=shadow)

# The check circle
d = ImageDraw.Draw(img)
d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0xFF, 0xFF, 0xFF))

# Rounded checkmark
w = S * 0.062
pts = [(cx - r * 0.42, cy + r * 0.02), (cx - r * 0.10, cy + r * 0.33), (cx + r * 0.45, cy - r * 0.30)]
ink = (0x4F, 0x5F, 0xCC)
d.line(pts, fill=ink, width=round(w), joint="curve")
for x, y in (pts[0], pts[2], pts[1]):
    d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=ink)

img.resize((1024, 1024), Image.LANCZOS).save(OUT)
print("wrote", OUT)
