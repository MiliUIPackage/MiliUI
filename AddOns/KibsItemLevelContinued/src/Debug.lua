local addonName, addonNamespace = ...

local queue = {}
local printer

addonNamespace.Debug = function(...)
    if printer then
        printer(...)
    else
        table.insert(queue, { ... })
    end
end

addonNamespace.SetDebugPrinter = function(callback)
    printer = callback

    if printer then
        for _, args in ipairs(queue) do
            printer(unpack(args))
        end

        queue = {}
    end
end