------------------------------------------------------------
-- MiliUI: Ayije_CDM 防禦 / 種族技能按鍵綁定延伸
-- 當 Ayije_CDM 已啟用按鍵綁定功能，且本選項啟用時，
-- 將按鍵綁定文字顯示延伸到「防禦技能」與「種族技能」的冷卻圖示上。
-- 位置 / 字型 / 顏色沿用 Ayije_CDM 自身的 assist 設定。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

MiliUI_DefRacKeybind = MiliUI_DefRacKeybind or {}
local M = MiliUI_DefRacKeybind

local TARGET_VIEWERS = {
    ["CDM_Defensives"] = true,
    ["CDM_Racials"]    = true,
}

-- Weak-keyed so released tracker frames can be garbage collected
local trackedFrames = setmetatable({}, { __mode = "k" })
local initialized = false

local function CDM()
    return _G.Ayije_CDM
end

local function IsFeatureOn()
    if not MiliUI_DB or MiliUI_DB.cdmDefRacKeybind ~= true then return false end
    local cdm = CDM()
    if not cdm or not cdm.Keybinds then return false end
    local KB = cdm.Keybinds
    return KB.IsEnabled and KB:IsEnabled() or false
end

local function GetCfg(key, default)
    local cdm = CDM()
    local GCV = cdm and cdm.CONST and cdm.CONST.GetConfigValue
    if GCV then return GCV(key, default) end
    return default
end

local function GetFontPath()
    local cdm = CDM()
    if cdm and cdm.CONST and cdm.CONST.GetBaseFontPath then
        return cdm.CONST.GetBaseFontPath()
    end
    return STANDARD_TEXT_FONT or "Fonts\\ARIALN.TTF"
end

local function GetOutline()
    local cdm = CDM()
    local raw = GetCfg("textFontOutline", "OUTLINE")
    if cdm and cdm.CONST and cdm.CONST.ResolveOutlineFlags then
        return cdm.CONST.ResolveOutlineFlags(raw)
    end
    return raw or ""
end

local function ScaleFontSize(size)
    local cdm = CDM()
    if cdm and cdm.Pixel and cdm.Pixel.FontSize then
        return cdm.Pixel.FontSize(size)
    end
    return size
end

local function EnsureFS(frame)
    local fs = trackedFrames[frame]
    if fs then return fs end
    local container = CreateFrame("Frame", nil, frame)
    container:SetAllPoints()
    fs = container:CreateFontString(nil, "OVERLAY")
    fs:SetDrawLayer("OVERLAY", 7)
    fs:SetShadowOffset(0, 0)
    fs:SetIgnoreParentScale(true)
    fs._container = container
    trackedFrames[frame] = fs
    return fs
end

local function GetKeybindText(frame)
    local cdm = CDM()
    local KB = cdm and cdm.Keybinds
    if not KB then return nil end

    local spellID = frame.spellID
    if not spellID and cdm.GetBaseSpellID then
        spellID = cdm.GetBaseSpellID(frame)
    end

    local text
    if spellID then
        text = KB:GetKeybindText(spellID)
    end
    if not text and frame.itemID then
        text = KB:GetKeybindTextForItem(frame.itemID)
    end
    return text
end

-- onlyText=true: skip style work, just refresh the displayed keybind text
local function UpdateFrame(frame, onlyText)
    if not frame then return end

    if not IsFeatureOn() then
        local fs = trackedFrames[frame]
        if fs and fs._container then fs._container:Hide() end
        return
    end

    local fs = EnsureFS(frame)

    if not onlyText then
        local pos    = GetCfg("assistPosition", "TOPRIGHT")
        local ox     = GetCfg("assistOffsetX", 0)
        local oy     = GetCfg("assistOffsetY", 0)
        local size   = ScaleFontSize(GetCfg("assistFontSize", 15))
        local color  = GetCfg("assistColor", nil) or { r = 1, g = 1, b = 1 }

        fs:ClearAllPoints()
        fs:SetPoint(pos, frame, pos, ox, oy)
        fs:SetFont(GetFontPath(), size, GetOutline())
        fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1)

        if fs._container then
            fs._container:SetFrameLevel(frame:GetFrameLevel() + 7)
            fs._container:Show()
        end
    end

    local text = GetKeybindText(frame)
    if text and text ~= "" then
        fs:SetText(text)
        fs:Show()
    else
        fs:SetText("")
        fs:Hide()
    end
end

local function UpdateAllTracked(onlyText)
    for frame in pairs(trackedFrames) do
        UpdateFrame(frame, onlyText)
    end
end

-- Scan container children once when the feature is toggled on, so existing
-- frames get their FontStrings created even without a style pass.
local function ScanContainer(containerName)
    local c = _G[containerName]
    if not c or not c.GetChildren then return end
    local children = { c:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and (child.spellID or child.itemID) then
            UpdateFrame(child, false)
        end
    end
end

function M.SetEnabled(enabled)
    if not MiliUI_DB then MiliUI_DB = {} end
    MiliUI_DB.cdmDefRacKeybind = enabled and true or false
    if enabled then
        ScanContainer("CDM_DefensivesContainer")
        ScanContainer("CDM_RacialsContainer")
    end
    UpdateAllTracked(false)
end

function M.IsEnabled()
    return MiliUI_DB and MiliUI_DB.cdmDefRacKeybind == true or false
end

local function Initialize()
    if initialized then return end
    local cdm = CDM()
    if not cdm or not cdm.ApplyStyle then return end
    initialized = true

    hooksecurefunc(cdm, "ApplyStyle", function(_, frame, vName)
        if not TARGET_VIEWERS[vName] then return end
        UpdateFrame(frame, false)
    end)

    if cdm.RefreshViewerKeybindText then
        hooksecurefunc(cdm, "RefreshViewerKeybindText", function()
            UpdateAllTracked(true)
        end)
    end

    -- Run after the "assist" refresh callback (priority 36) so we see the
    -- up-to-date Keybinds enabled state when CDM toggles it.
    if cdm.RegisterRefreshCallback then
        cdm:RegisterRefreshCallback("MiliUI_DefRacKeybind", function()
            UpdateAllTracked(false)
        end, 40, { "STYLE" })
    end

    if MiliUI_DB and MiliUI_DB.cdmDefRacKeybind == true then
        ScanContainer("CDM_DefensivesContainer")
        ScanContainer("CDM_RacialsContainer")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.cdmDefRacKeybind == nil then
        MiliUI_DB.cdmDefRacKeybind = true
    end
    C_Timer.After(0.5, Initialize)
end)
