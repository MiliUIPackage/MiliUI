local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_C = CDM and CDM.CONST or {}
local Snap = CDM.Pixel.Snap

CDM.CustomBuffs = {
    activeBuffs = {},       -- [spellID] = { expires, frame, startTime, duration }
    activeBuffVersion = 0,
    iconFrames = {},        -- [spellID] = frame
    framePool = {},         -- reusable, inactive custom buff frames
    -- MiliUI: 光環格（kind = "aura"）的執行期狀態，見檔案後半「光環格」一節
    auraSlots = {},         -- [spellID] = holder（目前在版面上的持有框）
    auraSoundIDs = {},      -- [spellID] = { added = id, removed = id, addedName, removedName }
    auraSlotErrors = {},    -- 暴雪 API 回的錯誤全文（最近 20 筆），實機驗證用 /dump 看
}

local CB = CDM.CustomBuffs
local VIEWERS = CDM_C.VIEWERS

local GetTime = GetTime
local GetPlayerAuraBySpellID = C_UnitAuras.GetPlayerAuraBySpellID
local GetSpellTexture = C_Spell.GetSpellTexture

local EMPTY_ORDER = {}

-- MiliUI: 光環格項目（引擎依法術 ID 畫的常駐格），跟施法計時項目共用註冊表
local function IsAuraEntry(entry)
    return type(entry) == "table" and entry.kind == "aura"
end
CDM.IsAuraCustomBuffEntry = IsAuraEntry
local ungroupedSeenScratch = {}

local TIME_SPIRAL_TRIGGERS = {
    [48265]  = true,  -- Death's Advance
    [195072] = true,  -- Fel Rush
    [189110] = true,  -- Infernal Strike
    [1850]   = true,  -- Dash
    [252216] = true,  -- Tiger Dash
    [358267] = true,  -- Hover
    [186257] = true,  -- Aspect of the Cheetah
    [1953]   = true,  -- Blink
    [212653] = true,  -- Shimmer
    [361138] = true,  -- Roll
    [119085] = true,  -- Chi Torpedo
    [190784] = true,  -- Divine Steed
    [73325]  = true,  -- Leap of Faith
    [2983]   = true,  -- Sprint
    [192063] = true,  -- Gust of Wind
    [58875]  = true,  -- Spirit Walk
    [79206]  = true,  -- Spiritwalker's Grace
    [48020]  = true,  -- Demonic Circle: Teleport
    [6544]   = true,  -- Heroic Leap
}

local TIME_SPIRAL_GLOW_FILTERS = {
    { talentID = 427640, spells = {198793, 370965, 195072} },  -- Inertia → Vengeful Retreat, The Hunt, Fel Rush
    { talentID = 427794, spells = {195072} },                  -- Dash of Chaos → Fel Rush
    { talentID = 385899, spells = {385899} },                  -- Soulburn
}

local glowSuppressSpells = {}
local suppressGlowUntil = 0

local BLOODLUST_DEBUFFS = {
    [57723]  = 32182,   -- Exhaustion → Heroism
    [57724]  = 2825,    -- Sated → Bloodlust
    [80354]  = 80353,   -- Temporal Displacement → Time Warp
    [95809]  = 90355,   -- Insanity → Ancient Hysteria
    [160455] = 264667,  -- Fatigued → Primal Rage
    [264689] = 264667,  -- Fatigued → Primal Rage
    [390435] = 390386,  -- Exhaustion → Fury of the Aspects
}

function CDM:RebuildGlowFilters()
    table.wipe(glowSuppressSpells)
    for _, entry in ipairs(TIME_SPIRAL_GLOW_FILTERS) do
        if IsPlayerSpell(entry.talentID) then
            for _, spellID in ipairs(entry.spells) do
                glowSuppressSpells[spellID] = true
            end
        end
    end
end

local cachedCustomBuffStyles = {
    fontPath = nil,
    fontOutline = nil,
    fontSize = 12,
    fontColor = nil,
}

local function RefreshCachedCustomBuffStyles()
    local db = CDM.db
    local defaults = CDM.defaults or {}

    CDM_C.RefreshBaseFontCache()
    cachedCustomBuffStyles.fontPath = CDM_C.GetBaseFontPath()
    cachedCustomBuffStyles.fontOutline = CDM_C.GetBaseFontOutline()
    cachedCustomBuffStyles.fontSize = db and db.buffCooldownFontSize or defaults.buffCooldownFontSize or 12
    cachedCustomBuffStyles.fontColor = (db and db.buffCooldownColor) or defaults.buffCooldownColor or CDM_C.WHITE
end

CDM.RefreshCachedCustomBuffStyles = RefreshCachedCustomBuffStyles

local function SetupCustomBuffCooldownTextLayout(frame)
    if not frame or not frame.Cooldown then return end

    local text = frame.Cooldown.Text or frame.Cooldown.text
    if not text or not text.SetFont then return end
    text:SetIgnoreParentScale(true)
    text:ClearAllPoints()
    text:SetPoint("CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetShadowOffset(0, 0)
    text:SetDrawLayer("OVERLAY", 7)
end

local function IsGroupedCustomBuff(spellID)
    local sets = CDM.BuffGroupSets
    local grouped = sets and sets.grouped
    return grouped and grouped[spellID] and true or false
end

local function ApplyCustomBuffCooldownTextStyle(frame)
    if not frame or not frame.Cooldown then return end
    if not cachedCustomBuffStyles.fontPath then
        RefreshCachedCustomBuffStyles()
    end

    local text = frame.Cooldown.Text or frame.Cooldown.text
    if not text or not text.SetFont then return end
    local fontColor = cachedCustomBuffStyles.fontColor or CDM_C.WHITE
    text:SetFont(
        cachedCustomBuffStyles.fontPath,
        CDM.Pixel.FontSize(cachedCustomBuffStyles.fontSize),
        cachedCustomBuffStyles.fontOutline
    )
    text:SetTextColor(fontColor.r, fontColor.g, fontColor.b, fontColor.a or 1)
end

local function ReanchorBuffViewer()
    local v = _G[VIEWERS.BUFF]
    if v then CDM:ForceReanchor(v) end
end

function CDM:GetCustomBuffEffectiveSize(spellID)
    local sets = self.BuffGroupSets
    local grouped = sets and sets.grouped
    local groupIdx = spellID and grouped and grouped[spellID]
    local groupData = groupIdx and sets.groups and sets.groups[groupIdx]
    if groupData then
        return Snap(groupData.iconWidth or 30), Snap(groupData.iconHeight or 30)
    end
    local defaults = self.defaults or {}
    local defaultSize = defaults.sizeBuff or { w = 32, h = 32 }
    local dbSize = self.db and self.db.sizeBuff
    return (dbSize and dbSize.w) or defaultSize.w, (dbSize and dbSize.h) or defaultSize.h
end

local function CreateCustomBuffIcon(spellID, config)
    if CB.iconFrames[spellID] then
        return CB.iconFrames[spellID]
    end

    local w, h = CDM:GetCustomBuffEffectiveSize(spellID)

    local frame = table.remove(CB.framePool)
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)

        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        CDM.Pixel.DisableTextureSnap(icon)
        frame.Icon = icon

        local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawSwipe(not (CDM.db and CDM.db.hideBuffSwipe))
        cooldown:SetSwipeColor(CDM_C.SWIPE_COLOR.r, CDM_C.SWIPE_COLOR.g, CDM_C.SWIPE_COLOR.b, CDM_C.SWIPE_COLOR.a)
        cooldown:SetReverse(true)  -- Fill up as time passes (like a buff)
        frame.Cooldown = cooldown
        SetupCustomBuffCooldownTextLayout(frame)

        if CDM.BORDER and CDM.BORDER.CreateBorder then
            frame.cdmBorder = CDM.BORDER:CreateBorder(frame)
        end
    end

    frame:SetSize(w, h)
    frame.spellID = spellID
    frame.isCustomBuff = true
    frame.customBuffStartTime = nil

    if frame.Icon then
        frame.Icon:SetAllPoints()
        CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), w, h)
        frame.Icon:SetTexture(config.icon)
        frame.Icon:SetDesaturation(0)
    end

    if frame.Cooldown then
        frame.Cooldown:SetAllPoints()
        frame.Cooldown:SetDrawBling(not (CDM.db and CDM.db.hideCooldownBling))
        frame.Cooldown:SetScript("OnCooldownDone", nil)
    end

    frame:Hide()

    CB.iconFrames[spellID] = frame

    return frame
