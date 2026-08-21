do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI then return end

local Trace = YUI.Trace or {}
YUI.Trace = Trace

Trace.records = Trace.records or {}
Trace.sequence = Trace.sequence or 0
Trace.maxRecords = Trace.maxRecords or 1200
Trace.enabled = Trace.enabled ~= false
Trace.detailed = Trace.detailed or false
Trace.anomalies = Trace.anomalies or {}
Trace.stageCounts = Trace.stageCounts or {}
Trace.stageFirst = Trace.stageFirst or {}
Trace.collapsed = Trace.collapsed or {}
Trace.maxStageIndex = Trace.maxStageIndex or 0
Trace.viewMode = Trace.viewMode or "timeline"
Trace.zoom = Trace.zoom or 1
Trace.pan = Trace.pan or 0

local TIMELINE_LABEL_WIDTH = 238
local TIMELINE_CHART_X = 248
local TIMELINE_CHART_WIDTH = 690
local TIMELINE_VERDICT_WIDTH = 118
local TIMELINE_ROW_WIDTH = TIMELINE_CHART_X + TIMELINE_CHART_WIDTH + TIMELINE_VERDICT_WIDTH + 16
local TIMELINE_GAP_THRESHOLD_MS = 1000

local unpack = unpack
local sort = table.sort
local tinsert = table.insert
local max = math.max
local min = math.min
local floor = math.floor

local TRACKED_EVENTS = {
    YUI_DB_READY = true,
    YUI_LOGIN_READY = true,
    YUI_WORLD_READY = true,
}

local EXPECTED_ORDER = {
    "ADDON_LOADED:YUI",
    "YUI_DB_READY",
    "PLAYER_LOGIN",
    "YUI_LOGIN_READY",
    "PLAYER_ENTERING_WORLD",
    "YUI_WORLD_READY",
}

local TIMELINE_MILESTONES = {
    { name = "ADDON_LOADED:YUI", label = "ADDON_LOADED", r = 1.00, g = 0.82, b = 0.20, a = 0.95 },
    { name = "PLAYER_LOGIN", label = "PLAYER_LOGIN", r = 0.42, g = 0.68, b = 0.95, a = 0.95 },
    { name = "PLAYER_ENTERING_WORLD", label = "PLAYER_ENTERING_WORLD", r = 0.38, g = 0.92, b = 0.64, a = 0.95 },
}

local EXPECTED_INDEX = {}
for index, name in ipairs(EXPECTED_ORDER) do
    EXPECTED_INDEX[name] = index
end

local GROUP_ORDER = {
    Lifecycle = 1,
    DB = 2,
    Framework = 3,
    EventBus = 4,
    Login = 5,
    World = 6,
    Modules = 7,
    Products = 8,
    Warnings = 99,
}

local GROUP_LABELS = {
    Lifecycle = "生命周期",
    DB = "数据库",
    Framework = "框架",
    EventBus = "事件分发",
    Login = "登录流程",
    World = "进世界",
    Modules = "模块",
    Products = "产品",
    Warnings = "告警",
    Other = "其他",
}

local STATUS_LABELS = {
    ok = "正常",
    error = "错误",
    skip = "跳过",
    running = "运行中",
}

local function Now()
    if debugprofilestop then
        return debugprofilestop()
    end
    if GetTime then
        return GetTime() * 1000
    end
    return 0
end

Trace.originMs = Trace.originMs or Now()

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function FormatMs(value)
    value = tonumber(value)
    if not value then
        return "-"
    end
    if value < 100 then
        return string.format("%.2fms", value)
    end
    return string.format("%.1fms", value)
end

local function ToSeconds(value)
    value = tonumber(value)
    if not value then
        return nil
    end
    return (value - (Trace.originMs or value)) / 1000
end

local function FormatPoint(value)
    local seconds = ToSeconds(value)
    if not seconds then
        return "-"
    end
    return string.format("T+%.2fs", seconds)
end

local function FormatSpan(value)
    value = tonumber(value)
    if not value then
        return "-"
    end
    return string.format("%.2fs", value / 1000)
end

local function FormatDuration(value, kind)
    if kind == "delay" then
        return "计划等待 " .. FormatSpan(value)
    end
    if kind == "async" then
        return "等待 " .. FormatSpan(value)
    end
    return "阻塞 " .. FormatMs(value)
end

local function DisplayGroup(name)
    return GROUP_LABELS[name] or tostring(name or "其他")
end

local function DisplayStatus(status)
    return STATUS_LABELS[status] or tostring(status or "正常")
end

local function DurationTone(value, isGroup, status)
    if status == "error" then
        return "error"
    end
    value = tonumber(value)
    if not value then
        return "muted"
    end
    if isGroup then
        if value < 30 then return "fast" end
        if value <= 100 then return "warn" end
        return "slow"
    end
    if value < 5 then return "fast" end
    if value <= 20 then return "warn" end
    return "slow"
end

local function WaitTone(value, blocking)
    value = tonumber(value)
    blocking = tonumber(blocking) or 0
    if not value then
        return "muted"
    end
    if blocking >= 30 then
        return DurationTone(blocking, true, "ok")
    end
    if value >= 1000 then
        return "warn"
    end
    return "fast"
end

local function SetTone(fontString, tone)
    if not fontString or not fontString.SetTextColor then return end
    if tone == "fast" then
        fontString:SetTextColor(0.48, 0.88, 0.66, 1)
    elseif tone == "warn" then
        fontString:SetTextColor(1, 0.83, 0.38, 1)
    elseif tone == "slow" or tone == "error" then
        fontString:SetTextColor(1, 0.42, 0.42, 1)
    else
        fontString:SetTextColor(0.67, 0.74, 0.82, 1)
    end
end

local function Print(...)
    if YUI.Print then
        YUI:Print(...)
    elseif print then
        print(...)
    end
end

