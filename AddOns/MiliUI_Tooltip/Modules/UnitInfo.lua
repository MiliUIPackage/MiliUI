------------------------------------------------------------
-- 單位資料層：GetUnitInfo（讀 API → raw 表）、GetUnitData（raw + elements 設定 →
-- 每列文字）、觀察裝等 / 成就點數的非同步快取。純資料，不碰任何 tooltip。
--
-- 秘密值策略：所有 Unit API 一律 SafeCall；字串組合只用串接與 format（合法）；
-- 需要比較 / 查表 / 字串運算的地方先 SafeValue / PlainText 洗成明文，洗不出來就跳過。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local L = ns.L
local Colors = ns.Colors

ns.UnitInfo = {}
local UnitInfo = ns.UnitInfo

local AFK, DND, PLAYER, BOSS, ELITE = AFK, DND, PLAYER, BOSS, ELITE
local MALE, FEMALE = MALE, FEMALE
local RARE = GARRISON_MISSION_RARE
local OFFLINE = FRIENDS_LIST_OFFLINE
local BASE_MOVEMENT_SPEED = BASE_MOVEMENT_SPEED or 7

local MEDIA = "Interface\\AddOns\\MiliUI_Tooltip\\Media\\"

------------------------------------------------------------
-- 圖標集
------------------------------------------------------------

-- 陣營圖示用扁平 atlas（任務日誌的陣營任務標）：TinyTooltip 內建的
-- UI-PVP-ALLIANCE/HORDE 是舊版帶金屬圓框的立體徽章，縮到 14px 只剩一坨。
-- 原本掛在 MiliUI/Enhance/TinyTooltipRemake_FactionIcon.lua，這裡改成內建。
-- atlas 被暴雪拿掉時退回舊貼圖，不要塞出一個綠框。
--
-- 要換款式就把下面 icons 表裡的 atlas 名（與寬高）換成這幾組：
--   社群面板款（純色符號、完全沒描邊，最扁平，但顏色偏暗）：
--     communities-icon-faction-alliance 12×14 ／ communities-icon-faction-horde 12×14
--   世界任務地圖款（小尺寸下最清楚、顏色最飽和）：
--     worldquest-icon-alliance 14×13 ／ worldquest-icon-horde 14×13
--   登入畫面剪影款（單色灰白、無陣營色；兩邊原生比例不同）：
--     CharacterSelection_Alliance_Icon 11×14 ／ CharacterSelection_Horde_Icon 8×14
local function FactionIcon(atlas, w, h, fallback)
    if type(CreateAtlasMarkup) == "function"
        and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        return CreateAtlasMarkup(atlas, w, h)
    end
    return fallback
end

local icons = {
    Alliance   = FactionIcon("questlog-questtypeicon-alliance", 14, 14,
        "|TInterface\\TargetingFrame\\UI-PVP-ALLIANCE:14:14:0:0:64:64:10:36:2:38|t"),
    Horde      = FactionIcon("questlog-questtypeicon-horde", 14, 14,
        "|TInterface\\TargetingFrame\\UI-PVP-HORDE:14:14:0:0:64:64:4:38:2:36|t"),
    Neutral    = "|TInterface\\Timer\\Panda-Logo:14|t",
    pvp        = "|TInterface\\TargetingFrame\\UI-PVP-FFA:14:14:0:0:64:64:10:36:0:38|t",
    class      = "|TInterface\\TargetingFrame\\UI-Classes-Circles:14:14:0:0:256:256:%d:%d:%d:%d|t",
    questboss  = "|TInterface\\TargetingFrame\\PortraitQuestBadge:0|t",
    friend     = ("|T%sfriend.blp:14:14:0:0:32:32:1:30:2:30|t"):format(MEDIA),
    bnetfriend = "|TInterface\\ChatFrame\\UI-ChatIcon-BattleNet:14:14:0:0:32:32:1:30:2:30|t",
    TANK       = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:0:19:22:41|t",
    HEALER     = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:1:20|t",
    DAMAGER    = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:14:14:0:0:64:64:20:39:22:41|t",
}
UnitInfo.icons = icons

local mountIconTag = ("|T%smount.tga:14:14:0:0|t"):format(MEDIA)
local mplusIconTag = ("|T%smplus.tga:14:14:0:0|t"):format(MEDIA)
local itemLevelIconTag = ("|T%sitem_level.blp:14:14:0:0|t"):format(MEDIA)
local achievementIconTag = (type(CreateAtlasMarkup) == "function" and CreateAtlasMarkup("storyheader-cheevoicon", 14, 14)) or "|A:storyheader-cheevoicon:14:14|a"

------------------------------------------------------------
-- 單項讀取
------------------------------------------------------------
local function GetRaidIcon(unit)
    local index = S.PlainNumber(S.SafeCall(GetRaidTargetIndex, unit))
    local icon = index and ICON_LIST and ICON_LIST[index]
    if icon then return icon .. "0|t" end
end

local function GetPVPIcon(unit)
    if S.SafeBool(UnitIsPVPFreeForAll, unit) then return icons.pvp end
end

local function GetRoleIcon(unit)
    local role = S.SafeValue(S.SafeCall(UnitGroupRolesAssigned, unit))
    if type(role) == "string" then return icons[strupper(role)] end
end
UnitInfo.GetRoleIcon = GetRoleIcon

