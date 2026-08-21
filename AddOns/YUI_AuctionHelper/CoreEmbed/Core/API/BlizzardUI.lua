do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}

local BlizzardUI = YUI.API.BlizzardUI or {}
YUI.API.BlizzardUI = BlizzardUI

local SUPPRESSION_LATE_ADDONS = {
    Blizzard_MicroMenu = true,
    Blizzard_NewPlayerExperience = true,
    Blizzard_TalentUI = true,
    Blizzard_TutorialManager = true,
    Blizzard_Tutorials = true,
}

local ELEMENTS = {
    statusTrackingBars = {
        frameGroups = {
            { "StatusTrackingBarManager" },
            { "MainStatusTrackingBarContainer", "MainMenuExpBar", "ReputationWatchBar" },
        },
    },
    microMenu = {
        frameGroups = {
            { "MicroMenuContainer", "TalentMicroButtonAlert" },
            { "MicroMenu", "MainMenuBarMicroButtons", "TalentMicroButtonAlert" },
        },
    },
    bagsBar = {
        frameGroups = {
            { "BagsBar" },
            {
                "MainMenuBarBackpackButton",
                "CharacterBag0Slot",
                "CharacterBag1Slot",
                "CharacterBag2Slot",
                "CharacterBag3Slot",
            },
        },
    },
}

local COMPOSITES = {
    {
        requires = { "microMenu", "bagsBar" },
        frameGroups = {
            { "MicroButtonAndBagsBar" },
        },
    },
}

BlizzardUI.claims = BlizzardUI.claims or {}
BlizzardUI.frameState = BlizzardUI.frameState or setmetatable({}, { __mode = "k" })
BlizzardUI.hookedFrames = BlizzardUI.hookedFrames or setmetatable({}, { __mode = "k" })
BlizzardUI.suppressedFrames = BlizzardUI.suppressedFrames or setmetatable({}, { __mode = "k" })
BlizzardUI.desiredFrames = BlizzardUI.desiredFrames or setmetatable({}, { __mode = "k" })
BlizzardUI.helpTipAnchors = BlizzardUI.helpTipAnchors or setmetatable({}, { __mode = "k" })
BlizzardUI.failureCount = BlizzardUI.failureCount or 0
BlizzardUI.deferredCount = BlizzardUI.deferredCount or 0
BlizzardUI.microMenuLoadWatching = BlizzardUI.microMenuLoadWatching == true
BlizzardUI.microMenuTutorialPointerHooked = BlizzardUI.microMenuTutorialPointerHooked == true
BlizzardUI.helpTipHooked = BlizzardUI.helpTipHooked == true

local function ClearTable(tbl)
    if type(wipe) == "function" then
        wipe(tbl)
        return
    end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

local function SafeMethod(frame, method, ...)
    if not frame then return false end
    local ok, func = pcall(function()
        return frame[method]
    end)
    if not ok or type(func) ~= "function" then return false end
    return pcall(func, frame, ...)
end

local function IsFrameShown(frame)
    local ok, shown = SafeMethod(frame, "IsShown")
    return ok and shown == true
end

local function IsElementClaimed(elementId)
    local owners = BlizzardUI.claims[elementId]
    return type(owners) == "table" and next(owners) ~= nil
end

local function HasHelpTipAnchorClaims()
    for _, owners in pairs(BlizzardUI.helpTipAnchors) do
        if type(owners) == "table" and next(owners) ~= nil then return true end
    end
    return false
end

local function IsHelpTipSuppressionActive()
    return IsElementClaimed("microMenu")
        or IsElementClaimed("bagsBar")
        or HasHelpTipAnchorClaims()
end

local function IsDynamicHelpTipAnchor(anchor)
    local owners = BlizzardUI.helpTipAnchors[anchor]
    return type(owners) == "table" and next(owners) ~= nil
end