end

local DeactivateCustomBuff

local function ActivateCustomBuff(spellID, config, overrideStartTime)
    local frame = CreateCustomBuffIcon(spellID, config)

    local startTime = overrideStartTime or GetTime()
    local duration = config.duration

    if not frame.cdmDurationObj then
        frame.cdmDurationObj = C_DurationUtil.CreateDuration()
    end
    frame.cdmDurationObj:SetTimeFromStart(startTime, duration)
    frame.Cooldown:SetCooldownFromDurationObject(frame.cdmDurationObj)
    frame.Cooldown:SetScript("OnCooldownDone", function()
        DeactivateCustomBuff(spellID)
    end)
    if not IsGroupedCustomBuff(spellID) then
        ApplyCustomBuffCooldownTextStyle(frame)
    end

    CB.activeBuffs[spellID] = {
        expires = startTime + duration,
        frame = frame,
        startTime = startTime,
        duration = duration,
    }
    CB.activeBuffVersion = (CB.activeBuffVersion or 0) + 1

    frame.customBuffStartTime = startTime

    frame:Show()
    ReanchorBuffViewer()

    if CDM.PlayCustomBuffNotification then
        CDM:PlayCustomBuffNotification(spellID, false)
    end
end

DeactivateCustomBuff = function(spellID)
    local buffData = CB.activeBuffs[spellID]
    if not buffData then return end

    if CDM.PlayCustomBuffNotification then
        CDM:PlayCustomBuffNotification(spellID, true)
    end

    if buffData.frame then
        if buffData.frame.Cooldown then
            buffData.frame.Cooldown:SetScript("OnCooldownDone", nil)
        end
        buffData.frame:Hide()
    end

    CB.activeBuffs[spellID] = nil
    CB.activeBuffVersion = (CB.activeBuffVersion or 0) + 1
    ReanchorBuffViewer()
end

local function OnSpellCastSucceeded(event, unit, castGUID, spellID)
    local config = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[spellID]
    if not config or config.triggerType then return end
    -- MiliUI: 光環格沒有持續時間，不走施法計時
    if IsAuraEntry(config) then return end

    ActivateCustomBuff(spellID, config)
end

local function OnSpellCastSent(event, unit, target, castGUID, spellID)
    if not CDM.IsSafeNumber(spellID) then return end
    if not glowSuppressSpells[spellID] then return end
    suppressGlowUntil = GetTime() + 1.5
end

local function OnGlowShow(event, spellID)
    if not CDM.IsSafeNumber(spellID) then return end
    if not TIME_SPIRAL_TRIGGERS[spellID] then return end
    if GetTime() < suppressGlowUntil then return end
    local config = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[374968]
    if not config or IsAuraEntry(config) then return end  -- MiliUI: 光環格不走施法計時
    if CB.activeBuffs[374968] then return end
    ActivateCustomBuff(374968, config)
end

local function OnGlowHide(event, spellID)
    if not CDM.IsSafeNumber(spellID) then return end
    if not TIME_SPIRAL_TRIGGERS[spellID] then return end
    if not CB.activeBuffs[374968] then return end
    DeactivateCustomBuff(374968)
end

local bloodlustDebuffInstanceID

local function ActivateBloodlustFromDebuff(aura, lustBuffID, requireWithinWindow)
    local config = CDM.db.customBuffRegistry and CDM.db.customBuffRegistry[2825]
    if not config or IsAuraEntry(config) then return end  -- MiliUI: 光環格不走施法計時
    if CB.activeBuffs[2825] then return end

    local dur = aura.duration
    if not dur or dur <= 0 then dur = 600 end
    local appliedTime = aura.expirationTime - dur

    if requireWithinWindow and (GetTime() - appliedTime) >= 40 then return end

    ActivateCustomBuff(2825, config, appliedTime)
    local frame = CB.iconFrames[2825]
    if frame and frame.Icon then
        frame.Icon:SetTexture(GetSpellTexture(lustBuffID))
    end
end

local function SeedBloodlust()
    bloodlustDebuffInstanceID = nil
    for debuffID, lustBuffID in pairs(BLOODLUST_DEBUFFS) do
        local aura = GetPlayerAuraBySpellID(debuffID)
        if aura and aura.auraInstanceID and aura.expirationTime then
            bloodlustDebuffInstanceID = aura.auraInstanceID
            ActivateBloodlustFromDebuff(aura, lustBuffID, true)
            return
        end
    end
end

local function OnBloodlustAura(event, unit, info)
    -- 12.1: bail to a spell-ID re-seed when the payload is secret and cannot be diffed
    if not CDM.CanDiffAuraPayload(info) or info.isFullUpdate then
        SeedBloodlust()
        return
    end
    if info.addedAuras then
        for _, aura in ipairs(info.addedAuras) do
            local sid = aura.spellId
            if CDM.IsSafeNumber(sid) then
                local lustBuffID = BLOODLUST_DEBUFFS[sid]
                if lustBuffID and aura.auraInstanceID and aura.expirationTime then
                    bloodlustDebuffInstanceID = aura.auraInstanceID
                    ActivateBloodlustFromDebuff(aura, lustBuffID, false)
                    break
                end
            end
        end
    end
    if bloodlustDebuffInstanceID and info.removedAuraInstanceIDs then
        for _, id in ipairs(info.removedAuraInstanceIDs) do
            if id == bloodlustDebuffInstanceID then
                bloodlustDebuffInstanceID = nil
                break
            end
        end
    end
end

