Conceal = LibStub("AceAddon-3.0"):NewAddon("Conceal", "AceConsole-3.0", "AceTimer-3.0", "AceEvent-3.0")
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")

local defaults = {
    profile = {
        interactive = true,
        health = 30,
        power = false,
        mouseover = true,
        alpha = 10,
        actionBar1 = false,
        actionBar1ConcealDuringCombat = false,
        actionBar2 = false,
        actionBar2ConcealDuringCombat = false,
        actionBar3 = false,
        actionBar3ConcealDuringCombat = false,
        actionBar4 = true,
        actionBar4ConcealDuringCombat = true,
        actionBar5 = true,
        actionBar5ConcealDuringCombat = true,
        actionBar6 = true,
        actionBar6ConcealDuringCombat = true,
        actionBar7 = true,
        actionBar7ConcealDuringCombat = true,
        actionBar8 = true,
        actionBar8ConcealDuringCombat = true,
        petActionBar = false,
        petActionBarConcealDuringCombat = false,
        stanceBar = false,
        stanceBarConcealDuringCombat = false,
        selfFrame = false,
        selfFrameConcealDuringCombat = false,
        targetFrame = false,
        targetFrameConcealDuringCombat = false,
        microBar = true,
        microBarConcealDuringCombat = true
    }
}