local function GetClassIcon(class)
    class = S.PlainText(class)
    if not class then return end
    local coords = CLASS_ICON_TCOORDS[strupper(class)]
    if not coords then return end
    local x1, x2, y1, y2 = unpack(coords)
    return format(icons.class, x1 * 256, x2 * 256, y1 * 256, y2 * 256)
end

local function GetQuestBossIcon(unit)
    if UnitIsQuestBoss and S.SafeBool(UnitIsQuestBoss, unit) then return icons.questboss end
end

local function GetFriendIcon(unit)
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    local guid = S.SafeValue(S.SafeCall(UnitGUID, unit))
    if not guid then return end
    if C_FriendList and S.SafeBool(C_FriendList.IsFriend, guid) then
        return icons.friend
    end
    if guid ~= UnitGUID("player") and C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
        local info = S.SafeCall(C_BattleNet.GetAccountInfoByGUID, guid)
        if type(info) == "table" and info.isFriend then
            return icons.bnetfriend
        end
    end
end

local GetUnitSpeedAPI = GetUnitSpeed
local function GetMoveSpeed(unit)
    local _, speed, flightSpeed, swimSpeed = S.SafeCall(GetUnitSpeedAPI, unit)
    if S.SafeBool(UnitIsOtherPlayersPet, unit) then
        -- 保持原速
    elseif S.SafeBool(IsSwimming, unit) then
        speed = swimSpeed
    elseif IsFlying and S.SafeBool(IsFlying, unit) then
        speed = flightSpeed
    end
    speed = S.PlainNumber(speed)
    if not speed or speed == 0 then return end
    return speed / BASE_MOVEMENT_SPEED * 100 + 0.5
end

-- 頭銜：pvpName 去掉 name 的剩餘部分（字串運算 → 兩者都要明文）
local function GetTitle(name, pvpName)
    name, pvpName = S.PlainText(name), S.PlainText(pvpName)
    if not name or not pvpName or name == pvpName then return end
    local pos = string.find(pvpName, name, 1, true)
    local title = pvpName:gsub(name, "", 1)
    title = title:gsub(",", ""):gsub("，", "")
    title = strtrim(title)
    if title == "" then return end
    return title, pos ~= 1
end

local function GetGender(gender)
    gender = S.PlainNumber(gender)
    if gender == 2 then
        return MALE
    elseif gender == 3 then
        return FEMALE
    end
end

-- 隊友所在的地區（GetRaidRosterInfo 的第 7 個回傳）。raidN 直接用編號查；partyN 的名冊順序跟 N 對不上，
-- target／focus 這些指著隊友的 token 也一樣 ⇒ 照名字（跨服的帶伺服器）在名冊裡找。
-- 單位面板也拿它認暴雪給視野外隊友加的那一行地區（ReadUnit.lua 的 zoneLine）
local function GetZone(unit, unitname, realm)
    if not IsInGroup() then return end
    unit = S.PlainText(unit)
    unitname = S.PlainText(unitname)
    if not unit or not unitname then return end
    local t, i = string.match(unit, "^(%a+)(%d+)$")
    if t == "raid" then
        return select(7, GetRaidRosterInfo(tonumber(i)))
    end
    if t ~= "party" and not (S.SafeBool(UnitInParty, unit) or S.PlainNumber((S.SafeCall(UnitInRaid, unit)))) then
        return
    end
    local fullname = unitname .. "-" .. tostring(S.PlainText(realm) or "")
    for j = 1, GetNumGroupMembers() do
        local name, _, _, _, _, _, zone = GetRaidRosterInfo(j)
        name = S.PlainText(name)
        if name and not string.find(name, "-", 1, true) and name == unitname then
            return zone
        elseif name and string.find(name, "-", 1, true) and name == fullname then
            return zone
        end
    end
end

local function GetMythicPlusScore(unit)
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then return end
    local summary = S.SafeCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
    if type(summary) ~= "table" then return end
    local score = S.PlainNumber(summary.currentSeasonScore)
    if not score then return end
    local color = summary.currentSeasonScoreColor or summary.color
    if not color and C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor then
        color = S.SafeCall(C_ChallengeMode.GetDungeonScoreRarityColor, score)
    end
    local bestLevel
    if type(summary.runs) == "table" then
        for _, run in ipairs(summary.runs) do
            local lv = run and S.PlainNumber(run.bestRunLevel)
            if lv and (not bestLevel or lv > bestLevel) then bestLevel = lv end
        end
    end
    return score, color, bestLevel
end

------------------------------------------------------------
-- 坐騎（光環掃描：12.1 光環變秘密後 index 讀取會硬炸，先問 ShouldAurasBeSecret）
------------------------------------------------------------
local function AurasAreSecret()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, res = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and res then return true end
    end
    return false
end
UnitInfo.AurasAreSecret = AurasAreSecret

local function FindMountAura(unit)
    if not (C_MountJournal and C_MountJournal.GetMountFromSpell) then return end
    if AuraUtil and AuraUtil.ForEachAura then
        local auraName, mountID
        local ok = pcall(AuraUtil.ForEachAura, unit, "HELPFUL", nil, function(aura)
            if type(aura) ~= "table" or not aura.spellId then return end
            local mount = C_MountJournal.GetMountFromSpell(aura.spellId)
            if mount then
                auraName, mountID = aura.name, mount
                return true
            end
        end)
        if not ok then auraName, mountID = nil, nil end
        if auraName then return auraName, mountID end
    end
    if AurasAreSecret() then return end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not aura then break end
            local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if mountID then return aura.name, mountID end
        end
    end
