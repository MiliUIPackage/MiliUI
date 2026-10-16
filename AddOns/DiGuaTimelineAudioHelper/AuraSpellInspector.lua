-- AuraSpellInspector.lua
-- 「法术属性查询」工具（纯查询，不参与任何显示逻辑 —— 与 ForeignDebuffRing.lua 互不干扰）
--
--   /asq <法术ID>        查单个技能：名称 / isPriorityAura / IsSpellImportant / secrecy
--   /asq scan            扫插件光环表（NormalAuraSound 的 addonTable.NormalAura），只列命中的
--   /asq scan all        全列（上限 80 行）
--   /asq scan <关键词>    按名字过滤，如 /asq scan 虚无
--
-- 为什么这些查询随时可用：读的是「法术本身」的属性 + 插件自己的 Lua 表，
-- 完全不碰光环数据，所以不受 12.1 的 taint / RequiresUnitAuraAccess 限制。
-- AuraContainer 到底能用哪些过滤字段，就是靠这些查询确认的。
--
-- 字段含义（对应 AuraContainer 的候选过滤器）：
--   priority=true  → 规则里可写 priorityOnly = true      （AuraUtil.IsPriorityDebuff）
--   important=true → 规则里可写 extraFilter = "IMPORTANT"（C_Spell.IsSpellImportant）
--   secrecy 标 NeverSecret 的，才允许 includeSpellIDs 按法术 ID 过滤（其它会被身份门控静默挡掉）

local addonName, addonTable = ...

-- ==================== 打印 / 安全调用 ====================
local function Log(msg)
    print("|cff00ccff[DiGua/查询]|r " .. tostring(msg))
end
local function Warn(msg)
    print("|cffff4444[DiGua/查询]|r " .. tostring(msg))
end

-- 直接传函数进来的安全调用（用于 C_Spell.xxx 这种带命名空间的）
local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function SpellName(spellID)
    return SafeCall(C_Spell and C_Spell.GetSpellName, spellID)
        or SafeCall(GetSpellInfo, spellID)
end

-- 返回：priority, important, secrecy, neverSecret
local function SpellFlags(spellID)
    local priority = SafeCall(AuraUtil and AuraUtil.IsPriorityDebuff, spellID)
    local important = SafeCall(C_Spell and C_Spell.IsSpellImportant, spellID)
    local secrecy = SafeCall(C_Secrets and C_Secrets.GetSpellAuraSecrecy, spellID)
    local neverSecret = (secrecy ~= nil and Enum and Enum.SecrecyLevel
        and secrecy == Enum.SecrecyLevel.NeverSecret) or false
    return priority, important, secrecy, neverSecret
end

-- ==================== 查单个技能 ====================
local function ReportOne(spellID)
    local name = SpellName(spellID)
    local priority, important, secrecy, neverSecret = SpellFlags(spellID)

    Log("法术 ID " .. spellID .. "：")
    Log("  名称                = " .. tostring(name or "（查不到，ID 可能不对）"))
    Log("  isPriorityAura      = " .. tostring(priority)
        .. "   ← true 可用 priorityOnly = true")
    Log("  IsSpellImportant    = " .. tostring(important)
        .. "   ← true 可用 extraFilter = \"IMPORTANT\"")
    Log("  GetSpellAuraSecrecy = " .. tostring(secrecy)
        .. (neverSecret and "（NeverSecret → 可用 includeSpellIDs）"
            or "（非 NeverSecret → includeSpellIDs 会被门控挡掉）"))
end

