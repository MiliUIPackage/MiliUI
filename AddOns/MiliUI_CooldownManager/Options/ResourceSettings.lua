------------------------------------------------------------
-- 每種資源自己的設定視窗（資源條頁「這個專精要顯示哪些」每一列的「設定…」開的）
--
--   ns.ResourceSettings.Open(key)     開（已經開著就換成這一種資源）
--   ns.ResourceSettings.Close()
--   ns.ResourceSettings.Refresh()     開著就重讀（資源條頁改了全域外觀時叫）
--
-- 內容是 Specs.BuildForm 建的表單、放在捲動容器裡（同資源條頁／施法條頁的做法），小節：
--   版面   高（resources.heights[key]，所有專精共用；R.KeyRowHeight／R.SetKeyHeight）
--   外觀   「跟隨資源條的外觀」（style[key].follow，沒存＝跟）＋材質、背景材質、填充透明度、平滑（連續條才有）、
--          數值文字、字型、字級——讀寫 style[key].*。跟著時這幾列蓋暗色遮罩（Specs 的 disabled 機制）、
--          顯示的是資源條頁的全域值；取消勾選時沒存過的欄位也先顯示全域值，改了才寫進 style[key]
--   文字   法力的數字格式／百分比、血量的百分比（欄位不搬家：manaAbbrev／manaPercent／healthPercent），
--          醉仙緩勁與血量也有數字格式（跟法力同一個欄位，說明列寫明），符文、秘法靈魂的數字
--   顏色   主色＋各資源的額外色、醉仙緩勁的門檻、氣漩摺疊、征戰聖擊、血量的職業色／門檻換色……
--          （原本資源條頁「顏色與條件」那一段，整段搬來）＋條件規則（只這一種資源）
--
-- 一次只開一個；表單照「形狀」快取（key、條件規則的結構、氣漩摺不摺、征戰聖擊在不在追蹤量條）：
-- frame 刪不掉，形狀一樣就重用。「跟隨」切換不換表單（遮罩是即時判的）。
-- 非強制回應的小視窗（同逐法術面板）：DIALOG 300，彈窗（血量門檻、確認）在 FULLSCREEN_DIALOG 蓋在它上面。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

local Options = ns.Options

ns.ResourceSettings = {}
local RS = ns.ResourceSettings

local KEY     = "resources"
local WIDTH   = 540          -- 條件規則的列是照資源條頁的表單寬排的（變數／比較／數值／移除一路排到控件欄 +332）
local MAX_H   = 560
local PAD     = 12
local HEAD_H  = 30
local FORM_W  = WIDTH - PAD * 2 - 24      -- 扣掉捲軸
local LABEL_W  = ns.WidgetsEnv.LABEL_W or 128
local CTRL_GAP = 12                       -- 共用層表單：標籤欄與控件欄的間距（Controls.lua 的 GAP）

local function Cfg() return ns.DB.ConfigTable(KEY) end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local RUNE_TEXT_ITEMS = {
    { text = L["Seconds left on each rune"], value = "countdown" },
    { text = L["Ready runes count"],         value = "count" },
}

local ARCANE_SOUL_ITEMS = {
    { text = L["Seconds left"],       value = "seconds" },
    { text = L["Global cooldowns left"], value = "gcd" },
}

local CRUSADING_FILL_ITEMS = {
    { text = L["Time since the last swing (fills up)"], value = "elapsed" },
    { text = L["Time until the next swing (empties)"], value = "remaining" },
}

local MANA_ITEMS = {
    { text = L["Full number"],           value = "none" },
    { text = L["K / M"],                 value = "k" },
    { text = L["10K / 100M (wan / yi)"], value = "wan" },
}

-- 背景材質的選項：第一項「跟填充相同」（資源條頁的全域外觀也用這張）
function RS.BgTextureItems()
    local items = ns.Specs.TextureItems()
    table.insert(items, 1, { text = L["Same as fill"], value = ns.Media.INHERIT })
    return items
end

-- 原地改值（顏色、門檻）：不換表單
local function Touched(ctx)
    ctx.lastSpec = nil
    ctx.apply()
end

------------------------------------------------------------
-- 外觀（style[key]）
------------------------------------------------------------
local function OwnStyle(key)
    local c = Cfg()
    local st = c and c.style
    local s = type(st) == "table" and st[key]
    return type(s) == "table" and s or nil
