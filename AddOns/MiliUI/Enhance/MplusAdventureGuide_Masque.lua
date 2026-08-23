------------------------------------------------------------
-- MplusAdventureGuide 傳送門按鈕：支援 Masque 樣式
--
-- MplusAdventureGuide 在傳奇鑰石介面的每個地城圖示
-- （ChallengesFrame.DungeonIcons）上蓋一顆無名的
-- SecureActionButton 當傳送門，這裡把它們註冊進 Masque 群組
-- 「MplusAdventureGuide」讓玩家套用按鈕樣式。
--
-- 兩個關鍵：
-- 1. 該插件用 SetNormalTexture(法術圖示) 當按鈕圖示，但 Masque
--    的 Normal 區域是「外框」——所以自建一張 Icon 貼圖，掛勾
--    SetNormalTexture 把圖示轉進去；Normal 則預塞一張貼圖後交給
--    Masque 換膚（Action 型按鈕 Masque 會自己掛反制勾，之後插件
--    再寫入 Normal 都會被換回外框樣式）。
-- 2. 按鈕沒有名字，只能認結構：地城圖示的子框中「帶 Cooldown
--    子框的 Button」。兩邊都掛 ChallengesFrame.Update，MiliUI 的
--    勾排在前面，按鈕在同一次 Update 的後段才誕生，所以掃描要
--    延到下一幀。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local group          -- Masque 群組，第一次掃到按鈕時才建立
local done = false   -- 傳送門按鈕一次全建，成功換膚過就不用再掃
local pending = false

-- 從地城圖示的子框裡認出傳送門按鈕（Button＋Cooldown 子框）
local function GetPortalButton(icon)
    for _, child in ipairs({ icon:GetChildren() }) do
        if child:GetObjectType() == "Button" then
            for _, sub in ipairs({ child:GetChildren() }) do
                if sub:GetObjectType() == "Cooldown" then
                    return child, sub
                end
            end
        end
    end
end

local function SkinButton(button, cooldown)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(button)

    -- 先給 Normal 一張貼圖，Masque 換膚當下才有區域可接手
    button:SetNormalTexture([[Interface\Buttons\UI-Quickslot2]])

    -- 之後每次滑過，插件都會用 SetNormalTexture 換上法術圖示：
    -- 轉進 Icon 區域，Normal 讓 Masque 的反制勾換回外框
    hooksecurefunc(button, "SetNormalTexture", function(_, tex)
        if tex then
            icon:SetTexture(tex)
        end
    end)

    group:AddButton(button, {
        Icon = icon,
        Cooldown = cooldown,
    }, "Action")
end

local function Scan()
    pending = false
    if done or InCombatLockdown() then return end
    if not ChallengesFrame.DungeonIcons then return end

    for _, dungeonIcon in ipairs(ChallengesFrame.DungeonIcons) do
        local button, cooldown = GetPortalButton(dungeonIcon)
        if button then
            group = group or LibStub("Masque"):Group("MplusAdventureGuide")
            SkinButton(button, cooldown)
            done = true
        end
    end
end

EventUtil.ContinueOnAddOnLoaded("Blizzard_ChallengesUI", function()
    -- 缺任何一邊就安靜缺席
    if not C_AddOns.IsAddOnLoaded("MplusAdventureGuide") then return end
    if not (LibStub and LibStub:GetLibrary("Masque", true)) then return end

    hooksecurefunc(ChallengesFrame, "Update", function()
        if done or pending then return end
        pending = true
        RunNextFrame(Scan)
    end)
end)
