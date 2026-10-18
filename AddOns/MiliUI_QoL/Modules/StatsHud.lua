------------------------------------------------------------
-- MiliUI_QoL: 畫面上顯示屬性（HUD，預設關閉；2026-10-15 從 MiliUI_Skin 搬來）
--
-- 做法照 EllesmereUI QoL 的 Secondary Stats overlay（EllesmereUIQoL.lua 1985-2560）：
--   * **一個** FontString，每列「標籤: 數值」，整塊用 `SetFormattedText` 一次畫完——
--     數值當參數交給引擎（秘密值照樣畫得出來、戰鬥中照樣會動，Libs/MiliUIStats.lua 檔頭）；
--   * 事件驅動、同一幀合併一次；
--   * 尺寸只在「這一輪全部明碼」時量，量到的寬高還要再問一次 IsSecret，
--     不是明碼就沿用上一次的尺寸（有限次數的重試，脫戰那一發 PLAYER_REGEN_ENABLED
--     也會再畫一次）；
--   * 位置存**邊錨**（TOPLEFT），不存中心：尺寸變了中心會漂（EUI 的理由）。
-- 設定項照 SimpleStatsPanel（每個屬性一個開關＋顏色、字級、縮放）再加使用者要的：
-- 標籤完整／縮寫／不顯示、數值格式、% 符號、標籤顏色模式、數值同色、描邊（含像素字體
-- 的 MONOCHROME）、陰影、背景、顯示時機、不顯示數值為 0 的列（`hideZero`，預設開，
-- 2026-10-19 使用者要的：只對定義帶 `hideZero` 的屬性＝次要四項、第三三項，暴雪自己也是
-- hideAt = 0；明碼才判斷，秘密時沿用上一次的可見性，跟清單同一套規則）。設定在角色面板的齒輪（CharacterStatsSettings.lua）
-- 與 /mqol 的「角色面板」頁，全部即時生效，存 `db.charSheet.hud`。
--
-- 可拖曳 ＝「角色面板的設定面板開著」或「暴雪編輯模式開著」（兩者都只在 hud.enabled 時）。
-- 可拖曳時強制顯示（不管顯示時機）、畫一圈 1px 職業色邊當提示、吃滑鼠；平常整塊
-- 不吃滑鼠（點得穿）。磁吸走套組的 MiliUISnap（`Libs/MiliUISnap.lua`）：只**對齊**，不貼附。
--
-- 計算與清單共用（`ns.Stats`、`X.SectionColor`）。
--
-- ## 刻意沒做
--
-- * 移動速度——「速度」是第三屬性那個（`GetSpeed`），不是移動速度。
-- * 自訂排序——順序固定（主屬性、耐力、次要四項、第三三項、強度、護甲）。
--
------------------------------------------------------------
-- ## 對暴雪物件的接觸面
--
-- | 物件 | 動作 |
-- |---|---|
-- | UIParent | 我們的框的 parent ＋ 錨點；讀 GetLeft／GetTop／GetEffectiveScale 換算位置 |
-- | EditModeManagerFrame | `HookScript("OnShow"/"OnHide")`、`hooksecurefunc("EnterEditMode"/"ExitEditMode")`、EventRegistry 的 EditMode.Enter／Exit（後置勾，只改自己的狀態）；讀 `IsShown()` |
-- | GameTooltip | SetOwner／SetText／AddLine／Show／Hide（可拖曳時滑過的說明） |
--
-- 寫入暴雪欄位：無。我們的框是普通框（沒有 secure 子物件）⇒ 戰鬥中顯示、隱藏、拖曳都合法。
------------------------------------------------------------
local _, ns = ...

local X = ns.CharSheet
local C = X.C
local S = ns.Secret
local Stats = ns.Stats

local Try = Stats.Try
local IsSecret = Stats.IsSecret

local PAD = 6             -- 字與框緣（背景／拖曳提示的邊）之間
local ROW_GAP = 3         -- 行距（SetSpacing）
local SNAP_KEY = "charStatsHud"   -- ⚠ 存檔內容（MiliUISnap 的 key），改名等於拆掉玩家的組合
local DEFAULT_POS = { x = 30, y = -200 }   -- 相對 UIParent 左上角，UIParent 單位（設定面板沒開時的退路）
local PANEL_GAP = 8                        -- 第一次開啟：擺在設定面板正下方，離它這麼遠
local MAX_HEALS = 5       -- 量不到尺寸時的重試次數上限（每次 1 秒）
local HUD_NAME = "畫面屬性"

