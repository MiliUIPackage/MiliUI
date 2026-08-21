local ADDON_NAME = ...

local PRODUCT_ID = "auction_helper"
local PRODUCT_TITLE = "Auction Helper · YanForge"
local PRODUCT_VERSION = "yah-106"
local PRODUCT_LOGO = "icons\\logo_256.png"
local CORE_MODE = "embedded"
local SETTINGS_SCOPE = "auction_helper"
local PRODUCT_SETTINGS = { enabled = false }
local PRODUCT_DB = { enabled = true, savedVariable = "YUI_AuctionHelper_DB", storageKey = "AuctionHelper" }
local PRODUCT_COMMANDS = { { alias = "/yah", aliases = { "/yauctionhelper" }, action = "openSettings" } }
local REQUIRED_CORE_VERSION = 1
local EMBEDDED_CORE_VERSION = 1

local states = _G.YUI_CORE_EMBED_STATE
if not states then
    states = {}
    _G.YUI_CORE_EMBED_STATE = states
end

local state = {
    addonName = ADDON_NAME,
    productId = PRODUCT_ID,
    productTitle = PRODUCT_TITLE,
    productVersion = PRODUCT_VERSION,
    productLogo = PRODUCT_LOGO,
    coreMode = CORE_MODE,
    settingsScope = SETTINGS_SCOPE,
    settings = PRODUCT_SETTINGS,
    db = PRODUCT_DB,
    commands = PRODUCT_COMMANDS,
    requiredCoreVersion = REQUIRED_CORE_VERSION,
    embeddedCoreVersion = EMBEDDED_CORE_VERSION,
    loadCore = false,
    productEnabled = false,
}
states[ADDON_NAME] = state

local function GetCoreVersion(core)
    if not core then
        return 0
    end

    return tonumber(core.CoreVersion) or 0
end

local function Report(message)
    local function write()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555YUI|r " .. message)
        elseif print then
            print("YUI " .. message)
        end
    end

    local core = _G.YUI
    if core and core.Event and core.Event.Once then
        core.Event:Once("PLAYER_LOGIN", write)
    else
        write()
    end
end

local existingCore = _G.YUI
if existingCore then
    state.loadCore = false
    local existingCoreVersion = GetCoreVersion(existingCore)
    if existingCoreVersion >= REQUIRED_CORE_VERSION then
        state.productEnabled = true
        state.activeCoreVersion = existingCoreVersion
    else
        state.productEnabled = false
        state.activeCoreVersion = existingCoreVersion
        state.errorMessage = PRODUCT_TITLE .. " 需要 YUI Core >= " .. REQUIRED_CORE_VERSION
            .. "，当前 Core 版本为 " .. existingCoreVersion .. "。请更新所有 YUI 插件。"
        if existingCore.BlockProduct then
            existingCore:BlockProduct(PRODUCT_ID, state.errorMessage)
        end
        Report(state.errorMessage)
    end
else
    state.loadCore = true
    if EMBEDDED_CORE_VERSION >= REQUIRED_CORE_VERSION then
        state.productEnabled = true
        state.activeCoreVersion = EMBEDDED_CORE_VERSION
    else
        state.productEnabled = false
        state.activeCoreVersion = EMBEDDED_CORE_VERSION
        state.errorMessage = PRODUCT_TITLE .. " 内嵌 Core 版本过低。请重新安装当前插件。"
        Report(state.errorMessage)
    end
end

function _G.YUI_CoreEmbed_ShouldLoadCore(addonName)
    local current = states and states[addonName]
    return current and current.loadCore
end

function _G.YUI_CoreEmbed_ShouldLoadProduct(addonName)
    local current = states and states[addonName]
    return current and current.productEnabled
end
