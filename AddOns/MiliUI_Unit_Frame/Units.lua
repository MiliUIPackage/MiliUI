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
