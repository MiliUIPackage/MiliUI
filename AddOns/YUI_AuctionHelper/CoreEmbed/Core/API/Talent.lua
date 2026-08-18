local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Talent = YUI.API.Talent or {}
YUI.API.Talent = Talent

local Legacy = YUI.WOW_API
local isRetail = YUI.IsRetail
local isMists = YUI.IsMists
local isWrath = YUI.IsWrath
local UNLEARNED_SPEC_NAME = "未激活天赋"
local UNLEARNED_SPEC_ICON = 134400

local currentSpecInfoCache
local currentSpecCacheEventsRegistered

Talent.Constants = Talent.Constants or {
    TraitConsts = {
        STARTER_BUILD_TRAIT_CONFIG_ID = Constants
            and Constants.TraitConsts
            and Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
            or nil
    }
}

Legacy.Constants = Legacy.Constants or {}
Legacy.Constants.TraitConsts = Legacy.Constants.TraitConsts or {}
Legacy.Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID =
    Legacy.Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
    or Talent.Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID

local function SecureCallFunction(func, ...)
    local Security = YUI.API and YUI.API.Security
    if Security and Security.SecureCallFunction then
        return Security.SecureCallFunction(func, ...)
    end

    if not func then return nil end
    return func(...)
end

local function SecureCallMethod(object, method, ...)
    local Security = YUI.API and YUI.API.Security
    if Security and Security.SecureCallMethod then
        return Security.SecureCallMethod(object, method, ...)
    end

    if not object or not method then return nil end
    local func = object[method]
    if func then
        return func(object, ...)
    end

    return nil
end

local function CopySpecInfo(info)
    if type(info) ~= "table" then return nil end
    return {
        specID = info.specID,
        specIndex = info.specIndex,
        name = info.name,
        description = info.description,
        icon = info.icon,
        role = info.role,
        classID = info.classID,
        classFile = info.classFile,
        groupIndex = info.groupIndex,
        treeIndex = info.treeIndex,
        points = info.points,
    }
end

local function GetUnitAPI()
    return YUI.API and YUI.API.Unit or YUI.WOW_API or {}
end

local function GetPlayerClassInfo()
    local UnitAPI = GetUnitAPI()
    local className, classFile, classID
    if UnitAPI.UnitClass then
        className, classFile, classID = UnitAPI.UnitClass("player")
    elseif UnitClass then
        className, classFile, classID = UnitClass("player")
    end

    if classFile then
        return {
            className = className or classFile,
            classFile = classFile,
            classID = tonumber(classID),
        }
    end

    return nil
end

local function ResolveClassInfo(classInfoOrClassID)
    local UnitAPI = GetUnitAPI()

    if classInfoOrClassID == nil then
        return GetPlayerClassInfo()
    end

    if type(classInfoOrClassID) == "table" then
        local info = {
            className = classInfoOrClassID.className or classInfoOrClassID.name,
            classFile = classInfoOrClassID.classFile or classInfoOrClassID.token,
            classID = tonumber(classInfoOrClassID.classID or classInfoOrClassID.id),
        }

        if info.classFile and not info.classID and UnitAPI.GetClassInfos then
            for _, candidate in ipairs(UnitAPI.GetClassInfos()) do
                if candidate.classFile == info.classFile then
                    info.classID = candidate.classID
                    info.className = info.className or candidate.className
                    break
                end
            end
        end

        return info
    end

    if type(classInfoOrClassID) == "number" then
        if UnitAPI.GetClassInfoByID then
            return UnitAPI.GetClassInfoByID(classInfoOrClassID)
        end
        if UnitAPI.GetClassInfos then
            for _, info in ipairs(UnitAPI.GetClassInfos()) do
                if info.classID == classInfoOrClassID then
                    return info
                end
            end
        end
        return nil
    end

    if type(classInfoOrClassID) == "string" and UnitAPI.GetClassInfos then
        local classFile = strupper and strupper(classInfoOrClassID) or string.upper(classInfoOrClassID)
        for _, info in ipairs(UnitAPI.GetClassInfos()) do
            if info.classFile == classFile then
                return info
            end
        end
    end

    return nil
