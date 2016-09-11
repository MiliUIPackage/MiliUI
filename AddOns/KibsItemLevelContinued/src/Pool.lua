local _, addonNamespace = ...

local Pool = {}
Pool.__index = Pool

addonNamespace.Pool = Pool

function Pool:new(categorizeCallback, allocateCallback, reuseCallback, releaseCallback)
    return setmetatable({
        categorizeCallback = categorizeCallback,
        allocateCallback = allocateCallback,
        reuseCallback = reuseCallback,
        releaseCallback = releaseCallback,
        allocated = {},
        released = {},
        defaultCategory = {},
    }, self)
end

function Pool:Allocate(...)
    local category = self.categorizeCallback(...) or self.defaultCategory
    local result

    if self.released[category] and #self.released[category] > 0 then
        result = table.remove(self.released[category])
        self.allocated[result] = category
        self.reuseCallback(result, ...)
    else
        result = self.allocateCallback(...)
        self.allocated[result] = category
    end

    return result
end

function Pool:Release(ref)
    if not self.allocated[ref] then
        error("Pool:Release failed: bad reference")
    end

    local category = self.allocated[ref]

    self.allocated[ref] = nil

    if not self.released[category] then
        self.released[category] = {}
    end

    table.insert(self.released[category], ref)

    self.releaseCallback(ref)
end