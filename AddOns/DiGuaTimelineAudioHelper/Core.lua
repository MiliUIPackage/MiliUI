local addonName, addonTable = ...
local frame = CreateFrame("Frame")

-- 1. 先聲明變量（但不賦值）
local MEDIA_PATH

local RING_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Ring_20px.tga"
local PLAYER_LEVEL = UnitLevel("player")
local NEXT_PLAYER_LEVEL = PLAYER_LEVEL + 1
local UNIT_CAST_TRACKER = {}
local unitCastTracker = {}
local auraTriggeredCache = {}
local UNIT_SUCCEEDED_AND_INTERRUPTED_TRACKER = {}
local hasPlayedSiJiaoTingYuan = false
local encounterUnitTriggerCount = 0
local UNIT_CAST_TIMER_HANDLES = {} -- 用於存儲定時器句柄
local UNIT_START_TIMES = {} -- 記錄每個怪第一次進入邏輯的時間
local UNIT_CHANNEL_TRACKER = {} -- 專門記錄引導狀態的表
-- 在文件頭部定義一些常量
local RING_COLOR_NORMAL = {0.4, 1, 0.8, 0.85}
local RING_COLOR_ALARM = {1, 0.2, 0.2, 0.9} -- 紅色警示
local TargetEndTime = 0 -- 記錄當前圓環預計結束的時間點
local CurrentRingIsCastSensitive = false -- 新增：記錄當前圓環是否受施法控制
local Lindormi = false
-- 1. 定義三個公共變量（在文件頂部定義）
local ttsStartTime = 0          -- 記錄開始時間
local ttsEndTime = 0            -- 記錄結束時間
local ttsDuration = 0           -- 記錄時間差（持續時長）
local MyTTSDict = {
    skill1Time = 0,
    skill2Time = 0,
    tolerance = 0.05,
    isSampled = false, -- 標記是否正在初始化采樣
    sampleIndex = 0,     -- 追蹤當前執行到第幾個技能
    -- isListening = false, -- 公共布爾變量
}
local BOSS_KILL_3071 = false -- 奧能金剛庫斯托斯
local BOSS_KILL_3072 = false -- 瑟拉奈爾·日鞭
local BOSS_KILL_2065 = false -- 晉升者祖拉爾
local BOSS_KILL_2066 = false -- 薩普瑞什

