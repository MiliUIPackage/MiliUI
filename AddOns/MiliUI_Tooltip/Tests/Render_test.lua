------------------------------------------------------------
-- Panel/Frame.lua＋Render.lua 的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Render_test.lua
--
-- 用假 panel（記錄 SetPoint／SetSize／SetText）驗 view → 幾何：
-- 寬度上下限與 snap、rows 右欄寬、prose 換行寬、Rule／Divider／Caption 的上下距、
-- 分隔線開關、圖示縮排與徽章、比價標籤、ItemRef 的關閉鈕、Strip、
-- 量測不讀 panel 自己的幾何（GetWidth 一叫就炸）。
-- 假字寬：每個位元組 size × 0.5（helpers.TextWidth）。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq, near = H.check, H.eq, H.near

local function Setup(scale)
    local env = H.Env()
    env.UIParent.scale = scale or 1
    env.ItemRefCloseButton = env.CreateFrame("Button")
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", Font = function() return "default.ttf" end },
        playerClass = "MAGE",
        db = { general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
            borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 } }, panel = { separators = true } },
    }
    H.Load(env, ns, "Libs/MiliUIWidgets/Secret.lua")
    H.Load(env, ns, "Panel/Patterns.lua")
    H.Load(env, ns, "Panel/Frame.lua")
    H.Load(env, ns, "Panel/Render.lua")
    local tip = H.Tip(env, "GameTooltip", {})
    local state = {}
    local panel = ns.Panel.Get(tip, state)
    -- 排版只准用自己記的數字：panel 的幾何一讀就炸
    panel.GetWidth = function() error("read panel geometry") end
    panel.GetHeight = panel.GetWidth
    return env, ns, tip, state, panel
end

local function FindText(panel, text)
    for i = 1, panel.textsUsed do
        if panel.texts[i].text == text then return panel.texts[i] end
    end
end

------------------------------------------------------------
-- 1. 寬度：下限、上限、snap
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    P.RenderView(panel, tip, { header = { { text = "Hi", style = "title" } } }, state)
    eq("下限 220", panel.width, 220)
    eq("SetWidth 同值", panel.w, 220)

    P.RenderView(panel, tip, { header = { { text = string.rep("x", 200), style = "title" } } }, state)
    eq("上限 440", panel.width, 440)
end

do
    -- 縮放 0.75：寬高都要落在整數實體像素上
    local _, ns, tip, state, panel = Setup(0.75)
    local P = ns.Panel
    P.RenderView(panel, tip, { header = { { text = string.rep("x", 37), style = "body" } } }, state)
    local px = panel.width * 0.75
    near("縮放 0.75：寬 snap 到整數像素", px, math.floor(px + 0.5))
    local py = panel.height * 0.75
    near("縮放 0.75：高 snap 到整數像素", py, math.floor(py + 0.5))
end

------------------------------------------------------------
-- 2. rows：右欄量寬、靠右
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    local view = {
        header = { { text = "Name", style = "title" } },
        sections = { { kind = "rows", rows = { { left = "Left side", right = "RIGHT" } } } },
    }
    P.RenderView(panel, tip, view, state)
    local right = FindText(panel, "RIGHT")
    local left = FindText(panel, "Left side")
    check("右欄存在", right ~= nil and left ~= nil)
    local want = H.TextWidth("RIGHT", 12) + 2
    eq("右欄寬 = 量出來 + 2", right.w, want)
    eq("右欄靠右", right.justifyH, "RIGHT")
    eq("右欄 x = 寬 − 內距 − 右欄寬", right.points[1][4], panel.width - 10 - want)
    eq("左欄 x = 內距", left.points[1][4], 10)
    eq("左欄寬 = 內寬 − 右欄 − 欄距", left.w, panel.width - 20 - want - 12)
    eq("左右同一列", left.points[1][5], right.points[1][5])
end

------------------------------------------------------------
-- 3. prose：換行寬（段落寬 300 封頂，不把 panel 撐到上限）
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    local long = string.rep("word ", 120)
    P.RenderView(panel, tip, {
        header = { { text = "N", style = "title" } },
        sections = { { kind = "prose", paragraphs = { long } } },
    }, state)
    eq("prose：panel 寬 = 段落寬 + 兩側內距", panel.width, 300 + 20)
    local fs = FindText(panel, long)
    eq("prose：文字寬 = 內寬", fs.w, 300)
    check("prose：換了好幾行（高 > 一行）", fs:GetStringHeight() > 12 * 3)

    -- numbers：描述數字上色
    P.RenderView(panel, tip, {
        header = { { text = "N", style = "title" } },
        sections = { { kind = "prose", paragraphs = { "Deals 150 damage" }, numbers = "ff0000" } },
    }, state)
    check("prose：數字上色", FindText(panel, "Deals |cffff0000150|r damage") ~= nil)
