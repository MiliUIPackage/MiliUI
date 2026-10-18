------------------------------------------------------------
-- 外觀：長條（從 Core/Decorate.lua 切出，2026-10-18；TOC 緊接在 Decorate.lua 之後載入）
--
--   長條的名字（SetBarContent／名字 SetText 的後掛勾、秘密名字的退路、名字的樣式）
--   長條的版面：圖示邊、條身、底色、材質；暴雪樣式（bar.look）；漸層填充（bar.gradient）
--
-- 跨檔的幫手都掛在 ns.Decorate 上（Plain、C4、CSig、WHITE、BLIZZ_ATLAS、nameOwner），這裡取回成 local。
-- 給 Decorate.lua 回頭叫的：D.OnSetBarContent／D.OnBarNameSetText（HookItem 掛）、D.ApplyBarLook（Apply／ApplyPreview）。
------------------------------------------------------------
local _, ns = ...

local D = ns.Decorate
local WHITE = D.WHITE
local BAR_FILL_ATLAS, BAR_BG_ATLAS, BAR_PIP_ATLAS = D.BLIZZ_ATLAS.fill, D.BLIZZ_ATLAS.bg, D.BLIZZ_ATLAS.pip
local nameOwner = D.nameOwner
local Plain, C4, CSig = D.Plain, D.C4, D.CSig

------------------------------------------------------------
-- 長條的名字
------------------------------------------------------------


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
D.OnSetBarContent = OnSetBarContent

-- 長條名字：暴雪寫進 nil／空字串時用法術名字頂
--   名字是暴雪在 RefreshName 寫的（我們只管樣式，見 Text.ApplyBar），召喚類（惡魔暴君這種）
--   第一次 PLAYER_TOTEM_UPDATE 時 GetTotemInfo 還沒有單位名字 ⇒ 寫進去的是 nil，而暴雪之後
--   不一定再叫一次 RefreshName（只有下一次 RefreshData 會）⇒ 整條空到消失。
--   秘密字串不碰（拿著不讀）；真名之後寫進來就自然蓋掉。只讀 Catalog 的明文資料，不碰 totemData。
--   法術 id 先問 item 自己的 GetSpellID（暴雪會把 linkedSpell／光環的 id 算進去，跟它寫名字用的是同一個），
--   讀不到明文再退 Catalog。每次處理都記一行 diag（Diag.Note 合併同字），實機不對時 /mcdm debug 看得到。
local nameGuard = false
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

-- 空的秘密名字的退路：疊在暴雪名字上面的一行我們自己的字（不寫進暴雪的框）。
-- 實機 2026-10-17：暴雪寫進空的秘密字串之後，我們對它 SetText(法術名) 畫面照樣空白（diag 記到「→ 法術名」、玩家看不到）
-- ⇒ 不跟暴雪的框搶：秘密那條改成自己疊一行，暴雪之後寫進任何有寬度的名字就藏起來。
-- 樣式照長條名字的設定（字型、字級、描邊、顯示開關；Text.StyleNameFill，跟暴雪那行同一份），設定改了 Text.ApplyBar
-- 會叫 RestyleNameFill 跟著換。Text 還沒套過這一格（理論上不會）才退回從暴雪那行抄
-- （實機 2026-10-17：從暴雪那行抄字型抄不到，退成遊戲預設字型，跟玩家設的不一致）
local nameFill = setmetatable({}, { __mode = "k" })   -- 暴雪名字 FontString → 我們的退路字
local function HideNameFill(fs)
    local f = nameFill[fs]
    if f then f:Hide() end
end

