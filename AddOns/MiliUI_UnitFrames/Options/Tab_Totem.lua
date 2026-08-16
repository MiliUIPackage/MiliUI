------------------------------------------------------------
-- 「召喚物」分頁
------------------------------------------------------------
local _, ns = ...

local W, Controls = ns.W, ns.Controls

local tab, scroll
local refreshers

local CONTROLS = {
    { type = "toggle", key = "enabled", label = "顯示召喚物框" },
    { type = "text",   label = "|cff4DD2FF停在這一頁時框裡會放四個示範召喚物|r（含會跑的時間條與倒數），方便對位置和大小——切到別頁或關掉面板就回真實狀態。" },
    { type = "text",   label = "圖騰、玉蛟／玄牛雕像、生命綻放這類「放出去會自己待一段時間」的東西——暴雪把它們收在同一組欄位裡，最多四個，所以這裡一起管。樣式：圖示膠囊列（圖示＋底部時間條）。" },
    { type = "header", label = "位置與大小" },
    { type = "text",   label = "座標是框架中心相對畫面中心的偏移；也可以在編輯模式直接拖曳。框固定四格寬、從左往右排。" },
    { type = "numbers", sub = "frame", label = "位置", fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
    { type = "slider", sub = "frame", key = "iconSize", label = "圖示大小", min = 16, max = 64 },
    { type = "slider", sub = "frame", key = "spacing", label = "間距", min = 0, max = 16 },
    { type = "header", label = "顏色與順序" },
    { type = "dropdown", key = "colors", label = "時間條顏色",
      items = { { text = "職業色", value = "accent" }, { text = "元素色（火／土／水／風）", value = "element" } } },
    { type = "toggle", key = "swapEarthFire", label = "土／火位置對調" },
    { type = "header", label = "剩餘時間" },
    { type = "toggle", key = "showTimeText", label = "顯示剩餘秒數" },
    { type = "text",   label = "關掉就只留底部的時間條。12.1 有時抽不到剩餘時間，那種情況數字會留白、時間條顯示滿格。" },
    { type = "header", label = "重置" },
    { type = "button", label = "恢復預設", text = "召喚物設定恢復預設", color = "red",
      confirm = "把召喚物框的設定恢復成預設值？",
      onClick = function()
          ns.DB.ResetUnit("totem")
          if ns.TotemsApplySettings then ns.TotemsApplySettings() end
      end },
}

local function Init()
    if tab then return end
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    local title = W.CreateSectionTitle(tab, "召喚物", 660)
    title:SetPoint("TOPLEFT", 16, -14)

    -- 同資源分頁：內容比面板高就會掉出去，一律走卷軸
    local holder = CreateFrame("Frame", nil, tab)
    holder:SetPoint("TOPLEFT", 16, -44)
    holder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(holder)

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(620, 1)

    local ctx = {
        get = function(spec)
            local t = Controls.Resolve(ns.db.units.totem, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = Controls.Resolve(ns.db.units.totem, spec)
            if t then t[spec.key] = v end
        end,
        apply = function()
            if ns.TotemsApplySettings then ns.TotemsApplySettings() end
        end,
    }

    local height, r = Controls.Build(content, CONTROLS, ctx, 4, -4, 620)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    refreshers = r
end

ns.RegisterCallback("ShowOptionsTab", "totemTab", function(id)
    -- 沒放召喚物時框是空的，調位置等於對著空氣調 → 進這一頁就填示範內容
    if ns.TotemsSetPreview then ns.TotemsSetPreview(id == "totem") end
    if id ~= "totem" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
