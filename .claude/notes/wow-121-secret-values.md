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

## ⚠ 計算器 getter 的多回傳值：一定要先落地

`UnitHealPredictionCalculator` 的 getter 不少是**回兩個值**的(`GetDamageAbsorbs` →
量, isClamped;`GetHealAbsorbs` 同樣)。Lua 在「最後一個參數位置」會把多回傳值**全部展開**,
所以:

```lua
bar:SetValue(calc:GetHealAbsorbs())     -- ⚠ 實際上是 SetValue(量, isClamped)
```

而 `StatusBar:SetValue` 的第二個參數在 12.x 是**插值模式**——等於餵了一個秘密布林進去,
結果是整條被鋪滿。症狀看起來像「API 回垃圾值」,其實是自己寫的展開。

**規則:計算器的值一律先 `local x = calc:GetXxx()` 再用**(Cell 每個取值點都這樣寫)。
這條在秘密值下特別難抓,因為印出來永遠是 `<secret number>`,對不出大小。

**追秘密值的正確工具**:秘密值**畫得出來、讀不進來**——`SetFormattedText` 是 C 端函式吃得下
秘密值,把數字寫進 FontString 顯示在畫面上就看得到實際大小(`/muf secret` 就是這樣做的)。
`tostring`/比較/算術一律不行。

## 秘密值下的通則：**當傳遞者，不當讀取者**

拿到一個秘密的「身分」（spellID、auraInstanceID…）不代表功能就做不了。很多時候
**根本不需要知道它是什麼** —— 原封不動交回給另一支 C 端函式，查表由暴雪那邊做。

實例：施法條的「重要法術」染色。

```lua
local spellID = UnitCastingInfo(unit)[9]     -- 可能是秘密值
if spellID == nil then return end            -- 只比 nil，不讀值
local isImportant = C_Spell.IsSpellImportant(spellID)   -- 轉交，不讀
Eval(isImportant, 重要色, 原色)               -- 回來還是秘密布林，照舊只餵曲線
```

Platynator 的 `Display/Colors.lua` 就是這樣做的，而且**它沒有維護任何法術清單** ——
判定完全是暴雪的 `C_Spell.IsSpellImportant`。看到「別的插件做得到，那它一定有一張表」
先別下結論，多半是有一支對應的 C API。

⚠ 這條的界線在 [[wow-121-duration-objects]]：圖騰槽做不到，是因為**沒有**一支
「吃 secret spellID 回你要的東西」的 API，不是因為身分是秘密。差別在有沒有那支 API。

## 曲線可以**串接**

`C_CurveUtil.EvaluateColorValueFromBoolean` 的回傳（秘密數字）可以直接當**下一次**
呼叫的參數，一層層疊上去做優先序。Platynator 的 `SplitEvaluate` + `colorQueue`
整套就是這樣跑的（逐色道各跑一次，前一輪結果當下一輪的 whenFalse），已上線驗證。

所以「不可打斷 > 斷法就緒 > 重要法術 > 一般」這種多層優先序在秘密值下做得出來，
不必退化成只顯示一種狀態。

## 上色一律走貼圖的 `SetVertexColor`，不要用 `SetStatusBarColor`

只要顏色分量**可能是秘密數字**（最常見的來源：`C_ClassColor.GetClassColor(secretClassFile)`，
或 `EvaluateColorValueFromBoolean` 算出來的結果），就不能指望 `StatusBar:SetStatusBarColor`
吃得下 —— 它沒有保證。

```lua
bar:GetStatusBarTexture():SetVertexColor(r, g, b, a)   -- 貼圖層的 setter，吃得下秘密分量
```

MiliUI_UnitFrames 的血條、能量條、預估條一開始就是這樣寫的；2026-08-18 施法條加「職業色
填充」時，因為職業色可能是秘密分量，也一併收斂成同一支 `SetBarColor`。
明文全域色（打斷紅、淡出色）留用原本的 setter 沒差，但統一走一支比較不會忘。
