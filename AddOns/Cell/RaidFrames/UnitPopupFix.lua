local _, Cell = ...
local F = Cell.funcs

-------------------------------------------------
-- 右鍵單位選單：寵物誤判補救
-------------------------------------------------
-- 暴雪的 togglemenu 安全動作（SecureTemplates.lua 的 SECURE_ACTIONS.togglemenu）用這條鏈
-- 決定要開哪一種選單：
--
--     token 字串比對（party / boss / focus / arena）→ 比中就結束
--     → UnitIsUnit(unit,"player") / "vehicle" / "pet"
--     → UnitIsOtherPlayersBattlePet / UnitIsOtherPlayersPet
--     → UnitIsPlayer(unit)            ← 真正該答對的那一格
--     → UnitIsUnit(unit,"target")
--
-- 12.1 對**身分受限**的單位（離線、不同區、資料還沒串流過來的隊友）回秘密布林，而秘密
-- 布林在 if 裡是 truthy ⇒ 第一個「問對方是不是誰的寵物」的分支就把整條鏈吃掉，UnitIsPlayer
-- 永遠問不到。症狀是右鍵團友跳出寵物選單，而且那份選單裡**沒有踢人**（踢人只在
-- PARTY / RAID_PLAYER 選單裡），看起來就像「選單踢不掉他」。
--
-- ⚠ 為什麼只有團隊框中招：上面第一段的 token 字串比對讓 partyN / bossN 早退出，一次
--   UnitIsUnit 都不呼叫，所以隊伍框與首領框天生免疫；**raidN 沒有對應分支**，會走完整條
--   鏈。partyN 一起收在下面是防其他分類路徑（暴雪自己的隊伍框走 menu-function，不經過
--   SECURE_ACTIONS.togglemenu）。
--
-- ⚠⚠ 不要改成「自己算出種類再開整份選單」。那樣開出來的選單整份帶著我們的 taint，保護
--   項目（設為焦點…）按下去會跳「嘗試進行 Blizzard UI 專屬動作，遭到封鎖」的強制彈窗，
--   還會建議玩家關掉插件；包 securecallfunction 也救不回來。這裡只在**引擎已經開錯**的
--   當下重開一次，taint 只沾到那一份本來就是錯的選單。
-------------------------------------------------

if not Cell.isRetail then return end

local PET_MENUS = {PET = true, OTHERPET = true, OTHERBATTLEPET = true}

-- 會被誤判的固定 token。刻意用白名單：寵物家族的 token（pet / partypetN / raidpetN）開
-- 寵物選單是對的，不能碰。Spotlight 框可以被玩家指到這幾個（見 Groups/SpotlightFrame.lua）。
-- （focus 其實在字串比對那段就早退出、不會誤判，留著是防其他分類路徑。）
local FIX_TOKENS = {
    target = true, targettarget = true, focus = true, focustarget = true,
}

-- 該重開哪一種選單。raidN / partyN 直接從 token 推；target 這類指向不固定的 token 用 GUID
-- 對照隊伍名冊 —— 隊友／團友的 GUID 就算離線、不同區也讀得到。
-- 分 PARTY / RAID_PLAYER 而不是一律 PLAYER，差別就是**踢人那幾項在不在選單裡**
-- （PLAYER 選單根本沒有踢人，看起來就像「選單踢不掉他」，那正是回報的場景）。
local function MenuWhichFor(lu, guid)
    if strfind(lu, "^raid%d+$") then return "RAID_PLAYER" end
    if strfind(lu, "^party%d+$") then return "PARTY" end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if F.Desecret(UnitGUID("raid"..i)) == guid then return "RAID_PLAYER" end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if F.Desecret(UnitGUID("party"..i)) == guid then return "PARTY" end
        end
    end
    return "PLAYER"
end

-- 重開的那份選單帶著 taint，有幾個項目**一定**壞，開著只會炸或污染：
--   設為焦點／跟隨   保護函式，點了跳 FORBIDDEN
--   標記目標圖示     子選單每顆勾選都要比較 GetRaidTargetIndex —— 12.1 是秘密數字，
--                    tainted 執行一比就炸（警告刷屏＋fontString nil 連鎖）；就算畫得
--                    出來，SetRaidTarget 也是保護函式
--   檢視房屋         tainted 初始化會把房屋清單污染到重登，之後連安全選單開的拜訪也被擋
--   複製角色名稱     CopyToClipboard 是保護函式（插件從來寫不進剪貼簿）
-- 全部灰掉。reopenUnit 閘保證只動我們重開的那一份，正常的安全選單一個不碰。
local reopenUnit

