#!/usr/bin/env python3
"""冷卻管理器「圖示形狀與陰影」的遮罩與陰影貼圖。

輸出（128×128，純白、只有透明度有內容）：
  shape-rounded.png   圓角方形遮罩（圓角半徑 ＝ 邊長 × ROUND_RATIO）
  shape-circle.png    圓形遮罩
  shadow-square.png   方形的模糊陰影
  shadow-rounded.png  圓角的模糊陰影
  shadow-circle.png   圓形的模糊陰影
  shadow-edge.png     長條的邊緣陰影（128×16、八格，backdrop 的 edgeFile 格式；見 edge_shadow()）

遊戲裡的用途（Core/Shape.lua）：
  * 遮罩：MaskTexture 的貼圖（圖示、邊框襯底、按鍵閃光、超出距離的暗影），
          以及 Cooldown:SetSwipeTexture（轉圈跟著形狀；方形不換）。
  * 陰影：圖示底下一張貼圖，SetVertexColor(0, 0, 0, 透明度)。
          陰影圖的中間 1 / (1 + 2 × SHADOW_PAD) 是「圖示（含邊框襯底）」本身，四邊各外擴 SHADOW_PAD 倍的邊長。
⚠ ROUND_RATIO 只在這裡；SHADOW_PAD 跟 Core/Shape.lua 的 SH.SHADOW_PAD 綁在一起，改一邊另一邊一起改。

遮罩的直邊貼齊貼圖邊（四角以外整片不透明）；圓形的外緣留半個像素（63.5），雙線性取樣在邊上才不會被切平。
4 倍超取樣、LANCZOS 縮回；透明的地方 RGB 也是白（濾波時邊緣不會滲出黑邊）。沒有亂數，同一份腳本跑出來的圖一模一樣。

跑法：cd 到 AddOns/MiliUI_CooldownManager/Media 再執行（用相對檔名存檔）。
      加 --debug 另外輸出 shadow-edge-debug.png（八格各一個顏色、不進版控），驗朝向用。
"""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 128                    # 輸出邊長（遊戲裡拉到格子大小；格子很少超過 64）
SS = 4                        # 超取樣倍率
ROUND_RATIO = 0.18            # 圓角半徑 ÷ 邊長
CIRCLE_EDGE = 0.5             # 圓形外緣離貼圖邊的距離（輸出像素）
SHADOW_PAD = 0.25             # 陰影四邊外擴（÷ 圖示邊長）；Core/Shape.lua 的 SH.SHADOW_PAD
SHADOW_SIGMA = 0.09           # 高斯模糊的半徑（÷ 圖示邊長）

# 長條的邊緣陰影（Core/Shape.lua 的 SH.EdgeShadow）
EDGE_CELL = 16                # 一格的邊長（貼圖像素）；八格橫排 ⇒ 128×16
EDGE_INSET = 1                # texcoord 每邊內縮 1 貼圖像素（暴雪 Backdrop.lua 的 coordStart＝1/16、x 的 1/128）
EDGE_FALLOFF = 3.0            # 衰減的陡度：alpha ＝ 正規化的 exp(−k·t²)，t＝離條身的距離（0 內緣～1 外緣）


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


# 八格的順序與朝向：照暴雪 SharedXML/Backdrop.lua 的 textureUVs（BackdropTemplateMixin）。
#   第 0～7 格：左邊、右邊、上邊、下邊、左上角、右上角、左下角、右下角（x 範圍 i/8 ～ (i+1)/8，各內縮 1/128）。
#   角與左右邊不旋轉：貼圖的上下左右＝螢幕的上下左右。
#   上下兩邊是旋轉過的：螢幕的「上→下」對應貼圖的「左→右」（UL＝(左, 底)、LL＝(右, 底)、UR＝(左, 頂)、LR＝(右, 頂)）。
#   ⇒ 內緣（貼著條身那一側）在貼圖上的位置：
#      左邊、上邊：右側       右邊、下邊：左側
#      左上：右下角  右上：左下角  左下：右上角  右下：左上角
# 內緣 alpha 1、外緣 0；角是以內角為圓心的放射衰減，跟兩條直邊在接縫處同值。
# 取樣範圍是格內 [EDGE_INSET, EDGE_CELL − EDGE_INSET]，範圍外的那一圈像素照邊界值補（雙線性濾波不吃到隔壁格）。
EDGE_INNER = [
    (1, None), (0, None), (1, None), (0, None),     # 1 ＝ 內緣在右（或下），0 ＝ 在左（或上）；None ＝ 這一軸不衰減
    (1, 1), (0, 1), (1, 0), (0, 0),
]
DEBUG_COLORS = [(255, 64, 64), (64, 255, 64), (64, 128, 255), (255, 255, 64),
                (255, 64, 255), (64, 255, 255), (255, 160, 32), (255, 255, 255)]


def falloff(t):
    t = min(max(t, 0.0), 1.0)
    e = math.exp(-EDGE_FALLOFF)
    return (math.exp(-EDGE_FALLOFF * t * t) - e) / (1 - e)


def edge_dist(u, inner):
    """格內座標 u（貼圖像素）到內緣的正規化距離：內緣 0、外緣 1"""
    span = EDGE_CELL - 2 * EDGE_INSET
    if inner == 1:
        return (EDGE_CELL - EDGE_INSET - u) / span
    return (u - EDGE_INSET) / span


def edge_shadow(debug=False):
    w, h = EDGE_CELL * 8, EDGE_CELL
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    px = img.load()
    for i, (ix, iy) in enumerate(EDGE_INNER):
        rgb = DEBUG_COLORS[i] if debug else (255, 255, 255)
        for y in range(h):
            for x in range(EDGE_CELL):
                acc = 0.0
                for sy in range(SS):
                    for sx in range(SS):
                        u = x + (sx + 0.5) / SS
                        v = y + (sy + 0.5) / SS
                        dx = max(0.0, edge_dist(u, ix))
                        dy = max(0.0, edge_dist(v, iy)) if iy is not None else 0.0
                        acc += falloff(math.hypot(dx, dy))
                a = acc / (SS * SS)
                if debug:
                    a = 0.35 + 0.65 * a          # 除錯圖：外緣也看得到顏色，才分得出是哪一格
                px[i * EDGE_CELL + x, y] = rgb + (int(round(a * 255)),)
    return img


def main():
    if "--debug" in sys.argv:
        edge_shadow(debug=True).save("shadow-edge-debug.png", optimize=True)
        print("shadow-edge-debug.png（除錯用，不要 commit）")
        return
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
    img = edge_shadow()
    img.save("shadow-edge.png", optimize=True)
    left = [img.getpixel((x, EDGE_CELL // 2))[3] for x in range(EDGE_CELL)]
    print("shadow-edge.png  左邊那格一列 alpha（外→內）%s" % left)


if __name__ == "__main__":
    main()
