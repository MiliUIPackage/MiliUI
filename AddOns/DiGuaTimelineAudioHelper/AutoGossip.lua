local addonName, addonTable = ...

-------------------------------------------------------------------------------
-- AutoGossip.lua —— 赛季五人本「全对话自动点」
-------------------------------------------------------------------------------
-- 【老做法·已停用】把每处对话的 gossipOptionID 一个个抓出来登记（EnabledGossipIDs 表已
--            整块注释掉，保留备查）。缺点：每加一处 RP / 每换一个副本都要重新抓 ID，太麻烦。
-- 【新做法】不再依赖 ID：三个条件同时成立时，遇到【只有一个选项】的对话就自动点掉；
--            两个及以上选项的对话（要玩家自己选）一律不点；
--            选项点了之后弹出的暴雪「二次确认」框（GOSSIP_CONFIRM）也会自动点确认（要花钱的除外）：
--              ① 队伍正在跑大秘境（钥石层数 ≥ 2，即钥石已插 / 计时中；史诗 M 本不算）；
--              ② 所在副本属于「当前赛季的 8 个五人本」；
--              ③ 本把还没打完、也没超时（打完最后一个 boss 或计时耗尽后都不再自动点，
--                 出本 / 重开一把即恢复）。
--            赛季名单不写死：运行时用 C_ChallengeMode.GetMapTable() 现取
--            （暴雪随赛季自己更新），下面的 SEASON_FALLBACK_INSTANCE_IDS 仅在
--            API 取不到时兜底，所以换赛季漏改也不会致命。
-- 【开关】控制台右栏「赛季五人本自动对话」（db.autoGossipEnabled，默认开）。
-- 【停用】手工 ID 表与对应的匹配逻辑已全部注释掉，只走上面这套「赛季本 + 大秘境」判定。
-------------------------------------------------------------------------------

--[[ 已停用（2026-10-09）：手工登记的对话选项 ID —— 现在只按「赛季本 + 大秘境」全自动点。
     保留在这里备查；万一要临时恢复老行为，把本块注释去掉，并把下面 TrySelectOneOption
     里注释掉的 manual 那两行一起放开即可。
addonTable.EnabledGossipIDs = {
    [135009] = true, -- 洞穴 (门口)
    [135010] = true, -- 洞穴 (老二)
    [137693] = true, -- 洞穴 (熏香人形态)
    [137694] = true, -- 洞穴 (熏香熊形态)
    [131567] = true, -- 密谋
    [131502] = true, -- 密谋
    [141729] = true, -- 毒牙
    [141730] = true, -- 毒牙
}
]]--

-- 新行为总开关（想在别的文件 / 控制台里关掉时置 false 即可；nil 视为开启）
-- 已改名：原名 AutoGossipInMythicPlus（因为不再要求大秘境环境）
addonTable.AutoGossipInSeasonDungeons = true

-------------------------------------------------------------------------------
-- 1. 「当前赛季的 8 个五人本」判定
-------------------------------------------------------------------------------
-- 兜底名单：当前赛季 8 个五人本的副本 ID（select(8, GetInstanceInfo())）
-- 与插件其它文件里已经在用的是同一套 ID；正常情况靠 GetMapTable() 自动取，
-- 这里只在 API 拿不到时兜底，所以换赛季漏改也不会致命。
local SEASON_FALLBACK_INSTANCE_IDS = {
    [1762] = "诸王之眠",
    [1877] = "塞塔里斯神庙",
    [2521] = "红玉新生法池",
    [2813] = "密谋小径",
    [2825] = "纳洛拉克的洞穴",
    [2859] = "夺目谷",
    [2923] = "虚空之痕竞技场",
    [2993] = "毒牙祭坛",
}

-- 运行时赛季名单：GetMapTable() 给出本季挑战模式地图 ID，GetMapUIInfo() 再取到地图 ID。
-- 使用时是「动态表 + 兜底表」取并集，所以动态表即使解析出别的命名空间也不会产生副作用。
local seasonInstanceIDs = {}
local seasonSetReady = false

