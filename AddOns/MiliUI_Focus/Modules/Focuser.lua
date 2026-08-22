------------------------------------------------------------
-- Shift+點擊（或自訂快捷鍵）設定焦點目標 ＋ 自動上團隊標記
------------------------------------------------------------
local _, ns = ...

ns.Focuser = {}
local Focuser = ns.Focuser

local MODIFIER     = "shift"
local MOUSE_BUTTON = "1"

local focuserButton         -- 巨集本體（單位框架與綁定都委派到這一顆）
local bindButton            -- override binding 的中繼按鈕（見 SetupButtons）
local hookedFrames = {}
local ready = false         -- PLAYER_LOGIN 之前不要碰 db

local function DB()
    return ns.db.focus
end

-- markOverride：用指定的標記編號組巨集（給 MarkBar 的標記選單預存每個編號對應的
-- 巨集文字，讓安全快照能在戰鬥中換上）；nil = 用目前設定值
local function GetActiveMacro(markOverride)
    local db = DB()
    local index = markOverride or db.markIndex
    local lines = {}
    -- 這裡曾經有一行 `/tm [@focus,exists] 0`（換焦點時清掉舊焦點的標記）。
    -- 拿掉了：巨集只能「無條件」清 —— 條件式沒有「已被標記」這種判斷，安全
    -- 動作也只有 set / set-unmarked / clear / clear-all / toggle，沒有「等於 N
    -- 才清」；而 12.1 的 GetRaidTargetIndex 回傳秘密值，Lua 端也比不了編號。
    -- 結果就是它會把隊長標好的骷髏一起清掉。反正被標的怪死掉標記就跟著消失，
    -- 這個功能救的只有「放掉一隻沒死的怪」，不值得為它冒誤清的風險。
    tinsert(lines, "/focus [@mouseover,exists]")
    tinsert(lines, "/clearfocus [@mouseover,noexists]")
    if db.autoMark and index > 0 and index <= 8 then
        -- "~" 前綴是暴雪 /tm 內建的：目標身上已經有任何標記就整行跳過
        -- （Blizzard_ChatFrameBase/Shared/SlashCommands.lua 的 TARGET_MARKER；
        --  另有 "!" 前綴＝已經是同一個標記就跳過，這裡用不到）。
        -- 巨集條件式沒有「已被標記」這種判斷，只有這條路能在戰鬥中成立。
        local prefix = db.noOverwriteMark and "~" or ""
        tinsert(lines, "/tm [@mouseover,exists] " .. prefix .. index)
    end
    return table.concat(lines, "\n")
end

----------------------------------------------------------------------
-- 單位框架：shift+click 執行巨集（focus + mark 一次完成）
--
-- 框架不各自存完整巨集，改用 type="click" 委派到 focuserButton
-- （11.0.2 起巨集文字裡的 /click 不能再觸發另一個巨集按鈕，但 clickbutton
-- 屬性的委派不受此限）。好處：戰鬥中改標記圖示時，只要改一顆按鈕的巨集就
-- 全面生效，而這件事可由標記選單的安全快照代做。
----------------------------------------------------------------------
local SetupButtons   -- forward declaration（SetFocusHotkey 需要 lazy 建立）

local function SetFocusHotkey(frame)
    if not frame then return end
    if not frame.SetAttribute then return end
    if InCombatLockdown() then return end
    if not focuserButton then SetupButtons() end

    frame:SetAttribute(MODIFIER .. "-type" .. MOUSE_BUTTON, "click")
    frame:SetAttribute(MODIFIER .. "-clickbutton" .. MOUSE_BUTTON, focuserButton)
    hookedFrames[frame] = true
end

local function ClearFocusHotkey(frame)
    if not frame then return end
    if not InCombatLockdown() then
        frame:SetAttribute(MODIFIER .. "-type" .. MOUSE_BUTTON, nil)
        frame:SetAttribute(MODIFIER .. "-clickbutton" .. MOUSE_BUTTON, nil)
        hookedFrames[frame] = false
    end
end

-- 暴雪原生框架不走 ClickCastFrames，只能列名字掃
local defaultFrameNames = {
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "TargetFrameToTTargetFrame",
    "PartyMemberFrame1",
    "PartyMemberFrame2",
    "PartyMemberFrame3",
    "PartyMemberFrame4",
    "PartyMemberFrame1PetFrame",
    "PartyMemberFrame2PetFrame",
    "PartyMemberFrame3PetFrame",
    "PartyMemberFrame4PetFrame",
    "PartyMemberFrame1TargetFrame",
    "PartyMemberFrame2TargetFrame",
    "PartyMemberFrame3TargetFrame",
    "PartyMemberFrame4TargetFrame",
    -- 米利的單位框架
    "MiliUIUF_Player",
    "MiliUIUF_Target",
    "MiliUIUF_TargetTarget",
    "MiliUIUF_Focus",
    "MiliUIUF_FocusTarget",
    "MiliUIUF_Pet",
    "MiliUIUF_Boss1",
    "MiliUIUF_Boss2",
    "MiliUIUF_Boss3",
    "MiliUIUF_Boss4",
    "MiliUIUF_Boss5",
}
Focuser.defaultFrameNames = defaultFrameNames

