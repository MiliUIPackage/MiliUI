------------------------------------------------------------
-- 最近場次的下拉
--
-- 引擎走共用層的 W.Menu（右鍵／情境選單那一支）—— **「有哪些項目」是宿主自己的事**，
-- 所以清單組在這裡，不寫回共用層。
--
-- 版面規則（miliui-menu-design）：
--   * 標題比內容**弱**（灰、小一級、底下髮絲線），已選比內容**強**（強調色＋打勾）。
--     兩者往相反方向走，才不會讓「標題」跟「目前這一場」長得一模一樣。
--   * 打勾走共用層的材質，不用 `✓` 字元 —— 中文字型沒有那個字，會變方框。
--   * 打勾欄是固定寬的，沒勾的列也留位置，文字才對得齊。
--   * 父按鈕上直接顯示目前選的是哪一場，不要讓人「點開才知道自己選了什麼」。
--   以上除了清單內容以外全部由 W.Menu 負責，這裡只要把 isActive 標對。
------------------------------------------------------------
local _, ns = ...

ns.HistoryMenu = {}
local Menu = ns.HistoryMenu

local L = ns.L
local H = ns.History

-- 下拉最多列幾場。歷史本身可以存到 200 筆，但一次列出來只會變成一根捲不動的長條；
-- 20 筆大約是「最近幾天」，真要翻更早的是另一種需求（雛形不做）
local MAX_ITEMS = 20

local function BuildItems()
    local items = {}
    local current = ns.Panel.CurrentRun()

    items[#items + 1] = { text = L["Recent runs"], isTitle = true }

    local n = H.Count()
    if n == 0 then
        items[#items + 1] = { text = L["No runs recorded yet"], isTitle = true }
        return items
    end

    local limit = math.min(n, MAX_ITEMS)
    for i = 1, limit do
        local run = H.Get(i)
        if run then
            items[#items + 1] = {
                text = H.Label(run),
                -- 同一張表才算同一場：id 可能撞號（同一秒打完兩場不可能，但
                -- 比對參照本來就更準，而且不必信任存檔裡的數字）
                isActive = (run == current),
                onClick = function()
                    ns.Panel.SetRun(run)
                end,
            }
        end
    end

    -- ⚠ 這裡刻意沒有分隔線：分隔線只留給「換一段沒有名字的東西」，而這張清單
    --   從頭到尾只有一個小節。破壞性動作（清除全部歷史）在設定頁，不放進來。
    return items
end

function Menu.Toggle(anchorBtn)
    local W = ns.W
    if W.Menu.IsOpenFor(anchorBtn) then
        W.Menu.Hide()
        return
    end
    W.Menu.Show(BuildItems(), anchorBtn)
end

function Menu.Close()
    local W = ns.W
    if W and W.Menu then W.Menu.Hide() end
end