local CastMonitor = {
    startTime = 0,
    unit = "player" -- 監控目標
}
-- local modelFrame = CreateFrame("PlayerModel")
local AudioTimeline = {
    [1698] = {
        interval = 40, 
        startOffset = 4, 
        alerts = {
            [0]  = "ZhunBeiDianMing.ogg",
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
    [1999] = { -- 熔爐之主加弗斯特
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
            [7] =  { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [10] = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            [20] = "ZhunBeiAOE.ogg",
            [22] = "ZhuYiDuoQuan.ogg",
            [24] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [29] = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            [39] = "ZhunBeiAOE.ogg",
            [41] = "ZhuYiDuoQuan.ogg",
            [49] = "ZhunBeiZhuiRen.ogg",
        }
    },
    [2000] = { -- 天災領主泰蘭努斯
        interval = 85, 
        startOffset = 0, 
        alerts = {
            [0] =  "ZhunBeiAOE.ogg",
            [4] =  "ZhunBeiDianMing.ogg",
            [14] = { file = "XiaoXinJiTui.ogg", role = "TANK" }, 
            [17] = "DuoKaiDaQuan.ogg",
            [24] = "ZhuYiDuoQuan.ogg",
            [33] = "ZhunBeiDianMing.ogg",
            [41] = { file = "XiaoXinJiTui.ogg", role = "TANK" }, 
            [44] = "DuoKaiDaQuan.ogg",
            [52] = "ZhunBeiXiaoGuai.ogg",
            [54] = "San.ogg",
            [55] = "Er.ogg",
            [56] = "Yi.ogg",
            [57] = { file = "JiHuoDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            [58] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [60] = { file = "KuaiKaiJianShang.ogg", role = {"HEALER", "DAMAGER"} },
            [67] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [69] = "ZhuYiDuoQuan.ogg",
        }
    },
    [2065] = { -- 晉升者祖拉爾
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
    [2066] = { -- 薩普瑞什
        interval = 38, 
        startOffset = 0, 
        alerts = {
            -- [6] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [7] =  "ZhuYiDuoQuan.ogg",
            -- [8] = { file = "DanShuaLiuXue.ogg", role = "HEALER" }, 
            -- [16] = "ZhuYiDuoQuan.ogg",
            -- [19] = { file = "DanShuaLiuXue.ogg", role = "HEALER" }, 
            [20] = "QuanZhuXiaoQiu.ogg",
            -- [21] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [32] = "ZhunBeiAOE.ogg",
        }        
    },
    [2067] = { -- 總督奈扎爾
        interval = 65, 
        startOffset = 0, 
        alerts = {
            -- [4]  = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [6]  = "ZhunBeiDuoQiu.ogg",
            -- [8]  = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [10] = "ZhuYiDuoQiu.ogg",
            -- [12] = { file = "ZhunBeiAOE.ogg", role = "HEALER" }, 
            -- [20] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [22] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [24] = "ZhunBeiDuoQiu.ogg",
            -- [26] = { file = "ZhunBeiAOE.ogg", role = "HEALER" },
            -- [28] = "ZhuYiDuoQiu.ogg",
            -- [30] = { file = "KongShaXiaoGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [36] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [42] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            [45] = "XiaoXinJiFei.ogg",
            [48] = "KaoJinZhongChang.ogg",
            [52] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" }, 
            [56] = { file = "KuaiKaiJianShang.ogg", role = {"TANK", "DAMAGER"} },
            [57] = { file = "DaZhaoTaiXue.ogg", role = "HEALER" }, 
        }        
    },
    [2068] = { -- 路拉
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
            -- [55] = "ZhunBeiDianMing.ogg",
            -- [66] = "ZhunBeiYiShang.ogg",
            -- [75] = "YiShangJieDuan.ogg",
            -- [91] = "ZhunBeiJiTui.ogg",
            -- [93] = "San.ogg",
            -- [94] = "Er.ogg",
            -- [95] = "Yi.ogg",
            -- [96] = "YiShangJieShu.ogg",
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
    [2563] = { -- 茂林古樹
        interval = 57, 
        startOffset = 9, 
        alerts = {
            -- [0]  = { file = "TanKeJianShang.ogg", role = {"TANK", "HEALER"} },
            -- [9]  = "ZhuYiJiaoXia.ogg",
            -- [21] = { file = "ZhunBeiDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            [21] = { file = "ZhuYiShuaXue.ogg", role = "HEALER" }, 
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
        -- 新增：事件觸發配置
        eventAlerts = {
            -- 觸發此事件時：播音，並徹底停掉計時器
            ["CLEAR_BOSS_EMOTES"] = { file = "KaiShiYunQiu.ogg", action = "STOP" },             
            -- 觸發此事件時：播音，並重頭開始計時
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
            [21] = { file = "TanKeJianShang.ogg", role = "TANK" },
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
            [22] = { file = "KuaiKaiJianShang.ogg", role = "DAMAGER" }, 
            -- [34] = "San.ogg",
            -- [35] = "Er.ogg",
            -- [36] = "Yi.ogg",
            -- [37] = "ChuiFengJieShu.ogg",
        },
        -- eventAlerts = {
        --     ["RAID_BOSS_WHISPER"] = { file = "TieBianFangShuiSanMiaoSanErYi.ogg", action = "STOP" },       
        -- }
    },
    [3057] = { -- 被遺棄的二人組
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            [2]  = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
            -- [8]  = { file = "MeiYouYinPin.ogg", duration = 4.3 },
            -- [16] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [17] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [20] = { file = "ZhunBeiZuZhou.ogg", role = {"HEALER", "DAMAGER"} },
            -- [35] = { file = "MeiYouYinPin.ogg", duration = 4.2 },
            -- [37] = { file = "KuaiKaiJianShang.ogg", role = "DAMAGER"},           
            -- [46] = "ZhunBeiDianMing.ogg",
            -- [48] = { file = "ZhiLiaoYuPu.ogg", role = "HEALER" },
        }
    },
    [3058] = {
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            -- [3]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            [5]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [14] = "ZhuYiDuoQuan.ogg",
            -- [18] = "KaoJinDuiYou.ogg",
            -- [30] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [31] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [45] = "KaoJinDuiYou.ogg",
            -- [54] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [55] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [69] = "KaoJinDuiYou.ogg",
            -- [75] = "ZhunBeiAOE.ogg",
            -- [83] = { file = "DaDuanDuTiao.ogg", role = {"TANK", "DAMAGER"} },
        },
        -- eventAlerts = {
        --     ["ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED"] = { file = "XiaoGuaiKuaiDa.ogg", action = "STOP" },       
        -- }
    },
    [3059] = {
        interval = 9999, 
        startOffset = 0, 
        alerts = {
            -- [9]  = "ZhuYiDuoQuan.ogg",
            -- [15] = { file = "CaiQuanXiaoCeng.ogg", role = {"HEALER", "DAMAGER"} },
            -- [21] = "ZhunBeiAOE.ogg",
            [25] = "ZhunBeiCaiQuan.ogg",
            [29] = "SanErYiCaiQuanShangTian.ogg",
            -- [30] = "Er.ogg",
            -- [31] = "Yi.ogg",
            -- [32] = "CaiQuanShangTian.ogg",
            -- [47] = "ZhuYiDuoQuan.ogg",
            -- [53] = { file = "CaiQuanXiaoCeng.ogg", role = {"HEALER", "DAMAGER"} },
            -- [57] = { file = "XiaoXinJiTui.ogg", role = "TANK" },
            -- [73] = "ZhunBeiJianYu.ogg",
            -- [87] = "ZhunBeiAOE.ogg",
            [91] = "ZhunBeiCaiQuan.ogg",
            [95] = "SanErYiCaiQuanShangTian.ogg",
            -- [96] = "Er.ogg",
            -- [97] = "Yi.ogg",
            -- [98] = "CaiQuanShangTian.ogg",
            -- [112]= "ZhuYiDuoQuan.ogg",
            -- [118]= { file = "CaiQuanXiaoCeng.ogg", role = {"HEALER", "DAMAGER"} },
            -- [122]= { file = "XiaoXinJiTui.ogg", role = "TANK" },
            -- [138]= "ZhunBeiJianYu.ogg",
            -- [151]= "ZhunBeiAOE.ogg",
            [155]= "ZhunBeiCaiQuan.ogg",
            [159]= "SanErYiCaiQuanShangTian.ogg",
            -- [160]= "Er.ogg",
            -- [161]= "Yi.ogg",
            -- [162]= "CaiQuanShangTian.ogg",
            -- [177]= "ZhuYiDuoQuan.ogg",
            -- [183]= { file = "CaiQuanXiaoCeng.ogg", role = {"HEALER", "DAMAGER"} },
            -- [187]= { file = "XiaoXinJiTui.ogg", role = "TANK" },
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
    [3072] = { -- 瑟拉奈爾·日鞭
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
    --         [14] = "ZhunBeiDianMing.ogg",
    --         [25] = "ZhunBeiDianMing.ogg",
    --         [38] = "ZhunBeiLaRen.ogg",
    --         [50] = "AnQuanAnQuan.ogg",
    --     }
    -- },
    -- [3074] = { -- 迪詹崔烏斯
    --     interval = 22, 
    --     startOffset = 0, 
    --     alerts = {
    --         [2]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
    --         [3]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
    --         [6]  = { file = "QuSanMoFa.ogg", role = "HEALER" },
    --         [16] = "ZhunBeiJieQuan.ogg",
    --         [18] = "接圈.ogg",
    --         [20] = "ZhunBeiDuoQiu.ogg",
    --         [23] = "San.ogg",
    --         [26] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
    --         [27] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
    --         [28] = "Er.ogg",
    --         [30] = { file = "QuSanMoFa.ogg", role = "HEALER" },
    --         [33] = "Yi.ogg",            
    --     }
    -- },
    [3177] = { -- 弗拉希烏斯
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [88]  = "KuaiKaiJianShang.ogg",
            [208] = "KuaiKaiJianShang.ogg",
            [329] = "KuaiKaiJianShang.ogg",
        }
    },
    [3179] = { -- 隕落之王薩哈達爾
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
    [3306] = { -- 奇美魯斯
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [68]  = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
            [139] = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
            [319] = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
            [391] = { file = "ZhuanHuoDaGuai.ogg", role = "DAMAGER" },
        }
    },

    [3178] = { -- 威厄高爾和艾佐拉克
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
    [3180] = { -- 光盲先鋒軍
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [17] = { file = "QuSanMoFa.ogg", role = "HEALER" },
            [19] = { file = "LaZouFangQi.ogg", role = "TANK" },
            [57] = { file = "ZhuanHuoFangQi.ogg", role = "DAMAGER" },
            [63] = "QunTiFeiDunZhunBei.ogg",
            [71] = { file = "LaZouChengJie.ogg", role = "TANK" },
            [127] = { file = "LaZouNaiQi.ogg", role = "TANK" },
            [142] = "GeRenJianShang.ogg",
        }
    },
    -- [3181] = { -- CrownOfTheCosmos
    --     interval = 999, 
    --     startOffset = 0, 
    --     alerts = {
    --         -- 修改後的配置示例
    --         [5] = { 
    --             file = "MeiYouYinPin.ogg", 
    --             duration = 5, 
    --             checkCast = true  -- 新增參數，標記此警報需要檢查施法
    --         },
    --         [25] = { 
    --             file = "MeiYouYinPin.ogg", 
    --             duration = 5, 
    --             checkCast = true  -- 新增參數，標記此警報需要檢查施法
    --         },
    --     }
    -- },
    [3212] = { -- 姆羅金和內克拉克斯
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
    -- [3213] = { -- 沃達扎
    --     interval = 9999, 
    --     startOffset = 0, 
    --     alerts = {
    --         [2]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
    --         [3]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
    --         [14] = "ZhunBeiDianMing.ogg",
    --         [25] = "DuoKaiTouQian.ogg",
    --         [35] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
    --         [36] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
    --         [48] = "ZhunBeiDianMing.ogg",
    --         [59] = "DuoKaiTouQian.ogg",
    --         [68] = "ZhunBeiPoDun.ogg",
    --         [71] = "KuaiKaiJianShang.ogg",
    --         [80] = "ZhuYiDuoQiu.ogg",
    --     }
    -- },
    [3214] = { -- 拉克圖爾，聚魂之器
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
        interval = 50, 
        startOffset = 0, 
        alerts = {
            -- [2]  = "ZhuYiSheXian.ogg",
            -- [6]  = "ZhunBeiDianMing.ogg",
            -- [12] = "ZhuYiDuoQuan.ogg",
            -- [14] = "ZhuYiSheXian.ogg",
            -- [18] = "ZhunBeiDianMing.ogg",
            -- [24] = "ZhuYiDuoQuan.ogg",
            -- [26] = "ZhuYiSheXian.ogg",
            -- [30] = "ZhunBeiDianMing.ogg",
            -- [36] = "ZhuYiSheXian.ogg",
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
            -- [2]  = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [3]  = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [5]  = "ZhunBeiDianMing.ogg",
            -- [19] = { file = "ZhuYiJianShang.ogg", role = "TANK" },
            -- [20] = { file = "ZhuYiShuaTan.ogg", role = "HEALER" },
            -- [22] = "小怪激活.ogg",
            -- [24] = "ZhunBeiDianMing.ogg",
            [26] = { file = "DaDuanDaGuai.ogg", role = {"TANK", "DAMAGER"} },
            -- [32] = "ZhunBeiYiShang.ogg",
            -- [37] = "KuaiJinShengGuang.ogg",
            -- [39] = { file = "KuaiKaiJianShang.ogg", role = {"HEALER", "DAMAGER"} },
            -- [52] = "San.ogg",
            -- [53] = "Er.ogg",
            -- [54] = "Yi.ogg",
            -- [55] = "YiShangJieShu.ogg",
        }
    },
}

local PrivateAuraList = {
    [1252733] = "XiaoXinJiTui", -- 疾風奔湧
    [154132]  = "NiBeiYiShang", -- 灼熱重擊
    [1279002] = "TanKeGuoYuan", -- 小的波是擊怒衝虛
    [1253511] = "XiaoGuaiDingNi", -- 擊邪追煞燃魔爆鬼
    -- [154150]  = "ZhuYiJianShang", -- 線熾光耀脈芒熾耀
    [1253541] = "ZhuYiJianShang", -- 線熾射耀燒脈灼芒
    [153954]  = "XiaoGuaiZhuaNi", -- 下墜扔崩碎震裂墜
    [1253531] = "JiGuangDianNiSanErYiAnQuanAnQuan", -- 光耀眩芒熾脈閃耀
    [1261286] = "ShiMaFenSanDuoKaiDaQuan", -- 鐵崩邪碎隆震薩裂擲墜投崩
    [1261540] = "QuanZhuShiTou", -- 碎礦猛擊
    [1261799] = "JingBao", -- 薩隆邪鐵淤泥
    [1275687] = "KuaiZhaoYanTi", -- 載劫過亂川災冰逆
    [1264186] = "XiaoGuaiDianNi", -- 縛囚束鎖影迷暗隱
    [1264299] = "JingBao", -- 凋零
    [1280616] = "DaGuaiZhuiNiSanErYiAnQuanAnQuan", -- 視禁凝瞳重淵笨滯
    [1264595] = "HuiDaoNeiChang", -- 暗影射線屏障
    [1262772] = "QuanZhuGuDuiKuaiKaiJianShang", -- 擊極衝裂霜零白絕    
    [245742]  = "ZhuYiZiBao", -- 襲瞬突幽影掠暗遁
    [244588]  = "JingBao", -- 虛空淤泥
    -- [1280064] = "QuanZhuXiaoQiu", -- 鋒散衝爆位逆相亂
    [246026]  = "ZhuYiZiBao", -- 彈蝕炸裂空崩虛寂
    [1268840] = "NiBeiYiShang", -- 空散虛蝕透亂滲逆
    [1263542] = "ZhuYiZiBao", -- 群體虛空灌輸
    [1263532] = "JingBao", -- 虛空風暴
    [1265426] = "SheYinFuKaiJianShang", -- 不諧射線   
    [386201]  = "JingBao", -- 腐化法力
    [391977]  = "NiBeiYiShang", -- 載震超爆動猛湧烈
    -- [388544]  = "NiBeiYiShang", -- 腐哀擊摧樹撼裂震
    [376760]  = "NiBeiQiangHua", -- 力怒之撕風疾狂破
    [389007]  = "JingBao", -- 量掠能蝕蠻碎野裂
    [1260643] = "KuaiKaiJianShang", -- 擊瞬射閃幕影彈掠
    -- [1260709] = "YiSuJiangDi", -- 刺腐釘枯枝死邪蝕
    [1249478] = "KuaiCaiXianJing", -- 撲裂飛掠肉碎腐蝕
    [1243752] = "JingBao", -- 覆冰    
    [1251775] = "MuBiaoShiNi", -- 終極追殺
    [1251813] = "SanErYiAnQuanAnQuan", -- 懼怨恐孽繞蝕縈寂
    [1266706] = "NiBeiYiShang", -- 骸魂殘滅繞寂縈怨
    [1251833] = "JingBao", -- 靈魂腐爛    
    [1252675] = "JiHeFangTuTengJiaSuKuaiPao", -- 粉碎靈魂
    [1252777] = "TuTengLaNi", -- 靈魂束縛
    [1252816] = "JingBao", -- 死亡戰栗
    [1253779] = "JingBao", -- 零枯凋劫魂哀幽腐
    [1254175] = "BieZhuangLingHun", -- 喊寂哭怨的劫者腐亡寂
    [1254043] = "JingBao", -- 苦腐痛寂的劫恆哀永腐 
    -- [466559]  = "TieBianFangShuiSanMiaoSanErYi", -- 流陰騰陽熾冷焰熱
    [470212]  = "CaiDaoXuanFeng", -- 卷笑龍哭燃怒熾愁
    [472118]  = "JingBao", -- 點燃余燼    
    [474129]  = "TieBianFangShuiYiMiaoSanErYi", -- 吐碗噴鍋濺勺飛鏟
    [472777]  = "JingBao", -- 濺桌噴椅稠咒黏死
    [472793]  = "MiaoZhunNvYao", -- 拽筆拖墨力紙猛硯
    [474075]  = "MeiYouGouDao", -- 砍燈劈表力走猛停
    [1283247] = "PaoKaiRenQunKuaiKaiJianShang", -- 躍草跳花情燈無碗
    [470966]  = "BossZhuiNiLiuMiaoSanErYiAnQuan", -- 暴桌風椅刃筆劍墨
    [468924]  = "KuaiDuoKai", -- 暴傘風雨刃雲劍電
    [1253054] = "AnQuanAnQuan", -- 吼獄怒淵膽冥破幽
    [1253030] = "MeiYouChongHe", -- 吼獄怒淵膽冥破幽
    [472662]  = "NiBeiYiShang", -- 斬疾風掠暴破瞬影
    [1253979] = "ZhuYiXiaoShuiSanMiaoKuaiKaiJianShang", -- 擊穿射裂風瞬勁影
    [1282911] = "MuBiaoShiNi", -- 飛矢烈風
    [474528]  = "XiaoXinJiTui", -- 飛矢烈風    
    [468442]  = "ZhuYiZiBao", -- 翻騰之風
    [1282955] = "JingBao", -- 風暴靈魂之泉
    [1251772] = "JiaoChaDianXiaoLianXian", -- 能激充旋流脈回震
    [1251785] = "JiaoChaDianXiaoLianXian", -- 能湧充裂流爆回震
    [1264042] = "JingBao", -- 溢杯噴響術紙奧束
    [1251626] = "KuaiDuoKai", -- 列燈陣表網走魔縛
    [1252828] = "NiBeiYiShang", -- 裂痛創碎空殼虛魂
    [1249020] = "ShiMaFenSanSiMiaoKuaiKaiJianShang", -- 伐書步畫光筆蝕墨
    -- [1271433] = "NiBeiQiangHua", -- 斑強耀光痕電光神
    [1255310] = "JingBao", -- 光耀之痕
    [1271956] = "ZhuYiZiBao", -- 裂震撕閃像影鏡瞬
    [1247975] = "NiBeiQiangHua", -- 斑強耀光痕電光神  
    [1265984] = "BieZhanTouQian", -- 斑強耀光痕電光神  
    [1214089] = "JingBao", -- 渣亂殘廢術破奧滅
    [1214038] = "NiBeiDingShen", -- 鎖苦枷酸靈甜虛辣
    [1243905] = "KuaiKaiJianShang", -- 不穩定的能量
    [1225792] = "WuMaFenSan", -- 符文印記
    [1225015] = "JingBao", -- 鎮壓力場
    [1246446] = "SanErYiAnQuan", -- 噬空反寂無滅虛湧
    [1225205] = "MeiJinZhaoZi", -- 潮碎浪退默嘯靜湧
    [1224104] = "JingBao", -- 虛空分泌物
    [1284958] = "ZhuYiZiBao", -- 擊星刺塵宇界寰幻
    [1253709] = "KaoJinShuiMu", -- 結絡接感經控神纏
    [1224299] = "MuBiaoShiNiWuMiaoSanErYi", -- 星界束縛
    [1224401] = "KuaiDuoKai", -- 宇宙輻射
    [1284627] = "TieBianQuSan", -- 片燈裂碎影牆幽魂
    [1284633] = "JingBao", -- 液桌腐咒河椅冥死
    [1269631] = "YiSuJiangDi", -- 珠鞋寶帽能襪熵衣
    [1215161] = "MeiYouJieQuan", -- 滅勺毀桶空鍋虛鏟

    -- 元首阿福扎恩
    [1275059] = "JiSuJiangDi", -- 黑色瘴氣
    [1280075] = "KuaiKaiJianShang", -- 徘徊黑暗
    [1284786] = "JingBao", -- 暗影方陣
    -- [1265540] = "", -- 黑化創傷
    [1283069] = "XiaoGuaiDingNi", -- 虛弱
    [1255680] = "KuaiKaiJianShang", -- 啃噬虛空
    -- [1249265] = "QuanZhuDaGuai", -- 幽影坍縮
    [1280023] = "KuaiJinZhaoZi", -- 虛空標記
    [1260981] = "JingBao", -- 無盡行軍

    -- 弗拉希烏斯
    [1259186] = "NiBeiYiShang", -- 氣泡爆裂
    [1272527] = "YiSuJiangDi", -- 爬行噴吐
    [1243270] = "JingBao", -- 黑暗黏液
    [1241844] = "NiBeiYiShang", -- 碾碎
    [1254113] = "XiaoGuaiDingNi", -- 鎖定

    -- 隕落之王薩哈達爾
    [1250828] = "JingBao", -- 虛空暴露
    [1245960] = "ShouLingQiangHua", -- 虛空灌輸
    -- [1250991] = "ZhuYiZiBao", -- 晦暗侵蝕
    [1245592] = "JingBao", -- 痛苦精粹
    [1251213] = "JingBao", -- 暮光尖峰
    [1248697] = "TieBianFangShui", -- 專制命令
    -- [1248709] = "ZhuYiZiBao", -- 壓抑黑暗
    -- [1250686] = "", -- 扭曲遮蔽
    [1260030] = "JingBao", -- 本影迸流
    [1253024] = "YuanLiRenQun", -- 粉碎暮光
    [1268992] = "YuanLiRenQunYiMiao", -- 粉碎暮光
    -- 威厄高爾和艾佐拉克
    [1244672] = "LaDuanLianXian", -- 虛界
    -- [1252157] = "ZhuYiZiBao", -- 虛界 
    [1264467] = "ZhuYiZiBao", -- 龍尾掃擊
    -- [1245554] = "ZhuYiZiBao", -- 陰霾觸摸
    -- [1270852] = "NiBeiYiShang", -- 削弱
    -- [1245175] = "ZhuYiZiBao", -- 虛空箭
    -- [1265152] = "ZhuYiZiBao", -- 穿刺
    -- [1255763] = "", -- 午夜化身
    -- [1262656] = "ZhuYiZiBao", -- 虛無光束
    [1255612] = "MuBiaoShiNi", -- 亡者吐息
    -- [1255979] = "KongJu", -- 亡者吐息
    [1245421] = "JingBao", -- 陰霾區域
    -- [1245059] = "", -- 虛空嚎叫
    -- [1248865] = "ZhuanHuoDaGuai", -- 輻光屏障
    [1270497] = "PaoKaiRenQun", -- 暗影印記

    -- 光盲先鋒軍
    [1276982] = "JingBao", -- 神聖奉獻
    [1272324] = "ZhuYiZiBao", -- 神恩風暴
    -- [1246736] = "NiBeiYiShang", -- 審判
    -- [1251857] = "NiBeiYiShang", -- 審判
    [1249130] = "ZhuYiZiBao", -- 雷像衝鋒
    [1258514] = "ZhuYiZiBao", -- 盲目之光
    -- [1248985] = "", -- 處決宣判
    [1248652] = "ZhuYiZiBao", -- 聖潔鳴鐘
    -- [1246487] = "WuMaFenSan", -- 復仇者之盾
    [1246502] = "ZhuYiZiBao", -- 復仇者之盾
    [1248721] = "ZhuYiZiBao", -- 提爾之怒

    -- 奇美魯斯，未夢之神
    -- [1245698] = "XiaoGuaiKuaiDa", -- 艾林洞察
    [1262020] = "ZhuYiZiBao", -- 巨像打擊
    -- [1250953] = "ZhuYiZiBao", -- 裂隙疲弊
    -- [1253744] = "XiaoGuaiKuaiDa", -- 裂隙易傷
    [1264756] = "MuBiaoShiNi", -- 裂隙瘋狂
    [1272726] = "ZhuYiZiBao", -- 猛撕開裂
    -- [1246653] = "ZhuYiZiBao", -- 腐蝕黏痰
    [1257087] = "ZhuYiXiaoShui", -- 吞噬瘴氣
    [1265940] = "KongJu", -- 可怖戰吼
    -- 宇宙之冕
    [1233602] = "MiaoZhunDaGuai", -- 銀鋒箭
    [1242553] = "JingBao", -- 虛空殘渣
    [1233865] = "ZhuYiZiBao", -- 空無之冕
    [1243753] = "ShangHaiJiangDi", -- 暴食深淵
    [1238206] = "ZhuYiZiBao", -- 無常裂隙
    -- [1237038] = "ZhuYiZiBao", -- 虛空追獵者釘刺
    [1232470] = "TiaoZhengJiaoDu", -- 空虛之握
    [1238708] = "YiSuTiGao", -- 黑暗衝鋒
    [1283236] = "TieBianFangShui", -- 虛空斥力
    -- [1243981] = "NiBeiYiShang", -- 銀鋒彈幕射擊
    -- [1234570] = "", -- 星辰散射
    [1246462] = "ZhuYiZiBao", -- 裂隙揮砍
    [1237623] = "MiaoZhunXiaoGuai", -- 游俠隊長印記
    [1227557] = "KuaiDuoKai", -- 噬滅宇宙
    [1239111] = "LianXianDianNi", -- 終末守護
    [1255453] = "NiBeiYiShang", -- 重力坍縮

    -- 貝洛朗，奧的子嗣
    [1241292] = "MuBiaoShiNi.ogg", -- 聖光俯衝
    [1241339] = "MuBiaoShiNi.ogg", -- 虛空俯衝
    -- [1244348] = ".ogg", -- 聖光灼燒
    -- [1266404] = ".ogg", -- 虛空灼燒
    [1242803] = "JingBao.ogg", -- 聖光烈焰
    [1242815] = "JingBao.ogg", -- 虛空烈焰
    [1241840] = "JingBao.ogg", -- 聖光區域
    [1241841] = "JingBao.ogg", -- 虛空區域
    [1241992] = "MuBiaoShiNi.ogg", -- 聖光飛羽
    [1242091] = "MuBiaoShiNi.ogg", -- 虛空飛羽
    -- 至暗之夜降臨
    [1282027] = "JingBao.ogg", -- 黑暗之井
    [1249609] = "FuWenDianNi.ogg", -- 黑暗符文
    -- [1249584] = ".ogg", -- 不諧
    -- [1251789] = ".ogg", -- 宇宙裂隙
    -- [1284699] = ".ogg", -- 聖光終末
    -- [1265842] = ".ogg", -- 被刺穿
    -- [1262055] = ".ogg", -- 蝕盛
    -- [1281184] = ".ogg", -- 臨界狀態
    -- [1266113] = ".ogg", -- 執炬手
    -- [1253104] = ".ogg", -- 黎明光障
    -- [1282470] = ".ogg", -- 黑暗類星體
    -- [1284984] = ".ogg", -- 黯滅協奏
    -- [1253031] = ".ogg", -- 閃爍
    [1279512] = "SheXianDianNi.ogg", -- 星辰裂片
    [1285510] = "SheXianDianNi.ogg", -- 星辰裂片
    -- [1282016] = ".ogg", -- 湮滅之虹
    [1284527] = "MiaoZhunHeiQiu.ogg", -- 充電
    -- [1284531] = ".ogg", -- 凋零
    [1263514] = "JingBao.ogg", -- 至暗之夜
    -- [1275429] = ".ogg", -- 斷離
    -- [1266946] = ".ogg", -- 斷離

}

local LocationWarningAlerts = {
    -- [184]  = "WuMaFenSanWuMiaoZhuYiJiaoXia.ogg", 
    [601]  = { file = "XiaoXinJiTui.ogg", duration = 2.7 },
    [602]  = { file = "XiaoXinJiTui.ogg", duration = 2.7 },
    [2501] = "ZhuYiJiuRen.ogg", 
}

local LocationCastData = {
    ["暸望台"] = {
        { file = "KongDuanDaGuai.ogg" }
    },
    ["阿爾蓋薩學院"] = {
        { 
            file = { "MeiYouYinPin.ogg", "MeiYouYinPin.ogg", "DuoKaiDaQuan.ogg", "MeiYouYinPin.ogg", "MeiYouYinPin.ogg" }, 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2098
        },
    },
    ["秘法圖書室"] = {
        { 
            file = { "ZhunBeiAOE.ogg", "JinZhanDaQuan.ogg", "DaDuanDaGuai.ogg" }, 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2515 
        },
    },
    ["回音大橋"] = {
        { 
            file = "JinZhanXuanFeng.ogg", 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2501
        },
    },
    ["亡靈悲悼"] = {
        {
            file = "TanKeDaiWei.ogg", 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2492 
        },
    },
    -- ["神秘地瓜的要塞"] = {
    --     { file = "TanKeDaiWei.ogg", unitLevel = 42, mapID = 581 },
    --     { 
    --         file = { "ZhuYiSheXian.ogg", "TingZhiShiFa.ogg" }, 
    --         unitLevel = 42, 
    --         mapID = 582 
    --     },
    -- },
}

local LocationChannelData = {
    -- ["凡蕾莎之憩"] = {
    --     { 
    --         file = "KongDuanLongYing.ogg",
    --         unitLevel = PLAYER_LEVEL, 
    --         mapID = { 2493, 2494 }
    --     },
    -- },
    ["希瓦娜斯閨房"] = {
        { 
            file = { "HuDunKuaiDa.ogg", "DaDuanNvYao.ogg" }, 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = { 2496, 2497 }
        },
    },
    ["亡靈悲悼"] = {
        {
            file = "ZhunBeiAOE.ogg", 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2492 
        },
    },
    ["回音大橋"] = {
        { 
            file = "BeiMianKuaiDa.ogg", 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2501
        },
    },
    [""] = {
        { 
            file = "LiangMiaoZhuYiDuoQuan.ogg", 
            unitLevel = NEXT_PLAYER_LEVEL, 
            mapID = 2501
        },
    },
}

local EventSoundData = {  
    -- 熔爐之主加弗斯特
    [147] = {"KuaiZhaoYanTi.ogg", 1}, -- 冰川過載
    -- 阿拉卡納斯
    [302] = {"ZhuYiTouQian.ogg", 1, {TANK = true}}, -- 灼熱重擊
    [303] = {"XiaoGuaiJiHuo.ogg", 1}, -- 充能
    [304] = {"ZhunBeiAOE.ogg", 1}, -- 超級新星
    -- 魯克蘭
    [603] = {"XiaoGuaiFuHuo.ogg", 0}, -- 榮耀烈焰 (1283787)
    -- 高階賢者維裡克斯
    -- [309] = {".ogg", 1}, -- 灼燒射線 (1253538)
    [310] = {"ZhunBeiJiuRen.ogg", 1}, -- 扔下 (1253998)
    -- [311] = {".ogg", 1}, -- 日光衝擊 (154396)
    -- [312] = {".ogg", 1}, -- 眩光 (1253840)
    -- 學院
    -- 茂林古樹
    [282] = {"TanKeJianCi.ogg", 1, {TANK = true, HEALER = true}}, -- 裂樹擊 (388544)
    [283] = {"ZhunBeiDaGuaiErDianWuMiaoZhuanHuoDaGuai.ogg", 1, {TANK = true, DAMAGER = true}}, -- 分枝 (388567)
    [284] = {"ZhuYiJiaoXia.ogg", 1}, -- 發芽 (388796)
    [285] = {"ZhunBeiAOE.ogg", 1}, -- 爆發蘇醒 (388923)
    -- [293] = {".ogg", 1}, -- 奧術飛彈 (373325)
    -- [294] = {".ogg", 1}, -- 星界衝擊 (1282251)
    [295] = {"TieBianFangShui.ogg", 0}, -- 能量炸彈 (374341)
    -- [296] = {".ogg", 1}, -- 力量真空 (388820)
    -- 晉升者祖拉爾
    [223] = {"DuoKaiZhengMian.ogg", 1}, -- 虛空之掌 (1268916)
    [224] = {"ZhunBeiTiaoRen.ogg", 1}, -- 殘殺 (1263282)
    [225] = {"ZhunBeiAOE.ogg", 1}, -- 滲漏猛擊 (1263399)
    [226] = {"SiMiaoTanKeJianShang.ogg", 2, {TANK = true, HEALER = true}}, -- 虛空揮砍 (1263440)
    -- [238] = {"XiaoXinJiTui.ogg", 1}, -- 崩解虛空 (1263304)
    -- 薩普瑞什
    [234] = {"ZhuYiDuoQuan.ogg", 1}, -- 虛空炸彈 (247175)
    -- [235] = {".ogg", 1}, -- 相位衝鋒 (1263509)
    [236] = {"DaDuanDuTiao.ogg", 0, {DAMAGER = true, TANK = true}}, -- 恐懼尖嘯 (248831)
    [237] = {"DanShuaLiuXue.ogg", 1, {HEALER = true}}, -- 暗影突襲 (245738)
    -- [243] = {".ogg", 1}, -- 過載 (1263523)
    -- 總督奈扎爾
    [244] = {"DaDuanDuTiao.ogg", 1, {DAMAGER = true, TANK = true}}, -- 心靈震爆 (244750)
    [246] = {"ZhunBeiXiaoGuai.ogg", 1}, -- 暗影觸須 (1263538)
    -- 魯拉    
    [249] = {"ZhunBeiAOE.ogg", 1}, -- 絕望哀歌    
    [250] = {"ZhunBeiDianMingLiangMiaoSanErYi.ogg", 2}, -- 不諧射線
    [251] = {"ZhuYiSheXian.ogg", 1}, -- 裂解
    [252] = {"DuoKaiDaQuan.ogg", 1}, -- 幽冥和音
    [253] = {"ZhunBeiYiShangShiMiaoYiShangJieDuan.ogg", 1}, -- 永夜交響曲
    [254] = {"ZhunBeiJiTuiLiangMiaoSanErYi.ogg", 2}, -- 反衝    
    -- [247] = {".ogg", 1}, -- 驅逐 (1263528)
    [376] = {"ZhunBeiDuoQiuSiMiaoZhuYiDuoQiu.ogg", 1}, -- 深淵之門 (1277358)
    [245] = {"ZhuYiDanShua.ogg", 1, {HEALER = true}}, -- 群體虛空灌輸 (1263542)
    -- 燼曉
    [239] = {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}}, -- 熾熱尖喙
    [241] = {"ZhunBeiDianMing.ogg", 1}, -- 熾焰騰流
    [242] = {"WuMiaoZhunBeiChuiFengSanMiaoNiShiZhenTouQian.ogg", 2}, -- 燃燒烈風          
    -- 被遺棄的二人組
    [25]  = {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}}, -- 碎骨猛砍  
    [26]  = {"GuiHunDianNiSanErYi.ogg", 0}, -- 黑暗詛咒    
    [27]  = {"ZhunBeiDianMing.ogg", 2}, -- 衰弱尖嘯         
    -- 指揮官克羅魯科
    [210] = {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}}, -- 暴怒
    [211] = {"ZiQuanChongHeLiangMiaoSanErYi.ogg", 1}, -- 破膽怒吼
    [212] = {"SanMiaoZhuYiDuoQuan.ogg", 1}, -- 無情跳躍
    -- [213] = {"ZiQuanChongHeLiangMiaoSanErYi.ogg", 1}, -- 破膽怒吼
    [214] = {"SanMiaoZhuYiDuoQuan.ogg", 1}, -- 無情跳躍
    [215] = {"ZhunBeiAOE.ogg", 0}, -- 集結怒吼
    -- 無眠之心
    [21]  = {"ZhunBeiAOELiangMiaoSanErYi.ogg", 2}, -- 疾風狙擊
    [22]  = {"ZhunBeiJianYu.ogg", 2}, -- 飛矢烈風
    [23]  = {"ZhuYiDuoQuanWuMiaoCaiQuanXiaoCeng.ogg", 1}, -- 矢如雨下
    [24]  = {"TanKeJiTui.ogg", 1, {TANK = true, HEALER = true}}, -- 暴風斬    
    -- 核技工程長卡斯雷瑟   
    [108] = {"ZhuYiSheXian.ogg", 1}, -- 魔網陣列 (1251183)
    -- [106] = {".ogg", 1}, -- 核閃引爆 (1257512)
    -- [107] = {"JiaoChaDianXiaoLianXian.ogg", 0}, -- 回流充能 (1251767)
    [172] = {"ZhuYiJiaoXia.ogg", 1}, -- 能量坍縮 (1264048)
    -- 核心守衛奈薩拉 
    [36]  = {"ZhunBeiXiaoGuaiLiuMiaoXiaoGuaiJiHuo.ogg", 1}, -- 空無先鋒
    [35]  = {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}}, -- 幽影鞭笞   
    [34]  = {"ZhunBeiYiShangJiuMiaoKuaiJinShengGuang.ogg", 0}, -- 光痕耀斑
    -- [33]  = {"ZhunBeiDianMing.ogg", 2}, -- 蝕光步伐    
    -- 洛薩克森
    [109] = {"BaMaFenSanSiMiaoZhuYiDuoQuan.ogg", 1}, -- 輝熠消散
    [110] = {"ZhunBeiJiTuiSiDianWuMiaoSanErYiDaDuanGuangTou.ogg", 1}, -- 神聖詭計
    [111] = {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}}, -- 灼熱撕裂
    [112] = {"DuoKaiChongFeng.ogg", 1}, -- 閃爍   
    -- 吉美爾魯斯
    [635] = {"SanChongFuZhi.ogg", 0}, -- 三重復制
    [97]  = {"ZhunBeiDianMing.ogg", 1}, -- 神經鏈接
    [98]  = {"ZhunBeiLaRen.ogg", 0}, -- 星界束縛
    [100] = {"DianMingFangShui.ogg", 1}, -- 寰宇刺擊
    -- 姆羅金和內克拉克斯
    [150] = {"TanKeLiuXue.ogg", 1, {TANK = true, HEALER = true}}, -- 長矛側攻
    [151] = {"ZhuYiDuoQuan.ogg", 1}, -- 惡臭羽毛風暴
    [152] = {"DuoKaiXianJing.ogg", 1}, -- 冰凍陷阱
    [153] = {"ZhunBeiJianYu.ogg", 2}, -- 彈幕射擊    
    [154] = {"ZhunBeiJiBing.ogg", 1, {HEALER = true}}, -- 感染羽翼
    [155] = {"ZhunBeiDianMing.ogg", 2}, -- 感染羽翼    
    -- 沃達扎    
    [16]  = {"TanKeChengShang.ogg", 1, {TANK = true, HEALER = true}}, -- 吸取靈魂
    [17]  = {"DuoKaiTouQian.ogg", 1}, -- 寂滅
    [19]  = {"ZhunBeiDianMing.ogg", 1}, -- 束縛幻影
    [20]  = {"WuMiaoZhunBeiPoDunSanMiaoKuaiKaiJianShangShiErMiaoZhuYiDuoQiu.ogg", 2}, -- 死疽融合
    -- 奧能金剛庫斯托斯
    -- [281] = {".ogg", 1}, -- 補給協議 (474345)
    -- [286] = {".ogg", 1}, -- 震退猛擊 (474496)
    -- [287] = {".ogg", 1}, -- 虛靈枷鎖 (1214032)
    [288] = {"XiaoXinJiTui.ogg", 1}, -- 奧術驅除 (1214081)
    -- 瑟拉奈爾·日鞭
    [94]  = {"ShouLingQiangHua.ogg", 1}, -- 加速結界
    [96]  = {"ZhunBeiJinZhaoZiSanErYiJin.ogg", 1}, -- 靜默浪潮        
    -- 迪詹崔烏斯
    [420] = {"TanKeChengShangSanMiaoQuSanTanKe.ogg", 1, {TANK = true, HEALER = true}}, -- 龐大碎片  
    [292] = {"ZhunBeiJieQuan.ogg", 1}, -- 不穩定的虛空精華
    [290] = {"ShiErMiaoDuoQiuShiWuMiaoDuoQiuShiBaMiaoDuoQiu.ogg", 1}, -- 貪噬之熵   

    -- 元首阿福扎恩
    [194] = {"ZhaoHuanDaGuai.ogg", 1}, -- [暗影進軍] (1262776)
    [195] = {"ZhaoHuanDaGuai.ogg", 1}, -- [暗影進軍] (1251361)
    [198] = {"DuoBiBiaoQiang.ogg", 1}, -- [湮滅之怒] (1260712)
    [197] = {"FenTanShangHaiQiMiaoFenTanShangHaiZhuanHuoDaGuai.ogg", 1}, -- [幽影坍縮] (1249265)
    [200] = {"ShouLingKuangBao.ogg", 0}, -- [無盡行軍] (1251583)
    -- [201] = {".ogg", 1}, -- [濃暗壁壘] (1255702)    
    -- [492] = {".ogg", 1}, -- [虛弱] (1283069)
    [419] = {"ZhunBeiDianMing.ogg", 1, {DAMAGER = true, HEALER = true}}, -- [虛空標記] (1280015)
    [196] = {"ZhunBeiAOE.ogg", 1, {HEALER = true}}, -- [黑暗顛覆] (1249251)

    -- 弗拉希烏斯
    [133] = {"ZhunBeiJiTuiLiangMiaoSanErYi.ogg", 1}, -- [始源咆哮] (1260046)
    [59]  = {"TanKeChengShangSanErYiShiMiaoTanKeChengShangSanErYi.ogg", 1}, -- [影爪重擊] (1241836)
    [60]  = {"TanKeChengShangSanErYiShiMiaoTanKeChengShangSanErYi.ogg", 1}, -- [影爪重擊] (1244293)
    [62]  = {"ZhuYiJiaoXia.ogg", 1}, -- [散逸寄生蟲] (1254199)
    [61]  = {"ZhunBeiJiGuang.ogg", 0}, -- [虛空吐息] (1243853)

    -- 隕落之王薩哈達爾
    -- [140] = {"ZhunBeiDianMing.ogg", 1}, -- 專制命令 (1260823)
    [143] = {"HuanJingShangHai.ogg", 1, {HEALER = true}}, -- 扭曲遮蔽 (1250686)
    [148] = {"YiShangJieDuan.ogg", 1}, -- 熵能瓦解 (1246175)
    [141] = {"KongDuanDaGuai.ogg", 1, {DAMAGER = true, TANK = true}}, -- 破碎投影 (1254081)
    [142] = {"ZhunBeiDiCi.ogg", 1}, -- 粉碎暮光 (1253911)
    [139] = {"ZhaoHuanXiaoGuai.ogg", 1, {DAMAGER = true, TANK = true}}, -- 虛空融合 (1243453)

    -- 威厄高爾和艾佐拉克
    [103] = {"CengQiu.ogg", 1}, -- 陰霾 (1245391)
    [104] = {"KongJuTuXi.ogg", 1}, -- 亡者吐息 (1244221)
    [105] = {"ZhuanHuoDaGuai.ogg", 1}, -- 午夜烈焰 (1249748)
    -- [221] = {"TanKeChengShang.ogg", 1, TANK = true}, -- 威厄之翼 (1265131)
    -- [220] = {"TanKeChengShang.ogg", 1, TANK = true}, -- 拉克獠牙 (1245645)
    -- [551] = {".ogg", 1}, -- 穿刺 (435193)
    -- [101] = {"TanKeTuXi.ogg", 1}, -- 虛無光束 (1262623)
    [102] = {"WuMaFenSan.ogg", 1}, -- 虛空嚎叫 (1244917)
    [381] = {"KaoJinZhongChang.ogg", 1}, -- 輻光屏障 (1248847)


    -- 光盲先鋒軍
    [74]  = {"ZhunBeiPoDun.ogg", 1, {DAMAGER = true}}, -- 聖潔護盾 (1248674)
    [80]  = {"ZhunBeiDuoFeiDun.ogg", 1, {DAMAGER = true, HEALER = true}}, -- 聖潔鳴鐘 (1248644)
    [85]  = {"FenTanShangHai.ogg", 1}, -- 處決宣判 (1276368)
    [79]  = {"BaMaFenSan.ogg", 1, {DAMAGER = true, HEALER = true}}, -- 復仇者之盾 (1246485)
    [365] = {"BaMaFenSan.ogg", 1, {DAMAGER = true, HEALER = true}}, -- 復仇者之盾 (1276635)
    [78]  = {"ZhuYiHuanTan.ogg", 1, {TANK = true}}, -- 審判 (1251857)
    [82]  = {"ZhuYiHuanTan.ogg", 1, {TANK = true}}, -- 審判 (1246736)
    [75]  = {"ZhunBeiShuaDun.ogg", 1, {HEALER = true}}, -- 提爾之怒 (1276831)
    [77]  = {"ZhunBeiAOE.ogg", 1, {HEALER = true}}, -- 灼熱光輝 (1255738)
    [373] = {"ZhunBeiAOE.ogg", 1, {HEALER = true}}, -- 灼熱光輝 (1276639)
    -- [358] = {".ogg", 1}, -- 狂熱之魂 (1272380)
    -- [359] = {".ogg", 1}, -- 狂熱之魂 (1272423)
    -- [360] = {".ogg", 1}, -- 狂熱之魂 (1272425)
    -- [535] = {".ogg", 1}, -- 盲目之光 (428169)
    -- [83] = {".ogg", 1}, -- 神聖風暴 (1246765)
    -- [374] = {".ogg", 1}, -- 神聖風暴 (1272310)
    [84]  = {"ZhunBeiAOE.ogg", 1, {HEALER = true}}, -- 神聖鳴罪 (1246749)
    -- [76]  = {"DuoKaiDaQuan.ogg", 1}, -- 虔誠光環 (1246162)    
    -- [71]  = {"DuoKaiDaQuan.ogg", 1}, -- 平心光環 (1248451)
    -- [81]  = {"DuoKaiDaQuan.ogg", 1}, -- 憤怒光環 (1248449)
    [73]  = {"DuoKaiChongFeng.ogg", 1, {DAMAGER = true, HEALER = true}}, -- 雷像衝鋒 (1249130)

    -- 奇美魯斯，未夢之神
    [118] = {"ZhunBeiAOE.ogg", 1, {HEALER = true}}, -- 不諧咆哮 (1249207)
    [117] = {"DaDuanDuTiao.ogg", 1, {DAMAGER = true, TANK = true}}, -- 可怖戰吼 (1249017)
    [307] = {"ZhunBeiAOE.ogg", 1}, -- 吞噬 (1245396)
    [119] = {"ZhunBeiQuSan.ogg", 1, {HEALER = true}}, -- 吞噬瘴氣 (1257085)
    [51]  = {"DuoKaiTouQian.ogg", 1}, -- 猛撕開裂 (1272726)
    [53]  = {"ZhunBeiTuXi.ogg", 1}, -- 腐化毀滅 (1245452)
    [458] = {"ZhunBeiTuXi.ogg", 1}, -- 腐化毀滅 (1282856)
    [50]  = {"ZhunBeiAOE.ogg", 1, {HEALER = true}}, -- 腐蝕黏痰 (1246621)
    [149] = {"FenTanShangHai.ogg", 1}, -- 艾林之塵劇變 (1262289)
    [431] = {"FenTanShangHai.ogg", 1}, -- 艾林之塵劇變 (1282001)
    [555] = {"ShouLingQiangHua.ogg", 1}, -- 被吞噬的精華 (1245844)
    [49]  = {"ZhunBeiNeiChang.ogg", 1}, -- 裂隙湧現 (1251021)
    [217] = {"ZhunBeiJiuRen.ogg", 1}, -- 裂隙瘋狂 (1268905)
    [48]  = {"ZhunBeiJiFei.ogg", 0}, -- 貪食俯衝 (1245404)

    -- 宇宙之冕
    [15]  = {"ChangDiQieHuan.ogg", 1}, -- 噬滅宇宙 (1238843)
    [8]   = {"ZhuYiDuoQuan.ogg", 1}, -- 奇點噴發 (1235622)
    [12]  = {"ZhunBeiDaDun.ogg", 0, {DAMAGER = true, HEALER = true}}, -- 宇宙屏障 (1246918)
    [66]  = {"ZhunBeiChenMo.ogg", 1, {DAMAGER = true, HEALER = true}}, -- 干擾震蕩 (1243743)
    [65]  = {"JinZhanDaQuan.ogg", 1, {DAMAGER = true}}, -- 暴食深淵 (1243753)
    [11]  = {"ZhunBeiYinFengJian.ogg", 1}, -- 游俠隊長印記 (1237614)
    [131] = {"ZhunBeiYinFengJian.ogg", 1}, -- 游俠隊長印記 (1260010)
    -- [4]   = {"ZhuYiDanShua.ogg", 1, {HEALER = true}}, -- 空無之冕 (1233865)
    [14]  = {"DuoBiBiaoQiang.ogg", 1}, -- 空虛之握 (1232467)
    [132] = {"DuoBiBiaoQiang.ogg", 1}, -- 空虛之握 (1260026)
    [13]  = {"ZhunBeiLaXian.ogg", 1}, -- 終末守護 (1239080)
    [10]  = {"ZhunBeiXiaoGuai.ogg", 1, {DAMAGER = true}}, -- 虛空召喚 (1237837)
    [5]   = {"HeiQiuChuXianDanQiuZhunBeiSanErYiShuangQiuZhunBeiSanErYi.ogg", 1, {HEALER = true}}, -- 虛空斥力 (1233819)
    -- [9]   = {".ogg", 1, HEALER = true}, -- 虛空追獵者釘刺 (1237035)
    [137] = {"TanKeChengShang.ogg", 1, {TANK = true}}, -- 裂隙揮砍 (1246461)
    [7]   = {"SheXian.ogg", 1}, -- 銀鋒彈幕射擊 (1234564)    
    [64]  = {"TanKeJiTui.ogg", 1, {TANK = true}}, -- 黑暗之手 (1233787)

    -- 貝洛朗，奧的子嗣
    [130] = {"ZhunBeiBaoZhu.ogg", 1}, -- 光耀回響 (1242981)
    [494] = {"FenTanShangHai.ogg", 0}, -- 聖光俯衝 (1241292)
    [482] = {"NiShiHuangSe.ogg", 0}, -- 聖光羽毛 (1241162)
    [384] = {"MuBiaoShiNi.ogg", 0}, -- 聖光飛羽 (1241992)
    [497] = {"JieDuanZhuanHuan.ogg", 1}, -- 復生 (1241313)
    [134] = {"TanKeLianJi.ogg", 1, {TANK = true}}, -- 守護者敕令 (1260763)
    [272] = {"ZhunBeiJiFei.ogg", 2}, -- 死亡墜落 (1246709)
    [138] = {"ZhuYiDanShua.ogg", 1, {HEALER = true}}, -- 永恆灼燒 (1244344)
    -- [161] = {"ZhuYiSheXian.ogg", 1, {DAMAGER = true, HEALER = true}}, -- 注能飛羽 (1242260)
    -- [273] = {".ogg", 1}, -- 烈焰孵化 (1242792)
    [218] = {"ZhunBeiAOELiangMiaoSanErYi.ogg", 2}, -- 虛光彙流 (1242515)
    [495] = {"FenTanShangHai.ogg", 0}, -- 虛空俯衝 (1241339)
    [483] = {"NiShiLanSe.ogg", 0}, -- 虛空羽毛 (1241163)
    [385] = {"MuBiaoShiNi.ogg", 0}, -- 虛空飛羽 (1242091)
    [128] = {"FenTanShangHai.ogg", 1}, -- 貝洛朗的燃燼 (1241282)

    -- 至暗之夜降臨    
    [632] = {"MiaoZhunHeiQiu.ogg", 0}, -- 充電 (1284525)
    [259] = {"JieDuanZhuanHuan.ogg", 1}, -- 全蝕 (1261871)
    [261] = {"XiHeiQiu.ogg", 1}, -- 聖光虹吸 (1266897)
    [364] = {"TanKeChengShang.ogg", 1, {TANK = true}}, -- 天穹之槍 (1267049)
    [256] = {"DuoKaiZhanRen.ogg", 1}, -- 天穹戰刃 (1253915)
    [257] = {"ZhunBeiHuWeiDaDuanHuWeiZhuanHuoShuiJing.ogg", 1}, -- 護衛棱鏡 (1251386)
    -- [434] = {".ogg", 1}, -- 宇宙裂變 (1282249)
    -- [363] = {".ogg", 1}, -- 斷離 (1276202)
    [437] = {"SheXianDianNi.ogg", 0}, -- 星辰裂片 (1282441)
    [435] = {"DuoKaiLianXian.ogg", 1}, -- 核心收割 (1282412)
    -- [362] = {".ogg", 1}, -- 死亡安魂曲 (1273158)    
    [255] = {"FuWenDianNi.ogg", 0}, -- 死亡挽歌 (1244412)
    [433] = {"JieDuanZhuanHuan.ogg", 1}, -- 深入黑暗之井 (1282047)
    -- [258] = {".ogg", 1}, -- 破碎天空 (1249796)
    -- [636] = {".ogg", 1}, -- 終結棱柱 (1284931)
    -- [260] = {".ogg", 1}, -- 至暗之夜 (1266622)
    -- [405] = {".ogg", 1}, -- 蝕盛 (1237690)
    [263] = {"KuaiJinZhaoZiQiMiaoKuaiPao.ogg", 1}, -- 黑暗天使長 (1250898)
    -- [262] = {"DuoKaiXingZuo.ogg", 1}, -- 黑暗星座 (1266388)
    [436] = {"JieDuanZhuanHuan.ogg", 1}, -- 黑暗熔毀 (1281194)
    -- [650] = {"FuWenDianNi.ogg", 0}, -- 黑暗符文 (1249609)
    [649] = {"ZhuYiSheXian.ogg", 1}, -- 黑暗類星體 (1279420)
    -- [644] = {".ogg", 1}, -- 黯滅協奏 (1284980)
}
local EventSoundData2 = {  
    -- 被遺棄的二人組
    [26]  = {"ZhunBeiZuZhouLiangMiao.ogg", 2}, -- 黑暗詛咒    
    -- 燼曉
    [241] = {"TieBianFangShuiSanMiaoSanErYi.ogg", 0}, -- 熾焰騰流    
    -- 元首阿福扎恩 
    [199] = {"ZhunBeiJiTuiShiYiMiaoZhuYiDuoQuan.ogg", 2}, -- [虛空墜落] (1258880)
    [209] = {"ZhunBeiJiTuiShiYiMiaoZhuYiDuoQuan.ogg", 2}, -- [虛空墜落] (1266786)
    -- 弗拉希烏斯
    [62]  = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 散逸寄生蟲 (1254199)
    -- 隕落之王薩哈達爾
    [148] = {"ZhunBeiYiShang.ogg", 2}, -- 熵能瓦解 (1246175)
    -- 威厄高爾和艾佐拉克
    [102] = {"ZhunBeiXiaoGuai.ogg", 2}, -- 虛空嚎叫 (1244917)    
    [103] = {"ZhunBeiCengQiuSanErYi.ogg", 2}, -- 陰霾 (1245391)
    [104] = {"ZhunBeiKongJuLiangMiaoSanErYi.ogg", 2}, -- 亡者吐息 (1244221)
    -- 光盲先鋒軍
    [78]  = {"ZhunBeiShenPanSanErYi.ogg", 2, {TANK = true}}, -- 審判 (1251857)
    [82]  = {"ZhunBeiShenPanSanErYi.ogg", 2, {TANK = true}}, -- 審判 (1246736)
    [84]  = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 神聖鳴罪 (1246749)     
    [76]  = {"TanKeDaiWei.ogg", 2, {TANK = true}}, -- 虔誠光環 (1246162)
    [71]  = {"TanKeDaiWei.ogg", 2, {TANK = true}}, -- 平心光環 (1248451)
    [81]  = {"TanKeDaiWei.ogg", 2, {TANK = true}}, -- 憤怒光環 (1248449)
    -- 宇宙之冕
    [5]   = {"ZhunBeiHeiQiu.ogg", 2}, -- 虛空斥力 (1233819)
    [6]   = {"ZhunBeiYinFengJian.ogg", 2}, -- 銀鋒箭 (1233602)
    [13]  = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 終末守護 (1239080)
    -- 奇美魯斯，未夢之神
    -- [307] = {"ZhunBeiAOE.ogg", 2, {HEALER = true}}, -- 吞噬 (1245396)
    [49]  = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 裂隙湧現 (1251021)
    [119] = {"ZhunBeiDianMing.ogg", 2}, -- 吞噬瘴氣 (1257085)
    -- 至暗之夜降臨
    [255] = {"ZhunBeiFuWenLiangMiaoSanErYi.ogg", 2}, -- 死亡挽歌 (1244412)
    [632] = {"ZhunBeiSheQiu.ogg", 2}, -- 充電 (1284525)
    [435] = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 核心收割 (1282412)
    -- [632] = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 充電 (1284525)
    -- 貝洛朗，奧的子嗣
    [218] = {"ZhiLiaoYuPu.ogg", 2, {HEALER = true}}, -- 虛光彙流 (1242515)
}
local startTime = 0
local currentEncounterID = 0
local lastPlayedSecond = -1
local isAuraRegistered = false

local function RegisterPrivateAuras()
    if isAuraRegistered then return end
    if not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAppliedSound) then return end

    for spellID, soundFile in pairs(PrivateAuraList) do
        C_UnitAuras.AddPrivateAuraAppliedSound({
            unitToken = "player",
            spellID = spellID,
            soundFileName = MEDIA_PATH .. soundFile .. ".ogg", 
            outputChannel = "Master",
        })
    end
    isAuraRegistered = true    
end

-- 職責/專精 檢查函數
local function CanPlayerHear(req)
    if not req then return true end
    
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    
    local _, _, _, _, role = GetSpecializationInfo(specIndex)
    local specID = GetSpecializationInfo(specIndex)
    if type(req) == "table" then
        for _, r in ipairs(req) do
            if r == role or r == specID then return true end
        end
    -- 如果要求是字符串(職責)或數字(專精ID)
    else
        if req == role or req == specID then return true end
    end
    
    return false
end

-- 獲取當前玩家職責
local function GetPlayerRole()
    local specIndex = GetSpecialization()
    if specIndex then
        local _, _, _, _, role = GetSpecializationInfo(specIndex)
        return role
    end
    return "NONE"
end


local function ProcessAlert(alert, debugSource, actualLevel, currentMapID, unitTarget)
    if not alert then return end
    
    local reqLevel = type(alert) == "table" and alert.unitLevel or nil
    local reqMapID = type(alert) == "table" and alert.mapID or nil
    
    -- 提取文件名或表（用於打印）
    local alertFile = type(alert) == "table" and alert.file or alert
    local displayTitle = type(alertFile) == "table" and alertFile[1] or alertFile

    -- 【關鍵修改點：通用的匹配函數】
    local function CheckMatch(required, actual)
        if not required then return true end -- 如果配置沒寫，預設匹配成功
        if type(required) == "table" then
            for _, val in ipairs(required) do
                if val == actual then return true end
            end
            return false
        end
        return required == actual -- 如果是單個值，直接對比
    end
    -- 調試 1：開始檢查某條具體配置
    -- print(string.format("|cff00ffff[檢查配置]|r %s | 需要Level:%s, 需要Map:%s", displayTitle, tostring(reqLevel), tostring(reqMapID)))

    -- 使用新邏輯進行匹配
    local levelMatch = CheckMatch(reqLevel, actualLevel)
    local mapMatch = CheckMatch(reqMapID, currentMapID)

    if levelMatch and mapMatch then        
        local fileName
        if type(alertFile) == "table" then
            unitCastTracker[unitTarget] = (unitCastTracker[unitTarget] or 0) + 1
            local index = ((unitCastTracker[unitTarget] - 1) % #alertFile) + 1
            fileName = alertFile[index]
            
            -- print(string.format("|cff00ff00[循環計數]|r 次數:%d, 播放索引:%d, 文件:%s", unitCastTracker[unitTarget], index, fileName))
        else
            fileName = alertFile
        end

        if fileName and CanPlayerHear(alert.role) then
            PlaySoundFile(MEDIA_PATH .. fileName, "Master")
        end
    else
        -- 調試 3：匹配失敗的原因
        local reason = ""
        if not levelMatch then reason = reason .. "等級不對(目標" .. actualLevel .. ") " end
        if not mapMatch then reason = reason .. "地圖ID不對(目標" .. currentMapID .. ") " end
        -- print("|cffffd100[跳過條目]|r " .. displayTitle .. " | 原因: " .. reason)
    end
end

local function OnUpdate()
    if startTime == 0 then return end
    local now = GetTime()
    local elapsed = math.floor(now - startTime)
    if elapsed < 0 or elapsed == lastPlayedSecond then return end
    lastPlayedSecond = elapsed
    
    local bossData = AudioTimeline[currentEncounterID]
    if bossData then
        local relativeTime = now - startTime - bossData.startOffset
        if relativeTime >= 0 then
            local moduloTime = relativeTime % bossData.interval
            for triggerTime, alert in pairs(bossData.alerts) do
                if moduloTime >= triggerTime and moduloTime < (triggerTime + 0.8) then
                    ProcessAlert(alert, "Timeline:"..triggerTime)
                    StartMyCircleTimer(alert)
                    break 
                end
            end
        end
    end
end

local function ApplyTimelineSounds()
    local count = 0
    local playerRole = GetPlayerRole()

    local function ClearTimelineSounds(dataTable)
        if not dataTable then return end
        for eventID, config in pairs(dataTable) do
            local triggerType = config[2]
            -- 將該 ID 的聲音配置設為 nil 即為卸載
            C_EncounterEvents.SetEventSound(eventID, triggerType, nil)
        end
    end

    -- 1. 定義一個內部的處理函數
    local function registerTable(dataTable)
        if not dataTable then return end
        
        for eventID, config in pairs(dataTable) do
            local fileName = config[1]
            local triggerType = config[2]
            local roleConfig = config[3]
            
            local isMatch = false
            
            -- 過濾邏輯
            if roleConfig == nil then
                isMatch = true
            elseif type(roleConfig) == "table" then
                if roleConfig[playerRole] then
                    isMatch = true
                end
            elseif type(roleConfig) == "string" then
                if roleConfig == playerRole then
                    isMatch = true
                end
            end

            -- 執行注冊
            if isMatch then
                C_EncounterEvents.SetEventSound(eventID, triggerType, {
                    file = MEDIA_PATH .. fileName, 
                    channel = "Master", 
                    volume = 1
                })
                count = count + 1
            end
        end
    end
    -- 2. 先執行清空（重置所有 ID）
    ClearTimelineSounds(EventSoundData)
    ClearTimelineSounds(EventSoundData2)
    -- 2. 分別調用兩個表
    registerTable(EventSoundData)
    registerTable(EventSoundData2)
    -- print("已根據職責成功加載 " .. count .. " 個語音事件")
end

local function GetTopWidgetText()
    local container = UIWidgetTopCenterContainerFrame
    if not container or not container.widgetFrames then return nil end

    for _, widget in pairs(container.widgetFrames) do
        -- 截圖顯示它有一個 .Text 屬性
        if widget.Text and widget.Text:GetText() then           
            return widget.Text:GetText()
        end
    end
    return nil
end

local function GetWidgetLabelText()
    local container = UIWidgetTopCenterContainerFrame
    if not container or not container.widgetFrames then return nil end
    -- 遍歷所有掛載在該容器下的 Widget
    for _, widget in pairs(container.widgetFrames) do
        -- 針對截圖中的特殊層級：widget -> Label
        if widget.Bar.Label and widget.Bar.Label.GetText then
            local text = widget.Bar.Label:GetText()
            -- 排除空字符串，確保拿到有效文字
            if text and text:trim() ~= "" then
                return text
            end
        end
    end    
    return nil
end

-- local function FindBestVoice()
--     local ttsVoices = C_VoiceChat.GetTtsVoices()
    
--     for _, v in ipairs(ttsVoices) do
--         -- 示例：尋找中文（Huihui）或者特定風格的聲音
--         if v.name:find("Huihui") then
--             return v.voiceID
--         end
--     end
    
--     -- 如果沒找到，返回預設的第一個
--     return ttsVoices[1] and ttsVoices[1].voiceID
-- end

-- 假設在插件加載或某個觸發點執行
-- local function StartTTSInitialization()
--     MyTTSDict.isSampling = true
--     MyTTSDict.sampleIndex = 0
    
--     -- 1秒後讀第一個
--     C_Timer.After(10, function()
--         MyTTSDict.sampleIndex = 1        
--         C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "冰霜猛襲", 10, C_TTSSettings.GetSpeechVolume(), true)
--         -- C_VoiceChat.SpeakText(FindBestVoice(), "852826", 10, C_TTSSettings.GetSpeechVolume(), true)
--     end)
    
--     -- 2秒後讀第二個
--     C_Timer.After(12, function()
--         MyTTSDict.sampleIndex = 2
--         C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "黑暗裂口", 10, C_TTSSettings.GetSpeechVolume(), true)
--         -- C_VoiceChat.SpeakText(FindBestVoice(), "4667427", 10, C_TTSSettings.GetSpeechVolume(), true)
--     end)
    
