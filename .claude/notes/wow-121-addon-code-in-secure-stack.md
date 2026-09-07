---
name: wow-121-addon-code-in-secure-stack
description: 自己的 Lua 跑在暴雪的 secure 堆疊裡、或在暴雪的框上寫了一個欄位，就會污染它——七個實測過的入口、延一幀／secure snippet／只讀不寫三種解法、探針怎麼做才不會假陰性
metadata: 
  node_type: memory
  type: reference
  originSessionId: a46e5c58-e427-4f26-b413-59eb1b1965fa
  modified: 2026-09-07T13:15:41.463Z
---

**指紋**：錯誤堆疊**整條都是暴雪的檔案**，一行插件程式都沒有，但訊息點名某支插件；
而那支插件看起來跟出事的系統毫無關係。三種訊息都是同一件事：

- `ADDON_ACTION_BLOCKED ... SetAttribute()`
- `Secret values are only allowed during untainted execution for this argument`
- `attempted to index a table that cannot be accessed while tainted`

**成因**：我們的 insecure 函式**在暴雪的 secure 呼叫堆疊裡面**被執行了。從那一刻起，
那條執行流程整條被染成我們的，**而且函式返回後還留著**——後面暴雪自己做的每一件事
都算在我們頭上。外層是迴圈的話更慘：染一次之後**同一輪剩下的每一個項目**都跟著壞，
包含別的插件的框。所以真正的污染點永遠不在堆疊裡。

## 三個已知入口（2026-08-30 在 MiliUI_UnitFrames 全部實測過）

**1. `RegisterUnitWatch` 驅動的 `Show()`**

```lua
-- Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua:83
local function SecureStateDriverManager_UpdateUnitWatch(frame, doState)
    if exists then
        frame:Show()                            -- ← 我們的 OnShow 在這裡同步跑
        frame:SetAttribute("statehidden", nil)  -- ← 下一行當場被封鎖
```

外層是 `for frame in pairs(unitExistsWatchers)`，所以會連累別的插件的單位框。
3 分半的樣本：60 次，`SetAttribute` 被擋 40 次。

**2. 按鍵的 secure 執行流程同步派送事件**

```
TARGETNEARESTENEMY:2     → TargetNearestEnemy()   ─┐
TURNORACTION:4           → TurnOrActionStop()     ─┼→ PLAYER_TARGET_CHANGED → 我們的 OnEvent
MULTIACTIONBAR4BUTTON9:2 → UseAction()            ─┘
```

也就是按 Tab 選目標、右鍵轉向點怪、按技能——最常按的三個動作。一分鐘 119 次，
`SetTexture` 被擋 62 次。**事件不一定是排隊派送的**，這是最容易忽略的一條。

**3. `AuraContainer` 的 `initializeFrame`**

跑在 `Blizzard_AuraContainerFrameProviders` 的 `CreateFrame`（`securecallfunction` 內）。
這條**不能延**——AuraButton 在初始化之後就 forbidden，樣式只能在那裡做。
見 [[wow-121-aura-containers]]。

**4. 8/30 漏掉的同類入口（2026-09-05 補）**

8/30 只把**全域 eventFrame** 延了一幀，這幾個一樣會在 secure 流程裡被同步呼叫的
入口沒動，症狀原封不動地回來：戰鬥中 `ActionButton3:SetAttribute()` 等五顆快捷列
按鈕同一秒被封鎖、記在 MiliUI_UnitFrames 頭上。

- 施法條自己的事件 frame（`Elements/Castbar.lua`）：player 框收
  `UNIT_SPELLCAST_FAILED`（UseAction 裡技能按不出去那一下**同步**派送）與
  `UNIT_TARGET`（按 Tab 的 TargetUnit 流程同步派送）——正好是入口 2 的那兩條按鍵。
- unit 範圍的事件 frame（`Core/Events.lua` 的 UnitReg）：`UNIT_TARGET`。
- 掛在 secure 單位框上的 HookScript：`OnAttributeChanged`（RegisterUnitWatch 的
  `SetAttribute("statehidden")` 會叫到）、Metro.Bind 的 OnShow/OnHide、
  光環 holder 的 OnShow。

全部改成 `ns.Defer(fn, ...)`（通用雙緩衝佇列，在 Core/Events.lua）。
**教訓：找入口要列「所有」會被暴雪呼叫的 script 與事件 frame，不是只看 OnEvent
主幹；`grep SetScript\|HookScript` 一次掃完。** 是否真的歸零待遊戲內驗證。

**5. 暴雪框上的欄位——一個都不能寫（2026-09-07 破案，追了九天的那條）**

不是「跑在堆疊裡」，是**寫了一個欄位、暴雪之後在自己的流程裡讀回去**。
MiliUI_InfoBar 把「尚未選用的天賦」那顆暴雪 HelpTip 的 `relativeRegion` 改成指向
自己的方塊；天賦視窗一開，`PlayerSpellsFrame:OnShow → EvaluateAlertVisibility` 收掉
那顆提示，`HelpTip.lua:408 OnHide → local relativeRegion = self.relativeRegion` 讀到
我們寫的值，**從那一行起整條開視窗的流程都是 InfoBar 的**：SetTab 的 SetShown 戰鬥中
被擋、ESC 關窗 `MultiActionBar_HideAllGrids` 把所有快捷列的格子收起來、每顆按鈕的
`.action`／輔助輸出旋轉框永久染髒、之後每個 tick `UpdateCooldown` 吃到秘密值就炸。
只在「有未用天賦點、提示正顯示」時發生 ⇒ 隨機。改錨、改 `info.targetPoint`、
`SetScript("OnUpdate", nil)`、呼叫 `HelpTip:Show/Hide/Acknowledge`（會寫它的 pool 與
FrameWatcher）通通算「寫」。

