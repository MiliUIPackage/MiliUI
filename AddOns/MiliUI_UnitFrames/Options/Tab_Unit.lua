------------------------------------------------------------
-- 「單位」分頁
--   左欄：單位清單
--   右上：元件切換列（框架 / 頭像 / 血條 / …）—— 一次只看一個元件的設定
--   右下：該元件的表單（Controls 引擎）
-- 分層方式：先挑對象，再挑部位，才不會一整面牆的拉桿。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls, Specs = ns.W, ns.Controls, ns.Specs
local PosSize, Pos = Specs.PosSize, Specs.Pos

-- ⚠ 這是**語系表的 key**，而 key 就是英文原文（Locales/Locale.lua 查不到就回傳 key）。
-- 原本寫成三段 `.. ` 串接，key 是串接後的結果 —— 任何人改動其中一段的空格，
-- 九個語系會同時對不上而且不報錯（靜默退成英文）。改成單一字面字串就沒有這個風險。
local TAG_SYNTAX_HELP = "Syntax: [name] [level] [curhp] [maxhp] [perchp] [curmp] [maxmp] [percmp] [shields] [healabsorbs] (blank when there is no shield), [shields_short] [healabsorbs_short] (abbreviated), [class] [race] [creaturetype] [classification]; conditional coloring [gray_if_dead:Dead], [class:name], [difficulty:level]."

local UNIT_LIST = {
    { key = "player",       label = L["Player"] },
    { key = "target",       label = L["Target"] },
    { key = "targettarget", label = L["Target of Target"] },
    { key = "focus",        label = L["Focus"] },
    { key = "focustarget",  label = L["Focus Target"] },
    { key = "pet",          label = L["Pet"] },
    { key = "boss",         label = L["Boss"] },
}

-- 元件切換列（依 DB 有沒有該元件決定要不要出現）
local ELEMENT_LIST = {
    { key = "frame",      label = L["Frame"] },
    { key = "portrait",   label = L["Portrait"] },
    { key = "hpbar",      label = L["Health bar"] },
    { key = "mpbar",      label = L["Power bar"] },
    { key = "manabar",    label = L["Mana bar"] },
    { key = "castbar",    label = L["Cast bar"] },
    { key = "buffs",      label = L["Buffs"] },
    { key = "debuffs",    label = L["Debuffs"] },
    { key = "icons",      label = L["Icons"] },
    { key = "inspect",    label = L["Inspect"] },
    { key = "texts",      label = L["Text"] },
}

local tab, scroll
local currentUnit, currentElement = "player", "frame"
local elementChips = {}
local chipHighlight
local panels = {}          -- [unitKey .. "/" .. elementKey] = { frame, refreshers, height }

