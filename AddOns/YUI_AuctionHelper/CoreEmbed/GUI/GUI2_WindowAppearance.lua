do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

if not YUI then return end

local GUI2 = YUI.GUI2
if not GUI2 then return end

local Existing = GUI2.WindowAppearance
if type(Existing) == "table" and Existing._windowAppearanceVersion then
    YUI.AuctionHelperAppearance = Existing
    return Existing
end

local Appearance = {}
GUI2.WindowAppearance = Appearance
YUI.AuctionHelperAppearance = Appearance
Appearance._windowAppearanceVersion = 2

local unpack = unpack or table.unpack

local FRAME_STATES = setmetatable({}, { __mode = "k" })
local FONT_STATES = setmetatable({}, { __mode = "k" })
local REGISTERED_FRAMES = setmetatable({}, { __mode = "k" })
local EXTERNAL_CONSUMERS = setmetatable({}, { __mode = "k" })
local EXTERNAL_SHELL_STATES = setmetatable({}, { __mode = "k" })
local CONTEXT_OVERRIDES = setmetatable({}, { __mode = "k" })
local contextOverrideSequence = 0
local NATIVE_TEXTURE = "Interface\\FrameGeneral\\UI-Background-Rock"
local STRIPE_TEXTURE = "Interface\\AddOns\\NDui\\Media\\bgTex.blp"

local FALLBACK = {
    background = { 0.045, 0.055, 0.065, 0.96 },
    border = { 0.20, 0.23, 0.27, 1 },
    accent = { 1, 0.82, 0, 1 },
    topBar = { 0, 0, 0, 0.34 },
}

local official = {
    provider = nil,
    attempted = false,
    accepted = false,
    facade = nil,
    looksHooked = false,
    resolving = false,
}

local appearanceEventOwner = {}

local function IsAddOnLoaded(name)
    local addons = _G.C_AddOns
    local checker = addons and addons.IsAddOnLoaded
    if type(checker) ~= "function" then
        checker = _G.IsAddOnLoaded
    end
    if type(checker) ~= "function" then return false end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function SafeCall(owner, key, ...)
    if type(owner) ~= "table" or type(owner[key]) ~= "function" then return nil, false end
    local ok, value, extra = pcall(owner[key], ...)
    if not ok then return nil, false end
    return value, true, extra
end

local function Unit(value)
    value = tonumber(value)
    if not value or value < 0 or value > 1 then return nil end
    return value
end

local function ReadColor(value, defaultAlpha)
    if type(value) ~= "table" then return nil end
    local r = Unit(value.r or value[1])
    local g = Unit(value.g or value[2])
    local b = Unit(value.b or value[3])
    local a = Unit(value.a or value[4]) or defaultAlpha or 1
    if not r or not g or not b then return nil end
    return { r, g, b, a }
end

local function CopyColor(value)
    return { value[1], value[2], value[3], value[4] }
end

local function ThemeColor(key, fallback)
    if GUI2 and type(GUI2.GetColor) == "function" then
        local ok, r, g, b, a = pcall(GUI2.GetColor, GUI2, key)
        if ok then
            local color = ReadColor({ r, g, b, a }, 1)
            if color then return color end
        end
    end
    return CopyColor(fallback)
end

local function DarkContext(reason)
    return {
        source = "dark",
        fallbackReason = reason,
        background = ThemeColor("color.surface.popup", FALLBACK.background),
        border = ThemeColor("color.popup.border", FALLBACK.border),
        accent = ThemeColor("color.text.accent", FALLBACK.accent),
        topBar = CopyColor(FALLBACK.topBar),
    }
end

local function GetOfficialProvider()
    local provider = _G.EllesmereUI
    if type(provider) ~= "table" or type(provider.RegisterSkin) ~= "function" then
        return nil
    end
    return provider
end

local function GetOfficialAccent(facade)
    if facade and type(facade.GetAccentColor) == "function" then
        local ok, r, g, b = pcall(facade.GetAccentColor)
        local color = ok and ReadColor({ r, g, b, 1 }, 1)
        if color then return color end
    end
    return CopyColor(FALLBACK.accent)
end

local function BuildOfficialContext(facade)
    return {
        source = "ellesmere",
        providerKind = "official",
        facade = facade,
        style = "official",
        accent = GetOfficialAccent(facade),
        border = { 0.20, 0.20, 0.20, 1 },
        topBar = { 0, 0, 0, 1 },
        background = CopyColor(FALLBACK.background),
    }
end

local function ResetOfficialState(provider)
    official.provider = provider
    official.attempted = false
    official.accepted = false
    official.facade = nil
    official.looksHooked = false
    official.resolving = false
end

function Appearance:AcceptOfficial(facade, provider)
    if type(facade) ~= "table" or type(facade.Shell) ~= "function" then return false end
    if provider and official.provider and provider ~= official.provider then return false end
    if official.facade ~= facade then official.looksHooked = false end
    official.facade = facade
    official.accepted = true

    if not official.looksHooked and type(facade.OnLooksChanged) == "function" then
        local callback = function()
            self:RefreshAll()
        end
        local ok, registered = pcall(facade.OnLooksChanged, callback)
        official.looksHooked = ok and registered ~= false
    end

    if not official.resolving then
        self:RefreshAll()
    end
    return true
