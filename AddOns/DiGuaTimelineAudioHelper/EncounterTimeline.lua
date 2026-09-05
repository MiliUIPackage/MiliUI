-- EncounterTimeline.lua
-- 处理 Boss 战斗时间轴音频警报的核心逻辑

local addonName, addonTable = ...

addonTable.AudioTimeline = {

    [2139] = { -- 黄金风蛇
        interval = 65, 
        startOffset = 0, 
        alerts = {
            [18] = "DaoShu3.ogg",
            [19] = "DaoShu2.ogg",
            [20] = "DaoShu1.ogg",
            [21] = "AnQuan.ogg",
            [46] = "DaoShu3.ogg",
            [47] = "DaoShu2.ogg",
            [48] = "DaoShu1.ogg",
            [49] = "AnQuan.ogg",
        }
    },

    [2142] = { -- 殓尸者姆沁巴
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [33] = "ZhuanHuoXiaoGuai.ogg",

        }
    },

    [2606] = { -- 柯姬雅·焰蹄
        interval = 40, 
        startOffset = 0, 
        alerts = {
            [13]  = "ZhuanHuoDaGuai.ogg",
            -- [8]  = "DaoShu5.ogg",
            -- [9]  = "DaoShu4.ogg",
            -- [10]  = "DaoShu3.ogg",
            -- [11]  = "DaoShu2.ogg",
            -- [12]  = "DaoShu1.ogg",
        }
    },

    [3103] = { -- 歼灭者萨祖克斯
        interval = 57, 
        startOffset = 0, 
        alerts = {
            [14]  = "ZhunBeiXiaoGuai.ogg",
        }
    },


    
    -- [3200] = { -- 圣光猎手伊库兹
    --     interval = 65, 
    --     startOffset = 0, 
    --     alerts = {
    --         -- [7]  = "DaoShu3.ogg",
    --         -- [8]  = "DaoShu2.ogg",
    --         -- [9]  = "DaoShu1.ogg",
    --         -- [9]  = "JiHeFangQuan.ogg",
    --         -- [24]  = "ZhuYiDuoQuan.ogg",
    --         -- [25]  = "KuaiKaiJianShang.ogg",
    --     }
    -- },

    [3209] = { -- 纳洛拉克
        interval = 65, 
        startOffset = 0, 
        alerts = {
            [15]  = "WuMiaoHouAOE.ogg",
            [17]  = "DaoShu3.ogg",
            [18]  = "DaoShu2.ogg",
            [19]  = "DaoShu1.ogg",
            [20]  = "XiaoXinJiTui.ogg",
            -- [21]  = "DaoShu2.ogg",
            -- [22]  = "DaoShu1.ogg",
            [23]  = "TanKeJieQuan.ogg",
            [40]  = "WuMiaoHouAOE.ogg",
            [42]  = "DaoShu3.ogg",
            [43]  = "DaoShu2.ogg",
            [44]  = "DaoShu1.ogg",
            [45]  = "XiaoXinJiTui.ogg",
            -- [46]  = "DaoShu2.ogg",
            -- [47]  = "DaoShu1.ogg",
            [48]  = "TanKeJieQuan.ogg",
        }
    },

    [3285] = { -- 塔兹拉尔
        interval = 70, 
        startOffset = 0, 
        alerts = {
            [15]  = "DuoQuan.ogg",
            [51]  = "DuoQuan.ogg",
        }
    },

    [3287] = { -- 煞戎努斯
        interval = 53, 
        startOffset = 0, 
        alerts = {
            [24]  = { file = "KuaiKaiJianShang.ogg", role = {"HEALER", "DAMAGER"} },
        }
    },


    [3456] = { -- 拉维
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [0]  = "ZhunBeiAOE.ogg",
            [2]  = "ZhuYiDuoQuan.ogg",
            [28] = "ZhuYiJieQuan.ogg",
        }
    },

    [3470] = { -- 盘魂者内克扎莉
        interval = 999, 
        startOffset = 0, 
        alerts = {
            [2]  = "ZhuYiDuoQuan.ogg",
            [22] = { file = "QuSanMoFa.ogg", role = "HEALER" },
        }
    },



    -- [1810] = { --测试
    --     -- 子表 key = 副本难度ID（数字）：2=5人英雄、16=史诗团本
    --     [23] = { 
    --         interval = 999, 
    --         startOffset = 0, 
    --         alerts = {
    --             [5]  = "FenTanShangHai.ogg", -- 27秒 分担伤害

    --         }
    --     },
    -- },



    [3492] = { -- 乌拉特克：按难度区分（5人英雄 difficultyID=2 / 史诗团本 difficultyID=16）
        -- 子表 key = 副本难度ID（数字）：5人英雄填2、史诗团本填16
        [15] = { -- 英雄难度 (difficultyID=2)
            interval = 999, 
            startOffset = 0, 
            alerts = {
                [27]  = "FenTanShangHai.ogg", -- 27秒 分担伤害
                [122] = "FenTanShangHai.ogg", -- 2分02秒 分担伤害
                [151] = "DaoShu5.ogg", -- 2分31秒 倒计时5
                [152] = "DaoShu4.ogg", -- 2分32秒 倒计时4
                [153] = "DaoShu3.ogg", -- 2分33秒 倒计时3
                [154] = "DaoShu2.ogg", -- 2分34秒 倒计时2
                [155] = "DaoShu1.ogg", -- 2分35秒 倒计时1
                [156] = "YiShangJieShu.ogg", -- 2分36秒 倒数结束
                [188] = "ZhunBeiLaXian.ogg", -- 3分08秒 准备拉线
                [300] = "DaoShu5.ogg", -- 5分钟整 倒计时5
                [301] = "DaoShu4.ogg", -- 5分01秒 倒计时4
                [302] = "DaoShu3.ogg", -- 5分02秒 倒计时3
                [303] = "DaoShu2.ogg", -- 5分03秒 倒计时2
                [304] = "DaoShu1.ogg", -- 5分04秒 倒计时1
                [305] = "YiShangJieShu.ogg", -- 5分05秒 倒数结束
                [412] = "ZhuYiDuoBo.ogg", -- 6:52.2 腐蚀浪潮
                [451] = "ZhuanHuoDaGuai.ogg", -- 7分32秒 转火大怪
                [467] = "ZhuYiDuoBo.ogg", -- 7:47.2 腐蚀浪潮
                [511] = "ZhuanHuoDaGuai.ogg", -- 8分31秒 转火大怪
                [517] = "ZhuYiDuoBo.ogg", -- 8:37.2 腐蚀浪潮
                [561] = "ZhuYiDuoBo.ogg", -- 9:21.2 腐蚀浪潮
                [589] = "DaoShu5.ogg", -- 9分49秒 倒计时5
                [590] = "DaoShu4.ogg", -- 9分50秒 倒计时4
                [591] = "DaoShu3.ogg", -- 9分51秒 倒计时3
                [592] = "DaoShu2.ogg", -- 9分52秒 倒计时2
                [593] = "DaoShu1.ogg", -- 9分53秒 倒计时1
                [594] = "YiShangJieShu.ogg", -- 9分54秒 倒数结束
            }
        },

        -- [16] = { -- 史诗团本难度 (difficultyID=16)
        --     interval = 999, 
        --     startOffset = 0, 
        --     alerts = {
        --     }
        -- },
    },

}