local function RebuildSeasonInstanceIDs()
    wipe(seasonInstanceIDs)
    seasonSetReady = false
    local cm = C_ChallengeMode
    if not (cm and cm.GetMapTable and cm.GetMapUIInfo) then return end
    local ok, maps = pcall(cm.GetMapTable)
    if not ok or type(maps) ~= "table" then return end
    for _, challengeMapID in ipairs(maps) do
        -- GetMapUIInfo 第 6 个返回值是地图 ID（可与当前所在地图 ID 直接对照）
        local infoOK, _, _, _, _, _, mapID = pcall(cm.GetMapUIInfo, challengeMapID)
        if infoOK and type(mapID) == "number" and mapID > 0 then
            seasonInstanceIDs[mapID] = true
            seasonSetReady = true
        end
    end
end

local function IsSeasonInstanceID(id)
    if type(id) ~= "number" then return false end
    return seasonInstanceIDs[id] == true or SEASON_FALLBACK_INSTANCE_IDS[id] ~= nil
end

-- 当前是否站在「赛季 8 个五人本」里（副本 ID 与当前地图 ID 都试一遍，谁中算谁）
local function IsSeasonDungeon()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType ~= "party" then return false end -- 只认五人本（团本 instanceType 是 raid）
    if IsSeasonInstanceID(instanceID) then return true end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return IsSeasonInstanceID(mapID)
end

-- 是否在跑大秘境：只看【钥石层数 ≥ 2】
-- 为什么不用其它信号：IsChallengeModeActive / HasSlottedKeystone / 难度 8·23 都会把
-- 「史诗(M) 五人本」也算进来（太松）；层数 ≥ 2 只有“钥石真的插进去在计时”才会满足。
-- 与 SkipCinematic.lua 的 IsMythicPlusActive() 是同一套判据。
local function IsMythicPlusRun()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then return false end
    local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    if keystoneLevel == nil then return false end
    if issecretvalue and issecretvalue(keystoneLevel) then return false end
    return type(keystoneLevel) == "number" and keystoneLevel >= 2
end

-- secret 值不能拼接 / 比较 / 当表键，统一从这里判断
local function IsSecret(v)
    return (issecretvalue ~= nil) and (issecretvalue(v) == true)
end

-- 大秘境是否已超时（计时耗尽）：直接读暴雪自己的世界计时器，
-- 数据源与暴雪目标追踪器（Blizzard_ScenarioObjectiveTracker）完全一致：
--   计时器已用时间（GetWorldElapsedTime 第 2 个返回）> 限时（GetMapUIInfo 第 3 个返回）→ 已超时。
-- 这一对值暴雪本来就是配着用的（同一个进度条），所以不存在单位不一致问题；
-- 任何一步拿不到值 / 碰到 secret 值都当作「没超时」——失败时宁可继续工作，也不要整把不生效。
local function IsChallengeModeExpired()
    local cm = C_ChallengeMode
    if not (cm and cm.GetActiveChallengeMapID and cm.GetMapUIInfo) then return false end
    if type(GetWorldElapsedTimers) ~= "function" or type(GetWorldElapsedTime) ~= "function" then return false end
    local challengeType = Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ChallengeMode
    if challengeType == nil then return false end

    local timers = GetWorldElapsedTimers()
    if type(timers) ~= "table" then return false end
    local mapID = cm.GetActiveChallengeMapID()
    if mapID == nil then return false end
    local _, _, timeLimit = cm.GetMapUIInfo(mapID)
    if type(timeLimit) ~= "number" or timeLimit <= 0 or IsSecret(timeLimit) then return false end

    for _, timerID in ipairs(timers) do
        local ok, _, elapsed, timerType = pcall(GetWorldElapsedTime, timerID)
        if ok and not IsSecret(timerType) and timerType == challengeType
            and type(elapsed) == "number" and not IsSecret(elapsed) and elapsed > timeLimit then
            return true
        end
    end
    return false
end

-- 本把大秘境是否已经打完（打完最后一个 boss → 停止自动对话）
-- 用事件维护（比查 API 可靠）：CHALLENGE_MODE_COMPLETED 置 true；
-- CHALLENGE_MODE_START / CHALLENGE_MODE_RESET / PLAYER_ENTERING_WORLD（换副本、上线、重载）置 false。
local runCompleted = false

