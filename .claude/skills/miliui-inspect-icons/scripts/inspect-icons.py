#!/usr/bin/env python3
"""MiliUI 觀察按鈕圖示。

設計限制（決定了每一個造型決定）：
  * 實際顯示 25x25，圖案區只有 ~21px → 造型必須是「大色塊 + 粗筆畫」，細節一律砍掉
  * 貼在 3D 頭像上，背景可能是亮的、花的 → 每個形狀都要有深色描邊撐開對比
  * 要跟套組調性一致：扁平、白 + 少量青 (#4DD2FF)，不要漸層不要擬真

畫法：4 倍超取樣後 LANCZOS downsample，邊緣才不會鋸齒。
描邊用「先畫大一號的深色形狀，再疊上淺色本體」做出來。
"""
from PIL import Image, ImageDraw, ImageFilter

OUT = 128           # 輸出邊長
SS = 8              # 超取樣倍率
S = OUT * SS        # 工作畫布

LIGHT = (237, 239, 242, 255)   # 本體：帶一點冷調的白
DARK = (10, 10, 12, 230)       # 描邊：接近純黑，留一點透明避免死板
CYAN = (77, 210, 255, 255)     # 套組主色
GLASS = (77, 210, 255, 115)     # 鏡片內的淡青玻璃

STROKE = int(0.080 * S)        # 描邊厚度：無底框時它是唯一的分離手段，寧可粗


def canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def paste(base, layer):
    return Image.alpha_composite(base, layer)


def disc(d, cx, cy, r, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)


def ring(d, cx, cy, r, w, fill):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=fill, width=w)