end

local function GetMountInfo(unit)
    if not (C_MountJournal and C_MountJournal.GetMountInfoByID) then return end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    local auraName, mountID = FindMountAura(unit)
    if not auraName then return end
    local name, isCollected
    if mountID then
        local ok, mountName, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if ok then name, isCollected = mountName, collected end
    end
    return name or auraName, isCollected
end

------------------------------------------------------------
-- 觀察裝等 / 成就點數：非同步快取（TTL 900s、節流 1.2s）
------------------------------------------------------------
-- INSPECT_PENDING_TIMEOUT 跟 INSPECT_INTERVAL 一樣：沒回音就再問，但再問本來就得等節流過，
-- 設得比節流短只是多重畫一次，所以比節流多一點點。實測來回 0.1～0.2 秒，團隊裡被別家插件搶時 1.4 秒。
local INSPECT_TTL, INSPECT_INTERVAL, INSPECT_PENDING_TIMEOUT = 900, 1.2, 1.3   -- 逾時比節流多 0.1 秒緩衝，重畫時節流一定已經過了
local inspect = { cache = {}, pendingGUID = nil, pendingUnit = nil, lastRequestAt = 0, suspendedUntil = 0 }
local achieve = { cache = {}, pendingGUID = nil, lastRequestAt = 0, suspendedUntil = 0 }
UnitInfo.inspectState = inspect
UnitInfo.achieveState = achieve

local function SafeGuid(unit)
    if not S.SafeBool(UnitExists, unit) then return end
    return S.SafeCall(UnitGUID, unit)
end

-- 12.1：受限單位的 GUID 可能是秘密 → 不能當 table key、不能直接 ==
-- 先問再比：讓 == 在 pcall 裡拋錯也照樣算一次封鎖、進 taint.log。看不出來就當作不同。
local function GuidEquals(a, b)
    if a == nil or b == nil then return false end
    if S.IsSecret(a) or S.IsSecret(b) then return false end
    return a == b
end
UnitInfo.GuidEquals = GuidEquals

local function CacheGet(state, unit, field)
    local guid = S.SafeValue(SafeGuid(unit))   -- 秘密 GUID 不查表
    if not guid then return end
    local cached = state.cache[guid]
    if not cached then return end
    if (GetTime() - cached.time) > INSPECT_TTL then
        state.cache[guid] = nil
        return
    end
    return cached[field]
end

local function CachePut(state, guid, field, value)
    guid = S.SafeValue(guid)
    if not guid or type(value) ~= "number" then return end
    state.cache[guid] = { [field] = value, time = GetTime() }
end

-- 裝等照玩家分頁設的小數位數（0～2）截斷，不四捨五入：整數位要跟暴雪角色面板與集合石
-- 一致，不然 329.8 四捨五入成 330，玩家照提示去找「330」的隊伍會找不到。
local function TruncItemLevel(v)
    local el = ns.db and ns.db.unit and ns.db.unit.player.elements.itemLevel
    local m = 10 ^ (el and el.decimals or 2)
    return floor(v * m) / m
end

-- 其他玩家的裝等：C_PaperDollInfo.GetInspectItemLevel 回的是暴雪已經四捨五入過的整數
-- （329.6 → 330），上面的截斷對它沒有作用。所以觀察資料到貨時照暴雪角色面板的算法
-- 自己平均：16 格（1～17 扣掉 4 襯衣；19 徽章不算），空格算 0，只拿一把雙手武器
-- （或遠程）時那把算兩格，雙持（含泰坦之握的兩把雙手）各算各的。
-- 哪一格的物品資料還沒同步到（有 ID 沒 link、或 GetDetailedItemLevelInfo 回 nil）、
-- 或 12.1 把 link 變成秘密，就整個放棄，退回暴雪那個整數——寧可少一位小數也不要算錯。
local ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }

-- 回 (裝等, 部位)；nil ＝ 這格算不出來
local function SlotItemLevel(unit, slot)
    local link = S.SafeCall(GetInventoryItemLink, unit, slot)
    if S.IsSecret(link) then return end
    if not link or link == "" then
        local id = S.SafeCall(GetInventoryItemID, unit, slot)
        if S.IsSecret(id) or id then return end   -- 有物品但 link 還沒到
        return 0                                   -- 真的空格
    end
    -- GetItemInfo 對沒快取的物品回 nil、同時向伺服器要資料 ⇒ 回 nil 讓上層稍後重試
    local name, _, _, _, _, _, _, _, equipLoc = S.SafeCall(C_Item.GetItemInfo, link)
    if not S.PlainText(name) then return end
    local lv = S.PlainNumber(S.SafeCall(C_Item.GetDetailedItemLevelInfo, link))
    if not lv or lv <= 0 then return end
    return lv, S.PlainText(equipLoc)
end

