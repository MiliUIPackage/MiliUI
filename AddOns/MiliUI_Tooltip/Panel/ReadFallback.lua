------------------------------------------------------------
-- 讀行（所有 reader 共用）＋ 最簡 reader／view（型別不認得時的退路，永遠不會「少行」）
--
-- Panel.CollectLines(tip, data)
--   data.lines 逐行讀（型別、左右欄、顏色），**任何一項是秘密就整份回 nil** ⇒ 退回原生樣式。
--   再把 tooltip 上 lineIndex 不在 data 裡的 TextLeftN／TextRightN 全部撿回來（appended）——
--   那是別的插件（含我們自己的 ID 行）用 AddLine 加的，一行都不能丟。
--
-- 暴雪的 ProcessLineData 每加一行就把 lineIndex 寫回 lineData（TooltipDataHandler.lua），
-- 被 linePreCall 吃掉的行（售價的錢幣框）沒有 lineIndex。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Panel = ns.Panel
local Patterns = ns.Patterns
local LOOK = Panel.LOOK

local LT = Enum and Enum.TooltipDataLineType or {}

-- 顏色表 → 明文 { r, g, b }；nil 表示沒給；false 表示是秘密（呼叫端整份放棄）
local function PlainColor(c)
    if c == nil then return nil end
    if S.IsSecret(c) or type(c) ~= "table" then return false end
    local r, g, b = c.r, c.g, c.b
    if S.IsSecret(r) or S.IsSecret(g) or S.IsSecret(b) then return false end
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return nil end
    return { r, g, b }
end

local function PlainString(v)
    if v == nil then return nil end
    if S.IsSecret(v) then return false end
    if type(v) ~= "string" then return nil end
    return v
end

local function FontColor(fs)
    local ok, r, g, b = pcall(fs.GetTextColor, fs)
    if not ok then return nil end
    if S.IsSecret(r) or S.IsSecret(g) or S.IsSecret(b) then return false end
    if type(r) ~= "number" then return nil end
    return { r, g, b }
end

local function Shown(fs)
    local ok, v = pcall(fs.IsShown, fs)
    if not ok or S.IsSecret(v) then return nil end
    return v and true or false
end

-- data 行上除了文字與顏色，reader 還要用的純量欄位（秘密 ⇒ 整份放棄）
local EXTRA_FIELDS = { "tooltipID", "tooltipType", "usable", "gemIcon", "socketType", "price" }

