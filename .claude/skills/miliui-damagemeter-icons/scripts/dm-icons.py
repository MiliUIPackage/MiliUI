#!/usr/bin/env python3
"""MiliUI_DamageMeters 標題列圖示（六款）。

技術限制：
  * 顯示尺寸 12~32px，預設 20px → 只能是「單一粗筆畫的幾何符號」，細節砍掉。
  * 貼在自己畫的深色標題列上（不是 3D 頭像）→ **不要深色描邊**。
    inspect-icons.py 那套「先畫大一號深色形狀」在這裡是反效果：
    在 20px 上描邊會把本體吃掉一半。
  * 插件用 SetVertexColor 染職業色 → 圖必須是**純白 + alpha**。
    鑰匙孔、齒輪軸孔一律**挖掉**（填全透明）而不是畫深色 ——
    畫深色染完會變成一塊不屬於配色的髒色。
  * 畫法：8 倍超取樣後 LANCZOS 縮到 128px。挖洞直接用 ImageDraw 填 (0,0,0,0)：
    PIL 的 ImageDraw 是**覆寫**像素不是合成，所以填全透明就等於挖掉。

────────────────────────────────────────────────────────────────────────
造型的三條規則（第二版重排。第一版「六款共用一個外框」看起來輕重不一）
────────────────────────────────────────────────────────────────────────

1. **留白是設計的一部分。** 圖示不該填滿整顆按鈕 —— PAD 佔畫布 21%，
   glyph 只有 58%。按鈕本身也比標題列矮（hdrIconSize 20 < hdrHeight 22），
   按鈕之間再留 2px。三層留白疊起來，一排圖示才不會看起來像貼滿的貼紙。

2. **光學等大 ≠ 幾何等大。** 同一個外框裡：
     圓看起來比方**小**    → 重置的環、齒輪要 overshoot（SCALE > 1）
     實心看起來比線條**大** → 直方圖要收進來（SCALE < 1）
     橫向展開的看起來寬     → 清單略收
   所以每一款帶自己的 SCALE，而不是共用一個外框。這是唯一能讓「一排圖示
   看起來一樣大」的辦法 —— 量尺寸是量不出來的。

3. **墨量要配平。** 直方圖是三塊實心、清單是三條細線，同樣大小下前者重得多。
   對策：直方圖的條畫瘦（縫比條寬）、齒輪的軸孔開大（實心圓盤 → 環），
   讓六款的黑色面積落在同一個帶子裡。
"""
import math

from PIL import Image, ImageDraw

OUT = 128            # 輸出邊長（2 的次方，WoW 才不會重新取樣）
SS = 8               # 超取樣倍率
S = OUT * SS         # 工作畫布

WHITE = (255, 255, 255, 255)
NONE = (0, 0, 0, 0)

PAD = 0.212 * S      # 內容框留白（規則 1）。0.18 → 0.212 = glyph 再縮 10%
BASE = S - 2 * PAD   # 基準外框；各款再乘自己的 SCALE
CX = CY = S / 2

# 筆畫粗細：六款共用，這是「同一套」的來源。
# ⚠ 綁在 BASE 而不是畫布 S：整套要縮放時只調 PAD 一個數字，比例自動保持。
# 綁 S 的話縮小外框會讓筆畫相對變粗，一整排看起來就從「小一號」變成「胖一號」。
W = 0.1375 * BASE


def box(scale):
    """回傳這一款的外框 (左, 上, 邊長)，置中。scale 是光學補償（規則 2）。"""
    size = BASE * scale
    return CX - size / 2, CY - size / 2, size


def canvas():
    return Image.new("RGBA", (S, S), NONE)


def disc(d, cx, cy, r, fill=WHITE):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def stroke(d, x1, y1, x2, y2, w=None, fill=WHITE):
    """圓端點直線。PIL 的 line 端點是方的，補兩顆圓才接得順。"""
    w = w or W
    d.line([x1, y1, x2, y2], fill=fill, width=int(round(w)))
    disc(d, x1, y1, w / 2, fill)
    disc(d, x2, y2, w / 2, fill)


def rrect(d, x1, y1, x2, y2, r=None, fill=WHITE):
    d.rounded_rectangle([x1, y1, x2, y2],
                        radius=int(round(r if r is not None else W / 2)), fill=fill)


