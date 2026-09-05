-- FocusInterrupt.lua
-- 焦点打断提醒：焦点单位（focus）开始施法/引导且符合各副本"打断特征"时播 JiaoDianDaDuan，并显示焦点施法条
local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- 防抖
local lastPlayTime, PLAY_DEBOUNCE = 0, 0.8
local BAR_HEIGHT = 40 -- 施法条/图标/移动框共用高度
local BAR_WIDTH = 240 -- 施法条/移动框共用宽度
local BAR_FONT_SIZE = 20 -- 技能名/倒计时共用字体大小

-- 剩余时间格式化（secret 安全，同 AdvancedFocusCastBar 做法）：≥1 秒显示整数，<1 秒显示一位小数
local castTimeFormatter = C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and C_StringUtil.CreateNumericRuleFormatter()
if castTimeFormatter then
    castTimeFormatter:SetBreakpoints({
        { threshold = 0, step = 0.1, format = "%.1f" }, -- 0≤x<1 显示一位小数（如 "0.5"）
        { threshold = 1, step = 1, format = "%d" },     -- x≥1 显示整数（如 "12"）
    })
end

-- ===== 施法条 =====
local CastBar = CreateFrame("Frame", "DiGuaFocusCastBarFrame", UIParent, "BackdropTemplate")
CastBar:SetSize(BAR_WIDTH, BAR_HEIGHT)
CastBar:SetPoint("CENTER", UIParent, "CENTER", 0, 260)
CastBar:SetClampedToScreen(true)
CastBar:EnableMouse(false)
CastBar:SetMovable(false)
CastBar:Hide()
CastBar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
CastBar:SetBackdropColor(0, 0, 0, 0.7)
CastBar:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)

-- 进度条（最低层，亮绿；从图标右缘开始，避免盖住图标）
local barFill = CreateFrame("StatusBar", nil, CastBar)
barFill:SetPoint("LEFT", CastBar, "LEFT", 4 + (BAR_HEIGHT - 5) + 1, 0) -- 图标左偏移4 + 图标宽(BAR_HEIGHT-5) + 1px间距
barFill:SetPoint("RIGHT", CastBar, "RIGHT", 0, 0)
barFill:SetPoint("TOP", CastBar, "TOP", 0, -1)
barFill:SetPoint("BOTTOM", CastBar, "BOTTOM", 0, 1)
barFill:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
barFill:GetStatusBarTexture():SetDrawLayer("BACKGROUND")
barFill:SetStatusBarColor(0.35, 1, 0.35, 0.9)

-- 技能名（左）/ 剩余时间（右），改在 barFill 上创建，天然高于 barFill 背景
local barName = barFill:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
barName:SetFont(STANDARD_TEXT_FONT, BAR_FONT_SIZE, "OUTLINE") -- 粗描边（去除阴影改用粗 outline 提升可读性）
barName:SetPoint("LEFT", CastBar, "LEFT", 42, 0)
barName:SetJustifyH("LEFT")
barName:SetTextColor(1, 1, 1, 1)

local barTime = barFill:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
barTime:SetFont(STANDARD_TEXT_FONT, BAR_FONT_SIZE, "OUTLINE") -- 粗描边（去除阴影改用粗 outline 提升可读性）
barTime:SetPoint("RIGHT", CastBar, "RIGHT", -8, 0)
barTime:SetJustifyH("RIGHT")
barTime:SetTextColor(1, 1, 1, 1)

-- 技能图标（左侧，跟施法条高度）
local barIcon = CastBar:CreateTexture(nil, "ARTWORK")
barIcon:SetSize(BAR_HEIGHT - 5, BAR_HEIGHT - 5)
barIcon:SetPoint("LEFT", CastBar, "LEFT", 4, 0)
barIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
barIcon:SetDrawLayer("ARTWORK", 7)
barIcon:SetTexture(132117)

-- ===== 移动框（淡蓝色，仅用于拖动）=====
local MoveFrame = CreateFrame("Frame", "DiGuaFocusCastBarMoveFrame", UIParent, "BackdropTemplate")
MoveFrame:SetSize(BAR_WIDTH, BAR_HEIGHT)
MoveFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 260)
MoveFrame:SetClampedToScreen(true)
MoveFrame:EnableMouse(false)
MoveFrame:SetMovable(false)
MoveFrame:Hide()
MoveFrame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
MoveFrame:SetBackdropColor(0.25, 0.65, 1, 0.4)
MoveFrame.text = MoveFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
MoveFrame.text:SetPoint("CENTER")
MoveFrame.text:SetText("焦點特定技能施法條")
MoveFrame.text:SetTextColor(1, 1, 1, 0.9)
MoveFrame.text:SetDrawLayer("OVERLAY", 7)
MoveFrame.text:SetJustifyH("CENTER")

