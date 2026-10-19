------------------------------------------------------------
-- 副本難度：用一小塊文字取代暴雪的難度旗標
--
-- 「英雄 5人」「傳奇 20人」「M+12」「探究 8」「隨機 25人」……
--
-- 版面：左下角，**直接坐在下資訊帶上面**（跟上下兩條同一個底色與字級，
--   看起來像下資訊帶長出來的一個頁籤）。四個角落的分工：
--     左上 追蹤、右上 郵件／製作訂單、右下 日曆、左下 原本就是暴雪的難度旗
--   所以文字放在旗子原本的位置，玩家不用重新找。
--   ⚠ 高度保留的是**下資訊帶的高度**，不看它現在顯示與否：座標設成「滑鼠移過時」
--   的話下資訊帶會隨滑鼠出現／消失，跟著它跳的話滑鼠一移進地圖這塊就往上竄一格。
--
-- 暴雪旗子的處理在 Map/Skin.lua 的 LayoutBlizzardButtons：開這個功能時旗子
-- **reparent 到隱藏框**（不 Hide —— 暴雪自己會依副本 Show/Hide 它，比誰後叫到
-- 是打不完的仗；也不寫它任何欄位），關掉時照原本的做法錨回左下角。
--
-- 顏色：一律白字（S.TEXT），不按難度上色 —— 理由見 Paint() 上面的註解。
--
-- 秘密值：這裡讀的全是副本／鑰石資訊，目前都是明文；但 12.1 的清單改過好幾輪，
--   所有值一律先過 ns.Secret 再比較、查表、做字串運算。拿不到就退成「沒有文字」
--   或「只有難度名、不帶數字」，不猜。
------------------------------------------------------------
local _, ns = ...

ns.Difficulty = {}
local D = ns.Difficulty
local S = ns.Style
local P = ns.P
local L = ns.L
local Secret = ns.Secret

-- 跟 Map/Skin.lua 的 BAR_PAD 同一個數：下資訊帶高度＝字級 + 5
local BAR_PAD = 5
-- 文字左右各留 4px，跟資訊帶裡的區域名／座標同一個內距
local TEXT_PAD = 4

local chip, chipText
local lastText

------------------------------------------------------------
-- 對照表
--
-- difficultyID 的完整清單：wago.tools 的 Difficulty 表。
-- 這裡只列「要自己縮短」的；沒列到的退回 GetDifficultyInfo 給的暴雪在地化名稱
-- （活動事件、托迦司這類一季一次的東西，名字本來就沒有更短的說法）。
--
--   label  難度詞（普通／英雄／傳奇／隨機…），已經過 L
--   size   固定人數；"flex" ＝ 彈性團隊，人數讀 GetInstanceInfo 的 instanceGroupSize
--   kind   特殊格式：keystone（M+N）／delve（探究 N）／plain（只有詞，不帶人數）
------------------------------------------------------------
-- 語系檔在 TOC 裡排在前面，檔案層就能取 L —— key 寫成字面值，語系檢查才掃得到
local NORMAL, HEROIC, MYTHIC = L["Normal"], L["Heroic"], L["Mythic"]
local LFR, TW, SCEN, HSCEN = L["Raid Finder"], L["Timewalking"], L["Scenario"], L["Heroic scenario"]

local MAP = {
    [1]   = { label = NORMAL, size = 5 },
    [2]   = { label = HEROIC, size = 5 },
    [3]   = { label = NORMAL, size = 10 },
    [4]   = { label = NORMAL, size = 25 },
    [5]   = { label = HEROIC, size = 10 },
    [6]   = { label = HEROIC, size = 25 },
    [7]   = { label = LFR, size = 25 },
    [8]   = { kind = "keystone" },
    [9]   = { label = NORMAL, size = 40 },
    [11]  = { label = HSCEN, kind = "plain" },
    [12]  = { label = SCEN, kind = "plain" },
    [14]  = { label = NORMAL, size = "flex" },
    [15]  = { label = HEROIC, size = "flex" },
    [16]  = { label = MYTHIC, size = 20 },
    [17]  = { label = LFR, size = "flex" },
    [23]  = { label = MYTHIC, size = 5 },
    [24]  = { label = TW, size = 5 },
    [33]  = { label = TW, size = "flex" },
    [38]  = { label = SCEN, kind = "plain" },
    [39]  = { label = HSCEN, kind = "plain" },
    [40]  = { label = L["Mythic scenario"], kind = "plain" },
    [151] = { label = LFR, size = "flex" },
    [205] = { label = L["Follower"], kind = "plain" },
    [208] = { kind = "delve" },
    [220] = { label = L["Story"], kind = "plain" },
}

