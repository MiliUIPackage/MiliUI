local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}

local Frame = YUI.API.Frame or {}
YUI.API.Frame = Frame

local Legacy = YUI.WOW_API
local isRetail = YUI.IsRetail
local Unit = YUI.API and YUI.API.Unit

local suppressedForbiddenNamePlateUnits = {}
local platynatorFriendlyNamePlateSuppressionEnabled = false
local platynatorNamePlateMixinHooksInstalled = false
local platynatorUpdateNameClassColorHookInstalled = false
local platynatorOnUnitSetHookInstalled = false
local platynatorUpdateIsFriendHookInstalled = false

local function SafeField(object, key)
    if not object then
        return nil
    end

    local ok, value = pcall(function()
        return object[key]
    end)

    if ok then
        return value
    end

    return nil
end

local function SafeFunction(func, ...)
    if type(func) ~= "function" then
        return false, nil, "NO_FUNCTION"
    end

    local ok, result = pcall(func, ...)
    if ok then
        return true, result, "OK"
    end

    return false, nil, "CALL_ERROR"
end

local function ClearTable(tbl)
    if type(wipe) == "function" then
        wipe(tbl)
        return
    end

    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function EnsureUnitAPI()
    Unit = Unit or (YUI.API and YUI.API.Unit)
    return Unit
end

local function GetNamePlateUnitFrame(nameplate)
    return SafeField(nameplate, "UnitFrame")
end

local function GetUnitFrameUnit(unitFrame)
    local unit = SafeField(unitFrame, "unit") or SafeField(unitFrame, "displayedUnit")
    if type(unit) == "string" and unit ~= "" then
        return unit
    end

    return nil
end

local function IsNonPlayerUnit(unit)
    local unitAPI = EnsureUnitAPI()
    if not unitAPI or not unitAPI.Exists or not unitAPI.IsPlayer then
        return false
    end

    return unitAPI.Exists(unit) and not unitAPI.IsPlayer(unit)
end

local function IsFriendlyPetOrMinionUnit(unit)
    local unitAPI = EnsureUnitAPI()
    if not unitAPI then
        return false
    end

    if unitAPI.IsUnit and unitAPI.IsUnit(unit, "pet") then
        return true
    end

    if unitAPI.IsMinion and unitAPI.IsMinion(unit) then
        return true
    end

    if unitAPI.IsOtherPlayersPet and unitAPI.IsOtherPlayersPet(unit) then
        return true
    end

    if unitAPI.IsBattlePet and unitAPI.IsBattlePet(unit) then
        return true
    end

    if unitAPI.IsOtherPlayersBattlePet and unitAPI.IsOtherPlayersBattlePet(unit) then
        return true
    end

    if unitAPI.IsBattlePetCompanion and unitAPI.IsBattlePetCompanion(unit) then
        return true
    end

    local guidType = unitAPI.GetGUIDType and unitAPI.GetGUIDType(unit) or nil
    return guidType == "Pet"
end

