local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST
local VIEWERS = CDM_C.VIEWERS
local GetBaseSpellID = CDM.GetBaseSpellID
local Keybinds = CDM.Keybinds
local GetFrameData = CDM.GetFrameData

local ipairs = ipairs
local pairs = pairs
local next = next
local IsShiftKeyDown = IsShiftKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsAltKeyDown = IsAltKeyDown
local IsKeyDown = IsKeyDown
local GetCurrentKeyBoardFocus = GetCurrentKeyBoardFocus


local isEnabled = false
local isReanchorHooked = false

local overlayFrames = setmetatable({}, { __mode = "k" })

local bindingMap = {}
local itemBindingMap = {}
local bindingMapCacheVer = -1
local bindingMapHasNoModifierCombo = false

local showTint = false
local showHighlight = false
local showBorder = false
local tintColor = { r = 1, g = 1, b = 1, a = 0.35 }
local borderColor = { r = 1, g = 1, b = 1, a = 1 }

local useTextureSwap = false
local emptyBorderEdgeFile = nil

local POLL_INTERVAL = 0.05
local elapsed = 0

local VIEWER_NAMES = CDM_C.COOLDOWN_VIEWER_NAMES

local function ParseRawKey(rawKey)
    if not rawKey or rawKey == "" then return nil end
    local shift, ctrl, alt = false, false, false
    local remaining = rawKey
    while true do
        if remaining:sub(1, 6) == "SHIFT-" then
            shift = true
            remaining = remaining:sub(7)
        elseif remaining:sub(1, 5) == "CTRL-" then
            ctrl = true
            remaining = remaining:sub(6)
        elseif remaining:sub(1, 4) == "ALT-" then
            alt = true
            remaining = remaining:sub(5)
        else
            break
        end
    end
    if remaining == "" then return nil end
    return { key = remaining, shift = shift, ctrl = ctrl, alt = alt }
end

local function IsComboDown(combo)
    if combo.shift ~= IsShiftKeyDown() then return false end
    if combo.ctrl ~= IsControlKeyDown() then return false end
    if combo.alt ~= IsAltKeyDown() then return false end
    return IsKeyDown(combo.key)
end

