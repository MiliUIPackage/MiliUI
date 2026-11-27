local _, Cell = ...
local F = Cell.funcs

-------------------------------------------------
-- fix from MiliUI: ping marker on unit buttons
-------------------------------------------------
-- 有人 ping 一個隊友時，暴雪會在自己的精簡團隊框那一格畫一顆標記。這裡把它鏡射到 Cell 的按鈕上。
-- 做法照成熟的同類團隊框（2026-11-28 對照過兩家，寫法取不在暴雪框上寫欄位的那一家）。
--
-- 沒有直接管道：
--   * UNIT_PING_PIN_ADDED / _REMOVED 對插件是受限事件 —— RegisterEvent 不會報錯，但一次都收不到
--     （2026-11-28 實機探針：ping 自己、隊友、敵人，只來 CHAT_MSG_PING）。
--   * 唯一的消費者 UnitPingIconFrameTemplate 是 forbidden，插件建不出來。
--   * 聊天那一行（CHAT_MSG_PING）只有組好的文字、沒有 GUID，而且首領戰／傳奇鑰石中是秘密值。
--     試過拿文字對名字，沒有意義，已經拿掉。
--
-- 碰得到的是：暴雪已經建在**它自己**每一格精簡框上的那顆圖示（cuf.pingIconFrame）是普通物件。
-- 暴雪的處理流程會把被 ping 的 GUID 對到那一格、檢查 showPingsOnRaidFrames，再呼叫圖示的
-- ShowPing(kit)／ClearPing()。在這兩個方法後面接 secure post-hook，就拿得到標記種類與那一格的
-- 單位 token，再對到我們的按鈕、畫同一組 atlas。事件是暴雪自己收的，所以不受聊天限制。
--
-- ⚠ 前提：暴雪的精簡框要在背景活著（名冊變動時照樣排版、每一格有正確的單位）。
--   所以這個功能開著時，HideBlizzard.lua 只把團隊管理員面板搬到隱藏的父層、**不解它的事件**，
--   由它繼續帶著容器排版（見那邊 PingMarkerOn 的說明）。關掉這個選項就回到原本整組停掉的做法，
--   暴雪框不在背景跑。開關要重載才生效（停掉是單向的）。
--
-- ⚠ 對暴雪框**只讀不寫**：掛過哪顆圖示、哪顆圖示點亮了哪些按鈕，全記在自己的弱鍵表裡。
--   hook 本體跑在暴雪的執行流程裡，只取值、把工作丟到下一幀。
-------------------------------------------------
local issecretvalue = issecretvalue or function() return false end

-- 一顆 pin 在引擎裡的壽命上限。暴雪自己的圖示在「被 ping 的人換到另一格」時收不到清除
-- （移除那一下對不到原來那一格了），所以鏡射一定要自己有逾時
local PING_EXPIRE = 20
-- 圖示的原生大小是 30；按鈕通常比暴雪團隊框矮，縮一點
local SCALE = 0.8

local hooked = setmetatable({}, {__mode = "k"}) -- 暴雪圖示 -> true（掛了）/ false（永遠不掛）
local lit = setmetatable({}, {__mode = "k"})    -- 暴雪圖示 -> { 我們點亮的按鈕, ... }
local overlays = setmetatable({}, {__mode = "k"}) -- 我們的按鈕 -> 標記框

-- 給 /run 看的診斷（實機確認「暴雪圖示有沒有在被呼叫」用）：
--   /dump Cell.pingStats
Cell.pingStats = {hooked = 0, shown = 0, cleared = 0, lit = 0}

local function Enabled()
    return not (CellDB and CellDB["general"] and CellDB["general"]["pingMarker"] == false)
end

-- 每種標記的框用圖只查一次。技能類的 ping（Available／Unavailable…）沒有框用圖：暴雪自己的
-- SetAtlas 會失敗、圖示停在上一張，所以那種不亮。尺寸一律拿 atlas 資訊，不讀貼圖當下的大小。
local art = {}
local function KitArt(kit)
    local a = art[kit]
    if a == nil then
        local bg, icon = "Ping_Frame_BG_" .. kit, "Ping_Frame_" .. kit
        local bgInfo, iconInfo = C_Texture.GetAtlasInfo(bg), C_Texture.GetAtlasInfo(icon)
        a = bgInfo and iconInfo and {
            bg = bg, bgW = bgInfo.width, bgH = bgInfo.height,
            icon = icon, iconW = iconInfo.width, iconH = iconInfo.height,
        } or false
        art[kit] = a
    end
    return a
end

-- 第一次用到才建（平常零成本）。按鈕的子框：跟著按鈕的顯示、縮放、透明度走
local function Overlay(button)
    local o = overlays[button]
    if o then return o end
    o = CreateFrame("Frame", nil, button)
    o:SetSize(30 * SCALE, 30 * SCALE)
    o:SetPoint("CENTER", button, "CENTER", 0, 0)
    -- 蓋在所有指示物之上：名字、團隊標記等都掛在 indicatorFrame（按鈕 +220，見 UnitButton.lua），
    -- 比它低的話標記會被名字遮住（實際回報）。ping 只亮幾秒，蓋住名字沒關係
    o:SetFrameLevel(button:GetFrameLevel() + 240)
    o:EnableMouse(false)
    o.bg = o:CreateTexture(nil, "BACKGROUND")
    o.bg:SetPoint("CENTER")
    o.icon = o:CreateTexture(nil, "ARTWORK")
    o.icon:SetPoint("CENTER")
    -- 閃爍：alpha 在 1 ↔ 0.35 之間來回，提醒一下就好，不必整顆消失
    o.anim = o:CreateAnimationGroup()
    o.anim:SetLooping("BOUNCE")
    local a = o.anim:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.35)
    a:SetDuration(0.3)
    a:SetSmoothing("IN_OUT")
    o:Hide()
    overlays[button] = o
    return o