local function ShouldSuppressPlatynatorFriendlyNamePlate(unit, includeForbidden)
    if not platynatorFriendlyNamePlateSuppressionEnabled then
        return false, "DISABLED"
    end

    local unitAPI = EnsureUnitAPI()
    if not unitAPI or not unitAPI.Exists or not unitAPI.IsPlayer then
        return false, "MISSING_UNIT_API"
    end

    local exists = unitAPI.Exists(unit)
    local player = unitAPI.IsPlayer(unit)
    local guidType = unitAPI.GetGUIDType and unitAPI.GetGUIDType(unit) or nil

    if not exists or player then
        return false, "NOT_NPC"
    end

    if includeForbidden then
        return true, "FORBIDDEN_NPC"
    end

    if not unitAPI.IsFriend then
        return false, "MISSING_UNIT_API"
    end

    local friend = unitAPI.IsFriend(unit, "player")
    if not friend then
        return false, "NOT_FRIENDLY_NPC"
    end

    local ownPet = unitAPI.IsUnit and unitAPI.IsUnit(unit, "pet") or false
    local minion = unitAPI.IsMinion and unitAPI.IsMinion(unit) or false
    local otherPet = unitAPI.IsOtherPlayersPet and unitAPI.IsOtherPlayersPet(unit) or false
    local battlePet = unitAPI.IsBattlePet and unitAPI.IsBattlePet(unit) or false
    local otherBattlePet = unitAPI.IsOtherPlayersBattlePet and unitAPI.IsOtherPlayersBattlePet(unit) or false
    local companion = unitAPI.IsBattlePetCompanion and unitAPI.IsBattlePetCompanion(unit) or false
    local petOrMinion = ownPet or minion or otherPet or battlePet or otherBattlePet or companion or guidType == "Pet"

    if petOrMinion or IsFriendlyPetOrMinionUnit(unit) then
        return true, "FRIENDLY_PET_OR_MINION"
    end

    return false, "FRIENDLY_NPC_ALLOWED"
end

local function IsForbiddenOrSecureNamePlateUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return false
    end

    if suppressedForbiddenNamePlateUnits[unit] then
        return true
    end

    local normalNameplate = Frame.GetNamePlateForUnit and Frame.GetNamePlateForUnit(unit, false) or nil
    if normalNameplate then
        return false
    end

    local forbiddenNameplate = Frame.GetNamePlateForUnit and Frame.GetNamePlateForUnit(unit, true) or nil
    return forbiddenNameplate ~= nil
end

local function TextureGroupSet(target, key)
    if not target then
        return false, "NO_TARGET"
    end

    if not (TextureLoadingGroupMixin and TextureLoadingGroupMixin.AddTexture) then
        return false, "MISSING_TEXTURE_GROUP_API"
    end

    local ok, _, reason = SafeFunction(TextureLoadingGroupMixin.AddTexture, { textures = target }, key)
    return ok, reason
end

local function TextureGroupRemove(target, key)
    if not target then
        return false, "NO_TARGET"
    end

    if not (TextureLoadingGroupMixin and TextureLoadingGroupMixin.RemoveTexture) then
        return false, "MISSING_TEXTURE_GROUP_API"
    end

    local ok, _, reason = SafeFunction(TextureLoadingGroupMixin.RemoveTexture, { textures = target }, key)
    return ok, reason
end

local function ApplyTextureGroupFlag(target, key)
    if not key then
        return 0, 1
    end

    local ok = TextureGroupSet(target, key)
    if ok then
        return 1, 0
    end

    return 0, 1
end

local function RemoveTextureGroupFlag(target, key)
    if not key then
        return 0, 1
    end

    local ok = TextureGroupRemove(target, key)
    if ok then
        return 1, 0
    end

    return 0, 1
end

