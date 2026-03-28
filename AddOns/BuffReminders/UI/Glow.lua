local _, BR = ...

-- ============================================================================
-- GLOW MODULE
-- ============================================================================
-- Shared glow primitives for expiration warnings and consumable rebuff borders.
-- Uses LibCustomGlow for Pixel/AutoCast effects and a custom pulsing border.

local LCG = LibStub("LibCustomGlow-1.0")

BR.Glow = {}

BR.Glow.Type = {
    Pixel = 1,
    AutoCast = 2,
    Border = 3,
    Proc = 4,
}

local GlowType = BR.Glow.Type

-- Default glow color (yellow, matches LibCustomGlow default)
BR.Glow.DEFAULT_COLOR = { 0.95, 0.95, 0.32, 1 }

-- ============================================================================
-- PULSING BORDER (shared primitive)
-- ============================================================================
-- Creates a 4-edge colored border with a bounce alpha animation.
-- Multiple independent borders per frame are supported via the `key` parameter,
-- which namespaces the state stored on the frame.

---@param frame table
---@param key string Unique key to namespace this border's state on the frame
---@param color number[]|nil {r, g, b [, a]} or nil for default color
---@param thickness? number Border thickness in pixels (default 2)
---@param xOffset? number Extra horizontal outward offset (default 0)
---@param yOffset? number Extra vertical outward offset (default 0)
---@param animDuration? number Pulse animation duration in seconds (default 0.6)
function BR.Glow.PulsingBorderStart(frame, key, color, thickness, xOffset, yOffset, animDuration)
    color = color or BR.Glow.DEFAULT_COLOR
    local cr, cg, cb, ca = color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
    local stateKey = "_pulsingBorder_" .. key
    local state = frame[stateKey]
    thickness = thickness or 2
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    animDuration = animDuration or 0.6

    if not state then
        local holder = CreateFrame("Frame", nil, frame)
        holder:SetPoint("TOPLEFT", -xOffset, yOffset)
        holder:SetPoint("BOTTOMRIGHT", xOffset, -yOffset)
        holder:SetFrameLevel(frame:GetFrameLevel() + 5)
        local t = holder:CreateTexture(nil, "OVERLAY")
        t:SetPoint("TOPLEFT")
        t:SetPoint("TOPRIGHT")
        t:SetHeight(thickness)
        t:SetColorTexture(cr, cg, cb, ca)
        local b = holder:CreateTexture(nil, "OVERLAY")
        b:SetPoint("BOTTOMLEFT")
        b:SetPoint("BOTTOMRIGHT")
        b:SetHeight(thickness)
        b:SetColorTexture(cr, cg, cb, ca)
        local l = holder:CreateTexture(nil, "OVERLAY")
        l:SetPoint("TOPLEFT")
        l:SetPoint("BOTTOMLEFT")
        l:SetWidth(thickness)
        l:SetColorTexture(cr, cg, cb, ca)
        local r = holder:CreateTexture(nil, "OVERLAY")
        r:SetPoint("TOPRIGHT")
        r:SetPoint("BOTTOMRIGHT")
        r:SetWidth(thickness)
        r:SetColorTexture(cr, cg, cb, ca)
        local ag = holder:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.3)
        fade:SetDuration(animDuration)
        fade:SetSmoothing("IN_OUT")
        state = {
            holder = holder,
            anim = ag,
            fade = fade,
            edges = { t, b, l, r },
            color = { cr, cg, cb, ca },
            thickness = thickness,
            xOffset = xOffset,
            yOffset = yOffset,
            animDuration = animDuration,
        }
        frame[stateKey] = state
    else
        local prev = state.color
        if prev[1] ~= cr or prev[2] ~= cg or prev[3] ~= cb or prev[4] ~= ca then
            for _, edge in ipairs(state.edges) do
                edge:SetColorTexture(cr, cg, cb, ca)
            end
            state.color = { cr, cg, cb, ca }
        end
        if state.thickness ~= thickness or state.xOffset ~= xOffset or state.yOffset ~= yOffset then
            state.holder:SetPoint("TOPLEFT", -xOffset, yOffset)
            state.holder:SetPoint("BOTTOMRIGHT", xOffset, -yOffset)
            state.edges[1]:SetHeight(thickness) -- top
            state.edges[2]:SetHeight(thickness) -- bottom
            state.edges[3]:SetWidth(thickness) -- left
            state.edges[4]:SetWidth(thickness) -- right
            state.thickness = thickness
            state.xOffset = xOffset
            state.yOffset = yOffset
        end
        if state.animDuration ~= animDuration then
            state.fade:SetDuration(animDuration)
            state.animDuration = animDuration
            -- Restart animation with new duration
            state.anim:Stop()
            state.anim:Play()
        end
    end
    state.holder:Show()
    if not state.anim:IsPlaying() then
        state.anim:Play()
    end
