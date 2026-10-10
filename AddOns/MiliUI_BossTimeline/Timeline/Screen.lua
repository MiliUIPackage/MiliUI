------------------------------------------------------------
-- 畫面上的那一條時間軸
--
-- 什麼時候畫：
--   * 時間軸上有東西（首領戰中）                       → 畫真的
--   * 設定視窗開著（且勾了「畫面上同步預覽」）、或在編輯模式 → 時間軸是空的就畫假資料
-- 預覽狀態下框可以直接拖（設定視窗開著時）或在編輯模式裡拖；兩邊存同一個位置。
--
-- 拖曳照 wow-editmode-draggable 技能：手動算位移、不用 StartMoving；
-- 選取框借 EditModeSystemSelectionTemplate 的外觀，OnMouseDown 一定要中和（見技能 Gotchas）。
--
-- 縮放：外層 holder 不縮放、只管位置；Display 的框掛在 holder 中央再 SetScale。
-- 位置偏移要是在被縮放的框上設，拖曳與存檔的單位會跟著縮放走（.claude/notes/wow-setscale-offset-units.md）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Screen = {}
local Screen = ns.Screen

local holder, display, selection, hint
local inEditMode = false
local optionsOpen = false
local inCombat = false      -- 自己記：PLAYER_REGEN_DISABLED 派送當下 InCombatLockdown() 還是 false

local function DB() return ns.db.display end

local function PreviewWanted()
    return inEditMode or (optionsOpen and ns.db.previewOnScreen)
end

local function Filter(kind)
    local src = DB().sources
    return src[kind] ~= false
end

-- 每幀決定資料來源：有真的就畫真的
local function Collect(out, filter)
    if ns.Events.HasAny(filter) or not PreviewWanted() then
        return ns.Events.Collect(out, filter)
    end
    return ns.Mock.Collect(out, filter)
end

------------------------------------------------------------
-- 位置與拖曳
------------------------------------------------------------
local function ApplyPosition()
    local d = DB()
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", d.x or 0, d.y or 0)
end

local dragState, dragDriver

local function EndDrag()
    if not dragState then return end
    dragState = nil
    if dragDriver then dragDriver:Hide() end
    local cx, cy = UIParent:GetCenter()
    local fx, fy = holder:GetCenter()
    local d = DB()
    d.x = math.floor(fx - cx + 0.5)
    d.y = math.floor(fy - cy + 0.5)
    ApplyPosition()
    ns.Fire("ScreenMoved")
end

local function DragTick()
    local s = dragState
    if not s then return end
    -- 收不到放開（滑鼠出視窗、被別的框吃掉）時自己補救
    if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then EndDrag() return end
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - s.cx, cy / scale - s.cy
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", s.x + dx, s.y + dy)
end

local function BeginDrag()
    if InCombatLockdown() then return end
    local d = DB()
    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    dragState = { cx = cx / scale, cy = cy / scale, x = d.x or 0, y = d.y or 0 }
    if not dragDriver then
        dragDriver = CreateFrame("Frame")
        dragDriver:Hide()
        dragDriver:SetScript("OnUpdate", DragTick)
    end
    dragDriver:Show()
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local function CreateSelection()
    local ok, sel = pcall(CreateFrame, "Frame", nil, holder, "EditModeSystemSelectionTemplate")
    if ok and sel then
        -- ⚠⚠ 模板 XML 綁的 OnMouseDown 會呼叫 EditModeManagerFrame:SelectSystem(self.parent)；
        -- 我們不是真的系統，讓它跑下去會帶著本插件的污染掃過每一個已註冊系統（動作條也在內）
        sel:SetScript("OnMouseDown", function() end)
        sel.system = { GetSystemName = function() return L["MiliUI Boss Timeline"] end }
    else
        sel = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        sel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                          edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        sel:SetBackdropColor(0.25, 0.6, 1, 0.15)
        sel:SetBackdropBorderColor(0.25, 0.6, 1, 0.9)
        sel.ShowHighlighted = sel.Show
    end
    sel:SetAllPoints(holder)
    sel:EnableMouse(true)
    sel:RegisterForDrag("LeftButton")
    sel:SetScript("OnDragStart", BeginDrag)
    sel:SetScript("OnDragStop", EndDrag)
    sel:Hide()
    return sel
