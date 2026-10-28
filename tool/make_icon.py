#!/usr/bin/env python3
"""Generate the group24 / «برنامهٔ درسی» app icon: an orange card with a weekly-schedule motif."""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 4096          # supersampled canvas
OUT = S // 4      # final size 1024

SAFFRON = (255, 114, 0)
SAFFRON_L = (255, 160, 45)
SAFFRON_D = (226, 92, 0)
PAPER = (247, 248, 239)
PIST = (100, 140, 22)
OLIVE = (71, 102, 0)
LINE = (226, 229, 213)
INK = (43, 53, 32)


def gradient_bg(size, top=SAFFRON_L, bottom=SAFFRON_D):
    img = Image.new('RGB', (size, size), top)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c)
    return img


def star_points(cx, cy, r_out, r_in, points=8, rot=0.0):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / points
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def draw_star(d, cx, cy, r_out, r_in, fill, points=8, rot=0.0):
    d.polygon(star_points(cx, cy, r_out, r_in, points, rot), fill=fill)


def draw_gear(d, cx, cy, r_out, fill, teeth=8, rot=0.0, hole=None):
    """چرخ‌دندهٔ ساده: حلقهٔ دندانه‌دار با سوراخ وسط."""
    r_root = r_out * 0.76
    step = 2 * math.pi / teeth
    pts = []
    for i in range(teeth):
        a = rot + i * step
        # پایهٔ دندانه → سر دندانه → سر دندانه → پایهٔ دندانهٔ بعدی
        pts.append((cx + r_root * math.cos(a - step * 0.30), cy + r_root * math.sin(a - step * 0.30)))
        pts.append((cx + r_out * math.cos(a - step * 0.17), cy + r_out * math.sin(a - step * 0.17)))
        pts.append((cx + r_out * math.cos(a + step * 0.17), cy + r_out * math.sin(a + step * 0.17)))
        pts.append((cx + r_root * math.cos(a + step * 0.30), cy + r_root * math.sin(a + step * 0.30)))
        pts.append((cx + r_root * math.cos(a + step * 0.50), cy + r_root * math.sin(a + step * 0.50)))
    d.polygon(pts, fill=fill)
    if hole is not None:
        hr = r_out * 0.38
        d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=hole)


def make(full_bleed: bool):
    img = gradient_bg(S) if full_bleed else Image.new('RGBA', (S, S), (0, 0, 0, 0))
    if not full_bleed:
        img = img.convert('RGB')
        img = Image.new('RGB', (S, S), SAFFRON)
        # transparent version handled separately below
    return img


def build(transparent: bool) -> Image.Image:
    if transparent:
        base = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    else:
        base = gradient_bg(S).convert('RGBA')
        # decorative faint star bottom-start corner
        deco = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        dd = ImageDraw.Draw(deco)
        draw_star(dd, int(S * 0.16), int(S * 0.86), int(S * 0.42), int(S * 0.19), (255, 255, 255, 26))
        base = Image.alpha_composite(base, deco)

    d = ImageDraw.Draw(base)

    # scale: adaptive foreground needs content inside the safe zone (~66% circle)
    scale = 0.60 if transparent else 0.72
    cw = int(S * scale)              # card width
    ch = int(cw * 1.10)              # card height
    cx, cy = S // 2, S // 2
    left, top = cx - cw // 2, cy - ch // 2
    right, bottom = left + cw, top + ch
    rad = int(cw * 0.16)

    # soft shadow
    if not transparent:
        sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle(
            [left + int(cw * 0.02), top + int(ch * 0.035), right + int(cw * 0.02), bottom + int(ch * 0.035)],
            radius=rad, fill=(120, 48, 0, 105))
        base = Image.alpha_composite(base, sh.filter(ImageFilter.GaussianBlur(S * 0.012)))
        d = ImageDraw.Draw(base)

    # card
    d.rounded_rectangle([left, top, right, bottom], radius=rad, fill=(255, 255, 255, 255))

    # header strip (binder) — saffron, clipped to the card's rounded top
    header = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(header)
    hd.rounded_rectangle([left, top, right, bottom], radius=rad, fill=(255, 255, 255, 255))
    hd.rectangle([left, top + int(ch * 0.13), right, bottom], fill=(0, 0, 0, 0))
    hdr = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(hdr).rounded_rectangle([left, top, right, top + int(ch * 0.20)], radius=rad, fill=SAFFRON + (255,))
    ImageDraw.Draw(hdr).rectangle([left, top + int(ch * 0.12), right, top + int(ch * 0.20)], fill=SAFFRON + (255,))
    base = Image.alpha_composite(base, hdr)
    d = ImageDraw.Draw(base)

    # binder rings on the header
    ring_y = top + int(ch * 0.075)
    ring_r = int(cw * 0.028)
    for fx in (0.30, 0.50, 0.70):
        rx = left + int(cw * fx)
        d.ellipse([rx - ring_r, ring_y - ring_r, rx + ring_r, ring_y + ring_r], fill=(255, 255, 255, 235))

    # schedule rows: colored subject chip + two lines
    rows = [(PIST, 0.62), (SAFFRON, 0.48), (OLIVE, 0.72)]
    row_h = int(ch * 0.075)
    gap = int(ch * 0.055)
    y = top + int(ch * 0.28)
    for color, frac in rows:
        chip = row_h
        d.rounded_rectangle([left + int(cw * 0.07), y, left + int(cw * 0.07) + chip, y + chip],
                            radius=int(chip * 0.30), fill=color + (255,))
        # bars are right-aligned (RTL reading direction)
        bar_r = right - int(cw * 0.07)
        bar_l = bar_r - int(cw * 0.58)
        d.rounded_rectangle([bar_l, y + int(chip * 0.10), bar_r, y + int(chip * 0.42)],
                            radius=int(chip * 0.16), fill=INK + (235,))
        bar_l2 = bar_r - int(cw * 0.50)
        d.rounded_rectangle([bar_l2, y + int(chip * 0.54), bar_r, y + int(chip * 0.86)],
                            radius=int(chip * 0.16), fill=LINE + (255,))
        y += row_h + gap

    # bottom accent: saffron gear (settings) on the card's lower corner
    sr = int(cw * 0.17)
    sx, sy = right - int(cw * 0.055) - sr, bottom - int(ch * 0.015) - sr
    draw_gear(d, sx, sy, sr, SAFFRON + (255,), teeth=8, rot=math.pi / 8, hole=(255, 255, 255, 255))

    return base


for name, transp in (('assets/icon/icon.png', False), ('assets/icon/icon_fg.png', True)):
    out = build(transp)
    out = out.convert('RGBA' if transp else 'RGB')
    out.resize((OUT, OUT), Image.LANCZOS).save(name)
    print('wrote', name)

# quick 64px legibility preview
build(False).convert('RGB').resize((64, 64), Image.LANCZOS).resize((256, 256), Image.NEAREST).save('/tmp/icon_preview_64.png')
print('preview /tmp/icon_preview_64.png')