def rot_rect(d, cx, cy, tang_w, rad_h, ang, fill=WHITE):
    """以 (cx,cy) 為中心的矩形：tang_w 沿切向、rad_h 沿 ang 的徑向。齒輪的齒用它。"""
    ca, sa = math.cos(ang), math.sin(ang)
    hx, hy = ca * rad_h / 2, sa * rad_h / 2
    wx, wy = -sa * tang_w / 2, ca * tang_w / 2
    d.polygon([(cx + hx + wx, cy + hy + wy), (cx + hx - wx, cy + hy - wy),
               (cx - hx - wx, cy - hy - wy), (cx - hx + wx, cy - hy + wy)], fill=fill)


def save(img, name):
    img.resize((OUT, OUT), Image.LANCZOS).save(name)
    print("wrote", name)


# ------------------------------------------------------------------ 統計類型
# 直方圖：三根不等高的直條。造型選它是因為**它就是這個插件在畫的東西**。
# SCALE 0.90：三塊實心會頂滿四個角，是六款裡墨量最重的，要收進來。
# 條也刻意畫瘦（0.20，不是均分的 0.33），縫比條寬，整體才透氣。
def meters(path):
    img = canvas()
    d = ImageDraw.Draw(img)
    x0, y0, box_s = box(0.90)

    bw = box_s * 0.20
    gap = (box_s - 3 * bw) / 2
    base = y0 + box_s
    for i, h in enumerate((0.55, 1.0, 0.76)):
        x = x0 + i * (bw + gap)
        rrect(d, x, base - box_s * h, x + bw, base, r=bw * 0.32)

    save(img, path)


# ------------------------------------------------------------------ 分段
# 清單：三條橫線 ＋ 前導點。跟直方圖是「橫 vs 直」的對比，20px 下分得出來，
# 不會像兩個格線圖示互相混淆。
# SCALE 0.96：橫向展開的形狀看起來偏寬，略收。
# 垂直只鋪到 0.84 而不是滿框 —— 三條線鋪滿會比其他款「高」。
def segments(path):
    img = canvas()
    d = ImageDraw.Draw(img)
    x0, y0, box_s = box(0.96)

    step = box_s * 0.84 / 2
    y_top = CY - step
    dot_r = W * 0.46
    x_dot = x0 + dot_r
    x_line = x_dot + dot_r + box_s * 0.17

    for i in range(3):
        y = y_top + i * step
        disc(d, x_dot, y, dot_r)
        stroke(d, x_line, y, x0 + box_s, y)

    save(img, path)


# ------------------------------------------------------------------ 重置
# 環形箭頭。SCALE 1.06：純圓形在同一個外框裡看起來最小，一定要 overshoot。
#
# 三個第一版做錯、看起來像「C 加一顆點」的地方：
#   * 缺口要夠大（這裡 95 度）—— 太小在 20px 下會糊成一個實心圓環
#   * 箭頭要明顯比筆畫寬 —— 跟筆畫一樣寬就只是圓環變厚
#   * 箭頭底邊要**往回退**壓在環的切口上 —— 切齊的話 arc 的方形切口會露出缺角
#   * 但也不能太寬：底邊往環外凸出太多就從箭頭變成一面旗子。
#     這裡底邊 2.0×筆畫、並且整體往圓心方向偏一點，讓它落在環的徑向帶裡；
#     鋒利度改由「拉長」而不是「加寬」來給。
def reset(path):
    img = canvas()
    d = ImageDraw.Draw(img)
    _, _, box_s = box(1.06)

    r = box_s / 2 - W / 2          # 外緣貼齊外框
    head_ang, tail_ang = -60, 35   # 度；PIL 的 0 度在三點鐘、順時針
    d.arc([CX - r, CY - r, CX + r, CY + r],
          start=tail_ang, end=360 + head_ang, fill=WHITE, width=int(round(W)))
    a = math.radians(tail_ang)
    disc(d, CX + r * math.cos(a), CY + r * math.sin(a), W / 2)   # 尾端補圓

    a = math.radians(head_ang)
    tx, ty = -math.sin(a), math.cos(a)     # 切線（順時針＝前進方向）
    nx, ny = math.cos(a), math.sin(a)      # 法線（往外）
    back, inward = W * 0.40, W * 0.12
    px = CX + r * math.cos(a) - tx * back - nx * inward
    py = CY + r * math.sin(a) - ty * back - ny * inward
    tip, half = W * 2.30, W * 1.00
    d.polygon([
        (px + tx * tip, py + ty * tip),
        (px + nx * half, py + ny * half),
        (px - nx * half, py - ny * half),
    ], fill=WHITE)

    save(img, path)


