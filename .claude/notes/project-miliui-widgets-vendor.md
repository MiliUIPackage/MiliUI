---
name: project-miliui-widgets-vendor
description: MiliUI 自製插件的共用設定介面（MiliUIWidgets）—— 走 vendor 複製而非 LibStub，唯一 source 在 MiliUI 本體
metadata: 
  node_type: memory
  type: project
  originSessionId: 7d08d4b9-4715-4b8f-87ca-737e01131ca6
  modified: 2026-08-22T20:42:59.910Z
---

**任何 MiliUI 自製插件要做設定介面，複製 `AddOns/MiliUI/Libs/MiliUIWidgets/`
整包過去，不要重寫、也不要叫 agent「參考頭像的介面」。** 那是唯一 source，包內
`README.md` 寫了完整的複製契約。（2026-08-18 建立；2026-08-23 唯一 source 從
UnitFrames 搬到 MiliUI 本體——本體那天也改用自製視窗，順勢接手 source 角色。
七份 copy 的 Widgets/Controls/PixelPerfect/README 均已 md5 同步。）

**內容**：`Widgets.lua`（元件庫）、`Controls.lua`（宣告式表單引擎）、`PixelPerfect.lua`、
`Env.lua`。前三支逐字複製，**只改 `Env.lua`** —— 它是唯一的宿主接點，提供
`NAMESPACE / L / P / Font / Accent / PopupParent` 六項，另有選用的 `LABEL_W`
（表單標籤欄寬，預設 128；2026-08-22 加，Tooltip 的 zhTW 長標籤用 200）。
同日 MakeLabel 補了左緣錨點＋WordWrap——原本只錨右緣，超過欄寬的標籤會往左
溢出被捲軸邊緣裁掉開頭（症狀：字的前面被吃掉），夾住後改成換行。
宿主專屬的選單清單與 spec 工廠放各自的 `Options/Specs_*.lua`，不要寫回 `Controls.lua`。

**Why 選 vendor 而不是 LibStub 或 MiliUI_Core 插件**：
- Core 插件 → 玩家從 GitHub 抓 zip 會缺件，而缺件的後果是插件整個不能設定（硬失敗）。
  插件都是單體發佈的，不能有這種前置條件。
- LibStub → 能共享單一視窗，但要背「API 只能加不能改語意」的永久稅。
- vendor → 拿到「介面不漂移、bug 修一次跑腳本同步」，又不用背相容包袱；代價是不能
  共用同一個設定視窗（各插件各開各的）。**哪天真的想要「一個視窗多分頁」再升級成
  LibStub 不遲**，原始碼已經是單一 source。

**踩雷點**：`Env.NAMESPACE` 每個插件必須不同。`CreateFont("同名")` 回傳既有物件而非
新的，具名 frame 也一樣 —— 撞名會讓兩個插件互相蓋掉字型設定，而且不報錯。

**現況**：八個消費者——**MiliUI 本體（source，2026-08-23 起）**、UnitFrames（舊 source）、
**MiliUI_Tooltip**（2026-08-22，見 [[project-miliui-tooltip]]）、**MiliUI_Focus**
（2026-08-22，見 [[project-miliui-focus-addon]]）、**MiliUI_BurstPotionHelper／
MiliUI_BloodlustMusic／MiliUI_ChatBar**（2026-08-23，見
[[project-miliui-esc-menu-window-migration]]）、**MiliUI_DamageMeters**（2026-08-24，見
[[project-miliui-damagemeters]]）。
設定視窗本體（`Options/Panel.lua`）仍是各插件自己組裝（簡化版：無搜尋、無小地圖鈕）；
設定搜尋刻意不進包，理由寫在 README 末段。
本體的視窗（2026-08-23）比別家多：頂部 banner（職業色漸層＋版本號，零圖檔）、開窗
0.15s 淡入、**「插件總覽」控制台分頁**（`Options/Roster.lua` 名冊＋`Tab_Addons.lua`：
分組清單＋勾選批次開關插件＋詳情面板含擷圖/說明/CPU/開啟設定按鈕；擷圖放
`MiliUI/Media/Shots/<key>.png` 840x420，佔位圖墊底所以不用偵測檔案存在）。
NAMESPACE 已用掉：MiliUIPack（本體）/MiliUIUF/MiliUITip/MiliUIFocus/MiliUIChatBar/
MiliUIBurst/MiliUIBLM/MiliUIDM。舊 `MiliUI/Settings.lua`（暴雪 canvas 面板）已刪，importRegistry
搬到 `MiliUI/Options/Tab_Import.lua`。

