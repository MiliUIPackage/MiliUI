------------------------------------------------------------
-- 外觀：邊框、圖示縮放、轉圈色、去飽和、GCD 轉圈、長條樣式
--
--   ns.Decorate.Apply(item, rec, barKey, w, h)   認領時套（簽章同就跳過）
--   ns.Decorate.InvalidateAll()                  設定變了：下一次認領全部重套
--   ns.Decorate.HookItem(item, rec)              Viewers 第一次看到 item 時叫（每框一次）
--
-- 規則
--   * **只寫有變的**：每個 item 存一個簽章字串（rec.decorated），條設定＋逐法術覆寫＋
--     長條尺寸組成；同簽章直接跳過。item 從池子重新取出時 Viewers 會清掉它
--     （暴雪取出時會重設計時顯示與縮放）。
--   * 自己畫的東西（邊框）一律建在**我們自己的 overlay 框**上（item 的子框），
--     不在 item 上建貼圖、不寫 item 的欄位；overlay 的參照存在弱鍵表 rec 裡。
--   * 暴雪每次刷新都會重寫的屬性（轉圈色、邊緣、轉圈開關、去飽和）不靠簽章，
--     改掛後掛勾：暴雪寫完，我們照 rec 上快取的設定再寫一次。
--   * 暴雪自己的裝飾（圓角遮罩、外框圖、觸發發光）只熄 alpha 或拔遮罩，不 Hide。
--
-- 觸發發光（SpellActivationAlert）：Core/Glow.lua 宣告接管（ns.Glow.ownsProcAlert = true）之後，
-- 條層「觸發發光」開著（或這個法術自己覆寫成開）的 item 熄掉暴雪的、在 overlay 上畫自己的；
-- 兩者都關時還給暴雪（alpha 1）。
--
-- 自訂法術／物品框（Modules/Custom.lua）也走這支 Apply：它們長得跟暴雪 item 一樣
-- （.Icon／.Cooldown／.ChargeCount.Current），邊框、縮放、轉圈色、文字同一套。
------------------------------------------------------------
local _, ns = ...

ns.Decorate = {}
local D = ns.Decorate

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local GCD_MAX = 1.5

local generation = 0            -- 設定變了就 +1，進簽章
local cooldownOwner = setmetatable({}, { __mode = "k" })   -- Cooldown 框 → item
local iconOwner     = setmetatable({}, { __mode = "k" })   -- Icon 貼圖 → item

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

local function C4(c, dr, dg, db, da)
    if type(c) ~= "table" then return dr, dg, db, da end
    return c.r or dr, c.g or dg, c.b or db, c.a or da
end

local function CSig(c)
    if type(c) ~= "table" then return tostring(c) end
    return string.format("%.3f,%.3f,%.3f,%.3f", c.r or 0, c.g or 0, c.b or 0, c.a or 1)
end

local function TSig(t)
    if type(t) ~= "table" then return tostring(t) end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = t[k]
        if v == nil then v = t[tonumber(k)] end
        if type(v) == "table" then v = (v.r ~= nil) and CSig(v) or TSig(v) end
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return "{" .. table.concat(parts, ";") .. "}"
end

------------------------------------------------------------
-- 條層設定一次解好（每條一份，generation 變了才重解）
------------------------------------------------------------
local resolved = {}

