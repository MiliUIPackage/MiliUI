do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = YUI or _G.YUI
if YUI and YUI.Assets and YUI.Assets.SetAvailableBundles then
    YUI.Assets:SetAvailableBundles({ "sharedmedia-statusbars" })
end