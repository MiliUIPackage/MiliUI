---------------------------------------------------------------
-- MiliUI Fix: 預組隊伍的搜尋結果帶秘密表時，那支插件每列洗一次錯
-- Author: Mili
--
-- 症狀：`Modules/Util.lua:48: bad argument #1 to 'pairs' (table expected, got secret)`，
--   堆疊是 LFGListSearchEntry_Update → OnLFGListSearchEntryUpdate → GetSearchResultInfo →
--   Table_Copy_Rec，一次開隊伍搜尋就幾百筆（2026-09-21 回報 258 次）。
--
-- 成因：它的 GetSearchResultInfo 先把 C_LFGList.GetSearchResultInfo 的結果**整張遞迴複製**
--   （為了之後往上面加自己的欄位）。插件限制生效時，結果裡有的子表是秘密表 ——
--   type() 照樣回 "table"，但 pairs() 不收，複製到那一層就炸。
--
-- 修法：讀不了的結果當作「沒有資料」回 nil。這是它本來就有的契約（原始碼自己寫著
--   C_LFGList.GetSearchResultInfo 偶爾回 nil），六個呼叫端全部都有 nil 閘：那一列
--   不上色、不加職責圖示、不參與過濾，照暴雪原樣顯示。資料都讀不到了，那些功能
--   本來就沒得做 —— 所以不是把錯誤吞掉，是不進去。
--
-- 第二個症狀（2026-09-22）：錯誤記在暴雪自己身上，
--   `LFGList.lua:3365: attempt to index field 'activityIDs' (a secret table value, while
--   execution tainted by 'PremadeGroupsFilter')`，堆疊整條是暴雪的（LFGListSearchEntry_Update）。
--   上游 #406（未關）同一條。
--
-- 成因：過濾的做法是改寫 LFGListFrame.SearchPanel.results，再從自己的程式呼叫
--   LFGListSearchPanel_UpdateResults 重畫。清單的每一列資料（elementData.resultID）因此是
--   髒執行建出來的，之後暴雪不管是當場初始化列、還是收到 LFG_LIST_SEARCH_RESULT_UPDATED
--   找那一列，一讀就整段變髒；髒執行不能碰秘密表，讀 activityIDs[1] 就炸。
--   乾淨的暴雪程式讀秘密表是合法的，所以只要清單是暴雪自己建的就沒事。
--
-- 修法：清單裡有讀不了的結果時，整次不發佈。那時它本來就過濾不了（上面那段讓每一筆都
--   回 nil ＝ 全部保留），發佈只剩「把暴雪剛建好的乾淨清單換成髒的」這個副作用。
--   限制中重新搜尋一次，清單就回到暴雪自己建的那份。
-- ⚠ 限制開始**之前**過濾過的清單救不回來：那份早就是髒的，限制中收到該列的更新照樣會炸，
--   直到下一次搜尋。插件沒有辦法用乾淨的執行重建它（上游作者在 #403 也是這個結論）。
--
-- ⚠ 它的私有命名空間靠 `PremadeGroupsFilter.Debug` 才摸得到（Init.lua）。上游拿掉那個
--   欄位這支就靜默失效，錯誤會回來。
-- ⚠ 只擋「秘密表」。純量的秘密值（數字／字串）它是原樣帶著走，目前沒有看到因此出錯，
--   沒有證據就不先擋。
---------------------------------------------------------------

local issecrettable, canaccesstable = issecrettable, canaccesstable
if type(issecrettable) ~= "function" and type(canaccesstable) ~= "function" then return end

local function Unreadable(t)
    if issecrettable and issecrettable(t) then return true end
    if canaccesstable and not canaccesstable(t) then return true end
    return false
end

-- 搜尋結果只有兩三層，不會有環
local function HasUnreadableTable(t)
    if Unreadable(t) then return true end
    for _, v in pairs(t) do
        if type(v) == "table" and HasUnreadableTable(v) then return true end
    end
    return false
end

local function IsUnreadableResult(resultID)
    local raw = C_LFGList.GetSearchResultInfo(resultID)
    return type(raw) == "table" and HasUnreadableTable(raw)
end

local function HasUnreadableResult(results)
    if Unreadable(results) then return true end
    for i = 1, #results do
        if IsUnreadableResult(results[i]) then return true end
    end
    return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local PGF = _G.PremadeGroupsFilter and _G.PremadeGroupsFilter.Debug
    local orig = type(PGF) == "table" and PGF.GetSearchResultInfo
    if type(orig) ~= "function" then return end

    PGF.GetSearchResultInfo = function(resultID, ...)
        if IsUnreadableResult(resultID) then return nil end
        return orig(resultID, ...)
    end

    -- 兩個呼叫端（搜尋結果更新的掛勾、改過濾條件）都是 PGF.FilterSearchResults() 查表呼叫
    local origFilter = PGF.FilterSearchResults
    if type(origFilter) ~= "function" then return end

    PGF.FilterSearchResults = function(...)
        local results = PGF.currentSearchResults
        if type(results) == "table" and HasUnreadableResult(results) then return end
        return origFilter(...)
    end
end)
