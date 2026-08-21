---------------------------------------------------------------
-- MiliUI Fix: ParagonReputation 巔峰列 HideTooltip forbidden
-- Author: Mili
--
-- 症狀：滑過聲望面板的巔峰聲望列再移開，洗版
--   Blizzard_UIPanels_Game/Mainline/ReputationFrame.lua:405:
--   Attempt to access forbidden object from code tainted by an AddOn
--
-- 成因（暴雪原始碼行號）：
--   393 ReputationEntryMixin:OnLeave()
--   394   self.Content.ReputationBar:TryShowReputationStandingText()
--           → 讀 reputationStandingText / barProgressText，這兩個欄位被
--             ParagonReputation 直接寫過（core.lua 的 UpdateBar），是髒的
--             → 從這裡開始整段 OnLeave 都在污染狀態下執行
--   398   self:HideTooltip()
--   405     elseif EmbeddedItemTooltip:GetOwner() == self then   ← 拋錯
--
--   12.1 之後 EmbeddedItemTooltip 對被污染的執行路徑是 forbidden object，
--   連 GetOwner() 都不能呼叫。錯誤發生在暴雪自己的函式裡，插件端擋不住；
--   而且 hooksecurefunc 的後掛勾在原函式拋錯後不會執行，所以 ParagonReputation
--   自建的 ParagonEmbeddedItemTooltip 也跟著關不掉（滑鼠移開後浮窗卡在畫面上）。
--
-- 修法：巔峰列的 HideTooltip 直接換成安全版本（那一列本來就已經被污染，
--   換函式不會讓情況更糟；這也是 ParagonReputation 自己對
--   ShowParagonRewardsTooltip 用的手法）。安全版本同時做兩件事：
--     1. 暴雪原本的行為，但碰 tooltip 前先問 IsForbidden
--     2. ParagonReputation 後掛勾原本要做的：關掉它自建的 tooltip
--   只處理巔峰列——普通聲望列沒有被污染，不要多碰。
---------------------------------------------------------------

local function IsForbiddenObject(obj)
    return (obj and obj.IsForbidden and obj:IsForbidden()) and true or false
end

-- 對應 ReputationFrame.lua 的 ReputationEntryMixin:HideTooltip()
local function SafeHideTooltip(self)
    if not IsForbiddenObject(GameTooltip) and GameTooltip:GetOwner() == self then
        GameTooltip_Hide()
    elseif not IsForbiddenObject(EmbeddedItemTooltip) and EmbeddedItemTooltip:GetOwner() == self then
        EmbeddedItemTooltip_Hide(EmbeddedItemTooltip)
    end
    -- ParagonReputation core.lua 的 HideTooltip 後掛勾
    local paragonTip = ParagonEmbeddedItemTooltip
    if paragonTip and not IsForbiddenObject(paragonTip) and paragonTip:GetOwner() == self then
        paragonTip:Hide()
    end
end

local function EnsureSafeHideTooltip(row)
    if not row or row.MiliUI_SafeHideTooltip then return end
    if type(row.HideTooltip) ~= "function" then return end
    local factionID = row.factionID
    if not factionID or not C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then return end
    row.HideTooltip = SafeHideTooltip
    row.MiliUI_SafeHideTooltip = true
end

local function SweepExistingRows()
    local scrollBox = ReputationFrame and ReputationFrame.ScrollBox
    local scrollTarget = scrollBox and scrollBox.ScrollTarget
    if not scrollTarget then return end
    for _, row in ipairs({scrollTarget:GetChildren()}) do
        EnsureSafeHideTooltip(row)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not C_AddOns.IsAddOnLoaded("ParagonReputation") then return end
    if not ReputationEntryMixin then return end

    -- 列是 XML mixin="ReputationEntryMixin"，方法在建立當下就複製到框架上，
    -- 所以掛 mixin 只對「之後才建立」的列有效；已存在的列另外掃一次。
    hooksecurefunc(ReputationEntryMixin, "Initialize", EnsureSafeHideTooltip)
    if ReputationFrame then
        ReputationFrame:HookScript("OnShow", SweepExistingRows)
    end
    SweepExistingRows()
end)
