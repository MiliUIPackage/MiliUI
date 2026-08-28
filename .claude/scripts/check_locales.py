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
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")

USE_RE = re.compile(r'L\[\s*"((?:[^"\\]|\\.)*)"\s*\]')
DEF_RE = re.compile(r'^L\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=\s*(.*)$', re.M)
FMT_RE = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[sdifgxXqc%]')

# 共用元件庫（MiliUIWidgets）自己會查的 key，不會出現在插件自己的程式碼裡
WIDGET_KEYS = {"Apply", "Okay", "Cancel", "Can't change settings during combat"}


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


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
            dirnames[:] = [d for d in dirnames if d != "Libs"]
            if os.path.abspath(dirpath) == os.path.abspath(ldir):
                continue
            for name in filenames:
                if not name.endswith(".lua"):
                    continue
                src = read(os.path.join(dirpath, name))
                used |= set(USE_RE.findall(src))
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
