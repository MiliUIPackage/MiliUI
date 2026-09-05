-- PlayerDebuffDisplay.lua
-- 固定显示玩家身上"别人施放"的减益（排除自己/宠物施放），屏幕正中偏上
-- 显示：图标 + 剩余时间转盘 + 层数 + 驱散类型边框 + 法术名
-- 使用 12.1 的 AuraContainer / CustomAuraContainerTemplate（Interface 120100）

local addonName, addonTable = ...

local container

-- 可移动宿主框（控制台打开且开关开启时可拖动，否则点击穿透）
local HostFrame = CreateFrame("Frame", nil, UIParent)
HostFrame:SetSize(55, 55)
HostFrame:SetPoint("CENTER", UIParent, "CENTER", 150, 60)
HostFrame:EnableMouse(false)
HostFrame:SetMovable(false)
HostFrame:SetClampedToScreen(true)

HostFrame.bg = HostFrame:CreateTexture(nil, "BACKGROUND")
HostFrame.bg:SetAllPoints(HostFrame)
HostFrame.bg:SetColorTexture(0.8, 0.3, 0.6, 0.4) -- 暖红紫色
HostFrame.bg:Hide()

HostFrame.text = HostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HostFrame.text:SetPoint("CENTER", HostFrame, "CENTER", 0, 0)
HostFrame.text:SetText("玩家减益\n图标")
HostFrame.text:SetTextColor(1, 1, 1, 0.9)
HostFrame.text:SetJustifyH("CENTER")
HostFrame.text:SetSpacing(2)
HostFrame.text:Hide()

-- 客户端是否支持 12.1 AuraContainer API（老客户端直接跳过，不报错）
local function IsAuraContainerAvailable()
    return type(AuraContainerSortMethod) == "table"
        and type(AuraContainerSortDirection) == "table"
        and type(AnchorUtil) == "table"
        and type(AnchorUtil.FlowDirection) == "table"
end

local function BuildContainer()
    if container then return container end
    if not IsAuraContainerAvailable() then return nil end

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, HostFrame, "CustomAuraContainerTemplate")
    if not ok or not c then return nil end
    c:Hide()

    -- 以左侧为锚点，跟随宿主拖动；图标向右生长
    c:SetPoint("LEFT", HostFrame, "LEFT", 0, 0)

    local ICON_SIZE = 48
    local opts = {
        initializeFrame = function(button)
            button:SetSize(ICON_SIZE, ICON_SIZE)

            -- 禁用悬停 tooltip：CustomAuraButton 的 OnEnter/OnLeave 是暴雪禁止替换的处理器，
            -- SetScript 会报错（forbidden script handler），直接关闭鼠标交互即可不触发 tooltip
            button:EnableMouse(false)

            -- 图标
            local icon = button:CreateTexture(nil, "BACKGROUND")
            icon:SetAllPoints(button)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            button:SetIcon(icon)

            -- 剩余时间转盘
            local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cd:SetAllPoints(button)
            cd:SetDrawEdge(false)
            button:SetDurationCooldown(cd)
            cd:SetReverse(true)

            -- 驱散类型边框（魔法/诅咒/疾病/中毒自动上色 + 小图标）
            -- 边框放进独立子帧 borderHost 并抬高 frameLevel，否则会被作为子帧的转盘(Cooldown)盖住
            local borderHost = CreateFrame("Frame", nil, button)
            borderHost:SetAllPoints(button)
            borderHost:SetFrameLevel(cd:GetFrameLevel() + 2)
            local border = borderHost:CreateTexture(nil, "OVERLAY")
            -- 替换 SetAllPoints：向四周各扩展 8 像素（即边框比图标宽/高各多 8 像素）
            border:SetPoint("TOPLEFT", borderHost, "TOPLEFT", -8, 8)
            border:SetPoint("BOTTOMRIGHT", borderHost, "BOTTOMRIGHT", 8, -8)

            local style = Enum.CustomAuraButtonDispelTypeTextureStyle
            pcall(button.AddDispelTypeTexture, button, border, {
                style = style and style.BorderWithIcon or nil,
                showWhenHarmful = true,
                showWhenHelpful = false,
            })

            -- 层数
            local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            count:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
            count:SetTextColor(1, 0.9, 0.6, 1)
            button:SetApplicationCount(count)

            -- 法术名（GameFontNormalSmall 12px 基础上减 1 = 11px）
            local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            name:SetFont(STANDARD_TEXT_FONT, 11)
            name:SetPoint("TOP", button, "BOTTOM", 0, -3)
            name:SetWidth(ICON_SIZE + 24)
            name:SetWordWrap(false)
            name:SetTextColor(1, 1, 1) -- 白色
            button:SetSpellName(name)
        end,
        maxFrameCount = math.huge,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Normal,
    }

    c:AddAuraGroup("debuffs", "HARMFUL", opts)
    c:SetUnit("player")

    -- 只显示不是自己/宠物施放的减益（别人给的）
    c:SetAuraGroupCandidateFilters("debuffs", { isFromPlayerOrPlayerPet = false })

    local maxCount = 3
    c:SetAuraGroupMaxFrameCount("debuffs", maxCount)
    c:SetAuraGroupSortMethod("debuffs",
        AuraContainerSortMethod.Expiration, AuraContainerSortDirection.Normal)

    -- 布局：以左侧为锚点，向右生长，一行最多 3 个
    local hG = AnchorUtil.FlowDirection.Right
    local vG = AnchorUtil.FlowDirection.Down
    pcall(c.SetFlowLayoutGrowthDirection, c, hG, vG)
    pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
    pcall(c.SetFlowLayoutPadding, c, 4, 4, 4, 4)
    pcall(c.SetFlowLayoutMaximumLineSize, c, maxCount * (ICON_SIZE + 9))
    pcall(c.SetAuraGroupLayout, c, "debuffs", { elementSpacing = 9, lineSpacing = 9 })

    container = c
    return c
