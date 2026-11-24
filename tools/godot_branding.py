"""Gullhaven HD-2D: the logo, icon, boot splash and store art (itch.io and Steam).
Usage: python3 tools/godot_branding.py      (needs pillow, numpy and fonttools with brotli)

Writes:
  godot/art/ui/logo.png        the GULLHAVEN title logo at pixel scale (the game scales it up)
  godot/art/ui/splash.png      the logo at 4x for Godot's boot splash
  godot/icon.png               the 256 px game icon (window, dock, taskbar)
  store/itch_cover.png         630 x 500 cover for the itch.io page
  store/steam_header.png       920 x 430 header capsule for a Steam page
  store/steam_capsule.png      616 x 353 small/main capsule for a Steam page
  store/steam_library.png      600 x 900 library capsule for a Steam page
The store art is a little pixel-art scene drawn from the game's own sprites: a dawn
harbour, the lighthouse, you on the dock with a line out, and a cat."""
import io
import os

import numpy as np
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
G = os.path.join(ROOT, 'godot')
FONT = os.path.join(G, 'art', 'fonts', 'pixelify_sans_bold.woff2')

OUTLINE = (28, 20, 48, 255)
SHADOW = (10, 48, 80, 255)
FILL = [(255, 246, 220), (255, 233, 168), (255, 214, 92), (255, 196, 62), (244, 164, 48), (226, 124, 42)]
GULL = ['..##.....##..',
        '.#..#...#..#.',
        '#....#.#....#',
        '......#......']


def font(size):
    f = TTFont(FONT)
    f.flavor = None
    buf = io.BytesIO()
    f.save(buf)
    buf.seek(0)
    return ImageFont.truetype(buf, size)


def dilate(mask, n=1):
    out = mask.copy()
    for _ in range(n):
        m = out.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                m |= np.roll(np.roll(out, dy, 0), dx, 1)
        out = m
    return out


def text_mask(text, size, pad=6):
    f = font(size)
    probe = Image.new('L', (size * len(text) + 40, size * 3))
    ImageDraw.Draw(probe).text((pad, pad), text, font=f, fill=255)
    a = np.array(probe) > 110
    ys, xs = np.nonzero(a)
    return a[ys.min() - pad:ys.max() + pad + 1, xs.min() - pad:xs.max() + pad + 1]


def logo():
    """The title logo at pixel scale: gradient letters, an outline, a sea-blue drop shadow,
    a gull overhead and a wave underneath."""
    m = text_mask('GULLHAVEN', 24, pad=4)
    h, w = m.shape
    H = h + 12
    img = np.zeros((H, w + 4, 4), np.uint8)
    top = 7
    letters = np.zeros((H, w + 4), bool)
    letters[top:top + h, 2:2 + w] = m
    outline = dilate(letters, 1)
    shadow = np.roll(np.roll(outline, 2, 0), 1, 1) & ~outline
    img[shadow] = SHADOW
    img[outline] = OUTLINE
    ys, xs = np.nonzero(letters)
    y0, y1 = ys.min(), ys.max()
    for y, x in zip(ys, xs):
        k = (y - y0) / max(1, y1 - y0)
        img[y, x, :3] = FILL[min(len(FILL) - 1, int(k * len(FILL)))]
        img[y, x, 3] = 255
    # a light edge along the top of each stroke
    edge = letters & ~np.roll(letters, 1, 0)
    img[edge] = (255, 252, 240, 255)
    # the gull, over the gap between the L's and the H
    gx = int(w * 0.43)
    for r, row in enumerate(GULL):
        for c, ch in enumerate(row):
            if ch == '#':
                img[1 + r, gx + c] = (250, 250, 245, 255)
    gull = np.zeros(img.shape[:2], bool)
    gull[1:5, gx:gx + 13] = img[1:5, gx:gx + 13, 3] > 0
    ring = dilate(gull, 1) & ~gull & (img[..., 3] == 0)
    img[ring] = OUTLINE
    # a wave under the word
    for x in range(4, w):
        y = H - 3 + int(round(np.sin(x / 3.2) * 1.0))
        if img[y, x, 3] == 0:
            img[y, x] = (110, 200, 236, 255)
        if y + 1 < H and img[y + 1, x, 3] == 0:
            img[y + 1, x] = (40, 110, 170, 255)
    return Image.fromarray(img, 'RGBA')


def sprite(path, col, row, fw, fh):
    sheet = Image.open(os.path.join(G, path)).convert('RGBA')
    return sheet.crop((col * fw, row * fh, (col + 1) * fw, (row + 1) * fh))


