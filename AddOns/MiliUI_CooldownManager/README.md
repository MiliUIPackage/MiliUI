# 米利的冷卻管理器 MiliUI_CooldownManager

接手暴雪 12.1 冷卻管理器的四條檢視器（核心技能、輔助技能、增益圖示、增益長條），
重新排版、換樣式、加文字與發光，外加自訂群組、追蹤項目、資源條與施法條。
設定視窗 `/mcdm`（或 `/miliuicdm`、小地圖按鈕、插件選單）。

## 第一次啟用（給玩家）

1. **停用舊的冷卻管理器插件**（插件清單裡的 `Ayije_CDM` 與 `Ayije_CDM_Options`）。兩支都開著的話，登入時本插件會跳出視窗，
   按「停用 … 並重新載入」就是這一步；想把它的設定帶過來就按「從 … 匯入」（見「從 Ayije_CDM 匯入」）。
2. `/reload`。
3. 要用套組調好的樣子：`/miliui` →「預設值匯入」→ 匯入 `MiliUI_CooldownManager` 再 `/reload`；
   不匯入也可以，本插件自己的內建預設值就能直接用。
4. 進**編輯模式**（Esc → 編輯模式）拖四條檢視器、資源條、施法條擺位置；細節在 `/mcdm` 設定視窗裡調。
5. 單位框架的資源條與征戰聖擊助手不用另外設定：預設就會改跟本插件（單位框架那邊取消「跟隨冷卻管理器的顏色」就改用自己的）。

## 現況

> **第一版完成，待實機驗證。** 四條暴雪檢視器認領重錨到自己的容器上（版面、兩列尺寸、固定格位、長條、
> 邊框／縮放／轉圈色／文字樣式、顯示條件）；編輯模式裡每條都拖得動；設定視窗每條一頁（預覽即編輯器＋表單）、
> 主題、設定檔（含匯出匯入）、自訂群組；自訂項目（光環格、自訂法術／物品冷卻）、觸發／就緒發光、無損刷新、
> 按鍵文字、音效（就緒／光環出現／消失）；資源條與玩家施法條；套組裡的單位框架、征戰聖擊助手、本體設定頁都認得本插件。
> 程式裡沒有實機跑過的假設全部列在最後的「待實機驗證」。
> `/mcdm debug` 印引擎與編輯模式現況，`/mcdm aura` 印每個光環格的保護狀態與最近錯誤，
> `/mcdm release` 把冷卻管理器還給暴雪（除錯用，/reload 接回來）。

⚠ 跟另一支同樣接管冷卻管理器的插件**不能同時啟用**：偵測到時登入會跳出視窗二選一，
本插件在那次登入裡什麼都不做。

## 架構

一支單體發佈的插件，共用層全部 vendor 在 `Libs/`（`MiliUIWidgets` 設定介面、`MiliUIGlow`
發光、`MiliUISnap` 磁吸），唯一 source 在 MiliUI 本體，改了跑
`python3 .claude/scripts/sync-widgets.py` 同步；只有 `Libs/MiliUIWidgets/Env.lua` 是本插件自己的。
另外內嵌三支通用函式庫 `LibStub`、`CallbackHandler-1.0`、`LibSharedMedia-3.0`（原封不動，TOC 最前面載入）：
字型／材質／音效的名稱都走 LibSharedMedia，單獨安裝本插件時也要有它。

| 位置 | 內容 |
|---|---|
| `Core/Init.lua` | 命名空間、`ns.Guard`（掛勾的 xpcall 包裝）、`ns.Defer`（下一幀）、`ns.Write`（容器層寫入的唯一出口：戰鬥中碰保護框就記帳、脫戰補做）、事件註冊表、互斥偵測、登入流程 |
| `Core/DB.lua` | 預設值（套組現值）、遷移鏈、設定檔／專精綁定、`ns.Setting`／`ns.SpellSetting` |
| `Core/Import.lua` | 從 `Ayije_CDM` 匯入：純函式 `Convert`（對方的一份設定檔 → 本插件的一份）、互斥彈窗的匯入流程 `FromAyije`、別的專精的 spellID 等目錄建好再對表（`ResolvePending`，`Core/Catalog.lua` 叫），見「從 Ayije_CDM 匯入」 |
| `Core/Media.lua` | 字型／材質 token → 路徑（名稱問 LibSharedMedia） |
| `Media/Sounds/` | 內建音效 106 個＋`Sounds.lua`（載入時註冊進 LibSharedMedia，別的插件的音效下拉也選得到）。**這個資料夾是 GPL-2.0**，出處與授權見裡面的 `README.md`、`LICENSE`；跟本體其餘程式分開，本體的程式不要搬進去、裡面的東西也不要搬出來混用 |
| `Core/Style.lua` | HUD 皮數值與職業色強調色 |
| `Options/` | 700×520 設定視窗、左欄導覽、條頁／主題頁／設定檔頁、預覽、逐法術面板、點擊層、暴雪選項入口頁、小地圖按鈕（見「設定介面」） |
| `Core/Catalog.lua` ～ `Core/Visibility.lua`、`Core/Glow.lua`、`Core/Keybinds.lua`、`Modules/Custom.lua` | 引擎，見下一節 |
| `Core/Masque.lua` | 圖示外觀＝Masque：登入時的模式快照、單一 Masque 群組、交格子／重套皮（見「圖示外觀：Masque」） |
| `Modules/Resources.lua`、`Modules/Pips.lua`、`Modules/AuraBar.lua`、`Modules/ResourceConditions.lua`、`Modules/Castbar.lua`、`Modules/Interrupt.lua` | 資源條、自訂格子、引擎寫層數與剩餘時間的光環條（AuraContainer ＋ SetApplicationBar／SetDurationBar／SetDurationText）、條件規則求值（純邏輯）、玩家施法條、斷法就緒，見「資源條與施法條」 |
| `EditMode/` | 編輯模式整合：`Geometry.lua`（純函式：放手位置換算回 pos、格線吸附、條對齊）、`Frames.lua`（覆蓋層、選取框、暴雪 Selection 接線）、`EditMode.lua`（拖曳、進出訊號、暴雪設定對話框） |
| `Api.lua` | slash（含 `/mcdm debug`、`/mcdm aura`、`/mcdm release`）、插件選單、公開 API `MiliUI_CooldownManager`（見「公開 API」） |
| `Tests/` | 離線測試，不進 TOC：`DB_test.lua`、`Layout_test.lua`、`Catalog_test.lua`、`EditMode_test.lua`、`Settings_test.lua`（設定介面的寫入路徑與匯出匯入）、`Custom_test.lua`（自訂項目的新增／刪除挪 id／清單排序與固定前綴）、`Keybinds_test.lua`（按鍵縮寫、動作條格 → 綁定指令）、`Resources_test.lua`（條件規則求值、資源清單依專精、法力縮寫、面板的 DB 與顯示條件（含自訂格子的面板與「核心 → 自訂格子 → 輔助」的預設錨定）、施法條的時間文字／截字／刻度查表、自訂格子的清單／規劃／容器高度／顯示時機／閘門算式、補齊的職業資源與 AuraBar 的幾何與簽章、列的順序（`ApplyOrder`／`MergeOrder`）、血量列與門檻曲線的點、施法條的暴雪材質）、`Clickable_test.lua`（可點擊群組：動作判定、簽章去重、收鈕、戰鬥中不建鈕）、`Sound_test.lua`（音效的節流、讀取畫面靜音、「消失又出現」合併抵消、AddAuraSound 對帳、音效覆寫的讀寫與分組）、`Masque_test.lua`（圖示外觀：設定值的繼承、沒裝 Masque 退回米利、登入快照與重載判斷、交格子／重套皮／戰鬥中補做）、`Import_test.lua`（從 `Ayije_CDM` 匯入：四條檢視器的位置換算、尺寸與文字、淡出、發光、資源條與條件規則、施法條、自訂群組與跨專精 pending、光環格、覆寫、報告、取名；夾具是使用者存檔去掉角色名的縮小版），用 `lua AddOns/MiliUI_CooldownManager/Tests/<名字>` 直接跑 |

套組裡哪些插件認得本插件、透過哪支 API：見「套組接線」。

引擎的硬規則（對暴雪框不 SetParent／不 Hide、不寫暴雪框的欄位、只後掛勾、秘密值只當傳遞者…）
寫在實作計畫的「引擎契約」一節，動 `Core/` 之前先看。

## 引擎

| 檔案 | 職責 |
|---|---|
| `Core/Catalog.lua` | cooldownID → 法術資料；四條檢視器各自的有序清單。玩家在暴雪面板排的順序自己解 `C_CooldownViewer.GetLayoutData()`（不問暴雪的 DataProvider，那會寫它的快取欄位）；解不開就無感退回類別集合順序。`Bar(key)` 回套好本專精 `order`／`groupOf`／`hidden` 的清單。暴雪設定面板開著時 `IsPaused()`；`CheckFresh` 輪詢版面字串最多每秒一次 |
| `Core/Layout.lua` | 純函式 `Compute(items, layout, kind)` → 每格 (x, y, w, h)、容器寬高、容器錨點；`AnchorOf`／`AnchorSide`／`StackTarget` ＝ 錨定的排開（跟著同一條同一邊的往外排，見「錨定的排開」）。不碰任何 WoW API，離線可測 |
| `Core/Viewers.lua` | 四條暴雪檢視器的後掛勾與 item 追蹤（弱鍵表 `frames[item]`）。登入退避重試等檢視器與 `CooldownViewerSettings`；戰鬥外一次把 `cooldownViewerEnabled` 打開；item 的縮放鎖 1 |
| `Core/Bars.lua` | 一條一個容器 `MiliUICDM_Bar_<key>`，錨定（pos 或錨在別條上；實際貼在誰身上由排開決定，一條變了整疊兩段式重貼）、重排排程、停放、固定格位的占位貼圖、把暴雪檢視器本體釘在容器上；`ReleaseAll` 全部還給暴雪 |
| `Core/Decorate.lua` | 邊框（自己的 overlay 框上）、圖示縮放、轉圈色、GCD 轉圈、去飽和、長條外觀；每 item 一個簽章，同簽章跳過 |
| `Core/Text.lua` | 倒數／充能／層數：改暴雪自己那幾顆 FontString 的樣式，從不寫字（為什麼見檔頭） |
| `Core/Visibility.lua` | 顯示條件與淡出，一律 `SetAlpha`；容器與每個認領中的 item 一起套（自訂項目的框是容器的子框，跟著容器的 alpha） |
| `Core/Glow.lua` | 觸發發光接管（`ActionButtonSpellAlertManager` 後掛勾）、就緒發光（探針）、無損刷新邊框色；發光一律畫在 overlay 底下自己的宿主框上 |
| `Core/Sound.lua` | 音效：就緒音效（吃就緒探針的訊號）、暴雪增益 item 的出現／消失（暴雪警示呼叫點的後掛勾＋下一幀合併）、光環格的 `C_UnitAuras.AddAuraSound` 登記對帳；節流、讀取畫面靜音 |
| `Core/Keybinds.lua` | 法術／物品 → 動作條格 → 綁定鍵 → 縮寫，畫在 overlay 一角 |
| `Core/Clickable.lua` | 可點擊的自訂圖示群組：每格蓋一顆透明的 secure 鈕（屬性戰鬥外寫好、寫入走 `ns.Write`＋簽章去重），見「可點擊的自訂群組」 |
| `Modules/Custom.lua` | 自訂項目：光環格（持有框＋AuraContainer）、自訂法術／物品的圖示框；每一格都是 Bars 的一個 entry |

登入流程：`PLAYER_LOGIN` → DB → `Loaded` → Catalog → Viewers → Custom → Glow → Sound → Keybinds → Bars
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

### 進場、換專精：暴雪正在顯示的才是真相

冷卻管理器的毛病多半「不報錯但畫面壞了」，而且集中在**進副本、被系統換專精（排隨機隊伍自動換成補師／坦克專精）、
天賦切換**這幾個時刻：暴雪會重套編輯模式版面、把整條檢視器的框放掉重取（可能生出全新的框），
而 `C_CooldownViewer` 的 API 在那幾幀回的東西不一定是最後的樣子。四道防線：

| 防線 | 位置 | 做什麼 |
|---|---|---|
| 收養 | `Catalog.Adopt(live)`，`Bars` 每次排版前叫 | 作用中、有 cooldownID 的 item 就是暴雪正在顯示的東西（暴雪只替已學會、屬於該類別的 id 設身分）。我們自己重建的清單漏了它 ⇒ 收進那條檢視器的清單尾端（照暴雪的順序），**不會因為清單過期就整格停到畫面外**；同時排 0.5／1.5／3 秒的重讀，乾淨的一輪之後額度還原 |
| 整套重來 | `Bars.Resync(reason)` | `PLAYER_ENTERING_WORLD`、`LOADING_SCREEN_DISABLED`、`ACTIVE_TALENT_GROUP_CHANGED`、`PLAYER_TALENT_UPDATE`、`TRAIT_CONFIG_UPDATED`、`EDIT_MODE_LAYOUTS_UPDATED`、專精變了 ⇒ 0／0.5／1.5／3 秒各做一輪：樣式簽章清掉、清單重讀、結構級重排。同一波事件合併成一組；事件處理器只排計時器 |
| 縮放稽核 | `Viewers.EnsureScale`，排版與同步放回時叫 | 讀一次 item 的縮放，不是 1 就壓回去並記一筆（後掛勾理論上擋得住，擋不住的那次要留下紀錄） |
| 套皮插件讓位 | `Core/Compat.lua` | 見下 |

**取出時不沿用舊身分**：`Viewers.Track` 讀 item 當下的 cooldownID（池子回收時暴雪已清掉，通常是 nil，同一輪的
`SetCooldownID` 後掛勾補上）。沿用上一輩子的身分的話，檢視器藏著時（`RefreshLayout` 不叫 `RefreshData`）那顆框會頂著舊身分被認領。

**圖示套皮插件（`Core/Compat.lua`）**：另一支插件會在每次 `RefreshLayout` 把還沒套過的 item 交給皮膚函式庫（重設遮罩／
texcoord、補外框圖，尺寸照套皮當下的 item），item 尺寸變了會重套，但戰鬥中與插件限制生效時跳過。兩邊在同一批框上
輪流蓋：登入那批相安無事，之後暴雪生出的新框就成了「它的皮＋我們的格子」的混合體（圖示比格子大、外面一圈深色框、
數字是原生字型）。圖示的長相是本插件的主題在管，所以四條檢視器都請它跳過：item 一取出就蓋上它自己的「已套皮」印記。
這是「暴雪框上一個欄位都不寫」的**唯一例外**（那個欄位只有它讀，而且它有載入才寫）；它改印記名字這裡就靜默失效。

**診斷記錄（`Core/Diag.lua`）**：上面每一道防線出手都記一行（`[adopt]`／`[resync]`／`[scale]`／`[viewer]` 檢視器被暴雪
藏起來或顯示回來），存在 `MiliUI_CooldownManager_DB.diag.log`（最近 120 行，跨登入保留）。`/mcdm debug` 印最近 6 行，
並把整份輸出＋**每顆 item 的現況**（身分、顯示、alpha、縮放、尺寸、錨在誰身上、誰認領）存進 `diag.dump`——
畫面壞掉時打一次 `/mcdm debug` 再 `/reload`，事後可以直接從 SavedVariables 讀。

## 編輯模式

