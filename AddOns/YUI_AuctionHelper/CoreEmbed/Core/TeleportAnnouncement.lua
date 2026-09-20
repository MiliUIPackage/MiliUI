do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI or not YUI.IsRetail or YUI.TeleportAnnouncement then return end

local Service = { previewFrames = setmetatable({}, { __mode = "k" }) }
YUI.TeleportAnnouncement = Service
local MODULE_ID = "core.teleport_announcement"
local L = YUI.Locale:Get("Core")
local DATA = YUI.TeleportData
local SpellAPI = YUI.API.Spell
local UnitAPI = YUI.API.Unit
local ChatInputAPI = YUI.API.ChatInput
local SecurityAPI = YUI.API.Security
local function IsSecret(value)
    return SecurityAPI and SecurityAPI.IsSecretValue and SecurityAPI.IsSecretValue(value) == true
end
local function T(key, fallback, ...)
    local value = L[key] or fallback or key
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end
local ANNOUNCE_DEFAULT_PREFIX = "[YUI]"
local ANNOUNCE_SCOPE_OFF = "off"
local ANNOUNCE_SCOPE_PORTALS = "portals"
local ANNOUNCE_SCOPE_DUNGEONS = "dungeons"
local ANNOUNCE_SCOPE_ALL = "all"
local ANNOUNCE_KIND_PORTAL = "portal"
local ANNOUNCE_KIND_DUNGEON = "dungeon"
local ANNOUNCE_PREVIEW_PARTY_COLOR = "ffaaaaff"
local ANNOUNCE_TRIGGER_CAST_START = "cast_start"
local ANNOUNCE_TRIGGER_CAST_SUCCESS = "cast_success"

local function IsValidAnnounceScope(scope)
    return scope == ANNOUNCE_SCOPE_OFF or scope == ANNOUNCE_SCOPE_PORTALS or
        scope == ANNOUNCE_SCOPE_DUNGEONS or scope == ANNOUNCE_SCOPE_ALL
end

local function IsValidAnnounceTrigger(trigger)
    return trigger == ANNOUNCE_TRIGGER_CAST_START or trigger == ANNOUNCE_TRIGGER_CAST_SUCCESS
end


function Service:GetOwnerProduct()
    if YUI.CoreMode == "suite" then return "suite" end
    local products = YUI.Products or {}
    if products.ybar and not (YUI.BlockedProducts and YUI.BlockedProducts.ybar) then return "ybar" end
    if products.toolbox and not (YUI.BlockedProducts and YUI.BlockedProducts.toolbox) then return "toolbox" end
end

local function GetLegacyConfig(profile)
    local bar = profile.YBar
    if type(bar) ~= "table" then return nil end
    if bar.version == 2 and type(bar.instances) == "table" then
        for _, id in ipairs(bar.instanceOrder or {}) do
            local instance = bar.instances[id]
            if instance and instance.moduleType == "Teleports" then return instance.config end
        end
        return bar.legacyRemainder and bar.legacyRemainder.Teleports
    end
    return bar.Teleports
end

function Service:GetConfig()
    local product = self:GetOwnerProduct()
    if not product or not YUI.DB:IsReady() then return nil end
    local profile = YUI.DB:GetProfile(product)
    if not profile then return nil end
    if type(profile.TeleportAnnouncement) ~= "table" then
        local legacy = GetLegacyConfig(profile) or {}
        profile.TeleportAnnouncement = {
            announceScope = IsValidAnnounceScope(legacy.announceScope) and legacy.announceScope or ANNOUNCE_SCOPE_OFF,
            announceTrigger = IsValidAnnounceTrigger(legacy.announceTrigger) and legacy.announceTrigger or ANNOUNCE_TRIGGER_CAST_START,
            announcePrefix = type(legacy.announcePrefix) == "string" and legacy.announcePrefix or ANNOUNCE_DEFAULT_PREFIX,
        }
    end
    return profile.TeleportAnnouncement
end

function Service:GetScope()
    local db = self:GetConfig()
    return db and IsValidAnnounceScope(db.announceScope) and db.announceScope or ANNOUNCE_SCOPE_OFF
end

function Service:Refresh()
    if self:GetScope() ~= ANNOUNCE_SCOPE_OFF then
        YUI.Module:Enable(MODULE_ID)
    else
        YUI.Module:Disable(MODULE_ID)
    end
    self:RefreshAnnouncementPreview()
    YUI.Event:Emit("YUI_TELEPORT_ANNOUNCEMENT_CHANGED")
end

function Service:SetOption(key, value)
    local db = self:GetConfig()
    if not db then return end
    if key == "announceScope" then
        value = IsValidAnnounceScope(value) and value or ANNOUNCE_SCOPE_OFF
    elseif key == "announceTrigger" then
        value = IsValidAnnounceTrigger(value) and value or ANNOUNCE_TRIGGER_CAST_START
    elseif key == "announcePrefix" then
        value = type(value) == "string" and value or ""
    else return end
    db[key] = value
    self:Refresh()
