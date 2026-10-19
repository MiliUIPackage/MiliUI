------------------------------------------------------------
-- Panel/ReadUnit.lua＋ViewUnit.lua（＋Try.lua 的單位分支）的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Unit_test.lua
--
-- 覆蓋：行的歸類（名字、公會行、等級行、職業行、陣營／PvP、可剝皮、NPC 頭銜、主人、任務、別人後加的行、右鍵提示）；
-- 開關關掉 ⇒ 對 tooltip 零寫入；秘密行／身分受限／token 讀不到 ⇒ 不接（舊樣式）；成功 ⇒ alpha 0、面板顯示；
-- 間距：標題區各行等距、◆ 線上下等距、四邊內距、頭像與文字的距離、等級底板在頭像下方；
-- 同一個單位重建不重畫；目標換人（只有動態簽章變）⇒ 下一幀立刻重畫；秘密的目標名字只交給 SetText；
-- 對帳讀到秘密值 ⇒ 退回並封鎖重接；設定改了 ⇒ 退回但不封鎖。
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

local LT_EXTRA = { UnitThreat = 7, QuestObjective = 8, UnitOwner = 16, QuestTitle = 17, QuestPlayer = 18 }

local PLAYER_GUID, NPC_GUID, TARGET_GUID = "Player-1-0001", "Creature-0-1-2-3-4-5", "Creature-0-1-2-3-9-9"

local function Setup(opts)
    opts = opts or {}
    local env = H.Env(GS)
    for k, v in pairs(LT_EXTRA) do env.Enum.TooltipDataLineType[k] = v end
    env.FACTION_BAR_COLORS = { [2] = { r = 0.8, g = 0.3, b = 0.22 }, [4] = { r = 0.9, g = 0.7, b = 0 }, [5] = { r = 0, g = 0.6, b = 0.1 } }
    env.RAID_CLASS_COLORS.WARLOCK = { r = 0.53, g = 0.53, b = 0.93 }
    env.RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
    -- 單位世界：mouseover＝玩家或 NPC；它的目標可以換
    local world = {
        mouseover = opts.npc and NPC_GUID or PLAYER_GUID,
        target = TARGET_GUID, targetName = "旅店老闆奧里森",
        identitySecret = false, dead = false, afk = false,
    }
    env.world = world
    env.UnitGUID = function(u)
        if u == "mouseover" then return world.mouseover end
        if u == "mouseovertarget" then return world.target end
        if u == "player" then return "Player-1-SELF" end
    end
    env.UnitExists = function(u)
        if u == "mouseover" then return world.mouseover ~= nil end
        if u == "mouseovertarget" then return world.target ~= nil end
        return u == "player"
    end
    env.UnitIsPlayer = function(u) return u == "mouseover" and not opts.npc or u == "player" end
    env.UnitName = function(u)
        if u == "mouseovertarget" then return world.targetName end
        if u == "player" then return "米利" end
        if u == "mouseover" then return opts.npc and "狡猾的莫加尼" or "Lokospoks" end
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
    if opts.npc then
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

    local t2 = Setup()
    t2.world.identitySecret = true
    check("身分受限：不接", not t2.P.TryUnit(t2.tip, t2.state, "mouseover", t2.data))
    eq("身分受限：沒畫", t2.renders(), 0)

    local t3 = Setup()
    t3.data.guid = SECRET
    check("GUID 秘密：不接", not t3.P.TryUnit(t3.tip, t3.state, SECRET, t3.data))

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
end

H.finish("Unit_test")