進暴雪的編輯模式，每條容器上蓋一層**自己的覆蓋層**（1px 職業色邊、左上角條名、
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
- **吸附**：拖曳中離吸附點 4（UIParent 座標，固定、不隨格距放大）以內才吸。先對齊本插件其他條的邊／中心（左貼左、右貼右、並排、中心對中心，上下同理；跟著拖的這條走的不算）；那一軸沒得對，而且暴雪編輯模式的格線**看得到**時，才把容器的錨點那一邊吸到格線上。開關照暴雪編輯模式的「吸附」，設定視窗開著時一律開；Shift 按著不吸。
  放手時再走 MiliUISnap 跟套組其他框對齊（`cdm:<key>`，只做 align、同組互不對齊）。
- **拖了就脫離錨定**：錨在別條上的條（`anchor` 是表）一開始拖就把現況換算成 pos、`anchor = false`。
  進編輯模式時這種條會先蓋一行黃字「拖曳會解除跟隨「核心技能」」，放手後消失。
- **暴雪的系統設定對話框**：點到四條檢視器時藏掉（它的尺寸／方向／間距跟我們的設定不同步）。
  **不 Hide**（Hide 會從我們的執行跑暴雪的 OnHide、寫 `attachedToSystem`）：後掛勾 `AttachToSystemFrame`
  當場 `SetAlpha(0)`＋`EnableMouse(false)`，對話框與每個吃滑鼠／滾輪的子孫都關、記下來；下一次
  `AttachToSystemFrame` 的系統不是四條之一、或離開編輯模式時照記錄還回去。第一次藏時聊天框印一行
  「冷卻管理器的設定在 /mcdm，或點一下藍框開那條的設定」。對話框的內容、欄位與 `Settings` 列不碰。
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
  - 左鍵：逐法術面板。中鍵：**移除**（`Preview.Remove`，不問）。對使用者只有「移除」這一個動作——
    設定面板上有什麼，畫面上就有什麼；他不在意東西有沒有從暴雪的冷卻管理器拿掉（使用者 2026-09-30 定案）。
    暴雪清單上的法術記進 `spells[spec].hidden`（暴雪那邊不動、逐法術設定留著），自己用「＋」加的項目整筆刪掉
    （`hidden` 對自訂項目無效，`Catalog.Bar` 不看）。**移除的不畫在預覽上**，加回來一律走「＋」：挑選器第一區
    把被移除的（不分原本在哪條）灰階列在後面，點一下還原並放進這條（`Picker.PutInto`）。
    逐法術面板的按鈕是「從這條移除」＋「還原此法術」。
  - 拖曳（3px 門檻）：職業色插入線、其他格變暗 0.5，放手寫 `spells[spec].order[key]`（完整清單）；
    拖到左欄的自訂群組上＝`groupOf`，拖回原本的檢視器上＝清 `groupOf`（可放的按鈕亮職業色邊）。
    長條只能拖進長條群組、圖示只能進圖示群組。`cell.locked`（光環格的固定前綴）蓋紅色、拖不動、別的格也不能插到它前面。自訂項目拖到左欄任何圖示條上＝改它的 bar。
  - 「＋」：挑選器（已在暴雪冷卻管理器的別條項目，點了拉進來；要先去暴雪面板加的候選池＋開面板鈕；
    自訂 ID：光環格／法術／物品，見「自訂項目與效果」）。暴雪面板開著時整個鎖住，`CatalogResumed` 自動重讀。
- **表單**：版面（每列上限、間距、成長方向（橫向：往右／往左／從中間往兩側長，向下／向上換列；直向：往下／往上長，向右／向左換列）、圖示尺寸、第二列尺寸、固定格位／長條的寬高圖示材質顏色）、
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
多一列「不在時顯示占位」；「從這條移除」對自訂項目是整筆刪掉（後面的 id 往前挪：
`DB.RemoveCustom` 同步改順序、隱藏、覆寫）。刪自訂群組時，上面的光環格回增益圖示、法術／物品回核心技能。
未學會的自訂法術顯示問號（預覽、挑選器、真實條都是），滑鼠提示寫「尚未學會」。

### 可點擊的自訂群組（`Core/Clickable.lua`）

自訂的**圖示**群組（`bars.g<n>`，`kind == "icons"`、`source == "custom"`）的版面節多一個勾選「可點擊」
（`bar.clickable`，nil 當 false，不做遷移；判準只有 `DB.BarClickable`）。勾了之後每一格點下去就施放那個法術／
使用那件物品，跟快捷列按鈕一樣；提示、發光、按鍵文字、淡出都照舊。

- **做法：每一格上面蓋一顆透明的 `SecureActionButtonTemplate` 鈕**（parent 與錨點都是條的容器、座標＝那一格的
  rect、層級容器 +40、沒有任何貼圖）。屬性（`type`／`spell`／`item`／`slot`）在戰鬥外寫好，戰鬥中由引擎處理
  點擊，我們的 Lua 不碰施法 API。暴雪的 item 不能變成按鈕（不能 SetParent、不能寫欄位）；自製圖示框每次重排都
  SetPoint／SetSize／Show，也不能換成 secure 模板。
- 動作：自訂法術 `spell`＝**基底 id**（引擎自己放覆寫後的；覆寫戰鬥中會變、屬性卻鎖著）、自訂物品
  `item = "item:<id>"`（照身分不照包包格）、飾品欄 `item`＋`slot`、從核心／輔助拖進來的暴雪技能（有裝備欄就
  `slot`，否則基底 `spellID`）。光環格、增益類來源、物品冷卻類別（藥水那種一格代表一整類）、占位格、秘密值 ⇒
  那一格的鈕收起來（留著沒屬性的鈕會搶 hover，光環格的暴雪提示就出不來）。判斷是純函式 `Clickable.Resolve`。
- **強制固定格位**：鈕錨在容器上 ⇒ 容器變成隱式保護框，格子在戰鬥中不能動，鈕才跟得上。跟「條上有光環格」
  同一套（`Bars` 的 `fixed`、設定頁那一列停用＋黃字原因）。
- 寫入：鈕的 SetPoint／SetSize／Show／Hide／SetAttribute／ClearAllPoints 一律走 `ns.Write`，三種各自簽章去重
  （`place`／`action`／`shown`），沒變不寫 ⇒ 戰鬥中重排沒有保護呼叫；變了就記帳到脫戰。鈕只在戰鬥外建：戰鬥中
  需要新鈕 ⇒ 記 pending，`PLAYER_REGEN_ENABLED` 一次性要求那條重排補建。不可點擊／被刪的條 `Release`（Hide＋
  ClearAllPoints、簽章清空），已經收過的不再排寫入。
- 鈕只掛 `OnEnter`／`OnLeave`（轉給 `Decorate.HoverEnter／HoverLeave`，提示照樣錨在 overlay 上）；**不准**
  PreClick／PostClick／OnClick／OnMouseDown（同一次點擊派送裡排在 secure 動作前面的插件 Lua 會把施放染髒）。
  鈕身上不寫 Lua 欄位，狀態放 `Clickable.lua` 的弱鍵表。
- overlay 的滑鼠旗標不動，兩種疊層順序都成立：鈕在上 ⇒ hover 由鈕轉提示、點擊到鈕；item 在上（群組 strata 比
  檢視器低）⇒ hover 照舊由 overlay 收、點擊穿到底下的鈕（待實機驗證暴雪 item 自己收不收點擊）。
- **編輯模式中鈕全部收起來**（`EditModeChanged` → 有鈕的條重排、`Place` 照 `EditMode.active` 當作沒有動作）：暴雪的
  選取框模板是 MEDIUM／層級 1000，群組 strata 設得比 MEDIUM 高（或模板建不出來、用自製選取框）時鈕會蓋在
  選取框上面，拖曳變施放。戰鬥中進出編輯模式 ⇒ 收／放照 `ns.Write` 記帳到脫戰。
- ⚠ 已知限制：顯示條件／淡出是容器 `SetAlpha`，**淡到 0 的群組鈕還在、照樣收點擊**（看不見但點得到、擋住點世界）。
  鈕是保護框，戰鬥中不能跟著條件 Show／Hide；要做得用 secure 狀態驅動把能寫成巨集條件的那幾種搬過去，先看實機回報再說。
- **內建條（核心／輔助／增益／增益長條）與長條型群組不做**：內建條的格子是暴雪的框、本來就由暴雪排，等玩家
  真的有需求再說。拖曳法術進群組、右鍵／修飾鍵另外指定動作也不做。
- 離線測試：`Tests/Clickable_test.lua`（Resolve 每一列、簽章去重、EndBar／Release、戰鬥中不建鈕）、
  `Tests/DB_test.lua` 第 10 節（預設值與判準）。

### 效果（`Core/Glow.lua`、`Core/Keybinds.lua`）

- **觸發發光**：後掛勾 `ActionButtonSpellAlertManager:ShowAlert／HideAlert`，frame 是我們認得的 item 就在 overlay
  上畫 MiliUIGlow（pixel／autocast／button／proc），暴雪的 `SpellActivationAlert` 熄 alpha（不 Hide）。
  條層「觸發發光」開著（或法術覆寫成開）才接管；都關時還給暴雪。自訂法術聽 `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW／HIDE`。
- **生效發光**（增益）：暴雪增益格（增益圖示列、增益長條、搬進自訂群組的增益）在光環生效期間一直亮。**只有逐法術開關**
  （`overrides[id].activeGlow`＋可選的 `activeGlowColor`，點預覽圖示設定），條層 `glow.active` 只有樣式與預設色。
  生效看暴雪 item 的 `IsActive()`（後掛勾 `OnActiveStateChanged`）；讀不到一律不亮，「沒生效也顯示」的灰圖示不會亮。
  覆寫分組自成 `activeGlow`：條頁「清除發光覆寫」不會清掉。從 Ayije 匯入 `spellRegistry[spec].glowEnabled／glowColors`。
  自訂光環格吃同一個開關：發光在 `initializeFrame` 裡用 MiliUIGlow 的 Attach 系列建在引擎按鈕底下（按鈕只在光環存在時顯示），
  樣式／顏色／格子尺寸進容器簽章，改了換容器、戰鬥中改等脫戰。
- **就緒發光**：探針（見「與計畫不同」第 28 條）；亮 `glow.ready.duration` 秒（預設 3），期間技能用掉（進了新的冷卻，GCD 不算）就提早熄；回充中的多充能技能不提早熄（暴雪每次 GCD 都重設充能計時，分不出來）。
  「觸發」樣式在裝了 Masque 時改用 Masque 的方形循環圖（`Masque/Textures/Square/SpellAlert-Loop-Modern`，6×5、每格 84px，沒有入場動畫），
  沒裝就是暴雪的圓角圖集；只換貼圖，不碰 Masque、不讀它的設定。
  設定頁的觸發／就緒發光各有一顆「預覽」樣本圖示，常亮目前的樣式與顏色（`ns.Glow.PaintOn`／`StopOn` 與格子共用）。
- **無損刷新**：後掛勾 item 的 `ShowPandemicStateFrame／HidePandemicStateFrame`，邊框換 `pandemic.color`，
  `pandemic.bars` 時長條條身也換色；Hide 換回。暴雪的 PandemicIcon 不碰。
  圖示外觀＝Masque 時平常不畫我們的邊框，無損刷新期間才把那圈彩色邊框亮出來（粗細照設定、至少 1），Hide 藏回去。
- **按鍵文字**：`FindSpellActionButtons`（覆寫法術優先）→ 格號 → 綁定指令（主動作條目前那一頁／左下右下右側／
  動作條 6–8，照暴雪 `MultiActionBars.xml` 的 actionpage 與按鈕模板的 buttonType）→ `GetBindingKey` → 縮寫
  （Shift→s、Ctrl→c、Alt→a、滑鼠鍵→M4、數字鍵盤→N5…）。物品掃動作條格子。綁定／動作條事件 0.2 秒合併重算。
- 發光宿主是 overlay 底下自己的框，尺寸由排版給（不從 item 讀）；停放時發光一律熄。

### 圖示外觀：Masque（`Core/Masque.lua`）

- 設定：圖示那一節最前面的「圖示外觀」（`icon.skin`：`"miliui"` 預設｜`"masque"`），走主題 → 條的繼承（跟「圖示」那一節的跟隨）。
  沒裝 Masque 一律當米利樣式（下拉停用＋灰字說明）。選 Masque 時邊框材質／粗細／顏色、圖示縮放四列停用（暗色遮罩，值不動）。
- **切換要重載**：每條的模式在引擎第一次排版時快照（`ns.Masque.Mode`），整個工作階段固定；設定值（`Desired`）
  跟快照不同時設定頁跳確認框（確認＝`ReloadUI`，取消＝留著設定、下次重載生效，同一組合不再追問）。
  預覽也照快照畫（畫面上真實條的樣子）。
- Masque 裡只有一個群組（插件「MiliUI Cooldown Manager」底下的「圖示」，ID 固定、換客戶端語系不換群組），皮膚、顏色、縮放在 Masque 自己的設定選；
  「開啟 Masque 設定」按鈕走 `/msq`（`SlashCmdList.MASQUE`，Masque 沒有公開的開設定函式），先關自己的設定視窗。
- 分工：Masque 畫邊框（皮的外框圖）、圖示縮放、轉圈材質、圖示遮罩；倒數／充能／層數文字、轉圈色、去飽和、隱藏 GCD、
  發光、按鍵文字、淡出、提示 overlay 照舊是我們的。`AddButton` 一律給完整 regions＋Strict：圖示型
  `{ Icon, Cooldown }`（自訂法術多一個回充的 `ChargeCooldown`），型別 `"Action"`，增益圖示 `"Debuff"`；長條型交 `item.Icon`
  那一層、`{ Icon = item.Icon.Icon }`、`"Debuff"`。不給 Count：文字不交出去，Masque 也不去 item 上找欄位。
  固定格位的佔位與設定頁的預覽格（我們自己的框）也交給同一個群組。光環格（AuraContainer）維持米利樣式：按鈕建好就 forbidden。
- 尺寸變了才 `ReSkin`（Masque 套皮時照按鈕當下的尺寸算比例）。寫入走 `ns.Write`：戰鬥中按鈕在保護鏈上就記帳、脫戰補做，
  補做之前那一格照米利樣式畫，補完重套一次。按鈕幾何讀不到（秘密錨點）就不交。
- 契約例外：Masque 會在交出去的暴雪 item 上寫 `_MSQ_CFG`、在 Icon／Cooldown 上寫 `_MSQ_*`、建外框圖與遮罩；我們自己不寫任何欄位
  （見 `Core/Masque.lua` 檔頭，與 `Core/Compat.lua` 的印記並列）。MasqueBlizzBars 照舊被印記請走，不會重複套。
- 玩家在 Masque 裡停用我們的群組：Masque 自己把按鈕還成預設皮；我們的回呼把邊框、縮放、方角轉圈畫回來並提示 /reload
  （Masque 預設皮的外框圖與圖示尺寸收不乾淨；重載後群組停用＝不套皮，畫面是乾淨的米利樣式）。重新啟用時 Masque 重套、我們收邊框。

### 音效（`Core/Sound.lua`）

響什麼是**逐法術**設定（逐法術面板：冷卻類一列「就緒音效」，增益類兩列「出現音效」「消失音效」；下拉第一項
「無」＝清掉覆寫，其餘是 LibSharedMedia 的音效名，開面板時才列、依名稱排序；旁邊「試聽」照目前聲道播一次，
不看總開關）。沒有條層的值（`DB.SPELL_CONST` 給 false）。全域只有 `theme.sound = { enabled, channel }`
（主題頁「音效」一節：總開關、聲道 Master／SFX／Music／Ambience／Dialog）。
音效來源：本插件內建一批（`Media/Sounds/`，載入時註冊進 LibSharedMedia，名稱沿用原註冊名），加上其他插件註冊的。
註冊是全域的，所以套組裡其他讀 LibSharedMedia 的插件（嗜血音樂、BigWigs…）也選得到這批音效。
萬一清單是空的（理論上不會發生），下拉只剩「無」，面板多一列灰字說明。

