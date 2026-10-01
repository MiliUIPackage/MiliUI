-- CoTankPrivateAuras.lua
-- 副坦（队伍里另一个坦克）身上的减益监控：图标 + 剩余时间倒计时 + 层数 + 驱散类型边框
--
-- 【2026-09-30 重写说明】
--   旧实现走 C_UnitAuras.AddPrivateAuraAnchor + auraIndex(1~3)，这条路在 12.x 已失效：
--   新客户端把「私有光环 / 减益」统一交给了 AuraContainer，旧的 anchor 接口拿不到东西了。
--
--   新实现完全照搬 DBM-Core/modules/AuraTracking.lua 里「副坦（Co-Tank）」那一套：
--     ✅ CreateFrame("AuraContainer", nil, HostFrame, "CustomAuraContainerTemplate")
--        + container:SetUnit(副坦的 unit token)  ← 关键：换个 unit 就是换个监控对象
--        → 「谁符合条件」全交给暴雪内部算（所以私有光环也拿得到），插件只负责
--          「给过滤条件」+「把按钮画成什么样」
--     ⛔ 不要自己调 C_UnitAuras.GetAuraDataByIndex / AuraUtil.ForEachAura 去扫光环：
--        12.1 起这些接口带 AllowedWhenUntainted + RequiresUnitAuraAccess，插件（tainted）
--        在战斗 / 副本 / 大秘境 / PvP 里会直接报 "Auras cannot be accessed when secret while tainted"
--
--   本文件与 PlayerDebuffDisplay.lua / ForeignDebuffRing.lua 是同一套 AuraContainer 写法，
--   差别只有一点：unit 从 "player" 换成副坦。

local addonName, addonTable = ...

-- ============================================================================
-- 可调参数（想改观感 / 行为，改这几行就够，不用动下面的逻辑）
-- ============================================================================
local ICON_SIZE = 48            -- 图标边长（与「玩家减益」保持一致：都是 48px，档0 时默认等大）
local ICON_SPACING = 10         -- 图标间距（别小于 9：驱散边框会向图标外扩 9px，否则互相压住）
local MAX_ICONS = 5             -- 最多同时显示几个减益（DBM 副坦默认也是 5；想少点改成 3）
local ONLY_FOREIGN_DEBUFFS = true -- true = 只显示「不是副坦本人/其宠物施加」的减益（BOSS 给的都算）
                                  -- DBM 默认就是这个；想连副坦自己身上的 self-debuff 也显示就改 false
local SHOW_STACKS = true        -- 显示层数（右下角）
local SHOW_DISPEL_BORDER = true -- 显示驱散类型边框（魔法/诅咒/疾病/中毒自动上色 + 小图标）
local SHOW_SPELL_NAME = true    -- 图标下方显示法术名（和「玩家减益」一样：11px 白字，不换行）
local REQUIRE_PLAYER_TANK = true -- true  = 只有自己也是坦克时才监控副坦（DBM「自动」模式的行为）
                                  -- false = 只要队伍里有别的坦克就显示（治疗/DPS 也能看）

-- 这些 ID 是「疲劳 / 时空错位 / 饱足 / 眩晕层数 / 逃离副本惩罚」之类的垃圾减益，
-- 一律不看（照抄 DBM AuraTracking 的排除表）
local JUNK_SPELL_IDS = {    [57723] = true,  -- 力竭
    [80354] = true,  -- 时空位移
    [57724] = true,  -- 饱足
    [390435] = true, -- 力竭（新）
    [264689] = true, -- 疲劳
    [160455] = true, -- 疲劳
    [95809] = true,  -- 疯狂
    [124255] = true, -- 酒仙「醉拳」的持续伤害
    [71041] = true,  -- 地下城逃亡者
    [206151] = true,  -- 挑战者的负担
}

