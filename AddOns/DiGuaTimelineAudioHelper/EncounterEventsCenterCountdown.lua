-- EncounterEventsCenterCountdown.lua
local addonName, addonTable = ...

------------------------------------------------------------
-- 配置与常量定义
------------------------------------------------------------
addonTable.TimelineEventKeys = addonTable.TimelineEventKeys or {}        -- 存储按 unitKey 关联的自定义事件 ID 列表
addonTable.CenterCountdownEvents = addonTable.CenterCountdownEvents or {}  -- 标记当前激活的自定义倒计时事件
addonTable.CenterEventInfoCache = addonTable.CenterEventInfoCache or {}  -- 缓存事件详细信息 (EventInfo)

local THRESHOLD, INTERVAL, ROW_HEIGHT, ROW_GAP, MAX_ROWS = 5, 0.1, 26, 6, 5 -- 显示阈值(秒), 刷新间隔, 行高, 行间距, 最大显示行数
local ICON_SIZE = 22                                                         -- 技能图标大小 (像素)

-- API 枚举值兼容性处理（防止不同版本客户端报错）
local ENCOUNTER_SOURCE = Enum.EncounterTimelineEventSource and Enum.EncounterTimelineEventSource.Encounter or 0
local HIDDEN = Enum.EncounterTimelineTrackType and Enum.EncounterTimelineTrackType.Hidden
local INDETERMINATE = Enum.EncounterTimelineTrack and Enum.EncounterTimelineTrack.Indeterminate

local cache = addonTable.CenterEventInfoCache

------------------------------------------------------------
-- 工具与辅助函数
------------------------------------------------------------
-- 检查中央倒计时功能是否开启
local function Enabled()
    return DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.centerCountdownEnabled == true
end

-- 安全调用函数，防止 API 抛出错误导致脚本中断
local function Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end

-- 获取事件剩余时间（秒）
local function Remaining(id)
    local r = Safe(C_EncounterTimeline.GetEventTimeRemaining, id)
    return type(r) == "number" and r or nil
end

-- 获取事件信息（优先取本地缓存）
local function EventInfo(id)
    return cache[id] or Safe(C_EncounterTimeline.GetEventInfo, id)
end

------------------------------------------------------------
-- 自定义倒计时管理
------------------------------------------------------------
-- 创建一个自定义倒计时计时条
function addonTable.CustomEncounterBar(iconID, duration, name, unitKey)
    local id = C_EncounterTimeline.AddScriptEvent({
        spellID = 0, 
        iconFileID = iconID or 132117, 
        duration = duration or 10,
        overrideName = name or "未命名提示", 
        icons = 0x1, 
        severity = 2, 
        maxQueueDuration = 0, 
        paused = false,
    })
    if id then
        addonTable.CenterCountdownEvents[id] = true
        -- 如果指定了 unitKey，将事件 ID 绑定到列表中以便后续批量取消
        if unitKey then
            addonTable.TimelineEventKeys[unitKey] = addonTable.TimelineEventKeys[unitKey] or {}
            table.insert(addonTable.TimelineEventKeys[unitKey], id)
        end
    end
    return id
end

-- 取消指定 unitKey 关联的所有自定义倒计时
function addonTable.CancelCustomEncounterBar(unitKey)
    local list = addonTable.TimelineEventKeys[unitKey]
    if not list then return end
    for i = #list, 1, -1 do
        local id = list[i]
        C_EncounterTimeline.CancelScriptEvent(id)
        addonTable.CenterCountdownEvents[id] = nil
        cache[id] = nil
    end
    addonTable.TimelineEventKeys[unitKey] = nil
end

------------------------------------------------------------
-- 校验与事件状态判断
------------------------------------------------------------
-- 判断是否为 Boss 机制事件
local function IsBossEvent(info)
    if not info then return false end
    if issecretvalue and issecretvalue(info.source) then return true end -- 保护强加密/私有值
    return info.source == ENCOUNTER_SOURCE
end

-- 判断事件所属轨道是否被隐藏
local function IsHidden(id)
    local track = Safe(C_EncounterTimeline.GetEventTrack, id)
    if not track then return false end
    if INDETERMINATE and track == INDETERMINATE then return true end
    if issecretvalue and issecretvalue(track) then return false end
    local trackType = Safe(C_EncounterTimeline.GetTrackType, track)
    return HIDDEN and trackType and trackType == HIDDEN
