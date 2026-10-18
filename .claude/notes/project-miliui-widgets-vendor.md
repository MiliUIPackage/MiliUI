---
name: project-miliui-widgets-vendor
description: MiliUI 自製插件的共用基礎設施（MiliUIWidgets）—— 走 vendor 複製而非 LibStub，唯一 source 在 MiliUI 本體；Env 契約、各元件的地雷、設定視窗 Panel.lua 的三條層級規矩（關閉鈕／toplevel／換面板叫回）、選色器與 1px 的修正模型
metadata: 
  node_type: memory
  type: project
  originSessionId: 7d08d4b9-4715-4b8f-87ca-737e01131ca6
  modified: 2026-10-14T00:00:00.000Z
---

**任何 MiliUI 自製插件要做設定介面，複製 `AddOns/MiliUI/Libs/MiliUIWidgets/` 整包過去，
不要重寫、也不要叫 agent「參考頭像的介面」。** 那是唯一 source，包內 `README.md` 是完整契約
（檔案表、Env 契約、載入順序、各元件用法、規矩、刻意不含什麼）。2026-08-18 建立，08-23 起 source 在本體。

**消費者數字別寫死**：一律 `ls -d AddOns/*/Libs/MiliUIWidgets`（2026-10-14 是 21 份）。
同步跑 `python3 .claude/scripts/sync-widgets.py`（無參數＝同步並列出改了哪幾份，`--check`＝檢查漂移，
已接進 `check-all.sh` 與 CI；它也同步單檔 vendor MiliUIGlow／MiliUISnap／MiliUIStats／MiliUIDB／MiliUIEditMode／MiliUIMinimapButton／Callbacks）。
**單檔 vendor 一律照 `AddOns/MiliUI/Libs/<名字>/<名字>.lua`＋`README.md` 的格式**，本體只放 source 不載入，
消費端放 `<插件>/Libs/<名字>.lua`、TOC 排 Libs 區；新一支要在 `sync-widgets.py` 的 `VENDOR_FILES` 加一筆。
- **MiliUIDB**（2026-10-18）：SavedVariables 的 nil-merge（`MergeDefaults`）＋遷移鏈（`Migrate`）＋版本號閘（`Versioned`，
  含單位框／冷卻管理器的 `schemaVersionSeen` 不回收）。純函式、無全域、無 WoW API，離線測試在 source 旁 `Tests/`
  （`run_tests.sh` 會跑，對照組是換掉前四種原文）。預設行為＝通用那份 nil-merge；單位框的 `userSized`、
  冷卻管理器的 `atomic`／`keepScalar` 做成 opts。已換：14 支（Merchant／ShoppingList／Tooltip／Skin／Minimap／QuestTracker／
  MythicPlus／BossTimeline／CrusadingStrikes／CharacterNotes／Focus／QoL／DamageMeters／AuraEnhance）；
  **UnitFrames／CooldownManager 尚未換**（API 已容納它們的閘；CDM 有自己的離線測試要一起改）。
- **MiliUIEditMode**（2026-10-18）：`wow-editmode-draggable` 技能配方的程式碼版——`Attach(frame, opts)` 給選取框
  （pcall 模板＋自畫備援、OnMouseDown no-op）、三重進出訊號（派送延一幀、EventRegistry owner 用各自的表）、手動拖曳
  （不用 StartMoving）、暴雪格線吸附（Shift 不吸）、戰鬥閘 `Write`（宿主受保護且戰鬥中記到脫戰；REGEN_DISABLED 同步收拖曳）。
  位置怎麼存由宿主的 `save`／`restore` 決定（`CenterOffset`／`ApplyCenter` 是建議存法）。離線測試在 source 旁 `Tests/`。
  已換：BloodlustMusic（條＋提醒）、ChatBar（save 交給 Anchor.OnDragStop）、BurstPotionHelper（原本沒有編輯模式，新加）。
  **未換**：Focus CastBar、CrusadingStrikes、DamageMeters Move.lua、InfoBar、Minimap、QoL 兩支、QuestTracker、BossTimeline；
  UnitFrames／CooldownManager 刻意不動（它們還掛暴雪系統框，規矩不同）。**三支換用的實機都還沒驗**。