-- ============================================================================
-- 0. 大小档位（控制台滑块 -2~9 档 → 整体等比缩放，做法同 PlayerDebuffDisplay）
--    负档位用于「比默认更小」：-1 = 90%、-2 = 80%；0 档 = 100%（默认 48px）；9 档 = 190%
-- ============================================================================
-- ⚠️ container / HostFrame 都必须提前声明：ApplyCoTankSize / SetCoTankAuraSize 都要读它们，
--    这里的 local 必须出现在那两个函数之前，否则函数体里读到的是恒为 nil 的全局变量
--    （SetSize 静默不执行 → 拖拽绿框不随档位变化）。做法同 PlayerDebuffDisplay.lua。
local container
local HostFrame -- 前向声明（真正的创建在第 1 节，那里用赋值而非 local）
local HOST_BASE_SIZE = 55 -- 拖拽定位框基础边长（与 PlayerDebuffDisplay 完全一致：都是 55）
                          -- ⚠️ 注意它不等于 ICON_SIZE(48)：绿框比图标略大一圈是刻意的，
                          --    两个拖拽框必须用同一个基准值，否则大小看起来不一样
local MIN_SIZE_STEP = -2 -- 最小档（越小越迷你）
local MAX_SIZE_STEP = 9  -- 最大档
local coTankSizeStep = tonumber((DiGuaTimelineAudioHelper or {}).coTankSize) or 0
if coTankSizeStep < MIN_SIZE_STEP then coTankSizeStep = MIN_SIZE_STEP
elseif coTankSizeStep > MAX_SIZE_STEP then coTankSizeStep = MAX_SIZE_STEP end

local function SizeFactor()
    return 1 + coTankSizeStep * 0.1 -- 档-2=80% / 档0=100% / 档9=190%
end

-- 用容器整体 SetScale 缩放：图标 / 间距 / 边框 / 层数 全部等比跟着变，不用逐个改尺寸。
-- 拖拽定位框（绿框）也随档位等比放大，和「玩家减益」行为一致 ——
-- 否则放大后图标会超出绿框，拖动时框体和实际图标对不上。
local function ApplyCoTankSize()
    local factor = SizeFactor()
    if container then
        container:SetScale(factor)
    end
    if HostFrame then
        HostFrame:SetSize(HOST_BASE_SIZE * factor, HOST_BASE_SIZE * factor)
    end
end

-- 外部接口：控制台滑块调用（-2 ~ 9）
function addonTable.SetCoTankAuraSize(step)
    step = tonumber(step) or 0
    if step < MIN_SIZE_STEP then step = MIN_SIZE_STEP
    elseif step > MAX_SIZE_STEP then step = MAX_SIZE_STEP end
    coTankSizeStep = math.floor(step + 0.5)
    ApplyCoTankSize()
end

-- ============================================================================
-- 1. 创建宿主框体（控制台打开且开关开启时可拖动，其它时候完全点击穿透）
-- ============================================================================
-- ⚠️ 这里必须是赋值，不能写 local —— 否则会遮蔽第 0 节的前向声明，
--    ApplyCoTankSize 依旧读不到 HostFrame，绿框还是不会跟着缩放。
HostFrame = CreateFrame("Frame", nil, UIParent)
HostFrame:SetSize(HOST_BASE_SIZE, HOST_BASE_SIZE) -- 尺寸 = 第一个图标的基础尺寸，方便拖动对齐
HostFrame:SetPoint("CENTER", UIParent, "CENTER", -400, 350) -- 初始位置，会被存档坐标覆盖

HostFrame:EnableMouse(false)
HostFrame:SetMovable(false)
HostFrame:SetClampedToScreen(true)

HostFrame.bg = HostFrame:CreateTexture(nil, "BACKGROUND")
HostFrame.bg:SetAllPoints(HostFrame)
HostFrame.bg:SetColorTexture(0, 1, 0, 0.4)
HostFrame.bg:Hide() -- 默认隐藏

