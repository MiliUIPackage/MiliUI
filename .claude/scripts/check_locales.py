#!/usr/bin/env python3
"""自製插件的語系檢查：缺鍵、重複定義、格式符對不起來。

    python3 .claude/scripts/check_locales.py

檢查項目（規則的完整版在 .claude/skills/miliui-locale-audit）：

1. **程式用到但語系檔沒定義** —— 最嚴重的一種。自寫的 `ns.L` 有 `__index` 退回 key
   （顯示英文原句，還算能看），AceLocale 那三支會退回 enUS 表；兩種都不會報錯，
   所以只能靠掃。
2. **同一個檔裡重複定義同一個 key** —— 後面那筆靜默蓋掉前面的，翻譯改了卻沒生效。
3. **各語系的格式符跟基準檔對不起來** —— `%s`／`%d` 數量不同會在 `format()` 當場炸，
   而且只在那個語系的客戶端才炸。
4. **色碼沒配對** —— `|c` 與 `|r` 數量不同，畫面上會整段染色一路吃到後面。

不檢查「多餘的 key」：那需要判斷有沒有動態組 key（`L[opt.key]`），誤報率太高。
清死鍵是人工的事，交給 miliui-locale-audit 技能。

⚠⚠⚠ **不要自動刪「沒人用的 key」。** key 有四種取法，靜態掃描認不全：

    L["KEY"]                中括號 ＋ 字串字面值
    L.KEY                   dot notation（key 是合法識別字時）
    L[variable]             變數
    L["PREFIX" .. suffix]   **前綴拼接** —— 最陰的一種，因為那一行確實含 `L["`

  2026-08-28 為了清死鍵翻車兩次：第一次只認第一種，把 MiliUI_BurstPotionHelper
  一整批 `L.TIP_*` 刪掉（遊戲裡變成 AceLocale 的 Missing entry 洗版）；補上
  dot notation 之後又差點刪掉 `CONTEXT_*` —— 那批是
  `L["CONTEXT_" .. ctx:upper()]` 組出來的。

  留著幾十條沒人用的字串在執行期是**零成本**，刪錯的代價是玩家的畫面。
  所以這支只報「用到但沒定義」，不報反向。真要清就人工一條一條確認。
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")

# ⚠⚠ **兩種寫法都要認。** 2026-08-28 踩過：稽核只比對中括號 L["KEY"]，
#   於是 MiliUI_BurstPotionHelper 那種用 dot notation（`L.TIP_NONE`）的插件，
#   整批還在用的 key 被判成死鍵刪掉，遊戲裡才變成 AceLocale 的 Missing entry。
#   dot notation 只在 key 是合法 Lua 識別字時可用，所以規則不同、要分兩條。
USE_RE = re.compile(r'L\[\s*"((?:[^"\\]|\\.)*)"\s*\]')
USE_DOT_RE = re.compile(r'\bL\.([A-Za-z_][A-Za-z0-9_]*)')
DEF_RE = re.compile(r'^L\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*(.*)$', re.M)
FMT_RE = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[sdifgxXqc%]')

# 共用元件庫（MiliUIWidgets）自己會查的 key，不會出現在插件自己的程式碼裡
WIDGET_KEYS = {"Apply", "Okay", "Cancel", "Can't change settings during combat"}


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def strip_comments(src):
    """把 Lua 註解拿掉再掃 L[...]。

    ⚠ 沒有這一步，**註解裡的用法範例會被當成真的用到**。2026-08-28 踩到：
      共用層 BlizzOptions.lua 的檔頭寫了 `L["MiliUI Tooltip"]` 當範例，
      於是每一支插件都被報「用到但沒定義 'MiliUI Tooltip'」。
    """
    # 長註解 --[[ ... ]] / --[==[ ... ]==]
    src = re.sub(r'--\[(=*)\[.*?\]\1\]', '', src, flags=re.S)
    out = []
    for line in src.split("\n"):
        i, n, quote = 0, len(line), None
        cut = None
        while i < n:
            c = line[i]
            if quote:
                if c == "\\":
                    i += 2; continue
                if c == quote:
                    quote = None
            elif c in "\"'":
                quote = c
            elif c == "-" and i + 1 < n and line[i + 1] == "-":
                cut = i
                break
            i += 1
        out.append(line if cut is None else line[:cut])
    return "\n".join(out)


def main():
    problems = 0
    checked = 0
    coverage = []

    for addon in sorted(os.listdir(ADDONS)):
        if not addon.startswith("MiliUI"):
            continue
        root = os.path.join(ADDONS, addon)
        ldir = os.path.join(root, "Locales")
        if not os.path.isdir(ldir):
            continue
        checked += 1

        used = set()
        dynamic = False
        for dirpath, dirnames, filenames in os.walk(root):
            # ⚠ **不要整個跳過 Libs**：共用層（Libs/MiliUIWidgets）自己也會查 L[...]，
            #   而宿主必須滿足它查的每一個 key。2026-08-28 就是漏掉這裡 ——
            #   BlizzOptions.lua 偷查了 L["Version: %s"] / L["Open options"]，在用
            #   AceLocale ＋ token key 的三支插件上變成 "Missing entry" 洗版，
            #   而這支腳本因為跳過 Libs 完全沒看到。
            #   其餘 vendor 函式庫（Ace*、LibStub…）有自己的語系機制，照樣跳過。
            dirnames[:] = [d for d in dirnames
                           if d != "Libs" or os.path.isdir(os.path.join(dirpath, d, "MiliUIWidgets"))]
            if os.path.basename(dirpath) == "Libs":
                dirnames[:] = [d for d in dirnames if d == "MiliUIWidgets"]
            if os.path.abspath(dirpath) == os.path.abspath(ldir):
                continue
            for name in filenames:
                if not name.endswith(".lua"):
                    continue
                src = strip_comments(read(os.path.join(dirpath, name)))
                used |= set(USE_RE.findall(src))
                used |= set(USE_DOT_RE.findall(src))
                # L[變數] ⇒ key 是動態組出來的，缺鍵檢查對這支不可信
                if re.search(r'L\[\s*[^"\s\]]', src):
                    dynamic = True

        defined = {}
        for name in sorted(os.listdir(ldir)):
            if not name.endswith(".lua") or name == "Locale.lua":
                continue
            src = read(os.path.join(ldir, name))
            keys, dupes = {}, []
            for m in DEF_RE.finditer(src):
                k, v = m.group(1), m.group(2)
                if k in keys:
                    dupes.append(k)
                keys[k] = v
            defined[name] = keys
            for k in sorted(set(dupes)):
                print(f"!! {addon}/Locales/{name}: key 重複定義（後面那筆會蓋掉前面）→ {k!r}")
                problems += 1

        if not defined:
            continue

        base_name = "zhTW.lua" if "zhTW.lua" in defined else sorted(defined)[0]
        base = defined[base_name]

        missing = used - set(base) - WIDGET_KEYS
        if missing and not dynamic:
            for k in sorted(missing):
                print(f"!! {addon}: 程式用到但 {base_name} 沒定義 → {k!r}")
                problems += 1
        elif missing and dynamic:
            # 有動態 key 就只提醒，不當錯誤（無從分辨是真缺還是動態組的）
            print(f"   {addon}: {len(missing)} 個 key 掃不到定義，但這支有動態 L[var]，需人工確認")

        for name, keys in sorted(defined.items()):
            if name == base_name:
                continue
            for k, base_val in base.items():
                if k not in keys:
                    continue
                a, b = sorted(FMT_RE.findall(base_val)), sorted(FMT_RE.findall(keys[k]))
                if a != b:
                    print(f"!! {addon}/Locales/{name}: 格式符對不起來 → {k!r}")
                    print(f"      {base_name}: {a}")
                    print(f"      {name}: {b}")
                    problems += 1

        for name, keys in sorted(defined.items()):
            if name != base_name:
                short = len(set(base) - set(keys))
                if short:
                    coverage.append(f"{addon}/{name}: 比 {base_name} 少 {short} 條")

        for name, keys in sorted(defined.items()):
            for k, v in keys.items():
                if v.count("|c") != v.count("|r"):
                    print(f"!! {addon}/Locales/{name}: |c 與 |r 沒配對 → {k!r}")
                    problems += 1

    if coverage:
        print("\n翻譯覆蓋率（缺的那幾條會退回基準語言顯示，不算錯誤）：")
        for line in coverage:
            print(f"  {line}")

    print(f"\n檢查了 {checked} 支有語系檔的插件。", "有問題。" if problems else "沒有問題。")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
