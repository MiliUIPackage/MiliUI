local _, Cell = ...
local L = Cell.L
---@type CellFuncs
local F = Cell.funcs
---@class CellIndicatorFuncs
local I = Cell.iFuncs

-- NOTE for Custom Indicator authors (Midnight 12.0.0+):
-- In restricted contexts (encounters, M+, PvP, combat), aura data fields
-- (spellId, expirationTime, applications, icon, etc.) are Secret Values.
-- - DO NOT compare secret values with == or use arithmetic on them
-- - DO NOT use secret values as table keys
-- - FontString:SetText() and SetTexture() ACCEPT secrets safely
-- - Use issecretvalue(val) to check if a value is secret
-- - Use GetRestrictedActionStatus(0) to check if aura access is restricted

-------------------------------------------------
-- custom indicators
-------------------------------------------------
local enabledIndicators = {}
local customIndicators = {
    ["buff"] = {},
    ["debuff"] = {},
}

Cell.snippetVars.enabledIndicators = enabledIndicators
Cell.snippetVars.customIndicators = customIndicators

--! init enabledIndicators & customIndicators
function I.UpdateIndicatorTable(indicatorTable)
    -- ⚠ Only user-created indicators belong here -- the caller walks from
    -- Cell.defaults.builtIns + 1. If that split point and the actual layout ever disagree (a
    -- layout that missed a migration, or a new built-in added without bumping builtIns), a
    -- built-in entry lands here with no ["auras"] and ipairs(nil) throws on EVERY roster
    -- update. Skipping is strictly better than erroring: the built-in is already driven by its
    -- own code path, and a genuinely broken custom entry just goes quiet instead of spamming.
    if indicatorTable["type"] == "built-in" or type(indicatorTable["auras"]) ~= "table" then
        return
    end

    local indicatorName = indicatorTable["indicatorName"]
    local auraType = indicatorTable["auraType"]

    -- keep custom indicators in table
    if indicatorTable["enabled"] then enabledIndicators[indicatorName] = true end

    -- NOTE: icons is different from other custom indicators, more like the Debuffs indicator
    if indicatorTable["type"] == "icons" then
        customIndicators[auraType][indicatorName] = {
            ["auras"] = F.ConvertSpellTable(indicatorTable["auras"], indicatorTable["trackByName"]), -- auras to match
            ["found"] = {},
            ["num"] = indicatorTable["num"],
        }
    elseif indicatorTable["type"] == "bars" or indicatorTable["type"] == "blocks" then
        customIndicators[auraType][indicatorName] = {
            ["auras"] = F.ConvertSpellTable_WithColor(indicatorTable["auras"], indicatorTable["trackByName"]), -- auras to match
            ["hasColor"] = true,
            ["found"] = {},
            ["num"] = indicatorTable["num"],
        }
    elseif indicatorTable["type"] == "border" then
        customIndicators[auraType][indicatorName] = {
            ["auras"] = F.ConvertSpellTable_WithColor(indicatorTable["auras"], indicatorTable["trackByName"]), -- auras to match
            ["hasColor"] = true,
            ["top"] = {},
            ["topOrder"] = {},
        }
    else
        customIndicators[auraType][indicatorName] = {
            ["auras"] = F.ConvertSpellTable(indicatorTable["auras"], indicatorTable["trackByName"]), -- auras to match
            ["top"] = {}, -- top aura details
            ["topOrder"] = {}, -- top aura order
        }
    end

    customIndicators[auraType][indicatorName]["name"] = indicatorTable["name"]
    customIndicators[auraType][indicatorName]["type"] = indicatorTable["type"]
    customIndicators[auraType][indicatorName]["castBy"] = indicatorTable["castBy"]

    if auraType == "buff" then
        customIndicators[auraType][indicatorName]["_auras"] = F.Copy(indicatorTable["auras"]) --* save ids
        customIndicators[auraType][indicatorName]["trackByName"] = indicatorTable["trackByName"]
    end
end

