------------------------------------------------------------
-- 「玩家」「NPC」分頁：同一個建構器、兩份設定
--
-- 元素只開放開關與圖示替代；顏色與顯示條件沿用套組預設
-- （跟現行 TinyTooltip 樣式一致——之後真的有需求再加）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Controls = ns.Controls
local Specs = ns.Specs

local tabs = {}   -- [kind] = { tab, refreshers }

local function BuildControls(kind)
    local controls = {
        { type = "header", label = L["Coloring"] },
        { type = "dropdown", key = "coloredBorder", label = L["Border tint"], items = Specs.BORDER_COLOR_ITEMS },
        { type = "dropdown", sub = "background", key = "colorfunc", label = L["Background tint"], items = Specs.BG_COLOR_ITEMS },
        { type = "slider", sub = "background", key = "alpha", label = L["Background opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "text", label = L["Opacity applies only when a background tint is selected; \"Global background color\" uses the alpha from the Style tab."] },

        { type = "header", label = L["Behavior"] },
        { type = "toggle", key = "showTarget", label = L["Show their target"] },
        { type = "toggle", key = "showTargetBy", label = L["Show who targets them (in groups)"] },
        { type = "toggle", key = "showModel", label = L["Show 3D model"] },
        { type = "toggle", key = "grayForDead", label = L["Gray out when dead"] },

        { type = "header", label = L["Lines and icons"] },
    }

    local order = (kind == "player") and Specs.PLAYER_ELEMENT_ORDER or Specs.NPC_ELEMENT_ORDER
    for _, key in ipairs(order) do
        controls[#controls + 1] = {
            type = "toggle", sub = "elements", sub2 = key, key = "enable",
            label = Specs.ELEMENT_LABELS[key] or key,
        }
    end

    if kind == "player" then
        controls[#controls + 1] = { type = "header", label = L["Icon instead of text"] }
        for _, key in ipairs({ "className", "mplusScore", "itemLevel", "achievementPoints", "mount" }) do
            controls[#controls + 1] = {
                type = "toggle", sub = "elements", sub2 = key, key = "icon",
                label = Specs.ELEMENT_LABELS[key] or key,
            }
        end
        controls[#controls + 1] = { type = "text", label = L["Replaces the text label with a small icon (spec icon for class, dedicated icons for the rest)."] }
    end

    controls[#controls + 1] = { type = "space", h = 8 }
    controls[#controls + 1] = { type = "text", label = L["Element colors and per-element filters follow the pack defaults, matching the existing TinyTooltip look. Hold Alt or Ctrl over a unit to temporarily show every element."] }
    return controls
end

local function Resolve(root, spec)
    local t = root
    if spec.sub then t = t[spec.sub] end
    if spec.sub2 then t = t[spec.sub2] end
    return t
end

local function Init(kind)
    if tabs[kind] then return end
    local title = (kind == "player") and L["Player"] or "NPC"
    local tab, scroll = ns.Options.MakeFormTab(title)
    local ctx = {
        get = function(spec)
            local t = Resolve(ns.db.unit[kind], spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = Resolve(ns.db.unit[kind], spec)
            if t then t[spec.key] = v end
        end,
        apply = ns.ApplyAll,
    }
    local _, refreshers = ns.Options.BuildScrollBody(scroll, BuildControls(kind), ctx, 640)
    tabs[kind] = { tab = tab, refreshers = refreshers }
end

local function Register(kind)
    ns.RegisterCallback("ShowOptionsTab", kind .. "Tab", function(id)
        if id ~= kind then
            if tabs[kind] then tabs[kind].tab:Hide() end
            return
        end
        Init(kind)
        for _, fn in ipairs(tabs[kind].refreshers) do fn() end
        tabs[kind].tab:Show()
    end)
end

Register("player")
Register("npc")
