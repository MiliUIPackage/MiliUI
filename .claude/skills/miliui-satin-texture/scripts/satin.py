#!/usr/bin/env python3
"""套組共用的長條材質「MiliUI Satin」：Media/miliui_satin.png，一次產到每一支自帶它的插件。

純灰階、不透明、沒有亂數：上緣一道高光往下壓到平台，下半段實色。遊戲裡 SetVertexColor 上色，
所以這裡只管明暗。要改高光亮度／平台亮度／高光多高就改下面的常數再跑一次。

    python3 .claude/skills/miliui-satin-texture/scripts/satin.py        # 在 repo 任何位置都可以

產出的位置照 ADDONS 這張表（單體發佈 ⇒ 每支自己帶一份，不跨插件引用路徑）。
"""
import os
from PIL import Image
import numpy as np

W, H = 256, 32          # StatusBar 會整張拉滿，寬度只是給取樣用
TOP = 190               # 上緣亮度（0～255）
BOTTOM = 168            # 平台亮度：高光壓到這裡之後一路到下緣都是它
KNEE = 0.5              # 高光佔多高（0.5 ＝ 上半段是漸層、下半段平的）
POWER = 1.6             # 漸層曲線：> 1 ＝ 一開始掉得快、接近平台時放緩
NAME = "miliui_satin.png"

# 自帶這張圖的插件（Core/Media.lua 或 Core/Tokens.lua 的路徑要跟這裡一致）
ADDONS = ["MiliUI_CooldownManager", "MiliUI_UnitFrames", "MiliUI_DamageMeters", "MiliUI_Tooltip", "MiliUI_Skin", "Cell"]

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))

y = np.arange(H) / (H - 1)
t = np.clip(y / KNEE, 0, 1)
L = BOTTOM + (TOP - BOTTOM) * (1 - t) ** POWER
rows = np.repeat(L[:, None], W, axis=1).round().astype(np.uint8)
im = Image.fromarray(np.dstack([rows, rows, rows]), "RGB")
for addon in ADDONS:
    out = os.path.join(REPO, "AddOns", addon, "Media", NAME)
    im.save(out)
    print("saved", os.path.relpath(out, REPO))
print("row luminance:", [int(round(v)) for v in L])
