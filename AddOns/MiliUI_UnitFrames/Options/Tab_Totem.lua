------------------------------------------------------------
-- 「單位 → 玩家 → 召喚物」面板的內容
--
-- 召喚物框（Elements/Totems.lua）掛在玩家框底下、跟資源條同一組座標，所以設定跟著
-- 資源條一樣放在玩家單位的 chip 列裡（Options/Tab_Unit.lua），不再是頂層分頁。
-- 這一支只負責**內容**（控件清單與 ctx）；面板本身（frame、快取、捲動、重建）歸 Tab_Unit 管，
-- 「選到這顆 chip 就填四個示範召喚物、離開就收」也由 Tab_Unit 在 ShowPanel 裡切。
--
-- 資料在 ns.db.units.totem（一個獨立的偽單位，不是玩家的元件），所以 ctx 的 root 是它；
-- 而 chip 要不要出現看 ns.TOTEM_CLASSES（Elements/Totems.lua 是唯一來源）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local Controls = ns.Controls

local CONTROLS = {
    { type = "toggle", key = "enabled", label = L["Show summons frame"] },
    { type = "text",   label = L["|cff4DD2FFWhile this tab is open the frame shows four demo summons|r (with running timer bars and countdowns) so you can line up position and size. Switch tabs or close the panel to go back to the real state."] },
    { type = "text",   label = L["Totems, Jade Serpent / Black Ox statues, Efflorescence and anything else you drop that sticks around for a while: Blizzard keeps them all in the same set of four slots, so they are managed together here. Style: icon capsules with a timer bar along the bottom."] },
    { type = "header", label = L["Position and size"] },
    { type = "text",   label = L["Offset from the bottom-left corner of the player frame (negative goes down), sharing coordinates with the resource bars, so it follows the player frame when you move it. You can also drag it in Edit Mode. The frame is always four slots wide, filling left to right."] },
    { type = "numbers", sub = "frame", label = L["Position"], fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
    { type = "slider", sub = "frame", key = "iconSize", label = L["Icon size"], min = 16, max = 64 },
    { type = "slider", sub = "frame", key = "spacing", label = L["Spacing"], min = 0, max = 16 },
    { type = "slider", sub = "frame", key = "scale", label = L["Scale (%)"], min = 50, max = 200, step = 1 },
    { type = "text",   label = L["100 is the original size, multiplied by the global scale on the General tab. Icon size and spacing keep their own numbers."] },
    { type = "header", label = L["Color and order"] },
    { type = "dropdown", key = "colors", label = L["Timer bar color"],
      items = { { text = L["Class color"], value = "accent" }, { text = L["Element colors (fire / earth / water / air)"], value = "element" } } },
    { type = "toggle", key = "swapEarthFire", label = L["Swap earth and fire positions"] },
    { type = "header", label = L["Time remaining"] },
    { type = "toggle", key = "showTimeText", label = L["Show remaining seconds"] },
    { type = "text",   label = L["Turn this off to keep only the bar at the bottom. 12.1 sometimes won't hand over the remaining time; when that happens the number stays blank and the bar shows full."] },
    { type = "header", label = L["Reset"] },
    { type = "button", label = L["Restore defaults"], text = L["Restore summons defaults"], color = "red",
      confirm = L["Restore the summons frame settings to their defaults?"],
      onClick = function()
          ns.DB.ResetUnit("totem")
          if ns.TotemsApplySettings then ns.TotemsApplySettings() end
          -- 控件顯示值是 refresher 推上去的，只在面板顯示時跑 ⇒ 丟掉面板重建，
          -- 不然滑桿會停在還原前的數字（以前的頂層分頁也有這個毛病）
          if ns.Options.RebuildUnitPanel then ns.Options.RebuildUnitPanel("player", "totem", true) end
      end },
}

-- root 每次現查 ns.db：換設定檔之後 ns.db 會被重指，抓著舊表的 closure 會寫到舊設定檔
local ctx = Controls.MakeCtx(function() return ns.db.units.totem end, function()
    if ns.TotemsApplySettings then ns.TotemsApplySettings() end
end)

ns.Options.TotemForm = {
    Controls = CONTROLS,
    ctx      = ctx,
}