-- ==================== 扫插件自己的光环表 ====================
-- 注意：读的是插件自己的 Lua 表 + 法术属性，不碰光环数据，所以不受 taint 限制
local function CollectNormalAuraSpellIDs()
    local list, seen = {}, {}
    local root = addonTable and addonTable.NormalAura
    if type(root) ~= "table" then return list end
    for _, sub in pairs(root) do
        if type(sub) == "table" then
            for spellID in pairs(sub) do
                if type(spellID) == "number" and not seen[spellID] then
                    seen[spellID] = true
                    list[#list + 1] = spellID
                end
            end
        end
    end
    table.sort(list)
    return list
end

local MAX_LINES = 80

local function ReportScan(arg)
    if type(addonTable and addonTable.NormalAura) ~= "table" then
        Warn("拿不到 addonTable.NormalAura（NormalAuraSound.lua 没加载？）")
        return
    end

    local ids = CollectNormalAuraSpellIDs()
    local showAll = (arg == "all")
    local keyword = (arg ~= "" and arg ~= "all") and arg or nil
    Log("光环表里共 " .. #ids .. " 个技能 ID，逐个查属性…"
        .. (keyword and ("（只看名字含「" .. keyword .. "」的）") or ""))

    local hits, shown, skipped = 0, 0, 0
    for _, spellID in ipairs(ids) do
        local name = SpellName(spellID)
        local priority, important, secrecy, neverSecret = SpellFlags(spellID)

        local matchKeyword = true
        if keyword then
            matchKeyword = (type(name) == "string")
                and name:lower():find(keyword, 1, true) ~= nil
        end

        if matchKeyword and (showAll or priority or important) then
            if priority or important then hits = hits + 1 end
            if shown < MAX_LINES then
                shown = shown + 1
                Log("  " .. spellID .. "  " .. tostring(name or "?")
                    .. "  priority=" .. tostring(priority)
                    .. "  important=" .. tostring(important)
                    .. "  secrecy=" .. tostring(secrecy)
                    .. (neverSecret and "（NeverSecret，可用 includeSpellIDs）" or ""))
            else
                skipped = skipped + 1
            end
        end
    end

    Log("扫完：priority/important 命中 " .. hits .. " 个，显示 " .. shown .. " 行"
        .. (skipped > 0 and ("，还有 " .. skipped .. " 条未显示") or ""))
end

-- ==================== 命令 ====================
SLASH_DIGUAASQ1 = "/asq"
SlashCmdList["DIGUAASQ"] = function(msg)
    msg = tostring(msg or ""):lower():gsub("%s+", "")

    if msg == "" then
        Log("用法：/asq <法术ID> = 查单个；/asq scan [all|关键词] = 扫插件光环表")
    elseif msg:sub(1, 4) == "scan" then
        ReportScan(msg:sub(5))
    else
        local spellID = tonumber(msg)
        if spellID then
            ReportOne(spellID)
        else
            Log("看不懂这个参数：「" .. msg .. "」；用法：/asq <法术ID> 或 /asq scan [all|关键词]")
        end
    end
end

-- ====================================================================
-- 扫描结果存档
-- ====================================================================
-- 2026-09-12 扫描本插件光环表（374 个 ID），priority/important 命中 21 个：
--
--   priority=true（2 个）
--     [1217973] 厄运诅咒
--     [1296025] 闪现新星
--
--   important=true（19 个，priority 均为 false）
--     [204018]  破咒祝福      [267273]  毒性新星      [267763]  恶疾排放
--     [269972]  妖术齐射      [270492]  妖术          [385536]  燃焰弹幕
--     [1201554] 诱惑          [1233398] 疯狂尖啸      [1238294] 迷乱尖叫
--     [1249621] 狂暴之沙      [1286837] 墓缚          [1293307] 扰乱心智
--     [1294557] 刺耳嘶鸣      [1297696] 治疗之风      [1298899] 挫志怒吼
--     [1300248] 吞噬          [1302158] 烈焰震击      [1308100] 涂毒偷袭
--     [1309919] 冰冷咆哮
--
-- ⚠️ 结论：这 21 个的 secrecy 全是 2（非 NeverSecret）→ includeSpellIDs 这条路对它们全部走不通。
--    所以实际能用的只剩两个"粗筛"：extraFilter = "IMPORTANT"（那 19 个）/ priorityOnly = true（那 2 个）。
--    另外注意这两个标记是「法术自身」的属性，跟"会不会上到玩家身上"无关：
--    例如 [204018] 破咒祝福 是给自己上的增益，它同样被标为 important。
--    想精确到"某个 debuff"，目前只能靠位置/进度规则（instanceIDs / bossProgress / subZones）。
-- ====================================================================
