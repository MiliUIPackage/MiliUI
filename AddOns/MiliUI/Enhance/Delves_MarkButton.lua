------------------------------------------------------------
-- MiliUI: 探究「標記敦敦」按鈕
--
-- 在**豐碩探究**裡，而且探究等級已經到 3（寶藏獵人）時，畫面上多一顆按鈕，
-- 點一下就是：
--     /target 敦敦
--     /tm 8
--
-- ⚠ 為什麼是安全按鈕而不是直接呼叫 API：12.0 起 `SetRaidTarget` 是戰鬥保護函式，
-- 插件程式在戰鬥中呼叫會被擋掉（點了沒反應）。走 SecureActionButtonTemplate 的
-- macro 型別、把 `/tm` 交給暴雪的巨集執行環境，戰鬥中才有效。
--
-- ⚠ 保護框架在戰鬥中不能 Show/Hide，也不能改屬性 ——
-- 巨集內文在建立時就寫死，顯示切換一律過 InCombatLockdown 閘、延到脫戰再補。
--
-- 名字目前只有繁中的「敦敦」。其他語系的叫法還沒查，所以非 zhTW 的客戶端不啟用
-- （硬套一個查不到的名字，巨集只會 /target 失敗，比不顯示更糟）。
--
-- 讀寫於 MiliUI_DB.delveMarkButton（boolean，預設開）與 .delveMarkButtonPos。
------------------------------------------------------------

local MIN_LEVEL   = 3            -- 探究**等級**（賽季軌道），不是探究的難度層級
local TARGET_NAME = "敦敦"
-- ⚠ `!8` 不是打錯：`!` 是暴雪 /tm 內建的前綴，「已經是同一個標記就整行跳過」
-- （Blizzard_ChatFrameBase/Shared/SlashCommands.lua 的 TARGET_MARKER）。
-- 沒有它的話，萬一按下與放開兩個邊緣都執行到，第二次會把剛標上的骷髏 toggle 掉
-- —— 症狀正好是「點了沒作用」。加上之後這串巨集重複執行是安全的。
local MACRO_TEXT  = "/target " .. TARGET_NAME .. "\n/tm [@target,exists] !8"
local BUTTON_TEXT = "點擊標記" .. TARGET_NAME

-- 畫面正中央往上 400（CENTER 對 CENTER，y 正值 = 往上）。
-- ⚠ 400 在小螢幕上會超出畫面上緣：UIParent 的座標高度大約是 768（預設縮放），
-- 一半才 384。所以顯示時一律夾住（見 ClampPos），夾到底就是「正上方」。
local DEFAULT_POS = { x = 0, y = 400 }

local BUTTON_W, BUTTON_H = 140, 26
local EDGE_PAD = 4

-- 只有繁中客戶端啟用（見檔頭）。查得到其他語系的叫法再把這裡換成對照表。
local SUPPORTED = GetLocale() == "zhTW"

------------------------------------------------------------
-- 「這場是豐碩探究嗎」
--
-- 探究的詞綴掛在場景標頭 widget 的 spells 清單上，一個詞綴一顆法術
-- （Plumber 的 DelvesScenario.lua 也是這樣認「宿敵」的）。所以判斷方式是
-- 「標頭上有沒有那顆法術」。
--
-- ⚠ 有些詞綴的法術 ID **每個賽季會換**（宿敵就是，Plumber 為此寫了兩個賽季各一顆
-- 的分支）。所以這裡不只吃 ID：先查 ID 白名單，查不到再退回比對法術名稱。要補 ID 的話，
-- 在探究裡把滑鼠移到標頭那顆詞綴圖示上，然後：
--     /dump GetMouseFoci()[1].spellID
-- 或直接 /run MiliUI_DelveMarkButton.Debug() ——它會把標頭上每顆法術的
-- ID 與名字都印出來。
------------------------------------------------------------
local BOUNTIFUL_SPELL_IDS = {
    -- 2026-08-24 實地抓的（第2賽季「學院災禍」，同場標頭還有 1278216 學生計畫、
    -- 1307638 死敵影響）。這顆的 ID 比另外兩顆小一個量級，看起來是 TWW 就沿用
    -- 到現在的通用詞綴，不像宿敵那樣每季換 —— 但還是留著名稱備援。
    [462940] = true,   -- 豐碩
}

