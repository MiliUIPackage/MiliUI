-- EncounterEvents.lua
local addonName, addonTable = ...
addonTable.EventSoundData = {

    -- 光明众花
    [177] = { {"ZhunBeiCaiQuan.ogg", 1} }, -- 光明之花射线 (1235564)
    [173] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}}, {"WuMiaoHouAOE.ogg", 2} }, -- 基岩猛击 (1234753)
    [174] = { {"DuoKaiChongFeng.ogg", 1} }, -- 播光急奔 (1234850)
    -- [175] = { {"ZhunBeiLiuXue.ogg", 0} }, -- 荆棘之刃 (1235640)
    -- [176] = { {"ZhunBeiLiuXue.ogg", 0} }, -- 荆棘之刃 (1261276)

    -- 圣光猎手伊库兹
    -- [178] = { {"HuDunKuaiDa.ogg", 1}, {"ZhunBeiPoDun.ogg", 2} }, -- 永恒夜幕 (1286918) 枚举1=护盾快打+1秒快开减伤（同响）
    [179] = { {"ZhunBeiAOE.ogg", 1} }, -- 唤棘者咆哮 (1236709)
    [180] = { {"MuBiaoShiNi.ogg", 0} }, -- 嗜血注视 (1237090)
    [178] = { {"XiaoXinJiTui.ogg", 1} }, -- 青翠践踏 (1236746)
    -- [1001] = { {"ShouLingQiangHua.ogg", 0} }, -- 光狂疯乱 (1237073)
    
    -- 护光者鲁伊亚
    [181] = { {"ZhuYiDianMing.ogg", 1}}, -- 光明之火 (1239824) , {"JiHeFangFeng.ogg", 0}
    [182] = { {"WuMiaoZhuYiDuoQuan.ogg", 2} }, -- 光明坠落 (1240098)
    [184] = { {"ZhunBeiLiuXue.ogg", 1}, {"WuMiaoHouLiuXue.ogg", 2, {HEALER = true}} }, -- 凶残痛击 (1241058)
    [188] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 峡谷之灵 (1241067)
    [115] = { {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}} }, -- 撕裂之爪 (1258136)
    [183] = { {"ZhuYiDianMing.ogg", 1} }, -- 粉碎打击 (1240210)

    -- 兹欧凯特
    [192] = { {"ZhunBeiChiQiu.ogg", 1} }, -- 光绽精华 (1246858)
    [191] = { {"MiaoZhunXiaoGuai.ogg", 0} }, -- 凝聚光线 (1246607)
    [189] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 唤醒光绽 (1246372)
    [190] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 棘刺 (1247685)

    -- 凯斯媞亚·魔力之心
    -- [610] = { {"YiShangJieDuan.ogg", 0} }, -- 光明灌注 (1230304)
    [202] = { {"DuoKaiDaQuan.ogg", 1} }, -- 邪能新星 (474240)
    [122] = { {"DuoKaiTouQian.ogg", 1} }, -- 邪能飞溅 (1253811)
    [120] = { {"DaDuanXiaoGuai.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 镜像 (1264095)

    -- 赞恩·刃悲
    [124] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 当日送达 (474765)
    [127] = { {"AOE.ogg", 1}, {"WuMiaoHouAOE.ogg", 2} }, -- 影舞步 (474478)
    [193] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 毒伤 (1222795)
    -- [123] = { {"QuanZhuLvTong.ogg", 0} }, -- 火焰炸弹 (1214357)
    -- [125] = { {"KuaiZhaoYanTi.ogg", 1} }, -- 绝命凶径 (1218347)

    -- 歼灭者萨祖克斯
    [30] = { {"TanKeTouQian.ogg", 1} }, -- 军团打击 (473898)
    -- [31] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 利斧投掷 (1214637)
    [32] = { {"ZhunBeiYiShang.ogg", 1} }, -- 魔化狂怒 (474197)
    [752] = { {"BaMaFenSan.ogg", 1} }, -- 地狱火碾压 (1295452)

    -- 利希尔·烬怒
    [37] = { {"JiHeFenSan.ogg", 1} }, -- 古尔丹之指 (1218203)
    [38] = { {"ZhaoHuanXiaoGuai.ogg", 1} }, -- 召唤邪犬 (474408)
    [207] = { {"ZhunBeiDianMen.ogg", 1} }, -- 灾厄浪潮 (1224478)

    -- 囤宝狂人
    [86] = { {"ZhuYiCaiQuan.ogg", 1} }, -- 腐坏补给 (1234233)
    [87] = { {"DuoKaiTouQian.ogg", 1} }, -- 裂地强击 (1253268)
    [88] = { {"ZhunBeiAOE.ogg", 1} }, -- 贪婪咆哮 (1235118)

    -- 寒冬哨兵
    [67] = { {"QuSanMoFa.ogg", 1, {HEALER = true}}, {"ZhuYiDianMing.ogg", 1, {DAMAGER = true}}, {"WuMiaoHouDianMing.ogg", 2, {DAMAGER = true, HEALER = true}} }, -- 冰川折磨 (1235548) 治疗=驱散 / DPS=注意点名
    [70] = { {"KaoJinZhongChang.ogg", 1} }, -- 寒冰暴雨 (1235656)
    [68] = { {"ZhuYiDuoFeng.ogg", 1} }, -- 狂怒的飑风 (1235623)
    [69] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 粉碎冰刺 (1235783)

    -- 纳洛拉克
    [92] = { {"KuaiZhaoYanTi.ogg", 1} }, -- 压制强攻 (1243569)
    [90] = { {"BaMaFenSan.ogg", 1} }, -- 回响重击 (1242860)
    -- [89] = { {"ZhunBeiJiTui.ogg", 1} }, -- 强力咆哮 (1255385)
    [91] = { {"ZuDangLingHun.ogg", 0} }, -- 战神之怒 (1243011)

    -- 塔兹拉尔
    [39] = { {"TanKeJiTui.ogg", 1, {TANK = true, HEALER = true}} }, -- 虚空冲击 (1222085)
    [558] = { {"SheXianDianNi.ogg", 0} }, -- 空灵冲刺 (1222098)
    [41] = { {"ZhunBeiDuoQiu.ogg", 1} }, -- 黑暗裂缝 (1222274)

    -- 阿特洛苏斯
    [297] = { {"ZhunBeiAOE.ogg", 1} }, -- 巨响咆哮 (1262497)
    [46] = { {"ZhuanHuoDaGuai.ogg", 0} }, -- 激怒蠕行者 (1222371)
    [47] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 巨型爪击 (1222642)
    [54] = { {"DuoKaiTouQian.ogg", 1} }, -- 毒性吐息 (1222721)
    [55] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 毒液喷溅 (1226120)

    -- 煞戎努斯
    [56] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 不稳定的奇点 (1282770)
    [57] = { {"WuMaFenSan.ogg", 1} }, -- 星辰坠击 (1227264)
    [58] = { {"ZhuYiBaoZhu.ogg", 1} }, -- 引力宝珠 (1263982)
    [171] = { {"DuoKaiTouQian.ogg", 1} }, -- 虚空奔涌 (1222758)
    [961] = { {"TanKeTouQian.ogg", 1} }, -- 暗影浪潮 (1311923)

    -- 拉维
    [795] = { {"ZhunBeiPoDun.ogg", 2}, {"HuDunKuaiDa.ogg", 1} }, -- 嘶嘶食腐 (1309522)
    [796] = { {"ZhunBeiAOE.ogg", 1} }, -- 恶臭咆哮 (1296219)
    [797] = { {"ZhunBeiDianMing.ogg", 1, {DAMAGER = true, HEALER = true}}, {"WuMiaoHouDianMing.ogg", 2, {DAMAGER = true, HEALER = true}} }, -- 三重喷吐 (1296220) -- , {"WuMaFenSan.ogg", 0}
    [798] = { {"DuoKaiTouQian.ogg", 1} }, -- 反刍 (1296050)
    [899] = { {"ZhunBeiAOE.ogg", 1} }, -- 贪婪践踏 (1307894)
    -- [902] = { {".ogg", 1} }, -- 进食狂热 (1307765)
    [901] = { {"TanKeDaiWei.ogg", 0, {TANK = true}} }, -- 鲜肉 (1307921)

    -- 扭缠盘蛇
    [813] = { {"ZhunBeiAOE.ogg", 1} }, -- 同步毒液 (1299154)
    [814] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 镰尾 (1298949)
    [815] = { {"DuoKaiChongFengSiDianLiuMiaoDuoKaiTouQian.ogg", 1} }, -- 复仇猛攻 (1299940)
    [816] = { {"ZhunBeiLaXian.ogg", 1} }, -- 濒死喘息 (1299053)
    -- [817] = { {"XiaoGuaiDingNi.ogg", 0} }, -- 怨毒狩猎 (1300503)
    [818] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 同化 (1300686)
    -- [938] = { {"YiDaDuan.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 剧毒弹幕 (1310357)
    [939] = { {"DaDuanXiaoGuai.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 剧毒萎缩 (1310547)

    -- 祖尔加
    [821] = { {"ZhuYiXiaoCeng.ogg", 1} }, -- 切骨者 (1301413)
    [822] = { {"ZhuYiDangXian.ogg", 1} }, -- 毒牙仪式 (1300876)
    [823] = { {"ZhuYiTouQian.ogg", 1} }, -- 碎斧 (1301111)
    [824] = { {"WuMiaoHouTanKeJianCiSanErYi.ogg", 2, {TANK = true, HEALER = true}}, {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 砍倒 (1301350)
    
    -- 梅莉杜莎·寒妆
    [866] = { {"ZhunBeiAOESanMiaoZhuYiJiaoXia.ogg", 1} }, -- 冰雹爆裂 (1307297)
    [867] = { {"ZhuYiDianMing.ogg", 1} }, -- 霜风 (1307308)
    [868] = { {"HuDunKuaiDa.ogg", 1} }, -- 冰霜过载 (373686)
    [869] = { {"ZhaoHuanXiaoGuai.ogg", 0} }, -- 唤醒雏龙 (373046)

    -- 柯姬雅·焰蹄
    [882] = { {"ZhunBeiDaGuai.ogg", 1} }, -- 缚焰仪式 (372864)
    [883] = { {"DuoKaiTouQian.ogg", 1}, {"YinTouQian.ogg", 2}}, -- 熔火巨石 (372110)
    [884] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 灼热打击 (372858)

    -- 基拉卡与厄克哈特·风脉
    [885] = { {"ZhunBeiChenMo.ogg", 1} }, -- 阻断暴雨 (381516)
    [887] = { {"ZhunBeiChuiFeng.ogg", 1} }, -- 变迁之风 (381517)
    [888] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 风暴猛击 (381512)
    [889] = { {"ZhunBeiDianMing.ogg", 1} }, -- 烈焰喷吐 (381602), {"TieBianFangShuiSanMiaoSanErYi.ogg", 0}
    [890] = { {"DuoKaiTouQian.ogg", 1} }, -- 怒吼火息 (381525)
    [894] = { {"ZhunBeiDianMing.ogg", 1} }, -- 烈焰喷吐 (381605), {"TieBianFangShuiSanMiaoSanErYi.ogg", 0}

    -- 阿德里斯和阿斯匹克斯
    [689] = { {"FenTanShangHaiSanErYiDuoKaiDaQuan.ogg", 1} }, -- 电闪雷鸣 (1288049)
    [690] = { {"ShouLingQiangHua.ogg", 1, {TANK = true, HEALER = true}} }, -- 过载 (1311804)
    [691] = { {"ZhunBeiDianMing.ogg", 1} }, -- 暴风 (1311805)
    -- [713] = { {"TieBianFangShui.ogg", 0} }, -- 暴风 (1289754)
    [692] = { {"XiaoXinJiTui.ogg", 1}, {"LingDianWuMiaoSanErYi.ogg", 0} }, -- 狂风之力 (1289059)

    -- 米利克萨
    [701] = { {"ZhuYiDuoBi.ogg", 0} }, -- 钻地 (264172)
    [702] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 缠绕蛇群 (1290029)
    [703] = { {"ZhuYiDianMing.ogg", 1} }, -- 雷霆喷吐 (1289109)
    [704] = { {"ZhunBeiDaGuai.ogg", 1} }, -- 孵化 (1289205)
    [705] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 闪电撕咬 (1290797)
    [706] = { {"XiaoXinJiTuiSanMiaoZhuYiDuoQuan.ogg", 1} }, -- 毒蛇风暴 (1293048)

    -- 加瓦兹特
    [697] = { {"ZhunBeiAOE.ogg", 1}, {"WuMiaoHouAOE.ogg", 2} }, -- 诱导 (1309525)
    [698] = { {"ZhuYiDangXian.ogg", 1} }, -- 闪电尖塔 (1291618)

    -- 塞塔里斯的化身
    [827] = { {"ZhiLiaoBoss.ogg", 1} }, -- 净化 (1301963)
    [828] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 污染之秽 (1301202)

    -- 黄金风蛇
    -- [767] = { {"ZhunBeiDianMing.ogg", 1} }, -- 吐金 (265773)
    [891] = { {"WuMiaoHouTanKeJianCiSanErYi.ogg", 2, {TANK = true}}, {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 甩尾 (265910)
    [892] = { {"ZhunBeiAOE.ogg", 1} }, -- 蛇之风 (1311987)
    [893] = { {"ZhuanHuoXiaoGuai.ogg", 1} }, -- 卢彻的召唤 (265923)

    -- 殓尸者姆沁巴
    [878] = { {"ZhuYiDianMing.ogg", 1} }, -- 燃烧腐蚀 (1311956)
    [879] = { {"ZhunBeiJiuRen.ogg", 1} }, -- 埋葬 (267702)
    [880] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 排干体液 (267618)
    [973] = { {"ZhunBeiAOE.ogg", 1} }, -- 觉醒猛击 (1312146)
    
    -- 部族议会
    [870] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 旋转利斧 (266206)
    [871] = { {"ZhunBeiLiuXue.ogg", 1, {HEALER = true}} }, -- 斩首之斧 (266231)
    [872] = { {"FenTanShangHai.ogg", 0} }, -- 翻滚 (267494)
    [873] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 衰弱抽击 (266237)
    -- [874] = { {"AOE.ogg", 1}, {"WuMiaoHouAOE.ogg", 2} }, -- 电弧 (1305810)
    [875] = { {"DaDuanBoss.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 毒性新星 (267273)
    [876] = { {"ZhuanHuoTuTeng.ogg", 1} }, -- 元素的召唤 (267060)

    -- 始皇达萨
    [831] = { {"MuBiaoShiNi.ogg", 0} }, -- 凌空猛击 (1303115)
    [832] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 剑刃连击 (268586)
    [833] = { {"ZhunBeiAOE.ogg", 1} }, -- 镀金毁灭 (1303267)
    [834] = { {"WuMiaoDuoKaiTouQian.ogg", 2} }, -- 狩猎跃击 (269230)
    [835] = { {"DaDuanDaGuai.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 致命咆哮 (269369)
    [836] = { {"BaMaFenSan.ogg", 0} }, -- 震地之跃 (1303326)
    [837] = { {"TanKeLiuXue.ogg", 1, {TANK = true, HEALER = true}} }, -- 野蛮槌击 (1303481)

    -- 小怪类条目（[474] 翻捡 / [476] 供品上限 / [493] 强风）已移到下方
    -- PersistentEventSoundData「常驻表」：它们不在首领战里触发，需要在登录时
    -- 就登记，并且不能被开怪时的清空清掉。


    -- 通用
    [937] = { {"ShouLingKuangBao.ogg", 1} }, -- 狂暴 (26662)
    -- [668] = { {"ShouLingKuangBao.ogg", 1} }, -- 狂暴 (26662)
    [633] = { {"ShouLingKuangBao.ogg", 1} }, -- 狂暴 (64238)

    -- 毒瀑深渊
    [978] = { {"DuoKaiTouQian.ogg", 1} }, -- 剧毒胆汁 (1291555)
    [979] = { {"QuSanMoFa.ogg", 1, {HEALER = true}} }, -- 虚空毒素 (1293824)
    [980] = { {"TanKeJianCi.ogg", 1, {TANK = true}} }, -- 毒蛇猛击 (1293825)
    [981] = { {"DaDuanBoss.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 灵魂灭绝 (1294963)
    [982] = { {"ZhunBeiDuoBo.ogg", 1} }, -- 毒性风暴 (1309418)
    [983] = { {"DuoKaiTouQian.ogg", 1} }, -- 剧毒胆汁 (1294984)
    [984] = { {"QuSanMoFa.ogg", 1, {HEALER = true}} }, -- 虚空毒素 (1294983)
    [985] = { {"TanKeJianCi.ogg", 1, {TANK = true}} }, -- 毒蛇猛击 (1294982)
    [986] = { {"DaDuanBoss.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 灵魂灭绝 (1294981)
    [987] = { {"ZhunBeiDuoBo.ogg", 1} }, -- 毒性风暴 (1309418)

}

-- ==================================================================
-- 团本首领语音（受控制台“禁用团本语音”开关控制：勾选时整体不注册）
-- 默认所有难度都登记；个别条目要限定难度，见下方 EventSoundDifficultyFilter
-- ==================================================================
addonTable.RaidEventSoundData = {
    -- 盘魂者内克扎莉
    [675] = { {"TieBianFangShui.ogg", 0} }, -- 精华撕裂 (1287426)
    [676] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 盘魂点燃 (1285681)
    -- [693] = { {".ogg", 1} }, -- 交织步 (1293497)
    [695] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 无眠的阿曼尼 (1295397)
    [710] = { {"TanKeTouQian.ogg", 1} }, -- 附身弹幕 (1292036)
    -- [712] = { {".ogg", 1} }, -- 解除盘卷 (1290001)
    -- [731] = { {".ogg", 1} }, -- 紧攫深渊 (1293212)
    [804] = { {"ZhunBeiChenMo.ogg", 1} }, -- 祈求 (1299673)
    [865] = { {"FenTanShangHai.ogg", 1} }, -- 噬灭烈焰 (1305421)
    -- [877] = { {".ogg", 1} }, -- 残余丧钟 (1305993)

    -- 陵寝哨兵
    [637] = { {"ZhunBeiDaGuai.ogg", 1} }, -- 毒液凝块 (1284251)
    [638] = { {"ZhunBeiCaiQuan.ogg", 1, {HEALER = true, DAMAGER = true}} }, -- 剧毒水滴 (1284434)
    [639] = { {"TanKeJianCi.ogg", 1, {TANK = true}} }, -- 强化猛击 (1284458)
    [640] = { {"TanKeJianCi.ogg", 1, {TANK = true}} }, -- 鲜血毒液注射 (1284487)
    [641] = { {"ZhunBeiQuSan.ogg", 1, {HEALER = true}} }, -- 凋零之血 (1284483)
    [643] = { {"HeBingXingZuo.ogg", 0}, {"QuanTuanFenSan.ogg", 2} }, -- 强酸静滞 (1284588)
    [668] = { {"ShouLingKuangBao.ogg", 1} }, -- 狂暴 (26662)
    [673] = { {"FenTanShangHai.ogg", 1} }, -- 不稳定的瘴气 (1288232)
    [788] = { {"ZhuYiFenSan.ogg", 1} }, -- 变幻的原型毒液 (1296878)

    -- 迷失的探险者
    [721] = { {"ZhunBeiAOE.ogg", 0} }, -- 灾变祈求 (1291390)
    -- [722] = { {"DaDuanBoss.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 冰封烈焰 (1286921)
    -- [723] = { {"ZhuYiDianMing.ogg", 1, {HEALER = true, DAMAGER = true}}, {"YiMiaoMuBiaoShiNi.ogg", 0} }, -- 闪现新星 (1296025)
    -- [724] = { {"ZhuYiDianMing.ogg", 1}, {"YiMiaoMuBiaoShiNi.ogg", 0} }, -- 闪现新星 (1290742)
    [725] = { {"FenTanShangHai.ogg", 1} }, -- 巨力重击 (1296092)
    [726] = { {"DuoBiGuiKe.ogg", 1} }, -- 旋壳 (1296061)
    -- [727] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 投掷垃圾 (1291933)
    -- [728] = { {".ogg", 1} }, -- 抛鱼 (1295817)
    [729] = { {"LiuMiaoDuoKaiMoGu.ogg", 1} }, -- 蘑菇投掷 (1292104)
    [768] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 撕裂碎片 (1295854)
    [776] = { {"BaMaFenSan.ogg", 1} }, -- 霜火连射 (1295886)
    [777] = { {"BaMaFenSan.ogg", 1} }, -- 霜火连射 (1295935)
    [781] = { {"WuMiaoHouDianMing.ogg", 2} }, -- 爆炸惊喜 (1297625)
    [783] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 强化晋升 (1292779)  

    -- 万毒邪祟者瓦什尼克
    [754] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 滴毒之牙 (1280935)
    [755] = { {"ZhuYiDianMing.ogg", 1, {HEALER = true}} }, -- 适应性感染 (1282114)
    [756] = { {"ZhunBeiJieQuan.ogg", 1} }, -- 恶性催化剂 (1282509)
    [757] = { {"ZhuYiFenSan.ogg", 1, {HEALER = true, DAMAGER = true}} }, -- 瘟疫泡沫 (1281907)
    [759] = { {"ZhunBeiAOE.ogg", 1} }, -- 痛饮 (1283164)
    -- [770] = { {".ogg", 1} }, -- 冥河感染 (1294994)
    -- [771] = { {".ogg", 1} }, -- 虹吸感染 (1295224)
    -- [772] = { {".ogg", 1} }, -- 爆炸感染 (1295173)
    -- [773] = { {".ogg", 1} }, -- 爆炸感染 (1295174)
    -- [774] = { {".ogg", 1} }, -- 虹吸感染 (1295244)
    -- [775] = { {".ogg", 1} }, -- 冥河喷发 (1295261)

    -- 斯索拉克
    -- [652] = { {"XiaoXinJiFei.ogg", 1} }, -- 狂怒侧风 (1285425)
    [653] = { {"ZhunBeiDianMing.ogg", 1}, {"KuaiZhaoGuangZhu.ogg", 0} }, -- 剧毒涌动 (1305959)
    [664] = { {"TanKeLianJi.ogg", 1} }, -- 顶级掠食者 (1277025)
    [665] = { {"KaoJinZhongChang.ogg", 2}, {"YiShangJieDuan.ogg", 1} }, -- 呼啸旋涡 (1285732)
    -- [851] = { {".ogg", 1} }, -- 腐蚀利爪 (1296310)
    [863] = { {"ShouLingKuangBao.ogg", 0} }, -- 怒不可遏 (1296898)

    -- 双子毒牙
    [711] = { {"TanKeJianCi.ogg", 0, {TANK = true}}, {"ZhuYiDuoQuan.ogg", 1, {HEALER = true, DAMAGER = true}} }, -- 腐蚀洪流 (1289192)
    [739] = { {"TanKeJieQuan.ogg", 1, {TANK = true}} }, -- 碎石击 (1288484)
    [740] = { {"ZhunBeiTuXi.ogg", 1} }, -- 邪恶洪流 (1294293)
    -- [741] = { {".ogg", 1} }, -- 洪流 (1294921)
    -- [742] = { {".ogg", 1} }, -- 搅动深渊 (1290956)
    [743] = { {"ZhunBeiDianMing.ogg", 1} }, -- 盘卷脓液 (1290809)
    [744] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 剧毒涌现 (1291404)
    [751] = { {"FenTanShangHai.ogg", 1}, {"WuMiaoHouFenTanShangHai.ogg", 2} }, -- 贪婪盛宴 (1290516)
    -- [753] = { {".ogg", 0} }, -- 腐蚀唾液 (1291478)
    -- [896] = { {".ogg", 1} }, -- 鲜血洪流 (1303230)
    [897] = { {"SanMiaoZhuYiDuoQuan.ogg", 1} }, -- 血色风暴 (1306872)
    [900] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 唤醒子嗣 (1308356)
    [995] = { {"WuMiaoJieDuanZhuanHuan.ogg", 2} }, -- 下潜 (1308556)

    -- 盘卷祭坛
    [667] = { {"XiaoGuaiDingNi.ogg", 0} }, -- 令人不安的凝视 (1285911)
    [677] = { {"WuMiaoHouAOE.ogg", 2, {HEALER = true}} }, -- 盘卷祭坛之牙 (1282487)
    [678] = { {"FenTanShangHai.ogg", 1}, {"WuMiaoHouFenTanShangHai.ogg", 2}}, -- 处斩 (1283485)
    [679] = { {"ZhunBeiZhongDu.ogg", 1, {HEALER = true}} }, -- 毒牙 (1282281)
    -- [669] = { {".ogg", 1} }, -- 凋零毒素 (1287227)
    [680] = { {"ZhuYiDuoQuan.ogg", 1, {HEALER = true, DAMAGER = true}} }, -- 碎斧 (1283832)
    -- [681] = { {".ogg", 1} }, -- 凋零毒素 (1287200)
    [682] = { {"HuDunKuaiDa.ogg", 1}, {"ZhunBeiPoDun.ogg", 2} }, -- 永恒夜幕 (1286918) 枚举1=护盾快打+1秒快开减伤（同响）
    -- [683] = { {".ogg", 1} }, -- 影牙 (1286308)
    [684] = { {"ZhuYiDianMing.ogg", 1, {HEALER = true, DAMAGER = true}} }, -- 幽暗炸弹 (1310882)  {"PaoKaiRenQun.ogg", 0}, 
    [685] = { {"XinKongDianNi.ogg", 0}, {"ZhunBeiXinKong.ogg", 1}, {"WuMiaoHouXinKong.ogg", 2} }, -- 恐惧行军 (1289900)
    [686] = { {"TanKeTouQian.ogg", 1}, {"WuMiaoHouTanKeJianCiSanErYi.ogg", 2, {TANK = true}} }, -- 灵魂撕裂 (1286573)
    [687] = { {"ZhuanHuoDaGuai.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 精魂狂笑 (1286441)
    [794] = { {"WuMiaoHouAOE.ogg", 2, {HEALER = true}} }, -- 盘卷祭坛亵渎 (1298381)
    [803] = { {"FenTanShangHai.ogg", 1}, {"WuMiaoHouFenTanShangHai.ogg", 2} }, -- 冷酷处斩 (1299266)
    [811] = { {"TanKeTouQian.ogg", 1}, {"WuMiaoHouTanKeJianCiSanErYi.ogg", 2, {TANK = true}} }, -- 撕裂 (1299680)
    [812] = { {"KaiShiYunQiu.ogg", 0, {HEALER = true, DAMAGER = true}} }, -- 剧毒洪流 (1299960)
    [898] = { {"TanKeTouQian.ogg", 1}, {"WuMiaoHouTanKeJianCiSanErYi.ogg", 2, {TANK = true}} }, -- 凋零撕裂 (1307279)

    -- 乌拉特克
    [799] = { {"WeiBaChuXian.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 血腥响尾 (1298559)
    [699] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 蛇母之怒 (1298367)
    [807] = { {"FenTanShangHai.ogg", 1} }, -- 幽魂盘卷 (1300530)
    [912] = { {"DuoKaiDaQuan.ogg", 1}, {"WuMiaoHouAOE.ogg", 2, {HEALER = true}} }, -- 恶臭痛击 (1296301)
    [719] = { {"ZhunBeiDuoBo.ogg", 1} }, -- 腐蚀浪潮 (1292188)
    [825] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 毒蛇呼唤 (1300751)
    [700] = { {"ZhunBeiYiShang.ogg", 1}, {"YiShangJieDuan.ogg", 0} }, -- 被缚之怒 (1286860)
    [800] = { {"ZhunBeiXiQiu.ogg", 1} }, -- 毒蛇之咬 (1295905)
    [826] = { {"ChangDiQieHuan.ogg", 1} }, -- 盘绕猎物 (1301510)
    [810] = { {"ShouLingKuangBao.ogg", 1} }, -- 怒火释放 (1286905)  
    [746] = { {"ShouLingKuangBao.ogg", 1} }, -- 怒火释放 (1286905)
    [806] = { {"TanKeJianCi.ogg", 1, {TANK = true}} }, -- 剧毒孵化 (1299757)
    [949] = { {"ChangDiQieHuan.ogg", 2} }, -- 下潜 (1292999)
    
    -- [830] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 剧毒喷吐 (1302982)

    -- 潮缚石窟
    [366] = { {"ZhuYiXiaoShui.ogg", 1, {TANK = true}} }, -- 水流喷射 (1268562)
    [367] = { {"ZhuanHuoXiaoGuai.ogg", 0} }, -- 诱人水泡 (1257717)
    -- [368] = { {"WuMiaoHouDianMing.ogg", 2} }, -- 冰霜弹幕 (1257608)
    [369] = { {"KuaiZhaoQueKou.ogg", 1} }, -- 激荡漩涡 (1258668)
    [370] = { {"ZhunBeiAOE.ogg", 1} }, -- 深渊之雨 (1260837)
    [745] = { {"ShouLingKuangBao.ogg", 1} }, -- 无尽潮汐 (1294867)
    [976] = { {"ZhuYiDianMing.ogg", 1}, {"WuMiaoHouDianMing.ogg", 2} }, -- 刺骨寒霜 (1313393)
    -- [977] = { {"ZhuanHuoXiaoGuai.ogg", 0} }, -- 诱人水泡 (1257717)
}

-- ==================================================================
-- 常驻事件语音（登录 / 重载时登记一次，且【不参与】开怪时的清空）
-- 适用：非首领战里就会触发的事件（小怪、场景事件等）——它们在开怪之前发生，
--       等不到 ENCOUNTER_START 才登记。
-- 受“开启首领语音警报”总开关控制（不受“禁用团本语音”影响）。
-- ==================================================================
addonTable.PersistentEventSoundData = {
    -- 小怪
    [474] = { {"KongDuanXiaoGuai.ogg", 0} }, -- 翻捡 (1239352)
    [476] = { {"ShouLingJiHuo.ogg", 0} }, -- 获得的供品达到上限 (1283004)
    -- [493] = { {"KuaiZhaoYanTi.ogg", 0} }, -- 强风 (1283107)
}

-- ==================================================================
-- 条目级难度过滤（按 eventID 生效，跟它在哪张表无关）
--   写法：eventID = { [难度ID] = true, ... }
--   不写在这里的条目 = 所有难度都登记（默认行为）
--   难度 ID：团本 14=普通 / 15=英雄 / 16=史诗；5 人本 2=英雄 / 8=史诗(大秘境)
-- ==================================================================
addonTable.EventSoundDifficultyFilter = {
    [804] = { [16] = true }, -- 祈求 (1299673)：仅史诗团本登记
}

local frame = CreateFrame("Frame")

-- 清空声音的函数
function addonTable.ClearTimelineSounds(dataTable)
    if not dataTable then return end
    for eventID, configs in pairs(dataTable) do
        -- 遍历该 ID 下的所有配置
        for _, config in ipairs(configs) do
            local triggerType = config[2]
            C_EncounterEvents.SetEventSound(eventID, triggerType, nil)
        end
    end
end

-- 注册声音的函数
--   配置格式：{ 文件名, 触发类型, 职责过滤? }；条目级难度过滤见 addonTable.EventSoundDifficultyFilter
function addonTable.registerTable(dataTable)
    if not dataTable then return end
    
    -- 获取当前推理出的职责 (TANK / HEALER / DAMAGER)
    local currentRole = addonTable.GetPlayerRole()
    local diffFilter = addonTable.EventSoundDifficultyFilter
    
    for eventID, configs in pairs(dataTable) do
        -- 条目级难度过滤：不在过滤表里 = 所有难度都登记；在表里则只登记列出的难度
        local diffAllowed = true
        local diffCfg = diffFilter and diffFilter[eventID]
        if diffCfg then
            local _, _, difficultyID = GetInstanceInfo()
            diffAllowed = diffCfg[difficultyID] == true
        end

        -- 遍历该 ID 下的所有配置
        for _, config in ipairs(configs) do
            local fileName = config[1]
            local triggerType = config[2]
            local roleConfig = config[3]
            
            local isMatch = false
            
            -- 过滤逻辑
            if roleConfig == nil then
                isMatch = true
            elseif type(roleConfig) == "table" then
                if roleConfig[currentRole] then
                    isMatch = true
                end
            elseif type(roleConfig) == "string" then
                if roleConfig == currentRole then
                    isMatch = true
                end
            end

            -- 执行注册
            if isMatch and fileName and triggerType and diffAllowed then
                C_EncounterEvents.SetEventSound(eventID, triggerType, {
                    -- 路径统一走 GetSoundFullPath：语音包缺这只语音时自动改用本体同名语音
                    file = addonTable.GetSoundFullPath(fileName),
                    channel = DiGuaTimelineAudioHelper.audioChannel,
                    volume = 1
                })
            end
        end
    end
end

-- 清空【场次表】事件音效（非团本表 + 团本表）
-- ⚠️ 不含常驻表 PersistentEventSoundData：那张表登录即登记，每场都要保留，故不参与开怪清空
function addonTable.ClearAllTimelineSounds()
    addonTable.ClearTimelineSounds(addonTable.EventSoundData)
    addonTable.ClearTimelineSounds(addonTable.RaidEventSoundData)
end

-- 登记【常驻表】事件音效（登录 / 重载后调用一次）：
--   非首领战事件（小怪等）；同样只在首领语音警报开启时登记。
function addonTable.RegisterPersistentTimelineSounds()
    addonTable.ClearTimelineSounds(addonTable.PersistentEventSoundData)
    if not (DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.bossVoiceEnabled) then return end
    addonTable.registerTable(addonTable.PersistentEventSoundData)
end

-- 按开关注册【场次表】事件音效（开怪后调用）：
--   前提：首领语音警报已开启（bossVoiceEnabled）；
--   非团本表始终注册；团本表仅当未勾选“禁用团本语音”时注册。
--   两张表默认都是全难度登记，个别条目的难度限制见上方 EventSoundDifficultyFilter。
function addonTable.RegisterAllTimelineSounds()
    if not (DiGuaTimelineAudioHelper and DiGuaTimelineAudioHelper.bossVoiceEnabled) then return end
    addonTable.registerTable(addonTable.EventSoundData)
    if not DiGuaTimelineAudioHelper.raidVoiceDisabled then
        addonTable.registerTable(addonTable.RaidEventSoundData)
    end
end

-- ==================================================================
-- 登记时机：开怪后延迟登记（ENCOUNTER_START + 0.5 秒）
-- ==================================================================
-- 为什么改成开怪登记：
--   1) SetEventSound 没有战斗限制（非 protected、无 secret 前置条件），开怪后登记完全允许；
--   2) 登记是“登记即存储”，开怪瞬间写入，本场后续的高亮/施放/文字警告都来得及；
--   3) 只有 ENCOUNTER_START 之后才拿得到「本场首领 ID / 副本难度」，方便按条件过滤
--      （个别条目的难度限制见上方 EventSoundDifficultyFilter）。
-- ⚠️ 开怪【之前】就可能触发的事件（小怪、场景事件等）不能等开怪，已单独放进
--    下方 PersistentEventSoundData「常驻表」，在 PLAYER_LOGIN 时登记、且不被开怪清空。

local REGISTER_DELAY = 0.5    -- 开怪后等待秒数（留给职责 / 难度 / 首领数据刷新）
local currentEncounterID = 0  -- 本场首领 ID（来自 ENCOUNTER_START）

-- 本场是否登记：返回 false = 本场只清空、不登记任何事件语音。
-- 想加条件（副本难度 / 首领白名单 / 副本类型）都写在这里。
local function ShouldRegisterForEncounter(encounterID)
    -- 注意：这里是【整场】级别开关（返回 false = 非团本表 + 团本表都不登记，本场完全静音）。
    -- 只想限制个别条目（比如某个技能只在史诗难度响）→ 用上面的 EventSoundDifficultyFilter，别改这里。
    -- 示例①：只在团队副本（raid）里登记
    --   local _, instanceType = GetInstanceInfo()
    --   if instanceType ~= "raid" then return false end
    -- 示例②：只在“有语音配置的首领”登记
    --   if not SOUND_ENCOUNTER_IDS[encounterID] then return false end
    return true
end

-- 清空上一场残留 + 按条件登记本场
-- ⚠️ 必须先清空：SetEventSound 登记是持久的，不清掉上一场的登记会继续生效，条件就形同虚设
function addonTable.RegisterTimelineSoundsForEncounter(encounterID)
    addonTable.ClearAllTimelineSounds()
    if not ShouldRegisterForEncounter(encounterID) then return end
    addonTable.RegisterAllTimelineSounds()
end

-- 战斗安全的“重新登记”接口：控台切声道 / 改勾选时调用，让 SetEventSound 立即按最新设置刷新。
-- 说明：SetEventSound 是“登记即存储”，改设置后不再调用，旧声道会一直生效
-- （这正是“未勾选却走环境音”的根因）。
local reloadPending = false
local reloadFrame = CreateFrame("Frame")
reloadFrame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if reloadPending then
        reloadPending = false
        addonTable.ReloadTimelineSounds()
    end
end)

function addonTable.ReloadTimelineSounds()
    if InCombatLockdown() then
        reloadPending = true
        reloadFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    reloadPending = false
    -- 常驻表 + 场次表都按最新设置刷新（常驻表登录即有，不受开怪清空影响）
    addonTable.RegisterPersistentTimelineSounds()
    -- 与开怪登记走同一入口，保证条件过滤不会被绕过
    addonTable.RegisterTimelineSoundsForEncounter(currentEncounterID)
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, encounterID)
    if event == "ENCOUNTER_START" then
        currentEncounterID = encounterID or 0
        -- 开怪 0.5 秒后再登记：此时职责 / 难度 / 首领数据都已就绪
        C_Timer.After(REGISTER_DELAY, function()
            -- 0.5 秒内若已换场或出本，就别再写入了
            if currentEncounterID == (encounterID or 0) then
                addonTable.RegisterTimelineSoundsForEncounter(encounterID)
            end
        end)

    elseif event == "ENCOUNTER_END" then
        currentEncounterID = 0

    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(REGISTER_DELAY, function()
            -- 常驻表：登录 / 重载后立刻登记（小怪等非首领事件在开怪前就可能触发）
            addonTable.RegisterPersistentTimelineSounds()
            -- 兜底：登录时若已身处首领战（战斗中 /reload、插件中途加载），
            -- ENCOUNTER_START 不会再补发，这里补一次场次登记
            if UnitExists("boss1") then
                addonTable.RegisterTimelineSoundsForEncounter(currentEncounterID)
            end
        end)
    end
end)