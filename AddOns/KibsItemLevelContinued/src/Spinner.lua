local addonName, addonNamespace = ...

local Spinner = {}
Spinner.__index = Spinner

function Spinner:new(parent)
    local frame = CreateFrame("FRAME", nil, parent, addonName.."Spinner")

    return setmetatable({
        frame = frame,
    }, self)
end

local pool = addonNamespace.Pool:new(
    function (...)
        return nil
    end,
    function (parent)
        return Spinner:new(parent)
    end,
    function (ref, parent)
        ref.frame:SetParent(parent)
    end,
    function (ref)
        ref.frame:SetParent(nil)
    end
)

addonNamespace.AllocateSpinner = function (parent)
    return pool:Allocate(parent)
end

addonNamespace.ReleaseSpinner = function (ref)
    pool:Release(ref)
end