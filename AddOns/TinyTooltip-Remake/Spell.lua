
local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local GetSpellTexture = GetSpellTexture or C_Spell.GetSpellTexture

local addon = TinyTooltip

local function ColorBorder(tip)
    if (addon.db.spell.borderColor) then
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.spell.borderColor))
    end
end

local function ColorBackground(tip)
    if (addon.db.spell.background) then
        LibEvent:trigger("tooltip.style.background", tip, unpack(addon.db.spell.background))
    end
end

local function SpellIcon(tip, spellId)
    if (addon.db.spell.showIcon) then
        local id = spellId
        if ((not id) and tip and tip.GetSpell) then
            local ok, _, sid = pcall(tip.GetSpell, tip)
            if (ok and type(sid) == "number") then
                id = sid
            end
        end
        local texture = GetSpellTexture(id or 0)
        local okText, text = pcall(function()
            return addon:GetLine(tip,1):GetText()
        end)
        if (texture and okText and type(text) == "string") then
            local okFind, found = pcall(strfind, text, "^|T")
            if (okFind and not found) then
                addon:GetLine(tip,1):SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
                tip:Show()
                if (addon.AutoSetTooltipWidth) then
                    addon:AutoSetTooltipWidth(tip)
                end
            end
        end
    end
end

LibEvent:attachTrigger("tooltip:spell", function(self, tip, spellId)
    if (addon.db and addon.db.general) then
        LibEvent:trigger("tooltip.style.bgfile", tip, addon.db.general.bgfile)
        LibEvent:trigger("tooltip.style.border.corner", tip, addon.db.general.borderCorner)
        if (addon.db.general.borderCorner == "angular") then
            LibEvent:trigger("tooltip.style.border.size", tip, addon.db.general.borderSize)
        end
    end
    SpellIcon(tip, spellId)
    ColorBorder(tip)
    ColorBackground(tip)
end)
