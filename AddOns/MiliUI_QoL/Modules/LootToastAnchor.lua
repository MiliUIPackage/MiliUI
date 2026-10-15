------------------------------------------------------------
-- 自訂戰利品通知位置（戰利品通知過濾的選做項，開關獨立）
--
-- 做法：一個自己的錨框（編輯模式可拖、存 UIParent CENTER 偏移，技能 wow-editmode-draggable），
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

local started = false
local moved = false
local isInEditMode = false

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
-- 拖曳：手動算，不用 StartMoving（技能第 3 節）
------------------------------------------------------------
local dragState, dragDriver

local function EndDrag()
    if not dragState then return end
    dragState = nil
    if dragDriver then dragDriver:Hide() end
    local c = Cfg()
    local cx, cy = UIParent:GetCenter()
    local fx, fy = anchor:GetCenter()
    if c and cx and fx then
        c.x = math.floor(fx - cx + 0.5)
        c.y = math.floor(fy - cy + 0.5)
    end
    PlaceAnchor()
end

local function DragTick()
    local d = dragState
    if not d then return end
    -- 收不到 OnDragStop 的情況（滑鼠出視窗、被別的框吃掉）自己補救
    if not IsMouseButtonDown("LeftButton") then EndDrag() return end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - d.cx, cy / scale - d.cy
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (d.left + dx) - pl, (d.top + dy) - pt)
end

local function BeginDrag()
    local left, top = anchor:GetLeft(), anchor:GetTop()
    if not (left and top) then return end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    dragState = { cx = cx / scale, cy = cy / scale, left = left, top = top }
    if not dragDriver then
        dragDriver = CreateFrame("Frame")
        dragDriver:Hide()
        dragDriver:SetScript("OnUpdate", DragTick)
    end
    dragDriver:Show()
end

------------------------------------------------------------
-- 選取框：借 EditModeSystemSelectionTemplate 的藍框，pcall＋自畫備援
------------------------------------------------------------
local sel
do
    local ok, f = pcall(CreateFrame, "Frame", nil, anchor, "EditModeSystemSelectionTemplate")
    if ok and f then
        -- ⚠⚠ 模板 XML 的 OnMouseDown 會呼叫 EditModeManagerFrame:SelectSystem(self.parent)，
        -- 暴雪讀我們寫的 parent ⇒ 整條選取流程帶著本插件的 taint 掃過每個系統（快捷列在內）。
        -- 點一下必須 no-op 化（[[wow-121-addon-code-in-secure-stack]] 入口 8）。
        f:SetScript("OnMouseDown", function() end)
        f.system = { GetSystemName = function() return "戰利品通知" end }
        sel = f
    else
        f = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.25, 0.6, 1, 0.15)
        f:SetBackdropBorderColor(0.25, 0.6, 1, 0.9)
        f:EnableMouse(true)
        f.ShowHighlighted = f.Show
        sel = f
    end
    sel:SetAllPoints(anchor)
    sel:Hide()
    sel:RegisterForDrag("LeftButton")
    sel:SetScript("OnDragStart", BeginDrag)
    sel:SetScript("OnDragStop", EndDrag)
end

local function UpdateEditModeState()
    local c = Cfg()
    if isInEditMode and started and c and c.moveEnabled then
        sel:ShowHighlighted()
    else
        EndDrag()
        sel:Hide()
    end
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

------------------------------------------------------------
-- 進出編輯模式：三重訊號，全部冪等（技能第 4 節）。錨框是普通框，戰鬥中進出也安全。
------------------------------------------------------------
local function OnEnter() isInEditMode = true;  UpdateEditModeState() end
local function OnExit()  isInEditMode = false; UpdateEditModeState() end

local editModeHooked = false
local function HookEditMode()
    if editModeHooked or not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", OnEnter)
    EditModeManagerFrame:HookScript("OnHide", OnExit)
    if EditModeManagerFrame.EnterEditMode then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", OnEnter)
    end
    if EditModeManagerFrame.ExitEditMode then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", OnExit)
    end
    if EditModeManagerFrame:IsShown() then OnEnter() end
end

HookEditMode()
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", OnEnter, "MiliUIQoL_LootToastAnchor")
    EventRegistry:RegisterCallback("EditMode.Exit",  OnExit,  "MiliUIQoL_LootToastAnchor")
end

ns.RegisterCallback("Init", "LootToastAnchor", function()
    HookEditMode()
    started = true
    AN.Apply()
end)
