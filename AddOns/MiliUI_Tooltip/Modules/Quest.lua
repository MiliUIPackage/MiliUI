------------------------------------------------------------
-- 任務：ItemRef 的任務連結按等差染邊框、任務日誌顯示任務 ID
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Skin = ns.Skin
local Item = ns.Item

-- 聊天視窗點任務連結 → ItemRefTooltip 邊框按等差上色
hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
    if not ns.db or not ns.db.quest.coloredQuestBorder then return end
    if not Skin.Get(self) then return end
    if type(link) ~= "string" then return end
    local schema, id = string.match(link, "|?H?(%a+):(%d+)")
    if schema ~= "quest" then return end
    local level = S.PlainNumber(S.SafeCall(C_QuestLog.GetQuestDifficultyLevel, tonumber(id)))
    if not level then return end
    local color = GetQuestDifficultyColor(level < 0 and (UnitLevel("player") or 80) or level)
    if color then
        Skin.SetBorderColor(self, color.r, color.g, color.b, 1)
    end
end)

-- 任務日誌滑過任務 → 顯示任務 ID
if QuestMapLogTitleButton_OnEnter then
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(self)
        if not ns.db or ns.db.quest.showQuestId == false then return end
        if self.questID then
            Item.AddIdLine(GameTooltip, L["Quest ID"], self.questID, false)
            if not S.IsForbiddenObject(GameTooltip) and GameTooltip:IsShown() then
                GameTooltip:Show()
            end
        end
    end)
end
