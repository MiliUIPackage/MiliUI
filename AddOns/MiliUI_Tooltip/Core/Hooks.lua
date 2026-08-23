------------------------------------------------------------
-- 所有暴雪接觸點的唯一集中地
--
-- ⚠ 接觸面清單（要碰暴雪物件的新程式碼必須先過這張表）：
--   1. TooltipDataProcessor.AddTooltipPostCall（官方入口）
--   2. hooksecurefunc：GameTooltip_SetDefaultAnchor（Anchor.lua）、
--      GameTooltip_AddInstructionLine、GameTooltip.SetAction / SetMacro、
--      GameTooltip 的光環 setter 六支（Spell.lua）、
--      ItemRefTooltip.SetHyperlink（Quest.lua）、InspectUnit（UnitInfo.lua）
--   3. HookScript("OnTooltipCleared")（清理暫態）
--   4. line FontString 的 SetText / SetTextColor（UnitLines.lua；暴雪每次
--      ProcessInfo 會重設所有行，寫入活不到 secure 讀取）
--   5. tip:AddLine / tip:Show（官方內容 API；Show 只在 ProcessInfo 之外呼叫）
--   6. 一次性視覺中和：NineSlice:SetAlpha(0)（Skin.lua）、
--      GameTooltipStatusBar:SetAlpha(0)、ItemRefCloseButton 造型
--   7. 全域字型物件（Fonts.lua）
--   8. SetOwner / SetPoint / SetScale / Hide 等定位 API（Anchor.lua、Skin.lua）
--   9. per-tip 狀態一律放 Skin.State[tip]，暴雪物件上零欄位寫入
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
local function OnUnit(tip)
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

local function OnItem(tip)
    local state = Gate(tip)
    if not state then return end
    ns.Bar.Deactivate(tip)
    local link
    if tip.GetItem then
        local ok, _, l = pcall(tip.GetItem, tip)
        if ok then link = l end
    end
    xpcall(ns.Item.Apply, ns.ReportError, tip, state, link)
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
            local okInfo, _, itemLink = pcall(GetItemInfo, macroItem)
            if okInfo and type(itemLink) == "string" and itemLink ~= "" then
                return nil, itemLink
            end
        end
    end
end

local function RouteMacroPayload(tip, spellId, itemLink)
    local state = Gate(tip)
    if not state then return end
    if itemLink then
        xpcall(ns.Item.Apply, ns.ReportError, tip, state, itemLink)
    elseif spellId then
        xpcall(ns.Spell.Apply, ns.ReportError, tip, state, spellId)
    end
end

local function OnMacro(tip, data)
    local macroId = data and S.PlainNumber(data.id)
    local spellId, itemLink = ResolveMacroPayload(tip, macroId)
    RouteMacroPayload(tip, spellId, itemLink)
end

local function OnSetAction(tip, slot)
    if not Gate(tip) then return end
    local function doAction()
        local spellId, itemLink
        if type(slot) == "number" and type(GetActionInfo) == "function" then
            local ok, actionType, actionId = pcall(GetActionInfo, slot)
            if ok and actionType == "spell" then
                spellId = ResolveSpellIdFromToken(actionId)
            elseif ok and actionType == "item" and actionId then
                local okInfo, _, link = pcall(GetItemInfo, actionId)
                if okInfo and type(link) == "string" and link ~= "" then itemLink = link end
            elseif ok and actionType == "macro" then
                spellId, itemLink = ResolveMacroPayload(tip, actionId)
            end
        end
        if not spellId and not itemLink and tip.GetSpell then
            local ok, _, sid = pcall(tip.GetSpell, tip)
            if ok then spellId = S.PlainNumber(sid) end
        end
        RouteMacroPayload(tip, spellId, itemLink)
    end
    -- 戰鬥中延後一幀，斷開 secure 動作條路徑的 taint 鏈
    if InCombatLockdown() then
        C_Timer.After(0, function()
            if not S.IsForbiddenObject(tip) and tip:IsShown() then doAction() end
        end)
    else
        doAction()
    end
end

local function OnSetMacro(tip, macroId)
    if not Gate(tip) then return end
    local function doAction()
        local spellId, itemLink = ResolveMacroPayload(tip, macroId)
        RouteMacroPayload(tip, spellId, itemLink)
    end
    if InCombatLockdown() then
        C_Timer.After(0, function()
            if not S.IsForbiddenObject(tip) and tip:IsShown() then doAction() end
        end)
    else
        doAction()
    end
end

------------------------------------------------------------
-- 設定套用總入口（設定面板 / 載入時）
------------------------------------------------------------
function ns.ApplyAll()
    Skin.ApplyBaseAll()
    ns.Bar.ApplySettingsAll()
    ns.Fonts.Apply()
    ns.Fire("SettingsApplied")
end

------------------------------------------------------------
-- 初始化
------------------------------------------------------------
local function TrackTip(tip)
    if not tip or Skin.Get(tip) then return end
    Skin.Attach(tip)
    -- 清理暫態（接觸面 #3）。HookScript 是後掛勾，安全。
    if tip.HasScript and tip:HasScript("OnTooltipCleared") then
        tip:HookScript("OnTooltipCleared", function(self)
            if S.IsForbiddenObject(self) then return end
            Skin.ClearTransient(self)
        end)
    end
end

ns.TrackTip = TrackTip   -- 預覽 tooltip（Options/Preview.lua）也走同一條接管管線

local function Install()
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
    if GameTooltip and type(GameTooltip.SetAction) == "function" then
        hooksecurefunc(GameTooltip, "SetAction", OnSetAction)
    end
    if GameTooltip and type(GameTooltip.SetMacro) == "function" then
        hooksecurefunc(GameTooltip, "SetMacro", OnSetMacro)
    end

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
        if C_AddOns.IsAddOnLoaded("TinyTooltip-Remake") then
            print("|cff4DD2FF[米利的滑鼠提示]|r |cffff5555偵測到 TinyTooltip-Remake 同時啟用——兩邊會重複改寫工具提示，請停用其中一個。|r")
        end
    end
end)
