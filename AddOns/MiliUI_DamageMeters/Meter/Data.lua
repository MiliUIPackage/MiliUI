------------------------------------------------------------
-- 資料層：C_DamageMeter 包裝、秘密值守衛、數字格式化、圖示解析
--
-- 全插件**只有這支檔案直接碰原生秘密值 API**（issecretvalue）。其餘模組一律走
-- D.IsSecret / D.SafeClass 之類的包裝，理由跟 Cell 的 Utils.lua 一樣：
-- 秘密值的規則會再變，只改一個地方。
------------------------------------------------------------
local _, ns = ...

ns.Data = {}
local D = ns.Data
local M = ns.Media
local L = ns.L

local issecret = ns.Secret.IsSecret
D.IsSecret = issecret

------------------------------------------------------------
-- 統計類型 / 分段類型
------------------------------------------------------------
local T = Enum.DamageMeterType or {}
local S = Enum.DamageMeterSessionType or {}
D.T, D.S = T, S

-- ⚠ 這三張表**不能寫成 table constructor**：舊客戶端沒有 Enum.DamageMeterType 時
--   `{ [T.DamageDone] = ... }` 的 key 會是 nil，那是載入時就炸的硬錯（table index is nil）。
--   逐筆檢查再塞，順便讓「暴雪哪天加一種統計類型」不必改結構。
--   名稱在這裡就翻好（TYPE_NAMES 存的是**譯文**，不是 key）。在這裡用字面字串
--   查一次、而不是讓呼叫端間接查 D.TYPE_NAMES 再套 L，是為了讓
--   miliui-locale-audit 掃得到這八條 —— 間接查表會被它報成「多餘的譯文」。
local TYPE_DEFS = {
    { "DamageDone",           L["Damage Done"],            "Interface\\Icons\\Ability_DualWield" },
    { "HealingDone",          L["Healing Done"],           "Interface\\Icons\\Spell_Holy_FlashHeal" },
    { "DamageTaken",          L["Damage Taken"],           "Interface\\Icons\\Ability_Warrior_ShieldGuard" },
    { "AvoidableDamageTaken", L["Avoidable Damage Taken"], "Interface\\Icons\\Spell_Fire_SelfDestruct" },
    { "EnemyDamageTaken",     L["Enemy Damage Taken"],     "Interface\\Icons\\Ability_Hunter_MarkedForDeath" },
    { "Interrupts",           L["Interrupts"],             "Interface\\Icons\\Ability_Kick" },
    { "Dispels",              L["Dispels"],                "Interface\\Icons\\Spell_Holy_DispelMagic" },
    { "Deaths",               L["Deaths"],                 "Interface\\Icons\\Ability_Rogue_FeignDeath" },
}

