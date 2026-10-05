------------------------------------------------------------
-- 宣告巨集
--
-- 12.x 的聊天封鎖（M+ 整趟、首領戰、戰場）擋的是「插件 Lua 呼叫 SendChatMessage」
-- 與安全按鈕的 macrotext；**玩家巨集書裡的巨集不在此列**。暴雪 2026-03-01 公告：
-- 遭遇戰中巨集仍可送「隊伍專屬頻道」（隊伍／團隊／副本），只是短時間連送會被擋、
-- 而且全隊都要在副本內；被禁的是公會、自訂頻道這類非隊伍頻道。
--
-- 所以宣告改成：把「/p 宣告內容」寫進巨集書裡一顆保留巨集，標記列的宣告鈕做成
-- SecureActionButton type="macro" 去跑它。點一下才喊，不是每次設專注目標都喊。
--
-- 規矩與代價：
--   * 佔一格巨集（一般 120 格優先，滿了退到角色 18 格）。玩家看得到、也刪得掉，
--     刪了下次會自己補回來。
--   * CreateMacro／EditMacro 戰鬥中不能呼叫 → 標記、範本、隊伍型態的變動都要
--     脫戰才寫得進巨集；戰鬥中按下去送的是舊內容（按鈕會提示）。
--   * 巨集上限 255 位元組；隊友那串塞不下就從後面砍。
--   * 沒組隊時 /p 會噴系統錯誤 → 這時按鈕不掛巨集，退回本地印預覽。
--   * 標記列沒開就不建巨集：不要替沒用這功能的人在巨集書裡塞東西。
--
-- 「每次設專注目標都宣告」模式（db.bar.announceOnMark）另用第二顆巨集
-- MiliUI_FocusMark：內容＝Shift+點擊的專注／標記那幾行＋宣告那一行，
-- Focuser 的巨集按鈕改跑它（type=macro 的 macro 屬性優先於 macrotext）。
-- 為什麼不能沿用 macrotext 再串一下：
--   * macrotext 送不出聊天（M+／首領戰會擋）；
--   * 11.0.2 起 macrotext 裡的 /click 叫不動另一顆巨集按鈕；
--   * 宣告那顆巨集也不能直接塞專注那幾行——喇叭鈕本身在滑鼠底下，
--     `/clearfocus [@mouseover,noexists]` 會把專注目標清掉。
-- 宣告前一行 /stopmacro 擋掉「滑鼠下沒有活著的敵人」（快捷鍵對空氣按＝清專注、
-- 對隊友設專注），只有真的盯上一隻怪才喊。
------------------------------------------------------------
local _, ns = ...

ns.AnnounceMacro = {}
local AM = ns.AnnounceMacro

local MACRO_NAME  = "MiliUI_Focus"              -- 巨集名稱上限 16 字
local MARK_MACRO_NAME = "MiliUI_FocusMark"      -- 剛好 16 字
local MACRO_ICON  = "Ability_Warrior_BattleShout"
local MACRO_BYTES = 255
local MAX_PEERS   = 6                           -- 宣告附帶的隊友上限（團隊裡不洗版）

AM.MACRO_NAME = MACRO_NAME
AM.MARK_MACRO_NAME = MARK_MACRO_NAME

-- 滑鼠下不是活著的敵人就不喊（沒有東西／友方／屍體）
local STOP_LINE = "/stopmacro [@mouseover,noharm][@mouseover,dead]"

local L = ns.L

-- 狀態（AM.GetState）：
--   ready    巨集內容就是現在該送的內容，按鈕已掛上
--   off      標記列沒開 → 不建巨集
--   nomark   還沒選標記
--   nogroup  沒組隊（沒有頻道可送）
--   noslot   巨集欄位全滿
--   toolong  內容超過 255 位元組
--   failed   CreateMacro／EditMacro 失敗
local state    = "off"
local pending  = false   -- 戰鬥中有變動還沒寫進巨集
local lastBody = nil     -- 最後一次確認寫進巨集的內容
-- 「每次設專注目標都宣告」那顆的狀態，跟上面同一套代碼，另加 noautomark（自動標記沒開）
local markState    = "off"
local markLastBody = nil
local writing  = false   -- EditMacro 會派 UPDATE_MACROS，擋掉重入

