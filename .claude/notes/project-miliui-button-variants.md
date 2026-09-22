---
name: project-miliui-button-variants
description: 全套組按鈕上色規則——primary（主動作）／normal（其餘）兩種長相、職業色公式、判準、實作入口與舊配色待辦；所有自製插件與 MiliUI_Skin 換皮都要遵守
metadata: 
  node_type: memory
  type: project
  originSessionId: 71bbf8e9-54dc-4f24-a23c-4d295b4f2cac
  modified: 2026-09-22T03:56:34.886Z
---

**全套組的文字按鈕只有兩種長相。** 自製插件（`MiliUI`、`MiliUI_*`）用 `W.CreateButton`
畫的按鈕，跟 MiliUI_Skin 換過皮的暴雪視窗按鈕，一律照這套走。
（2026-09-22 使用者原話：「這種按鈕上色邏輯與方法寫到筆記內，整個 Interface 插件都需要遵守」。
起因是採購清單的「購買」鈕要「取 MiliUI_Skin 按鈕的職業色搭法，要職業色不要固定藍色」。）

**Why:** Skin 第九輪時使用者說過「目前設計有時候不知道他是按鈕」。平時跟面板同一個 0.115 底的按鈕，
在一片深灰裡只剩一圈黑邊可以認。主動作要自己帶顏色，而且整個套組要是同一顆按鈕。

**How to apply:** 新按鈕先照下面的判準決定是 primary 還是 normal，再挑 colorKey。
**顏色一律從職業色（`Accent()`）推導。** 不要照擷圖挑一個色寫死：使用者的參考擷圖是薩滿，
所以看起來是藍色，換一隻角色就不是了。

## 兩種長相

| 狀態 | **primary** | **normal**（Skin 叫 secondary） |
|---|---|---|
| 平時 | 底＝保護色 × 0.30、1px 邊＝職業色 × 0.60 | 底 0.115、黑邊 |
| 滑過 | 底＝保護色、邊＝職業色（全亮） | 底提亮到 0.23（Skin 另外亮職業色邊，見待辦） |
| 按下 | 沒有底色變化（字往下 1px） | 同左 |
| 停用 | **退回中性**：0.115 底、黑邊、灰字 0.4。停用的按鈕不能看起來像能按 | 平時的底＋灰字 |
| 文字 | 白 | 白 |

**保護色**＝職業色 × k，`k = min(1, 0.40 / lum)`，`lum = 0.299r + 0.587g + 0.114b`。
白字壓在職業色上時，牧師（白）跟盜賊（亮黃）會讀不到，所以依亮度壓暗。
深色職業（死騎、薩滿、惡魔獵人）的 k = 1，顏色不變。
為什麼門檻是 0.40 而不是 0.50：拿十三個職業算過 WCAG 對比，0.50 會把十個職業壓成泥色。
完整推導在 `AddOns/MiliUI_Skin/STYLE.md` ② 的 `buttonTextLum`。

底色是算出來的**不透明純色**，不是用 alpha 疊在背景上（[[feedback-ui-visual-style]]、
`miliui-color-states` 技能第三條）。

## 判準：哪一顆是 primary

1. 成對或成組時，「確認／執行」那顆用 primary。「取消／返回／拒絕／跳過」用 normal。
2. 只有一顆時用 primary。例外是它本身就是「返回／再見」。
3. 一整排平行選項（分頁、切換檢視、欄位表頭、每列只有一顆的「載入」）全部用 normal。
   ⚠ **例外：每一列都有、而且在列裡跟次要按鈕成對的主動作**。採購清單每列是「搜尋｜購買」，
   購買用 primary（2026-09-22 使用者指定）。它多半時候是停用的（拍賣場沒開、或這樣已經買齊），
   所以平常整欄是中性的，只有真的還能買的那幾列會亮起來，反而成了資訊。
4. 一個區塊最多一顆 primary。例如「搜尋全部＋全部購買」只有全部購買是 primary；
   「製作＋全部製作」只有製作是 primary。
5. 會開選單的按鈕、可收合的清單標題用 normal。它們不是動作。
6. 讀不出是哪一顆時照位置判斷。位置也不可靠就全部用 normal。
7. `red` 只給破壞性動作（清空、刪除、還原預設）跟關閉鈕 ×。「取消」不是破壞性動作，用 normal。
8. **主按鈕不要再疊發光或彩色字**（2026-09-22，「加入一鍵購買清單」拿掉發光時定的）。
   發光原本是在講「這顆可以按」，primary 平時就帶職業色，已經在講同一件事，兩個訊號疊在一起只會變吵。
   字裡的色碼還會蓋掉停用時的灰字。