| 觸發 | 做法 |
|---|---|
| 就緒（暴雪核心／輔助 item、自訂法術／物品） | 跟就緒發光同一顆探針的 `OnCooldownDone`（`Core/Glow.lua`）。只設了音效沒開發光也照樣建探針、武裝；GCD 不算、多充能每回一層響一次（探針現況）。暴雪 item 自己的 `TriggerAvailableAlert` 只在玩家替那個法術設了暴雪警示時才被 OnUpdate 叫到，不能當通用訊號 |
| 暴雪增益圖示／增益長條 item 出現／消失 | 後掛勾 item 的 `TriggerAuraAppliedAlert`／`TriggerAuraRemovedAlert`（12.1.0.69933 的 `Blizzard_CooldownViewer/CooldownViewer.lua`，`CooldownViewerMixin:OnUnitAura` 裡先 `CheckAuraRemovedAlertTriggers`、後 `CheckAuraAddedAlertTriggers`；不管有沒有設暴雪警示都會叫）。掛勾本體只拿 item 查我們的弱鍵表拿明文 cooldownID。事件進批次、下一幀合併：同一格「消失又出現」（換光環實例的刷新）抵消不響（`Logic.Net`：第一個事件推之前狀態、最後一個事件是之後狀態）。這兩支哪天沒了退回 `OnActiveStateChanged` 後掛勾＋`IsActive()`／`IsShown()` 前後比對（讀得到才算） |
| 光環格出現／消失 | `C_UnitAuras.AddAuraSound(Enum.UnitAuraSoundTrigger.Added／Removed, { unitToken = "player", spellID, soundFileName 或 soundFileID, outputChannel, throttleSeconds = 1.5 })`，回傳 `auraSoundID`，`RemoveAuraSound(id)` 撤銷；引擎自己播。對帳（`Logic.Diff`：多的撤、少的登、同簽章不動）在光環格放好／收起、設定檔／專精換了時排到下一幀。**戰鬥中或 `C_Secrets.ShouldAurasBeSecret()`（副本、鑰石、PvP）不叫**（封鎖動作、pcall 攔不住），排到脫戰／首領戰結束／換區域／鑰石完成再試；`PLAYER_ENTERING_WORLD` 撤掉手上的全部重登（不跨 /reload） |

- 播放：`PlaySoundFile(路徑或檔案編號, 聲道)`；LSM 取出來是字串或數字都能播。
- 節流：同一個法術同一種音效 1.5 秒內只響一次；讀取畫面中與結束後 2 秒內（`LOADING_SCREEN_ENABLED／DISABLED`、
  `PLAYER_ENTERING_WORLD`）靜音。這兩條只管我們自己 `PlaySoundFile` 的那兩種；光環格由引擎播，只能給 `throttleSeconds`。
- 覆寫分組：三個音效欄位是 `DB.OVERRIDE_GROUP` 的 `"sound"`，條頁自成一節「音效」（「本條 N 個法術有覆寫」＋
  「清除覆寫」），**不跟「效果」節的發光算在一起**：清發光覆寫不該順手把玩家挑好的音效清掉，而且音效沒有條層的值，
  「跟隨全域主題」對它沒有意義。逐法術面板的「還原此法術」照樣整筆清（含音效）。
- 圖騰型的增益（不是光環）不經過 `UNIT_AURA`，暴雪那兩支警示不會叫 ⇒ 沒有出現／消失音效。
- 被移除（記在 `hidden`）的增益照樣響：音效是逐法術明確設的，而收合模式下沒顯示的增益本來就是停放狀態，拿停放當閘會把正常的出現音效也擋掉。
- `/mcdm debug` 的「音效」一行：總開關、聲道、光環格登記筆數（待登記）、增益掛勾方式（alert／active）、播過幾次（擋掉幾次）、最近一次播放。

## 資源條與施法條

三者都是**面板**：資源條、自訂格子（`pips`）、施法條。不在 `bars` 裡（沒有版面／主題繼承），設定在
`profile.resources`／`profile.pips`／`profile.castbar`，資源條與施法條在左欄有自己的頁（自訂格子的設定在資源條頁）；
但**錨定語意跟條一模一樣**（`pos = { point, x, y }`、`anchor = false | { to, point, relPoint, x, y }`），
容器也是 `MiliUICDM_Bar_<key>`、走 `Core/Bars.lua` 的同一套 `ApplyStructure`、編輯模式覆蓋層／選取框／磁吸、點擊層。

| 位置 | 內容 |
|---|---|
| `Core/DB.lua` | `DB.PANEL_KEYS`／`DB.PANEL_ORDER`（`resources`、`pips`、`castbar`；順序＝顯示條件套用與錨定候選的順序）、`DB.ConfigTable(key)`（條或面板的設定表：錨定、編輯模式、設定頁的 `root = "bar"` 都走它）、`RESOURCE_COLORS`（資源預設色的單一來源）、三張預設表 |
| `Core/Bars.lua` | `B.RegisterPanel(key, { anchorPoint, minSize, relayout, collapsible })`：建容器（連帶 `EditMode.OnContainer`）、照存檔貼位置；`B.SetPanelSize`（走 `ns.Write`；`collapsible` 的面板收 `h = 0`，見「自訂格子」）；`B.FirstRowWidth("essential")`，核心技能第一列寬度變了廣播 `FirstRowWidthChanged`。排程對面板只做結構級，內容交給模組的 `relayout` |
| `Core/Visibility.lua` | `Vis.EvaluatePanel`／`PanelAlpha`（見下），一律 alpha；面板排在條後面套（資源條要讀核心技能剛算好的 alpha） |
| `Options/Specs.lua` | `Specs.Anchor(key, opts)` 對面板照用；`opts.other` ＝ 讀寫的不是這張表單自己的條（資源條頁上的自訂格子）：spec 的 root 換成 `"bar@pips"`（numbers 型的子格只把 root／sub 往下傳，所以目標帶在 root 上），`MakeCtx` 與右鍵重設都認得；錨定候選＝`barOrder` ＋ `PANEL_ORDER`（排除成環）；表單簽章多了整張錨定圖（別條的錨定一變，候選清單就要重算） |
| `Options/Panel.lua` | 沒有自己一頁的面板：`Options.HostPage("pips") == "resources"`（`ShowPage`／`FocusBar` 照它轉，點擊層點了開資源條頁）、`Options.PageTitle("pips")` 回「自訂格子」（覆蓋層條名、錨定候選、點擊層提示） |

容器的錨點：資源條 `BOTTOM`（預設錨在核心技能上緣、往上長，列數增減時下緣不動）、自訂格子 `TOP`（預設錨在
核心技能下緣、往下長）、施法條 `CENTER`。寬 0 ＝ 核心技能第一列寬（施法條含圖示；自訂格子照資源條的 `width`）。

預設的上下疊法（使用者 2026-09-30 指定；增益圖示 2026-10-01 加入）：增益圖示 → 施法條 → 資源條 → **核心技能 → 自訂格子 → 輔助技能**。
五個的 `anchor.to` 全部是 `essential`（資源條、施法條、增益圖示在上方；自訂格子、輔助技能在下方），先後由排開決定。

### 錨定的排開（`Core/Layout.lua` 的 `StackTarget`）

設定裡的錨定是「跟著誰、在它哪一邊」。照字面各自貼上去的話，兩個東西都選「核心技能上方」就疊在一起，
所以**實際貼在誰身上是算出來的**：

- 跟著同一個目標、同一邊的算一疊，照固定順序往外排：資源條 → 自訂格子 → 輔助技能 → 施法條 → 增益圖示 →
  增益長條 → 自訂群組（照左欄順序）。後面那個貼在前面那個的外緣，邊與偏移照自己的設定。
- 前面那個自己身上同一邊還掛著東西（有人指名跟著它）⇒ 貼在那一串的最外面。
- 目標關掉了、而且它自己也掛在同一邊 ⇒ 當它不存在，接到它的上一層（資源條關掉，施法條貼回核心）。
- 目標掛在**相反**那一邊（輔助「在自訂格子下方」，而自訂格子在核心「上方」）⇒ 那個位置一定壓到東西，
  改排到上一層的那一邊去（輔助排到核心下方）。
- 四個邊以外的錨定（置中對置中之類）不參與，照字面貼。

`Core/Bars.lua`：`PlaceContainer` 貼在 `StackTarget` 回的那條上，記在 `state[key].stackTo`。任何一條重套結構時
先找出「該貼的跟現在貼的不一樣」的其他條，**兩段式**重貼（先全部 `ClearAllPoints`、再各自 `SetPoint`）：逐條直接貼會在
過渡狀態撞上「甲還貼著乙、乙卻要改貼甲」，`SetPoint` 當場報錯。戰鬥中整疊記帳到脫戰。關掉的面板照字面貼在它的
目標上（不佔位，但容器身上不留舊錨）。編輯模式一開始拖曳就 `B.Restack()`：被拖的那條脫離之後，疊在它外面的補位。
`/mcdm debug` 的「跟隨」欄在兩者不同時寫成「essential（貼 resources）」。

### 資源條（`Modules/Resources.lua`）

從單位框架的資源條與能量條改來。專精 → 資源清單（`SPEC_RESOURCES`）；德魯伊看型態（熊怒氣、貓能量＋連擊點、
其餘照專精）；用法力施法的專精（`MANA_SPECS`）在職業資源下面多一列法力；每個專精最後都多一列**血量**（預設關）。一種資源一列：

| 模式 | 資源 | 畫法 |
|---|---|---|
| bar | 怒氣、能量、集中值、符文能量、星能、元能、狂亂值、魔怒、**法力** | 一顆 StatusBar：`SetMinMaxValues(0, UnitPowerMax)`＋`SetValue(UnitPower)` **直接餵**（引擎收秘密值），明文且上限 <= 0 才顯示空條；原生內插（`smooth`） |
| bar（`def.get`） | **醉仙緩勁**（釀酒）、**噬靈魂碎片**（噬魂者 1480） | 醉仙緩勁：`SetMinMaxValues(0, UnitHealthMax × 滿條%)`＋`SetValue(UnitStagger)` 直接餵；三段色（輕／中／重，門檻預設 30%／60%；另有第 3／4 段 `staggerTier3At`／`staggerTier4At`，預設 90%／150%、預設關，各自一個開關與顏色，`R.StaggerBand`／`R.StaggerTiers` 純函式、高的段先比；滿條上限 `staggerCeiling` 1～300，超過 100 才看得到第 4 段）**只在兩個值都是明文時**算比例，秘密值那幾下（副本戰鬥中間歇出現）沿用上一段顏色與上一次的明文上限，從沒讀到過明文就把秘密的最大生命原樣餵（＝ 滿條 100%）。噬靈魂碎片：光環層數（化身中 1227702、平常 1225789），上限 40／50（天賦 35、PvP 天賦 +50） |
| bar（`def.get`、`health`） | **血量**（每個專精都是候選，`R.DefaultOn` 一律回 false：在「這個專精要顯示哪些」勾起來才顯示；不在 `RawList` 裡，`R.Candidates` 接在最後） | `UnitHealth`／`UnitHealthMax` **直接餵** `SetMinMaxValues`／`SetValue`（12.1 連脫戰都是秘密值，Lua 不比較不算術）、`smooth` 照連續條。顏色：`healthClassColor`（預設）職業色、關掉用 `colors.Health.color`（預設綠）；**門檻換色**（`healthThresholdEnabled`＋`healthThresholds`，`{ pct = 1..99, color }` 最多 6 筆）照單位框架的血量門檻：由低到高 → Step 色彩曲線（x 是 0～1 比例；`R.HealthCurvePoints` 純函式）→ `UnitHealthPercent("player", nil, 曲線)` 由 C 端挑色 → 填充 `SetVertexColor`。曲線物件建一次、點在**排版時**比簽章（`R.HealthCurveSig`）變了才重建，`UNIT_HEALTH` 上不碰；挑出來的顏色可能是秘密值，暗底一律用明文底色算。數字：縮寫沿用 `manaAbbrev`；`healthPercent` 印百分比（秘密值時 `UnitHealthPercent("player", nil, CurveConstants.ScaleTo100)`）。條件規則不適用（`R.SupportsConditions` 回 false，條件編輯器的候選也不列） |
| auraPct | **無視苦痛**（防戰） | **引擎寫百分比**（2026-10-02）：增益 190456 的「層數」欄位是盾量佔上限的百分比（0～100）。一顆單格 AuraContainer（`includeSpellIDs { 190456 }`）＋`SetApplicationBar(bar, { maxApplications = 100 })`，列上的裝飾畫成**連續條**（暗底＝主色 × 0.25、不分格）。只算這個增益自己的盾（別人套的盾、其他吸收不算）。`showText` 開著時層數走 `SetApplicationCount(fs, {})`——**不給格式器**（引擎拿格式器處理秘密層數會整顆容器壞掉），後面另一顆固定字的 FontString 印「%」，兩顆都錨在按鈕中線上、不互相錨定；字型／字級進簽章（`spec.count`）。條件規則不適用（`R.SupportsConditions` 回 false）。容器沒好（戰鬥中、建失敗）時 `R.DrawMode("auraPct", false)` 退回下一列的 absorbBar |
| absorbBar | 無視苦痛的**退路** | 值 `UnitGetTotalAbsorbs("player")`、上限「最大生命的三成」**用幾何做**：裁切框（`SetClipsChildren`）＝ 列，裡面一條寬 W／0.3 的 StatusBar 貼在填充起點那一側，`SetMinMaxValues(0, UnitHealthMax)` ⇒ 只看得到前三成。**不對秘密的最大生命乘 0.3**；這條的填充貼圖上不錨任何東西。顯示的是**身上所有吸收盾的總量**（說明列寫明） |
| pip | 聖能、連擊點數、真氣、靈魂碎片、秘法充能、精華、符文；漩渦之武、矛尖、靈魂碎片、**冰刺**（光環／施放次數型） | **每格一顆 StatusBar**：`SetMinMaxValues(i-1, i)`＋`SetValue(目前值)` ⇒ 第幾格亮由引擎決定，秘密值照樣畫得對。格子一律錨在列上（`SetValue(秘密值)` 會讓那顆條的幾何變秘密、傳染給錨在它身上的框） |
| pip（碎片零頭） | **毀滅術**（267）的靈魂裂片（`def.fractionalSpec`；痛苦、惡魔照整數） | 讀原始單位 `UnitPower("player", SoulShards, true)`（一顆 ＝ `per` 單位；`R.ShardPer` ＝ 原始上限 ／ 整顆上限，讀不到 10）：第 i 格 `SetMinMaxValues((i-1)·per, i·per)`＋`SetValue(原始值)`，零頭由引擎畫、秘密值照樣對。明文時 `R.ShardSplit` 算整顆數與正在累積的那一格：那一格用主色 × 0.55（跟符文回充同一個係數），文字 `%.1f`（3.7），條件規則吃整顆數；秘密時只畫填充、不印字、不套條件 |
| pip（精華回充） | 喚能師的精華（`fill = "essence"`） | 明文且未滿時下一格（第 cur+1 格）畫回充進度：`SetValue(cur + 進度)`、那一格主色 × 0.55。進度來源 `UnitPartialPower("player", Essence)`（0～1000，明文且 > 0 才用）；拿不到 ⇒ `GetPowerRegenForPowerType(Essence)`（每秒幾顆，明文才收、記住上次的）×「這一輪回充開始到現在的秒數」（精華變多或從滿的掉下來時重算起點，`R.EssenceFrac` 純函式）；兩者都沒有就不畫。跟符文共用 0.1 秒 ticker（有格子在回充才跑，滿了就停）。數值文字照印整數 |
| pip（摺疊） | 氣漩武器（`def.foldable`、`maelstromFold`，**預設關**） | 10 層摺成 5 格：每格疊兩顆 StatusBar，底層 `(i-1, i)`、上層 `(i+4, i+5)`（`R.FoldRange`）同樣 `SetValue(層數)`；上層也錨在列上、層級高一階、自帶 1px 黑邊、沒有暗底，顏色是 `colors.MaelstromWeapon.overflowColor`（預設金黃）。條件規則：整條的覆寫（暗底、透明度、文字色）照舊，逐格顏色只套底層（格子序號 1～5）。預設關是因為使用者調好的 ≥9／≥10 兩段換色是照 10 格寫的 |
| pip（符文） | 符文 | **先排序再畫**：轉好的靠左（照編號）、在轉的依剩餘時間往右排（`R.RuneOrder`）；在轉的格子 `SetValue((now−start)/duration)` 填進度、同色暗一階，排隊中（start 在未來）進度 0。數字由 `showText` 總開關＋`runeText` 二選一：`countdown`（預設，在轉的格子印剩餘秒數、無條件進位）／`count`（中間印轉好的顆數），兩者不並列。有符文在轉時開 0.1 秒 ticker 只重畫符文列，全部轉好就停。start／duration／ready 讀不到明文 ⇒ 不填不印、排最後 |
| auraBar | **旋風斬**（狂怒，4 層）、**橫掃攻擊**（武器，12 層，點了 1261049 是 18）、**鐵鬃**（守護熊形態，一層一格、5 格） | **引擎寫**（`Modules/AuraBar.lua`）：這幾個增益連戰鬥外 `GetPlayerAuraBySpellID` 都可能回 nil。旋風斬／橫掃攻擊：一顆單格 AuraContainer（`AddAuraSlot`＋`includeSpellIDs`、player、HELPFUL），`initializeFrame` 裡把整列寬的 StatusBar 交給按鈕的 `SetApplicationBar(bar, { maxApplications })`，引擎每次套用寫 `SetMinMaxValues(0, max)`＋`SetValue(層數)`（光環消失寫 0）。鐵鬃每施放一次是**一顆獨立的光環**（層數欄是 0），改用 `AddAuraGroup`（`maxFrameCount` ＝ 格數、`layout` 的 elementWidth／Height／Spacing ＝ 一格），每顆按鈕的 StatusBar 交給 `SetDurationBar(bar, { direction = RemainingTime })`：一格一層、各自倒數。格子外觀（暗底、黑邊、分隔）是列上另外畫的裝飾；整列寬的填色第 k 層終點落在第 k 個格距裡，被分隔蓋住。條件規則與數值文字不適用（Lua 沒有值），設定頁寫明 |
| auraTimer | **黯黑力量**（增輝喚能師，增益 395296、天賦閘 395152）、**秘法靈魂**（秘法法師，增益 451038＋1223522、天賦閘「歐爾的記憶」449619 或英雄樹 39 Sunfury） | **光環剩餘時間條，引擎寫**（`Modules/AuraBar.lua` 的 `kind = "duration"`）：一顆單格 AuraContainer（`AddAuraSlot`＋`includeSpellIDs`、player、HELPFUL），`initializeFrame` 裡把整列寬的 StatusBar 交給 `SetDurationBar(bar, { direction = RemainingTime, interpolation = Immediate })`：光環在身上時由引擎往下縮（上限＝光環自己的持續時間，含黯黑力量的延長，Lua 不必知道秒數）、光環不在時按鈕藏起來，看到的是列上畫的空條（暗底＝主色 × 0.25、1px 黑邊）。`showText` 開著時另建一個 FontString 交給 `SetDurationText`（formatter `Text.PlainFormatter(5)` 在容器建立前先建好：剩 5 秒起一位小數），字型／字級進簽章。秘法靈魂多一個 `arcaneSoulText = "gcd"`（剩幾個 GCD）：建容器前用明文算 GCD 長度（`R.ReadGcd`：`C_Spell.GetSpellCooldown(61304)` 正在 GCD 的 duration；不在 GCD 或讀不到 ⇒ 1.5 ／（1 ＋ 加速 ／ 100）；再讀不到用上次的、沒有就 1.5；夾 0.75～1.5、四捨五入到 0.05 秒），`Text.GcdFormatter(g, "最後")` 建一顆 NumericRuleFormatter：門檻 0 印「最後」（這一段沒有數字格式符）、門檻 g 印 `%d`（元件 `div = g`、`step 1` 往上取 ⇒ ceil(剩餘 ／ g)）。GCD 長度進簽章，`UNIT_SPELL_HASTE`（法師）上重算、變了才重排（戰鬥中照舊記旗標、脫戰補）。容器沒好（戰鬥中、建失敗）時先畫空條（`timerIdle`）。條件規則不適用；`GetValue` 對這種列固定回 0, 0（不讀光環） |

