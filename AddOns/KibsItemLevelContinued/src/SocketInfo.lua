local _, addonNamespace = ...

local SocketInfo = {
    TYPE = {
        UNKNOWN = 0,
        PRISMATIC = 1,
        RED = 2,
        BLUE = 3,
        YELLOW = 4,
        META = 5,
    }
}
SocketInfo.__index = SocketInfo

addonNamespace.SocketInfo = SocketInfo

function SocketInfo:new(typeId, gemItemInfo)
    return setmetatable({
        typeId = typeId,
        gemItemInfo = gemItemInfo,
    }, self)
end

function SocketInfo:getTypeId()
    return self.typeId
end

function SocketInfo:isEmpty()
    return self.gemItemInfo == nil
end

function SocketInfo:getGem()
    return self.gemItemInfo
end

function SocketInfo:getTextureName()
    return ({
        [self.TYPE.PRISMATIC] = "INTERFACE/ITEMSOCKETINGFRAME/UI-EmptySocket-Prismatic",
        [self.TYPE.RED] = "INTERFACE/ITEMSOCKETINGFRAME/UI-EmptySocket-Red",
        [self.TYPE.BLUE] = "INTERFACE/ITEMSOCKETINGFRAME/UI-EmptySocket-Blue",
        [self.TYPE.YELLOW] = "INTERFACE/ITEMSOCKETINGFRAME/UI-EmptySocket-Yellow",
        [self.TYPE.META] = "INTERFACE/ITEMSOCKETINGFRAME/UI-EmptySocket-Meta",
        [self.TYPE.UNKNOWN] = "INTERFACE/ICONS/INV_Misc_QuestionMark",
    })[self.typeId]
end