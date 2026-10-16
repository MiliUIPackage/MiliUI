------------------------------------------------------------
-- 坐騎特效按鈕（獨立 HUD，面板 mountspecial，容器 MiliUICDM_Bar_mountspecial；2026-10-16）
--
-- 一顆普通按鈕（不是 secure 模板），按下去呼叫 C_ChatInfo.PerformEmote("MOUNTSPECIAL")：坐騎的特效動作。
--   * PerformEmote 是 12.0 取代 DoEmote 的 API（wiki 沒標保護、只標 HasRestrictions）；舊客戶端退回 DoEmote。
--     token 是英文，每個語系都通。坐騎特效不是施法，不需要 secure ⇒ 自己做滑過／按下／閃光，戰鬥中 Show／Hide 也不受限、
--     容器不會變成隱式保護框。
--   * 受限（M+ 那類聊天封鎖）時回 false／拋錯：不報、不處理（天空騎術本來就進不了那些地方）。
--
-- 顯示（MS.Shown，純函式；Visibility 的 EvaluatePanel 讀上次判斷的 MS.Visible）：
--   開著、騎著坐騎（IsMounted 明文 true）、不在載具、不在空中滑翔（GetGlidingInfo 的 isGliding 明文 false；
--   秘密／讀不到 ⇒ 當在空中，不顯示——天空騎術在空中按了沒用）。一般飛行坐騎在空中照樣顯示（懸停時特效播得出來）。
--   天空騎術的「藏起冷卻管理器」不藏它（Core/Visibility.lua 的 PanelAlpha 豁免）。編輯模式一律亮（面板的通則）。
--
-- 位置：走既有的面板機制（Bars.RegisterPanel ⇒ 編輯模式拖曳／磁吸／錨定候選／設定頁的錨定小節都自動有），
--   預設錨在核心技能下方正中央（排開的最外圈：STACK_RANK 950，所以在核心技能那一疊的最下面）。
--   followSky（預設開）：天空騎術條顯示中時改貼在天空騎術條正下方（skyX／skyY），不看自己的錨定／pos
--  （Core/Bars.lua 的 PlaceContainer；天空騎術條的結構重套時跟著重貼）。天空騎術條顯示狀態一變（SkyridingShownChanged）就重套結構。
--
-- 效果（HUD 皮的三態：只換明暗）：閒置字 0.75、滑過字 1.0＋亮一層、按下字 0.6＋暗一層＋字下沉 1 實體像素。
--   按下去閃一下（像快捷列按鍵那種）：一層比鈕大兩個實體像素的白色 ADD 貼圖從 0 衝到 0.9 再淡掉（AnimationGroup，引擎跑）。
--   編輯模式中不收滑鼠（不然蓋在覆蓋層上、拖曳變按鈕）。
--   外觀照套組 HUD 皮：0x1A 灰底 alpha 0.8、1 實體像素職業色邊（ns.Resources.Edges，P.Pixel）、白字描邊、直角。
--
-- 存檔：profile.mountspecial（Core/DB.lua 的 MountSpecialDefaults）。10-16 當天上午的版本把它放在 profile.skyriding.mountButton，
--   MS.Upgrade 看到就搬過來再清掉（冪等；那版只有開發者存檔有，不走 DB 遷移鏈）。
-- 自己的框，不碰任何暴雪框。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.MountSpecial = {}
local MS = ns.MountSpecial

local KEY = "mountspecial"
MS.KEY = KEY

local MOUNT_EMOTE = "MOUNTSPECIAL"
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local HUD_BG = 0x1A / 255
local A_IDLE, A_HOVER, A_PRESS = 0.75, 1, 0.6
local FLASH_IN, FLASH_OUT, FLASH_PEAK = 0.06, 0.30, 0.9
local FLASH_BLEED = 2          -- 閃光比鈕大幾個實體像素（溢出邊框，像快捷列按鍵的那層光）

local container, btn, ui
local visible = false          -- 上次 Refresh 判的「該顯示」（Visibility 的快照讀這支，不重讀 API）
local skyShown = false         -- 上次看到的天空騎術條顯示狀態（跟著它重貼）

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
MS.Cfg = Cfg

local function Clamp(v, lo, hi, d)
    v = tonumber(v) or d
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

