#!/usr/bin/env python3
"""第三方插件的本地修補有沒有被上游更新洗掉。

    python3 .claude/scripts/check_forks.py

`AddOns/` 裡的第三方插件是上游原封不動的副本，但有一批帶著不回上游的修改
（見 `.claude/notes/project-local-addon-forks.md` 那張表）。`update: <插件>` 整包覆蓋
時這些修改會被洗掉，而且**不報錯**，只是某個修好的問題悄悄回來。這支腳本把表上每筆
修補的「辨識法」寫成宣告式清單，洗掉就失敗。

每一筆：插件資料夾、檔案（相對於該資料夾）、必須出現的字串或 regex、一句說明。

- 檔案不存在（插件不在套組裡，例如 AztarecHelper）→ 印「不在套組裡，略過」，不算失敗。
- `pending=True` → 已知退化、還沒重套：印警告但不擋。重套之後把 `pending` 拿掉，
  這筆就開始守門。

⚠ 新增修補時，筆記那張表與這裡要同時加一筆；辨識字串優先用註解裡的 `fix from MiliUI`
／`MiliUI` 標記，沒有標記的才用程式碼本身的特徵。
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")


def P(addon, file, needle, note, regex=False, pending=False):
    return {
        "addon": addon,
        "file": file,
        "needle": needle,
        "note": note,
        "regex": regex,
        "pending": pending,
    }


PATCHES = [
    # ── TinyInspect-Remake：12.1 secret guard ───────────────────────────
    P("TinyInspect-Remake", "InspectCore.lua", "fix from MiliUI", "SafeUnitGUID／血量新鮮度檢查"),
    P("TinyInspect-Remake", "InspectCore.lua", "SafeUnitGUID", "SafeUnitGUID 函式本體"),
    P("TinyInspect-Remake", "ItemLevel.lua", "fix from MiliUI", "IsInspectFrameData"),
    P("TinyInspect-Remake", "InspectUnit.lua", "fix from MiliUI", "IsInspectFrameData"),

    # ── Ayije_CDM：12.1 secret guard、xpcall 隔離、米利頭像錨定…（挑各檔一個標記）──
    P("Ayije_CDM", "Init.lua", "fix from MiliUI", "事件／刷新鏈 xpcall 逐一隔離"),
    P("Ayije_CDM", "Core/InternalCallbacks.lua", "fix from MiliUI", "戰鬥／專精／天賦 handler 隔離"),
    P("Ayije_CDM", "Core/Main.lua", "fix from MiliUI", "編輯模式 scale／拖曳補丁、模組初始化隔離"),
    P("Ayije_CDM", "Core/EditMode.lua", "fix from MiliUI", "編輯模式改成可拖曳"),
    P("Ayije_CDM", "Core/TrackerUtils.lua", "MiliUIUF_Player", "錨定米利頭像框架"),
    P("Ayije_CDM", "Core/Style.lua", "fix from MiliUI", "黑底清除、增益長條名字"),
    P("Ayije_CDM", "Modules/Tags.lua", "fix from MiliUI", "法力數字縮寫選項"),
    P("Ayije_CDM_Options", "Border.lua", "MiliUI", "無損刷新標題下的說明列"),
    P("Ayije_CDM", "Ayije_CDM.toc", "_MiliUI", "TOC 版本號尾綴"),

    # ── Chattynator ─────────────────────────────────────────────────────
    P("Chattynator", "Core/Config.lua", r"SHOW_LEVEL\s*=.*default\s*=\s*false.*MiliUI",
      "SHOW_LEVEL 預設 false", regex=True),

    # ── Platynator ──────────────────────────────────────────────────────
    P("Platynator", "Core/Initialize.lua", "MiliUI_PlatynatorProfile", "讀 MiliUI 內建 profile 並自動切換"),
    P("Platynator", "Display/Auras/AurasNext.lua", "MiliUI: lazy aura groups", "光環群組延遲登記"),
    P("Platynator", "Display/Initialize.lua", "miliPoolSlot", "光環群組延遲登記（名條池格號）"),

    # ── AppearanceTooltip：秘密值修補（中文化刻意不標，不守）────────────
    P("AppearanceTooltip", "addon.lua", "fix from MiliUI", "GetCenter guard／秘密錨點下不顯示預覽"),
    P("AppearanceTooltip", "addon.lua", "issecretframe", "issecretframe helper"),

    # ── TeleportMenu ────────────────────────────────────────────────────
    P("TeleportMenu", "TeleportMenu.lua", 'GameMenuFrame:HookScript("OnShow"',
      "從選單圖示開選單也要出現傳送按鈕"),

    # ── YUI_AuctionHelper：TOC 兩行被洗掉不會報錯，只是又變回登入就載入 ──
    P("YUI_AuctionHelper", "YUI_AuctionHelper.toc", r"^## LoadOnDemand:\s*1\s*$",
      "TOC 晚載入", regex=True),
    P("YUI_AuctionHelper", "YUI_AuctionHelper.toc", r"^## LoadWith:\s*Blizzard_AuctionHouseUI\s*$",
      "TOC 晚載入（拍賣場開啟時載入）", regex=True),

    # ── MRT：12.1 光環秘密值閘 ──────────────────────────────────────────
    #   ⚠ 2026-08-25 `update: MRT` 已洗掉，待重套
    P("MRT", "RaidCheck.lua", "fix from MiliUI", "UpdateData／CheckPotionsOnPull 光環秘密值閘",
      pending=True),

    # ── ChatThrottleLib：每一份都要改，誰先載入誰贏 ─────────────────────
    P("Cell", "Libs/AceComm-3.0/ChatThrottleLib.lua", "SafeStrLen", "密語秘密字串不炸統計掛勾"),
    P("BugSack", "Libs/AceComm-3.0/ChatThrottleLib.lua", "SafeStrLen", "密語秘密字串不炸統計掛勾"),
    #   ⚠ 2026-09-26 新進套組的 MDT 那份沒有 SafeStrLen，待補
    P("MythicDungeonTools", "libs/AceComm-3.0/ChatThrottleLib.lua", "SafeStrLen",
      "密語秘密字串不炸統計掛勾", pending=True),

    # ── HandyNotes_Valdrakken：補上漏掉的兩個 local ─────────────────────
    P("HandyNotes_Valdrakken", "core/handler.lua", r"^\s*local profile = self\.db\.profile\s*$",
      "OnInitialize 的 local profile", regex=True),
    P("HandyNotes_Valdrakken", "core/handler.lua", r"^\s*local global = self\.db\.global\s*$",
      "OnInitialize 的 local global", regex=True),

    # ── HandyNotes 三支：core/util.lua 的 C_Calendar secret guard（三份副本）──
    #   Midnight 的 core 較新、上游已內含，沒有 MiliUI 標記，所以認守衛本身
    P("HandyNotes_Midnight", "core/util.lua", r"issecretvalue\(eventID\)",
      "C_Calendar secret guard（上游已內含）", regex=True),
    P("HandyNotes_TheWarWithin", "core/util.lua", r"issecretvalue\(eventID\)",
      "C_Calendar secret guard", regex=True),
    P("HandyNotes_TheWarWithin", "core/util.lua", "fix from MiliUI", "NameResolver leftText secret guard 回填"),
    P("HandyNotes_Dragonflight", "core/util.lua", r"issecretvalue\(eventID\)",
      "C_Calendar secret guard", regex=True),
    P("HandyNotes_Dragonflight", "core/util.lua", "fix from MiliUI", "NameResolver leftText secret guard 回填"),

    # ── AztarecHelper：不在套組裡，檔案不存在會自動略過（補丁腳本留在 .claude/patches）──
    P("AztarecHelper", "Core.lua", "fix from MiliUI", "整包 zhTW 中文化"),
]

# 不守的：Cell（我們自己就是上游）、BuffReminders（2026-09-06 已洗掉，要不要補回由使用者決定）、
# DiGuaTimelineAudioHelper（已改走 MiliUI/Enhance）。


def read(path):
    with open(path, encoding="utf-8-sig", errors="replace") as fh:
        return fh.read()


def found(text, p):
    if p["regex"]:
        return re.search(p["needle"], text, re.M) is not None
    return p["needle"] in text


def main():
    ok = skipped = pending_n = 0
    failed = []
    print("第三方插件的本地修補（%d 筆）" % len(PATCHES))
    for p in PATCHES:
        path = os.path.join(ADDONS, p["addon"], p["file"])
        label = "%s/%s" % (p["addon"], p["file"])
        if not os.path.isfile(path):
            if os.path.isdir(os.path.join(ADDONS, p["addon"])):
                # 插件在、檔案不在：上游改名或刪檔，修補跟著沒了，不能當成略過
                print("  %s  %s  檔案不見了（%s）" % ("警告" if p["pending"] else "失敗", label, p["note"]))
                if p["pending"]:
                    pending_n += 1
                else:
                    failed.append(label)
            else:
                print("  略過  %s  不在套組裡，略過" % label)
                skipped += 1
            continue
        if found(read(path), p):
            print("  ok    %s  %s" % (label, p["note"]))
            ok += 1
        elif p["pending"]:
            print("  警告  %s  已知退化（pending），待重套：%s" % (label, p["note"]))
            pending_n += 1
        else:
            print("  失敗  %s  找不到 %r —— 修補被洗掉了？%s" % (label, p["needle"], p["note"]))
            failed.append(label)

    print()
    print("通過 %d、略過 %d、待重套（pending）%d、失敗 %d" % (ok, skipped, pending_n, len(failed)))
    if failed:
        print("修補被洗掉了。重套後再提交；若是刻意放棄，從 check_forks.py 與筆記那張表同時拿掉。")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