--     -- 3秒後關閉采樣模式（防止後續正常使用TTS時誤觸發賦值）
--     C_Timer.After(14, function()
--         MyTTSDict.isSampling = false
--         print("TTS 技能指紋預存完成")
--     end)
-- end

-- 核心比對邏輯函數
local function ExecuteClosestLogic(measuredTime, sound1, sound2)
    local diff1 = math.abs(measuredTime - MyTTSDict.skill1Time)
    local diff2 = math.abs(measuredTime - MyTTSDict.skill2Time)
    
    if diff1 < diff2 and diff1 < MyTTSDict.tolerance and MyTTSDict.isSampled == true then
        -- print(string.format("技能 1 實際耗時: %.3f 秒", measuredTime))
        -- print("識別為：技能1 邏輯執行")
        PlaySoundFile(MEDIA_PATH .. sound1, "Master")
        -- 執行技能1邏輯
    elseif diff2 < diff1 and diff2 < MyTTSDict.tolerance and MyTTSDict.isSampled == true then
        -- print(string.format("技能 2 實際耗時: %.3f 秒", measuredTime))
        -- print("識別為：技能2 邏輯執行")
        if sound2 == "TanKeJianCi.ogg" then
            local PlayerRole = GetPlayerRole()
            if PlayerRole ~= "TANK" and PlayerRole ~= "HEALER" then
                return -- 關鍵點：非坦奶直接閉嘴，不再往下走
            end
        end
        PlaySoundFile(MEDIA_PATH .. sound2, "Master")
        -- 執行技能2邏輯
    else
        -- print("無法識別，誤差過大")
    end