function I.CreateIndicator(parent, indicatorTable)
    local indicatorName = indicatorTable["indicatorName"]

    -- This function overwrites parent.indicators[indicatorName] below. If one already
    -- exists, its AuraContainer is parented to the BUTTON (not to the indicator), so
    -- dropping the reference alone leaves it live and still bound to the unit -- it keeps
    -- rendering a stuck icon at the old position forever. Tear it down before orphaning it.
    local existing = parent.indicators[indicatorName]
    if existing and I.UnregisterContainerIndicator then
        I.UnregisterContainerIndicator(parent, existing)
    end

    local indicator
    if indicatorTable["type"] == "icon" then
        indicator = I.CreateAura_BarIcon(nil, parent.widgets.indicatorFrame)
    elseif indicatorTable["type"] == "text" then
        indicator = I.CreateAura_Text(nil, parent.widgets.indicatorFrame)
    elseif indicatorTable["type"] == "bar" then
        indicator = I.CreateAura_Bar(nil, parent.widgets.indicatorFrame)
    elseif indicatorTable["type"] == "bars" then
        indicator = I.CreateAura_Bars(nil, parent.widgets.indicatorFrame, 10)
    elseif indicatorTable["type"] == "rect" then
        indicator = I.CreateAura_Rect(nil, parent.widgets.indicatorFrame)
    elseif indicatorTable["type"] == "icons" then
        indicator = I.CreateAura_Icons(nil, parent.widgets.indicatorFrame, 10)
    elseif indicatorTable["type"] == "color" then
        indicator = I.CreateAura_Color(nil, parent)
    elseif indicatorTable["type"] == "texture" then
        indicator = I.CreateAura_Texture(nil, parent.widgets.indicatorFrame)
    elseif indicatorTable["type"] == "glow" then
        indicator = I.CreateAura_Glow(nil, parent.widgets.highLevelFrame)
    elseif indicatorTable["type"] == "overlay" then
        indicator = I.CreateAura_Overlay(nil, parent)
    elseif indicatorTable["type"] == "block" then
        indicator = I.CreateAura_Block(nil, parent.widgets.indicatorFrame)
    elseif indicatorTable["type"] == "blocks" then
        indicator = I.CreateAura_Blocks(nil, parent.widgets.indicatorFrame, 10)
    elseif indicatorTable["type"] == "border" then
        indicator = I.CreateAura_Border(nil, parent.widgets.highLevelFrame)
    end
    parent.indicators[indicatorName] = indicator

    -- 12.1 "Route A": back icon-type BUFF indicators with a Blizzard AuraContainer so they
    -- keep updating in combat -- the manual aura scan cannot, because auras are secret
    -- there. Friendly-unit BUFFS may still be filtered by spell ID, which is what makes
    -- this possible (the ban covers debuffs on friendly units).
    -- Effect types (color/glow/border/overlay/text/bar/...) stay on the manual path: they
    -- render aura PRESENCE rather than icons, and presence is secret.
    -- NOTE: trackByName matches by name in the manual path; the container matches the
    -- configured IDs exactly (candidateFilters has no name form).
    -- 12.1 "Route A" now also covers effect-type BUFF indicators: block and text render aura
    -- PRESENCE, which the manual path cannot read once auras are secret. The container drives
    -- visibility so they update in combat -- as a fixed-colour block or a bare countdown/stack
    -- number (no time-based recolour; remaining duration stays secret). See StyleButton.
    local ctype = indicatorTable["type"]
    local isIconish  = ctype == "icon" or ctype == "icons"
    local isEffectish = ctype == "block" or ctype == "text"
    if indicator and indicatorTable["auraType"] == "buff" and I.AttachBuffContainer
        and (isIconish or isEffectish) then
        local isMulti = ctype == "icons"
        local customStyle = isEffectish and ctype or nil
        I.AttachBuffContainer(parent, indicator, function(t)
            local ids = {}
            for _, id in pairs(t["auras"] or {}) do
                if type(id) == "number" then ids[id] = true end
            end
            return ids
        end, isMulti and (indicatorTable["num"] or 3) or 1,
        true, customStyle) -- ring/fill colour comes from the indicator's own 顏色 setting
    end

    return indicator