- **MiliUIMinimapButton**（2026-10-18）：小地圖鈕——`Create(opts)` → `handle:Apply()`；31×31、暴雪圓框、沿邊緣拖曳存**角度**、
  點擊在 OnMouseUp 判（不用 RegisterForDrag，12px＋0.12s 門檻）、`portrait` 選項（單位框的玩家頭像，事件只綁 player）。
  **被收納袋收走（父層≠Minimap）就不拖不定位**；收納袋 `Qualifies` 認 `btn.miliuiMinimapButton`。五支全換
  （UnitFrames／CooldownManager／BossTimeline／CharacterNotes／MythicPlus；CharacterNotes 順便從 RegisterForDrag 改成門檻判定）。實機未驗。
⚠ 腳本**不會主動把新模組塞進沒帶它的插件**，只更新已經帶著的那幾支；例外是 `Media/` 的資產檔
（`check-outline.tga`）一律補齊——貼圖不排 TOC、缺了是靜默空白。

**內容**：`Env.lua`（唯一宿主接點：`NAMESPACE / L / P / Font / Accent / PopupParent` ＋選用 `LABEL_W`）、
`Secret.lua`／`Errors.lua`／`Metro.lua`（無相依，排 TOC 最前面）、`BlizzOptions.lua`（暴雪「選項>插件」入口頁，
選用 `extraButtons`）、`Widgets.lua`（元件庫）、`ContextMenu.lua`（右鍵選單，要在 Widgets 之後）、
`Controls.lua`（宣告式表單引擎）、`PixelPerfect.lua`。除 Env 外逐字複製。
宿主專屬的選單清單與 spec 工廠放各自的 `Options/Specs_*.lua`，不要寫回 `Controls.lua`。

**Why 選 vendor 而不是 LibStub 或 MiliUI_Core 插件**：
- Core 插件 → 玩家從 GitHub 抓 zip 會缺件，後果是插件整個不能設定（硬失敗）。插件都是單體發佈的。
- LibStub → 能共享單一視窗，但要背「API 只能加不能改語意」的永久稅。
- vendor → 介面不漂移、bug 修一次跑腳本同步；代價是各插件各開各的視窗。哪天真要「一個視窗多分頁」再升級成 LibStub 不遲。

**踩雷點**：`Env.NAMESPACE` 每個插件必須不同——`CreateFont("同名")` 回傳既有物件、具名 frame 也一樣，
撞名會互相蓋掉字型設定而且不報錯。已用掉的前綴清單在 README「NAMESPACE 為什麼一定要不同」。

## 語系契約：四個 key，不要擴充

共用層只查 `Apply / Okay / Cancel / Can't change settings during combat`。AceLocale 宿主（ChatBar／BurstPotionHelper／
BloodlustMusic）補在各自 `Locales/enUS.lua` 就好（其他語系退回 enUS）。`BlizzOptions.lua` 第一版偷查
`L["Version: %s"]`，AceLocale 那三支當場 `Missing entry` 洗版——**需要字串就從 spec 收，沒傳退回英文字面值**。
共用層自己長出來的元件（拖曳把手、格線開關）的文案例外：自帶十語系，宿主要蓋走 `opts`。
`check_locales.py` 會掃 `Libs/MiliUIWidgets`（先剝註解，否則檔頭範例被當成真用到）；`miliui-locale-audit`
技能的腳本對 AceLocale 那三支不適用。

## 元件地雷（每條都是撞過的）

- **`custom` spec**：`{ type = "custom", label, build, h }`，`build(parent, x, y, width, ctx)` 回 `高度, refresh(選用)`。
  只有一個插件會用的控件走這裡，不要在共用層長新型別。