local castingActive, placeholderActive = false, false

-- ===== 获取 focus 当前施法/引导信息（name, texture, duration）=====
local function GetFocusCastInfo()
    local duration = UnitCastingDuration("focus")
    if duration then
        local name, _, texture = UnitCastingInfo("focus")
        return name, texture, duration
    end
    duration = UnitChannelDuration("focus")
    if duration then
        local name, _, texture = UnitChannelInfo("focus")
        return name, texture, duration
    end
    return nil, nil, nil
end

-- ===== 刷新施法条 =====
local function UpdateFocusCastBar()
    if not castingActive then return end
    local name, texture, duration = GetFocusCastInfo()
    if not duration then
        EndFocusCastDisplay()
        return
    end
    barName:SetText(name or "") -- 直接 SetText，不做格式化/比较（避免 secret 值）
    if texture then barIcon:SetTexture(texture) end
    if barFill.SetTimerDuration then
        barFill:SetTimerDuration(duration) -- DurationObject 直接交给 StatusBar
    else
        barFill:SetMinMaxValues(0, duration:GetTotalDuration())
        barFill:SetValue(duration:GetElapsedDuration())
    end
    if castTimeFormatter and duration.FormatRemainingDuration then
        barTime:SetText(duration:FormatRemainingDuration(castTimeFormatter)) -- 返回值是 secret 字符串，只能直接交给 SetText，勿做任何 Lua 操作
    else
        barTime:SetText(duration:GetRemainingDuration()) -- 降级：直接交给 FontString
    end
    barFill:SetStatusBarColor(0.35, 1, 0.35, 0.9)
end

-- ===== 显示/隐藏 =====
local function ShowFocusCastBar()
    castingActive = true
    if not (DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.focusCastBarEnabled) then return end
    MoveFrame:Hide()
    CastBar:Show()
    UpdateFocusCastBar()
end

function EndFocusCastDisplay()
    castingActive = false
    CastBar:Hide()
    if placeholderActive then MoveFrame:Show() else MoveFrame:Hide() end
end

local function HideFocusCastBar()
    EndFocusCastDisplay()
end

-- ===== 控制台状态刷新 =====
function addonTable.RefreshFocusCastBarState(isConsoleShown)
    if not DiGuaTimelineAudioHelper then return end
    placeholderActive = isConsoleShown and DiGuaTimelineAudioHelper.focusCastBarEnabled
    MoveFrame:EnableMouse(placeholderActive)
    MoveFrame:SetMovable(placeholderActive)
    if castingActive then
        MoveFrame:Hide()
    elseif placeholderActive then
        MoveFrame:Show()
    else
        MoveFrame:Hide()
    end
end

-- ===== 移动框拖动 =====
MoveFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and self:IsMovable() then
        self:StartMoving()
        self.isMoving = true
    end
end)
MoveFrame:SetScript("OnMouseUp", function(self)
    if not self.isMoving then return end
    self:StopMovingOrSizing()
    self.isMoving = false
    local _, _, _, x, y = self:GetPoint()
    if DiGuaTimelineAudioHelper then
        DiGuaTimelineAudioHelper.focusCastBarX, DiGuaTimelineAudioHelper.focusCastBarY = x, y
    end
    CastBar:ClearAllPoints()
    CastBar:SetPoint("CENTER", UIParent, "CENTER", x, y)
    print(string.format("|cff00ff00[DiGua]|r 焦點特定技能施法條新位置已保存 (X: %d, Y: %d)", x, y))
end)

-- ===== 持续刷新 =====
CastBar:SetScript("OnUpdate", function(self, elapsed)
    self._t = (self._t or 0) + elapsed
    if self._t < 0.05 then return end
    self._t = 0
    UpdateFocusCastBar()
end)

-- ===== 登录恢复位置 =====
local positionFrame = CreateFrame("Frame")
positionFrame:RegisterEvent("PLAYER_LOGIN")
positionFrame:SetScript("OnEvent", function()
    if not DiGuaTimelineAudioHelper then return end
    if DiGuaTimelineAudioHelper.focusCastBarX and DiGuaTimelineAudioHelper.focusCastBarY then
        local x, y = DiGuaTimelineAudioHelper.focusCastBarX, DiGuaTimelineAudioHelper.focusCastBarY
        CastBar:ClearAllPoints()
        CastBar:SetPoint("CENTER", UIParent, "CENTER", x, y)
        MoveFrame:ClearAllPoints()
        MoveFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
    if addonTable.RefreshFocusCastBarState then
        addonTable.RefreshFocusCastBarState(DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown() or false)
    end
end)