-- ===== 按副本难度区分时间轴配置 =====
-- AudioTimeline 每个首领的数据支持两种写法：
--   旧格式（不区分难度）：{ interval = ..., startOffset = ..., alerts = ... }
--   新格式（按难度区分）：{ [难度ID数字] = {...}, ... }
--     子表 key 直接填副本难度 ID（数字），如 2=5人英雄、8=5人史诗/大秘境、
--     14=团本普通、15=团本英雄、16=史诗团本；当前难度匹配不到就返回 nil 不播
local function ResolveDifficultyData(bossData)
    -- 旧格式：直接含 interval 字段，无需区分难度
    if bossData.interval ~= nil then return bossData end

    -- GetInstanceInfo 现代返回：name, instanceType, difficultyID, difficultyName, ...
    -- 难度ID 在第3位（数字），用它去匹配数字 key 子表
    local _, _, difficultyID = GetInstanceInfo()

    -- 新格式：只返回当前难度对应的子表；匹配不到返回 nil（不播）。
    -- ⚠️ 不要回退到任意子表，否则设了 8 还会在普通难度误播
    return difficultyID and bossData[difficultyID] or nil
end

local startTime = 0
local currentEncounterID = 0
local lastPlayedSecond = -1

local frame = CreateFrame("Frame")

