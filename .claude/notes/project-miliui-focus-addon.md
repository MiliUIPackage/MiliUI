---
name: project-miliui-focus-addon
description: MiliUI_Focus「米利的焦點助手」——從套組拆出來的獨立插件，含一次性 SV 遷移的設計
metadata: 
  node_type: memory
  type: project
  originSessionId: dcc3afbf-4625-45df-80f1-5c77e6f5a5b9
  modified: 2026-08-22T15:22:42.057Z
---

2026-08-22 把 MiliUI 套組裡「焦點目標」那一整組功能拆成獨立插件
`AddOns/MiliUI_Focus`（Title-zhTW `|cff00FFFF[焦點]|r 米利的焦點助手`、
SV `MiliUI_Focus_DB`、指令 `/mfocus`、NAMESPACE `MiliUIFocus`）。
**MiliUI 那邊的四支 `Enhance/Focuser*.lua` 與 Settings.lua 的「焦點目標」子分類已整個刪除**
（同時跑會有兩顆巨集按鈕、兩條標記列、宣告送兩次）。`MiliUI/Media/announce.tga` 也搬過來了。

## 檔案對照

| 舊 | 新 |
|---|---|
| `MiliUI/Enhance/Focuser.lua` | `Modules/Focuser.lua` |
| `MiliUI/Enhance/FocuserBar.lua` | `Modules/MarkBar.lua` |
| `MiliUI/Enhance/FocuserSync.lua` | `Modules/Sync.lua` |
| `MiliUI/Enhance/FocuserCastBar.lua` | `Modules/CastBar.lua` |
| `MiliUI/Settings.lua` 的焦點子分類 | `Options/Tab_Focus / Tab_Bar / Tab_Cast` |

行為與註解逐條照搬（secret value 的處理、安全動作標記、巨集委派…細節見
[[project-focuser-castbar]] 與 [[project-raidtarget-secure]]，那兩份的路徑已更新）。
全域 API `MiliUI_Focuser` / `MiliUI_FocusCast` 不再存在，改成插件內部的 `ns.Focuser` /
`ns.CastBar`；設定改完一律走 `ns.Focuser.Apply()` / `ns.CastBar.Apply()` 一個入口。

## 一次性遷移（使用者要求的重點）

`Core/DB.lua`：`MergeDefaults` 補完預設值 **之後** 才看要不要遷移，因為遷移要寫進
`db.focus / db.bar / db.cast` 這些子表。

- 印記 `db.miliuiMigration`：`nil` = 還沒查過，`"migrated"` / `"none"` / `"reset"` = 查過了。
  **只要不是 nil 就永遠不再讀 `MiliUI_DB`**，一切以自身設定為準。
- 沒東西可搬（MiliUI 沒裝／沒存過焦點設定）也照樣蓋印記。理由：不蓋的話每次登入都要再看
  一次，玩家哪天把舊套組裝回來就會被舊值蓋掉現有設定。
- **`DB.ResetAll` 不能整包清成 nil**，要寫成 `{ miliuiMigration = "reset" }` ——
  否則下次登入又從 `MiliUI_DB` 搬一次，玩家按的「還原預設值」等於沒按。
- 補救路徑 `/mfocus migrate`：第一次啟動時剛好停用 MiliUI 的人可以手動補搬（會覆蓋現有設定，
  所以只在明確下指令時跑）。
- 全程唯讀 `MiliUI_DB`，一個字都不寫（玩家還在用套組的其他功能）。
- 時機：**所有初始化都等 PLAYER_LOGIN**。`MiliUI_DB` 要等 MiliUI 自己的 ADDON_LOADED
  才存在，等到 PLAYER_LOGIN 就不必猜載入順序。模組一律 `ns.RegisterCallback("Init", ...)`。
  ⚠ Init 回呼是 `pairs` 走訪、**順序不保證** —— MarkBar 建選單前要先叫
  `ns.Focuser.EnsureButtons()`，否則格子少了 focuser 的 frame ref，戰鬥中換圖示不會換巨集（靜默）。

舊鍵 → 新鍵：`focuserEnabled/Hotkey/AutoMark/MarkIndex/NoOverwriteMark` → `db.focus.*`；
`focuserBarShown/AnnounceText/BarX/BarY` → `db.bar.*`；`focusCast.*` → `db.cast.*`
（顏色從 `{r,g,b}` 陣列換成 `{r=,g=,b=,a=}`，色票控件吃後者）。

## 預設值（2026-08-22 使用者定案）

`enabled = true`、**`autoMark = false`**、`noOverwriteMark = true`。
自動標記維持預設關：標記是全隊看得到的東西，預設就替玩家把記號蓋到怪身上太主動。
（過程中一度改成預設開，同日又改回關。）

`markIndex` 預設**隨機**，從 1~6 挑（**排除 7 叉叉、8 骷髏**——那兩個是團隊慣例的
擊殺順序／風箏記號，通常由隊長指定，被自動標記搶走會干擾指揮）。
隨機而不是固定 1 號的理由：整隊都裝這支的話，固定值 = 所有人預設盯同一個符號，
一開自動標記就全員撞號，Sync 的撞號提醒會一次跳一整排。**跟 autoMark 預設關不衝突**：
號碼先備好，玩家哪天打開就直接是錯開的。只挑一次，存進 SV 就是玩家自己的設定。

`DB.Init` 收尾有一道正規化：`markIndex` 不在 1~8 就補一個隨機值。0 只會來自「全新安裝」
或「從舊套組搬來但從沒選過圖示」，留 0 的話玩家一打開自動標記就會遇到「開了卻什麼都沒標」
（巨集少一行）。設定頁下拉與標記列選單都只給 1~8，玩家選不出 0。

## 其他決定

- **comm 前綴刻意沿用 `MiliUI_FM`、協定版本不動**：還在用舊套組的隊友照樣互通得到。
- 設定介面走 [[project-miliui-widgets-vendor]]，是第三個消費者；為了「擷取按鍵」與
  「唯讀巨集複製框」在共用層加了通用的 `custom` spec（三份 copy 已同步）。
- **標記列層級：`MEDIUM` ＋ `SetFrameLevel(600)`，兩邊都不要碰**（2026-08-22 試了三次才收斂）。
  詳見 [[wow-actionbar-text-overlay-level-500]] —— 要越過的是快捷鍵**文字層的 500**，
  不是按鈕本體的 level。改成 `HIGH` 則反過來蓋掉天賦樹等暴雪面板（那些面板其實也在
  MEDIUM，只是帶 `toplevel` 會自我抬升），所以只能留在 MEDIUM 把 level 墊高。
- **自訂快捷鍵那一列的鍵盤擷取走覆蓋層 Show/Hide**，不要在按鈕上切
  `EnableKeyboard`／`SetPropagateKeyboardInput` —— 卡住會讓全遊戲快捷鍵含 ESC 全部失效，
  而症狀是「設定視窗按 ESC 關不掉」。踩過一次，見 [[wow-keyboard-capture-blocks-bindings]]。
- 載入時偵測到舊的 `MiliUI_Focuser` 全域就印一次警告（套組沒更新的人），不自動停用。
