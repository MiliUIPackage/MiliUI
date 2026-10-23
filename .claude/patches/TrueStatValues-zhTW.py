#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TrueStatValues 繁中化補丁 —— 上游更新後重新套用。

用法（在 Interface/ 底下跑）：

    python3 .claude/patches/TrueStatValues-zhTW.py            套用
    python3 .claude/patches/TrueStatValues-zhTW.py --check    只看不改（check-all 不跑這個，守門在 check_forks.py）

做三件事：
  1. 補回 Locales.lua —— 上游沒有語系檔，字串全是就地寫死的。L 表 `__index` 退回英文原句，
     英文客戶端完全不受影響；要加 zhCN 就在 Locales.lua 多開一段。
  2. .toc：載入清單在 Core.lua 前面插 `Locales.lua`，檔尾補回 MiliUI 區塊
     （Title-zhTW／Notes-zhTW／Category-zhTW）。⚠ Title-zhTW 的標籤色碼是「介面」分類
     漸層的一格，新增／移除介面分類的插件時整條要重鋪，見 notes/project-toc-title-tag-style.md。
  3. Core.lua／Tooltips.lua：寫死字串改走 L[...]；黑名單補 zhTW 法術名（wowhead 查證過的）；
     物品提示的「提高N點精通」句型從暴雪的 ITEM_MOD_*_RATING 格式字串產生 pattern
     （上游只認英文 " by"）。

冪等：套過的略過；錨點找不到（上游改寫了那段）就列出來交給人，不硬套。
上游的 Core.lua／.toc 是 CRLF（進 git 後 autocrlf 會轉成 LF）：對照一律用 \\n 寫，套用時依檔案自動換。
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDON = os.path.join(REPO, "AddOns", "TrueStatValues")

LOCALES = '''local name, addon = ...

-- fix from MiliUI (中文化): 上游沒有語系檔，Core.lua／Tooltips.lua 的字串都是就地寫死的。
-- 這張表讓它們改走 L["英文原句"] 取字；沒翻的 key 退回原句，所以英文客戶端照舊。
-- 重套腳本：.claude/patches/TrueStatValues-zhTW.py
local L = setmetatable({}, { __index = function(_, key) return key end })
addon.L = L

if GetLocale() == "zhTW" then
    -- 設定面板
    L["True Stat Values"] = "真實屬性數值"
    L["Options"] = "選項"
    L["True Stat Value Settings"] = "真實屬性數值設定"
    L["Stat Tooltips"] = "屬性滑鼠提示"
    L["When checked, displays True Stat Rating information on Secondary-Stat tooltips."] = "勾選後，角色面板的次要屬性滑鼠提示會顯示扣除遞減後的真實數值、損失量，以及目前遞減區間的進度。"
    L["Item Tooltips"] = "物品滑鼠提示"
    L["When checked, displays True Stat Rating information on Item tooltips."] = "勾選後，物品滑鼠提示的屬性數值後面會標出扣除遞減後的實際增加量。"
    L["Font Color"] = "文字顏色"
    -- 滑鼠提示
    L["True Rating:"] = "真實數值："
    L["Lost Rating:"] = "遞減損失："
    L[" [%s penalty]"] = " [遞減 %s]"
end
'''

TOC_BLOCK = '''
## Title-zhTW: |cff33FFCC[屬性]|r 真實屬性數值
## Notes-zhTW: True Stat Values|n|n顯示次要屬性的遞減資訊：角色面板的屬性滑鼠提示列出扣除遞減後的真實數值、損失量，以及目前遞減區間的進度條；物品滑鼠提示的屬性數值後面標出實際增加量。|n|n|cffffd200使用方法: |r從Esc>選項>插件>真實屬性數值，進行設定。
## Category-zhTW: 介面
'''

MARK = "fix from MiliUI (中文化)"