end

------------------------------------------------------------
-- 4. 分隔線：Rule 上下距、Divider 的 ◆、Caption、開關
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    local view = {
        header = { { text = "N", style = "title" } },
        sections = {
            { kind = "rows", rows = { { left = "A" } } },
            { separator = { rule = true }, kind = "rows", rows = { { left = "B" } } },
        },
    }
    P.RenderView(panel, tip, view, state)
    local a, b = FindText(panel, "A"), FindText(panel, "B")
    local aBottom = -a.points[1][5] + 14 + 2      -- A 的上緣 + 行高（size+2）+ 行距
    local line
    for i = 1, panel.texturesUsed do
        local t = panel.textures[i]
        if t.shown and t.h == 1 and t.w == panel.width - 20 then line = t end
    end
    check("Rule：畫了一條整寬 1px 線", line ~= nil)
    eq("Rule：線在上一段下方 6", -line.points[1][5], aBottom + 6)
    eq("Rule：下一段在線下方 1px + 6", -b.points[1][5], aBottom + 6 + 1 + 6)
    eq("Rule：白 alpha 0.22", line.color[4], 0.22)

    ns.db.panel.separators = false
    P.RenderView(panel, tip, view, state)
    local shown = 0
    for i = 1, panel.texturesUsed do if panel.textures[i].shown then shown = shown + 1 end end
    eq("分隔線關：沒有線", shown, 0)
    b = FindText(panel, "B")
    eq("分隔線關：留白還在", -b.points[1][5], aBottom + 6)
    ns.db.panel.separators = true

    P.RenderView(panel, tip, {
        header = { { text = "N", style = "title" } },
        sections = { { kind = "rows", rows = { { left = "A" } } },
            { separator = { divider = true }, kind = "rows", rows = { { left = "B" } } } },
    }, state)
    local diamond
    for i = 1, panel.texturesUsed do
        local t = panel.textures[i]
        if t.rotation and t.rotation ~= 0 then diamond = t end
    end
    check("Divider：◆ 轉 45°", diamond and math.abs(diamond.rotation - math.rad(45)) < 1e-9)
    eq("Divider：◆ 邊長 5", diamond and diamond.w, 5)
    check("Divider：◆ 職業色", diamond and math.abs(diamond.color[1] - 0.25) < 1e-9 and diamond.color[4] == 0.9)

    P.RenderView(panel, tip, {
        header = { { text = "N", style = "title" } },
        sections = { { separator = { caption = "Reagents" }, kind = "rows", rows = { { left = "B" } } } },
    }, state)
    local cap = FindText(panel, "Reagents")
    check("Caption：置中", cap and cap.justifyH == "CENTER")
    eq("Caption：字級 body−2", cap and cap.size, 10)
    eq("Caption：0.65 灰", cap and cap.textColor[1], 0.65)
end

