"""預覽板。用法：python3 -I board.py 輸出檔 職業色R,G,B key=標籤 ...（圖從 out/<key>-full.png 讀）"""
import sys
from PIL import Image, ImageDraw, ImageFont
F = "/System/Library/Fonts/STHeiti Medium.ttc"
font, small = ImageFont.truetype(F, 22), ImageFont.truetype(F, 15)
OUTFILE = sys.argv[1]
CLS = tuple(int(v) for v in sys.argv[2].split(","))
keys = [tuple(a.split("=", 1)) for a in sys.argv[3:]]

def shrink(im, px):
    return im.convert("RGBa").resize((px, px), Image.LANCZOS).convert("RGBA")

def checker(w, h, a=(200, 200, 200), b=(235, 235, 235), s=8):
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(0, h, s):
        for x in range(0, w, s):
            d.rectangle([x, y, x + s - 1, y + s - 1], fill=a if (x // s + y // s) % 2 else b)
    return im

board = Image.new("RGBA", (1000, 40 + 160 * len(keys) + 200), (40, 40, 44, 255))
d = ImageDraw.Draw(board)
y = 20
for k, label in keys:
    full = Image.open(f"out/{k}-full.png")
    ic = Image.open(f"out/{k}.png")
    d.text((20, y + 50), label, fill=(230, 230, 230), font=font)
    # 128 直接放在板子的灰底上（透明）
    board.alpha_composite(ic, (90, y))
    # 棋盤底 128（看去背乾不乾淨）
    ck = checker(128, 128); ck.alpha_composite(ic)
    board.alpha_composite(ck, (230, y))
    # 24 / 20 實際大小 ×4 放大
    x = 370
    for px in (24, 20):
        sm = shrink(full, px)
        t = checker(px, px, s=2); t.alpha_composite(sm)   # 小圖也看透明，不墊深底
        board.alpha_composite(t.resize((px * 4, px * 4), Image.NEAREST), (x, y))
        d.text((x, y + px * 4 + 2), f"{px}px ×4", fill=(160, 160, 160), font=small)
        x += px * 4 + 20
    # 原寸 24 / 20
    for px in (24, 20):
        sm = shrink(full, px)
        board.alpha_composite(sm, (x, y + 40))
        x += px + 14
    y += 160

# 長條模擬（原寸）：列高 24 與 20
names = ["1. 終極狩獵", "2. 修加-恐濤", "3. 梅瑞迪-尋湧", "4. 嘉里克船長"]
rows = [(k, names[i % 4], 1.0 - i * 0.22) for i, (k, _) in enumerate(keys)]
for H, x0 in ((24, 20), (20, 510)):
    d.text((x0, y), f"列高 {H}px（原寸，圖示格的深底由程式畫）", fill=(200, 200, 200), font=small)
    yy = y + 24
    f = ImageFont.truetype(F, H - 8)
    for k, txt, frac in rows:
        board.alpha_composite(Image.new("RGBA", (460, H), (0, 0, 0, 120)), (x0, yy))
        d.rectangle([x0 + H, yy, x0 + H + int((460 - H) * frac), yy + H - 1], fill=CLS)
        board.alpha_composite(Image.new("RGBA", (H, H), (14, 14, 14, 255)), (x0, yy))   # 模擬 SetColorTexture 的深底
        board.alpha_composite(shrink(Image.open(f"out/{k}-full.png"), H), (x0, yy))
        d.text((x0 + H + 5, yy + 3), txt, fill=(255, 255, 255), font=f, stroke_width=1, stroke_fill=(0, 0, 0))
        yy += H + 2
board.convert("RGB").save(OUTFILE)
