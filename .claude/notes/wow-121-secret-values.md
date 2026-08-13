---
name: wow-121-secret-values
description: "WoW 12.x Secret Values rules — what tainted addon code may/may not do with secrets, plus 12.1's new table-security APIs"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f1b7b639-5461-453c-bd27-5aa2c80bde5f
  modified: 2026-08-09T17:44:06.146Z
---

Warcraft Wiki: https://warcraft.wiki.gg/wiki/Secret_Values

Secret values landed in 12.0.0; 12.1.0 (TOC 120100) widens them a lot. Rules for tainted (addon) code:

- **允許**：把 secret 存進變數/upvalue/table 的 *value*、傳給 Lua function、字串串接、`string.format` / `string.join` / `string.concat`、對「非 boolean 型別」的 secret 做布林測試（所以 `x or "DEFAULT"` 是安全的）、`type(secret)` 回傳真實型別。
- **禁止（立即 Lua error）**：算術、比較（`==`, `<`）、對 boolean secret 做布林測試、`#`、用 secret 當 table **key**、對 secret 做 index 讀寫、把 secret 當 function 呼叫。

偵測用 API：`issecretvalue(v)`、`canaccessvalue(v)`、`issecrettable(t)`、`canaccesstable(t)`、`hasanysecretvalues(...)`。

Table 相關（12.1）：
- 新增 `settablesecurity(table, Enum.TableSecurityOption)`，取代 12.0 的 `SetTableSecurityOption`（已移除）。Enum：`0 DisallowTaintedAccess` / `1 DisallowSecretKeys` / `2 SecretWrapContents`（wiki 沒寫說明，語意需上 PTR 實測）。
- 新增 `securecopy(value [, options])`：深拷貝，保留遞迴/共用參照，script object 以參照保留，拷貝結果帶當前執行的 taint。
- untainted 程式把 secret 當 key 存進 table，那個 table 會被**永久**標記為 tainted 不可存取。

顯示 secret 而不讀取它的官方管道：`C_CurveUtil.CreateCurve()` / `CreateColorCurve()`、`C_DurationUtil.CreateDuration()` + `StatusBar:SetTimerDuration()`、直接把 secret 丟給 `StatusBar:SetValue()` 這類接受 secret 的 widget API。

Secret aspects：把 secret 丟給 widget API 會在該物件上留下 aspect（例如 `FontString:SetText(secret)` → `Text` aspect → 之後 `GetText()` 也回 secret）。只能用 `FrameScriptObject:SetToDefaults()` 清除，用 `HasSecretAspect()` / `HasSecretValues()` / `IsAnchoringSecret()` 檢測。

**踩過的坑：`StatusBar:SetValue(secret)` 會污染整個 frame 的幾何資料。** 它「接受 secret 但沒有對應的 aspect」，所以不是只標記某個面向，而是把**整個物件**標成 has-secret-values → 之後 `GetWidth()` / `GetHeight()` / 錨點資料全部回 secret，而且會往下傳染給錨在它身上的子區域，只有 `SetToDefaults()` 能清。

所以「把 secret 直接餵給 widget」這招只有在**該 frame 的版面完全不回讀幾何**時才成立。Coolinator 能這樣做是因為它的尺寸全部來自自己的設定（`PixelUtil.SetSize(bar, sizing.statusWidth * scale, ...)`）；Ayije_CDM 的資源條在 `SetValue` 之後緊接著 `RefreshBarTicks()` → `bar:GetWidth()` 做刻度算術，套用同一招會換來一個更難查、而且會沾黏的崩潰。評估任何 pass-through 之前先 grep 那個 frame 有沒有 `GetWidth`/`GetHeight`/`GetPoint`。

**`debugstack()` / `debuglocals()` 也會回 secret string**：只要呼叫堆疊上有秘密值參與就是（`debuglocals` 的輸出裡個別的值反而是被塗成 `<secret string>` 的明碼）。所以任何錯誤處理／回報插件對 stack、locals 做 `:gsub()`、`:find()`、`:sub()` 之前都要 `issecretvalue` 檢查——BugSack 就是這樣整個視窗打不開的，見 [[project-121-addon-migration]]。

相關：[[wow-121-unit-api-secrets]]、[[wow-secret-key-table-lookup]]、[[wow-121-aura-containers]]
