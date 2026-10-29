------------------------------------------------------------
-- 所有暴雪接觸點的唯一集中地
--
-- ⚠ 接觸面清單（要碰暴雪物件的新程式碼必須先過這張表）：
--   1. TooltipDataProcessor.AddTooltipPostCall（官方入口）
--   2. hooksecurefunc：GameTooltip_SetDefaultAnchor（Anchor.lua）、
--      GameTooltip.SetWorldCursor（Anchor.lua：世界游標的 Cursor 分支不經過 SetDefaultAnchor，後掛勾照設定重新定位；
--      內容已畫好 ⇒ 只 SetAnchorType／SetPoint，不 SetOwner）、
--      GameTooltip_AddInstructionLine、
--      ItemRefTooltip.SetHyperlink（Quest.lua）、InspectUnit（UnitInfo.lua）
--   3. HookScript("OnTooltipCleared")（清理暫態）、GameTooltipStatusBar 的 OnShow／OnHide
--      （我們的血條跟著引擎血條開關，Bar.OnEngineBar；掛勾裡只動自己的條）；
--      HookScript(GameTooltip, "OnShow")（Anchor.lua：戰鬥中隱藏的網，該藏就 Panel.Restore＋Hide，#8）
--   4. line FontString 的 SetText / SetTextColor（UnitLines.lua；暴雪每次
--      ProcessInfo 會重設所有行，寫入活不到 secure 讀取）
--   5. tip:AddLine / tip:Show（官方內容 API；Show 只在 ProcessInfo 之外呼叫）
--   6. 一次性視覺中和：NineSlice:SetAlpha(0)（Skin.lua）、
--      GameTooltipStatusBar:SetAlpha(0)、ItemRefCloseButton 造型
--   7. 全域字型物件（Fonts.lua）
--   8. SetOwner / SetAnchorType / SetPoint / SetScale / Hide 等定位 API（Anchor.lua、Skin.lua）
--   9. per-tip 狀態一律放 Skin.State[tip]，暴雪物件上零欄位寫入
--  10. 重繪面板（Panel/Native.lua）：tip:SetAlpha(0)／還原、tip:SetPadding(right, bottom,
--      left, top)／還原——定位類 C 端 setter，只在 panel 成功顯示時寫，Restore 寫回原值
--      （padding 只在「還是我們設的那個」時才寫回）。讀 GetPoint／GetLeft／GetWidth／
--      GetPadding 一律先過 S.IsSecret，秘密 ⇒ 整格退回原樣式。
--  11. ItemRefCloseButton 的 ClearAllPoints／SetPoint（Panel/Render.lua）：原生關閉鈕（跟著 tooltip 一起 alpha 0，
--      看不見但點得到）疊到 panel 畫的 × 上，退回時貼回 TOPRIGHT -4,-4。⚠ **不從我們的程式 Click() 它**：
--      它的 OnClick 是 HideUIPanel(ItemRefTooltip)，在污染的執行裡跑會連坐面板管理與比價管理器的共用狀態
--  12. hooksecurefunc(tip, "Show")／(tip, "SetShown")（Panel/Native.lua 的 HookShow）：暴雪的 Show 會把
--      alpha 改回 1、而且在 post-call 之後才叫 ⇒ 後掛勾同一幀壓回 0。只掛在用過面板的 tooltip 上、
--      面板沒在用時掛勾什麼都不做；掛勾裡只查 Skin.State、只呼叫 SetAlpha（與補回被清掉的 padding）
--  13. tip:SetClampRectInsets／還原（Panel/Native.lua 的 UpdateClamp）：接管期間原生**照暴雪的夾邊**，我們只替它
--      設夾邊範圍（四邊呼吸、上緣多留比價標籤）。C 端 setter，第一次藏原生時 GetClampRectInsets 記原值、Restore 寫回。
--      （2026-10-18～19 曾改成 SetClampedToScreen(false) 由面板自己夾：原生幾何變假、下游全被誤導，已改回）
--  14. hooksecurefunc(frame, "SetPoint")（Panel/Frame.lua 的 Panel.Follow；PLAYER_LOGIN 時對已知的隨行框自己掛，
--      MiliUITip_API.Adopt 的 followPanel 也會掛）：
--      **對象是別的插件自己建的框，不是暴雪物件**（外觀預覽）。它貼到有面板顯示中的 tooltip 時，掛勾裡把對象換成面板、
--      點與位移原樣、相鄰邊留縫；讀到的參數先過 S.IsSecret，重入旗標擋自己的 SetPoint，暴雪物件一個都不碰
--  15. hooksecurefunc(tip, "FadeOut")（下面的 OnFadeOut，TrackTip 時掛）：暴雪的 FadeOut＝原生全不透明停 1 秒、再花 1 秒淡掉，
--      只有世界中的單位／物件、暴雪頭像框滑開時叫（介面上的物品／法術是 OnLeave 直接 Hide）。
--      平常：原生在 alpha 0，淡不到面板 ⇒ 後掛勾讓**自己的面板**跟著淡，暴雪物件一個都不碰。
--      「滑開立即消失」開著：後掛勾裡 tip:Hide()（#8）——跟任何插件按鈕 OnLeave 的 GameTooltip:Hide() 同一種接觸
--  16. 單位的重繪面板（Panel/ReadUnit.lua）：面板接手時**不改寫暴雪的行**（#4 那條只在舊樣式跑），只讀 TooltipData
--      ＋明文 token 的 Unit API；對原生的寫入跟物品一樣只有 #10／#12／#13／#15。退回舊樣式時用 #5 的 tip:Show()
--      讓暴雪重跑一次這份內容（Panel.UnitFallback），之後的 post-call 走舊樣式
--  17. 戰鬥中按修飾鍵叫回藏掉的提示（Modules/Anchor.lua 的 watcher）：tip:SetUnit(unit)——secure delegate，污染的呼叫
--      也能安全顯示含秘密值的內容（世界單位不能改叫 SetWorldCursor：一般 mixin，整段 ProcessInfo 帶污染）。
--      tip:GetPrimaryTooltipInfo() 只拿那張表比身分（內容換過沒），不讀寫它的欄位；滑鼠離開時照 SetWorldCursor 的規則
--      tip:FadeOut()／Hide()（#8）
--  18. frame:SetIgnoreParentAlpha(true)（Panel/Frame.lua 的 Panel.AdoptSidecar；PLAYER_LOGIN 對已知的隨行框、
--      MiliUITip_API.Adopt 的 ignoreParentAlpha）：**對象是別的插件自己建的框**（外觀預覽每次顯示都 SetParent 到
--      我們接管的 tooltip 底下），原生被 #10 壓 0 時它才不會跟著透明。C 端 setter、冪等、暴雪物件一個都不碰
--
-- 不碰的：EmbeddedItemTooltip（UIWidget 會借走 → forbidden 大宗）、
-- 任何暴雪函式替換、SetScript。所有入口先 IsForbidden 閘，
-- 失敗方向 = 該次顯示原味樣式，不報錯。
------------------------------------------------------------
local ADDON, ns = ...

