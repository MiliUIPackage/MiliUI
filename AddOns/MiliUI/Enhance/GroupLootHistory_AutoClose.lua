------------------------------------------------------------
-- MiliUI: 「戰利品擲骰」視窗隱藏／自動關閉（GroupLootHistoryFrame）
--
-- 團隊裡每掉一件裝備，暴雪就把「戰利品擲骰」清單視窗（誰擲了什麼、誰贏了）
-- 自動彈出來。兩種模式，同一個開關：
--   hide       完全不自動彈出（手動 /loot 或點聊天裡的連結照樣打得開）
--   autoclose  照常彈出，N 秒後自己關掉（預設 5 秒，1~30）；
--              視窗開著時又掉東西／有新的擲骰結果就重新計時
-- **不影響需求／貪婪的擲骰彈窗本身**（那是 GroupLootFrame，另一個框）。
-- 預設關閉。讀寫於 MiliUI_DB.lootHistory。
--
-- ## 為什麼不照成熟同類實作的寫法（`hooksecurefunc(f, "Show")` ＋ OnShow 裡 Hide）
--
-- 出處（12.1 live，Gethe/wow-ui-source）：
--   Blizzard_FrameXML/Blizzard_FrameXML.toc:119-120  LootHistory 登入就載好
--   Blizzard_FrameXML/Mainline/LootHistory.xml:190   GroupLootHistoryFrame
--       （DefaultPanelFlatTemplate，**沒有保護**，不在 UIPanelWindows 裡）
--   Blizzard_FrameXML/Mainline/LootHistory.lua
--       :291 常駐事件 LOOT_HISTORY_GO_TO_ENCOUNTER / LOOT_HISTORY_CLEAR_HISTORY
--       :341 OnEvent：**GO_TO_ENCOUNTER → self:Show() ＋ OpenToEncounter** ——
--            這是「自動彈出」唯一的來源（其餘兩個 Show 都是玩家自己開的：
--            SlashCommands.lua:1430 的 /loot、ItemRefHandlers.lua:101 的聊天連結）
--       :333 OnHide 會寫 self.selectedEncounterID、清 ScrollBox 的資料、停動畫
--       :100 列的 Init 每次都 SetScript 物品格的 OnClick（shift 點＝把連結塞進聊天框）
--
--   1. `hooksecurefunc(f, "Show")` ＝在暴雪框上寫欄位（f.Show 被換成包裝函式），禁止。
--   2. 從插件的 Lua 直接 `f:Hide()`，暴雪的 OnHide 就在我們的執行裡跑 ⇒
--      selectedEncounterID 與 ScrollBox 的欄位**被我們寫髒**。下一次彈出時 OnShow
--      讀到髒值、整趟刷新都算我們的：列的 Init 在污染下建的 OnClick 閉包也是髒的，
--      玩家 shift 點物品把連結塞進聊天框 ⇒ 聊天框被染（.claude/notes/
--      wow-121-chat-reply-secret-taint.md：之後回秘密名字的密語就炸）。
--      C_LootHistory 的查詢又是 SecretArguments = AllowedWhenUntainted。
--   3. `HookScript("OnShow")` 也不掛：玩家打 /loot 開視窗時 OnShow 跑在**聊天輸入框送出**
--      的那條執行裡，掛上去等於把我們的 Lua 塞進聊天框的流程（同上那份筆記）。
--
-- ## 我們的做法
--
--   * **hide 模式治本**：把「自動彈出」那一條事件從暴雪的框上解掉
--     （`f:UnregisterEvent("LOOT_HISTORY_GO_TO_ENCOUNTER")`）。視窗根本不會被叫出來，
--     不用事後去藏，暴雪的 Lua 一行都沒在我們的執行裡跑。事件登記是 C 端狀態、
--     不是 Lua 欄位；框沒有保護，戰鬥中也可以解。關掉功能時登記回去。
--     ⚠ 只解那一條：LOOT_HISTORY_CLEAR_HISTORY 還是它的，手動打開照樣正常。
--   * **autoclose 模式**：倒數由**自己的事件框**聽 LOOT_HISTORY_GO_TO_ENCOUNTER
--     （自動彈出的同一個訊號；視窗已開著時暴雪的 Show 不會再觸發 OnShow，事件照樣來）
--     與 LOOT_HISTORY_UPDATE_DROP（開著的時候有新結果）來開始／重新開始，
--     世代計數器 closeGen 讓舊的 timer 失效。
--     **關窗走 secure 端**：`SecureHandlerExecute` 的 snippet 裡對 frame handle 呼叫
--     `Hide()` —— 受限環境的執行是 secure 的，暴雪的 OnHide 因此在乾淨的執行裡跑，
--     欄位不會被染（套組先例：MiliUI_InfoBar/Core/Bar.lua 的 SecureReanchorUIParent、
--     Core/MicroMenu.lua 的 hider）。框沒有保護 ⇒ frame handle 只在**脫戰**有效，
--     戰鬥中到點就等 PLAYER_REGEN_ENABLED 再關。
--   * 只管「自動彈出」的那一次：玩家自己 /loot 打開的視窗不倒數（除非開著的時候又掉東西）。
------------------------------------------------------------
local _, ns = ...

local GO_TO = "LOOT_HISTORY_GO_TO_ENCOUNTER"
local DEFAULT_DELAY = 5