- **跟單位框架不同的兩件事**：那邊不做法力（單位框有自己的能量條）、也剔掉「單位框能量條已經在畫的主資源」；
  這裡是獨立 HUD，兩件都做。
- **秘密值讀不到 ≠ 畫不出來**：醉仙緩勁、吸收盾的數字 Lua 讀不到，但 StatusBar 直接收秘密值（跟法力條同一招，當傳遞者）；
  讀不到的只有「數值文字」與「條件規則」，那兩樣明文時才做。
- **auraBar 讓面板變保護框**：AuraContainer 是受保護的 intrinsic，保護沿父層往上傳到列、資源條面板 ⇒ 戰鬥中面板是保護框時
  （`ns.IsProtectedFrame(root)`）**不重排**、記旗標、`PLAYER_REGEN_ENABLED` 補（值照常重畫）。容器戰鬥中不建（記帳、脫戰建；
  期間退回明文的點數型），樣式（顏色、材質、透明度、格數、方向）進簽章、變了換一顆容器（池化在列的持有框上）；
  `initializeFrame` 整段 xpcall、不 CreateColor、不掛 script；容器層的 Show／Hide 走 `ns.Write`。
- **天賦閘**：標準資源看 `UnitPowerMax > 0`（秘密值當有）；光環型／取值型看被動已學（冰刺、噬靈魂碎片不需要天賦），
  被動 ID 寫錯的保險是「目前有層數就顯示」。剩餘時間條沒有 Lua 讀得到的值、沒有這條保險，改成「被動已學 **或** 目前的英雄天賦樹是
  `def.heroTree`」（`C_ClassTalents.GetActiveHeroTalentSpec`，明文才比）。
- **這個專精要顯示哪些**（`resources.rows[specID][key]`，**分專精**；nil ＝ 照那個專精的預設 `R.DefaultOn`、true／false ＝ 強制）：
  `R.RowOn(cfg, specID, key)` 讀、`R.SetRow` 寫（跟預設一樣就清掉、空子表也拿掉）。DB v3 遷移（`Core/DB.lua` 的 `MIGRATIONS[3]`）把舊的平面
  `rows[key]`（整份設定檔共用）攤到每個「這個 key 是候選」的專精（`R.SpecCandidates`：德魯伊三種型態併起來、每個專精都有血量；
  `R.MigrateFlatRows`：值跟那個專精的預設不同才寫、平面的鍵拿掉、新形狀已有的值不蓋、跑兩次結果一樣）。
  專精 → 候選的資料在 `Resources.lua`，遷移呼叫 `ns.Resources` 的純函式：遷移只在 `DB.Init`（登入）與匯入設定字串時跑，那時 TOC 的檔案都載完了；
  萬一沒有 `ns.Resources` 就什麼都不動（平面鍵留著，`R.RowOn` 不認字串鍵，等於回到預設）。
- **列的順序**（`resources.order`，資源 key 的陣列，**整份設定檔共用、不分專精**；開關則是分專精的，見上一條）：
  `R.ApplyOrder(list, order)`（純函式）——在 `order` 裡的照它的位置；不在的維持專精清單的相對順序、排在所有排過的**後面**；穩定。
  套在 `R.Candidates()` 的結果上再快取，所以畫面、設定頁、`/mcdm debug` 都是同一個順序。「法力、血量在最下面」只是預設位置。
  設定頁每列勾選框右邊有上移／下移（第一列的上移、最後一列的下移停用）：按下把目前候選的**完整順序**交換後寫回
  （`R.MergeOrder`：這個專精的順序在前，舊 `order` 裡別的專精排過的 key 照原相對位置接在後面），`R.Apply()`，表單照簽章換一份
  （候選順序本來就在簽章裡）。兩個專精共有的 key（法力、血量、能量…）在一邊調了另一邊也跟著。「恢復預設」清掉 `order`。
- **資源名**：暴雪全域字串（`STAGGER`…）或 `C_Spell.GetSpellName`（冰刺、無視苦痛、旋風斬、橫掃攻擊、鐵鬃、黯黑力量、秘法靈魂——後兩個取**光環**的法術名；醉仙緩勁的中度／重度色
  標籤是暴雪自己的減益名 124274／124273），載入當下讀不到時 `R.Name` 之後再問一次。

**做不到／沒做**（跟另一支參考實作的資源條比對過，2026-09-30）：

| 資源 | 原因 |
|---|---|
| 無視苦痛「只算自己這顆盾」 | **補了**（2026-10-02）：Lua 讀不到，但引擎讀得到——光環層數（＝佔上限的百分比）交給 AuraContainer 的 `SetApplicationBar` 寫，見上表的 auraPct。原本「只在追蹤了暴雪增益圖示時才讀得到」是 Lua 讀取的限制，引擎寫值不受影響 |
| 鐵鬃「依施放推算」 | 引擎的 AuraGroup 已經給得出每一層的真實剩餘時間，不必用施放事件猜（推算不含延長效果、戰鬥中身分讀不到） |
| 增輝喚能師的黯黑力量、秘法法師的秘法靈魂 | **補了**（2026-09-30）：新增 auraTimer 模式，見上表。光環 ID 以 wowhead 核對；參考實作的秘法靈魂是「秘法奔騰結束時」給、固定 4 秒，wowhead 的「歐爾的記憶」寫「秘法鳳凰消失時」給、4 秒——ID 一致（451038），觸發時機的差異不影響做法（只看增益在不在） |
| 醉仙緩勁的數值文字、條件規則（秘密值那幾下） | 秘密值不能比較、不能算術；明文時照常 |
- **條件規則**（`Modules/ResourceConditions.lua`，純邏輯）：形狀跟單位框架的資源條一模一樣（`conditions[key] = { rule… }`，
  第一條成立的勝出、`target` 指定第幾格、`and` 巢狀、深度上限、壞資料當不成立）。**只在值是明文時求值**：
  秘密值下整段不求值（照主色）、數值文字不印、充能格照常（充能索引是另一支 API）。
  預設規則（聖能 ≥5／≥3、氣旋武器 ≥10／≥9 換色）是 `Core/DB.lua` 的 `Atomic` 表：設定檔**沒有** `conditions` 才整張給
  （新設定檔、恢復預設），已經有的（含空表）一個字都不合併——否則預設規則的欄位會併進玩家自己的規則，刪光也會被補回來。
  Ayije 匯入照樣蓋過預設（匯入記自己寫過哪些資源，不看 `conditions[key]` 是不是 nil）。
- **格距 0**：每格自帶 1px 黑邊，間距 0 時兩條邊並排成 2px ⇒ 一格一框的（點數型、自訂格子）重疊 1 實體像素共用一條邊
  （`R.SegLayout`），引擎畫的格子裝飾第 2 格起不畫左邊（`AuraBar.lua` 的 `LayoutDecor`）。
- **法力數字**：`manaAbbrev` = none／k（K、M）／wan（萬、億；中韓預設）；`manaPercent` 印百分比。
- **事件**：`UNIT_POWER_FREQUENT`（＋`UNIT_POWER_UPDATE` 當回滿保底）、`UNIT_MAXPOWER`、`UNIT_DISPLAYPOWER`、
  `UPDATE_SHAPESHIFT_FORM`、`PLAYER_SPECIALIZATION_CHANGED`、天賦、進出載具、`RUNE_POWER_UPDATE`（死騎）、
  `UNIT_POWER_POINT_CHARGE`（盜賊）、`UNIT_AURA`（有光環型資源的職業：薩滿、獵人、惡魔獵人、德魯伊、法師、武僧）、
  `UNIT_HEALTH`／`UNIT_MAXHEALTH`（每個職業都註冊：血量列；沒有血量列時只有武僧（醉仙緩勁每跳扣血）與戰士的 `UNIT_MAXHEALTH` 會重畫）、
  `UNIT_ABSORB_AMOUNT_CHANGED`（戰士：無視苦痛的退路）、`UNIT_SPELL_HASTE`（法師：秘法靈魂印 GCD 時，GCD 長度變了才重排），
  全部綁 `player`、**只標髒、下一幀做**。auraBar／auraTimer／auraPct 的列不需要事件（引擎自己寫）。
  符文與精華的回充進度沒有事件：共用一個 0.1 秒 ticker（`R.ArmTicker`），有格子在回充才跑、全部好了就停。
  能量事件走「只重畫值」那條（不重算清單、不配表）；清單／格數／尺寸變了才重排。
- **顯示條件**：`enabled`、`loadConditions`（騎乘或坐載具時隱藏、只在戰鬥中）任一不符 ⇒ alpha 0；
  `fadeWithEssential` 開著時取核心技能現在的 alpha（它的顯示條件與淡出一起帶過來）。容器不是 secure 框，Lua 判斷即可。
- 列是池化的（frame 刪不掉），換專精只換內容；條件規則套上去的透明度／文字色換列時先還原。

### 自訂格子（`Modules/Pips.lua`，面板 `pips`）

玩家自己加的列：追蹤一個法術的**充能**或自己身上某個光環的**層數**，一組一列。**自己的面板**
（容器 `MiliUICDM_Bar_pips`），預設**排在核心技能下方、輔助技能上方**（兩個都跟著核心技能下方，排開之後輔助在它外面，有列時自動往下讓）。
從資源條拆出來時的分工：

| 東西 | 存在哪 | 說明 |
|---|---|---|
| 清單 | `profile.resources.customRows[specID]` | 沒動（每個專精一份，形狀見下） |
| 樣式 | `profile.resources` | 列距、格距、材質、填充方向、填充透明度、寬（0 ＝ 核心技能第一列）**沿用資源條**，不另開一組；**列高與顏色是每一列自己的**（`entry.height`，沒存 ＝ 8，範圍 2～30；`Pips.CustomHeight`） |
| 位置 | `profile.pips` | `{ enabled = true, pos = { point = "CENTER", x = 0, y = -250 }, anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 }, fadeWithEssential = true, loadConditions = { hideMounted = false, onlyCombat = false }, strata = "MEDIUM" }` |

清單的純函式（`CustomRowList`／`FindCustomRow`／`AddCustomRow`／`RemoveCustomRow`／`ClampSegments`／
`PlanCustomRows`／`CustomColor`／`CustomValue`）**整組搬進 `ns.Pips`**，設定頁改呼叫 `ns.Pips.*`；
`Modules/Resources.lua` 不再有任何自訂格子的程式，只出借 `R.Plain`／`R.AuraStacks`／`R.Edges`／`R.Width`／`R.DIM`。