-- 名稱備援：本模組本來就只跑繁中，所以直接比中文關鍵字
local BOUNTIFUL_NAME_MATCH = "豐"

------------------------------------------------------------
-- 設定
------------------------------------------------------------
local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.delveMarkButton == nil then
        MiliUI_DB.delveMarkButton = true
    end
    if type(MiliUI_DB.delveMarkButtonPos) ~= "table" then
        MiliUI_DB.delveMarkButtonPos = { x = DEFAULT_POS.x, y = DEFAULT_POS.y }
    end
    return MiliUI_DB
end

local function IsEnabled()
    return GetDB().delveMarkButton and true or false
end

------------------------------------------------------------
-- 偵測
------------------------------------------------------------
-- ⚠ 不要用 C_DelvesUI.HasActiveDelve(mapID)：在探究裡重新登入時它會失準
-- （Plumber 的 API.lua 就是為了這個換掉的，那段舊寫法還註解在原地）。
local function InDelve()
    return C_PartyInfo and C_PartyInfo.IsPartyWalkIn and C_PartyInfo.IsPartyWalkIn() and true or false
end

-- 探究等級 ＝ 賽季探究陣營的聲望等級（畫面上「探究：第N賽季」那條軌道，
-- 3 就是「寶藏獵人」那一格）
local seasonFaction
local function SeasonLevel()
    if not seasonFaction or seasonFaction == 0 then
        -- 0 不快取：登入初期可能還問不到，下次再試
        seasonFaction = (C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason
                         and C_DelvesUI.GetDelvesFactionForSeason()) or 0
    end
    if seasonFaction == 0 then return nil end
    local info = C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo
                 and C_MajorFactions.GetMajorFactionRenownInfo(seasonFaction)
    return info and info.renownLevel or nil
end

local function DelveHeaderInfo()
    if not (C_Scenario and C_UIWidgetManager) then return nil end
    local widgetSetID = select(12, C_Scenario.GetStepInfo())
    if not widgetSetID or widgetSetID == 0 then return nil end
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID)
    if not widgets then return nil end

    local typeID = (Enum.UIWidgetVisualizationType
                    and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves) or 29
    for _, w in ipairs(widgets) do
        if w.widgetType == typeID then
            return C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(w.widgetID)
        end
    end
    return nil
end

-- nil ＝ 標頭還讀不到（剛進場 widget 還沒建好）
local function IsBountiful()
    local info = DelveHeaderInfo()
    if not (info and info.spells) then return nil end
    for _, sp in ipairs(info.spells) do
        if sp.shownState == 1 and sp.spellID then
            if BOUNTIFUL_SPELL_IDS[sp.spellID] then return true end
            local si = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sp.spellID)
            if si and si.name and si.name:find(BOUNTIFUL_NAME_MATCH, 1, true) then
                return true
            end
        end
    end
    return false
end

-- ⚠ 這裡刻意 fail-closed（讀不到就不顯示）：需求是「只有豐碩探究才出現」，
-- 讀不到就放行等於每場探究都冒出來，正好是要避免的那件事。
-- 剛進場那一兩秒讀不到很正常，進場事件排的重試會補上。
local function ShouldShow()
    if not SUPPORTED then return false end
    if not IsEnabled() then return false end
    if not InDelve() then return false end
    local level = SeasonLevel()
    if not level or level < MIN_LEVEL then return false end
    return IsBountiful() == true
end

