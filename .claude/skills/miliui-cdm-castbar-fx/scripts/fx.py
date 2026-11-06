#!/usr/bin/env python3
"""MiliUI_CooldownManager 施法條動畫材質的貼圖（宇宙星辰／閃電／熔岩／火焰）：Media/fx-*.png，十張一次產。

全部自己算、固定亂數種子（同一份腳本跑出來的圖一模一樣）、不帶別人的檔。可平鋪的雜訊是「白雜訊在頻域乘高斯低通」，
每一軸都繞得回來，所以橫向捲動沒有接縫。閃電的電弧沿用技能 miliui-cdm-skyriding-lightning 的折線演算法（import 它的 frame()）。

    python3 .claude/skills/miliui-cdm-castbar-fx/scripts/fx.py        # 在 repo 任何位置都可以

每張圖怎麼用（哪幾層、捲多快、哪張是序列圖）登記在 AddOns/MiliUI_CooldownManager/Core/Media.lua 的 M.FX；
改格數／排列要兩邊一起改。尺寸一律 2 的次方。
"""
import importlib.util
import os
import random

import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))
OUT = os.path.join(REPO, "AddOns", "MiliUI_CooldownManager", "Media")
W, H = 512, 32                                   # 捲動層：遊戲裡拉到條的寬高，一輪 ＝ 整張


def gnoise(shape, feats, rng):
    """週期性的平滑雜訊（每一軸都能平鋪）。feats ＝ 每一軸的特徵尺寸（像素）"""
    F = np.fft.fftn(rng.standard_normal(shape))
    k2 = 0
    for ax, (n, f) in enumerate(zip(shape, feats)):
        sh = [1] * len(shape)
        sh[ax] = n
        k2 = k2 + (np.fft.fftfreq(n).reshape(sh) * f) ** 2
    n = np.real(np.fft.ifftn(F * np.exp(-k2 * 4.0)))
    return (n - n.mean()) / (n.std() + 1e-9)


def fbm(shape, feats, rng, octaves=3, gain=0.5):
    out, amp = 0, 1.0
    for i in range(octaves):
        out = out + amp * gnoise(shape, [f / (2 ** i) for f in feats], rng)
        amp *= gain
    out = (out - out.mean()) / (out.std() + 1e-9)
    return np.clip(out * 0.22 + 0.5, 0, 1)        # 約 ±2.3σ 落在 0～1


def save(arr, name):
    a = np.clip(arr, 0, 255).round().astype(np.uint8)
    path = os.path.join(OUT, name)
    Image.fromarray(a, "RGBA" if a.shape[2] == 4 else "RGB").save(path, optimize=True)
    print("saved", os.path.relpath(path, REPO), f"{a.shape[1]}x{a.shape[0]}", os.path.getsize(path), "bytes")


def ramp(t, stops):
    """t（0～1 陣列）→ 顏色；stops ＝ [(位置, (r,g,b[,a])), …]"""
    pos = np.array([s[0] for s in stops])
    cols = np.array([s[1] for s in stops], dtype=float)
    return np.stack([np.interp(t, pos, cols[:, c]) for c in range(cols.shape[1])], axis=-1)


yb = (1 - np.arange(H) / (H - 1))[:, None]        # 0 ＝ 下緣、1 ＝ 上緣
# 上緣一道高光（跟 MiliUI Satin 同一條曲線）
satin = 0.86 + 0.14 * np.clip(1 - (np.arange(H) / (H - 1)) / 0.5, 0, 1)[:, None] ** 1.6

# ───────── 宇宙星辰：星雲底 ＋ 小星點 ＋ 亮星（後兩張黑底，遊戲裡加亮混色）─────────
rng = np.random.default_rng(20261106)
n1 = fbm((H, W), (26, 70), rng)
n2 = fbm((H, W), (22, 90), rng)
n3 = fbm((H, W), (10, 24), rng)
base = np.array([7, 9, 30.0])[None, None, :] * np.ones((H, W, 1))
base += (np.clip(n1 - 0.38, 0, 1) * 1.9)[..., None] ** 1.4 * np.array([120, 40, 165.0])
base += (np.clip(n2 - 0.42, 0, 1) * 1.9)[..., None] ** 1.4 * np.array([20, 95, 170.0])
base += (np.clip(n1 * n2 * 2.2 - 0.55, 0, 1))[..., None] * np.array([150, 90, 120.0]) * n3[..., None]
save(base * satin[..., None], "fx-cosmos-base.png")


def stars(count, rng, bright, sigma, flare):
    img = np.zeros((H, W, 3))
    yy, xx = np.mgrid[0:H, 0:W]
    tints = np.array([[255, 255, 255], [190, 215, 255], [255, 235, 200], [215, 195, 255]], dtype=float)
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(2.5, H - 2.5)
        b = rng.uniform(*bright)
        s = rng.uniform(*sigma)
        col = tints[rng.integers(len(tints))]
        dx = (xx - x + W / 2) % W - W / 2                 # 橫向繞回：平鋪無接縫
        dy = yy - y
        g = np.exp(-(dx * dx + dy * dy) / (2 * s * s)) * b
        if flare:                                         # 亮星：十字星芒＋一圈柔光
            L = rng.uniform(3.5, 6.5)
            g += (np.exp(-(dy * dy) / 0.5 - np.abs(dx) / L) + np.exp(-(dx * dx) / 0.5 - np.abs(dy) / (L * 0.8))) * b * 0.55
            g += np.exp(-(dx * dx + dy * dy) / (2 * (s * 3.2) ** 2)) * b * 0.22
        img += g[..., None] * col
    return img