local function IsElementHelpTipAnchor(anchor, elementId)
    if elementId == "microMenu" then
        return anchor == _G.MicroMenuContainer
            or anchor == _G.MicroMenu
            or anchor == _G.MainMenuBarMicroButtons
    end
    if elementId == "bagsBar" then
        return anchor == _G.BagsBar
            or anchor == _G.MainMenuBarBackpackButton
            or anchor == _G.CharacterBag0Slot
            or anchor == _G.CharacterBag1Slot
            or anchor == _G.CharacterBag2Slot
            or anchor == _G.CharacterBag3Slot
            or anchor == _G.CharacterReagentBag0Slot
            or anchor == _G.BagBarExpandToggle
    end
    return false
end

local function IsSuppressedHelpTipAnchor(anchor)
    local current = anchor
    for _ = 1, 8 do
        if not current then return false end
        if IsDynamicHelpTipAnchor(current)
            or (IsElementClaimed("microMenu") and IsElementHelpTipAnchor(current, "microMenu"))
            or (IsElementClaimed("bagsBar") and IsElementHelpTipAnchor(current, "bagsBar"))
        then
            return true
        end

        local ok, parent = SafeMethod(current, "GetParent")
        if not ok or not parent or parent == current then return false end
        current = parent
    end
    return false
end

local function ShouldSuppressHelpTip(frame)
    if not frame then return false end
    if IsSuppressedHelpTipAnchor(frame.relativeRegion) then return true end
    local ok, parent = SafeMethod(frame, "GetParent")
    return ok and IsSuppressedHelpTipAnchor(parent)
end

local function CloseHelpTip(frame)
    local info = frame and frame.info
    local safeInfo
    if type(info) == "table" then
        safeInfo = {}
        for key, value in pairs(info) do safeInfo[key] = value end
        safeInfo.acknowledgeOnHide = false
        frame.info = safeInfo
    end

    local closed = SafeMethod(frame, "Close")
    if not closed then closed = SafeMethod(frame, "Hide") end
    if not closed and safeInfo and frame.info == safeInfo then frame.info = info end
    return closed
end

local function SuppressHelpTips()
    if not IsHelpTipSuppressionActive() then return true end
    local helpTip = _G.HelpTip
    local pool = helpTip and helpTip.framePool
    local enumerate = pool and pool.EnumerateActive
    if type(enumerate) ~= "function" then return true end

    local frames = {}
    local ok = pcall(function()
        for frame in enumerate(pool) do
            if IsFrameShown(frame) and ShouldSuppressHelpTip(frame) then
                frames[#frames + 1] = frame
            end
        end
    end)
    if not ok then
        BlizzardUI.failureCount = BlizzardUI.failureCount + 1
        return false
    end

    local success = true
    for index = 1, #frames do
        if not CloseHelpTip(frames[index]) then success = false end
    end
    if not success then BlizzardUI.failureCount = BlizzardUI.failureCount + 1 end
    return success
end

local function EnsureHelpTipHook()
    if BlizzardUI.helpTipHooked then return true end
    local helpTip = _G.HelpTip
    local hook = _G.hooksecurefunc
    if type(helpTip) ~= "table"
        or type(helpTip.Show) ~= "function"
        or type(hook) ~= "function"
    then
        return true
    end

    local ok = pcall(hook, helpTip, "Show", function()
        SuppressHelpTips()
    end)
    if not ok then
        BlizzardUI.failureCount = BlizzardUI.failureCount + 1
        return false
    end
    BlizzardUI.helpTipHooked = true
    return true
end

local function IsMicroMenuTutorialAnchor(anchor)
    local current = anchor
    for _ = 1, 8 do
        if not current then return false end
        if current == _G.MicroMenuContainer
            or current == _G.MicroMenu
            or current == _G.MainMenuBarMicroButtons
        then
            return true
        end

        local ok, parent = SafeMethod(current, "GetParent")
        if not ok or not parent or parent == current then return false end
        current = parent
    end
    return false
end

local function HideMicroMenuTutorialPointers(manager)
    manager = manager or _G.TutorialPointerFrame
    local inUseFrames = manager and manager.InUseFrames
    local hide = manager and manager.Hide
    if type(inUseFrames) ~= "table" or type(hide) ~= "function" then return true end

    while true do
        local pointerId
        for id, frame in pairs(inUseFrames) do
            if IsMicroMenuTutorialAnchor(frame and frame.currentTarget) then
                pointerId = id
                break
            end
        end
        if pointerId == nil then return true end

        local ok = pcall(hide, manager, pointerId)
        if not ok then
            BlizzardUI.failureCount = BlizzardUI.failureCount + 1
            return false
        end
    end
end

local function OnTutorialPointerShown(manager, _, _, anchor)
    if IsElementClaimed("microMenu") and IsMicroMenuTutorialAnchor(anchor) then
        HideMicroMenuTutorialPointers(manager)
    end
end

local function SuppressMicroMenuTutorialPointers()
    if not BlizzardUI.microMenuTutorialPointerHooked then
        local manager = _G.TutorialPointerFrame
        local hook = _G.hooksecurefunc
        if type(manager) == "table"
            and type(manager.Show) == "function"
            and type(hook) == "function"
        then
            local ok = pcall(hook, manager, "Show", OnTutorialPointerShown)
            if not ok then
                BlizzardUI.failureCount = BlizzardUI.failureCount + 1
                return false
            end
            BlizzardUI.microMenuTutorialPointerHooked = true
        end
    end

    return HideMicroMenuTutorialPointers()
end

local function EnsureSuppressionLoadFrame()
    if BlizzardUI.microMenuLoadFrame or type(CreateFrame) ~= "function" then
        return BlizzardUI.microMenuLoadFrame
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, addonName)
        if event ~= "ADDON_LOADED" or SUPPRESSION_LATE_ADDONS[addonName] ~= true then return end
        if IsHelpTipSuppressionActive() then
            BlizzardUI:Refresh("suppression-addon-loaded")
        end
    end)
    BlizzardUI.microMenuLoadFrame = frame
    return frame
