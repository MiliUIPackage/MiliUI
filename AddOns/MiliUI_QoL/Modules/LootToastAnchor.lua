------------------------------------------------------------
-- 自訂戰利品通知位置（戰利品通知過濾的選做項，開關獨立）
--
-- 做法：一個自己的錨框（編輯模式可拖、存 UIParent CENTER 偏移；拖曳走共用層 Libs/MiliUIEditMode.lua），
-- 勾選時把 AlertFrame 錨到它上面：
--   AlertFrame:ClearAllPoints(); AlertFrame:SetPoint("BOTTOM", anchor, "BOTTOM")
-- 取消勾選時改回暴雪 XML 的原位 BOTTOM, UIParent, BOTTOM, 0, 128。
-- **沒勾過就完全不碰 AlertFrame**（moved 旗標，只有我們動過才還原）。
--
-- 事實（Blizzard_FrameXML/Mainline/AlertFrames.xml／.lua，12.1.5）：
--   * AlertFrame 是一般 Frame（10×10），不是保護框；全 FrameXML 沒有地方重錨它
--   * 通知從 AlertFrame 往上排；擲骰框（GroupLootContainer）、NPC 對話框（TalkingHead）
--     顯示時，通知改從它們上緣往上排 —— 那是暴雪的排法，搬了位置也一樣
-- ⚠ 只用 C 端的 ClearAllPoints／SetPoint，不寫 AlertFrame 的任何欄位。UpdateAnchors 會在
--   暴雪的執行裡讀它的位置，戰鬥中拾取、開關背包與天賦有沒有 taint 要實機確認。
------------------------------------------------------------
local _, ns = ...

local AN = {}
ns.LootToastAnchor = AN

local ANCHOR_W, ANCHOR_H = 280, 90
local DEFAULT_OFFSET_Y = 128      -- AlertFrames.xml：<Anchor point="BOTTOM" x="0" y="128"/>

local EM = ns.MiliUIEditMode

local started = false
local moved = false

local function Cfg()
    return ns.db and ns.db.lootToast
end

------------------------------------------------------------
-- 錨框：開檔就建（選取框也是，技能的規矩）
------------------------------------------------------------
local anchor = CreateFrame("Frame", "MiliUIQoL_LootToastAnchor", UIParent)
anchor:SetSize(ANCHOR_W, ANCHOR_H)
anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, DEFAULT_OFFSET_Y)
anchor:SetMovable(true)
anchor:SetUserPlaced(false)       -- 位置自己存 SavedVariables，不給版面快取管
anchor:SetClampedToScreen(true)
AN.frame = anchor

local function PlaceAnchor()
    local c = Cfg()
    anchor:ClearAllPoints()
    if c and type(c.x) == "number" and type(c.y) == "number" then
        anchor:SetPoint("CENTER", UIParent, "CENTER", c.x, c.y)
    else
        -- 沒拖過：跟暴雪預設同一個位置（不換算成 CENTER 偏移存檔：登入時 UIParent
        -- 尺寸還不是最終值，算出來的數字會是錯的）
        anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, DEFAULT_OFFSET_Y)
    end
end

------------------------------------------------------------
-- 編輯模式拖曳（Libs/MiliUIEditMode.lua）：選取框（開檔就建）、三重進出訊號、手動拖曳、
-- 格線吸附、戰鬥閘都在共用層。錨框是普通框，戰鬥中進出也安全。
------------------------------------------------------------
local function MoveEnabled()
    local c = Cfg()
    return (started and c and c.moveEnabled) and true or false
end

local UpdateEditModeState   -- 下面定義

local mover = EM.Attach(anchor, {
    name     = "戰利品通知",
    enabled  = MoveEnabled,
    save     = function(f)
        local c = Cfg()
        local x, y = EM.CenterOffset(f)
        if c and x then c.x, c.y = x, y end
        PlaceAnchor()
    end,
    restore  = PlaceAnchor,
    onChange = function() UpdateEditModeState() end,
})

-- 選取框亮／收；收起來時拖到一半的照現況存下
function UpdateEditModeState()
    mover:Refresh()
    if not (EM.IsActive() and MoveEnabled()) then mover:EndDrag(true) end
end

------------------------------------------------------------
-- 套用：設定一改就叫；叫幾次都沒有副作用
------------------------------------------------------------
function AN.Apply()
    if not started or not AlertFrame then return end
    local c = Cfg()
    if c and c.moveEnabled then
        PlaceAnchor()
        AlertFrame:ClearAllPoints()
        AlertFrame:SetPoint("BOTTOM", anchor, "BOTTOM")
        moved = true
    elseif moved then
        AlertFrame:ClearAllPoints()
        AlertFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, DEFAULT_OFFSET_Y)
        moved = false
    end
    UpdateEditModeState()
end

-- 重設位置：回到暴雪預設的那一格
function AN.ResetPosition()
    local c = Cfg()
    if not c then return end
    c.x, c.y = nil, nil
    PlaceAnchor()
end

function AN.IsMoved()
    return moved
end

ns.RegisterCallback("Init", "LootToastAnchor", function()
    started = true
    AN.Apply()
end)