end
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("ENCOUNTER_WARNING")
frame:RegisterEvent("CLEAR_BOSS_EMOTES")
frame:RegisterEvent("ENCOUNTER_WARNING")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_BLOCK_STATE_CHANGED")
frame:RegisterEvent("RAID_BOSS_EMOTE")
frame:RegisterEvent("RAID_BOSS_WHISPER")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_STARTED")
frame:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("BOSS_KILL")

-- frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID = ...
        encounterUnitTriggerCount = 0
        currentEncounterID = encounterID
        startTime = GetTime()
        lastPlayedSecond = -1
        frame:SetScript("OnUpdate", OnUpdate)
        -- 延遲 0.01 秒執行
        C_Timer.After(0.01, function()
            ApplyTimelineSounds()
        end)
        -- print("|cFF00FF00[神秘地瓜副本語音插件]|r 已加載")
    elseif event == "ENCOUNTER_END" then
        startTime = 0
        currentEncounterID = 0
        frame:SetScript("OnUpdate", nil)
        -- print("|cFF00FF00[TimelineAudio]|r 戰鬥結束")
        return

    elseif event == "BOSS_KILL" then
        local encounterID = ...
        if encounterID == 3071 then
            BOSS_KILL_3071 = true
            return
        end
        if encounterID == 3072 then
            BOSS_KILL_3072 = true
            return
        end
        if encounterID == 2065 then
            BOSS_KILL_2065 = true
            return
        end
        if encounterID == 2066 then
            BOSS_KILL_2066 = true
            return
        end
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_STARTED" then
        ttsStartTime = GetTime() -- 記錄當前精確時間
        return
    elseif event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" then
        -- ttsDuration = GetTime() - ttsStartTime
        -- print(ttsDuration)
        -- 如果開關沒開，說明這次 TTS 播放不是由我們的插件觸發的，直接攔截
        -- if not MyTTSDict.isListening then return end
        ttsDuration = GetTime() - ttsStartTime
        -- 僅在采樣模式下進行賦值
        if MyTTSDict.isSampled == false then
            if MyTTSDict.sampleIndex == 1 then
                MyTTSDict.skill1Time = ttsDuration
                -- print(string.format("技能 1 采樣完成: %.3f 秒", ttsDuration))
            elseif MyTTSDict.sampleIndex == 2 then
                MyTTSDict.skill2Time = ttsDuration
                -- print(string.format("技能 2 采樣完成: %.3f 秒", ttsDuration))
                MyTTSDict.isSampled = true
                MyTTSDict.sampleIndex = 0
                -- print("TTS 技能指紋預存完成")
            end
        else
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            local subZone = GetSubZoneText()
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if instanceID == 658 and not C_CombatAudioAlert.IsEnabled() then 
                ExecuteClosestLogic(ttsDuration, "ZhuYiDuoQuan.ogg", "TanKeJianCi.ogg")
            end
            if instanceID == 2805 and currentMapID == 2498 and subZone == "亡靈悲悼" then 
                ExecuteClosestLogic(ttsDuration, "DuoKaiChongFeng.ogg", "ZhunBeiChenMo.ogg")
            end
            if instanceID == 2526 and currentMapID == 2098 and subZone == "運動場" then 
                ExecuteClosestLogic(ttsDuration, "DuoKaiTouQian.ogg", "ZhunBeiAOE.ogg")
            end
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        wipe(unitCastTracker) 
        return
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_STOP" then
        local unitTarget = ...
        if unitTarget == "player" then
            UpdateRingColor(false)
        end
    --     -- 獲取該 unit 對應的姓名板框架
    --     local nameplate = C_NamePlate.GetNamePlateForUnit(unitTarget)
        
    --     if nameplate then
    --         -- 如果之前沒創建過文字，就創建一個
    --         if not nameplate.BigText then
    --             nameplate.BigText = nameplate:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    --             -- 設置字體、大小、描邊 (參數：路徑, 大小, 描邊)
    --             nameplate.BigText:SetFont(STANDARD_TEXT_FONT, 80, "OUTLINE")
    --             nameplate.BigText:SetPoint("BOTTOM", nameplate, "TOP", 0, 10)
    --             nameplate.BigText:SetTextColor(1, 0, 0) -- 紅色
    --         end
            
    --         -- 設置文字內容並顯示
    --         nameplate.BigText:SetText("快斷！！！")
    --         nameplate.BigText:Show()
            
    --         -- (可選) 3秒後自動隱藏
    --         C_Timer.After(3, function() 
    --             if nameplate.BigText then nameplate.BigText:Hide() end 
    --         end)
    --     end
    --     return
    elseif event == "UNIT_AURA" then
        -- 1. 獲取事件自帶的參數
        local unitTarget, updateInfo = ...
        local subZone = GetSubZoneText()
        local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()

        -- -- 2. 基礎條件過濾：必須有數據、目標是玩家、處於特定 Boss 戰
        -- if unitTarget and unitTarget:find("player") and currentEncounterID == 2562 then
            
        --     -- 計算從戰鬥開始到現在過去了多少秒
        --     -- 假設你的 startTime 是在 ENCOUNTER_START 中用 GetTime() 記錄的
        --     local elapsed = GetTime() - startTime
            
        --     -- 3. 判斷時間是否在大於 5 秒且小於 10 秒之間
        --     if elapsed > 5 and elapsed < 125 then
                
        --         -- 4. 確保 updateInfo 存在，且不是全量刷新（isFullUpdate 時不會有 addedAuras）
        --         if updateInfo and not updateInfo.isFullUpdate and updateInfo.addedAuras then
                    
        --             -- 5. 遍歷本次事件中所有【新添加】的 Aura
        --             for _, auraData in ipairs(updateInfo.addedAuras) do
                        
        --                 -- 6. 判斷是否是 debuff 
        --                 -- 依據你提供的文檔：isHarmful 表示是否為 debuff
        --                 if auraData.isHarmful then
                            
        --                     -- 執行你的打印邏輯
        --                     print(elapsed)
                            
        --                     -- 如果檢測到一個就足夠了，可以 break 退出循環
        --                     break 
        --                 end
        --             end
        --         end
        --     end
        -- end




        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "風行者寶庫" and keyLevel >= 12 then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                local auraData2 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
                local auraData3 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                local auraCheck = false
                if Lindormi == false then
                    auraCheck = auraData2
                else
                    auraCheck = auraData3
                end
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2498 and unitPowerType == 0 and auraCheck then
                    if not auraTriggeredCache[unitTarget] then
                        PlaySoundFile(MEDIA_PATH .. "JiNu.ogg", "Master")
                        auraTriggeredCache[unitTarget] = true
                    end
                    return
                end
            end                
        end
        return
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local subZone = GetSubZoneText()
        if subZone == "學院中庭" and not hasPlayedSiJiaoTingYuan then
            PlaySoundFile(MEDIA_PATH .. "XuanZeZengYi.ogg", "Master")
            hasPlayedSiJiaoTingYuan = true
        end
        return

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...  
        if unit and unit:find("nameplate") and UnitCanAttack("player", unit) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 then                   
                local actualLevel = UnitLevel(unit)
                local classification = UnitClassification(unit)
                local unitPowerType = UnitPowerType(unit)   
                local sex = UnitSex(unit)
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, 3, "HELPFUL")                 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and auraData then     
                    Lindormi = true
                    return
                end
            end         
        end
        if unit and unit:find("nameplate") and UnitCanAttack("player", unit) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local subZone = GetSubZoneText()
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 2492 and subZone == "亡靈悲悼" and keyLevel >= 12 then                   
                local actualLevel = UnitLevel(unit)
                local classification = UnitClassification(unit)
                local unitPowerType = UnitPowerType(unit)   
                local sex = UnitSex(unit)
                local auraData = C_UnitAuras.GetAuraDataByIndex(unit, 2, "HELPFUL")                 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and classification == "elite" and sex == 2 and auraData then     
                    Lindormi = true
                    return
                end
            end         
        end

    elseif event == "UNIT_SPELLCAST_START" then
        -- print("當前機制文字: " .. (GetTopWidgetText() or "沒找到"))
        -- UnitAffectingCombat(unit)
        local unitTarget = ...
        local subZone = GetSubZoneText()   
        local alerts = LocationCastData[subZone]
        local name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellID = UnitCastingInfo(unitTarget)
        -- local spellInfo = C_Spell.GetSpellInfo(spellID)
        -- -- 獲取事件信息
        -- local eventID = 66
        -- local info = C_EncounterEvents.GetEventInfo(eventID)
        
        -- if info then
        --     print("|cffffd100[Debug] 事件 " .. eventID .. " 數據詳情:|r")
            
        --     -- 文本類
        --     print("文本 (text):", info.text)
        --     print("施法者 (casterName):", info.casterName)
        --     print("目標 (targetName):", info.targetName)
            
        --     -- GUID
        --     print("施法者GUID:", info.casterGUID)
        --     print("目標GUID:", info.targetGUID)
            
        --     -- 數字/ID
        --     print("圖標文件ID (iconFileID):", info.iconFileID)
        --     print("技能ID (tooltipSpellID):", info.tooltipSpellID)
        --     print("持續時間 (duration):", info.duration)
        --     print("嚴重程度 (severity):", info.severity)
            
        --     -- 布爾值 (使用 tostring 強制顯示 true/false/nil)
        --     print("是否致命 (isDeadly):", tostring(info.isDeadly))
        --     print("播放聲音 (shouldPlaySound):", tostring(info.shouldPlaySound))
        --     print("聊天框消息 (shouldShowChatMessage):", tostring(info.shouldShowChatMessage))
        --     print("顯示警告 (shouldShowWarning):", tostring(info.shouldShowWarning))
            
        --     -- 顏色處理
        --     if info.color then
        --         print("顏色 (RGB):", info.color.r, info.color.g, info.color.b)
        --     else
        --         print("顏色: nil")
        --     end
        -- else
        --     print("|cffff0000[Error] 無法獲取事件 " .. eventID .. " 的信息，請確認 ID 是否正確。|r")
        -- end



        -- -- 檢查是否有在讀條
        -- if name then
        --     print("--- 施法詳情 ---")
        --     print("1. 技能名稱 (name):", name)
        --     print("2. 進度條文字 (text):", text)
        --     print("3. 圖標路徑 (texture):", texture)
        --     print("4. 開始時間 (startTimeMS):", startTimeMS) -- 絕對時間(毫秒)
        --     print("5. 結束時間 (endTimeMS):", endTimeMS)     -- 絕對時間(毫秒)
        --     print("6. 專業制造 (isTradeSkill):", isTradeSkill)
        --     print("7. 施法唯一ID (castID):", castID)
        --     print("8. 不可打斷 (notInterruptible):", notInterruptible)
        --     print("9. 技能ID (spellID):", spellID)

        -- end

        if unitTarget == "player" and endTimeMS and CurrentRingIsCastSensitive then
            -- 【雙重保險】只有當前時間還處於圓環倒計時內，才處理顏色和聲音
            if GetTime() < TargetEndTime then
                local castEndTime = endTimeMS / 1000
                -- 如果玩家讀條結束時間 晚於 圓環結束時間
                if not notInterruptible and castEndTime > TargetEndTime then
                    UpdateRingColor(true)
                else
                    UpdateRingColor(false)
                end
            else
                -- 如果時間已經過了，說明圓環該結束了，直接重置標記
                CurrentRingIsCastSensitive = false
            end
        end
        -- if not C_CombatAudioAlert.IsEnabled() then C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), spellName, 1, C_TTSSettings.GetSpeechVolume()) end

        -- local modelFrame = CreateFrame("PlayerModel")

        -- local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        -- local name = UnitName(unitTarget) or "未知"
        -- local actualLevel = UnitLevel(unitTarget)
        -- local classification = UnitClassification(unitTarget)
        -- local unitPowerType = UnitPowerType(unitTarget)   
        -- local sex = UnitSex(unitTarget)
        -- local isInside = IsIndoors()
        -- local classInfo = { UnitClass(unitTarget) }
        -- local className = classInfo[2]
        -- local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
        -- local inCombat = UnitAffectingCombat(unitTarget)
        -- local spellHastePercent = UnitSpellHaste(unitTarget)
        -- local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
        -- local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
        -- local maxhealthMod = GetUnitMaxHealthModifier(unitTarget)
        -- local raceID = UnitRace(unitTarget)
        -- local stepInfo = C_ScenarioInfo.GetScenarioStepInfo()
        -- local cur, per, str = C_ScenarioInfo.GetUnitCriteriaProgressValues("target")
        -- local getWidgetLabelText = GetWidgetLabelText()
        -- print(getWidgetLabelText)
        -- C_Timer.After(0.1, function()
        --     modelFrame:SetUnit(unitTarget) 
        --     local modelFileID = modelFrame:GetModelFileID()
        --     print("當前目標的模型 ID 為: " .. (modelFileID or "未知"))
        -- end)        
        

        -- print(name .. " | 等級: " .. actualLevel .. " | 區域: " .. subZone .. " | 地圖ID: ".. currentMapID .. " | 分類: " .. classification .. " | 能量類型: " .. unitPowerType .. " | 性別: " .. sex .. " | 室內: " .. tostring(isInside) .. " | 職業: " .. className .. " | 存在兩個增益: " .. (auraData and "是" or "否") .. " | 法術加速: " .. spellHastePercent .. " | 生物家族: " .. tostring(creatureFamily))
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "山崁" or subZone == "巍峨峰" then
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)   
                local creatureFamily, familyID = UnitCreatureFamily(unitTarget)
                if not creatureFamily and actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                    local currentCount = UNIT_CAST_TRACKER[unitTarget]
                    local PlayerRole = GetPlayerRole()
                    if currentCount % 2 == 1 then                        
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKePoJia.ogg", "Master")
                            if PlayerRole == "TANK" then
                                StartCircleTimerBySeconds(3)
                            end                                
                        end
                    else                      
                        if PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "DanShuaLiuXue.ogg", "Master")                               
                        end
                    end
                else
                    -- print("|cffffa500[DEBUG]|r 條件未達成，不執行聲音切換。")
                end            
            end
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "山崁" or subZone == "巍峨峰" then 
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget) 
                local creatureFamily, familyID = UnitCreatureFamily(unitTarget)                
                if creatureFamily and actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        PlaySoundFile(MEDIA_PATH .. "MeiYouYinPin.ogg", "Master")
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master")
                    end
                    return
                end            
            end
        end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "巍峨峰" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local isInside = IsIndoors()
                local sex = UnitSex(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                if isInside == false and actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 601 and unitPowerType == 0 and sex == 1 then
                    C_Timer.After(1.9, function()
                        PlaySoundFile(MEDIA_PATH .. "ZhuanHuoBaoZhu.ogg", "Master")
                    end)
                    return
                end
            end               
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "巍峨峰" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local isInside = IsIndoors()

                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 601 and unitPowerType == 0 and sex == 1 and isInside == true then
                    -- 計數器遞增
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    local step = UNIT_CAST_TRACKER[unitTarget] % 3
                    local PlayerRole = GetPlayerRole()
                    if step == 1 then                        
                        if PlayerRole == "DAMAGER" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", "Master")
                        end                        
                    elseif step == 2 then
                        -- 技能 2
                        PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", "Master")
                    else
                        if PlayerRole == "DAMAGER" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", "Master")
                        end      
                    end
                    
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "巍峨峰" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local isInside = IsIndoors()
                local sex = UnitSex(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)
                if isInside == true and actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 602 and unitPowerType == 0 and sex == 1 then
                    C_Timer.After(1.9, function()
                        PlaySoundFile(MEDIA_PATH .. "ZhuanHuoBaoZhu.ogg", "Master")
                    end)
                    return
                end
            end               
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                local sex = UnitSex(unitTarget)
                if actualLevel == PLAYER_LEVEL and unitPowerType == 0 and classification == "elite" and auraData and sex == 2 then                    
                    PlaySoundFile(MEDIA_PATH .. "XuKongBaoFa.ogg", "Master")
                    return
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 and Lindormi == false then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and auraData then                    
                    -- local castInfo = { UnitCastingInfo(unitTarget) }
                    -- local spellName = castInfo[1]
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" or PlayerRole == "DAMAGER" then
                        PlaySoundFile(MEDIA_PATH .. "HanBingChongJi.ogg", "Master")
                    end                    
                    -- if not C_CombatAudioAlert.IsEnabled() then C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), spellName, 1, C_TTSSettings.GetSpeechVolume()) end
                    return
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()
            if currentMapID == 184 and keyLevel >= 12 then 
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                local auraData2 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 2, "HELPFUL") 
                local auraData3 = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                local auraCheck = false
                if Lindormi == false then
                    auraCheck = not auraData2
                else
                    auraCheck = not auraData3
                end
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and auraCheck then 
                    -- UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1    
                    -- print(maxRange)
                    if spellID then
                        local maxRange = C_Spell.GetSpellInfo(spellID).maxRange
                        C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), maxRange, 10, 0, true)   
                    end                    
                    -- local castInfo = { UnitCastingInfo(unitTarget) }
                    -- local spellName = castInfo[1]
                    -- if not C_CombatAudioAlert.IsEnabled() then C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), spellName, 1, C_TTSSettings.GetSpeechVolume()) end
                end
            end         
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local isInside = IsIndoors()
                if actualLevel == NEXT_PLAYER_LEVEL and (currentMapID == 2097 or currentMapID == 2098) and unitPowerType == 1 and sex == 1 and isInside == false then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        PlaySoundFile(MEDIA_PATH .. "DuoKaiDaQuan.ogg", "Master")
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiTouQian.ogg", "Master")
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if currentEncounterID == 2563 then   
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)  
                if actualLevel == PLAYER_LEVEL and unitPowerType == 0 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "DAMAGER" then
                            PlaySoundFile(MEDIA_PATH .. "DaDuanDaGuai.ogg", "Master")
                        end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "運動場" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2098 then
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), name, 10, 0, true)
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" or subZone == "院長區" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2097 and unitPowerType == 1 and sex == 3 then
                    PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master")
                    C_EncounterTimeline.AddScriptEvent({
                        spellID = 1270356,
                        iconFileID = 1391782,
                        duration = 26,
                        overrideName = "準備AOE",
                        icons = 0x1,
                        severity = 2,
                        maxQueueDuration = 0,
                        paused = false,
                    })
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2501 and unitPowerType == 1 and sex == 1 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeLiuXue.ogg", "Master")
                        end
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiChenMoSanDianWuMiaoAnQuan.ogg", "Master")
                        StartCircleTimerBySeconds(3.5, true)
                        C_EncounterTimeline.AddScriptEvent({
                            spellID = 1256047,
                            iconFileID = 132117,
                            duration = 24,
                            overrideName = "準備沉默",
                            icons = 0x1,
                            severity = 2,
                            maxQueueDuration = 0,
                            paused = false,
                        })
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0     
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local isInside = IsIndoors()
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 1 and isInside == false then
                    PlaySoundFile(MEDIA_PATH .. "LingDianWuMiaoDuoKaiTouQian.ogg", "Master")
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentText = GetTopWidgetText() or ""
                if currentText:find("關閉的虛無裂隙") then    
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                        UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                        if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                            local PlayerRole = GetPlayerRole()
                            if PlayerRole == "HEALER" then
                                PlaySoundFile(MEDIA_PATH .. "SanMiaoQuSanMoFa.ogg", "Master")
                            end
                        else
                            PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master")                     
                        end
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentText = GetTopWidgetText() or ""
                if currentText:find("關閉的虛無裂隙") then    
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 2 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJiTui.ogg", "Master")
                            -- 直接在調用時構造 Table
                            C_EncounterTimeline.AddScriptEvent({
                                spellID = 1280326,
                                iconFileID = 6718454,
                                duration = 22,
                                overrideName = "坦克擊退",
                                icons = 0x1,
                                severity = 1,
                                maxQueueDuration = 0,
                                paused = false,
                            })
                        end                        
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "三傑議會之座" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentText = GetTopWidgetText() or ""
                if not currentText:find("關閉的虛無裂隙") then    
                    if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                        UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                        if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                            PlaySoundFile(MEDIA_PATH .. "WuMaFenSan.ogg", "Master")
                        else
                            PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", "Master")
                        end
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "三傑議會之座" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        -- PlaySoundFile(MEDIA_PATH .. "QiMiaoZhuYiDuoQiu.ogg", "Master")
                    else
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "YiMiaoZhuYiDanShua.ogg", "Master")
                        end                        
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "三傑講修院" or subZone == "影衛哨站" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiYouBuYouBu.ogg", "Master")
                    else
                        PlaySoundFile(MEDIA_PATH .. "MeiYouYinPin.ogg", "Master")                     
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "凡蕾莎之憩" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1        
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        -- PlaySoundFile(MEDIA_PATH .. "MeiYouYinPin.ogg", "Master")
                    else
                        PlaySoundFile(MEDIA_PATH .. "WuMaFenSan.ogg", "Master")                     
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "凡蕾莎之憩" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2494 and unitPowerType == 3 then
                    if not UNIT_START_TIMES[unitTarget] then
                        UNIT_START_TIMES[unitTarget] = GetTime()
                        UNIT_CAST_TRACKER[unitTarget] = 0 -- 確保初始狀態為0
                    end

                    -- 2. 計算經過的時間
                    local elapsed = GetTime() - UNIT_START_TIMES[unitTarget]
                    local currentStep = UNIT_CAST_TRACKER[unitTarget] or 0
                    -- print(elapsed)
                    -- 3. 第一階段：超過 7 秒且未播報過
                    if elapsed >= 6 and currentStep == 0 then
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master")
                        UNIT_CAST_TRACKER[unitTarget] = 1 -- 標記已完成第一階段
                        -- print("|cff00ff00[地瓜提示]|r 時間軸 6秒 播報完成")
                        return 
                    end

                    -- 4. 第二階段：超過 32 秒且只進行過第一階段播報
                    if elapsed >= 32 and currentStep == 1 then
                        -- 這裡可以播放同一個文件，或者換一個不同的提示音
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master") 
                        UNIT_CAST_TRACKER[unitTarget] = 2 -- 標記已完成第二階段
                        -- print("|cff00ff00[地瓜提示]|r 時間軸 32.5秒 再次播報")
                        return
                    end

                    -- 4. 第三階段：超過 57 秒且只進行過第二階段播報
                    if elapsed >= 59 and currentStep == 2 then
                        -- 這裡可以播放同一個文件，或者換一個不同的提示音
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master") 
                        UNIT_CAST_TRACKER[unitTarget] = 3 -- 標記已完成第二階段
                        -- print("|cff00ff00[地瓜提示]|r 時間軸 58秒 再次播報")
                        return
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "希瓦娜斯閨房" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1   
                    local PlayerRole = GetPlayerRole()     
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", "Master")
                        end                        
                    else
                        if PlayerRole == "TANK" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeDaiWei.ogg", "Master")
                        else
                            PlaySoundFile(MEDIA_PATH .. "WuMaFenSan.ogg", "Master")
                        end
                    end
                    return
                end
            end                
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "亡靈悲悼" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 1 and currentMapID == 2498 then
                    -- local castInfo = { UnitCastingInfo(unitTarget) }
                    -- local spellName = castInfo[1]
                    -- print(texture)
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), texture, 10, 0, true)
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 3 and sex == 1 and BOSS_KILL_3072 == false then
                    CastMonitor.startTime = GetTime()
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                    local remainder = UNIT_CAST_TRACKER[unitTarget] % 3
                    if remainder == 1 then
                        -- local PlayerRole = GetPlayerRole()
                        -- if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                        --     PlaySoundFile(MEDIA_PATH .. "TanKeDingShen.ogg", "Master")
                        -- end
                    elseif remainder == 2 then
                        -- PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", "Master")
                    elseif remainder == 0 then
                        StartCircleTimerBySeconds(3)
                        PlaySoundFile(MEDIA_PATH .. "XiaoXinJiTui.ogg", "Master") 
                    end               
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 and BOSS_KILL_3072 == true then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                        PlaySoundFile(MEDIA_PATH .. "TanKeChengShang.ogg", "Master")
                    end
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 3 and BOSS_KILL_3071 == true then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1   
                    if UNIT_CAST_TRACKER[unitTarget] % 2 == 1 then
                        PlaySoundFile(MEDIA_PATH .. "ZhunBeiDianMing.ogg", "Master")
                        C_EncounterTimeline.AddScriptEvent({
                            spellID = 1244907,
                            iconFileID = 5927616,
                            duration = 19,
                            overrideName = "準備點名",
                            icons = 0x1,
                            severity = 2,
                            maxQueueDuration = 0,
                            paused = false,
                        })
                    else
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", "Master")   
                        -- C_EncounterTimeline.AddScriptEvent({
                        --     spellID = 1283901,
                        --     iconFileID = 4667417,
                        --     duration = 23,
                        --     overrideName = "注意躲圈",
                        --     icons = 0x1,
                        --     severity = 1,
                        --     maxQueueDuration = 0,
                        --     paused = false,
                        -- })
                    end                    
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) and UnitAffectingCombat(unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2915 then -- 節點希納斯
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 0 and sex == 2 and currentEncounterID == 0 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                    local remainder = UNIT_CAST_TRACKER[unitTarget] % 3
                    local PlayerRole = GetPlayerRole()
                    if remainder == 1 then                        
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", "Master")
                        end
                    elseif remainder == 2 then
                        if PlayerRole == "HEALER" then
                            C_Timer.After(3, function()
                                PlaySoundFile(MEDIA_PATH .. "DanShuaDianMing.ogg", "Master")
                            end)                            
                        end                        
                    elseif remainder == 0 then
                        PlaySoundFile(MEDIA_PATH .. "DuoKaiTouQian.ogg", "Master") 
                    end               
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 3 and sex == 1 and BOSS_KILL_3072 == true then
                    PlaySoundFile(MEDIA_PATH .. "KuaiKaiJianShang.ogg", "Master")
                    C_EncounterTimeline.AddScriptEvent({
                        spellID = 1265977,
                        iconFileID = 136160,
                        duration = 33,
                        overrideName = "吞噬暗影",
                        icons = 0x1,
                        severity = 2,
                        maxQueueDuration = 0,
                        paused = false,
                    })
                    return
                end
            end                
        end
        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     if subZone == "風行者寶庫" then
        --         local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
        --         local actualLevel = UnitLevel(unitTarget)
        --         local unitPowerType = UnitPowerType(unitTarget)    

        --         if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 2498 and unitPowerType == 0 and currentEncounterID == 0 then
        --             -- 1. 初始化開始時間
        --             if not UNIT_START_TIMES[unitTarget] then
        --                 UNIT_START_TIMES[unitTarget] = GetTime()
        --                 UNIT_CAST_TRACKER[unitTarget] = 0 -- 確保初始狀態為0
        --             end

        --             -- 2. 計算經過的時間
        --             local elapsed = GetTime() - UNIT_START_TIMES[unitTarget]
        --             local currentStep = UNIT_CAST_TRACKER[unitTarget] or 0
        --             -- print(elapsed)
        --             -- 3. 第一階段：超過 7 秒且未播報過
        --             if elapsed >= 6.3 and currentStep == 0 then
        --                 PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master")
        --                 UNIT_CAST_TRACKER[unitTarget] = 1 -- 標記已完成第一階段
        --                 -- print("|cff00ff00[地瓜提示]|r 時間軸 8秒 播報完成")
        --                 return 
        --             end

        --             -- 4. 第二階段：超過 32 秒且只進行過第一階段播報
        --             if elapsed >= 31.2 and currentStep == 1 then
        --                 -- 這裡可以播放同一個文件，或者換一個不同的提示音
        --                 PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master") 
        --                 UNIT_CAST_TRACKER[unitTarget] = 2 -- 標記已完成第二階段
        --                 -- print("|cff00ff00[地瓜提示]|r 時間軸 32秒 再次播報")
        --                 return
        --             end

        --             -- 4. 第三階段：超過 56 秒且只進行過第二階段播報
        --             if elapsed >= 55.5 and currentStep == 2 then
        --                 -- 這裡可以播放同一個文件，或者換一個不同的提示音
        --                 PlaySoundFile(MEDIA_PATH .. "ZhunBeiAOE.ogg", "Master") 
        --                 UNIT_CAST_TRACKER[unitTarget] = 3 -- 標記已完成第二階段
        --                 -- print("|cff00ff00[地瓜提示]|r 時間軸 56秒 再次播報")
        --                 return
        --             end
        --         end
        --     end                
        -- end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "哀嚎深淵" or subZone == "苦難平臺" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 2 then
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1 
                    local castCount = UNIT_CAST_TRACKER[unitTarget]
                    if castCount == 1 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", "Master")
                        end                        
                    elseif castCount == 2 then
                        PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", "Master")
                    elseif castCount == 3 then
                        PlaySoundFile(MEDIA_PATH .. "JinZhanDaQuan.ogg", "Master")
                    elseif castCount == 4 then
                        local PlayerRole = GetPlayerRole()
                        if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                            PlaySoundFile(MEDIA_PATH .. "TanKeJianCi.ogg", "Master")
                        end      
                    else
                        -- print("超過4次，停止播報") 
                    end
                    return
                end
            end                
        end


        if not alerts then return end

        if startTime ~= 0 or currentEncounterID ~= 0 then return end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
            local actualLevel = UnitLevel(unitTarget)
            local name = UnitName(unitTarget) or "未知"
            -- print(name .. " | dengji: " .. actualLevel .. " | quyu: " .. subZone .. " | dituID: ".. currentMapID)  
            for _, alertConfig in ipairs(alerts) do
                ProcessAlert(alertConfig, "Location:"..subZone, actualLevel, currentMapID, unitTarget)
            end
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unitTarget = ...
        local subZone = GetSubZoneText()   
        local alerts = LocationChannelData[subZone]

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 3 then                    
                    if not UNIT_CHANNEL_TRACKER[unitTarget] then
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiJiuRen.ogg", "Master")
                        UNIT_CHANNEL_TRACKER[unitTarget] = true
                        C_EncounterTimeline.AddScriptEvent({
                            spellID = 1258997,
                            iconFileID = 4632787,
                            duration = 30,
                            overrideName = "注意救人",
                            icons = 0x1,
                            severity = 1,
                            maxQueueDuration = 0,
                            paused = false,
                        })
                        return
                    end                    
                    return
                end
            end         
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "巍峨峰" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local isInside = IsIndoors() and true or false
                if isInside == false and actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 601 then
                    PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", "Master")
                    return
                end
            end               
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "巍峨峰" then
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
                local actualLevel = UnitLevel(unitTarget)
                local isInside = IsIndoors() and true or false          
                if isInside == true and actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 602 then
                    PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", "Master")
                    return
                end
            end               
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "亡靈悲悼" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and sex == 3 and currentMapID == 2498 then
                    PlaySoundFile(MEDIA_PATH .. "ZhuYiDuoQuan.ogg", "Master")
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0      
            if subZone == "凡蕾莎之憩" or subZone == "" then
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local sex = UnitSex(unitTarget)
                if (currentMapID == 2493 or currentMapID == 2494 or currentMapID == 2492) and actualLevel == PLAYER_LEVEL and classification == "elite" and sex == 1 then
                    PlaySoundFile(MEDIA_PATH .. "KongDuanLongYing.ogg", "Master")
                    local testEventInfo = {
                        spellID = 1216848,              -- 示例：幻影打擊 (隨便找個法術ID)
                        iconFileID = 135812,           -- 示例：一個圖標的 FileID
                        duration = 17.6,                 -- 持續 10 秒
                        maxQueueDuration = 0,
                        overrideName = "控斷龍鷹", -- 顯示的名稱
                        icons = 0x1,                  -- 對應 TankRole (坦克圖標)
                        severity = 2,                  -- High (高傷害/重要等級)
                        paused = false,
                    }
                    local eventID = C_EncounterTimeline.AddScriptEvent(testEventInfo)
                    return
                end
            end          
        end

        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "哀嚎深淵" or subZone == "苦難平臺" then    
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
                    if not UNIT_CHANNEL_TRACKER[unitTarget] then
                        PlaySoundFile(MEDIA_PATH .. "DaDuanFuHuo.ogg", "Master")
                        UNIT_CHANNEL_TRACKER[unitTarget] = true
                        return
                    end
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 3 and sex == 1 and BOSS_KILL_3072 == true then -- 影衛虛空召喚師
                    UNIT_CAST_TRACKER[unitTarget] = (UNIT_CAST_TRACKER[unitTarget] or 0) + 1
                    local remainder = UNIT_CAST_TRACKER[unitTarget] % 3
                    if remainder == 1 then                        
                        PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", "Master")
                    elseif remainder == 2 then
                        -- PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", "Master")
                    elseif remainder == 0 then
                        PlaySoundFile(MEDIA_PATH .. "ZhaoHuanXiaoGuai.ogg", "Master")
                    end                    
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0
            if currentMapID == 184 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local sex = UnitSex(unitTarget)
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and classification == "elite" and sex == 2 and currentEncounterID == 0 then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "HEALER" then
                        PlaySoundFile(MEDIA_PATH .. "DanShuaDianMing.ogg", "Master")
                    end                    
                    return
                end
            end         
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 3 and sex == 1 and BOSS_KILL_3072 == false then
                        PlaySoundFile(MEDIA_PATH .. "ZhuYiDianMing.ogg", "Master")       
                    return
                end
            end                
        end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            if subZone == "核心防禦空無結界" then      
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget) 
                local sex = UnitSex(unitTarget)   
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 and currentEncounterID == 0 then
                    local PlayerRole = GetPlayerRole()
                    if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                        PlaySoundFile(MEDIA_PATH .. "TanKeChengShang.ogg", "Master")
                        C_EncounterTimeline.AddScriptEvent({
                            spellID = 1252417,
                            iconFileID = 4914668,
                            duration = 24,
                            overrideName = "坦克承傷",
                            icons = 0x1,
                            severity = 2,
                            maxQueueDuration = 0,
                            paused = false,
                        })
                    end
                    return
                end
            end               
        end
        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     if subZone == "山崁" then
        --         local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
        --         local actualLevel = UnitLevel(unitTarget)   
        --         if actualLevel == NEXT_PLAYER_LEVEL and currentMapID == 601 then
        --             local PlayerRole = GetPlayerRole()     
        --             if PlayerRole == "HEALER" then
        --                 PlaySoundFile(MEDIA_PATH .. "AOE.ogg", "Master")
        --             end
        --         end
        --     end               
        -- end
        -- local currentMapID = C_Map.GetBestMapForUnit("player") or 0  
        -- local name = UnitName(unitTarget) or "未知"
        -- local actualLevel = UnitLevel(unitTarget)
        -- print(name .. " | dengji: " .. actualLevel .. " | quyu: " .. subZone .. " | dituID: ".. currentMapID)  
        if not alerts then return end

        if startTime ~= 0 or currentEncounterID ~= 0 then return end
        
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
            local actualLevel = UnitLevel(unitTarget)
            local name = UnitName(unitTarget) or "未知"
            -- print(name .. " | dengji: " .. actualLevel .. " | quyu: " .. subZone .. " | dituID: ".. currentMapID)  

            for _, alertConfig in ipairs(alerts) do
                ProcessAlert(alertConfig, "Location:"..subZone, actualLevel, currentMapID, unitTarget)
            end
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        -- print("測試")
        local unitTarget = ...
        local interruptedBy = (event == "UNIT_SPELLCAST_INTERRUPTED") and select(4, ...) or nil
        local subZone = GetSubZoneText()   
    --     if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
    --         if subZone == "山崁" or subZone == "巍峨峰" then
    --             -- local currentMapID = C_Map.GetBestMapForUnit("player") or 0        
    --             local actualLevel = UnitLevel(unitTarget)
    --             local unitPowerType = UnitPowerType(unitTarget)    
    --             local sex = UnitSex(unitTarget)
    --             C_Timer.After(0.1, function()
    --                 modelFrame:SetUnit(unitTarget) 
    --                 local modelFileID = modelFrame:GetModelFileID()      
    --                 if modelFileID == 986699 and actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 1 and sex == 1 then
    --                     UNIT_SUCCEEDED_AND_INTERRUPTED_TRACKER[unitTarget] = (UNIT_SUCCEEDED_AND_INTERRUPTED_TRACKER[unitTarget] or 0) + 1        
    --                     if UNIT_SUCCEEDED_AND_INTERRUPTED_TRACKER[unitTarget] % 2 == 1 then
    --                         local testEventInfo = {
    --                             spellID = 1254380,              -- 示例：幻影打擊 (隨便找個法術ID)
    --                             iconFileID = 4635276,           -- 示例：一個圖標的 FileID
    --                             duration = 22,                 -- 持續 10 秒
    --                             maxQueueDuration = 0,
    --                             overrideName = "坦克破甲", -- 顯示的名稱
    --                             icons = 0x80,                  -- 對應 TankRole (坦克圖標)
    --                             severity = 2,                  -- High (高傷害/重要等級)
    --                             paused = false,
    --                         }
    --                         local eventID = C_EncounterTimeline.AddScriptEvent(testEventInfo)
    --                     else
    --                         -- print("成功4")
    --                     end
    --                     return
    --                 end
    --             end)                
    --         end
    --     end
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local currentMapID = C_Map.GetBestMapForUnit("player") or 0   
            local keyLevel = C_ChallengeMode.GetActiveKeystoneInfo()         
            if currentMapID == 184 and keyLevel >= 12 then                   
                local actualLevel = UnitLevel(unitTarget)
                local classification = UnitClassification(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)   
                local auraData = C_UnitAuras.GetAuraDataByIndex(unitTarget, 3, "HELPFUL") 
                local sex = UnitSex(unitTarget)
                if interruptedBy and actualLevel == PLAYER_LEVEL and unitPowerType == 0 and classification == "elite" and sex == 2 and auraData then
                    local testEventInfo = {
                        spellID = 1271479,              -- 示例：幻影打擊 (隨便找個法術ID)
                        iconFileID = 1041233,           -- 示例：一個圖標的 FileID
                        duration = 20,                 -- 持續 10 秒
                        maxQueueDuration = 0,
                        overrideName = "虛空爆發", -- 顯示的名稱
                        icons = 0x1,                  -- 對應 TankRole (坦克圖標)
                        severity = 2,                  -- High (高傷害/重要等級)
                        paused = false,
                    }
                    local eventID = C_EncounterTimeline.AddScriptEvent(testEventInfo)
                    return
                end
            end          
        end
        if unitTarget and unitTarget:find("boss") and UnitCanAttack("player", unitTarget) then
            if subZone == "運動場" then
                local LabelText = GetWidgetLabelText()
                if LabelText == nil then
                    -- print("火焰")
                    PlaySoundFile(MEDIA_PATH .. "YiShangJieDuan.ogg", "Master")
                    C_Timer.After(7, function()
                        if currentEncounterID ~= 0 then
                            PlaySoundFile(MEDIA_PATH .. "DaoShu5.ogg", "Master")
                        end                            
                    end)
                    C_Timer.After(8, function()
                        if currentEncounterID ~= 0 then
                            PlaySoundFile(MEDIA_PATH .. "DaoShu4.ogg", "Master")
                        end                            
                    end)
                    C_Timer.After(9, function()
                        if currentEncounterID ~= 0 then
                            PlaySoundFile(MEDIA_PATH .. "DaoShu3.ogg", "Master")
                        end                            
                    end)
                    C_Timer.After(10, function()
                        if currentEncounterID ~= 0 then
                            PlaySoundFile(MEDIA_PATH .. "DaoShu2.ogg", "Master")
                        end                            
                    end)
                    C_Timer.After(11, function()
                        if currentEncounterID ~= 0 then
                            PlaySoundFile(MEDIA_PATH .. "DaoShu1.ogg", "Master")
                        end                            
                    end)
                    C_Timer.After(12, function()
                        if currentEncounterID ~= 0 then
                            PlaySoundFile(MEDIA_PATH .. "YiShangJieShu.ogg", "Master")
                        end                            
                    end)
                else
                    -- print("狂風")
                    PlaySoundFile(MEDIA_PATH .. "JieDuanZhuanHuan.ogg", "Master")     
                end           
            end          
        end
        return
    -- elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    --     local unitTarget = ...
    --     local subZone = GetSubZoneText()
    elseif event == "RAID_BOSS_EMOTE" or event == "ENCOUNTER_WARNING" then

        local encounterWarningInfo = ...
        -- if encounterWarningInfo then
        --     print("|cffffd100[Debug] 捕獲到實時事件數據:|r")
            
        --     -- 1. 文本類
        --     print("文本 (text):", encounterWarningInfo.text)
        --     print("施法者 (casterName):", encounterWarningInfo.casterName)
        --     print("目標 (targetName):", encounterWarningInfo.targetName)
            
        --     -- 2. GUID
        --     print("施法者GUID:", encounterWarningInfo.casterGUID)
        --     print("目標GUID:", encounterWarningInfo.targetGUID)
            
        --     -- 3. 數字/ID
        --     print("圖標ID (iconFileID):", encounterWarningInfo.iconFileID)
        --     print("技能ID (tooltipSpellID):", encounterWarningInfo.tooltipSpellID)
        --     print("持續時間 (duration):", encounterWarningInfo.duration)
        --     print("嚴重程度 (severity):", encounterWarningInfo.severity)
            
        --     -- 4. 布爾值
        --     print("是否致命 (isDeadly):", tostring(encounterWarningInfo.isDeadly))
        --     print("播放聲音 (shouldPlaySound):", tostring(encounterWarningInfo.shouldPlaySound))
        --     print("聊天框消息 (shouldShowChatMessage):", tostring(encounterWarningInfo.shouldShowChatMessage))
        --     print("顯示警告 (shouldShowWarning):", tostring(encounterWarningInfo.shouldShowWarning))
            
        --     -- 5. 顏色
        --     if encounterWarningInfo.color then
        --         print("顏色 (RGB):", encounterWarningInfo.color.r, encounterWarningInfo.color.g, encounterWarningInfo.color.b)
        --     else
        --         print("顏色: nil")
        --     end
            
        --     -- 這裡可以直接接你的圓環啟動邏輯
        --     if encounterWarningInfo.duration and encounterWarningInfo.duration > 0 then
        --         -- 假設只有 severity 大於某個值才需要檢查讀條，或者全部檢查
        --         StartCircleTimerBySeconds(encounterWarningInfo.duration, true)
        --     end
        -- else
        --     print("|cffff0000[Error] 事件觸發但數據為空|r")
        -- end




        if currentEncounterID == 3056 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：檢測到熾焰騰流")
            PlaySoundFile(MEDIA_PATH .. "TieBianFangShuiSanMiaoSanErYi.ogg", "Master")
            StartCircleTimerBySeconds(6)
            return
        end
        if currentEncounterID == 3179 and encounterWarningInfo.severity and encounterWarningInfo.severity == 0 then
            -- print("成功：檢測到專制命令")
            -- PlaySoundFile(MEDIA_PATH .. "TieBianFangShui.ogg", "Master")
            StartCircleTimerBySeconds(12)
            return
        end
        if currentEncounterID == 2065 and encounterWarningInfo.targetName then
            -- print("成功：檢測到殘殺")
            StartCircleTimerBySeconds(5)
            return
        end
        if currentEncounterID == 2564 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：檢測到震耳尖嘯")
            -- local PlayerRole = GetPlayerRole()
            -- if PlayerRole == "HEALER" then
            --     C_Timer.After(1.3, function()
            --         PlaySoundFile(MEDIA_PATH .. "Yi.ogg", "Master")
            --     end)   
            -- end
            StartCircleTimerBySeconds(2.3, true)
            return
        end        
        if currentEncounterID == 3072 and encounterWarningInfo.severity and encounterWarningInfo.severity == 2 then
            -- print("成功：檢測到靜默浪潮")
            StartCircleTimerBySeconds(4.8)
            return
        end
        if currentEncounterID == 3057 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：檢測到黑暗詛咒和飛濺噴吐")
            StartCircleTimerBySeconds(4.1)
            return
        end        
        if currentEncounterID == 3214 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            -- print("成功：檢測到粉碎靈魂")
            StartCircleTimerBySeconds(4.5)
            return
        end
        if currentEncounterID == 3181 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 then
            local _, _, difficultyID = GetInstanceInfo()            
            -- 如果是史詩難度（ID 16）
            if difficultyID == 16 then
                local preciseTime = GetTime() - startTime
                local PlayerRole = GetPlayerRole()
                if PlayerRole == "DAMAGER" or PlayerRole == "HEALER" then
                    if preciseTime >= 4 and preciseTime <= 6 then
                        StartCircleTimerBySeconds(5, true)
                    end
                    if preciseTime >= 24 and preciseTime <= 27 then
                        StartCircleTimerBySeconds(5, true)
                    end
                    if preciseTime >= 47 and preciseTime <= 49 then
                        StartCircleTimerBySeconds(5, true)
                    end
                    if preciseTime >= 427 and preciseTime <= 429 then
                        StartCircleTimerBySeconds(5, true)
                    end
                    if preciseTime >= 444 and preciseTime <= 446 then
                        StartCircleTimerBySeconds(5, true)
                    end
                end
                if preciseTime >= 19 and preciseTime <= 21 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 36 and preciseTime <= 38 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 55 and preciseTime <= 58 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 74 and preciseTime <= 77 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 92 and preciseTime <= 95 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 118 and preciseTime <= 121 then
                    StartCircleTimerBySeconds(6)
                end
            end
            return
        end
        if currentEncounterID == 3178 and encounterWarningInfo.severity and encounterWarningInfo.severity == 1 and encounterWarningInfo.shouldPlaySound == true then
            -- print("成功：檢測到亡者吐息")
            local _, _, difficultyID = GetInstanceInfo()            
            -- 如果是史詩難度（ID 16）
            if difficultyID == 16 then
                local preciseTime = GetTime() - startTime
                if preciseTime >= 4 and preciseTime <= 6 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 69 and preciseTime <= 71 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 131 and preciseTime <= 134 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 190 and preciseTime <= 193 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 315 and preciseTime <= 318 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 359 and preciseTime <= 362 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 359 and preciseTime <= 362 then
                    StartCircleTimerBySeconds(6)
                end
                if preciseTime >= 411 and preciseTime <= 414 then
                    StartCircleTimerBySeconds(6)
                end
            end
            return
        end
        if currentEncounterID == 3183 and encounterWarningInfo.severity == 1 then
            local _, _, difficultyID = GetInstanceInfo()
            
            -- 定義預設時間為 3.9 秒（普通/英雄）
            local timerDuration = 3.9
            
            -- 如果是史詩難度（ID 16），則改為 2.9 秒
            if difficultyID == 16 then
                timerDuration = 2.9
            end
            StartCircleTimerBySeconds(timerDuration)
            return 
        end
        if startTime ~= 0 or currentEncounterID ~= 0 then 
            return 
        end

        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return end

        
        -- print("['" .. encounterWarningInfo.duration .. "']")
        if encounterWarningInfo.duration == 3.5 and mapID == 184 then
            -- print("成功")
            PlaySoundFile(MEDIA_PATH .. "WuMaFenSanSanErYiZhuYiJiaoXia.ogg", "Master")
            StartCircleTimerBySeconds(5.1)
            return
        end

        -- print("ID: " .. mapID)
        local alert = LocationWarningAlerts[mapID]
        
        if alert then
            StartMyCircleTimer(alert)
            ProcessAlert(alert, "Location:"..mapID)
        end
        return


    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget = ...
        if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
            local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
            if instanceID == 2811 then -- 博學者殿堂
                local actualLevel = UnitLevel(unitTarget)
                local unitPowerType = UnitPowerType(unitTarget)    
                local sex = UnitSex(unitTarget)
                local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
                if actualLevel == NEXT_PLAYER_LEVEL and unitPowerType == 3 and sex == 1 and BOSS_KILL_3072 == false then
                    if CastMonitor.startTime > 0 then
                        local duration = GetTime() - CastMonitor.startTime
                        if duration <= 2.5 then
                            local PlayerRole = GetPlayerRole()
                            if PlayerRole == "TANK" or PlayerRole == "HEALER" then
                                PlaySoundFile(MEDIA_PATH .. "TanKeDingShen.ogg", "Master")
                                return
                            end
                        end  
                    end
                end
            end                
        end
        -- if unitTarget and unitTarget:find("nameplate") and UnitCanAttack("player", unitTarget) then
        --     local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        --     if instanceID == 2805 then -- 風行者之塔
        --         local actualLevel = UnitLevel(unitTarget)
        --         local unitPowerType = UnitPowerType(unitTarget)    
        --         local sex = UnitSex(unitTarget)
        --         local currentMapID = C_Map.GetBestMapForUnit("player") or 0 
        --         if actualLevel == PLAYER_LEVEL and unitPowerType == 1 and sex == 3 then
        --             print("測試")
        --             PlaySoundFile(MEDIA_PATH .. "TanKeDingShen.ogg", "Master")
        --             return
        --         end
        --     end                
        -- end

    elseif event == "PLAYER_LOGIN" then
        -- 2. 根據檢測結果動態賦值
        if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
            MEDIA_PATH = "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
            -- print("|cff00ff00[聯動]|r 檢測到 DiGua-WYJJ，[忘憂景久語音包啟動]")
        else
            MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
            -- print("|cffaaaaaa[系統]|r 未檢測到 DiGua-WYJJ，使用預設素材路徑")
        end
        -- 1. 專門針對 BigWigs 的判斷
        local hasBigWigs = C_AddOns.IsAddOnLoaded("BigWigs")

        -- 2. 只有在【沒有 BigWigs】的情況下，才在 2 秒後強制開啟系統警報
        if not hasBigWigs then
            C_Timer.After(2, function()
                -- 如果有 DBM 但沒有 BW，這裡依然會執行，滿足你“DBM無所謂”的需求
                SetCVar("encounterWarningsEnabled", 1)
            end)
        end       
        SetCVar("Sound_NumChannels", 128)
        -- 【修改這裡】如果“不是”大秘境進行中，才執行該函數
        -- 建議加一個極其微小的延時（如 0.1 秒）確保 API 數據已准備好
        C_Timer.After(0.5, function()
            if not C_ChallengeMode.IsChallengeModeActive() then
                RegisterPrivateAuras()
            end
        end)
        --[[C_Timer.After(2, function()
            print("感謝使用|cFF00FF00[神秘地瓜副本語音插件]|r如果覺得好用，請在|cFFFFA6D5“愛發電”|r平台搜索|cFFFFFF00“神秘地瓜”|r支持我的插件，您的支持就是我最大的動力。")
        --end)]]       
        -- ApplyTimelineSounds()

        


        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        hasPlayedSiJiaoTingYuan = false
        Lindormi = false
        MyTTSDict.isSampled = false
        MyTTSDict.sampleIndex = 0
        local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID = GetInstanceInfo()
        -- print("當前副本 ID: " .. (instanceID or "nil"))
        C_Timer.After(2, function()
            if instanceID == 658 then 
                C_Timer.After(2, function()
                    MyTTSDict.sampleIndex = 1        
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "0", 10, 0, true)
                end)
                -- 2秒後讀第二個
                C_Timer.After(4, function()
                    MyTTSDict.sampleIndex = 2
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "50000", 10, 0, true)                
                end)
            end
            if instanceID == 2805 then 
                C_Timer.After(2, function()
                    MyTTSDict.sampleIndex = 1        
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "4667427", 10, 0, true)
                end)
                -- 2秒後讀第二個
                C_Timer.After(4, function()
                    MyTTSDict.sampleIndex = 2
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "852826", 10, 0, true)
                end)
            end
            if instanceID == 2526 then -- 阿爾蓋薩學院
                C_Timer.After(2, function()
                    MyTTSDict.sampleIndex = 1        
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "狂風", 10, 0, true)
                end)
                -- 2秒後讀第二個
                C_Timer.After(4, function()
                    MyTTSDict.sampleIndex = 2
                    C_VoiceChat.SpeakText(C_TTSSettings.GetVoiceOptionID(0), "狂怒尖嘯", 10, 0, true)
                end)
            end  
        end)
        return
    -- elseif event == "LOADING_SCREEN_DISABLED" then
    --     print("LOADING_SCREEN_DISABLED")
        
    --     return
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        local subZone = GetSubZoneText()
        if subZone == "藥草園" then
            encounterUnitTriggerCount = (encounterUnitTriggerCount or 0) + 1
            if encounterUnitTriggerCount >= 3 and encounterUnitTriggerCount % 2 ~= 0 then
                if UnitExists("boss1") and not UnitIsDead("boss1") then
                    PlaySoundFile(MEDIA_PATH .. "KuaiJinLvQuan.ogg", "Master")
                    -- print("|cffff0000[警報]|r 第 " .. encounterUnitTriggerCount .. " 次觸發：滿足奇數序列，播放語音")
                end
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...  
        if unit and UNIT_CAST_TRACKER[unit] then
            UNIT_CAST_TRACKER[unit] = nil
        end
        if unit and auraTriggeredCache[unit] then
            auraTriggeredCache[unit] = nil
        end
        -- 清理時間戳和播放狀態
        UNIT_START_TIMES[unit] = nil
        UNIT_CAST_TRACKER[unit] = nil
        -- 如果還有之前 NewTimer 的句柄，也順手清理（雖然新邏輯不用了，但為了保險）
        if UNIT_CAST_TIMER_HANDLES[unit] then
            UNIT_CAST_TIMER_HANDLES[unit]:Cancel()
            UNIT_CAST_TIMER_HANDLES[unit] = nil
        end
        if unit then
            UNIT_CHANNEL_TRACKER[unit] = nil -- 徹底清除
        end
    end

    local bossData = AudioTimeline[currentEncounterID]
    if bossData and bossData.eventAlerts then
        local specificAlert = bossData.eventAlerts[event]
        if specificAlert then
            ProcessAlert(specificAlert, "Event:"..event)
            if type(specificAlert) == "table" and specificAlert.action then
                if specificAlert.action == "STOP" then
                    startTime = 0
                    lastPlayedSecond = -1
                    frame:SetScript("OnUpdate", nil) 
                    -- print("|cFFFF0000[TimelineAudio]|r 收到 STOP：時間軸已掛起")                    
                elseif specificAlert.action == "START" then
                    startTime = GetTime()
                    lastPlayedSecond = -1
                    frame:SetScript("OnUpdate", OnUpdate)
                    -- print("|cFF00FF00[TimelineAudio]|r 收到 START：時間軸已重新啟動")
                end
            end
        end
    end
