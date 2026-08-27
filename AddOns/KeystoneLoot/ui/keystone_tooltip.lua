local AddonName, KeystoneLoot = ...;

local Keystone = KeystoneLoot.Keystone;
local DB = KeystoneLoot.DB;
local L = KeystoneLoot.L;

local function OnTooltipSetItem(Tooltip)
    -- GameTooltip and ItemRefTooltip only
    if (Tooltip ~= GameTooltip and Tooltip ~= ItemRefTooltip) then
        return;
    end

    -- Check if feature is enabled
    if (not DB:Get("settings.keystoneTooltip")) then
        return;
    end

    -- Get item link from tooltip
    local _, itemLink = Tooltip:GetItem();
    if (not itemLink) then
        return;
    end

    -- Extract keystone level from item link
    -- New format: keystone:180653:2:378:10:9:160:0
    local keystoneLevel = tonumber(itemLink:match("keystone:%d+:%d+:(%d+)"));

    -- Old format fallback: item:180653:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10
    if (not keystoneLevel) then
        keystoneLevel = tonumber(itemLink:match("item:180653:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:(%d+)"));
    end

    if (not keystoneLevel) then
        return;
    end

    -- Get rewards from Keystone module
    local rewards = Keystone:GetRewards(keystoneLevel);
    if (not rewards) then
        return;
    end

    -- Add to tooltip
    Tooltip:AddLine(" ");
    Tooltip:AddLine("|cff9d5db8KeystoneLoot|r");
    Tooltip:AddDoubleLine(
        LOOT,
        rewards.endOfRun.level .. " (" .. rewards.endOfRun.rank .. ")",
        1, 1, 1,
        1, 1, 1
    );
    Tooltip:AddDoubleLine(
        L["Great Vault"],
        rewards.greatVault.level .. " (" .. rewards.greatVault.rank .. ")",
        1, 1, 1,
        1, 1, 1
    );
    Tooltip:Show();
end

-- Register tooltip hook
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem);
