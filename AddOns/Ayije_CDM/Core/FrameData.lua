local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

local CDM_FrameData = setmetatable({}, { __mode = "k" })

local function GetFrameData(frame)
    local data = CDM_FrameData[frame]
    if not data then
        data = {}
        CDM_FrameData[frame] = data
    end
    return data
end

CDM.GetFrameData = GetFrameData