local function ShowNameFill(fs, name)
    local f = nameFill[fs]
    if not f then
        local okP, parent = pcall(fs.GetParent, fs)
        if not (okP and parent and parent.CreateFontString) then return false end
        f = parent:CreateFontString(nil, "OVERLAY")
        f:SetAllPoints(fs)
        nameFill[fs] = f
    end
    if ns.Text and ns.Text.StyleNameFill and ns.Text.StyleNameFill(fs, f) then
        f:SetText(name)
        f:Show()
        return true
    end
    local okF, font, size, flags = pcall(fs.GetFont, fs)
    font, size, flags = Plain(font), Plain(size), Plain(flags)
    if not (okF and type(font) == "string" and type(size) == "number" and pcall(f.SetFont, f, font, size, flags or "")) then
        f:SetFontObject(_G.GameFontHighlightSmall)          -- ⚠ FontString 要先有字型才能 SetText
    end
    local okJ, jh = pcall(fs.GetJustifyH, fs)
    jh = okJ and Plain(jh) or nil
    f:SetJustifyH(type(jh) == "string" and jh or "LEFT")
    local okC, r, g, b, a = pcall(fs.GetTextColor, fs)
    r, g, b, a = Plain(r), Plain(g), Plain(b), Plain(a)
    if okC and type(r) == "number" and type(g) == "number" and type(b) == "number" then
        f:SetTextColor(r, g, b, type(a) == "number" and a or 1)
    else
        f:SetTextColor(1, 1, 1, 1)
    end
    local okA, alpha = pcall(fs.GetAlpha, fs)
    alpha = okA and Plain(alpha) or nil
    f:SetAlpha(type(alpha) == "number" and alpha or 1)
    f:SetText(name)
    f:Show()
    return true
end
D.ShowNameFill, D.HideNameFill = ShowNameFill, HideNameFill      -- 測試用
-- Text.ApplyBar 套完名字樣式叫：疊字建過就跟著換（沒建過不建）
function D.RestyleNameFill(fs)
    local f = nameFill[fs]
    if f and ns.Text and ns.Text.StyleNameFill then ns.Text.StyleNameFill(fs, f) end
end

-- 這一格的法術名（退路用）：nil ＝ 拿不到
local function FallbackName(item, rec)
    local spellID = BarItemSpellID(item, rec)
    if spellID then
        local ok, v = pcall(C_Spell.GetSpellName, spellID)
        v = ok and Plain(v) or nil
        if type(v) == "string" and v ~= "" then return v, spellID end
    end
    return nil, spellID
end

-- 名字框現在量到的寬度 → 0（空的）／"寬>0"／"寬秘密"／"寬讀不到"
local function WidthKind(fs)
    local ok, w = pcall(fs.GetStringWidth, fs)
    if not ok then return "寬讀不到" end
    if ns.IsSecret(w) then return "寬秘密" end
    w = Plain(w)
    if w == 0 then return 0 end
    return type(w) == "number" and "寬>0" or "寬讀不到"
end

-- 暴雪每寫一次名字就換一號：下一幀的重量只在這中間沒有新的寫入時才算數
local nameGen = setmetatable({}, { __mode = "k" })

-- 秘密字串、寫字當下量到的寬度不是 0：下一幀再量一次。
-- 實機 2026-10-17：/reload 後第一次召喚暴君記到「秘密字串（留著）」、畫面卻空白約 0.5 秒才出現真名
-- ⇒ 寫字當下的寬度不可靠（推測是上一次的字留下的版面還沒重算；當下是秘密值也一樣當不知道）
local function RecheckSecretName(fs, gen, first)
    if nameGen[fs] ~= gen or ns.released then return end
    local item = nameOwner[fs]
    local rec = item and ns.Viewers.frames[item]
    if not rec or rec.custom then return end
    local now = WidthKind(fs)
    local Note = ns.Diag and ns.Diag.Note
    if now ~= 0 then
        if Note then Note("barname", string.format("%s 秘密字串 %s、下一幀 %s（留著）", tostring(rec.cooldownID), first, now)) end
        return
    end
    local name = FallbackName(item, rec)
    local how = name and ShowNameFill(fs, name) and ("疊字 " .. name) or "沒退路"
    if Note then Note("barname", string.format("%s 秘密字串 %s、下一幀量到空的 → %s", tostring(rec.cooldownID), first, how)) end
end

