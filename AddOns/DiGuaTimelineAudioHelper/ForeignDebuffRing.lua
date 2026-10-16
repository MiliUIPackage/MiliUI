-- ForeignDebuffRing.lua
-- 步骤 2：圆环 + 按 debuff 剩余时间自动扫圈（转圈）
--   圆环视觉与扫描倒计时照搬 Utils.lua：暗底圈做轨道 + 同一张贴图当 SwipeTexture
--   区别：扫圈不需要自己算时间、也不用 OnUpdate —— button:SetDurationCooldown(cd)
--         之后暴雪会按该 debuff 的剩余时间驱动 Cooldown（续期/刷新也自动跟上）
--
-- 实现方式完全照搬本插件的 PlayerDebuffDisplay.lua（同一套 12.1 AuraContainer）：
--   ⛔ 不能自己调 C_UnitAuras.GetAuraDataByIndex 扫光环！12.1 起这些接口带
--      AllowedWhenUntainted + RequiresUnitAuraAccess，插件（tainted 代码）在战斗 / 副本 /
--      大秘境 / PvP 限制生效时直接报 "Auras cannot be accessed when secret while tainted"。
--   ✅ 把「谁符合条件」交给暴雪内部算（AuraContainer），插件只负责过滤条件 + 怎么画。
--
-- 查法术属性 / 批量扫描已拆到 AuraSpellInspector.lua：/asq

local addonName, addonTable = ...

local RING_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Ring_20px.tga" -- 复用插件自带的圆环贴图
local RING_SIZE = 120   -- 圆环直径（贴图本身是 20px 细环，这里放大显示）
local RING_OFFSET_X = 0 -- 相对屏幕中心的偏移（以后接拖动定位框时改成读存档）
local RING_OFFSET_Y = 0
-- 颜色/贴图参数照抄 Utils.lua 的倒计时圆环：底圈压暗做轨道，扫描圈用亮色
local RING_COLOR = { 0.4, 1, 0.8, 0.85 }    -- 扫描弧颜色（Utils.lua 的 RING_COLOR_NORMAL）；想要红色警示就改成 { 1, 0.2, 0.2, 0.9 }
local RING_TRACK_COLOR = { 0, 0, 0, 0.3 }   -- 底圈颜色（Utils.lua 里 bg 的用法）