-- 順序固定。def ＝ MiliUIStats 的 defKey；short ＝ 「標籤：縮寫」用的一字縮寫
-- （zhTW／zhCN 一字，其他語系用英文縮寫）。
local SHORT_ZH = GetLocale() == "zhTW" or GetLocale() == "zhCN"
local HUD_STATS = {
    { key = "primary",   def = "primary",     zh = "主", en = "P"  },
    { key = "stamina",   def = "stamina",     zh = "耐", en = "S"  },
    { key = "crit",      def = "crit",        zh = "爆", en = "C"  },
    { key = "haste",     def = "haste",       zh = "急", en = "H"  },
    { key = "mastery",   def = "mastery",     zh = "精", en = "M"  },
    { key = "vers",      def = "versatility", zh = "全", en = "V"  },
    { key = "leech",     def = "lifesteal",   zh = "汲", en = "L"  },
    { key = "avoidance", def = "avoidance",   zh = "迴", en = "A"  },
    { key = "speed",     def = "speed",       zh = "速", en = "Sp" },
    { key = "power",     def = "power",       zh = "攻", en = "AP" },
    { key = "armor",     def = "armor",       zh = "甲", en = "Ar" },
}

local Hud = {}
X.Hud = Hud
Hud.STATS = HUD_STATS

local function HDB()
    return X.DB().hud
end

local frame, text, bd, selection
local inCombat, inInstance, editMode = false, false, false
local heals = 0
local lastVisible = {}   -- [statKey] = hideZero 上一次明碼時的可見性（秘密時沿用；沒記過就當可見）

local function Short(st)
    return SHORT_ZH and st.zh or st.en
end

-- 這一列的標籤顏色（{ r, g, b }）。分區色含玩家在清單裡換過的（statsColors）。
function Hud.StatColor(st)
    local h = HDB()
    local sectionColor = X.SectionColor and X.SectionColor(Stats.SectionOf[st.def]) or C.text
    if h.colorMode == "class" then
        return { X.Accent() }
    elseif h.colorMode == "custom" then
        local c = type(h.colors) == "table" and h.colors[st.key]
        if type(c) == "table" and type(c[1]) == "number" then return c end
    end
    return sectionColor
end

local function Hex(c)
    return format("%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

------------------------------------------------------------
-- 可拖曳／顯示條件
------------------------------------------------------------
local function Draggable()
    local h = HDB()
    if not h.enabled then return false end
    return editMode or (X.SettingsShown and X.SettingsShown()) or false
end

local function ShouldShow()
    local h = HDB()
    if not h.enabled then return false end
    if Draggable() then return true end
    if h.when == "combat" then return inCombat end
    if h.when == "instance" then return inInstance end
    return true
end

------------------------------------------------------------
-- 位置（存 UIParent 單位；SetPoint 的偏移是框自己的單位 ⇒ 除以框的 scale）
------------------------------------------------------------
-- 沒存過位置：設定面板開著就擺在它正下方（左緣對齊）並**存起來**——面板跟著角色面板
-- 關掉之後 HUD 要留在原地，不能每次都重算。面板沒開才退到 DEFAULT_POS（不存）。
local function Pos()
    local p = HDB().pos
    if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then return p end
    -- ⚠ 不能寫 `X.SettingsRect and X.SettingsRect()`：`and` 會把第二個回傳值截掉
    --   （.claude/notes/wow-lua-and-or-pitfalls.md），下緣永遠是 nil ⇒ 退回舊預設位置
    local l, b
    if X.SettingsRect then l, b = X.SettingsRect() end
    if l and b then
        p = { point = "TOPLEFT", x = math.floor(l + 0.5), y = math.floor(b - PANEL_GAP + 0.5) }
        HDB().pos = p
        return p
    end
    return DEFAULT_POS
end

local function ApplyPos()
    local p = Pos()
    local s = frame:GetScale() or 1
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p.x / s, p.y / s)
    if ns.Snap then ns.Snap.Restore(SNAP_KEY) end
