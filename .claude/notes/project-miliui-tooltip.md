---
name: project-miliui-tooltip
description: MiliUI_Tooltip — 取代 TinyTooltip 的自製滑鼠提示重寫版：taint 接觸面清單、架構決策、接管名單（含 FriendsTooltip 與 MiliUITip_API.Adopt）、v1 刻意捨棄的功能、戰鬥中秘密值與 Leatrix 殘留兩次破案的規則
metadata: 
  node_type: memory
  type: project
  originSessionId: 629d19ba-309f-41f7-aa47-258c1bee5d39
  modified: 2026-10-18T10:12:30.534Z
---

**MiliUI_Tooltip**（2026-08-22 一次寫完，`c01f3fde0`）：取代 `TinyTooltip-Remake` 的全新滑鼠提示插件，只支援 12.1+。
`AddOns/MiliUI_Tooltip/`，SV `MiliUI_Tooltip_DB`，namespace `_G.MiliUITip`，指令 `/mtip`（`reset`／`debug`／`log`／`logdump`）。
已發佈多版、玩家回報兩輪破案（見下），寫完當下列的八項「待遊戲內驗證」已不再有意義——沒有針對性回饋的只剩比價風暴下的實測 CPU 與 forbidden 情境（UIWidget 光環行）。

**Taint 圍堵設計**（核心賣點，接觸面清單維護在 `Core/Hooks.lua` 檔頭，要碰暴雪物件的新程式碼必須先過那張表）：
- 裝飾全在自己的 skin frame（tip 的 child、frameLevel = tip−1、SetAllPoints）：背景 1 貼圖＋邊框 4 貼圖＋漸層 mask＋大陣營圖＋血條＋3D 模型全掛這上面。
  **純貼圖零 SetBackdrop** ⇒ 沒有跟暴雪 SetBackdropStyle 的攻防戰（TinyTooltip ~195ms 效能地板的根源直接消失）；上色一律 SetVertexColor（吃秘密分量）。
- 暴雪物件上**零欄位寫入**：per-tip 狀態在 `Skin.State[tip]`（frame 當 key）。
- 入口只有 TooltipDataProcessor post-call（Unit/Item/Spell/UnitAura/Macro）＋ hooksecurefunc（SetDefaultAnchor、AddInstructionLine、SetAction/SetMacro、
  ItemRefTooltip.SetHyperlink、InspectUnit）＋ HookScript(OnTooltipCleared)。不換函式、不 SetScript 暴雪物件；每個入口先 `IsForbidden()` 閘，失敗方向＝該次顯示原味樣式。
- **不碰 EmbeddedItemTooltip**（UIWidget 會借走變 forbidden 的大宗）。接管清單 `TRACKED`：GameTooltip、ShoppingTooltip1/2、ItemRefTooltip、ItemRefShoppingTooltip1/2、NamePlateTooltip、
  **FriendsTooltip**（2026-09-26；它不是 GameTooltip，是繼承 TooltipBackdropTemplate 的普通 Frame，只換外觀、內容不經過 post-call）。
- **`MiliUITip_API.Adopt(tip)`**（`Api.lua`，2026-09-21）：給套組裡其他插件自建的 tooltip「交給我接管」套同一套提示皮（[[project-miliui-hud-skin]]）。
  只有提示插件 ⇒ 沒人叫 Adopt、那些框維持暴雪原樣；只有外觀插件 ⇒ API 不存在、MiliUI_Skin 退回自己畫一層（[[project-miliui-skin]]「特例二」）。
