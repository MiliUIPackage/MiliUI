MiliUI_PlatynatorProfile = {
["stack_region_scale_x"] = 1.1,
["simplified_scale"] = 0.4,
["design_all"] = {
},
["show_nameplates"] = {
["friendlyMinion"] = false,
["enemyMinor"] = true,
["friendlyPlayer"] = false,
["friendlyNPC"] = false,
["enemyMinion"] = true,
["enemy"] = true,
},
["closer_nameplates"] = true,
["closer_to_screen_edges"] = true,
["click_region_scale_x"] = 1.1,
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
["designs_assigned"] = {
["enemySimplified"] = "Luxthos (Simplified)",
["friend"] = "Luxthos",
["enemy"] = "Luxthos",
},
["show_friendly_in_instances"] = true,
["cast_scale"] = 1,
["global_scale"] = 1.1,
["show_friendly_in_instances_1"] = "name_only",
["stack_applies_to"] = {
["normal"] = true,
["minion"] = false,
["minor"] = false,
},
["not_target_alpha"] = 1,
["apply_cvars"] = true,
["current_skin"] = "blizzard",
["style"] = "Luxthos",
["designs"] = {
["_custom"] = {
["highlights"] = {
},
["specialBars"] = {
},
["addon"] = "Platynator",
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.35,
["showCountdown"] = true,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
["showPandemic"] = true,
["height"] = 1,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["kind"] = "debuffs",
["textScale"] = 1,
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
"LEFT",
-117,
0,
},
["height"] = 1,
["kind"] = "buffs",
["textScale"] = 1,
["filters"] = {
["dispelable"] = true,
["important"] = true,
},
},
{
["direction"] = "RIGHT",
["scale"] = 1,
["showCountdown"] = true,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
["anchor"] = {
"RIGHT",
138,
0,
},
["height"] = 1,
["kind"] = "crowdControl",
["textScale"] = 1,
["filters"] = {
["fromYou"] = false,
},
},
},
["font"] = {
["outline"] = true,
["shadow"] = true,
["asset"] = "Friz Quadrata TT",
},
["version"] = 1,
["scale"] = 1,
["bars"] = {
{
["absorb"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["asset"] = "wide/blizzard-absorb",
},
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["color"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["height"] = 0.75,
["asset"] = "thin",
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
["warning"] = {
["r"] = 0.7568628191947937,
["g"] = 0.1450980454683304,
["b"] = 0.1764705926179886,
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
["offtank"] = {
["r"] = 0.05882353335618973,
["g"] = 0.6666666865348816,
["b"] = 0.7843137979507446,
},
},
["kind"] = "threat",
["useSafeColor"] = true,
["instancesOnly"] = false,
},
{
["colors"] = {
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
},
["neutral"] = {
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
},
["hostile"] = {
["r"] = 0.8352941870689392,
["g"] = 0,
["b"] = 0,
},
["friendly"] = {
["r"] = 0.2745098173618317,
["g"] = 0.8862745761871338,
["b"] = 0.3372549116611481,
},
},
["kind"] = "reaction",
},
},
["foreground"] = {
["asset"] = "white",
},
["relativeTo"] = 0,
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
["asset"] = "black",
},
["marker"] = {
["asset"] = "wide/glow",
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
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["height"] = 1,
["asset"] = "thin",
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
["scale"] = 1.5,
["anchor"] = {
"TOP",
0,
-8,
},
["foreground"] = {
["asset"] = "white",
},
["background"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyColor"] = true,
["asset"] = "black",
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
["anchor"] = {
"BOTTOMLEFT",
-113,
11,
},
["layer"] = 3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "elite",
["asset"] = "special/blizzard-elite",
["scale"] = 0.9,
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
["widthLimit"] = 0,
["truncate"] = false,
["scale"] = 1.1,
["layer"] = 2,
["significantFigures"] = 0,
["displayTypes"] = {
"percentage",
},
["anchor"] = {
"BOTTOMRIGHT",
95,
11,
},
["kind"] = "health",
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["align"] = "CENTER",
},
{
["widthLimit"] = 137,
["truncate"] = true,
["scale"] = 1.3,
["layer"] = 2,
["autoColors"] = {
},
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"BOTTOMLEFT",
-93,
12,
},
["kind"] = "creatureName",
["showWhenWowDoes"] = false,
["align"] = "LEFT",
},
{
["scale"] = 1.2,
["layer"] = 2,
["widthLimit"] = 0,
["truncate"] = false,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "castSpellName",
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["align"] = "CENTER",
},
},
},
["Luxthos (Simplified)"] = {
["highlights"] = {
{
["height"] = 0.5,
["anchor"] = {
"TOPLEFT",
-93,
1.5,
},
["layer"] = 2,
["scale"] = 1,
["color"] = {
["a"] = 0.3776039183139801,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "focus",
["asset"] = "striped-reverse",
["width"] = 1.48,
},
{
["height"] = 0.5,
["anchor"] = {
"TOP",
0,
3.5,
},
["layer"] = 2,
["scale"] = 1.52,
["color"] = {
["a"] = 0.6119787096977234,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "mouseover",
["asset"] = "1px",
["width"] = 1,
},
{
["anchor"] = {
"TOP",
0,
3.5,
},
["scale"] = 1.52,
["kind"] = "target",
["height"] = 0.5,
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 2,
["asset"] = "1px",
["width"] = 1,
},
},
["specialBars"] = {
},
["addon"] = "Platynator",
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.6,
["showCountdown"] = true,
["sorting"] = {
["reversed"] = false,
["kind"] = "duration",
},
["showPandemic"] = true,
["height"] = 1,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["kind"] = "debuffs",
["textScale"] = 0.7,
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
["height"] = 1,
["kind"] = "buffs",
["textScale"] = 1,
["filters"] = {
["dispelable"] = true,
["important"] = true,
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
},
["version"] = 1,
["scale"] = 2.8,
["bars"] = {
{
["absorb"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["asset"] = "wide/blizzard-absorb",
},
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["color"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["height"] = 0.5,
["asset"] = "1px",
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
["a"] = 1,
["r"] = 0.7372549019607844,
["g"] = 0.1098039215686275,
["b"] = 0,
},
["melee"] = {
["a"] = 1,
["r"] = 0.7803922295570374,
["g"] = 0.6196078658103943,
["b"] = 0.3686274588108063,
},
["caster"] = {
["a"] = 1,
["b"] = 1,
["g"] = 0.6431372761726379,
["r"] = 0,
},
["trivial"] = {
["a"] = 1,
["r"] = 0.4705882668495178,
["g"] = 0.4039216041564941,
["b"] = 0.3254902064800263,
},
["miniboss"] = {
["a"] = 1,
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
["warning"] = {
["a"] = 1,
["r"] = 0.7568628191947937,
["g"] = 0.1450980454683304,
["b"] = 0.1764705926179886,
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
["offtank"] = {
["r"] = 0.05882353335618973,
["g"] = 0.6666666865348816,
["b"] = 0.7843137979507446,
},
},
["kind"] = "threat",
["useSafeColor"] = true,
["instancesOnly"] = false,
},
{
["colors"] = {
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
},
["neutral"] = {
["a"] = 1,
["b"] = 0.3176470696926117,
["g"] = 0.7176470756530762,
["r"] = 0.8588235974311829,
},
["hostile"] = {
["a"] = 1,
["r"] = 0.7568628191947937,
["g"] = 0.1450980454683304,
["b"] = 0.1764705926179886,
},
["friendly"] = {
["r"] = 0.2745098173618317,
["g"] = 0.8862745761871338,
["b"] = 0.3372549116611481,
},
},
["kind"] = "reaction",
},
},
["foreground"] = {
["asset"] = "white",
},
["relativeTo"] = 0,
["anchor"] = {
"TOP",
0,
3.5,
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
["asset"] = "black",
},
["marker"] = {
["asset"] = "none",
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
["r"] = 0,
["g"] = 0,
["b"] = 0,
},
["height"] = 1,
["asset"] = "1px",
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
["a"] = 1,
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
["a"] = 1,
["r"] = 0.760784387588501,
["g"] = 0.3803921937942505,
["b"] = 1,
},
["channel"] = {
["a"] = 1,
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
["a"] = 1,
["r"] = 0.9058824181556702,
["g"] = 0.4235294461250305,
["b"] = 0.2000000178813934,
},
["interrupted"] = {
["a"] = 1,
["r"] = 1,
["g"] = 0.2039215862751007,
["b"] = 0.1450980454683304,
},
["channel"] = {
["a"] = 1,
["r"] = 0.9058824181556702,
["g"] = 0.4235294461250305,
["b"] = 0.2000000178813934,
},
},
["kind"] = "cast",
},
},
["scale"] = 1.5,
["anchor"] = {
"TOP",
0,
-8,
},
["foreground"] = {
["asset"] = "white",
},
["background"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["applyColor"] = true,
["asset"] = "black",
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
["openWorldOnly"] = true,
["anchor"] = {
"BOTTOMLEFT",
-116,
9.5,
},
["layer"] = 3,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "elite",
["asset"] = "special/blizzard-elite",
["scale"] = 1,
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
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "raid",
["anchor"] = {
"BOTTOMRIGHT",
57,
-1,
},
["layer"] = 3,
["asset"] = "normal/blizzard-raid",
["scale"] = 1.5,
},
},
["texts"] = {
{
["widthLimit"] = 132,
["truncate"] = true,
["scale"] = 1.3,
["layer"] = 2,
["autoColors"] = {
{
["combatOnly"] = true,
["colors"] = {
["warning"] = {
["r"] = 0.8,
["g"] = 0,
["b"] = 0,
},
["transition"] = {
["r"] = 1,
["g"] = 0.6274509803921569,
["b"] = 0,
},
["safe"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["offtank"] = {
["r"] = 0.05882352941176471,
["g"] = 0.6666666666666666,
["b"] = 0.7843137254901961,
},
},
["kind"] = "threat",
["useSafeColor"] = false,
["instancesOnly"] = true,
},
},
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"BOTTOMLEFT",
-94.5,
6.5,
},
["kind"] = "creatureName",
["showWhenWowDoes"] = false,
["align"] = "LEFT",
},
{
["scale"] = 1.2,
["layer"] = 2,
["widthLimit"] = 100,
["truncate"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["kind"] = "castSpellName",
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["align"] = "LEFT",
},
{
["widthLimit"] = 77,
["truncate"] = true,
["align"] = "RIGHT",
["layer"] = 2,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
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
["Luxthos"] = {
["highlights"] = {
{
["height"] = 0.98,
["scale"] = 1,
["kind"] = "focus",
["color"] = {
["a"] = 0.3776039183139801,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["anchor"] = {
"LEFT",
-93,
0,
},
["layer"] = 2,
["asset"] = "striped-reverse",
["width"] = 1.48,
},
{
["height"] = 0.8,
["scale"] = 1.52,
["kind"] = "mouseover",
["color"] = {
["a"] = 0.6119787096977234,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["anchor"] = {
},
["layer"] = 2,
["asset"] = "1px",
["width"] = 1,
},
{
["anchor"] = {
},
["height"] = 0.8,
["layer"] = 2,
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["scale"] = 1.52,
["kind"] = "target",
["asset"] = "1px",
["width"] = 1,
},
},
["specialBars"] = {
},
["addon"] = "Platynator",
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.6,
["showCountdown"] = true,
["filters"] = {
["important"] = true,
["fromYou"] = true,
},
["textScale"] = 0.7,
["height"] = 1,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["kind"] = "debuffs",
["showPandemic"] = true,
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
},
["textScale"] = 1,
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
},
["version"] = 1,
["scale"] = 1,
["bars"] = {
{
["relativeTo"] = 0,
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["height"] = 0.75,
["color"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["asset"] = "1px",
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
["kind"] = "eliteType",
["colors"] = {
["boss"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0.1098039215686275,
["r"] = 0.7372549019607844,
},
["melee"] = {
["a"] = 1,
["b"] = 0.3686274588108063,
["g"] = 0.6196078658103943,
["r"] = 0.7803922295570374,
},
["caster"] = {
["a"] = 1,
["r"] = 0,
["g"] = 0.6431372761726379,
["b"] = 1,
},
["trivial"] = {
["a"] = 1,
["b"] = 0.3254902064800263,
["g"] = 0.4039216041564941,
["r"] = 0.4705882668495178,
},
["miniboss"] = {
["a"] = 1,
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
["transition"] = {
["b"] = 0,
["g"] = 0.6274510025978088,
["r"] = 1,
},
["warning"] = {
["a"] = 1,
["b"] = 0.1764705926179886,
["g"] = 0.1450980454683304,
["r"] = 0.7568628191947937,
},
["safe"] = {
["b"] = 0.9019608497619628,
["g"] = 0.5882353186607361,
["r"] = 0.05882353335618973,
},
["offtank"] = {
["b"] = 0.7843137979507446,
["g"] = 0.6666666865348816,
["r"] = 0.05882353335618973,
},
},
["kind"] = "threat",
["instancesOnly"] = false,
["useSafeColor"] = true,
},
{
["colors"] = {
["unfriendly"] = {
["r"] = 1,
["g"] = 0.5058823529411764,
["b"] = 0,
},
["neutral"] = {
["a"] = 1,
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
},
["hostile"] = {
["a"] = 1,
["b"] = 0.1764705926179886,
["g"] = 0.1450980454683304,
["r"] = 0.7568628191947937,
},
["friendly"] = {
["b"] = 0.3372549116611481,
["g"] = 0.8862745761871338,
["r"] = 0.2745098173618317,
},
},
["kind"] = "reaction",
},
},
["marker"] = {
["asset"] = "none",
},
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
["asset"] = "black",
},
["foreground"] = {
["asset"] = "white",
},
["absorb"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["asset"] = "wide/blizzard-absorb",
},
},
{
["scale"] = 1.5,
["layer"] = 1,
["border"] = {
["height"] = 1,
["color"] = {
["a"] = 1,
["b"] = 0,
["g"] = 0,
["r"] = 0,
},
["asset"] = "1px",
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
["a"] = 1,
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
["a"] = 1,
["b"] = 1,
["g"] = 0.3803921937942505,
["r"] = 0.760784387588501,
},
["channel"] = {
["a"] = 1,
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
["a"] = 1,
["b"] = 0.2000000178813934,
["g"] = 0.4235294461250305,
["r"] = 0.9058824181556702,
},
["interrupted"] = {
["a"] = 1,
["b"] = 0.1450980454683304,
["g"] = 0.2039215862751007,
["r"] = 1,
},
["channel"] = {
["a"] = 1,
["b"] = 0.2000000178813934,
["g"] = 0.4235294461250305,
["r"] = 0.9058824181556702,
},
},
["kind"] = "cast",
},
},
["marker"] = {
["asset"] = "none",
},
["background"] = {
["color"] = {
["a"] = 1,
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["applyColor"] = true,
["asset"] = "black",
},
["foreground"] = {
["asset"] = "white",
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
["anchor"] = {
"BOTTOMLEFT",
-116,
9.5,
},
["kind"] = "elite",
["scale"] = 1,
["layer"] = 3,
["asset"] = "special/blizzard-elite",
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
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
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["kind"] = "raid",
["scale"] = 1.5,
["layer"] = 3,
["asset"] = "normal/blizzard-raid",
["anchor"] = {
"BOTTOMRIGHT",
58.5,
5,
},
},
},
["texts"] = {
{
["widthLimit"] = 0,
["displayTypes"] = {
"percentage",
},
["scale"] = 1.1,
["layer"] = 2,
["significantFigures"] = 0,
["align"] = "CENTER",
["anchor"] = {
"BOTTOMRIGHT",
96.5,
12.5,
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
["widthLimit"] = 132,
["truncate"] = true,
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["layer"] = 2,
["autoColors"] = {
{
["combatOnly"] = true,
["colors"] = {
["warning"] = {
["b"] = 0,
["g"] = 0,
["r"] = 0.8,
},
["transition"] = {
["b"] = 0,
["g"] = 0.6274509803921569,
["r"] = 1,
},
["safe"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["offtank"] = {
["b"] = 0.7843137254901961,
["g"] = 0.6666666666666666,
["r"] = 0.05882352941176471,
},
},
["kind"] = "threat",
["instancesOnly"] = true,
["useSafeColor"] = false,
},
},
["align"] = "LEFT",
["anchor"] = {
"BOTTOMLEFT",
-93.5,
12.5,
},
["kind"] = "creatureName",
["showWhenWowDoes"] = false,
["scale"] = 1.2,
},
{
["color"] = {
["r"] = 1,
["g"] = 1,
["b"] = 1,
},
["align"] = "LEFT",
["widthLimit"] = 100,
["truncate"] = true,
["anchor"] = {
"TOPLEFT",
-86,
-13,
},
["kind"] = "castSpellName",
["layer"] = 2,
["scale"] = 1.2,
},
{
["widthLimit"] = 77,
["truncate"] = true,
["color"] = {
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["layer"] = 2,
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
},
["target_behaviour"] = "enlarge",
["target_scale"] = 1.2,
["click_region_scale_y"] = 2.3,
["stack_region_scale_y"] = 1.8,
["clickable_nameplates"] = {
["friend"] = false,
["enemy"] = true,
},
["show_nameplates_only_needed"] = false,
["cast_alpha"] = 1,
}
MiliUI_PlatynatorProfile.kind = "profile"
MiliUI_PlatynatorProfile.addon = "Platynator"
