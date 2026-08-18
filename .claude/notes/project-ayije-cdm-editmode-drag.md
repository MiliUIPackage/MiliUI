---
name: project-ayije-cdm-editmode-drag
description: Ayije_CDM 四個冷卻檢視器改成可在編輯模式拖曳；四種錨點語意的換算表與兩個受限情境
metadata:
  type: project
---

2026-08-18 把 Ayije_CDM 的編輯模式從「鎖死」改成「可拖曳」。**這是本地 fork 改動，上游
更新會整包洗掉**，見 [[project-local-addon-forks]]。

上游原本的 `Core/EditMode.lua` 整支的作用就是鎖：系統框 `SetMovable(false)`、把 Selection
的 `OnDragStart` 清成 nil、選到就蓋紅字「Edit Mode locked - use /acdm」。位置只能從
`/acdm` 的 X/Y 滑桿調。（語系檔裡還留著上上個版本的 `L["Click and drag to move - ..."]`，
沒有任何程式碼用到，代表更早以前是可拖的。）

**做法：拖 CDM 自己的 `anchorContainer`，不碰暴雪的系統框。** 系統框維持
`SetMovable(false)` 並繼續被釘在容器上，所以位置不會進暴雪的 Edit Mode layout，沒有 taint
風險。Selection 已經被 `UpdateEditModeSelectionOverlay` 錨到容器上，藍框視覺本來就對齊，
只要把它的 drag script 換成移動容器即可（**用 `SetScript` 不是 `HookScript`** —— 暴雪原本
那條路是去移動系統框自己，要整條換掉）。

改動的檔案：`Core/EditMode.lua`（前半整段重寫）、`Core/Layout/Layout.lua`（加
`CDM:GetViewerPositionSettings` getter ＋ 三處 `draggingViewer` 閘）、`Core/Main.lua`（兩個
函式改名 ＋ EditMode.Exit 清標記）、`Ayije_CDM_Options/{Positions,Layout}.lua`（滑桿同步）、
`Locales/{zhTW,zhCN}.lua`。全部有 `fix from MiliUI` 標記。

**Why:** 四個容器的錨點語意**每個都不一樣**，換算共用一套一定會偏；這張表是重做時最貴的部分。

**How to apply:** 放開滑鼠後這樣回推（`halfW` 一律用 `Pixel.HalfFloor`，跟 Layout.lua 同一個
實作，換別的會來回漂）：

| 容器 | 套用時的錨點 | 反推 |
|---|---|---|
| Essential | `TOPLEFT → UIParent point, (x - halfW, y)` | `x = left + halfW - ax`；`y = top - ay` |
| Buff | `BOTTOM → UIParent point, (x, y)` | `x = GetCenter() - ax`；`y = bottom - ay` |
| BuffBar | 往下長 `TOPLEFT`／往上長 `BOTTOMLEFT`，x 一樣扣半寬 | x 同 Essential；y 取 top 或 bottom 看 `buffBarGrowDirection` |
| Utility | `TOPLEFT → essContainer BOTTOMLEFT, (essHalfW - utilHalfW + xOff, -spacing + yOff)` | `xOff = util.left - ess.left - essHalfW + utilHalfW`；`yOff = util.top - ess.bottom + spacing` |

`ax, ay` 是 UIParent 上 `pos.point` 的座標（實務上一律 CENTER，但 db 存得下別的值，別寫死）。

**兩個框的拖曳會被別的設定限制住**，拖的時候框上會蓋一行黃字說明：

- **Utility 的水平**：`utilityXOffset` 只有在 `utilityWrap` ＋ `utilityUnlock` 都開時才被
  `GetLayoutConfig` 採用（沒開強制 0），所以沒解鎖時只寫 Y。
- **Buff 跟隨資源條**：`moveBuffsDown` 生效時 `UpdateBuffContainerPosition` 會直接錨到資源條，
  拖了會被拉回。判斷條件要跟那個函式保持一致（含 `moveBuffsDownFallback` 的兩種退路）。

其他要點：`container:SetUserPlaced(false)` 每次放開都要清（容器**有名字**，會被 layout cache
接管）；`CDM.draggingViewer` 在拖曳中擋掉 `ReanchorContainer`／`UpdateBuffBarContainerPosition`
／`UpdateBuffContainerPosition`，並在 `EditMode.Exit` 一律清掉（滑鼠在視窗外放開時
`OnDragStop` 不一定進得來，卡住的話之後所有重錨都失效）。暴雪的
`EditModeSystemSettingsDialog` 仍然攔下來 Hide —— 那裡的選項跟 CDM 不同步，開了只會誤導。
