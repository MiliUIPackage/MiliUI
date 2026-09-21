---------------------------------------------------------------
-- MiliUI Fix: 預組隊伍右上角的「PGF」勾選框標籤被截成「P...」
-- Author: Mili
--
-- 症狀：地城與團隊 → 預組隊伍的搜尋頁，右上那顆勾選框旁邊的字顯示成「P...」。
--
-- 成因：那支插件把標籤寬度寫死成 30（UI/UsePGFButton.lua 的
--   `self.Text:SetWidth(30)`），文字是固定的「PGF」三個字母。套組的字型比暴雪
--   預設字型寬，30 放不下，FontString 就整段截成「...」。跟任何換皮無關。
--
-- 修法：登入後把那條標籤加寬到 40。標籤是從勾選框往右長的，右邊到視窗邊緣
--   還有十幾個單位的空間。不改它的檔案（上游更新會洗掉），從這裡掛。
--
-- ⚠ 動的是那支插件自己建的 FontString（不是暴雪物件、不是保護框），
--   只設一次、不寫任何 Lua 欄位、不讀回寬度（直接設常數）。
---------------------------------------------------------------

local LABEL_WIDTH = 40

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    local button = _G.UsePGFButton
    local text = button and button.Text
    if text and type(text.SetWidth) == "function" then
        pcall(text.SetWidth, text, LABEL_WIDTH)
    end
end)
