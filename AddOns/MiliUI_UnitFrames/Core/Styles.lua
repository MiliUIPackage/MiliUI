------------------------------------------------------------
-- 樣式快速選擇（資料層）
--
-- 樣式＝一包單位設定值。玩家在設定頁點一張樣式卡先「試穿」（只有預覽孿生換樣子，
-- 見 Options/Preview.lua 的 SetOverride），按「套用」才寫進目前設定檔，可以「復原上一次」。
--
-- ⚠ 沒按套用的人行為完全不變：這支**不動任何預設值**、不需要遷移、不 bump DB_VERSION。
--   classic 就是 DB.BuildDefaults 的現行預設值；slim／card 從 classic 那份出發、只覆寫
--   版面相關的欄位（尺寸、元件位置、文字、小圖示），其餘欄位自然跟著現行預設。
--
-- 套用時哪些東西留玩家自己的（位置、縮放、顯示條件、顏色、光環過濾…）只看下面那張
-- PRESERVE 表 —— 別在程式裡零散地判斷「這個要留」。
--
-- 數字都在註解寫出算式：沒辦法實機看，審查靠算式。座標語意同 Core/DB.lua 檔頭：
--   元件 x/y ＝ 相對框 TOPLEFT（往下為負）；hpbar／mpbar 的 texts ＝ 相對**該條** TOPLEFT；
--   castbar 的 icon／spell／time／castTarget ＝ 相對施法條 TOPLEFT；
--   光環 x/y 釘的是容器的錨點角（往上長釘 BOTTOM、往左長釘 RIGHT，見 Elements/Auras.lua）。
-- 條的邊框畫在條自己的矩形**裡面**（內縮 1 實體像素），所以「兩條共用 1px 邊框」＝能量條的
-- y 往上疊 1、壓在血條最下面那一列上（能量條層級 0 在血條 4 底下，看到的是血條的下邊框）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local DB = ns.DB
local DeepCopy = ns.MiliUIDB.DeepCopy

ns.Styles = {}
local Styles = ns.Styles

-- 有樣式的單位（設定頁只有這四個單位出現「樣式」那一節）
Styles.UNITS = { "player", "target", "focus", "party" }
local SUPPORTED = {}
for _, k in ipairs(Styles.UNITS) do SUPPORTED[k] = true end
function Styles.Supports(unitKey) return SUPPORTED[unitKey] == true end

-- ⚠ label 必須是 L["…"] 單一字面值（語系稽核靠這個對 key）
Styles.LIST = {
    { id = "classic", label = L["Classic portrait"] },
    { id = "slim",    label = L["Slim bars"] },
    { id = "card",    label = L["Portrait card"] },
}
local KNOWN = { classic = true, slim = true, card = true }

-- 目標側：頭像卡的頭像放右邊（跟玩家框鏡像，兩個框面對面）
local TARGET_SIDE = { target = true, focus = true }
Styles.TARGET_SIDE = TARGET_SIDE

