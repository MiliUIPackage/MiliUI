#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ChatThrottleLib：流量統計掛勾對秘密字串不炸 —— 某支插件更新後它那份被洗掉時重套。

用法（在 Interface/ 底下跑，可一次給多個檔）：

    python3 .claude/patches/ChatThrottleLib-SafeStrLen.py AddOns/Cell/Libs/AceComm-3.0/ChatThrottleLib.lua
    python3 .claude/patches/ChatThrottleLib-SafeStrLen.py --check AddOns/*/Libs/AceComm-3.0/ChatThrottleLib.lua

修什麼：12.1 起密語對象的名字可能是秘密字串（跨服／戰網／非隊友），`Hook_SendChatMessage`／
`Hook_SendAddonMessage` 對它 `tostring` 會報 `attempt to perform string conversion on a
secret string value`。兩支只是流量統計，取不到長度就用固定值估（`SafeStrLen`）。

⚠ 每一份都要改：同版本比載入順序、高版本直接贏，只修一份會在停用／更新某支之後復發。
   套組裡現有哪幾份：`ls AddOns/*/Libs/AceComm-3.0/ChatThrottleLib.lua AddOns/*/libs/AceComm-3.0/ChatThrottleLib.lua`。

上游 v32 起自己在兩支 Hook 開頭加了 `issecretvalue(text) or issecretvalue(destination)` 早退，
效果等同；碰到那種檔這支會印「上游已自帶」並略過，不疊第二層。
守門：`.claude/scripts/check_forks.py` 的 ChatThrottleLib 那幾筆。
"""
import io
import re
import sys

HELPER = '''
-- fix from MiliUI: 12.1 起玩家名字可能是秘密字串（跨服／戰網／不在隊伍裡），
-- 被污染的執行對它 tostring 會直接報錯（attempt to perform string conversion
-- on a secret string value）。下面兩支只是流量統計，取不到長度就用固定值估。
local issecretvalue = _G.issecretvalue
local SECRET_STR_LEN = 32
local function SafeStrLen(v)
\tif v == nil then
\t\treturn 0
\telseif issecretvalue and issecretvalue(v) then
\t\treturn SECRET_STR_LEN
\tend
\treturn strlen(tostring(v))
end
'''

ANCHOR = "\nlocal bMyTraffic = false\n"

# 上游 v31 的兩種寫法 → SafeStrLen
REPLACES = [
    ('local size = strlen(tostring(text or "")) + strlen(tostring(destination or "")) + self.MSG_OVERHEAD',
     "local size = SafeStrLen(text) + SafeStrLen(destination) + self.MSG_OVERHEAD"),
    ('local size = tostring(text or ""):len() + tostring(prefix or ""):len();',
     "local size = SafeStrLen(text) + SafeStrLen(prefix);"),
    ('size = size + tostring(destination or ""):len() + self.MSG_OVERHEAD',
     "size = size + SafeStrLen(destination) + self.MSG_OVERHEAD"),
]

UPSTREAM_GUARD = "issecretvalue(text) or issecretvalue(destination)"


def patch(path, check):
    src = io.open(path, encoding="utf-8").read()
    if "SafeStrLen" in src:
        print("%s：已套用。" % path)
        return 0
    if UPSTREAM_GUARD in src:
        print("%s：上游已自帶秘密字串早退（v32+），略過。" % path)
        return 0
    if src.count(ANCHOR) != 1 or not all(old in src for old, _ in REPLACES):
        print("%s：找不到 v31 的錨點，上游改寫了這段，請人工處理。" % path)
        return 1
    if check:
        print("%s：修補不在，跑這支腳本重套。" % path)
        return 1
    out = src.replace(ANCHOR, ANCHOR + HELPER, 1)
    for old, new in REPLACES:
        out = out.replace(old, new)
    io.open(path, "w", encoding="utf-8", newline="\n").write(out)
    print("%s：已重套 SafeStrLen。" % path)
    return 0


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    check = "--check" in sys.argv
    if not args:
        print(__doc__)
        return 1
    rc = 0
    for p in args:
        rc |= patch(p, check)
    return rc


if __name__ == "__main__":
    sys.exit(main())