------------------------------------------------------------
-- 各元件的表單 spec
------------------------------------------------------------
local function FrameSpecs(unitKey)
    local list = {
        { type = "toggle", root = "unit", key = "enabled", label = L["Enable this unit frame"],
          hint = L["Blizzard's own frame does not come back on its own after disabling; /reload is needed"] },
        { type = "header", label = L["Position and size"] },
        { type = "text", label = L["Coordinates are the frame center relative to the screen center. You can also drag it in Edit Mode."] ..
                                 L["Click into a number box and use the mouse wheel to nudge it (Shift for ×10)."] },
        { type = "numbers", root = "frame", label = L["Position"], fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "numbers", root = "frame", label = L["Size"], fields = { { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "slider", root = "frame", key = "scale", label = L["Scale (%)"], min = 50, max = 200, step = 1 },
        { type = "text", label = L["100 is the original size, multiplied by the global scale on the General tab. Everything on the frame scales with it, including the resource and mana bars anchored below; the frame grows around its center, so the position stays put."] },
    }
    if unitKey == "boss" then
        tinsert(list, { type = "header", label = L["Multiple boss layout"] })
        tinsert(list, { type = "dropdown", root = "frame", key = "growth", label = L["Grow direction"],
                        items = { { text = L["Downward"], value = "DOWN" }, { text = L["Upward"], value = "UP" } } })
        tinsert(list, { type = "slider", root = "frame", key = "spacing", label = L["Spacing"], min = 20, max = 120 })
    end
    ------------------------------------------------------------
    -- 顯示條件
    ------------------------------------------------------------
    tinsert(list, { type = "header", label = L["When to show"] })
    tinsert(list, { type = "dropdown", root = "frame", key = "visibility", label = L["Show"], items = {
        { text = L["Always"],           value = "always" },
        { text = L["In combat only"],   value = "inCombat" },
        { text = L["Out of combat only"], value = "outOfCombat" },
        { text = L["In a group"],       value = "inGroup" },
        { text = L["In a party only"],  value = "inParty" },
        { text = L["In a raid only"],   value = "inRaid" },
        { text = L["Solo only"],        value = "solo" },
    } })
    tinsert(list, { type = "text", label = L["Hidden frames stop updating entirely, so conditions cost nothing while they hide the frame."] })
    tinsert(list, { type = "toggle", root = "frame", key = "visOnlyInstances",
                    label = L["Only in instances"],
                    hint = L["Dungeons, raids, scenarios, arenas and battlegrounds."] })
    tinsert(list, { type = "toggle", root = "frame", key = "visHideMounted",
                    label = L["Hide while mounted"],
                    hint = L["Druid travel, aquatic and flight forms count as mounted."] })
    tinsert(list, { type = "toggle", root = "frame", key = "visHideNoTarget",
                    label = L["Hide without a target"] })
    tinsert(list, { type = "toggle", root = "frame", key = "visHideNoEnemy",
                    label = L["Hide without a hostile target"] })
    tinsert(list, { type = "text", label = L["These stack on top of the choice above: any one of them hides the frame. Inside restricted content whether a target is hostile can be a secret value; when it can't be determined the frame stays visible."] })

    ------------------------------------------------------------
    -- 淡出與高亮
    ------------------------------------------------------------
    tinsert(list, { type = "header", label = L["Fade"] })
    tinsert(list, { type = "toggle", root = "frame", key = "fadeOutOfRange",
                    label = L["Fade when out of range"],
                    hint = L["Fades the whole frame when the unit is beyond your reach. Transparency is set globally under General."] })
    tinsert(list, { type = "toggle", root = "frame", key = "fadeOutOfCombat",
                    label = L["Fade out of combat"],
                    hint = L["Fades the whole frame while you are not in combat. Transparency is set globally under General."] })
    tinsert(list, { type = "text", label = L["With both on, whichever is more transparent wins."] })

    tinsert(list, { type = "header", label = L["Mouseover"] })
    tinsert(list, { type = "toggle", root = "frame", key = "highlight",
                    label = L["Highlight border"],
                    hint = L["Draws a border around the frame while the cursor is over it. Color and thickness are set globally under General."] })

    tinsert(list, { type = "header", label = L["Reset"] })
    tinsert(list, { type = "button", label = L["Restore defaults"], text = L["Restore everything for this unit"], color = "red",
                    confirm = L["Restore every setting for \"%s\" to its default?"]
                              :format(ns.UNIT_LABELS[unitKey] or unitKey),
                    onClick = function()
                        ns.DB.ResetUnit(unitKey)
                        ns.ApplySettings(unitKey)
                    end })
    tinsert(list, { type = "text", label = L["Resets only this unit (position, elements, text). Other units and global styling are untouched."] })
    return list
end

local function BarSpecs(name, isHP)
    local list = {
        { type = "toggle", sub = name, key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and size"] },
        PosSize(name),
        { type = "header", label = L["Color"] },
        { type = "dropdown", sub = name, key = "colorMethod", label = L["Foreground"], items = Specs.COLOR_METHOD_ITEMS },
        { type = "slider", sub = name, key = "barAlpha", label = L["Foreground opacity"], min = 0, max = 1, step = 0.05 },
        { type = "dropdown", sub = name, key = "bgColorMethod", label = L["Background"], items = Specs.COLOR_METHOD_ITEMS },
        { type = "slider", sub = name, key = "bgAlpha", label = L["Background opacity"], min = 0, max = 1, step = 0.05 },
        { type = "color", sub = name, key = "barColor", label = L["Custom foreground color"], hasAlpha = false },
        { type = "color", sub = name, key = "bgColor", label = L["Custom background color"], hasAlpha = false },
        { type = "text", label = L["Custom colors only apply when \"Custom color\" is picked above."] },
        { type = "header", label = L["Layer"] },
        { type = "slider", sub = name, key = "level", label = L["Foreground layer"], min = 0, max = 15, step = 1 },
        { type = "slider", sub = name, key = "bgLevel", label = L["Background layer"], min = 0, max = 15, step = 1 },
        { type = "text", label = L["With the background below the portrait layer and the foreground above it, the 3D portrait sits inside the health bar and the model shows through the missing-health area."] },
        { type = "header", label = L["Border"] },
        { type = "toggle", sub = name, key = "border", label = L["Show border"] },
    }
    if isHP then
        tinsert(list, { type = "header", label = L["Missing health"] })
        tinsert(list, { type = "slider", sub = name, key = "lossAlpha", label = L["Missing health darkening"], min = 0, max = 1, step = 0.05 })
        tinsert(list, { type = "text", label = L["Lays translucent black over the missing-health area. Without it, frames with a 3D portrait give no visible health edge. 0 = no darkening."] })
        tinsert(list, { type = "header", label = L["Overlays"] })
        tinsert(list, { type = "toggle", sub = name, key = "showHealPrediction", label = L["Heal prediction"] })
        tinsert(list, { type = "color", sub = name, key = "healPredictionColor", label = L["Prediction color"] })
        tinsert(list, { type = "toggle", sub = name, key = "healPredictionFollowBar", label = L["Prediction follows bar color"] })
        tinsert(list, { type = "slider", sub = name, key = "healPredictionAlpha", label = L["Opacity when following"], min = 0.1, max = 1, step = 0.05 })
        tinsert(list, { type = "text", label = L["Grows rightward from the leading edge of the health."] })
        tinsert(list, { type = "toggle", sub = name, key = "showAbsorb", label = L["Absorb shield"] })
        tinsert(list, { type = "color", sub = name, key = "absorbColor", label = L["Absorb shield color"] })
        tinsert(list, { type = "toggle", sub = name, key = "absorbReverseFill", label = L["Absorb shield reverse fill"] })
        tinsert(list, { type = "text", label = L["Reverse means it grows **from the right end leftward**, reading like extra health (the default). Turn it off and it overlays the health from the left instead."] })
        tinsert(list, { type = "toggle", sub = name, key = "showOvershield", label = L["Overshield glow"] })
        tinsert(list, { type = "color", sub = name, key = "overshieldColor", label = L["Overshield glow color"] })
        tinsert(list, { type = "toggle", sub = name, key = "overshieldGlowReverse", label = L["Put the overshield glow on the left"] })
        tinsert(list, { type = "text", label = L["When the absorb exceeds full health the edge of the bar lights up. This side is an independent toggle, unrelated to the fill direction above."] })
        tinsert(list, { type = "header", label = L["Standalone absorb bar"] })
        tinsert(list, { type = "dropdown", sub = name, key = "absorbBarPosition", label = L["Position"], items = {
            { text = L["Off"], value = "none" },
            { text = L["Above the health bar"], value = "above" },
            { text = L["Below the health bar"], value = "below" },
        } })
        tinsert(list, { type = "slider", sub = name, key = "absorbBarHeight", label = L["Height"], min = 1, max = 16, step = 1 })
        tinsert(list, { type = "slider", sub = name, key = "absorbBarGap", label = L["Gap from the health bar"], min = 0, max = 10, step = 1 })
        tinsert(list, { type = "color", sub = name, key = "absorbBarColor", label = L["Color"] })
        tinsert(list, { type = "text", label = L["A separate thin bar for the absorb, instead of overlaying the health. With a large shield at full health the overlay whites out the whole bar; this keeps the health readable. Both can be on at once, and unlike the overlay this one also works on enemies."] })
        tinsert(list, { type = "header", label = L["Heal absorb"] })
        tinsert(list, { type = "toggle", sub = name, key = "showHealAbsorb", label = L["Heal absorb"] })
        tinsert(list, { type = "color", sub = name, key = "healAbsorbColor", label = L["Heal absorb color"] })
        tinsert(list, { type = "text", label = L["Debuffs that eat healing, such as Necrotic. Reverse-filled and drawn on top."] })
    end
    return list
end

local function PortraitSpecs()
    return {
        { type = "toggle", sub = "portrait", key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and size"] },
        PosSize("portrait"),
        { type = "header", label = L["Style"] },
        { type = "dropdown", sub = "portrait", key = "mode", label = L["Mode"],
          items = { { text = L["3D model"], value = "3d" }, { text = L["2D image"], value = "2d" } } },
        { type = "toggle", sub = "portrait", key = "fallback2D", label = L["Fall back to 2D"] },
        { type = "text", label = L["Enemies inside 12.1 instances have restricted identity and their 3D model can't be fetched (in practice it doesn't error, it just returns nothing). By default nothing is drawn in that case; turn this on to draw the 2D portrait instead. The client resolves 2D portraits itself, so even trash works. It's the same one Blizzard's own frames use."] },
        { type = "color", sub = "portrait", key = "bg", label = L["Backdrop color"] },
        { type = "text", label = L["Drop the background opacity to 0 for no backdrop, leaving the 3D model floating on screen. That's the boss frame default."] },
        { type = "slider", sub = "portrait", key = "zoom", label = L["3D zoom"], min = 0, max = 1, step = 0.05 },
        { type = "text", label = L["1 = close-up on the face, 0 = full body; around 0.6 shows down to the shoulders."] },
        { type = "slider", sub = "portrait", key = "rotation", label = L["3D rotation (degrees)"], min = -180, max = 180, step = 5 },
        { type = "text", label = L["0 faces the camera; around ±25 gives a three-quarter view, and setting player and target to opposite values makes them look at each other. 180 shows the back."] },
        { type = "slider", sub = "portrait", key = "modelOffsetX", label = L["Model horizontal"], min = -100, max = 100, step = 5, scale = 100 },
        { type = "slider", sub = "portrait", key = "modelOffsetY", label = L["Model vertical"], min = -100, max = 100, step = 5, scale = 100 },
        { type = "text", label = L["Rotated models often sit off to one side; use these two to push it back to the middle (positive = right / up)."] },
        { type = "slider", sub = "portrait", key = "level", label = L["Layer"], min = 0, max = 15, step = 1 },
        { type = "text", label = L["A layer above the health bar (4) makes the portrait float over it for a cut-out look."] },
    }
end


local function ManaBarSpecs()
    return {
        { type = "toggle", sub = "manabar", key = "enabled", label = L["Show"] },
        { type = "text", label = L["A small mana bar that only appears when mana isn't the main resource (cat, bear, elemental, shadow priest)."] },
        { type = "header", label = L["Position and size"] },
        PosSize("manabar"),
        { type = "text", label = L["Same coordinate meaning as the resource bars: Y starts at the bottom edge of the frame, negative goes down."] ..
                                 L["By default it sits just above the resource bars (frame bottom > 6 > mana bar > 2 > resource bars) so the two never overlap."] },
        { type = "header", label = L["Color and appearance"] },
        { type = "color", sub = "manabar", key = "color", label = L["Foreground color"] },
        { type = "text", label = L["Left empty it uses the global mana blue, the same color the power bar uses for mana."] },
        { type = "slider", sub = "manabar", key = "barAlpha", label = L["Fill opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "slider", sub = "manabar", key = "bgAlpha", label = L["Background opacity"], min = 0, max = 1, step = 0.05 },
        { type = "toggle", sub = "manabar", key = "border", label = L["Show border"] },
        { type = "text", label = L["Looks like a resource bar row: a background plus a 1px black edge all round. The border eats 1px top and bottom, so a height of 5 or more is recommended."] },
        { type = "header", label = L["Layer"] },
        { type = "slider", sub = "manabar", key = "level", label = L["Layer"], min = 0, max = 15, step = 1 },
    }
end

local function TextStyleSpecs(sub, sub2, label)
    return {
        { type = "header", label = label },
        { type = "numbers", sub = sub, sub2 = sub2, label = L["Position and size"],
          fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "slider", sub = sub, sub2 = sub2, key = "size", label = L["Font size"], min = 6, max = 32 },
        { type = "dropdown", sub = sub, sub2 = sub2, key = "flags", label = L["Outline"], items = Specs.FLAGS_ITEMS },
        { type = "dropdown", sub = sub, sub2 = sub2, key = "justifyH", label = L["Horizontal align"], items = Specs.JUSTIFY_H_ITEMS },
        { type = "color", sub = sub, sub2 = sub2, key = "color", label = L["Color"] },
    }
end

local function CastbarSpecs()
    local list = {
        { type = "toggle", sub = "castbar", key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and size"] },
        PosSize("castbar"),
        { type = "header", label = L["Appearance"] },
        { type = "color", sub = "castbar", key = "bg", label = L["Background color"] },
        { type = "slider", sub = "castbar", key = "barAlpha", label = L["Fill opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "text", label = L["Only the colored fill; the icon and text stay fully readable, and the background has its own opacity in the color above. Turn it down and the 3D portrait shows through while casting — on the player and target the cast bar sits exactly on top of the portrait."] },
        { type = "toggle", sub = "castbar", key = "border", label = L["Show border"] },
        { type = "toggle", sub = "castbar", key = "showInterruptState", label = L["Show non-interruptible"] },
        { type = "dropdown", sub = "castbar", key = "shieldStyle", label = L["Shield style"], items = ns.Media.SHIELD_STYLES },
        { type = "text", label = L["When on, non-interruptible casts turn gray and show a shield on the icon. Off by default for you and your pet, since whether your own cast can be interrupted is meaningless."] },
        { type = "toggle", sub = "castbar", key = "showSpark", label = L["Spark at the leading edge"] },
        { type = "text", label = L["A bright dot that rides the front of the fill. Off by default."] },
        { type = "toggle", sub = "castbar", key = "classColorBar", label = L["Use the class color for the fill"] },
        { type = "text", label = L["One color for casting, channeling and empowered alike, taken from the unit's class (pets use their owner's). On your own frame the cast bar sits on top of the portrait next to the health and power bars, and a single hue reads much calmer than three. The tints below still layer on top."] },
        { type = "toggle", sub = "castbar", key = "showImportantCast", label = L["Tint important spells"] },
        { type = "text", label = L["Which spells count as important is decided by the game itself, not by a list this addon maintains — the same call the Platynator nameplates use. The color lives under General > Cast bar colors. Ranked below \"interrupt ready\" and \"non-interruptible\"."] },
        { type = "toggle", sub = "castbar", key = "showInterruptReady", label = L["Tint while your interrupt is ready"] },
        { type = "text", label = L["Tints the bar while your own interrupt is off cooldown — one glance tells you whether a cast is worth stopping. The color lives under General > Cast bar colors. A non-interruptible cast still wins and stays gray. Off for you and your pet."] },
        { type = "toggle", sub = "castbar", key = "showCompleteFlash", label = L["Color on finish"] },
        { type = "slider", sub = "castbar", key = "fadeTime", label = L["Fade time (seconds)"], min = 0.1, max = 1.5, step = 0.05 },
        { type = "slider", sub = "castbar", key = "interruptHold", label = L["Interrupt hold (seconds)"], min = 0, max = 2, step = 0.1 },
        { type = "text", label = L["A finished cast turns completion yellow, a failed one failure red, then fades out."] ..
                                 L["Channels and empowered casts don't change color when they run out, they just fade; they were always going to finish, so recoloring looks wrong."] ..
                                 L["With this off, a finished cast keeps its color too. An interrupted cast shows the interrupter on a red bar, holds for the given seconds, then fades."] },
        { type = "dropdown", sub = "castbar", key = "timeFormat", label = L["Time format"], items = {
            { text = L["Remaining / total (0.3/1.5)"], value = "remainTotal" },
            { text = L["Elapsed / total (1.2/1.5)"], value = "elapsedTotal" },
            { text = L["Remaining (0.3)"],           value = "remain" },
            { text = L["Elapsed (1.2)"],           value = "elapsed" },
        } },
        { type = "text", label = L["In restricted content (instances, combat) the seconds on an enemy cast are a secret value, so you may get a moving bar with no number. That's a 12.1 limitation."] },
        { type = "header", label = L["Icon"] },
        { type = "numbers", sub = "castbar", sub2 = "icon", label = L["Position and size"],
          fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "toggle", sub = "castbar", key = "showShield", label = L["Non-interruptible shield"] },
        { type = "text", label = L["Shows a shield in front of the icon when a cast can't be interrupted. In restricted content that flag is a secret value, so the game drives the shield straight from the secret boolean and the addon never reads it."] },
        { type = "slider", sub = "castbar", key = "shieldScale", label = L["Shield size (× icon)"], min = 0.5, max = 1.5, step = 0.05 },
        { type = "numbers", sub = "castbar", label = L["Shield offset"],
          fields = { { key = "shieldOffsetX", label = "X" }, { key = "shieldOffsetY", label = "Y" } } },
    }
    tinsert(list, { type = "header", label = L["Cast target"] })
    tinsert(list, { type = "toggle", sub = "castbar", key = "showCastTarget", label = L["Show who the cast is aimed at"] })
    tinsert(list, { type = "text", label = L["The name of the caster's current target. Useful on the focus and boss frames for spotting a tank swap or a fixate. Only available for units the game gives a target token for (player, pet, target, focus, boss), and in restricted content the name may be unavailable."] })
    for _, s in ipairs(TextStyleSpecs("castbar", "spell", L["Spell name"])) do tinsert(list, s) end
    for _, s in ipairs(TextStyleSpecs("castbar", "time", L["Time"])) do tinsert(list, s) end
    for _, s in ipairs(TextStyleSpecs("castbar", "castTarget", L["Cast target"])) do tinsert(list, s) end
    return list
end

local function AuraSpecs(name)
    return {
        { type = "toggle", sub = name, key = "enabled", label = L["Show"] },
        { type = "header", label = L["Position and layout"] },
        Pos(name),
        { type = "numbers", sub = name, label = L["Icon size"], fields = { { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } },
        { type = "dropdown", sub = name, key = "growth", label = L["Grow direction"], items = Specs.GROWTH_ITEMS },
        { type = "slider", sub = name, key = "perRow", label = L["Per row"], min = 1, max = 20 },
        { type = "slider", sub = name, key = "maxCount", label = L["Max count"], min = 1, max = 40 },
        { type = "slider", sub = name, key = "spacing", label = L["Spacing"], min = 0, max = 10 },
        { type = "header", label = L["Filter"] },
        -- 模式清單的唯一來源在 Elements/Auras.lua（ns.AuraFilterItems）
        { type = "dropdown", sub = name, key = "filterMode", label = L["Show only"],
          items = function() return ns.AuraFilterItems(name) end },
        { type = "toggle", sub = name, key = "onlyMine", label = L["Only show my own"] },
        { type = "text", label = L["Filtering is done by the game, not by a spell list — 12.1 addons can't read aura contents. The two settings stack: \"dispellable by me\" plus \"only my own\" shows only what you applied and can remove. Changing either rebuilds the icons."] },
        { type = "header", label = L["Text"] },
        { type = "toggle", sub = name, key = "showStack", label = L["Show stacks"] },
        { type = "slider", sub = name, key = "stackSize", label = L["Stack font size"], min = 6, max = 20 },
        { type = "dropdown", sub = name, key = "stackAnchor", label = L["Stack anchor"], items = Specs.ANCHOR_ITEMS },
        { type = "numbers", sub = name, label = L["Stack offset"],
          fields = { { key = "stackX", label = "X" }, { key = "stackY", label = "Y" } } },
        { type = "text", label = L["The anchor is which corner of the number sits on the same corner of the icon, so which way the offset pushes depends on it: from the top left, positive X goes right and negative Y goes down."] },
        { type = "toggle", sub = name, key = "durationText", label = L["Show countdown"] },
        { type = "slider", sub = name, key = "durationThreshold", label = L["Show within seconds"], min = 5, max = 600, step = 5 },
        { type = "text", label = L["The countdown is drawn by the game (12.1 addons can't read the remaining seconds); changing this rebuilds the icons."] },
    }
end

local function IconSpecs(els)
    local list = {}
    local defs = {
        { key = "raidtarget", label = L["Raid target marker"] },
        { key = "status",     label = L["Status (combat / resting)"] },
        { key = "leader",     label = L["Leader"] },
        { key = "pvp",        label = "PvP" },
    }
    for _, d in ipairs(defs) do
        if els.icons[d.key] then
            tinsert(list, { type = "header", label = d.label })
            tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "enabled", label = L["Show"] })
            -- 只有玩家框的 status 有這兩個鍵，其他單位不會冒出無效選項
            if els.icons[d.key].restAnimated ~= nil then
                tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "restAnimated",
                                label = L["Animated zzZ while resting"] })
                tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "combatBlizzard",
                                label = L["Blizzard combat icon (native 16x16, ignores the size below)"] })
            end
            tinsert(list, PosSize("icons", nil, d.key))
        end
    end
    return list
end

local function InspectSpecs()
    return {
        { type = "toggle", sub = "inspect", key = "enabled", label = L["Show"] },
        { type = "text", label = L["A small button on the frame that opens the inspect window. Only players can be inspected, so it only shows up on them."] },
        { type = "header", label = L["Position and size"] },
        PosSize("inspect"),
        { type = "header", label = L["Appearance"] },
        { type = "dropdown", sub = "inspect", key = "style", label = L["Icon"], items = ns.INSPECT_STYLE_ITEMS },
        { type = "color", sub = "inspect", key = "bgColor", label = L["Background color"] },
        { type = "toggle", sub = "inspect", key = "border", label = L["Show border"] },
        { type = "slider", sub = "inspect", key = "alpha", label = L["Opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "slider", sub = "inspect", key = "iconPadding", label = L["Icon padding"], min = 0, max = 6, step = 1 },
        { type = "header", label = L["Layer"] },
        { type = "slider", sub = "inspect", key = "level", label = L["Layer"], min = 0, max = 15, step = 1 },
        { type = "text", label = L["It has to sit above the health bar to stay clickable; 8 is the default."] },
    }
end

local function TextsSpecs(els)
    local list = {
        { type = "text", label = L[TAG_SYNTAX_HELP] },
    }
    for i = 1, #els.texts do
        tinsert(list, { type = "header", label = L["Text %d"]:format(i) })
        tinsert(list, { type = "toggle", sub = "texts", index = i, key = "enabled", label = L["Show"] })
        tinsert(list, { type = "input", sub = "texts", index = i, key = "pattern", label = L["Content"] })
        tinsert(list, { type = "numbers", sub = "texts", index = i, label = L["Position and size"],
                        fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } })
        tinsert(list, { type = "slider", sub = "texts", index = i, key = "size", label = L["Font size"], min = 6, max = 32 })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "flags", label = L["Outline"], items = Specs.FLAGS_ITEMS })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "justifyH", label = L["Horizontal align"], items = Specs.JUSTIFY_H_ITEMS })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "justifyV", label = L["Vertical align"], items = Specs.JUSTIFY_V_ITEMS })
        tinsert(list, { type = "color", sub = "texts", index = i, key = "color", label = L["Color"] })
    end
    return list