local function ApplyNamePlateTextureGroups(unitFrame)
    if not unitFrame then
        return false, "NO_UNIT_FRAME", 0, 0
    end

    local applied = 0
    local failed = 0
    local count, miss

    count, miss = ApplyTextureGroupFlag(unitFrame, "showOnlyName")
    applied = applied + count
    failed = failed + miss

    local healthBarsContainer = SafeField(unitFrame, "HealthBarsContainer")
    local healthBar = SafeField(healthBarsContainer, "healthBar") or SafeField(unitFrame, "healthBar")
    count, miss = ApplyTextureGroupFlag(healthBar, "showOnlyName")
    applied = applied + count
    failed = failed + miss

    local castBar = SafeField(unitFrame, "castBar") or SafeField(unitFrame, "CastBar")
    count, miss = ApplyTextureGroupFlag(castBar, "showOnlyName")
    applied = applied + count
    failed = failed + miss
    count, miss = ApplyTextureGroupFlag(castBar, "widgetsOnly")
    applied = applied + count
    failed = failed + miss

    local aurasFrame = SafeField(unitFrame, "AurasFrame")
    count, miss = ApplyTextureGroupFlag(aurasFrame, "showOnlyName")
    applied = applied + count
    failed = failed + miss
    count, miss = ApplyTextureGroupFlag(aurasFrame, "widgetsOnly")
    applied = applied + count
    failed = failed + miss

    local classificationFrame = SafeField(unitFrame, "ClassificationFrame")
    count, miss = ApplyTextureGroupFlag(classificationFrame, "showOnlyName")
    applied = applied + count
    failed = failed + miss
    count, miss = ApplyTextureGroupFlag(classificationFrame, "widgetsOnly")
    applied = applied + count
    failed = failed + miss

    local raidTargetFrame = SafeField(unitFrame, "RaidTargetFrame")
    count, miss = ApplyTextureGroupFlag(raidTargetFrame, "showOnlyName")
    applied = applied + count
    failed = failed + miss
    count, miss = ApplyTextureGroupFlag(raidTargetFrame, "widgetsOnly")
    applied = applied + count
    failed = failed + miss

    local optionTable = SafeField(unitFrame, "optionTable")
    count, miss = ApplyTextureGroupFlag(optionTable, "colorNameBySelection")
    applied = applied + count
    failed = failed + miss

    if applied > 0 then
        return true, failed > 0 and "TEXTURE_GROUP_PARTIAL" or "TEXTURE_GROUP_APPLIED", applied, failed
    end

    return false, failed > 0 and "TEXTURE_GROUP_FAILED" or "NO_TEXTURE_GROUP_TARGET", applied, failed
end

local function ApplyPlatynatorTextureSuppressionForUnitFrame(unitFrame, includeForbidden)
    if not platynatorFriendlyNamePlateSuppressionEnabled then
        return false, "DISABLED"
    end

    local unit = GetUnitFrameUnit(unitFrame)
    if not unit then
        return false, "NO_UNIT"
    end

    local secureOrForbidden = includeForbidden or IsForbiddenOrSecureNamePlateUnit(unit)
    local shouldSuppress, reason = ShouldSuppressPlatynatorFriendlyNamePlate(unit, secureOrForbidden)
    if not shouldSuppress then
        return false, reason
    end

    local ok, applyReason = ApplyNamePlateTextureGroups(unitFrame)
    return ok, applyReason
end

local function ClearSecureNamePlatePlayerFlag(unitFrame)
    if not platynatorFriendlyNamePlateSuppressionEnabled then
        return false, "DISABLED"
    end

    local unit = GetUnitFrameUnit(unitFrame)
    if not unit or not IsForbiddenOrSecureNamePlateUnit(unit) or not IsNonPlayerUnit(unit) then
        return false, "NOT_SECURE_NPC"
    end

    local isFriend = SafeField(unitFrame, "isFriend") == true
    if isFriend then
        return false, "FRIENDLY_ALLOWED"
    end

    local removed = RemoveTextureGroupFlag(unitFrame, "isPlayer")
    return removed > 0, removed > 0 and "PLAYER_FLAG_REMOVED" or "PLAYER_FLAG_UNCHANGED"
end

local function OnNamePlateUnitFrameMixinUpdateNameClassColor(unitFrame)
    ApplyPlatynatorTextureSuppressionForUnitFrame(unitFrame, false)
end

local function OnNamePlateUnitFrameMixinOnUnitSet(unitFrame)
    ApplyPlatynatorTextureSuppressionForUnitFrame(unitFrame, false)
end

local function OnNamePlateUnitFrameMixinUpdateIsFriend(unitFrame)
    ClearSecureNamePlatePlayerFlag(unitFrame)
end