local function PreciseInspectItemLevel(unit)
    if not (GetInventoryItemLink and GetInventoryItemID and C_Item
        and C_Item.GetDetailedItemLevelInfo and C_Item.GetItemInfo) then return end
    local total = 0
    for _, slot in ipairs(ILVL_SLOTS) do
        local lv = SlotItemLevel(unit, slot)
        if not lv then return nil, slot end
        total = total + lv
    end
    local mh, mhLoc = SlotItemLevel(unit, 16)
    local oh, ohLoc = SlotItemLevel(unit, 17)
    if not mh then return nil, 16 end
    if not oh then return nil, 17 end
    if mh > 0 and oh > 0 then
        total = total + mh + oh
    elseif TWO_HAND[mhLoc] or TWO_HAND[ohLoc] then
        total = total + max(mh, oh) * 2
    else
        total = total + mh + oh
    end
    return total / 16
end

-- 客戶端現在有沒有這個單位的觀察資料：任何一格裝備連結讀得到就算有（只對當前被觀察者回得出來）
local function InspectDataPresent(unit)
    if not GetInventoryItemLink then return false end
    for slot = 1, 17 do
        local link = S.SafeCall(GetInventoryItemLink, unit, slot)
        if S.IsSecret(link) or (link and link ~= "") then return true end
    end
    local lv = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
        and S.PlainNumber(S.SafeCall(C_PaperDollInfo.GetInspectItemLevel, unit))
    return (lv and lv > 0) or false
end

local function GetUnitItemLevel(unit)
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if S.SafeBool(UnitIsUnit, unit, "player") and GetAverageItemLevel then
        local average, equipped = S.SafeCall(GetAverageItemLevel)
        equipped, average = S.PlainNumber(equipped), S.PlainNumber(average)
        if equipped and equipped > 0 then return equipped end
        if average and average > 0 then return average end
    end
    local cached = CacheGet(inspect, unit, "level")
    if cached then return cached end
    -- 別家插件剛好觀察過這個人、物品也都快取了：直接算，不用自己發問。
    -- 只收小數：暴雪的整數不收，收了會在快取待 15 分鐘、也擋掉我們自己發問
    local precise = PreciseInspectItemLevel(unit)
    if precise and precise > 0 then
        CachePut(inspect, SafeGuid(unit), "level", precise)
        return precise
    end
end

local function GetUnitAchievementPoints(unit)
    if S.SafeBool(UnitIsUnit, unit, "player") then
        local points = S.PlainNumber(S.SafeCall(GetTotalAchievementPoints))
        if points and points >= 0 then return points end
        return
    end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    return CacheGet(achieve, unit, "points")
end

function UnitInfo.RequestInspect(unit)
    if not (NotifyInspect and CanInspect) then return end
    if not S.SafeBool(UnitExists, unit) then return end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if S.SafeBool(UnitIsUnit, unit, "player") then return end
    if not S.SafeBool(CanInspect, unit) then return end
    local guid = S.SafeValue(SafeGuid(unit))
    if not guid then return end
    local now = GetTime()
    if (inspect.suspendedUntil or 0) > now then return end
    if InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown() then return end
    local cached = inspect.cache[guid]
    if cached and (now - cached.time) <= INSPECT_TTL then return end
    -- 同一個人還在等：INSPECT_READY 可能永遠不來（別家插件同幀也發、伺服器只回最後一個），
    -- 等超過 INSPECT_PENDING_TIMEOUT 就准再問一次，不然這個人會卡在「??」到登出
    if inspect.pendingGUID == guid and (now - (inspect.lastRequestAt or 0)) < INSPECT_PENDING_TIMEOUT then return end
    if (now - (inspect.lastRequestAt or 0)) < INSPECT_INTERVAL then
        if ns.logEnabled then ns.Log("觀察 %s 被節流（距上次 %.2fs）", tostring(unit), now - inspect.lastRequestAt) end
        return
    end
    if pcall(NotifyInspect, unit) then
        inspect.pendingGUID = guid
        inspect.pendingUnit = unit
        inspect.lastRequestAt = now
        if ns.logEnabled then ns.Log("觀察 送出 NotifyInspect(%s)", tostring(unit)) end
        -- 回音沒來（別家插件在掃團隊、伺服器只回最後一個）就自動再問：逾時後叫提示重畫一次，
        -- 提示還開在這個人身上的話，重讀時會發現裝等仍未知而再發一次；已經滑走就什麼都不做
        C_Timer.After(INSPECT_PENDING_TIMEOUT + 0.05, function()
            if inspect.pendingGUID ~= guid or inspect.lastRequestAt ~= now then return end
            if ns.logEnabled then ns.Log("觀察 %s 等 %.1fs 沒回音，重畫讓它再問", tostring(unit), INSPECT_PENDING_TIMEOUT) end
            if ns.RefreshUnitTip then ns.RefreshUnitTip(guid) end
        end)
    elseif ns.logEnabled then
        ns.Log("觀察 NotifyInspect(%s) 拋錯", tostring(unit))
    end
end