end

-- 判断事件是否处于活跃状态（未完成且未取消）
local function IsActive(id)
    local state = Safe(C_EncounterTimeline.GetEventState, id)
    if not state or (issecretvalue and issecretvalue(state)) then return true end
    return state ~= Enum.EncounterTimelineEventState.Finished and state ~= Enum.EncounterTimelineEventState.Canceled
end

------------------------------------------------------------
-- 锚点框架与拖拽交互
------------------------------------------------------------
-- 创建屏幕中央的核心锚点容器框架
local Base = CreateFrame("Frame", "DiGuaCenterCountdownBase", UIParent)
Base:SetSize(260, 80)
Base:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
Base:SetFrameStrata("HIGH")
Base:SetClampedToScreen(true)

-- 拖拽时的背景指示层
Base.bg = Base:CreateTexture(nil, "BACKGROUND")
Base.bg:SetAllPoints()
Base.bg:SetColorTexture(1, 0.82, 0, 0.25)
Base.bg:Hide()

-- 拖拽时的中心文字提示
Base.txt = Base:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
Base.txt:SetPoint("CENTER")
Base.txt:SetText("中央\n倒计时")
Base.txt:SetTextColor(1, 1, 1, 0.9)
Base.txt:Hide()

-- 开启/关闭 UI 拖拽移动状态
function addonTable.SetCenterCountdownDragEnabled(enabled)
    local show = enabled and Enabled()
    Base.bg:SetShown(show)
    Base.txt:SetShown(show)
    Base:SetMovable(show)
    Base:EnableMouse(show)
end

-- 鼠标按下开始拖拽
Base:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and self:IsMovable() then
        self:StartMoving()
        self.moving = true
    end
end)

-- 鼠标释放停止拖拽并保存坐标到 SavedVariables
Base:SetScript("OnMouseUp", function(self)
    if not self.moving then return end
    self:StopMovingOrSizing()
    self.moving = false
    local _, _, _, x, y = self:GetPoint()
    DiGuaTimelineAudioHelper = DiGuaTimelineAudioHelper or {}
    DiGuaTimelineAudioHelper.centerCountdownX, DiGuaTimelineAudioHelper.centerCountdownY = x, y
end)

------------------------------------------------------------
-- 行 UI 对象管理
------------------------------------------------------------
local rows = {} -- 存储创建的倒计时文本行对象池

-- 工厂函数：创建一个新的计时显示行
local function CreateRow()
    local row = CreateFrame("Frame", nil, Base)
    row:SetSize(380, ROW_HEIGHT)

    -- 图标控件
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- 裁切图标外边框使外观更加精美

    -- 倒计时文本控件
    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    row.Text:SetFont(STANDARD_TEXT_FONT, 18, "OUTLINE")
    -- row.Text:SetShadowColor(0, 0, 0, 0) -- 关闭投影阴影，保留描边
    row.Text:SetWordWrap(false)
    -- 文本稍微右移，为左侧图标腾出 space，确保“图标+文字”整体居中显示
    row.Text:SetPoint("CENTER", row, "CENTER", (ICON_SIZE + 4) / 2, 0)

    -- 将图标锚定在文本的左侧
    row.Icon:SetPoint("RIGHT", row.Text, "LEFT", -4, 0)

    return row
end

-- 隐藏指定下标之后的所有行
local function HideRows(from)
    for i = from, #rows do rows[i]:Hide() end
end

-- 模块功能开启/关闭开关
function addonTable.SetCenterCountdownEnabled(enabled)
    DiGuaTimelineAudioHelper = DiGuaTimelineAudioHelper or {}
    DiGuaTimelineAudioHelper.centerCountdownEnabled = (enabled == true)
    if not enabled then
        HideRows(1)
        wipe(addonTable.CenterCountdownEvents)
    end
end

------------------------------------------------------------
-- 事件监听与生命周期管理
------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")   -- 时间线新增技能事件
eventFrame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED") -- 时间线移除技能事件
eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")              -- 玩家离开游戏世界/传送
eventFrame:RegisterEvent("PLAYER_LOGIN")                      -- 玩家登录