end

local function SetSuppressionLoadWatching(watching)
    watching = watching == true
    if watching == BlizzardUI.microMenuLoadWatching then return true end

    local frame = watching and EnsureSuppressionLoadFrame() or BlizzardUI.microMenuLoadFrame
    if not frame then return true end

    local method = watching and "RegisterEvent" or "UnregisterEvent"
    local ok = SafeMethod(frame, method, "ADDON_LOADED")
    if not ok then
        BlizzardUI.failureCount = BlizzardUI.failureCount + 1
        return false
    end
    BlizzardUI.microMenuLoadWatching = watching
    return true
end

local function AddFirstAvailableFrameGroup(target, frameGroups)
    for _, names in ipairs(frameGroups or {}) do
        local found = false
        for _, name in ipairs(names) do
            local frame = _G[name]
            if frame then
                target[frame] = true
                found = true
            end
        end
        if found then return true end
    end
    return false
end

local function BuildDesiredFrames()
    local desired = BlizzardUI.desiredFrames
    ClearTable(desired)

    for elementId, definition in pairs(ELEMENTS) do
        if IsElementClaimed(elementId) then
            AddFirstAvailableFrameGroup(desired, definition.frameGroups)
        end
    end

    for _, composite in ipairs(COMPOSITES) do
        local active = true
        for _, elementId in ipairs(composite.requires) do
            if not IsElementClaimed(elementId) then
                active = false
                break
            end
        end
        if active then
            AddFirstAvailableFrameGroup(desired, composite.frameGroups)
        end
    end

    return desired
end

local function IsInCombat()
    local security = YUI.API and YUI.API.Security
    if security and type(security.InCombatLockdown) == "function" then
        local ok, result = pcall(security.InCombatLockdown)
        if ok then return result == true end
    end
    if type(InCombatLockdown) == "function" then
        local ok, result = pcall(InCombatLockdown)
        return ok and result == true
    end
    return false
end

local function EnsureDeferredFrame()
    if BlizzardUI.deferredFrame or type(CreateFrame) ~= "function" then
        return BlizzardUI.deferredFrame
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        BlizzardUI.pendingRefresh = false
        BlizzardUI:Refresh("combat-ended")
    end)
    BlizzardUI.deferredFrame = frame
    return frame
