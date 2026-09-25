#!/usr/bin/env python3
"""Cell（本地分支）的 Lua 檢查：語法 ＋ UnitButton.lua 主 chunk 的 local 餘裕 ＋ upvalue 上限。

    python3 .claude/scripts/check_cell.py

check_lua.py 只掃自製插件；Cell 是帶本地修改的第三方插件，它有兩個「編譯期硬上限、
不報錯到遊戲裡才整支不載入」的地雷，這支專門盯它們：

1. `luac -p` —— Cell/ 底下（不含 Libs/）每個 .lua 都要編得過。

2. RaidFrames/UnitButton.lua 主 chunk 的 local 餘裕。Lua 一個函式同時存活的 local 上限
   是 200，超過是編譯錯誤（"too many local variables"）＝整支檔案不載入＝團隊框全部消失。
   這支檔案曾經剛好卡在 200（餘裕 0），加一個檔案層 local 就炸。量法：在檔尾追加 N 個
   `local __probeN = N`，二分找出最多還能加幾個仍可編譯。本機 luac 5.5 對這個上限的
   計算跟遊戲的 5.1 一樣。餘裕 < MIN_HEADROOM 就失敗。

3. upvalue ≤ 60。遊戲的 Lua 5.1 一個函式最多 60 個 upvalue，超過在遊戲裡是
   LUA_WARNING；本機 luac 5.5 的上限是 255，**編譯不會報**，只能從 `luac -l -l` 的
   upvalues 清單自己數。5.5 會把 `_ENV` 也算成一個 upvalue、5.1 沒有這個東西，所以
   清單裡有 `_ENV` 時減 1 才是遊戲裡的數字。
   ⚠ UPVALUE_ENFORCED 裡的檔案超標＝失敗；其他 Cell 檔超標只警告 —— 上游本來就有的
   超標不是這裡該修的，但要看得到。

原理見 .claude/notes/project-cell-unitbutton-local-ceiling.md。
"""

import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
CELL = os.path.join(REPO, "AddOns", "Cell")

UNITBUTTON = os.path.join(CELL, "RaidFrames", "UnitButton.lua")
MIN_HEADROOM = 20

UPVALUE_LIMIT = 60
# 我們自己動過、而且曾經貼著上限的檔：超標直接失敗
UPVALUE_ENFORCED = {
    os.path.join("RaidFrames", "UnitButton.lua"),
    os.path.join("Modules", "Appearance", "Appearance.lua"),
}


def lua_files():
    for dirpath, dirnames, filenames in os.walk(CELL):
        dirnames[:] = sorted(d for d in dirnames if d != "Libs")
        for name in sorted(filenames):
            if name.endswith(".lua"):
                yield os.path.join(dirpath, name)


def compiles(path):
    return subprocess.run(["luac", "-p", path], capture_output=True).returncode == 0


def local_headroom(path):
    """檔尾最多還能追加幾個 local 仍可編譯。原檔編不過回 None。"""
    with open(path, encoding="utf-8") as f:
        src = f.read()

    def ok(n):
        probe = "".join(f"local __probe{i} = {i}\n" for i in range(n))
        fd, tmp = tempfile.mkstemp(suffix=".lua")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as t:
                t.write(src + "\n" + probe)
            return compiles(tmp)
        finally:
            os.remove(tmp)

    if not ok(0):
        return None
    lo, hi = 0, 1
    while ok(hi):
        lo, hi = hi, hi * 2
        if hi > 4096:          # 不可能這麼多；防呆
            return lo
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if ok(mid):
            lo = mid
        else:
            hi = mid
    return lo


FUNC_RE = re.compile(r"^(?:main|function) <[^:]+:(\d+),\d+>")
UPVAL_HDR_RE = re.compile(r"^upvalues \((\d+)\)")


def upvalue_counts(path):
    """[(定義行, 5.1 等效 upvalue 數)]，只回超過上限的。"""
    out = subprocess.run(["luac", "-l", "-l", "-p", path],
                         capture_output=True, text=True).stdout
    hits = []
    line_no = None
    lines = out.splitlines()
    i = 0
    while i < len(lines):
        m = FUNC_RE.match(lines[i])
        if m:
            line_no = int(m.group(1))
        h = UPVAL_HDR_RE.match(lines[i])
        if h and line_no is not None:
            n = int(h.group(1))
            names = [l.split()[1] for l in lines[i + 1:i + 1 + n] if len(l.split()) > 1]
            n51 = n - (1 if "_ENV" in names else 0)
            if n51 > UPVALUE_LIMIT:
                hits.append((line_no, n51))
            i += n
        i += 1
    return hits


def main():
    if subprocess.run(["luac", "-v"], capture_output=True).returncode != 0:
        print("找不到 luac —— 這台機器沒裝 Lua，跳過檢查")
        return 1
    if not os.path.isdir(CELL):
        print("沒有 AddOns/Cell，跳過")
        return 0

    fail = False
    syntax, up_err, up_warn = [], [], []
    count = 0
    for path in lua_files():
        count += 1
        rel = os.path.relpath(path, CELL)
        proc = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
        if proc.returncode != 0:
            syntax.append((rel, proc.stderr.strip()))
            continue
        for line, n in upvalue_counts(path):
            (up_err if rel in UPVALUE_ENFORCED else up_warn).append((rel, line, n))

    print(f"掃了 {count} 個 .lua（Cell 本體，不含 Libs/）")

    if syntax:
        fail = True
        print(f"\n語法錯誤 {len(syntax)}：")
        for rel, err in syntax:
            print(f"  Cell/{rel}\n      {err}")
    else:
        print("語法：全過")

    headroom = local_headroom(UNITBUTTON) if os.path.exists(UNITBUTTON) else None
    if headroom is None:
        fail = True
        print("UnitButton.lua 主 chunk 餘裕：量不到（檔案本身編不過）")
    elif headroom < MIN_HEADROOM:
        fail = True
        print(f"UnitButton.lua 主 chunk 餘裕 {headroom}（低於 {MIN_HEADROOM}）"
              " —— 上限 200 個同時存活的 local，超過整支不載入。"
              "把區段私有的狀態收進 do … end，或拿掉冷路徑的 API 快取")
    else:
        print(f"UnitButton.lua 主 chunk 餘裕 {headroom}")

    if up_err:
        fail = True
        print(f"\nupvalue 超過 {UPVALUE_LIMIT}（5.1 算法）的函式 {len(up_err)}：")
        for rel, line, n in up_err:
            print(f"  Cell/{rel}:{line}  →  {n} 個")
    if up_warn:
        print(f"\n⚠ 警告（不擋）：其他 Cell 檔 upvalue 超過 {UPVALUE_LIMIT} 的函式 {len(up_warn)}：")
        for rel, line, n in up_warn:
            print(f"  Cell/{rel}:{line}  →  {n} 個")
    if not up_err and not up_warn:
        print(f"upvalue：沒有超過 {UPVALUE_LIMIT} 的函式（5.1 算法，不含 _ENV）")
    elif not up_err:
        print(f"upvalue：{'、'.join(sorted(UPVALUE_ENFORCED))} 沒有超過 {UPVALUE_LIMIT}")

    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
