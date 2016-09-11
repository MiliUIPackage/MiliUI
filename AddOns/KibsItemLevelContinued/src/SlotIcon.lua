local _, addonNamespace = ...

local SlotIcon = {}
SlotIcon.__index = SlotIcon

addonNamespace.SlotIcon = SlotIcon

function SlotIcon:new(parent)
    local frame = CreateFrame("FRAME", nil, parent)
    frame:RegisterEvent("MouseUp")

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetAllPoints();

    return setmetatable({
        frame = frame,
        texture = nil,
        hidden = nil,
    }, self)
end

function PostLink(link)
    if MacroFrameText and MacroFrameText:IsShown() and MacroFrameText:HasFocus() then
        local text = MacroFrameText:GetText()..link
        if 255 >= strlenutf8(text) then
            MacroFrameText:Insert(link)
        end
    elseif ChatEdit_GetActiveWindow() then
        ChatEdit_InsertLink(link)
    end

    PlaySound("igMainMenuOptionCheckBoxOn")
end

function SlotIcon:Hide()
    self.frame:SetAlpha(0.0)
    self.frame:SetScript("OnEnter", nil)
    self.frame:SetScript("OnLeave", nil)
    self.frame:SetScript("OnMouseUp", nil)
    self.hidden = true
end

function SlotIcon:SetHyperlink(itemInfo)
    self.frame.icon:SetTexture(itemInfo:getTextureName())
    self.frame:SetAlpha(1.0)
    self.hidden = false
end

function SlotIcon:Render(textureName, tooltip)
    self:Hide()

    self.frame:SetAlpha(1.0)
    self.frame.icon:SetTexture(textureName)

    self.frame:SetScript("OnEnter", function ()
        tooltip:Show(self.frame)
    end)

    self.frame:SetScript("OnLeave", function ()
        tooltip:Hide()
    end)

    self.frame:SetScript("OnMouseUp", function ()
        if tooltip and tooltip:HasLink() and IsModifiedClick("CHATLINK") then
            PostLink(tooltip:GetLink())
        end
    end)

    self.hidden = false
end

function SlotIcon:isHidden()
    return self.hidden
end

local pool = addonNamespace.Pool:new(
    function (...)
        return nil
    end,
    function (parent)
        local ref = SlotIcon:new(parent)
        ref:Hide()
        return ref
    end,
    function (ref, parent)
        ref.frame:SetParent(parent)
    end,
    function (ref)
        ref:Hide()
        ref.frame:SetParent(nil)
        ref.frame:ClearAllPoints()
    end
)

addonNamespace.AllocateSlotIcon = function (parent)
    return pool:Allocate(parent)
end

addonNamespace.ReleaseSlotIcon = function (ref)
    pool:Release(ref)
end