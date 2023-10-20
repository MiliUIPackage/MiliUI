local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local I = Cell.iFuncs
local LCG = LibStub("LibCustomGlow-1.0")

local UnitIsVisible = UnitIsVisible
local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local UnitIsEnemy = UnitIsEnemy
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

-------------------------------------------------
-- show / hide
-------------------------------------------------
local function HideCasts(b)
    b.indicators.targetedSpells:Hide()
end

local function ShowCasts(b, inListFound, start, duration, icon, isChanneling, num)
    b.indicators.targetedSpells.cooldown:SetReverse(not isChanneling)
    b.indicators.targetedSpells:SetCooldown(start, duration, icon, num)
    -- glow if not 0
    if inListFound then
        b.indicators.targetedSpells:ShowGlow(unpack(Cell.vars.targetedSpellsGlow))
    else
        b.indicators.targetedSpells:ShowGlow()
    end
end

-------------------------------------------------
-- targeted spells
-------------------------------------------------
local casts, castsOnUnit = {}, {}
local showAllSpells

local function GetCastsOnUnit(guid)
    if castsOnUnit[guid] then
        wipe(castsOnUnit[guid])
    else
        castsOnUnit[guid] = {}
    end

    for sourceGUID, castInfo in pairs(casts) do
        if guid == castInfo["targetGUID"] then
            if castInfo["endTime"] > GetTime() then -- not expired
                tinsert(castsOnUnit[guid], castInfo)
            else
                casts[sourceGUID] = nil
            end
        end
    end

    return castsOnUnit[guid]
end

local function UpdateCastsOnUnit(guid)
    local allCasts = 0
    local startTime, endTime, spellId, icon, isChanneling
    local inListFound

    for _, castInfo in pairs(GetCastsOnUnit(guid)) do
        allCasts = allCasts + 1

        if not endTime then --! init
            startTime, endTime, spellId, icon, isChanneling = castInfo["startTime"], castInfo["endTime"], castInfo["spellId"], castInfo["icon"], castInfo["isChanneling"]
        else
            spellId = castInfo["spellId"]
            if Cell.vars.targetedSpellsList[spellId] then --! [IN LIST]
                if not inListFound or endTime > castInfo["endTime"] then --! NOT FOUND BEFORE or SHORTER DURATION
                    startTime, endTime, icon, isChanneling = castInfo["startTime"], castInfo["endTime"], castInfo["icon"], castInfo["isChanneling"]
                end
            elseif not inListFound and endTime > castInfo["endTime"] then --! [NOT IN LIST] NOT FOUND BEFORE and SHORTER DURATION
                startTime, endTime, icon, isChanneling = castInfo["startTime"], castInfo["endTime"], castInfo["icon"], castInfo["isChanneling"]
            end
        end

        if Cell.vars.targetedSpellsList[spellId] then
            inListFound = true
        end
    end

    if allCasts == 0 then
        F:HandleUnitButton("guid", guid, HideCasts)
    else
        F:HandleUnitButton("guid", guid, ShowCasts, inListFound, startTime, endTime-startTime, icon, isChanneling, allCasts)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, sourceUnit)
    if event == "ENCOUNTER_END" then
        wipe(casts)
        wipe(castsOnUnit)
        F:IterateAllUnitButtons(function(b)
            b.indicators.targetedSpells:Hide()
        end, true)
        return
    end

    if sourceUnit and UnitIsEnemy(sourceUnit, "player") then
        local sourceGUID = UnitGUID(sourceUnit)
        local previousTarget

        -- check if expired
        if casts[sourceGUID] and casts[sourceGUID]["endTime"] <= GetTime() then
            previousTarget = casts[sourceGUID]["targetGUID"]
            casts[sourceGUID] = nil
            UpdateCastsOnUnit(previousTarget)
        end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED"  or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
            or event == "UNIT_TARGET" or event == "NAME_PLATE_UNIT_ADDED" then
            local isChanneling
            -- name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId
            local name, _, texture, startTimeMS, endTimeMS, _, _, notInterruptible, spellId = UnitCastingInfo(sourceUnit)
            if not name then
                -- name, text, texture, startTimeMS, endTimeMS, isTradeSkill, notInterruptible, spellId
                name, _, texture, startTimeMS, endTimeMS, _, notInterruptible, spellId = UnitChannelInfo(sourceUnit)
                isChanneling = true
            end

            -- print(name, spellId)

            if casts[sourceGUID] then previousTarget = casts[sourceGUID]["targetGUID"] end

            if spellId and (Cell.vars.targetedSpellsList[spellId] or showAllSpells) then
                local targetUnit = sourceUnit.."target"
                targetUnit = F:GetTargetUnitID(targetUnit) -- units in group (players/pets), no npcs
                if targetUnit and UnitIsVisible(targetUnit) then
                    local targetGUID = UnitGUID(targetUnit)
                    casts[sourceGUID] = {
                        ["startTime"] = startTimeMS/1000,
                        ["endTime"] = endTimeMS/1000,
                        ["spellId"] = spellId,
                        ["icon"] = texture,
                        ["targetGUID"] = targetGUID,
                        ["isChanneling"] = isChanneling,
                        -- ["sourceUnit"] = sourceUnit,
                        -- ["targetUnit"] = targetUnit,
                    }
                    UpdateCastsOnUnit(targetGUID)
                    
                    -- NOTE: double check
                    C_Timer.After(0.1, function()
                        local newSourceGUID = UnitGUID(sourceUnit) -- NOTE: if sourceUnit == "target", it can change
                        if newSourceGUID == sourceGUID and not UnitIsUnit(sourceUnit.."target", targetUnit) then
                            -- print("old:", sourceUnit, targetUnit)
                            if casts[sourceGUID] then
                                -- update new
                                local newTarget = F:GetTargetUnitID(sourceUnit.."target")
                                if newTarget and UnitIsVisible(newTarget) then
                                    -- print("new:", sourceUnit, newTarget)
                                    newTarget = UnitGUID(newTarget)
                                    casts[sourceGUID]["targetGUID"] = newTarget
                                    UpdateCastsOnUnit(newTarget)
                                else
                                    casts[sourceGUID] = nil
                                end
                                -- update old
                                UpdateCastsOnUnit(targetGUID)
                            end
                        end
                    end)
                end
            end
            if previousTarget then UpdateCastsOnUnit(previousTarget) end

        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "NAME_PLATE_UNIT_REMOVED" then
            if casts[sourceGUID] then
                previousTarget = casts[sourceGUID]["targetGUID"]
                casts[sourceGUID] = nil
                UpdateCastsOnUnit(previousTarget)
            end
        end
    end
