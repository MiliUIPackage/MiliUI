-- FacingArrow.lua
-- 屏幕中心的罗盘式方向箭头（随人物朝向绕中心转、尖朝外）

-- 旋转跟随方案参考自 DreamForgeTools\modules\UlatekCompass\logic.lua

-- 显示规则（授权驱动）：
--   公共变量 addonTable.FacingArrowAllowed == true 才允许显示“战斗方向箭头”。
--   EncounterWarning.lua 在 2623 “烈焰喷吐”点名时置 true，并调用
--   addonTable.TriggerFacingArrow(6)：FacingArrow 按当前开战秒在 2623 时间表
--   找到“该轮”方向，立即显示 6 秒；6 秒后自动把 FacingArrowAllowed 复位 false。
--   手动 /farrow（北针，调试用）不受该授权限制。
--
-- 渲染思路：
--   1. 屏幕中心固定为圆心；显示期间临时开启旋转小地图(rotateMinimap)，
--      并保活 MinimapCompassTexture(副本/UI 隐藏时它仍在持续更新旋转值)；
--   2. 箭头是整张贴图上的一“块”，用顶点偏移摆到距中心 ORBIT_RADIUS 的
--      圆周上，几何上位置与图形朝向同源 → 尖始终朝外(基准角=目标世界方向)；
--   3. 每帧把 MinimapCompassTexture:GetRotation() 原样透传给该纹理的
--      SetRotation()。该值可能是 secret number，做任何算术都会触发 taint。

local _, addonTable = ...

local ARROW_TEXTURE =
    "Interface\\AddOns\\DiGuaTimelineAudioHelper\\FacingArrow.png"
local ORBIT_RADIUS = 110 -- 箭头中心离屏幕中心(圆心)的距离，调大=离中心更远
local REFRESH_INTERVAL = 0.03 -- 刷新间隔（秒）

-- ===== 2623 方向时间表（烈焰喷吐各轮次的方向）=====
-- encounterID → { 开战秒数 = 指向方向(度) }，0°=北，顺时针(地图方位)
-- 时钟换算：n 点半 = n*30+15°，如 7点半=225°、4点半=135°、1点半=45°
local BATTLE_TIMELINES = {
    [2623] = {
        [18] = 225, -- 第18秒 7点半(西南)
        [43] = 135, -- 第43秒 4点半
        [67] = 45,  -- 第67秒 1点半
        [88] = 315, -- 第88秒 10点半
        [108] = 225, -- 第88秒 10点半
        [128] = 135, -- 第88秒 10点半
    },
}
local TRIGGER_TOLERANCE = 10   -- 事件触发时间相对表内秒数的容差(秒)
local TRIGGER_DURATION = 6    -- 触发后默认显示时长(秒，EncounterWarning 会传入)

-- ===== 状态 =====
addonTable.FacingArrowAllowed = false -- 授权：true 才允许显示战斗方向箭头
local arrowFrame
local arrowTexture
local minimapRotateBackup -- 进入显示前玩家 rotateMinimap 的真实开关(开战瞬间记录，避免手动改动被覆盖)
local compassSnapshot    -- 被强制 Show 期间 MinimapCompassTexture 的原始 {可见, alpha}
local ellesmereCfg       -- 检测到 Ellesmere 接管小地图时的配置表
local ellesmereRotateBackup -- 该配置表原始的 rotateMinimap 值，供退出还原

local manualOn = false    -- 手动模式(/farrow)
local battleTimeline -- 非 nil = 2623 boss 战进行中(命中时间表)
local battleStart = 0
local triggerDeg -- 授权触发要显示的方向
local triggerUntil = 0 -- 授权显示到期时刻(GetTime)
local triggerTimer -- 授权到期复位定时器
local lastPlacedDeg -- 上次 placeArrow 的基准角，用于判断是否需要重摆
local currentlyShown = false

local triggerActive -- forward，见调度区

-- ===== 罗盘旋转与罗盘贴图保活 =====
-- 原理：MinimapCompassTexture 只在旋转小地图开启时才持续更新自身旋转角；
-- 一旦被隐藏或停更(副本 UI / 其它小地图插件接管)，GetRotation() 就返回旧值，
-- 箭头会停转。因此显示期间需：临时打开旋转、同步 Ellesmere、强制 Show 罗盘，
-- 并在结束时把三者逐一还原。
-- 注意：罗盘旋转值可能是 secret number，只能原样透传给 SetRotation，
--       任何算术(哪怕只是取负/换弧度)都会触发 taint 报错。

