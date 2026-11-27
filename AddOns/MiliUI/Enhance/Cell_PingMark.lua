------------------------------------------------------------
-- MiliUI: Cell 的 Ping 標記
-- 有人 ping 某個單位時，在 Cell 對應的那一格上閃幾秒 ping 圖示（秒數跟單位框架的設定，預設 3）。不改 Cell 原始碼。
--
-- 跟 MiliUI_UnitFrames/Core/PingMark.lua 是同一套做法（那邊有完整的來龍去脈），兩邊各自獨立：
--   * 來源只有 CHAT_MSG_PING 的聊天文字（暴雪單位框用的 UNIT_PING_PIN_ADDED 插件收不到，
--     2026-11-28 實機探針）。文字＝`|A:ping_chat_<種類>:…|a` ＋「名字」或「前綴：名字」，
--     沒有 GUID，只能拿內文對名字。
--   * 聊天受限的時段（首領戰、傳奇鑰石）文字是秘密值 ⇒ 不顯示。
--   * 圖示框掛在 UIParent 底下、**錨到** Cell 的單位按鈕上（按鈕是 protected，戰鬥中不能替它
--     生子框；錨在 protected 框上不會讓自己變成 protected），用完回池。
--
-- 開關與秒數：跟著單位框架一般分頁的「被 ping 時在框上閃 ping 圖示」「閃爍秒數」；
-- 單位框架沒載入就一律開、3 秒。
------------------------------------------------------------
local DEFAULT_SECONDS = 3
local ICON_SIZE = 22

local isSecret = issecretvalue or function() return false end

local function IsSeparatorTail(s)
    if s == "" then return false end
    local last = s:sub(-1)
    if last == ":" or last == " " then return true end
    return s:sub(-3) == "\239\188\154"      -- 全形冒號
end

local function Parse(text)
    if type(text) ~= "string" then return nil end
    local atlas = text:match("|A:(ping_chat_[%w_]+):")
    if not atlas then return nil end
    local body = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    body = body:gsub("^%s+", ""):gsub("%s+$", "")
    if body == "" then return nil end
    return atlas, body
end

local function Matches(body, name)
    if type(name) ~= "string" or name == "" then return false end
    if body == name then return true end
    local n = #name
    if #body <= n then return false end
    if body:sub(-n) == name and IsSeparatorTail((body:sub(1, #body - n):gsub("%s+$", " "))) then return true end
    if body:sub(1, n) == name then
        local rest = body:sub(n + 1)
        local c = rest:sub(1, 1)
        if c == ":" or c == " " or rest:sub(1, 3) == "\239\188\154" then return true end
    end
    return false
end

local pool, active = {}, {}

local function Acquire()
    local m = table.remove(pool)
    if m then return m end
    m = CreateFrame("Frame", nil, UIParent)
    m:SetSize(ICON_SIZE, ICON_SIZE)
    m:SetFrameStrata("HIGH")
    m:EnableMouse(false)
    m.tex = m:CreateTexture(nil, "OVERLAY")
    m.tex:SetAllPoints()
    m.anim = m:CreateAnimationGroup()
    m.anim:SetLooping("BOUNCE")
    local a = m.anim:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0.25)
    a:SetDuration(0.25)
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

local function Flash(host, atlas)
    local m = active[host]
    if not m then
        m = Acquire()
        active[host] = m
        m:ClearAllPoints()
        m:SetPoint("CENTER", host, "CENTER", 0, 0)
    end
    m.tex:SetAtlas(atlas)
    m:SetAlpha(1)
    m:Show()
    m.anim:Stop()
    m.anim:Play()
    m.token = (m.token or 0) + 1
    local token = m.token
    local uf = _G.MiliUIUF
    local g = uf and uf.db and uf.db.global
    local secs = tonumber(g and g.pingFlashSeconds) or DEFAULT_SECONDS
    if secs < 1 then secs = 1 end
    C_Timer.After(secs, function()
        if active[host] == m and m.token == token then Release(host) end
    end)
end

local function Enabled()
    local uf = _G.MiliUIUF
    local g = uf and uf.db and uf.db.global
    if g and g.pingFlash == false then return false end
    return true
end

local function OnPing(text)
    local Cell = _G.Cell
    local F = Cell and Cell.funcs
    if not (F and F.IterateAllUnitButtons) or not Enabled() then return end
    if isSecret(text) then return end
    local atlas, body = Parse(text)
    if not atlas then return end
    -- 只走目前這種隊伍型態的按鈕（第二個參數）；每顆各自隔離，一顆出錯不影響其他
    F.IterateAllUnitButtons(function(b)
        pcall(function()
            local unit = b.states and b.states.unit
            if not unit or not b:IsVisible() then return end
            local name = UnitName(unit)
            if not isSecret(name) and Matches(body, name) then Flash(b, atlas) end
        end)
    end, true)
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_PING")
-- 延到下一幀：聊天事件可能在暴雪的執行流程裡同步派送，不在裡面動畫面
f:SetScript("OnEvent", function(_, _, text) C_Timer.After(0, function() OnPing(text) end) end)