local S = ns.Secret
local Skin = ns.Skin

local TRACKED = {
    "GameTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "NamePlateTooltip",
    -- 好友名單滑過的 Battle.net 好友提示。不是 GameTooltip，是普通 Frame 繼承
    -- TooltipBackdropTemplate（一樣是 NineSlice 底），只換外觀、內容不經過 post-call
    "FriendsTooltip",
}

-- 共同入口閘：沒接管的 tooltip（例如 EmbeddedItemTooltip）、forbidden、db 未載入 → 全部跳過
local function Gate(tip)
    if not ns.db then return end
    local state = Skin.Get(tip)
    if not state then return end
    if S.IsForbiddenObject(tip) then return end
    return state
end

------------------------------------------------------------
-- post-call 處理器
------------------------------------------------------------
local function OnUnit(tip, data)
    local state = Gate(tip)
    if not state then return end
    if not tip.GetUnit then return end
    local ok, _, unit = pcall(tip.GetUnit, tip)
    if ns.logEnabled then
        ns.Log("OnUnit tip=%s getunit_ok=%s unit=%s state.unit=%s combat=%s",
            tip:GetName() or "?", tostring(ok), ns.Describe(unit),
            ns.Describe(state.unit), tostring(InCombatLockdown()))
    end
    if not ok or not unit then return end
    -- 重繪面板（玩家／NPC 兩個開關都關 ⇒ UnitWanted 一次查表就回 false，下面的舊樣式照舊，零成本）
    if ns.Panel.UnitWanted() then
        state.inUnitPostCall = true      -- 這裡面的退回不必重跑舊樣式（下面馬上就跑）
        local okTry, shown = xpcall(ns.Panel.TryUnit, ns.ReportError, tip, state, unit, data)
        if not okTry then ns.Panel.Fail(tip, state) end      -- 還在 inUnitPostCall 裡退：不重跑內容
        state.inUnitPostCall = nil
        if okTry and shown then
            -- 面板接手：不改寫暴雪的行、不加目標行；只記單位（目標輪詢／觀察資料刷新認這幾個欄位）
            state.unit = unit
            state.unitGuid = S.SafeCall(UnitGUID, unit)
            state.isUnitTip = true
            xpcall(ns.Model.OnUnit, ns.ReportError, tip, state, unit)
            if tip == GameTooltip then ns.Bar.Activate(tip, unit) end
            return
        end
    end
    -- xpcall + ReportError：這裡吞錯會讓「行寫了、著色沒跑」這種半套結果
    -- 靜默發生（實測抓過一次），至少要進 /mtip debug 的錯誤紀錄
    local applied = xpcall(ns.UnitLines.Apply, ns.ReportError, tip, state, unit, false)
    if not applied then return end
    xpcall(ns.Target.OnUnit, ns.ReportError, tip, state, unit)
    xpcall(ns.Model.OnUnit, ns.ReportError, tip, state, unit)
    if tip == GameTooltip then
        ns.Bar.Activate(tip, unit)
    end