-- ===== 播放焦点打断音效 =====
local function PlayFocusInterruptSound()
    -- 方案A：焦点打断播报只在"焦点施法条"开启时由本文件负责；
    -- 关闭时交回 UNIT_SPELLCAST_START/CHANNEL 打断块，避免同一焦点施法播两次
    if not (DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.focusCastBarEnabled) then return end
    ShowFocusCastBar()
    if addonTable.IsInterruptOnCooldown and addonTable.IsInterruptOnCooldown() then return end
    local now = GetTime()
    if now - lastPlayTime < PLAY_DEBOUNCE then return end
    lastPlayTime = now
    PlaySoundFile(addonTable.GetMediaPath() .. "JiaoDianDaDuan.ogg", DiGuaTimelineAudioHelper.audioChannel)
end

-- ===== 施法事件 =====
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:SetScript("OnEvent", function(self, event, unitTarget)
    if event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_CHANNEL_START" then return end
    if unitTarget == "focus" then HideFocusCastBar() end
    -- PlayFocusInterruptSound()
    -- 毒牙祭坛：刺耳嘶鸣
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2993
        and (C_Map.GetBestMapForUnit("player") or 0) == 2588
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and UnitIsLieutenant("focus") == false
        and not select(2, UnitCreatureFamily("focus"))
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false
        and not UnitSpellTargetName("focus")
    then PlayFocusInterruptSound() return end

    -- 红玉新生法池：雷霆冲击
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2521
        and (C_Map.GetBestMapForUnit("player") or 0) == 2094
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player") + 1
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true
        and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true
        and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false
        and UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

    -- 红玉新生法池：寒冰壁垒（引导）
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2521
        and (C_Map.GetBestMapForUnit("player") or 0) == 2095
        and IsIndoors() == true
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and not select(2, UnitCreatureFamily("focus"))
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false
        and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false
        and UnitSpellTargetName("focus")
    then PlayFocusInterruptSound() return end


    -- 虚空之痕竞技场：挫志怒吼
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2923
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 1
        and UnitClassification("focus") == "elite"
        and not select(2, UnitCreatureFamily("focus"))
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end


    -- 虚空之痕竞技场：暗影箭雨
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2923
        and UnitLevel("focus") == UnitLevel("player") + 1
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false
        and not UnitSpellTargetName("focus")
        and addonTable.XuChuFaShi == false
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

    -- 虚空之痕竞技场：狂暴之沙
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2923
        and (C_Map.GetBestMapForUnit("player") or 0) == 2572
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 1
        and UnitClassification("focus") == "elite"
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

    -- 虚空之痕竞技场：疯狂尖啸
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2923
        and (C_Map.GetBestMapForUnit("player") or 0) == 2572
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 1
        and UnitClassification("focus") == "elite"
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true
        and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

    -- 诸王之眠：妖术齐射
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 1762
        and (C_Map.GetBestMapForUnit("player") or 0) == 1004
        and UnitLevel("focus") == UnitLevel("player") + 1
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

    -- 夺目谷：光箭雨
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2859
        and (C_Map.GetBestMapForUnit("player") or 0) == 2500
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and not select(2, UnitCreatureFamily("focus"))
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
        and C_ChallengeMode.GetActiveKeystoneInfo()
        and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
    then PlayFocusInterruptSound() return end

    -- 夺目谷：迷乱尖叫
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2859
        and (C_Map.GetBestMapForUnit("player") or 0) == 2500
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 1
        and UnitClassification("focus") == "elite"
        and not select(2, UnitCreatureFamily("focus"))
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
        and C_ChallengeMode.GetActiveKeystoneInfo()
        and C_ChallengeMode.GetActiveKeystoneInfo() >= 12
    then PlayFocusInterruptSound() return end


    -- 纳洛拉克的洞穴：治疗之风
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
        and IsIndoors() == false -- 在室外
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite" -- 精英怪
        and not select(2, UnitCreatureFamily("focus")) -- 不是生物家族
        and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        and not UnitSpellTargetName("focus") -- 法术没目标
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end


    -- 纳洛拉克的洞穴：冰冷咆哮
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2825
        and (C_Map.GetBestMapForUnit("player") or 0) == 2514
        and IsIndoors() == false
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite"
        and select(2, UnitCreatureFamily("focus"))
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true
        and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false
        and not UnitSpellTargetName("focus")
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

    -- 纳洛拉克的洞穴：电弧
    if unitTarget == "focus" and UnitCanAttack("player", "focus")
        and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
        and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
        and IsIndoors() == false -- 在室外
        and UnitLevel("focus") == UnitLevel("player")
        and UnitPowerType("focus") == 0
        and UnitClassification("focus") == "elite" -- 精英怪
        and not select(2, UnitCreatureFamily("focus")) -- 不是生物家族
        and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
        and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
        and UnitSpellTargetName("focus") -- 法术有目标
        and UnitGroupRolesAssigned("player") ~= "HEALER"
    then PlayFocusInterruptSound() return end

end)