end)



-- 1. 創建主框架
local RingFrame = CreateFrame("Frame", "MyCustomCircleTimer", UIParent)
RingFrame:SetSize(120, 120)
RingFrame:SetPoint("CENTER", 0, 0)
RingFrame:Hide()

-- 2. 創建底色圓環 (背景)
local bg = RingFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetTexture(RING_PATH)
bg:SetVertexColor(0, 0, 0, 0.3)

-- 3. 創建進度層
local cd = CreateFrame("Cooldown", nil, RingFrame, "CooldownFrameTemplate")
cd:SetAllPoints()
cd:SetDrawEdge(false)           
cd:SetDrawSwipe(true)           
cd:SetSwipeTexture(RING_PATH)   
cd:SetSwipeColor(0.4, 1, 0.8, 0.85) 
cd:SetHideCountdownNumbers(true)
cd:SetBlingTexture("")          

function StartMyCircleTimer(alert)
    -- 1. 只有當 alert 是 table 且包含 duration 字段時才繼續
    if type(alert) ~= "table" or not alert.duration then 
        return 
    end

    local duration = alert.duration
    
    -- 2. 執行倒計時邏輯
    local startTime = GetTime()
    
    -- --- 新增邏輯：同步全局變量 ---
    TargetEndTime = startTime + duration             -- 記錄全局結束時間
    CurrentRingIsCastSensitive = alert.checkCast     -- 從表中讀取 checkCast 參數
    UpdateRingColor(false)                           -- 恢復預設顏色
    -- ---------------------------