function UnitInfo.RequestAchievements(unit)
    if not S.SafeBool(UnitExists, unit) then return end
    if not S.SafeBool(UnitIsPlayer, unit) then return end
    if S.SafeBool(UnitIsUnit, unit, "player") then return end
    if not S.SafeBool(CanInspect, unit) then return end
    local guid = S.SafeValue(SafeGuid(unit))
    if not guid then return end
    local now = GetTime()
    if (achieve.suspendedUntil or 0) > now then return end
    local cached = achieve.cache[guid]
    if cached and (now - cached.time) <= INSPECT_TTL then return end
    if achieve.pendingGUID == guid then return end
    if (now - (achieve.lastRequestAt or 0)) < INSPECT_INTERVAL then return end
    -- 成就比較視窗開著就不要搶
    if AchievementFrame and AchievementFrame.isComparison then return end
    if AchievementFrameComparison and AchievementFrameComparison.UnregisterEvent then
        pcall(AchievementFrameComparison.UnregisterEvent, AchievementFrameComparison, "INSPECT_ACHIEVEMENT_READY")
    end
    if ClearAchievementComparisonUnit then pcall(ClearAchievementComparisonUnit) end
    local ok, result = pcall(SetAchievementComparisonUnit, unit)
    if ok and result ~= false then
        achieve.pendingGUID = guid
        achieve.lastRequestAt = now
    end
end

-- 這個 GUID 現在在哪個 token 上：先用發問時的 token（nameplate 會被回收、換人），再試 mouseover／target
local function ResolveUnit(guid, hint)
    if hint and GuidEquals(SafeGuid(hint), guid) then return hint end
    if GuidEquals(SafeGuid("mouseover"), guid) then return "mouseover" end
    if GuidEquals(SafeGuid("target"), guid) then return "target" end
end

-- 觀察收尾：清掉觀察資料（玩家自己開著觀察視窗就不清）、放開 pending、叫提示重畫
local function FinishInspect(guid)
    if ns.logEnabled then ns.Log("觀察 收尾（快取 level=%s）", tostring(S.SafeValue(guid) and inspect.cache[S.SafeValue(guid)] and inspect.cache[S.SafeValue(guid)].level)) end
    if ClearInspectPlayer and not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then
        pcall(ClearInspectPlayer)
    end
    inspect.pendingGUID, inspect.pendingUnit = nil, nil
    if ns.RefreshUnitTip then ns.RefreshUnitTip(guid) end
end

-- 小數真的算不出來（重試到期、或根本沒有哪一格卡住卻也算不出）才退回暴雪四捨五入過的整數
local function FallbackRoughItemLevel(unit, guid)
    local rough = C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel
        and S.PlainNumber(S.SafeCall(C_PaperDollInfo.GetInspectItemLevel, unit))
    if ns.logEnabled then ns.Log("觀察裝等 暴雪整數=%s", tostring(rough)) end
    if rough and rough > 0 then CachePut(inspect, guid, "level", rough) end
end

-- 到貨當下物品資料常常還沒全部快取（GetItemInfo 剛發問），每 0.25 秒再算一次、最多等 5 秒（中間畫面上有整數頂著，等久一點不痛）。
-- 期間觀察資料要留著（不能 ClearInspectPlayer，不然連結就沒了）。
-- 放棄的條件：unit token 已經指到別人、或又發了新的觀察（pendingGUID 換人）—— 那時資料已經是別人的，
-- 收尾交給新的那一輪，自己安靜退場，快取裡留的是前面存的整數。
local PRECISE_RETRY_EVERY, PRECISE_RETRY_FOR = 0.25, 5
local function RetryPreciseItemLevel(unit, guid, deadline)
    C_Timer.After(PRECISE_RETRY_EVERY, function()
        if not GuidEquals(inspect.pendingGUID, guid) then
            if ns.logEnabled then ns.Log("觀察裝等 重試中 pending 換人，退場") end
            return
        end
        local now = ResolveUnit(guid, unit)
        if not now then
            if ns.logEnabled then ns.Log("觀察裝等 重試中 %s 已指到別人、也不在 mouseover／target，收尾", tostring(unit)) end
            FinishInspect(guid)
            return
        end
        unit = now
        local precise, slot = PreciseInspectItemLevel(unit)
        if ns.logEnabled then ns.Log("觀察裝等 重試 自己算=%s 卡格=%s", tostring(precise), tostring(slot)) end
        if precise and precise > 0 then
            CachePut(inspect, guid, "level", precise)
            FinishInspect(guid)
        elseif GetTime() < deadline then
            RetryPreciseItemLevel(unit, guid, deadline)
        else
            if ns.logEnabled then ns.Log("觀察裝等 第 %s 格等不到快取，放棄、退回暴雪的整數", tostring(slot)) end
            FallbackRoughItemLevel(unit, guid)
            FinishInspect(guid)
        end
    end)
