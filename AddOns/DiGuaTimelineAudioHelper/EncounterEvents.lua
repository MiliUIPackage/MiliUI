-- EncounterEvents.lua
local addonName, addonTable = ...
addonTable.EventSoundData = {
    -- 熔炉之主加弗斯特
    [147] = { {"KuaiZhaoYanTi.ogg", 1} }, -- 冰川过载
    -- 阿拉卡纳斯
    [302] = { {"ZhuYiTouQian.ogg", 1, {TANK = true}} }, -- 灼热重击
    [303] = { {"XiaoGuaiJiHuo.ogg", 1} }, -- 充能
    [304] = { {"ZhunBeiAOE.ogg", 1} }, -- 超级新星
    -- 鲁克兰
    [603] = { {"XiaoGuaiFuHuo.ogg", 0} }, -- 荣耀烈焰 (1283787)
    -- 高阶贤者维里克斯
    -- [309] = { {".ogg", 1} }, -- 灼烧射线 (1253538)
    [310] = { {"ZhunBeiJiuRen.ogg", 1} }, -- 扔下 (1253998)
    -- [311] = { {".ogg", 1} }, -- 日光冲击 (154396)
    -- [312] = { {".ogg", 1} }, -- 眩光 (1253840)
    
    -- 学院
    -- 茂林古树
    [282] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 裂树击 (388544)
    [283] = { {"ZhunBeiDaGuaiErDianWuMiaoZhuanHuoDaGuai.ogg", 1, {TANK = true, DAMAGER = true}} }, -- 分枝 (388567)
    [284] = { {"ZhuYiJiaoXia.ogg", 1} }, -- 发芽 (388796)
    [285] = { {"ZhunBeiAOE.ogg", 1} }, -- 爆发苏醒 (388923)
    -- [293] = { {".ogg", 1} }, -- 奥术飞弹 (373325)
    -- [294] = { {".ogg", 1} }, -- 星界冲击 (1282251)
    [295] = { {"TieBianFangShui.ogg", 0} }, -- 能量炸弹 (374341)
    -- [296] = { {".ogg", 1} }, -- 力量真空 (388820)
    
    -- 晋升者祖拉尔
    [223] = { {"DuoKaiZhengMian.ogg", 1} }, -- 虚空之掌 (1268916)
    [224] = { {"ZhunBeiTiaoRen.ogg", 1} }, -- 残杀 (1263282)
    [225] = { {"ZhunBeiAOE.ogg", 1} }, -- 渗漏猛击 (1263399)
    [226] = { {"WuMiaoHouTanKeJianCiSanErYi.ogg", 2, {TANK = true, HEALER = true}}, {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 虚空挥砍 (1263440)
    -- [238] = { {"XiaoXinJiTui.ogg", 1} }, -- 崩解虚空 (1263304)
    
    -- 萨普瑞什
    [234] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 虚空炸弹 (247175)
    -- [235] = { {".ogg", 1} }, -- 相位冲锋 (1263509)
    [236] = { {"DaDuanDuTiao.ogg", 0, {DAMAGER = true, TANK = true}} }, -- 恐惧尖啸 (248831)
    [237] = { {"DanShuaLiuXue.ogg", 1, {HEALER = true}}, {"ZhunBeiLiuXueSanErYi.ogg", 2, {DAMAGER = true, HEALER = true}} }, -- 暗影突袭 (245738)
    -- [243] = { {".ogg", 1} }, -- 过载 (1263523)
    
    -- 总督奈扎尔
    [244] = { {"DaDuanDuTiao.ogg", 1, {DAMAGER = true, TANK = true}} }, -- 心灵震爆 (244750)
    [246] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 暗影触须 (1263538)
    
    -- 鲁拉    
    [249] = { {"ZhunBeiAOE.ogg", 1} }, -- 绝望哀歌    
    [250] = { {"ZhunBeiDianMingLiangMiaoSanErYi.ogg", 2} }, -- 不谐射线
    [251] = { {"ZhuYiSheXian.ogg", 1} }, -- 裂解
    [252] = { {"DuoKaiDaQuan.ogg", 1} }, -- 幽冥和音
    [253] = { {"ZhunBeiYiShangShiMiaoYiShangJieDuan.ogg", 1} }, -- 永夜交响曲
    [254] = { {"ZhunBeiJiTuiLiangMiaoSanErYi.ogg", 2} }, -- 反冲    
    -- [247] = { {".ogg", 1} }, -- 驱逐 (1263528)
    -- [376] = { {"ZhunBeiDuoQiuSiMiaoZhuYiDuoQiu.ogg", 1} }, -- 深渊之门 (1277358)
    [245] = { {"ZhuYiDanShua.ogg", 1, {HEALER = true}} }, -- 群体虚空灌输 (1263542)
    
    -- 烬晓
    [239] = { {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}} }, -- 炽热尖喙
    [241] = { {"ZhunBeiDianMing.ogg", 1}, {"TieBianFangShuiSanMiaoSanErYi.ogg", 0} }, -- 炽焰腾流 (包含原表2)
    [242] = { {"WuMiaoZhunBeiChuiFengSanMiaoNiShiZhenTouQian.ogg", 2} }, -- 燃烧烈风          
    
    -- 被遗弃的二人组
    [25]  = { {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}} }, -- 碎骨猛砍  
    [26]  = { {"GuiHunDianNiSanErYi.ogg", 0}, {"ZhunBeiZuZhouLiangMiao.ogg", 2} }, -- 黑暗诅咒 (包含原表2)
    [27]  = { {"ZhunBeiDianMing.ogg", 2} }, -- 衰弱尖啸         
    
    -- 指挥官克罗鲁科
    [210] = { {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}} }, -- 暴怒
    [211] = { {"ZiQuanChongHeLiangMiaoSanErYi.ogg", 1} }, -- 破胆怒吼
    [212] = { {"SanMiaoZhuYiDuoQuan.ogg", 1} }, -- 无情跳跃
    -- [213] = { {"ZiQuanChongHeLiangMiaoSanErYi.ogg", 1} }, -- 破胆怒吼
    [214] = { {"SanMiaoZhuYiDuoQuan.ogg", 1} }, -- 无情跳跃
    [215] = { {"ZhunBeiAOE.ogg", 0} }, -- 集结怒吼
    
    -- 无眠之心
    [21]  = { {"ZhunBeiAOELiangMiaoSanErYi.ogg", 2} }, -- 疾风狙击
    [22]  = { {"ZhunBeiJianYu.ogg", 2} }, -- 飞矢烈风
    [23]  = { {"ZhuYiDuoQuanWuMiaoCaiQuanXiaoCeng.ogg", 1} }, -- 矢如雨下
    [24]  = { {"TanKeJiTui.ogg", 1, {TANK = true, HEALER = true}} }, -- 暴风斩    
    
    -- 核技工程长卡斯雷瑟   
    [108] = { {"ZhuYiSheXian.ogg", 1} }, -- 魔网阵列 (1251183)
    -- [106] = { {".ogg", 1} }, -- 核闪引爆 (1257512)
    -- [107] = { {"JiaoChaDianXiaoLianXian.ogg", 0} }, -- 回流充能 (1251767)
    [172] = { {"ZhuYiJiaoXia.ogg", 1} }, -- 能量坍缩 (1264048)
    
    -- 核心守卫奈萨拉 
    [36]  = { {"ZhunBeiXiaoGuaiLiuMiaoXiaoGuaiJiHuo.ogg", 1} }, -- 空无先锋
    [35]  = { {"WuMiaoHouTanKeJianCi.ogg", 2, {TANK = true, HEALER = true}}, {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 幽影鞭笞   
    [34]  = { {"ZhunBeiYiShangJiuMiaoKuaiJinShengGuang.ogg", 0} }, -- 光痕耀斑
    -- [33]  = { {"ZhunBeiDianMing.ogg", 2} }, -- 蚀光步伐    
    
    -- 洛萨克森
    [109] = { {"BaMaFenSanSiMiaoZhuYiDuoQuan.ogg", 1} }, -- 辉熠消散
    [110] = { {"ZhunBeiJiTuiSiDianWuMiaoSanErYiDaDuanGuangTou.ogg", 1} }, -- 神圣诡计
    [111] = { {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}} }, -- 灼热撕裂
    [112] = { {"DuoKaiChongFeng.ogg", 1} }, -- 闪烁   

    -- 姆罗金和内克拉克斯
    [150] = { {"TanKeLiuXue.ogg", 1, {TANK = true, HEALER = true}} }, -- 长矛侧攻
    [151] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 恶臭羽毛风暴
    [152] = { {"DuoKaiXianJing.ogg", 1} }, -- 冰冻陷阱
    [153] = { {"ZhunBeiJianYu.ogg", 2} }, -- 弹幕射击    
    [154] = { {"ZhunBeiJiBing.ogg", 1}, {"WuMiaoHouAOE.ogg", 2} }, -- 感染羽翼 (包含原表2)
    [155] = { {"ZhunBeiDianMing.ogg", 2} }, -- 腐肉飞扑
    
    -- 沃达扎    
    [16]  = { {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}} }, -- 吸取灵魂
    [17]  = { {"DuoKaiTouQian.ogg", 1} }, -- 寂灭
    [19]  = { {"ZhunBeiDianMing.ogg", 1} }, -- 束缚幻影
    [20]  = { {"WuMiaoZhunBeiPoDunSanMiaoKuaiKaiJianShangShiErMiaoZhuYiDuoQiu.ogg", 2} }, -- 死疽融合

    -- 魔导师平台
    -- 奥能金刚库斯托斯
    -- [281] = { {".ogg", 1} }, -- 补给协议 (474345)
    -- [286] = { {".ogg", 1} }, -- 震退猛击 (474496)
    -- [287] = { {".ogg", 1} }, -- 虚灵枷锁 (1214032)
    [288] = { {"XiaoXinJiTui.ogg", 1} }, -- 奥术驱除 (1214081)    
    -- 瑟拉奈尔·日鞭
    [94]  = { {"ShouLingQiangHua.ogg", 1} }, -- 加速结界
    [96]  = { {"ZhunBeiJinZhaoZiSanErYiJin.ogg", 1} }, -- 静默浪潮        
    -- 吉美尔鲁斯
    [635] = { {"SanChongFuZhi.ogg", 0} }, -- 三重复制
    [97]  = { {"ZhunBeiDianMing.ogg", 1} }, -- 神经链接
    [98]  = { {"ZhunBeiLaRen.ogg", 0} }, -- 星界束缚
    [100] = { {"DianMingFangShui.ogg", 1} }, -- 寰宇刺击
    -- 迪詹崔乌斯
    [420] = { {"TanKeChengShangSanMiaoQuSanTanKe.ogg", 1, {TANK = true, HEALER = true}} }, -- 庞大碎片  
    [292] = { {"ZhunBeiJieQuan.ogg", 1} }, -- 不稳定的虚空精华
    [290] = { {"ShiErMiaoDuoQiuShiWuMiaoDuoQiuShiBaMiaoDuoQiu.ogg", 1} }, -- 贪噬之熵   

    -- 元首阿福扎恩
    [194] = { {"ZhaoHuanDaGuai.ogg", 1} }, -- [暗影进军] (1262776)
    [195] = { {"ZhaoHuanDaGuai.ogg", 1} }, -- [暗影进军] (1251361)
    [198] = { {"DuoBiBiaoQiang.ogg", 1} }, -- [湮灭之怒] (1260712)
    [197] = { {"FenTanShangHaiQiMiaoFenTanShangHaiZhuanHuoDaGuai.ogg", 1} }, -- [幽影坍缩] (1249265)
    [200] = { {"ShouLingKuangBao.ogg", 0} }, -- [无尽行军] (1251583)
    -- [201] = { {".ogg", 1} }, -- [浓暗壁垒] (1255702)    
    -- [492] = { {".ogg", 1} }, -- [虚弱] (1283069)
    [419] = { {"ZhunBeiDianMing.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- [虚空标记] (1280015)
    [196] = { {"ZhunBeiAOE.ogg", 1, {HEALER = true}} }, -- [黑暗颠覆] (1249251)
    [199] = { {"ZhunBeiJiTuiShiYiMiaoZhuYiDuoQuan.ogg", 2} }, -- [虚空坠落] (1258880) (来自原表2)
    [209] = { {"ZhunBeiJiTuiShiYiMiaoZhuYiDuoQuan.ogg", 2} }, -- [虚空坠落] (1266786) (来自原表2)

    -- 弗拉希乌斯
    [133] = { {"ZhunBeiJiTuiLiangMiaoSanErYi.ogg", 1} }, -- [始源咆哮] (1260046)
    [59]  = { {"TanKeChengShangSanErYiShiMiaoTanKeChengShangSanErYi.ogg", 1} }, -- [影爪重击] (1241836)
    [60]  = { {"TanKeChengShangSanErYiShiMiaoTanKeChengShangSanErYi.ogg", 1} }, -- [影爪重击] (1244293)
    [62]  = { {"ZhuYiJiaoXia.ogg", 1}, {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}} }, -- [散逸寄生虫] (包含原表2)
    [61]  = { {"ZhunBeiJiGuang.ogg", 0} }, -- [虚空吐息] (1243853)

    -- 陨落之王萨哈达尔
    -- [140] = { {"ZhunBeiDianMing.ogg", 1} }, -- 专制命令 (1260823)
    [143] = { {"HuanJingShangHai.ogg", 1, {HEALER = true}} }, -- 扭曲遮蔽 (1250686)
    [148] = { {"YiShangJieDuan.ogg", 1}, {"ZhunBeiYiShang.ogg", 2} }, -- 熵能瓦解 (包含原表2)
    [141] = { {"KongDuanDaGuai.ogg", 1, {DAMAGER = true, TANK = true}} }, -- 破碎投影 (1254081)
    [142] = { {"ZhunBeiDiCi.ogg", 1} }, -- 粉碎暮光 (1253911)
    [139] = { {"ZhaoHuanXiaoGuai.ogg", 1, {DAMAGER = true, TANK = true}} }, -- 虚空融合 (1243453)

    -- 威厄高尔和艾佐拉克
    [103] = { {"CengQiu.ogg", 1}, {"ZhunBeiCengQiuSanErYi.ogg", 2} }, -- 阴霾 (包含原表2)
    [104] = { {"KongJuTuXi.ogg", 1}, {"ZhunBeiKongJuLiangMiaoSanErYi.ogg", 2} }, -- 亡者吐息 (包含原表2)
    [105] = { {"ZhuanHuoDaGuai.ogg", 1} }, -- 午夜烈焰 (1249748)
    -- [221] = { {"TanKeChengShang.ogg", 1, TANK = true} }, -- 威厄之翼 (1265131)
    -- [220] = { {"TanKeChengShang.ogg", 1, TANK = true} }, -- 拉克獠牙 (1245645)
    -- [551] = { {".ogg", 1} }, -- 穿刺 (435193)
    -- [101] = { {"TanKeTuXi.ogg", 1} }, -- 虚无光束 (1262623)
    [102] = { {"WuMaFenSan.ogg", 1}, {"ZhunBeiXiaoGuai.ogg", 2} }, -- 虚空嚎叫 (包含原表2)
    [381] = { {"KaoJinZhongChang.ogg", 1} }, -- 辐光屏障 (1248847)

    -- 光盲先锋军
    [74]  = { {"ZhunBeiPoDun.ogg", 1, {DAMAGER = true}} }, -- 圣洁护盾 (1248674)
    [80]  = { {"ZhunBeiDuoFeiDun.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 圣洁鸣钟 (1248644)
    [85]  = { {"FenTanShangHai.ogg", 1} }, -- 处决宣判 (1276368)
    [79]  = { {"BaMaFenSan.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 复仇者之盾 (1246485)
    [365] = { {"BaMaFenSan.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 复仇者之盾 (1276635)
    [78]  = { {"ZhuYiHuanTan.ogg", 1, {TANK = true}}, {"ZhunBeiShenPanSanErYi.ogg", 2, {TANK = true}} }, -- 审判 (包含原表2)
    [82]  = { {"ZhuYiHuanTan.ogg", 1, {TANK = true}}, {"ZhunBeiShenPanSanErYi.ogg", 2, {TANK = true}} }, -- 审判 (包含原表2)
    -- [75]  = { {"ZhunBeiShuaDun.ogg", 1, {HEALER = true}} }, -- 提尔之怒 (1276831)
    [77]  = { {"ZhunBeiAOE.ogg", 1, {HEALER = true}} }, -- 灼热光辉 (1255738)
    [373] = { {"ZhunBeiAOE.ogg", 1, {HEALER = true}} }, -- 灼热光辉 (1276639)
    -- [535] = { {".ogg", 1} }, -- 盲目之光 (428169)
    -- [83] = { {".ogg", 1} }, -- 神圣风暴 (1246765)
    -- [374] = { {".ogg", 1} }, -- 神圣风暴 (1272310)
    [84]  = { {"AOE.ogg", 1, {HEALER = true}}, {"ZhunBeiAOELiangMiaoSanErYi", 2, {HEALER = true}} }, -- 神圣鸣罪 (包含原表2)
    -- [76]  = { {"DuoKaiDaQuan.ogg", 1} }, -- 虔诚光环 (1246162)    
    -- [71]  = { {"DuoKaiDaQuan.ogg", 1} }, -- 平心光环 (1248451)
    -- [81]  = { {"DuoKaiDaQuan.ogg", 1} }, -- 愤怒光环 (1248449)
    [73]  = { {"DuoKaiChongFeng.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 雷象冲锋 (1249130)

    -- 奇美鲁斯，未梦之神
    [118] = { {"ZhunBeiAOE.ogg", 1, {HEALER = true}} }, -- 不谐咆哮 (1249207)
    [117] = { {"DaDuanDuTiao.ogg", 1, {DAMAGER = true, TANK = true}} }, -- 可怖战吼 (1249017)
    [307] = { {"ZhunBeiAOE.ogg", 1} }, -- 吞噬 (1245396)
    [119] = { {"ZhunBeiQuSan.ogg", 1, {HEALER = true}}, {"ZhunBeiDianMing.ogg", 2} }, -- 吞噬瘴气 (包含原表2)
    [51]  = { {"DuoKaiTouQian.ogg", 1} }, -- 猛撕开裂 (1272726)
    [53]  = { {"ZhunBeiTuXi.ogg", 1} }, -- 腐化毁灭 (1245452)
    [458] = { {"ZhunBeiTuXi.ogg", 1} }, -- 腐化毁灭 (1282856)
    [50]  = { {"ZhunBeiAOE.ogg", 1, {HEALER = true}} }, -- 腐蚀黏痰 (1246621)
    [149] = { {"FenTanShangHai.ogg", 1} }, -- 艾林之尘剧变 (1262289)
    [431] = { {"FenTanShangHai.ogg", 1} }, -- 艾林之尘剧变 (1282001)
    [555] = { {"ShouLingQiangHua.ogg", 1} }, -- 被吞噬的精华 (1245844)
    [49]  = { {"ZhunBeiNeiChang.ogg", 1}, {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}} }, -- 裂隙涌现 (包含原表2)
    [217] = { {"ZhunBeiJiuRen.ogg", 1} }, -- 裂隙疯狂 (1268905)
    [48]  = { {"ZhunBeiJiFei.ogg", 0} }, -- 贪食俯冲 (1245404)

    -- 宇宙之冕
    [15]  = { {"ChangDiQieHuan.ogg", 1} }, -- 噬灭宇宙 (1238843)
    [8]   = { {"ZhuYiDuoQuan.ogg", 1} }, -- 奇点喷发 (1235622)
    [12]  = { {"ZhunBeiDaDun.ogg", 0, {DAMAGER = true, HEALER = true}} }, -- 宇宙屏障 (1246918)
    [66]  = { {"ZhunBeiChenMo.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 干扰震荡 (1243743)
    [65]  = { {"JinZhanDaQuan.ogg", 1, {DAMAGER = true}} }, -- 暴食深渊 (1243753)
    [11]  = { {"ZhunBeiYinFengJian.ogg", 1} }, -- 游侠队长印记 (1237614)
    [131] = { {"ZhunBeiYinFengJian.ogg", 1} }, -- 游侠队长印记 (1260010)
    -- [4]   = { {"ZhuYiDanShua.ogg", 1, {HEALER = true}} }, -- 空无之冕 (1233865)
    [14]  = { {"DuoBiBiaoQiang.ogg", 1} }, -- 空虚之握 (1232467)
    [132] = { {"DuoBiBiaoQiang.ogg", 1} }, -- 空虚之握 (1260026)
    [13]  = { {"ZhunBeiLaXian.ogg", 1}, {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}} }, -- 终末守护 (包含原表2)
    [10]  = { {"ZhunBeiXiaoGuai.ogg", 1, {DAMAGER = true}} }, -- 虚空召唤 (1237837)
    [5]   = { {"HeiQiuChuXianDanQiuZhunBeiSanErYiShuangQiuZhunBeiSanErYi.ogg", 1, {HEALER = true}}, {"ZhunBeiHeiQiu.ogg", 2} }, -- 虚空斥力 (包含原表2)
    [6]   = { {"ZhunBeiYinFengJian.ogg", 2} }, -- 银锋箭 (来自原表2)
    -- [9]   = { {".ogg", 1, HEALER = true} }, -- 虚空追猎者钉刺 (1237035)
    [137] = { {"TanKeChengShang.ogg", 1, {TANK = true}} }, -- 裂隙挥砍 (1246461)
    [7]   = { {"SheXian.ogg", 1} }, -- 银锋弹幕射击 (1234564)    
    [64]  = { {"TanKeJiTui.ogg", 1, {TANK = true}} }, -- 黑暗之手 (1233787)

    -- 贝洛朗，奥的子嗣
    [130] = { {"ZhunBeiBaoZhu.ogg", 1} }, -- light (1242981)
    [494] = { {"FenTanShangHai.ogg", 0} }, -- 圣光俯冲 (1241292)
    [482] = { {"NiShiHuangSe.ogg", 0} }, -- 圣光羽毛 (1241162)
    [384] = { {"MuBiaoShiNi.ogg", 0} }, -- 圣光飞羽 (1241992)
    [497] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 复生 (1241313)
    [134] = { {"TanKeLianJi.ogg", 1, {TANK = true}} }, -- 守护者敕令 (1260763)
    [272] = { {"ZhunBeiJiFei.ogg", 2} }, -- 死亡坠落 (1246709)
    [138] = { {"ShuaXiNaiDun.ogg", 1, {HEALER = true}} }, -- 永恒灼烧 (1244344)
    -- [161] = { {"ZhuYiSheXian.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 注能飞羽 (1242260)
    -- [273] = { {".ogg", 1} }, -- 烈焰孵化 (1242792)
    [218] = { {"KaiShiHuanSe.ogg", 1}, {"ZhunBeiHuanSeSanErYiKaiShiHuanSe.ogg", 2} }, -- 虚光汇流 (包含原表2)
    [495] = { {"FenTanShangHai.ogg", 0} }, -- 虚空俯冲 (1241339)
    [483] = { {"NiShiLanSe.ogg", 0} }, -- 虚空羽毛 (1241163)
    [385] = { {"MuBiaoShiNi.ogg", 0} }, -- 虚空飞羽 (1242091)
    [128] = { {"FenTanShangHai.ogg", 1} }, -- 贝洛朗的燃烬 (1241282)

    -- 至暗之夜降临    
    [632] = { {"MiaoZhunHeiQiu.ogg", 0}, {"ZhunBeiSheQiu.ogg", 2} }, -- 充电 (包含原表2)
    [259] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 全蚀 (1261871)
    [261] = { {"XiHeiQiu.ogg", 1} }, -- 圣光虹吸 (1266897)
    [364] = { {"TanKeChengShang.ogg", 1, {TANK = true}} }, -- 天穹之枪 (1267049)
    [256] = { {"DuoKaiZhanRen.ogg", 1} }, -- 天穹战刃 (1253915)
    [257] = { {"ZhunBeiHuWeiDaDuanHuWeiZhuanHuoShuiJing.ogg", 1} }, -- 护卫棱镜 (1251386)
    -- [434] = { {".ogg", 1} }, -- 宇宙裂变 (1282249)
    -- [363] = { {".ogg", 1} }, -- 断离 (1276202)
    [437] = { {"SheXianDianNi.ogg", 0} }, -- 星辰裂片 (1282441)
    [435] = { {"DuoKaiLianXian.ogg", 1}, {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}} }, -- 核心收割 (包含原表2)
    -- [362] = { {".ogg", 1} }, -- 死亡安魂曲 (1273158)    
    [255] = { {"FuWenDianNi.ogg", 0}, {"ZhunBeiFuWenLiangMiaoSanErYi.ogg", 2} }, -- 死亡挽歌 (包含原表2)
    [433] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 深入黑暗之井 (1282047)
    -- [258] = { {".ogg", 1} }, -- 破碎天空 (1249796)
    -- [636] = { {".ogg", 1} }, -- 终结棱柱 (1284931)
    -- [260] = { {".ogg", 1} }, -- 至暗之夜 (1266622)
    -- [405] = { {".ogg", 1} }, -- 蚀盛 (1237690)
    [263] = { {"KuaiJinZhaoZiQiMiaoKuaiPao.ogg", 1} }, -- 黑暗天使长 (1250898)
    -- [262] = { {"DuoKaiXingZuo.ogg", 1} }, -- 黑暗星座 (1266388)
    [436] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 黑暗熔毁 (1281194)
    -- [650] = { {"FuWenDianNi.ogg", 0} }, -- 黑暗符文 (1249609)
    [649] = { {"ZhuYiSheXian.ogg", 1} }, -- 黑暗类星体 (1279420)
    -- [644] = { {".ogg", 1} }, -- 黯灭协奏 (1284980)

    -- 腐沼
    [424] = { {"ZhunBeiJiTuiLiangMiaoSanErYi.ogg", 1} }, -- 真菌绽放 (1221637)
    [425] = { {"ZhuYiJiaoXia.ogg", 1} }, -- 唤醒真菌 (1221622)
    [426] = { {"ZhunBeiAOE.ogg", 1}, {"WuMiaoHouAOE.ogg", 2, {HEALER = true}} }, -- 脓包爆裂 (1221787)
    [427] = { {"WuMiaoHouTanKeJianCi.ogg", 2, {TANK = true}}, {"TanKeJianCi.ogg", 1, {TANK = true}} }, -- 腐烂之拳 (1221781)
    [428] = { {"ZhunBeiDianMing.ogg", 1, {DAMAGER = true, HEALER = true}} }, -- 溃烂藤蔓 (1222088)
    -- [808] = { {"HongSeLianXian.ogg", 0} },
    -- [809] = { {"LvSeLianXian.ogg", 0} },
    -- 光明众花
    [177] = { {"ZhunBeiCaiQuan.ogg", 1} }, -- 光明之花射线 (1235564)
    [173] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 基岩猛击 (1234753)
    [174] = { {"DuoKaiChongFeng.ogg", 1} }, -- 播光急奔 (1234850)
    -- [175] = { {"ZhunBeiLiuXue.ogg", 1} }, -- 荆棘之刃 (1235640)
    -- [176] = { {"ZhunBeiLiuXue.ogg", 1} }, -- 荆棘之刃 (1261276)

    -- 圣光猎手伊库兹
    [179] = { {"ZhunBeiAOE.ogg", 1} }, -- 唤棘者咆哮 (1236709)
    [180] = { {"MuBiaoShiNi.ogg", 0} }, -- 嗜血注视 (1237090)
    [178] = { {"XiaoXinJiTui.ogg", 1} }, -- 青翠践踏 (1236746)

    -- 护光者鲁伊亚
    [181] = { {"ZhuYiDianMing.ogg", 1}, {"TieBianFangShui.ogg", 0}}, -- 光明之火 (1239824)
    [182] = { {"ZhuYiDuoQuan.ogg", 1} }, -- 光明坠落 (1240098)
    [184] = { {"ZhunBeiLiuXue.ogg", 1}, {"WuMiaoHouAOE.ogg", 2, {HEALER = true}} }, -- 凶残痛击 (1241058)
    [188] = { {"JieDuanZhuanHuan.ogg", 1} }, -- 峡谷之灵 (1241067)
    [115] = { {"TanKeChengShang.ogg", 1} }, -- 撕裂之爪 (1258136)
    [183] = { {"ZhuYiDianMing.ogg", 1} }, -- 粉碎打击 (1240210)

    -- 兹欧凯特
    [192] = { {"ZhunBeiChiQiu.ogg", 1} }, -- 光绽精华 (1246858)
    [191] = { {"MuBiaoShiNi.ogg", 0} }, -- 凝聚光线 (1246607)
    [189] = { {"ZhunBeiXiaoGuai.ogg", 1} }, -- 唤醒光绽 (1246372)
    [190] = { {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}} }, -- 棘刺 (1247685)
}