-- fresh = true：不讀也不寫快取（設定頁預覽用：滑桿拖動中只重畫預覽，不動 generation，
-- 真實條的簽章要等 debounce 之後的 InvalidateAll 才作廢）
function D.Resolve(barKey, fresh)
    local r = not fresh and resolved[barKey]
    if r and r.gen == generation then return r end
    local S = ns.Setting
    r = {
        gen          = generation,
        kind         = S(barKey, "kind") or "icons",
        font         = S(barKey, "font"),
        outline      = S(barKey, "outline") or "",
        border       = S(barKey, "border") or {},
        zoom         = tonumber(S(barKey, "icon.zoom")) or 0,
        swipeColor   = S(barKey, "icon.swipeColor"),
        hideGCDSwipe = S(barKey, "icon.hideGCDSwipe") and true or false,
        drawEdge     = S(barKey, "icon.drawEdge"),          -- 沒存 ＝ 不動暴雪的
        cooldownText = S(barKey, "cooldownText") or {},
        chargeText   = S(barKey, "chargeText") or {},
        stackText    = S(barKey, "stackText") or {},
        bar          = S(barKey, "bar"),
    }
    r.sig = table.concat({
        generation, r.kind, tostring(r.font), r.outline, TSig(r.border), r.zoom,
        CSig(r.swipeColor), tostring(r.hideGCDSwipe), tostring(r.drawEdge),
        TSig(r.cooldownText), TSig(r.chargeText), TSig(r.stackText),
        type(r.bar) == "table" and TSig(r.bar) or "-",
    }, "|")
    if not fresh then resolved[barKey] = r end
    return r
end

function D.InvalidateAll()
    generation = generation + 1
    for _, rec in pairs(ns.Viewers.frames) do rec.decorated = nil end
    if ns.Custom and ns.Custom.Records then
        for _, rec in pairs(ns.Custom.Records()) do rec.decorated = nil end
    end
end

local function SpellStyle(barKey, id)
    local SS = ns.SpellSetting
    return {
        borderColor      = SS(barKey, id, "borderColor"),
        desaturate       = SS(barKey, id, "desaturate"),
        hideCooldownText = SS(barKey, id, "hideCooldownText"),
        hideStackText    = SS(barKey, id, "hideStackText"),
    }
end

------------------------------------------------------------
-- overlay 框與邊框（自己的框、自己的貼圖）
------------------------------------------------------------
local function EnsureOverlay(item, rec, isBar)
    local ov = rec.overlay
    if not ov then
        ov = CreateFrame("Frame", nil, item)
        rec.overlay = ov
    end
    ov:ClearAllPoints()
    ov:SetAllPoints(item)
    -- 長條的子框是寫死的絕對層級（圖示 512、條 511、減益框 520），要蓋在它們上面
    local base = item:GetFrameLevel() or 1
    local lvl = base + 10
    if isBar and lvl < 530 then lvl = 530 end
    if lvl > 9000 then lvl = 9000 end
    ov:SetFrameLevel(lvl)
    return ov
end

local function MakeBorder(ov)
    local b = { ov = ov }
    for i = 1, 4 do
        local t = ov:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(WHITE)
        b[i] = t
    end
    return b
end

-- 只換顏色（無損刷新的邊框色、換回原色）：不動形狀
local function ColorBorder(b, r, g, bl, a)
    if not b then return end
    for i = 1, 4 do b[i]:SetVertexColor(r, g, bl, a) end
    if b.edge then b.edge:SetBackdropBorderColor(r, g, bl, a) end
end

function D.RecolorBorder(rec, c)
    if not (rec and type(c) == "table") then return end
    local r, g, bl, a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
    ColorBorder(rec.border, r, g, bl, a)
    ColorBorder(rec.border2, r, g, bl, a)
end

-- 換回 Apply 當時的顏色
function D.RestoreBorder(rec)
    local c = rec and rec.borderRGBA
    if not c then return end
    ColorBorder(rec.border, c[1], c[2], c[3], c[4])
    ColorBorder(rec.border2, c[1], c[2], c[3], c[4])
end

