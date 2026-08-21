do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.productEnabled then
        return
    end
end
local _, ns = ...

local GUI2 = ns and ns.GUI2
local Appearance = GUI2 and GUI2.WindowAppearance
if not Appearance then return end

ns.AuctionHelperAppearance = Appearance
return Appearance