end

-- 鼠标拖动：仅当控制台打开且开关开启（HostFrame 可移动）时生效
HostFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and self:IsMovable() then
        self:StartMoving()
        self.isMoving = true
    end
end)

HostFrame:SetScript("OnMouseUp", function(self)
    if self.isMoving then
        self:StopMovingOrSizing()
        self.isMoving = false
        local _, _, _, xOfs, yOfs = self:GetPoint()
        if DiGuaTimelineAudioHelper then
            DiGuaTimelineAudioHelper.playerDebuffX = xOfs
            DiGuaTimelineAudioHelper.playerDebuffY = yOfs
            print(string.format("|cff00ff00[DiGua]|r 玩家减益新位置已保存 (X: %d, Y: %d)", xOfs, yOfs))
        end
    end
end)

-- 控制台打开 + 开关开启 → 显示绿色拖动框；否则点击穿透
function addonTable.RefreshPlayerDebuffAnchor(isConsoleShown)
    if not DiGuaTimelineAudioHelper then return end
    if isConsoleShown and DiGuaTimelineAudioHelper.playerDebuffEnabled then
        HostFrame.bg:Show()
        HostFrame.text:Show()
        HostFrame:EnableMouse(true)
        HostFrame:SetMovable(true)
    else
        HostFrame.bg:Hide()
        HostFrame.text:Hide()
        HostFrame:EnableMouse(false)
        HostFrame:SetMovable(false)
    end
end

-- 开关切换：开启时构建并显示减益图标，关闭时隐藏；同步拖动框状态
function addonTable.SetPlayerDebuffEnabled(enabled)
    if enabled then
        local c = BuildContainer()
        if c then
            c:SetEnabled(true)
            c:Show()
        end
    elseif container then
        container:SetEnabled(false)
        container:Hide()
    end
    local shown = DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown() or false
    addonTable.RefreshPlayerDebuffAnchor(shown)
end

-- PLAYER_LOGIN 读取位置并按开关显示；UNIT_AURA(player) 兜底刷新
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterUnitEvent("UNIT_AURA", "player")

f:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        -- 读取保存的拖动位置
        if DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.playerDebuffX and DiGuaTimelineAudioHelper.playerDebuffY then
            HostFrame:ClearAllPoints()
            HostFrame:SetPoint("CENTER", UIParent, "CENTER",
                DiGuaTimelineAudioHelper.playerDebuffX, DiGuaTimelineAudioHelper.playerDebuffY)
        end
        -- 默认关闭，按开关显示/隐藏并同步拖动框状态
        addonTable.SetPlayerDebuffEnabled(DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.playerDebuffEnabled)
    elseif event == "UNIT_AURA" and unit == "player" then
        if container and container:IsShown() then
            pcall(container.UpdateAllAuras, container)
        end
    end
end)
