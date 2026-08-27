------------------------------------------------------------
-- 頭像框架專屬的選單清單與 spec 工廠
--
-- 這些以前住在 Controls.lua，但那支是**可以複製到其他 MiliUI 插件**的共用表單
-- 引擎，而「職業著色方式」「光環生長方向」只有頭像框架用得到。共用層裡混進宿主
-- 專屬資料，複製過去的插件就得帶著一堆用不到的選單和翻譯字串。
--
-- 新增本插件專屬的 spec 工廠請放這裡，不要寫回 Controls.lua。
------------------------------------------------------------
local _, ns = ...

local L = ns.WidgetsEnv.L

ns.Specs = {}
local Specs = ns.Specs

-- 超出距離的表現方式（見 Core/Visibility.lua）
Specs.OOR_STYLE_ITEMS = {
    { text = L["Dim"],  value = "dim" },
    -- ⚠ key 不能用 "Fade"：那個已經是「淡出」小節的標題（名詞形），
    -- 重複定義會靜默蓋掉其中一個，而且五個語系的名詞／動詞形本來就不同
    { text = L["Fade out"], value = "fade" },
}

Specs.COLOR_METHOD_ITEMS = {
    { text = L["Class color"],        value = "class" },
    { text = L["Class color (dark)"],  value = "classdark" },
    { text = L["Reaction color"],        value = "reaction" },
    { text = L["Reaction color (dark)"],  value = "reactiondark" },
    { text = L["Class first"],         value = "classfirst" },
    { text = L["Class first (dark)"],  value = "classfirstdark" },
    { text = L["Class / reaction"],    value = "classreaction" },
    { text = L["Class / reaction (dark)"], value = "classreactiondark" },
    { text = L["Power color"],        value = "power" },
    { text = L["Power color (dark)"],  value = "powerdark" },
    { text = L["Green"],          value = "hpgreen" },
    { text = L["Green (dark)"],    value = "hpgreendark" },
    { text = L["Red"],          value = "hpred" },
    { text = L["Red (dark)"],    value = "hpreddark" },
    { text = L["Gray"],          value = "gray" },
    { text = L["Custom color"],        value = "solid" },
    { text = L["Hidden"],          value = "hide" },
}

Specs.GROWTH_ITEMS = {
    { text = L["Left to right, downward"], value = "LRTB" },
    { text = L["Left to right, upward"], value = "LRBT" },
    { text = L["Right to left, downward"], value = "RLTB" },
    { text = L["Right to left, upward"], value = "RLBT" },
    { text = L["Top to bottom, rightward"], value = "TBLR" },
    { text = L["Top to bottom, leftward"], value = "TBRL" },
    { text = L["Bottom to top, rightward"], value = "BTLR" },
    { text = L["Bottom to top, leftward"], value = "BTRL" },
}

-- 九宮錨點。語意是「文字的哪一角貼到按鈕的同一角」，所以偏移的正負方向會隨錨點
-- 改變（靠左上要往右下推＝x 正 y 負，靠右下相反）。
Specs.ANCHOR_ITEMS = {
    { text = L["Top left"], value = "TOPLEFT" },
    { text = L["Top"], value = "TOP" },
    { text = L["Top right"], value = "TOPRIGHT" },
    { text = L["Left"], value = "LEFT" },
    { text = L["Center"], value = "CENTER" },
    { text = L["Right"], value = "RIGHT" },
    { text = L["Bottom left"], value = "BOTTOMLEFT" },
    { text = L["Bottom"], value = "BOTTOM" },
    { text = L["Bottom right"], value = "BOTTOMRIGHT" },
}

Specs.JUSTIFY_H_ITEMS = {
    { text = L["Left"], value = "LEFT" }, { text = L["Center"], value = "CENTER" }, { text = L["Right"], value = "RIGHT" },
}
Specs.JUSTIFY_V_ITEMS = {
    { text = L["Top"], value = "TOP" }, { text = L["Center"], value = "MIDDLE" }, { text = L["Bottom"], value = "BOTTOM" },
}
Specs.FLAGS_ITEMS = {
    { text = L["None"], value = "" }, { text = L["Outline"], value = "OUTLINE" }, { text = L["Thick outline"], value = "THICKOUTLINE" },
}

-- 位置尺寸四件組（最常用，抽成工廠）
function Specs.PosSize(sub, index, sub2)
    return { type = "numbers", sub = sub, sub2 = sub2, index = index, label = L["Position and size"],
             fields = { { key = "x", label = "X" }, { key = "y", label = "Y" },
                        { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } }
end
function Specs.Pos(sub, index, sub2)
    return { type = "numbers", sub = sub, sub2 = sub2, index = index, label = L["Position"],
             fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }
end
