---
name: wow-blizzard-window-skin-strategies
description: 暴雪原生視窗換皮（12.x）的通用策略——背景直接建成目標框的貼圖、進度條邊與文字同框交錯、池化列掛法、物品格方框、哪些區域一律不碰與原因；做 MiliUI_Skin 或任何「重畫暴雪視窗」時先看
metadata: 
  node_type: memory
  type: reference
  originSessionId: 3d3da2d2-d8a9-4944-8afe-aebf91167c1f
  modified: 2026-09-20T18:21:24.702Z
---

歸納自對成熟同類實作的研讀（2026-09-21），配合 [[project-miliui-skin]] 自己五輪實測。**只記策略，不記出處、不抄程式。**

## 背景怎麼畫（最重要的一條）

**直接 `frame:CreateTexture(nil, "BACKGROUND", nil, -8)` 建在目標暴雪框自己身上**，不要另建子框當底。
- CreateTexture 不寫任何 Lua 欄位、不改 secure 屬性 ⇒ 不 taint；**保護框／隱式保護的容器照樣能建**（收藏視窗那種「secure 子孫把祖先染成保護」的情況不必特判）。
- 貼圖在 BACKGROUND 的最底 sublevel（-8 底、-7 邊、-5 標題帶…）⇒ 永遠在該框自己的內容之下，**沒有 frame level／strata 問題**（DIALOG strata 的彈窗、`useParentLevel` 的 Inset、toplevel 提層都不用管），顯示隱藏自動跟隨。
- 子框只留給「必須畫在內容之上」的東西（物品格的品質方框、外框裝飾），level 設 `目標+N`。
- ⚠ 例外：自動排版的框（ResizeLayoutFrame／Vertical／HorizontalLayoutFrame）會把 region 算進版面 ⇒ 底改建在它底下的非排版子框（彈窗的 `BG`、ESC 選單的 `Border`）。
- 保護判斷不要用 `IsProtected()` 黑名單；用**模板特徵白名單**：只處理「確定認得的模板形狀」（例如同時有 Left/Middle/Right 三段的按鈕），secure 格子天然不符合就被跳過。統一守衛是 `IsForbidden()`。

## 進度條

- 邊框的貼圖建在**條自己身上**（BORDER／BACKGROUND 層），不要放在 level+1 的子框 —— frame level 會壓過所有 draw layer，邊線就橫切條上的文字；同一個框內 region 按 draw layer 交錯，文字（OVERLAY）自然浮在邊上。邊往外擴 1px，填充碰不到。
- 背景槽：BACKGROUND 一張深色（約 0.12 @0.85）。填充換平面材質；`FadeRegions` 類的掃描要把 `GetStatusBarTexture()` 放進保留名單。
- 條上的字偏高可以一次性下移幾 px（那是我們契約外的 SetPoint，要另行核准）。

## 分頁

- 視覺：分頁底＝面板色；**選中＝微提亮＋一條強調色底線（1~2 物理像素）＋白字；未選＝字降到 0.5~0.65**；hover＝只提亮底。不要用整塊強調色、也不要在共用邊線的分頁上畫 hover 邊框（右邊線屬於下一顆，永遠只會亮三邊）。
- 選中判定的可靠來源依序：自己的覆寫 > `parent.selectedTabID == tab.tabID` > `tab.isSelected` > `PanelTemplates_GetSelectedTab`；重畫觸發點：`PanelTemplates_SetTab/UpdateTabs` 後置勾、TabSystem 的 `SetTabVisuallySelected`。
- 分頁計數文字（「公開訂單 (4)」）不一定經過 button 的 SetText，會直接改 label。

## 池化列（ScrollBox）

- 最通用的掛法：`hooksecurefunc(scrollBox, "Update", …)` ＋ 立即 `ForEachFrame` 掃一次；有 mixin 的勾 mixin 方法。列內狀態分「一次性結構」與「每次重申」。
- ⚠ **skin 永遠不可以是觸發某個 ScrollBox「第一次 layout」的那個人** —— 會污染它的 updateLock，之後每次 Update 自我 taint，而且 taintLog 看不到。對 ScrollBox 支撐的視窗，寧可延到該框第一次 OnShow 之後才掃。只做唯讀的 `ForEachFrame` 沒事；不要主動呼叫它的 Update／FullUpdate／SetDataProvider。
- 遞迴掃描一律有深度上限，並跳過「別的插件塞進暴雪視窗的框」及其整棵子樹（`issecurevariable` 可判斷）。

## 物品格