------------------------------------------------------------
-- MiliUI: 光環格（customBuffRegistry 裡 kind = "aura" 的項目）
--
-- 玩家給一個法術 ID，這裡在增益列（或增益群組）佔一格常駐的「持有框」，
-- 光環在身上時由暴雪的 AuraContainer／AuraButton 自己畫圖示、掃描、倒數、層數。
-- 12.1 光環資料在戰鬥／首領戰／M+ 是秘密值，插件端讀不到有沒有、剩幾秒、幾層，
-- 所以這裡**一次都不讀**，全部交給引擎。代價都是這個做法的必然結果：
--   * 格位固定：讀不到「按鈕現在顯不顯示」，不能依有無收合、不能置中補位。
--     不在身上時顯示的去飽和占位圖示畫在持有框上、壓在按鈕底下，按鈕出現就自然蓋住。
--   * 樣式只能在 initializeFrame 裡做，之後整棵子樹 forbidden ⇒ 影響外觀的設定一變
--     就換一顆新容器（簽章比對）。暴雪 frame 刪不掉，所以舊容器留在持有框自己的池裡，
--     同一個簽章回來時直接重用。持有框本身一個法術 ID 一顆、永不改作他用。
--   * 對容器下 Hide／Show、或藏／顯示它的祖先（持有框），戰鬥中會跳封鎖視窗
--     （容器的 OnShow／OnHide 會重做事件註冊）⇒ 持有框的顯示切換一律戰鬥外做，
--     戰鬥中只記下來，脫戰再補。
--   * AddAuraSlot 的按鈕不參與容器的 flow layout（只有 AddAuraGroup 的會），所以在
--     initializeFrame 裡自己 SetAllPoints 到容器上。
------------------------------------------------------------
local AuraSlots = {}
CB.AuraSlots = AuraSlots

local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local AURA_SLOT_KEY = "cdm"
-- 持有框之上的相對層級：按鈕 +1、掃描 +2、邊框 +4（Style.lua 會照這個抬）、文字 +5。
-- 邊框要壓過掃描、文字要壓過邊框；占位圖示畫在持有框本身（+0），被按鈕蓋住。
local LEVEL_BUTTON = 1
local LEVEL_SWIPE = 2
local LEVEL_BORDER = 4
local LEVEL_TEXT = 5
CB.AURA_SLOT_BORDER_LEVEL = LEVEL_BORDER

local SWIPE_TEXTURE_ZOOMED = CDM_C.TEX_WHITE8X8 or "Interface\\Buttons\\WHITE8X8"
-- 跟 Core/Style.lua 的 DEFAULT_COOLDOWN_ICON_SWIPE_TEXTURE 同一張
local SWIPE_TEXTURE_DEFAULT = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"

local NEVER_SECRET = (Enum and Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret) or 0

-- 所有建過的持有框（[spellID] = holder），項目刪掉也留著，重新加回來時沿用。
local holderCache = {}
-- 戰鬥中不能做、等脫戰補做的事
local pendingBuild = {}         -- [spellID] = true：容器要建／換
local pendingVisibility = {}    -- [holder] = true / false
local pendingKick = {}          -- [holder] = true：容器要 Hide→Show→SetEnabled 補踢
local pendingClearPoints = {}   -- [holder] = true：收掉的持有框脫戰再拆錨點
local soundsDirty = false
-- 簽章變了先等一下再換：拖滑桿每一格都會刷新一次，每一格都換一顆刪不掉的容器太浪費
local REBUILD_DEBOUNCE = 0.4
local rebuildTimer = nil