end

function I.RemoveIndicator(parent, indicatorName, auraType)
    local indicator = parent.indicators[indicatorName]
    if I.UnregisterContainerIndicator then I.UnregisterContainerIndicator(parent, indicator) end
    indicator:ClearAllPoints()
    indicator:Hide()
    indicator:SetParent(nil)
    parent.indicators[indicatorName] = nil
    enabledIndicators[indicatorName] = nil
    customIndicators[auraType][indicatorName] = nil
end

-- used for switching to a new layout
function I.RemoveAllCustomIndicators(parent)
    -- if parent ~= CellIndicatorsPreviewButton then
    --     wipe(enabledIndicators)
    --     wipe(customIndicators["buff"])
    --     wipe(customIndicators["debuff"])
    -- end

    for indicatorName, indicator in pairs(parent.indicators) do
        if string.find(indicatorName, "^indicator") then
            if I.UnregisterContainerIndicator then I.UnregisterContainerIndicator(parent, indicator) end
            indicator:ClearAllPoints()
            indicator:Hide()
            indicator:SetParent(nil)
            parent.indicators[indicatorName] = nil
        end
    end
end

function I.ResetCustomIndicatorTables()
    -- clear
    wipe(enabledIndicators)
    wipe(customIndicators["buff"])
    wipe(customIndicators["debuff"])

    -- update customs
    for i = Cell.defaults.builtIns + 1, #Cell.vars.currentLayoutTable.indicators do
        I.UpdateIndicatorTable(Cell.vars.currentLayoutTable.indicators[i])
    end
end

local function UpdateCustomIndicators(layout, indicatorName, setting, value, value2)
    if layout and layout ~= Cell.vars.currentLayout then return end

    if not indicatorName or not string.find(indicatorName, "^indicator") then return end

    if setting == "enabled" then
        if value then
            enabledIndicators[indicatorName] = true
        else
            enabledIndicators[indicatorName] = nil
        end
    elseif setting == "auras" then
        customIndicators[value][indicatorName]["_auras"] = F.Copy(value2) --* save ids
        if customIndicators[value][indicatorName]["hasColor"] then
            customIndicators[value][indicatorName]["auras"] = F.ConvertSpellTable_WithColor(value2, customIndicators[value][indicatorName]["trackByName"])
        else
            customIndicators[value][indicatorName]["auras"] = F.ConvertSpellTable(value2, customIndicators[value][indicatorName]["trackByName"])
        end
    elseif setting == "checkbutton" then
        if customIndicators["buff"][indicatorName] then
            customIndicators["buff"][indicatorName][value] = value2
            if value == "trackByName" then
                if customIndicators["buff"][indicatorName]["hasColor"] then
                    customIndicators["buff"][indicatorName]["auras"] = F.ConvertSpellTable_WithColor(customIndicators["buff"][indicatorName]["_auras"], value2)
                else
                    customIndicators["buff"][indicatorName]["auras"] = F.ConvertSpellTable(customIndicators["buff"][indicatorName]["_auras"], value2)
                end
            end
        elseif customIndicators["debuff"][indicatorName] then
            customIndicators["debuff"][indicatorName][value] = value2
        end
    else -- num, castBy
        if customIndicators["buff"][indicatorName] then
            customIndicators["buff"][indicatorName][setting] = value
        elseif customIndicators["debuff"][indicatorName] then
            customIndicators["debuff"][indicatorName][setting] = value
        end
    end
end
Cell.RegisterCallback("UpdateIndicators", "UpdateCustomIndicators", UpdateCustomIndicators)

