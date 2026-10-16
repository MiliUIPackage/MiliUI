-- NAME_PLATE_UNIT_ADDED.lua
-- 处理姓名板出现事件（血条加载）的独立分支

local addonName, addonTable = ...

-- 存储每个姓名板绑定的 FontString 对象，避免重复创建
local nameplateTexts = {}

-------------------------------------------------------------------------------
-- 血誓刺客（诸王之眠 / 达哈基之墓）：必须【2 秒内出现 4 个】才播报「准备AOE」
-------------------------------------------------------------------------------
-- 只记两个数：这批的起点时间 + 已经数到几个；超过 2 秒就当作新的一批重新数
local ASSASSIN_COUNT, ASSASSIN_WINDOW = 4, 2.0
local assassinCount, assassinBatchStart = 0, 0

-- 核心：在姓名板下方创建并更新文字
local function DisplayNameplateText(u, textToDisplay)
    -- 开关关闭时（默认开启）不显示"图腾"文字；语音播报不受此开关控制
    if not (DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.nameplateTotemTextEnabled) then
        return
    end

    local plate = C_NamePlate.GetNamePlateForUnit(u)
    if not plate then return end

    -- 如果尚未为此姓名板创建文本，则进行创建
    if not nameplateTexts[plate] then
        local fontString = plate:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- 字号设置为 40，使用描边样式
        fontString:SetFont(STANDARD_TEXT_FONT, 45, "OUTLINE")
        fontString:SetTextColor(1, 1, 1, 1)
        fontString:SetShadowColor(0, 0, 0, 1)
        -- 核心锚点：将文本顶部 (TOP) 挂载到姓名板底部 (BOTTOM) 偏下 5 像素处
        fontString:SetPoint("TOP", plate, "BOTTOM", 0, 0)
        
        nameplateTexts[plate] = fontString
    end

    local textObj = nameplateTexts[plate]
    textObj:SetText(textToDisplay or "")
    textObj:Show()
end

-- 开关回调辅助：关闭时清掉已显示的"图腾"文字
function addonTable.SetNameplateTotemTextEnabled(enabled)
    if enabled then return end
    for plate, textObj in pairs(nameplateTexts) do
        if textObj and textObj.Hide then textObj:Hide() end
    end
end

-- 注册事件监听的框架层代码
local frame = CreateFrame("Frame")

frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then

        local unitTarget = ... 
        





        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 骸骨狩猎迅猛龙
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓") 
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            then 
            addonTable.HaiGuShouLieXunMengLong = true
            -- print(addonTable.HaiGuShouLieXunMengLong)
            end



        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 血誓刺客
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "达哈基圣墓" or GetSubZoneText() == "達哈茲之墓")
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            then
            -- ★ 计数：2 秒内命中 4 次才播报（单位筛选就是上面那串条件）
            local now = GetTime()
            if now - assassinBatchStart > ASSASSIN_WINDOW then
                assassinBatchStart, assassinCount = now, 0 -- 上一批已过期 → 重新开一批
            end
            assassinCount = assassinCount + 1
            -- print("[血誓刺客] 本批已数 " .. assassinCount .. " 个")
            if assassinCount >= ASSASSIN_COUNT then
                assassinBatchStart, assassinCount = now, 0 -- 已触发 → 重新数
                addonTable.XueShiCiKe = true
                C_Timer.After(9.7, function()
                    PlaySoundFile(addonTable.GetMediaPath() .. "WuMiaoHouAOE.ogg", DiGuaTimelineAudioHelper.audioChannel)
                end)
                if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                    addonTable.CustomEncounterBar(1394887, 8.4, "坦克流血", unitTarget)
                end
                addonTable.CustomEncounterBar(132334, 15.7, "大怪吸血", unitTarget)
            end
            end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 动荡图腾 / 熔岩图腾
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            then
            
            -- 在姓名板下方显示竖排“图腾”
            DisplayNameplateText(unitTarget, "图\n腾")

            -- 检查并触发防抖锁
            if not addonTable.isAudioDebounced then
                addonTable.isAudioDebounced = true
                
                PlaySoundFile(addonTable.GetMediaPath() .. "ZhuanHuoTuTeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
                
                -- 使用当前片段内的临时防抖间隔变量（单位：秒）
                local debounceInterval = 2.0 
                C_Timer.After(debounceInterval, function()
                    addonTable.isAudioDebounced = false
                end)
            end
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 熔岩图腾
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and C_ChallengeMode.GetActiveKeystoneInfo() 
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
            then
            
            -- 在姓名板下方显示竖排“图腾”
            DisplayNameplateText(unitTarget, "图\n腾")

            -- 检查并触发防抖锁
            if not addonTable.isAudioDebounced then
                addonTable.isAudioDebounced = true
                
                PlaySoundFile(addonTable.GetMediaPath() .. "ZhuanHuoTuTeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
                
                -- 使用当前片段内的临时防抖间隔变量（单位：秒）
                local debounceInterval = 2.0 
                C_Timer.After(debounceInterval, function()
                    addonTable.isAudioDebounced = false
                end)
            end

        end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 治疗之潮图腾
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player")
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "normal" -- 普通怪
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and addonTable.GetEncounterID() == 0
            then
            
            -- 在姓名板下方显示竖排“图腾”
            DisplayNameplateText(unitTarget, "图\n腾")

            -- 检查并触发防抖锁
            if not addonTable.isAudioDebounced then
                addonTable.isAudioDebounced = true
                
                PlaySoundFile(addonTable.GetMediaPath() .. "ZhuanHuoTuTeng.ogg", DiGuaTimelineAudioHelper.audioChannel)
                
                -- 使用当前片段内的临时防抖间隔变量（单位：秒）
                local debounceInterval = 2.0 
                C_Timer.After(debounceInterval, function()
                    addonTable.isAudioDebounced = false
                end)
            end
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unitTarget = ...
        local plate = C_NamePlate.GetNamePlateForUnit(unitTarget)
        if plate and nameplateTexts[plate] then
            nameplateTexts[plate]:Hide()
        end
    end
end)