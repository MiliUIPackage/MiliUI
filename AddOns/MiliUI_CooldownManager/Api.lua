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
        if B.released then
            p(("  |cffff5555已還給暴雪|r（%s）%s"):format(tostring(B.releaseReason),
                ns.engineFailed and ("  啟動失敗：" .. table.concat(ns.engineFailed, ", ")) or ""))
        end
        for _, key in ipairs(V.ORDER) do
            local viewer = V.Get(key)
            p(("  %-9s 暴雪 item %s  清單 %d  認領 %d  alpha %s")
                :format(key, viewer and tostring(V.Count(key)) or "✕",
                        #C.Bar(key), B.Count(key), tostring(ns.Visibility and ns.Visibility.Current(key))))
        end
        if ns.Visibility and ns.Visibility.DebugLine then p(ns.Visibility.DebugLine()) end
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
    local CU, G = ns.Custom, ns.Glow
    if CU and CU.Counts then
        local n = CU.Counts()
        local pb, pk = CU.PendingCounts()
        p(("  自訂項目：光環格 %d  法術 %d  物品 %d（放好的框 %d、光環容器 %d 顆、建過 %d 次）  待建 %d  待補踢 %d")
            :format(n.aura, n.spell, n.item, n.placed, n.containers, CU.builds, pb, pk))
        local prot, total = 0, 0
        for _, rec in pairs(CU.Records()) do
            if rec.kind == "aura" and rec.container then
                total = total + 1
                if ns.IsProtectedFrame(rec.container) then prot = prot + 1 end
            end
        end
        if total > 0 then p(("  光環格容器 IsProtected：%d／%d（細節 /mcdm aura）"):format(prot, total)) end
    end
    if G and G.Counts then
        local proc, ready, pandemic = G.Counts()
        p(("  發光：觸發 %d  就緒 %d（觸發過 %d 次）  無損刷新 %d  探針 %d 顆  manager 掛勾 %s")
            :format(proc, ready, G.readyFired or 0, pandemic, G.probes or 0, tostring(G.hooked)))
    end
    if ns.Resources and ns.Resources.DebugLines then
        for _, line in ipairs(ns.Resources.DebugLines()) do p(line) end
    end
    if ns.Castbar and ns.Castbar.DebugLines then
        for _, line in ipairs(ns.Castbar.DebugLines()) do p(line) end
    end
    if ns.Keybinds and ns.Keybinds.CacheSize then
        p(("  按鍵文字：快取 %d 筆"):format(ns.Keybinds.CacheSize()))
    end
    p("  容器層待補寫入（戰鬥記帳）：" .. tostring(ns.PendingWrites()))
    if ns.EditMode and ns.EditMode.DebugLines then
        for _, line in ipairs(ns.EditMode.DebugLines()) do p(line) end
    end

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

------------------------------------------------------------
-- /mcdm aura：每個光環格的持有框／容器／所在條容器的 IsProtected、待辦旗標、最近錯誤
-- （給實機驗證：保護鏈是不是真的存在、戰鬥中有沒有被擋）
------------------------------------------------------------
local function Prot(f)
    if not f then return "–" end
    local ok, a, b = pcall(f.IsProtected, f)
    if not ok then return "err" end
    if ns.IsSecret(a) then return "secret" end
    return tostring(a) .. (b and "(explicit)" or "")
end

local function AuraDebug()
    local p = print
    local CU = ns.Custom
    if not (CU and CU.Records) then p("  自訂項目模組沒有載入") return end
    local n = 0
    for key, rec in pairs(CU.Records()) do
        if rec.kind == "aura" then
            n = n + 1
            local h = rec.frame
            local parent = h and h:GetParent()
            local pb, pk = CU.IsPending(rec)
            local inits = rec.inits or 0
            local nc = 0
            for _ in pairs(rec.containers or {}) do nc = nc + 1 end
            p(("%s[光環格]|r %s  id=%s  條=%s  %s"):format(ns.PREFIX_COLOR, key, tostring(rec.cooldownID),
                tostring(rec.placedBar), rec.placedBar and "放好了" or "|cffaaaaaa沒放|r"))
            p(("  持有框 IsProtected=%s  容器 IsProtected=%s  所在條 IsProtected=%s")
                :format(Prot(h), Prot(rec.container), Prot(parent ~= UIParent and parent or nil)))
            p(("  容器 %d 顆（簽章池）  按鈕初始化 %d 次  待建=%s  待補踢=%s")
                :format(nc, inits, tostring(pb), tostring(pk)))
            if rec.lastError then p("  |cffff5555最近錯誤：" .. tostring(rec.lastError) .. "|r") end
        end
    end
    if n == 0 then p(ns.PREFIX_COLOR .. "[光環格]|r 這個專精沒有光環格") end
    p("  容器層待補寫入（戰鬥記帳）：" .. tostring(ns.PendingWrites()))
end
ns.AuraDebug = AuraDebug

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
    elseif msg == "aura" then
        AuraDebug()
    elseif msg == "release" then
        -- 除錯用：把暴雪的冷卻管理器還給暴雪（item、檢視器、發光、按鍵文字），/reload 才接回來
        if ns.Bars and ns.Bars.ReleaseAll and not ns.released then
            ns.Bars.ReleaseAll("manual")
            print(ns.PREFIX_COLOR .. "[米利冷卻 debug]|r 已把冷卻管理器還給暴雪；/reload 重新接管")
        else
            print(ns.PREFIX_COLOR .. "[米利冷卻 debug]|r " .. (ns.released and "已經還過了（/reload 重新接管）" or "引擎沒有載入"))
        end
    else
        ns.OpenOptions()
    end
end

------------------------------------------------------------
-- 公開 API：給其他插件讀（單位框架的資源條顏色、錨定候選…）
--
-- ⚠ **契約**：以下每一支的回傳形狀之後不改（README「公開 API」一節）。呼叫端一律要處理 nil
--   （本插件沒載入完、互斥偵測成立、那一項不存在），退回自己的預設。
--   回傳的表是設定檔裡的**參照**：唯讀，別改、別長期持有（換設定檔之後就是另一張表）。
------------------------------------------------------------
-- 設定檔還沒載入（登入前、互斥偵測成立整支沒初始化）一律 nil：呼叫端退自己的來源
local function ResourcesCfg()
    if not (ns.ready and ns.profile and ns.DB and ns.DB.ConfigTable) then return nil end
    return ns.DB.ConfigTable("resources")
end

-- 資源顏色／條件規則變了（資源條設定頁、換設定檔、換專精）：0.2 秒合併成一次
-- "ResourceStyleChanged"，給跟隨我們顏色的插件（單位框架的資源條）重畫
local styleArmed = false
function ns.NotifyResourceStyle()
    if styleArmed then return end
    styleArmed = true
    C_Timer.After(0.2, function()
        styleArmed = false
        ns.Fire("ResourceStyleChanged")
    end)
end
ns.RegisterCallback("ProfileChanged", "api_style", ns.NotifyResourceStyle)
ns.RegisterCallback("SpecChanged", "api_style", ns.NotifyResourceStyle)

-- 對外開放的回呼（白名單）；key 加前綴，不會撞到內部訂閱者
local PUBLIC_EVENTS = { ResourceStyleChanged = true }
local function ExtKey(key) return "ext:" .. tostring(key) end

_G.MiliUI_CooldownManager = {
    -- 資源 key（"ComboPoints"、"HolyPower"、"Mana"…，見 README）的顏色：
    --   { color = {r,g,b,a}, chargedColor = {…}|nil, chargedEmptyColor = {…}|nil }
    -- 回的是設定檔裡那張表本身（不配新表）；沒有這個資源回 nil。
    GetResourceColors = function(key)
        local cfg = ResourcesCfg()
        local colors = cfg and type(cfg.colors) == "table" and cfg.colors
        local t = colors and type(key) == "string" and colors[key]
        return type(t) == "table" and t or nil
    end,
    -- 資源 key 的條件規則陣列（形狀見 Modules/ResourceConditions.lua 檔頭）；沒有規則回 nil
    GetResourceConditions = function(key)
        local cfg = ResourcesCfg()
        if not cfg or type(key) ~= "string" then return nil end
        return ns.ResCond and ns.ResCond.Resolve(cfg, key) or nil
    end,
    -- Enum.PowerType → 資源條上那一列的框（別的插件要錨在它身上用）；
    -- 沒有這一列、被玩家關掉、整條資源條關掉（容器藏起來）都回 nil。
    -- 載入條件／淡出造成的 alpha 0 不算藏：框還在，錨在上面的東西不必換錨點
    GetResourceBarFrame = function(powerType)
        if not (ns.ready and ns.Resources and ns.Resources.GetRowFrame) then return nil end
        return ns.Resources.GetRowFrame(powerType)
    end,
    -- 引擎是否已經認領好四條檢視器（別的插件要錨在我們的容器上前先問）
    IsReady = function()
        return (ns.ready and ns.Viewers and ns.Viewers.ready and ns.Bars and ns.Bars.ready) and true or false
    end,
    -- 某條的容器框（MiliUICDM_Bar_<key>；資源條 "resources"、施法條 "castbar" 也是），給別的插件錨定用；
    -- 還沒建好回 nil。⚠ 錨上來的框會跟著這條移動；別對它 SetParent 或改它的大小。
    GetBarFrame = function(barKey)
        return ns.Bars and ns.Bars.Get(barKey) or nil
    end,
    -- 訂閱本插件的事件；目前只開放 "ResourceStyleChanged"（資源顏色或條件規則變了，
    -- 不帶參數，已合併節流）。同一個 key 再登記＝換掉。成功回 true，事件不開放回 false。
    -- fn 拋錯會被隔離（記在本插件的錯誤清單），不影響其他訂閱者
    RegisterCallback = function(event, key, fn)
        if not PUBLIC_EVENTS[event] or key == nil or type(fn) ~= "function" then return false end
        ns.RegisterCallback(event, ExtKey(key), fn)
        return true
    end,
    UnregisterCallback = function(event, key)
        if not PUBLIC_EVENTS[event] or key == nil then return false end
        ns.UnregisterCallback(event, ExtKey(key))
        return true
    end,
}
