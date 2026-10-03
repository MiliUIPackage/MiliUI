#!/usr/bin/env python3
"""MiliUI_CooldownManager 預覽格的範圍記號（自訂項目的戰隊層／職業層）。

設計限制（決定了每一個造型決定）：
  * 實際顯示 8x8（10x10 的黑底框內縮 1px）→ 只能是一個粗輪廓，細節一律砍掉
  * 底是 Lua 畫的黑色方塊，圖案是**純白**，遊戲裡用 SetVertexColor 染色
    （職業層染職業色、戰隊層維持白）→ 不畫描邊、不畫陰影、不用第二個顏色
  * 跟套組調性一致：扁平、直角（盾牌下緣的尖角除外）

  scope-shared.png  戰隊：兩個並排的人像（前大後小），讀成「一群人」
  scope-class.png   職業：盾牌

畫法：8 倍超取樣後 LANCZOS 縮到 64px（WoW 的貼圖邊長要是 2 的次方）。
"""
from PIL import Image, ImageDraw

OUT = 64            # 輸出邊長
SS = 8              # 超取樣倍率
S = OUT * SS        # 工作畫布
WHITE = (255, 255, 255, 255)


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def disc(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def bust(d, cx, top, scale, fill):
    """頭＋肩：肩是一個下緣切平的圓角矩形。top 是頭頂的 y，scale 是相對整張的比例。"""
    head_r = int(0.15 * S * scale)
    head_cy = top + head_r
    disc(d, cx, head_cy, head_r, fill)
    sw = int(0.56 * S * scale)
    sh = int(0.40 * S * scale)
    st = head_cy + head_r + int(0.035 * S * scale)
    d.rounded_rectangle([cx - sw // 2, st, cx + sw // 2, st + sh], radius=int(0.22 * S * scale), fill=fill)
    d.rectangle([cx - sw // 2, st + sh // 2, cx + sw // 2, st + sh], fill=fill)


def shared(path):
    img = canvas()
    d = ImageDraw.Draw(img)
    # 後面那個（右上、小一點）先畫，前面那個（左下、大）蓋上去；中間留一道透明縫分開兩個輪廓
    bust(d, int(0.68 * S), int(0.06 * S), 0.78, WHITE)
    gap = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(gap)
    bust(gd, int(0.38 * S), int(0.14 * S), 1.0 * 1.12, 255)       # 大一號的輪廓當縫
    img.putalpha(Image.composite(Image.new("L", (S, S), 0), img.split()[3], gap))
    d = ImageDraw.Draw(img)
    bust(d, int(0.38 * S), int(0.18 * S), 1.0, WHITE)
    img.resize((OUT, OUT), Image.LANCZOS).save(path)
    print("wrote", path)


def klass(path):
    img = canvas()
    d = ImageDraw.Draw(img)
    # 盾牌：上緣平、兩側直、下半收成尖角
    l, r = int(0.14 * S), int(0.86 * S)
    t, mid, b = int(0.08 * S), int(0.52 * S), int(0.94 * S)
    cx = S // 2
    d.polygon([(l, t), (r, t), (r, mid), (cx, b), (l, mid)], fill=WHITE)
    # 不挖中線：8px 下那道縫讀起來像驚嘆號（試過），實心的盾牌輪廓反而一眼認得
    img.resize((OUT, OUT), Image.LANCZOS).save(path)
    print("wrote", path)


if __name__ == "__main__":
    shared("scope-shared.png")
    klass("scope-class.png")
