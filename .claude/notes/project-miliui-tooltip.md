---
name: project-miliui-tooltip
description: MiliUI_Tooltip — 取代 TinyTooltip 的自製滑鼠提示重寫版：接觸面清單、架構決策、v1 刻意捨棄的功能、待遊戲內驗證清單
metadata: 
  node_type: memory
  type: project
  originSessionId: 629d19ba-309f-41f7-aa47-258c1bee5d39
  modified: 2026-08-22T14:05:39.146Z
---

**MiliUI_Tooltip**（2026-08-22 一次寫完，約 4700 行自寫 + 1200 行 vendor）：取代
`TinyTooltip-Remake` 的全新滑鼠提示插件，只支援 12.1+。`AddOns/MiliUI_Tooltip/`，
SV `MiliUI_Tooltip_DB`，namespace `_G.MiliUITip`，指令 `/mtip`（`/mtip reset`、`/mtip debug`）。
計畫全文在 `~/.claude/plans/miliui-tooltip-rewrite.md`。**尚未 commit、尚未遊戲內驗證。**

**Taint 圍堵設計**（核心賣點，接觸面清單維護在 `Core/Hooks.lua` 檔頭）：
- 裝飾全在自己的 skin frame（tip 的 child、frameLevel = tip−1、SetAllPoints）：背景 1 貼圖＋
  邊框 4 貼圖＋漸層 mask＋大陣營圖＋血條＋3D 模型全掛這上面。**純貼圖零 SetBackdrop** ⇒
  沒有跟暴雪 SetBackdropStyle 的攻防戰（TinyTooltip ~195ms 效能地板的根源直接消失）；
  上色一律 SetVertexColor（吃秘密分量）。
- 暴雪物件上**零欄位寫入**：per-tip 狀態在 `Skin.State[tip]`（frame 當 key）。
- 入口只有 TooltipDataProcessor post-call（Unit/Item/Spell/UnitAura/Macro）＋
  hooksecurefunc（SetDefaultAnchor、AddInstructionLine、SetAction/SetMacro、
  ItemRefTooltip.SetHyperlink、InspectUnit）＋ HookScript(OnTooltipCleared)。
  不換函式、不 SetScript 暴雪物件；每個入口先 `IsForbidden()` 閘。
- **不碰 EmbeddedItemTooltip**（UIWidget 會借走變 forbidden 的大宗）。skin 範圍：
  GameTooltip、ShoppingTooltip1/2、ItemRefTooltip、ItemRefShoppingTooltip1/2、NamePlateTooltip。
- 一次性視覺中和：`NineSlice:SetAlpha(0)`（skin OnShow 重申）、`GameTooltipStatusBar:SetAlpha(0)`。
- 血條是自己的：`UnitHealthPercent(unit, true, ScaleTo100)` → SetValue(秘密)；文字
  AbbreviateNumbers（zh）/AbbreviateLargeNumbers + SetFormattedText；0.15s 輪詢 driver。
- **post-call 時序紅利**：行加在暴雪排版之前 ⇒ 不需要自我 Show()，比價重建風暴只剩重上色。
  Show() 只在 ProcessInfo 之外（目標行輪詢、非同步觀察刷新）呼叫。

**設定介面**：MiliUIWidgets vendor **第二個消費者**（Env 六項契約夠用，見
[[project-miliui-widgets-vendor]]）。Panel 700×520 照 UnitFrames；分頁：樣式/玩家/NPC/錨點/
物品與ID/關於。**即時預覽 = 自建 `CreateFrame("GameTooltip","MiliUITip_Preview",...,
"GameTooltipTemplate")` 走 ns.TrackTip 進同一條管線**——玩家預覽 SetUnit("player")（明文）、
物品預覽 SetItemByID(19019)，都是真管線；NPC 預覽餵假 raw。設定改動 → ns.ApplyAll →
Fire("SettingsApplied") → 重繪。

**v1 刻意捨棄**（要加回去時知道去哪找）：elements 的顏色/wildcard/filter 編輯 UI（DB 有、
UI 只給 enable+icon 開關，顏色沿用套組預設）、列版面編輯（DB.OverwriteElementRows 每次
登入用預設覆蓋列陣列）、per-unit 錨點 UI（DB 有 inherit 結構、UI 只出全域）、
skinMoreFrames 大清單、BattlePetTooltip、LSM border、SavedVariablesPerCharacter、
announcement、DialogueUICompat（未裝）、AutoSetTooltipWidth（賭 post-call 時序下引擎自己會量）。

**預設值 = 套組現行 TinyTooltip 樣式**：scale 1.2、1px 直角 0.18 灰框、0.133 深底、
cursorRight、血條 bottom h4、玩家職業框/NPC 立場框、elements 全套照抄 Config.lua。

