-- NormalAuraSound.lua
-- 处理普通光环声音注册 (支持获得/移除双向监听)

local addonName, addonTable = ...

-- 本地变量与状态控制
local isNormalAuraRegistered = false
local registeredNormalAuraIDs = {} -- 存储绑定的唯一流水号 ID

-- ==================== 1. 注册普通光环音效 (12.1+ 新API) ====================
-- 注意：这是真正的注册逻辑（调用保护接口），调用方需保证已脱战（见第 3 节安全入口）
local function DoRegisterNormalAuras()
    if isNormalAuraRegistered then return true end
    if not (C_UnitAuras and C_UnitAuras.AddAuraSound) then return true end
    if not addonTable.NormalAura then return true end
    -- 光环音效总开关：DiGua 控制台勾选"关闭光环音效"后，任何入口（登录/切专精/Boss战后补注册）都跳过注册
    if DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.normalAuraSoundEnabled == false then
        return true
    end

    -- 战斗锁定防御：进入本函数后可能刚进战斗，真正注册前再确认一次
    if InCombatLockdown() then return false end

    -- 上次注册若被中途进战斗打断会残留部分流水号；先清掉避免重复注册
    for i = #registeredNormalAuraIDs, 1, -1 do
        pcall(C_UnitAuras.RemoveAuraSound, registeredNormalAuraIDs[i])
        table.remove(registeredNormalAuraIDs, i)
    end

    -- 明确 枚举 -> 配置表 的映射关系
    -- 0: Applied (获得) | 1: Refreshed (刷新) | 2: Removed (移除)
    local triggers = {
        [(Enum.AuraSoundTrigger and Enum.AuraSoundTrigger.Applied) or 0]   = addonTable.NormalAura.appliedList,
        [(Enum.AuraSoundTrigger and Enum.AuraSoundTrigger.Refreshed) or 1] = addonTable.NormalAura.refreshedList,
        [(Enum.AuraSoundTrigger and Enum.AuraSoundTrigger.Removed) or 2]   = addonTable.NormalAura.removedList,
    }

    -- 集合令牌 -> 展开为具体单位列表
    --   nameplate -> nameplate1-40（随机编号姓名板）
    --   party     -> party1-5（队伍成员）
    --   raid      -> raid1-40（团队）
    --   boss      -> boss1-5（首领）
    --   arena     -> arena1-5（竞技场）
    -- 其余单令牌（player / target / focus / mouseover / pet / vehicle / party1 / boss1 等）直接透传
    local expandMap = {
        nameplate = 40,
        party     = 5,
        raid      = 40,
        boss      = 5,
        arena     = 5,
    }
    local function GetUnitTokenList(token)
        local count = expandMap[token]
        if count then
            local tokens = {}
            for i = 1, count do
                tokens[i] = token .. i
            end
            return tokens
        end
        return { token }
    end

    -- 注册单条配置值（可含多个 "|" 分隔的子配置，用于同一 ID 按职责注册不同声音）
    -- 子配置格式："文件名[:单位令牌[:职责]]"
    local function RegisterAuraValue(triggerEnum, spellID, value)
        for subValue in string.gmatch(value, "[^|]+") do
            -- 解析 "文件名:单位令牌:职责"
            local soundFile, unitToken, roleFilter = strsplit(":", subValue)
            if not soundFile or soundFile == "" then soundFile = subValue end
            if not unitToken or unitToken == "" then unitToken = "player" end

            -- 职责过滤：默认不填 = 全职责；支持 "TANK" 或 "TANK,DAMAGER" 多职责
            -- 若职责函数不可用，则视为全职责注册（保持向后兼容）
            local isRoleMatch = true
            if roleFilter and roleFilter ~= "" then
                local getRole = addonTable.GetPlayerRole
                local currentRole = getRole and getRole()
                if currentRole then
                    isRoleMatch = false
                    for role in string.gmatch(roleFilter, "[^,]+") do
                        if role == currentRole then
                            isRoleMatch = true
                            break
                        end
                    end
                end
            end

            if isRoleMatch then
                local soundInfo = {
                    unitToken = unitToken,
                    spellID = tonumber(spellID),
                    -- 使用固定默认路径辅助函数：alarmbeep / JingBao 永远从内置 Media 目录播放
                    soundFileName = addonTable.GetSoundFullPath(soundFile .. ".ogg"),
                    outputChannel = DiGuaTimelineAudioHelper.audioChannel,
                }

                -- 展开集合令牌（nameplate/party/raid/boss/arena），其余单令牌直接透传
                for _, token in ipairs(GetUnitTokenList(unitToken)) do
                    soundInfo.unitToken = token
                    -- 战斗锁定防御：注册可能耗时较长，战斗随时可能开始；
                    -- 锁定中调 AddAuraSound 会触发 ADDON_ACTION_BLOCKED（pcall 挡不住这种 taint），
                    -- 检测到立即中断本函数，交由外层在脱战后补注册
                    if InCombatLockdown() then return true end
                    -- 容错：单个单位无效（不在队伍/没有首领等）不影响其余注册
                    local ok, auraSoundID = pcall(C_UnitAuras.AddAuraSound, triggerEnum, soundInfo)
                    if ok and auraSoundID then
                        table.insert(registeredNormalAuraIDs, auraSoundID)
                    end
                end
            end
        end
    end

    -- 遍历各种触发时机的列表
    -- 配置值格式：
    --   "声音文件"                -> 给 player 注册（默认，向后兼容旧配置），全职责
    --   "声音文件:单位令牌"        -> 给指定单位注册，如 "JingBao:nameplate" = 遍历 nameplate1-40
    --                                 也支持集合令牌：party / raid / boss / arena（自动展开）
    --                                 或单令牌：target / focus / party1 / boss1 / raid5 等（直接透传）
    --   "声音文件:单位令牌:职责"    -> 按玩家职责过滤注册，如 "JingBao:nameplate:TANK"
    --                                 职责支持多个用逗号分隔："TANK,HEALER"；默认不填 = 全职责
    --   "配置1|配置2|..."          -> 同一 ID 按职责注册不同声音，如 "ZhongDu:player:DAMAGER|QuSan:player:HEALER"
    --                                 每个子配置独立做职责过滤，不匹配的子配置不会注册
    -- 记录是否被中途进战斗打断
    local aborted = false
    for triggerEnum, list in pairs(triggers) do
        if list then
            for spellID, value in pairs(list) do
                if value and value ~= "" then
                    if RegisterAuraValue(triggerEnum, spellID, value) then
                        aborted = true
                        break
                    end
                end
            end
        end
        if aborted then break end
    end

    if aborted then
        -- 被打断：保持未完成状态（残留流水号下次注册时先清），交由调用方脱战后补注册
        return false
    end

    isNormalAuraRegistered = true
    return true
