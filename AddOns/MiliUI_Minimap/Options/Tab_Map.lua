------------------------------------------------------------
-- 「小地圖」分頁：形狀、尺寸、位置、外觀、地圖上的元素
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local CONTROLS = {
    { type = "toggle",   key = "enabled", label = L["Skin the minimap"] },
    -- ⚠ 關掉之後**這一整套都不會載入**，所以重新開啟要 /reload。
    --   刻意做成這樣而不是「即時關掉再還原」：把小地圖交還給暴雪需要復原
    --   reparent、遮罩、隱藏的按鈕與 cluster 的 alpha，其中任何一項還原得不完整，
    --   症狀都是「小地圖壞掉了」而玩家會怪到別的插件頭上。乾淨的做法只有重載。
    { type = "text",     label = L["Turning this off hands the minimap back to the game, but only after a /reload — see the note in the code for why there is no live restore."] },

    { type = "header",   label = L["Shape and size"] },
    { type = "dropdown", key = "shape", label = L["Shape"], items = Specs.SHAPES },
    -- ⚠ 範圍必須跟拉把手一致（Map/Skin.lua 的 MIN_SIZE / MAX_SIZE = 100 / 400）。
    --   原本滑桿只到 300、把手卻能拉到 400 —— 拉到 350 之後回設定頁，滑桿就表示
    --   不出那個值了（滑桿會顯示成上限，看起來像設定被改掉）。
    { type = "slider",   key = "size",  label = L["Map size"], min = 100, max = 400, step = 2 },
    { type = "slider",   key = "scale", label = L["Scale"], min = 0.5, max = 2, step = 0.05 },
    { type = "text",     label = L["Position is set by dragging: uncheck \"Lock in place\" below (opening this window unlocks it for you), then drag the map. Right-click the drag overlay to send it back to the top-right corner."] },
    { type = "text",     label = L["Drag the bottom-left corner to resize"] },
    { type = "text",     label = L["The map canvas has to stay square: the terrain projection and the player arrow both depend on it, so a rectangle would need a fixed-aspect crop mask. Drag the corner for size, or use Scale above to shrink everything including the text."] },
    { type = "toggle",   key = "locked", label = L["Lock in place"] },

    { type = "header",   label = L["Appearance"] },
    { type = "slider",   key = "bgAlpha", label = L["Background opacity"], min = 0, max = 1, step = 0.05 },
    { type = "toggle",   key = "borderClassColor", label = L["Border uses your class colour"] },
    { type = "color",    key = "borderColor", label = L["Border colour"], hasAlpha = true },
    { type = "slider",   key = "borderAlpha", label = L["Border opacity"], min = 0.1, max = 1, step = 0.05 },
    { type = "text",     label = L["The 1px class-coloured border is the MiliUI house style — the same look as the damage meter windows. Turn the class colour off to pick a fixed colour instead."] },

    { type = "header",   label = L["Text"] },
    { type = "dropdown", key = "font", label = L["Font"], items = Specs.Fonts },
    { type = "dropdown", key = "fontOutline", label = L["Outline"], items = Specs.OUTLINES },
    { type = "slider",   key = "fontSize", label = L["Font size"], min = 8, max = 18, step = 1 },

    { type = "header",   label = L["Elements on the map"] },
    { type = "dropdown", key = "zoneText", label = L["Zone name"], items = Specs.VISIBILITY },
    { type = "dropdown", key = "coords",   label = L["Coordinates"], items = Specs.VISIBILITY },
    { type = "dropdown", key = "clock",    label = L["Clock"], items = Specs.VISIBILITY },
    { type = "text",     label = L["\"Mouseover\" elements appear while the cursor is anywhere over the map, including the strips themselves."] },

    { type = "header",   label = L["Blizzard's own bits"] },
    { type = "toggle",   key = "hideBlizzardArt", label = L["Hide the border art and compass"] },
    { type = "toggle",   key = "hideZoomButtons", label = L["Hide the zoom buttons"] },
    { type = "toggle",   key = "scrollZoom",      label = L["Zoom with the mouse wheel"] },
    { type = "text",     label = L["A square map's corners fall outside the game's own round click area, so the wheel there would zoom the camera instead. This addon covers the full square, which is also what makes mouseover elements work when you enter from a corner."] },
    { type = "toggle",   key = "hideTracking", label = L["Hide the tracking button"] },
    { type = "toggle",   key = "hideMail",     label = L["Hide the mail / crafting order icons"] },
    { type = "toggle",   key = "hideCalendar", label = L["Hide the calendar button"] },
    { type = "toggle",   key = "showAddonCompartment", label = L["Show Blizzard's addon compartment"] },
    { type = "text",     label = L["Blizzard's own addon list button. Off by default: it is a text label sitting next to a skinned map, and what it does overlaps with the button bag above."] },
    { type = "text",     label = L["The buttons that stay are moved into the map's corners rather than redrawn, so they keep their normal click behaviour. Third-party addon buttons are not touched — use MBB or a similar button bag for those."] },

    { type = "header",   label = L["Reset"] },
    { type = "button",   label = L["All settings"], text = L["Restore defaults"], color = "red",
      confirm = L["Restore every MiliUI Minimap setting to its default?"],
      onClick = function() ns.DB.ResetAll() end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Minimap"])
    local ctx = ns.Options.MakeCtx()
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "mapTab", function(id)
    if id ~= "map" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
