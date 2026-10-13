---
name: project-burst-helper
description: 自製 MiliUI_BurstPotionHelper 爆發藥水切換插件的設計與維護——戰鬥零讀取避免秘密值、SecureHandler 切換、item:ID 不用 bag slot、選擇持久化只存意圖、分環境記憶、團隊副本只在首領戰喝（「首領戰」的 secure 定義＝這場戰鬥見過 bossN 就鎖存到脫戰）；藥水 itemID 每季更新
metadata: 
  node_type: memory
  type: project
  originSessionId: e7321db7-8df6-4ae1-a0e8-59ea5426ae4d
  modified: 2026-09-13T20:54:22.653Z
---

`AddOns/MiliUI_BurstPotionHelper/` 是參考 `BurstPotionSwitcher` 重寫的爆發藥水切換插件。SV `MiliUI_BurstPotionHelperDB`。
檔案：`Data.lua`（藥水清單）、`Core.lua`（DB／掃描／環境）、`Secure.lua`（閘框＋use button）、`Bar.lua`（切換列）、
`Options/{Panel,Tab_General,Tab_List,Tab_Macro,Blizzard}.lua`（MiliUIWidgets 自製視窗，2026-08-23 起；舊的暴雪 Settings canvas 面板的坑見 [[wow-settings-canvas-onrefresh]]、
遷移過程見 [[project-miliui-esc-menu-window-migration]]）、`Api.lua`。切換列參與 [[project-miliui-snap-bars]]（磁吸、滑鼠淡出群組 `fadeEnabled`／`fadeAlpha`）。

**核心設計（避免污染/秘密值）**：tainted Lua 在戰鬥中「零保護呼叫、零背包讀取」——`C_Item.GetItemCount`/插件自己的 `SetAttribute` 只在非戰鬥執行（戰鬥中設 `pendingRebuild`/`pendingApply`，`PLAYER_REGEN_ENABLED` 補做）。秘密值只由 unit/aura 類 API 產生，此插件完全不碰。**插件完全不碰巨集**（不再有 `EditMacro`/`#showtooltip`/圖示同步——使用者要求移除，2026-06）。

**戰鬥中切換藥水/選擇不使用**：靠 SecureHandler 在受限環境內完成。每個切換列圖示是 `SecureActionButtonTemplate`，用 `SecureHandlerWrapScript(btn,"OnClick",btn,preBody)` 包一段 snippet：左鍵時把預存 `potionref`（非戰鬥寫入的 `"item:ID"`）複製到共用 use button（戰鬥合法）。`SecureHandlerSetFrameRef(btn,"use",useButton)`、wrap、`potionref` 全部只在非戰鬥寫。insecure `HookScript("OnClick")` 只在左鍵更新存檔/貼圖。

**ref 用 `item:ID` 不用 "bag slot"（2026-09 改，別回退）**：原本照 BurstPotionSwitcher 用 "bag slot"（理由是「指定到那一疊＝那個品質」），但每個品質本來就是獨立 itemID，`item:ID` 一樣精確。"bag slot" 是**位置**，屬性在戰鬥中鎖死：那一疊在戰鬥中喝完，ref 就指著空格直到脫戰 → 暴雪 `SECURE_ACTIONS.item` 先 `SecureCmdItemParse` 從空格取名字得 nil → `C_Item.IsEquippableItem(nil)` 在 12.x 直接丟錯、整個動作中斷（BugGrabber：`bad argument #1 to '?' (Usage: local result = C_Item.IsEquippableItem(itemInfo))`，locals `item="0 4" name=nil`）。同瓶還有另一疊時就是「第二瓶按不出來」。改成 `item:ID` 後 `ScanAvailable` 也不用走背包了（只剩 `GetItemCount`）。