end

local function ScheduleCastBarDiag(context)
    if not isRetail or not Legacy.LogCastBarDiag then return end

    Legacy.LogCastBarDiag(context .. " now")

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            Legacy.LogCastBarDiag(context .. " +0")
        end)
        C_Timer.After(0.2, function()
            Legacy.LogCastBarDiag(context .. " +0.2")
        end)
    end
end

local function MarkCastBarDiagAction(action)
    if isRetail and Legacy.MarkCastBarDiagAction then
        Legacy.MarkCastBarDiagAction(action)
    end
end

function Talent.ToggleTalentFrame()
    if isRetail then
        MarkCastBarDiagAction("ToggleTalentFrame")
        ScheduleCastBarDiag("ToggleTalentFrame before")

        if PlayerSpellsUtil and PlayerSpellsUtil.TogglePlayerSpellsFrame then
            local classTalentsTab = (PlayerSpellsUtil.FrameTabs and PlayerSpellsUtil.FrameTabs.ClassTalents) or 2
            local result = SecureCallFunction(PlayerSpellsUtil.TogglePlayerSpellsFrame, classTalentsTab)
            ScheduleCastBarDiag("ToggleTalentFrame after PlayerSpellsUtil")
            return result
        elseif TogglePlayerSpellsFrame then
            local result = SecureCallFunction(TogglePlayerSpellsFrame, 2)
            ScheduleCastBarDiag("ToggleTalentFrame after TogglePlayerSpellsFrame")
            return result
        end

        if not PlayerSpellsFrame and PlayerSpellsFrame_LoadUI then
            SecureCallFunction(PlayerSpellsFrame_LoadUI)
        end

        if PlayerSpellsFrame then
            if PlayerSpellsFrame:IsShown() then
                SecureCallFunction(HideUIPanel, PlayerSpellsFrame)
            else
                if PlayerSpellsFrame.TrySetTab then
                    SecureCallMethod(PlayerSpellsFrame, "TrySetTab", 2)
                elseif PlayerSpellsFrame.SetTab then
                    local talentTab = (Enum and Enum.PlayerSpellsFrameTab and Enum.PlayerSpellsFrameTab.Talents) or 2
                    SecureCallMethod(PlayerSpellsFrame, "SetTab", talentTab)
                end
                SecureCallFunction(ShowUIPanel, PlayerSpellsFrame)
            end
        elseif ClassTalentFrame then
            SecureCallFunction(ToggleFrame, ClassTalentFrame)
        else
            SecureCallFunction(ToggleTalentFrame)
        end

        ScheduleCastBarDiag("ToggleTalentFrame after fallback")
        return nil
    end

    if isMists or isWrath then
        if PlayerTalentFrame_Toggle then
            return PlayerTalentFrame_Toggle()
        elseif ToggleTalentFrame then
            return ToggleTalentFrame()
        end
    end

    if ToggleTalentFrame then
        return ToggleTalentFrame()
    end

    return nil
end

function Talent.GetLootSpecialization()
    if GetLootSpecialization then
        return GetLootSpecialization()
    end

    return 0
end

function Talent.SetLootSpecialization(specID)
    if SetLootSpecialization then
        return SetLootSpecialization(specID)
    end

    return nil
end

function Talent.GetSpecialization()
    if isRetail then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
            return C_SpecializationInfo.GetSpecialization()
        elseif GetSpecialization then
            return GetSpecialization()
        end
        return nil
    end

    if isMists then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
            return C_SpecializationInfo.GetSpecialization()
        elseif GetSpecialization then
            return GetSpecialization()
        elseif C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
            return C_SpecializationInfo.GetActiveSpecGroup()
        elseif GetActiveTalentGroup then
            return GetActiveTalentGroup()
        end
        return nil
    end

    if isWrath then
        if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
            return C_SpecializationInfo.GetActiveSpecGroup()
        elseif GetActiveTalentGroup then
            return GetActiveTalentGroup()
        end
        return nil
    end

    if GetSpecialization then
        return GetSpecialization()
    elseif C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
        return C_SpecializationInfo.GetActiveSpecGroup()
    elseif GetActiveTalentGroup then
        return GetActiveTalentGroup()
    end

    return nil