end)

function I:CreateTargetedSpells(parent)
    local frame = I:CreateAura_BorderIcon(parent:GetName().."TargetedSpells", parent.widget.overlayFrame, 2)
    parent.indicators.targetedSpells = frame
    frame:Hide()

    frame.cooldown:SetScript("OnCooldownDone", function()
        frame:Hide()
    end)

    function frame:SetCooldown(start, duration, icon, count)
        frame.duration:Hide()

        if count ~= 1 then
            frame.stack:Show()
            frame.stack:SetText(count)
        else
            frame.stack:Hide()
        end

        frame.border:Show()
        frame.cooldown:Show()
        frame.cooldown:SetSwipeColor(unpack(Cell.vars.targetedSpellsGlow[2]))
        frame.cooldown:SetCooldown(start, duration)
        frame.icon:SetTexture(icon)
        frame:Show()
    end

    function frame:SetFont(font, size, flags, anchor, xOffset, yOffset)
        I:SetFont(frame.stack, frame, font, size, flags, anchor, xOffset, yOffset)
    end

    function frame:ShowGlow(glowType, color, arg1, arg2, arg3, arg4)
        if glowType == "Normal" then
            LCG.PixelGlow_Stop(parent.widget.tsGlowFrame)
            LCG.AutoCastGlow_Stop(parent.widget.tsGlowFrame)
            LCG.ProcGlow_Stop(parent.widget.tsGlowFrame)
            LCG.ButtonGlow_Start(parent.widget.tsGlowFrame, color)
        elseif glowType == "Pixel" then
            LCG.ButtonGlow_Stop(parent.widget.tsGlowFrame)
            LCG.AutoCastGlow_Stop(parent.widget.tsGlowFrame)
            LCG.ProcGlow_Stop(parent.widget.tsGlowFrame)
            -- color, N, frequency, length, thickness
            LCG.PixelGlow_Start(parent.widget.tsGlowFrame, color, arg1, arg2, arg3, arg4)
        elseif glowType == "Shine" then
            LCG.ButtonGlow_Stop(parent.widget.tsGlowFrame)
            LCG.PixelGlow_Stop(parent.widget.tsGlowFrame)
            LCG.ProcGlow_Stop(parent.widget.tsGlowFrame)
            -- color, N, frequency, scale
            LCG.AutoCastGlow_Start(parent.widget.tsGlowFrame, color, arg1, arg2, arg3)
        elseif glowType == "Proc" then
            LCG.ButtonGlow_Stop(parent.widget.tsGlowFrame)
            LCG.PixelGlow_Stop(parent.widget.tsGlowFrame)
            LCG.AutoCastGlow_Stop(parent.widget.tsGlowFrame)
            -- color, duration
            LCG.ProcGlow_Start(parent.widget.tsGlowFrame, {color=color, duration=arg1, startAnim=false})
        else
            LCG.ButtonGlow_Stop(parent.widget.tsGlowFrame)
            LCG.PixelGlow_Stop(parent.widget.tsGlowFrame)
            LCG.AutoCastGlow_Stop(parent.widget.tsGlowFrame)
            LCG.ProcGlow_Stop(parent.widget.tsGlowFrame)
        end
    end

    frame:SetScript("OnHide", function()
        LCG.ButtonGlow_Stop(parent.widget.tsGlowFrame)
        LCG.PixelGlow_Stop(parent.widget.tsGlowFrame)
        LCG.AutoCastGlow_Stop(parent.widget.tsGlowFrame)
        LCG.ProcGlow_Stop(parent.widget.tsGlowFrame)
    end)

    function frame:ShowGlowPreview()
        frame:ShowGlow(unpack(Cell.vars.targetedSpellsGlow))
    end

    function frame:HideGlowPreview()
        LCG.ButtonGlow_Stop(parent.widget.tsGlowFrame)
        LCG.PixelGlow_Stop(parent.widget.tsGlowFrame)
        LCG.AutoCastGlow_Stop(parent.widget.tsGlowFrame)
        LCG.ProcGlow_Stop(parent.widget.tsGlowFrame)
    end
