local addonName, addonTable = ...
addonTable.AudioTimeline = {
    [1698] = {
        interval = 40, 
        startOffset = 4, 
        alerts = {
            [0]  = { file = "ZhunBeiDianMing.ogg", role = {"HEALER", "DAMAGER"} },
            -- [6]  = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" },
            [8]  = "ZhunBeiAOE.ogg",
            -- [10] = "LiuXue.ogg",
            [14] = "ZhunBeiHuiXuanBiao.ogg",
            [19] = "FeiBiaoFanHui.ogg",
            [24] = "ZhunBeiHuiXuanBiao.ogg",
            [29] = "FeiBiaoFanHui.ogg",
            -- [26] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" },
            [28] = "ZhunBeiAOE.ogg",
            [31] = "ZhunBeiDuoFeng.ogg",
        }
    },
    [1699] = {
        interval = 9999, 
        startOffset = 5, 
        alerts = {
            -- [0]  = "ZhuYiTouQian.ogg",
            -- [3]  = "小怪激活.ogg",
            -- [10] = "ZhuYiTouQian.ogg",
            -- [15] = "ZhuYiTouQian.ogg",
            [23] = "ZhuYiJiaoXia.ogg",
            -- [25] = "小怪激活.ogg",
            -- [30] = "ZhuYiTouQian.ogg",
            -- [35] = "ZhuYiTouQian.ogg",
            [44] = "ZhuYiJiaoXia.ogg",
            -- [41] = "ZhunBeiAOE.ogg",
        }
    },
    [1700] = {
        interval = 47, 
        startOffset = 5, 
        alerts = {
            [0]  = { file = "ZhuYiJianShang.ogg", role = "TANK" }, 
            [1]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" }, 
            [7]  = "ZhaoHuanXiaoGuai.ogg",
            [10] = { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            [11] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" }, 
            [12] = { file = "ZhuYiJianShang.ogg", role = "TANK" }, 
            [28] = "ZhaoHuanXiaoGuai.ogg",
            [31] = { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            [33] = "KuaiZhaoYanTi.ogg",
            [41] = "San.ogg",
            [42] = "Er.ogg",
            [43] = "Yi.ogg",
            [44] = "AnQuanAnQuan.ogg",
        }
    },
    [1701] = {
        interval = 39, 
        startOffset = 5, 
        alerts = {
            -- [1] =  { file = "ZhuYiDanShua.ogg", role = "HEALER" }, 
            [3] =  { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [10] = { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [11] = { file = "ZhuYiDanShua.ogg", role = "HEALER" }, 
            [15] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [21] = { file = "ZhuYiDanShua.ogg", role = "HEALER" }, 
            [24] = "ZhunBeiJiGuang.ogg",
        }
    },
    [1999] = { -- 熔炉之主加弗斯特
        interval = 42, 
        startOffset = 4, 
        alerts = {
            [0] =  "ZhunBeiDianMing.ogg",
            [20] = "ZhuYiDuoQuan.ogg",
            -- [29] = "KuaiZhaoYanTi.ogg",
            [37] = { file = "KuaiKaiJianShang.ogg", role = {"HEALER", "DAMAGER"} },
            [39] = "ZhuYiDuoQuan.ogg",
            [41] = { file = "QuSanDuiYou.ogg", role = "HEALER" }, 
        }
    },
    [2001] = { -- 伊克和科瑞克
        interval = 83, 
        startOffset = 1, 
        alerts = {
            [0] =  "KuaiKaiJianShang.ogg",
            [4] =  "ZhunBeiZuZhou.ogg",
            [6] =  { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [7] =  { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [10] = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            [20] = "ZhunBeiAOE.ogg",
            [22] = "ZhuYiDuoQuan.ogg",
            -- [24] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [29] = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            [39] = "ZhunBeiAOE.ogg",
            [41] = "ZhuYiDuoQuan.ogg",
            [49] = "ZhunBeiZhuiRen.ogg",
        }
    },
    [2000] = { -- 天灾领主泰兰努斯
        interval = 85, 
        startOffset = 0, 
        alerts = {
            [0] =  "ZhunBeiAOE.ogg",
            [4] =  { file = "ZhunBeiDianMing.ogg", role = {"HEALER", "DAMAGER"} },
            [14] = { file = "XiaoXinJiTui.ogg", role = "TANK" }, 
            [17] = "DuoKaiDaQuan.ogg",
            [24] = "ZhuYiDuoQuan.ogg",
            [33] = { file = "ZhunBeiDianMing.ogg", role = {"HEALER", "DAMAGER"} },
            [41] = { file = "XiaoXinJiTui.ogg", role = "TANK" }, 
            [44] = "DuoKaiDaQuan.ogg",
            [52] = "ZhunBeiXiaoGuai.ogg",
            [54] = "San.ogg",
            [55] = "Er.ogg",
            [56] = "Yi.ogg",
            [57] = { file = "JiHuoDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [58] = { file = "DaDuanDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            [60] = { file = "KuaiKaiJianShang.ogg", role = {"HEALER", "DAMAGER"} },
            -- [67] = { file = "DaDuanDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            [69] = "ZhuYiDuoQuan.ogg",
        }
    },
    [2065] = { -- 晋升者祖拉尔
        interval = 56, 
        startOffset = 0, 
        alerts = {
            -- [2] = { file = "ZhuYiJianShang.ogg", role = "TANK" }, 
            -- [3] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" }, 
            -- [7] =  "TieBianFangShui.ogg",
            -- [16] = "DuoKaiZhengMian.ogg",
            -- [22] = { file = "MeiYouYinPin.ogg", duration = 3 },
            [29] = { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [33] = "TieBianFangShui.ogg",
            -- [35] = { file = "ZhuYiJianShang.ogg", role = "TANK" }, 
            -- [36] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" }, 
            -- [45] = { file = "MeiYouYinPin.ogg", duration = 5 },
            [52] = "XiaoXinJiTui.ogg",
        }
    },
    [2066] = { -- 萨普瑞什
        interval = 38, 
        startOffset = 0, 
        alerts = {
            [20] = "QuanZhuXiaoQiu.ogg",
            -- [21] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [32] = "ZhunBeiAOE.ogg",
        }        
    },
    [2067] = { -- 总督奈扎尔
        interval = 65, 
        startOffset = 0, 
        alerts = {
            [10] = "DuoQiu.ogg",
            [28] = "DuoQiu.ogg",
            [45] = "XiaoXinJiFei.ogg",
            [48] = "KaoJinZhongChang.ogg",
            [52] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" }, 
            [56] = { file = "KuaiKaiJianShang.ogg", role = {"TANK", "DAMAGER"} },
            [57] = { file = "DaZhaoTaiXue.ogg", role = "HEALER" }, 
        }        
    },
    [2068] = { -- 鲁拉
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            -- [0]  = { file = "BieKaiBaoFa.ogg", role = "DAMAGER" }, 
            -- [2]  = "ZhunBeiAOE.ogg",
            -- [12] = "ZhuYiSheXian.ogg",
            [13] = { file = "TanKeJianCi.ogg", role = "TANK" }, 
            [15] = "ZhuYiZiBao.ogg",
            [17] = "San.ogg",
            [18] = "Er.ogg",
            [19] = "Yi.ogg",
            [20] = "AnQuanAnQuan.ogg",
            -- [22] = "ZhunBeiDianMing.ogg",
            [29] = { file = "TanKeJianCi.ogg", role = "TANK" }, 
            -- [35] = "DuoKaiDaQuan.ogg",
            -- [45] = "ZhuYiSheXian.ogg",
            [45] = { file = "TanKeJianCi.ogg", role = "TANK" }, 
            [50] = "San.ogg",
            [51] = "Er.ogg",
            [52] = "Yi.ogg",
            [53] = "AnQuanAnQuan.ogg",
        }        
    },
    [2562] = {
        interval = 44, 
        startOffset = 2, 
        alerts = {
            -- [0]  = "ZhunBeiChiQiu.ogg",
            [0]  = "ZhunBeiChiQiu.ogg",
            [3]  = { file = "TanKeTouQian.ogg", role = "TANK" },
            [13] = { file = "ZhunBeiFangShui.ogg", role = {"DAMAGER", "HEALER"} },
            [18] = "ZhunBeiChiQiu.ogg",
            [21] = { file = "TanKeTouQian.ogg", role = "TANK" },
            [31] = { file = "ZhunBeiFangShui.ogg", role = {"DAMAGER", "HEALER"} },
            [38] = { file = "ZhunBeiJiTui.ogg", duration = 3 },
            [41] = "ZhuYiJiaoXia.ogg",
        }
    },
    [2563] = { -- 茂林古树
        interval = 58, 
        startOffset = 9, 
        alerts = {
            -- [0]  = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            -- [9]  = "ZhuYiJiaoXia.ogg",
            -- [21] = { file = "ZhunBeiDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            [21] = { file = "LiuXue.ogg", role = "HEALER" }, 
            -- [23] = { file = "ZhuanHuoDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [28] = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            -- [30] = { file = "DaDuanDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [42] = "ZhuYiJiaoXia.ogg",
            -- [46] = "ZhunBeiAOE.ogg",
        }
    },
    [2564] = {
        interval = 24, 
        startOffset = 5, 
        alerts = {
            [0]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            [1]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            [4]  = { file = "WuMiaoHouAOE.ogg", role = "HEALER" },
            [9]  = { file = "TingZhiShiFa.ogg" },
            -- [10] = { file = "Er.ogg" },
            -- [11] = { file = "Yi.ogg" },
            [15] = "DuoKaiZhengMian.ogg",
        },
        -- 新增：事件触发配置
        eventAlerts = {
            -- 触发此事件时：播音，并彻底停掉计时器
            ["CLEAR_BOSS_EMOTES"] = { file = "KaiShiYunQiu.ogg", action = "STOP" },             
            -- 触发此事件时：播音，并重头开始计时
            ["ENCOUNTER_TIMELINE_EVENT_ADDED"] = { file = "MeiYouYinPin.ogg", action = "START" },
        }
    },
    [2565] = {
        interval = 33, 
        startOffset = 0, 
        alerts = {
            [9]  = { file = "TanKeJianShang.ogg", role = "TANK" },
            [14] = { file = "ZhunBeiDianMing.ogg", role = {"DAMAGER", "HEALER"} },
            [17] = { file = "ZhuYiQuSan.ogg", role = "HEALER" }, 
            [21] = { file = "TanKeJianCi.ogg", role = {"TANK", "HEALER"} },
            [24] = "ZhunBeiLaRen.ogg",
            [25] = "San.ogg",
            [26] = "Er.ogg",
            [27] = "Yi.ogg",
            [30] = "DuoKaiDaQuan.ogg",
        }
    },
    [3056] = {
        interval = 9999, -- 40?
        startOffset = 0, 
        alerts = {
            -- [5]  = "ZhunBeiDianMing.ogg",
            -- [11] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [12] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [16] = "ZhunBeiChuiFeng.ogg",
            -- [19] = "NiShiZhenTouQian.ogg",
            [24] = { file = "KuaiKaiJianShang.ogg", role = "DAMAGER" }, 
            -- [34] = "San.ogg",
            -- [35] = "Er.ogg",
            -- [36] = "Yi.ogg",
            -- [37] = "ChuiFengJieShu.ogg",
        },
        -- eventAlerts = {
        --     ["RAID_BOSS_WHISPER"] = { file = "TieBianFangShuiSanMiaoSanErYi.ogg", action = "STOP" },       
        -- }
    },
    [3057] = { -- 被遗弃的二人组
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            [2]  = { file = "DaDuanNvYao.ogg", role = {"TANK", "DAMAGER"} },
        }
    },
    [3058] = {
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            -- [3]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            [5]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
        },
    },
    [3059] = {
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            [25] = "ZhunBeiCaiQuan.ogg",
            [29] = "SanErYiCaiQuanShangTian.ogg",
            [91] = "ZhunBeiCaiQuan.ogg",
            [95] = "SanErYiCaiQuanShangTian.ogg",
            [155]= "ZhunBeiCaiQuan.ogg",
            [159]= "SanErYiCaiQuanShangTian.ogg",
        }
    },
    [3071] = {
        interval = 69, 
        startOffset = 0, 
        alerts = {
            [5]  = { file = "TanKeJiTui.ogg", role = {"HEALER", "TANK"} },
            -- [16] = { file = "XiaoXinJiTui.ogg", duration = 2.9 },
            [20] = "ZhunBeiDianMing.ogg",
            [24] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [28] = { file = "TanKeJiTui.ogg", role = {"HEALER", "TANK"} },
            -- [39] = { file = "XiaoXinJiTui.ogg", duration = 2.9 },
            [46] = "ZhunBeiChiQiu.ogg",
            [49] = "YiShangJieDuan.ogg",
            [62] = "DaoShu5.ogg",
            [63] = "DaoShu4.ogg",
            [64] = "DaoShu3.ogg",
            [65] = "DaoShu2.ogg",
            [66] = "DaoShu1.ogg",
            [67] = "YiShangJieShu.ogg",
        }
    },
    [3072] = { -- 瑟拉奈尔·日鞭
        interval = 57, 
        startOffset = 0, 
        alerts = {
            [7]  = "ZhunBeiDianMing.ogg",
            [18] = "DuoKaiDaQuan.ogg",
            [20] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" },
            [22] = "ZhuYiDuoQuan.ogg",
            [26] = "ZhuYiDuoQuan.ogg",
            -- [27] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [30] = "JinGongQuSanMoFa.ogg",            
            [36] = "ZhunBeiDianMing.ogg",
            [38] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" },
            [40] = "ZhuYiDuoQuan.ogg",
            [44] = "ZhuYiDuoQuan.ogg",
            -- [51] = { file = "MeiYouYinPin.ogg", duration = 4.9 }
            -- [52] = "Si.ogg",
            -- [53] = "San.ogg",
            -- [54] = "Er.ogg",
            -- [55] = "Yi.ogg",
            -- [56] = "Jin.ogg",
        }
    },
    -- [3073] = {
    --     interval = 9999, 
    --     startOffset = 0, 
    --     alerts = {
    --         [5]  = "ShouLingFuZhi.ogg",
    --     }
    -- },
    -- [3074] = { -- 迪詹崔乌斯
    --     interval = 22, 
    --     startOffset = 0, 
    --     alerts = {
    --         [33] = "Yi.ogg",            
    --     }
    -- },
    [3177] = { -- 弗拉希乌斯
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [88]  = "KuaiKaiJianShang.ogg",
            [208] = "KuaiKaiJianShang.ogg",
            [329] = "KuaiKaiJianShang.ogg",
        }
    },
    [3179] = { -- 陨落之王萨哈达尔
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [36]  = { file = "ZhuanHuoErQiu.ogg", role = "DAMAGER" },
            [82]  = { file = "ZhuanHuoErQiu.ogg", role = "DAMAGER" },
            [155] = { file = "ZhuanHuoErQiu.ogg", role = "DAMAGER" },
            [208] = { file = "ZhuanHuoErQiu.ogg", role = "DAMAGER" },
            [278] = { file = "ZhuanHuoErQiu.ogg", role = "DAMAGER" },
            [329] = { file = "ZhuanHuoErQiu.ogg", role = "DAMAGER" },
        }
    },
    [3306] = { -- 奇美鲁斯
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [68]  = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
            [139] = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
            [319] = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
            [391] = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
        }
    },

    [3178] = { -- 威厄高尔和艾佐拉克
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [300] = "FangQiuZhanWei.ogg",
            [302] = "GeRenJianShang.ogg",
            [303] = "San.ogg",
            [304] = "Er.ogg",
            [305] = "Yi.ogg",
        }
    },
    [3180] = { -- 光盲先锋军
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [17] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [19] = { file = "LaZouFangQi.ogg", role = "TANK" },
            [32] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
            [34] = "DuoBiFeiDun.ogg",
            [57] = { file = "ZhuanHuoFangQi.ogg", role = "DAMAGER" },
            [63] = "QunTiFeiDunZhunBei.ogg",
            [71] = { file = "LaZouChengJie.ogg", role = "TANK" },
            [79] = "TianChuiZhanWei.ogg",
            [87] = "DuoBiFeiDun.ogg",
            [92] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
            [95] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [107] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [125] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [126] = { file = "ZhuYiDuoFeng.ogg", role = {"HEALER", "DAMAGER"} },
            [127] = { file = "LaZouNaiQi.ogg", role = "TANK" },
            [134] = "TianChuiZhanWei.ogg",            
            [139] = { file = "QuSanMoFa.ogg", role = "HEALER" },            
            [142] = "GeRenJianShang.ogg",
            [145] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [161] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [164] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
            [179] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [193] = "DuoBiFeiDun.ogg",
            [209] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
            [225] = "QunTiFeiDunZhunBei.ogg",
            [238] = "TianChuiZhanWei.ogg",
            [246] = "DuoBiFeiDun.ogg",
            [254] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [261] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
            [269] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [287] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [294] = "TianChuiZhanWei.ogg",
            [298] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [302] = "ZuiQiangYiBo.ogg",
            [304] = "GeRenJianShang.ogg",
            [305] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [324] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
            [325] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [341] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [352] = "DuoBiFeiDun.ogg",
            [368] = { file = "ZhuanHuoNaiQi.ogg", role = "DAMAGER" },
        }
    },
    -- [3181] = { -- CrownOfTheCosmos
    --     interval = 999, 
    --     startOffset = 0, 
    --     alerts = {
    --         -- 修改后的配置示例
    --         [5] = { 
    --             file = "MeiYouYinPin.ogg", 
    --             duration = 5, 
    --             checkCast = true  -- 新增参数，标记此警报需要检查施法
    --         },
    --         [25] = { 
    --             file = "MeiYouYinPin.ogg", 
    --             duration = 5, 
    --             checkCast = true  -- 新增参数，标记此警报需要检查施法
    --         },
    --     }
    -- },
    [3212] = { -- 姆罗金和内克拉克斯
        interval = 45, 
        startOffset = 0, 
        alerts = {
            -- [5]  = { file = "XiaoXinJiFei.ogg", role = "TANK" }, 
            -- [6]  = { file = "TanKeLiuXue.ogg", role = "HEALER" }, 
            -- [12] = "ZhunBeiJiBing.ogg",
            -- [20] = "DuoKaiXianJing.ogg",
            -- [28] = "ZhuYiDuoQuan.ogg",
            -- [32] = "ZhunBeiJianYu.ogg",
            [40] = { file = "QuSanMoFa.ogg", role = "HEALER" }, 
        }
    },
    -- [3213] = { -- 沃达扎
    --     interval = 9999, 
    --     startOffset = 0, 
    --     alerts = {
    --         [80] = "ZhuYiDuoQiu.ogg",
    --     }
    -- },
    [3214] = { -- 拉克图尔，聚魂之器
        interval = 120, 
        startOffset = 0, 
        alerts = {
            [2]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            [4]  = { file = "TieBianFangShui.ogg", role = "TANK" },
            [5]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            [6]  = "ZhuYiDuoQuan.ogg",
            [12] = "ZhuYiDuoQuan.ogg",
            [18] = "ZhuYiDuoQuan.ogg",
            [24] = { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            [29] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            [31] = { file = "TieBianFangShui.ogg", role = "TANK" },
            [36] = "ZhuYiDuoQuan.ogg",
            [42] = "ZhuYiDuoQuan.ogg",
            [49] = "ZhuYiDuoQuan.ogg",
            [52] = { file = "ZhuanHuoXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            [55] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            [57] = { file = "TieBianFangShui.ogg", role = "TANK" },
            [66] = "ZhuYiDuoQuan.ogg",
            [70] = "JieDuanZhuanHuan.ogg",
            [80] = "KongDuanDaGuai.ogg",
            -- [86] = "KuaiKaiJianShang.ogg",
            [116]= "San.ogg",
            [117]= "Er.ogg",
            [118]= "Yi.ogg",
            [119]= "YiShangJieShu.ogg",
        }
    },
    [3328] = {
        interval = 52, 
        startOffset = 0, 
        alerts = {
            [38] = "JiHeYinQiu.ogg",
            [43] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" },
            [46] = { file = "XiaoXinJiTui.ogg" },
            [48] = "KuaiKaiJianShang.ogg",
        }
    },
    [3332] = {
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            [26] = { file = "DaDuanDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [32] = "ZhunBeiYiShang.ogg",
            -- [37] = "KuaiJinShengGuang.ogg",
            -- [39] = { file = "KuaiKaiJianShang.ogg", role = {"HEALER", "DAMAGER"} },
            -- [55] = "San.ogg",
            -- [56] = "Er.ogg",
            -- [57] = "Yi.ogg",
            -- [58] = "YiShangJieShu.ogg",
        }
    },
}