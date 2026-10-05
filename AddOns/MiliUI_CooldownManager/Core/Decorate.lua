------------------------------------------------------------
-- 外觀：邊框、圖示縮放、轉圈色、去飽和、GCD 轉圈、長條樣式
--
--   ns.Decorate.Apply(item, rec, barKey, w, h)   認領時套（簽章同就跳過）
--   ns.Decorate.InvalidateAll()                  設定變了：下一次認領全部重套
--   ns.Decorate.HookItem(item, rec)              Viewers 第一次看到 item 時叫（每框一次）
--   ns.Decorate.HoverEnter(rec) / HoverLeave(rec) 可點擊群組的鈕轉來的 hover（提示照 overlay 的設定）
--   ns.Decorate.ApplyItemAlpha(item, rec, barAlpha) 暴雪 item 的 alpha 唯一出口（條的淡出 × 冷卻狀態，見下面那一節）
--   ns.Decorate.DurationColorOf(on, color)      增益持續時間那一段的倒數顏色（純函式，見下面那一節）
--   ns.Decorate.SyncAuraHide(item, rec)          「增益持續中不顯示持續時間」照現況蓋／還原（Apply 末尾叫，見那一節）
--   ns.Decorate.DesatCurve()                     去飽和的階梯曲線（剩餘 > 0 ⇒ 1；自訂法術與蓋掉增益的格共用）
--
-- 規則
--   * **只寫有變的**：每個 item 存一個簽章字串（rec.decorated），條設定＋逐法術覆寫＋
--     長條尺寸組成；同簽章直接跳過。item 從池子重新取出時 Viewers 只標 rec.reacquired（不清簽章），
--     簽章命中時走 D.Reattach 補做暴雪取出時會重設的那幾樣（Viewers.CHEAP_REACQUIRE ＝ false 回到「清簽章、整套重套」）。
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
--
-- 圖示外觀＝Masque（Core/Masque.lua，依登入時的 Mode 分支）：格子交給 Masque 群組之後，
-- 邊框、縮放、轉圈材質由它畫；我們的邊框照樣排好但藏著，只有無損刷新期間亮出來
-- （RecolorBorder／RestoreBorder）。交不出去（戰鬥中保護鏈上、幾何讀不到、群組在 Masque 裡被停用）
-- 的時候照米利樣式畫，交出去了再重套一次。
------------------------------------------------------------
local _, ns = ...

ns.Decorate = {}
local D = ns.Decorate
-- /mcdm perf 的計數（Api.lua；只 +1，不配置）：
--   applyCalls／applySkipped（簽章命中）／applyPre（前置鍵命中：連 SpellStyle／簽章都沒算，見 D.PreKeyMatch）
--   setCooldownHooks（SetCooldown 後掛勾被叫幾次）／afterCooldownWrites（其中倒數色／formatter 真的重寫的次數：
--   去重沒擋下來的；轉圈色與邊緣暴雪每次都重寫，我們每次都蓋，不算在這裡，見 AfterCooldown）
D.applyCalls, D.applySkipped, D.applyPre = 0, 0, 0
D.setCooldownHooks, D.afterCooldownWrites = 0, 0
D.applyReattach = 0             -- 簽章命中而且剛重新取出 ⇒ 只補做（D.Reattach）

local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local ICON_OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"

local generation = 0            -- 設定變了就 +1，進簽章
-- 條層樣式的世代（前置鍵的第一欄）：InvalidateAll 時 +1。Resolve 的快取 resolved[barKey] 只靠 generation 作廢
-- （沒有任何地方單獨清 resolved[barKey]；fresh 的那條路不讀也不寫快取），所以兩個一起動
D.styleGen = 0
local cooldownOwner = setmetatable({}, { __mode = "k" })   -- Cooldown 框 → item
local iconOwner     = setmetatable({}, { __mode = "k" })   -- Icon 貼圖 → item
local nameOwner     = setmetatable({}, { __mode = "k" })   -- 長條名字 FontString → item

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
        tooltips     = S(barKey, "icon.tooltips") and true or false,
        -- 按鍵鏡射（Core/Keybinds.lua 的 SyncPress 讀這兩欄）：舊存檔沒有 ＝ 主題預設 false／0.35
        pressFlash   = S(barKey, "icon.pressFlash") and true or false,
        pressAlpha   = tonumber(S(barKey, "icon.pressFlashAlpha")) or 0.35,
        swipeColor   = S(barKey, "icon.swipeColor"),
        hideGCDSwipe = S(barKey, "icon.hideGCDSwipe") and true or false,
        hideDebuffBorder = S(barKey, "icon.hideDebuffBorder") ~= false,   -- 舊存檔沒有這欄 ＝ 預設藏
        drawEdge     = S(barKey, "icon.drawEdge"),          -- 沒存 ＝ 不動暴雪的
        colorDuration = S(barKey, "icon.colorDuration") and true or false,   -- 增益那一段的倒數換色（PhaseColors）
        durationColor = S(barKey, "icon.durationColor"),
        durationLowColor   = S(barKey, "icon.durationLowColor"),       -- 增益那一段的低秒顏色（門檻共用 cooldownText.lowBelow）
        durationSwipeColor = S(barKey, "icon.durationSwipeColor"),     -- 增益那一段的轉圈背景色
        cooldownText = S(barKey, "cooldownText") or {},
        chargeText   = S(barKey, "chargeText") or {},
        stackText    = S(barKey, "stackText") or {},
        stackBarPoint = S(barKey, "stackText.barPoint") or "BOTTOMRIGHT",   -- 長條的層數錨點（Text.ApplyBar）
        bar          = S(barKey, "bar"),
        masque       = ns.Masque and ns.Masque.Mode(barKey) == "masque" or false,
    }
    r.sig = table.concat({
        generation, r.kind, tostring(r.font), r.outline, TSig(r.border), r.zoom,
        CSig(r.swipeColor), tostring(r.hideGCDSwipe), tostring(r.hideDebuffBorder), tostring(r.drawEdge), tostring(r.tooltips),
        tostring(r.pressFlash), r.pressAlpha,
        tostring(r.colorDuration), CSig(r.durationColor), CSig(r.durationLowColor), CSig(r.durationSwipeColor),
        TSig(r.cooldownText), TSig(r.chargeText), TSig(r.stackText), r.stackBarPoint,
        type(r.bar) == "table" and TSig(r.bar) or "-",
        tostring(r.masque) .. tostring(r.masque and ns.Masque.Active()),
    }, "|")
    if not fresh then resolved[barKey] = r end
    return r
end

function D.InvalidateAll()
    generation = generation + 1
    D.styleGen = D.styleGen + 1
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
        cdState          = SS(barKey, id, "cdState"),
        cdStateAlpha     = SS(barKey, id, "cdStateAlpha"),
        dimNoAura        = SS(barKey, id, "dimNoAura"),
        customIcon       = D.IconOverrideOf(id),
        -- 增益持續時間那一段的換色（五個欄位跟條層同一套，沒覆寫自然退回條層）：開關是布林、三個顏色是色表
        colorDuration      = SS(barKey, id, "colorDuration") and true or false,
        durationColor      = SS(barKey, id, "durationColor"),
        durationLowColor   = SS(barKey, id, "durationLowColor"),
        durationSwipeColor = SS(barKey, id, "durationSwipeColor"),
        -- 增益持續中顯示持續時間：布林（沒覆寫退回條層 icon.showAuraTime）；false ＝ 這格蓋掉增益那一段
        showAuraTime     = SS(barKey, id, "showAuraTime"),
    }
end
D.SpellStyle = SpellStyle                                           -- 測試用

------------------------------------------------------------
-- 增益持續時間的倒數換色
--
-- 核心／輔助的技能用掉之後，暴雪的格子先倒**增益的持續時間**、增益掉了才改倒冷卻
-- （CooldownViewerCooldownItemMixin:RefreshSpellCooldownInfo：先 cooldownFrame:SetUseAuraDisplayTime(旗標)
-- 再 CooldownFrame_Set）。旗標是暴雪 Lua 裡的字面布林（CacheCooldownValues 那幾支寫的），
-- 我們在 SetUseAuraDisplayTime 的後掛勾裡記進 rec.auraTime（讀不到／秘密值 ＝ false），
-- SetCooldown 的後掛勾（暴雪緊接著就叫）與重新裝飾時照它換倒數數字的顏色（ns.Text.ApplyPhaseColor）。
-- 只做暴雪核心／輔助的 item（含被搬進自訂群組的）：增益兩條整條都是增益時間、自訂法術沒有增益階段。
-- 低秒變色（formatter 裡的 |c 色碼）兩段都照舊生效、壓過這個顏色。
--
-- 設定是五個欄位、逐法術跟條層同一套（SpellStyle 用 SpellSetting 解好：沒覆寫退回條層）：
--   showAuraTime 顯示增益持續時間 → colorDuration 換色開關 → durationColor／durationLowColor／durationSwipeColor
--   on     生效的 colorDuration（布林）
--   color  生效的 durationColor（色表）
-- 回傳色表（{ r, g, b, a }，設定本身的參照）或 nil（不換色）
------------------------------------------------------------
function D.DurationColorOf(on, color)
    if on and type(color) == "table" then return color end
    return nil
end

-- 倒數數字兩段的顏色（陣列 { r, g, b, a }）：style ＝ Resolve 解好的那包（cooldownText.color）、
-- spell ＝ SpellStyle 解好的那包（colorDuration、durationColor；逐法術沒覆寫就是條層的值）
-- 回傳 cdColor（冷卻那一段＝倒數原色）, durColor（增益那一段；nil ＝ 這格不換色）
function D.PhaseColors(style, spell)
    local st = type(style) == "table" and style or {}
    local sp = type(spell) == "table" and spell or {}
    local ct = type(st.cooldownText) == "table" and st.cooldownText or {}
    local dc = D.DurationColorOf(sp.colorDuration, sp.durationColor)
    return { C4(ct.color, 1, 1, 1, 1) }, dc and { C4(dc, 1, 1, 1, 1) } or nil
end

------------------------------------------------------------
-- 自訂圖示（逐法術覆寫 customIcon：貼圖檔案編號）
--
--   ns.Decorate.IconOverrideOf(id)       → 檔案編號或 nil（沒設、false、壞值、光環格）
--   ns.IconFor(barKey, id, info)         → 顯示用的圖示：有覆寫用覆寫，否則 info.icon（設定頁的預覽、挑選器、
--                                          逐法術面板標題都走這支；Catalog.Info 本身不改）
--
-- 套用：自訂框在 Custom.Update 設圖示時先看覆寫；暴雪 item 由 Apply 當場換、再後掛勾 Icon 貼圖的 SetTexture
-- （暴雪每次 RefreshSpellTexture 換回去時再蓋回來，遞迴防護同 desatGuard）。光環格（引擎畫圖示）、固定格位的
-- 占位不支援。
------------------------------------------------------------
local function ValidIcon(v)
    return type(v) == "number" and v > 0 and v == math.floor(v)
end
D.ValidIcon = ValidIcon

function D.IconOverrideOf(id)
    if id == nil then return nil end
    local C = ns.Catalog
    if C and C.IsAuraSlot and C.IsAuraSlot(id) then return nil end
    local v = ns.SpellSetting and ns.SpellSetting(nil, id, "customIcon")
    return ValidIcon(v) and v or nil
end

function ns.IconFor(barKey, id, info)
    local own = D.IconOverrideOf(id)
    if own then return own end
    return info and info.icon or nil
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
D.MakeBorder = MakeBorder          -- 下一招圖示（Modules/AssistIcon.lua）的邊框跟格子同一套

-- 只換顏色（無損刷新的邊框色、換回原色）：不動形狀
local function ColorBorder(b, r, g, bl, a)
    if not b then return end
    for i = 1, 4 do b[i]:SetVertexColor(r, g, bl, a) end
    if b.edge then b.edge:SetBackdropBorderColor(r, g, bl, a) end
end

local LayoutBorder

-- Masque 在畫外框時，我們的邊框平常藏著（Apply 只記下排法：rec.msqEdge），
-- 無損刷新期間才照那個排法亮出來；粗細 0 的話至少 1，不然換色等於看不到。
-- 長條的條身那圈（border2）不歸 Masque，照常換色
local function ShowHiddenBorder(rec, r, g, bl, a)
    local e = rec.msqEdge
    if not e then return end
    LayoutBorder(rec.border, e.region, math.max(1, e.size or 0), e.token, r, g, bl, a)
end

function D.RecolorBorder(rec, c)
    if not (rec and type(c) == "table") then return end
    local r, g, bl, a = c.r or 1, c.g or 1, c.b or 1, c.a or 1
    if rec.msqSkinned then
        ShowHiddenBorder(rec, r, g, bl, a)
    else
        ColorBorder(rec.border, r, g, bl, a)
    end
    ColorBorder(rec.border2, r, g, bl, a)
end

-- 換回 Apply 當時的顏色（Masque 在畫時：藏回去）
function D.RestoreBorder(rec)
    if rec and rec.msqSkinned then LayoutBorder(rec.border, nil) end
    local c = rec and rec.borderRGBA
    if not c then return end
    if not rec.msqSkinned then ColorBorder(rec.border, c[1], c[2], c[3], c[4]) end
    ColorBorder(rec.border2, c[1], c[2], c[3], c[4])
end

function LayoutBorder(b, region, size, token, r, g, bl, a)
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
D.LayoutBorder = LayoutBorder

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