end

function Service:NormalizeAnnouncePrefix()
    local db = self:GetConfig()
    local prefix = db and db.announcePrefix
    if type(prefix) ~= "string" then
        prefix = ANNOUNCE_DEFAULT_PREFIX
    end
    return prefix
end

function Service:GetAnnounceTrigger()
    local db = self:GetConfig()
    local trigger = db and db.announceTrigger or ANNOUNCE_TRIGGER_CAST_START
    if not IsValidAnnounceTrigger(trigger) then
        trigger = ANNOUNCE_TRIGGER_CAST_START
    end
    return trigger
end

function Service:NormalizeAnnouncementName(name)
    if IsSecret(name) then return nil end
    if type(name) ~= "string" then
        name = name and tostring(name) or ""
    end
    if name == "" then return nil end
    if name:match("^<.*>$") then return name end
    return "<" .. name .. ">"
end

function Service:GetDungeonAnnouncementName(itemData)
    if type(itemData) == "table" then
        local key = itemData.announceNameKey or itemData.mapKey or itemData.id
        if key then
            local fullName = L["teleports.announce.full_name." .. tostring(key)]
            if type(fullName) == "string" and fullName ~= "" then
                return fullName
            end
        end
        return itemData.announceName or (itemData.id and SpellAPI.GetName(itemData.id)) or itemData.text
    end
    return itemData
end

function Service:GetAnnouncementTargetName(kind, itemData)
    if kind == ANNOUNCE_KIND_DUNGEON then
        return self:GetDungeonAnnouncementName(itemData)
    end
    if type(itemData) == "table" then
        return itemData.announceName or (itemData.id and SpellAPI.GetName(itemData.id)) or itemData.text
    end
    return itemData
end

function Service:BuildAnnouncementMessage(kind, itemData, trigger)
    trigger = IsValidAnnounceTrigger(trigger) and trigger or self:GetAnnounceTrigger()
    local name = self:NormalizeAnnouncementName(self:GetAnnouncementTargetName(kind, itemData))
    if not name or name == "" then return nil end
    local body
    if kind == ANNOUNCE_KIND_PORTAL then
        if trigger == ANNOUNCE_TRIGGER_CAST_SUCCESS then
            body = T("teleports.announce.opened", "已开启传送门 %s", name)
        else
            body = T("teleports.announce.opening", "正在开启传送门 %s", name)
        end
    elseif kind == ANNOUNCE_KIND_DUNGEON then
        if trigger == ANNOUNCE_TRIGGER_CAST_SUCCESS then
            body = T("teleports.announce.arrived", "已传送至 %s", name)
        else
            body = T("teleports.announce.going", "正在前往 %s", name)
        end
    end
    if not body then return nil end

    local prefix = self:NormalizeAnnouncePrefix()
    if prefix ~= "" then
        return prefix .. " " .. body
    end
    return body
end

function Service:GetAnnouncementChannel()
    local resolver = ChatInputAPI and ChatInputAPI.ResolveGroupChatType
    return type(resolver) == "function" and resolver() or nil
end

function Service:ShouldAnnounce(kind)
    local scope = self:GetScope()
    if scope == ANNOUNCE_SCOPE_ALL then
        return kind == ANNOUNCE_KIND_PORTAL or kind == ANNOUNCE_KIND_DUNGEON
    elseif scope == ANNOUNCE_SCOPE_PORTALS then
        return kind == ANNOUNCE_KIND_PORTAL
    elseif scope == ANNOUNCE_SCOPE_DUNGEONS then
        return kind == ANNOUNCE_KIND_DUNGEON
    end
    return false
end

function Service:AnnounceTeleport(itemData, trigger)
    if not itemData or not self:ShouldAnnounce(itemData.announceKind) then return end
    local channel = self:GetAnnouncementChannel()
    if not channel or not SendChatMessage then return end

    local message = self:BuildAnnouncementMessage(itemData.announceKind, itemData, trigger)
    if message and message ~= "" then
        SendChatMessage(message, channel)
    end
end

