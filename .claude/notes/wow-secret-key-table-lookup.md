---
name: wow-secret-key-table-lookup
description: "How to fix \"attempted to index a table that cannot be indexed with secret keys\" in WoW addons"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-14T15:25:46.244Z
---

錯誤訊息 `attempted to index a table that cannot be indexed with secret keys` = 拿一個 secret 字串（通常是 `UnitClass()` 的 class token、`UnitName()` 的名字）去索引一個沒有開放 secret key 的 table。

注意：`t[x or "DEFAULT"]` **擋不住**這個錯誤 —— 對非 boolean 的 secret 做布林測試是合法的，所以 `x` 是 secret 時 `or` 不會 fallback，secret 還是被拿去當 key。

**保守寫法（確定可行，各 addon 目前都這樣做）**：查表前先 `issecretvalue()` 過濾，是 secret 就退回預設值。

```lua
local class = uf.cache.CLASS
if class == nil or issecretvalue(class) then class = "PRIEST" end
local c = classcolor[class] or classcolor.PRIEST
```

**可能的進階寫法（未實測，需上 PTR 驗證）**：把自己的查表 table 用
`settablesecurity(t, Enum.TableSecurityOption.SecretWrapContents)` 標記，讓 `t[secretKey]` 回傳 secret 值，再把 secret 直接餵給接受 secret 的 widget API。因為 r/g/b 要分開取，得拆成三張表
（`classR` / `classG` / `classB`）才能 `fs:SetTextColor(classR[c], classG[c], classB[c])`。
Enum 語意 wiki 沒寫，用之前先在 PTR 測。

Cell 的封裝值得抄（`Cell/Utils.lua` 約 2546 行起）：把 `issecretvalue` / `hasanysecretvalues` 統一包成 `F.IsValueNonSecret()`、`F.IsSecretValue()`、`F.HasAnySecretValues()`、`F.IsAuraNonSecret()`，並用 `C_Secrets.ShouldSpellAuraBeSecret()` 事先判斷某法術的 aura 會不會是 secret。原則是「全 addon 只有 Utils.lua 直接碰原生 secret API」。

**多回傳值陷阱（實際踩過）**：`SafeValue(select(2, UnitClass(unit)))` 這種寫法會爆。`select(2, UnitClass(unit))` 一次吐出 `classFilename, classID` 兩個值，當成 `SafeValue(v, default)` 的最後一個引數時 `default` 會吃到 `classID`。若 `classFilename` 是 secret，guard 觸發後回傳 `default`（= 也是 secret 的 classID），secret 照樣外洩去查表爆掉。修法：多包一層括號把回傳截成單值 —— `SafeValue((select(2, UnitClass(unit))))`。任何「把 secret 過濾函式的最後引數接多回傳 API」都要小心。

**全域閘不等於 per-aura 安全（2026-08-14 踩到）**：`C_Secrets.ShouldAurasBeSecret()` 只反映「現在是不是受限內容」。它回 false 時，**個別光環的欄位還是可能 secret** —— Cell 的 `_buffs_cache[auraInstanceID] = auraInfo` 就是在單人框架、非受限內容下炸的（`indexed assignment on a table that cannot be indexed with secret keys`）。

同樣要小心 `auraInstanceID` 本身：舊註解常寫「auraInstanceID is NOT secret」，12.1 已不成立。而且 `F.IsAuraNonSecret(auraInfo)` 只驗 `spellId`，**驗不到當 key 用的那個值**——凡是要拿某欄位當 table key，就對那個欄位本身做 `F.IsValueNonSecret()`，別靠整包光環的判斷。

讀取也算：`if cache[secretID] then` 這種「只是查有沒有」一樣是硬錯誤，所以 guard 要包在**整個迴圈本體**外面，不是只包寫入那行。Lua 沒有 continue，用 `if not F.IsValueNonSecret(id) then --[[skip]] elseif ... ` 這個形狀最省改動。

相關：[[wow-121-secret-values]]、[[wow-121-unit-api-secrets]]、[[project-cell-auracontainer-rewrite]]
