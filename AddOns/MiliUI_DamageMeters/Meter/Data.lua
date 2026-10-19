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

------------------------------------------------------------
-- 合併檢視：一個視窗切成左右兩欄，各看一種統計類型
--
-- 它不是暴雪的統計類型，只是「左欄問 A、右欄問 B」的一個名字 —— 資料照舊是兩次
-- 各自獨立的 GetCombatSession。**不去把兩份清單照人合併成一列兩個數字**：
-- 那要拿 GUID／名字配對，而戰鬥中兩者都是秘密值（不能當 key、不能比較），
-- 最需要看打斷的傳奇鑰石裡剛好整個做不出來。兩欄各自排行則完全不碰身分。
--
-- 值用字串：跟 Enum.DamageMeterType 的數字不可能撞號，暴雪以後加類型也一樣。
-- 存進 wdb.curDMType 的就是這個字串，**改名等於把玩家的選擇洗掉**。
------------------------------------------------------------
local SPLIT_DEFS = {
    -- after＝排在哪個類型後面（打斷、驅散之後緊接著就是它們的合併檢視）
    { key = "InterruptsDispels", left = "Interrupts", right = "Dispels", after = "Dispels",
      name = L["Interrupts & Dispels"], icon = "Interface\\Icons\\Spell_Frost_IceShock" },
}
-- 合併類型的值 → 正規化的 def：{ left = { type, seg }, right = { type, seg } }。
-- 內建與自訂長同一個形狀，消費端（Rows、Publish、Breakdown…）不必分兩條路。
local _split = {}

D.TYPE_NAMES = {}
D.TYPE_ICONS = {}
D.TYPE_ORDER = {}   -- 首頁與選單的排序，也決定「有哪些類型可選」