-- ===== 显示规则表（同一条规则内部是 AND，规则之间是 OR）=====
-- 一张都不填（{}）= 所有地方都显示。
-- 字段值怎么查：instanceID 用 `/dump select(8, GetInstanceInfo())`；encounterID / bossProgress 可对照
-- EncounterWarning.lua、EncounterTimeline.lua 里现成的 ID；role 用 `/dump UnitGroupRolesAssigned("player")`。
--
-- 每条规则可用的字段（不写的字段 = 不限制）：
--   name          = "起个名"                        -- 仅用于标识（不再打印）
--   instanceIDs   = { [2923] = true }              -- select(8, GetInstanceInfo()) 副本ID
--   encounterIDs  = { [3458] = true }              -- 当前首领战ID（0 = 不在首领战/小怪阶段）
--                                                     ⚠️ 想只匹配“小怪阶段”就写 { [0] = true }
--   roles         = { TANK = true }                -- 玩家职责（TANK / HEALER / DAMAGER）
--                                                     三种写法都认：{ TANK = true } / { "TANK", "DAMAGER" } / role = "TANK"
--   mapIDs        = { [2572] = true }              -- C_Map.GetBestMapForUnit 地图ID（副本地图/区域）
--   subZones      = { ["虚空之痕"] = true }         -- 子区域名（本地化文本，对 GetSubZoneText / GetMinimapZoneText）
--   difficultyIDs = { [8] = true }                 -- 难度ID（8=大秘境，14/15/16=团本普通/英雄/史诗，17=团队查找器（随机））
--   keystoneMin   = 2                              -- 大秘境钥石层数 ≥ N（不写=不限）
--   bossProgress  = { [1] = false, [2] = true }    -- 第 N 个 criteria 的 completed 必须等于该值
--                                                     false = 该 Boss 还没打（进度还没到）
--   indoor        = true                           -- 是否室内（IsIndoors），不写=不限
--
-- 【光环过滤】下面五个不写就用文件下面的默认值（DEFAULT_*）；每个 debuff 一套数值就写在这里：
--   maxDuration           = 4.5                    -- 只留总时长 ≤ N 秒的（0 = 不限）
--   extraFilter           = "!RAID"                -- 叠加在 BASE_FILTER 上的过滤器串（如 "IMPORTANT"）
--   excludeDispelTypes    = { Magic = true }       -- 要排除的驱散类型（写 {} = 这条不限类型）
--   fromPlayerOrPlayerPet = false                  -- 只看“非自己/宠物/载具施加的”（默认就是 false）
--   priorityOnly          = true                   -- 只要暴雪标记的“高优先级减益”（AuraUtil.IsPriorityDebuff）
local SHOW_RULES = {


    {
        name = "M9",
        encounterIDs = { [3379] = true }, 
        -- 16=史诗团本 / 17=团队查找器（随机）都要生效（14=普通 / 15=英雄 不生效）
        difficultyIDs = { [16] = true, [17] = true },
        roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
        maxDuration = 6,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },


    {
        name = "M2",
        encounterIDs = { [3445] = true }, 
        roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
        maxDuration = 9,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },

    -- {
    --     name = "密谋",
    --     instanceIDs = { [2813] = true },
    --     roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
    --     maxDuration = 7.5,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    -- },

    {
        name = "洞穴",
        instanceIDs = { [2825] = true },
        encounterIDs = { [3209] = true }, 
        roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
        maxDuration = 7,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },

    {
        name = "红玉老3前小怪",
        instanceIDs = { [2521] = true },
        encounterIDs = { [0] = true },   -- 0 = 不在首领战 → 老 3 开打前的小怪阶段
        bossProgress = { [2] = true },   -- 2 号 死亡
        roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
        maxDuration = 7,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },


    {
        name = "红玉老2",
        instanceIDs = { [2521] = true },
        encounterIDs = { [2606] = true }, 
        roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
        maxDuration = 7,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },



    {
        name = "神庙",
        instanceIDs = { [1877] = true },
        roles = { HEALER = true, DAMAGER = true },  -- 只有治疗 / DPS 显示（坦克不显示）
        bossProgress = { [1] = true },   -- 1 号 死亡
        maxDuration = 7,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },


    {
        name = "切骨者",
        encounterIDs = { [3458] = true }, -- 只在“切骨者”这场首领战里生效（出战斗/小怪阶段不匹配）
        maxDuration = 7.5,                -- 这条规则只关心“总时长 ≤7.5 秒”的短 debuff
    },


    {
        name = "虚无喷发",
        instanceIDs = { [2923] = true },  -- 虚空之痕竞技场
        bossProgress = { [1] = false },   -- 1 号 Boss 还没打
        maxDuration = 4.5,                -- 这条规则只关心“总时长 ≤4.5 秒”的短 debuff
    },

    {
        name = "钉锤风暴 虚空光束 疯狂尖啸",
        instanceIDs = { [2923] = true },  -- 虚空之痕竞技场
        bossProgress = { [1] = true },   -- 2 号 Boss 还没打
        maxDuration = 7,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },

    {
        name = "虚无喷发 钉锤风暴 虚空光束 疯狂尖啸",
        instanceIDs = { [2923] = true },  -- 虚空之痕竞技场
        bossProgress = { [2] = true },   -- 2 号 Boss 还没打
        maxDuration = 7,                -- 这条规则只关心“总时长 ≤7 秒”的短 debuff
    },

}
-- 命中就“不显示”，优先级高于 SHOW_RULES（字段写法与上面完全一样）
local HIDE_RULES = {}

-- ===== 光环过滤（两层，都交给暴雪内部算，插件不碰光环数据）=====
-- 下面这几个是「默认值」：规则里没写对应字段时用它。
-- 【第一层】filterString：基础串 + 叠加条件（多个用 | 连接，`!` 取反）
--   "!RAID"                    ← 排除「我本人能驱散」的减益
--   "!RAID_PLAYER_DISPELLABLE" ← 排除「团队里有人能驱散」的减益
--   "!CANCELABLE"              ← 排除「我能主动取消」的减益
--   ""                         ← 不给第一层加条件
local BASE_FILTER = "HARMFUL"
local DEFAULT_EXTRA_FILTER = ""

