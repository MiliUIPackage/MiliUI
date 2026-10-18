------------------------------------------------------------
-- 真實資料（/mtip record，zhTW 12.1.5）跑 reader＋view＋render 的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/RealData_test.lua
--
-- fixtures/real_zhTW.lua：每筆的 data 是 post-call 拿到的 TooltipData、lines 是當下的 FontString；
-- lineIndex 不在 data 裡的 FontString 就是別家後加的。_G 用 fixtures/GlobalStrings.lua 的 zhTW。
--
-- 通則（每筆都跑）：**不丟行**——data 與後加行的每一段非空文字（去色碼、去空白）都要在 model 某個欄位找得到；
-- 售價進 model.price；比價框有標籤；view 畫得出來。
-- 逐筆（record 編號＝fixture 的 source）：#39 護手、#17 雙手斧、#19 盾、#38 戒指、#1 消耗品、#60／#56／#55／#53／#59 法術。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq
local GS = dofile(here .. "/fixtures/GlobalStrings.lua")
local FX = dofile(here .. "/fixtures/real_zhTW.lua")
local FX2 = dofile(here .. "/fixtures/real_zhTW_2.lua")      -- 第二批：同一件多個版本、天賦面板、雕紋段、專業技能

local function Load()
    local env = H.Env(GS.zhTW)
    env.PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, HOLY_POWER = { r = 0.95, g = 0.9, b = 0.6 } }
    env.C_Spell = { GetSpellTexture = function(id) return 1000 + id end }
    env.C_Item = { GetItemIconByID = function(x) return type(x) == "number" and 5000 + x or 7777 end,
        GetItemCount = function() return 0 end }
    env.C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
    env.UnitLevel = function() return 90 end
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", Font = function() return "default.ttf" end, BarTexture = function() return "satin.png" end },
        playerClass = "PALADIN",
        db = { general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
            borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 } },
            item = { panel = true }, spell = { panel = true },
            panel = { separators = true, strip = true, statMarkers = true, levelBadge = true, numberColor = "class",
                extrasBox = true } },
        Skin = { State = {}, Poll = function() end, Unpoll = function() end, Each = function() end },
    }
    env.RAID_CLASS_COLORS.PALADIN = { r = 0.96, g = 0.55, b = 0.73 }
    for _, f in ipairs({ "Libs/MiliUIWidgets/Secret.lua", "Panel/Patterns.lua", "Panel/Frame.lua", "Panel/Render.lua",
        "Panel/Native.lua", "Panel/ReadFallback.lua", "Panel/Try.lua", "Panel/ReadSpell.lua", "Panel/ViewSpell.lua",
        "Panel/ReadItem.lua", "Panel/ViewItem.lua" }) do
        H.Load(env, ns, f)
    end
    return env, ns
end

-- 照 fixture 的 lines 建 tooltip 的 FontString
local function TipFor(env, entry)
    local tip = H.Tip(env, entry.tip, {})
    tip.lines = {}
    for i, l in ipairs(entry.lines) do
        tip.lines[i] = true
        local function region(side)
            local r = H.Region("FontString", tip)
            r.size = 12
            local src = l[side] or {}
            r.text = src.text
            local c = src.color or { 1, 1, 1 }
            r.textColor = { c[1] or 1, c[2] or 1, c[3] or 1 }
            r.shown = src.shown ~= false and (side == "left" or (src.text ~= nil and src.text ~= ""))
            if side == "right" and src.shown ~= nil then r.shown = src.shown end
            return r
        end
        env[entry.tip .. "TextLeft" .. i] = region("left")
        env[entry.tip .. "TextRight" .. i] = region("right")
    end
    return tip
end

local env, ns = Load()
local P = ns.Panel

local function N(s)
    if type(s) ~= "string" then return "" end
    -- 去色碼、去行內圖示（我們在名字前加的 |T…|t、行尾的品質圖示都是另外畫的）
    s = P.Trim(ns.Patterns.StripTextures(ns.Patterns.StripColors((s:gsub("\r", "")))))
    return s
end