HostFrame.text = HostFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
HostFrame.text:SetPoint("CENTER", HostFrame, "CENTER", 0, 0)
HostFrame.text:SetText("副坦\n減益")
HostFrame.text:SetTextColor(1, 1, 1, 0.9)
HostFrame.text:SetJustifyH("CENTER")
HostFrame.text:SetSpacing(2)
HostFrame.text:Hide()

-- ============================================================================
-- 2. 12.1 AuraContainer：把「找符合条件的减益」交给暴雪
-- ============================================================================
-- ⚠️ container 必须在这里之前就声明（见文件上方「0. 大小档位」区块），
--    否则 ApplyCoTankSize 里的 container 会被解析成一个恒为 nil 的全局变量，
--    缩放函数静默失效（滑块怎么拖图标都不变）。
local lastUnit -- 当前容器绑在哪个 unit 上（变了才需要重新 SetUnit）

local function Warn(msg)
    print("|cffff4444[DiGua/副坦]|r " .. tostring(msg))
end

-- 包一层 pcall：只有失败时才打印原因（成功时完全安静）
local function Try(what, fn)
    local ok, err = pcall(fn)
    if not ok then
        Warn("✘ " .. what .. " → " .. tostring(err))
    end
    return ok
end

-- 客户端是否支持 12.1 AuraContainer API（老客户端直接跳过，不报错）
local function IsAuraContainerAvailable()
    return type(AuraContainerSortMethod) == "table"
        and type(AuraContainerSortDirection) == "table"
        and type(AnchorUtil) == "table"
        and type(AnchorUtil.FlowDirection) == "table"
end

