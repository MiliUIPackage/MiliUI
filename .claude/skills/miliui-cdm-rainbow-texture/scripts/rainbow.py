#!/usr/bin/env python3
"""MiliUI_CooldownManager 施法條的彩虹材質：Media/miliui_rainbow*.png，四張一次產。

全部自己算、不帶別人的檔（SharedMedia 那包貼圖沒有授權檔，不拿來改）。橫向是色相、縱向沿用
MiliUI Satin 的高光曲線（上緣亮、往下壓到平台）；遊戲裡 SetVertexColor 一律白（Castbar.lua 選到彩虹時底色自動白），
所以這裡的飽和度／亮度就是玩家看到的。

    python3 .claude/skills/miliui-cdm-rainbow-texture/scripts/rainbow.py        # 在 repo 任何位置都可以

兩款 × 兩用途：
  miliui_rainbow.png        鮮豔，靜態：色相 0→300°（紅→紫，兩端不同色，是「一道彩虹」），當 StatusBar 填充材質，進度前進時逐段露出
  miliui_rainbow_flow.png   鮮豔，流動：色相 0→360°（兩端同色 ⇒ REPEAT 平鋪無接縫），給流動層的貼圖座標動畫捲
  miliui_rainbow_soft.png / miliui_rainbow_soft_flow.png   柔和款（飽和度降一半），同上
"""
import colorsys
import os
from PIL import Image
import numpy as np

W, H = 512, 32          # 寬只是取樣密度（300px 的條也不會有色帶）；高跟 Satin 同
TOP = 1.00              # 上緣亮度（0～1）
BOTTOM = 0.84           # 平台亮度：高光壓到這裡之後一路到下緣都是它
KNEE = 0.5              # 高光佔多高（跟 Satin 同一條曲線）
POWER = 1.6
STATIC_END = 300.0      # 靜態款的色相終點（度）：紅→紫；流動款固定 360 讓平鋪無接縫
VARIANTS = {            # 檔名字尾 → 飽和度
    "": 0.85,
    "_soft": 0.45,
}
ADDONS = ["MiliUI_CooldownManager"]

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))

y = np.arange(H) / (H - 1)
t = np.clip(y / KNEE, 0, 1)
V = BOTTOM + (TOP - BOTTOM) * (1 - t) ** POWER        # 每一列的亮度


def build(sat, hue_end):
    px = np.zeros((H, W, 3), dtype=np.uint8)
    for x in range(W):
        h = (x / W if hue_end >= 360 else x / (W - 1) * hue_end / 360.0)
        for row in range(H):
            r, g, b = colorsys.hsv_to_rgb(h % 1.0, sat, V[row])
            px[row, x] = (round(r * 255), round(g * 255), round(b * 255))
    return Image.fromarray(px, "RGB")


for suffix, sat in VARIANTS.items():
    for kind, hue_end in (("", STATIC_END), ("_flow", 360.0)):
        im = build(sat, hue_end)
        name = f"miliui_rainbow{suffix}{kind}.png"
        for addon in ADDONS:
            out = os.path.join(REPO, "AddOns", addon, "Media", name)
            im.save(out)
            print("saved", os.path.relpath(out, REPO))
