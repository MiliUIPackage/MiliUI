local ADDON_NAME = ...
local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[ADDON_NAME]
if state and not state.productEnabled then
    return
end

local YUI = _G.YUI
if not YUI then
    return
end

local PRODUCT_ID = "auction_helper"
local PRODUCT_TITLE = "Auction Helper · YanForge"
local PRODUCT_LOGO = "icons\\logo_256.png"
local OWNED_GLOBALS = {}
local PRODUCT_SETTINGS = { enabled = false }
local PRODUCT_DB = { enabled = true, savedVariable = "YUI_AuctionHelper_DB", storageKey = "AuctionHelper" }
local PRODUCT_COMMANDS = { { alias = "/yah", aliases = { "/yauctionhelper" }, action = "openSettings" } }
local PRODUCT_ASSET_FOLDERS = { "Components\\AuctionHelper\\Media" } or {}
local PRODUCT_COMPONENT = { id = "AuctionHelper", settingsMode = "toggleOnly" }
local PRODUCT_COMPONENTS = nil or {}
local SUITE_EXCLUSIVE = nil == true

local function Report(message)
    local function write()
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555YUI|r " .. message)
        elseif print then
            print("YUI " .. message)
        end
    end

    if YUI.Event and YUI.Event.Once then
        YUI.Event:Once("PLAYER_LOGIN", write)
    else
        write()
    end
end

local function BlockProduct(reason, blockRegisteredProduct)
    if state then
        state.productEnabled = false
        state.errorMessage = reason
    end

    if blockRegisteredProduct and YUI.BlockProduct then
        YUI:BlockProduct(PRODUCT_ID, reason)
    end
    YUI.BlockedAddons = YUI.BlockedAddons or {}
    YUI.BlockedAddons[ADDON_NAME] = reason or true

    Report(reason)
end

if SUITE_EXCLUSIVE and YUI.CoreMode == "suite" then
    BlockProduct("完整 YUI 已启用，当前工具箱单体已停止加载。", false)
    return
end

local existingProduct = YUI.Products and YUI.Products[PRODUCT_ID]
if existingProduct and existingProduct.addonName ~= ADDON_NAME then
    BlockProduct(PRODUCT_TITLE .. " 已经由另一个 YUI 插件注册，当前副本已停止加载。", false)
    return
end

local componentId = PRODUCT_COMPONENT and PRODUCT_COMPONENT.id
local existingComponent = componentId
    and YUI.Components
    and YUI.Components.Get
    and YUI.Components:Get(componentId)
if existingComponent then
    BlockProduct(PRODUCT_TITLE .. " 已经由 YUI 整合包中的同名组件提供，当前单体副本已停止加载。", false)
    return
end

for i = 1, #OWNED_GLOBALS do
    local key = OWNED_GLOBALS[i]
    if YUI[key] ~= nil then
        BlockProduct(PRODUCT_TITLE .. " 检测到已有 YUI." .. key .. "，当前副本已停止加载。请避免同时启用整合包和同名单体包。", false)
        return
    end
end

if YUI.Assets and YUI.Assets.RegisterProductRoot then
    for i = 1, #PRODUCT_ASSET_FOLDERS do
        local folder = PRODUCT_ASSET_FOLDERS[i]
        if type(folder) == "string" and folder ~= "" then
            local root = "Interface\\AddOns\\" .. ADDON_NAME .. "\\" .. folder
            YUI.Assets:RegisterProductRoot(PRODUCT_ID, root)
            if PRODUCT_COMPONENT and PRODUCT_COMPONENT.id and YUI.Assets.RegisterComponentRoot then
                YUI.Assets:RegisterComponentRoot(PRODUCT_COMPONENT.id, root)
            end
            break
        end
    end

    if YUI.Assets.RegisterComponentRoot then
        for i = 1, #PRODUCT_COMPONENTS do
            local component = PRODUCT_COMPONENTS[i]
            if component and type(component.id) == "string" and component.id ~= ""
                and type(component.sourceRoot) == "string" and component.sourceRoot ~= "" then
                local root = "Interface\\AddOns\\" .. ADDON_NAME .. "\\" .. component.sourceRoot .. "\\Media"
                YUI.Assets:RegisterComponentRoot(component.id, root)
            end
        end
    end
end

local product = {
    addonName = ADDON_NAME,
    id = PRODUCT_ID,
    title = PRODUCT_TITLE,
    titleKey = "product.title",
    titleNamespace = "AuctionHelper",
    localizedTitles = { zhCN = "购物助手 · 言工坊", zhTW = "購物助手 · 言工坊" },
    shortTitle = "",
    shortTitleKey = "",
    shortTitleNamespace = "",
    localizedShortTitles = nil,
    logo = PRODUCT_LOGO,
    version = "yah-106",
    coreMode = "embedded",
    requiredCoreVersion = 1,
    embeddedCoreVersion = 1,
    settingsScope = "auction_helper",
    author = "阿言",
    notes = "购物助手 · 言工坊",
    notesKey = "product.notes",
    notesNamespace = "AuctionHelper",
    localizedNotes = { zhCN = "购物助手 · 言工坊", zhTW = "購物助手 · 言工坊" },
    profileExportPrefix = "!YUI-AuctionHelper-v2:",
    settings = PRODUCT_SETTINGS,
    component = PRODUCT_COMPONENT,
    components = PRODUCT_COMPONENTS,
    db = PRODUCT_DB,
    commands = PRODUCT_COMMANDS,
}

if YUI.RegisterProduct then
    YUI:RegisterProduct(product)
else
    YUI.Products = YUI.Products or {}
    YUI.Products[product.id] = product
end
