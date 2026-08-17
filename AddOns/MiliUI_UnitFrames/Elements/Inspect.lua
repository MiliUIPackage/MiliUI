------------------------------------------------------------
-- 觀察按鈕：貼在單位框上的小按鈕，點下去開暴雪的觀察面板
-- （左右鍵都一樣，不分工）
--
-- 圖示全部用暴雪內建的 atlas／圖示檔，本插件不自帶貼圖；「圓底問號」那款連底
-- 都是白方塊套內建圓形遮罩裁出來的。
--
-- 12.1：可以觀察的只有玩家單位，而玩家單位的身分本來就不受限
-- （受限的定義是「非玩家操控、又不在自己隊伍裡」）→ 顯示閘門用 cache.isPlayer
-- （Cache 已經 ToBool 過）就夠，這裡不再自己讀任何 Unit API。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Media = ns.Media

------------------------------------------------------------
-- 圖示樣式
--
-- 一律用自己的圖，**不碰暴雪的 atlas**：實測 Midnight 已經把
-- UI-HUD-MicroMenu-CharacterInfo-Up 拿掉（微型選單整組重畫過），而 atlas 消失是
-- 靜默的——畫面上只會變成一張莫名其妙的備援圖示，沒有任何錯誤。
--
-- 兩張圖是 Media/inspect-icons.py 產生的（改造型就改那支再跑一次）：
-- 扁平白 + 套組主色 #4DD2FF 的鏡片，每個形狀都帶深色描邊，貼在 3D 頭像那種
-- 亮的、花的背景上才撐得住對比。
--
-- 「圓底問號」不吃這張表：它連圖都不用，整顆是畫出來的。
------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\MiliUI_UnitFrames\\Media\\"

local STYLE_DEFS = {
    inspector = { texture = MEDIA .. "inspect-inspector.png" },
    glass     = { texture = MEDIA .. "inspect-glass.png" },
}
ns.INSPECT_STYLE_DEFS = STYLE_DEFS      -- /muf debug 的探針要列

-- 設定面板的下拉選單（唯一來源就是這裡）
-- round 不是圖示、是整顆按鈕換一種畫法（見 EnsureRound）
ns.INSPECT_STYLE_ITEMS = {
    { text = L["Inspector"],           value = "inspector" },
    { text = L["Magnifier"],           value = "glass" },
    { text = L["Round question mark"], value = "round" },
}

-- 圓形遮罩：暴雪內建，本包好幾支插件都在用，12.x 確定還在
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- 自己的圖四周留白是畫進去的，不要再裁 texcoord（那是給暴雪 icon 檔用的，
-- 它們四邊各有一圈邊框留白）；明寫 0,1 是為了洗掉舊版本留下的裁切
local function ApplyIcon(tex, style)
    local def = STYLE_DEFS[style] or STYLE_DEFS.inspector
    tex:SetTexture(def.texture)
    tex:SetTexCoord(0, 1, 0, 1)
end

------------------------------------------------------------
-- 動作
--
-- InspectUnit 是 FrameXML 的全域函式，改版換過家好幾次 → 存在才呼叫，
-- 不在就自己把官方流程走一遍（載入 LoD 面板 → 通知伺服器 → 開窗）。
-- 這條路會被 taint 影響（MiliUI/Fix/InspectTaintFix.lua 專門吞那上面的
-- secret 錯誤），所以這裡自己再包一層錯誤隔離，點一下不要炸掉整個腳本。
------------------------------------------------------------
local function DoInspect(unit)
    if type(InspectUnit) == "function" then
        InspectUnit(unit)
        return
    end
    if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_InspectUI") end
    if NotifyInspect then NotifyInspect(unit) end
    if InspectFrame_Show then InspectFrame_Show(unit) end
end

-- 左右鍵同一件事：右鍵也接住是為了不要讓它穿過去變成單位框的右鍵選單
local function OnClick(self)
    local uf = self:GetParent()
    if not uf or uf.isPreview then return end     -- 預覽孿生只是排版用，不真的動作
    local unit = uf.unit
    if not unit then return end
    xpcall(DoInspect, ns.ReportError, unit)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Inspect"], 1, 1, 1)
    GameTooltip:AddLine(L["Opens the inspect window."], 0.4, 1, 0.4)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

------------------------------------------------------------
-- 圓底問號的畫法
--
-- 純白方塊套上內建的圓形遮罩，任何尺寸都是乾淨的圓（縮放不糊、不必自帶貼圖）。
-- 邊框是「外圈一顆、內圈一顆內縮一個邊框厚度」疊出來的：中間露出來那一圈就是邊，
-- 比找一張圓環貼圖可靠得多，粗細也跟其他元件共用同一個 BorderInset。
------------------------------------------------------------
local function NewCircleMask(btn, tex)
    local mask = btn:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    return mask
end

local function MaskCircle(btn, tex)
    local mask = NewCircleMask(btn, tex)
    tex:AddMaskTexture(mask)
    return mask
end