end

local function QueueDeferredRefresh()
    if BlizzardUI.pendingRefresh == true then return end
    BlizzardUI.pendingRefresh = true
    BlizzardUI.deferredCount = BlizzardUI.deferredCount + 1
    local frame = EnsureDeferredFrame()
    if frame and type(frame.RegisterEvent) == "function" then
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

local function HideSuppressedFrame(frame)
    local state = BlizzardUI.frameState[frame]
    if not state then return false end
    state.selfHiding = true
    local ok = SafeMethod(frame, "Hide")
    state.selfHiding = false
    if not ok then
        BlizzardUI.failureCount = BlizzardUI.failureCount + 1
        if IsInCombat() then QueueDeferredRefresh() end
    end
    return ok
end

local function OnFrameShown(frame)
    if BlizzardUI.suppressedFrames[frame] ~= true then return end
    local state = BlizzardUI.frameState[frame]
    if state then state.restoreShown = true end
    HideSuppressedFrame(frame)
end

local function OnFrameHidden(frame)
    if BlizzardUI.suppressedFrames[frame] ~= true then return end
    local state = BlizzardUI.frameState[frame]
    if state and state.selfHiding ~= true then
        state.restoreShown = false
    end
end

local function InstallFrameHooks(frame)
    if BlizzardUI.hookedFrames[frame] == true then return true end
    local okShow = SafeMethod(frame, "HookScript", "OnShow", OnFrameShown)
    local okHide = SafeMethod(frame, "HookScript", "OnHide", OnFrameHidden)
    if okShow and okHide then
        BlizzardUI.hookedFrames[frame] = true
        return true
    end
    BlizzardUI.failureCount = BlizzardUI.failureCount + 1
    return false
end

local function SuppressFrame(frame)
    local state = BlizzardUI.frameState[frame]
    if not state then
        state = {
            restoreShown = IsFrameShown(frame),
        }
        BlizzardUI.frameState[frame] = state
        state.hooksInstalled = InstallFrameHooks(frame)
    end
    BlizzardUI.suppressedFrames[frame] = true
    local hidden = true
    if IsFrameShown(frame) then
        hidden = HideSuppressedFrame(frame)
    end
    return hidden and state.hooksInstalled == true
end

local function RestoreFrame(frame)
    local state = BlizzardUI.frameState[frame]
    BlizzardUI.suppressedFrames[frame] = nil
    if not state then return true end

    local ok
    if state.restoreShown == true then
        ok = SafeMethod(frame, "Show")
    else
        ok = SafeMethod(frame, "Hide")
    end
    if ok then
        BlizzardUI.frameState[frame] = nil
        return true
    end

    BlizzardUI.failureCount = BlizzardUI.failureCount + 1
    if IsInCombat() then QueueDeferredRefresh() end
    return false
end

local function ValidateOwnerAndElement(owner, elementId)
    if owner == nil then return false, "owner-required" end
    if ELEMENTS[elementId] == nil then return false, "unknown-element" end
    return true
end

