------------------------------------------------------------
-- tooltip 字型：寫全域字型物件（接觸面清單第 7 條）
--
-- GameTooltipHeaderText / GameTooltipText / Tooltip_Small 是所有 tooltip 共用的
-- 字型物件，改字型只有這一條路（業界標準做法）。一次性 + 設定變更時寫入，
-- 不在任何顯示路徑上重複寫。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

ns.Fonts = {}
local Fonts = ns.Fonts

-- 載入時記下暴雪預設，"default" 就還原成這組
local defHeaderFont, defHeaderSize, defHeaderFlag = GameTooltipHeaderText:GetFont()
local defBodyFont, defBodySize, defBodyFlag = GameTooltipText:GetFont()

-- SetFont 第三參數只吃特定 flag；"NORMAL" 不合法，"default" 還原預設
local function NormalizeFlag(flag, defaultFlag)
    if type(flag) ~= "string" or flag == "" then return defaultFlag end
    if flag == "default" then return defaultFlag end
    if flag == "NORMAL" then return "" end
    return flag
end

function Fonts.Apply()
    if not ns.db then return end
    local g = ns.db.general

    local headerFont = (g.headerFont == "default") and defHeaderFont or Media.Font(g.headerFont)
    local headerSize = (tonumber(g.headerFontSize) or 0) > 0 and g.headerFontSize or defHeaderSize
    GameTooltipHeaderText:SetFont(headerFont, headerSize, NormalizeFlag(g.headerFontFlag, defHeaderFlag))
    GameTooltipHeaderText:SetShadowOffset(1, -1)
    GameTooltipHeaderText:SetShadowColor(0, 0, 0, 0.9)

    local bodyFont = (g.bodyFont == "default") and defBodyFont or Media.Font(g.bodyFont)
    local bodySize = (tonumber(g.bodyFontSize) or 0) > 0 and g.bodyFontSize or defBodySize
    GameTooltipText:SetFont(bodyFont, bodySize, NormalizeFlag(g.bodyFontFlag, defBodyFlag))
    GameTooltipText:SetShadowOffset(1, -1)
    GameTooltipText:SetShadowColor(0, 0, 0, 0.9)

    if Tooltip_Small then
        Tooltip_Small:SetShadowOffset(1, -1)
        Tooltip_Small:SetShadowColor(0, 0, 0, 0.9)
    end
end
