#!/usr/bin/env python3
"""自製插件的 Lua 靜態檢查：語法 ＋ 「該是 local 卻寫成全域」＋ upvalue 上限。

    python3 .claude/scripts/check_lua.py

`luac -p` 只驗語法，抓不到未宣告的全域。第二道檢查把每個檔編成位元組碼、掃它對
`_ENV` 的**寫入**（`SETTABUP`），扣掉白名單之後剩下的幾乎一定是漏了 `local`
——那種錯誤是靜默的，會到遊戲裡才變成一個指不到成因的崩潰。

第三道檢查抓「某支函式的 upvalue 超過 Lua 的 60 上限」——那在遊戲裡只跳一行
LUA_WARNING，很容易被忽略，而且踩到的那天多半跟當下改的東西沒關係。

原理與兩次實際抓到的東西見 .claude/notes/wow-luac-global-scan.md。

⚠ 只掃自製插件（MiliUI 與 MiliUI_*）本體，不含 Libs/：vendor 進來的函式庫有自己的
   慣例（LibStub 就是刻意寫全域），拿同一把尺量只會製造雜訊。
"""

import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")

# 刻意寫出去的全域。新增一筆之前先想清楚：這裡放寬一格，就少一道保護。
ALLOWED_GLOBAL_WRITES = {
    # 套組本體與各插件的 SavedVariables（TOC 有宣告）
    "MiliUI_DB", "MiliUI_CharDB", "MiliUI_CastBarEnhanceDB",
    "MiliUI_AuraEnhance_DB", "MiliUI_AuraEnhanceDB",
    "MiliUI_BloodlustMusic_DB", "MiliUI_BurstPotionHelperDB",
    "MiliUI_CharacterNotes_DB", "MiliUI_ChatBar_DB",
    "MiliUI_DamageMeters_DB", "MiliUI_Focus_DB",
    "MiliUI_InfoBar_DB",
    "MiliUI_Minimap_DB",
    "MiliUI_QuestTracker_DB",
    "MiliUI_Tooltip_DB", "MiliUI_UnitFrames_DB",
    "AGSCDB",
    # 內建預設值資料（Config/ 底下那幾支就是一整包全域表）
    "MiliUI_PlatynatorProfile", "MiliUI_AyijeCDM_Profile",
    # 對外 API 與跨插件註冊表
    "MiliUI", "MiliUI_MenuEntries", "MiliUI_Snap",
    "MiliUI_OpenUnitFrameSettings", "MiliUIUF_OnAddonCompartmentClick",
    "MiliUICrafterTableCellRewardsMixin",
    # 各 Enhance 模組的對外開關（設定面板要叫得到）
    "MiliUI_AHFilter", "MiliUI_BagsAlpha", "MiliUI_BaganatorKeystone",
    "MiliUI_BonusRollFilter",
    "MiliUI_CVarEnforce", "MiliUI_CastBarEnhance", "MiliUI_CastBarPixelFont",
    "MiliUI_ChattynatorButtons", "MiliUI_ChattynatorTabs",
    "MiliUI_DelveMarkButton", "MiliUI_KeystoneDebug", "MiliUI_LegacyAddons",
    "MiliUI_MerchantAutomation",
    "MiliUI_WorldMapCoords",
    # 刻意寫回暴雪／第三方的全域（都有掛勾理由，見各檔註解）
    "ChatEdit_CustomTabPressed",      # 暴雪留的官方覆寫點，有串回原本的
    "SetDesaturation", "AnimateTexCoords",   # Fix/DeprecatedGlobals.lua 的相容層
    "BugSackDB", "Ayije_CDMDB", "PLATYNATOR_CONFIG",   # 預設值匯入的目標
    # Clique 的點擊施法註冊表：規格就是「自己的框往這張全域表塞」，Clique 沒載入時
    # 也要建得起來（`ClickCastFrames = ClickCastFrames or {}`）
    "ClickCastFrames",
}

