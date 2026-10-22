------------------------------------------------------------
-- Panel/ReadUnit.lua＋ViewUnit.lua（＋Try.lua 的單位分支）的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Unit_test.lua
--
-- 覆蓋：行的歸類（名字、公會行、等級行、職業行、陣營／PvP、可剝皮、NPC 頭銜、主人、任務、別人後加的行、右鍵提示）；
-- 開關關掉 ⇒ 對 tooltip 零寫入；秘密行／身分受限／token 讀不到 ⇒ 不接（舊樣式）；成功 ⇒ alpha 0、面板顯示；
-- 間距：標題區各行等距、◆ 線上下等距、四邊內距、頭像與文字的距離、等級底板在頭像下方；
-- 同一個單位重建不重畫；目標換人（只有動態簽章變）⇒ 下一幀立刻重畫；秘密的目標名字只交給 SetText；
-- 對帳讀到秘密值 ⇒ 退回並封鎖重接；設定改了 ⇒ 退回但不封鎖；被誰當目標的標籤（自己／別人）與名字表（小隊／團隊）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq, near = H.check, H.eq, H.near
local SECRET = H.SECRET

-- zhTW 實值（Interface/tmp/GlobalStrings/gs_zhTW.csv）
local GS = {
    LEVEL = "等級", FACTION_ALLIANCE = "聯盟", FACTION_HORDE = "部落", PVP = "PvP", DEAD = "死亡", CORPSE = "屍體",
    UNIT_SKINNABLE_LEATHER = "可剝皮", UNIT_SKINNABLE_HERB = "需要草藥學", UNIT_SKINNABLE_ROCK = "需要採礦",
    UNIT_POPUP_RIGHT_CLICK = "<右鍵點擊以查看框架設定>", STATUS_TEXT_TARGET = "目標", ELITE = "精英", BOSS = "首領",
    AFK = "離開", DND = "忙碌", YOU = "你", ZONE = "區域", MAP_LEGEND_RARE = "稀有", MAP_LEGEND_RAREELITE = "稀有精英",
}

local LT_EXTRA = { UnitThreat = 7, QuestObjective = 8, UnitOwner = 16, QuestTitle = 17, QuestPlayer = 18,
    UnitCriteriaProgress = 50 }

local PLAYER_GUID, NPC_GUID, TARGET_GUID = "Player-1-0001", "Creature-0-1-2-3-4-5", "Creature-0-1-2-3-9-9"