end

local function ResolveOfficialProvider()
    local provider = GetOfficialProvider()
    if not provider then
        if official.provider then ResetOfficialState(nil) end
        return nil, false
    end

    if official.provider ~= provider then
        ResetOfficialState(provider)
    end

    if not official.attempted and not official.facade then
        official.attempted = true
        official.resolving = true
        local ok, accepted = pcall(
            provider.RegisterSkin,
            "YUI",
            function(facade)
                Appearance:AcceptOfficial(facade, provider)
            end
        )
        official.resolving = false
        if ok and accepted == true then
            official.accepted = true
        end
    end

    if official.facade then
        return BuildOfficialContext(official.facade), true
    end
    return nil, false
end

local function ResolveLegacyProvider()
    if not IsAddOnLoaded("EllesmereUIBlizzardSkin") then return nil, false end

    local provider = _G.EllesmereUI
    if type(provider) ~= "table" or type(provider.RegisterSkin) == "function" then
        return nil, false
    end

    local style, styleOK = SafeCall(provider, "GetThirdPartySkinStyle")
    if not styleOK or (style ~= "eui" and style ~= "modern") then
        style, styleOK = SafeCall(provider, "GetBlizzWindowStyle", "auctionhouse")
    end
    if not styleOK or (style ~= "eui" and style ~= "modern") then
        return nil, false
    end

    local context = {
        source = "ellesmere",
        providerKind = "legacy",
        style = style,
        provider = provider,
        accent = ReadColor(provider.ELLESMERE_GREEN, 1) or CopyColor(FALLBACK.accent),
        border = { 0.20, 0.20, 0.20, 1 },
        topBar = { 0, 0, 0, 1 },
        contentShade = { 0, 0, 0, 0.25 },
    }
    if style == "eui" then
        context.background = { 0.08, 0.08, 0.08, 0.92 }
    else
        context.background = ReadColor(
            _G.EllesmereUIDB and _G.EllesmereUIDB.blizzWindowModernDefault,
            0.97
        ) or { 0.067, 0.067, 0.067, 0.97 }
    end

    local fontPath, fontOK = SafeCall(provider, "GetFontPath", "blizzardSkin")
    if fontOK and type(fontPath) == "string" and fontPath ~= "" then
        context.fontPath = fontPath
        local fontFlags, flagsOK = SafeCall(provider, "GetFontOutlineFlag", "blizzardSkin")
        if flagsOK and type(fontFlags) == "string" then context.fontFlags = fontFlags end
        local useShadow, shadowOK = SafeCall(provider, "GetFontUseShadow", "blizzardSkin")
        if shadowOK and type(useShadow) == "boolean" then context.useShadow = useShadow end
    end
    return context, true
end

local function ResolveElvUIProvider()
    if not IsAddOnLoaded("ElvUI") then return nil, false end
    local root = _G.ElvUI
    local engine = type(root) == "table" and root[1] or nil
    local media = type(engine) == "table" and engine.media or nil
    if type(media) ~= "table" then
        if not (type(engine) == "table" and engine.initialized == true) then return nil, false end
        media = {}
    end

    local background = ReadColor(media.backdropfadecolor, 0.88)
        or ReadColor(media.backdropcolor, 0.94)
    local border = ReadColor(media.bordercolor, 1)
    local accent = ReadColor(media.rgbvaluecolor, 1)
    if not background and not border and not accent
        and not (type(engine) == "table" and engine.initialized == true)
    then
        return nil, false
    end

    local context = {
        source = "elvui",
        providerKind = "media",
        background = background or CopyColor(FALLBACK.background),
        border = border or CopyColor(FALLBACK.border),
        accent = accent or CopyColor(FALLBACK.accent),
        topBar = { 0, 0, 0, 0.22 },
    }
    local fontPath = media.normFont or media.font
    if type(fontPath) == "string" and fontPath ~= "" then context.fontPath = fontPath end
    return context, true
end

local function GetNDuiSkinProvider()
    local ndui = _G.NDui
    if type(ndui) ~= "table" then return nil end
    local provider = ndui[1] or ndui.B or ndui
    if type(provider) ~= "table" or type(provider.CreateBDFrame) ~= "function" then return nil end
    if not (provider.Modules or ndui[4] or ndui.DB or ndui.C) then return nil end
    return provider
end

local function ResolveNDuiProvider()
    if not IsAddOnLoaded("NDui") then return nil, false end
    local provider = GetNDuiSkinProvider()
    if not provider then return nil, false end
    return {
        source = "ndui",
        providerKind = "ndui",
        provider = provider,
        background = { 0.025, 0.025, 0.025, 0.90 },
        border = { 0.16, 0.16, 0.16, 1 },
        accent = CopyColor(FALLBACK.accent),
        topBar = { 0, 0, 0, 0.30 },
        stripe = STRIPE_TEXTURE,
    }, true