end

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("INSPECT_READY")
    f:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
    f:SetScript("OnEvent", function(_, event, guid)
        if event == "INSPECT_READY" then
            -- 不靠事件帶的 GUID 認貨：12.1 它可能是秘密值（比對一律 false）；別家插件（TinyInspect）
            -- 同幀也發觀察時伺服器只回最後那一個，事件的 GUID 是別人的。
            -- 改問「我們等的那個人的裝備現在讀不讀得到」：客戶端只留著當前被觀察者的裝備，
            -- 讀得到就是我們要的資料，不管是誰發的問。
            local pendingGUID = inspect.pendingGUID
            if not pendingGUID then return end
            local unit = ResolveUnit(pendingGUID, inspect.pendingUnit)
            if not unit then
                if ns.logEnabled then ns.Log("INSPECT_READY 等的人已經不在任何 token 上（事件 guid %s）", S.IsSecret(guid) and "秘密" or tostring(guid)) end
                return
            end
            if not InspectDataPresent(unit) then
                if ns.logEnabled then ns.Log("INSPECT_READY 不是我們等的 %s（事件 guid %s）", tostring(unit), S.IsSecret(guid) and "秘密" or tostring(guid)) end
                return
            end
            guid = pendingGUID
            if ns.logEnabled then ns.Log("INSPECT_READY 到貨 unit=%s", tostring(unit)) end
            local precise, slot = PreciseInspectItemLevel(unit)
            if ns.logEnabled then ns.Log("觀察裝等 自己算=%s 卡格=%s", tostring(precise), tostring(slot)) end
            if precise and precise > 0 then
                CachePut(inspect, guid, "level", precise)
            elseif slot then
                -- 物品資料沒快取齊：留著觀察資料重試，「??」等到小數算齊才換掉。
                -- 不先畫暴雪的整數——那會先跳一次整數再跳一次小數，看起來在抖。
                RetryPreciseItemLevel(unit, guid, GetTime() + PRECISE_RETRY_FOR)
                return
            else
                FallbackRoughItemLevel(unit, guid)
            end
            FinishInspect(guid)
        elseif event == "INSPECT_ACHIEVEMENT_READY" then
            if not achieve.pendingGUID then return end
            if guid and not GuidEquals(guid, achieve.pendingGUID) then return end
            local resolved = guid or achieve.pendingGUID
            local points = S.PlainNumber(S.SafeCall(GetComparisonAchievementPoints))
            if points and points >= 0 then CachePut(achieve, resolved, "points", points) end
            if ClearAchievementComparisonUnit then pcall(ClearAchievementComparisonUnit) end
            achieve.pendingGUID = nil
            if ns.RefreshUnitTip then ns.RefreshUnitTip(resolved) end
        end
    end)

    -- 玩家自己開觀察視窗時退讓 3 秒
    if InspectUnit then
        hooksecurefunc("InspectUnit", function()
            local now = GetTime()
            inspect.suspendedUntil = now + 3
            inspect.pendingGUID, inspect.pendingUnit = nil, nil
            achieve.suspendedUntil = now + 3
            achieve.pendingGUID = nil
        end)
    end
end

------------------------------------------------------------
-- raw 表（重用同一張，跟 TinyTooltip 一樣）
------------------------------------------------------------
local t = {}
function UnitInfo.GetUnitInfo(unit)
    if not unit or not S.SafeBool(UnitExists, unit) then
        wipe(t)
        t.unit = unit
        return t
    end

    local name, realm = S.SafeCall(UnitName, unit)
    local pvpName = S.SafeCall(UnitPVPName, unit)
    local gender = S.SafeCall(UnitSex, unit)
    local level = S.SafeCall(UnitLevel, unit)
    local effectiveLevel = UnitEffectiveLevel and S.SafeCall(UnitEffectiveLevel, unit) or level
    local raceName, race = S.SafeCall(UnitRace, unit)
    local className, class = S.SafeCall(UnitClass, unit)
    local factionGroup, factionName = S.SafeCall(UnitFactionGroup, unit)
    local reaction = S.SafeValue(S.SafeCall(UnitReaction, unit, "player"))
    local guildName, guildRank, guildIndex, guildRealm = S.SafeCall(GetGuildInfo, unit)
    local classif = S.SafeValue(S.SafeCall(UnitClassification, unit))
    local role = S.SafeValue(S.SafeCall(UnitGroupRolesAssigned, unit))
    local mplusScore, mplusColor, mplusBest = GetMythicPlusScore(unit)
    local isPlayer = S.SafeBool(UnitIsPlayer, unit)
    local itemLevel = isPlayer and GetUnitItemLevel(unit) or nil
    local achievementPoints = isPlayer and GetUnitAchievementPoints(unit) or nil
    local plainLevel = S.PlainNumber(level)

    t.raidIcon     = GetRaidIcon(unit)
    t.pvpIcon      = GetPVPIcon(unit)
    t.factionIcon  = S.PlainText(factionGroup) and icons[factionGroup] or nil
    t.classIcon    = GetClassIcon(class)
    t.roleIcon     = GetRoleIcon(unit)
    t.questIcon    = GetQuestBossIcon(unit)
    t.friendIcon   = GetFriendIcon(unit)
    t.factionName  = factionName
    t.role         = (type(role) == "string" and role ~= "NONE") and role or nil
    t.name         = name
    t.gender       = GetGender(gender)
    t.realm        = realm or GetRealmName()
    t.levelValue   = (plainLevel and plainLevel >= 0) and plainLevel or L["unknown"]
    t.itemLevel    = isPlayer and ((itemLevel and itemLevel > 0) and TruncItemLevel(itemLevel) or L["unknown"]) or nil
    t.achievementPoints = isPlayer and ((achievementPoints and achievementPoints >= 0) and floor(achievementPoints + 0.5) or L["unknown"]) or nil
    t.className    = className
    t.raceName     = raceName
    t.guildName    = guildName
    t.guildRank    = guildRank
    t.guildIndex   = guildName and guildIndex or nil
    t.guildRealm   = guildRealm
    t.statusAFK    = S.SafeBool(UnitIsAFK, unit) and AFK or nil
    t.statusDND    = S.SafeBool(UnitIsDND, unit) and DND or nil
    t.statusDC     = (S.SafeValue(S.SafeCall(UnitIsConnected, unit), true) == false) and OFFLINE or nil
    t.reactionName = reaction and _G["FACTION_STANDING_LABEL" .. reaction] or nil
    t.creature     = S.SafeCall(UnitCreatureType, unit)
    t.classifBoss  = (S.PlainNumber(level) == -1 or classif == "worldboss") and BOSS or nil
    t.classifElite = classif == "elite" and ELITE or nil
    t.classifRare  = (classif == "rare" or classif == "rareelite") and RARE or nil
    t.isPlayer     = isPlayer and PLAYER or nil
    t.moveSpeed    = GetMoveSpeed(unit)
    t.zone         = GetZone(unit, t.name, t.realm)
    t.unit         = unit
    t.level        = level
    t.effectiveLevel = effectiveLevel or level
    t.race         = race
    t.class        = class
    t.factionGroup = factionGroup
    t.reaction     = reaction
    t.classif      = classif
    t.title, t.titleIsPrefix = GetTitle(name, pvpName)
    if t.classifBoss then t.classifElite = nil end
    -- 分數與括號拆開存：染色只染分數，括號（最佳層數）固定白色
    if mplusScore and mplusScore > 0 then
        t.mplusScoreNumber = floor(mplusScore + 0.5)
        t.mplusBestText = (mplusBest and mplusBest > 0) and (" (" .. mplusBest .. ")") or ""
        t.mplusScoreColor = mplusColor
    else
        t.mplusScoreNumber = 0
        t.mplusBestText = " (0)"
        t.mplusScoreColor = { r = 0.6, g = 0.6, b = 0.6 }
    end
    t.mountName = nil
    t.mountCollected = nil
    t.classSpecIcon = nil
    return t
