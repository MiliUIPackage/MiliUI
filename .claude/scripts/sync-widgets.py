#!/usr/bin/env python3
"""把 MiliUIWidgets 共用層從本體同步到各消費插件。

    python3 .claude/scripts/sync-widgets.py           同步，並列出改了哪幾份
    python3 .claude/scripts/sync-widgets.py --check   只檢查有沒有漂移（有就回傳 1）

MiliUIWidgets 是 **vendor 包，不是 LibStub 函式庫**：每個插件各帶一份、各跑各的，
所以單獨發佈時玩家只會下載到一個資料夾。代價是同一份程式碼躺在 10 個地方 ——
這支腳本就是用來讓那個代價變成零的：原始碼的唯一來源是
`AddOns/MiliUI/Libs/MiliUIWidgets/`，改那裡再跑這支。

⚠ `Env.lua` **每個插件都不一樣**（宿主接點），永遠不同步。
⚠ 沒有那個檔案的插件不會被塞進去 —— 只更新它已經帶著的那幾支。
   要讓某支插件開始用新模組，先手動複製一次（或在下面的 SEED 加一筆）。
"""

import filecmp
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")
SRC = os.path.join(ADDONS, "MiliUI", "Libs", "MiliUIWidgets")

# 逐字複製的檔案。Env.lua 不在裡面 —— 那是宿主接點。
VERBATIM = [
    "Secret.lua",
    "Errors.lua",
    "Metro.lua",
    "PixelPerfect.lua",
    "Widgets.lua",
    "ContextMenu.lua",
    "Controls.lua",
    "BlizzOptions.lua",
    "README.md",
]

NEVER = {"Env.lua"}


def consumers():
    for name in sorted(os.listdir(ADDONS)):
        if name == "MiliUI" or not name.startswith("MiliUI"):
            continue
        d = os.path.join(ADDONS, name, "Libs", "MiliUIWidgets")
        if os.path.isdir(d):
            yield name, d


def main():
    check = "--check" in sys.argv
    if not os.path.isdir(SRC):
        print(f"找不到共用層原始碼：{SRC}")
        return 1

    drift, missing, extra = [], [], []

    for addon, dest in consumers():
        have = {f for f in os.listdir(dest) if f.endswith((".lua", ".md"))}
        for name in VERBATIM:
            src = os.path.join(SRC, name)
            dst = os.path.join(dest, name)
            if not os.path.exists(src):
                continue
            if not os.path.exists(dst):
                # 這支插件還沒帶這個模組 —— 不主動塞，只報告
                missing.append(f"{addon}/{name}")
                continue
            if not filecmp.cmp(src, dst, shallow=False):
                drift.append(f"{addon}/{name}")
                if not check:
                    shutil.copy2(src, dst)
        for name in sorted(have - set(VERBATIM) - NEVER):
            extra.append(f"{addon}/{name}")

    if drift:
        print(("落後" if check else "已更新") + f" {len(drift)} 份：")
        for x in drift:
            print(f"  {x}")
    if missing:
        print(f"\n沒帶這些模組的插件（要用就手動複製一次，之後這支腳本才管得到）：")
        for x in missing:
            print(f"  {x}")
    if extra:
        print(f"\n⚠ 消費端有、來源沒有的檔案（改錯地方了？）：")
        for x in extra:
            print(f"  {x}")

    if not drift and not extra:
        print("共用層一致。" + (f"（{len(missing)} 個模組尚未鋪到所有插件）" if missing else ""))

    if check:
        return 1 if (drift or extra) else 0
    return 1 if extra else 0


if __name__ == "__main__":
    sys.exit(main())
