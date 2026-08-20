-- UNIT_SPELLCAST_SUCCEEDED.lua
-- 处理怪物施法成功事件的独立分支

local addonName, addonTable = ...

-- 注册事件监听的框架层代码（供主文件参考或直接使用）
local frame = CreateFrame("Frame")
addonTable.SpellCastSuccessTriggered = addonTable.SpellCastSuccessTriggered or {}

frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget = ...

        local MEDIA_PATH = addonTable.GetMediaPath and addonTable.GetMediaPath() or ""
        local audioChannel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"

        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 喷涌之花 -- 拔根而起 -- 光颚射线
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and not UnitCreatureFamily(unitTarget)
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and not UnitSpellTargetName(unitTarget)
            then 
                -- 确保时间表已初始化，且该单位有记录起始时间
                local startTime = addonTable.SpellCastStartTime and addonTable.SpellCastStartTime[unitTarget]

                if startTime then
                    addonTable.SpellCastDuration[unitTarget] = GetTime() - startTime
                    if addonTable.SpellCastDuration[unitTarget] >= 2.5 then
                        addonTable.SpellCastDuration[unitTarget] = nil
                    end
                end
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 野性之怒
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            -- 确保之前确实有开始时间的记录
            and addonTable.SpellCastStartTime[unitTarget] 
            then
            -- 1. 计算出最终的施法总耗时并覆盖原变量
            addonTable.SpellCastStartTime[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
            
            local duration = addonTable.SpellCastStartTime[unitTarget]
            -- print(string.format("⏱️ [施法成功] 实际施法时间为: %.2f 秒", duration))

            -- 2. 核心判定：如果实际耗时小于 1.1 秒，则执行播放逻辑
            if duration < 1.1 then
                -- print("🚨 施法耗时小于 1.1 秒 -> 播放激怒语音")
                PlaySoundFile(MEDIA_PATH .. "JiNu.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end

            -- 3. 清理该目标的临时耗时数据，防止因其他非判定内的施法成功事件导致错误计算
            addonTable.SpellCastStartTime[unitTarget] = nil
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狂暴之沙 (工具)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastSuccessTriggered[unitTarget] = true -- 标记施法成功事件触发
            C_Timer.After(4, function() addonTable.SpellCastSuccessTriggered[unitTarget] = nil end) end -- 4秒后清除标记
            
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 腐蚀唾液
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法术有目标
            and UnitGroupRolesAssigned("player") == "HEALER"
            then addonTable.CustomEncounterBar(132887, 6.5, "驱散魔法")
            PlaySoundFile(MEDIA_PATH .. "QuSanMoFa.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 厄运诅咒
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
                addonTable.SpellCastStartTime[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
                if addonTable.SpellCastStartTime[unitTarget] <= 1.6 then
                    -- 播放前检查职业：德鲁伊、唤魔师、法师、萨满
                    local class = UnitClassBase("player")
                    if class == "DRUID" or class == "EVOKER" or class == "MAGE" or class == "SHAMAN" then
                        addonTable.CustomEncounterBar(136122, 25.5, "驱散诅咒")
                        PlaySoundFile(MEDIA_PATH .. "QuSanZuZhou.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 风暴祝福
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 2
            and UnitPowerType(unitTarget) == 3
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then 
                -- 确保时间表已初始化，且该单位有记录起始时间
                local startTime = addonTable.SpellCastStartTime and addonTable.SpellCastStartTime[unitTarget]

                if startTime then
                    addonTable.SpellCastDuration[unitTarget] = GetTime() - startTime
                    if addonTable.SpellCastDuration[unitTarget] >= 2.4 and addonTable.SpellCastDuration[unitTarget] <= 2.6 then
                        PlaySoundFile(MEDIA_PATH .. "MuBiaoZhuanHuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 嗜血飞斧 (工具) -- 灵魂碾压 (工具)
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
            and UnitSpellTargetName(unitTarget) -- 法术没目标
            then addonTable.SpellCastSuccessTriggered[unitTarget] = true -- 标记施法成功事件触发
            C_Timer.After(0.5, function() addonTable.SpellCastSuccessTriggered[unitTarget] = nil end) end -- 0.5秒后清除标记
        
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
            then 
                -- 确保时间表已初始化，且该单位有记录起始时间
                local startTime = addonTable.SpellCastStartTime and addonTable.SpellCastStartTime[unitTarget]

                if startTime then
                    addonTable.SpellCastDuration[unitTarget] = GetTime() - startTime
                    if addonTable.SpellCastDuration[unitTarget] >= 4.9 and addonTable.SpellCastDuration[unitTarget] <= 5.1 then
                        addonTable.SpellCastCounter[unitTarget] = true
                    end
                end
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 释放电荷 (工具)
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
            then addonTable.SpellCastSuccessTriggered[unitTarget] = true -- 标记施法成功事件触发
            C_Timer.After(0.5, function() addonTable.SpellCastSuccessTriggered[unitTarget] = nil end) end -- 0.5秒后清除标记
        
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
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 回去干活!
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2435 -- 地图ID
            and IsIndoors() == true -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术没目标
            then PlaySoundFile(MEDIA_PATH .. "JiNu.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        
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
            then 
                addonTable.SpellCastStartTime[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
                if addonTable.SpellCastStartTime[unitTarget] >= 2.5 then
                    addonTable.SpellCastSuccessTriggered[unitTarget] = true
                else
                    addonTable.SpellCastSuccessTriggered[unitTarget] = nil
                end
                return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震术 (工具) -- 动荡图腾 (工具)
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
            -- 确保之前确实有开始时间的记录
            and addonTable.SpellCastStartTime[unitTarget] 
            then
            -- 1. 计算出最终的施法总耗时并覆盖原变量
            addonTable.SpellCastStartTime[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
            
            local duration = addonTable.SpellCastStartTime[unitTarget]
            -- print(string.format("⏱️ [施法成功] 实际施法时间为: %.2f 秒", duration))

            -- 2. 核心判定：如果实际耗时小于 3.5 秒，则执行播放逻辑
            if duration < 3.5 then
                -- PlaySoundFile(MEDIA_PATH .. "ZhuanHuoTuTeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1.5, function() PlaySoundFile(MEDIA_PATH .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel) end)
            end

            -- 3. 清理该目标的临时耗时数据，防止因其他非判定内的施法成功事件导致错误计算
            addonTable.SpellCastStartTime[unitTarget] = nil
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 腐蚀精华 (工具)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法术无目标
            then addonTable.SpellCastSuccessTriggered[unitTarget] = true end
    end
end)