- 一次性視覺中和：`NineSlice:SetAlpha(0)`（skin OnShow 重申）、`GameTooltipStatusBar:SetAlpha(0)`（載入時壓一次不夠，單位提示流程會弄回來 → `Bar.Activate` 每次重申）。
- 血條／模型層級要明寫 tip+1（skin 是 tip−1，child 放著會被 tooltip 背景蓋掉文字半截）。血條是自己的：`UnitHealthPercent(unit, true, ScaleTo100)` → SetValue(秘密)。
- **post-call 時序紅利**：行加在暴雪排版之前 ⇒ 不需要自我 Show()，比價重建風暴只剩重上色。Show() 只在 ProcessInfo 之外（目標行輪詢、非同步觀察刷新）呼叫。
- 輪詢走 `Skin.Poll`（`ns.Metro.New(0.05, ns.ReportError)`，共用層）並掛在「有沒有 tooltip 顯示中」上——沒有提示的時候 ticker 根本不存在。
  可見度判斷用**自己的 skin frame 的 OnShow/OnHide**（父層一藏子層就跟著發，零接觸面）。`Core/Secret.lua` 已刪，`ns.Secret` 由共用層提供（[[project-miliui-widgets-vendor]]）。

**設定介面**：MiliUIWidgets vendor，Panel 1000×520、左欄 340 固定放**即時預覽**、右欄捲動；分頁：樣式／玩家／NPC／物品與法術／錨點／設定檔（`fullWidth`，無預覽）／關於。
預覽＝自建 `CreateFrame("GameTooltip","MiliUITip_Preview",…,"GameTooltipTemplate")` 走 ns.TrackTip 進同一條管線（玩家預覽 SetUnit("player")、物品預覽 SetItemByID(19019)，NPC 預覽餵假 raw）；
設定改動 → ns.ApplyAll → Fire("SettingsApplied") → 重繪。顯示元素是**可拖曳方塊看板**（Tab_Unit.lua：列內排序／跨列搬移／拖到「不顯示」隱藏／點一下快速開關；列版面直接寫回 DB elements，DB 端 EnsureElementRows 健檢）。
法術的「按住修飾鍵顯示全部」要靠 MODIFIER_STATE_CHANGED 監聽補行＋Show——法術提示不像物品會被比價系統一直重建。
**成就點數不是秘密值**（先過 PlainNumber），colorfunc "achievement" 設為預設。**遷移鏈整個拔掉**（`DB_VERSION = 1`、`PROFILE_MIGRATIONS = {}`），預設值變動要使用者 `/mtip reset` 才吃到。
描邊 2026-10-03 起全套組統一五選一。

**v1 刻意捨棄**（要加回去時知道去哪找）：elements 的顏色/wildcard/filter 編輯 UI（DB 有、UI 只給 enable+icon 開關）、per-unit 錨點 UI（DB 有 inherit 結構、UI 只出全域）、
skinMoreFrames 大清單、BattlePetTooltip、LSM border、SavedVariablesPerCharacter、announcement、QuickFocus（使用者不要）、AutoSetTooltipWidth（賭 post-call 時序下引擎自己會量，實測沒出問題）。
設定介面說明不提 TinyTooltip（關於頁致謝除外，原作者 55510696）。

**切換**：TinyTooltip-Remake 整包從套組移除，`MiliUI/Enhance/LegacyAddons.lua` 的 REPLACED 加了 TinyTooltip-Remake → MiliUI_Tooltip（自動停用玩家殘留資料夾）。
**從套組移除插件時要同步列進 LegacyAddons**，不然解壓縮覆蓋的玩家永遠留著（Leatrix_Plus 與 MBB 就是漏列，2026-09-15 補上）。

## 戰鬥中敵方顯示成上一個友方（2026-08-23 log 破案，兩層）

① `tip:Show()` 會讓 tooltip **重新處理「儲存的上一份內容」**——目標行輪詢的 Show 把舊的 `unit="target"` 內容翻回來、重跑又把 `isUnitTip` 設回 true ⇒ 自我延續的舊資料迴圈。
規則：**任何會 Show 的輪詢都要先確認「目前內容是自己要更新的那個 token」**（`SafeValue(state.unit)=="mouseover"` 明文比對）。
② 世界游標的秘密 token 連 `UnitExists` 都回**秘密布林**（不能 truth-test）⇒ SafeBool 當 false 早退，敵方整個套不到文法。**存在性判斷要 fail-open**：只有明文 false 才退、秘密照畫。
診斷靠 `/mtip log`／`/mtip logdump`（Init.lua 的 ns.Log 記錄器，秘密值只標型別）。