local DEFAULTS = {
    enabled = false,    -- 預設關閉
    mode    = "hide",   -- "hide" 完全不自動彈出 / "autoclose" 彈出後 N 秒自動關閉
    delay   = DEFAULT_DELAY,
}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.lootHistory
    if type(db) ~= "table" then
        db = {}
        MiliUI_DB.lootHistory = db
    end
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

local function Delay()
    local d = tonumber(GetDB().delay)
    if not d then return DEFAULT_DELAY end
    return math.min(30, math.max(1, math.floor(d + 0.5)))
end

local function IsMode(mode)
    local db = GetDB()
    return db.enabled and db.mode == mode
end

local function HistoryFrame()
    local f = _G.GroupLootHistoryFrame
    if not f or type(f.UnregisterEvent) ~= "function" then return nil end
    if f.IsForbidden and f:IsForbidden() then return nil end
    return f
end

local function IsHistoryShown()
    local f = HistoryFrame()
    if not f then return false end
    local ok, shown = pcall(f.IsShown, f)
    return ok and shown == true
end

------------------------------------------------------------
-- hide 模式：解掉自動彈出的那一條事件
------------------------------------------------------------
local unregisteredByUs = false

local function SyncRegistration()
    local f = HistoryFrame()
    if not f then return end
    local want = not IsMode("hide")
    if not want and not unregisteredByUs then
        if pcall(f.UnregisterEvent, f, GO_TO) then unregisteredByUs = true end
    elseif want and unregisteredByUs then
        -- 只登記回「我們解掉的」那一條；從來沒解過就一根手指都不碰
        if pcall(f.RegisterEvent, f, GO_TO) then unregisteredByUs = false end
    end
end

------------------------------------------------------------
-- 關窗：secure 端的 Hide（理由見檔頭）
------------------------------------------------------------
local CLOSE_SNIPPET = [[
    local f = self:GetFrameRef("history")
    if f and f:IsShown() then f:Hide() end
]]

local closer
local function GetCloser()
    if closer then return closer end
    -- SetFrameRef 會寫 secure 框的屬性，戰鬥中不能建
    if InCombatLockdown() or not SecureHandlerExecute or not SecureHandlerSetFrameRef then return nil end
    local f = HistoryFrame()
    if not f then return nil end
    local h = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
    SecureHandlerSetFrameRef(h, "history", f)
    closer = h
    return h
end

local ev = CreateFrame("Frame")
local closeGen = 0          -- 每次開始／重新開始倒數就 +1，舊的 timer 自己作廢
local armed = false         -- 目前有沒有一個「自動彈出」在倒數
local pendingGen            -- 戰鬥中到點、等脫戰再關的那一輪

local function CloseNow(gen)
    if gen ~= closeGen then return end
    if InCombatLockdown() then
        -- 框沒有保護 ⇒ frame handle 戰鬥中無效；等脫戰
        pendingGen = gen
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    armed = false
    if not IsHistoryShown() then return end
    local h = GetCloser()
    if not h then return end
    local ok, err = pcall(SecureHandlerExecute, h, CLOSE_SNIPPET)
    if not ok and ns.ReportError then ns.ReportError(err) end
end

local function Arm()
    closeGen = closeGen + 1
    armed = true
    local gen = closeGen
    C_Timer.After(Delay(), function()
        if gen ~= closeGen then return end
        if not IsMode("autoclose") then armed = false; return end
        CloseNow(gen)
    end)
end

-- 取消倒數（關掉功能、換模式）
local function Disarm()
    closeGen = closeGen + 1
    armed = false
    pendingGen = nil
    ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        SyncRegistration()
        GetCloser()            -- 脫戰的時候先建好
    elseif event == GO_TO then
        -- 自動彈出（或開著時又被叫一次）：從頭倒數
        if IsMode("autoclose") then Arm() end
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then
        -- 開著的時候有新的掉落／擲骰結果：重新計時（只管我們在倒數的那一個）
        if armed and IsMode("autoclose") and IsHistoryShown() then Arm() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
        local gen = pendingGen
        pendingGen = nil
        -- 兩種模式都可能走到這裡（hide 模式是「打開開關時視窗正開著」那一次）
        if gen and GetDB().enabled then CloseNow(gen) end
    end
end)
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent(GO_TO)
ev:RegisterEvent("LOOT_HISTORY_UPDATE_DROP")

-- 設定改了要當下生效，不等下一次掉落
local function ApplyNow()
    Disarm()
    SyncRegistration()
    if not GetDB().enabled or not IsHistoryShown() then return end
    if IsMode("hide") then
        -- 開關打開的當下視窗正開著：關掉它（同一條 secure 路）
        closeGen = closeGen + 1
        CloseNow(closeGen)
    elseif IsMode("autoclose") then
        Arm()
    end
end

------------------------------------------------------------
-- 對內 API（給 Options/Tab_QoL.lua 用；走 ns，不開全域）
------------------------------------------------------------
ns.LootHistoryAutoClose = {
    IsEnabled  = function() return GetDB().enabled and true or false end,
    SetEnabled = function(v) GetDB().enabled = v and true or false; ApplyNow() end,
    GetMode    = function() return GetDB().mode end,
    SetMode    = function(v)
        if v ~= "hide" and v ~= "autoclose" then return end
        GetDB().mode = v
        ApplyNow()
    end,
    GetDelay   = function() return Delay() end,
    SetDelay   = function(v)
        v = tonumber(v)
        if not v then return end
        GetDB().delay = math.min(30, math.max(1, math.floor(v + 0.5)))
        -- 正在倒數就用新的秒數重來
        if armed and IsMode("autoclose") then Arm() end
    end,
}
