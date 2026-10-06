#!/usr/bin/env python3
"""天空騎術面板「旋轉急衝」長條滿的時候的閃電序列圖（FlipBook）。

輸出 skyriding-lightning.png：1024×128，2 欄 × 4 列 ＝ 8 格，每格 512×32，由左而右、由上而下播放。
圖案是純白（遊戲裡 SetVertexColor 染成長條色、ADD 混色），所以這裡只畫亮度與透明度。

每一格是一道橫跨整格的閃電（中點位移法）＋一兩條分岔，外面一圈模糊的光暈。
最後兩格是餘暉（變暗、變細）：動畫播完接一段停頓，看起來就是「啪一下、消散、再啪一下」。
固定亂數種子：同一份腳本跑出來的圖一模一樣（git 才會乾淨）。

跑法：cd 到 AddOns/MiliUI_CooldownManager/Media 再執行（用相對檔名存檔）。
"""
import math
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SEED = 20261006
COLS, ROWS = 2, 4
FW, FH = 512, 32              # 一格的尺寸（遊戲裡會被拉到長條的寬高；16:1 接近長條的比例，垂直的鋸齒才不會被壓平）
SS = 4                        # 超取樣倍率，畫完 LANCZOS 縮回來
OUT = "skyriding-lightning.png"

# 每一格的強度（1 ＝ 全亮）：前六格是六道不同的閃電，後兩格是最後一道的餘暉
INTENSITY = [1.0, 0.95, 1.0, 0.9, 1.0, 0.95, 0.55, 0.22]


def bolt(rng, x0, y0, x1, y1, rough, depth, decay=0.62):
    """中點位移：回傳折線的點列。rough 是第一層的最大垂直位移（像素）。
    decay 越大，細節（高頻的鋸齒）越多——閃電要尖，所以比一般的地形雜訊大"""
    pts = [(x0, y0), (x1, y1)]
    disp = rough
    for _ in range(depth):
        nxt = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            mx, my = (ax + bx) / 2, (ay + by) / 2
            dx, dy = bx - ax, by - ay
            ln = math.hypot(dx, dy) or 1
            nx, ny = -dy / ln, dx / ln
            d = rng.uniform(-disp, disp)
            # 偶爾一個大折角：閃電的「拐一下」
            if rng.random() < 0.12:
                d *= 2.2
            nxt.append((mx + nx * d, my + ny * d))
            nxt.append((bx, by))
        pts = nxt
        disp *= decay
    return pts


def fit_y(groups, lo, hi):
    """整組點列（主幹＋分岔）等比縮進 [lo, hi]——不硬夾（硬夾會在邊上壓出一段直線）"""
    ys = [y for pts in groups for _, y in pts]
    ymin, ymax = min(ys), max(ys)
    mid, span = (ymin + ymax) / 2, (ymax - ymin) or 1
    k = min(1.0, (hi - lo) / span)
    c = (lo + hi) / 2
    return [[(x, c + (y - mid) * k) for x, y in pts] for pts in groups]


def frame(rng, strength):
    w, h = FW * SS, FH * SS
    cy = h / 2
    margin = h * 0.14
    main = bolt(rng, -0.02 * w, cy + rng.uniform(-0.1, 0.1) * h,
                1.02 * w, cy + rng.uniform(-0.1, 0.1) * h, h * 0.55, 9)
    groups, widths = [main], [1.0]

    # 分岔：從主幹上某一點往右前方斜岔出去，短、細、更尖
    for _ in range(rng.choice([1, 2, 2, 3])):
        i = rng.randrange(len(main) // 8, len(main) * 7 // 8)
        sx, sy = main[i]
        length = rng.uniform(0.06, 0.18) * w
        up = rng.choice([-1, 1])
        ex, ey = sx + length, sy + up * rng.uniform(0.25, 0.45) * h
        groups.append(bolt(rng, sx, sy, ex, ey, h * 0.18, 6, 0.6))
        widths.append(0.5)
    groups = fit_y(groups, margin, h - margin)
    lines = list(zip(groups, widths))

    def draw(width_px, alpha):
        layer = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(layer)
        for pts, k in lines:
            d.line(pts, fill=int(255 * alpha), width=max(1, round(width_px * k * strength + 0.4)), joint=None)
        return layer

    glow = draw(6 * SS, 0.8).filter(ImageFilter.GaussianBlur(3 * SS))
    halo = draw(3 * SS, 0.9).filter(ImageFilter.GaussianBlur(1 * SS))
    core = draw(1.2 * SS, 1.0)
    a = ImageChops.add(ImageChops.add(glow, halo), core)
    a = a.point(lambda v: int(min(255, v * strength)))
    img = Image.merge("RGBA", (Image.new("L", (w, h), 255),) * 3 + (a,))
    return img.resize((FW, FH), Image.LANCZOS)


def main():
    rng = random.Random(SEED)
    sheet = Image.new("RGBA", (FW * COLS, FH * ROWS), (255, 255, 255, 0))
    last = None
    for n, s in enumerate(INTENSITY):
        if s < 0.6 and last is not None:
            # 餘暉：拿最後一道全亮的閃電調暗（不是新的一道），看起來才像同一道在消散
            r, g, b, a = last.split()
            f = Image.merge("RGBA", (r, g, b, a.point(lambda v: int(v * s))))
        else:
            f = frame(rng, s)
            last = f
        x, y = (n % COLS) * FW, (n // COLS) * FH
        sheet.paste(f, (x, y))
    sheet.save(OUT, optimize=True)
    print("wrote", OUT, sheet.size)


if __name__ == "__main__":
    main()