local function OnBarNameSetText(fs, text)
    if nameGuard or ns.released then return end
    local item = nameOwner[fs]
    local rec = item and ns.Viewers.frames[item]
    if not rec or rec.custom then return end
    local gen = (nameGen[fs] or 0) + 1
    nameGen[fs] = gen
    local Note = ns.Diag and ns.Diag.Note
    local what, secret
    if ns.IsSecret(text) then                           -- ⚠ 秘密值連跟 nil 比都會拋錯，先擋
        -- 秘密字串讀不到內容，但 GetStringWidth 只在「錨點是秘密」時才回秘密（API 文件 SecretWhenAnchoringSecret，
        -- 跟文字的秘密 aspect 無關）⇒ 明文寬度 0 ＝ 暴雪寫進來的是空的。實機 2026-10-17：12.1.5 召喚惡魔暴君
        -- 第一次召喚的名字是秘密字串（totemData 整張秘密），而且是空的 ⇒ 以前「秘密就留著」整條空白到消失
        local kind = WidthKind(fs)
        if kind ~= 0 then
            -- 當下量不到 0：先當有名字（疊字收起來），下一幀再量一次（見 RecheckSecretName）
            HideNameFill(fs)
            ns.Defer(RecheckSecretName, fs, gen, kind)
            return
        end
        what, secret = "空的秘密字串", true
    elseif text ~= nil and text ~= "" then
        HideNameFill(fs)
        return
    else
        what = text == nil and "nil" or "空字串"
    end
    local name, spellID = FallbackName(item, rec)
    local how = "沒退路（spellID " .. tostring(spellID) .. "）"
    if name then
        if secret and ShowNameFill(fs, name) then
            how = "疊字 " .. name
        else
            HideNameFill(fs)
            nameGuard = true
            local ok = pcall(fs.SetText, fs, name)
            nameGuard = false
            how = (ok and "法術名 " or "寫入失敗 ") .. name
        end
    end
    if Note then Note("barname", string.format("%s %s → %s", tostring(rec.cooldownID), what, how)) end
end
D.OnBarNameSetText = OnBarNameSetText
D.RecheckSecretName = RecheckSecretName                              -- 測試用

------------------------------------------------------------
-- 長條的版面：圖示邊、條身、底色、材質
------------------------------------------------------------
-- 長條的暴雪樣式（bar.look ＝ "blizzard"）：畫成暴雪冷卻管理器原生長條的長相。依據 Gethe/wow-ui-source
-- Blizzard_CooldownViewer/CooldownViewer.xml 的 CooldownViewerBuffBarItemTemplate（item 220×30）：
--   圖示 30×30 靠左、圓角遮罩 UI-HUD-CoolDownManager-Mask、外框圖 UI-HUD-CoolDownManager-IconOverlay（TOPLEFT -6,5／BOTTOMRIGHT 6,-5）
--   條身高 19、垂直置中、LEFT 錨圖示 RIGHT +2；填充 UI-HUD-CoolDownManager-Bar 頂點色 (1, 0.5, 0.25)
--   底 UI-HUD-CoolDownManager-Bar-BG（TOPLEFT -2,2／BOTTOMRIGHT 4,-7：右下凸出的那截是陰影）頂點色白
--   火花 UI-HUD-CoolDownManager-Bar-Pip（useAtlasSize），CENTER 錨填充貼圖 RIGHT (0, -1)；沒有邊框
-- 暴雪的 Lua（CooldownViewerBuffBarItemMixin）執行期不碰填充材質／顏色／BarBG，只寫值、Pip 的 Show、文字
-- ⇒ 寫一次就留得住（同米利樣式）。我們的差別：尺寸照格高等比（D.BlizzBarMetrics）、圖示與條身的間距照 bar.iconGap、
-- 填充色是 bar.blizzardColor（跟米利樣式的 bar.color 分開存，切回來藍色還在）、文字照我們的文字設定。
-- 直向沒有暴雪樣式（底的圖集是橫的、陰影在右下）：存著也當米利畫（D.BarLook）。
-- StatusBar:SetStatusBarTexture 收圖集名稱：暴雪自己的 UnitFrame.lua 就是 manaBar:SetStatusBarTexture(info.atlas)
-- （API 文件的參數型別是 TextureAsset；2026-10-09 對過 live 分支），所以填充直接傳圖集名，不必先 SetTexture 再 SetAtlas。
-- 一般貼圖（底、自己的火花、層數那一層的色塊）走 SetAtlas；換回米利樣式時 SetTexture(WHITE)＋SetTexCoord 全幅（圖集的
-- 裁切座標不留下來）。
local BLIZZ_H = 30
local BLIZZ_COLOR = { r = 1, g = 0.5, b = 0.25, a = 1 }
D.BLIZZ_COLOR = BLIZZ_COLOR

