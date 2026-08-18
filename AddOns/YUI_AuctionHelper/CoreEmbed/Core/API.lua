local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...
YUI.API = YUI.API or {}
YUI.WOW_API = {}
local API = YUI.WOW_API

API.Constants = {
    TraitConsts = {
        STARTER_BUILD_TRAIT_CONFIG_ID = Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
    }
}

local isRetail = YUI.IsRetail
local isWrath = YUI.IsWrath
local isMists = YUI.IsMists
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetItemIcon = GetItemIcon

-------------------------------------------------------------------------------
-- System & Frame
-------------------------------------------------------------------------------
function API.GetAddOnMetadata(name, field)
    local System = YUI.API and YUI.API.System
    if System and System.GetAddOnMetadata then
        return System.GetAddOnMetadata(name, field)
    end

    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, field)
    end

    return GetAddOnMetadata(name, field)
end

function API.GetPhysicalScreenSize()
    if GetPhysicalScreenSize then
        return GetPhysicalScreenSize()
    end
    return UIParent:GetWidth(), UIParent:GetHeight()
end

function API.InCombatLockdown()
    return InCombatLockdown()
end

function API.GetTime()
    return GetTime()
end

function API.IsShiftKeyDown()
    return IsShiftKeyDown()
end

function API.IsAltKeyDown()
    return IsAltKeyDown()
end

function API.IsControlKeyDown()
    return IsControlKeyDown()
end

function API.SecureCallFunction(func, ...)
    if not func then return nil end
    if securecallfunction then
        return securecallfunction(func, ...)
    end
    return func(...)
end

function API.SecureCallMethod(object, method, ...)
    if not object or not method then return nil end
    if securecallmethod then
        return securecallmethod(object, method, ...)
    end

    local func = object[method]
    if func then
        return func(object, ...)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Retail castbar taint diagnostics
-------------------------------------------------------------------------------
local CastBarDiag = {
    enabled = false,
    hooksInstalled = false,
    hookRetryPending = false,
    sequence = 0,
    lastAction = nil,
    lastActionTime = nil,
    logging = false,
}

API.CastBarDiag = CastBarDiag

local function CastBarDiagPrint(...)
    if YUI and YUI.Print then
        YUI:Print("|cff66c6ffCastDiag:|r", ...)
    else
        print("CastDiag:", ...)
    end
end

local function CastBarDiagBool(value)
    if value == nil then return "nil" end
    return value and "true" or "false"
end

local function CastBarDiagValue(value)
    local valueType = type(value)
    if value == nil then
        return "nil"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return value
    end
    return valueType
end

local function CastBarDiagReadField(frame, field)
    if not frame then return "no-frame" end
    local ok, value = pcall(function()
        return frame[field]
    end)
    if not ok then return "error" end
    return CastBarDiagValue(value)
end

local function CastBarDiagReadMethod(frame, method)
    if not frame then return "no-frame" end
    local methodOK, methodFunc = pcall(function()
        return frame[method]
    end)
    if not methodOK then return "error" end
    if not methodFunc then return "no-method" end

    local ok, value = pcall(methodFunc, frame)
    if not ok then return "error" end
    return CastBarDiagValue(value)
end

local function CastBarDiagSecretState(frame, field)
    if not frame then return "no-frame" end
    local ok, value = pcall(function()
        return frame[field]
    end)
    if not ok then return "error" end
    if value == nil then return "nil" end

    if issecretvalue then
        local secretOK, isSecret = pcall(issecretvalue, value)
        if not secretOK then return "error" end
        if isSecret then return "secret" end
    end

    return "normal"
end

local function CastBarDiagCanAccessSecrets()
    if not canaccesssecrets then return "n/a" end
    local ok, result = pcall(canaccesssecrets)
    if not ok then return "error" end
    return CastBarDiagBool(result)
end