function Frame.InstallPlatynatorFriendlyNamePlateTextureHooks()
    if platynatorNamePlateMixinHooksInstalled then
        return true, "HOOKED"
    end

    if not isRetail then
        return false, "NOT_RETAIL"
    end

    if not (NamePlateUnitFrameMixin and hooksecurefunc) then
        return false, "MISSING_NAMEPLATE_MIXIN"
    end

    local updateOk = platynatorUpdateNameClassColorHookInstalled
    if not updateOk then
        updateOk = SafeFunction(hooksecurefunc, NamePlateUnitFrameMixin, "UpdateNameClassColor", OnNamePlateUnitFrameMixinUpdateNameClassColor)
        platynatorUpdateNameClassColorHookInstalled = updateOk and true or false
    end

    local unitSetOk = platynatorOnUnitSetHookInstalled
    if not unitSetOk then
        unitSetOk = SafeFunction(hooksecurefunc, NamePlateUnitFrameMixin, "OnUnitSet", OnNamePlateUnitFrameMixinOnUnitSet)
        platynatorOnUnitSetHookInstalled = unitSetOk and true or false
    end

    local updateIsFriendOk = platynatorUpdateIsFriendHookInstalled
    if not updateIsFriendOk then
        updateIsFriendOk = SafeFunction(hooksecurefunc, NamePlateUnitFrameMixin, "UpdateIsFriend", OnNamePlateUnitFrameMixinUpdateIsFriend)
        platynatorUpdateIsFriendHookInstalled = updateIsFriendOk and true or false
    end

    platynatorNamePlateMixinHooksInstalled = platynatorUpdateNameClassColorHookInstalled
        and platynatorOnUnitSetHookInstalled
        and platynatorUpdateIsFriendHookInstalled

    if platynatorNamePlateMixinHooksInstalled then
        return true, "HOOKED"
    end

    return false, "HOOK_FAILED"
end

function Frame.GetPhysicalScreenSize()
    if GetPhysicalScreenSize then
        return GetPhysicalScreenSize()
    end

    if UIParent then
        return UIParent:GetWidth(), UIParent:GetHeight()
    end

    return 0, 0
end

function Frame.ReloadUI()
    if ReloadUI then
        return ReloadUI()
    end

    return nil
end

function Frame.IsShiftKeyDown()
    if IsShiftKeyDown then
        return IsShiftKeyDown()
    end

    return false
end

function Frame.IsAltKeyDown()
    if IsAltKeyDown then
        return IsAltKeyDown()
    end

    return false
end

function Frame.IsControlKeyDown()
    if IsControlKeyDown then
        return IsControlKeyDown()
    end

    return false
end

function Frame.ToggleCharacter(tab)
    if ToggleCharacter then
        return ToggleCharacter(tab)
    end

    return nil
end

function Frame.ToggleSpellBook()
    if isRetail then
        if PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
            return PlayerSpellsUtil.ToggleSpellBookFrame()
        elseif ToggleSpellBook then
            return ToggleSpellBook(BOOKTYPE_SPELL)
        end
    elseif ToggleSpellBook then
        return ToggleSpellBook(BOOKTYPE_SPELL)
    end

    return nil
end

function Frame.ToggleAchievementFrame()
    if ToggleAchievementFrame then
        return ToggleAchievementFrame()
    end

    return nil
end

function Frame.ToggleQuestLog()
    if ToggleQuestLog then
        return ToggleQuestLog()
    end

    return nil
end

function Frame.ToggleCollectionsJournal()
    if ToggleCollectionsJournal then
        return ToggleCollectionsJournal()
    end

    return nil
end

function Frame.ToggleEncounterJournal()
    if ToggleEncounterJournal then
        return ToggleEncounterJournal()
    end

    return nil
end

function Frame.TogglePVEFrame()
    if PVEFrame_ToggleFrame then
        return PVEFrame_ToggleFrame()
    elseif ToggleLFGParentFrame then
        return ToggleLFGParentFrame()
    end

    return nil
end

function Frame.TogglePVPUI()
    local togglePVPUI = isRetail and TogglePVPUI or TogglePVPFrame
    if togglePVPUI then
        return togglePVPUI()
    end

    return nil
end