-- 生效的外觀（純函式，Tests/Extras_test.lua）："blizzard" 只在存了暴雪樣式而且不是直向時
function D.BarLook(bar)
    if type(bar) == "table" and bar.look == "blizzard" and not bar.vertical then return "blizzard" end
    return "miliui"
end

-- 以 30 高為基準的等比尺寸（純函式，Tests/Extras_test.lua）；像素對齊用 Layout.Snap
--   thick 條身高；bgL／bgT／bgR／bgB 底相對條身四角的偏移（照 SetPoint 的正負：左 −、上 ＋、右 ＋、下 −）；
--   ovX／ovY 外框圖往外凸的量；pipScale 火花對圖集原尺寸的倍率
function D.BlizzBarMetrics(h)
    h = tonumber(h) or BLIZZ_H
    if h <= 0 then h = BLIZZ_H end
    local k = h / BLIZZ_H
    local Snap = ns.Layout and ns.Layout.Snap or function(v) return v end
    return {
        thick = Snap(h * 19 / BLIZZ_H),
        bgL = -Snap(2 * k), bgT = Snap(2 * k), bgR = Snap(4 * k), bgB = -Snap(7 * k),
        ovX = Snap(6 * k), ovY = Snap(5 * k),
        pipScale = k,
    }
end

-- 填充上色要用的那張表（純函式，Tests/Extras_test.lua）：米利樣式就是 bar 本身（單色或漸層），
-- 暴雪樣式是 { color = blizzardColor }（沒有漸層 ⇒ PaintFill 畫單色、把畫過的漸層洗掉）。
-- 填充色的唯一來源：ApplyBarLook、無損刷新還原（Core/Glow.lua）、層數那一層（Core/StackGate.lua）、充能分段都問它
-- spellColor ＝ 這一招的長條顏色（逐法術覆寫 barColor）：色表 ⇒ 一律單色（兩種外觀都是，條的漸層不套）；
-- 不是色表（nil／false）＝ 跟隨條
function D.BarFillStyle(bar, spellColor)
    if type(spellColor) == "table" then return { color = spellColor } end
    bar = type(bar) == "table" and bar or {}
    if D.BarLook(bar) ~= "blizzard" then return bar end
    local c = type(bar.blizzardColor) == "table" and bar.blizzardColor or BLIZZ_COLOR
    return { color = c }
end

-- 填充的材質：暴雪樣式回圖集名（StatusBar:SetStatusBarTexture 收），米利樣式回 LibSharedMedia 的路徑
function D.BarFillTexture(bar)
    if D.BarLook(bar) == "blizzard" then return BAR_FILL_ATLAS end
    return ns.Media.Texture(type(bar) == "table" and bar.texture or nil)
end

-- 一般貼圖換成填充的材質（層數那一層的原色填充／色塊）：圖集要走 SetAtlas
function D.SetFillTexture(tex, bar)
    if not tex then return end
    if D.BarLook(bar) == "blizzard" and tex.SetAtlas then
        tex:SetAtlas(BAR_FILL_ATLAS)
    else
        tex:SetTexture(ns.Media.Texture(type(bar) == "table" and bar.texture or nil))
        if tex.SetTexCoord then tex:SetTexCoord(0, 1, 0, 1) end
    end
end

-- 底的頂點色：暴雪樣式白（圖集本身的顏色）、米利樣式 bar.bgColor
function D.BarBGColor(bar)
    if D.BarLook(bar) == "blizzard" then return 1, 1, 1, 1 end
    return C4(type(bar) == "table" and bar.bgColor or nil, 0.1, 0.1, 0.1, 0.8)