**右鍵直接喝（預設關，`db.rightClickUse`）**：開啟時 layout 給每個變體按鈕設 `type2="item"`/`item2=ref` → 右鍵直接喝該品質藥水（不影響選取）；none 鈕不設 type2。切換選項要重寫 type2（保護操作）→ `ns.SetRightClickUse` 非戰鬥才 relayout。

**點擊邊緣 gotcha（曾經喝不出來）**：(1) 巨集 `/click` 只送 up-edge，配 `ActionButtonUseKeyDown` cvar 開啟時普通 click action 不觸發 → use button 必須設 `pressAndHoldAction=true` + `typerelease`/`itemrelease`（外加 `type1`/`item1`），照抄 BurstPotionSwitcher 的配方。(2) selector 的 OnClick 被 `SecureHandlerWrapScript` 包過，`SafeCallWrappedHandler` 不轉傳 isSecureAction → 變 keypress(fire-on-down) → selector 要 `RegisterForClicks("AnyDown","AnyUp")` 兩邊都註冊才會剛好觸發一次；insecure hook 用 `if down then return end` 只在 up 跑一次。snippet 設 use button 時也要設整組（type/item/typerelease/itemrelease/type1/item1+pressAndHold），否則戰鬥中切換後 release 路徑會用到舊 ref。

**品質文字（信任偵測）**：`ns.GetQualityLabel(itemID)` 對**所有**物品都用 `ns.GetItemQuality`（`C_TradeSkillUI.GetItemReagentQualityByItemInfo`，fallback 解析 `GetItemReagentQualityInfo().iconInventory` 的 `Tier(%d+)`）→ 這些藥水只有兩種品質，所以 `q>=2`→`LABEL_T3` 高品質、`q==1`→`LABEL_T1` 一般；`LABEL_T2` 目前用不到。**Data 是純 itemID 清單**（`ns.DEFAULT_ITEMS`＋`ns.DEFAULT_ITEM_SET`，照「每瓶：大鍋高/一般、工藝高/一般」順序，較小 ID 排前＝高品質在前），不記 rank/kind/groupKey；舊的 `ns.POTIONS`/`VARIANT_BY_ID`/`GROUP_ORDER`/`GetVariantLabel`/`db.selectedKey`/「同群組優先選取」都已移除。`itemList`/`available` entry 只剩 `{id,isCustom,enabled}` 與 `{id,count}`。

**選擇持久化（2026-06 修過大坑，別回退）**：`db.selectedItemID` 是「使用者意圖」、**掃描永遠不可覆蓋它**。先前 `EnsureValidSelection` 寫成「選的那瓶不在 `byID` 就改成 `available[1]`」——但**登入時背包快取常是冷的**（掃到 0 瓶，跟 PositionBar 同一個冷快取事實），於是把存好的選擇洗成 nil→下次掃到變第一瓶，使用者回報「上線預設不是原本那罐」（間歇、偏向清單前段）。正解：`EnsureValidSelection` **只在 `selectedItemID==nil`（從沒選過）時**設初始預設，其餘一律不動；「現在實際要喝/標黃框的那瓶」由 `ns.GetSelected` **執行期計算**——存的那瓶在背包就用它、不在（冷快取/用完）就暫用 `available[1]` 當後備但**不寫回 DB**。三個呼叫處（`ApplySecure`、`Bar_UpdateSelection`、`Bar_Layout` 收合）都吃這個「有效選擇」。`db.disabled`（不使用藥水）仍提前 return。

**踩過的低級坑**：`db.itemEnabled[id] = enabled and nil or false` 在 Lua **永遠是 false**（`X and nil` 短路成 nil 再 `or false`）→勾選永遠停用、無法再勾。正解用 `if enabled then nil else false`。`RestoreDefaults` 要同時 wipe `removedDefaults` ＋清掉 default 的 `itemEnabled`（重新啟用），否則「恢復預設」對被停用的沒作用。設定頁的 DB→UI 刷新在 `Tab_General` 的 `RefreshAll`（分頁顯示時叫，不在建表時讀 DB）。