end

function Talent.SetSpecialization(index)
    Talent.ClearCurrentSpecializationInfoCache()

    if isRetail then
        MarkCastBarDiagAction("SetSpecialization:" .. tostring(index))
        ScheduleCastBarDiag("SetSpecialization before")

        if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
            local result = SecureCallFunction(C_SpecializationInfo.SetSpecialization, index)
            ScheduleCastBarDiag("SetSpecialization after C_SpecializationInfo")
            return result
        elseif SetSpecialization then
            local result = SecureCallFunction(SetSpecialization, index)
            ScheduleCastBarDiag("SetSpecialization after SetSpecialization")
            return result
        end
        return nil
    end

    if isMists then
        if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
            return C_SpecializationInfo.SetSpecialization(index)
        elseif SetSpecialization then
            return SetSpecialization(index)
        elseif C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup then
            return C_SpecializationInfo.SetActiveSpecGroup(index)
        elseif SetActiveTalentGroup then
            return SetActiveTalentGroup(index)
        end
        return nil
    end

    if isWrath then
        if C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup then
            return C_SpecializationInfo.SetActiveSpecGroup(index)
        elseif SetActiveTalentGroup then
            return SetActiveTalentGroup(index)
        end
        return nil
    end

    if SetSpecialization then
        return SetSpecialization(index)
    elseif C_SpecializationInfo and C_SpecializationInfo.SetActiveSpecGroup then
        return C_SpecializationInfo.SetActiveSpecGroup(index)
    elseif SetActiveTalentGroup then
        return SetActiveTalentGroup(index)
    end

    return nil
end

function Talent.GetNumSpecializations()
    if isRetail then
        if GetNumSpecializations then
            return GetNumSpecializations()
        end
        return 0
    end

    if isMists then
        if GetNumSpecializations then
            return GetNumSpecializations()
        elseif GetNumSpecGroups then
            return GetNumSpecGroups(false)
        elseif GetNumTalentGroups then
            return GetNumTalentGroups()
        end
        return 0
    end

    if isWrath then
        if GetNumTalentGroups then
            return GetNumTalentGroups()
        elseif GetNumSpecGroups then
            return GetNumSpecGroups(false)
        end
        return 0
    end

    if GetNumSpecializations then
        return GetNumSpecializations()
    elseif GetNumTalentGroups then
        return GetNumTalentGroups()
    end

    return 0
end

local function GetTalentTabInfoCompat(tab, groupIndex)
    if GetTalentTabInfo then
        return GetTalentTabInfo(tab, false, false, groupIndex)
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        local id, name, description, icon, _, _, points = C_SpecializationInfo.GetSpecializationInfo(tab, false, false, nil, nil, groupIndex)
        return id, name, description, icon, points
    end

    return nil
end

function Talent.GetTalentTabInfo(tab, groupIndex)
    if isRetail then return nil end
    return GetTalentTabInfoCompat(tab, groupIndex)
end

local function GetClassicSpecializationInfo(index)
    local maxPoints = -1
    local mainTreeIndex = 1
    local totalPoints = 0

    for tab = 1, 3 do
        local _, _, _, _, points = GetTalentTabInfoCompat(tab, index)
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

    local _, name, description, icon = GetTalentTabInfoCompat(mainTreeIndex, index)
    local p1 = select(5, GetTalentTabInfoCompat(1, index)) or 0
    local p2 = select(5, GetTalentTabInfoCompat(2, index)) or 0
    local p3 = select(5, GetTalentTabInfoCompat(3, index)) or 0
    local fullName = string.format("%s (%d/%d/%d)", name, p1, p2, p3)

    return index, fullName, description, icon, nil
end