end

local function SavePos()
    local l, t = frame:GetLeft(), frame:GetTop()
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    if not (l and t and pl and pt) then return end
    local s = frame:GetScale() or 1
    HDB().pos = {
        point = "TOPLEFT",
        x = math.floor(l * s - pl + 0.5),
        y = math.floor(t * s - pt + 0.5),
    }
end

------------------------------------------------------------
-- 畫
------------------------------------------------------------
local Render   -- forward

local function ArmHeal()
    if heals >= MAX_HEALS then return end
    heals = heals + 1
    C_Timer.After(1, function() Render() end)
end

-- 量尺寸：只在這一輪全部明碼時呼叫。度量本身也可能是秘密（上一次排版餵過秘密值），
-- 所以量到的值還要再問一次；不是明碼就沿用上一次的尺寸、排一次重試。
local function Measure()
    local ok, w, h = pcall(function() return text:GetStringWidth(), text:GetStringHeight() end)
    if not ok or IsSecret(w) or IsSecret(h) or type(w) ~= "number" or type(h) ~= "number" then
        ArmHeal()
        return
    end
    heals = 0
    frame:SetSize(math.max(w, 1) + PAD * 2, math.max(h, 1) + PAD * 2)
end

function Render()
    if not frame or not frame:IsShown() then return end
    local h = HDB()
    local c = Stats.BuildContext(h.valueFormat)
    local rows, args = {}, { n = 0 }
    local anySecret = false
    for _, st in ipairs(HUD_STATS) do
        local def = Stats.DefByKey[st.def]
        if def and h.stats[st.key] and (def.show == nil or def.show(c)) then
            local ok, v, v2 = Try("StatsHud." .. st.key, def.value, c)
            if not ok then v, v2 = nil, nil end
            -- hideZero：明碼才判斷；秘密時維持上一次的可見性（第一次就當可見）
            local visible = true
            if h.hideZero ~= false and def.hideZero and v ~= nil then
                if IsSecret(v) then
                    visible = lastVisible[st.key] ~= false
                else
                    visible = v ~= 0
                    lastVisible[st.key] = visible
                end
            end
            if visible then
                local tmpl, rowArgs, secret = Stats.ValueTemplate(def, c, v, v2, h.percentSign ~= false)
                for i = 1, rowArgs.n do
                    args.n = args.n + 1
                    args[args.n] = rowArgs[i]
                end
                if secret then anySecret = true end
                local hex = Hex(Hud.StatColor(st))
                local valHex = h.valueColored and hex or "ffffff"
                if h.labelStyle == "none" then
                    rows[#rows + 1] = "|cff" .. valHex .. tmpl .. "|r"
                else
                    local label = (h.labelStyle == "short") and Short(st) or def.label(c)
                    rows[#rows + 1] = "|cff" .. hex .. Stats.Esc(label) .. ":|r |cff" .. valHex .. tmpl .. "|r"
                end
            end
        end
    end
    -- 引擎把參數填進 template——秘密值從頭到尾沒在 Lua 裡被讀過
    text:SetFormattedText(table.concat(rows, "\n"), unpack(args, 1, args.n))
    if not anySecret then Measure() end
end

local pending = false
local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Render()
    end)
end

------------------------------------------------------------
-- 外觀
------------------------------------------------------------
local function ApplyFont()
    local h = HDB()
    text:SetFont(X.Font(), h.fontSize or 12, h.outline or "")
    if h.shadow ~= false then
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
    else
        text:SetShadowOffset(0, 0)
    end
    text:SetSpacing(ROW_GAP)
end

local function UpdateChrome()
    local h = HDB()
    local drag = Draggable()
    frame:EnableMouse(drag)
    bd:SetFill(X.HUD_FILL)
    bd:SetBorder({ X.Accent() })
    bd:SetFillShown(h.backdrop)
    -- 暴雪編輯模式：藍色選取框（跟暴雪自己的系統同一款）取代職業色邊；設定面板開著時照舊職業色邊
    local blue = editMode and h.enabled
    if selection then
        if blue then selection:ShowHighlighted() else selection:Hide() end
    end
    bd:SetBorderShown(h.backdrop or (drag and not blue))
end

local function UpdateVisibility()
    if not frame then return end
    frame:SetShown(ShouldShow())
end

------------------------------------------------------------
-- 事件：顯示時機那幾個常駐（框藏著也要知道什麼時候該出來）；讀值那幾個只在顯示中註冊
------------------------------------------------------------
local STATE_EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
}
local UNIT_EVENTS = {
    "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_SPELL_HASTE",
    "UNIT_MAXHEALTH", "UNIT_ATTACK_SPEED",
}
local STAT_EVENTS = {
    "COMBAT_RATING_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "MASTERY_UPDATE", "SPELL_POWER_CHANGED",
    "PLAYER_DAMAGE_DONE_MODS", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
}

