------------------------------------------------------------
-- MiliUI: BugSack 預設值
-- 預設靜音錯誤音效（使用者仍可在 BugSack 設定中開啟）
------------------------------------------------------------

-- BugSack 的 ADDON_LOADED 檢查 type(sv.mute) ~= "boolean"，
-- 若已是 boolean 就不覆蓋，所以提前設好即可。
if type(BugSackDB) ~= "table" then BugSackDB = {} end
if type(BugSackDB.mute) ~= "boolean" then
    BugSackDB.mute = true
end