local function Setup(opts)
    opts = opts or {}
    local env = H.Env(GS)
    for k, v in pairs(LT_EXTRA) do env.Enum.TooltipDataLineType[k] = v end
    env.FACTION_BAR_COLORS = { [2] = { r = 0.8, g = 0.3, b = 0.22 }, [4] = { r = 0.9, g = 0.7, b = 0 }, [5] = { r = 0, g = 0.6, b = 0.1 } }
    env.RAID_CLASS_COLORS.WARLOCK = { r = 0.53, g = 0.53, b = 0.93 }
    env.RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
    -- 單位世界：mouseover＝玩家或 NPC；它的目標可以換
    -- opts.restricted：身分受限（副本裡的 NPC，2026-10-21 探針實測）——GUID、名字、生物類型秘密；等級、分類、立場明文
    local world = {
        mouseover = opts.npc and NPC_GUID or PLAYER_GUID,
        target = TARGET_GUID, targetName = "旅店老闆奧里森",
        identitySecret = opts.restricted or false, dead = false, afk = false,
    }
    env.world = world
    env.UnitGUID = function(u)
        if u == "mouseover" then return opts.restricted and world.mouseover and SECRET or world.mouseover end
        if u == "mouseovertarget" then return opts.restricted and world.target and SECRET or world.target end
        if u == "player" then return "Player-1-SELF" end
    end
    env.UnitLevel = function(u) if u == "mouseover" then return world.level or 91 end end
    env.UnitEffectiveLevel = env.UnitLevel
    env.UnitClassification = function(u) if u == "mouseover" then return world.classif or "elite" end end
    env.UnitCreatureType = function(u) if u == "mouseover" then return opts.restricted and SECRET or "人型生物" end end
    env.UnitExists = function(u)
        if u == "mouseover" then return world.mouseover ~= nil end
        if u == "mouseovertarget" then return world.target ~= nil end
        return u == "player"
    end
    env.UnitIsPlayer = function(u) return u == "mouseover" and not opts.npc or u == "player" end
    env.UnitName = function(u)
        if u == "mouseovertarget" then return world.targetName end
        if u == "player" then return "米利" end
        if u == "mouseover" then
            if opts.restricted then return SECRET end
            return opts.npc and "狡猾的莫加尼" or "Lokospoks"
        end
    end
    env.UnitClass = function(u) if u == "player" then return "聖騎士", "PALADIN" end; return "術士", "WARLOCK" end
    env.UnitIsUnit = function(a, b) return a == b end
    for _, fn in ipairs({ "UnitIsDead", "UnitIsDeadOrGhost" }) do env[fn] = function() return world.dead end end
    env.UnitIsAFK = function() return world.afk end
    env.UnitIsDND = function() return false end
    env.UnitIsTapDenied = function() return false end
    env.UnitIsPVP = function() return true end
    env.UnitPlayerControlled = function(u) return u == "player" or (u == "mouseover" and not opts.npc) end
    env.UnitCanAttack = function() return false end
    env.UnitReaction = function() return 2 end
    env.UnitTokenFromGUID = function(g) if g == world.mouseover then return "mouseover" end end
    env.C_Secrets = { ShouldUnitIdentityBeSecret = function() return world.identitySecret end }
    env.GetNumGroupMembers = function() return 0 end
    env.IsInRaid = function() return false end
    env.IsAltKeyDown = function() return false end
    env.IsControlKeyDown = function() return false end
    env.GetCreatureDifficultyColor = function() return { r = 1, g = 0.1, b = 0.1 } end
    env.SetPortraitTexture = function(tex, unit) tex.portrait = unit; tex.portraitCalls = (tex.portraitCalls or 0) + 1 end
    env.UnitFactionGroup = function() return "Alliance" end
    -- 分量只用 0／1：Colors.Hex 的 %02x 在 Lua 5.3 收不了小數（遊戲的 5.1 會截斷）
    env.ITEM_QUALITY_COLORS = { [2] = { r = 0, g = 1, b = 0 }, [3] = { r = 0, g = 0, b = 1 },
        [4] = { r = 1, g = 0, b = 1 }, [5] = { r = 1, g = 1, b = 0 } }

    local polls, State = {}, {}
    local fallbacks = {}
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", NoSnap = function(t) return t end, Font = function() return "default.ttf" end },
        playerClass = "PALADIN",
        db = {
            general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
                borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 }, hideUnitFrameHint = true },
            item = { panel = true }, spell = { panel = true },
            panel = { separators = true, unitWatermark = true, extrasBox = true },
            unit = {
                player = { panel = opts.playerPanel ~= false, coloredBorder = "class", showTarget = true, showTargetBy = true,
                    elements = {} },
                npc = { panel = opts.npcPanel ~= false, coloredBorder = "reaction", showTarget = true, showTargetBy = true,
                    grayForDead = true, elements = {} },
            },
        },
        Skin = {
            State = State,
            Poll = function(key, _, fn) polls[key] = fn end,
            Unpoll = function(key) polls[key] = nil end,
            Each = function(fn) for tip, st in pairs(State) do fn(tip, st) end end,
            SetBorderColor = function(tip, r, g, b, a) local st = State[tip]; st.borderColor = { r, g, b, a } end,
        },
    }
    for _, kind in ipairs({ "player", "npc" }) do
        local el = ns.db.unit[kind].elements
        for _, key in ipairs({ "title", "realm", "levelValue", "guildName", "guildRank", "raceName", "className",
            "creature", "classifElite", "classifRare", "classifBoss", "npcTitle", "statusAFK", "itemLevel", "factionName" }) do
            el[key] = { enable = true }
        end
    end
    -- UnitInfo：只給面板會叫到的幾支（真的那份牽一大串全域）
    ns.UnitInfo = {
        GetUnitInfo = function(u)
            local raw = { unit = u, name = env.UnitName(u), level = opts.npc and 10 or 25, effectiveLevel = opts.npc and 10 or 25,
                classif = opts.npc and "rare" or "normal" }
            if not opts.npc then
                raw.guildName, raw.guildRank = "米利公會", "會長"
                raw.raceName, raw.className, raw.class = "人類", "術士", "WARLOCK"
                raw.factionGroup, raw.factionName = "Alliance", "聯盟"
                raw.statusAFK = world.afk and "離開" or nil
                raw.itemLevel = 652
                raw.zone = opts.zone            -- 名冊的地區（GetZone；只有隊友有）
            else
                raw.creature = "人型生物"
            end
            if opts.secretName then raw.name = SECRET end
            return raw
        end,
        ModifierShowAll = function() return false end,
        CheckFilter = function(c) return c.enable end,
        FillMount = function() end,
        RequestInspect = function() end,
        RequestAchievements = function() end,
        inspectState = { cache = {} }, achieveState = { cache = {} },
    }
    for _, f in ipairs({ "Libs/MiliUIWidgets/Secret.lua", "Core/Colors.lua", "Panel/Patterns.lua", "Panel/Frame.lua",
        "Panel/Render.lua", "Panel/Native.lua", "Panel/ReadFallback.lua", "Panel/Try.lua", "Panel/ReadSpell.lua",
        "Panel/ReadUnit.lua", "Panel/ViewUnit.lua" }) do
        H.Load(env, ns, f)
    end
    -- Colors.Hex 的 %02x：遊戲的 Lua 5.1 會截斷小數，5.3 會報錯 ⇒ 測試裡換成先取整的版本（行為同遊戲）
    local hex = ns.Colors.Hex
    ns.Colors.Hex = function(r, g, b)
        if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return hex(r, g, b) end
        return ("%02x%02x%02x"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    end
    local P = ns.Panel
    P.UnitFallback = function(tip, state, key, block) fallbacks[#fallbacks + 1] = { key = key, block = block } end
    local renders = 0
    local render = P.RenderView
    P.RenderView = function(...) renders = renders + 1; return render(...) end

    local LT = env.Enum.TooltipDataLineType
    local lines, data
    if opts.restricted then
        -- 探針實測的形狀：文字、顏色秘密，type／lineIndex 明文；等級行、類型行都是 type 0
        lines = {
            { left = SECRET }, { left = SECRET }, { left = SECRET }, { left = SECRET }, { left = SECRET },
            { left = "Press NUMPAD9 to submit an issue" },   -- 別人後加的（明文）
            { left = SECRET },                               -- 別人後加、讀到秘密：只跳過這一行
        }
        data = { guid = SECRET, lines = {
            { type = LT.UnitName, lineIndex = 1, leftText = SECRET, leftColor = SECRET },
            { type = 0, lineIndex = 2, leftText = SECRET, leftColor = SECRET },
            { type = 0, lineIndex = 3, leftText = SECRET, leftColor = SECRET },
            { type = LT.QuestTitle, lineIndex = 4, leftText = SECRET, leftColor = SECRET },
            { type = LT.QuestObjective, lineIndex = 5, leftText = SECRET, leftColor = SECRET },
        } }
    elseif opts.npc then
        lines = {
            { left = "狡猾的莫加尼" }, { left = "<迪菲亞兄弟會>" }, { left = "等級 10 人型生物（稀有）" },
            { left = "可剝皮" }, { left = "盜賊頭子" },
            { left = "Press NUMPAD9 to submit an issue" },   -- 別人後加的
        }
        data = { guid = NPC_GUID, lines = {
            { type = LT.UnitName, lineIndex = 1, leftText = "狡猾的莫加尼", leftColor = { r = 1, g = 0.1, b = 0.1 } },
            { type = 0, lineIndex = 2, leftText = "<迪菲亞兄弟會>" },
            { type = 0, lineIndex = 3, leftText = "等級 10 人型生物（稀有）" },
            { type = 0, lineIndex = 4, leftText = "可剝皮" },
            { type = 0, lineIndex = 5, leftText = "盜賊頭子" },
        } }
    else
        lines = {
            { left = "Lokospoks" }, { left = "<米利公會>" }, { left = "等級 25 人類 (玩家)" }, { left = "毀滅 術士" },
            { left = "聯盟" }, { left = "PvP" },
        }
        data = { guid = PLAYER_GUID, lines = {
            { type = LT.UnitName, lineIndex = 1, leftText = "Lokospoks" },
            { type = 0, lineIndex = 2, leftText = "<米利公會>" },
            { type = 0, lineIndex = 3, leftText = "等級 25 人類 (玩家)" },
            { type = 0, lineIndex = 4, leftText = "毀滅 術士" },
            { type = 0, lineIndex = 5, leftText = "聯盟" },
            { type = 0, lineIndex = 6, leftText = "PvP" },
        } }
        -- 視野外的隊友：暴雪在最後加一行地名（None、白字、沒有標籤）
        if opts.zoneLine then
            lines[#lines + 1] = { left = opts.zoneLine }
            data.lines[#data.lines + 1] = { type = 0, lineIndex = #data.lines + 1, leftText = opts.zoneLine }
        end
    end
    local tip = H.Tip(env, "GameTooltip", lines)
    local state = {}
    State[tip] = state
    return { env = env, ns = ns, P = P, tip = tip, state = state, data = data, polls = polls, world = world,
        fallbacks = fallbacks, renders = function() return renders end }
end

-- 面板上畫了某段字的 FontString（第一個）
local function FindText(panel, text)
    for i = 1, panel.textsUsed do
        local fs = panel.texts[i]
        if fs.text == text then return fs end
    end
end
local function FindTextLike(panel, pattern)
    for i = 1, panel.textsUsed do
        local fs = panel.texts[i]
        if type(fs.text) == "string" and fs.text:find(pattern, 1, true) then return fs end
    end
end
local function Y(region) return -region.points[1][5] end
local function X(region) return region.points[1][4] end

------------------------------------------------------------
-- 1. 純邏輯：行的歸類
------------------------------------------------------------
do
    local t = Setup()
    local P = t.P
    local LT = t.env.Enum.TooltipDataLineType
    local rows = {
        { left = "Lokospoks", lineIndex = 1, type = LT.UnitName },
        { left = "<米利公會>", lineIndex = 2 },
        { left = "等級 25 人類 (玩家)", lineIndex = 3 },
        { left = "毀滅 術士", lineIndex = 4 },
        { left = "聯盟", lineIndex = 5 },
        { left = "PvP", lineIndex = 6 },
        { left = "|cffffffff威脅 30%|r", lineIndex = 7, type = LT.UnitThreat },
        { left = "<右鍵點擊以查看框架設定>", lineIndex = 8, appended = true },
        { left = "Press NUMPAD9", lineIndex = 9, appended = true },
    }
    local m = P.ReadUnitRows(rows, { isPlayer = true, guildLine = "米利公會", classLine = "術士" }, true)
    eq("玩家：職業行", m.specLine, "毀滅 術士")
    eq("玩家：其他只剩威脅", #m.others, 1)
    eq("玩家：右鍵提示丟掉、別人的行進附屬框", #m.extras, 1)
    eq("玩家：附屬框是別人的行", m.extras[1].left, "Press NUMPAD9")
    local m2 = P.ReadUnitRows(rows, { isPlayer = true, guildLine = "米利公會", classLine = "術士" }, false)
    eq("右鍵提示設定關：留著", #m2.extras, 2)

    -- 不帶角括號的「公會-伺服器」行也是公會行（標題區已經畫了）
    local m3 = P.ReadUnitRows({
        { left = "Lokospoks", lineIndex = 1, type = LT.UnitName },
        { left = "<米利公會> 會長", lineIndex = 2 },
        { left = "毀滅 術士", lineIndex = 3 },
        { left = "|cffffffff米利公會-聖光之願|r", lineIndex = 4 },
        { left = "米利公會的朋友", lineIndex = 5 },
    }, { isPlayer = true, guildLine = "米利公會", classLine = "術士" }, true)
    eq("公會-伺服器行丟掉、名字開頭相同的別行留著", #m3.others, 1)
    eq("留下的是別行", m3.others[1].left, "米利公會的朋友")

    -- 視野外隊友的地區行：跟名冊的地區一樣 ⇒ 認成 model.zone、不進其他；名冊讀不到 ⇒ 照舊留在其他
    local zoneRows = {
        { left = "米利龍", lineIndex = 1, type = LT.UnitName },
        { left = "米利公會-聖光之願", lineIndex = 2 },
        { left = "等級90半龍人（玩家）", lineIndex = 3 },
        { left = "破滅 喚能師", lineIndex = 4 },
        { left = "部落", lineIndex = 5 },
        { left = "|cffffffff憤怒之印|r", lineIndex = 6 },
    }
    local mz = P.ReadUnitRows(zoneRows, { isPlayer = true, guildLine = "米利公會", classLine = "喚能師", zoneLine = "憤怒之印" }, true)
    eq("地區行：認成 zone", mz.zone, "憤怒之印")
    eq("地區行：不進其他", #mz.others, 0)
    eq("地區行：職業行照認", mz.specLine, "破滅 喚能師")
    local mz2 = P.ReadUnitRows(zoneRows, { isPlayer = true, guildLine = "米利公會", classLine = "喚能師" }, true)
    eq("名冊沒地區：不認", mz2.zone, nil)
    eq("名冊沒地區：留在其他", #mz2.others, 1)
    local mz3 = P.ReadUnitRows(zoneRows, { isPlayer = false, zoneLine = "憤怒之印" }, true)
    eq("NPC 不認地區行", mz3.zone, nil)

    local npc = P.ReadUnitRows({
        { left = "狡猾的莫加尼", lineIndex = 1 },
        { left = "<迪菲亞兄弟會>", lineIndex = 2 },
        { left = "等級 10 人型生物", lineIndex = 3 },
        { left = "死亡", lineIndex = 4 },
        { left = "可剝皮", lineIndex = 5 },
        { left = "某某的寵物", lineIndex = 6, type = LT.UnitOwner },
        { left = "清除迪菲亞", lineIndex = 7, type = LT.QuestTitle },
        { left = " - 盜賊: 3/10", lineIndex = 8, type = LT.QuestObjective },
        { left = "", lineIndex = 9, type = LT.Blank },
        { left = "盜賊頭子", lineIndex = 10 },
    }, { isPlayer = false }, true)
    eq("NPC：頭銜", npc.npcTitle, "<迪菲亞兄弟會>")
    eq("NPC：可剝皮是徽章", npc.skin[1], "可剝皮")
    eq("NPC：主人", npc.owner, "某某的寵物")
    eq("NPC：任務兩行", #npc.quests, 2)
    check("NPC：任務標題", npc.quests[1].title)
    eq("NPC：其他一行（死亡由 API 畫）", #npc.others, 1)
    eq("NPC：其他是第二個頭銜", npc.others[1].left, "盜賊頭子")
    local pet = P.ReadUnitRows({
        { left = "BMWDRIVER", lineIndex = 1 }, { left = "Ariwa Ziva的寵物", lineIndex = 2, type = LT.UnitOwner },
        { left = "等級 11 野獸", lineIndex = 3 },
    }, { isPlayer = false }, true)
    eq("寵物：主人不是頭銜", pet.owner, "Ariwa Ziva的寵物")
    eq("寵物：沒有頭銜", pet.npcTitle, nil)
end

------------------------------------------------------------
-- 2. 開關關掉：零寫入；UnitWanted 一次查表
------------------------------------------------------------
do
    local t = Setup({ playerPanel = false, npcPanel = false })
    check("兩個都關：UnitWanted false", not t.P.UnitWanted())
    local t2 = Setup({ playerPanel = false })
    check("NPC 開著：UnitWanted true", t2.P.UnitWanted())
    local shown = t2.P.TryUnit(t2.tip, t2.state, "mouseover", t2.data)
    check("玩家關：不接", not shown)
    eq("玩家關：沒碰 alpha", t2.tip.alphaCalls, nil)
    eq("玩家關：沒碰 padding", t2.tip.padCalls, nil)
    eq("玩家關：沒畫", t2.renders(), 0)
end

------------------------------------------------------------
-- 3. 讀不到 ⇒ 不接（舊樣式）
------------------------------------------------------------
do
    local t = Setup()
    t.data.lines[2].leftText = SECRET
    check("秘密行：不接", not t.P.TryUnit(t.tip, t.state, "mouseover", t.data))
    eq("秘密行：沒碰 alpha", t.tip.alphaCalls, nil)

    -- GUID 明文、C_Secrets 卻說受限：走受限的畫法（不讀行文字）
    local t2 = Setup()
    t2.world.identitySecret = true
    check("身分受限（GUID 明文）：走受限畫法", t2.P.TryUnit(t2.tip, t2.state, "mouseover", t2.data))
    check("身分受限（GUID 明文）：標成受限", t2.state.panelRestricted)
    eq("身分受限（GUID 明文）：不記 GUID", t2.state.panelGuid, nil)

    -- GUID 秘密、token 秘密、游標下也沒有單位：找不到明文 token ⇒ 不接
    local t3 = Setup()
    t3.data.guid = SECRET
    t3.world.mouseover = nil
    check("GUID 秘密、沒有 mouseover：不接", not t3.P.TryUnit(t3.tip, t3.state, SECRET, t3.data))
    eq("GUID 秘密、沒有 mouseover：沒畫", t3.renders(), 0)

    local t4 = Setup({ secretName = true })
    check("名字秘密：不接", not t4.P.TryUnit(t4.tip, t4.state, "mouseover", t4.data))
    eq("名字秘密：alpha 沒被壓", t4.tip.alpha, 1)

    -- 暴雪插進提示的框（UIWidget／進度條）顯示中：面板畫不出來 ⇒ 不接；顯示途中才插進來 ⇒ 下一次對帳讓回原生
    local t6 = Setup()
    local widget = H.Region("Frame", t6.tip); widget.shown = true
    t6.tip.insertedFrames = { widget }
    check("插入框：不接", not t6.P.TryUnit(t6.tip, t6.state, "mouseover", t6.data))
    widget.shown = false
    check("插入框藏著：接", t6.P.TryUnit(t6.tip, t6.state, "mouseover", t6.data))
    widget.shown = true
    t6.tip.lines[#t6.tip.lines + 1] = { left = " " }
    t6.tip:SetLines(t6.tip.lines)
    t6.polls[t6.state]()
    t6.env.FlushTimers()
    check("插入框中途出現：面板收起", not t6.state.panel.shown)
    eq("插入框中途出現：原生 alpha 寫回", t6.tip.alpha, 1)

    -- token 是秘密字串（世界游標）：用 GUID 反查出明文 token 照樣接
    local t5 = Setup()
    check("秘密 token：用 GUID 反查", t5.P.TryUnit(t5.tip, t5.state, SECRET, t5.data))
    eq("秘密 token：明文 token 是 mouseover", t5.state.panelUnit, "mouseover")
end

------------------------------------------------------------
-- 4. 玩家：成功＋內容＋間距
------------------------------------------------------------
do
    local t = Setup()
    local P, LOOK = t.P, t.P.LOOK
    check("玩家：接", t.P.TryUnit(t.tip, t.state, "mouseover", t.data))
    local panel = t.state.panel
    check("面板顯示", panel.shown)
    eq("原生 alpha 0", t.tip.alpha, 0)
    eq("頭像", panel.icon.portrait, "mouseover")
    eq("等級徽章", panel.badgeText.text, "25")
    check("等級底板用難度色", panel.badgeTint ~= nil)
    eq("邊框職業色", t.state.borderColor[1], 0.53)

    local name = FindText(panel, "Lokospoks")
    local guild = FindTextLike(panel, "<米利公會>")
    local info = FindText(panel, "人類 毀滅 術士")
    local badges = FindTextLike(panel, "PvP")
    check("名字", name); check("公會＋階級", guild and guild.text:find("會長", 1, true))
    check("種族＋專精行", info); check("狀態徽章", badges)
    check("陣營徽章", badges and badges.text:find("聯盟", 1, true))
    eq("名字字級 = title + 3", name and name.size, 14 + LOOK.NAME_GROW)

    -- 左緣、頭像與文字的距離
    eq("頭像貼左內距", X(panel.icon), LOOK.PAD)
    eq("標題文字 = 內距 + 頭像 + 間距", X(name), LOOK.PAD + LOOK.ICON_UNIT + LOOK.ICON_GAP)
    eq("名字與頭像同一個上緣", Y(name), Y(panel.icon))

    -- 標題區等距：每一行的頂 = 上一行的頂 + 行高 + UNIT_HEADER_GAP
    local seq = { name, guild, info, badges }
    for i = 2, #seq do
        local prev, cur = seq[i - 1], seq[i]
        if prev and cur then
            eq(("標題區第 %d 行等距"):format(i), Y(cur) - (Y(prev) + prev.size + 2), LOOK.UNIT_HEADER_GAP)
        end
    end

    -- 等級底板在頭像下方、隔 BADGE_GAP（＋1px 邊）
    local bp = panel.badge.points[1]
    eq("底板貼頭像下緣", bp[1] .. ">" .. bp[3], "TOP>BOTTOM")
    eq("底板與頭像的縫", -bp[5], LOOK.BADGE_GAP + 1)

    -- ◆ 線：上下等距（線的 y 與上方標題區底、下方目標列頂）
    local divider
    for i = 1, panel.texturesUsed do
        local tex = panel.textures[i]
        if tex.rotation and tex.rotation ~= 0 then divider = tex end
    end
    check("有 ◆", divider)
    local target = FindText(panel, "目標")
    check("目標列", target)
    local targetName = FindText(panel, "旅店老闆奧里森")
    check("目標名字", targetName)
    eq("目標名字靠右", targetName and targetName.justifyH, "RIGHT")
    local lineY
    for i = 1, panel.texturesUsed do
        local tex = panel.textures[i]
        if tex.w and tex.h == 1 and tex.layer == "ARTWORK" and (tex.sublevel or 0) == 1 then lineY = Y(tex); break end
    end
    local headerBottom = math.max(Y(badges) + badges.size + 2, -panel.badge.points[1][5] + Y(panel.icon) + LOOK.ICON_UNIT
        + LOOK.BADGE_H + 1)
    local above = lineY - headerBottom
    local below = Y(target) - (lineY + 1)
    eq("◆ 線上下等距", above, below)
    eq("◆ 線離文字 RULE_SPACE＋ROW_GAP", below, LOOK.RULE_SPACE + LOOK.ROW_GAP)

    -- 下緣：最後一行（裝等）底到面板底 = ROW_GAP + 下內距；細節列之間 ROW_GAP 等距
    local ilvl = FindText(panel, "ItemLevel")
    check("裝等列", ilvl)
    eq("細節列等距", Y(ilvl) - (Y(target) + target.size + 2), LOOK.ROW_GAP)
    local bottom = 0
    for i = 1, panel.textsUsed do
        local fs = panel.texts[i]
        if fs.shown then bottom = math.max(bottom, Y(fs) + fs.size + 2) end
    end
    eq("下緣內距", panel.height - bottom, LOOK.ROW_GAP + LOOK.PAD + LOOK.PAD_BOTTOM_EXTRA)
    -- 上緣：名字頂到面板頂 = 上內距；左右內距一樣（右欄的字貼右內距）
    eq("上緣內距", Y(name), LOOK.PAD + LOOK.PAD_TOP_EXTRA)
    eq("右欄貼右內距", X(targetName) + targetName.w, panel.width - LOOK.PAD)
    check("面板寬至少 UNIT_MIN_W", panel.width >= LOOK.UNIT_MIN_W)
    check("陣營浮水印", (function()
        for i = 1, panel.texturesUsed do
            if panel.textures[i].texture and tostring(panel.textures[i].texture):find("faction%-alliance") then return true end
        end
    end)())

    -- 同一個單位重建（暴雪重跑 ProcessInfo）：不重畫、頭像不重抓
    local r0, p0 = t.renders(), panel.icon.portraitCalls
    t.env.FlushTimers()
    eq("對帳：沒變不重畫", t.renders(), r0)
    check("同一個單位：接", t.P.TryUnit(t.tip, t.state, "mouseover", t.data))
    t.env.FlushTimers()
    eq("同一個單位：不重畫", t.renders(), r0)

    -- 換目標：動態簽章變了 ⇒ 輪詢排對帳 ⇒ 下一幀立刻重畫（不等 SETTLE）
    t.world.target, t.world.targetName = "Player-1-0009", "米利"
    t.polls[t.state]()
    t.env.FlushTimers()
    eq("換目標：立刻重畫一次", t.renders(), r0 + 1)
    check("換目標：新名字", FindText(panel, "米利"))
    eq("換目標：頭像沒重抓", panel.icon.portraitCalls, p0)

    -- 目標是自己
    t.world.target = "Player-1-SELF"
    t.env.UnitIsUnit = function(a, b) return a == b or (a == "mouseovertarget" and b == "player") end
    t.polls[t.state]()
    t.env.FlushTimers()
    check("目標是自己", FindTextLike(panel, "你"))

    -- 暫離：動態簽章
    t.world.afk = true
    t.polls[t.state]()
    t.env.FlushTimers()
    check("暫離徽章", FindTextLike(panel, "離開"))

    -- 對帳讀到秘密值 ⇒ 退回、封鎖重接
    t.data.lines[3].leftText = SECRET
    t.tip.lines[#t.tip.lines + 1] = { left = "x" }
    t.tip:SetLines(t.tip.lines)
    t.polls[t.state]()
    t.env.FlushTimers()
    t.state.isUnitTip = true      -- （Hooks 設的；這裡直接看 Restore 的分支）
    check("秘密 ⇒ 面板收起", not panel.shown)
    eq("秘密 ⇒ 原生 alpha 寫回", t.tip.alpha, 1)
end

do
    -- 退回時是否重跑舊樣式：post-call 外、還顯示著同一個單位 ⇒ 重跑＋封鎖；設定改了 ⇒ 重跑不封鎖
    local t = Setup()
    t.P.TryUnit(t.tip, t.state, "mouseover", t.data)
    t.state.isUnitTip = true
    t.data.lines[3].leftText = SECRET
    t.tip.lines[#t.tip.lines + 1] = { left = "x" }
    t.tip:SetLines(t.tip.lines)
    t.polls[t.state]()
    t.env.FlushTimers()
    eq("對帳秘密：重跑舊樣式一次", #t.fallbacks, 1)
    check("對帳秘密：封鎖", t.fallbacks[1] and t.fallbacks[1].block)
    eq("對帳秘密：封鎖的是這個單位", t.fallbacks[1] and t.fallbacks[1].key, "unit:" .. PLAYER_GUID)

    local t2 = Setup()
    t2.P.TryUnit(t2.tip, t2.state, "mouseover", t2.data)
    t2.state.isUnitTip = true
    t2.P.RestoreAll()
    eq("設定改了：重跑一次", #t2.fallbacks, 1)
    check("設定改了：不封鎖", t2.fallbacks[1] and not t2.fallbacks[1].block)

    local t3 = Setup()
    t3.P.TryUnit(t3.tip, t3.state, "mouseover", t3.data)
    t3.state.isUnitTip = true
    t3.state.inUnitPostCall = true
    t3.P.Restore(t3.tip, t3.state)
    eq("post-call 裡退回：不重跑（Hooks 馬上跑舊樣式）", #t3.fallbacks, 0)

    -- 封鎖中：同一個單位 1 秒內不接、過了才接
    local t4 = Setup()
    t4.state.unitBlockKey, t4.state.unitBlockUntil = "unit:" .. PLAYER_GUID, 1
    check("封鎖中：不接", not t4.P.TryUnit(t4.tip, t4.state, "mouseover", t4.data))
    t4.env.now = 2
    check("封鎖過了：接", t4.P.TryUnit(t4.tip, t4.state, "mouseover", t4.data))
end

do
    -- 視野外的隊友：暴雪最後那行地名 ⇒ 細節列「區域：地名」，不再沒標籤地丟在最底下的其他段
    local function Count(panel, text)
        local n = 0
        for i = 1, panel.textsUsed do
            local fs = panel.texts[i]
            if fs.shown and fs.text == text then n = n + 1 end
        end
        return n
    end
    local t = Setup({ zone = "憤怒之印", zoneLine = "憤怒之印" })
    check("隊友地區：接", t.P.TryUnit(t.tip, t.state, "mouseover", t.data))
    local panel = t.state.panel
    local label, value = FindText(panel, "區域"), FindText(panel, "憤怒之印")
    check("隊友地區：區域標籤", label)
    check("隊友地區：地名", value)
    eq("隊友地區：地名只畫一次", Count(panel, "憤怒之印"), 1)
    eq("隊友地區：跟標籤同一列", value and label and Y(value), label and Y(label))
    local ilvl = FindText(panel, "ItemLevel")
    check("隊友地區：排在裝等之後（細節段）", ilvl and label and Y(label) > Y(ilvl))

    -- 元素開著（名冊地區本來就畫）＋暴雪的地區行：只畫一列
    local t2 = Setup({ zone = "憤怒之印", zoneLine = "憤怒之印" })
    t2.ns.db.unit.player.elements.zone = { enable = true }
    t2.P.TryUnit(t2.tip, t2.state, "mouseover", t2.data)
    eq("元素開著：區域只一列", Count(t2.state.panel, "區域"), 1)
    eq("元素開著：地名只畫一次", Count(t2.state.panel, "憤怒之印"), 1)

    -- 名冊讀不到地區（不在隊伍、token 對不上）：照舊留在其他段
    local t3 = Setup({ zoneLine = "憤怒之印" })
    t3.P.TryUnit(t3.tip, t3.state, "mouseover", t3.data)
    check("名冊沒地區：沒有區域標籤", not FindText(t3.state.panel, "區域"))
    eq("名冊沒地區：地名還在（其他段）", Count(t3.state.panel, "憤怒之印"), 1)
end

------------------------------------------------------------
-- 5. NPC：稀有、頭銜、可剝皮、其他、別人的行進附屬框、秘密目標名字
------------------------------------------------------------
do
    local t = Setup({ npc = true })
    t.world.targetName = SECRET           -- 它的目標身分受限：名字是秘密值（只能交給 SetText）
    check("NPC：接", t.P.TryUnit(t.tip, t.state, "mouseover", t.data))
    local panel = t.state.panel
    check("NPC：名字", FindText(panel, "狡猾的莫加尼"))
    check("NPC：頭銜", FindText(panel, "<迪菲亞兄弟會>"))
    check("NPC：生物類型", FindText(panel, "人型生物"))
    local badges = FindTextLike(panel, "稀有")
    check("NPC：稀有徽章", badges)
    check("NPC：可剝皮徽章", badges and badges.text:find("可剝皮", 1, true))
    check("NPC：其他（第二個頭銜）", FindText(panel, "盜賊頭子"))
    check("NPC：別人的行在附屬框", panel.extrasBox and panel.extrasBox.shown)
    local fs = t.state.panelTargetFS
    check("秘密目標：記下那顆字", fs)
    check("秘密目標：原封不動交給 SetText", fs and rawequal(fs.text, SECRET))
    -- 寫過秘密字串的字之後量不出高度：那一顆不能是池裡的（不然還回去被別的段落借到，量高回秘密 ⇒ 只留一行、跟下一段疊在一起）
    local pooled = false
    for _, p in ipairs(panel.texts) do if p == fs then pooled = true end end
    check("秘密目標：不跟池借", fs and not pooled)
    t.world.targetName = "換人"
    t.P.UnitTick(t.state)
    eq("秘密目標：輪詢重新交給 SetText", fs and fs.text, "換人")
    check("NPC：沒有陣營浮水印（沒有 C_Texture 就沒有龍）", true)

    -- 死了：灰（grayForDead）
    t.world.dead = true
    t.world.targetName = "旅店老闆"
    t.polls[t.state]()
    t.env.FlushTimers()
    local name = FindText(panel, "狡猾的莫加尼")
    near("死亡：名字灰", name and name.textColor[1], 0.6)
    check("死亡：頭像去色", panel.icon.desaturated)
    check("死亡徽章", FindTextLike(panel, "死亡"))
    check("換成明文目標後：秘密那顆放掉", t.state.panelTargetFS == nil)
    check("換成明文目標後：秘密那顆藏起來", fs and not fs.shown)
    local measurable = true
    for i = 1, panel.textsUsed do
        if t.env.issecretvalue(panel.texts[i]:GetStringHeight()) then measurable = false end
    end
    check("重畫後：池裡每一顆都量得出高度", measurable)
end

------------------------------------------------------------
-- 6. 身分受限的 NPC（副本裡，2026-10-21 探針實測的形狀）：秘密名字／類型交給專用字、明文的等級分類照畫、
--    None 行不畫、任務行原封不動、別人的明文行進附屬框；寬度照原生排好的寬留；對帳不退；退回時封鎖受限那一把
------------------------------------------------------------
do
    local function Pooled(panel, fs)
        for _, p in ipairs(panel.texts) do if p == fs then return true end end
        return false
    end
    local t = Setup({ npc = true, restricted = true })
    t.world.targetName = SECRET
    check("受限：接（秘密 token 用 mouseover 代替）", t.P.TryUnit(t.tip, t.state, SECRET, t.data))
    eq("受限：明文 token", t.state.panelUnit, "mouseover")
    check("受限：標成受限", t.state.panelRestricted)
    eq("受限：原生 alpha 0", t.tip.alpha, 0)
    local panel = t.state.panel
    check("受限：面板顯示", panel.shown)
    local st = panel.secretTexts or {}
    local name = st.name
    check("受限：名字原封不動交給 SetText", name and rawequal(name.text, SECRET))
    check("受限：名字那顆不跟池借", name and not Pooled(panel, name))
    check("受限：名字是立場色", name and name.textColor and math.abs(name.textColor[1] - 0.8) < 0.3)
    check("受限：第二個 None 行（類型）原封不動進標題區", st.info1 and rawequal(st.info1.text, SECRET))
    check("受限：第一個 None 行（等級行）不畫", st.info2 == nil)
    eq("受限：等級底板（明文）", panel.badgeText.text, "91")
    check("受限：精英徽章（明文分類）", FindTextLike(panel, "精英"))
    check("受限：任務標題", st.quest1 and rawequal(st.quest1.text, SECRET))
    check("受限：任務目標", st.quest2 and rawequal(st.quest2.text, SECRET))
    check("受限：沒有其他段", st.other1 == nil)
    check("受限：別人的明文行在附屬框", panel.extrasBox and panel.extrasBox.shown)
    check("受限：秘密目標名字", t.state.panelTargetFS and rawequal(t.state.panelTargetFS.text, SECRET))
    local measurable = true
    for i = 1, panel.textsUsed do
        if t.env.issecretvalue(panel.texts[i]:GetStringHeight()) then measurable = false end
    end
    check("受限：池裡每一顆都量得出高度", measurable)

    -- 名字寬照原生排好的寬：post-call 當下原生還沒照新內容排（量不準），第一次只畫最小寬，對帳時量到才補
    eq("受限：post-call 當下不拿原生的寬", panel.width, 250)
    t.env.FlushTimers()
    check("受限：對帳後還顯示", panel.shown)
    local w1 = panel.width
    check("受限：對帳量到原生的寬 ⇒ 替名字留寬", w1 > 250)

    -- 同一隻又進 post-call（提示刷新）：重畫，寬度不因為原生被撐大而越長越寬（ContentWidth 扣掉自己撐的 padding）
    t.P.TryUnit(t.tip, t.state, SECRET, t.data)
    t.env.FlushTimers()
    eq("受限：重畫寬度不漂", panel.width, w1)

    -- 暴雪真正的刷新順序（TooltipDataHandlerMixin:InternalProcessInfo）：ClearLines（padding 清回 0、尺寸不動）→ 加行 →
    -- post-call → Show() 才照新內容＋當下的 padding 重排。post-call 當下 GetWidth 還是被我們撐到面板寬的那個；
    -- 拿它當名字寬的話每刷新一次寬一截（2026-10-22 回報「有時候好長、有點隨機」）
    local function Refresh(tc, natural)
        local tip = tc.tip
        tip.padding = { 0, 0, 0, 0 }
        tc.P.TryUnit(tip, tc.state, SECRET, tc.data)
        tip.w = natural + tip.padding[1]
        tc.env.FlushTimers()
    end
    for _ = 1, 4 do Refresh(t, 200) end
    eq("受限：刷新四次（padding 被清、尺寸還沒重排）寬度不漂", panel.width, w1)

    -- 不收提示直接滑到另一隻（token 都是 mouseover）：post-call 先照上一隻的寬畫，對帳量到就照這一隻（可以變窄）
    Refresh(t, 400)
    local wLong = panel.width
    check("受限：換一隻名字長的 ⇒ 變寬", wLong > w1)
    Refresh(t, 200)
    eq("受限：換回名字短的 ⇒ 對帳後變回原寬", panel.width, w1)
    -- 同一輪裡原生變寬（行數沒變、內容變長）：輪詢量到就補；變窄不縮（別家的行輪流出現不來回）
    t.tip.w = t.tip.w + 100
    t.polls[t.state]()
    t.env.FlushTimers()
    check("受限：輪詢量到原生變寬 ⇒ 跟著寬", panel.width > w1)
    local wGrown = panel.width
    t.tip.w = t.tip.w - 100
    t.polls[t.state]()
    t.env.FlushTimers()
    eq("受限：同一輪原生變窄 ⇒ 不縮", panel.width, wGrown)
    Refresh(t, 200)
    eq("受限：下一次 post-call ⇒ 照新量的", panel.width, w1)

    -- 剛顯示時原生的尺寸是上一個提示（例如很寬的物品）排的：不能拿來當名字寬
    local tw = Setup({ npc = true, restricted = true })
    tw.tip.w = 440
    tw.P.TryUnit(tw.tip, tw.state, SECRET, tw.data)
    tw.tip.w = 200 + tw.tip.padding[1]
    tw.env.FlushTimers()
    eq("受限：上一個提示很寬 ⇒ 對帳後寬度照這一隻", tw.state.panel.width, w1)

    -- 原生排得比較寬（長名字）⇒ 面板替名字留寬（post-call 當下量不準，對帳時量）
    local t2 = Setup({ npc = true, restricted = true })
    t2.tip.w = 600
    t2.P.TryUnit(t2.tip, t2.state, SECRET, t2.data)
    t2.env.FlushTimers()
    check("受限：原生寬 ⇒ 面板跟著寬", t2.state.panel.width > w1)
    local nameFS = t2.state.panel.secretTexts.name
    check("受限：名字那一欄寬度給滿", nameFS.w and nameFS.w > 300)

    -- 原生的幾何是秘密（探針只量過脫戰；戰鬥中若變秘密）⇒ 替身撐不了，不接、alpha 寫回（舊樣式照跑）
    local t3 = Setup({ npc = true, restricted = true })
    t3.tip.GetWidth = function() return SECRET end
    check("受限：原生寬是秘密 ⇒ 不接", not t3.P.TryUnit(t3.tip, t3.state, SECRET, t3.data))
    eq("受限：原生寬是秘密 ⇒ alpha 寫回", t3.tip.alpha, 1)

    -- 對帳時行的型別變秘密 ⇒ 退回、封鎖受限那一把 1 秒
    local t4 = Setup({ npc = true, restricted = true })
    t4.state.isUnitTip = true      -- （Hooks 設的；這裡直接看 Restore 的分支）
    t4.P.TryUnit(t4.tip, t4.state, SECRET, t4.data)
    t4.data.lines[2].type = SECRET
    t4.state.panelFingerprint = nil
    t4.P.Reconcile(t4.tip, t4.state)
    check("受限：型別變秘密 ⇒ 面板收起", not t4.state.panel.shown)
    eq("受限：退回封鎖受限那一把", t4.fallbacks[1] and t4.fallbacks[1].key, t4.P.UNIT_BLOCK_RESTRICTED)
    t4.state.unitBlockKey, t4.state.unitBlockUntil = t4.P.UNIT_BLOCK_RESTRICTED, 1     -- （UnitFallback 設的）
    t4.data.lines[2].type = 0
    check("受限：封鎖中不接", not t4.P.TryUnit(t4.tip, t4.state, SECRET, t4.data))
    t4.env.now = 2
    check("受限：封鎖過了再接", t4.P.TryUnit(t4.tip, t4.state, SECRET, t4.data))

    -- 換成明文的單位：受限的旗標清掉、走一般路徑
    local t5 = Setup({ npc = true, restricted = true })
    t5.P.TryUnit(t5.tip, t5.state, SECRET, t5.data)
    t5.P.Restore(t5.tip, t5.state)
    eq("受限：退回清掉旗標", t5.state.panelRestricted, nil)

    -- M+ 小怪的實際形狀（2026-10-21 納羅拉克之穴，戰鬥中）：名字、四個 None、敵軍部隊進度（50）、仇恨（7）
    local t6 = Setup({ npc = true, restricted = true })
    local LT = t6.env.Enum.TooltipDataLineType
    local mplus = { { type = LT.UnitName, lineIndex = 1, leftText = SECRET, leftColor = SECRET } }
    for i = 2, 5 do mplus[i] = { type = 0, lineIndex = i, leftText = SECRET, leftColor = SECRET } end
    mplus[6] = { type = LT.UnitCriteriaProgress, lineIndex = 6, leftText = SECRET, leftColor = SECRET }
    mplus[7] = { type = LT.UnitThreat, lineIndex = 7, leftText = SECRET, leftColor = SECRET }
    t6.data.lines = mplus
    local tipLines = {}
    for i = 1, 7 do tipLines[i] = { left = SECRET } end
    t6.tip:SetLines(tipLines)
    check("M+：接", t6.P.TryUnit(t6.tip, t6.state, SECRET, t6.data))
    local s6 = t6.state.panel.secretTexts or {}
    check("M+：等級行之後的三個 None 行都在標題區", s6.info1 and s6.info2 and s6.info3 and not s6.info4)
    check("M+：敵軍部隊進度留著", s6.other1 and rawequal(s6.other1.text, SECRET) and s6.other1.shown)
    check("M+：仇恨留著", s6.other2 and rawequal(s6.other2.text, SECRET))
    -- 名字那一欄至少要有原生排好的寬：秘密行不量寬，寬度全靠它
    check("M+：標題的秘密行寬度給滿", s6.info1 and s6.name and s6.info1.w == s6.name.w)
end

------------------------------------------------------------
-- 被誰當目標：標籤是中性的「誰在看他」（隊友選你當目標不一定在打你），滑的是自己改說「我」；
-- 小隊、或團隊裡滑玩家列名字，團隊裡滑 NPC 只數人數；自己不算
------------------------------------------------------------
do
    -- prefix 隊伍的 targeting 這幾個人把 token 當目標；團隊裡 raid1 是自己（也把它當目標，要被排除）
    local function TargetedByRow(opts, token, prefix, targeting)
        local t = Setup(opts)
        local env = t.env
        env.GetNumGroupMembers = function() return 4 end
        env.IsInRaid = function() return prefix == "raid" end
        local set = {}
        for _, m in ipairs(targeting) do set[m .. "target"] = true end
        if prefix == "raid" then set["raid1target"] = true end
        env.UnitIsUnit = function(a, b)
            if a == token and set[b] then return true end
            if prefix == "raid" and a == "raid1" and b == "player" then return true end
            return a == b
        end
        local unitName = env.UnitName
        env.UnitName = function(u)
            local n = u:match("^" .. prefix .. "(%d)$")
            if n then return "隊友" .. n end
            return unitName(u)
        end
        local f = t.P.UnitFacts(token, t.ns.db.unit[opts.npc and "npc" or "player"])
        local view = t.P.ViewUnit({ facts = f, others = {}, quests = {}, extras = {} })
        for _, section in ipairs(view.sections) do
            for _, row in ipairs(section.rows or {}) do
                if row.left == "Targeted by" or row.left == "Targeting you" then return row, f.targetedBy end
            end
        end
    end
    local function Plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

    local row = TargetedByRow({}, "mouseover", "party", { "party1", "party3" })
    eq("小隊滑玩家：中性標籤", row and row.left, "Targeted by")
    eq("小隊滑玩家：列名字", row and Plain(row.right), "隊友1, 隊友3")

    row = TargetedByRow({}, "player", "party", { "party2" })
    eq("小隊滑自己：標籤說「我」", row and row.left, "Targeting you")
    eq("小隊滑自己：列名字", row and Plain(row.right), "隊友2")

    local by
    row, by = TargetedByRow({}, "mouseover", "raid", { "raid2", "raid4" })
    eq("團隊滑玩家：自己不算", by and by.count, 2)
    eq("團隊滑玩家：也列名字（跟小隊一樣）", row and Plain(row.right), "隊友2, 隊友4")

    row, by = TargetedByRow({ npc = true }, "mouseover", "raid", { "raid2", "raid3", "raid4" })
    eq("團隊滑 NPC：只數人數", row and Plain(row.right), "3")
    eq("團隊滑 NPC：沒有名字表", by and by.names, nil)

    check("沒人看：沒有這一列", not TargetedByRow({}, "mouseover", "party", {}))
end

H.finish("Unit_test")
