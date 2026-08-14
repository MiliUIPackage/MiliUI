-- UNIT_SPELLCAST_CHANNEL.lua
-- 处理怪物引导事件的独立分支
local addonName, addonTable = ...

-- 注册事件监听的框架层代码（供主文件参考或直接使用）
local frame = CreateFrame("Frame")
addonTable.SpellChannelStart = addonTable.SpellChannelStart or {}
addonTable.SpellChannelCounter = addonTable.SpellChannelCounter or {}
-- addonTable.UNIT_SPELLCAST_CHANNEL_STOP_Triggered = addonTable.UNIT_SPELLCAST_CHANNEL_STOP_Triggered or {}
local function GenerateAllSpecsCodeBlock(unitTarget)
    if not UnitExists(unitTarget) then return end
    
    local spellName, _, _, _, _, _, _, _, spellID = UnitCastingInfo(unitTarget)
    if not spellName then
        spellName, _, _, _, _, _, _, _, spellID = UnitChannelInfo(unitTarget)
    end
    spellName = spellName or "未知法术"
    local spellComment = spellName .. (spellID and (" (" .. spellID .. ")") or "")

    C_Timer.After(0.5, function()
        if not UnitExists(unitTarget) then print("❌ [错误] 0.5秒后怪物血条已消失") return end

        print("🎯 [开始抓取快照] 技能 => " .. spellComment)
        print("--------------------------------------------------")

        local canAttack = UnitCanAttack("player", unitTarget)
        print(" -> 是否可攻击:", canAttack)

        local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        print(" -> 当前地图ID:", currentMapID)

        local subZoneText = GetSubZoneText() or ""
        print(" -> 当前子区域名字:", subZoneText ~= "" and subZoneText or "无")

        local name = UnitName(unitTarget) or "未知"
        print(" -> 怪物名字:", name)

        local actualLevel = UnitLevel(unitTarget) or 0
        print(" -> 实际等级:", actualLevel)

        local classification = UnitClassification(unitTarget) or "normal"
        print(" -> 分类(精英/普通):", classification)

        local unitPowerType = UnitPowerType(unitTarget) or 0   
        print(" -> 能量类型代码:", unitPowerType)

        -- local sex = UnitSex(unitTarget) or 1
        -- print(" -> 性别代码:", sex)

        local isInside = IsIndoors()
        print(" -> 是否在室内:", isInside)

        -- -- 严格获取大写英文职业名
        -- local className = select(2, UnitClass(unitTarget)) or "NONE"
        -- print(" -> 职业名称:", className)

        -- local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 1, "HELPFUL") 
        -- print(" -> 1号位增益光环(SpellID):", auraData and auraData.spellId or "无")

        local inCombat = UnitAffectingCombat(unitTarget)
        print(" -> 是否在战斗中:", inCombat)

        local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo() or 0
        print(" -> 大秘境层数:", keyLevel)

        local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
        creatureFamily = creatureFamily or "无"
        print(" -> 生物家族:", creatureFamily, "(家族ID:", familyID or "nil", ")")

        local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        local stepName = (type(stepInfo) == "table" and stepInfo.title) or "无"
        print(" -> 战役步骤名称:", stepName)

        local actualValue, percentValue, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues("target")
        print(" -> 战役条件进度(数值/百分比/文本):", actualValue, percentValue, percentValueString)

        local currentPercentText = GetTrashProgressString and GetTrashProgressString() or "0%"
        print(" -> 当前小怪进度%:", currentPercentText)

        local hasTarget = UnitExists(unitTarget .. "target")
        print(" -> 目标是否存在(是否有目标):", hasTarget)

        local rawTargetName = UnitSpellTargetName(unitTarget) 
        print(" -> 法术指向目标名字:", rawTargetName)

        local targetRole = UnitGroupRolesAssigned(unitTarget .. "target") or "NONE"
        print(" -> 目标职责(TANK/HEALER/DAMAGER):", targetRole)

        local instName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        instanceID = instanceID or 0
        print(" -> 副本信息(副本名/ID):", instName, instanceID)

        local boss1Kill = C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false   
        local boss2Kill = C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false
        local boss3Kill = C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false 
        local boss4Kill = C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false
        print(" -> Boss击杀状态(1-4号):", boss1Kill, boss2Kill, boss3Kill, boss4Kill)

        print("--------------------------------------------------")

        -- 计算战斗文本注释
        local combatComment = inCombat and "在战斗中" or "不在战斗中"
        
        -- 计算室内文本注释
        local indoorComment = isInside and "在室内" or "在室外"

        -- 计算性别文本注释
        local sexComment = "无性别"
        if sex == 2 then sexComment = "男性" elseif sex == 3 then sexComment = "女性" end

        -- 计算分类注释
        local classifcationComment = "普通怪"
        if classification == "elite" then classifcationComment = "精英怪"
        elseif classification == "rare" then classifcationComment = "稀有怪"
        elseif classification == "rareelite" then classifcationComment = "稀有精英"
        elseif classification == "worldboss" then classifcationComment = "世界Boss" end

        -- 动态匹配客户端常量等级字符串
        local levelCodeStr = tostring(actualLevel)
        if actualLevel == 90 then
            levelCodeStr = "PLAYER_LEVEL"
        elseif actualLevel == 91 then
            levelCodeStr = "NEXT_PLAYER_LEVEL"
        elseif actualLevel == 92 then
            levelCodeStr = "BOSS_LEVEL"
        elseif actualLevel == -1 then
            levelCodeStr = "-1"
        end

        local spellTargetCodeStr = rawTargetName and "            and UnitSpellTargetName(unitTarget) -- 法术有目标" or "            and not UnitSpellTargetName(unitTarget) -- 法术没目标"
        local hasTargetStr = hasTarget and "UnitExists(unitTarget .. \"target\")" or "not UnitExists(unitTarget .. \"target\")"
        -- local roleCheckStr = (hasTarget and targetRole ~= "NONE") and (" and UnitGroupRolesAssigned(unitTarget .. \"target\") == \"" .. targetRole .. "\"") or ""

        -- 建立生物家族的判定行
        local familyCodeStr = familyID and "            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族" or "            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族"

        -- 纯净版运行代码块生成
        print("        if unitTarget and unitTarget:find(\"nameplate\") and UnitCanAttack(\"player\", unitTarget)")
        print("            and select(8, GetInstanceInfo()) == " .. instanceID .. " -- 副本ID (" .. (instName or "未知") .. ")")
        print("            and (C_Map.GetBestMapForUnit(\"player\") or 0) == " .. currentMapID .. " -- 地图ID")
        if subZoneText ~= "" then
            print("            and GetSubZoneText() == \"" .. subZoneText .. "\" -- 子区域 (" .. subZoneText .. ")")
        end
        print("            and IsIndoors() == " .. tostring(isInside) .. " -- " .. indoorComment)
        print("            and UnitLevel(unitTarget) == " .. levelCodeStr .. " -- 怪物等级: " .. actualLevel)
        print("            and UnitPowerType(unitTarget) == " .. unitPowerType)
        -- print("            and UnitSex(unitTarget) == " .. sex .. " -- " .. sexComment)
        print("            and UnitClassification(unitTarget) == \"" .. classification .. "\" -- " .. classifcationComment)
        print("            and UnitAffectingCombat(unitTarget) == " .. tostring(inCombat) .. " -- " .. combatComment)
        
        -- 生成代码块时，严格输出大写英文键，不夹带任何本地化文本
        -- if className ~= "NONE" then
        --     print("            and select(2, UnitClass(unitTarget)) == \"" .. className .. "\"")
        -- end

        -- 动态生成生物家族代码行
        print(familyCodeStr)
        
        -- 4个Boss击杀状态判定条件生成
        print("            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == " .. tostring(boss1Kill) .. " -- Boss1")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == " .. tostring(boss2Kill) .. " -- Boss2")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == " .. tostring(boss3Kill) .. " -- Boss3")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == " .. tostring(boss4Kill) .. " -- Boss4")

        print(spellTargetCodeStr)
        print("        then")
        print("            C_Timer.After(0.5, function()")
        -- print("                if UnitExists(unitTarget) and " .. hasTargetStr .. roleCheckStr .. " then")
        print("                    PlaySoundFile(MEDIA_PATH .. \"音频文件名.ogg\", DiGuaTimelineAudioHelper.audioChannel)")
        print("                end")
        print("            end)")
        print("        end")
    end)