local function RegisterStatEvents()
    -- ⚠ unit 事件一律 RegisterUnitEvent：處理器裡**不比對 arg1**（12.1 的 unit token 可能是秘密字串）
    for _, ev in ipairs(UNIT_EVENTS) do pcall(frame.RegisterUnitEvent, frame, ev, "player") end
    for _, ev in ipairs(STAT_EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
end

local function UnregisterStatEvents()
    for _, ev in ipairs(UNIT_EVENTS) do pcall(frame.UnregisterEvent, frame, ev) end
    for _, ev in ipairs(STAT_EVENTS) do pcall(frame.UnregisterEvent, frame, ev) end
end

local function RegisterStateEvents()
    for _, ev in ipairs(STATE_EVENTS) do pcall(frame.RegisterEvent, frame, ev) end
end

local function ReadInstance()
    inInstance = S.ToBool((IsInInstance())) == true
end

local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- 這一發派送當下 InCombatLockdown() 還是 false ⇒ 狀態自己記
        inCombat = true
        UpdateVisibility()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        UpdateVisibility()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ReadInstance()
        UpdateVisibility()
    end
    Queue()
end

------------------------------------------------------------
-- 暴雪編輯模式：開著時可以拖（三重訊號、全部冪等，技能 wow-editmode-draggable 第 4 節；
-- 後置勾，只改自己的狀態；不寫它的任何欄位）
------------------------------------------------------------
local editHooked = false
local function SetEditMode(on)
    on = on and true or false
    if editMode == on then return end
    editMode = on
    Hud.UpdateDraggable()
end

local function HookEditMode()
    local em = _G.EditModeManagerFrame
    if editHooked or not em then return end
    editHooked = true
    em:HookScript("OnShow", function() SetEditMode(true) end)
    em:HookScript("OnHide", function() SetEditMode(false) end)
    if type(em.EnterEditMode) == "function" then
        hooksecurefunc(em, "EnterEditMode", function() SetEditMode(true) end)
    end
    if type(em.ExitEditMode) == "function" then
        hooksecurefunc(em, "ExitEditMode", function() SetEditMode(false) end)
    end
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", function() SetEditMode(true) end, "MiliUIQoL_StatsHud")
        EventRegistry:RegisterCallback("EditMode.Exit", function() SetEditMode(false) end, "MiliUIQoL_StatsHud")
    end
    editMode = S.ToBool(em:IsShown()) == true
end

------------------------------------------------------------
-- 建框（第一次在設定裡打開、或登入時已經是開的）
------------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("LOW")
    frame:SetSize(120, 60)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetUserPlaced(false)   -- 位置自己存 SavedVariables，不給版面快取管
    frame:EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    bd = X.Backdrop(frame, X.HUD_FILL, { X.Accent() })

    text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    text:SetJustifyH("LEFT")
    ApplyFont()

    -- 編輯模式的藍色選取框（照 wow-editmode-draggable 技能：借暴雪的
    -- `EditModeSystemSelectionTemplate` 當視覺，不註冊真的 Edit Mode 系統）。
    -- ⚠ 建框時就建，不要等進了編輯模式才建；模板的 OnMouseDown 會叫
    --   `EditModeManagerFrame:SelectSystem(self.parent)`——我們不是真的系統，必須 no-op 化，
    --   不然暴雪帶著我們的 taint 掃過每一個已註冊系統（動作條在內），戰鬥中才爆。
    -- 標籤走 `self.system:GetSystemName()`，塞個 stub。建不出來就自己畫一個藍框頂著。
    local okSel, sel = pcall(CreateFrame, "Frame", nil, frame, "EditModeSystemSelectionTemplate")
    if okSel and sel then
        sel:SetScript("OnMouseDown", function() end)
        sel.system = { GetSystemName = function() return HUD_NAME end }
    else
        sel = CreateFrame("Frame", nil, frame)
        X.Backdrop(sel, { 0.25, 0.6, 1, 0.15 }, { 0.25, 0.6, 1, 0.9 })
        sel.ShowHighlighted = sel.Show
    end
    sel:SetAllPoints(frame)
    sel:EnableMouse(true)
    sel:RegisterForDrag("LeftButton")
    -- 藍框蓋在整塊上面、吃掉滑鼠 ⇒ 拖曳從它進來，轉給框自己的處理器（StartMoving 動的是父框）
    sel:SetScript("OnDragStart", function() frame:GetScript("OnDragStart")(frame) end)
    sel:SetScript("OnDragStop", function() frame:GetScript("OnDragStop")(frame) end)
    sel:Hide()
    selection = sel

    frame:SetScript("OnShow", function()
        RegisterStatEvents()
        Render()
    end)
    frame:SetScript("OnHide", UnregisterStatEvents)
    frame:SetScript("OnEvent", OnEvent)

    -- 普通框（沒有 secure 子物件）⇒ StartMoving 可用；保護框才要走技能的手動拖曳
    frame:SetScript("OnDragStart", function(self)
        if not Draggable() then return end
        if ns.Snap then ns.Snap.OnDragStart(SNAP_KEY) end
        self:StartMoving()
        self.moving = true
    end)
    frame:SetScript("OnDragStop", function(self)
        if not self.moving then return end
        self.moving = false
        self:StopMovingOrSizing()
        if ns.Snap then ns.Snap.OnDragStop(SNAP_KEY) end   -- 放手離得近就對齊（不貼附）
        SavePos()
        ApplyPos()
    end)
    frame:SetScript("OnEnter", function(self)
        if not Draggable() then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(HUD_NAME, 1, 1, 1)
        GameTooltip:AddLine("拖曳可以移動。", C.textDim[1], C.textDim[2], C.textDim[3])
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    if ns.Snap then
        ns.Snap.Register(SNAP_KEY, frame, {
            db = HDB,
            label = HUD_NAME,
            enabled = function() return HDB().enabled == true end,
        })
    end

    HookEditMode()
    inCombat = InCombatLockdown() and true or false
    ReadInstance()
    RegisterStateEvents()
    -- 設定改了（清單換色會影響分區色）：顯示中就重畫
    X.OnStatsChanged(function() Queue() end)
end

------------------------------------------------------------
-- 對外（設定面板用）
------------------------------------------------------------
-- 設定改了一律叫這支：沒建就建（開啟）、關了就收（框留著，frame 刪不掉）
function Hud.Apply()
    local h = HDB()
    if not h.enabled then
        if frame then
            frame:UnregisterAllEvents()
            frame:Hide()
        end
        return
    end
    if not frame then
        Build()
    else
        -- 關掉期間沒收事件：狀態重讀一次
        RegisterStateEvents()
        inCombat = InCombatLockdown() and true or false
        ReadInstance()
    end
    ApplyFont()
    frame:SetScale(h.scale or 1)
    ApplyPos()
    UpdateChrome()
    UpdateVisibility()
    Render()
end

-- 設定面板開關、編輯模式進出
function Hud.UpdateDraggable()
    if not frame then return end
    if frame.moving and not Draggable() then
        frame.moving = false
        frame:StopMovingOrSizing()
        SavePos()
        ApplyPos()
    end
    UpdateChrome()
    UpdateVisibility()
end

function Hud.ResetPosition()
    HDB().pos = nil
    if frame then ApplyPos() end
end

-- 登入：開著才建（沒有自己的 db 開關——看 hud.enabled）
X.Register(nil, function()
    if HDB().enabled then Hud.Apply() end
end)
