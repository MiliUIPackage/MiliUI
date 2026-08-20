------------------------------------------------------------
-- MiliUI Focuser
-- Shift+Click（或自訂快捷鍵）設定焦點目標 + 自動上團隊標記
------------------------------------------------------------
MiliUI_Focuser = {}

local modifier = "shift"
local mouseButton = "1"

local focuserButton
local bindButton            -- override binding 的中繼按鈕（見 SetupFocuserButton）
local SetupFocuserButton    -- forward declaration（SetFocusHotkey 需要 lazy 建立）
local hookedFrames = {}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.focuserEnabled == nil then MiliUI_DB.focuserEnabled = true end
    if MiliUI_DB.focuserAutoMark == nil then MiliUI_DB.focuserAutoMark = false end
    if MiliUI_DB.focuserMarkIndex == nil then MiliUI_DB.focuserMarkIndex = 0 end
    if MiliUI_DB.focuserNoOverwriteMark == nil then MiliUI_DB.focuserNoOverwriteMark = true end
    -- focuserHotkey：自訂快捷鍵的綁定字串（"F"、"ALT-CTRL-G"、"BUTTON4"…），
    -- nil = 未設定（預設）。Shift+左鍵那組是固定的，不受這個影響。
    return MiliUI_DB
end

-- markOverride：用指定的標記編號組巨集（給 FocuserBar 的標記選單預存
-- 每個編號對應的巨集文字，讓安全快照能在戰鬥中換上）；nil = 用目前設定值
local function GetActiveMacro(markOverride)
    local db = GetDB()
    local index = markOverride or db.focuserMarkIndex
    local lines = {}
    -- 這裡曾經有一行 `/tm [@focus,exists] 0`（換焦點時清掉舊焦點的標記）。
    -- 拿掉了：巨集只能「無條件」清 —— 條件式沒有「已被標記」這種判斷，安全
    -- 動作也只有 set / set-unmarked / clear / clear-all / toggle，沒有「等於 N
    -- 才清」；而 12.1 的 GetRaidTargetIndex 回傳秘密值，Lua 端也比不了編號。
    -- 結果就是它會把隊長標好的骷髏一起清掉。反正被標的怪死掉標記就跟著消失，
    -- 這個功能救的只有「放掉一隻沒死的怪」，不值得為它冒誤清的風險。
    table.insert(lines, "/focus [@mouseover,exists]")
    table.insert(lines, "/clearfocus [@mouseover,noexists]")
    if db.focuserAutoMark and index > 0 and index <= 8 then
        -- "~" 前綴是暴雪 /tm 內建的：目標身上已經有任何標記就整行跳過
        -- （Blizzard_ChatFrameBase/Shared/SlashCommands.lua 的 TARGET_MARKER；
        --  另有 "!" 前綴＝已經是同一個標記就跳過，這裡用不到）。
        -- 巨集條件式沒有「已被標記」這種判斷，只有這條路能在戰鬥中成立。
        local prefix = db.focuserNoOverwriteMark and "~" or ""
        table.insert(lines, "/tm [@mouseover,exists] " .. prefix .. index)
    end
    return table.concat(lines, "\n")
end

-- 單位框架不再各自存完整巨集，改用 type="click" 委派到 FocuserButton
-- （11.0.2 起巨集文字裡的 /click 不能再觸發另一個巨集按鈕，但 clickbutton
-- 屬性的委派不受此限）。好處：戰鬥中改標記圖示時，只要改 FocuserButton
-- 一顆的巨集就全面生效，而這件事可由標記選單的安全快照代做。

----------------------------------------------------------------------
-- 單位框架：shift+click 執行巨集（focus + mark 一次完成）
----------------------------------------------------------------------
local function SetFocusHotkey(frame)
    if not frame then return end
    if not frame.SetAttribute then return end
    if InCombatLockdown() then return end
    if not focuserButton then SetupFocuserButton() end

    frame:SetAttribute(modifier .. "-type" .. mouseButton, "click")
    frame:SetAttribute(modifier .. "-clickbutton" .. mouseButton, focuserButton)
    hookedFrames[frame] = true
