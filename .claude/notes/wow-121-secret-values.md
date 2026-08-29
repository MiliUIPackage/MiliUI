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

**暴雪自己的光環按鈕（BuffFrame / DebuffFrame 的 AuraContainer 子按鈕）也是這個狀態。**
`btn.Icon:GetSize()` 回的是秘密數字，拿去比大小就是
`attempt to compare local 'iw' (a secret number value, while execution tainted by '<你的插件>')`，
`GetPoint()` 同理。**掛在光環按鈕上做事的插件，一律只傳不讀**：位置與尺寸自己用常數
（樣板的圖示就是 30x30，縮放走 `SetScale`，當它的子框就會跟著縮），
`Icon:GetTexture()` 這種「拿到就直接餵給 `SetTexture`」是允許的（傳遞者不是讀取者）。
2026-08-26 在 [[project-miliui-auraenhance]] 撞到，見那份的包裝框那節。

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

## 分支搬進引擎：一個區間一條曲線（2026-08-24，Cell 血量門檻）

想要「在 N 個區間裡挑一個顯示」但判斷值是秘密的（血量百分比）：**不要挑，全部畫出來，
再用曲線關掉不該亮的**。

- 每個區間一個貼圖，位置/顏色是靜態的（門檻百分比 × 血條寬），啟動時就擺好；
- 每個貼圖配一條曲線：區間內 = 1、區間外 = 0（用 `AddPoint(下界-eps, 0)` /
  `AddPoint(下界, 1)` 做出方波）；
- 每次更新 `tex:SetAlpha(calc:EvaluateCurrentHealthPercent(該區間的曲線))`。
  alpha 吃秘密值，所以引擎自己挑，Lua 從頭到尾沒有比較過任何東西。

⚠ **區間不是「小於某條線」**：Cell 舊邏輯是「第一條**高於**目前血量的門檻」，
所以門檻 i 的區間是 `[t(i-1), t(i))`，t(0)=0。做成獨立的「血量 < t(i)」會讓
目前血量以上的門檻全部同時亮。

⚠ **血條寬度要進快取簽章**：版面還沒定位時 `GetWidth()` 是 0，用簽章快取住那一刻
等於把所有線釘在 offset 0，之後永遠不會重建。

實作在 `Cell/Indicators/Built-in.lua` 的 `CheckThresholdMidnight`
（同檔的 `CELL_FADE_OUT_HEALTH_PERCENT` 是同一招的單門檻版）。

## 秘密幾何噴在排版上：訊息指的是 FrameUtil，不是 LayoutFrame

秘密面向會**沿著錨點往下傳染**：插進 `GameTooltip` 的那些行（`GameTooltip_InsertFrame`）
錨在已經有秘密面向的 tooltip 上，`GetRect()` / `GetScaledRect()` 就跟著回秘密數字，
接著暴雪自己的排版做除法直接拋錯。實例：滑過團隊戰利品紀錄的條目
（`LootHistoryElementMixin:OnEnter` → `SetTooltip` → `Layout`）。

兩個要記住的細節：

- **拋出點是 `Blizzard_SharedXMLBase/FrameUtil.lua` 的 `GetUnscaledFrameRect()`**
  （`frameLeft / scale`），`LayoutFrame.lua` 只出現在堆疊上。錯誤處理器如果比對
  訊息字串，只寫 `LayoutFrame.lua` 會整批漏接 —— `MiliUI/Fix/TooltipTaintFix.lua`
  的過濾器 2026-08-27 因此補上 `FrameUtil.lua`。
- 污染來源印成 `*** ForceTaint_Strong ***` 表示是**引擎自己 forceinsecure**，
  不是某個插件。整條路徑都是暴雪程式碼時，插件端沒有東西可修，只能過濾錯誤 ——
  而且**不要去替換 `GetUnscaledFrameRect` 這種泛用函式**，那會讓所有 `Layout()`
  都變成被污染的執行，換來更大的災難。

## 材質值也是秘密值，而且失效是**靜默的畫錯**（2026-08-28，光環圖示變紅問號）