------------------------------------------------------------
-- 保留清單：套用（與試穿）時從玩家現有設定複製回來的欄位
--
-- 路徑相對單位設定表（units.<key>）。玩家存檔裡那格是 nil 就不複製（用樣式給的值）；
-- 樣式那份沒有對應的父表就略過（例如隊伍框沒有 classpower）。
-- 表就整張深拷貝過來（黑名單、門檻、資源條）。
--
-- 為什麼是這些：
--   * 框的「在哪裡、多大縮放、什麼時候出現、怎麼淡出／高亮」是玩家對**這個框**的選擇，
--     跟長相無關。多格單位的 growth／hSpacing 一樣；直排格距 spacing 跟框高綁在一起，
--     由樣式給（不在這裡）。
--   * 血條／能量條的上色方式與每一個顏色欄位（含背景透明度、閾值上色、各疊加層的色）。
--     前景透明度 barAlpha 不在這裡：精簡條／頭像卡要不透明的條，那是長相的一部分。
--   * 施法條的開關一定要留：關掉施法條時暴雪原生施法條是放出來的（Core/HideBlizzard.lua
--     看「我們的施法條實際建出來沒有」），樣式把它打開的話兩條疊在一起直到 /reload。
--     施法條的上色選項（職業色填充、不可打斷灰、斷法就緒、重要法術）是顏色，一起留。
--   * 光環：開關、過濾模式、只看自己的、黑白名單、右鍵取消 —— 「顯示哪些」不是版面。
--   * 玩家框掛在框底下的資源條（classpower）與魔力小條（manabar）整組不動：兩個都是
--     TOPLEFT 錨在單位框 BOTTOMLEFT（Elements/ClassPower.lua），框高變了會自己跟著走。
--     召喚物在 units.totem、不在單位表裡，本來就碰不到，也是錨在玩家框 BOTTOMLEFT。
--   * 觀察按鈕的開關、戰鬥中隱藏、圖示款式（位置與尺寸由樣式給）。
------------------------------------------------------------
local PRESERVE = {
    { "enabled" },

    -- 框：位置、縮放、多格排列方向
    { "frame", "x" }, { "frame", "y" }, { "frame", "scale" },
    { "frame", "growth" }, { "frame", "hSpacing" },
    -- 框：顯示條件（Core/Visibility.lua 讀的全部鍵）
    { "frame", "visShowCombat" }, { "frame", "visShowTarget" },
    { "frame", "visShowEnemy" },  { "frame", "visShowFocus" },
    { "frame", "visOnlyInstances" }, { "frame", "visHideMounted" },
    { "frame", "visHideCombat" }, { "frame", "visGroup" },
    { "frame", "clickWhenHidden" },
    -- 框：淡出
    { "frame", "fadeOutOfRange" }, { "frame", "fadeOutOfCombat" },
    { "frame", "oocShowWhenHurt" }, { "frame", "oocShowWithTarget" },
    -- 框：滑鼠／選中／驅散高亮
    { "frame", "highlight" }, { "frame", "targetHighlight" }, { "frame", "dispelHighlight" },

    -- 血條：上色
    { "elements", "hpbar", "colorMethod" }, { "elements", "hpbar", "bgColorMethod" },
    { "elements", "hpbar", "barColor" },    { "elements", "hpbar", "bgColor" },
    { "elements", "hpbar", "bgAlpha" },     { "elements", "hpbar", "borderColor" },
    { "elements", "hpbar", "fillDirection" },
    { "elements", "hpbar", "thresholdEnabled" }, { "elements", "hpbar", "thresholds" },
    { "elements", "hpbar", "lossColor" },
    { "elements", "hpbar", "healPredictionColor" }, { "elements", "hpbar", "healPredictionFollowBar" },
    { "elements", "hpbar", "healPredictionAlpha" },
    { "elements", "hpbar", "absorbColor" },  { "elements", "hpbar", "absorbBarColor" },
    { "elements", "hpbar", "overshieldColor" }, { "elements", "hpbar", "healAbsorbColor" },
    { "elements", "hpbar", "maxHealthLossColor" }, { "elements", "hpbar", "threatColor" },
    -- 能量條：上色
    { "elements", "mpbar", "colorMethod" }, { "elements", "mpbar", "bgColorMethod" },
    { "elements", "mpbar", "barColor" },    { "elements", "mpbar", "bgColor" },
    { "elements", "mpbar", "bgAlpha" },     { "elements", "mpbar", "borderColor" },
    { "elements", "mpbar", "fillDirection" },

    -- 施法條：開關與上色
    { "elements", "castbar", "enabled" }, { "elements", "castbar", "bg" },
    { "elements", "castbar", "fillDirection" }, { "elements", "castbar", "classColorBar" },
    { "elements", "castbar", "showInterruptState" }, { "elements", "castbar", "showInterruptReady" },
    { "elements", "castbar", "showImportantCast" },

    -- 光環：顯示與過濾
    { "elements", "buffs", "enabled" },  { "elements", "buffs", "filterMode" },
    { "elements", "buffs", "onlyMine" }, { "elements", "buffs", "blacklist" },
    { "elements", "buffs", "whitelist" }, { "elements", "buffs", "rightClickCancel" },
    { "elements", "debuffs", "enabled" },  { "elements", "debuffs", "filterMode" },
    { "elements", "debuffs", "onlyMine" }, { "elements", "debuffs", "blacklist" },
    { "elements", "debuffs", "whitelist" }, { "elements", "debuffs", "rightClickCancel" },

    -- 玩家框底下那疊（整組）
    { "elements", "classpower" }, { "elements", "manabar" },

    -- 觀察按鈕
    { "elements", "inspect", "enabled" }, { "elements", "inspect", "hideInCombat" },
    { "elements", "inspect", "style" },
}
Styles.PRESERVE = PRESERVE

