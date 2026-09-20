do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
YUI = YUI or _G.YUI
local Sources = YUI and YUI.Monitor and YUI.Monitor.CommonSources
if not Sources then return end
-- Category membership is not evidence of a shared native cooldown.
local groups = {
    ['health-potion'] = { 271883, 271884, 241304, 241305, 241298, 241299 },
    ['burst-potion'] = { 241308, 241309, 241288, 241289, 271887, 271886,
        241292, 241293, 271890, 271889, 241296, 241297 },
}
local families = {
    [271883] = { 271883, 271884 }, [241304] = { 241304, 241305 }, [241298] = { 241298, 241299 },
    [241308] = { 241308, 241309 }, [241288] = { 241288, 241289 }, [271887] = { 271887, 271886 },
    [241292] = { 241292, 241293 }, [271890] = { 271890, 271889 }, [241296] = { 241296, 241297 },
    [241286] = { 241286, 241287 }, [241300] = { 241300, 241301 }, [241294] = { 241294, 241295 },
    [241306] = { 241306, 241307 }, [241338] = { 241338, 241339 }, [241302] = { 241302, 241303 },
}
function Sources:GetItemFamily(id)
    if YUI.IsRetail and families[id] then return self:DescribeItemGroup(families[id], 'all-owned-ready') end
end
function Sources:GetPresetItemGroup(id)
    if not YUI.IsRetail then return nil, 'unsupported-item-group-client' end
    local ids = groups[id]
    if not ids then return nil, 'unknown-item-group' end
    return self:DescribeItemGroup(ids, 'all-owned-ready')
end
