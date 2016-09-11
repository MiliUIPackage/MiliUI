local _, addonNamespace = ...

local AceEvent = LibStub('AceEvent-3.0')

local FrameAdapter = {}
local FrameAdapterMetaTable = { __index = FrameAdapter }

function FrameAdapter:new(frame, utilityParentFrame, slotFramePrefix)
    local instance = {
        frame = frame,
        utilityParentFrame = utilityParentFrame,
        slotFramePrefix = slotFramePrefix,
        utilityChildFrame = nil,
        callbacks = {},
        onFrameShow = {},
        onFrameHide = {},
        messages = {
            contentChanged = 'FrameAdapter.contentChanged',
        },
    }

    instance.utilityChildFrame = CreateFrame('FRAME', nil, instance.utilityParentFrame)

    setmetatable(instance, FrameAdapterMetaTable)

    AceEvent:Embed(instance)

    return instance
end

function FrameAdapter:GetType()
    return self.slotFramePrefix
end

function FrameAdapter:GetFrame()
    return self.frame
end

function FrameAdapter:_OnUtilityFrameEvent(event, callback)
    if not self.callbacks[event] then
        self.callbacks[event] = {}

        self.utilityChildFrame:RegisterEvent(event)

        self.frame:SetScript(event, function()
            for _, callback in ipairs(self.callbacks[event]) do
                callback()
            end
        end)
    end

    table.insert(self.callbacks[event], callback)
end

function FrameAdapter:OnShow(callback)
    self:_OnUtilityFrameEvent('OnShow', callback)
end

function FrameAdapter:OnHide(callback)
    self:_OnUtilityFrameEvent('OnHide', callback)
end

function FrameAdapter:OnContentChanged(callback, ...)
    self:RegisterMessage(self.messages.contentChanged, callback, ...)
end

function FrameAdapter:GetSlotFrame(slotName)
    return _G[self.slotFramePrefix .. slotName]
end

function FrameAdapter:Debug(...)
    addonNamespace.Debug('FrameAdapter:', ...)
end

addonNamespace.FrameAdapter = FrameAdapter