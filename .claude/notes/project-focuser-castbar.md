---
name: project-focuser-castbar
description: MiliUI 焦點目標施法監控（施法條/斷法巨集/唱法音效）的結構與維護要點
metadata: 
  node_type: memory
  type: project
  originSessionId: 9e4f9255-c588-4b9e-a948-ba9035e7faa2
---

焦點目標施法監控，2026-07 新增。**2026-08-22 已隨整組焦點功能拆成獨立插件**：程式在 [AddOns/MiliUI_Focus/Modules/CastBar.lua]，設定 UI 在 [AddOns/MiliUI_Focus/Options/Tab_Cast.lua]（MiliUI 套組裡的舊檔與「焦點目標」子分類已刪除，見 [[project-miliui-focus-addon]]）。

**架構**：不依賴 Platynator/BloodlustMusic。對外只有插件內部的 `ns.CastBar.*`（舊的全域 `MiliUI_FocusCast` 已不存在）。設定存 `MiliUI_Focus_DB.cast`（舊的 `MiliUI_DB.focusCast` 只在首次遷移時讀一次）。

**12.0 Secrets（極重要，踩過雷）**：Midnight 有 `C_Secrets.HasSecretRestrictions()`。生效時敵方施法的**起訖時間(cast[4]/[5])、notInterruptible(cast[8]/channel[7])、name(cast[1])、texture(cast[3])** 都是秘密值；連**玩家自己斷法冷卻** `C_Spell.GetSpellCooldownDuration(id):IsZero()` 也是秘密布林。

Lua 對秘密值的規則（實測歸納）：
- 秘密**字串/數字**：truthiness/`==nil`/`~=nil`/`or` **可以**（只洩漏 nil-ness，可知）。所以 `if name`、`texture or X`、`castTbl[1] ~= nil` 都 OK。
- 秘密**布林**：任何 `if <secret bool>` / `and/or` / `not` 都會 **taint**（布林值本身就是機密）。`notInterruptible`、`d:IsZero()` 絕不能測。

繞法（抄 Platynator）：
1. 進度：用 `UnitCastingDuration/UnitChannelDuration/UnitEmpoweredChannelDuration` 拿 duration 物件，餵 `StatusBar:SetTimerDuration(dur,nil,Enum.StatusBarTimerDirection.Elapsed/RemainingTime)` 讓引擎驅動。**`dur:GetTotalDuration()` 也可能回秘密數字**（2026-07-11 實戰：castTotal 比較炸 1408 次），存入明文變數前必須 `issecretvalue(total)` 檢查，秘密就退回 0（不顯示數字；保險收條改在 ticker 輪詢 `UnitCastingInfo/UnitChannelInfo == nil`，不猜固定秒數）。elapsed 一律秘密。
2. 顏色（三態）：不可分支，改用 `C_CurveUtil.EvaluateColorValueFromBoolean(secretBool, valTrue, valFalse)` 把秘密布林餵進去選色，再 `GetStatusBarTexture():SetVertexColor(r,g,b)`。斷法冷卻會變 → 0.1s ticker 重算。
3. 偵測是否施法：`UnitCastingInfo("focus") ~= nil`。挑欄位用明文 isCast 旗標分支（值可為秘密，賦值不分支）。
4. 數字時間文字：秘密模式 elapsed 不可讀，用本地近似計時(`GetTime()-castLocalStart`)補。

`SecretsActive()` 每次施法判斷走秘密/一般路徑（一般路徑才可 Lua 判斷、才有 ComputeState/InterruptReady）。

**依斷法狀態播不同音效在 Secrets 下無解**：挑音效必然要對秘密布林分支（正是暴雪封殺的自動斷法）。音效功能只在非秘密模式可用，秘密模式 `HandleSound` 直接 return。

**中文字體**：FontString 不能寫死 `FRIZQT__.TTF`（無中文字形→方框），要用本地化字型（抄 BloodlustMusic：zhTW=blei00d.TTF/zhCN=ARKai_T.ttf/koKR=2002.TTF）。

**打斷顯示斷法者**（抄 Platynator）：Midnight 的 `UNIT_SPELLCAST_INTERRUPTED`/`CHANNEL_STOP` 事件 payload 第 4 參數、`EMPOWER_STOP` 第 5 參數帶 interrupterGUID（通道/蓄力只有被打斷才帶）。GUID→名字用 `UnitNameFromGUID` + `GetPlayerInfoByGUID` 拿職業→`C_ClassColor.GetClassColor`。凍結條用 `SetMinMaxValues(0,1)+SetValue(1)` 可蓋掉 SetTimerDuration（Platynator ApplyInterrupt 同法）。停留用 displayToken 世代計數防過期計時器誤收新施法。Platynator 停留預設 0.3s（名條有常駐名字），獨立條用 1.0s。

**執行架構（效能）**：閒置零成本（條隱藏→無 OnUpdate、事件 focus-only）。秘密模式**不掛每幀 OnUpdate**，改用單一 0.1s `displayTicker`（文字+顏色一起）；一般模式施法時才掛 `LegacyOnUpdate`（每幀 SetValue 平滑填充）。START 只讀一次 cast/chan table 傳給 HandleSound+StartDisplay；DELAYED 走輕量 `ResyncTiming`（只重設引擎計時，不重讀圖示/名稱/位置，castLocalStart 不動避免文字跳）。位置/大小只在建立與編輯模式套用，不在每次施法。OnUpdate/ticker 都成對掛卸（HideBar、StartDisplay、編輯模式進入）。

**斷法判斷抄自 Platynator**（Display/Utilities.lua 的 interruptMap + Display/Colors.lua）：`notInterruptible`→immune；否則逐一檢查已學斷法法術 `C_Spell.GetSpellCooldownDuration:IsZero()`（fallback `GetSpellCooldown().startTime==0`）→ready/cd。三態顏色預設抄 [AddOns/MiliUI/Config/Luxthos_Platynator.lua] autoColors：ready 金(1,0.741,0)、cd 橘(0.906,0.424,0.2)、immune 灰(0.529 灰階)。

**每季/改版維護**：
- `interruptMap`（各職業斷法 spellID）要跟 Platynator/Display/Utilities.lua 同步（新職業/改法術時）。
- UnitCastingInfo notInterruptible 在第 8 個回傳、UnitChannelInfo 在第 7 個。

**編輯模式拖曳**：抄 BloodlustMusic 三層 hook + EditModeSystemSelectionTemplate，作法已寫成 skill [[wow-editmode-draggable]]。名稱走語系檔 `L["Focus cast bar"]`（zhTW「焦點目標施法條」），監控關閉時編輯模式不顯示。預設座標 x=0,y=260（刻意放 BLM 倒數條 y=300 下方，硬編碼不耦合）。

**唱法音效**：獨立於監控開關，三態各別啟用，SoundKit 數字或 LSM 字串（MiliUI 沒內建 LSM，用 `LibStub("LibSharedMedia-3.0", true)` 可選抓取）。

**斷法巨集**：設定頁內唯讀 EditBox + 「全選」按鈕（HighlightText 讓使用者 Ctrl+C）。範本 `#showtooltip\n/cast [@focus,exists][@target] 法術名稱`，會用 `GetInterruptSpellName()` 自動填入玩家斷法技能名。
