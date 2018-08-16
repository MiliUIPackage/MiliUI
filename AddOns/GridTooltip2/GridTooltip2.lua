local GridFrame = Grid:GetModule("GridFrame")

GridTooltip2 = Grid:NewModule("GridTooltip2")

GridTooltip2.defaultDB = {
    enabledIndicators = {
        icon = true,
    },
}

GridTooltip2.options = {
	name = "GridTooltip2",
	desc = "Options for GridTooltip2.",
	order = 2,
	type = "group",
	childGroups = "tab",
	disabled = InCombatLockdown,
	args = {
    }
}

local lastMouseOverFrame

local function FindTooltip(unit, texture, index)
    index = index or 1
    local i = 0
    --search from the last index the texture was found to the left and right for the texture
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId = UnitDebuff(unit, index)
    while name or index - i > 1 do 
        if icon == texture then
            return index + i, spellId
        end
        i = i + 1
        name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId = UnitDebuff(unit, index - i)
        if icon == texture then
            return index - i, spellId
        end
        name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, _, spellId = UnitDebuff(unit, index + i)
    end
    
    return nil
end

function GridTooltip2.SetIndicator(frame, indicator, color, text, value, maxValue, texture, start, duration, stack)
	
	if texture and GridTooltip2.db.profile.enabledIndicators[indicator] then
        if frame.unit and UnitExists(frame.unit)then
            frame.ToolTip = texture
            if lastMouseOverFrame then
                GridTooltip2.OnEnter(lastMouseOverFrame)
            end            
        end
	end
end



function GridTooltip2.ClearIndicator(frame, indicator)   
    if GridTooltip2.db.profile.enabledIndicators[indicator] then
        frame.ToolTip = nil
        frame.ToolTipIndex = nil
    end
end

function GridTooltip2.CreateFrames(gridFrameObj, frame)
    local f = frame
    frame:HookScript("OnEnter", GridTooltip2.OnEnter)
	frame:HookScript("OnLeave", GridTooltip2.OnLeave)
end

function GridTooltip2.OnEnter(frame)
    local unitid = frame.unit
    if not unitid then return end   
    lastMouseOverFrame = frame
    
    if not frame.ToolTip then return end 
    
    local id
    frame.ToolTipIndex, id = FindTooltip(unitid, frame.ToolTip, frame.ToolTipIndex)

    if frame.ToolTipIndex then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetUnitDebuff(unitid, frame.ToolTipIndex)        
        GameTooltip:Show()
    end
end

function GridTooltip2.OnLeave(iconFrame)
    GameTooltip:Hide()
    if lastMouseOverFrame == iconFrame then
        lastMouseOverFrame = nil
    end
end

function GridTooltip2:OnInitialize()
    if not self.db then
		self.db = Grid.db:RegisterNamespace(self.moduleName, { profile = self.defaultDB or { } })
	end
    
    GridTooltip2.knownIndicators = {}
    
    GridFrame:RegisterIndicator("tooltip", "Tooltip dummy. Do not use!",
        function(frame)
            GridTooltip2.CreateFrames(nil, frame)
            return {}
        end,
        
        function(self)
            local indicators = self.__owner.indicators
            for id, indicator in pairs(indicators) do
                if not GridTooltip2.knownIndicators[id] then 
                    GridTooltip2.options.args[id] = {
                        name = id,
                        desc = "Display tooltip for indicator: "..GridFrame.indicators[id].name,
                        order = 60, width = "double",
                        type = "toggle",
                        get = function()
                            return GridTooltip2.db.profile.enabledIndicators[id]
                        end,
                        set = function(_, v)
                            GridTooltip2.db.profile.enabledIndicators[id] = v
                        end,
                    }
                    GridTooltip2.knownIndicators[id] = true
                end
            end
        end,
        
        function()
        end,
        function()
        end
    )
    hooksecurefunc(GridFrame.prototype, "SetIndicator", GridTooltip2.SetIndicator)
    hooksecurefunc(GridFrame.prototype, "ClearIndicator", GridTooltip2.ClearIndicator)
end

function GridTooltip2:OnEnable()
end

function GridTooltip2:OnDisable()
end

function GridTooltip2:Reset(frame)
end
