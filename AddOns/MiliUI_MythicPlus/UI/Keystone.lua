------------------------------------------------------------
-- 鑰石視窗（ChallengesKeystoneFrame）：自動放入鑰石 ＋ 底下的確認／倒數列
--
-- 2026-09-24 從 MiliUI 本體的 Enhance/AutoSlotKeystone.lua 與
-- Enhance/ChallengesUI_Buttons.lua 搬過來，設定在「鑰石」分頁（Options/Tab_Keystone.lua）。
-- 本體那兩支沒有存檔，所以沒有遷移。
--
-- ⚠⚠ 確認與倒數走 secure 巨集（/readycheck、/cd N），**不要**改回在 Lua 裡直呼
--   DoReadyCheck／C_PartyInfo.DoCountdown。那兩支是 HasRestrictions，插件端的呼叫
--   會被 12.x 的情境限制擋下（寫法同 MiliUI_InfoBar/Core/ReadyCheck.lua）。
--   連帶的規矩：
--     * secure 按鈕的 OnClick 上不掛任何 Lua（HookScript 也不行）—— 那會跟 secure
--       動作同一次派送，執行流程染成我們的。「正在倒數」改聽倒數事件，不聽點擊；
--     * 列裡有 secure 按鈕 ⇒ 整列是保護框：Show／Hide／SetAttribute 都要過戰鬥閘。
--
-- ⚠ 列是 UIParent 的孩子、只錨在鑰石視窗底下，**不當它的孩子**：當孩子的話
--   保護狀態會往上傳到暴雪的視窗（見 wow-combat-drag-release 筆記）。
--   代價是顯示／隱藏要自己跟著鑰石視窗的 OnShow／OnHide 走。
--
-- 外觀：設定視窗皮（MiliUIWidgets 的 W.CreateFrame／W.CreateButton／W.CreateSlider），
-- 跟本插件的設定視窗同一套。「開始倒數」是這一區唯一的 primary。
------------------------------------------------------------
local _, ns = ...

ns.Keystone = {}
local K = ns.Keystone

local L = ns.L
local S = ns.Secret

K.MIN_SECONDS = 3
K.MAX_SECONDS = 30

local PAD      = 10
local BTN_H    = 26
local ROW_GAP  = 8
local ROW_H    = BTN_H + ROW_GAP + 20 + PAD * 2

local bar                   -- 確認／倒數列
local readyBtn, countBtn    -- 看得到的 W.CreateButton
local readySec, countSec    -- 疊在上面的 secure 按鈕
local slider
local counting = false
local countTimer
local pendingSync = false   -- 戰鬥中被擋下的顯示／巨集更新，脫戰補

local function Cfg()
    return ns.db and ns.db.keystone
end

local function Seconds()
    local c = Cfg()
    local sec = math.floor(tonumber(c and c.countdown) or 5)
    return math.min(math.max(sec, K.MIN_SECONDS), K.MAX_SECONDS)
end

------------------------------------------------------------
-- 自動放入鑰石
------------------------------------------------------------
local function AutoSlot()
    local c = Cfg()
    if not (c and c.autoSlot) then return end
    if CursorHasItem() then return end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link and link:find("keystone:", 1, true) then
                C_Container.PickupContainerItem(bag, slot)
                if CursorHasItem() then C_ChallengeMode.SlotKeystone() end
                return
            end
        end
    end
end

------------------------------------------------------------
-- 確認／倒數列
------------------------------------------------------------
-- 看得到的按鈕畫外觀，上面蓋一顆同大小的 secure 按鈕接點擊。
-- 滑過顏色由 secure 那顆轉給底下那顆（OnEnter／OnLeave 不是點擊派送，掛 Lua 沒事）
local function SecureOverlay(visual)
    local b = CreateFrame("Button", nil, visual, "SecureActionButtonTemplate")
    b:SetAllPoints(visual)
    b:RegisterForClicks("AnyUp")
    -- 沒有這行，ActionButtonUseKeyDown 會讓 secure handler 只認 key-down，AnyUp 被丟掉
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("type", "macro")
    b:HookScript("OnEnter", function() ns.W.PaintButton(visual, true) end)
    b:HookScript("OnLeave", function() ns.W.PaintButton(visual, false) end)
    return b
end

local function Paint()
    if not bar then return end
    countBtn:SetText(counting and L["Stop countdown"] or L["Start countdown"])
end

-- 巨集內容跟著狀態走。SetAttribute 對 secure 按鈕是戰鬥違禁品 → 脫戰補
local function SyncMacros()
    if not bar then return end
    if InCombatLockdown() then pendingSync = true; return end
    readySec:SetAttribute("macrotext", "/readycheck")
    countSec:SetAttribute("macrotext", counting and "/cd 0" or ("/cd " .. Seconds()))