local function EscapeJSON(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub("\"", "\\\"")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return value
end

local function NormalizeRecordOptions(detail, options)
    if type(detail) == "table" and options == nil then
        options = detail
        detail = options.detail
    end
    return detail, type(options) == "table" and options or {}
end

local function CopyRecordFields(record, options)
    if type(options) ~= "table" then
        return
    end
    if options.durationKind ~= nil then record.durationKind = options.durationKind end
    if options.blocking ~= nil then record.blocking = options.blocking end
    if options.moduleId ~= nil then record.moduleId = options.moduleId end
    if options.phase ~= nil then record.phase = options.phase end
    if options.traceName ~= nil then record.traceName = options.traceName end
    if options.delaySeconds ~= nil then record.delaySeconds = options.delaySeconds end
    if options.nextAction ~= nil then record.nextAction = options.nextAction end
end

local function IsBlocking(record)
    return record and record.type == "measure" and record.duration and record.blocking ~= false and record.durationKind ~= "async" and record.durationKind ~= "delay"
end

local function IsSyncMeasure(record)
    return record and record.type == "measure" and record.duration and record.durationKind ~= "async" and record.durationKind ~= "delay"
end

local function IsAsyncMeasure(record)
    return record and record.type == "measure" and record.duration and record.durationKind == "async"
end

local DescribeVerdict

local function Utf8Shorten(text, limit)
    text = tostring(text or "")
    limit = tonumber(limit) or 80
    local count = 0
    local bytes = 0
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        bytes = bytes + #char
        if count > limit then
            return text:sub(1, bytes - #char) .. "..."
        end
    end
    return text
end

local function ShortenPath(path)
    path = tostring(path or ""):gsub("\\", "/")
    path = path:gsub("^.-Interface/AddOns/", "")
    path = path:gsub("^.-/AddOns/", "")
    path = path:gsub("^.-/YUI/", "YUI/")
    return path
end

local function CompactDetail(detail)
    if not detail or detail == "" then
        return ""
    end
    detail = tostring(detail)
    if detail:match("^table:%s*") then
        return "owner table"
    end
    detail = detail:gsub("source=([^%s]+)", function(path)
        return "source=" .. ShortenPath(path)
    end)
    detail = detail:gsub("Interface/AddOns/", "")
    detail = detail:gsub("Interface\\AddOns\\", "")
    return Utf8Shorten(detail, 92)
end

local function MakeItemText(item)
    local name = tostring(item.displayName or item.name or "unknown")
    local detail = item.displayDetail
    if detail == nil then
        detail = CompactDetail(item.detail)
    end
    local status = item.status and item.status ~= "ok" and (" 状态=" .. DisplayStatus(item.status)) or ""
    local err = item.error and (" 错误=" .. Utf8Shorten(item.error, 50)) or ""
    if detail ~= "" then
        return Utf8Shorten(name .. "  " .. detail .. status .. err, 76)
    end
    return Utf8Shorten(name .. status .. err, 76)
end

local function RecordStart(record)
    return record and (record.start or record.time) or 0
end

local function RecordFinish(record)
    if not record then
        return 0
    end
    return record.finish or record.start or record.time or 0
end

local function RecordSpan(record)
    local first = RecordStart(record)
    local last = RecordFinish(record)
    return max(0, last - first)
end

local function RecordLane(record)
    local group = record and record.group or "Other"
    if group == "Modules" and record.moduleId and record.moduleId ~= "" then
        return "模块 / " .. tostring(record.moduleId)
    end
    if group == "Products" and record.moduleId and record.moduleId ~= "" then
        return "产品 / " .. tostring(record.moduleId)
    end
    if group == "EventBus" then
        return "事件分发"
    end
    return DisplayGroup(group)
end

local function ShouldShowOnTimeline(record)
    if not record then
        return false
    end
    if record.group == "EventBus" and not Trace.detailed then
        local name = tostring(record.name or "")
        return name:find("YUI_DB_READY", 1, true) or name:find("YUI_LOGIN_READY", 1, true) or name:find("YUI_WORLD_READY", 1, true)
    end
    return true
end

local function GetRecordTone(record)
    if not record then
        return "muted"
    end
    if record.status == "error" then
        return "error"
    end
    if record.group == "Warnings" then
        return "error"
    end
    if record.durationKind == "delay" then
        return "delay"
    end
    if record.durationKind == "async" then
        return "async"
    end
    return DurationTone(record.duration or 0, false, record.status)
end

local function ApplyTextureTone(texture, tone)
    if not texture then
        return
    end
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    if tone == "fast" then
        texture:SetVertexColor(0.35, 0.86, 0.56, 0.9)
    elseif tone == "warn" then
        texture:SetVertexColor(1, 0.78, 0.25, 0.92)
    elseif tone == "slow" then
        texture:SetVertexColor(1, 0.38, 0.28, 0.94)
    elseif tone == "async" then
        texture:SetVertexColor(0.42, 0.68, 0.95, 0.58)
    elseif tone == "delay" then
        texture:SetVertexColor(0.40, 0.55, 0.72, 0.34)
    elseif tone == "gap" then
        texture:SetVertexColor(0.45, 0.5, 0.62, 0.26)
    elseif tone == "error" then
        texture:SetVertexColor(1, 0.18, 0.28, 0.96)
    else
        texture:SetVertexColor(0.55, 0.63, 0.72, 0.75)
    end
end

local function GetTraceRange(records)
    local first, last
    for _, record in ipairs(records or {}) do
        if ShouldShowOnTimeline(record) then
            local start = RecordStart(record)
            local finish = RecordFinish(record)
            if start and start > 0 then
                first = first and min(first, start) or start
                last = last and max(last, finish or start) or (finish or start)
            end
        end
    end
    first = first or (Trace.originMs or 0)
    last = last or first
    if last <= first then
        last = first + 1
    end
    return first, last, last - first
end

local function BuildTimelineGaps(records, first, last)
    local items = {}
    for _, record in ipairs(records or {}) do
        if ShouldShowOnTimeline(record) then
            items[#items + 1] = {
                first = RecordStart(record),
                last = RecordFinish(record),
            }
        end
    end
    sort(items, function(a, b)
        if a.first ~= b.first then return a.first < b.first end
        return a.last < b.last
    end)

    local gaps = {}
    local cursor = first
    for _, item in ipairs(items) do
        if item.first and item.first > cursor + TIMELINE_GAP_THRESHOLD_MS then
            gaps[#gaps + 1] = {
                first = cursor,
                last = item.first,
                duration = item.first - cursor,
            }
        end
        if item.last and item.last > cursor then
            cursor = item.last
        end
    end
    if last and cursor and last > cursor + TIMELINE_GAP_THRESHOLD_MS then
        gaps[#gaps + 1] = {
            first = cursor,
            last = last,
            duration = last - cursor,
        }
    end
    return gaps
end

local function FormatRecordTooltip(record)
    if not record then
        return ""
    end
    local lines = {
        "分组=" .. DisplayGroup(record.group),
        "名称=" .. tostring(record.name or ""),
        "开始=" .. FormatPoint(RecordStart(record)),
        "结束=" .. FormatPoint(RecordFinish(record)),
    }
    if record.duration then
        lines[#lines + 1] = "耗时=" .. FormatDuration(record.duration, record.durationKind)
    end
    if record.moduleId then
        lines[#lines + 1] = "模块=" .. tostring(record.moduleId)
    end
    if record.phase then
        lines[#lines + 1] = "阶段=" .. tostring(record.phase)
    end
    if record.delaySeconds then
        lines[#lines + 1] = "计划等待=" .. string.format("%.2fs", tonumber(record.delaySeconds) or 0)
    end
    if record.nextAction then
        lines[#lines + 1] = "后续动作=" .. tostring(record.nextAction)
    end
    if record.detail then
        lines[#lines + 1] = "详情=" .. tostring(record.detail)
    end
    if record.error then
        lines[#lines + 1] = "错误=" .. tostring(record.error)
    end
    return table.concat(lines, "\n")
end

local function BuildTimelineLanes(records)
    local laneMap = {}
    local lanes = {}
    for _, record in ipairs(records or {}) do
        if ShouldShowOnTimeline(record) then
            local laneName = RecordLane(record)
            local lane = laneMap[laneName]
            if not lane then
                lane = {
                    name = laneName,
                    group = record.group,
                    items = {},
                    first = RecordStart(record),
                    last = RecordFinish(record),
                    blockingTotal = 0,
                    errorCount = 0,
                }
                laneMap[laneName] = lane
                lanes[#lanes + 1] = lane
            end
            lane.items[#lane.items + 1] = record
            lane.first = min(lane.first or RecordStart(record), RecordStart(record))
            lane.last = max(lane.last or RecordFinish(record), RecordFinish(record))
            if IsBlocking(record) then
                lane.blockingTotal = lane.blockingTotal + record.duration
            end
            if record.status == "error" then
                lane.errorCount = lane.errorCount + 1
            end
        end
    end

    sort(lanes, function(a, b)
        local ag = GROUP_ORDER[a.group] or 50
        local bg = GROUP_ORDER[b.group] or 50
        if ag ~= bg then return ag < bg end
        local af = a.first or 0
        local bf = b.first or 0
        if af ~= bf then return af < bf end
        return tostring(a.name) < tostring(b.name)
    end)

    for _, lane in ipairs(lanes) do
        sort(lane.items, function(a, b)
            local af = RecordStart(a)
            local bf = RecordStart(b)
            if af ~= bf then return af < bf end
            return (a.seq or 0) < (b.seq or 0)
        end)
        lane.span = max(0, (lane.last or 0) - (lane.first or 0))
        lane.verdict = DescribeVerdict(lane.blockingTotal, max(0, lane.span - lane.blockingTotal), lane.errorCount)
    end
    return lanes
end

local function EncodeJSON(value, seen)
    local valueType = type(value)
    if valueType == "nil" then
        return "null"
    elseif valueType == "boolean" then
        return value and "true" or "false"
    elseif valueType == "number" then
        return tostring(value)
    elseif valueType == "string" then
        return "\"" .. EscapeJSON(value) .. "\""
    elseif valueType ~= "table" then
        return "\"" .. EscapeJSON(value) .. "\""
    end

    seen = seen or {}
    if seen[value] then
        return "\"<cycle>\""
    end
    seen[value] = true

    local isArray = true
    local maxIndex = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            isArray = false
            break
        end
        if key > maxIndex then
            maxIndex = key
        end
    end

    local parts = {}
    if isArray then
        for index = 1, maxIndex do
            parts[#parts + 1] = EncodeJSON(value[index], seen)
        end
        seen[value] = nil
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = tostring(key)
    end
    sort(keys)
    for _, key in ipairs(keys) do
        parts[#parts + 1] = "\"" .. EscapeJSON(key) .. "\":" .. EncodeJSON(value[key], seen)
    end
    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

function Trace:Reset()
    self.records = {}
    self.sequence = 0
    self.anomalies = {}
    self.stageCounts = {}
    self.stageFirst = {}
    self.maxStageIndex = 0
    self.originMs = Now()
end

function Trace:AddRecord(record)
    if not self.enabled then
        return record
    end
    self.sequence = (self.sequence or 0) + 1
    record.seq = self.sequence
    record.start = record.start or Now()
    record.time = record.start
    record.startSec = ToSeconds(record.start)
    record.timeSec = record.startSec
    record.status = record.status or "ok"
    record.group = record.group or "Other"
    record.name = record.name or "unknown"
    record.type = record.type or "mark"
    if record.type == "measure" then
        record.durationKind = record.durationKind or "sync"
        if record.blocking == nil then
            record.blocking = record.durationKind ~= "async" and record.durationKind ~= "delay"
        end
    else
        record.blocking = false
    end
    self.records[#self.records + 1] = record
    while #self.records > (self.maxRecords or 1200) do
        table.remove(self.records, 1)
    end
    return record
end

function Trace:Mark(group, name, detail, status, options)
    detail, options = NormalizeRecordOptions(detail, options)
    local record = {
        group = group,
        name = name,
        detail = detail,
        type = "mark",
        status = status or "ok",
    }
    CopyRecordFields(record, options)
    return self:AddRecord(record)
end

function Trace:Begin(group, name, detail, options)
    detail, options = NormalizeRecordOptions(detail, options)
    local record = {
        group = group,
        name = name,
        detail = detail,
        type = "measure",
        status = "running",
    }
    CopyRecordFields(record, options)
    return self:AddRecord(record)
end

function Trace:Finish(record, status, err, detail, options)
    if type(record) ~= "table" then
        return nil
    end
    if type(detail) == "table" and options == nil then
        options = detail
        detail = options.detail
    end
    record.finish = Now()
    record.duration = math.max(0, record.finish - (record.start or record.finish))
    record.finishSec = ToSeconds(record.finish)
    record.durationMs = record.duration
    record.status = status or "ok"
    CopyRecordFields(record, options)
    if record.type == "measure" then
        record.durationKind = record.durationKind or "sync"
        if record.blocking == nil then
            record.blocking = record.durationKind ~= "async" and record.durationKind ~= "delay"
        end
    end
    if err then
        record.error = tostring(err)
    end
    if detail then
        record.detail = detail
    end
    return record
end

function Trace:Measure(group, name, fn, detail, options)
    if type(fn) ~= "function" then
        return nil
    end
    local record = self:Begin(group, name, detail, options)
    local results = Pack(pcall(fn))
    if results[1] then
        self:Finish(record, "ok")
        return unpack(results, 2, results.n)
    end
    self:Finish(record, "error", results[2])
    error(results[2], 0)
end

function Trace:ShouldMeasureListener(event)
    if self.detailed or YUI.IsDev then
        return true
    end
    return TRACKED_EVENTS[event] == true
end

function Trace:Anomaly(title, detail, kind)
    local now = Now()
    local item = {
        title = tostring(title or "Trace 异常"),
        detail = tostring(detail or ""),
        kind = kind or "general",
        time = now,
        timeSec = ToSeconds(now),
    }
    self.anomalies[#self.anomalies + 1] = item
    self:Mark("Warnings", item.title, item.detail, "error")
    return item
end

function Trace:RecordStage(name, group, detail)
    local count = (self.stageCounts[name] or 0) + 1
    self.stageCounts[name] = count
    if not self.stageFirst[name] then
        self.stageFirst[name] = Now()
    elseif count > 1 then
        self:Anomaly("阶段重复", name .. " 已触发 " .. tostring(count) .. " 次", "order")
    end

    local expectedIndex = EXPECTED_INDEX[name]
    if expectedIndex then
        if expectedIndex < (self.maxStageIndex or 0) then
            self:Anomaly("阶段顺序异常", name .. " 在更靠后的阶段之后才触发", "order")
        end
        for index = 1, expectedIndex - 1 do
            local expectedName = EXPECTED_ORDER[index]
            if not self.stageFirst[expectedName] then
                self:Anomaly("缺失前置阶段", expectedName .. " 未在 " .. name .. " 之前出现", "order")
            end
        end
        if expectedIndex > (self.maxStageIndex or 0) then
            self.maxStageIndex = expectedIndex
        end
    end

    return self:Mark(group or "Lifecycle", name, detail, "ok")
end

function Trace:GetMissingStages()
    local missing = {}
    for _, name in ipairs(EXPECTED_ORDER) do
        if not self.stageFirst[name] then
            missing[#missing + 1] = name
        end
    end
    return missing
end

function Trace:RecordDBAccessBeforeReady(apiName, productId, source)
    if not source and type(debugstack) == "function" then
        local ok, stack = pcall(debugstack, 2, 12, 0)
        if not ok then
            ok, stack = pcall(debugstack)
        end
        if ok and type(stack) == "string" then
            local fallback
            for line in stack:gmatch("[^\r\n]+") do
                local file, lineNo = line:match('@([^"]+%.lua)"]:(%d+)')
                if not file then
                    file, lineNo = line:match('@([^:]+%.lua):(%d+)')
                end
                if not file then
                    file, lineNo = line:match('([^%s"]+%.lua):(%d+)')
                end
                if file and lineNo then
                    local candidate = file .. ":" .. lineNo
                    fallback = fallback or candidate
                    if not candidate:find("YUI.lua", 1, true) and not candidate:find("Core/Trace.lua", 1, true) and not candidate:find("Core\\Trace.lua", 1, true) then
                        source = candidate
                        break
                    end
                end
            end
            source = source or fallback
        end
    end
    local detail = tostring(apiName or "DB") .. " product=" .. tostring(productId or "suite")
    if source then
        detail = detail .. " source=" .. source
    end
    self:Anomaly("DB 未就绪访问", detail, "db")
end

function Trace:RecordDBSplit(productId, db, savedVariableName)
    local raw = savedVariableName and _G[savedVariableName] or nil
    if db and raw and db.sv ~= raw then
        self:Anomaly("DB 表分裂", tostring(productId or "suite") .. " db.sv ~= _G." .. tostring(savedVariableName), "db")
    end
end

function Trace:GetGroups()
    local groups = {}
    local order = {}
    for _, record in ipairs(self.records or {}) do
        local groupName = record.group or "Other"
        local group = groups[groupName]
        if not group then
            group = {
                name = groupName,
                items = {},
                total = 0,
                blockingTotal = 0,
                syncTotal = 0,
                asyncTotal = 0,
                first = record.start or record.time or 0,
                last = record.finish or record.start or record.time or 0,
                errorCount = 0,
            }
            groups[groupName] = group
            order[#order + 1] = group
        end

        group.items[#group.items + 1] = record
        local first = record.start or record.time or 0
        local last = record.finish or record.start or record.time or first
        if first < group.first then group.first = first end
        if last > group.last then group.last = last end
        if record.duration then
            group.total = group.total + record.duration
            if IsSyncMeasure(record) then
                group.syncTotal = group.syncTotal + record.duration
            end
            if IsAsyncMeasure(record) then
                group.asyncTotal = group.asyncTotal + record.duration
                if not group.slowestAsync or record.duration > (group.slowestAsync.duration or 0) then
                    group.slowestAsync = record
                end
            end
            if IsBlocking(record) then
                group.blockingTotal = group.blockingTotal + record.duration
                if not group.slowestBlocking or record.duration > (group.slowestBlocking.duration or 0) then
                    group.slowestBlocking = record
                end
            end
            if not group.slowest or record.duration > (group.slowest.duration or 0) then
                group.slowest = record
            end
        end
        if record.status == "error" then
            group.errorCount = group.errorCount + 1
        end
    end

    for _, group in ipairs(order) do
        group.span = max(0, (group.last or 0) - (group.first or 0))
        group.waitInterval = max(0, group.span - (group.blockingTotal or 0))
    end

    sort(order, function(a, b)
        local af = a.first or 0
        local bf = b.first or 0
        if af ~= bf then return af < bf end
        return (GROUP_ORDER[a.name] or 50) < (GROUP_ORDER[b.name] or 50)
    end)
    return order
end

function Trace:GetModuleStats()
    local statsById = {}
    local stats = {}
    for _, record in ipairs(self.records or {}) do
        local moduleId = record.moduleId
        if moduleId and moduleId ~= "" then
            local stat = statsById[moduleId]
            if not stat then
                stat = {
                    moduleId = moduleId,
                    records = 0,
                    blockingTotal = 0,
                    syncTotal = 0,
                    asyncTotal = 0,
                    first = record.start or record.time or 0,
                    last = record.finish or record.start or record.time or 0,
                    errorCount = 0,
                }
                statsById[moduleId] = stat
                stats[#stats + 1] = stat
            end
            stat.records = stat.records + 1
            local first = record.start or record.time or 0
            local last = record.finish or record.start or record.time or first
            if first < stat.first then stat.first = first end
            if last > stat.last then stat.last = last end
            if IsSyncMeasure(record) then
                stat.syncTotal = stat.syncTotal + record.duration
            end
            if IsAsyncMeasure(record) then
                stat.asyncTotal = stat.asyncTotal + record.duration
                if not stat.slowestAsync or record.duration > (stat.slowestAsync.duration or 0) then
                    stat.slowestAsync = record
                end
            end
            if IsBlocking(record) then
                stat.blockingTotal = stat.blockingTotal + record.duration
                if not stat.slowestBlocking or record.duration > (stat.slowestBlocking.duration or 0) then
                    stat.slowestBlocking = record
                end
            end
            if record.status == "error" then
                stat.errorCount = stat.errorCount + 1
            end
        end
    end

    for _, stat in ipairs(stats) do
        stat.span = max(0, (stat.last or 0) - (stat.first or 0))
        stat.waitInterval = max(0, stat.span - (stat.blockingTotal or 0))
    end

    sort(stats, function(a, b)
        if (a.blockingTotal or 0) ~= (b.blockingTotal or 0) then
            return (a.blockingTotal or 0) > (b.blockingTotal or 0)
        end
        if (a.span or 0) ~= (b.span or 0) then
            return (a.span or 0) > (b.span or 0)
        end
        return tostring(a.moduleId) < tostring(b.moduleId)
    end)
    return stats
end

function Trace:GetSlowestItem()
    local slowest
    for _, record in ipairs(self.records or {}) do
        if record.duration and (not slowest or record.duration > (slowest.duration or 0)) then
            slowest = record
        end
    end
    return slowest
end

local function AggregateWarnings(items)
    local map = {}
    local order = {}
    for _, item in ipairs(items or {}) do
        local key = tostring(item.name or "") .. "\001" .. tostring(item.detail or "")
        local aggregate = map[key]
        if not aggregate then
            aggregate = {
                source = item,
                count = 0,
                name = item.name,
                detail = item.detail,
                status = item.status,
                error = item.error,
                type = item.type,
                start = item.start,
                duration = item.duration,
                durationKind = item.durationKind,
                blocking = item.blocking,
            }
            map[key] = aggregate
            order[#order + 1] = aggregate
        end
        aggregate.count = aggregate.count + 1
        if item.start and (not aggregate.start or item.start < aggregate.start) then
            aggregate.start = item.start
        end
    end

    local result = {}
    for _, aggregate in ipairs(order) do
        local item = aggregate.source
        local copy = {}
        for key, value in pairs(item) do
            copy[key] = value
        end
        if aggregate.count > 1 then
            copy.displayName = tostring(item.name or "告警") .. " x" .. tostring(aggregate.count)
        end
        copy.displayDetail = CompactDetail(item.detail)
        result[#result + 1] = copy
    end
    return result
end

local function GetDisplayItems(group)
    if group and group.name == "Warnings" then
        return AggregateWarnings(group.items)
    end
    return group and group.items or {}
end

function DescribeVerdict(blocking, wait, errors)
    blocking = tonumber(blocking) or 0
    wait = tonumber(wait) or 0
    errors = tonumber(errors) or 0
    if errors > 0 then
        return "错误"
    end
    if blocking > 100 then
        return "卡"
    end
    if blocking >= 30 then
        return "偏慢"
    end
    if wait >= 1000 then
        return "等待长"
    end
    return "正常"
end

local function SetRowTooltip(row, title, detail)
    row._traceTipTitle = title
    row._traceTipDetail = detail
    if title or detail then
        row:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self._traceTipTitle then
                GameTooltip:SetText(self._traceTipTitle, 1, 0.82, 0)
            end
            if self._traceTipDetail and self._traceTipDetail ~= "" then
                GameTooltip:AddLine(self._traceTipDetail, 0.82, 0.87, 0.94, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            if GameTooltip then
                YUI.HideGameTooltip()
            end
        end)
    else
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
    end
end

function Trace:ExportJSON()
    return EncodeJSON({
        generatedAt = date and date("%Y-%m-%d %H:%M:%S") or nil,
        originMs = self.originMs,
        detailed = self.detailed,
        expectedOrder = EXPECTED_ORDER,
        missingStages = self:GetMissingStages(),
        moduleStats = self:GetModuleStats(),
        anomalies = self.anomalies,
        records = self.records,
    })
end

local function FrameTemplate()
    if _G.BackdropTemplateMixin then
        return "BackdropTemplate"
    end
    return nil
end

local function GetGUI2()
    local gui = YUI and YUI.GUI2
    if gui and gui.CreateFrame then
        return gui
    end
    return nil
end

function Trace:CreateButton(parent, text, width, height)
    local GUI2 = GetGUI2()
    if GUI2 and GUI2.CreateButton then
        return GUI2:CreateButton(parent, text or "", width or 90, height or 22)
    end

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 90, height or 22)
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(text or "")
    return button
end

function Trace:SetViewMode(mode)
    self.viewMode = mode or "timeline"
    self:RenderWindow()
end

function Trace:SetZoom(value)
    value = tonumber(value) or 1
    if value < 1 then value = 1 end
    if value > 8 then value = 8 end
    self.zoom = value
    if value == 1 then
        self.pan = 0
    end
    self:RenderWindow()
end

function Trace:GetTimelineMaxPan()
    return tonumber(self.maxTimelinePan) or 0
end

function Trace:SetTimelinePan(value)
    local maxPan = self:GetTimelineMaxPan()
    self.pan = min(max(0, tonumber(value) or 0), maxPan)
    self:RenderWindow()
end

function Trace:PanTimeline(delta)
    self:SetTimelinePan((tonumber(self.pan) or 0) + (tonumber(delta) or 0))
end

function Trace:ZoomTimeline(delta, anchorRatio)
    local oldZoom = tonumber(self.zoom) or 1
    local newZoom = oldZoom + (delta or 0)
    if newZoom < 1 then newZoom = 1 end
    if newZoom > 8 then newZoom = 8 end
    if newZoom == oldZoom then
        return
    end

    local chartWidth = TIMELINE_CHART_WIDTH
    local oldVirtual = chartWidth * oldZoom
    local newVirtual = chartWidth * newZoom
    local anchor = min(max(tonumber(anchorRatio) or 0.5, 0), 1) * chartWidth
    local worldPixel = (tonumber(self.pan) or 0) + anchor
    self.zoom = newZoom
    self.maxTimelinePan = max(0, newVirtual - chartWidth)
    self.pan = min(max(0, (worldPixel / oldVirtual) * newVirtual - anchor), self.maxTimelinePan)
    self:RenderWindow()
end

function Trace:GetCursorRatio(frame)
    if not frame or not frame.GetLeft or not frame.GetWidth or not GetCursorPosition then
        return 0.5
    end
    local cursorX = GetCursorPosition()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or (UIParent and UIParent:GetEffectiveScale()) or 1
    local left = frame:GetLeft()
    local width = frame:GetWidth()
    if not cursorX or not left or not width or width <= 0 then
        return 0.5
    end
    local x = cursorX / scale - left
    return min(max(x / width, 0), 1)
end

function Trace:HandleTimelineMouseWheel(delta, frame)
    self:ZoomTimeline(delta and delta > 0 and 1 or -1, self:GetCursorRatio(frame))
end

function Trace:BeginTimelineDrag(frame)
    if not frame or not GetCursorPosition then
        return
    end
    local cursorX = GetCursorPosition()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or (UIParent and UIParent:GetEffectiveScale()) or 1
    self.timelineDragStartX = cursorX / scale
    self.timelineDragStartPan = tonumber(self.pan) or 0
end

function Trace:EndTimelineDrag(frame)
    if not self.timelineDragStartX or not GetCursorPosition then
        return
    end
    local cursorX = GetCursorPosition()
    local scale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or (UIParent and UIParent:GetEffectiveScale()) or 1
    local dx = cursorX / scale - self.timelineDragStartX
    self.timelineDragStartX = nil
    self:SetTimelinePan((tonumber(self.timelineDragStartPan) or 0) - dx)
end

function Trace:AttachTimelineInput(frame)
    if not frame then
        return
    end
    frame:EnableMouse(true)
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(owner, delta)
            Trace:HandleTimelineMouseWheel(delta, owner)
        end)
    end
    frame:SetScript("OnMouseDown", function(owner, button)
        if button == "LeftButton" then
            Trace:BeginTimelineDrag(owner)
        end
    end)
    frame:SetScript("OnMouseUp", function(owner, button)
        if button == "LeftButton" then
            Trace:EndTimelineDrag(owner)
        end
    end)
end

function Trace:CreateWindow()
    if self.window then
        return self.window
    end

    local GUI2 = GetGUI2()
    local frame
    if GUI2 and GUI2.CreateFrame then
        frame = GUI2:CreateFrame(UIParent, {
            name = "YUITraceFrame",
            template = FrameTemplate(),
            width = 1120,
            height = 680,
            frameStrata = "DIALOG",
            mouse = true,
            movable = true,
            drag = "LeftButton",
            surface = "color.surface.window",
            border = "color.border.default",
            shadow = true,
        })
    else
        frame = CreateFrame("Frame", "YUITraceFrame", UIParent, FrameTemplate())
        frame:SetSize(1120, 680)
        frame:SetFrameStrata("DIALOG")
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    end
    frame:SetPoint("CENTER")
    if not GUI2 and frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.05, 0.06, 0.08, 0.94)
        frame:SetBackdropBorderColor(0.2, 0.25, 0.33, 1)
    end

    if GUI2 and GUI2.CreateText then
        frame.title = GUI2:CreateText(frame, "YUI 加载时间轴", "font.size.title", "color.text.heading")
    else
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetText("YUI 加载时间轴")
    end
    frame.title:SetPoint("TOPLEFT", 16, -14)

    if GUI2 and GUI2.CreateText then
        frame.summary = GUI2:CreateText(frame, "", "font.size.sm", "color.text.secondary")
    else
        frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.summary:SetTextColor(0.7, 0.76, 0.84, 1)
    end
    frame.summary:SetPoint("TOPLEFT", 16, -40)

    frame.timelineTab = self:CreateButton(frame, "时间轴", 68, 22)
    frame.timelineTab:SetPoint("TOPLEFT", 16, -62)
    frame.timelineTab:SetScript("OnClick", function() Trace:SetViewMode("timeline") end)

    frame.listTab = self:CreateButton(frame, "列表", 56, 22)
    frame.listTab:SetPoint("LEFT", frame.timelineTab, "RIGHT", 6, 0)
    frame.listTab:SetScript("OnClick", function() Trace:SetViewMode("list") end)

    frame.modulesTab = self:CreateButton(frame, "模块榜", 68, 22)
    frame.modulesTab:SetPoint("LEFT", frame.listTab, "RIGHT", 6, 0)
    frame.modulesTab:SetScript("OnClick", function() Trace:SetViewMode("modules") end)

    frame.eventsTab = self:CreateButton(frame, "事件", 56, 22)
    frame.eventsTab:SetPoint("LEFT", frame.modulesTab, "RIGHT", 6, 0)
    frame.eventsTab:SetScript("OnClick", function() Trace:SetViewMode("events") end)

    frame.anomaliesTab = self:CreateButton(frame, "异常", 56, 22)
    frame.anomaliesTab:SetPoint("LEFT", frame.eventsTab, "RIGHT", 6, 0)
    frame.anomaliesTab:SetScript("OnClick", function() Trace:SetViewMode("anomalies") end)

    frame.close = self:CreateButton(frame, "关闭", 64, 22)
    frame.close:SetPoint("TOPRIGHT", -12, -12)
    frame.close:SetScript("OnClick", function() frame:Hide() end)

    frame.refresh = self:CreateButton(frame, "刷新", 72, 22)
    frame.refresh:SetPoint("RIGHT", frame.close, "LEFT", -8, 0)
    frame.refresh:SetScript("OnClick", function() Trace:RenderWindow() end)

    frame.export = self:CreateButton(frame, "导出", 72, 22)
    frame.export:SetPoint("RIGHT", frame.refresh, "LEFT", -8, 0)
    frame.export:SetScript("OnClick", function() Trace:OpenExport() end)

    local scroll
    local content
    if GUI2 and GUI2.CreateScrollFrame then
        scroll = GUI2:CreateScrollFrame(frame, {
            childWidth = TIMELINE_ROW_WIDTH,
            childHeight = 1,
        })
        content = scroll.scrollChild or scroll.child
    else
        scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        content = CreateFrame("Frame", nil, scroll)
        content:SetSize(TIMELINE_ROW_WIDTH, 1)
        scroll:SetScrollChild(content)
    end
    scroll:SetPoint("TOPLEFT", 16, -92)
    scroll:SetPoint("BOTTOMRIGHT", -34, 38)
    content:SetSize(TIMELINE_ROW_WIDTH, 1)
    frame.scroll = scroll
    frame.content = content
    frame.rows = {}

    local slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("BOTTOMLEFT", 264, 16)
    slider:SetPoint("BOTTOMRIGHT", -164, 16)
    slider:SetHeight(14)
    slider:SetMinMaxValues(0, 1)
    slider:SetValue(0)
    if GUI2 and GUI2.SkinSlider then
        GUI2:SkinSlider(slider)
    else
        slider.track = slider:CreateTexture(nil, "BACKGROUND")
        slider.track:SetAllPoints()
        slider.track:SetTexture("Interface\\Buttons\\WHITE8x8")
        slider.track:SetVertexColor(0.16, 0.19, 0.25, 0.78)
        slider.thumb = slider:CreateTexture(nil, "OVERLAY")
        slider.thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
        slider.thumb:SetVertexColor(1, 0.82, 0, 0.9)
        slider.thumb:SetSize(54, 12)
        slider:SetThumbTexture(slider.thumb)
    end
    slider:SetScript("OnValueChanged", function(_, value)
        if Trace.updatingTimelineSlider then
            return
        end
        Trace.pan = tonumber(value) or 0
        Trace:RenderWindow()
    end)
    frame.timelineSlider = slider

    self.window = frame
    return frame
end

function Trace:AcquireRow(parent, index)
    local row = parent.rows and parent.rows[index]
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Button", nil, parent)
    row:SetSize(TIMELINE_ROW_WIDTH, 20)
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.left:SetPoint("LEFT", 0, 0)
    row.left:SetPoint("RIGHT", -440, 0)
    row.left:SetJustifyH("LEFT")
    if row.left.SetWordWrap then row.left:SetWordWrap(false) end
    if row.left.SetNonSpaceWrap then row.left:SetNonSpaceWrap(false) end
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.right:SetPoint("RIGHT", -4, 0)
    row.right:SetJustifyH("RIGHT")
    row.right:SetWidth(430)
    if row.right.SetWordWrap then row.right:SetWordWrap(false) end
    if row.right.SetNonSpaceWrap then row.right:SetNonSpaceWrap(false) end
    parent.rows[index] = row
    return row
end

function Trace:AcquireTimelineRow(parent, index)
    parent.timelineRows = parent.timelineRows or {}
    local row = parent.timelineRows[index]
    if row then
        row:Show()
        return row
    end

    row = CreateFrame("Frame", nil, parent)
    row:SetSize(TIMELINE_ROW_WIDTH, 26)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWidth(TIMELINE_LABEL_WIDTH)
    row.label:SetScale(0.9)
    if row.label.SetWordWrap then row.label:SetWordWrap(false) end
    if row.label.SetNonSpaceWrap then row.label:SetNonSpaceWrap(false) end

    row.chart = CreateFrame("Frame", nil, row)
    row.chart:SetPoint("LEFT", TIMELINE_CHART_X, 0)
    row.chart:SetSize(TIMELINE_CHART_WIDTH, 22)
    row.bg = row.chart:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.bg:SetVertexColor(0.12, 0.15, 0.2, 0.38)
    self:AttachTimelineInput(row.chart)

    row.verdict = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.verdict:SetPoint("LEFT", row.chart, "RIGHT", 10, 0)
    row.verdict:SetJustifyH("LEFT")
    row.verdict:SetWidth(TIMELINE_VERDICT_WIDTH)

    row.bars = {}
    row.ticks = {}
    row.texts = {}
    row.milestones = {}
    row.milestoneTexts = {}
    parent.timelineRows[index] = row
    return row
end

local function HideTimelineRow(row)
    if not row then return end
    row:Hide()
    if row.bars then
        for _, bar in ipairs(row.bars) do
            bar:Hide()
            SetRowTooltip(bar, nil, nil)
        end
    end
    if row.ticks then
        for _, tick in ipairs(row.ticks) do
            tick:Hide()
        end
    end
    if row.texts then
        for _, text in ipairs(row.texts) do
            text:Hide()
        end
    end
    if row.milestones then
        for _, marker in ipairs(row.milestones) do
            marker:Hide()
            SetRowTooltip(marker, nil, nil)
        end
    end
    if row.milestoneTexts then
        for _, text in ipairs(row.milestoneTexts) do
            text:Hide()
        end
    end
end

function Trace:AcquireTimelineBar(row, index)
    local bar = row.bars[index]
    if bar then
        bar:Show()
        return bar
    end

    bar = CreateFrame("Button", nil, row.chart)
    bar:SetHeight(14)
    bar.texture = bar:CreateTexture(nil, "ARTWORK")
    bar.texture:SetAllPoints()
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.label:SetPoint("LEFT", 3, 0)
    bar.label:SetJustifyH("LEFT")
    if bar.label.SetWordWrap then bar.label:SetWordWrap(false) end
    if bar.label.SetNonSpaceWrap then bar.label:SetNonSpaceWrap(false) end
    self:AttachTimelineInput(bar)
    row.bars[index] = bar
    return bar
end

function Trace:AcquireTimelineMilestone(row, index)
    row.milestones = row.milestones or {}
    local marker = row.milestones[index]
    if marker then
        marker:Show()
        return marker
    end

    marker = CreateFrame("Button", nil, row.chart)
    marker:SetSize(7, 22)
    marker.texture = marker:CreateTexture(nil, "OVERLAY")
    marker.texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    marker.texture:SetPoint("TOP", marker, "TOP", 0, 0)
    marker.texture:SetPoint("BOTTOM", marker, "BOTTOM", 0, 0)
    marker.texture:SetWidth(1)
    row.milestones[index] = marker
    return marker
end

function Trace:AcquireTimelineMilestoneText(row, index)
    row.milestoneTexts = row.milestoneTexts or {}
    local text = row.milestoneTexts[index]
    if text then
        text:Show()
        return text
    end

    text = row.chart:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetJustifyH("CENTER")
    text:SetTextColor(0.9, 0.95, 1, 0.95)
    if text.SetWordWrap then text:SetWordWrap(false) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end
    row.milestoneTexts[index] = text
    return text
end

function Trace:AcquireTimelineTick(row, index)
    local tick = row.ticks[index]
    if tick then
        tick:Show()
        return tick
    end

    tick = row.chart:CreateTexture(nil, "OVERLAY")
    tick:SetTexture("Interface\\Buttons\\WHITE8x8")
    tick:SetVertexColor(0.7, 0.75, 0.82, 0.25)
    tick:SetWidth(1)
    row.ticks[index] = tick
    return tick
end

function Trace:AcquireTimelineText(row, index)
    local text = row.texts[index]
    if text then
        text:Show()
        return text
    end

    text = row.chart:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetJustifyH("CENTER")
    text:SetTextColor(0.67, 0.74, 0.82, 1)
    row.texts[index] = text
    return text
end

function Trace:UpdateViewButtons(frame)
    local mode = self.viewMode or "timeline"
    local buttons = {
        { frame.timelineTab, "timeline" },
        { frame.listTab, "list" },
        { frame.modulesTab, "modules" },
        { frame.eventsTab, "events" },
        { frame.anomaliesTab, "anomalies" },
    }
    for _, item in ipairs(buttons) do
        local button, buttonMode = item[1], item[2]
        if button and button.SetSelected then
            button:SetSelected(mode == buttonMode)
        end
        if button and button.text then
            if mode == buttonMode then
                button.text:SetTextColor(1, 0.82, 0, 1)
            else
                button.text:SetTextColor(0.85, 0.9, 1, 1)
            end
        end
    end
end

function Trace:RenderTimelineContent(content)
    local records = self.records or {}
    local first, last, range = GetTraceRange(records)
    local lanes = BuildTimelineLanes(records)
    local gaps = BuildTimelineGaps(records, first, last)
    local chartWidth = TIMELINE_CHART_WIDTH
    local zoom = tonumber(self.zoom) or 1
    if zoom < 1 then zoom = 1 end
    local virtualWidth = chartWidth * zoom
    local maxPan = max(0, virtualWidth - chartWidth)
    local pan = min(max(0, tonumber(self.pan) or 0), maxPan)
    self.pan = pan
    self.maxTimelinePan = maxPan
    if self.window and self.window.timelineSlider then
        local slider = self.window.timelineSlider
        self.updatingTimelineSlider = true
        slider:SetMinMaxValues(0, maxPan > 0 and maxPan or 1)
        slider:SetValue(pan)
        self.updatingTimelineSlider = false
        if maxPan > 0 then
            slider:Show()
        else
            slider:Hide()
        end
    end

    local function XAt(time)
        return ((time - first) / range) * virtualWidth - pan
    end

    local function DrawMilestones(row, showLabels)
        local used = 0
        local labelUsed = 0
        for _, milestone in ipairs(TIMELINE_MILESTONES) do
            local time = self.stageFirst and self.stageFirst[milestone.name]
            if time then
                local x = XAt(time)
                if x >= 0 and x <= chartWidth then
                    used = used + 1
                    local marker = self:AcquireTimelineMilestone(row, used)
                    marker:ClearAllPoints()
                    marker:SetPoint("TOP", row.chart, "TOPLEFT", x, 0)
                    marker:SetHeight(22)
                    marker.texture:SetVertexColor(milestone.r, milestone.g, milestone.b, milestone.a)
                    SetRowTooltip(marker, milestone.label, "时间=" .. FormatPoint(time))
                    if showLabels then
                        labelUsed = labelUsed + 1
                        local label = self:AcquireTimelineMilestoneText(row, labelUsed)
                        label:ClearAllPoints()
                        label:SetPoint("TOP", row.chart, "TOPLEFT", x, -11)
                        label:SetText(Utf8Shorten(milestone.label, 16))
                        label:SetTextColor(milestone.r, milestone.g, milestone.b, 0.95)
                    end
                end
            end
        end
        for index = used + 1, #(row.milestones or {}) do
            row.milestones[index]:Hide()
            SetRowTooltip(row.milestones[index], nil, nil)
        end
        for index = labelUsed + 1, #(row.milestoneTexts or {}) do
            row.milestoneTexts[index]:Hide()
        end
    end

    local function DrawRange(row, barIndex, startTime, finishTime, tone, label, tooltipTitle, tooltipText)
        local startX = XAt(startTime)
        local endX = XAt(finishTime)
        local visibleStart = startX
        local visibleEnd = endX
        if visibleEnd >= 0 and visibleStart <= chartWidth then
            local drawStart = max(0, visibleStart)
            local drawEnd = min(chartWidth, visibleEnd)
            local bar = self:AcquireTimelineBar(row, barIndex)
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", row.chart, "LEFT", drawStart, 0)
            bar:SetSize(max(3, drawEnd - drawStart), 14)
            ApplyTextureTone(bar.texture, tone)
            bar.label:SetWidth(max(1, drawEnd - drawStart - 6))
            if drawEnd - drawStart > 56 then
                bar.label:SetText(Utf8Shorten(label, 22))
                bar.label:Show()
            else
                bar.label:SetText("")
                bar.label:Hide()
            end
            SetRowTooltip(bar, tooltipTitle, tooltipText)
            return true
        end
        return false
    end

    local y = 0
    local rowIndex = 0

    rowIndex = rowIndex + 1
    local axis = self:AcquireTimelineRow(content, rowIndex)
    axis:SetPoint("TOPLEFT", 0, y)
    axis.label:SetText("时间")
    axis.label:SetTextColor(0.85, 0.9, 1, 1)
    axis.verdict:SetText("缩放 x" .. tostring(zoom))
    axis.verdict:SetTextColor(0.67, 0.74, 0.82, 1)
    axis.bg:SetVertexColor(0.08, 0.1, 0.14, 0.65)
    SetRowTooltip(axis, "总时间轴", "完整范围=" .. FormatSpan(range) .. "\n起止=" .. FormatPoint(first) .. " -> " .. FormatPoint(last))
    y = y - 28

    local tickCount = 5
    for i = 1, tickCount do
        local ratio = (i - 1) / (tickCount - 1)
        local x = floor(ratio * chartWidth)
        local tick = self:AcquireTimelineTick(axis, i)
        tick:ClearAllPoints()
        tick:SetPoint("TOPLEFT", axis.chart, "TOPLEFT", x, 0)
        tick:SetHeight(22)
        local label = self:AcquireTimelineText(axis, i)
        label:ClearAllPoints()
        label:SetPoint("TOP", axis.chart, "TOPLEFT", x, -2)
        label:SetText(string.format("T+%.2fs", ((pan + ratio * chartWidth) / virtualWidth) * (range / 1000)))
    end
    DrawMilestones(axis, true)

    if #gaps > 0 then
        rowIndex = rowIndex + 1
        local row = self:AcquireTimelineRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        y = y - 28
        row.label:SetText("无记录间隔")
        row.label:SetTextColor(0.72, 0.78, 0.86, 1)
        row.bg:SetVertexColor(0.08, 0.1, 0.14, 0.48)
        local longest = 0
        for _, gap in ipairs(gaps) do
            longest = max(longest, gap.duration or 0)
        end
        row.verdict:SetText("最长 " .. FormatSpan(longest))
        row.verdict:SetTextColor(0.67, 0.74, 0.82, 1)
        SetRowTooltip(row, "无记录间隔", "这些灰色条表示：这段时间内 Trace 没有记录到 YUI 步骤。\n它通常是等待、异步回调、玩家停顿，或当前 Trace 范围没有覆盖的时间，不等于卡顿。")
        for i, tick in ipairs(row.ticks) do tick:Hide() end
        for i, text in ipairs(row.texts) do text:Hide() end
        DrawMilestones(row, false)
        local barIndex = 0
        for _, gap in ipairs(gaps) do
            barIndex = barIndex + 1
            if not DrawRange(row, barIndex, gap.first, gap.last, "gap", "无记录 " .. FormatSpan(gap.duration), "无记录间隔", "开始=" .. FormatPoint(gap.first) .. "\n结束=" .. FormatPoint(gap.last) .. "\n跨度=" .. FormatSpan(gap.duration) .. "\n说明=这段时间 Trace 没有记录到 YUI 步骤。") then
                barIndex = barIndex - 1
            end
        end
        for index = barIndex + 1, #row.bars do
            row.bars[index]:Hide()
            SetRowTooltip(row.bars[index], nil, nil)
        end
    end

    for _, lane in ipairs(lanes) do
        rowIndex = rowIndex + 1
        local row = self:AcquireTimelineRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        y = y - 28
        row.label:SetText(Utf8Shorten(lane.name, 32))
        row.label:SetTextColor(0.82, 0.87, 0.94, 1)
        row.verdict:SetText(lane.verdict or "")
        SetTone(row.verdict, DurationTone(lane.blockingTotal, true, lane.errorCount > 0 and "error" or "ok"))
        row.bg:SetVertexColor(0.12, 0.15, 0.2, 0.38)
        SetRowTooltip(row, lane.name, "阻塞=" .. FormatMs(lane.blockingTotal) ..
            "\n跨度=" .. FormatSpan(lane.span) ..
            "\n起止=" .. FormatPoint(lane.first) .. " -> " .. FormatPoint(lane.last))

        for i, tick in ipairs(row.ticks) do tick:Hide() end
        for i, text in ipairs(row.texts) do text:Hide() end
        DrawMilestones(row, false)
        local barIndex = 0
        for _, record in ipairs(lane.items) do
            local startX = XAt(RecordStart(record))
            local endX = XAt(RecordFinish(record))
            local visibleStart = startX
            local visibleEnd = endX
            if record.type == "mark" then
                visibleEnd = startX + 3
            end
            if visibleEnd >= 0 and visibleStart <= chartWidth then
                local drawStart = max(0, visibleStart)
                local drawEnd = min(chartWidth, visibleEnd)
                barIndex = barIndex + 1
                local bar = self:AcquireTimelineBar(row, barIndex)
                bar:ClearAllPoints()
                bar:SetPoint("LEFT", row.chart, "LEFT", drawStart, 0)
                bar:SetSize(max(3, drawEnd - drawStart), record.type == "mark" and 18 or 14)
                ApplyTextureTone(bar.texture, GetRecordTone(record))
                bar.label:SetWidth(max(1, drawEnd - drawStart - 6))
                if drawEnd - drawStart > 52 then
                    local recordLabel = record.traceName or record.name
                    if record.durationKind == "delay" then
                        local delayMs = record.duration or ((tonumber(record.delaySeconds) or 0) * 1000)
                        recordLabel = "等待 " .. FormatSpan(delayMs)
                    end
                    bar.label:SetText(Utf8Shorten(recordLabel, 18))
                    bar.label:Show()
                else
                    bar.label:SetText("")
                    bar.label:Hide()
                end
                SetRowTooltip(bar, tostring(record.name or ""), FormatRecordTooltip(record))
            end
        end
        for index = barIndex + 1, #row.bars do
            row.bars[index]:Hide()
            SetRowTooltip(row.bars[index], nil, nil)
        end
    end

    if #lanes == 0 then
        rowIndex = rowIndex + 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        row.left:SetText("暂无 Trace 记录。")
        row.right:SetText("")
        y = y - 20
    end

    content:SetHeight(max(1, -y + 20))
end

function Trace:RenderModulesContent(content)
    local y = 0
    local rowIndex = 0
    for index, stat in ipairs(self:GetModuleStats()) do
        rowIndex = rowIndex + 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        y = y - 22
        local verdict = DescribeVerdict(stat.blockingTotal, stat.waitInterval, stat.errorCount)
        local slow = stat.slowestBlocking and (" 最慢=" .. tostring(stat.slowestBlocking.phase or stat.slowestBlocking.name) .. " " .. FormatMs(stat.slowestBlocking.duration)) or ""
        row.left:SetText(Utf8Shorten(tostring(stat.moduleId), 64) .. "  结论=" .. verdict .. slow)
        row.right:SetText("阻塞 " .. FormatMs(stat.blockingTotal) .. " / 等待 " .. FormatSpan(stat.waitInterval) .. " / 跨度 " .. FormatSpan(stat.span))
        row.left:SetTextColor(0.82, 0.87, 0.94, 1)
        SetTone(row.right, DurationTone(stat.blockingTotal, true, stat.errorCount > 0 and "error" or "ok"))
        SetRowTooltip(row, tostring(stat.moduleId), "阻塞耗时=" .. FormatMs(stat.blockingTotal) ..
            "\n执行耗时=" .. FormatMs(stat.syncTotal) ..
            "\n等待/间隔=" .. FormatSpan(stat.waitInterval) ..
            "\n跨度=" .. FormatSpan(stat.span) ..
            (stat.slowestBlocking and ("\n最慢同步项=" .. tostring(stat.slowestBlocking.name) .. " " .. FormatMs(stat.slowestBlocking.duration)) or "") ..
            (stat.slowestAsync and ("\n最慢等待项=" .. tostring(stat.slowestAsync.name) .. " " .. FormatSpan(stat.slowestAsync.duration)) or ""))
    end
    content:SetHeight(max(1, -y + 20))
end

function Trace:RenderEventsContent(content)
    local y = 0
    local rowIndex = 0
    local groups = {}
    local order = {}
    for _, record in ipairs(self.records or {}) do
        if record.group == "EventBus" then
            local key = tostring(record.name or "") .. "\001" .. tostring(record.detail or "")
            local group = groups[key]
            if not group then
                group = { record = record, count = 0, blockingTotal = 0, first = RecordStart(record), last = RecordFinish(record), errorCount = 0 }
                groups[key] = group
                order[#order + 1] = group
            end
            group.count = group.count + 1
            group.first = min(group.first, RecordStart(record))
            group.last = max(group.last, RecordFinish(record))
            if IsBlocking(record) then
                group.blockingTotal = group.blockingTotal + record.duration
            end
            if record.status == "error" then
                group.errorCount = group.errorCount + 1
            end
        end
    end
    sort(order, function(a, b) return (a.first or 0) < (b.first or 0) end)
    for _, group in ipairs(order) do
        rowIndex = rowIndex + 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        y = y - 22
        local record = group.record
        row.left:SetText(Utf8Shorten(tostring(record.name or "") .. "  " .. CompactDetail(record.detail), 76) .. (group.count > 1 and (" x" .. tostring(group.count)) or ""))
        row.right:SetText("阻塞 " .. FormatMs(group.blockingTotal) .. " / " .. FormatPoint(group.first) .. " -> " .. FormatPoint(group.last))
        row.left:SetTextColor(0.82, 0.87, 0.94, 1)
        SetTone(row.right, DurationTone(group.blockingTotal, true, group.errorCount > 0 and "error" or "ok"))
        SetRowTooltip(row, tostring(record.name or ""), tostring(record.detail or ""))
    end
    content:SetHeight(max(1, -y + 20))
end

function Trace:RenderAnomaliesContent(content)
    local y = 0
    local rowIndex = 0
    local anomalies = self.anomalies or {}
    for index, item in ipairs(anomalies) do
        rowIndex = rowIndex + 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        y = y - 24
        local title = tostring(item.title or "Trace 异常")
        local detail = tostring(item.detail or "")
        row.left:SetText(Utf8Shorten(tostring(index) .. ". " .. title .. "  " .. CompactDetail(detail), 94))
        row.right:SetText(FormatPoint(item.time))
        row.left:SetTextColor(1, 0.42, 0.42, 1)
        row.right:SetTextColor(1, 0.64, 0.64, 1)
        SetRowTooltip(row, title, "时间=" .. FormatPoint(item.time) ..
            "\n类型=" .. tostring(item.kind or "general") ..
            "\n详情=" .. detail)
    end
    if rowIndex == 0 then
        rowIndex = 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        row.left:SetText("暂无异常。")
        row.right:SetText("")
        row.left:SetTextColor(0.48, 0.88, 0.66, 1)
    end
    content:SetHeight(max(1, -y + 20))
end

function Trace:RenderWindow()
    local frame = self:CreateWindow()
    local content = frame.content
    content.rows = frame.rows
    for _, row in ipairs(frame.rows) do
        row:Hide()
        row:SetScript("OnClick", nil)
        SetRowTooltip(row, nil, nil)
    end
    if content.timelineRows then
        for _, row in ipairs(content.timelineRows) do
            HideTimelineRow(row)
        end
    end

    local missing = self:GetMissingStages()
    local missingText = #missing > 0 and (" 缺失=" .. table.concat(missing, ", ")) or ""
    self:UpdateViewButtons(frame)
    frame.summary:SetText("记录=" .. tostring(#(self.records or {})) ..
        " 异常=" .. tostring(#(self.anomalies or {})) ..
        " 缺失阶段=" .. tostring(#missing) ..
        " 详细追踪=" .. tostring(self.detailed == true or YUI.IsDev == true) ..
        missingText)

    local mode = self.viewMode or "timeline"
    if frame.timelineSlider and mode ~= "timeline" then
        frame.timelineSlider:Hide()
    end
    if mode == "timeline" then
        self:RenderTimelineContent(content)
        frame:Show()
        return
    elseif mode == "modules" then
        self:RenderModulesContent(content)
        frame:Show()
        return
    elseif mode == "events" then
        self:RenderEventsContent(content)
        frame:Show()
        return
    elseif mode == "anomalies" then
        self:RenderAnomaliesContent(content)
        frame:Show()
        return
    end

    local y = 0
    local rowIndex = 0
    local moduleStats = self:GetModuleStats()
    if #moduleStats > 0 then
        rowIndex = rowIndex + 1
        local moduleRow = self:AcquireRow(content, rowIndex)
        moduleRow:SetPoint("TOPLEFT", 0, y)
        y = y - 24
        moduleRow.left:SetText((self.collapsed.__moduleStats and "+ " or "- ") .. "模块耗时榜")
        moduleRow.right:SetText("按阻塞耗时排序 / 共 " .. tostring(#moduleStats) .. " 项")
        moduleRow.left:SetTextColor(1, 1, 1, 1)
        moduleRow.right:SetTextColor(0.67, 0.74, 0.82, 1)
        SetRowTooltip(moduleRow, "模块耗时榜", "判断卡不卡主要看阻塞耗时；等待/跨度只表示流程拖了多久。")
        moduleRow:SetScript("OnClick", function()
            Trace.collapsed.__moduleStats = not Trace.collapsed.__moduleStats
            Trace:RenderWindow()
        end)

        if not self.collapsed.__moduleStats then
            for index, stat in ipairs(moduleStats) do
                if index > 30 then
                    break
                end
                rowIndex = rowIndex + 1
                local child = self:AcquireRow(content, rowIndex)
                child:SetPoint("TOPLEFT", 0, y)
                y = y - 20
                local verdict = DescribeVerdict(stat.blockingTotal, stat.waitInterval, stat.errorCount)
                local slow = stat.slowestBlocking and (" 最慢=" .. tostring(stat.slowestBlocking.phase or stat.slowestBlocking.name) .. " " .. FormatMs(stat.slowestBlocking.duration)) or ""
                child.left:SetText("  - " .. Utf8Shorten(tostring(stat.moduleId), 72) .. "  结论=" .. verdict .. slow)
                child.right:SetText("阻塞 " .. FormatMs(stat.blockingTotal) ..
                    " / 等待 " .. FormatSpan(stat.waitInterval) ..
                    " / 跨度 " .. FormatSpan(stat.span))
                child.left:SetTextColor(0.82, 0.87, 0.94, 1)
                SetTone(child.right, DurationTone(stat.blockingTotal, true, stat.errorCount > 0 and "error" or "ok"))
                SetRowTooltip(child, tostring(stat.moduleId), "阻塞耗时=" .. FormatMs(stat.blockingTotal) ..
                    "\n执行耗时=" .. FormatMs(stat.syncTotal) ..
                    "\n等待/间隔=" .. FormatSpan(stat.waitInterval) ..
                    "\n跨度=" .. FormatSpan(stat.span))
            end
        end
    end

    for _, group in ipairs(self:GetGroups()) do
        rowIndex = rowIndex + 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        y = y - 24
        row.left:SetText((self.collapsed[group.name] and "+ " or "- ") .. DisplayGroup(group.name))
        row.right:SetText("阻塞 " .. FormatMs(group.blockingTotal) ..
            " / 执行 " .. FormatMs(group.syncTotal) ..
            " / 等待 " .. FormatSpan(group.waitInterval) ..
            " / 跨度 " .. FormatSpan(group.span))
        row.left:SetTextColor(1, 1, 1, 1)
        SetTone(row.right, DurationTone(group.blockingTotal, true, group.errorCount > 0 and "error" or "ok"))
        SetRowTooltip(row, DisplayGroup(group.name), "起止=" .. FormatPoint(group.first) .. " -> " .. FormatPoint(group.last) ..
            "\n阻塞耗时用于判断卡不卡；等待/跨度用于判断流程是否拖得久。")
        row:SetScript("OnClick", function()
            Trace.collapsed[group.name] = not Trace.collapsed[group.name]
            Trace:RenderWindow()
        end)

        if not self.collapsed[group.name] then
            for _, item in ipairs(GetDisplayItems(group)) do
                rowIndex = rowIndex + 1
                local child = self:AcquireRow(content, rowIndex)
                child:SetPoint("TOPLEFT", 0, y)
                y = y - 20
                local marker = item.type == "mark" and "  * " or "  - "
                child.left:SetText(marker .. MakeItemText(item))
                child.right:SetText(item.duration and FormatDuration(item.duration, item.durationKind) or FormatPoint(item.start))
                if item.status == "error" then
                    child.left:SetTextColor(1, 0.42, 0.42, 1)
                else
                    child.left:SetTextColor(0.82, 0.87, 0.94, 1)
                end
                SetTone(child.right, item.durationKind == "async" and WaitTone(item.duration, 0) or DurationTone(item.duration, false, item.status))
                SetRowTooltip(child, tostring(item.name or ""), tostring(item.detail or ""))
            end
        end
    end

    if rowIndex == 0 then
        rowIndex = 1
        local row = self:AcquireRow(content, rowIndex)
        row:SetPoint("TOPLEFT", 0, y)
        row.left:SetText("暂无 Trace 记录。")
        row.right:SetText("")
    end

    content:SetHeight(math.max(1, -y + 20))
    frame:Show()
end

function Trace:Open()
    self:RenderWindow()
end

function Trace:OpenExport()
    local frame = self.exportFrame
    if not frame then
        frame = CreateFrame("Frame", "YUITraceExportFrame", UIParent, FrameTemplate())
        frame:SetSize(740, 420)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableMouse(true)
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            frame:SetBackdropColor(0.04, 0.05, 0.07, 0.96)
            frame:SetBackdropBorderColor(0.2, 0.25, 0.33, 1)
        end

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOPLEFT", 14, -12)
        frame.title:SetText("YUI Trace 导出")

        frame.close = self:CreateButton(frame, "关闭", 64, 22)
        frame.close:SetPoint("TOPRIGHT", -12, -12)
        frame.close:SetScript("OnClick", function() frame:Hide() end)

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -44)
        scroll:SetPoint("BOTTOMRIGHT", -34, 14)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(670)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)
        frame.edit = edit
        self.exportFrame = frame
    end
    frame.edit:SetText(self:ExportJSON())
    frame.edit:HighlightText()
    frame:Show()
end

function Trace:PrintSummary()
    local groups = self:GetGroups()
    Print("YUI Trace 摘要")
    for _, group in ipairs(groups) do
        local slowSync = group.slowestBlocking and (group.slowestBlocking.name .. " " .. FormatMs(group.slowestBlocking.duration)) or "-"
        local slowAsync = group.slowestAsync and (group.slowestAsync.name .. " " .. FormatSpan(group.slowestAsync.duration)) or "-"
        Print(DisplayGroup(group.name) .. "：阻塞耗时=" .. FormatMs(group.blockingTotal) ..
            " 执行耗时=" .. FormatMs(group.syncTotal) ..
            " 等待间隔=" .. FormatSpan(group.waitInterval) ..
            " 跨度=" .. FormatSpan(group.span) ..
            " 起止=" .. FormatPoint(group.first) .. "->" .. FormatPoint(group.last) ..
            " 最慢同步项=" .. slowSync ..
            " 最慢等待项=" .. slowAsync ..
            " 错误=" .. tostring(group.errorCount or 0))
    end
    local moduleStats = self:GetModuleStats()
    if #moduleStats > 0 then
        Print("模块耗时榜：")
        for index, stat in ipairs(moduleStats) do
            if index > 10 then
                break
            end
            Print("- " .. tostring(stat.moduleId) ..
                " 阻塞=" .. FormatMs(stat.blockingTotal) ..
                " 等待=" .. FormatSpan(stat.waitInterval) ..
                " 跨度=" .. FormatSpan(stat.span) ..
                " 结论=" .. DescribeVerdict(stat.blockingTotal, stat.waitInterval, stat.errorCount))
        end
    end
    if #(self.anomalies or {}) > 0 then
        Print("异常：")
        for _, item in ipairs(self.anomalies) do
            Print("- " .. tostring(item.title) .. ": " .. tostring(item.detail))
        end
    end
    local missing = self:GetMissingStages()
    if #missing > 0 then
        Print("缺失阶段：" .. table.concat(missing, ", "))
    end
end

local function RegisterSlash()
    if SlashCmdList and not SlashCmdList.YUITRACE then
        _G.SLASH_YUITRACE1 = "/yuitrace"
        SlashCmdList.YUITRACE = function(msg)
            msg = tostring(msg or ""):lower()
            if msg == "summary" then
                Trace:PrintSummary()
            elseif msg == "export" then
                Trace:OpenExport()
            elseif msg == "timeline" then
                Trace:SetViewMode("timeline")
            elseif msg == "list" then
                Trace:SetViewMode("list")
            elseif msg == "modules" then
                Trace:SetViewMode("modules")
            elseif msg == "events" then
                Trace:SetViewMode("events")
            elseif msg == "anomalies" or msg == "warnings" then
                Trace:SetViewMode("anomalies")
            elseif msg == "on" then
                Trace.detailed = true
                Print("YUI Trace 详细 listener 耗时：开启")
            elseif msg == "off" then
                Trace.detailed = false
                Print("YUI Trace 详细 listener 耗时：关闭")
            elseif msg == "reset" then
                Trace:Reset()
                Print("YUI Trace 已重置")
            else
                Trace.viewMode = "timeline"
                Trace:Open()
            end
        end
    end
end

RegisterSlash()
Trace:Mark("Framework", "Trace 已就绪")
