MiliUI_PlatynatorProfile = {
["stack_region_scale_y"] = 1.4,
["design_all"] = {
},
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
["mouseover_alpha"] = 1,
["closer_to_screen_edges"] = true,
["cast_scale"] = 1,
["closer_nameplates"] = true,
["designs_assigned"] = {
["enemySimplifiedCombat"] = "_hare_simplified",
["enemyPvPPlayer"] = "_deer",
["enemyCombat"] = "_deer",
["friendCombat"] = "_name-only",
["friendPvPPlayer"] = "_name-only",
["friend"] = "MiliUI (Only Name)",
["enemySimplified"] = "Luxthos (Simplified)",
["enemy"] = "Luxthos",
},
["designs_enabled"] = {
["pvpInstance"] = false,
["combat"] = false,
["pvpWorld"] = false,
},
["simplified_scale"] = 0.9,
["addon"] = "Platynator",
["apply_cvars"] = true,
["current_skin"] = "blizzard",
["designs"] = {
["MiliUI (Only Name)"] = {
["highlights"] = {
{
["scale"] = 0.56,
["layer"] = 0,
["asset"] = "Platy: Glow",
["width"] = 1,
["height"] = 1,
["anchor"] = {
"BOTTOM",
0,
-12,
},
["kind"] = "target",
["color"] = {
["a"] = 1,
["r"] = 0.1098039299249649,
["g"] = 0.8862745761871338,
["b"] = 0.9294118285179138,
},
["sliced"] = false,
},
},
["specialBars"] = {
},
["scale"] = 1.1,
["auras"] = {
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "RobotoCondensed-Bold",
["slug"] = true,
},
["version"] = 1,
["bars"] = {
},
["markers"] = {
{
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 3,
["anchor"] = {
"BOTTOMLEFT",
-82,
0,
},
["kind"] = "quest",
["asset"] = "normal/quest-boss-blizzard",
["scale"] = 0.9,
},
{
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 3,
["anchor"] = {
"BOTTOM",
0,
32,
},
["kind"] = "raid",
["asset"] = "normal/blizzard-raid",
["scale"] = 1.45,
},
},
["texts"] = {
{
["showWhenWowDoes"] = true,
["truncate"] = false,
["color"] = {
["r"] = 0.9686275124549866,
["g"] = 0.9686275124549866,
["b"] = 0.9686275124549866,
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
["r"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["b"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["colors"] = {
["neutral"] = {
["b"] = 0,
["g"] = 1,
["r"] = 1,
},
["friendly"] = {
["b"] = 0,
["g"] = 1,
["r"] = 0,
},
["hostile"] = {
["b"] = 0,
["g"] = 0,
["r"] = 1,
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
["anchor"] = {
"BOTTOM",
0,
7,
},
["kind"] = "creatureName",
["scale"] = 1.1,
["align"] = "CENTER",
},
{
["showWhenWowDoes"] = true,
["playerGuild"] = true,
["scale"] = 0.9,
["layer"] = 2,
["maxWidth"] = 0.99,
["npcRole"] = true,
["truncate"] = true,
["anchor"] = {
"BOTTOM",
0,
-4,
},
["kind"] = "guild",
["color"] = {
["a"] = 1,
["r"] = 0.6313725709915161,
["g"] = 0.6313725709915161,
["b"] = 0.6313725709915161,
},
["align"] = "CENTER",
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
["direction"] = "RIGHT",
["scale"] = 1.35,
["showCountdown"] = true,
["filters"] = {
["important"] = true,
["fromYou"] = true,
},
["showPandemic"] = true,
["kind"] = "debuffs",
["height"] = 1,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["showDispel"] = {
},
["textScale"] = 1,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
},
{
["direction"] = "LEFT",
["scale"] = 1,
["showCountdown"] = true,
["filters"] = {
["dispelable"] = true,
["important"] = true,
["defensive"] = false,
},
["textScale"] = 1,
["kind"] = "buffs",
["anchor"] = {
"LEFT",
-117,
0,
},
["showDispel"] = {
["enrage"] = true,
},
["height"] = 1,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
},
{
["direction"] = "RIGHT",
["scale"] = 1,
["showCountdown"] = true,
["filters"] = {
["fromYou"] = false,
},
["textScale"] = 1,
["kind"] = "crowdControl",
["anchor"] = {
"RIGHT",
138,
0,
},
["showDispel"] = {
},
["height"] = 1,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
["slug"] = true,
},
["version"] = 1,
["bars"] = {
{
["relativeTo"] = 0,
["animate"] = false,
["marker"] = {
["asset"] = "wide/glow",
},
["layer"] = 1,
["border"] = {
["color"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["height"] = 0.75,
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
["b"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["r"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["combatOnly"] = false,
["colors"] = {
["transition"] = {
["b"] = 0,
["g"] = 0.6274510025978088,
["r"] = 1,
},
["warning"] = {
["b"] = 0.1764705926179886,
["g"] = 0.1450980454683304,
["r"] = 0.7568628191947937,
},
["offtank"] = {
["b"] = 0.7843137979507446,
["g"] = 0.6666666865348816,
["r"] = 0.05882353335618973,
},
["safe"] = {
["b"] = 0.9019608497619628,
["g"] = 0.5882353186607361,
["r"] = 0.05882353335618973,
},
},
["kind"] = "threat",
["instancesOnly"] = false,
["useSafeColor"] = true,
},
{
["colors"] = {
["neutral"] = {
["b"] = 0.3176470696926117,
["g"] = 0.7176470756530762,
["r"] = 0.8588235974311829,
},
["unfriendly"] = {
["r"] = 1,
["g"] = 0.5058823529411764,
["b"] = 0,
},
["friendly"] = {
["b"] = 0.3372549116611481,
["g"] = 0.8862745761871338,
["r"] = 0.2745098173618317,
},
["hostile"] = {
["b"] = 0,
["g"] = 0,
["r"] = 0.8352941870689392,
},
},
["kind"] = "reaction",
},
},
["scale"] = 1.5,
["kind"] = "health",
["anchor"] = {
},
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
["asset"] = "wide/glow",
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
["asset"] = "Platy: 2px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
["cast"] = {
["r"] = 1,
["g"] = 0.09411764705882351,
["b"] = 0.1529411764705883,
},
["channel"] = {
["r"] = 0.0392156862745098,
["g"] = 0.2627450980392157,
["b"] = 1,
},
},
["kind"] = "importantCast",
},
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
["cast"] = {
["r"] = 1,
["g"] = 0.7411764705882353,
["b"] = 0,
},
["interrupted"] = {
["r"] = 0.9882352941176472,
["g"] = 0.211764705882353,
["b"] = 0.8784313725490196,
},
["channel"] = {
["r"] = 0.2431372549019608,
["g"] = 0.7764705882352941,
["b"] = 0.2156862745098039,
},
},
["kind"] = "cast",
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
["applyColor"] = true,
["asset"] = "Platy: Solid Black",
},
["foreground"] = {
["asset"] = "Platy: Solid White",
},
["kind"] = "cast",
["anchor"] = {
"TOP",
0,
-8,
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
["anchor"] = {
"RIGHT",
114,
0,
},
["kind"] = "quest",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 3,
["asset"] = "normal/quest-blizzard",
["scale"] = 1.34,
},
{
["openWorldOnly"] = false,
["anchor"] = {
"BOTTOMLEFT",
-113,
11,
},
["kind"] = "elite",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 3,
["asset"] = "special/blizzard-elite",
["scale"] = 0.9,
},
{
["anchor"] = {
"TOPLEFT",
-112,
-11,
},
["kind"] = "cannotInterrupt",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 3,
["asset"] = "normal/blizzard-shield",
["scale"] = 0.95,
},
{
["anchor"] = {
"BOTTOMRIGHT",
98,
32,
},
["kind"] = "raid",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 3,
["asset"] = "normal/blizzard-raid",
["scale"] = 1,
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
["significantFigures"] = 0,
["scale"] = 1.1,
["anchor"] = {
"BOTTOMRIGHT",
95,
11,
},
["kind"] = "health",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["truncate"] = false,
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
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["scale"] = 1.3,
},
{
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["scale"] = 1.2,
["kind"] = "castSpellName",
["truncate"] = false,
["align"] = "CENTER",
["layer"] = 2,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["maxWidth"] = 0,
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
["anchor"] = {
"TOPLEFT",
-93,
1.5,
},
["height"] = 0.5,
["kind"] = "focus",
["color"] = {
["a"] = 0.3776039183139801,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["sliced"] = false,
},
{
["scale"] = 1.52,
["layer"] = 2,
["asset"] = "Platy: 1px",
["width"] = 1,
["color"] = {
["a"] = 0.6119787096977234,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"TOP",
0,
3.5,
},
["height"] = 0.5,
["kind"] = "mouseover",
["sliced"] = true,
["includeTarget"] = true,
},
{
["scale"] = 1.52,
["layer"] = 2,
["asset"] = "Platy: 1px",
["width"] = 1,
["height"] = 0.5,
["anchor"] = {
"TOP",
0,
3.5,
},
["kind"] = "target",
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["sliced"] = true,
},
},
["specialBars"] = {
},
["scale"] = 1.1,
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.6,
["showCountdown"] = true,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
["textScale"] = 0.7,
["showDispel"] = {
},
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["height"] = 1,
["kind"] = "debuffs",
["showPandemic"] = true,
["filters"] = {
["fromYou"] = true,
["important"] = true,
},
},
{
["direction"] = "LEFT",
["scale"] = 1,
["showCountdown"] = true,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
["anchor"] = {
"BOTTOMLEFT",
-118.5,
-9,
},
["showDispel"] = {
["enrage"] = true,
},
["height"] = 1,
["kind"] = "buffs",
["textScale"] = 1,
["filters"] = {
["dispelable"] = true,
["important"] = true,
["defensive"] = false,
},
},
{
["direction"] = "RIGHT",
["scale"] = 1.7,
["showCountdown"] = true,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
["anchor"] = {
"RIGHT",
154,
0,
},
["showDispel"] = {
},
["height"] = 1,
["kind"] = "crowdControl",
["textScale"] = 0.7,
["filters"] = {
["fromYou"] = false,
},
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
["slug"] = true,
},
["version"] = 1,
["bars"] = {
{
["relativeTo"] = 0,
["animate"] = false,
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["height"] = 0.5,
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
["kind"] = "eliteType",
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
["instancesOnly"] = true,
},
{
["combatOnly"] = true,
["colors"] = {
["transition"] = {
["r"] = 1,
["g"] = 0.6274510025978088,
["b"] = 0,
},
["warning"] = {
["r"] = 0.7568628191947937,
["g"] = 0.1450980454683304,
["b"] = 0.1764705926179886,
},
["offtank"] = {
["r"] = 0.05882353335618973,
["g"] = 0.6666666865348816,
["b"] = 0.7843137979507446,
},
["safe"] = {
["r"] = 0.05882353335618973,
["g"] = 0.5882353186607361,
["b"] = 0.9019608497619628,
},
},
["kind"] = "threat",
["useSafeColor"] = true,
["instancesOnly"] = false,
},
{
["colors"] = {
["neutral"] = {
["b"] = 0.3176470696926117,
["g"] = 0.7176470756530762,
["r"] = 0.8588235974311829,
},
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
},
["friendly"] = {
["r"] = 0.2745098173618317,
["g"] = 0.8862745761871338,
["b"] = 0.3372549116611481,
},
["hostile"] = {
["r"] = 0.7568628191947937,
["g"] = 0.1450980454683304,
["b"] = 0.1764705926179886,
},
},
["kind"] = "reaction",
},
},
["absorb"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["asset"] = "Platy: Absorb Wide",
},
["anchor"] = {
"TOP",
0,
3.5,
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
["marker"] = {
["asset"] = "none",
},
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
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 3,
["scale"] = 1.34,
["kind"] = "quest",
["asset"] = "normal/quest-blizzard",
["anchor"] = {
"RIGHT",
114,
0,
},
},
{
["openWorldOnly"] = true,
["anchor"] = {
"BOTTOMLEFT",
-116,
9.5,
},
["layer"] = 3,
["scale"] = 1,
["kind"] = "elite",
["asset"] = "special/blizzard-elite",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
{
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 3,
["scale"] = 0.95,
["kind"] = "cannotInterrupt",
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
["kind"] = "raid",
["scale"] = 1.5,
["layer"] = 3,
["asset"] = "normal/blizzard-raid",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
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
["transition"] = {
["r"] = 1,
["g"] = 0.6274509803921569,
["b"] = 0,
},
["warning"] = {
["r"] = 0.8,
["g"] = 0,
["b"] = 0,
},
["offtank"] = {
["r"] = 0.05882352941176471,
["g"] = 0.6666666666666666,
["b"] = 0.7843137254901961,
},
["safe"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
},
["kind"] = "threat",
["useSafeColor"] = false,
["instancesOnly"] = true,
},
},
["anchor"] = {
"BOTTOMLEFT",
-94.5,
6.5,
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
["align"] = "LEFT",
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["layer"] = 2,
["truncate"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "castSpellName",
["scale"] = 1.2,
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
},
},
["Luxthos"] = {
["highlights"] = {
{
["color"] = {
["a"] = 0.3776039183139801,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 2,
["asset"] = "Platy: Striped Reverse",
["width"] = 1.48,
["scale"] = 1,
["height"] = 0.98,
["kind"] = "focus",
["anchor"] = {
"LEFT",
-93,
0,
},
["sliced"] = false,
},
{
["color"] = {
["a"] = 0.6119787096977234,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 2,
["asset"] = "Platy: 1px",
["width"] = 1,
["scale"] = 1.52,
["anchor"] = {
},
["height"] = 0.8,
["kind"] = "mouseover",
["sliced"] = true,
["includeTarget"] = true,
},
{
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 0,
["asset"] = "Platy: 1px",
["width"] = 1,
["height"] = 0.82,
["anchor"] = {
},
["kind"] = "target",
["scale"] = 1.51,
["sliced"] = true,
},
{
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 1,
["asset"] = "Platy: Arrow Double",
["width"] = 2,
["scale"] = 1,
["anchor"] = {
},
["kind"] = "target",
["height"] = 1.25,
["sliced"] = true,
},
},
["specialBars"] = {
},
["scale"] = 1.05,
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.4,
["showCountdown"] = true,
["filters"] = {
["important"] = true,
["fromYou"] = true,
},
["showPandemic"] = true,
["showDispel"] = {
},
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["height"] = 1,
["kind"] = "debuffs",
["textScale"] = 0.6,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
},
{
["direction"] = "LEFT",
["scale"] = 1,
["showCountdown"] = true,
["filters"] = {
["dispelable"] = true,
["important"] = true,
["defensive"] = false,
},
["textScale"] = 1,
["showDispel"] = {
["enrage"] = true,
},
["anchor"] = {
"BOTTOMLEFT",
-118.5,
-9,
},
["kind"] = "buffs",
["height"] = 1,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
},
{
["direction"] = "RIGHT",
["scale"] = 1.7,
["showCountdown"] = true,
["filters"] = {
["fromYou"] = false,
},
["textScale"] = 0.7,
["showDispel"] = {
},
["anchor"] = {
"RIGHT",
154,
0,
},
["kind"] = "crowdControl",
["height"] = 1,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
["slug"] = true,
},
["version"] = 1,
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
["height"] = 0.75,
["asset"] = "Platy: 1px",
["width"] = 1,
},
["autoColors"] = {
{
["colors"] = {
["neutral"] = {
["r"] = 1,
["g"] = 0.5882353186607361,
["b"] = 0.1607843190431595,
},
["hostile"] = {
["r"] = 1,
["g"] = 0.5882353186607361,
["b"] = 0.1607843190431595,
},
["friendly"] = {
["r"] = 1,
["g"] = 0.5882353186607361,
["b"] = 0.1607843190431595,
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
["b"] = 0.4313725490196079,
["g"] = 0.4313725490196079,
["r"] = 0.4313725490196079,
},
},
["kind"] = "tapped",
},
{
["kind"] = "eliteType",
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
["instancesOnly"] = true,
},
{
["combatOnly"] = true,
["colors"] = {
["warning"] = {
["r"] = 0.729411780834198,
["g"] = 0.1411764770746231,
["b"] = 0.168627455830574,
},
["transition"] = {
["b"] = 0,
["g"] = 0.6274510025978088,
["r"] = 1,
},
["offtank"] = {
["b"] = 0.7843137979507446,
["g"] = 0.6666666865348816,
["r"] = 0.05882353335618973,
},
["safe"] = {
["b"] = 0.9019608497619628,
["g"] = 0.5882353186607361,
["r"] = 0.05882353335618973,
},
},
["kind"] = "threat",
["instancesOnly"] = true,
["useSafeColor"] = false,
},
{
["colors"] = {
["neutral"] = {
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
},
["unfriendly"] = {
["r"] = 1,
["g"] = 0.5058823529411764,
["b"] = 0,
},
["friendly"] = {
["b"] = 0.3372549116611481,
["g"] = 0.8862745761871338,
["r"] = 0.2745098173618317,
},
["hostile"] = {
["r"] = 0.729411780834198,
["g"] = 0.1411764770746231,
["b"] = 0.168627455830574,
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
-7.5,
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
["scale"] = 1.34,
["kind"] = "quest",
["anchor"] = {
"RIGHT",
114,
0,
},
["layer"] = 3,
["asset"] = "normal/quest-blizzard",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
},
{
["openWorldOnly"] = true,
["anchor"] = {
"BOTTOMLEFT",
-116,
9.5,
},
["kind"] = "elite",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 3,
["asset"] = "special/blizzard-elite",
["scale"] = 1,
},
{
["scale"] = 0.95,
["kind"] = "cannotInterrupt",
["anchor"] = {
"TOPLEFT",
-112,
-11,
},
["layer"] = 3,
["asset"] = "normal/blizzard-shield",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
{
["scale"] = 1.5,
["kind"] = "raid",
["anchor"] = {
"BOTTOMRIGHT",
58.5,
5,
},
["layer"] = 3,
["asset"] = "normal/blizzard-raid",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
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
["significantFigures"] = 0,
["scale"] = 1.1,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["anchor"] = {
"BOTTOMRIGHT",
96.5,
12.5,
},
["kind"] = "health",
["truncate"] = false,
["showPercentSymbol"] = true,
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
["transition"] = {
["b"] = 0,
["g"] = 0.6274509803921569,
["r"] = 1,
},
["warning"] = {
["b"] = 0,
["g"] = 0,
["r"] = 0.8,
},
["offtank"] = {
["b"] = 0.7843137254901961,
["g"] = 0.6666666666666666,
["r"] = 0.05882352941176471,
},
["safe"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
},
["kind"] = "threat",
["instancesOnly"] = true,
["useSafeColor"] = false,
},
},
["anchor"] = {
"BOTTOMLEFT",
-93.5,
12.5,
},
["kind"] = "creatureName",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["align"] = "LEFT",
},
{
["scale"] = 1.2,
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["layer"] = 2,
["truncate"] = true,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "castSpellName",
["align"] = "LEFT",
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
{
["truncate"] = false,
["align"] = "CENTER",
["layer"] = 2,
["maxWidth"] = 0,
["scale"] = 1,
["anchor"] = {
"TOPRIGHT",
57,
-13.5,
},
["kind"] = "castInterrupter",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyClassColors"] = true,
},
},
},
},
["global_scale"] = 0.99,
["target_behaviour"] = "enlarge",
["obscured_alpha"] = 0.4,
["click_region_scale_y"] = 2.3,
["style"] = "Luxthos",
["clickable_nameplates"] = {
["friend"] = false,
["enemy"] = true,
},
["target_scale"] = 1.2,
["show_nameplates"] = {
["friendlyMinion"] = false,
["enemyMinor"] = true,
["friendlyPlayer"] = true,
["friendlyNPC"] = false,
["enemyMinion"] = true,
["enemy"] = true,
},
}

MiliUI_PlatynatorProfile.kind = "profile"
MiliUI_PlatynatorProfile.addon = "Platynator"
MiliUI_PlatynatorVersion = 20260327