**品質星徽圖標**：別用 rank 猜 tier（會錯，尤其大鍋）。用 Blizzard 在背包按鈕的同一來源 `C_TradeSkillUI.GetItemReagentQualityInfo(itemID).iconInventory` 取 atlas（保證和遊戲內一致），再用 `C_Texture.GetAtlasInfo` 拿原生尺寸 ×`BADGE_SCALE`(=1) 顯示。沒品質的物品回 nil → 不顯示徽章。

**「不使用藥水」按鈕**：切換列尾端固定一顆紅色禁止圖示（`Interface\RaidFrame\ReadyCheck-NotReady`），potionref="" → snippet 清空 use button；選中一樣套黃框（`db.disabled` 旗標）。X 圖透明，所以 `slotBg`（不透明近黑、內縮 1px）要畫在黃 `border` 之上（sublevel 2 > border 1），選中時只露出 2~3px 黃框、底維持黑色。

**語系架構**：AceLocale-3.0（`Libs/LibStub`+`Libs/AceLocale-3.0`、`embeds.xml`、`Locales/Locales.xml` 載 `enUS/zhTW/zhCN.lua`）。enUS 為 default(`NewLocale(...,true)`)、其餘 `NewLocale(...,locale); if not L then return end`。Core.lua 頂 `ns.L = LibStub("AceLocale-3.0"):GetLocale(addonName)`（TOC 要先載 embeds+Locales 再載 Core）。新增字串三個語系檔都加（enUS 必加否則 AceLocale 報錯）。⚠ 這支用 AceLocale＋token key，共用層的語系契約**不要擴充**（見 CLAUDE.md）。

**藥水冷卻顯示（`db.showCooldown`，預設開）**：每個 selector 加一個 `CooldownFrameTemplate` 子框（insecure，不繼承保護→戰鬥中更新安全）。`ns.Bar_UpdateCooldowns` 用 `C_Item.GetItemCooldown(itemID)`→`CooldownFrame_Set`；由 `BAG_UPDATE_COOLDOWN`（戰鬥中也照跑）+ `Bar_Refresh` 末尾 + 選項切換觸發。count/badge 在比 cooldown 高 5 級的 overlay 子框。none 鈕無 itemID→不顯示 CD。

**收合（`db.collapsed`）**：左鍵點拖曳把手 grip 收合成只剩選取那一格／再點還原。grip 用 `_moved` 旗標分辨「拖動」vs「點擊」：OnMouseDown 重置、OnDragStart 設 true、OnMouseUp 左鍵且 `not _moved` 才 toggle。收合要 Hide 受保護的 selector → 戰鬥中不能做，`Bar_ToggleCollapse` 戰鬥中改設 `pendingApply` 出戰再套，並印 `MSG_COLLAPSE_COMBAT`。**（2026-06 實測：戰鬥中強制 relayout 會噴一連串 `ADDON_ACTION_BLOCKED`——`SetAttribute`/`Show`/`ClearAllPoints`/`SetPoint`/`SetWidth`/`SetShown`，連列 frame 本身都被擋。收合/展開在戰鬥中絕對只能延後。）**`Bar_Refresh` 收合時只把「選取那格(或 disabled 時的 none 鈕)」放進 `cells` 重新 pack。**收合靠左 + 預設位置**：列一律用 `BOTTOMLEFT`→UIParent `BOTTOMLEFT` 錨點（`db.bar={x,y,v}` 存左下角絕對座標），任何寬度變化都往右伸縮、左緣固定。`db.bar.x/y=nil` 代表「自動擺放一次」：`PositionBar`（要等掃到藥水 `#available>0` 才算）x 置中、y=`UIParent:GetHeight()*DEFAULT_Y_FRACTION`(0.10)。**`PositionBar()` 必須在 `Bar_Refresh` 末尾呼叫**（不能只在 PLAYER_LOGIN）——登入時背包快取可能是冷的、掃到 0 瓶 → 會跳過定位、列卡左邊 x=0（[[wow-login-screen-size-not-final]] 同類）。拖曳 `SavePosition` 用 `GetLeft/GetBottom` 實際幾何存檔再重錨。**位置版本** `ns.BAR_POS_VERSION`（現 2）：改預設位置時 +1；InitDB 偵測舊格式(`db.bar.point`)或 `db.bar.v` 不符 → 重設 `{x=nil,y=nil,v=新版}` 一次性重新擺放。grip tooltip：鎖定時「已鎖定」否則「拖動以移動」，外加「左鍵：收合／展開」「右鍵開啟設定」。