end

-- 坐騎欄位另外填（只有元素開啟才掃光環）
function UnitInfo.FillMount(raw, unit)
    raw.mountName, raw.mountCollected = GetMountInfo(unit)
end

------------------------------------------------------------
-- 顯示條件與格式化
------------------------------------------------------------
-- showAll：按住修飾鍵、且該類單位開著 modifierShowAll（見 UnitInfo.ModifierShowAll）
-- ⇒ 連關掉的元素也顯示、不看顯示條件
function UnitInfo.CheckFilter(config, raw, showAll)
    if showAll then return true end
    if not config or not config.enable then return end
    local filter = config.filter
    if not filter or filter == "" or filter == "none" then return true end
    local key = strsplit(":", filter)
    local oppo
    key, oppo = key:gsub("not%s+", "")
    local func = Colors.filterfunc[key]
    if func then
        local res = func(raw, select(2, strsplit(":", filter)))
        if oppo > 0 then return not res end
        return res
    end
    return true
end

-- value 可能是秘密（名字等）：format 合法；hex 上色只在有明文 hex 時做
function UnitInfo.FormatData(value, config, raw, numericValue)
    local color, wildcard = config.color, config.wildcard or "%s"
    local prevNumeric
    if raw and numericValue ~= nil then
        prevNumeric = raw._numericColorValue
        raw._numericColorValue = numericValue
    end
    local hex
    if Colors.colorfunc[color] then
        hex = select(4, Colors.colorfunc[color](raw))
    elseif type(color) == "string" and color:match("^%x%x%x%x%x%x$") then
        hex = color
    end
    if raw and numericValue ~= nil then
        raw._numericColorValue = prevNumeric
    end
    if not hex or color == "" or color == "default" or color == "none" then
        return (wildcard):format(value)
    end
    return ("|cff" .. hex .. wildcard .. "|r"):format(value)
end

------------------------------------------------------------
-- raw + elements → data（每列一個字串陣列）
------------------------------------------------------------
local function PushLabeled(out, labelText, iconTag, useIcon, valueText)
    local labelPart
    if useIcon and iconTag then
        labelPart = iconTag .. "|cffffd200:|r"
    else
        labelPart = format("|cffffd100%s:|r", labelText)
    end
    tinsert(out, format("%s %s", labelPart, valueText))
end

-- 「按住修飾鍵顯示全部」：Alt／Ctrl，玩家／NPC 各自一個開關（物品／法術是 item／spell 底下那兩個）
function UnitInfo.ModifierShowAll(config)
    if not (config and config.modifierShowAll) then return false end
    return IsAltKeyDown() or IsControlKeyDown()
end

