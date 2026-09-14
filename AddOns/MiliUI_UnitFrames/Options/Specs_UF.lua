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

-- 填充方向下拉（血條／能量條／施法條／魔力小條／資源條共用，值見 ns.FillReversed）。
-- 刻意用下拉而不是「反轉」勾選：勾選要先知道「正常」是哪個方向，下拉直接寫出方向
Specs.FILL_DIRECTION_ITEMS = {
    { text = L["Left to right"], value = "ltr" },
    { text = L["Right to left"], value = "rtl" },
}

-- 超出距離的表現方式（見 Core/Visibility.lua）
Specs.OOR_STYLE_ITEMS = {
    { text = L["Dim"],  value = "dim" },
    -- ⚠ key 不能用 "Fade"：那個已經是「淡出」小節的標題（名詞形），
    -- 重複定義會靜默蓋掉其中一個，而且五個語系的名詞／動詞形本來就不同
    { text = L["Fade out"], value = "fade" },
}

-- 上色方式。前四組（連同各自的暗色變體）是一條階梯：往下一階，能拿到職業色的單位
-- 就少一圈，拿不到的一律退敵我關係色。
--   class         所有單位 —— 小怪吃的是暴雪內部的假職業（近戰＝戰士色、施法者＝法師色）
--   classfirst    所有玩家 —— 含 PvP 敵方玩家與跨陣營路人（身分被藏起來時靠秘密布林曲線挑色）
--   classreaction 僅友方玩家 —— 敵對(2)／中立(4) 先被攔下來，所以 PvP 對手是紅的
--   reaction      沒有人
-- 順序本身就是說明的一部分，不要為了別的理由打散它（以前 reaction 卡在第二個，階梯是斷的）。
--
-- ⚠ text 改名隨意，**value 不能動** —— 那是存進 SavedVariables 的東西，而 Colors.Get
-- 對認不得的方法名會退成綠色血條（不是隱藏），玩家的設定會靜默變綠而且看不出原因。
Specs.COLOR_METHOD_ITEMS = {
    { text = L["Class color (everything)"],             value = "class" },
    { text = L["Class color (everything, dark)"],       value = "classdark" },
    { text = L["Class color (all players)"],            value = "classfirst" },
    { text = L["Class color (all players, dark)"],      value = "classfirstdark" },
    { text = L["Class color (friendly players)"],       value = "classreaction" },
    { text = L["Class color (friendly players, dark)"], value = "classreactiondark" },
    { text = L["Reaction color"],       value = "reaction" },
    { text = L["Reaction color (dark)"], value = "reactiondark" },
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

-- 寵物專精色**只給寵物框**：專精 API 問的是玩家自己的寵物欄，放進目標／首領的選單
-- 只會多兩個（除了選到自己寵物的那一刻）永遠等於「職業色（僅友方玩家）」的選項。
-- 插在職業色階梯（到敵我關係色為止）之後，不打斷上面那條階梯。
local PET_SPEC_ITEMS = {
    { text = L["Pet specialization color"],        value = "petspec" },
    { text = L["Pet specialization color (dark)"], value = "petspecdark" },
}
local petColorItems

function Specs.ColorMethodItems(unitKey)
    if unitKey ~= "pet" then return Specs.COLOR_METHOD_ITEMS end
    if not petColorItems then
        petColorItems = {}
        for _, item in ipairs(Specs.COLOR_METHOD_ITEMS) do
            tinsert(petColorItems, item)
            if item.value == "reactiondark" then
                for _, p in ipairs(PET_SPEC_ITEMS) do tinsert(petColorItems, p) end
            end
        end
    end
    return petColorItems
end

-- 寵物專精的名字用暴雪自己的（十二個語系都是官方譯名），查不到才退英文
function Specs.PetSpecName(specID, fallback)
    local get = GetSpecializationInfoByID
    if get then
        local ok, _, name = pcall(get, specID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return fallback
end

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
