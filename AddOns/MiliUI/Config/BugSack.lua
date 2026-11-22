------------------------------------------------------------
-- MiliUI: BugSack 預設值
-- 預設靜音錯誤音效（使用者仍可在 BugSack 設定中開啟）
------------------------------------------------------------

-- 不能在檔案載入當下先把 BugSackDB.mute 寫好就算數：BugSack 的字母順序在 MiliUI 前面，
-- 它的 ADDON_LOADED 早就跑完、把沒設過的 mute 補成 false 了。等我們載入時那已經是
-- boolean，分不出「玩家自己關的」還是「它補的預設」——舊寫法因此從來沒生效過。
--
-- 所以改成每個帳號只套一次：MiliUI 的存檔到貨之後把 mute 設成 true、記一顆旗標，
-- 之後玩家在 BugSack 設定裡取消靜音就不會再被改回來。
-- BugSack 執行中用的設定表就是 BugSackDB 本身，直接寫欄位當場生效、設定頁的勾也跟著對。
local AddonName = ...
if AddonName ~= "MiliUI" then return end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
    if name ~= AddonName then return end
    self:UnregisterEvent("ADDON_LOADED")

    if type(MiliUI_DB) ~= "table" then MiliUI_DB = {} end
    if MiliUI_DB.bugSackMuteApplied then return end
    -- 沒裝／沒啟用 BugSack 就先不記旗標，等哪天裝了再套
    if type(BugSackDB) ~= "table" then return end

    BugSackDB.mute = true
    MiliUI_DB.bugSackMuteApplied = true
end)
