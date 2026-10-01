------------------------------------------------------------
-- MiliUI: 吃掉神秘地瓜（DiGuaTimelineAudioHelper）的登入歡迎訊息
--
-- 地瓜在 PLAYER_LOGIN 後 2 秒 `print("感谢使用[神秘地瓜副本语音插件]/digua 可开启控制台")`。
-- 以前是直接改 Core.lua 註解掉，每次上游更新都要重改、常漏掉，改成從這裡擋。
--
-- ## 掛在 print handler，不換全域 print
--
-- `print` 是 Blizzard_PrintHandler.lua 的 `print → securecall(pcall, print_inner)`，
-- print_inner 先 `forceinsecure()` 再呼叫 `setprinthandler` 設的 handler ——
-- handler 本來就跑在不安全的執行裡，換掉它不會染到任何人。
-- 反過來寫 `_G.print` 是全域寫入，還原了變數照樣髒，不採用。
--
-- 只在登入那一小段時間掛著：吃到那一行、或 10 秒逾時就換回原本的 handler
-- （換回前確認目前還是我們的，別人在中間換過就不動）。
-- 掛著的期間 Chattynator 用 debugstack 深度判斷訊息來源，會多算一層 ——
-- 這幾秒內其他插件 print 的來源標記會不準，不影響顯示。
------------------------------------------------------------

local function IsDiGuaWelcome(msg)
    return type(msg) == "string" and not issecretvalue(msg)
        and (msg:find("^感谢使用") or msg:find("^感謝使用"))
        and msg:find("神秘地瓜", 1, true)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    -- 登入時所有插件都載完了，這裡判斷才不受載入順序影響
    if not C_AddOns.IsAddOnLoaded("DiGuaTimelineAudioHelper") then return end

    local original = getprinthandler()
    local filter
    local function Restore()
        if getprinthandler() == filter then
            setprinthandler(original)
        end
    end
    filter = function(...)
        if select("#", ...) == 1 and IsDiGuaWelcome(...) then
            Restore()
            return
        end
        return original(...)
    end

    setprinthandler(filter)
    C_Timer.After(10, Restore)
end)