------------------------------------------------------------
-- 資料
------------------------------------------------------------
-- 探究這一場的難度層級（1～11）。在場景標頭 widget 的 tierText 裡，是在地化字串，
-- 抓第一串數字。⚠ 不是「探究等級」（賽季聲望軌道），兩者是不同的東西
-- （.claude/notes/wow-delve-detection.md）。剛進場 widget 還沒建好時回 nil。
local function DelveTier()
    if not (C_Scenario and C_Scenario.GetStepInfo and C_UIWidgetManager) then return end
    local setID = Secret.PlainNumber(Secret.SafeCall(function()
        return (select(12, C_Scenario.GetStepInfo()))
    end))
    if not setID or setID == 0 then return end
    local widgets = Secret.SafeCall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
    if type(widgets) ~= "table" then return end
    local typeID = (Enum.UIWidgetVisualizationType
                    and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves) or 29
    for _, w in ipairs(widgets) do
        local wType = Secret.PlainNumber(w.widgetType)
        local wID = Secret.PlainNumber(w.widgetID)
        if wType == typeID and wID then
            local info = Secret.SafeCall(
                C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo, wID)
            local tierText = info and Secret.PlainText(info.tierText)
            local n = tierText and tierText:match("%d+")
            return n and tonumber(n)
        end
    end
end

local function KeystoneLevel()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then return end
    local level = Secret.PlainNumber(Secret.SafeCall(C_ChallengeMode.GetActiveKeystoneInfo))
    if level and level > 0 then return level end
end

-- 回傳要顯示的字串；nil ＝ 不顯示（野外、主城、住宅……）
local function BuildText()
    local _, instanceType, difficultyID, difficultyName, maxPlayers, _, _, _, groupSize =
        GetInstanceInfo()
    instanceType = Secret.PlainText(instanceType)
    difficultyID = Secret.PlainNumber(difficultyID)

    if instanceType == "pvp" then return L["Battleground"] end
    if instanceType == "arena" then return L["Arena"] end
    if not instanceType or instanceType == "none" then return end
    if not difficultyID or difficultyID == 0 then return end

    local spec = MAP[difficultyID]
    if not spec then
        -- 沒列到的：暴雪自己的在地化名稱。那也讀不到就乾脆不顯示，不要印數字代碼。
        local name = Secret.PlainText(difficultyName)
        if not name or name == "" then
            name = Secret.PlainText(Secret.SafeCall(GetDifficultyInfo, difficultyID))
        end
        if name and name ~= "" then return name end
        return
    end

    if spec.kind == "keystone" then
        local level = KeystoneLevel()
        return level and L["M+%d"]:format(level) or L["M+"]
    end
    if spec.kind == "delve" then
        local tier = DelveTier()
        return tier and L["Delve %d"]:format(tier) or L["Delve"]
    end
    if spec.kind == "plain" then return spec.label end

    local size = spec.size
    if size == "flex" then
        -- 彈性團隊：instanceGroupSize 是「現在這一場算幾人」，比 maxPlayers（30）有意義
        size = Secret.PlainNumber(groupSize)
        if not size or size <= 0 then size = Secret.PlainNumber(maxPlayers) end
    end
    if size and size > 0 then
        return L["%s %d-man"]:format(spec.label, size)
    end
    return spec.label
end

------------------------------------------------------------
-- 畫
------------------------------------------------------------
local function Build()
    if chip or not ns.overlay or not ns.holder then return end
    chip = CreateFrame("Frame", nil, ns.overlay)
    chip:EnableMouse(false)
    chip:SetFrameLevel(ns.overlay:GetFrameLevel() + 3)
    chip.bg = S.NoSnap(chip:CreateTexture(nil, "BACKGROUND"))   -- 貼著外框內側
    chip.bg:SetAllPoints(chip)
    chipText = chip:CreateFontString(nil, "OVERLAY")
    -- 一建出來就給字型（理由見 Map/Skin.lua 的 MakeText）
    S.SetFont(chipText, 12)
    chipText:SetPoint("LEFT", chip, "LEFT", TEXT_PAD, 0)
    chipText:SetJustifyH("LEFT")
    chipText:SetWordWrap(false)
    chip:Hide()