local function OnUpdate(self, elapsed)
    if startTime == 0 or currentEncounterID == 0 then return end

    local now = GetTime()
    local currentSecond = math.floor(now - startTime)
    if currentSecond < 0 or currentSecond == lastPlayedSecond then return end
    lastPlayedSecond = currentSecond

    local bossData = addonTable.AudioTimeline[currentEncounterID]
    if not bossData then return end

    -- 按当前副本难度解析配置（旧格式直接返回；新格式匹配不到当前难度返回 nil，不播）
    bossData = ResolveDifficultyData(bossData)
    if not bossData then return end

    local relativeTime = now - startTime - bossData.startOffset
    if relativeTime >= 0 then
        local moduloTime = relativeTime % bossData.interval
        
        -- 获取当前玩家职责
        local playerRole = UnitGroupRolesAssigned("player")

        for triggerTime, alert in pairs(bossData.alerts) do
            if moduloTime >= triggerTime and moduloTime < (triggerTime + 0.8) then
                local soundFile = nil
                local requiredRole = nil

                if type(alert) == "table" then
                    soundFile = alert.file
                    requiredRole = alert.role
                else
                    soundFile = alert
                end

                -- 职责匹配逻辑：无要求 / 单字符串匹配 / 数组包含匹配
                local roleMatched = false
                if not requiredRole then
                    roleMatched = true
                elseif type(requiredRole) == "string" then
                    roleMatched = (requiredRole == playerRole)
                elseif type(requiredRole) == "table" then
                    for _, r in ipairs(requiredRole) do
                        if r == playerRole then
                            roleMatched = true
                            break
                        end
                    end
                end

                if soundFile and roleMatched then
                    PlaySoundFile(addonTable.GetMediaPath() .. soundFile, DiGuaTimelineAudioHelper.audioChannel)
                end
                break 
            end
        end
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")

-- 抽离出来的“恢复普通光环”辅助函数
local function SafeRegisterAuras()
    C_Timer.After(0.5, function()
        if not DiGuaTimelineAudioHelper.bossVoiceEnabled then
            if addonTable.RegisterNormalAuras then
                addonTable.RegisterNormalAuras()
                -- print("|cffffd100[DiGua]|r 注册光环音频")
            end
        end
    end)
end

frame:SetScript("OnEvent", function(self, event, encounterID)
    if event == "ENCOUNTER_START" then
        -- 核心逻辑：只有在【没勾选】首领语音时，才注销普通光环
        if not DiGuaTimelineAudioHelper.bossVoiceEnabled then
            if addonTable.UnregisterNormalAuras then
                addonTable.UnregisterNormalAuras()
                -- print("注销光环音频")
            end
            -- 拦截首领语音时间轴，不启动 OnUpdate
            return
        end

        -- 勾选了首领语音：正常启动首领语音时间轴（不影响普通光环）
        currentEncounterID = encounterID
        startTime = GetTime()
        lastPlayedSecond = -1
        frame:SetScript("OnUpdate", OnUpdate)

    elseif event == "ENCOUNTER_END" then
        -- 1. 重置首领语音时间轴
        startTime = 0
        currentEncounterID = 0
        frame:SetScript("OnUpdate", nil)

        -- 2. 如果【没勾选】首领语音，准备重新注册普通光环
        if not DiGuaTimelineAudioHelper.bossVoiceEnabled then
            if not InCombatLockdown() then
                -- 非战斗状态：直接延迟 0.5 秒注册
                SafeRegisterAuras()
            else
                -- 战斗中：开启脱战事件监听，等脱战后再触发注册
                self:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- 脱战后触发注册
        SafeRegisterAuras()
        -- 注册完成后注销脱战事件，防止平时无谓触发
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)

function addonTable.GetStartTime() return startTime end
function addonTable.GetEncounterID() return currentEncounterID end
