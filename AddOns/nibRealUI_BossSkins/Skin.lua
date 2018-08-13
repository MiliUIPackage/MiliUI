local NAME, addon = ...
local function debug(...)
    if RealUI then
        RealUI.Debug("BossSkins", ...)
    end
end

local defaults = {
    version = GetAddOnMetadata(NAME, "Version"),
}

local f = CreateFrame("Frame")
local function registerBWStyle()
    debug("registerBWStyle")
    if not BigWigs then return end
    local bars = BigWigs:GetPlugin("Bars", true)
    if not bars then return end
    debug("registerBWStyle: Start")

    f:UnregisterEvent("ADDON_LOADED")
    f:UnregisterEvent("PLAYER_LOGIN")

    local fontName, fontSize, fontArgs = RealUISkinFont:GetFont()

    -- based on MonoUI style
    local backdropBorder = {
        bgFile = [[Interface\AddOns\nibRealUI_BossSkins\media\Plain]],
        edgeFile = [[Interface\AddOns\nibRealUI_BossSkins\media\Plain]],
        tile = false, tileSize = 0, edgeSize = 1,
        insets = {left = 0, right = 0, top = 0, bottom = 0}
    }

    local function styleBar(bar)
        debug("styleBar", bar)
        bar:SetHeight(10)
        bar.candyBarBackground:Hide()

        local bd = bar.candyBarBackdrop
        bd:SetBackdrop(backdropBorder)
        bd:SetBackdropColor(0, 0, 0, 0.5)
        bd:SetBackdropBorderColor(0, 0, 0, 1)

        bd:ClearAllPoints()
        bd:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        bd:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        bd:Show()

        if bars.db.profile.icon then
            local icon = bar.candyBarIconFrame
            local tex = icon.icon
            bar:SetIcon(nil)
            icon:SetTexture(tex)
            icon:ClearAllPoints()
            icon:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -4, 0)
            icon:SetSize(24, 24)
            icon:Show() -- XXX temp
            bar:Set("bigwigs:restoreIcon", tex)

            local iconBd = bar.candyBarIconFrameBackdrop
            iconBd:SetBackdrop(backdropBorder)
            iconBd:SetBackdropColor(0, 0, 0, 0.5)
            iconBd:SetBackdropBorderColor(0, 0, 0, 1)

            iconBd:ClearAllPoints()
            iconBd:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
            iconBd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
            iconBd:Show()
        end

        local label = bar.candyBarLabel
        local font = label:GetFontObject() or {label:GetFont()}
        bar:Set("bigwigs:restoreFont", font)
        local shadow = {label:GetShadowOffset()}
        bar:Set("bigwigs:restoreShadow", shadow)

        label:SetFont(fontName, fontSize, fontArgs)
        label:SetShadowOffset(0, 0)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("BOTTOM")
        label:ClearAllPoints()
        label:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 4, 3)
        label:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -25, 20)

        local timer = bar.candyBarDuration
        timer:SetFont(fontName, fontSize, fontArgs)
        timer:SetShadowOffset(0, 0)
        timer:SetJustifyH("RIGHT")
        timer:ClearAllPoints()
        timer:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -4, 3)

        bar:SetTexture([[Interface\AddOns\nibRealUI_BossSkins\media\Plain]])
    end

    local function removeStyle(bar)
        debug("removeStyle", bar)
        bar:SetHeight(14)
        bar.candyBarBackdrop:Hide()
        bar.candyBarBackground:Show()

        local tex = bar:Get("bigwigs:restoreIcon")
        if tex then
            local icon = bar.candyBarIconFrame
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT")
            icon:SetPoint("BOTTOMLEFT")
            bar:SetIcon(tex)

            bar.candyBarIconFrameBackdrop:Hide()
        end

        local shadow = bar:Get("bigwigs:restoreShadow")
        local label = bar.candyBarLabel
        label:SetShadowOffset(shadow[1], shadow[2])
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", bar.candyBarBar, "TOPLEFT", 2, 0)
        label:SetPoint("BOTTOMRIGHT", bar.candyBarBar, "BOTTOMRIGHT", -2, 0)

        local timer = bar.candyBarDuration
        timer:SetShadowOffset(shadow[1], shadow[2])
        timer:ClearAllPoints()
        timer:SetPoint("RIGHT", bar.candyBarBar, "RIGHT", -2, 0)

        local font = bar:Get("bigwigs:restoreFont")
        if type(font) == "table" and font[1] then
            debug("restoreFont", font[1], font[2], font[3])
            label:SetFont(font[1], floor(font[2] + 0.5), font[3])
            timer:SetFont(font[1], floor(font[2] + 0.5), font[3])
        else
            label:SetFontObject(font)
            timer:SetFontObject(font)
        end
    end

    bars:RegisterBarStyle("RealUI", {
        apiVersion = 1,
        version = 1,
        GetSpacing = function(bar) return 23 end,
        ApplyStyle = styleBar,
        BarStopped = removeStyle,
        GetStyleName = function() return "RealUI" end,
    })
end

local function registerDBMStyle()
    debug("registerDBMStyle")
    if not DBM then return end
    debug("registerDBMStyle: Start")
    local skin = DBT:RegisterSkin("nibRealUI_BossSkins")

    f:UnregisterEvent("ADDON_LOADED")
    f:UnregisterEvent("PLAYER_LOGIN")

    skin.defaults = {
        Skin = "RealUI",
        Template = "RealUISkinTimerTemplate",
        Texture = [[Interface\AddOns\nibRealUI_BossSkins\media\Plain]],
        FillUpBars = false,
        IconLocked = false,

        Font = "", --If this has any set font it will override the XML font template, so it needs to be blank.
        FontSize = 8,

        StartColorR = 1,
        StartColorG = 0.8,
        StartColorB = 0,
        EndColorR = 1,
        EndColorG = 0.1,
        EndColorB = 0,

        Width = 185,
        Height = 10,
        Scale = 1,
        TimerPoint = "TOP",
        TimerX = 281.5,
        TimerY = -135,
        BarYOffset = 9,

        HugeWidth = 185,
        HugeScale = 1,
        HugeTimerPoint = "TOP",
        HugeTimerX = -249,
        HugeTimerY = -134.5,
        HugeBarYOffset = 9,
    }

    debug("Override texture", DBM.Bars.options.Texture)
    if DBM.Bars.options.Texture:find("DBM") then
        DBM.Bars.options.Texture = skin.defaults.Texture
    end

    debug("Set skin", DBM.Bars.options.Template, skin.defaults.Template)
    if (DBM.Bars.options.Template ~= skin.defaults.Template) then
        --only set the skin if it isn't already set.
        DBM.Bars:SetSkin("nibRealUI_BossSkins")
    end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

local reason = nil
f:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == NAME then
            debug(addon, "loaded")
            RUIBossSkinsDB = RUIBossSkinsDB or defaults
        end
        if not reason then reason = (select(5, GetAddOnInfo("BigWigs_Plugins"))) end
        debug(event, addon, reason)
        if (reason == "MISSING" and addon == "BigWigs") or addon == "BigWigs_Plugins" then
            registerBWStyle()
        end
    elseif event == "PLAYER_LOGIN" then
        debug(event)
        if IsAddOnLoaded("BigWigs") then
            registerBWStyle()
        elseif IsAddOnLoaded("DBM-Core") then
            registerDBMStyle()
        end
    end
end)
