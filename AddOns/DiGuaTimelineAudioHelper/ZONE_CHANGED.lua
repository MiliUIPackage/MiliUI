-- -- ZONE_CHANGED.lua
-- -- 进入“四角庭院 / 學院中庭”子区域时，播放一次增益提示音（XuanZeZengYi）

-- local addonName, addonTable = ...

-- local lastSubZone = nil -- 记录上一次子区域：用于“每次进入播一次、且不被 ZONE 三连事件重复播”

-- local frame = CreateFrame("Frame")
-- frame:RegisterEvent("ZONE_CHANGED")

-- frame:SetScript("OnEvent", function()
--     local subZone = GetSubZoneText()

--     -- 只在“离开该子区域后再进入”的瞬间触发一次；
--     -- 同一次进入连续触发的 ZONE_CHANGED / _INDOORS / _NEW_AREA 只会播一次
--      (GetSubZoneText() == "漫长寒冬" or GetSubZoneText() == "恆常凜冬") -- 子区域 (漫长寒冬)



-- end)
