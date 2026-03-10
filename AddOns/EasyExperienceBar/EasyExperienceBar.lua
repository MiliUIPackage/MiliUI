--luacheck: globals min max ceil Round strtrim

-- Initialization

EasyExperienceBar = _G.LibStub("AceAddon-3.0"):NewAddon("EasyExperienceBar", "AceConsole-3.0")
EasyExperienceBar.AceGUI = _G.LibStub("AceGUI-3.0")
EasyExperienceBar.AceConfig = _G.LibStub("AceConfig-3.0")
EasyExperienceBar.AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
EasyExperienceBar.LSM = _G.LibStub("LibSharedMedia-3.0")
EasyExperienceBar.MainFrame = nil
EasyExperienceBar.ProgressBar = nil
EasyExperienceBar.sessionTime = 0

local L = LibStub("AceLocale-3.0"):GetLocale("EasyExperienceBar")

function EasyExperienceBar:GetMaxLevel(exp)
    exp = exp or _G.GetExpansionLevel()

    return min(_G.GetMaxPlayerLevel(), _G.GetMaxLevelForExpansionLevel(exp))
end

EasyExperienceBar.level = _G.UnitLevel("player")
EasyExperienceBar.isPlayerMaxLevel = EasyExperienceBar.level >= EasyExperienceBar:GetMaxLevel()

EasyExperienceBar.GetNumQuestLogEntries = _G.C_QuestLog.GetNumQuestLogEntries or _G.GetNumQuestLogEntries
EasyExperienceBar.GetQuestIDForLogIndex = _G.C_QuestLog.GetQuestIDForLogIndex or function(i)
    return select(8, _G.GetQuestLogTitle(i))
end

EasyExperienceBar.IsQuestComplete = _G.C_QuestLog.IsComplete or _G.IsQuestComplete
EasyExperienceBar.QuestReadyForTurnIn = _G.C_QuestLog.ReadyForTurnIn or function() return false end
EasyExperienceBar.SetSelectedQuest = _G.C_QuestLog.SetSelectedQuest or _G.SelectQuestLogEntry
EasyExperienceBar.GetSelectedQuest = _G.C_QuestLog.GetSelectedQuest or _G.GetQuestLogSelection


EasyExperienceBar.UpdateTimer = nil

-- Options