end

-- 單位面板在 post-call 之外退回（對帳讀到秘密值、設定改了）：原生的行是暴雪原樣（面板接手時不改寫）⇒
-- 讓暴雪重跑一次這份內容（tip:Show()，接觸面 #5），同一個單位 1 秒內不接面板 ⇒ 那次 post-call 走舊樣式。
-- 只有 Try.lua 的 Restore 在「提示還顯示著同一個單位」時叫（Release／OnHide 那兩條 isUnitTip 已經被清掉）
-- block = false（設定改了）：不封鎖 ⇒ 重跑時照新設定接面板或走舊樣式
local function UnitFallback(tip, state, key, block)
    if block then
        state.unitBlockKey, state.unitBlockUntil = key, GetTime() + 1
    end
    if S.IsForbiddenObject(tip) then return end
    if ns.logEnabled then ns.Log("單位面板退回 ⇒ 舊樣式重跑 key=%s", tostring(key)) end
    tip:Show()
end

-- 記錄模式（/mtip record）＋重繪面板，物品與法術共用。在既有的 Apply 之後：
-- 面板要撿得到我們自己加的 ID 行；Try 出錯時一定要退回（不能留著 alpha 0 的原生）
local T_ITEM = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
local T_SPELL = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Spell

local function AfterApply(tip, state, kind, dataType, data)
    xpcall(ns.Record.OnPostCall, ns.ReportError, tip, kind, data)
    if not xpcall(ns.Panel.Try, ns.ReportError, tip, state, dataType, data) then
        ns.Panel.Fail(tip, state)
    end
