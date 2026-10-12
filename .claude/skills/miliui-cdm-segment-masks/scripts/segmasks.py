#!/usr/bin/env python3
"""層數列透明格距的 REPEAT 遮罩：segmask-<den>.png（512×8，左邊不透明、右端 1/den 透明）。

在 AddOns/MiliUI_CooldownManager/Media/ 底下跑。den 清單跟 Modules/AuraBar.lua 的 MASK_DENS 一致。
"""
from PIL import Image

W, H = 512, 8
DENS = [2, 4, 8, 16, 32, 64, 128]

for den in DENS:
    clear = W // den
    im = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    px = im.load()
    for x in range(W - clear, W):
        for y in range(H):
            px[x, y] = (255, 255, 255, 0)
    name = f"segmask-{den}.png"
    im.save(name, optimize=True)
    print(f"{name}: 不透明 {W - clear} 欄、透明 {clear} 欄")