# ------------------------------------------------------------------ 設定
# 齒輪：六齒。SCALE 1.02 —— 含齒的剪影是圓，要 overshoot，但比純圓的重置少
# （齒讓它看起來已經比較滿）。
#
# 三個造型重點：
#   * 齒要「沿切向夠寬、沿徑向夠短」。最早那版把齒畫成細長的放射粗線，
#     剪影出來是一朵花不是齒輪 —— 齒輪之所以像齒輪，靠的是齒比縫寬而且很短。
#   * **六齒不是八齒。** 20px 下八齒每顆只剩約 2px，糊成一圈毛邊；
#     六齒每顆有 3px 多，才看得出是齒。齒數是「看得清楚」與「像齒輪」的取捨，
#     在這個尺寸六是下限也是最佳解。
#   * 軸孔開到 0.56：這一款本來是六款裡墨量最重的（實心圓盤 ＋ 八顆齒，
#     量出來是最輕那款的兩倍）。開大變成「環」才跟其他款配得起來（規則 3）。
def settings(path):
    img = canvas()
    d = ImageDraw.Draw(img)
    _, _, box_s = box(1.02)

    r_out = box_s / 2                             # 含齒的外緣
    r_body = r_out * 0.74
    teeth = 6
    t_w = 2 * math.pi * r_body / teeth * 0.52     # 切向寬：略大於縫
    t_h = (r_out - r_body) * 2.1                  # 徑向長：短
    t_r = r_body + (r_out - r_body) / 2 - t_h * 0.14

    for i in range(teeth):
        a = math.radians(i * 360 / teeth)
        rot_rect(d, CX + math.cos(a) * t_r, CY + math.sin(a) * t_r, t_w, t_h, a)

    disc(d, CX, CY, r_body)
    disc(d, CX, CY, r_body * 0.56, NONE)          # 軸孔：填全透明＝挖掉

    save(img, path)


# ------------------------------------------------------------------ 鎖定 / 未鎖
# 同一支函式畫兩款，差別只有鎖環的位置與右腿長度 —— 兩款必須是「同一把鎖」，
# 切換時才不會看起來像換了一顆按鈕。
#
# SCALE 0.98，而且**鎖身比外框窄**（0.74）：掛鎖是直立的東西，畫成接近正方形
# 會看起來又胖又重。吃滿外框的是「鎖環＋鎖身」的整體高度，不是寬度。
#
# 20px 下最容易壞的地方是「鎖環跟鎖身糊成一塊」→ 鎖環半徑要夠大、圓心要抬高，
# 兩者之間才留得出看得見的空隙。
def padlock(path, locked):
    img = canvas()
    d = ImageDraw.Draw(img)
    x0, y0, box_s = box(0.98)

    body_w = box_s * 0.74
    body_h = box_s * 0.50
    body_x1 = CX - body_w / 2
    body_y2 = y0 + box_s
    body_y1 = body_y2 - body_h
    rrect(d, body_x1, body_y1, body_x1 + body_w, body_y2, r=box_s * 0.11)

    sh_w = W * 0.78                       # 鎖環比鎖身筆畫細，視覺上才不會頭重
    sh_r = body_w * 0.33
    sh_cx = CX if locked else CX + body_w * 0.24
    sh_cy = body_y1 - sh_r * 0.38
    d.arc([sh_cx - sh_r, sh_cy - sh_r, sh_cx + sh_r, sh_cy + sh_r],
          start=180, end=360, fill=WHITE, width=int(round(sh_w)))

    leg = (body_y1 - sh_cy) + body_h * 0.10
    stroke(d, sh_cx - sh_r, sh_cy, sh_cx - sh_r,
           sh_cy + (leg if locked else sh_r * 0.95), w=sh_w)
    stroke(d, sh_cx + sh_r, sh_cy, sh_cx + sh_r,
           sh_cy + (leg if locked else sh_r * 0.20), w=sh_w)

    # 鑰匙孔：**挖掉**不是畫深色
    kh_r = body_h * 0.20
    kh_cy = body_y1 + body_h * 0.38
    disc(d, CX, kh_cy, kh_r, NONE)
    d.polygon([
        (CX - kh_r * 0.72, body_y2 - body_h * 0.18),
        (CX + kh_r * 0.72, body_y2 - body_h * 0.18),
        (CX + kh_r * 0.34, kh_cy),
        (CX - kh_r * 0.34, kh_cy),
    ], fill=NONE)

    save(img, path)


if __name__ == "__main__":
    meters("icon-meters.png")
    segments("icon-segments.png")
    reset("icon-reset.png")
    settings("icon-settings.png")
    padlock("icon-locked.png", True)
    padlock("icon-unlocked.png", False)
