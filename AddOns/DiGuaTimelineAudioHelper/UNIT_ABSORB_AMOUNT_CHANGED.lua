-- UNIT_ABSORB_AMOUNT_CHANGED.lua
-- 描述: 敌对姓名板吸收盾触发监听模块
-- 功能: 当敌对姓名板首次产生吸收盾数值变化时，播报一次“护盾快打”语音，直至姓名板离开画面被移除

local addonName, addonTable = ... 

local frame = CreateFrame("Frame")

addonTable.UnitAbsorbAmountChanged = addonTable.UnitAbsorbAmountChanged or {}

frame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

frame:SetScript("OnEvent", function(self, event, unitTarget)
    if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 暴风骤雨之盾
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
            and not addonTable.UnitAbsorbAmountChanged[unitTarget]
            then addonTable.CustomEncounterBar(4632783, 32.7, "护盾快打", unitTarget)
            PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
            addonTable.UnitAbsorbAmountChanged[unitTarget] = true 
            C_Timer.After(10, function() addonTable.UnitAbsorbAmountChanged[unitTarget] = nil end) end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 残暴猛击
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not addonTable.UnitAbsorbAmountChanged[unitTarget]
            then addonTable.CustomEncounterBar(132340, 34, "护盾快打", unitTarget)
            PlaySoundFile(addonTable.GetMediaPath() .. "HuDunKuaiDa.ogg", DiGuaTimelineAudioHelper.audioChannel)
            addonTable.UnitAbsorbAmountChanged[unitTarget] = true 
            C_Timer.After(31, function() addonTable.UnitAbsorbAmountChanged[unitTarget] = nil end) end
    end
end)