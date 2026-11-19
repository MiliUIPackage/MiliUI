------------------------------------------------------------
-- 畫面上的那一條時間軸
--
-- 什麼時候畫：
--   * 時間軸上有東西（首領戰中）                       → 畫真的
--   * 設定視窗開著（且勾了「畫面上同步預覽」）、或在編輯模式 → 時間軸是空的就畫假資料
-- 預覽狀態下框可以直接拖（設定視窗開著時）或在編輯模式裡拖；兩邊存同一個位置。
--
-- 拖曳走共用層（Libs/MiliUIEditMode.lua）：選取框、三重進出訊號、手動拖曳、格線吸附、戰鬥閘都在那裡。
-- 設定視窗開著也能拖＝mover:SetForced。
--
-- 縮放：外層 holder 不縮放、只管位置；Display 的框掛在 holder 中央再 SetScale。
-- 位置偏移要是在被縮放的框上設，拖曳與存檔的單位會跟著縮放走（.claude/notes/wow-setscale-offset-units.md）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Screen = {}
local Screen = ns.Screen

local EM = ns.MiliUIEditMode

local holder, display, mover, hint
local optionsOpen = false
local inCombat = false      -- 自己記：PLAYER_REGEN_DISABLED 派送當下 InCombatLockdown() 還是 false

local function DB() return ns.db.display end

local function PreviewWanted()
    return EM.IsActive() or (optionsOpen and ns.db.previewOnScreen)
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

-- 時間軸要不要跑。只在副本裡：野外的時間軸事件（世界首領、別的插件在外面加的條）不畫；預覽不受限
local function Running(preview)
    local d = DB()
    local allowed = d.visibility ~= "instance" or IsInInstance()
    return (d.enabled and ((ns.Events.HasAny(Filter) and allowed) or preview)) and true or false
end

------------------------------------------------------------
-- 位置與拖曳
------------------------------------------------------------
local function ApplyPosition()
    local d = DB()
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", d.x or 0, d.y or 0)
end

-- 放手：照框的現況存 CENTER 偏移（四捨五入），再照存檔重貼
local function SavePosition()
    local d = DB()
    local x, y = EM.CenterOffset(holder)
    if x then d.x, d.y = x, y end
    ApplyPosition()
    ns.Fire("ScreenMoved")
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
local UpdateState   -- 下面定義（選取框的 onChange 要叫它）

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

    mover = EM.Attach(holder, {
        name     = L["MiliUI Boss Timeline"],
        save     = SavePosition,
        restore  = ApplyPosition,
        -- 時間軸在跑才亮選取框（「在編輯模式或設定視窗開著」由 Editing() 那一半管）
        enabled  = function() return Running(PreviewWanted()) end,
        onChange = function() if ns.db then UpdateState() end end,
    })

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
function UpdateState()
    if not holder then return end
    local d = DB()
    local preview = PreviewWanted()
    local run = Running(preview)
    display:SetRunning(run)
    holder:SetShown(run)
    -- 戰鬥外淡一點（預覽時照常，不然調的時候看不清楚）
    holder:SetAlpha((preview or inCombat) and 1 or (d.oocAlpha or 1))

    -- 選取框：編輯模式用模板的藍框；設定視窗開著（且勾了同步預覽）時也給一個可抓的區域
    mover:SetForced(optionsOpen and ns.db.previewOnScreen)
    mover:Refresh()
    if run and preview then
        hint:SetShown(optionsOpen and not EM.IsActive())
    else
        hint:Hide()
        mover:EndDrag(true)
    end
end

function Screen.Apply()
    Create()
    local d = DB()
    -- 縮放先寫：Apply 裡的 1px 邊照框自己的有效縮放換算
    display.frame:SetScale(d.scale or 1)
    display:Apply(d, ns.DB.Layout(), d.orientation)
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

ns.RegisterCallback("Init", "screen", function()
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