-- 测试总开关（2026-10-09 测试完已恢复）：
--   false = 正常（默认）：下面【所有环境限制】全部生效（副本名单 / 大秘境层数 / 未打完 / 未超时）；
--   true  = 仅测试用：跳过全部环境限制，任何副本甚至野外都会自动点对话。
--   （限制条件的代码一行都没删，只是被这个开关跳过。）
local SKIP_ALL_RESTRICTIONS = false

-- 最终判定：三个条件都成立才放开「所有对话自动点」
--   ① 所在副本属于当前赛季的 8 个五人本；
--   ② 队伍正在跑大秘境（钥石层数 ≥ 2）；
--   ③ 本把还没打完、也没超时
local function IsAutoGossipEnvironment()
    -- 用户开关：控制台「赛季五人本自动对话」（db.autoGossipEnabled，默认开；旧存档 nil 视为开）
    local db = DiGuaTimelineAudioHelper
    if db and db.autoGossipEnabled == false then return false end
    -- 程序级开关：给其它文件 / 调试用（默认开）
    if addonTable.AutoGossipInSeasonDungeons == false then return false end
    -- ★ 测试模式：跳过以下全部环境限制
    if SKIP_ALL_RESTRICTIONS then return true end
    -- ① 赛季 8 个五人本
    if not seasonSetReady then RebuildSeasonInstanceIDs() end
    if not IsSeasonDungeon() then return false end
    -- ② 大秘境（钥石层数 ≥ 2）
    if not IsMythicPlusRun() then return false end
    -- ③ 本把还没打完、也没超时（超时那一刻就停手，不等最后一个 boss）
    if runCompleted then return false end
    if IsChallengeModeExpired() then return false end
    return true
end

-------------------------------------------------------------------------------
-- 2. 自动选择对话选项的核心逻辑（常驻看门狗，目标是 100% 点到）
-------------------------------------------------------------------------------
-- 【为什么改】旧版是「打开对话 → 轮询 5 秒」：
--   只要选项在这 5 秒之后才出现（服务器慢 / 翻页间隔长 / 事件压根没触发），就永远点不到，
--   实测做不到 100%。同一选项 ID 5 秒内不许再点那层防抖，也会把"继续"这类翻页按钮挡住。
--   现在改成 OnUpdate 常驻监看（每 0.2 秒看一眼 C_GossipInfo.GetOptions()）：
--   不依赖任何事件、不设时间预算 —— 只要还读得到选项，就一定会被点掉。
--
-- 【怎么点】Blizzard 自己的对话按钮点击就是 C_GossipInfo.SelectOptionByIndex(orderIndex)
--   （见 GossipFrameShared.lua / CustomGossipFrameBase.lua），所以优先走这条官方路径，
--   同一个页面再来一次时改用 C_GossipInfo.SelectOption(gossipOptionID)，第三次两条都发。
--
-- 【防死循环】用「页面签名」判断有没有真的翻页：签名 = 选项数量 + 每个选项的
--   orderIndex/gossipOptionID/name + GetText()。翻页了（签名变了）就继续点；
--   同一页面连点 6 次都没变化 = 服务器没反应或本来就不前进 → 停手，等它下次变化。
-------------------------------------------------------------------------------

-- 看门狗节流：每 0.2 秒看一眼
-- ⚠️ OnUpdate 只在「已 Show 的框架」上触发，所以下面 frame 必须 Show()
local WATCH_INTERVAL = 0.2
local watchElapsed = 0

-- 调试开关：遇到"没自动点"时改成 true，每次点击会印一行到聊天框（看完记得改回 false）
local DEBUG = false

-- 选项状态枚举（12.1：Available = 0）
local AVAILABLE = (Enum.GossipOptionStatus and Enum.GossipOptionStatus.Available) or 0

-- 防死循环 / 限流
local MAX_SAME_PAGE_TRIES = 6 -- 同一页面连续点 6 次都没变化 → 停手
local CLICK_WINDOW = 30 -- 滚动窗口
local MAX_CLICKS_PER_WINDOW = 25 -- 窗口内最多自动点 25 下（最后一道保险）