end

local function ClearFocusHotkey(frame)
    if not frame then return end
    if not InCombatLockdown() then
        frame:SetAttribute(modifier .. "-type" .. mouseButton, nil)
        frame:SetAttribute(modifier .. "-clickbutton" .. mouseButton, nil)
        hookedFrames[frame] = false
    end
end

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
    -- MiliUI_UnitFrames（米利頭像框架）
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

local function CreateFrame_Hook(type, name, parent, template)
    if not GetDB().focuserEnabled then return end
    if template == "SecureUnitButtonTemplate" or template == "SecureUnitButtonTemplate,BackdropTemplate" then
        SetFocusHotkey(_G[name])
    end
end

----------------------------------------------------------------------
-- FocuserButton：override binding 處理名條 / 世界目標
----------------------------------------------------------------------
-- SetOverrideBinding* 在戰鬥中會被擋，記下待辦脫戰再套
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
    SetOverrideBindingClick(bindButton, true, modifier .. "-BUTTON" .. mouseButton, "FocuserBindButton")
    local key = GetDB().focuserHotkey
    if key and key ~= "" then
        SetOverrideBindingClick(bindButton, true, key, "FocuserBindButton")
    end
end

----------------------------------------------------------------------
-- /focuscheck 用的小工具
----------------------------------------------------------------------
local issecret = issecretvalue or function() return false end

-- 只描述「有沒有標記」，不印值也不印單位名 —— 兩者在 12.1 都可能是秘密值
local function MarkDesc(unit)
    if not UnitExists(unit) then return "無單位" end
    local i = GetRaidTargetIndex(unit)
    if i == nil then return "沒標記" end
    if issecret(i) then return "有標記(秘密值)" end
    return "有標記(" .. tostring(i) .. ")"
end

function SetupFocuserButton()   -- 已於檔案上方 forward-declare
    if not focuserButton then
        focuserButton = CreateFrame("CheckButton", "FocuserButton", UIParent, "SecureActionButtonTemplate")
        focuserButton:SetSize(1, 1)   -- 需存在且顯示中才能被委派點擊
        focuserButton:RegisterForClicks("AnyDown", "AnyUp")
        -- 單位框架與綁定都用 type="click" 委派過來，delegate:Click() 只送
        -- 「放開」邊緣；照 BurstPotionHelper 的配方標記 pressAndHold 並同時
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

    -- 綁定不直接掛在 FocuserButton 上（鍵綁會送下+上兩個邊緣，配上
    -- pressAndHold 會跑兩次巨集），改綁到中繼按鈕：由 cvar 門檻挑一個
    -- 邊緣執行 click 動作，再委派 FocuserButton 恰好一次
    if not bindButton then
        bindButton = CreateFrame("Button", "FocuserBindButton", UIParent, "SecureActionButtonTemplate")
        bindButton:SetSize(1, 1)
        bindButton:RegisterForClicks("AnyDown", "AnyUp")
        -- 無後綴與 1 後綴都設（屬性查找的相容寫法，抄 BurstPotionHelper）
        bindButton:SetAttribute("type", "click")
        bindButton:SetAttribute("clickbutton", focuserButton)
        bindButton:SetAttribute("type1", "click")
        bindButton:SetAttribute("clickbutton1", focuserButton)
    end
    ApplyBindings()
end

local function TeardownFocuserButton()
    if not bindButton then return end
    if not InCombatLockdown() then
        ClearOverrideBindings(bindButton)
    end
end

-- 戰鬥中改設定（標記圖示等）時，巨集屬性是保護的不能改，
-- 記下待辦，脫戰（PLAYER_REGEN_ENABLED）再套用
local pendingMacro = false

