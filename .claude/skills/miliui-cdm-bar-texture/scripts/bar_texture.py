#!/usr/bin/env python3
"""MiliUI_CooldownManager 自製的長條材質 Media/bar-glass.png（LSM 名「MiliUI Glass」）。

純灰階、不透明、沒有亂數：上緣一道高光往下壓到平台，下半段實色。遊戲裡 SetVertexColor 上色，
所以這裡只管明暗。要改高光亮度／平台亮度／高光多高就改下面三個常數再跑一次。

    cd AddOns/MiliUI_CooldownManager/Media && python3 ../../../.claude/skills/miliui-cdm-bar-texture/scripts/bar_texture.py
"""
from PIL import Image
import numpy as np

W, H = 256, 32          # StatusBar 會整張拉滿，寬度只是給取樣用
TOP = 190               # 上緣亮度（0～255）
BOTTOM = 168            # 平台亮度：高光壓到這裡之後一路到下緣都是它
KNEE = 0.5              # 高光佔多高（0.5 ＝ 上半段是漸層、下半段平的）
POWER = 1.6             # 漸層曲線：> 1 ＝ 一開始掉得快、接近平台時放緩

y = np.arange(H) / (H - 1)
t = np.clip(y / KNEE, 0, 1)
L = BOTTOM + (TOP - BOTTOM) * (1 - t) ** POWER
rows = np.repeat(L[:, None], W, axis=1)
rgba = np.dstack([rows, rows, rows, np.full((H, W), 255.0)]).round().astype(np.uint8)
Image.fromarray(rgba, "RGBA").save("bar-glass.png")
print("bar-glass.png", W, "x", H, "row luminance:", [int(round(v)) for v in L])