end

local function Following(key) return ns.Resources.StyleFollows(Cfg(), key) end

-- 顯示的值：跟著 ⇒ 全域；不跟 ⇒ 自己存的，沒存的那欄退回全域（引擎的代理表同一個規則）
local function StyleGet(key, field)
    local c = Cfg()
    if not Following(key) then
        local own = OwnStyle(key)
        local v = own and own[field]
        if v ~= nil then return v end
    end
    return c and c[field]
end

-- 外觀的一列：寫 style.<key>.<field>（DB.SetPath 沿路補表；右鍵重設＝清成 nil ＝ 回到全域值）。
-- 跟著時整列蓋遮罩（點不動、右鍵也擋）
local function SS(kind, key, field, label, extra)
    local s = BS(kind, "style." .. key .. "." .. field, label, extra)
    if not s.get then s.get = function() return StyleGet(key, field) end end
    s.disabled = function() return Following(key) end
    return s
end

local function AppendStyle(add, key, info)
    add({ type = "header", label = L["Appearance"] })
    add(BS("toggle", "style." .. key .. ".follow", L["Follow the resource bar's look"], {
        refreshPage = true,
        get = function() return Following(key) end,
    }))
    add(Note(L["While checked, this resource uses the Appearance section of the Class Resources tab. Uncheck it to give this resource its own look."]))
    add(SS("dropdown", key, "texture", L["Texture"], { items = ns.Specs.TextureItems }))
    add(SS("dropdown", key, "bgTexture", L["Background texture"], { items = RS.BgTextureItems,
        get = function() return ns.Specs.InheritOr(StyleGet(key, "bgTexture")) end }))
    add(SS("slider", key, "barAlpha", L["Fill opacity"], { min = 0.1, max = 1, step = 0.05 }))
    if info.mode == "bar" then add(SS("toggle", key, "smooth", L["Smooth bar changes"])) end
    if not info.noText then
        add(SS("dropdown", key, "textFont", L["Font"], { items = ns.Specs.ElementFontItems,
            get = function() return ns.Specs.InheritOr(StyleGet(key, "textFont")) end }))
        add(SS("slider", key, "textSize", L["Font size"], { min = 6, max = 24, step = 1 }))
    end
end

------------------------------------------------------------
-- 文字（數字格式）：欄位留在原處，只是搬到這裡顯示
------------------------------------------------------------
local function AppendNumbers(add, key, info)
    local rows = {}
    local function put(s) rows[#rows + 1] = s end
    if info.mana then
        put(BS("dropdown", "manaAbbrev", L["Mana number format"], { items = MANA_ITEMS }))
        put(BS("toggle", "manaPercent", L["Mana as percent"]))
        put(Note(L["One number format is shared by mana, health and the other large numbers."]))
    elseif info.health or info.stagger then
        -- 血量與醉仙緩勁的大數字照法力的縮寫（同一個 manaAbbrev）：沒有法力列的專精也要改得到
        if info.health then put(BS("toggle", "healthPercent", L["Health as percent"])) end
        put(BS("dropdown", "manaAbbrev", L["Number format"], { items = MANA_ITEMS }))
        put(Note(L["One number format is shared by mana, health and the other large numbers."]))
    end
    if info.fill == "rune" then
        put(BS("dropdown", "runeText", L["Numbers on runes"], { items = RUNE_TEXT_ITEMS }))
        put(Note(L["Ready runes always line up on the left and recharging ones fill up on the right. With \"Show value on the bar\" on, pick one number: the seconds left on each recharging rune, or how many runes are ready in the middle."]))
        put(BS("toggle", "runeQueued", L["Count waiting runes"]))
        put(Note(L["Only three runes recharge at a time; the rest wait their turn. With this on, waiting runes also show the seconds until they're ready and fill up across the whole wait."]))
    elseif info.gcdText then
        put(BS("dropdown", "arcaneSoulText", L["Number on the bar"], { items = ARCANE_SOUL_ITEMS }))
        put(Note(L["Global cooldowns left counts how many more global cooldowns fit before the buff ends, and shows \"Last\" during the final one. It follows your haste; when haste changes in combat the count catches up after combat."]))
    end
    if #rows == 0 then return end
    add({ type = "header", label = L["Text"] })
    for _, s in ipairs(rows) do add(s) end
end

------------------------------------------------------------
-- 顏色（原本資源條頁「顏色與條件」裡逐資源的那一段）
------------------------------------------------------------

-- 醉仙緩勁第 3／4 段的顏色：標籤是門檻本身（≥ N%），跟著滑桿改 ⇒ 標籤自己畫、Refresh 時重寫
-- （共用層的色票列標籤建好就固定，門檻放進表單簽章的話拖一次滑桿就多一份表單）
local TIER_ROW_H = 26
local function StaggerTierColorRow(tier)
    local R = ns.Resources
    return { type = "custom", h = TIER_ROW_H, noReset = true, build = function(parent, x, y, width, ctx)
        local cy = y - TIER_ROW_H / 2
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontNormal)
        fs:SetJustifyH("RIGHT")
        fs:SetWidth(LABEL_W)
        fs:SetPoint("RIGHT", parent, "TOPLEFT", x - CTRL_GAP, cy)
        local cp = W.CreateColorPicker(parent, nil, false, function(r, g, b)
            local c = Cfg()
            if not c then return end
            local colors = type(c.colors) == "table" and c.colors or {}
            c.colors = colors
            if type(colors.Stagger) ~= "table" then colors.Stagger = {} end
            colors.Stagger[tier .. "Color"] = { r = r, g = g, b = b, a = 1 }
            Touched(ctx)
        end)
        cp:SetPoint("LEFT", parent, "TOPLEFT", x, cy)
        local function Refresh()
            local c = Cfg()
            fs:SetText(R.StaggerLabel(tier, c))
            cp:SetColor(R.ResolveColor(c, "Stagger", tier .. "Color"))
        end
        Refresh()
        return TIER_ROW_H, Refresh
    end }