------------------------------------------------------------
-- 5. 圖示縮排、徽章、標籤、關閉鈕、頁尾帶、Strip
------------------------------------------------------------
do
    local env, ns, tip, state, panel = Setup()
    local P = ns.Panel
    P.RenderView(panel, tip, {
        icon = 12345, iconSize = 40, badge = "639",
        header = { { text = "Sword", style = "title" }, { badges = { { "One-Hand" }, { "Sword" } }, style = "small" } },
        sections = { { kind = "rows", rows = { { left = "x" } } } },
        tag = "Currently Equipped",
        footer = { rows = { { left = "Durability", right = "165 / 165" } } },
    }, state)
    check("圖示顯示", panel.icon.shown and panel.icon.texture == 12345)
    eq("圖示尺寸", panel.icon.w, 40)
    local name = FindText(panel, "Sword")
    eq("標題縮排 = 內距 + 圖示 + 間距", name.points[1][4], 10 + 40 + 10)
    check("徽章列用 · 串", FindText(panel, "One-Hand · Sword") ~= nil)
    check("等級徽章", panel.badge.shown and panel.badgeText.text == "639")
    check("比價標籤", panel.tag and panel.tag.shown and panel.tag.text.text == "Currently Equipped")
    eq("比價標籤在 panel 上方外側", panel.tag.points[1][1], "BOTTOMLEFT")
    check("頁尾帶", panel.footer.shown)
    eq("頁尾帶 0.102 灰", panel.footer.color[1], 0.102)
    local x = FindText(panel, "x")
    check("內容不被圖示＋徽章蓋到", -x.points[1][5] >= 12 + 40 + 4 + 16)
    check("一般 tooltip 沒有關閉鈕", not panel.close or not panel.close.shown)

    -- ItemRefTooltip：關閉鈕轉呼叫原生那顆
    local refTip = H.Tip(env, "ItemRefTooltip", {})
    local refState = {}
    local refPanel = P.Get(refTip, refState)
    P.RenderView(refPanel, refTip, { header = { { text = "Linked", style = "title" } } }, refState)
    check("ItemRef：畫了 ×", refPanel.close and refPanel.close.shown)
    eq("ItemRef：× 是純 Frame（不收滑鼠、沒有 OnClick）", refPanel.close.kind, "Frame")
    eq("ItemRef：× 沒有 OnClick", refPanel.close.scripts.OnClick, nil)
    eq("ItemRef：原生關閉鈕疊到 × 上", env.ItemRefCloseButton.points[1][2], refPanel.close)
    eq("ItemRef：從來沒有 Click() 原生那顆", env.ItemRefCloseButton.clicks, nil)
    P.ResetNativeClose(refTip)
    eq("ItemRef：退回時貼回原位（錨 tooltip）", env.ItemRefCloseButton.points[1][2], refTip)
    eq("ItemRef：退回時貼回 TOPRIGHT -4,-4", env.ItemRefCloseButton.points[1][1] .. env.ItemRefCloseButton.points[1][4], "TOPRIGHT-4")

    -- Strip
    P.RenderView(panel, tip, {
        header = { { text = "Fireball", style = "title" } },
        sections = { P.Strip({ { label = "Cost", value = "50 Mana" }, { label = "Cast", value = "Instant", dim = true } }) },
    }, state)
    local v = FindText(panel, "50 Mana")
    eq("Strip：值字級 body+2", v and v.size, 14)
    eq("Strip：缺格 0.45 灰", FindText(panel, "Instant").textColor[1], 0.45)
end

------------------------------------------------------------
-- 6. 邊框色：Skin 記的那組原封不動交給 SetVertexColor（可以是秘密值）
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    state.borderColor = { H.SECRET, H.SECRET, H.SECRET, 1 }
    P.RenderView(panel, tip, { header = { { text = "N", style = "title" } } }, state)
    check("秘密邊框色只傳不讀", rawequal(panel.edges[1].color[1], H.SECRET))
    eq("邊框 1 實體像素", panel.edges[1].h, 1)
end