function BlizzardUI:Refresh()
    local microMenuClaimed = IsElementClaimed("microMenu")
    local helpTipSuppressionActive = IsHelpTipSuppressionActive()
    local desired = BuildDesiredFrames()
    local failures = 0
    local restoreFrames = {}

    if microMenuClaimed then
        if not SuppressMicroMenuTutorialPointers() then failures = failures + 1 end
    end
    if helpTipSuppressionActive then
        if not EnsureHelpTipHook() then failures = failures + 1 end
        if not SuppressHelpTips() then failures = failures + 1 end
    end
    if not SetSuppressionLoadWatching(helpTipSuppressionActive) then failures = failures + 1 end

    for frame in pairs(self.frameState) do
        if desired[frame] ~= true then
            restoreFrames[#restoreFrames + 1] = frame
        end
    end
    for _, frame in ipairs(restoreFrames) do
        if not RestoreFrame(frame) then
            failures = failures + 1
        end
    end
    for frame in pairs(desired) do
        if not SuppressFrame(frame) then
            failures = failures + 1
        end
    end

    if failures > 0 and IsInCombat() then
        QueueDeferredRefresh()
        return false, "combat-deferred"
    end
    if failures > 0 then
        return false, "frame-operation-failed"
    end
    return true
end

function BlizzardUI:Acquire(owner, elementId)
    local valid, reason = ValidateOwnerAndElement(owner, elementId)
    if not valid then return false, reason end
    local owners = self.claims[elementId]
    if not owners then
        owners = {}
        self.claims[elementId] = owners
    end
    owners[owner] = true
    return self:Refresh("acquire")
end

function BlizzardUI:Release(owner, elementId)
    local valid, reason = ValidateOwnerAndElement(owner, elementId)
    if not valid then return false, reason end
    local owners = self.claims[elementId]
    if owners then
        owners[owner] = nil
        if next(owners) == nil then self.claims[elementId] = nil end
    end
    return self:Refresh("release")
end

function BlizzardUI:AcquireHelpTipAnchor(owner, anchor)
    if owner == nil then return false, "owner-required" end
    if anchor == nil then return false, "anchor-required" end
    local owners = self.helpTipAnchors[anchor]
    if not owners then
        owners = {}
        self.helpTipAnchors[anchor] = owners
    end
    owners[owner] = true
    return self:Refresh("help-tip-anchor-acquire")
end

function BlizzardUI:ReleaseHelpTipAnchor(owner, anchor)
    if owner == nil then return false, "owner-required" end
    if anchor == nil then return false, "anchor-required" end
    local owners = self.helpTipAnchors[anchor]
    if owners then
        owners[owner] = nil
        if next(owners) == nil then self.helpTipAnchors[anchor] = nil end
    end
    return self:Refresh("help-tip-anchor-release")
end

function BlizzardUI:SetOwnerSuppression(owner, elements)
    if owner == nil then return false, "owner-required" end
    if type(elements) ~= "table" then return false, "elements-required" end
    for elementId in pairs(elements) do
        if ELEMENTS[elementId] == nil then return false, "unknown-element" end
    end

    for elementId in pairs(ELEMENTS) do
        local owners = self.claims[elementId]
        if elements[elementId] == true then
            if not owners then
                owners = {}
                self.claims[elementId] = owners
            end
            owners[owner] = true
        elseif owners then
            owners[owner] = nil
            if next(owners) == nil then self.claims[elementId] = nil end
        end
    end
    return self:Refresh("owner-update")
end

function BlizzardUI:ReleaseOwner(owner)
    if owner == nil then return false, "owner-required" end
    for elementId, owners in pairs(self.claims) do
        owners[owner] = nil
        if next(owners) == nil then self.claims[elementId] = nil end
    end
    for anchor, owners in pairs(self.helpTipAnchors) do
        owners[owner] = nil
        if next(owners) == nil then self.helpTipAnchors[anchor] = nil end
    end
    return self:Refresh("owner-release")
end

function BlizzardUI:IsSuppressed(elementId)
    if ELEMENTS[elementId] == nil then return false end
    return IsElementClaimed(elementId)
end

function BlizzardUI:GetStats()
    local claimedElements = 0
    local owners = 0
    local suppressedFrames = 0
    local helpTipAnchors = 0
    for _, claims in pairs(self.claims) do
        claimedElements = claimedElements + 1
        for _ in pairs(claims) do owners = owners + 1 end
    end
    for _ in pairs(self.suppressedFrames) do suppressedFrames = suppressedFrames + 1 end
    for _ in pairs(self.helpTipAnchors) do helpTipAnchors = helpTipAnchors + 1 end
    return {
        claimedElements = claimedElements,
        ownerClaims = owners,
        suppressedFrames = suppressedFrames,
        helpTipAnchors = helpTipAnchors,
        pendingRefresh = self.pendingRefresh == true,
        deferredCount = self.deferredCount or 0,
        failureCount = self.failureCount or 0,
    }
end