PAIRS = {
    "Core.lua": [
        ('local tsv = LibStub("AceAddon-3.0"):NewAddon("TrueStatValues", "AceConsole-3.0", "AceEvent-3.0")\n',
         'local tsv = LibStub("AceAddon-3.0"):NewAddon("TrueStatValues", "AceConsole-3.0", "AceEvent-3.0")\n'
         'local L = addon.L -- ' + MARK + ': 語系表在 Locales.lua\n'),
        ('local options = {\n\tname = "True Stat Values",',
         'local options = {\n\tname = L["True Stat Values"],'),
        ('name = "Options",', 'name = L["Options"],'),
        ('name = "True Stat Value Settings",', 'name = L["True Stat Value Settings"],'),
        ('name = "Stat Tooltips",', 'name = L["Stat Tooltips"],'),
        ('desc = "When checked, displays True Stat Rating information on Secondary-Stat tooltips.",',
         'desc = L["When checked, displays True Stat Rating information on Secondary-Stat tooltips."],'),
        ('name = "Item Tooltips",', 'name = L["Item Tooltips"],'),
        ('desc = "When checked, displays True Stat Rating information on Item tooltips.",',
         'desc = L["When checked, displays True Stat Rating information on Item tooltips."],'),
        ('name = "Font Color",', 'name = L["Font Color"],'),
        ('local BlizOptionsTable = {\n\tname = "True Stat Values",',
         'local BlizOptionsTable = {\n\tname = L["True Stat Values"],'),
        ('AddToBlizOptions("TSV_Bliz", "True Stat Values")',
         'AddToBlizOptions("TSV_Bliz", L["True Stat Values"])'),
    ],
    "Tooltips.lua": [
        ('local name, addon = ...\n\nlocal function RGBPercToHex',
         'local name, addon = ...\nlocal L = addon.L -- ' + MARK + ': 語系表在 Locales.lua\n\nlocal function RGBPercToHex'),
        ('\t["转化精通"] = true\n}',
         '\t["转化精通"] = true,\n'
         '\t-- ' + MARK + ': zhTW 的名字（wowhead 查證）。標題前幾個字就是屬性名的法術\n'
         '\t-- 會被 HandleLabel 誤判成屬性提示（中文三個字就超過 11 bytes 的門檻）\n'
         '\t["吸血毒藥"] = true, -- Leeching Poison\n'
         '\t["盜賊的臨機應變"] = true, -- Thief\'s Versatility\n'
         '\t["巫毒精通"] = true, -- Voodoo Mastery\n'
         '\t["鍊金術專精"] = true, -- Alchemical Mastery\n'
         '\t["變形精通"] = true, -- Metamorphic Mastery\n'
         '\t["卡茲阿爾加轉化精通"] = true -- Khaz Algar Transmutation Mastery\n'
         '}'),
        ('STAT_SPEED .. " by%s*([,0-9]+)"}\n}\n',
         'STAT_SPEED .. " by%s*([,0-9]+)"}\n}\n'
         '\n'
         '-- ' + MARK + ': 「裝備：提高123點精通。」這種句子各語系語序不同，上游只認英文的 " by"。\n'
         '-- 直接拿暴雪的 ITEM_MOD_*_RATING 格式字串（zhTW「提高%s點精通。」）轉成 pattern，哪個語系都通。\n'
         'local function StatPatternFromGlobal(fmt)\n'
         '    if type(fmt) ~= "string" or not fmt:find("%s", 1, true) then return nil end\n'
         '    fmt = fmt:gsub("。$", "")\n'
         '    fmt = fmt:gsub("%.$", "")\n'
         '    local p = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")\n'
         '    p = p:gsub("%%%%s", "([,0-9]+)")\n'
         '    return p\n'
         'end\n'
         'for statId, fmt in pairs({\n'
         '    [CR_MASTERY] = ITEM_MOD_MASTERY_RATING,\n'
         '    [CR_CRIT_SPELL] = ITEM_MOD_CRIT_RATING,\n'
         '    [CR_HASTE_SPELL] = ITEM_MOD_HASTE_RATING,\n'
         '}) do\n'
         '    local p = StatPatternFromGlobal(fmt)\n'
         '    if p then table.insert(patterns[statId], p) end\n'
         'end\n'),
        ('" [" .. pctLabel .. " penalty]"', 'format(L[" [%s penalty]"], pctLabel)'),
        ('tooltip:AddDoubleLine("True Rating:",', 'tooltip:AddDoubleLine(L["True Rating:"],'),
        ('tooltip:AddDoubleLine("Lost Rating:",', 'tooltip:AddDoubleLine(L["Lost Rating:"],'),
    ],
}


def rd(path):
    return io.open(path, encoding="utf-8", newline="").read()


def wr(path, s, check):
    if not check:
        io.open(path, "w", encoding="utf-8", newline="").write(s)


def nl(s, text):
    """對照用 \\n 寫；檔案是 CRLF 就換成 \\r\\n。"""
    return text.replace("\n", "\r\n") if "\r\n" in s else text


def main():
    check = "--check" in sys.argv
    applied, fails = 0, []

    # 1. Locales.lua
    loc = os.path.join(ADDON, "Locales.lua")
    if not os.path.exists(loc) or rd(loc) != LOCALES:
        wr(loc, LOCALES, check)
        applied += 1

    # 2. TOC
    toc = os.path.join(ADDON, "TrueStatValues.toc")
    s = rd(toc)
    if not re.search(r"^Locales\.lua\s*$", s, re.M):
        if re.search(r"^Core\.lua\s*$", s, re.M):
            s = re.sub(r"^(Core\.lua\s*)$", lambda m: "Locales.lua" + nl(s, "\n") + m.group(1), s, count=1, flags=re.M)
            applied += 1
        else:
            fails.append(("TrueStatValues.toc", "載入清單找不到 Core.lua", ""))
    if "## Category-zhTW:" not in s:
        if not s.endswith(("\n", "\r\n")):
            s += nl(s, "\n")
        s += nl(s, TOC_BLOCK)
        applied += 1
    wr(toc, s, check)

    # 3. Lua 字串對照
    for rel, pairs in PAIRS.items():
        path = os.path.join(ADDON, rel)
        if not os.path.exists(path):
            fails.append((rel, "檔案不存在", ""))
            continue
        s = rd(path)
        for old, new in pairs:
            old, new = nl(s, old), nl(s, new)
            if new in s:
                continue
            if s.count(old) == 1:
                s = s.replace(old, new)
                applied += 1
            else:
                fails.append((rel, "命中 %d 次" % s.count(old), old))
        wr(path, s, check)

    verb = "要套用" if check else "已套用"
    print("%s %d 處，未命中 %d 處" % (verb, applied, len(fails)))
    for rel, why, what in fails:
        head = what.strip().splitlines()[0][:90] if what else ""
        print("  [%s] %s :: %s" % (rel, why, head))
    if fails:
        print("\n^ 這些是上游改過字的地方，去新版原始碼找到對應段落重翻，再改這支的 PAIRS。")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