------------------------------------------------------------
-- 按鈕
------------------------------------------------------------
local button

local function SavePosition()
    local pos = GetDB().delveMarkButtonPos
    local cx, cy = UIParent:GetCenter()
    local bx, by = button:GetCenter()
    if not (cx and bx) then return end
    pos.x = math.floor(bx - cx + 0.5)
    pos.y = math.floor(by - cy + 0.5)
end

------------------------------------------------------------
-- 夾進畫面內
--
-- 只在**顯示的時候**夾，不回寫設定：大螢幕上拖到 y = 500，換到小螢幕會被夾成
-- 正上方，但換回大螢幕又回到 500。回寫的話那個 500 就永久沒了。
-- 尺寸與邊界都用 UIParent 的座標單位（它已經含 UI 縮放），不必自己換算解析度。
------------------------------------------------------------
local function ClampPos(x, y)
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    if not (pw and ph) or pw <= 0 or ph <= 0 then return x, y end
    local bw = (button and button:GetWidth()) or BUTTON_W
    local bh = (button and button:GetHeight()) or BUTTON_H
    if not bw or bw <= 0 then bw = BUTTON_W end
    if not bh or bh <= 0 then bh = BUTTON_H end

    local maxX = math.max(0, pw / 2 - bw / 2 - EDGE_PAD)
    local maxY = math.max(0, ph / 2 - bh / 2 - EDGE_PAD)
    if x >  maxX then x =  maxX end
    if x < -maxX then x = -maxX end
    if y >  maxY then y =  maxY end
    if y < -maxY then y = -maxY end
    return x, y
end

local function ApplyPosition()
    local pos = GetDB().delveMarkButtonPos
    local x, y = ClampPos(pos.x or 0, pos.y or 0)
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function CreateButton()
    if button then return button end

    -- ⚠ 框架的全域名字不能跟下面那張 API 表同名：CreateFrame 會把 frame 寫進
    -- _G[name]，而它比檔案層的 MiliUI_DelveMarkButton = {...} 晚跑（這支是在
    -- 事件裡才建的）⇒ 表會被 frame 蓋掉，設定分頁那邊 IsEnabled() 就變成 nil。
    button = CreateFrame("Button", "MiliUI_DelveMarkFrame", UIParent,
                         "SecureActionButtonTemplate,BackdropTemplate")
    button:Hide()
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)   -- 拖曳時就拖不出畫面（存檔值另外由 ClampPos 夾）

    local S = MiliUI and MiliUI.Style
    if S and S.ApplyDarkButton then
        S.ApplyDarkButton(button, BUTTON_TEXT, { 140, 26 }, 12)
    else
        button:SetSize(140, 26)
    end

    -- 巨集在這裡寫死一次。戰鬥中不能改保護按鈕的屬性，而這串內容也不需要變。
    --
    -- ⚠ 兩個邊緣都註冊、而且無後綴與「1」後綴的屬性都設 —— 這是本 repo 裡直接用
    -- 滑鼠點的保護按鈕唯一驗證過的形狀（MiliUI_Focus 的標記格子、
    -- MiliUI_BurstPotionHelper 的藥水鈕都是這樣）。只註冊 "AnyUp" 又只設無後綴的
    -- type/macrotext，會被 ActionButtonUseKeyDown 這類 cvar 影響到哪個邊緣才執行，
    -- 運氣不好就一次都不跑。重複執行由巨集自己的 `!` 前綴擋掉（見 MACRO_TEXT）。
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", MACRO_TEXT)
    button:SetAttribute("type1", "macro")
    button:SetAttribute("macrotext1", MACRO_TEXT)

    -- 拖曳：保護框架在戰鬥中不能移動，所以只在脫戰時可拖
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        SavePosition()
        ApplyPosition()
    end)

    -- ⚠ HookScript：S.ApplyDarkButton 用 SetScript 掛了 hover 換色，
    -- 這裡再 SetScript 會把它蓋掉
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(BUTTON_TEXT)
        GameTooltip:AddLine("/target " .. TARGET_NAME, 0.6, 0.9, 1)
        GameTooltip:AddLine("/tm [@target,exists] !8", 0.6, 0.9, 1)
        GameTooltip:AddLine("拖曳可移動（戰鬥中不能移動）", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", GameTooltip_Hide)

    ApplyPosition()
    return button
end

------------------------------------------------------------
-- 套用
------------------------------------------------------------
local watcher = CreateFrame("Frame")
local pendingApply = false

local function Apply()
    local show = ShouldShow()
    if not show and not button then return end     -- 沒符合過條件就不建按鈕

    -- 保護框架的 Show/Hide 在戰鬥中會被擋（而且不是 Lua error，pcall 攔不住）
    if InCombatLockdown() then
        pendingApply = true
        return
    end
    pendingApply = false

    CreateButton()
    ApplyPosition()
    button:SetShown(show)
end

local function SetEnabled(enabled)
    GetDB().delveMarkButton = enabled and true or false
    Apply()
end

------------------------------------------------------------
-- 事件
--
-- 剛進場時場景標頭 widget 還沒建好（詞綴讀不到），所以進場那兩個事件額外排
-- 幾次延遲重試 —— 那幾次就是把「還讀不到」換成真正判定的機會。
-- ⚠ 重試只掛在進場事件上，而且有防重入旗標：SCENARIO_CRITERIA_UPDATE 在探究裡
-- 會一直來，每次都排三顆計時器等於白燒。
------------------------------------------------------------
local retrying = false
local function ScheduleRetries()
    if retrying then return end
    retrying = true
    C_Timer.After(1, Apply)
    C_Timer.After(3, Apply)
    C_Timer.After(6, function() Apply(); retrying = false end)
end

watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
watcher:RegisterEvent("SCENARIO_UPDATE")
watcher:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
-- 換解析度／改 UI 縮放 → 原本剛好在邊緣的位置可能就跑出去了，重夾一次
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then Apply() end
        return
    end
    Apply()
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ScheduleRetries()
    end
end)

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 用）
------------------------------------------------------------
local function Say(...)
    print("|cff4DD2FF[米利UI 探究]|r", ...)
