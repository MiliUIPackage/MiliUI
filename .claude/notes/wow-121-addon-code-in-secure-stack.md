---
name: wow-121-addon-code-in-secure-stack
description: 自己的 Lua 跑在暴雪的 secure 堆疊裡就會污染它——三個已知入口、延一幀的解法、taintLog 看不到這一類的原因
metadata: 
  node_type: memory
  type: reference
  originSessionId: a46e5c58-e427-4f26-b413-59eb1b1965fa
  modified: 2026-08-29T16:53:48.995Z
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

⚠ **BugSack 的錯誤是寫進 SavedVariables 跨場次留著的。** 做插件二分法的時候，
看到「某支根本沒載入的插件」被點名就是舊紀錄。測之前先 Clear，不然會追鬼——
2026-08-30 這樣白跑了三輪。

相關：[[wow-actionbar-taint-blame]]、[[wow-121-secret-values]]、[[project-miliui-unit-frame]]
