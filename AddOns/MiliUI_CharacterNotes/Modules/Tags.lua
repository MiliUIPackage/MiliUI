------------------------------------------------------------
-- 筆記標記
--
-- 一行筆記裡可以夾幾種 `{...}` 標記，顯示的時候才展開。設計上照著團隊筆記那類
-- 插件已經通行的寫法（`{time:1:30}`、`{spell:12345}`、`{rt1}`、角色過濾），
-- 玩家從別處抄一段過來多半是通的。
--
--   {time:1:30} {time:90}   這一行的時間點；顯示成倒數，戰鬥開始才會跑
--   {rt1} ... {rt8}         團隊標記圖示（星星、圓圈…）
--   {spell:12345}           法術圖示＋名稱
--   {p:主坦}                 **顯示**那個變數（或那個玩家）的名字，職業色
--   {p:主坦}...{/p}          **只有**那組人看得到這一段
--   {t}...{/t} {h}...{/h} {d}...{/d}   只有坦／補／輸出看得到
--   {c:WARRIOR}...{/c}      只有那個職業看得到
--
-- `{p:...}` 兩種寫法靠「有沒有收尾」分辨，這是使用者實際會用到的兩件事：
-- 時間軸上寫「誰去做」（顯示）與「這句話是給誰看的」（過濾）。
-- 中間那個名字可以是**分組變數**（見 Core/Roster.lua）或直接打玩家名字；
-- 變數的好處是下一場只要重新分配名單，所有時間軸筆記就自動指到新的人。
--
-- ⚠ 12.1：這裡**只讀自己的身分**（UnitName("player")、ns.playerClass、專精角色），
--   完全不碰隊友的 Unit API —— 那些在受限身分下是秘密值，拿來比對或當 key 會崩潰。
--   「只有某人看得到」是本機的顯示過濾，不需要知道別人是誰。
------------------------------------------------------------
local _, ns = ...

ns.Tags = {}
local Tags = ns.Tags

------------------------------------------------------------
-- 自己的身分（每次過濾都要用，快取起來；專精會換所以不能只算一次）
------------------------------------------------------------
local function MyName()
    local name = UnitName("player")
    if not name or ns.issecret(name) then return nil end
    return name:lower()
end

local function MyRole()
    if not (GetSpecialization and GetSpecializationRole) then return nil end
    local spec = GetSpecialization()
    if not spec then return nil end
    local ok, role = pcall(GetSpecializationRole, spec)
    return ok and role or nil
end

------------------------------------------------------------
-- 時間
------------------------------------------------------------
-- "1:30" → 90、"90" → 90
local function ParseTime(str)
    local m, sec = str:match("^(%d+):(%d+)$")
    if m then return tonumber(m) * 60 + tonumber(sec) end
    local plain = str:match("^(%d+)$")
    if plain then return tonumber(plain) end
    return nil
end

-- 這一行的時間點（取第一個 {time:...}）
function Tags.Time(text)
    if type(text) ~= "string" then return nil end
    for body in text:gmatch("{[Tt][Ii][Mm][Ee]:([^}]+)}") do
        local sec = ParseTime(strtrim(body))
        if sec then return sec end
    end
    return nil
end

------------------------------------------------------------
-- 圖示
------------------------------------------------------------
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d"

-- 多個名字之間的分隔。中文用頓號、其他語系用逗號 —— 只是排版，不值得開一個語系 key
local NAME_SEP = GetLocale():find("^zh") and "、" or ", "

local function SpellMarkup(id)
    id = tonumber(id)
    if not id then return nil end
    local tex, name
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, id)
        if ok then tex = t end
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok then name = n end
    end
    if not tex then return nil end
    -- 查不到名字就只放圖示（法術可能是別的資料片的、或客戶端還沒快取到）
    return ("|T%s:0|t%s"):format(tex, name and (" " .. name) or "")
end

------------------------------------------------------------
-- 展開
--
-- 回傳 顯示用文字, 時間點（秒；沒有就是 nil）
------------------------------------------------------------
function Tags.Render(text)
    if type(text) ~= "string" or text == "" then return text or "", nil end
    if not text:find("{", 1, true) then return text, nil end

    local seconds = Tags.Time(text)
    local out = text:gsub("{[Tt][Ii][Mm][Ee]:[^}]*}", "")

    ------------------------------------------------------------
    -- 過濾：符合就把外框拿掉留內容，不符合就整段刪掉
    ------------------------------------------------------------
    local function Filter(pattern, keep)
        out = out:gsub(pattern, function(a, b)
            -- 兩個捕獲的用法：a = 參數、b = 內容；一個捕獲時 a 就是內容
            if b == nil then return keep(nil) and a or "" end
            return keep(a) and b or ""
        end)
    end

    -- ⚠ 成對的要先處理。先做單獨的話，`{p:A}文字{/p}` 的開頭會被當成「顯示名字」
    --   換掉，剩下一個孤兒 {/p}。
    local myName = MyName()
    Filter("{[Pp]:([^}]*)}(.-){/[Pp]}", function(who)
        if not myName then return false end
        for _, n in ipairs(ns.Roster.ResolveNames(who)) do
            if n:lower() == myName then return true end
        end
        return false
    end)

    local myClass = ns.playerClass
    Filter("{[Cc]:([^}]*)}(.-){/[Cc]}", function(cls)
        if type(myClass) ~= "string" then return false end
        return strtrim(cls or ""):upper() == myClass:upper()
    end)

    local role = MyRole()
    Filter("{[Tt]}(.-){/[Tt]}", function() return role == "TANK" end)
    Filter("{[Hh]}(.-){/[Hh]}", function() return role == "HEALER" end)
    Filter("{[Dd]}(.-){/[Dd]}", function() return role == "DAMAGER" end)

    ------------------------------------------------------------
    -- 圖示與代換
    ------------------------------------------------------------
    out = out:gsub("{[Rr][Tt]([1-8])}", function(n)
        return ("|T" .. RAID_ICON .. ":0|t"):format(tonumber(n))
    end)

    out = out:gsub("{[Ss][Pp][Ee][Ll][Ll]:(%d+)}", function(id)
        return SpellMarkup(id) or ("{spell:" .. id .. "}")
    end)

    -- 單獨的 {p:...}：把變數換成實際的名字（職業色）。
    -- 變數是空的就顯示灰色的 [變數名] —— 寫的人一眼看得出「這組還沒分配人」。
    out = out:gsub("{[Pp]:([^}]*)}", function(who)
        local names = ns.Roster.ResolveNames(who)
        if #names == 0 then
            return "|cff808080[" .. strtrim(who or "") .. "]|r"
        end
        local parts = {}
        for i, n in ipairs(names) do
            parts[i] = ns.Media.ClassColoredName(n, ns.Roster.ClassOf(n))
        end
        return table.concat(parts, NAME_SEP)
    end)

    -- 認不得的標記**留著不動**：玩家打錯字時看得到自己打了什麼，
    -- 默默吃掉只會變成「我明明寫了東西卻不見了」。
    return out, seconds
end

------------------------------------------------------------
-- 編輯器用：這一行有沒有標記（有的話清單/編輯器要提示「顯示時會變樣」）
------------------------------------------------------------
function Tags.Has(text)
    return type(text) == "string" and text:find("%b{}") ~= nil
end
