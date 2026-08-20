-- UNIT_SPELLCAST_CHANNEL.lua
-- 處理怪物引導事件的獨立分支
local addonName, addonTable = ...

-- 注冊事件監聽的框架層代碼（供主文件參考或直接使用）
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
    spellName = spellName or "未知法術"
    local spellComment = spellName .. (spellID and (" (" .. spellID .. ")") or "")

    C_Timer.After(0.5, function()
        if not UnitExists(unitTarget) then print("❌ [錯誤] 0.5秒後怪物血條已消失") return end

        print("🎯 [開始抓取快照] 技能 => " .. spellComment)
        print("--------------------------------------------------")

        local canAttack = UnitCanAttack("player", unitTarget)
        print(" -> 是否可攻擊:", canAttack)

        local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        print(" -> 當前地圖ID:", currentMapID)

        local subZoneText = GetSubZoneText() or ""
        print(" -> 當前子區域名字:", subZoneText ~= "" and subZoneText or "無")

        local name = UnitName(unitTarget) or "未知"
        print(" -> 怪物名字:", name)

        local actualLevel = UnitLevel(unitTarget) or 0
        print(" -> 實際等級:", actualLevel)

        local classification = UnitClassification(unitTarget) or "normal"
        print(" -> 分類(精英/普通):", classification)

        local unitPowerType = UnitPowerType(unitTarget) or 0   
        print(" -> 能量類型代碼:", unitPowerType)

        -- local sex = UnitSex(unitTarget) or 1
        -- print(" -> 性別代碼:", sex)

        local isInside = IsIndoors()
        print(" -> 是否在室內:", isInside)

        -- -- 嚴格獲取大寫英文職業名
        -- local className = select(2, UnitClass(unitTarget)) or "NONE"
        -- print(" -> 職業名稱:", className)

        -- local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 1, "HELPFUL") 
        -- print(" -> 1號位增益光環(SpellID):", auraData and auraData.spellId or "無")

        local inCombat = UnitAffectingCombat(unitTarget)
        print(" -> 是否在戰斗中:", inCombat)

        local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo() or 0
        print(" -> 大秘境層數:", keyLevel)

        local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
        creatureFamily = creatureFamily or "無"
        print(" -> 生物家族:", creatureFamily, "(家族ID:", familyID or "nil", ")")

        local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        local stepName = (type(stepInfo) == "table" and stepInfo.title) or "無"
        print(" -> 戰役步驟名稱:", stepName)

        local actualValue, percentValue, percentValueString = C_ScenarioInfo.GetUnitCriteriaProgressValues("target")
        print(" -> 戰役條件進度(數值/百分比/文本):", actualValue, percentValue, percentValueString)

        local currentPercentText = GetTrashProgressString and GetTrashProgressString() or "0%"
        print(" -> 當前小怪進度%:", currentPercentText)

        local hasTarget = UnitExists(unitTarget .. "target")
        print(" -> 目標是否存在(是否有目標):", hasTarget)

        local rawTargetName = UnitSpellTargetName(unitTarget) 
        print(" -> 法術指向目標名字:", rawTargetName)

        local targetRole = UnitGroupRolesAssigned(unitTarget .. "target") or "NONE"
        print(" -> 目標職責(TANK/HEALER/DAMAGER):", targetRole)

        local instName, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        instanceID = instanceID or 0
        print(" -> 副本信息(副本名/ID):", instName, instanceID)

        local boss1Kill = C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false   
        local boss2Kill = C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false
        local boss3Kill = C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false 
        local boss4Kill = C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false
        print(" -> Boss擊殺狀態(1-4號):", boss1Kill, boss2Kill, boss3Kill, boss4Kill)

        print("--------------------------------------------------")

        -- 計算戰斗文本注釋
        local combatComment = inCombat and "在戰斗中" or "不在戰斗中"
        
        -- 計算室內文本注釋
        local indoorComment = isInside and "在室內" or "在室外"

        -- 計算性別文本注釋
        local sexComment = "無性別"
        if sex == 2 then sexComment = "男性" elseif sex == 3 then sexComment = "女性" end

        -- 計算分類注釋
        local classifcationComment = "普通怪"
        if classification == "elite" then classifcationComment = "精英怪"
        elseif classification == "rare" then classifcationComment = "稀有怪"
        elseif classification == "rareelite" then classifcationComment = "稀有精英"
        elseif classification == "worldboss" then classifcationComment = "世界Boss" end

        -- 動態匹配客戶端常量等級字符串
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

        local spellTargetCodeStr = rawTargetName and "            and UnitSpellTargetName(unitTarget) -- 法術有目標" or "            and not UnitSpellTargetName(unitTarget) -- 法術沒目標"
        local hasTargetStr = hasTarget and "UnitExists(unitTarget .. \"target\")" or "not UnitExists(unitTarget .. \"target\")"
        -- local roleCheckStr = (hasTarget and targetRole ~= "NONE") and (" and UnitGroupRolesAssigned(unitTarget .. \"target\") == \"" .. targetRole .. "\"") or ""

        -- 建立生物家族的判定行
        local familyCodeStr = familyID and "            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族" or "            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族"

        -- 純淨版運行代碼塊生成
        print("        if unitTarget and unitTarget:find(\"nameplate\") and UnitCanAttack(\"player\", unitTarget)")
        print("            and select(8, GetInstanceInfo()) == " .. instanceID .. " -- 副本ID (" .. (instName or "未知") .. ")")
        print("            and (C_Map.GetBestMapForUnit(\"player\") or 0) == " .. currentMapID .. " -- 地圖ID")
        if subZoneText ~= "" then
            print("            and GetSubZoneText() == \"" .. subZoneText .. "\" -- 子區域 (" .. subZoneText .. ")")
        end
        print("            and IsIndoors() == " .. tostring(isInside) .. " -- " .. indoorComment)
        print("            and UnitLevel(unitTarget) == " .. levelCodeStr .. " -- 怪物等級: " .. actualLevel)
        print("            and UnitPowerType(unitTarget) == " .. unitPowerType)
        -- print("            and UnitSex(unitTarget) == " .. sex .. " -- " .. sexComment)
        print("            and UnitClassification(unitTarget) == \"" .. classification .. "\" -- " .. classifcationComment)
        print("            and UnitAffectingCombat(unitTarget) == " .. tostring(inCombat) .. " -- " .. combatComment)
        
        -- 生成代碼塊時，嚴格輸出大寫英文鍵，不夾帶任何本地化文本
        -- if className ~= "NONE" then
        --     print("            and select(2, UnitClass(unitTarget)) == \"" .. className .. "\"")
        -- end

        -- 動態生成生物家族代碼行
        print(familyCodeStr)
        
        -- 4個Boss擊殺狀態判定條件生成
        print("            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == " .. tostring(boss1Kill) .. " -- Boss1")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == " .. tostring(boss2Kill) .. " -- Boss2")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == " .. tostring(boss3Kill) .. " -- Boss3")
        print("            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == " .. tostring(boss4Kill) .. " -- Boss4")

        print(spellTargetCodeStr)
        print("        then")
        print("            C_Timer.After(0.5, function()")
        -- print("                if UnitExists(unitTarget) and " .. hasTargetStr .. roleCheckStr .. " then")
        print("                    PlaySoundFile(MEDIA_PATH .. \"音頻文件名.ogg\", DiGuaTimelineAudioHelper.audioChannel)")
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
        -- ==        毒牙祭壇        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毒素吐息 (重置計數)
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and not UnitSpellTargetName(unitTarget) then
            -- 確保全局計數器表已經初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [計數重置] 目標: " .. unitTarget .. " | 開啟新引導，清空前計數: " .. previousCount .. " -> 當前已歸零")
            
            return end
        
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 振響
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) then
            PlaySoundFile(addonTable.GetMediaPath() .. "AOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 進化
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2589 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            addonTable.SpellChannelStart[unitTarget] = GetTime() end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 劇毒噴霧 (重置計數)
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and UnitSpellTargetName(unitTarget) then
            -- 確保全局計數器表已經初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [計數重置] 目標: " .. unitTarget .. " | 開啟新引導，清空前計數: " .. previousCount .. " -> 當前已歸零")
            
            return end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 劇毒湧動
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget)
            then addonTable.CustomEncounterBar(5764925, 23.1, "注意射線")
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiSheXian.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        -- ============================
        -- ==      紅玉新生法地      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 鋼鐵彈幕
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and addonTable.SpellChannelCounter[unitTarget] == nil
            then addonTable.CustomEncounterBar(535414, 20, "注意躲圈")
            addonTable.SpellChannelCounter[unitTarget] = true
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(10, function() ddonTable.SpellChannelCounter[unitTarget] = nil end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 寒冰壁壘
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雷霆顎咬 -- 火焰之喉 -- 風暴吐息 -- 烈焰吐息
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then
            -- 確保全局計數器表已經初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [計數重置] 目標: " .. unitTarget .. " | 開啟新引導，清空前計數: " .. previousCount .. " -> 當前已歸零")
            
            return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 燃焰彈幕
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellChannelCounter[unitTarget] == nil
            then addonTable.SpellChannelCounter[unitTarget] = true
            PlaySoundFile(addonTable.GetMediaPath() .. "KongDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            C_Timer.After(26, function() addonTable.SpellChannelCounter[unitTarget] = nil end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 閃電湧流 (大引導者萊瓦迪)
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
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

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 閃電湧流 (暴風引導者)
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
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
        -- ==     虛空之痕競技場     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 虛空光束 -- 虛空光束 (工具)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then
            -- 確保全局計數器表已經初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
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

            -- print("🧹 [計數重置] 目標: " .. unitTarget .. " | 開啟新引導，清空前計數: " .. previousCount .. " -> 當前已歸零")
            
            return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 釘鎚風暴 -- 殘暴猛擊
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2572 or (C_Map.GetBestMapForUnit("player") or 0) == 2573 or (C_Map.GetBestMapForUnit("player") or 0) == 2574)
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
            addonTable.SpellChannelStart[unitTarget] = (addonTable.SpellChannelStart[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellChannelStart[unitTarget]

            if currentCount % 2 == 1 then
                PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
            else
                -- PlaySoundFile(addonTable.GetMediaPath() .. "JianRenFengBao.ogg", DiGuaTimelineAudioHelper.audioChannel)
            end            
            return
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雷鳴風暴 (工具)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.XuChuFaShi == true
            then
            -- 確保全局計數器表已經初始化
            addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [計數重置] 目標: " .. unitTarget .. " | 開啟新引導，清空前計數: " .. previousCount .. " -> 當前已歸零")
            
            return end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 險惡光環
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.CustomEncounterBar(840194, 20.6, "准備AOE")
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 甲殼守護
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKaiQi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==        諸王之眠        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 警戒防衛
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(addonTable.GetMediaPath() .. "BeiMianKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暗影箭雨 -- 劍刃風暴
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "達哈基聖墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoBi.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狩獵躍擊 (骸骨狩獵迅猛龍)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "達哈基聖墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) return end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狩獵躍擊
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狩獵躍擊 (榮耀迅猛龍)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 哀痛慟哭
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "不朽肉身密室" or GetSubZoneText() == "永存之室") 
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and addonTable.GetEncounterID() == 0
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiJiuRen.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黑暗之池
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == -1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiCaiQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        -- ============================
        -- ==         奪目谷         ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光顎射線
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastStartTime[unitTarget]
            then addonTable.SpellCastDuration[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
                -- print(addonTable.SpellCastDuration[unitTarget])
            if (addonTable.SpellCastDuration[unitTarget] or 0) > 1.75 then 
                addonTable.SpellCastStartTime[unitTarget] = nil
                addonTable.CustomEncounterBar(5764902, 26.7, "五碼分散")
                if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                    PlaySoundFile(addonTable.GetMediaPath() .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    PlaySoundFile(addonTable.GetMediaPath() .. "WuMaFenSan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end 
            end
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 噴射孢子
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastStartTime[unitTarget]
            then
                addonTable.CustomEncounterBar(136016, 31.6, "注意躲圈")
                addonTable.SpellCastDuration[unitTarget] = GetTime() - addonTable.SpellCastStartTime[unitTarget]
                -- print(addonTable.SpellCastDuration[unitTarget])
                if addonTable.SpellCastDuration[unitTarget] <= 1.75 then
                    PlaySoundFile(addonTable.GetMediaPath() .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
            end



        -- ============================
        -- ==     納洛拉克的洞穴     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 苦難盛宴 (工具)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) 
            -- 確保全局計數器表已經初始化
            then addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

            -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
            local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
            addonTable.SpellCastCounter[unitTarget] = 0
            
            -- print("🧹 [計數重置] 目標: " .. unitTarget .. " | 開啟新引導，清空前計數: " .. previousCount .. " -> 當前已歸零")
            
            return end
        -- ============================
        -- ==      塞塔裡斯神廟      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 箭雨
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
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


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 淨化瓦解
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        -- ============================
        -- ==        密謀小徑        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 召喚浮龍
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then addonTable.CustomEncounterBar(7301939, 24.4, "召喚小怪")
            PlaySoundFile(addonTable.GetMediaPath() .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 刃舞
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then PlaySoundFile(addonTable.GetMediaPath() .. "AOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end




    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unitTarget = ...

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 進化
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2589 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and addonTable.SpellChannelStart[unitTarget] -- 確保存在開始時間記錄
            then 
                local duration = GetTime() - addonTable.SpellChannelStart[unitTarget]
                if duration > 5.9 then
                    PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
                addonTable.SpellChannelStart[unitTarget] = nil
            end

        
    end

end)