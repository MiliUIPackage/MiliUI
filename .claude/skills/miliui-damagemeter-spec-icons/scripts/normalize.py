"""統一 40 張的視覺大小。用法：python3 -I normalize.py <final 資料夾> <輸出資料夾>

讀 final/<key>-full.png（去背後的高解析原圖），輸出 <輸出>/<key>.png（128px）。

視覺份量 v = 0.5·sqrt(覆蓋率) + 0.5·sqrt(外框矩形面積)。只看覆蓋率的話細長的矛會被算得太小。
縮放 s = (中位數 / v) ^ 0.8 —— 打八折：圓滾滾的圖本來就該比細長的飽滿一點，完全拉平反而怪。
上限：長邊最多填到畫布 98%（原本 93%，等於吃掉邊距）；圖不能更大，否則主體會被切掉。
"""
import sys, os, glob
import numpy as np
from PIL import Image

SRC, DST = sys.argv[1], sys.argv[2]
OUT, DAMP, FILL_MAX = 128, 0.8, 0.98
os.makedirs(DST, exist_ok=True)

def measure(a):
    al = np.asarray(a.getchannel("A")).astype(np.float32) / 255
    n = al.shape[0]
    ys, xs = np.where(al > 0.1)
    bw, bh = (xs.max() - xs.min() + 1) / n, (ys.max() - ys.min() + 1) / n
    return 0.5 * np.sqrt(al.mean()) + 0.5 * np.sqrt(bw * bh), max(bw, bh), (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)

items = {}
for f in sorted(glob.glob(os.path.join(SRC, "*-full.png"))):
    im = Image.open(f).convert("RGBA")
    items[os.path.basename(f)[:-9]] = (im, *measure(im))
target = float(np.median([v for _, v, _, _ in items.values()]))

for k, (im, v, longest, box) in items.items():
    s = min((target / v) ** DAMP, FILL_MAX / longest)
    n = im.size[0]
    crop = im.crop(box)                                   # 主體的緊外框
    w, h = crop.size
    side = n                                              # 畫布維持原尺寸，主體依 s 縮放後置中
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    body = crop.convert("RGBa").resize((nw, nh), Image.LANCZOS).convert("RGBA")
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(body, ((side - nw) // 2, (side - nh) // 2))
    canvas.save(os.path.join(DST, f"{k}-full.png"))
    canvas.convert("RGBa").resize((OUT, OUT), Image.LANCZOS).convert("RGBA").save(os.path.join(DST, f"{k}.png"))
    print(f"{k:24s} v={v:.3f} 縮放 {s:.3f}")
print("中位數", round(target, 3))
