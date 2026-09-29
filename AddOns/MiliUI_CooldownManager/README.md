# 米利的冷卻管理器 MiliUI_CooldownManager

接手暴雪 12.1 冷卻管理器的四條檢視器（核心技能、輔助技能、增益圖示、增益長條），
重新排版、換樣式、加文字與發光，外加自訂群組、追蹤項目、資源條與施法條。
設定視窗 `/mcdm`（或 `/miliuicdm`、小地圖按鈕、插件選單）。

## 第一次啟用（給玩家）

1. **停用舊的冷卻管理器插件**（插件清單裡的 `Ayije_CDM` 與 `Ayije_CDM_Options`）。兩支都開著的話，登入時本插件會跳出視窗，
   按「停用 … 並重新載入」就是這一步。
2. `/reload`。
3. 要用套組調好的樣子：`/miliui` →「預設值匯入」→ 匯入 `MiliUI_CooldownManager` 再 `/reload`；
   不匯入也可以，本插件自己的內建預設值就能直接用。
4. 進**編輯模式**（Esc → 編輯模式）拖四條檢視器、資源條、施法條擺位置；細節在 `/mcdm` 設定視窗裡調。
5. 單位框架的資源條與征戰聖擊助手不用另外設定：預設就會改跟本插件（單位框架那邊取消「跟隨冷卻管理器的顏色」就改用自己的）。

## 現況

> **第一版完成，待實機驗證。** 四條暴雪檢視器認領重錨到自己的容器上（版面、兩列尺寸、固定格位、長條、
> 邊框／縮放／轉圈色／文字樣式、顯示條件）；編輯模式裡每條都拖得動；設定視窗每條一頁（預覽即編輯器＋表單）、
> 主題、設定檔（含匯出匯入）、自訂群組；自訂項目（光環格、自訂法術／物品冷卻）、觸發／就緒發光、無損刷新、
> 按鍵文字；資源條與玩家施法條；套組裡的單位框架、征戰聖擊助手、本體設定頁都認得本插件。
> 程式裡沒有實機跑過的假設全部列在最後的「待實機驗證」。
> `/mcdm debug` 印引擎與編輯模式現況，`/mcdm aura` 印每個光環格的保護狀態與最近錯誤，
> `/mcdm release` 把冷卻管理器還給暴雪（除錯用，/reload 接回來）。

⚠ 跟另一支同樣接管冷卻管理器的插件**不能同時啟用**：偵測到時登入會跳出視窗二選一，
本插件在那次登入裡什麼都不做。

## 架構

一支單體發佈的插件，共用層全部 vendor 在 `Libs/`（`MiliUIWidgets` 設定介面、`MiliUIGlow`
發光、`MiliUISnap` 磁吸），唯一 source 在 MiliUI 本體，改了跑
`python3 .claude/scripts/sync-widgets.py` 同步；只有 `Libs/MiliUIWidgets/Env.lua` 是本插件自己的。

| 位置 | 內容 |
|---|---|
| `Core/Init.lua` | 命名空間、`ns.Guard`（掛勾的 xpcall 包裝）、`ns.Defer`（下一幀）、`ns.Write`（容器層寫入的唯一出口：戰鬥中碰保護框就記帳、脫戰補做）、事件註冊表、互斥偵測、登入流程 |
| `Core/DB.lua` | 預設值（套組現值）、遷移鏈、設定檔／專精綁定、`ns.Setting`／`ns.SpellSetting` |
| `Core/Media.lua` | 字型／材質 token → 路徑（LibSharedMedia 可選） |
| `Core/Style.lua` | HUD 皮數值與職業色強調色 |
| `Options/` | 700×520 設定視窗、左欄導覽、條頁／主題頁／設定檔頁、預覽、逐法術面板、點擊層、暴雪選項入口頁、小地圖按鈕（見「設定介面」） |
| `Core/Catalog.lua` ～ `Core/Visibility.lua`、`Core/Glow.lua`、`Core/Keybinds.lua`、`Modules/Custom.lua` | 引擎，見下一節 |
| `Modules/Resources.lua`、`Modules/ResourceConditions.lua`、`Modules/Castbar.lua`、`Modules/Interrupt.lua` | 資源條、條件規則求值（純邏輯）、玩家施法條、斷法就緒，見「資源條與施法條」 |
| `EditMode/` | 編輯模式整合：`Geometry.lua`（純函式：放手位置換算回 pos、格線吸附）、`Frames.lua`（覆蓋層、選取框、暴雪 Selection 接線）、`EditMode.lua`（拖曳、進出訊號、暴雪設定對話框） |
| `Api.lua` | slash（含 `/mcdm debug`、`/mcdm aura`、`/mcdm release`）、插件選單、公開 API `MiliUI_CooldownManager`（見「公開 API」） |
| `Tests/` | 離線測試，不進 TOC：`DB_test.lua`、`Layout_test.lua`、`Catalog_test.lua`、`EditMode_test.lua`、`Settings_test.lua`（設定介面的寫入路徑與匯出匯入）、`Custom_test.lua`（自訂項目的新增／刪除挪 id／清單排序與固定前綴）、`Keybinds_test.lua`（按鍵縮寫、動作條格 → 綁定指令）、`Resources_test.lua`（條件規則求值、資源清單依專精、法力縮寫、面板的 DB 與顯示條件、施法條的時間文字／截字／刻度查表），用 `lua AddOns/MiliUI_CooldownManager/Tests/<名字>` 直接跑 |

套組裡哪些插件認得本插件、透過哪支 API：見「套組接線」。

引擎的硬規則（對暴雪框不 SetParent／不 Hide、不寫暴雪框的欄位、只後掛勾、秘密值只當傳遞者…）
寫在實作計畫的「引擎契約」一節，動 `Core/` 之前先看。

## 引擎

| 檔案 | 職責 |
|---|---|
| `Core/Catalog.lua` | cooldownID → 法術資料；四條檢視器各自的有序清單。玩家在暴雪面板排的順序自己解 `C_CooldownViewer.GetLayoutData()`（不問暴雪的 DataProvider，那會寫它的快取欄位）；解不開就無感退回類別集合順序。`Bar(key)` 回套好本專精 `order`／`groupOf`／`hidden` 的清單。暴雪設定面板開著時 `IsPaused()`；`CheckFresh` 輪詢版面字串最多每秒一次 |
| `Core/Layout.lua` | 純函式 `Compute(items, layout, kind)` → 每格 (x, y, w, h)、容器寬高、容器錨點。不碰任何 WoW API，離線可測 |
| `Core/Viewers.lua` | 四條暴雪檢視器的後掛勾與 item 追蹤（弱鍵表 `frames[item]`）。登入退避重試等檢視器與 `CooldownViewerSettings`；戰鬥外一次把 `cooldownViewerEnabled` 打開；item 的縮放鎖 1 |
| `Core/Bars.lua` | 一條一個容器 `MiliUICDM_Bar_<key>`，錨定（pos 或錨在別條上）、重排排程、停放、固定格位的占位貼圖、把暴雪檢視器本體釘在容器上；`ReleaseAll` 全部還給暴雪 |
| `Core/Decorate.lua` | 邊框（自己的 overlay 框上）、圖示縮放、轉圈色、GCD 轉圈、去飽和、長條外觀；每 item 一個簽章，同簽章跳過 |
| `Core/Text.lua` | 倒數／充能／層數：改暴雪自己那幾顆 FontString 的樣式，從不寫字（為什麼見檔頭） |
| `Core/Visibility.lua` | 顯示條件與淡出，一律 `SetAlpha`；容器與每個認領中的 item 一起套（自訂項目的框是容器的子框，跟著容器的 alpha） |
| `Core/Glow.lua` | 觸發發光接管（`ActionButtonSpellAlertManager` 後掛勾）、就緒發光（探針）、無損刷新邊框色；發光一律畫在 overlay 底下自己的宿主框上 |
| `Core/Keybinds.lua` | 法術／物品 → 動作條格 → 綁定鍵 → 縮寫，畫在 overlay 一角 |
| `Modules/Custom.lua` | 自訂項目：光環格（持有框＋AuraContainer）、自訂法術／物品的圖示框；每一格都是 Bars 的一個 entry |

登入流程：`PLAYER_LOGIN` → DB → `Loaded` → Catalog → Viewers → Custom → Glow → Keybinds → Bars
→ Interrupt → Resources → Castbar → Visibility（`Core/Init.lua` 的 `ns.StartEngine`）。
換設定檔／專精：清樣式簽章、重讀目錄、全部重排、重套 alpha，不需要 /reload。
任何一步 `Init` 拋錯 ⇒ `ns.EngineFailed`：`Bars.ReleaseAll` 把冷卻管理器還給暴雪，聊天框印一行。

