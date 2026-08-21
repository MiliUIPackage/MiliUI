---
name: project-tinytooltip-perf
description: TinyTooltip-Remake 滑過裝備掉 FPS 的根因與 MiliUI 就地效能修補
metadata: 
  node_type: memory
  type: project
  originSessionId: 20ca021f-292c-45db-a109-d31d6d73f347
---

TinyTooltip-Remake 是 MiliUI 維護的**就地修補**插件（Core.lua/Item.lua/LinkID.lua/General.lua 內有大量 `fix from MiliUI`〔taint〕與 `perf fix from MiliUI`〔效能〕標記）。**上游更新會覆蓋這些修補，更新後需重新套用。**

**2026-06-22 修掉「滑過背包/裝管裝備掉 FPS」**（~2700-3700 ms/s → ~195 ms/s）。

根因：滑到可裝備物品 → 暴雪 `TooltipComparisonManager` 每秒對 tooltip 清空重建 **20-25 次**（`<Cleared>` == `ProcessInfo`，頻率關不掉），每次都觸發 TinyTooltip 整條樣式鏈。三個放大來源依序修掉：
1. **Show 連鎖風暴**（ShoppingTooltip1:Show 80→464/秒）：Item.lua / LinkID 在重建途中又 `tooltip:Show()` → 再觸發 ProcessInfo。修法：ProcessInfo/OnTooltipSetItem hook 期間設 `_tinySuppressShow`，加行只設 `_tinyNeedsShow`，整批加完統一 Show 一次。
2. **SetBackdrop 材質重建**（最大宗）：邊框色每週期在「預設(清空)↔品質(物品)」擺盪，使含顏色的快取 key 永不命中。修法：`ApplyNativeBackdrop` 把**結構**(背景/邊框檔、尺寸、insets、邊角、遮罩)與**顏色**拆成兩把 key，昂貴的 SetBackdrop 只在結構變時做；4 個失效點(Reapply / OnShow / 2×SetBackdropStyle)要同時清 `_tinyLastBackdropKey` 和 `_tinyLastStructKey`。
3. **重複解析**：LinkID 的 gmatch 物品字串解析改 `ComputeItemIdData` + per-tooltip 快取。

剩 ~195ms（SetBackdrop ~60ms）是暴雪每刷新用 `SetBackdropStyle` 重設底框、我們必須重套自訂底框的合理地板。

**2026-06-22 補：秘密值(secret)防呆**（同屬上述效能修補、重套時要一起帶上）。物品品質邊框色在新版可能是「秘密值」(暴雪防自動化的值污染)，`Core.lua:1885` 用 `table.concat` 把顏色字串化做 styleKey 時會丟 `invalid value (secret) at index 6 in table for 'concat'`（577x 洗版）。修法：styleKey 的 concat 包 `pcall`，失敗就 `styleKey=nil` → 跳過「整個樣式」早退，但 structKey(不含顏色、永不秘密)仍照常擋下昂貴 SetBackdrop，顏色每週期只走便宜的 SetBackdropBorderColor，效能優化不受影響。注意 structKey(line 1880)別放顏色，否則它也會變秘密而失去擋重建能力。

診斷方法：用自製 `MiliUI_FPSDebug`（watch=各插件 ms/s、count=tooltip 函式次/秒、trace=呼叫堆疊、prof=逐 LibEvent 事件計時、t1/t2=A/B 開關）；關鍵教訓：**prof 顯示 LibEvent 只 ~40ms 但 GetAddOnCPUUsage 報 1100ms → 成本在 Lua 之外的 C 端呼叫(SetBackdrop)**，別只看 Lua。相關：[[project-charframe-taint]]。

**2026-08-21 補：forbidden object 防呆**（同屬就地修補、重套時要一起帶上）。12.1 之後 UIWidget 系統會借走 `EmbeddedItemTooltip` 顯示安全內容（`Blizzard_UIWidgetTemplateBase` 的 `OnEnter` → `GameTooltip_ShowHyperlink` → `ProcessInfo`），期間框架變成 forbidden object，插件對它呼叫**任何**方法（連 `NumLines()`）都會拋 `Attempt to access forbidden object from code tainted by an AddOn`。這是動態狀態（載入時還能套樣式、之後才被鎖），所以只能在每個入口重問，`IsForbidden()` 本身在 forbidden object 上永遠可以呼叫。Core.lua 的 `IsForbiddenObject()` 已移到檔案開頭（原本在 1820 附近，工具函式在它前面用不到），現在兩層閘：**入口**（ProcessInfo、OnEvent、OnTooltipSetUnit/Item/Spell、OnTooltipCleared、OnUpdate、OnShow/OnHide、SetBackdropStyle）直接 return；**工具函式**（`GetLine`／`FindLine`／`HideLine`／`HideLines`／`AutoSetTooltipWidth`）也各自擋一次，其中 `GetLine` 回 nil，所以 Item.lua／Unit.lua／Spell.lua 的呼叫端一律要 `local line = addon:GetLine(...)` 再判空，不能接著 `:SetText()`。
