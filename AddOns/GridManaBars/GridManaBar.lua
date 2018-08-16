local L = GridManaBarsLocale
--local AceOO = AceLibrary("AceOO-2.0")

local SML = LibStub("LibSharedMedia-3.0", true)

local GridFrame = Grid:GetModule("GridFrame")

GridMBFrame = GridFrame:NewModule("GridMBFrame")

GridMBFrame.defaultDB = {
    size = 0.1,
    side = "Bottom",
}

--local indicators = GridFrame.prototype.indicators
--table.insert(indicators, { type = "manabar",    order = 15,  name = L["Mana Bar"] })

local statusmap = GridFrame.db.profile.statusmap
if ( not statusmap["manabar"] ) then
	statusmap["manabar"] = { unit_mana = true }
end

local mb_options = {
    type = "group",
    name = L["Mana Bar"],
    desc = L["Mana Bar options."],
    args = {
        ["Manabar size"] = {
            type = "range",
            name = L["Size"],
            desc = L["Percentage of frame for mana bar"],
            max = 90,
            min = 10,
            step = 5,
            get = function ()
                return GridMBFrame.db.profile.size * 100
                end,
            set = function(_, v)
                GridMBFrame.db.profile.size = v / 100
                GridFrame:UpdateAllFrames()
            end
        },
        ["Manabar side"] = {
            type = "select",
            name = L["Side"],
            desc = L["Side of frame manabar attaches to"],
            get = function ()
                return GridMBFrame.db.profile.side
                end,
            set = function(_, v)
                GridMBFrame.db.profile.side = v
                GridFrame:UpdateAllFrames()
            end,
            values={["Left"] = L["Left"], ["Top"] = L["Top"], ["Right"] = L["Right"], ["Bottom"] = L["Bottom"] },
        },
    }
}

Grid.options.args["manabar"] = mb_options
--GridFrame.options.args["manabar"] = mb_options


function GridMBFrame:OnInitialize()
    if not self.db then
		self.db = Grid.db:RegisterNamespace(self.moduleName, { profile = self.defaultDB or { } })
	end
    
    GridFrame:RegisterIndicator("manabar", L["Mana Bar"],
    	-- New
        function(frame)
            local bar = CreateFrame("StatusBar", nil, frame)
           
            local bg = bar:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(true)
            bar.bg = bg

            bar:SetStatusBarTexture("Interface\\Addons\\Grid\\gradient32x32")
            bar:SetMinMaxValues(0,1)
            bar:SetValue(1)          
            
            --hide per default            
            bar.bg:Show()
            bar:Hide()
            
            return bar
        end,

        -- Reset
        function(self)
            local texture = SML:Fetch("statusbar", GridFrame.db.profile.texture) or "Interface\\Addons\\Grid\\gradient32x32"
            local frame = self.__owner
            local side = GridMBFrame.db.profile.side
            local healthBar = frame.indicators.bar
            local barWidth = GridMBFrame.db.profile.size
            local offset = GridFrame.db.profile.borderSize + 1
            self:SetParent(healthBar)
            
            --set anchor of manabar            
            self:ClearAllPoints()  
            --healthBar:ClearAllPoints()
            
            if side == "Right" then
                self:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -offset, -offset)
                self:SetWidth((frame:GetWidth()-2*offset) * barWidth)
                self:SetHeight((frame:GetHeight()-2*offset))
                self:SetOrientation("VERTICAL")
                --healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -offset)
                --healthBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMLEFT")
            elseif side == "Left" then
                self:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -offset)
                self:SetWidth((frame:GetWidth()-2*offset) * barWidth)
                self:SetHeight((frame:GetHeight()-2*offset))
                self:SetOrientation("VERTICAL")
                --healthBar:SetPoint("TOPLEFT", self, "TOPRIGHT")
                --healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -offset, offset)
            elseif side == "Bottom" then
                self:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", offset, offset)
                self:SetWidth((frame:GetWidth()-2*offset))
                self:SetHeight((frame:GetHeight()-2*offset) * barWidth)
                self:SetOrientation("HORIZONTAL")
                --healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -offset)
                --healthBar:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT")
            else
                self:SetPoint("TOPLEFT", frame, "TOPLEFT", offset, -offset)
                self:SetWidth((frame:GetWidth()-2*offset))
                self:SetHeight((frame:GetHeight()-2*offset) * barWidth)
                self:SetOrientation("HORIZONTAL")
                --healthBar:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
                --healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -offset, offset)
            end
            
            if self:IsShown() then
                frame.indicators.text:SetParent(self)
                frame.indicators.text2:SetParent(self)
                frame.indicators.corner1:SetParent(self)
                frame.indicators.corner2:SetParent(self)
                frame.indicators.corner3:SetParent(self)
                frame.indicators.corner4:SetParent(self)
                frame.indicators.icon:SetParent(self)
            end
            
            self:SetStatusBarTexture(texture)
            self.bg:SetTexture(texture)
        end,

        -- SetStatus
        function(self, color, text, value, maxValue, texture, texCoords, count, start, duration)  
            if not value or not maxValue then return end
            self:SetMinMaxValues(0, maxValue)
            self:SetValue(value)            

            if color then
                if GridFrame.db.profile.invertBarColor then
                    self:SetStatusBarColor(color.r,color.g,color.b,color.a)
                    self.bg:SetVertexColor(0,0,0,0.8)
                else
                    self:SetStatusBarColor(0,0,0,0.8)
                    self.bg:SetVertexColor(color.r,color.g,color.b,color.a)
                end
            end
            
            if not self:IsShown() then
                local frame = self.__owner
                frame.indicators.text:SetParent(self)
                frame.indicators.text2:SetParent(self)
                frame.indicators.corner1:SetParent(self)
                frame.indicators.corner2:SetParent(self)
                frame.indicators.corner3:SetParent(self)
                frame.indicators.corner4:SetParent(self)
                frame.indicators.icon:SetParent(self)                
            end
            self:Show()
        end,

        -- ClearStatus
        function(self)
            if self:IsShown() then
                local frame = self.__owner
                local healthBar = frame.indicators.bar
                frame.indicators.text:SetParent(healthBar)
                frame.indicators.text2:SetParent(healthBar)
                frame.indicators.corner1:SetParent(healthBar)
                frame.indicators.corner2:SetParent(healthBar)
                frame.indicators.corner3:SetParent(healthBar)
                frame.indicators.corner4:SetParent(healthBar)
                frame.indicators.icon:SetParent(healthBar)
            end
            self:Hide()
            self:SetValue(0)
        end
    )
    hooksecurefunc(GridFrame.prototype, "ResetAllIndicators", function(self) self.indicators.manabar:Reset() end)
end

function GridMBFrame:OnEnable()
end

function GridMBFrame:OnDisable()
end

function GridMBFrame:Reset()
end