### 訊號流

```
暴雪：取出 item／RefreshLayout／Layout／SetCooldownID／ClearCooldownID／光環上下
  └─ Viewers 的後掛勾（ns.Guard）：更新弱鍵表上的身分，丟訊號
       ├─ Layout 後掛勾：當場用上次的格子快取把 item 放回去（Bars.Reapply，不重算，避免閃一幀）
       └─ Bars.RequestSource → 受影響的條標髒（取最高等級）：來源條、認領著它的 item 的條、
            從它拉法術的條（groupOf）；設定變了才 RequestAll
            └─ 排程：同一幀合併成一次 C_Timer.After(0)；兩次排版至少隔 0.1 秒
                 └─ Flush（暴雪設定面板開著就等它關）
                      Catalog.CheckFresh（最多每秒讀一次版面字串）→ 每條：Catalog.Bar ∩ 作用中的 item → Layout.Compute
                      → item ClearAllPoints＋SetPoint(TOPLEFT, 容器, x, -y)＋SetSize → Decorate.Apply
                      → 沒被認領的 item 停到畫面外（alpha 0、錨 UIParent (-10000, 10000)）
                      → Visibility.ApplyAll
```

### 髒標記三級

| 等級 | 內容 | 戰鬥中 |
|---|---|---|
| membership | 哪些 item 在哪條（清單、收合、隱藏） | 照做 |
| layout | 格位座標（設定值變了） | 照做 |
| structure | 容器的錨點、strata、顯示 | **記帳**，`PLAYER_REGEN_ENABLED` 補做 |

前兩級做的事其實一樣（重取清單很便宜），分開只為了讓呼叫端講清楚意圖。item 不是保護框，
戰鬥中照樣 SetPoint；容器層的 SetPoint／SetSize／Show／Hide 一律走 `ns.Write`。

## 編輯模式

進暴雪的編輯模式，每條容器上蓋一層**自己的覆蓋層**（1px 職業色邊、左上角條名、右上角齒輪、
需要時一行黃字提示），底下是藍色選取框，拖選取框就是拖整條。

| 條 | 選取框 | 拖的是什麼 |
|---|---|---|
| 四條暴雪檢視器 | 暴雪自己的 `viewer.Selection`（編輯模式勾了「冷卻管理器」才顯示）；沒顯示時改用我們自己的 | 我們的**容器**（檢視器本體釘在容器上，跟著走） |
| 自訂條 | 自己借 `EditModeSystemSelectionTemplate` 建的（容器一建好就建、`pcall`＋自畫藍框備援、`OnMouseDown` no-op） | 容器 |

- **拖曳**：手動游標差值（不用 `StartMoving`）。放手時把容器**錨點那一邊**（`Bars.AnchorPoint(key)`，
  版面算出來的 TOP／BOTTOMLEFT…）換算回 `bars[key].pos = { point = 原本的 pos.point, x, y }`
  （`EditMode.ReadPos`，`Tests/EditMode_test.lua` 覆蓋六種錨點 × CENTER／BOTTOM），
  `SetUserPlaced(false)`，排結構級重排讓 `ApplyStructure` 照存檔重貼。拖曳中 `ns.dragging = key`，
  重排與 `PinViewer` 跳過那條；放手、離開編輯模式、進戰鬥一律清掉。
  放手後廣播 `BarMoved(key)`（之後的設定頁用）。
- **吸附**：暴雪編輯模式的「吸附」開關與格線間距，Shift 反轉；只吸容器的錨點那一邊。
  放手時再走 MiliUISnap 跟套組其他框對齊（`cdm:<key>`，只做 align、同組互不對齊）。
- **拖了就脫離錨定**：錨在別條上的條（`anchor` 是表）一開始拖就把現況換算成 pos、`anchor = false`。
  進編輯模式時這種條會先蓋一行黃字「拖曳會解除跟隨「核心技能」」，放手後消失。
- **暴雪的系統設定對話框**：點到四條檢視器時藏掉（它的尺寸／方向／間距跟我們的設定不同步）。
  **不 Hide**（Hide 會從我們的執行跑暴雪的 OnHide、寫 `attachedToSystem`）：後掛勾 `AttachToSystemFrame`
  當場 `SetAlpha(0)`＋`EnableMouse(false)`，對話框與每個吃滑鼠／滾輪的子孫都關、記下來；下一次
  `AttachToSystemFrame` 的系統不是四條之一、或離開編輯模式時照記錄還回去。第一次藏時聊天框印一行
  「冷卻管理器的設定在 /mcdm，或點藍框右上角的齒輪」。對話框的內容、欄位與 `Settings` 列不碰。
- **齒輪**：`Options.FocusBar(key)`。設定視窗是 DIALOG strata、開窗時 `Raise()`，蓋得過編輯模式的面板。
  自訂群組也開得到自己的頁面（`Options.SyncBarPages` 先登記）。
- **編輯模式裡每條全亮**：顯示條件（沒目標淡出、騎乘隱藏…）在編輯模式中不生效，離開後恢復。
- **空條**：沒 buff 的條容器可能只有 1×1，覆蓋層與選取框至少一格（`layout.size`）大，照樣拖得動；
  樣板內容（假圖示）留給 D／E 階段的預覽。
- **進出訊號**：三重（管理視窗 OnShow/OnHide、`EnterEditMode`／`ExitEditMode` 後掛勾、
  `EventRegistry` 的 `EditMode.Enter`／`Exit`），全部冪等，處理器只改旗標、工作延一幀；
  再加暴雪「冷卻管理器」勾選框的 `RefreshCooldownViewer` 後掛勾（決定四條用哪個選取框）。
  覆蓋層／選取框的顯示收起走 `ns.Write`（容器在保護鏈上就記帳，脫戰照**當下**狀態重跑）。
  進戰鬥那一刻（`PLAYER_REGEN_DISABLED`，鎖定還沒生效）拖曳中就當場收掉、容器放回存檔位置、不寫 db。

### 為什麼暴雪的 Selection 用 SetScript

引擎契約是「只後掛勾」。唯一例外是四條檢視器 `Selection` 的 `OnDragStart`／`OnDragStop`：
暴雪原本的腳本會叫系統框自己 `StartMoving`，放手後把位置寫進暴雪的編輯模式版面。後掛勾只能多做、
不能讓它不做——讓它做了，檢視器會被拖離容器、位置進暴雪版面，下一幀又被 `PinViewer` 釘回來。
所以整條換掉，改拖容器。`OnMouseDown`（暴雪的 `SelectSystem`）不動。
暴雪 Selection 上**其他**東西一律不碰：不呼叫它的 `ShowHighlighted`／`Hide`（會寫它的欄位），
只 `SetAllPoints` 到覆蓋層。

## 設定介面

`/mcdm` 開 700×520 的設定視窗。左欄：條（四條檢視器＋自訂群組＋「＋ 新增群組」）、資源條、施法條、
全域（主題／設定檔／關於）。**所有選項即時生效，沒有一個要 /reload。**

| 檔案 | 內容 |
|---|---|
| `Options/Panel.lua` | 視窗殼、頁面登記（懶建、頁面快取不丟）、`SyncBarPages`（自訂群組跟著設定檔登記頁面）、`ApplyEngine`（真實條 0.2 秒合併套用）、換設定檔／專精時重讀目前那頁 |
| `Options/Sidebar.lua` | 左欄（自訂群組多時滾輪捲）、新增群組（選類型→取名）、右鍵改名／刪除、預覽拖曳的放置目標 |
| `Options/Specs.lua` | 表單規格（版面／圖示／文字／效果／顯示條件／錨定）與接線：ctx、跟隨遮罩、右鍵重設、覆寫數 |
| `Options/Tab_Bar.lua` | 一條一頁（四條檢視器與自訂群組共用）：標題列、預覽、說明、表單；開暴雪面板 |
| `Options/Preview.lua` | 預覽即編輯器（見下） |
| `Options/Picker.lua` | 預覽最右邊「＋」的挑選器 |
| `Options/SpellPopover.lua` | 逐法術面板 |
| `Options/Tab_Theme.lua` | 全域主題（跟條頁同一支 builder） |
| `Options/Tab_Profile.lua` | 設定檔：切換／新增／複製／改名／刪除／恢復預設、依專精切換、匯出／匯入（審閱後建成新的一份） |
| `Options/Tab_Resources.lua`、`Options/ResourceConditions.lua` | 資源條頁與它的條件規則編輯器 |
| `Options/Tab_Castbar.lua` | 施法條頁（頁首「預覽」） |
| `Options/ClickLayer.lua` | 視窗開著時畫面上每條蓋一層透明點擊層，點了切到那條的頁面並閃職業色邊 |

### 條的頁面

