------------------------------------------------------------
-- 確認倒數：滑過方塊彈出來的面板
--
-- 由上而下：三顆鍵各做什麼 →（按了沒反應的原因）→ 標記工具列開關（沒裝那支插件
-- 就沒有這段）→ 最底下的設定入口。
--
-- 皮、開關節奏、定位、列層與所有版面常數都在 Core/HoverPanel.lua，這支只負責
-- 「這張面板有哪些列」。
--
-- 三顆鍵的列刻意跟坐騎面板的快捷列**同一種寫法**：主文字寫「按下去會發生什麼」，
-- 右側灰標寫「哪顆鍵」。原本是自己一張兩欄格線（鍵名欄在左、動作在右），那會讓
-- 同一條資訊列上的兩張面板出現兩種欄位語意。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local HP = ns.HoverPanel
local RC = ns.ReadyCheck

ns.ReadyCheckPopup = {}
local Popup = ns.ReadyCheckPopup

local panel         -- 檔尾建立

------------------------------------------------------------
-- 列的動作
------------------------------------------------------------
-- 開關型項目按下去**原地重畫**（打勾即時更新），不關面板
local function ToggleCellMarks()
    if RC.SetCellMarksEnabled(not RC.CellMarksEnabled()) then
        panel:Refresh()
    end
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function BuildModel()
    local model = {}

    for _, b in ipairs(RC.BUTTONS) do
        local action, seconds = RC.Binding(b.key)
        model[#model + 1] = {
            kind = "item",
            text = RC.Describe(action, seconds),
            tag  = L[b.label],
            dim  = (action == "none"),
        }
    end

    -- 按下去沒反應的兩種情況要說出來：暴雪的斜線指令在這兩種情況都安靜地什麼都不做
    if not IsInGroup() then
        model[#model + 1] = { kind = "note", text = L["RC_TIP_SOLO"] }
    elseif RC.UsesAction("readycheck") and not RC.CanReadyCheck() then
        model[#model + 1] = { kind = "note", text = L["RC_TIP_NEED_LEAD"] }
    end

    if RC.HasCellMarks() then
        model[#model + 1] = { kind = "sep" }
        model[#model + 1] = {
            kind    = "item",
            text    = L["RC_CELL_MARKS"],
            check   = RC.CellMarksEnabled(),
            onClick = ToggleCellMarks,
        }
    end

    -- 設定入口永遠在最底下
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "settings", text = L["RC_POPUP_SETTINGS"], tab = "readycheck" }
    return model
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
panel = HP.New({
    name = "MiliUIInfoBar_ReadyCheckPopup",
    populate = function(rows)
        rows:Render(BuildModel())
    end,
})

------------------------------------------------------------
-- 對外（名字保留給 Core/Blocks.lua）
------------------------------------------------------------
function Popup.CancelClose()   panel:CancelClose() end
function Popup.CancelOpen()    panel:CancelOpen() end
function Popup.Hide()          panel:Hide() end
function Popup.ScheduleClose() panel:ScheduleClose() end
function Popup.Open(tile)         panel:Open(tile) end
function Popup.ScheduleOpen(tile) panel:ScheduleOpen(tile) end
function Popup.IsOpenFor(tile)    return panel:IsOpenFor(tile) end
