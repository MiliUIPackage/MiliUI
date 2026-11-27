------------------------------------------------------------
-- Ping 標記：有人 ping 某個單位時，在那個單位的框上閃三秒 ping 圖示
--
-- 來源只有 CHAT_MSG_PING 那一行聊天文字（2026-11-28 實機探針）：
--   * 暴雪自己的單位框是聽 UNIT_PING_PIN_ADDED(guid, 標記種類) 畫標記的，那個事件插件
--     **註冊得起來、但一次都收不到**（ping 自己、隊友、敵人都試過，只來 CHAT_MSG_PING）。
--   * CHAT_MSG_PING 的文字是組好的一句話：`|A:ping_chat_<種類>:0:0:0:0|a` ＋ 內文，內文是
--     「名字」或「前綴：名字」（警告：某某、威脅警報：某某；前綴是在地化字串）。沒有 GUID，
--     arg12 是 nil；送出者那一欄也帶著聊天頻道的裝飾，不能拿來用。
--   所以只能拿內文去對名字：整句等於名字，或前綴＋分隔＋名字結尾。
--
-- 限制（都是來源決定的，不是沒做完）：
--   * 首領戰／傳奇鑰石這些聊天受限的時段，文字是秘密值 ⇒ 對不了名字，那時不會顯示。
--   * ping 地面（「注意這裡」）沒有單位，不顯示。
--   * 同名的兩個單位會一起亮（同一批小怪）。
--   * 單位名字讀不到（身分受限的敵人，UnitName 回秘密值）的框不會亮。
--
-- 畫法：圖示用聊天裡那張 atlas（ping_chat_<種類>，聊天畫得出來就一定存在）。
-- 圖示框是掛在 UIParent 底下的普通框、**錨到**單位框上，不是單位框的子物件：
--   單位框是 protected，戰鬥中不能替它生子框；而「錨在 protected 框上」不會讓自己變成
--   protected（保護往父層與被錨的那一方傳，不往錨別人的這一方傳），戰鬥中照樣能擺、能顯示。
-- 用池：同時被 ping 的框很少，用完藏起來留著重用（frame 刪不掉）。
------------------------------------------------------------
local _, ns = ...

local PM = {}
ns.PingMark = PM

local FLASH_SECONDS = 3
local ICON_SIZE = 28

-- 內文裡「前綴」與名字之間的分隔：半形冒號、全形冒號（UTF-8 三個位元組）、空白
local function IsSeparatorTail(s)
    if s == "" then return false end
    local last = s:sub(-1)
    if last == ":" or last == " " then return true end
    return s:sub(-3) == "\239\188\154"
end

-- 聊天文字 → 圖示 atlas, 內文（去掉圖示與色碼）。認不出來回 nil
function PM.Parse(text)
    if type(text) ~= "string" then return nil end
    local atlas = text:match("|A:(ping_chat_[%w_]+):")
    if not atlas then return nil end
    local body = text:gsub("|A.-|a", ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    body = body:gsub("^%s+", ""):gsub("%s+$", "")
    if body == "" then return nil end
    return atlas, body
end

-- 內文是不是在 ping 這個名字
function PM.Matches(body, name)
    if type(name) ~= "string" or name == "" then return false end
    if body == name then return true end
    local n = #name
    if #body <= n then return false end
    -- 「前綴：名字」
    if body:sub(-n) == name and IsSeparatorTail((body:sub(1, #body - n):gsub("%s+$", " "))) then return true end
    -- 語序相反的語系：「名字：前綴」
    if body:sub(1, n) == name then
        local rest = body:sub(n + 1)
        local c = rest:sub(1, 1)
        if c == ":" or c == " " or rest:sub(1, 3) == "\239\188\154" then return true end
    end
    return false
end

------------------------------------------------------------
-- 圖示池
------------------------------------------------------------
local pool, active = {}, {}     -- active[host] = mark

local function Acquire()
    local m = table.remove(pool)
    if m then return m end
    m = CreateFrame("Frame", nil, UIParent)
    m:SetSize(ICON_SIZE, ICON_SIZE)
    m:SetFrameStrata("HIGH")
    m:EnableMouse(false)
    m.tex = m:CreateTexture(nil, "OVERLAY")
    m.tex:SetAllPoints()
    -- 閃爍：整顆的 alpha 在 1 ↔ 0.25 之間來回（每趟 0.25 秒）
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

-- 在 host（任何框）正中央閃一顆。同一個框連續被 ping：換圖、重新計時
function PM.Flash(host, atlas)
    if not (host and host.IsVisible and host:IsVisible()) then return end
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
    C_Timer.After(FLASH_SECONDS, function()
        if active[host] == m and m.token == token then Release(host) end
    end)
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function OnPing(text)
    if not (ns.db and ns.db.global and ns.db.global.pingFlash ~= false) then return end
    if ns.IsSecret(text) then return end       -- 聊天受限時段：對不了名字
    local atlas, body = PM.Parse(text)
    if not atlas then return end
    for _, uf in pairs(ns.frames) do
        if uf:IsVisible() then
            local name = UnitName(uf.unit)
            if not ns.IsSecret(name) and PM.Matches(body, name) then
                PM.Flash(uf, atlas)
            end
        end
    end
end

ns.Events.Register("CHAT_MSG_PING", "pingmark", OnPing)