**戰鬥中光環顯示法術 ID**：12.1 光環 tooltip 資料**不帶 `args`**（TinyTooltip 讀 `args[2].intVal` 是舊制）、`lines[1].tooltipID` 也是 nil，**spellId 在 `tooltipData.id`，戰鬥中是秘密數字**。
顯示走 format 傳遞（不可 tostring）；要明文的（坐騎查表、圖示 ID 解析）下游各自把關。`UnitInfo.JoinRow` 不可用 `table.concat`（秘密字串進去整列回 ""），已改逐段 format。

## 玩家回報「職業欄有時候不見」（2026-09-08～15，玩家 log 破案）

**成因在玩家端：殘留的 Leatrix_Plus（「Manage tooltip」）在我們寫完之後按固定行號就地覆寫第 1–3 行。** 本機重現不了。
現場指紋（`/mtip log` 的 pre/post 行掃描）：每行尾巴的 `|cffffffff|r` 是它的簽名；目標行有兩條——`選取目標: [名字]` 是**我們的**（暴雪 zhTW 的 `TARGET` 全域就是「選取目標」），`目標: 名字` 是 Leatrix 的。
⚠ 別把「選取目標」當成外來插件的指紋，一開始就判反過。第一輪 post 之後 0.06–0.15s 就被改、中間沒有 OnUnit/Apply（暴雪 ProcessInfo 一定先 ClearLines 再觸發 post-call，所以不是暴雪重建）；
只有觀察／成就資料到貨的 relayout 會把我們的行寫回去 ⇒ **快取過的玩家永遠壞**（玩家描述的「只出現一次」）。

**順帶修掉的自家 bug**：relayout 時行已經是自己寫的，`GetOriginalSpecLine` 找「含職業名的最短一行」會抓到自己的職業列 ⇒ 整列塞回職業欄、畫面重複一次。
規則：**relayout 不可從 FontString 文字推斷任何東西**，只吃第一輪（post-call）存下的快取。

**被否證的假設**：secret aspect（`SetText(秘密)` 讓行的 GetText 永久回秘密）——玩家 log 全行 `aspect=false`，脫戰同陣營時 name/class/guid 全明文。`HasSecretAspect("Text")`／`HasSecretValues()` 在 FontString 上回明文布林，探針可用。

## 重繪面板（2026-10-18，`Panel/`，commit 289a46807；plan `~/.claude/plans/miliui-tooltip-panel.md`）

**物品／法術／配方三型改走「重繪面板」，單位／光環／巨集維持就地改寫一行未動。** 參考對象是 WoW Forever 的 PrettyTooltip（MIT，本機 `Interface/tmp/PrettyTooltip/`）：
它鎖 enUS、資料表全是永恆版所以不能直接用，但它是照 12.x 引擎寫的、排版骨架可搬；法術係數／DPM／分解／剝皮那些是客戶端資料表硬編，正式服沒 API，**不搬**。

- **做法**：原生 tooltip 留著當替身——`SetAlpha(0)`、`SetPadding(right, bottom, left, top)` 撐到跟 panel 一樣大（暴雪的比價定位、夾邊、游標跟隨全照原生框算，一行定位都不用重寫），
  旁邊畫自有 panel（parent UIParent、strata 讀 tip 的、level = tip+5 並在輪詢裡跟著抬——ItemRefTooltip 是 toplevel，點了會抬層，不跟的話 alpha 0 的原生框會吃掉 panel 上 × 的點擊）。
  接觸面 #10（SetAlpha／SetPadding）、#11（`ItemRefCloseButton:Click()`）；**P0～P3 零 hooksecurefunc**，尺寸貼合走 `C_Timer.After(0)`＋`Skin.Poll` 0.1 秒。