EasyExperienceBar.options = {}
function EasyExperienceBar:Options()

    if EasyExperienceBar.global.levelTimeText == nil then  EasyExperienceBar.global.levelTimeText = true end
    if EasyExperienceBar.global.sessionTimeText == nil then  EasyExperienceBar.global.sessionTimeText = true end
    if EasyExperienceBar.global.showXpHourText == nil then  EasyExperienceBar.global.showXpHourText = true end
    if EasyExperienceBar.global.questRestedText == nil then  EasyExperienceBar.global.questRestedText = true end
    if EasyExperienceBar.global.questXpBar == nil then EasyExperienceBar.global.questXpBar = true end
    if EasyExperienceBar.global.showMaxLevel == nil then EasyExperienceBar.global.showMaxLevel = false end
    if EasyExperienceBar.global.resetReload == nil then EasyExperienceBar.global.resetReload = false end
    if EasyExperienceBar.global.hideXpBar == nil then EasyExperienceBar.global.hideXpBar = true end
    if EasyExperienceBar.global.lockBar == nil then EasyExperienceBar.global.lockBar = false end
    if EasyExperienceBar.global.font == nil then
        local locale = GetLocale()
        if locale == "zhTW" or locale == "zhCN" then
            EasyExperienceBar.global.font = "Fonts\\blei00d.TTF"
        else
            EasyExperienceBar.global.font = "Fonts\\FRIZQT__.TTF"
        end
    end
    if EasyExperienceBar.global.fontOutline == nil then EasyExperienceBar.global.fontOutline = "THICKOUTLINE" end
    if EasyExperienceBar.global.bartexture == nil then EasyExperienceBar.global.bartexture = "Interface\\Addons\\SharedMedia\\statusbar\\normT  ex" end
    if EasyExperienceBar.global.barWidth == nil then EasyExperienceBar.global.barWidth = 600 end
    if EasyExperienceBar.global.barHeight == nil then EasyExperienceBar.global.barHeight = 30 end
    if EasyExperienceBar.global.fontSize == nil then EasyExperienceBar.global.fontSize = 14 end
    if EasyExperienceBar.global.classColour == nil then EasyExperienceBar.global.classColour = false end

    local options = {
        name = L["Easy Experience Bar"],
        handler = EasyExperienceBar.options,
        type = 'group',
        args = {
            header1 = {
                type = 'header',
                order = 0,
                name = L["Information"],
            },
            levelTimeText = {
                type = 'toggle',
                order = 1,
                name = L["Played Time Text"],
                desc = L["Show Level time text"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.levelTimeText end,
                set = function(info,val) if EasyExperienceBar.global.levelTimeText
                    then EasyExperienceBar.global.levelTimeText = false
                    else EasyExperienceBar.global.levelTimeText = true end end,
            },
             sessionTimeText = {
                type = 'toggle',
                order = 2,
                name = L["Session Time Text"],
                desc = L["Show current session time"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.sessionTimeText end,
                set = function(info,val) if EasyExperienceBar.global.sessionTimeText
                    then EasyExperienceBar.global.sessionTimeText = false
                    else EasyExperienceBar.global.sessionTimeText = true end end,
            },
            showXpHourText = {
                type = 'toggle',
                order = 3,
                name = L["Leveling Time & XP/Hour Text"],
                desc = L["Show an estimate of how long it takes to hit the next level"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.showXpHourText end,
                set = function(info,val) if EasyExperienceBar.global.showXpHourText
                    then EasyExperienceBar.global.showXpHourText = false
                    else EasyExperienceBar.global.showXpHourText = true end end,
            },
            questRestedText = {
                type = 'toggle',
                order = 4,
                name = L["Completed & Rested Text"],
                desc = L["Show how much rested XP and XP from completed quests the character has"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.questRestedText end,
                set = function(info,val) if EasyExperienceBar.global.questRestedText
                    then EasyExperienceBar.global.questRestedText = false
                    else EasyExperienceBar.global.questRestedText = true end end,
            },
            questBar = {
                type = 'toggle',
                order = 5,
                name = L["Completed Quest XP Bar"],
                desc = L["Show a bar indicating how much XP is available from completed quests"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.questXpBar end,
                set = function(info,val) if EasyExperienceBar.global.questXpBar
                    then EasyExperienceBar.global.questXpBar = false
                    else EasyExperienceBar.global.questXpBar = true end end,
            },
            header2 = {
                type = 'header',
                order = 6,
                name = L["Settings"],
            },
            showMaxLevel = {
                type = 'toggle',
                order = 7,
                name = L["Show Bar at Max Level"],
                desc = L["Do not hide the bar on max level characters"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.showMaxLevel end,
                set = function(info,val) if EasyExperienceBar.global.showMaxLevel
                    then EasyExperienceBar.global.showMaxLevel = false
                    else EasyExperienceBar.global.showMaxLevel = true end end,
            },
            resetReload = {
                type = 'toggle',
                order = 8,
                name = L["Reset Session Time and XP/Hour on Reload UI"],
                desc = L["Do not retain stats after a /reload"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.resetReload end,
                set = function(info,val) if EasyExperienceBar.global.resetReload
                    then EasyExperienceBar.global.resetReload = false
                    else EasyExperienceBar.global.resetReload = true end end,
            },
            hideXPBar = {
                type = 'toggle',
                order = 9,
                name = L["Hide Default Experience Bar"],
                desc = L["Hides the standard XP bar"],
                width = "full",
                hidden = function() return not _G.StatusTrackingBarManager end,
                get = function(info)  return EasyExperienceBar.global.hideXpBar end,
                set = function(info,val) if EasyExperienceBar.global.hideXpBar then
                                            EasyExperienceBar.global.hideXpBar = false
                                         else
                                            EasyExperienceBar.global.hideXpBar = true
                                         end
                                         EasyExperienceBar:ResetBar()
                    end,
            },
            header3 = {
                type = 'header',
                order = 10,
                name = L["Display"],
            },
             lockBar = {
                type = 'toggle',
                order = 11,
                name = L["Lock Bar"],
                desc = L["Disables the click and drag to move function"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.lockBar end,
                set = function(info,val) if EasyExperienceBar.global.lockBar then
                                            EasyExperienceBar.global.lockBar = false
                                         else
                                            EasyExperienceBar.global.lockBar = true
                                         end
                    end,
            },
            width = {
                type = 'range',
                order = 12,
                name = L["Width"],
                desc = L["Adjust bar width"],
                min  = 10,
                max  = 1000,
                step = 1,
                width = "full",
                get = function(info)  return EasyExperienceBar.global.barWidth end,
                set = function(info,val) EasyExperienceBar.global.barWidth = val 
                                         EasyExperienceBar:Resize() 
                                         end,
            },
            height = {
                type = 'range',
                order = 13,
                name = L["Height"],
                desc = L["Adjust bar height"],
                min  = 10,
                max  = 100, 
                step = 1,
                width = "full",
                get = function(info)  return EasyExperienceBar.global.barHeight end,
                set = function(info,val) EasyExperienceBar.global.barHeight = val 
                                         EasyExperienceBar:Resize() 
                                         end,
            },
            fontSize = {
                type = 'range',
                order = 14,
                name = L["Font Size"],
                desc = L["Adjust font size"],
                min  = 5,
                max  = 30, 
                step = 1,
                width = "full",
                get = function(info)  return EasyExperienceBar.global.fontSize end,
                set = function(info,val) EasyExperienceBar.global.fontSize = val 
                                         EasyExperienceBar:Resize() 
                                         end,
            },
            font = {
                type = 'select',
                order = 15,
                name = L["Font"],
                desc = L["Font Selector"],
                dialogControl = 'LSM30_Font',
                values = EasyExperienceBar.LSM:HashTable("font"),
                width = "normal",
                get = function(info) local values = {}
                    local list = EasyExperienceBar.LSM:List("font")
                    local hashtable = EasyExperienceBar.LSM:HashTable("font")
                    for i,handle in ipairs(list) do
                        values[hashtable[handle]] = handle
                    end
                    local hash = values[EasyExperienceBar.global.font]
                    return hash end,
                set = function(info,val)
                    local hashtable = EasyExperienceBar.LSM:HashTable("font")
                    EasyExperienceBar.global.font = hashtable[val]
                    EasyExperienceBar:ChangeFont(EasyExperienceBar.global.font)
                    end
            },
            outline = {
                type = 'select',
                order = 16,
                name = L["Text Outline"],
                desc = L["Adds a black outline to text"],
                values = { ["NONE"] = L["None"], ["THICKOUTLINE"] = L["Thick Outline"], ["OUTLINE"] = L["Outline"] },
                sorting = { "NONE", "OUTLINE", "THICKOUTLINE" },
                style = "dropdown",
                width = "normal",
                get = function(info)  return EasyExperienceBar.global.fontOutline end,
                set = function(info,val) 
                        EasyExperienceBar.global.fontOutline = val
                        EasyExperienceBar:ChangeFont(EasyExperienceBar.global.font)
                    end,
            },
            textures = {
                type = 'select',
                order = 17,
                name = L["Bar Texture"],
                desc = L["Selects the texture used for the bars"],
                dialogControl = 'LSM30_Statusbar',
                values = EasyExperienceBar.LSM:HashTable("statusbar"),
                width = "normal",
                 get = function(info) local values = {}
                    local list = EasyExperienceBar.LSM:List("statusbar")
                    local hashtable = EasyExperienceBar.LSM:HashTable("statusbar")
                    for i,handle in ipairs(list) do
                        values[hashtable[handle]] = handle
                    end
                    local hash = values[EasyExperienceBar.global.bartexture]
                    return hash end,
                set = function(info,val)
                    local hashtable = EasyExperienceBar.LSM:HashTable("statusbar")
                    EasyExperienceBar.global.bartexture = hashtable[val]
                    EasyExperienceBar:ChangeTexture(EasyExperienceBar.global.bartexture)
                    end,
            },
            classColour = {
                type = 'toggle',
                order = 18,
                name = L["Use Class Color"],
                desc = L["Uses the player's class color for the progress bar"],
                width = "full",
                get = function(info)  return EasyExperienceBar.global.classColour end,
                set = function(info,val) EasyExperienceBar.global.classColour = val
                     EasyExperienceBar:ChangeTexture(EasyExperienceBar.global.bartexture)
                    end,
            },
            header4 = {
                type = 'header',
                order = 19,
                name = 'Data',
            },
              resetGuide = {
                order = 20,
                type = "execute",
                name = L["Reset Timers"],
                desc = L["Resets Session and Level time"],
                func =  function (info)
                            EasyExperienceBar:ResetTimes()
                        end
            },
        },
    }
    EasyExperienceBar.AceConfig:RegisterOptionsTable("EasyExperienceBar", options)
    EasyExperienceBar.AceConfigDialog:AddToBlizOptions("EasyExperienceBar", "EasyExperienceBar")
end

function EasyExperienceBar:ResetBar()
        if EasyExperienceBar.global.showMaxLevel and EasyExperienceBar.UpdateTimer and
            not EasyExperienceBar.UpdateTimer:IsCancelled() then
            EasyExperienceBar:CreateTimer()
        end
        if _G.MainStatusTrackingBarContainer then
            if EasyExperienceBar.global.hideXpBar then
                _G.MainStatusTrackingBarContainer:Hide()
            else
                 _G.UIParent.Show(_G.MainStatusTrackingBarContainer)
            end
        end
end

function EasyExperienceBar.EventHandler(self, event, arg1, arg2, arg3, arg4, ...)

    if "PLAYER_ENTERING_WORLD" == event then
        if arg1 or (arg2 and EasyExperienceBar.global.resetReload) then
            EasyExperienceBar.session.gainedXP = 0
            EasyExperienceBar.session.lastXP = _G.UnitXP("player") or 0
            EasyExperienceBar.session.maxXP = _G.UnitXPMax("player") or 0
            EasyExperienceBar.session.startTime = _G.GetTime()
            EasyExperienceBar.session.lastSessionLevelTime = EasyExperienceBar.session.lastSessionLevelTime
            EasyExperienceBar.currentSessionLevelStart = EasyExperienceBar.session.startTime
        end
    elseif "PLAYER_LEVEL_UP" == event then
        EasyExperienceBar.level = arg1 or EasyExperienceBar.level
        EasyExperienceBar.isPlayerMaxLevel = EasyExperienceBar.level >= EasyExperienceBar:GetMaxLevel()

        EasyExperienceBar.session.realLevelTime = 0
        EasyExperienceBar.lastSessionLevelTime = 0
        EasyExperienceBar.currentSessionLevelStart = _G.GetTime()
        EasyExperienceBar.session.maxXP = _G.UnitXPMax("player")

        if EasyExperienceBar.isMaxLevel and not EasyExperienceBar.showMaxLevel then
            EasyExperienceBar.UpdateTimer:Cancel()
        end
     elseif "UPDATE_EXPANSION_LEVEL" == event or "MAX_EXPANSION_LEVEL_UPDATED" == event then
        local minExpLevel, maxExpLevel

        if arg3 then
            minExpLevel = min(arg1, arg2, arg3, arg4)
            maxExpLevel = max(arg1, arg2, arg3, arg4)
        else
            minExpLevel = _G.GetExpansionLevel()
            maxExpLevel = minExpLevel
        end

        EasyExperienceBar.isPlayerMaxLevel = EasyExperienceBar.level >= EasyExperienceBar:GetMaxLevel(maxExpLevel)

        if EasyExperienceBar.level == _G.GetMaxLevelForExpansionLevel(minExpLevel) then
            EasyExperienceBar.session.startTime = _G.GetTime()
        end

        if not EasyExperienceBar.isMaxLevel then
            EasyExperienceBar:CreateTimer()
        end
    elseif "QUEST_LOG_UPDATE" == event or ("UNIT_QUEST_LOG_CHANGED" == event and arg1 == "player") then
        EasyExperienceBar:Update()
    elseif "PLAYER_XP_UPDATE" == event then
        local currentXP = _G.UnitXP("player") or 0
        EasyExperienceBar.session.lastXP = EasyExperienceBar.session.lastXP or currentXP
        local gainedXP = currentXP - EasyExperienceBar.session.lastXP

        if gainedXP < 0 then
            gainedXP =  EasyExperienceBar.session.maxXP - EasyExperienceBar.session.lastXP + currentXP
        end

        EasyExperienceBar.session.gainedXP = EasyExperienceBar.session.gainedXP + gainedXP
        EasyExperienceBar.session.lastXP = currentXP
        EasyExperienceBar.session.maxXP = _G.UnitXPMax("player") or 0
        EasyExperienceBar:Update()
    end
end

function EasyExperienceBar:OnInitialize()
    -- Saved Variables
    EasyExperienceBar.sessionDB = _G.LibStub("AceDB-3.0"):New("EasyExperienceDB")
    EasyExperienceBar.session = EasyExperienceBar.sessionDB.char

    EasyExperienceBar.session = EasyExperienceBar.session or {}
    EasyExperienceBar.session.gainedXP = EasyExperienceBar.session.gainedXP or 0
    EasyExperienceBar.session.lastXP = EasyExperienceBar.session.lastXP or _G.UnitXP("player")
    EasyExperienceBar.session.maxXP = EasyExperienceBar.session.maxXP or _G.UnitXPMax("player")
    EasyExperienceBar.session.startTime = EasyExperienceBar.session.startTime or _G.GetTime()
    EasyExperienceBar.session.realTotalTime = EasyExperienceBar.session.realTotalTime or 0
    EasyExperienceBar.session.realLevelTime = EasyExperienceBar.session.realLevelTime or 0

    EasyExperienceBar.session.lastSessionLevelTime = EasyExperienceBar.session.lastSessionLevelTime or 0
    EasyExperienceBar.lastSessionLevelTime = EasyExperienceBar.session.lastSessionLevelTime
    EasyExperienceBar.currentSessionLevelStart = EasyExperienceBar.session.startTime
    EasyExperienceBar.session.lastSessionTotalTime = EasyExperienceBar.session.realTotalTime
    EasyExperienceBar.currentTotalTimeStart = EasyExperienceBar.session.startTime

    EasyExperienceBar.global = EasyExperienceBar.sessionDB.global
    
    EasyExperienceBar:Options()

    local width = EasyExperienceBar.global.barWidth or 600
    local height = EasyExperienceBar.global.barHeight or 30
    local fontSize = EasyExperienceBar.global.fontSize or 14

    EasyExperienceBar.MainFrame = _G.CreateFrame("Button", "EasyExperienceBar.MainFrame", _G.UIParent,
                  _G.BackdropTemplateMixin and "BackdropTemplate" or nil)
    EasyExperienceBar.MainFrame:SetPoint("TOP", _G.UIParent, -7, -70)
    EasyExperienceBar.MainFrame:SetFrameStrata("BACKGROUND")
    EasyExperienceBar.MainFrame:SetSize(width, height)
    EasyExperienceBar.MainFrame:SetMovable(true)

    EasyExperienceBar.BackgroundBar = EasyExperienceBar:CreateBackgroundBar(EasyExperienceBar.MainFrame)
    EasyExperienceBar.BackgroundBar:SetValue(100)
    EasyExperienceBar.BackgroundBar:SetFrameLevel(10)
    EasyExperienceBar.BackgroundBar:Show()

    EasyExperienceBar.RestedBar = EasyExperienceBar:CreateRestedBar(EasyExperienceBar.MainFrame)
    EasyExperienceBar.RestedBar:SetValue(0)
    EasyExperienceBar.RestedBar:SetFrameLevel(20)
    EasyExperienceBar.RestedBar:Show()

    EasyExperienceBar.QuestBar = EasyExperienceBar:CreateQuestBar(EasyExperienceBar.MainFrame)
    EasyExperienceBar.QuestBar:SetValue(100)
    EasyExperienceBar.QuestBar:SetFrameLevel(30)
    EasyExperienceBar.QuestBar:Show()

    EasyExperienceBar.ProgressBar = EasyExperienceBar:CreateProgressBar(EasyExperienceBar.MainFrame)
    EasyExperienceBar.ProgressBar:SetValue(50)
    EasyExperienceBar.ProgressBar:SetFrameLevel(40)
    EasyExperienceBar.ProgressBar:Show()

    EasyExperienceBar.Texts = EasyExperienceBar:CreateTexts(EasyExperienceBar.ProgressBar)

    if not EasyExperienceBar.isMaxLevel then
        EasyExperienceBar:CreateTimer()
    end
    EasyExperienceBar:RegisterEvents()

    if EasyExperienceBar.global.hideXpBar and _G.MainStatusTrackingBarContainer then
        _G.MainStatusTrackingBarContainer:Hide()
    end

    EasyExperienceBar.MainFrame:SetScript("OnMouseDown", function(this, button)
        if button == "LeftButton" and not EasyExperienceBar.global.lockBar then
            this:StartMoving()
        end
    end)
    EasyExperienceBar.MainFrame:SetScript("OnMouseUp", function(this, button)
        if button == "LeftButton" then
            this:StopMovingOrSizing()
        end
    end)
end

function EasyExperienceBar:CreateTimer()
     EasyExperienceBar.UpdateTimer = _G.C_Timer.NewTicker(0.5, function() EasyExperienceBar.Update() end)
end

function EasyExperienceBar:RegisterEvents()
    EasyExperienceBar.MainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    EasyExperienceBar.MainFrame:RegisterEvent("PLAYER_LEVEL_UP")
    EasyExperienceBar.MainFrame:RegisterEvent("UPDATE_EXPANSION_LEVEL")
    EasyExperienceBar.MainFrame:RegisterEvent("MAX_EXPANSION_LEVEL_UPDATED")
    EasyExperienceBar.MainFrame:RegisterEvent("QUEST_LOG_UPDATE")
    EasyExperienceBar.MainFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    EasyExperienceBar.MainFrame:RegisterEvent("PLAYER_XP_UPDATE")
    EasyExperienceBar.MainFrame:SetScript("OnEvent", EasyExperienceBar.EventHandler)
end

function EasyExperienceBar:CreateProgressBar(parent)
    local startColour = _G.CreateColor(0.335, 0.388, 1.0)
    local endColour =  _G.CreateColor(0.773, 0.380, 1.0)

    if EasyExperienceBar.global.classColour then
        local colourRgb
        if  C_ClassColor then
            colourRgb =  C_ClassColor.GetClassColor(_G.select(2, _G.UnitClass("player")))
        else
           colourRgb =  RAID_CLASS_COLORS[_G.select(2, _G.UnitClass("player"))]
        end
        startColour = _G.CreateColor(colourRgb.r, colourRgb.g, colourRgb.b)
        endColour = _G.CreateColor(colourRgb.r, colourRgb.g, colourRgb.b)
    end

    local progressBar = _G.CreateFrame("StatusBar", nil, EasyExperienceBar.MainFrame,
                _G.BackdropTemplateMixin and "BackdropTemplate")
    progressBar:SetPoint("CENTER", EasyExperienceBar.MainFrame, 0, 0)
    progressBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)

    local texture = progressBar:CreateTexture()
    texture:SetPoint("CENTER")
    texture:SetTexture(EasyExperienceBar.global.bartexture)
    texture:SetGradient("HORIZONTAL", startColour, endColour)

    progressBar:SetStatusBarTexture(texture)
    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(0)
    return progressBar
end

function EasyExperienceBar:CreateBackgroundBar(parent, scale)
    local backgroundBar = _G.CreateFrame("StatusBar", nil, EasyExperienceBar.MainFrame,
             _G.BackdropTemplateMixin and "BackdropTemplate")
    backgroundBar:SetPoint("CENTER", EasyExperienceBar.MainFrame, 0, 0)
    backgroundBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)

    backgroundBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
    backgroundBar:SetStatusBarColor(0, 0, 0, 0.5)
    backgroundBar:SetMinMaxValues(0, 100)
    backgroundBar:SetValue(100)
    return backgroundBar
end

function EasyExperienceBar:CreateRestedBar(parent, scale)
    local restedBar = _G.CreateFrame("StatusBar", nil, EasyExperienceBar.MainFrame,
                _G.BackdropTemplateMixin and "BackdropTemplate")
    restedBar:SetPoint("CENTER", EasyExperienceBar.MainFrame, 0, 0)
    restedBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)

    restedBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
    restedBar:SetStatusBarColor(0.309, 0.562, 1.0, 0.5)
    restedBar:SetMinMaxValues(0, 100)
    restedBar:SetValue(100)
    return restedBar
end

function EasyExperienceBar:CreateQuestBar(parent, scale)
    local questBar = _G.CreateFrame("StatusBar", nil, EasyExperienceBar.MainFrame,
                _G.BackdropTemplateMixin and "BackdropTemplate")
    questBar:SetPoint("CENTER", EasyExperienceBar.MainFrame, 0, 0)
    questBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)

    questBar:SetStatusBarTexture(EasyExperienceBar.global.bartexture)
    questBar:SetStatusBarColor(1.0, 0.589, 0.0, 1)
    questBar:SetMinMaxValues(0, 100)
    questBar:SetValue(100)
    return questBar
end

 function EasyExperienceBar:CreateTexts(frame, scale)
    local fontOutline
    if "NONE" ==  EasyExperienceBar.global.fontOutline then
        fontOutline = nil
    else
        fontOutline = EasyExperienceBar.global.fontOutline
    end
    local levelText = frame:CreateFontString(nil, nil, "GameTooltipText")
    levelText:SetPoint("LEFT", frame, "LEFT" , 5, 0)
    levelText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize, fontOutline)
    levelText:SetWidth(100)
    levelText:SetJustifyH("LEFT")
    levelText:SetTextColor(1,1,1)
    levelText:SetText("Level Test")

    local progressText = frame:CreateFontString(nil, nil, "GameTooltipText")
    progressText:SetPoint("CENTER", frame, "CENTER" , 0, 0)
    progressText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize, fontOutline)
    progressText:SetWidth(350)
    progressText:SetJustifyH("CENTER")
    progressText:SetTextColor(1,1,1)
    progressText:SetText("Progress Test")

    local percentText = frame:CreateFontString(nil, nil, "GameTooltipText")
    percentText:SetPoint("RIGHT", frame, "RIGHT" , -5, 0)
    percentText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize, fontOutline)
    percentText:SetJustifyH("RIGHT")
    percentText:SetWidth(150)
    percentText:SetText("Percent Test")

    local levelTimeText = frame:CreateFontString(nil, nil, "GameTooltipText")
    levelTimeText:SetPoint("TOPLEFT", frame, "TOPLEFT" , 5, 15)
    levelTimeText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    levelTimeText:SetWidth(300)
    levelTimeText:SetJustifyH("LEFT")
    levelTimeText:SetText("Level Time")

    local sessionTimeText = frame:CreateFontString(nil, nil, "GameTooltipText")
    sessionTimeText:SetPoint("TOPRIGHT", frame, "TOPRIGHT" , 05, 15)
    sessionTimeText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    sessionTimeText:SetJustifyH("RIGHT")
    sessionTimeText:SetWidth(300)
    sessionTimeText:SetText("Session Time")

    local timeToLevelText = frame:CreateFontString(nil, nil, "GameTooltipText")
    timeToLevelText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT" , 5, -20)
    timeToLevelText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    timeToLevelText:SetWidth(320)
    timeToLevelText:SetJustifyH("LEFT")
    timeToLevelText:SetText("Time To Level")
    timeToLevelText:SetWordWrap(false)

    local statText = frame:CreateFontString(nil, nil, "GameTooltipText")
    statText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT" , -5, -20)
    statText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    statText:SetJustifyH("RIGHT")
    statText:SetWidth(280)
    statText:SetText("Stats")


    return { levelText = levelText,
             progressText = progressText,
             percentText = percentText,
             levelTimeText = levelTimeText,
             sessionTimeText = sessionTimeText,
             timeToLevelText = timeToLevelText,
             statText = statText, }
 end

function EasyExperienceBar:Resize()
    local fontOutline
    if "NONE" ==  EasyExperienceBar.global.fontOutline then
        fontoutline = nil
    else
        fontOutline = EasyExperienceBar.global.fontOutline
    end

    EasyExperienceBar.MainFrame:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight )
    EasyExperienceBar.ProgressBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)
    EasyExperienceBar.BackgroundBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)
    EasyExperienceBar.RestedBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)
    EasyExperienceBar.QuestBar:SetSize(EasyExperienceBar.global.barWidth, EasyExperienceBar.global.barHeight)
    EasyExperienceBar.Texts.levelText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize, fontOutline)
    EasyExperienceBar.Texts.progressText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize, fontOutline)
    EasyExperienceBar.Texts.percentText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize, fontOutline)
    EasyExperienceBar.Texts.levelTimeText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    EasyExperienceBar.Texts.sessionTimeText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    EasyExperienceBar.Texts.timeToLevelText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    EasyExperienceBar.Texts.statText:SetFont(EasyExperienceBar.global.font, EasyExperienceBar.global.fontSize - 1, fontOutline)
