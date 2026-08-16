------------------------------------------------------------
-- 「資源」分頁
--
-- 資源清單是**跟著專精走的**（Ayije_CDM 的做法），所以控制項不能像其他分頁那樣
-- 在 Init 時建一次就算了 —— 換專精之後可選項目會整個換掉。用 specSig 比對，
-- 變了就把內容框整個丟掉重建。
------------------------------------------------------------
local _, ns = ...

local W, Controls = ns.W, ns.Controls

local tab, scroll, content, refreshers, specSig

local function EDB()
    local u = ns.db.units.player
    return u and u.elements and u.elements.classpower
end

local function BuildControls()
    local cand, specID = ns.ResourceCandidates()
    local list = {
        { type = "toggle", key = "enabled", label = "顯示資源條" },
        { type = "text",   label = "掛在玩家框下方，逐列往下排。要顯示哪些資源跟著專精走，切專精會自動換。" },
        { type = "header", label = "位置與大小" },
        { type = "numbers", label = "位置", fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "text",   label = "相對玩家框「左下角」的偏移（往下是負的）。" },
        { type = "slider", key = "totalw",     label = "總寬",   min = 40, max = 400, step = 2 },
        { type = "slider", key = "h",          label = "每列高", min = 2,  max = 30,  step = 1 },
        { type = "slider", key = "rowSpacing", label = "列距",   min = 0,  max = 12,  step = 1 },
        { type = "slider", key = "spacing",    label = "分段間距", min = 0, max = 8,  step = 1 },
        { type = "text",   label = "分段間距只影響點數型（聖能、連擊點那種一格一格的）。" },
        { type = "slider", key = "level",      label = "圖層",   min = 0,  max = 15,  step = 1 },
        { type = "header", label = "外觀" },
        { type = "slider", key = "barAlpha", label = "填充透明度", min = 0.1, max = 1, step = 0.05 },
        { type = "toggle", key = "showText", label = "長條上顯示數值" },
        { type = "header", label = "這個專精要顯示哪些" },
    }

    if #cand == 0 then
        list[#list + 1] = { type = "text",
            label = "目前這個專精沒有額外資源要顯示，整條會自動收起來。法力刻意不列在這裡——單位框自己的能量條已經在顯示了。" }
    else
        for _, key in ipairs(cand) do
            local info = ns.ResourceInfo(key)
            list[#list + 1] = { type = "toggle", sub = "resources", key = key,
                                label = info and info.name or key, default = true }
        end
        list[#list + 1] = { type = "text",
            label = "吸收量型的資源（醉仙緩勁、鐵鬃、無視苦痛）12.1 是秘密值，插件拿不到數字，所以沒有列進來。" }
    end

    list[#list + 1] = { type = "header", label = "重置" }
    list[#list + 1] = { type = "button", label = "恢復預設", text = "資源設定恢復預設", color = "red",
        confirm = "把資源條的設定恢復成預設值？",
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
    local height, r = Controls.Build(content, controls, ctx, 4, -4, 620)
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

    local title = W.CreateSectionTitle(tab, "資源條", 660)
    title:SetPoint("TOPLEFT", 16, -14)

    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(holder)

    Rebuild()
end

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