-- model 裡所有字串（遞迴；顏色表是數字不影響）
local function Strings(t, out, seen)
    out, seen = out or {}, seen or {}
    if seen[t] then return out end
    seen[t] = true
    for k, v in pairs(t) do
        if type(v) == "string" then
            local n = N(v)
            if n ~= "" then out[#out + 1] = n end
        elseif type(v) == "table" and k ~= "rows" then
            Strings(v, out, seen)
        end
    end
    return out
end

local function Found(strings, line)
    for _, c in ipairs(strings) do
        if c == line or c:find(line, 1, true) then return true end
        if #c >= #line * 0.4 and line:find(c, 1, true) then return true end
    end
    return false
end

local BY, BY2 = {}, {}
local results = {}

local function RunFixture(FXlist, by, label)
for _, entry in ipairs(FXlist) do
    local tag = ("%s#%s %s "):format(label, tostring(entry.source), tostring(entry.data.lines[1].leftText))
    local tip = TipFor(env, entry)
    local model = P.readers[entry.kind](tip, entry.data)
    check(tag .. "reader 有結果", model ~= nil)
    if model then
        by[entry.source] = model
        results[#results + 1] = { entry = entry, model = model, tip = tip }
        local strings = Strings(model)
        -- data 行
        local covered = {}
        for _, line in ipairs(entry.data.lines) do
            if line.lineIndex then covered[line.lineIndex] = true end
            for _, field in ipairs({ "leftText", "rightText" }) do
                local text = N(line[field])
                if text ~= "" then check(tag .. "不丟行（data）：" .. text, Found(strings, text)) end
            end
            if line.price then eq(tag .. "售價", model.price, line.price) end
        end
        -- 後加的行
        for i, l in ipairs(entry.lines) do
            if not covered[i] then
                local left = N(l.left and l.left.text)
                if left ~= "" then check(tag .. "不丟行（後加）：" .. left, Found(strings, left)) end
                if l.right and l.right.shown then
                    local right = N(l.right.text)
                    if right ~= "" then check(tag .. "不丟行（後加右欄）：" .. right, Found(strings, right)) end
                end
            end
        end
        if entry.tip:find("ShoppingTooltip%d$") then
            eq(tag .. "比價框標籤", model.tag, GS.zhTW.CURRENTLY_EQUIPPED)
        end
        -- 畫得出來
        local state = {}
        local panel = P.Get(tip, state)
        local view = P.views[entry.kind](model, state)
        check(tag .. "畫得出來", P.RenderView(panel, tip, view, state))
    end
end

end
RunFixture(FX, BY, "")
RunFixture(FX2, BY2, "第二批")

------------------------------------------------------------
-- 逐筆
------------------------------------------------------------
local function StatBy(m, needle)
    for _, s in ipairs(m.stats) do if s.text:find(needle, 1, true) then return s end end
end

do -- #39 聖化烈焰護手
    local m = BY[39]
    eq("#39 力量＝主屬", StatBy(m, "力量") and StatBy(m, "力量").category, "primary")
    eq("#39 耐力＝主屬", StatBy(m, "耐力") and StatBy(m, "耐力").category, "primary")
    eq("#39 加速＝次屬", StatBy(m, "加速") and StatBy(m, "加速").category, "secondary")
    eq("#39 精通＝次屬", StatBy(m, "精通") and StatBy(m, "精通").category, "secondary")
    eq("#39 智力 disabled", StatBy(m, "智力") and StatBy(m, "智力").disabled, true)
    eq("#39 套裝 4/5", m.set and (m.set.owned .. "/" .. m.set.total), "4/5")
    eq("#39 套裝五件", m.set and #m.set.items, 5)
    local shoulder
    for _, it in ipairs(m.set and m.set.items or {}) do if it.text:find("肩鎧", 1, true) then shoulder = it end end
    eq("#39 肩鎧沒擁有", shoulder and shoulder.owned, false)
    eq("#39 其他四件擁有", (function() local n = 0 for _, it in ipairs(m.set.items) do if it.owned then n = n + 1 end end return n end)(), 4)
    eq("#39 加成兩條接到套裝", m.set and #m.set.bonuses, 2)
    eq("#39 耐久", m.durability and (m.durability.cur .. "/" .. m.durability.max), "55/55")
    eq("#39 售價", m.price, 295170)
    eq("#39 沒有東西掉進「其他」", #m.extras, 0)
    check("#39 塑形兩行在標題補充區", m.headerRows and #m.headerRows == 2 and m.headerRows[2].left == "璀璨光明使者護手")
end

do -- #17 『督軍之怒』馬茲羅亞（比價框）
    local m = BY[17]
    eq("#17 每秒傷害", m.weapon and m.weapon.dps and m.weapon.dps.value, "141.9")
    eq("#17 傷害下限", m.weapon and m.weapon.damage and m.weapon.damage.min, "332")
    eq("#17 傷害上限", m.weapon and m.weapon.damage and m.weapon.damage.max, "690")
    eq("#17 速度", m.weapon and m.weapon.speed and m.weapon.speed.value, "3.60")
    eq("#17 附魔＋油兩列", #m.enchants, 2)
    check("#17 油是臨時附魔", m.enchants[2] and m.enchants[2].left:find("鳳凰之油", 1, true))
    eq("#17 套裝 2/3", m.set and (m.set.owned .. "/" .. m.set.total), "2/3")
    local aman
    for _, it in ipairs(m.set and m.set.items or {}) do if it.text:find("阿曼穆索", 1, true) then aman = it end end
    eq("#17 阿曼穆索沒擁有", aman and aman.owned, false)
    eq("#17 唯一", m.unique[1], "僅可裝備一件")
    check("#17 提升等級", m.upgrade ~= nil)
    eq("#17 比價標籤", m.tag, GS.zhTW.CURRENTLY_EQUIPPED)
    eq("#17 標題補充一列（英雄難度）", m.headerRows and #m.headerRows, 1)
    eq("#17 沒有東西掉進「其他」", #m.extras, 0)
end

do -- #19 高貴決心壁壘（盾）
    local m = BY[19]
    eq("#19 護甲", m.armor and m.armor.value, "931")
    eq("#19 格擋", m.block and m.block.value, "2327")
    eq("#19 智力 disabled", StatBy(m, "智力") and StatBy(m, "智力").disabled, true)
    eq("#19 風味", #m.flavor, 1)
    eq("#19 標題補充兩列（難度＋虛無鍛造）", m.headerRows and #m.headerRows, 2)
    check("#19 標題補充保留原字串（含壞色碼）", m.headerRows and m.headerRows[1].left:find("|cFF 0FF 0", 1, true))
    eq("#19 沒有東西掉進「其他」", #m.extras, 0)
end

do -- #38 蟲群呼喚指環
    local m = BY[38]
    eq("#38 附魔一列", #m.enchants, 1)
    eq("#38 寶石一列", #m.sockets, 1)
    eq("#38 寶石圖示", m.sockets[1] and m.sockets[1].gemIcon, 7549137)
    local hint
    for _, d in ipairs(m.details) do if d.left:find("Shift", 1, true) then hint = d end end
    check("#38 插槽提示進細節（灰）", hint and hint.color[1] == 0.65)
    eq("#38 沒有東西掉進「其他」", #m.extras, 0)
end

do -- #1 血騎士精煉藥劑（消耗品）
    local m = BY[1]
    eq("#1 使用效果", m.effects[1] and m.effects[1].kind, "use")
    check("#1 使用效果去掉前綴", m.effects[1] and not m.effects[1].text:find("^使用"))
    check("#1 使用效果沒有 \\r", m.effects[1] and not m.effects[1].text:find("\r", 1, true))
    eq("#1 風味", #m.flavor, 1)
    check("#1 品質行", m.craftQuality ~= nil)
    eq("#1 售價", m.price, 468000)
    eq("#1 後加行全進附屬框", #m.extras, 0)
    check("#1 附屬框有東西", #m.appended > 0)
end

do -- 法術
    local m = BY[60]
    eq("#60 距離", m.range and m.range.text, "30碼距離")
    eq("#60 立即", m.cast and m.cast.text, "立即")
    eq("#60 冷卻精簡寫法", P.ShortTime(m.cooldown), "1分鐘")
    m = BY[56]
    eq("#56 聖能耗能", m.cost and m.cost.key, "HOLY_POWER_COST")
    eq("#56 聖能資源", m.cost and m.cost.power, "HOLY_POWER")
    eq("#56 立即", m.cast and m.cast.text, "立即")
    check("#56 描述沒有 \\r", not m.description[1]:find("\r", 1, true))
    m = BY[55]
    eq("#55 坐騎徽章兩個", #m.tags, 2)
    eq("#55 戰隊坐騎", m.tags[1] and m.tags[1][1], "戰隊坐騎")
    H.near("#55 戰隊坐騎保留原色", m.tags[1] and m.tags[1][2][2], 0.8, 1e-4)
    eq("#55 飛行", m.tags[2] and m.tags[2][1], "飛行")
    eq("#55 施法時間精簡", P.ShortTime(m.cast), "1.5秒")
    eq("#55 沒有東西掉進「其他」（同 lineIndex 的空行不重撿原生右欄）", #m.extras, 0)
    m = BY[53]
    eq("#53 名字", m.name, "奧流之術")
    eq("#53 冷卻 2 分鐘", P.ShortTime(m.cooldown), "2分鐘")
    m = BY[59]
    eq("#59 名字（同 lineIndex 的空行不影響）", m.name, "感應不死生物")
    for _, src in ipairs({ 53, 55, 56, 58, 59, 60 }) do
        eq("#" .. src .. " 法術沒有後加行", #BY[src].appended, 0)
    end
end

------------------------------------------------------------
-- 第二批逐筆
------------------------------------------------------------
do -- 天賦面板：名字與「等級|cffffffff1|r/1」是後加行、data 從第 3／4 行開始
    local m = BY2[26]
    eq("2#26 天賦：名字（去掉我們加的圖示）", m.name, "責難")
    eq("2#26 天賦：等級", m.talent and (m.talent.rank .. "/" .. m.talent.max), "1/1")
    eq("2#26 近戰範圍", m.range and m.range.key, "MELEE_RANGE")
    eq("2#26 冷卻 15 秒", P.ShortTime(m.cooldown), "15秒")
    local view = P.views.spell(m, {})
    local badgeLine = view.header[2] and P.BadgeText(view.header[2].badges) or ""
    check("2#26 等級進徽章列", badgeLine:find("等級1/1", 1, true), badgeLine)
    eq("2#26 天賦行沒有掉進附屬框", #m.appended, 0)
    m = BY2[28]
    eq("2#28 天賦被動：名字", m.name, "神聖之地")
    eq("2#28 被動", m.passive, "被動")
    eq("2#28 等級", m.talent and (m.talent.rank .. "/" .. m.talent.max), "1/1")
    view = P.views.spell(m, {})
    badgeLine = P.BadgeText(view.header[2].badges)
    check("2#28 徽章列：被動 · 等級", badgeLine:find("被動", 1, true) and badgeLine:find("等級1/1", 1, true), badgeLine)
    m = BY2[24]
    eq("2#24 退邪術：名字", m.name, "退邪術")
    eq("2#24 還沒學（0/1）", m.talent and m.talent.rank, 0)
    eq("2#24 耗能法力", m.cost and m.cost.power, "MANA")
    eq("2#24 施法時間精簡", P.ShortTime(m.cast), "1.3秒")
end

do -- 復仇之怒＋雕紋段
    local m = BY2[10]
    eq("2#10 主描述只有一段（雕紋說明沒併進來）", #m.description, 1)
    eq("2#10 雕紋段三行", m.tail and #m.tail, 3)
    eq("2#10 雕紋名保留原色", m.tail and m.tail[1].left, "復仇展翅雕紋")
    H.near("2#10 雕紋名的藍", m.tail and m.tail[1].color[1], 0.44, 0.01)
    eq("2#10 沒有東西掉進「其他」", #m.extras, 0)
end

do -- 鍊金術：描述裡的大寫色碼
    local m = BY2[29]
    local desc = m.description[1]
    check("2#29 描述帶大寫色碼", desc:find("|CFFFFFFFF", 1, true))
    local colored = ns.Patterns.ColorNumbers(desc, "ff0000")
    check("2#29 數字上色不碰大寫色碼", colored:find("|CFFFFFFFF特殊能力", 1, true), colored)
    check("2#29 去色碼認得大寫", not ns.Patterns.StripColors(desc):find("|C", 1, true))
end

do -- 同一件「精工製作之錘」三個版本：都讀得出、行數一版比一版多
    local a, b, c = BY2[53], BY2[54], BY2[55]
    eq("2#53 錘：名字", a.name, "精工製作之錘")
    eq("2#53 錘：標題補充行（房屋裝飾）", a.headerRows and #a.headerRows, 1)
    eq("2#53 錘：還沒有使用效果", #a.effects, 0)
    eq("2#54 錘：多了使用效果", #b.effects, 1)
    check("2#55 錘：按 Shift 的 ID 行進附屬框", #c.appended > #b.appended)
    eq("2#41 G91：等級需求", BY2[41].levelReq and BY2[41].levelReq.unmet, false)
    eq("2#42 G91：多了使用效果", #BY2[42].effects, 1)
    local helm = BY2[31]
    eq("2#31 戰盔：比價標籤", helm.tag, GS.zhTW.CURRENTLY_EQUIPPED)
    eq("2#31 戰盔：套裝 4/5", helm.set and (helm.set.owned .. "/" .. helm.set.total), "4/5")
end

H.finish("RealData_test")