end

local function TryResolve(resolver, skip)
    local ok, context, detected = pcall(resolver)
    if not ok or not detected then return nil end
    if skip and context and skip[context.source] then return nil end
    return context
end

local function ApplyContextOverrides(context, themeStyle, options)
    if type(context) ~= "table" or themeStyle == "native" or themeStyle == "dark" then
        return context
    end

    local ordered = {}
    for owner, entry in pairs(CONTEXT_OVERRIDES) do
        if owner and type(entry) == "table" and type(entry.callback) == "function" then
            ordered[#ordered + 1] = entry
        end
    end
    table.sort(ordered, function(left, right)
        if left.priority ~= right.priority then return left.priority > right.priority end
        return left.sequence < right.sequence
    end)

    for index = 1, #ordered do
        local ok, replacement = pcall(ordered[index].callback, context, themeStyle, options)
        if ok and type(replacement) == "table" then context = replacement end
    end
    return context
end

function Appearance:RegisterContextOverride(owner, priority, callback)
    if not owner then return false end
    if type(priority) == "function" and callback == nil then
        callback = priority
        priority = 0
    end
    if type(callback) ~= "function" then return false end

    contextOverrideSequence = contextOverrideSequence + 1
    CONTEXT_OVERRIDES[owner] = {
        callback = callback,
        priority = tonumber(priority) or 0,
        sequence = contextOverrideSequence,
    }
    self:RefreshAll()
    return true
end

function Appearance:UnregisterContextOverride(owner)
    if not owner or not CONTEXT_OVERRIDES[owner] then return false end
    CONTEXT_OVERRIDES[owner] = nil
    self:RefreshAll()
    return true
end

function Appearance:Resolve(themeStyle, options)
    if themeStyle == "native" then return { source = "native" } end
    if themeStyle == "dark" then return DarkContext() end

    local skip = options and options.skip
    local context = not (skip and skip.ellesmere)
        and (TryResolve(ResolveOfficialProvider, skip) or TryResolve(ResolveLegacyProvider, skip))
        or nil
    if context then return ApplyContextOverrides(context, themeStyle, options) end

    context = not (skip and skip.elvui) and TryResolve(ResolveElvUIProvider, skip) or nil
    if context then return ApplyContextOverrides(context, themeStyle, options) end

    context = not (skip and skip.ndui) and TryResolve(ResolveNDuiProvider, skip) or nil
    if context then return ApplyContextOverrides(context, themeStyle, options) end

    return ApplyContextOverrides({ source = "native" }, themeStyle, options)
end

local function SafeHide(region)
    if region and type(region.Hide) == "function" then pcall(region.Hide, region) end
end

local function SafeShow(region)
    if region and type(region.Show) == "function" then pcall(region.Show, region) end
end

local function ReadAlpha(region)
    if not region or type(region.GetAlpha) ~= "function" then return 1 end
    local ok, alpha = pcall(region.GetAlpha, region)
    if not ok or type(alpha) ~= "number" then return 1 end
    return alpha
end

local function SetAlpha(region, alpha)
    if not region or type(region.SetAlpha) ~= "function" then return false end
    return pcall(region.SetAlpha, region, alpha)
end

local function SetColor(region, color)
    if not region or not color or type(region.SetColorTexture) ~= "function" then return false end
    return pcall(region.SetColorTexture, region, color[1], color[2], color[3], color[4])
end

local function SetGradient(region, gradient)
    if not region or type(gradient) ~= "table" then return false end
    local bottom, top = gradient.bottom, gradient.top
    if type(bottom) ~= "table" or type(top) ~= "table" then return false end

    if type(region.SetGradientAlpha) == "function" then
        local ok = pcall(region.SetGradientAlpha, region, gradient.orientation or "VERTICAL",
            bottom[1], bottom[2], bottom[3], bottom[4] or 0,
            top[1], top[2], top[3], top[4] or 0)
        if ok then return true end
    end

    if type(region.SetGradient) == "function" and type(CreateColor) == "function" then
        local ok = pcall(function()
            region:SetGradient(gradient.orientation or "VERTICAL",
                CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 0),
                CreateColor(top[1], top[2], top[3], top[4] or 0))
        end)
        if ok then return true end
    end

    return SetColor(region, top)
end

local function SetVertexColor(region, color)
    if not region or not color or type(region.SetVertexColor) ~= "function" then return false end
    return pcall(region.SetVertexColor, region, color[1], color[2], color[3], color[4] or 1)
end

local function PreparePixelTexture(texture)
    if not texture then return end
    if GUI2 and type(GUI2.ApplyTexturePixelPolicy) == "function" then
        pcall(GUI2.ApplyTexturePixelPolicy, GUI2, texture)
        return
    end
    if type(texture.SetSnapToPixelGrid) == "function" then
        pcall(texture.SetSnapToPixelGrid, texture, false)
    end
    if type(texture.SetTexelSnappingBias) == "function" then
        pcall(texture.SetTexelSnappingBias, texture, 0)
    end