```lua
customRows[specID] = {
    { kind = "charges" | "stacks", spellID = n,
      max = n,             -- stacks：格數（1–10，預設 5）；charges：新增時記下的充能上限，只在 API 讀不到時用
      color = { r, g, b, a },   -- 新增時預設職業色
      showTime = true,     -- charges 的「下一格」顯示回充秒數
      showWhen = nil,      -- nil／"always" ＝ 一直顯示；"active"（充能：回充中；層數：有光環）；"activeOrCombat"（充能限定）
      enabled = true },    -- false ＝ 不建列（目前沒有介面開關）
}
```

- **收合的面板不佔位（2026-09-30 修正）**：原本沒有列時把容器設成高度 0、讓輔助技能照樣貼在它身上。**高度 0 的框在遊戲裡
  沒有有效的矩形，貼在它身上的整條都畫不出來**——沒有自訂格子的專精（被系統換成神聖、或根本沒設格子的角色）輔助技能
  整條消失，設定頁的預覽卻是滿的（清單沒問題，是容器沒位置）。現在收合是邏輯狀態（`state.collapsed`）：框留 1 的高度，
  排開時別人跳過它接到上一層（`Layout.StackTarget` 的 `skip`）；展開／收合一切換，整疊兩段式重貼。下面這一條是原設計：
- **收合（沒有列就高度 0）**：`B.RegisterPanel("pips", { collapsible = true })`。沒有任何一列（清單空、全部 `enabled = false`、
  充能法術都沒學、`pips.enabled = false`）時 `SetPanelSize("pips", w, 0)`，而且上下向錨定（TOP↔BOTTOM）的 **y 偏移一起收掉**
  （`Core/Bars.lua` 的 `PlaceContainer`）：核心 → 自訂格子（0 高、0 偏移）→ 輔助（−1）＝ 輔助照舊在核心下方 1px，跟改版前一模一樣；
  有列時偏移回來，間距是「核心 −1 → 格子 → −1 輔助」。收合狀態一變就重套結構（戰鬥中記帳到脫戰）。
  關掉的面板容器是藏著的，但位置照樣對好（照字面錨在它身上的東西要有個位置）。
- **規劃**是純函式 `Pips.PlanCustomRows(cfg, specID, probe)`（`Tests/Resources_test.lua` 測；cfg 是資源條那張表）：壞資料、`enabled = false`、
  未學會的充能法術（`C_SpellBook.IsSpellKnown`／`IsSpellInSpellBook` 過 pcall，秘密值當學了）不建列；
  充能格數 ＝ `GetSpellCharges().maxCharges`（明文才收，順手快取）→ 存檔的 `max` → 2；層數格數 ＝ `max` → 5；上限 10。
  容器高度 `Pips.PanelHeight(heights, gap)`：各列高加總＋列距（0 列 ＝ 0）。
- **畫法：充能列**（只在「下一格」顯示回充，平滑填滿）。每格由下往上：底色貼圖 → **閘門**（透明 StatusBar，
  `SetMinMaxValues(i-2, i-1)`＋`SetValue(充能數)`：充能數 ≥ i-1 時是滿的）→ **裁切框**（`SetClipsChildren(true)`，兩點錨在閘門的
  **填充貼圖**上：閘門滿 ＝ 跟格子一樣大、空 ＝ 寬 0）→ 裁切框裡的**回充條**（StatusBar，錨在**格子**上所以是被裁切不是被壓扁，
  `SetTimerDuration(C_Spell.GetSpellChargeDuration 的 duration 物件, nil, ElapsedTime)`，引擎平滑填滿，顏色 ＝ 這一列顏色 × 0.5）
  與**秒數**（一顆 `SetDrawSwipe(false)`／`SetDrawEdge(false)`／`SetDrawBling(false)` 的 Cooldown，`SetCooldownFromDurationObject` 同一個物件，
  只留倒數字）→ 填色 StatusBar（`SetMinMaxValues(i-1, i)`，最上層）。於是第 i 格已滿 ⇒ 填色蓋住；充能數 = i-1 ⇒ 這一格是下一格，
  回充條看得到；更後面的空格 ⇒ 閘門空，什麼都沒有。全程不讀充能數。閘門的填充貼圖幾何是秘密的：**除了裁切框以外沒有東西錨在它上面**，
  裁切框底下一律錨回格子，裁切框與它的子孫不讀任何幾何。算式抽成 `Pips.GateRange(i)`／`Pips.FillRange(i)`（離線測過每種充能數下
  「只有下一格看得到」）。已知小瑕疵：填充透明度 < 1 時，滿的格子底下看得到下一格之前那格的回充條（填色蓋不滿）。
- **畫法：層數列**（**引擎寫**）：一顆單格 AuraContainer（`Modules/AuraBar.lua`，同資源條的 auraBar），`SetApplicationBar` 交一條整列寬的
  StatusBar（`maxApplications` ＝ 上限），暗底、黑邊、分隔是列上另外畫的裝飾。首領戰／M+ 裡 `GetPlayerAuraBySpellID` 回 nil 也照樣對。
  容器還沒建好（戰鬥中新增／登入）或建失敗時退回**明文路徑**：`GetPlayerAuraBySpellID().applications` 直接餵每格的 `SetValue`，
  讀不到整列半透明；脫戰建好換回引擎。
- **顯示時機**（`showWhen`，設定頁每筆一個下拉）：
  | 選項 | 充能列 | 層數列 |
  |---|---|---|
  | 一直顯示（預設） | ✓ | ✓ |
  | 只在回充中／只在有這個光環時（`active`） | `GetSpellCharges().isActive`（**NeverSecret** 的明文布林）→ `SetAlpha`；讀不到時退回 `GetSpellChargeDuration():IsZero()`（秘密布林）餵 `row:SetAlphaFromBoolean(zero, 0, 1)` | 裝飾與填色都建在**按鈕子樹**裡（按鈕只在有光環時顯示 ⇒ 整列跟著出現），裝飾幾何進簽章；明文退路時看 `GetPlayerAuraBySpellID` 有沒有回表 |
  | 回充中或戰鬥中（`activeOrCombat`） | 戰鬥中（明文 `InCombatLockdown`）一律顯示，脫戰同上；有這種列時才註冊進出戰鬥 | 不開放（按鈕子樹與列上兩份裝飾會疊出兩倍暗底） |
  「非零時才顯示」照字面做不到：充能數是秘密數字，沒有「秘密數字 → alpha」的引擎路徑（`Curve:Evaluate` 不收秘密 x）；改用上面兩個
  引擎給得出的布林。**不是「一直顯示」的列照樣佔位**：秘密值下不知道它現在顯不顯示，面板高度只看有幾列（收合判斷不變）。
- **保護**：層數列的 AuraContainer 讓列與面板變保護框 ⇒ 戰鬥中不重排（記旗標、脫戰補），只重畫值；收合（高度 0）切換本來就走
  `SetPanelSize` → `ns.Write`＋結構排程，戰鬥中記帳。
- **秒數**：`showTime`（預設開）；倒數字是秒數 Cooldown 自己的 `GetCountdownFontString()`，換成像素字型、字級 ＝ 這一列的高 − 4（最小 8），
  `PlainFormatter(0)`＋`SetCountdownMillisecondsThreshold(0)`；關掉走 `SetHideCountdownNumbers(true)`。
- **讀不到**（充能 API 回 nil）：整列 alpha 0.5，`/mcdm debug` 的自訂格子段寫「讀不到」；秘密值照常畫、寫「秘密」；引擎寫的寫「引擎寫」
  與容器狀態（ready／pending／failed）、「交條」（`initializeFrame` 有沒有跑完 `SetApplicationBar`）。
- **事件**（自己一個事件框）：`SPELL_UPDATE_CHARGES`／`SPELL_UPDATE_COOLDOWN`（有充能列才註冊）、`UNIT_AURA`（player；有層數列才註冊，明文退路用）、
  `PLAYER_REGEN_DISABLED／ENABLED`（有「回充中或戰鬥中」的列才註冊），
  只標髒、下一幀只重畫值；`SPELLS_CHANGED`、天賦、換專精、進世界、`FirstRowWidthChanged`（寬 0 時）、設定檔／專精回呼走重排。
  資源條的能量事件不碰自訂格子；資源條的 `UNIT_AURA` 只剩「有光環型資源的職業」註冊。
- **顯示條件**：`pips.enabled = false` → alpha 0（容器藏、收合；設定頁「自訂格子」一節最上面的開關）；
  `pips.loadConditions`（騎乘或坐載具時隱藏、只在戰鬥中）→ alpha 0（自訂格子自己的一份，跟資源條的各管各的）；
  `pips.fadeWithEssential` 同資源條（取核心技能現在的 alpha）。資源條關掉不影響自訂格子。
- **編輯模式**：容器一建好就有覆蓋層（條名「自訂格子」）與選取框、磁吸；空的時候覆蓋層照最小尺寸（寬 × 預設列高 8）從上緣往下畫。
  拖了就脫離錨定（既有機制）；輔助跟的是核心技能，留在原地補位（指名跟著自訂格子的才會跟著走）。點擊層也蓋，點了開資源條頁。
- `/mcdm debug`：自訂格子自己一段（開關、清單幾筆、顯示幾列、容器高、錨定或位置、alpha、事件），清單每一筆一行（沒建列寫原因）；
  資源條那段不再印自訂格子。
- 列另外池化（格子懶建；層數列多一顆持有框，容器依簽章池化在上面），`GetResourceBarFrame` 只找資源列。

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
- **材質**：下拉多一項「暴雪施法條」（`texture = "blizzard"`，排在「純色」後面；只有施法條有，資源條與自訂格子的選單不加）：
  填充用遊戲內建施法條的圖集 `UI-CastingBar-Filling-Standard`（`SetStatusBarTexture` 收圖集名；`C_Texture.GetAtlasInfo` 查不到就退回純色、
  `SetStatusBarTexture` 失敗退回貼圖 `SetAtlas`）、**去飽和**，顏色照原本的上色流程（施法／引導／不可打斷／斷法就緒／蓄力都是對填充貼圖
  `SetVertexColor`）。一般施法與引導同一張，不依不可打斷換圖（秘密布林）。換材質後火花照舊在 `SetStatusBarTexture` 之後重下錨點；底色照 `bgColor`。
- **沒在施法**：`hideWhenNotCasting` 開著 ⇒ 容器 alpha 0；關掉 ⇒ 留一條空條。淡出、打斷停留（0.4 秒）期間算「在施法」。
- **預覽**：設定頁頁首的按鈕，十秒假施法（明文路徑，帶假延遲），再按一次停；真的開唱就讓位；離開那一頁自動停。

### 公開 API（契約：回傳形狀之後不改）

全域表 `MiliUI_CooldownManager`（`Api.lua`）。呼叫端一律處理 `nil`（本插件沒載入完、互斥偵測成立、那一項不存在）。
回傳的表是**設定檔裡的參照**：唯讀、不長期持有（換設定檔之後就是另一張）。

| 函式 | 回傳 |
|---|---|
| `GetResourceColors(key)` | `{ color = {r,g,b,a}, chargedColor = {…}\|nil, chargedEmptyColor = {…}\|nil }`；沒有這個資源、設定檔還沒載入 → `nil`。key 見下 |
| `GetResourceConditions(key)` | 規則陣列（形狀見 `Modules/ResourceConditions.lua` 檔頭，與單位框架相同）；沒有規則 → `nil` |
| `GetResourceBarFrame(powerType)` | `Enum.PowerType`（或資源 key 字串，給沒有 PowerType 的資源：`"Stagger"`、`"IgnorePain"`、`"Ironfur"`、`"EbonMight"`…）→ 資源條上那一列的框；沒有這一列、玩家關掉、整條關掉（容器藏起來）→ `nil`。載入條件／淡出造成的 alpha 0 不算藏（框還在，錨在上面的東西不必換錨點） |
| `GetBarFrame(key)` | 容器框 `MiliUICDM_Bar_<key>`（四條檢視器、自訂群組、`resources`、`pips`、`castbar`）；還沒建 → `nil` |
| `IsReady()` | 引擎是否已經認領好四條檢視器（布林）。問資源顏色／條件不必等它：設定檔載入前那兩支自己回 `nil` |
| `RegisterCallback(event, key, fn)` | 訂閱事件，目前只開放 `"ResourceStyleChanged"`（資源顏色或條件規則變了：資源條頁的套用、換設定檔、換專精，合併 0.2 秒，不帶參數）。同一個 key 再登記＝換掉；成功回 `true`，事件不開放回 `false`。`fn` 拋錯會被隔離 |
| `UnregisterCallback(event, key)` | 取消訂閱 |

資源 key（存檔內容，不要改名）：`Mana`、`Rage`、`Energy`、`Focus`、`RunicPower`、`LunarPower`、`Maelstrom`、`Insanity`、`Fury`、
`HolyPower`、`ComboPoints`、`Chi`、`SoulShards`、`ArcaneCharges`、`Essence`、`Runes`、`MaelstromWeapon`、`TipOfTheSpear`、`SoulFragments`、
`Icicles`、`DevourerFragments`、`Stagger`（顏色多 `moderateColor`／`heavyColor`／`tier3Color`／`tier4Color`）、`IgnorePain`、`WhirlwindStacks`、`SweepingStrikes`、`Ironfur`、
`EbonMight`、`ArcaneSoul`。

### 設定頁

- **資源條**：顯示、版面（寬、列高、列距、格距、填充方向）、外觀（材質、填充透明度、平滑、數值文字與字級、法力格式）、
  顏色與條件（每種資源的顏色、連擊點數的充能色、醉仙緩勁的中度／重度色與兩個門檻、第 3／4 段（開關＋門檻＋顏色，顏色列的標籤是門檻本身「≥ N%」，
  自己畫的標籤在 Refresh 時重寫——共用層的色票標籤建好就固定，門檻放進表單簽章的話拖一次滑桿就多一份表單）、滿條上限（到 300）、
  氣漩武器「摺成 5 格」＋溢出色、秘法靈魂「長條上的數字」（剩餘秒數／剩幾個公共冷卻）、無視苦痛／碎片零頭／精華回充／鐵鬃／引擎寫層數／光環剩餘時間條的說明列、
  血量的職業色／百分比／門檻換色（門檻在彈窗裡編：`Options/HealthThresholds.lua`，一列一個「低於 N% ＋ 色票 ＋ 刪除」，最多 6 筆；
  設定頁那顆按鈕寫目前筆數）、條件規則編輯器——引擎寫的列與血量不列進候選）、**自訂格子**（最上面整組開關；目前專精的清單：每筆一列名字＋圖示＋種類＋
  「刪除」（確認窗）、一列顏色＋充能的「顯示秒數」／層數的「層數上限」、一列「顯示時機」下拉（選項依種類）；「＋ 新增格子」→ 選「法術充能／光環層數」（兩顆按鈕滑過有
  GameTooltip：標題＋白字說明與舉例；`CreateChoicePopup` 不回傳按鈕，照按鈕字從彈窗子框認回來掛 OnEnter／OnLeave，彈窗 OnHide 一起收提示）
  → 輸入 ID（層數多一欄上限）→ 驗證：`C_Spell.GetSpellInfo`、充能要 `GetSpellCharges` 不是 nil、同專精不收重複，錯誤寫在彈窗裡的灰字列；
  底下小節「位置與錨定」＝ `Specs.Anchor("pips", { other = true })`（跟著哪條走／邊／偏移，寫進 `profile.pips`）＋「跟核心技能一起淡出」＋
  自訂格子自己的載入條件）、
  這個專精要顯示哪幾列（新資源自動列出；每列勾選框＋上移／下移；勾選存在目前專精底下 `rows[specID][key]`）、載入條件、錨定（資源條自己的）、恢復預設（連自訂格子的清單與 `profile.pips` 一起清）。
  表單照「形狀」快取（專精、候選清單（含順序）、條件編輯器的結構、自訂格子清單、資源條與自訂格子各自有沒有錨定、錨定圖、氣漩武器摺不摺（條件規則的「第幾格」選單跟著換））：規則／自訂格子增刪之類的結構變動延一幀換一份表單。
  套用時 `Resources.Apply()` 與 `Pips.Apply()` 都叫（樣式兩邊共用）。
