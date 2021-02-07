local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local LPP = LibStub:GetLibrary("LibPixelPerfect")

local appearanceTab = Cell:CreateFrame("CellOptionsFrame_AppearanceTab", Cell.frames.optionsFrame, nil, nil, true)
Cell.frames.appearanceTab = appearanceTab
appearanceTab:SetAllPoints(Cell.frames.optionsFrame)
appearanceTab:Hide()

-------------------------------------------------
-- texture
-------------------------------------------------
local textureText = Cell:CreateSeparator(L["Texture"], appearanceTab, 188)
textureText:SetPoint("TOPLEFT", 5, -5)

local textureDropdown = Cell:CreateDropdown(appearanceTab, 150, "texture")
textureDropdown:SetPoint("TOPLEFT", textureText, "BOTTOMLEFT", 5, -12)

local function CheckTextures()
    local items = {}
    local textures, textureNames
    local defaultTexture, defaultTextureName = "Interface\\AddOns\\Cell\\Media\\statusbar.tga", "Cell ".._G.DEFAULT
    
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        textures, textureNames = F:Copy(LSM:HashTable("statusbar")), F:Copy(LSM:List("statusbar"))
        -- insert default texture
        tinsert(textureNames, 1, defaultTextureName)
        textures[defaultTextureName] = defaultTexture

        for _, name in pairs(textureNames) do
            tinsert(items, {
                ["text"] = name,
                ["texture"] = textures[name],
                ["onClick"] = function()
                    CellDB["appearance"]["texture"] = name
                    Cell:Fire("UpdateAppearance", "texture")
                end,
            })
        end
    else
        textureNames = {defaultTextureName}
        textures = {[defaultTextureName] = defaultTexture}

        tinsert(items, {
            ["text"] = defaultTextureName,
            ["texture"] = defaultTexture,
            ["onClick"] = function()
                CellDB["appearance"]["texture"] = defaultTextureName
                Cell:Fire("UpdateAppearance", "texture")
            end,
        })
    end
    textureDropdown:SetItems(items)

    -- validation
    if textures[CellDB["appearance"]["texture"]] then
        textureDropdown:SetSelected(CellDB["appearance"]["texture"], textures[CellDB["appearance"]["texture"]])
    else
        textureDropdown:SetSelected(defaultTextureName, defaultTexture)
    end
end


-------------------------------------------------
-- scale
-------------------------------------------------
local scaleText = Cell:CreateSeparator(L["Scale"], appearanceTab, 188)
scaleText:SetPoint("TOPLEFT", 203, -5)

local scaleDropdown = Cell:CreateDropdown(appearanceTab, 150)
scaleDropdown:SetPoint("TOPLEFT", scaleText, "BOTTOMLEFT", 5, -12)

local scales = {
    [1] = "100% ("..L["Pixel Perfect"]..")",
    [1.5] = "150%",
    [2] = "200% ("..L["Pixel Perfect"]..")",
    [2.5] = "250%",
    [3] = "300%",
    [3.5] = "350%",
    [4] = "400% ("..L["Pixel Perfect"]..")",
}

do
    local indices = {1, 1.5, 2, 2.5, 3, 3.5, 4}
    local items = {}
    for _, value in pairs(indices) do
        table.insert(items, {
            ["text"] = scales[value],
            ["onClick"] = function()
                CellDB["appearance"]["scale"] = value
                Cell:Fire("UpdateAppearance", "scale")
            end,
        })
    end
    scaleDropdown:SetItems(items)
end

-------------------------------------------------
-- font
-------------------------------------------------
local fontText = Cell:CreateSeparator(L["Options UI Font Size"], appearanceTab, 188)
fontText:SetPoint("TOPLEFT", 5, -99)

local optionsFontSizeOffset = Cell:CreateSlider("", appearanceTab, -5, 5, 131, 1, nil, function(value)
    CellDB["appearance"]["optionsFontSizeOffset"] = value
    Cell:UpdateOptionsFont(value)
end)
optionsFontSizeOffset:SetPoint("TOPLEFT", fontText, "BOTTOMLEFT", 5, -12)
-- optionsFontSizeOffset.currentEditBox:Hide()
-- optionsFontSizeOffset.lowText:Hide()
-- optionsFontSizeOffset.highText:Hide()

-------------------------------------------------
-- unitbutton color
-------------------------------------------------
local unitButtonColorText = Cell:CreateSeparator(L["UnitButton Color"], appearanceTab, 387)
unitButtonColorText:SetPoint("TOPLEFT", 5, -195)

