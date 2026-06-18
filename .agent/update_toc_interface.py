#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
update_toc_interface.py  —  一鍵更新所有插件 .toc 的「## Interface:」正式服版本號

================================ 這支程式在做什麼 ================================
魔獸世界正式服(_retail_)每次改版後，插件 .toc 檔開頭的：

    ## Interface: 120005

如果沒跟上新版本號，遊戲就會把插件標成「已過期 / Out of date」。
這支程式會掃描 AddOns/*/*.toc，把裡面的「正式服版本號」自動換成目前版本
(預設 120007)，讓所有插件一次跟上，不用一個一個手動改。

================================ 版本號規則(重要) ================================
.toc 的 ## Interface: 後面可以放「一串」版本號，用逗號分隔，例如：

    ## Interface: 120005, 50503, 40402, 30404, 20505, 11508
                  └正式服┘  └─────────── 各經典服 ───────────┘

每個數字代表一個「遊戲版本(flavor)」，數字 = 主版本*10000 + 次版本*100 + 修訂：
    11508  → 經典舊世 1.15.8 (Classic Era / Vanilla)
    20505  → 燃燒的遠征 2.5.5 (TBC Classic)
    30404  → 巫妖王 3.4.4   (Wrath Classic)
    40402  → 大地的裂變 4.4.2 (Cata Classic)
    50503  → 潘達利亞 5.5.3   (MoP Classic)
    120007 → 正式服 12.0.7   ← 這支程式只動「正式服」這一個

判斷方法：版本號 >= 100000 (見下方 RETAIL_THRESHOLD) 就是「正式服」，
其餘小於 100000 的都是經典服，程式「完全不動」它們，避免弄壞多版本相容的插件。

================================ 處理邏輯 ================================
對每個 AddOns/*/*.toc：
  1. 找出第一行 ## Interface: 指令。
  2. 把後面的版本號拆開分類成「正式服」與「經典服」。
  3. 若這行「沒有任何正式服版本號」(純經典服 .toc，例如 Cell_Mists.toc) → 跳過不動。
  4. 若有 → 把所有正式服版本號「合併成單一個目標版本(120007)」，放回原本第一個
     正式服版本號的位置，經典服版本號維持原順序原樣。
        例：110207,120000,120005,11508,20505,50503
          → 120007, 11508, 20505, 50503
  5. 只有「內容真的有變」才會寫檔；並且逐檔保留原本的換行字元(LF / CRLF)，
     不動其他任何一行，確保 git diff 乾淨。

================================ 以後改版怎麼用 ================================
下次正式服又更新(例如變成 120010)時，只要：

    # 先預覽會改哪些檔(不會動到檔案)
    python3 update_toc_interface.py 120010 --dry-run

    # 確認沒問題後正式執行
    python3 update_toc_interface.py 120010

不帶版本號時，會用下方 DEFAULT_RETAIL_VERSION 的預設值。
也可以乾脆把 DEFAULT_RETAIL_VERSION 改成新版本號，之後直接跑：

    python3 update_toc_interface.py

其他參數：
    --dry-run            只預覽、不寫檔
    --addons-dir <路徑>  指定 AddOns 資料夾(預設會自動往上層尋找 AddOns)