- **施法條**：顯示、隱藏暴雪施法條、版面（材質多一項「暴雪施法條」）、顏色（含蓄力四階、斷法就緒）、圖示、文字（名稱最多字數、時間格式）、
  效果（火花、刻度、延遲）、沒在施法時隱藏、錨定、恢復預設。

## 套組接線

G 階段：套組裡原本只認舊的冷卻管理器插件的地方，改成**先問本插件、再問舊插件**。一律走「公開 API」那一節的函式，
呼叫端都處理 `nil`（本插件沒載入、還沒就緒、互斥偵測成立）。

| 插件 | 認得什麼 | 透過哪支 |
|---|---|---|
| `MiliUI_UnitFrames` 資源條 | 「跟隨冷卻管理器的顏色」：每種資源的顏色（含連擊點數的充能色）與條件規則 | 有 `GetResourceColors` 就問（不等 `IsReady()`：設定檔還沒載入時它自己回 nil）；本插件在答（法力的顏色表問得到）時條件規則只看本插件，否則 → 舊插件 → 自己的預設。登記 `RegisterCallback("ResourceStyleChanged")`，改色後立刻重畫（不等下一次能量事件）。存檔鍵仍叫 `followAyije`（相容），語意是「跟隨冷卻管理器」。`/muf debug` 的「顏色來源」印實際在答的是哪一支 |
| `MiliUI_CrusadingStrikes` | 掛在聖能條上方／下方；「自動」模式兩支任一載入就掛聖能條 | `GetResourceBarFrame(Enum.PowerType.HolyPower)`，沒有再退舊插件的表。資源列是池化重用的，輪詢時比對「解析出來還是同一個框」 |
| `MiliUI_UnitFrames`（反向） | 本插件取消「隱藏暴雪施法條」時要不要把事件裝回去 | 單位框架的公開 API `MiliUI_UnitFrames.HidesPlayerCastBar()`（布林，單向：為真就維持到 /reload） |
| `MiliUI` 本體 | 插件清單、預設值匯入（圖示套皮插件的相容由本插件自己的 `Core/Compat.lua` 處理，本體那支修補只管舊插件） | 資料夾名 `IsAddOnLoaded`。「插件強化」頁的施法條三個開關只對舊插件有效，**只在舊插件載入時出現**；本插件的引導刻度與延遲條在 `/mcdm` → 施法條 |

兩支 `OptionalDeps` 都加了 `MiliUI_CooldownManager`（只排載入順序；每次都現查，不快取「有沒有載入」）。
舊插件本身不動：互斥只在本插件這邊偵測（彈窗二選一）。

## 從 Ayije_CDM 匯入

換插件的玩家不用重調：把 `Ayije_CDM` 的設定檔轉成本插件的設定檔（`Core/Import.lua`）。

- **只能在互斥彈窗那一刻做**：存檔只在插件載入時才在記憶體裡。兩支都開著時登入，彈窗多一顆主按鈕「從 … 匯入」
  （對方存檔裡有這隻角色的設定才出現）：讀 `Ayije_CDMDB`、直接寫 `MiliUI_CooldownManager_DB`（`DB.Init` 還沒跑，
  缺的欄位登入後照常補）、停用 `Ayije_CDM`／`Ayije_CDM_Options`、重載。已經停用它的玩家：設定檔頁「從 … 匯入」一節的
  「啟用 … 並重載」，登入時就會看到彈窗。
- **每一份**對方的設定檔都轉成一份**新的**設定檔「Ayije：原名」（撞名加序號），不覆蓋既有的；這隻角色改用它原本用的那份，
  對方的「依專精切換」一起帶過來。`importedFromAyije = { at, char, profiles = { 原名 → 新名 }, main, summary }` 記在 SV：
  再匯入一次（彈窗的字變成「重新從 … 匯入」）覆蓋的是上次建的那幾份。重載後登入時聊天框印摘要（幾份設定檔、幾個自訂群組／
  光環格／逐法術設定、哪些類別沒匯入）。
- **轉換是純函式** `Import.Convert(profile, opts) → profile, report`，不碰 frame、離線可測。對方只存「跟它的預設值不同」的鍵，
  **沒出現的鍵一律保留本插件的預設值**（摘要會講這句）。report 列出用到的鍵、略過的鍵（本插件沒有這個功能／對方舊版的殘留／不認得）、近似的換算。
- **對照的重點**（完整語意寫在 `Core/Import.lua` 各節檔頭）：

  | 對方 | 本插件 | 備註 |
  |---|---|---|
  | `editModePositions` 三條檢視器 | 各條 `pos`，成長方向設成置中 | 對方存的 (x, y) 本來就是上緣／下緣中點（套用時才扣半寬），跟置中對齊的錨點同一點 |
  | `utilityYOffset`（＋解鎖時 `utilityXOffset`）、`spacing` | 輔助 `anchor.y = −spacing + yOff` | |
  | `sizeEssRow1/2`、`sizeUtility`、`sizeBuff`、`maxRowEss`、`maxRowUtil`（開換列時） | `layout.size`／`row2Size`／`maxPerRow` | 第二、三排增益（`sizeBuffSecondary`…）是對方舊版殘留 |
  | 字型、倒數／充能／層數的字級顏色位置、低秒變色、小數 | `theme.*Text`；輔助、增益圖示自己的字（跟主題不同才寫） | |
  | `fading*` | `theme.fade` | 「沒目標＋脫戰」兩個觸發都開、只開騎乘兩種表達不了，取近似（見檔頭） |
  | `pandemic*`、`glow*` | `theme.pandemic`、`theme.glow.proc` | 無損刷新要三個鍵同時成立才開 |
  | `resourceBarSettings[職業][資源]` | `resources.colors`／`conditions`（同形狀）／`rows[specID][key]`（載入條件）與共用的列高、寬、材質、數值文字；醉仙緩勁第 3／4 段（`tier3/4Threshold`／`Enabled`／`Color`） | 共用欄位先看玩家職業、再 General；螢幕座標貼著核心技能上緣 20 像素內 ⇒ 錨在核心技能上方。載入條件換成分專精的開關（`Import.ImportRows`，借 `R.SpecCandidates`／`R.SetRow`）：`loadMode = never` ⇒ 那個職業（General＝全部）每個候選專精關、`always` ⇒ 都開、`conditional` ⇒ 照 `load.spec` 集合逐專精對照；沒存 `loadMode` 的照對方的預設（法力 conditional、其他 always）；跟本插件預設相同的不寫。`load` 裡專精以外的條件（戰鬥中、騎乘、獵豹形態）記略過 |
  | `castBar*` | `castbar.*` | 位置：跟著資源條＝錨核心上方交給排開；錨核心／輔助時換成中心點照字面貼；螢幕座標換算成中心 |
  | `cooldownGroups`／`buffGroups`／`barGroups[專精]` | 自訂群組 `bars.g<n>` ＋ `spells[專精].groupOf`／`order` | 成長方向與位置換算見檔頭；往左長的清單反過來；撞名加專精名 |
  | `customBuffRegistry` ＋ `ungroupedCustomBuffOrder` | `spells[專精].custom` 光環格 | 固定秒數的自訂增益沒有對應 |
  | `ungrouped*Overrides` | `spells[專精].overrides` | 只有「隱藏倒數」與出現／消失音效對得上 |
  | 飾品、防禦、種族、外部防禦、輸出循環輔助、按壓覆蓋層、施法條逐法術 | 沒有 | 摘要提示飾品等可以用自訂群組＋自訂 ID |

- **跨專精**：對方的群組與增益覆寫用 spellID、本插件用 cooldownID（每個專精不同）。匯入當下只查得到目前專精
  （`C_CooldownViewer` 全部 pcall、回傳值過 Plain）；其他專精的原樣存在設定檔的 `pendingImport[specID]`，
  `Core/Catalog.lua` 每次建好目錄就對目前專精那一筆（`Import.ResolvePending`），換到的寫進 `spells[specID]`、清掉；
  換不到的留著，`/mcdm debug` 印「匯入待對應」。

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
7. **位置語意**：容器用版面算出來的錨點（CENTER_DOWN → TOP…；直向 DOWN_RIGHT → TOPLEFT、UP_LEFT → BOTTOMRIGHT，起點那個角不動），貼在 UIParent 的 `pos.point` 上加 (x, y)。所以預設的核心 (CENTER, 0, -202) 現在是「上緣」在畫面中心下方 202，不是中心點——之後給套組預設值時要照這個語意重量一次。
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

**自訂格子移到核心技能下方（2026-09-30）**

60. **空的自訂格子連錨定偏移一起收掉**：照原本的寫法（高度 0、錨點照舊），沒有自訂格子時輔助會離核心 2px（自訂格子的 −1 ＋ 輔助的 −1），
    跟改版前的 1px 不一樣。改成 `collapsible` 面板在高度 0 時上下向錨定的 y 偏移當 0；存檔的 `anchor.y` 不動，有列時照舊生效。
61. **沒有 DB 遷移**：本插件還沒出過版（`DB_VERSION` 仍是 1），預設的錨定改過兩次都不加遷移（合併只補 nil，既有存檔
    寫下的 `anchor` 不會被改）；出版後再改這種預設就要加一步有值閘的遷移。
    後來（同一天）改成**排開**：輔助、施法條的預設都直接跟著核心技能，先後由 `StackTarget` 決定。起因是實機回報
    「自訂格子改到核心上方，輔助跟著黏上去、而且跟資源條疊在一起」——鏈式預設（輔助錨在自訂格子上）把「輔助在哪」綁在
    一個使用者看不到的依賴上，同一邊兩個東西又沒有人負責排開。舊存檔留著的鏈（輔助跟自訂格子、施法條跟資源條）
    靠「相反邊往上讓」與「同邊掛在一串後面」兩條規則照樣排得開。

**自訂格子三項升級、補齊職業資源（2026-09-30）**

62. **顯示時機的鍵名**：任務寫的是 `"always" | "nonzero" | "nonzeroOrCombat"`，實作存 `"always" | "active" | "activeOrCombat"`——
    「非零」在秘密值下做不到（見「自訂格子」的顯示時機），實際語意是「回充中」／「有光環」，鍵名照實際語意取。
63. **層數列的「有光環才顯示」不開「或戰鬥中」**：要在列上與按鈕子樹各放一份裝飾，兩份疊起來暗底變兩倍，而 Lua 不知道按鈕現在顯不顯示、沒辦法二選一。
64. **醉仙緩勁、無視苦痛、鐵鬃從「不做」改成做**：原本的說明列（「吸收量型 12.1 是秘密值，所以沒有列進來」）不準確——數字讀不到，
    但 StatusBar 直接收秘密值。無視苦痛的「三成」用幾何做（不對秘密值算術），鐵鬃用 AuraGroup＋SetDurationBar（不用施放事件推算）。
65. **資源條多一種「戰鬥中不重排」**：有 auraBar 的專精（戰士、守護熊形態）面板是保護框，清單在戰鬥中變了（上限事件、型態）要等脫戰才重排；值照常更新。
    代價落在守護德魯伊：鐵鬃的容器建過之後（池化、留在列上），**戰鬥中切貓形／人形時資源列要到脫戰才換**。
    要避開只能讓持有框不掛在列的父層／錨點鏈上（例如錨 UIParent、用明文座標同步位置），面板移動、核心技能寬度變化都得跟著重對，這一版不做。

**光環剩餘時間條（2026-09-30）**

66. **黯黑力量、秘法靈魂從「不做」改成做**（使用者指定）：新增 `auraTimer` 模式，沿用 `Modules/AuraBar.lua` 的持有框／簽章池化／戰鬥外建，
    多一種 `kind = "duration"`（單格 `AddAuraSlot` ＋ `SetDurationBar`）。沒有新選項：顏色一列、「這個專精要顯示哪些」一列，都是自動列出；
    秒數沿用「長條上顯示數值」與字級，小數門檻固定 5 秒（不開選項）。代價跟 auraBar 一樣：這兩個專精的資源條面板也變保護框、戰鬥中不重排。
67. **秘法靈魂的過濾放兩個 ID**（451038、1223522）：wowhead 上同名同圖示的兩個增益，後者 11.1 加入、標秘法專精、持續 5 秒；
    不確定現行是哪一個，兩個都放（沒出現的永遠比對不到）。天賦閘是「歐爾的記憶 449619 已學」**或**「英雄樹是 39（Sunfury）」，
    其中英雄樹 ID 沒在 wowhead 核對到，只是保險。

**資源條補齊（2026-10-02）**

68. **碎片零頭沒有改 `GetValue`**：計畫寫「`GetValue("SoulShards")` 在 267 改讀原始單位」，但 `GetValue` 的上限也被格數（`SegmentsFor`）
    與天賦閘拿去用，改了會變成 50 格。改成在畫點數列時另讀原始值（`def.fractionalSpec`），`GetValue` 照舊回整顆數。
69. **無視苦痛的「N%」不是格式器**：`SetApplicationCount` 給格式器時引擎會對秘密層數跑 Lua 格式化、整顆容器壞掉（套組的團隊框架踩過），
    所以層數 FontString 不給格式器，「%」是旁邊另一顆固定字。改走引擎之後**條件規則不適用**（Lua 沒有值），容器沒好時的退路
    （吸收盾總量）也不套條件。
70. **醉仙緩勁第 3／4 段的標籤**：計畫寫「≥ N%」，「≥」改走語系字串（`At least %d%%`：中文「≥ %d%%」、其他語系寫成文字），
    西文介面的字型不一定有這個字。
71. **秘法靈魂的 GCD 格式器可行**：`NumericRuleFormatBreakpoint` 的 `format` 文件寫「沒有 components 時最多一個數字格式符」⇒ 零個可以
    （「最後」那段）；`NumericRuleFormatComponent` 有 `div`／`step`／`rounding` ⇒ `div = GCD、step 1、往上取` 就是 ceil(剩餘 ／ GCD)。
    門檻剛好等於 GCD 那一瞬間印「1」而不是「最後」（文件：門檻是「這條規則適用的最小值」），看不出來，不另外處理。