-- 写入旋转小地图开关：新老两套接口 + 集群对象都设一遍，保证各种 UI 下生效
local function applyRotateCVar(state)
    local flag = state and "1" or "0"
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "rotateMinimap", flag)
    end
    if SetCVar then
        pcall(SetCVar, "rotateMinimap", flag)
    end
    local cluster = rawget(_G, "MinimapCluster")
    if cluster and cluster.SetRotateMinimap then
        pcall(cluster.SetRotateMinimap, cluster, state and true or false)
    end
end

-- 若 Ellesmere 小地图在场，它会接管系统罗盘；这里取到它的配置表
local function findEllesmereCfg()
    local db = rawget(_G, "_EMM_DB")
    local profile = type(db) == "table" and db["profile"]
    local minimap = type(profile) == "table" and profile["minimap"]
    return type(minimap) == "table" and minimap or nil
end

-- 调用罗盘贴图“真正”的 Show：有些插件在实例上 hook 过 Show，直接 :Show()
-- 会被拦下；从类方法表里把原生实现取出来调用
local function invokeNativeShow(tex)
    local mt = getmetatable(tex)
    local methods = mt and mt.__index
    if type(methods) == "table" and type(methods.Show) == "function" then
        methods.Show(tex)
    else
        tex:Show()
    end
end

-- 保活：让罗盘贴图保持可见(若被 UI 藏着，先置零 alpha 再 Show，不打扰画面)
local function keepCompassAlive()
    local tex = rawget(_G, "MinimapCompassTexture")
    if not tex then return end
    if not compassSnapshot then
        compassSnapshot = { shown = tex:IsShown(), alpha = tex:GetAlpha() }
    end
    if not tex:IsShown() then tex:SetAlpha(0) end
    invokeNativeShow(tex)
end

-- 结束保活：把罗盘贴图还原成我们改动前的样子
local function settleCompass()
    local tex = rawget(_G, "MinimapCompassTexture")
    if compassSnapshot and tex then
        if not compassSnapshot.shown then tex:Hide() end
        tex:SetAlpha(compassSnapshot.alpha or 1)
    end
    compassSnapshot = nil
end

-- 进入显示/战斗保持期调用(幂等)：缺哪项补哪项；
-- 首次调用会把玩家当时的设置快照下来，供结束还原
local function enableCompassRotation()
    if minimapRotateBackup == nil then
        minimapRotateBackup = GetCVar("rotateMinimap") == "1"
    end
    local cfg = findEllesmereCfg()
    if cfg then
        if cfg ~= ellesmereCfg then
            ellesmereCfg = cfg
            ellesmereRotateBackup = cfg.rotateMinimap
        end
        cfg.rotateMinimap = true
    end
    keepCompassAlive()
    if GetCVar("rotateMinimap") ~= "1" then
        applyRotateCVar(true)
    end
end

-- 退出显示：把旋转开关、Ellesmere 配置、罗盘贴图逐一还原
local function disableCompassRotation()
    if ellesmereCfg then
        ellesmereCfg.rotateMinimap = ellesmereRotateBackup
        ellesmereCfg = nil
        ellesmereRotateBackup = nil
    end
    settleCompass()
    if minimapRotateBackup ~= nil then
        if GetCVar("rotateMinimap") ~= (minimapRotateBackup and "1" or "0") then
            applyRotateCVar(minimapRotateBackup)
        end
        minimapRotateBackup = nil
    end
end

-- ===== 摆放几何 =====
-- 箭头贴图是一整张正方形画布，箭头是画布上的一“块”内容；画布边长由
-- “箭头到圆心距离”(ORBIT_RADIUS)反推，之后每帧把整块画布旋转到罗盘角度，
-- 尖朝外因此自动成立。箭头块尺寸夹在 48~96，避免过小/过大。
local SQRT2 = math.sqrt(2)
local function canvasMetrics()
    local canvas = ORBIT_RADIUS / (0.30 * SQRT2) -- 画布边长
    return canvas, canvas * SQRT2 -- 边长 + 贴图层边长(放大 √2 让旋转后四角不越界)
end