- **`W.CreateRowList`**：`updateRow` 必須連 OnClick 的 closure 一起重設，否則捲幾次就動到別筆；handler 一律讀 `row.<欄位>`。
- **`W.CreateInputPopup`**：刻意不 Raise，層級固定 410（遮罩 400 之上、戰鬥遮罩 500 之下）——Raise 會讓它戰鬥中浮在戰鬥遮罩上還能按。
- **建好但預設不顯示的元件要自己 `Hide()`**：`W.CreateFrame` 建出來預設顯示；`CreateConfirmPopup` 漏了那行的後果是
  「進分頁就自己跳出來」＋「已顯示的框 `Show()` 不觸發 OnShow ⇒ 第一次沒遮罩」。
- **`W.CloseOnEscape(frame, closeWithPanels)`** 走 `UISpecialFrames`，吃全域名稱、註冊後不移除，只給設定視窗／下拉／彈窗用，
  建立時叫一次。⚠ 不要自己 `EnableKeyboard` 抓 ESC（[[wow-keyboard-capture-blocks-bindings]]）；收尾掛 `OnHide`，ESC 是繞過 `Hide()` 直接藏框的。
  **換面板叫回**（2026-10-01）：ShowUIPanel 開中間面板（天賦／法術書）走的是同一支 `CloseSpecialWindows`，
  設定視窗會跟著被收掉（症狀：從法術書 Shift 點法術填 ID，視窗先關了）。預設分辨兩條路：同一幀被收掉且接著 ShowUIPanel 跑完＝換面板→叫回；
  ESC（ToggleGameMenu）不經 ShowUIPanel→照關。下拉與右鍵選單傳 `true` 維持舊行為。⚠ 自己的程式先關視窗、同一幀再 ShowUIPanel，視窗會被叫回來——要延一幀。
  詳見 [[wow-uispecialframes-login-closed]]。
- **`W.CreateTitleBar` / `W.MakeDragHandle`**：把手是有底有邊的 chip（標題列在面板外側、背後是會動的遊戲畫面）；
  `MakeDragHandle` 走 `HookScript`，宿主同一框的 `SetScript("OnMouseUp")` 要排在它前面（[[wow-setscript-clobbers-hookscript]]）；
  放開落在把手外的自檢靠 `IsMouseButtonDown` 輪詢（clamp 住時收不到 OnMouseUp）。通則：**雙用途控件一定要給第二個訊號**（分頁鈕兼把手＝隱形把手）。
- **`W.Menu.Show(items, anchorBtn, keepAnchor)`**（ContextMenu）：「有哪些項目」留在宿主；設計規則見 `miliui-menu-design` 技能。
  2026-09-22 起支援項目 `tooltip`、子選單裡的開關按下去原地重畫不收掉。
- **`W.CreateColorPicker`** 對暴雪 `ColorPickerFrame` 的兩個事實（同一控件修兩次，10-07／10-11）：
  ① 按確定**一律**呼叫 `opacityFunc`，沒開透明度時不重設滑桿 ⇒ `GetColorAlpha()` 回的是上一個選色器（可能是別支插件）留下的值，
  要守 `hasAlpha`、沒開就沿用原 alpha；② 取消（含點外面、ESC）給的舊值是 `{ r, g, b, a }`，透明度在 **`a` 不在 `opacity`**，
  讀錯欄位寫成 nil，畫面當下還留著拖過的值、重載／換專精才露出來。
- **`W.CreateChoicePopup`** 按鈕等寬平分、最長的字放不下就整個視窗撐寬（`width` 是最小值），OnShow 再量一次（建立時字型可能未就緒、字寬 0）。
- **表單 `Controls.Build`** 的 opt-in：`requires = { key }`（toggle 依賴另一個勾選）、`maxW`（控件欄上限）、`numbers` 的 `field.get／set`。
  標籤換行與欄寬見 [[project-miliui-options-label-width]]。
- **`W.CreateTabCard`**：頁裡的一段要分子分頁就用它（卡片是畫在 parent 上的貼圖不是 frame ⇒ 列、遮罩自動在上面；`opts.help` 加「!」說明）。
  **頂層分頁不套卡片**（accent-hover 群組），跟子分頁區分階層。
