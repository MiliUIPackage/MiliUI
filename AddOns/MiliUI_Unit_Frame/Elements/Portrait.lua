------------------------------------------------------------
-- 頭像：3D PlayerModel；拿不到就不畫（明確選 2D 模式才畫 2D）
--
-- 12.1 副本裡的敵人／首領是受限身分，SetUnit 拿不到模型。首領戰有合法後門：
-- Encounter Journal 的 EJ_GetCreatureInfo(index, encounterID) 回的 displayInfo 是明文
-- （暴雪冒險指南就是用它畫模型），ENCOUNTER_START 給 encounterID →
-- boss1..N 對應該戰第 1..N 隻生物；目標／專注若明文確定是 bossN 也套同一顆。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

------------------------------------------------------------
-- 遭遇戰 displayID 表
------------------------------------------------------------
local encounterDisplays = {}      -- [index] = displayID（ENCOUNTER_START 建，ENCOUNTER_END 清）
local encounterActive = false

-- ENCOUNTER_START 給的是 DungeonEncounterID（DBM 那套），EJ 吃的是 JournalEncounterID，
-- 兩套 ID 空間不同 → 用玩家所在地圖找冒險指南 instance，列舉遭遇戰、比對第 7 個回傳值
-- dungeonEncounterID 來換算
local function JournalEncounterFromDungeon(dungeonEncounterID)
    if not (EJ_GetEncounterInfoByIndex and C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local jInst
    if EJ_GetInstanceForMap then
        local ok, id = pcall(EJ_GetInstanceForMap, mapID)
        if ok and id and id > 0 then jInst = id end
    end
    if not jInst and C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
        local ok, id = pcall(C_EncounterJournal.GetInstanceForGameMap, mapID)
        if ok and id and id > 0 then jInst = id end
    end
    if not jInst then return nil end
    if EJ_SelectInstance then pcall(EJ_SelectInstance, jInst) end
    for i = 1, 40 do
        local ok, name, _, jEnc, _, _, _, dungeonEnc = pcall(EJ_GetEncounterInfoByIndex, i, jInst)
        if not ok or not name then break end
        if dungeonEnc == dungeonEncounterID then return jEnc end
    end
    return nil
end

local lastEncounterDebug = ""
local function BuildEncounterDisplays(dungeonEncounterID)
    wipe(encounterDisplays)
    if not (EJ_GetCreatureInfo and dungeonEncounterID) then return end
    local jEnc = JournalEncounterFromDungeon(dungeonEncounterID)
    lastEncounterDebug = ("dungeonEnc=%s journalEnc=%s"):format(
        tostring(dungeonEncounterID), tostring(jEnc))
    if not jEnc then return end
    for i = 1, 9 do
        local ok, _, _, _, displayInfo = pcall(EJ_GetCreatureInfo, i, jEnc)
        if not ok then break end
        if displayInfo == nil then break end
        if type(displayInfo) == "number" and displayInfo > 0 then
            tinsert(encounterDisplays, displayInfo)
        end
    end
end

-- 這個單位在遭遇戰裡對應到哪顆 displayID（nil = 沒有）
local function EncounterDisplayFor(uf)
    if not encounterActive or #encounterDisplays == 0 then return nil end
    local idx = uf.bossIndex
    if not idx then
        -- 目標／專注：明文確定是 bossN 才套（UnitIsUnit 可能回秘密值 → 跳過）
        for i = 1, 5 do
            local m = UnitIsUnit(uf.unit, "boss" .. i)
            if not ns.IsSecret(m) and m then idx = i; break end
        end
    end
    if not idx then return nil end
    -- 生物數少於首領框數時（例如三個附加單位共用一種模型）退到第一隻
    return encounterDisplays[idx] or encounterDisplays[1]
end

local function RefreshEncounterFrames()
    for _, unit in ipairs({ "boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus" }) do
        local uf = ns.frames[unit]
        if uf and uf:IsVisible() and uf.elements.portrait then
            local edb = uf.db.elements.portrait
            if edb and edb.enabled ~= false then
                ns.Elements.portrait.update(uf, edb, "identity")
            end
        end
    end
end

-- 給 /muf debug 看
function ns.GetEncounterDisplays()
    return encounterActive, encounterDisplays, lastEncounterDebug
end

ns.Events.Register("ENCOUNTER_START", "portrait_ej", function(encounterID)
    encounterActive = true
    BuildEncounterDisplays(encounterID)
    RefreshEncounterFrames()
end)
ns.Events.Register("ENCOUNTER_END", "portrait_ej_end", function()
    encounterActive = false
    wipe(encounterDisplays)
    RefreshEncounterFrames()
end)
ns.Events.Register("PLAYER_ENTERING_WORLD", "portrait_ej_pew", function()
    encounterActive = false
    wipe(encounterDisplays)
end)

local function Build(uf, edb)
    local f = uf.elements.portrait or ns.CreateElementBase(uf, "portrait", "Frame", "BackdropTemplate")
    ns.ApplyElementBase(uf, f, edb)

    if not f.bg then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
    end
    f.bg:SetTexture(Media.BarTexture(ns.db.global.barTexture))
    local c = edb.bg or { r = 0.165, g = 0.165, b = 0.165, a = 1 }
    -- 底色 alpha 0 = 去背（3D 模型直接浮在畫面上，首領框的「突出」效果靠這個）
    f.bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    f.bg:SetShown((c.a or 1) > 0)

    if not f.model then
        f.model = CreateFrame("PlayerModel", nil, f)
        f.model:SetAllPoints(f)
    end
    f.model:SetFrameLevel(edb.level or 2)
    f.zoom = edb.zoom or 1              -- 1 = 特寫臉，0 = 全身；首領用 ~0.6 露到肩膀
    f.rotation = edb.rotation or 0      -- 弧度，稍微側身比較有戲

    if not f.tex2d then
        f.tex2d = f:CreateTexture(nil, "ARTWORK")
        f.tex2d:SetAllPoints(f)
        f.tex2d:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    f.tex2d:Hide()

    f:Show()
end

local function Update(uf, edb, bucket)
    local f = uf.elements.portrait
    if not f then return end
    local unit = uf.isPreview and "player" or uf.unit

    if edb.mode == "3d" then
        local ok
        -- 預覽：敵對示範單位（目標／專注／首領）用示範模型（預設薩拉塔斯 131474）
        local demoID = uf.isPreview and not uf.cache.pc and (ns.db.global.previewBossDisplayID or 131474)
        -- 真實遭遇戰：EJ 給的首領 displayID（受限身分下唯一拿得到 3D 的路）
        local ejID = not uf.isPreview and EncounterDisplayFor(uf)
        if demoID and demoID > 0 then
            ok = pcall(f.model.SetDisplayInfo, f.model, demoID)
        elseif ejID then
            pcall(f.model.ClearModel, f.model)
            ok = pcall(f.model.SetDisplayInfo, f.model, ejID)
        else
            -- PlayerModel:SetUnit 對「模型載不進來」的單位（不可見／屍體淡出／受限身分）
            -- 不會清空，而是留上一個模型或退回預設 —— 預設就是玩家自己（widget 就叫 PlayerModel）。
            -- 所以：不可見就不試；試之前先 ClearModel；SetUnit 回 false 也當失敗 → 退 2D
            local vis = UnitIsVisible(unit)
            if ns.IsSecret(vis) then vis = true end        -- 秘密 boolean 當可見（試試看）
            -- 12.1 受限身分單位（副本裡的敵人）：SetUnit 一律拿不到模型、退回玩家自己。
            -- UnitName 是不是秘密 = 身分是否受限的直接探針 → 受限就直接走 2D
            if vis and ns.IsSecret(UnitName(unit)) then vis = false end
            if vis then
                pcall(f.model.ClearModel, f.model)
                local pok, ret = pcall(f.model.SetUnit, f.model, unit)
                ok = pok and ret ~= false
            else
                ok = false
            end
        end
        if ok then
            pcall(f.model.SetPortraitZoom, f.model, f.zoom or 1)
            pcall(f.model.SetRotation, f.model, f.rotation or 0)
            f.model:Show()
            f.tex2d:Hide()
            return
        end
        -- 3D 拿不到（受限身分／不可見）就什麼都不畫，不退 2D（使用者定案：
        -- 副本裡的敵人與首領大多拿不到，寧可空著也不要混一張 2D 破壞風格）
        pcall(f.model.ClearModel, f.model)
        f.model:Hide()
        f.tex2d:Hide()
        return
    end

    -- 明確選 2D 模式才畫 2D
    f.model:Hide()
    if pcall(SetPortraitTexture, f.tex2d, unit) then
        f.tex2d:Show()
    else
        f.tex2d:Hide()
    end
end

ns.RegisterElement{
    name = "portrait",
    order = 10,
    buckets = {},          -- 只吃 identity 全量刷新
    build = Build,
    update = Update,
}