end

-- ==================== 4. 光环配置列表 ====================
-- 配置值格式说明：
--   "声音文件"              -> 给 player 注册（默认，旧配置不变），全职责
--   "声音文件:单位令牌"      -> 给指定单位注册，如 "JingBao:nameplate" 会遍历 nameplate1-40
--                               支持的单位令牌：
--                                 集合令牌（自动展开）：
--                                   nameplate -> nameplate1-40
--                                   party     -> party1-5
--                                   raid      -> raid1-40
--                                   boss      -> boss1-5
--                                   arena     -> arena1-5
--                                 单令牌（直接透传）：
--                                   player / target / focus / mouseover / pet / vehicle
--                                   party1-5 / raid1-40 / boss1-5 / arena1-5 等
--   "声音文件:单位令牌:职责"  -> 按玩家职责过滤（TANK / HEALER / DAMAGER）
--                               职责支持多个用逗号分隔，如 "TANK,HEALER"
--                               默认不填职责 = 全职责都响
--   "配置1|配置2|..."        -> 同一技能 ID 按职责注册不同声音
--                               注意：Lua 表里同 ID 重复键会覆盖，必须用 "|" 写在同一行！
--                               例：[1305368] = "ZhongDu:player:DAMAGER|QuSan:player:HEALER"
--                               每个子配置独立做职责过滤，不匹配的不会注册
addonTable.NormalAura = {
    -- 获得光环时播放 (Trigger = Applied)
    appliedList = {
    -- ============================
    -- ==        毒牙祭坛        ==
    -- ============================

        [1294557] = "JiSuJiangDi", -- 刺耳嘶鸣
        [1294569] = "YouBu:player:DAMAGER,TANK|QuSanMoFasmall:player:HEALER|QuSanMoFasmall:party:HEALER", -- 麻痹射击
        [1294845] = "NiBeiYiShang", -- 腐蚀之牙
        [1294934] = "JingBao", -- 剧毒喷雾
        [1294958] = "JingBao", -- 剧毒喷雾
        [1296069] = "YouBu", -- 反刍
        [1297422] = "JingBao", -- 致命剧毒
        [1297876] = "WuMaFenSan", -- 三重喷吐
        -- [1299080] = "LaDuanLianXian", -- 濒死喘息
        [1299189] = "alarmbeep", -- 同步毒液
        -- [1300503] = "XiaoGuaiDingNi", -- 怨毒狩猎
        [1300885] = "alarmbeep", -- 毒牙仪式
        -- [1300894] = "alarmbeep", -- 仪式毒液
        [1301231] = "JingBao", -- 放血
        [1301508] = "KuaiKaiJianShang", -- 切骨者
        [1305368] = "ZhongDu", -- 怨毒毒液
        [1306232] = "JingBao", -- 腐脓飞溅        
        [1306550] = "XiNaiDun", -- 鲜血献祭
        [1306669] = "JingBao", -- 毒素吐息
        [1307531] = "JingBao", -- 放血
        [1307571] = "ZhongDu", -- 毒伤
        -- [1307700] = "alarmbeep", -- 腐肉喷发
        [1307915] = "alarmbeep", -- 贪婪践踏
        [1308518] = "alarmbeep", -- 淬毒之刃
        [1308865] = "JiHeFangQuan", -- 感染
        [1309416] = "JingBao", -- 烈毒旋风
        [1309980] = "ZuZhou", -- 被诅咒
        -- [1310012] = "QuanNengTiGao", -- 变异药剂
        [1310974] = "ShangHaiJiangDi", -- 剧毒萎缩        

    -- ============================
    -- ==     虚空之痕竞技场     ==
    -- ============================

        [458835]  = "JingBao", -- 毒性淤泥
        [1222103] = "KuaiKaiJianShang", -- 空灵冲刺
        [1222484] = "JingBao", -- 毒池
        [1222642] = "alarmbeep", -- 巨型爪击
        [1222692] = "KuaiKaiJianShang", -- 剧毒光环
        [1226031] = "JingBao", -- 毒液喷溅
        [1227247] = "JingBao", -- 虚空奔涌
        [1233398] = "LouDuan", -- 疯狂尖啸
        [1233535] = "TanKeYiShang", -- 撕碎防御
        [1234833] = "JingBao", -- 贪婪之虫
        [1249621] = "YouBu", -- 狂暴之沙        
        [1249712] = "JingBao", -- 毒性喷吐
        [1250023] = "NiBeiQiangHua", -- 受保护
        [1250043] = "QuSanMoFa:party:HEALER|HuJiaJiangDi:player:TANK", -- 熔化护甲（治疗：队里有人中→驱散音；坦克：自己中→护甲降低音）
        [1252406] = "alarmbeep", -- 恐惧咆哮
        [1263971] = "JingBao", -- Mind-Numbing Poison 麻痹毒药?
        [1263983] = "MuBiaoShiNi", -- 凝缩物质
        -- [1264188] = "KaoJinZhongChang", -- 不稳定奇点
        [1267894] = "alarmbeep", -- 野蛮飞跃
        [1282892] = "YuanLiDaGuai", -- 致病撕咬
        [1283506] = "DaGuaiZhuiNi", -- 锁定
        [1287450] = "XiaoGuaiDingNi", -- 凝缩物质
        [1289258] = "ZhongDu", -- 腐蚀精华
        -- [1295123] = "ShuXingJiangDi", -- 衰弱毒液 ???
        [1296967] = "JingBao", -- 虚空裂隙
        [1298899] = "ShangHaiJiangDi", -- 挫志怒吼
        [1298902] = "JingTongTiGao", -- 精通之证
        [1298903] = "QuanNengTiGao", -- 坚韧之证
        [1298917] = "ZhuanHuoXiaoGuai", -- 勇士之矛
        [1298922] = "MuBiaoShiNi", -- 野蛮猛击
        [1298933] = "KuaiKaiJianShang", -- 野蛮猛击
        [1299133] = "alarmbeep", -- 凶猛飞跃
        [1299210] = "JingBao", -- 余震        
        [1299905] = "YiMiaoMuBiaoShiNi", -- 虚无喷发
        [1299913] = "KuaiKaiJianShang", -- 虚无喷发        
        -- [1300138] = "KuaiKaiJianShang", -- 虚空光束
        [1300243] = "KuaiKaiJianShang", -- 残杀
        [1300372] = "alarmbeep", -- 星辰坠击
        [1310026] = "JingBao", -- 灰飞烟灭
        [1310309] = "DaGuaiZhuiNi", -- 钉锤风暴
        [1311730] = "JiSuJiangDi", -- 瓦解宝珠
        [1311778] = "KuaiKaiJianShang", -- Rip and Slice
        
    -- ============================
    -- ==        密谋小径        ==
    -- ============================

        [473898]  = "NiBeiJianLiao", -- 军团打击
        [474234]  = "JingBao", -- 燃烧脚步
        [474515]  = "ZhongDu", -- 断心药膏
        [474545]  = "KuaiZhaoYanTi", -- 绝命凶径
        [474740]  = "KuaiKaiJianShang", -- 绝命凶径
        [1201554] = "NiBeiMeiHuo", -- 诱惑
        [1214352] = "QuanZhuLvTong", -- 火焰炸弹
        [1214637] = "MuBiaoShiNi", -- 利斧投掷
        -- [1214650] = "alarmbeep", -- 魔能闪电
        -- [1214730] = "", -- 恶魔传送门
        -- [1214740] = "", -- 恶魔传送门
        [1215985] = "JingBao", -- 邪能光束
        [1216074] = "JingBao", -- 洒落物区域
        -- [1216076] = "", -- 作呕
        [1216300] = "LiuXue", -- 妙手空空
        [1216529] = "NiBeiYiShang", -- 盾击
        [1216571] = "KuaiKaiJianShang", -- 邪能飞弹
        [1216590] = "ZhongDu:player:TANK|TanKeZhongDu:party:HEALER", -- 断心药膏
        [1216954] = "JingBao", -- 眼棱
        [1217384] = "NiBeiYiShang", -- 灾厄浪潮
        [1217633] = "alarmbeep", -- 腐蚀唾液
        [1217973] = "ZuZhouDianNi", -- 厄运诅咒
        [1218187] = "JiGuangZhuiNi", -- 邪能光束
        [1218465] = "TiGongShiWu", -- 服务员
        [1218466] = "DaSaoDiMian", -- 清洁工
        [1218467] = "HuoDeWeiZhuang", -- 表演者
        [1218468] = "TiZouGuKe", -- 保镖
        [1218508] = "HuoDeWeiZhuang", -- 伪装
        -- [1219631] = "alarmbeep", -- 邪能灌注货物
        [1223553] = "HuoDeZengYi", -- 精美画作
        [1223585] = "NiBeiQiangHua", -- 日光陈酿
        [1223613] = "JiSuTiGao", -- 邪能灌注
        [1224863] = "NiBeiQiangHua", -- 五星好评！
        [1228198] = "alarmbeep", -- 腐蚀唾液
        [1253813] = "JingBao", -- 邪能飞溅
        [1256736] = "ZhunBeiGanHuo", -- 准备干活！
        [1257877] = "DaDuanXiaoGuai", -- 恶意评价
        [1270638] = "HuoDeShuiJing", -- 琢面的邪能结晶
        [1294870] = "JingBao", -- 邪痕大地
        [1295035] = "LiuXue", -- 飞刃
        -- [1295123] = "ShuXingJiangDi", -- 衰弱毒液 ???
        [1295427] = "alarmbeep", -- 剥离
        [1295455] = "alarmbeep", -- 地狱火碾压
        [1297682] = "KuaiKaiJianShang", -- 吸取生命
        [1302010] = "AOE", -- 刃舞
        [1311136] = "LiuXue", -- Sharp Nail

    -- ============================
    -- ==         夺目谷         ==
    -- ============================

        [1234802] = "JingBao", -- 肥沃壤土
        [1235574] = "alarmbeep", -- 光明之花射线
        [1235828] = "JingBao", -- 光灼大地
        [1235865] = "LiuXue", -- 荆棘之刃
        [1236747] = "JiHeFangQuan", -- 青翠践踏
        [1237091] = "KuaiPao", -- 嗜血注视
        [1237267] = "LiuXue", -- 切裂
        [1237858] = "JingBao", -- 破裂大地
        [1238076] = "LiuXue", -- 荆棘之刃
        [1238084] = "alarmbeep", -- 孢子棘刺
        [1238294] = "MiHuo", -- 迷乱尖叫
        -- [1238368] = "WuMaFenSan", -- 光颚射线
        [1239825] = "MuBiaoShiNi", -- 光明之火
        [1239919] = "JingBao", -- 光明之火射线
        [1241058] = "LiuXue", -- 凶残痛击
        [1242135] = "LiuXue", -- 凶残创裂
        [1246751] = "JingBao", -- 凝聚光线
        [1246753] = "JingBao", -- 光明树脂
        [1247052] = "NiBeiQiangHua", -- 光绽之力
        [1247746] = "LiuXue", -- 棘刺
        [1250937] = "ZhongDu", -- 喷毒
        [1251345] = "JingBao", -- 荒芜树脂
        [1257094] = "NiBeiYiShang", -- 粉碎
        [1259365] = "DingShen", -- 血棘之根
        -- [1261276] = "ShiMaFenSan", -- 荆棘之刃
        [1276586] = "KuaiKaiJianShang", -- 基岩涌动
        [1303039] = "alarmbeep", -- 狩猎跃击 (诸王共用)

    -- ============================
    -- ==     纳洛拉克的洞穴     ==
    -- ============================
        
        [1297696] = "LouDuan:target", -- 治疗之风
        -- [1238053] = "JiNu:nameplate", -- 母熊之怒
        -- [1233904] = "AnQuan", -- 受到掩护。
        [1234681] = "KuaiKaiJianShang", -- 贪婪咆哮
        [1234846] = "ZhongDu", -- 剧毒孢子
        [1235125] = "KuaiKaiJianShang", -- 饕餮怒吼
        [1235405] = "JingBao", -- 骨刺扎入
        [1235549] = "alarmbeep", -- 冰川折磨
        [1235829] = "alarmbeep", -- 寒冬帷幕        
        [1235841] = "AnQuan", -- 雪流
        [1236289] = "JingBao", -- 暴风雪之怒
        -- [1238247] = "HuJiaJiangDi", -- 撕裂之爪
        [1238439] = "LiuXue", -- 剃刀俯冲
        [1238687] = "AOE", -- 苦难盛宴
        [1238801] = "ZuZhou", -- 饥肠辘辘
        [1239428] = "HuoDeDaoJu", -- 携带补给品
        [1239860] = "WuMaFenSan", -- 冰寒涌动
        [1240280] = "MeiYouDuoQuan", -- 粉碎
        [1241464] = "DingShen", -- 冰川之墓
        [1242869] = "BaMaFenSan", -- 回响重击
        [1243018] = "HunMi", -- 震荡冲击
        [1243078] = "NiBeiYiShang", -- 战争的重担
        [1243273] = "alarmbeep", -- 战神之怒
        [1246882] = "MuBiaoShiNi", -- 锁定        
        -- [1246957] = "alarmbeep", -- 原始回响
        [1247233] = "YiMiaoTieBianFangShui", -- 地震术
        [1247367] = "JingBao", -- 地震术
        [1252825] = "JingBao", -- 强风
        [1255577] = "KuaiKaiJianShang", -- 幽魂劈砍
        [1261781] = "AnQuan", -- 防御姿态
        [1262253] = "NiBeiYiShang", -- 挫志怒吼
        [1263597] = "MeiYouJieQuan", -- 白霜爆破
        [1266193] = "AnQuan", -- 雪流
        [1271545] = "QuanNengTiGao", -- 守卫熏香
        [1297701] = "JingBao", -- 腐烂地面
        [1297749] = "JingBao", -- 寒冰暴雨
        [1297792] = "ZhunBeiJiFei", -- 压制强攻
        [1297796] = "HunMi", -- 昏迷
        [1297797] = "KuaiKaiJianShang", -- 强力猛击
        [1309919] = "YouBu", -- 冰冷咆哮
        [1309964] = "JingBao", -- 凛冽严冬
        [1311695] = "HuJiaJiangDi", -- Shred Armor

    -- ============================
    -- ==      塞塔里斯神庙      ==
    -- ============================

        -- [263958]  = "JiHeFangXiaoGuai", -- 缠绕的蛇群
        [264206]  = "alarmbeep", -- 钻地
        [266923]  = "alarmbeep", -- 镀流
        [267027]  = "ZhongDu", -- 毒素喷吐
        [272655]  = "alarmbeep", -- 黄沙冲刷
        [273274]  = "JingBao", -- 极化力场
        [1225638] = "HunMi", -- 不羁的火花
        [1263342] = "ChenMo", -- 虚空的代价
        [1288457] = "alarmbeep", -- 阵风
        [1288885] = "ChenMo", -- 暴风
        [1289109] = "YiMiaoMuBiaoShiNi", -- 雷霆喷吐
        -- [1289229] = "", -- 风暴祝福（BOSS）
        [1289588] = "KuaiKaiJianShang", -- 雷霆喷吐
        [1289589] = "JingBao", -- 萦绕风暴
        [1289754] = "TieBianFangShui|[2]321.ogg", -- 暴风
        -- [1290030] = "JiHeFangXiaoGuai", -- 缠绕蛇群
        [1291399] = "LiuXue", -- 锯齿冲锋
        [1291468] = "NiBeiYiShang", -- 破甲猛击
        [1291815] = "JingBao", -- 诱导力场
        -- [1292035] = "", -- 狂乱（BOSS）
        [1293048] = "KuaiKaiJianShang", -- 毒蛇风暴
        [1293133] = "JingBao", -- 萦绕风暴
        [1293307] = "MiHuo", -- 扰乱心智
        [1295635] = "alarmbeep", -- 蜿蜒打击
        [1296052] = "KuaiKaiJianShang", -- 灌能传导
        [1297034] = "JingBao", -- 电击大地
        [1300227] = "DuoKaiDaQuan", -- 钻地之震
        [1300666] = "BaMaFenSan", -- 潜藏妖术
        [1300684] = "JingBao", -- 妖术淤泥
        [1300704] = "alarmbeep", -- 锁定
        [1300714] = "NiBeiJianLiao", -- 暗影鞭笞
        [1300877] = "KuaiKaiJianShang", -- 腐化
        [1302153] = "BaMaFenSan", -- 潜藏妖术
        [1302158] = "KuaiKaiJianShang", -- 烈焰震击
        [1302618] = "KuaiKaiJianShang", -- 邪恶冲锋
        [1302826] = "KuaiKaiJianShang", -- 腐化爆发
        [1303446] = "KuaiKaiJianShang", -- 污秽打击
        [1303486] = "KuaiKaiJianShang", -- 蚀骨践踏
        -- [1303596] = "alarmbeep", -- 能量虹吸
        [1308100] = "alarmbeep", -- 涂毒偷袭
        [1308113] = "alarmbeep", -- 箭雨
        [1308148] = "ZhongDu", -- 细胞毒素
        [1308546] = "KuaiKaiJianShang", -- 毒刃斩击
        -- [1308738] = "", -- 过载（BOSS）
        [1308838] = "KuaiKaiJianShang", -- 闪电撕咬

    -- ============================
    -- ==        诸王之眠        ==
    -- ============================
        [1297763]  = "JiNusmall:nameplate", -- 兽性狂暴
        -- [270016]  = "AOE:nameplate", -- 释放抑制剂
        -- [265773]  = "TieBianFangShui", -- 吐金
        [265914]  = "JingBao", -- 熔化的黄金
        [266191]  = "LiuXue", -- 回旋飞斧
        [266231]  = "LiuXue", -- 斩首之斧
        [266238]  = "NiBeiYiShang", -- 粉碎防御
        [267273]  = "KuaiKaiJianShang", -- 毒性新星    
        -- [267494]  = "FenTanShangHai", -- 翻滚
        [267618]  = "KuaiKaiJianShang", -- 排干体液
        [267626]  = "ShuaManXueLiang:party:HEALER|ShuaManXueLiang:player:HEALER", -- 干枯
        [267702]  = "TeShuAnNiu", -- 埋葬
        [267763]  = "KuaiKaiJianShang", -- 恶疾排放
        [267874]  = "JingBao", -- 燃烧之地
        [269936]  = "XiaoGuaiDingNi", -- 锁定
        [269972]  = "KuaiKaiJianShang", -- 妖术齐射
        [270003]  = "HunMi", -- 压制猛击
        [270292]  = "JingBao", -- 净化烈焰
        [270492]  = "ZuZhouDianNi", -- 妖术
        [270499]  = "YouBu", -- 冰霜震击
        [270927]  = "YiMiaoMuBiaoShiNi", -- 剑刃风暴
        [270931]  = "JingBao", -- 暗影箭雨
        [271555]  = "TeShuAnNiu", -- 埋葬
        [271564]  = "ZhongDu", -- 残留液体
        [272021]  = "NiBeiYiShang", -- 喷涌黑暗
        -- [272388]  = "alarmbeep", -- 暗影弹幕
        [274387]  = "alarmbeep", -- 黑暗吸收        
        [276031]  = "KongJu", -- 绝望深渊
        [1255856] = "JingTongJiangDi", -- 烬翼灼烧
        [1255857] = "JingTongJiangDi", -- 烬翼灼烧
        [1294815] = "YouBu", -- 暗影冰霜箭
        [1297781] = "LiuXue", -- 骤裂
        [1297918] = "LiuXue", -- 致死流血
        [1298104] = "ZhongDu", -- 腐烂搜寻者
        [1298304] = "ShiMaFenSan", -- 黑暗启示
        [1301851] = "LiuXue", -- 嗜血飞斧
        [1302028] = "HuJiaJiangDi", -- 灵魂碾压
        [1302945] = "JingBao", -- 穿刺之矛
        -- [1303039] = "alarmbeep", -- 狩猎跃击 (夺目共用)
        [1303267] = "KuaiKaiJianShang", -- 镀金毁灭
        [1303399] = "JingBao", -- 液态黄金
        [1303490] = "LiuXue", -- 野蛮槌击
        [1306736] = "TieBianFangShui", -- 吐金
        [1306763] = "ZhongDu", -- 毒蛇打击
        [1311956] = "YiMiaoTieBianFangShui", -- 燃烧腐蚀
        [1312569] = "KuaiKaiJianShang", -- 防腐
        
    -- ============================
    -- ==      红玉新生法地      ==
    -- ============================
    
        [373972]  = "DuoQuan:nameplate", -- 荣耀烈焰
        [372047]  = "alarmbeep", -- 钢铁弹幕
        [372820]  = "JingBao", -- 焦灼之土（BOSS）/小怪 ???
        [372858]  = "KuaiKaiJianShang", -- 灼热打击
        [372860]  = "KuaiKaiJianShang", -- 灼热伤口
        [372865]  = "YiMiaoMuBiaoShiNi", -- 缚焰仪式
        [372963]  = "JingBao", -- 风暴之眼
        [373593]  = "CengShuGuoGao", -- 冻结     
        -- [373688]  = "HuDunKuaiDa", -- 冰霜过载
        [373693]  = "KuaiKaiJianShang", -- 活动炸弹
        [381515]  = "NiBeiYiShang:player:TANK|QuSanTanKe:party:HEALER", -- 风暴猛击
        -- [381518]  = "JingBao", -- 变迁之风
        [381526]  = "JingBao", -- 怒吼火息
        [381862]  = "TieBianFangShui", -- 烈焰喷吐
        [384024]  = "JiSuJiangDi", -- 冰雹炸弹
        [384773]  = "JingBao", -- 烈焰余烬
        [384823]  = "alarmbeep", -- 地狱烈火
        -- [385518]  = "TieBianFangShui", -- 霜风（点名）
        [385536]  = "KuaiKaiJianShang", -- 燃焰弹幕
        [392641]  = "KuaiKaiJianShang", -- 滚雷
        [395292]  = "alarmbeep", -- 火焰之喉
        -- [397077]  = "", -- 霜风（吸）
        [1305201] = "alarmbeep", -- 采掘冲击
        [1305225] = "NiBeiYiShang", -- 地壳震击
        [1305234] = "alarmbeep", -- 冰寒利爪
        -- [1306366] = "KuaiKaiJianShang", -- 闪电涌流
        [1307205] = "GeRenJianShang:player:DAMAGER,HEALER|alarmbeep:player:TANK", -- 地缚印记
        [1307372] = "JingBao", -- 炽烈灭亡
        [1310361] = "alarmbeep", -- 暴风骤雨之盾
        [1310599] = "KuaiKaiJianShang", -- 电荷释能

    -- ============================
    -- ==      盘魂者内克扎莉    ==
    -- ============================
        [1285623] = "JingBao", -- 盘魂之井
        [1287434] = "TieBianQuSan", -- 精华撕裂
        [1288554] = "JingBao", -- 潜藏的教徒
        -- [1284103] = "", -- 附身弹幕
        [1307939] = "alarmbeep", -- 残骸凋零
        [1293214] = "KaiShiLaRen", -- 紧攫深渊
        -- [1300235] = "", -- 灵魂疲惫
        -- [1299988] = "", -- 不朽缠绕
        [1300239] = "alarmbeep", -- 盘旋精魂
        [1294933] = "QuanZhuShiTi", -- 蛇行烈焰
        -- [1284109] = "", -- 摄魂打击
        -- [1288772] = "", -- 盘魂仪式
        -- [1297624] = "", -- 仪式灼烧
        [1292751] = "ZhunBeiNeiChang", -- 盘魂

    -- ============================
    -- ==        陵寝哨兵        ==
    -- ============================

        -- [1284590] = "", -- 螺旋毒素
        [1284947] = "KuaiKaiJianShang", -- 培育爆裂
        [1284491] = "alarmbeep", -- 鲜血毒液注射
        [1288260] = "YiMiaoMuBiaoShiNi", -- 不稳定的瘴气
        [1288297] = "TieBianFangShui|[3]321", -- 附着幽暗
        [1284471] = "alarmbeep", -- 凋零之血
        [1284210] = "JingBao", -- 鲜血毒液
        
    -- ============================
    -- ==       迷失的探险者      ==
    -- ============================
        
        [1296025] = "YuanLiRenQun|[4]321", -- 闪现新星
        -- [1291929] = "", -- 稳固打击
        [1291918] = "alarmbeep", -- 旋壳
        [1286922] = "KuaiKaiJianShang", -- 冰封烈焰
        -- [1295858] = "alarmbeep", -- 撕裂碎片
        [1295954] = "CaiHuoXiaoCeng", -- 穿刺冰霜
        [1295928] = "CaiBingXiaoCeng", -- 燃烧烈焰
        [1308853] = "LiuXue", -- 木刺炸裂
        [1297625] = "ZhaDanDianNi|[7]321", -- 爆炸惊喜
        [1299854] = "MarioJump", -- 弹射
        [1297648] = "JingBao", -- 冰霜区域
        [1297649] = "JingBao", -- 火焰区域        
        [1297650] = "JingBao", -- 延烧之火
        [1310500] = "JingBao", -- 余震
        [1296092] = "YiMiaoMuBiaoShiNi", -- 巨力重击
        
    -- ============================
    -- ==   万毒邪祟者瓦什尼克    ==
    -- ============================

        -- [1282114] = "", -- 适应性感染
        [1280935] = "NiBeiYiShang", -- 滴毒之牙
        -- [1282509] = "", -- 恶性催化剂
        [1281913] = "[3]321.ogg", -- 瘟疫泡沫
        [1294994] = "ZhuYiJiaoXia", -- 冥河感染
        [1295224] = "KaoJinDuiYou", -- 虹吸感染
        [1295380] = "alarmbeep", -- 虹吸感染
        [1295173] = "YiMiaoKuaiKaiJianShang", -- 爆炸感染
        -- [1302489] = "", -- 冥河爆发
        -- [1283164] = "", -- 痛饮
        [1291461] = "JingBao", -- 剧毒烟雾
        
    -- ============================
    -- ==       斯索拉克         ==
    -- ============================

        [1297707] = "WuMaFenSan", -- 剧毒
        [1299899] = "WuMaFenSan", -- 剧毒
        [1277051] = "alarmbeep", -- 残毁创伤
        [1285425] = "XiaoXinJiFei|[5]321.ogg", -- 狂怒侧风
        [1285453] = "XiaoXinJiFei|[5]321.ogg", -- 狂怒侧风        
        [1305963] = "[7]321.ogg", -- 剧毒涌动
        -- [1305959] = "[7]321.ogg", -- 剧毒涌动
        [1296667] = "JingBao", -- 腐蚀残渣
        [1287205] = "alarmbeep", -- 粘稠囊肿
        [1287083] = "ZhongDu", -- 风暴
        [1305621] = "MuBiaoShiNi", -- 毒蛇之怒

    -- ============================
    -- ==       双子毒牙         ==
    -- ============================

        [1289192] = "KuaiKaiJianShang", -- 腐蚀洪流
        [1288484] = "alarmbeep", -- 碎石击
        [1294293] = "JingBao", -- 邪恶洪流
        [1294921] = "JingBao", -- 洪流
        [1292807] = "JingBao", -- 搅动深渊
        [1290809] = "TieBianFangShui", -- 盘卷脓液
        [1290814] = "TieBianFangShui", -- 盘卷脓液        
        -- [1291404] = "", -- 剧毒涌现
        -- [1290516] = "", -- 贪婪盛宴
        -- [1303230] = "", -- 鲜血洪流
        -- [1306872] = "", -- 血色风暴
        -- [1308356] = "", -- 唤醒子嗣
        [1310096] = "alarmbeep", -- 饱餐
        [1309471] = "JingBao", -- 剧毒粘液
        [1293979] = "SheXianDianNi", -- 腐蚀唾液
        [1291478] = "SheXianDianNi", -- 腐蚀唾液
        [1292552] = "JingBao", -- 凝结的鲜血
        [1306925] = "JingBao", -- 凝结的鲜血

    -- ============================
    -- ==       盘卷祭坛         ==
    -- ============================

        [1285911] = "XiaoGuaiDingNi", -- 令人不安的凝视
        [1286399] = "LouDuan", -- 恐惧哀嚎
        [1285017] = "JingBao", -- 碎斧
        [1283290] = "JingBao", -- 剧毒之地
        [1286837] = "ZhuYiChiHun", -- 墓缚
        [1307425] = "KuaiPao", -- 处斩
        [1283485] = "YiMiaoMuBiaoShiNi", -- 处斩
        [1310881] = "PaoKaiRenQun", -- 幽暗炸弹
        [1286901] = "PaoKaiRenQun", -- 幽暗炸弹
        [1297445] = "NiBeiMeiHuo", -- 恐惧行军
        [1310744] = "alarmbeep", -- 恶毒共鸣
        [1301690] = "alarmbeep", -- 撕裂
        [1299838] = "alarmbeep", -- 毒液爆裂
        [1306906] = "ZhongDu", -- 毒牙
        [1282419] = "alarmbeep|WuSiSanErYi", -- 烈性毒液
        [1310498] = "alarmbeep|WuSiSanErYi", -- 诱变毒液
        [1286912] = "YiMiaoKuaiKaiJianShang:nameplate", -- 暮光之帷

        

    -- ============================
    -- ==       乌拉特克         ==
    -- ============================

        [1311600] = "alarmbeep", -- 凋萎静脉
        [1300312] = "alarmbeep", -- 厄鳞外壳
        -- [1306858] = "", -- 守卫的保护
        [1298417] = "alarmbeep", -- 岩石剧毒
        [1295360] = "alarmbeep", -- 恶性甲壳
        -- [1313529] = "", -- 摄入毒液
        [1311611] = "LianXianDianNi", -- 攫取毒牙
        [1312967] = "WuMaFenSan", -- 易爆清除
        -- [1300938] = "", -- 步履维艰
        [1288879] = "YiMiaoMuBiaoShiNi", -- 毒蛇之咬
        [1292403] = "JingBao", -- 腐蚀浪潮
        [1297338] = "JingBao", -- 致命剧毒
        [1298367] = "alarmbeep", -- 蛇母之怒
        [1306119] = "HunMi", -- 钙化尸骸
        [1296301] = "alarmbeep", -- 恶臭痛击
        [1295995] = "JingBao", -- 毒素云
        [1305709] = "alarmbeep", -- 绝望鞭笞

    -- ============================
    -- ==       潮缚石窟         ==
    -- ============================

        [1268562] = "ZhuYiXiaoShui", -- 水流喷射
        -- [1282937] = "", -- 冰刃乱舞
        [1313393] = "ZhuYiJiaoXia", -- 刺骨寒霜        
        [1257608] = "TieBianFangShui", -- 冰霜弹幕
        [1258668] = "JingBao", -- 激荡漩涡
        -- [1260837] = "", -- 深渊之雨
        -- [1260843] = "", -- 深渊之雨
        -- [1307352] = "", -- 浸透
        [1281393] = "alarmbeep", -- 漂浮水珠
        [1282537] = "alarmbeep", -- 漂浮水珠
        [1257644] = "ZhuYiJiaoXia", -- 冰霜弹幕
        [1257654] = "JingBao", -- 残留冰霜
        [1258154] = "alarmbeep", -- 嘭！
        [1266340] = "alarmbeep", -- 嘭！
        -- [1271380] = "", -- 脉动潮汐
        [1258677] = "JingBao", -- 激荡漩涡
        [1271458] = "ZhuYiXiaoShui", -- 水流喷射
        [1281341] = "JingBao", -- 野性撕咬

    -- ============================
    -- ==       毒瀑深渊         ==
    -- ============================

        [1298887] = "JingBao", -- 剧毒毒液

    -- ============================
    -- ==       通用             ==
    -- ============================

        [204018] = "PoZhouZhuFu", -- 破咒祝福
        -- [29166] = "NiBeiJiHuo", -- 激活
        [406789] = "YiDongShiFa", -- 空间悖论
        -- [8936] = "alarmbeep|TieBianFangShui", -- 愈合(测试)（同ID用"|"写一行，两个声音一起响）
    },

    -- 1: 光环刷新/叠层时 (可选)
    refreshedList = {
        -- [1238053] = "JiNuDieJia:nameplate:TANK", -- 母熊之怒
        [1311730] = "alarmbeep", -- 瓦解宝珠
        [1282892] = "alarmbeep", -- 致病撕咬
        [1238801] = "alarmbeep", -- 饥肠辘辘
        [272021]  = "alarmbeep", -- 喷涌黑暗
        [1219631] = "alarmbeep", -- 邪能灌注货物
        -- [1307700] = "alarmbeep", -- 腐肉喷发
        -- [1294845] = "NiBeiYiShang_Refresh",
    },

    -- 2: 移除/消退光环时
    removedList = {
        [1310309] = "AnQuan", -- 钉锤风暴
        [270927]  = "AnQuan", -- 剑刃风暴
        [1286837] = "AnQuan", -- 墓缚
        -- [1305225] = "yishangjieshu", -- 地壳震击
        -- [1294569] = "AnQuan", -- 麻痹射击
        -- 通用
        [204018] = "PoZhouJieShu", -- 破咒祝福        
        [1281910] = "ZhuYiDuoBo", -- 瘟疫泡沫
        [1281913] = "ZhuYiDuoBo", -- 瘟疫泡沫
        [1295954] = "AnQuan", -- 穿刺冰霜
        [1295928] = "AnQuan", -- 燃烧烈焰
    },    

}