end

-- 底（bg 貼圖排在條身 b 上）：暴雪樣式＝圖集＋等比偏移（h ＝ 格高），米利樣式＝白底貼滿條身＋bgColor
function D.PaintBarBG(bg, b, bar, h)
    if not (bg and b) then return end
    bg:ClearAllPoints()
    if D.BarLook(bar) == "blizzard" and bg.SetAtlas then
        local m = D.BlizzBarMetrics(h)
        bg:SetPoint("TOPLEFT", b, "TOPLEFT", m.bgL, m.bgT)
        bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", m.bgR, m.bgB)
        bg:SetAtlas(BAR_BG_ATLAS)
    else
        bg:SetAllPoints(b)
        bg:SetTexture(WHITE)
        if bg.SetTexCoord then bg:SetTexCoord(0, 1, 0, 1) end
    end
    bg:SetVertexColor(D.BarBGColor(bar))
end

-- 火花圖集的原尺寸（C_Texture.GetAtlasInfo；讀不到 ＝ nil，呼叫端不調尺寸）
local function PipAtlasSize()
    local CT = _G.C_Texture
    local ok, info = pcall(function() return CT and CT.GetAtlasInfo and CT.GetAtlasInfo(BAR_PIP_ATLAS) end)
    if ok and type(info) == "table" and tonumber(info.width) and tonumber(info.height) then
        return info.width, info.height
    end
end
-- 暴雪條的火花（Pip）：暴雪只在 OnLoad 錨一次（CENTER → 填充貼圖的 RIGHT, 0, -1），之後不再動。
-- 直向時改錨填充的頂緣、轉 90 度；反向填充（bar.reverseFill）時移動的那一端在填充的左緣（直向＝底緣）；
-- 回到橫向不反向時照暴雪原本的錨回去。動過的記在弱鍵表（不寫暴雪的欄位）
local turnedPip = setmetatable({}, { __mode = "k" })
local function OrientBlizzPip(b, vertical, reverse)
    local pip = b.Pip
    if not pip or b.ownPip then return end
    local stock = not vertical and not reverse
    if stock and not turnedPip[pip] then return end
    local ok, fill = pcall(b.GetStatusBarTexture, b)
    if not ok or not fill then return end
    pip:ClearAllPoints()
    if vertical then
        pip:SetPoint("CENTER", fill, reverse and "BOTTOM" or "TOP", 0, 0)
        if pip.SetRotation then pcall(pip.SetRotation, pip, math.pi / 2) end
        turnedPip[pip] = true
    elseif reverse then
        pip:SetPoint("CENTER", fill, "LEFT", 0, -1)
        if pip.SetRotation then pcall(pip.SetRotation, pip, 0) end
        turnedPip[pip] = true
    else
        pip:SetPoint("CENTER", fill, "RIGHT", 0, -1)
        if pip.SetRotation then pcall(pip.SetRotation, pip, 0) end
        turnedPip[pip] = nil
    end
end

-- 自己畫的火花（ownPip：設定頁假條、自訂長條；2px 亮線）錨在填充**移動的那一端**：
--   橫向＝右緣（反向＝左緣）；直向（F8c）＝頂緣（反向＝底緣）。只錨不讀（fill 可能是跟著秘密值走的填充貼圖）
--   Modules/Custom.lua 的充能分段／光環長條是同一套錨法（那邊在測試裡沒有 Decorate，自己留一份）
function D.AnchorFillPip(pip, fill, vertical, reverse)
    if not (pip and fill) then return end
    pip:ClearAllPoints()
    if vertical then
        local e = reverse and "BOTTOM" or "TOP"
        pip:SetPoint("LEFT", fill, e .. "LEFT", 0, 0)
        pip:SetPoint("RIGHT", fill, e .. "RIGHT", 0, 0)
        pip:SetHeight(2)
    else
        local e = reverse and "LEFT" or "RIGHT"
        pip:SetPoint("TOP", fill, "TOP" .. e, 0, 0)
        pip:SetPoint("BOTTOM", fill, "BOTTOM" .. e, 0, 0)
        pip:SetWidth(2)
    end