- **`W.CreateGridToggle`**：全套組共用一張 `_G.MiliUIWidgetsGridOverlay1`，暴雪格線看得到就讓位——要問 `IsVisible` 不是 `IsShown`（[[wow-editmode-blizzard-grid]]）。
- **`W.fontEmphasis`** 黃字說明（[[feedback-emphasis-note-yellow]]）；**`W.CreateButton(…, "primary")`／`W.PaintButton`／`W.SetButtonVariant`**（[[project-miliui-button-variants]]）。
- **勾選框的勾**是 `Media/check-outline.tga`（64×64 白勾黑框，SetVertexColor 染職業色）：原本拿 30×29 的 `checkmark-minimal` 圖集當遮罩放大，高解析度糊成一團。
- **1px 邊框與細線走 `P.Pixel(1)` 不是 `P.Scale(1)`**（2026-10-14，[[wow-hairline-p-pixel-not-p-scale]]）。

## 設定視窗 `Options/Panel.lua` 的三條層級規矩（各插件自己組裝，共用層不含）

1. **關閉鈕不能單獨設 strata**（09-30 修一次、10-01 又回來才抓到模型）：子框一旦 `SetFrameStrata` 過，面板之後被抬層級
   （Open 裡的 `Raise()`、拖曳 `StartMoving` 自動 Raise）它就不跟著走 ⇒ 掉到面板背景後面，看起來暗掉、點不到。
   正確做法：一般狀態只設相對層級（`panel:GetFrameLevel() + 200`，壓過表單遮罩 +40 起跳的子框）；
   戰鬥中要壓過戰鬥遮罩的那顆是**建在遮罩裡的另一顆**（`CreateCloseButton(mask, …)`），跟著遮罩的 strata。
   「原本為了戰鬥中切 DIALOG／FULLSCREEN_DIALOG，每次開窗都把它設成自訂 strata」就是這個 bug 修了又回來的原因。
2. **有標題列的視窗開 `SetToplevel(true)`**（`W.CreateTitleBar` 裡做，09-26）：各插件視窗都是 DIALOG／level 100，Raise 只抬面板本身，
   同時開兩扇時控件照 level 交錯著畫。toplevel 隱含 render layer flattening（[[wow-toplevel-flattens-child-strata]]）：
   整扇併成一層、視窗之間只剩整扇前後。代價是子孫的 strata 失效——視窗內彈窗／戰鬥遮罩靠 level 400～520 所以照樣在上；
   **要浮到別的視窗上面的東西別掛在面板底下**（下拉與右鍵選單掛 UIParent）。
3. **從設定視窗開別的面板要先關視窗**（HIGH 會被 DIALOG 蓋住，[[project-miliui-mythicplus]]）；配合 `CloseOnEscape` 的換面板叫回，關完要開暴雪中間面板得延一幀。

## Errors.lua 是修 bug 不是省行數

8 份 `ReportError` 只有 2 份有守衛，其餘 `tostring(err)`——`tostring(secret)` 是禁止操作，錯誤處理器在最需要它的時候自己炸成
"error in error handling"。共用版三道守衛缺一不可：① 防遞迴 ② err 可能是秘密字串 ③ 下游 handler 包 pcall。
`Secret.lua` 收掉八支插件的 15 處 `issecretvalue` 宣告（UnitFrames 的 `Core/Secret.lua` 只剩單位框自己的短名）；
`Metro.lua`：`ns.Metro.New(tick, onError)` → `Add/Remove/SetEnabled/Debug`，取代各自的輪詢 ticker。

本體的視窗比別家多：頂部 banner（職業色漸層＋版本號）、開窗淡入、「插件總覽」控制台分頁（`Options/Roster.lua` 名冊＋`Tab_Addons.lua`，
擷圖放 `MiliUI/Media/Shots/<key>.png` 840×420）。設定搜尋刻意不進包，理由在 README 末段。

相關：[[project-miliui-unit-frame]]、[[project-miliui-release-version]]、[[project-miliui-glow-vendor]]、[[project-miliui-snap-bars]]