----------------------------------------------------------------------
-- 頻道：chatType 給 SendChatMessage 退路用、slash 給巨集用
-- 斜線指令從 GlobalStrings 讀（各語系客戶端一定認得自己的 SLASH_*1）
----------------------------------------------------------------------
function AM.GetChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT", SLASH_INSTANCE_CHAT1 or "/i"
    elseif IsInRaid() then
        return "RAID", SLASH_RAID1 or "/raid"
    elseif IsInGroup() then
        return "PARTY", SLASH_PARTY1 or "/p"
    end
    return nil
end

----------------------------------------------------------------------
-- 訊息
----------------------------------------------------------------------
local function MarkIcon(index, size)
    return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_"
        .. index .. ":" .. (size or 14) .. "|t"
end

-- 組出宣告訊息。宣告的是「設定的自動標記圖示」（告訴隊友：這個標記就是
-- 我的專注打斷目標），不讀專注目標身上的標記，所以不需要專注目標存在。
--   forChat  = true 用 {rtN}（送進頻道由客戶端轉圖示）；
--              false 用 |T...|t 材質跳脫（print / tooltip 本地顯示用，{rtN} 在本地不會轉）
--   maxBytes = 位元組上限（巨集用）；隊友那串放不下就從後面砍，砍到剩主句為止
-- 回傳 訊息 或 nil, 錯誤說明
function AM.BuildMessage(forChat, maxBytes)
    local index = ns.db and ns.db.focus.markIndex or 0
    if index < 1 or index > 8 then
        return nil, L["Pick a marker icon first (click the icon on the left)."]
    end
    local iconToken = forChat and ("{rt" .. index .. "}") or MarkIcon(index, 16)
    local text = ns.db.bar.announceText or L["My focus interrupt target is {icon}!"]
    local base = (text:gsub("{icon}", iconToken))

    -- 帶上隊友的標記，隊友一眼就看得出誰盯哪一隻。只列有設標記的。
    local parts, truncated = {}, false
    for _, p in ipairs(ns.Sync.GetPeers()) do
        if p.index >= 1 and p.index <= 8 then
            if #parts >= MAX_PEERS then truncated = true; break end
            local token = forChat and ("{rt" .. p.index .. "}") or MarkIcon(p.index, 16)
            parts[#parts + 1] = p.name .. token
        end
    end

    local function Compose()
        if #parts == 0 then return base end
        return base .. "(" .. L["Teammates:"] .. " " .. table.concat(parts, " ")
            .. (truncated and " …" or "") .. ")"
    end

    local msg = Compose()
    while maxBytes and #msg > maxBytes and #parts > 0 do
        table.remove(parts)
        truncated = true
        msg = Compose()
    end
    return msg
end

----------------------------------------------------------------------
-- 巨集書
----------------------------------------------------------------------
local function HasMacroAPI()
    return type(GetMacroIndexByName) == "function" and type(GetMacroInfo) == "function"
        and type(CreateMacro) == "function" and type(EditMacro) == "function"
end

local function NormalizeBody(body)
    if type(body) ~= "string" then return nil end
    body = body:gsub("\r\n", "\n"):gsub("\r", "\n")
    return (body:gsub("\n+$", ""))
end

-- 讓巨集書裡的保留巨集 name 內容等於 body。脫戰才叫。回傳 true，或 false, 原因
local function EnsureMacro(name, body, createdMsg)
    if not HasMacroAPI() then return false, "failed" end
    local idx = GetMacroIndexByName(name)
    if idx and idx > 0 then
        local _, _, existing = GetMacroInfo(idx)
        if NormalizeBody(existing) == NormalizeBody(body) then return true end
        local ok = pcall(EditMacro, idx, name, MACRO_ICON, body)
        return ok, (not ok) and "failed" or nil
    end

    local general, perChar = GetNumMacros()
    local ok
    if (general or 0) < (MAX_ACCOUNT_MACROS or 120) then
        ok = pcall(CreateMacro, name, MACRO_ICON, body, false)
    elseif (perChar or 0) < (MAX_CHARACTER_MACROS or 18) then
        ok = pcall(CreateMacro, name, MACRO_ICON, body, true)
    else
        return false, "noslot"
    end
    idx = GetMacroIndexByName(name)
    if ok and idx and idx > 0 then
        -- 巨集書裡突然多一顆巨集，要講一聲，不然玩家會以為是別的東西塞的
        ns.Print(createdMsg:format("|cffffd200" .. name .. "|r"))
        return true
    end
    return false, "failed"
end

----------------------------------------------------------------------
-- 重算：內容 → 巨集 → 按鈕
----------------------------------------------------------------------
local function ShouldExist()
    return ns.db and ns.db.bar.shown and ns.db.focus.enabled
end

-- 「每次設專注目標都宣告」另外要自動標記有開（Refresh 裡判）：沒標上去還喊
-- 「我的目標是{icon}」只會誤導隊友
local function ShouldExistMark()
    return ShouldExist() and ns.db.bar.announceOnMark
end

-- 第二顆巨集的內容：專注／標記那幾行（跟 Shift+點擊的 macrotext 同一份）＋擋線＋宣告
local function BuildMarkBody(slash)
    local prefix = ns.Focuser.GetMacroForMarkIndex(nil) .. "\n" .. STOP_LINE .. "\n" .. slash .. " "
    local msg = AM.BuildMessage(true, MACRO_BYTES - #prefix)
    return msg and (prefix .. msg) or nil
end

function AM.Refresh()
    if not ns.db or writing then return end

    local desired, desiredMark
    local _, slash = AM.GetChannel()
    if slash and ShouldExist() then
        local msg = AM.BuildMessage(true, MACRO_BYTES - #slash - 1)
        if msg then desired = slash .. " " .. msg end
    end
    local autoMarkOn = ns.Focuser.GetEffectiveMarkIndex() >= 1
    if slash and ShouldExistMark() and autoMarkOn then
        desiredMark = BuildMarkBody(slash)
    end

    if InCombatLockdown() then
        -- 巨集與按鈕的保護屬性都不能動；只記下「有沒有東西等著寫」
        if desired ~= lastBody or desiredMark ~= markLastBody then pending = true end
        if ns.MarkBar and ns.MarkBar.ApplyAnnounceButton then ns.MarkBar.ApplyAnnounceButton() end
        return
    end
    pending = false

    if not ShouldExist() then
        state = "off"
    elseif not (ns.db.focus.markIndex and ns.db.focus.markIndex >= 1 and ns.db.focus.markIndex <= 8) then
        state = "nomark"
    elseif not desired then
        state = "nogroup"
    elseif #desired > MACRO_BYTES then
        state = "toolong"
    else
        writing = true
        local ok, why = EnsureMacro(MACRO_NAME, desired,
            L["Created the %s macro in your macro book. It carries the focus announcement so it can be sent in Mythic+ and boss fights; deleting it just recreates it."])
        writing = false
        if ok then
            state, lastBody = "ready", desired
        else
            state = why or "failed"
        end
    end

    markLastBody = nil
    if not ShouldExistMark() then
        markState = "off"
    elseif not autoMarkOn then
        markState = "noautomark"
    elseif not slash then
        markState = "nogroup"
    elseif not desiredMark or #desiredMark > MACRO_BYTES then
        markState = "toolong"   -- 主句加上專注那幾行就超過 255
    else
        writing = true
        local ok, why = EnsureMacro(MARK_MACRO_NAME, desiredMark,
            L["Created the %s macro in your macro book. It sets focus, marks and announces in one go when \"announce on every focus\" is on; deleting it just recreates it."])
        writing = false
        if ok then
            markState, markLastBody = "ready", desiredMark
        else
            markState = why or "failed"
        end
    end
    -- 巨集按鈕改跑哪一份（第二顆巨集／原本的 macrotext）
    ns.Focuser.ApplyAnnounceMode()

    if ns.MarkBar and ns.MarkBar.ApplyAnnounceButton then ns.MarkBar.ApplyAnnounceButton() end
end

function AM.GetState()  return state end
function AM.IsUsable()  return state == "ready" end
function AM.IsPending() return pending end
function AM.GetMarkState()       return markState end
function AM.IsMarkMacroUsable()  return markState == "ready" end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pending then AM.Refresh() end
    else
        -- PLAYER_ENTERING_WORLD：登入／重載後對一次
        -- GROUP_ROSTER_UPDATE：頻道可能變（隊伍↔團隊↔副本隊伍↔沒組隊）
        -- UPDATE_MACROS：巨集書載入完成，或玩家動了巨集（刪掉就補回來；
        --                自己 EditMacro 引發的那次，內容已相同不會再寫）
        AM.Refresh()
    end
end)

ns.RegisterCallback("Init", "announceMacro", function()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("UPDATE_MACROS")
    AM.Refresh()
end)

-- 標記、範本改了（設定頁 Apply／標記選單）；隊友名單變了（Sync）
ns.RegisterCallback("SettingsChanged", "announceMacro", AM.Refresh)
ns.RegisterCallback("PeersChanged", "announceMacro", AM.Refresh)
