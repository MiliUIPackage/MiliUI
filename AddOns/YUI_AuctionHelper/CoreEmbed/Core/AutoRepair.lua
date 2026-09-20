do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI or YUI.AutoRepair then return end

local Service = {}
YUI.AutoRepair = Service
local MODULE_ID = "core.auto_repair"
local DEFAULT_MODE = "guild"
local L = YUI.Locale:Get("Core")
local UnitAPI = YUI.API and YUI.API.Unit
local floor, format = math.floor, string.format
local BreakUpLargeNumbers = BreakUpLargeNumbers
local CanMerchantRepair, CanGuildBankRepair = CanMerchantRepair, CanGuildBankRepair
local GetRepairAllCost, RepairAllItems = GetRepairAllCost, RepairAllItems

local function NormalizeMode(mode)
    return (mode == "guild" or mode == "personal") and mode or "off"
end

function Service:IsAvailable()
    return type(CanMerchantRepair) == "function" and type(GetRepairAllCost) == "function"
        and type(RepairAllItems) == "function"
end

function Service:IsGuildAvailable()
    return self:IsAvailable() and type(CanGuildBankRepair) == "function"
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
    -- Read saved data directly: migration must not create a visible bar instance.
    if bar.version == 2 and type(bar.instances) == "table" then
        for _, id in ipairs(bar.instanceOrder or {}) do
            local instance = bar.instances[id]
            if instance and instance.moduleType == "DurabilityMount" then return instance.config end
        end
        return bar.legacyRemainder and bar.legacyRemainder.DurabilityMount
    end
    return bar.DurabilityMount
end

function Service:GetConfig()
    local product = self:GetOwnerProduct()
    if not product or not YUI.DB:IsReady() then return nil end
    local profile = YUI.DB:GetProfile(product)
    if not profile then return nil end
    if type(profile.AutoRepair) ~= "table" then
        local legacy = GetLegacyConfig(profile) or {}
        local mode = legacy.autoRepairMode
        if mode == nil then
            if legacy.guildRepairEnabled ~= nil then
                mode = legacy.guildRepairEnabled == true and "guild" or "off"
            else
                mode = DEFAULT_MODE
            end
        end
        local notify = legacy.autoRepairNotify
        if notify == nil then notify = legacy.guildRepairNotify end
        profile.AutoRepair = { mode = NormalizeMode(mode), notify = notify ~= false }
    elseif profile.AutoRepair.mode == nil then
        profile.AutoRepair.mode = DEFAULT_MODE
    end
    return profile.AutoRepair
end

function Service:GetMode()
    local db = self:GetConfig()
    local mode = NormalizeMode(db and db.mode)
    if mode == "guild" and not self:IsGuildAvailable() then return "off" end
    return mode
end

function Service:GetModeText(mode)
    return L["auto_repair.mode." .. NormalizeMode(mode)]
end

function Service:SetMode(mode)
    local db = self:GetConfig()
    if not db then return end
    mode = NormalizeMode(mode)
    if mode == "guild" and not self:IsGuildAvailable() then mode = "off" end
    db.mode = mode
    if self:IsAvailable() and mode ~= "off" then
        YUI.Module:Enable(MODULE_ID)
    else
        YUI.Module:Disable(MODULE_ID)
    end
    YUI.Event:Emit("YUI_AUTO_REPAIR_CHANGED")
end

function Service:ToggleMode()
    local mode = self:GetMode()
    self:SetMode(mode == "off" and (self:IsGuildAvailable() and "guild" or "personal")
        or mode == "guild" and "personal" or "off")
end

function Service:GetNotify()
    local db = self:GetConfig()
    return not db or db.notify ~= false
end

function Service:SetNotify(value)
    local db = self:GetConfig()
    if db then db.notify = value == true end
    YUI.Event:Emit("YUI_AUTO_REPAIR_CHANGED")
end

local GUILD_REPAIR_MESSAGE_COLOR = "|cff40ff40"
local PERSONAL_REPAIR_FALLBACK_COLOR = "|cffffffff"
local MONEY_GOLD_SYMBOL = GOLD_AMOUNT_SYMBOL and ("|cffffd700" .. GOLD_AMOUNT_SYMBOL .. "|r") or ""
local MONEY_SILVER_SYMBOL = SILVER_AMOUNT_SYMBOL and ("|cffd0d0d0" .. SILVER_AMOUNT_SYMBOL .. "|r") or ""
local MONEY_COPPER_SYMBOL = COPPER_AMOUNT_SYMBOL and ("|cffc77050" .. COPPER_AMOUNT_SYMBOL .. "|r") or ""