- **退路＝退回現有樣式**：任何一行文字／型別／顏色／lineIndex 是秘密、GetPoint／GetLeft／GetWidth／GetPadding 回秘密、讀不出名字、render 出錯、內嵌物品框或 BottomFontString 顯示中（暴雪自己在用 padding）
  → 不藏原生、不顯示 panel。開關關掉時對 tooltip 零寫入。
- **OnTooltipCleared 先不拆（Release）、下一幀沒被新 post-call 認領才 Restore**；skin OnHide 立刻 Restore。不然比價風暴「清空再填同一件」每秒拆重畫二十幾次，指紋白做。
  padding 只在「tooltip 還顯示、而且還是我們設的值」才寫回（`GameTooltip_OnHide` 第 419 行自己 `ClearPadding`、OnShow 走 CalculatePadding 沒內嵌框也清——wow-ui-source live 核過）。
- **先比指紋再解析**：指紋＝CollectLines 的原始行（文字＋顏色＋price）＋設定版本＋行數；相同連 reader 都不跑。
- **像素基準用 panel 自己的有效縮放**（panel 跟著 `general.scale` SetScale，拿 UIParent 基準整組偏）。量測與排版只讀自己記的 width／height，不讀 `panel:GetWidth()`（錨在 tooltip 上會沿鏈染到秘密幾何）。
- **語系 pattern 全部從 `_G` 的 GlobalStrings 反轉產生**（`Panel/Patterns.lua`），不寫任何語言字面；12.1.5 的 `TooltipDataLineType` 很多行有型別（ItemName／ItemBinding／EquipSlot／ItemLevel／FlavorText／ItemSpellTriggerOnUse…／SpellName／SpellPassive／SpellDescription／UsageRequirement／NestedBlock），
  **能用型別就用型別**，文字只留耗能（`_G` 掃 `*_COST`／`_COST_PER_TIME`／`_COST_LARGE`／`_COST_PCT` 族，排除 TRAINER_／REPAIR_／POWER_DISPLAY_ 等）、施法、冷卻、距離、屬性（`ITEM_MOD_*_SHORT`）、護甲、傷害、耐久、套裝、需求。
  數字型 conversion（%d／%.2g）只吃數字——用 `(.-)` 的話 zhTW「冷卻時間%.2g秒」會吞掉「冷卻時間尚有：12秒」。`|4a:b;` 展開單數／複數／原碼三條。三語 GlobalStrings CSV 在 `Interface/tmp/GlobalStrings/`（gitignored，wago.tools `db2/GlobalStrings/csv?locale=zhTW`）。
- **`lineIndex` 確實由 `TooltipDataHandlerMixin:ProcessLineData` 第 330 行寫回 lineData**；不在 data 裡的 `TextLeftN` 就是別人（含我們的 ID 行）`AddLine` 加的，全收進「其他」區，**一行不丟**。
- **描述數字只能上色不能加粗**（FontString 不能局部換字型）。zhTW 描述不切句、整段畫。
- **`/mtip record on|off|clear` 記錄模式**（使用者要求「滑的時候記錄，不要滑一次 dump 一次」）：post-call 自動記 data 整張＋當下 FontString 文字顏色＋語系，同 id＋型別＋行數去重、上限 60，存帳號層 `MiliUI_Tooltip_DB.dumps`，/reload 才落地。
  真實行結構（尤其配方「製造／材料」、屬性行形狀）**全部還是推定**，等 record 資料進來對 fixture；README 待實機驗證 1～14。
- 設定：`item.panel`／`spell.panel`（預設開）、`panel.{separators,strip,numberColor,numberCustom,statMarkers,levelBadge}`，靠 MergeDefaults 補，沒遷移。離線測試 `Tests/*_test.lua` 六支。

相關：[[project-miliui-unit-frame]]、[[wow-121-secret-values]]、[[project-121-addon-migration]]、[[project-tinytooltip-perf]]、[[project-local-addon-forks]]、[[project-miliui-hud-skin]]