local function SwitchMacro()
    if InCombatLockdown() then
        pendingMacro = true
        return
    end
    pendingMacro = false
    -- 單位框架只是委派點擊，巨集本體只在 FocuserButton 上（三個變體都要更新）
    if focuserButton then
        local macro = GetActiveMacro()
        focuserButton:SetAttribute("macrotext", macro)
        focuserButton:SetAttribute("macrotextrelease", macro)
        focuserButton:SetAttribute("macrotext1", macro)
    end
    -- 同步標記選單各格子預存的巨集文字（戰鬥中換圖示用）
    if MiliUI_FocuserBar and MiliUI_FocuserBar.SyncCellMacros then
        MiliUI_FocuserBar.SyncCellMacros()
    end
end
-- 設定改了就告訴隊友一聲（節流與封鎖判斷都在 FocuserSync 裡）
local function BroadcastToPeers()
    if MiliUI_FocuserSync and MiliUI_FocuserSync.Broadcast then
        MiliUI_FocuserSync.Broadcast()
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
hooksecurefunc("CreateFrame", CreateFrame_Hook)

----------------------------------------------------------------------
-- ClickCastFrames：單位框架的標準註冊表
----------------------------------------------------------------------
-- 這才是接單位框架的正確位置。ClickCastFrames 是點擊施法（Clique）的慣例，
-- 每個支援它的單位框架插件都會在框架就緒時寫入 —— Stuf 在 core.lua:1494、
-- DandersFrames 等等也都有。監看這張表就能在「框架剛好可以用」的那一刻接到。
--
-- 為什麼不靠原本的兩條路：
--   * defaultFrameNames + PLAYER_LOGIN 掃描：只掃那一瞬間。Stuf 的 target /
--     focus 是在 C_Timer.After(0) 裡才建的，掃過去時還不存在。
--   * hooksecurefunc("CreateFrame")：只保護「hook 安裝之後」建立的框架，
--     載入順序一變（例如 TOC 的 OptionalDeps 改了）就接不到。
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
            if enabled and type(frame) == "table" and GetDB().focuserEnabled then
                SetFocusHotkey(frame)
            end
        end,
    })
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        local db = GetDB()
        if db.focuserEnabled then
            SetupFocuserButton()
            ApplyAllHotkeys()   -- 暴雪原生框架不走 ClickCastFrames，仍需這份清單
        end
        WatchClickCastFrames()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if GetDB().focuserEnabled then
            ApplyAllHotkeys()
            if pendingMacro then
                SwitchMacro()   -- 補套戰鬥中被擋下的巨集更新（含 FocuserButton）
            end
            if pendingBindings then
                ApplyBindings() -- 補套戰鬥中被擋下的快捷鍵綁定
            end
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if GetDB().focuserEnabled then
            local plate = C_NamePlate.GetNamePlateForUnit(arg1)
            if plate then SetFocusHotkey(plate) end
        end
    end
end)