local function EnsureRound(btn)
    if btn.disc then return end
    btn.ring = btn:CreateTexture(nil, "BACKGROUND")
    btn.ring:SetTexture(Media.WHITE8X8)
    MaskCircle(btn, btn.ring)
    btn.disc = btn:CreateTexture(nil, "BORDER")
    btn.disc:SetTexture(Media.WHITE8X8)
    MaskCircle(btn, btn.disc)
    btn.glyph = btn:CreateFontString(nil, "ARTWORK")
    btn.glyph:SetPoint("CENTER", 0, 0)
    btn.glyph:SetTextColor(1, 1, 1, 1)
    btn.glyph:SetText("?")
end

------------------------------------------------------------
-- 建構／更新
------------------------------------------------------------
local function Build(uf, edb)
    local btn = uf.elements.inspect
    if not btn then
        btn = ns.CreateElementBase(uf, "inspect", "Button")
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetTexture(Media.WHITE8X8)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn:SetHighlightTexture(Media.WHITE8X8, "ADD")
        btn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.15)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", OnClick)
        btn:SetScript("OnEnter", OnEnter)
        btn:SetScript("OnLeave", OnLeave)
    end
    ns.ApplyElementBase(uf, btn, edb)
    -- 預覽孿生上的按鈕只是排版用：關掉滑鼠，免得它把編輯模式的拖曳吃掉
    btn:EnableMouse(not uf.isPreview)

    -- 邊框有畫就要內縮，內縮量一律問 BorderInset（直接寫 1 會在 Retina 露縫）
    local bordered = edb.border ~= false
    local inset = bordered and Media.BorderInset() or 0
    local c = edb.bgColor or { r = 0, g = 0, b = 0, a = 0.6 }
    local bc = (ns.db and ns.db.global.borderColor) or { r = 0, g = 0, b = 0, a = 1 }
    local hl = btn:GetHighlightTexture()
    local isRound = edb.style == "round"

    if isRound then
        EnsureRound(btn)
        -- 方形那套全部收起來：backdrop 的直角邊畫在圓底上會露出四個角
        btn:SetBackdrop(nil)
        btn.bg:Hide()
        btn.icon:Hide()

        btn.ring:SetAllPoints(btn)
        btn.ring:SetVertexColor(bc.r, bc.g, bc.b, bc.a or 1)
        btn.ring:SetShown(bordered)
        btn.disc:ClearAllPoints()
        btn.disc:SetPoint("TOPLEFT", inset, -inset)
        btn.disc:SetPoint("BOTTOMRIGHT", -inset, inset)
        btn.disc:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        btn.disc:Show()

        -- 問號跟著按鈕高度縮放，字級寫死的話換尺寸就爆框或縮成一點
        Media.SetFont(btn.glyph, math.max(8, math.floor((edb.h or 25) * 0.62)), "OUTLINE")
        btn.glyph:Show()

        hl:ClearAllPoints()
        hl:SetAllPoints(btn)
    else
        if bordered then
            Media.ApplyBorder(btn)
        else
            btn:SetBackdrop(nil)
        end
        if btn.disc then                       -- 從圓底切回來：圓的那三件要收掉
            btn.ring:Hide()
            btn.disc:Hide()
            btn.glyph:Hide()
        end

        btn.bg:ClearAllPoints()
        btn.bg:SetPoint("TOPLEFT", inset, -inset)
        btn.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
        btn.bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
        btn.bg:Show()

        local pad = inset + ns.P.Scale(edb.iconPadding or 2)
        btn.icon:ClearAllPoints()
        btn.icon:SetPoint("TOPLEFT", pad, -pad)
        btn.icon:SetPoint("BOTTOMRIGHT", -pad, pad)
        ApplyIcon(btn.icon, edb.style)
        btn.icon:Show()

        -- 高亮也跟著內縮，不然滑過去會把邊框一起蓋掉
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", inset, -inset)
        hl:SetPoint("BOTTOMRIGHT", -inset, inset)
    end

    -- 高亮跟著形狀走：方形白光罩在圓底上，四個角會凸出來。
    -- ⚠ 遮罩物件建了就拿不掉，切樣式只加／拆掛載，不要每次重建
    if isRound then
        btn.hlMask = btn.hlMask or NewCircleMask(btn, hl)
        if not btn.hlMasked then
            hl:AddMaskTexture(btn.hlMask)
            btn.hlMasked = true
        end
    elseif btn.hlMasked then
        hl:RemoveMaskTexture(btn.hlMask)
        btn.hlMasked = false
    end

    btn:Hide()      -- 顯示與否由 Update 決定
end

local function Update(uf, edb)
    local btn = uf.elements.inspect
    if not btn then return end
    -- 預覽一律畫出來：對著空氣調位置很痛苦
    if uf.isPreview then btn:Show(); return end
    -- 只有玩家觀察得了 → 其他單位一律不畫，不然就是一顆按不動的按鈕
    btn:SetShown(uf.cache.isPlayer and true or false)
end

ns.RegisterElement{
    name = "inspect",
    order = 75,
    -- 「是不是玩家」跟著身分欄位走，跟隊長圖示／PvP 圖示同一個桶
    buckets = { "reaction" },
    build = Build,
    update = Update,
}
