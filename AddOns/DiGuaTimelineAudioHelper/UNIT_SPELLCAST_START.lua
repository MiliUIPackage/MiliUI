-- UNIT_SPELLCAST_START.lua
-- 处理怪物开始施法事件的独立分支
local addonName, addonTable = ...

-- 注册事件监听的框架层代码（供主文件参考或直接使用）
local frame = CreateFrame("Frame")
addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}
addonTable.SpellCastStartTime = addonTable.SpellCastStartTime or {}
addonTable.SpellCastAudioTriggered = nil
addonTable.DuoKaiTouQianLock = nil -- 躲開正面防抖锁
addonTable.SpellCastDuration = addonTable.SpellCastDuration or {}
addonTable.HasCastFearRoar = addonTable.HasCastFearRoar or {} -- 记录已施放过"恐惧咆哮"的单位（作为"残杀"播报资格）

-- ShouldWarnInterruptWithFocus() 已移至 Utils.lua（addonTable 全局函数），START/CHANNEL 共用

frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_START" then
        local unitTarget = ...
        -- local specID = PlayerUtil.GetCurrentSpecID()

        -- print(specID)
        -- 获取主文件的路径与声道配置
        -- encounterEventIDs = C_EncounterEvents.GetEventList()
        -- if encounterEventIDs then
        --     print("--- 开始打印 Event List ---")
        --     for index, eventID in ipairs(encounterEventIDs) do
        --         print(string.format("[%d] = %d", index, eventID))
        --     end
        --     print("--- 打印结束 ---")
        -- else
        --     print("未获取到事件列表")
        -- end

        -- local instanceID = 1202 -- 替换为你当前副本的 Instance ID（例如 1202 是红玉新生法池，1041 是诸王之眠）
        -- local encounterID = 3470

        -- -- 优先预热/选中该副本手册
        -- if instanceID then
        --     EJ_SelectInstance(instanceID)
        -- end

        -- local name = EJ_GetEncounterInfo(encounterID)
        -- if name then
        --     print(string.format("Encounter ID: %d -> %s", encounterID, name))
        -- else
        --     print(string.format("Encounter ID: %d -> 未找到首领信息", encounterID))
        -- end


        -- local events = {}
        -- for i = 950, 1050 do
        --     table.insert(events, i)
        -- end
        -- local privateAuras = {1297649, 1297648},

        -- -- 2. 开始打印 Encounter Events 格式（已加双层大括号）
        -- print("--- 开始打印 Encounter Events 格式 ---")
        -- for _, eventID in ipairs(events) do
        --     local info = C_EncounterEvents.GetEventInfo(eventID)
        --     local spellName = info and C_Spell.GetSpellName(info.spellID or 0) or "未知"
        --     -- 修复了原本代码中转义偏多的 \" 结构，使其输出为标准的 [.ogg] 键值对格式
        --     print(string.format("    [%d] = { {\".ogg\", 1} }, -- %s (%d)", eventID, spellName, info and info.spellID or 0))
        -- end

        -- -- 3. 开始打印 Private Auras 格式
        -- print("--- 开始打印 Private Auras 格式 ---")
        -- for _, spellID in ipairs(privateAuras) do
        --     local spellName = C_Spell.GetSpellName(spellID) or "未知"
        --     print(string.format("    [%d] = \"\", -- %s", spellID, spellName))
        -- end


        -- local checkList8 = {
        --     372047, 372963, 373693, 385536, 392641, 395292, 1305201, 1305225, 
        --     1306366, 1307205, 1307372, 1310361, 1310599
        -- }

        -- for _, spellID in ipairs(checkList8) do
        --     local spellLink = C_Spell.GetSpellLink(spellID)
        --     if spellLink then
        --         print(string.format("ID: %d -> %s", spellID, spellLink))
        --     else
        --         print(string.format("ID: %d -> |cffff0000未缓存或无效ID|r", spellID))
        --     end
        -- end


        local MEDIA_PATH = addonTable.GetMediaPath and addonTable.GetMediaPath() or ""
        local audioChannel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"
        
        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     addonTable.GenerateAllSpecsCodeBlock(unitTarget)
        -- end

        -- addonTable.CustomEncounterBar(132274, 10, "準備誘捕")

        -- ============================
        -- ==        毒牙祭坛        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 麻痹射击 -- 毒素吐息
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]

            if currentCount % 2 == 1 then
                if UnitGroupRolesAssigned("player") ~= "TANK" then
                    addonTable.CustomEncounterBar(132274, 24, "準備誘捕", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiYouBu.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end               
                -- 1.5秒后，如果是治疗则播放驱散魔法
                C_Timer.After(4.2, function()
                    if UnitGroupRolesAssigned("player") == "HEALER" and UnitExists(unitTarget) then                        
                        -- PlaySoundFile(MEDIA_PATH .. "QuSanMoFa.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end)
                
            else
                if not addonTable.DuoKaiTouQianLock then
                    addonTable.DuoKaiTouQianLock = true
                    addonTable.CustomEncounterBar(135798, 23.5, "躲開正面", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", audioChannel)
                    C_Timer.After(1.5, function() addonTable.DuoKaiTouQianLock = nil end)
                end
            end
            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 肢解 
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            and addonTable.SpellCastAudioTriggered == nil
            then
                addonTable.SpellCastAudioTriggered = true
                addonTable.CustomEncounterBar(132109, 23, "坦克尖刺", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function() addonTable.SpellCastAudioTriggered = nil end)
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 鲜血献祭
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget)
            then addonTable.CustomEncounterBar(132334, 23, "準備吸奶盾", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiXiNaiDun.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 腐蚀之牙
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(136067, 28, "坦克尖刺", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 振响
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) 
            then addonTable.CustomEncounterBar(6238561, 28, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 群体毒伤
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2589 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget)
            and addonTable.SpellCastCounter[unitTarget] == nil
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            then PlaySoundFile(MEDIA_PATH .. "QunTiZhongDu.ogg", DiGuaTimelineAudioHelper.audioChannel)
            addonTable.SpellCastCounter[unitTarget] = true
            C_Timer.After(7, function() if addonTable.SpellCastCounter[unitTarget] then addonTable.SpellCastCounter[unitTarget] = nil end end) end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 感染 -- 剧毒旋风
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget)
            then
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]

            if currentCount % 2 == 1 then
                addonTable.CustomEncounterBar(132211, 36, "準備小怪", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhunBeiXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
            else
                addonTable.CustomEncounterBar(5764921, 36.9, "注意躲圈", unitTarget)
                C_Timer.After(1.1, function() PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end)                
            end
            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 剧毒喷雾
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地图ID
            and IsIndoors() == true
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and UnitSpellTargetName(unitTarget) 
            then addonTable.CustomEncounterBar(5764918, 36.6, "坦克頭前", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 剧毒弹幕
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地图ID
            and addonTable.GetEncounterID() == 3457
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 2
            and UnitPowerType(unitTarget) == 3
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.JuDuWeiSuo == true
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then
                -- 计数 +1
                addonTable.JuDuWeiSuoCounter = (addonTable.JuDuWeiSuoCounter or 0) + 1
                -- 【调试】播放音频时打印当前计数
                -- print("[剧毒萎缩] 播放音频 | JuDuWeiSuoCounter=" .. tostring(addonTable.JuDuWeiSuoCounter))
                -- 按第几次播放对应音频：1→YiDaDuan，2→ErDaDuan，3→SanDaDuan
                if addonTable.JuDuWeiSuoCounter == 1 then
                    PlaySoundFile(MEDIA_PATH .. "YiDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                elseif addonTable.JuDuWeiSuoCounter == 2 then
                    PlaySoundFile(MEDIA_PATH .. "ErDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                elseif addonTable.JuDuWeiSuoCounter == 3 then
                    PlaySoundFile(MEDIA_PATH .. "SanDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    addonTable.JuDuWeiSuo = false
                end
                return
            end

        -- ============================
        -- ==      红玉新生法地      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毁灭猛击 -- 钢铁弹幕
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 采掘冲击
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then 
                C_Timer.After(0.1, function() 
                    if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then
                        addonTable.CustomEncounterBar(136025, 28, "準備AOE", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        C_Timer.After(3.3, function() 
                            if UnitExists(unitTarget) then
                                PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                            end
                        end)
                    end
                end)
            end

        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 炽焰冲锋
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellCastAudioTriggered == nil
            then C_Timer.After(0.1, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then addonTable.SpellCastAudioTriggered = true
            addonTable.CustomEncounterBar(237517, 21, "躲開衝鋒", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DuoKaiChongFeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(10, function() addonTable.SpellCastAudioTriggered = nil end) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 滚雷
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.CustomEncounterBar(136050, 35.2, "準備點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(1.4, function() if UnitExists(unitTarget) and UnitGroupRolesAssigned("player") == "HEALER" 
            then PlaySoundFile(MEDIA_PATH .. "QuSanMoFa.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雷霆颚咬 -- 火焰之喉 -- 风暴吐息 -- 烈焰吐息
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then
            if addonTable.SpellCastCounter[unitTarget] == nil then
                PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
                return
            end
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            if currentCount % 2 == 1 then
                if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                    PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end                
            else
                PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地狱烈火
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellCastAudioTriggered == nil
            then 
                C_Timer.After(0.2, function()
                    if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then
                        addonTable.CustomEncounterBar(460698, 25.5, "準備AOE", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)                    
                        addonTable.SpellCastAudioTriggered = true
                        C_Timer.After(25.5, function() addonTable.SpellCastAudioTriggered = nil end)
                    end
                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 燃尽
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.GetEncounterID() == 0
            then C_Timer.After(0.2, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "DuoKaiDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 烈焰狂轰
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.GetEncounterID() ~= 0
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then
            
            -- 【核心修正】每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            
            -- ==================== 3轮循环音效映射表 ====================
            local interruptSounds = {
                [1] = "YiDaDuan.ogg",   -- 1轮
                [2] = "ErDaDuan.ogg",   -- 2轮
                [0] = "SanDaDuan.ogg",  -- 3轮 (当 currentCount % 3 == 0 时)
            }
            
            -- 通过取模 3 计算当前属于 1, 2, 3 哪一轮
            local currentRound = currentCount % 3
            local soundFile = interruptSounds[currentRound]
            
            -- 播放对应的打斷提示音
            if soundFile then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雷霆冲击
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        
        -- ============================
        -- ==      塞塔里斯神庙      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 破甲猛击
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(132318, 21.9, "坦克尖刺", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 震地
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then 
                addonTable.CustomEncounterBar(132358, 31.5, "小心擊退", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "XiaoXinJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                C_Timer.After(1, function()
                    if UnitExists(unitTarget) then
                        -- print("⏱️ [倒计时] 目标仍在 -> 播放 3")
                        PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 3 声效路径
                        
                        -- 【再过1秒后检测 2】
                        C_Timer.After(1, function()
                            if UnitExists(unitTarget) then
                                -- print("⏱️ [倒计时] 目标仍在 -> 播放 2")
                                PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 2 声效路径
                                
                                -- 【再过1秒后检测 1】
                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        -- print("⏱️ [倒计时] 目标仍在 -> 播放 1")
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 1 声效路径
                                    else
                                        -- print("❌ [倒计时终止] 1秒检测前怪物已死亡/消失")
                                    end
                                end)
                            else
                                -- print("❌ [倒计时终止] 2秒检测前怪物已死亡/消失")
                            end
                        end)
                    else
                        -- print("❌ [倒计时终止] 3秒检测前怪物已死亡/消失")
                    end
                end)
            end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 风暴祝福 (工具)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 2
            and UnitPowerType(unitTarget) == 3
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黄沙冲刷 (砂誓骑兵)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then C_Timer.After(0.5, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then addonTable.SpellCastCounter[unitTarget] = true
            addonTable.CustomEncounterBar(796637, 21.8, "躲開正面", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 三叶虫群 (砂誓骑兵)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellCastCounter[unitTarget] == true
            then
                addonTable.CustomEncounterBar(2011146, 27.8, "召唤小怪", unitTarget)
                C_Timer.After(0.5, function()
                    if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then 
                        PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)   
                    end
                    C_Timer.After(2, function() 
                        if UnitExists(unitTarget) and UnitGroupRolesAssigned("player") == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end
                    end)
                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黄沙冲刷 (三叶虫主母)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.GetEncounterID() == 0
            then PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 风暴触媒 (风暴风蛇)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.GetEncounterID() ~= 0
            and addonTable.GetSpecPosition() == "MELEE" -- 仅近戰播报
            then PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 召唤闪电
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then C_Timer.After(1.3, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 释放电荷
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then C_Timer.After(1.6, function() if UnitExists(unitTarget) and not addonTable.SpellCastSuccessTriggered[unitTarget]
            then PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毒刃斩击
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(132287, 24, "坦克尖刺", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 蚀骨践踏
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then
                addonTable.CustomEncounterBar(5764923, 26.7, "準備AOE", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                C_Timer.After(0.5, function()
                    if UnitExists(unitTarget) then
                        -- print("⏱️ [倒计时] 目标仍在 -> 播放 3")
                        -- PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 3 声效路径
                        
                        -- 【再过1秒后检测 2】
                        C_Timer.After(1, function()
                            if UnitExists(unitTarget) then
                                -- print("⏱️ [倒计时] 目标仍在 -> 播放 2")
                                PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 2 声效路径
                                
                                -- 【再过1秒后检测 1】
                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        -- print("⏱️ [倒计时] 目标仍在 -> 播放 1")
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 1 声效路径
                                    else
                                        -- print("❌ [倒计时终止] 1秒检测前怪物已死亡/消失")
                                    end
                                end)
                            else
                                -- print("❌ [倒计时终止] 2秒检测前怪物已死亡/消失")
                            end
                        end)
                    else
                        -- print("❌ [倒计时终止] 3秒检测前怪物已死亡/消失")
                    end
                end)
            
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 潜藏妖术
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then C_Timer.After(2, function() if UnitExists(unitTarget)
            then PlaySoundFile(MEDIA_PATH .. "BaMaFenSan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            addonTable.CustomEncounterBar(7264184, 20.1, "八碼分散", unitTarget)
            end end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 撞头
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"            
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==     虚空之痕竞技场     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暗影箭雨
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            and addonTable.XuChuFaShi == false
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
            then PlaySoundFile(MEDIA_PATH .. "AnYingJianYu.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 虚无喷发
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.XuChuFaShi == false
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
            then addonTable.CustomEncounterBar(4914670, 19, "注意點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 瓦解宝珠 -- 雷鸣风暴
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.XuChuFaShi == true
            then
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]

            if currentCount % 2 == 1 then

                C_Timer.After(1.1, function() 
                    if UnitExists(unitTarget) then
                        addonTable.CustomEncounterBar(613397, 32.2, "轉火寶珠", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhuanHuoBaoZhu.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                    end
                end)
            else
                addonTable.CustomEncounterBar(237589, 32.1, "注意躲圈", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", audioChannel)
                C_Timer.After(2.8, function() 
                    if UnitExists(unitTarget) then                        
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                    end
                end)
            end
            
            return
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 凶猛飞跃
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then addonTable.CustomEncounterBar(236171, 33.2, "注意點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 勇士之矛
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.LuMangJianDuZhe == true
            then C_Timer.After(0.2, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "ZhunBeiLaRen.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 劈地者 -- 野蛮猛击
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then C_Timer.After(0.2, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end




        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 野性之怒 (工具)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狂暴之沙
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then C_Timer.After(1.2, function() if addonTable.SpellCastSuccessTriggered[unitTarget] == nil 
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end
            

 
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 粉碎冲锋
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.CustomEncounterBar(1127958, 22, "躲開衝鋒", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DuoKaiChongFeng.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 头槌重击
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(1127958, 23, "坦克擊退", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 疯狂尖啸
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanKongJu.ogg", DiGuaTimelineAudioHelper.audioChannel) return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 天空打击 -- 虚空光束
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.SpellCastSuccessTriggered[unitTarget] == nil
            then             
                addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
                local currentCount = addonTable.SpellCastCounter[unitTarget]                
                if currentCount % 2 == 1 then
                    addonTable.CustomEncounterBar(4622488, 25.6, "分攤傷害", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "FenTanShangHai.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    C_Timer.After(4.9, function() 
                        if UnitExists(unitTarget) then
                            PlaySoundFile(MEDIA_PATH .. "DuoKaiDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end
                    end)
                else
                    if UnitGroupRolesAssigned("player") ~= "TANK" then
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end         
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 撕碎切割
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.SpellCastSuccessTriggered[unitTarget] == true
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 恐惧咆哮
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2573 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then
                -- 该单位已开始施放"恐惧咆哮" -> 立即标记；只有被标记的单位，后续"残杀"播报才有资格触发
                addonTable.HasCastFearRoar[unitTarget] = true
                C_Timer.After(0.5, function()
                    if not UnitExists(unitTarget .. "target") then
                        addonTable.CustomEncounterBar(136185, 30.3, "準備擊退", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        C_Timer.After(1, function()
                            if UnitExists(unitTarget) then
                                -- print("⏱️ [倒计时] 目标仍在 -> 播放 3")
                                PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 3 声效路径
                                
                                -- 【再过1秒后检测 2】
                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        -- print("⏱️ [倒计时] 目标仍在 -> 播放 2")
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 2 声效路径
                                        
                                        -- 【再过1秒后检测 1】
                                        C_Timer.After(1, function()
                                            if UnitExists(unitTarget) then
                                                -- print("⏱️ [倒计时] 目标仍在 -> 播放 1")
                                                PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替换为你的 1 声效路径
                                            else
                                                -- print("❌ [倒计时终止] 1秒检测前怪物已死亡/消失")
                                            end
                                        end)
                                    else
                                        -- print("❌ [倒计时终止] 2秒检测前怪物已死亡/消失")
                                    end
                                end)
                            else
                                -- print("❌ [倒计时终止] 3秒检测前怪物已死亡/消失")
                            end
                        end)                        
                    end
                end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 残杀
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2573 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            and addonTable.HasCastFearRoar[unitTarget] == true -- 仅"施放过恐惧咆哮"的单位才播（防同特征怪误报）
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==        诸王之眠        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 压制猛击
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and not addonTable.SpellCastAudioTriggered
            then
                addonTable.CustomEncounterBar(132154, 24, "躲開正面", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                addonTable.SpellCastAudioTriggered = true
                C_Timer.After(1, function()
                    addonTable.SpellCastAudioTriggered = nil
                end) 
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暗影旋风斩
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitExists(unitTarget .. "target")
            then
                addonTable.CustomEncounterBar(2576091, 24, "準備AOE", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhuYiJiaoXia.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function()
                    if UnitExists(unitTarget) then
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end)            
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 先祖狂怒
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and not UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "JiNu.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 妖术齐射
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then addonTable.CustomEncounterBar(615099, 24, "打斷大怪", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 邪恶愈合
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓")
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术无目标  
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) return end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 过载
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 净化打击
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "荣耀亡者大厅" or GetSubZoneText() == "先王之堂") 
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and not UnitIsDeadOrGhost(unitTarget) -- 初始触发时必须存活
            then
            addonTable.CustomEncounterBar(451169, 11, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "zhunbeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
            
            C_Timer.After(8, function()
                -- 检测：目标存在 且 没有死亡
                if UnitExists(unitTarget) and not UnitIsDeadOrGhost(unitTarget) then
                    -- print("⏱️ [倒计时] 目标存活 -> 播放 3")
                    PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    
                    -- 【再过1秒后检测 2】
                    C_Timer.After(1, function()
                        if UnitExists(unitTarget) and not UnitIsDeadOrGhost(unitTarget) then
                            -- print("⏱️ [倒计时] 目标存活 -> 播放 2")
                            PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            
                            -- 【再过1秒后检测 1】
                            C_Timer.After(1, function()
                                if UnitExists(unitTarget) and not UnitIsDeadOrGhost(unitTarget) then
                                    -- print("⏱️ [倒计时] 目标存活 -> 播放 1")
                                    PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                else
                                    -- print("❌ [倒计时终止] 1秒检测前怪物已死亡/消失")
                                end
                            end)
                        else
                            -- print("❌ [倒计时终止] 2秒检测前怪物已死亡/消失")
                        end
                    end)
                else
                    -- print("❌ [倒计时终止] 3秒检测前怪物已死亡/消失")
                end
            end)
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 埋葬
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "不朽肉身密室" or GetSubZoneText() == "永存之室") 
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.GetEncounterID() == 0
            then addonTable.CustomEncounterBar(236399, 23.1, "準備救人", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiJiuRen.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 恶疾排放 (首领战)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.GetEncounterID() == 2142 -- 在首领战
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 妖术（工具）
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震岩层 -- 暴怒猛击
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and not addonTable.SpellCastAudioTriggered
            then
                PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                addonTable.SpellCastAudioTriggered = true
                C_Timer.After(1, function()
                    addonTable.SpellCastAudioTriggered = nil
                end) 
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震岩层（工具） -- 暴怒猛击（工具）
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黑暗启示
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == -1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.CustomEncounterBar(1022945, 22, "注意點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 灵魂碾压
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标           
            then 
                if addonTable.SpellCastCounter[unitTarget] == true then
                    if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                        addonTable.CustomEncounterBar(6035321, 20.3, "坦克尖刺", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                else
                    C_Timer.After(2.1, function()
                        if UnitExists(unitTarget) then
                            if addonTable.SpellCastSuccessTriggered[unitTarget] == nil then 
                                if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                                    addonTable.CustomEncounterBar(6035321, 24.3, "坦克尖刺", unitTarget)
                                    PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                end
                            end
                        end
                    end)
                end
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 嗜血飞斧
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then 
                C_Timer.After(2.1, function()
                    if addonTable.SpellCastSuccessTriggered[unitTarget] == true then
                        C_Timer.After(0.4, function()
                            if UnitExists(unitTarget) and addonTable.ShiXueFeiFuAudioLock == nil then
                                if UnitGroupRolesAssigned("player") == "HEALER" then
                                    addonTable.ShiXueFeiFuAudioLock = true
                                    addonTable.CustomEncounterBar(1033474, 17, "單刷流血", unitTarget)
                                    PlaySoundFile(MEDIA_PATH .. "DanShuaLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                    C_Timer.After(1, function() addonTable.ShiXueFeiFuAudioLock = nil end)
                                end
                            end
                        end)
                    end 
                end)
            end

        -- ============================
        -- ==         夺目谷         ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光箭雨
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            then PlaySoundFile(MEDIA_PATH .. "DaDuanJianYu.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地裂打击 -- 凶残创裂
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then addonTable.SpellCastCounter[unitTarget] = true                
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" 
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 炽阳吐息 -- 子弹种子
            and UnitCanAttack("player", unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) then
            C_Timer.After(0.5, function() if not UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) return end end) end
        

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光颚射线 (工具)
            and UnitCastingInfo(unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and not UnitCreatureFamily(unitTarget)
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and not UnitSpellTargetName(unitTarget) 
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 喷涌之花 -- 拔根而起 -- 光颚射线
            and UnitCastingInfo(unitTarget) -- 正在读条
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and not UnitCreatureFamily(unitTarget)
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and not UnitSpellTargetName(unitTarget)
            and (addonTable.SpellCastDuration[unitTarget] or 0) <= 1.75
            then 

            -- 所有前置条件通过，开启 0.5 秒延迟检测
            C_Timer.After(0.5, function()
                local targetUnit = unitTarget .. "target"
                local exists = UnitExists(targetUnit)
                
                if exists then
                    if addonTable.SpellCastCounter[unitTarget] == true then
                        addonTable.CustomEncounterBar(7291441, 33.9, "小心擊退", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "XiaoXinJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        C_Timer.After(0.5, function()
                            if UnitExists(unitTarget) then
                                PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)

                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                    else
                                    end
                                end)
                            else
                            end
                        end)
                        addonTable.SpellCastCounter[unitTarget] = nil
                    else
                        addonTable.CustomEncounterBar(132862, 32.1, "準備AOE", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end
            end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光颚射线 (工具) -- 喷射孢子 (工具)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 迷乱尖叫
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            and not addonTable.MiLuanJianJiaoLock -- 4 秒防抖锁
            then
                addonTable.MiLuanJianJiaoLock = true
                C_Timer.After(4, function() addonTable.MiLuanJianJiaoLock = nil end)
                C_Timer.After(0.5, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
                then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 吐舌攻击
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then                
                addonTable.SpellCastStartTime[unitTarget] = true
                if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                    addonTable.CustomEncounterBar(252175, 27.2, "坦克擊飛", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "TanKeJiFei.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 蛤蟆卵
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            and addonTable.SpellCastStartTime[unitTarget]
            then addonTable.CustomEncounterBar(236999, 27.9, "召唤小怪", unitTarget)
            C_Timer.After(0.1, function() PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end)
            addonTable.SpellCastStartTime[unitTarget] = nil return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 喷毒
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            and not addonTable.SpellCastStartTime[unitTarget]
            then addonTable.CustomEncounterBar(136016, 26.7, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) return end

        if unitTarget == "boss2" and UnitCanAttack("player", unitTarget) -- 光芒箭 (3199 Boss2)
            and addonTable.GetEncounterID() == 3199
            and UnitExists("focus") -- 有焦点才执行（UnitIsUnit 对 Boss 令牌在战斗中不可靠，改为判断“已设置焦点”）
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否为中尉
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") ~= "HEALER" -- 非治疗才播
            then
                -- 该 Boss 每次读条计一次数：奇数次播一断(YiDaDuan)，偶数次播二断(ErDaDuan)，循环往复
                local encID = addonTable.GetEncounterID()
                if addonTable.GuangMangJianEnc ~= encID then
                    -- 换 Boss / 重新开怪时清零，保证每场第一次读条都从"一断"开始
                    addonTable.GuangMangJianEnc = encID
                    addonTable.GuangMangJianCounter = 0
                end
                addonTable.GuangMangJianCounter = (addonTable.GuangMangJianCounter or 0) + 1
                if addonTable.GuangMangJianCounter % 2 == 1 then
                    PlaySoundFile(MEDIA_PATH .. "YiDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    PlaySoundFile(MEDIA_PATH .. "ErDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
                return
            end

        -- ============================
        -- ==        密谋小径        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 盾击 -- 飞刃
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            
            -- 使用 if-else 代替取反逻辑，清晰且高效
            if currentCount % 2 == 1 then
                -- addonTable.CustomEncounterBar(132330, 24, "坦克流血")
                -- PlaySoundFile(MEDIA_PATH .. "TanKeLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel)
            else
                addonTable.CustomEncounterBar(132357, 24, "坦克尖刺", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", audioChannel)
            end
            
            return
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 断心药膏
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") == "TANK"
            and addonTable.DuanXinYaoGaoLock == nil -- 2 秒防抖锁
            then
            addonTable.DuanXinYaoGaoLock = true
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiZhongDu.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(2, function() addonTable.DuanXinYaoGaoLock = nil end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 刃舞
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            and addonTable.PoHuaiMoChengFaZhe == 2
            and UnitIsLieutenant(unitTarget)
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then addonTable.CustomEncounterBar(1305149, 22.7, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) return end end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 旋风斩（老三前）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            and addonTable.PoHuaiMoChengFaZhe <= 1
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 旋风斩 -- 亵渎猛击（老三后）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 魔化狂乱
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "DaGuaiQiangHua.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

                
                -- PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end

                -- C_Timer.After(1.1, function() 
                --     if UnitExists(unitTarget) and addonTable.SpellCastSuccessTriggered[unitTarget] == nil then 
                        
                --     else
                --         PlaySoundFile(MEDIA_PATH .. "DaGuaiQiangHua.ogg", DiGuaTimelineAudioHelper.audioChannel)
                --     end
                -- end)

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 吸取生命 -- 厄运诅咒（工具）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then
                addonTable.SpellCastStartTime[unitTarget] = GetTime()
                C_Timer.After(0.6, function() 
                    if addonTable.IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                        -- addonTable.StartCircleTimerBySeconds(1.4)
                        if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                            PlaySoundFile(MEDIA_PATH .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        else
                            PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end
                    end
                end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 眼棱
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitIsLieutenant(unitTarget)
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiSheXian.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==     纳洛拉克的洞穴     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 饥荒雕像 -- 苦难盛宴
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            if currentCount % 2 == 1 then
                C_Timer.After(1.6, function() 
                    if UnitExists(unitTarget) and UnitGroupRolesAssigned("player") ~= "HEALER" then
                        addonTable.CustomEncounterBar(2101983, 24.2, "轉火圖騰", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhuanHuoTuTeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end)       
            else
                addonTable.CustomEncounterBar(3154546, 25.5, "準備AOE", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", audioChannel)
            end            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 治疗之风（老一前）
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否为中尉
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 治疗之风（老二前）
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and GetSubZoneText() == "迫近风暴" -- 子区域 (迫近风暴)
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否为中尉
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 冰冷咆哮
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 冰川之墓
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then C_Timer.After(0.5, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then addonTable.CustomEncounterBar(236209, 18, "準備定身", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiDingShen.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 粉碎
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then C_Timer.After(0.5, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target")
            then addonTable.CustomEncounterBar(132318, 28.7, "近戰大圈", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 原始回响 (工具) -- 毒矛乱射 (工具)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 原始回响
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellCastSuccessTriggered[unitTarget] == nil
            then addonTable.CustomEncounterBar(463283, 23.1, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毒矛乱射
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellCastSuccessTriggered[unitTarget] == true
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end
            -- addonTable.CustomEncounterBar(135125, 21.8, "注意躲圈", unitTarget)



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 电弧
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否为中尉
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then
                -- 2.6 秒后复核：单位仍存在、仍在施法中、且施法尚未成功 → 才提示打斷小怪
                C_Timer.After(2.6, function()
                    if UnitExists(unitTarget) and UnitCastingInfo(unitTarget) and addonTable.SpellCastSuccessTriggered[unitTarget] == nil then
                        PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震术 -- 动荡圖騰
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then
            addonTable.SpellCastStartTime[unitTarget] = GetTime()
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            
            -- 通过取模 3 计算当前属于 1, 2, 0(3) 哪一轮
            local currentRound = currentCount % 3
            
            -- 1 和 3(即模为0) 轮播放 BaMaFenSan.ogg，2 轮播放 ZhaoHuanXiaoGuai.ogg
            if currentRound == 1 or currentRound == 0 then
                addonTable.CustomEncounterBar(451165, 15.8, "注意點名", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
            elseif currentRound == 2 then
                addonTable.CustomEncounterBar(135829, 32, "準備小怪", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhunBeiXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end
            
            return
            end

        -- ============================
        -- ==        烈毒之渊        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 风暴
            and select(8, GetInstanceInfo()) == 3004 -- 副本ID (烈毒之渊)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2609 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == -1 -- 怪物等级: -1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.GetEncounterID() == 3420
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end
    end
end)



