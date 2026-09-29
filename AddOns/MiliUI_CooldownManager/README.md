# 米利的冷卻管理器 MiliUI_CooldownManager

接手暴雪 12.1 冷卻管理器的四條檢視器（核心技能、輔助技能、增益圖示、增益長條），
重新排版、換樣式、加文字與發光，外加自訂群組、追蹤項目、資源條與施法條。
設定視窗 `/mcdm`（或 `/miliuicdm`、小地圖按鈕、插件選單）。

> **目前進度：C 階段（編輯模式）。** 四條暴雪檢視器已經認領重錨到自己的容器上，版面、兩列尺寸、
> 固定格位、長條、邊框／縮放／轉圈色／文字樣式、顯示條件都照設定檔跑；編輯模式裡每條都拖得動
> （見「編輯模式」一節）。設定視窗各頁的內容、自訂群組與追蹤項目、發光、資源條與施法條還沒做
> （改設定暫時只能改 SV）。`/mcdm debug` 印引擎與編輯模式現況。

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
| `Options/` | 700×520 設定視窗、左欄導覽、暴雪選項入口頁、小地圖按鈕 |
| `Core/Catalog.lua` ～ `Core/Visibility.lua` | 引擎，見下一節 |
| `EditMode/` | 編輯模式整合：`Geometry.lua`（純函式：放手位置換算回 pos、格線吸附）、`Frames.lua`（覆蓋層、選取框、暴雪 Selection 接線）、`EditMode.lua`（拖曳、進出訊號、暴雪設定對話框） |
| `Api.lua` | slash（含 `/mcdm debug`）、插件選單、公開 API `MiliUI_CooldownManager`（`IsReady`、`GetBarFrame(key)`；`GetResourceColors` 還是占位） |
| `Tests/` | 離線測試，不進 TOC：`DB_test.lua`、`Layout_test.lua`、`Catalog_test.lua`、`EditMode_test.lua`，用 `lua AddOns/MiliUI_CooldownManager/Tests/<名字>` 直接跑 |

之後的階段依序補上：各頁設定介面與預覽、自訂群組與追蹤項目、資源條與施法條、套組接線。

引擎的硬規則（對暴雪框不 SetParent／不 Hide、不寫暴雪框的欄位、只後掛勾、秘密值只當傳遞者…）
寫在實作計畫的「引擎契約」一節，動 `Core/` 之前先看。

## 引擎

| 檔案 | 職責 |
|---|---|
| `Core/Catalog.lua` | cooldownID → 法術資料；四條檢視器各自的有序清單。玩家在暴雪面板排的順序自己解 `C_CooldownViewer.GetLayoutData()`（不問暴雪的 DataProvider，那會寫它的快取欄位）；解不開就無感退回類別集合順序。`Bar(key)` 回套好本專精 `order`／`groupOf`／`hidden` 的清單。暴雪設定面板開著時 `IsPaused()` |
| `Core/Layout.lua` | 純函式 `Compute(items, layout, kind)` → 每格 (x, y, w, h)、容器寬高、容器錨點。不碰任何 WoW API，離線可測 |
| `Core/Viewers.lua` | 四條暴雪檢視器的後掛勾與 item 追蹤（弱鍵表 `frames[item]`）。登入退避重試等檢視器與 `CooldownViewerSettings`；戰鬥外一次把 `cooldownViewerEnabled` 打開；item 的縮放鎖 1 |
| `Core/Bars.lua` | 一條一個容器 `MiliUICDM_Bar_<key>`，錨定（pos 或錨在別條上）、重排排程、停放、固定格位的占位貼圖、把暴雪檢視器本體釘在容器上 |
| `Core/Decorate.lua` | 邊框（自己的 overlay 框上）、圖示縮放、轉圈色、GCD 轉圈、去飽和、長條外觀；每 item 一個簽章，同簽章跳過 |
| `Core/Text.lua` | 倒數／充能／層數：改暴雪自己那幾顆 FontString 的樣式，從不寫字（為什麼見檔頭） |
| `Core/Visibility.lua` | 顯示條件與淡出，一律 `SetAlpha`；容器與每個認領中的 item 一起套 |

登入流程：`PLAYER_LOGIN` → DB → `Loaded` → Catalog → Viewers → Bars → Visibility（`Core/Init.lua` 的 `ns.StartEngine`）。
換設定檔／專精：清樣式簽章、重讀目錄、全部重排、重套 alpha，不需要 /reload。

### 訊號流