local options = {
    name = "隱藏介面 ",
    handler = Conceal,
    type = "group",
    args = {
            -- General Options
            GeneralHeader = {
                order = 0,
                name = "一般",
                type = "header",              
            },
            alpha = {
                order = 1,
                name = "不透明度",
                desc = "隱藏時的不透明度。",
                width = 2,
                type = "range",
                get = "GetSlider",
                set = "SetSlider",
                min = 0,
                max = 100,   
                step = 5,
                disabled = false,
            },
            health = {
                order = 2,
                name = "血量臨界值",
                desc = "血量 % 低於此數值時會顯示隱藏的介面。",
                width = 2,
                type = "range",
                get = "GetSlider",
                set = "SetSlider",
                min = 0,
                max = 100,   
                step = 5,
                disabled = false,
            },
            GeneralHeader = {
                order = 3,
                name = "玩家框架",
                type = "header",              
            },
            selfFrame = {
                order = 3.1,
                name = "隱藏玩家框架",
                desc = "使用設定的透明度隱藏玩家框架。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            selfFrameConcealDuringCombat = {
                order = 3.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量隱藏玩家框架。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            targetFrame = {
                order = 3.3,
                name = "隱藏目標框架",
                desc = "使用設定的透明度隱藏玩家框架。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            targetFrameConcealDuringCombat = {
                order = 3.4,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏目標框架。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 1 Options
            ActionBar1Header = {
                order = 4,
                name = "快捷列 1",
                type = "header",              
            },
            actionBar1 = {
                order = 4.1,
                name = "隱藏快捷列 1",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar1ConcealDuringCombat = {
                order = 4.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 1。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 2 Options
            ActionBar2Header = {
                order = 5,
                name = "快捷列 2",
                type = "header",              
            },
            actionBar2 = {
                order = 5.1,
                name = "隱藏快捷列 2",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar2ConcealDuringCombat = {
                order = 5.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 2。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 3 Options
            ActionBar3Header = {
                order = 6,
                name = "快捷列 3",
                type = "header",              
            },
            actionBar3 = {
                order = 6.1,
                name = "隱藏快捷列 3",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5 ,
                disabled = false,
            },
            actionBar3ConcealDuringCombat = {
                order = 6.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 3。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 4 Options
            ActionBar4Header = {
                order = 7,
                name = "快捷列 4",
                type = "header",              
            },
            actionBar4 = {
                order = 7.1,
                name = "隱藏快捷列 4",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar4ConcealDuringCombat = {
                order = 7.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 4。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 5 Options
            ActionBar5Header = {
                order = 8,
                name = "快捷列 5",
                type = "header",              
            },
            actionBar5 = {
                order = 8.1,
                name = "隱藏快捷列 5",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar5ConcealDuringCombat = {
                order = 8.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 5。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 6 Options
            ActionBar6Header = {
                order = 9,
                name = "快捷列 6",
                type = "header",              
            },
            actionBar6 = {
                order = 9.1,
                name = "隱藏快捷列 6",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar6ConcealDuringCombat = {
                order = 9.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 6。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 7 Options
            ActionBar7Header = {
                order = 10,
                name = "快捷列 7",
                type = "header",              
            },
            actionBar7 = {
                order = 10.1,
                name = "隱藏快捷列 7",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar7ConcealDuringCombat = {
                order = 10.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 7。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Action Bar 8 Options
            ActionBar8Header = {
                order = 11,
                name = "快捷列 8",
                type = "header",              
            },
            actionBar8 = {
                order = 11.1,
                name = "隱藏快捷列 8",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            actionBar8ConcealDuringCombat = {
                order = 11.2,
                name = "戰鬥中隱藏",
                desc = "戰鬥中和低血量時隱藏快捷列 8。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            -- Other Bar Options
            OtherBarsHeader = {
                order = 13,
                name = "其他快捷列",
                type = "header",              
            },
            petActionBar = {
                order = 13.1,
                name = "隱藏寵物快捷列",
                desc = "使用設定的透明度隱藏快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            petActionBarConcealDuringCombat = {
                order = 13.2,
                name = "戰鬥中隱藏寵物快捷列",
                desc = "戰鬥中和低血量時隱藏寵物快捷列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            stanceBar = {
                order = 13.3,
                name = "隱藏姿勢形態列",
                desc = "使用設定的透明度隱藏姿勢形態列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            stanceBarConcealDuringCombat = {
                order = 13.4,
                name = "戰鬥中隱藏姿勢形態列",
                desc = "戰鬥中和低血量時隱藏姿勢形態列。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            microBar = {
                order = 13.5,
                name = "隱藏微型選單和背包",
                desc = "使用設定的透明度隱藏微型選單和背包。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
            microBarConcealDuringCombat = {
                order = 13.6,
                name = "戰鬥中隱藏微型選單和背包",
                desc = "戰鬥中和低血量時隱藏微型選單和背包。",
                type = "toggle",
                get = "GetStatus",
                set = "SetStatus",
                width = 1.5,
                disabled = false,
            },
    }
}

local isInCombat = false

ActionBar2 = MultiBarBottomLeft
ActionBar3 = MultiBarBottomRight
ActionBar4 = MultiBarRight 
ActionBar5 = MultiBarLeft
ActionBar6 = MultiBar5
ActionBar7 = MultiBar6
ActionBar8 = MultiBar7

function Conceal:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("ConcealDB", defaults, true) 
    self.db.RegisterCallback(self, "OnProfileChanged", "ProfileHandler")
    self.db.RegisterCallback(self, "OnProfileCopied", "ProfileHandler")
    self.db.RegisterCallback(self, "OnProfileReset", "ProfileHandler")
    AC:RegisterOptionsTable("Conceal_options", options) 
    self.optionsFrame = ACD:AddToBlizOptions("Conceal_options", "隱藏")  
    
    Conceal:RegisterEvent("ADDON_LOADED", "loadConfig");
    -- Conceal:RegisterEvent("PLAYER_ENTERING_WORLD", "refreshGUI");
    -- Conceal:RegisterEvent("PLAYER_LEAVING_WORLD", "refreshGUI");
    Conceal:RegisterEvent("PLAYER_ENTER_COMBAT", "DidEnterCombat");
    Conceal:RegisterEvent("PLAYER_LEAVE_COMBAT", "DidExitCombat");
    Conceal:RegisterEvent("PLAYER_REGEN_DISABLED", "DidEnterCombat");
    Conceal:RegisterEvent("PLAYER_REGEN_ENABLED", "DidExitCombat");
    Conceal:RegisterEvent("PLAYER_TARGET_CHANGED", "TargetChanged");
    
    Conceal:HideGcdFlash()
    
    C_Timer.NewTicker(0.10, function()
        Conceal:ShowMouseOverElements()
        Conceal:RefreshGUI()
    end)
end

-- Conditionals
function Conceal:isHealthBelowThreshold()
    local threshold = self.db.profile["health"];
    if threshold then
        local hp = UnitHealth("player");
        local maxHP = UnitHealthMax("player");
        local pct = (hp / maxHP) * 100;
        return pct < threshold;
    else
        return false;
    end
end


-- Actions
function Conceal:ShowCombatElements()

    if self.db.profile["selfFrame"] and not self.db.profile["selfFrameConcealDuringCombat"] then PlayerFrame:SetAlpha(1) end
    if self.db.profile["targetFrame"] and not self.db.profile["targetFrameConcealDuringCombat"] then TargetFrame:SetAlpha(1) end

    -- Action Bar 1
    local isActionBar1Concealable = self.db.profile["actionBar1"] 
    local concealActionBar1InCombat = self.db.profile["actionBar1ConcealDuringCombat"] 
    if isActionBar1Concealable and not concealActionBar1InCombat then 
        for i=1,12 do
            _G["ActionButton" ..i]:SetAlpha(1)
        end
    end
    
    if self.db.profile["actionBar2"] and not self.db.profile["actionBar2ConcealDuringCombat"] then ActionBar2:SetAlpha(1) end
    if self.db.profile["actionBar3"] and not self.db.profile["actionBar3ConcealDuringCombat"] then ActionBar3:SetAlpha(1) end
    if self.db.profile["actionBar4"] and not self.db.profile["actionBar4ConcealDuringCombat"] then ActionBar4:SetAlpha(1) end
    if self.db.profile["actionBar5"] and not self.db.profile["actionBar5ConcealDuringCombat"] then ActionBar5:SetAlpha(1) end
    if self.db.profile["actionBar6"] and not self.db.profile["actionBar6ConcealDuringCombat"] then ActionBar6:SetAlpha(1) end
    if self.db.profile["actionBar7"] and not self.db.profile["actionBar7ConcealDuringCombat"] then ActionBar7:SetAlpha(1) end
    if self.db.profile["actionBar8"] and not self.db.profile["actionBar8ConcealDuringCombat"] then ActionBar8:SetAlpha(1) end
    if self.db.profile["petActionBar"] and not self.db.profile["petActionBarConcealDuringCombat"] then PetActionBar:SetAlpha(1) end

    -- Stance Bar
    if self.db.profile["stanceBar"] and not self.db.profile["stanceBarConcealDuringCombat"]  then StanceBar:SetAlpha(1) end
    if self.db.profile["microBar"] and not self.db.profile["microBarConcealDuringCombat"]  then MicroButtonAndBagsBar:SetAlpha(1) end
end

function Conceal:ShowMouseOverElements()
    local frameAlpha = self.db.profile["alpha"];
    if frameAlpha > 1 then frameAlpha = frameAlpha / 100; end

    if self.db.profile["selfFrame"] then 
        if PlayerFrame:IsMouseOver() then 
            PlayerFrame:SetAlpha(1); 
        elseif self.db.profile["selfFrameConcealDuringCombat"] then 
            PlayerFrame:SetAlpha(frameAlpha); 
        end 
    end

    if self.db.profile["targetFrame"] then 
        if TargetFrame:IsMouseOver() then 
            TargetFrame:SetAlpha(1); 
        elseif self.db.profile["targetFrameConcealDuringCombat"] then 
            TargetFrame:SetAlpha(frameAlpha); 
        end 
    end

    -- Action Bar 1
    local isActionBar1Concealable = self.db.profile["actionBar1"]
    if isActionBar1Concealable then
        local isMouseOverActionBar1 = false
        for i=1,12 do
            if _G["ActionButton" ..i]:IsMouseOver() then isMouseOverActionBar1 = true end
        end
        if isMouseOverActionBar1 then 
            for i=1,12 do
                _G["ActionButton" ..i]:SetAlpha(1)
            end
        elseif self.db.profile["actionBar1ConcealDuringCombat"] then
            for i=1,12 do
                _G["ActionButton" ..i]:SetAlpha(frameAlpha)
            end
        end
    end

    if self.db.profile["actionBar2"] then 
        if ActionBar2:IsMouseOver() then 
            ActionBar2:SetAlpha(1); 
        elseif self.db.profile["actionBar2ConcealDuringCombat"] then 
            ActionBar2:SetAlpha(frameAlpha); 
        end 
    end 
    if self.db.profile["actionBar3"] then 
        if ActionBar3:IsMouseOver() then 
            ActionBar3:SetAlpha(1); 
        elseif self.db.profile["actionBar3ConcealDuringCombat"] then 
            ActionBar3:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["actionBar4"] then 
        if ActionBar4:IsMouseOver() then 
            ActionBar4:SetAlpha(1); 
        elseif self.db.profile["actionBar4ConcealDuringCombat"] then 
            ActionBar4:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["actionBar5"] then 
        if ActionBar5:IsMouseOver() then 
            ActionBar5:SetAlpha(1); 
        elseif self.db.profile["actionBar5ConcealDuringCombat"] then 
            ActionBar5:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["actionBar6"] then 
        if ActionBar6:IsMouseOver() then 
            ActionBar6:SetAlpha(1); 
        elseif self.db.profile["actionBar6ConcealDuringCombat"] then 
            ActionBar6:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["actionBar7"] then 
        if ActionBar7:IsMouseOver() then 
            ActionBar7:SetAlpha(1); 
        elseif self.db.profile["actionBar7ConcealDuringCombat"] then 
            ActionBar7:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["actionBar8"] then 
        if ActionBar8:IsMouseOver() then 
            ActionBar8:SetAlpha(1); 
        elseif self.db.profile["actionBar8ConcealDuringCombat"] then 
            ActionBar8:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["petActionBar"] then 
        if PetActionBar:IsMouseOver() then 
            PetActionBar:SetAlpha(1); 
        elseif self.db.profile["petActionBarConcealDuringCombat"] then 
            PetActionBar:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["stanceBar"]  then 
        if StanceBar:IsMouseOver() then 
            StanceBar:SetAlpha(1); 
        elseif self.db.profile["stanceBarConcealDuringCombat"] then 
            StanceBar:SetAlpha(frameAlpha); 
        end 
    end
    if self.db.profile["microBar"]  then 
        if MicroButtonAndBagsBar:IsMouseOver() then 
            MicroButtonAndBagsBar:SetAlpha(1); 
        elseif self.db.profile["microBarConcealDuringCombat"] then 
            MicroButtonAndBagsBar:SetAlpha(frameAlpha); 
        end 
    end
end

function Conceal:HideElements()

    if isInCombat then return end

    local frameAlpha = self.db.profile["alpha"];
    if frameAlpha > 1 then frameAlpha = frameAlpha / 100; end
    
    -- Player Frame
    if self.db.profile["selfFrame"] and not PlayerFrame:IsMouseOver() then PlayerFrame:SetAlpha(frameAlpha); end
    if self.db.profile["targetFrame"] and not TargetFrame:IsMouseOver() then TargetFrame:SetAlpha(frameAlpha); end

    -- Action Bar 1
    local isActionBar1Concealable = self.db.profile["actionBar1"]
    local isMouseOverActionBar1 = false
    for i=1,12 do
        if _G["ActionButton" ..i]:IsMouseOver() then isMouseOverActionBar1 = true end
    end
    if isActionBar1Concealable and not isMouseOverActionBar1 then 
        for i=1,12 do
            _G["ActionButton" ..i]:SetAlpha(frameAlpha)
        end
    end

    if self.db.profile["actionBar2"] and not ActionBar2:IsMouseOver() then ActionBar2:SetAlpha(frameAlpha); end
    if self.db.profile["actionBar3"] and not ActionBar3:IsMouseOver() then ActionBar3:SetAlpha(frameAlpha); end
    if self.db.profile["actionBar4"] and not ActionBar4:IsMouseOver() then ActionBar4:SetAlpha(frameAlpha); end
    if self.db.profile["actionBar5"] and not ActionBar5:IsMouseOver() then ActionBar5:SetAlpha(frameAlpha); end
    if self.db.profile["actionBar6"] and not ActionBar6:IsMouseOver() then ActionBar6:SetAlpha(frameAlpha); end
    if self.db.profile["actionBar7"] and not ActionBar7:IsMouseOver() then ActionBar7:SetAlpha(frameAlpha); end
    if self.db.profile["actionBar8"] and not ActionBar8:IsMouseOver() then ActionBar8:SetAlpha(frameAlpha); end
    if self.db.profile["petActionBar"] and not PetActionBar:IsMouseOver() then PetActionBar:SetAlpha(frameAlpha); end
    if self.db.profile["stanceBar"] and not StanceBar:IsMouseOver() then StanceBar:SetAlpha(frameAlpha); end
    if self.db.profile["microBar"] and not MicroButtonAndBagsBar:IsMouseOver() then MicroButtonAndBagsBar:SetAlpha(frameAlpha); end
end

function Conceal:TargetChanged()
    if UnitExists("target") then 
         Conceal:ShowCombatElements();
    else
        Conceal:HideElements()
    end
end


-- Event Handlers
function Conceal:DidEnterCombat() 
    Conceal:ShowCombatElements()
    isInCombat = true
end

function Conceal:DidExitCombat() 
    Conceal:HideElements()
    isInCombat = false
end


--credit https://www.mmo-champion.com/threads/2414999-How-do-I-disable-the-GCD-flash-on-my-bars
function Conceal:HideGcdFlash() 
    for i,v in pairs(_G) do
        if type(v)=="table" and type(v.SetDrawBling)=="function" then
            v:SetDrawBling(false)
        end
    end
end

function Conceal:ProfileHandler() 
    Conceal:loadConfig();
    Conceal:RefreshGUI();
end

function Conceal:loadConfig()
    -- Unused for now
end

function Conceal:RefreshGUI()
    local shouldShowCombatElement = false
    if UnitExists("target") then shouldShowCombatElement = shouldShowCombatElement or true; end
    if Conceal:isHealthBelowThreshold() then shouldShowCombatElement = shouldShowCombatElement or true; end
    if shouldShowCombatElement then 
        Conceal:ShowCombatElements();
    else
        Conceal:HideElements()
    end
end

function Conceal:GetStatus(info)
    Conceal:RefreshGUI()
    Conceal:loadConfig()
    return self.db.profile[info[#info]]
end

function Conceal:SetStatus(info) 
    if self.db.profile[info[#info]] then
        self.db.profile[info[#info]] = false
        if info[#info] == "selfFrame" then PlayerFrame:SetAlpha(1); self.db.profile["selfFrameConcealDuringCombat"] = false end
        if info[#info] == "targetFrame" then TargetFrame:SetAlpha(1); self.db.profile["targetFrameConcealDuringCombat"] = false end
        if info[#info] == "actionBar1" then 
            for i=1,12 do
                _G["ActionButton" ..i]:SetAlpha(1)
            end
            self.db.profile["actionBar1ConcealDuringCombat"] = false 
        end
        if info[#info] == "actionBar2" then ActionBar2:SetAlpha(1); self.db.profile["actionBar2ConcealDuringCombat"] = false end
        if info[#info] == "actionBar3" then ActionBar3:SetAlpha(1); self.db.profile["actionBar3ConcealDuringCombat"] = false end
        if info[#info] == "actionBar4" then ActionBar4:SetAlpha(1); self.db.profile["actionBar4ConcealDuringCombat"] = false end
        if info[#info] == "actionBar5" then ActionBar5:SetAlpha(1); self.db.profile["actionBar5ConcealDuringCombat"] = false end
        if info[#info] == "actionBar6" then ActionBar6:SetAlpha(1); self.db.profile["actionBar6ConcealDuringCombat"] = false end
        if info[#info] == "actionBar7" then ActionBar7:SetAlpha(1); self.db.profile["actionBar7ConcealDuringCombat"] = false end
        if info[#info] == "actionBar8" then ActionBar8:SetAlpha(1); self.db.profile["actionBar8ConcealDuringCombat"] = false end
        if info[#info] == "petActionBar" then PetActionBar:SetAlpha(1); self.db.profile["petActionBarConcealDuringCombat"] = false end
        if info[#info] == "stanceBar" then StanceBar:SetAlpha(1); self.db.profile["stanceBarConcealDuringCombat"] = false end
        if info[#info] == "microBar" then MicroButtonAndBagsBar:SetAlpha(1); self.db.profile["microBarConcealDuringCombat"] = false end
    else 
        self.db.profile[info[#info]] = true
        if info[#info] == "selfFrameConcealDuringCombat" then self.db.profile["selfFrame"] = true end
        if info[#info] == "targetFrameConcealDuringCombat" then self.db.profile["targetFrame"] = true end
        if info[#info] == "actionBar1ConcealDuringCombat" then self.db.profile["actionBar1"] = true end
        if info[#info] == "actionBar2ConcealDuringCombat" then self.db.profile["actionBar2"] = true end
        if info[#info] == "actionBar3ConcealDuringCombat" then self.db.profile["actionBar3"] = true end
        if info[#info] == "actionBar4ConcealDuringCombat" then self.db.profile["actionBar4"] = true end
        if info[#info] == "actionBar5ConcealDuringCombat" then self.db.profile["actionBar5"] = true end
        if info[#info] == "actionBar6ConcealDuringCombat" then self.db.profile["actionBar6"] = true end
        if info[#info] == "actionBar7ConcealDuringCombat" then self.db.profile["actionBar7"] = true end
        if info[#info] == "actionBar8ConcealDuringCombat" then self.db.profile["actionBar8"] = true end
        if info[#info] == "petActionBarConcealDuringCombat" then self.db.profile["petActionBar"] = true end
        if info[#info] == "stanceBarConcealDuringCombat" then self.db.profile["stanceBar"] = true end
        if info[#info] == "microBarConcealDuringCombat" then self.db.profile["microBar"] = true end
        Conceal:loadConfig()
    end
    Conceal:RefreshGUI()
end

function Conceal:GetSlider(info)
    return self.db.profile[info[#info]]
end

function Conceal:SetSlider(info, value)
    self.db.profile[info[#info]] = value
end