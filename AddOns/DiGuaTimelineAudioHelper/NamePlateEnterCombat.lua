-- NamePlateEnterCombat.lua
-- 姓名板出現事件：怪進入戰斗時，按副本條件給出倒計時提示
-- 結構與 UNIT_SPELLCAST_START 一致：低耦合代碼塊直接寫在 OnEvent 裡，條件完整羅列

local addonName, addonTable = ...

-- 記錄每個單位是否已觸發過提示，保證同一單位只提示第一次
-- （單位離開視野/死亡時由 NAME_PLATE_UNIT_REMOVED.lua 清空，下一只怪可重新觸發）
addonTable.UnitTargetTriggered = addonTable.UnitTargetTriggered or {}
-- 記錄每個單位的進戰斗輪詢 ticker，單位消失時由 NAME_PLATE_UNIT_REMOVED.lua 兜底取消
addonTable.UnitTargetTickers = addonTable.UnitTargetTickers or {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

frame:SetScript("OnEvent", function(self, event, unitTarget)
    if event ~= "NAME_PLATE_UNIT_ADDED" then return end
    if not unitTarget then return end

    -- 處理單個單位：所有怪的低耦合判斷塊都平鋪在這裡（寫法同 UNIT_SPELLCAST_START）
    -- 血條剛出現時怪可能還沒進戰斗，靠下面的輪詢每秒重查，進戰斗才觸發
    local function CheckThisUnit()
        if addonTable.UnitTargetTriggered[unitTarget] then return end

        -- ============================
        -- ==      虛空之痕競技場    ==
        -- ============================
        -- 法術風暴拉傑克斯（雷鳴風暴 / 瓦解寶珠）—— 首次施放 20.3 / 10.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 法術風暴拉傑克斯
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.XuChuFaShi == true
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(613397, 20.3, "雷鳴風暴", unitTarget)
            addonTable.CustomEncounterBar(237589, 10.8, "瓦解寶珠", unitTarget)
        end
        -- 虛觸法師（虛無噴發）—— 首次施放 15.9s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 虛觸法師
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.XuChuFaShi == false
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(4914670, 15.9, "注意點名", unitTarget)
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 魯莽監督者（老1前）
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
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


        -- 不屈的埃吉拉（凶猛飛躍）—— 首次施放 7.6s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 不屈的埃吉拉
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2574 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.LuMangJianDuZhe == true
            and C_ChallengeMode.GetActiveKeystoneInfo()
            and C_ChallengeMode.GetActiveKeystoneInfo() >= 2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(236171, 7.6, "注意點名", unitTarget)
        end
        -- 幾丁高斯（險惡光環）—— 首次施放 17.1s（該姓名板無進戰斗記錄 = 第一只）
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 幾丁高斯
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.JiDingGaoSi == nil
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.JiDingGaoSi = true
            addonTable.CustomEncounterBar(840194, 17.1, "險惡光環", unitTarget)
            return
        end
        -- 布魯托克（粉碎沖鋒 / 頭槌重擊）—— 首次施放 26.8 / 47.4s（該姓名板有進戰斗記錄 = 第二只）
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 布魯托克
            and select(8, GetInstanceInfo()) == 2923 -- 副本ID (虛空之痕競技場)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2572 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and addonTable.JiDingGaoSi == true
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.JiDingGaoSi = nil
            addonTable.CustomEncounterBar(1127958, 26.8, "粉碎沖鋒", unitTarget)
            addonTable.CustomEncounterBar(1127958, 47.4, "頭槌重擊", unitTarget)
            return
        end

        -- ============================
        -- ==        毒牙祭壇        ==
        -- ============================
        -- 雙牙蹂躪者（準備誘捕 / 躲開頭前）—— 生物家族，法力系
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 雙牙蹂躪者
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(132274, 6.5, "準備誘捕", unitTarget)
            addonTable.CustomEncounterBar(135798, 14.9, "躲開頭前", unitTarget)
        end
        -- 儀式首領（坦克尖刺 / 準備吸奶盾）—— 非生物家族，法力系，室外特定地圖
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 儀式首領
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and ((C_Map.GetBestMapForUnit("player") or 0) == 2588 or (C_Map.GetBestMapForUnit("player") or 0) == 2590) -- 地圖ID
            and IsIndoors() == false -- 在室外
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            -- 坦克尖刺：只對非 DPS（坦克/治療）觸發
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                addonTable.CustomEncounterBar(132109, 5.8, "坦克尖刺", unitTarget)
            end
            addonTable.CustomEncounterBar(132334, 11.7, "準備吸奶盾", unitTarget)
        end
        -- 振響的扭纏蛇（準備AOE / 坦克尖刺）—— 非生物家族，法力系，地圖 2589，Boss1 已過 / Boss2 未過
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 振響的扭纏蛇
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_Map.GetBestMapForUnit("player") or 0) == 2589 -- 地圖ID
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1 已過
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2 未過
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(6238561, 11.6, "準備AOE", unitTarget)
            -- 坦克尖刺：只對非 DPS（坦克/治療）觸發
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                addonTable.CustomEncounterBar(136067, 5.5, "坦克尖刺", unitTarget)
            end
        end
        -- 晉升之蛇（準備小怪 / 注意躲圈 / 坦克頭前）—— 非生物家族，法力系，地圖 2590 室內，Boss1/Boss2 已過
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 晉升之蛇
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1 已過
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2 已過
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(132211, 3.8, "準備小怪", unitTarget)
            addonTable.CustomEncounterBar(5764921, 21, "注意躲圈", unitTarget)
            addonTable.CustomEncounterBar(5764918, 29.5, "坦克頭前", unitTarget)
        end
        -- 烏拉特克神選者（注意射線）—— 非生物家族，非法力系，地圖 2590，Boss1/Boss2 已過 / Boss3 未過
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 烏拉特克神選者
            and select(8, GetInstanceInfo()) == 2993 -- 副本ID (毒牙祭壇)
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0 -- 非法力系
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_Map.GetBestMapForUnit("player") or 0) == 2590 -- 地圖ID
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1 已過
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2 已過
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == false -- Boss3 未過
        then
            addonTable.UnitTargetTriggered[unitTarget] = true -- 標記已觸發，防止重復
            addonTable.CustomEncounterBar(5764925, 17.5, "注意射線", unitTarget)
        end

        -- ============================
        -- ==      納洛拉克的洞穴    ==
        -- ============================
        -- 飢渴之靈（苦難盛宴 / 飢荒雕像）—— 首次施放 6.4 / 2.7s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 飢渴之靈
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(2101983, 4.4, "轉火圖騰", unitTarget)
            addonTable.CustomEncounterBar(3154546, 8, "準備AOE", unitTarget)
        end
        -- 決意化身（粉碎 / 冰川之墓）—— 首次施放 15.4 / 9.3s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 決意化身
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2514 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132318, 13.4, "近戰大圈", unitTarget)
            addonTable.CustomEncounterBar(236209, 7.3, "準備定身", unitTarget)
        end
        -- 神靈代言人納尼亞（地震術 / 動蕩圖騰）—— 首次施放 7.2 / 14.5s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 神靈代言人納尼亞
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(451165, 5.2, "注意點名", unitTarget)
            addonTable.CustomEncounterBar(135829, 12.5, "準備小怪", unitTarget)
        end
        -- 老練的戰爭使者（原始回響；毒矛亂射只有播音不做倒計時）—— 首次施放 4.2s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 老練的戰爭使者
            and select(8, GetInstanceInfo()) == 2825 -- 副本ID (納洛拉克的洞穴)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2513 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(463283, 4.2, "準備AOE", unitTarget)
        end

        -- ============================
        -- ==      紅玉新生法池      ==
        -- ============================
        -- 炎縛毀滅者（地獄烈火）—— 首次施放 10.4s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 地獄烈火
            and select(8, GetInstanceInfo()) == 2521 -- 副本ID (紅玉新生法池)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2094 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(460698, 10.4, "準備AOE", unitTarget)
        end

        -- ============================
        -- ==      塞塔裡斯神廟      ==
        -- ============================
        -- 沙怒石拳戰士（震地 / 破甲猛擊）—— 首次施放 18.6 / 4s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 沙怒石拳戰士
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132358, 18.6, "小心擊退", unitTarget)
            addonTable.CustomEncounterBar(132318, 4, "坦克尖刺", unitTarget)
        end
        -- 寶珠守望者（毒刃斬擊 / 蝕骨踐踏）—— 首次施放 9.1 / 16.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 寶珠守望者
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1043 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132287, 9.1, "坦克尖刺", unitTarget)
            addonTable.CustomEncounterBar(5764923, 16.8, "準備AOE", unitTarget)
        end
        -- 砂誓騎兵（黃沙沖刷）—— 首次施放 7.1s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 砂誓騎兵
            and select(8, GetInstanceInfo()) == 1877 -- 副本ID (塞塔裡斯神廟)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1038 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(796637, 7.1, "躲開頭前", unitTarget)
            addonTable.CustomEncounterBar(2011146, 18.5, "召喚小怪", unitTarget)
        end

        -- ============================
        -- ==         奪目谷         ==
        -- ============================
        -- 薯身蟾主母（吐舌攻擊 / 蛤蟆卵 / 噴毒）—— 首次施放 3.7 / 7.3 / 15.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 薯身蟾主母
            and select(8, GetInstanceInfo()) == 2859 -- 副本ID (奪目谷)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2500 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and select(2, UnitCreatureFamily(unitTarget)) -- 是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3 已過
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4 未過
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            -- 吐舌攻擊：只對非 DPS（坦克/治療）觸發
            if UnitGroupRolesAssigned("player") ~= "DAMAGER" then
                addonTable.CustomEncounterBar(252175, 3.6, "坦克擊飛", unitTarget)
            end
            addonTable.CustomEncounterBar(236999, 8.6, "召喚小怪", unitTarget)
            addonTable.CustomEncounterBar(136016, 16.8, "準備AOE", unitTarget)
        end

        -- ============================
        -- ==        諸王之眠        ==
        -- ============================
        -- 淨化構造體（淨化打擊）—— 首次施放 1.9s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 淨化構造體
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "榮耀亡者大廳" or GetSubZoneText() == "先王之堂") -- 子區域
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(451169, 1.9, "準備AOE", unitTarget)
        end
        -- 葬禮構造體（埋葬）—— 首次施放 15.7s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 葬禮構造體
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and (GetSubZoneText() == "不朽肉身密室" or GetSubZoneText() == "永存之室") -- 子區域
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == false -- Boss2
            and addonTable.GetEncounterID() == 0 -- 非首領戰
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(236399, 15.7, "準備救人", unitTarget)
        end
        -- 復活的妖術師（妖術齊射；暗影冰霜箭無倒計時條跳過）—— 首次施放 12.8s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 復活的妖術師
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
            and UnitGroupRolesAssigned("player") ~= "HEALER"
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(615099, 12.8, "打斷大怪", unitTarget)
        end
        -- 祖爾之影（注意點名 / 注意踩圈）—— 首次施放 6.1 / 12.5s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 祖爾之影
            and select(8, GetInstanceInfo()) == 1762 -- 副本ID (諸王之眠)
            and (C_Map.GetBestMapForUnit("player") or 0) == 1004 -- 地圖ID
            and IsIndoors() == true -- 在室內
            and UnitLevel(unitTarget) == -1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(3) and C_ScenarioInfo.GetCriteriaInfo(3).completed or false) == true -- Boss3
            and (C_ScenarioInfo.GetCriteriaInfo(4) and C_ScenarioInfo.GetCriteriaInfo(4).completed or false) == false -- Boss4
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(1022945, 5.1, "注意點名", unitTarget)
            addonTable.CustomEncounterBar(1386548, 12.6, "注意踩圈", unitTarget)
        end

        -- ============================
        -- ==        密謀小徑        ==
        -- ============================
        -- 被買通的守衛（盾擊 / 飛刃）—— 首次施放 16.2 / 10.1s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 被買通的守衛
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 1
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(132357, 13.1, "坦克尖刺", unitTarget)
        end
        -- 巨大的邪能浮龍（召喚浮龍；腐蝕唾液無倒計時條跳過）—— 首次施放 14.6s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 巨大的邪能浮龍
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2433 -- 地圖ID
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == false -- Boss1
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(7301939, 14.6, "召喚小怪", unitTarget)
        end
        -- 腐化的術士（吸取生命 / 厄運詛咒）—— 首次施放 7.1 / 13.4s
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) -- 吸取生命 -- 厄運詛咒（工具）
            and select(8, GetInstanceInfo()) == 2813 -- 副本ID (密謀小徑)
            and (C_Map.GetBestMapForUnit("player") or 0) == 2434 -- 地圖ID
            and IsIndoors() == false -- 在室外
            and UnitLevel(unitTarget) == UnitLevel("player") + 1
            and UnitPowerType(unitTarget) == 0
            and UnitClassification(unitTarget) == "elite" -- 精英怪
            and UnitAffectingCombat(unitTarget) == true -- 在戰斗中
            and not select(2, UnitCreatureFamily(unitTarget)) -- 不是生物家族
            and (C_ScenarioInfo.GetCriteriaInfo(1) and C_ScenarioInfo.GetCriteriaInfo(1).completed or false) == true -- Boss1
            and (C_ScenarioInfo.GetCriteriaInfo(2) and C_ScenarioInfo.GetCriteriaInfo(2).completed or false) == true -- Boss2
        then
            addonTable.UnitTargetTriggered[unitTarget] = true
            addonTable.CustomEncounterBar(136122, 13.4, "厄運詛咒", unitTarget)
            addonTable.CustomEncounterBar(136169, 7.1, "吸取生命", unitTarget)
        end
    end

    CheckThisUnit() -- 立刻查一次（可能已經在戰斗）

    -- 沒進戰斗則每秒輪詢，直到進戰斗觸發 / 單位消失
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
