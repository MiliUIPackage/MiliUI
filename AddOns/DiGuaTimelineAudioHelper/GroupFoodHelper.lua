-- GroupFoodHelper.lua
-- 大餐 / 灵魂之井 社交提醒：
--   1) 术士自己成功施放 29893（制造灵魂之井）→ 通过插件通讯通知队友拿糖（聊天无任何显示）
--   2) 收到队友的通知 / 聊天里出现大餐表情 → 播放对应语音

local addonName, addonTable = ...

-- ===== 施放灵魂之井 → 插件通讯通知队友 =====
local SOULWELL_MSG_PREFIX = "DIGUA_SOULWELL" -- 自定义 addon 消息前缀（收发一致）
local SOULWELL_SPELL_ID = 29893 -- 制造灵魂之井
local WARLOCK_CLASS = "WARLOCK" -- 术士

-- 防抖：防止短时间内反复放井导致队友语音刷屏
local DEBOUNCE_INTERVAL = 10 -- 秒
local lastSendTime = 0 -- 发送端防抖时间戳

-- 注册消息前缀（只有装了本插件的客户端才能收到）
C_ChatInfo.RegisterAddonMessagePrefix(SOULWELL_MSG_PREFIX)

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
    if channel and GetTime() - lastSendTime >= DEBOUNCE_INTERVAL then
        lastSendTime = GetTime()
        C_ChatInfo.SendAddonMessage(SOULWELL_MSG_PREFIX, "1", channel) -- 隐藏通知，聊天框无任何显示
    end
end)

-- ===== 收到队友的灵魂之井通知 → 播拿糖语音 =====
local msgFrame = CreateFrame("Frame")
local lastPlayTime = 0 -- 接收端防抖时间戳
msgFrame:RegisterEvent("CHAT_MSG_ADDON")
msgFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    -- 战斗门控：战斗中不运作（不播任何语音/不处理通知）
    if InCombatLockdown() then return end

    -- 秘密值防护（永远在最前）
    if issecretvalue and (issecretvalue(prefix) or issecretvalue(sender)) then return end
    if issecrettable and (issecrettable(prefix) or issecrettable(sender)) then return end

    if prefix ~= SOULWELL_MSG_PREFIX then return end -- 只看自己的前缀
    if not sender then return end

    -- sender 通常带 "-服务器" 后缀，去掉后和队伍成员名比较
    local bare = strsplit("-", sender)
    if bare == UnitName("player") then return end -- 自己发的，跳过（术士本人不需听语音）

    -- 判断是否本队/本团成员（避免 ADDON 消息被陌生客户端伪造骚扰）
    local isGroup = false
    if IsInRaid() then
        for i = 1, 40 do
            local n = UnitName("raid" .. i)
            if n == bare or n == sender then isGroup = true break end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local n = UnitName("party" .. i)
            if n == bare or n == sender then isGroup = true break end
        end
    end
    if not isGroup then return end

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