D.TYPE_NAMES = {}
D.TYPE_ICONS = {}
D.TYPE_ORDER = {}   -- 首頁與選單的排序，也決定「有哪些類型可選」
for _, def in ipairs(TYPE_DEFS) do
    local value = T[def[1]]
    if value ~= nil then
        D.TYPE_NAMES[value] = def[2]
        D.TYPE_ICONS[value] = def[3]
        D.TYPE_ORDER[#D.TYPE_ORDER + 1] = value
    end
end

-- 「次數」型統計不顯示每秒值，直接印整數
function D.IsCountType(dmType)
    if dmType == nil then return false end
    return dmType == T.Interrupts or dmType == T.Dispels
end

function D.IsDeathType(dmType)
    if dmType == nil or T.Deaths == nil then return false end
    return dmType == T.Deaths
end

------------------------------------------------------------
-- 秘密值守衛
------------------------------------------------------------
-- 這一列是不是自己？isLocalPlayer 是文件標記的 NeverSecret，所以戰鬥中讀它合法。
-- 但「文件寫錯」必須退化成「不是自己」（那一列就只是沒被釘住），
-- 絕對不能退化成一個丟出來的比較。
function D.IsOwnRow(src)
    local own = src and src.isLocalPlayer
    if own == nil or issecret(own) then return false end
    return own == true
end

-- classFile 可能是秘密 → 拿不到就回 nil，呼叫端自己決定退什麼
function D.SafeClass(classFile)
    if classFile == nil or issecret(classFile) or classFile == "" then return nil end
    return classFile
end

-- GUID 可能是秘密 → 秘密的絕對不能當 table key（會硬錯）
function D.PlainGUID(guid)
    if guid == nil or issecret(guid) then return nil end
    return guid
end

------------------------------------------------------------
-- 數字縮寫
--
-- 走暴雪的 AbbreviateNumbers：它是 C 端函式，**吃得下秘密數字**，
-- 自己用 math.floor 拆位數的話遇到秘密值就直接爆。
------------------------------------------------------------
-- 東亞客戶端按萬／億分級，K/M/B 對他們反而難讀；簡繁的算法一樣，只有字不同
local CJK = ({
    zhCN = { thousand = "千", wan = "万", yi = "亿" },
    zhTW = { thousand = "千", wan = "萬", yi = "億" },
    koKR = { thousand = "천", wan = "만", yi = "억" },
})[GetLocale()]

local function BuildAbbrevOpts(forceEnglish)
    if CJK and not forceEnglish then
        return {
            { breakpoint = 100000000, abbreviation = CJK.yi,       significandDivisor = 1000000, fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 10000,     abbreviation = CJK.wan,      significandDivisor = 100,     fractionDivisor = 100, abbreviationIsGlobal = false },
            { breakpoint = 1000,      abbreviation = CJK.thousand, significandDivisor = 100,     fractionDivisor = 10,  abbreviationIsGlobal = false },
            { breakpoint = 1,         abbreviation = "",           significandDivisor = 1,       fractionDivisor = 1,   abbreviationIsGlobal = false },
        }
    end
    return {
        { breakpoint = 1000000000, abbreviation = "B", significandDivisor = 10000000, fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1000000,    abbreviation = "M", significandDivisor = 10000,    fractionDivisor = 100, abbreviationIsGlobal = false },
        { breakpoint = 1000,       abbreviation = "K", significandDivisor = 100,      fractionDivisor = 10,  abbreviationIsGlobal = false },
        { breakpoint = 1,          abbreviation = "",  significandDivisor = 1,        fractionDivisor = 1,   abbreviationIsGlobal = false },
    }
end

local _abbrevCfg

-- 只在「載入時」與「玩家翻那個選項時」重建一次。成本是一個 config 物件，
-- 完全不碰每列／每次刷新的路徑。
function D.RebuildNumberFormat()
    local forceEnglish = false
    local style = ns.DB and ns.DB.Style()
    if style and style.forceEnglishUnits then forceEnglish = true end
    if CreateAbbreviateConfig then
        _abbrevCfg = { config = CreateAbbreviateConfig(BuildAbbrevOpts(forceEnglish)) }
    end
end
D.RebuildNumberFormat()

function D.Abbrev(n)
    if n == nil then return "0" end
    if AbbreviateNumbers then
        return AbbreviateNumbers(n, _abbrevCfg) or "0"
    end
    -- 備援路徑：只有在 AbbreviateNumbers 不存在時才會走到，此時秘密值也無解，
    -- tonumber 會回 nil，印個問號比讓整個刷新爆掉好
    local num = tonumber(n)
    if not num then return "?" end
    if CJK then
        if num >= 1e8 then return format("%.2f%s", num / 1e8, CJK.yi)
        elseif num >= 1e4 then return format("%.2f%s", num / 1e4, CJK.wan)
        elseif num >= 1e3 then return format("%.1f%s", num / 1e3, CJK.thousand)
        end
        return format("%.0f", num)
    end
    if num >= 1e9 then return format("%.1fB", num / 1e9)
    elseif num >= 1e6 then return format("%.1fM", num / 1e6)
    elseif num >= 1e3 then return format("%.1fK", num / 1e3)
    end
    return format("%.0f", num)
end

-- numberFormat: 0 只每秒 / 1 只總量 / 2 「總量 (每秒)」 / 3 「總量 | 每秒」
function D.FormatValue(amt, perSec, numFmt)
    -- 長時間的 Overall 會讓每秒值掉到 1 以下，印出來是一串小數。夾成最小 1，
    -- 但只對明碼數字做——秘密值不能比較（而且秘密的分段都很短，不會小於 1）
    if perSec ~= nil and not issecret(perSec) and perSec < 1 then perSec = 1 end
    if numFmt == 0 then return D.Abbrev(perSec) end
    if numFmt == 2 and perSec then return format("%s (%s)", D.Abbrev(amt), D.Abbrev(perSec)) end
    if numFmt == 3 and perSec then return format("%s | %s", D.Abbrev(amt), D.Abbrev(perSec)) end
    return D.Abbrev(amt)
end

------------------------------------------------------------
-- 法術標籤：寵物／守護物放的技能，後面用灰括號標出施法者
--
-- 來源是 `spell.creatureName`。本來只拿它當「查不到法術名」的退路，但它其實是
-- **施法的寵物名**（Details 也是這樣用的：`法術名 (creatureName)`）。
-- 玩家自己放的技能這一欄是空的。
--
-- ⚠ 它可能是秘密字串：串接與 SetFormattedText 都合法（C 端吃得下、FontString
--   顯示得出來），但**不能測 `~= ""`**，所以秘密的那條路要先分出來。
------------------------------------------------------------
function D.SpellLabel(fs, spellName, creatureName, fallback)
    if issecret(creatureName) then
        fs:SetFormattedText("%s (|cFF999999%s|r)", spellName or fallback, creatureName)
    elseif spellName and creatureName and creatureName ~= "" then
        fs:SetFormattedText("%s (|cFF999999%s|r)", spellName, creatureName)
    else
        fs:SetText(spellName or creatureName or fallback)
    end
end

function D.StripRealm(name)
    if name == nil then return "?" end
    if Ambiguate then return Ambiguate(name, "short") or name end
    return name
end

function D.FormatTimer(seconds)
    if not seconds or issecret(seconds) then return "0:00" end
    return format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

------------------------------------------------------------
-- C_DamageMeter 包裝
--
-- 吃 GUID 的呼叫全部包 pcall：秘密 GUID 進去時 API 的行為沒有保證，
-- 而這些呼叫在刷新迴圈裡，一次拋錯等於整個視窗停更。
------------------------------------------------------------
function D.GetSession(sessionType, sessionID, dmType)
    if not ns.HAS_API then return nil end
    if sessionID then
        local ok, s = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, dmType)
        return ok and s or nil
    end
    local ok, s = pcall(C_DamageMeter.GetCombatSessionFromType, sessionType, dmType)
    return ok and s or nil