**待遊戲內驗證**：① tooltip 寬度（重寫單位行後引擎會不會自己撐開，不行就要補
SetMinimumWidth）② GameTooltipStatusBar alpha 0 中和法夠不夠（會不會留 padding 空隙）
③ NineSlice alpha 0 會不會被暴雪某條路徑重設 ④ skin frameLevel −1 在所有 tooltip 上
都壓得住文字之下 ⑤ 比價風暴下的實測 CPU ⑥ forbidden 情境（UIWidget 光環行）
⑦ 預覽 tooltip 的 owner/自動隱藏行為 ⑧ 觀察裝等/成就非同步刷新。
**切換已完成（2026-08-22）**：TinyTooltip-Remake 整包從套組移除、
`MiliUI/Enhance/TinyTooltipRemake_FactionIcon.lua` 一併刪（扁平陣營圖示已內建進
UnitInfo.lua 圖標表，questlog atlas 款＋atlas 消失退回舊圖，另外三款寫在註解）、
`MiliUI/Enhance/LegacyAddons.lua` 的 REPLACED 加了 TinyTooltip-Remake → MiliUI_Tooltip
（自動停用玩家殘留資料夾）、AddonNames/MiliUI.toc 的引用清掉。
[[project-tinytooltip-perf]] 與 [[project-local-addon-forks]] 的 TinyTooltip 列已標作廢。

**第二輪實測回饋（2026-08-22）**：① 預覽移進設定視窗**左欄**（面板 1000 寬、左 340 固定
放預覽、右欄捲動；預覽 tooltip 改成 panel 的 child、frameLevel panel+20）；② 顯示元素改成
**可拖曳方塊看板**（Tab_Unit.lua：一列一條 strip、列內排序／跨列搬移／拖到「不顯示」隱藏／
拖到底部自成一列／點一下快速開關；列版面直接寫回 DB elements 數字鍵陣列，DB 端
OverwriteElementRows 改成 EnsureElementRows 健檢）；③ **QuickFocus 整個移除**（使用者不要）；
④ 法術的「按住修飾鍵顯示全部」要靠 MODIFIER_STATE_CHANGED 監聽補行＋Show——法術提示
不像物品會被比價系統一直重建，按修飾鍵不會重跑 post-call；⑤ **成就點數不是秘密值**
（自己 GetTotalAchievementPoints、別人觀察快取，都先過 PlainNumber），新增 colorfunc
"achievement"（4萬橘/2萬紫/1萬藍/5000綠/白）設為預設；⑥ 預設值再調：showModel 玩家=false、
spell.modifierShowAll=true、成就色；**遷移鏈已整個拔掉（未發佈）**，預設值變動要使用者
`/mtip reset` 才會吃到；⑦ 設定介面說明不提 TinyTooltip（致謝除外），原作者致謝名=55510696。

**首輪實測回饋已修（2026-08-22）**：① 暴雪 GameTooltipStatusBar 載入時壓一次 alpha 0
不夠，單位提示流程會弄回來 → Bar.Activate 每次重申；② 血條/模型層級要明寫 tip+1
（skin 是 tip−1，child 放著會被 tooltip 背景蓋掉文字半截）；③ 單位背景 default 分支
不能拿 per-unit alpha 蓋全域 alpha（會讓「樣式」頁的背景透明度整個失效，預覽也走
這條）；④ 預設縮放 1.2 → 1，配 v2 值閘遷移。

## 輪詢改走共用 ticker（2026-08-28）

血條數值與 mouseover 目標行原本各自開一個**永久顯示**的 driver frame 掛 OnUpdate，
內部累加到門檻（0.15s／0.2s）才做事。問題不在做事那部分，而是 **OnUpdate 本身每一幀
都會進 Lua** —— 兩支加起來在 144fps 是每秒約 300 次空轉，從登入到登出，即使畫面上
根本沒有任何提示。

現在走 `Skin.Poll`（`ns.Metro.New(0.05, ns.ReportError)`，共用層），並掛在
「有沒有 tooltip 顯示中」上：沒有提示的時候 ticker 根本不存在。
可見度判斷用**我們自己的 skin frame 的 OnShow/OnHide** —— skin 是 tip 的 child，
父層一藏子層就跟著發 OnHide，等價而且**零接觸面**（不必掛暴雪 tooltip 的腳本，
不進 Core/Hooks.lua 那張接觸面清單）。

⚠ `Core/Bar.lua` 那條「不看個別 tip 的 IsShown」的需求還在（戰鬥中被藏起來的條要靠
輪詢在出戰鬥後撿回來）—— 新的閘是「有**任何**提示顯示中」，比它粗，所以沒有衝突。

⚠ `Core/Secret.lua` 已整支刪除，`ns.Secret` 改由共用層提供（是舊版的超集，
7 個 API 全含），呼叫點一個字都沒改。見 [[project-miliui-widgets-vendor]]。
相關：[[project-miliui-unit-frame]]、[[wow-121-secret-values]]、[[project-121-addon-migration]]