local function FormatRepairMoney(amount)
    amount = floor(amount or 0)
    local gold = floor(amount / 10000)
    local silver = floor(math.fmod(amount / 100, 100))
    local copper = floor(math.fmod(amount, 100))

    local moneyString = ""
    if gold > 0 then
        moneyString = BreakUpLargeNumbers(gold) .. MONEY_GOLD_SYMBOL
    end
    if silver > 0 then
        if moneyString ~= "" then moneyString = moneyString .. " " end
        moneyString = moneyString .. silver .. MONEY_SILVER_SYMBOL
    end
    if copper > 0 or moneyString == "" then
        if moneyString ~= "" then moneyString = moneyString .. " " end
        moneyString = moneyString .. copper .. MONEY_COPPER_SYMBOL
    end
    return moneyString
end

local function GetPlayerClassColorCode()
    local color
    if UnitAPI and UnitAPI.GetUnitClassColor then
        color = UnitAPI.GetUnitClassColor("player")
    elseif UnitAPI and UnitAPI.UnitClass and UnitAPI.GetClassColor then
        local _, classFile = UnitAPI.UnitClass("player")
        color = UnitAPI.GetClassColor(classFile)
    end

    if color and color.GenerateHexColor then
        local hex = color:GenerateHexColor()
        if type(hex) == "string" and hex ~= "" then
            return "|c" .. hex
        end
    end

    return PERSONAL_REPAIR_FALLBACK_COLOR
end

local function GetRepairMessageColor(key)
    if key == "auto_repair.message.guild_repair_done" then
        return GUILD_REPAIR_MESSAGE_COLOR
    elseif key == "auto_repair.message.personal_repair_done" then
        return GetPlayerClassColorCode()
    end
    return PERSONAL_REPAIR_FALLBACK_COLOR
end

local function FormatRepairMessage(key, amount)
    return format(GetRepairMessageColor(key) .. (L[key] or "%s") .. "|r", "|r" .. FormatRepairMoney(amount))
end


function Service:TryRepair()
    if not self:IsAvailable() then return end
    local mode = self:GetMode()
    if mode == "off" or not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end
    local guild = mode == "guild" and CanGuildBankRepair and CanGuildBankRepair()
    if guild then RepairAllItems(true) else RepairAllItems() end
    if PlaySound and SOUNDKIT and SOUNDKIT.ITEM_REPAIR then PlaySound(SOUNDKIT.ITEM_REPAIR) end
    if self:GetNotify() and YUI.Print then
        YUI:Print(FormatRepairMessage(guild and "auto_repair.message.guild_repair_done"
            or "auto_repair.message.personal_repair_done", cost))
    end
end

function Service:GetOptions(width)
    local modes = { { text = self:GetModeText("off"), value = "off" } }
    if self:IsGuildAvailable() then modes[#modes + 1] = { text = self:GetModeText("guild"), value = "guild" } end
    modes[#modes + 1] = { text = self:GetModeText("personal"), value = "personal" }
    local function hidden() return not Service:IsAvailable() end
    return {
        { type = "divider", label = L["auto_repair.header"], alignLeft = true, width = width or 600, hidden = hidden },
        { type = "dropdown", label = L["auto_repair.header"], width = 220, default = DEFAULT_MODE, options = modes,
            get = function() return Service:GetMode() end,
            set = function(value) Service:SetMode(value) end, hidden = hidden },
        { type = "checkbox", label = L["auto_repair.notify"], default = true,
            get = function() return Service:GetNotify() end,
            set = function(value) Service:SetNotify(value) end, hidden = hidden },
    }
end

YUI.Module:Register({
    id = MODULE_ID,
    owner = Service,
    dependencies = { "core.db", "core.event", "core.locale" },
    getEnabled = function() return Service:IsAvailable() and Service:GetMode() ~= "off" end,
    OnInitialize = function()
        -- Profile callbacks follow the settings owner, never the first CoreEmbed carrier.
        YUI.Module:Get(MODULE_ID).product = Service:GetOwnerProduct() or YUI.ProductId
    end,
    OnEnable = function()
        YUI.Event:OffOwner(Service)
        YUI.Event:On("MERCHANT_SHOW", "TryRepair", Service)
    end,
    OnDisable = function() YUI.Event:OffOwner(Service) end,
})
