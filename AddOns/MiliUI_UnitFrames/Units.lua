------------------------------------------------------------
-- 進場：初始化 DB、spawn 所有單位框
------------------------------------------------------------
local _, ns = ...

-- tot / focustarget 沒有自己的單位事件，UNIT_TARGET 之外加輪詢當保險。
-- ⚠ 常數表放檔案層級：這個回呼一秒跑兩次，寫成 ipairs({...}) 等於每次現配一張表
local INDIRECT_UNITS = { "targettarget", "focustarget" }
local INDIRECT_KEY = "watch_indirect"

-- 換人偵測用 GUID，不要用名字：
--   * 名字會撞（同一批小怪全都同名），GUID 不會
--   * 名字是秘密值時 Desecret 後兩邊都變成空字串，永遠比不出變化 —— 那是
--     **fail closed**，框會停在上一個單位。失敗方向要朝「重畫」而不是「不動」。
--
-- GUID 自己也可能是秘密（受限身分單位）。那種情況比不出來，只能一律當作換人了；
-- 但 ns.Refresh(uf,"unitchanged") 目前是全量重畫（會彈光環容器、重載 3D 模型），
-- 每 0.5 秒來一次太貴 → 秘密時降到每 SECRET_EVERY 次輪詢才重畫一次。
-- identity 拆桶（體檢報告 P2）之後這個節流就可以拿掉。
-- 主要路徑仍然是 UNIT_TARGET 事件，這整段只是保險。
local SECRET_EVERY = 4          -- ×0.5s = 2 秒

local function UnitChanged(uf, unit)
    local guid
    if UnitExists(unit) then guid = UnitGUID(unit) end     -- UnitExists 回明文布林
    local old = uf.lastGuid
    if ns.IsSecret(guid) or ns.IsSecret(old) then
        uf.lastGuid = guid
        uf.secretTicks = (uf.secretTicks or 0) + 1
        if uf.secretTicks < SECRET_EVERY then return false end
        uf.secretTicks = 0
        return true
    end
    uf.secretTicks = 0
    if guid ~= old then
        uf.lastGuid = guid
        return true
    end
    return false
end

local function WatchIndirect()
    for _, unit in ipairs(INDIRECT_UNITS) do
        local uf = ns.frames[unit]
        if uf and uf:IsVisible() and UnitChanged(uf, unit) then
            ns.Refresh(uf, "unitchanged")
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
            uf:HookScript("OnShow", function(self)
                -- OnShow 本身就會全量重畫，順手把比對基準歸零，
                -- 免得第一次輪詢拿舊單位的 GUID 比出一次多餘的重畫
                self.lastGuid, self.secretTicks = nil, 0
                SyncIndirectWatch()
            end)
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

    -- 顯示條件／淡出的初次套用。PLAYER_ENTERING_WORLD 也會做同一件事，但那是
    -- 「登入時它一定排在 PLAYER_LOGIN 後面」的假設——明寫一次就不用賭載入順序
    ns.Visibility.Refresh()

    ns.Fire("Loaded")     -- 圖騰等獨立模組在 DB 就緒後初始化

    -- tot / focustarget 的輪詢保險：掛在兩個框的顯示狀態上
    HookIndirectWatch()
end)

------------------------------------------------------------
-- 載具：進出載具時玩家框改顯示 vehicle、寵物框改顯示 player（暴雪原生框的行為）。
-- 用專屬 frame + RegisterUnitEvent 綁 player，不佔全域事件桶。
-- UNIT_PET 也要聽：載具是掛在寵物欄位上的。
------------------------------------------------------------
local vehicleWatch = CreateFrame("Frame")
vehicleWatch:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
vehicleWatch:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
vehicleWatch:RegisterUnitEvent("UNIT_PET", "player")
vehicleWatch:SetScript("OnEvent", function()
    ns.EvalActiveUnit(ns.frames.player)
    ns.EvalActiveUnit(ns.frames.pet)
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
