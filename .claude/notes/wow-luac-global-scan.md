---
name: wow-luac-global-scan
description: luac -p 只驗語法抓不到未宣告的全域；用 luac -l 掃 _ENV 讀取才找得出「該是 local 卻寫成全域」
metadata: 
  node_type: memory
  type: reference
  originSessionId: 1c4053d2-0bf5-47a0-b612-8c4a21559dcf
  modified: 2026-08-17T02:46:16.731Z
---

`luac -p` **只檢查語法**。少一行 `local L = ns.L`、或變數在宣告之前就被使用，它一律放行，
到遊戲裡才會炸成 `attempt to index a nil value`——而且那種錯常常發生在檔案中段，
導致該檔後面的東西（例如 `ns.frames = {}`）全部沒跑到，錯誤訊息卻指向完全不相干的地方。

補一道靜態檢查：把每個檔編成位元組碼，掃它「從 `_ENV` 讀了哪些名字」。

⚠⚠ **只 grep `_ENV "名字"` 會在大檔上靜默漏掉。** 常數超過 255 個的檔案，Lua 5.5
不會發 `GETTABUP … ; _ENV "name"`，而是拆成三行：

```
GETUPVAL  r5 0        ; _ENV
LOADK     r6 "GetMouseFoci"
GETTABLE  r5 r5 r6
```

註解裡根本沒有 `_ENV "name"`，舊寫法直接跳過。**這正是這道檢查存在要抓的那類 bug ——
而它在專案最大的檔案上失效**。2026-08-19 在 `MiliUI_UnitFrames/Api.lua` 實測：
舊寫法抓到 54 個名字、新寫法 61 個 —— 三行形式出現 15 次，漏掉 7 個不同的名字
（`C_CurveUtil`、`C_Secrets`、`C_Spell`、`EditModeManagerFrame`、`GetMouseFoci`、
`GetShapeshiftFormID`、`next`）。判斷某個檔能不能信舊寫法：

```bash
luac -l -p <檔> | grep -c 'GETUPVAL.*; _ENV$'    # 非 0 就代表舊寫法不可信
```

兩種形式都要認。可以直接用這支（Python，不必外部套件）：

```python
import subprocess, re
def globals_read(path):
    out = subprocess.run(["luac", "-l", "-p", path], capture_output=True, text=True).stdout
    names = set(re.findall(r'_ENV "([^"]+)"', out))          # 一般形式
    lines = out.split("\n")
    for i, ln in enumerate(lines):                            # 大常數表的三行形式
        if re.search(r'GETUPVAL.*; _ENV\s*$', ln):
            for j in range(i + 1, min(i + 4, len(lines))):
                m = re.search(r'LOADK.*; "([^"]+)"', lines[j])
                if m: names.add(m.group(1)); break
    return names
```

（Lua 5.1 是 `GETGLOBAL`，5.2 之後改成 `GETTABUP … _ENV`。本機的 luac 是 5.5。）

## 比對法比清單法好用

把「全域名單扣掉暴雪 API」很麻煩（要維護白名單）。實務上更有效的是**跟改動前比對**：

```python
added = globals_read(現在的檔) - globals_read(git show BASE:同一個檔)
```

新增的名字通常只有幾個，一眼就看得出哪個是打錯字或漏掉的 `local`。
2026-08-19 那次大規模修改（45 檔）用這招驗完，新增的九個全是合法的
`xpcall` / `C_Timer` / `tinsert` 之類，零誤判。

**改重構時更要看「全域寫入」**：`SETTABUP … _ENV "name"` 代表指派到全域，
那幾乎一定是漏了 `local`。把 tab 的 `content`／`scroll` 之類改成由 helper 回傳再賦值時，
只要原本的 `local` 宣告漏了一個就會靜默變成全域：

```bash
luac -l -p <檔> | grep -oE 'SETTABUP.*_ENV "[A-Za-z_][A-Za-z0-9_]*"'
```

把結果扣掉暴雪 API、Lua 標準庫、自己刻意輸出的全域，剩下的就是嫌疑犯。
兩次實際抓到的東西：

- **`L`**：i18n 重構時腳本用 `^local _, ns = \.\.\.` 這個正規式插入 `local L = ns.L`，
  但 `Core/Init.lua` 的第一行是 `local ADDON, ns = ...` → 沒插到 → 整個插件掛掉。
  **教訓：機械式重構加了 header，一定要反向驗證「每個用到它的檔都宣告了」**：

  ```bash
  # 用了 L[ 卻沒有 local L = 的檔
  grep -rln 'L\[' --include="*.lua" . | xargs grep -L '^\s*local L\s*='
  ```

- **`previewOn`**（`Elements/Totems.lua`）：`local` 宣告寫在使用點**下面**，
  所以使用點讀到的是全域 nil，整個預覽分支變死碼、零錯誤零徵兆。

相關：[[project-miliui-unit-frame]]

## `luac -p` 過得了、但一定會炸的另一類：機械式取代打到自己

2026-08-19 實際踩到。當時要把七個「暗色」顏色方法統一加上秘密值守衛，做法是先插入一支
helper，再把七處的計算行全域取代成呼叫 helper：

```python
s = s.replace(helper_source, ...)                       # 先插入 helper
s = s.replace("    return r * 0.3, g * 0.3, b * 0.3, a\n", "    return Dim(r, g, b, a)\n")
```

第二個 replace **把剛插入的 helper 自己的函式本體也換掉了**，於是：

```lua
local function Dim(r, g, b, a)
    if ns.IsSecret(r) then return r, g, b, a end
    return Dim(r, g, b, a)      -- ← 無限遞迴
end
```

`luac -p` 完全過得了（語法合法），要到遊戲裡才會爆堆疊。

**規則：全域取代與「插入新程式碼」不要放在同一支腳本裡。** 真的要合併就把插入放最後，
或給 helper 的本體用一個不會被 pattern 命中的寫法。改完一定要回頭看 helper 本身：

```bash
grep -A4 'local function <Helper>' <檔>     # 確認函式體沒有呼叫自己
```

同一類的還有：`sed 's/foo/bar/'` 把註解裡的說明文字也改掉、把 helper 名稱本身改掉。
**每次機械式取代之後，diff 一定要逐段看過，不能只看 `luac -p` 的結果。**
