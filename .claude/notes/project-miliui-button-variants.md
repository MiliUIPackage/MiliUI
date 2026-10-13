---
name: project-miliui-button-variants
description: 全套組按鈕上色規則——primary（主動作）／normal（其餘）兩種長相、職業色公式、九條判準、實作入口（W.CreateButton／PaintButton／SetButtonVariant、Skin.Button）與舊配色待辦；所有自製插件與 MiliUI_Skin 換皮都要遵守
metadata: 
  node_type: memory
  type: project
  originSessionId: 71bbf8e9-54dc-4f24-a23c-4d295b4f2cac
  modified: 2026-10-14T00:00:00.000Z
---

**全套組的文字按鈕只有兩種長相。** 自製插件（`MiliUI`、`MiliUI_*`）用 `W.CreateButton` 畫的按鈕，跟 MiliUI_Skin 換過皮的暴雪視窗按鈕，一律照這套走。
（2026-09-22 使用者原話：「這種按鈕上色邏輯與方法寫到筆記內，整個 Interface 插件都需要遵守」。）

**Why:** Skin 第九輪時使用者說過「目前設計有時候不知道他是按鈕」。平時跟面板同一個 0.115 底的按鈕，在一片深灰裡只剩一圈黑邊可以認。主動作要自己帶顏色，而且整個套組要是同一顆按鈕。

**How to apply:** 新按鈕先照下面的判準決定是 primary 還是 normal，再挑 colorKey。**顏色一律從職業色（`Accent()`）推導。**
不要照擷圖挑一個色寫死：使用者的參考擷圖是薩滿所以看起來是藍色，換一隻角色就不是了。

## 兩種長相

| 狀態 | **primary** | **normal**（Skin 叫 secondary） |
|---|---|---|
| 平時 | 底＝保護色 × 0.30、1px 邊＝職業色 × 0.60 | 底 0.115、黑邊 |
| 滑過 | 底＝保護色、邊＝職業色（全亮） | 底提亮到 0.23（Skin 另外亮職業色邊，見待辦） |
| 按下 | 沒有底色變化（字往下 1px） | 同左 |
| 停用 | **退回中性**：0.115 底、黑邊、灰字 0.4。停用的按鈕不能看起來像能按 | 平時的底＋灰字 |
| 文字 | 白 | 白 |

**保護色**＝職業色 × k，`k = min(1, 0.40 / lum)`，`lum = 0.299r + 0.587g + 0.114b`。白字壓在職業色上時牧師（白）跟盜賊（亮黃）會讀不到，所以依亮度壓暗；
深色職業（死騎、薩滿、惡魔獵人）的 k = 1。門檻 0.40 而不是 0.50：拿十三個職業算過 WCAG 對比，0.50 會把十個職業壓成泥色。完整推導在 `AddOns/MiliUI_Skin/STYLE.md` ②「Tokens」的 `buttonTextLum`。

底色是算出來的**不透明純色**，不是用 alpha 疊在背景上（[[feedback-ui-visual-style]]、`miliui-color-states` 技能第三條）。

## 判準：哪一顆是 primary

1. 成對或成組時，「確認／執行」那顆用 primary。「取消／返回／拒絕／跳過」用 normal。
2. 只有一顆時用 primary。例外是它本身就是「返回／再見」。
3. 一整排平行選項（分頁、切換檢視、欄位表頭、每列只有一顆的「載入」）全部用 normal。
   ⚠ **例外：每一列都有、而且在列裡跟次要按鈕成對的主動作**。採購清單每列是「搜尋｜購買」，購買用 primary。它多半時候是停用的，所以平常整欄是中性的，只有真的還能買的那幾列會亮起來，反而成了資訊。
4. 一個區塊最多一顆 primary。「搜尋全部＋全部購買」只有全部購買是 primary；「製作＋全部製作」只有製作是 primary。
5. 會開選單的按鈕、可收合的清單標題用 normal。它們不是動作。
6. 讀不出是哪一顆時照位置判斷。位置也不可靠就全部用 normal。
7. `red` 只給破壞性動作（清空、刪除、還原預設）跟關閉鈕 ×。「取消」不是破壞性動作，用 normal。
8. **主按鈕不要再疊發光或彩色字**。發光原本在講「這顆可以按」，primary 平時就帶職業色，兩個訊號疊在一起只會變吵；字裡的色碼還會蓋掉停用時的灰字。
9. **動作已經做過、再按沒有意義時：字直接改成現況、按鈕停用**（「加入一鍵購買清單」→「已在清單中」）。停用的 primary 自己退回中性，「能不能按」跟「做過沒」就是同一個訊號。
   提示裡只留現況數據，「點一下會…」這類操作說明在停用時一律不列。
10. **開／關型的單顆按鈕：開＝primary、關＝normal，狀態只換明暗**（本體 `Enhance/AuctionHouseFilter.lua` 拍賣行「僅限當前資料片」，2026-09-24）。
    2026-09-24 試過在選中態字前加職業色勾勾，同日 revert（`ed0c3cca5`→`f0e729b42`，理由沒留下）——選中態不另加記號，就靠 primary／normal 的差。