-- 只做一次（rec.stripped；轉圈材質另外記，見 SquareSwipe）。查證（2026-09-30，12.1.0.69933 的 Blizzard_CooldownViewer）：
-- 圓角遮罩（MaskTexture atlas UI-HUD-CoolDownManager-Mask）、外框圖、轉圈材質
-- （SwipeTexture UI-HUD-CoolDownManager-Icon-Swipe）全部只在 CooldownViewer.xml 的模板裡宣告；
-- CooldownViewer.lua／CooldownViewerItemData.lua 沒有任何 AddMaskTexture／SetSwipeTexture／SetAtlas，
-- OnAcquireItemFrame 只設 viewer、縮放、計時／提示顯示、hideWhenInactive、編輯中；
-- RefreshData／SetCooldownID 只換資料與轉圈「顏色」（SetSwipeColor，由 Decorate 的 SetCooldown 後掛勾重寫）；
-- 池子的 reset 只 Hide＋清錨點＋ResetCooldownData。⇒ 池化的框一次拔乾淨就一直乾淨，取出時不必重做。
-- 暴雪哪天在 Lua 裡重加遮罩／換轉圈材質，改成在 Viewers.Track 清 rec.stripped。
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
    end
end

-- 暴雪的減益類型邊框（item.DebuffBorder；長條型可能在 item.Icon 底下）：有害光環才出現、框一圈驅散色，
-- 跟我們的 1px 邊框疊在一起像兩層外框。暴雪只對它 Show／Hide、不碰 alpha ⇒ alpha 0 一直有效；
-- 不 Hide（暴雪下一次 RefreshIconBorder 會再 Show）、不寫它的欄位。設定關掉時還 alpha 1
local function DimDebuffBorder(item, hide)
    local a = hide and 0 or 1
    for _, owner in ipairs({ item, item.Icon }) do
        local b = type(owner) == "table" and owner.DebuffBorder
        if type(b) == "table" and b.SetAlpha then pcall(b.SetAlpha, b, a) end
    end
end

-- 圓角轉圈 → 方角（顏色參數不可省；實際色由 SetSwipeColor 決定）。
-- 不併進 StripBlizzard 的「只做一次」：Masque 套皮會換成它的轉圈材質、群組停用時又換成空材質，
-- 輪到我們畫的時候要再換回來 ⇒ holder.swipeSquare 記著現在是不是我們的
local function SquareSwipe(cd, holder)
    if holder.swipeSquare or not (cd and cd.SetSwipeTexture) then return end
    holder.swipeSquare = true
    pcall(cd.SetSwipeTexture, cd, WHITE, 1, 1, 1, 1)
end

------------------------------------------------------------
-- 後掛勾：暴雪每次刷新都會重寫的屬性
------------------------------------------------------------
local desatGuard = false

------------------------------------------------------------
-- 去飽和的階梯曲線（剩餘 > 0 ⇒ 1，剩 0 ⇒ 0），第一次用到才建，失敗就不用（回 nil）。
-- duration:EvaluateRemainingDuration(曲線) 由引擎求值（秘密值照樣成立），結果餵 Texture:SetDesaturation。
-- 自訂法術（Modules/Custom.lua）與「蓋掉增益那一段」的暴雪格共用這一顆
------------------------------------------------------------
local desatCurve
function D.DesatCurve()
    if desatCurve ~= nil then return desatCurve or nil end
    desatCurve = false
    local CU2 = C_CurveUtil
    if not (CU2 and CU2.CreateCurve) then return nil end
    local ok, c = pcall(CU2.CreateCurve)
    if not ok or not c then return nil end
    local step = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step
    if step and c.SetType then pcall(c.SetType, c, step) end
    local added = pcall(function()
        c:AddPoint(0, 0)
        c:AddPoint(0.05, 1)
        c:AddPoint(86400, 1)
    end)
    if added then desatCurve = c end
    return desatCurve or nil
end

------------------------------------------------------------
-- 增益持續中不顯示持續時間（主題／條 icon.showAuraTime、逐法術 showAuraTime；false ＝ 不顯示）
--
-- 暴雪的 RefreshSpellCooldownInfo 每次刷新：SetSwipeColor → SetDrawSwipe → SetUseAuraDisplayTime(旗標) →
-- CooldownFrame_Set（→ SetCooldown）。增益期間旗標 true、start/duration 是增益的。讓暴雪不用增益做不到
-- （CanUseAuraForDisplay 讀的是暴雪資料表的旗標），所以**蓋掉顯示**：
--   1. SetUseAuraDisplayTime 後掛勾：旗標 true（明文）＋這格設成不顯示＋是法術類 ⇒ rec.auraHidden
--      （倒數換色當冷卻那段：rec.auraTime ＝ false）。
--   2. SetCooldown 後掛勾看到 rec.auraHidden ⇒ FeedRealCooldown：SetUseAuraDisplayTime(false)、引擎給的
--      duration 物件原封轉交 SetCooldownFromDurationObject（有充能在回充：GetSpellChargeDuration＋只畫邊緣；
--      否則 GetSpellCooldownDuration(id, true)＋轉圈）；拿不到物件 ⇒ Clear。就緒探針改走 Glow.ArmProbe
--      （同一個物件；Glow.OnItemSetCooldown 這次不叫——它看到增益旗標會直接走，探針永遠不武裝）。
--      冷卻中去飽和：EvaluateRemainingDuration(階梯曲線) → SetDesaturation。最後照常做尾巴（AfterCooldown）。
--   3. 暴雪下一次刷新又餵增益、我們又蓋一次（幾個 C 呼叫）；增益結束暴雪旗標變 false，正常路徑接手。
--   * SetCooldownFromDurationObject 不是 SetCooldown，不會再進我們的後掛勾（沒有遞迴）；我們自己叫的
--     SetUseAuraDisplayTime／Clear 會進後掛勾 ⇒ overriding 守衛：那兩支看到就走。
--   * 只做法術類（明文 spellID、不是裝備欄項目）；飾品照暴雪顯示增益（明文 GetInventoryItemCooldown 才建得出
--     duration 物件，秘密值時沒輒，留到有人要再說）。
--   * 設定改了（簽章變）：Apply 末尾 SyncAuraHide 照現況重蓋；從「藏」改「顯示」不做事，等暴雪下一次刷新餵回增益。
------------------------------------------------------------
local overriding = false

local function TryDur(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, d = pcall(fn, ...)
    if ok and d then return d end
    return nil
end

-- 這個法術**現在**是不是充能法術（上限 > 1）。
-- ⚠ 暴雪資料的 charges 旗標是「這招可以有充能」：天賦給第二次充能的技能（武器戰的法術反射）沒點天賦時
--   旗標照樣是 true，實際只有一次。拿它去問 GetSpellChargeDuration 會拿到永遠是零的回充 ⇒
--   隱藏 GCD 轉圈把整個冷卻框一直藏著（2026-10-04 玩家回報「就緒發光會亮、倒數完全不顯示」）。
--   所以旗標只是「要不要去問」，問 GetSpellCharges 的 maxCharges 才算數（Modules/Custom.lua 同一套）。
-- 明文讀到就記在 rec 上（天賦一換就會變，每次讀得到都更新）；讀不到（秘密值）用上次記的，從沒讀到過退回旗標。
local function IsChargeSpell(rec, id, flag)
    if not flag then return false end
    local fn = C_Spell and C_Spell.GetSpellCharges
    if not fn then return true end
    local ok, info = pcall(fn, id)
    -- 快取跟著法術走：item 會換身分（SetCooldownID），別拿上一招記的值
    local cached = nil
    if rec.isChargeID == id then cached = rec.isCharge end   -- ⚠ 不寫 a and b or nil：記的是 false 時會變 nil
    if not ok then return cached ~= false end
    if type(info) ~= "table" then                                       -- 不是充能法術：API 回 nil
        rec.isChargeID, rec.isCharge = id, false
        return false
    end
    local okM, m = pcall(function() return info.maxCharges end)
    m = okM and Plain(m) or nil
    if type(m) == "number" then
        rec.isChargeID, rec.isCharge = id, m > 1
        return m > 1
    end
    return cached ~= false
end
D.IsChargeSpell = IsChargeSpell                                     -- 測試用

-- 這一格能不能蓋：法術類 → spellID, 有沒有充能；裝備欄項目／沒有明文法術 ⇒ nil
local function HideTarget(rec)
    local info = rec and ns.Catalog.Info(rec.cooldownID)
    if not info or type(info.equipSlot) == "number" then return nil end
    local id = info.overrideSpellID or info.spellID
    -- 覆蓋法術當下問（英雄天賦的觸發換招：心臟打擊→吸血鬼打擊）：目錄要等覆蓋事件延後重建才跟上，
    -- 這一刻的冷卻要算在現在那一招身上。FindSpellOverrideByID 回明文（EUI 同一招，戰鬥中照用）
    local base = info.spellID
    local find = C_SpellBook and C_SpellBook.FindSpellOverrideByID
    if find and type(base) == "number" then
        local ok, ov = pcall(find, base)
        ov = ok and Plain(ov) or nil
        if type(ov) == "number" and ov > 0 then id = ov end
    end
    if type(id) ~= "number" then return nil end
    return id, IsChargeSpell(rec, id, info.charges)
end
D.HideTarget = HideTarget                                           -- 測試用

-- 充能法術這一刻：走回充那條（還有充能、只畫邊緣）？回充有沒有在跑（full ＝ 明文確認滿了）？
-- 讀不到（秘密值）⇒ 走回充那條、當作在跑（暴雪有充能時也是這樣畫）
local function ChargeState(id)
    local info = C_Spell and C_Spell.GetSpellCharges and TryDur(C_Spell.GetSpellCharges, id)
    if type(info) ~= "table" then return true, false end
    local cur, max = Plain(info.currentCharges), Plain(info.maxCharges)
    if type(cur) ~= "number" then return true, false end
    if cur <= 0 then return false, false end             -- 0 充能：暴雪畫技能冷卻（轉圈）
    return true, type(max) == "number" and cur >= max
end

-- 就緒探針這次要不要武裝：明文確認「沒在冷卻／只是 GCD」就不（零長度的物件會被 clearIfZero 清掉，
-- 卻留著「武裝中」的記號 ⇒ 下一次暴雪 Clear 會被當成轉好）。讀不到 ⇒ 武裝（跟暴雪 item 的正常路徑一樣）
local function ShouldArm(rec, id, chargePath, full)
    if chargePath then return not full end
    local info = C_Spell and C_Spell.GetSpellCooldown and TryDur(C_Spell.GetSpellCooldown, id)
    if type(info) ~= "table" then return true end
    local gcd, active = Plain(info.isOnGCD), Plain(info.isActive)
    if gcd == true or active == false then return false end
    -- 明文確認進了新的冷卻（技能用掉了）⇒ 還亮著的就緒發光收掉（正常路徑在 Glow.OnItemSetCooldown 做，這條路不經過它）
    if gcd == false and active == true and ns.Glow and ns.Glow.CooldownStarted then ns.Glow.CooldownStarted(rec) end
    return true
end

-- 蓋掉的格的去飽和：dur 由引擎求值（秘密值也行）。沒有 dur ／曲線建不出來／求值失敗 ⇒ 不動
local function ApplyHiddenDesat(item, rec)
    local dur = rec.auraDur
    local icon = item.Icon
    if not (dur and dur.EvaluateRemainingDuration and icon and icon.SetDesaturation) then return end
    if rec.style and rec.style.desaturate == false then return end
    local curve = D.DesatCurve()
    if not curve then return end
    local ok, v = pcall(dur.EvaluateRemainingDuration, dur, curve)
    -- 秘密值連跟 nil 比都會拋錯：先問是不是秘密值
    if not ok or not (ns.IsSecret(v) or v ~= nil) then return end
    desatGuard = true
    pcall(icon.SetDesaturation, icon, v)
    desatGuard = false
end

-- 把這格的 Cooldown 改餵技能自己的冷卻（呼叫端確認過 rec.auraHidden）
local function FeedRealCooldown(item, rec, cd)
    local id, charges = HideTarget(rec)
    if not id then return end
    local chargePath, full = false, false
    if charges then chargePath, full = ChargeState(id) end
    local dur, edgeOnly
    -- show：畫在 Cooldown 上的。技能冷卻那條要含 GCD（暴雪正常路徑也畫 GCD；「隱藏 GCD 轉圈」由
    -- AfterCooldown 的 ApplyGCDAlpha 另外管）——曾經只餵 ignoreGCD 的，目標身上一直掛著減益的格
    -- （血魄心臟打擊的緩速）就一直沒有 GCD，2026-10-05。去飽和與就緒探針照舊用不含 GCD 的 dur。
    local show
    if chargePath and C_Spell then
        dur = TryDur(C_Spell.GetSpellChargeDuration, id)
        edgeOnly = dur ~= nil
        show = dur
    end
    if not dur and C_Spell then
        dur = TryDur(C_Spell.GetSpellCooldownDuration, id, true)
        show = TryDur(C_Spell.GetSpellCooldownDuration, id) or dur
        chargePath = false
    end
    overriding = true
    if cd.SetUseAuraDisplayTime then pcall(cd.SetUseAuraDisplayTime, cd, false) end
    local fed = false
    if show and cd.SetCooldownFromDurationObject then
        if edgeOnly then
            if cd.SetDrawSwipe then pcall(cd.SetDrawSwipe, cd, false) end
            if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, true) end
        elseif cd.SetDrawSwipe then
            pcall(cd.SetDrawSwipe, cd, true)
        end
        fed = pcall(cd.SetCooldownFromDurationObject, cd, show, true)
    end
    if not fed then
        dur = nil
        if cd.Clear then pcall(cd.Clear, cd) end
    end
    overriding = false
    -- 去飽和只跟技能冷卻那條（有充能在回充時暴雪也不去飽和）
    rec.auraDur = (dur and not edgeOnly) and dur or nil
    ApplyHiddenDesat(item, rec)
    if dur and ns.Glow and ns.Glow.ArmProbe and ShouldArm(rec, id, chargePath, full) then
        ns.Glow.ArmProbe(rec, dur)
    end
    -- 圖示也不跟增益（D.ApplyHiddenIcon 在自訂圖示那一節）
    D.ApplyHiddenIcon(item, rec)
