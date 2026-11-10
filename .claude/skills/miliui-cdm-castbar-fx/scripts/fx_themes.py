#!/usr/bin/env python3
"""MiliUI_CooldownManager 施法條動畫材質第二批的貼圖（櫻花／青海波／天燈／客家花布／老花磚／珍珠奶茶／極光）：Media/fx-*.png，二十張一次產。

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