local function BuildContainer()
    if container then return container end
    if not IsAuraContainerAvailable() then
        Warn("客戶端不支持 AuraContainer（12.1 才有）→ 功能跳過")
        return nil
    end

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, HostFrame, "CustomAuraContainerTemplate")
    if not ok or not c then
        Warn("CreateFrame(AuraContainer) 失敗 → " .. tostring(c))
        return nil
    end
    c:Hide()

    local opts = {
        -- 每生成一个光环按钮调用一次：这里决定按钮长什么样
        initializeFrame = function(button)
            local okInit, errInit = pcall(function()
                -- CustomAuraButton 的 OnEnter/OnLeave 是暴雪禁止替换的处理器，SetScript 会报错
                -- （forbidden script handler），直接关掉鼠标交互，顺带也不会触发 tooltip
                button:EnableMouse(false)
                button:SetSize(ICON_SIZE, ICON_SIZE)

                -- ① 图标
                local icon = button:CreateTexture(nil, "BACKGROUND")
                icon:SetAllPoints(button)
                icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- 裁掉图标外面那圈描边
                button:SetIcon(icon)

                -- ② 剩余时间倒计时：把 Cooldown 交给光环按钮，暴雪每帧按该 debuff 的剩余时间自动驱动
                --    （刷新 / 续期 / 消失全自动，插件不用 SetCooldown，也不用 OnUpdate）
                local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                cd:SetAllPoints(button)
                cd:SetDrawEdge(false)
                cd:SetReverse(true)
                button:SetDurationCooldown(cd)

                -- ③ 驱散类型边框（魔法/诅咒/疾病/中毒自动上色 + 小图标）
                --    边框放进独立子帧 borderHost 并抬高 frameLevel，否则会被作为子帧的转盘盖住
                if SHOW_DISPEL_BORDER then
                    local borderHost = CreateFrame("Frame", nil, button)
                    borderHost:SetAllPoints(button)
                    borderHost:SetFrameLevel(button:GetFrameLevel() + 4)
                    local border = borderHost:CreateTexture(nil, "OVERLAY")
                    -- 向四周各扩展 9 像素（边框比图标大一圈）
                    border:SetPoint("TOPLEFT", borderHost, "TOPLEFT", -9, 9)
                    border:SetPoint("BOTTOMRIGHT", borderHost, "BOTTOMRIGHT", 9, -9)
                    local style = Enum.CustomAuraButtonDispelTypeTextureStyle
                    pcall(button.AddDispelTypeTexture, button, border, {
                        style = style and style.BorderWithIcon or nil,
                        showWhenHarmful = true,
                        showWhenHelpful = false,
                    })
                end

                -- ④ 层数（右下角）—— 字号/位置与「玩家减益」保持一致
                if SHOW_STACKS then
                    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
                    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                    count:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
                    count:SetTextColor(1, 0.9, 0.6, 1)
                    button:SetApplicationCount(count)
                end

                -- ⑤ 法术名（与「玩家减益」完全一致：11px 白字、不换行、贴在图标下方）
                if SHOW_SPELL_NAME then
                    local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    name:SetFont(STANDARD_TEXT_FONT, 11)
                    name:SetPoint("TOP", button, "BOTTOM", 0, -3)
                    name:SetWidth(ICON_SIZE + 24)
                    name:SetWordWrap(false)
                    name:SetTextColor(1, 1, 1)
                    button:SetSpellName(name)
                end
            end)
            if not okInit then Warn("initializeFrame 内部出错 → " .. tostring(errInit)) end
        end,
        maxFrameCount = MAX_ICONS,
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Normal,
    }

    -- ★ 第一层过滤：过滤器字符串（"HARMFUL" = 只看减益）
    Try("AddAuraGroup(debuffs, HARMFUL)", function() c:AddAuraGroup("debuffs", "HARMFUL", opts) end)

    -- ★ 第二层过滤：候选过滤器（同样是暴雪内部算）
    --   · isFromPlayerOrPlayerPet = false → 只留「不是副坦本人/其宠物施加」的减益（BOSS 给的都算）
    --     DBM 的另一条分支是 isBossOrRoleAura = true（只要暴雪标记的 BOSS/职责相关减益），
    --     想更严格就把下面这行换成 filters.isBossOrRoleAura = true
    --   · excludeSpellIDs → 一刀切排除垃圾减益
    local filters = { excludeSpellIDs = JUNK_SPELL_IDS }
    if ONLY_FOREIGN_DEBUFFS then
        filters.isFromPlayerOrPlayerPet = false
    end
    Try("SetAuraGroupCandidateFilters(debuffs)", function() c:SetAuraGroupCandidateFilters("debuffs", filters) end)

    Try("SetAuraGroupMaxFrameCount(debuffs, " .. MAX_ICONS .. ")", function()
        c:SetAuraGroupMaxFrameCount("debuffs", MAX_ICONS)
    end)
    Try("SetAuraGroupSortMethod(debuffs)", function()
        c:SetAuraGroupSortMethod("debuffs",
            AuraContainerSortMethod.Expiration, AuraContainerSortDirection.Normal)
    end)

    -- 布局：与「玩家减益」完全一致 —— 垂直居中于绿框、向左贴边，向右生长，一行最多 MAX_ICONS 个
    Try("SetFlowLayoutGrowthDirection(Right,Down)", function()
        c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    end)
    Try("SetFlowLayoutAnchorPoint(TOPLEFT)", function() c:SetFlowLayoutAnchorPoint("TOPLEFT") end)
    -- ⚠️ 内缩必须和「玩家减益」一样是 4px：
    --    绿框 55px、图标 48px，差 7px；四周各让 4px 后图标正好在框内竖直居中
    --    （改成 0 的话图标会贴着左上角，看起来「没居中」）
    Try("SetFlowLayoutPadding(4,4,4,4)", function() c:SetFlowLayoutPadding(4, 4, 4, 4) end)
    Try("SetFlowLayoutMaximumLineSize", function()
        c:SetFlowLayoutMaximumLineSize(MAX_ICONS * (ICON_SIZE + ICON_SPACING))
    end)
    Try("SetAuraGroupLayout(debuffs)", function()
        c:SetAuraGroupLayout("debuffs", { elementSpacing = ICON_SPACING, lineSpacing = ICON_SPACING })
    end)

    -- 容器锚点：左侧对齐宿主框左侧（垂直方向由 Padding 撑出居中效果），跟随绿框拖动。
    -- ⚠️ 这里用 LEFT 而不是 TOPLEFT —— TOPLEFT 会把图标顶到框的最上面，
    --    和「玩家减益」（用 LEFT）表现不一致，用户一眼就能看出副坦没居中。
    Try("SetPoint(LEFT ← 宿主框 LEFT)", function()
        c:SetPoint("LEFT", HostFrame, "LEFT", 0, 0)
    end)

    -- 先挂上全局引用，再缩放：ApplyCoTankSize 内部读的是 container，
    -- 若放在赋值之前调用会静默 return（容器还没登记，缩放不生效）
    container = c
    ApplyCoTankSize() -- 应用控制台设定的档位（整体等比缩放）
    return c
