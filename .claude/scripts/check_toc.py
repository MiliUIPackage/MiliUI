#!/usr/bin/env python3
"""自製插件的 TOC 檢查：載入清單對得上磁碟嗎、Interface 版本號有沒有漏。

    python3 .claude/scripts/check_toc.py

三件事：

1. **TOC 列了但檔案不存在** —— 遊戲會靜默略過那一行，插件少半套功能而且不報錯。
2. **檔案在磁碟上但沒進 TOC** —— 通常是新增檔案忘了掛，症狀同上（而且更難發現，
   因為你「明明寫了」）。⚠ 經由 `.xml` 間接載入的檔案不算漏，所以要把 XML 裡的
   `<Script file="..."/>` 一起收進來。
3. **有插件沒跟上最新的 Interface 版本號** —— 那幾支在新改版上線時會顯示「過期」。
   2026-08-28 體檢時有三支停在 `120007, 120100`，就是這樣漏掉的。

   ⚠ 判準是「**有沒有人落後**」，不是「是不是全都一樣」。舊插件多列一個 `120007`
   （還支援 12.0.7）跟新插件只列 `120100, 120105`（12.1 之後才寫的、用了那時候才有的
   API）兩種都對，硬要對齊反而會把「這支在舊版跑不起來」這個事實抹掉。
   所以只比最大的那個號碼，向下相容的部分各自決定。

   ⚠ 要 bump 用 `.claude/skills/wow-toc-interface-bump` 的腳本，不要手改
   （六位數 retail／五位數 classic 的規則很容易弄錯）。
"""

import os
import re
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")

SCRIPT_RE = re.compile(r'<Script\s+file\s*=\s*"([^"]+)"', re.I)
INCLUDE_RE = re.compile(r'<Include\s+file\s*=\s*"([^"]+)"', re.I)


def norm(p):
    return p.replace("\\", "/").strip()


def read(path):
    with open(path, encoding="utf-8-sig", errors="replace") as fh:
        return fh.read()


def xml_refs(addon_root, rel_xml, seen):
    """把一個 .xml 裡 <Script>/<Include> 指到的檔案攤平（路徑相對於該 xml 所在目錄）。"""
    out = set()
    if rel_xml in seen:
        return out
    seen.add(rel_xml)
    full = os.path.join(addon_root, rel_xml)
    if not os.path.isfile(full):
        return out
    base = os.path.dirname(rel_xml)
    text = read(full)
    for m in list(SCRIPT_RE.finditer(text)) + list(INCLUDE_RE.finditer(text)):
        ref = norm(os.path.normpath(os.path.join(base, norm(m.group(1)))))
        out.add(ref)
        if ref.lower().endswith(".xml"):
            out |= xml_refs(addon_root, ref, seen)
    return out


def main():
    problems = 0
    interfaces = defaultdict(list)

    for addon in sorted(os.listdir(ADDONS)):
        if addon != "MiliUI" and not addon.startswith("MiliUI_"):
            continue
        root = os.path.join(ADDONS, addon)
        if not os.path.isdir(root):
            continue
        tocs = [f for f in os.listdir(root) if f.endswith(".toc")]
        if not tocs:
            print(f"!! {addon} 沒有 .toc")
            problems += 1
            continue
        toc = os.path.join(root, tocs[0])
        text = read(toc)

        m = re.search(r"^##\s*Interface\s*:\s*(.+)$", text, re.M)
        if m:
            vals = tuple(sorted(v.strip() for v in m.group(1).split(",") if v.strip()))
            interfaces[vals].append(addon)
        else:
            print(f"!! {addon} 的 TOC 沒有 ## Interface")
            problems += 1

        # TOC 直接列的檔案
        listed = set()
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.lower().endswith((".lua", ".xml")):
                listed.add(norm(line))

        referenced = set(listed)
        seen = set()
        for rel in list(listed):
            if rel.lower().endswith(".xml"):
                referenced |= xml_refs(root, rel, seen)

        for rel in sorted(referenced):
            if not os.path.isfile(os.path.join(root, rel)):
                print(f"!! {addon}: TOC/XML 指到不存在的檔案 → {rel}")
                problems += 1

        on_disk = set()
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d != "Libs"]
            for name in filenames:
                if name.endswith((".lua", ".xml")):
                    on_disk.add(norm(os.path.relpath(os.path.join(dirpath, name), root)))

        for rel in sorted(on_disk - referenced):
            print(f"!! {addon}: 檔案沒被載入（TOC 與 XML 都沒列）→ {rel}")
            problems += 1

    print()
    # 只看 retail（六位數）；五位數是經典服，混在一起比會得到胡說八道的答案
    retail = {v for vals in interfaces for v in vals if re.fullmatch(r"\d{6}", v)}
    if not retail:
        print("!! 一個 retail Interface 版本都沒讀到")
        return 1
    newest = max(retail)
    behind = [(addon, vals) for vals, addons in interfaces.items()
              for addon in addons if newest not in vals]
    if behind:
        print(f"最新的 Interface 是 {newest}，下列沒跟上（新改版一上線就會顯示過期）：")
        for addon, vals in sorted(behind):
            print(f"  {addon:36s} {', '.join(vals)}")
        print("\n用 .claude/skills/wow-toc-interface-bump 的腳本 bump，不要手改。")
        problems += 1
    else:
        n = sum(len(v) for v in interfaces.values())
        print(f"Interface：{n} 支全部含 {newest}")
        for vals, addons in sorted(interfaces.items()):
            print(f"  {', '.join(vals):26s}  {len(addons)} 支")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