end
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unitTarget = ...

        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     GenerateAllSpecsCodeBlock(unitTarget)
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


            -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 鲜血献祭
            -- and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            -- and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            -- and IsIndoors() == false -- 在室外
            -- and UnitLevel(unitTarget) == UnitLevel("player") + 1
            -- and UnitPowerType(unitTarget) == 1
            -- and UnitClassification(unitTarget) == "elite" -- 精英怪
            -- and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            -- and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            -- and not UnitSpellTargetName(unitTarget) then
            -- PlaySoundFile(addonTable.GetMediaPath() .. "XiNaiDun.ogg", DiGuaTimelineAudioHelper.audioChannel) end

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
            and not UnitSpellTargetName(unitTarget) then
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
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 寒冰壁垒
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
                PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
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
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end

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
            then PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) return end
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
            then PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end


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
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiCaiQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end
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
            and addonTable.SpellCastStartTime[unitTarget]
            then 
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
            then
            if addonTable.IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true
            then
                if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                    PlaySoundFile(addonTable.GetMediaPath() .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    PlaySoundFile(addonTable.GetMediaPath() .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end 
            end            
            return end


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
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 亵渎猛击 -- 邪能光束???
        --     and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
        --     and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
        --     and IsIndoors() == false -- 是否在室内
        --     and UnitLevel(unitTarget) == UnitLevel("player") + 1
        --     and UnitPowerType(unitTarget) == 1
        --     and UnitAffectingCombat(unitTarget) == true
        --     and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
        --     and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        --     and not UnitSpellTargetName(unitTarget) -- 法术没目标
        --     then
        --     addonTable.SpellChannelCounter[unitTarget] = (addonTable.SpellChannelCounter[unitTarget] or 0) + 1
        --     local currentCount = addonTable.SpellChannelCounter[unitTarget]
        --     if currentCount % 2 == 1 then
        --         PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiJiaoXia.ogg", DiGuaTimelineAudioHelper.audioChannel)
        --     end
        --     return
        --     end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 刃舞
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
            then PlaySoundFile(addonTable.GetMediaPath() .. "AOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end




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