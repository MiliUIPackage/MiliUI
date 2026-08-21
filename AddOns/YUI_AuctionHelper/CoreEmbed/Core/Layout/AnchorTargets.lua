do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - anchor targets
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local GUI2 = P.GUI2
local CreateFrame = P.CreateFrame
local UIParent = P.UIParent
local SafeCall = P.SafeCall
local Round = P.Round
local pairs = P.pairs
local ipairs = P.ipairs
local type = P.type
local tostring = P.tostring
local tonumber = P.tonumber
local math_max = P.math_max
local string_find = P.string_find
local string_gsub = P.string_gsub
local OVERLAY_STRATA = P.OVERLAY_STRATA
local ANCHOR_OVERLAY_FRAME_LEVEL = P.ANCHOR_OVERLAY_FRAME_LEVEL
local MOVER_COLOR_PLACEHOLDER = P.MOVER_COLOR_PLACEHOLDER
local MOVER_BG_PLACEHOLDER = P.MOVER_BG_PLACEHOLDER
local PLACEMENT_SIMULATED = P.PLACEMENT_SIMULATED
local select = select

local BUILTIN_PLAYER = "@YUI.PlayerFrame"
local BUILTIN_TARGET = "@YUI.TargetFrame"
local BUILTIN_PARTY = "@YUI.PartyFrame"
local BUILTIN_RAID = "@YUI.RaidFrame"

local BUILTIN_ORDER = {
    BUILTIN_PLAYER,
    BUILTIN_TARGET,
    BUILTIN_PARTY,
    BUILTIN_RAID,
}

local BUILTIN_LABELS = {
    [BUILTIN_PLAYER] = "layout.anchor_target.player",
    [BUILTIN_TARGET] = "layout.anchor_target.target",
    [BUILTIN_PARTY] = "layout.anchor_target.party",
    [BUILTIN_RAID] = "layout.anchor_target.raid",
}

local AnchorTargetDisplayText

local PLACEHOLDER_SPECS = {
    [BUILTIN_PLAYER] = { width = 220, height = 48, point = "BOTTOM", relativePoint = "BOTTOM", x = -240, y = 190 },
    [BUILTIN_TARGET] = { width = 220, height = 48, point = "BOTTOM", relativePoint = "BOTTOM", x = 240, y = 190 },
    [BUILTIN_PARTY] = { width = 220, height = 176, point = "LEFT", relativePoint = "LEFT", x = 180, y = -70 },
    [BUILTIN_RAID] = { width = 320, height = 260, point = "LEFT", relativePoint = "LEFT", x = 220, y = 40 },
}

local function L(key)
    return P.L and P.L(key) or key
end

local function TrimText(value)
    value = tostring(value or "")
    value = string_gsub(value, "^%s+", "")
    value = string_gsub(value, "%s+$", "")
    return value
end

local function AddOnLoaded(name)
    local System = YUI.API and YUI.API.System
    if System and type(System.IsAddOnLoadedSafe) == "function" then
        return System.IsAddOnLoadedSafe(name) == true
    end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = SafeCall("Layout:anchorTarget:C_AddOns.IsAddOnLoaded:" .. tostring(name), C_AddOns.IsAddOnLoaded, name)
        return ok and loaded == true
    end
    if type(IsAddOnLoaded) == "function" then
        local ok, loaded = SafeCall("Layout:anchorTarget:IsAddOnLoaded:" .. tostring(name), IsAddOnLoaded, name)
        return ok and loaded == true
    end
    return false
end

local function HasAddOn(addonName, globalName)
    return AddOnLoaded(addonName) or _G[globalName or addonName] ~= nil
end

local function GetDB()
    if not P.EnsureDB then return nil end
    local db = P.EnsureDB()
    if type(db) ~= "table" then return nil end
    if type(db.anchorPlaceholders) ~= "table" then
        db.anchorPlaceholders = {}
    end
    return db
end

