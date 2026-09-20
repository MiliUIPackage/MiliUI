---------------------------------------------------------------
-- MiliUI Fix: 好友名單左上的狀態下拉顯示成「...」
-- Author: Mili
--
-- 症狀：好友名單左上那顆「有空／離開／忙碌」的下拉，框裡該顯示一顆狀態小圖，
--   實際顯示的是「...」。
--
-- 成因：暴雪把這顆下拉的寬度寫死成 51（FriendsFrame.lua 的
--   FriendsTabHeaderMixin:OnLoad → `self.StatusDropdown:SetWidth(51)`），而框裡的
--   「文字」其實是一張 16 寬的貼圖標記（`|T<狀態圖>.tga:16:16:0:0|t`）。
--   下拉模板（WowStyle1DropdownTemplate）的 Text 左邊內縮 8、右邊錨在箭頭鈕的左緣，
--   箭頭鈕約 28 寬 ⇒ 51 − 8 − 28 ＋ 1 ≈ 16，**剛好等於**那張圖的寬度，一點餘裕都沒有。
--   FontString 只要差不到 1 個單位放不下，就把整段截成「...」；換了字型
--   （套組的字型包）之後度量的零頭不一樣，就從「剛好放得下」變成「剛好放不下」。
--   跟任何換皮無關。
--
-- 修法：登入後把那顆下拉加寬 12（51 → 63）。它是用 RIGHT 錨在戰網名牌左邊的，
--   加寬只會往左長，左邊本來就是空的。
--
-- ⚠ 為什麼可以動它的寬度、又為什麼只動這一顆：
--   * 這是一個普通的（非保護）按鈕，只做一次、只在脫戰時做、不寫任何 Lua 欄位。
--   * **不要把同樣的手法拿去改清單列或名冊的寬度** —— 那種框會在同一輪更新裡把
--     寬度讀回去排版，寫過的尺寸會一路污染到後面的受保護動作。這顆下拉沒有人讀它的寬度。
---------------------------------------------------------------

local EXTRA_WIDTH = 12
local BLIZZARD_WIDTH = 51

local done = false

local function Widen()
    if done then return true end
    if InCombatLockdown() then return false end

    local dropdown = _G.FriendsFrameStatusDropdown
    if not dropdown or type(dropdown.SetWidth) ~= "function" then
        done = true          -- 暴雪改版把它拿掉了：靜默放棄，不要每次脫戰都重試
        return true
    end

    -- ⚠ 直接設成常數，不要 `GetWidth() + 12`：讀回來的尺寸在 12.1 可能是秘密數字，
    --   拿去做算術當場炸；而且重複執行會一直往上加。
    pcall(dropdown.SetWidth, dropdown, BLIZZARD_WIDTH + EXTRA_WIDTH)
    done = true
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        -- 延一幀：同一幀裡還有別的插件在跑自己的登入初始化
        C_Timer.After(0, function()
            if not Widen() then
                self:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
        end)
    elseif Widen() then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)