end

local function SetCounting(on)
    counting = on and true or false
    if countTimer then countTimer:Cancel(); countTimer = nil end
    Paint()
    SyncMacros()
end

local function KeystoneFrame()
    return _G.ChallengesKeystoneFrame
end

local function WantBar()
    local c = Cfg()
    local kf = KeystoneFrame()
    return c and c.buttons and kf and kf:IsShown() and true or false
end

-- 顯示跟著鑰石視窗與設定。保護框戰鬥中不能 Show／Hide → 脫戰補
local function SyncShown()
    if not bar then return end
    if InCombatLockdown() then pendingSync = true; return end
    if WantBar() then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", KeystoneFrame(), "BOTTOMLEFT", 0, -8)
        bar:SetPoint("TOPRIGHT", KeystoneFrame(), "BOTTOMRIGHT", 0, -8)
        bar:Show()
    else
        bar:Hide()
    end
end

local function BuildBar()
    if bar then return end
    local W = ns.W

    bar = W.CreateFrame("MiliUIMythicPlus_KeystoneBar", UIParent)
    bar:Hide()
    bar:SetHeight(ROW_H)
    -- 鑰石視窗本身是 HIGH，列要在同一層才不會被它（或它的皮）蓋掉
    bar:SetFrameStrata("HIGH")

    readyBtn = W.CreateButton(bar, L["Ready check"], "normal", 100, BTN_H)
    readyBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", PAD, -PAD)
    readyBtn:SetPoint("TOPRIGHT", bar, "TOP", -PAD / 2, -PAD)
    readySec = SecureOverlay(readyBtn)

    countBtn = W.CreateButton(bar, L["Start countdown"], "primary", 100, BTN_H)
    countBtn:SetPoint("TOPLEFT", bar, "TOP", PAD / 2, -PAD)
    countBtn:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -PAD, -PAD)
    countSec = SecureOverlay(countBtn)

    local label = bar:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(W.fontSmall)
    label:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", PAD, PAD + 3)
    label:SetText(L["Countdown seconds"])

    -- 滑桿：拖曳中就改巨集（放開前按下去的倒數也要是看到的秒數）
    local function OnValue(v)
        local c = Cfg()
        if c then c.countdown = v end
        SyncMacros()
    end
    slider = W.CreateSlider(bar, K.MIN_SECONDS, K.MAX_SECONDS, 200, 1, OnValue, OnValue)
    slider:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -PAD, PAD)

    SetCounting(false)
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
-- 倒數事件：自己點的、隊友點的都會來。參數過守衛，秘密值就退回滑桿上的秒數
local function OnCountdownStart(_, timeRemaining)
    SetCounting(true)
    local sec = S.PlainNumber(timeRemaining) or Seconds()
    countTimer = C_Timer.NewTimer(sec + 0.5, function()
        countTimer = nil
        SetCounting(false)
    end)
end

local function OnKeystoneShow()
    local c = Cfg()
    if c and c.buttons then
        BuildBar()
        slider:SetValue(Seconds())
        SyncMacros()
    end
    SyncShown()
    AutoSlot()
end

local hooked = false
local function Hook()
    local kf = KeystoneFrame()
    if hooked or not kf then return end
    hooked = true
    kf:HookScript("OnShow", function() ns.Guard(OnKeystoneShow) end)
    kf:HookScript("OnHide", function() ns.Guard(SyncShown) end)
    if kf:IsShown() then ns.Guard(OnKeystoneShow) end
end

-- 設定頁改了開關：當場套
function K.Apply()
    local kf = KeystoneFrame()
    if kf and kf:IsShown() then
        OnKeystoneShow()
    else
        SyncShown()
    end
end

function K.Init()
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    ns.SafeRegister(f, "START_PLAYER_COUNTDOWN")
    ns.SafeRegister(f, "CANCEL_PLAYER_COUNTDOWN")
    f:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            if ... == "Blizzard_ChallengesUI" then ns.Guard(Hook) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingSync then
                pendingSync = false
                ns.Guard(SyncMacros)
                ns.Guard(SyncShown)
            end
        elseif event == "START_PLAYER_COUNTDOWN" then
            ns.Guard(OnCountdownStart, ...)
        elseif event == "CANCEL_PLAYER_COUNTDOWN" then
            ns.Guard(SetCounting, false)
        end
    end)
    -- 暴雪的鑰石介面是隨選載入的；已經載入了（別的插件先叫過）就直接掛
    if C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") then Hook() end
end