local function CastBarDiagCanAccessCastingBarTypeInfo()
    if not canaccesstable then return "n/a" end
    local ok, result = pcall(function()
        if not CastingBarTypeInfo then return nil end
        return canaccesstable(CastingBarTypeInfo)
    end)
    if not ok then return "error" end
    return CastBarDiagBool(result)
end

local function CastBarDiagGetFrame(globalName)
    local ok, frame = pcall(function()
        return _G[globalName]
    end)
    if not ok then return nil end
    return frame
end

local function CastBarDiagSchedule(context)
    if not isRetail or not CastBarDiag.enabled then return end

    API.LogCastBarDiag(context .. " now")

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            API.LogCastBarDiag(context .. " +0")
        end)
        C_Timer.After(0.2, function()
            API.LogCastBarDiag(context .. " +0.2")
        end)
    end
end

local function CastBarDiagInstallHooks()
    if not isRetail or CastBarDiag.hooksInstalled then return end
    if not hooksecurefunc then return end

    local overlay = CastBarDiagGetFrame("OverlayPlayerCastingBarFrame")
    if not overlay then
        if not CastBarDiag.hookRetryPending and C_Timer and C_Timer.After then
            CastBarDiag.hookRetryPending = true
            C_Timer.After(1, function()
                CastBarDiag.hookRetryPending = false
                CastBarDiagInstallHooks()
            end)
        end
        return
    end

    local ok, err = pcall(function()
        if overlay.StartReplacingPlayerBarAt then
            hooksecurefunc(overlay, "StartReplacingPlayerBarAt", function()
                if not CastBarDiag.enabled then return end
                CastBarDiag.sequence = CastBarDiag.sequence + 1
                API.LogCastBarDiag("Overlay.StartReplacingPlayerBarAt after")
            end)
        end

        if overlay.EndReplacingPlayerBar then
            hooksecurefunc(overlay, "EndReplacingPlayerBar", function()
                if not CastBarDiag.enabled then return end
                CastBarDiag.sequence = CastBarDiag.sequence + 1
                API.LogCastBarDiag("Overlay.EndReplacingPlayerBar after")
            end)
        end

        if overlay.SetAndUpdateShowCastbar then
            hooksecurefunc(overlay, "SetAndUpdateShowCastbar", function()
                if not CastBarDiag.enabled then return end
                CastBarDiag.sequence = CastBarDiag.sequence + 1
                API.LogCastBarDiag("Overlay.SetAndUpdateShowCastbar after")
            end)
        end
    end)

    if ok then
        CastBarDiag.hooksInstalled = true
        if CastBarDiag.enabled then
            CastBarDiagPrint("hooks installed")
        end
    elseif CastBarDiag.enabled then
        CastBarDiagPrint("hook install failed:", tostring(err))
    end
end

function API.SetCastBarDiagEnabled(enabled)
    if not isRetail then
        CastBarDiagPrint("not available on this client")
        return false
    end

    CastBarDiag.enabled = enabled and true or false

    if CastBarDiag.enabled then
        CastBarDiagInstallHooks()
        CastBarDiagPrint("enabled")
        API.LogCastBarDiag("enabled", true)
    else
        CastBarDiagPrint("disabled")
    end

    return CastBarDiag.enabled
end

function API.ToggleCastBarDiag()
    return API.SetCastBarDiagEnabled(not CastBarDiag.enabled)
end

function API.IsCastBarDiagEnabled()
    return CastBarDiag.enabled
end

function API.MarkCastBarDiagAction(action)
    if not isRetail then return end

    CastBarDiag.sequence = CastBarDiag.sequence + 1
    CastBarDiag.lastAction = action or "unknown"
    CastBarDiag.lastActionTime = GetTime and GetTime() or nil

    if CastBarDiag.enabled then
        CastBarDiagInstallHooks()
    end
end