end

-- 自己的火花換成暴雪樣式（圖集＋等比尺寸）時記在這裡（火花 → pipScale；米利樣式 ＝ nil）。只是我們的對照
local blizzOwnPip = setmetatable({}, { __mode = "k" })
-- 暴雪條的火花被我們照格高縮放過（米利樣式要 SetAtlas(…, true) 換回圖集原尺寸）
local scaledPip = setmetatable({}, { __mode = "k" })

-- 自己的火花錨到填充末端：照它現在的長相（ApplyBarLook 換的）——暴雪樣式是一顆圖集，CENTER 錨填充移動的那一端
-- （同暴雪條的 (0, -1)，照格高等比）；米利樣式是 2px 亮線（D.AnchorFillPip）。
-- Modules/Custom.lua 的充能分段把火花搬到進度條的填充末端時也走這支
function D.AnchorOwnPip(pip, fill, vertical, reverse)
    if not (pip and fill) then return end
    local k = blizzOwnPip[pip]
    if not k then return D.AnchorFillPip(pip, fill, vertical, reverse) end
    local Snap = ns.Layout and ns.Layout.Snap or function(v) return v end
    pip:ClearAllPoints()
    pip:SetPoint("CENTER", fill, reverse and "LEFT" or "RIGHT", 0, -Snap(k))
end

-- g = { h, w, side, gap, vertical, reverse, look }：格子尺寸由排版給（不讀框）。
-- 直向（F8c）：圖示 w×w（w ＝ 條的粗細），side 的 LEFT／RIGHT 當上／下；條身 SetOrientation("VERTICAL")
-- look ＝ "blizzard"（D.BarLook 算好的生效值，直向不會是它）：條身改成垂直置中的細條，見「長條的暴雪樣式」
-- 反向填充（bar.reverseFill）：SetReverseFill 只換填充起點（橫向從右、直向從上），值一個都不碰（可能是秘密值）；
-- true／false 每次都寫，關掉時才回得去
function D.ApplyBarGeometry(item, rec, g)
    local icon, b = item.Icon, item.Bar
    if not (icon and b) then return end
    local h = g.h
    local gap = ns.Layout.Snap(g.gap or 0)
    if b.SetOrientation then b:SetOrientation(g.vertical and "VERTICAL" or "HORIZONTAL") end
    if b.SetReverseFill then b:SetReverseFill(g.reverse and true or false) end
    OrientBlizzPip(b, g.vertical, g.reverse)
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
    elseif g.look == "blizzard" then
        -- 暴雪樣式（只有橫向）：圖示 h×h；條身高照 30:19 等比、垂直置中（錨 LEFT／RIGHT，高度自己給）
        icon:SetSize(h, h)
        b:SetHeight(D.BlizzBarMetrics(h).thick)
        if g.side == "RIGHT" then
            icon:SetPoint("RIGHT", item, "RIGHT", 0, 0)
            b:SetPoint("LEFT", item, "LEFT", 0, 0)
            b:SetPoint("RIGHT", icon, "LEFT", -gap, 0)
        elseif g.side == "NONE" then
            icon:SetPoint("LEFT", item, "LEFT", 0, 0)
            b:SetPoint("LEFT", item, "LEFT", 0, 0)
            b:SetPoint("RIGHT", item, "RIGHT", 0, 0)
        else
            icon:SetPoint("LEFT", item, "LEFT", 0, 0)
            b:SetPoint("LEFT", icon, "RIGHT", gap, 0)
            b:SetPoint("RIGHT", item, "RIGHT", 0, 0)
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
--   反向填充（bar.reverseFill）：起點色跟著**填充的起點**走（決定：條從右邊長出來時，起點色在右）⇒ 漸層方向
--   跟條的填充方向同一軸時兩色對調（D.GradientFlip）；跨粗細那一軸（橫條的 V、直條的 H）不受反向影響。
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