秘密值的討論多半集中在數字（血量、秒數、層數），但**貼圖的 fileID 一樣會是秘密值**。
光環受限時暴雪往 `Icon:SetTexture(buttonInfo.texture)` 餵的就是秘密值。

危險的地方在於它**不拋錯**。算術／比較會當場炸，材質不會——你只是畫不出來，
停在那張貼圖原本的樣子。玩家 `scriptErrors` 預設關閉，所以什麼都不會浮上來。

**指紋：同一顆按鈕上「暴雪自己畫的部分正常、我們畫的部分錯」。**
（那次是倒數秒數正常、圖示全變紅問號 —— 紅問號是 `AuraButtonTemplate` 的
樣板預設材質 `INV_Misc_QuestionMark`，也就是「從來沒被成功指派過」的樣子。）

⚠ **「鏡射」這個模式在 12.1 整類失效。** `hooksecurefunc(區域, "SetTexture", 轉發)`
＋ 藏掉原本那個，是插件界很常見的手法（要換父層、要交給樣式引擎、要改繪製層都會用）。
只要來源值可能是秘密的，這個模式就沒有安全版本 —— 污染端既讀不出也餵不進。

正解是**交出原件，不要複製**：把暴雪那個區域本人交給下游（樣式引擎／容器），
自己只做 `SetParent` / `SetPoint` / `SetSize` 這類 setter。轉手可以（見上面
「當傳遞者，不當讀取者」），但那條的前提是**你手上真的接得到那個值**；
材質這裡連接都接不到，所以連轉手都不成立。

⚠ **不能拿暴雪的原始碼當「我們也可以這樣寫」的依據。** 同一版 `BuffFrame.lua` 裡
就有 `buttonInfo.count > 1` ——安全端讀秘密值完全合法，污染端照抄會炸。
**光看原始碼分辨不出來**，要去
`Blizzard_APIDocumentationGenerated/` 查那支 API 的 `SecretArguments`。

同理，引進任何 12.1 之前寫成的實作（哪怕它「跑了很多年零錯誤」）都要單獨問一次
「它碰不碰秘密值」。那份零錯誤是在結構上產生不出這個 bug 的環境裡累積的，
不構成證據。實例見 MiliUI_AuraEnhance 的 `Modules/Skin.lua`。

## 12.1 廢掉了「不碰保護框就安全」這條線（2026-08-28，實測 336 連環炸）

12.0 以前寫暴雪欄位的風險評估是「下游有沒有保護動作」——沒有就頂多視覺出錯。
12.1 不是這樣：**秘密值讓「執行污染」本身變成炸點**。安全端讀秘密值合法、
帶污染的執行讀秘密值直接拋錯，而暴雪的程式**到處都在讀秘密值**（血量、光環、
座標……），所以污染流到哪、哪裡就炸，跟保護框毫無關係。

實測案例（MiliUI_AuraEnhance 的圖示間隔，當天撤掉）：寫 `AuraContainer.iconPadding`
（明碼數字！）→ 暴雪排版讀它、該次執行帶污染 → 排版尾端 `UpdateSize` 把污染寫進
編輯模式管理層的**共用狀態** → 團隊框架在同一片狀態下更新 →
`CompactUnitFrame.lua attempt to compare local 'health' (a secret number value,
while execution tainted by 'MiliUI_AuraEnhance')`。錯誤指向的檔案跟我們動的
東西**隔了兩個系統**，錯誤數量是「每次血量更新一發」。

判準更新：
- **暴雪會讀的欄位一個都不能寫**，值是明碼也一樣——污染跟著值走，不跟內容走。
- 評估寫入點時問的不是「這條路有沒有保護框」，是「這條執行流最終會不會碰到
  任何秘密值的讀取」——而 12.1 的答案幾乎永遠是會。
- 症狀指紋：錯誤發生在**跟你完全無關的暴雪檔案**裡、掛著你的插件名、
  數量隨某種更新頻率暴增。看到這種就往「我寫了什麼暴雪會讀的東西」查，
  不要去查錯誤指向的那支檔案。
- 純 C 端 setter（SetPoint／SetAlpha／SetColorTexture／SetTexCoord…對**自己建的**
  區塊）仍然安全——它們不產生暴雪 Lua 會回讀的髒值。
