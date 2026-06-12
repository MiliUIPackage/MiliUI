--------------------------------------------------------------------------------
-- ItemUpgrade_PreviewIcon
-- 物品升級介面（ItemUpgradeFrame）的左右屬性比較面板不顯示物品 icon，
-- 在兩個面板右上角各補一個 icon，mouseover 顯示完整物品 tooltip，
-- 讓塑形收藏類 tooltip 插件（CanIMogIt 等）能接手。
--
-- 左側 icon：當前物品（GameTooltip:SetUpgradeItem）。
-- 右側 icon：依下拉選單選擇的目標升級等級顯示「升級後」的物品：
--   1) 優先把物品連結中的升級軌道 bonusID 換成目標階級的
--      （tooltip 會正確顯示「提升等級：英雄 6/6」與升級後 ilvl/屬性）
--   2) 連結中認不得軌道時，改附加「物品等級 +N」差值 bonusID
--      （ilvl 與屬性正確，提升等級行維持原文）
--------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_ItemUpgradeUI", function()
    if not ItemUpgradeFrame then return end

    ----------------------------------------------------------------------------
    -- 升級軌道 bonusID（每季需更新，資料來源：KeystoneLoot data/upgrade_tracks.lua）
    -- 陣列索引 = 軌道內的升級階級（upgradeLevel 1..N）
    ----------------------------------------------------------------------------
    local TRACK_BONUS_IDS = {
        veteran  = { 12777, 12778, 12779, 12780, 12781, 12782 },
        champion = { 12785, 12786, 12787, 12788, 12789, 12790 },
        hero     = { 12793, 12794, 12795, 12796, 12797, 12798 },
        myth     = { 12801, 12802, 12803, 12804, 12805, 12806 },
    }

    -- 反查表：bonusID -> { track, rank }
    local TRACK_BONUS_LOOKUP = {}
    for track, ids in pairs(TRACK_BONUS_IDS) do
        for rank, id in ipairs(ids) do
            TRACK_BONUS_LOOKUP[id] = { track = track, rank = rank }
        end
    end

    -- 「物品等級 +N」差值 bonusID：N 1..100 對應 1473..1572（通用，跨季不變）
    local function GetIlvlDeltaBonusID(delta)
        if delta >= 1 and delta <= 100 then
            return 1472 + delta
        end
    end

    ----------------------------------------------------------------------------
    -- 組出「升級後」的物品連結；無法組出時回傳 nil（呼叫端 fallback 當前物品）
    ----------------------------------------------------------------------------
    local function GetUpgradedItemLink()
        local upgradeInfo = ItemUpgradeFrame.upgradeInfo
        local target = ItemUpgradeFrame.targetUpgradeLevel
        if not upgradeInfo or not target then return nil end
        if target <= (upgradeInfo.currUpgrade or 0) then return nil end

        local link = C_ItemUpgrade.GetItemHyperlink()
        if not link then return nil end
        local itemString = link:match("|H(item:[^|]*)|h")
            or (link:find("^item:") and link)
        if not itemString then return nil end

        -- 物品連結欄位：parts[14] = numBonusIDs，bonusID 從 parts[15] 起
        local parts = { strsplit(":", itemString) }
        local numBonus = tonumber(parts[14]) or 0

        -- 方法一：把當前軌道階級的 bonusID 換成目標階級
        for i = 15, 14 + numBonus do
            local rev = TRACK_BONUS_LOOKUP[tonumber(parts[i])]
            if rev then
                local trackIDs = TRACK_BONUS_IDS[rev.track]
                -- 雙重驗證：此 bonus 的階級需與 API 回報的當前階級一致，
                -- 且目標階級存在；不符就放棄換軌道（改走差值法）
                if rev.rank == upgradeInfo.currUpgrade and trackIDs[target] then
                    parts[i] = tostring(trackIDs[target])
                    return table.concat(parts, ":")
                end
                break
            end
        end

        -- 方法二：附加 ilvl 差值 bonusID
        local levelInfo = ItemUpgradeFrame.targetUpgradeLevelInfo
        local delta = levelInfo and levelInfo.itemLevelIncrement
        local deltaID = delta and GetIlvlDeltaBonusID(delta)
        if not deltaID then return nil end
        table.insert(parts, 15 + numBonus, tostring(deltaID))
        parts[14] = tostring(numBonus + 1)
        return table.concat(parts, ":")
    end

    ----------------------------------------------------------------------------
    -- Icon 按鈕
    ----------------------------------------------------------------------------
    local ICON_SIZE = 40

    local function CreateIconButton(parent, isUpgradePreview)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(ICON_SIZE, ICON_SIZE)
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -12)
        btn:Hide()

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints()
        btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        -- 品質外框（與 Blizzard ItemButton 同款貼圖）
        btn.border = btn:CreateTexture(nil, "OVERLAY")
        btn.border:SetTexture("Interface\\Common\\WhiteIconFrame")
        btn.border:SetAllPoints()

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local upgradedLink = isUpgradePreview and GetUpgradedItemLink()
            if upgradedLink then
                GameTooltip:SetHyperlink(upgradedLink)
            else
                GameTooltip:SetUpgradeItem()  -- 升級槽中的當前物品
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)

        return btn
    end

    local function UpdateIcon(btn)
        local info = ItemUpgradeFrame.upgradeInfo
        if not info or not info.iconID then
            btn:Hide()
            return
        end
        btn.icon:SetTexture(info.iconID)
        local color = info.displayQuality and ITEM_QUALITY_COLORS[info.displayQuality]
        if color then
            btn.border:SetVertexColor(color.r, color.g, color.b)
        else
            btn.border:SetVertexColor(1, 1, 1)
        end
        btn:Show()
    end

    -- 兩個比較面板各掛一個 icon，於面板重新產生內容時刷新
    local previews = {
        { frame = ItemUpgradeFrame.LeftItemPreviewFrame,  isUpgradePreview = false },
        { frame = ItemUpgradeFrame.RightItemPreviewFrame, isUpgradePreview = true },
    }
    for _, p in ipairs(previews) do
        if p.frame and p.frame.GeneratePreviewTooltip then
            local btn = CreateIconButton(p.frame, p.isUpgradePreview)
            hooksecurefunc(p.frame, "GeneratePreviewTooltip", function()
                UpdateIcon(btn)
            end)
        end
    end
end)
