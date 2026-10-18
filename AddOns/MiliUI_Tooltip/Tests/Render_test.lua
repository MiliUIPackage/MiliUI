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
    check("ItemRef：關閉鈕", refPanel.close and refPanel.close.shown)
    refPanel.close.scripts.OnClick()
    eq("ItemRef：點 × 轉呼叫 ItemRefCloseButton:Click()", env.ItemRefCloseButton.clicks, 1)

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
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMRIGHT", env.UIParent, "BOTTOMRIGHT", -10, 10)
    tip.left, tip.top = 100.4, 500.3
    check("Align：成功", P.Align(panel, tip))
    eq("Align：右側被錨 → TOPRIGHT", panel.points[1][1], "TOPRIGHT")
    near("Align：x 修到整數像素", panel.points[1][4], math.floor(100.4 + 200 + 0.5) - (100.4 + 200))
    near("Align：y 修到整數像素", panel.points[1][5], 500 - 500.3)

    tip:ClearAllPoints()
    tip:SetPoint(H.SECRET, env.UIParent, "TOP", 0, 0)
    eq("Align：秘密錨點 → false", P.Align(panel, tip), false)
    tip:ClearAllPoints()
    tip:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 0, 0)
    tip.GetTop = function() return H.SECRET end
    eq("Align：秘密 GetTop → false", P.Align(panel, tip), false)
end

H.finish("Render_test")
