#!/usr/bin/env python3
"""長條材質「MiliUI Ombre」（米利UI: 漸染）的直向明暗：Media/miliui_ombre.png。

漸染＝左端是更濃的職業色、右端是原本的職業色（2026-11-13 照使用者給的截圖量出來的）。**左右那道漸層不在圖裡**——
材質圖只能把顏色整體乘暗，做不出「變濃」，所以橫向是各插件用 Texture:SetGradient 給兩個顏色
（左＝每個通道取 2.6 次方、右＝原色 ×0.88，公式在各插件的 Core/Media.lua）。這張圖只管直向：
三成高的地方最亮、上緣略暗、下緣壓到 84%。純灰階、不透明、沒有亂數。

    python3 .claude/skills/miliui-satin-texture/scripts/ombre.py        # 在 repo 任何位置都可以
"""
import os
from PIL import Image
import numpy as np

W, H = 256, 32
# 直向亮度的控制點（y 由上到下 0～1 → 亮度 0～1），中間線性內插
STOPS_Y = [0.0, 0.3, 0.6, 1.0]
STOPS_L = [0.95, 1.0, 0.96, 0.84]
NAME = "miliui_ombre.png"

# 自帶這張圖的插件（接了雙色漸層的才列；Core/Media.lua 的路徑要跟這裡一致）
ADDONS = ["MiliUI_UnitFrames", "MiliUI_CooldownManager", "MiliUI_DamageMeters", "MiliUI_Tooltip", "Cell"]

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))

y = np.arange(H) / (H - 1)
L = np.interp(y, STOPS_Y, STOPS_L) * 255
rows = np.repeat(L[:, None], W, axis=1).round().astype(np.uint8)
im = Image.fromarray(np.dstack([rows, rows, rows]), "RGB")
for addon in ADDONS:
    out = os.path.join(REPO, "AddOns", addon, "Media", NAME)
    im.save(out)
    print("saved", os.path.relpath(out, REPO))
print("row luminance:", [int(round(v)) for v in L])