save(stars(150, rng, (0.25, 0.8), (0.45, 0.75), False), "fx-cosmos-stars-a.png")
save(stars(16, rng, (0.9, 1.3), (0.7, 1.0), True), "fx-cosmos-stars-b.png")

# ───────── 閃電：電能底 ＋ 八格電弧序列圖（2 欄 × 4 列，每格 512×32，黑底加亮混色）─────────
rng = np.random.default_rng(20261107)
e = np.clip(fbm((H, W), (7, 80), rng) * 0.65 + fbm((H, W), (4, 40), rng) * 0.35, 0, 1)
lb = np.array([6, 14, 46.0]) * np.ones((H, W, 1))
lb += (e ** 2.2)[..., None] * np.array([30, 110, 255.0])
lb += (np.clip(e - 0.62, 0, 1) * 2.6)[..., None] ** 2 * np.array([170, 225, 255.0])
save(lb * satin[..., None], "fx-lightning-base.png")

spec = importlib.util.spec_from_file_location(
    "skyriding_lightning", os.path.join(REPO, ".claude", "skills", "miliui-cdm-skyriding-lightning", "scripts", "lightning.py"))
lt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lt)
prng = random.Random(20261108)
BOLT_INTENSITY = [1.0, 0.9, 1.0, 0.95, 1.0, 0.9, 0.5, 0.2]      # 六道不同的電弧 ＋ 兩格餘暉
sheet = np.zeros((H * 4, W * 2, 3))
last = None
for i, s in enumerate(BOLT_INTENSITY):
    if s < 0.6 and last is not None:
        a = last * s
    else:
        a = np.asarray(lt.frame(prng, s).split()[3], dtype=float) / 255.0
        last = a
    a3 = a[..., None]
    rgb = a3 * (np.array([70, 150, 255.0]) * (1 - a3 ** 2) + np.array([255, 255, 255.0]) * a3 ** 2)   # 藍暈、白芯
    sheet[(i // 2) * H:(i // 2 + 1) * H, (i % 2) * W:(i % 2 + 1) * W] = rgb
save(sheet, "fx-lightning-bolts.png")

# ───────── 熔岩：暗紅底 ＋ 兩層火紋（黑底加亮混色，不同速度橫著流）─────────
FIRE = [(0.0, (0, 0, 0)), (0.18, (95, 8, 0)), (0.4, (215, 50, 4)), (0.62, (255, 135, 15)), (0.84, (255, 215, 80)), (1.0, (255, 250, 215))]
rng = np.random.default_rng(20261109)
n = fbm((H, W), (14, 60), rng, 2)
t = np.clip(0.30 + 0.22 * (1 - yb) + (n - 0.5) * 0.28, 0, 1)      # 下緣熱、上緣暗紅
save(ramp(t, FIRE) * satin[..., None] ** 0.5, "fx-lava-base.png")
for nm, feats, gain in (("fx-lava-wisp-a.png", (16, 34), 2.3), ("fx-lava-wisp-b.png", (11, 20), 2.0)):
    n = fbm((H, W), feats, rng, 3, 0.55)
    heat = np.clip((n - 0.47) * gain * (1.05 - 0.7 * yb), 0, 1)
    save(ramp(heat, FIRE), nm)

# ───────── 火焰：餘燼底 ＋ 十六格可循環的火舌序列圖（4 欄 × 4 列，每格 256×64，RGBA 一般混色）─────────
# 每格下面 2/3 是條身、上面 1/3 是竄出條外的火舌（Media.lua 那層的 overflow = 0.5：往條的上緣外多畫半個條高）。
# 三維雜訊（時間 × 高 × 寬）三軸都週期；每格再把雜訊往上推 FH/T 列 ⇒ 16 格剛好繞一圈、接回第一格。
T, FH, FW = 16, 64, 256
rng = np.random.default_rng(20261110)
N = (gnoise((T, FH, FW), (6, 58, 13), rng) + 0.6 * gnoise((T, FH, FW), (3.5, 29, 7), rng)
     + 0.35 * gnoise((T, FH, FW), (2.5, 13, 4), rng))
N = np.clip((N - N.mean()) / N.std() * 0.22 + 0.5, 0, 1)
fy = (1 - np.arange(FH) / (FH - 1))[:, None]                      # 0 下緣、1 上緣
FIRE_A = [(0.0, (120, 10, 0, 0)), (0.06, (120, 10, 0, 0)), (0.16, (150, 18, 0, 150)), (0.34, (225, 60, 5, 245)),
          (0.58, (255, 135, 15, 255)), (0.82, (255, 205, 60, 255)), (1.0, (255, 240, 170, 255))]
sheet = np.zeros((FH * 4, FW * 4, 4))
for i in range(T):
    fr = np.roll(N[i], -i * (FH // T), axis=0)
    # 下緣穩定在橘黃（字還讀得到）、越往上越靠雜訊的峰才燒得到 ⇒ 尖的火舌；最上面一段再收尖，不會被格子切平
    heat = np.clip(0.60 - 0.80 * fy + (fr - 0.5) * (0.45 + 1.45 * fy) - np.clip((fy - 0.72) / 0.28, 0, 1) ** 1.5 * 0.55, 0, 1)
    sheet[(i // 4) * FH:(i // 4 + 1) * FH, (i % 4) * FW:(i % 4 + 1) * FW] = ramp(heat, FIRE_A)
save(sheet, "fx-flame-tongues.png")
n = fbm((H, W), (14, 50), rng, 2)
t = np.clip(0.2 + 0.12 * (1 - yb) + (n - 0.5) * 0.2, 0, 1)
save(ramp(t, FIRE), "fx-flame-base.png")
