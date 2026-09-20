#!/usr/bin/env python3
"""MiliUI_Skin 的 Skin 契約 lint：配方與原語裡不准出現「會動到暴雪物件」的呼叫。

    python3 .claude/scripts/check_skin.py

這支插件的全部價值都建立在一條契約上：**只重畫，不重排。**
對暴雪物件只准 SetAlpha / SetVertexColor / SetTextColor / SetTexCoord /
SetColorTexture（限按鈕的 Highlight／Pushed／Checked 貼圖）／
SetDesaturated（限 Engine.Desaturate）／SetStatusBarTexture（限 Engine.BarTexture），
其餘一律禁止 —— 因為 12.1 之後
「寫一個暴雪會讀的欄位」與「讓自己的 Lua 跑在暴雪的執行流裡」都會把污染擴散到
完全不相干的系統，而錯誤訊息不會指向這裡（見 .claude/notes/wow-121-secret-values.md
與 wow-121-addon-code-in-secure-stack.md）。

契約靠人眼守不住：`frame:Hide()` 看起來人畜無害，跟合法的 `overlay:Hide()` 也只
差一個變數名。所以規則是**分檔**的：

  * `Core/Engine.lua`  —— 唯一可以對「自己的 overlay」做定位類呼叫的地方，不掃。
  * `Core/Primitives.lua` 與 `Skins/*.lua` —— 全掃。要操作 overlay 一律經由
    Engine 的函式（Engine.Overlay / Engine.Paint / Engine.Fill…）。

真的有例外就在行尾加 `-- skin-lint: own-frame`，那一行會放行並列進輸出的放行數
—— 看得到才管得住，靜默的例外等於沒有規則。

輸出風格照 .claude/scripts/check_lua.py。
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ADDON = os.path.join(REPO, "AddOns", "MiliUI_Skin")

ALLOW_MARK = "skin-lint: own-frame"

# 每一條都是 (正規式, 為什麼禁止)。
#
# ⚠ `PanelTemplates_` 只禁**呼叫**：`hooksecurefunc("PanelTemplates_SelectTab", …)`
#   是字串，那是合法而且必要的（分頁選中態唯一的來源）。所以樣式帶 `(`。
#
# ⚠ 這裡**沒有**禁 `hooksecurefunc`。池化列（ScrollBox 的 element）只能靠 mixin
#   後置勾來套（STYLE.md ③ 的陷阱 4），所以
#     hooksecurefunc(TokenEntryMixin, "Initialize", fn)      ← mixin 表
#     hooksecurefunc("AchievementObjectives_DisplayCriteria", fn)  ← 全域
#   兩種寫法都是合法的，不能誤報。後置勾不會把 taint 帶回呼叫端
#   （.claude/notes/project-charframe-taint.md 明列它不會汙染 CharacterFrame）。
#   真正危險的是**前置**替換（`X.Init = function() end`），那會在下面的
#   「結構性修改」那組被 `=` 左邊的寫法擋掉 —— 目前沒有規則抓得到它，
#   所以這一條靠 code review，記在這裡是為了下次有人想加規則時看得到。
RULES = [
    (r":Hide\s*\(",              "暴雪的框不可以 Hide —— 它會被暴雪自己的 Show 打回來，還會跟編輯模式打架"),
    (r":Show\s*\(",              "暴雪的框不可以 Show"),
    (r":SetShown\s*\(",          "暴雪的框不可以 SetShown"),
    (r":SetParent\s*\(",         "reparent 暴雪的框會改變它的 strata／層級／尺寸語意"),
    (r":ClearAllPoints\s*\(",    "不可以重排暴雪的框"),
    (r":SetPoint\s*\(",          "overlay 的定位一律走 Engine.Overlay 的 opts；暴雪的框不可以重排"),
    (r":SetSize\s*\(",           "不可以改暴雪物件的尺寸"),
    (r":SetWidth\s*\(",          "不可以改暴雪物件的尺寸"),
    (r":SetHeight\s*\(",         "不可以改暴雪物件的尺寸"),
    (r":SetScale\s*\(",          "縮放會連帶改掉位移量，而且會傳染給整棵子樹"),
    (r":SetScript\s*\(",         "SetScript 會把暴雪自己的處理器整個蓋掉；要加行為只能 HookScript"),
    (r":SetFrameLevel\s*\(",     "層級一律由 Engine.Overlay 決定"),
    (r":SetFrameStrata\s*\(",    "層級一律由 Engine.Overlay 決定"),
    (r":EnableMouse\s*\(",       "overlay 吃滑鼠會把暴雪按鈕的 OnEnter／OnClick 攔掉"),
    (r":SetAtlas\s*\(",          "中和一律用 alpha：暴雪會重新 SetAtlas，而且有程式會讀回 GetAtlas()"),
    (r":SetTexture\s*\(\s*nil",  "SetTexture(nil) 會讓讀回材質的暴雪程式拿到 nil 然後炸"),
    # 結構性修改：在暴雪按鈕上**補一張本來沒有的貼圖**，跟中和／換色不是同一件事。
    # 模板沒有 PushedTexture 就是沒有（STYLE.md ⑤ 的註 ⓒ），補一張等於改它的結構。
    (r":SetNormalTexture\s*\(",  "在暴雪按鈕上換／補狀態貼圖是結構性修改，不在白名單裡"),
    (r":SetPushedTexture\s*\(",  "在暴雪按鈕上換／補狀態貼圖是結構性修改，不在白名單裡"),
    (r":SetHighlightTexture\s*\(", "在暴雪按鈕上換／補狀態貼圖是結構性修改，不在白名單裡"),
    (r":SetCheckedTexture\s*\(", "在暴雪按鈕上換／補狀態貼圖是結構性修改，不在白名單裡"),
    # 第三輪把「換進度條的填充材質」放進白名單（STYLE.md ③）：那不是補一張本來沒有
    # 的狀態貼圖，是把本來就存在、本來就被 SetValue 改寬度的那一張換掉長相。
    # 但前提是「沒有程式讀回它」（`GetAtlas()`／`GetTexture()`），那要人去查原始碼、
    # lint 抓不到 ⇒ **只准走 `Engine.BarTexture`**，查證結果就記在那一支的註解裡。
    # 收緊不是放寬：配方與原語裡直接呼叫照樣是違規。
    (r":SetStatusBarTexture\s*\(",
     "換填充材質走 Engine.BarTexture（Skin.StatusBar 的 opts.texture）："
     "查證「有沒有程式讀回這張圖」的結果記在那一支的註解裡"),
    # 12.1：顏色分量可能是秘密數字，只有貼圖層的 setter 保證吃得下
    (r":SetStatusBarColor\s*\(", "上色走貼圖的 SetVertexColor：顏色分量在 12.1 可能是秘密數字"),
    # 讀暴雪物件的顏色**只准走 Engine.PassBorderColor**（當傳遞者不當讀取者）。
    # 在配方裡直接讀就會忍不住拿去做判斷，而那一次比較就是在讀秘密值。
    (r":GetVertexColor\s*\(",
     "讀顏色只准走 Engine.PassBorderColor：分量可能是秘密值，"
     "只能原封不動轉交，不能存、不能比較、不能算術"),
    # `SetChecked` 寫的是暴雪按鈕的**值**（玩家的設定），比寫欄位更嚴重。
    # 已勾的長相走 Engine.CheckedTexture —— 只換貼圖長相，顯示與否仍然是 C 端決定。
    (r":SetChecked\s*\(",        "勾沒勾是暴雪的值；我們只換 Checked 貼圖的長相"),
    # 去飽和只准走 Engine.Desaturate：那一支會擋掉「對按鈕下」的寫法
    # （對按鈕下去會把它所有狀態貼圖一起灰掉，不是「只換長相」），
    # 而且把「為什麼需要去飽和」的理由跟呼叫收在同一個地方。
    (r":SetDesaturated\s*\(",
     "去飽和走 Engine.Desaturate（Skin.IconButton 的 opts.desaturate）：只准對 region"),
    (r":LockHighlight\s*\(",     "LockHighlight 是寫暴雪按鈕的狀態；選中態走自己的 overlay"),
    (r":UnlockHighlight\s*\(",   "UnlockHighlight 是寫暴雪按鈕的狀態；選中態走自己的 overlay"),
    (r"\bPanelTemplates_\w+\s*\(", "不可以呼叫 PanelTemplates_*：那會寫暴雪框的欄位（selectedTab、isDisabled…）"),
    (r"\bShowUIPanel\s*\(",      "UIPanel 系是保護函式"),
    (r"\bHideUIPanel\s*\(",      "UIPanel 系是保護函式"),
    (r"StripTextures",           "遞迴清除式的中和會掃到暴雪還要用的區域"),
    (r"BackdropTemplate",        "BackdropTemplate 自帶 OnSizeChanged 的 Lua，會跑在暴雪的執行堆疊裡"),
    (r"\bsecurecall\s*\(",       "securecall 不會讓我們的碼變乾淨，只會讓錯誤更難追"),
    (r"\bseterrorhandler\s*\(",  "錯誤處理器一律走共用層的 ns.ReportError"),
]

COMPILED = [(re.compile(p), why) for p, why in RULES]


def scanned_files():
    """掃描範圍：Core/Primitives.lua ＋ Skins/*.lua。Core/Engine.lua 刻意不掃。"""
    prim = os.path.join(ADDON, "Core", "Primitives.lua")
    if os.path.isfile(prim):
        yield prim
    skins = os.path.join(ADDON, "Skins")
    if os.path.isdir(skins):
        for name in sorted(os.listdir(skins)):
            if name.endswith(".lua"):
                yield os.path.join(skins, name)


def strip_comment(line):
    """把行尾註解切掉再比對。

    ⚠ 沒有這一步，檔頭那張「taint 接觸面清單」（裡面照理會寫到 SetAlpha、
      甚至寫到「不可以 Hide」）會整片被當成違規。字串裡的引號要跟著看，
      否則 `"-- 這不是註解"` 也會被切掉。
    """
    i, n, quote = 0, len(line), None
    while i < n:
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "-" and i + 1 < n and line[i + 1] == "-":
            return line[:i]
        i += 1
    return line


def main():
    if not os.path.isdir(ADDON):
        print("找不到 AddOns/MiliUI_Skin —— 跳過")
        return 0

    hits = []
    allowed = []
    count = 0

    for path in scanned_files():
        count += 1
        rel = os.path.relpath(path, REPO)
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()

        # 長註解整段拿掉（檔頭的接觸面清單如果改成 --[[ ]] 也要擋得住）。
        # 換行數保留，行號才不會跑掉。
        raw = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m.group(0).count("\n"),
                     raw, flags=re.S)

        for lineno, line in enumerate(raw.split("\n"), 1):
            if ALLOW_MARK in line:
                allowed.append(f"{rel}:{lineno}")
                continue
            code = strip_comment(line)
            if not code.strip():
                continue
            for rx, why in COMPILED:
                if rx.search(code):
                    hits.append((rel, lineno, code.strip(), why))

    print(f"掃了 {count} 個檔（Core/Primitives.lua ＋ Skins/*.lua；Core/Engine.lua 不在範圍內）")

    if hits:
        print(f"\n違反 Skin 契約 {len(hits)} 處：")
        for rel, lineno, code, why in hits:
            print(f"  {rel}:{lineno}")
            print(f"      {code}")
            print(f"      → {why}")
        print(f"\n真的是對「自己建的 overlay」做的，就把那一行搬進 Core/Engine.lua，"
              f"\n或在行尾加  -- {ALLOW_MARK}  放行（放行數會印出來）。")
    else:
        print("Skin 契約：沒有違規")

    if allowed:
        print(f"\n以 `-- {ALLOW_MARK}` 放行 {len(allowed)} 行：")
        for x in allowed:
            print(f"  {x}")

    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
