#!/usr/bin/env python3
"""Cell（本地分支）的 Lua 檢查：語法 ＋ 每支檔案主 chunk 的 local 餘裕 ＋ upvalue 上限。

    python3 .claude/scripts/check_cell.py

check_lua.py 只掃自製插件；Cell 是帶本地修改的第三方插件，它有兩個「編譯期硬上限、
不報錯到遊戲裡才整支不載入」的地雷，這支專門盯它們：

1. `luac -p` —— Cell/ 底下（不含 Libs/）每個 .lua 都要編得過。

2. 每支檔案主 chunk 的 local 餘裕。Lua 一個函式同時存活的 local 上限是 200，超過是
   編譯錯誤（"too many local variables"）＝整支檔案不載入。UnitButton.lua 曾經剛好卡在
   200（餘裕 0），加一個檔案層 local 就炸＝團隊框全部消失。量法：在檔尾追加 N 個
   `local __probeN = N`，二分找出最多還能加幾個仍可編譯。本機 luac 5.5 對這個上限的
   計算跟遊戲的 5.1 一樣。
   ⚠ 檔尾是 `return X` 的檔（AuraDisplay.lua 的 `return AD`）要把探針插在 return 前面——
   接在後面是語法錯誤，會量成餘裕 0（2026-09-25 誤報過一次）。
   UnitButton.lua 餘裕 < MIN_HEADROOM 失敗；其他檔 < MIN_HEADROOM_ANY 失敗、
   < MIN_HEADROOM 警告。

3. upvalue ≤ 60。遊戲的 Lua 5.1 一個函式最多 60 個 upvalue，超過在遊戲裡是
   LUA_WARNING；本機 luac 5.5 的上限是 255，**編譯不會報**，只能從 `luac -l -l` 的
   upvalues 清單自己數。5.5 會把 `_ENV` 也算成一個 upvalue、5.1 沒有這個東西，所以
   清單裡有 `_ENV` 時減 1 才是遊戲裡的數字。
   任何 Cell 檔超過 UPVALUE_LIMIT 都失敗（2026-09-25 全部檔案都在上限內）；
   ≥ UPVALUE_WARN 警告，最緊的是設定面板那種「一個函式建一整頁控件」的寫法。

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
MIN_HEADROOM = 20       # UnitButton 低於這個失敗；其他檔低於這個警告
MIN_HEADROOM_ANY = 10   # 其他檔低於這個失敗

UPVALUE_LIMIT = 60
UPVALUE_WARN = 55


def lua_files():
    for dirpath, dirnames, filenames in os.walk(CELL):
        dirnames[:] = sorted(d for d in dirnames if d != "Libs")
        for name in sorted(filenames):
            if name.endswith(".lua"):
                yield os.path.join(dirpath, name)


def compiles(path):
    return subprocess.run(["luac", "-p", path], capture_output=True).returncode == 0


TRAILING_RETURN_RE = re.compile(r"\n[ \t]*return\b[^\n]*\s*$")


def local_headroom(path, enough=None):
    """檔尾最多還能追加幾個 local 仍可編譯。原檔編不過回 None。
    enough：只想知道「至少有這麼多」時給，夠了就直接回它（省掉二分）。"""
    with open(path, encoding="utf-8") as f:
        src = f.read()
    # 主 chunk 的最後一句是 return 時，探針要插在它前面（後面只能是 <eof>）
    m = TRAILING_RETURN_RE.search(src)
    head, tail = (src[:m.start()], src[m.start():]) if m else (src, "")

    def ok(n):
        probe = "".join(f"local __probe{i} = {i}\n" for i in range(n))
        fd, tmp = tempfile.mkstemp(suffix=".lua")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as t:
                t.write(head + "\n" + probe + tail)
            return compiles(tmp)
        finally:
            os.remove(tmp)

    if not ok(0):
        return None
    if enough is not None and ok(enough):
        return enough
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
    """[(定義行, 5.1 等效 upvalue 數)]，只回 ≥ UPVALUE_WARN 的。"""
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
            if n51 >= UPVALUE_WARN:
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
    hr_err, hr_warn = [], []
    ub_headroom = None
    count = 0
    for path in lua_files():
        count += 1
        rel = os.path.relpath(path, CELL)
        proc = subprocess.run(["luac", "-p", path], capture_output=True, text=True)
        if proc.returncode != 0:
            syntax.append((rel, proc.stderr.strip()))
            continue
        for line, n in upvalue_counts(path):
            (up_err if n > UPVALUE_LIMIT else up_warn).append((rel, line, n))

        if path == UNITBUTTON:
            h = local_headroom(path)
            ub_headroom = h
        else:
            # 大部分檔離上限很遠：先問「夠不夠 MIN_HEADROOM」，不夠才二分出確切數字
            h = local_headroom(path, enough=MIN_HEADROOM)
            if h is not None and h < MIN_HEADROOM:
                (hr_err if h < MIN_HEADROOM_ANY else hr_warn).append((rel, h))

    print(f"掃了 {count} 個 .lua（Cell 本體，不含 Libs/）")

    if syntax:
        fail = True
        print(f"\n語法錯誤 {len(syntax)}：")
        for rel, err in syntax:
            print(f"  Cell/{rel}\n      {err}")
    else:
        print("語法：全過")

    if not os.path.exists(UNITBUTTON) or ub_headroom is None:
        fail = True
        print("UnitButton.lua 主 chunk 餘裕：量不到（檔案不存在或編不過）")
    elif ub_headroom < MIN_HEADROOM:
        fail = True
        print(f"UnitButton.lua 主 chunk 餘裕 {ub_headroom}（低於 {MIN_HEADROOM}）"
              " —— 上限 200 個同時存活的 local，超過整支不載入。"
              "把區段私有的狀態收進 do … end，或拿掉冷路徑的 API 快取")
    else:
        print(f"UnitButton.lua 主 chunk 餘裕 {ub_headroom}")

    if hr_err:
        fail = True
        print(f"\n主 chunk local 餘裕低於 {MIN_HEADROOM_ANY} 的檔 {len(hr_err)}（上限 200，超過整支不載入）：")
        for rel, h in hr_err:
            print(f"  Cell/{rel}  →  餘裕 {h}")
    if hr_warn:
        print(f"\n⚠ 警告（不擋）：主 chunk local 餘裕低於 {MIN_HEADROOM} 的檔 {len(hr_warn)}：")
        for rel, h in hr_warn:
            print(f"  Cell/{rel}  →  餘裕 {h}")
    if not hr_err and not hr_warn:
        print(f"其他檔主 chunk 餘裕：全部 ≥ {MIN_HEADROOM}")

    if up_err:
        fail = True
        print(f"\nupvalue 超過 {UPVALUE_LIMIT}（5.1 算法）的函式 {len(up_err)}：")
        for rel, line, n in up_err:
            print(f"  Cell/{rel}:{line}  →  {n} 個")
    if up_warn:
        print(f"\n⚠ 警告（不擋）：upvalue ≥ {UPVALUE_WARN} 的函式 {len(up_warn)}"
              "（拆出子函式，見 Appearance.lua 的 LoadColorThresholds）：")
        for rel, line, n in up_warn:
            print(f"  Cell/{rel}:{line}  →  {n} 個")
    if not up_err and not up_warn:
        print(f"upvalue：全部 < {UPVALUE_WARN}（上限 {UPVALUE_LIMIT}，5.1 算法，不含 _ENV）")

    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
