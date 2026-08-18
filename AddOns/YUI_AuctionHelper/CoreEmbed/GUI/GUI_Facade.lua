local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
local GUI2 = YUI and YUI.GUI2

if not GUI2 then
    return
end

-- Phase 5H: YUI.GUI is now the public GUI2 entry. Legacy adapter fallback is removed.
YUI.GUI = GUI2

GUI2.PublicEntry = "YUI.GUI"
GUI2.PromotedToGUI = true

function GUI2:IsFacade()
    return false
end

function GUI2:GetGUI2()
    return self
end

function GUI2:HasGUI2()
    return true
end
