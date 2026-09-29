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

------------------------------------------------------------
-- /mcdm debug：引擎現況（開發用，字串不進語系檔）
------------------------------------------------------------
local function Debug()
    local p = print
    p(ns.PREFIX_COLOR .. "[米利冷卻 debug]|r v" .. tostring(ns.VERSION)
        .. "  設定檔=" .. tostring(ns.profileName) .. "  specID=" .. tostring(ns.specID))

    local V, C, B = ns.Viewers, ns.Catalog, ns.Bars
    if not (V and C and B) then
        p("  引擎沒有載入（互斥偵測成立或初始化失敗）")
    else
        p(("  檢視器：%s（嘗試 %d 次）  排版 %d 次  待排 %d 條  格位快取 %d")
            :format(V.ready and "已掛上" or "|cffff5555尚未就緒|r", V.Attempts(), B.flushes,
                    B.PendingCount(), B.SlotCount()))
        for _, key in ipairs(V.ORDER) do
            local viewer = V.Get(key)
            p(("  %-9s 暴雪 item %s  清單 %d  認領 %d  alpha %s")
                :format(key, viewer and tostring(V.Count(key)) or "✕",
                        #C.Bar(key), B.Count(key), tostring(ns.Visibility and ns.Visibility.Current(key))))
        end
        local p2 = ns.profile
        for key in pairs(p2 and p2.bars or {}) do
            if not V.VIEWERS[key] then
                p(("  %-9s（自訂）清單 %d  認領 %d"):format(key, #C.Bar(key), B.Count(key)))
            end
        end
        local sig = C.sig or ""
        p(("  目錄：順序來源 %s  建置 %d 次  簽章 %s%s  暫停 %s")
            :format(tostring(C.source), C.builds, sig:sub(1, 16), #sig > 16 and "…" or "",
                    tostring(C.IsPaused())))
        if #V.blocked > 0 then
            p("  被擋的寫入：" .. table.concat(V.blocked, ", "))
        end
    end
    p("  容器層待補寫入（戰鬥記帳）：" .. tostring(ns.PendingWrites()))

    local errs = ns.errors or {}
    if #errs == 0 then
        p("  錯誤：無")
    else
        p("  最近錯誤（新→舊）：")
        for i = #errs, math.max(1, #errs - 4), -1 do
            p("   |cffff5555" .. tostring(errs[i]) .. "|r")
        end
    end
end
ns.Debug = Debug

SLASH_MILIUICDM1 = "/mcdm"
SLASH_MILIUICDM2 = "/miliuicdm"
SlashCmdList.MILIUICDM = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "minimap" and ns.ready then
        local shown = not ns.IsMinimapButtonShown()
        ns.SetMinimapButtonShown(shown)
        ns.Print(shown and L["Minimap button shown."] or L["Minimap button hidden. Type /mcdm minimap to bring it back."])
    elseif msg == "debug" then
        Debug()
    else
        ns.OpenOptions()
    end
end

------------------------------------------------------------
-- 公開 API：給其他插件讀（單位框架的資源條顏色、錨定候選…）
--
-- ⚠ GetResourceColors 目前是占位（計畫的 F 階段：資源條與施法條，才會回真的值）。
--   呼叫端一律要處理 nil／false（退回自己的預設），回傳形狀之後不改。
------------------------------------------------------------
_G.MiliUI_CooldownManager = {
    -- barKey 那條資源條的顏色表；沒有就 nil。F 階段補上。
    GetResourceColors = function(barKey) return nil end,
    -- 引擎是否已經認領好四條檢視器（別的插件要錨在我們的容器上前先問）
    IsReady = function()
        return (ns.ready and ns.Viewers and ns.Viewers.ready and ns.Bars and ns.Bars.ready) and true or false
    end,
    -- 某條的容器框（MiliUICDM_Bar_<key>），給別的插件錨定用；還沒建好回 nil。
    -- ⚠ 錨上來的框會跟著這條移動；別對它 SetParent 或改它的大小。
    GetBarFrame = function(barKey)
        return ns.Bars and ns.Bars.Get(barKey) or nil
    end,
}