-- 摆位(基准角 degrees：0°=北，顺时针增大)：先求箭头四角相对圆心的局部坐标，
-- 再按目标方位整体旋转，最后用顶点偏移把整张贴图放正、中心贴回圆心。
local function placeArrow(degrees)
    if not arrowTexture then return end
    local canvas, layerSize = canvasMetrics()
    local halfDiag = layerSize * 0.5
    local glyphHalf = math.max(48, math.min(96, canvas * 0.22)) * SQRT2 * 0.5
    local theta = math.rad(degrees or 0)
    local cosT, sinT = math.cos(theta), math.sin(theta)
    local function pivot(x, y)
        return x * cosT + y * sinT, -x * sinT + y * cosT
    end
    -- 四角(径向基准)：左右 ±glyphHalf，前后 ORBIT_RADIUS ± glyphHalf
    local ulX, ulY = pivot(-glyphHalf, ORBIT_RADIUS + glyphHalf)
    local llX, llY = pivot(-glyphHalf, ORBIT_RADIUS - glyphHalf)
    local urX, urY = pivot( glyphHalf, ORBIT_RADIUS + glyphHalf)
    local lrX, lrY = pivot( glyphHalf, ORBIT_RADIUS - glyphHalf)
    arrowTexture:SetRotation(0)
    arrowTexture:SetTexCoord(0, 1, 0, 1)
    arrowTexture:SetScale(1)
    arrowTexture:ClearVertexOffsets()
    -- 平移量 = 旋转后角点坐标 ± 半对角线，把贴图中心拉回圆心
    arrowTexture:SetVertexOffset(UPPER_LEFT_VERTEX,  ulX + halfDiag,  ulY - halfDiag)
    arrowTexture:SetVertexOffset(LOWER_LEFT_VERTEX,  llX + halfDiag,  llY + halfDiag)
    arrowTexture:SetVertexOffset(UPPER_RIGHT_VERTEX, urX - halfDiag,  urY - halfDiag)
    arrowTexture:SetVertexOffset(LOWER_RIGHT_VERTEX, lrX - halfDiag,  lrY + halfDiag)
end

local function ensureArrow()
    if arrowFrame then return end
    local size, layerSize = canvasMetrics()
    arrowFrame = CreateFrame("Frame", nil, UIParent)
    arrowFrame:SetSize(size, size)
    arrowFrame:SetPoint("CENTER", UIParent, "CENTER") -- 固定圆心
    arrowFrame:SetFrameStrata("HIGH")
    arrowFrame:SetFrameLevel(900)
    arrowFrame:EnableMouse(false)
    arrowFrame:SetClipsChildren(false)

    arrowTexture = arrowFrame:CreateTexture(nil, "OVERLAY")
    arrowTexture:SetPoint("CENTER")
    arrowTexture:SetTexture(ARROW_TEXTURE)
    arrowTexture:SetHorizTile(false)
    arrowTexture:SetVertTile(false)
    arrowTexture:SetBlendMode("BLEND")
    arrowTexture:SetSize(layerSize, layerSize)
end

-- ===== 方向来源 =====
-- 授权触发时的方向：按当前开战秒在时间表找“该轮”方向(烈焰喷吐轮次)。
-- 命中窗口 = [at - TRIGGER_TOLERANCE, at + TRIGGER_DURATION)
local function currentTimelineDeg()
    if not battleTimeline then return nil end
    local elapsed = GetTime() - battleStart
    for at, deg in pairs(battleTimeline) do
        local diff = elapsed - at
        if diff >= -TRIGGER_TOLERANCE and diff < TRIGGER_DURATION then
            return deg
        end
    end
    return nil
end

-- 当前想让箭头指向哪个方向(度)；nil = 隐藏。
-- 优先级：授权触发窗口 > 手动北针(0° 调试)
local function currentTargetDeg()
    if triggerActive() then return triggerDeg end
    if manualOn then return 0 end
    return nil
end

-- 每帧评估：显示/隐藏、方向变化时重摆、整图自转跟随罗盘
local function evaluate()
    local deg = currentTargetDeg()
    if deg then
        ensureArrow()
        enableCompassRotation()
        if deg ~= lastPlacedDeg then
            placeArrow(deg)
            lastPlacedDeg = deg
        end
        if not currentlyShown then
            arrowFrame:Show()
            currentlyShown = true
        end
        local compass = rawget(_G, "MinimapCompassTexture")
        if compass then
            local ok, rotation = pcall(compass.GetRotation, compass)
            if ok and rotation then
                -- rotation 可能是 secret 值，禁止任何运算，只能原样传给 SetRotation
                pcall(arrowTexture.SetRotation, arrowTexture, rotation)
            end
        end
    else
        if currentlyShown then
            currentlyShown = false
            if arrowFrame then arrowFrame:Hide() end
        end
        -- boss 战进行中：保持旋转开启(下轮提示要用、罗盘保持更新)；否则还原设置
        if battleTimeline then
            enableCompassRotation()
        else
            disableCompassRotation()
        end
    end
end

-- ===== 调度：按需低频率驱动（只在有内容要显示时才挂 OnUpdate，平时零开销）=====
local driver = CreateFrame("Frame")
local driverRunning = false
driver.rotationElapsed = 0

