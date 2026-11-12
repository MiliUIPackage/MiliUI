#!/usr/bin/env python3
"""長條材質「MiliUI Ombre」（米利UI: 漸染）的兩張圖，一次產到每一支接了它的插件。

漸染＝左端是更濃的顏色、右端是原色，**用材質疊出來**（疊法與原因見 AddOns/MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua 檔尾）：

  miliui_ombre.png        登記進 LibSharedMedia 的那張、下拉預覽鋪的也是它：左暗右亮的灰階橫向漸層 × 直向明暗。
                          疊層蓋在它上面，平常看不到；最右一行（只剩直向明暗）被疊層拿來當底。
  miliui_ombre_ramp.png   疊層最上面那張：RGB＝直向明暗 ×0.88，alpha 左端 10% → 右端 100%。

直向明暗：三成高最亮、上緣略暗、下緣壓到 84%。沒有亂數。

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
RAMP_NAME = "miliui_ombre_ramp.png"

# 自帶這張圖的插件（接了雙色漸層的才列；Core/Media.lua 的路徑要跟這裡一致）
ADDONS = ["MiliUI_UnitFrames", "MiliUI_CooldownManager", "MiliUI_DamageMeters", "MiliUI_Tooltip", "Cell"]

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".."))

LEFT = 90 / 255          # miliui_ombre.png 左端亮度（右端固定 1.0：疊層取最右一行當底）
RAMP_A0 = 0.10           # 頂層左端的不透明度（留一點原色，三次方才不會太死）
RAMP_RGB = 0.88          # 頂層亮度＝右端看到的原色亮度

y = np.arange(H) / (H - 1)
x = np.arange(W) / (W - 1)
V = np.interp(y, STOPS_Y, STOPS_L)
base = (np.outer(V, LEFT + (1 - LEFT) * x) * 255).round().astype(np.uint8)
rgb = np.repeat((V * RAMP_RGB * 255)[:, None], W, axis=1)
alpha = np.repeat(((RAMP_A0 + (1 - RAMP_A0) * x) * 255)[None, :], H, axis=0)
ramp = np.dstack([rgb, rgb, rgb, alpha]).round().astype(np.uint8)
for addon in ADDONS:
    d = os.path.join(REPO, "AddOns", addon, "Media")
    Image.fromarray(np.dstack([base, base, base]), "RGB").save(os.path.join(d, NAME))
    Image.fromarray(ramp, "RGBA").save(os.path.join(d, RAMP_NAME))
    print("saved", os.path.relpath(d, REPO))