end

MiliUI_DelveMarkButton = {
    IsAvailable = function() return SUPPORTED end,
    IsEnabled  = IsEnabled,
    SetEnabled = SetEnabled,
    Apply      = Apply,
    -- 位置跑掉時的救援（設定面板的按鈕用）
    ResetPosition = function()
        local pos = GetDB().delveMarkButtonPos
        pos.x, pos.y = DEFAULT_POS.x, DEFAULT_POS.y
        if button and not InCombatLockdown() then ApplyPosition() end
    end,

    -- 在探究裡跑這支，把判定過程整串印出來（要補豐碩的法術 ID 就看這個）
    Debug = function()
        Say("在探究裡:", tostring(InDelve()))
        Say("探究等級:", tostring(SeasonLevel()),
            ("（需要 >= %d，賽季陣營 ID %s）"):format(MIN_LEVEL, tostring(seasonFaction)))
        local info = DelveHeaderInfo()
        if not info then
            Say("讀不到探究標頭 widget")
            return
        end
        Say("標頭:", tostring(info.headerText), " 層級文字:", tostring(info.tierText))
        if not info.spells or #info.spells == 0 then
            Say("標頭上沒有詞綴法術")
        else
            for i, sp in ipairs(info.spells) do
                local si = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(sp.spellID)
                Say(("  %d. spellID=%s shownState=%s %s"):format(
                    i, tostring(sp.spellID), tostring(sp.shownState), si and si.name or "?"))
            end
        end
        Say("判定為豐碩:", tostring(IsBountiful()), " 該不該顯示:", tostring(ShouldShow()))
    end,
}