------------------------------------------------------------
-- 7. 對齊：照 tooltip 被錨的那一側；秘密錨點 → false
------------------------------------------------------------
do
    local env, ns, tip, state, panel = Setup()
    local P = ns.Panel
    -- 從上緣錨定（比價框、ANCHOR_TOP…）：貼上緣，照舊
    tip:ClearAllPoints()
    tip:SetPoint("TOPRIGHT", env.UIParent, "TOPRIGHT", -10, -10)
    tip.left, tip.top = 100.4, 500.3
    check("Align：成功", P.Align(panel, tip))
    eq("Align：TOPRIGHT 錨定 → 貼 TOPRIGHT", panel.points[1][1], "TOPRIGHT")
    near("Align：x 修到整數像素", panel.points[1][4], math.floor(100.4 + 200 + 0.5) - (100.4 + 200))
    near("Align：y 修到整數像素", panel.points[1][5], 500 - 500.3)

    -- 從下緣錨定（跟隨游標 cp=BOTTOMLEFT、固定右下）：貼下緣，原生高度暫時不對時 panel 不動
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 30, 40)
    tip.left, tip.top, tip.h = 100, 500.3, 100
    check("Align：下緣錨定成功", P.Align(panel, tip))
    eq("Align：BOTTOMLEFT 錨定 → 貼 BOTTOMLEFT", panel.points[1][1], "BOTTOMLEFT")
    eq("Align：對到 tooltip 的 BOTTOMLEFT", panel.points[1][3], "BOTTOMLEFT")
    near("Align：下緣也修到整數像素", panel.points[1][5], 400 - 400.3)
    -- 有附屬框：原生的底＝整組的底，主面板往上讓出縫＋附屬框
    panel.height, panel.totalHeight = 100, 160
    P.Align(panel, tip)
    near("Align：有附屬框時往上讓出 60", panel.points[1][5], (400 - 400.3) + 60)
    panel.totalHeight = 100
    -- 只有 LEFT／RIGHT／CENTER 的點：用 TOP
    tip:ClearAllPoints()
    tip:SetPoint("LEFT", env.UIParent, "CENTER", 0, 0)
    P.Align(panel, tip)
    eq("Align：只有 LEFT → 貼 TOPLEFT", panel.points[1][1], "TOPLEFT")
    -- 兩個點：第一個含 TOP／BOTTOM 的點決定垂直側
    tip:ClearAllPoints()
    tip:SetPoint("RIGHT", env.UIParent, "CENTER", 0, 0)
    tip:SetPoint("BOTTOM", env.UIParent, "CENTER", 0, 0)
    P.Align(panel, tip)
    eq("Align：RIGHT＋BOTTOM → 貼 BOTTOMRIGHT", panel.points[1][1], "BOTTOMRIGHT")

    tip:ClearAllPoints()
    tip:SetPoint(H.SECRET, env.UIParent, "TOP", 0, 0)
    eq("Align：秘密錨點 → false", P.Align(panel, tip), false)
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 0, 0)
    tip.GetTop = function() return H.SECRET end
    eq("Align：秘密 GetTop → false", P.Align(panel, tip), false)
end

------------------------------------------------------------
-- 8. 標題區到第一段：圖示（或徽章）底邊至少留 HEADER_BOTTOM；第一段是四格再多 ROW_GAP
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    P.RenderView(panel, tip, {
        icon = 1, iconSize = 36,
        header = { { text = "Sense Undead", style = "title" } },
        sections = { { kind = "rows", rows = { { left = "first" } } } },
    }, state)
    local first = FindText(panel, "first")
    local iconBottom = 12 + 36
    check("單行名字＋圖示：第一段 ≥ 圖示底 + 6", -first.points[1][5] >= iconBottom + 6, -first.points[1][5])

    P.RenderView(panel, tip, {
        icon = 1, iconSize = 36,
        header = { { text = "Sense Undead", style = "title" } },
        sections = { P.Strip({ { label = "CostLabel", value = "v" } }) },
    }, state)
    local label = FindText(panel, "CostLabel")
    eq("第一段是四格：再多 ROW_GAP", -label.points[1][5], iconBottom + 6 + 2)

    P.RenderView(panel, tip, {
        icon = 1, iconSize = 40, badge = "639",
        header = { { text = "Cap", style = "title" } },
        sections = { { kind = "rows", rows = { { left = "first" } } } },
    }, state)
    first = FindText(panel, "first")
    -- 徽章：圖示下 4、高 16
    check("有徽章：第一段 ≥ 徽章底 + 6", -first.points[1][5] >= 12 + 40 + 4 + 16 + 6, -first.points[1][5])
end

