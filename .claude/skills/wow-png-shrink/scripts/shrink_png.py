#!/usr/bin/env python3
"""把 WoW 插件的 PNG 壓到最小，同時保住遊戲裡看得出來的畫質。

預設是乾跑（只報告不寫檔），要真的覆蓋加 --apply。

三個手段依序套用，每一步都量測過才決定要不要用：
  1. 去掉沒在用的 alpha 通道（全 255 才動）—— 像素完全不變
  2. 縮到 --max-width（要自己指定，因為只有你知道顯示區多大）
  3. ±N 階雜訊吸附 —— 只有省超過 --denoise-gain 才套，否則保持像素相同

需要 Pillow / numpy / scipy，以及 oxipng（brew install oxipng）。
zopflipng（brew install zopfli）有裝就會多試一輪，沒裝不影響。
"""

import argparse
import os
import shutil
import struct
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image
from scipy.ndimage import gaussian_filter, median_filter

# WoW 的貼圖載入器實測吃 8-bit 的 RGB / RGBA / 調色盤，非交錯。
# 16-bit 與交錯沒驗過，一律不要產生。
SAFE_COLOR_TYPES = {2: "RGB", 3: "PALETTE", 6: "RGBA"}


# ---------------------------------------------------------------- 量測

def ssim(a, b):
    """標準 SSIM，對每個通道各算一次再平均。"""
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    out = []
    for c in range(a.shape[2]):
        x, y = a[..., c], b[..., c]
        blur = lambda z: gaussian_filter(z, 1.5, truncate=3.5)
        mx, my = blur(x), blur(y)
        vx, vy = blur(x * x) - mx * mx, blur(y * y) - my * my
        vxy = blur(x * y) - mx * my
        out.append((((2 * mx * my + c1) * (2 * vxy + c2))
                    / ((mx * mx + my * my + c1) * (vx + vy + c2))).mean())
    return float(np.mean(out))


def compare(a_img, b_img):
    """回傳 (PSNR, SSIM, 最大單通道差)。兩張圖尺寸必須一樣。"""
    a = np.asarray(a_img.convert("RGB"), dtype=np.float64)
    b = np.asarray(b_img.convert("RGB"), dtype=np.float64)
    d = a - b
    mse = float((d * d).mean())
    psnr = float("inf") if mse == 0 else 10 * np.log10(255.0 ** 2 / mse)
    return psnr, ssim(a, b), int(np.abs(d).max())


def compare_at(a_img, b_img, size):
    """兩張都先縮到 size 再比 —— 這才是玩家在顯示區看到的東西。

    判斷「縮圖會不會掉畫質」一定要用這個，不能拿原尺寸直接比：
    原尺寸比的是「有沒有丟像素」（一定有），顯示尺寸比的才是「看不看得出來」。
    """
    return compare(a_img.convert("RGB").resize(size, Image.LANCZOS),
                   b_img.convert("RGB").resize(size, Image.LANCZOS))


# ---------------------------------------------------------------- 手段

def drop_dead_alpha(im):
    """alpha 全不透明就轉成 RGB。省掉四分之一的原始資料量，像素不變。

    有真的在用的 alpha 就原封不動 —— 不要為了壓縮把透明區的 RGB 清成 0
    （zopflipng --lossy_transparent 會這麼做）：遊戲用雙線性取樣，
    透明像素的 RGB 會被鄰近的不透明像素採到，邊緣會出現黑邊。
    """
    if im.mode != "RGBA":
        return im, False
    if np.asarray(im.getchannel("A")).min() == 255:
        return im.convert("RGB"), True
    return im, False


def denoise(im, tol):
    """3x3 中位數，但只在偏差 <= tol 時吸附到中位數。

    邊緣與文字的相鄰差異遠大於 tol，所以完全不動 —— 被抹掉的只有遊戲渲染
    留下的散粒雜訊。這是壓縮率的來源：雜訊讓 PNG 的行預測器失效。
    tol=2 時最大色偏 2/255，PSNR 通常在 50 dB 以上，肉眼看不出來。

    有 alpha 就只處理 RGB，A 原封不動（動到 A 會改變邊緣形狀）。
    """
    has_alpha = im.mode == "RGBA"
    a = np.asarray(im.convert("RGBA") if has_alpha else im.convert("RGB"))
    rgb = a[..., :3]
    med = median_filter(rgb, size=(3, 3, 1), mode="nearest")
    diff = med.astype(np.int16) - rgb.astype(np.int16)
    out = np.where(np.abs(diff) <= tol, med, rgb).astype(np.uint8)
    if has_alpha:
        out = np.dstack([out, a[..., 3]])
        return Image.fromarray(out, "RGBA")
    return Image.fromarray(out, "RGB")


