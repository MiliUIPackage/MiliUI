------------------------------------------------------------
-- 進場：初始化 DB、spawn 所有單位框
------------------------------------------------------------
local _, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    ns.DB.Init()
    ns.Events.Start()

    -- 逐一隔離：單一單位 spawn 失敗不能拖垮其餘單位與後面的初始化
    for _, unit in ipairs(ns.UNITS) do
        xpcall(ns.SpawnUnitFrame, ns.ReportError, unit)
    end

    -- LSM 可能比我們晚載入，這裡補登記一次（自己的材質不靠它，這只是分享出去）
    if ns.Media.RegisterSharedMedia then ns.Media.RegisterSharedMedia() end

    ns.HideBlizzardFrames()

    ns.Fire("Loaded")     -- 圖騰等獨立模組在 DB 就緒後初始化

    -- tot / focustarget 沒有自己的事件，UNIT_TARGET 之外加輪詢保險
    -- （名字是秘密時 Desecret 後比對不到變化，UNIT_TARGET 事件補上主要路徑）
    ns.Metro.Add("watch_indirect", 0.5, function()
        for _, unit in ipairs({ "targettarget", "focustarget" }) do
            local uf = ns.frames[unit]
            if uf and uf:IsVisible() then
                local name = ns.Desecret(UnitName(unit), "")
                if name ~= uf.cache.name then
                    ns.Refresh(uf, "identity")
                end
            end
        end
    end)
end)

------------------------------------------------------------
-- 解析度／UI 縮放變動：像素對齊的錨點是拿 UIParent 尺寸算出來的，
-- 尺寸一變就得整組重算，否則所有框會集體偏掉
------------------------------------------------------------
local function RepositionAll()
    if InCombatLockdown() then ns.needReposition = true; return end
    for _, uf in pairs(ns.frames) do
        ns.ApplyFramePosition(uf)
    end
end
ns.Events.Register("UI_SCALE_CHANGED", "reposition_scale", RepositionAll)
ns.Events.Register("DISPLAY_SIZE_CHANGED", "reposition_display", RepositionAll)
ns.Events.Register("PLAYER_REGEN_ENABLED", "reposition_regen", function()
    if ns.needReposition then
        ns.needReposition = nil
        RepositionAll()
    end
end)