------------------------------------------------------------
-- 純函式（Tests/MountSpecial_test.lua）
------------------------------------------------------------
-- 尺寸與字級：box.w 40～400（預設 100）、box.h 12～60（20）、fontSize 6～40（12）
function MS.Dims(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local box = type(cfg.box) == "table" and cfg.box or {}
    return Clamp(box.w, 40, 400, 100), Clamp(box.h, 12, 60, 20), Clamp(cfg.fontSize, 6, 40, 12)
end

-- 跟著天空騎術條：沒存 ＝ 開
function MS.FollowSky(cfg)
    return type(cfg) == "table" and cfg.followSky ~= false
end

-- 貼在天空騎術條下方時的位移 sky.x／sky.y（鈕的 TOP 對條的 BOTTOM）：±400／±300，預設 (0, -6)
function MS.SkyOffsetOf(cfg)
    cfg = type(cfg) == "table" and cfg or {}
    local sky = type(cfg.sky) == "table" and cfg.sky or {}
    return Clamp(sky.x, -400, 400, 0), Clamp(sky.y, -300, 300, -6)
end

-- st：{ mounted, vehicle, gliding }（gliding ＝ 明文 true／false，秘密或讀不到 ＝ nil）
function MS.Shown(cfg, st)
    if type(cfg) ~= "table" or cfg.enabled == false then return false end
    if type(st) ~= "table" then return false end
    if st.mounted ~= true or st.vehicle then return false end
    return st.gliding == false
end

-- 10-16 上午版本的欄位搬家：profile.skyriding.mountButton → profile.mountspecial（冪等；搬完清掉舊表）。
-- 回傳有沒有搬
function MS.Upgrade(cfg, sky)
    local old = type(sky) == "table" and type(sky.mountButton) == "table" and sky.mountButton or nil
    if not old or type(cfg) ~= "table" then return false end
    if old.enabled ~= nil then cfg.enabled = old.enabled ~= false end
    if type(cfg.box) ~= "table" then cfg.box = {} end
    if type(cfg.sky) ~= "table" then cfg.sky = {} end
    if tonumber(old.width) then cfg.box.w = tonumber(old.width) end
    if tonumber(old.height) then cfg.box.h = tonumber(old.height) end
    if tonumber(old.size) then cfg.fontSize = tonumber(old.size) end
    if tonumber(old.x) then cfg.sky.x = tonumber(old.x) end
    if tonumber(old.y) then cfg.sky.y = tonumber(old.y) end
    sky.mountButton = nil
    return true
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
local function PlainTrue(fn, ...)
    if not fn then return false end
    local ok, v = pcall(fn, ...)
    if not ok or ns.IsSecret(v) then return false end
    return v == true
end

local function ReadState()
    local st = {}
    st.mounted = PlainTrue(IsMounted)
    st.vehicle = PlainTrue(UnitInVehicle, "player") or PlainTrue(UnitHasVehicleUI, "player")
    local P = C_PlayerInfo
    local fn = P and P.GetGlidingInfo
    if fn then
        local ok, g = pcall(fn)
        if ok then
            g = Plain(g)
            -- 不寫 `cond and g or nil`：g 是 false 時會被 or 吃成 nil（.claude/notes 的 wow-lua-and-or-pitfalls）
            if g == true or g == false then st.gliding = g end
        end
    else
        st.gliding = false            -- 沒有天空騎術的客戶端：沒有「空中滑翔」這回事
    end
    return st
end
MS.ReadState = ReadState

-- 上次判斷的結果（Visibility 的快照、Bars 的跟隨判斷讀這兩支，不重讀 API）
function MS.Visible() return visible end

-- 正在跟著天空騎術條（Bars 的 PlaceContainer 問）：開著跟隨、天空騎術條顯示中、沒被舊插件擋
function MS.FollowingSky()
    local cfg = Cfg()
    if not (cfg and cfg.enabled ~= false and MS.FollowSky(cfg)) then return false end
    if ns.falconBlocked then return false end
    local SR = ns.Skyriding
    return (SR and SR.Shown and SR.Shown()) and true or false
end

function MS.SkyOffset()
    return MS.SkyOffsetOf(Cfg())
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function AccentColor()
    local r, g, b = ns.Style.Accent()
    return { r = r, g = g, b = b, a = 1 }
end

local function PaintBorder()
    if ui then ns.Resources.PaintEdges(ui.edges, 1, AccentColor()) end
end

-- 三態：hover／pressed 來自滑鼠腳本
local function PaintState(hover, pressed)
    if not ui then return end
    ui.text:SetAlpha(pressed and A_PRESS or hover and A_HOVER or A_IDLE)
    ui.hl:SetAlpha(hover and not pressed and 0.10 or 0)
    ui.dark:SetAlpha(pressed and 0.30 or 0)
    ui.text:SetPoint("CENTER", ui.top, "CENTER", 0, pressed and -ns.P.Pixel(1) or 0)
end

local function Flash()
    if not ui then return end
    if ui.flashAnim:IsPlaying() then ui.flashAnim:Stop() end
    ui.flashAnim:Play()
end

local function OnClick()
    local fn = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
    if fn then pcall(fn, MOUNT_EMOTE) end
    Flash()
end

local function Build()
    btn = CreateFrame("Button", nil, container)
    btn:SetAllPoints(container)
    btn:RegisterForClicks("LeftButtonUp")
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    bg:SetTexture(SOLID)
    bg:SetVertexColor(HUD_BG, HUD_BG, HUD_BG, 0.8)
    local hl = btn:CreateTexture(nil, "ARTWORK")          -- 滑過：亮一層（ADD）
    hl:SetAllPoints(btn)
    hl:SetTexture(SOLID)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0)
    local dark = btn:CreateTexture(nil, "ARTWORK", nil, 1) -- 按下：暗一層
    dark:SetAllPoints(btn)
    dark:SetTexture(SOLID)
    dark:SetVertexColor(0, 0, 0, 1)
    dark:SetAlpha(0)
    -- 閃光：比鈕大一圈（Layout 定，兩個實體像素）的白色 ADD 貼圖，按下去衝亮再淡掉（AnimationGroup，引擎跑）
    local flash = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    flash:SetTexture(SOLID)
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    local ag = flash:CreateAnimationGroup()
    local up = ag:CreateAnimation("Alpha")
    up:SetFromAlpha(0)
    up:SetToAlpha(FLASH_PEAK)
    up:SetDuration(FLASH_IN)
    up:SetOrder(1)
    local down = ag:CreateAnimation("Alpha")
    down:SetFromAlpha(FLASH_PEAK)
    down:SetToAlpha(0)
    down:SetDuration(FLASH_OUT)
    down:SetSmoothing("OUT")
    down:SetOrder(2)
    -- 文字與邊框：最上層的子框，不吃滑鼠（不然會搶走按鈕的 OnEnter／OnLeave）
    local top = CreateFrame("Frame", nil, btn)
    top:SetAllPoints(btn)
    top:SetFrameLevel(btn:GetFrameLevel() + 3)
    top:EnableMouse(false)
    local text = top:CreateFontString(nil, "OVERLAY")
    ns.Media.SetPixelFont(text, 12, "OUTLINE")       -- 先有字型才能 SetText
    text:SetPoint("CENTER", top, "CENTER", 0, 0)
    text:SetText(L["Mount Special"])
    text:SetAlpha(A_IDLE)
    ui = { bg = bg, hl = hl, dark = dark, flash = flash, flashAnim = ag, top = top, text = text,
           edges = ns.Resources.Edges(top, 1, AccentColor()) }
    btn:SetScript("OnEnter", function() PaintState(true, false) end)
    btn:SetScript("OnLeave", function() PaintState(false, false) end)
    btn:SetScript("OnMouseDown", function() PaintState(true, true) end)
    btn:SetScript("OnMouseUp", function(self) PaintState(self:IsMouseOver(), false) end)
    btn:SetScript("OnClick", OnClick)