- **預覽即編輯器**：自己的假框、真實尺寸（`ns.Layout.Compute`），外觀走 `ns.Decorate.ApplyPreview`
  （跟真實條同一套邊框／縮放／轉圈色／文字樣式，簽章函式共用）。奇數格冷卻中（轉圈、「15」、去飽和），
  技能印充能「2」、增益印層數「2」；長條跑十五秒循環。太寬水平捲動、太高垂直捲動（上限 170）。
  - 左鍵：逐法術面板。中鍵：隱藏（`spells[spec].hidden`），隱藏的排在尾端 alpha 0.35、點一下還原。
  - 拖曳（3px 門檻）：職業色插入線、其他格變暗 0.5，放手寫 `spells[spec].order[key]`（完整清單）；
    拖到左欄的自訂群組上＝`groupOf`，拖回原本的檢視器上＝清 `groupOf`（可放的按鈕亮職業色邊）。
    長條只能拖進長條群組、圖示只能進圖示群組。`cell.locked`（光環格的固定前綴）蓋紅色、拖不動、別的格也不能插到它前面。自訂項目拖到左欄任何圖示條上＝改它的 bar。
  - 「＋」：挑選器（已在暴雪冷卻管理器的別條項目，點了拉進來；要先去暴雪面板加的候選池＋開面板鈕；
    自訂 ID：光環格／法術／物品，見「自訂項目與效果」）。暴雪面板開著時整個鎖住，`CatalogResumed` 自動重讀。
- **表單**：版面（每列上限、間距、成長方向、圖示尺寸、第二列尺寸、固定格位／長條的寬高圖示材質顏色）、
  圖示、文字、效果（含淡出）、顯示條件、錨定。圖示／文字／效果／淡出各有「跟隨全域主題」：勾著時整節蓋
  半透明遮罩、顯示的是主題的值。標題右側「本條 N 個法術有覆寫［清除覆寫］」。每一列的標籤右鍵
  「重設為預設」（條上的主題欄位＝清掉、回到跟主題；條自己的欄位＝預設值／自訂群組的預設）。
- **套用兩層**：值寫進去的當下只重畫預覽；真實條（`Decorate.InvalidateAll`＋`Bars.RequestAll("structure")`
  ＋`Visibility.ApplyAll`）合併 0.2 秒一次。滑桿拖動由共用層再合併成 0.05 秒一次。
- **表單照形狀快取**（第二列尺寸開關、有沒有錨定、條清單）：有列要出現／消失時換一份表單，
  變回來就拿舊的（frame 刪不掉，不能每次重建）。

### 寫入路徑

條頁的主題欄位**讀**繼承後的值（`ns.Setting`），**寫**進條自己的子表（`DB.OwnSet`，照 `THEMED` 決定
子表）。顏色若直接回主題那張表，色票會就地改掉主題 —— 所以條頁的主題顏色回代理表：讀照繼承、
第一次寫才複製進條自己的子表。自訂群組、覆寫、設定檔改名／匯入、匯出字串都在 `Core/DB.lua`
（`CreateBar`／`DeleteBar`／`SetOverride`／`CountOverrides`／`RenameProfile`／`ImportProfile`／
`EncodeProfile`／`DecodeProfileString`），`Tests/Settings_test.lua` 全部覆蓋。

## 自訂項目與效果

### 自訂項目（`Modules/Custom.lua`）

資料在 `spells[specID].custom`（逐專精），一筆 `{ kind, spellID|itemID, filter, placeholder, bar }`，
在順序／隱藏／覆寫裡的 id 是 `"c:<index>"`。挑選器（預覽最右邊的「＋」）的「自訂 ID」區三顆鈕：
**光環**（輸入 ID → 選增益／減益）、**法術**、**物品**；驗證 `C_Spell.GetSpellInfo`／`C_Item.GetItemInfoInstant`，
同專精不收重複。只有圖示類的條收自訂項目。

| 種類 | 框 | 冷卻／顯示 | 秘密值下 |
|---|---|---|---|
| 光環格 `aura` | **持有框**（自己的 Frame，parent 條容器，一個 spellID＋filter 一顆、永不改用）＋底下一顆 `AuraContainer`（`AddAuraSlot`＋`includeSpellIDs`、unit player） | 暴雪自己畫圖示、倒數、層數；樣式在 `initializeFrame` 裡烘 | 插件零讀取，照常 |
| 法術 `spell` | 自己的圖示框（`.Icon`／`.Cooldown`／`.ChargeCount.Current`，跟暴雪 item 同形狀，`Decorate.Apply` 同一套樣式） | `C_Spell.GetSpellCooldownDuration(id, ignoreGCD)` 的 duration 物件；回充另一顆只畫邊緣的 Cooldown；去飽和走 `EvaluateRemainingDuration(階梯曲線)` → `SetDesaturation` | 引擎給的 duration 物件照用；充能數字秘密時走 `C_StringUtil.TruncateWhenZero` |
| 物品 `item` | 同上 | `C_Item.GetItemCooldown` 明文才建 duration（`SetTimeFromStart`）；數量 `GetItemCount` 寫在充能位置，0 去飽和 | 讀不到就不動（已經 arm 的由引擎繼續跑） |

光環格的硬規則（每條都是 12.1 限制推出來的，細節在檔頭）：

- **固定前綴**：光環格永遠排在該條最前面（`Catalog.Bar` 最後一步），預覽裡鎖住（紅色、拖不動、不能插到它前面）。
  條上有光環格時**固定格位強制打開**（`layout.fixedSlots` 的值不動；設定頁那一列停用並寫原因）——
  其他增益收合也不會讓光環格的 x 變，戰鬥中不必動持有框。
- **持有框整條鏈是保護框**：持有框的 SetParent／SetPoint／SetSize／Show／Hide 一律走 `ns.Write`
  （戰鬥中記帳、脫戰補做）；條容器本來就走 `ns.Write`。
- **簽章池**：影響外觀的設定（邊框、縮放、轉圈色、字型／字級／顏色／錨點、倒數小數與低秒變色、
  隱藏倒數／層數覆寫）進簽章；變了換一顆容器，舊的 Hide 留在池子裡，改回來直接拿回去。
  尺寸不進簽章（按鈕 `SetAllPoints` 到容器、容器 `SetAllPoints` 到持有框，跟著走）。
- **戰鬥中不建容器**（會不可攔截地報錯）：記旗標，`PLAYER_REGEN_ENABLED` 再建；占位圖示先頂著。
- `initializeFrame` 整段 `xpcall`、不 `CreateColor`、不掛 script；formatter 與低秒變色的色彩曲線在建容器前先建好。
- 持有框 `OnShow`（`ns.Defer`）時戰鬥外補踢容器（Hide→Show→SetEnabled），戰鬥中記旗標。
- 減益只收 `C_Secrets.GetSpellAuraSecrecy(id) == NeverSecret`（新增時就擋並說明）。
- 光環格不提供發光（不知道光環在不在）。

逐法術面板對自訂項目：「所在條」改的是它自己的 bar（任何圖示類的條）；光環格藏掉觸發／就緒發光與去飽和、
多一列「不在時顯示占位」、沒有「隱藏此法術」；自訂項目多一顆紅色「移除此項目」（確認後刪，後面的 id 往前挪：
`DB.RemoveCustom` 同步改順序、隱藏、覆寫）。刪自訂群組時，上面的光環格回增益圖示、法術／物品回核心技能。
未學會的自訂法術顯示問號（預覽、挑選器、真實條都是），滑鼠提示寫「尚未學會」。

### 效果（`Core/Glow.lua`、`Core/Keybinds.lua`）