local function CopyPlaceholderPlacement(value)
    if type(value) ~= "table" then return nil end
    return {
        point = value.point or "CENTER",
        relative = "UIParent",
        relativePoint = value.relativePoint or "CENTER",
        x = tonumber(value.x) or 0,
        y = tonumber(value.y) or 0,
    }
end

local function GetPlaceholderPlacement(value)
    local spec = PLACEHOLDER_SPECS[value]
    if not spec then return nil end

    local db = GetDB()
    local saved = db and db.anchorPlaceholders and db.anchorPlaceholders[value]
    local placement = CopyPlaceholderPlacement(saved)
    if placement then return placement end

    return {
        point = spec.point,
        relative = "UIParent",
        relativePoint = spec.relativePoint,
        x = spec.x,
        y = spec.y,
    }
end

local function SavePlaceholderPlacement(value, frame)
    local db = GetDB()
    if not db or not frame or not frame.GetLeft then return false end

    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    local width = frame:GetWidth() or 0
    local height = frame:GetHeight() or 0
    local parentWidth = UIParent and UIParent:GetWidth() or 0
    local parentHeight = UIParent and UIParent:GetHeight() or 0
    if not left or not bottom then return false end

    db.anchorPlaceholders[value] = {
        point = "CENTER",
        relative = "UIParent",
        relativePoint = "CENTER",
        x = Round(left + width / 2 - parentWidth / 2),
        y = Round(bottom + height / 2 - parentHeight / 2),
    }
    return true
end

local function PaintPlaceholder(frame)
    if not frame then return end
    local bg = MOVER_BG_PLACEHOLDER or { 0.08, 0.62, 1.00, 0.18 }
    local border = MOVER_COLOR_PLACEHOLDER or { 0.08, 0.78, 1.00, 0.95 }
    if frame.SetBackdropColor then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    end
    if GUI2 and GUI2.SetBorderColor then
        GUI2:SetBorderColor(frame, border[1], border[2], border[3], border[4])
    elseif frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end
    if frame.label and frame.label.SetTextColor then
        frame.label:SetTextColor(border[1], border[2], border[3], border[4] or 1)
    end
end

local function ApplyPlaceholderPlacement(frame, value)
    local placement = GetPlaceholderPlacement(value)
    local spec = PLACEHOLDER_SPECS[value]
    if not frame or not placement or not spec then return end
    frame:SetSize(spec.width, spec.height)
    frame:ClearAllPoints()
    frame:SetPoint(placement.point or "CENTER", UIParent, placement.relativePoint or "CENTER", placement.x or 0, placement.y or 0)
end

local function CreatePlaceholderFrame(value)
    local spec = PLACEHOLDER_SPECS[value]
    if not spec or not CreateFrame then return nil end

    Layout.anchorTargetPlaceholders = Layout.anchorTargetPlaceholders or {}
    if Layout.anchorTargetPlaceholders[value] then
        return Layout.anchorTargetPlaceholders[value]
    end

    local safeName = string_gsub(string_gsub(value, "^@YUI%.", ""), "[^%w_]", "_")
    local name = "YUI_LayoutAnchorPlaceholder_" .. safeName
    local frame = CreateFrame("Button", name, UIParent, "BackdropTemplate")
    frame.yuiLayoutInternal = true
    frame.yuiLayoutAnchorPlaceholder = value
    frame:SetSize(spec.width, spec.height)
    frame:SetFrameStrata(OVERLAY_STRATA)
    frame:SetFrameLevel((ANCHOR_OVERLAY_FRAME_LEVEL or 55) - 1)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    end
    if GUI2 and GUI2.CreateBorder then GUI2:CreateBorder(frame, "color.border.accent") end

    local label
    if GUI2 and GUI2.CreateText then
        label = GUI2:CreateText(frame, AnchorTargetDisplayText(value), "font.size.md", "color.text.primary")
    else
        label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    label:SetPoint("CENTER")
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetWidth(math_max((spec.width or 0) - 8, 10))
    frame.label = label

    frame:SetScript("OnDragStart", function(self)
        if not Layout.editing or Layout.anchorPickerEntryId or (P.InCombat and P.InCombat()) then return end
        if P.GetOptions and P.GetOptions().locked then return end
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePlaceholderPlacement(value, self)
        if Layout.ApplyAllPlacements then Layout:ApplyAllPlacements() end
        if Layout.RefreshOverlays then Layout:RefreshOverlays() end
        if Layout.RefreshAnchorLine then Layout:RefreshAnchorLine() end
        if Layout.RefreshMovementWidgets then Layout:RefreshMovementWidgets() end
    end)

    Layout.anchorTargetPlaceholders[value] = frame
    return frame
