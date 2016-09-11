local _, addonNamespace = ...

local CharacterFrameAdapter = {}
local CharacterFrameAdapterMetaTable = { __index = CharacterFrameAdapter }

setmetatable(CharacterFrameAdapter, { __index = addonNamespace.FrameAdapter })

function CharacterFrameAdapter:new()
    local instance = addonNamespace.FrameAdapter:new(CharacterModelFrame, CharacterModelFrame, 'Character')

    instance.messages = {
        contentChanged = 'CharacterFrameAdapter.contentChanged',
    }

    setmetatable(instance, CharacterFrameAdapterMetaTable)

    instance:RegisterEvent("UNIT_INVENTORY_CHANGED", function(event, unit)
        if unit == 'player' then
            instance:Debug("UNIT_INVENTORY_CHANGED", unit)
            instance:SendMessage(instance.messages.contentChanged)
        end
    end)

    instance:RegisterEvent("SOCKET_INFO_CLOSE", function()
        instance:Debug("SOCKET_INFO_CLOSE")
        instance:SendMessage(instance.messages.contentChanged)
    end)

    instance:RegisterEvent("SOCKET_INFO_SUCCESS", function()
        instance:Debug("SOCKET_INFO_SUCCESS")
        instance:SendMessage(instance.messages.contentChanged)
    end)

    instance:RegisterEvent("SOCKET_INFO_UPDATE", function()
        instance:Debug("SOCKET_INFO_UPDATE")
        instance:SendMessage(instance.messages.contentChanged)
    end)

    return instance
end

function CharacterFrameAdapter:GetUnit()
    return "player"
end

function CharacterFrameAdapter:Debug(...)
    addonNamespace.Debug('CharacterFrameAdapter:', ...)
end

addonNamespace.CharacterFrameAdapter = CharacterFrameAdapter