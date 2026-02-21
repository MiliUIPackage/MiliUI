MiliUI_PlatynatorProfile = {
["stack_region_scale_y"] = 1.4,
["show_nameplates"] = {
["friendlyMinion"] = false,
["enemyMinor"] = true,
["friendlyPlayer"] = true,
["enemy"] = true,
["enemyMinion"] = true,
["friendlyNPC"] = false,
},
["show_nameplates_only_needed"] = false,
["cast_scale"] = 1,
["design_all"] = {
},
["obscured_alpha"] = 0.4,
["click_region_scale_y"] = 2.3,
["closer_to_screen_edges"] = true,
["style"] = "Luxthos",
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
["friend"] = "MiliUI (Only Name)",
["enemySimplified"] = "Luxthos (Simplified)",
["enemy"] = "Luxthos",
},
["show_friendly_in_instances"] = true,
["current_skin"] = "blizzard",
["blizzard_widget_scale"] = 1.2,
["show_friendly_in_instances_1"] = "name_only",
["stack_applies_to"] = {
["normal"] = true,
["minion"] = false,
["minor"] = false,
},
["designs"] = {
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
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["textScale"] = 1,
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
["kind"] = "duration",
["reversed"] = false,
},
["anchor"] = {
"LEFT",
-117,
0,
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
},
},
{
["direction"] = "RIGHT",
["scale"] = 1,
["showCountdown"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["anchor"] = {
"RIGHT",
138,
0,
},
["showDispel"] = {
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
["neutral"] = {
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
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
["asset"] = "wide/glow",
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
["displayTypes"] = {
"percentage",
},
["scale"] = 1.1,
["layer"] = 2,
["maxWidth"] = 0,
["significantFigures"] = 0,
["truncate"] = false,
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
["scale"] = 1,
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.4,
["showCountdown"] = true,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
},
["textScale"] = 0.6,
["kind"] = "debuffs",
["height"] = 1,
["anchor"] = {
"BOTTOMLEFT",
-93,
34,
},
["showDispel"] = {
},
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
["kind"] = "duration",
["reversed"] = false,
},
["anchor"] = {
"BOTTOMLEFT",
-118.5,
-9,
},
["kind"] = "buffs",
["height"] = 1,
["showDispel"] = {
["enrage"] = true,
},
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
["kind"] = "duration",
["reversed"] = false,
},
["anchor"] = {
"RIGHT",
154,
0,
},
["kind"] = "crowdControl",
["height"] = 1,
["showDispel"] = {
},
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
["kind"] = "threat",
["useSafeColor"] = false,
["instancesOnly"] = true,
},
{
["colors"] = {
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
["b"] = 0.168627455830574,
["g"] = 0.1411764770746231,
["r"] = 0.729411780834198,
},
["neutral"] = {
["b"] = 0.3176470696926117,
["g"] = 0.7176470756530762,
["r"] = 0.8588235974311829,
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
["scale"] = 1.1,
["layer"] = 2,
["maxWidth"] = 0,
["significantFigures"] = 0,
["truncate"] = false,
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
["align"] = "CENTER",
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
["kind"] = "threat",
["useSafeColor"] = false,
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
["scale"] = 1,
["auras"] = {
{
["direction"] = "RIGHT",
["scale"] = 1.6,
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
["textScale"] = 0.7,
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
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
["kind"] = "buffs",
["height"] = 1,
["showDispel"] = {
["enrage"] = true,
},
["anchor"] = {
"BOTTOMLEFT",
-118.5,
-9,
},
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
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
["kind"] = "crowdControl",
["height"] = 1,
["showDispel"] = {
},
["anchor"] = {
"RIGHT",
154,
0,
},
["sorting"] = {
["kind"] = "duration",
["reversed"] = false,
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
["absorb"] = {
["color"] = {
["a"] = 1,
["b"] = 1,
["g"] = 1,
["r"] = 1,
},
["asset"] = "Platy: Absorb Wide",
},
["animate"] = false,
["scale"] = 1.5,
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
["neutral"] = {
["r"] = 0.8588235974311829,
["g"] = 0.7176470756530762,
["b"] = 0.3176470696926117,
},
},
["kind"] = "reaction",
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
["relativeTo"] = 0,
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
["kind"] = "threat",
["instancesOnly"] = true,
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
["scale"] = 1,
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
["neutral"] = {
["r"] = 1,
["g"] = 1,
["b"] = 0,
},
["unfriendly"] = {
["b"] = 0,
["g"] = 0.5058823529411764,
["r"] = 1,
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
["scale"] = 1.27,
},
{
["showWhenWowDoes"] = true,
["truncate"] = true,
["scale"] = 0.92,
["layer"] = 2,
["maxWidth"] = 0.99,
["npcRole"] = true,
["align"] = "CENTER",
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
["playerGuild"] = true,
},
},
},
},
["apply_cvars"] = true,
["not_target_alpha"] = 0.9,
["cast_alpha"] = 1,
["global_scale"] = 1.1,
["target_behaviour"] = "enlarge",
["target_scale"] = 1.2,
["click_region_scale_x"] = 1.1,
["closer_nameplates"] = true,
["clickable_nameplates"] = {
["friend"] = false,
["enemy"] = true,
},
["stack_region_scale_x"] = 1.1,
["simplified_scale"] = 0.9,
}

MiliUI_PlatynatorProfile.kind = "profile"
MiliUI_PlatynatorProfile.addon = "Platynator"
MiliUI_PlatynatorVersion = 20260222
