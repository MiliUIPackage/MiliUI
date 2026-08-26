------------------------------------------------------------
-- 聊天列的右鍵選單：**只有內容**
--
-- 選單引擎已經搬進共用層（Libs/MiliUIWidgets/ContextMenu.lua）——
-- 這支跟 MiliUI_DamageMeters 各自帶一份幾乎一樣的引擎，結果同一個
-- 「ESC 關不掉」的 bug 要修兩次。照 MiliUIWidgets 本來的道理收成 vendor 包。
--
-- 這裡只留「有哪些項目」：那是宿主自己的事，不該寫回共用層
-- （見 Libs/MiliUIWidgets/README.md 的規矩那節）。
--
-- 用法與 items 的欄位見 ContextMenu.lua 的檔頭；版面規則見
-- .claude/skills/miliui-menu-design。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

------------------------------------------------------------
-- 聊天列自己的那一份選單
--
-- 開關型項目 keepOpen ＋ 原地重畫（Reopen）：按一下看得到勾起來／取消，
-- 不用重開選單確認自己按到了沒有。
------------------------------------------------------------
local function Items()
    ns.InitDB()
    local cb = MiliUI_ChatBar_DB.Chatbar
    local horizontal = cb.Orientation ~= "VERTICAL"

    local function Reopen()
        ns.W.Menu.Show(Items(), nil, true)
    end

    return {
        { text = L["ADDON_TITLE"], isTitle = true },

        { text = L["MENU_LOCK"], isActive = cb.Locked, keepOpen = true,
          onClick = function() ns.SetLocked(not cb.Locked); Reopen() end },

        { text = L["GROUP_WITH_CHAT"], isActive = cb.GroupWithChat, keepOpen = true,
          onClick = function() ns.SetGroupWithChat(not cb.GroupWithChat); Reopen() end },

        { text  = L["ORIENTATION"],
          value = horizontal and L["ORIENT_HORIZONTAL"] or L["ORIENT_VERTICAL"],
          submenu = {
              { text = L["ORIENTATION"], isTitle = true },
              { text = L["ORIENT_HORIZONTAL"], isActive = horizontal,
                onClick = function() ns.SetOrientation("HORIZONTAL") end },
              { text = L["ORIENT_VERTICAL"], isActive = not horizontal,
                onClick = function() ns.SetOrientation("VERTICAL") end },
          } },

        { isSeparator = true },
        { text = L["CONTEXT_OPEN_SETTINGS"], onClick = function() ns.OpenSettings() end },

        -- 重置擺最後、跟一般項目隔一條線：破壞性動作不能混在順手點的位置
        { isSeparator = true },
        { text = L["RESET_POSITION"], onClick = function() ns.ResetPosition() end },
    }
end

function ns.ShowBarMenu()
    ns.W.Menu.Show(Items())
end