------------------------------------------------------------
-- 9. 行內圖示：頭尾那一顆拆出來另外畫（實機：附魔行尾的品質圖示掉半行）
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    local body = "Enchanted: Gift of the Ashes"
    local text = body .. " |A:Professions-ChatIcon-Quality-Tier3:17:15::1|a"
    local style = P.Styles().body
    eq("量寬：文字寬 + 圖示寬 + 間隔", P.Measure(text, style), H.TextWidth(body, 12) + 15 + P.ICON_TEXT_GAP)
    local before = 0
    P.RenderView(panel, tip, { header = { { text = "N", style = "title" } },
        sections = { { kind = "rows", rows = { { left = "plain" } } } } }, state)
    for i = 1, panel.texturesUsed do if panel.textures[i].shown then before = before + 1 end end
    P.RenderView(panel, tip, { header = { { text = "N", style = "title" } },
        sections = { { kind = "rows", rows = { { left = text } } } } }, state)
    local after, icon = 0, nil
    for i = 1, panel.texturesUsed do
        local t = panel.textures[i]
        if t.shown then after = after + 1 end
        if t.shown and t.atlas then icon = t end
    end
    eq("尾圖示：多一顆貼圖", after, before + 1)
    eq("尾圖示：atlas", icon and icon.atlas, "Professions-ChatIcon-Quality-Tier3")
    eq("尾圖示：寬照字串", icon and icon.w, 15)
    eq("尾圖示：高照字串", icon and icon.h, 17)
    local fs = FindText(panel, body)
    check("尾圖示：文字裡沒有 |A", fs ~= nil)
    eq("尾圖示：貼在文字之後", icon and icon.points[1][4], fs.points[1][4] + H.TextWidth(body, 12) + P.ICON_TEXT_GAP)
    eq("尾圖示：垂直置中在這一列", icon and icon.points[1][5], fs.points[1][5] - (12 + 2) / 2)
    eq("尾圖示：錨 LEFT", icon and icon.points[1][1], "LEFT")

    -- 頭圖示（|T，含裁切）：文字往右讓
    local lead = "|T12345:16:16:0:0:32:32:2:30:2:30|t Hearthstone"
    P.RenderView(panel, tip, { header = { { text = "N", style = "title" } },
        sections = { { kind = "rows", rows = { { left = lead } } } } }, state)
    local hs = FindText(panel, "Hearthstone")
    local ic
    for i = 1, panel.texturesUsed do if panel.textures[i].shown and panel.textures[i].texture == 12345 then ic = panel.textures[i] end end
    check("頭圖示：另外畫（檔案編號以數字餵 SetTexture）", ic ~= nil and ic.w == 16)
    eq("頭圖示：文字讓出圖示寬＋間隔", hs and hs.points[1][4], 10 + 16 + P.ICON_TEXT_GAP)

    -- 兩顆以上（錢幣）：不拆，照原樣交給 FontString
    local coins = "12|TGold:0|t 34|TSilver:0|t"
    eq("多顆圖示：不拆", select(2, P.SplitIcons(coins)), coins)
    eq("沒有圖示：不拆", select(2, P.SplitIcons("abc")), "abc")
    -- 大小沒給（0）：用該行字級
    local w, h = P.IconSize({ h = 0 }, style)
    check("圖示大小 0 → 字級", w == 12 and h == 12)
end