end

------------------------------------------------------------
-- 版面（全部來自設定，不讀框的幾何）
------------------------------------------------------------
local function MinSize()
    local w, h = MS.Dims(Cfg())
    return ns.P.Scale(w), ns.P.Scale(h)
end

function MS.Layout()
    if not btn then return end
    local w, h, size = MS.Dims(Cfg())
    ns.Bars.SetPanelSize(KEY, ns.P.Scale(w), ns.P.Scale(h))
    ns.Media.SetPixelFont(ui.text, size, "OUTLINE")
    local bleed = ns.P.Pixel(FLASH_BLEED)
    ui.flash:ClearAllPoints()
    ui.flash:SetPoint("TOPLEFT", btn, "TOPLEFT", -bleed, bleed)
    ui.flash:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", bleed, -bleed)
    PaintBorder()
end

------------------------------------------------------------
-- 狀態變了：重判顯示、跟著天空騎術條重貼
------------------------------------------------------------
local dirty = false
function MS.Refresh()
    dirty = false
    if not btn then return end
    local cfg = Cfg() or {}
    local was = visible
    visible = MS.Shown(cfg, ReadState())
    if was ~= visible and ns.Visibility then ns.Visibility.Later() end
    -- 編輯模式中不收滑鼠：不然它蓋在覆蓋層上面，拖曳變成按鈕（同點擊層在編輯模式收起來）
    local editing = ns.EditMode and ns.EditMode.active and true or false
    btn:EnableMouse(not editing)
    if editing then PaintState(false, false) end
    local sky = MS.FollowingSky()
    if sky ~= skyShown then
        skyShown = sky
        ns.Bars.ApplyPanelStructure(KEY)
    end
