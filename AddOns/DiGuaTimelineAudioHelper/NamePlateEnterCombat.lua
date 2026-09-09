-- NamePlateEnterCombat.lua
-- 姓名板出现事件：怪进入战斗时，按副本条件给出倒计时提示
-- 结构与 UNIT_SPELLCAST_START 一致：低耦合代码块直接写在 OnEvent 里，条件完整罗列

local addonName, addonTable = ...

-- 记录每个单位是否已触发过提示，保证同一单位只提示第一次
-- （单位离开视野/死亡时由 NAME_PLATE_UNIT_REMOVED.lua 清空，下一只怪可重新触发）
addonTable.UnitTargetTriggered = addonTable.UnitTargetTriggered or {}
-- 记录每个单位的进战斗轮询 ticker，单位消失时由 NAME_PLATE_UNIT_REMOVED.lua 兜底取消
addonTable.UnitTargetTickers = addonTable.UnitTargetTickers or {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

frame:SetScript("OnEvent", function(self, event, unitTarget)
    if event ~= "NAME_PLATE_UNIT_ADDED" then return end
    if not unitTarget then return end

    -- 处理单个单位：所有怪的低耦合判断块都平铺在这里（写法同 UNIT_SPELLCAST_START）
    -- 血条刚出现时怪可能还没进战斗，靠下面的轮询每秒重查，进战斗才触发
    local function CheckThisUnit()
        if addonTable.UnitTargetTriggered[unitTarget] then return end

        -- ============================
        -- ==      虚空之痕竞技场    ==
        -- ============================
        -- 法术风暴拉杰克斯（雷鸣风暴 / 瓦解宝珠）—— 首次施放 20.3 / 10.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 法术风暴拉杰克斯
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.XuChuFaShi == true
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(613397, 20.3, "雷鳴風暴", unitTarget)
            addonTable.CustomEncounterBar(237589, 10.8, "瓦解寶珠", unitTarget)
        end
        -- 虚触法师（虚无喷发）—— 首次施放 15.9s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 虚触法师
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.XuChuFaShi == false
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(4914670, 15.9, "注意點名", unitTarget)
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 鲁莽监督者（老1前）
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.LuMangJianDuZhe == false
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132340, 7.4, "護盾快打", unitTarget)
            addonTable.CustomEncounterBar(236251, 20.8, "劍刃風暴", unitTarget)
        end


        -- 不屈的埃吉拉（凶猛飞跃）—— 首次施放 7.6s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 不屈的埃吉拉
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.LuMangJianDuZhe == true
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(236171, 7.6, "注意點名", unitTarget)
            addonTable.CustomEncounterBar(6035322, 22, "準備拉人", unitTarget)
        end
        -- 几丁高斯（险恶光环）—— 首次施放 17.1s（该姓名板无进战斗记录 = 第一只）
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 几丁高斯
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.JiDingGaoSi == nil
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 标记已触发，防止重复
            addonTable.JiDingGaoSi = true
            addonTable.CustomEncounterBar(840194, 17.1, "險惡光環", unitTarget)
            return
        end
        -- 布鲁托克（粉碎冲锋 / 头槌重击）—— 首次施放 26.8 / 47.4s（该姓名板有进战斗记录 = 第二只）
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 布鲁托克
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虚空之痕竞技场)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.JiDingGaoSi == true
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 标记已触发，防止重复
            addonTable.JiDingGaoSi = nil
            addonTable.CustomEncounterBar(1127958, 26.8, "粉碎沖鋒", unitTarget)
            addonTable.CustomEncounterBar(1127958, 47.4, "頭槌重擊", unitTarget)
            return
        end

        -- ============================
        -- ==        毒牙祭坛        ==
        -- ============================
        -- 双牙蹂躏者（准备诱捕 / 躲开头前）—— 生物家族，法力系
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 双牙蹂躏者
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(132274, 6.5, "準備誘捕", unitTarget)
            addonTable.CustomEncounterBar(135798, 14.9, "躲開正面", unitTarget)
        end
        -- 仪式首领（坦克尖刺 / 准备吸奶盾）—— 非生物家族，法力系，室外特定地图
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 仪式首领
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地图ID
            and IsIndoors() == false -- 在室外
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 标记已触发，防止重复
            -- 坦克尖刺：只对非 DPS（坦克/治疗）触发
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                addonTable.CustomEncounterBar(132109, 5.8, "坦克尖刺", unitTarget)
            end
            addonTable.CustomEncounterBar(132334, 11.7, "準備吸奶盾", unitTarget)
        end
        -- 振响的扭缠蛇（准备AOE / 坦克尖刺）—— 非生物家族，法力系，地图 2589，Boss1 已过 / Boss2 未过
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 振响的扭缠蛇
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地图ID
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1 已过
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2 未过
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(6238561, 11.6, "準備AOE", unitTarget)
            -- 坦克尖刺：只對非 DPS（坦克/治療）觸發
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                addonTable.CustomEncounterBar(136067, 5.5, "坦克尖刺", unitTarget)
            end
        end
        -- 晋升之蛇（准备小怪 / 注意躲圈 / 坦克头前）—— 非生物家族，法力系，地图 2590 室内，Boss1/Boss2 已过
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 晋升之蛇
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地图ID
            and IsIndoors() == true -- 在室内
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1 已过
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2 已过
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(132211, 3.8, "準備小怪", unitTarget)
            addonTable.CustomEncounterBar(5764921, 21, "注意躲圈", unitTarget)
            addonTable.CustomEncounterBar(5764918, 29.5, "坦克頭前", unitTarget)
        end
        -- 乌拉特克神选者（注意射线）—— 非生物家族，非法力系，地图 2590，Boss1/Boss2 已过 / Boss3 未过
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 乌拉特克神选者
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭坛)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0 -- 非法力系
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地图ID
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1 已过
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2 已过
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3 未过
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(5764925, 17.5, "注意射線", unitTarget)
        end

        -- ============================
        -- ==      纳洛拉克的洞穴    ==
        -- ============================
        -- 饥渴之灵（苦难盛宴 / 饥荒雕像）—— 首次施放 6.4 / 2.7s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 饥渴之灵
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(2101983, 4.4, "轉火圖騰", unitTarget)
            addonTable.CustomEncounterBar(3154546, 8, "準備AOE", unitTarget)
        end
        -- 决意化身（粉碎 / 冰川之墓）—— 首次施放 15.4 / 9.3s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 决意化身
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132318, 13.4, "近戰大圈", unitTarget)
            addonTable.CustomEncounterBar(236209, 7.3, "準備定身", unitTarget)
        end
        -- 神灵代言人纳尼亚（地震术 / 动荡图腾）—— 首次施放 7.2 / 14.5s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 神灵代言人纳尼亚
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(451165, 5.2, "注意點名", unitTarget)
            addonTable.CustomEncounterBar(135829, 12.5, "準備小怪", unitTarget)
        end
        -- 老练的战争使者（原始回响；毒矛乱射只有播音不做倒计时）—— 首次施放 4.2s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 老练的战争使者
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (纳洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(463283, 4.2, "準備AOE", unitTarget)
        end

        -- ============================
        -- ==      红玉新生法池      ==
        -- ============================
        -- 炎缚毁灭者（地狱烈火）—— 首次施放 10.4s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地狱烈火
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (红玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(460698, 10.4, "準備AOE", unitTarget)
        end

        -- ============================
        -- ==      塞塔里斯神庙      ==
        -- ============================
        -- 沙怒石拳战士（震地 / 破甲猛击）—— 首次施放 18.6 / 4s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 沙怒石拳战士
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132358, 18.6, "小心擊退", unitTarget)
            addonTable.CustomEncounterBar(132318, 4, "坦克尖刺", unitTarget)
        end
        -- 宝珠守望者（毒刃斩击 / 蚀骨践踏）—— 首次施放 9.1 / 16.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 宝珠守望者
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132287, 3.1, "坦克尖刺", unitTarget)
            addonTable.CustomEncounterBar(5764923, 11.8, "準備AOE", unitTarget)
        end
        -- 砂誓骑兵（黄沙冲刷）—— 首次施放 7.1s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 砂誓骑兵
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔里斯神庙)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(796637, 7.1, "躲開正面", unitTarget)
            addonTable.CustomEncounterBar(2011146, 18.5, "召喚小怪", unitTarget)
        end

        -- ============================
        -- ==         夺目谷         ==
        -- ============================
        -- 薯身蟾主母（吐舌攻击 / 蛤蟆卵 / 喷毒）—— 首次施放 3.7 / 7.3 / 15.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 薯身蟾主母
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (夺目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3 已过
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4 未过
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            -- 吐舌攻击：只对非 DPS（坦克/治疗）触发
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                addonTable.CustomEncounterBar(252175, 3.6, "坦克擊飛", unitTarget)
            end
            addonTable.CustomEncounterBar(236999, 8.6, "召喚小怪", unitTarget)
            addonTable.CustomEncounterBar(136016, 16.8, "準備AOE", unitTarget)
        end

        -- ============================
        -- ==        诸王之眠        ==
        -- ============================
        -- 净化构造体（净化打击）—— 首次施放 1.9s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 净化构造体
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "荣耀亡者大厅" or GetSubZoneText() == "先王之堂") -- 子区域
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(451169, 1.9, "準備AOE", unitTarget)
        end
        -- 葬礼构造体（埋葬）—— 首次施放 15.7s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 葬礼构造体
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and (GetSubZoneText() == "不朽肉身密室" or GetSubZoneText() == "永存之室") -- 子区域
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and addonTable.GetEncounterID() == 0 -- 非首领战
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(236399, 15.7, "準備救人", unitTarget)
        end
        -- 复活的妖术师（妖术齐射；暗影冰霜箭无倒计时条跳过）—— 首次施放 12.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 复活的妖术师
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitGroupRolesAssigned("player") ~= "HEALER"
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(615099, 12.8, "打斷大怪", unitTarget)
        end
        -- 祖尔之影（注意点名 / 注意踩圈）—— 首次施放 6.1 / 12.5s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 祖尔之影
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (诸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地图ID
            and IsIndoors() == true -- 在室内
            and UnitLevel(unitTarget) == -1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(1022945, 5.1, "注意點名", unitTarget)
            addonTable.CustomEncounterBar(1386548, 12.6, "注意踩圈", unitTarget)
        end

        -- ============================
        -- ==        密谋小径        ==
        -- ============================
        -- 被买通的守卫（盾击 / 飞刃）—— 首次施放 16.2 / 10.1s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 被买通的守卫
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132357, 13.1, "坦克尖刺", unitTarget)
        end
        -- 巨大的邪能浮龙（召唤浮龙；腐蚀唾液无倒计时条跳过）—— 首次施放 14.6s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 巨大的邪能浮龙
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地图ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(7301939, 14.6, "召喚小怪", unitTarget)
        end


        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 邪能主宰鲁科西
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 是否在室内
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 分类
            and UnitAffectingCombat(unitTarget) == true -- 是否在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3
            and UnitIsLieutenant(unitTarget) == true -- 是否为中尉
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(1305149, 6, "準備AOE", unitTarget)
            addonTable.CustomEncounterBar(1305156, 11, "注意射線", unitTarget)
        end
        

        -- 腐化的术士（吸取生命 / 厄运诅咒）—— 首次施放 7.1 / 13.4s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 吸取生命 -- 厄运诅咒（工具）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密谋小径)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地图ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在战斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(136122, 13.4, "厄運詛咒", unitTarget)
            addonTable.CustomEncounterBar(136169, 7.1, "吸取生命", unitTarget)
        end
    end

    CheckThisUnit() -- 立刻查一次（可能已经在战斗）

    -- 没进战斗则每秒轮询，直到进战斗触发 / 单位消失
    if not addonTable.UnitTargetTriggered[unitTarget] then
        if addonTable.UnitTargetTickers[unitTarget] then
            addonTable.UnitTargetTickers[unitTarget]:Cancel()
        end
        local ticker
        ticker = C_Timer.NewTicker(1, function()
            CheckThisUnit()
            if addonTable.UnitTargetTriggered[unitTarget] or not UnitExists(unitTarget) then
                ticker:Cancel()
                addonTable.UnitTargetTickers[unitTarget] = nil
            end
        end)
        addonTable.UnitTargetTickers[unitTarget] = ticker
    end
end)