function Talent.GetSpecializationInfo(index)
    if not index then return nil end

    if isRetail then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            return C_SpecializationInfo.GetSpecializationInfo(index)
        elseif GetSpecializationInfo then
            return GetSpecializationInfo(index)
        end
        return nil
    end

    if isMists then
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            return C_SpecializationInfo.GetSpecializationInfo(index)
        elseif GetSpecializationInfo then
            return GetSpecializationInfo(index)
        elseif GetTalentTabInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) then
            return GetClassicSpecializationInfo(index)
        end
        return nil
    end

    if isWrath then
        if GetTalentTabInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) then
            return GetClassicSpecializationInfo(index)
        end
        return nil
    end

    if GetSpecializationInfo then
        return GetSpecializationInfo(index)
    elseif GetTalentTabInfo or (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) then
        return GetClassicSpecializationInfo(index)
    end

    return nil
end

function Talent.GetSpecializationInfoByID(specID)
    if GetSpecializationInfoByID then
        return GetSpecializationInfoByID(specID)
    end

    return nil
end

function Talent.GetNumSpecializationsForClassID(classID)
    classID = tonumber(classID)
    if not classID then return 0 end

    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    elseif GetNumSpecializationsForClassID then
        return GetNumSpecializationsForClassID(classID) or 0
    end

    return 0
end

function Talent.GetSpecializationInfoForClassID(classID, index)
    classID = tonumber(classID)
    index = tonumber(index)
    if not classID or not index then return nil end

    local sex = UnitSex and UnitSex("player") or nil
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID then
        return C_SpecializationInfo.GetSpecializationInfoForClassID(classID, index, sex)
    elseif GetSpecializationInfoForClassID then
        return GetSpecializationInfoForClassID(classID, index, sex)
    end

    return nil
end

function Talent.GetClassSpecializations(classInfoOrClassID)
    local classInfo = ResolveClassInfo(classInfoOrClassID)
    local classID = classInfo and classInfo.classID
    local specs = {}
    if not classID then return specs end

    local count = Talent.GetNumSpecializationsForClassID(classID)
    for index = 1, count do
        local specID, name, description, icon, role = Talent.GetSpecializationInfoForClassID(classID, index)
        if specID then
            specs[#specs + 1] = {
                specID = specID,
                specIndex = index,
                name = name or tostring(specID),
                description = description,
                icon = icon,
                role = role,
                classID = classID,
                classFile = classInfo.classFile,
            }
        end
    end

    return specs
end

function Talent.ClearCurrentSpecializationInfoCache()
    currentSpecInfoCache = nil
end

local function BuildRetailCurrentSpecializationInfo()
    local specIndex = Talent.GetSpecialization()
    if not specIndex then return nil end

    local specID, name, description, icon, role = Talent.GetSpecializationInfo(specIndex)
    if not specID then return nil end

    local classInfo = GetPlayerClassInfo() or {}
    return {
        specID = specID,
        specIndex = specIndex,
        name = name,
        description = description,
        icon = icon,
        role = role,
        classID = classInfo.classID,
        classFile = classInfo.classFile,
    }
end