function API.LogCastBarDiag(context, force)
    if not isRetail or (not CastBarDiag.enabled and not force) then return end
    if CastBarDiag.logging then return end

    CastBarDiag.logging = true
    local ok, err = pcall(function()
        if CastBarDiag.enabled and not CastBarDiag.hooksInstalled then
            CastBarDiagInstallHooks()
        end

        local overlay = CastBarDiagGetFrame("OverlayPlayerCastingBarFrame")
        local player = CastBarDiagGetFrame("PlayerCastingBarFrame")
        local now = GetTime and GetTime() or 0
        local lastActionAge = "nil"
        if CastBarDiag.lastActionTime then
            lastActionAge = string.format("%.3f", now - CastBarDiag.lastActionTime)
        end

        CastBarDiagPrint(
            string.format(
                "#%d %s time=%.3f action=%s actionAge=%s canSecrets=%s canTypeInfo=%s",
                CastBarDiag.sequence,
                context or "snapshot",
                now,
                CastBarDiag.lastAction or "nil",
                lastActionAge,
                CastBarDiagCanAccessSecrets(),
                CastBarDiagCanAccessCastingBarTypeInfo()
            )
        )

        CastBarDiagPrint(
            string.format(
                "overlay exists=%s shown=%s visible=%s showCastbar=%s unit=%s casting=%s channeling=%s reverseChanneling=%s overrideBarType=%s barType=%s",
                CastBarDiagBool(overlay ~= nil),
                CastBarDiagReadMethod(overlay, "IsShown"),
                CastBarDiagReadMethod(overlay, "IsVisible"),
                CastBarDiagReadField(overlay, "showCastbar"),
                CastBarDiagReadField(overlay, "unit"),
                CastBarDiagReadField(overlay, "casting"),
                CastBarDiagReadField(overlay, "channeling"),
                CastBarDiagReadField(overlay, "reverseChanneling"),
                CastBarDiagSecretState(overlay, "overrideBarType"),
                CastBarDiagSecretState(overlay, "barType")
            )
        )

        CastBarDiagPrint(
            string.format(
                "player exists=%s shown=%s visible=%s showCastbar=%s unit=%s casting=%s channeling=%s reverseChanneling=%s",
                CastBarDiagBool(player ~= nil),
                CastBarDiagReadMethod(player, "IsShown"),
                CastBarDiagReadMethod(player, "IsVisible"),
                CastBarDiagReadField(player, "showCastbar"),
                CastBarDiagReadField(player, "unit"),
                CastBarDiagReadField(player, "casting"),
                CastBarDiagReadField(player, "channeling"),
                CastBarDiagReadField(player, "reverseChanneling")
            )
        )
    end)

    CastBarDiag.logging = false
    if not ok then
        CastBarDiagPrint("log failed:", tostring(err))
    end
end

-------------------------------------------------------------------------------
-- Guild
-------------------------------------------------------------------------------
function API.GetNumGuildMembers()
    return GetNumGuildMembers()
end

function API.GetGuildRosterInfo(index)
    return GetGuildRosterInfo(index)
end

function API.GuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    else
        GuildRoster()
    end
end

function API.GetGuildInfo(unit)
    return GetGuildInfo(unit)
end

function API.ToggleGuildFrame()
    if ToggleGuildFrame then 
        ToggleGuildFrame() 
    elseif ToggleGuildTab then 
        ToggleGuildTab()
    end
end

-------------------------------------------------------------------------------
-- Friends & Social
-------------------------------------------------------------------------------
function API.GetNumFriends()
    if C_FriendList and C_FriendList.GetNumFriends then
        return C_FriendList.GetNumFriends()
    end
    return GetNumFriends()
end

function API.GetFriendInfoByIndex(index)
    if C_FriendList and C_FriendList.GetFriendInfoByIndex then
        return C_FriendList.GetFriendInfoByIndex(index)
    end
    
    local name, level, class, area, connected, status, notes = GetFriendInfo(index)
    return {
        name = name,
        level = level,
        className = class,
        area = area,
        connected = connected,
        afk = (status == "AFK"),
        dnd = (status == "DND"),
        notes = notes
    }