end

-- 這一格的就緒發光是不是「就緒時一直亮」（Core/Glow.lua）：SetCooldown 與 SPELL_UPDATE_COOLDOWN 都要替它重算
local function ReadyWhileOn(rec)
    local G = ns.Glow
    if not (G and G.ReadyMode and rec.claimKey) then return false end
    return G.ReadyMode(rec.claimKey, rec) == "whileReady"
end

-- SetCooldown 後掛勾的尾巴（正常路徑與蓋掉的那條共用）：轉圈色、邊緣、倒數換色、GCD 轉圈、冷卻狀態
--
-- 去重（效能修整 E2 #9）：只有**倒數色＋formatter**（ns.Text.ApplyPhaseColor）照「上次套的是哪一包樣式
-- （rec.style 的參照）＋哪一段（增益／冷卻）」去重——rec.acStyle／rec.acAura 都沒變就不再寫。
-- 查證（Gethe/wow-ui-source live，Blizzard_CooldownViewer/CooldownViewer.lua、Blizzard_FrameXMLUtil/Cooldown.lua）：
--   * CooldownViewerCooldownItemMixin:RefreshSpellCooldownInfo 每次刷新都 cooldownFrame:SetSwipeColor(…)、
--     CooldownFrame_Set 每次都 SetDrawEdge(forceShowDrawEdge) 再 SetCooldown；增益圖示的 RefreshCooldownInfo 也先
--     SetSwipeColor ⇒ **轉圈色與邊緣暴雪每次都重寫，不能去重**（FeedRealCooldown 自己也會改邊緣），照舊每次蓋
--   * 倒數數字的顏色（GetCountdownFontString:SetTextColor）與 SetCountdownFormatter：整個檢視器沒有一處寫，
--     CooldownFrame_Set／CooldownFrame_SetDisplayAsPercentage 也不碰 ⇒ 可以去重
-- 作廢：D.Apply 換了 rec.style（新表 ⇒ 參照不等；Text.ApplyIcon 會先寫倒數原色）、增益旗標變了（rec.auraTime 變 ⇒
-- 布林不等）、D.Reattach（暴雪取出時的 SetTimerShown 會動倒數數字，保守起見清掉）
local function AfterCooldown(item, rec, cd)
    local st = rec.style
    if not st then return end
    -- 轉圈色：增益那一段用它自己的背景色（換色開著才有 durSwipe）
    local aura = (rec.auraTime or st.allAura) and true or false
    local sw = (aura and st.durSwipe) or st.swipe
    if sw then cd:SetSwipeColor(sw[1], sw[2], sw[3], sw[4]) end
    if type(st.drawEdge) == "boolean" then cd:SetDrawEdge(st.drawEdge) end
    -- 增益持續時間那一段的倒數換色（旗標是剛剛 SetUseAuraDisplayTime 後掛勾記的；蓋掉的格是 false ＝ 原色）
    if st.cdColor and ns.Text and ns.Text.ApplyPhaseColor and (rec.acStyle ~= st or rec.acAura ~= aura) then
        D.afterCooldownWrites = D.afterCooldownWrites + 1
        ns.Text.ApplyPhaseColor(item, rec)
        rec.acStyle, rec.acAura = st, aura
    end
    D.ApplyGCDAlpha(item, rec)
    -- 冷卻狀態：暴雪每次刷新冷卻都會經過這裡（停放中的不碰：停放的 alpha 0 是 Bars 的）
    if (st.cdState or st.dimNoAura) and rec.claimKey and not rec.parked then D.ApplyItemAlpha(item, rec) end
    -- 就緒時一直亮的發光（Core/Glow.lua）：同一個時機重算
    if ns.Glow and ns.Glow.ApplyReadyState and (rec.readyWhile or ReadyWhileOn(rec)) then ns.Glow.ApplyReadyState(rec, item) end
end

-- 旗標（暴雪的明文布林）＋目前設定 → rec.auraHidden／rec.auraTime
local function ResolveAuraFlag(rec)
    local on = rec.auraFlag == true
    local hide = on and rec.style ~= nil and rec.style.hideAuraTime == true and HideTarget(rec) ~= nil
    rec.auraHidden = hide and true or false
    rec.auraTime = on and not hide
    if not hide then rec.auraDur = nil end
end

-- 旗標換成 plain（明文布林、或 nil ＝ 秘密／讀不到）之後的連帶：音效、蓋增益判斷、生效發光、效果不在時變暗
local function SetAuraFlag(item, rec, plain)
    local was = rec.auraFlag
    rec.auraFlag = plain == true              -- 秘密值／讀不到 ⇒ false（不換色、不蓋）
    -- 冷卻格的「增益出現／消失」音效與語音（Core/Sound.lua）：明文才算，它自己去重
    if ns.Sound and ns.Sound.OnAuraFlag then ns.Sound.OnAuraFlag(rec, plain) end
    ResolveAuraFlag(rec)
    -- 冷卻格的「生效期間發光」吃這個旗標（Core/Glow.lua 的 SyncActive）：變了才對帳
    if was ~= rec.auraFlag and ns.Glow and ns.Glow.SyncActive then ns.Glow.SyncActive(item, rec) end
    -- 效果不在時變暗：暴雪接著不一定 SetCooldown（沒冷卻的持續傷害走 Clear），變了就當場套
    local st = rec.style
    if was ~= rec.auraFlag and st and st.dimNoAura and rec.claimKey and not rec.parked then
        D.ApplyItemAlpha(item, rec)
    end
end

-- 暴雪在每次刷新冷卻（SetCooldown 之前）寫「這次顯示的是不是光環時間」：只記下來，換色／蓋掉在 SetCooldown 後掛勾做
-- ⚠ 暴雪的 RefreshSpellCooldownInfo 只在「沒到期」那條路寫這個旗標；到期（光環掉了、技能又沒冷卻）只叫
--   CooldownFrame_Clear、**不會寫 false** ⇒ 旗標會卡在 true（實機：痛苦詛咒掉了、換到沒上的目標還是亮的，
--   2026-10-04）。所以這裡記一筆「這次刷新寫過了」，Clear 後掛勾看沒有這一筆 ⇒ 走的是到期那條 ⇒ 當成 false。
local function OnSetUseAuraDisplayTime(cd, flag)
    if overriding or ns.released then return end      -- 我們自己蓋的那一次（false）不算
    local item = cooldownOwner[cd]
    local rec = item and ns.Viewers.frames[item]
    if not rec then return end
    rec.auraFlagPending = true
    SetAuraFlag(item, rec, Plain(flag))
end
D.OnSetUseAuraDisplayTime = OnSetUseAuraDisplayTime              -- 測試用

local function OnSetCooldown(cd, start, duration, modRate)
    D.setCooldownHooks = D.setCooldownHooks + 1
    if ns.released then return end                  -- 已還給暴雪（Bars.ReleaseAll）
    local item = cooldownOwner[cd]
    local rec = item and ns.Viewers.frames[item]
    if not rec then return end
    rec.auraFlagPending = nil                       -- 這次刷新的旗標已經配到 SetCooldown 了
    if rec.auraHidden and rec.style then
        -- 增益那一段不顯示：改餵技能自己的冷卻（探針在裡面走 ArmProbe）
        FeedRealCooldown(item, rec, cd)
    elseif ns.Glow and ns.Glow.OnItemSetCooldown then
        -- 就緒發光的探針：同一組參數轉交（Core/Glow.lua，不讀不算）
        ns.Glow.OnItemSetCooldown(item, rec, start, duration, modRate, cd)
    end
    AfterCooldown(item, rec, cd)
end
D.OnSetCooldown = OnSetCooldown                                  -- 測試用

-- 設定變了／重新裝飾：照暴雪最後一次的旗標重判；要藏而現在是增益 ⇒ 當場蓋一次（/reload 時增益還在也一樣）。
-- 藏 → 顯示：Cooldown 上是我們餵的冷卻，等暴雪下一次刷新餵回增益（換色旗標由後掛勾補，這之前照原色）
function D.SyncAuraHide(item, rec)
    local cd = item and item.Cooldown
    if not (cd and rec and rec.style) or rec.custom or ns.released then return end
    local was = rec.auraHidden
    ResolveAuraFlag(rec)
    if rec.auraHidden then
        FeedRealCooldown(item, rec, cd)
        AfterCooldown(item, rec, cd)
    elseif was then
        rec.auraTime = false
    end
end

------------------------------------------------------------
-- 隱藏 GCD 轉圈
--
-- 舊做法是在 SetCooldown 後掛勾裡讀 duration、≤1.5 秒就關 swipe：12.1 那個 duration 是秘密值，
-- 讀不到 ⇒ 勾了跟沒勾一樣。改成交給引擎判斷：`C_Spell.GetSpellCooldownDuration(id, true)`
--（ignoreGCD ＝ 真正的冷卻）的 `IsZero()` 是秘密布林，餵 `Cooldown:SetAlphaFromBoolean(zero, 0, 1)`
-- —— 只有 GCD 在轉（真冷卻是零）時整個 Cooldown 框透明（轉圈與倒數字一起），真冷卻一開始就亮回來。
-- 充能法術用 `GetSpellChargeDuration`（有充能時 ignoreGCD 的冷卻永遠是零，會把回充的轉圈也藏掉）。
-- 觸發時機：SetCooldown 後掛勾（暴雪每次刷新）＋ SPELL_UPDATE_COOLDOWN 延一幀補一次。
------------------------------------------------------------
------------------------------------------------------------
-- 裝備欄項目（飾品、武器）：「真的在冷卻」還是只是 GCD
--
-- 暴雪對裝備欄項目的冷卻是這樣取的（CooldownViewer.lua）：法術冷卻那條路遇到 GCD 會跳過
--（ShouldDisplaySpellCooldown：isOnGCD 且有 equipSlot ⇒ 不用），接著退到
-- GetInventoryItemCooldown——而它在 GCD 期間回的就是 GCD 本身，那條路又把 isOnGCD 寫死成 false。
-- 結果：每次 GCD，飾品那一格都被當成「真的在冷卻」⇒ 圖示去飽和、還會閃一下。法術類的格子沒這個問題。
-- 我們在 SetDesaturated 的後掛勾裡重判一次，只有真的在冷卻才留著去飽和。
--
-- 回傳：
--   "plain",  active   讀得到明文：冷卻中而且比 GCD 長（GCD 最長 1.5 秒）
--   "secret", zero     讀到的是秘密值：改問那一格法術的「不含 GCD 的冷卻」是不是零（秘密布林，交給引擎）
--   nil                判不出來（不動）
------------------------------------------------------------
local GCD_MAX = 1.5

-- 「有拿到值」：秘密值算有。⚠ 不能寫 v ~= nil —— 秘密值連跟 nil 比都會拋錯
local function Has(v)
    return ns.IsSecret(v) or v ~= nil
end

local function EquipSlotSpell(info)
    local id = info.overrideSpellID or info.spellID
    if type(id) == "number" then return id end
    -- 冷卻管理器的資料沒帶法術：從那一格裝備的使用效果拿
    if not (GetInventoryItemID and C_Item and C_Item.GetItemSpell) then return nil end
    local ok, itemID = pcall(GetInventoryItemID, "player", info.equipSlot)
    itemID = ok and Plain(itemID) or nil
    if type(itemID) ~= "number" then return nil end
    local ok2, _, spellID = pcall(C_Item.GetItemSpell, itemID)
    spellID = ok2 and Plain(spellID) or nil
    return type(spellID) == "number" and spellID or nil
end

local function EquipRealCooldown(info)
    if not (info and type(info.equipSlot) == "number") then return nil end
    if GetInventoryItemCooldown then
        local ok, start, duration, enable = pcall(GetInventoryItemCooldown, "player", info.equipSlot)
        if ok and not (ns.IsSecret(start) or ns.IsSecret(duration) or ns.IsSecret(enable))
            and type(start) == "number" and type(duration) == "number" then
            local enabled = enable ~= 0 and enable ~= false
            local now = GetTime and GetTime() or 0
            return "plain", (enabled and duration > GCD_MAX and start + duration > now) and true or false
        end
    end
    local spellID = EquipSlotSpell(info)
    if spellID and C_Spell and C_Spell.GetSpellCooldownDuration then
        local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
        if ok and dur and dur.IsZero then
            local ok2, zero = pcall(dur.IsZero, dur)
            if ok2 and Has(zero) then return "secret", zero end
        end
    end
    return nil
end
D.EquipRealCooldown = EquipRealCooldown