end

local function OnItem(tip, data)
    local state = Gate(tip)
    if not state then return end
    ns.Bar.Deactivate(tip)
    local link
    if tip.GetItem then
        local ok, _, l = pcall(tip.GetItem, tip)
        if ok then link = l end
    end
    xpcall(ns.Item.Apply, ns.ReportError, tip, state, link)
    AfterApply(tip, state, "item", T_ITEM, data)
end

local function OnSpell(tip, data)
    local state = Gate(tip)
    if not state then return end
    if ns.logEnabled then
        ns.Log("OnSpell tip=%s data.id=%s", tip:GetName() or "?", ns.Describe(data and data.id))
    end
    ns.Bar.Deactivate(tip)
    local spellId = data and S.PlainNumber(data.id)
    xpcall(ns.Spell.Apply, ns.ReportError, tip, state, spellId)
    AfterApply(tip, state, "spell", T_SPELL, data)
end

local function OnUnitAura(tip, data)
    local state = Gate(tip)
    if not state then return end
    if ns.logEnabled then
        local iv, tid
        if data and type(data.args) == "table" and type(data.args[2]) == "table" then
            iv = data.args[2].intVal
        end
        if data and type(data.lines) == "table" and type(data.lines[1]) == "table" then
            tid = data.lines[1].tooltipID
        end
        ns.Log("OnUnitAura tip=%s has_args=%s intVal=%s data.id=%s lines1.tooltipID=%s",
            tip:GetName() or "?", tostring(data and data.args ~= nil),
            ns.Describe(iv), ns.Describe(data and data.id), ns.Describe(tid))
    end
    ns.Bar.Deactivate(tip)
    xpcall(ns.Spell.ApplyAura, ns.ReportError, tip, state, data)
end

------------------------------------------------------------
-- 巨集 / 動作條：解析出法術或物品再走對應管線
------------------------------------------------------------
local function ResolveSpellIdFromToken(token)
    if type(token) == "number" then return token end
    if type(token) == "string" and token ~= "" and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, token)
        if ok and type(info) == "table" and type(info.spellID) == "number" then
            return info.spellID
        end
    end
end

local function ResolveMacroPayload(tip, macroId)
    if tip and tip.GetPrimaryTooltipData then
        local ok, data = pcall(tip.GetPrimaryTooltipData, tip)
        if ok and type(data) == "table" and type(data.lines) == "table"
            and type(data.lines[1]) == "table" and type(data.lines[1].tooltipID) == "number" then
            return data.lines[1].tooltipID
        end
    end
    if type(macroId) == "number" and type(GetMacroSpell) == "function" then
        local ok, a, b, c = pcall(GetMacroSpell, macroId)
        if ok then
            local spellId = ResolveSpellIdFromToken(a) or ResolveSpellIdFromToken(b) or ResolveSpellIdFromToken(c)
            if spellId then return spellId end
        end
    end
    if type(macroId) == "number" and type(GetMacroItem) == "function" then
        local ok, macroItem = pcall(GetMacroItem, macroId)
        if ok and macroItem then
            local okInfo, _, itemLink = pcall(C_Item.GetItemInfo, macroItem)
            if okInfo and type(itemLink) == "string" and itemLink ~= "" then
                return nil, itemLink
            end
        end
    end
end

-- 巨集的 tooltipData 是 type=Macro、id=巨集編號、lines=解析出來那個法術／物品的行。重繪面板的
-- key（「同一件」）與圖示都認 data.id／data.hyperlink ⇒ 餵一份「法術／物品視角」的資料：id／hyperlink
-- 換成解析出來的、lines 原封（Collect 只讀 lines）。key 就跟直接滑過那個法術／物品一樣，面板一致
local function MacroView(data, dataType, id, link)
    return { type = dataType, id = id, hyperlink = link, lines = type(data) == "table" and data.lines or nil }
end