end

function D.GetSource(sessionType, sessionID, dmType, guid, creatureID)
    if not ns.HAS_API then return nil end
    if sessionID and C_DamageMeter.GetCombatSessionSourceFromID then
        local ok, sd = pcall(C_DamageMeter.GetCombatSessionSourceFromID, sessionID, dmType, guid, creatureID)
        return ok and sd or nil
    end
    if C_DamageMeter.GetCombatSessionSourceFromType then
        local ok, sd = pcall(C_DamageMeter.GetCombatSessionSourceFromType, sessionType, dmType, guid, creatureID)
        return ok and sd or nil
    end
    return nil
end

function D.GetAvailableSessions()
    if not ns.HAS_API or not C_DamageMeter.GetAvailableCombatSessions then return nil end
    local ok, list = pcall(C_DamageMeter.GetAvailableCombatSessions)
    return ok and list or nil
end

function D.GetSessionDuration(sessionType, sessionID)
    if not ns.HAS_API then return nil end
    if sessionID then
        local list = D.GetAvailableSessions()
        if list then
            for _, s in ipairs(list) do
                if s.sessionID == sessionID then return s.durationSeconds end
            end
        end
        return nil
    end
    if not C_DamageMeter.GetSessionDurationSeconds then return nil end
    local ok, d = pcall(C_DamageMeter.GetSessionDurationSeconds, sessionType)
    return ok and d or nil