-- 【第二层】candidateFilters.excludeDispelTypes：按驱散类型一刀切
--   列进去 = 该类型的减益**一律不显示**（不管我到底能不能驱）。
--   六种全列 = “把能驱散的 debuff 全过滤掉”，仅剩 dispelName 为空/None 的减益才会亮。
--   ⚠️ 键名必须与 auraData.dispelName 完全一致（英文、不随语言变）
local DEFAULT_EXCLUDE_DISPEL_TYPES = {
    Magic = true,
    Curse = true,
    Disease = true,
    Poison = true,
    Bleed = true,
    Enrage = true,
}

-- 【第二层】maxDuration：光环时长上限（秒）
--   ⚠️ 比的是 auraData.duration = **这个 debuff 本身的（最大）总时长**，不是剩余时间！
--      例：maxDuration=4.5 → 一个“总共 8 秒”的 debuff 就算只剩 3 秒，也不会通过。
--   ⚠️ 一旦设了，**永久光环也会被一起排掉**（暴雪源码里 maxDuration 隐含排除 duration==0）
--   0 = 不限；规则里写了就用规则自己的值
local DEFAULT_MAX_DURATION = 4.5

-- ===== 异常提示（正常运行不打印任何东西）=====
local function Warn(msg)
    print("|cffff4444[DiGua/圆环]|r " .. tostring(msg))