local function ApplyAllHotkeys()
    if InCombatLockdown() then return end
    for _, name in ipairs(defaultFrameNames) do
        local f = _G[name]
        if f then SetFocusHotkey(f) end
    end
    for _, plate in pairs(C_NamePlate.GetNamePlates()) do
        SetFocusHotkey(plate)
    end
end

local function RemoveAllHotkeys()
    if InCombatLockdown() then return end
    for frame in pairs(hookedFrames) do
        ClearFocusHotkey(frame)
    end
end

local function CreateFrame_Hook(frameType, name, parent, template)
    if not ready or not DB().enabled then return end
    if template == "SecureUnitButtonTemplate" or template == "SecureUnitButtonTemplate,BackdropTemplate" then
        SetFocusHotkey(_G[name])
    end
end

----------------------------------------------------------------------
-- 綁定：override binding 處理名條 / 世界目標
-- SetOverrideBinding* 在戰鬥中會被擋，記下待辦脫戰再套
----------------------------------------------------------------------
local pendingBindings = false

-- 兩組綁定都掛在 bindButton 上：固定的 shift+左鍵，以及玩家自訂的快捷鍵。
-- 兩者走同一顆中繼按鈕 → 同一份巨集，行為完全一致。
local function ApplyBindings()
    if not bindButton then return end
    if InCombatLockdown() then
        pendingBindings = true
        return
    end
    pendingBindings = false
    ClearOverrideBindings(bindButton)
    if not DB().enabled then return end
    SetOverrideBindingClick(bindButton, true, MODIFIER .. "-BUTTON" .. MOUSE_BUTTON,
        "MiliUIFocus_BindButton")
    local key = DB().hotkey
    if key and key ~= "" then
        SetOverrideBindingClick(bindButton, true, key, "MiliUIFocus_BindButton")
    end
end

function SetupButtons()   -- 已於檔案上方 forward-declare
    if not focuserButton then
        focuserButton = CreateFrame("CheckButton", "MiliUIFocus_Button", UIParent,
            "SecureActionButtonTemplate")
        focuserButton:SetSize(1, 1)   -- 需存在且顯示中才能被委派點擊
        focuserButton:RegisterForClicks("AnyDown", "AnyUp")
        -- 單位框架與綁定都用 type="click" 委派過來，delegate:Click() 只送
        -- 「放開」邊緣；照 MiliUI_BurstPotionHelper 的配方標記 pressAndHold 並同時
        -- 設 type / typerelease / type1，確保不論 cvar 設定都恰好執行一次
        focuserButton:SetAttribute("pressAndHoldAction", true)
        focuserButton:SetAttribute("type", "macro")
        focuserButton:SetAttribute("typerelease", "macro")
        focuserButton:SetAttribute("type1", "macro")
    end
    local macro = GetActiveMacro()
    focuserButton:SetAttribute("macrotext", macro)
    focuserButton:SetAttribute("macrotextrelease", macro)
    focuserButton:SetAttribute("macrotext1", macro)

    -- 綁定不直接掛在 focuserButton 上（鍵綁會送下+上兩個邊緣，配上
    -- pressAndHold 會跑兩次巨集），改綁到中繼按鈕：由 cvar 門檻挑一個
    -- 邊緣執行 click 動作，再委派 focuserButton 恰好一次
    if not bindButton then
        bindButton = CreateFrame("Button", "MiliUIFocus_BindButton", UIParent,
            "SecureActionButtonTemplate")
        bindButton:SetSize(1, 1)
        bindButton:RegisterForClicks("AnyDown", "AnyUp")
        -- 無後綴與 1 後綴都設（屬性查找的相容寫法）
        bindButton:SetAttribute("type", "click")
        bindButton:SetAttribute("clickbutton", focuserButton)
        bindButton:SetAttribute("type1", "click")
        bindButton:SetAttribute("clickbutton1", focuserButton)
    end
    ApplyBindings()
end

----------------------------------------------------------------------
-- 巨集熱更新
-- 戰鬥中巨集屬性是保護的不能改，記下待辦，脫戰再套用
----------------------------------------------------------------------
local pendingMacro = false

local function SwitchMacro()
    if InCombatLockdown() then
        pendingMacro = true
        return
    end
    pendingMacro = false
    if focuserButton then
        local macro = GetActiveMacro()
        focuserButton:SetAttribute("macrotext", macro)
        focuserButton:SetAttribute("macrotextrelease", macro)
        focuserButton:SetAttribute("macrotext1", macro)
    end
    -- 同步標記選單各格子預存的巨集文字（戰鬥中換圖示用）
    ns.MarkBar.SyncCellMacros()
end