function D.ApplyGCDAlpha(item, rec)
    local cd = item and item.Cooldown
    if not cd then return end
    local st = rec.style
    -- 自訂框（含代畫的裝備欄冷卻格）自己就不餵 GCD（法術 ignoreGCD、物品／飾品欄只收比 GCD 長的冷卻），
    -- 而且沒有 SetCooldown 後掛勾會回來重算：這裡只在 Apply 時算一次的話，當下沒在冷卻 ⇒ 轉圈 alpha 0 一直留著，
    -- 之後真的進冷卻也看不到。代畫格的 cooldownID 是暴雪的數字 id（Info 有 equipSlot），一定會走進下面那條
    if not (st and st.hideGCD) or rec.custom then
        if rec.gcdAlpha then
            rec.gcdAlpha = nil
            pcall(cd.SetAlpha, cd, 1)
        end
        return
    end
    local info = ns.Catalog.Info(rec.cooldownID)
    -- 裝備欄項目：GCD 期間暴雪拿 GCD 當它的冷卻在轉，同一套判法
    if info and type(info.equipSlot) == "number" then
        local kind, v = EquipRealCooldown(info)
        if kind == "plain" then
            pcall(cd.SetAlpha, cd, v and 1 or 0)
            rec.gcdAlpha = true
        elseif kind == "secret" and cd.SetAlphaFromBoolean then
            pcall(cd.SetAlphaFromBoolean, cd, v, 0, 1)
            rec.gcdAlpha = true
        end
        return
    end
    local spellID = info and (info.overrideSpellID or info.spellID)
    if type(spellID) ~= "number" or not (C_Spell and C_Spell.GetSpellCooldownDuration) then return end
    local dur
    if IsChargeSpell(rec, spellID, info.charges) and C_Spell.GetSpellChargeDuration then
        local ok, d = pcall(C_Spell.GetSpellChargeDuration, spellID)
        if ok then dur = d end
    end
    if not dur then
        local ok, d = pcall(C_Spell.GetSpellCooldownDuration, spellID, true)
        if ok then dur = d end
    end
    if not (dur and dur.IsZero) then return end
    local ok, zero = pcall(dur.IsZero, dur)
    if not ok or not Has(zero) then return end
    if cd.SetAlphaFromBoolean then
        pcall(cd.SetAlphaFromBoolean, cd, zero, 0, 1)
    elseif not ns.IsSecret(zero) then
        cd:SetAlpha(zero and 0 or 1)
    end
    rec.gcdAlpha = true
end

------------------------------------------------------------
-- 冷卻狀態效果（cdState）：冷卻中變暗／冷卻中隱藏／轉好時隱藏
--
--   ns.Decorate.StateAlphas(mode, x, barAlpha)     純函式 → A_cd, A_ready（模式不適用回 nil）
--   ns.Decorate.PreviewStateAlpha(mode, x, onCD)   純函式：設定頁預覽格的 alpha（兩種隱藏畫成 0.25）
--   ns.Decorate.CooldownState(item, rec)           → "plain", onCD | "secret", zero | nil
--   ns.Decorate.ApplyItemAlpha(item, rec, barAlpha) 暴雪 item 的 alpha **唯一出口**（Bars 放格／Reapply、
--                                                   Visibility.Apply、SetCooldown 後掛勾、就緒探針都走這支）
--   ns.Decorate.RefreshState(rec)                  就緒探針觸發（轉好的那一刻）：照現況重算一次，0.1 秒後再一次
--
-- 隱藏的格照樣佔位（只動 alpha，不 Hide、不重排）。GCD 不算冷卻；充能法術還有充能＝不算冷卻中
-- （GetSpellCooldown 的 isActive、ignoreGCD 的 duration 在有充能時都是「沒在冷卻」）。
-- 增益類（暴雪增益兩條、長條、光環格）不適用：rec.style.cdState 一律 nil。編輯模式中全亮。
-- 秘密值：讀不到明文旗標就拿引擎的「不含 GCD 的冷卻是零」秘密布林餵 SetAlphaFromBoolean，
-- 之後**不讀回**那顆框的 alpha（rec.alphaSecret 記著，/mcdm debug 直接印「秘密」）。
--
-- 效果不在時變暗（逐法術勾選 dimNoAura，預設不勾；玩家要求：術士的持續傷害，目前目標身上沒有就變暗）：
-- 跟冷卻狀態是兩回事、可以同時開——它只把「條的 alpha」再乘上變暗透明度（cdStateAlpha），其餘照冷卻狀態算。
-- 訊號是暴雪這一格是不是正在倒光環時間（rec.auraFlag，SetUseAuraDisplayTime 後掛勾記的明文）。
-- 放在核心／輔助的持續傷害，暴雪倒的就是目前目標身上那個減益；換目標由暴雪自己重刷（射程檢查的格、
-- 光環在目標身上的格都登記了換目標更新）。沒有目標＝沒有光環＝變暗。旗標變了在後掛勾裡當場重套。
-- 只有暴雪的冷卻格有這個訊號：自訂項目、長條、增益類一律不給（rec.style.dimNoAura ＝ nil）。
------------------------------------------------------------
local CD_MODES = { dim = true, hideOnCD = true, hideReady = true }
D.CD_MODES = CD_MODES
local PREVIEW_HIDDEN = 0.25          -- 預覽裡「看不到」畫成這麼淡（完全看不到就點不到了）

local function ClampAlpha(x, default)
    x = tonumber(x) or default
    if x < 0 then x = 0 elseif x > 1 then x = 1 end
    return x
end

-- 適用的模式（none／未知值 ＝ nil）
local function StateMode(v)
    return CD_MODES[v] and v or nil
end
D.StateMode = StateMode

function D.StateAlphas(mode, x, barAlpha)
    barAlpha = tonumber(barAlpha) or 1
    if mode == "dim" then
        return barAlpha * ClampAlpha(x, 0.4), barAlpha
    elseif mode == "hideOnCD" then
        return 0, barAlpha
    elseif mode == "hideReady" then
        return barAlpha, 0
    end
    return nil
end

function D.PreviewStateAlpha(mode, x, onCD)
    if mode == "dim" then return onCD and ClampAlpha(x, 0.4) or 1 end
    if mode == "hideOnCD" then return onCD and PREVIEW_HIDDEN or 1 end
    if mode == "hideReady" then return onCD and 1 or PREVIEW_HIDDEN end
    return 1
end

function D.CooldownState(item, rec)
    local info = rec and ns.Catalog.Info(rec.cooldownID)
    if not info then return nil end
    -- 1. 裝備欄項目：GCD 期間暴雪拿 GCD 當它的冷卻，用同一套判法
    if type(info.equipSlot) == "number" then return EquipRealCooldown(info) end
    local id = info.overrideSpellID or info.spellID
    if type(id) == "number" and C_Spell then
        -- 2. 明文旗標（兩個都讀得到才算）
        if C_Spell.GetSpellCooldown then
            local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
            if ok and type(cd) == "table" then
                local active, gcd = Plain(cd.isActive), Plain(cd.isOnGCD)
                if type(active) == "boolean" and type(gcd) == "boolean" then
                    return "plain", (active and not gcd) and true or false
                end
            end
        end
        -- 3. 讀不到：引擎的「不含 GCD 的冷卻是零」（可能是秘密布林）
        if C_Spell.GetSpellCooldownDuration then
            local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, id, true)
            if ok and dur and dur.IsZero then
                local ok2, zero = pcall(dur.IsZero, dur)
                if ok2 and Has(zero) then
                    if not ns.IsSecret(zero) and type(zero) == "boolean" then return "plain", not zero end
                    return "secret", zero
                end
            end
        end
        return nil
    end
    -- 4. 沒有法術的類別項目（藥水那種）：暴雪自己的明文欄位（只讀）
    local v = item and Plain(rawget(item, "isOnActualCooldown"))
    if type(v) == "boolean" then return "plain", v end
    return nil
end

local function EditModeActive()
    return ns.EditMode and ns.EditMode.active or false
end

local function CurrentBarAlpha(key)
    local V = ns.Visibility
    if not (V and key) then return 1 end
    local a = V.Current and V.Current(key)
    if a == nil and V.Alpha then a = V.Alpha(key) end
    return tonumber(a) or 1
end

function D.ApplyItemAlpha(item, rec, barAlpha)
    if not item or ns.released then return end
    if barAlpha == nil then barAlpha = CurrentBarAlpha(rec and rec.claimKey) end
    local st = rec and rec.style
    local mode = st and st.cdState
    -- 效果不在時變暗：條的 alpha 先乘上去，下面冷卻狀態照常算（編輯模式中全亮）
    if st and st.dimNoAura and rec.auraFlag ~= true and not EditModeActive() then
        barAlpha = barAlpha * st.cdAlpha
    end
    if not mode or EditModeActive() then
        item:SetAlpha(barAlpha)
        if rec then rec.stateHidden = nil end
        return
    end
    local aCD, aReady = D.StateAlphas(mode, st.cdAlpha, barAlpha)
    local kind, v = D.CooldownState(item, rec)
    if kind == "plain" then
        local a = v and aCD or aReady
        item:SetAlpha(a)
        rec.stateHidden = (a == 0)
    elseif kind == "secret" and item.SetAlphaFromBoolean
        and pcall(item.SetAlphaFromBoolean, item, v, aReady, aCD) then
        -- v ＝「不含 GCD 的冷卻是零」：真 ⇒ 轉好的 alpha
        rec.stateHidden = nil            -- 不知道藏了沒（提示照舊）
        rec.alphaSecret = true
    else
        item:SetAlpha(barAlpha)
        rec.stateHidden = nil
    end
end

-- rec → 暴雪 item（就緒探針只拿得到 rec）。弱鍵弱值：item 是池化的框，rec 是 Viewers 的弱鍵表裡的值
local itemOf = setmetatable({}, { __mode = "kv" })
function D.ItemOf(rec) return rec and itemOf[rec] end

function D.RefreshState(rec, noRetry)
    if not rec or ns.released then return end
    if not (rec.style and rec.style.cdState) then return end
    if rec.custom then
        if ns.Custom and ns.Custom.RefreshState then ns.Custom.RefreshState(rec) end
    else
        local item = itemOf[rec]
        if item and ns.Viewers.frames[item] == rec and rec.claimKey and not rec.parked then
            D.ApplyItemAlpha(item, rec)
        end
    end
    -- 探針與本尊的到期可能差幾毫秒（那一刻引擎可能還說在冷卻）：過一下再對一次
    if not noRetry and C_Timer then
        C_Timer.After(0.1, function() D.RefreshState(rec, true) end)
    end
end

------------------------------------------------------------
-- SPELL_UPDATE_COOLDOWN 很密：事件處理器在 Core/SpellIndex.lua（分類一次、合併、延一幀），這裡是暴雪 item 那個消費者。
-- 事件帶明文 spellID 而且索引查得到 ⇒ 只跑那幾格；讀不懂（nil／秘密／帶 category 等）⇒ 全掃。
--
-- 全掃只走 D.cdWork（效能修整 E3 #8）：弱鍵表 rec → item，收「認領中、沒停放、而且開了隱藏 GCD／冷卻狀態／
-- 就緒時一直亮」的暴雪 item（自訂框不收，它們歸 Custom 那個消費者）。以前全掃走過每條的每顆 item、每顆再問一次
-- ReadyWhileOn（SpellSetting）。維護點（寫入出口）：
--   * D.Apply 結尾（三條出路都經過 CdWorkSync）：簽章命中與完整套用時重算 rec.cdNeed／rec.cdReady
--     （樣式快取 rec.style 只在完整套用時換；ReadyMode 吃的設定變了一律經過 InvalidateAll ⇒ 前置鍵不中 ⇒ 會重算）；
--     前置鍵命中時輸入全等、只重新判「認領中、沒停放」（停放後重新放格會走這條）
--   * Glow.OnParked（停放、還給暴雪）：移除
--   * Glow.ApplyReadyState 翻 rec.readyWhile（兩個方向）：重判
-- 迴圈裡照舊檢查 frames[item] == rec、認領中、沒停放（漏掉的作廢點最多多跑一格，不會跑錯格）。
-- cdWork 空了（而且 Custom 也沒事做）⇒ 事件處理器連分類與 Defer 都不排（SI.Subscribe 的 wants）。
------------------------------------------------------------
local SI = ns.SpellIndex
local cdWork = setmetatable({}, { __mode = "k" })
D.cdWork = cdWork

local function NeedsWork(rec)
    local st = rec.style
    return (st and (st.hideGCD or st.cdState or st.dimNoAura)) or rec.readyWhile or ReadyWhileOn(rec) or false
end

-- D.Apply 算一次存在 rec 上（rec.readyWhile 不在這裡：它由 Glow 翻、翻的時候自己叫 CdWorkSync）
local function CdNeedStore(rec)
    local st = rec.style
    rec.cdReady = ReadyWhileOn(rec) and true or false
    rec.cdNeed = ((st and (st.hideGCD or st.cdState)) and true or false) or rec.cdReady
end

-- 照 rec 現在的狀態加入／移除。item 沒給 ⇒ 用 Apply 記下的 itemOf，再沒有用表裡原本的
function D.CdWorkSync(rec, item)
    if not rec or rec.custom then return end
    item = item or itemOf[rec] or cdWork[rec]
    if item and rec.claimKey and not rec.parked and (rec.cdNeed or rec.readyWhile) then
        cdWork[rec] = item
    else
        cdWork[rec] = nil
    end
end

-- rw：要不要重算就緒時一直亮。nil ＝ 照舊現問（精準那條）；全掃傳 Apply 存的 rec.cdReady（不再每格問設定）
local function RefreshOne(item, rec, rw)
    local st = rec.style
    if st and st.hideGCD then D.ApplyGCDAlpha(item, rec) end
    if st and (st.cdState or st.dimNoAura) then D.ApplyItemAlpha(item, rec) end
    if rw == nil then rw = ReadyWhileOn(rec) end
    if ns.Glow and ns.Glow.ApplyReadyState and (rec.readyWhile or rw) then ns.Glow.ApplyReadyState(rec, item) end