function Service:BuildSpellcastAnnouncementIndex()
    local index = {}

    local function addSpell(kind, spellID, nameKey)
        spellID = tonumber(spellID)
        if not spellID then return end

        local itemData = {
            id = spellID,
            announceKind = kind,
        }

        if kind == ANNOUNCE_KIND_DUNGEON then
            itemData.mapKey = nameKey or spellID
            itemData.announceNameKey = nameKey or spellID
        end

        index[spellID] = itemData
    end

    local function addDungeonSpell(canonicalId)
        canonicalId = tonumber(canonicalId)
        if not canonicalId then return end

        addSpell(ANNOUNCE_KIND_DUNGEON, canonicalId, canonicalId)

        local variants = DATA.DungeonVariants[canonicalId]
        if variants then
            for _, variantId in pairs(variants) do
                addSpell(ANNOUNCE_KIND_DUNGEON, variantId, canonicalId)
            end
        end
    end

    for _, id in ipairs(DATA.MagePortals) do
        addSpell(ANNOUNCE_KIND_PORTAL, id)
    end

    for _, list in pairs(DATA.Dungeons) do
        for _, id in ipairs(list) do
            addDungeonSpell(id)
        end
    end

    for _, id in ipairs(DATA.CurrentSeason) do
        addDungeonSpell(id)
    end

    self.announcementSpellcastIndex = index
    return index
end

function Service:GetSpellcastAnnouncementData(spellID)
    if IsSecret(spellID) or type(spellID) ~= "number" then return nil end

    local index = self.announcementSpellcastIndex or self:BuildSpellcastAnnouncementIndex()
    return index and index[spellID] or nil
end

function Service:OnSpellcast(event, unit, castGUID, spellID)
    if IsSecret(unit) or IsSecret(spellID) or IsSecret(castGUID) then return end
    if unit ~= "player" or type(spellID) ~= "number" then return end
    if event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
    local itemData = self:GetSpellcastAnnouncementData(spellID)
    if not itemData then return end
    local trigger = self:GetAnnounceTrigger()
    if (event == "UNIT_SPELLCAST_START" and trigger ~= ANNOUNCE_TRIGGER_CAST_START)
        or (event == "UNIT_SPELLCAST_SUCCEEDED" and trigger ~= ANNOUNCE_TRIGGER_CAST_SUCCESS) then return end
    if castGUID and castGUID ~= "" then
        if self.lastCastGUID == castGUID then return end
        self.lastCastGUID = castGUID
    end
    self:AnnounceTeleport(itemData, trigger)
end

function Service:GetAnnouncementPreviewPlayerName()
    local name = T("teleports.announce.preview_player_name", "玩家名")
    if UnitAPI and UnitAPI.UnitName then
        name = UnitAPI.UnitName("player") or name
    elseif UnitName then
        name = UnitName("player") or name
    end

    local classFilename
    if UnitAPI and UnitAPI.UnitClass then
        local _
        _, classFilename = UnitAPI.UnitClass("player")
    elseif UnitClass then
        local _
        _, classFilename = UnitClass("player")
    end

    local colorHex = ANNOUNCE_PREVIEW_PARTY_COLOR
    local classColor = classFilename and UnitAPI and UnitAPI.GetClassColor and UnitAPI.GetClassColor(classFilename)
    if classColor and classColor.GenerateHexColor then
        colorHex = classColor:GenerateHexColor()
    elseif classFilename and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFilename] then
        local color = RAID_CLASS_COLORS[classFilename]
        colorHex = color.GenerateHexColor and color:GenerateHexColor() or color.colorStr or colorHex
    end

    return "|c" .. colorHex .. "[" .. name .. "]|r"
end

function Service:BuildAnnouncementPreviewLine(message)
    local channelName = T("teleports.announce.preview_party_channel", "队伍")
    return "|c" .. ANNOUNCE_PREVIEW_PARTY_COLOR .. "[" .. channelName .. "]|r " ..
        self:GetAnnouncementPreviewPlayerName() .. ": |c" .. ANNOUNCE_PREVIEW_PARTY_COLOR .. (message or "") .. "|r"
end

function Service:GetAnnouncementPreview(kind)
    local name
    if kind == ANNOUNCE_KIND_PORTAL then
        name = T("teleports.announce.preview_portal_name", "传送门名字")
    else
        name = T("teleports.announce.preview_dungeon_name", "副本名字")
    end
    return self:BuildAnnouncementPreviewLine(self:BuildAnnouncementMessage(kind, name, self:GetAnnounceTrigger()))
end

function Service:RefreshAnnouncementPreview()
    for frame in pairs(self.previewFrames) do
        if frame:IsShown() then
            frame.dungeon:SetText(self:GetAnnouncementPreview(ANNOUNCE_KIND_DUNGEON))
            frame.portal:SetText(self:GetAnnouncementPreview(ANNOUNCE_KIND_PORTAL))
        end
    end
end