end

-- 血量門檻那一列：按鈕寫著目前筆數，點開是編輯器（Options/HealthThresholds.lua）
local function HealthThresholdRow()
    return { type = "custom", label = "", h = 30, noReset = true, build = function(parent, x, y)
        local btn = W.CreateButton(parent, L["Health thresholds"], "normal", 160, 22)
        btn:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local function UpdateText()
            btn:SetText(("%s  (%d)"):format(L["Health thresholds"], ns.HealthThresholds.Count()))
            W.FitButton(btn, 160, 22)
        end
        btn:SetScript("OnClick", function() ns.HealthThresholds.Open(UpdateText) end)
        UpdateText()
        return 30, UpdateText
    end }
end

local function AppendColors(add, key, info)
    local R = ns.Resources
    add({ type = "header", label = L["Colors"] })
    add(BS("color", "colors." .. key .. ".color", L["Color"], { hasAlpha = false }))
    if key == "ComboPoints" then
        add(BS("color", "colors.ComboPoints.chargedColor", L["Charged color"], { hasAlpha = false }))
        add(BS("color", "colors.ComboPoints.chargedEmptyColor", L["Charged (empty)"], { hasAlpha = false }))
        add(Note(L["Some combo points become charged (the Rogue's Supercharger, the Feral druid's Overflowing Power). The dim shade marks a charged point you haven't filled yet."]))
    elseif key == "Stagger" then
        -- 中度／重度的標籤是暴雪自己的減益名（中度醉仙緩勁、重度醉仙緩勁）
        add(BS("color", "colors.Stagger.moderateColor", R.StaggerLabel("moderate"), { hasAlpha = false }))
        add(BS("color", "colors.Stagger.heavyColor", R.StaggerLabel("heavy"), { hasAlpha = false }))
        add(BS("slider", "staggerModerateAt", L["Moderate threshold (percent of max health)"], { min = 1, max = 100, step = 1 }))
        add(BS("slider", "staggerHeavyAt", L["Heavy threshold (percent of max health)"], { min = 1, max = 200, step = 1 }))
        -- 第 3／4 段：開關＋門檻＋顏色（標籤是門檻本身，見 StaggerTierColorRow）
        add(BS("toggle", "staggerTier3Enabled", L["Third tier"]))
        add(BS("slider", "staggerTier3At", L["Third tier threshold (percent of max health)"], { min = 1, max = R.STAGGER_CEILING_MAX, step = 1 }))
        add(StaggerTierColorRow("tier3"))
        add(BS("toggle", "staggerTier4Enabled", L["Fourth tier"]))
        add(BS("slider", "staggerTier4At", L["Fourth tier threshold (percent of max health)"], { min = 1, max = R.STAGGER_CEILING_MAX, step = 1 }))
        add(StaggerTierColorRow("tier4"))
        add(Note(L["The third and fourth tiers add colors above heavy stagger. Raise \"Full bar at\" above 100 to see them fill on the bar."]))
        add(BS("slider", "staggerCeiling", L["Full bar at (percent of max health)"], { min = 10, max = R.STAGGER_CEILING_MAX, step = 5 }))
        add(Note(L["The color follows how much of your max health is staggered. In instanced combat the numbers are sometimes unreadable; those updates keep the previous color and bar scale."]))
    elseif key == "IgnorePain" then
        add(Note(L["Shows only your own Ignore Pain shield, as a percent of how big it can get; the game fills it in itself, so it stays right in combat. Showing the value on the bar prints the percent. Until the bar is ready (for example right after logging in during combat) it falls back to the total of every absorb shield on you, where a full bar is 30 percent of your max health."]))
    elseif key == "MaelstromWeapon" then
        add(BS("toggle", "maelstromFold", L["Fold into 5 segments"]))
        add(Note(L["Stacks 6 to 10 fill the same 5 segments again on top, in the overflow color. Condition colors only apply to the first layer."]))
        add(BS("color", "colors.MaelstromWeapon.overflowColor", L["Overflow color"], { hasAlpha = false }))
    elseif key == "SoulShards" then
        add(Note(L["Destruction shows shard fragments: the segment that is filling up is a shade darker, and the number on the bar has one decimal."]))
    elseif key == "Essence" then
        add(Note(L["The next segment fills up as Essence recharges, a shade darker."]))
    elseif key == "CrusadingStrikes" then
        add(BS("color", "colors.CrusadingStrikes.backColor", L["Background color"], { hasAlpha = true }))
        add(BS("dropdown", "crusadingFill", L["Bar fills with"], { items = CRUSADING_FILL_ITEMS }))
        add(BS("toggle", "crusadingHideBar", L["Hide Crusading Strikes on the buff bars"]))
        -- 沒在暴雪的追蹤量條裡 ⇒ 這一列沒有來源、一直空著：紅字講清楚（戰鬥中查不到就不講，不猜）
        if R.CrusadingTracked() == "no" then
            add(Note("|cffff5555" .. L["Crusading Strikes isn't in the Tracked Bars row of Blizzard's Cooldown Manager, so this row stays empty. Add it there (Edit Mode → Cooldown Manager → Tracked Bars)."] .. "|r"))
        end
        add(Note(L["This row copies Blizzard's Crusading Strikes bar, so Crusading Strikes must stay in the Tracked Bars row of Blizzard's Cooldown Manager. With the option above on, that bar is taken off the buff bars while this row shows; it keeps updating out of sight. This row has its own height, shows no number, and condition rules don't apply."]))
    elseif key == "Ironfur" then
        add(Note(L["One segment per active application, each draining with its own remaining time."]))
    elseif key == "Health" then
        add(BS("toggle", "healthClassColor", L["Use the class color for the fill"]))
        add(Note(L["While this is on, the color above isn't used."]))
        add(BS("toggle", "healthThresholdEnabled", L["Recolor below a threshold"]))
        add(Note(L["Once health drops below a threshold, the bar switches to that threshold's color. The game decides which side of the line you are on, so it also works in instanced combat."]))
        add(HealthThresholdRow())
    end
    if info.crusading then
        -- 征戰聖擊的說明在上面那段（鏡射暴雪的追蹤量條）
    elseif info.mode == "auraTimer" then
        -- 剩餘時間條：秒數由引擎印（數值文字適用），條件規則不適用
        add(Note(L["%s: the game runs this timer itself, so it stays right in combat. The bar drains with the buff's remaining time and stays empty while you don't have it; showing the value on the bar prints the seconds left. Condition rules don't apply."]:format(R.Name(key))))
    elseif not R.SupportsConditions(key) and not (info.health or info.mode == "auraPct") then
        -- 血量不印這句（條件規則不適用由門檻換色那段帶過）
        add(Note(L["%s: the game fills this row in itself, so it stays right in combat; condition rules and value text don't apply."]:format(R.Name(key))))
    end
