------------------------------------------------------------
-- 好友名單：名字改成職業色
--
-- 好友視窗「聯絡人」頁的清單裡，正在玩 WoW 的好友名字換成職業色：
--   * 遊戲內好友（線上）：「名字, 等級 N 職業」的名字那一段。
--   * 戰網好友（線上、在玩跟自己同一版的正式服）：「戰網名稱 (角色名)」的括號那一段。
-- 可選：滿級的遊戲內好友不顯示「等級 N 職業」（職業已經看顏色了）。戰網好友在清單裡
-- 本來就不顯示等級，不受影響。
--
-- 掛點：全域 `FriendsFrame_UpdateFriendButton(button, elementData)` 的後置勾
--   （Blizzard_FriendsFrame/Mainline/FriendsFrame.lua，ScrollBox 的 element factory
--   每次都重新查這個全域，所以 hooksecurefunc 換掉的版本會被用到）。
--   暴雪在那支裡用 `button.name:SetText(nameText)`＋`SetTextColor` 寫好整串字，
--   我們在它後面把字串重組一次：**只換顏色碼，字面一個字都不多不少**（戰網好友那一列的
--   最愛星號是照名字的字寬排的，字寬不能變）。
--
-- ⚠ taint 紀律（.claude/notes/wow-121-addon-code-in-secure-stack.md、wow-121-secret-values.md）：
--   * 對暴雪的東西只做兩件事：讀欄位／呼叫查詢函式，以及對 `button.name` 這個 FontString
--     呼叫 SetText。**不在 button、elementData 或任何暴雪表上寫欄位**，
--     自己要記的東西（暴雪原本的字，關掉功能時還原用）放模組自己的弱鍵表。
--   * 不從我們的 Lua 呼叫暴雪的清單更新函式（FriendsList_Update 之類）：那等於讓暴雪
--     整條更新流程在我們的執行裡跑、寫它自己的欄位。改設定時只重畫目前看得到的列。
--   * 名字、職業、等級全部先過 ns.Secret：任何一個是秘密值就整列不動，維持暴雪原樣。
--
-- 跟套組裡其他碰好友視窗的東西不衝突：Fix/Blizzard_FriendsButtonBar.lua 只動按鈕列錨點、
-- Fix/Blizzard_FriendsStatusDropdown.lua 只動狀態下拉寬度；MiliUI_Skin 的好友皮也掛同一個
-- 全域，但只碰列的 background／highlight 與滑鼠腳本，不碰 name 的字與顏色。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

-- 暴雪原本寫進 button.name 的字（明文才記）。弱鍵：列是池化的，框不會消失，
-- 但不要讓這張表變成唯一一條參照
local original = setmetatable({}, { __mode = "k" })

-- 本地化職業名 → 職業代碼（兩種性別都收；部分語系的女性職業名不同）
local classByName
local function ClassTokenFromName(className)
    if not className then return end
    if not classByName then
        classByName = {}
        for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
            if type(tbl) == "table" then
                for token, name in pairs(tbl) do classByName[name] = token end
            end
        end
    end
    return classByName[className]
end

local function ClassTokenFromID(classID)
    if not (classID and classID > 0 and GetClassInfo) then return end
    local _, token = GetClassInfo(classID)
    return S.PlainText(token)
end

local function ClassColor(token)
    if not token then return end
    local c = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(token)
    return c
end

------------------------------------------------------------
-- 設定
------------------------------------------------------------
local function DB()
    if not MiliUI_DB then MiliUI_DB = {} end
    return MiliUI_DB
end

local function IsEnabled() return DB().friendsClassColor ~= false end
local function IsHideMaxLevel() return DB().friendsHideMaxLevel == true end

------------------------------------------------------------
-- 組字
------------------------------------------------------------
-- 遊戲內好友：暴雪寫的是 info.name..", "..format(FRIENDS_LEVEL_TEMPLATE, level, className)
local function BuildWoW(id)
    local info = C_FriendList.GetFriendInfoByIndex(id)
    if type(info) ~= "table" then return end
    if not S.ToBool(info.connected) then return end
    local name = S.PlainText(info.name)
    local className = S.PlainText(info.className)
    local level = S.PlainNumber(info.level)
    if not (name and className and level) then return end
    local color = ClassColor(ClassTokenFromName(className))
    if not color then return end

    local text = color:WrapTextInColorCode(name)
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    if IsHideMaxLevel() and maxLevel and level >= maxLevel then
        return text
    end
    return text .. ", " .. format(FRIENDS_LEVEL_TEMPLATE, level, className)
