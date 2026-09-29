------------------------------------------------------------
-- 對外出口：slash、AddonCompartment、公開 API
------------------------------------------------------------
local _, ns = ...

local L = ns.L

-- 設定介面入口。互斥偵測成立時整支插件沒初始化，改成再彈一次二選一的視窗。
function ns.OpenOptions(pageId)
    if ns.conflict then
        ns.ShowConflictPopup()
    elseif ns.ready and ns.Options and ns.Options.Open then
        ns.Options.Open(pageId)
    else
        ns.Print(L["Options UI failed to load."])
    end
end

-- 小地圖旁插件選單（AddonCompartment）
function MiliUICDM_OnAddonCompartmentClick()
    ns.OpenOptions()
end

SLASH_MILIUICDM1 = "/mcdm"
SLASH_MILIUICDM2 = "/miliuicdm"
SlashCmdList.MILIUICDM = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "minimap" and ns.ready then
        local shown = not ns.IsMinimapButtonShown()
        ns.SetMinimapButtonShown(shown)
        ns.Print(shown and L["Minimap button shown."] or L["Minimap button hidden. Type /mcdm minimap to bring it back."])
    else
        ns.OpenOptions()
    end
end

------------------------------------------------------------
-- 公開 API：給其他插件讀（單位框架的資源條顏色、錨定候選…）
--
-- ⚠ 目前是占位（計畫的 F 階段：資源條與施法條，才會回真的值；IsReady 在 B 階段引擎接上）。呼叫端一律要處理 nil／false
--   （退回自己的預設），這兩支的回傳形狀之後不改。
------------------------------------------------------------
_G.MiliUI_CooldownManager = {
    -- barKey 那條資源條的顏色表；沒有就 nil。F 階段補上。
    GetResourceColors = function(barKey) return nil end,
    -- 引擎是否已經認領好四條檢視器（別的插件要錨在我們的容器上前先問）。B 階段補上。
    IsReady = function() return false end,
}