**效能模型（2026-06 已最佳化，別回退）**：全插件**零 `OnUpdate` 輪詢**，純事件驅動；框架池化重用（`ns.buttons[]`/設定列 `rows[]`）。(1)`ScanAvailable` **不走背包**，每瓶只問 `GetItemCount`。(2)`ns.GetItemQuality`（Core）與 `GetQualityAtlas`（Bar）**memoize**——只快取非 nil 結果（未載入的下次重試）。(3)`ITEM_DATA_LOAD_RESULT` 是全域高頻事件，**只在設定清單分頁顯示時註冊、隱藏時取消**，平時遊戲完全不進 handler。(4)`Bar_UpdateCooldowns` 在 `showCooldown=false` 時用 `ns.cooldownsShown` 旗標「清一次後就 return」。

**機制**：單一隱藏 `SecureActionButton`（global 名 `MiliUIBurstButton`），巨集 `ns.MACRO_LINE = "/click MiliUIBurstButton"`（`/click` 預設就是左鍵）。grip 把手是方向三角形（`ChatFrameExpandArrow` 貼圖＋vertexcolor 暗灰藍）：收合顯示▶、展開顯示◀，由 `ns.Bar_UpdateGripArrow` 依 `db.collapsed` 更新。框架用套組無邊框風格（`WHITE8X8` edge `edgeSize=1` + 暗底）。一般分頁：顯示列／鎖定列／右鍵直接喝／冷卻／物品提示／切換時聊天提示／重置位置、團隊副本只在首領戰、滑鼠淡出、分環境記憶；「巨集」分頁複製巨集。

**可編輯藥水清單（item 級）**：`Options/Tab_List.lua`，每個 itemID 一行（勾選啟用＋刪除X），可手動新增（輸入 ID 或 Shift 點物品連結，靠 `hooksecurefunc("HandleModifiedItemClick")` 帶入）。**資料模型**：預設清單放程式碼 `ns.DEFAULT_ITEMS`＋`ns.DEFAULT_ITEM_SET`；DB 只存 `db.itemEnabled[id]=false`（停用）、`db.removedDefaults[id]=true`（刪掉的預設）、`db.customItems[]`（自訂）。`ns.RebuildItemList()` 合併「預設(未刪)＋自訂」成 `ns.itemList`，`ScanAvailable` 只掃啟用的。**改版自動帶新預設**：預設來自程式碼，Data.lua 加新水→所有人自動出現，不用遷移。操作：`ns.SetItemEnabled/RemoveItem/AddItem/RestoreDefaults`→`RefreshFromListChange`（戰鬥中設 pendingRebuild，清單 UI 用 `ns.RefreshSettingsList` 即時重畫，因 RebuildItemList 是純 DB 讀取、戰鬥安全）。

