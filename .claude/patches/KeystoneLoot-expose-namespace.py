#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""KeystoneLoot：把私有命名空間露成全域 `KeystoneLootNS` —— 上游更新後重新套用。

用法（在 Interface/ 底下跑）：

    python3 .claude/patches/KeystoneLoot-expose-namespace.py            # 套用
    python3 .claude/patches/KeystoneLoot-expose-namespace.py --check    # 只檢查

修什麼：`MiliUI/Enhance/KeystoneLoot_GearStats.lua`（視窗右上角的「裝備屬性計算」）要用
KeystoneLoot 的 `Upgrade:BuildItemLink` 與 `UpgradeTrackData` 組出「指定軌道／階級」的物品連結。
這些都掛在插件的私有命名空間上（`local AddonName, KeystoneLoot = ...`），公開的 `KeystoneLootAPI`
沒有這條路，從 MiliUI 掛勾拿不到 —— 所以在 `modules/api.lua` 結尾、`_G.KeystoneLootAPI = API;`
的下面多露一行 `_G.KeystoneLootNS = KeystoneLoot;`。功能本體全部在 MiliUI 那支，這裡只有這一行。

洗掉的症狀：不報錯，「裝備屬性計算」按鈕不再出現（那支在 PLAYER_LOGIN 檢查不到命名空間就整個不啟用）。

冪等：已經套過就什麼都不做。找不到錨點代表上游改了 api.lua 的結尾，印出來人工處理。
守門：`.claude/scripts/check_forks.py` 的 KeystoneLoot 那筆。
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TARGET = os.path.join(REPO, "AddOns", "KeystoneLoot", "modules", "api.lua")

ANCHOR = "_G.KeystoneLootAPI = API;\n"
MARK = "_G.KeystoneLootNS = KeystoneLoot;"
PATCH = (
    "\n"
    "-- fix from MiliUI: 把私有命名空間露給 MiliUI/Enhance/KeystoneLoot_GearStats.lua（裝備屬性計算）。\n"
    "-- 它要用 Upgrade:BuildItemLink 與軌道資料組出「指定軌道／階級」的物品連結，公開 API 沒有這條路。\n"
    "-- 這行被上游更新洗掉不會報錯，只是「裝備屬性計算」按鈕不再出現。\n"
    + MARK + "\n"
)


def main():
    check = "--check" in sys.argv
    if not os.path.isfile(TARGET):
        print("找不到 %s（KeystoneLoot 不在套組裡？）" % TARGET)
        return 1
    src = io.open(TARGET, encoding="utf-8", newline="").read()
    if MARK in src:
        print("KeystoneLoot/modules/api.lua：已套用。")
        return 0
    eol = "\r\n" if "\r\n" in src else "\n"
    anchor = ANCHOR.replace("\n", eol)
    if src.count(anchor) != 1:
        print("KeystoneLoot/modules/api.lua：找不到 `_G.KeystoneLootAPI = API;` 的錨點（出現 %d 次），"
              "上游改了這段，請人工處理。" % src.count(anchor))
        return 1
    if check:
        print("KeystoneLoot/modules/api.lua：修補不在，跑這支腳本重套。")
        return 1
    io.open(TARGET, "w", encoding="utf-8", newline="").write(
        src.replace(anchor, anchor + PATCH.replace("\n", eol)))
    print("KeystoneLoot/modules/api.lua：已重套 KeystoneLootNS。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
