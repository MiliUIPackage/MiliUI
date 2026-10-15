--------------------------------------------------------------------------------
-- AuctionHouseFilter（MiliUI_QoL，2026-10 從本體 MiliUI/Enhance 搬來）
-- 在拍賣行底部標籤列最右側放置「僅限當前資料片」按鈕。
-- 點擊切換篩選狀態，不影響其他標籤切換。
-- 受「便利功能」設定的「拍賣行」開關控制（MiliUI_AHFilter.SetEnabled）。
-- 讀寫於 MiliUI_QoL_DB.ahFeatureEnabled／ahAutoCurrentExpansion（兩個頂層布林，預設都開）。
--
-- 智慧判斷：
--   只在使用者主動搜尋/瀏覽時注入篩選（透過 AuctionHouseFrame 的方法），
--   Auctionator 等插件直接呼叫 C_AuctionHouse.SendBrowseQuery 的掃描
--   不會被影響。
--------------------------------------------------------------------------------

local _, ns = ...
if ns.legacyCore then return end

-- 回傳的是根表（兩個 key 都是頂層布林，不是子表）
local function GetDB()
    -- ns.db（＝MiliUI_QoL_DB）在自己的 ADDON_LOADED 才有；那之前一律當預設值，不碰存檔
    local root = ns.db
    if not root then return { ahFeatureEnabled = true, ahAutoCurrentExpansion = true } end
    if root.ahFeatureEnabled == nil then
        root.ahFeatureEnabled = true
    end
    if root.ahAutoCurrentExpansion == nil then
        root.ahAutoCurrentExpansion = true
    end
    return root
end

-- 對外 API（給 Options/Controls.lua 用）。UpdateVisibility 等拍賣行介面載入、按鈕建好才補上。
MiliUI_AHFilter = {
    IsEnabled = function() return GetDB().ahFeatureEnabled ~= false end,
    SetEnabled = function(v)
        GetDB().ahFeatureEnabled = v
        if MiliUI_AHFilter.UpdateVisibility then MiliUI_AHFilter.UpdateVisibility() end
    end,
}

-- ⚠ 在 Init（PLAYER_LOGIN）才開始等拍賣行介面，不在檔案載入時：拍賣行介面萬一已經載入，
-- ContinueOnAddOnLoaded 會當場執行，那時 ns.W（TOC 排在 Modules\ 之後）與 ns.db 都還是 nil
ns.RegisterCallback("Init", "AuctionHouseFilter", function()
EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", function()
    local db = GetDB()   -- ＝MiliUI_QoL_DB（重設預設值會 ReloadUI，抓一次就好）

    --------------------------------------------------------------------------
    -- 建立篩選按鈕（不用 PanelTabButtonTemplate，避免破壞標籤系統）
    -- 套組按鈕樣式：開＝primary（職業色）、關＝normal（中性），狀態只換明暗
    --------------------------------------------------------------------------
    local W = ns.W
    local btn = W.CreateButton(AuctionHouseFrame, "", "primary", 130, 22)
    btn:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 10)

    local onColors = btn._colors
    -- 四格：切回「關」時邊框才會一起退回黑色（兩格的配色不換邊）
    local offColors = {
        { 0.115, 0.115, 0.115, 1 },
        { 0.23, 0.23, 0.23, 1 },
        { 0, 0, 0, 1 },
        { 0, 0, 0, 1 },
    }

    local function UpdateAppearance(hover)
        if db.ahAutoCurrentExpansion then
            btn:SetText("僅限當前資料片")
            btn._colors = onColors
        else
            btn:SetText("所有資料片")
            btn._colors = offColors
        end
        if hover == nil then hover = btn:IsVisible() and btn:IsMouseOver() end
        W.PaintButton(btn, hover)
    end

    btn:SetScript("OnClick", function()
        db.ahAutoCurrentExpansion = not db.ahAutoCurrentExpansion
        UpdateAppearance()
        if db.ahAutoCurrentExpansion then
            print("|cff00ff00[MiliUI]|r 僅限當前資料片: |cff00ff00開|r")
        else
            print("|cff00ff00[MiliUI]|r 僅限當前資料片: |cffff6600關|r")
        end
    end)

    btn:SetScript("OnEnter", function(self)
        W.PaintButton(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, 0)
        GameTooltip:SetText("僅限當前資料片", 1, 1, 1)
        GameTooltip:AddLine("由 MiliUI 提供，搜尋時自動篩選當前資料片的物品。點擊切換。\n\n可在「便利功能」設定（/mqol）→ 拍賣行中關閉此功能。", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        UpdateAppearance(false)
        GameTooltip_Hide()
    end)

    -- 錨定到拍賣行框體右上角
    local function AnchorButton()
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", 0, 2)
    end

    -- 根據主開關控制按鈕顯示
    local function UpdateVisibility()
        if db.ahFeatureEnabled then
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

    MiliUI_AHFilter.UpdateVisibility = UpdateVisibility

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
           and db.ahFeatureEnabled
           and db.ahAutoCurrentExpansion
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
end)  -- ns.RegisterCallback("Init")：內層沿用搬家前的縮排