end


function EasyExperienceBar:ChangeFont(font)
    local fontOutline
    if "NONE" ==  EasyExperienceBar.global.fontOutline then
        fontOutline = nil
    else
        fontOutline = EasyExperienceBar.global.fontOutline
    end
    if font then 
        EasyExperienceBar.Texts.levelText:SetFont(font, EasyExperienceBar.global.fontSize, fontOutline)
        EasyExperienceBar.Texts.progressText:SetFont(font, EasyExperienceBar.global.fontSize, fontOutline)
        EasyExperienceBar.Texts.percentText:SetFont(font, EasyExperienceBar.global.fontSize, fontOutline)
        EasyExperienceBar.Texts.levelTimeText:SetFont(font, EasyExperienceBar.global.fontSize - 1, fontOutline)
        EasyExperienceBar.Texts.sessionTimeText:SetFont(font, EasyExperienceBar.global.fontSize - 1, fontOutline)
        EasyExperienceBar.Texts.timeToLevelText:SetFont(font, EasyExperienceBar.global.fontSize - 1, fontOutline)
        EasyExperienceBar.Texts.statText:SetFont(font, EasyExperienceBar.global.fontSize - 1, fontOutline)
    end
end

function EasyExperienceBar:ChangeTexture(bartexture)
    local startColour = _G.CreateColor(0.335, 0.388, 1.0)
    local endColour =  _G.CreateColor(0.773, 0.380, 1.0)

    if EasyExperienceBar.global.classColour then
        local colourRgb
        if  C_ClassColor then
           colourRgb = C_ClassColor.GetClassColor( _G.UnitClass("player"))
        else
           colourRgb =  RAID_CLASS_COLORS[_G.select(2, _G.UnitClass("player"))]
        end
        startColour = _G.CreateColor(colourRgb.r, colourRgb.g, colourRgb.b)
        endColour = _G.CreateColor(colourRgb.r, colourRgb.g, colourRgb.b)
    end

    if bartexture then
        local progressTexture = EasyExperienceBar.ProgressBar:CreateTexture()
        progressTexture:SetPoint("CENTER")
        progressTexture:SetTexture(EasyExperienceBar.global.bartexture)
        progressTexture:SetGradient("HORIZONTAL", startColour, endColour)
        EasyExperienceBar.ProgressBar:SetStatusBarTexture(progressTexture)

        local questTexture = EasyExperienceBar.QuestBar:CreateTexture()
        questTexture:SetPoint("CENTER")
        questTexture:SetTexture(EasyExperienceBar.global.bartexture)
        local tstart = _G.CreateColor(1.0, 0.589, 0.0, 1)
        local tend = _G.CreateColor(1.0, 0.589, 0.0, 1)
        questTexture:SetGradient("HORIZONTAL", tstart, tend)
        EasyExperienceBar.QuestBar:SetStatusBarTexture(questTexture)
    end