規則：**對暴雪的框只讀。** 要改外觀就自己畫一顆（讀 `info.text` 畫自己的泡泡）；
要讓它消失只能用純 C 端狀態（`SetAlpha(0)`、`EnableMouse(false)`——taint 不追蹤
widget 屬性），而且要在 `Release` 後置勾還原；要記「已看過」直接 `SetCVarBitfield`
（暴雪自己的 HandleAcknowledge 也是這行）。

**6. 自己動 UIParent 的錨點**

UIParent 一動，引擎**同步**發 OnSizeChanged → 編輯模式重排整個介面 → 每排快捷列
`UpdateShownButtons`／`UpdateAction`——整條瀑布跑在「呼叫 SetPoint 的人」的執行流程裡。
**延一幀沒用**（timer 回呼還是我們的碼）。只能從 secure 端動：`SecureHandlerExecute`
的 snippet 裡 `p:ClearAllPoints(); p:SetPoint("TOPLEFT", "$screen", ...)`（relframe 用
`"$screen"`；UIParent 不是保護框，snippet 只在脫戰放行）。

**7. secure 按鈕的點擊派送**

同一次點擊派送裡排在 secure OnClick **前面**的插件 Lua（`PreClick`、`OnMouseUp`）會把
secure 動作一起染髒；右鍵選單不能 `HookScript("OnClick")`，走
`SecureHandlerWrapScript` ＋ `control:CallMethod`；轉發到暴雪按鈕用
`*macrotext1 = "/click <名字>"`，不要 `*clickbutton1 = 框`（框參照型的屬性讀回來是髒的，
字串型引擎會複製成乾淨的值）。EUI 的做法是乾脆 `[combat] combat; nocombat` 把戰鬥中的
點擊拔掉、也完全不碰 HelpTip。

## 解法

**能延就延一幀。** `C_Timer.After(0, ...)` 把工作丟出那條堆疊，taint 就注不進去。
實測有效：入口 1、2 改完之後 60→0、119→0，被封鎖的動作 40/62→0。寫法：

- 用共用旗標 ＋ 單一 flush，不要每次都排一個 closure（換目標很頻繁）
- flush 前先把待辦收成陣列（或雙緩衝），跑的途中又有東西進來才不會蓋掉正在跑的
- **不要順手去重**：參數是 unit token 的事件（`UNIT_PET`、`PLAYER_FLAGS_CHANGED`）
  同一幀來兩次很可能是不同單位
- 參數整包留著（`n = select("#", ...)` ＋ `unpack`），不要只存 arg1——開放註冊的
  事件表哪天有人要第二個參數就會**靜默**壞掉

**不能延的**（入口 3）：把會踩雷的呼叫搬到外面先做好快取，callback 裡只查表；
整個 callback 再用 `xpcall` 隔離，錯誤逃出去會打斷暴雪**整批** frame 的建立。

## 診斷

**taintLog 對這一類是瞎的。** 它記的是「Execution tainted by X **while reading
variable Y**」——要有被寫髒的**變數**被讀到才留紀錄。執行層級的污染沒有變數參與，
所以不會出現。`taintLog 3`（記表格欄位存取）**只存在於測試版客戶端**，正式服最高 2。

真正有用的兩招：

1. **讀 taint.log 裡自己插件那些條目的堆疊「底部」**。底下是暴雪的 secure 函式
   （`SecureStateDriver`、`UseAction`、`TARGETNEARESTENEMY`、`securecallfunction`）
   就是一條管道；底下是自己的檔案就無害。這比看訊息本身有用得多。
2. `issecurevariable(t, k)` / `issecurevariable("全域名")` 逐一掃出事路徑上的欄位。
   **全部乾淨**就代表污染是執行層級的，別再往變數方向找。
   ⚠ 但要在 bug **發作之後**掃，而且要掃「每個 key」不是挑欄位——變數污染是永久的，
   發作前掃永遠乾淨（8/30、9/07 12:49 兩次都被這樣騙）。掃的範圍要含**插件可能寫過的
   暴雪框**（微型按鈕、HelpTip 現役框、快捷列本體、UIParent），不只出事的那條路徑。
   `_CDProbe` 的 `/cdprobe scan` 就是這個。
3. **`ADDON_ACTION_BLOCKED` 事件帶插件名字**——引擎自己點名，比 taintLog 好用。
   `!BugGrabber` 對這兩個事件是註解掉的（BugGrabber.lua:507），BugSack 裡永遠看不到，
   要自己 `RegisterEvent` 接。同一條路徑再往下走的封鎖（SetShown／SetAttribute）
   會替不寫名字的 SetCooldown 錯誤把名字補上。
4. **不要用 `seterrorhandler` 做探針**：`!BugGrabber` 把它換成空函式（BugGrabber.lua:527），
   接不到但也不報錯，計數永遠 0——跟「沒有錯誤」長得一模一樣，2026-09-07 整輪二分法
   因此全是假陰性。讀 `BugGrabber:GetDB()` 算 counter 差量；而且它的洗版保護
   （`BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE = 10`）會把每 tick 炸的風暴整批丟掉，
   要先把那個全域調高。
5. taint.log **在 /reload 時可能被客戶端重建**（19:00、21:04 兩次都清空了）。重現完
   不要 reload：等一分鐘讓它自己 flush，或登出到角色選擇畫面。

⚠ **BugSack 的錯誤是寫進 SavedVariables 跨場次留著的。** 做插件二分法的時候，
看到「某支根本沒載入的插件」被點名就是舊紀錄。測之前先 Clear，不然會追鬼——
2026-08-30 這樣白跑了三輪。

相關：[[wow-actionbar-taint-blame]]、[[wow-121-secret-values]]、[[project-miliui-unit-frame]]