-- 內建部分（暴雪類型＋內建合併）的快照。它只跟客戶端有關，載入時算一次；
-- RefreshTypes 每次從它重灌，再把玩家自己組的接在後面。
local BASE_NAMES, BASE_ICONS, BASE_ORDER, BASE_SPLIT = {}, {}, {}, {}
for _, def in ipairs(TYPE_DEFS) do
    local value = T[def[1]]
    if value ~= nil then
        BASE_NAMES[value] = def[2]
        BASE_ICONS[value] = def[3]
        BASE_ORDER[#BASE_ORDER + 1] = value
    end
    for _, sp in ipairs(SPLIT_DEFS) do
        -- 兩個成員都存在的客戶端才提供（舊客戶端少一種就整個不出現）
        if sp.after == def[1] and T[sp.left] ~= nil and T[sp.right] ~= nil then
            BASE_SPLIT[sp.key] = {
                left  = { type = T[sp.left],  seg = "follow" },
                right = { type = T[sp.right], seg = "follow" },
            }
            BASE_NAMES[sp.key] = sp.name
            BASE_ICONS[sp.key] = sp.icon
            BASE_ORDER[#BASE_ORDER + 1] = sp.key
        end
    end
end

-- 自訂組合的名稱：兩欄都跟著視窗就是「A / B」；有釘分段的欄在名字後面接「·分段」。
-- 只在 RefreshTypes 時算，不進每幀的路徑。類型在這支客戶端不存在就印「?」
-- （設定頁的列表還是要列得出它，見 Options/Tab_Each.lua）。
local function SideName(side)
    local name = BASE_NAMES[side.type] or "?"
    local seg = D.SegLabel(side.seg)
    if seg then return name .. "·" .. seg end
    return name
end

function D.SegLabel(seg)
    if seg == "current" then return L["Current"] end
    if seg == "overall" then return L["Overall"] end
    return nil
end

function D.SplitName(def)
    return format("%s / %s", SideName(def.left), SideName(def.right))
end

-- 自訂組合的兩個類型在這支客戶端都有，才算數
function D.SplitAvailable(def)
    local a, b = def.left.type, def.right.type
    -- 只收暴雪的類型：合併套合併沒有意義（BASE_NAMES 裡也有內建合併的字串 key）
    return type(a) == "number" and type(b) == "number"
        and BASE_NAMES[a] ~= nil and BASE_NAMES[b] ~= nil
end

-- 三張表重建：內建照舊在前，自訂照建立順序接在最後。
-- 呼叫點：Windows.Rebuild 開頭（登入、匯入、換設定檔都以重載收尾，一定會走到）
-- 與 DB 的每個寫入口。三張表的名字與形狀不變，消費端一行都不必改。
function D.RefreshTypes()
    wipe(D.TYPE_NAMES); wipe(D.TYPE_ICONS); wipe(D.TYPE_ORDER); wipe(_split)
    for k, v in pairs(BASE_NAMES) do D.TYPE_NAMES[k] = v end
    for k, v in pairs(BASE_ICONS) do D.TYPE_ICONS[k] = v end
    for k, v in pairs(BASE_SPLIT) do _split[k] = v end
    for i = 1, #BASE_ORDER do D.TYPE_ORDER[i] = BASE_ORDER[i] end

    local DB = ns.DB
    if not (DB and DB.Splits and ns.db) then return end
    for _, def in ipairs(DB.Splits().list) do
        -- 這支客戶端沒有的類型：跳過不列、也不刪（換回新客戶端就回來）
        if D.SplitAvailable(def) then
            local key = DB.SPLIT_PREFIX .. def.id
            _split[key] = def
            D.TYPE_NAMES[key] = D.SplitName(def)
            D.TYPE_ICONS[key] = BASE_ICONS[def.left.type]
            D.TYPE_ORDER[#D.TYPE_ORDER + 1] = key
        end
    end
end
D.RefreshTypes()

function D.IsValidType(v)
    return v ~= nil and D.TYPE_NAMES[v] ~= nil
end

function D.IsCustomSplit(v)
    return type(v) == "string" and v:match("^custom:") ~= nil
end

-- "custom:3" → 3；其他回 nil
function D.SplitIdOf(v)
    if not D.IsCustomSplit(v) then return nil end
    return tonumber(v:match("^custom:(%d+)$"))
end

function D.SplitDef(dmType)
    return dmType ~= nil and _split[dmType] or nil
end

-- 合併類型 → 左欄類型, 右欄類型；一般類型回 nil
function D.SplitTypes(dmType)
    local def = D.SplitDef(dmType)
    if not def then return nil end
    return def.left.type, def.right.type
end

------------------------------------------------------------
-- 這一欄實際要問 API 的分段
--
-- 視窗的分段只管 seg＝follow 的欄。釘住的欄回的是我們自己的 Enum 值，
-- 不是 API 的回傳值，所以這條路上沒有秘密值。
-- side = "left" | "right"；nil、或這不是合併類型，就是視窗自己的分段。
-- dmType 預設是視窗正在看的類型；首頁的卡片要問的是那張卡片的類型，所以可以另外給。
------------------------------------------------------------
function D.PaneSession(W, side, dmType)
    local def = side and D.SplitDef(dmType or W.curDMType)
    local seg = def and def[side] and def[side].seg
    if seg == "current" then return S.Current, nil end
    if seg == "overall" then return S.Overall, nil end
    return W.curSession, W.curSessionID
end

-- 兩欄都釘住了分段：視窗的分段在畫面上沒有任何作用（標題、選單、智慧顯示要退場）
function D.BothPinned(W)
    local def = D.SplitDef(W.curDMType)
    return def ~= nil and def.left.seg ~= "follow" and def.right.seg ~= "follow"
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
-- 專精對照：暴雪專精圖示（fileID）→ 專精資訊
--
-- C_DamageMeter 的 source 只給 specIconID，沒有 specID。要換成自己的圖、或寫出
-- 「獸王 獵人」，都得先從圖示反查專精。圖示 fileID 每個專精唯一，所以第一次用到
-- 時把全部職業的專精掃一遍建表就好（13 職業 × 3～4 專精，一次性成本）。
--
-- 自己的圖檔照「職業-專精」命名（Media/Spec/hunter-beastmastery.png），
-- 專精名用**暴雪的專精順序**對（GetSpecializationInfoForClassID 的第 i 個）——
-- 不寫死 specID：新專精（噬滅）的 ID 寫錯就整張對不到，順序則跟遊戲內的天賦頁一樣。
-- ⚠ 暴雪改了某職業的專精順序，這張表要跟著改，否則圖會錯位到同職業別的專精上。
------------------------------------------------------------
local SPEC_KEYS = {
    DEATHKNIGHT = { "blood", "frost", "unholy" },
    DEMONHUNTER = { "havoc", "vengeance", "devourer" },
    DRUID       = { "balance", "feral", "guardian", "restoration" },
    EVOKER      = { "devastation", "preservation", "augmentation" },
    HUNTER      = { "beastmastery", "marksmanship", "survival" },
    MAGE        = { "arcane", "fire", "frost" },
    MONK        = { "brewmaster", "mistweaver", "windwalker" },
    PALADIN     = { "holy", "protection", "retribution" },
    PRIEST      = { "discipline", "holy", "shadow" },
    ROGUE       = { "assassination", "outlaw", "subtlety" },
    SHAMAN      = { "elemental", "enhancement", "restoration" },
    WARLOCK     = { "affliction", "demonology", "destruction" },
    WARRIOR     = { "arms", "fury", "protection" },
}
local SPEC_TEX_DIR = "Interface\\AddOns\\MiliUI_DamageMeters\\Media\\Spec\\"
-- 米利風格的職業圖（Media/Class/<職業>.png，13 張）：還不知道專精時的退路
local CLASS_TEX_DIR = "Interface\\AddOns\\MiliUI_DamageMeters\\Media\\Class\\"

local specByIcon, specByID
local function BuildSpecMap()
    specByIcon, specByID = {}, {}
    if not (GetNumClasses and GetClassInfo and GetNumSpecializationsForClassID
            and GetSpecializationInfoForClassID) then return end
    for classID = 1, GetNumClasses() do
        local _, classFile = GetClassInfo(classID)
        local keys = classFile and SPEC_KEYS[classFile]
        for i = 1, GetNumSpecializationsForClassID(classID) or 0 do
            local specID, name, _, icon = GetSpecializationInfoForClassID(classID, i)
            if icon then
                local info = {
                    specID = specID, name = name, classFile = classFile, icon = icon,
                    tex = keys and keys[i] and (SPEC_TEX_DIR .. classFile:lower() .. "-" .. keys[i] .. ".png"),
                }
                specByIcon[icon] = info
                if specID then specByID[specID] = info end
            end
        end
    end
end

-- 回傳 { specID, name, classFile, tex } 或 nil。秘密的 fileID 不能拿來查表（會硬錯）。
function D.SpecInfo(specIconID)
    if specIconID == nil or issecret(specIconID) or type(specIconID) ~= "number" or specIconID == 0 then
        return nil
    end
    if not specByIcon then BuildSpecMap() end
    return specByIcon[specIconID]
end

function D.SpecInfoByID(specID)
    if specID == nil or issecret(specID) or type(specID) ~= "number" then return nil end
    if not specByIcon then BuildSpecMap() end
    return specByID[specID]
end

-- 這個 source 是哪個專精。
-- ⚠ C_DamageMeter **常常不給別人的 specIconID**（實測 2026-10-14：同隊、距離遠的兩位隊友
--   都是 nil，只有自己有）。退路是觀察快取（ItemLevel.lua 觀察時順便記的專精，
--   脫戰自動排隊問隊友）。戰鬥中 GUID 是秘密值查不了快取，那時只剩 specIconID。
function D.SourceSpec(src)
    local info = D.SpecInfo(src.specIconID)
    if info then return info end
    local IL = ns.ItemLevel
    return IL and D.SpecInfoByID(IL.Spec(src.sourceGUID or src.guid))
end

-- 觀察問到新專精時 +1。長條的圖示備忘連它一起比，不然 specIconID 一直是 nil、
-- 職業也沒變，那一列永遠不會重畫。
D.specGen = 0

-- 除錯報告用：整張對照表一行一個專精，照職業與暴雪順序排（驗 SPEC_KEYS 有沒有錯位）
function D.SpecMapLines()
    if not specByIcon then BuildSpecMap() end
    local rows = {}
    for icon, info in pairs(specByIcon) do
        rows[#rows + 1] = ("%s %s(%s) icon=%s -> %s"):format(tostring(info.classFile),
            tostring(info.name), tostring(info.specID), tostring(icon),
            info.tex and info.tex:match("([^\\]+)%.png$") or "NO TEXTURE")
    end
    table.sort(rows)
    return rows
end

------------------------------------------------------------
-- 圖示
--
-- 四種樣式：
--   mili  自己畫的專精圖（Media/Spec）＋程式畫的深底 → 專精不知道就用自己的職業圖（Media/Class）
--   spec  專精圖示（source.specIconID，是個 fileID）→ 沒有就退職業 sprite
--   class 職業 sprite（CLASS_ICON_TCOORDS）
--   none  不畫
-- 回傳圖示佔用的寬度（0 = 沒畫），呼叫端用它決定填充條從哪裡開始。
------------------------------------------------------------
local CLASS_SPRITE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- 米利圖是去背的，需要一塊深底才不會直接疊在長條材質上。
-- 懶建在圖示的同一個父層、低一個 sublevel：不必改任何一處建列的程式。
local ICON_BG = { 0.055, 0.055, 0.055, 0.92 }
local function IconBg(tex, show)
    local bg = tex._miliBg
    if not show then
        if bg then bg:Hide() end
        return
    end
    if not bg then
        local layer, sub = tex:GetDrawLayer()
        bg = tex:GetParent():CreateTexture(nil, layer, nil, math.max(-8, (sub or 0) - 1))
        bg:SetColorTexture(ICON_BG[1], ICON_BG[2], ICON_BG[3], ICON_BG[4])
        bg:SetAllPoints(tex)
        tex._miliBg = bg
    end
    bg:Show()
end

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
    if style == "none" then tex:Hide(); IconBg(tex, false); return 0 end
    zoom = zoom or 0.06

    local classFile = D.SafeClass(src.classFilename)
    -- 拿不到職業（秘密值、NPC、寵物）就不畫圖示：畫一個猜出來的職業圖比空白更糟
    if not classFile then tex:Hide(); IconBg(tex, false); return 0 end

    local info = (style == "mili" or style == "spec") and D.SourceSpec(src)
    if style == "mili" then
        -- 自己的圖本身就留了邊，不做 zoom 裁切。
        -- 專精還不知道（別人的 specIconID 常常是 nil、觀察還沒問到）→ 米利職業圖，不猜專精
        local path = (info and info.tex)
            or (SPEC_KEYS[classFile] and (CLASS_TEX_DIR .. classFile:lower() .. ".png"))
        if path then
            tex:SetTexture(path)
            tex:SetTexCoord(0, 1, 0, 1)
            IconBg(tex, true)
        else
            IconBg(tex, false)
            ApplyClassSprite(tex, classFile, zoom)
        end
    elseif style == "spec" then
        IconBg(tex, false)
        -- specIconID 沒給時，觀察快取問到的專精也能換回暴雪的專精圖示
        local specIcon = info and info.icon
        -- 對照表沒收到的圖示 ID（理論上不會有）照舊直接畫，不要退成職業圖
        if not specIcon then
            local raw = src.specIconID
            if raw and not issecret(raw) and type(raw) == "number" and raw ~= 0 then specIcon = raw end
        end
        if specIcon then
            tex:SetTexture(specIcon)
            tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        else
            ApplyClassSprite(tex, classFile, zoom)
        end
    else
        IconBg(tex, false)
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
--   我們自己的 MiliUI_QoL/Modules/Delves_MarkButton.lua 也是（實機驗證過，
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

-- 邊框／分隔線／細線的粗細：設定值＝剛好 n 個實體像素（走 P.Pixel）。
-- ⚠ 不能走 D.Px：P.Scale 是「n 個 UI 單位貼整數像素」，1440p 以上 1 會變 2px。
-- 列高、間距這類尺寸照舊 D.Px。規則見 .claude/notes/wow-1px-border-rules.md
function D.Hair(userValue)
    if not userValue or userValue == 0 then return 0 end
    if ns.P and ns.P.Pixel then return ns.P.Pixel(userValue) end
    return userValue
end

------------------------------------------------------------
-- 排名字串：40 個字串開檔就備好，省掉每次刷新的 i .. "."
------------------------------------------------------------
D.RANK = {}
for i = 1, 40 do D.RANK[i] = i .. "." end
