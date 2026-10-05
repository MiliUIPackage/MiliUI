------------------------------------------------------------
-- 對外出口：slash、AddonCompartment、公開 API
------------------------------------------------------------
local ADDON, ns = ...

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

-- 米利UI選單（ESC 選單「米利UI設定」滑過展開）的項目。
-- 直接往全域表塞而不是呼叫 MiliUI 的函式：兩邊沒有相依宣告，載入順序不保證，
-- 而且玩家可能只裝這支、根本沒有 MiliUI 套組。接口說明見 MiliUI/Menu.lua。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}
MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
    key     = "cooldownmanager",
    text    = L["MiliUI Cooldown Manager"],
    icon    = "Interface\\Icons\\Spell_Nature_TimeStop",
    order   = 25,
    OnClick = function() ns.OpenOptions() end,
}

------------------------------------------------------------
-- /mcdm debug：引擎現況（開發用，字串不進語系檔）
------------------------------------------------------------
-- 讀框的狀態一律包起來：讀不到（拋錯）印 "?"、秘密值印「秘密」（不比較、不算）
local function Read(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, obj, ...)
    if not ok then return nil end
    if ns.IsSecret(a) then return "秘密" end
    return a, b, c, d, e
end
local function Num(v)
    if ns.IsSecret(v) then return "秘密" end
    if type(v) == "number" then return ("%.2f"):format(v):gsub("%.?0+$", "") end
    return tostring(v == nil and "?" or v)
end

-- 秘密值／nil 一律印字串，不比較
local function Txt(v)
    if ns.IsSecret(v) then return "秘密" end
    return tostring(v)
end

-- 增益類 item：暴雪自己認為生效了沒、光環從哪個單位抓到、抓到哪個法術、這一項連結了哪些法術
-- （「目標有腐蝕術、增益圖示卻是灰的」：看抓不抓得到、連結的法術 ID 跟目標身上的對不對得上）
local function AuraInfo(item, rec)
    local active = Read(item, "IsActive")
    local unit = rawget(item, "auraDataUnit")
    local sid = rawget(item, "auraSpellID")
    local linked = "—"
    local CV = C_CooldownViewer
    if CV and CV.GetCooldownViewerCooldownInfo and type(rec.cooldownID) == "number" then
        local ok, info = pcall(CV.GetCooldownViewerCooldownInfo, rec.cooldownID)
        if ok and type(info) == "table" and type(info.linkedSpellIDs) == "table" then
            local t = {}
            for i, id in ipairs(info.linkedSpellIDs) do t[i] = Txt(id) end
            if #t > 0 then linked = table.concat(t, "/") end
        end
    end
    return (" 生效=%s 光環單位=%s 光環法術=%s 連結=%s"):format(Txt(active), Txt(unit), Txt(sid), linked)
end