end

 function EasyExperienceBar:Update()
     local show = not EasyExperienceBar.isPlayerMaxLevel or EasyExperienceBar.global.showMaxLevel

    if show then
        if not EasyExperienceBar.BackgroundBar:IsShown() then
            EasyExperienceBar.BackgroundBar:Show()
            EasyExperienceBar.QuestBar:Show()
            EasyExperienceBar.RestedBar:Show()
            EasyExperienceBar.ProgressBar:Show()
        end
        EasyExperienceBar:UpdateQuestXP()
        EasyExperienceBar:CalculateValues()
        EasyExperienceBar:UpdateTexts()
    elseif EasyExperienceBar.BackgroundBar:IsShown() then
        EasyExperienceBar.BackgroundBar:Hide()
        EasyExperienceBar.QuestBar:Hide()
        EasyExperienceBar.RestedBar:Hide()
        EasyExperienceBar.ProgressBar:Hide()
    return true
    end
 end

function EasyExperienceBar:UpdateTexts()   
    local textDisplays = EasyExperienceBar.Texts
    local textValues = EasyExperienceBar.customTexts

    textDisplays.levelText:SetText(textValues.c1)
    textDisplays.progressText:SetText(textValues.c2)
    textDisplays.percentText:SetText(textValues.c3)
    textDisplays.timeToLevelText:SetText(textValues.c4)
    textDisplays.statText:SetText(textValues.c5)
    textDisplays.levelTimeText:SetText(textValues.c6)
    textDisplays.sessionTimeText:SetText(textValues.c7)
