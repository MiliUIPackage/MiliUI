------------------------------------------------------------
-- 單位框工廠與刷新主流程
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

------------------------------------------------------------
-- 元件基座（對應 Stuf CreateBase / UpdateBaseLook）
------------------------------------------------------------
-- 建立元件容器：掛在 uf 底下、TOPLEFT 相對定位
function ns.CreateElementBase(uf, name, frameType, template)
    local f = CreateFrame(frameType or "Frame", nil, uf, template or "BackdropTemplate")
    f.ename = name
    uf.elements[name] = f
    return f
end

-- 套用基本版面：尺寸/位置/層級全部來自設定，絕不回讀
-- 尺寸與位移都對齊實體像素：設定值是「版面單位」，在 Retina／UI 縮放不是 1 的機器上
-- 會落在半個實體像素上，元件邊緣就會糊掉、1px 細線變成忽粗忽細。四捨五入到最近的
-- 實體像素邊界（位移量最多動半個實體像素，肉眼看不出來，但邊緣會變乾淨）。
local Scale = function(v) return ns.P.Scale(v or 0) end

function ns.ApplyElementBase(uf, f, edb)
    f:SetSize(Scale(edb.w or 10), Scale(edb.h or 10))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", Scale(edb.x or 0), Scale(edb.y or 0))
    f:SetFrameLevel(edb.level or 3)
    f:SetAlpha(edb.alpha or 1)
end

------------------------------------------------------------
-- 刷新
------------------------------------------------------------
-- 12.1 教訓：dispatch 迴圈一律逐一隔離——一個元件拋錯不能拖垮同迴圈的其他元件
-- （錯誤照常進 BugSack，鏈路繼續跑）
local function SafeUpdate(def, uf, edb, bucket)
    xpcall(def.update, ns.ReportError, uf, edb, bucket)
end

function ns.Refresh(uf, bucket)
    if not uf.isPreview then          -- 預覽孿生的 cache 由 Preview 模組維護（全假資料）
        ns.Cache.Update(uf, bucket)
    end
    if bucket == "identity" then
        -- 全量：跑所有元件的 update（依序）
        for _, def in ipairs(ns.ElementOrder) do
            local edb = uf.db.elements and uf.db.elements[def.name]
            if edb and edb.enabled ~= false and uf.elements[def.name] and def.update then
                SafeUpdate(def, uf, edb, "identity")
            end
        end
        return
    end
    local members = ns.BucketMembers[bucket]
    if not members then return end
    for _, def in ipairs(members) do
        local edb = uf.db.elements and uf.db.elements[def.name]
        if edb and edb.enabled ~= false and uf.elements[def.name] then
            SafeUpdate(def, uf, edb, bucket)
        end
    end
end

function ns.RefreshAll(bucket)
    for _, uf in pairs(ns.frames) do
        if uf:IsVisible() then
            ns.Refresh(uf, bucket or "identity")
        end
    end
end

------------------------------------------------------------
-- 位置：CENTER 對 CENTER 偏移；boss1-5 依 growth/spacing 疊排
------------------------------------------------------------
function ns.ApplyFramePosition(uf)
    if InCombatLockdown() then return end   -- uf 是 protected frame
    local fdb = uf.db.frame
    local x, y = fdb.x or 0, fdb.y or 0
    if uf.bossIndex and uf.bossIndex > 1 then
        local spacing = fdb.spacing or 47
        if fdb.growth == "UP" then
            y = y + (uf.bossIndex - 1) * spacing
        else
            y = y - (uf.bossIndex - 1) * spacing
        end
    end
    -- 單位框自己也要對齊實體像素：它沒對齊的話，底下所有元件再怎麼對齊都白搭。
    --
    -- ⚠ 不能直接 CENTER 對 CENTER 再 P.Scale 偏移量：P.Scale 只會把「長度」湊成整數
    -- 實體像素，管不到起算點。UIParent 的中心本身就可能落在半個像素上，框寬又是奇數
    -- 像素時左右邊緣還會各再偏半格 → 邊緣糊掉。
    -- 改成從 UIParent 的 BOTTOMLEFT 起算：那是螢幕原點 (0,0)，保證在像素邊界上，
    -- 把左下角座標對齊之後，寬高又都是整數像素 ⇒ 四邊全部落在邊界。
    -- 設定值語意不變（仍是「框中心相對畫面中心的偏移」），只是換算後再錨定。
    local w, h = ns.P.Scale(fdb.w or 100), ns.P.Scale(fdb.h or 30)
    uf:SetSize(w, h)
    uf:ClearAllPoints()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    uf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
                ns.P.Scale(pw / 2 + x - w / 2),
                ns.P.Scale(ph / 2 + y - h / 2))
    uf:SetFrameStrata(ns.db.global.strata or "LOW")
