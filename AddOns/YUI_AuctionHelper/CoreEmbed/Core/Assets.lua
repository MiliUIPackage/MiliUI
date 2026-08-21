do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local ADDON_NAME, YUI = ...
YUI = YUI or _G.YUI
if not YUI then return end

local Assets = YUI.Assets or {}
YUI.Assets = Assets

Assets.bundleRoots = Assets.bundleRoots or {}
Assets.componentRoots = Assets.componentRoots or {}
Assets.productRoots = Assets.productRoots or {}

local function NormalizeSlash(path)
    path = tostring(path or "")
    path = path:gsub("/", "\\")
    path = path:gsub("^\\+", "")
    return path
end

local function JoinPath(root, path)
    path = NormalizeSlash(path)
    if path == "" then
        return root
    end
    if root:sub(-1) == "\\" then
        return root .. path
    end
    return root .. "\\" .. path
end

function Assets:GetAddonRoot()
    return "Interface\\AddOns\\" .. (YUI.AddonName or ADDON_NAME or "YUI")
end

function Assets:GetMediaRoot()
    local root = self:GetAddonRoot()
    if YUI.CoreMode == "embedded" then
        return root .. "\\CoreEmbed\\Media"
    end
    return root .. "\\Media"
end

function Assets:RegisterBundleRoot(bundleId, root)
    if type(bundleId) ~= "string" or bundleId == "" or type(root) ~= "string" or root == "" then
        return false
    end
    self.bundleRoots[bundleId] = root
    self.availableBundles = self.availableBundles or {}
    self.availableBundles[bundleId] = true
    return true
end

function Assets:SetAvailableBundles(bundleIds)
    self.availableBundles = {}
    if type(bundleIds) ~= "table" then
        return false
    end
    for i = 1, #bundleIds do
        local bundleId = bundleIds[i]
        if type(bundleId) == "string" and bundleId ~= "" then
            self.availableBundles[bundleId] = true
        end
    end
    return true
end

function Assets:IsBundleAvailable(bundleId)
    if type(bundleId) ~= "string" or bundleId == "" then
        return false
    end
    if self.availableBundles then
        return self.availableBundles[bundleId] == true
    end
    return YUI.CoreMode ~= "embedded"
end

function Assets:RegisterComponentRoot(componentId, root)
    if type(componentId) ~= "string" or componentId == "" or type(root) ~= "string" or root == "" then
        return false
    end
    self.componentRoots[componentId] = root
    return true
end

function Assets:RegisterProductRoot(productId, root)
    if type(productId) ~= "string" or productId == "" or type(root) ~= "string" or root == "" then
        return false
    end
    self.productRoots[productId] = root
    return true
end

function Assets:Core(path)
    return JoinPath(self:GetMediaRoot() .. "\\Core", path)
end

function Assets:Bundle(bundleId, path)
    local root = self.bundleRoots[bundleId] or (self:GetMediaRoot() .. "\\Bundles\\" .. NormalizeSlash(bundleId))
    return JoinPath(root, path)
end

function Assets:Component(componentId, path)
    local root = self.componentRoots[componentId]
    if not root then
        root = self:GetAddonRoot() .. "\\Components\\" .. NormalizeSlash(componentId) .. "\\Media"
    end
    return JoinPath(root, path)
end

function Assets:Product(productId, path)
    local root = self.productRoots[productId]
    if not root then
        root = self:GetAddonRoot() .. "\\Products\\" .. NormalizeSlash(productId) .. "\\Media"
    end
    return JoinPath(root, path)
end

function Assets:LegacyMedia(path)
    return JoinPath(self:GetAddonRoot() .. "\\Media", path)
end