end

local function CreateTexture(frame, layer, subLevel)
    if type(frame.CreateTexture) == "function" then
        local ok, texture = pcall(frame.CreateTexture, frame, nil, layer, nil, subLevel)
        if ok and texture then return texture end
    end
    if GUI2 and type(GUI2.CreateTexture) == "function" then
        local ok, texture = pcall(GUI2.CreateTexture, GUI2, frame, { layer = layer, subLevel = subLevel })
        if ok then return texture end
    end
end

local function AnchorAll(region, frame, inset)
    if not region or type(region.SetPoint) ~= "function" then return end
    inset = inset or 0
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
end

local function CreateBorder(frame, state)
    if GUI2 and type(GUI2.CreateBorder) == "function" then
        if not frame.gui2Borders then
            pcall(GUI2.CreateBorder, GUI2, frame, "color.border.default")
        end
        local standard = frame.gui2Borders
        if standard and standard.top and standard.bottom and standard.left and standard.right then
            state.border = { standard.top, standard.bottom, standard.left, standard.right }
            state.standardPixelBorder = true
            return
        end
    end

    state.border = {}
    for index = 1, 4 do
        state.border[index] = CreateTexture(frame, "OVERLAY", 7)
        PreparePixelTexture(state.border[index])
    end
    local pixel = GUI2 and type(GUI2.GetPixelSize) == "function"
        and GUI2:GetPixelSize(frame, 1, 1) or (GUI2 and GUI2.mult or 1)
    local top, bottom, left, right = unpack(state.border)
    if top then
        top:SetPoint("TOPLEFT", frame, "TOPLEFT")
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        top:SetHeight(pixel)
    end
    if bottom then
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
        bottom:SetHeight(pixel)
    end
    if left then
        left:SetPoint("TOPLEFT", frame, "TOPLEFT")
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        left:SetWidth(pixel)
    end
    if right then
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
        right:SetWidth(pixel)
    end
end

local function CreateNativeShell(frame, state)
    if state.nativeAttempted then return state.nativeFrame end
    state.nativeAttempted = true
    if type(_G.CreateFrame) ~= "function" then return nil end
    local clip
    if GUI2 and type(GUI2.CreateFrame) == "function" then
        local clipOK, created = pcall(GUI2.CreateFrame, GUI2, frame)
        if clipOK then clip = created end
    end
    if not clip then
        local clipOK, created = pcall(_G.CreateFrame, "Frame", nil, frame)
        if clipOK then clip = created end
    end
    if not clip then return nil end
    clip:SetAllPoints(frame)
    if type(clip.SetFrameLevel) == "function" and type(frame.GetFrameLevel) == "function" then
        clip:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 2))
    end
    if type(clip.SetClipsChildren) == "function" then pcall(clip.SetClipsChildren, clip, true) end
    state.nativeClip = clip

    local ok, native = pcall(_G.CreateFrame, "Frame", nil, clip, "NineSlicePanelTemplate")
    if not ok or not native then return nil end
    native:SetAllPoints(frame)
    if type(native.SetFrameLevel) == "function" and type(frame.GetFrameLevel) == "function" then
        native:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    end
    local util = _G.NineSliceUtil
    if type(util) == "table" and type(util.ApplyLayoutByName) == "function" then
        pcall(util.ApplyLayoutByName, native, "ButtonFrameTemplateNoPortrait")
    end
    local texture = CreateTexture(native, "BACKGROUND", -7)
    if texture then
        texture:SetTexture(NATIVE_TEXTURE)
        texture:SetPoint("TOPLEFT", native, "TOPLEFT", 6, -2)
        texture:SetPoint("BOTTOMRIGHT", native, "BOTTOMRIGHT", -2, 2)
        if type(texture.SetHorizTile) == "function" then texture:SetHorizTile(true) end
        if type(texture.SetVertTile) == "function" then texture:SetVertTile(true) end
    end
    state.nativeFrame = native
    state.nativeTexture = texture
    return native
end

local function EnsureState(frame)
    local state = FRAME_STATES[frame]
    if state then return state end
    state = {
        background = CreateTexture(frame, "BACKGROUND", 7),
        overlay = CreateTexture(frame, "BACKGROUND", 8),
        topBar = CreateTexture(frame, "BACKGROUND", 9),
        contentShade = CreateTexture(frame, "BACKGROUND", 10),
    }
    FRAME_STATES[frame] = state
    AnchorAll(state.background, frame)
    AnchorAll(state.overlay, frame)
    if state.topBar then
        state.topBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        state.topBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        state.topBar:SetHeight(25)
    end
    if state.contentShade then
        state.contentShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -25)
        state.contentShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    CreateBorder(frame, state)
    return state
end

local function HideShell(state)
    SafeHide(state.background)
    SafeHide(state.overlay)
    SafeHide(state.topBar)
    SafeHide(state.contentShade)
    SafeHide(state.nativeClip)
    SafeHide(state.nativeFrame)
    SafeHide(state.nduiBg)
    for _, line in ipairs(state.border or {}) do SafeHide(line) end