# ---------------------------------------------------------------- 編碼

def encode(im, path, zopfli_timeout):
    """寫檔並用能拿到的最強無損編碼器壓一輪。

    oxipng 預設會自作主張改色彩型別，實測會吐出 1-bit 調色盤與 8-bit 灰階
    （拿平面色與灰階內容各測一張就看得到）—— 這兩種在遊戲裡都沒驗過。
    所以：
      --nb  擋掉位元深度縮減，保證留在 8-bit
      調色盤放行（Cell 的 mvp.png 實證可用，而且這裡的轉換是無損的）
      灰階事後補救：真的變灰階就加 --nc 重壓一次
    """
    im.save(path, "PNG", optimize=True, compress_level=9)
    if shutil.which("oxipng"):
        base = ["oxipng", "-o", "max", "--zopfli", "--strip", "safe", "-q", "--nb"]
        subprocess.run(base + [path], capture_output=True)
        hdr = png_header(path)
        if hdr and hdr[3] in (0, 4):        # 灰階 / 灰階+A
            im.save(path, "PNG", optimize=True, compress_level=9)
            subprocess.run(base + ["--nc", path], capture_output=True)
    if shutil.which("zopflipng") and zopfli_timeout > 0:
        alt = path + ".z"
        before = png_header(path)
        try:
            subprocess.run(["zopflipng", "--filters=e", "--iterations=20", "-y", path, alt],
                           capture_output=True, timeout=zopfli_timeout)
            # zopflipng 沒有「保持色彩型別」的旗標，所以改了型別就不採用
            if (os.path.exists(alt)
                    and os.path.getsize(alt) < os.path.getsize(path)
                    and png_header(alt) and png_header(alt)[2:5] == before[2:5]):
                os.replace(alt, path)
        except subprocess.TimeoutExpired:
            pass
        if os.path.exists(alt):
            os.remove(alt)
    return os.path.getsize(path)


def png_header(path):
    with open(path, "rb") as fh:
        head = fh.read(33)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h, bd, ct, _, _, inter = struct.unpack(">IIBBBBB", head[16:29])
    return w, h, bd, ct, inter


def check_safe(path):
    """輸出必須是遊戲載得動的格式，不然壓得再小也是白搭。"""
    hdr = png_header(path)
    if hdr is None:
        return "不是 PNG"
    _, _, bd, ct, inter = hdr
    if bd != 8:
        return f"{bd}-bit（只能 8-bit）"
    if ct not in SAFE_COLOR_TYPES:
        return f"色彩型別 {ct}"
    if inter:
        return "交錯式"
    return None


# ---------------------------------------------------------------- 主流程