function Frame.ToggleGameMenu()
    if not GameMenuFrame then return nil end

    if GameMenuFrame:IsShown() then
        if HideUIPanel then
            return HideUIPanel(GameMenuFrame)
        end
        return GameMenuFrame:Hide()
    end

    if ShowUIPanel then
        return ShowUIPanel(GameMenuFrame)
    end

    return GameMenuFrame:Show()
end

function Frame.GetNamePlateForUnit(unit, includeForbidden)
    if not unit or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then
        return nil
    end

    local ok, nameplate = pcall(C_NamePlate.GetNamePlateForUnit, unit, includeForbidden and true or false)
    if ok then
        return nameplate
    end

    return nil
end

function Frame.SuppressNamePlateUnitFrame(nameplate)
    local unitFrame = GetNamePlateUnitFrame(nameplate)
    if not unitFrame then
        return false, "NO_UNIT_FRAME"
    end

    return ApplyPlatynatorTextureSuppressionForUnitFrame(unitFrame, true)
end

function Frame.SetPlatynatorFriendlyNamePlateSuppressionEnabled(enabled)
    platynatorFriendlyNamePlateSuppressionEnabled = enabled and true or false

    if platynatorFriendlyNamePlateSuppressionEnabled then
        Frame.InstallPlatynatorFriendlyNamePlateTextureHooks()
    end

    if not platynatorFriendlyNamePlateSuppressionEnabled then
        ClearTable(suppressedForbiddenNamePlateUnits)
    end

    return platynatorFriendlyNamePlateSuppressionEnabled
end

function Frame.ClearPlatynatorFriendlyNamePlateSuppression(unit, includeForbidden)
    if type(unit) == "string" and unit ~= "" then
        suppressedForbiddenNamePlateUnits[unit] = nil
    end

    return true
end

function Frame.SuppressPlatynatorFriendlyNamePlate(unit, includeForbidden)
    if not platynatorFriendlyNamePlateSuppressionEnabled then
        return false, "DISABLED"
    end

    Frame.InstallPlatynatorFriendlyNamePlateTextureHooks()

    local shouldSuppress, reason = ShouldSuppressPlatynatorFriendlyNamePlate(unit, includeForbidden and true or false)
    if not shouldSuppress then
        return false, reason
    end

    if includeForbidden and type(unit) == "string" and unit ~= "" then
        suppressedForbiddenNamePlateUnits[unit] = true
    end

    local nameplate = Frame.GetNamePlateForUnit(unit, includeForbidden and true or false)
    if not nameplate then
        return false, "NO_NAMEPLATE"
    end

    local unitFrame = GetNamePlateUnitFrame(nameplate)
    if not unitFrame then
        return false, "NO_UNIT_FRAME"
    end

    return ApplyPlatynatorTextureSuppressionForUnitFrame(unitFrame, includeForbidden and true or false)
end

function Frame.SuppressForbiddenFriendlyNamePlate(unit)
    return Frame.SuppressPlatynatorFriendlyNamePlate(unit, true)
end

Legacy.GetPhysicalScreenSize = Frame.GetPhysicalScreenSize
Legacy.IsShiftKeyDown = Frame.IsShiftKeyDown
Legacy.IsAltKeyDown = Frame.IsAltKeyDown
Legacy.IsControlKeyDown = Frame.IsControlKeyDown
Legacy.ToggleCharacter = Frame.ToggleCharacter
Legacy.ToggleSpellBook = Frame.ToggleSpellBook
Legacy.ToggleAchievementFrame = Frame.ToggleAchievementFrame
Legacy.ToggleQuestLog = Frame.ToggleQuestLog
Legacy.ToggleCollectionsJournal = Frame.ToggleCollectionsJournal
Legacy.ToggleEncounterJournal = Frame.ToggleEncounterJournal
Legacy.TogglePVEFrame = Frame.TogglePVEFrame
Legacy.TogglePVPUI = Frame.TogglePVPUI
Legacy.ToggleGameMenu = Frame.ToggleGameMenu
Legacy.GetNamePlateForUnit = Frame.GetNamePlateForUnit