end

local function Resize()
    if not chip or not chipText:IsShown() then return end
    local w = chipText:GetStringWidth() or 0
    chip:SetWidth(math.ceil(w) + TEXT_PAD * 2)
end

function D.Update()
    ns.Count("Difficulty.Update")
    if not chip then return end
    local db = ns.DB.Get()
    local text = db.difficultyText and BuildText() or nil
    if text == lastText then return end
    lastText = text
    if text then
        chipText:SetText(text)
        chip:Show()
        Resize()
    else
        chip:Hide()
    end
end

------------------------------------------------------------
-- ⚠ 顏色選擇：**白字，不按難度上色。**
--   這塊跟區域名、座標、時鐘並排在同一張地圖上，那三個都是白字；難度要是
--   一個綠一個藍一個紫，地圖上就會出現一塊唯一有顏色的東西，視線會先被它抓走，
--   而它其實是進場看一眼就不再變的資訊。暴雪的旗子本身也沒有「難度色」可以沿用
--   （它是靠圖案分辨，不是靠顏色）；常被拿來當難度色的綠藍紫橙是**物品品質色**，
--   挪過來用等於讓玩家以為那是在講裝備。字已經寫著「英雄」「傳奇」「M+12」了，
--   顏色不必再說一次。
------------------------------------------------------------
local function Paint()
    if not chip then return end
    local db = ns.DB.Get()
    local barH = db.fontSize + BAR_PAD

    chip:ClearAllPoints()
    -- 外框 1px 內側、緊貼下資訊帶的上緣
    -- 內縮跟外框同一個值：holder 有自己的縮放，換算基準用框自己的（S.Pixel）
    local px = S.Pixel(chip, 1)
    chip:SetPoint("BOTTOMLEFT", ns.holder, "BOTTOMLEFT", px, px + barH)
    chip:SetHeight(barH)

    -- 底色跟上下兩條完全一樣（整體底色 alpha +0.1，理由見 Skin.Apply）
    local br, bg, bb, ba = S.BackdropColor()
    chip.bg:SetColorTexture(br, bg, bb, math.min(1, ba + 0.1))

    S.SetFont(chipText, db.fontSize)
    chipText:SetTextColor(unpack(S.TEXT))

    -- 字型或字級換了 ⇒ 寬度要重量；文字本身沒變，所以強制重畫一次
    lastText = nil
    D.Update()
end

------------------------------------------------------------
-- 事件
--
-- GROUP_ROSTER_UPDATE 在團隊裡會連發（進出、換組、上下線都算），而它只影響
-- 彈性團隊的人數 ⇒ 合流成一次。其餘事件都是進場／換難度這種低頻的，直接更新。
-- 探究剛進場時場景標頭 widget 還沒建好，讀不到層級 ⇒ SCENARIO_UPDATE 會補上，
-- 另外排兩次延遲重試當保底（有防重入旗標，不會疊）。
------------------------------------------------------------
local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    "GROUP_ROSTER_UPDATE", "INSTANCE_GROUP_SIZE_CHANGED", "SCENARIO_UPDATE",
}

local rosterQueued, retrying = false, false

local function ScheduleRetries()
    if retrying then return end
    retrying = true
    C_Timer.After(2, function() ns.Safe(D.Update) end)
    C_Timer.After(5, function() retrying = false; ns.Safe(D.Update) end)
end

local ev
local function RegisterEvents(on)
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", function(_, event)
            if event == "GROUP_ROSTER_UPDATE" then
                if rosterQueued then return end
                rosterQueued = true
                C_Timer.After(0.5, function()
                    rosterQueued = false
                    ns.Safe(D.Update)
                end)
                return
            end
            ns.Safe(D.Update)
            if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
                ScheduleRetries()
            end
        end)
    end
    for _, e in ipairs(EVENTS) do
        if on then
            -- 舊客戶端沒有的事件註冊會拋錯，逐一隔離
            pcall(ev.RegisterEvent, ev, e)
        else
            ev:UnregisterEvent(e)
        end
    end
end

-- Skin.Apply 跑完才有 overlay／holder，也是字型、底色、字級變動之後的唯一出口
ns.RegisterCallback("SkinApplied", "Difficulty", function()
    Build()
    if not chip then return end
    local on = ns.DB.Get().difficultyText and true or false
    RegisterEvents(on)
    if not on then
        lastText = nil
        chip:Hide()
        return
    end
    Paint()
end)