local function RebuildBindingMapIfStale()
    local ver = Keybinds:GetCacheVersion()
    if ver == bindingMapCacheVer then return end
    bindingMapCacheVer = ver
    wipe(bindingMap)
    wipe(itemBindingMap)
    bindingMapHasNoModifierCombo = false

    for _, vName in ipairs(VIEWER_NAMES) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local baseID = GetBaseSpellID(frame)
                if baseID then
                    if not bindingMap[baseID] then
                        local rawKeys = Keybinds:GetRawKeysForSpell(baseID)
                        if rawKeys then
                            local combos
                            for _, rk in ipairs(rawKeys) do
                                local combo = ParseRawKey(rk)
                                if combo then
                                    if not combos then combos = {} end
                                    combos[#combos + 1] = combo
                                    if not (combo.shift or combo.ctrl or combo.alt) then
                                        bindingMapHasNoModifierCombo = true
                                    end
                                end
                            end
                            if combos then
                                bindingMap[baseID] = combos
                            end
                        end
                    end
                end
            end
        end
    end

    local trinketFrames = CDM.GetTrinketIconFrames and CDM.GetTrinketIconFrames()
    if trinketFrames then
        for _, frame in ipairs(trinketFrames) do
            local itemID = frame.itemID
            if itemID and not itemBindingMap[itemID] then
                local rawKey = Keybinds:GetRawKeyForItem(itemID)
                if rawKey then
                    local combo = ParseRawKey(rawKey)
                    if combo then
                        itemBindingMap[itemID] = { combo }
                        if not (combo.shift or combo.ctrl or combo.alt) then
                            bindingMapHasNoModifierCombo = true
                        end
                    end
                end
            end
        end
    end
end

local function GetOrCreateOverlay(frame)
    local ov = overlayFrames[frame]
    if ov then return ov end
    ov = {}
    overlayFrames[frame] = ov
    return ov
end

local function GetOrCreateTint(frame)
    local ov = GetOrCreateOverlay(frame)
    if ov.tint then return ov.tint end
    local f = CreateFrame("Frame", nil, frame)
    f:SetAllPoints()
    f:SetFrameLevel(frame:GetFrameLevel() + 1)
    local tex = CDM.Pixel.CreateSolidTexture(f, "OVERLAY")
    tex:SetAllPoints()
    f.texture = tex
    f:Hide()
    ov.tint = f
    return f
end

local function GetOrCreateHighlight(frame)
    local ov = GetOrCreateOverlay(frame)
    if ov.highlight then return ov.highlight end
    local f = CreateFrame("Frame", nil, frame)
    f:SetAllPoints()
    f:SetFrameLevel(frame:GetFrameLevel() + 1)
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas("UI-HUD-ActionBar-IconFrame-Down")
    f.texture = tex
    f:Hide()
    ov.highlight = f
    return f
end

local function OverrideBorderColor(frame)
    local frameData = GetFrameData(frame)
    if not frameData then return end

    local border = frameData.borderFrame and frameData.borderFrame.border
    if border and border.SetBackdropBorderColor then
        if useTextureSwap then
            local ov = GetOrCreateOverlay(frame)
            if not ov.textureSwapped then
                local bd = border:GetBackdrop()
                if bd then
                    ov.origBackdrop = bd
                    local altBd = CopyTable(bd)
                    altBd.edgeFile = emptyBorderEdgeFile
                    border:SetBackdrop(altBd)
                end
                ov.textureSwapped = true
            end
        end
        border:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
    end
end

local function RestoreBorderColor(frame)
    local frameData = GetFrameData(frame)
    if not frameData then return end

    local border = frameData.borderFrame and frameData.borderFrame.border
    if border and border.SetBackdropBorderColor then
        local ov = overlayFrames[frame]
        if ov and ov.textureSwapped then
            if ov.origBackdrop then
                border:SetBackdrop(ov.origBackdrop)
            end
            ov.textureSwapped = false
            ov.origBackdrop = nil
        end
        local c = border.backdropBorderColor
        if c then
            border:SetBackdropBorderColor(c.r, c.g, c.b, border.backdropBorderColorAlpha or 1)
        end
    end
end

local function ShowOverlays(frame)
    local ov = GetOrCreateOverlay(frame)
    if showBorder then
        ov.borderActive = true
    end
    if showTint then
        local tf = GetOrCreateTint(frame)
        tf:SetFrameLevel(frame:GetFrameLevel() + 1)
        tf.texture:SetColorTexture(tintColor.r, tintColor.g, tintColor.b, tintColor.a)
        tf:Show()
    end
    if showHighlight then
        local hf = GetOrCreateHighlight(frame)
        hf:SetFrameLevel(frame:GetFrameLevel() + 1)
        hf.texture:ClearAllPoints()
        hf.texture:SetPoint("TOPLEFT", frame, "TOPLEFT")
        hf.texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
        hf:Show()
    end
    if showBorder then
        OverrideBorderColor(frame)
    end
end

local function HideOverlays(frame)
    local ov = overlayFrames[frame]
    if not ov then return end
    if ov.tint then ov.tint:Hide() end
    if ov.highlight then ov.highlight:Hide() end
    if ov.borderActive then
        ov.borderActive = false
        RestoreBorderColor(frame)
    end
end

local function HideAllOverlays()
    for frame in pairs(overlayFrames) do
        HideOverlays(frame)
    end
end

local function IsAnyComboDown(combos)
    for _, combo in ipairs(combos) do
        if IsComboDown(combo) then return true end
    end
    return false
end

local pollFrame = CreateFrame("Frame")
pollFrame:Hide()

pollFrame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < POLL_INTERVAL then return end
    elapsed = 0

    if GetCurrentKeyBoardFocus() then
        HideAllOverlays()
        return
    end

    RebuildBindingMapIfStale()

    local hasBindings = next(bindingMap) or next(itemBindingMap)
    if not hasBindings then
        HideAllOverlays()
        return
    end

    if not bindingMapHasNoModifierCombo
        and not IsShiftKeyDown()
        and not IsControlKeyDown()
        and not IsAltKeyDown() then
        HideAllOverlays()
        return
    end

    for _, vName in ipairs(VIEWER_NAMES) do
        local viewer = _G[vName]
        if viewer and viewer.itemFramePool then
            for frame in viewer.itemFramePool:EnumerateActive() do
                local pressed = false
                local baseID = GetBaseSpellID(frame)
                if baseID then
                    local combos = bindingMap[baseID]
                    if combos then
                        pressed = IsAnyComboDown(combos)
                    end
                end
                if pressed then
                    ShowOverlays(frame)
                else
                    HideOverlays(frame)
                end
            end
        end
    end

    local trinketFrames = CDM.GetTrinketIconFrames and CDM.GetTrinketIconFrames()
    if trinketFrames then
        for _, frame in ipairs(trinketFrames) do
            local pressed = false
            local itemID = frame.itemID
            local combos = itemID and itemBindingMap[itemID]
            if combos then
                pressed = IsAnyComboDown(combos)
            end
            if not pressed then
                local baseID = GetBaseSpellID(frame)
                if baseID then
                    combos = bindingMap[baseID]
                    if combos then
                        pressed = IsAnyComboDown(combos)
                    end
                end
            end
            if pressed then
                ShowOverlays(frame)
            else
                HideOverlays(frame)
            end
        end
    end
end)

