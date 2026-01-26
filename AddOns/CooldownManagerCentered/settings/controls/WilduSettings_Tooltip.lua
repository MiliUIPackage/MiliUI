local _, ns = ...

--- WilduSettings_Tooltip

WilduDefaultTooltipMixin = {}

---Initialize tooltip script handlers
function WilduDefaultTooltipMixin:InitDefaultTooltipScriptHandlers()
    self:SetScript("OnEnter", self.OnEnter)
    self:SetScript("OnLeave", self.OnLeave)
end

---Load event handler for tooltip elements
function WilduDefaultTooltipMixin:OnLoad()
    self:SetDefaultTooltipAnchors()
    self:InitDefaultTooltipScriptHandlers()
end

---Set default tooltip anchor position
function WilduDefaultTooltipMixin:SetDefaultTooltipAnchors()
    self.tooltipAnchorParent = nil
    self.tooltipAnchoring = "ANCHOR_RIGHT"
    self.tooltipXOffset = -10
    self.tooltipYOffset = 0
end

---Set custom tooltip function
---@param tooltipFunc function Function to call when showing tooltip
function WilduDefaultTooltipMixin:SetTooltipFunc(tooltipFunc)
    self.tooltipFunc = tooltipFunc
end

---Set custom tooltip hide function
---@param tooltipHideFunc function Function to call when hiding tooltip
function WilduDefaultTooltipMixin:SetTooltipHideFunc(tooltipHideFunc)
    self.tooltipHideFunc = tooltipHideFunc
end

---Mouse enter handler
function WilduDefaultTooltipMixin:OnEnter()
    if self.tooltipAnchorParent then
        SettingsTooltip:SetOwner(self.tooltipAnchorParent, self.tooltipAnchoring, self.tooltipXOffset, self.tooltipYOffset)
    else
        SettingsTooltip:SetOwner(self, self.tooltipAnchoring, self.tooltipXOffset, self.tooltipYOffset)
    end

    if self.tooltipFunc then
        self.tooltipFunc()
    elseif self.tooltipText then
        SettingsTooltip:SetText(self.tooltipText, nil, nil, nil, nil, true)
    end
    
    if not self.tooltipHideFunc then
        SettingsTooltip:Show()
    end

    if self.HoverBackground then
        self.HoverBackground:Show()
    end
end

---Mouse leave handler
function WilduDefaultTooltipMixin:OnLeave()
    SettingsTooltip:Hide()

    if self.tooltipHideFunc then
        self.tooltipHideFunc()
    end

    if self.HoverBackground then
        self.HoverBackground:Hide()
    end
end

---Set custom tooltip anchoring
---@param parent Frame Parent frame for tooltip anchor
---@param anchoring string Anchor point (e.g., "ANCHOR_RIGHT")
---@param xOffset number Horizontal offset
---@param yOffset number Vertical offset
function WilduDefaultTooltipMixin:SetCustomTooltipAnchoring(parent, anchoring, xOffset, yOffset)
    self.tooltipAnchorParent = parent
    self.tooltipAnchoring = anchoring
    self.tooltipXOffset = xOffset
    self.tooltipYOffset = yOffset
end
