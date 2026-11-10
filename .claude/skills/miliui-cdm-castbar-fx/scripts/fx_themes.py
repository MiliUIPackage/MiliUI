#!/usr/bin/env python3
"""MiliUI_CooldownManager 施法條動畫材質第二、三批的貼圖：Media/fx-*.png，四十二張一次產。
第二批 ＝ 櫻花／青海波／天燈／客家花布／老花磚／珍珠奶茶／極光（二十張）；第三批 ＝ 紅葉／螢火蟲／錦鯉水波／夜市霓虹／藍白拖（二十二張）。

全部自己算、固定亂數種子、不帶別人的檔。七款都只用捲動的層（沒有序列圖）；花瓣、天燈、氣泡那幾張上下也接得起來
（引擎的捲動層可以帶直向分量 vy）。形狀（花瓣、天燈、牡丹、花磚、珍珠）用 Pillow 以 4 倍超取樣畫再縮回來。

    python3 .claude/skills/miliui-cdm-castbar-fx/scripts/fx_themes.py        # 在 repo 任何位置都可以

每張圖怎麼疊、捲多快登記在 AddOns/MiliUI_CooldownManager/Core/Media.lua 的 M.FX。第一批（宇宙星辰／閃電／熔岩／火焰）是同一個技能的 fx.py。
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
OUT = os.path.join(REPO, "AddOns", "MiliUI_CooldownManager", "Media")
W, H, SS = 512, 32, 4
TAU = math.pi * 2


def gnoise(shape, feats, rng):
    F = np.fft.fftn(rng.standard_normal(shape))
    k2 = 0
    for ax, (n, f) in enumerate(zip(shape, feats)):
        sh = [1] * len(shape); sh[ax] = n
        k2 = k2 + (np.fft.fftfreq(n).reshape(sh) * f) ** 2
    n = np.real(np.fft.ifftn(F * np.exp(-k2 * 4.0)))
    return (n - n.mean()) / (n.std() + 1e-9)


def fbm(shape, feats, rng, octaves=3, gain=0.5):
    out, amp = 0, 1.0
    for i in range(octaves):
        out = out + amp * gnoise(shape, [f / (2 ** i) for f in feats], rng)
        amp *= gain
    out = (out - out.mean()) / (out.std() + 1e-9)
    return np.clip(out * 0.22 + 0.5, 0, 1)


def ramp(t, stops):
    pos = np.array([s[0] for s in stops]); cols = np.array([s[1] for s in stops], dtype=float)
    return np.stack([np.interp(t, pos, cols[:, c]) for c in range(cols.shape[1])], axis=-1)


def save(a, name):
    if isinstance(a, Image.Image):
        im = a
    else:
        a = np.clip(a, 0, 255).round().astype(np.uint8)
        im = Image.fromarray(a, "RGBA" if a.shape[2] == 4 else "RGB")
    p = os.path.join(OUT, name)
    im.save(p, optimize=True)
    print("saved", os.path.relpath(p, REPO), im.size, os.path.getsize(p))


def canvas(color=(0, 0, 0, 0), w=W, h=H):
    return Image.new("RGBA", (w * SS, h * SS), color)


def down(im, bleed=None):
    """預乘後縮小（不然透明黑會滲進邊緣）；bleed ＝ 全透明像素填的顏色（遊戲的雙線性取樣才不會取到黑邊）"""
    out = im.convert("RGBa").resize((im.width // SS, im.height // SS), Image.LANCZOS).convert("RGBA")
    if bleed is not None:
        a = np.asarray(out).copy()
        a[a[..., 3] == 0, :3] = bleed
        out = Image.fromarray(a, "RGBA")
    return out


def stamp(dst, sprite, cx, cy, wrap_y=True):
    w, h = dst.size
    x0, y0 = int(round(cx - sprite.width / 2)), int(round(cy - sprite.height / 2))
    for ox in (-w, 0, w):
        for oy in ((-h, 0, h) if wrap_y else (0,)):
            x, y = x0 + ox, y0 + oy
            if x >= w or y >= h or x + sprite.width <= 0 or y + sprite.height <= 0:
                continue
            layer = Image.new("RGBA", dst.size, (0, 0, 0, 0))
            layer.paste(sprite, (x, y))
            dst.alpha_composite(layer)


def lens(cx, cy, length, width, angle, n=14):
    """葉片／花瓣形（兩端尖的梭形）的多邊形點"""
    pts = []
    ca, sa = math.cos(angle), math.sin(angle)
    for side in (1, -1):
        rng_ = range(n + 1) if side == 1 else range(n, -1, -1)
        for i in rng_:
            u = i / n
            x = (u - 0.5) * length
            y = side * width / 2 * math.sin(math.pi * u)
            pts.append((cx + x * ca - y * sa, cy + x * sa + y * ca))
    return pts


yy = np.arange(H)[:, None]
yb = 1 - yy / (H - 1)
satin = 0.88 + 0.12 * np.clip(1 - (yy / (H - 1)) / 0.5, 0, 1) ** 1.6

# ═════════ 櫻花 ═════════
rng = np.random.default_rng(31001); pr = random.Random(31001)
t = (yy / (H - 1)) * np.ones((H, W))
base = ramp(t, [(0, (248, 168, 192)), (1, (204, 96, 142))])
n = fbm((H, W), (30, 120), rng, 2)
base += (n - 0.5)[..., None] * np.array([26, 30, 22.0])
X, Y = np.meshgrid(np.arange(W), np.arange(H))
for _ in range(18):                                   # 柔焦光斑
    cx, cy, r, k = rng.uniform(0, W), rng.uniform(2, H - 2), rng.uniform(5, 10), rng.uniform(10, 24)
    dx = (X - cx + W / 2) % W - W / 2
    base += (np.exp(-(dx * dx + (Y - cy) ** 2) / (2 * (r * 0.6) ** 2)) * k)[..., None] * np.array([1.0, 0.9, 0.95])
save(base * satin[..., None], "fx-sakura-base.png")


def petal(size, angle, alpha, light):
    s = size * SS
    pad = 3
    im = Image.new("RGBA", (int(s) + pad * 2, int(s) + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = im.width / 2, im.height / 2
    w = s * 0.64
    d.polygon(lens(cx, cy, s, w, 0, 18), fill=(255, 178, 204, alpha))
    d.polygon(lens(cx - s * 0.05, cy, s * 0.72, w * 0.62, 0, 14), fill=(255, 226 + light, 236 + light // 2, alpha))
    d.polygon([(cx + s / 2 + 2, cy - w * 0.17), (cx + s * 0.27, cy), (cx + s / 2 + 2, cy + w * 0.17)], fill=(0, 0, 0, 0))   # 花瓣尖的缺口
    return im.rotate(math.degrees(angle), resample=Image.BICUBIC, expand=True)


for name, count, size, alpha in (("fx-sakura-petals-a.png", 44, (3.2, 4.6), 205), ("fx-sakura-petals-b.png", 15, (6.0, 8.4), 245)):
    c = canvas()
    for _ in range(count):
        c_ = petal(pr.uniform(*size), pr.uniform(0, TAU), alpha, pr.randint(0, 12))
        stamp(c, c_, pr.uniform(0, W * SS), pr.uniform(0, H * SS))
    save(down(c, (255, 200, 218)), name)

# ═════════ 青海波 ═════════
R = 16
c = canvas((20, 40, 98, 255))
d = ImageDraw.Draw(c)
LINE, FILL_A, FILL_B = (214, 226, 246, 255), (24, 48, 112, 255), (18, 36, 92, 255)
for j in range(-1, 8):                                  # 由上往下畫：下面那排蓋住上面那排
    cy = j * R / 2
    off = R if j % 2 else 0
    for i in range(-1, W // (2 * R) + 2):
        cx = i * 2 * R + off
        for k, rr in enumerate((1.0, 0.74, 0.48, 0.22)):
            r = R * rr
            d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=LINE)
            r2 = r - 1.25
            if r2 > 0:
                d.ellipse([(cx - r2) * SS, (cy - r2) * SS, (cx + r2) * SS, (cy + r2) * SS], fill=FILL_A if k % 2 == 0 else FILL_B)
a = np.asarray(down(c).convert("RGB"), dtype=float)
a *= (0.80 + 0.26 * yb)[..., None]                       # 上亮下暗
save(a, "fx-seigaiha-base.png")

# 波光／釉光：黑底加亮的一道斜光（青海波、花磚、花布共用）
xs = (X - 256 - (Y - 16) * 0.9)
sheen = np.exp(-(xs / 20.0) ** 2) * 0.42 + np.exp(-((xs - 46) / 7.0) ** 2) * 0.22
save((sheen[..., None] * np.array([255, 250, 235.0])), "fx-sheen.png")

# ═════════ 天燈 ═════════
rng = np.random.default_rng(31003); pr = random.Random(31003)
t = (yy / (H - 1)) * np.ones((H, W))
sky = ramp(t, [(0, (8, 10, 36)), (0.65, (26, 20, 62)), (1, (58, 30, 66))])
n = fbm((H, W), (22, 110), rng, 2)
sky += (np.clip(n - 0.5, 0, 1) * 2)[..., None] * np.array([18, 10, 34.0])
for _ in range(70):                                      # 幾顆小星
    cx, cy, b = rng.uniform(0, W), rng.uniform(1, H * 0.7), rng.uniform(40, 130)
    dx = (X - cx + W / 2) % W - W / 2
    sky += (np.exp(-(dx * dx + (Y - cy) ** 2) / 0.5) * b)[..., None]
save(sky, "fx-lantern-sky.png")


def lantern(wpx, bright):
    w = wpx * SS; h = w * 1.28
    pad = int(w * 1.7)
    size = (int(w) + pad * 2, int(h) + pad * 2)
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    cx, top, bot = size[0] / 2, pad, pad + h
    d.polygon([(cx - w / 2, top + w * 0.26), (cx + w / 2, top + w * 0.26), (cx + w * 0.30, bot), (cx - w * 0.30, bot)], fill=255)
    d.ellipse([cx - w / 2, top, cx + w / 2, top + w * 0.52], fill=255)
    gy = np.clip((np.arange(size[1]) - top) / h, 0, 1)[:, None] * np.ones((1, size[0]))
    col = ramp(gy, [(0, (255, 112, 28)), (0.55, (255, 170, 52)), (1, (255, 236, 150))]) * bright
    m = np.asarray(mask, dtype=float) / 255
    glow = np.asarray(mask.filter(ImageFilter.GaussianBlur(w * 0.55)), dtype=float) / 255
    rgb = col * m[..., None] + np.array([255, 130, 40.0]) * (glow * 0.75 * bright * (1 - m))[..., None]
    al = np.clip(m + glow * 0.9, 0, 1) * 255
    return Image.fromarray(np.dstack([np.clip(rgb / np.maximum(np.clip(m + glow * 0.75 * (1 - m), 1e-3, 1), 1e-3)[..., None], 0, 255),
                                      al]).round().astype(np.uint8), "RGBA")


for name, count, size, bright in (("fx-lantern-far.png", 30, (2.6, 3.8), 0.62), ("fx-lantern-near.png", 9, (5.6, 7.8), 1.0)):
    c = canvas((0, 0, 0, 255))
    for _ in range(count):
        stamp(c, lantern(pr.uniform(*size), bright * pr.uniform(0.8, 1.0)), pr.uniform(0, W * SS), pr.uniform(0, H * SS))
    save(c.convert("RGB").resize((W, H), Image.LANCZOS), name)

# ═════════ 客家花布 ═════════
pr = random.Random(31004); rng = np.random.default_rng(31004)
c = canvas((204, 26, 42, 255))
d = ImageDraw.Draw(c)


def wrapx(fn, cx, *a):
    for ox in (-W, 0, W):
        fn(cx + ox, *a)


def disc(cx, cy, r, fill, outline=None, ow=0.55):
    if outline:
        d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=outline)
        r -= ow
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=fill)


def leaf(cx, cy, length, width, ang, fill, vein):
    d.polygon([(x * SS, y * SS) for x, y in lens(cx, cy, length, width, ang)], fill=(22, 84, 52, 255))
    d.polygon([(x * SS, y * SS) for x, y in lens(cx, cy, length - 1.2, width - 1.2, ang)], fill=fill)
    ca, sa = math.cos(ang), math.sin(ang)
    d.line([((cx - ca * length * 0.4) * SS, (cy - sa * length * 0.4) * SS), ((cx + ca * length * 0.4) * SS, (cy + sa * length * 0.4) * SS)], fill=vein, width=2)


def peony(cx, cy, Rr, rot, palette):
    for n_, dist, prr, fill, outline in palette:
        for k in range(n_):
            a = rot + TAU * k / n_ + dist * 3.1
            disc(cx + math.cos(a) * dist * Rr, cy + math.sin(a) * dist * Rr, prr * Rr, fill, outline)
    for k in range(6):
        a = rot + TAU * k / 6
        disc(cx + math.cos(a) * 0.09 * Rr, cy + math.sin(a) * 0.09 * Rr, 0.055 * Rr, (255, 214, 96, 255))


PINK = [(8, 0.62, 0.46, (232, 84, 138, 255), (150, 22, 72, 255)), (7, 0.40, 0.40, (246, 132, 172, 255), (176, 40, 96, 255)),
        (6, 0.22, 0.32, (255, 184, 208, 255), (206, 78, 128, 255)), (1, 0.0, 0.20, (255, 222, 232, 255), (226, 120, 160, 255))]
WHITE = [(8, 0.62, 0.46, (246, 226, 232, 255), (170, 80, 110, 255)), (7, 0.40, 0.40, (255, 240, 244, 255), (196, 110, 140, 255)),
         (6, 0.22, 0.32, (255, 250, 250, 255), (220, 150, 170, 255)), (1, 0.0, 0.20, (255, 236, 200, 255), (220, 150, 120, 255))]
flowers = []
x = 20.0
i = 0
while x < W - 30:
    flowers.append((x, pr.uniform(9, 23), pr.uniform(12.5, 15.5), pr.uniform(0, TAU), PINK if i % 3 != 2 else WHITE))
    x += pr.uniform(64, 84); i += 1
for fx_, fy_, fr_, rot, pal in flowers:                    # 先葉子、再花
    for k in range(3):
        a = rot + TAU * k / 3 + pr.uniform(-0.4, 0.4)
        lx, ly = fx_ + math.cos(a) * fr_ * 1.05, fy_ + math.sin(a) * fr_ * 1.05
        wrapx(leaf, lx, ly, fr_ * 1.0, fr_ * 0.5, a, (46, 150, 92, 255) if k % 2 else (30, 124, 84, 255), (150, 214, 150, 255))
for fx_, fy_, fr_, rot, pal in flowers:
    wrapx(peony, fx_, fy_, fr_, rot, pal)
for j in range(len(flowers)):                              # 花與花之間的小白花、藍綠花苞
    a_, b_ = flowers[j], flowers[(j + 1) % len(flowers)]
    mx = (a_[0] + (b_[0] if b_[0] > a_[0] else b_[0] + W)) / 2
    for k in range(2):
        sx, sy = mx + pr.uniform(-9, 9), (6 if k == 0 else 26) + pr.uniform(-3, 3)
        col = (252, 246, 240, 255) if (j + k) % 2 == 0 else (64, 190, 200, 255)

        def blossom(cx, cy, col=col):
            for q in range(5):
                a = TAU * q / 5 + cx
                disc(cx + math.cos(a) * 2.3, cy + math.sin(a) * 2.3, 1.9, col, (120, 30, 50, 255), 0.4)
            disc(cx, cy, 1.2, (255, 206, 80, 255))
        wrapx(blossom, sx, sy)
a = np.asarray(down(c).convert("RGB"), dtype=float)
weave = (gnoise((H, W), (1.2, 1.2), rng) * 3.5)[..., None]   # 布紋的細顆粒
save((a + weave) * (0.90 + 0.12 * yb)[..., None], "fx-hakka-base.png")

# ═════════ 老花磚（一塊 32×32，橫向重複）═════════
TS = 8
tile = Image.new("RGBA", (32 * TS, 32 * TS), (236, 226, 198, 255))
d = ImageDraw.Draw(tile)
OUTL = (84, 46, 38, 255)


def tdisc(cx, cy, r, fill, outline=OUTL, ow=0.7):
    if outline:
        d.ellipse([(cx - r) * TS, (cy - r) * TS, (cx + r) * TS, (cy + r) * TS], fill=outline); r -= ow
    d.ellipse([(cx - r) * TS, (cy - r) * TS, (cx + r) * TS, (cy + r) * TS], fill=fill)


def tlens(cx, cy, length, width, ang, fill, ow=0.7):
    d.polygon([(x * TS, y * TS) for x, y in lens(cx, cy, length, width, ang, 20)], fill=OUTL)
    d.polygon([(x * TS, y * TS) for x, y in lens(cx, cy, length - ow * 2, width - ow * 2, ang, 20)], fill=fill)


for cx, cy in ((0, 0), (32, 0), (0, 32), (32, 32)):          # 四角：四塊拼起來是一朵圓花
    tdisc(cx, cy, 10.5, (34, 132, 138, 255))
    tdisc(cx, cy, 7.2, (236, 226, 198, 255))
    tdisc(cx, cy, 4.2, (198, 60, 70, 255))
for k in range(4):                                           # 斜向四片綠葉
    a = math.pi / 4 + k * math.pi / 2
    tlens(16 + math.cos(a) * 7.6, 16 + math.sin(a) * 7.6, 10.5, 4.6, a, (76, 150, 92, 255))
for k in range(4):                                           # 正向四片花瓣
    a = k * math.pi / 2
    tlens(16 + math.cos(a) * 6.2, 16 + math.sin(a) * 6.2, 11.5, 6.6, a, (214, 82, 104, 255))
    tlens(16 + math.cos(a) * 5.4, 16 + math.sin(a) * 5.4, 6.5, 2.6, a, (244, 160, 170, 255), 0)
tdisc(16, 16, 3.4, (244, 204, 92, 255))
tdisc(16, 16, 1.3, (198, 60, 70, 255), None)
d.rectangle([0, 0, 32 * TS - 1, 32 * TS - 1], outline=(176, 162, 132, 255), width=3)   # 磚縫
t1 = np.asarray(tile.resize((32, 32), Image.LANCZOS).convert("RGB"), dtype=float)
a = np.tile(t1, (1, W // 32, 1))
glaze = 0.90 + 0.14 * np.clip(1 - (yy / (H - 1)) / 0.45, 0, 1) ** 1.4      # 釉面：上緣一道亮
save(a * glaze[..., None], "fx-tile-base.png")

# ═════════ 珍珠奶茶 ═════════
rng = np.random.default_rng(31006); pr = random.Random(31006)
n1 = fbm((H, W), (9, 90), rng, 3); n2 = fbm((H, W), (5, 46), rng, 2)
m = np.clip(0.42 + (n1 - 0.5) * 1.5 + 0.22 * (yy / (H - 1) - 0.5), 0, 1)
tea = ramp(m, [(0, (244, 224, 192)), (0.5, (214, 172, 124)), (1, (176, 122, 78))])
syrup = np.clip((n2 - 0.60) * 4.5, 0, 1) * (0.35 + 0.65 * (yy / (H - 1)))       # 黑糖虎紋：往下越濃
tea = tea * (1 - syrup[..., None] * 0.62) + np.array([92, 46, 20.0]) * (syrup[..., None] * 0.62)
save(tea * satin[..., None], "fx-boba-base.png")
c = canvas()
d = ImageDraw.Draw(c)
pearls = []
x = 4.0
while x < W - 4:
    pearls.append((x, pr.uniform(23.5, 27.0), pr.uniform(4.2, 5.4)))
    if pr.random() < 0.3:
        pearls.append((x + pr.uniform(-3, 3), pr.uniform(15.5, 18.5), pr.uniform(3.8, 4.8)))
    x += pr.uniform(8.5, 13.5)
pr.shuffle(pearls)
for px_, py_, r_ in sorted(pearls, key=lambda p: p[1]):
    def pearl(cx, cy=py_, r=r_):
        d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=(30, 16, 10, 255))
        r2 = r - 0.55
        d.ellipse([(cx - r2) * SS, (cy - r2) * SS, (cx + r2) * SS, (cy + r2) * SS], fill=(62, 34, 22, 255))
        d.ellipse([(cx - r * 0.62) * SS, (cy - r * 0.68) * SS, (cx + r * 0.18) * SS, (cy + r * 0.05) * SS], fill=(112, 70, 48, 255))
        d.ellipse([(cx - r * 0.42) * SS, (cy - r * 0.52) * SS, (cx - r * 0.12) * SS, (cy - r * 0.24) * SS], fill=(236, 206, 180, 255))
    wrapx(pearl, px_)
save(down(c, (62, 34, 22)), "fx-boba-pearls.png")
bub = np.zeros((H, W, 3))
for _ in range(46):                                           # 往上冒的小氣泡（黑底加亮、上下可接）
    cx, cy, r, b = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.9, 2.0), rng.uniform(70, 150)
    dx = (X - cx + W / 2) % W - W / 2
    dy = (Y - cy + H / 2) % H - H / 2
    dist = np.sqrt(dx * dx + dy * dy)
    bub += (np.exp(-((dist - r) / 0.55) ** 2) * b + np.exp(-(((dx + r * 0.4) ** 2 + (dy + r * 0.4) ** 2)) / 0.35) * b * 0.9)[..., None]
save(bub * np.array([1.0, 0.96, 0.88]), "fx-boba-bubbles.png")

# ═════════ 極光 ═════════
rng = np.random.default_rng(31007)
t = (yy / (H - 1)) * np.ones((H, W))
night = ramp(t, [(0, (4, 8, 26)), (1, (6, 26, 36))])
for _ in range(60):
    cx, cy, b = rng.uniform(0, W), rng.uniform(1, H * 0.8), rng.uniform(30, 110)
    dx = (X - cx + W / 2) % W - W / 2
    night += (np.exp(-(dx * dx + (Y - cy) ** 2) / 0.5) * b)[..., None]
save(night, "fx-aurora-sky.png")


def n1d(feat, octv=3):
    return fbm((W,), (feat,), rng, octv)


def aurora(y0, amp, length, cols):
    edge = y0 + (n1d(110) - 0.5) * 2 * amp
    env = 0.22 + 0.78 * np.clip(n1d(75) * 1.5 - 0.25, 0, 1)           # 整片光幕哪裡亮、哪裡淡（不會全黑）
    rays = (0.42 + 0.58 * n1d(8, 2)) * env                              # 細光束：只是明暗起伏，沒有暗縫
    above = edge[None, :] - yy
    I = np.where(above >= 0, np.exp(-above / length), np.exp(above / 2.6)) * rays[None, :]
    I = I + 0.30 * np.exp(-((above - 3) / 7.0) ** 2) * env[None, :]     # 光幕下緣一圈柔光
    tt = np.clip(above / (length * 2.4), 0, 1)
    return ramp(tt, cols) * I[..., None]


save(aurora(25, 5, 9, [(0, (120, 255, 170)), (0.4, (40, 220, 170)), (1, (60, 120, 255))]) * 1.25, "fx-aurora-a.png")
save(aurora(20, 6, 11, [(0, (90, 255, 200)), (0.35, (70, 150, 255)), (1, (190, 70, 255))]) * 1.05, "fx-aurora-b.png")


# ═══════════════════ 第三批（2026-11-10）：紅葉／螢火蟲／錦鯉水波／夜市霓虹／藍白拖 ═══════════════════
from PIL import ImageFont

T01 = (yy / (H - 1)) * np.ones((H, W))


def wdx(cx):
    return (X - cx + W / 2) % W - W / 2


def wdy(cy):
    return (Y - cy + H / 2) % H - H / 2


# ═════════ 紅葉 ═════════
rng = np.random.default_rng(32001); pr = random.Random(32001)
base = ramp(T01, [(0, (44, 20, 20)), (1, (108, 46, 20))])
base += (fbm((H, W), (30, 120), rng, 2) - 0.5)[..., None] * np.array([44, 24, 8.0])
for _ in range(18):                                   # 暖金色的柔焦光斑
    cx, cy, r, k = rng.uniform(0, W), rng.uniform(2, H - 2), rng.uniform(5, 10), rng.uniform(12, 30)
    base += (np.exp(-(wdx(cx) ** 2 + (Y - cy) ** 2) / (2 * (r * 0.6) ** 2)) * k)[..., None] * np.array([1.0, 0.72, 0.30])
save(base * satin[..., None], "fx-momiji-base.png")

LOBES = [(-140, 0.46), (-95, 0.78), (-42, 0.93), (0, 1.0), (42, 0.93), (95, 0.78), (140, 0.46)]


def maple_pts(cx, cy, R, rot):
    pts = []
    for i, (a, l) in enumerate(LOBES):
        if i > 0:
            pts.append(((LOBES[i - 1][0] + a) / 2, 0.33))      # 裂片之間的凹口
        pts += [(a - 9, l * 0.60), (a, l), (a + 9, l * 0.60)]
    pts += [(165, 0.22), (180, 0.20), (195, 0.22)]
    return [(cx + math.sin(math.radians(a) + rot) * l * R, cy - math.cos(math.radians(a) + rot) * l * R) for a, l in pts]


LEAF_COLS = [((206, 34, 30), (240, 96, 70)), ((232, 82, 26), (250, 150, 80)), ((244, 140, 34), (255, 196, 110)), ((248, 196, 70), (255, 232, 150)),
             ((176, 24, 34), (226, 70, 70))]


def maple(size, rot, alpha):
    R = size * SS
    pad = 4
    im = Image.new("RGBA", (int(R * 2) + pad * 2, int(R * 2.3) + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = im.width / 2, pad + R
    col, light = pr.choice(LEAF_COLS)
    d.line([(cx, cy), (cx, cy + R * 0.95)], fill=(96, 40, 20, alpha), width=max(2, int(R * 0.10)))     # 葉柄
    d.polygon(maple_pts(cx, cy, R, 0), fill=col + (alpha,))
    d.polygon(maple_pts(cx, cy - R * 0.02, R * 0.52, 0), fill=light + (alpha,))
    return im.rotate(math.degrees(rot), resample=Image.BICUBIC, expand=True)


for name, count, size, alpha in (("fx-momiji-leaves-a.png", 34, (2.6, 3.8), 215), ("fx-momiji-leaves-b.png", 13, (4.8, 6.8), 250)):
    c = canvas()
    for _ in range(count):
        stamp(c, maple(pr.uniform(*size), pr.uniform(0, TAU), alpha), pr.uniform(0, W * SS), pr.uniform(0, H * SS))
    save(down(c, (220, 80, 40)), name)

# ═════════ 螢火蟲 ═════════
rng = np.random.default_rng(32002); pr = random.Random(32002)
night = ramp(T01, [(0, (4, 14, 24)), (0.6, (6, 26, 30)), (1, (10, 40, 30))])
night += (np.clip(fbm((H, W), (20, 100), rng, 2) - 0.5, 0, 1) * 2)[..., None] * np.array([6, 26, 16.0])
c = canvas()
d = ImageDraw.Draw(c)
x = 0.0
while x < W:                                          # 底部的草葉剪影
    hgt, lean, wd = pr.uniform(5, 15), pr.uniform(-4, 4), pr.uniform(1.0, 2.0)
    for ox in (-W, 0, W):
        bx = x + ox
        d.polygon([((bx - wd) * SS, H * SS), ((bx + wd) * SS, H * SS), ((bx + lean) * SS, (H - hgt) * SS)], fill=(3, 16, 12, 255))
    x += pr.uniform(1.6, 4.2)
g = np.asarray(down(c), dtype=float)
al = g[..., 3:4] / 255
save(night * (1 - al) + g[..., :3] * al, "fx-firefly-night.png")
for name, count, seedcol in (("fx-firefly-a.png", 15, (200, 255, 90)), ("fx-firefly-b.png", 13, (230, 255, 120)), ("fx-firefly-c.png", 11, (170, 255, 110))):
    a = np.zeros((H, W, 3))
    for _ in range(count):
        cx, cy, b, s = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0.75, 1.15), rng.uniform(0.55, 0.9)
        dd = wdx(cx) ** 2 + wdy(cy) ** 2
        gl = np.exp(-dd / (2 * s * s)) * 1.25 + np.exp(-dd / (2 * (s * 3.4) ** 2)) * 0.40 + np.exp(-dd / (2 * (s * 7) ** 2)) * 0.12
        a += (gl * b)[..., None] * np.array(seedcol, dtype=float)
    save(a, name)

# ═════════ 錦鯉水波 ═════════
rng = np.random.default_rng(32003); pr = random.Random(32003)
water = ramp(T01, [(0, (20, 104, 120)), (1, (10, 62, 92))])
water += (fbm((H, W), (16, 70), rng, 2) - 0.5)[..., None] * np.array([18, 40, 36.0])
save(water * satin[..., None], "fx-koi-water.png")
for name in ("fx-koi-caustic-a.png", "fx-koi-caustic-b.png"):          # 水面的光網：脊狀雜訊的細亮線
    r1 = 1 - np.abs(2 * fbm((H, W), (9, 26), rng, 2) - 1)
    r2 = 1 - np.abs(2 * fbm((H, W), (6, 15), rng, 2) - 1)
    cst = np.clip((r1 * r2 - 0.74) * 5.5, 0, 1) ** 1.3
    save(cst[..., None] * np.array([150, 232, 236.0]) * 0.62, name)

KOI = [((250, 246, 240), [(232, 66, 28)], 3), ((246, 128, 28), [(255, 196, 96)], 2), ((250, 246, 240), [(30, 26, 32), (226, 60, 30)], 4),
       ((250, 204, 72), [], 0), ((250, 246, 240), [(236, 90, 36)], 2), ((238, 84, 30), [(250, 244, 236)], 2)]


def koi(length, width, kind):
    L, Wd = length * SS, width * SS
    sz = (int(L * 1.35), int(Wd * 3.2))
    cx, cy = sz[0] * 0.52, sz[1] / 2
    body_col, patch_cols, npatch = kind
    fins = Image.new("RGBA", sz, (0, 0, 0, 0)); d = ImageDraw.Draw(fins)
    fin = tuple(int(v * 0.5 + 255 * 0.5) for v in body_col) + (175,)
    d.polygon([(cx - 0.30 * L, cy), (cx - 0.55 * L, cy - 0.62 * Wd), (cx - 0.45 * L, cy), (cx - 0.55 * L, cy + 0.62 * Wd)], fill=fin)   # 尾鰭
    for sgn in (-1, 1):                                                                                                               # 胸鰭
        d.polygon(lens(cx + 0.13 * L, cy + sgn * 0.50 * Wd, 0.22 * L, 0.34 * Wd, sgn * 0.75), fill=fin)
    mask = Image.new("L", sz, 0); d = ImageDraw.Draw(mask)
    d.polygon(lens(cx + 0.02 * L, cy, 0.80 * L, Wd * 0.98, 0, 20), fill=255)
    d.ellipse([cx + 0.17 * L, cy - Wd * 0.44, cx + 0.44 * L, cy + Wd * 0.44], fill=255)                                               # 頭比較圓
    body = Image.new("RGBA", sz, body_col + (255,)); d = ImageDraw.Draw(body)
    for _ in range(npatch):
        px_, py_, r = cx + pr.uniform(-0.28, 0.30) * L, cy + pr.uniform(-0.3, 0.3) * Wd, pr.uniform(0.09, 0.17) * L
        d.ellipse([px_ - r, py_ - r * 0.8, px_ + r, py_ + r * 0.8], fill=pr.choice(patch_cols) + (255,))
    d.line([(cx - 0.25 * L, cy), (cx + 0.25 * L, cy)], fill=tuple(int(v * 0.86) for v in body_col) + (255,), width=max(1, int(Wd * 0.07)))   # 背脊
    body.putalpha(mask)
    shadow = Image.new("RGBA", sz, (4, 30, 44, 0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(SS * 1.2)).point(lambda v: int(v * 0.42)))
    out = Image.new("RGBA", sz, (0, 0, 0, 0))
    sh = Image.new("RGBA", sz, (0, 0, 0, 0)); sh.paste(shadow, (int(SS * 1.6), int(SS * 2.4)))
    out.alpha_composite(sh); out.alpha_composite(fins); out.alpha_composite(body)
    return out.rotate(pr.uniform(-9, 9), resample=Image.BICUBIC, expand=True)


c = canvas()
x = 30.0
i = 0
while x < W - 20:
    stamp(c, koi(pr.uniform(30, 42), pr.uniform(8.5, 11), KOI[i % len(KOI)]), x * SS, pr.uniform(9, 23) * SS, wrap_y=False)
    x += pr.uniform(58, 86); i += 1
save(down(c, (20, 90, 110)), "fx-koi-fish.png")

# ═════════ 夜市霓虹 ═════════
# 招牌字用思源黑體（OFL）畫。字型檔不在 repo 裡（套組的字型典藏庫 ~/MiliUI-Fonts/字型母版/）：找不到就整節跳過、保留現有的圖
FONT = os.path.expanduser("~/MiliUI-Fonts/字型母版/NotoMerged-Black.ttf")
if not os.path.exists(FONT):
    print("⚠ 找不到", FONT, "——夜市霓虹那四張沒有重產（其餘照常）")
else:
    rng = np.random.default_rng(32004)
    wall = ramp(T01, [(0, (14, 10, 30)), (1, (30, 14, 42))])
    wall += (np.clip(fbm((H, W), (26, 70), rng, 2) - 0.45, 0, 1) * 2)[..., None] * np.array([26, 8, 34.0])
    NEON = [(255, 60, 150), (60, 230, 255), (255, 220, 60), (90, 255, 120), (255, 140, 40)]
    SIGNS = ["夜市", "雞排", "珍奶", "滷味", "蚵仔煎", "豆花", "燒烤", "芒果冰"]
    font = ImageFont.truetype(FONT, int(16.5 * SS))
    masks = {}                                           # (層, 顏色) → L 遮罩


    def M(layer, col):
        k = (layer, col)
        if k not in masks:
            masks[k] = Image.new("L", (W * SS, H * SS), 0)
        return ImageDraw.Draw(masks[k])


    widths = [font.getlength(t) / SS + 13 for t in SIGNS]
    gap = (W - sum(widths)) / len(SIGNS)
    x = gap / 2
    for i, (t, wd_) in enumerate(zip(SIGNS, widths)):
        layer = i % 2
        cf, ct = i % len(NEON), (i + 2) % len(NEON)
        M(layer, cf).rounded_rectangle([x * SS, 5.0 * SS, (x + wd_) * SS, 30.0 * SS], radius=5 * SS, outline=255, width=int(1.5 * SS))
        bb = font.getbbox(t)
        M(layer, ct).text(((x + wd_ / 2) * SS - (bb[0] + bb[2]) / 2, 17.5 * SS - (bb[1] + bb[3]) / 2), t, font=font, fill=255)
        x += wd_ + gap
    for layer in (0, 1):
        rgb = np.zeros((H * SS, W * SS, 3))
        for (ly, ci), m in masks.items():
            if ly != layer:
                continue
            col = np.array(NEON[ci], dtype=float)
            core = np.asarray(m, dtype=float) / 255
            g1 = np.asarray(m.filter(ImageFilter.GaussianBlur(2.6 * SS)), dtype=float) / 255
            g2 = np.asarray(m.filter(ImageFilter.GaussianBlur(0.9 * SS)), dtype=float) / 255
            rgb += col * (g1 * 0.70 + g2 * 0.45)[..., None] + (col * 0.72 + 255 * 0.28) * core[..., None] * 0.80
        im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").resize((W, H), Image.LANCZOS)
        save(im, "fx-neon-signs-%s.png" % "ab"[layer])
    bulbs = np.zeros((H, W, 3))                           # 頂上一串小燈泡
    k = 0
    xb = 5.0
    while xb < W:
        yb_ = 1.9 + 1.5 * abs(math.sin(math.pi * k / 5))
        dd = wdx(xb) ** 2 + (Y - yb_) ** 2
        bulbs += (np.exp(-dd / 1.2) * 1.2 + np.exp(-dd / 9.0) * 0.35)[..., None] * np.array(NEON[k % len(NEON)], dtype=float)
        wall += (np.exp(-dd / 40.0) * 0.10)[..., None] * np.array(NEON[k % len(NEON)], dtype=float)
        xb += W / 44; k += 1
    save(wall, "fx-neon-wall.png")
    save(bulbs, "fx-neon-bulbs.png")

# ═════════ 藍白拖（放在磨石子地上，鞋頭朝上）═════════
pr = random.Random(32005); rng = np.random.default_rng(32005)
c = canvas((204, 202, 196, 255))
d = ImageDraw.Draw(c)
CHIPS = [(120, 120, 122), (236, 232, 222), (150, 84, 70), (92, 124, 104), (176, 170, 160), (70, 72, 78)]
for _ in range(1500):                                  # 磨石子的碎石
    cx, cy, r = pr.uniform(0, W), pr.uniform(0, H), pr.uniform(0.35, 1.25)
    col = pr.choice(CHIPS) + (255,)
    pts = [(cx + math.cos(t_) * r * pr.uniform(0.6, 1.2), cy + math.sin(t_) * r * pr.uniform(0.6, 1.2)) for t_ in (0.3, 1.5, 2.8, 4.0, 5.2)]
    for ox in (-W, 0, W):
        d.polygon([((x + ox) * SS, y * SS) for x, y in pts], fill=col)


def slipper(cx, cy, side, rot):
    """side ＝ -1 左腳、+1 右腳（前掌往外偏一點）。本體 13×28，鞋頭朝上"""
    sz = (int(22 * SS), int(36 * SS))
    im = Image.new("RGBA", sz, (0, 0, 0, 0)); dd = ImageDraw.Draw(im)
    mx, my = sz[0] / 2, sz[1] / 2
    fx_ = mx + side * 0.7 * SS

    def sole(g, fill):
        dd.ellipse([fx_ - (6.3 + g) * SS, my - (14 + g) * SS, fx_ + (6.3 + g) * SS, my + (2.5 + g) * SS], fill=fill)          # 前掌
        dd.ellipse([mx - (4.9 + g) * SS, my + (0.5 - g) * SS, mx + (4.9 + g) * SS, my + (14 + g) * SS], fill=fill)            # 腳跟
        dd.polygon([(fx_ - (6.0 + g) * SS, my - 4 * SS), (fx_ + (6.0 + g) * SS, my - 4 * SS),
                    (mx + (4.9 + g) * SS, my + 7 * SS), (mx - (4.9 + g) * SS, my + 7 * SS)], fill=fill)
    sole(0.75, (40, 96, 200, 255))                      # 鞋底的藍邊
    sole(0, (250, 250, 247, 255))
    for iy in range(-11, 12, 3):                        # 止滑顆粒
        for ix in range(-4, 5, 2):
            if abs(ix) < (4.6 if iy < 2 else 3.4):
                dd.ellipse([mx + ix * SS - 2, my + iy * SS - 2, mx + ix * SS + 2, my + iy * SS + 2], fill=(222, 226, 232, 255))
    toe = (fx_ - side * 1.2 * SS, my - 8.2 * SS)
    for sgn in (-1, 1):                                 # 人字帶
        end = (mx + sgn * 5.6 * SS, my + 1.6 * SS)
        dd.line([toe, end], fill=(12, 44, 140, 255), width=int(3.5 * SS))
    for sgn in (-1, 1):
        end = (mx + sgn * 5.6 * SS, my + 1.6 * SS)
        dd.line([toe, end], fill=(30, 100, 232, 255), width=int(2.3 * SS))
    dd.ellipse([toe[0] - 1.7 * SS, toe[1] - 1.7 * SS, toe[0] + 1.7 * SS, toe[1] + 1.7 * SS], fill=(12, 44, 140, 255))
    dd.ellipse([toe[0] - 1.1 * SS, toe[1] - 1.1 * SS, toe[0] + 1.1 * SS, toe[1] + 1.1 * SS], fill=(30, 100, 232, 255))
    im = im.rotate(rot, resample=Image.BICUBIC, expand=True)
    sh = Image.new("RGBA", im.size, (60, 60, 66, 0)); sh.putalpha(im.split()[3].filter(ImageFilter.GaussianBlur(SS * 0.8)).point(lambda v: int(v * 0.55)))
    stamp(c, sh, cx * SS + 1.4 * SS, cy * SS + 1.4 * SS, wrap_y=False)
    stamp(c, im, cx * SS, cy * SS, wrap_y=False)


n_pairs = 13
for i in range(n_pairs):
    cx = (i + 0.5) * W / n_pairs + pr.uniform(-2, 2)
    rot = pr.uniform(-9, 9)
    slipper(cx - 7.3, 16 + pr.uniform(-0.8, 0.8), -1, rot + pr.uniform(-5, 5))
    slipper(cx + 7.3, 16 + pr.uniform(-0.8, 0.8), 1, rot + pr.uniform(-5, 5))
a = np.asarray(down(c).convert("RGB"), dtype=float)
save(a * (0.93 + 0.08 * yb)[..., None], "fx-slipper-base.png")

# ═════════ 靜態那張（當一般長條的填充、登記進 LSM）：把幾層疊成一張 ═════════
def _load(name):
    return np.asarray(Image.open(os.path.join(OUT, name)).convert("RGBA"), dtype=float)


def _static(name, layers):
    out = None
    for fn, mode, k in layers:
        a = _load(fn)
        if out is None:
            out = a[..., :3].copy()
        elif mode == "add":
            out = np.clip(out + a[..., :3] * k, 0, 255)
        else:
            al = a[..., 3:4] / 255.0 * k
            out = out * (1 - al) + a[..., :3] * al
    save(out, name)


_static("fx-sakura-static.png", [("fx-sakura-base.png", "", 1), ("fx-sakura-petals-a.png", "blend", 1), ("fx-sakura-petals-b.png", "blend", 1)])
_static("fx-lantern-static.png", [("fx-lantern-sky.png", "", 1), ("fx-lantern-far.png", "add", 1), ("fx-lantern-near.png", "add", 1)])
_static("fx-boba-static.png", [("fx-boba-base.png", "", 1), ("fx-boba-pearls.png", "blend", 1), ("fx-boba-bubbles.png", "add", 0.8)])
_static("fx-aurora-static.png", [("fx-aurora-sky.png", "", 1), ("fx-aurora-b.png", "add", 0.85), ("fx-aurora-a.png", "add", 1)])
_static("fx-momiji-static.png", [("fx-momiji-base.png", "", 1), ("fx-momiji-leaves-a.png", "blend", 1), ("fx-momiji-leaves-b.png", "blend", 1)])
_static("fx-firefly-static.png", [("fx-firefly-night.png", "", 1), ("fx-firefly-a.png", "add", 1), ("fx-firefly-b.png", "add", 0.9), ("fx-firefly-c.png", "add", 1)])
_static("fx-koi-static.png", [("fx-koi-water.png", "", 1), ("fx-koi-caustic-a.png", "add", 0.8), ("fx-koi-fish.png", "blend", 1), ("fx-koi-caustic-b.png", "add", 0.7)])
_static("fx-neon-static.png", [("fx-neon-wall.png", "", 1), ("fx-neon-signs-a.png", "add", 1), ("fx-neon-signs-b.png", "add", 1), ("fx-neon-bulbs.png", "add", 1)])