----------------------------------------------------------------------
-- ClickCastFrames：單位框架的標準註冊表
----------------------------------------------------------------------
-- 這才是接單位框架的正確位置。ClickCastFrames 是點擊施法（Clique）的慣例，
-- 每個支援它的單位框架插件都會在框架就緒時寫入。監看這張表就能在「框架剛好
-- 可以用」的那一刻接到。
--
-- 為什麼不靠另外兩條路：
--   * defaultFrameNames + PLAYER_LOGIN 掃描：只掃那一瞬間，有些插件的 target /
--     focus 是在 C_Timer.After(0) 裡才建的，掃過去時還不存在。
--   * hooksecurefunc("CreateFrame")：只保護「hook 安裝之後」建立的框架，
--     載入順序一變就接不到。
-- 兩條都是時機相依，才會出現「有時好有時壞」。註冊表沒有這個問題。
local function WatchClickCastFrames()
    ClickCastFrames = ClickCastFrames or {}

    -- 先補上在我們接手之前就註冊好的
    for frame, enabled in pairs(ClickCastFrames) do
        if enabled and type(frame) == "table" then SetFocusHotkey(frame) end
    end

    -- 之後每有新框架註冊就立刻套用。用 rawset 保存原本的寫入語意，
    -- 我們只是搭順風車。
    setmetatable(ClickCastFrames, {
        __newindex = function(t, frame, enabled)
            rawset(t, frame, enabled)
            if enabled and type(frame) == "table" and ready and DB().enabled then
                SetFocusHotkey(frame)
            end
        end,
    })
end

----------------------------------------------------------------------
-- 對外
----------------------------------------------------------------------
-- 設定改完統一走這裡：開關、巨集、綁定一次套到位
function Focuser.Apply()
    if not ready then return end
    if InCombatLockdown() then
        -- 保護屬性與覆寫綁定都不能在戰鬥中寫，記下待辦脫戰補套
        pendingMacro = true
        pendingBindings = true
        ns.MarkBar.Refresh()
        return
    end
    if DB().enabled then
        SetupButtons()
        ApplyAllHotkeys()
        SwitchMacro()
    else
        RemoveAllHotkeys()
        if bindButton then ClearOverrideBindings(bindButton) end
    end
    -- 標記切換列跟著開關；放在按鈕就緒之後，選單建立時才拿得到 frame ref
    ns.MarkBar.Refresh()
    ns.Sync.Broadcast()
end

-- 標記選單改圖示用的輕量版：只動巨集與廣播，不重掃框架
function Focuser.SetMarkIndex(index)
    DB().markIndex = index
    SwitchMacro()
    ns.Sync.Broadcast()
    ns.MarkBar.UpdateMarkIcon()
end

-- 實際會用到的標記編號：自動標記關掉或沒選過 → 0。給 Sync 廣播用，
-- 隊友那邊看到 0 就知道「有裝這個插件，但沒在標」。
function Focuser.GetEffectiveMarkIndex()
    if not ns.db then return 0 end
    local db = DB()
    if not db.autoMark then return 0 end
    local i = db.markIndex or 0
    if i < 1 or i > 8 then return 0 end
    return i
end

-- 給 MarkBar 用：標記選單的安全快照需要按鈕的 frame ref，以及每個標記編號
-- 對應的巨集文字（預存為格子屬性，戰鬥中換上）
--
-- ⚠ 選單建立時一定要先叫 EnsureButtons()：Init 回呼是 pairs 走訪、順序不保證，
--   MarkBar 有可能排在 Focuser 前面。那時 GetButton() 回 nil，格子就少了
--   focuser 的 frame ref —— 不會報錯，只是戰鬥中換圖示後巨集不會跟著換。
function Focuser.EnsureButtons()
    if InCombatLockdown() then return end
    if not focuserButton then SetupButtons() end
end

function Focuser.GetButton()
    return focuserButton
end

function Focuser.GetMacroForMarkIndex(index)
    return GetActiveMacro(index)
end

function Focuser.IsEnabled()
    return ns.db and DB().enabled
end

-- /mfocus check 用
function Focuser.GetDebugInfo()
    return focuserButton, bindButton, MODIFIER .. "-type" .. MOUSE_BUTTON
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
hooksecurefunc("CreateFrame", CreateFrame_Hook)

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if not ready then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if not DB().enabled then
            if pendingBindings then ApplyBindings() end
            return
        end
        ApplyAllHotkeys()
        if pendingMacro then SwitchMacro() end
        if pendingBindings then ApplyBindings() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if DB().enabled then
            local plate = C_NamePlate.GetNamePlateForUnit(arg1)
            if plate then SetFocusHotkey(plate) end
        end
    end
end)

ns.RegisterCallback("Init", "focuser", function()
    ready = true
    if DB().enabled then
        SetupButtons()
        ApplyAllHotkeys()   -- 暴雪原生框架不走 ClickCastFrames，仍需這份清單
    end
    WatchClickCastFrames()
end)
