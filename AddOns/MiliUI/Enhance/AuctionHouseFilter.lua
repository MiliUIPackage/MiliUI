--------------------------------------------------------------------------------
-- AuctionHouseFilter
-- 在拍賣行底部標籤列最右側放置「僅限當前資料片」按鈕。
-- 點擊切換篩選狀態，不影響其他標籤切換。
-- 受 MiliUI 設定面板的「拍賣行」開關控制。
--
-- 智慧判斷：
--   只在使用者主動搜尋/瀏覽時注入篩選（透過 AuctionHouseFrame 的方法），
--   Auctionator 等插件直接呼叫 C_AuctionHouse.SendBrowseQuery 的掃描
--   不會被影響。
--------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    -- 初始化 SavedVariables
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.ahFeatureEnabled == nil then
        MiliUI_DB.ahFeatureEnabled = true
    end
    if MiliUI_DB.ahAutoCurrentExpansion == nil then
        MiliUI_DB.ahAutoCurrentExpansion = true
    end

    --------------------------------------------------------------------------
    -- 建立篩選按鈕（不用 PanelTabButtonTemplate，避免破壞標籤系統）
    --------------------------------------------------------------------------
    local btn = CreateFrame("Button", "MiliUI_AHFilterBtn", AuctionHouseFrame, "BackdropTemplate")
    btn:SetSize(130, 28)

    -- 文字
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnText:SetPoint("CENTER", 0, 1)

    -- 背景
    btn:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

    local function UpdateAppearance()
        if MiliUI_DB.ahAutoCurrentExpansion then
            btnText:SetText("|cffffd200僅限當前資料片|r")
            btn:SetBackdropColor(0.15, 0.12, 0.05, 0.95)
            btn:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.9)
        else
            btnText:SetText("|cff999999所有資料片|r")
            btn:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
        end
    end

    btn:SetScript("OnClick", function()
        MiliUI_DB.ahAutoCurrentExpansion = not MiliUI_DB.ahAutoCurrentExpansion
        UpdateAppearance()
        if MiliUI_DB.ahAutoCurrentExpansion then
            print("|cff00ff00[MiliUI]|r 僅限當前資料片: |cff00ff00開|r")
        else
            print("|cff00ff00[MiliUI]|r 僅限當前資料片: |cffff6600關|r")
        end
    end)

    btn:SetScript("OnEnter", function(self)
        btn:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, 0)
        GameTooltip:SetText("僅限當前資料片", 1, 1, 1)
        GameTooltip:AddLine("由 MiliUI 提供，搜尋時自動篩選當前資料片的物品。點擊切換。\n\n可在 MiliUI 設定 → 插件強化 → 拍賣行中關閉此功能。", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        UpdateAppearance()
        GameTooltip_Hide()
    end)

    -- 錨定到拍賣行框體右上角
    local function AnchorButton()
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", 0, 2)
    end

    -- 根據主開關控制按鈕顯示
    local function UpdateVisibility()
        if MiliUI_DB.ahFeatureEnabled then
            AnchorButton()
            UpdateAppearance()
            btn:Show()
        else
            btn:Hide()
        end
    end

    -- 延遲初始化，等 Auctionator 等插件完成標籤建立
    AuctionHouseFrame:HookScript("OnShow", function()
        UpdateVisibility()
    end)
    AuctionHouseFrame:HookScript("OnHide", function()
        btn:Hide()
    end)

    MiliUI_AHFilter = {
        UpdateVisibility = UpdateVisibility,
    }

    --------------------------------------------------------------------------
    -- 篩選注入（只在使用者操作時生效，避開 Auctionator 等掃描）
    --------------------------------------------------------------------------
    local userInitiated = false

    local origFrameSendBrowse = AuctionHouseFrame.SendBrowseQuery
    AuctionHouseFrame.SendBrowseQuery = function(self, ...)
        userInitiated = true
        local result = origFrameSendBrowse(self, ...)
        userInitiated = false
        return result
    end

    local origSendBrowseQuery = C_AuctionHouse.SendBrowseQuery
    C_AuctionHouse.SendBrowseQuery = function(query)
        if userInitiated
           and MiliUI_DB.ahFeatureEnabled
           and MiliUI_DB.ahAutoCurrentExpansion
           and query and query.filters then
            local found = false
            for _, f in ipairs(query.filters) do
                if f == Enum.AuctionHouseFilter.CurrentExpansionOnly then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(query.filters, Enum.AuctionHouseFilter.CurrentExpansionOnly)
            end
        end
        return origSendBrowseQuery(query)
    end
end)