local function InstallHooks()
    if isReanchorHooked then return end
    isReanchorHooked = true
    hooksecurefunc(CDM, "ForceReanchor", function(_, viewer)
        if not isEnabled then return end
        local name = viewer and viewer.GetName and viewer:GetName()
        if name == VIEWERS.ESSENTIAL or name == VIEWERS.UTILITY then
            bindingMapCacheVer = -1
        end
    end)
end

local function Enable()
    if isEnabled then return end
    isEnabled = true
    InstallHooks()
    bindingMapCacheVer = -1
    elapsed = 0
    pollFrame:Show()
end

local function Disable()
    if not isEnabled then return end
    isEnabled = false
    pollFrame:Hide()
    HideAllOverlays()
    wipe(bindingMap)
    wipe(itemBindingMap)
end

CDM.PressOverlay = CDM.PressOverlay or {}

function CDM.PressOverlay:Initialize()
    CDM:RegisterRefreshCallback("pressOverlay", function()
        local db = CDM.db
        local wantEnabled = db and db.pressOverlayEnabled
        showTint = db and db.pressOverlayTint or false
        showHighlight = db and db.pressOverlayHighlight or false
        showBorder = db and db.pressOverlayBorder or false
        local tc = db and db.pressOverlayTintColor
        if tc then
            tintColor.r = tc.r or 1
            tintColor.g = tc.g or 1
            tintColor.b = tc.b or 1
            tintColor.a = tc.a or 0.35
        end
        local bc = db and db.pressOverlayBorderColor
        if bc then
            borderColor.r = bc.r or 1
            borderColor.g = bc.g or 1
            borderColor.b = bc.b or 1
            borderColor.a = bc.a or 1
        end
        useTextureSwap = false
        if showBorder and db then
            local borderKey = db.borderFile
            if borderKey == "Ayije_Thin" then
                local LSM = LibStub("LibSharedMedia-3.0", true)
                local path = LSM and LSM:Fetch("border", "Ayije_Empty")
                if path then
                    useTextureSwap = true
                    emptyBorderEdgeFile = path
                end
            end
        end
        if wantEnabled and not isEnabled then
            Enable()
        elseif not wantEnabled and isEnabled then
            Disable()
        end
    end, 57, { "STYLE", "TRACKERS" })
end
