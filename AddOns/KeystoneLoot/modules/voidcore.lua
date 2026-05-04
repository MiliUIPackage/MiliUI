local AddonName, KeystoneLoot = ...;

KeystoneLoot.Voidcore = {};

local Voidcore = KeystoneLoot.Voidcore;
local DB = KeystoneLoot.DB;
local Query = KeystoneLoot.Query;

local OTHER_SLOT = 14;

function Voidcore:IsEligible(itemId)
    local item = Query:GetItemInfo(itemId);
    if (not item or item == "catalyst") then
        return false;
    end

    return item.slotId ~= OTHER_SLOT;
end

function Voidcore:IsUsed(itemId)
    local voidcores = DB:Get("voidcore");
    return voidcores ~= nil and voidcores[itemId] == true;
end

function Voidcore:SetUsed(itemId, value)
    local voidcores = DB:Get("voidcore") or {};
    voidcores[itemId] = value or nil;
    DB:Set("voidcore", voidcores);
end