## 按鈕文字

- 結尾不加「…」／「...」，見 [[feedback-button-no-ellipsis]]。

## 實作入口

- **自製插件**：`W.CreateButton(parent, text, "primary", w, h)`（共用層 `AddOns/MiliUI/Libs/MiliUIWidgets/Widgets.lua`，改完跑 `sync-widgets.py`）。
  - 配色表的形狀是 `{ 平時底, 滑過底, 平時邊, 滑過邊 }`。有第 3、4 格才會換邊色、停用時退回中性，只有兩格的舊配色行為完全沒變。
  - ⚠ 自己 `SetScript("OnEnter"/"OnLeave")` 的（掛工具提示、列高亮）要叫 `W.PaintButton(self, hover)`，**不要自己 `unpack(self._colors[2])`**，否則只換得到底，邊會卡在上一個狀態。
  - 啟停（`SetEnabled`／`Enable`／`Disable`）已內建重畫：停用中的按鈕收不到 OnEnter/OnLeave，滑過時被停用、移開、再啟用，只靠滑鼠腳本會卡在滑過的顏色上。
  - **`W.SetButtonVariant(btn, "primary"|"normal")`**（2026-10-05）：執行期切換配色，給「狀態跟著設定走」的按鈕（MCDM 預覽效果列：啟用＝primary）。
- **暴雪視窗**：MiliUI_Skin 的 `Skin.Button{ variant = "primary"|"secondary" }`，以及 `T.ButtonPalette`。零腳本的特許按鈕走 `Engine.ScriptlessButton`。細節在 `AddOns/MiliUI_Skin/STYLE.md` ④「按鈕的兩種變體」。
- ⚠ **數字寫在兩個地方**：`Widgets.lua` 的 `BTN_TEXT_LUM`／`BTN_IDLE_SCALE`／`BTN_BORDER_SCALE`（0.40／0.30／0.60），跟 `MiliUI_Skin/Core/Tokens.lua` 的 `buttonTextLum`／`buttonIdleScale`／`buttonBorderScale`。
  插件是單體發佈的，不能互相讀，**要改就兩邊一起改**。
- Cell 的 `CreateButton` 是它自己的函式庫（第三方分支），不在這條規則內。

## 舊配色：新程式碼不要再用（遷移待辦；2026-10-14 以 `grep -rl 'CreateButton([^)]*"green"'` 重盤）

- **`accent`**（職業色 alpha 0.3 的底、黑邊）：半透明底，而且沒有邊色訊號。還在用的：三份 `Tab_Share`（UnitFrames／DamageMeters／Tooltip）、UnitFrames 的 `HealthThresholds`／`AuraBlacklist`、
  BurstPotionHelper `Tab_List`、BloodlustMusic `Tab_Tracks`／`Tab_Bar`、本體 `Tab_Addons`／`Tab_Import`／`Tab_Perf`，以及共用層 `CreateChoicePopup` 的預設色。
- **`green`**（確認、匯入並重載、套用並重載）：都是「確認／執行」，應該改成 primary。還在用的：本體 `Tab_Addons`、三份 `Tab_Share`、CharacterNotes `Share.lua`、BossTimeline `BossPicker.lua`，
  以及共用層自己的 `W.CreateConfirmPopup`／`W.CreateInputPopup`（「確定」是 green、「取消」是 red，應分別改成 primary 跟 normal）。**這一條會一次改到所有插件的彈窗，動手前先問使用者。**
- **`accent-hover` 當成單顆動作鈕用的**：改成 primary。分頁（`W.CreateButtonGroup`）維持原樣。
- **normal 的滑過**：共用層只把底提亮到 0.23、邊維持黑；Skin 的 secondary 另外亮職業色邊。兩邊還沒統一，要統一的話會改到全部插件的 normal 按鈕。

## 已套用（以 `grep -rl '"primary"' AddOns --include='*.lua' | grep -v Libs` 為準）

- MiliUI_ShoppingList（2026-09-22）：每列「購買」、底部「全部購買」、確認列的「確認」與「購買」用 primary；搜尋、搜尋全部、清除已齊、取消、跳過用 normal；清空清單跟關閉用 red。
  專業視窗上的「加入一鍵購買清單」改成 primary、發光與金色碼拿掉、已在清單裡就寫「已在清單中」並停用（判準 9）。
- 本體：拍賣行「僅限當前資料片」（判準 10）、星雲之核擲骰確認框、插件總覽的「進入除錯模式」（normal）。
- MiliUI_Merchant 批量購買、MiliUI_MythicPlus 鑰石面板、MiliUI_CooldownManager（預覽效果列用 SetButtonVariant）、MiliUI_BossTimeline 各面板。
- MiliUI_Skin 換皮的暴雪視窗（第九輪起）。

相關：[[project-miliui-skin]]、[[project-miliui-widgets-vendor]]、[[project-miliui-shoppinglist]]、[[feedback-ui-visual-style]]、[[project-miliui-hud-skin]]