-- 把 src（玩家存檔）在保留清單上的值深拷貝進 dst（樣式那份）。dst 原地改、也回傳。
-- 預覽孿生試穿時每次重建前都會再叫一次（Options/Preview.lua 的 Rebuild）：
-- 試穿期間拖曳孿生、改顏色寫的是存檔，孿生要跟著反映。
function Styles.CopyPreserved(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return dst end
    for _, path in ipairs(PRESERVE) do
        local s = src
        for i = 1, #path do
            if type(s) ~= "table" then s = nil break end
            s = s[path[i]]
        end
        if s ~= nil then
            local d = dst
            for i = 1, #path - 1 do
                d = type(d) == "table" and d[path[i]] or nil
            end
            if type(d) == "table" then
                d[path[#path]] = type(s) == "table" and DeepCopy(s) or s
            end
        end
    end
    return dst
end

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Put(t, fields)
    if type(t) ~= "table" then return end
    for k, v in pairs(fields) do t[k] = v end
end

local TextDef = DB.TextDef
local GRAY_TEXT = { r = 0.851, g = 0.851, b = 0.851, a = 1 }   -- 目前血量（同經典的那條）

-- 光環：只動位置／尺寸，數量、每排幾個、方向維持經典預設
local function Aura(els, name, fields) Put(els[name], fields) end

-- 小圖示：只動位置與尺寸
local function Icon(els, name, x, y, w, h)
    local ic = els.icons and els.icons[name]
    if ic then Put(ic, { x = x, y = y, w = w, h = h or w }) end
end

------------------------------------------------------------
-- 精簡條（slim）
--
-- 沒有頭像；血條不透明；能量條是血條正下方緊貼的一條細條（x 相同、不錯位），
-- 能量條上緣跟血條下緣共用 1px 邊框。
------------------------------------------------------------
-- 玩家／目標：寬 200（同經典寬度）。專注目標維持它經典的 120：它本來就是比目標小一號的框，
-- 精簡條把它撐到跟目標一樣寬反而變大了
local SLIM_W    = 200
local SLIM_FOCUS_W = 120
local SLIM_HP_H = 22
local SLIM_MP_H = 6
local SLIM_MP_Y = -(SLIM_HP_H - 1)           -- -21：疊在血條最下面那 1px 上
local SLIM_H    = SLIM_HP_H + SLIM_MP_H - 1  -- 27 = 22 + 6 - 1（框底＝能量條底）

-- 隊伍：寬 160
local SLIM_P_W    = 160
local SLIM_P_HP_H = 22
local SLIM_P_MP_H = 5
local SLIM_P_MP_Y = -(SLIM_P_HP_H - 1)              -- -21
local SLIM_P_H    = SLIM_P_HP_H + SLIM_P_MP_H - 1   -- 26 = 22 + 5 - 1
-- 光環同經典隊伍框：減益在框上方、增益在框下方，圖示 19（8 × 19 ＋ 7 ＝ 159 ＝ 160 − 1，跟框等寬）
local SLIM_P_AURA = 19
-- 格距要容得下上下兩排光環（同經典隊伍框的算法，見 Core/DB.lua 的 party）：
--   框高 26 ＋ 4 ＋ 這一格的增益列 19 ＋ 4 ＋ 下一格的減益列 19 ＋ 4 ＝ 76
local SLIM_P_SPACING = SLIM_P_H + 4 + SLIM_P_AURA + 4 + SLIM_P_AURA + 4

local STATUS_FULL = L["[gray_if_oor:Out of Range ][gray_if_tapped:Tapped ][gray_if_offline:Offline ][gray_if_dead:Dead ][gray_if_ghost:Ghost ]"]
local STATUS_SELF = L["[gray_if_dead:Dead][gray_if_ghost:Ghost]"]
-- 目標／專注：等級與分類寫在名字**前面、同一條文字裡**。分開兩條的話等級的寬度跟著
-- 「精英／稀有精英」變，名字那條的 x 只能猜；同一條就由字型自己排，永遠不會疊字。
local LEVEL_NAME = "[difficulty:level][difficulty:classification] [name]"

-- 血條右側：百分比貼右緣、目前血量接在它左邊（同經典：x = -42 ⇒ 右緣落在 200 - 42 = 158，
-- 留 42 給「100%」）。目前血量的字（10 號約 45～55 寬）從 158 往左長到 103～113。
-- 名字從左邊 3 起、寬 86 ⇒ 到 89：跟目前血量之間留 14 以上，也剛好讓開團標（90～110，見 SlimBig）。
local function SlimBigHPTexts(w, h)
    return {
        TextDef{ pattern = "[curhp] || ", x = -42, y = 0, w = w, h = h, size = 10,
                 justifyH = "RIGHT", justifyV = "MIDDLE", color = GRAY_TEXT },
        TextDef{ pattern = "[perchp]%", x = -3, y = 0, w = w, h = h, size = 12,
                 justifyH = "RIGHT", justifyV = "MIDDLE" },
    }
end

-- 蓋在框上的施法條（玩家／目標／隊伍）：跟框一樣大，圖示在左、法術名接著、秒數靠右
--   圖示邊長 = 框高 - 8（上下各留 4）
--   法術名 x = 4 + 圖示 + 4；寬到秒數的字（約 40 寬、靠右留 4）之前
local function OverlayCastbar(cb, w, h, spellW)
    local icon = h - 8
    Put(cb, { x = 0, y = 0, w = w, h = h })
    Put(cb.icon,  { x = 4, y = -4, w = icon, h = icon })
    Put(cb.spell, { x = 4 + icon + 4, y = 0, w = spellW, h = h, justifyV = "MIDDLE" })
    Put(cb.time,  { x = -4, y = 0, w = w, h = h, justifyH = "RIGHT", justifyV = "MIDDLE", size = 11 })
    -- 施法目標（預設關）：施法條正上方一行，右緣對齊施法條右緣
    Put(cb.castTarget, { x = 0, y = 12, w = w, h = 12, justifyH = "RIGHT", justifyV = "BOTTOM", size = 9 })
end

-- 專注目標的施法條：經典是一條細條浮在框**上方**（不蓋框），精簡條／頭像卡沿用這個位置，
-- 只把寬度拉成框寬。高 14，下緣離框頂 2 ⇒ y = 2 + 14 = 16。
--   圖示 14×14 貼左（同經典：圖示邊長＝條高）
--   法術名從 14 + 3 = 17 起，寬到秒數的字（約 40 寬、靠右留 4）之前：
--   框寬 200 ⇒ 130（上限）；框寬 120 ⇒ 120 - 17 - 44 = 59
local FOCUS_CB_H = 14
local function FocusCastbar(cb, w)
    Put(cb, { x = 0, y = 2 + FOCUS_CB_H, w = w, h = FOCUS_CB_H })
    Put(cb.icon,  { x = 0, y = 0, w = FOCUS_CB_H, h = FOCUS_CB_H })
    Put(cb.spell, { x = FOCUS_CB_H + 3, y = 0, w = math.min(130, w - FOCUS_CB_H - 3 - 44),
                    h = FOCUS_CB_H, size = 10,
                    justifyH = "LEFT", justifyV = "MIDDLE" })
    Put(cb.time,  { x = -3, y = 0, w = w, h = FOCUS_CB_H, size = 9,
                    justifyH = "RIGHT", justifyV = "MIDDLE" })
    -- 施法目標在施法條上方（y = 12，高 10 ⇒ 底邊在施法條頂 +2）
    Put(cb.castTarget, { x = 0, y = 12, w = w, h = 10, size = 9,
                         justifyH = "RIGHT", justifyV = "BOTTOM" })
end

local function SlimBig(u, unitKey)
    local els = u.elements
    local narrow = (unitKey == "focus")
    local W, H = narrow and SLIM_FOCUS_W or SLIM_W, SLIM_H
    Put(u.frame, { w = W, h = H })
    if els.portrait then els.portrait.enabled = false end
    -- 專注目標（120 寬）放不下「目前血量 | 百分比」兩條，只留百分比
    local hpTexts = SlimBigHPTexts(W, SLIM_HP_H)
    if narrow then hpTexts = { hpTexts[2] } end
    Put(els.hpbar, { x = 0, y = 0, w = W, h = SLIM_HP_H, barAlpha = 1, texts = hpTexts })
    Put(els.mpbar, { x = 0, y = SLIM_MP_Y, w = W, h = SLIM_MP_H, texts = {} })

    -- 框層文字：名字在血條內靠左（寬 86，理由見 SlimBigHPTexts）、狀態置中（死亡／離線時
    -- 數字多半是 0 或空的，蓋在中間不會跟名字搶）。不放種族職業那一行。
    local name = TARGET_SIDE[unitKey] and LEVEL_NAME or "[name]"
    els.texts = {
        -- 專注目標：120 - 3 - 42（留給「100%」）= 75
        TextDef{ pattern = name, x = 3, y = 0, w = narrow and (W - 3 - 42) or 86, h = SLIM_HP_H,
                 size = 12, justifyV = "MIDDLE" },
        TextDef{ pattern = unitKey == "player" and STATUS_SELF or STATUS_FULL,
                 x = 0, y = 0, w = W, h = SLIM_HP_H, size = 12,
                 justifyH = "CENTER", justifyV = "MIDDLE", level = 10 },
    }

    -- 施法條
    if els.castbar then
        if unitKey == "focus" then
            FocusCastbar(els.castbar, W)
        else
            -- 法術名從 4 + 19 + 4 = 27 起、寬 125 ⇒ 到 152，秒數（約 40 寬）在 156～196
            OverlayCastbar(els.castbar, W, H, 125)
        end
    end

    -- 光環
    if unitKey == "player" then
        -- 同經典的規則：增益對齊框下那疊（魔力小條／資源條，x = 8）、在框底往下 27
        -- 讓開那疊（經典 y = -(50 + 27) = -77）⇒ -(27 + 27) = -54。減益在框上，不變（y = 4）。
        Aura(els, "buffs", { y = -(H + 27) })
    elseif unitKey == "target" then
        -- 經典的增益 x = -8 是為了讓開往左露 8 的能量條；精簡條沒有露出，
        -- 改成跟減益同一套：8 × 24 ＋ 7 間距 = 199，從 0 起算右緣落在 199（框寬 200 減 1px 邊框）。
        -- y：框底 -27 往下留 4（同經典 -58 → -62）⇒ -31
        Aura(els, "buffs", { x = 0, y = -(H + 4), w = 24, h = 24 })
    elseif unitKey == "focus" then
        -- 同經典：兩排都在框下方，減益貼框底留 1、增益接在下面（19 ＋ 1 間距）
        Aura(els, "debuffs", { y = -(H + 1) })            -- -28
        Aura(els, "buffs",   { y = -(H + 1) - 19 - 1 })   -- -48
    end

    -- 小圖示（狀態、隊長、小隊編號在框頂之上，框高變了不必動）
    if unitKey == "focus" then
        -- 經典的團標在框頂正中（y = 12），跟浮在框上方的施法條（16..2）會疊在一起；
        -- 搬到框左邊外側、垂直置中：16 寬，右緣離框 4 ⇒ x = -20；y = -(27 - 16) / 2 ≈ -5
        Icon(els, "raidtarget", -20, -5, 16)
    else
        -- 團標：水平置中 (200 - 20) / 2 = 90 ⇒ 90～110，在名字（到 89）右邊；y = 12 ⇒ 跨在框頂上、
        -- 下緣 -8（同頭像卡；經典 y = 10）
        Icon(els, "raidtarget", (W - 20) / 2, 12, 20)
        -- PvP：經典在框左（玩家）／右（目標）裡面、28 高；精簡條只有 27 高、右邊外側又是觀察鈕，
        -- 一律搬到框左邊外側：28 寬、右緣離框 2 ⇒ x = -30。
        -- y = -4：上緣讓開狀態圖示（-8..6、下緣 -4）；下緣 -32，在框底 -27 與魔力小條上緣
        -- （框底再往下 6 ＝ -33）之間
        Icon(els, "pvp", -30, -4, 28)
    end

    -- 觀察按鈕（只有目標框有）：經典在框右上角、往下伸到 -20，精簡條上會壓住百分比 ⇒
    -- 搬到框右邊外側：x = 200 + 3 = 203；25 高、y = 1 ⇒ 下緣 -24，在框高 27 之內
    if els.inspect then Put(els.inspect, { x = W + 3, y = 1, w = 25, h = 25 }) end
end

local function SlimParty(u)
    local els = u.elements
    local W, H = SLIM_P_W, SLIM_P_H
    Put(u.frame, { w = W, h = H, spacing = SLIM_P_SPACING })
    if els.portrait then els.portrait.enabled = false end
    -- 百分比貼右緣（字約 32 寬 ⇒ 125～157）
    Put(els.hpbar, { x = 0, y = 0, w = W, h = SLIM_P_HP_H, barAlpha = 1,
                     texts = {
                         TextDef{ pattern = "[perchp]%", x = -3, y = 0, w = W, h = SLIM_P_HP_H, size = 12,
                                  justifyH = "RIGHT", justifyV = "MIDDLE" },
                     } })
    Put(els.mpbar, { x = 0, y = SLIM_P_MP_Y, w = W, h = SLIM_P_MP_H, texts = {} })
    -- 名字：讓出左邊的職責圖示（3 + 14 + 2 = 19 起），寬 95 ⇒ 到 114，百分比在 125 之後
    els.texts = {
        TextDef{ pattern = "[name]", x = 19, y = 0, w = 95, h = SLIM_P_HP_H, size = 12, justifyV = "MIDDLE" },
        TextDef{ pattern = STATUS_FULL, x = 0, y = 0, w = W, h = SLIM_P_HP_H, size = 11,
                 justifyH = "CENTER", justifyV = "MIDDLE", level = 10 },
    }
    -- 施法條（預設關）：蓋滿整格。圖示 26 - 8 = 18；法術名 4 + 18 + 4 = 26 起、寬 90 ⇒ 到 116
    if els.castbar then
        OverlayCastbar(els.castbar, W, H, 90)
        els.castbar.time.size = 10
        -- 格距只有 4，條上方放不下一行字：施法目標改成條內右上角
        Put(els.castbar.castTarget, { x = -4, y = -1, w = W, h = 10, justifyV = "TOP" })
    end
    -- 光環：同經典隊伍框的上下兩排（位置語意見 Core/DB.lua 的 party），只換圖示大小讓整排跟框等寬
    --   減益 y = 4（框頂上方）；增益 y = -(26 + 4) = -30（框底下方留 4）
    Aura(els, "debuffs", { x = 0, y = 4, w = SLIM_P_AURA, h = SLIM_P_AURA })
    Aura(els, "buffs",   { x = 0, y = -(H + 4), w = SLIM_P_AURA, h = SLIM_P_AURA })
    -- 小圖示：框頂上方是減益列，經典那種跨在框頂上的團標／隊長會蓋到減益 ⇒ 全部收進框的高度裡。
    --   職責：血條內左側，14×14、垂直置中 (22 - 14) / 2 = 4
    --   隊長：框左邊外側上半，10×10、y = -1 ⇒ -1..-11
    --   團標：框左邊外側下半，14×14、y = -12 ⇒ -12..-26（剛好到框底 26）
    --   兩個的水平中心都在 -10（隊長 -15..-5、團標 -17..-3）
    Icon(els, "role", 3, -(SLIM_P_HP_H - 14) / 2, 14)
    Icon(els, "leader", -15, -1, 10)
    Icon(els, "raidtarget", -17, -12, 14)
end

------------------------------------------------------------
-- 頭像卡（card）
--
-- 方形頭像在血條**外側**（不被血條蓋住），玩家／隊伍在左、目標／專注在右（鏡像）。
-- 頭像邊長＝框高，深色底＋1px 邊框。血條在頭像旁邊、不透明，能量條緊貼在血條下方
-- （共用 1px 邊框），兩條加起來等於框高。頭像與條之間留 2。
------------------------------------------------------------
local CARD_W, CARD_H = 200, 44
local CARD_GAP       = 2
local CARD_BAR_W     = CARD_W - CARD_H - CARD_GAP   -- 154 = 200 - 44 - 2
local CARD_HP_H      = 35
local CARD_MP_H      = CARD_H - CARD_HP_H + 1       -- 10 = 44 - 35 + 1（共用 1px）
local CARD_MP_Y      = -(CARD_HP_H - 1)             -- -34 ⇒ 能量條底 -34 - 10 = -44 ＝ 框底

local CARD_P_W, CARD_P_H = 168, 36                  -- 隊伍：同經典隊伍框的外框尺寸
local CARD_P_BAR_W   = CARD_P_W - CARD_P_H - CARD_GAP    -- 130 = 168 - 36 - 2
local CARD_P_HP_H    = 28
local CARD_P_MP_H    = CARD_P_H - CARD_P_HP_H + 1        -- 9 = 36 - 28 + 1
local CARD_P_MP_Y    = -(CARD_P_HP_H - 1)                -- -27 ⇒ 底 -36
-- 格距要容得下上下兩排光環（光環同經典隊伍框：上減益、下增益，20 見方）：
--   框高 36 ＋ 4 ＋ 這一格的增益列 20 ＋ 4 ＋ 下一格的減益列 20 ＋ 4 ＝ 88
local CARD_P_SPACING = CARD_P_H + 4 + 20 + 4 + 20 + 4

local PORTRAIT_BG = { r = 0.08, g = 0.08, b = 0.08, a = 1 }

-- 頭像方塊與兩條的 x
--   頭像在左：頭像 0、條從 頭像 + 2 起
--   頭像在右：條從 0 起、頭像在 條寬 + 2
local function CardColumns(w, h, right)
    local barW = w - h - CARD_GAP
    if right then return w - h, 0, barW end
    return 0, h + CARD_GAP, barW
end

local function CardBig(u, unitKey)
    local els = u.elements
    local right = TARGET_SIDE[unitKey] == true
    local W, H = CARD_W, CARD_H
    local px, bx, bw = CardColumns(W, H, right)   -- 玩家 0,46,154；目標／專注 156,0,154
    Put(u.frame, { w = W, h = H })
    if els.portrait then
        Put(els.portrait, { enabled = true, x = px, y = 0, w = H, h = H,
                            bg = { r = PORTRAIT_BG.r, g = PORTRAIT_BG.g, b = PORTRAIT_BG.b, a = 1 },
                            border = true })
    end

    -- 血條文字：百分比與目前血量在**遠離頭像**的那一側，上下兩行
    --   百分比 13 號：y = -2、高 16 ⇒ 中線 -10
    --   目前血量 10 號：y = -18、高 14 ⇒ 中線 -25（血條底 -35 之內）
    --   兩行右（左）緣都離條邊 3
    local side = right and "LEFT" or "RIGHT"
    local nx = right and 3 or -3
    Put(els.hpbar, { x = bx, y = 0, w = bw, h = CARD_HP_H, barAlpha = 1,
                     texts = {
                         TextDef{ pattern = "[perchp]%", x = nx, y = -2, w = bw, h = 16, size = 13,
                                  justifyH = side, justifyV = "MIDDLE" },
                         TextDef{ pattern = "[curhp]", x = nx, y = -18, w = bw, h = 14, size = 10,
                                  justifyH = side, justifyV = "MIDDLE", color = GRAY_TEXT },
                     } })
    Put(els.mpbar, { x = bx, y = CARD_MP_Y, w = bw, h = CARD_MP_H, texts = {} })

    -- 名字在**靠近頭像**那一側、整條血條高度內垂直置中，寬 98：
    --   數字那一欄最寬是「目前血量」（10 號字約 45～50 寬）＋ 離邊 3 ⇒ 名字留 154 - 3 - 50 - 3 = 98
    --   玩家：條內 3 起 ⇒ 框座標 46 + 3 = 49
    --   目標：靠右對齊，右緣離條邊 3 ⇒ x = 154 - 3 - 98 = 53
    local nameW = 98
    local nameX = right and (bx + bw - 3 - nameW) or (bx + 3)
    els.texts = {
        TextDef{ pattern = right and LEVEL_NAME or "[name]", x = nameX, y = 0, w = nameW, h = CARD_HP_H,
                 size = 13, justifyH = right and "RIGHT" or "LEFT", justifyV = "MIDDLE" },
        TextDef{ pattern = unitKey == "player" and STATUS_SELF or STATUS_FULL,
                 x = bx, y = 0, w = bw, h = CARD_HP_H, size = 12,
                 justifyH = "CENTER", justifyV = "MIDDLE", level = 10 },
    }

    -- 施法條：蓋在兩條上（不蓋頭像）。圖示 20（垂直置中 (44 - 20) / 2 = 12），
    -- 法術名 4 + 20 + 4 = 28 起、寬 82 ⇒ 到 110，秒數（約 40 寬）在 110～150
    if els.castbar then
        if unitKey == "focus" then
            FocusCastbar(els.castbar, W)
        else
            local cb = els.castbar
            Put(cb, { x = bx, y = 0, w = bw, h = H })
            Put(cb.icon,  { x = 4, y = -(H - 20) / 2, w = 20, h = 20 })
            Put(cb.spell, { x = 28, y = 0, w = 82, h = H, justifyV = "MIDDLE" })
            Put(cb.time,  { x = -4, y = 0, w = bw, h = H, size = 11, justifyH = "RIGHT", justifyV = "MIDDLE" })
            Put(cb.castTarget, { x = 0, y = 12, w = bw, h = 12, size = 9, justifyH = "RIGHT", justifyV = "BOTTOM" })
        end
    end

    -- 光環
    if unitKey == "player" then
        -- 同精簡條：增益 x = 8 對齊框下那疊、框底往下 27 ⇒ -(44 + 27) = -71；減益不變
        Aura(els, "buffs", { y = -(H + 27) })
    elseif unitKey == "target" then
        -- 跟精簡條同一套：8 × 24 ＋ 7 = 199 從 0 起算，右緣 199（頭像也在這個寬度裡）。
        -- y：框底 -44 往下留 4 ⇒ -48
        Aura(els, "buffs", { x = 0, y = -(H + 4), w = 24, h = 24 })
    elseif unitKey == "focus" then
        Aura(els, "debuffs", { y = -(H + 1) })            -- -45
        Aura(els, "buffs",   { y = -(H + 1) - 19 - 1 })   -- -65
    end

    -- 小圖示
    if unitKey == "focus" then
        -- 同精簡條：框外側、垂直置中。頭像在右 ⇒ 放左邊：x = -20，y = -(44 - 16) / 2 = -14
        Icon(els, "raidtarget", -20, -(H - 16) / 2, 16)
    else
        -- 團標：條那一段的正中、跨在框頂（y = 12 ⇒ 下緣 -8；名字 13 號在 35 高的條裡置中，
        -- 字面上緣約 -11，不碰）。玩家 46 + (154 - 20) / 2 = 113；目標 (154 - 20) / 2 = 67
        Icon(els, "raidtarget", bx + (bw - 20) / 2, 12, 20)
        -- PvP：框左邊外側、垂直置中 (44 - 28) / 2 = 8（玩家的頭像在左，放裡面會蓋住頭像）
        Icon(els, "pvp", -30, -(H - 28) / 2, 28)
    end
    -- 觀察按鈕（目標）：經典位置 (180, 5) 剛好浮在右邊頭像的右上角，跟經典一樣蓋在框角上
    if els.inspect then Put(els.inspect, { x = 180, y = 5, w = 25, h = 25 }) end
end

local function CardParty(u)
    local els = u.elements
    local W, H = CARD_P_W, CARD_P_H
    local px, bx, bw = CardColumns(W, H, false)   -- 0, 38, 130
    Put(u.frame, { w = W, h = H, spacing = CARD_P_SPACING })
    if els.portrait then
        Put(els.portrait, { enabled = true, x = px, y = 0, w = H, h = H,
                            bg = { r = PORTRAIT_BG.r, g = PORTRAIT_BG.g, b = PORTRAIT_BG.b, a = 1 },
                            border = true })
    end
    Put(els.hpbar, { x = bx, y = 0, w = bw, h = CARD_P_HP_H, barAlpha = 1,
                     texts = {
                         -- 百分比貼右緣（約 32 寬 ⇒ 條內 95..127，框座標 133..165）
                         TextDef{ pattern = "[perchp]%", x = -3, y = 0, w = bw, h = CARD_P_HP_H, size = 12,
                                  justifyH = "RIGHT", justifyV = "MIDDLE" },
                     } })
    Put(els.mpbar, { x = bx, y = CARD_P_MP_Y, w = bw, h = CARD_P_MP_H, texts = {} })
    -- 職責圖示在條內左側（38 + 3 = 41、垂直置中 (28 - 14) / 2 = 7），
    -- 名字接在後面：41 + 14 + 2 = 57 起、寬 68 ⇒ 到 125，百分比（「100%」12 號約 38 寬，
    -- 從右緣 165 往左長到 127）之前留 2
    els.texts = {
        TextDef{ pattern = "[name]", x = bx + 3 + 14 + 2, y = 0, w = 68, h = CARD_P_HP_H, size = 12,
                 justifyV = "MIDDLE" },
        TextDef{ pattern = STATUS_FULL, x = bx, y = 0, w = bw, h = CARD_P_HP_H, size = 11,
                 justifyH = "CENTER", justifyV = "MIDDLE", level = 10 },
    }
    -- 施法條（預設關）：蓋在兩條上。圖示 16（(36 - 16) / 2 = 10），法術名 4 + 16 + 4 = 24 起、寬 60 ⇒ 到 84，
    -- 秒數（約 40 寬、靠右留 4）在 86～126
    if els.castbar then
        local cb = els.castbar
        Put(cb, { x = bx, y = 0, w = bw, h = H })
        Put(cb.icon,  { x = 4, y = -(H - 16) / 2, w = 16, h = 16 })
        Put(cb.spell, { x = 24, y = 0, w = 60, h = H, size = 11, justifyV = "MIDDLE" })
        Put(cb.time,  { x = -4, y = 0, w = bw, h = H, size = 10, justifyH = "RIGHT", justifyV = "MIDDLE" })
        Put(cb.castTarget, { x = -4, y = -1, w = bw, h = 10, size = 9, justifyH = "RIGHT", justifyV = "TOP" })
    end
    -- 光環：框寬跟經典隊伍框相同 ⇒ 減益沿用經典（x = 0、y = 4、20 見方、8 × 20 ＋ 7 ＝ 167）；
    -- 這裡沒有往左下錯開的能量條，增益改成跟減益同一個左緣（x = 0）、貼框底留 4 ⇒ y = -(36 + 4) = -40
    Aura(els, "buffs", { x = 0, y = -(H + 4) })
    -- 小圖示：全部收進框裡（框頂上方是減益列，跨框頂的會蓋到減益）
    --   職責：條內左側 (41, -7)
    --   隊長：頭像左上角內側 (1, -1)，10×10
    --   團標：頭像右下角內側，14×14：x = 36 - 14 - 1 = 21、y = -(36 - 14 - 1) = -21
    Icon(els, "role", bx + 3, -(CARD_P_HP_H - 14) / 2, 14)
    Icon(els, "leader", 1, -1, 10)
    Icon(els, "raidtarget", H - 14 - 1, -(H - 14 - 1), 14)
end

------------------------------------------------------------
-- 組裝
------------------------------------------------------------
local BUILDERS = {
    slim = function(u, unitKey)
        if unitKey == "party" then SlimParty(u) else SlimBig(u, unitKey) end
    end,
    card = function(u, unitKey)
        if unitKey == "party" then CardParty(u) else CardBig(u, unitKey) end
    end,
}

-- 一張完整的單位設定表（跟 BuildDefaults().units[unitKey] 同形狀、全新的表）。
-- 不含玩家的保留欄位；要套保留清單用 Styles.Compose。
function Styles.Build(unitKey, styleId)
    if not (SUPPORTED[unitKey] and KNOWN[styleId]) then return nil end
    local defaults = DB.BuildDefaults().units
    local u = defaults[unitKey]
    if not u then return nil end
    -- 專注目標的經典版面沒有頭像元件；頭像卡要一個 ⇒ 借目標框預設的那份（3D、層級 3…），
    -- 位置與尺寸由 CardBig 給。回到經典時整張表換掉，這個元件就跟著消失
    if styleId == "card" and unitKey == "focus" and not u.elements.portrait then
        u.elements.portrait = defaults.target.elements.portrait
    end
    local fn = BUILDERS[styleId]
    if fn then fn(u, unitKey) end
    return u
end

-- 樣式 ＋ 玩家現有設定的保留欄位。試穿與套用都用這一份，兩邊才會一模一樣。
function Styles.Compose(unitKey, styleId)
    local u = Styles.Build(unitKey, styleId)
    if not u then return nil end
    return Styles.CopyPreserved(u, ns.GetUnitDB(unitKey))
end

------------------------------------------------------------
-- 套用與復原
--
-- 復原快照只留一層、只放記憶體（不進 SavedVariables）：它是「剛剛手滑」的保險，
-- 不是版本紀錄。一次套用多個單位就一次復原那幾個。換設定檔時丟掉（快照是舊設定檔的）。
------------------------------------------------------------
local undo     -- { profile = 名字, units = { [unitKey] = 深拷貝 }, keys = { … } }

-- 原地 wipe 再灌回：uf.db、設定面板的 ctx 都抓著這張表的參照（同 DB.ResetUnit）
local function Replace(live, data)
    wipe(live)
    for k, v in pairs(data) do live[k] = v end
end

local function Finish(keys)
    -- 先放掉試穿（不重建：下面的 ApplySettings 會帶孿生照新的存檔重建一次）
    if ns.Preview and ns.Preview.ClearOverride then
        for _, key in ipairs(keys) do ns.Preview.ClearOverride(key, true) end
    end
    -- ⚠ 先派送再 ApplySettings：設定頁收到 StyleApplied 會先丟掉這幾個單位的快取面板、
    -- 正在顯示的那份排到下一幀重建（Options/Tab_Unit.lua）。反過來的話 SettingsApplied 會因為
    -- 文字條數變了，當場把正在顯示的表單重建一次，下一幀又再建一次
    ns.Fire("StyleApplied", keys)
    for _, key in ipairs(keys) do ns.ApplySettings(key) end
end

-- 回傳 true；戰鬥中或參數不對回 false（呼叫端印訊息）
function Styles.ApplyMany(unitKeys, styleId)
    if InCombatLockdown() then return false end
    if not (KNOWN[styleId] and ns.db and type(unitKeys) == "table") then return false end
    local keys, built, snap = {}, {}, {}
    for _, key in ipairs(unitKeys) do
        local live = ns.GetUnitDB(key)
        local u = live and Styles.Compose(key, styleId)
        if u then
            keys[#keys + 1] = key
            built[key] = u
            snap[key] = DeepCopy(live)
        end
    end
    if #keys == 0 then return false end
    for _, key in ipairs(keys) do
        local u = built[key]
        u.style = styleId          -- 不進預設值：舊玩家是 nil ＝ 沒有哪一張卡是「目前」
        Replace(ns.GetUnitDB(key), u)
    end
    undo = { profile = ns.profileName, units = snap, keys = keys }
    Finish(keys)
    return true
end

function Styles.Apply(unitKey, styleId)
    return Styles.ApplyMany({ unitKey }, styleId)
end

function Styles.CanUndo()
    return undo ~= nil and undo.profile == ns.profileName
end

-- 復原上一次套用的那幾個單位（快照裡記著是哪幾個）。回傳 true／false
function Styles.Undo()
    if InCombatLockdown() then return false end
    if not Styles.CanUndo() then return false end
    local u = undo
    undo = nil
    for _, key in ipairs(u.keys) do
        local live = ns.GetUnitDB(key)
        if live then Replace(live, u.units[key]) end
    end
    Finish(u.keys)
    return true
end

-- 換設定檔：快照是上一份設定檔的，復原過去等於把它寫進新的這份 ⇒ 丟掉
ns.RegisterCallback("ProfileChanged", "styles", function() undo = nil end)