end

------------------------------------------------------------
-- 建構元件（冪等；設定變更後整組重跑）
------------------------------------------------------------
function ns.BuildElements(uf)
    for _, def in ipairs(ns.ElementOrder) do
        local edb = uf.db.elements and uf.db.elements[def.name]
        if edb then
            if edb.enabled ~= false then
                -- 逐一隔離：一個元件 build 炸掉，其他元件照常建
                xpcall(def.build, ns.ReportError, uf, edb)
            elseif uf.elements[def.name] then
                if def.disable then def.disable(uf) end
                uf.elements[def.name]:Hide()
            end
        end
    end
end

------------------------------------------------------------
-- Spawn
------------------------------------------------------------
function ns.SpawnUnitFrame(unit)
    if ns.frames[unit] then return ns.frames[unit] end
    local unitKey = ns.UNIT_KEYS[unit]
    local udb = ns.GetUnitDB(unitKey)
    if not udb or not udb.enabled then return end

    local uf = CreateFrame("Button", ns.GLOBAL_NAMES[unit], UIParent,
                           "SecureUnitButtonTemplate,BackdropTemplate")
    uf.unit = unit
    uf.unitKey = unitKey
    uf.db = udb
    uf.cache = { unit = unit }
    uf.elements = {}
    if unitKey == "boss" then
        uf.bossIndex = tonumber(unit:match("boss(%d)"))
    end

    uf:RegisterForClicks("AnyUp")
    uf:SetAttribute("*type1", "target")
    uf:SetAttribute("type2", "togglemenu")     -- R1：12.1 行為待遊戲內驗證
    uf:SetAttribute("unit", unit)

    -- Clique / 點擊施法整合
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[uf] = true

    ns.ApplyFramePosition(uf)
    ns.BuildElements(uf)

    -- 單位出現時（RegisterUnitWatch 驅動 Show）做全量刷新
    uf:SetScript("OnShow", function(self)
        ns.Refresh(self, "identity")
    end)

    -- 滑鼠提示（暴雪單位提示；EUI/暴雪同法）。OnEnter/OnLeave 不是受保護腳本，
    -- 掛在 SecureUnitButton 上安全
    uf:SetScript("OnEnter", function(self)
        if not ns.db.global.showTooltip then return end
        if ns.db.global.tooltipHideInCombat and InCombatLockdown() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not GameTooltip:SetUnit(self.unit) then
            GameTooltip:Hide()
        end
    end)
    uf:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    if unit == "player" then
        uf:Show()
        ns.Refresh(uf, "identity")
    else
        uf:Hide()
        RegisterUnitWatch(uf, false)
    end

    ns.frames[unit] = uf
    return uf
end

------------------------------------------------------------
-- 設定套用入口（設定 UI 唯一入口；戰鬥中排隊）
------------------------------------------------------------
local pendingApply = {}
local applyWatcher = CreateFrame("Frame")
applyWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
applyWatcher:SetScript("OnEvent", function()
    for unitKey in pairs(pendingApply) do
        pendingApply[unitKey] = nil
        ns.ApplySettings(unitKey)
    end
end)

function ns.ApplySettings(unitKey)
    if InCombatLockdown() then
        pendingApply[unitKey] = true
        return
    end
    local udb = ns.GetUnitDB(unitKey)
    local previewOpen = ns.Preview and ns.Preview.IsOpen and ns.Preview.IsOpen()
    for _, unit in ipairs(ns.UNITS) do
        if ns.UNIT_KEYS[unit] == unitKey then
            local uf = ns.frames[unit]
            if udb.enabled then
                if not uf then
                    uf = ns.SpawnUnitFrame(unit)
                    -- 預覽開著時真實框由 Preview 管：剛生出來的先藏，關窗 RestoreReal 再放出
                    if uf and previewOpen then
                        UnregisterUnitWatch(uf)
                        uf:Hide()
                    end
                elseif uf then
                    ns.ApplyFramePosition(uf)
                    ns.BuildElements(uf)
                    -- 預覽開啟時真實框由 Preview 管顯示，這裡不搶（關窗時 RestoreReal 還原）
                    if not previewOpen then
                        if unit == "player" then
                            uf:Show()
                        else
                            RegisterUnitWatch(uf, false)
                        end
                    end
                    -- 一律重畫（不再只在可見時）：顏色、文字內容這些是在 update 才套用的，
                    -- 只 build 不 refresh 會出現「改了下拉選單沒反應、動別的設定才一起生效」
                    ns.Refresh(uf, "identity")
                end
            elseif uf then
                UnregisterUnitWatch(uf)
                uf:Hide()
            end
        end
    end
    ns.Fire("SettingsApplied", unitKey)
end