def scene(w, h, char_x, horizon_k=0.5):
    """A dawn harbour at pixel scale (w x h)."""
    rng = np.random.default_rng(7)
    img = Image.new('RGBA', (w, h))
    px = img.load()
    hz = int(h * horizon_k)
    sky = [(40, 52, 110), (88, 84, 150), (190, 120, 150), (246, 170, 130), (255, 214, 150)]
    for y in range(hz):
        k = y / max(1, hz - 1) * (len(sky) - 1)
        i = min(int(k), len(sky) - 2)
        f = k - i
        c = tuple(int(sky[i][j] * (1 - f) + sky[i + 1][j] * f) for j in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(img)
    # the sun, half up
    sx = int(w * 0.32)
    d.ellipse((sx - 14, hz - 14, sx + 14, hz + 14), fill=(255, 236, 170, 255))
    d.ellipse((sx - 10, hz - 10, sx + 10, hz + 10), fill=(255, 248, 210, 255))
    # far islands
    for ix, iw, ih in ((int(w * 0.62), 26, 5), (int(w * 0.08), 18, 3)):
        d.polygon([(ix, hz), (ix + iw // 3, hz - ih), (ix + iw * 2 // 3, hz - ih + 1), (ix + iw, hz)], fill=(84, 70, 110, 255))
    # the sea
    sea = [(232, 170, 140), (96, 120, 170), (54, 96, 150), (34, 72, 124), (24, 54, 100)]
    for y in range(hz, h):
        k = (y - hz) / max(1, h - hz - 1) * (len(sea) - 1)
        i = min(int(k), len(sea) - 2)
        f = k - i
        c = tuple(int(sea[i][j] * (1 - f) + sea[i + 1][j] * f) for j in range(3))
        for x in range(w):
            px[x, y] = c + (255,)
    # sun glitter and wave lines
    for _ in range(int(w * h * 0.012)):
        x = int(rng.normal(sx, w * 0.07))
        y = int(rng.uniform(hz + 1, h))
        if 0 <= x < w - 3:
            d.line((x, y, x + int(rng.integers(1, 4)), y), fill=(255, 226, 170, 255))
    for _ in range(int(w * h * 0.006)):
        x = int(rng.uniform(0, w - 4))
        y = int(rng.uniform(hz + 3, h))
        d.line((x, y, x + 3, y), fill=(120, 170, 210, 255))
    # the lighthouse on its rocks
    lx = int(w * 0.8)
    base = hz + 6
    d.polygon([(lx - 16, base + 4), (lx - 10, base - 3), (lx + 9, base - 4), (lx + 18, base + 4)], fill=(70, 62, 78, 255))
    d.polygon([(lx - 5, base - 2), (lx - 3, base - 34), (lx + 3, base - 34), (lx + 5, base - 2)], fill=(240, 236, 226, 255))
    for k in range(3):
        y = base - 8 - k * 9
        d.rectangle((lx - 5 + (k + 1) // 2, y - 3, lx + 4 - (k + 1) // 2, y), fill=(200, 64, 56, 255))
    d.rectangle((lx - 4, base - 40, lx + 3, base - 35), fill=(255, 220, 120, 255))
    d.polygon([(lx - 5, base - 40), (lx, base - 45), (lx + 4, base - 40)], fill=(60, 50, 70, 255))
    beam = Image.new('RGBA', (w, h))
    ImageDraw.Draw(beam).polygon([(lx + 3, base - 39), (w, base - 50), (w, base - 30)], fill=(255, 236, 170, 46))
    img.alpha_composite(beam)
    # gulls
    for gx, gy in ((int(w * 0.18), int(h * 0.3)), (int(w * 0.52), int(h * 0.22)), (int(w * 0.6), int(h * 0.28))):
        d.line((gx - 3, gy - 1, gx, gy + 1), fill=(250, 250, 245, 255))
        d.line((gx, gy + 1, gx + 3, gy - 1), fill=(250, 250, 245, 255))
    # the dock
    dock_y = h - 22
    d.rectangle((0, dock_y, char_x + 18, dock_y + 4), fill=(140, 96, 60, 255))
    d.line((0, dock_y, char_x + 18, dock_y), fill=(186, 136, 88, 255))
    for x in range(0, char_x + 18, 6):
        d.line((x, dock_y + 1, x, dock_y + 4), fill=(110, 74, 46, 255))
    for x in range(4, char_x + 18, 14):
        d.rectangle((x, dock_y + 5, x + 2, h), fill=(96, 64, 40, 255))
    # you, casting off the end, and a cat watching
    you = sprite('art/chars2/player.png', 3, 3, 32, 48)
    img.alpha_composite(you, (char_x - 16, dock_y - 46))
    cat = sprite('art/cats2/calico.png', 3, 3, 32, 32)
    img.alpha_composite(cat, (char_x - 46, dock_y - 30))
    tip = (char_x + 12, dock_y - 40)
    float_at = (min(w - 10, char_x + 52), dock_y + 10)
    pts = [(tip[0] + (float_at[0] - tip[0]) * t / 20, tip[1] + (float_at[1] - tip[1]) * t / 20 - 10 * np.sin(np.pi * t / 20))
           for t in range(21)]
    d.line(pts, fill=(240, 240, 230, 200))
    d.rectangle((float_at[0] - 1, float_at[1] - 2, float_at[0] + 1, float_at[1]), fill=(230, 60, 50, 255))
    d.line((float_at[0] - 4, float_at[1] + 2, float_at[0] + 4, float_at[1] + 2), fill=(170, 210, 236, 255))
    return img


def store_art(w, h, scale, horizon_k, char_x_k, logo_k):
    base_w, base_h = w // scale + 1, h // scale + 1
    img = scene(base_w, base_h, int(base_w * char_x_k), horizon_k)
    # draw the logo on top at the base scale, then scale everything up together
    lg = logo()
    if lg.width > base_w * logo_k:
        lg = lg.resize((int(lg.width * base_w * logo_k / lg.width), int(lg.height * base_w * logo_k / lg.width)), Image.NEAREST)
    img = img.copy()
    img.alpha_composite(lg, ((base_w - lg.width) // 2, int(base_h * 0.07)))
    big = img.resize((base_w * scale, base_h * scale), Image.NEAREST)
    return big.crop((0, 0, w, h))


def icon():
    """256 px: the lighthouse against a sunset disc, with a gull."""
    s = 32
    img = Image.new('RGBA', (s, s))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, s - 1, s - 1), 6, fill=(30, 40, 86, 255))
    d.ellipse((5, 5, 26, 26), fill=(246, 166, 120, 255))
    d.ellipse((8, 8, 23, 23), fill=(255, 210, 140, 255))
    d.rectangle((1, 20, s - 2, s - 2), fill=(34, 82, 138, 255))
    d.line((1, 20, s - 2, 20), fill=(130, 196, 230, 255))
    d.polygon([(12, 22), (13, 9), (18, 9), (19, 22)], fill=(244, 240, 230, 255))
    d.rectangle((13, 13, 18, 15), fill=(206, 66, 58, 255))
    d.rectangle((12, 18, 19, 20), fill=(206, 66, 58, 255))
    d.rectangle((13, 6, 18, 8), fill=(255, 224, 120, 255))
    d.polygon([(12, 6), (15, 3), (19, 6)], fill=(60, 50, 70, 255))
    d.polygon([(8, 22), (11, 20), (21, 20), (24, 22)], fill=(80, 70, 88, 255))
    for p in ((4, 10), (5, 11), (6, 11), (7, 10), (8, 11), (9, 11), (10, 10)):
        d.point(p, fill=(250, 250, 245, 255))
    d.line((4, 26, 8, 25), fill=(160, 214, 240, 255))
    d.line((22, 27, 27, 26), fill=(160, 214, 240, 255))
    return img.resize((256, 256), Image.NEAREST)


def main():
    os.makedirs(os.path.join(G, 'art', 'ui'), exist_ok=True)
    store = os.path.join(ROOT, 'store')
    os.makedirs(store, exist_ok=True)
    lg = logo()
    lg.save(os.path.join(G, 'art', 'ui', 'logo.png'))
    lg.resize((lg.width * 4, lg.height * 4), Image.NEAREST).save(os.path.join(G, 'art', 'ui', 'splash.png'))
    icon().save(os.path.join(G, 'icon.png'))
    store_art(630, 500, 4, 0.5, 0.42, 0.9).save(os.path.join(store, 'itch_cover.png'))
    store_art(920, 430, 4, 0.55, 0.3, 0.6).save(os.path.join(store, 'steam_header.png'))
    store_art(616, 353, 3, 0.55, 0.3, 0.7).save(os.path.join(store, 'steam_capsule.png'))
    store_art(600, 900, 4, 0.42, 0.55, 0.9).save(os.path.join(store, 'steam_library.png'))
    print('logo %dx%d, icon, splash and store art written' % lg.size)


if __name__ == '__main__':
    main()