end

local function Create()
    if holder then return end
    holder = CreateFrame("Frame", "MiliUIBT_Timeline", UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    holder:SetUserPlaced(false)     -- 位置自己存 SavedVariables，不給版面快取管

    display = ns.Display.New(holder)
    display.frame:SetPoint("CENTER", holder, "CENTER", 0, 0)
    display:SetCollector(Collect)
    display:SetFilter(Filter)

    selection = CreateSelection()

    -- 設定視窗開著時的提示：一行小字，跟在框的上緣
    hint = holder:CreateFontString(nil, "OVERLAY")
    hint:SetFont(ns.Media.Font(), 11, "OUTLINE")
    hint:SetPoint("BOTTOM", holder, "TOP", 0, 6)
    hint:SetTextColor(1, 0.82, 0)
    hint:SetText(L["Preview — drag to move"])
    hint:Hide()

    ApplyPosition()
end

------------------------------------------------------------
-- 套用與狀態
------------------------------------------------------------
local function UpdateState()
    if not holder then return end
    local d = DB()
    local preview = PreviewWanted()
    -- 只在副本裡：野外的時間軸事件（世界首領、別的插件在外面加的條）不畫；預覽不受限
    local allowed = d.visibility ~= "instance" or IsInInstance()
    local run = d.enabled and ((ns.Events.HasAny(Filter) and allowed) or preview)
    display:SetRunning(run and true or false)
    holder:SetShown(run and true or false)
    -- 戰鬥外淡一點（預覽時照常，不然調的時候看不清楚）
    holder:SetAlpha((preview or inCombat) and 1 or (d.oocAlpha or 1))

    -- 選取框：編輯模式用模板的藍框；設定視窗開著時也給一個可抓的區域
    if run and preview then
        selection:ShowHighlighted()
        hint:SetShown(optionsOpen and not inEditMode)
    else
        selection:Hide()
        hint:Hide()
        EndDrag()
    end
end

function Screen.Apply()
    Create()
    local d = DB()
    display:Apply(d, ns.DB.Layout(), d.orientation)
    display.frame:SetScale(d.scale or 1)
    -- holder 的大小＝縮放後的時間軸（選取框照它畫）
    local w, h = display.frame:GetSize()
    local sc = d.scale or 1
    holder:SetSize(w * sc, h * sc)
    ApplyPosition()
    UpdateState()
    ns.BlizzardView.Apply()
end

function Screen.SetOptionsOpen(open)
    optionsOpen = open and true or false
    UpdateState()
end

function Screen.Refresh()
    UpdateState()
end

------------------------------------------------------------
-- 編輯模式：三路訊號，全部冪等（見 wow-editmode-draggable 技能）
------------------------------------------------------------
local function OnEnterEditMode() inEditMode = true;  UpdateState() end
local function OnExitEditMode()  inEditMode = false; UpdateState() end

local editModeHooked = false
local function HookEditMode()
    if editModeHooked or not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", OnEnterEditMode)
    EditModeManagerFrame:HookScript("OnHide", OnExitEditMode)
    if EditModeManagerFrame.EnterEditMode then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", OnEnterEditMode)
    end
    if EditModeManagerFrame.ExitEditMode then
        hooksecurefunc(EditModeManagerFrame, "ExitEditMode", OnExitEditMode)
    end
    if EditModeManagerFrame:IsShown() then OnEnterEditMode() end
end

HookEditMode()
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)
end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", OnEnterEditMode, "MiliUI_BossTimeline")
    EventRegistry:RegisterCallback("EditMode.Exit", OnExitEditMode, "MiliUI_BossTimeline")
end

ns.RegisterCallback("Init", "screen", function()
    HookEditMode()
    Screen.Apply()
end)

-- 進出戰鬥、換區域 → 透明度與「只在副本裡」重算
local stateFrame = CreateFrame("Frame")
stateFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
stateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
stateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
stateFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
    if ns.db then UpdateState() end
end)

-- 時間軸上有沒有東西變了 → 要不要畫
ns.RegisterCallback("TimelineChanged", "screen", function()
    if ns.db then UpdateState() end
end)