-- ==================== 2. 注销普通光环音效 ====================
local function DoUnregisterNormalAuras()
    if not isNormalAuraRegistered then return true end
    if not (C_UnitAuras and C_UnitAuras.RemoveAuraSound) then return true end

    -- 倒序解绑所有已注册的流水号
    for i = #registeredNormalAuraIDs, 1, -1 do
        local auraSoundID = registeredNormalAuraIDs[i]
        -- 战斗锁定防御：锁定中 RemoveAuraSound 同样被拦截；中断留待脱战续清
        if InCombatLockdown() then return false end
        pcall(C_UnitAuras.RemoveAuraSound, auraSoundID)
        table.remove(registeredNormalAuraIDs, i)
    end

    isNormalAuraRegistered = false
    return true
end

-- ==================== 3. 战斗锁定防御 + 安全入口 ====================
-- 保护接口（AddAuraSound / RemoveAuraSound）在战斗锁定期间调用会触发
-- ADDON_ACTION_BLOCKED（典型场景：快速进出首领战刷坐骑，战斗中延迟回调去注册）。
-- 统一入口：若处于战斗锁定，先挂 PLAYER_REGEN_ENABLED，脱战后补执行。

local pendingNormalAuraAction = nil   -- nil | "register" | "unregister" | "reload"

