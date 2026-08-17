------------------------------------------------------------
-- 進場：初始化 DB、spawn 所有單位框
------------------------------------------------------------
local _, ns = ...

-- tot / focustarget 沒有自己的單位事件，UNIT_TARGET 之外加輪詢當保險。
-- ⚠ 常數表放檔案層級：這個回呼一秒跑兩次，寫成 ipairs({...}) 等於每次現配一張表
local INDIRECT_UNITS = { "targettarget", "focustarget" }
local INDIRECT_KEY = "watch_indirect"

local function WatchIndirect()
    for _, unit in ipairs(INDIRECT_UNITS) do
        local uf = ns.frames[unit]
        if uf and uf:IsVisible() then
            -- 名字是秘密時 Desecret 後兩邊都是空字串，這裡比不出變化——
            -- 主要路徑是 UNIT_TARGET 事件，這只是保險（見體檢報告 C2）
            local name = ns.Desecret(UnitName(unit), "")
            if name ~= uf.cache.name then
                ns.Refresh(uf, "identity")
            end
        end
    end
end

-- 兩個框都沒顯示就把輪詢卸掉，ticker 才停得下來
local function SyncIndirectWatch()
    for _, unit in ipairs(INDIRECT_UNITS) do
        local uf = ns.frames[unit]
        if uf and uf:IsShown() then
            ns.Metro.Add(INDIRECT_KEY, 0.5, WatchIndirect)
            return
        end
    end
    ns.Metro.Remove(INDIRECT_KEY)
end

-- 框可能是登入後才被啟用（設定裡打開）才生出來的，所以掛勾要能重跑；
-- 每個框自己記一個旗標避免疊上去
local function HookIndirectWatch()
    for _, unit in ipairs(INDIRECT_UNITS) do
        local uf = ns.frames[unit]
        if uf and not uf.indirectHooked then
            uf.indirectHooked = true
            uf:HookScript("OnShow", SyncIndirectWatch)
            uf:HookScript("OnHide", SyncIndirectWatch)
        end
    end
    SyncIndirectWatch()
end

ns.RegisterCallback("SettingsApplied", "watch_indirect", HookIndirectWatch)

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

    -- tot / focustarget 的輪詢保險：掛在兩個框的顯示狀態上
    HookIndirectWatch()
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
