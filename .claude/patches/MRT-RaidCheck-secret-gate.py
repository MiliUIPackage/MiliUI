#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MRT：RaidCheck.lua 的光環秘密值閘 —— 上游更新後重新套用。

用法（在 Interface/ 底下跑）：

    python3 .claude/patches/MRT-RaidCheck-secret-gate.py            # 套用
    python3 .claude/patches/MRT-RaidCheck-secret-gate.py --check    # 只檢查

修什麼：`CheckPotionsOnPull` 掛在 ENCOUNTER_START 後 1.5 秒，正好是光環變秘密的時候；
12.1 的 `C_UnitAuras.GetAuraDataByIndex` 在光環為秘密時**直接拋錯而不是回 nil**，
迴圈裡的 `issecretvalue(auraData.spellId)` 永遠等不到。閘必須在呼叫之前。

（`module.frame:UpdateData` 原本也要補，上游 5335 起自己加了外層
`if not C_Secrets or not C_Secrets.ShouldAurasBeSecret()`，不用再動。
上游若哪天把外層閘拿掉，`check_forks.py` 不會抓到 —— 那筆守的是 `fix from MiliUI` 字樣，
準備確認再噴 `Auras cannot be accessed when secret` 時回來看這裡。）

冪等：已經套過就什麼都不做。找不到錨點代表上游改了這段，印出來人工處理。
守門：`.claude/scripts/check_forks.py` 的 MRT 那筆。
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
TARGET = os.path.join(REPO, "AddOns", "MRT", "RaidCheck.lua")

ANCHOR = "local function CheckPotionsOnPull()\n\ttable.wipe(module.db.potionList)\n"
GATE = (
    "\t-- fix from MiliUI: 這支在 ENCOUNTER_START 後 1.5 秒跑，正好是光環變秘密的時候，\n"
    "\t-- GetAuraDataByIndex 會直接拋錯（不是回 nil），迴圈裡的 issecretvalue 等不到；\n"
    "\t-- 閘要在呼叫之前（開場藥水名單就空著，戰鬥中的施放仍由戰鬥記錄補）\n"
    "\tif C_Secrets and C_Secrets.ShouldAurasBeSecret() then return end\n"
)


def main():
    check = "--check" in sys.argv
    if not os.path.isfile(TARGET):
        print("找不到 %s（MRT 不在套組裡？）" % TARGET)
        return 1
    src = io.open(TARGET, encoding="utf-8").read()
    if ANCHOR + GATE in src:
        print("MRT/RaidCheck.lua：已套用。")
        return 0
    if src.count(ANCHOR) != 1:
        print("MRT/RaidCheck.lua：找不到 CheckPotionsOnPull 的錨點（出現 %d 次），上游改了這段，請人工處理。"
              % src.count(ANCHOR))
        return 1
    if check:
        print("MRT/RaidCheck.lua：修補不在，跑這支腳本重套。")
        return 1
    io.open(TARGET, "w", encoding="utf-8", newline="\n").write(src.replace(ANCHOR, ANCHOR + GATE))
    print("MRT/RaidCheck.lua：已重套 CheckPotionsOnPull 的秘密值閘。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
