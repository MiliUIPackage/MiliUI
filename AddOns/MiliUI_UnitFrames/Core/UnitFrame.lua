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
    do
        local stamps = uf.paintStamps
        if not stamps then stamps = {}; uf.paintStamps = stamps end
        local gen = Gen()
        -- ⚠ 只有「跳過」那一步吃 force，戳記維護**兩條路都要跑**。
        -- 以前整段包在 `if not force` 裡，於是強制重畫既不清戳記也不留戳記：
        -- 同幀稍早畫過的 health／info 戳記還在 ⇒ 換人之後那幾個桶當幀都被擋掉，
        -- 血條與文字停在**上一個單位**的值。
        if not force and stamps[bucket] == gen then return end
        -- 換人是全量重畫，不能被同幀稍早的數值重畫蓋掉 → 先清掉所有戳記
        if bucket == "unitchanged" then wipe(stamps) end
        stamps[bucket] = gen
    end

    if not uf.isPreview then          -- 預覽孿生的 cache 由 Preview 模組維護（全假資料）
        -- ⚠ 這裡以前是裸呼叫，是整條 Refresh 上唯一沒有隔離的一步。Cache.Update 會碰
        -- 受限單位的 Unit API（那些在某些情境會直接拋錯），一拋就等於這個框當次的
        -- **所有**元件都不更新 —— 比「某個欄位讀不到」嚴重得多。
        xpcall(ns.Cache.Update, ns.ReportError, uf, bucket)
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
    -- ⚠ force：換單位一定要畫下去。同一幀稍早只要有人跑過 unitchanged（OnShow 的
    -- RegisterUnitWatch 重畫、顯示閘、輪詢的換人偵測都會），去重就會把這次整個吃掉
    -- ⇒ uf.unit 已經是 "vehicle"，cache 卻還是上一個單位的（載具期間玩家框顯示
    -- 自己的名字／職業色，而頭像已經換成載具 —— 那個「有時候好有時候壞」就是這裡）。
    -- 換單位是新資訊，同幀稍早的任何一次重畫都不可能已經涵蓋它。
    ns.Refresh(uf, "unitchanged", true)
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
-- 淡出（超出距離 ＋ 脫戰）
--
-- 超出距離要輪詢（沒有「距離變了」的事件），掛在既有的 Metro 上不另開 ticker——
-- Metro.Bind 會跟著框架的可見度上下，框藏起來就不輪詢。脫戰淡出吃事件，不需要輪詢。
--
-- ⚠ 兩種淡出**不可以各自 SetAlpha**：後設的會蓋掉前設的（先設 0.45 再設 1 ⇒ 永遠不淡）。
-- 一律交給 ns.Visibility.ApplyAlpha 算完再設一次，它取兩者最低。
------------------------------------------------------------
function ns.ApplyFrameFade(uf)
    -- ⚠ key 用 baseUnit：進載具後 uf.unit 變 "vehicle"，這時若重跑 ApplySettings
    -- 會註冊 range_vehicle，而舊的 range_player 沒人 Unbind（Unbind 只認新 key）
    -- ⇒ 留一個孤兒項目在 metroEntries 裡繼續每 0.2 秒跑
    local key = "range_" .. (uf.baseUnit or uf.unit)
    if uf.isPreview or not uf.db.frame.fadeOutOfRange then
        ns.Metro.Unbind(uf, key)
    else
        uf.rangeFn = uf.rangeFn or function() ns.Visibility.ApplyAlpha(uf) end
        -- ⚠ 距離沒有事件可訂閱（WoW 不發「距離變了」），只能輪詢 ⇒ **間隔就是延遲**。
        -- 0.3 秒時肉眼看得出遮罩／淡出慢半拍（實測回報）。收到 0.15：
        -- 探針是 IsSpellInRange 這種便宜的 C 呼叫，而且只掛在「有開淡出且正在顯示」
        -- 的框上（Metro.Bind 跟著可見度上下），成本可以接受。
        -- ⚠ Core/Range.lua 的快取 TTL 必須比這個短，否則等於沒收緊。
        ns.Metro.Bind(uf, key, 0.15, uf.rangeFn)
    end
    -- 不管有沒有掛輪詢都要套一次：關掉淡出時要把 alpha 還原，不然會卡在半透明
    uf.appliedAlpha = nil       -- 設定可能剛改過 oorAlpha／oocAlpha，強迫重設
    ns.Visibility.ApplyAlpha(uf)
end

------------------------------------------------------------
-- 滑鼠移過高亮
--
-- 一圈細邊框，層級要壓過光環容器的 holder（12），不然滑到有光環的框上時高亮會被
-- 光環蓋掉一角。EnableMouse(false)：它鋪滿整個框，吃到滑鼠就會把單位框的點擊擋掉。
------------------------------------------------------------
local HIGHLIGHT_LEVEL = 20