end

-- 戰網好友：暴雪寫的是 戰網名稱.." "..色碼.."("..角色名..")"..FONT_COLOR_CODE_CLOSE
-- （FriendsFrame_GetBNetAccountNameAndStatus）。只在線上、在玩同一版正式服時換色碼。
local function BuildBNet(id)
    local accountInfo = C_BattleNet.GetFriendAccountInfo(id)
    if type(accountInfo) ~= "table" then return end
    local g = accountInfo.gameAccountInfo
    if type(g) ~= "table" then return end
    if not S.ToBool(g.isOnline) then return end
    if S.PlainText(g.clientProgram) ~= BNET_CLIENT_WOW then return end
    if S.PlainNumber(g.wowProjectID) ~= WOW_PROJECT_ID then return end

    local charName = S.PlainText(g.characterName)
    if not charName or charName == "" then return end
    local token = ClassTokenFromID(S.PlainNumber(g.classID))
        or ClassTokenFromName(S.PlainText(g.className))
    local color = ClassColor(token)
    if not color then return end

    local accountName = S.PlainText(BNet_GetBNetAccountName(accountInfo))
    if not accountName then return end

    local shown = S.PlainText(FriendsFrame_GetFormattedCharacterName(charName, nil,
        g.clientProgram, S.PlainNumber(g.timerunningSeasonID)))
    if not shown or shown == "" then return end
    -- 不能合作（跨陣營／跨區、邀不進隊）的暴雪用灰色括號表示 —— 那個灰是有意義的訊號，
    -- 換成職業色就看不出來了，所以這種的維持原樣
    if not CanCooperateWithGameAccount(accountInfo) then return end
    return accountName .. " " .. color:WrapTextInColorCode("(" .. shown .. ")")
end

local function Build(button, elementData)
    local data = elementData or (button.GetElementData and button:GetElementData())
    if type(data) ~= "table" then return end
    local buttonType = S.PlainNumber(data.buttonType)
    local id = S.PlainNumber(data.id)
    if not (buttonType and id) then return end
    if buttonType == FRIENDS_BUTTON_TYPE_WOW then
        return BuildWoW(id)
    elseif buttonType == FRIENDS_BUTTON_TYPE_BNET then
        return BuildBNet(id)
    end
end

-- fresh＝暴雪剛寫完字（後置勾）；否則是改設定時的重畫，暴雪原字沿用上一次記的
local function Apply(button, elementData, fresh)
    local fs = button and button.name
    if not (fs and fs.GetText and fs.SetText) then return end
    if fresh then
        original[button] = S.PlainText(fs:GetText())
    end
    if not IsEnabled() then return end
    local ok, text = pcall(Build, button, elementData)
    if ok and text then
        fs:SetText(text)
    end
end

local function Restore(button)
    local text = original[button]
    if text and button.name then button.name:SetText(text) end
end

-- 改設定：只重畫看得到的列。清單沒開就什麼都不做，下次暴雪更新自然套用
local function RefreshVisible()
    local frame = _G.FriendsListFrame
    local box = frame and frame.ScrollBox
    if not (box and box.ForEachFrame and frame:IsVisible()) then return end
    pcall(box.ForEachFrame, box, function(button)
        if not original[button] then return end
        Restore(button)
        Apply(button, nil, false)
    end)
end

------------------------------------------------------------
-- 掛勾
------------------------------------------------------------
local hooked = false
local function Hook()
    if hooked then return end
    if type(_G.FriendsFrame_UpdateFriendButton) ~= "function" then return end
    hooked = true
    hooksecurefunc("FriendsFrame_UpdateFriendButton", function(button, elementData)
        Apply(button, elementData, true)
    end)
end

Hook()
if not hooked then
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(self, _, name)
        if name ~= "Blizzard_FriendsFrame" then return end
        self:UnregisterAllEvents()
        Hook()
    end)
end

------------------------------------------------------------
-- 對設定頁的 API
------------------------------------------------------------
ns.FriendsClassColor = {
    IsEnabled = IsEnabled,
    SetEnabled = function(v)
        DB().friendsClassColor = v and true or false
        RefreshVisible()
    end,
    IsHideMaxLevel = IsHideMaxLevel,
    SetHideMaxLevel = function(v)
        DB().friendsHideMaxLevel = v and true or false
        RefreshVisible()
    end,
}
