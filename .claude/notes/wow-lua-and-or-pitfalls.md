---
name: wow-lua-and-or-pitfalls
description: Lua 的 `a and b or c` 兩個地雷——b 是 false 時整式退成 c（「取消勾選永遠存成 nil」）、`x and f()` 只留 f 的第一個回傳值（GetCenter 的 y 變 nil）；check_lua.py 抓不到，同一症狀在 MiliUI_CooldownManager 三天內踩三次
metadata:
  type: reference
---

兩個都是 Lua 語言本身的行為，不是 WoW API；lint（`check_lua.py`）抓不到，程式看起來也很合理，所以會重複踩。

**① `cond and false or nil` 永遠是 nil。** `and`／`or` 是短路運算：`false or nil` ⇒ nil。
症狀：「取消勾選沒有作用」——勾選框存三態（nil＝跟隨、false＝關、true＝開）時，把關寫成 `(not on) and false or nil`，
關那一邊永遠寫進 nil ⇒ 存檔看起來跟沒設一樣、重載後又回到跟隨。MiliUI_CooldownManager 2026-09-30 資源列「這個專精要顯示哪些」、
2026-10-02 生效發光「脫戰也亮」各踩一次（268b741a5、b59701952）。
**寫法**：要存 false 的值一律用 `if`：
```lua
local v = nil
if not on then v = false end
DB.SetOverride(id, key, v)
```
三態欄位凡是「沒有／不要」存 `false` 不存 `nil`（否則合併預設值時被補回來），所以這個地雷在三態設定裡特別常見。

**② `x and f()` 只留 f 的第一個回傳值。** `and` 的結果是單一值，後面的回傳值被截掉。
症狀：`local nx, ny = n and n:GetCenter()` ⇒ ny 永遠 nil，拖曳排序算插入位置時報錯（2026-10-03，5051e7f13）。
同類：`local ok, a, b = cond and pcall(...)`、`return frame and frame:GetPoint()`。
**寫法**：多回傳值的呼叫不要接在 `and` 後面，拆成 `if n then nx, ny = n:GetCenter() end`。

**How to apply:** code review 看到 `and false or`、`and <多回傳值函式>()` 就停下來；寫三態設定與幾何讀取時先想這兩條。
相關：[[project-miliui-cooldownmanager]]。