end

function API.GetNumOnlineFriends()
    if C_FriendList and C_FriendList.GetNumOnlineFriends then
        return C_FriendList.GetNumOnlineFriends()
    end
    local num = GetNumFriends()
    local online = 0
    for i=1, num do
        local _, _, _, _, connected = GetFriendInfo(i)
        if connected then online = online + 1 end
    end
    return online
end

function API.InviteUnit(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(name)
    else
        InviteUnit(name)
    end
end

function API.ToggleFriendsFrame()
    ToggleFriendsFrame()
end

function API.ToggleTalentFrame()
    if YUI.IsRetail then
        API.MarkCastBarDiagAction("ToggleTalentFrame")
        CastBarDiagSchedule("ToggleTalentFrame before")

        if PlayerSpellsUtil and PlayerSpellsUtil.TogglePlayerSpellsFrame then
            local classTalentsTab = (PlayerSpellsUtil.FrameTabs and PlayerSpellsUtil.FrameTabs.ClassTalents) or 2
            local result = API.SecureCallFunction(PlayerSpellsUtil.TogglePlayerSpellsFrame, classTalentsTab)
            CastBarDiagSchedule("ToggleTalentFrame after PlayerSpellsUtil")
            return result
        elseif TogglePlayerSpellsFrame then
            local result = API.SecureCallFunction(TogglePlayerSpellsFrame, 2)
            CastBarDiagSchedule("ToggleTalentFrame after TogglePlayerSpellsFrame")
            return result
        end

        if not PlayerSpellsFrame and PlayerSpellsFrame_LoadUI then
            API.SecureCallFunction(PlayerSpellsFrame_LoadUI)
        end

        if PlayerSpellsFrame then
            if PlayerSpellsFrame:IsShown() then
                API.SecureCallFunction(HideUIPanel, PlayerSpellsFrame)
            else
                if PlayerSpellsFrame.TrySetTab then
                    API.SecureCallMethod(PlayerSpellsFrame, "TrySetTab", 2)
                elseif PlayerSpellsFrame.SetTab then
                    local talentTab = (Enum and Enum.PlayerSpellsFrameTab and Enum.PlayerSpellsFrameTab.Talents) or 2
                    API.SecureCallMethod(PlayerSpellsFrame, "SetTab", talentTab)
                end
                API.SecureCallFunction(ShowUIPanel, PlayerSpellsFrame)
            end
        elseif ClassTalentFrame then
            API.SecureCallFunction(ToggleFrame, ClassTalentFrame)
        else
            API.SecureCallFunction(ToggleTalentFrame)
        end

        CastBarDiagSchedule("ToggleTalentFrame after fallback")
    else
        if PlayerTalentFrame_Toggle then
            PlayerTalentFrame_Toggle()
        else
            ToggleTalentFrame()
        end
    end
end

function API.BNGetNumFriends()
    return BNGetNumFriends()
end

function API.BNGetFriendAccountInfo(index)
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        return C_BattleNet.GetFriendAccountInfo(index)
    end
    -- Fallback handling would be complex here due to structure differences
    -- Assuming modern API availability for target versions or implementing partial fallback if needed later
    return nil 
end

-------------------------------------------------------------------------------
-- Panels & Toggles
-------------------------------------------------------------------------------
function API.ToggleCharacter(tab)
    ToggleCharacter(tab)
end

function API.ToggleSpellBook()
    if isRetail then
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
            PlayerSpellsUtil.ToggleSpellBookFrame()
        elseif ToggleSpellBook then
            ToggleSpellBook(BOOKTYPE_SPELL)
        end
    else
        ToggleSpellBook(BOOKTYPE_SPELL)
    end
end

function API.ToggleAchievementFrame()
    if ToggleAchievementFrame then ToggleAchievementFrame() end
end

function API.ToggleQuestLog()
    if ToggleQuestLog then ToggleQuestLog() end
end

function API.ToggleCollectionsJournal()
    if ToggleCollectionsJournal then ToggleCollectionsJournal() end
end

function API.ToggleEncounterJournal()
    if ToggleEncounterJournal then ToggleEncounterJournal() end
end

function API.TogglePVEFrame()
    if PVEFrame_ToggleFrame then 
        PVEFrame_ToggleFrame() 
    elseif ToggleLFGParentFrame then
        ToggleLFGParentFrame()
    end
end

function API.TogglePVPUI()
    local TogglePVPUI = YUI.IsRetail and TogglePVPUI or TogglePVPFrame
    if TogglePVPUI then
        TogglePVPUI()
    end
end

function API.ToggleGameMenu()
    if GameMenuFrame:IsShown() then
        HideUIPanel(GameMenuFrame)
    else
        ShowUIPanel(GameMenuFrame)
    end
end

-------------------------------------------------------------------------------
-- Misc
-------------------------------------------------------------------------------
function API.GetRealZoneText()
    return GetRealZoneText()
end

function API.GetBindingKey(action)
    return GetBindingKey(action)
end

function API.GetBindingText(key)
    return GetBindingText(key)
end

function API.GetQuestDifficultyColor(level)
    return GetQuestDifficultyColor(level)
end

function API.RunSlashCmd(cmd)
    local slash, args = cmd:match("^(%S+)%s*(.*)$")

    if not slash then return false end
    slash = slash:upper()

    for name, func in pairs(SlashCmdList) do
        local i = 1
        while true do
            local c = _G["SLASH_" .. name .. i]
            -- if name and c then print(name, c) end
            if not c then break end
            if c:upper() == slash then
                -- pcall to avoid errors breaking the loop or execution
                local success, err = pcall(func, args)
                if not success then
                    -- YUI:Print("Error executing slash command:", err)
                end
                return true
            end
            i = i + 1
        end
    end

    -- Fallback: Try sending via ChatEdit if not found in SlashCmdList
    -- This handles cases where SlashCmdList might be empty or incomplete but the command is valid system-wise
    if ChatEdit_SendText then
         -- Use a safe way to send command without opening chat box if possible
         -- However, ChatEdit_SendText is the standard way to emulate input
         local editBox = ChatFrame1EditBox
         if editBox then
             -- local originalText = editBox:GetText()
             editBox:SetText(cmd)
             ChatEdit_SendText(editBox, 0)
             -- if originalText ~= "" then
                 -- Restore text if we interrupted something (though SendText clears it usually)
                 -- This is tricky, usually we assume user isn't typing when clicking a menu
             -- end
             return true
         end
    end

    return false
end

function API.GetTitleIconTexture(client, version, callback)
    if C_Texture and C_Texture.GetTitleIconTexture then
         return C_Texture.GetTitleIconTexture(client, version, callback)
    end
    return nil
end

function API.SendTell(name, text)
    if ChatFrameUtil and ChatFrameUtil.SendTell then
        ChatFrameUtil.SendTell(name, SELECTED_DOCK_FRAME)
    else
        ChatFrame_SendTell(name)
    end
end

function API.SendBNetTell(name)
    if ChatFrameUtil and ChatFrameUtil.SendBNetTell then
        ChatFrameUtil.SendBNetTell(name)
    elseif ChatFrame_SendBNetTell then
        ChatFrame_SendBNetTell(name)
    else
        -- Fallback logic for BNet tell if needed
        -- ChatFrame_OpenChat("/w " .. name .. " ")
    end
end

-------------------------------------------------------------------------------
-- Talents & Specializations
-------------------------------------------------------------------------------
function API.GetLootSpecialization()
    if GetLootSpecialization then
        return GetLootSpecialization()
    end
    return 0 -- Not supported in Classic/Wrath
end

function API.SetLootSpecialization(specID)
    if SetLootSpecialization then
        SetLootSpecialization(specID)
    end
end

function API.GetSpecialization()
    if isRetail and C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    elseif isRetail and GetSpecialization then
        return GetSpecialization()
    elseif C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        return C_SpecializationInfo.GetActiveSpecGroup()
    elseif GetActiveTalentGroup then
        -- In Wrath, returns the active talent group index (1 or 2)
        return GetActiveTalentGroup()
    end
    return nil
end

function API.SetSpecialization(index)
    if isRetail then
        API.MarkCastBarDiagAction("SetSpecialization:" .. tostring(index))
        CastBarDiagSchedule("SetSpecialization before")
    end

    if isRetail and C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
        local result = API.SecureCallFunction(C_SpecializationInfo.SetSpecialization, index)
        CastBarDiagSchedule("SetSpecialization after C_SpecializationInfo")
        return result
    elseif isRetail and SetSpecialization then
        local result = API.SecureCallFunction(SetSpecialization, index)
        CastBarDiagSchedule("SetSpecialization after SetSpecialization")
        return result
    elseif C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup then
        return C_SpecializationInfo.SetActiveSpecGroup(index)
    elseif SetActiveTalentGroup then
        return SetActiveTalentGroup(index)
    end
    return nil
end

function API.GetNumSpecializations()
    if isRetail and GetNumSpecializations then
        return GetNumSpecializations()
    elseif GetNumTalentGroups then
        return GetNumTalentGroups()
    end
    return 0
end

-- Unified GetSpecializationInfo
-- Retail: id, name, description, icon, role, primaryStat
-- Wrath: id(groupIndex), name(MainTreeName), description(Points), icon, role(guessed), primaryStat(nil)
function API.GetSpecializationInfo(index)
    if isRetail and GetSpecializationInfo then
        return GetSpecializationInfo(index)
    elseif GetTalentTabInfo then
        -- Classic/Wrath Logic
        -- index is the Talent Group Index (1 or 2)
        -- We need to find the "Main Tree" for this group (most points spent)
        local maxPoints = -1
        local mainTreeIndex = 1
        local totalPoints = 0
        
        for tab = 1, 3 do
            local id, name, description, icon, points = GetTalentTabInfo(tab, false, false, index)
            if points then
                totalPoints = totalPoints + points
                if points > maxPoints then
                    maxPoints = points
                    mainTreeIndex = tab
                end
            end
        end
        
        if totalPoints == 0 then
            return index, "未激活天赋", "", 134400, nil
        end
        
        -- Get Name and Icon of the main tree
        local id, name, description, icon = GetTalentTabInfo(mainTreeIndex, false, false, index)
        
        -- Format Name with points, e.g. "Fire (51/0/0)"
        local p1 = select(5, GetTalentTabInfo(1, false, false, index)) or 0
        local p2 = select(5, GetTalentTabInfo(2, false, false, index)) or 0
        local p3 = select(5, GetTalentTabInfo(3, false, false, index)) or 0
        
        local fullName = string.format("%s (%d/%d/%d)", name, p1, p2, p3)
        
        return index, fullName, description, icon, nil
    end
    return nil
end

function API.GetSpecializationInfoByID(specID)
    if GetSpecializationInfoByID then
        return GetSpecializationInfoByID(specID)
    end
    -- Fallback for Wrath/Classic if needed, but usually ID based lookup is Retail only
    return nil
end

function API.GetConfigIDsBySpecID(specID)
    if C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
        return API.SecureCallFunction(C_ClassTalents.GetConfigIDsBySpecID, specID)
    end
    return nil
end

function API.GetStarterBuildConfigID()
    return API.Constants
        and API.Constants.TraitConsts
        and API.Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
        or nil
end

function API.IsStarterBuildConfigID(configID)
    local starterConfigID = API.GetStarterBuildConfigID()
    return starterConfigID ~= nil and configID == starterConfigID
end

function API.GetCurrentConfigID()
    if isRetail and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        return API.SecureCallFunction(C_ClassTalents.GetActiveConfigID)
    end
    return nil
end

function API.GetLastSelectedSavedConfigID(specID)
    if YUI.IsRetail and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
        return API.SecureCallFunction(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
    end
    return nil
end

function API.GetActiveConfigID(specID)
    return API.GetLastSelectedSavedConfigID(specID)
end

function API.GetHasStarterBuild()
    if C_ClassTalents and C_ClassTalents.GetHasStarterBuild then
        return API.SecureCallFunction(C_ClassTalents.GetHasStarterBuild)
    end
    return false
end

function API.GetStarterBuildActive()
    if C_ClassTalents and C_ClassTalents.GetStarterBuildActive then
        return API.SecureCallFunction(C_ClassTalents.GetStarterBuildActive)
    end
    return false
end

function API.UpdateLastSelectedSavedConfigID(specID, configID)
    if isRetail and specID and C_ClassTalents and C_ClassTalents.UpdateLastSelectedSavedConfigID then
        return API.SecureCallFunction(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, configID)
    end
    return nil
end

local LoadAndApplyPending = nil
local LoadAndApplyEventsRegistered = false

local function LoadAndApplyGetCurrentSpecID()
    local specIndex = API.GetSpecialization()
    if specIndex then
        local specID = API.GetSpecializationInfo(specIndex)
        return specID
    end
    return nil
end

local function LoadAndApplyIsStarterConfig(configID)
    return API.IsStarterBuildConfigID(configID)
end

local function LoadAndApplyClearPending()
    LoadAndApplyPending = nil
end

local function LoadAndApplyShowError(changeError)
    if changeError and changeError ~= "" and UIErrorsFrame and UIErrorsFrame.AddExternalErrorMessage then
        UIErrorsFrame:AddExternalErrorMessage(changeError)
    end
end

local function LoadAndApplyFinishPending()
    local pending = LoadAndApplyPending
    if not pending then return end

    if pending.specID and pending.configID and not LoadAndApplyIsStarterConfig(pending.configID) then
        API.UpdateLastSelectedSavedConfigID(pending.specID, pending.configID)
    end

    if pending.unflagStarterBuild and C_ClassTalents and C_ClassTalents.SetStarterBuildActive then
        API.SecureCallFunction(C_ClassTalents.SetStarterBuildActive, false)
    end

    LoadAndApplyClearPending()
    CastBarDiagSchedule("LoadAndApplyConfig committed")
end

local function LoadAndApplyEnsureEventFrame()
    if LoadAndApplyEventsRegistered or not YUI.Event then return end

    LoadAndApplyEventsRegistered = true
    local function OnLoadAndApplyEvent(event)
        if not LoadAndApplyPending then return end

        if event == "CONFIG_COMMIT_FAILED" then
            LoadAndApplyClearPending()
            CastBarDiagSchedule("LoadAndApplyConfig commit failed")
            return
        end

        LoadAndApplyFinishPending()
    end

    YUI.Event:On("TRAIT_CONFIG_UPDATED", OnLoadAndApplyEvent)
    YUI.Event:On("CONFIG_COMMIT_FAILED", OnLoadAndApplyEvent)
end

local function LoadAndApplyArmPending(configID, specID, unflagStarterBuild)
    LoadAndApplyPending = {
        configID = configID,
        specID = specID,
        unflagStarterBuild = unflagStarterBuild and true or false,
    }
    LoadAndApplyEnsureEventFrame()
end

function API.LoadConfig(configID, autoApply)
    YUI:Debug("LoadConfig", configID, autoApply)
    if isRetail then
        API.MarkCastBarDiagAction("LoadConfig:" .. tostring(configID))
        CastBarDiagSchedule("LoadConfig before")
    end

    if C_ClassTalents and C_ClassTalents.LoadConfig then
        local result, changeError, newLearnedNodeIDs = API.SecureCallFunction(C_ClassTalents.LoadConfig, configID, autoApply)
        YUI:Debug("LoadConfig result: ", result, changeError, newLearnedNodeIDs)
        CastBarDiagSchedule("LoadConfig after")
        return result, changeError, newLearnedNodeIDs
    end
end

function API.LoadAndApplyConfig(configID)
    YUI:Debug("LoadAndApplyConfig", configID)
    if isRetail then
        API.MarkCastBarDiagAction("LoadAndApplyConfig:" .. tostring(configID))
        CastBarDiagSchedule("LoadAndApplyConfig before")
    end

    if not isRetail or not C_ClassTalents or not Enum or not Enum.LoadConfigResult then
        return API.LoadConfig(configID, true)
    end

    local enum = Enum.LoadConfigResult
    local specID = LoadAndApplyGetCurrentSpecID()
    local isStarterConfig = LoadAndApplyIsStarterConfig(configID)
    local wasStarterBuildActive = API.GetStarterBuildActive()
    local result, changeError, newLearnedNodeIDs

    if isStarterConfig then
        result = API.SecureCallFunction(C_ClassTalents.SetStarterBuildActive, true)
    elseif C_ClassTalents.LoadConfig then
        result, changeError, newLearnedNodeIDs = API.SecureCallFunction(C_ClassTalents.LoadConfig, configID, true)
    end

    YUI:Debug("LoadAndApplyConfig result:", result, changeError, newLearnedNodeIDs)
    CastBarDiagSchedule("LoadAndApplyConfig after load")

    if changeError then
        LoadAndApplyShowError(changeError)
        return result, changeError, newLearnedNodeIDs, false
    end

    if result == enum.Error then
        return result, changeError, newLearnedNodeIDs, false
    elseif result == enum.NoChangesNecessary then
        if specID and not isStarterConfig then
            API.UpdateLastSelectedSavedConfigID(specID, configID)
        end
        if wasStarterBuildActive and not isStarterConfig and C_ClassTalents.SetStarterBuildActive then
            API.SecureCallFunction(C_ClassTalents.SetStarterBuildActive, false)
        end
        return result, changeError, newLearnedNodeIDs, true
    elseif result == enum.LoadInProgress then
        LoadAndApplyArmPending(configID, specID, wasStarterBuildActive and not isStarterConfig)
        return result, changeError, newLearnedNodeIDs, true
    elseif result == enum.Ready then
        if C_ClassTalents.CommitConfig then
            LoadAndApplyArmPending(configID, specID, wasStarterBuildActive and not isStarterConfig)
            local commitSuccess = API.SecureCallFunction(C_ClassTalents.CommitConfig, configID)
            CastBarDiagSchedule("LoadAndApplyConfig after commit")
            if not commitSuccess then
                LoadAndApplyClearPending()
            end
            return result, changeError, newLearnedNodeIDs, commitSuccess and true or false
        end
        return result, changeError, newLearnedNodeIDs, false
    end

    return result, changeError, newLearnedNodeIDs, nil
end

function API.SetStarterBuildActive(active)
    if isRetail then
        API.MarkCastBarDiagAction("SetStarterBuildActive:" .. tostring(active))
        CastBarDiagSchedule("SetStarterBuildActive before")
    end

    if C_ClassTalents and C_ClassTalents.SetStarterBuildActive then
        local result = API.SecureCallFunction(C_ClassTalents.SetStarterBuildActive, active)
        CastBarDiagSchedule("SetStarterBuildActive after")
        return result
    end
    return nil
end

function API.GetConfigInfo(configID)
    if C_Traits and C_Traits.GetConfigInfo then
        return C_Traits.GetConfigInfo(configID)
    end
    return nil
end

-------------------------------------------------------------------------------
-- Spell / Item Icon
-------------------------------------------------------------------------------
function API.GetSpellIcon(spellID)
    return GetSpellTexture(spellID)
end

function API.GetItemIcon(itemID)
    return GetItemIcon(itemID)
end


