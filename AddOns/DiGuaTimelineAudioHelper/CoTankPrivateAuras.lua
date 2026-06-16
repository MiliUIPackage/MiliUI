-- CoTankPrivateAuras.lua
local addonName, addonTable = ...

-- 1. 创建宿主框体
local HostFrame = CreateFrame("Frame", nil, UIParent)
HostFrame:SetSize(55, 55) -- 改为 55x55 方便拖动和对齐第一个图标
-- 初始位置先给个暂存，随后会被 PLAYER_LOGIN 事件中的读取数据覆盖
HostFrame:SetPoint("CENTER", UIParent, "CENTER", -400, 350) 

-- 【核心修复】：新创建时，默认直接死锁鼠标权限和移动权限，防止登录时成为无形墙
HostFrame:EnableMouse(false)
HostFrame:SetMovable(false)

-- 创建可移动的测试绿框背景
HostFrame.bg = HostFrame:CreateTexture(nil, "BACKGROUND")
HostFrame.bg:SetAllPoints(HostFrame)
HostFrame.bg:SetColorTexture(0, 1, 0, 0.4)
HostFrame.bg:Hide() -- 默认隐藏

-- ============================================================================
-- [优化] 在绿框中央添加硬换行提示文字
-- ============================================================================
HostFrame.text = HostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HostFrame.text:SetPoint("CENTER", HostFrame, "CENTER", 0, 0)
HostFrame.text:SetText("副坦\n私有\n光环") -- 使用 \n 强制两字一换行
HostFrame.text:SetTextColor(1, 1, 1, 0.9)   -- 白色微透明
HostFrame.text:SetJustifyH("CENTER")          -- 文字水平居中
HostFrame.text:SetSpacing(2)                  -- [可选] 微调行间距，让排版更紧凑好看
HostFrame.text:Hide()                         -- 默认隐藏

-- 开启夹持，防止框体被拖出屏幕外面
HostFrame:SetClampedToScreen(true)

-- 存储暴雪返回的 AnchorID
local ActiveAnchors = {}

-- 2. 核心团队扫描与绑定功能（挂载到私有表上）
function addonTable.UpdateRaidTankAuras()
    for _, anchorID in ipairs(ActiveAnchors) do
        C_UnitAuras.RemovePrivateAuraAnchor(anchorID)
    end
    ActiveAnchors = {}

    if not DiGuaTimelineAudioHelper or not DiGuaTimelineAudioHelper.coTankAuraEnabled then 
        return 
    end

    if not IsInRaid() then return end
    if UnitGroupRolesAssigned("player") ~= "TANK" then return end

    local iconSize = 55  
    local spacing = 6
    local targetUnit = nil

    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if UnitExists(unit) and not UnitIsUnit("player", unit) and UnitGroupRolesAssigned(unit) == "TANK" then
            targetUnit = unit
            break 
        end
    end

    if not targetUnit then return end

    for auraIndex = 1, 3 do
        local auraFrame = CreateFrame("Frame", nil, HostFrame)
        auraFrame:SetSize(iconSize, iconSize)
        
        local xOffset = (auraIndex - 1) * (iconSize + spacing)
        auraFrame:SetPoint("LEFT", HostFrame, "LEFT", xOffset, 0)

        local anchorID = C_UnitAuras.AddPrivateAuraAnchor({
            unitToken = targetUnit, 
            auraIndex = auraIndex,
            parent = auraFrame,
            showCountdownFrame = true,
            showCountdownNumbers = true,
            isContainer = false,
            iconInfo = {
                iconAnchor = { point = "CENTER", relativeTo = auraFrame, relativePoint = "CENTER", offsetX = 0, offsetY = 0 },
                borderScale = iconSize / 16, 
                iconWidth = iconSize,
                iconHeight = iconSize,
            },
        })

        if anchorID then
            table.insert(ActiveAnchors, anchorID)
        end
    end
end

-- ============================================================================
-- 专门管理测试绿框显隐与拖动状态的函数（修复点击穿透问题）
-- ============================================================================
function addonTable.RefreshAnchorState(isConsoleShown)
    if not DiGuaTimelineAudioHelper then return end

    -- 只有当控制台打开 且 用户开启了副坦监控时，绿框才具有实体
    if isConsoleShown and DiGuaTimelineAudioHelper.coTankAuraEnabled then
        HostFrame.bg:Show()          -- 显示绿色背景
        HostFrame.text:Show()        -- 显示文字
        
        HostFrame:EnableMouse(true)  -- 激活鼠标：允许接收点击和拖拽
        HostFrame:SetMovable(true)    
    else
        -- 【核心修复】其他任何情况下，彻底释放该区域的鼠标控制权
        HostFrame.bg:Hide()          -- 隐藏绿色背景
        HostFrame.text:Hide()        -- 隐藏文字
        
        HostFrame:EnableMouse(false) -- 彻底关闭鼠标互动，使该区域完美“点击穿透”
        HostFrame:SetMovable(false)   
    end
end

-- 鼠标拖动脚本绑定
HostFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and self:IsMovable() then
        self:StartMoving()
        self.isMoving = true
    end
end)

HostFrame:SetScript("OnMouseUp", function(self, button)
    if self.isMoving then
        self:StopMovingOrSizing()
        self.isMoving = false
        
        -- 【补全功能】：抓取松开鼠标时的偏移量坐标
        local _, _, _, xOfs, yOfs = self:GetPoint()
        
        -- 【补全功能】：将坐标存入大表，以便暴雪自动将其持久化保存至 WTF 文件
        if DiGuaTimelineAudioHelper then
            DiGuaTimelineAudioHelper.coTankX = xOfs
            DiGuaTimelineAudioHelper.coTankY = yOfs
            print(string.format("|cff00ff00[DiGua]|r 副坦光环新位置已保存 (X: %d, Y: %d)", xOfs, yOfs))
        end
    end
end)

-- 3. 事件驱动
local EventListener = CreateFrame("Frame")
EventListener:RegisterEvent("PLAYER_LOGIN")
EventListener:RegisterEvent("GROUP_ROSTER_UPDATE")   
EventListener:RegisterEvent("PLAYER_ROLES_ASSIGNED") 
EventListener:RegisterEvent("ZONE_CHANGED_NEW_AREA") 

EventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.coTankX and DiGuaTimelineAudioHelper.coTankY then
            HostFrame:ClearAllPoints()
            HostFrame:SetPoint("CENTER", UIParent, "CENTER", DiGuaTimelineAudioHelper.coTankX, DiGuaTimelineAudioHelper.coTankY)
        end
        
        -- 【安全兜底】：根据当前控制台实际状态（初始必然是隐藏），强行对齐一次绿框实体的鼠标状态
        if addonTable.RefreshAnchorState then
            -- 如果控制台存在，传入它当前的显隐状态（通常为 false）
            local isConsoleShown = DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown() or false
            addonTable.RefreshAnchorState(isConsoleShown)
        end

        addonTable.UpdateRaidTankAuras()
    else
        addonTable.UpdateRaidTankAuras()
    end
end)