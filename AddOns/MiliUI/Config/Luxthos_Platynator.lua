MiliUI_PlatynatorProfile = {
["stack_region_scale_y"] = 1.4,
["design_all"] = {
},
["migration"] = 6,
["not_in_combat_alpha"] = 1,
["not_target_behaviour"] = "none",
["simplified_nameplates"] = {
["minor"] = false,
["minion"] = false,
["instancesNormal"] = false,
},
["stacking_nameplates"] = {
["friend"] = false,
["enemy"] = true,
},
["obscured_combat_alpha"] = 0.4,
["show_friendly_in_instances"] = true,
["blizzard_widget_scale"] = 1.2,
["show_friendly_in_instances_1"] = "name_only",
["stack_applies_to"] = {
["normal"] = true,
["minion"] = false,
["minor"] = false,
},
["not_target_alpha"] = 0.9,
["show_nameplates_only_needed"] = false,
["click_region_scale_x"] = 1.1,
["kind"] = "profile",
["cast_alpha"] = 1,
["stack_region_scale_x"] = 1.1,
["design_assignments"] = {
{
["scale"] = 1,
["simplified"] = false,
["criteria"] = {
"cannot-attack",
},
["style"] = "MiliUI (Only Name)",
},
{
["scale"] = 1,
["simplified"] = false,
["criteria"] = {
"can-attack",
},
["style"] = "Luxthos",
},
},
["mouseover_alpha"] = 1,
["closer_to_screen_edges"] = true,
["obscured_alpha"] = 0.4,
["cast_scale"] = 1,
["closer_nameplates"] = true,
["nameplate_position"] = "top",
["designs_assigned"] = {
["enemySimplifiedCombat"] = "_hare_simplified",
["enemyPvPPlayer"] = "_deer",
["enemy"] = "Luxthos",
["friendCombat"] = "_name-only",
["friendPvPPlayer"] = "_name-only",
["enemySimplified"] = "Luxthos (Simplified)",
["friend"] = "MiliUI (Only Name)",
["enemyCombat"] = "_deer",
},
["simplified_assigned_fallback"] = "Luxthos (Simplified)",
["vertical_offset"] = 0,
["designs_enabled"] = {
["pvpInstance"] = false,
["combat"] = false,
["pvpWorld"] = false,
},
["target_scale"] = 1.2,
["cast_interrupted_timeout"] = 0.3,
["addon"] = "Platynator",
["apply_cvars"] = true,
["current_skin"] = "blizzard",
["designs"] = {
["Luxthos"] = {
["highlights"] = {
{
["color"] = {
["a"] = 0.3776039183139801,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 2,
["asset"] = "Platy: Striped Reverse",
["width"] = 1.48,
["kind"] = "focus",
["height"] = 0.98,
["sliced"] = false,
["anchor"] = {
"LEFT",
-93,
0,
},
["scale"] = 1,
},
{
["color"] = {
["a"] = 0.6119787096977234,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 2,
["asset"] = "Platy: 1px",
["width"] = 1,
["scale"] = 1.52,
["kind"] = "mouseover",
["height"] = 0.8,
["sliced"] = true,
["anchor"] = {
},
["includeTarget"] = true,
},
{
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 0,
["asset"] = "Platy: 1px",
["width"] = 1,
["kind"] = "target",
["anchor"] = {
},
["sliced"] = true,
["scale"] = 1.51,
["height"] = 0.82,
},
{
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 1,
["asset"] = "Platy: Arrow Double",
["width"] = 2,
["kind"] = "target",
["anchor"] = {
},
["sliced"] = true,
["height"] = 1.25,
["scale"] = 1,
},
},
["specialBars"] = {
},
["scale"] = 1.05,
["auras"] = {
{
["height"] = 1,
["direction"] = "RIGHT",
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.7,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.55,
},
},
["showSwipe"] = true,
["scale"] = 1.4,
["layer"] = 1,
["textScale"] = 1,
["showPandemic"] = true,
["showTooltips"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["limit"] = 30,
["showType"] = false,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["kind"] = "debuffs",
["showCountdown"] = true,
["filters"] = {
["fromYou"] = true,
["important"] = true,
},
},
{
["height"] = 1,
["direction"] = "LEFT",
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.17,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.92,
},
},
["showCountdown"] = true,
["scale"] = 1,
["layer"] = 1,
["textScale"] = 1,
["showSwipe"] = true,
["showTooltips"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["limit"] = 30,
["showType"] = true,
["anchor"] = {
"BOTTOMLEFT",
-118.5,
-9,
},
["kind"] = "buffs",
["showStealable"] = false,
["filters"] = {
["dispelable"] = true,
["important"] = true,
["defensive"] = false,
},
},
{
["direction"] = "RIGHT",
["showType"] = false,
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.82,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.64,
},
},
["scale"] = 1.7,
["layer"] = 1,
["textScale"] = 1,
["showSwipe"] = true,
["showTooltips"] = true,
["height"] = 1,
["limit"] = 30,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["anchor"] = {
"RIGHT",
154,
0,
},
["kind"] = "crowdControl",
["showCountdown"] = true,
["filters"] = {
["fromYou"] = false,
},
},
},
["regions"] = {
["stack"] = {
["anchor"] = {
"TOP",
0,
31.36,
},
["autoSized"] = true,
["height"] = 4.35,
["width"] = 1.65,
},
["click"] = {
["anchor"] = {
"TOP",
0,
25.7,
},
["autoSized"] = true,
["height"] = 3.62,
["width"] = 1.5,
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
["slug"] = true,
},
["version"] = 10,
["bars"] = {
{
["absorb"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["asset"] = "Platy: Absorb Wide",
},
["animate"] = false,
["marker"] = {
["asset"] = "none",
},
["layer"] = 1,
["border"] = {
["height"] = 0.75,
["color"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["asset"] = "Platy: 1px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
["neutral"] = {
["b"] = 0.1607843190431595,
["g"] = 0.5882353186607361,
["r"] = 1,
},
["hostile"] = {
["b"] = 0.1607843190431595,
["g"] = 0.5882353186607361,
["r"] = 1,
},
["friendly"] = {
["b"] = 0.1607843190431595,
["g"] = 0.5882353186607361,
["r"] = 1,
},
},
["kind"] = "quest",
},
{
["colors"] = {
},
["kind"] = "classColors",
},
{
["colors"] = {
["tapped"] = {
["r"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["b"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["enabled"] = {
["boss"] = true,
["melee"] = true,
["caster"] = true,
["trivial"] = true,
["miniboss"] = true,
},
["colors"] = {
["boss"] = {
["r"] = 0.7372549019607844,
["g"] = 0.1098039215686275,
["b"] = 0,
},
["melee"] = {
["r"] = 0.7803922295570374,
["g"] = 0.6196078658103943,
["b"] = 0.3686274588108063,
},
["caster"] = {
["b"] = 1,
["g"] = 0.6431372761726379,
["r"] = 0,
},
["trivial"] = {
["r"] = 0.4705882668495178,
["g"] = 0.4039216041564941,
["b"] = 0.3254902064800263,
},
["miniboss"] = {
["r"] = 0.5647058823529412,
["g"] = 0,
["b"] = 0.7372549019607844,
},
},
["kind"] = "eliteType",
["applyCasterAlways"] = false,
["instancesOnly"] = true,
},
{
["combatOnly"] = true,
["colors"] = {
["offtank"] = {
["r"] = 0.05882353335618973,
["g"] = 0.6666666865348816,
["b"] = 0.7843137979507446,
},
["transition"] = {
["r"] = 1,
["g"] = 0.6274510025978088,
["b"] = 0,
},
["safe"] = {
["r"] = 0.05882353335618973,
["g"] = 0.5882353186607361,
["b"] = 0.9019608497619628,
},
["warning"] = {
["b"] = 0.168627455830574,
["g"] = 0.1411764770746231,
["r"] = 0.729411780834198,
},
},
["useSafeColor"] = false,
["useOffTankColor"] = true,
["kind"] = "threat",
["tanksOnly"] = false,
["instancesOnly"] = true,
},
{
["colors"] = {
["neutral"] = {
["b"] = 0.3176470696926117,
["g"] = 0.7176470756530762,
["r"] = 0.8588235974311829,
},
["friendly"] = {
["r"] = 0.2745098173618317,
["g"] = 0.8862745761871338,
["b"] = 0.3372549116611481,
},
["hostile"] = {
["b"] = 0.168627455830574,
["g"] = 0.1411764770746231,
["r"] = 0.729411780834198,
},
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
},
},
["kind"] = "reaction",
},
},
["relativeTo"] = 0,
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["anchor"] = {
},
["kind"] = "health",
["background"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyColor"] = false,
["asset"] = "Platy: Solid Black",
},
["scale"] = 1.5,
},
{
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["height"] = 1,
["color"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["asset"] = "Platy: 1px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
["uninterruptable"] = {
["b"] = 0.5294117647058824,
["g"] = 0.5294117647058824,
["r"] = 0.5294117647058824,
},
},
["kind"] = "uninterruptableCast",
},
{
["colors"] = {
["ready"] = {
["r"] = 1,
["g"] = 0.7411764860153198,
["b"] = 0,
},
},
["kind"] = "interruptReady",
},
{
["colors"] = {
["cast"] = {
["r"] = 0.760784387588501,
["g"] = 0.3803921937942505,
["b"] = 1,
},
["channel"] = {
["r"] = 0.760784387588501,
["g"] = 0.3803921937942505,
["b"] = 1,
},
},
["kind"] = "importantCast",
},
{
["colors"] = {
["cast"] = {
["r"] = 0.9058824181556702,
["g"] = 0.4235294461250305,
["b"] = 0.2000000178813934,
},
["empowered"] = {
["r"] = 0.0196078431372549,
["g"] = 0.7764705882352941,
["b"] = 0.4,
},
["interrupted"] = {
["r"] = 1,
["g"] = 0.2039215862751007,
["b"] = 0.1450980454683304,
},
["channel"] = {
["r"] = 0.9058824181556702,
["g"] = 0.4235294461250305,
["b"] = 0.2000000178813934,
},
},
["kind"] = "cast",
},
},
["marker"] = {
["asset"] = "none",
},
["anchor"] = {
"TOP",
0,
-7.5,
},
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["background"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyColor"] = true,
["asset"] = "Platy: Solid Black",
},
["kind"] = "cast",
["interruptMarker"] = {
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["asset"] = "wide/glow",
},
},
},
["markers"] = {
{
["scale"] = 1.34,
["layer"] = 3,
["anchor"] = {
"RIGHT",
114,
0,
},
["kind"] = "quest",
["asset"] = "normal/quest-blizzard",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
{
["openWorldOnly"] = true,
["scale"] = 1,
["layer"] = 3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "elite",
["asset"] = "special/blizzard-elite",
["anchor"] = {
"BOTTOMLEFT",
-116,
9.5,
},
},
{
["scale"] = 0.95,
["layer"] = 3,
["anchor"] = {
"TOPLEFT",
-112,
-11,
},
["kind"] = "cannotInterrupt",
["asset"] = "normal/blizzard-shield",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
},
{
["scale"] = 1.5,
["layer"] = 3,
["anchor"] = {
"BOTTOMRIGHT",
58.5,
5,
},
["kind"] = "raid",
["asset"] = "normal/blizzard-raid",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
},
["texts"] = {
{
["displayTypes"] = {
"percentage",
},
["align"] = "CENTER",
["layer"] = 2,
["maxWidth"] = 0,
["showPercentSymbol"] = true,
["truncate"] = false,
["significantFigures"] = 0,
["anchor"] = {
"BOTTOMRIGHT",
96.5,
12.5,
},
["kind"] = "health",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.1,
},
{
["showWhenWowDoes"] = false,
["truncate"] = true,
["scale"] = 1.2,
["layer"] = 2,
["maxWidth"] = 1.05,
["autoColors"] = {
{
["combatOnly"] = true,
["colors"] = {
["offtank"] = {
["r"] = 0.05882352941176471,
["g"] = 0.6666666666666666,
["b"] = 0.7843137254901961,
},
["warning"] = {
["r"] = 0.8,
["g"] = 0,
["b"] = 0,
},
["safe"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["transition"] = {
["r"] = 1,
["g"] = 0.6274509803921569,
["b"] = 0,
},
},
["useSafeColor"] = false,
["useOffTankColor"] = true,
["kind"] = "threat",
["tanksOnly"] = false,
["instancesOnly"] = true,
},
},
["anchor"] = {
"BOTTOMLEFT",
-93.5,
12.5,
},
["kind"] = "creatureName",
["align"] = "LEFT",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
{
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.2,
["kind"] = "castSpellName",
["truncate"] = true,
["align"] = "LEFT",
["layer"] = 2,
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["maxWidth"] = 0.8,
},
{
["truncate"] = true,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 2,
["maxWidth"] = 0.61,
["align"] = "RIGHT",
["anchor"] = {
"TOPRIGHT",
90,
-15,
},
["kind"] = "castTarget",
["scale"] = 1,
["applyClassColors"] = true,
},
{
["truncate"] = false,
["scale"] = 1,
["layer"] = 2,
["maxWidth"] = 0,
["align"] = "CENTER",
["anchor"] = {
"TOPRIGHT",
57,
-13.5,
},
["kind"] = "castInterrupter",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["applyClassColors"] = true,
},
},
},
["MiliUI (Only Name)"] = {
["highlights"] = {
{
["scale"] = 0.56,
["layer"] = 0,
["asset"] = "Platy: Glow",
["width"] = 1,
["kind"] = "target",
["anchor"] = {
"BOTTOM",
0,
-12,
},
["sliced"] = false,
["color"] = {
["a"] = 1,
["b"] = 0.9294118285179138,
["g"] = 0.8862745761871338,
["r"] = 0.1098039299249649,
},
["height"] = 1,
},
},
["specialBars"] = {
},
["scale"] = 1.1,
["auras"] = {
},
["regions"] = {
["stack"] = {
["anchor"] = {
"BOTTOM",
0,
5.79,
},
["autoSized"] = true,
["height"] = 0.93,
["width"] = 1.14,
},
["click"] = {
["anchor"] = {
"BOTTOM",
0,
7,
},
["autoSized"] = true,
["height"] = 0.77,
["width"] = 1.04,
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "RobotoCondensed-Bold",
["slug"] = true,
},
["version"] = 10,
["bars"] = {
},
["markers"] = {
{
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "quest",
["anchor"] = {
"BOTTOMLEFT",
-82,
0,
},
["layer"] = 3,
["asset"] = "normal/quest-boss-blizzard",
["scale"] = 0.9,
},
{
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "raid",
["anchor"] = {
"BOTTOM",
0,
32,
},
["layer"] = 3,
["asset"] = "normal/blizzard-raid",
["scale"] = 1.45,
},
},
["texts"] = {
{
["showWhenWowDoes"] = true,
["truncate"] = false,
["color"] = {
["b"] = 0.9686275124549866,
["g"] = 0.9686275124549866,
["r"] = 0.9686275124549866,
},
["layer"] = 2,
["maxWidth"] = 1.04,
["autoColors"] = {
{
["colors"] = {
},
["kind"] = "classColors",
},
{
["colors"] = {
["tapped"] = {
["b"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["r"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["colors"] = {
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
},
["neutral"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["hostile"] = {
["r"] = 1,
["g"] = 0,
["b"] = 0,
},
["friendly"] = {
["r"] = 0,
["g"] = 1,
["b"] = 0,
},
},
["kind"] = "reaction",
},
},
["anchor"] = {
"BOTTOM",
0,
7,
},
["kind"] = "creatureName",
["align"] = "CENTER",
["scale"] = 1.1,
},
{
["showWhenWowDoes"] = true,
["playerGuild"] = true,
["align"] = "CENTER",
["layer"] = 2,
["maxWidth"] = 0.99,
["npcRole"] = true,
["scale"] = 0.9,
["anchor"] = {
"BOTTOM",
0,
-4,
},
["kind"] = "guild",
["color"] = {
["a"] = 1,
["b"] = 0.6313725709915161,
["g"] = 0.6313725709915161,
["r"] = 0.6313725709915161,
},
["truncate"] = true,
},
},
},
["Luxthos (Simplified)"] = {
["highlights"] = {
{
["scale"] = 1,
["layer"] = 2,
["asset"] = "Platy: Striped Reverse",
["width"] = 1.48,
["kind"] = "focus",
["height"] = 0.5,
["sliced"] = false,
["color"] = {
["a"] = 0.3776039183139801,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"TOPLEFT",
-93,
1.5,
},
},
{
["scale"] = 1.52,
["layer"] = 2,
["asset"] = "Platy: 1px",
["width"] = 1,
["color"] = {
["a"] = 0.6119787096977234,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "mouseover",
["height"] = 0.5,
["sliced"] = true,
["anchor"] = {
"TOP",
0,
3.5,
},
["includeTarget"] = true,
},
{
["scale"] = 1.52,
["layer"] = 2,
["asset"] = "Platy: 1px",
["width"] = 1,
["kind"] = "target",
["anchor"] = {
"TOP",
0,
3.5,
},
["sliced"] = true,
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["height"] = 0.5,
},
},
["specialBars"] = {
},
["scale"] = 1.1,
["auras"] = {
{
["height"] = 1,
["direction"] = "RIGHT",
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.82,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.64,
},
},
["showSwipe"] = true,
["scale"] = 1.6,
["layer"] = 1,
["textScale"] = 1,
["showType"] = false,
["showTooltips"] = true,
["filters"] = {
["important"] = true,
["fromYou"] = true,
},
["limit"] = 30,
["showPandemic"] = true,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["kind"] = "debuffs",
["showCountdown"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
},
{
["height"] = 1,
["direction"] = "LEFT",
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.17,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.92,
},
},
["showCountdown"] = true,
["scale"] = 1,
["layer"] = 1,
["textScale"] = 1,
["showSwipe"] = true,
["showTooltips"] = true,
["filters"] = {
["dispelable"] = true,
["important"] = true,
["defensive"] = false,
},
["limit"] = 30,
["showType"] = true,
["anchor"] = {
"BOTTOMLEFT",
-118.5,
-9,
},
["kind"] = "buffs",
["showStealable"] = false,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
},
{
["direction"] = "RIGHT",
["filters"] = {
["fromYou"] = false,
},
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.82,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.64,
},
},
["scale"] = 1.7,
["layer"] = 1,
["textScale"] = 1,
["showSwipe"] = true,
["showTooltips"] = true,
["anchor"] = {
"RIGHT",
154,
0,
},
["limit"] = 30,
["showType"] = false,
["height"] = 1,
["kind"] = "crowdControl",
["showCountdown"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
},
},
["regions"] = {
["stack"] = {
["anchor"] = {
"TOPLEFT",
-103.91,
26.02,
},
["autoSized"] = true,
["height"] = 4.01,
["width"] = 1.66,
},
["click"] = {
["anchor"] = {
"TOPLEFT",
-94.5,
20.8,
},
["autoSized"] = true,
["height"] = 3.34,
["width"] = 1.51,
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
["slug"] = true,
},
["version"] = 10,
["bars"] = {
{
["relativeTo"] = 0,
["animate"] = false,
["marker"] = {
["asset"] = "none",
},
["layer"] = 1,
["border"] = {
["color"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["height"] = 0.5,
["asset"] = "Platy: 1px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
},
["kind"] = "classColors",
},
{
["colors"] = {
["tapped"] = {
["b"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["r"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["enabled"] = {
["boss"] = true,
["melee"] = true,
["caster"] = true,
["trivial"] = true,
["miniboss"] = true,
},
["colors"] = {
["boss"] = {
["b"] = 0,
["g"] = 0.1098039215686275,
["r"] = 0.7372549019607844,
},
["melee"] = {
["b"] = 0.3686274588108063,
["g"] = 0.6196078658103943,
["r"] = 0.7803922295570374,
},
["caster"] = {
["r"] = 0,
["g"] = 0.6431372761726379,
["b"] = 1,
},
["trivial"] = {
["b"] = 0.3254902064800263,
["g"] = 0.4039216041564941,
["r"] = 0.4705882668495178,
},
["miniboss"] = {
["b"] = 0.7372549019607844,
["g"] = 0,
["r"] = 0.5647058823529412,
},
},
["kind"] = "eliteType",
["applyCasterAlways"] = false,
["instancesOnly"] = true,
},
{
["combatOnly"] = true,
["colors"] = {
["offtank"] = {
["b"] = 0.7843137979507446,
["g"] = 0.6666666865348816,
["r"] = 0.05882353335618973,
},
["warning"] = {
["b"] = 0.1764705926179886,
["g"] = 0.1450980454683304,
["r"] = 0.7568628191947937,
},
["safe"] = {
["b"] = 0.9019608497619628,
["g"] = 0.5882353186607361,
["r"] = 0.05882353335618973,
},
["transition"] = {
["b"] = 0,
["g"] = 0.6274510025978088,
["r"] = 1,
},
},
["instancesOnly"] = false,
["useOffTankColor"] = true,
["kind"] = "threat",
["tanksOnly"] = false,
["useSafeColor"] = true,
},
{
["colors"] = {
["neutral"] = {
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
},
["friendly"] = {
["b"] = 0.3372549116611481,
["g"] = 0.8862745761871338,
["r"] = 0.2745098173618317,
},
["hostile"] = {
["b"] = 0.1764705926179886,
["g"] = 0.1450980454683304,
["r"] = 0.7568628191947937,
},
["unfriendly"] = {
["r"] = 1,
["g"] = 0.5058823529411764,
["b"] = 0,
},
},
["kind"] = "reaction",
},
},
["scale"] = 1.5,
["background"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["applyColor"] = false,
["asset"] = "Platy: Solid Black",
},
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["kind"] = "health",
["anchor"] = {
"TOP",
0,
3.5,
},
["absorb"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["asset"] = "Platy: Absorb Wide",
},
},
{
["marker"] = {
["asset"] = "none",
},
["layer"] = 1,
["border"] = {
["color"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["height"] = 1,
["asset"] = "Platy: 1px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
["uninterruptable"] = {
["r"] = 0.5294117647058824,
["g"] = 0.5294117647058824,
["b"] = 0.5294117647058824,
},
},
["kind"] = "uninterruptableCast",
},
{
["colors"] = {
["ready"] = {
["b"] = 0,
["g"] = 0.7411764860153198,
["r"] = 1,
},
},
["kind"] = "interruptReady",
},
{
["colors"] = {
["cast"] = {
["b"] = 1,
["g"] = 0.3803921937942505,
["r"] = 0.760784387588501,
},
["channel"] = {
["b"] = 1,
["g"] = 0.3803921937942505,
["r"] = 0.760784387588501,
},
},
["kind"] = "importantCast",
},
{
["colors"] = {
["cast"] = {
["b"] = 0.2000000178813934,
["g"] = 0.4235294461250305,
["r"] = 0.9058824181556702,
},
["empowered"] = {
["r"] = 0.0196078431372549,
["g"] = 0.7764705882352941,
["b"] = 0.4,
},
["interrupted"] = {
["b"] = 0.1450980454683304,
["g"] = 0.2039215862751007,
["r"] = 1,
},
["channel"] = {
["b"] = 0.2000000178813934,
["g"] = 0.4235294461250305,
["r"] = 0.9058824181556702,
},
},
["kind"] = "cast",
},
},
["scale"] = 1.5,
["kind"] = "cast",
["anchor"] = {
"TOP",
0,
-8,
},
["background"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["applyColor"] = true,
["asset"] = "Platy: Solid Black",
},
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["interruptMarker"] = {
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["asset"] = "wide/glow",
},
},
},
["markers"] = {
{
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "quest",
["scale"] = 1.34,
["layer"] = 3,
["asset"] = "normal/quest-blizzard",
["anchor"] = {
"RIGHT",
114,
0,
},
},
{
["openWorldOnly"] = true,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "elite",
["scale"] = 1,
["layer"] = 3,
["asset"] = "special/blizzard-elite",
["anchor"] = {
"BOTTOMLEFT",
-116,
9.5,
},
},
{
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "cannotInterrupt",
["scale"] = 0.95,
["layer"] = 3,
["asset"] = "normal/blizzard-shield",
["anchor"] = {
"TOPLEFT",
-112,
-11,
},
},
{
["anchor"] = {
"BOTTOMRIGHT",
57,
-1,
},
["layer"] = 3,
["scale"] = 1.5,
["kind"] = "raid",
["asset"] = "normal/blizzard-raid",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
},
["texts"] = {
{
["showWhenWowDoes"] = false,
["truncate"] = true,
["align"] = "LEFT",
["layer"] = 2,
["maxWidth"] = 1.05,
["autoColors"] = {
{
["combatOnly"] = true,
["colors"] = {
["offtank"] = {
["b"] = 0.7843137254901961,
["g"] = 0.6666666666666666,
["r"] = 0.05882352941176471,
},
["warning"] = {
["b"] = 0,
["g"] = 0,
["r"] = 0.8,
},
["safe"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["transition"] = {
["b"] = 0,
["g"] = 0.6274509803921569,
["r"] = 1,
},
},
["instancesOnly"] = true,
["useOffTankColor"] = true,
["kind"] = "threat",
["tanksOnly"] = false,
["useSafeColor"] = false,
},
},
["anchor"] = {
"BOTTOMLEFT",
-94.5,
6.5,
},
["kind"] = "creatureName",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["scale"] = 1.3,
},
{
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["align"] = "LEFT",
["kind"] = "castSpellName",
["truncate"] = true,
["scale"] = 1.2,
["layer"] = 2,
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["maxWidth"] = 0.8,
},
{
["truncate"] = true,
["align"] = "RIGHT",
["layer"] = 2,
["maxWidth"] = 0.61,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"TOPRIGHT",
90,
-15,
},
["kind"] = "castTarget",
["scale"] = 1,
["applyClassColors"] = true,
},
},
},
["_custom"] = {
["highlights"] = {
},
["specialBars"] = {
},
["scale"] = 1,
["auras"] = {
{
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["direction"] = "RIGHT",
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.17,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.92,
},
},
["showSwipe"] = true,
["scale"] = 1.35,
["layer"] = 1,
["textScale"] = 1,
["showPandemic"] = true,
["showTooltips"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["limit"] = 30,
["showType"] = false,
["height"] = 1,
["kind"] = "debuffs",
["showCountdown"] = true,
["filters"] = {
["fromYou"] = true,
["important"] = true,
},
},
{
["height"] = 1,
["direction"] = "LEFT",
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.17,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.92,
},
},
["showCountdown"] = true,
["scale"] = 1,
["layer"] = 1,
["textScale"] = 1,
["showSwipe"] = true,
["showTooltips"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["limit"] = 30,
["showType"] = true,
["anchor"] = {
"LEFT",
-117,
0,
},
["kind"] = "buffs",
["showStealable"] = false,
["filters"] = {
["dispelable"] = true,
["important"] = true,
["defensive"] = false,
},
},
{
["direction"] = "RIGHT",
["showType"] = false,
["texts"] = {
["countdown"] = {
["anchor"] = {
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.17,
},
["stacks"] = {
["anchor"] = {
"TOPRIGHT",
12,
-1,
},
["visible"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 0.92,
},
},
["scale"] = 1,
["layer"] = 1,
["textScale"] = 1,
["showSwipe"] = true,
["showTooltips"] = true,
["height"] = 1,
["limit"] = 30,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["anchor"] = {
"RIGHT",
138,
0,
},
["kind"] = "crowdControl",
["showCountdown"] = true,
["filters"] = {
["fromYou"] = false,
},
},
},
["regions"] = {
["stack"] = {
["anchor"] = {
"TOP",
0,
32.07,
},
["autoSized"] = true,
["height"] = 4.43,
["width"] = 1.65,
},
["click"] = {
["anchor"] = {
"TOP",
0,
26.3,
},
["autoSized"] = true,
["height"] = 3.7,
["width"] = 1.5,
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
["slug"] = true,
},
["version"] = 10,
["bars"] = {
{
["absorb"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["asset"] = "Platy: Absorb Wide",
},
["animate"] = false,
["marker"] = {
["asset"] = "wide/glow",
},
["layer"] = 1,
["border"] = {
["height"] = 0.75,
["color"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["asset"] = "Platy: 2px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
},
["kind"] = "classColors",
},
{
["colors"] = {
["tapped"] = {
["r"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["b"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["combatOnly"] = false,
["colors"] = {
["offtank"] = {
["r"] = 0.05882353335618973,
["g"] = 0.6666666865348816,
["b"] = 0.7843137979507446,
},
["warning"] = {
["r"] = 0.7568628191947937,
["g"] = 0.1450980454683304,
["b"] = 0.1764705926179886,
},
["safe"] = {
["r"] = 0.05882353335618973,
["g"] = 0.5882353186607361,
["b"] = 0.9019608497619628,
},
["transition"] = {
["r"] = 1,
["g"] = 0.6274510025978088,
["b"] = 0,
},
},
["useSafeColor"] = true,
["useOffTankColor"] = true,
["kind"] = "threat",
["tanksOnly"] = false,
["instancesOnly"] = false,
},
{
["colors"] = {
["neutral"] = {
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
},
["friendly"] = {
["r"] = 0.2745098173618317,
["g"] = 0.8862745761871338,
["b"] = 0.3372549116611481,
},
["hostile"] = {
["r"] = 0.8352941870689392,
["g"] = 0,
["b"] = 0,
},
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
},
},
["kind"] = "reaction",
},
},
["relativeTo"] = 0,
["anchor"] = {
},
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["background"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyColor"] = false,
["asset"] = "Platy: Solid Black",
},
["kind"] = "health",
["scale"] = 1.5,
},
{
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["height"] = 1,
["color"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["asset"] = "Platy: 2px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
["cast"] = {
["b"] = 0.1529411764705883,
["g"] = 0.09411764705882351,
["r"] = 1,
},
["channel"] = {
["b"] = 1,
["g"] = 0.2627450980392157,
["r"] = 0.0392156862745098,
},
},
["kind"] = "importantCast",
},
{
["colors"] = {
["uninterruptable"] = {
["b"] = 0.5294117647058824,
["g"] = 0.5294117647058824,
["r"] = 0.5294117647058824,
},
},
["kind"] = "uninterruptableCast",
},
{
["colors"] = {
["cast"] = {
["b"] = 0,
["g"] = 0.7411764705882353,
["r"] = 1,
},
["empowered"] = {
["r"] = 0.0196078431372549,
["g"] = 0.7764705882352941,
["b"] = 0.4,
},
["interrupted"] = {
["b"] = 0.8784313725490196,
["g"] = 0.211764705882353,
["r"] = 0.9882352941176472,
},
["channel"] = {
["b"] = 0.2156862745098039,
["g"] = 0.7764705882352941,
["r"] = 0.2431372549019608,
},
},
["kind"] = "cast",
},
},
["marker"] = {
["asset"] = "wide/glow",
},
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["anchor"] = {
"TOP",
0,
-8,
},
["kind"] = "cast",
["background"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyColor"] = true,
["asset"] = "Platy: Solid Black",
},
["interruptMarker"] = {
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["asset"] = "wide/glow",
},
},
},
["markers"] = {
{
["anchor"] = {
"RIGHT",
114,
0,
},
["layer"] = 3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "quest",
["asset"] = "normal/quest-blizzard",
["scale"] = 1.34,
},
{
["openWorldOnly"] = false,
["scale"] = 0.9,
["layer"] = 3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "elite",
["asset"] = "special/blizzard-elite",
["anchor"] = {
"BOTTOMLEFT",
-113,
11,
},
},
{
["anchor"] = {
"TOPLEFT",
-112,
-11,
},
["layer"] = 3,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "cannotInterrupt",
["asset"] = "normal/blizzard-shield",
["scale"] = 0.95,
},
{
["anchor"] = {
"BOTTOMRIGHT",
98,
32,
},
["layer"] = 3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "raid",
["asset"] = "normal/blizzard-raid",
["scale"] = 1,
},
},
["texts"] = {
{
["truncate"] = false,
["align"] = "CENTER",
["layer"] = 2,
["formatMultiple"] = "%s (%s)",
["maxWidth"] = 0,
["significantFigures"] = 0,
["displayTypes"] = {
"percentage",
},
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"BOTTOMRIGHT",
95,
11,
},
["kind"] = "health",
["scale"] = 1.1,
["showPercentSymbol"] = true,
},
{
["showWhenWowDoes"] = false,
["truncate"] = true,
["align"] = "LEFT",
["layer"] = 2,
["maxWidth"] = 1.09,
["autoColors"] = {
},
["anchor"] = {
"BOTTOMLEFT",
-93,
12,
},
["kind"] = "creatureName",
["scale"] = 1.3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
{
["align"] = "CENTER",
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["layer"] = 2,
["truncate"] = false,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "castSpellName",
["scale"] = 1.2,
["maxWidth"] = 0,
},
},
},
},
["global_scale"] = 0.99,
["target_behaviour"] = "enlarge",
["style"] = "MiliUI (Only Name)",
["click_region_scale_y"] = 2.3,
["out_of_range_alpha"] = 1,
["clickable_nameplates"] = {
["friend"] = false,
["enemy"] = true,
},
["simplified_scale"] = 0.9,
["show_nameplates"] = {
["friendlyMinion"] = false,
["friendlyMinionTotem"] = true,
["enemyMinionGuardian"] = true,
["friendlyNPC"] = false,
["enemyMinionTotem"] = true,
["friendlyMinionPet"] = true,
["enemyMinionPet"] = true,
["friendlyMinionGuardian"] = true,
["friendlyPlayer"] = true,
["enemyMinor"] = true,
["enemyMinion"] = true,
["enemy"] = true,
},
}

MiliUI_PlatynatorProfile.kind = "profile"
MiliUI_PlatynatorProfile.addon = "Platynator"
MiliUI_PlatynatorVersion = 20260608

-- 內建版本較新時，是否「強制覆蓋」用戶現有的 MiliUI profile：
--   true  ：登入時若 MiliUI_PlatynatorVersion 比存檔記錄新，強制重新匯入最新預設值（會覆蓋用戶自訂）
--   false ：僅新角色 / 尚無 MiliUI profile 時才匯入，不強制覆蓋（預設）
MiliUI_PlatynatorForceUpdate = false