local function LayoutBorder(b, region, size, token, r, g, bl, a)
    if not b then return end
    if not region or not size or size <= 0 then
        for i = 1, 4 do b[i]:Hide() end
        if b.edge then b.edge:Hide() end
        return
    end
    -- 材質邊框（LibSharedMedia 的 border 類）是 backdrop 的 edgeFile：四條細條畫不出來，
    -- 改用一個 backdrop 框貼齊 region。粗細 1 ＝ edgeSize 4（這類材質本來就是 8～16 的邊）
    local edgeFile = ns.Media.Border(token)
    if edgeFile then
        for i = 1, 4 do b[i]:Hide() end
        local e = b.edge
        if not e then
            e = CreateFrame("Frame", nil, b.ov, "BackdropTemplate")
            b.edge = e
        end
        e:ClearAllPoints()
        e:SetAllPoints(region)
        e:SetBackdrop({ edgeFile = edgeFile, edgeSize = ns.P.Scale(size * 4) })
        e:SetBackdropBorderColor(r, g, bl, a)
        e:Show()
        return
    end
    if b.edge then b.edge:Hide() end
    local t = ns.Media.BorderInset(size)
    local tex = ns.Media.Texture(token)
    local top, bottom, left, right = b[1], b[2], b[3], b[4]
    for i = 1, 4 do
        b[i]:SetTexture(tex)
        b[i]:SetVertexColor(r, g, bl, a)
        b[i]:ClearAllPoints()
        b[i]:Show()
    end
    top:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    top:SetHeight(t)
    bottom:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(t)
    left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -t)
    left:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, t)
    left:SetWidth(t)
    right:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, -t)
    right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, t)
    right:SetWidth(t)
end

------------------------------------------------------------
-- 暴雪自己的裝飾：圓角遮罩拔掉、外框圖熄 alpha（每框一次）
------------------------------------------------------------
local function Unmask(tex)
    if not (tex and tex.GetNumMaskTextures and tex.RemoveMaskTexture) then return end
    for i = tex:GetNumMaskTextures(), 1, -1 do
        local m = tex:GetMaskTexture(i)
        if m then tex:RemoveMaskTexture(m) end
    end
end

local function DimAtlasRegions(frame, atlas)
    if not (frame and frame.GetRegions) then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetAtlas and region.GetObjectType and region:GetObjectType() == "Texture" then
            local a = Plain(region:GetAtlas())
            if a == atlas then region:SetAlpha(0) end
        end
    end
end

local function StripBlizzard(item, rec, isBar)
    if rec.stripped then return end
    rec.stripped = true
    if isBar then
        local iconFrame = item.Icon
        Unmask(iconFrame and iconFrame.Icon)
        DimAtlasRegions(iconFrame, ICON_OVERLAY_ATLAS)
    else
        Unmask(item.Icon)
        DimAtlasRegions(item, ICON_OVERLAY_ATLAS)
        local cd = item.Cooldown
        -- 圓角轉圈 → 方角（顏色參數不可省；實際色由 SetSwipeColor 決定）
        if cd and cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, WHITE, 1, 1, 1, 1) end
    end
end

------------------------------------------------------------
-- 後掛勾：暴雪每次刷新都會重寫的屬性
------------------------------------------------------------
local desatGuard = false

local function OnSetCooldown(cd, start, duration, modRate)
    local item = cooldownOwner[cd]
    local rec = item and ns.Viewers.frames[item]
    if not rec then return end
    -- 就緒發光的探針：同一組參數轉交（Core/Glow.lua，不讀不算）
    if ns.Glow and ns.Glow.OnItemSetCooldown then ns.Glow.OnItemSetCooldown(item, rec, start, duration, modRate) end
    if not rec.style then return end
    local st = rec.style
    if st.swipe then cd:SetSwipeColor(st.swipe[1], st.swipe[2], st.swipe[3], st.swipe[4]) end
    if type(st.drawEdge) == "boolean" then cd:SetDrawEdge(st.drawEdge) end
    if st.hideGCD then
        -- 秘密值讀不到就不動（寧可多轉一圈）
        local d = Plain(duration)
        if type(d) == "number" and d > 0 and d <= GCD_MAX then
            cd:SetDrawSwipe(false)
        end
    end
end

local function OnClearCooldown(cd)
    local item = cooldownOwner[cd]
    local rec = item and ns.Viewers.frames[item]
    if rec and ns.Glow and ns.Glow.OnItemClear then ns.Glow.OnItemClear(item, rec) end
end