72. **分專精開關的遷移資料不放 DB.lua**：專精 → 候選資源只在 `Resources.lua` 一份（`R.SpecCandidates`），遷移 v3 與匯入在執行時借用；
    遷移跑的時機（`DB.Init` 在 `ADDON_LOADED` 之後、匯入在登入後）一定在 TOC 全部載完之後。

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
20. 編輯模式點一下藍框（沒拖）開那條的設定頁，四條檢視器（暴雪 Selection，後掛勾 OnMouseDown／OnMouseUp）與自訂條都要試；拖完放開不能開。
21. 暴雪的「吸附」開關與格距讀得到（`IsSnapEnabled`、`GetAccountSettingValue(GridSpacing)`），格線原點是畫面中心、單位是 UIParent 座標。
22. 覆蓋層 strata HIGH：條名與提示要蓋得過選取框（MEDIUM／1000、toplevel），但不能蓋過暴雪的編輯模式面板（DIALOG）。
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
   ~~`C_Spell.GetSpellCooldown` 的 `isOnGCD`／`isActive` 戰鬥中是明文（GCD 閘靠它；讀不到時會退回舊行為＝GCD 結束整排亮）：戰鬥中連按幾招，只有真的轉好冷卻的那格亮。亮著的時候按下那一招，發光當場熄；按別招（只有 GCD）不熄。裝了 Masque 時「觸發」樣式是方形、四角貼齊圖示，顏色照設定上色（去飽和＋染色），循環速度跟暴雪版一致。~~ ✅ 2026-10-01 實機通過。
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

**自訂格子**

50. （已改掉：不再讓任何東西貼在高度 0 的容器上）沒有自訂格子的專精／角色：輔助技能照樣顯示在核心下方 1px；加了格子之後輔助往下讓，刪掉又回來。
51. 加一列／刪到沒有列：收合狀態切換時輔助技能跟著移動、不閃；戰鬥中清單變了（充能法術學會／忘掉）時收合的偏移延到脫戰才換，期間不報錯。
52. 輔助技能有光環格（持有框保護鏈）時，自訂格子容器被連坐成保護框：戰鬥中 `SetPanelSize` 走 `ns.Write` 記帳、脫戰補做，零 ADDON_ACTION_BLOCKED。
53. 編輯模式：空的自訂格子覆蓋層（一列高）壓在輔助技能覆蓋層上緣，兩個選取框都點得到、拖得動；拖自訂格子時輔助跟著走。
54. 「法術充能／光環層數」兩顆按鈕的滑鼠提示：DIALOG 等級的彈窗上 GameTooltip 蓋得過彈窗、長字換行不超出螢幕。

**自訂格子升級與補齊的職業資源（2026-09-30）**

55. 充能列：裁切框兩點錨在閘門 StatusBar 的填充貼圖上，閘門空（值 ≤ min）時填充貼圖寬 0／藏起來，裁切框是否真的收成 0 寬（下下一格起看不到回充條）；
    閘門滿時裁切框跟格子一樣大；`SetValue(秘密充能數)` 之後裁切框的錨點仍有效（秘密錨點只擋讀取，不擋排版）。
56. 回充條 `SetTimerDuration(GetSpellChargeDuration(id), nil, ElapsedTime)` 是否從空平滑長到滿；每次 `SPELL_UPDATE_COOLDOWN` 重餵同一段時間不會讓條跳回 0；
    滿充能時 `GetSpellChargeDuration` 回什麼（nil 或零長度物件）——秒數 Cooldown 用 `clearIfZero = true`。
57. `GetSpellCharges().isActive` 在戰鬥中／首領戰是明文布林（文件標 NeverSecret）；「只在回充中」在最後一格回滿的瞬間藏起來。
58. 層數列與 auraBar：`SetApplicationBar` 在 12.1.0 正式服存在（`live` 分支的 `Blizzard_CustomAuraButton.lua` 有）；按鈕是 `AddAuraSlot` 當下建（`/mcdm debug` 的「交條 是」）；
    沒有光環時條是 0、按鈕藏起來；首領戰／M+ 中層數照樣跳。**旋風斬**（85739／190411）的層數真的寫在這顆光環上、上限 4；**橫掃攻擊**（260708）的上限 12／18 與天賦 1261049。
59. 鐵鬃：每施放一次確實是一顆獨立的光環（`AddAuraGroup` 一顆一格、各自倒數）；如果其實是單顆光環疊層數，會只顯示一格——那就改成 applications 型。
    `layout` 的 elementWidth（小數）有沒有被接受；從右到左時 `SetFlowLayoutAnchorPoint("TOPRIGHT")`＋`SetFlowLayoutGrowthDirection(Left, Down)` 是否生效。
60. 容器讓資源條／自訂格子面板變保護框：`IsProtected()` 是否真的往上傳到列與 root（`/mcdm debug` 的「延到脫戰」）；戰鬥中改設定、上限事件、換型態時零 ADDON_ACTION_BLOCKED；
    保護框上 `SetAlpha`／`SetAlphaFromBoolean`（條件規則、顯示時機、淡出）戰鬥中不被擋。12.1.5 的 Cooldown setter 標了 `IsProtectedFunction`：我們的秒數 Cooldown 不在保護鏈上，確認沒被擋。
61. 醉仙緩勁：`UnitStagger("player")` 戰鬥外明文、副本戰鬥中間歇秘密；每跳 `UNIT_HEALTH` 有到（沒有的話條不會隨時間變短）；三段色切換與沿用上一段的觀感。
62. 無視苦痛（2026-10-02 起只剩容器沒好時的退路，主路徑見 135）：`UnitGetTotalAbsorbs`／`UnitHealthMax` 秘密值直接餵；寬 W／0.3 的條被裁在列裡、滿條＝三成最大生命；`UNIT_ABSORB_AMOUNT_CHANGED` 在盾被打掉時有到。
63. 冰刺（205473）戰鬥中 `GetPlayerAuraBySpellID` 讀得到層數；噬靈魂碎片的兩個光環（1225789、1227702）與化身（1217607）ID、上限 50／35／40 是否仍對。

**光環剩餘時間條（2026-09-30）**

64. 黯黑力量（395296）與秘法靈魂（451038／1223522）：`includeSpellIDs` 對玩家自己的增益在首領戰／M+ 照樣比對得到（`/mcdm debug` 的「容器 ready／交條 是」）；
    按鈕在增益出現時才顯示、條從滿往下縮（`SetDurationBar` 的 `RemainingTime`），增益消失時回到空條；從右到左時縮向右邊（`SetReverseFill`）。
65. 黯黑力量被噴發／蓄力法術延長時條跟著變長（引擎用光環當下的持續時間，不必知道上限秒數）；延長瞬間是跳一下還是平滑（`interpolation = Immediate`）。
66. 開「長條上顯示數值」：秒數由 `SetDurationText` 印在條中央、字級跟著設定、剩 5 秒起一位小數；關掉再打開、改字級時換一顆容器（簽章）而不報錯。
67. 秘法靈魂的天賦閘：`C_SpellBook.IsSpellKnown(449619)`（歐爾的記憶，英雄天賦被動）是否回 true；`C_ClassTalents.GetActiveHeroTalentSpec()` 在Sunfury時是否回 39。
    兩者都不成立時非 Sunfury 的秘法法師不會多一列空條；換英雄樹（`TRAIT_CONFIG_UPDATED`）後列跟著出現／消失。黯黑力量的閘 395152 在增輝是否 IsSpellKnown。
68. 增輝／秘法的資源條面板因為容器變保護框：戰鬥中改設定、換天賦零 ADDON_ACTION_BLOCKED，脫戰補重排。

**音效（2026-09-30）**

69. 就緒音效：只設音效、沒開就緒發光的法術照樣響（探針有建：`/mcdm debug` 的「探針 N 顆」會增加）；GCD 不響；
    多充能每回一層響一次；同一個法術 1.5 秒內不重複；`/reload`、過圖、進出副本後 2 秒內不響（冷卻剛好在那時轉好的會被吃掉，是預期）。
70. 暴雪增益 item：`TriggerAuraAppliedAlert`／`TriggerAuraRemovedAlert` 的後掛勾在戰鬥中、首領戰、M+ 都有到，零 ADDON_ACTION_BLOCKED、零秘密值錯誤
    （`/mcdm debug` 的「增益掛勾 alert」）；刷新同一個增益（重新施放、換一個光環實例）不會連響「消失＋出現」；
    切換目標時追蹤目標身上減益的 item（`OnNewTarget`）會不會誤響。
71. 增益長條與增益圖示同一個法術各自一個 item 時只響一次（節流 key 是 cooldownID）。
72. 光環格 `AddAuraSound`：戶外登記成功（`/mcdm debug` 的「光環格登記 N 筆」）、出現／消失都響、聲道照設定；
    `throttleSeconds = 1.5` 被接受（被拒的話會退成不帶節流再登記一次，`登記失敗` 計數會 +1）；
    副本裡 `ShouldAurasBeSecret()` 為真時改設定 ⇒「待登記」，出副本後補上；登記過的在副本／首領戰／M+ 裡照樣響；
    過圖（`PLAYER_ENTERING_WORLD` 撤掉重登）後不會重複響兩次。`soundFileID`（LSM 回數字的音效）是否照樣播。
73. `LOADING_SCREEN_ENABLED` 在 `/reload` 時有沒有到（沒到也有 `PLAYER_ENTERING_WORLD` 的 2 秒保底）。
74. 下拉清單一百多項：選單裁在 14 列、滾輪捲得到最後一項；「試聽」在沒選時停用。

**錨定的排開（2026-09-30）**

75. 自訂格子改成「核心技能／在它上方」：跟資源條排開（資源條 → 自訂格子 → 施法條，由內往外）、輔助技能留在核心下方；
    改回下方、改成跟著施法條、資源條開關，每一步都零 Lua 錯誤（`SetPoint` 的「錨在依賴自己的框上」），位置當場更新。
76. 舊存檔（輔助跟著自訂格子、施法條跟著資源條）在格子移到上方時：輔助排在核心下方、沒有東西疊在一起。
77. 戰鬥中在設定頁改「跟著哪條走／邊」：不報 ADDON_ACTION_BLOCKED，脫戰後整疊一次排好。
78. 編輯模式拖走資源條：施法條當場補位貼回核心、不跟著游標跑；放手後不跳。
79. 倒數的「分／時」照客戶端語系：zhTW 顯示「4分」「2小時」（`COOLDOWN_DURATION_MIN`／`_HOURS`，暴雪給冷卻倒數用的字串；
    格式不是「單一個 %d」的語系退回 `%dm`／`%dh`）。輔助技能那種小圖示上「2小時」會不會太寬。

**進場與換專精（2026-09-30）**

80. 排追隨者地城／隨機隊伍被系統換專精（懲戒 → 神聖）進副本：核心技能每一格都是本插件的樣式（沒有比格子大的圖示、
    沒有深色外框、層數字型一致），輔助技能有顯示；出副本換回來也正常。壞掉的話當場 `/mcdm debug` 再 `/reload`。
81. `/mcdm debug`：「圖示套皮插件：已請它跳過」；各檢視器那行的「顯示＝true」「大小」是 1 或編輯模式設的值；
    診斷記錄在進副本後有 `[resync] loading`／`world`，清單真的漏過的話有 `[adopt]`。
82. 圖示套皮插件讓位之後：四條檢視器的圖示都沒有它的皮（圓角遮罩、外框圖），戰鬥中新出現的增益圖示也一樣；
    它的設定裡把冷卻管理器那幾個群組開關來回切，圖示不受影響。
83. 戰鬥中天賦不能換，但戰鬥中進場（重連、召喚）時 `Resync` 的結構級照常記帳到脫戰，零 ADDON_ACTION_BLOCKED。
84. 移除：預覽上任何一格按中鍵都直接消失（不留暗格）、畫面上同步不見；左鍵開的面板是「從這條移除」＋「還原此法術」。
    按「＋」：第一區後段有灰階的「已移除（原本在：…）」，點一下回到這條；別條的挑選器也能把它收進去。
    自己加的項目移除後不在挑選器上（整筆刪了），要的話重新輸入 ID。
85. 挑選器開著按「開暴雪冷卻管理器」：挑選器不關，整片蓋上「暴雪面板開著」的說明；暴雪面板關掉後自動重讀。
86. 「要先去暴雪面板加」那一區沒有問號：戰鬥藥水／治療藥水／治療石是類別圖示與暴雪的標題，空的飾品／武器欄是空格圖與欄位名。
87. 挑選器「要先去暴雪面板加」照暴雪面板的分頁分兩排（「法術」／「增益效果」，名稱用暴雪的字串）：同一件飾品在兩排各一格
    （一個追蹤冷卻、一個追蹤它給的增益）不再像重複；增益那排的提示多一句「這一格追蹤的是它給的增益，不是冷卻」。
    兩排各自的數量跟暴雪面板兩個分頁的「不顯示」「不顯示：物品」加起來一致。
88. 裝備欄項目（飾品）放在核心技能：按任何技能進 GCD 時那一格**不再變灰**（暴雪對裝備欄項目在 GCD 期間拿
    `GetInventoryItemCooldown` 回的 GCD 當真冷卻、`isOnGCD` 寫死 false；我們在 `SetDesaturated` 後掛勾重判）。
    真的用掉飾品進冷卻時照樣變灰；戰鬥中（讀到秘密值時走「不含 GCD 的法術冷卻是不是零」交給引擎）也一樣。
    開了「隱藏 GCD 轉圈」時飾品那一格的 GCD 轉圈也一起藏。
89. 沒有自訂格子的專精（例如被系統換成神聖）：輔助技能有顯示、貼在核心技能下方；切回有格子的專精時輔助排到格子下面。
    `/mcdm debug` 的「跟隨」欄：格子收合時輔助是「pips（貼 essential）」。
90. 資源條頁「這個專精要顯示哪些」：取消勾選當場少一列、`/reload` 後還是關的（原本寫成 `(not on) and false or nil`，
    永遠存成 nil）。
91. 清單上有、暴雪卻沒有給框的（例如飾品拖進關鍵冷卻技能之後條上沒出現）：設定頁預覽那一格是暗的、提示寫
    「暴雪的冷卻管理器目前沒有顯示這一格」；`/mcdm debug` 的診斷記錄有 `[missing]`。此時請打 `/mcdm debug` 再 `/reload`，
    從存檔的 item 現況看暴雪那邊到底有沒有那顆框、身分是什麼（`[identity]` ＝ 後掛勾漏接、下一輪已救回）。
92. 挑選器「自訂 ID」的說明多一行「官方的飾品監控不穩定，建議直接用『物品』輸入物品 ID 來監控飾品」；
    預覽上暴雪沒給框的裝備欄那一格，提示也帶這一句。
93. 自訂 ID 的輸入彈窗開著時，按住 Shift 點背包／角色面板的物品、法術書或天賦的法術：ID 自動填進輸入框、下面灰字寫出名字，
    按確定才加（`Picker.TakeLink`，後掛勾 `ChatFrameUtil.InsertLink` 與 `HandleModifiedItemClick`，彈窗沒開不收）。
    物品彈窗點到法術（或反過來）只給一行說明、不填。聊天輸入框同時開著時連結也會照常插進聊天框。
    物品彈窗確定／取消上面有一顆「開啟背包」（法術／光環彈窗是「開啟天賦與法術書」）：點了開背包（裝 Baganator 時開它的背包），
    之後點背包裡的物品使用不會被擋（走 secure `/click MainMenuBarBackpackButton`，不是插件 Lua 開）。
    先開法術彈窗再開物品彈窗（或反過來），按鈕開的是對的那個視窗。
94. 資源條的數值預設開、16 號字、置中（新設定檔／恢復預設才會套到；既有存檔不遷移，要自己勾「在條上顯示數值」）。
    預設列高 8 的條上印 16 號字，數字會上下各突出幾像素、相鄰兩列的數字可能互相碰到——要跟舊套組一樣就把列高調成 16。
95. 輸出專精（暗牧、元素、增強、三系術士、平衡、湮滅、強化）：資源條預設沒有法力；「這個專精要顯示哪些」裡法力那一列預設不勾，
    勾起來就出現、再取消又消失，`/reload` 後照存的。治療專精與法師預設照舊顯示（跟 Ayije_CDM 的預設一致）。（每個專精的預設在 `Resources.lua` 的 `DEFAULT_OFF`；
    `rows[specID][key]`：nil＝照預設、true／false＝強制；2026-10-02 起分專精存，見 136。）