9. **動作已經做過、再按沒有意義時：字直接改成現況、按鈕停用**（2026-09-22，「加入一鍵購買清單」→「已在清單中」）。
   停用的 primary 自己退回中性，「能不能按」跟「做過沒」就是同一個訊號。不要留著能按、再用工具提示解釋
   「重按會怎樣」—— 使用者原話「這樣不用解釋重複加入清單的話 blablabla 了」。提示裡只留現況數據
   （清單裡幾份、還缺幾樣），「點一下會…」這類操作說明在停用時一律不列。

## 實作入口

- **自製插件**：`W.CreateButton(parent, text, "primary", w, h)`。這是共用層
  `AddOns/MiliUI/Libs/MiliUIWidgets/Widgets.lua` 在 2026-09-22 加的，改完跑 `sync-widgets.py`。
  - 配色表的形狀是 `{ 平時底, 滑過底, 平時邊, 滑過邊 }`。有第 3、4 格才會換邊色、停用時退回中性，
    只有兩格的舊配色行為完全沒變。
  - ⚠ 自己 `SetScript("OnEnter"/"OnLeave")` 的（掛工具提示、列高亮）要叫 `W.PaintButton(self, hover)`，
    **不要自己 `unpack(self._colors[2])`**，否則只換得到底，邊會卡在上一個狀態。
  - 啟停（`SetEnabled`／`Enable`／`Disable`）已經內建重畫。原因是停用中的按鈕預設收不到
    OnEnter/OnLeave：滑過時被停用、移開、再啟用，只靠滑鼠腳本的話會卡在滑過的顏色上。
- **暴雪視窗**：MiliUI_Skin 的 `Skin.Button{ variant = "primary"|"secondary" }`，以及
  `T.ButtonPalette`。零腳本的特許按鈕（彈窗、拍賣場／專業的受保護請求）走
  `Engine.ScriptlessButton`。細節在 `AddOns/MiliUI_Skin/STYLE.md` ④「按鈕的兩種變體」。
- ⚠ **數字寫在兩個地方**：`Widgets.lua` 的 `BTN_TEXT_LUM`／`BTN_IDLE_SCALE`／`BTN_BORDER_SCALE`，
  跟 `MiliUI_Skin/Core/Tokens.lua` 的 `buttonTextLum`／`buttonIdleScale`／`buttonBorderScale`。
  插件是單體發佈的，不能互相讀，**要改就兩邊一起改**。
- Cell 的 `CreateButton` 是它自己的函式庫（第三方分支），不在這條規則內。

## 舊配色：新程式碼不要再用（遷移待辦，2026-09-22 盤點）

- **`accent`**（職業色 alpha 0.3 的底、黑邊）：半透明底，而且沒有邊色訊號。
  用在 UnitFrames／DamageMeters 的 `Tab_Share`（新增、複製、產生匯出字串）、UnitFrames 的
  `HealthThresholds`／`AuraBlacklist`、BurstPotionHelper 的 `Tab_List`、MiliUI 本體的
  `Tab_Import`／`Tab_Addons`／`Tab_Perf`，以及共用層 `CreateChoicePopup` 的預設色。
- **`green`**（確認、匯入並重載、套用並重載）：這些都是「確認／執行」，應該改成 primary。
  也包括共用層自己的 `W.CreateConfirmPopup`／`W.CreateInputPopup`：
  「確定」是 green、「取消」是 red，應該分別改成 primary 跟 normal。
  **這一條會一次改到所有插件的彈窗**，動手前先問使用者。
- **`accent-hover` 當成單顆動作鈕用的**：改成 primary。分頁（`W.CreateButtonGroup`）維持原樣。
- **normal 的滑過**：共用層只把底提亮到 0.23、邊維持黑；Skin 的 secondary 另外亮職業色邊。
  兩邊還沒統一，要統一的話會改到全部插件的 normal 按鈕。

## 已套用

- MiliUI_ShoppingList（2026-09-22，**待實機驗證**）：用 primary 的是每列「購買」、底部「全部購買」、
  確認列的「確認」與「購買」。用 normal 的是搜尋、搜尋全部、清除已齊、取消、跳過。
  用 red 的是清空清單跟關閉。
  同一天，專業視窗上的「加入一鍵購買清單」也改成 primary（使用者指定）：**發光拿掉、字的金色碼拿掉**；
  已在清單裡就寫「已在清單中」並停用（判準 9）。
- MiliUI_Skin 換皮的暴雪視窗（第九輪，未實測）。

相關：[[project-miliui-skin]]、[[project-miliui-widgets-vendor]]、[[project-miliui-shoppinglist]]、
[[feedback-ui-visual-style]]。
