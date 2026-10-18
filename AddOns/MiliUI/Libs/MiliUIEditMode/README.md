# MiliUIEditMode

自訂框在暴雪編輯模式裡可拖曳：選取框、進出訊號、手動拖曳、格線吸附、戰鬥閘。
**唯一 source 是這個資料夾**（`AddOns/MiliUI/Libs/MiliUIEditMode/MiliUIEditMode.lua`），其餘全部是 vendor 複製。

這是 `.claude/skills/wow-editmode-draggable/SKILL.md` 那份配方的程式碼版：套組每支插件原本各抄一份，
每一條地雷（OnMouseDown 要 no-op、StartMoving 在保護框上是死的、三重訊號、戰鬥中進出編輯模式）
都得各補一次。現在規則只住這裡；技能文件留著講「為什麼」。

## 為什麼是 vendor

跟 [MiliUISnap](../MiliUISnap/README.md) 同一個理由：消費它的插件各自獨立發佈、玩家可能只裝一支。
每支插件各自掛暴雪的勾（HookScript／hooksecurefunc 本來就可以疊）、各管自己的 mover，
不寫任何全域；EventRegistry 的 owner 用各自那張表，不會互相蓋掉。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）。

## 複製契約

複製到 `<插件>/Libs/MiliUIEditMode.lua`（單一檔），**逐字不改**。改了這裡就跑
`python3 .claude/scripts/sync-widgets.py` 同步（新消費者先手動複製一次），再跑 `bash .claude/scripts/run_tests.sh`。

載入順序：`Libs\MiliUISnap.lua` 之後（放手時走 `ns.Snap` 對齊，沒有也行）、任何 `Attach` 之前。
只讀 `ns`（`ns.Snap`、`ns.P.Pixel` 都是選用）。

## 用法

```lua
local EM = ns.MiliUIEditMode

frame:SetMovable(true)
frame:SetUserPlaced(false)          -- 位置自己存 SavedVariables，不給版面快取管
frame:SetClampedToScreen(true)
local function Reposition() EM.ApplyCenter(frame, db.x, db.y) end
Reposition()

local mover = EM.Attach(frame, {
    name     = L["BAR_NAME"],                              -- 選取框上的標籤（字串或 function）
    save     = function(f) db.x, db.y = EM.CenterOffset(f); Reposition() end,
    restore  = Reposition,                                 -- 拖曳被中斷（進戰鬥）時照存檔放回
    onChange = function(editing) if editing then ShowSample() else HideSample() end end,
    enabled  = function() return db.enabled end,           -- 關著就不亮選取框
    snapKey  = "myBar",                                    -- MiliUISnap 的 key（有註冊才給）
})
```

### `Attach(frame, opts) → mover`

| opts | |
|---|---|
| `name` | 選取框標籤：字串或 `function(frame)` |
| `save(frame)` | 放手時（已確認不在戰鬥）。**宿主照框的現況存座標、並照存檔重貼**（拖曳中框是 TOPLEFT 錨在 UIParent 上的） |
| `restore(frame)` | 拖曳被中斷（進戰鬥、框不見）：照存檔放回。宿主是保護框時走戰鬥閘 |
| `onChange(editing, mover)` | 進出編輯模式（**下一幀**）：給樣板內容、平常藏著的框要 `Show` 讓玩家瞄得到。`editing` ＝ 暴雪編輯模式 or `SetForced` |
| `enabled(frame)` | 回 false 時進了編輯模式也不亮選取框（功能關著） |
| `canDrag(frame)` | 回 false 時不能拖（鎖定、停靠中） |
| `onClick(frame, button)` | 點一下沒拖（下一幀），例如開設定頁 |
| `onDragStart(frame)`／`onDragStop(frame, committed)` | 拖曳前後的掛點 |
| `snapKey` | MiliUISnap 的 key：開拖 `OnDragStart`、放手 `OnDragStop`（Shift 不吸）。`Register` 仍由宿主做 |
| `grid` | `false` 就不吸暴雪格線（預設吸：暴雪吸附開著、格線看得到、沒按 Shift） |
| `anchorPoint` | 吸格線時用框的哪一點（預設 `CENTER`；錨左下角存檔的條給 `BOTTOMLEFT`） |

mover：`Refresh()`（依狀態亮／收選取框，走戰鬥閘）、`Editing()`、`SetForced(bool)`（設定視窗開著也能拖）、
`BeginDrag()`／`EndDrag(commit)`、`IsDragging()`、`.selection`、`.isFallback`。宿主框上會記 `frame.miliuiMover`。

### 全域（每支插件各一份）

`IsActive()`、`OnChange(owner, fn)`／`OffChange(owner)`（狀態改變時 `fn(active)`，下一幀）、`Dragging()`、
`ReadBlizzard()`、`GridSpacing()`／`SnapEnabled()`／`ActiveGridSpacing()`、`Defer(fn)`、`Write(frame, fn)`（戰鬥閘）。

### 幾何（純函式，離線有測）

`RectOf(frame)`、`CenterOffset(frame)`／`CenterOffsetOf(rect, parent)`、`ApplyCenter(frame, x, y)`、
`PointXY`、`SnapDelta`、`SnapValue`、`Round`。

## 規矩（每條都是撞過的）

- **選取框開檔就建**（Attach 時），`pcall` 建模板、建不出來自畫藍框頂著。在暴雪 OnShow 執行路徑裡建框實測整組靜默失效。
- **模板的 OnMouseDown 換掉**：XML 綁了 `EditModeManagerFrame:SelectSystem(self.parent)`，自訂框不是真系統，讓它跑＝
  整條選取流程帶著本插件的 taint 掃過每一個已註冊系統（快捷列在內），當下靜默、戰鬥中才爆。
- **拖曳手動算**，不用 `StartMoving`：保護框＋編輯模式那條路它是死的，手動機制兩種框通吃。driver 只在拖曳中有 OnUpdate。
- **三重訊號、派送延一幀**：管理視窗 OnShow/OnHide、EnterEditMode/ExitEditMode 後掛勾、EventRegistry。處理器只改旗標，
  工作在下一幀（離開暴雪的執行堆疊，見 notes/wow-121-addon-code-in-secure-stack.md）。
- **編輯模式不會被戰鬥關掉**：進出處理器可能在鎖定中跑。碰選取框一律走 `Write`（宿主受保護且在戰鬥中就記到
  `PLAYER_REGEN_ENABLED`）；`PLAYER_REGEN_DISABLED` **同步**收掉進行中的拖曳、`restore`、不寫 db。
- **吸附參數讀暴雪的**（吸附開關、格線間距、格線 `IsVisible`），不另開設定；Shift 一律不吸。
- 放手 `SetUserPlaced(false)`：框有名字時不清，WoW 的版面快取會跟宿主的 SetPoint 打架。

## 刻意不含

- **不碰暴雪的系統框**（冷卻管理器四條檢視器那套 WireViewer／藏設定對話框）——那是對暴雪框的後掛勾，規矩不同，留在 CDM。
- **不做方向鍵微調、不做條與條對齊**（CDM 的 AlignDelta）：跨插件的對齊走 MiliUISnap。
- **不決定位置怎麼存**：`save`／`restore` 由宿主給；`CenterOffset`／`ApplyCenter` 是建議的存法。

## 消費者

以 `ls AddOns/*/Libs/MiliUIEditMode.lua` 為準。還沒換過去的見 `.claude/notes/project-miliui-widgets-vendor.md`。