96. 設定視窗開著（沒進暴雪編輯模式）：每條上面有覆蓋層（職業色邊、條名），**直接拖就能移動**，條與條對齊與套組磁吸都在（不吸格線：看不到）；
    **按住 Shift 拖曳不吸**（暴雪編輯模式裡也是：Shift 一律不吸，不再是「反轉」）。點一下仍是開那條的設定頁。
    設定視窗開著再進暴雪編輯模式：點擊層收起、換成選取框；出來又換回點擊層。戰鬥中設定視窗鎖著、點擊層不出現。

**從 Ayije_CDM 匯入**

97. 兩支都開著登入：彈窗三顆鈕（「從 … 匯入」是主按鈕、另外兩顆一般樣式），字沒有被截斷；說明多一段匯入的說明。
    對方存檔裡沒有這隻角色的設定時只有原本兩顆。
98. 按「從 … 匯入」：重載後 `Ayije_CDM`／`Ayije_CDM_Options` 都已停用；設定檔清單多了「Ayije：Default」等，這隻角色正在用它；
    聊天框印了摘要（設定檔數、自訂群組數與待對應數、光環格數、沒匯入的類別、「沒改過的用本插件預設值」）。
99. 位置對照：核心技能、增益圖示、增益長條、輔助技能跟匯入前在對方插件裡的位置一樣（誤差 1 像素內）；資源條貼在核心技能上方、
    施法條在資源條上方。對方用的材質（例如 `TukTex`）在它停用後本插件還讀得到（讀不到會退回純色）。
100. 自訂群組：目前專精的群組法術都在（`/mcdm debug` 沒有這個專精的「匯入待對應」）；切到另一個有群組的專精後，群組也自動有法術
     （第一次切過去時對表）、`/mcdm debug` 那一筆消失。往左長的群組順序跟對方一樣（第一個法術在最右邊）。
101. 光環格（例如回春術）在每個列在 `ungroupedCustomBuffOrder` 的專精都出現在增益圖示最前面，占位圖示照對方的設定。
102. 資源條：聖能等顏色與條件規則（聖能 ≥3／≥5 換色）跟對方一樣；列高 16。
103. 兩支再同時開一次登入：按鈕字變成「重新從 … 匯入」，按下去覆蓋的是上次那幾份（設定檔清單沒有多出「(2)」）。
104. 設定檔頁最下面「從 … 匯入」一節：對方已安裝時「啟用 … 並重載」可按、按了重載後出現彈窗；沒安裝時按鈕停用、灰字寫「沒有安裝」；
     匯入過的話灰字多一行「上次匯入：日期（N 份設定檔）」。
105. 左欄的自訂群組在「目前專精沒有內容」時整顆變暗（alpha 0.45），滑過有說明；按「＋」加東西、拖圖示進去、移除到空、
    換專精、換設定檔都會即時更新。內建的四條不會變暗。群組本身仍是設定檔裡所有角色共用的（使用者 2026-10-01 定案：不做範圍）。
106. 自訂項目新種類「裝備欄位」（`kind = "slot"`，`slot = 13／14`）：挑選器「自訂 ID」多一顆「飾品欄」，選飾品 1 或 2（按鈕上帶現在裝的名字），
    不用輸入 ID。格子追蹤「現在裝在那一格的物品」：冷卻、數量、提示（`SetInventoryItem`）、按鍵文字都照那件物品；換飾品
    （`PLAYER_EQUIPMENT_CHANGED` 標髒）自動換，空格顯示空格圖並去飽和。同一專精同一格只能加一次。這條路完全不經過暴雪的
    冷卻管理器，所以它的飾品項目不穩定也不影響；「官方的飾品監控不穩定」那句提示改成指向這顆按鈕。
107. ESC 選單「米利UI設定」滑過展開的清單裡有「米利的冷卻管理器」（`MiliUI_MenuEntries`，order 25），點了開設定；本體「插件」頁
    的那一列也改走這個入口。小地圖按鈕本來就有（`/mcdm minimap` 開關），裝了米利的小地圖時會被收進它的按鈕收納、圖示正確（`btn.icon`）。
108. 增益長條（與長條型自訂群組）不畫按鍵文字，條頁的「效果」節也沒有「按鍵文字」那一小節（主題頁與圖示條照舊）。
109. 自訂圖示群組勾「可點擊」後：自訂法術、自訂物品、飾品欄、從核心拖進來的暴雪技能（含暴雪的飾品格），左鍵與右鍵都會施放／使用；
     光環格照舊只有提示、點了沒反應（鈕收起來）。`/framestack` 看得到 `MiliUICDM_Click_<條>_<格>` 蓋在格子上。
110. 戰鬥中：鈕照樣可點；戰鬥中改勾選、加減群組內容不跳 ADDON_ACTION_BLOCKED，脫戰自動補上（新加的那格脫戰後才可點）。
111. 勾了之後版面節的「固定格位」變成停用＋黃字原因（「這條設成可點擊時固定開啟…」）；取消勾選回復成可勾、灰字。
     條上同時有光環格時講的是光環格那句。
112. 群組 strata 設成 BACKGROUND／LOW（暴雪 item 蓋在鈕上面的那種順序）時點擊是否仍可用（暴雪 item 自己若收點擊，
     這種順序會點不到；那就要把鈕的層級／strata 往上提）。
113. 有天賦覆寫的法術（例如換了圖示的那種），點了放的是覆寫後的那個。
114. 開著設定視窗時拖曳（ClickLayer 在 HIGH）照舊、不會誤施放；進編輯模式鈕收起來、拖曳照常（群組 strata 設 HIGH 也一樣），
     離開編輯模式鈕回來、照樣可點。
115. 滑過提示的位置、按鍵文字、發光、淡出都跟沒勾一樣；提示開關關掉時滑過什麼都不出現（暴雪自己的也不出現）。
116. `/console taintLog 2` 後打一場（含戰鬥中點鈕施放），taint.log 沒有 MiliUI_CooldownManager；取消勾選後那條容器
     戰鬥中移動（編輯模式、錨定的條變高）照樣延到脫戰、不報封鎖。
117. 顯示條件不成立（例如「只在戰鬥中顯示」的群組在戰鬥外）淡到 0 時，鈕還在原地收點擊：確認玩家能不能接受，
     不能的話再做 secure 狀態驅動（見「可點擊的自訂群組」的已知限制）。
118. 資源條格距 0：聖能、氣旋武器、連擊點等點數型，相鄰兩格之間是 1px 黑線（不是 2px），最左／最右的外框也還是 1px；
    自訂格子（充能／層數）同樣。從右到左填充時一樣。格距 1 以上照舊。
119. 新設定檔（或資源條頁「恢復預設」）：列高 14、字級 14、格距 0；聖能 ≥3 換粉紫、≥5 換紅，氣旋武器 ≥9 換粉、≥10 換紅。
    既有設定檔不變（不遷移）；已有規則或規則刪光的設定檔不會被補回預設規則。
120. 死騎符文（資源條與單位框架兩邊）：轉好的靠左、在轉的往右依剩餘時間排，用掉一顆時不跳格；在轉的格子填進度、印剩餘秒數，
    排隊中（第四顆以後）不填不印；全部轉好後 ticker 停掉（單位框架看 `/muf debug` 的 Metro 清單沒有 `classpower_rune`）。
    從右到左填充時，進度從右邊長起。倒數關掉時中間照舊印轉好的顆數。
    （2026-10-01 實機通過：排序、回充進度、秒數、排隊中不填、ticker 停掉；剩從右到左與倒數關掉兩項未看）

**圖示外觀：Masque**

121. 主題頁「圖示外觀」選 Masque → 跳重載確認框 → 重載後核心／輔助／自訂圖示群組、增益圖示、增益長條（只有圖示那一格）都是 Masque 選的皮；
     倒數／充能／層數文字、轉圈色、去飽和、按鍵文字、發光、淡出照舊。按取消的話設定留著、畫面不變，再改別的設定不會一直追問。
122. 戰鬥中才生出來的格子（戰鬥中換天賦被整條重取出、新上的增益）有套到皮；可點擊群組（item 在保護鏈上）戰鬥中新增的格子
     先是米利樣式、脫戰換成 Masque 的皮，零 ADDON_ACTION_BLOCKED。
123. 無損刷新期間 Masque 皮外面出現我們那圈彩色邊框（粗細 0 時是 1px），刷新窗口過了就消失；長條的條身換色照舊。
124. 改條的尺寸（每列上限、兩列尺寸、長條高度）之後皮跟著重套、不歪；佔位圖示（固定格位）跟真實格同一張皮。
125. Masque 設定裡停用「MiliUI Cooldown Manager」群組：聊天框一行提示、圖示回到米利樣式（可能留著 Masque 預設皮的外框圖），
     /reload 後乾淨；再啟用回到 Masque 的皮、我們的邊框不殘留。換皮（SkinID）之後轉圈色仍是我們設的。
126. 同時裝 MasqueBlizzBars：它的冷卻管理器群組裡沒有我們的 item（印記照舊），不會兩張皮疊在一起。
127. 「開啟 Masque 設定」：先關我們的設定視窗、Masque 的設定出現在最上層並能找到我們的群組；戰鬥中按了沒反應（Masque 自己擋）。
128. `/console taintLog 2` 打一場：Masque 寫在暴雪 item 上的欄位（`_MSQ_CFG`、Cooldown 的 `_MSQ_Color` 等）沒有讓暴雪的冷卻管理器
     或快捷列出現污染／秘密值錯誤。

**資源條排序、血量條、施法條暴雪材質（2026-10-02）**

129. 血量列（2026-10-02 加）：每個專精的「這個專精要顯示哪些」最後都多一列血量、預設不勾；勾起來出現在最下面。
     脫戰與副本／M+ 戰鬥中（`UnitHealth` 是秘密值）條都跟著血量動、`smooth` 有內插、數值文字照縮寫印（`AbbreviateNumbers`）、
     勾「生命力顯示百分比」印百分比；`/mcdm debug` 那一列「秘密 是」也照樣畫。最大生命變了（增益、裝備）上限跟著換。
     預設職業色；取消「填充用職業色」改用色票的顏色。沒有勾血量列的職業，受傷時資源條不會跟著重畫（`healthShown` 閘）。
130. 血量門檻換色：開了之後設 50% 橘、20% 紅，脫戰、副本、**M+** 都照段換色（C 端求值，不受秘密值影響）；
     門檻增刪／改百分比／改色當場生效；改了職業色開關，最高那段（底色）跟著換。門檻彈窗「新增門檻」滿 6 筆時停用。
131. 施法條材質選「暴雪施法條」：填充是內建施法條的漸層灰階 × 我們的顏色（施法、引導、蓄力四階、斷法就緒）；
     **不可打斷**的施法變灰（同一張圖、顏色由曲線決定）；打斷／失敗是紅色；火花貼在填充前緣；換回其他材質時不再是灰階。
     底色仍是 `bgColor`。圖集名若在某個版本查不到會退回純色（看 `/framestack` 填充貼圖）。
     **它是預設材質**（DB v2 遷移：還是舊預設「純色」或沒存的設定檔換成它，選過別的不動）：
     升級後第一次登入，原本純色的施法條變成暴雪材質、選過 LSM 材質的照舊；`schemaVersion` 變 2。
132. 資源條列的順序：在設定頁按上移／下移，畫面上的列與設定頁的「顏色與條件」「這個專精要顯示哪些」三處順序一致；
     第一列的上移、最後一列的下移是停用的；換專精後，別的專精沒排過的資源維持預設順序、排在排過的後面；
     `/reload` 後順序照存的；「恢復預設」回到預設順序。

**資源條補齊（2026-10-02）**

133. 毀滅術：靈魂裂片的格子照碎片零頭填（例如 3.7 顆 ⇒ 前三格滿、第四格七成而且暗一階），條上印 `3.7`；痛苦、惡魔照整數。
     副本戰鬥中 `UnitPower(…, true)` 是秘密值時格子照樣填、文字空白；`UNIT_POWER_FREQUENT` 在零頭變化時有到（碎片一點一點長）。
     `UnitPowerMax("player", SoulShards, true)` 是 50（一顆 ＝ 10）。條件規則（例如 ≥3 換色）照整顆數。
134. 喚能師：精華沒滿時下一格慢慢填滿（暗一階），轉好那一刻變成正常色、再下一格開始；滿了 ticker 停掉。
     `UnitPartialPower("player", Essence)` 有沒有回 0～1000 的明文（沒有的話走回充速度推算，進度跟實際轉好的時間差多少）；
     戰鬥中兩者都讀不到時下一格空著、不報錯。
135. 防戰無視苦痛：條的長度＝盾量佔上限的百分比——**增益 190456 的層數真的是 0～100**（`/mcdm debug` 看「容器 ready／交條 是」）；
     首領戰／M+ 身分閘讓這個增益過（條會動）；被別人套盾（真言術：盾等）時條**不動**；條上印「N%」（層數＝1 或 0 時引擎是否照樣印，
     不印的話 1% 那一下空白可以接受）；「%」跟數字貼在一起、大致置中。戰鬥中登入時先畫吸收盾總量，脫戰換成百分比條。
136. 「這個專精要顯示哪些」分專精：在暗牧勾法力、切到戒律看法力仍是預設（勾著）、切回暗牧仍勾著；`/reload` 後照存的。
     **升級第一次登入**（DB v3 遷移）：原本關掉的法力／魔怒等開關攤到對應專精、`schemaVersion` 變 3；原本在一個專精關掉法力、
     另一個專精的法力也跟著關的情況（舊版共用）在遷移後還是一樣（兩邊都寫了），之後分開調互不影響。
137. 氣漩武器「摺成 5 格」：0～5 層只有底層、6～10 層在同一格上疊溢出色（金黃）；上層的黑邊跟底層對齊、不粗一圈；
     數值文字蓋在上層之上；≥9／≥10 的條件色（照 10 格寫的）摺疊時只染底層。取消勾選回到 10 格。
138. 醉仙緩勁第 3／4 段：勾開後重醉仙緩勁超過 90%（150%）換第 3（4）段的顏色；顏色列的標籤跟著門檻滑桿變（「≥ 95%」）；
     滿條上限設 200 時 150% 那段看得到。從 Ayije 匯入時 tier3／tier4 的開關、門檻、顏色都帶過來。
139. 秘法靈魂「長條上的數字」選「剩幾個公共冷卻」：4 秒的增益在 1.5 秒 GCD 下印 3 → 2 → 「最後」；開嗜血（加速變了）後脫戰才換新的分段；
     `C_StringUtil.CreateNumericRuleFormatter` 與 `SetDurationText(fs, { textFormatter })` 吃這顆格式器（吃不下時退回秒數）。
140. 生效發光：增益圖示列開著「沒生效時隱藏」與關著兩種情況都試——勾了的增益生效時亮、消失就熄，灰圖示不亮；
     戰鬥中、首領戰、M+ 裡照樣跟著生效狀態開關（`IsActive` 讀得到）；換專精／增益搬進自訂群組後設定跟著走；
     每個增益自訂的顏色生效；從 Ayije 匯入後原本勾了發光的增益自動打勾。
     自訂光環格：四種樣式都在光環出現時亮、消失時熄（首領戰／M+ 秘密狀態下動畫照樣跑）；按鈕／觸發樣式的入場閃光有播；
     改格子大小後發光框跟著換尺寸。
