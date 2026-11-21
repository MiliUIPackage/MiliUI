------------------------------------------------------------
-- 診斷記錄：引擎發現「現況跟預期不一樣」時記一行，留在存檔裡
--
-- 冷卻管理器的毛病多半是「不報錯但畫面壞了」（進副本、被系統換專精、暴雪重建整條檢視器），
-- 發生當下沒有任何 Lua 錯誤可以看，事後也重現不了。所以引擎每次自己修掉一個異常
-- （縮放被改、清單漏了暴雪正在顯示的法術、讀取畫面後重排…）就在這裡記一行，
-- 連同 /mcdm debug 的完整輸出一起存進 SavedVariables：
--
--   MiliUI_CooldownManager_DB.diag = {
--       log  = { "09-30 16:21:05 [adopt] utility ← 19397, 19393", … },   最近 LOG_MAX 行（跨登入保留）
--       dump = { … },  dumpAt = "09-30 16:30:12",                          上一次 /mcdm debug 的輸出
--       perf = { … },  perfAt = "…",                                       上一次 /mcdm perf 的輸出
--       glow = { … },  glowAt = "…",                                       上一次 /mcdm glow 的輸出
--       echo = { … },  echoAt = "…",                                       上一次 /mcdm echo 的輸出
--       deck = { … },  deckAt = "…",                                       上一次 /mcdm deck 的輸出
--       charge = { … }, chargeAt = "…",                                    上一次 /mcdm charge 的輸出
--       cs = { … },    csAt = "…",                                         上一次 /mcdm cs 的輸出
--   }
--
--   ns.Diag.Note(kind, text)   記一行。跟上一行一模一樣就只累計次數，不洗版
--   ns.Diag.Lines(n)           最近 n 行（新 → 舊），給 /mcdm debug 印
--   ns.Diag.SaveDump(lines)    存 /mcdm debug 的輸出
--   ns.Diag.SavePerf(lines)    存 /mcdm perf 的輸出（另一個欄位：/mcdm debug 換掉 dump 時不會把它洗掉）
--   ns.Diag.SaveGlow(lines)    存 /mcdm glow 的輸出（同上，自己一個欄位）
--   ns.Diag.SaveEcho(lines)    存 /mcdm echo 的輸出（事件視窗的探針，Modules/EchoWindow.lua）
--   ns.Diag.SaveDeck(lines)    存 /mcdm deck 的輸出（觸發牌堆的探針，Modules/ProcDeck.lua）
--   ns.Diag.SaveCharge(lines)  存 /mcdm charge 的輸出（核心／輔助充能格的回充長相，Core/Decorate.lua）
--   ns.Diag.SaveCS(lines)      存 /mcdm cs 的輸出（征戰聖擊鏡射列的現況與轉換記錄，Modules/Resources_Rows.lua）
--   ns.Diag.Attach(sv)         DB 就緒後接上存檔（之前記的先放在記憶體裡）
--
-- 這支只記不修，修的動作在各模組；字串不進語系檔（開發用）。
------------------------------------------------------------
local _, ns = ...

ns.Diag = {}
local D = ns.Diag

local LOG_MAX = 120
local log = {}            -- 接上存檔之後就是存檔裡那張表
local lastText, lastIndex, repeats = nil, nil, 0

local function Stamp()
    local d = _G.date
    return d and d("%m-%d %H:%M:%S") or "?"
end