function UnitInfo.GetUnitData(unit, elements, raw, showAll)
    local data = {}
    local namePos, titlePos
    if not raw then raw = UnitInfo.GetUnitInfo(unit) end
    local CheckFilter, FormatData = UnitInfo.CheckFilter, UnitInfo.FormatData
    for i, v in ipairs(elements) do
        data[i] = {}
        local out = data[i]
        namePos, titlePos = nil, nil
        for _, e in ipairs(v) do
            local config = elements[e]
            if e == "mount" then
                if CheckFilter(config, raw, showAll) and raw.mountName then
                    local nameText
                    if config.color and config.wildcard then
                        nameText = FormatData(raw.mountName, config, raw)
                    else
                        nameText = raw.mountName
                    end
                    local label = config.icon and (mountIconTag .. "|cffffd200:|r") or ("|cffffd200" .. L["Mount"] .. ":|r")
                    local statusText
                    if raw.mountCollected == true then
                        statusText = "|cff00ff00(" .. L["collected"] .. ")|r"
                    elseif raw.mountCollected == false then
                        statusText = "|cff999999(" .. L["uncollected"] .. ")|r"
                    end
                    if statusText then
                        tinsert(out, format("%s %s %s", label, nameText, statusText))
                    else
                        tinsert(out, format("%s %s", label, nameText))
                    end
                end
            elseif e == "className" then
                if CheckFilter(config, raw, showAll) and raw.className then
                    local classText
                    if config.color and config.wildcard then
                        classText = FormatData(raw.className, config, raw, raw.className)
                    else
                        classText = raw.className
                    end
                    if config.icon then
                        if raw.classSpecIcon then
                            classText = ("|T%s:14:14:0:0|t"):format(raw.classSpecIcon)
                        elseif type(raw.classIcon) == "string" then
                            classText = raw.classIcon
                        end
                    end
                    tinsert(out, classText)
                end
            elseif e == "mplusScore" then
                if CheckFilter(config, raw, showAll) and raw.mplusScoreNumber then
                    -- 只染分數；括號（最佳層數）固定白色（使用者定案）
                    local scorePart
                    if config.color and config.wildcard then
                        scorePart = FormatData(raw.mplusScoreNumber, config, raw, raw.mplusScoreNumber)
                    else
                        scorePart = tostring(raw.mplusScoreNumber)
                    end
                    local bestPart = (raw.mplusBestText and raw.mplusBestText ~= "")
                        and ("|cffffffff" .. raw.mplusBestText .. "|r") or ""
                    if config.icon then
                        tinsert(out, format("%s|cffffd200:|r %s%s", mplusIconTag, scorePart, bestPart))
                    else
                        tinsert(out, format("|cffffd100%s:|r %s%s", L["Mythic+ Score"], scorePart, bestPart))
                    end
                end
            elseif e == "itemLevel" then
                if CheckFilter(config, raw, showAll) and raw.itemLevel then
                    local valuePart
                    if tostring(raw.itemLevel) == L["unknown"] then
                        valuePart = "|cff999999" .. L["unknown"] .. "|r"
                    elseif config.color and config.wildcard then
                        valuePart = FormatData(raw.itemLevel, config, raw, raw.itemLevel)
                    else
                        valuePart = tostring(raw.itemLevel)
                    end
                    PushLabeled(out, L["ItemLevel"], itemLevelIconTag, config.icon, valuePart)
                end
            elseif e == "achievementPoints" then
                if CheckFilter(config, raw, showAll) and raw.achievementPoints ~= nil then
                    local valuePart
                    if tostring(raw.achievementPoints) == L["unknown"] then
                        valuePart = "|cff999999" .. L["unknown"] .. "|r"
                    elseif config.color and config.wildcard then
                        valuePart = FormatData(raw.achievementPoints, config, raw, raw.achievementPoints)
                    else
                        valuePart = tostring(raw.achievementPoints)
                    end
                    PushLabeled(out, L["Achievement"], achievementIconTag, config.icon, valuePart)
                end
            elseif CheckFilter(config, raw, showAll) and raw[e] then
                if e == "name" then namePos = #out + 1 end
                if e == "title" then titlePos = #out + 1 end
                if config.color and config.wildcard then
                    -- 頭銜是後綴時要排在名字後面（TinyTooltip 同款位置交換）
                    if e == "title" and namePos == #out and raw.titleIsPrefix then
                        tinsert(out, namePos, FormatData(raw[e], config, raw, raw[e]))
                    elseif e == "name" and titlePos == #out and not raw.titleIsPrefix then
                        tinsert(out, titlePos, FormatData(raw[e], config, raw, raw[e]))
                    else
                        tinsert(out, FormatData(raw[e], config, raw, raw[e]))
                    end
                else
                    tinsert(out, raw[e])
                end
            end
        end
    end
    for i = #data, 1, -1 do
        if not data[i][1] then tremove(data, i) end
    end
    return data
end

------------------------------------------------------------
-- 一列的欄位串成一行。
--
-- ⚠ **不可用 table.concat**：秘密字串（12.1 的 UnitClass／UnitName／GetGuildInfo…）
--   餵進 C 函式會失敗，而原本整包只有一個 pcall ⇒ 任何一個欄位是秘密值就
--   **整列回 ""**，畫面上「職業 等級 陣營 性別 種族」一起消失，且完全不報錯
--   （2026-09-06 玩家回報「職業有時候不見」的候選成因）。
--   秘密值可以串接、可以 format，只是不能讀（當傳遞者不當讀取者），所以逐段串、
--   逐段 pcall —— 失效的粒度就從「整列」縮到「那一個欄位」。
--   同理 `tostring` 對秘密數字是禁止的，數字也一律走 format。
------------------------------------------------------------
function UnitInfo.JoinRow(list, sep)
    if type(list) ~= "table" then return "" end
    sep = sep or " "
    local res
    for i = 1, #list do
        local v = list[i]
        local vt = type(v)          -- type() 對秘密值合法
        if vt == "string" or vt == "number" then
            local ok, piece = pcall(format, "%s", v)
            if ok and piece ~= nil then
                if res == nil then
                    res = piece
                else
                    local ok2, joined = pcall(format, "%s%s%s", res, sep, piece)
                    if ok2 and joined ~= nil then res = joined end
                end
            end
        end
    end
    return res or ""
end