end

local function SpecsFor(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    local els = udb.elements
    if elementKey == "frame" then return FrameSpecs(unitKey) end
    if elementKey == "portrait" then return PortraitSpecs() end
    if elementKey == "hpbar" then return BarSpecs("hpbar", true) end
    if elementKey == "mpbar" then return BarSpecs("mpbar", false) end
    if elementKey == "manabar" then return ManaBarSpecs() end
    if elementKey == "castbar" then return CastbarSpecs() end
    if elementKey == "buffs" then return AuraSpecs("buffs") end
    if elementKey == "debuffs" then return AuraSpecs("debuffs") end
    if elementKey == "icons" then return IconSpecs(els) end
    if elementKey == "inspect" then return InspectSpecs() end
    if elementKey == "texts" then return TextsSpecs(els) end
    return {}
end

------------------------------------------------------------
-- 面板生成
------------------------------------------------------------
local function BuildPanel(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(520, 1)

    local ctx = {
        get = function(spec)
            local root = (spec.root == "unit" and udb)
                or (spec.root == "frame" and udb.frame)
                or udb.elements
            local t = Controls.Resolve(root, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local root = (spec.root == "unit" and udb)
                or (spec.root == "frame" and udb.frame)
                or udb.elements
            local t = Controls.Resolve(root, spec)
            if t then t[spec.key] = v end
        end,
        apply = function() ns.ApplySettings(unitKey) end,
    }

    local height, refreshers, rows = Controls.Build(content, SpecsFor(unitKey, elementKey), ctx, 4, -8, 520)
    content:SetHeight(height + 24)
    content:Hide()
    -- textCount：表單的**結構**是 build 當下依 #els.texts 生的，記下來才比對得出
    -- 「恢復預設之後條目數變了」（見底部的 SettingsApplied）
    local texts = udb.elements and udb.elements.texts
    return { frame = content, refreshers = refreshers, height = height + 24,
             rows = rows,
             textCount = texts and #texts or nil }
end

------------------------------------------------------------
-- 表單快取失效
--
-- 表單的**結構**是 build 當下依 DB 生出來的（文字分頁是 `for i = 1, #els.texts`），
-- 之後就一直重用。所以「恢復預設」把文字條目數改掉之後，快取住的那份會停在舊的條數
-- ——多的殘留、少的看不到。設定套用時把那個單位的表單全部丟掉，下次進去重建。
--
-- 只丟該單位的（`unitKey/*`），別的單位沒必要重建。
------------------------------------------------------------
local function InvalidatePanels(unitKey)
    local prefix = unitKey .. "/"
    for id, p in pairs(panels) do
        if id:sub(1, #prefix) == prefix then
            p.frame:Hide()     -- frame 無法銷毀，丟掉參照＋藏起來就好
            panels[id] = nil
        end
    end
end

local function ShowPanel(unitKey, elementKey)
    for _, p in pairs(panels) do p.frame:Hide() end
    local id = unitKey .. "/" .. elementKey
    if not panels[id] then panels[id] = BuildPanel(unitKey, elementKey) end
    local p = panels[id]
    for _, fn in ipairs(p.refreshers) do fn() end
    p.frame:Show()
    scroll:SetContentHeight(p.height)
    scroll:SetVerticalScroll(0)
end

-- 元件切換列：依單位有的元件重排 chip
local function RefreshChips(unitKey)
    local els = ns.GetUnitDB(unitKey).elements
    local prev
    local firstVisible
    for _, chip in ipairs(elementChips) do
        -- DB 有這欄 且 這個職業真的有註冊該元件（職業資源條只對六個職業註冊，
        -- 薩滿看到卻調了沒反應會很困惑）
        local visible = chip.id == "frame"
            or (els[chip.id] ~= nil and ns.Elements[chip.id] ~= nil)
        chip:SetShown(visible)
        if visible then
            chip:ClearAllPoints()
            if prev then
                chip:SetPoint("LEFT", prev, "RIGHT", 3, 0)
            else
                chip:SetPoint("TOPLEFT", tab.chipRow, "TOPLEFT", 0, 0)
            end
            prev = chip
            firstVisible = firstVisible or chip
        end
    end
    -- 目前選的元件這個單位沒有 → 退回框架
    local ok = false
    for _, chip in ipairs(elementChips) do
        if chip.id == currentElement and chip:IsShown() then ok = true end
    end
    if not ok then currentElement = "frame" end
    for _, chip in ipairs(elementChips) do
        if chip.id == currentElement then chipHighlight(chip) end
    end
end

local function SelectUnit(unitKey)
    currentUnit = unitKey
    RefreshChips(unitKey)
    ShowPanel(unitKey, currentElement)
    ns.Preview.Highlight(unitKey)
    ns.Preview.SetElement(currentElement)
end

local function SelectElement(elementKey)
    currentElement = elementKey
    ShowPanel(currentUnit, elementKey)
    -- 只有選到施法條時預覽才演示假施法（它會蓋住頭像，調別的元件時很礙事）
    ns.Preview.SetElement(elementKey)
end

------------------------------------------------------------
-- 分頁本體
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    -- 左欄單位清單
    local unitButtons = {}
    for i, info in ipairs(UNIT_LIST) do
        local b = W.CreateButton(tab, info.label, "accent-hover", 106, 24)
        b.id = info.key
        b:SetPoint("TOPLEFT", 12, -14 - (i - 1) * 28)
        unitButtons[i] = b
    end
    tab._unitHighlight = W.CreateButtonGroup(unitButtons, SelectUnit)
    tab._unitButtons = unitButtons

    -- 分隔線
    local sep = tab:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sep:SetVertexColor(0, 0, 0, 1)
    sep:SetPoint("TOPLEFT", 128, -10)
    sep:SetPoint("BOTTOMLEFT", 128, 10)
    sep:SetWidth(ns.P.Scale(1))

    -- 右上：元件切換列
    local chipRow = CreateFrame("Frame", nil, tab)
    chipRow:SetPoint("TOPLEFT", 140, -14)
    chipRow:SetPoint("RIGHT", -12, 0)
    chipRow:SetHeight(22)
    tab.chipRow = chipRow
    for _, info in ipairs(ELEMENT_LIST) do
        local chip = W.CreateButton(chipRow, info.label, "accent-hover", 46, 20)
        chip.id = info.key
        -- 寬度依文字自適應（中文 2-4 字）
        chip:SetWidth(math.max(40, chip:GetFontString():GetStringWidth() + 16))
        tinsert(elementChips, chip)
    end
    chipHighlight = W.CreateButtonGroup(elementChips, SelectElement)

    -- 切換列下方一條淡線
    local chipLine = tab:CreateTexture(nil, "ARTWORK")
    chipLine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    chipLine:SetVertexColor(1, 1, 1, 0.08)
    chipLine:SetPoint("TOPLEFT", chipRow, "BOTTOMLEFT", 0, -6)
    chipLine:SetPoint("TOPRIGHT", chipRow, "BOTTOMRIGHT", 0, -6)
    chipLine:SetHeight(ns.P.Scale(1))

    -- 右下：表單卷軸
    local scrollHolder = CreateFrame("Frame", nil, tab)
    scrollHolder:SetPoint("TOPLEFT", chipRow, "BOTTOMLEFT", 0, -12)
    scrollHolder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(scrollHolder)
end

------------------------------------------------------------
-- 表單快取失效（E5）
--
-- 文字分頁的表單是 `for i = 1, #els.texts` 生出來的，之後一直重用。「恢復預設」把
-- 條目數改掉之後，快取住的那份會停在舊的條數 —— 多的殘留、少的看不到。
--
-- ⚠ 只在條目數**真的變了**時丟。ApplySettings 是每動一個控件都會跑的，
-- 無條件重建會把輸入焦點與捲動位置弄掉。
-- 註冊放在檔案底部：InvalidatePanels 與 ShowPanel 都要在 scope 裡（宣告在下面的
-- local function 從上面呼叫會拿到全域 nil）。
------------------------------------------------------------
-- 換設定檔：每個面板的 ctx 都把**那一份**設定檔的 udb 捕捉在 closure 裡，
-- 換過去之後那些 closure 還在寫舊表 —— 症狀是「切了設定檔，面板上的數字沒變，
-- 而且一動就改到舊的那份」。全部丟掉重建。
ns.RegisterCallback("ProfileChanged", "unitTabPanels", function()
    for id, p in pairs(panels) do
        p.frame:Hide()      -- frame 無法銷毀，丟參照＋藏起來
        panels[id] = nil
    end
    if tab and tab:IsShown() and currentUnit then
        ShowPanel(currentUnit, currentElement)
    end
end)

ns.RegisterCallback("SettingsApplied", "unitTabPanels", function(unitKey)
    local p = panels[unitKey .. "/texts"]
    if not p then return end
    local udb = ns.GetUnitDB(unitKey)
    local texts = udb and udb.elements and udb.elements.texts
    if not texts or p.textCount == #texts then return end
    InvalidatePanels(unitKey)
    -- 現在顯示的那份可能剛被丟掉 → 立刻重建，不然分頁會空著等使用者亂點
    if tab and tab:IsShown() and currentUnit == unitKey then
        ShowPanel(currentUnit, currentElement)
    end
end)

ns.RegisterCallback("ShowOptionsTab", "unitTab", function(id)
    if id ~= "units" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
    for _, b in ipairs(tab._unitButtons) do
        if b.id == currentUnit then tab._unitHighlight(b) end
    end
    SelectUnit(currentUnit)
end)

------------------------------------------------------------
-- 設定搜尋（Options/Search.lua）
--
-- 列舉的是 spec 表本身，所以「單位 × 元件」每一種組合都進得了索引，
-- 不必先把那些分頁建出來（這一頁有 7 個單位 × 最多 11 個元件，
-- 靠「開過才收得到」的做法等於幾乎搜不到東西）。
--
-- 元件的可見性判斷跟 RefreshChips 同一套：DB 有這欄，而且這個職業真的有註冊該元件。
------------------------------------------------------------
ns.Search.Register("units", {
    label = L["Units"],
    enumerate = function(add)
        for _, u in ipairs(UNIT_LIST) do
            local udb = ns.GetUnitDB(u.key)
            local els = udb and udb.elements
            if els then
                for _, e in ipairs(ELEMENT_LIST) do
                    if e.key == "frame" or (els[e.key] ~= nil and ns.Elements[e.key] ~= nil) then
                        add(SpecsFor(u.key, e.key), u.label .. " › " .. e.label,
                            { unit = u.key, element = e.key })
                    end
                end
            end
        end
    end,
    jump = function(payload, spec)
        if not payload then return end
        Init()
        -- 走跟使用者自己點一樣的路徑：SelectUnit 會重排 chip、切面板、同步預覽
        currentElement = payload.element
        SelectUnit(payload.unit)
        for _, b in ipairs(tab._unitButtons) do
            if b.id == payload.unit then tab._unitHighlight(b) end
        end
        local p = panels[payload.unit .. "/" .. payload.element]
        if p then ns.Search.Reveal(scroll, p.frame, p.rows, spec) end
    end,
})
