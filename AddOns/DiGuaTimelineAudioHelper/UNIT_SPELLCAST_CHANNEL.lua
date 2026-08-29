-- UNIT_SPELLCAST_CHANNEL.lua
-- 处理怪物引导事件的独立分支
local addonName, addonTable = ...

-- 注册事件监听的框架层代码（供主文件参考或直接使用）
local frame = CreateFrame("Frame")
addonTable.SpellChannelStart = addonTable.SpellChannelStart or {}
addonTable.SpellChannelCounter = addonTable.SpellChannelCounter or {}
-- addonTable.UNIT_SPELLCAST_CHANNEL_STOP_Triggered = addonTable.UNIT_SPELLCAST_CHANNEL_STOP_Triggered or {}
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unitTarget = ...

        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     addonTable.GenerateAllSpecsCodeBlock(unitTarget)
        -- end
        -- ============================
        -- ==        毒牙祭坛        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毒素吐息 (重置计数)
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and not UnitSpellTargetName(unitTarget) then
            -- 确保全局计数器表已经初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕获旧计数并直接将该目标的计数重置为 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [计数重置] 目标: " .. unitTarget .. " | 开启新引导，清空前计数: " .. previousCount .. " -> 当前已归零")
            
            return end
        
        
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
            and not UnitSpellTargetName(unitTarget) then
            PlaySoundFile(addonTable.GetMediaPath() .. "AOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 进化
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2589 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            addonTable.SpellChannelStart[unitTarget] = GetTime() end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 剧毒喷雾 (重置计数)
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
            and UnitSpellTargetName(unitTarget) then
            -- 确保全局计数器表已经初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕获旧计数并直接将该目标的计数重置为 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [计数重置] 目标: " .. unitTarget .. " | 开启新引导，清空前计数: " .. previousCount .. " -> 当前已归零")
            
            return end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 剧毒涌动
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget)
            then addonTable.CustomEncounterBar(5764925, 23.1, "注意射线", unitTarget)
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiSheXian.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        -- ============================
        -- ==      红玉新生法地      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 钢铁弹幕
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.SpellChannelCounter[unitTarget] == nil
            then addonTable.CustomEncounterBar(535414, 20, "注意躲圈", unitTarget)
            addonTable.SpellChannelCounter[unitTarget] = true
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(10, function() addonTable.SpellChannelCounter[unitTarget] = nil end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 寒冰壁垒
            and not UnitExists("focus")
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end
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
            -- 确保全局计数器表已经初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕获旧计数并直接将该目标的计数重置为 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [计数重置] 目标: " .. unitTarget .. " | 开启新引导，清空前计数: " .. previousCount .. " -> 当前已归零")
            
            return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 燃焰弹幕
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellChannelCounter[unitTarget] == nil
            then addonTable.SpellChannelCounter[unitTarget] = true
            PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            C_Timer.After(26, function() addonTable.SpellChannelCounter[unitTarget] = nil end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 闪电涌流 (大引导者莱瓦迪)
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then 
                C_Timer.After(0.3, function() 
                    -- addonTable.StartCircleTimerBySeconds(4)

                if addonTable.IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true
                then
                    if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                        PlaySoundFile(addonTable.GetMediaPath() .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    else
                        PlaySoundFile(addonTable.GetMediaPath() .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end 
                end                   

                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 闪电涌流 (暴风引导者)
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget)
            then 
                C_Timer.After(0.3, function() 
                    -- addonTable.StartCircleTimerBySeconds(4)

                    if addonTable.IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true
                    then
                        if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                            PlaySoundFile(addonTable.GetMediaPath() .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        else
                            PlaySoundFile(addonTable.GetMediaPath() .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end 
                    end  
                end)
            end
        -- ============================
        -- ==     虚空之痕竞技场     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 虚空光束 -- 虚空光束 (工具)
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
            then
            -- 确保全局计数器表已经初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕获旧计数并直接将该目标的计数重置为 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0

            if addonTable.IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true
            then
                -- addonTable.StartCircleTimerBySeconds(4)
                if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                    PlaySoundFile(addonTable.GetMediaPath() .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    PlaySoundFile(addonTable.GetMediaPath() .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end 
            end

            -- print("🧹 [计数重置] 目标: " .. unitTarget .. " | 开启新引导，清空前计数: " .. previousCount .. " -> 当前已归零")
            
            return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 钉锤风暴 -- 残暴猛击
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2572 or (C_Map.GetBestMapForUnit("player") or 0) == 2573 or (C_Map.GetBestMapForUnit("player") or 0) == 2574)
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then
            -- 【核心修正】在这里统一累加，每次施法事件触发且满足条件，必然且只累加 1 次
            addonTable.SpellChannelStart[unitTarget] = (addonTable.SpellChannelStart[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellChannelStart[unitTarget]

            if currentCount % 2 == 1 then
                -- PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
            else
                -- PlaySoundFile(addonTable.GetMediaPath() .. "JianRenFengBao.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end            
            return
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雷鸣风暴 (工具)
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
            -- 确保全局计数器表已经初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕获旧计数并直接将该目标的计数重置为 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [计数重置] 目标: " .. unitTarget .. " | 开启新引导，清空前计数: " .. previousCount .. " -> 当前已归零")
            
            return end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 险恶光环
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.CustomEncounterBar(840194, 20.6, "准备AOE", unitTarget)
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 甲壳守护
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKaiQi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==        诸王之眠        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 警戒防卫
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(addonTable.GetMediaPath() .. "BeiMianKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暗影箭雨 -- 剑刃风暴
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoBi.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狩猎跃击 (骸骨狩猎迅猛龙)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.ShouLieYueJiAudioLock == nil
            then
                addonTable.ShouLieYueJiAudioLock = true
                PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function() addonTable.ShouLieYueJiAudioLock = nil end)
                return
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狩猎跃击
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狩猎跃击 (荣耀迅猛龙)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.ShouLieYueJiAudioLock == nil
            then
                addonTable.ShouLieYueJiAudioLock = true
                PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function() addonTable.ShouLieYueJiAudioLock = nil end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 哀痛恸哭
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
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiJiuRen.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黑暗之池
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
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then addonTable.CustomEncounterBar(1386548, 23, "注意踩圈", unitTarget)
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiCaiQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        -- ============================
        -- ==         夺目谷         ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光颚射线
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and addonTable.SpellCastStartTime[unitTarget]
            then addonTable.SpellCastDuration[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
                -- print(addonTable.SpellCastDuration[unitTarget])
            if (addonTable.SpellCastDuration[unitTarget] or 0) > 1.75 then 
                addonTable.SpellCastStartTime[unitTarget] = nil
                addonTable.CustomEncounterBar(5764902, 26.7, "五码分散", unitTarget)
                if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                    PlaySoundFile(addonTable.GetMediaPath() .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    PlaySoundFile(addonTable.GetMediaPath() .. "WuMaFenSan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end 
            end
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 喷射孢子
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and addonTable.SpellCastStartTime[unitTarget]
            then
                addonTable.CustomEncounterBar(136016, 31.6, "注意躲圈", unitTarget)
                addonTable.SpellCastDuration[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
                -- print(addonTable.SpellCastDuration[unitTarget])
                if addonTable.SpellCastDuration[unitTarget] <= 1.75 then
                    PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
            end



        -- ============================
        -- ==     纳洛拉克的洞穴     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 苦难盛宴 (工具)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) 
            -- 确保全局计数器表已经初始化
            then addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕获旧计数并直接将该目标的计数重置为 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [计数重置] 目标: " .. unitTarget .. " | 开启新引导，清空前计数: " .. previousCount .. " -> 当前已归零")
            
            return end
        -- ============================
        -- ==      塞塔里斯神庙      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 箭雨
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 净化瓦解
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then PlaySoundFile(addonTable.GetMediaPath() .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        -- ============================
        -- ==        密谋小径        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 召唤浮龙
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            then addonTable.CustomEncounterBar(7301939, 24.4, "召唤小怪", unitTarget)
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unitTarget = ...

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 进化
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2589 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and addonTable.SpellChannelStart[unitTarget] -- 确保存在开始时间记录
            then 
                local duration = GetTime() - addonTable.SpellChannelStart[unitTarget]
                if duration > 5.9 then
                    PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
                addonTable.SpellChannelStart[unitTarget] = nil
            end

        
    end

end)