local function RouteMacroPayload(tip, state, data, spellId, itemLink)
    if itemLink then
        xpcall(ns.Item.Apply, ns.ReportError, tip, state, itemLink)
        local itemId = tonumber(itemLink:match("item:(%d+)"))
        AfterApply(tip, state, "item", T_ITEM, MacroView(data, T_ITEM, itemId, itemLink))
    elseif spellId then
        xpcall(ns.Spell.Apply, ns.ReportError, tip, state, spellId)
        AfterApply(tip, state, "spell", T_SPELL, MacroView(data, T_SPELL, spellId, nil))
    else
        -- 純指令巨集（/say 之類）：沒有法術／物品可畫，面板退回原生
        ns.Panel.Restore(tip, state)
    end
end

local function OnMacro(tip, data)
    local state = Gate(tip)
    if not state then return end
    local macroId = data and S.PlainNumber(data.id)
    local spellId, itemLink = ResolveMacroPayload(tip, macroId)
    if ns.logEnabled then
        ns.Log("OnMacro tip=%s macro=%s spell=%s item=%s", tip:GetName() or "?",
            ns.Describe(macroId), ns.Describe(spellId), ns.Describe(itemLink))
    end
    RouteMacroPayload(tip, state, data, spellId, itemLink)
end

-- （SetAction / SetMacro 的後掛勾已刪：動作條上的法術／物品／巨集提示都會
-- 產生型別化資料、由 post-call 在排版前處理。掛勾那條在戰鬥中延後一幀加行
-- ＝排版之後才塞 → ID 行掛在框體外面閃（TinyTooltip 一路帶過來的老毛病，
-- 使用者以為是官方 bug）。post-call 版本沒有這個時序問題。）

------------------------------------------------------------
-- 設定套用總入口（設定面板 / 載入時）
------------------------------------------------------------
function ns.ApplyAll()
    -- 重繪面板：設定版本進指紋（改了外觀要重畫）；顯示中的先退回，下一次 post-call 照新設定畫
    ns.Panel.settingsVersion = ns.Panel.settingsVersion + 1
    ns.Panel.RestoreAll()
    Skin.ApplyBaseAll()
    ns.Bar.ApplySettingsAll()
    ns.Fonts.Apply()
    ns.Fire("SettingsApplied")
end

------------------------------------------------------------
-- 滑開淡出（接觸面 #15）。暴雪預設是停 1 秒再淡 1 秒；游標錨點的提示這 2 秒還跟著游標走
------------------------------------------------------------
local function OnFadeOut(tip)
    local state = Gate(tip)
    if not state then return end
    local panel = state.panel
    if ns.db.general.instantHide then
        local ok, shown = pcall(tip.IsShown, tip)
        if not ok or S.IsSecret(shown) or not shown then return end
        -- 面板是獨立的框，tip 藏起來要下一幀才拆（OnSkinHide 延一幀）⇒ 先當場透明，不然晚一幀消失
        if panel and panel:IsShown() then ns.Panel.FadeOut(panel, true) end
        tip:Hide()
    elseif state.native and panel and panel:IsShown() then
        ns.Panel.FadeOut(panel)
    end
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
-- isPreview：設定視窗的預覽 tooltip（重繪面板要掛在設定視窗底下、跟著它的層級）
-- opts：原樣交給 Skin.Attach（目前只有 keepScale，見 `MiliUITip_API.Adopt`）
local function TrackTip(tip, isPreview, opts)
    if not tip or Skin.Get(tip) then return end
    local state = Skin.Attach(tip, opts)
    if state and isPreview then state.isPreview = true end
    -- 清理暫態（接觸面 #3）。HookScript 是後掛勾，安全。
    if tip.HasScript and tip:HasScript("OnTooltipCleared") then
        tip:HookScript("OnTooltipCleared", function(self)
            if S.IsForbiddenObject(self) then return end
            Skin.ClearTransient(self)
            ns.Panel.Release(self, Skin.Get(self))
        end)
    end
    if state and tip.FadeOut and not isPreview then hooksecurefunc(tip, "FadeOut", OnFadeOut) end