end


function EasyExperienceBar:CalculateValues()
    local level = _G.UnitLevel("player")
    local totalTime = EasyExperienceBar.session.realTotalTime or 0
    local levelTime = EasyExperienceBar.session.realLevelTime or 0
    local currentTime = _G.GetTime()
    local hourlyXP, timeToLevel = 0, 0
    local gainedXP = EasyExperienceBar.session.gainedXP or 0
    local currentXP = _G.UnitXP("player") or 0
    local totalXP = _G.UnitXPMax("player") or 0
    local remainingXP = totalXP - currentXP
    local restedXP = _G.GetXPExhaustion() or 0
    local questXP = EasyExperienceBar.questXP or 0
    local completeXP = EasyExperienceBar.completeXP or 0
    local incompleteXP = EasyExperienceBar.incompleteXP or 0

    if EasyExperienceBar.global.levelTimeText  then
        totalTime = (currentTime - EasyExperienceBar.currentTotalTimeStart) +
                      EasyExperienceBar.session.lastSessionTotalTime
        levelTime = (currentTime - EasyExperienceBar.currentSessionLevelStart) +
                   EasyExperienceBar.lastSessionLevelTime
        EasyExperienceBar.session.lastSessionLevelTime = levelTime
    end

    EasyExperienceBar.session.realLevelTime = levelTime
    EasyExperienceBar.session.realTotalTime = totalTime

    if EasyExperienceBar.global.sessionTimeText or  EasyExperienceBar.global.showXpHourText  then
        if EasyExperienceBar.session.startTime > 0 then
            EasyExperienceBar.sessionTime = currentTime - EasyExperienceBar.session.startTime

            local coeff = EasyExperienceBar.sessionTime / 3600

            if coeff > 0 and gainedXP > 0 then
                hourlyXP = ceil(gainedXP / coeff)
                timeToLevel = ceil(remainingXP / hourlyXP * 3600)
            end
        end
    end

    local allstates = {
        show = true,
        changed = true,
        progressType = "static",
        value = currentXP,
        total = totalXP,

        -- Usable Variables
        level = level,
        currentXP = currentXP,
        totalXP = totalXP,
        remainingXP = remainingXP,
        restedXP = restedXP,
        questXP = questXP,
        completeXP = completeXP,
        incompleteXP = incompleteXP,
        hourlyXP = hourlyXP,
        timeToLevel = timeToLevel,
        timeToLevelText = timeToLevel > 0 and EasyExperienceBar:FormatTime(timeToLevel) or "--",
        totalTime = totalTime,
        totalTimeText = EasyExperienceBar:FormatTime(totalTime),
        levelTime = levelTime,
        levelTimeText = EasyExperienceBar:FormatTime(levelTime),
        sessionTime = EasyExperienceBar.sessionTime,
        sessionTimeText = EasyExperienceBar:FormatTime(EasyExperienceBar.sessionTime),
        percentXP = totalXP > 0 and ((currentXP / totalXP) * 100) or 0,
        percentremaining = totalXP > 0 and ((remainingXP / totalXP) * 100) or 0,
        percentrested = totalXP > 0 and ((restedXP / totalXP) * 100) or 0,
        percentquest = totalXP > 0 and ((questXP / totalXP) * 100) or 0,
        percentcomplete = totalXP > 0 and ((completeXP / totalXP) * 100) or 0,
        percentincomplete = totalXP > 0 and ((incompleteXP / totalXP) * 100) or 0,
        totalpercentcomplete = totalXP > 0 and (((completeXP + currentXP) / totalXP) * 100) or 0,
    }

    local questXP = 0
    if EasyExperienceBar.global.questXpBar  then
        questXP = allstates.percentcomplete
    end
    EasyExperienceBar.ProgressBar:SetValue(allstates.percentXP)
    EasyExperienceBar.QuestBar:SetValue(min(allstates.percentXP + questXP, 100))
    EasyExperienceBar.RestedBar:SetValue(min(allstates.percentXP +
         questXP + allstates.percentrested, 100))

    EasyExperienceBar:UpdateCustomTexts(allstates)

    return true