- **觸發發光**：後掛勾 `ActionButtonSpellAlertManager:ShowAlert／HideAlert`，frame 是我們認得的 item 就在 overlay
  上畫 MiliUIGlow（pixel／autocast／button／proc），暴雪的 `SpellActivationAlert` 熄 alpha（不 Hide）。
  條層「觸發發光」開著（或法術覆寫成開）才接管；都關時還給暴雪。自訂法術聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE`。
- **就緒發光**：探針（見「與計畫不同」第 28 條）；亮 `glow.ready.duration` 秒（預設 3）。
- **無損刷新**：後掛勾 item 的 `ShowPandemicStateFrame／HidePandemicStateFrame`，邊框換 `pandemic.color`，
  `pandemic.bars` 時長條條身也換色；Hide 換回。暴雪的 PandemicIcon 不碰。
- **按鍵文字**：`FindSpellActionButtons`（覆寫法術優先）→ 格號 → 綁定指令（主動作條目前那一頁／左下右下右側／
  動作條 6–8，照暴雪 `MultiActionBars.xml` 的 actionpage 與按鈕模板的 buttonType）→ `GetBindingKey` → 縮寫
  （Shift→s、Ctrl→c、Alt→a、滑鼠鍵→M4、數字鍵盤→N5…）。物品掃動作條格子。綁定／動作條事件 0.2 秒合併重算。
- 發光宿主是 overlay 底下自己的框，尺寸由排版給（不從 item 讀）；停放時發光一律熄。

## 資源條與施法條

兩者都是**面板**：不在 `bars` 裡（沒有版面／主題繼承），設定在 `profile.resources`／`profile.castbar`，
左欄有自己的頁；但**錨定語意跟條一模一樣**（`pos = { point, x, y }`、`anchor = false | { to, point, relPoint, x, y }`），
容器也是 `MiliUICDM_Bar_<key>`、走 `Core/Bars.lua` 的同一套 `ApplyStructure`、編輯模式覆蓋層／選取框／磁吸、點擊層。

| 位置 | 內容 |
|---|---|
| `Core/DB.lua` | `DB.PANEL_KEYS`／`DB.PANEL_ORDER`（`resources`、`castbar`）、`DB.ConfigTable(key)`（條或面板的設定表：錨定、編輯模式、設定頁的 `root = "bar"` 都走它）、`RESOURCE_COLORS`（資源預設色的單一來源）、兩張預設表 |
| `Core/Bars.lua` | `B.RegisterPanel(key, { anchorPoint, minSize, relayout })`：建容器（連帶 `EditMode.OnContainer`）、照存檔貼位置；`B.SetPanelSize`（走 `ns.Write`）；`B.FirstRowWidth("essential")`，核心技能第一列寬度變了廣播 `FirstRowWidthChanged`。排程對面板只做結構級，內容交給模組的 `relayout` |
| `Core/Visibility.lua` | `Vis.EvaluatePanel`／`PanelAlpha`（見下），一律 alpha；面板排在條後面套（資源條要讀核心技能剛算好的 alpha） |
| `Options/Specs.lua` | `Specs.Anchor(key)` 對面板照用；錨定候選＝`barOrder` ＋ 兩個面板（排除成環）；表單簽章多了整張錨定圖（別條的錨定一變，候選清單就要重算） |

容器的錨點：資源條 `BOTTOM`（預設錨在核心技能上緣、往上長，列數增減時下緣不動）、施法條 `CENTER`。
寬 0 ＝ 核心技能第一列寬（施法條含圖示）。

### 資源條（`Modules/Resources.lua`）

從單位框架的資源條與能量條改來。專精 → 資源清單（`SPEC_RESOURCES`）；德魯伊看型態（熊怒氣、貓能量＋連擊點、
其餘照專精）；用法力施法的專精（`MANA_SPECS`）在**最下面**多一列法力。一種資源一列：

| 模式 | 資源 | 畫法 |
|---|---|---|
| bar | 怒氣、能量、集中值、符文能量、星能、元能、狂亂值、魔怒、**法力** | 一顆 StatusBar：`SetMinMaxValues(0, UnitPowerMax)`＋`SetValue(UnitPower)` **直接餵**（引擎收秘密值），明文且上限 <= 0 才顯示空條；原生內插（`smooth`） |
| pip | 聖能、連擊點數、真氣、靈魂碎片、秘法充能、精華、符文；漩渦之武、矛尖、靈魂碎片（光環／施放次數型） | **每格一顆 StatusBar**：`SetMinMaxValues(i-1, i)`＋`SetValue(目前值)` ⇒ 第幾格亮由引擎決定，秘密值照樣畫得對。格子一律錨在列上（`SetValue(秘密值)` 會讓那顆條的幾何變秘密、傳染給錨在它身上的框） |
| pip（符文） | 符文 | 每格看 `GetRuneCooldown(i)` 的就緒旗標（明文才算） |

- **跟單位框架不同的兩件事**：那邊不做法力（單位框有自己的能量條）、也剔掉「單位框能量條已經在畫的主資源」；
  這裡是獨立 HUD，兩件都做。吸收型（醉仙緩勁、鐵鬃、無視苦痛）**維持不做**：12.1 是秘密值，插件讀不到數字。
- **天賦閘**：標準資源看 `UnitPowerMax > 0`（秘密值當有）；光環型看被動已學，被動 ID 寫錯的保險是「目前有層數就顯示」。
- **條件規則**（`Modules/ResourceConditions.lua`，純邏輯）：形狀跟單位框架的資源條一模一樣（`conditions[key] = { rule… }`，
  第一條成立的勝出、`target` 指定第幾格、`and` 巢狀、深度上限、壞資料當不成立）。**只在值是明文時求值**：
  秘密值下整段不求值（照主色）、數值文字不印、充能格照常（充能索引是另一支 API）。
- **法力數字**：`manaAbbrev` = none／k（K、M）／wan（萬、億；中韓預設）；`manaPercent` 印百分比。
- **事件**：`UNIT_POWER_FREQUENT`（＋`UNIT_POWER_UPDATE` 當回滿保底）、`UNIT_MAXPOWER`、`UNIT_DISPLAYPOWER`、
  `UPDATE_SHAPESHIFT_FORM`、`PLAYER_SPECIALIZATION_CHANGED`、天賦、進出載具、`RUNE_POWER_UPDATE`（死騎）、
  `UNIT_POWER_POINT_CHARGE`（盜賊）、`UNIT_AURA`（有光環型資源的職業），全部綁 `player`、**只標髒、下一幀做**。
  能量事件走「只重畫值」那條（不重算清單、不配表）；清單／格數／尺寸變了才重排。
- **顯示條件**：`enabled`、`loadConditions`（騎乘或坐載具時隱藏、只在戰鬥中）任一不符 ⇒ alpha 0；
  `fadeWithEssential` 開著時取核心技能現在的 alpha（它的顯示條件與淡出一起帶過來）。容器不是 secure 框，Lua 判斷即可。
- 列是池化的（frame 刪不掉），換專精只換內容；條件規則套上去的透明度／文字色換列時先還原。

### 施法條（`Modules/Castbar.lua`）

從單位框架的施法條改來，單位固定 `player`（載具期間開唱事件 player／vehicle 兩個 token 都認）。12.1 鐵律照舊：
受限時 `UnitCastingDuration` 等 duration 物件餵 `SetTimerDuration`、10Hz ticker 更新時間文字與顏色；
`notInterruptible` 只餵 `EvaluateColorValueFromBoolean`；事件處理器只轉手 `ns.Defer`（時間戳在派送當下取）。

- **顏色**：施法／引導（`useClassColor` 共用職業色）→ 蓄力時換成「現在放開會是第幾階」的顏色（四階）→
  斷法就緒（`interruptReady`，`Modules/Interrupt.lua`，可能是秘密布林，只餵曲線）→ 不可打斷。打斷／失敗是紅色。
- **引導刻度**（`ticks`）：固定跳數表（spellID，天賦會改跳數的四顆在天賦變動時重算；查不到 ID 再用法術名）。
  平均分就不需要總長；引導延長（`CHANNEL_UPDATE`）時照明文時間補刻度。
- **延遲條**（`latency`）：`UNIT_SPELLCAST_SENT` → 開唱的時間差（不合理就退回 `GetNetStats`），在條的終點端
  （施法在右、引導在左、反向填充對調）塗一段，上限三成。
- **蓄力分階**：`GetUnitEmpowerStageDuration`／`GetUnitEmpowerHoldAtMaxTime` 算每一階的終點畫線、決定顏色。
- 刻度、延遲、分階都要**明文的時間軸**（開始／結束讀得到）：讀不到就不畫，條本身照樣由 duration 物件驅動。
  位置一律用設定算出來的寬度，不讀框的幾何。
- **隱藏暴雪施法條**（`hideBlizzard`）：只能用單位框架已驗證的做法 —— `UnregisterAllEvents`，不 Hide、不 SetParent、
  不寫欄位。解之前先用 `IsEventRegistered` 記下它註冊了哪些（含 unit），取消勾選時照原樣 `RegisterUnitEvent` 裝回去，
  所以不需要 /reload。走 `ns.Write`。**例外**：單位框架（MiliUI_UnitFrames）的玩家框施法條也在隱藏它時
  （問它的公開 API `MiliUI_UnitFrames.HidesPlayerCastBar()`），取消勾選**不裝回**、只清帳 —— 那邊的隱藏是單向的，
  裝回去等於把它藏的條叫回來。設定頁那個開關的說明列有寫。
- **沒在施法**：`hideWhenNotCasting` 開著 ⇒ 容器 alpha 0；關掉 ⇒ 留一條空條。淡出、打斷停留（0.4 秒）期間算「在施法」。
- **預覽**：設定頁頁首的按鈕，十秒假施法（明文路徑，帶假延遲），再按一次停；真的開唱就讓位；離開那一頁自動停。

### 公開 API（契約：回傳形狀之後不改）

全域表 `MiliUI_CooldownManager`（`Api.lua`）。呼叫端一律處理 `nil`（本插件沒載入完、互斥偵測成立、那一項不存在）。
回傳的表是**設定檔裡的參照**：唯讀、不長期持有（換設定檔之後就是另一張）。

| 函式 | 回傳 |
|---|---|
| `GetResourceColors(key)` | `{ color = {r,g,b,a}, chargedColor = {…}\|nil, chargedEmptyColor = {…}\|nil }`；沒有這個資源、設定檔還沒載入 → `nil`。key 見下 |
| `GetResourceConditions(key)` | 規則陣列（形狀見 `Modules/ResourceConditions.lua` 檔頭，與單位框架相同）；沒有規則 → `nil` |
| `GetResourceBarFrame(powerType)` | `Enum.PowerType` → 資源條上那一列的框；沒有這一列、玩家關掉、整條關掉（容器藏起來）→ `nil`。載入條件／淡出造成的 alpha 0 不算藏（框還在，錨在上面的東西不必換錨點） |
| `GetBarFrame(key)` | 容器框 `MiliUICDM_Bar_<key>`（四條檢視器、自訂群組、`resources`、`castbar`）；還沒建 → `nil` |
| `IsReady()` | 引擎是否已經認領好四條檢視器（布林）。問資源顏色／條件不必等它：設定檔載入前那兩支自己回 `nil` |
| `RegisterCallback(event, key, fn)` | 訂閱事件，目前只開放 `"ResourceStyleChanged"`（資源顏色或條件規則變了：資源條頁的套用、換設定檔、換專精，合併 0.2 秒，不帶參數）。同一個 key 再登記＝換掉；成功回 `true`，事件不開放回 `false`。`fn` 拋錯會被隔離 |
| `UnregisterCallback(event, key)` | 取消訂閱 |

資源 key（存檔內容，不要改名）：`Mana`、`Rage`、`Energy`、`Focus`、`RunicPower`、`LunarPower`、`Maelstrom`、`Insanity`、`Fury`、
`HolyPower`、`ComboPoints`、`Chi`、`SoulShards`、`ArcaneCharges`、`Essence`、`Runes`、`MaelstromWeapon`、`TipOfTheSpear`、`SoulFragments`。

### 設定頁

- **資源條**：顯示、版面（寬、列高、列距、格距、填充方向）、外觀（材質、填充透明度、平滑、數值文字與字級、法力格式）、
  顏色與條件（每種資源的顏色、連擊點數的充能色、條件規則編輯器）、這個專精要顯示哪幾列、載入條件、錨定、恢復預設。
  表單照「形狀」快取（專精、候選清單、條件編輯器的結構、錨定圖）：規則增刪之類的結構變動延一幀換一份表單。
- **施法條**：顯示、隱藏暴雪施法條、版面、顏色（含蓄力四階、斷法就緒）、圖示、文字（名稱最多字數、時間格式）、
  效果（火花、刻度、延遲）、沒在施法時隱藏、錨定、恢復預設。

## 套組接線

G 階段：套組裡原本只認舊的冷卻管理器插件的地方，改成**先問本插件、再問舊插件**。一律走「公開 API」那一節的函式，
呼叫端都處理 `nil`（本插件沒載入、還沒就緒、互斥偵測成立）。

| 插件 | 認得什麼 | 透過哪支 |
|---|---|---|
| `MiliUI_UnitFrames` 資源條 | 「跟隨冷卻管理器的顏色」：每種資源的顏色（含連擊點數的充能色）與條件規則 | 有 `GetResourceColors` 就問（不等 `IsReady()`：設定檔還沒載入時它自己回 nil）；本插件在答（法力的顏色表問得到）時條件規則只看本插件，否則 → 舊插件 → 自己的預設。登記 `RegisterCallback("ResourceStyleChanged")`，改色後立刻重畫（不等下一次能量事件）。存檔鍵仍叫 `followAyije`（相容），語意是「跟隨冷卻管理器」。`/muf debug` 的「顏色來源」印實際在答的是哪一支 |
| `MiliUI_CrusadingStrikes` | 掛在聖能條上方／下方；「自動」模式兩支任一載入就掛聖能條 | `GetResourceBarFrame(Enum.PowerType.HolyPower)`，沒有再退舊插件的表。資源列是池化重用的，輪詢時比對「解析出來還是同一個框」 |
| `MiliUI_UnitFrames`（反向） | 本插件取消「隱藏暴雪施法條」時要不要把事件裝回去 | 單位框架的公開 API `MiliUI_UnitFrames.HidesPlayerCastBar()`（布林，單向：為真就維持到 /reload） |
| `MiliUI` 本體 | 插件清單、預設值匯入、MasqueBlizzBars 修補（兩支任一載入就讓它跳過冷卻管理器） | 資料夾名 `IsAddOnLoaded`。「插件強化」頁的施法條三個開關只對舊插件有效，**只在舊插件載入時出現**；本插件的引導刻度與延遲條在 `/mcdm` → 施法條 |

兩支 `OptionalDeps` 都加了 `MiliUI_CooldownManager`（只排載入順序；每次都現查，不快取「有沒有載入」）。
舊插件本身不動：互斥只在本插件這邊偵測（彈窗二選一）。

## 設定的三層繼承

取值一律走兩支函式，引擎與設定介面都一樣，不各自翻表：

```lua
ns.Setting(barKey, path)                        -- 例：ns.Setting("essential", "cooldownText.size")
ns.SpellSetting(barKey, cooldownID, key[, specID]) -- 例：ns.SpellSetting("essential", 1234, "borderColor")
```

`theme`（全域主題）→ `bars[barKey]`（該條的 `follow` 那一項為 false 才讀條自己的值）→
`spells[specID].overrides[cooldownID]`（逐法術覆寫）。**沒有複製**：條沒存的格子退回主題，
法術沒覆寫的欄位退回條。`path` 用主題的形狀寫（`cooldownText.size`、`border.color`、
`glow.proc.type`、`icon.zoom`、`fade.mounted`），條把它存在哪張子表由 `Core/DB.lua` 的
`THEMED` 對照表決定；版面、位置、錨定、顯示條件這類條自己的欄位不繼承。
「沒有／不要」一律存 `false` 不存 `nil`（否則合併預設值時會被補回來）。

## 與計畫不同

實作時發現計畫上寫的做不到、或換了做法的地方，依階段排；編號連續。

**B 階段：引擎**

1. **倒數文字不自己畫**。計畫寫「`SetHideCountdownNumbers(true)`、倒數我們自己畫」與「低秒變色用曲線餵 `SetCooldownFromDurationObject`」都走不通：`GetCooldownTimes`／`GetCooldownDuration` 回秘密值；`Curve:Evaluate` 不收秘密 x；`SetCooldownFromDurationObject` 沒有曲線參數，而且暴雪用的是 `SetCooldown(start, duration)`，我們拿不到 duration 物件。改成打開暴雪 Cooldown 的內建數字、換它的 FontString 樣式，小數門檻走 `SetCountdownMillisecondsThreshold`，低秒變色走 `SetCountdownFormatter`（分段規則的 format 包 `|c` 色碼，**待實機驗證**）。同理充能與層數也是改暴雪的 FontString，overlay 框上沒有自己的文字。
2. **「IconOverlay」不是 parentKey**：暴雪 XML 裡那張外框圖沒有名字，改成掃 item 的 regions、用 atlas 名稱 `UI-HUD-CoolDownManager-IconOverlay` 認出來熄 alpha。另外拔掉圖示的圓角遮罩、轉圈材質換成方的（不然直角邊框配圓角圖示）。
3. **暴雪的觸發發光先不熄**：自己的發光在效果那一階段才做，現在熄掉等於功能倒退。留了開關：`ns.Glow.ownsProcAlert = true` 才熄。
4. **12.1 新增的四個類別（裝備欄、不分專精）是候選池，不是無條件併進去**。暴雪檢視器只為「有效類別等於自己」的 id 建框（`GetOrderedCooldownIDsForCategory`），還留在原類別的 id 沒有 item，列進清單只會變成永遠的空位／占位格。玩家在暴雪面板把它們拖進核心／輔助／增益之後，分類覆寫就是那一條，自然併進來；還在池裡的由 `Catalog.Pool(key)` 給之後的設定介面用。
5. **版面字串的「版本」**：`"<版本>|…"` 那個是編碼版本（目前 1），不是 5；5 是解出來的表的 `data[1]`（存檔格式版本）。收 4 與 5（3 以前 `data[2]` 存的是版面名稱不是 ID）。
6. `cooldownInfo` 沒有 icon／name 欄位：`Catalog.Info` 用 `C_Spell.GetSpellTexture／GetSpellName(overrideSpellID or spellID)` 補。
7. **位置語意**：容器用版面算出來的錨點（CENTER_DOWN → TOP…），貼在 UIParent 的 `pos.point` 上加 (x, y)。所以預設的核心 (CENTER, 0, -202) 現在是「上緣」在畫面中心下方 202，不是中心點——之後給套組預設值時要照這個語意重量一次。
8. **每個訊號都讓所有條重排**：自訂群組與「把 A 檢視器的法術拉到 B 條」會讓任一條檢視器的變動影響別條，條最多十來條，全排很便宜，就不追蹤來源。（**H 階段已改**：只標受影響的條，見第 54 條）
9. 多掛了幾個點：檢視器的 `Layout`（同步放回，避免閃一幀）、`SetTimerShown`／`SetBarContent`（暴雪改顯示計時或長條內容時樣式重套）、`SetHideWhenInactive`。`SetBarContent` 是 **item** 的方法（計畫寫在 Bar 上）。
10. **淡出也要逐個 item 套 alpha**：item 的 parent 仍是暴雪檢視器（不 SetParent），容器的 alpha 管不到它們。
11. 目錄在每次排版前做一次便宜的新鮮度檢查（版面字串、specTag）：暴雪換專精／存版面是在它自己的下一幀做的，不保證有事件接得到。多聽了 `SPELLS_CHANGED`／`PLAYER_EQUIPMENT_CHANGED`／`TRAIT_CONFIG_UPDATED`（isKnown 會變）。（H 階段：輪詢改成每秒最多一次，見第 55 條）
12. 「騎乘時隱藏」也包含坐載具（計畫的事件清單有載具事件、但資料模型沒有載具欄位）。
13. 容器的 1px 職業色邊也先透明（計畫只說底 alpha 0；邊框留著會在每條外面框一圈）。

**C 階段：編輯模式**

14. 暴雪的 Selection `SetAllPoints` 到**覆蓋層**，不是容器：非空的條兩者一樣大；空條容器只有 1×1，
   貼容器就點不到。
15. 四條檢視器不呼叫暴雪 Selection 的 `ShowHighlighted`（計畫寫「進入時 ShowHighlighted」）：那會寫它的
   `textureShown`／`isSelected` 欄位。顯示與否交給暴雪的「冷卻管理器」勾選框；沒勾時改用我們自己的
   選取框頂上（同一個模板、同一套拖曳），所以四條永遠拖得動。
16. 暴雪設定對話框不在掛勾裡當場 `Hide`：當場只 `SetAlpha(0)`（C 端狀態），`Hide` 延一幀走 `ns.Write`，
   離開 `SelectSystem` 的堆疊。（**H 階段已改**：不再 Hide，見第 53 條）
17. 提示「拖曳會解除跟隨」在進編輯模式時就顯示（不只拖曳前一刻），放手後消失。
18. 編輯模式中顯示條件暫停、每條全亮（計畫沒寫；不然條件不成立的條進編輯模式看不到、拖不到）。

**D 階段：設定介面**

19. **「開暴雪警示設定」開的是同一個面板**：暴雪面板沒有「警示」分頁，警示是逐法術右鍵設定的；
   要切顯示模式得呼叫它的 `SetDisplayMode`（從我們的執行寫它的 `displayMode` 欄位），不做。
   按鈕多印一行「對法術按右鍵新增警示」，滑鼠提示也寫。
20. **淡出放在效果節尾端，但有自己的「跟隨全域主題」**：資料模型的 `follow.fade` 是獨立的一項，
   跟 `follow.glow` 綁在一起會讓「只想改淡出」的玩家連發光一起脫離主題。
21. **邊框材質**：LibSharedMedia 的 border 類是 backdrop 的 edgeFile，四條細條畫不出來；選了材質邊框
   改用一個 backdrop 框貼齊（粗細 1 ＝ edgeSize 4），`solid` 維持四條細條（`Decorate` 的 `LayoutBorder`）。
22. **主題多了 `keybind = { enabled = false }`**（`THEMED` 跟著 glow 走、存在條的 `glow` 子表）：按鍵文字的
   開關要有地方存。E 階段接上引擎，效果節頂端那行「下一版才畫」的灰字已拿掉。
23. **`Catalog.Bar(key, true)`** 多回一張「被藏起來」的清單（預覽排在尾端用），不帶參數時行為不變。
24. **預覽假倒數是靜態「15」**，沒用真的 Cooldown 倒數數字（那條路要實機驗證 formatter，見待驗證 10）；
   轉圈是自己的 Cooldown 框跑十五秒循環，轉圈色所見即所得。
25. **挑選器的「已在暴雪冷卻管理器」包含增益圖示**（圖示類都可以互拉），長條只收長條。
26. 「新增群組」的類型選擇多一顆「取消」；新群組的 key 取最小的空號（刪掉 g1 之後下一個又是 g1），
   頁面與預覽照 key 快取重用。
27. `EditMode` 多廣播 `EditModeChanged`（點擊層要讓位），`Frames.lua` 匯出 `EM.CellSize`。

**E 階段：自訂項目與效果**

28. **就緒探針對暴雪 item 不是只靠「轉交 SetCooldown 參數」**：`Cooldown:SetCooldown` 是 AllowedWhenUntainted，
   參數是秘密值時我們（污染端）轉交會被拒。做法改成兩段：先 `pcall(probe.SetCooldown, start, duration, modRate)`
   原封轉交（明文時成立、跟暴雪那顆完全同步）；被拒就改拿**引擎給的** duration 物件
   （`C_Spell.GetSpellCooldownDuration(spellID, true)`，暴雪標了 `wasSetFromCharges` 時用 `GetSpellChargeDuration`）
   餵 `SetCooldownFromDurationObject`。另外：暴雪正在顯示光環時間（`cooldownUseAuraDisplayTime`，只讀）時不武裝；
   GCD（明文 ≤ 1.5 秒）不武裝；暴雪提早 `Clear`（到期那一刻它自己清、或冷卻被重置）而探針還武裝著 ⇒ 當場算就緒
   （掛了 item Cooldown 的 `Clear` 後掛勾）；item 換了身分就不算。（H 階段：這兩個狀態改成先問 getter，見第 49 條）
29. **多充能**：每一次暴雪的 SetCooldown 都是回充（有充能時是充能計時、0 充能時是技能冷卻），所以每回一層亮一次，
   沒有另外判斷 `wasSetFromCharges`（見待驗證 35）。
30. **觸發發光的接管以「條」為單位**：`ns.Glow.ownsProcAlert` 常開，逐格問 `OwnsProc`（條層開著，或這個法術覆寫成開）。
   條層開、法術覆寫成關 ⇒ 暴雪的熄掉、我們的也不畫（＝這個法術不要發光）。
31. **自訂項目只進圖示類的條**：長條的 item 是暴雪另一種框，自訂項目沒有長條外觀可畫。挑選器在長條頁寫明原因。
32. **條的淡出不逐框套到自訂框**：自訂框是容器的子框，容器的 alpha 就管得到；再套一次會變成 alpha²。
33. **無損刷新多一個開關** `pandemic.enabled`（預設開）：只有顏色沒有開關的話，不想要的人關不掉。
34. **按鍵文字的設定**：DB 預設 `keybind = { enabled = false, size = 10, point = "TOPLEFT", x = 1, y = -1 }`，
   效果節多了字級／錨點／偏移三列；字型跟文字節的字型／描邊走。
35. **刪自訂群組時自訂項目不會消失**：光環格回增益圖示、法術／物品回核心技能（計畫沒寫；它們沒有「原本的暴雪那條」）。
36. 物品的「數量」只在可消耗的物品（`C_Item.IsConsumableItem`）或數量不是 1 時顯示（飾品不印「1」）。
37. 固定格位那一列改成自畫的 custom 列（表單引擎的 toggle 沒有停用狀態），說明依狀態換兩種說法。

**F 階段：資源條與施法條**

38. **沒有 DB 遷移**：第一版還沒發佈，`DB_VERSION` 維持 1，直接補預設值（`MergeDefaults` 替舊存檔補新鍵）。
39. **錨定候選不寫進 `barOrder`**：`barOrder` 是左欄「條」的順序，面板放進去會被當條列出；改成候選清單＝`barOrder`＋`DB.PANEL_ORDER`。
40. **條件規則的比較不走曲線**：玩家自己的資源值在目前的客戶端是明文（`UnitPower("player")` 沒有身分受限），
   單位框架也是明文比較。秘密值下改成「不求值」（照主色、不印字），pip 的亮格仍由 StatusBar 引擎畫對。
41. **點數型改成每格一顆 StatusBar**：單位框架是讀明文值、在 Lua 裡比「第 i 格亮不亮」再上色；這裡照任務要求改成
   `SetMinMaxValues(i-1, i)`＋`SetValue(目前值)`，秘密值也畫得對。
42. **資源條的計畫欄位砍了一部分**：計畫寫「每職業每條」各自的高／寬／材質／tag 文字（光環剩餘時間）、錨到另一條資源條；
   這一版是整條一組設定（寬、列高、材質共用），每種資源只有自己的顏色與條件規則。載入條件只做騎乘／只在戰鬥中，
   專精由清單本身決定、型態只在德魯伊生效。
43. **施法條沒有施法目標、斷法者名字、重要法術染色、完成閃色**（那是給敵方施法條的）；打斷固定停留 0.4 秒、淡出 0.3 秒。
   不可打斷色照樣套（自己少數引導會是不可打斷），沒有另開開關。
44. **延遲只畫紅區不印毫秒數**：本體強化的延遲文字會壓在時間文字上；`/mcdm debug` 印得到量到的值。
45. 施法條的 `hideWhenNotCasting` 關掉時留空條（計畫沒寫空條長什麼樣）；編輯模式中一律全亮。
46. 面板的顯示條件不走條的 `visibility`／`fade` 模型（各自一條，見上）。
47. **斷法就緒**從單位框架搬進 `Modules/Interrupt.lua`（事件改走 `ns.Events`／設定檔回呼）。
48. 核心技能頁的錨定清單會排除「錨在自己身上」的面板（成環）；錨定圖進了條頁的表單簽章。

**H 階段：打磨**

49. **身分讀取改走 getter**：item 的身分先 `pcall(item.GetCooldownID)`，讀不到才 `rawget(item, "cooldownID")`（欄位名與 getter 對過 12.1.0.69933 的 `CooldownViewerItemData.lua`）。就緒探針的「暴雪在顯示光環時間」先問 Cooldown 框自己的 C 端 `GetUseAuraDisplayTime()`、「這次是回充」先問 item 的 `HasVisualDataSource_Charges()`，欄位 `cooldownUseAuraDisplayTime`／`wasSetFromCharges` 只當退路。
50. **圓角遮罩／轉圈材質只拔一次**（`rec.stripped`）：查過暴雪原始碼，遮罩與轉圈材質只在 XML 模板裡，Lua 端（取出、`RefreshData`、`SetCooldownID`、池子 reset）都不會重加，所以不必在取出時重做（查證寫在 `Decorate.lua` 的 `StripBlizzard` 上面）。
51. **延遲量測的戳記**：兩個戳記都在事件派送當下取，SENT 不進 `ns.Defer`；`GetTime()` 整幀凍結，SENT 與開唱同一幀時相減是 0 ⇒ 退回 `GetNetStats` 的世界延遲。`/mcdm debug` 的施法條那行會標「（GetNetStats）」。
52. **還給暴雪**（`ns.Bars.ReleaseAll`）：`/mcdm release`（除錯）或引擎任何一步啟動失敗時自動叫（聊天框印一行失敗的模組）。所有追蹤過的 item alpha 1、清錨點、尺寸還原成第一次看到時的；釘過的檢視器錨回 UIParent CENTER；發光停、暴雪的觸發發光 alpha 還回 1、按鍵文字與邊框藏起來；之後條不再排（資源條、施法條照常）。回不去，要重新接管就 /reload；改過的圖示遮罩、轉圈材質、字型不還原。
53. **暴雪的系統設定對話框不 Hide**：改成 `SetAlpha(0)`＋`EnableMouse(false)`（對話框與每個吃滑鼠／滾輪的子孫，記下來），點到別的系統或離開編輯模式時照記錄還回去。Hide 會從我們的執行跑暴雪的 `OnHide`（寫 `attachedToSystem`）。
54. **重排訊號只標受影響的條**：檢視器有動靜時標「來源條＋目前認領著它的 item 的條＋從它拉法術的條（`groupOf`，`Catalog.GroupTargets`）」，不再全部條重排；設定變了照舊 `RequestAll`。自訂法術／物品的冷卻讀取（`Custom.Update`）只在位置／條換了、樣式重套了、事件標髒了才做。
55. **目錄新鮮度檢查每秒最多一次**：`Catalog.CheckFresh` 輪詢 `GetLayoutData()` 限 1 秒；事件路徑（標髒）不受限。
56. **資源顏色變更主動通知**：資源條頁的每次套用、換設定檔、換專精都（合併 0.2 秒）廣播 `ResourceStyleChanged`；公開 API 多了 `RegisterCallback`／`UnregisterCallback`（只開放這一個事件），單位框架登記它、收到就重評估資源條。單位框架問顏色不再看 `IsReady()`：`GetResourceColors` 在設定檔還沒載入時自己回 nil。
57. **輸入錯誤不換標題**：挑選器的「自訂 ID」輸入彈窗，錯誤改成說明與按鈕之間一列灰色小字（彈窗跟著長），標題不動；共用層彈窗是絕對座標，放不進標題正下方。
58. **字高在顯示之後重量**：逐法術面板的每列標籤與說明、設定檔頁匯入審閱區（說明、摘要、「綁定到目前專精」換行），都在 OnShow 重量重排；審閱區的勾選框與按鈕改成跟著摘要往下排。
59. **刪掉的自訂群組**：容器收起來時編輯模式的覆蓋層與選取框一起收；`/mcdm debug` 的編輯模式段只列設定檔裡有的條與面板。匯出失敗有自己的訊息（不再借用「字串已損壞」）。

## 待實機驗證

依區塊排，編號連續。打一場記得開 `/console taintLog 2`，看完別 /reload（會清掉 taint.log）。

**暴雪檢視器與引擎**

1. 暴雪 12.1 的 `EquipSlotEssential`／`EquipSlotTracked` 是否真的讓飾品出現在核心／輔助檢視器；沒有的話追蹤項目要補「裝備欄」種類。
2. 增益圖示 item 的 `IsShown()` 在秘密值下是否仍是明文布林（收合模式的前提）。
3. `GetLayoutData` 的格式版本是否仍是 5、`data[2]`／`data[3]` 的欄位位置是否如上（先拿使用者自己的 SV 字串離線解一次）；解不開時退回類別集合順序要能無感。在暴雪面板存版面後，排版最晚一秒內跟上（`CheckFresh` 節流）。
4. item 身分：`GetCooldownID()` 在戰鬥中／首領戰回的是明文 number；登入時 item 已在池子裡（`/reload` 在戰鬥外、戰鬥中各一次），四條沒有被整條停到畫面外。
5. 後掛勾的污染：`hooksecurefunc` 掛在 item 的 `SetCooldownID`／`OnActiveStateChanged`／`SetScale`、Cooldown 的 `SetCooldown`、Icon 的 `SetDesaturated` 上，戰鬥中零 ADDON_ACTION_BLOCKED、零秘密值錯誤。
6. 檢視器本體釘在容器上之後，底部管理框（`BottomManagedFrameTemplate`）與編輯模式重排會不會跟我們拉鋸（SetPoint 後掛勾每次都會釘回來）。
7. 重排只標受影響的條：光環上下、把法術在核心／輔助／自訂群組之間拉來拉去之後，沒有哪一格卡在舊的條上或被停放（認領過期）；`/mcdm debug` 的「認領」數跟畫面一致。
8. 圓角遮罩與轉圈材質只拔一次（`rec.stripped`）：換專精、開關暴雪設定面板、暴雪整條 `RefreshLayout` 之後，圖示仍是直角、轉圈仍是方的。
9. `/mcdm release`：item 在暴雪下一次排版時回到暴雪自己的格線（在那之前沒有錨點、看不到是預期的）；檢視器在畫面中央；觸發發光由暴雪自己畫；之後 /reload 一切接回來。

**外觀與文字**

10. 倒數低秒變色：Cooldown 的 `SetCountdownFormatter` 是否照 FontString 規則解析 format 裡的 `|c` 色碼；自訂 formatter 會不會蓋掉暴雪原本的「1:31」縮寫樣式（我們給了 91 秒／5401 秒的分／時段）。
11. GCD 轉圈：`SetCooldown` 的 duration 在戰鬥中是否明文（讀不到就不藏，會多轉一圈）。
12. 長條換材質（`SetStatusBarTexture`）後暴雪的 Pip 錨點失效——我們把 Pip 熄了，確認沒有殘影。
13. 固定格位的占位貼圖畫在容器的 BACKGROUND 層，暴雪 item 是檢視器的子框：兩者都掛在 UIParent 下，容器的 frame level 必須低於 item 才會被蓋住（item 出現時占位要看不見）。
14. 12.1 增益圖示檢視器裡「無視痛苦」這類數值型 buff 的 `Applications` 文字是否明文；資源條要顯示它的話只能掛 `SetText` 後掛勾照抄字串，不能算。
15. LibSharedMedia 的 border 材質用 backdrop edgeFile 畫在 overlay 上：粗細 1～4 對應 edgeSize 4～16 看起來合理嗎。

**編輯模式**

16. `Selection` 用 `SetScript` 換拖曳腳本後，戰鬥中動作條零封鎖。
17. 戰鬥中進出、拖曳中進戰鬥零 ADDON_ACTION_BLOCKED；資源條（錨在核心技能上）拖曳脫離、施法條拖曳，放手後位置不跳。
18. 暴雪的系統設定對話框：點四條檢視器 ⇒ 看不到也點不到（對話框本身與子孫的滑鼠、滾輪都關了）；點別的系統 ⇒ 正常顯示、每個控件都點得到、滾輪有反應；離開編輯模式再進來也正常。點過四條、離開編輯模式打一場，快捷列零封鎖、`/dump issecurevariable(EditModeSystemSettingsDialog, "attachedToSystem")` 為真（我們不再 Hide 它，不會寫到這一欄）。對話框藏著時暴雪若又為四條之一重建設定列（新的列沒被我們關滑鼠），確認不會出現看不見但點得到的控件。
19. 暴雪 Selection `SetAllPoints` 到覆蓋層後，暴雪自己的磁吸（別的系統吸到冷卻管理器）與 `UpdateClampOffsets` 沒有怪行為；離開編輯模式後 Selection 留著這個錨點（下次進來會重貼）。
20. 齒輪圖示 `Interface\Buttons\UI-OptionsButton` 在 12.1 仍存在、16×16 看得清楚。
21. 暴雪的「吸附」開關與格距讀得到（`IsSnapEnabled`、`GetAccountSettingValue(GridSpacing)`），格線原點是畫面中心、單位是 UIParent 座標。
22. 覆蓋層 strata HIGH：齒輪要蓋得過選取框（MEDIUM／1000、toplevel），但不能蓋過暴雪的編輯模式面板（DIALOG）。
23. 刪掉自訂群組後進編輯模式：那一條的覆蓋層與選取框不再出現。

**設定視窗**

24. `securecall("ShowUIPanel", CooldownViewerSettings)` 從插件開暴雪面板不留污染（開完打一場）。
25. 預覽的 `CooldownFrameTemplate` 在設定視窗裡：`OnCooldownDone` 循環、方角轉圈材質、`SetHideCountdownNumbers` 後沒有暴雪數字。
26. 預覽的像素字（`SetIgnoreParentScale`）在設定視窗裡字級跟真實條一致；設定視窗若被其他插件縮放會不一致。
27. 點擊層（HIGH strata、錨在容器上）在容器被光環格保護連坐之後，開關窗走 `ns.Write` 不被擋。
28. 字高重量：德文／法文客戶端第一次開逐法術面板、設定檔頁的匯入審閱區，換行的標籤不重疊、列高對；挑選器輸入錯誤時灰字那一列把彈窗撐高、不壓到按鈕。

**自訂項目**

29. 容器與光環格持有框的 `IsProtected()`（`/mcdm aura`）；戰鬥中原生增益增減、換樣式（記旗標、脫戰換容器）零 ADDON_ACTION_BLOCKED；暴雪 item 錨在被保護連坐的容器上，戰鬥中重排 item 不被擋。
30. 光環格的 `SetDurationText(fs, { textFormatter, textColor = { curve, RemainingDuration } })` 有沒有被拒、低秒變色有沒有生效；`AddAuraSlot` 的按鈕在 `initializeFrame` 裡 `SetAllPoints(container)` 之後尺寸對不對。
31. 光環格的 HARMFUL（NeverSecret 的減益）在首領戰／M+ 是否照樣顯示；HELPFUL 在秘密值下是否照樣。
32. 自訂法術：`GetSpellCooldownDuration(id, true)` 的 ignoreGCD 是否真的不含 GCD；`EvaluateRemainingDuration`＋`Texture:SetDesaturation` 的去飽和在戰鬥中是否正確；`GetSpellChargeDuration` 的回充邊緣。冷卻讀取改成「位置／樣式變了或事件標髒才做」之後，增益上下造成的重排不會讓自訂法術的冷卻停住。
33. 物品冷卻：`C_Item.GetItemCooldown`／`GetInventoryItemCooldown` 的 start／duration 在戰鬥中／首領戰／M+ 是否明文（讀不到時 arm 過的照跑、沒 arm 的脫戰才出現）；藥水「戰鬥中用了、脫戰才開始冷卻」（enable = 0）的顯示。

**發光與按鍵文字**

34. 觸發發光：`ShowAlert` 後掛勾在首領戰是否照樣觸發；暴雪的 `SpellActivationAlert` 熄 alpha 之後沒有殘影。
35. 就緒探針：`Cooldown` 的 `OnCooldownDone` 在餵秘密 duration object 時是否照觸發；秘密參數被拒 → 改走 duration 物件那條是否照樣觸發；`Clear` 後掛勾在「到期時暴雪先清」的情況是否比探針自己的 OnCooldownDone 早（兩條都會觸發一次就緒，有旗標擋重複）；多充能每回一層亮一次是否符合預期（沒有另外判斷「這次是回充」）。
36. 就緒探針讀暴雪狀態：Cooldown 的 `GetUseAuraDisplayTime()` 在 SetCooldown 後掛勾裡回的是這一次的值（暴雪先 `SetUseAuraDisplayTime` 再 `CooldownFrame_Set`）、明文布林；`HasVisualDataSource_Charges()` 在秘密參數那條路上回的是對的。光環型技能（顯示光環時間的那段）不會亮就緒。
37. 無損刷新：`ShowPandemicStateFrame` 在增益圖示／長條上真的會叫（暴雪在 OnUpdate 裡每幀叫，後掛勾有「狀態沒變就走」）。
38. 按鍵文字：變形／姿態列（`GetBonusBarOffset`）、動作條 6–8 的綁定名、`FindSpellActionButtons` 對覆寫法術回不回格子。
39. 發光宿主（overlay 底下的子框）在 item 被停放（alpha 0、畫面外）時 MiliUIGlow 的 driver 仍在推（可見度閘看的是 IsVisible，alpha 0 仍算可見）——停放時我們已經 Stop，確認沒有漏掉的。

**資源條**

40. 點數型每格一顆 StatusBar（`SetMinMaxValues(i-1, i)`＋`SetValue(目前值)`）在秘密值下亮格正確；首領戰／M+ 中 `UnitPower("player")` 是否仍是明文（`/mcdm debug` 每列印「秘密 是／否」）。
41. `UNIT_POWER_FREQUENT` 綁 player 後能量平滑；回滿時 `UNIT_POWER_UPDATE` 保底有到。
42. 光環型（漩渦之武、矛尖）`GetPlayerAuraBySpellID(...).applications` 在戰鬥中是否讀得到；讀不到時層數顯示 0（直接餵 SetValue 也不會壞）。
43. 法力列 `smooth`（`Enum.StatusBarInterpolation.ExponentialEaseOut`）的觀感；德魯伊變形時清單切換不閃。
44. 單位框架的資源條跟隨本插件的顏色：登入後不必等四條檢視器認領完就換色；在資源條頁改顏色／規則，單位框架那邊 0.2 秒內跟著變（`ResourceStyleChanged`）；互斥偵測成立（另一支冷卻管理器插件開著）時照樣退回那一支的顏色。

**施法條**

45. 受限內容裡 `UnitCastingInfo("player")` 的開始／結束是不是秘密值（是的話刻度只能平均分、延遲與蓄力分階不畫）；`C_Secrets.HasSecretRestrictions()` 的值。
46. `UnitChannelInfo` 第 10 個回傳（蓄力階數）與 `GetUnitEmpowerStageDuration` 在戰鬥中是否明文；蓄力四階的顏色切換時機與暴雪的階段動畫一致。
47. 隱藏暴雪施法條 → 取消勾選 → 暴雪條立刻恢復運作（`IsEventRegistered` 回的 unit 參數、`RegisterUnitEvent` 裝回去）；打一場確認零 ADDON_ACTION_BLOCKED。單位框架的玩家框施法條也開著時，取消勾選暴雪條**維持隱藏**（`/mcdm debug` 施法條那行印「單位框架也在隱藏」）。
48. 延遲量測：兩個戳記都在派送當下取；SENT 與開唱在同一幀（`GetTime()` 相同）時退回 `GetNetStats` 的世界延遲——`/mcdm debug` 的延遲有沒有常常帶「（GetNetStats）」、量到的值是否跟 `GetNetStats` 同一個量級。
49. 載具上施法（player／vehicle 兩個 token）畫得對；`UNIT_SPELLCAST_FAILED` 的 castGUID 比對。