```
暴雪：取出 item／RefreshLayout／Layout／SetCooldownID／ClearCooldownID／光環上下
  └─ Viewers 的後掛勾（ns.Guard）：更新弱鍵表上的身分，丟訊號
       ├─ Layout 後掛勾：當場用上次的格子快取把 item 放回去（Bars.Reapply，不重算，避免閃一幀）
       └─ Bars.RequestSource → 所有條標髒（取最高等級）
            └─ 排程：同一幀合併成一次 C_Timer.After(0)；兩次排版至少隔 0.1 秒
                 └─ Flush（暴雪設定面板開著就等它關）
                      Catalog.CheckFresh → 每條：Catalog.Bar ∩ 作用中的 item → Layout.Compute
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

### 與計畫不同

B 階段實作時發現計畫上寫的做不到、或換了做法的地方：

1. **倒數文字不自己畫**。計畫寫「`SetHideCountdownNumbers(true)`、倒數我們自己畫」與「低秒變色用曲線餵 `SetCooldownFromDurationObject`」都走不通：`GetCooldownTimes`／`GetCooldownDuration` 回秘密值；`Curve:Evaluate` 不收秘密 x；`SetCooldownFromDurationObject` 沒有曲線參數，而且暴雪用的是 `SetCooldown(start, duration)`，我們拿不到 duration 物件。改成打開暴雪 Cooldown 的內建數字、換它的 FontString 樣式，小數門檻走 `SetCountdownMillisecondsThreshold`，低秒變色走 `SetCountdownFormatter`（分段規則的 format 包 `|c` 色碼，**待實機驗證**）。同理充能與層數也是改暴雪的 FontString，overlay 框上沒有自己的文字。
2. **「IconOverlay」不是 parentKey**：暴雪 XML 裡那張外框圖沒有名字，改成掃 item 的 regions、用 atlas 名稱 `UI-HUD-CoolDownManager-IconOverlay` 認出來熄 alpha。另外拔掉圖示的圓角遮罩、轉圈材質換成方的（不然直角邊框配圓角圖示）。
3. **暴雪的觸發發光先不熄**：自己的發光在效果那一階段才做，現在熄掉等於功能倒退。留了開關：`ns.Glow.ownsProcAlert = true` 才熄。
4. **12.1 新增的四個類別（裝備欄、不分專精）是候選池，不是無條件併進去**。暴雪檢視器只為「有效類別等於自己」的 id 建框（`GetOrderedCooldownIDsForCategory`），還留在原類別的 id 沒有 item，列進清單只會變成永遠的空位／占位格。玩家在暴雪面板把它們拖進核心／輔助／增益之後，分類覆寫就是那一條，自然併進來；還在池裡的由 `Catalog.Pool(key)` 給之後的設定介面用。
5. **版面字串的「版本」**：`"<版本>|…"` 那個是編碼版本（目前 1），不是 5；5 是解出來的表的 `data[1]`（存檔格式版本）。收 4 與 5（3 以前 `data[2]` 存的是版面名稱不是 ID）。
6. `cooldownInfo` 沒有 icon／name 欄位：`Catalog.Info` 用 `C_Spell.GetSpellTexture／GetSpellName(overrideSpellID or spellID)` 補。
7. **位置語意**：容器用版面算出來的錨點（CENTER_DOWN → TOP…），貼在 UIParent 的 `pos.point` 上加 (x, y)。所以預設的核心 (CENTER, 0, -202) 現在是「上緣」在畫面中心下方 202，不是中心點——之後給套組預設值時要照這個語意重量一次。
8. **每個訊號都讓所有條重排**：自訂群組與「把 A 檢視器的法術拉到 B 條」會讓任一條檢視器的變動影響別條，條最多十來條，全排很便宜，就不追蹤來源。
9. 多掛了幾個點：檢視器的 `Layout`（同步放回，避免閃一幀）、`SetTimerShown`／`SetBarContent`（暴雪改顯示計時或長條內容時樣式重套）、`SetHideWhenInactive`。`SetBarContent` 是 **item** 的方法（計畫寫在 Bar 上）。
10. **淡出也要逐個 item 套 alpha**：item 的 parent 仍是暴雪檢視器（不 SetParent），容器的 alpha 管不到它們。
11. 目錄在每次排版前做一次便宜的新鮮度檢查（版面字串、specTag）：暴雪換專精／存版面是在它自己的下一幀做的，不保證有事件接得到。多聽了 `SPELLS_CHANGED`／`PLAYER_EQUIPMENT_CHANGED`／`TRAIT_CONFIG_UPDATED`（isKnown 會變）。
12. 「騎乘時隱藏」也包含坐載具（計畫的事件清單有載具事件、但資料模型沒有載具欄位）。
13. 容器的 1px 職業色邊也先透明（計畫只說底 alpha 0；邊框留著會在每條外面框一圈）。

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
  後掛勾 `AttachToSystemFrame` 當場只 `SetAlpha(0)`，下一幀才 `Hide`＋還原 alpha。第一次藏時聊天框印一行
  「冷卻管理器的設定在 /mcdm，或點藍框右上角的齒輪」。對話框的內容與 `Settings` 列不碰。
- **齒輪**：`Options.FocusBar(key)`。設定視窗是 DIALOG strata、開窗時 `Raise()`，蓋得過編輯模式的面板。
  自訂條還沒有自己的頁面（D／E 階段），目前退回核心技能那頁。
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

### C 階段與計畫不同

1. 暴雪的 Selection `SetAllPoints` 到**覆蓋層**，不是容器：非空的條兩者一樣大；空條容器只有 1×1，
   貼容器就點不到。
2. 四條檢視器不呼叫暴雪 Selection 的 `ShowHighlighted`（計畫寫「進入時 ShowHighlighted」）：那會寫它的
   `textureShown`／`isSelected` 欄位。顯示與否交給暴雪的「冷卻管理器」勾選框；沒勾時改用我們自己的
   選取框頂上（同一個模板、同一套拖曳），所以四條永遠拖得動。
3. 暴雪設定對話框不在掛勾裡當場 `Hide`：當場只 `SetAlpha(0)`（C 端狀態），`Hide` 延一幀走 `ns.Write`，
   離開 `SelectSystem` 的堆疊。
4. 提示「拖曳會解除跟隨」在進編輯模式時就顯示（不只拖曳前一刻），放手後消失。
5. 編輯模式中顯示條件暫停、每條全亮（計畫沒寫；不然條件不成立的條進編輯模式看不到、拖不到）。

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

## 待實機驗證

1. 暴雪 12.1 的 `EquipSlotEssential`／`EquipSlotTracked` 是否真的讓飾品出現在核心／輔助檢視器；沒有的話追蹤項目要補「裝備欄」種類。
2. 增益圖示 item 的 `IsShown()` 在秘密值下是否仍是明文布林（收合模式的前提）。
3. 容器與光環格持有框 `IsProtected()` 的實際值；戰鬥中原生增益增減零 ADDON_ACTION_BLOCKED。
4. `Selection` 用 `SetScript` 換拖曳腳本後，戰鬥中動作條零封鎖（開 taintLog 2 打一場）。
5. 觸發發光接管：`ShowAlert` 後掛勾在首領戰是否照樣觸發。
6. 就緒發光靠 `Cooldown` 的 `OnCooldownDone`：多充能法術的行為。
7. 物品冷卻：`GetItemCooldown`／`GetInventoryItemCooldown` 的 start／duration 在首領戰／M+ 是否仍是明文（前例直接運算、目前沒炸；我們照 §2 包 `canaccessvalue`）。
8. 12.1 增益圖示檢視器裡「無視痛苦」這類數值型 buff 的 `Applications` 文字是否明文；資源條要顯示它的話只能掛 `SetText` 後掛勾照抄字串，不能算。
9. `GetLayoutData` 的格式版本是否仍是 5、`data[2]`／`data[3]` 的欄位位置是否如上（先拿使用者自己的 SV 字串離線解一次）；解不開時退回類別集合順序要能無感。
10. 探針 `Cooldown` 的 `OnCooldownDone` 在餵秘密 duration object 時是否照觸發。
11. 倒數低秒變色：Cooldown 的 `SetCountdownFormatter` 是否照 FontString 規則解析 format 裡的 `|c` 色碼；自訂 formatter 會不會蓋掉暴雪原本的「1:31」縮寫樣式（我們給了 91 秒／5401 秒的分／時段）。
12. 後掛勾的污染：`hooksecurefunc` 掛在 item 的 `SetCooldownID`／`OnActiveStateChanged`／`SetScale`、Cooldown 的 `SetCooldown`、Icon 的 `SetDesaturated` 上，戰鬥中開 taintLog 2 確認零 ADDON_ACTION_BLOCKED、零秘密值錯誤。
13. 檢視器本體釘在容器上之後，底部管理框（`BottomManagedFrameTemplate`）與編輯模式重排會不會跟我們拉鋸（SetPoint 後掛勾每次都會釘回來）。
14. GCD 轉圈：`SetCooldown` 的 duration 在戰鬥中是否明文（讀不到就不藏，會多轉一圈）。
15. 長條換材質（`SetStatusBarTexture`）後暴雪的 Pip 錨點失效——我們把 Pip 熄了，確認沒有殘影。
16. 固定格位的占位貼圖畫在容器的 BACKGROUND 層，暴雪 item 是檢視器的子框：兩者都掛在 UIParent 下，容器的 frame level 必須低於 item 才會被蓋住（item 出現時占位要看不見）。
17. 編輯模式：戰鬥中進出、拖曳中進戰鬥零 ADDON_ACTION_BLOCKED；點過四條檢視器的選取框、藏過設定對話框之後
    離開編輯模式打一場，快捷列零封鎖（`/dump issecurevariable(EditModeSystemSettingsDialog, "attachedToSystem")`：
    對話框的 OnHide 由我們的 `Hide()` 觸發，那一欄會被我們的執行寫成 nil —— 要看它在下一次暴雪自己
    `AttachToSystemFrame` 時有沒有把污染帶進去）。
18. 暴雪 Selection `SetAllPoints` 到覆蓋層後，暴雪自己的磁吸（別的系統吸到冷卻管理器）與 `UpdateClampOffsets`
    沒有怪行為；離開編輯模式後 Selection 留著這個錨點（下次進來會重貼）。
19. 齒輪圖示 `Interface\Buttons\UI-OptionsButton` 在 12.1 仍存在、16×16 看得清楚。
20. 暴雪的「吸附」開關與格距讀得到（`IsSnapEnabled`、`GetAccountSettingValue(GridSpacing)`），
    格線原點是畫面中心、單位是 UIParent 座標。
21. 覆蓋層 strata HIGH：齒輪要蓋得過選取框（MEDIUM／1000、toplevel），但不能蓋過暴雪的編輯模式面板（DIALOG）。