end

---@param frame table
---@param key string Must match the key used in PulsingBorderStart
function BR.Glow.PulsingBorderStop(frame, key)
    local state = frame["_pulsingBorder_" .. key]
    if state then
        state.anim:Stop()
        state.holder:Hide()
    end
end

-- ============================================================================
-- GLOW TYPES (Pixel, AutoCast, Border)
-- ============================================================================

BR.Glow.Types = {
    { name = "像素" },
    { name = "自動施放" },
    { name = "外框" },
    { name = "觸發" },
}

local GLOW_START = {
    function(f, color, key, size, xOff, yOff, params)
        local p = params or {}
        LCG.PixelGlow_Start(f, color, p.lines, p.frequency, p.length or 10, size, xOff, yOff, false, key)
    end,
    function(f, color, key, size, xOff, yOff, params)
        local p = params or {}
        LCG.AutoCastGlow_Start(f, color, p.particles, p.frequency, p.scale or (size / 2), xOff, yOff, key)
    end,
    function(f, color, key, size, xOff, yOff, params)
        local p = params or {}
        BR.Glow.PulsingBorderStart(f, key, color, size, xOff, yOff, p.frequency)
    end,
    function(f, color, key, _, xOff, yOff, params)
        local p = params or {}
        LCG.ProcGlow_Start(f, {
            color = color,
            key = key,
            duration = p.duration or 1,
            startAnim = p.startAnim or false,
            xOffset = xOff,
            yOffset = yOff,
        })
    end,
}

local GLOW_STOP = {
    LCG.PixelGlow_Stop,
    LCG.AutoCastGlow_Stop,
    BR.Glow.PulsingBorderStop,
    LCG.ProcGlow_Stop,
}

---Start a glow by type index
---@param frame table
---@param typeIndex number BR.Glow.Type value (Pixel, AutoCast, Border, Proc)
---@param color number[]|nil {r, g, b, a} or nil for native library color
---@param key string Unique key for this glow instance
---@param size? number Glow thickness/scale (default 2)
---@param xOffset? number Extra horizontal outward offset (default 0)
---@param yOffset? number Extra vertical outward offset (default 0)
---@param params? table Advanced glow params (type-specific: lines, frequency, length, particles, scale, duration, startAnim)
function BR.Glow.Start(frame, typeIndex, color, key, size, xOffset, yOffset, params)
    size = size or 2
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    local fn = GLOW_START[typeIndex]
    if fn then
        fn(frame, color, key, size, xOffset, yOffset, params)
    end
end

---Stop a specific glow type on a frame
---@param frame table
---@param typeIndex number BR.Glow.Type value (Pixel, AutoCast, Border, Proc)
---@param key string Must match the key used in Start
function BR.Glow.Stop(frame, typeIndex, key)
    local fn = GLOW_STOP[typeIndex]
    if fn then
        fn(frame, key)
    end
end

---Stop all glow types on a frame for a given key (use when the active type is unknown)
---@param frame table
---@param key string Must match the key used in Start
function BR.Glow.StopAll(frame, key)
    LCG.PixelGlow_Stop(frame, key)
    LCG.AutoCastGlow_Stop(frame, key)
    BR.Glow.PulsingBorderStop(frame, key)
    LCG.ProcGlow_Stop(frame, key)
end

-- ============================================================================
-- HIGH-LEVEL GLOW FUNCTIONS
-- ============================================================================

local EXPIRATION_KEY = "BR_expiration"

-- Per-frame glow state key (avoids polluting frame namespace with multiple keys)
local GLOW_STATE_KEY = "_brGlowState"

---Compare two color tables {r, g, b, a} for equality
---@param a number[]|nil
---@param b number[]|nil
---@return boolean
local function ColorsEqual(a, b)
    if a == b then
        return true
    end
    if not a or not b then
        return false
    end
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