end

local function RestoreCleanBorderAtlas(state)
    local record = state and state.cleanBorderAtlas
    if not record then return end
    if record.region and type(record.region.SetAlpha) == "function"
        and math.abs(ReadAlpha(record.region) - (record.lastAppliedAlpha or 0)) <= 0.001
    then
        pcall(record.region.SetAlpha, record.region, record.originalAlpha or 1)
    end
    state.cleanBorderAtlas = nil
end

local function FindExactBorderAtlas(frame, atlas)
    if type(atlas) ~= "string" or atlas == "" or not frame or type(frame.GetChildren) ~= "function" then return nil end
    local childrenOK, children = pcall(function() return { frame:GetChildren() } end)
    if not childrenOK then return nil end
    local matches = {}
    for childIndex = 1, #children do
        local child = children[childIndex]
        if child and type(child.GetRegions) == "function" then
            local regionsOK, regions = pcall(function() return { child:GetRegions() } end)
            if regionsOK then
                for regionIndex = 1, #regions do
                    local region = regions[regionIndex]
                    if region and type(region.GetAtlas) == "function" then
                        local atlasOK, regionAtlas = pcall(region.GetAtlas, region)
                        local layerOK, layer, subLevel = true, "OVERLAY", 7
                        if type(region.GetDrawLayer) == "function" then
                            layerOK, layer, subLevel = pcall(region.GetDrawLayer, region)
                        end
                        if atlasOK and regionAtlas == atlas and layerOK and layer == "OVERLAY" and subLevel == 7 then
                            matches[#matches + 1] = region
                        end
                    end
                end
            end
        end
    end
    return #matches == 1 and matches[1] or nil
end

local function ApplyCleanBorderAtlas(frame, state, context)
    local atlas = context and context.cleanBorderAtlas
    if type(atlas) ~= "string" or atlas == "" then
        RestoreCleanBorderAtlas(state)
        return false
    end
    local region = FindExactBorderAtlas(frame, atlas)
    if not region then
        RestoreCleanBorderAtlas(state)
        return false
    end
    local record = state.cleanBorderAtlas
    if not record or record.region ~= region then
        RestoreCleanBorderAtlas(state)
        record = { region = region, originalAlpha = ReadAlpha(region) }
        state.cleanBorderAtlas = record
    end
    if not SetAlpha(region, 0) then
        RestoreCleanBorderAtlas(state)
        return false
    end
    record.lastAppliedAlpha = 0
    for _, line in ipairs(state.border or {}) do
        SetColor(line, context.border or FALLBACK.border)
        SetAlpha(line, 1)
        SafeShow(line)
    end
    return true
end

local function ClearOfficialShell(frame, state, context)
    if not state.officialFacade then return end
    if context and context.facade == state.officialFacade and context.customShell ~= true then return end
    SafeCall(state.officialFacade, "Unshell", frame)
    SafeCall(state.officialFacade, "ResetShell", frame)
    state.officialFacade = nil
end

local function ApplyOfficialShell(frame, state, context)
    local facade = context and context.facade
    if not facade or type(facade.Shell) ~= "function" then return false end
    if type(frame.SetBackdrop) == "function" then
        pcall(frame.SetBackdrop, frame, nil)
    end
    local ok, applied = pcall(facade.Shell, frame)
    if not ok or applied == false then
        SafeCall(facade, "Unshell", frame)
        SafeCall(facade, "ResetShell", frame)
        if state.officialFacade == facade then state.officialFacade = nil end
        return false
    end
    state.officialFacade = facade
    return true
end

local function ClearNDuiShell(frame, state, context)
    if not state.nduiBg or (context and context.source == "ndui") then return end
    SafeHide(state.nduiBg)
    if type(frame.SetBackdrop) == "function" then
        pcall(frame.SetBackdrop, frame, nil)
    end
end

local function ApplyNDuiShell(frame, state, context)
    local provider = context and context.provider
    if not provider or type(provider.CreateBDFrame) ~= "function" then return false end

    if state.nduiBg and state.nduiProvider == provider then
        SafeShow(state.nduiBg)
        return true
    end

    SafeHide(state.nduiBg)
    if type(frame.SetBackdrop) == "function" then
        pcall(frame.SetBackdrop, frame, nil)
    end

    local ok, background = pcall(provider.CreateBDFrame, frame, nil, true)
    if not ok or not background then return false end
    state.nduiProvider = provider
    state.nduiBg = background
    if type(provider.CreateTex) == "function" then
        pcall(provider.CreateTex, background)
    end
    if type(provider.CreateSD) == "function" then
        pcall(provider.CreateSD, background, nil, true)
    end
    SafeShow(background)
    return true
end

local function ApplyTexture(texture, path)
    if not texture or type(texture.SetTexture) ~= "function" then return false end
    local ok, applied = pcall(texture.SetTexture, texture, path)
    return ok and applied ~= false
end

local function SetTextureTiling(texture, horizontal, vertical)
    if not texture then return end
    if type(texture.SetHorizTile) == "function" then pcall(texture.SetHorizTile, texture, horizontal == true) end
    if type(texture.SetVertTile) == "function" then pcall(texture.SetVertTile, texture, vertical == true) end
end

local function SetTextureCoords(texture, coords)
    if not texture or type(texture.SetTexCoord) ~= "function" then return end
    coords = type(coords) == "table" and coords or { 0, 1, 0, 1 }
    texture:SetTexCoord(coords[1] or 0, coords[2] or 1, coords[3] or 0, coords[4] or 1)
end

local function ApplyCoverCrop(texture, frame, context)
    if not texture or type(texture.SetTexCoord) ~= "function" then return end
    context = context or {}
    local coords = type(context.textureCoords) == "table" and context.textureCoords or { 0, 1, 0, 1 }
    local sourceAspect = tonumber(context.textureAspect)
    if not sourceAspect or sourceAspect <= 0 then
        SetTextureCoords(texture, coords)
        return
    end
    local function ReadDimension(key)
        if type(frame[key]) ~= "function" then return nil end
        local ok, value = pcall(frame[key], frame)
        if not ok or (_G.issecretvalue and _G.issecretvalue(value)) then return nil end
        return tonumber(value)
    end
    local width = ReadDimension("GetWidth")
    local height = ReadDimension("GetHeight")
    if not width or not height or width <= 0 or height <= 0 then
        SetTextureCoords(texture, coords)
        return
    end
    local frameAspect = width / height
    local left, right, top, bottom = coords[1] or 0, coords[2] or 1, coords[3] or 0, coords[4] or 1
    if frameAspect > sourceAspect then
        local visible = sourceAspect / frameAspect
        local center = (top + bottom) / 2
        local half = (bottom - top) * visible / 2
        top, bottom = center - half, center + half
    else
        local visible = frameAspect / sourceAspect
        local center = (left + right) / 2
        local half = (right - left) * visible / 2
        left, right = center - half, center + half
    end
    texture:SetTexCoord(left, right, top, bottom)
end

local function ApplyCustomShell(frame, state, context)
    local background = state.background
    local backgroundColor = context.background or FALLBACK.background
    SetTextureTiling(background, false, false)
    SetTextureTiling(state.overlay, false, false)
    SetVertexColor(background, { 1, 1, 1, 1 })
    SetVertexColor(state.overlay, { 1, 1, 1, 1 })
    if context.texture and ApplyTexture(background, context.texture) then
        if context.textureMode == "cover" then
            ApplyCoverCrop(background, frame, context)
        else
            SetTextureCoords(background, context.textureCoords)
        end
        SetTextureTiling(background, context.textureTile == true, context.textureTile == true)
        SetVertexColor(background, context.textureColor or { 1, 1, 1, 1 })
    else
        SetColor(background, backgroundColor)
    end
    SetAlpha(background, 1)
    SafeShow(background)

    local overlayTexture = context.overlayTexture or context.stripe
    if overlayTexture then
        if ApplyTexture(state.overlay, overlayTexture) then
            SetTextureCoords(state.overlay, context.overlayTexCoords)
            SetTextureTiling(state.overlay, context.overlayTile == true, context.overlayTile == true)
            SetVertexColor(state.overlay, context.overlayColor or { 0.32, 0.32, 0.32, 0.30 })
            SetAlpha(state.overlay, 1)
            SafeShow(state.overlay)
        else
            SafeHide(state.overlay)
        end
    elseif context.backgroundGradient then
        if SetGradient(state.overlay, context.backgroundGradient) then
            SetAlpha(state.overlay, 1)
            SafeShow(state.overlay)
        else
            SafeHide(state.overlay)
        end
    elseif context.overlay then
        SetColor(state.overlay, context.overlay)
        SetAlpha(state.overlay, 1)
        SafeShow(state.overlay)
    else
        SafeHide(state.overlay)
    end

    SetColor(state.topBar, context.topBar or FALLBACK.topBar)
    SetAlpha(state.topBar, 1)
    SafeShow(state.topBar)
    if context.contentShade then
        SetColor(state.contentShade, context.contentShade)
        SetAlpha(state.contentShade, 1)
        SafeShow(state.contentShade)
    else
        SafeHide(state.contentShade)
    end
    for _, line in ipairs(state.border or {}) do
        SetColor(line, context.border or FALLBACK.border)
        SetAlpha(line, 1)
        SafeShow(line)
    end
end

local function ApplyUniformNativeShell(state)
    if ApplyTexture(state.background, NATIVE_TEXTURE) then
        if type(state.background.SetTexCoord) == "function" then
            state.background:SetTexCoord(0, 1, 0, 1)
        end
        if type(state.background.SetHorizTile) == "function" then state.background:SetHorizTile(true) end
        if type(state.background.SetVertTile) == "function" then state.background:SetVertTile(true) end
        SafeShow(state.background)
    else
        SetColor(state.background, FALLBACK.background)
        SafeShow(state.background)
    end
    SetColor(state.topBar, { 0, 0, 0, 0.36 })
    SafeShow(state.topBar)
    for _, line in ipairs(state.border or {}) do
        SetColor(line, { 0.34, 0.34, 0.34, 1 })
        SafeShow(line)
    end
end

function Appearance:GetAccentColor(context)
    if context and context.facade and type(context.facade.GetAccentColor) == "function" then
        local ok, r, g, b = pcall(context.facade.GetAccentColor)
        local color = ok and ReadColor({ r, g, b, 1 }, 1)
        if color then return color[1], color[2], color[3] end
    end
    local color = context and context.accent
    if color then return color[1], color[2], color[3] end
end

function Appearance:ApplyFont(fontString, context)
    if not fontString then return false end
    if type(fontString.GetFont) ~= "function" or type(fontString.SetFont) ~= "function" then return false end
    local state = FONT_STATES[fontString]
    if not state then
        local ok, path, size, flags = pcall(fontString.GetFont, fontString)
        if not ok or type(path) ~= "string" or type(size) ~= "number" then return false end
        state = { path = path, size = size, flags = flags or "" }
        if type(fontString.GetShadowOffset) == "function" then
            local shadowOK, x, y = pcall(fontString.GetShadowOffset, fontString)
            if shadowOK then state.shadowX, state.shadowY = x, y end
        end
        if type(fontString.GetShadowColor) == "function" then
            local shadowOK, r, g, b, a = pcall(fontString.GetShadowColor, fontString)
            if shadowOK then state.shadowColor = { r, g, b, a } end
        end
        FONT_STATES[fontString] = state
    end

    local officialFontFailed = false
    if context and context.facade and type(context.facade.Font) == "function" then
        local ok, applied = pcall(context.facade.Font, fontString)
        if ok and applied ~= false then return true end
        officialFontFailed = true
    end

    local fontPath = context and context.fontPath or state.path
    local fontFlags = context and type(context.fontFlags) == "string" and context.fontFlags or state.flags
    local setOK, applied = pcall(fontString.SetFont, fontString, fontPath, state.size, fontFlags)
    if not setOK or applied == false then return false end
    if context and context.useShadow == true then
        if type(fontString.SetShadowColor) == "function" then
            pcall(fontString.SetShadowColor, fontString, 0, 0, 0, 0.6)
        end
        if type(fontString.SetShadowOffset) == "function" then
            pcall(fontString.SetShadowOffset, fontString, 1, -1)
        end
    elseif context and context.useShadow == false then
        if type(fontString.SetShadowColor) == "function" then
            pcall(fontString.SetShadowColor, fontString, 0, 0, 0, 0)
        end
        if type(fontString.SetShadowOffset) == "function" then
            pcall(fontString.SetShadowOffset, fontString, 0, 0)
        end
    elseif state.shadowColor then
        if type(fontString.SetShadowColor) == "function" then
            pcall(fontString.SetShadowColor, fontString, unpack(state.shadowColor))
        end
        if state.shadowX and state.shadowY and type(fontString.SetShadowOffset) == "function" then
            pcall(fontString.SetShadowOffset, fontString, state.shadowX, state.shadowY)
        end
    end
    return not officialFontFailed and context and (context.fontPath ~= nil or context.facade ~= nil) or false
end

function Appearance:ApplyAccent(region, context)
    local r, g, b = self:GetAccentColor(context)
    if not region or not r or type(region.SetTextColor) ~= "function" then return false end
    local ok, applied = pcall(region.SetTextColor, region, r, g, b, 1)
    return ok and applied ~= false
end

local function ApplyResolvedShell(self, frame, state, context, themeStyle)
    ClearOfficialShell(frame, state, context)
    ClearNDuiShell(frame, state, context)
    HideShell(state)

    if context.source == "ellesmere" and context.facade and context.customShell ~= true then
        if ApplyOfficialShell(frame, state, context) then
            ApplyCleanBorderAtlas(frame, state, context)
            return context
        end
        context = self:Resolve(themeStyle, { skip = { ellesmere = true } })
    end

    if context.source == "ndui" then
        if ApplyNDuiShell(frame, state, context) then
            ApplyCleanBorderAtlas(frame, state, context)
            return context
        end
        context = self:Resolve(themeStyle, { skip = { ndui = true } })
    end

    if context.source == "native" then
        local role = state.options.role
        if role == "editor" or role == "item-editor" or role == "dialog" then
            ApplyUniformNativeShell(state)
        else
            local native = CreateNativeShell(frame, state)
            if native then
                SafeShow(state.nativeClip)
                SafeShow(native)
            else
                context = DarkContext("native-shell-unavailable")
                ApplyCustomShell(frame, state, context)
            end
        end
    else
        ApplyCustomShell(frame, state, context)
    end
    ApplyCleanBorderAtlas(frame, state, context)
    return context
end

function Appearance:Refresh(frame)
    local state = FRAME_STATES[frame]
    if not state then return nil end
    local themeStyle = "auto"
    if type(state.options.themeProvider) == "function" then
        local ok, value = pcall(state.options.themeProvider)
        if ok and (value == "auto" or value == "native" or value == "dark") then themeStyle = value end
    end
    local context = self:Resolve(themeStyle)
    context = ApplyResolvedShell(self, frame, state, context, themeStyle)
    state.context = context

    for _, heading in ipairs(state.options.headings or {}) do
        self:ApplyFont(heading, context)
        if not self:ApplyAccent(heading, context) and GUI2 and type(GUI2.SetTextColorKey) == "function" then
            GUI2:SetTextColorKey(heading, "color.text.accent")
        end
    end
    if type(state.options.onRefresh) == "function" then
        pcall(state.options.onRefresh, frame, context)
    end
    return context
end

function Appearance:GetContext(frame)
    local state = FRAME_STATES[frame]
    return state and state.context or nil
end

function Appearance:RefreshAll()
    if self._refreshing then
        self._refreshQueued = true
        return
    end
    self._refreshing = true
    repeat
        self._refreshQueued = false
        for frame in pairs(REGISTERED_FRAMES) do
            if FRAME_STATES[frame] then
                self:Refresh(frame)
            end
        end
        for owner, callback in pairs(EXTERNAL_CONSUMERS) do
            if type(callback) == "function" then
                pcall(callback, self, owner)
            end
        end
    until not self._refreshQueued
    self._refreshing = false
end

function Appearance:Register(frame, options)
    if not frame then return nil end
    local state = EnsureState(frame)
    REGISTERED_FRAMES[frame] = true
    options = options or {}
    state.options = {
        themeProvider = options.themeProvider,
        headings = options.headings or (options.heading and { options.heading }) or {},
        role = options.role,
        onRefresh = options.onRefresh,
    }
    if not state.onShowHooked and type(frame.HookScript) == "function" then
        state.onShowHooked = true
        frame:HookScript("OnShow", function(owner) Appearance:Refresh(owner) end)
    end
    return self:Refresh(frame)
end

function Appearance:RegisterConsumer(owner, callback)
    if not owner or type(callback) ~= "function" then return false end
    EXTERNAL_CONSUMERS[owner] = callback
    return true
end

function Appearance:UnregisterConsumer(owner)
    if owner then EXTERNAL_CONSUMERS[owner] = nil end
end

function Appearance:ApplyExternalShell(frame, context)
    if not frame or not context then return false end
    local state = EXTERNAL_SHELL_STATES[frame] or EnsureState(frame)
    EXTERNAL_SHELL_STATES[frame] = state

    if context.source == "ellesmere" and context.facade and context.customShell ~= true then
        HideShell(state)
        ClearNDuiShell(frame, state, context)
        ClearOfficialShell(frame, state, context)
        local applied = ApplyOfficialShell(frame, state, context)
        if applied then ApplyCleanBorderAtlas(frame, state, context) end
        return applied
    end

    if context.source == "ellesmere" and context.customShell == true then
        ClearOfficialShell(frame, state, context)
        ClearNDuiShell(frame, state, context)
        HideShell(state)
        ApplyCustomShell(frame, state, context)
        ApplyCleanBorderAtlas(frame, state, context)
        return true, state.background
    end

    if context.source == "ndui" then
        HideShell(state)
        ClearOfficialShell(frame, state, context)
        local applied = ApplyNDuiShell(frame, state, context)
        ApplyCleanBorderAtlas(frame, state, context)
        return applied, applied and state.nduiBg or nil
    end

    ClearOfficialShell(frame, state)
    ClearNDuiShell(frame, state)
    RestoreCleanBorderAtlas(state)
    return false
end

function Appearance:ReleaseExternalShell(frame)
    local state = frame and EXTERNAL_SHELL_STATES[frame]
    if not state then return end
    RestoreCleanBorderAtlas(state)
    ClearOfficialShell(frame, state)
    ClearNDuiShell(frame, state)
    HideShell(state)
    EXTERNAL_SHELL_STATES[frame] = nil
end

function Appearance:IsDark(context)
    return context and context.source ~= "native"
end

local function OnAppearanceEvent(event, addonName)
    if event == "ADDON_LOADED" and (
        addonName == "EllesmereUI"
        or addonName == "EllesmereUIBlizzardSkin"
        or addonName == "ElvUI"
        or addonName == "NDui"
    ) then
        if not official.accepted then official.attempted = false end
    end
    Appearance:RefreshAll()
end

if YUI.Event and type(YUI.Event.On) == "function" then
    YUI.Event:On("ADDON_LOADED", OnAppearanceEvent, appearanceEventOwner)
    YUI.Event:On("YUI_APPEARANCE_SKIN_OPTION_CHANGED", OnAppearanceEvent, appearanceEventOwner)
end

if type(hooksecurefunc) == "function" and GUI2 and type(GUI2.SetPreset) == "function" then
    pcall(hooksecurefunc, GUI2, "SetPreset", function()
        Appearance:RefreshAll()
    end)
end

return Appearance