-- 回 rows, numLines；讀不到回 nil
function Panel.CollectLines(tip, data)
    if type(data) ~= "table" or S.IsSecret(data) then return end
    local lines = data.lines
    if type(lines) ~= "table" or S.IsSecret(lines) then return end
    local okName, name = pcall(tip.GetName, tip)
    name = okName and S.PlainText(name)
    if not name then return end

    local rows, covered = {}, {}
    local rightSeen = {}       -- 這個 lineIndex 已經有某一行 data 給過右欄（實機：同 lineIndex 的空行會重複出現）
    for _, line in ipairs(lines) do
        if type(line) ~= "table" or S.IsSecret(line) then return end
        local left, right = PlainString(line.leftText), PlainString(line.rightText)
        local lineType, index = line.type, line.lineIndex
        if left == false or right == false or S.IsSecret(lineType) or S.IsSecret(index) then return end
        local lc, rc = PlainColor(line.leftColor), PlainColor(line.rightColor)
        if lc == false or rc == false then return end
        local wrap = line.wrapText
        if S.IsSecret(wrap) then return end
        if type(index) == "number" then covered[index] = true end
        local row = {
            left = left or "",
            right = (right and right ~= "") and right or nil,
            color = lc, rightColor = rc,
            type = lineType, lineIndex = index,
            wrap = wrap == true,
        }
        for _, field in ipairs(EXTRA_FIELDS) do
            local v = line[field]
            if S.IsSecret(v) then return end
            local t = type(v)
            if t == "number" or t == "string" or t == "boolean" then row[field] = v end
        end
        -- 右欄可能只寫在原生的 FontString 上、data 裡是空的（法術的冷卻排在施法時間旁邊）
        if row.right and type(index) == "number" then rightSeen[index] = true end
        if not row.right and type(index) == "number" and not rightSeen[index] then
            local rf = _G[name .. "TextRight" .. index]
            if rf and Shown(rf) then
                local ok, text = pcall(rf.GetText, rf)
                if not ok then return end
                local plain = PlainString(text)
                if plain == false then return end
                if plain and plain ~= "" then
                    local rcolor = FontColor(rf)
                    if rcolor == false then return end
                    row.right, row.rightColor = plain, row.rightColor or rcolor
                    rightSeen[index] = true
                end
            end
        end
        rows[#rows + 1] = row
    end

    local okN, n = pcall(tip.NumLines, tip)
    n = okN and S.PlainNumber(n)
    if not n then return end
    for i = 1, n do
        if not covered[i] then
            local lf, rf = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
            local left, right, lc, rc
            if lf and Shown(lf) ~= false then
                local ok, text = pcall(lf.GetText, lf)
                if not ok then return end
                left = PlainString(text)
                if left == false then return end
                lc = FontColor(lf)
                if lc == false then return end
            end
            -- 右欄的 FontString 沒用到時是藏起來的，但可能還留著上一份提示的字
            if rf and Shown(rf) then
                local ok, text = pcall(rf.GetText, rf)
                if not ok then return end
                right = PlainString(text)
                if right == false then return end
                rc = FontColor(rf)
                if rc == false then return end
            end
            if (left and left ~= "") or (right and right ~= "") then
                rows[#rows + 1] = {
                    left = left or "", right = (right and right ~= "") and right or nil,
                    color = lc, rightColor = rc,
                    lineIndex = i, appended = true, wrap = true,
                }
            end
        end
    end
    return rows, n
end

------------------------------------------------------------
-- 售價：錢幣字串（暴雪是另外畫一個錢幣框，不是文字）
------------------------------------------------------------
function Panel.Coins(copper)
    copper = S.PlainNumber(copper)
    if not copper then return end
    local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or _G.GetCoinTextureString
    if not fn then return end
    local ok, text = pcall(fn, copper)
    return ok and S.PlainText(text) or nil
end

------------------------------------------------------------
-- 最簡 reader：第一行當名字、其餘照原樣分段（Blank／Separator 切段），別人加的行放最後
------------------------------------------------------------
local function IsBreak(row)
    if row.type ~= nil and (row.type == LT.Blank or row.type == LT.Separator) then return true end
    local plain = Patterns.StripColors(row.left or "")
    return (plain == "" or plain:match("^%s+$") ~= nil) and not row.right
end

function Panel.ReadFallback(tip, data, kind, rows, n)
    if not rows then rows, n = Panel.CollectLines(tip, data) end
    if not rows then return end
    local model = { kind = kind, groups = {}, extras = {}, numLines = n, rows = rows }

    local first
    local group = {}
    for _, row in ipairs(rows) do
        if not first and not row.appended and not IsBreak(row)
            and not (_G.CURRENTLY_EQUIPPED and row.left == _G.CURRENTLY_EQUIPPED) then
            first = row
        elseif row.appended then
            if not IsBreak(row) then model.extras[#model.extras + 1] = row end
        elseif IsBreak(row) then
            if #group > 0 then
                model.groups[#model.groups + 1] = group
                group = {}
            end
        elseif not (_G.CURRENTLY_EQUIPPED and row.left == _G.CURRENTLY_EQUIPPED) then
            if row.price then
                local coins = Panel.Coins(row.price)
                if coins then row = { left = row.left, right = coins, color = row.color } end
            end
            group[#group + 1] = row
        end
    end
    if #group > 0 then model.groups[#model.groups + 1] = group end
    if not first then return end

    local name = Patterns.StripTextures(first.left or "")
    if name == "" then return end
    model.name = name
    model.nameColor = first.color
    model.subtitle = first.right

    -- 圖示（拿不到就沒有，不影響其他）
    local id = S.PlainNumber(data.id)
    if id then
        if kind == "item" and C_Item and C_Item.GetItemIconByID then
            local ok, icon = pcall(C_Item.GetItemIconByID, id)
            model.icon = ok and S.PlainNumber(icon) or nil
        elseif kind == "spell" and C_Spell and C_Spell.GetSpellTexture then
            local ok, icon = pcall(C_Spell.GetSpellTexture, id)
            model.icon = ok and S.PlainNumber(icon) or nil
        end
    end

    local okName, tipName = pcall(tip.GetName, tip)
    tipName = okName and S.PlainText(tipName)
    model.isComparison = tipName and tipName:find("ShoppingTooltip%d$") ~= nil or false
    return model
end

function Panel.ViewFallback(model)
    local view = {
        icon = model.icon,
        iconSize = model.kind == "spell" and LOOK.ICON_SPELL or LOOK.ICON_ITEM,
        header = { { text = model.name, style = "title", color = model.nameColor or LOOK.TEXT } },
        sections = {},
        tag = model.isComparison and _G.CURRENTLY_EQUIPPED or nil,
    }
    if model.subtitle then
        view.header[2] = { badges = { { model.subtitle } }, style = "small" }
    end
    for i, group in ipairs(model.groups) do
        view.sections[#view.sections + 1] = {
            separator = (i > 1) and { rule = true } or nil,
            kind = "rows", rows = group, wrap = true, color = LOOK.TEXT,
        }
    end
    -- 最簡 reader 的 extras 就是後加的行 ⇒ 附屬框
    view.extras = { rows = model.extras }
    return view
end