----------------------------------------------------------------------
-- /focuscheck：逐框架回報 shift 屬性有沒有設上
----------------------------------------------------------------------
-- 「shift+click 沒反應」有兩種完全不同的成因：屬性沒設上（時機問題），
-- 或設上了但點擊被別的框架吃掉。這裡只回答第一個，第二個要用
-- GetMouseFoci() 看焦點鏈。
SLASH_MILIUIFOCUSCHECK1 = "/focuscheck"
SlashCmdList["MILIUIFOCUSCHECK"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if msg == "macro" then
        local db = GetDB()
        print("|cffffe00a[MiliUI]|r 目前巨集（FocuserButton.macrotext）：")
        local macro = focuserButton and focuserButton:GetAttribute("macrotext")
        if macro then
            for line in tostring(macro):gmatch("[^\n]+") do print("   " .. line) end
        else
            print("   （按鈕還沒建立）")
        end
        print(("|cffffe00a[MiliUI]|r 自動標記=%s 圖示=%s 不覆蓋既有標記=%s")
            :format(tostring(db.focuserAutoMark), tostring(db.focuserMarkIndex),
                    tostring(db.focuserNoOverwriteMark)))
        print("   焦點：" .. MarkDesc("focus") .. "　指向：" .. MarkDesc("mouseover"))
        return
    end

    print("|cffffe00a[MiliUI]|r Focuser：啟用=" .. tostring(GetDB().focuserEnabled)
        .. "　FocuserButton=" .. tostring(focuserButton ~= nil)
        .. "　快捷鍵=" .. tostring(GetDB().focuserHotkey or "未設定"))
    local missing, ok = {}, 0
    for _, name in ipairs(defaultFrameNames) do
        local f = _G[name]
        if not f then
            table.insert(missing, name .. "（框架不存在）")
        elseif f:GetAttribute(modifier .. "-type" .. mouseButton) then
            ok = ok + 1
        else
            table.insert(missing, name .. "（屬性未設）")
        end
    end
    print("|cffffe00a[MiliUI]|r 已設定：" .. ok .. "　未設定：" .. #missing)
    for _, m in ipairs(missing) do print("   " .. m) end
    print("|cffffe00a[MiliUI]|r 另有 /focuscheck macro（看目前巨集內容）")
end

-- 公開 API
function MiliUI_Focuser.IsEnabled()
    return GetDB().focuserEnabled
end

function MiliUI_Focuser.SetEnabled(val)
    local db = GetDB()
    db.focuserEnabled = val
    if InCombatLockdown() then
        print("|cffff6600[MiliUI]|r 戰鬥中無法切換，請離開戰鬥後重載介面。")
        if MiliUI_FocuserBar then MiliUI_FocuserBar.Refresh() end   -- 記下待辦，脫戰套用
        return
    end
    if val then
        SetupFocuserButton()
        ApplyAllHotkeys()
    else
        RemoveAllHotkeys()
        TeardownFocuserButton()
    end
    -- 標記切換列跟著開關；放在 FocuserButton 就緒之後，選單建立時才拿得到 frame ref
    if MiliUI_FocuserBar then MiliUI_FocuserBar.Refresh() end
end

function MiliUI_Focuser.IsAutoMarkEnabled()
    return GetDB().focuserAutoMark
end

function MiliUI_Focuser.SetAutoMark(val)
    GetDB().focuserAutoMark = val
    SwitchMacro()
    BroadcastToPeers()
end

function MiliUI_Focuser.GetMarkIndex()
    return GetDB().focuserMarkIndex
end

-- 實際會用到的標記編號：自動標記關掉或沒選過 → 0。給 FocuserSync 廣播用，
-- 隊友那邊看到 0 就知道「有裝米利UI，但沒在標」。
function MiliUI_Focuser.GetEffectiveMarkIndex()
    local db = GetDB()
    if not db.focuserAutoMark then return 0 end
    local i = db.focuserMarkIndex or 0
    if i < 1 or i > 8 then return 0 end
    return i
end


function MiliUI_Focuser.SetMarkIndex(index)
    GetDB().focuserMarkIndex = index
    SwitchMacro()
    BroadcastToPeers()
    if MiliUI_FocuserBar then MiliUI_FocuserBar.UpdateMarkIcon() end
end

-- 給 FocuserBar 用：標記選單的安全快照需要 FocuserButton 的 frame ref，
-- 以及每個標記編號對應的巨集文字（預存為格子屬性，戰鬥中換上）
function MiliUI_Focuser.GetFocuserButton()
    return focuserButton
end

function MiliUI_Focuser.GetMacroForMarkIndex(index)
    return GetActiveMacro(index)
end

-- 自訂快捷鍵：nil / "" = 未設定（只剩固定的 shift+左鍵）
function MiliUI_Focuser.GetHotkey()
    return GetDB().focuserHotkey
end

function MiliUI_Focuser.SetHotkey(key)
    if key == "" then key = nil end
    GetDB().focuserHotkey = key
    if not bindButton and GetDB().focuserEnabled and not InCombatLockdown() then
        SetupFocuserButton()   -- 尚未建立就順手補齊（ApplyBindings 需要 bindButton）
        return
    end
    ApplyBindings()
end

function MiliUI_Focuser.IsNoOverwriteMarkEnabled()
    return GetDB().focuserNoOverwriteMark
end

function MiliUI_Focuser.SetNoOverwriteMark(val)
    GetDB().focuserNoOverwriteMark = val
    SwitchMacro()
end

