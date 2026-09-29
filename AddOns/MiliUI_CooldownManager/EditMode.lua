------------------------------------------------------------
-- 編輯模式整合
--
-- 這一階段只有唯讀的狀態查詢。拖曳（四條暴雪檢視器拖容器、自訂條走
-- EditModeSystemSelectionTemplate）、齒輪開設定頁、進出處理器的戰鬥閘，
-- 都在編輯模式那一階段補進這支。
------------------------------------------------------------
local _, ns = ...

ns.EditMode = {}
local EditMode = ns.EditMode

-- 只讀不寫：編輯模式不會被戰鬥關掉、戰鬥中也能進出，讀狀態本身沒有限制
function EditMode.IsActive()
    local mgr = EditModeManagerFrame
    if not (mgr and mgr.IsEditModeActive) then return false end
    local ok, active = pcall(mgr.IsEditModeActive, mgr)
    if not ok or ns.IsSecret(active) then return false end
    return active and true or false
end
