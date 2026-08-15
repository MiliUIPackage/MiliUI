------------------------------------------------------------
-- 「圖騰」分頁
------------------------------------------------------------
local _, ns = ...

local W, Controls = ns.W, ns.Controls

local tab
local refreshers

local CONTROLS = {
    { type = "toggle", key = "enabled", label = "顯示圖騰框" },
    { type = "text",   label = "只在薩滿／德魯伊／死亡騎士／聖騎士登場。樣式：圖示膠囊列（圖示＋底部剩時條）。" },
    { type = "header", label = "位置與大小" },
    { type = "text",   label = "座標是框架中心相對畫面中心的偏移；也可以在編輯模式直接拖曳。框固定四格寬、從左往右排。" },
    { type = "numbers", sub = "frame", label = "位置", fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
    { type = "slider", sub = "frame", key = "iconSize", label = "圖示大小", min = 16, max = 64 },
    { type = "slider", sub = "frame", key = "spacing", label = "間距", min = 0, max = 16 },
    { type = "header", label = "顏色與順序" },
    { type = "dropdown", key = "colors", label = "剩時條顏色",
      items = { { text = "職業色", value = "accent" }, { text = "元素色（火／土／水／風）", value = "element" } } },
    { type = "toggle", key = "swapEarthFire", label = "土／火位置對調" },
    { type = "header", label = "重置" },
    { type = "button", label = "恢復預設", text = "圖騰設定恢復預設", color = "red",
      confirm = "把圖騰框的設定恢復成預設值？",
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

    local title = W.CreateSectionTitle(tab, "圖騰框架", 660)
    title:SetPoint("TOPLEFT", 16, -14)

    local content = CreateFrame("Frame", nil, tab)
    content:SetPoint("TOPLEFT", 16, -44)
    content:SetSize(640, 400)

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

    local _, r = Controls.Build(content, CONTROLS, ctx, 4, -4, 640)
    refreshers = r
end

ns.RegisterCallback("ShowOptionsTab", "totemTab", function(id)
    if id ~= "totem" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
