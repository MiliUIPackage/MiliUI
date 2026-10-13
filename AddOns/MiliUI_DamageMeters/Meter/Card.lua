------------------------------------------------------------
-- 頭像卡片：滑過預覽與展開頁的標題共用
--
--   [大圖示]  名字（職業色）
--             專精 職業  ·  裝等 639（灰字）
--
-- 圖示跟長條用同一個樣式設定（米利／專精／職業／無），高度＝兩行字。
-- 裝等第一次沒有就排觀察，回來時卡片自己重填（IL.Listen）。
--
-- 兩個宿主的右側各有自己的東西（預覽是統計類型、展開頁是總量＋返回提示），
-- 所以名字與第二行的右緣交給呼叫端錨：Card.ClipRight(card, region)。
------------------------------------------------------------
local _, ns = ...

ns.Card = {}
local Card = ns.Card
local D = ns.Data
local M = ns.Media
local IL = ns.ItemLevel
local Win = ns.Window
local L = ns.L

local LINE_GAP = 2
local ICON_GAP = 6

function Card.Create(parent)
    local card = CreateFrame("Frame", nil, parent)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)

    card.name = card:CreateFontString(nil, "OVERLAY")
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)

    card.sub = card:CreateFontString(nil, "OVERLAY")
    card.sub:SetJustifyH("LEFT")
    card.sub:SetWordWrap(false)
    card.sub:SetTextColor(0.62, 0.62, 0.62)

    IL.Listen(card, function(guid)
        if card._guid == guid and card:IsVisible() and card._src then
            Card.Fill(card, card._src)
        end
    end)
    return card
end

-- 名字與第二行的右緣錨到 region 的左緣（region 為 nil ＝ 卡片右緣）
function Card.ClipRight(card, region, gap)
    card._clip, card._clipGap = region, gap or 8
end

-- 依字級排版，回傳卡片高度
function Card.Layout(card)
    local s = ns.DB.Style()
    local nameSize = s.leftFontSize or 11
    local subSize = math.max(8, nameSize - 2)
    Win.SetFont(card.name, nameSize)
    Win.SetFont(card.sub, subSize)
    local h = math.max(26, nameSize + subSize + LINE_GAP + 8)
    card._size = h
    card:SetHeight(h)
    card.icon:SetSize(h, h)
    return h
end

local function Anchor(card, hasIcon)
    local left = hasIcon and (card._size + ICON_GAP) or 0
    local clip, gap = card._clip, card._clipGap or 8
    local nameH = select(2, card.name:GetFont()) or 0
    local subH = select(2, card.sub:GetFont()) or 0
    -- 兩行字整組在圖示高度內垂直置中
    local top = math.max(0, (card._size - nameH - subH - LINE_GAP) / 2)
    card.name:ClearAllPoints()
    card.sub:ClearAllPoints()
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top)
    card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -LINE_GAP)
    if clip then
        card.name:SetPoint("RIGHT", clip, "LEFT", -gap, 0)
        card.sub:SetPoint("RIGHT", clip, "LEFT", -gap, 0)
    else
        card.name:SetPoint("RIGHT", card, "RIGHT", 0, 0)
        card.sub:SetPoint("RIGHT", card, "RIGHT", 0, 0)
    end
end

-- src = { name, classFilename, specIconID, guid, isOwn }
function Card.Fill(card, src)
    card._src = src
    card._guid = D.PlainGUID(src.guid)
    if not card._size then Card.Layout(card) end
    local s = ns.DB.Style()

    local shown = D.ResolveIcon(src, card.icon, card._size, s.iconStyle or "mili", s.iconZoom) > 0
    Anchor(card, shown)

    local r, g, b = M.ClassColor(src.classFilename)
    card.name:SetTextColor(r or 1, g or 1, b or 1)
    -- 名字可能是秘密：FontString 顯示得出來，不要拿去串接
    card.name:SetText(D.StripRealm(src.name))

    -- 第二行：專精 職業 · 裝等。NPC／拿不到職業就整行留白。
    local classFile = D.SafeClass(src.classFilename)
    if not classFile then card.sub:SetText(""); return end
    local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile
    local info = D.SpecInfo(src.specIconID)
    local text = info and info.name and (info.name .. " " .. className) or className
    local lvl = IL.Get(src.guid, src.isOwn)
    if lvl then
        text = text .. "  ·  " .. format(L["iLvl %d"], lvl)
    elseif not src.isOwn then
        IL.Request(src.guid)
    end
    card.sub:SetText(text)
end
