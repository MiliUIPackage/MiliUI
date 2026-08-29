-- LFG_PROPOSAL_SHOW.lua
-- 监听"副本准备就绪"事件（组队查找器弹出确认框），播放副本就绪提示音
-- 由控制台"副本就绪提示音"开关控制（默认关闭）

local addonName, addonTable = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("LFG_PROPOSAL_SHOW")

frame:SetScript("OnEvent", function(self, event, ...)
    local MEDIA_PATH = addonTable.GetMediaPath and addonTable.GetMediaPath() or ""

    -- 安全检查：开关未开启则直接返回（默认关闭）
    if not DiGuaTimelineAudioHelper.lfgProposalSound then return end

    PlaySoundFile(MEDIA_PATH .. "ZuDuiJiuXu.ogg", DiGuaTimelineAudioHelper.audioChannel)
end)