end

-- ============================================================================
-- 3. 找副坦
-- ============================================================================
-- ⚠️ 关于「不在同一小队」：unit token（raid1~40 / party1~4）覆盖的是**整个团队 / 整个小队**，
--    和「小队分组」无关 —— 40 人团里 1 队到 8 队的人，一律都叫 raid1 ~ raid40。
--    所以「在别的队」本身不影响显示；真正会找不到副坦的只有这三种情况：
--      · 不是团队/小队成员（跨服不同团、敌对目标、副本外的人）→ 没有 unit token，看不到
--      · 职责没被系统标记为 TANK（用个人拾取/职责分配混乱的时候会漏）
--      · 自己是治疗/DPS，而被 REQUIRE_PLAYER_TANK 挡住了
--    另外：暴雪不是所有副本都允许插件对非本小队的人取光环（unit 可达性限制），
--    真遇到「判定到了副坦但图标不出」的情况，用 /dump UnitGroupRolesAssigned("raid5") 先确认职责。

-- 队伍里另一个坦克（自己除外）；找不到返回 nil
local function FindCoTankUnit()
    if not IsInGroup() then return nil end
    if REQUIRE_PLAYER_TANK and UnitGroupRolesAssigned("player") ~= "TANK" then return nil end

    local prefix, count
    if IsInRaid() then
        -- 整个团队（含其它小队）一起扫：raid1 ~ raid40
        prefix, count = "raid", GetNumGroupMembers()
    else
        -- 五人小队：party1 ~ party4（party 计数含自己，所以减 1）
        prefix, count = "party", GetNumGroupMembers() - 1
    end

    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit)
            and not UnitIsUnit("player", unit)
            and UnitGroupRolesAssigned(unit) == "TANK" then
            return unit
        end
    end
    return nil
end

-- ============================================================================
-- 4. 核心：刷新副坦监控（外部只调这一个）
-- ============================================================================
-- 战斗锁定防御：改动 AuraContainer / SetUnit 属于保护操作，锁定中调用会被拦成
-- ADDON_ACTION_BLOCKED（这是暴雪发的事件，pcall 挡不住），所以挂到脱战后补做
local pendingCoTankRefresh = false
local CoTankRegenFrame = CreateFrame("Frame")
CoTankRegenFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if pendingCoTankRefresh then
        pendingCoTankRefresh = false
        addonTable.UpdateRaidTankAuras()
    end
end)

local function HideContainer()
    if container then
        container:SetEnabled(false)
        container:Hide()
    end
    lastUnit = nil
end

