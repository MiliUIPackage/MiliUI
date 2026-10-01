-- UNIT_SPELLCAST_START.lua
-- 處理怪物開始施法事件的獨立分支
local addonName, addonTable = ...

-- 注冊事件監聽的框架層代碼（供主文件參考或直接使用）
local frame = CreateFrame("Frame")
addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}
addonTable.SpellCastStartTime = addonTable.SpellCastStartTime or {}
addonTable.SpellCastAudioTriggered = nil
addonTable.DuoKaiTouQianLock = nil -- 躲開正面防抖鎖
addonTable.SpellCastDuration = addonTable.SpellCastDuration or {}
addonTable.HasCastFearRoar = addonTable.HasCastFearRoar or {} -- 記錄已施放過"恐懼咆哮"的單位（作為"殘殺"播報資格）

-- ShouldWarnInterruptWithFocus() 已移至 Utils.lua（addonTable 全局函數），START/CHANNEL 共用

frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_START" then
        local unitTarget = ...
        -- local specID = PlayerUtil.GetCurrentSpecID()

        -- print(specID)
        -- 獲取主文件的路徑與聲道配置
        -- encounterEventIDs = C_EncounterEvents.GetEventList()
        -- if encounterEventIDs then
        --     print("--- 開始打印 Event List ---")
        --     for index, eventID in ipairs(encounterEventIDs) do
        --         print(string.format("[%d] = %d", index, eventID))
        --     end
        --     print("--- 打印結束 ---")
        -- else
        --     print("未獲取到事件列表")
        -- end

        -- local instanceID = 1202 -- 替換為你當前副本的 Instance ID（例如 1202 是紅玉新生法池，1041 是諸王之眠）
        -- local encounterID = 3470

        -- -- 優先預熱/選中該副本手冊
        -- if instanceID then
        --     EJ_SelectInstance(instanceID)
        -- end

        -- local name = EJ_GetEncounterInfo(encounterID)
        -- if name then
        --     print(string.format("Encounter ID: %d -> %s", encounterID, name))
        -- else
        --     print(string.format("Encounter ID: %d -> 未找到首領信息", encounterID))
        -- end


        -- local events = {}
        -- for i = 950, 1050 do
        --     table.insert(events, i)
        -- end
        -- local privateAuras = {1297649, 1297648},

        -- -- 2. 開始打印 Encounter Events 格式（已加雙層大括號）
        -- print("--- 開始打印 Encounter Events 格式 ---")
        -- for _, eventID in ipairs(events) do
        --     local info = C_EncounterEvents.GetEventInfo(eventID)
        --     local spellName = info and C_Spell.GetSpellName(info.spellID or 0) or "未知"
        --     -- 修復了原本代碼中轉義偏多的 \" 結構，使其輸出為標准的 [.ogg] 鍵值對格式
        --     print(string.format("    [%d] = { {\".ogg\", 1} }, -- %s (%d)", eventID, spellName, info and info.spellID or 0))
        -- end

        -- -- 3. 開始打印 Private Auras 格式
        -- print("--- 開始打印 Private Auras 格式 ---")
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
        --         print(string.format("ID: %d -> |cffff0000未緩存或無效ID|r", spellID))
        --     end
        -- end


        local MEDIA_PATH = addonTable.GetMediaPath and addonTable.GetMediaPath() or ""
        local audioChannel = DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.audioChannel or "Master"
        
        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     addonTable.GenerateAllSpecsCodeBlock(unitTarget)
        -- end

        -- addonTable.CustomEncounterBar(613397, 20.3, "雷鳴風暴", nil, "ff3333")

        -- ============================
        -- ==        毒牙祭壇        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 麻痺射擊 -- 毒素吐息
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]

            if currentCount % 2 == 1 then
                -- 非坦克播報；坦克中僅防騎(66)/酒仙(268) 豁免、照常播報
                if addonTable.IsNonTankOrExemptTank() then
                    addonTable.CustomEncounterBar(132274, 24, "準備減速", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiYouBu.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
                -- 1.5秒後，如果是治療則播放驅散魔法
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
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            and addonTable.SpellCastAudioTriggered == nil
            then
                addonTable.SpellCastAudioTriggered = true
                addonTable.CustomEncounterBar(132109, 23, "坦克尖刺", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function() addonTable.SpellCastAudioTriggered = nil end)
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 鮮血獻祭
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget)
            then addonTable.CustomEncounterBar(132334, 23, "準備吸奶盾", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiXiNaiDun.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 腐蝕之牙
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(136067, 28, "坦克尖刺", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

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
            and not UnitSpellTargetName(unitTarget) 
            then
            -- 僅非坦克（輸出/治療）展示倒數圓環
            if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(3) end
            addonTable.CustomEncounterBar(6238561, 28, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 群體毒傷
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2589 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
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



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 感染 -- 劇毒旋風
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
            and not UnitSpellTargetName(unitTarget)
            then
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]

            if currentCount % 2 == 1 then
                addonTable.CustomEncounterBar(132211, 36, "準備小怪", unitTarget)

                -- 2 秒後若該單位仍存在，則展示 5 秒倒數圓環（僅非坦克）
                C_Timer.After(2, function()
                    if UnitExists(unitTarget) and UnitGroupRolesAssigned("player") ~= "TANK" then
                        addonTable.StartCircleTimerBySeconds(5)
                    end
                end)

                PlaySoundFile(MEDIA_PATH .. "ZhunBeiXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
            else
                addonTable.CustomEncounterBar(5764921, 36.9, "注意躲圈", unitTarget)
                C_Timer.After(1.1, function() PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end)                
            end
            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 劇毒噴霧
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地圖ID
            and IsIndoors() == true
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and UnitSpellTargetName(unitTarget) 
            then addonTable.CustomEncounterBar(5764918, 36.6, "坦克正面", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 劇毒彈幕
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地圖ID
            and addonTable.GetEncounterID() == 3457
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 2
            and UnitPowerType(unitTarget) == 3
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.JuDuWeiSuo == true
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then
                -- 計數 +1
                addonTable.JuDuWeiSuoCounter = (addonTable.JuDuWeiSuoCounter or 0) + 1
                -- 【調試】播放音頻時打印當前計數
                -- print("[劇毒萎縮] 播放音頻 | JuDuWeiSuoCounter=" .. tostring(addonTable.JuDuWeiSuoCounter))
                -- 按第幾次播放對應音頻：1→YiDaDuan，2→ErDaDuan，3→SanDaDuan
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
        -- ==      紅玉新生法地      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毀滅猛擊 -- 鋼鐵彈幕
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 采掘沖擊
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then 
                C_Timer.After(0.1, function() 
                    if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then
                        addonTable.CustomEncounterBar(136025, 28, "準備AOE", unitTarget)
                        -- 僅非坦克（輸出/治療）展示倒數圓環
                        if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(3.5) end
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        C_Timer.After(3.3, function() 
                            if UnitExists(unitTarget) then
                                PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                            end
                        end)
                    end
                end)
            end

        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 熾焰衝鋒
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2095 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastAudioTriggered == nil
            then C_Timer.After(0.1, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then addonTable.SpellCastAudioTriggered = true
            addonTable.CustomEncounterBar(237517, 21, "躲開衝鋒", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DuoKaiChongFeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(10, function() addonTable.SpellCastAudioTriggered = nil end) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 滾雷
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.CustomEncounterBar(136050, 35.2, "準備點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(1.4, function() if UnitExists(unitTarget) and UnitGroupRolesAssigned("player") == "HEALER" 
            then PlaySoundFile(MEDIA_PATH .. "QuSanMoFa.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end


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

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地獄烈火
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastAudioTriggered == nil
            then 
                C_Timer.After(0.2, function()
                    if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then
                        addonTable.CustomEncounterBar(460698, 25.5, "準備AOE", unitTarget)
                        -- 僅非坦克（輸出/治療）展示倒數圓環
                        if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(3.5) end
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)                    
                        addonTable.SpellCastAudioTriggered = true
                        C_Timer.After(25, function() addonTable.SpellCastAudioTriggered = nil end)
                    end
                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 燃盡
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.GetEncounterID() == 0
            then C_Timer.After(0.2, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "DuoKaiDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 烈焰狂轟
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and addonTable.GetEncounterID() ~= 0
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then
            
            -- 【核心修正】每次施法事件觸發且滿足條件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            
            -- ==================== 3輪循環音效映射表 ====================
            local interruptSounds = {
                [1] = "YiDaDuan.ogg",   -- 1輪
                [2] = "ErDaDuan.ogg",   -- 2輪
                [0] = "SanDaDuan.ogg",  -- 3輪 (當 currentCount % 3 == 0 時)
            }
            
            -- 通過取模 3 計算當前屬於 1, 2, 3 哪一輪
            local currentRound = currentCount % 3
            local soundFile = interruptSounds[currentRound]
            
            -- 播放對應的打斷提示音
            if soundFile then
                PlaySoundFile(MEDIA_PATH .. soundFile, audioChannel or DiGuaTimelineAudioHelper.audioChannel)
            end
            
            return
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雷霆沖擊
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        
        -- ============================
        -- ==      塞塔裡斯神廟      ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 破甲猛擊
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(132318, 21.9, "坦克尖刺", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 震地
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then
                -- 僅非坦克（輸出/治療）展示倒數圓環
                if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(4) end
                addonTable.CustomEncounterBar(132358, 31.5, "小心擊退", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "XiaoXinJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                C_Timer.After(1, function()
                    if UnitExists(unitTarget) then
                        -- print("⏱️ [倒計時] 目標仍在 -> 播放 3")
                        PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 3 聲效路徑
                        
                        -- 【再過1秒後檢測 2】
                        C_Timer.After(1, function()
                            if UnitExists(unitTarget) then
                                -- print("⏱️ [倒計時] 目標仍在 -> 播放 2")
                                PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 2 聲效路徑
                                
                                -- 【再過1秒後檢測 1】
                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        -- print("⏱️ [倒計時] 目標仍在 -> 播放 1")
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 1 聲效路徑
                                    else
                                        -- print("❌ [倒計時終止] 1秒檢測前怪物已死亡/消失")
                                    end
                                end)
                            else
                                -- print("❌ [倒計時終止] 2秒檢測前怪物已死亡/消失")
                            end
                        end)
                    else
                        -- print("❌ [倒計時終止] 3秒檢測前怪物已死亡/消失")
                    end
                end)
            end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 風暴祝福 (工具)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 2
            and UnitPowerType(unitTarget) == 3
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黃沙沖刷 (砂誓騎兵)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then C_Timer.After(0.5, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then addonTable.SpellCastCounter[unitTarget] = true
            addonTable.CustomEncounterBar(796637, 21.8, "躲開正面", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 三葉蟲群 (砂誓騎兵)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastCounter[unitTarget] == true
            then
                addonTable.CustomEncounterBar(2011146, 27.8, "召喚小怪", unitTarget)
                C_Timer.After(0.5, function()
                    if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") then 
                        PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)   
                    end
                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黃沙沖刷 (三葉蟲主母)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.GetEncounterID() == 0
            then PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 風暴觸媒 (風暴風蛇)
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.GetEncounterID() ~= 0
            and addonTable.GetSpecPosition() == "MELEE" -- 僅近戰播報
            then PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 召喚閃電
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitIsLieutenant(unitTarget) == true -- 是否為中尉
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then C_Timer.After(1.3, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 釋放電荷
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitIsLieutenant(unitTarget) == true -- 是否為中尉
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then C_Timer.After(1.6, function() if UnitExists(unitTarget) and not addonTable.SpellCastSuccessTriggered[unitTarget]
            then PlaySoundFile(MEDIA_PATH .. "AOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毒刃斬擊
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(132287, 24, "坦克尖刺", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 蝕骨踐踏
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then
                -- 僅非坦克（輸出/治療）展示倒數圓環
                if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(3.5) end
                addonTable.CustomEncounterBar(5764923, 26.7, "準備AOE", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                C_Timer.After(0.5, function()
                    if UnitExists(unitTarget) then
                        C_Timer.After(1, function()
                            if UnitExists(unitTarget) then
                                -- print("⏱️ [倒計時] 目標仍在 -> 播放 2")
                                PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 2 聲效路徑
                                
                                -- 【再過1秒後檢測 1】
                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        -- print("⏱️ [倒計時] 目標仍在 -> 播放 1")
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 1 聲效路徑
                                    else
                                        -- print("❌ [倒計時終止] 1秒檢測前怪物已死亡/消失")
                                    end
                                end)
                            else
                                -- print("❌ [倒計時終止] 2秒檢測前怪物已死亡/消失")
                            end
                        end)
                    else
                        -- print("❌ [倒計時終止] 3秒檢測前怪物已死亡/消失")
                    end
                end)
            
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 潛藏妖術
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then C_Timer.After(2, function() if UnitExists(unitTarget)
            then PlaySoundFile(MEDIA_PATH .. "BaMaFenSan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
            addonTable.CustomEncounterBar(7264184, 20.1, "八碼分散", unitTarget)
            end end) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 撞頭
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"            
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==     虛空之痕競技場     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暗影箭雨
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            and addonTable.XuChuFaShi == false
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
            then PlaySoundFile(MEDIA_PATH .. "AnYingJianYu.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 虛無噴發
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and addonTable.XuChuFaShi == false
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
            then addonTable.CustomEncounterBar(4914670, 19, "注意點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 瓦解寶珠 -- 雷鳴風暴
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
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
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
                -- 僅非坦克（輸出/治療）展示倒數圓環
                if UnitGroupRolesAssigned("player") ~= "TANK" then
                    addonTable.StartCircleTimerBySeconds(3)
                end
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


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 凶猛飛躍
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then addonTable.CustomEncounterBar(236171, 33.2, "注意點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 勇士之矛
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.LuMangJianDuZhe == true
            then C_Timer.After(0.2, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target") 
            then addonTable.CustomEncounterBar(6035322, 35.3, "準備拉人", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiLaRen.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 劈地者 -- 野蠻猛擊
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then C_Timer.After(0.2, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end




        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 野性之怒 (工具)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 狂暴之沙
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then C_Timer.After(1.2, function() if addonTable.SpellCastSuccessTriggered[unitTarget] == nil 
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end
            

 
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 粉碎衝鋒
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.CustomEncounterBar(1127958, 22, "躲開衝鋒", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DuoKaiChongFeng.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 頭槌重擊
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then addonTable.CustomEncounterBar(1127958, 23, "坦克擊退", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "TanKeJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 瘋狂尖嘯 -- 挫志怒吼
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 天空打擊 -- 虛空光束
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
            and addonTable.SpellCastSuccessTriggered[unitTarget] == true
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 恐懼咆哮
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2573 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then
                -- 該單位已開始施放"恐懼咆哮" -> 立即標記；只有被標記的單位，後續"殘殺"播報才有資格觸發
                addonTable.HasCastFearRoar[unitTarget] = true
                C_Timer.After(0.5, function()
                    if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") then
                        addonTable.StartCircleTimerBySeconds(4)
                        addonTable.CustomEncounterBar(136185, 30, "準備擊退", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        C_Timer.After(1, function()
                            if UnitExists(unitTarget) then
                                PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 3 聲效路徑
                                C_Timer.After(1, function()
                                    if UnitExists(unitTarget) then
                                        -- print("⏱️ [倒計時] 目標仍在 -> 播放 2")
                                        PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 2 聲效路徑
                                        
                                        -- 【再過1秒後檢測 1】
                                        C_Timer.After(1, function()
                                            if UnitExists(unitTarget) then
                                                -- print("⏱️ [倒計時] 目標仍在 -> 播放 1")
                                                PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel) -- 替換為你的 1 聲效路徑
                                            else
                                                -- print("❌ [倒計時終止] 1秒檢測前怪物已死亡/消失")
                                            end
                                        end)
                                    else
                                        -- print("❌ [倒計時終止] 2秒檢測前怪物已死亡/消失")
                                    end
                                end)
                            else
                                -- print("❌ [倒計時終止] 3秒檢測前怪物已死亡/消失")
                            end
                        end)                        
                    end
                end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 殘殺
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2573 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            and addonTable.HasCastFearRoar[unitTarget] == true -- 僅"施放過恐懼咆哮"的單位才播（防同特征怪誤報）
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==        諸王之眠        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 壓制猛擊
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and not addonTable.SpellCastAudioTriggered
            then
                addonTable.CustomEncounterBar(132154, 24, "躲開正面", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                addonTable.SpellCastAudioTriggered = true
                C_Timer.After(1, function()
                    addonTable.SpellCastAudioTriggered = nil
                end) 
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暗影旋風斬
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitExists(unitTarget .. "target")
            then
                addonTable.CustomEncounterBar(2576091, 24, "準備AOE", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "ZhuYiJiaoXia.ogg", DiGuaTimelineAudioHelper.audioChannel)
                C_Timer.After(1, function()
                    if UnitExists(unitTarget) then
                        if UnitGroupRolesAssigned("player") ~= "TANK" then
                            addonTable.StartCircleTimerBySeconds(3)
                        end
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end)            
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 先祖狂怒
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and not UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "JiNu.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 妖術齊射
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then addonTable.CustomEncounterBar(615099, 24, "打斷大怪", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 邪惡愈合
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓")
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術無目標  
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) return end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 過載
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) return end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 淨化打擊
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "荣耀亡者大厅" or GetSubZoneText() == "先王之堂") 
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and not UnitIsDeadOrGhost(unitTarget) -- 初始觸發時必須存活
            then
            if UnitGroupRolesAssigned("player") ~= "TANK" then
                addonTable.StartCircleTimerBySeconds(2)
            end
            addonTable.CustomEncounterBar(451169, 11, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
            
            C_Timer.After(8, function()
                -- 檢測：目標存在 且 沒有死亡
                if UnitExists(unitTarget) and not UnitIsDeadOrGhost(unitTarget) then
                    -- print("⏱️ [倒計時] 目標存活 -> 播放 3")
                    PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    
                    -- 【再過1秒後檢測 2】
                    C_Timer.After(1, function()
                        if UnitExists(unitTarget) and not UnitIsDeadOrGhost(unitTarget) then
                            -- print("⏱️ [倒計時] 目標存活 -> 播放 2")
                            PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)
                            
                            -- 【再過1秒後檢測 1】
                            C_Timer.After(1, function()
                                if UnitExists(unitTarget) and not UnitIsDeadOrGhost(unitTarget) then
                                    -- print("⏱️ [倒計時] 目標存活 -> 播放 1")
                                    PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
                                else
                                    -- print("❌ [倒計時終止] 1秒檢測前怪物已死亡/消失")
                                end
                            end)
                        else
                            -- print("❌ [倒計時終止] 2秒檢測前怪物已死亡/消失")
                        end
                    end)
                else
                    -- print("❌ [倒計時終止] 3秒檢測前怪物已死亡/消失")
                end
            end)
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 埋葬
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
            then addonTable.CustomEncounterBar(236399, 23.1, "準備救人", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiJiuRen.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 惡疾排放 (首領戰)
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.GetEncounterID() == 2142 -- 在首領戰
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 妖術（工具）
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震岩層 -- 暴怒猛擊
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and not addonTable.SpellCastAudioTriggered
            then
                PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) 
                addonTable.SpellCastAudioTriggered = true
                C_Timer.After(1, function()
                    addonTable.SpellCastAudioTriggered = nil
                end) 
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震岩層（工具） -- 暴怒猛擊（工具）
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 黑暗啟示
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
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.CustomEncounterBar(1022945, 22, "注意點名", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 靈魂碾壓
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標           
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

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 嗜血飛斧
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標
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
        -- ==         奪目谷         ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光箭雨
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            then PlaySoundFile(MEDIA_PATH .. "DaDuanJianYu.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地裂打擊 -- 凶殘創裂
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then addonTable.SpellCastCounter[unitTarget] = true                
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" 
            then PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", DiGuaTimelineAudioHelper.audioChannel) end end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 熾陽吐息 -- 子彈種子
            and UnitCanAttack("player", unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) then
            C_Timer.After(0.5, function() if not UnitExists(unitTarget .. "target") 
            then PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", DiGuaTimelineAudioHelper.audioChannel) return end end) end
        

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光顎射線 (工具)
            and UnitCastingInfo(unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and not UnitCreatureFamily(unitTarget)
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and not UnitSpellTargetName(unitTarget) 
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 噴湧之花 -- 拔根而起 -- 光顎射線
            and UnitCastingInfo(unitTarget) -- 正在讀條
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and not UnitCreatureFamily(unitTarget)
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and not UnitSpellTargetName(unitTarget)
            and (addonTable.SpellCastDuration[unitTarget] or 0) <= 1.75
            then 

            -- 所有前置條件通過，開啟 0.5 秒延遲檢測
            C_Timer.After(0.5, function()
                local targetUnit = unitTarget .. "target"
                local exists = UnitExists(targetUnit)
                
                if exists then
                    if addonTable.SpellCastCounter[unitTarget] == true then
                        addonTable.CustomEncounterBar(7291441, 33.9, "小心擊退", unitTarget)
                        PlaySoundFile(MEDIA_PATH .. "XiaoXinJiTui.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        C_Timer.After(0.5, function()
                            if UnitExists(unitTarget) then  
                                if UnitGroupRolesAssigned("player") ~= "TANK" then
                                    addonTable.StartCircleTimerBySeconds(2)
                                end
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


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 光顎射線 (工具) -- 噴射孢子 (工具)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 迷亂尖叫
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
            and not addonTable.MiLuanJianJiaoLock -- 4 秒防抖鎖
            then
                addonTable.MiLuanJianJiaoLock = true
                C_Timer.After(4, function() addonTable.MiLuanJianJiaoLock = nil end)
                C_Timer.After(0.5, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target") 
                then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 吐舌攻擊
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then
                -- 確保全局計數器表已經初始化
                addonTable.SpellCastCounter = addonTable.SpellCastCounter or {}

                -- 核心修正：捕獲舊計數並直接將該目標的計數重置為 0
                local previousCount = addonTable.SpellCastCounter[unitTarget] or 0
                addonTable.SpellCastCounter[unitTarget] = 0
                if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                    addonTable.CustomEncounterBar(252175, 27.2, "坦克擊飛", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "TanKeJiFei.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 蛤蟆卵 -- 噴毒
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then
                addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
                local currentCount = addonTable.SpellCastCounter[unitTarget]                
                if currentCount % 2 == 1 then
                    addonTable.CustomEncounterBar(236999, 27.9, "召喚小怪", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
                else
                    addonTable.CustomEncounterBar(136016, 26.7, "準備中毒", unitTarget)
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiZhongDu.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end         
            return
            end

        if unitTarget == "boss2" and UnitCanAttack("player", unitTarget) -- 光芒箭 (3199 Boss2)
            and addonTable.GetEncounterID() == 3199
            and UnitExists("focus") -- 有焦點才執行（UnitIsUnit 對 Boss 令牌在戰斗中不可靠，改為判斷「已設置焦點」）
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            and UnitGroupRolesAssigned("player") ~= "HEALER" -- 非治療才播
            then
                -- 該 Boss 每次讀條計一次數：奇數次播一斷(YiDaDuan)，偶數次播二斷(ErDaDuan)，循環往復
                local encID = addonTable.GetEncounterID()
                if addonTable.GuangMangJianEnc ~= encID then
                    -- 換 Boss / 重新開怪時清零，保證每場第一次讀條都從"一斷"開始
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
        -- ==        密謀小徑        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 盾擊 -- 飛刃
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "DAMAGER"
            then
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            
            -- 使用 if-else 代替取反邏輯，清晰且高效
            if currentCount % 2 == 1 then
                -- addonTable.CustomEncounterBar(132330, 24, "坦克流血")
                -- PlaySoundFile(MEDIA_PATH .. "TanKeLiuXue.ogg", DiGuaTimelineAudioHelper.audioChannel)
            else
                addonTable.CustomEncounterBar(132357, 24, "坦克尖刺", unitTarget)
                PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", audioChannel)
            end
            
            return
            end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 斷心藥膏
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") == "TANK"
            and addonTable.DuanXinYaoGaoLock == nil -- 2 秒防抖鎖
            then
            addonTable.DuanXinYaoGaoLock = true
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiZhongDu.ogg", DiGuaTimelineAudioHelper.audioChannel)
            C_Timer.After(3, function() addonTable.DuanXinYaoGaoLock = nil end) end

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
            then
            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", DiGuaTimelineAudioHelper.audioChannel)
            -- 【读条点名玩家 → 倒计时圆环】
            -- 时长优先用真实剩余秒数（敌方读条时长可能是保密值，读不到就退回 1.8 秒）
            local remain = 1.8
            local ok, value = pcall(function()
                local _, _, _, _, endTimeMS = UnitCastingInfo(unitTarget)
                if endTimeMS == nil then
                    _, _, _, _, endTimeMS = UnitChannelInfo(unitTarget)
                end
                if endTimeMS == nil then return nil end
                local seconds = (endTimeMS / 1000) - GetTime()
                if seconds > 0 then return seconds end
                return nil
            end)
            if ok and value then remain = value end

            -- PlayerIsSpellTarget 可能是保密值(secret)：保密值不能在 Lua 里 if 判断，
            -- 所以先用 pcall 试普通判断；试不了就把原始值交给圆环第 3 个参数，由内部 SetAlphaFromBoolean 控制显隐。
            local canCompare, isMine = pcall(function() return PlayerIsSpellTarget(unitTarget) == true end)
            if not canCompare then
                addonTable.StartCircleTimerBySeconds(remain, false, PlayerIsSpellTarget(unitTarget))
            elseif isMine then
                addonTable.StartCircleTimerBySeconds(remain, false)
            end
            end -- 腐蚀唾液

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
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            and UnitIsLieutenant(unitTarget) == true -- 是否為中尉
            then if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(2) end
            addonTable.CustomEncounterBar(1305149, 22.7, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) return end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 旋風斬（老三前）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 旋風斬 -- 褻瀆猛擊（老三後）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 魔化狂亂
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術無目標
            then C_Timer.After(0.4, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target")
            then PlaySoundFile(MEDIA_PATH .. "DaGuaiQiangHua.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

                
                -- PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end

                -- C_Timer.After(1.1, function() 
                --     if UnitExists(unitTarget) and addonTable.SpellCastSuccessTriggered[unitTarget] == nil then 
                        
                --     else
                --         PlaySoundFile(MEDIA_PATH .. "DaGuaiQiangHua.ogg", DiGuaTimelineAudioHelper.audioChannel)
                --     end
                -- end)

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 吸取生命 -- 厄運詛咒（工具）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then
                addonTable.SpellCastStartTime[unitTarget] = GetTime()
                C_Timer.After(0.6, function() 
                    if addonTable.IsMobTargetAndPlayerFingerprintMatch(unitTarget) == true then
                        -- addonTable.StartCircleTimerBySeconds(1.4)
                        if UnitGroupRolesAssigned("player") ~= "TANK" and addonTable.PlayerSpellStatus.spells[58984] == true then
                            PlaySoundFile(MEDIA_PATH .. "YingDun.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        else
                            -- PlaySoundFile(MEDIA_PATH .. "MuBiaoShiNi.ogg", DiGuaTimelineAudioHelper.audioChannel)
                        end
                    end
                end)
            end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 眼棱
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
            and UnitIsLieutenant(unitTarget) == true -- 是否為中尉
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiSheXian.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        -- ============================
        -- ==     納洛拉克的洞穴     ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 飢荒雕像 -- 苦難盛宴
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 是否在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分類
            and UnitAffectingCombat(unitTarget) == true -- 是否在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
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

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 治療之風（老一前）
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 治療之風（老二前）
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and GetSubZoneText() == "風暴逼近" -- 子區域 (迫近風暴)
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 冰冷咆哮
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and UnitGroupRolesAssigned("player") ~= "HEALER"
            then PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 冰川之墓
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then C_Timer.After(0.5, function() if UnitExists(unitTarget) and UnitExists(unitTarget .. "target")
            then addonTable.CustomEncounterBar(236209, 18, "準備定身", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiDingShen.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 粉碎
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then C_Timer.After(0.5, function() if UnitExists(unitTarget) and not UnitExists(unitTarget .. "target")
            then addonTable.CustomEncounterBar(132318, 28.7, "近戰大圈", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 原始回響 (工具) -- 毒矛亂射 (工具)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 原始回響
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastSuccessTriggered[unitTarget] == nil
            then if UnitGroupRolesAssigned("player") ~= "TANK" then addonTable.StartCircleTimerBySeconds(3) end
            addonTable.CustomEncounterBar(463283, 23.1, "準備AOE", unitTarget)
            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", DiGuaTimelineAudioHelper.audioChannel) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 毒矛亂射
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.SpellCastSuccessTriggered[unitTarget] == true
            then PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel) end
            -- addonTable.CustomEncounterBar(135125, 21.8, "注意躲圈", unitTarget)



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 電弧
            and addonTable.ShouldWarnInterruptWithFocus(unitTarget)
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitIsLieutenant(unitTarget) == false -- 是否為中尉
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitSpellTargetName(unitTarget) -- 法術有目標
            then
                -- 2.6 秒後復核：單位仍存在、仍在施法中、且施法尚未成功 → 才提示打斷小怪
                C_Timer.After(2.6, function()
                    if UnitExists(unitTarget) and UnitCastingInfo(unitTarget) and addonTable.SpellCastSuccessTriggered[unitTarget] == nil then
                        PlaySoundFile(MEDIA_PATH .. "DaDuanXiaoGuai.ogg", DiGuaTimelineAudioHelper.audioChannel)
                    end
                end)
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地震術 -- 動蕩圖騰
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            then
            addonTable.SpellCastStartTime[unitTarget] = GetTime()
            -- 【核心修正】在這裡統一累加，每次施法事件觸發且滿足條件，必然且只累加 1 次
            addonTable.SpellCastCounter[unitTarget] = (addonTable.SpellCastCounter[unitTarget] or 0) + 1
            local currentCount = addonTable.SpellCastCounter[unitTarget]
            
            -- 通過取模 3 計算當前屬於 1, 2, 0(3) 哪一輪
            local currentRound = currentCount % 3
            
            -- 1 和 3(即模為0) 輪播放 BaMaFenSan.ogg，2 輪播放 ZhaoHuanXiaoGuai.ogg
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
        -- ==        烈毒之淵        ==
        -- ============================
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 風暴
            and select(8, GetInstanceInfo()) == 3004 -- 副本ID (烈毒之淵)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2609 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == -1 -- 怪物等級: -1
            and not UnitSpellTargetName(unitTarget) -- 法術沒目標
            and addonTable.GetEncounterID() == 3420
            then addonTable.SpellCastStartTime[unitTarget] = GetTime() end
    end
end)