end

function EasyExperienceBar:UpdateQuestXP()
    local numQ, _ = EasyExperienceBar.GetNumQuestLogEntries()
    local questXP = 0
    local completeXP = 0
    local incompleteXP = 0
    local questID, rewardXP

    local currentQuestID = EasyExperienceBar.GetSelectedQuest()

    for i = 1, numQ do
         EasyExperienceBar.SetSelectedQuest(i)
         questID = EasyExperienceBar.GetQuestIDForLogIndex(i) 

         if questID > 0 then
             rewardXP = _G.GetQuestLogRewardXP(questID) or 0

             if rewardXP > 0 then
                questXP = questXP + rewardXP

                 if EasyExperienceBar.IsQuestComplete(questID) or EasyExperienceBar.QuestReadyForTurnIn(questID) then
                     completeXP = completeXP + rewardXP
                 else
                     incompleteXP = incompleteXP + rewardXP
                 end
             end
         end
    end

    if currentQuestID then 
        EasyExperienceBar.SetSelectedQuest(currentQuestID)
    end

    EasyExperienceBar.questXP = questXP
    EasyExperienceBar.completeXP = completeXP
    EasyExperienceBar.incompleteXP = incompleteXP

end

function EasyExperienceBar:round(num, decimals)
    local mult = 10^(decimals or 0)

    return Round(num * mult) / mult