-- 漸層兩色要不要對調（純函式，Tests/Extras_test.lua）：反向填充、而且漸層沿著填充方向（橫條的 H、直條的 V）
function D.GradientFlip(bar)
    if type(bar) ~= "table" or not bar.reverseFill then return false end
    local cg = D.CleanGradient(bar.gradient)
    if not cg then return false end
    return (cg.dir == "V") == (bar.vertical and true or false)
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
            if D.GradientFlip(bar) then c1, c2 = c2, c1 end
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

-- h ＝ 格高（暴雪樣式的等比尺寸；直向不會是暴雪樣式，用不到）。兩種樣式每次都整套寫，切換不必重載：
--   填充材質（SetStatusBarTexture 每次寫）、填充色（PaintFill：暴雪樣式沒有漸層 ⇒ 畫過的漸層洗掉）、
--   底（D.PaintBarBG：錨點／圖集或白底／頂點色全寫）、火花（下面）
-- spellColor ＝ 這一招的長條顏色（SpellStyle 的 barColor；nil／false ＝ 跟隨條）
local function ApplyBarLook(item, rec, style, bar, h, spellColor)
    local b = item.Bar
    if not b then return end
    local blizz = D.BarLook(bar) == "blizzard"
    if b.SetStatusBarTexture then
        b:SetStatusBarTexture(D.BarFillTexture(bar))
        local tex = b:GetStatusBarTexture()
        if tex then D.PaintFill(tex, D.BarFillStyle(bar, spellColor)) end
    end
    D.PaintBarBG(b.BarBG, b, bar, h)
    -- 火花（bar.spark）：暴雪條的 Pip 只調 alpha（顯示／隱藏照舊是暴雪自己管：倒數中才 Show），
    -- 設定頁預覽的假條是我們自己畫的那條線（ownPip，跟著填充末端走）
    local pip = b.Pip
    if pip then
        local m = blizz and D.BlizzBarMetrics(h) or nil
        local aw, ah = nil, nil
        if blizz then aw, ah = PipAtlasSize() end
        if b.ownPip then
            -- 長相：暴雪樣式＝火花圖集（等比；圖集尺寸讀不到時退成 2px 寬、條身高）、米利樣式＝2px 白線
            if blizz and pip.SetAtlas then
                pip:SetAtlas(BAR_PIP_ATLAS)
                if aw then pip:SetSize(aw * m.pipScale, ah * m.pipScale) else pip:SetSize(2, m.thick) end
                blizzOwnPip[pip] = m.pipScale
            else
                pip:SetTexture(WHITE)
                if pip.SetTexCoord then pip:SetTexCoord(0, 1, 0, 1) end
                blizzOwnPip[pip] = nil
            end
            -- 充能分段（F8b）時跟著進度條的填充末端（b.pipAnchor，Modules/Custom.lua 設；只錨不讀）
            -- 直向（F8c）是頂緣一條橫線；反向填充時換到另一端（D.AnchorOwnPip）
            local fill = b.pipAnchor or (b.GetStatusBarTexture and b:GetStatusBarTexture())
            pip:ClearAllPoints()
            if fill then D.AnchorOwnPip(pip, fill, bar.vertical, bar.reverseFill) end
        elseif blizz then
            -- 暴雪條的火花：本來就是這張圖集，只照格高等比縮（錨點是 OrientBlizzPip 管的）
            if pip.SetAtlas then pip:SetAtlas(BAR_PIP_ATLAS, true) end
            if aw then pip:SetSize(aw * m.pipScale, ah * m.pipScale) end
            scaledPip[pip] = true
        elseif scaledPip[pip] then
            -- 從暴雪樣式切回來：圖集原尺寸（米利樣式以前就不動它的尺寸）
            if pip.SetAtlas then pip:SetAtlas(BAR_PIP_ATLAS, true) end
            scaledPip[pip] = nil
        end
        pip:SetAlpha(bar.spark and 1 or 0)
    end
end
D.ApplyBarLook = ApplyBarLook                                      -- 測試用