local function OnSetDesaturated(icon)
    if desatGuard then return end
    local item = iconOwner[icon]
    local rec = item and ns.Viewers.frames[item]
    if not (rec and rec.style) or rec.style.desaturate ~= false then return end
    desatGuard = true
    icon:SetDesaturated(false)
    desatGuard = false
end

-- 暴雪換長條內容（僅圖示／僅名字）時會藏名字、重錨條：把名字 Show 回來（名字要一直
-- 顯示暴雪才會寫字），版面照我們的重排
local function OnSetBarContent(item)
    local rec = ns.Viewers.frames[item]
    if not rec then return end
    local name = item.Bar and item.Bar.Name
    if name and not name:IsShown() then name:Show() end
    if rec.barGeometry then D.ApplyBarGeometry(item, rec, rec.barGeometry) end
end

function D.HookItem(item, rec)
    if rec.decoHooked then return end
    rec.decoHooked = true
    local cd = item.Cooldown
    if cd and cd.SetCooldown and not rec.custom then
        cooldownOwner[cd] = item
        hooksecurefunc(cd, "SetCooldown", ns.Guard(OnSetCooldown))
        if cd.Clear then hooksecurefunc(cd, "Clear", ns.Guard(OnClearCooldown)) end
    end
    -- 無損刷新（ShowPandemicStateFrame／Hide…）的後掛勾在 Glow
    if not rec.custom and ns.Glow and ns.Glow.HookItem then ns.Glow.HookItem(item, rec) end
    local icon = item.Icon
    if not rec.custom and icon and icon.SetDesaturated and icon.GetObjectType and icon:GetObjectType() == "Texture" then
        iconOwner[icon] = item
        hooksecurefunc(icon, "SetDesaturated", ns.Guard(OnSetDesaturated))
    end
    if item.SetBarContent then
        hooksecurefunc(item, "SetBarContent", ns.Guard(OnSetBarContent))
    end
end

------------------------------------------------------------
-- 長條的版面：圖示邊、條身、底色、材質
------------------------------------------------------------
function D.ApplyBarGeometry(item, rec, g)
    local icon, b = item.Icon, item.Bar
    if not (icon and b) then return end
    local h = g.h
    local gap = ns.Layout.Snap(g.gap or 0)
    icon:ClearAllPoints()
    icon:SetSize(h, h)
    b:ClearAllPoints()
    if g.side == "RIGHT" then
        icon:SetPoint("RIGHT", item, "RIGHT", 0, 0)
        b:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", icon, "BOTTOMLEFT", -gap, 0)
    elseif g.side == "NONE" then
        icon:SetPoint("LEFT", item, "LEFT", 0, 0)
        b:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
        b:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    else
        icon:SetPoint("LEFT", item, "LEFT", 0, 0)
        b:SetPoint("TOPLEFT", icon, "TOPRIGHT", gap, 0)
        b:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    end
    if g.side == "NONE" then
        icon:SetAlpha(0)
    else
        icon:SetAlpha(1)
        if not icon:IsShown() then icon:Show() end     -- 暴雪「僅名字」會藏它；我們的設定優先
    end
end

local function ApplyBarLook(item, rec, style, bar)
    local b = item.Bar
    if not b then return end
    if b.SetStatusBarTexture then
        b:SetStatusBarTexture(ns.Media.Texture(bar.texture))
        local tex = b:GetStatusBarTexture()
        if tex then tex:SetVertexColor(C4(bar.color, 0.4, 0.6, 0.9, 1)) end
    end
    local bg = b.BarBG
    if bg then
        bg:ClearAllPoints()
        bg:SetAllPoints(b)
        bg:SetTexture(WHITE)
        bg:SetVertexColor(C4(bar.bgColor, 0.1, 0.1, 0.1, 0.8))
    end
    if b.Pip then b.Pip:SetAlpha(0) end
end

