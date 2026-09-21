---------------------------------------------------------------
-- MiliUI Fix: 預組隊伍的團隊列表，職責人數顯示成「...」
-- Author: Mili
--
-- 症狀：團隊副本的隊伍列表右邊「2 坦 4 補 12 輸出」那一組，兩位數的那一格
--   （幾乎都是輸出）顯示成「...」。
--
-- 成因：暴雪把三個人數的 FontString 寬度寫死成 17
--   （UIPanelTemplates.xml 的 `RoleCountNoScriptsTemplate`）。原廠字型的兩位數
--   剛好塞得下；套組的字型字面較寬，兩位數差一點點 ⇒ 整段截成「...」。
--   跟任何換皮無關。
--
-- 修法：把「輸出」「治療」兩格加寬幾 px。三個數字與三顆圖示是一條由右往左的
--   錨定鏈（每一個的 RIGHT 錨在右邊那一個的 LEFT），加寬只會讓左邊的整串往左讓，
--   不用動任何錨點。
--
-- ⚠ 加寬的總量要**盡量小**：列寬 312、隊伍名稱最寬到 x=186、這一組的左緣在 187
--   —— 一點餘裕都沒有，往左長出去的部分會伸進名稱欄。數字是置中的、單位數的
--   坦克人數左邊本來就有約 5px 空白，所以總共 +8 還看不出重疊；再多就會壓到
--   長名稱結尾的「…」。坦克那一格不會到兩位數，不動。
--
-- ⚠ 為什麼可以動寬度：
--   * 暴雪對這三個 FontString 只做 SetText／SetTextColor
--     （`LFGListGroupDataDisplayRoleCount_Update`），**沒有人把寬度讀回去**排版。
--   * 只呼叫 SetWidth(常數)：不寫任何 Lua 欄位、不讀它的文字或尺寸
--     （隊伍資料在 12.x 是秘密值，這裡完全不碰傳進來的 displayData）。
--   * 列是池化的、用到才建 ⇒ 沒辦法登入時一次改完，只能跟在暴雪的更新函式後面；
--     每個框只改一次（弱鍵表記著，不在暴雪框上留欄位）。
---------------------------------------------------------------

local DAMAGER_WIDTH = 22    -- 暴雪：17
local HEALER_WIDTH  = 20    -- 暴雪：17（四十人團的治療會到兩位數）

local UPDATE_FUNC = "LFGListGroupDataDisplayRoleCount_Update"

local widened = setmetatable({}, { __mode = "k" })

local function SetWidthOf(fontString, width)
    if fontString and type(fontString.SetWidth) == "function" then
        pcall(fontString.SetWidth, fontString, width)
    end
end

local function Widen(roleCount)
    if type(roleCount) ~= "table" or widened[roleCount] then return end
    if roleCount.IsForbidden and roleCount:IsForbidden() then return end
    widened[roleCount] = true
    SetWidthOf(roleCount.DamagerCount, DAMAGER_WIDTH)
    SetWidthOf(roleCount.HealerCount, HEALER_WIDTH)
end

local hooked = false

local function TryHook()
    if hooked then return true end
    if type(_G[UPDATE_FUNC]) ~= "function" then return false end
    hooked = true
    hooksecurefunc(UPDATE_FUNC, Widen)
    return true
end

-- 隊伍搜尋器這一包不保證在我們之前載入（也可能是用到才載入）⇒ 沒有就等它。
-- 等不到（暴雪改名）的代價只是每載入一支插件多一次 type 檢查，不值得另設放棄條件。
if not TryHook() then
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(self)
        if TryHook() then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