end

local function Controls(key)
    local R = ns.Resources
    local info = R.Info(key) or {}
    local list = {}
    local function add(s) list[#list + 1] = s end
    add({ type = "header", label = L["Layout"] })
    add(BS("slider", "heights." .. key, L["Height"], {
        min = R.HEIGHT_MIN, max = R.HEIGHT_MAX, step = 1,
        get = function() return R.KeyRowHeight(Cfg(), key) end,
        set = function(_, v) R.SetKeyHeight(Cfg(), key, v) end,
    }))
    add(Note(L["Height is per resource and shared by every specialization too."]))
    -- 「長條上顯示數值」放在版面、不看「跟隨」（使用者 2026-10-03 指定）：這一列自己存，沒存＝照資源條的全域值
    -- （右鍵重設＝清掉＝回到全域）；字型、字級仍在外觀那一節跟著「跟隨」走
    if not info.noText then
        add(BS("toggle", "style." .. key .. ".showText", L["Show value on the bar"], {
            get = function()
                local own = OwnStyle(key)
                if own and own.showText ~= nil then return own.showText and true or false end
                local c = Cfg()
                return c and c.showText and true or false
            end,
        }))
        add(Note(L["Starts out following the Class Resources tab; right-click to follow it again."]))
    end
    AppendStyle(add, key, info)
    AppendNumbers(add, key, info)
    AppendColors(add, key, info)
    -- 條件規則只給 Lua 讀得到值的列（引擎寫的、血量沒有值可比）；只這一種資源，編輯器不出「編輯對象」下拉
    if R.SupportsConditions(key) then ns.ResourceConditionsUI.Append(list, { key }) end
    return list
end

------------------------------------------------------------
-- 視窗
------------------------------------------------------------
local frame, scroll
local cur                      -- 現在開的資源 key
local forms = {}               -- 簽章 → 表單（frame 刪不掉，形狀一樣就重用）

local function Signature(key)
    local R = ns.Resources
    local info = R.Info(key) or {}
    local cfg = Cfg() or {}
    return table.concat({
        key,
        R.SupportsConditions(key) and ns.ResourceConditionsUI.FormSignature({ key }) or "-",
        -- 氣漩武器摺疊改了格數：條件規則的「第幾格」選單跟著換
        (info.foldable and cfg.maelstromFold) and "f" or "-",
        -- 征戰聖擊不在追蹤量條裡時多一行紅字
        info.crusading and R.CrusadingTracked() or "-",
    }, "|")
end

local ShowForm                 -- 前置宣告（OnApply 要用）

local function OnApply(spec)
    ns.Resources.Apply()
    if ns.Pips then ns.Pips.Apply() end
    -- 顏色與條件規則：跟隨我們顏色的插件重畫（合併節流）
    if ns.NotifyResourceStyle then ns.NotifyResourceStyle() end
    if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
    -- 形狀可能變了（規則增刪、摺疊開關）：延一幀再比對，不在按鈕的處理器裡換表單。
    -- 資源條頁開著的話一起重讀（「這個專精要顯示哪些」那幾列的狀態）
    ns.Defer(function()
        if frame and frame:IsShown() and cur and (frame.sig ~= Signature(cur) or (spec and spec.refreshPage)) then
            ShowForm(false)
        end
        local page = Options.GetPage(KEY)
        if page and page:IsVisible() and page.RefreshForm then page:RefreshForm() end
    end)
end

-- 視窗高度：內容少就縮、最多 MAX_H。keepTop：換表單形狀時上緣不動（往下長）。
-- 開窗時**貼在設定視窗右邊**（右邊放不下改左邊，再不行交給 PlaceClamped 平移）——跟逐法術面板、挑選器同一套：
-- 蓋在設定視窗正中央的話，「這個專精要顯示哪些」那排被遮住，要換另一種資源得先關窗
local function Fit(form, keepTop)
    local h = math.min(MAX_H, PAD + HEAD_H + form.height + PAD)
    local parent = frame:GetParent()
    local top, pb = frame:GetTop(), parent and parent:GetBottom()
    local pcx = parent and parent:GetCenter()
    local fcx = frame:GetCenter()
    P.Height(frame, h)
    if keepTop and top and pb and pcx and fcx then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", parent, "BOTTOM", fcx - pcx, top - pb)
    else
        local pts = { "TOPLEFT", parent, "TOPRIGHT", 6, 0 }
        local right, sw = parent and parent:GetRight(), UIParent:GetRight()
        if right and sw and right + WIDTH + 10 > sw then
            pts = { "TOPRIGHT", parent, "TOPLEFT", -6, 0 }
        end
        W.PlaceClamped(frame, pts)
    end
    return h - PAD - HEAD_H - PAD
end

ShowForm = function(reset)
    if not (frame and cur) then return end
    local sig = Signature(cur)
    local form = forms[sig]
    if not form then
        local ctx = ns.Specs.MakeCtx({ mode = "panel", key = KEY }, OnApply)
        form = ns.Specs.BuildForm(scroll.child, Controls(cur), ctx, FORM_W)
        forms[sig] = form
    end
    for _, fm in pairs(forms) do fm.content:SetShown(fm == form) end
    -- 同一種資源換表單形狀（規則增刪）：維持捲動位置與上緣；換資源或剛開窗：捲回最上面、置中
    local keep = (not reset) and scroll:GetVerticalScroll() or 0
    frame.form, frame.sig = form, sig
    local viewH = Fit(form, not reset)
    scroll:SetContentHeight(form.height)
    scroll:SetVerticalScroll(math.min(keep, math.max(0, form.height - viewH)))
    form:Refresh()
end

local function Build()
    if frame then return end
    frame = W.CreateFrame(nil, Options.panel, WIDTH, 300)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetBackdropBorderColor(W.Accent(1))
    frame:SetPoint("CENTER")
    frame:Hide()
    W.CloseOnEscape(frame)

    local close = W.CreateButton(frame, "", "red", 18, 18)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(10, 10)
    x:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    P.Size(icon, 20, 20)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", PAD, -PAD + 2)
    frame.icon = icon
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    frame.title = title              -- 錨點在 SetHeader（有沒有圖示兩種排法）

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 4, -(PAD + HEAD_H))
    holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, PAD)
    scroll = W.CreateScrollFrame(holder)

    -- 血量門檻的彈窗跟著這個視窗走（它改的是這一種資源）
    frame:HookScript("OnHide", function()
        if ns.HealthThresholds and ns.HealthThresholds.Close then ns.HealthThresholds.Close() end
    end)

    ns.RegisterCallback("OptionsHidden", "resourcesettings", function() frame:Hide() end)
    ns.RegisterCallback("SpecChanged", "resourcesettings", function() frame:Hide() end)
    ns.RegisterCallback("ProfileChanged", "resourcesettings", function() frame:Hide() end)