**`custom` spec（2026-08-22 加，共用層唯一一次擴充）**：`Controls.Build` 多了
`{ type = "custom", label, build, h }`，`build(parent, x, y, width, ctx)` 回傳
`高度, refresh(選用)`。宿主自己畫那一列、共用層只負責排版與把 refresh 併進 refreshers。
加它的理由：Focus 需要「擷取按鍵」與「唯讀巨集複製框」兩種控件，兩者都只有一個插件會用
—— 與其在共用層長出 `keybind` / `copybox` 這種宿主味的型別，不如開一個通用逃生口。
**三份 copy 必須一字不差**（改完 `diff` 三份確認），這次是同時改三份同步過去的。

**2026-08-23 第二次擴充共用層**（同樣三份 → 六份一起同步，`md5` 對過）：
- `W.CreateCopyBox(parent, w, h, getText, selectLabel)` —— 唯讀但選得起來的複製框
  （巨集／指令）。停用的輸入框連選取都做不到，所以做法是「一被輸入就還原」。
  `selectLabel` 由宿主傳，共用層不多吃一個 L key。消費者：Focus（斷法巨集）、
  BurstPotionHelper（/click 那行）。
- `W.CreateRowList(parent, w, h, rowH, buildRow)` —— 列會回收的可捲動清單。
  **`updateRow` 必須連 OnClick 的 closure 一起重設**，否則捲幾次就會動到別筆；
  最省事的寫法是 handler 一律讀 `row.<欄位>`，建列時完全不抓資料進 closure。
  消費者：藥水清單／曲目清單／頻道開關三支。
- `W.CreateInputPopup(parent, w, title, fields)` —— 「新增一筆／改名」的輸入彈窗，
  `onAccept` 回傳 `false` 就不關窗。**刻意不 Raise**：層級固定 410（遮罩 400 之上、
  戰鬥遮罩 500 之下），Raise 會讓它戰鬥中浮在戰鬥遮罩上面還能按。

**2026-08-24 共用層修正（八份一起同步，`md5` 對過）**：`W.CreateConfirmPopup`
建完之後沒有 `Hide()` —— 而 `W.CreateFrame` 建出來預設是**顯示**的。兩個後果：
1. 「分頁 Init 就先建好、按鈕按下去才 Show」這種寫法，確認視窗會**一進分頁就自己跳出來**
   （MiliUI_DamageMeters 的「還原預設值」就是這樣被使用者看到的）。
2. 就算是「建完馬上 Show」的多數寫法也壞：對一個**已經顯示**的框呼叫 `Show()`
   不會觸發 `OnShow`，所以第一次按下去時背後那層遮罩不會出現。
修法是 `return popup` 之前補一行 `popup:Hide()`。
通則：**共用層任何「建好但預設不顯示」的元件都要自己關掉**，不要指望呼叫端記得。

**AceLocale 宿主要補四個 key**：那三支是 AceLocale（大寫 key 風格），共用層查的是
`Apply / Okay / Cancel / Can't change settings during combat` 這四個英文原文 key，
補在各自的 `Locales/enUS.lua` 就好（AceLocale 是單一 app 表，其他語系沒翻會退回 enUS）。
另外 **`miliui-locale-audit` 技能的腳本對這三支不適用**——它假設 `ns.L` ＋ 英文原文 key
的架構，跑 AceLocale 插件會噴一整排假警報（格式符、TOC 找不到 Locale.lua…）。

相關：[[project-miliui-unit-frame]]、[[project-miliui-release-version]]
