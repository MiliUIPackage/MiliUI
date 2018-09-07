local _, Engine = ...

local L = Engine.Locales
local D = Engine.Definitions
local G = Engine.Globals

D.Helpers = {}

----------------------------------------------------------------------------------------
function D.Helpers:NewPluginDefinition(pluginName, definition, shortDescription, longDescription)
    if Engine.Definitions[pluginName] then return false end
    --print("ADD PLUGIN DEFINITION:"..tostring(pluginName).."  "..tostring(shortDescription))
    Engine.Definitions[pluginName] = definition
    Engine.Descriptions[pluginName] = { short = shortDescription, long = longDescription }
    --print(tostring(Engine.Descriptions[pluginName].short).."  "..tostring(Engine.Descriptions[pluginName].long))
    --Engine.Descriptions[pluginName]short = shortDescription
    --Engine.Descriptions[pluginName]long = longDescription
end

----------------------------------------------------------------------------------------
D.Helpers.SaveValueUsingInfo = function(section, info, value)
    --print("SAVEINFO:"..tostring(info.arg.key).."  "..tostring(section.name).."  "..tostring(G.SavedPerChar.Plugins).."  "..tostring(G.SavedPerChar.Plugins[section.name]).."  "..tostring(info[#info]))
    -- for k, v in pairs(G.SavedPerChar.Plugins) do
    -- print(tostring(k).."=>"..tostring(v))
    -- end
    G.SavedPerChar.Plugins[section.name] = G.SavedPerChar.Plugins[section.name] or {}
    G.SavedPerChar.Plugins[section.name][info[#info]] = value

    local updated = G.PluginUpdateFunction and G:PluginUpdateFunction(section.kind, section.name) or false

    if not updated then
        -- something modified, -> /reloadui
        G.ConfigModified = true
    end
end

D.Helpers.GetValueUsingInfo = function(info)
    local value = info.arg.section[info[#info]]
    --print("GETINFO "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(info[#info]).." : "..tostring(value))
    return value
end

D.Helpers.SetValueUsingInfo = function(info, value)
    --print("SETINFO "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(value).."  "..tostring(info[#info]))
    info.arg.section[info[#info]] = value
    D.Helpers.SaveValueUsingInfo(info.arg.section, info, info.arg.section[info[#info]])
end

D.Helpers.SaveValue = function(section, info, value)
    --print("SAVE:"..tostring(info.arg.key).."  "..tostring(section.name).."  "..tostring(G.SavedPerChar.Plugins).."  "..tostring(G.SavedPerChar.Plugins[section.name]))
    -- for k, v in pairs(G.SavedPerChar.Plugins) do
    -- print(tostring(k).."=>"..tostring(v))
    -- end
    G.SavedPerChar.Plugins[section.name] = G.SavedPerChar.Plugins[section.name] or {}
    G.SavedPerChar.Plugins[section.name][info.arg.key] = value

    local updated = G.PluginUpdateFunction and G:PluginUpdateFunction(section.kind, section.name) or false

    if not updated then
        -- something modified, -> /reloadui
        G.ConfigModified = true
    end
end

D.Helpers.GetValue = function(info)
    local value = info.arg.section[info.arg.key]
    --print("GET "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(info.arg.section[info.arg.key]).." : "..tostring(value))
    return value
end

D.Helpers.SetValue = function(info, value)
    --print("SET "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(value))
    info.arg.section[info.arg.key] = value
    D.Helpers.SaveValue(info.arg.section, info, info.arg.section[info.arg.key])
end

D.Helpers.GetNumberValue = function(info)
    return tostring(info.arg.section[info.arg.key] or "")
end

D.Helpers.SetNumberValue = function(info, value)
    info.arg.section[info.arg.key] = tonumber(value)
    D.Helpers.SaveValue(info.arg.section, info, info.arg.section[info.arg.key])
end

D.Helpers.GetMultiValue = function(info, key)
    --print("GET MULTIVALUE "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(key).."  "..tostring(info.arg.section[info.arg.key]))
    if info.arg.section[info.arg.key] then
        for k, v in pairs(info.arg.section[info.arg.key]) do
            if tostring(v) == key then
                return true
            end
        end
    end
    return false
end

D.Helpers.SetMultiValue = function(info, key, value)
    --print("SET MULTIVALUE "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(value))
    info.arg.section[info.arg.key] = info.arg.section[info.arg.key] or {}
    local found = 0
    for k, v in pairs(info.arg.section[info.arg.key]) do
        if tostring(v) == key then
            found = k
            break
        end
    end
    if value == true and found == 0 then
        tinsert(info.arg.section[info.arg.key], key)
    elseif value == false and found ~= 0 then
        tremove(info.arg.section[info.arg.key], found)
    end
    D.Helpers.SaveValue(info.arg.section, info, info.arg.section[info.arg.key])
end

----------------------------------------------------------------------------------------
D.Helpers.IsPluginDisabled = function(info)
    --print("IsDisabled:"..tostring(info.arg.key).."  "..tostring(not info.arg.section.enabled))
    return not info.arg.section.enabled
end

----------------------------------------------------------------------------------------
D.Helpers.ValidateNumber = function(info, value)
    local asNumber = tonumber(value)
    --print("ValidateNumber:"..tostring(asNumber).."  "..type(value).."  "..type(asNumber))
    if asNumber and type(asNumber) == "number" then
        return true
    else
        return L.MustBeANumber
    end
end

----------------------------------------------------------------------------------------
D.Helpers.Name = {
    key = "name",
    name = L.Name,
    desc = L.NameDesc,
    type = "input",
    get = D.Helpers.GetValue,
    disabled = true,
    hidden = D.Globals.IsInReleaseMode,
}

local function ValidateDisplayName(info, value)
    for _, setting in pairs(G.Config) do
        if setting.displayName == value and setting.__deleted ~= true then
            return string.format(L.PluginNameAlreadyExists, value)
        end
    end
    return true
end

D.Helpers.DisplayName = {
    key = "displayName",
    name = L.DisplayName,
    desc = L.DisplayNameDesc,
    type = "input",
    get = D.Helpers.GetValue,
    set = D.Helpers.SetValue,
    validate = ValidateDisplayName,
    disabled = D.Helpers.IsPluginDisabled
}

local kindValues = nil
local function GetKindValues()
    if not kindValues then
        kindValues = {}
        if G.GetPluginListFunction and type(G.GetPluginListFunction) == "function" then
            local pluginList = G:GetPluginListFunction()
            for kind in pairs(pluginList) do
--                print("KIND:" .. tostring(kind))
--                print("short: " .. tostring(Engine.Descriptions[kind]["short"]) .. " long: " .. tostring(Engine.Descriptions[kind]["long"]))
                kindValues[kind] = Engine.Descriptions[kind].short or kind
            end
        end
    end
    return kindValues
end

D.Helpers.Kind = {
    key = "kind",
    name = L.Kind,
    desc = L.KindDesc,
    type = "select",
    get = D.Helpers.GetValue,
    values = GetKindValues,
    disabled = true,
}

local function SetEnabled(info, value)
    D.Helpers.SetValue(info, value)
    if G.SavedPerChar.Global.autogridanchor == true then
        if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
            G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing, "anchor", "width", "height")
        end
    end
end

D.Helpers.Enabled = {
    key = "enabled",
    name = L.Enabled,
    desc = L.EnabledDesc,
    type = "toggle",
    get = D.Helpers.GetValue,
    --set = D.Helpers.SetValue,
    set = SetEnabled
}

D.Helpers.Autohide = {
    key = "autohide",
    name = L.Autohide,
    desc = L.AutohideDesc,
    type = "toggle",
    get = D.Helpers.GetValue,
    set = D.Helpers.SetValue,
    disabled = D.Helpers.IsPluginDisabled
}

D.Helpers.WidthAndHeight = {
    key = "size",
    name = L.Size,
    desc = L.SizeDesc,
    type = "group",
    guiInline = true,
    disabled = D.Helpers.IsPluginDisabled,
    hidden = D.Globals.IsNormalAnchorDisabled, -- shown only when anchor is shown
    args = {
        width = {
            order = 1,
            name = L.Width,
            desc = L.WidthDesc,
            type = "range",
            min = 80,
            max = 300,
            step = 1,
            get = D.Helpers.GetValueUsingInfo,
            set = D.Helpers.SetValueUsingInfo,
        },
        height = {
            order = 2,
            name = L.Height,
            desc = L.HeightDesc,
            type = "range",
            min = 10,
            max = 50,
            step = 1,
            get = D.Helpers.GetValueUsingInfo,
            set = D.Helpers.SetValueUsingInfo,
        }
    }
}

local filterValues = {
    ["HELPFUL"] = L.FilterValueHelpful,
    ["HARMFUL"] = L.FilterValueHarmful,
}
local function GetFilterValues()
    return filterValues
end

D.Helpers.Filter = {
    key = "filter",
    name = L.Filter,
    desc = L.FilterDesc,
    type = "select",
    get = D.Helpers.GetValue,
    set = D.Helpers.SetValue,
    values = GetFilterValues,
    disabled = D.Helpers.IsPluginDisabled
}

local unitValues = {
    ["player"] = L.UnitValuePlayer,
    ["target"] = L.UnitValueTarget,
    ["focus"] = L.UnitValueFocus,
    ["pet"] = L.UnitValuePet,
}
local function GetUnitValues()
    return unitValues
end

D.Helpers.Unit = {
    key = "unit",
    name = L.Unit,
    desc = L.UnitDesc,
    type = "select",
    values = GetUnitValues,
    get = D.Helpers.GetValue,
    set = D.Helpers.SetValue,
    disabled = D.Helpers.IsPluginDisabled
}

local function GetPluginDescription(info)
    -- print(unpack(Engine))
    return info.arg.section.kind ~= "" and (Engine.Descriptions[info.arg.section.kind].long or L.NoPluginDescription) or ""
end

D.Helpers.Description = {
    key = "description",
    name = GetPluginDescription,
    type = "description",
}

----------------------------------------------------------------------------------------
local function GetSpecsValue(info, key)
    --print("GET SPECSVALUE "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(key).."  "..tostring(info.arg.section[info.arg.key]))
    if info.arg.section[info.arg.key] then
        for k, v in pairs(info.arg.section[info.arg.key]) do
            if tostring(v) == key then
                return true
            end
        end
    end
    return false
end

local function SetSpecsValue(info, key, value)
    --print("SET SPECSVALUE "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(value))
    info.arg.section[info.arg.key] = info.arg.section[info.arg.key] or {}
    if key == "any" and value == true then
        -- replace value by "any"
        info.arg.section[info.arg.key] = { key }
    else
        -- remove "any"
        for k, v in pairs(info.arg.section[info.arg.key]) do
            if tostring(v) == "any" then
                tremove(info.arg.section[info.arg.key], k)
                break
            end
        end
        -- check if key already in array
        local found = 0
        for k, v in pairs(info.arg.section[info.arg.key]) do
            if tostring(v) == key then
                found = k
                break
            end
        end
        if value == true and found == 0 then
            tinsert(info.arg.section[info.arg.key], key) -- add key
        elseif value == false and found ~= 0 then
            tremove(info.arg.section[info.arg.key], found) -- remove key
        end
    end
    D.Helpers.SaveValue(info.arg.section, info, info.arg.section[info.arg.key])
end

local function GetSpecsValues()
    local specs = {}
    specs["any"] = "Any"
    local num = GetNumSpecializations()
    for i = 1, num do
        local _, specName = GetSpecializationInfo(i)
        specs[tostring(i)] = specName -- TODO: why the hell, am I forced to used a string as key
    end
    return specs
end

D.Helpers.Specs = {
    key = "specs",
    name = L.Specs,
    desc = L.SpecsDesc,
    type = "multiselect",
    get = GetSpecsValue,
    set = SetSpecsValue,
    values = GetSpecsValues,
    disabled = D.Helpers.IsPluginDisabled
}

-------------------------------
-- Spell ID
local function GetSpellName(info)
    local spellID = tonumber(D.Helpers.GetValue(info) or 0)
    local spellName = GetSpellInfo(spellID)
    return spellName or "Invalid"
end

local function GetSpellIcon(info)
    local spellID = tonumber(D.Helpers.GetValue(info) or 0)
    local _, _, icon = GetSpellInfo(spellID)
    return icon or "INTERFACE/ICONS/INV_MISC_QUESTIONMARK"
end

local function ValidateSpellID(info, value)
    local asNumber = tonumber(value)
    if asNumber and type(asNumber) == "number" then
        local spellName = GetSpellInfo(asNumber)
        if not spellName then
            return L.InvalidSpellID
        else
            return true
        end
    else
        return L.MustBeANumber
    end
end

local function ValidateSpellName(info, value)
    local spellName = GetSpellInfo(value)
    --print("ValidateSpellName:"..tostring(value).."  "..tostring(spellName))
    if not spellName then
        return L.InvalidSpellName
    else
        return true
    end
end

D.Helpers.Spell = {
    key = "spellID",
    name = L.Spell,
    desc = L.SpellDesc,
    type = "group",
    guiInline = true,
    args = {
        spellID = {
            order = 1,
            name = L.SpellSpellID,
            desc = L.SpellSpellIDDesc,
            type = "input",
            validate = ValidateSpellID,
            --get = GetSpellIDAndSetSpellIcon,
            get = D.Helpers.GetNumberValue,
            set = D.Helpers.SetNumberValue, --D.Helpers.SetValue,
        },
        spellIcon = {
            order = 2,
            name = GetSpellName, --"Invalid",
            type = "description",
            --image = "INTERFACE/ICONS/INV_MISC_QUESTIONMARK",
            image = GetSpellIcon,
        },
    },
    disabled = D.Helpers.IsPluginDisabled
}

-----------------------------
-- Auto Grid Anchor
local function SetAutoGridValue(info, value)
    D.Helpers.SetValueUsingInfo(info, value)
    if G.SavedPerChar.Global.autogridanchor == true then
        if G.AutoGridAnchorFunction and type(G.AutoGridAnchorFunction) == "function" then
            G:AutoGridAnchorFunction(G.Config, G.SavedPerChar.Global.width, G.SavedPerChar.Global.height, G.SavedPerChar.Global.autogridanchorspacing, "anchor", "width", "height")
        end
    end
end

D.Helpers.AutoGridAnchor = {
    key = "autogridAnchor",
    name = L.AutoGridAnchor,
    desc = L.AutoGridAnchorDesc,
    type = "group",
    guiInline = true,
    hidden = D.Globals.IsAutoAnchorDisabled,
    disabled = D.Helpers.IsPluginDisabled,
    args = {
        verticalIndex = {
            order = 1,
            name = L.AutoGridAnchorVerticalIndex,
            desc = L.AutoGridAnchorVerticalIndexDesc,
            type = "range",
            min = -20,
            max = 20,
            step = 1,
            get = D.Helpers.GetValueUsingInfo,
            set = SetAutoGridValue,
        },
        horizontalIndex = {
            order = 2,
            name = L.AutoGridAnchorHorizontalIndex,
            desc = L.AutoGridAnchorHorizontalIndexDesc,
            type = "range",
            min = 0,
            max = 9,
            step = 1,
            get = D.Helpers.GetValueUsingInfo,
            set = SetAutoGridValue,
        }
    }
}
-- D.Helpers.AutoGridVerticalIndex = {
-- key = "verticalIndex",
-- name = L.AutoGridAnchorVerticalIndex,
-- desc = L.AutoGridAnchorVerticalIndexDesc,
-- type = "range",
-- min = -20, max = 20, step = 1,
-- get = D.Helpers.GetValue,
-- set = SetAutoGridValue,
-- disabled = D.Helpers.IsPluginDisabled,
-- hidden = D.Globals.IsAutoAnchorDisabled
-- }
-- D.Helpers.AutoGridHorizontalIndex = {
-- key = "horizontalIndex",
-- name = L.AutoGridAnchorHorizontalIndex,
-- desc = L.AutoGridAnchorHorizontalIndexDesc,
-- type = "range",
-- min = 0, max = 9, step = 1,
-- get = D.Helpers.GetValue,
-- set = SetAutoGridValue,
-- disabled = D.Helpers.IsPluginDisabled,
-- hidden = D.Globals.IsAutoAnchorDisabled
-- }

-----------------------------
-- Anchor
local function GetAnchor(info)
    -- point, relativeFrame, relativePoint, offsetX, offsetY
    --anchor = { "CENTER", UIParent, "CENTER", 0, -140 },
    local option = info[#info]
    if option == "point" then
        value = info.arg.section[info.arg.key][1]
    elseif option == "relativeFrame" then
        value = tostring(info.arg.section[info.arg.key][2])
    elseif option == "relativePoint" then
        value = info.arg.section[info.arg.key][3]
    elseif option == "offsetX" then
        value = info.arg.section[info.arg.key][4]
    elseif option == "offsetY" then
        value = info.arg.section[info.arg.key][5]
    end
    --print("GetAnchor "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(info[#info]).."  "..tostring(value))
    return value
end

local function SetAnchor(info, value)
    local section = info.arg.section
    --print("SetAnchor "..tostring(info.type)..":"..tostring(info.arg.key).."  "..tostring(info.arg.section[info.arg.key]).."  "..tostring(value).."  "..tostring(info[#info]))
    local option = info[#info]
    if option == "point" then
        section[info.arg.key][1] = tostring(value)
    elseif option == "relativeFrame" then
        section[info.arg.key][2] = tostring(value)
    elseif option == "relativePoint" then
        section[info.arg.key][3] = tostring(value)
    elseif option == "offsetX" then
        section[info.arg.key][4] = value
    elseif option == "offsetY" then
        section[info.arg.key][5] = value
    end
    -- save
    G.SavedPerChar.Plugins[section.name] = G.SavedPerChar.Plugins[section.name] or {}
    G.SavedPerChar.Plugins[section.name][info.arg.key] = Engine.DeepCopy(section[info.arg.key])

    local updated = G.PluginUpdateFunction and G:PluginUpdateFunction(section.kind, section.name) or false

    if not updated then
        -- something modified, -> /reloadui
        G.ConfigModified = true
    end
end

--local frameListValues = nil
local function GetFrameListValues(info)
    local values = {}
    values["UIParent"] = "UIParent" -- Add main frame
    for _, section in pairs(G.Config) do
        if section.name ~= info.arg.section.name then -- can't anchor a frame to itself
            values[section.name] = section.displayName or section.name
        end
    end
    return values
end

local positionValues = {
    ["TOPLEFT"] = "TOPLEFT",
    ["LEFT"] = "LEFT",
    ["BOTTOMLEFT"] = "BOTTOMLEFT",
    ["RIGHT"] = "RIGHT",
    ["TOPRIGHT"] = "TOPRIGHT",
    ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
    ["CENTER"] = "CENTER",
    ["TOP"] = "TOP",
    ["BOTTOM"] = "BOTTOM",
}
local function GetPositionsValues()
    return positionValues
end

D.Helpers.Anchor = {
    key = "anchor",
    name = L.Anchor,
    desc = L.AnchorDesc,
    type = "group",
    guiInline = true,
    get = GetAnchor,
    set = SetAnchor,
    args = {
        point = {
            order = 1,
            name = L.AnchorPoint,
            desc = L.AnchorPointDesc,
            type = "select",
            values = GetPositionsValues,
        },
        relativeFrame = {
            order = 2,
            name = L.AnchorRelativeFrame,
            desc = L.AnchorRelativeFrameDesc,
            type = "select",
            values = GetFrameListValues,
        },
        relativePoint = {
            order = 3,
            name = L.AnchorRelativePoint,
            desc = L.AnchorRelativePointDesc,
            type = "select",
            values = positionValues,
        },
        offsetX = {
            order = 4,
            name = L.AnchorOffsetX,
            desc = L.AnchorOffsetXDesc,
            type = "range",
            min = -400,
            max = 400,
            step = 1,
        },
        offsetY = {
            order = 5,
            name = L.AnchorOffsetY,
            desc = L.AnchorOffsetYDesc,
            type = "range",
            min = -400,
            max = 400,
            step = 1,
        },
    },
    disabled = D.Helpers.IsPluginDisabled,
    hidden = D.Globals.IsNormalAnchorDisabled
}

-----------------------------
-- Colors

D.Helpers.IsCustomColor = function(info)
    --print("IsDisabled:"..tostring(info.arg.key).."  "..tostring(not info.arg.section.enabled))
    return not info.arg.section.customcolor
end

-- Only one color
local function GetColor(info)
    local color = D.Helpers.GetValueUsingInfo(info)
    --    local color = info.arg.section[info[#info]]
    local extend_color = { color[1], color[2], color[3], color[4], 0.1, 1, 0.1 }
    --    return unpack(extend_color)
    --    return unpack(color)
    return color[1], color[2], color[3], color[4]
end

local function SetColor(info, r, g, b)
    local color = { r, g, b }
    --    D.Helpers.SetValue(info, color)
    D.Helpers.SetValueUsingInfo(info, color)
end

-- Array of color
local function GetColors(info)
    local value = D.Helpers.GetValue(info)
    local index = tonumber(info[#info])
    local color = value[index] and value[index] or value[#value]
    --    print("GetColors:" .. tostring(value) .. "  " .. tostring(index) .. "  " .. tostring(color[1]) .. "  " .. tostring(color[2]) .. "  " .. tostring(color[3]))
    return unpack(color)
end

local function SetColors(info, r, g, b)
    local index = tonumber(info[#info])
    --print("SetColors:"..tostring(index).."  "..tostring(r).."  "..tostring(g).."  "..tostring(b))
    local section = info.arg.section
    section[info.arg.key][index] = { r, g, b }
    G.SavedPerChar.Plugins[section.name] = G.SavedPerChar.Plugins[section.name] or {}
    G.SavedPerChar.Plugins[section.name][info.arg.key] = Engine.DeepCopy(section[info.arg.key])

    local updated = G.PluginUpdateFunction and G:PluginUpdateFunction(section.kind, section.name) or false

    if not updated then
        -- something modified, -> /reloadui
        G.ConfigModified = true
    end
end

D.Helpers.CreateColorsDefinition = function(key, count, names)
    --print(tostring(not names).."  "..tostring(names).."  "..tostring(names and type(names) == "table").."  "..tostring(names and type(names) == "table" and #names == count))
    --    assert(not names or (names and count == 1 and type(names) == "string") or (names and type(names) == "table" and #names == count), "Invalid names for colors definition")
    if count == 1 then
        return {
            key = key,
            name = type(names) == "table" and names[1] or names,
            desc = type(names) == "table" and names[1] or names,
            type = "color",
            get = GetColor,
            set = SetColor,
            disabled = D.Helpers.IsPluginDisabled
        }
    else
        local args = {}
        for i = 1, count do
            args[tostring(i)] = {
                order = i,
                name = type(names) == "table" and names[i] or names,
                type = "color"
            }
        end
        return {
            key = key,
            name = L.Colors,
            desc = L.Colors,
            type = "group",
            guiInline = true,
            get = GetColors,
            set = SetColors,
            args = args,
            disabled = D.Helpers.IsPluginDisabled
        }
    end
end

D.Helpers.ColorPanel = {
    key = "color_panel",
    name = L.BarColor,
    desc = L.BarColor,
    type = "group",
    guiInline = true,
    disabled = D.Helpers.IsPluginDisabled,
    args = {
        customcolor = {
            order = 1,
            name = L.CustomColor,
            desc = L.CustomColorDesc,
            type = "toggle",
            get = D.Helpers.GetValueUsingInfo,
            set = D.Helpers.SetValueUsingInfo,
        },
        color = {
            order = 2,
            name = L.Colors,
            desc = L.Colors,
            type = "color",
            get = GetColor,
            set = SetColor,
            hasAlpha = true,
            disabled = D.Helpers.IsCustomColor,
        },
    },
}