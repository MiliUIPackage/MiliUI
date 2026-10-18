# MiliUIMinimapButton

套組插件的小地圖按鈕：31×31 的 Button、暴雪圓框、沿小地圖邊緣拖曳、位置存**角度**。純手刻零依賴，
不走 LibDBIcon。**唯一 source 是這個資料夾**（`AddOns/MiliUI/Libs/MiliUIMinimapButton/MiliUIMinimapButton.lua`），
其餘全部是 vendor 複製。

五支插件原本各抄一份，兩條規則每份都要各補：「點了沒反應」的修法（不用 RegisterForDrag，自己量位移
＋最短按住時間，點擊統一在 OnMouseUp 判斷）、「被 MiliUI_Minimap 收納袋收走之後不能再往小地圖邊緣
SetPoint」（會把它從袋子裡拽出來、格子留洞）。現在規則只住這裡。

## 為什麼是 vendor

跟 [MiliUISnap](../MiliUISnap/README.md) 同一個理由：插件各自獨立發佈、玩家可能只裝一支。純函式庫、
不寫全域（按鈕本身要有全域名，那是收納袋的設定鍵，不算）。

⚠ **MiliUI 本體只放 source，不載入**（`MiliUI.toc` 裡沒有這一行）。

## 複製契約

複製到 `<插件>/Libs/MiliUIMinimapButton.lua`（單一檔），**逐字不改**。改了這裡就跑
`python3 .claude/scripts/sync-widgets.py` 同步（新消費者先手動複製一次），再跑 `bash .claude/scripts/run_tests.sh`。
載入順序：任何 `Create` 之前；只讀 `ns`。

## 用法

```lua
local handle = ns.MiliUIMinimapButton.Create({
    name    = "MiliUIXX_MinimapButton",             -- 全域名：唯一、結尾 MinimapButton、不以數字結尾
    icon    = "Interface\\Icons\\…",
    db      = function() return ns.db.minimap end,  -- 存 angle 的表；回 nil 時 Apply 先不建
    shown   = function() return ns.db.minimap.show end,
    onClick = function(button) if button == "RightButton" then ns.OpenOptions() else ns.Window.Toggle() end end,
    tooltip = function(tt, onMinimap)
        tt:AddLine(ns.PREFIX_COLOR .. L["MiliUI XX"] .. "|r")
        if onMinimap then tt:AddLine(L["Drag: move around the minimap"], 0.8, 0.8, 0.8) end
    end,
})
ns.RegisterCallback("Init", "minimap", function() handle:Apply() end)
```

`handle:Apply()` —— 登入、設定改變、還原預設值都叫這一支：該顯示就（建、）擺位置、Show；不該就 Hide。
其他：`Button()`、`OnMinimap()`（還掛在小地圖上）、`UpdatePosition()`、`Angle()`／`SetAngle()`、`RefreshIcon()`、`IsShown()`。

| opts | |
|---|---|
| `name` | 必填。全域名（收納袋用名字當 pinned 的設定鍵，改名等於玩家釘選失效） |
| `icon` | 圖示路徑／fileID，放在 `btn.icon`（收納袋照這個欄位找圖） |
| `portrait` | 選用：單位 token（`"player"`）。顯示 2D 頭像（圓形裁切），拿不到退回 `icon`；自己聽 PORTRAITS_UPDATED／PLAYER_ENTERING_WORLD／UNIT_PORTRAIT_UPDATE（只綁那個單位） |
| `db` | `function() → 表` 或直接給表；角度存 `db[angleKey]` |
| `angleKey`／`defaultAngle` | 預設 `"angle"`／215 |
| `shown` | `function() → bool`，預設永遠顯示 |
| `onClick(button, btn)` | 點一下沒拖（左右鍵都會進來） |
| `tooltip(GameTooltip, onMinimap)` | 在 `SetOwner(btn, "ANCHOR_LEFT")` 之後、`Show()` 之前加行 |
| `log(fmt, …)` | 除錯記錄（按下／進入拖曳／放開） |

## 跟 MiliUI_Minimap 收納袋的契約（`Map/Buttons.lua`）

- 有全域名、是 Button、寬 ≥ 18、圖示在 `.icon`；另外標 `btn.miliuiMinimapButton = true`，`Qualifies` 直接認記號。
- 收走之後父層不是 `Minimap`：`OnMinimap()` 為 false 時**不拖、Apply 也不重新定位**；tooltip 回呼拿到 `onMinimap=false` 可以不印「拖曳」那行。
- 收納袋會 `RegisterForDrag()` 清掉拖曳登記——我們本來就不靠它（OnMouseDown 自己量），所以要靠上一條擋。

## 刻意不含

- 不做 LibDBIcon 相容（DataBroker 物件、`minimapPos` 存法）——套組的鈕不需要跟別人互通。
- 不做右鍵選單——那是宿主的事（`onClick("RightButton")` 裡自己開 `W.Menu`）。

## 消費者

以 `ls AddOns/*/Libs/MiliUIMinimapButton.lua` 為準。
