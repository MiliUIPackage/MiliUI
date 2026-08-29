-- MythicPlusProgressTracker.lua
local addonName, addonTable = ...

addonTable.XuChuFaShi = false
addonTable.LuMangJianDuZhe = false
addonTable.PoHuaiMoChengFaZhe = 0
-- 1. 将防抖锁挂载到 addonTable，供其他 Lua 文件共享
addonTable.isAudioDebounced = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, criteriaID)
    if event == "SCENARIO_CRITERIA_UPDATE" then
        -- 1. 调试打印
        -- local info = criteriaID and C_ScenarioInfo.GetCriteriaInfoByID and C_ScenarioInfo.GetCriteriaInfoByID(criteriaID)
        -- if info then
        --     print(string.format("|cffffaa00[Criteria 变动]|r ID: |cff00ffff%d|r | 描述: %s | 进度: %d/%d", 
        --         criteriaID, info.description or "未知", info.quantity or 0, info.totalQuantity or 0))
        -- else
        --     print(string.format("|cffffaa00[Criteria 变动]|r ID: |cff00ffff%s|r", tostring(criteriaID)))
        -- end

        -- 2. 机制判断

        if criteriaID == 113962 then -- 破坏魔惩罚者
            addonTable.PoHuaiMoChengFaZhe = addonTable.PoHuaiMoChengFaZhe + 1

        elseif criteriaID == 115538 then -- 神灵代言人纳尼亚
                addonTable.CustomEncounterBar(460693, 26, "首领激活")
                -- 首领激活前 5 秒语音倒数：5 → 4 → 3 → 2 → 1（26 秒倒计时的最后 5 秒）
                C_Timer.After(21, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu5.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
                C_Timer.After(22, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu4.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
                C_Timer.After(23, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu3.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
                C_Timer.After(24, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu2.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
                C_Timer.After(25, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "DaoShu1.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
        elseif criteriaID == 116483 then -- 活体毒液
            if not addonTable.isAudioDebounced then
                addonTable.isAudioDebounced = true
                PlaySoundFile(addonTable.GetMediaPath() .. "KuaiKaiJianShang.ogg", DiGuaTimelineAudioHelper.audioChannel)
                
                C_Timer.After(20, function()
                    addonTable.isAudioDebounced = false
                end)
            end

        elseif criteriaID == 115500 then -- 虚触法师
            addonTable.XuChuFaShi = true

        elseif criteriaID == 115501 then -- 鲁莽监督者
            addonTable.LuMangJianDuZhe = true

        elseif criteriaID == 40370 or criteriaID == 116488 then -- 防腐液 / 毒液水蛭 (带防抖)
            if not addonTable.isAudioDebounced then
                addonTable.isAudioDebounced = true
                PlaySoundFile(addonTable.GetMediaPath() .. "DuoQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
                
                C_Timer.After(4, function()
                    addonTable.isAudioDebounced = false
                end)
            end

        elseif criteriaID == 113952 then -- 巨大的邪能浮龙 (无防抖)
            PlaySoundFile(addonTable.GetMediaPath() .. "DuoKaiDaQuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
        end

    elseif event == "CHALLENGE_MODE_START" or event == "PLAYER_ENTERING_WORLD" then
        addonTable.XuChuFaShi = false
        addonTable.LuMangJianDuZhe = false
        addonTable.isAudioDebounced = false
        addonTable.PoHuaiMoChengFaZhe = 0
    end
end)