end

local function HideOverlay(button)
    local o = button and overlays[button]
    if not o then return end
    o.anim:Stop()
    o:Hide()
end

-- 顯示幾秒：米利的單位框架有載入時照它一般分頁的「閃爍秒數」（兩邊的標記同時收），那時不跟暴雪的清除；
-- 沒有載入就跟著暴雪那顆的壽命（ClearPing），PING_EXPIRE 當保險
local function CustomSeconds()
    local uf = _G.MiliUIUF
    local g = uf and uf.db and uf.db.global
    local secs = g and tonumber(g.pingFlashSeconds)
    if secs and secs >= 1 then return secs end
end

local function Light(button, kitArt)
    local o = Overlay(button)
    o.bg:SetAtlas(kitArt.bg)
    o.bg:SetSize(kitArt.bgW * SCALE, kitArt.bgH * SCALE)
    o.icon:SetAtlas(kitArt.icon)
    o.icon:SetSize(kitArt.iconW * SCALE, kitArt.iconH * SCALE)
    o:SetAlpha(1)
    o:Show()
    o.anim:Stop()
    o.anim:Play()
    o.stamp = (o.stamp or 0) + 1
    local stamp = o.stamp
    C_Timer.After(CustomSeconds() or PING_EXPIRE, function()
        if o.stamp == stamp then HideOverlay(button) end
    end)
    Cell.pingStats.lit = Cell.pingStats.lit + 1
end

local function ClearIcon(icon)
    local list = lit[icon]
    if not list then return end
    lit[icon] = nil
    for i = 1, #list do HideOverlay(list[i]) end
end

-- 下一幀才跑（不在暴雪的執行流程裡動畫面）
local function Apply(icon, unit, kit)
    ClearIcon(icon)     -- 這顆圖示換了一個人：先放掉它之前點亮的
    if not Enabled() then return end
    local kitArt = KitArt(kit)
    if not kitArt then return end
    -- 隊友的 GUID 是明文；讀不到（秘密值）就退回用 token 直接查
    local guid = UnitGUID(unit)
    local normal, spotlights
    if guid and not issecretvalue(guid) then
        normal, spotlights = F.GetUnitButtonByGUID(guid, true)
    end
    if not normal and not spotlights then
        normal, spotlights = F.GetUnitButtonByUnit(unit, true)
    end
    local list = {}
    if normal then
        list[#list + 1] = normal
        Light(normal, kitArt)
    end
    if spotlights then
        for _, b in ipairs(spotlights) do
            list[#list + 1] = b
            Light(b, kitArt)
        end
    end
    if #list > 0 then lit[icon] = list end
end

local function OnShowPing(icon, kit)
    Cell.pingStats.shown = Cell.pingStats.shown + 1
    if issecretvalue(kit) or type(kit) ~= "string" then return end
    local owner = icon:GetParent()
    local unit = owner and owner.unit
    if issecretvalue(unit) or type(unit) ~= "string" then return end
    C_Timer.After(0, function() Apply(icon, unit, kit) end)
end

local function OnClearPing(icon)
    Cell.pingStats.cleared = Cell.pingStats.cleared + 1
    if CustomSeconds() then return end      -- 照設定的秒數顯示，不跟暴雪的清除
    C_Timer.After(0, function() ClearIcon(icon) end)
end

local function HookCuf(cuf)
    local icon = cuf and cuf.pingIconFrame
    if not icon or hooked[icon] ~= nil then return end
    -- 名條的精簡框帶著同一顆子框，不是我們要鏡射的
    local okN, name = pcall(cuf.GetName, cuf)
    if okN and type(name) == "string" and name:find("^NamePlate") then
        hooked[icon] = false
        return
    end
    local okF, forbidden = pcall(icon.IsForbidden, icon)
    if not okF or forbidden then
        hooked[icon] = false
        return
    end
    hooked[icon] = true
    hooksecurefunc(icon, "ShowPing", OnShowPing)
    hooksecurefunc(icon, "ClearPing", OnClearPing)
    Cell.pingStats.hooked = Cell.pingStats.hooked + 1
end

-- 每顆圖示只掛一次：之後建出來的由 SetUpFrame 的 post-hook 接，已經存在的登入時掃一遍
if type(CompactUnitFrame_SetUpFrame) == "function" then
    hooksecurefunc("CompactUnitFrame_SetUpFrame", HookCuf)
end

local sweeper = CreateFrame("Frame")
sweeper:RegisterEvent("PLAYER_ENTERING_WORLD")
sweeper:RegisterEvent("GROUP_ROSTER_UPDATE")
sweeper:SetScript("OnEvent", function()
    for i = 1, 40 do HookCuf(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do
        for i = 1, 5 do HookCuf(_G["CompactRaidGroup" .. g .. "Member" .. i]) end
    end
    for i = 1, 5 do HookCuf(_G["CompactPartyFrameMember" .. i]) end
end)