local function BuildClassicCurrentSpecializationInfo()
    local classInfo = GetPlayerClassInfo() or {}
    local groupIndex = Talent.GetSpecialization() or 1
    local selected
    local maxPoints = -1
    local totalPoints = 0

    for treeIndex = 1, 3 do
        local specID, name, description, icon, points = GetTalentTabInfoCompat(treeIndex, groupIndex)
        points = tonumber(points) or 0
        totalPoints = totalPoints + points
        if points > maxPoints then
            maxPoints = points
            selected = {
                specID = specID,
                specIndex = treeIndex,
                treeIndex = treeIndex,
                name = name,
                description = description,
                icon = icon,
                points = points,
            }
        end
    end

    if totalPoints <= 0 or not selected then
        return {
            specID = nil,
            specIndex = nil,
            name = UNLEARNED_SPEC_NAME,
            description = "",
            icon = UNLEARNED_SPEC_ICON,
            classID = classInfo.classID,
            classFile = classInfo.classFile,
            groupIndex = groupIndex,
            treeIndex = nil,
            points = 0,
        }
    end

    local classSpecs = Talent.GetClassSpecializations(classInfo)
    local listedSpec = classSpecs[selected.treeIndex]

    return {
        specID = tonumber(selected.specID or (listedSpec and listedSpec.specID)),
        specIndex = selected.specIndex,
        name = selected.name or (listedSpec and listedSpec.name) or tostring(selected.specID or selected.specIndex),
        description = selected.description or (listedSpec and listedSpec.description),
        icon = selected.icon or (listedSpec and listedSpec.icon) or UNLEARNED_SPEC_ICON,
        role = listedSpec and listedSpec.role or nil,
        classID = classInfo.classID,
        classFile = classInfo.classFile,
        groupIndex = groupIndex,
        treeIndex = selected.treeIndex,
        points = selected.points,
    }
end

function Talent.GetCurrentSpecializationInfo()
    if isWrath and currentSpecInfoCache then
        return CopySpecInfo(currentSpecInfoCache)
    end

    local info
    if isWrath then
        info = BuildClassicCurrentSpecializationInfo()
        currentSpecInfoCache = CopySpecInfo(info)
    else
        info = BuildRetailCurrentSpecializationInfo()
    end

    return CopySpecInfo(info)
end

function Talent.GetConfigIDsBySpecID(specID)
    if isRetail and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
        return SecureCallFunction(C_ClassTalents.GetConfigIDsBySpecID, specID)
    end

    return nil
end

function Talent.GetStarterBuildConfigID()
    return Talent.Constants
        and Talent.Constants.TraitConsts
        and Talent.Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
        or nil
end

function Talent.IsStarterBuildConfigID(configID)
    local starterConfigID = Talent.GetStarterBuildConfigID()
    return starterConfigID ~= nil and configID == starterConfigID
end

function Talent.GetCurrentConfigID()
    if isRetail and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        return SecureCallFunction(C_ClassTalents.GetActiveConfigID)
    end

    return nil
end

function Talent.HasClassTalents()
    return isRetail and C_ClassTalents ~= nil
end

