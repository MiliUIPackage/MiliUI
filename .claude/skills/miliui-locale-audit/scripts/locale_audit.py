#!/usr/bin/env python3
"""語系對齊檢查（預設 MiliUI_UnitFrames，可傳插件資料夾路徑當參數）。

檢查項目：
  1. 覆蓋率      原始碼用到的 key，每個語系檔都有嗎
  2. 多餘        語系檔定義了沒人用的 key
  3. 重複定義    同一個檔裡同一個 key 定義兩次（後面的會蓋掉前面的，靜默）
  4. 格式符      key 與譯文的 %s / %d 數量對不對得起來
  5. 色碼        |cff…|r 有沒有配對
  6. 未翻譯      譯文跟 key 一模一樣
  7. 檔案守衛    if GetLocale() ~= "xx" 的 xx 跟檔名對不對得起來
  8. TOC         語系檔有沒有全部列進 TOC，順序在 Core\\Init.lua 之前
"""
import re, pathlib, sys

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                    else "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_UnitFrames")
STR = r'"(?:[^"\\]|\\.)*"'
CALL = re.compile(r'L\[\s*(' + STR + r'(?:\s*\.\.\s*' + STR + r')*)\s*\]', re.S)
DEF = re.compile(r'^L\[(' + STR + r')\]\s*=\s*(' + STR + r')\s*$', re.M)


def unq(lit):
    """把一串（可能是串接的）Lua 字串常值還原成實際內容"""
    return "".join(re.sub(r'\\(.)', r'\1', m[1:-1]) for m in re.findall(STR, lit))


def specs(s):
    return sorted(re.findall(r'%[-+ #0-9.]*[sdif%]', s))


def color_balanced(s):
    return len(re.findall(r'\|c[fF]{0,2}%?[0-9a-fA-F]{6,8}', s)) == len(re.findall(r'\|r', s))


# ── 原始碼用到的 key ──────────────────────────────────────
used = {}
for p in sorted(ROOT.rglob("*.lua")):
    if p.relative_to(ROOT).parts[0] == "Locales":
        continue
    txt = p.read_text(encoding="utf-8")
    for m in CALL.finditer(txt):
        k = unq(m.group(1))
        used.setdefault(k, str(p.relative_to(ROOT)))

problems = 0


def bad(msg):
    global problems
    problems += 1
    print("  ✗ " + msg)


print("原始碼用到 %d 個 key\n" % len(used))

locales = sorted(ROOT.glob("Locales/*.lua"))
for p in locales:
    name = p.stem
    if name == "Locale":
        continue
    txt = p.read_text(encoding="utf-8")

    # 守衛
    guard = re.search(r'GetLocale\(\)\s*~=\s*"(\w+)"', txt)
    guards = re.findall(r'GetLocale\(\)\s*~=\s*"(\w+)"', txt)

    defined, dupes = {}, []
    for m in DEF.finditer(txt):
        k, v = unq(m.group(1)), unq(m.group(2))
        if k in defined:
            dupes.append(k)
        defined[k] = v

    stub = len(defined) == 0
    print("── %s%s  定義 %d 條" % (name, "（空殼）" if stub else "", len(defined)))

    if not guards:
        bad("沒有 GetLocale 守衛")
    elif name not in guards:
        bad("守衛的語系代碼 %s 跟檔名 %s 對不起來" % (guards, name))

    if stub:
        print()
        continue

    missing = sorted(k for k in used if k not in defined)
    extra = sorted(k for k in defined if k not in used)
    if missing:
        bad("缺 %d 條：%s" % (len(missing), [k[:40] for k in missing[:5]]))
    if extra:
        bad("多餘 %d 條：%s" % (len(extra), [k[:40] for k in extra[:5]]))
    if dupes:
        bad("重複定義 %d 條（後面的會靜默蓋掉前面的）：%s" % (len(dupes), dupes[:5]))

    for k, v in defined.items():
        if specs(k) != specs(v):
            bad("格式符對不起來：key=%s → %s ／ 譯文 %s" % (k[:34], specs(k), specs(v)))
        if not color_balanced(v):
            bad("色碼沒配對：%s" % v[:50])
    same = [k for k, v in defined.items() if k == v and len(k) > 3]
    if same:
        print("  · 譯文與 key 相同 %d 條（可能漏翻）：%s" % (len(same), [k[:30] for k in same[:5]]))
    print()

# ── TOC ────────────────────────────────────────────────
# TOC 檔名跟資料夾同名（MiliUI_UnitFrames、MiliUI_Tooltip…），用 glob 找而不是寫死
toc_paths = sorted(ROOT.glob("*.toc"))
if not toc_paths:
    bad("找不到 .toc 檔")
    print("\n共 %d 個問題" % problems)
    sys.exit(1)
toc = toc_paths[0].read_text(encoding="utf-8")
lines = [l.strip() for l in toc.splitlines()]
listed = [l for l in lines if l.lower().startswith("locales\\")]
on_disk = sorted("Locales\\%s.lua" % p.stem for p in locales)
print("── TOC  列了 %d 個語系檔" % len(listed))
for f in on_disk:
    if f not in listed:
        bad("%s 在磁碟上但沒進 TOC（永遠不會載入）" % f)
for f in listed:
    if f not in on_disk:
        bad("TOC 列了 %s 但檔案不存在" % f)
try:
    if lines.index("Locales\\Locale.lua") > min(lines.index(x) for x in listed if x != "Locales\\Locale.lua"):
        bad("Locale.lua 必須排在其他語系檔之前（它建 ns.L）")
    if max(lines.index(x) for x in listed) > lines.index("Core\\Init.lua"):
        bad("語系檔必須排在 Core\\Init.lua 之前（那個檔載入時就用 L）")
except ValueError as e:
    bad("TOC 順序檢查失敗：%s" % e)

print("\n%s" % ("全部通過 ✓" if problems == 0 else "共 %d 個問題" % problems))
sys.exit(1 if problems else 0)