function addonTable.UpdateRaidTankAuras()
    if InCombatLockdown() then
        pendingCoTankRefresh = true
        CoTankRegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    -- 存档里的档位可能在登录后才读到（SavedVariables 加载顺序），这里每次对齐一次
    coTankSizeStep = tonumber((DiGuaTimelineAudioHelper or {}).coTankSize) or coTankSizeStep

    -- 开关关掉 → 直接收起容器（容器留着，下次开不用重建）
    if not (DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.coTankAuraEnabled) then
        HideContainer()
        return
    end

    local unit = FindCoTankUnit()
    if not unit then
        HideContainer()
        return
    end

    local c = BuildContainer()
    if not c then return end

    -- 只有换了对象才需要重新绑 unit（SetUnit 可以反复调，DBM 每次注册也是这么干的）
    if unit ~= lastUnit then
        Try("SetUnit(" .. unit .. ")", function() c:SetUnit(unit) end)
        lastUnit = unit
    end

    -- 缩放可能在空中被改过（拖滑块），每次刷新都对齐一次，保证档位与存档一致
    ApplyCoTankSize()

    c:Show()
    c:SetEnabled(true)
    -- 立刻刷一次，免得要等下一次光环变动才冒图标（老客户端没这个方法就静默跳过）
    if c.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
end

-- ============================================================================
-- 5. 测试绿框：显隐 + 拖动（只有控制台打开且开关开启时可拖，其余时候点击穿透）
-- ============================================================================
function addonTable.RefreshAnchorState(isConsoleShown)
    if not DiGuaTimelineAudioHelper then return end

    -- 中央倒计时拖拽状态与控制台联动
    if addonTable.SetCenterCountdownDragEnabled then
        addonTable.SetCenterCountdownDragEnabled(isConsoleShown)
    end

    -- 只有当控制台打开 且 用户开启了副坦监控时，绿框才具有实体
    if isConsoleShown and DiGuaTimelineAudioHelper.coTankAuraEnabled then
        HostFrame.bg:Show()
        HostFrame.text:Show()
        HostFrame:EnableMouse(true)
        HostFrame:SetMovable(true)
    else
        -- 其他任何情况下彻底释放鼠标控制权，保证该区域完美“点击穿透”
        HostFrame.bg:Hide()
        HostFrame.text:Hide()
        HostFrame:EnableMouse(false)
        HostFrame:SetMovable(false)
    end
end

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

        -- 规整回 CENTER/CENTER 再取坐标（否则拖到靠边时 x,y 会变成「离边的距离」）
        local xOfs, yOfs = addonTable.NormalizeFrameToUIParentCenter(self)

        -- 存进大表，暴雪会自动持久化到 WTF
        if DiGuaTimelineAudioHelper then
            DiGuaTimelineAudioHelper.coTankX = xOfs
            DiGuaTimelineAudioHelper.coTankY = yOfs
            print(string.format("|cff00ff00[DiGua]|r 副坦減益新位置已保存 (X: %d, Y: %d)", xOfs, yOfs))
        end
    end
end)

-- ============================================================================
-- 6. 事件驱动
-- ============================================================================
local EventListener = CreateFrame("Frame")
EventListener:RegisterEvent("PLAYER_LOGIN")
EventListener:RegisterEvent("GROUP_ROSTER_UPDATE")   -- 队友进出 / 换队伍
EventListener:RegisterEvent("PLAYER_ROLES_ASSIGNED") -- 职责被改（谁当坦克）
EventListener:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventListener:RegisterEvent("PLAYER_ENTERING_WORLD") -- 过图 / 进本 / reload 后补一次

EventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        if DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.coTankX and DiGuaTimelineAudioHelper.coTankY then
            HostFrame:ClearAllPoints()
            HostFrame:SetPoint("CENTER", UIParent, "CENTER",
                DiGuaTimelineAudioHelper.coTankX, DiGuaTimelineAudioHelper.coTankY)
        end

        -- 【安全兜底】：根据控制台当前显隐状态，强行对齐一次绿框实体的鼠标状态
        if addonTable.RefreshAnchorState then
            local isConsoleShown = DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown() or false
            addonTable.RefreshAnchorState(isConsoleShown)
        end

        addonTable.UpdateRaidTankAuras()
    else
        addonTable.UpdateRaidTankAuras()
    end
end)
