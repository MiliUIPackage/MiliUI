do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
local LSM = LibStub("LibSharedMedia-3.0", true)
if not LSM then return end

local Assets = YUI and YUI.Assets
local function HasBundle(bundleId)
    if Assets and Assets.IsBundleAvailable then
        return Assets:IsBundleAvailable(bundleId)
    end
    return true
end

local function Bundle(bundleId, path)
    if Assets and Assets.Bundle then
        return Assets:Bundle(bundleId, path)
    end
    return "Interface\\AddOns\\YUI_AuctionHelper\\CoreEmbed\\Media\\Bundles\\" .. bundleId .. "\\" .. path
end

-- -----
-- BACKGROUND
-- -----

-- -----
--  BORDER
-- ----
-- LSM:Register("border", "|CFFBA55D3YUI Border1|r", Bundle("sharedmedia-borders", "YUI Border1.tga"))

-- -----
--  Arrows
-- ----
-- LSM:Register("media", "|CFFBA55D3EthricArrow|r", Bundle("sharedmedia-arrows", "EthricArrow.tga"))

-- -----
--   FONT
-- -----
if HasBundle("sharedmedia-fonts") then
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3Inter Black|r", Bundle("sharedmedia-fonts", "YUI Inter Black.ttf"), 255)
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3Inter Bold|r", Bundle("sharedmedia-fonts", "YUI Inter Bold.ttf"), 255)
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3Text|r", Bundle("sharedmedia-fonts", "YUI Text.TTF"), 255)
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3龙珠|r", Bundle("sharedmedia-fonts", "YUI LongZhu.ttf"), 255)
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3HOOGE|r", Bundle("sharedmedia-fonts", "YUI HOOGE.ttf"), 255)
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3胖娃|r", Bundle("sharedmedia-fonts", "YUI Damage1.ttf"), 255)
    LSM:Register("font", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3Dark|r", Bundle("sharedmedia-fonts", "YUI Dark.ttf"), 255)
end



-- -----
--   SOUND
-- -----
-- LSM:Register("sound", "|CFFBA55D3SX1|r", Bundle("voice-wyjj", "???.ogg"))

-- -----
--   STATUSBAR
-- -----
local function RegisterStatusBar(name, file)
    LSM:Register("statusbar", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3" .. name .. "|r", Bundle("sharedmedia-statusbars", file))
end

LSM:Register("statusbar", " |cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r |CFFBA55D3Solid|r", [[Interface\Buttons\WHITE8X8]])
if HasBundle("sharedmedia-statusbars") then
    RegisterStatusBar("G1", "YUI G1.tga")
    RegisterStatusBar("G2", "YUI G2.tga")
    RegisterStatusBar("H1", "YUI H1.tga")
    RegisterStatusBar("H2", "YUI H2.tga")
    RegisterStatusBar("F1", "YUI F1.tga")
    RegisterStatusBar("F2", "YUI F2.tga")
    RegisterStatusBar("1P", "YUI 1P.tga")
    RegisterStatusBar("C1", "YUI C1.tga")
    RegisterStatusBar("None", "YUI None.png")
end
