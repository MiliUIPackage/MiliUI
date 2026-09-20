-- SkipCinematic.lua
-- 自动跳过过场动画
--
-- 参考 DBM / BigWigs 的“跳过动画”思路，分两类处理：
--   1) CINEMATIC_START —— 游戏内过场动画：
--        真实过场动画 → StopCinematic()  （直接跳过，不会弹“是否跳过”确认框）
--        载具/脚本场景 → CanCancelScene() 为真时 CancelScene()
--   2) PLAY_MOVIE      —— 预渲染影片：优先 MovieFrame:StopMovie()，没有该方法时退回 Hide()
--
-- 生效范围（强制开启，无控制台开关）：
--   诸王之眠（1762，5人本）：仅【大秘境】环境
--   烈毒之渊（3004，团本）  ：【英雄】/【史诗】难度
--   其余副本 / 难度不生效

local addonName, addonTable = ...

-- ==================== 生效条件 ====================
local INSTANCE_JINJI = 1762 -- 副本ID（诸王之眠，5人本）
local INSTANCE_LIEDU = 3004 -- 副本ID（烈毒之渊，团本）

-- 团本难度ID：15 = 英雄，16 = 史诗（14 = 普通）
local RAID_DIFFICULTY_HEROIC = 15
local RAID_DIFFICULTY_MYTHIC = 16

-- 大秘境进行中（不在钥石副本时返回 nil；第一返回值就是钥石等级）
local function IsMythicPlusActive()
    if not (C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo) then return false end
    local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
    return keystoneLevel ~= nil and keystoneLevel >= 2
end

local function ShouldAutoSkip()
    local difficultyID = select(3, GetInstanceInfo())
    local instanceID   = select(8, GetInstanceInfo())

    -- 诸王之眠（5人本）：仅大秘境
    if instanceID == INSTANCE_JINJI then
        return IsMythicPlusActive()
    end

    -- 烈毒之渊（团本）：英雄 / 史诗 难度
    if instanceID == INSTANCE_LIEDU then
        return difficultyID == RAID_DIFFICULTY_HEROIC
            or difficultyID == RAID_DIFFICULTY_MYTHIC
    end

    return false
end

-- ==================== 跳过逻辑 ====================

-- 真实过场动画：直接停止（不会弹“是否跳过”确认框）
local function StopRealCinematic()
    if type(StopCinematic) ~= "function" then return false end
    StopCinematic()
    return true
end

-- 载具/脚本场景：只有在可取消时才取消，避免对不可取消的场景乱来
local function CancelSceneIfPossible()
    if type(CanCancelScene) ~= "function" or type(CancelScene) ~= "function" then
        return false
    end
    if CanCancelScene() then
        CancelScene()
        return true
    end
    return false
end

-- 跳过当前过场动画
-- 注意：CINEMATIC_START 的第一个参数 canBeCancelled 命名有误导性——
--       true = “真实过场动画”，false = 载具/脚本场景（需要用 CancelScene）。
local function SkipCinematic(canBeCancelled)
    -- 明确是载具/脚本场景：优先 CancelScene，失败再试 StopCinematic
    if canBeCancelled == false then
        return CancelSceneIfPossible() or StopRealCinematic()
    end
    -- 真实过场动画，或状态未知（如载入画面结束后补检）：优先 StopCinematic
    return StopRealCinematic() or CancelSceneIfPossible()
end

-- 跳过预渲染影片
local function SkipMovie()
    if not MovieFrame then return false end
    if type(MovieFrame.IsShown) == "function" and not MovieFrame:IsShown() then return false end

    -- 官方 StopMovie 优先（能真正停止播放，而不只是隐藏画面）
    if type(MovieFrame.StopMovie) == "function" then
        local ok = pcall(MovieFrame.StopMovie, MovieFrame)
        if ok then return true end
    end
    -- 兜底：隐掉影片框
    MovieFrame:Hide()
    return true
end

local function NotifySkipped()
    print("|cffffd100[DiGua]|r 已自动跳过过场动画")
end

-- ==================== 事件监听 ====================
local frame = CreateFrame("Frame")
frame:RegisterEvent("CINEMATIC_START")
frame:RegisterEvent("PLAY_MOVIE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, canBeCancelled)
    if not ShouldAutoSkip() then return end

    if event == "CINEMATIC_START" then
        if SkipCinematic(canBeCancelled) then NotifySkipped() end

    elseif event == "PLAY_MOVIE" then
        if SkipMovie() then NotifySkipped() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 有部分过场动画在载入画面结束时才播放，因加载顺序可能收不到 CINEMATIC_START，
        -- 这里延迟补检一次（同 DialogueUI 的做法）。
        C_Timer.After(0.3, function()
            if not ShouldAutoSkip() then return end
            if CinematicFrame and CinematicFrame:IsShown() then
                if SkipCinematic(CinematicFrame.isRealCinematic) then NotifySkipped() end
            end
        end)
    end
end)

-- ==================== 对外接口 ====================
-- 手动触发一次跳过（不受副本限制，供调试/其它模块用）
addonTable.SkipCurrentCinematic = function() return SkipCinematic(true) end