-- 「複製角色名稱」的替代品：剪貼簿寫封死，但反白讓玩家自己 Ctrl+C 不受任何限制。
local COPY_POPUP = "CELL_COPY_CHARACTER_NAME"
StaticPopupDialogs[COPY_POPUP] = {
    text = COPY_CHARACTER_NAME,
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self, data)
        -- 12.x 的 StaticPopup 欄位是大寫 EditBox（舊版小寫 editBox），兩個都認
        local eb = self.EditBox or self.editBox
        if not eb then return end
        eb:SetText(data or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    -- 唯讀：使用者一改就還原
    EditBoxOnTextChanged = function(self)
        local data = self:GetParent().data
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- 遞迴走訪：像「複製角色名稱」這種項目藏在「其他選項」**子選單**裡，只掃第一層碰不到。
local function GreyBrokenItems(desc)
    for _, d in desc:EnumerateElementDescriptions() do
        if d.SetEnabled then
            local ok, text = pcall(MenuUtil.GetElementText, d)
            if ok and text and (text == SET_FOCUS or text == FOLLOW
                    or text == RAID_TARGET_ICON or text == UNIT_VIEW_HOUSES
                    or text == COPY_CHARACTER_NAME) then
                d:SetEnabled(false)
            end
        end
        if d.EnumerateElementDescriptions then
            GreyBrokenItems(d)
        end
    end
end

local function ModifyReopenedMenu(owner, rootDescription, contextData)
    if not reopenUnit then return end
    if not contextData or contextData.unit ~= reopenUnit then return end
    GreyBrokenItems(rootDescription)
    -- 名字讀得到才補我們自己的那顆（讀不到＝連給玩家 Ctrl+C 的內容都沒有）。
    -- 這份選單本來就是 tainted 的，加一般按鈕沒有額外代價。
    local name = contextData.name
    if name and rootDescription.CreateButton then
        rootDescription:CreateButton(COPY_CHARACTER_NAME, function()
            StaticPopup_Show(COPY_POPUP, nil, nil, name)
        end)
    end
end

local installed = false
local function InstallMenuClassifierFix()
    if installed or type(UnitPopup_OpenMenu) ~= "function" then return end
    installed = true

    -- 只註冊我們可能重開的三種（見 MenuWhichFor 的回傳值）
    if Menu and Menu.ModifyMenu and MenuUtil and MenuUtil.GetElementText then
        Menu.ModifyMenu("MENU_UNIT_PLAYER", ModifyReopenedMenu)
        Menu.ModifyMenu("MENU_UNIT_PARTY", ModifyReopenedMenu)
        Menu.ModifyMenu("MENU_UNIT_RAID_PLAYER", ModifyReopenedMenu)
    end

    local reopening = false
    hooksecurefunc("UnitPopup_OpenMenu", function(which, contextData)
        if reopening then return end
        if not PET_MENUS[which] then return end
        local unit = contextData and contextData.unit
        if type(unit) ~= "string" then return end

        local lu = strlower(unit)
        if not (FIX_TOKENS[lu] or strfind(lu, "^raid%d+$") or strfind(lu, "^party%d+$")) then
            return
        end

        -- GUID 是秘密值就放棄：判不出來就不動。救得回來的是「GUID 讀得到、但引擎那條
        -- UnitIsUnit 鏈誤判」—— 離線／不同區的團友正是這種。
        local guid = UnitGUID(unit)
        if not F.IsValueNonSecret(guid) then return end
        if type(guid) ~= "string" or not strfind(guid, "^Player%-") then return end

        -- 名字讀得到就放進 context，餵給上面補的那顆「複製角色名稱」
        local ctx = {unit = unit}
        local name, realm = (UnitNameUnmodified or UnitName)(unit)
        name = F.Desecret(name)
        if name then
            realm = F.Desecret(realm)
            ctx.name = (realm and realm ~= "" and (name.."-"..realm)) or name
        end

        -- ⚠ 重開一定要傳**全新的 context 表**：UnitPopup_OpenMenu 會就地把
        --   playerLocation/accountInfo 塞進去，而入口又斷言那些欄位是 nil ⇒ 重用第一次
        --   那張表會直接 assertion failed。
        reopening = true
        reopenUnit = unit
        UnitPopup_OpenMenu(MenuWhichFor(lu, guid), ctx)
        reopenUnit = nil
        reopening = false
    end)

    -- 給套組裡其他也掛 UnitPopup_OpenMenu 的插件看的旗標：上面那些 token 由 Cell 接手了，
    -- 別再救第二次 —— 兩份 hook 各重開一次會開出兩層選單。這個掛勾是全域的、只看 token
    -- 不看是誰的框，所以接手的範圍就是全部，不是只有 Cell 自己的框。
    _G.CellUnitPopupClassifierFix = true
end

InstallMenuClassifierFix()
if not installed then
    -- 罕見：選單系統還沒載入。等登入再試一次。
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        InstallMenuClassifierFix()
        self:UnregisterAllEvents()
    end)
end
