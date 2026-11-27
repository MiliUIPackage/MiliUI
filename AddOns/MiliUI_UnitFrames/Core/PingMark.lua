------------------------------------------------------------
-- Ping 標記：隊友被 ping 時，在他的框上閃 ping 標記
--
-- 做法＝鏡射暴雪自己團隊框上的那顆標記（2026-11-28 對照兩家成熟的團隊框，寫法取不在暴雪框上
-- 寫欄位的那一家；Cell 那一份在 Cell/RaidFrames/PingMarker.lua，兩邊各自獨立）：
--
-- 沒有直接管道：
--   * UNIT_PING_PIN_ADDED / _REMOVED 對插件是受限事件 —— RegisterEvent 不報錯，但一次都收不到
--     （實機探針：ping 自己、隊友、敵人，只來 CHAT_MSG_PING）。
--   * 唯一的消費者 UnitPingIconFrameTemplate 是 forbidden，插件建不出來。
--   * CHAT_MSG_PING 只有組好的文字、沒有 GUID，首領戰／傳奇鑰石中還是秘密值。第一版拿文字對名字，
--     使用者定案沒有意義，已經整個拿掉。
--
-- 碰得到的是暴雪已經建在**它自己**每一格精簡框上的圖示（cuf.pingIconFrame，普通物件）。暴雪的
-- 處理流程把被 ping 的 GUID 對到那一格、檢查 showPingsOnRaidFrames，再呼叫圖示的
-- ShowPing(kit)／ClearPing()。在這兩個方法後面接 secure post-hook，拿到標記種類與那一格的單位，
-- 再畫到我們自己「正在顯示同一個人」的框上（隊伍框；那個人剛好是目標／專注目標時那兩個框也亮）。
-- 事件是暴雪自己收的，所以不受聊天限制。
--
-- ⚠ 前提：暴雪的精簡框要在背景活著、每一格綁著正確的單位。
--   * 團隊：那是暴雪團隊框的事。有別的團隊框插件把它整組停掉的話，這裡就收不到（Cell 開著
--     自己的 ping 標記時會讓它在背景繼續跑）。
--   * 五人隊伍：只有開了「團隊風格隊伍框」才有精簡框（CompactPartyFrame）。我們藏暴雪隊伍框時
--     在這個功能開著的情況下不解它的事件（Core/HideBlizzard.lua），讓它繼續更新成員。
--   關掉這個選項就回到原本的做法，暴雪框不在背景跑；要重載才生效（解事件是單向的）。
--
-- ⚠ 對暴雪框**只讀不寫**（notes：wow-121-addon-code-in-secure-stack）：掛過哪顆、哪顆點亮了誰，
--   全記在自己的弱鍵表。hook 本體跑在暴雪的執行流程裡，只取值、把工作丟到下一幀。
--
-- 圖示框掛在 UIParent 底下、**錨到**單位框上（不是單位框的子物件）：單位框是 protected，而
-- 錨在 protected 框上不會讓自己變成 protected，戰鬥中照樣能擺、能顯示。用池重用（frame 刪不掉）。
------------------------------------------------------------
local _, ns = ...

local PM = {}
ns.PingMark = PM

local DEFAULT_SECONDS = 3
local SCALE = 0.9                   -- 圖示原生 30

local hooked = setmetatable({}, { __mode = "k" })   -- 暴雪圖示 -> true（掛了）/ false（永遠不掛）
local litBy  = setmetatable({}, { __mode = "k" })   -- 暴雪圖示 -> { 我們點亮的單位框, ... }

-- /muf debug 之外的快速診斷：/dump MiliUIUF.PingMark.stats
PM.stats = { hooked = 0, shown = 0, cleared = 0, lit = 0 }

local function Enabled()
    return ns.db and ns.db.global and ns.db.global.pingFlash ~= false
end

-- 每種標記的框用圖只查一次。技能類的 ping 沒有框用圖（暴雪自己的 SetAtlas 也會失敗），那種不亮
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

------------------------------------------------------------
-- 圖示池
------------------------------------------------------------
local pool, active = {}, {}     -- active[單位框] = 標記框

local function Acquire()
    local m = table.remove(pool)
    if m then return m end
    m = CreateFrame("Frame", nil, UIParent)
    m:SetSize(30 * SCALE, 30 * SCALE)
    m:SetFrameStrata("HIGH")
    m:EnableMouse(false)
    m.bg = m:CreateTexture(nil, "BACKGROUND")
    m.bg:SetPoint("CENTER")
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetPoint("CENTER")
    -- 閃爍：alpha 在 1 ↔ 0.35 之間來回
    m.anim = m:CreateAnimationGroup()
    m.anim:SetLooping("BOUNCE")
    local a = m.anim:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.35)
    a:SetDuration(0.3)
    a:SetSmoothing("IN_OUT")
    return m
