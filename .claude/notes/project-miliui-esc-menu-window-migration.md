---
name: project-miliui-esc-menu-window-migration
description: 爆發藥水助手／嗜血音樂／快捷聊天列改用 MiliUIWidgets 自製設定視窗（2026-08-23）
metadata: 
  node_type: memory
  type: project
  originSessionId: cf8cd3da-dcd0-4dd8-a660-28913874493c
  modified: 2026-08-22T16:18:32.772Z
---

爆發藥水助手、嗜血音樂、快捷聊天列這三支原本是**暴雪 Settings canvas 面板**
（主分類＋子分類、`UIPanelButtonTemplate`、`OptionsSliderTemplate`），2026-08-23
全部改成跟 [[project-miliui-unit-frame]] 同一套的自製設定視窗，ESC 選單「米利UI設定」
點下去開的就是它。

**每支的結構**（都是照 MiliUI_Focus 的簡化版抄的）：

```
Libs/MiliUIWidgets/{PixelPerfect,Env,Widgets,Controls}.lua   ← 見 [[project-miliui-widgets-vendor]]
Libs/Callbacks.lua            ← 也是逐字複製，六支一模一樣
Options/Panel.lua             ← 視窗骨架（分頁鈕兼拖曳把手＋戰鬥遮罩）
Options/Tab_*.lua             ← 每個分頁自己註冊 ShowOptionsTab、懶初始化
Options/Blizzard.lua          ← 暴雪「選項>插件」只剩一頁「開啟設定」按鈕
Api.lua                       ← 斜線指令＋MiliUI_MenuEntries 那一筆
```

分頁：藥水助手＝一般／藥水清單／巨集／關於；嗜血音樂＝音樂／曲目／倒數條／提醒／關於；
聊天列＝一般／頻道／關於。

**幾個踩過的點**：

- `Options/Panel.lua` 需要 `ns.VERSION` / `ns.PREFIX_COLOR` / `ns.ReportError`，
  三支原本都沒有 → 補在各自的核心檔（Core.lua／Config.lua／ChatBar.lua）頂端。
- 視窗位置存進各自的 SavedVariables，但**舊 DB 沒有那一格**，所以
  `WindowPos()` 每次都自己補 `optionsWindow = {x=0,y=0}`，不假設 DEFAULTS 有。
- 聊天列的「全部重置」原本是 `StaticPopupDialogs`，改成 `ns.ResetAll()` ＋
  共用層的 `W.CreateConfirmPopup`。**`SetUserPlaced(false)` 一定要在 `ReloadUI()` 之前**，
  否則暴雪會把舊位置寫回去。
- 分頁裡監聽全域高頻事件（藥水清單的 `ITEM_DATA_LOAD_RESULT`）要掛在**分頁 frame 的
  OnShow/OnHide**，不要掛在切分頁的 callback：直接關掉整個視窗時不會派送
  `ShowOptionsTab`，但子框的 OnHide 照樣會跑。同理刷新守衛要用 `IsVisible()` 不是
  `IsShown()`（分頁自己一直是 Show 的）。
- 聊天列新增了 `/mchatbar`（`/mcb`）指令，TOC 的 Notes-zhTW 從「Esc>選項>插件」改成指令。
- 嗜血音樂的 `ns.testBarBtnRef` 是 Music.lua 直接改按鈕文字用的（測試條開著會變成
  「隱藏倒數條」），所以那顆按鈕必須是實體按鈕、而且要掛回 ns。

相關：[[project-miliui-widgets-vendor]]、[[project-miliui-focus-addon]]