---Shallow-compare two tables (or nil) for key/value equality
---@param a table|nil
---@param b table|nil
---@return boolean
local function ShallowEqual(a, b)
    if a == b then
        return true
    end
    if not a or not b then
        return false
    end
    for k, v in pairs(a) do
        if b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

---Build advanced glow params table from a settings table.
---Accepts both short names (pixelLines) and glow-prefixed names (glowPixelLines).
---@param t table Settings table (cached glow settings or db.defaults)
---@param typeIndex number Current glow type index
---@return table? params Advanced params or nil if all defaults
function BR.Glow.BuildAdvancedParams(t, typeIndex)
    if typeIndex == GlowType.Pixel then
        local lines = t.pixelLines or t.glowPixelLines
        local freq = t.pixelFrequency or t.glowPixelFrequency
        local len = t.pixelLength or t.glowPixelLength
        if lines or freq or len then
            return { lines = lines, frequency = freq, length = len }
        end
    elseif typeIndex == GlowType.AutoCast then
        local particles = t.autocastParticles or t.glowAutocastParticles
        local freq = t.autocastFrequency or t.glowAutocastFrequency
        local scale = t.autocastScale or t.glowAutocastScale
        if particles or freq or scale then
            return { particles = particles, frequency = freq, scale = scale }
        end
    elseif typeIndex == GlowType.Border then
        local freq = t.borderFrequency or t.glowBorderFrequency
        if freq then
            return { frequency = freq }
        end
    elseif typeIndex == GlowType.Proc then
        local dur = t.procDuration or t.glowProcDuration
        local startAnim = t.procStartAnim
        if startAnim == nil then
            startAnim = t.glowProcStartAnim
        end
        if dur or startAnim then
            return { duration = dur, startAnim = startAnim }
        end
    end
    return nil
end

---Show/hide expiration glow on a buff frame (reads type + color from DB or cached settings)
---@param frame table
---@param show boolean
---@param category? string Category name for per-category glow settings (nil = use global defaults)
---@param cachedSettings? table Pre-fetched glow settings to avoid DB reads
function BR.Glow.SetExpiration(frame, show, category, cachedSettings)
    local state = frame[GLOW_STATE_KEY]

    if show then
        local typeIndex, color, size, borderOffset, params, glowXOff, glowYOff
        if cachedSettings then
            typeIndex = cachedSettings.typeIndex
            color = cachedSettings.color
            size = cachedSettings.size
            borderOffset = cachedSettings.borderSize or BR.DEFAULT_BORDER_SIZE
            params = cachedSettings.params
            glowXOff = cachedSettings.glowXOffset or 0
            glowYOff = cachedSettings.glowYOffset or 0
        else
            local db = BR.profile
            local d = db and db.defaults or {}
            typeIndex = d.glowType or GlowType.Pixel
            color = d.glowColor
            if typeIndex == GlowType.Proc and not d.glowProcUseCustomColor then
                color = nil
            end
            size = d.glowSize or 2
            borderOffset = (category and BR.Config.GetCategorySetting(category, "borderSize"))
                or d.borderSize
                or BR.DEFAULT_BORDER_SIZE
            params = BR.Glow.BuildAdvancedParams(d, typeIndex)
            glowXOff = d.glowXOffset or 0
            glowYOff = d.glowYOffset or 0
        end

        local xOff = borderOffset + glowXOff
        local yOff = borderOffset + glowYOff

        -- Already glowing with the same type, size, color, and offsets — don't restart (preserves animation state)
        if
            state
            and state.showing
            and state.typeIndex == typeIndex
            and state.size == size
            and state.xOff == xOff
            and state.yOff == yOff
            and ColorsEqual(state.color, color)
            and ShallowEqual(state.params, params)
        then
            return
        end

        -- Stop previous glow if any parameter changed
        if state and state.showing then
            BR.Glow.Stop(frame, state.typeIndex, EXPIRATION_KEY)
        end

        BR.Glow.Start(frame, typeIndex, color, EXPIRATION_KEY, size, xOff, yOff, params)
        frame[GLOW_STATE_KEY] = {
            showing = true,
            typeIndex = typeIndex,
            size = size,
            color = color,
            xOff = xOff,
            yOff = yOff,
            params = params,
        }
    else
        if state and state.showing then
            BR.Glow.Stop(frame, state.typeIndex, EXPIRATION_KEY)
            state.showing = false
        end
    end
end