def process(src, args, tmpdir):
    name = os.path.basename(src)
    orig_size = os.path.getsize(src)
    orig = Image.open(src)
    orig_dim = orig.size
    notes = []

    staged, dropped = drop_dead_alpha(orig)
    if dropped:
        notes.append("去 alpha")

    # 縮圖：只有超過 --max-width 才動，而且要能整除成 2:1 之類的原比例
    resize_metrics = None
    if args.max_width and staged.size[0] > args.max_width:
        target = (args.max_width, round(staged.size[1] * args.max_width / staged.size[0]))
        smaller = staged.convert(staged.mode).resize(target, Image.LANCZOS)
        # 在「實際顯示尺寸」下比對，那才是玩家看到的
        display = args.display or (target[0] // 2, target[1] // 2)
        resize_metrics = compare_at(staged, smaller, display)
        staged = smaller
        notes.append(f"縮到 {target[0]}x{target[1]}")

    # 候選 A：從這裡開始像素完全不變
    pa = os.path.join(tmpdir, "a.png")
    sa = encode(staged, pa, args.zopfli_timeout)

    # 候選 B：雜訊吸附
    pb = os.path.join(tmpdir, "b.png")
    sb = encode(denoise(staged, args.denoise_tol), pb, args.zopfli_timeout)

    gain = (sa - sb) / sa if sa else 0
    if gain >= args.denoise_gain:
        pick, size, path = f"去雜訊±{args.denoise_tol}", sb, pb
        metrics = compare(staged, Image.open(pb))
    else:
        pick, size, path = "無損", sa, pa
        metrics = compare(staged, Image.open(pa))

    problem = check_safe(path)
    return {
        "name": name, "src": src, "out": path, "problem": problem,
        "orig_size": orig_size, "size": size, "pick": pick,
        "orig_dim": orig_dim, "dim": staged.size,
        "notes": notes, "metrics": metrics, "resize_metrics": resize_metrics,
        "lossless_size": sa, "denoise_size": sb,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("paths", nargs="+", help="PNG 檔或含 PNG 的資料夾")
    p.add_argument("--apply", action="store_true", help="真的覆蓋原檔（預設只報告）")
    p.add_argument("--max-width", type=int, default=0,
                   help="超過這個寬度就等比縮下來。不給就不縮 —— "
                        "只有你知道遊戲裡的顯示區多大，別亂猜")
    p.add_argument("--display", type=lambda s: tuple(map(int, s.split("x"))), default=None,
                   help="實際顯示尺寸如 420x210，用來驗證縮圖有沒有掉畫質。"
                        "預設取 --max-width 的一半（即當成 2 倍圖）")
    p.add_argument("--denoise-tol", type=int, default=2,
                   help="雜訊吸附的容許色階，預設 2（肉眼不可見）。0 = 完全不做")
    p.add_argument("--denoise-gain", type=float, default=0.05,
                   help="雜訊吸附至少要省這個比例才採用，預設 0.05")
    p.add_argument("--zopfli-timeout", type=int, default=45,
                   help="每張圖給 zopflipng 的秒數上限，0 = 不跑")
    args = p.parse_args()

    files = []
    for path in args.paths:
        if os.path.isdir(path):
            files += [os.path.join(path, f) for f in sorted(os.listdir(path))
                      if f.lower().endswith(".png")]
        elif path.lower().endswith(".png"):
            files.append(path)
    if not files:
        sys.exit("找不到 PNG")

    if not shutil.which("oxipng"):
        print("！ 沒裝 oxipng，壓縮率會差很多：brew install oxipng\n", file=sys.stderr)

    print(f"{'檔案':<30} {'原始':>9} {'無損':>9} {'去雜訊':>9} {'採用':>9}  手段")
    print("-" * 96)

    results, tot_o, tot_n = [], 0, 0
    with tempfile.TemporaryDirectory() as tmpdir:
        for f in files:
            r = process(f, args, tmpdir)
            results.append(r)
            tot_o += r["orig_size"]
            tot_n += r["size"]
            psnr, ssim_v, maxd = r["metrics"]
            desc = "、".join(r["notes"] + [r["pick"]])
            print(f"{r['name']:<30} {r['orig_size']:>9} {r['lossless_size']:>9} "
                  f"{r['denoise_size']:>9} {r['size']:>9}  {desc}")
            if r["orig_dim"] != r["dim"]:
                rp, rs, rm = r["resize_metrics"]
                print(f"{'':<30}   {r['orig_dim'][0]}x{r['orig_dim'][1]} → "
                      f"{r['dim'][0]}x{r['dim'][1]}，顯示尺寸下 "
                      f"PSNR={rp:.1f} SSIM={rs:.5f} 最大差={rm}")
            if maxd:
                print(f"{'':<30}   像素 PSNR={psnr:.1f} SSIM={ssim_v:.5f} 最大差={maxd}")
            if r["problem"]:
                print(f"{'':<30}   ！ 格式有問題：{r['problem']}")

            if args.apply and not r["problem"]:
                shutil.copyfile(r["out"], r["src"])

        print("-" * 96)
        pct = 100 * tot_n / tot_o if tot_o else 0
        print(f"合計 {tot_o/1048576:.2f} MB → {tot_n/1048576:.2f} MB"
              f"（{pct:.1f}%，省 {(tot_o-tot_n)/1048576:.2f} MB）")

    bad = [r for r in results if r["problem"]]
    if bad:
        print(f"\n！ {len(bad)} 張格式不合格，已跳過沒有寫入")
    if not args.apply:
        print("\n這是乾跑。確認上面的數字沒問題再加 --apply 覆蓋。")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
