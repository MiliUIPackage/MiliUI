------------------------------------------------------------
-- 單位框工廠與刷新主流程
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

------------------------------------------------------------
-- 元件基座（建立容器 / 套用外觀）
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
--
-- 效能上量過了，不要再拿出來討論：xpcall 相對裸呼叫每次多約 0.035 µs（+26%），
-- 而單單「重畫一次目標框的八條文字」就要 8.8 µs。這裡的成本是雜訊，
-- 換到的錯誤隔離值錢得多。
local function SafeUpdate(def, uf, edb, bucket)
    xpcall(def.update, ns.ReportError, uf, edb, bucket)
end

------------------------------------------------------------
-- 同幀去重
--
-- UNIT_HEALTH / UNIT_MAXHEALTH / UNIT_ABSORB_AMOUNT_CHANGED /
-- UNIT_HEAL_ABSORB_AMOUNT_CHANGED 全部對到 health 桶，同一幀四個都來就會跑四次
-- 完整的 health 更新（cache 消毒 ＋ 血條計算器 ＋ 目標框八條文字 tag）。
-- 一幀一個世代編號，同一 (框, 桶) 在同一幀只跑一次。
--
-- 我們每次都是「重讀當下的值」而不是套用差量，所以併掉中間那幾次不會漏資訊。
------------------------------------------------------------
local paintGen, lastGenTime = 0, 0

local function Gen()
    local now = GetTime()
    if now ~= lastGenTime then
        paintGen = paintGen + 1
        lastGenTime = now
    end
    return paintGen
end

-- force = 跳過去重（設定套用要保證畫下去，不能被同幀稍早的刷新吃掉）
function ns.Refresh(uf, bucket, force)
    if not force then
        local stamps = uf.paintStamps
        if not stamps then stamps = {}; uf.paintStamps = stamps end
        local gen = Gen()
        if stamps[bucket] == gen then return end
        -- 換人是全量重畫，不能被同幀稍早的數值重畫蓋掉 → 先清掉所有戳記
        if bucket == "unitchanged" then wipe(stamps) end
        stamps[bucket] = gen
    end

    if not uf.isPreview then          -- 預覽孿生的 cache 由 Preview 模組維護（全假資料）
        ns.Cache.Update(uf, bucket)
    end
    if bucket == "unitchanged" then
        -- 只有這個桶跑所有元件：框現在看的是另一個單位，每個元件都要重接
        for _, def in ipairs(ns.ElementOrder) do
            local edb = uf.db.elements and uf.db.elements[def.name]
            if edb and edb.enabled ~= false and uf.elements[def.name] and def.update then
                SafeUpdate(def, uf, edb, "unitchanged")
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

------------------------------------------------------------
-- 換單位 token（進出載具）
--
-- 暴雪的 secure 端在 toggleForVehicle 開著時會自己把「點擊要打誰」換掉，
-- 那是讀取時計算（SecureButton_GetModifiedUnit），不需要寫任何受保護屬性，
-- 所以戰鬥中也成立。這裡處理的是**顯示面**：把 uf.unit 換掉再全量重畫。
--
-- 暴雪的規則是 player ↔ pet 對調：進載具後玩家框的 modified unit 會變成 "pet"
-- （載具坐在寵物欄），寵物框的變成 "player"。所以玩家框那邊要再翻譯成 "vehicle"。
------------------------------------------------------------
local function ResolveUnit(uf)
    if not (SecureButton_GetUnit and SecureButton_GetModifiedUnit) then return uf.baseUnit end
    local real = SecureButton_GetUnit(uf)
    local mod  = SecureButton_GetModifiedUnit(uf)
    if real == "playerpet" then real = "pet" end
    if mod == "playerpet" then mod = "pet" end
    if mod == "playertarget" then mod = "target" end
    -- real 不是 pet 卻被解成 pet ⇒ 這個框現在站的是載具
    if mod == "pet" and real ~= "pet" then mod = "vehicle" end
    return mod or real or uf.baseUnit
end

function ns.EvalActiveUnit(uf)
    if not uf then return end
    local resolved = ResolveUnit(uf)
    if not resolved or resolved == uf.unit then return end
    -- ⚠ 不要認一個還不存在的單位。進載具時 "vehicle" 在轉場**開始**就解得出來，
    -- 但那時還查不到資料，認下去會畫出一片空白，而之後每個載具事件都會因為
    -- resolved == uf.unit 而 no-op，整趟車就一直空著。留著舊 token 讓它在下一個
    -- 轉場邊緣再試一次，那次才有真資料。base unit 例外——它必須永遠認得下去。
    if resolved ~= uf.baseUnit and not UnitExists(resolved) then return end

    uf.unit = resolved
    uf.cache.unit = resolved
    -- 有自己存一份 unit 的元件要跟著換（castbar、光環容器）
    for _, def in ipairs(ns.ElementOrder) do
        if def.setunit and uf.elements[def.name] then
            xpcall(def.setunit, ns.ReportError, uf, resolved)
        end
    end
    ns.Refresh(uf, "unitchanged")
end

function ns.RefreshAll(bucket)
    for _, uf in pairs(ns.frames) do
        if uf:IsVisible() then
            ns.Refresh(uf, bucket or "unitchanged")
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
    uf.baseUnit = unit          -- 載具切換會改 uf.unit，這個永遠是原始 token
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
    -- 載具：讓 secure 端在點擊時自己把 player ↔ pet 對調（讀取時計算，不寫屬性，
    -- 所以戰鬥中也有效）。顯示面由 ns.EvalActiveUnit 跟上，見那裡的說明。
    uf:SetAttribute("toggleForVehicle", true)
    -- secure 端搬動 unit 屬性時同步顯示面
    uf:HookScript("OnAttributeChanged", function(self, attr)
        if attr == "unit" or attr == "toggleForVehicle" then
            ns.EvalActiveUnit(self)
        end
    end)

    -- Clique / 點擊施法整合
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[uf] = true

    ns.ApplyFramePosition(uf)
    ns.BuildElements(uf)

    -- 單位出現時（RegisterUnitWatch 驅動 Show）做全量刷新
    uf:SetScript("OnShow", function(self)
        ns.Refresh(self, "unitchanged")
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
        ns.Refresh(uf, "unitchanged")
    else
        uf:Hide()
        RegisterUnitWatch(uf, false)
    end

    ns.frames[unit] = uf
    -- 單位事件走這個 token 專屬的 tracker（C 端過濾）
    ns.Events.AttachUnit(uf)
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
                    -- force：設定套用必須畫下去，不能被同幀稍早的刷新去重掉
                    ns.Refresh(uf, "unitchanged", true)
                end
            elseif uf then
                UnregisterUnitWatch(uf)
                uf:Hide()
            end
        end
    end
    ns.Fire("SettingsApplied", unitKey)
end