**戰鬥中敵方顯示成上一個友方（2026-08-23 log 破案，兩層）**：
① `tip:Show()` 會讓 tooltip **重新處理「儲存的上一份內容」**——目標行輪詢的 Show 把舊的
`unit="target"` 內容翻回來、重跑又把 `isUnitTip` 設回 true ⇒ 自我延續的舊資料迴圈，跟世界
游標畫的敵方內容互蓋。規則：**任何會 Show 的輪詢都要先確認「目前內容是自己要更新的那個
token」**（`SafeValue(state.unit)=="mouseover"` 明文比對）。
② 世界游標的秘密 token 連 `UnitExists` 都回**秘密布林**（不能 truth-test）⇒ SafeBool 當
false 早退，敵方整個套不到文法。**存在性判斷要 fail-open**：只有明文 false 才退、秘密照畫
（文法全程秘密值安全）。UnitLines.Apply 與 Bar.RefreshInner 兩處同款。
診斷靠 `/mtip log`／`/mtip logdump`（Init.lua 的 ns.Log 記錄器，秘密值只標型別）。

**戰鬥中光環顯示法術 ID（2026-08-23 三輪 log 收斂）**：12.1 光環 tooltip 資料
**不帶 `args`**（TinyTooltip 讀 `args[2].intVal` 是舊制）、`lines[1].tooltipID` 也是 nil，
**spellId 在 `tooltipData.id`，戰鬥中是秘密數字**。顯示走 format 傳遞（AddIdLine 不可
tostring，秘密值會炸）；要明文的（坐騎查表、圖示 ID 解析）下游各自把關，戰鬥中沒有
那兩項是正常的。`C_UnitAuras` 的 setter 解析（AurasAreSecret 閘）只剩脫戰時的補充。

## 玩家回報「職業欄有時候不見」（2026-09-08～15，玩家 log 破案）

**成因在玩家端：殘留的 Leatrix_Plus（「Manage tooltip」TipModEnable）在我們寫完之後
按固定行號就地覆寫第 1–3 行。** 套組 2026-08-29 移除了 Leatrix_Plus，但**沒有列進
`MiliUI/Enhance/LegacyAddons.lua`**，解壓縮覆蓋更新的玩家舊資料夾照樣載入。本機重現不了。
現場指紋（`/mtip log` 的 pre/post 行掃描，對照 git 歷史裡的 Leatrix_Plus.lua 9407–9521 行）：
- L1 `名字 - 伺服器|cffffffff|r`、L2 `|c00aaaaff公會名|cffffffff|r`（不帶 `<>`）、
  L3 `等級 90 種族|cffffffff|r`（有空格）—— 每行尾巴的 `|cffffffff|r` 是它的簽名
- 目標行有兩條：`選取目標: [名字]` 是**我們的**（暴雪 zhTW 的 `TARGET` 全域就是「選取目標」，
  NPC 目標用 `[ ]`）；`目標: 名字` 是 Leatrix 的（`ttTarget` 寫死「目標」）。
  ⚠ 別把「選取目標」當成外來插件的指紋，一開始就判反過
- 第一輪 post 之後 0.06–0.15s 就被改，中間**沒有 OnUnit/Apply**（暴雪 ProcessInfo 一定先 ClearLines 再觸發 post-call，所以不是暴雪重建）
- 只有觀察／成就資料到貨的 relayout 會把我們的行寫回去 ⇒ **快取過的玩家永遠壞**，
  也就是玩家描述的「只出現一次」「滑回第一個人也沒了」
處理：請玩家停用或刪掉 Leatrix_Plus（或關掉它的 Manage tooltip）；套組端把 Leatrix_Plus 和 MBB（同一天移除、同樣漏列）加進 LegacyAddons 的 REPLACED（2026-09-15），取代者分別掛 MiliUI_Tooltip／MiliUI_Minimap。**從套組移除插件時要同步列進 LegacyAddons**，不然解壓縮覆蓋的玩家永遠留著。

**順帶修掉的自家 bug**：relayout 時行已經是自己寫的，`GetOriginalSpecLine` 找「含職業名
的最短一行」會抓到自己的職業列 ⇒ 整列塞回職業欄、畫面上重複一次
（log：`class="復仇 惡魔獵人 90 聯盟 女性 夜精靈"`）。規則：**relayout 不可從 FontString
文字推斷任何東西**，只吃第一輪（post-call）存下的快取。

**被否證的假設**：secret aspect（`SetText(秘密)` 讓行的 GetText 永久回秘密）—— 玩家 log
全行 `aspect=false`，脫戰同陣營時 name/class/guid 全明文。`HasSecretAspect("Text")`／
`HasSecretValues()` 在 FontString 上回明文布林，探針可用。
`UnitInfo.JoinRow` 不可用 `table.concat`（秘密字串進去整列回 ""），已改逐段 format。
