------------------------------------------------------------
-- 「資源」分頁
--
-- 資源清單是**跟著專精走的**（Ayije_CDM 的做法），所以控制項不能像其他分頁那樣
-- 在 Init 時建一次就算了 —— 換專精之後可選項目會整個換掉。用 specSig 比對，
-- 變了就把內容框整個丟掉重建。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls = ns.W, ns.Controls

local tab, scroll, content, refreshers, specSig, rows

local function EDB()
    local u = ns.db.units.player
    return u and u.elements and u.elements.classpower
end

local function BuildControls()
    local cand, specID = ns.ResourceCandidates()
    local list = {
        { type = "toggle", key = "enabled", label = L["Show resource bars"] },
        { type = "text",   label = L["Anchored below the player frame, stacking downward. Which resources appear follows your specialization and switches automatically."] },
        { type = "header", label = L["Position and size"] },
        { type = "numbers", label = L["Position"], fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "text",   label = L["Offset from the bottom-left corner of the player frame (negative goes down)."] },
        { type = "slider", key = "totalw",     label = L["Total width"],   min = 40, max = 400, step = 2 },
        { type = "slider", key = "h",          label = L["Row height"], min = 2,  max = 30,  step = 1 },
        { type = "slider", key = "rowSpacing", label = L["Row spacing"],   min = 0,  max = 12,  step = 1 },
        { type = "slider", key = "spacing",    label = L["Segment spacing"], min = 0, max = 8,  step = 1 },
        { type = "text",   label = L["Segment spacing only affects point-style resources (Holy Power, combo points and the like)."] },
        { type = "slider", key = "level",      label = L["Layer"],   min = 0,  max = 15,  step = 1 },
        { type = "header", label = L["Appearance"] },
        { type = "slider", key = "barAlpha", label = L["Fill opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "toggle", key = "showText", label = L["Show value on the bar"] },
        { type = "header", label = L["Show for this specialization"] },
    }

    if #cand == 0 then
        list[#list + 1] = { type = "text",
            label = L["This specialization has no extra resource to show, so the whole row collapses. Mana is deliberately not listed here: the unit frame's own power bar already shows it."] }
    else
        for _, key in ipairs(cand) do
            local info = ns.ResourceInfo(key)
            list[#list + 1] = { type = "toggle", sub = "resources", key = key,
                                label = info and info.name or key, default = true }
        end
        list[#list + 1] = { type = "text",
            label = L["Absorb-style resources (Stagger, Ironfur, Ignore Pain) are secret values in 12.1 — addons can't read the numbers, so they aren't listed."] }
    end

    list[#list + 1] = { type = "header", label = L["Reset"] }
    list[#list + 1] = { type = "button", label = L["Restore defaults"], text = L["Restore resource defaults"], color = "red",
        confirm = L["Restore the resource bar settings to their defaults?"],
        onClick = function()
            local edb = EDB()
            if not edb then return end
            local def = ns.DB.BuildDefaults().units.player.elements.classpower
            for k in pairs(edb) do edb[k] = nil end
            for k, v in pairs(def) do edb[k] = v end
            ns.ApplySettings("player")
        end }

    return list, specID
end

local ctx = {
    get = function(spec)
        local edb = EDB()
        if not edb then return nil end
        local t = Controls.Resolve(edb, spec)
        if not t then return spec.default end
        local v = t[spec.key]
        if v == nil then return spec.default end
        return v
    end,
    set = function(spec, v)
        local edb = EDB()
        if not edb then return end
        if spec.sub and not edb[spec.sub] then edb[spec.sub] = {} end
        local t = Controls.Resolve(edb, spec)
        if t then t[spec.key] = v end
    end,
    apply = function()
        -- 資源清單／格數可能一起變 → 逼引擎重排，不只是重畫
        if ns.ResourceReevaluate then ns.ResourceReevaluate() end
        ns.ApplySettings("player")
    end,
}

-- ⚠ 一定要放在卷軸裡：這一頁的長度跟著專精走（資源多的專精會多好幾列開關），
-- 直接鋪在 tab 上的話，內容一長就會整段掉出面板外面
local function Rebuild()
    local controls, specID = BuildControls()
    if content then content:Hide() end
    content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(620, 1)
    local height, r, built = Controls.Build(content, controls, ctx, 4, -4, 620)
    rows = built
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    scroll:SetVerticalScroll(0)
    refreshers = r
    specSig = specID or 0
end

local function Init()
    if tab then return end
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    local title = W.CreateSectionTitle(tab, L["Resource bars"], 660)
    title:SetPoint("TOPLEFT", 16, -14)

    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(holder)

    Rebuild()
end

-- 換設定檔時，正開著的這一頁要重整。
-- ⚠ ctx 是現查 ns.db 所以**寫入**一直都正確，錯的是**控件顯示值** —— 那是 refresher
-- 推上去的，而 refresher 只在 ShowOptionsTab 跑。原本只有「單位」分頁訂了這個事件，
-- 所以停在這一頁換設定檔會看到顏色與滑桿全停在舊值，切走再切回來才對。
ns.RegisterCallback("ProfileChanged", "resourceTabProfile", function()
    if tab and tab:IsShown() then
        for _, fn in ipairs(refreshers) do fn() end
    end
end)

ns.RegisterCallback("ShowOptionsTab", "resourceTab", function(id)
    if id ~= "resource" then
        if tab then tab:Hide() end
        return
    end
    Init()
    local _, specID = ns.ResourceCandidates()
    if specSig ~= (specID or 0) then Rebuild() end
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)

------------------------------------------------------------
-- 設定搜尋（Options/Search.lua）
--
-- ⚠ 這一頁的內容跟著目前專精走（資源清單不一樣），所以列舉時**現算**一次，
-- 不快取。索引本身會在 SettingsApplied／ProfileChanged 時失效重建。
------------------------------------------------------------
ns.Search.Register("resource", {
    label = L["Resources"],
    enumerate = function(add) add((BuildControls()), L["Resources"]) end,
    jump = function(_, spec)
        Init()
        ns.Search.Reveal(scroll, content, rows, spec)
    end,
})