**分環境記憶（`db.splitByContext`，預設開，2026-07）**：選擇（`selectedItemID`/`disabled`）依環境分開存 `db.profiles[ctx]`，六個 ctx：world／party（M+/五人地城）／raid／pvp（戰場）／arena／scenario（探究/儀式）。**環境判斷**（`ns.ComputeContext`，掛 `PLAYER_ENTERING_WORLD`）：`GetInstanceInfo` 的 instanceType 為主，但 **"party" 不可直接信**——要塞/跟隨者地城(205)/任務副本(216)也回 "party"，須再過 difficultyID 白名單 {1,2,8(M+),23,24}（`DifficultyUtil.ID` 常數+數字 fallback）；`scenario` 概括探究(208)與 Midnight 儀式地點；其餘歸 world。**存取一律走 `ns.SelStore()`**（split 關閉時回傳 db 本體；profile 懶建立、以共用欄位為種子），`OnSelect/OnSelectNone` 同時鏡寫共用欄位（關閉選項時保留最後選擇）。UI：一般分頁 `SETTINGS_CURRENT_CONTEXT` 顯示目前記憶；grip tooltip 加 `TIP_CONTEXT`；換環境時聊天印 `MSG_CONTEXT_APPLIED`。

**每季維護**：`Data.lua` 的藥水 itemID 是當季資料：圣光潜力(241308/241309, 大鍋245898/245897)、鲁莽(241288/241289, 大鍋245903/245902)、惡念狂飲 Draught of Rampant Abandon(241292/241293, 大鍋245911/245910)。改版換新藥水要更新（類似 [[project-itemupgrade-preview-icon]] 的季更新模式）。toc 版本號跟 [[project-toc-interface-bump]] 一起 bump。

## 團隊副本只在首領戰喝（`db.raidBossOnly`，預設開，2026-09-27 cbb875f84）

use button 的所有寫入改走一個 `SecureHandlerStateTemplate` 閘框 `ns.gate`（Secure.lua）：`state-sel`＝選的 ref（ApplySecure 脫戰寫、選取 snippet 戰鬥中寫——snippet 對 `state-` 屬性 SetAttribute 會觸發 `_onstate-sel`）、`bossonly`＝選項開且 ctx==raid（只脫戰寫）、`state-boss` 由 `RegisterStateDriver` 驅動。`GATE_APPLY` 在閘關著時清空 use button，**選擇本身不改**（不變成 X，首領一上來自動恢復）。脫戰預喝照常；右鍵直接喝不受閘影響。UX：暫停時藥水圖示去色＋alpha 0.4（只換明暗）、tooltip 加「目前沒有首領，按巨集不會喝」、進團隊印一行提示。視覺是 insecure 鏡射（REGEN／INSTANCE_ENCOUNTER_ENGAGE_UNIT／ENCOUNTER_* 事件＋`UnitExists("bossN")`，秘密布林當「有首領」），**不要 hook 閘框的 OnAttributeChanged**（會把插件 Lua 塞進 state driver 的 secure 迴圈）。

**偵測模型：「首領戰」的 secure 定義 ＝ 這場戰鬥中曾經有 bossN 存在**（31f21074c，實機：首領戰轉階段首領框暫時消失，被判成小怪戰、藥水被清掉）。
第一版 driver 是二態 `[nocombat] open; [@boss1..5,exists] open; closed`——「現在有沒有首領框」當下判，轉階段／換首領的空窗就關閘。改成：

- driver 三態 `[nocombat] nocombat; [@boss1..5,exists] boss; trash`；
- `GATE_APPLY` 在 `boss` 時 `SetAttribute("seenboss", true)`、`nocombat` 才清，閘只在 `bossonly ∧ trash ∧ not seenboss` 時關 ⇒ 這場戰鬥見過首領就一路開到脫戰；
- insecure 鏡射 `ns.bossSeen`（`ns.UpdateBossSeen`，掛 REGEN_DISABLED／ENGAGE／ENCOUNTER_*／REGEN_ENABLED）同步給變暗用。

**沒有 secure 的「首領戰中」訊號**：巨集條件沒有 encounter 類（wiki 確認），`ENCOUNTER_START`／`IsEncounterInProgress`（傷害統計用的那個）只有 insecure 讀得到，戰鬥中寫不進閘框——所以只能用「見過」鎖存，不能用「遭遇中」。剩餘盲點：開怪當下首領框就沒出現的戰鬥（鎖存救不了），待實機。