-- bar color
local barColorDropdown = Cell:CreateDropdown(appearanceTab, 131)
barColorDropdown:SetPoint("TOPLEFT", unitButtonColorText, "BOTTOMLEFT", 5, -27)
barColorDropdown:SetItems({
    {
        ["text"] = L["Class Color"],
        ["onClick"] = function()
            CellDB["appearance"]["barColor"][1] = "Class Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
    {
        ["text"] = L["Class Color (dark)"],
        ["onClick"] = function()
            CellDB["appearance"]["barColor"][1] = "Class Color (dark)"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
    {
        ["text"] = L["Custom Color"],
        ["onClick"] = function()
            CellDB["appearance"]["barColor"][1] = "Custom Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
})

local barColorText = appearanceTab:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
barColorText:SetPoint("BOTTOMLEFT", barColorDropdown, "TOPLEFT", 0, 1)
barColorText:SetText(L["Bar Color"])

local barColorPicker = Cell:CreateColorPicker(appearanceTab, "", false, function(r, g, b)
    CellDB["appearance"]["barColor"][2][1] = r
    CellDB["appearance"]["barColor"][2][2] = g
    CellDB["appearance"]["barColor"][2][3] = b
    if CellDB["appearance"]["barColor"][1] == "Custom Color" then
        Cell:Fire("UpdateAppearance", "color")
    end
end)
barColorPicker:SetPoint("LEFT", barColorDropdown, "RIGHT", 5, 0)

-- bg color
local bgColorDropdown = Cell:CreateDropdown(appearanceTab, 131)
bgColorDropdown:SetPoint("TOPLEFT", unitButtonColorText, "BOTTOMLEFT", 203, -27)
bgColorDropdown:SetItems({
    {
        ["text"] = L["Class Color"],
        ["onClick"] = function()
            CellDB["appearance"]["bgColor"][1] = "Class Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
    {
        ["text"] = L["Class Color (dark)"],
        ["onClick"] = function()
            CellDB["appearance"]["bgColor"][1] = "Class Color (dark)"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
    {
        ["text"] = L["Custom Color"],
        ["onClick"] = function()
            CellDB["appearance"]["bgColor"][1] = "Custom Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
})

local bgColorText = appearanceTab:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
bgColorText:SetPoint("BOTTOMLEFT", bgColorDropdown, "TOPLEFT", 0, 1)
bgColorText:SetText(L["Background Color"])

local bgColorPicker = Cell:CreateColorPicker(appearanceTab, "", false, function(r, g, b)
    CellDB["appearance"]["bgColor"][2][1] = r
    CellDB["appearance"]["bgColor"][2][2] = g
    CellDB["appearance"]["bgColor"][2][3] = b
    if CellDB["appearance"]["bgColor"][1] == "Custom Color" then
        Cell:Fire("UpdateAppearance", "color")
    end
end)
bgColorPicker:SetPoint("LEFT", bgColorDropdown, "RIGHT", 5, 0)

-- power color
local powerColorDropdown = Cell:CreateDropdown(appearanceTab, 131)
powerColorDropdown:SetPoint("TOPLEFT", barColorDropdown, "BOTTOMLEFT", 0, -30)
powerColorDropdown:SetItems({
    {
        ["text"] = L["Power Color"],
        ["onClick"] = function()
            CellDB["appearance"]["powerColor"][1] = "Power Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
    {
        ["text"] = L["Class Color"],
        ["onClick"] = function()
            CellDB["appearance"]["powerColor"][1] = "Class Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
    {
        ["text"] = L["Custom Color"],
        ["onClick"] = function()
            CellDB["appearance"]["powerColor"][1] = "Custom Color"
            Cell:Fire("UpdateAppearance", "color")
        end,
    },
})

local powerColorText = appearanceTab:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
powerColorText:SetPoint("BOTTOMLEFT", powerColorDropdown, "TOPLEFT", 0, 1)
powerColorText:SetText(L["Power Color"])

local powerColorPicker = Cell:CreateColorPicker(appearanceTab, "", false, function(r, g, b)
    CellDB["appearance"]["powerColor"][2][1] = r
    CellDB["appearance"]["powerColor"][2][2] = g
    CellDB["appearance"]["powerColor"][2][3] = b
    if CellDB["appearance"]["powerColor"][1] == "Custom Color" then
        Cell:Fire("UpdateAppearance", "color")
    end
end)
powerColorPicker:SetPoint("LEFT", powerColorDropdown, "RIGHT", 5, 0)

-- target highlight
local targetColorPicker = Cell:CreateColorPicker(appearanceTab, L["Target Highlight Color"], true, function(r, g, b, a)
    CellDB["appearance"]["targetColor"][1] = r
    CellDB["appearance"]["targetColor"][2] = g
    CellDB["appearance"]["targetColor"][3] = b
    CellDB["appearance"]["targetColor"][4] = a
    Cell:Fire("UpdateAppearance", "highlightColor")
end)
targetColorPicker:SetPoint("TOPLEFT", powerColorDropdown, "BOTTOMLEFT", 0, -20)

-- mouseover highlight
local mouseoverColorPicker = Cell:CreateColorPicker(appearanceTab, L["Mouseover Highlight Color"], true, function(r, g, b, a)
    CellDB["appearance"]["mouseoverColor"][1] = r
    CellDB["appearance"]["mouseoverColor"][2] = g
    CellDB["appearance"]["mouseoverColor"][3] = b
    CellDB["appearance"]["mouseoverColor"][4] = a
    Cell:Fire("UpdateAppearance", "highlightColor")
end)
mouseoverColorPicker:SetPoint("TOPLEFT", targetColorPicker, "BOTTOMLEFT", 0, -10)

-- reset
local resetBtn = Cell:CreateButton(appearanceTab, L["Reset All"], "class-hover", {70, 17})
resetBtn:SetPoint("RIGHT", -5, 0)
resetBtn:SetPoint("BOTTOM", unitButtonColorText)
resetBtn:SetScript("OnClick", function()
    CellDB["appearance"]["barColor"] = {"Class Color", {.2, .2, .2}}
    CellDB["appearance"]["bgColor"] = {"Class Color (dark)", {.667, 0, 0}}
    CellDB["appearance"]["powerColor"] = {"Power Color", {.7, .7, .7}}
    CellDB["appearance"]["targetColor"] = {1, .19, .19, .5}
    CellDB["appearance"]["mouseoverColor"] = {1, 1, 1, .5}

    barColorDropdown:SetSelected(L["Class Color"])
    barColorPicker:SetColor({.2, .2, .2})

    bgColorDropdown:SetSelected(L["Class Color (dark)"])
    bgColorPicker:SetColor({.667, 0, 0})

    powerColorDropdown:SetSelected(L["Power Color"])
    powerColorPicker:SetColor({.7, .7, .7})

    targetColorPicker:SetColor({1, .19, .19, .5})
    mouseoverColorPicker:SetColor({1, 1, 1, .5})

    Cell:Fire("UpdateAppearance", "colors")
end)

-------------------------------------------------
-- functions
-------------------------------------------------
local loaded
local function ShowTab(tab)
    if tab == "appearance" then
        appearanceTab:Show()
        if loaded then return end
        loaded = true

        -- load data
        CheckTextures()
        scaleDropdown:SetSelected(scales[CellDB["appearance"]["scale"]])
        optionsFontSizeOffset:SetValue(CellDB["appearance"]["optionsFontSizeOffset"])

        barColorDropdown:SetSelected(L[CellDB["appearance"]["barColor"][1]])
        barColorPicker:SetColor(CellDB["appearance"]["barColor"][2])

        bgColorDropdown:SetSelected(L[CellDB["appearance"]["bgColor"][1]])
        bgColorPicker:SetColor(CellDB["appearance"]["bgColor"][2])

        powerColorDropdown:SetSelected(L[CellDB["appearance"]["powerColor"][1]])
        powerColorPicker:SetColor(CellDB["appearance"]["powerColor"][2])

        targetColorPicker:SetColor(CellDB["appearance"]["targetColor"])
        mouseoverColorPicker:SetColor(CellDB["appearance"]["mouseoverColor"])
    else
        appearanceTab:Hide()
    end
end
Cell:RegisterCallback("ShowOptionsTab", "AppearanceTab_ShowTab", ShowTab)

-------------------------------------------------
-- update appearance
-------------------------------------------------
local function UpdateAppearance(which)
    F:Debug("|cff7f7fffUpdateAppearance:|r "..(which or "all"))
    
    if not which or which == "texture" or which == "color" or which == "highlightColor" or which == "colors" then
        local tex
        if not which or which == "texture" then tex = F:GetBarTexture() end

        F:IterateAllUnitButtons(function(b)
            -- texture
            if not which or which == "texture" then
                b.func.SetTexture(tex)
            end
            -- color
            if not which or which == "color" or which == "colors" then
                b.func.UpdateColor()
            end
            -- highlightColor
            if not which or which == "highlightColor" or which == "colors" then
                b.func.UpdateHighlightColor()
            end
        end)
    end

    -- scale
    if not which or which == "scale" then
        Cell.frames.mainFrame:SetScale(LPP:GetPixelPerfectScale() * CellDB["appearance"]["scale"])
        Cell.frames.whatsNewFrame:SetScale(LPP:GetPixelPerfectScale() * CellDB["appearance"]["scale"])
        CellTooltip:SetScale(LPP:GetPixelPerfectScale() * CellDB["appearance"]["scale"])
        CellScanningTooltip:SetScale(LPP:GetPixelPerfectScale() * CellDB["appearance"]["scale"])
    end
end
Cell:RegisterCallback("UpdateAppearance", "UpdateAppearance", UpdateAppearance)