end

local function Valid(item, rec)
    return rec and not rec.custom and ns.Viewers.frames[item] == rec and rec.claimKey and not rec.parked
end

-- 全掃先把 cdWork 抄進暫存陣列（迴圈裡 ApplyReadyState 可能翻 readyWhile ⇒ 改到 cdWork）
local scratchI, scratchR = {}, {}
local doneRec = {}

local function OnCooldownBatch(all, entries, gcd)
    if not (ns.Bars and ns.profile) or ns.released then return end
    if all then
        local n = 0
        for rec, item in pairs(cdWork) do
            n = n + 1
            scratchI[n], scratchR[n] = item, rec
        end
        for i = 1, n do
            local item, rec = scratchI[i], scratchR[i]
            scratchI[i], scratchR[i] = nil, nil
            if Valid(item, rec) then RefreshOne(item, rec, rec.cdReady) end
        end
        return
    end
    for e in pairs(entries) do
        local item, rec = e.owner, e.rec
        if Valid(item, rec) and NeedsWork(rec) then
            RefreshOne(item, rec)
            if gcd then doneRec[rec] = true end
        end
    end
    -- GCD 開始（SI.GCD_PRECISE）：沒命中的格只重算 GCD 轉圈（GCD 不影響冷卻狀態與就緒時一直亮；
    -- 萬一施放順便動了別格的冷卻，暴雪 GCD 時對每一格的 SetCooldown 會經過 AfterCooldown 補算那兩樣）
    if gcd then
        for rec, item in pairs(cdWork) do
            local st = rec.style
            if st and st.hideGCD and not doneRec[rec] and Valid(item, rec) then D.ApplyGCDAlpha(item, rec) end
        end
        for rec in pairs(doneRec) do doneRec[rec] = nil end
    end
end
D.OnCooldownBatch = OnCooldownBatch                              -- 測試用
D.RefreshCooldownAll = function() OnCooldownBatch(true, SI.EMPTY, false) end

SI.Subscribe(OnCooldownBatch, function() return next(cdWork) ~= nil end)

local function OnClearCooldown(cd)
    -- 我們自己清的（蓋掉增益那一段、技能拿不到冷卻物件）：不是暴雪說「轉好了」，alpha 由 AfterCooldown 重算
    if overriding then return end
    local item = cooldownOwner[cd]
    local rec = item and ns.Viewers.frames[item]
    if not rec then return end
    -- 前面沒寫旗標就清 ＝ 暴雪走「到期」那條：什麼都沒在倒 ⇒ 增益時間的旗標歸零（見 OnSetUseAuraDisplayTime）。
    -- 剛寫過旗標接著清（CooldownFrame_Set 拿到零長度）＝ 同一次刷新，旗標照暴雪剛寫的
    if rec.auraFlagPending then
        rec.auraFlagPending = nil
    elseif rec.auraFlag and not ns.released then
        SetAuraFlag(item, rec, false)
    end
    if ns.Glow and ns.Glow.OnItemClear then ns.Glow.OnItemClear(item, rec) end
end

local function OnSetDesaturated(icon, desaturated)
    if desatGuard or ns.released then return end
    local item = iconOwner[icon]
    local rec = item and ns.Viewers.frames[item]
    if not (rec and rec.style) then return end
    if rec.style.desaturate == false then
        desatGuard = true
        icon:SetDesaturated(false)
        desatGuard = false
        return
    end
    -- 增益那一段被蓋掉的格：暴雪增益期間寫 false（不去飽和），照我們餵的冷卻重算（傳進來的值不比較）。
    -- 沒有冷卻物件（技能沒在冷卻／有充能在回充）⇒ 不動，暴雪的就是對的
    if rec.auraHidden then
        ApplyHiddenDesat(item, rec)
        return
    end
    -- 只管裝備欄項目（先判這個：法術類的格子到這裡就走了，不碰傳進來的值）
    local info = ns.Catalog.Info(rec.cooldownID)
    if not (info and type(info.equipSlot) == "number") then return end
    -- 暴雪剛把它設成去飽和：重判一次，只是 GCD 的話還原。
    -- ⚠ 傳進來的值戰鬥中是秘密布林，**不能拿來比較**（比了就拋錯）；讀不到就當作「可能是去飽和」照樣重判
    if not ns.IsSecret(desaturated) and desaturated == false then return end
    local kind, v = EquipRealCooldown(info)
    if kind == "plain" then
        if not v then
            desatGuard = true
            icon:SetDesaturated(false)
            desatGuard = false
        end
    elseif kind == "secret" then
        -- v ＝「不含 GCD 的冷卻是零」的秘密布林：零 ⇒ 不去飽和（0）、不是零 ⇒ 去飽和（1）
        local eval = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
        if eval and icon.SetDesaturation then
            local ok, amount = pcall(eval, v, 0, 1)
            if ok and Has(amount) then
                desatGuard = true
                pcall(icon.SetDesaturation, icon, amount)
                desatGuard = false
            end
        end
    end
end

------------------------------------------------------------
-- 自訂圖示：暴雪 item 的 Icon 貼圖（長條是 item.Icon.Icon）
--
-- 暴雪每次 RefreshData 都會 RefreshSpellTexture → Icon:SetTexture(它的圖)：後掛勾蓋回我們的。
--   * 掛勾只在**第一次需要覆寫**時才掛（沒人用這個功能的格完全不掛）；沒有覆寫的格進掛勾第一件事就走。
--   * 傳進來的貼圖參數不看（光環的圖可能是秘密值）。
--   * SetCooldownID 會同步 RefreshData、**比我們的 SetCooldownID 後掛勾先跑** ⇒ 掛勾裡用 item 現在的身分
--     （Viewers.ReadItemID，pcall getter）對 rec.iconFor：不一樣＝覆寫是上一個法術的，清掉、交回 Apply 重判。
--   * 拿掉覆寫：用目錄的圖示（明文）換回去；暴雪下一次刷新本來也會寫回它自己的。
------------------------------------------------------------
local iconGuard = false
local iconTexOwner = setmetatable({}, { __mode = "k" })   -- 圖示貼圖 → item

local function OnIconSetTexture(tex)
    if iconGuard or ns.released then return end
    local item = iconTexOwner[tex]
    local rec = item and ns.Viewers.frames[item]
    local want = rec and rec.iconOverride
    if not want then
        if rec and rec.auraHidden then D.ApplyHiddenIcon(item, rec, tex) end
        return
    end
    local V = ns.Viewers
    local now = V.ReadItemID and V.ReadItemID(item)
    if now ~= rec.iconFor then
        rec.iconOverride, rec.iconFor = nil, nil
        return
    end
    iconGuard = true
    pcall(tex.SetTexture, tex, want)
    iconGuard = false
end

local function IconTexture(item, isBar)
    local t = item.Icon
    if isBar then t = type(t) == "table" and t.Icon or nil end
    if type(t) ~= "table" or type(t.SetTexture) ~= "function" then return nil end
    local ok, kind = pcall(t.GetObjectType, t)
    if not ok or kind ~= "Texture" then return nil end
    return t
end

local function ApplyIconOverride(item, rec, id, isBar, want)
    if not want and not rec.iconOverride then return end      -- 沒設、也沒換過：什麼都不碰
    local tex = IconTexture(item, isBar)
    if not tex then return end
    if want then
        if not iconTexOwner[tex] then
            iconTexOwner[tex] = item
            hooksecurefunc(tex, "SetTexture", ns.Guard(OnIconSetTexture))
        end
        rec.iconOverride, rec.iconFor = want, id
        iconGuard = true
        pcall(tex.SetTexture, tex, want)
        iconGuard = false
        return
    end
    rec.iconOverride, rec.iconFor = nil, nil
    local info = ns.Catalog.Info(id)
    local orig = info and Plain(info.icon)
    if orig then
        iconGuard = true
        pcall(tex.SetTexture, tex, orig)
        iconGuard = false
    end
end
D.ApplyIconOverride = ApplyIconOverride                             -- 測試用

------------------------------------------------------------
-- 增益時間不顯示的格（rec.auraHidden）：圖示也跟著法術走，不跟增益
--
-- 暴雪 GetSpellTexture 在 PreferAuraDataOverSpellData 成立時直接回光環的圖示；主動施放的冷卻格只要
-- 目標身上有它追蹤的減益就成立 ⇒ 減益期間圖示鎖成減益圖，覆蓋法術完全不看（血魄心臟打擊的緩速掛著，
-- 薩萊因觸發吸血鬼打擊也不換圖，2026-10-05 NGA 回報；暴雪內建一樣）。
-- 玩家把增益時間關掉＝不要追蹤這個光環，圖示改走暴雪「沒有光環」那條：overrideTooltipSpellID 優先、
-- 否則基本法術，交給 C_Spell.GetSpellTexture（它自己套覆蓋），有動態圖示用動態那個。
--   * 時機：暴雪 RefreshData 是先冷卻（SetUseAuraDisplayTime → 我們判 auraHidden）再 RefreshSpellTexture
--     ⇒ 同一次刷新 SetTexture 後掛勾就讀得到新的 auraHidden；觸發換招走 SPELL_UPDATE_ICON 也只叫
--     RefreshSpellTexture，一樣進後掛勾。FeedRealCooldown 每次也補蓋一次（設定切換的 SyncAuraHide 路徑）。
--   * 自訂圖示優先；身分對不上（SetCooldownID 剛換、rec 還是舊的）不動。
--   * 回傳值可能是秘密值：不比對、原樣交給 SetTexture。
--   * 藏 → 顯示：不還原，暴雪下一次刷新會寫回它自己的。
------------------------------------------------------------
function D.ApplyHiddenIcon(item, rec, tex)
    if rec.iconOverride or rec.custom or ns.released then return end
    if not (C_Spell and C_Spell.GetSpellTexture) then return end
    if ns.Viewers.ReadItemID(item) ~= rec.cooldownID then return end
    local info = ns.Catalog.Info(rec.cooldownID)
    local sid = info and (info.overrideTooltipSpellID or info.spellID)
    if type(sid) ~= "number" then return end
    tex = tex or IconTexture(item, rec.style ~= nil and rec.style.kind == "bars" and item.Bar ~= nil)
    if not tex then return end
    if not iconTexOwner[tex] then
        iconTexOwner[tex] = item
        hooksecurefunc(tex, "SetTexture", ns.Guard(OnIconSetTexture))
    end
    local ok, icon, _, cond = pcall(C_Spell.GetSpellTexture, sid)
    if not ok then return end
    -- 秘密值連跟 nil 比都會拋錯：先問是不是秘密值
    if ns.IsSecret(cond) or cond ~= nil then icon = cond end
    if not ns.IsSecret(icon) and icon == nil then return end
    iconGuard = true
    pcall(tex.SetTexture, tex, icon)
    iconGuard = false
end
D.IconTextureOwner = function(tex) return iconTexOwner[tex] end     -- 測試用

-- 暴雪換長條內容（僅圖示／僅名字）時會藏名字、重錨條：把名字 Show 回來（名字要一直
-- 顯示暴雪才會寫字），版面照我們的重排
local function OnSetBarContent(item)
    if ns.released then return end
    local rec = ns.Viewers.frames[item]
    if not rec then return end
    local name = item.Bar and item.Bar.Name
    if name and not name:IsShown() then name:Show() end
    if rec.barGeometry then D.ApplyBarGeometry(item, rec, rec.barGeometry) end
end

-- 長條名字：暴雪寫進 nil／空字串時用法術名字頂
--   名字是暴雪在 RefreshName 寫的（我們只管樣式，見 Text.ApplyBar），召喚類（惡魔暴君這種）
--   第一次 PLAYER_TOTEM_UPDATE 時 GetTotemInfo 還沒有單位名字 ⇒ 寫進去的是 nil，而暴雪之後
--   不一定再叫一次 RefreshName（只有下一次 RefreshData 會）⇒ 整條空到消失。
--   秘密字串不碰（拿著不讀）；真名之後寫進來就自然蓋掉。只讀 Catalog 的明文資料，不碰 totemData。
--   法術 id 先問 item 自己的 GetSpellID（暴雪會把 linkedSpell／光環的 id 算進去，跟它寫名字用的是同一個），
--   讀不到明文再退 Catalog。每次處理都記一行 diag（去重），實機不對時 /mcdm debug 看得到。
local nameGuard = false
-- 秘密字串那一支的 diag 只記一次（Diag.Note 自己會合併同字，但每次仍要 date()＋組字串）；進場清掉、下一輪再記一次
local notedSecret = {}
ns.Events.Register("PLAYER_ENTERING_WORLD", "decorate_barname", function() notedSecret = {} end)
local function BarItemSpellID(item, rec)
    local get = item.GetSpellID
    if type(get) == "function" then
        local ok, v = pcall(get, item)
        v = ok and Plain(v) or nil
        if type(v) == "number" then return v end
    end
    local info = ns.Catalog.Info(rec.cooldownID)
    local id = info and (info.overrideSpellID or info.spellID)
    return type(id) == "number" and id or nil
end