本程式建議放在 .agent/ 目錄(該目錄已在 .gitattributes 標為 export-ignore，
打包/匯出插件時會被排除)。AddOns 資料夾會從本程式位置往上層自動尋找，
所以放在 Interface 根目錄或 .agent/ 內都能正常運作。
"""

import argparse
import os
import re
import sys

# ----------------------------- 可調整設定 -----------------------------

# 目前正式服版本號。改版後把這裡改成新版本，或執行時用參數覆寫。
DEFAULT_RETAIL_VERSION = 120007

# 版本號 >= 此門檻 = 正式服；以下 = 經典服(不會被更動)。
# 正式服自 10.0 起為 100000+，經典服最高僅到 5.x(50xxx)，門檻 100000 可乾淨切開。
RETAIL_THRESHOLD = 100000

# 比對 ## Interface: 這行(大小寫不拘、容許多餘空白)。
# 用 \s*: 結尾，因此不會誤判 ## Interface-Cata: 這類其他版本專用指令。
INTERFACE_RE = re.compile(r"^(##\s*Interface\s*:)(.*)$", re.IGNORECASE)


# ----------------------------- 核心邏輯 -----------------------------

def rebuild_interface_value(raw_value, target):
    """
    輸入 ## Interface: 後面的原始字串，回傳 (新的版本字串, 是否有正式服版本號)。
    - 沒有正式服版本號 → 回傳 (None, False)，呼叫端據此跳過。
    - 有 → 正式服版本號全部合併成單一 target，放在原本第一個正式服的位置，
      經典服版本號維持原順序。
    """
    tokens = [t.strip() for t in raw_value.split(",")]
    tokens = [t for t in tokens if t != ""]

    has_retail = False
    result = []
    retail_done = False
    for tok in tokens:
        if tok.isdigit() and int(tok) >= RETAIL_THRESHOLD:
            has_retail = True
            if not retail_done:           # 第一個正式服版本號 → 放入目標版本
                result.append(str(target))
                retail_done = True
            # 其餘正式服版本號一律略過(合併)
        else:
            result.append(tok)            # 經典服 / 非數字 → 原樣保留

    if not has_retail:
        return None, False
    return ", ".join(result), True


def process_file(path, target, dry_run):
    """
    處理單一 .toc。回傳狀態字串：
      'changed'      已更新(或 dry-run 下「將更新」)
      'unchanged'    有正式服版本號但已是最新，無需更動
      'skip-classic' 純經典服 .toc，無正式服版本號 → 不動
      'skip-noiface' 找不到 ## Interface: 指令 → 不動
    另回傳 (舊行, 新行) 供顯示(無變更時為 None)。
    """
    with open(path, "rb") as f:
        data = f.read()

    text = data.decode("utf-8-sig")       # 容忍 BOM；寫回時不會再加 BOM
    lines = text.splitlines(keepends=True)  # 保留每行原本的換行字元

    for i, line in enumerate(lines):
        # 拆出行尾換行字元，單獨保留
        stripped = line.rstrip("\r\n")
        newline = line[len(stripped):]

        m = INTERFACE_RE.match(stripped)
        if not m:
            continue

        new_value, has_retail = rebuild_interface_value(m.group(2), target)
        if not has_retail:
            return "skip-classic", None

        new_line_content = "## Interface: " + new_value
        if new_line_content == stripped:
            return "unchanged", None

        if not dry_run:
            lines[i] = new_line_content + newline
            with open(path, "wb") as f:
                f.write("".join(lines).encode("utf-8"))
        return "changed", (stripped, new_line_content)

    return "skip-noiface", None


def find_addons_dir():
    """
    從本程式所在資料夾往上層尋找，回傳第一個含「AddOns」子資料夾者底下的 AddOns 路徑。
    如此不論本程式放在 Interface 根目錄或 .agent/ 內，都能正確定位 AddOns。
    """
    here = os.path.dirname(os.path.abspath(__file__))
    cur = here
    while True:
        candidate = os.path.join(cur, "AddOns")
        if os.path.isdir(candidate):
            return candidate
        parent = os.path.dirname(cur)
        if parent == cur:          # 已到檔案系統根仍找不到
            break
        cur = parent
    return os.path.join(here, "AddOns")  # 退回同層，交由後續錯誤訊息提示


def find_toc_files(addons_dir):
    """只取 AddOns/<插件>/<檔名>.toc 這一層，不含插件內部 Libs 的巢狀 .toc。"""
    result = []
    for entry in sorted(os.listdir(addons_dir)):
        addon_path = os.path.join(addons_dir, entry)
        if not os.path.isdir(addon_path):
            continue
        for name in sorted(os.listdir(addon_path)):
            if name.lower().endswith(".toc"):
                result.append(os.path.join(addon_path, name))
    return result


def main():
    parser = argparse.ArgumentParser(
        description="更新所有插件 .toc 的正式服 ## Interface: 版本號",
    )
    parser.add_argument("version", nargs="?", type=int, default=DEFAULT_RETAIL_VERSION,
                        help="目標正式服版本號(預設 %(default)s)")
    parser.add_argument("--dry-run", action="store_true",
                        help="只預覽不寫檔")
    parser.add_argument("--addons-dir", default=None,
                        help="AddOns 資料夾路徑(預設會從本程式位置往上層自動尋找)")
    args = parser.parse_args()

    if args.addons_dir:
        addons_dir = args.addons_dir
    else:
        addons_dir = find_addons_dir()

    if not os.path.isdir(addons_dir):
        print(f"找不到 AddOns 資料夾：{addons_dir}", file=sys.stderr)
        return 1

    target = args.version
    toc_files = find_toc_files(addons_dir)

    changed, unchanged, skip_classic, skip_noiface = [], [], [], []
    for path in toc_files:
        status, detail = process_file(path, target, args.dry_run)
        rel = os.path.relpath(path, os.path.dirname(addons_dir))
        if status == "changed":
            changed.append((rel, detail))
        elif status == "unchanged":
            unchanged.append(rel)
        elif status == "skip-classic":
            skip_classic.append(rel)
        else:
            skip_noiface.append(rel)

    mode = "預覽(未寫檔)" if args.dry_run else "已套用"
    print(f"目標正式服版本：{target}　模式：{mode}")
    print(f"掃描 .toc：{len(toc_files)} 個\n")

    if changed:
        print(f"── {'將更新' if args.dry_run else '已更新'} {len(changed)} 個 ──")
        for rel, (old, new) in changed:
            print(f"  {rel}")
            print(f"      舊: {old}")
            print(f"      新: {new}")
        print()

    print(f"已是最新、無需更動：{len(unchanged)} 個")
    print(f"純經典服 .toc(略過)：{len(skip_classic)} 個")
    if skip_noiface:
        print(f"找不到 ## Interface: (略過)：{len(skip_noiface)} 個 -> {skip_noiface}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
