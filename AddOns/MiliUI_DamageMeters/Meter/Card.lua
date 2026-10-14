------------------------------------------------------------
-- 頭像卡片：滑過預覽與展開頁的標題共用
--
--   [大圖示]  名字（職業色）
--             專精 職業  ·  裝等 639（灰字）
--
-- 圖示跟長條用同一個樣式設定（米利／專精／職業／無），高度＝兩行字。
-- 裝等第一次沒有就排觀察，回來時卡片自己重填（IL.Listen）。
--
-- 右側兩格 card.right1／card.right2 各跟一行對齊，由宿主填（預覽：統計類型；
-- 展開頁：總量／返回提示）。名字只讓位給 right1、第二行只讓位給 right2 ——
-- 早期右側只有一格、兩行都讓位給它時，展開頁的總量很長，名字與專精被擠成「米利丹…」。
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

    card.right1 = card:CreateFontString(nil, "OVERLAY")
    card.right1:SetJustifyH("RIGHT")
    card.right1:SetWordWrap(false)
    card.right2 = card:CreateFontString(nil, "OVERLAY")
    card.right2:SetJustifyH("RIGHT")
    card.right2:SetWordWrap(false)

    IL.Listen(card, function(guid)
        if card._guid == guid and card:IsVisible() and card._src then
            Card.Fill(card, card._src)
        end
    end)
    return card
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

local RIGHT_GAP = 8

local function Anchor(card, hasIcon)
    local left = hasIcon and (card._size + ICON_GAP) or 0
    local nameH = select(2, card.name:GetFont()) or 0
    local subH = select(2, card.sub:GetFont()) or 0
    -- 兩行字整組在圖示高度內垂直置中；右側兩格各自用同一個 y，對齊所在的那一行
    local top = math.max(0, (card._size - nameH - subH - LINE_GAP) / 2)
    local top2 = top + nameH + LINE_GAP
    for _, fs in ipairs({ card.name, card.sub, card.right1, card.right2 }) do fs:ClearAllPoints() end
    card.right1:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -top)
    card.right2:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -top2)
    card.name:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top)
    card.name:SetPoint("RIGHT", card.right1, "LEFT", -RIGHT_GAP, 0)
    card.sub:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top2)
    card.sub:SetPoint("RIGHT", card.right2, "LEFT", -RIGHT_GAP, 0)
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
    local info = D.SourceSpec(src)
    local text = info and info.name and (info.name .. " " .. className) or className
    local lvl = IL.Get(src.guid, src.isOwn)
    if lvl then
        text = text .. "  ·  " .. format(L["iLvl %d"], lvl)
    elseif not src.isOwn then
        IL.Request(src.guid)
    end
    card.sub:SetText(text)
end