function Service:RenderAnnouncementPreview(parent, x, y, width)
    local GUI2 = YUI.GUI2
    width = width or 360
    local labelWidth = GUI2.GetMetric and GUI2:GetMetric("layout.form.labelWidth", 120) or 120
    local rowHeight = GUI2.GetMetric and GUI2:GetMetric("layout.form.rowHeight", 32) or 32
    local previewTop = math.max(rowHeight - 6, 24)
    local lineHeight = math.max(rowHeight, 34)
    local lineGap = 0
    local height = previewTop + lineHeight * 2 + lineGap + 2

    local frame = GUI2:CreateFrame(parent, { width = width, height = height })
    frame:SetPoint("TOPLEFT", x, y)

    local title = GUI2:CreateText(frame, T("teleports.settings.announce_preview", "预览"), "font.size.md", "color.text.primary", "LEFT")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
    title:SetWidth(labelWidth)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)

    local dungeon = GUI2:CreateText(frame, self:GetAnnouncementPreview(ANNOUNCE_KIND_DUNGEON), "font.size.md", "color.text.primary", "LEFT")
    dungeon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -previewTop)
    dungeon:SetSize(width, lineHeight)
    dungeon:SetJustifyH("LEFT")
    dungeon:SetWordWrap(true)
    if dungeon.SetNonSpaceWrap then dungeon:SetNonSpaceWrap(true) end

    local portal = GUI2:CreateText(frame, self:GetAnnouncementPreview(ANNOUNCE_KIND_PORTAL), "font.size.md", "color.text.primary", "LEFT")
    portal:SetPoint("TOPLEFT", dungeon, "BOTTOMLEFT", 0, -lineGap)
    portal:SetSize(width, lineHeight)
    portal:SetJustifyH("LEFT")
    portal:SetWordWrap(true)
    if portal.SetNonSpaceWrap then portal:SetNonSpaceWrap(true) end

    frame.dungeon, frame.portal = dungeon, portal
    self.previewFrames[frame] = true
    frame:SetScript("OnShow", function() Service:RefreshAnnouncementPreview() end)

    return width, height
end

function Service:GetOptions(width)
    return {
        { type = "divider", label = L["teleports.settings.announce_header"] or "Teleport Announcement", alignLeft = true, width = width or 600 },
        {
            type = "dropdown",
            label = L["teleports.settings.announce_scope"] or "Announcement Scope",
            width = 220,
            options = {
                { text = L["teleports.settings.announce_scope_off"] or "Off", value = ANNOUNCE_SCOPE_OFF },
                { text = L["teleports.settings.announce_scope_portals"] or "Portals", value = ANNOUNCE_SCOPE_PORTALS },
                { text = L["teleports.settings.announce_scope_dungeons"] or "Mythic+", value = ANNOUNCE_SCOPE_DUNGEONS },
                { text = L["teleports.settings.announce_scope_all"] or "Portals + Dungeons", value = ANNOUNCE_SCOPE_ALL },
            },
            get = function() return Service:GetScope() end,
            set = function(v)
                Service:SetOption("announceScope", v)
            end,
        },
        {
            type = "dropdown",
            label = L["teleports.settings.announce_trigger"] or "Trigger Condition",
            width = 220,
            options = {
                { text = L["teleports.settings.announce_trigger_cast_start"] or "Cast Start", value = ANNOUNCE_TRIGGER_CAST_START },
                { text = L["teleports.settings.announce_trigger_cast_success"] or "Cast Success", value = ANNOUNCE_TRIGGER_CAST_SUCCESS },
            },
            get = function() return self:GetAnnounceTrigger() end,
            set = function(v)
                Service:SetOption("announceTrigger", v)
            end,
        },
        {
            type = "editbox",
            label = L["teleports.settings.announce_prefix"] or "Announcement Prefix",
            width = 220,
            get = function() return self:NormalizeAnnouncePrefix() end,
            set = function(v)
                Service:SetOption("announcePrefix", v)
            end,
        },
        {
            type = "custom",
            render = function(parent, x, y, width)
                return self:RenderAnnouncementPreview(parent, x, y, width)
            end,
        },
    }
end

YUI.Module:Register({
    id = MODULE_ID,
    owner = Service,
    dependencies = { "core.db", "core.event", "core.locale", "core.api" },
    getEnabled = function() return Service:GetScope() ~= ANNOUNCE_SCOPE_OFF end,
    OnInitialize = function()
        YUI.Module:Get(MODULE_ID).product = Service:GetOwnerProduct() or YUI.ProductId
    end,
    OnEnable = function()
        YUI.Event:OffOwner(Service)
        Service:BuildSpellcastAnnouncementIndex()
        YUI.Event:On("UNIT_SPELLCAST_START", "OnSpellcast", Service, { unit = "player" })
        YUI.Event:On("UNIT_SPELLCAST_SUCCEEDED", "OnSpellcast", Service, { unit = "player" })
    end,
    OnDisable = function()
        YUI.Event:OffOwner(Service)
        Service.announcementSpellcastIndex = nil
        Service.lastCastGUID = nil
    end,
    OnProfileChanged = function()
        Service.lastCastGUID = nil
        Service:RefreshAnnouncementPreview()
    end,
})
