#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 .claude/notes/*.md 的 frontmatter 整理成索引表，寫進 notes/README.md 的自動區塊。

    python3 .claude/scripts/notes-index.py           重寫 README.md 的自動區塊
    python3 .claude/scripts/notes-index.py --check   只比對（落後回傳 1）

sync-notes.sh 匯出之後會順手叫這支，所以正常情況不用手動跑。

README.md 上半是人手整理的分組索引（有重點、有粗體），那部分不動；
自動區塊夾在 `<!-- notes-index:start -->` 與 `<!-- notes-index:end -->` 之間，
列出**全部**筆記（以 frontmatter 的 `name`／`description` 為準），按檔名前綴分四組。
人手索引漏掉的篇，至少在這裡找得到。
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
NOTES = os.path.join(REPO, ".claude", "notes")
README = os.path.join(NOTES, "README.md")

START = "<!-- notes-index:start -->"
END = "<!-- notes-index:end -->"

GROUPS = [
    ("wow-121-", "12.1／12.x API 規則"),
    ("wow-12", "12.1／12.x API 規則"),
    ("wow-", "暴雪 UI 通則與工具"),
    ("project-", "專案現況"),
    ("feedback-", "使用者回饋與工作慣例"),
]


def frontmatter(path):
    text = io.open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    fields = {}
    if m:
        for line in m.group(1).splitlines():
            km = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
            if km and not line.startswith(" "):
                v = km.group(2).strip()
                if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                    v = v[1:-1]
                fields[km.group(1)] = v
    return fields


def group_of(base):
    for prefix, title in GROUPS:
        if base.startswith(prefix):
            return title
    return "其他"


def build():
    by_group = {}
    for base in sorted(os.listdir(NOTES)):
        if not base.endswith(".md") or base == "README.md":
            continue
        fm = frontmatter(os.path.join(NOTES, base))
        desc = fm.get("description", "").replace("|", "\\|").replace("\n", " ")
        by_group.setdefault(group_of(base), []).append((base, desc or "（沒有 description）"))

    order = []
    for _, title in GROUPS:
        if title not in order:
            order.append(title)
    order.append("其他")

    total = sum(len(v) for v in by_group.values())
    lines = [START,
             "## 全部筆記（自動產生，共 %d 篇）" % total,
             "",
             "由 `python3 .claude/scripts/notes-index.py` 從各篇 frontmatter 的 `description` 產生；"
             "`sync-notes.sh` 匯出後會自動重寫。上面的分組索引是人手整理的，這裡保證不漏篇。",
             ""]
    for title in order:
        rows = by_group.get(title)
        if not rows:
            continue
        lines += ["### %s" % title, "", "| 檔案 | description |", "|---|---|"]
        for base, desc in rows:
            lines.append("| [%s](%s) | %s |" % (base, base, desc))
        lines.append("")
    lines.append(END)
    return "\n".join(lines)


def main():
    check = "--check" in sys.argv
    readme = io.open(README, encoding="utf-8").read()
    block = build()
    if START in readme and END in readme:
        head = readme[: readme.index(START)]
        tail = readme[readme.index(END) + len(END):]
        new = head + block + tail
    else:
        new = readme.rstrip("\n") + "\n\n" + block + "\n"
    if check:
        if new == readme:
            print("notes/README.md 的自動索引是最新的。")
            return 0
        print("notes/README.md 的自動索引落後了，跑 python3 .claude/scripts/notes-index.py。")
        return 1
    if new != readme:
        io.open(README, "w", encoding="utf-8", newline="\n").write(new)
        print("已重寫 notes/README.md 的自動索引。")
    else:
        print("自動索引沒有變動。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
