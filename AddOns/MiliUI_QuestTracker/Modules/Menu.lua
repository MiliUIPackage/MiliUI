------------------------------------------------------------
-- 標題列的右鍵選單：**只有內容**
--
-- 選單引擎在共用層（Libs/MiliUIWidgets/ContextMenu.lua）—— 打勾欄、標題弱化、
-- 分隔線、子選單的關閉寬限期、貼齊螢幕全部由它處理。這裡只列項目，
-- 那是宿主自己的事（見 Libs/MiliUIWidgets/README.md 的規矩那節）。
--
-- 版面與互動的設計規則見 .claude/skills/miliui-menu-design。
--
-- 刻意**不放**在這裡的東西：
--   * 「顯示標題列」—— 這是自殺選項。關掉之後就沒有東西可以按右鍵，
--     玩家得去翻設定才救得回來。這種開關只能放設定頁。
--   * 「在編輯模式中移動」—— 移動追蹤器確實要走編輯模式，但從插件呼叫
--     ShowUIPanel(EditModeManagerFrame) 等於在**管著追蹤器保護狀態的那個系統**
--     上開一個污染入口。這支插件整個設計就是為了不碰那些東西，不值得為了
--     一個捷徑破例。設定頁的說明文字有寫要去編輯模式。
--   * 自動摺疊的七個條件 —— 那是設定好就不會再動的東西，塞進右鍵選單只會
--     讓它變長；而且共用層的子選單項目按下去會整個關掉，多選型的勾選在那裡
--     沒辦法「原地重畫」，違反設計規則。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local function Items()
    local au = ns.db.automation

    -- 開關型項目：keepOpen 讓選單不關，Reopen 原地重畫更新勾勾。
    -- 按一下就看得到勾起來／取消，不用重開一次確認自己有沒有按到
    local function Reopen()
        ns.W.Menu.Show(Items(), nil, true)
    end

    local items = {
        { text = L["MiliUI Quest Tracker"], isTitle = true },

        -- 動作，不是狀態 —— 所以用會變的動詞、不給打勾。
        -- 打勾在這份選單裡已經代表「這個開關是開的」，一個訊號只能有一個語意
        { text = ns.Visibility.IsFolded() and L["Unfold the list"] or L["Fold the list"],
          onClick = function() ns.Visibility.ToggleManualFold() end },

        { isSeparator = true },

        { text = L["Auto accept"], isActive = au.autoAccept, keepOpen = true,
          onClick = function()
              au.autoAccept = not au.autoAccept
              ns.Fire("SettingsChanged")
              ns.Chrome.Layout()
              Reopen()
          end },

        { text = L["Auto turn-in"], isActive = au.autoTurnIn, keepOpen = true,
          onClick = function()
              au.autoTurnIn = not au.autoTurnIn
              ns.Fire("SettingsChanged")
              ns.Chrome.Layout()
              Reopen()
          end },

        { isSeparator = true },
        { text = L["Open options"], onClick = function() ns.OpenOptions() end },
    }

    -- 位置是我們接管之後才有東西可以還，沒接管就不要放一個按了沒事的項目。
    -- 破壞性動作擺最後、跟一般項目隔一條線
    if ns.Position.IsOverridden() then
        items[#items + 1] = { isSeparator = true }
        items[#items + 1] = { text = L["Hand the position back to Edit Mode"],
                              onClick = function() ns.Position.Reset() end }
    end
    return items
end

-- ⚠ **不要**傳 anchor。傳了的話共用層會把選單掛在標題列的右下角，而標題列
--   跟追蹤器一樣寬 —— 在左邊按右鍵，選單卻從最右邊掉出來。
--   不傳就是貼著游標開，這也是聊天列與資訊列的行為。
--   代價是失去「同一顆再按一次＝關閉」，但點外面本來就會關，影響不大。
function ns.ShowTrackerMenu()
    ns.W.Menu.Show(Items())
end
