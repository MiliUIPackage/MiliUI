------------------------------------------------------------
-- 確認倒數：資料層（三顆鍵的動作、巨集、顯示條件）
--
-- 方塊在 Core/Blocks.lua（readycheck），設定分頁在 Options/Tab_ReadyCheck.lua。
-- 設定存 db.readycheck = { onlyInGroup, left/middle/right = { action, seconds } }。
--
-- ⚠⚠ 動作一律走 secure 巨集跑暴雪自己的斜線指令（/readycheck、/cd N），
--   **不要**改成在 Lua 裡直呼 C_PartyInfo.DoReadyCheck／DoCountdown。
--   API 文件上那兩支都是 `HasRestrictions = true`（DoCountdown 還加上
--   SecretArguments = AllowedWhenUntainted）——插件端的呼叫會被 12.x 的情境限制擋下，
--   而開怪倒數最常按的時機正好就是首領戰前、整趟鑰石裡（ChallengeMode 限制整趟都算，
--   見 .claude/notes/wow-12x-addon-restrictions.md）。巨集處理器是暴雪的碼，從 secure
--   按鈕點下去是乾淨的執行，不受那套限制。
--   按鈕寫法照 MiliUI_ChatBar 的開怪鈕（type／macrotext）。但那顆的倒數是自訂斜線指令
--   再從 Lua 呼叫 DoCountdown——那段仍是插件端執行，這裡刻意不抄那一半，改用暴雪原生的
--   `/cd N`（`/cd 0` ＝取消倒數）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.ReadyCheck = {}
local RC = ns.ReadyCheck

RC.ICON = "Interface\\RaidFrame\\ReadyCheck-Ready"

-- 按鍵：index 是 SecureActionButton 的按鍵編號（左 1、右 2、中 3），
-- 列出順序照使用者習慣的「左／中／右」
RC.BUTTONS = {
    { key = "left",   index = 1, label = "READYCHECK_LEFT"   },
    { key = "middle", index = 3, label = "READYCHECK_MIDDLE" },
    { key = "right",  index = 2, label = "READYCHECK_RIGHT"  },
}

RC.ACTIONS = { "none", "readycheck", "countdown", "cancel" }

local ACTION_LABEL = {
    none       = "RC_ACTION_NONE",
    readycheck = "RC_ACTION_READYCHECK",
    countdown  = "RC_ACTION_COUNTDOWN",
    cancel     = "RC_ACTION_CANCEL",
}

-- 設定頁滑桿的範圍。暴雪的上限是 Constants.PartyCountdownConstants.MaxCountdownSeconds
-- （很大），但開怪倒數實際不會超過一分鐘，滑桿拉太長反而難調
RC.MIN_SECONDS = 1
RC.MAX_SECONDS = 60

function RC.ActionLabel(action)
    return L[ACTION_LABEL[action] or ACTION_LABEL.none]
end

-- 某顆鍵現在的 action, seconds。存檔被手改壞（未知動作、秒數不是數字）就退回無／預設
function RC.Binding(key)
    local cfg = ns.GetDB().readycheck
    local b = cfg and cfg[key]
    if type(b) ~= "table" or not ACTION_LABEL[b.action] then return "none", 10 end
    local sec = tonumber(b.seconds) or 10
    sec = math.floor(math.min(math.max(sec, RC.MIN_SECONDS), RC.MAX_SECONDS))
    return b.action, sec
end

-- 巨集內容；"none" 回 nil（那顆鍵不做事）
function RC.Macro(action, seconds)
    if action == "readycheck" then return "/readycheck" end
    if action == "countdown"  then return "/cd " .. seconds end
    if action == "cancel"     then return "/cd 0" end
    return nil
end

-- 給提示／面板看的一行字：「開怪倒數 10 秒」
function RC.Describe(action, seconds)
    if action == "countdown" then
        return L["RC_COUNTDOWN_FMT"]:format(seconds)
    end
    return RC.ActionLabel(action)
end

function RC.UsesAction(action)
    for _, b in ipairs(RC.BUTTONS) do
        if (RC.Binding(b.key)) == action then return true end
    end
    return false
end

-- 「在隊伍／團隊內啟用」勾著的時候，不在隊伍裡就整顆不顯示。
-- IsInGroup() 不帶參數＝一般隊伍或副本隊伍（隨機地城／戰場）任一種都算
function RC.ShouldShow()
    local cfg = ns.GetDB().readycheck
    if not (cfg and cfg.onlyInGroup) then return true end
    return IsInGroup() and true or false
end

-- 暴雪 /readycheck 處理器的同一道閘（Blizzard_ChatFrameBase SlashCommands.lua）。
-- 沒權限時斜線指令安靜地什麼都不做，所以提示要說出來
function RC.CanReadyCheck()
    return (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and true or false
end

------------------------------------------------------------
-- Cell 標記工具列的快速開關（滑過面板裡那一列）
--
-- 讀寫的就是 Cell 自己設定頁「工具 > 標記工具列」那個勾選框背後的欄位
-- （CellDB.tools.marks[1]），寫完照它自己勾選框的做法發 UpdateTools，所以兩邊永遠
-- 是同一個值，不另外存。Cell 沒載入、或存檔結構對不上就當作沒有，面板不顯示這列。
------------------------------------------------------------
local function CellMarks()
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Cell")) then return nil end
    local cell, cdb = _G.Cell, _G.CellDB
    if type(cell) ~= "table" or type(cell.Fire) ~= "function" then return nil end
    local tools = type(cdb) == "table" and cdb.tools
    local marks = type(tools) == "table" and tools.marks
    if type(marks) ~= "table" then return nil end
    return marks, cell
end

function RC.HasCellMarks()
    return CellMarks() ~= nil
end

function RC.CellMarksEnabled()
    local marks = CellMarks()
    return marks and marks[1] and true or false
end

-- 回傳是否真的切換了。戰鬥中不動：Cell 那排裡有 secure 按鈕（世界標記），
-- 它自己的更新在戰鬥中也是延到脫戰，這裡乾脆不收這一下
function RC.SetCellMarksEnabled(on)
    local marks, cell = CellMarks()
    if not marks or InCombatLockdown() then return false end
    marks[1] = on and true or false
    cell.Fire("UpdateTools", "marks")
    -- Cell 的設定視窗正開在「工具」分頁的話，勾選框要跟著變：重發它自己的分頁切換，
    -- 讓它照目前的子頁重讀一次存檔（其他分頁的處理器在非自己分頁時都只做 Hide，重發無副作用）。
    -- 沒開著就不碰——下次開頁它本來就會重讀
    local tab = type(cell.frames) == "table" and cell.frames.utilitiesTab
    if tab and tab.IsVisible and tab:IsVisible() then
        cell.Fire("ShowOptionsTab", "utilities")
    end
    return true
end

-- 把三顆鍵的巨集寫進 secure 方塊。SetAttribute 在戰鬥中對 secure 按鈕是違禁品，
-- 延到脫戰（實際上只有 ApplyAll 會叫，ApplyAll 本身已經延過了）
function RC.ApplyBindings(tile)
    if InCombatLockdown() then
        ns.Defer("readycheck-bindings", function() RC.ApplyBindings(tile) end)
        return
    end
    for _, b in ipairs(RC.BUTTONS) do
        local macro = RC.Macro(RC.Binding(b.key))
        tile:SetAttribute("*type" .. b.index, macro and "macro" or nil)
        tile:SetAttribute("*macrotext" .. b.index, macro)
    end
end