-- 前向声明（RegenFrame 与 ExecuteNormalAuraAction 相互引用）
local RegenFrame
local ExecuteNormalAuraAction

RegenFrame = CreateFrame("Frame")
RegenFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local action = pendingNormalAuraAction
    pendingNormalAuraAction = nil
    if action then
        ExecuteNormalAuraAction(action)
    end
end)

-- 统一执行动作：若中途进战斗被打断（返回 false），自动挂 PLAYER_REGEN_ENABLED 脱战后重试
ExecuteNormalAuraAction = function(action)
    if action == "register" then
        if not DoRegisterNormalAuras() then
            pendingNormalAuraAction = "register"
            RegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    elseif action == "unregister" then
        if not DoUnregisterNormalAuras() then
            pendingNormalAuraAction = "unregister"
            RegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    elseif action == "reload" then
        if not DoUnregisterNormalAuras() then
            pendingNormalAuraAction = "reload"
            RegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        elseif not DoRegisterNormalAuras() then
            pendingNormalAuraAction = "register"
            RegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    end
end

-- 尝试立即执行；若在战斗锁定中则等脱战再执行
local function RunNormalAuraAction(action)
    if InCombatLockdown() then
        pendingNormalAuraAction = action
        RegenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    ExecuteNormalAuraAction(action)
end

-- 导出函数（全部走战斗安全入口）
addonTable.RegisterNormalAuras   = function() RunNormalAuraAction("register") end
addonTable.UnregisterNormalAuras = function() RunNormalAuraAction("unregister") end
addonTable.ReloadNormalAuras     = function() RunNormalAuraAction("reload") end


-- ==================== 5. 事件监听与自启动 ====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local versionStr = GetBuildInfo()
        local major, minor = strsplit(".", versionStr)
        major, minor = tonumber(major) or 0, tonumber(minor) or 0

        if major > 12 or (major == 12 and minor >= 1) then
            -- 使用战斗安全入口：若处于战斗锁定会自动等脱战后注册
            C_Timer.After(0.5, function()
                RunNormalAuraAction("register")
            end)
        end

        self:UnregisterEvent("PLAYER_LOGIN")

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- 专精/职责变化：延迟 1 秒后按新职责重新注册（战斗锁定会自动等脱战）
        C_Timer.After(1, function()
            RunNormalAuraAction("reload")
        end)

    -- PLAYER_REGEN_ENABLED 已由第 3 节的 RegenFrame 统一处理，这里不再单独监听
    end
end)