- 暴雪的 `IconBorder` 是圓角環，跟方形裁切衝突 ⇒ 一律 alpha 0，自己畫方形 1px；**顏色從暴雪的環轉交**（不查 itemID）。沒有品質時畫黑邊而不是隱藏 —— 空格子要看得出「這裡是一格」。
- 方框錨在 **icon** 上、外擴 1px（貼齊會被 icon 蓋住），host 是自己的子框、level 在上。
- 重畫要同時接**全域** `SetItemButtonQuality` 與**實例方法**那一條 —— 商人視窗直接呼叫方法不經全域。
- 裁邊前先確認圖示沒有遮罩（`GetNumMaskTextures() > 0` 跳過），`SetTexCoord` 用 pcall。
- 商人格：**每格一個獨立底框**（內縮約 2px、1px 邊），商品名顏色（品質色）不動。

## 一律不碰的區域（都有人踩過）

| 區域 | 為什麼 |
|---|---|
| **通貨清單的列**（TokenFrame 的 entry／header） | 連淡化底帶都會讓戰隊通貨轉移（`RequestCurrencyFromAccountCharacter`）被封鎖 |
| 公會名單的尺寸／錨點 | 列在同一個 pass 讀回被寫過的寬度 ⇒ 整個 session 帶 taint ⇒ 改註記／階級被 FORBIDDEN |
| secure 的欄位表頭容器（ColumnDisplay 類） | 連 HookScript 都不行：OnShow 會在 secure refresh 裡觸發 |
| 世界地圖／任務日誌（QuestMapFrame）的腳本、池化任務列 | 通往任務追蹤的 taint 路徑 |
| 設定面板的每一項控制項 | 面積大、貼近 taint，只做外框 |
| `GroupLootContainer`、`SocialUIFrame` 的 sizer、`PVEFrame` 的位置 | UIPanel 管理路徑一沾，`ToggleUIPanel` 就死 |
| 預組隊伍的 per-result／per-member 資料 | 12.x 起是秘密值，讀就爆 |
| 就位確認／申請／邀請彈窗 | 另一類功能，按鈕通往受保護動作 |

## 文字顏色

- **SimpleHTML 的 `SetTextColor` 要帶文字類型**：`SetTextColor("P", r,g,b)`（標題另有 H1～H3）。不帶類型的 `SetTextColor(r,g,b)` 管不到純文字 ——
  沒標籤的內文是當 "P" 畫的。暴雪自己就這樣寫（ItemTextFrame.lua:58）。冒險指南踩過：換色、重畫都做了，字照樣暗棕。
- **SimpleHTML 的顏色（推測）在 `SetText` 那一刻才烘進去**：事後 `SetTextColor` 只影響下一次 SetText，已顯示的字不變。
  後置勾來不及 ⇒ 換色後用**暴雪剛寫的同一段文字**（取自被勾函式的參數，切段照抄）再 SetText 一次；內容相同，高度不變。
  FontString 的 SetTextColor 是即時的，沒這個問題。症狀：「第一次打開是暗字，收合再展開就對了」。

## 其他穩定性通則

- 狀態全放弱鍵外部表；連「哪些貼圖是我畫的」也記在那裡，重掃時按物件識別跳過自己的東西。
- 只用後置勾（hooksecurefunc／HookScript），永不 SetScript；對 secure 容器連 HookScript 都避開。
- **秘密值測試要排在任何比較之前** —— `w == 0` 本身就是比較，會先炸。尺寸／座標讀取一律當成可能是秘密值。
- 每份配方、每個回呼各自 pcall，錯誤丟給錯誤處理器而不是往上炸。
- 開關：樣式切換即時生效（兩套底同時存在、靠 alpha 切），只有「整個關掉」才需要 reload。

## 讓畫面顯得精緻的小手法

- 視窗頂部一條較暗的**標題帶**（約 24px，sublevel 在底之上），必要時底部對稱一條 footer 帶。
- 內嵌區比面板暗一階；區塊之間用 10% 黑洗＋1 物理像素分隔線，不用邊框堆疊。
- 捲軸 thumb 做成 4px 細條（白 0.3），軌道與箭頭隱藏。
- 標題重新置中到標題帶（原本相對已移除的頭像錨定，會偏幾 px）。
- 按鈕 hover 優先用引擎的 HIGHLIGHT 層（零腳本）；只有要改「顏色而不是顯示」才用 HookScript。按鈕 re-enable 會重設字型物件 ⇒ 白字要在 OnEnable 補。
