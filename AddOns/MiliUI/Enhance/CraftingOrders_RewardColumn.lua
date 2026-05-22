--------------------------------------------------------------------------------
-- CraftingOrders_RewardColumn
-- 在「製作訂單」(顧客分頁) 的訂單列表新增一個獨立的「獎勵」欄位，顯示 NPC
-- 訂單的獎勵物品圖示。欄位標題不可排序 (用 AddUnsortableFixedWidthColumn)。
--
-- 流程：
--   1. 定義繼承 TableBuilderCellMixin 的 cell mixin，Populate() 從
--      rowData.option.npcOrderRewards 讀獎勵並設定圖示。
--   2. hook ProfessionsCraftingOrderPageMixin:SetupTable，在原欄位之後追加
--      我們的欄位，並重跑 Arrange() 重新排版。
--   3. 只在 Flat browse 模式 (顧客 / 公開 / 個人) 加入；Bucketed 模式
--      (按配方聚合) 沒有單筆訂單概念，會跳過。
--------------------------------------------------------------------------------

local MAX_ICONS    = 4
local ICON_SIZE    = 20
local ICON_SPACING = 2
local COLUMN_WIDTH = (ICON_SIZE * MAX_ICONS) + (ICON_SPACING * (MAX_ICONS - 1)) + 6

-- Blizzard 在 Blizzard_ProfessionsCrafterOrderPage.lua 把 OrderBrowseType 定義為
-- file-local，所以這裡用同樣的 EnumUtil 重建一份以便比對 GetBrowseType() 的回傳。
local OrderBrowseType = EnumUtil.MakeEnum("Flat", "Bucketed", "None")

--------------------------------------------------------------------------------
-- 圖示按鈕 tooltip
--------------------------------------------------------------------------------
local function OnIconEnter(self)
    if self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    elseif self.currencyType then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyByID(self.currencyType)
        GameTooltip:Show()
    end
end

local function OnIconLeave()
    GameTooltip:Hide()
end

local function ResolveReward(reward)
    if reward.itemLink then
        local itemID = C_Item.GetItemInfoInstant(reward.itemLink)
        if itemID then
            return C_Item.GetItemIconByID(itemID), reward.itemLink, nil
        end
    elseif reward.currencyType then
        local info = C_CurrencyInfo.GetCurrencyInfo(reward.currencyType)
        if info then
            return info.iconFileID, nil, reward.currencyType
        end
    end
end

--------------------------------------------------------------------------------
-- Cell mixin (由 XML template 的 mixin 屬性自動套用到每個 cell frame)
--------------------------------------------------------------------------------
MiliUICrafterTableCellRewardsMixin = CreateFromMixins(TableBuilderCellMixin)

function MiliUICrafterTableCellRewardsMixin:CreateIconsIfNeeded()
    if self.icons then return end
    self.icons = {}
    for i = 1, MAX_ICONS do
        local btn = CreateFrame("Button", nil, self)
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        -- 點擊穿透回訂單列，保留原本「點擊 = 查看訂單」行為
        if btn.SetPassThroughButtons then
            btn:SetPassThroughButtons("LeftButton", "RightButton")
        end

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.texture = tex

        local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, 1)
        btn.count = count

        if i == 1 then
            btn:SetPoint("LEFT", self, "LEFT", 2, 0)
        else
            btn:SetPoint("LEFT", self.icons[i - 1], "RIGHT", ICON_SPACING, 0)
        end

        btn:SetScript("OnEnter", OnIconEnter)
        btn:SetScript("OnLeave", OnIconLeave)
        btn:Hide()
        self.icons[i] = btn
    end
end

function MiliUICrafterTableCellRewardsMixin:Populate(rowData, dataIndex)
    self:CreateIconsIfNeeded()

    local order = rowData and (rowData.option or rowData)
    local rewards = order and order.npcOrderRewards

    if not rewards or #rewards == 0 then
        for _, btn in ipairs(self.icons) do btn:Hide() end
        return
    end

    for i, btn in ipairs(self.icons) do
        local r = rewards[i]
        if r then
            local icon, link, curr = ResolveReward(r)
            if icon then
                btn.texture:SetTexture(icon)
                btn.itemLink = link
                btn.currencyType = curr
                if r.count and r.count > 1 then
                    btn.count:SetText(r.count)
                    btn.count:Show()
                else
                    btn.count:Hide()
                end
                btn:Show()
            else
                btn:Hide()
            end
        else
            btn:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Hook SetupTable 追加欄位
--------------------------------------------------------------------------------
local hooked = false
local function TryHook()
    if hooked then return end
    -- Mixin() 是把方法複製到 instance 上，所以一定要 hook 在 instance 而不是 mixin table。
    local ordersPage = ProfessionsFrame and ProfessionsFrame.OrdersPage
    if not ordersPage or not ordersPage.SetupTable then return end

    hooksecurefunc(ordersPage, "SetupTable", function(self)
        if self:GetBrowseType() ~= OrderBrowseType.Flat then return end

        local PTC = ProfessionsTableConstants
        self.tableBuilder:AddUnsortableFixedWidthColumn(
            self,
            PTC.NoPadding,
            COLUMN_WIDTH,
            PTC.NoPadding,
            PTC.NoPadding,
            "獎勵",
            "MiliUICrafterTableCellRewardsTemplate"
        )
        self.tableBuilder:Arrange()
    end)

    -- 若插件載入時訂單頁已開啟過，重跑一次 SetupTable 讓我們的欄位現身
    if ordersPage.tableBuilder then
        ordersPage:SetupTable()
    end

    hooked = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Blizzard_Professions" then
        TryHook()
        f:UnregisterEvent("ADDON_LOADED")
    end
end)

if C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
    TryHook()
end