end

local function GetBuiltinAnchorPlaceholder(value)
    value = TrimText(value)
    if not Layout.editing or not PLACEHOLDER_SPECS[value] then return nil end

    local frame = CreatePlaceholderFrame(value)
    if not frame then return nil end
    ApplyPlaceholderPlacement(frame, value)
    PaintPlaceholder(frame)
    frame:Show()
    return frame
end
P.GetBuiltinAnchorPlaceholder = GetBuiltinAnchorPlaceholder

local function HideBuiltinAnchorPlaceholder(value)
    value = TrimText(value)
    local frame = Layout.anchorTargetPlaceholders and Layout.anchorTargetPlaceholders[value]
    if frame then frame:Hide() end
end
P.HideBuiltinAnchorPlaceholder = HideBuiltinAnchorPlaceholder

local function HideBuiltinAnchorPlaceholders()
    for _, frame in pairs(Layout.anchorTargetPlaceholders or {}) do
        if frame then frame:Hide() end
    end
end
P.HideBuiltinAnchorPlaceholders = HideBuiltinAnchorPlaceholders

local function RefreshBuiltinAnchorPlaceholderVisibility()
    if not Layout.editing then
        HideBuiltinAnchorPlaceholders()
        return
    end

    for value, frame in pairs(Layout.anchorTargetPlaceholders or {}) do
        local needed = false
        for _, id in ipairs(Layout.order or {}) do
            local entry = Layout.frames and Layout.frames[id]
            if entry and entry.placementState == PLACEMENT_SIMULATED and entry.pendingAnchor == value then
                needed = true
                break
            end
        end
        if needed then
            ApplyPlaceholderPlacement(frame, value)
            PaintPlaceholder(frame)
            frame:Show()
        elseif frame then
            frame:Hide()
        end
    end
end
P.RefreshBuiltinAnchorPlaceholderVisibility = RefreshBuiltinAnchorPlaceholderVisibility

local function IsUsableAnchorFrame(frame)
    if not frame then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return frame.GetObjectType or frame.IsObjectType or frame.GetLeft
end
P.IsUsableAnchorFrame = P.IsUsableAnchorFrame or IsUsableAnchorFrame

local function ReadFrameGeometry(frame)
    if type(frame.IsShown) == "function" and frame:IsShown() ~= true then return nil end
    if type(frame.GetWidth) ~= "function" or type(frame.GetHeight) ~= "function"
        or type(frame.GetLeft) ~= "function" or type(frame.GetBottom) ~= "function" then
        return nil
    end
    local width = tonumber(frame:GetWidth()) or 0
    local height = tonumber(frame:GetHeight()) or 0
    if width <= 0 or height <= 0 then return nil end
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()
    if left == nil or bottom == nil then return nil end
    return left, bottom, width, height
end

local function ReadVisibleAnchorFrameGeometry(frame)
    if not IsUsableAnchorFrame(frame) then return nil end
    local ok, left, bottom, width, height = SafeCall(
        "Layout:anchorTarget:geometry",
        ReadFrameGeometry,
        frame
    )
    if not ok then return nil end
    return left, bottom, width, height
end
P.ReadVisibleAnchorFrameGeometry = ReadVisibleAnchorFrameGeometry

local function IsVisibleSizedFrame(frame)
    return ReadVisibleAnchorFrameGeometry(frame) ~= nil