------------------------------------------------------------
-- 觸發發光：接管之後才熄（見檔頭）
------------------------------------------------------------
-- 暴雪的 SpellActivationAlert 是在第一次 ShowAlert 才建的：Glow 的 ShowAlert 後掛勾會再叫一次
local function ApplyProcAlert(item, rec, barKey)
    local alert = item.SpellActivationAlert
    if not alert then return end
    local G = ns.Glow
    local owns = G and G.ownsProcAlert and (not G.OwnsProc or G.OwnsProc(barKey, rec and rec.cooldownID))
    alert:SetAlpha(owns and 0 or 1)
end
D.ApplyProcAlert = ApplyProcAlert

------------------------------------------------------------
-- 簽章：條層設定＋逐法術覆寫＋格子尺寸（真實 item 與預覽格共用）
------------------------------------------------------------
local function Signature(style, id, spell, w, h)
    return style.sig .. "|" .. tostring(id) .. "|" .. CSig(spell.borderColor) .. "|"
        .. tostring(spell.desaturate) .. tostring(spell.hideCooldownText) .. tostring(spell.hideStackText)
        .. "|" .. tostring(w) .. "x" .. tostring(h)
end
D.Signature = Signature

------------------------------------------------------------
-- 主入口
------------------------------------------------------------
function D.Apply(item, rec, barKey, w, h)
    if not (item and rec and barKey) then return end
    local style = D.Resolve(barKey)
    local id = rec.cooldownID
    local spell = SpellStyle(barKey, id)
    local isBar = style.kind == "bars" and item.Bar ~= nil
    local sig = Signature(style, id, spell, w, h)
    if rec.decorated == sig and rec.decoratedBar == barKey then return end

    D.HookItem(item, rec)
    StripBlizzard(item, rec, isBar)

    -- 後掛勾讀的快取（暴雪下一次刷新時再套一次）
    local sr, sg, sb, sa = C4(style.swipeColor, 0, 0, 0, 0.8)
    rec.style = {
        swipe      = { sr, sg, sb, sa },
        drawEdge   = style.drawEdge,
        hideGCD    = style.hideGCDSwipe and not ns.Viewers.AURA_KIND[rec.barKey],
        desaturate = spell.desaturate,
    }

    local ov = EnsureOverlay(item, rec, isBar)
    local border = style.border or {}
    local br, bg, bb, ba = C4(spell.borderColor or border.color, 0, 0, 0, 1)
    local size = tonumber(border.size) or 0
    rec.borderRGBA = { br, bg, bb, ba }

    if isBar then
        local bar = type(style.bar) == "table" and style.bar or {}
        rec.barGeometry = { h = h, side = bar.iconSide or "LEFT", gap = bar.iconGap or 0 }
        D.ApplyBarGeometry(item, rec, rec.barGeometry)
        ApplyBarLook(item, rec, style, bar)
        -- 邊框：圖示一圈、條身一圈
        rec.border = rec.border or MakeBorder(ov)
        rec.border2 = rec.border2 or MakeBorder(ov)
        local showIcon = rec.barGeometry.side ~= "NONE"
        LayoutBorder(rec.border, showIcon and item.Icon or nil, size, border.texture, br, bg, bb, ba)
        LayoutBorder(rec.border2, item.Bar, size, border.texture, br, bg, bb, ba)
        local iconTex = item.Icon and item.Icon.Icon
        if iconTex and iconTex.SetTexCoord then
            local z = style.zoom
            iconTex:SetTexCoord(z, 1 - z, z, 1 - z)
        end
        ns.Text.ApplyBar(item, style, spell, bar)
    else
        rec.barGeometry = nil
        rec.border = rec.border or MakeBorder(ov)
        LayoutBorder(rec.border, item, size, border.texture, br, bg, bb, ba)
        if rec.border2 then LayoutBorder(rec.border2, nil) end
        local icon = item.Icon
        if icon and icon.SetTexCoord then
            local z = style.zoom
            icon:SetTexCoord(z, 1 - z, z, 1 - z)
        end
        local cd = item.Cooldown
        if cd then
            cd:SetSwipeColor(sr, sg, sb, sa)
            if type(style.drawEdge) == "boolean" then cd:SetDrawEdge(style.drawEdge) end
        end
        -- 關掉「冷卻中去飽和」：當場還原一次，之後靠 SetDesaturated 後掛勾擋
        if spell.desaturate == false and icon and icon.SetDesaturated then
            desatGuard = true
            icon:SetDesaturated(false)
            desatGuard = false
        end
        ns.Text.ApplyIcon(item, style, spell)
    end

    ApplyProcAlert(item, rec, barKey)
    rec.decorated, rec.decoratedBar = sig, barKey
    -- 發光的框跟著格子尺寸走（尺寸由我們給，不從 item 讀）；樣式變了的發光重畫
    if ns.Glow and ns.Glow.AfterApply then ns.Glow.AfterApply(item, rec, barKey, w, h) end