-------------------------------------------------
-- reset
-------------------------------------------------
function I.ResetCustomIndicators(unitButton, auraType)
    local unit = unitButton.states.displayedUnit

    for indicatorName, indicatorTable in pairs(customIndicators[auraType]) do
        if enabledIndicators[indicatorName] and unitButton.indicators[indicatorName] then
            unitButton.indicators[indicatorName]:Hide(true)
            if indicatorTable["num"] then
                if not indicatorTable["found"][unit] then
                    indicatorTable["found"][unit] = {}
                else
                    wipe(indicatorTable["found"][unit])
                end
            else
                indicatorTable["topOrder"][unit] = 999
                if not indicatorTable["top"][unit] then
                    indicatorTable["top"][unit] = {}
                else
                    wipe(indicatorTable["top"][unit])
                end
            end
        end
    end
end

-------------------------------------------------
-- update
-------------------------------------------------
local function Update(indicator, indicatorTable, unit, spell, start, duration, debuffType, icon, count, refreshing)
    if indicatorTable["num"] then
        if indicatorTable["hasColor"] then
            tinsert(indicatorTable["found"][unit], {indicatorTable["auras"][spell][1], start, duration, debuffType, icon, count, refreshing, indicatorTable["auras"][spell][2]})
        else
            tinsert(indicatorTable["found"][unit], {indicatorTable["auras"][spell], start, duration, debuffType, icon, count, refreshing})
        end
    else
        if indicatorTable["hasColor"] then
            if indicatorTable["auras"][spell][1] < indicatorTable["topOrder"][unit] then
                indicatorTable["topOrder"][unit] = indicatorTable["auras"][spell][1]
                indicatorTable["top"][unit]["start"] = start
                indicatorTable["top"][unit]["duration"] = duration
                indicatorTable["top"][unit]["debuffType"] = debuffType
                indicatorTable["top"][unit]["texture"] = icon
                indicatorTable["top"][unit]["count"] = count
                indicatorTable["top"][unit]["refreshing"] = refreshing
                indicatorTable["top"][unit]["color"] = indicatorTable["auras"][spell][2]
            end
        else
            if indicatorTable["auras"][spell] < indicatorTable["topOrder"][unit] then
                indicatorTable["topOrder"][unit] = indicatorTable["auras"][spell]
                indicatorTable["top"][unit]["start"] = start
                indicatorTable["top"][unit]["duration"] = duration
                indicatorTable["top"][unit]["debuffType"] = debuffType
                indicatorTable["top"][unit]["texture"] = icon
                indicatorTable["top"][unit]["count"] = count
                indicatorTable["top"][unit]["refreshing"] = refreshing
            end
        end
    end
end

