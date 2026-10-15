do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
local CL = YUI.Changelog or {}
YUI.Changelog = CL
CL.recordsByProduct = CL.recordsByProduct or {}

function CL:Register(productId, records)
    self.recordsByProduct[productId] = records
    if productId == "suite" then self.RawData = records end
end

function CL:LoadData(productId)
    productId = productId or "suite"
    return self.recordsByProduct[productId] or (productId == "suite" and self.RawData) or {}
end

function CL:GetLanguage()
    local locale = GetLocale and GetLocale() or "zhCN"
    return (locale == "zhCN" or locale == "zhTW") and "zhCN" or "enUS"
end

local function MatchesClient(entry)
    local client = YUI.GameVersion or "Retail"
    if entry.client then return entry.client == client end
    if not entry.clients then return true end
    for _, value in ipairs(entry.clients) do
        if value == client then return true end
    end
    return false
end

function CL:HasData(productId)
    for _, entry in ipairs(self:LoadData(productId)) do
        if MatchesClient(entry) then return true end
    end
    return false
end

function CL:GetData(maxVersions, productId)
    local result, included, count = {}, {}, 0
    local limit = tonumber(maxVersions) or 10
    local language = self:GetLanguage()
    for _, entry in ipairs(self:LoadData(productId)) do
        if MatchesClient(entry) then
            if not included[entry.version] then
                if count >= limit then break end
                included[entry.version], count = true, count + 1
            end
            local content = entry.content[language] or (#entry.content > 0 and language == "zhCN" and entry.content)
            if content and #content > 0 then
                result[#result + 1] = { version = entry.version, date = entry.date, content = content }
            end
        end
    end
    return result
end

function CL:HasUntranslatedHistory(productId)
    if self:GetLanguage() ~= "enUS" then return false end
    for _, entry in ipairs(self:LoadData(productId)) do
        if MatchesClient(entry) and (not entry.content.enUS or #entry.content.enUS == 0) then return true end
    end
    return false
end

function CL:CompareVersion(first, second)
    if not first or not second or first == second then return 0 end
    local function parts(version)
        local value = version:match("^[%a][%w]*%-(%d+)$") or version:match("^[vV](%d[%d%.]*)%a?$")
        if not value then return nil end
        local result = {}
        for number in value:gmatch("%d+") do result[#result + 1] = tonumber(number) end
        return result
    end
    local a, b = parts(first), parts(second)
    if not a or not b then return 0 end
    for index = 1, math.max(#a, #b) do
        local left, right = a[index] or 0, b[index] or 0
        if left ~= right then return left > right and 1 or -1 end
    end
    return 0
end

function CL:MarkAsSeen(version, productId)
    productId = productId or "suite"
    local db = YUI.DB
    local global = db and db.IsReady and db:IsReady() and db:GetGlobal(productId)
        or (productId == "suite" and YUI.global)
    if global then global.lastChangelogVersion = version end
end
