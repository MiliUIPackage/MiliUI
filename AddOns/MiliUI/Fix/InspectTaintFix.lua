------------------------------------------------------------
-- MiliUI: Inspect 系列 taint 修正
--   目標：
--     1. TinyInspect/InspectCore.lua:31 — guids[guid] "table index is secret"
--     2. Blizzard_InspectUI/Blizzard_InspectUI.lua:40 — "compare a secret string"
--     3. Blizzard_InspectUI/InspectGuildFrame.lua:7    — "compare a secret string"
--
--   原因：
--     Stuf 單位框架的 OnEnter/Tooltip 路徑污染執行堆疊後，
--     後續呼叫 UnitGUID()、NotifyInspect() 取回的字串變成 secret，
--     TinyInspect 與 Blizzard_InspectUI 皆未處理 secret 字串。
--
--   原則（與 Stuf_Fix / TooltipTaintFix 一致）：
--     • 不替換任何「全域 Blizzard 函式」避免把 MiliUI 當作 taint 來源
--     • 對第三方插件的全域 API：以 pcall 包裝原函式（不改動原實作）
--     • 對 Blizzard InspectFrame / InspectGuildFrame 的 OnEvent：
--       僅替換該「特定框架實例」的 script，用 pcall 吞掉 secret 錯誤；
--       對全域環境無額外副作用，效能成本幾乎為零（僅多一層 pcall）。
------------------------------------------------------------
local AddonName = ...
if AddonName ~= "MiliUI" then return end

local pcall = pcall
local type = type
local string_find = string.find

------------------------------------------------------------
-- 判斷錯誤是否為 secret value taint（其他錯誤正常拋出）
------------------------------------------------------------
local function IsSecretError(err)
    return type(err) == "string" and string_find(err, "secret", 1, true) ~= nil
end

-- secret error 被吞掉後，Blizzard 內部資料常會留下 nil，
-- 後續呼叫如 SetFormattedText / SetText 等遇到 nil 會丟 "bad argument"。
-- 把這類後續錯誤也視為相同根因一起吞掉。
local function IsTaintFollowupError(err)
    if type(err) ~= "string" then return false end
    if string_find(err, "bad argument", 1, true) then return true end
    if string_find(err, "string expected, got nil", 1, true) then return true end
    return false
end

local function ShouldSwallowError(err)
    return IsSecretError(err) or IsTaintFollowupError(err)
end

------------------------------------------------------------
-- 1) TinyInspect: 包裝 GetInspecting / GetInspectInfo
--    原函式對 guids[guid] 做索引時，若 guid 為 secret string 會炸。
--    我們不動 TinyInspect 原始碼，只在全域層 pcall 包一層。
------------------------------------------------------------
local function WrapTinyInspectGlobals()
    if _G.GetInspecting and not _G._miliOrigGetInspecting then
        local orig = _G.GetInspecting
        _G._miliOrigGetInspecting = orig
        _G.GetInspecting = function(...)
            local ok, r = pcall(orig, ...)
            if ok then return r end
            if not IsSecretError(r) then error(r, 2) end
            -- secret taint: 視同「沒有正在進行的 inspect」
            return nil
        end
    end
    if _G.GetInspectInfo and not _G._miliOrigGetInspectInfo then
        local orig = _G.GetInspectInfo
        _G._miliOrigGetInspectInfo = orig
        _G.GetInspectInfo = function(...)
            local ok, r = pcall(orig, ...)
            if ok then return r end
            if not IsSecretError(r) then error(r, 2) end
            return nil
        end
    end
end

------------------------------------------------------------
-- 2) Blizzard_InspectUI: 對 InspectFrame / InspectGuildFrame 的 script 包 pcall
--    僅攔截 secret 類錯誤與其後續 nil-argument 錯誤，其他錯誤維持原行為。
--    因為原本 script 是由 Blizzard code 安全註冊的，我們在 Blizzard_InspectUI
--    載入後立即用 pcall 包一層，對 taint 不會有放大效應。
------------------------------------------------------------
local function WrapFrameScript(frame, scriptName, flagKey)
    if not frame then return end
    if frame[flagKey] then return end
    local orig = frame:GetScript(scriptName)
    if not orig then return end
    frame[flagKey] = true
    frame:SetScript(scriptName, function(self, ...)
        local ok, err = pcall(orig, self, ...)
        if not ok and not ShouldSwallowError(err) then
            error(err, 2)
        end
    end)
end

local function WrapBlizzardInspectFrames()
    -- OnEvent：避免 secret 字串比對直接炸
    WrapFrameScript(_G.InspectFrame,        "OnEvent", "_miliOnEventWrapped")
    WrapFrameScript(_G.InspectGuildFrame,   "OnEvent", "_miliOnEventWrapped")
    WrapFrameScript(_G.InspectPVPFrame,     "OnEvent", "_miliOnEventWrapped")
    WrapFrameScript(_G.InspectTalentFrame,  "OnEvent", "_miliOnEventWrapped")

    -- OnShow：secret error 在 OnEvent 被吞掉後，frame 的 guildName/title 等資料會殘留 nil；
    -- OnShow → InspectGuildFrame_Update → SetFormattedText(nil) 會炸，這裡一併吞掉。
    WrapFrameScript(_G.InspectGuildFrame, "OnShow", "_miliOnShowWrapped")
end

------------------------------------------------------------
-- 載入觸發
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "TinyInspect" then
            WrapTinyInspectGlobals()
        elseif addon == "Blizzard_InspectUI" then
            WrapBlizzardInspectFrames()
        end
    elseif event == "PLAYER_LOGIN" then
        -- 保險：若 ADDON_LOADED 比 PLAYER_LOGIN 先觸發並已載入，也確保包裝完成
        if _G.GetInspecting then WrapTinyInspectGlobals() end
        if _G.InspectFrame then WrapBlizzardInspectFrames() end
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