function I.UpdateCustomIndicators(unitButton, auraInfo)
    -- ⚠ A PER-AURA secrecy gate is required here, not just the content-level one.
    -- UnitButton_UpdateAuras bails on C_Secrets.ShouldAurasBeSecret(), but that answers for the
    -- CONTENT, not for one aura -- an individual aura on a raid member can still come back
    -- wholly secret while it says false, which is how this function was reached at all.
    -- Three reads below are boolean tests on fields that are secret exactly then (isHelpful on
    -- the next line, isHarmful twice after it), and a boolean test on a secret boolean is a
    -- hard error, not a nil -- so it threw before the function could do anything.
    --
    -- Bailing loses nothing. A secret aura cannot match an indicator further down either: its
    -- spell ID and name are unusable as table keys (the lookup is explicitly skipped for
    -- secrets), and the "track any aura" wildcard branch needs duration ~= 0 while the secret
    -- path below forces duration to 0. The whole body was already dead work for these auras.
    --
    -- Both checks earn their place: IsAuraNonSecret is the sentinel the rest of this function
    -- and HandleBuff already use (it reads spellId), and the second one guards the exact field
    -- that crashed rather than assuming a payload is always secret as a whole.
    if not F.IsAuraNonSecret(auraInfo) or not F.IsValueNonSecret(auraInfo.isHelpful) then return end

    local unit = unitButton.states.displayedUnit

    local auraType = auraInfo.isHelpful and "buff" or "debuff"
    local icon = auraInfo.icon
    -- Midnight 12.0.0+: dispelName may be secret; sanitize to avoid table-key/comparison crashes downstream
    local rawDispelName = auraInfo.dispelName
    local debuffType = auraInfo.isHarmful and ((rawDispelName and (not issecretvalue or not issecretvalue(rawDispelName))) and rawDispelName or "") or nil
    local count = auraInfo.applications
    local duration = auraInfo.duration
    -- Use per-aura check for duration: non-secret auras get real timers, secret ones get zeroed.
    local start
    if F.IsAuraNonSecret(auraInfo) then
        start = (auraInfo.expirationTime or 0) - auraInfo.duration
    else
        start = 0
        duration = 0
    end
    -- sourceUnit is secret on restricted auras; castByMe defaults to false when unreadable.
    local castByMe = false
    if F.IsValueNonSecret(auraInfo.sourceUnit) then
        castByMe = auraInfo.sourceUnit == "player" or auraInfo.sourceUnit == "pet"
    end

    -- check Bleed
    if auraInfo.isHarmful then
        debuffType = I.CheckDebuffType(debuffType, auraInfo.spellId)
    end

    for indicatorName, indicatorTable in pairs(customIndicators[auraType]) do
        -- Skip indicators an AuraContainer backs: they drive themselves from SetUnit and
        -- keep working while auras are secret, which this manual path cannot.
        if indicatorName and enabledIndicators[indicatorName] and unitButton.indicators[indicatorName]
            and not unitButton.indicators[indicatorName].container then
            local spell  --* trackByName
            if indicatorTable["trackByName"] then
                spell = auraInfo.name
            else
                spell = auraInfo.spellId
            end

            -- Midnight 12.0.0+: spell (name or spellId) may be secret; cannot use as table key
            if spell and (not issecretvalue or not issecretvalue(spell)) and indicatorTable["auras"][spell] or (indicatorTable["auras"][0] and duration ~= 0) then -- is in indicator spell list
                -- check caster
                if (indicatorTable["castBy"] == "me" and castByMe) or (indicatorTable["castBy"] == "others" and not castByMe) or (indicatorTable["castBy"] == "anyone") then
                    if auraType == "buff" then
                        Update(unitButton.indicators[indicatorName], indicatorTable, unit, spell, start, duration, debuffType, icon, count, auraInfo.refreshing)
                    else -- debuff
                        Update(unitButton.indicators[indicatorName], indicatorTable, unit, spell, start, duration, debuffType, icon, count, auraInfo.refreshing)
                    end
                end
            end
        end
    end
end

-------------------------------------------------
-- show
-------------------------------------------------
local sort = table.sort
local function comparator(a, b)
    if a[1] and b[1] then
        return a[1] < b[1]
    else
        return a[2] <= b[2]
    end
end

function I.ShowCustomIndicators(unitButton, auraType)
    if not unitButton._indicatorsReady then return end

    local unit = unitButton.states.displayedUnit
    for indicatorName, indicatorTable in pairs(customIndicators[auraType]) do
        local indicator = unitButton.indicators[indicatorName]
        if indicator and enabledIndicators[indicatorName] and not indicator.container then
            if indicatorTable["num"] then
                local t = indicatorTable["found"][unit]
                if t[1] then
                    sort(t, comparator)
                    for i = 1, indicatorTable["num"] do
                        if not t[i] then break end
                        -- 1:order, 2:start, 3:duration, 4:debuffType, 5:icon, 6:count, 7:refreshing, 8:color
                        indicator[i]:SetCooldown(t[i][2], t[i][3], t[i][4], t[i][5], t[i][6], t[i][7], t[i][8])
                    end
                    indicator:Show()
                    indicator:UpdateSize()
                end
            else
                if indicatorTable["top"][unit] and indicatorTable["top"][unit]["start"] then
                    indicator:SetCooldown(
                        indicatorTable["top"][unit]["start"],
                        indicatorTable["top"][unit]["duration"],
                        indicatorTable["top"][unit]["debuffType"],
                        indicatorTable["top"][unit]["texture"],
                        indicatorTable["top"][unit]["count"],
                        indicatorTable["top"][unit]["refreshing"],
                        indicatorTable["top"][unit]["color"]
                    )
                end
            end
        end
    end
end