local function RecordError(where, msg)
    local list = CB.auraSlotErrors
    list[#list + 1] = date("%H:%M:%S") .. " " .. tostring(where) .. ": " .. tostring(msg)
    while #list > 20 do table.remove(list, 1) end
end

-- 減益只有 NeverSecret 的法術能用法術 ID 過濾（引擎對自己身上的減益也一樣擋）。
-- 查不到（API 不在）就放行 —— 由設定介面在新增前擋，這裡只是保險。
function CDM:IsAuraSpellNeverSecret(spellID)
    if not (C_Secrets and C_Secrets.GetSpellAuraSecrecy) then return true end
    local ok, level = pcall(C_Secrets.GetSpellAuraSecrecy, spellID)
    if not ok or level == nil then return true end
    return level == NEVER_SECRET
end

local function ColorRGBA(c, dr, dg, db, da)
    if type(c) ~= "table" then return dr, dg, db, da end
    return c.r or dr, c.g or dg, c.b or db, c.a or da
end

------------------------------------------------------------
-- 簽章與烘焙樣式：所有在 initializeFrame 裡寫死的東西都在這裡
------------------------------------------------------------
local function ResolveTextSettings(spellID)
    local sc = CDM.styleCache or {}
    local sets = CDM.BuffGroupSets
    local groupIdx = sets and sets.grouped and sets.grouped[spellID]
    local gd = groupIdx and sets.groups and sets.groups[groupIdx]
    local t
    if gd then
        local ov = CDM:ResolveBuffOverrideEntry(gd.spellOverrides, spellID)
        t = (ov and ov.textOverride) and ov or nil
        return {
            cdSize = (t and t.cooldownFontSize) or gd.cooldownFontSize or 12,
            cdColor = (t and t.cooldownColor) or gd.cooldownColor,
            countSize = (t and t.countFontSize) or gd.countFontSize or 15,
            countColor = (t and t.countColor) or gd.countColor,
            countPos = (t and t.countPosition) or gd.countPosition or "BOTTOMRIGHT",
            countX = (t and t.countOffsetX) or gd.countOffsetX or 0,
            countY = (t and t.countOffsetY) or gd.countOffsetY or 0,
        }
    end
    local ov = CDM.GetUngroupedBuffOverride and CDM:GetUngroupedBuffOverride(spellID) or nil
    t = (ov and ov.textOverride) and ov or nil
    return {
        cdSize = (t and t.cooldownFontSize) or sc.buffCooldownFontSize or 12,
        cdColor = (t and t.cooldownColor) or sc.buffCooldownColor,
        countSize = (t and t.countFontSize) or sc.countFontSize or 12,
        countColor = (t and t.countColor) or sc.countColor,
        countPos = (t and t.countPosition) or sc.countPositionMain or "TOP",
        countX = (t and t.countOffsetX) or sc.countOffsetXMain or 0,
        countY = (t and t.countOffsetY) or sc.countOffsetYMain or 0,
    }
end

local function BuildAuraSlotStyle(spellID, entry, holder)
    if CDM.RefreshStyleCache then CDM.RefreshStyleCache() end
    local sc = CDM.styleCache or {}
    local Pixel = CDM.Pixel

    local w, h = CDM:GetCustomBuffEffectiveSize(spellID)
    w, h = Snap(w), Snap(h)
    local text = ResolveTextSettings(spellID)
    local swipe = sc.swipeColor or CDM_C.SWIPE_COLOR

    local s = {
        spellID = spellID,
        filter = (entry.auraFilter == "HARMFUL") and "HARMFUL" or "HELPFUL",
        w = w, h = h,
        zoom = CDM_C.GetEffectiveZoomAmount(),
        icon = GetSpellTexture(spellID) or entry.icon,
        level = holder:GetFrameLevel(),
        hideCooldownText = entry.hideCooldownText and true or false,
        fontPath = sc.fontPath or (CDM_C.GetBaseFontPath and CDM_C.GetBaseFontPath()),
        outline = sc.textFontOutline or "OUTLINE",
        cdSize = Pixel.FontSize(text.cdSize),
        countSize = Pixel.FontSize(text.countSize),
        countPos = text.countPos,
        countX = text.countX, countY = text.countY,
        drawSwipe = not sc.hideBuffSwipe,
        drawBling = not sc.hideCooldownBling,
        swipeTexture = sc.zoomIcons and SWIPE_TEXTURE_ZOOMED or SWIPE_TEXTURE_DEFAULT,
        -- ⚠ formatter 一定要在這裡（正常插件路徑）先取好：initializeFrame 跑在暴雪的
        -- frame 建立堆疊裡，那裡面建 formatter／CreateColor 會撞上污染存取限制
        formatter = CDM.CooldownFormatter and CDM.CooldownFormatter.GetForAuraText() or nil,
    }
    -- 顏色一律拆成純數字（initializeFrame 裡不碰任何色彩物件）
    s.cdR, s.cdG, s.cdB, s.cdA = ColorRGBA(text.cdColor, 1, 1, 1, 1)
    s.countR, s.countG, s.countB, s.countA = ColorRGBA(text.countColor, 1, 1, 1, 1)
    s.swipeR, s.swipeG, s.swipeB, s.swipeA = ColorRGBA(swipe, 0, 0, 0, 0.6)

    local signature = table.concat({
        spellID, s.filter, s.w, s.h, s.zoom, tostring(s.hideCooldownText), tostring(s.icon), s.level,
        tostring(s.fontPath), tostring(s.outline), s.cdSize, s.cdR, s.cdG, s.cdB, s.cdA,
        s.countSize, s.countR, s.countG, s.countB, s.countA, tostring(s.countPos), s.countX, s.countY,
        s.swipeR, s.swipeG, s.swipeB, s.swipeA, tostring(s.drawSwipe), tostring(s.drawBling), s.swipeTexture,
        -- formatter 的斷點也是烘死的（綁定當下拿的那顆）
        tostring(sc.cooldownDecimalThreshold), tostring(sc.cooldownColorThresholdEnabled),
        tostring(sc.cooldownColorThreshold), tostring(s.formatter),
    }, "|")
    return s, signature
end

------------------------------------------------------------
-- AuraButton 外觀：只在 initializeFrame 內跑（整段由呼叫端 xpcall 隔離）
--
-- 規矩：不讀按鈕任何屬性、不掛 script、不建動畫、不 CreateColor、不對光環資料做任何判斷。
-- 每個暴雪的綁定 API 各自 pcall：一支被鎖起來的代價是少一樣東西，不是後面全部沒建。
------------------------------------------------------------
local function InitAuraSlotButton(auraButton, s)
    pcall(auraButton.SetIgnoringChildrenForBounds, auraButton, true)
    -- 不擋滑鼠、不搶 @mouseover
    pcall(auraButton.EnableMouse, auraButton, false)
    pcall(auraButton.SetMouseClickEnabled, auraButton, false)
    pcall(auraButton.SetMouseMotionEnabled, auraButton, false)
    -- slot 按鈕不在 flow layout 裡，自己貼滿容器（容器又貼滿持有框）
    local okPoint, errPoint = pcall(function()
        auraButton:ClearAllPoints()
        auraButton:SetAllPoints(s.container)
    end)
    if not okPoint then RecordError("SetAllPoints", errPoint) end
    pcall(auraButton.SetFrameLevel, auraButton, s.level + LEVEL_BUTTON)

    -- 圖示：法術 ID 是明文，貼圖在容器建立前就查好了；靜態貼圖跟著按鈕一起顯示／隱藏
    local icon = auraButton:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(auraButton)
    if s.icon then icon:SetTexture(s.icon) end
    CDM_C.ApplyIconTexCoord(icon, s.zoom, s.w, s.h)
    CDM.Pixel.DisableTextureSnap(icon)

    -- 掃描（少了 CooldownFrameTemplate 不會動）
    local cd = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
    cd:SetAllPoints(auraButton)
    cd:SetFrameLevel(s.level + LEVEL_SWIPE)
    cd:SetReverse(true)   -- 跟施法計時的自訂增益一致：時間過去填滿
    cd:SetDrawEdge(false)
    cd:SetDrawBling(s.drawBling)
    cd:SetDrawSwipe(s.drawSwipe)
    cd:SetSwipeTexture(s.swipeTexture)
    cd:SetSwipeColor(s.swipeR, s.swipeG, s.swipeB, s.swipeA)
    cd:SetHideCountdownNumbers(true)
    local okCd, errCd = pcall(auraButton.SetDurationCooldown, auraButton, cd)
    if not okCd then RecordError("SetDurationCooldown", errCd) end

    -- 文字建在子框上，層級才壓得過掃描與邊框
    local textFrame = CreateFrame("Frame", nil, auraButton)
    textFrame:SetAllPoints(auraButton)
    textFrame:SetFrameLevel(s.level + LEVEL_TEXT)

    if not s.hideCooldownText then
        local fs = textFrame:CreateFontString(nil, "OVERLAY")
        fs:SetIgnoreParentScale(true)
        fs:SetFont(s.fontPath, s.cdSize, s.outline)
        fs:SetTextColor(s.cdR, s.cdG, s.cdB, s.cdA)
        fs:SetShadowOffset(0, 0)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetPoint("CENTER", auraButton, "CENTER", 0, 0)
        -- 主路徑帶 formatter；失敗退回不帶的。⚠ 備援也要 pcall：SetDurationText 內部
        -- 可能走到被污染時不給存取的表，備援裸呼叫一炸就把後面的層數也截掉
        local okText, errText = true, nil
        if s.formatter then
            okText, errText = pcall(auraButton.SetDurationText, auraButton, fs, { textFormatter = s.formatter })
        else
            okText = false
        end
        if not okText then
            if errText then RecordError("SetDurationText(options)", errText) end
            local okPlain, errPlain = pcall(auraButton.SetDurationText, auraButton, fs)
            if not okPlain then RecordError("SetDurationText", errPlain) end
        end
    end

    -- 層數：絕不傳 formatter（暴雪會在 Lua 端對秘密層數跑 FormatNumber，整個容器當掉）
    local count = textFrame:CreateFontString(nil, "OVERLAY")
    count:SetIgnoreParentScale(true)
    count:SetFont(s.fontPath, s.countSize, s.outline)
    count:SetTextColor(s.countR, s.countG, s.countB, s.countA)
    count:SetShadowOffset(0, 0)
    count:SetDrawLayer("OVERLAY", 7)
    CDM.Pixel.SetPoint(count, s.countPos, auraButton, s.countPos, s.countX, s.countY)
    local okCount, errCount = pcall(auraButton.SetApplicationCount, auraButton, count)
    if not okCount then RecordError("SetApplicationCount", errCount) end
end

------------------------------------------------------------
-- 容器
------------------------------------------------------------
local function HideShow(c) c:Hide(); c:Show() end

-- 容器在藏著的框底下建立時，SetEnabled 的事件註冊條件（IsVisible and IsEnabled）不成立，
-- 之後就永遠空白 ⇒ 持有框顯示出來時補踢一次。戰鬥中不踢（對容器 Hide 會跳封鎖視窗）。
local function KickContainer(holder)
    local c = holder and holder.cdmAuraContainer
    if not c then return end
    if InCombatLockdown() then
        pendingKick[holder] = true
        return
    end
    pendingKick[holder] = nil
    pcall(HideShow, c)
    pcall(c.SetEnabled, c, true)
end

local function CreateAuraContainer(holder, s)
    if not s.formatter then
        -- 退路：不帶 options 的 SetDurationText 走暴雪預設格式，中文會帶「秒」
        RecordError("formatter unavailable", "spellID " .. tostring(s.spellID))
    end
    local ok, result = pcall(function()
        local c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
        c:SetFrameLevel(s.level)
        c:SetAllPoints(holder)
        -- 建立順序固定：SetUnit → AddAuraSlot → SetEnabled 最後（它管事件註冊）
        c:SetUnit("player")
        s.container = c   -- initializeFrame 在 AddAuraSlot 裡同步跑，要先放好
        c:AddAuraSlot(AURA_SLOT_KEY, s.filter, {
            candidateFilters = { includeSpellIDs = { [s.spellID] = true } },
            initializeFrame = function(auraButton)
                -- ⚠ 一定要隔離：錯誤逃出去會打斷暴雪那一整批 frame 建立
                xpcall(InitAuraSlotButton, geterrorhandler(), auraButton, s)
            end,
        })
        c:SetEnabled(true)
        return c
    end)
    if not ok then
        RecordError("CreateAuraContainer", result)
        return nil
    end
    return result
end

local function RetireContainer(c)
    if not c then return end
    pcall(c.SetEnabled, c, false)
    pcall(c.Hide, c)
end

-- 換上符合簽章的容器（池裡有就重用，沒有才建）。只在戰鬥外呼叫。
local function ApplyContainer(holder, s, signature)
    local current = holder.cdmAuraContainer
    if current and holder.cdmAuraSignature == signature then return false end

    local pool = holder.cdmAuraContainerPool
    local c = pool[signature]
    if c then
        pcall(c.SetAllPoints, c, holder)
        pcall(c.Show, c)
        pcall(c.SetEnabled, c, true)
    else
        c = CreateAuraContainer(holder, s)
        if not c then return false end
        pool[signature] = c
    end
    if current and current ~= c then RetireContainer(current) end
    holder.cdmAuraContainer = c
    holder.cdmAuraSignature = signature
    -- 藏著的時候建的，顯示出來時 OnShow 會補踢；已經顯示的話現在就踢一次
    if holder:IsVisible() then KickContainer(holder) end
    return true
end

------------------------------------------------------------
-- 持有框
------------------------------------------------------------
local function OnHolderShow(holder)
    -- 掛勾裡只記帳，工作延到下一幀（Show 可能是從別人的執行流程觸發的）
    C_Timer.After(0, function()
        if holder:IsShown() then KickContainer(holder) end
    end)
end

local function CreateAuraSlotFrame(spellID, entry)
    local holder = holderCache[spellID]
    if holder then return holder end

    holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    holder.spellID = spellID
    holder.isCustomBuff = true   -- 讓既有的排序／群組邏輯認得它
    holder.isAuraSlot = true     -- 沒有 Cooldown／Applications 欄位：那些在 forbidden 子樹裡
    holder.cdmAuraContainerPool = {}

    -- 占位圖示：畫在持有框本身，按鈕顯示時蓋在它上面
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    CDM.Pixel.DisableTextureSnap(icon)
    holder.Icon = icon

    if CDM.BORDER and CDM.BORDER.CreateBorder then
        holder.cdmBorder = CDM.BORDER:CreateBorder(holder)
        if holder.cdmBorder then
            holder.cdmBorder:SetFrameLevel(holder:GetFrameLevel() + LEVEL_BORDER)
        end
    end

    -- ⚠ 掛在自己的持有框上，不能掛在容器上（容器是 forbidden，HookScript 直接丟錯）
    holder:HookScript("OnShow", OnHolderShow)

    holderCache[spellID] = holder
    return holder
end

-- 值沒變就不寫；戰鬥中完全不寫（持有框因為底下的 intrinsic 容器是隱式保護框），
-- 記旗標讓脫戰時重排一次，那一輪的 ApplyStyle／群組排版會把尺寸補上
function AuraSlots.SetSize(holder, w, h)
    if holder.cdmSlotW == w and holder.cdmSlotH == h then return end
    if InCombatLockdown() then
        CDM.auraSlotLayoutDeferred = true
        return
    end
    holder.cdmSlotW, holder.cdmSlotH = w, h
    holder:SetSize(w, h)
end

local function UpdatePlaceholder(holder, entry)
    local w, h = CDM:GetCustomBuffEffectiveSize(holder.spellID)
    w, h = Snap(w), Snap(h)
    AuraSlots.SetSize(holder, w, h)
    local icon = holder.Icon
    icon:SetTexture(GetSpellTexture(holder.spellID) or entry.icon)
    CDM_C.ApplyIconTexCoord(icon, CDM_C.GetEffectiveZoomAmount(), w, h)
    icon:SetDesaturation(1)
    icon:SetShown(entry.placeholder ~= false)
end

-- 持有框的顯示切換。戰鬥中不動（見本節開頭），記下來脫戰補。
function AuraSlots.SetShown(holder, shown)
    if not holder then return end
    shown = shown and true or false
    if holder:IsShown() == shown then
        pendingVisibility[holder] = nil
        return
    end
    if InCombatLockdown() then
        pendingVisibility[holder] = shown
        return
    end
    pendingVisibility[holder] = nil
    holder:SetShown(shown)
end

-- 群組／版面程式要藏一個框時用這個：光環格走戰鬥閘，其他框照舊
function CDM:HideBuffLayoutFrame(frame)
    if frame.isAuraSlot then
        AuraSlots.SetShown(frame, false)
    else
        frame:Hide()
    end
end

local function RetireAuraSlot(spellID)
    local holder = CB.auraSlots[spellID]
    if not holder then return end
    CB.auraSlots[spellID] = nil
    pendingBuild[spellID] = nil
    AuraSlots.SetShown(holder, false)
    holder.cdmBuffCategorySpellID = nil
    -- 戰鬥中不拆錨點（持有框是隱式保護框），脫戰再做
    if InCombatLockdown() then
        pendingClearPoints[holder] = true
    else
        pendingClearPoints[holder] = nil
        holder:ClearAllPoints()
        holder.cdmAnchor = nil
    end
    if not InCombatLockdown() then
        RetireContainer(holder.cdmAuraContainer)
        holder.cdmAuraContainer = nil
        holder.cdmAuraSignature = nil
    end
end

-- 建／換一個項目的容器。戰鬥中排隊。
local function BuildAuraSlot(spellID, entry, allowDebounce)
    local holder = CB.auraSlots[spellID]
    if not holder then return false end
    if InCombatLockdown() then
        pendingBuild[spellID] = true
        return false
    end
    local s, signature = BuildAuraSlotStyle(spellID, entry, holder)
    if holder.cdmAuraSignature == signature and holder.cdmAuraContainer then
        pendingBuild[spellID] = nil
        return false
    end
    -- 已經有容器、只是樣式變了：等設定停下來再換（見 REBUILD_DEBOUNCE）
    if allowDebounce and holder.cdmAuraContainer and not holder.cdmAuraContainerPool[signature] then
        pendingBuild[spellID] = true
        return false
    end
    pendingBuild[spellID] = nil
    return ApplyContainer(holder, s, signature)
end

------------------------------------------------------------
-- 出現／消失音效：交給引擎（C_UnitAuras.AddAuraSound）
--
-- Lua 端判斷不到光環出現與否，所以不走 PlayCustomBuffNotification。
-- AddAuraSound 有 HasRestrictions：戰鬥中／首領戰／鑰石戰鬥中呼叫會直接跳封鎖視窗
-- （pcall 攔不住），所以登記與移除一律先問過再做，不行就等限制解除。
-- 登記不會跨 /reload 保留，登入時整份重登。
------------------------------------------------------------
local function CanChangeAuraSounds()
    if InCombatLockdown() then return false end
    local isActive = C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive
    local R = Enum and Enum.AddOnRestrictionType
    if isActive and R then
        if R.Encounter and isActive(R.Encounter) then return false end
        if R.PvPMatch and isActive(R.PvPMatch) then return false end
        if R.ChallengeMode and isActive(R.ChallengeMode) and R.Combat and isActive(R.Combat) then
            return false
        end
    end
    return true
end

-- 跟施法計時項目同一套存檔欄位（群組覆寫／未分組覆寫），TTS 不支援（引擎沒有 TTS 觸發）
local function ResolveAuraSoundNames(spellID)
    local sets = CDM.BuffGroupSets
    local groupIdx = sets and sets.grouped and sets.grouped[spellID]
    local ov
    if groupIdx then
        local gd = sets.groups and sets.groups[groupIdx]
        ov = gd and CDM:ResolveBuffOverrideEntry(gd.spellOverrides, spellID) or nil
    elseif CDM.GetUngroupedBuffOverride then
        ov = CDM:GetUngroupedBuffOverride(spellID)
    end
    if type(ov) ~= "table" or not ov.soundEnabled then return nil, nil end
    local added = (ov.soundOnShowEnabled ~= false) and ov.soundOnShow or nil
    local removed = (ov.soundOnHideEnabled ~= false) and ov.soundOnHide or nil
    return added, removed
end

local function RegisterAuraSound(trigger, spellID, soundName)
    if not (soundName and LSM and C_UnitAuras and C_UnitAuras.AddAuraSound) then return nil end
    local path = LSM:Fetch("sound", soundName, true)
    if not path then return nil end
    local info = { unitToken = "player", spellID = spellID, outputChannel = "Master" }
    -- 路徑與檔案 ID 走不同欄位，放錯欄位是靜默無聲
    if type(path) == "number" then
        info.soundFileID = path
    else
        info.soundFileName = path
    end
    local ok, id = pcall(C_UnitAuras.AddAuraSound, trigger, info)
    if not ok then
        RecordError("AddAuraSound", id)
        return nil
    end
    return id
end

local function RemoveAuraSoundID(id)
    if id and C_UnitAuras and C_UnitAuras.RemoveAuraSound then
        local ok, err = pcall(C_UnitAuras.RemoveAuraSound, id)
        if not ok then RecordError("RemoveAuraSound", err) end
    end
end

function AuraSlots.SyncSounds()
    if not (C_UnitAuras and C_UnitAuras.AddAuraSound) then return end
    if not CanChangeAuraSounds() then
        soundsDirty = true
        return
    end
    soundsDirty = false

    local trig = Enum and Enum.UnitAuraSoundTrigger
    local ADDED = trig and trig.Added or 0
    local REMOVED = trig and trig.Removed or 2
    local registry = CDM.db and CDM.db.customBuffRegistry or EMPTY_ORDER
    local ids = CB.auraSoundIDs

    -- 已登記但不再需要（項目刪了、改了音效、關掉了）
    for spellID, reg in pairs(ids) do
        local added, removed
        if IsAuraEntry(registry[spellID]) and CB.auraSlots[spellID] then
            added, removed = ResolveAuraSoundNames(spellID)
        end
        if reg.addedName ~= added then
            RemoveAuraSoundID(reg.added)
            reg.added, reg.addedName = nil, nil
        end
        if reg.removedName ~= removed then
            RemoveAuraSoundID(reg.removed)
            reg.removed, reg.removedName = nil, nil
        end
        if not reg.added and not reg.removed then ids[spellID] = nil end
    end

    for spellID in pairs(CB.auraSlots) do
        local added, removed = ResolveAuraSoundNames(spellID)
        if added or removed then
            local reg = ids[spellID] or {}
            if added and not reg.added then
                reg.added = RegisterAuraSound(ADDED, spellID, added)
                reg.addedName = reg.added and added or nil
            end
            if removed and not reg.removed then
                reg.removed = RegisterAuraSound(REMOVED, spellID, removed)
                reg.removedName = reg.removed and removed or nil
            end
            if reg.added or reg.removed then ids[spellID] = reg end
        end
    end
end

------------------------------------------------------------
-- 總同步：依註冊表建／收持有框、換容器、對齊音效。刷新鏈（BUFF_DATA／LAYOUT／STYLE）
-- 與脫戰時呼叫。回傳版面是否有變（有的話呼叫端要重排增益列）。
------------------------------------------------------------
local function ScheduleDebouncedRebuild()
    if rebuildTimer then rebuildTimer:Cancel() end
    rebuildTimer = C_Timer.NewTimer(REBUILD_DEBOUNCE, function()
        rebuildTimer = nil
        AuraSlots.FlushPendingBuilds()
    end)
end

function AuraSlots.FlushPendingBuilds()
    if InCombatLockdown() then return end
    local registry = CDM.db and CDM.db.customBuffRegistry
    if not registry then return end
    for spellID in pairs(pendingBuild) do
        local entry = registry[spellID]
        if IsAuraEntry(entry) and CB.auraSlots[spellID] then
            BuildAuraSlot(spellID, entry, false)
        else
            pendingBuild[spellID] = nil
        end
    end
end

function AuraSlots.Sync()
    local registry = CDM.db and CDM.db.customBuffRegistry
    if not registry then return false end
    local changed = false

    for spellID, holder in pairs(CB.auraSlots) do
        if not IsAuraEntry(registry[spellID]) then
            RetireAuraSlot(spellID)
            changed = true
        end
    end

    local needDebounce = false
    for spellID, entry in pairs(registry) do
        if IsAuraEntry(entry) then
            local holder = CB.auraSlots[spellID]
            if not holder then
                holder = CreateAuraSlotFrame(spellID, entry)
                CB.auraSlots[spellID] = holder
                changed = true
            end
            UpdatePlaceholder(holder, entry)
            BuildAuraSlot(spellID, entry, true)
            if pendingBuild[spellID] then needDebounce = true end
        end
    end
    if needDebounce and not InCombatLockdown() then ScheduleDebouncedRebuild() end

    AuraSlots.SyncSounds()
    return changed
end

local function OnRegenEnabled()
    local relayout = false
    -- 戰鬥中被跳過的持有框位置／尺寸（Core/Layout/Layout.lua 的 DeferAuraSlotPlacement）
    if CDM.auraSlotLayoutDeferred then
        CDM.auraSlotLayoutDeferred = nil
        relayout = true
    end
    -- 戰鬥中延後的主增益容器定位（Core/Layout/Layout.lua 的 UpdateBuffContainerPosition）
    if CDM.pendingBuffContainerPosition and CDM.UpdateBuffContainerPosition then
        CDM:UpdateBuffContainerPosition()
        relayout = true
    end
    -- 戰鬥中延後的群組容器定位（Core/GroupContainerUtils.lua 的 deferInCombat）
    if CDM.pendingBuffGroupContainerPosition and CDM.UpdateBuffGroupContainerPositions then
        CDM:UpdateBuffGroupContainerPositions()
        relayout = true
    end
    for holder in pairs(pendingClearPoints) do
        pendingClearPoints[holder] = nil
        -- 期間又被加回來的話就別拆了（下一輪排版會重新定位）
        if not CB.auraSlots[holder.spellID] then
            holder:ClearAllPoints()
            holder.cdmAnchor = nil
        end
    end
    for holder, shown in pairs(pendingVisibility) do
        pendingVisibility[holder] = nil
        if holder:IsShown() ~= shown then
            holder:SetShown(shown)
            relayout = true
        end
    end
    if next(pendingBuild) ~= nil then relayout = true end
    AuraSlots.FlushPendingBuilds()
    for holder in pairs(pendingKick) do
        KickContainer(holder)
    end
    if soundsDirty then AuraSlots.SyncSounds() end
    -- 戰鬥中延後的顯示切換會讓那一輪的排版把持有框當成沒顯示，這裡重排一次
    if relayout then ReanchorBuffViewer() end
end

local function OnRestrictionChanged()
    -- 派送當下讀不到正在變的那個型別的終值，延一幀再問
    if soundsDirty then
        C_Timer.After(0, function()
            if soundsDirty then AuraSlots.SyncSounds() end
        end)
    end
end

local function OnAuraSlotsEnteringWorld()
    -- 音效登記不跨 /reload；登入／換地圖時整份重對一次
    C_Timer.After(0, function()
        if AuraSlots.Sync() then ReanchorBuffViewer() end
    end)
end

------------------------------------------------------------
-- /cdmaura：實機驗證用的診斷（純讀取，戰鬥中也能跑）
------------------------------------------------------------
local function ProtectedText(frame)
    if not frame or not frame.IsProtected then return "-" end
    local ok, isProtected, explicit = pcall(frame.IsProtected, frame)
    if not ok then return "err" end
    return tostring(isProtected) .. (explicit and "(explicit)" or "")
end

function AuraSlots.PrintDiagnostics()
    local out = print
    local count = 0
    out("|cffffd200Ayije_CDM aura slots|r  combat=" .. tostring(InCombatLockdown())
        .. "  layoutDeferred=" .. tostring(CDM.auraSlotLayoutDeferred and true or false)
        .. "  buffPosPending=" .. tostring(CDM.pendingBuffContainerPosition and true or false)
        .. "  groupPosPending=" .. tostring(CDM.pendingBuffGroupContainerPosition and true or false)
        .. "  soundsDirty=" .. tostring(soundsDirty))
    local sets = CDM.BuffGroupSets
    for spellID, holder in pairs(CB.auraSlots) do
        count = count + 1
        local groupIdx = sets and sets.grouped and sets.grouped[spellID]
        local host, hostName
        if groupIdx then
            host = CDM.buffGroupContainers and CDM.buffGroupContainers[groupIdx]
            hostName = "group" .. groupIdx
        else
            host = CDM.anchorContainers and CDM.anchorContainers[VIEWERS.BUFF]
            hostName = "main"
        end
        local vis = pendingVisibility[holder]
        out(("  %s %s  shown=%s  holder=%s  container=%s  %s=%s"):format(
            tostring(spellID), tostring(C_Spell.GetSpellName(spellID) or "?"),
            tostring(holder:IsShown()), ProtectedText(holder),
            ProtectedText(holder.cdmAuraContainer), hostName, ProtectedText(host)))
        out(("    pendingBuild=%s  pendingVisibility=%s  pendingKick=%s  pendingClear=%s  sounds=%s/%s"):format(
            tostring(pendingBuild[spellID] and true or false),
            vis == nil and "-" or tostring(vis),
            tostring(pendingKick[holder] and true or false),
            tostring(pendingClearPoints[holder] and true or false),
            tostring(CB.auraSoundIDs[spellID] and CB.auraSoundIDs[spellID].added or "-"),
            tostring(CB.auraSoundIDs[spellID] and CB.auraSoundIDs[spellID].removed or "-")))
        out("    sig=" .. tostring(holder.cdmAuraSignature))
    end
    if count == 0 then out("  (no aura slots)") end
    local errs = CB.auraSlotErrors
    local first = math.max(1, #errs - 4)
    out(("  errors: %d"):format(#errs))
    for i = first, #errs do
        out("    " .. errs[i])
    end
end

SLASH_AYIJECDMAURA1 = "/cdmaura"
SlashCmdList["AYIJECDMAURA"] = function()
    AuraSlots.PrintDiagnostics()
end

AuraSlots.OnRegenEnabled = OnRegenEnabled
AuraSlots.OnRestrictionChanged = OnRestrictionChanged
AuraSlots.OnEnteringWorld = OnAuraSlotsEnteringWorld
AuraSlots.Retire = RetireAuraSlot

-- MiliUI: templateOverrides.kind = "aura" 時新增光環格項目，duration 可為 nil；
-- 另收 auraFilter（"HELPFUL"／"HARMFUL"）、placeholder、hideCooldownText。
-- 減益只收 NeverSecret 的法術（其餘在戰鬥中是秘密值，引擎不讓用法術 ID 過濾），
-- 被擋時第二個回傳值是 "secret"。
function CDM:AddCustomBuffSpell(spellID, duration, templateOverrides)
    local isAura = (templateOverrides and templateOverrides.kind == "aura") and true or false
    if not spellID or (not isAura and not duration) then return false end

    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return false end

    local auraFilter
    if isAura then
        auraFilter = (templateOverrides.auraFilter == "HARMFUL") and "HARMFUL" or "HELPFUL"
        if auraFilter == "HARMFUL" and not CDM:IsAuraSpellNeverSecret(spellID) then
            return false, "secret"
        end
    end

    if not CDM.db.customBuffRegistry then
        CDM.db.customBuffRegistry = {}
    end

    local entry = {
        duration = (not isAura) and duration or nil,
        name = spellInfo.name,
        icon = spellInfo.iconID,
    }
    if templateOverrides then
        if templateOverrides.icon then entry.icon = templateOverrides.icon end
        if templateOverrides.triggerType and not isAura then entry.triggerType = templateOverrides.triggerType end
    end
    if isAura then
        entry.kind = "aura"
        entry.auraFilter = auraFilter
        entry.placeholder = templateOverrides.placeholder ~= false
        entry.hideCooldownText = templateOverrides.hideCooldownText and true or false
    end

    -- 同一個 ID 從施法計時換成光環格（或反過來）：先把舊的執行期框收掉
    local old = CDM.db.customBuffRegistry[spellID]
    if old and IsAuraEntry(old) ~= isAura then
        if isAura then
            if CB.activeBuffs[spellID] then DeactivateCustomBuff(spellID) end
        else
            AuraSlots.Retire(spellID)
        end
    end

    CDM.db.customBuffRegistry[spellID] = entry
    return true
end

function CDM:RemoveCustomBuffSpell(spellID)
    if not CDM.db.customBuffRegistry then return end

    if CB.activeBuffs[spellID] then
        DeactivateCustomBuff(spellID)
    end

    -- MiliUI: 光環格的持有框收起來（框本身留在快取裡，同一個 ID 加回來時沿用）
    AuraSlots.Retire(spellID)

    local frame = CB.iconFrames[spellID]
    if frame then
        if frame.Cooldown then
            frame.Cooldown:SetScript("OnCooldownDone", nil)
            frame.Cooldown:Clear()
        end
        frame:Hide()
        frame:ClearAllPoints()
        frame.cdmAnchor = nil
        if frame:GetParent() ~= UIParent then
            frame:SetParent(UIParent)
        end
        frame.spellID = nil
        frame.customBuffStartTime = nil
        CB.framePool[#CB.framePool + 1] = frame
        CB.iconFrames[spellID] = nil
    end

    CDM.db.customBuffRegistry[spellID] = nil
    AuraSlots.SyncSounds()  -- MiliUI: 刪掉的光環格不再響

    if CDM.db.ungroupedCustomBuffOrder then
        for _, order in pairs(CDM.db.ungroupedCustomBuffOrder) do
            for i = #order, 1, -1 do
                if order[i].spellID == spellID then
                    table.remove(order, i)
                end
            end
        end
    end

    if CDM.db.buffGroups then
        for _, specGroups in pairs(CDM.db.buffGroups) do
            if type(specGroups) == "table" then
                for _, groupData in ipairs(specGroups) do
                    if groupData.spells then
                        for i = #groupData.spells, 1, -1 do
                            if groupData.spells[i] == spellID then
                                table.remove(groupData.spells, i)
                            end
                        end
                    end
                end
            end
        end
    end

    local isAlsoNative = CDM.ResolveStableBase and CDM:ResolveStableBase(spellID)
    if not isAlsoNative then
        local storageKey = CDM.GetBuffOverrideStorageKey and CDM:GetBuffOverrideStorageKey(spellID) or spellID

        if CDM.db.ungroupedBuffOverrides then
            for _, specOv in pairs(CDM.db.ungroupedBuffOverrides) do
                if type(specOv) == "table" then
                    specOv[spellID] = nil
                    if storageKey then specOv[storageKey] = nil end
                end
            end
        end

        if CDM.db.spellRegistry then
            for specID, registry in pairs(CDM.db.spellRegistry) do
                if type(registry) == "table" then
                    if registry.colors then registry.colors[spellID] = nil end
                    if registry.glowEnabled then registry.glowEnabled[spellID] = nil end
                    if registry.glowColors then registry.glowColors[spellID] = nil end
                end
                if CDM.CompactRegistrySpec then
                    CDM:CompactRegistrySpec(specID)
                end
            end
        end
    end
end

function CDM:UpdateCustomBuffs()
    RefreshCachedCustomBuffStyles()

    for spellID, frame in pairs(CB.iconFrames) do
        local w, h = self:GetCustomBuffEffectiveSize(spellID)
        frame:SetSize(w, h)

        if frame.Icon then
            CDM_C.ApplyIconTexCoord(frame.Icon, CDM_C.GetEffectiveZoomAmount(), w, h)
        end

        if not IsGroupedCustomBuff(spellID) then
            ApplyCustomBuffCooldownTextStyle(frame)
        end
    end

    -- MiliUI: 光環格：建／收持有框、簽章變了換容器、對齊音效；持有框有增減就重排增益列
    if AuraSlots.Sync() then
        ReanchorBuffViewer()
    end
end

CDM.CustomBuffTemplates = {
    { spellID = 1236616, duration = 30 },  -- Light's Potential
    { spellID = 1236994, duration = 30 },  -- Potion of Recklessness
    { spellID = 1239479, duration = 10 },  -- Potion of Devoured Dreams
    { spellID = 374968, duration = 10, icon = 4622479, triggerType = "timespiral" },  -- Time Spiral
    { spellID = 2825, duration = 40, triggerType = "bloodlust" },  -- Bloodlust
    -- MiliUI: 光環格範例（引擎依法術 ID 顯示，別人上給你的也算）
    { spellID = 10060, kind = "aura", auraFilter = "HELPFUL" },  -- Power Infusion
}


function CDM:IsCustomBuffInAnyGroup(specID, spellID)
    local groups = self.db and self.db.buffGroups and self.db.buffGroups[specID]
    if not groups then return false end
    for _, groupData in ipairs(groups) do
        if groupData.spells then
            for _, sid in ipairs(groupData.spells) do
                if sid == spellID then return true end
            end
        end
    end
    return false
end

function CDM:GetUngroupedCustomBuffOrder(specID)
    if not specID then return EMPTY_ORDER end
    local db = self.db
    if not db then return EMPTY_ORDER end

    local registry = db.customBuffRegistry
    if not registry then return EMPTY_ORDER end

    if not db.ungroupedCustomBuffOrder then
        db.ungroupedCustomBuffOrder = {}
    end

    local order = db.ungroupedCustomBuffOrder[specID]
    if not order then
        order = {}
        db.ungroupedCustomBuffOrder[specID] = order
    end

    for i = #order, 1, -1 do
        local entry = order[i]
        if not registry[entry.spellID] or self:IsCustomBuffInAnyGroup(specID, entry.spellID) then
            table.remove(order, i)
        end
    end

    local seen = ungroupedSeenScratch
    table.wipe(seen)
    for _, entry in ipairs(order) do
        seen[entry.spellID] = true
    end

    for spellID in pairs(registry) do
        if not seen[spellID] and not self:IsCustomBuffInAnyGroup(specID, spellID) then
            order[#order + 1] = { spellID = spellID, afterNative = 0 }
        end
    end

    return order
end

function CDM:SetUngroupedCustomBuffOrder(specID, list)
    if not specID or not self.db then return end
    if not self.db.ungroupedCustomBuffOrder then
        self.db.ungroupedCustomBuffOrder = {}
    end
    self.db.ungroupedCustomBuffOrder[specID] = list
end

local function OnPlayerDead()
    if not next(CB.activeBuffs) then return end
    local toClear = {}
    for spellID in pairs(CB.activeBuffs) do
        toClear[#toClear + 1] = spellID
    end
    for i = 1, #toClear do
        DeactivateCustomBuff(toClear[i])
    end
end

local CUSTOM_BUFF_EVENTS = {
    UNIT_SPELLCAST_SUCCEEDED        = OnSpellCastSucceeded,
    UNIT_SPELLCAST_SENT             = OnSpellCastSent,
    UNIT_AURA                       = OnBloodlustAura,
    SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = OnGlowShow,
    SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = OnGlowHide,
    PLAYER_DEAD                     = OnPlayerDead,
    -- MiliUI: 光環格的脫戰補做／音效重登
    PLAYER_REGEN_ENABLED            = AuraSlots.OnRegenEnabled,
    PLAYER_ENTERING_WORLD           = AuraSlots.OnEnteringWorld,
    ADDON_RESTRICTION_STATE_CHANGED = AuraSlots.OnRestrictionChanged,
}

function CDM:InitializeCustomBuffs()
    local eventFrame = CreateFrame("Frame")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        local fn = CUSTOM_BUFF_EVENTS[event]
        if fn then fn(event, ...) end
    end)
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    eventFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    eventFrame:RegisterEvent("PLAYER_DEAD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    end

    self:RebuildGlowFilters()
end

CDM:RegisterRefreshCallback("customBuffs", function()
    CDM:UpdateCustomBuffs()
end, 50, { "BUFF_DATA", "LAYOUT", "STYLE" })
