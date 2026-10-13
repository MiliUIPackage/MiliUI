---
name: project-miliui-esc-menu-window-migration
description: 爆發藥水助手／嗜血音樂／快捷聊天列改用 MiliUIWidgets 自製設定視窗（2026-08-23）——三支小插件的標準結構、AceLocale 宿主的差異、踩過的點
metadata: 
  node_type: memory
  type: project
  originSessionId: cf8cd3da-dcd0-4dd8-a660-28913874493c
  modified: 2026-10-14T00:00:00.000Z
---

爆發藥水助手、嗜血音樂、快捷聊天列這三支原本是**暴雪 Settings canvas 面板**（主分類＋子分類、`UIPanelButtonTemplate`、`OptionsSliderTemplate`），2026-08-23
全部改成跟 [[project-miliui-unit-frame]] 同一套的自製設定視窗，ESC 選單「米利UI設定」點下去開的就是它。這三支是 **AceLocale（大寫 token key）宿主**，跟自寫 `ns.L` 的其他插件在語系契約上有差（見 [[project-miliui-widgets-vendor]]）。

**每支的結構**（新的小插件也照這個；共用層內容以 `ls Libs/MiliUIWidgets` 為準）：

```
Libs/MiliUIWidgets/           ← Secret/Errors/Metro/BlizzOptions/Widgets/ContextMenu/Controls/PixelPerfect/Env，見 [[project-miliui-widgets-vendor]]
Libs/Callbacks.lua            ← 也是逐字複製（17 份；⚠ MiliUI_Minimap 那份多了 ns.prof 計數，已分家，md5 對不上是正常的）
Libs/MiliUISnap.lua           ← 有條要磁吸的才帶（藥水列、聊天列），見 [[project-miliui-snap-bars]]
Options/Panel.lua             ← 視窗骨架：W.CreateTitleBar（把手＋toplevel）＋分頁鈕＋戰鬥遮罩＋關閉鈕（規矩見 widgets-vendor「三條層級規矩」）
Options/Tab_*.lua             ← 每個分頁自己註冊 ShowOptionsTab、懶初始化
Options/Blizzard.lua          ← 17 行：ns.RegisterBlizzardCategory（共用層 BlizzOptions），暴雪「選項>插件」只剩「開啟設定」按鈕
Api.lua                       ← 斜線指令＋MiliUI_MenuEntries 那一筆
```

分頁：藥水助手＝一般／藥水清單／巨集／關於；嗜血音樂＝音樂／曲目／倒數條／提醒／關於；聊天列＝一般／頻道／關於（關於頁在 Panel.lua 裡組）。

**幾個踩過的點**：

- `Options/Panel.lua` 需要 `ns.VERSION` / `ns.PREFIX_COLOR` / `ns.ReportError`，補在各自的核心檔（Core.lua／Config.lua／ChatBar.lua）頂端；`ReportError` 現在由共用層 `Errors.lua` 提供。
- 視窗位置存進各自的 SavedVariables，但**舊 DB 沒有那一格**，所以 `WindowPos()` 每次都自己補 `optionsWindow = {x=0,y=0}`，不假設 DEFAULTS 有。
- 聊天列的「全部重置」原本是 `StaticPopupDialogs`，改成 `ns.ResetAll()` ＋ 共用層的 `W.CreateConfirmPopup`。**`SetUserPlaced(false)` 一定要在 `ReloadUI()` 之前**（[[project-miliui-chatbar-snap]]）。
- 分頁裡監聽全域高頻事件（藥水清單的 `ITEM_DATA_LOAD_RESULT`）要掛在**分頁 frame 的 OnShow/OnHide**，不要掛在切分頁的 callback：直接關掉整個視窗時不會派送 `ShowOptionsTab`，但子框的 OnHide 照樣會跑。
  同理刷新守衛要用 `IsVisible()` 不是 `IsShown()`（分頁自己一直是 Show 的）。
- 聊天列有 `/mchatbar`（`/mcb`）指令，TOC 的 Notes-zhTW 從「Esc>選項>插件」改成指令。
- 嗜血音樂的 `ns.testBarBtnRef` 是 Music.lua 直接改按鈕文字用的（測試條開著會變成「隱藏倒數條」），所以那顆按鈕必須是實體按鈕、而且要掛回 ns。
- 嗜血音樂的 `UNIT_AURA` 要 `RegisterUnitEvent("UNIT_AURA", "player")`（2026-09-26）：引擎在 C 層先濾掉隊友與名條的光環事件，不讓它們進 Lua（[[wow-unitframe-event-dispatch-cost]]）。
- 關閉鈕被面板背景蓋住修了兩次（09-30、10-01）才抓到模型：**關閉鈕不能單獨設 strata**，戰鬥中用遮罩裡的第二顆——正確寫法在 [[project-miliui-widgets-vendor]]。

相關：[[project-miliui-widgets-vendor]]、[[project-miliui-focus-addon]]、[[project-burst-helper]]
