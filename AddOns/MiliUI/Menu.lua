------------------------------------------------------------
-- 米利UI選單項目的註冊表：各米利系列插件把自己的「開設定」入口掛進來。
-- 讀它的人：插件總覽與快速設定面板（名冊的 menuKey 對這裡的 key，
-- 見 Options/Tab_Addons.lua 的 ResolveOpen）。
-- 原本還有一張「滑過 ESC 選單按鈕往上展開」的直式選單畫這張表，2026-11-28 拿掉了，
-- 改成按鈕左鍵開快速設定面板（Options/QuickPanel.lua）。註冊接口不變。
--
-- ── 對外接口 ──────────────────────────────────────────────
-- 其他米利系列插件這樣掛一筆進來（放在自己的入口檔就好）：
--
--   MiliUI_MenuEntries = MiliUI_MenuEntries or {}
--   MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
--       key     = "unitframes",             -- 唯一鍵，同鍵重複註冊後者覆蓋前者
--       text    = L["MiliUI Unit Frames"],  -- 顯示文字，自己在地化
--       icon    = "Interface\\Icons\\...",  -- 選填，省略用套組圖示
--       order   = 10,                       -- 選填，小的排前面；同序再比文字
--       OnClick = function() ns.OpenOptions() end,
--   }
--
-- 走「往全域表裡塞」而不是「呼叫 MiliUI 的函式」是刻意的：註冊方與 MiliUI 之間
-- 沒有相依宣告，誰先載入不一定；而且玩家可能只裝單一插件、根本沒有 MiliUI。
-- 直接塞表兩種情況都不會炸，MiliUI.RegisterMenuEntry 只是同一件事的糖。
------------------------------------------------------------

local _, _ = ...

MiliUI = MiliUI or {}
MiliUI.Menu = MiliUI.Menu or {}
local M = MiliUI.Menu

-- 註冊表本身是全域的（見檔頭），MiliUI 沒載入時註冊方自己建。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}

function MiliUI.RegisterMenuEntry(entry)
    if type(entry) ~= "table" then return end
    MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = entry
end

------------------------------------------------------------
-- 讀註冊表 → 去重 → 排序
------------------------------------------------------------
function M.GetEntries()
    local list, seen = {}, {}
    for _, e in ipairs(MiliUI_MenuEntries) do
        if type(e) == "table" and type(e.text) == "string" and type(e.OnClick) == "function" then
            local key = e.key or e.text
            if seen[key] then
                list[seen[key]] = e     -- 插件重複註冊（例如 /reload 之外的重進）不長出第二列
            else
                list[#list + 1] = e
                seen[key] = #list
            end
        end
    end
    table.sort(list, function(a, b)
        local ao, bo = a.order or 100, b.order or 100
        if ao ~= bo then return ao < bo end
        return a.text < b.text
    end)
    return list
end

function M.HasEntries()
    return #M.GetEntries() > 0
end