local function OnBarNameSetText(fs, text)
    if nameGuard or ns.released then return end
    local item = nameOwner[fs]
    local rec = item and ns.Viewers.frames[item]
    if not rec or rec.custom then return end
    local Note = ns.Diag and ns.Diag.Note
    if ns.IsSecret(text) then                           -- ⚠ 秘密值連跟 nil 比都會拋錯，先擋
        local cid = rec.cooldownID
        if Note and cid ~= nil and not notedSecret[cid] then
            notedSecret[cid] = true
            Note("barname", tostring(cid) .. " 秘密字串（留著）")
        elseif Note and cid == nil then
            Note("barname", "nil 秘密字串（留著）")
        end
        return
    end
    if text ~= nil and text ~= "" then return end
    local spellID = BarItemSpellID(item, rec)
    local name
    if spellID then
        local ok, v = pcall(C_Spell.GetSpellName, spellID)
        v = ok and Plain(v) or nil
        if type(v) == "string" and v ~= "" then name = v end
    end
    if Note then
        Note("barname", string.format("%s %s → %s", tostring(rec.cooldownID), text == nil and "nil" or "空字串",
            name and ("法術名 " .. name) or ("沒退路（spellID " .. tostring(spellID) .. "）")))
    end
    if not name then return end
    nameGuard = true
    pcall(fs.SetText, fs, name)
    nameGuard = false
end

function D.HookItem(item, rec)
    if rec.decoHooked then return end
    rec.decoHooked = true
    local cd = item.Cooldown
    if cd and cd.SetCooldown and not rec.custom then
        cooldownOwner[cd] = item
        hooksecurefunc(cd, "SetCooldown", ns.Guard(OnSetCooldown))
        if cd.Clear then hooksecurefunc(cd, "Clear", ns.Guard(OnClearCooldown)) end
        if cd.SetUseAuraDisplayTime then
            hooksecurefunc(cd, "SetUseAuraDisplayTime", ns.Guard(OnSetUseAuraDisplayTime))
            -- 掛上的當下可能正在增益那一段（/reload 時增益還在）：先問一次 C 端 getter（只讀、pcall），
            -- 不然要等暴雪下一次刷新才知道
            if cd.GetUseAuraDisplayTime then
                local ok, v = pcall(cd.GetUseAuraDisplayTime, cd)
                rec.auraFlag = ok and Plain(v) == true or false
                -- 音效的初值（只記不響：/reload 時增益還在不該響）
                if ok and ns.Sound and ns.Sound.OnAuraFlag then ns.Sound.OnAuraFlag(rec, Plain(v)) end
                -- 要不要蓋在 Apply 末尾（SyncAuraHide）判：第一次掛上時 rec.style 還沒寫
                ResolveAuraFlag(rec)
            end
        end
    end
    -- 無損刷新（ShowPandemicStateFrame／Hide…）的後掛勾在 Glow
    if not rec.custom and ns.Glow and ns.Glow.HookItem then ns.Glow.HookItem(item, rec) end
    -- 層數門檻（增益 item 的 RefreshApplications／OnActiveStateChanged 後掛勾）在 Core/StackGate.lua
    if not rec.custom and ns.StackGate and ns.StackGate.HookItem then ns.StackGate.HookItem(item, rec) end
    local icon = item.Icon
    if not rec.custom and icon and icon.SetDesaturated and icon.GetObjectType and icon:GetObjectType() == "Texture" then
        iconOwner[icon] = item
        hooksecurefunc(icon, "SetDesaturated", ns.Guard(OnSetDesaturated))
    end
    if item.SetBarContent then
        hooksecurefunc(item, "SetBarContent", ns.Guard(OnSetBarContent))
    end
    -- 增益生效／失效的重排訊號在 Core/Viewers.lua 的 HookItem（每顆 item 都掛 OnActiveStateChanged）；
    -- 這裡以前另掛一份做同一件事，重複了（2026-10-04 拿掉）
    local nameFS = not rec.custom and item.Bar and item.Bar.Name
    if nameFS and type(nameFS.SetText) == "function" then
        nameOwner[nameFS] = item
        hooksecurefunc(nameFS, "SetText", ns.Guard(OnBarNameSetText))
    end
end

------------------------------------------------------------
-- 長條的版面：圖示邊、條身、底色、材質
------------------------------------------------------------
-- 暴雪條的火花（Pip）：暴雪只在 OnLoad 錨一次（CENTER → 填充貼圖的 RIGHT, 0, -1），之後不再動。
-- 直向時改錨填充的頂緣、轉 90 度；切回橫向時照暴雪原本的錨回去。動過的記在弱鍵表（不寫暴雪的欄位）
local turnedPip = setmetatable({}, { __mode = "k" })
local function OrientBlizzPip(b, vertical)
    local pip = b.Pip
    if not pip or b.ownPip then return end
    if not vertical and not turnedPip[pip] then return end
    local ok, fill = pcall(b.GetStatusBarTexture, b)
    if not ok or not fill then return end
    pip:ClearAllPoints()
    if vertical then
        pip:SetPoint("CENTER", fill, "TOP", 0, 0)
        if pip.SetRotation then pcall(pip.SetRotation, pip, math.pi / 2) end
        turnedPip[pip] = true
    else
        pip:SetPoint("CENTER", fill, "RIGHT", 0, -1)
        if pip.SetRotation then pcall(pip.SetRotation, pip, 0) end
        turnedPip[pip] = nil
    end
end

-- g = { h, w, side, gap, vertical }：格子尺寸由排版給（不讀框）。
-- 直向（F8c）：圖示 w×w（w ＝ 條的粗細），side 的 LEFT／RIGHT 當上／下；條身 SetOrientation("VERTICAL")
function D.ApplyBarGeometry(item, rec, g)
    local icon, b = item.Icon, item.Bar
    if not (icon and b) then return end
    local h = g.h
    local gap = ns.Layout.Snap(g.gap or 0)
    if b.SetOrientation then b:SetOrientation(g.vertical and "VERTICAL" or "HORIZONTAL") end
    OrientBlizzPip(b, g.vertical)
    icon:ClearAllPoints()
    b:ClearAllPoints()
    if g.vertical then
        local s = g.w or h
        icon:SetSize(s, s)
        if g.side == "RIGHT" then
            icon:SetPoint("BOTTOM", item, "BOTTOM", 0, 0)
            b:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
            b:SetPoint("BOTTOMRIGHT", icon, "TOPRIGHT", 0, gap)
        elseif g.side == "NONE" then
            icon:SetPoint("TOP", item, "TOP", 0, 0)
            b:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
            b:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
        else
            icon:SetPoint("TOP", item, "TOP", 0, 0)
            b:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -gap)
            b:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
        end
    else
        icon:SetSize(h, h)
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
    end
    if g.side == "NONE" then
        icon:SetAlpha(0)
    else
        icon:SetAlpha(1)
        if not icon:IsShown() then icon:Show() end     -- 暴雪「僅名字」會藏它；我們的設定優先
    end
end

------------------------------------------------------------
-- 漸層填充（bar.gradient，F8a）
--   bar.gradient = false | { color2 = rgba, dir = "H" | "V" }
--   起點（橫向的左、直向的下）是 bar.color、終點是 color2；SetGradient 套在**填充貼圖**上，
--   所以漸層跨的是「已填的那一截」（條縮短時兩端顏色都在，跟條身寬無關）。
--
-- SetVertexColor 與 SetGradient 的關係（共用頂點色、後寫的贏，或是兩者相乘）沒查證 ⇒ 兩種模型都對的寫法：
--   開漸層：先 SetVertexColor 白、再 SetGradient（共用 ⇒ 漸層贏；相乘 ⇒ 白 × 漸層）
--   關／單色：畫過漸層的貼圖先 SetGradient 白→白、再 SetVertexColor（共用 ⇒ 單色贏；相乘 ⇒ 白 × 單色）
-- 畫過漸層的貼圖記在弱鍵表（只是我們的對照，不寫暴雪貼圖的欄位）。
------------------------------------------------------------
local gradTex = setmetatable({}, { __mode = "k" })
local whiteColor

-- 清洗：開著回 { r1..a1 不管，color2 = {r,g,b,a}, dir = "H"|"V" }；關／壞值回 nil（純函式，Tests/Extras_test.lua）
function D.CleanGradient(g)
    if type(g) ~= "table" then return nil end
    local c = g.color2
    if type(c) ~= "table" then return nil end
    return { color2 = { r = tonumber(c.r) or 1, g = tonumber(c.g) or 1, b = tonumber(c.b) or 1, a = tonumber(c.a) or 1 },
             dir = g.dir == "V" and "V" or "H" }
end

-- 簽章片段（StackGate 的層簽章用；條層簽章 TSig(r.bar) 已經整張進）
function D.GradientSig(g)
    local cg = D.CleanGradient(g)
    if not cg then return "-" end
    return cg.dir .. ":" .. CSig(cg.color2)
end

local function MakeColor(r, g, b, a)
    local mk = _G.CreateColor
    return mk and mk(r, g, b, a) or nil
end

-- 填充貼圖上色的唯一出口：bar 的單色或漸層；solid（rgba 表）給了 ⇒ 一律單色（無損刷新的提醒色）
function D.PaintFill(tex, bar, solid)
    if not tex then return end
    bar = type(bar) == "table" and bar or {}
    local cg = (not solid) and D.CleanGradient(bar.gradient) or nil
    if cg and tex.SetGradient then
        local c1 = MakeColor(C4(bar.color, 0.4, 0.6, 0.9, 1))
        local c2 = MakeColor(cg.color2.r, cg.color2.g, cg.color2.b, cg.color2.a)
        if c1 and c2 then
            tex:SetVertexColor(1, 1, 1, 1)
            local ok = pcall(tex.SetGradient, tex, cg.dir == "V" and "VERTICAL" or "HORIZONTAL", c1, c2)
            if ok then
                gradTex[tex] = true
                return
            end
        end
    end
    if gradTex[tex] and tex.SetGradient then
        whiteColor = whiteColor or MakeColor(1, 1, 1, 1)
        if whiteColor then pcall(tex.SetGradient, tex, "HORIZONTAL", whiteColor, whiteColor) end
        gradTex[tex] = nil
    end
    if solid then
        tex:SetVertexColor(C4(solid, 1, 1, 1, 1))
    else
        tex:SetVertexColor(C4(bar.color, 0.4, 0.6, 0.9, 1))
    end
end

local function ApplyBarLook(item, rec, style, bar)
    local b = item.Bar
    if not b then return end
    if b.SetStatusBarTexture then
        b:SetStatusBarTexture(ns.Media.Texture(bar.texture))
        local tex = b:GetStatusBarTexture()
        if tex then D.PaintFill(tex, bar) end
    end
    local bg = b.BarBG
    if bg then
        bg:ClearAllPoints()
        bg:SetAllPoints(b)
        bg:SetTexture(WHITE)
        bg:SetVertexColor(C4(bar.bgColor, 0.1, 0.1, 0.1, 0.8))
    end
    -- 火花（bar.spark）：暴雪條的 Pip 只調 alpha（顯示／隱藏照舊是暴雪自己管：倒數中才 Show），
    -- 設定頁預覽的假條是我們自己畫的那條線（ownPip，跟著填充末端走）
    local pip = b.Pip
    if pip then
        if b.ownPip then
            -- 充能分段（F8b）時跟著進度條的填充末端（b.pipAnchor，Modules/Custom.lua 設；只錨不讀）
            local fill = b.pipAnchor or (b.GetStatusBarTexture and b:GetStatusBarTexture())
            pip:ClearAllPoints()
            if fill then
                if bar.vertical then
                    -- 直向（F8c）：填充由下往上，火花是頂緣一條橫線
                    pip:SetPoint("LEFT", fill, "TOPLEFT", 0, 0)
                    pip:SetPoint("RIGHT", fill, "TOPRIGHT", 0, 0)
                    pip:SetHeight(2)
                else
                    pip:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
                    pip:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)
                    pip:SetWidth(2)
                end
            end
        end
        pip:SetAlpha(bar.spark and 1 or 0)
    end
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
        .. "|" .. tostring(spell.cdState) .. "," .. tostring(spell.cdStateAlpha) .. "," .. tostring(spell.dimNoAura)
        .. "|" .. tostring(spell.customIcon)
        .. "|" .. tostring(spell.colorDuration) .. "," .. CSig(spell.durationColor) .. "," .. CSig(spell.durationLowColor)
        .. "," .. CSig(spell.durationSwipeColor) .. "," .. tostring(spell.showAuraTime)
        .. "|" .. tostring(w) .. "x" .. tostring(h)
end
D.Signature = Signature

------------------------------------------------------------
-- 固定格位的占位格（Bars 畫在容器上、item 出現就蓋住）：邊框跟真實格一樣
-- —— 條的邊框設定、逐法術的邊框色覆寫都照套，不然占位看起來像沒有框的暗圖
--   ph = { frame = 占位框（自己的 Frame）, tex = 圖示貼圖, border = MakeBorder 的表（這裡補） }
------------------------------------------------------------
-- w, h：格子尺寸（Masque 模式要它判斷要不要重套皮）。Masque 模式下佔位也交給同一個群組
-- （是我們自己的框），外框跟真實格同一張皮。自訂光環格的占位（Modules/Custom.lua）也是同一種獨立框、走這裡
function D.ApplyPlaceholder(ph, barKey, id, w, h)
    if not (ph and ph.frame and barKey) then return end
    local style = D.Resolve(barKey)
    local border = style.border or {}
    local br, bg, bb, ba = C4(ns.SpellSetting(barKey, id, "borderColor") or border.color, 0, 0, 0, 1)
    ph.border = ph.border or MakeBorder(ph.frame)
    local skinned = false
    if style.masque and ph.tex then
        skinned = ns.Masque.Sync(ph, ph.frame, { Icon = ph.tex }, ns.Masque.TypeFor(barKey), w, h)
    elseif ph.msqButton then
        ns.Masque.Release(ph)
    end
    if skinned then
        LayoutBorder(ph.border, nil)
        return
    end
    LayoutBorder(ph.border, ph.frame, tonumber(border.size) or 0, border.texture, br, bg, bb, ba)
    if ph.tex then
        local z = style.zoom or 0
        ph.tex:SetTexCoord(z, 1 - z, z, 1 - z)
    end