------------------------------------------------------------
-- 10. 附屬框：別人後加的行另開一框（設定 extrasBox）
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    local view = {
        header = { { text = "Thunderfury", style = "title" } },
        sections = { { kind = "rows", rows = { { left = "Binds when picked up" } } } },
        extras = { rows = { { left = "Item ID: 19019", color = { 1, 0.82, 0 } }, { left = "Bag: 3" } } },
    }
    state.borderColor = { 0.64, 0.21, 0.93, 1 }      -- 品質色只給主面板
    P.RenderView(panel, tip, view, state)
    local box = panel.extrasBox
    check("附屬框：顯示", box and box.shown)
    eq("附屬框：寬同主面板", box.w, panel.width)
    eq("附屬框：錨在主面板下方", box.points[1][1] .. ">" .. box.points[1][3], "TOPLEFT>BOTTOMLEFT")
    eq("附屬框：留縫 4", box.points[1][5], -4)
    eq("附屬框：totalHeight", panel.totalHeight, panel.height + 4 + box.height)
    eq("附屬框：邊框用 general.borderColor、不吃品質色", box.edges[1].color[1], 0.18)
    eq("附屬框：底色同主面板", box.bg.color[1], 0.133)
    local idLine
    for i = 1, box.textsUsed do if box.texts[i].text == "Item ID: 19019" then idLine = box.texts[i] end end
    check("附屬框：行保留自己的顏色", idLine and idLine.textColor[2] == 0.82)
    local inMain
    for i = 1, panel.textsUsed do if panel.texts[i].shown and panel.texts[i].text == "Bag: 3" then inMain = true end end
    check("附屬框：主面板裡沒有那些行", not inMain)

    ns.db.panel.extrasBox = false
    P.RenderView(panel, tip, view, state)
    check("開關關：附屬框藏起來", not box.shown)
    eq("開關關：totalHeight＝主高", panel.totalHeight, panel.height)
    inMain = false
    for i = 1, panel.textsUsed do if panel.texts[i].shown and panel.texts[i].text == "Bag: 3" then inMain = true end end
    check("開關關：接回主面板尾端", inMain)
    eq("開關關：view.sections 沒被改到", #view.sections, 1)
    ns.db.panel.extrasBox = true

    P.RenderView(panel, tip, { header = { { text = "N", style = "title" } }, extras = { rows = {} } }, state)
    check("沒有後加的行：附屬框藏起來", not box.shown)
    eq("沒有後加的行：totalHeight＝主高", panel.totalHeight, panel.height)
end

------------------------------------------------------------
-- 11. 對齊的遲滯（J2a）：原生角在半像素附近抖，面板的整數像素修正不翻轉
------------------------------------------------------------
do
    local env, ns, tip, state, panel = Setup()
    local P = ns.Panel
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMRIGHT", env.UIParent, "BOTTOMRIGHT", -10, 10)
    tip.top, tip.h = 500, 100
    tip.left = 100.49                       -- 右緣 300.49：捨入到 300
    P.Align(panel, tip)
    local dx1 = panel.points[1][4]
    near("前提：修正到 300", 300.49 + dx1, 300)
    tip.left = 100.51                       -- 浮點誤差把右緣推過半像素：不重算就會翻到 301
    P.Align(panel, tip)
    near("遲滯：0.02px 的抖動沿用上次的修正（不翻到 301）", panel.points[1][4], dx1)
    tip.left = 101.4                        -- 真的移動快一個像素：重算
    P.Align(panel, tip)
    near("真的移動超過半像素：重算", 301.4 + panel.points[1][4], 301)
    -- 重畫（RenderView 會 Detach(panel, true)）：遲滯記憶保留
    tip.left = 101.49
    P.Align(panel, tip)
    local dxKeep = panel.points[1][4]
    P.RenderView(panel, tip, { header = { { text = "N", style = "title" } } }, state)
    tip.left = 101.51
    P.Align(panel, tip)
    near("重畫之後：遲滯記憶還在（不翻）", panel.points[1][4], dxKeep)
    -- 退回（Detach 不保留）：照新位置重算
    P.Detach(panel)
    tip.left = 100.51
    P.Align(panel, tip)
    near("退回之後重新貼上：照新位置重算", 300.51 + panel.points[1][4], 301)
end

------------------------------------------------------------
-- 12. 夾邊範圍（L2）：四邊各留一圈 EDGE_MARGIN 呼吸；標籤高加在上緣
------------------------------------------------------------
do
    local _, ns, tip, state, panel = Setup()
    local P = ns.Panel
    local M = P.Scale(panel, P.LOOK.EDGE_MARGIN)
    P.RenderView(panel, tip, { header = { { text = "Hi", style = "title" } } }, state)
    eq("L2：沒有標籤、沒有附屬框 ⇒ 左緣 −呼吸", panel.clampInsets[1], -M)
    eq("L2：右緣 ＋呼吸", panel.clampInsets[2], M)
    eq("L2：上緣 ＋呼吸", panel.clampInsets[3], M)
    eq("L2：下緣 −呼吸", panel.clampInsets[4], -M)
    P.RenderView(panel, tip, { header = { { text = "Hi", style = "title" } }, tag = "Equipped" }, state)
    local m = P.Metrics(panel)
    eq("L2：有標籤 ⇒ 上緣 = 標籤高＋呼吸", panel.clampInsets[3], m.tagGap + m.tagH + M)
    eq("L2：有標籤時其他三邊不變", panel.clampInsets[4], -M)
end

do
    -- 預覽面板不夾邊、不設範圍
    local env = H.Env()
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", Font = function() return "default.ttf" end },
        playerClass = "MAGE",
        db = { general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
            borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 } }, panel = { separators = true } },
    }
    H.Load(env, ns, "Libs/MiliUIWidgets/Secret.lua")
    H.Load(env, ns, "Panel/Patterns.lua")
    H.Load(env, ns, "Panel/Frame.lua")
    H.Load(env, ns, "Panel/Render.lua")
    local tip = H.Tip(env, "Preview", {})
    local state = { isPreview = true }
    local panel = ns.Panel.Get(tip, state)
    ns.Panel.RenderView(panel, tip, { header = { { text = "Hi", style = "title" } } }, state)
    eq("L2：預覽面板不設夾邊範圍", panel.clampInsets, nil)
    check("L2：預覽面板不夾邊", not panel.clamped)
end

H.finish("Render_test")