-- 目標身上「你上的」減益：法術 ID＋名字（戰鬥中可能整串秘密，讀不到就印秘密）
local function TargetDebuffLine(out)
    local U = C_UnitAuras
    if not (U and U.GetAuraDataByIndex) then return end
    local parts = {}
    for i = 1, 40 do
        local ok, a = pcall(U.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
        if not ok or type(a) ~= "table" then break end
        parts[#parts + 1] = Txt(a.spellId) .. "=" .. Txt(a.name)
    end
    out[#out + 1] = "  目標身上你的減益：" .. (#parts > 0 and table.concat(parts, "、") or "（無）")
end
ns.DebugTargetDebuffLine = TargetDebuffLine

-- 每條檢視器與每顆 item 的現況（只進存檔，不印聊天框：幾十行）
local function ItemLines(out)
    local V, B = ns.Viewers, ns.Bars
    for _, key in ipairs(V.ORDER) do
        local viewer = V.Get(key)
        if viewer then
            local n = 0
            V.EnumerateItems(function(item, rec)
                n = n + 1
                local point, rel, relPoint, x, y = Read(item, "GetPoint", 1)
                local relName = "?"
                -- 錨點的回傳值可能整組是秘密值：先判，別拿去比較
                if ns.IsSecret(point) or ns.IsSecret(rel) or ns.IsSecret(relPoint) then
                    point, rel, relName = "secret", false, "secret"
                elseif rel == nil then relName = "nil"
                elseif rel == UIParent then relName = "UIParent"
                elseif rel == viewer then relName = "viewer"
                elseif type(rel) == "table" then
                    relName = Read(rel, "GetName") or "?"
                    relName = tostring(relName):gsub("^MiliUICDM_Bar_", "容器:")
                end
                local w, h = Read(item, "GetSize")
                -- 冷卻狀態效果餵過秘密布林（SetAlphaFromBoolean）的框不讀回 alpha
                local alpha = rec.alphaSecret and "秘密" or Num(Read(item, "GetAlpha"))
                local st = rec.style and rec.style.cdState
                -- 以增益取代：A 被 B 頂掉（停放中）／B 頂著 A 的格
                local by = B and B.ReplacedBy and B.ReplacedBy(rec.cooldownID)
                local rep = (by and ("（被 " .. tostring(by) .. " 取代）") or "")
                    .. (rec.replacing and ("（取代 " .. tostring(rec.replacing) .. "）") or "")
                -- 冷卻框（轉圈＋倒數字）：隱藏 GCD 轉圈會整個調它的 alpha、增益那段可能被改餵技能冷卻
                -- （Core/Decorate.lua）—— 「發光會亮、倒數不顯示」要看這幾欄
                local info = ns.Catalog.Info(rec.cooldownID)
                local cdf = rawget(item, "Cooldown")
                local cdInfo = (" 法術=%s/%s%s 冷卻框 alpha=%s%s%s%s%s"):format(
                    tostring(info and info.spellID), tostring(info and info.overrideSpellID),
                    -- 「充能」＝現在真的是充能法術；「充能旗標」＝暴雪資料說可以有、但現在只有一次
                    (info and info.charges) and ((ns.Decorate.IsChargeSpell(rec, info.overrideSpellID or info.spellID, true)
                        and " 充能" or " 充能旗標")) or "",
                    cdf and Num(Read(cdf, "GetAlpha")) or "✕",
                    (rec.style and rec.style.hideGCD) and " 藏GCD" or "",
                    rec.auraFlag and " 增益中" or "", rec.auraHidden and "（改餵冷卻）" or "",
                    -- 效果不在時變暗：勾了才印（「勾了沒變暗」先看這格有沒有 增益中 旗標）
                    (rec.style and rec.style.dimNoAura) and " 效果不在變暗" or "")
                if ns.Viewers.AURA_KIND and ns.Viewers.AURA_KIND[rec.barKey] then
                    cdInfo = cdInfo .. AuraInfo(item, rec)
                end
                out[#out + 1] = ("    %s #%s id=%s%s 顯示=%s alpha=%s 縮放=%s 尺寸=%sx%s 錨=%s→%s(%s,%s) 認領=%s%s%s%s")
                    :format(key, tostring(rawget(item, "layoutIndex")), tostring(rec.cooldownID), rep,
                            tostring(Read(item, "IsShown")), alpha, Num(Read(item, "GetScale")),
                            Num(w), Num(h), tostring(point), relName, Num(x), Num(y),
                            tostring(rec.claimKey or "—"), rec.parked and " 停放" or "",
                            st and (" 冷卻狀態=" .. st .. (rec.stateHidden and "（藏）" or "")) or "", cdInfo)
            end, key)
            if n == 0 then out[#out + 1] = ("    %s（沒有作用中的 item）"):format(key) end
        end
    end
    local _ = B
end

-- silent ＝ 不印聊天框（設定視窗的除錯分頁「重新產生」用）；回傳不帶色碼的輸出行
local function CountKeys(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- 事件集合（事件 → true）→ 排序後的一行；空的印「（無）」
local function EventList(set)
    local list = {}
    for ev in pairs(set or {}) do list[#list + 1] = ev end
    table.sort(list)
    return #list > 0 and table.concat(list, " ") or "（無）"
end

local function Debug(silent)
    local dump = {}
    local function p(line)
        if not silent then print(line) end
        -- 存檔裡不留色碼
        dump[#dump + 1] = (tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
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
            local withID, shown = 0, 0
            if viewer then
                V.EnumerateItems(function(item, rec)
                    if rec.cooldownID ~= nil then withID = withID + 1 end
                    if Read(item, "IsShown") == true then shown = shown + 1 end
                end, key)
            end
            p(("  %-9s 暴雪 item %s（有身分 %d、顯示中 %d）  清單 %d  認領 %d  alpha %s")
                :format(key, viewer and tostring(V.Count(key)) or "✕", withID, shown,
                        #C.Bar(key), B.Count(key), tostring(ns.Visibility and ns.Visibility.Current(key))))
            if viewer then
                local vs = Read(viewer, "IsShown")
                p(("            檢視器 顯示=%s%s alpha=%s 縮放=%s  暴雪設定：大小 %s／可見 %s")
                    :format(tostring(vs), vs == false and "（|cffff5555暴雪把這條藏起來了|r：編輯模式的「可見」設定或冷卻管理器不可用）" or "",
                            Num(Read(viewer, "GetAlpha")), Num(Read(viewer, "GetScale")),
                            Num(rawget(viewer, "iconScale")), tostring(rawget(viewer, "visibleSetting"))))
            end
        end
        if ns.Visibility and ns.Visibility.DebugLine then p(ns.Visibility.DebugLine()) end
        local p2 = ns.profile
        for key in pairs(p2 and p2.bars or {}) do
            if not V.VIEWERS[key] then
                p(("  %-9s（自訂）清單 %d  認領 %d"):format(key, #C.Bar(key), B.Count(key)))
            end
        end
        -- 格數上限＋溢出（Core/Overflow.lua）：成立的印去向與顆數；設了上限卻不成立的印原因
        do
            local O = ns.Overflow
            local ov = C.Overflow and C.Overflow()
            for _, key in ipairs(C.BarKeys and C.BarKeys() or {}) do
                local dst = ov and ov.target[key]
                if dst then
                    p(("  %-9s 溢出 → %s（%d 顆）"):format(key, dst, #(ov.to[key] or {})))
                elseif O and O.MaxOf(C.BarCfgOf(key)) > 0 then
                    local _, why = O.Target(key, C.BarCfgOf)
                    p(("  %-9s 上限 %d 不成立（%s）：不限制顆數"):format(key, O.MaxOf(C.BarCfgOf(key)), tostring(why)))
                end
                for _, src in ipairs(ov and ov.into[key] or {}) do
                    local n = 0
                    for _, from in pairs(ov.from[key]) do if from == src then n = n + 1 end end
                    p(("  %-9s 接收 ← %s（%d 顆）"):format(key, src, n))
                end
            end
        end
        -- 逐法術「不在時顯示占位」（F7，暴雪的增益）：哪幾條有、固定格位開著時這個勾不起作用
        for _, key in ipairs(C.BarKeys and C.BarKeys() or {}) do
            local n = 0
            for _, id in ipairs(C.Bar(key)) do
                if type(id) == "number" and ns.SpellOverride(id, "placeholder") == true then n = n + 1 end
            end
            if n > 0 then
                local b = C.BarCfgOf(key)
                local fixed = (type(b) == "table" and type(b.layout) == "table" and b.layout.fixedSlots)
                    or C.BarHasAuraSlot(key) or (ns.Clickable and ns.Clickable.Enabled(key))
                p(("  %-9s 逐法術占位 %d 格%s"):format(key, n, fixed and "（固定格位開著：每一格本來就保留）" or ""))
            end
        end
        local sig = C.sig or ""
        p(("  目錄：順序來源 %s  建置 %d 次  簽章 %s%s  暫停 %s  specTag %s  收養 %d  整套重來 %d 次")
            :format(tostring(C.source), C.builds, sig:sub(1, 16), #sig > 16 and "…" or "",
                    tostring(C.IsPaused()), tostring(C.specTag), C.adopted or 0, B.resyncs or 0))
        -- 增益兩條的每個 id 落在哪、沒落地是哪一關擋的（「暴雪面板加了、這邊不顯示」的回報看這段）
        if C.Explain then
            p("  增益診斷（✓ 落在哪條／✕ 擋在哪一關；暴雪面板開著時目錄暫停，關掉再看）：")
            for _, line in ipairs(C.Explain({ "buffs", "buffbars" })) do p(line) end
        end
        -- 重新取出只補做（Viewers.CHEAP_REACQUIRE；false ＝ 每次取出都整套重裝飾）
        p(("  重新取出只補做 %s  （Decorate.Reattach %d 次）"):format(tostring(V.CHEAP_REACQUIRE),
            ns.Decorate and ns.Decorate.applyReattach or 0))
        -- 從另一支插件匯入、還沒對到 cooldownID 的法術（那個專精第一次登入時才對得到）
        if ns.Import and ns.Import.DebugLines then
            for _, line in ipairs(ns.Import.DebugLines()) do p(line) end
        end
        -- 暴雪 API 現在給的是哪一份清單：每一類幾個、學會幾個、前三個的 cooldownID＝法術。
        -- 換專精之後暴雪有時還在給上一個專精的清單（面板上一排灰色的別專精技能、本專精的技能不見），
        -- 這幾行對照暴雪資料表的 cooldownID 就看得出來
        local CV = C_CooldownViewer
        local cats = Enum and Enum.CooldownViewerCategory
        if CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo and cats then
            for _, def in ipairs({ { "核心", cats.Essential }, { "輔助", cats.Utility }, { "增益", cats.TrackedBuff }, { "長條", cats.TrackedBar } }) do
                local ok, ids = pcall(CV.GetCooldownViewerCategorySet, def[2], true)
                if ok and type(ids) == "table" then
                    local known, head = 0, {}
                    for i = 1, #ids do
                        local ok2, info = pcall(CV.GetCooldownViewerCooldownInfo, ids[i])
                        if ok2 and type(info) == "table" then
                            local isKnown, spellID = info.isKnown, info.spellID
                            if not ns.IsSecret(isKnown) and isKnown == true then known = known + 1 end
                            if #head < 3 and not ns.IsSecret(ids[i]) then
                                head[#head + 1] = tostring(ids[i]) .. "=" .. (ns.IsSecret(spellID) and "secret" or tostring(spellID))
                            end
                        end
                    end
                    p(("  暴雪清單（API）%s：%d 個、已學會 %d  前三個 %s")
                        :format(def[1], #ids, known, table.concat(head, "、")))
                end
            end
            -- 裝備欄項目（飾品／武器）：面板上「有時候變灰、條上抓不到」——API 與暴雪快取的 isKnown 各是多少
            if ns.Catalog.KnownProbe then
                for _, cat in ipairs({ cats.EquipSlotEssential, cats.EquipSlotTracked }) do
                    local ok, ids = pcall(CV.GetCooldownViewerCategorySet, cat, true)
                    if ok and type(ids) == "table" then
                        for i = 1, #ids do
                            if not ns.IsSecret(ids[i]) then p("  裝備欄 " .. ns.Catalog.KnownProbe(ids[i])) end
                        end
                    end
                end
            end
        end
        if ns.Compat then
            p(("  圖示套皮插件：%s"):format(ns.Compat.Active() and ("已請它跳過（蓋印 " .. tostring(ns.Compat.marked) .. " 次）") or "沒有／不處理"))
        end
        if #V.blocked > 0 then
            p("  被擋的寫入：" .. table.concat(V.blocked, ", "))
        end
    end
    local CU, G = ns.Custom, ns.Glow
    if CU and CU.Counts then
        local n = CU.Counts()
        local pb, pk = CU.PendingCounts()
        p(("  自訂項目：光環格 %d  法術 %d  物品 %d  飾品欄 %d  代畫 %d（增益疊層 %d）（放好的框 %d、光環容器 %d 顆、建過 %d 次）  待建 %d  待補踢 %d")
            :format(n.aura, n.spell, n.item, n.slot or 0, n.proxy or 0, n.overlays or 0, n.placed, n.containers, CU.builds, pb, pk))
        if CU.SegDebugLine then p(CU.SegDebugLine()) end
        -- 代畫（暴雪沒給框的裝備欄冷卻格，Core/Bars.lua）：哪條、哪個 id、槽、有沒有疊增益、疊層容器的簽章
        local px = B and B.Proxied and B.Proxied() or {}
        for key, ids in pairs(px) do
            for id, slot in pairs(ids) do
                local rec = CU.Proxies and CU.Proxies()[id]
                local o = rec and rec.buffOverlay
                local ov = (o and o.placedBar) and ("有、容器 " .. tostring(o.sig or "未建")) or "無"
                p(("  代畫：%s  %d→槽%d（%s，疊層 %s）"):format(key, id, slot,
                    (rec and rec.placedBar) and "放好了" or "沒放", ov))
            end
        end
        local prot, total = 0, 0
        for _, rec in pairs(CU.Records()) do
            if rec.kind == "aura" and rec.container then
                total = total + 1
                if ns.IsProtectedFrame(rec.container) then prot = prot + 1 end
            end
        end
        if total > 0 then p(("  光環格容器 IsProtected：%d／%d（細節 /mcdm aura）"):format(prot, total)) end
    end
    -- 自訂項目每筆的範圍（戰隊／職業／專精；窄蓋寬之後生效的那幾筆）＋寬層裡這個角色看不到的筆數
    if ns.DB and ns.DB.EffectiveCustom then
        local SCOPE_TEXT = { shared = "戰隊", class = "職業", spec = "專精" }
        local items = ns.DB.EffectiveCustom()
        local shown = {}
        for _, it in ipairs(items) do
            local e = it.entry
            local what = type(e) == "table" and (e.kind or "?") .. ":" .. tostring(e.spellID or e.itemID or e.slot)
                .. (e.kind == "slotbuff" and ("#" .. tostring(e.buff or 1) .. "→"
                    .. table.concat((ns.Catalog.SlotBuffIDs(e.slot, e.buff or 1)), "/")) or "")
                .. (e.racial and "（種族技能）" or "") or "壞資料"
            p(("    %s  %s  %s  條=%s"):format(it.id, SCOPE_TEXT[it.scope] or it.scope, what,
                tostring(type(e) == "table" and e.bar or nil)))
            shown[it.raw] = true
        end
        local hiddenWide = 0
        for _, scope in ipairs({ "shared", "class" }) do
            for _, raw in ipairs(ns.DB.ScopeList(scope, false) or {}) do
                if not shown[raw] then hiddenWide = hiddenWide + 1 end
            end
        end
        if hiddenWide > 0 then
            p(("    寬層（戰隊／職業）這裡不列的 %d 筆（被專精／職業層蓋掉、沒學、種族技能解不到）"):format(hiddenWide))
        end
    end
    if G and G.Counts then
        local proc, ready, pandemic = G.Counts()
        p(("  發光：觸發 %d  就緒 %d（觸發過 %d 次）  無損刷新 %d  探針 %d 顆  manager 掛勾 %s")
            :format(proc, ready, G.readyFired or 0, pandemic, G.probes or 0, tostring(G.hooked)))
    end
    -- 層數門檻：設了幾格、RefreshApplications 掛了幾格、最近一次餵的是明文還是秘密
    if ns.StackGate and ns.StackGate.DebugLine then p(ns.StackGate.DebugLine()) end
    local SI = ns.SpellIndex
    if SI and SI.Count then
        p(("  法術索引：%d 個法術、重建 %d 次  冷卻事件（合併後）精準 %d 次（其中 GCD %d）／全掃 %d 次  GCD 精準 %s  全掃清單 %d 格")
            :format(SI.Count(), SI.rebuilds or 0, SI.precise or 0, SI.gcd or 0, SI.full or 0,
                    tostring(SI.GCD_PRECISE), CountKeys(ns.Decorate and ns.Decorate.cdWork)))
    end
    -- 動態註冊的事件（效能修整 E3）：自訂項目（Custom.SyncEvents）與資源條（光環／生命事件）
    if ns.Custom and ns.Custom.evOn then
        p(("  自訂項目事件：%s  （生效中的非光環項目 %d 筆）"):format(EventList(ns.Custom.evOn),
            ns.Custom.activeNonAura or 0))
    end
    if ns.Resources and ns.Resources.unitEvOn then
        p("  資源條光環／生命事件：" .. EventList(ns.Resources.unitEvOn))
    end
    if ns.Sound and ns.Sound.DebugLine then p(ns.Sound.DebugLine()) end
    if ns.Cursor and ns.Cursor.DebugLine then
        local line = ns.Cursor.DebugLine()
        if line then p(line) end
    end
    if ns.Resources and ns.Resources.DebugLines then
        for _, line in ipairs(ns.Resources.DebugLines()) do p(line) end
    end
    if ns.Pips and ns.Pips.DebugLines then
        for _, line in ipairs(ns.Pips.DebugLines()) do p(line) end
    end
    if ns.Castbar and ns.Castbar.DebugLines then
        for _, line in ipairs(ns.Castbar.DebugLines()) do p(line) end
    end
    -- 戰鬥輔助：輪詢的 ticker 在不在、目前建議、亮著幾格；下一招圖示的現況
    if ns.Assist and ns.Assist.DebugLine then p(ns.Assist.DebugLine()) end
    if ns.AssistIcon and ns.AssistIcon.DebugLine then p(ns.AssistIcon.DebugLine()) end
    if ns.Keybinds and ns.Keybinds.CacheSize then
        p(("  按鍵文字：快取 %d 筆"):format(ns.Keybinds.CacheSize()))
    end
    if ns.Keybinds and ns.Keybinds.PressDebugLine then p(ns.Keybinds.PressDebugLine()) end
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

    -- 診斷記錄（引擎自己修掉的異常）：聊天框印最近幾行，完整的在存檔裡
    if ns.Diag then
        local lines = ns.Diag.Lines(6)
        if #lines == 0 then
            p("  診斷記錄：無")
        else
            p(("  診斷記錄（新→舊，共 %d 行，完整的在存檔）："):format(ns.Diag.Count()))
            for _, line in ipairs(lines) do p("   " .. line) end
        end
        -- 每顆 item 的現況只進存檔
        if ns.Viewers and ns.Bars and ns.Viewers.ready then
            xpcall(TargetDebuffLine, ns.ReportError, dump)
            dump[#dump + 1] = "  item 現況："
            xpcall(ItemLines, ns.ReportError, dump)
        end
        ns.Diag.SaveDump(dump)
        if not silent then print("  |cffaaaaaa（這份輸出已存檔；/reload 或登出後寫進 SavedVariables）|r") end
    end
    return dump
end
ns.Debug = Debug

-- 設定視窗除錯分頁的全文：debug 輸出＋完整的診斷記錄（聊天框只印最近幾行）。玩家整段複製貼給作者
function ns.DebugText()
    local lines = Debug(true)
    if ns.Diag and ns.Diag.Count and ns.Diag.Count() > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "  完整診斷記錄（新→舊）："
        for _, line in ipairs(ns.Diag.Lines(ns.Diag.Count())) do lines[#lines + 1] = "   " .. line end
    end
    return table.concat(lines, "\n")
end

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

-- 光環格的 Masque（Modules/Custom.lua「光環格的 Masque」）：探針有沒有交出去、讀回來的形狀、容器簽章的 msq 段
local function MasqueLines(p, rec)
    local h = rec.frame
    if not h then return end
    local L = h.skin
    local sh = h.msqShape
    local mk = sh and sh.mask
    local nm = sh and sh.normal
    local nmTxt = nm == nil and "讀不到" or (nm == false and "這張皮沒有外框")
        or ("%s %sx%s 層 %s"):format(tostring(nm.atlas or nm.file), tostring(nm.w), tostring(nm.h), tostring(nm.layer))
    p(("  Masque：在畫=%s  探針=%s（交出去=%s、顯示=%s）")
        :format(tostring(h.msqOn), L and "有" or "無", L and tostring(L.msqButton ~= nil) or "—",
            L and tostring(L.frame:IsShown()) or "—"))
    p(("  形狀：%s  圖示 %sx%s  遮罩 %s  外框 %s")
        :format(sh and "讀到" or "沒讀到", sh and tostring(sh.iw) or "—", sh and tostring(sh.ih) or "—",
            mk and tostring(mk.atlas or mk.file) or "無", sh and nmTxt or "—"))
    -- 現在（不是快取）探針身上的狀態：Icon 掛了幾張遮罩、GetNormal 拿到的貼圖長怎樣；占位圖示也看一次
    local function Live(t)
        if not t then return "—" end
        local ok, n = pcall(t.GetNumMaskTextures, t)
        local okT, tex = pcall(t.GetTexture, t)
        return ("遮罩 %s 張、貼圖 %s"):format(ok and tostring(n) or "✕", okT and tostring(tex) or "✕")
    end
    if L then
        p("  探針 Icon 現況：" .. Live(L.icon))
        local M = ns.Masque
        local nt = M and M.GetNormal and M.GetNormal(L.frame)
        if nt then
            local okS, shown = pcall(nt.IsShown, nt)
            local okA, a = pcall(nt.GetAlpha, nt)
            local okT, tex = pcall(nt.GetTexture, nt)
            p(("  探針 GetNormal：%s（是我們給的=%s）顯示=%s alpha=%s 貼圖=%s"):format(tostring(nt), tostring(nt == L.normal),
                okS and tostring(shown) or "✕", okA and tostring(a) or "✕", okT and tostring(tex) or "✕"))
        else
            p("  探針 GetNormal：nil")
        end
    end
    if h.ph then p("  占位圖示現況：" .. Live(h.ph.tex) .. "  交給 Masque=" .. tostring(h.ph.msqButton ~= nil)) end
    local sig = tostring(rec.sig or "未建")
    p("  容器簽章：" .. (sig:match("msq:[^|]*") or (sig:sub(1, 60) .. "…（沒有 msq 段）")))
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
            MasqueLines(p, rec)
        end
    end
    -- 飾品冷卻格的增益疊層（光環格形狀的子 rec）
    for key, rec in pairs(CU.Records()) do
        local o = rec.kind ~= "aura" and rec.buffOverlay
        if o and o.placedBar then
            n = n + 1
            p(("%s[增益疊層]|r %s  條=%s  按鈕初始化 %d 次"):format(ns.PREFIX_COLOR, key, tostring(o.placedBar), o.inits or 0))
            if o.lastError then p("  |cffff5555最近錯誤：" .. tostring(o.lastError) .. "|r") end
            MasqueLines(p, o)
        end
    end
    p(("  烘過的遮罩 %d 張、皮外框 %d 張"):format(CU.masksBaked or 0, CU.normalsBaked or 0))
    if n == 0 then p(ns.PREFIX_COLOR .. "[光環格]|r 這個專精沒有光環格") end
    p("  容器層待補寫入（戰鬥記帳）：" .. tostring(ns.PendingWrites()))
end
ns.AuraDebug = AuraDebug

------------------------------------------------------------
-- /mcdm perf：效能計數（開發用，字串不進語系檔）
--
-- 計數器散在各模組表上（模組層級整數，熱路徑上只有 +1、不配置、不新增 OnUpdate）。這裡只負責讀、相減、印：
--   /mcdm perf         自上次重設以來每個計數的總數與每秒；最上面一行是暴雪的插件分析器（C_AddOnProfiler）與記憶體
--   /mcdm perf reset   重設
--   /mcdm perf log     切換「脫戰時印一行這一場的計數」（MiliUI_CooldownManager_DB.perfLog，預設關）
-- 輸出跟 /mcdm debug 一樣存進 SavedVariables（diag.perf，/reload 後可讀）。
--
-- ⚠ 重設**不把計數器歸零**，而是記一份基準、印的時候相減：B.flushes 同時是 Bars 的排版世代
--   （Relayout 的 gen → rec.claimGen），歸零會讓新的世代撞上舊的。印出來的數字跟「歸零」一樣。
------------------------------------------------------------
-- { 模組（ns 上的表名）, 欄位, 標籤, of = 印成「佔誰的幾 %」（同表的 key） }
local PERF = {
    { "Bars",       "flushes",             "排版 Flush" },
    { "Bars",       "relayoutBars",        "  重排條（Relayout）" },
    { "Bars",       "requestSource",       "RequestSource" },
    { "Bars",       "requestSourceHit",    "  快取命中",            of = "Bars.requestSource" },
    { "Bars",       "reapplyItems",        "Reapply 放回 item" },
    { "Visibility", "snapshots",           "顯示條件 Snapshot" },
    { "Decorate",   "applyCalls",          "Decorate.Apply" },
    { "Decorate",   "applySkipped",        "  簽章命中跳過",        of = "Decorate.applyCalls" },
    { "Decorate",   "applyPre",            "  前置鍵命中",          of = "Decorate.applyCalls" },
    { "Decorate",   "applyReattach",       "  重新取出只補做",      of = "Decorate.applyCalls" },
    { "Decorate",   "setCooldownHooks",    "SetCooldown 掛勾" },
    { "Decorate",   "afterCooldownWrites", "  重寫倒數色（去重後）", of = "Decorate.setCooldownHooks" },
    { "SpellIndex", "rebuilds",            "法術索引重建" },
    { "SpellIndex", "precise",             "冷卻事件 精準" },
    { "SpellIndex", "gcd",                 "  其中 GCD 開始",      of = "SpellIndex.precise" },
    { "SpellIndex", "full",                "冷卻事件 全掃" },
    { "Glow",       "pandemicCalls",       "無損刷新掛勾" },
    { "Glow",       "pandemicChanges",     "  狀態真的變了",        of = "Glow.pandemicCalls" },
    { "StackGate",  "feeds",               "層數門檻餵值" },
    { "Custom",     "updates",             "自訂法術 UpdateSpell" },
    { "Custom",     "colorOnly",           "自訂法術只重算顏色" },
    { "Cursor",     "ticks",               "跟著游標 OnUpdate" },
    { "Resources",  "mirrorTicks",         "征戰聖擊鏡射 OnUpdate" },
    { "Resources",  "valueFlushes",        "資源條只重畫值" },
}
for _, def in ipairs(PERF) do def.key = def[1] .. "." .. def[2] end

-- 脫戰那一行挑哪幾個（sub ＝ 括號裡附帶的子計數）
local PERF_SUMMARY = {
    { "Bars.flushes",            "Flush" },
    { "Decorate.applyCalls",     "Apply",          sub = "Decorate.applySkipped",       subLabel = "跳過" },
    { "Decorate.setCooldownHooks", "SetCooldown",  sub = "Decorate.afterCooldownWrites", subLabel = "寫" },
    { "Bars.requestSource",      "RequestSource" },
    { "Visibility.snapshots",    "Snapshot" },
    { "SpellIndex.full",         "冷卻全掃" },
    { "Glow.pandemicCalls",      "無損刷新" },
}

-- 計數表 → 文字行（純函式，Tests/Extras_test.lua）
--   counters：陣列，每筆 { key, label, n = 數字｜nil（沒有這個計數）, of = 另一筆的 key, gauge = 現況值（不算每秒） }
--   elapsed：秒（≤ 0 或不是數字 ⇒ 不印每秒）
function ns.PerfLines(counters, elapsed)
    local byKey = {}
    for _, c in ipairs(counters) do
        if c.key ~= nil then byKey[c.key] = c.n end
    end
    local secs = type(elapsed) == "number" and elapsed > 0 and elapsed or nil
    local out = { secs and ("  自上次重設 %.1f 秒"):format(secs) or "  自上次重設不到一秒（不算每秒）" }
    for _, c in ipairs(counters) do
        local n, line = c.n, nil
        if type(n) ~= "number" then
            line = ("  %s：—（沒有這個計數）"):format(c.label)
        elseif c.gauge then
            line = ("  %s：%d（現況）"):format(c.label, n)
        else
            line = ("  %s：%d"):format(c.label, n)
            if secs then line = line .. ("  每秒 %.1f"):format(n / secs) end
            local base = c.of and byKey[c.of]
            if type(base) == "number" and base > 0 then
                line = line .. ("（%d%%）"):format(math.floor(n / base * 100 + 0.5))
            end
        end
        out[#out + 1] = line
    end
    return out
end

-- 脫戰那一行（純函式，同上的 counters 形狀）
function ns.PerfSummary(counters, elapsed)
    local byKey = {}
    for _, c in ipairs(counters) do
        if c.key ~= nil then byKey[c.key] = c.n end
    end
    local parts = {}
    for _, s in ipairs(PERF_SUMMARY) do
        local n = byKey[s[1]]
        if type(n) == "number" then
            local part = ("%s %d"):format(s[2], n)
            local sub = s.sub and byKey[s.sub]
            if type(sub) == "number" then part = part .. ("（%s %d）"):format(s.subLabel, sub) end
            parts[#parts + 1] = part
        end
    end
    local secs = type(elapsed) == "number" and elapsed > 0 and elapsed or 0
    return ("這一場 %.0f 秒：%s"):format(secs, #parts > 0 and table.concat(parts, "、") or "（沒有計數）")
end

-- 讀現在的計數進 out（重用同一張表；只有手動指令與進出戰鬥會叫）
local function PerfRead(out)
    for _, def in ipairs(PERF) do
        local m = ns[def[1]]
        local v = type(m) == "table" and m[def[2]] or nil
        if type(v) == "number" then out[def.key] = v else out[def.key] = nil end
    end
    return out
end

-- 現在減掉基準 → PerfLines 的 counters 形狀；後面接發光的現況（G.Counts，不是累計）
local function PerfCounters(base)
    local now = PerfRead({})
    local list = {}
    for _, def in ipairs(PERF) do
        local v = now[def.key]
        list[#list + 1] = { key = def.key, label = def[3], of = def.of,
                            n = v and (v - (base[def.key] or 0)) or nil }
    end
    local G = ns.Glow
    if G and G.Counts then
        local ok, proc, ready, pandemic = pcall(G.Counts)
        if ok then
            list[#list + 1] = { label = "發光現況 觸發", n = proc, gauge = true }
            list[#list + 1] = { label = "發光現況 就緒", n = ready, gauge = true }
            list[#list + 1] = { label = "發光現況 無損刷新", n = pandemic, gauge = true }
        end
    end
    return list
end

local perfBase, perfSince = {}, GetTime()       -- 基準（空表 ＝ 全 0，載入當下所有計數都是 0）
local combatBase, combatSince = {}, nil         -- 這一場的基準（PLAYER_REGEN_DISABLED 記；表重用）

-- 暴雪的插件分析器：讀值免費；欄位名照 Enum.AddOnProfilerMetric（warcraft.wiki.gg 查過），沒有的跳過
local PROFILER_METRICS = {
    { "RecentAverageTime",    "近期平均" },
    { "SessionAverageTime",   "本次登入平均" },
    { "EncounterAverageTime", "首領戰平均" },
    { "PeakTime",             "單幀尖峰" },
}
local function ProfilerLine()
    local P = _G.C_AddOnProfiler
    local E = _G.Enum and _G.Enum.AddOnProfilerMetric
    local parts = {}
    if type(P) == "table" and type(P.GetAddOnMetric) == "function" and type(E) == "table" then
        for _, m in ipairs(PROFILER_METRICS) do
            local metric = E[m[1]]
            if metric ~= nil then
                local ok, v = pcall(P.GetAddOnMetric, ADDON, metric)
                -- v ~= v 是 nan
                if ok and type(v) == "number" and not ns.IsSecret(v) and v == v then
                    parts[#parts + 1] = ("%s %.3fms"):format(m[2], v)
                end
            end
        end
    end
    -- 記憶體：UpdateAddOnMemoryUsage 是全堆掃描，只在這支手動指令叫一次（不放任何迴圈）
    local upd, get = _G.UpdateAddOnMemoryUsage, _G.GetAddOnMemoryUsage
    if type(upd) == "function" and type(get) == "function" then
        pcall(upd)
        local ok, kb = pcall(get, ADDON)
        if ok and type(kb) == "number" and not ns.IsSecret(kb) then
            parts[#parts + 1] = ("記憶體 %.0f KB"):format(kb)
        end
    end
    if #parts == 0 then return nil end
    return "  插件分析器：" .. table.concat(parts, "  ")
end

local function Perf(arg)
    local tag = ns.PREFIX_COLOR .. "[米利冷卻 perf]|r "
    local sv = _G.MiliUI_CooldownManager_DB
    if arg == "reset" then
        PerfRead(perfBase)
        perfSince = GetTime()
        print(tag .. "已重設")
        return
    elseif arg == "log" then
        if type(sv) ~= "table" then print(tag .. "存檔還沒載入") return end
        sv.perfLog = sv.perfLog ~= true
        print(tag .. (sv.perfLog and "脫戰時印這一場的計數：開" or "脫戰時印這一場的計數：關"))
        return
    end
    local dump = {}
    local function p(line)
        print(line)
        dump[#dump + 1] = (tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    p(tag .. "v" .. tostring(ns.VERSION) .. "  戰鬥中 " .. tostring(InCombatLockdown() and true or false)
        .. "  脫戰記錄 " .. ((type(sv) == "table" and sv.perfLog == true) and "開" or "關"))
    local prof = ProfilerLine()
    if prof then p(prof) end
    for _, line in ipairs(ns.PerfLines(PerfCounters(perfBase), GetTime() - perfSince)) do p(line) end
    if ns.Diag and ns.Diag.SavePerf then
        ns.Diag.SavePerf(dump)
        print("  |cffaaaaaa（這份輸出已存檔；/reload 或登出後寫進 SavedVariables）|r")
    end
end
ns.Perf = Perf

-- 這一場：進戰鬥記基準，脫戰（perfLog 開著才）印一行
ns.Events.Register("PLAYER_REGEN_DISABLED", "perf", function()
    PerfRead(combatBase)
    combatSince = GetTime()
end)
ns.Events.Register("PLAYER_REGEN_ENABLED", "perf", function()
    local since = combatSince
    combatSince = nil
    local sv = _G.MiliUI_CooldownManager_DB
    if not since or type(sv) ~= "table" or sv.perfLog ~= true then return end
    print(ns.PREFIX_COLOR .. "[米利冷卻 perf]|r " .. ns.PerfSummary(PerfCounters(combatBase), GetTime() - since))
end)

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
        -- 設定視窗多一個「除錯」分頁（這次登入期間一直在），直接切過去：玩家全選複製就能貼給作者
        if ns.ready and ns.Options and ns.Options.ShowDebugTab then ns.Options.ShowDebugTab() end
    elseif msg == "aura" then
        AuraDebug()
    elseif msg == "perf" or msg:match("^perf%s") then
        Perf(msg:match("^perf%s+(%S+)"))
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
    -- Enum.PowerType（或資源 key 字串：沒有 PowerType 的資源，例如 "Stagger"、"IgnorePain"）→ 資源條上那一列的框
    --（別的插件要錨在它身上用）；
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
    -- 某條的容器框（MiliUICDM_Bar_<key>；資源條 "resources"、自訂格子 "pips"、施法條 "castbar"、
    -- 下一招圖示 "assistIcon" 也是），給別的插件錨定用；
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
