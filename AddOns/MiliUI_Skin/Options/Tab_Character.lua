------------------------------------------------------------
-- 設定：角色面板的自建功能（Extras/）
--
-- 兩種開關混在同一頁：
--   * 建不建（`statsPanel`、`titlesSearch`）—— 要 /reload：Extras 沒有「拆掉」那條路，
--     跟一般頁的視窗開關同一個理由（DB.lua 檔頭）。改了走共用的 `Options.AskReload`。
--   * 顯示選項（`statsValueFormat`）—— 即時：清單開著就當場重讀一次。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

-- 改了就要 /reload 的那幾個 key
local NEEDS_RELOAD = {
    statsPanel = true,
    titlesSearch = true,
}

local controls = {
    { type = "header", label = L["Character Sheet"] },
    { type = "toggle", sub = "extras", key = "statsPanel", label = L["Custom stat list"] },
    { type = "text", label = L["Splits stats the EllesmereUI way: Attributes, Secondary, Tertiary, Attack and Defense each get a section that can be collapsed and reordered; values show two decimal places. Requires a UI reload."] },
    {
        type = "dropdown", sub = "extras", key = "statsValueFormat", label = L["Show values"],
        items = function() return ns.Extras.ValueFormatItems() end,
    },
    { type = "text", label = L["Other settings (colors, which rows show, on-screen stats) are behind the gear at the top right of the character sheet."] },
    { type = "toggle", sub = "extras", key = "titlesSearch", label = L["Title search box"] },
    { type = "text", label = L["Requires a UI reload."] },
}

ns.Options.builders.charsheet = function()
    local tab, scroll = ns.Options.MakeFormTab(L["Character Sheet"])

    -- Controls.Build 的 ctx.apply 不帶參數 ⇒ 在 set 裡記下這次改的是哪一個
    local lastKey
    local ctx = {
        get = function(spec)
            local t = ns.Controls.Resolve(ns.db, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = ns.Controls.Resolve(ns.db, spec)
            if t then t[spec.key] = v end
            lastKey = spec.key
        end,
        apply = function()
            if NEEDS_RELOAD[lastKey] then
                ns.Options.AskReload()
            else
                ns.Extras.RefreshStats()
            end
        end,
    }

    local _, refreshers = ns.Options.BuildScrollBody(scroll, controls, ctx, ns.Options.FORM_W)

    tab.Refresh = function()
        for _, fn in ipairs(refreshers) do fn() end
    end
    tab.Refresh()
    return tab
end