local function Push(line)
    log[#log + 1] = line
    while #log > LOG_MAX do table.remove(log, 1) end
    return #log
end

function D.Note(kind, text)
    text = "[" .. tostring(kind) .. "] " .. tostring(text)
    if text == lastText and lastIndex and log[lastIndex] then
        repeats = repeats + 1
        log[lastIndex] = ("%s %s ×%d"):format(Stamp(), text, repeats)
        return
    end
    lastText, repeats = text, 1
    lastIndex = Push(Stamp() .. " " .. text)
end

function D.Lines(n)
    local out = {}
    for i = #log, math.max(1, #log - (n or 10) + 1), -1 do out[#out + 1] = log[i] end
    return out
end

function D.Count() return #log end

function D.SaveDump(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.dump = lines
    sv.diag.dumpAt = Stamp()
end

function D.SavePerf(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.perf = lines
    sv.diag.perfAt = Stamp()
end

function D.SaveGlow(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.glow = lines
    sv.diag.glowAt = Stamp()
end

function D.SaveEcho(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.echo = lines
    sv.diag.echoAt = Stamp()
end

function D.SaveDeck(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.deck = lines
    sv.diag.deckAt = Stamp()
end

function D.SaveCharge(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.charge = lines
    sv.diag.chargeAt = Stamp()
end

function D.SaveCS(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.cs = lines
    sv.diag.csAt = Stamp()
end

function D.Attach(sv)
    if type(sv) ~= "table" then return end
    local saved = type(sv.diag) == "table" and sv.diag or {}
    local old = type(saved.log) == "table" and saved.log or {}
    -- 舊的在前、這次登入到目前為止記的接在後面
    local pending = log
    log = {}
    for i = 1, #old do if type(old[i]) == "string" then Push(old[i]) end end
    Push(Stamp() .. " ── 登入／重載 ──")
    for i = 1, #pending do Push(pending[i]) end
    lastText, lastIndex = nil, nil
    saved.log = log
    sv.diag = saved
end

------------------------------------------------------------
-- /mcdm under：游標底下每一張看得到的貼圖
--
-- 畫面上有來路不明的東西（卡住的發光、放錯大小的圖）時用：從 UIParent 往下走遍所有框，列出矩形蓋到游標、
-- 而且真的看得到（IsVisible、整條鏈的 alpha > 0）的貼圖，由小到大。每行：尺寸、圖（圖集或檔名）、混合模式、
-- alpha、往上幾層有名字的祖先（我們的容器叫 MiliUICDM_Bar_<key>；畫面編輯的假格標「假格:<key>」）。
-- 只讀不寫；讀回來是秘密值的（錨在受限框上的）整張跳過。一次性的走訪，不常駐。
------------------------------------------------------------
local function Plain(v)
    if ns.IsSecret and ns.IsSecret(v) then return nil end
    return type(v) == "number" and v or nil
end

function ns.Diag.UnderCursor()
    local out, found = {}, {}
    local skipped = 0
    local rx, ry = GetCursorPosition()
    local ghost = {}
    for key, h in pairs(ns.LiveEdit and ns.LiveEdit.hosts or {}) do ghost[h.holder] = key end
    local function Owner(f)
        local parts, depth = {}, 0
        while f and depth < 12 do
            if ghost[f] then parts[#parts + 1] = "假格:" .. tostring(ghost[f]) end
            local ok, name = pcall(f.GetName, f)
            if ok and type(name) == "string" and not (ns.IsSecret and ns.IsSecret(name)) then parts[#parts + 1] = name end
            local okp, parent = pcall(f.GetParent, f)
            f = okp and parent or nil
            depth = depth + 1
        end
        return #parts > 0 and table.concat(parts, " < ") or "（整條都沒名字）"
    end
    local function Walk(f)
        -- 受限框的 IsVisible 讀回來是秘密布林（連 if 都不能判）：先過 IsSecret，秘密的整棵跳過
        local okv, vis = pcall(f.IsVisible, f)
        if not okv or (ns.IsSecret and ns.IsSecret(vis)) or not vis then return end
        local oks, scale = pcall(f.GetEffectiveScale, f)
        local oka, ea = pcall(f.GetEffectiveAlpha, f)
        scale, ea = oks and Plain(scale), oka and Plain(ea)
        if scale and scale > 0 and ea and ea > 0 then
            local cx, cy = rx / scale, ry / scale
            for _, r in ipairs({ f:GetRegions() }) do
                local rv = r.IsVisible and r:IsVisible()
                if ns.IsSecret and ns.IsSecret(rv) then rv = false end
                if rv and r.GetObjectType and r:GetObjectType() == "Texture" then
                    local ok, l, b, w, h = pcall(r.GetRect, r)
                    l, b, w, h = ok and Plain(l), ok and Plain(b), ok and Plain(w), ok and Plain(h)
                    local a = Plain(r:GetAlpha())
                    if l and b and w and h and a and a > 0 and cx >= l and cx <= l + w and cy >= b and cy <= b + h then
                        local tex = r:GetAtlas() or r:GetTexture()
                        found[#found + 1] = { area = w * h, line = ("%.0fx%.0f  %s  %s  alpha %.2f×%.2f  %s  ｜ %s"):format(
                            w, h, tostring(tex), tostring(r:GetBlendMode()), a, ea, tostring(r:GetDrawLayer()), Owner(f)) }
                    end
                end
            end
        end
        -- 一棵子樹出錯（別的秘密值讀法）不要中斷整趟
        for _, c in ipairs({ f:GetChildren() }) do
            if not pcall(Walk, c) then skipped = skipped + 1 end
        end
    end
    local ok, err = pcall(Walk, UIParent)
    table.sort(found, function(x, y) return x.area < y.area end)
    for i = 1, math.min(#found, 40) do
        out[i] = found[i].line
        if ns.Diag.Note then ns.Diag.Note("under", found[i].line) end
    end
    if not ok then out[#out + 1] = "走訪中斷：" .. tostring(err) end
    if skipped > 0 then out[#out + 1] = ("（%d 棵子樹讀不了，跳過）"):format(skipped) end
    return out
end
