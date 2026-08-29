-- NAME_PLATE_UNIT_ADDED.lua
-- 处理姓名板出现事件（血条加载）的独立分支

local addonName, addonTable = ...

-- 存储每个姓名板绑定的 FontString 对象，避免重复创建
local nameplateTexts = {}

-- 核心：在姓名板下方创建并更新文字
local function DisplayNameplateText(u, textToDisplay)
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

-- 注册事件监听的框架层代码
local frame = CreateFrame("Frame")

frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitTarget = ... 
        
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
            then            
            DisplayNameplateText(unitTarget, "图\n腾")
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