end

------------------------------------------------------------
-- 滑鼠提示
--
-- 用**我們的 overlay** 收滑鼠移動（它蓋在 item 上面，子框收到 OnEnter 之後父層就收不到，
-- 所以暴雪 item 自己的提示自然不會再出現）。開：顯示這格的法術／裝備／物品提示；關：overlay
-- 照樣收滑鼠但什麼都不顯示 ⇒ 暴雪的提示也一起關掉，不用去碰它的 SetTooltipsShown（那會寫暴雪欄位）。
-- 只收滑鼠移動、不收點擊（SetMouseClickEnabled(false)），點擊照舊穿到底下。
------------------------------------------------------------
local function ShowTip(ov)
    local rec = ov.rec
    if not (rec and GameTooltip) then return end
    -- 冷卻狀態把這格藏起來了（明文判得出來的才算；秘密值路徑不知道，照舊顯示）：看不到的格不冒提示
    if rec.stateHidden then return end
    GameTooltip:SetOwner(ov, "ANCHOR_RIGHT")
    local shown = false
    if rec.custom then
        if rec.kind == "slot" and rec.slot then
            shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", rec.slot)
        elseif rec.kind == "item" and rec.itemID then
            shown = pcall(GameTooltip.SetItemByID, GameTooltip, rec.itemID)
        elseif rec.spellID then
            shown = pcall(GameTooltip.SetSpellByID, GameTooltip, rec.overrideID or rec.spellID)
        end
    else
        local info = ns.Catalog.Info(rec.cooldownID)
        local spellID = info and (info.overrideTooltipSpellID or info.overrideSpellID or info.spellID)
        if type(spellID) == "number" then
            shown = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
        elseif info and type(info.equipSlot) == "number" then
            shown = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", info.equipSlot)
        end
    end
    if shown then GameTooltip:Show() else GameTooltip:Hide() end
end

local function HideTip(ov)
    if GameTooltip and GameTooltip:IsOwned(ov) then GameTooltip:Hide() end
end

local function ApplyTooltip(ov, rec, on)
    ov.rec = rec
    if not ov.tipWired then
        ov.tipWired = true
        ov:SetScript("OnEnter", function(self) if self.tipOn then ShowTip(self) end end)
        ov:SetScript("OnLeave", HideTip)
    end
    ov.tipOn = on
    -- 兩種狀態 overlay 都收滑鼠移動：關的時候是為了把暴雪自己的提示也擋掉
    pcall(ov.SetMouseMotionEnabled, ov, true)
    pcall(ov.SetMouseClickEnabled, ov, false)
end
D.ApplyTooltip = ApplyTooltip

-- 可點擊群組的 secure 鈕（Core/Clickable.lua）蓋在格子最上層時，hover 由它收、轉到這裡：
-- 提示照樣錨在 overlay 上（位置跟沒勾一樣），開關照 overlay 的 tipOn。
-- overlay 的滑鼠旗標不動：群組 strata 比檢視器低、item 反過來蓋在鈕上面時，hover 照舊由 overlay 收，
-- 點擊（overlay 不收）穿到底下的鈕。
function D.HoverEnter(rec)
    local ov = rec and rec.overlay
    if ov and ov.tipOn then ShowTip(ov) end
end

function D.HoverLeave(rec)
    local ov = rec and rec.overlay
    if ov then HideTip(ov) end
end

------------------------------------------------------------
-- 重新取出、簽章沒變：只補做暴雪取出時真的會重設、而且我們沒有後掛勾接得到的東西
--
-- 查證（Gethe/wow-ui-source live 分支 12.1.0 (69933)，Blizzard_CooldownViewer）：
--   * 池子的 reset（CooldownViewer.lua CooldownViewerMixin:OnLoad 的 itemResetCallback）：
--     Pool_HideAndClearAnchors、ResetCooldownData（只清資料欄位）、layoutIndex = nil
--     ⇒ 錨點／尺寸由 Bars 放格（Relayout、Reapply）重寫，資料由接著的 RefreshData 補，都不靠 Apply
--   * CooldownViewerMixin:OnAcquireItemFrame（同檔）：
--       SetViewerFrame（欄位）、SetScale(iconScale)（Viewers 的 SetScale 後掛勾＋Track 的 LockScale 壓回 1）、
--       SetTimerShown(timerShown) → 圖示類 CooldownViewerItemMixin:SetTimerShown：
--         **cooldownFrame:SetHideCountdownNumbers(not shown)** ← 蓋掉 Text.ApplyIcon 依「隱藏倒數文字」設的值，
--         沒有後掛勾接得到 ⇒ **這裡補**；
--         長條 CooldownViewerBuffBarItemMixin:SetTimerShown：Duration:SetShown(…)（我們只調它的 alpha、從不 Show／Hide，
--         改之前的完整 Apply 也不碰）⇒ 不補
--       SetTooltipsShown → item 自己的 SetMouseClickEnabled／SetMouseMotionEnabled（我們的提示在 overlay 上，不碰 item 的滑鼠）⇒ 不補
--       SetHideWhenInactive／SetIsEditing → UpdateShownState → SetShown（顯示與否是暴雪的）⇒ 不補
--     增益長條另外（BuffBarCooldownViewerMixin:OnAcquireItemFrame）：SetBarContent（item 的後掛勾 OnSetBarContent
--     已經照 rec.barGeometry 重排、把名字 Show 回來）、SetBarWidth → SetWidth（Bars 放格的 SetSize 蓋過）⇒ 不補
--   * 圓角遮罩、外框圖、轉圈材質只在 XML 模板裡（StripBlizzard 的註解），取出時不會重加 ⇒ 不補
--   * RefreshData 系列（轉圈色、邊緣、去飽和、圖示貼圖、觸發發光、層數字）每次刷新都會寫，本來就靠後掛勾，
--     跟取出無關
------------------------------------------------------------
-- spell 可以是 nil（前置鍵命中那條路沒算 SpellStyle）：這時照 barKey 只讀「隱藏倒數文字」這一個欄位
function D.Reattach(item, rec, spell, isBar, barKey)
    rec.reacquired = nil
    rec.acStyle = nil               -- AfterCooldown 的倒數色去重作廢（下一次 SetCooldown 照現況重寫一次）
    D.applyReattach = D.applyReattach + 1
    if isBar then return end
    local cd = item.Cooldown
    if cd and cd.SetHideCountdownNumbers then
        local hide
        if spell then hide = spell.hideCooldownText
        else hide = ns.SpellSetting(barKey, rec.cooldownID, "hideCooldownText") end
        cd:SetHideCountdownNumbers(hide and true or false)     -- 同 Text.ApplyIcon
    end
end

------------------------------------------------------------
-- 前置鍵（效能修整 E2 #3）：簽章的全部輸入縮成八個純量，八個都跟上一次一樣 ⇒ 簽章一定一樣 ⇒ 連 SpellStyle
-- （新表＋十幾次 SpellSetting）與 Signature（幾個 string.format）都不算
--
--   欄位        ← 簽章的哪個輸入
--   pK_style    D.styleGen：style.sig（Resolve 的快取只靠 generation 作廢，InvalidateAll 兩個一起 +1）
--   pK_over     ns.DB.overrideGen：SpellStyle 的逐法術覆寫（含 customIcon）、IconOverrideOf 看的「是不是光環格」
--               （自訂清單寫入一併 +1）、replaceAuraStyle 與 A 的 SpellStyle（也是覆寫）
--   pK_id       rec.cooldownID
--   pK_w／pK_h  格子尺寸
--   pK_rep      rec.replacing（頂著哪個 A）
--   pK_bar      barKey（＝ rec.decoratedBar 那個比較）
--   pK_masque   ns.Masque.Active()（style.sig 裡的 Masque 那一段是 Resolve 當下的值；這裡比現況，只會更嚴）
-- 另外 rec.decorated 是 nil 就一律不中：所有「強制重套」的地方（InvalidateAll、身分換了、Masque 補做完的 OnLate、
-- 自訂框換 id）都是清 rec.decorated，前置鍵不另外清。
-- SpellStyle 裡退回條層的值（ns.Setting）不在八欄裡：條層設定變了一律經過 InvalidateAll（設定頁 ApplyEngine 0.2 秒
-- 合併後、換設定檔／專精、Masque 變了、整套重來）⇒ styleGen 變。
-- 預覽格（ApplyPreview）不走前置鍵：它每次都要照設定頁當下的值重畫。
------------------------------------------------------------
function D.PreKeyMatch(rec, sgen, ogen, id, w, h, rep, barKey, msq)
    return rec.decorated ~= nil
        and rec.pK_style == sgen and rec.pK_over == ogen and rec.pK_id == id
        and rec.pK_w == w and rec.pK_h == h and rec.pK_rep == rep
        and rec.pK_bar == barKey and rec.pK_masque == msq
end

function D.PreKeyStore(rec, sgen, ogen, id, w, h, rep, barKey, msq)
    rec.pK_style, rec.pK_over, rec.pK_id = sgen, ogen, id
    rec.pK_w, rec.pK_h, rec.pK_rep = w, h, rep
    rec.pK_bar, rec.pK_masque = barKey, msq
end

local function MasqueActive()
    local M = ns.Masque
    return (M and M.Active and M.Active()) and true or false
end