end

function EasyExperienceBar:FormatTime(time, format)
    if time < 60 then
        return "< 1" .. L["min_abbrev"]
    end

    local d, h, m, s = _G.ChatFrame_TimeBreakDown(time)
    local dAbbrev = L["day_abbrev"]
    local hAbbrev = L["hour_abbrev"]
    local mAbbrev = L["min_abbrev"]

    local parts = {}
    if d > 0 then
        parts[#parts + 1] = d .. dAbbrev
    end
    if d > 0 or h > 0 then
        parts[#parts + 1] = h .. hAbbrev
    end
    parts[#parts + 1] = m .. mAbbrev

    local text = table.concat(parts, " ")

    if text == "" then
        return "< 1" .. mAbbrev
    end

    return text
end

EasyExperienceBar.tickerRTP = EasyExperienceBar.tickerRTP or nil
EasyExperienceBar.requestingTimePlayed = false

function EasyExperienceBar:ClearTickerRTP()
    if EasyExperienceBar.tickerRTP then
        EasyExperienceBar.tickerRTP:Cancel()
        EasyExperienceBar.tickerRTP = nil
    end

    EasyExperienceBar.requestingTimePlayed = false
end

EasyExperienceBar.customTexts = {
    c1 = L["Level "] .. EasyExperienceBar.level,
    c2 = "0 / 0 (0)",
    c3 = "0%",
    c4 = "",
    c5 = "",
    c6 = "",
    c7 = "",
}

function EasyExperienceBar:UpdateCustomTexts(state)
    local c1, c2, c3, c4, c5, c6, c7
    local s = state or EasyExperienceBar.state
    local isMaxLevel = EasyExperienceBar.isPlayerMaxLevel

    c1 = L["Level "] .. (s.level or _G.UnitLevel("player"))

    if isMaxLevel then
        c2 = L["Max Level"]
    else
        c2 = string.format("%s / %s (%s)", _G.FormatLargeNumber(s.currentXP or 0),
            _G.FormatLargeNumber(s.totalXP or 0), _G.FormatLargeNumber(s.remainingXP or 0))
    end

    c3 = string.format("%s%%" .. ((s.percentcomplete or 0) > 0 and " (%s%%)" or ""),
       EasyExperienceBar:round(s.percentXP or 0, 1), EasyExperienceBar:round(s.totalpercentcomplete or 0, 1))

    if not isMaxLevel then

        if EasyExperienceBar.global.showXpHourText then
            local hourlyXP = s.hourlyXP or 0
            local divisor = tonumber(L["large_number_divisor"]) or 1000
            local suffix = L["large_number_suffix"] or "K"

            c4 = string.format(L["Leveling in:"] .. " %s (%s%s " .. L["XP/Hour"] .. ")", s.timeToLevelText or "",
               hourlyXP > divisor and EasyExperienceBar:round(hourlyXP / divisor, 1) or
               _G.FormatLargeNumber(hourlyXP), hourlyXP > divisor and suffix or "")
        end

        if EasyExperienceBar.global.questRestedText then
            c5 = string.format(L["Completed:"] .. " |cFFFF9700%s%%|r - " .. L["Rested:"] .. " |cFF4F90FF%s%%|r",
               EasyExperienceBar:round(s.percentcomplete or 0, 1), EasyExperienceBar:round(s.percentrested or 0, 1))
        end
    end

    if EasyExperienceBar.global.levelTimeText then
        if isMaxLevel then
            c6 = L["Time played:"] .. " " .. (s.totalTimeText or "")
        else
            c6 = L["Time this level:"] .. " " .. (s.levelTimeText or "")
        end
    end

    if EasyExperienceBar.global.sessionTimeText then
        c7 = L["Time this session:"] .. " " .. (s.sessionTimeText or "")
    end

    EasyExperienceBar.customTexts = {
        c1 = c1,
        c2 = c2,
        c3 = c3,
        c4 = c4,
        c5 = c5,
        c6 = c6,
        c7 = c7,
    }
end

function EasyExperienceBar:ResetTimes()
    EasyExperienceBar.session.gainedXP = 0
    EasyExperienceBar.session.lastXP = _G.UnitXP("player") or 0
    EasyExperienceBar.session.maxXP = _G.UnitXPMax("player") or 0
    EasyExperienceBar.session.startTime = _G.GetTime()
    EasyExperienceBar.session.lastSessionLevelTime = 0
    EasyExperienceBar.lastSessionLevelTime = 0
    EasyExperienceBar.currentSessionLevelStart = EasyExperienceBar.session.startTime
    EasyExperienceBar.session.lastSessionTotalTime = 0
    EasyExperienceBar.currentTotalTimeStart = EasyExperienceBar.session.startTime
    EasyExperienceBar:Update()
end