local pageSignature = nil -- 上一次点击时的页面签名
local samePageTries = 0 -- 同一页面连着点了几次
local clickLog = {} -- 最近的点击时间（升序）

local function PruneClickLog(now)
    while #clickLog > 0 and now - clickLog[1] > CLICK_WINDOW do
        table.remove(clickLog, 1)
    end
end

-- secret 值不能拼接 / 不能当表键 / 不能比较，这里统一转成安全字符串
local function SafeStr(v)
    if v == nil then return "?" end
    if issecretvalue and issecretvalue(v) then return "#" end
    local t = type(v)
    if t == "string" then return v end
    if t == "number" or t == "boolean" then return tostring(v) end
    return "?"
end

local function BuildPageSignature(options)
    local parts = { "#" .. tostring(#options) }
    for i = 1, #options do
        local option = options[i]
        parts[#parts + 1] = SafeStr(option.orderIndex) .. "/" .. SafeStr(option.gossipOptionID) .. "/" .. SafeStr(option.name)
    end
    local text = C_GossipInfo.GetText and C_GossipInfo.GetText()
    parts[#parts + 1] = SafeStr(text)
    return table.concat(parts, "|")
end

-- 这个选项现在能不能点（状态读不到 / 是 secret 时一律放行：宁可点了被服务器忽略）
local function IsOptionUsable(option)
    local status = option.status
    if status == nil then return true end
    if issecretvalue and issecretvalue(status) then return true end
    return status == AVAILABLE
end

-- 按第 attempt 次尝试的策略点这个选项（1=官方 index 路径 2=ID 路径 3+=两条都发）
local function ClickOption(option, attempt)
    local orderIndex = option.orderIndex
    local optionID = option.gossipOptionID
    local mode = attempt % 3

    if (mode == 1 or mode == 0) and orderIndex ~= nil then
        pcall(C_GossipInfo.SelectOptionByIndex, orderIndex)
    end
    if (mode == 2 or mode == 0) and optionID ~= nil then
        pcall(C_GossipInfo.SelectOption, optionID)
    end
end

-- 点当前页面：只有本页【恰好一个选项】时才点（两个及以上 = 要让玩家自己选，不替玩家做决定）
-- 返回是否算作一次点击尝试
local function TryClickCurrentPage(options)
    -- 两个或更多选项 → 不点（例如「人形态 / 熊形态」这类要自己挑的对话）
    if #options > 1 then return false end

    -- 优先 Available = 0；拿不到 / 不是 Available 也点这唯一的选项
    local target = options[1]
    for i = 1, #options do
        if IsOptionUsable(options[i]) then
            target = options[i]
            break
        end
    end
    if not target then return false end

    local now = GetTime()
    PruneClickLog(now)
    if #clickLog >= MAX_CLICKS_PER_WINDOW then return end
    clickLog[#clickLog + 1] = now

    samePageTries = samePageTries + 1
    ClickOption(target, samePageTries)
    if DEBUG then
        print(("|cffffd100[DiGua AutoGossip]|r 第 %d 次点击 %s (orderIndex=%s, id=%s)"):format(
            samePageTries, SafeStr(target.name), SafeStr(target.orderIndex), SafeStr(target.gossipOptionID)))
    end
    return true
end

-- 看门狗本体：不依赖任何事件，只要有选项就点
local function WatchGossip()
    if not (C_GossipInfo and C_GossipInfo.GetOptions) then return end
    local options = C_GossipInfo.GetOptions()
    if not options or #options == 0 then
        -- 对话不在 / 选项还没加载出来 → 清空记忆，下次出现按新页面处理
        pageSignature = nil
        samePageTries = 0
        return
    end
    if not IsAutoGossipEnvironment() then return end

    local signature = BuildPageSignature(options)
    if signature ~= pageSignature then
        pageSignature = signature
        samePageTries = 0 -- 翻页了 → 重新开始点
        if DEBUG and #options > 1 then
            print(("|cffffd100[DiGua AutoGossip]|r 本页有 %d 个选项 → 不自动点（交给玩家自己选）"):format(#options))
        end
    end
    if samePageTries >= MAX_SAME_PAGE_TRIES then return end -- 这一页点够了，等它变

    TryClickCurrentPage(options)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:RegisterEvent("GOSSIP_OPTIONS_REFRESHED")
frame:RegisterEvent("GOSSIP_CONFIRM")
frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHALLENGE_MODE_RESET")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:Show() -- 关键：OnUpdate 只对已显示的框架触发（本框无尺寸无贴图，显示不会有任何副作用）

-- 常驻看门狗：每 0.2 秒看一眼（事件只是"加急"，不看门狗不靠它们）
frame:SetScript("OnUpdate", function(_, elapsed)
    watchElapsed = watchElapsed + (elapsed or 0)
    if watchElapsed < WATCH_INTERVAL then return end
    watchElapsed = 0
    WatchGossip()
end)

local function ResetPageMemory()
    pageSignature = nil
    samePageTries = 0
end

-- 对话选项的「二次确认」弹窗（GOSSIP_CONFIRM）自动点确认。
-- 依据：暴雪自己的确认按钮就是这条调用 ——
--   Blizzard_StaticPopup_Game/GameDialogDefs.lua 里
--   StaticPopupDialogs["GOSSIP_CONFIRM"].OnAccept = function(dialog, data)
--       C_GossipInfo.SelectOption(data.optionID, "", true)   -- 第三个参数 true = 玩家已确认
--   end
-- 所以这里照抄同一条调用（第 3 个参数 true 就是“已确认”，不会再弹一次框）。
-- 花钱的确认（cost > 0）默认不自动点，避免自动花金币；想放开把 ALLOW_COSTLY_CONFIRM 改成 true。
local ALLOW_COSTLY_CONFIRM = false

local function AutoConfirmGossipOption(optionID, text, cost)
    if optionID == nil then return end
    if cost ~= nil and not IsSecret(cost) and type(cost) == "number" and cost > 0 then
        if not ALLOW_COSTLY_CONFIRM then
            print(("|cffffd100[DiGua]|r 对话需要二次确认（花费 %d 铜）→ 已跳过自动确认，请手动点"):format(cost))
            return
        end
    end
    -- 与自动点选项一样，只在生效环境下才自动确认（不干预范围外的手动操作）
    if not IsAutoGossipEnvironment() then return end
    local ok = pcall(C_GossipInfo.SelectOption, optionID, "", true)
    if DEBUG then
        print(("|cffffd100[DiGua AutoGossip]|r 自动确认弹窗 optionID=%s 文本=%s ok=%s"):format(
            SafeStr(optionID), SafeStr(text), tostring(ok)))
    end
end

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        -- 交互类型拿不到（nil）时也照样看一遍，宁可多看一眼
        if arg1 ~= nil and arg1 ~= Enum.PlayerInteractionType.Gossip then return end
        ResetPageMemory()
        WatchGossip() -- 加急：立刻先点一次，不等 OnUpdate
    elseif event == "GOSSIP_SHOW" then
        ResetPageMemory()
        WatchGossip()
    elseif event == "GOSSIP_OPTIONS_REFRESHED" then
        -- 选项刷新：可能翻页了，也可能同一页重发 —— 交给页面签名判断
        WatchGossip()
    elseif event == "GOSSIP_CONFIRM" then
        -- 点了选项后弹出的「确认框」→ 自动确认（arg1=optionID, arg2=文本, arg3=花费铜币）
        AutoConfirmGossipOption(arg1, arg2, arg3)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if arg1 == nil or arg1 == Enum.PlayerInteractionType.Gossip then
            ResetPageMemory()
        end
    elseif event == "GOSSIP_CLOSED" then
        ResetPageMemory()
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        -- 赛季地图表变了（新赛季 / 热修）→ 丢掉缓存，下次判定时重建
        seasonSetReady = false
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        -- 打完（最后一个 boss 死）→ 这一把不再自动点对话
        runCompleted = true
    elseif event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET"
        or event == "PLAYER_ENTERING_WORLD" then
        -- 新开一把 / 重置挑战模式 / 换副本（含上线、重载）→ 恢复自动点
        runCompleted = false
    end
end)