end

local function Release(host)
    local m = active[host]
    if not m then return end
    active[host] = nil
    m.anim:Stop()
    m:Hide()
    m:ClearAllPoints()
    pool[#pool + 1] = m
end

-- 顯示多久：**只看玩家設的秒數**（預設 3，使用者指定要能自己調）。暴雪清掉自己那顆的時間不管
-- （見 OnClearPing）——跟著它收的話，設得比暴雪的標記壽命長就沒有作用，選項等於假的。
local function Light(host, kitArt)
    local m = active[host]
    if not m then
        m = Acquire()
        active[host] = m
        m:ClearAllPoints()
        m:SetPoint("CENTER", host, "CENTER", 0, 0)
    end
    m.bg:SetAtlas(kitArt.bg)
    m.bg:SetSize(kitArt.bgW * SCALE, kitArt.bgH * SCALE)
    m.icon:SetAtlas(kitArt.icon)
    m.icon:SetSize(kitArt.iconW * SCALE, kitArt.iconH * SCALE)
    m:SetAlpha(1)
    m:Show()
    m.anim:Stop()
    m.anim:Play()
    m.token = (m.token or 0) + 1
    local token = m.token
    local secs = tonumber(ns.db.global.pingFlashSeconds) or DEFAULT_SECONDS
    if secs < 1 then secs = 1 end
    C_Timer.After(secs, function()
        if active[host] == m and m.token == token then Release(host) end
    end)
    PM.stats.lit = PM.stats.lit + 1
end

local function ClearIcon(icon)
    local list = litBy[icon]
    if not list then return end
    litBy[icon] = nil
    for i = 1, #list do Release(list[i]) end
end

-- 下一幀才跑（不在暴雪的執行流程裡動畫面）
local function Apply(icon, unit, kit)
    ClearIcon(icon)     -- 這顆圖示換了一個人：先放掉它之前點亮的
    if not Enabled() then return end
    local kitArt = KitArt(kit)
    if not kitArt then return end
    -- 隊友的 GUID 是明文；讀不到就對不了，放棄這一次（不猜）
    local guid = UnitGUID(unit)
    if not guid or ns.IsSecret(guid) then return end
    local list = {}
    for _, uf in pairs(ns.frames) do
        if uf:IsVisible() then
            local g = UnitGUID(uf.unit)
            if g and not ns.IsSecret(g) and g == guid then
                list[#list + 1] = uf
                Light(uf, kitArt)
            end
        end
    end
    if #list > 0 then litBy[icon] = list end
end

local function OnShowPing(icon, kit)
    PM.stats.shown = PM.stats.shown + 1
    if ns.IsSecret(kit) or type(kit) ~= "string" then return end
    local owner = icon:GetParent()
    local unit = owner and owner.unit
    if ns.IsSecret(unit) or type(unit) ~= "string" then return end
    C_Timer.After(0, function() Apply(icon, unit, kit) end)
end

-- 暴雪清掉它自己那顆：只記帳，**不跟著收**。我們的標記照玩家設的秒數顯示（Light 裡的計時器）；
-- 那顆圖示之後點亮別人時，Apply 開頭的 ClearIcon 會把舊的放掉。
local function OnClearPing(icon)
    PM.stats.cleared = PM.stats.cleared + 1
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
    PM.stats.hooked = PM.stats.hooked + 1
end

-- 每顆圖示只掛一次：之後建出來的由 SetUpFrame 的 post-hook 接，已經存在的在登入／名冊變動時掃一遍
if type(CompactUnitFrame_SetUpFrame) == "function" then
    hooksecurefunc("CompactUnitFrame_SetUpFrame", HookCuf)
end

local function Sweep()
    for i = 1, 40 do HookCuf(_G["CompactRaidFrame" .. i]) end
    for g = 1, 8 do
        for i = 1, 5 do HookCuf(_G["CompactRaidGroup" .. g .. "Member" .. i]) end
    end
    for i = 1, 5 do HookCuf(_G["CompactPartyFrameMember" .. i]) end
end
ns.Events.Register("PLAYER_ENTERING_WORLD", "pingmark_sweep", Sweep)
ns.Events.Register("GROUP_ROSTER_UPDATE", "pingmark_sweep", Sweep)