SLASH_RE = re.compile(r"^SLASH_[A-Z0-9_]+\d$")


def lua_files():
    for addon in sorted(os.listdir(ADDONS)):
        if addon != "MiliUI" and not addon.startswith("MiliUI_"):
            continue
        root = os.path.join(ADDONS, addon)
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d != "Libs"]
            for name in sorted(filenames):
                if name.endswith(".lua"):
                    yield os.path.join(dirpath, name)


def global_writes(path):
    out = subprocess.run(["luac", "-l", "-p", path],
                         capture_output=True, text=True).stdout
    return set(re.findall(r'SETTABUP.*_ENV "([^"]+)"', out))


# Lua 一個函式最多 60 個 upvalue。超過在遊戲裡只跳一行 LUA_WARNING
# （「function at line N has more than 60 upvalues」），很容易被忽略，
# 而且是「檔案越長越容易踩、踩到那天跟當下改的東西沒關係」的那種。
#
# 常見成因：檔案層一路加 local，而某支大函式（通常是 Init）把它們全捕捉進去。
# 修法是把同一組的 local 收進一張表——一張表只吃一格。
UPVALUE_LIMIT = 60

FUNC_RE = re.compile(r"^function <([^:]+):(\d+),\d+>", re.M)
UPVAL_RE = re.compile(r"(\d+) upvalues")


def upvalue_overflows(path):
    out = subprocess.run(["luac", "-l", "-l", "-p", path],
                         capture_output=True, text=True).stdout
    hits = []
    lines = out.splitlines()
    for i, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if not m or i + 1 >= len(lines):
            continue
        n = UPVAL_RE.search(lines[i + 1])
        if n and int(n.group(1)) > UPVALUE_LIMIT:
            hits.append((int(m.group(2)), int(n.group(1))))
    return hits


def main():
    if subprocess.run(["luac", "-v"], capture_output=True).returncode != 0:
        print("找不到 luac —— 這台機器沒裝 Lua，跳過檢查")
        return 1

    syntax, leaks, upvals = [], [], []
    count = 0
    for path in lua_files():
        count += 1
        rel = os.path.relpath(path, REPO)
        proc = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
        if proc.returncode != 0:
            syntax.append((rel, proc.stderr.strip()))
            continue
        for name in sorted(global_writes(path)):
            if name in ALLOWED_GLOBAL_WRITES or SLASH_RE.match(name):
                continue
            leaks.append((rel, name))
        for line, n in upvalue_overflows(path):
            upvals.append((rel, line, n))

    print(f"掃了 {count} 個 .lua（自製插件本體，不含 Libs/）")

    if syntax:
        print(f"\n語法錯誤 {len(syntax)}：")
        for rel, err in syntax:
            print(f"  {rel}\n      {err}")
    else:
        print("語法：全過")

    if leaks:
        print(f"\n可疑的全域寫入 {len(leaks)}（多半是漏了 local）：")
        for rel, name in leaks:
            print(f"  {rel}  →  {name}")
        print("\n確定是刻意的就把名字加進本檔的 ALLOWED_GLOBAL_WRITES。")
    else:
        print("全域寫入：沒有名單外的")

    if upvals:
        print(f"\nupvalue 超過 {UPVALUE_LIMIT} 的函式 {len(upvals)}：")
        for rel, line, n in upvals:
            print(f"  {rel}:{line}  →  {n} 個")
        print("把同一組的 file-scope local 收進一張表，一張表只吃一格。")
    else:
        print(f"upvalue：沒有超過 {UPVALUE_LIMIT} 的函式")

    # luac -l 會在工作目錄留下 luac.out（.gitignore 擋著，但不要留垃圾）
    for junk in (os.path.join(os.getcwd(), "luac.out"), os.path.join(REPO, "luac.out")):
        if os.path.exists(junk):
            os.remove(junk)

    return 1 if (syntax or leaks or upvals) else 0


if __name__ == "__main__":
    sys.exit(main())