end

local function Mark()
    if dirty then return end
    dirty = true
    ns.Defer(MS.Refresh)
end
MS.Mark = Mark

-- 設定頁改了值：版面、結構（位置、strata、開關）、alpha
function MS.Apply()
    if not container then return end
    MS.Layout()
    ns.Bars.ApplyPanelStructure(KEY)
    MS.Refresh()
    if ns.Visibility then ns.Visibility.Later() end
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Skyriding 之後）
------------------------------------------------------------
function MS.Init()
    if container then return end
    -- 上午版本的欄位搬家（見檔頭）
    local p = ns.profile
    if p then MS.Upgrade(Cfg(), p.skyriding) end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "TOP",
        minSize     = MinSize,
        relayout    = function() MS.Layout() end,
    })
    Build()
    MS.Layout()
    local E = ns.Events
    E.Register("PLAYER_MOUNT_DISPLAY_CHANGED", "mountspecial", Mark)
    E.Register("PLAYER_ENTERING_WORLD", "mountspecial", Mark)
    E.Register("UNIT_ENTERED_VEHICLE", "mountspecial", Mark, "player")
    E.Register("UNIT_EXITED_VEHICLE", "mountspecial", Mark, "player")
    -- 客戶端不認得的事件不註冊（同 Visibility／Skyriding）
    local Vis = ns.Visibility
    for _, ev in ipairs({ "PLAYER_CAN_GLIDE_CHANGED", "PLAYER_IS_GLIDING_CHANGED" }) do
        if not Vis or Vis.EventExists(ev) then E.Register(ev, "mountspecial", Mark) end
    end
    ns.RegisterCallback("SkyridingShownChanged", "mountspecial", Mark)
    ns.RegisterCallback("EditModeChanged", "mountspecial", Mark)
    ns.RegisterCallback("AccentChanged", "mountspecial", PaintBorder)
    ns.RegisterCallback("ProfileChanged", "mountspecial", function()
        local pr = ns.profile
        if pr then MS.Upgrade(Cfg(), pr.skyriding) end
        MS.Apply()
    end)
    Mark()
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
-- 滑鼠現在停在哪個框上（滑過效果不對時第一個要看的東西：有別的框蓋在按鈕上就是它搶走了 OnEnter）
local function MouseFocusName()
    local ok, foci = pcall(GetMouseFoci)
    local f = ok and type(foci) == "table" and foci[1] or nil
    if not f then return "無" end
    local okn, name = pcall(f.GetName, f)
    name = okn and not ns.IsSecret(name) and name or nil
    if name then return name end
    local okp, parent = pcall(f.GetParent, f)
    local okpn, pname = false, nil
    if okp and parent then okpn, pname = pcall(parent.GetName, parent) end
    return "（匿名框" .. ((okpn and type(pname) == "string") and ("，父框 " .. pname) or "") .. "）"
end

function MS.DebugLine()
    if not btn then return "  坐騎特效鈕：沒有初始化" end
    local cfg = Cfg() or {}
    local st = ReadState()
    return ("  坐騎特效鈕：%s  顯示 %s  騎乘 %s  載具 %s  滑翔 %s  跟著天空騎術條 %s（現在 %s）  收滑鼠 %s  滑鼠在 %s  alpha %s")
        :format(cfg.enabled ~= false and "開" or "關", tostring(visible), tostring(st.mounted), tostring(st.vehicle),
                tostring(st.gliding), tostring(MS.FollowSky(cfg)), skyShown and "是" or "否",
                btn:IsMouseEnabled() and "是" or "否", MouseFocusName(),
                tostring(ns.Visibility and ns.Visibility.Current(KEY)))
end