------------------------------------------------------------
-- 主入口
------------------------------------------------------------
function D.Apply(item, rec, barKey, w, h)
    if not (item and rec and barKey) then return end
    D.applyCalls = D.applyCalls + 1
    -- 前置鍵：輸入在算簽章之前先讀好（中途有人作廢 ⇒ 存進去的是舊世代，下一次自然不中）
    local sgen, ogen = D.styleGen, ns.DB and ns.DB.overrideGen or 0
    local id, rep, msq = rec.cooldownID, rec.replacing, MasqueActive()
    if D.PreKeyMatch(rec, sgen, ogen, id, w, h, rep, barKey, msq) then
        D.applyPre = D.applyPre + 1
        if rec.reacquired then
            local st = D.Resolve(barKey)
            D.Reattach(item, rec, nil, st.kind == "bars" and item.Bar ~= nil, barKey)
        end
        D.CdWorkSync(rec, item)       -- 輸入全等：只重判認領／停放（停放後重新放格）
        return
    end
    local style = D.Resolve(barKey)
    local spell = SpellStyle(barKey, id)
    local isBar = style.kind == "bars" and item.Bar ~= nil
    local sig = Signature(style, id, spell, w, h)
    -- 以增益取代：這顆增益 item 正頂著 A 的格（rec.replacing ＝ A），A 勾了「使用增益時間樣式」（預設）
    -- ⇒ 倒數整段照 A 的增益時間樣式（A 的 SpellStyle：換色開關＋三個顏色，沒覆寫退回這一條）。
    -- 沒勾 ⇒ aSpell nil，照增益原本的倒數樣式（不換色）
    local aSpell
    if rec.replacing ~= nil and not isBar and not rec.custom then
        if ns.SpellSetting(barKey, rec.replacing, "replaceAuraStyle") ~= false then
            aSpell = SpellStyle(barKey, rec.replacing)
        end
        sig = sig .. "|rp" .. tostring(rec.replacing)
        if aSpell then
            sig = sig .. "," .. tostring(aSpell.colorDuration) .. "," .. CSig(aSpell.durationColor)
                .. "," .. CSig(aSpell.durationLowColor) .. "," .. CSig(aSpell.durationSwipeColor)
        end
    end
    if rec.decorated == sig and rec.decoratedBar == barKey then
        D.applySkipped = D.applySkipped + 1
        if rec.reacquired then D.Reattach(item, rec, spell, isBar, barKey) end
        D.PreKeyStore(rec, sgen, ogen, id, w, h, rep, barKey, msq)
        if not rec.custom then CdNeedStore(rec); D.CdWorkSync(rec, item) end
        return
    end
    rec.reacquired = nil              -- 下面整套重套，取出時被重設的一併蓋回去

    D.HookItem(item, rec)
    StripBlizzard(item, rec, isBar)
    DimDebuffBorder(item, style.hideDebuffBorder)

    -- 後掛勾讀的快取（暴雪下一次刷新時再套一次）
    local sr, sg, sb, sa = C4(style.swipeColor, 0, 0, 0, 0.8)
    rec.style = {
        swipe      = { sr, sg, sb, sa },
        drawEdge   = style.drawEdge,
        hideGCD    = style.hideGCDSwipe and not ns.Viewers.AURA_KIND[rec.barKey],
        desaturate = spell.desaturate,
        -- 冷卻狀態：長條與增益類不適用（nil ＝ alpha 只跟條走）。alpha 本身由呼叫端走 ApplyItemAlpha／Custom.ApplyState
        cdState    = (not isBar and not ns.Viewers.AURA_KIND[rec.barKey]) and StateMode(spell.cdState) or nil,
        cdAlpha    = ClampAlpha(spell.cdStateAlpha, 0.4),
        -- 效果不在時變暗：只有暴雪的冷卻格有訊號（rec.auraFlag）
        dimNoAura  = (spell.dimNoAura == true and not isBar and not rec.custom
                      and not ns.Viewers.AURA_KIND[rec.barKey]) or nil,
    }
    -- 倒數數字兩段的顏色（ns.Text.ApplyPhaseColor 讀）：長條與增益類、自訂框沒有「先倒增益」那一段 ⇒ 不給
    if not isBar and not rec.custom and not ns.Viewers.AURA_KIND[rec.barKey] then
        rec.style.cdColor, rec.style.durColor = D.PhaseColors(style, spell)
        -- 換色開著的格：增益那一段自己的轉圈背景色＋低秒顏色的 formatter（兩段各一顆，ApplyPhaseColor 換）；
        -- 兩個顏色逐法術可覆寫（SpellStyle 解好，沒覆寫就是條層的）
        if rec.style.durColor then
            rec.style.durSwipe = { C4(spell.durationSwipeColor, 1, 0.9, 0.5, 0.5) }
            local ct = style.cooldownText or {}
            rec.style.cdFmt = ns.Text.CountdownFormatter(ct)
            rec.style.durFmt = ns.Text.CountdownFormatter({ decimalsBelow = ct.decimalsBelow, lowBelow = ct.lowBelow,
                                                           lowColor = spell.durationLowColor or ct.lowColor })
        end
        -- 增益持續中不顯示持續時間（同一個條件；裝備欄項目在 HideTarget 再擋）
        rec.style.hideAuraTime = spell.showAuraTime == false
    elseif aSpell then
        -- 頂著 A 的增益：整段都是增益時間 ⇒ allAura（ApplyPhaseColor／AfterCooldown 不看 rec.auraTime 旗標）
        local cdColor, durColor = D.PhaseColors(style, aSpell)
        if durColor then
            rec.style.cdColor, rec.style.durColor, rec.style.allAura = cdColor, durColor, true
            rec.style.durSwipe = { C4(aSpell.durationSwipeColor, 1, 0.9, 0.5, 0.5) }
            local ct = style.cooldownText or {}
            rec.style.cdFmt = ns.Text.CountdownFormatter(ct)
            rec.style.durFmt = ns.Text.CountdownFormatter({ decimalsBelow = ct.decimalsBelow, lowBelow = ct.lowBelow,
                                                           lowColor = aSpell.durationLowColor or ct.lowColor })
        end
    end
    if not rec.custom then itemOf[rec] = item end

    local ov = EnsureOverlay(item, rec, isBar)
    local border = style.border or {}
    local br, bg, bb, ba = C4(spell.borderColor or border.color, 0, 0, 0, 1)
    local size = tonumber(border.size) or 0
    rec.borderRGBA = { br, bg, bb, ba }

    -- Masque 補做完（脫戰）：這一格重套一次，把暫代的邊框收掉（自訂項目的條記在 placedBar）
    local function OnLate()
        rec.decorated = nil
        local key = rec.claimKey or rec.placedBar
        if key and ns.Bars and ns.Bars.Request then ns.Bars.Request(key, "layout") end
    end

    if isBar then
        local bar = type(style.bar) == "table" and style.bar or {}
        rec.barGeometry = { h = h, w = w, side = bar.iconSide or "LEFT", gap = bar.iconGap or 0, vertical = bar.vertical and true or false }
        D.ApplyBarGeometry(item, rec, rec.barGeometry)
        ApplyBarLook(item, rec, style, bar)
        -- 長條交給 Masque 的是 item.Icon 那一層（整個 item 交出去的話皮會被拉成條的寬度）；
        -- 尺寸＝ApplyBarGeometry 剛設的 h×h
        local skinned = false
        if style.masque and item.Icon and item.Icon.Icon then
            local isz = rec.barGeometry.vertical and w or h      -- 直向：圖示邊長 ＝ 條的粗細（格寬）
            skinned = ns.Masque.Sync(rec, item.Icon, { Icon = item.Icon.Icon },
                ns.Masque.TypeFor(barKey, rec.barKey), isz, isz, OnLate)
        elseif rec.msqButton then
            ns.Masque.Release(rec)
        end
        rec.msqSkinned = skinned
        -- 邊框：圖示一圈、條身一圈（Masque 在畫時圖示那圈藏著、排法記給無損刷新；條身那圈照常）
        rec.border = rec.border or MakeBorder(ov)
        rec.border2 = rec.border2 or MakeBorder(ov)
        local showIcon = rec.barGeometry.side ~= "NONE"
        if skinned then
            rec.msqEdge = { region = showIcon and item.Icon or nil, size = size, token = border.texture }
            LayoutBorder(rec.border, nil)
            LayoutBorder(rec.border2, item.Bar, size, border.texture, br, bg, bb, ba)
        else
            rec.msqEdge = nil
            LayoutBorder(rec.border, showIcon and item.Icon or nil, size, border.texture, br, bg, bb, ba)
            LayoutBorder(rec.border2, item.Bar, size, border.texture, br, bg, bb, ba)
            local iconTex = item.Icon and item.Icon.Icon
            if iconTex and iconTex.SetTexCoord then
                local z = style.zoom
                iconTex:SetTexCoord(z, 1 - z, z, 1 - z)
            end
        end
        ns.Text.ApplyBar(item, style, spell, bar, rec)
    else
        rec.barGeometry = nil
        local icon, cd = item.Icon, item.Cooldown
        local skinned = false
        if style.masque and icon then
            -- 自訂法術的回充轉圈（只畫邊緣）也交出去，尺寸才跟主轉圈一致；暴雪 item 沒有這一層
            skinned = ns.Masque.Sync(rec, item, { Icon = icon, Cooldown = cd, ChargeCooldown = rec.custom and item.ChargeCooldown or nil },
                ns.Masque.TypeFor(barKey, rec.custom and "custom" or rec.barKey), w, h, OnLate)
        elseif rec.msqButton then
            ns.Masque.Release(rec)
        end
        rec.msqSkinned = skinned
        rec.border = rec.border or MakeBorder(ov)
        if rec.border2 then LayoutBorder(rec.border2, nil) end
        if skinned then
            rec.msqEdge = { region = item, size = size, token = border.texture }
            rec.swipeSquare = nil            -- 轉圈材質現在是 Masque 的
            LayoutBorder(rec.border, nil)
        else
            rec.msqEdge = nil
            LayoutBorder(rec.border, item, size, border.texture, br, bg, bb, ba)
            if icon and icon.SetTexCoord then
                local z = style.zoom
                icon:SetTexCoord(z, 1 - z, z, 1 - z)
            end
            SquareSwipe(cd, rec)
        end
        -- 轉圈色一律是我們的（Masque 套皮時會寫它的色，所以在 Sync 之後寫）
        if cd then
            local sw = ((rec.auraTime or rec.style.allAura) and rec.style.durSwipe) or { sr, sg, sb, sa }
            cd:SetSwipeColor(sw[1], sw[2], sw[3], sw[4])
            if type(style.drawEdge) == "boolean" then cd:SetDrawEdge(style.drawEdge) end
        end
        -- 關掉「冷卻中去飽和」：當場還原一次，之後靠 SetDesaturated 後掛勾擋
        if spell.desaturate == false and icon and icon.SetDesaturated then
            desatGuard = true
            icon:SetDesaturated(false)
            desatGuard = false
        end
        ns.Text.ApplyIcon(item, style, spell, rec)
    end

    -- 自訂圖示（暴雪 item；自訂框在 Custom.Update 自己設）
    if not rec.custom then ApplyIconOverride(item, rec, id, isBar, spell.customIcon) end
    ApplyProcAlert(item, rec, barKey)
    D.ApplyGCDAlpha(item, rec)          -- 開關切換當場生效（關掉要把 alpha 還回 1）
    ApplyTooltip(ov, rec, style.tooltips)
    rec.decorated, rec.decoratedBar = sig, barKey
    D.PreKeyStore(rec, sgen, ogen, id, w, h, rep, barKey, msq)
    -- 冷卻事件的全掃清單（D.cdWork）：rec.style 剛換，重算
    if not rec.custom then CdNeedStore(rec); D.CdWorkSync(rec, item) end
    -- 層數門檻（增益）：設定快取在 rec.stackCfg、閘照簽章重建。排在 ApplyBarLook 之後（暴雪條的填充貼圖要有材質）、
    -- Glow.AfterApply 之前（生效發光要看 rec.stackCfg 決定讓不讓位）
    if ns.StackGate and ns.StackGate.Apply then ns.StackGate.Apply(item, rec, barKey, w, h, isBar) end
    -- 發光的框跟著格子尺寸走（尺寸由我們給，不從 item 讀）；樣式變了的發光重畫
    if ns.Glow and ns.Glow.AfterApply then ns.Glow.AfterApply(item, rec, barKey, w, h) end
    -- 增益持續中不顯示持續時間：設定變了（或 /reload 時增益還在）照現況蓋／還原。排最後：
    -- 探針（Glow）與倒數換色（Text.ApplyIcon）都已就位
    if not isBar and not rec.custom then D.SyncAuraHide(item, rec) end
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
    -- 冷卻狀態：假冷卻的格照設定畫（Options/Preview.lua 讀 cell.stateAlpha 疊在格子的 alpha 上）
    local mode = (not isBar and not cell.aura) and StateMode(spell.cdState) or nil
    cell.stateAlpha = D.PreviewStateAlpha(mode, spell.cdStateAlpha, cell.onCD)
    local sig = Signature(style, id, spell, w, h) .. "|" .. tostring(cell.onCD) .. tostring(cell.aura)
        .. tostring(cell.auraPhase)
    if cell.decorated == sig then return end

    local ov = cell.overlay
    local border = style.border or {}
    local br, bg, bb, ba = C4(spell.borderColor or border.color, 0, 0, 0, 1)
    local size = tonumber(border.size) or 0
    local z = style.zoom
    -- 預覽照**登入時的模式**（畫面上真實條現在的樣子）：設定改成 Masque、還沒重載之前預覽不變。
    -- 預覽格是我們自己的框，交給同一個 Masque 群組沒有契約問題
    local masque = style.masque and ns.Masque

    if isBar then
        local bar = type(style.bar) == "table" and style.bar or {}
        local g = { h = h, w = w, side = bar.iconSide or "LEFT", gap = bar.iconGap or 0, vertical = bar.vertical and true or false }
        D.ApplyBarGeometry(cell, nil, g)
        ApplyBarLook(cell, nil, style, bar)
        local skinned = false
        if masque and cell.Icon and cell.Icon.Icon then
            local isz = g.vertical and w or h
            skinned = masque.Sync(cell, cell.Icon, { Icon = cell.Icon.Icon }, masque.TypeFor(barKey), isz, isz)
        end
        cell.msqSkinned, cell.barGeometry = skinned, g      -- 長條：發光／按鍵不跟形狀（同真實格）
        cell.border = cell.border or MakeBorder(ov)
        cell.border2 = cell.border2 or MakeBorder(ov)
        if skinned then
            LayoutBorder(cell.border, nil)
            LayoutBorder(cell.border2, cell.Bar, size, border.texture, br, bg, bb, ba)
        else
            LayoutBorder(cell.border, g.side ~= "NONE" and cell.Icon or nil, size, border.texture, br, bg, bb, ba)
            LayoutBorder(cell.border2, cell.Bar, size, border.texture, br, bg, bb, ba)
            local iconTex = cell.Icon and cell.Icon.Icon
            if iconTex then iconTex:SetTexCoord(z, 1 - z, z, 1 - z) end
        end
        ns.Text.ApplyBar(cell, style, spell, bar)
    else
        local icon = cell.Icon
        local skinned = false
        if masque and icon then
            skinned = masque.Sync(cell, cell, { Icon = icon, Cooldown = cell.Cooldown }, masque.TypeFor(barKey), w, h)
        end
        -- 跟真實格同一個旗標：預覽的發光樣本、按鍵演示（Glow／Keybinds 讀它決定要不要跟著皮的形狀）
        cell.msqSkinned = skinned
        cell.barGeometry = nil
        cell.border = cell.border or MakeBorder(ov)
        if skinned then
            cell.swipeSquare = nil
            LayoutBorder(cell.border, nil)
        else
            LayoutBorder(cell.border, cell, size, border.texture, br, bg, bb, ba)
            if icon then icon:SetTexCoord(z, 1 - z, z, 1 - z) end
            SquareSwipe(cell.Cooldown, cell)
        end
        if icon then
            -- 冷卻中的格才去飽和（增益沒有冷卻，不去飽和）
            icon:SetDesaturated((cell.onCD and not cell.aura and spell.desaturate) and true or false)
        end
        -- 增益持續時間那一段：Preview 標了 cell.auraPhase 的假冷卻格照設定換色（逐法術覆寫也照套）
        -- 設成「增益持續中不顯示持續時間」的格：那一段被蓋成冷卻，當普通冷卻格畫（原色）
        cell.durColor = (cell.auraPhase and not cell.aura and spell.showAuraTime ~= false)
            and D.DurationColorOf(spell.colorDuration, spell.durationColor) or nil
        local cd = cell.Cooldown
        if cd then
            -- 增益那一段的格轉圈用它自己的背景色（逐法術覆寫也照套）
            if cell.durColor then cd:SetSwipeColor(C4(spell.durationSwipeColor, 1, 0.9, 0.5, 0.5))
            else cd:SetSwipeColor(C4(style.swipeColor, 0, 0, 0, 0.8)) end
            if type(style.drawEdge) == "boolean" then cd:SetDrawEdge(style.drawEdge) end
        end
        ns.Text.ApplyPreviewIcon(cell, style, spell)
    end
    cell.decorated = sig
end
