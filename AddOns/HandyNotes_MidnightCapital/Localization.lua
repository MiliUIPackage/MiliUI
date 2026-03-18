local _, ns = ...

ns.L = ns.L or {}

setmetatable(ns.L, {
    __index = function(_, key)
        return key
    end,
})