end

ns.TrackTip = TrackTip   -- 預覽 tooltip（Options/Preview.lua）也走同一條接管管線

local function Install()
    ns.Panel.UnitFallback = UnitFallback

    -- skin 接管
    for _, name in ipairs(TRACKED) do
        TrackTip(_G[name])
    end

    -- post-call（接觸面 #1）
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        local T = Enum.TooltipDataType
        if T.Unit then TooltipDataProcessor.AddTooltipPostCall(T.Unit, OnUnit) end
        if T.Item then TooltipDataProcessor.AddTooltipPostCall(T.Item, OnItem) end
        if T.Spell then TooltipDataProcessor.AddTooltipPostCall(T.Spell, OnSpell) end
        if T.UnitAura then TooltipDataProcessor.AddTooltipPostCall(T.UnitAura, OnUnitAura) end
        if T.Macro then TooltipDataProcessor.AddTooltipPostCall(T.Macro, OnMacro) end
    end

    -- 動作條 / 巨集（接觸面 #2）

    -- 右鍵提示：暴雪加進來的當下就移掉（接觸面 #2）
    if GameTooltip_AddInstructionLine then
        hooksecurefunc("GameTooltip_AddInstructionLine", function(tt)
            if tt ~= GameTooltip then return end
            local state = Gate(tt)
            if not state or not state.isUnitTip then return end
            ns.UnitLines.RemoveRightClickHint(tt)
        end)
    end

    -- 一次性視覺中和（接觸面 #6）：血條自己畫，暴雪那條藏掉
    if GameTooltipStatusBar and GameTooltipStatusBar.SetAlpha then
        pcall(GameTooltipStatusBar.SetAlpha, GameTooltipStatusBar, 0)
    end
    -- 引擎血條的 Show／Hide（暴雪的 post-call TooltipDataRules.HealthBar 照資料的 healthGUID SetWatch／ClearWatch）⇒ 我們的條跟著開關
    -- （接觸面 #3；Bar.lua 的 EngineBarShown）。後掛勾，裡面只查 Skin.State、只動自己的條
    local engineBar = GameTooltip and (GameTooltip.StatusBar or GameTooltipStatusBar)
    if engineBar and engineBar.HookScript then
        engineBar:HookScript("OnShow", function() ns.Bar.OnEngineBar(GameTooltip) end)
        engineBar:HookScript("OnHide", function() ns.Bar.OnEngineBar(GameTooltip) end)
    end
    if ItemRefCloseButton then
        ItemRefCloseButton:SetSize(14, 14)
        ItemRefCloseButton:SetPoint("TOPRIGHT", -4, -4)
        ItemRefCloseButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        ItemRefCloseButton:SetPushedTexture("Interface\\Buttons\\UI-StopButton")
        local tex = ItemRefCloseButton:GetNormalTexture()
        if tex then tex:SetVertexColor(0.9, 0.6, 0) end
    end
end

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        ns.DB.Init()
        ns.Fonts.Apply()
        Install()
        ns.ApplyAll()
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        -- NamePlateTooltip 這類可能比較晚才存在，補接管一次
        for _, tipName in ipairs(TRACKED) do
            TrackTip(_G[tipName])
        end
        -- 掛在我們的 tooltip 底下的別家框（外觀預覽）：原生壓 alpha 0 時不跟著透明、貼面板（#14／#18）
        ns.Panel.AdoptKnownSidecars()
        if C_AddOns.IsAddOnLoaded("TinyTooltip-Remake") then
            print("|cff4DD2FF[米利的滑鼠提示]|r |cffff5555偵測到 TinyTooltip-Remake 同時啟用——兩邊會重複改寫工具提示，請停用其中一個。|r")
        end
    end
end)
