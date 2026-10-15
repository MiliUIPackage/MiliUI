"""洋紅底／綠底去背（從四角自動判斷） → 裁成正方 → 128px。

用法：python3 -I key.py [--fill-enclosed] 輸出名=輸入檔 ...   （輸出到目前目錄的 out/，會自動建）

--fill-enclosed：主體顏色接近底色（洋紅底上的紫色）時用。被黑框整圈包住的像素一定是主體，
  從四邊往內灌不到的地方一律改成不透明、顏色用原圖。前提是外框連續封閉；預設關，
  開了會改變結果，舊圖重跑不要加。2026-10-16 術士職業圖的紫火焰（16% 被吃成半透明）用它救回。
"""
import sys
import numpy as np
from PIL import Image

OUT = 128
LO, HI = 60, 190      # 背景色度：<=LO 全不透明，>=HI 全透明
# 背景色度的算法：洋紅＝min(R,B)-G；綠＝G-max(R,B)。紫色主體配綠底、綠色主體配洋紅底。
KEYS = {
    "magenta": (np.array([255, 0, 255], np.float32), lambda R, G, B: np.minimum(R, B) - G),
    "green":   (np.array([0, 255, 0], np.float32),   lambda R, G, B: G - np.maximum(R, B)),
}

def detect(a):
    c = np.concatenate([a[:16, :16].reshape(-1, 3), a[:16, -16:].reshape(-1, 3),
                        a[-16:, :16].reshape(-1, 3), a[-16:, -16:].reshape(-1, 3)]).mean(0)
    return "green" if c[1] > max(c[0], c[2]) else "magenta"
PAD = 0.04            # 裁切留白（佔邊長）

def strip_frame(a, score):
    """Gemini 偶爾會自己加一圈外框：沿四邊的幾條取樣線往內走到第一個洋紅像素，裁掉外框。"""
    mag = score(a[..., 0], a[..., 1], a[..., 2]) > 150
    h, w = mag.shape
    samples = [int(h * f) for f in (.1, .3, .5, .7, .9)]
    def inset(line):
        idx = np.flatnonzero(line)
        return int(idx[0]) if idx.size else 0
    # 外框是一圈均勻的邊 → 每一邊取所有取樣線的**最小值**。
    # 取最大值的話，主體貼到畫面邊緣（例：龍脖子出血到右下角）會被當成外框，一路裁到只剩一角。
    top = min(inset(mag[:, x]) for x in samples)
    bot = min(inset(mag[::-1, x]) for x in samples)
    lef = min(inset(mag[y, :]) for y in samples)
    rig = min(inset(mag[y, ::-1]) for y in samples)
    cap = int(min(h, w) * 0.08)   # 外框不會比這厚；超過就是主體，不裁
    top, bot, lef, rig = (v if v <= cap else 0 for v in (top, bot, lef, rig))
    if max(top, bot, lef, rig) == 0:
        return a
    m = 6  # 多裁幾像素，吃掉外框和洋紅交界的 JPEG 雜訊
    return a[top + m:h - bot - m, lef + m:w - rig - m]

def fill_enclosed(rgba, raw):
    from scipy import ndimage
    a = rgba[..., 3].astype(np.float32) / 255
    # 不完全不透明的像素裡，跟畫面邊緣連通的才是背景（含外框外側的抗鋸齒）
    soft = a < 0.98
    lab, _ = ndimage.label(soft)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    outside = np.isin(lab, list(border))
    # 被包住、但幾乎全透明的那一塊是真的洞（手腕與火焰之間透出的底色），保持透明；
    # 洞邊緣幾個像素的抗鋸齒也照原本的算法，不然洞會鑲一圈洋紅邊
    holes = (a < 0.15) & ~outside
    near_hole = ndimage.binary_dilation(holes, iterations=max(2, a.shape[0] // 300))
    inner = soft & ~outside & ~near_hole
    rgba[inner, :3] = np.clip(raw[inner], 0, 255).astype(np.uint8)
    rgba[inner, 3] = 255
    return rgba

FILL_ENCLOSED = False

def key(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    # 有外框時四角是框的顏色，判不出來 → 用畫面內縮 6% 的位置取樣
    inset = int(a.shape[0] * 0.06)
    kind = detect(a[inset:-inset, inset:-inset])
    M, score = KEYS[kind]
    a = strip_frame(a, score)
    R, G, B = a[..., 0], a[..., 1], a[..., 2]
    m = score(R, G, B)
    alpha = np.clip((HI - m) / (HI - LO), 0, 1)
    # 反混色：觀察值 = α·前景 + (1-α)·洋紅 → 解出前景，去掉邊緣的紫暈
    al = np.maximum(alpha, 1e-3)[..., None]
    fg = np.clip((a - (1 - alpha[..., None]) * M) / al, 0, 255)
    fg[alpha < 1e-3] = 0
    rgba = np.dstack([fg, alpha * 255]).astype(np.uint8)
    if FILL_ENCLOSED:
        rgba = fill_enclosed(rgba, a)
    return Image.fromarray(rgba, "RGBA")

def square_crop(im):
    l, t, r, b = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    side = max(r - l, b - t)
    side = int(side * (1 + 2 * PAD))
    cx, cy = (l + r) / 2, (t + b) / 2
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im.crop((l, t, r, b)), (int(side / 2 - (r - l) / 2), int(side / 2 - (b - t) / 2)))
    return canvas

def shrink(im, px):
    # 預乘 alpha 再縮，透明區的黑色才不會滲進邊緣
    return im.convert("RGBa").resize((px, px), Image.LANCZOS).convert("RGBA")

import os
os.makedirs("out", exist_ok=True)
args = sys.argv[1:]
if "--fill-enclosed" in args:
    FILL_ENCLOSED = True
    args.remove("--fill-enclosed")
for arg in args:
    name, src = arg.split("=", 1)
    big = square_crop(key(src))
    big.save(f"out/{name}-full.png")
    shrink(big, OUT).save(f"out/{name}.png")
    print(name, big.size)
