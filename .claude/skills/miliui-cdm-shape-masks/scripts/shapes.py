#!/usr/bin/env python3
"""冷卻管理器「圖示形狀與陰影」的遮罩與陰影貼圖。

輸出（128×128，純白、只有透明度有內容）：
  shape-rounded.png   圓角方形遮罩（圓角半徑 ＝ 邊長 × ROUND_RATIO）
  shape-circle.png    圓形遮罩
  shadow-square.png   方形的模糊陰影
  shadow-rounded.png  圓角的模糊陰影
  shadow-circle.png   圓形的模糊陰影

遊戲裡的用途（Core/Shape.lua）：
  * 遮罩：MaskTexture 的貼圖（圖示、邊框襯底、按鍵閃光、超出距離的暗影），
          以及 Cooldown:SetSwipeTexture（轉圈跟著形狀；方形不換）。
  * 陰影：圖示底下一張貼圖，SetVertexColor(0, 0, 0, 透明度)。
          陰影圖的中間 1 / (1 + 2 × SHADOW_PAD) 是「圖示（含邊框襯底）」本身，四邊各外擴 SHADOW_PAD 倍的邊長。
⚠ ROUND_RATIO 只在這裡；SHADOW_PAD 跟 Core/Shape.lua 的 SH.SHADOW_PAD 綁在一起，改一邊另一邊一起改。

遮罩的直邊貼齊貼圖邊（四角以外整片不透明）；圓形的外緣留半個像素（63.5），雙線性取樣在邊上才不會被切平。
4 倍超取樣、LANCZOS 縮回；透明的地方 RGB 也是白（濾波時邊緣不會滲出黑邊）。沒有亂數，同一份腳本跑出來的圖一模一樣。

跑法：cd 到 AddOns/MiliUI_CooldownManager/Media 再執行（用相對檔名存檔）。
"""
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128                    # 輸出邊長（遊戲裡拉到格子大小；格子很少超過 64）
SS = 4                        # 超取樣倍率
ROUND_RATIO = 0.18            # 圓角半徑 ÷ 邊長
CIRCLE_EDGE = 0.5             # 圓形外緣離貼圖邊的距離（輸出像素）
SHADOW_PAD = 0.25             # 陰影四邊外擴（÷ 圖示邊長）；Core/Shape.lua 的 SH.SHADOW_PAD
SHADOW_SIGMA = 0.09           # 高斯模糊的半徑（÷ 圖示邊長）


def shape_alpha(kind, box, size):
    """在 size×size（已超取樣）的畫布上，box（x0, y0, x1, y1）裡畫一個實心的形狀"""
    a = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(a)
    x0, y0, x1, y1 = box
    if kind == "circle":
        d.ellipse(box, fill=255)
    elif kind == "rounded":
        r = (x1 - x0) * ROUND_RATIO
        d.rounded_rectangle(box, radius=r, fill=255)
    else:
        d.rectangle(box, fill=255)
    return a


def to_white(alpha):
    img = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def mask(kind):
    big = SIZE * SS
    if kind == "circle":
        e = CIRCLE_EDGE * SS
        box = (e, e, big - e, big - e)
    else:
        box = (0, 0, big - 1, big - 1)
    a = shape_alpha(kind, box, big).resize((SIZE, SIZE), Image.LANCZOS)
    return to_white(a)


def shadow(kind):
    big = SIZE * SS
    inner = big / (1 + 2 * SHADOW_PAD)          # 圖示本身在陰影圖裡的邊長（超取樣後）
    o = (big - inner) / 2
    a = shape_alpha(kind, (o, o, o + inner, o + inner), big)
    a = a.filter(ImageFilter.GaussianBlur(SHADOW_SIGMA * inner))
    a = a.resize((SIZE, SIZE), Image.LANCZOS)
    return to_white(a)


def main():
    for kind in ("rounded", "circle"):
        name = "shape-%s.png" % kind
        mask(kind).save(name, optimize=True)
        print(name)
    for kind in ("square", "rounded", "circle"):
        name = "shadow-%s.png" % kind
        img = shadow(kind)
        img.save(name, optimize=True)
        edge = max(img.getpixel((0, SIZE // 2))[3], img.getpixel((SIZE // 2, 0))[3])
        print("%s  邊緣 alpha %d" % (name, edge))
    print("圓角半徑 %.2f px／%d（%.0f%%）  陰影外擴 %.0f%%" % (SIZE * ROUND_RATIO, SIZE, ROUND_RATIO * 100, SHADOW_PAD * 100))


if __name__ == "__main__":
    main()