end

-- 標題：資源名；有對應的法術（R.Info(key).nameSpell）就在前面放它的圖示
local function SetHeader(key)
    local R = ns.Resources
    local info = R.Info(key) or {}
    local tex
    if info.nameSpell and C_Spell and C_Spell.GetSpellTexture then
        local ok, t = pcall(C_Spell.GetSpellTexture, info.nameSpell)
        if ok and not ns.IsSecret(t) and t ~= nil then tex = t end
    end
    frame.icon:SetShown(tex ~= nil)
    if tex then frame.icon:SetTexture(tex) end
    frame.title:ClearAllPoints()
    if tex then
        frame.title:SetPoint("LEFT", frame.icon, "RIGHT", 8, 0)
    else
        frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD - 1)
    end
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
    frame.title:SetText(R.Name(key))
end

function RS.Open(key)
    if type(key) ~= "string" or not ns.Resources.Info(key) or not Cfg() then return end
    Build()
    if not frame then return end
    cur = key
    SetHeader(key)
    -- 先 Show 再建表單：說明列的換行高度要在顯示中才量得準
    frame:Show()
    ShowForm(true)
end

function RS.Close()
    if frame then frame:Hide() end
end

function RS.Refresh()
    if not (frame and frame:IsShown() and cur) then return end
    if frame.sig ~= Signature(cur) then
        ShowForm(false)
    elseif frame.form then
        frame.form:Refresh()
    end
end