end

local function AddFrameCandidate(candidates, seen, frame)
    if type(frame) == "string" then
        frame = _G[frame]
    end
    if not IsUsableAnchorFrame(frame) or seen[frame] then return end
    seen[frame] = true
    candidates[#candidates + 1] = frame
end

local function AddNamedCandidates(candidates, seen, ...)
    for index = 1, select("#", ...) do
        AddFrameCandidate(candidates, seen, _G[select(index, ...)])
    end
end

local function GetParentFrame(frame)
    if not frame or type(frame.GetParent) ~= "function" then return nil end
    local ok, parent = SafeCall("Layout:anchorTarget:GetParent", frame.GetParent, frame)
    if ok then return parent end
    return nil
end

local function AddFrameCandidateWithParent(candidates, seen, frame)
    if type(frame) == "string" then frame = _G[frame] end
    AddFrameCandidate(candidates, seen, GetParentFrame(frame))
    AddFrameCandidate(candidates, seen, frame)
end

local function PickCandidate(candidates, requireVisible)
    for _, frame in ipairs(candidates) do
        if IsVisibleSizedFrame(frame) then
            return frame
        end
    end
    if requireVisible then return nil end
    for _, frame in ipairs(candidates) do
        if IsUsableAnchorFrame(frame) then
            return frame
        end
    end
    return nil
end

local function PickFromProvider(addCandidates, kind, requireVisible)
    local candidates = {}
    local seen = {}
    local active = addCandidates(kind, candidates, seen)
    return PickCandidate(candidates, requireVisible), active == true
end

local function PickFromProviders(kind, providers, requireVisible)
    for _, addCandidates in ipairs(providers) do
        local frame, active = PickFromProvider(addCandidates, kind, requireVisible)
        if frame then return frame end
        if active then return nil end
    end
    return PickFromProvider(function(nativeKind, candidates, seen)
        if nativeKind == "player" then
            AddFrameCandidate(candidates, seen, _G.PlayerFrame)
        elseif nativeKind == "target" then
            AddFrameCandidate(candidates, seen, _G.TargetFrame)
        elseif nativeKind == "party" then
            AddFrameCandidate(candidates, seen, _G.PartyFrame)
            AddFrameCandidate(candidates, seen, _G.CompactPartyFrame)
        elseif nativeKind == "raid" then
            AddFrameCandidate(candidates, seen, _G.CompactRaidFrameContainer)
            AddFrameCandidate(candidates, seen, _G.RaidFrame)
        end
    end, kind, requireVisible)
end

local function GetElvUIUnitFrames()
    local ns = _G.ElvUI
    local core = type(ns) == "table" and ns[1] or nil
    if core and type(core.GetModule) == "function" then
        local ok, module = SafeCall("Layout:anchorTarget:ElvUI.GetModule", core.GetModule, core, "UnitFrames", true)
        if ok and type(module) == "table" then return module end
    end
    return nil
end

local function AddElvUICandidates(kind, candidates, seen)
    local active = HasAddOn("ElvUI", "ElvUI") or _G.ElvUF_Player or _G.ElvUF_Target or _G.ElvUF_Party
    if not active then return false end

    local uf = GetElvUIUnitFrames()
    local units = uf and uf.units
    local headers = uf and uf.headers

    if kind == "player" then
        AddNamedCandidates(candidates, seen, "ElvUF_Player")
        AddFrameCandidate(candidates, seen, units and units.player)
    elseif kind == "target" then
        AddNamedCandidates(candidates, seen, "ElvUF_Target")
        AddFrameCandidate(candidates, seen, units and units.target)
    elseif kind == "party" then
        AddNamedCandidates(candidates, seen, "ElvUF_Party", "ElvUF_PartyGroup1")
        AddFrameCandidate(candidates, seen, headers and (headers.party or headers.party1))
    elseif kind == "raid" then
        AddNamedCandidates(candidates, seen, "ElvUF_Raid1", "ElvUF_Raid2", "ElvUF_Raid3", "ElvUF_Raid")
        AddNamedCandidates(candidates, seen, "ElvUF_Raid1Group1", "ElvUF_Raid2Group1", "ElvUF_Raid3Group1")
        AddFrameCandidate(candidates, seen, headers and (headers.raid1 or headers.raid or headers.raid2 or headers.raid3))
    end
    return true
end

local function GetNDuiObjects()
    local ns = _G.NDui or _G.NDUI
    local oUF = type(ns) == "table" and ns.oUF or nil
    local objects = oUF and oUF.objects
    if type(objects) == "table" then return objects end
    return nil
end

local function GetFrameUnit(frame)
    if not frame then return nil end
    if type(frame.unit) == "string" then return frame.unit end
    if type(frame.GetAttribute) == "function" then
        local ok, unit = SafeCall("Layout:anchorTarget:GetAttribute(unit)", frame.GetAttribute, frame, "unit")
        if ok and type(unit) == "string" then return unit end
    end
    return nil
end

local function UnitMatchesKind(unit, kind)
    if type(unit) ~= "string" then return false end
    if kind == "player" or kind == "target" then
        return unit == kind
    end
    return string_find(unit, kind, 1, true) ~= nil
end

local function AddNDuiCandidates(kind, candidates, seen)
    local active = HasAddOn("NDui", "NDui") or HasAddOn("NDUI", "NDUI") or _G.oUF_Player or _G.oUF_Target
    if not active then return false end

    if kind == "player" then
        AddNamedCandidates(candidates, seen, "oUF_Player")
    elseif kind == "target" then
        AddNamedCandidates(candidates, seen, "oUF_Target")
    elseif kind == "party" then
        AddNamedCandidates(candidates, seen, "oUF_Party", "oUF_PartyHeader", "oUF_PartyUnitButton1")
    elseif kind == "raid" then
        AddNamedCandidates(candidates, seen, "oUF_Raid", "oUF_Raid1")
        for group = 1, 8 do
            AddFrameCandidateWithParent(candidates, seen, _G["oUF_Raid" .. group .. "UnitButton1"])
        end
    end

    local objects = GetNDuiObjects()
    if not objects then return true end
    for _, frame in pairs(objects) do
        if UnitMatchesKind(GetFrameUnit(frame), kind) then
            if kind == "party" or kind == "raid" then
                AddFrameCandidateWithParent(candidates, seen, frame)
            else
                AddFrameCandidate(candidates, seen, frame)
            end
        end
    end
    return true
end

local function AddEQoLUnitCandidates(kind, candidates, seen)
    if kind == "player" then
        AddNamedCandidates(candidates, seen, "EQOLUFPlayerFrame")
    elseif kind == "target" then
        AddNamedCandidates(candidates, seen, "EQOLUFTargetFrame")
    elseif kind == "party" then
        AddNamedCandidates(candidates, seen, "EQOLUFPartyHeader", "EQOLUFPartyFrame", "EQOLUFPartyHeaderUnitButton1")
    elseif kind == "raid" then
        AddNamedCandidates(candidates, seen, "EQOLUFRaidHeader", "EQOLUFRaidFrame", "EQOLUFRaidHeader1")
    end
end

local function GetEQoLGroupFrames()
    local addon = _G.EnhanceQoL
    return addon and addon.Aura and addon.Aura.UF and addon.Aura.UF.GroupFrames or nil
end

local function AddEQoLGroupContainer(candidates, seen, container, kind)
    if not container then return end
    if container._eqolGroupKind == kind then
        AddFrameCandidate(candidates, seen, container)
        return
    end
    if type(container.GetChildren) ~= "function" then return end
    local ok, children = SafeCall("Layout:anchorTarget:EQoL.GetChildren", function(frame)
        return { frame:GetChildren() }
    end, container)
    if not ok or type(children) ~= "table" then return end
    for _, child in ipairs(children) do
        if child and child._eqolGroupKind == kind then
            AddFrameCandidate(candidates, seen, container)
            AddFrameCandidate(candidates, seen, child)
        end
    end
end

local function AddEQoLCandidates(kind, candidates, seen)
    local active = HasAddOn("EnhanceQoL", "EnhanceQoL") or _G.EQOLUFPlayerFrame or _G.EQOLUFTargetFrame
    if not active then return false end

    AddEQoLUnitCandidates(kind, candidates, seen)
    if kind ~= "party" and kind ~= "raid" then return true end

    local groupFrames = GetEQoLGroupFrames()
    if type(groupFrames) ~= "table" then return true end
    if type(groupFrames.anchors) == "table" then
        for key, anchor in pairs(groupFrames.anchors) do
            if key == kind then AddFrameCandidate(candidates, seen, anchor) end
            AddEQoLGroupContainer(candidates, seen, anchor, kind)
        end
    end
    if type(groupFrames.headers) == "table" then
        for key, header in pairs(groupFrames.headers) do
            if key == kind then AddFrameCandidate(candidates, seen, header) end
            AddEQoLGroupContainer(candidates, seen, header, kind)
        end
    end
    return true
end

local function AddEllesmereUICandidates(kind, candidates, seen)
    local frame
    if kind == "player" then
        frame = _G.EllesmereUIUnitFrames_Player
    elseif kind == "target" then
        frame = _G.EllesmereUIUnitFrames_Target
    end
    if not IsUsableAnchorFrame(frame) then return false end

    AddFrameCandidate(candidates, seen, frame)
    return true
end

local function AddCellCandidates(kind, candidates, seen)
    if kind ~= "party" and kind ~= "raid" then return false end
    local active = HasAddOn("Cell", "Cell") or _G.CellMainFrame or _G.CellPartyFrame or _G.CellRaidFrame
    if not active then return false end

    local cell = _G.Cell
    local frames = type(cell) == "table" and cell.frames or nil
    if kind == "party" then
        AddFrameCandidate(candidates, seen, frames and frames.partyFrame)
        AddNamedCandidates(candidates, seen, "CellPartyFrame", "CellPartyFrameHeader", "CellPartyFrameHeaderUnitButton1")
    else
        AddFrameCandidate(candidates, seen, frames and frames.raidFrame)
        AddNamedCandidates(candidates, seen, "CellRaidFrame", "CellRaidFrameHeader0", "CellRaidFrameHeader1")
    end
    AddFrameCandidate(candidates, seen, frames and frames.anchorFrame)
    AddFrameCandidate(candidates, seen, frames and frames.mainFrame)
    return true
end

local function AddDandersCandidates(kind, candidates, seen)
    if kind ~= "party" and kind ~= "raid" then return false end
    local active = HasAddOn("DandersFrames", "DandersFrames") or _G.DandersPartyHeader or _G.DandersRaidFrame or _G.DandersRaidGroup1Header
    if not active then return false end
    if kind == "party" then
        AddNamedCandidates(candidates, seen, "DandersPartyHeader", "DandersFrames_Party", "DandersFrames_Player")
        for index = 1, 5 do
            AddFrameCandidateWithParent(candidates, seen, _G["DandersPartyHeaderUnitButton" .. index])
        end
    else
        AddNamedCandidates(candidates, seen, "DandersRaidFrame", "DandersRaidGroup1Header")
        for group = 1, 8 do
            AddFrameCandidate(candidates, seen, _G["DandersRaidGroup" .. group .. "Header"])
            AddFrameCandidateWithParent(candidates, seen, _G["DandersRaidGroup" .. group .. "HeaderUnitButton1"])
        end
    end
    return true
end

local UNIT_PROVIDERS = {
    AddEllesmereUICandidates,
    AddElvUICandidates,
    AddNDuiCandidates,
    AddEQoLCandidates,
}

local GROUP_PROVIDERS = {
    AddCellCandidates,
    AddDandersCandidates,
    AddElvUICandidates,
    AddNDuiCandidates,
    AddEQoLCandidates,
}

-- Group containers normally keep the same frame identity while roster members
-- change. Reusing a still-visible target avoids rebuilding provider candidate
-- tables for every GROUP_ROSTER_UPDATE burst.
local RESOLVED_GROUP_ANCHORS = {}

local function ResolveGroupAnchorTarget(value, kind)
    local cached = RESOLVED_GROUP_ANCHORS[value]
    local left, bottom, width, height = ReadVisibleAnchorFrameGeometry(cached)
    if left ~= nil then return cached, left, bottom, width, height end

    local frame = PickFromProviders(kind, GROUP_PROVIDERS, true)
    RESOLVED_GROUP_ANCHORS[value] = frame
    left, bottom, width, height = ReadVisibleAnchorFrameGeometry(frame)
    return frame, left, bottom, width, height
end

local function ResolveBuiltinAnchorTarget(value)
    value = TrimText(value)
    if value == BUILTIN_PLAYER then
        return PickFromProviders("player", UNIT_PROVIDERS), BUILTIN_PLAYER
    elseif value == BUILTIN_TARGET then
        return PickFromProviders("target", UNIT_PROVIDERS), BUILTIN_TARGET
    elseif value == BUILTIN_PARTY then
        local frame, left, bottom, width, height = ResolveGroupAnchorTarget(value, "party")
        return frame, BUILTIN_PARTY, left, bottom, width, height
    elseif value == BUILTIN_RAID then
        local frame, left, bottom, width, height = ResolveGroupAnchorTarget(value, "raid")
        return frame, BUILTIN_RAID, left, bottom, width, height
    end
    return nil, value
end
P.ResolveBuiltinAnchorTarget = ResolveBuiltinAnchorTarget

local function IsBuiltinAnchorTarget(value)
    return BUILTIN_LABELS[TrimText(value)] ~= nil
end
P.IsBuiltinAnchorTarget = IsBuiltinAnchorTarget

local function NormalizeAnchorTargetAlias(value)
    value = TrimText(value)
    if value == "" then return value end
    if value == L("layout.anchor_target.screen") then return "UIParent" end
    if value == L("layout.anchor_target.main_chat") then return "ChatFrame1" end
    for id, key in pairs(BUILTIN_LABELS) do
        if value == L(key) then return id end
    end
    return value
end
P.NormalizeAnchorTargetAlias = NormalizeAnchorTargetAlias

AnchorTargetDisplayText = function(value)
    value = TrimText(value)
    if value == "" or value == "UIParent" then
        return L("layout.anchor_target.screen")
    end
    if value == "ChatFrame1" then
        return L("layout.anchor_target.main_chat")
    end
    local key = BUILTIN_LABELS[value]
    if key then return L(key) end

    local findEntry = P.FindEntryByFrameName
    if type(findEntry) == "function" then
        local entry = findEntry(value)
        local title = entry and entry.spec and entry.spec.title
        if type(title) == "string" then
            title = TrimText(title)
            if title ~= "" then return title end
        end
    end
    local cachedLabel = Layout.anchorTargetLabels and Layout.anchorTargetLabels[value]
    if type(cachedLabel) == "string" then
        cachedLabel = TrimText(cachedLabel)
        if cachedLabel ~= "" then return cachedLabel end
    end
    return value
end
P.AnchorTargetDisplayText = AnchorTargetDisplayText

local function FormatAnchorTargetOption(value)
    value = NormalizeAnchorTargetAlias(value)
    local text = AnchorTargetDisplayText(value)
    return { text = text, selectionText = text, value = value }
end
P.FormatAnchorTargetOption = FormatAnchorTargetOption

function P.GetBuiltinAnchorTargetValues()
    return BUILTIN_ORDER
end

P.BUILTIN_ANCHOR_TARGETS = {
    PLAYER = BUILTIN_PLAYER,
    TARGET = BUILTIN_TARGET,
    PARTY = BUILTIN_PARTY,
    RAID = BUILTIN_RAID,
}