function Talent.GetLastSelectedSavedConfigID(specID)
    if isRetail and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
        return SecureCallFunction(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
    end

    return nil
end

function Talent.GetActiveConfigID(specID)
    return Talent.GetLastSelectedSavedConfigID(specID)
end

function Talent.GetHasStarterBuild()
    if isRetail and C_ClassTalents and C_ClassTalents.GetHasStarterBuild then
        return SecureCallFunction(C_ClassTalents.GetHasStarterBuild)
    end

    return false
end

function Talent.GetStarterBuildActive()
    if isRetail and C_ClassTalents and C_ClassTalents.GetStarterBuildActive then
        return SecureCallFunction(C_ClassTalents.GetStarterBuildActive)
    end

    return false
end

function Talent.UpdateLastSelectedSavedConfigID(specID, configID)
    if isRetail and specID and C_ClassTalents and C_ClassTalents.UpdateLastSelectedSavedConfigID then
        return SecureCallFunction(C_ClassTalents.UpdateLastSelectedSavedConfigID, specID, configID)
    end

    return nil
end

local LoadAndApplyPending = nil
local LoadAndApplyEventsRegistered = false

local function LoadAndApplyGetCurrentSpecID()
    local specIndex = Talent.GetSpecialization()
    if specIndex then
        local specID = Talent.GetSpecializationInfo(specIndex)
        return specID
    end

    return nil
end

local function LoadAndApplyIsStarterConfig(configID)
    return Talent.IsStarterBuildConfigID(configID)
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
        Talent.UpdateLastSelectedSavedConfigID(pending.specID, pending.configID)
    end

    if pending.unflagStarterBuild and C_ClassTalents and C_ClassTalents.SetStarterBuildActive then
        SecureCallFunction(C_ClassTalents.SetStarterBuildActive, false)
    end

    LoadAndApplyClearPending()
    ScheduleCastBarDiag("LoadAndApplyConfig committed")
end

local function LoadAndApplyEnsureEventFrame()
    if LoadAndApplyEventsRegistered or not YUI.Event then return end

    LoadAndApplyEventsRegistered = true
    local function OnLoadAndApplyEvent(event)
        if not LoadAndApplyPending then return end

        if event == "CONFIG_COMMIT_FAILED" then
            LoadAndApplyClearPending()
            ScheduleCastBarDiag("LoadAndApplyConfig commit failed")
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

function Talent.LoadConfig(configID, autoApply)
    YUI:Debug("LoadConfig", configID, autoApply)
    if isRetail then
        MarkCastBarDiagAction("LoadConfig:" .. tostring(configID))
        ScheduleCastBarDiag("LoadConfig before")
    end

    if isRetail and C_ClassTalents and C_ClassTalents.LoadConfig then
        local result, changeError, newLearnedNodeIDs = SecureCallFunction(C_ClassTalents.LoadConfig, configID, autoApply)
        YUI:Debug("LoadConfig result: ", result, changeError, newLearnedNodeIDs)
        ScheduleCastBarDiag("LoadConfig after")
        return result, changeError, newLearnedNodeIDs
    end

    return nil
end

function Talent.LoadAndApplyConfig(configID)
    YUI:Debug("LoadAndApplyConfig", configID)
    if isRetail then
        MarkCastBarDiagAction("LoadAndApplyConfig:" .. tostring(configID))
        ScheduleCastBarDiag("LoadAndApplyConfig before")
    end

    if not isRetail or not C_ClassTalents or not Enum or not Enum.LoadConfigResult then
        return Talent.LoadConfig(configID, true)
    end

    local enum = Enum.LoadConfigResult
    local specID = LoadAndApplyGetCurrentSpecID()
    local isStarterConfig = LoadAndApplyIsStarterConfig(configID)
    local wasStarterBuildActive = Talent.GetStarterBuildActive()
    local result, changeError, newLearnedNodeIDs

    if isStarterConfig then
        result = SecureCallFunction(C_ClassTalents.SetStarterBuildActive, true)
    elseif C_ClassTalents.LoadConfig then
        result, changeError, newLearnedNodeIDs = SecureCallFunction(C_ClassTalents.LoadConfig, configID, true)
    end

    YUI:Debug("LoadAndApplyConfig result:", result, changeError, newLearnedNodeIDs)
    ScheduleCastBarDiag("LoadAndApplyConfig after load")

    if changeError then
        LoadAndApplyShowError(changeError)
        return result, changeError, newLearnedNodeIDs, false
    end

    if result == enum.Error then
        return result, changeError, newLearnedNodeIDs, false
    elseif result == enum.NoChangesNecessary then
        if specID and not isStarterConfig then
            Talent.UpdateLastSelectedSavedConfigID(specID, configID)
        end
        if wasStarterBuildActive and not isStarterConfig and C_ClassTalents.SetStarterBuildActive then
            SecureCallFunction(C_ClassTalents.SetStarterBuildActive, false)
        end
        return result, changeError, newLearnedNodeIDs, true
    elseif result == enum.LoadInProgress then
        LoadAndApplyArmPending(configID, specID, wasStarterBuildActive and not isStarterConfig)
        return result, changeError, newLearnedNodeIDs, true
    elseif result == enum.Ready then
        if C_ClassTalents.CommitConfig then
            LoadAndApplyArmPending(configID, specID, wasStarterBuildActive and not isStarterConfig)
            local commitSuccess = SecureCallFunction(C_ClassTalents.CommitConfig, configID)
            ScheduleCastBarDiag("LoadAndApplyConfig after commit")
            if not commitSuccess then
                LoadAndApplyClearPending()
            end
            return result, changeError, newLearnedNodeIDs, commitSuccess and true or false
        end
        return result, changeError, newLearnedNodeIDs, false
    end

    return result, changeError, newLearnedNodeIDs, nil
end

function Talent.SetStarterBuildActive(active)
    if isRetail then
        MarkCastBarDiagAction("SetStarterBuildActive:" .. tostring(active))
        ScheduleCastBarDiag("SetStarterBuildActive before")
    end

    if isRetail and C_ClassTalents and C_ClassTalents.SetStarterBuildActive then
        local result = SecureCallFunction(C_ClassTalents.SetStarterBuildActive, active)
        ScheduleCastBarDiag("SetStarterBuildActive after")
        return result
    end

    return nil
end

function Talent.GetConfigInfo(configID)
    if isRetail and C_Traits and C_Traits.GetConfigInfo then
        return C_Traits.GetConfigInfo(configID)
    end

    return nil
end

local function RegisterCurrentSpecCacheEvents()
    if currentSpecCacheEventsRegistered or not YUI.Event then return end
    currentSpecCacheEventsRegistered = true

    local function ClearCache()
        Talent.ClearCurrentSpecializationInfoCache()
    end

    YUI.Event:On("PLAYER_SPECIALIZATION_CHANGED", ClearCache, Talent)
    YUI.Event:On("PLAYER_TALENT_UPDATE", ClearCache, Talent)
    YUI.Event:On("CHARACTER_POINTS_CHANGED", ClearCache, Talent)
    YUI.Event:On("ACTIVE_TALENT_GROUP_CHANGED", ClearCache, Talent)
    YUI.Event:On("ACTIVE_COMBAT_CONFIG_CHANGED", ClearCache, Talent)
    YUI.Event:On("YUI_WORLD_READY", ClearCache, Talent)
end

RegisterCurrentSpecCacheEvents()

Legacy.ToggleTalentFrame = Talent.ToggleTalentFrame
Legacy.GetLootSpecialization = Talent.GetLootSpecialization
Legacy.SetLootSpecialization = Talent.SetLootSpecialization
Legacy.GetSpecialization = Talent.GetSpecialization
Legacy.SetSpecialization = Talent.SetSpecialization
Legacy.GetNumSpecializations = Talent.GetNumSpecializations
Legacy.GetTalentTabInfo = Talent.GetTalentTabInfo
Legacy.GetSpecializationInfo = Talent.GetSpecializationInfo
Legacy.GetSpecializationInfoByID = Talent.GetSpecializationInfoByID
Legacy.GetNumSpecializationsForClassID = Talent.GetNumSpecializationsForClassID
Legacy.GetSpecializationInfoForClassID = Talent.GetSpecializationInfoForClassID
Legacy.GetClassSpecializations = Talent.GetClassSpecializations
Legacy.ClearCurrentSpecializationInfoCache = Talent.ClearCurrentSpecializationInfoCache
Legacy.GetCurrentSpecializationInfo = Talent.GetCurrentSpecializationInfo
Legacy.GetConfigIDsBySpecID = Talent.GetConfigIDsBySpecID
Legacy.GetStarterBuildConfigID = Talent.GetStarterBuildConfigID
Legacy.IsStarterBuildConfigID = Talent.IsStarterBuildConfigID
Legacy.GetCurrentConfigID = Talent.GetCurrentConfigID
Legacy.HasClassTalents = Talent.HasClassTalents
Legacy.GetLastSelectedSavedConfigID = Talent.GetLastSelectedSavedConfigID
Legacy.GetActiveConfigID = Talent.GetActiveConfigID
Legacy.GetHasStarterBuild = Talent.GetHasStarterBuild
Legacy.GetStarterBuildActive = Talent.GetStarterBuildActive
Legacy.UpdateLastSelectedSavedConfigID = Talent.UpdateLastSelectedSavedConfigID
Legacy.LoadConfig = Talent.LoadConfig
Legacy.LoadAndApplyConfig = Talent.LoadAndApplyConfig
Legacy.SetStarterBuildActive = Talent.SetStarterBuildActive
Legacy.GetConfigInfo = Talent.GetConfigInfo