end

-- NOTE: in case there's a casting spell, hide!
local function EnterLeaveInstance()
    F:IterateAllUnitButtons(function(b)
        b.indicators.targetedSpells:Hide()
    end)
end

function I:EnableTargetedSpells(enabled)
    if enabled then
        -- UNIT_SPELLCAST_DELAYED UNIT_SPELLCAST_FAILED UNIT_SPELLCAST_FAILED_QUIET UNIT_SPELLCAST_INTERRUPTED UNIT_SPELLCAST_START UNIT_SPELLCAST_STOP
        -- UNIT_SPELLCAST_CHANNEL_START UNIT_SPELLCAST_CHANNEL_STOP UNIT_SPELLCAST_CHANNEL_UPDATE
        -- UNIT_TARGET ENCOUNTER_END
        
        eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
        eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
        
        -- eventFrame:RegisterEvent("UNIT_TARGET") --! Fired when the target of yourself, raid, and party members change, Should also work for 'pet' and 'focus'.
        eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
        
        eventFrame:RegisterEvent("ENCOUNTER_END")
        
        Cell:RegisterCallback("EnterInstance", "TargetedSpells_EnterInstance", EnterLeaveInstance)
        Cell:RegisterCallback("LeaveInstance", "TargetedSpells_LeaveInstance", EnterLeaveInstance)
    else
        eventFrame:UnregisterAllEvents()
        
        Cell:UnregisterCallback("EnterInstance", "TargetedSpells_EnterInstance")
        Cell:UnregisterCallback("LeaveInstance", "TargetedSpells_LeaveInstance")
        
        F:IterateAllUnitButtons(function(b)
            b.indicators.targetedSpells:Hide()
        end)
    end
end

function I:ShowAllTargetedSpells(showAll)
    showAllSpells = showAll
end