eventFrame:SetScript("OnEvent", function(_, event, arg)
    if event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        -- 当游戏添加新事件时，将其数据提前存入本地缓存，避免每帧重复请求 API
        if arg and arg.id then cache[arg.id] = arg end
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then
        cache[arg] = nil
    elseif event == "PLAYER_LEAVING_WORLD" then
        wipe(cache) -- 切地图时清理缓存
    elseif event == "PLAYER_LOGIN" then
        -- 读取玩家之前保存的位置坐标
        local db = DiGuaTimelineAudioHelper
        if db and db.centerCountdownX and db.centerCountdownY then
            Base:ClearAllPoints()
            Base:SetPoint("CENTER", UIParent, "CENTER", db.centerCountdownX, db.centerCountdownY)
        end
        addonTable.SetCenterCountdownDragEnabled(DiGuaTimelineMainFrame and DiGuaTimelineMainFrame:IsShown())
    end
end)

------------------------------------------------------------
-- 核心主循环逻辑 (OnUpdate)
------------------------------------------------------------
local elapsed, active = 0, {}
local monitor = CreateFrame("Frame")

monitor:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < INTERVAL then return end -- 限制帧率，降低开销 (每 0.1 秒刷新一次)
    elapsed = 0

    if not Enabled() then
        HideRows(1)
        return
    end

    wipe(active)
    local custom = addonTable.CenterCountdownEvents

    --------------------------------------------------------
    -- 1. 处理自定义倒计时事件
    --------------------------------------------------------
    for id in pairs(custom) do
        local remaining = Remaining(id)
        -- 仅筛选出剩余时间在 0 ~ THRESHOLD(5秒) 之间的事件
        if remaining and remaining > 0 and remaining <= THRESHOLD then
            local info = EventInfo(id)
            if info then active[#active + 1] = { id = id, time = remaining, info = info } end
        elseif not remaining or remaining <= 0 then
            -- 超时或失效事件自动清理
            custom[id] = nil
            cache[id] = nil
        end
    end

    --------------------------------------------------------
    -- 2. 处理 Boss 时间线系统事件
    --------------------------------------------------------
    local list = Safe(C_EncounterTimeline.GetSortedEventList, 20)
    if list then
        for _, id in ipairs(list) do
            if not custom[id] then
                local remaining = Remaining(id)
                if remaining and remaining > 0 and remaining <= THRESHOLD then
                    local info = EventInfo(id)
                    -- 严格校验：Boss 事件 & 非隐藏 & 处于活跃状态
                    if info and IsBossEvent(info) and not IsHidden(id) and IsActive(id) then
                        active[#active + 1] = { id = id, time = remaining, info = info }
                    end
                end
            end
        end
    end

    --------------------------------------------------------
    -- 3. 排序 (按剩余时间升序排列，即最急迫的排在最前)
    --------------------------------------------------------
    table.sort(active, function(a, b)
        return a.time ~= b.time and a.time < b.time or a.id < b.id
    end)

    --------------------------------------------------------
    -- 4. UI 渲染与更新显示
    --------------------------------------------------------
    local count = math.min(#active, MAX_ROWS)
    for i = 1, count do
        local item = active[i]
        local row = rows[i] or CreateRow()
        rows[i] = row

        row.eventID, row.eventInfo = item.id, item.info

        -- 提取图标路径（优先顺序：iconFileID -> icon -> 兜底图）
        local iconTexture = item.info.iconFileID or item.info.icon or 132117
        row.Icon:SetTexture(iconTexture)

        -- 拼接技能名称与高亮显示的倒计时秒数
        row.Text:SetText(string.format("%s  |cffffcc00%i|r", item.info.spellName or "", math.ceil(item.time)))

        -- 向上逐级堆叠排列各个倒计时行
        row:ClearAllPoints()
        row:SetPoint("BOTTOM", Base, "CENTER", 0, (i - 1) * (ROW_HEIGHT + ROW_GAP))
        row:Show()
    end

    -- 隐藏未用到的剩余 UI 行
    HideRows(count + 1)
end)