-- --- 核心修改：只有在勾選時才顯示 ---
    if DiGuaTimelineAudioHelper.ringEnabled then
        cd:SetCooldown(startTime, duration)
        RingFrame:Show()
    else
        RingFrame:Hide() -- 確保它是關閉的
    end
    
    -- 3. 動態延時隱藏
    C_Timer.After(duration, function()
        -- 減去 0.1 秒作為容錯緩衝
        if GetTime() >= (startTime + duration - 0.1) then
            RingFrame:Hide()
            -- 【核心修復】圓環徹底結束後，關閉讀條敏感標記，防止後續施法誤觸發
            CurrentRingIsCastSensitive = false
        end
    end)
end

function StartCircleTimerBySeconds(seconds, checkCast)
    -- 1. 安全檢查：確保傳入的是數字且大於 0
    local duration = tonumber(seconds)
    if not duration or duration <= 0 then 
        return 
    end

    -- 2. 執行倒計時邏輯
    local startTime = GetTime()
    TargetEndTime = startTime + duration -- 記錄全局結束時間
    -- print(TargetEndTime)
    CurrentRingIsCastSensitive = checkCast -- 記錄本次是否需要檢查施法

    UpdateRingColor(false) -- 先恢復預設顏色
-- --- 核心修改：只有在勾選時才顯示 ---
    if DiGuaTimelineAudioHelper.ringEnabled then
        cd:SetCooldown(startTime, duration)
        RingFrame:Show()
    else
        RingFrame:Hide()
    end
    
    -- 3. 動態延遲隱藏
    C_Timer.After(duration, function()
        -- 容錯緩衝：如果當前時間已經達到或超過預計結束時間，隱藏框架
        if GetTime() >= (startTime + duration - 0.1) then
            RingFrame:Hide()
        end
    end)