def bar(d, x1, y1, x2, y2, w, fill):
    d.line([x1, y1, x2, y2], fill=fill, width=w)
    for x, y in ((x1, y1), (x2, y2)):        # 圓端點
        disc(d, x, y, w // 2, fill)


def bust(d, cx, cy, scale, fill):
    """頭 + 肩：肩線用一個被裁掉下半部的圓角矩形，比畫梯形自然。"""
    head_r = int(150 * scale)
    head_cy = cy - int(150 * scale)
    disc(d, cx, head_cy, head_r, fill)
    sw, sh = int(500 * scale), int(360 * scale)
    top = head_cy + head_r + int(40 * scale)
    d.rounded_rectangle([cx - sw // 2, top, cx + sw // 2, top + sh],
                        radius=int(230 * scale), fill=fill)
    # 把肩膀下緣切平（圓角矩形下半在按鈕裡會露出突兀的弧）
    d.rectangle([cx - sw // 2, top + sh - int(150 * scale), cx + sw // 2, top + sh], fill=fill)


def shadow(img):
    """整張圖往下投一層淡影：貼在亮背景上才不會糊成一片。"""
    a = img.split()[3].filter(ImageFilter.GaussianBlur(S * 0.028))
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh.putalpha(a.point(lambda v: int(min(255, v * 0.75))))
    off = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    off.paste(sh, (0, int(S * 0.018)))
    return paste(off, img)


def finish(img, name):
    img = shadow(img)
    img.resize((OUT, OUT), Image.LANCZOS).save(name)
    print("wrote", name)


# ---------------------------------------------------------------- 觀察者
# 一個人像 + 右下角一支放大鏡。兩個元素分佔不同區塊（不是套在一起），
# 縮到 21px 時各自都還看得出輪廓；疊在一起的版本在這個尺寸會糊成一團。
def inspector(path):
    img = canvas()

    # 深色描邊層：所有形狀先畫粗一號
    l = canvas()
    d = ImageDraw.Draw(l)
    bust(d, int(S * 0.37), int(S * 0.49), S / 1024 * 1.0, DARK)
    l = l.filter(ImageFilter.MaxFilter(1))
    img = paste(img, l)

    # 人像本體（稍微縮小，讓描邊從邊緣露出來）
    l = canvas()
    d = ImageDraw.Draw(l)
    bust(d, int(S * 0.37), int(S * 0.49), S / 1024 * 0.90, LIGHT)
    img = paste(img, l)

    gx, gy, gr = int(S * 0.70), int(S * 0.69), int(S * 0.225)
    gw = int(S * 0.075)

    # 放大鏡的描邊：把鏡框從人像上「挖」開，兩者才不會黏成一塊
    l = canvas()
    d = ImageDraw.Draw(l)
    bar(d, gx + int(gr * 0.72), gy + int(gr * 0.72),
        int(S * 0.90), int(S * 0.90), gw + STROKE, DARK)
    ring(d, gx, gy, gr, gw + STROKE, DARK)
    disc(d, gx, gy, gr - gw // 2, (14, 24, 30, 140))
    img = paste(img, l)

    # 鏡片玻璃 + 鏡框 + 握把
    l = canvas()
    d = ImageDraw.Draw(l)
    disc(d, gx, gy, gr - gw // 2, GLASS)
    ring(d, gx, gy, gr, gw, LIGHT)
    bar(d, gx + int(gr * 0.72), gy + int(gr * 0.72),
        int(S * 0.90), int(S * 0.90), gw, LIGHT)
    img = paste(img, l)

    finish(img, path)


# ---------------------------------------------------------------- 放大鏡
# 只有一支放大鏡，畫得大、筆畫粗，是三款裡最耐縮的
def glass(path):
    img = canvas()
    cx, cy, r = int(S * 0.44), int(S * 0.42), int(S * 0.30)
    w = int(S * 0.105)

    l = canvas()
    d = ImageDraw.Draw(l)
    bar(d, cx + int(r * 0.72), cy + int(r * 0.72),
        int(S * 0.88), int(S * 0.88), w + STROKE, DARK)
    ring(d, cx, cy, r, w + STROKE, DARK)
    disc(d, cx, cy, r - w // 2, (14, 24, 30, 140))
    img = paste(img, l)

    l = canvas()
    d = ImageDraw.Draw(l)
    disc(d, cx, cy, r - w // 2, GLASS)
    ring(d, cx, cy, r, w, LIGHT)
    bar(d, cx + int(r * 0.72), cy + int(r * 0.72),
        int(S * 0.88), int(S * 0.88), w, LIGHT)
    # 鏡片上的一道反光：純白細條，讓玻璃看起來是玻璃
    d.line([cx - int(r * 0.42), cy - int(r * 0.12),
            cx - int(r * 0.12), cy - int(r * 0.42)],
           fill=(255, 255, 255, 210), width=int(w * 0.42))
    img = paste(img, l)

    finish(img, path)


# ---------------------------------------------------------------- 圓底問號
# 深色圓底 + 白問號。以前這款是拿白方塊套圓形遮罩即時畫出來的，
# 但遮罩貼圖是外部資產、失敗又沒有錯誤（畫面只會停在上一款），
# 所以改成跟另外兩款一樣先畫成圖——同一條路徑、同一種失敗模式。
def roundmark(path):
    from PIL import ImageFont
    img = canvas()
    cx = cy = S // 2
    r = int(S * 0.40)

    l = canvas()
    d = ImageDraw.Draw(l)
    disc(d, cx, cy, r + STROKE, DARK)                 # 外圈描邊
    disc(d, cx, cy, r, (26, 28, 34, 235))             # 圓底
    ring(d, cx, cy, r - int(STROKE * 0.6), int(S * 0.018), (255, 255, 255, 40))  # 內緣一圈微亮
    img = paste(img, l)

    l = canvas()
    d = ImageDraw.Draw(l)
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", int(S * 0.62))
    # 用 anchor="mm" 對齊字的視覺中心：問號有下降部，照 bbox 置中會偏上
    d.text((cx, cy - int(S * 0.02)), "?", font=font, fill=LIGHT, anchor="mm",
           stroke_width=int(S * 0.022), stroke_fill=DARK)
    img = paste(img, l)

    finish(img, path)


if __name__ == "__main__":
    inspector("inspect-inspector.png")
    glass("inspect-glass.png")
    roundmark("inspect-round.png")
