#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""產生 THIRD_PARTY.md：套組收錄的第三方插件清單（上游、套組內版本、最近一次同步）。

    python3 .claude/scripts/third-party-manifest.py           重新產生 THIRD_PARTY.md
    python3 .claude/scripts/third-party-manifest.py --check   只比對有沒有過期（過期回傳 1；check-all 跑這個）

為什麼要有這份：第三方插件是整包覆蓋進來的，沒有上游 remote 可以 diff，`update: <插件>`
的 commit 只說「更新了」沒說從哪版到哪版。版本與同步日期由這支從 TOC 與 git log 算出來，
**上游網址是這支檔案裡手寫的表**（UPSTREAM）—— TOC 有 `X-Website`／`X-Curse-Project-ID`／
`X-Wago-ID` 的會自動推；沒有的要在 UPSTREAM 補，不然會列成「待補」。

怎麼認第三方：`AddOns/` 底下不以 `MiliUI` 開頭、且有 .toc 的資料夾。
"""
import io
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDONS = os.path.join(REPO, "AddOns")
OUT = os.path.join(REPO, "THIRD_PARTY.md")

# 手寫的上游網址（TOC 推不出來的）。查證過才填；不確定就留空，會印「待補」。
UPSTREAM = {
    "!BugGrabber": "https://github.com/funkydude/BugGrabber",
    "Baganator": "https://github.com/plusmouse/Baganator（套組用的是 fork 的 miliui 分支，見 notes/project-baganator-miliui-skin.md）",
    "Syndicator": "https://github.com/plusmouse/Syndicator",
    "Chattynator": "https://github.com/plusmouse/Chattynator",
    "Platynator": "https://github.com/plusmouse/Platynator",
    "Cell": "fork 自 https://github.com/enderneko/Cell，**2026-08-16 起不再追上游、我們自己就是上游**",
    "MythicDungeonTools": "https://github.com/Nnoggie/MythicDungeonTools",
    "MythicDungeonTools_UI": "隨 MythicDungeonTools 一起",
    "Plumber": "https://github.com/Peterodox/Plumber",
    "PremadeGroupsFilter": "https://github.com/0xbs/premade-groups-filter",
    "tullaRange": "https://github.com/Tuller/tullaRange",
    "tullaRange_Config": "隨 tullaRange 一起",
    "HandyNotes_Dragonflight": "https://github.com/zarillion/handynotes-plugins",
    "HandyNotes_TheWarWithin": "https://github.com/zarillion/handynotes-plugins",
    "HandyNotes_Midnight": "https://github.com/zarillion/handynotes-plugins",
}

# 跟套組綁在一起、不是獨立更新的（版本欄照印，但「最近同步」看主插件）
BUNDLED_WITH = {
    "MythicDungeonTools_UI": "MythicDungeonTools",
    "tullaRange_Config": "tullaRange",
}


def git(*args):
    return subprocess.run(["git", *args], cwd=REPO, capture_output=True, text=True, check=False).stdout.strip()


def toc_of(folder):
    name = os.path.basename(folder)
    for cand in (name + ".toc", name + "_Mainline.toc"):
        p = os.path.join(folder, cand)
        if os.path.isfile(p):
            return p
    tocs = sorted(f for f in os.listdir(folder) if f.lower().endswith(".toc"))
    return os.path.join(folder, tocs[0]) if tocs else None


def toc_fields(path):
    out = {}
    with io.open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            m = re.match(r"^##\s*([\w-]+)\s*:\s*(.*?)\s*$", line.strip())
            if m:
                out.setdefault(m.group(1), m.group(2))
    return out


def upstream_of(name, fields):
    if name in UPSTREAM:
        return UPSTREAM[name]
    for key in ("X-Website", "X-GitHub", "X-Project"):
        if fields.get(key):
            return fields[key]
    if fields.get("X-Curse-Project-ID"):
        return "https://www.curseforge.com/projects/" + fields["X-Curse-Project-ID"]
    if fields.get("X-Wago-ID"):
        return "https://addons.wago.io/addons/" + fields["X-Wago-ID"]
    return "待補"


def last_sync(name):
    # 最近一次「update:」的 commit；沒有就退回最近一次碰到這個資料夾的 commit（首次收錄）
    rel = "AddOns/" + name
    line = git("log", "-1", "--format=%ad %h", "--date=short", "--grep=^update:", "--", rel)
    tag = ""
    if not line:
        line = git("log", "-1", "--format=%ad %h", "--date=short", "--", rel)
        tag = "（收錄）"
    return (line + tag) if line else "—"


def build():
    rows = []
    for name in sorted(os.listdir(ADDONS), key=str.lower):
        folder = os.path.join(ADDONS, name)
        if not os.path.isdir(folder) or name.startswith("MiliUI") or name.startswith("."):
            continue
        toc = toc_of(folder)
        if not toc:
            continue
        fields = toc_fields(toc)
        version = fields.get("Version", "") or "—"
        sync = last_sync(BUNDLED_WITH.get(name, name))
        rows.append((name, version, sync, upstream_of(name, fields)))

    lines = [
        "# 套組收錄的第三方插件",
        "",
        "由 `python3 .claude/scripts/third-party-manifest.py` 產生，**不要手改**；上游網址改腳本裡的 `UPSTREAM` 表。",
        "「最近同步」是最後一次 `update: <插件>` 的 commit（沒有的話是首次收錄）。",
        "帶本地修改的插件見 [.claude/notes/project-local-addon-forks.md](.claude/notes/project-local-addon-forks.md)，",
        "守門與重套腳本見 [.claude/patches/](.claude/patches/README.md)。",
        "",
        "| 資料夾 | 套組內版本 | 最近同步 | 上游 |",
        "|---|---|---|---|",
    ]
    for name, version, sync, up in rows:
        lines.append("| %s | %s | %s | %s |" % (name, version.replace("|", "\\|"), sync, up))
    lines.append("")
    lines.append("共 %d 個資料夾。" % len(rows))
    return "\n".join(lines) + "\n"


def main():
    check = "--check" in sys.argv
    text = build()
    old = io.open(OUT, encoding="utf-8").read() if os.path.isfile(OUT) else None
    if check:
        if old == text:
            print("THIRD_PARTY.md 是最新的。")
            return 0
        print("THIRD_PARTY.md 過期了，跑 python3 .claude/scripts/third-party-manifest.py 重新產生。")
        return 1
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(text)
    print("已寫入 THIRD_PARTY.md" + ("（沒有變動）" if old == text else ""))
    missing = [l for l in text.splitlines() if l.endswith("| 待補 |")]
    if missing:
        print("上游待補 %d 筆：" % len(missing))
        for l in missing:
            print("  " + l.split("|")[1].strip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