end

function D.ResetAll()
    if ns.HAS_API and C_DamageMeter.ResetAllCombatSessions then
        C_DamageMeter.ResetAllCombatSessions()
    end
end

------------------------------------------------------------
-- 圖示
--
-- 三種樣式，全部用暴雪內建資源：
--   spec  專精圖示（source.specIconID，是個 fileID）→ 沒有就退職業 sprite
--   class 職業 sprite（CLASS_ICON_TCOORDS）
--   none  不畫
-- 回傳圖示佔用的寬度（0 = 沒畫），呼叫端用它決定填充條從哪裡開始。
------------------------------------------------------------
local CLASS_SPRITE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local function ZoomCoords(u1, u2, v1, v2, z)
    local du, dv = (u2 - u1) * z, (v2 - v1) * z
    return u1 + du, u2 - du, v1 + dv, v2 - dv
end

local function ApplyClassSprite(tex, classFile, zoom)
    tex:SetTexture(CLASS_SPRITE)
    local co = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if co then
        tex:SetTexCoord(ZoomCoords(co[1], co[2], co[3], co[4], zoom))
    else
        tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
    end
end

function D.ResolveIcon(src, tex, size, style, zoom)
    if style == "none" then tex:Hide(); return 0 end
    zoom = zoom or 0.06

    local classFile = D.SafeClass(src.classFilename)
    -- 拿不到職業（秘密值、NPC、寵物）就不畫圖示：畫一個猜出來的職業圖比空白更糟
    if not classFile then tex:Hide(); return 0 end

    if style == "spec" then
        local specIcon = src.specIconID
        if specIcon and not issecret(specIcon) and type(specIcon) == "number" and specIcon ~= 0 then
            tex:SetTexture(specIcon)
            tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        else
            ApplyClassSprite(tex, classFile, zoom)
        end
    else
        ApplyClassSprite(tex, classFile, zoom)
    end

    tex:SetSize(size, size)
    tex:SetDesaturated(false)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:Show()
    return size
end

------------------------------------------------------------
-- 在不在探究（Delve）裡
--
-- ⚠ 用 `C_PartyInfo.IsPartyWalkIn()`，**不要用 `IsDelveInProgress()`**。
--   本機的證據很一致：Plumber 與 Cell 都把 `IsDelveInProgress` 註解掉改用這支，
--   我們自己的 MiliUI/Enhance/Delves_MarkButton.lua 也是（實機驗證過，
--   見 notes/wow-delve-detection）。EUI 用的是大家已經放棄的那支。
--
-- ⚠ 已知延遲：**離開探究的那一瞬間它還會回 true**（Plumber 的 API.lua 為此加了
--   0.5 秒的強制延遲）。所以呼叫端不能只在換區事件當下判斷一次 ——
--   Manager 的顯示條件另外排了一次延後重算。
------------------------------------------------------------
function D.IsInDelve()
    return (C_PartyInfo and C_PartyInfo.IsPartyWalkIn and C_PartyInfo.IsPartyWalkIn()) and true or false
end

------------------------------------------------------------
-- 像素對齊：設定值＝實體像素數，換算成能對齊實體像素的框架單位。
-- 列高／間距一律走這裡，否則 UI 縮放不是整數倍時每一列會差半個像素，
-- 四十列累積下來就是「最後幾列跟捲軸對不上」。
------------------------------------------------------------
function D.Px(userValue)
    if not userValue or userValue == 0 then return 0 end
    if ns.P and ns.P.Scale then return ns.P.Scale(userValue) end
    return userValue
end

------------------------------------------------------------
-- 排名字串：40 個字串開檔就備好，省掉每次刷新的 i .. "."
------------------------------------------------------------
D.RANK = {}
for i = 1, 40 do D.RANK[i] = i .. "." end