end

------------------------------------------------------------
-- 設定頁的預覽格：同一套邊框／縮放／轉圈色／文字樣式，餵的是**我們自己的假框**
--
--   ns.Decorate.ApplyPreview(cell, barKey, id, w, h)
--
-- cell 的形狀（Options/Preview.lua 建的）：
--   圖示  cell.Icon（貼圖）、cell.Cooldown（自己的 Cooldown 框）、cell.overlay、
--         cell.cdText／cell.chargeText／cell.stackText（FontString）、cell.onCD、cell.aura
--   長條  cell.Icon（框，.Icon 貼圖、.Applications）、cell.Bar（StatusBar，.Name／.Duration／.BarBG）、
--         cell.overlay
-- 讀值走 Resolve(barKey, true)：不碰快取，滑桿拖動中只重畫預覽。
-- 暴雪框的掛勾、剝除裝飾、觸發發光一律不做（假框上沒有那些東西）。
------------------------------------------------------------
function D.ApplyPreview(cell, barKey, id, w, h)
    if not (cell and barKey) then return end
    local style = D.Resolve(barKey, true)
    local spell = SpellStyle(barKey, id)
    local isBar = style.kind == "bars" and cell.Bar ~= nil
    local sig = Signature(style, id, spell, w, h) .. "|" .. tostring(cell.onCD) .. tostring(cell.aura)
    if cell.decorated == sig then return end

    local ov = cell.overlay
    local border = style.border or {}
    local br, bg, bb, ba = C4(spell.borderColor or border.color, 0, 0, 0, 1)
    local size = tonumber(border.size) or 0
    local z = style.zoom

    if isBar then
        local bar = type(style.bar) == "table" and style.bar or {}
        local g = { h = h, side = bar.iconSide or "LEFT", gap = bar.iconGap or 0 }
        D.ApplyBarGeometry(cell, nil, g)
        ApplyBarLook(cell, nil, style, bar)
        cell.border = cell.border or MakeBorder(ov)
        cell.border2 = cell.border2 or MakeBorder(ov)
        LayoutBorder(cell.border, g.side ~= "NONE" and cell.Icon or nil, size, border.texture, br, bg, bb, ba)
        LayoutBorder(cell.border2, cell.Bar, size, border.texture, br, bg, bb, ba)
        local iconTex = cell.Icon and cell.Icon.Icon
        if iconTex then iconTex:SetTexCoord(z, 1 - z, z, 1 - z) end
        ns.Text.ApplyBar(cell, style, spell, bar)
    else
        cell.border = cell.border or MakeBorder(ov)
        LayoutBorder(cell.border, cell, size, border.texture, br, bg, bb, ba)
        local icon = cell.Icon
        if icon then
            icon:SetTexCoord(z, 1 - z, z, 1 - z)
            -- 冷卻中的格才去飽和（增益沒有冷卻，不去飽和）
            icon:SetDesaturated((cell.onCD and not cell.aura and spell.desaturate) and true or false)
        end
        local cd = cell.Cooldown
        if cd then
            cd:SetSwipeColor(C4(style.swipeColor, 0, 0, 0, 0.8))
            if type(style.drawEdge) == "boolean" then cd:SetDrawEdge(style.drawEdge) end
        end
        ns.Text.ApplyPreviewIcon(cell, style, spell)
    end
    cell.decorated = sig
end
