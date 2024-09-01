local myname, ns = ...

local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("Slash", "AceConsole-3.0")
local config

function module:OnInitialize()
    config = core:GetModule("Config", true)

    self:RegisterChatCommand("silverdragon", "OnChatCommand")
    if not select(4, C_AddOns.GetAddOnInfo("NPCScan")) then
        -- NPCScan is either not installed or not loaded
        -- We'd like to borrow the "/npcscan add 12345" and similar command since it's all over sites
        self:RegisterChatCommand("npcscan", "OnChatCommand")
    end
end

local commands = {
    add = function(self, arg)
        local npcid = ns.input_to_mobid(arg)
        if npcid then
            if not core:SetCustom('any', npcid, true) then
                return self:Printf("%s (%d) 已經在自訂觀察名單中", core:NameForMob(npcid) or UNKNOWN, npcid)
            end
            return self:Printf("已經將 %s (%d) 加入自訂觀察名單", core:NameForMob(npcid) or UNKNOWN, npcid)
        end
        self:Print("無法根據你所輸入的 ID 找到稀有怪")
    end,
    remove = function(self, arg)
        local npcid = ns.input_to_mobid(arg)
        if npcid then
            if not core:SetCustom('any', npcid, false) then
                return self:Printf("%s (%d) 不在自訂觀察名單中", core:NameForMob(npcid) or UNKNOWN, npcid)
            end
            return self:Printf("已經將 %s (%d) 從自訂觀察名單中移除", core:NameForMob(npcid) or UNKNOWN, npcid)
        end
        self:Print("無法根據你所輸入的 ID 找到稀有怪")
    end,
    ignore = function(self, arg)
        local npcid = ns.input_to_mobid(arg)
        if npcid then
            if not core:SetIgnoreMob(npcid, true) then
                return self:Printf("%s (%d) 已經在忽略名單中", core:NameForMob(npcid) or UNKNOWN, npcid)
            end
            return self:Printf("已經將 %s (%d) 加入忽略觀察名單", core:NameForMob(npcid) or UNKNOWN, npcid)
        end
        self:Print("無法根據你所輸入的 ID 找到稀有怪")
    end,
    debug = function(self, args)
        core:ShowDebugWindow()
    end,
}

function module:OnChatCommand(input)
    local command, arg = self:GetArgs(input, 2)
    if command and commands[command:lower()] then
        commands[command:lower()](self, arg, input)
    else
        if config then
            config:ShowConfig()
        end
    end
end