triggerActive = function()
    return triggerDeg ~= nil and GetTime() < triggerUntil
end

-- 是否应跑驱动：手动北针 / 授权窗口 / 对应 boss 战进行中
local function ShouldRunDriver()
    return manualOn or triggerActive() or battleTimeline ~= nil
end

local function SetDriver(on)
    if on and not driverRunning then
        driver.rotationElapsed = 0
        driver:SetScript("OnUpdate", function(self, elapsed)
            self.rotationElapsed = self.rotationElapsed + elapsed
            if self.rotationElapsed < REFRESH_INTERVAL then return end
            self.rotationElapsed = 0
            evaluate()
        end)
        driverRunning = true
    elseif not on and driverRunning then
        driver:SetScript("OnUpdate", nil)
        driverRunning = false
    end
end

-- 按当前状态刷新：重算驱动开关并立即评估一次（各外部接口统一入口）
local function refresh()
    SetDriver(ShouldRunDriver())
    evaluate()
end

-- 复位“授权触发”的临时状态（不取消计时器本身，供计时器到期回调用）
local function resetTriggerState()
    triggerDeg = nil
    triggerUntil = 0
    addonTable.FacingArrowAllowed = false
end

-- 取消授权触发：停掉未到期的计时器并复位状态
local function cancelTrigger()
    if triggerTimer then
        triggerTimer:Cancel()
        triggerTimer = nil
    end
    resetTriggerState()
end

-- ===== 联动接口（EncounterWarning.lua 调用）=====
-- 立即显示 2623 时间表“当前该轮”方向的箭头 seconds 秒；
-- 到期自动把 addonTable.FacingArrowAllowed 复位 false 并隐藏。
function addonTable.TriggerFacingArrow(seconds)
    local deg = currentTimelineDeg() -- 只在该轮次附近才显示，防误指
    if not deg then return end
    seconds = tonumber(seconds) or TRIGGER_DURATION
    cancelTrigger()
    addonTable.FacingArrowAllowed = true
    triggerDeg = deg
    triggerUntil = GetTime() + seconds
    refresh()
    triggerTimer = C_Timer.NewTimer(seconds, function()
        triggerTimer = nil
        resetTriggerState()
        refresh()
    end)
end

-- ===== 对外开关（手动模式，调试北针）=====
function addonTable.SetFacingArrowEnabled(enabled)
    manualOn = enabled and true or false
    addonTable.facingArrow = manualOn
    refresh()
end

-- /farrow 切换显示/隐藏
SLASH_DIGUAFACINGARROW1 = "/farrow"
SlashCmdList["DIGUAFACINGARROW"] = function()
    local show = not addonTable.facingArrow
    addonTable.SetFacingArrowEnabled(show)
    -- 诊断：旋转小地图是否开启 + 罗盘旋转(secret 值禁止算术，换算需 pcall 保护)
    local compass = rawget(_G, "MinimapCompassTexture")
    local ok, rot = compass and pcall(compass.GetRotation, compass) or false, nil
    local deg = "无"
    if ok and rot then
        local dgOK, d = pcall(function() return math.floor(rot * 180 / math.pi) end)
        deg = dgOK and (d .. "°") or "(secret)"
    end
    print("|cffffd100[DiGua]|r 朝向箭頭: " ..
        (show and "|cff00ff00已顯示|r" or "|cffff0000已隱藏|r") ..
        "  |cff66ccff旋轉小地圖=" .. (GetCVar("rotateMinimap") == "1" and "開" or "關") ..
        " 羅盤旋轉=" .. deg)
end

-- ===== 事件：登录/登出 + 配置中的 boss 战斗开始/结束 =====
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")

f:SetScript("OnEvent", function(self, event, encounterID)
    if event == "PLAYER_LOGIN" then
        if addonTable.facingArrow then
            addonTable.SetFacingArrowEnabled(true)
        end
    elseif event == "PLAYER_LOGOUT" then
        battleTimeline = nil
        cancelTrigger()
        SetDriver(false)
        disableCompassRotation()
    elseif event == "ENCOUNTER_START" then
        local timeline = BATTLE_TIMELINES[tonumber(encounterID)]
        if timeline then
            battleTimeline = timeline
            battleStart = GetTime()
            -- 开启旋转小地图并启动常驻驱动，让罗盘保持活跃更新
            enableCompassRotation()
            SetDriver(true)
        end
    elseif event == "ENCOUNTER_END" then
        if battleTimeline then
            battleTimeline = nil
            cancelTrigger()
            refresh()
        end
    end
end)