end

-- 4. 顏色切換函數
function UpdateRingColor(isAlarm)
    if isAlarm then
        PlaySoundFile(MEDIA_PATH .. "BuBu.ogg", "Master")
        cd:SetSwipeColor(unpack(RING_COLOR_ALARM))
    else
        cd:SetSwipeColor(unpack(RING_COLOR_NORMAL))
    end
end


-- ==========================================
-- 1. 數據庫初始化與路徑判定邏輯
-- ==========================================
-- 創建一個臨時的初始化框架
local initLoader = CreateFrame("Frame")
initLoader:RegisterEvent("ADDON_LOADED")

initLoader:SetScript("OnEvent", function(self, event, addonName)
    -- 只有當加載的插件是【你自己這個插件】時才執行
    if addonName == "DiGuaTimelineAudioHelper" then
        
        -- 1. 確保大表存在
        if DiGuaTimelineAudioHelper == nil then
            DiGuaTimelineAudioHelper = {
                enabled = true,
                ringEnabled = true,
                path = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
            }
        else
            -- 2. 老用戶補全邏輯
            if DiGuaTimelineAudioHelper.ringEnabled == nil then
                print("|cffffd100[DiGua]|r 檢測到新功能，已為你預設開啟倒計時光圈。")
                DiGuaTimelineAudioHelper.ringEnabled = true
            end
        end

        -- 3. 這裡執行 UI 狀態同步（如果你已經創建了按鈕）
        if cbRing then
            cbRing:SetChecked(DiGuaTimelineAudioHelper.ringEnabled)
        end
        
        -- 4. 執行完成後取消注冊，節省資源
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 定義全局變量 MEDIA_PATH
-- MEDIA_PATH = ""

-- 核心：路徑更新邏輯（根據“啟用狀態”和“聯動狀態”雙重判定）
local function RefreshMediaPath()
    if DiGuaTimelineAudioHelper.enabled == false then
        -- 如果禁用了，路徑指向 Mute 文件夾（實現靜音）
        MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Mute\\"
    else
        -- 如果啟用了，檢查是否有聯動語音包
        if C_AddOns.IsAddOnLoaded("DiGua-WYJJ") then
            MEDIA_PATH = "Interface\\AddOns\\DiGua-WYJJ\\Media\\"
        else
            MEDIA_PATH = "Interface\\AddOns\\DiGuaTimelineAudioHelper\\Media\\"
        end
    end
end

-- ==========================================
-- 2. UI 界面創建 (長名風格)
-- ==========================================
local f = CreateFrame("Frame", "DiGuaTimelineMainFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(170, 90)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()

-- 標題
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -3)
f.title:SetText("DiGua 控制台")

-- 復選框
local cb = CreateFrame("CheckButton", "DiGuaTimelineEnableCheck", f, "ChatConfigCheckButtonTemplate")
cb:SetPoint("CENTER", -45, -5)

-- 復選框文字
local cbText = _G[cb:GetName() .. "Text"]
cbText:SetText("啟用語音")
cbText:SetTextColor(1, 0.82, 0)
-- [新增] 復選框 2：啟用倒計時光圈
local cbRing = CreateFrame("CheckButton", "DiGuaTimelineRingCheck", f, "ChatConfigCheckButtonTemplate")
cbRing:SetPoint("TOPLEFT", 20, -65) -- 放在第一個按鈕下方
local cbRingText = _G[cbRing:GetName() .. "Text"]
cbRingText:SetText("顯示倒計時光圈")
cbRingText:SetTextColor(1, 0.82, 0)
-- ==========================================
-- 3. 事件與點擊邏輯
-- ==========================================

-- 注冊指令 /digua
SLASH_DIGUA1 = "/digua"
SlashCmdList["DIGUA"] = function()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- 點擊復選框時的邏輯
cb:SetScript("OnClick", function(self)
    -- 更新長名數據庫
    DiGuaTimelineAudioHelper.enabled = self:GetChecked()
    
    -- 直接刷新路徑變量
    RefreshMediaPath()
    
    -- 打印提示
    local status = DiGuaTimelineAudioHelper.enabled and "|cff00ff00已開啟|r" or "|cffff0000已禁用|r"
    print("|cffffd100[DiGua]|r 整體音效狀態: " .. status)
end)
-- [新增] 點擊復選框 2 (倒計時光圈)
cbRing:SetScript("OnClick", function(self)
    DiGuaTimelineAudioHelper.ringEnabled = self:GetChecked()
    local status = DiGuaTimelineAudioHelper.ringEnabled and "|cff00ff00已顯示|r" or "|cffff0000已隱藏|r"
    print("|cffffd100[DiGua]|r 倒計時光圈圖示狀態: " .. status)
end)
-- 監聽登錄事件進行初始化
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- 1. 同步 UI 狀態
        cb:SetChecked(DiGuaTimelineAudioHelper.enabled)
        cbRing:SetChecked(DiGuaTimelineAudioHelper.ringEnabled)
        -- 2. 初始計算路徑
        RefreshMediaPath()
        
    end
end)