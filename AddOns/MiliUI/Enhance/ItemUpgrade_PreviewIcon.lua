--------------------------------------------------------------------------------
-- ItemUpgrade_PreviewIcon
-- 物品升級介面（ItemUpgradeFrame）的左右屬性比較面板不顯示物品 icon，
-- 在兩個面板右上角各補一個 icon，mouseover 顯示完整物品 tooltip，
-- 讓塑形收藏類 tooltip 插件（CanIMogIt 等）能接手。
--
-- 左側 icon：當前物品（GameTooltip:SetUpgradeItem）。
-- 右側 icon：依下拉選單選擇的目標升級等級顯示「升級後」的物品：
--   1) 優先把物品連結中的升級軌道 bonusID 換成目標階級的
--      （tooltip 會正確顯示「提升等級：神話 6/6」與升級後 ilvl/屬性）
--   2) 認不出軌道時，改附加「物品等級 +N」差值 bonusID
--      （ilvl 與屬性正確，提升等級行維持原文）
--
-- 軌道 bonusID 刻意「不」寫死。每季的軌道會換一整組新號碼，寫死的表每季都得
-- 更新，而且過期時是靜默降級——tooltip 看起來只是「怪怪的」，不會報錯。
-- 改用的性質是：同一條軌道內 6 個階級的 bonusID 連號，所以
--   目標階級的 ID = 當前階級的 ID + (目標階級 - 當前階級)
-- 這個關係跨季不變。難點只剩「連結裡哪一個 bonusID 才是軌道的」，用
-- GetDetailedItemLevelInfo 對每個候選試算 ilvl 來驗證即可。
--------------------------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Blizzard_ItemUpgradeUI", function()
    if not ItemUpgradeFrame then return end

    local GetDetailedIlvl = (C_Item and C_Item.GetDetailedItemLevelInfo)
        or GetDetailedItemLevelInfo

    -- 「物品等級 +N」差值 bonusID：N 1..100 對應 1473..1572（通用，跨季不變）
    local function GetIlvlDeltaBonusID(delta)
        if delta >= 1 and delta <= 100 then
            return 1472 + delta
        end
    end

    local function GetItemString(link)
        if not link then return nil end
        return link:match("|H(item:[^|]*)|h") or (link:find("^item:") and link)
    end

    -- 目標階級相對現在的 ilvl 增量。12.0 是放在 targetUpgradeLevelInfo，
    -- 但這個欄位不保證存在（12.1 實測拿不到），所以多找幾個地方，
    -- 全都沒有時回傳 nil —— 方法一有不需要它的備援路徑。
    local function GetTargetIlvlIncrement()
        local info = ItemUpgradeFrame.targetUpgradeLevelInfo
        if info and info.itemLevelIncrement then return info.itemLevelIncrement end

        local up = ItemUpgradeFrame.upgradeInfo
        local target = ItemUpgradeFrame.targetUpgradeLevel
        local levels = up and (up.upgradeLevelInfos or up.upgradeLevels)
        if levels and target then
            for _, li in ipairs(levels) do
                if li.upgradeLevel == target and li.itemLevelIncrement then
                    return li.itemLevelIncrement
                end
            end
        end
        return nil
    end

    local function WithBonusReplaced(parts, index, newID)
        local copy = {}
        for i, v in ipairs(parts) do copy[i] = v end
        copy[index] = tostring(newID)
        return table.concat(copy, ":")
    end

    ----------------------------------------------------------------------------
    -- 組出「升級後」的物品連結；無法組出時回傳 nil（呼叫端 fallback 當前物品）
    ----------------------------------------------------------------------------
    local function GetUpgradedItemLink()
        local upgradeInfo = ItemUpgradeFrame.upgradeInfo
        local target = ItemUpgradeFrame.targetUpgradeLevel
        if not upgradeInfo or not target then return nil end
        local curr = upgradeInfo.currUpgrade or 0
        if target <= curr then return nil end

        local link = C_ItemUpgrade.GetItemHyperlink()
        local itemString = GetItemString(link)
        if not itemString then return nil end

        -- 物品連結欄位：parts[14] = numBonusIDs，bonusID 從 parts[15] 起
        local parts = { strsplit(":", itemString) }
        local numBonus = tonumber(parts[14]) or 0

        local baseIlvl = GetDetailedIlvl and GetDetailedIlvl(link)
        local inc = GetTargetIlvlIncrement()
        local wantIlvl = (baseIlvl and inc) and (baseIlvl + inc) or nil

        -- 方法一：把每個 bonusID 都當成「軌道階級」候選，加上階級差之後
        -- 試算 ilvl。真正的軌道 bonus 才會讓 ilvl 往上跳到預期值；
        -- 其他 bonus（插槽、工藝、ilvl 差值…）加減後不會湊巧命中。
        if baseIlvl and GetDetailedIlvl then
            local step = target - curr
            for i = 15, 14 + numBonus do
                local id = tonumber(parts[i])
                if id then
                    local candidate = WithBonusReplaced(parts, i, id + step)
                    local ilvl = GetDetailedIlvl(candidate)
                    if ilvl then
                        if wantIlvl then
                            -- 知道確切增量時要求完全吻合，最嚴格
                            if ilvl == wantIlvl then return candidate end
                        else
                            -- 拿不到增量時看漲幅是否像「跳了 step 個升級階級」。
                            -- 階級之間固定差 3~4 ilvl，所以下限抓 2*step：
                            -- 這正好擋掉物品本身帶的「物品等級 +N」差值 bonus——
                            -- 它 +step 後 ilvl 剛好也只漲 step，會被誤認成軌道。
                            local gain = ilvl - baseIlvl
                            if gain >= 2 * step and gain <= 6 * step and gain <= 60 then
                                return candidate
                            end
                        end
                    end
                end
            end
        end

        -- 方法二：附加 ilvl 差值 bonusID（需要知道增量才做得到）
        local deltaID = inc and GetIlvlDeltaBonusID(inc)
        if not deltaID then return nil end
        table.insert(parts, 15 + numBonus, tostring(deltaID))
        parts[14] = tostring(numBonus + 1)
        return table.concat(parts, ":")
    end

    ----------------------------------------------------------------------------
    -- /miliuiupgrade：把上面每一步實際拿到什麼印出來。
    -- 升級介面開著、下拉選好目標階級時執行。
    ----------------------------------------------------------------------------
    SLASH_MILIUIUPGRADEDEBUG1 = "/miliuiupgrade"
    SlashCmdList["MILIUIUPGRADEDEBUG"] = function()
        local function out(fmt, ...) print("|cff00ff00[MiliUI]|r " .. fmt:format(...)) end
        local up = ItemUpgradeFrame.upgradeInfo
        if not up then return out("upgradeInfo = nil（升級槽是空的？）") end

        local target = ItemUpgradeFrame.targetUpgradeLevel
        out("currUpgrade=%s maxUpgrade=%s target=%s",
            tostring(up.currUpgrade), tostring(up.maxUpgrade), tostring(target))
        out("targetUpgradeLevelInfo=%s itemLevelIncrement=%s",
            tostring(ItemUpgradeFrame.targetUpgradeLevelInfo),
            tostring(GetTargetIlvlIncrement()))

        local link = C_ItemUpgrade.GetItemHyperlink()
        local itemString = GetItemString(link)
        out("link=%s", tostring(itemString))
        if not itemString then return end

        local parts = { strsplit(":", itemString) }
        local numBonus = tonumber(parts[14]) or 0
        local baseIlvl = GetDetailedIlvl and GetDetailedIlvl(link)
        out("baseIlvl=%s numBonus=%d", tostring(baseIlvl), numBonus)

        local step = (target or 0) - (up.currUpgrade or 0)
        for i = 15, 14 + numBonus do
            local id = tonumber(parts[i])
            local ilvl = id and GetDetailedIlvl
                and GetDetailedIlvl(WithBonusReplaced(parts, i, id + step))
            out("  bonus[%d]=%s  +%d -> ilvl %s", i - 14, tostring(id), step, tostring(ilvl))
        end
        out("結果連結=%s", tostring(GetUpgradedItemLink()))
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