function ns.ApplyHighlight(uf)
    local on = uf.db.frame.highlight ~= false
    uf.highlightOn = on
    if not on then
        if uf.highlight then uf.highlight:Hide() end
        return
    end
    local hl = uf.highlight
    if not hl then
        hl = CreateFrame("Frame", nil, uf, "BackdropTemplate")
        hl:SetAllPoints(uf)
        hl:SetFrameLevel(HIGHLIGHT_LEVEL)
        hl:EnableMouse(false)
        uf.highlight = hl
    end
    local g = ns.db.global
    local c = g.highlightColor or { r = 1, g = 1, b = 1, a = 0.7 }
    hl:SetBackdrop({ edgeFile = Media.WHITE8X8, edgeSize = Media.BorderInset(g.highlightSize or 1) })
    hl:SetBackdropBorderColor(c.r, c.g, c.b, c.a or 0.7)
    hl:Hide()      -- 顯示與否由 OnEnter/OnLeave 決定
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
                -- disable 也要隔離：跟上面的 build 同一個迴圈，一支拋錯會讓後面的
                -- 元件整批不重建（而它們的設定已經被判定為「要停用」）
                if def.disable then xpcall(def.disable, ns.ReportError, uf) end
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

    -- ⚠⚠ 腳本要在 BuildElements **之前**設好。
    -- SetScript 是「取代」，HookScript 是「包在現有的外面」。元件建構裡有東西會
    -- HookScript OnShow（Metro.Bind 靠它在框顯示時把輪詢加回來），先 Hook 再
    -- SetScript 的話那個 hook 會被整個蓋掉——症狀是輪詢永遠掛不上、超出距離的
    -- 文字凍結在選目標那一刻，而且完全不報錯。實際踩過。
    uf:SetScript("OnShow", function(self)
        ns.Refresh(self, "unitchanged")     -- 單位出現時（RegisterUnitWatch 驅動）全量刷新
    end)

    -- 滑鼠提示與高亮（暴雪單位提示；EUI/暴雪同法）。OnEnter/OnLeave 不是受保護腳本，
    -- 掛在 SecureUnitButton 上安全。
    -- ⚠ 高亮要在提示的 early return **之前**：關掉提示的人一樣要看得到高亮。
    uf:SetScript("OnEnter", function(self)
        if self.highlightOn and self.highlight then self.highlight:Show() end
        if not ns.db.global.showTooltip then return end
        if ns.db.global.tooltipHideInCombat and InCombatLockdown() then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not GameTooltip:SetUnit(self.unit) then
            GameTooltip:Hide()
        end
    end)
    uf:SetScript("OnLeave", function(self)
        if self.highlight then self.highlight:Hide() end
        GameTooltip:Hide()
    end)

    -- 顯示閘：單位框改當它的子物件（藏父層 = 藏單位框，戰鬥中合法且不跟 unit watch 搶）。
    -- ⚠ 一定要在 ApplyFramePosition 之前換好父層，位置才是換完之後才下的
    -- （SetParent 對錨點的影響不必去賭）。SetParent 對 secure 框在戰鬥中不合法，
    -- 而 spawn 只會發生在 PLAYER_LOGIN 與設定套用，兩邊都保證不在戰鬥。
    ns.Visibility.CreateGate(uf)

    ns.ApplyFramePosition(uf)
    ns.BuildElements(uf)
    ns.ApplyHighlight(uf)
    ns.ApplyFrameFade(uf)

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
-- 換設定檔之後把活著的東西重新指到新表上
--
-- `ns.db` 由 DB.Activate 換掉了，這裡負責的是「還抓著舊表參照的人」。
-- 逐一盤點過的清單（改動這個插件時新增任何長命的 db 參照，記得回來補）：
--   uf.db          spawn 時存的（Core/UnitFrame.lua）→ 這裡重指
--   預覽孿生       Options/Preview.lua 自己存一份 → 它訂閱 SettingsApplied，
--                  下面的 ApplySettings 會帶它重指，不必特別處理
--   設定面板       Options/Tab_Unit.lua 的 panels 快取把 udb 捕捉在 ctx 的 closure
--                  裡，而它只在「文字條目數變了」時才丟快取 → 訂閱 ProfileChanged
--   其餘分頁       Tab_General／Tab_Resource／Tab_Totem 都是每次現查 ns.db，安全
--   圖騰           Totems 的 GetDB() 也是現查，安全
--
-- ⚠ 這支**不處理「啟用的單位集合變了」**——那種情況 DB.SwitchProfile 會改走
-- ReloadUI，理由見那裡（HideBlizzard 是單向的）。
------------------------------------------------------------
function ns.RebindProfile()
    for _, uf in pairs(ns.frames) do
        uf.db = ns.GetUnitDB(uf.unitKey)
    end
    ns.Fire("ProfileChanged")
    -- 每個 unitKey 重套一次（ApplySettings 內含 BuildElements ＋ 全量重畫，
    -- 並且會 Fire SettingsApplied 帶動預覽與顯示條件）。boss1-5 共用一個 key，去重。
    local seen = {}
    for _, unit in ipairs(ns.UNITS) do
        local key = ns.UNIT_KEYS[unit]
        if key and not seen[key] then
            seen[key] = true
            ns.ApplySettings(key)
        end
    end
    if ns.TotemsApplySettings then ns.TotemsApplySettings() end
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
                    ns.ApplyHighlight(uf)
                    ns.ApplyFrameFade(uf)
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
