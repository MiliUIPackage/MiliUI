#!/usr/bin/env python3
"""冷卻管理器「圓環顯示」的環形貼圖。

輸出 ring-01.png ～ ring-20.png：256×256，純白、只有透明度有內容的抗鋸齒圓環。
遊戲裡同一張圖當兩種用途：
  * 軌道（深色底環）：我們自己框上的貼圖，SetVertexColor 染軌道色
  * 進度：暴雪 Cooldown 的 SetSwipeTexture，SetSwipeColor 染填色

SetSwipeTexture 會把貼圖拉滿整個 Cooldown ⇒ 環的粗細跟直徑成正比。同心圓要每圈「像素粗細一樣」，
所以每圈依 環寬 / 直徑 挑一張最接近的：這裡的第 j 張，環寬比例（環寬 ÷ 直徑）是
  RATIO_MIN × (RATIO_MAX / RATIO_MIN) ^ ((j − 1) / (STEPS − 1))    j ＝ 1 … STEPS
等比級數（細環與粗環的相對誤差一樣大）。
⚠ 這組常數跟 Core/Layout.lua 的 RING_STEPS／RING_MIN／RING_MAX 綁在一起，改一邊另一邊一起改。

外緣半徑留半個像素（127.5）：外緣剛好貼齊貼圖邊的話，雙線性取樣在邊上會被切平。
4 倍超取樣、畫完 LANCZOS 縮回來；沒有亂數，同一份腳本跑出來的圖一模一樣（git 才會乾淨）。

跑法：cd 到 AddOns/MiliUI_CooldownManager/Media 再執行（用相對檔名存檔）。
"""
from PIL import Image, ImageDraw

STEPS = 20
RATIO_MIN, RATIO_MAX = 0.02, 0.30
SIZE = 256                    # 輸出邊長（遊戲裡會被拉到圈的直徑；最大的圈也不過一兩百像素）
SS = 4                        # 超取樣倍率
EDGE = 0.5                    # 外緣離貼圖邊的距離（輸出像素）


def ratio(j):
    """第 j 張（1 起算）的環寬比例：環寬 ÷ 直徑"""
    return RATIO_MIN * (RATIO_MAX / RATIO_MIN) ** ((j - 1) / (STEPS - 1))


def ring(r):
    big = SIZE * SS
    c = big / 2
    outer = (SIZE / 2 - EDGE) * SS
    # 環寬以「直徑 ＝ 整張圖」計：直徑 SIZE 的圈，環寬 r × SIZE
    inner = max(0.0, outer - r * SIZE * SS)
    a = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(a)
    d.ellipse((c - outer, c - outer, c + outer, c + outer), fill=255)
    if inner > 0:
        d.ellipse((c - inner, c - inner, c + inner, c + inner), fill=0)
    a = a.resize((SIZE, SIZE), Image.LANCZOS)
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    img.putalpha(a)
    return img


def main():
    for j in range(1, STEPS + 1):
        name = "ring-%02d.png" % j
        ring(ratio(j)).save(name, optimize=True)
        print("%s  ratio %.4f" % (name, ratio(j)))


if __name__ == "__main__":
    main()
