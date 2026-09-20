-- GroupFoodHelper.lua
-- 大餐 / 灵魂之井 社交提醒：
--   1) 术士自己成功施放 29893（制造灵魂之井）→ 通过插件通讯通知队友拿糖（聊天无任何显示）
--      只在副本内生效，且要求双方「同队伍 + 同一副本 + 副本内同一区域（地图）」，
--      野外放井不提示；术士在副本末尾、接收者在入口时也不提示
--   2) 收到队友的通知 / 聊天里出现大餐表情 → 播放对应语音

local addonName, addonTable = ...

-- ===== 施放灵魂之井 → 插件通讯通知队友 =====
local SOULWELL_MSG_PREFIX = "DIGUA_SOULWELL" -- 自定义 addon 消息前缀（收发一致）
local SOULWELL_SPELL_ID = 29893 -- 制造灵魂之井
local WARLOCK_CLASS = "WARLOCK" -- 术士
local SOULWELL_MSG_VERSION = "DIGUA3" -- 消息格式版本：对不上直接忽略（格式变更时记得同步改这里）

-- 防抖：防止短时间内反复放井导致队友语音刷屏
local DEBOUNCE_INTERVAL = 10 -- 秒
local lastSendTime = 0 -- 发送端防抖时间戳

-- 注册消息前缀（只有装了本插件的客户端才能收到）
C_ChatInfo.RegisterAddonMessagePrefix(SOULWELL_MSG_PREFIX)

-- 取「我自己在副本的哪个区域」的指纹。⚠️ 永远只查本人（"player"），绝不去查队友：
-- 发送端由术士查到自己的值后随消息发出去，接收端也只查自己的值来对账。
--   instanceID GetInstanceInfo 第 8 位：该副本的 InstanceID（挡住「一人在本里、一人在外面」）
--   mapID      C_Map.GetBestMapForUnit("player")：当前所在区域的 UI 地图 ID，
--              返回的是「最内层」地图（副本里就是该副本/该区域的图）。
--              同一副本不同区域地图 ID 不同（例如毒牙祭坛入口 2588 / 深处 2589、2590），
--              所以它能顺便当距离用：术士在副本末尾、接收者在入口 → 地图 ID 不同 → 不提示。
-- 只认副本内（团本/5人本/大秘境），野外和主城一律返回 nil —— 本功能不处理野外。
local function GetMyInstanceSignature()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "none" then return nil end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return instanceID or 0, mapID or 0
end

local castFrame = CreateFrame("Frame")
castFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
castFrame:SetScript("OnEvent", function(self, event, unitTarget, castGUID, spellID)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
    if InCombatLockdown() then return end -- 战斗中不运作
    if unitTarget ~= "player" then return end -- 只看自己施法成功
    if spellID ~= SOULWELL_SPELL_ID then return end -- 制造灵魂之井
    if UnitClassBase("player") ~= WARLOCK_CLASS then return end -- 仅术士

    -- 仅小队/团队中才通知；按当前队伍类型选通道（团本 RAID / 5人小队 PARTY）
    local channel
    if IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    end
    -- 10 秒防抖后发送隐藏通知；术士本人不放语音（自己放的技能，无需提示）
    -- 由术士（发送端）自己查自己的副本 ID / 区域地图 ID，然后随消息发出去；野外放井不发
    local instanceID, mapID = GetMyInstanceSignature()
    if channel and instanceID and GetTime() - lastSendTime >= DEBOUNCE_INTERVAL then
        lastSendTime = GetTime()
        -- 格式：版本:副本ID:区域地图ID
        local msg = table.concat({ SOULWELL_MSG_VERSION, instanceID, mapID }, ":")
        C_ChatInfo.SendAddonMessage(SOULWELL_MSG_PREFIX, msg, channel) -- 隐藏通知，聊天框无任何显示
    end
end)

-- 在队伍/团队里按名字找出对应的 unit token；顺便挡掉陌生客户端伪造的 ADDON 消息
local function FindGroupUnit(bare, sender)
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            local n = UnitName(unit)
            if n and (n == bare or n == sender) then return unit end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            local n = UnitName(unit)
            if n and (n == bare or n == sender) then return unit end
        end
    end
    return nil
end

-- ===== 收到队友的灵魂之井通知 → 播拿糖语音 =====
local msgFrame = CreateFrame("Frame")
local lastPlayTime = 0 -- 接收端防抖时间戳
msgFrame:RegisterEvent("CHAT_MSG_ADDON")
msgFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    -- 战斗门控：战斗中不运作（不播任何语音/不处理通知）
    if InCombatLockdown() then return end

    -- 秘密值防护（永远在最前）
    if issecretvalue and (issecretvalue(prefix) or issecretvalue(message) or issecretvalue(sender)) then return end
    if issecrettable and (issecrettable(prefix) or issecrettable(message) or issecrettable(sender)) then return end

    if prefix ~= SOULWELL_MSG_PREFIX then return end -- 只看自己的前缀
    if not sender or not message then return end

    -- sender 通常带 "-服务器" 后缀，去掉后和队伍成员名比较
    local bare = strsplit("-", sender)
    if bare == UnitName("player") then return end -- 自己发的，跳过（术士本人不需听语音）

    -- 必须是本队/本团成员（避免 ADDON 消息被陌生客户端伪造骚扰），顺便拿到 unit token
    local unit = FindGroupUnit(bare, sender)
    if not unit then return end

    -- 位置校验：必须「同一副本 + 副本内同一区域」，否则说明两人根本不在一块
    local ver, sInstanceID, sMapID = strsplit(":", message)
    if ver ~= SOULWELL_MSG_VERSION then return end -- 版本对不上（对方插件过旧/过新）
    sInstanceID = tonumber(sInstanceID)
    sMapID = tonumber(sMapID)
    if not sInstanceID or not sMapID then return end -- 消息格式不对

    -- ⚠️ 这里查的是「我自己」的位置，不是去查队友：术士的位置来自上面解析出来的消息
    local myInstanceID, myMapID = GetMyInstanceSignature()
    if not myInstanceID then return end -- 自己不在副本里（野外/主城）不提示
    if sInstanceID ~= myInstanceID then return end -- 不同副本（含「一人在副本里、一人在外面」）
    if sMapID ~= myMapID then return end -- 同一副本但人不在同一区域（入口 vs 末尾）

    -- 10 秒防抖：防止多个术士/重复消息导致语音刷屏
    if GetTime() - lastPlayTime >= DEBOUNCE_INTERVAL then
        lastPlayTime = GetTime()
        PlaySoundFile(addonTable.GetMediaPath() .. "NaTang.ogg", DiGuaTimelineAudioHelper.audioChannel)
    end
end)

-- ===== 聊天表情 → 播放语音 =====
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")

frame:SetScript("OnEvent", function(self, event, text, playerName)
    -- 战斗门控：战斗中不运作（不播大餐语音）
    if InCombatLockdown() then return end

    -- 1. 秘密值/安全检查 (11.0+ / 12.0+ API 兼容保护)
    if issecretvalue and issecretvalue(text) then return end
    if issecrettable and issecrettable(text) then return end

    if not text or not playerName then return end

    -- 2. 队员过滤：判断发送者是否在队伍或团队中
    if not UnitInParty(playerName) and not UnitInRaid(playerName) then
        return
    end

    -- 3. 文本匹配与语音触发
    if string.find(text, "供大家享用") then
        PlaySoundFile(addonTable.GetMediaPath() .. "QuChiDaCan.ogg", DiGuaTimelineAudioHelper.audioChannel)
    end
end)