end
-- 包一层 pcall：只有失败时才把原因打出来（成功时完全安静）
local function Try(what, fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        Warn("✘ " .. what .. " → " .. tostring(res))
    end
    return ok, res
end

-- 宿主框：只给容器一个固定落点（与 PlayerDebuffDisplay 的 HostFrame 同角色）
local HostFrame = CreateFrame("Frame", nil, UIParent)
HostFrame:SetSize(RING_SIZE, RING_SIZE)
HostFrame:SetPoint("CENTER", UIParent, "CENTER", RING_OFFSET_X, RING_OFFSET_Y)
HostFrame:EnableMouse(false)

-- ===== 12.1 AuraContainer：把“找符合条件的 debuff”交给暴雪 =====
local container

local function IsAuraContainerAvailable()
    return type(AuraContainerSortMethod) == "table"
        and type(AuraContainerSortDirection) == "table"
        and type(AnchorUtil) == "table"
        and type(AnchorUtil.FlowDirection) == "table"
end

-- 过滤器字符串合并 + 合法性校验（非法就退回基础串，照 AuraSpotlight 的 safeFilter 思路）
local function SafeFilter(base, extra)
    if not extra or extra == "" then return base end
    local combined = base .. "|" .. extra
    if AuraUtil and AuraUtil.IsValidFilterString and AuraUtil.IsValidFilterString(combined) then
        return combined
    end
    Warn("过滤器字符串非法，已退回 \"" .. base .. "\"：" .. combined)
    return base
end

-- 把一条规则（nil = 无规则，全用默认值）解析成最终过滤参数
local function ResolveFilters(rule)
    rule = (type(rule) == "table") and rule or {}

    local filterString = SafeFilter(BASE_FILTER, rule.extraFilter or DEFAULT_EXTRA_FILTER)

    local maxDuration = rule.maxDuration
    if maxDuration == nil then maxDuration = DEFAULT_MAX_DURATION end

    local excludeTypes = rule.excludeDispelTypes or DEFAULT_EXCLUDE_DISPEL_TYPES
    local names = {}
    for name, on in pairs(excludeTypes) do
        if on then names[#names + 1] = name end
    end
    table.sort(names)

    local onlySelf = rule.fromPlayerOrPlayerPet
    if onlySelf == nil then onlySelf = false end

    local priorityOnly = rule.priorityOnly and true or false

    return filterString, maxDuration, onlySelf, names, priorityOnly
end

-- 把解析出来的过滤参数真正落到容器上（和上次完全相同就跳过，避免频繁重算）
local lastFilterSignature
local function ApplyAuraFilters(rule)
    local c = container
    if not c then return end

    local filterString, maxDuration, onlySelf, names, priorityOnly = ResolveFilters(rule)
    local signature = filterString .. "|" .. tostring(maxDuration) .. "|"
        .. tostring(onlySelf) .. "|" .. tostring(priorityOnly) .. "|" .. table.concat(names, ",")
    if signature == lastFilterSignature then return end
    lastFilterSignature = signature

    -- ★ 通过 SetAuraGroupFilterString / SetAuraGroupCandidateFilters 动态改过滤
    --   （这就是“每条规则一套过滤数值”的实现方式）
    Try("SetAuraGroupFilterString(" .. filterString .. ")", function()
        c:SetAuraGroupFilterString("debuffs", filterString)
    end)

    local cf = { isFromPlayerOrPlayerPet = onlySelf and true or false }
    if #names > 0 then
        local map = {}
        for i = 1, #names do map[names[i]] = true end
        cf.excludeDispelTypes = map
    end
    local hasMaxDuration = (maxDuration ~= nil) and (maxDuration > 0)
    if hasMaxDuration then cf.maxDuration = maxDuration end
    if priorityOnly then cf.isPriorityAura = true end

    Try("SetAuraGroupCandidateFilters(isFromPlayerOrPlayerPet=" .. tostring(cf.isFromPlayerOrPlayerPet)
        .. (hasMaxDuration and (", maxDuration≤" .. maxDuration .. "s") or "")
        .. (priorityOnly and ", isPriorityAura=true" or "")
        .. (#names > 0 and (", excludeDispelTypes×" .. #names) or "") .. ")",
        function() c:SetAuraGroupCandidateFilters("debuffs", cf) end)
end

local function BuildContainer()
    if container then return container end
    if not IsAuraContainerAvailable() then
        Warn("客户端不支持 AuraContainer（12.1 才有）→ 功能跳过")
        return nil
    end

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, HostFrame, "CustomAuraContainerTemplate")
    if not ok or not c then
        Warn("CreateFrame(AuraContainer) 失败 → " .. tostring(c))
        return nil
    end
    c:Hide()

    local opts = {
        -- 每创建一个光环按钮时调用一次：这里决定按钮长什么样
        initializeFrame = function(button)
            local okInit, errInit = pcall(function()
                -- CustomAuraButton 的部分处理器是“禁止替换”的，连 SetScript 都会报错，
                -- 所以直接关掉鼠标交互（也就不会触发 tooltip）
                button:EnableMouse(false)
                button:SetSize(RING_SIZE, RING_SIZE)
                -- ① 底圈：整圈圆环压暗，当“剩余时间要走完的轨道”（照抄 Utils.lua 的 bg）
                --    不画图标（故意不调用 button:SetIcon）
                local track = button:CreateTexture(nil, "BACKGROUND")
                track:SetAllPoints(button)
                track:SetTexture(RING_PATH)
                track:SetVertexColor(unpack(RING_TRACK_COLOR))

                -- ② 扫描圈：Cooldown + 同一张圆环贴图当 SwipeTexture（照抄 Utils.lua 的 cd）
                local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                cd:SetAllPoints(button)
                cd:SetDrawEdge(false)
                cd:SetDrawSwipe(true)
                cd:SetSwipeTexture(RING_PATH)
                cd:SetSwipeColor(unpack(RING_COLOR))
                cd:SetHideCountdownNumbers(true)
                pcall(cd.SetDrawBling, cd, false)

                -- ③ 关键：把 Cooldown 交给光环按钮，暴雪每帧按该 debuff 的剩余时间自动扫圈；
                --    续期 / 刷新 / 消失都由暴雪管，我们不用 SetCooldown、也不用 OnUpdate
                button:SetDurationCooldown(cd)
            end)
            if not okInit then Warn("initializeFrame 内部出错 → " .. tostring(errInit)) end
        end,
        maxFrameCount = math.huge, -- 具体显示几个由下面的 SetAuraGroupMaxFrameCount 决定
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Normal,
    }

    -- 以下几行与 PlayerDebuffDisplay.lua 一致，只是每行都带了打印
    -- ★ 第一层过滤：过滤器字符串（暴雪自己算，插件不参与光环数据读取）
    local filterString = SafeFilter(BASE_FILTER, DEFAULT_EXTRA_FILTER)
    Try("AddAuraGroup(debuffs, " .. filterString .. ")",
        function() c:AddAuraGroup("debuffs", filterString, opts) end)
    Try("SetUnit(player)", function() c:SetUnit("player") end)

    -- 注意：光环过滤（filterString / candidateFilters）不在这里写死，
    -- 而是由 ApplyAuraFilters() 按「命中的那条规则」动态套用（见下面的规则表）
    Try("SetAuraGroupMaxFrameCount(debuffs,1)",
        function() c:SetAuraGroupMaxFrameCount("debuffs", 1) end)
    Try("SetAuraGroupSortMethod(debuffs)", function()
        c:SetAuraGroupSortMethod("debuffs",
            AuraContainerSortMethod.Expiration, AuraContainerSortDirection.Normal)
    end)
    Try("SetFlowLayoutGrowthDirection(Right,Down)", function()
        c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    end)
    Try("SetFlowLayoutAnchorPoint(TOPLEFT)", function() c:SetFlowLayoutAnchorPoint("TOPLEFT") end)
    Try("SetFlowLayoutPadding(0,0,0,0)", function() c:SetFlowLayoutPadding(0, 0, 0, 0) end)
    Try("SetFlowLayoutMaximumLineSize", function() c:SetFlowLayoutMaximumLineSize(RING_SIZE) end)
    Try("SetAuraGroupLayout(debuffs)", function()
        c:SetAuraGroupLayout("debuffs", { elementSpacing = 0, lineSpacing = 0 })
    end)
    -- 容器锚点 = 宿主框左上角（只有一个按钮时，按钮正好和宿主框重合）
    Try("SetPoint(TOPLEFT ← 宿主框 TOPLEFT)",
        function() c:SetPoint("TOPLEFT", HostFrame, "TOPLEFT", 0, 0) end)

    container = c
    return c
end

-- ===== 判断“现在该不该显示”（规则表驱动）=====
-- 取一个安全的值（API 可能返回 nil / 秘密值）
local function SafeText(v)
    if v == nil then return "" end
    if issecretvalue and issecretvalue(v) then return "" end
    return tostring(v)
end

local function SafeNumber(v)
    if type(v) ~= "number" then return 0 end
    if issecretvalue and issecretvalue(v) then return 0 end
    return v
end

local function CallValue(fnName, ...)
    local fn = _G[fnName]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function CallText(fnName)
    return SafeText(CallValue(fnName))
end

local function CurrentMapID()
    local api = C_Map and C_Map.GetBestMapForUnit
    if type(api) ~= "function" then return 0 end
    local ok, id = pcall(api, "player")
    if not ok or type(id) ~= "number" then return 0 end
    return id
end

-- 大秘境钥石层数（没在打大秘境 = 0）
local function CurrentKeystone()
    local api = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo
    if type(api) ~= "function" then return 0 end
    local ok, level = pcall(api)
    if not ok or type(level) ~= "number" then return 0 end
    return level
end

-- 当前玩家职责（"TANK" / "HEALER" / "DAMAGER" / "NONE"）
-- 优先用插件自己的 addonTable.GetPlayerRole()（按专精判定，单人也拿得到），兜底队伍职责
local function CurrentPlayerRole()
    local fn = addonTable and addonTable.GetPlayerRole
    if type(fn) == "function" then
        local ok, role = pcall(fn)
        if ok and type(role) == "string" and role ~= "" then return role:upper() end
    end
    local ok2, role2 = pcall(UnitGroupRolesAssigned, "player")
    if ok2 and type(role2) == "string" and role2 ~= "" then return role2:upper() end
    return "NONE"
end

-- 第 index 个 scenario criteria 是否已击杀：nil = 拿不到（拿不到时规则算“不匹配”）
local MAX_BOSS_INDEX = 6
local function BossCompleted(index)
    local api = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo
    if type(api) ~= "function" then return nil end
    local ok, criteria = pcall(api, index)
    if not ok or type(criteria) ~= "table" then return nil end
    local ok2, completed = pcall(function() return criteria.completed end)
    if not ok2 or completed == nil then return nil end
    if issecretvalue and issecretvalue(completed) then return nil end
    return completed and true or false
end

-- 当前首领战 encounterID（0 = 不在首领战 / 小怪阶段）
-- ⚠️ 这里自己跟踪，不用 addonTable.GetEncounterID()：那个值只在勾选「首领语音」时才会更新，
--    没勾选时恒为 0（EncounterTimeline.lua 的 ENCOUNTER_START 分支会提前 return）。
local CurrentEncounterID = 0

-- 一次性收全“我在哪 / 打到哪”（供 MatchRule 逐条规则判定用）
local function GetHereInfo()
    local instanceName, instanceType, difficultyID, _, _, _, _, instanceID = GetInstanceInfo()
    local bossCompleted = {}
    for i = 1, MAX_BOSS_INDEX do bossCompleted[i] = BossCompleted(i) end
    return {
        subZone = CallText("GetSubZoneText"),      -- 子区域名
        miniZone = CallText("GetMinimapZoneText"), -- 小地图上显示的名字（没子区域时=大区域名）
        zone = CallText("GetZoneText"),            -- 大区域名
        realZone = CallText("GetRealZoneText"),    -- 真实大区域名（副本里=副本名）
        mapID = CurrentMapID(),
        role = CurrentPlayerRole(),                 -- 玩家职责（TANK / HEALER / DAMAGER / NONE）
        instanceID = SafeNumber(instanceID),
        encounterID = CurrentEncounterID,          -- 当前首领战（0 = 不在首领战）
        instanceName = SafeText(instanceName),
        instanceType = SafeText(instanceType),
        difficultyID = SafeNumber(difficultyID),
        keystone = CurrentKeystone(),
        indoor = CallValue("IsIndoors"),
        bossCompleted = bossCompleted,
    }
end

local function RuleLabel(rule)
    local name = type(rule) == "table" and rule.name
    return name and ("（" .. tostring(name) .. "）") or ""
end

-- 职责写法归一化成集合：{ TANK = true } / { "TANK", "DAMAGER" } / "TANK" 都接受
local function NormalizeRoleSet(v)
    local set = {}
    if type(v) == "string" then
        set[v:upper()] = true
    elseif type(v) == "table" then
        for k, val in pairs(v) do
            if type(k) == "number" then
                if type(val) == "string" then set[val:upper()] = true end
            elseif val then
                set[tostring(k):upper()] = true
            end
        end
    else
        return nil
    end
    return set
end

-- 单条规则：内部所有条件都要满足（AND）；不写的字段不参与判断
local function MatchRule(rule, info)
    if type(rule) ~= "table" then return false end

    if rule.instanceIDs and not rule.instanceIDs[info.instanceID] then return false end
    if rule.encounterIDs and not rule.encounterIDs[info.encounterID] then return false end
    local roleCfg = rule.roles or rule.role     -- roles / role 两种字段名都认
    if roleCfg then
        local set = NormalizeRoleSet(roleCfg)
        if set and not set[info.role] then return false end
    end
    if rule.mapIDs and not rule.mapIDs[info.mapID] then return false end
    if rule.difficultyIDs and not rule.difficultyIDs[info.difficultyID] then return false end
    if rule.subZones then
        local hit = (info.subZone ~= "" and rule.subZones[info.subZone])
            or (info.miniZone ~= "" and rule.subZones[info.miniZone])
        if not hit then return false end
    end
    if rule.keystoneMin and not (info.keystone >= rule.keystoneMin) then return false end
    if rule.indoor ~= nil and info.indoor ~= rule.indoor then return false end
    if rule.bossProgress then
        for index, want in pairs(rule.bossProgress) do
            if info.bossCompleted[index] ~= want then return false end -- nil(拿不到) 也不匹配
        end
    end
    return true
end

local function ShouldShowHere()
    local info = GetHereInfo()

    -- 排除规则优先
    for index, rule in ipairs(HIDE_RULES) do
        if MatchRule(rule, info) then
            return false, "命中排除规则 #" .. index .. RuleLabel(rule), nil
        end
    end

    -- 没写显示规则 = 不限制
    if #SHOW_RULES == 0 then return true, "未设显示规则，各地都显示", nil end

    for index, rule in ipairs(SHOW_RULES) do
        if MatchRule(rule, info) then
            return true, "命中显示规则 #" .. index .. RuleLabel(rule), rule -- 第三个返回值：命中的规则
        end
    end
    return false, "没有任何显示规则命中", nil
end

-- ===== 总开关：与控制台「显示倒计时圆环」共用（同一个 db.ringEnabled）=====
-- 勾选 = 显示；取消勾选 = 所有圆环（含本文件的）一律不显示，不看区域规则。
local function IsRingEnabled()
    local db = DiGuaTimelineAudioHelper
    if type(db) ~= "table" then return true end -- 存档还没建好时按默认（显示）处理
    return db.ringEnabled ~= false
end

-- 按当前所在地 / 战斗进度开关整个容器（暴雪那套过滤只管光环，不管你在哪、打到哪）
local function ApplyShowGate()
    local c = container
    if not c then return end

    -- ★ 总开关优先：取消勾选「显示倒计时圆环」→ 无条件隐藏，不再走下面的区域规则
    if not IsRingEnabled() then
        pcall(c.SetEnabled, c, false)
        c:Hide()
        return
    end

    local show, _, rule = ShouldShowHere()
    if show then
        ApplyAuraFilters(rule) -- ★ 按命中的规则套用“这一套”光环过滤数值
        pcall(c.SetEnabled, c, true)
        pcall(c.UpdateAllAuras, c)
        c:Show()
    else
        pcall(c.SetEnabled, c, false)
        c:Hide()
    end
end

local function Enable()
    if not BuildContainer() then return end
    ApplyShowGate()
end

-- 供控制台勾选框调用：总开关一变就立刻重判（不用等下一次区域 / 光环事件）
-- 取消勾选时容器可能还没建 / 已建，两种情况都要能立刻生效
addonTable.RefreshForeignDebuffRing = function()
    if not IsRingEnabled() then
        if container then pcall(container.SetEnabled, container, false) ; container:Hide() end
        return
    end
    Enable() -- 内部会 BuildContainer（已建则复用）+ ApplyShowGate
end
addonTable.IsForeignDebuffRingEnabled = IsRingEnabled

-- ===== 事件 =====
-- 登录 / 过图后确保容器已建好；之后光环的增删**不用我们管**（AuraContainer 自己会跟随），
-- UNIT_AURA 只是照 PlayerDebuffDisplay 的做法再兜底刷一次。
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED")          -- 同一大区域内换了子区域（进城 / 进洞 / 换楼层）
f:RegisterEvent("ZONE_CHANGED_INDOORS")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- 换地图 / 进副本（最常用）
-- Boss 进度类：规则表里用了 bossProgress 时，Boss 一死就要立刻重判（否则圆环会赖着不走）
f:RegisterEvent("SCENARIO_CRITERIA_UPDATE") -- 副本/Boss 进度更新（5人本靠它）
f:RegisterEvent("CRITERIA_UPDATE")          -- 成就/场景进度更新
f:RegisterEvent("BOSS_KILL")                -- 团本 Boss 击杀
-- 首领战起止：规则表里用了 encounterIDs 时，开战 / 结束都要立刻重判
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Enable() -- 登录 / 过图 / reload 后确保容器已建好，并重判区域
    elseif event == "ENCOUNTER_START" then
        CurrentEncounterID = tonumber(arg1) or 0
        ApplyShowGate()
    elseif event == "ENCOUNTER_END" then
        CurrentEncounterID = 0
        ApplyShowGate()
    elseif event == "UNIT_AURA" then
        -- 总开关关着时直接跳过刷新（容器已隐藏，不必再算）
        if container and IsRingEnabled() then pcall(container.UpdateAllAuras, container) end
    else
        ApplyShowGate() -- ZONE_CHANGED*：换地方了，重新按规则表判一次
    end
end)
