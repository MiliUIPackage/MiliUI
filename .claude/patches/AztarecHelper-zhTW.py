# -*- coding: utf-8 -*-
"""AztarecHelper 繁中化補丁 —— 上游更新後重新套用。

用法（在 Interface/ 底下跑）：

    python3 .claude/patches/AztarecHelper-zhTW.py AddOns/AztarecHelper

流程：
  1. 把上游新版整包覆蓋進 AddOns/AztarecHelper
  2. 把 Media/zhTW/ 放回去（中文語音，不在上游包裡）
  3. 跑這支
  4. 補回 .toc 的 MiliUI 區塊（Title-zhTW / Notes-zhTW / Category-zhTW）
  5. luac -p 過一次

沒命中的對照會列出來 —— 那就是上游改過字的地方，逐一重翻，然後把新的對照補進
AztarecHelper-zhTW.json。已經翻過的不會重複套用（會先檢查譯文在不在）。

**不能翻譯的三處**（碰了會壞）：
  * AZT.QUAD_DIR ── 同時是 NPE_Arrow%s 貼圖集後綴，也是隊長報點送出去的約定字串
  * 報點 payload ── 戰鬥中是 secret value，只能原封不動轉手，不能檢查也不能翻
  * TURNS 的 stay/left/forward/right ── 音效檔名與旋轉角度表的 key

語音：Media/zhTW/{forward,left,right,stay}.mp3＝往前／往左／往右／不要動，
macOS `say -v Meijia -r 185` 產生，再用 ffmpeg 去頭尾靜音、壓縮、峰值正規化到
-1.5 dBFS（對齊上游英文檔的響度）。Core/Cues.lua 依 GetLocale() 選資料夾。

另外這份補丁也帶著一個非翻譯的本地修改：把上游正式版空的 AZT.Log 接到
AztarecHelperDB.log（/azt log）。SafeSpots 的事件處理器整個包在 pcall 裡，
沒有這個的話出事完全靜音。
"""
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else "AddOns/AztarecHelper"
    data = json.load(io.open(os.path.join(HERE, "AztarecHelper-zhTW.json"), encoding="utf-8"))
    pairs, regions = data["pairs"], data["regions"]
    os.chdir(target)

    fails, applied = [], 0
    for path in sorted(set(list(pairs) + list(regions))):
        if not os.path.exists(path):
            fails.append((path, "檔案不存在", ""))
            continue
        s = io.open(path, encoding="utf-8").read()
        for start, end, rep in regions.get(path, []):
            if rep in s:
                continue  # 已經套過了
            if start in s and end in s:
                s = s[: s.index(start)] + rep + s[s.index(end) + 1 :]
                applied += 1
            else:
                fails.append((path, "區塊錨點找不到", start))
        for old, new in pairs.get(path, []):
            if new in s:
                continue  # 已經套過了
            if s.count(old) == 1:
                s = s.replace(old, new)
                applied += 1
            else:
                fails.append((path, "命中 %d 次" % s.count(old), old))
        io.open(path, "w", encoding="utf-8").write(s)

    print("已套用 %d 處，未命中 %d 處" % (applied, len(fails)))
    for path, why, what in fails:
        head = what.strip().splitlines()[0][:90] if what else ""
        print("  [%s] %s :: %s" % (path, why, head))
    if fails:
        print("\n^ 這些是上游改過字的地方，去新版原始碼找到對應段落重翻，再補進 json。")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
