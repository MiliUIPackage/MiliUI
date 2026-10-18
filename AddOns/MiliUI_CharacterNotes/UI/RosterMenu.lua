------------------------------------------------------------
-- 分組／隊友的共用選單內容
--
-- 編輯器的「名字」「限定顯示」都要同一份清單，設定頁的「加入目前隊友」也是。
-- ⚠ 這裡回傳的一律是**扁平**清單（用標題列分段），不是巢狀子選單：
--   共用層的選單只支援一層子選單，而這份清單本身就常常是別人的子選單。
------------------------------------------------------------
local _, ns = ...

ns.RosterMenu = {}
local RosterMenu = ns.RosterMenu

local L = ns.L
local Roster, Media = ns.Roster, ns.Media

------------------------------------------------------------
-- 一個分組的名單摘要（選單右側的讀數）
------------------------------------------------------------
local function Summary(group)
    local n = #group.members
    if n == 0 then return "|cff808080" .. L["unassigned"] .. "|r" end
    if n == 1 then return group.members[1] end
    return ("%s +%d"):format(group.members[1], n - 1)
end
RosterMenu.Summary = Summary

------------------------------------------------------------
-- 「插入哪個名字」：分組變數 ＋ 目前隊友
--
-- onPick(token) 的 token 是要寫進 {p:...} 的字串：分組就是分組名，隊友就是玩家名。
------------------------------------------------------------
function RosterMenu.InsertItems(onPick)
    local items = {}

    local groups = Roster.Groups()
    items[#items + 1] = { text = L["Group variables"], isTitle = true }
    if #groups == 0 then
        items[#items + 1] = { text = "|cff808080" .. L["No groups yet"] .. "|r",
                              onClick = function() end }
    end
    for _, g in ipairs(groups) do
        local name = g.name
        items[#items + 1] = {
            text = name,
            value = Summary(g),
            onClick = function() onPick(name) end,
        }
    end

    local live = Roster.LiveMembers()
    if #live > 0 then
        items[#items + 1] = { text = L["In your group right now"], isTitle = true }
        for _, m in ipairs(live) do
            local who = m.name
            items[#items + 1] = {
                text = Media.ClassColoredName(who, m.class),
                onClick = function() onPick(who) end,
            }
        end
    end

    items[#items + 1] = { isSeparator = true }
    items[#items + 1] = {
        text = L["Manage groups..."],
        onClick = function() ns.OpenOptions("roster") end,
    }
    return items
end

------------------------------------------------------------
-- 職業清單
------------------------------------------------------------
local classCache

local function ClassList()
    if classCache then return classCache end
    classCache = {}
    local num = GetNumClasses and GetNumClasses() or 0
    for i = 1, num do
        local ok, className, classFile = pcall(GetClassInfo, i)
        if ok and classFile then
            classCache[#classCache + 1] = { file = classFile, name = className or classFile }
        end
    end
    -- 這個 API 拿不到就退回貼圖座標表的鍵（那張表本來就是每個職業一筆）
    if #classCache == 0 and CLASS_ICON_TCOORDS then
        for classFile in pairs(CLASS_ICON_TCOORDS) do
            classCache[#classCache + 1] = { file = classFile, name = classFile }
        end
        table.sort(classCache, function(a, b) return a.file < b.file end)
    end
    return classCache
end

function RosterMenu.ClassItems(onPick)
    local items = {}
    for _, c in ipairs(ClassList()) do
        local file = c.file
        items[#items + 1] = {
            text = Media.ClassIconMarkup(file, 14) .. " " .. Media.ClassColoredName(c.name, file),
            onClick = function() onPick(file) end,
        }
    end
    return items
end

------------------------------------------------------------
-- 「把目前隊友加進這個分組」：設定頁用
------------------------------------------------------------
function RosterMenu.AddMemberItems(groupID)
    local items = {}
    local live = Roster.LiveMembers()
    if #live == 0 then
        items[#items + 1] = { text = "|cff808080" .. L["You are not in a group right now"] .. "|r",
                              onClick = function() end }
        return items
    end

    local g = Roster.FindByID(groupID)
    local have = {}
    if g then
        for _, m in ipairs(g.members) do have[m:lower()] = true end
    end

    items[#items + 1] = { text = L["In your group right now"], isTitle = true }
    for _, m in ipairs(live) do
        local who, cls = m.name, m.class
        items[#items + 1] = {
            text = Media.ClassColoredName(who, cls),
            isActive = have[who:lower()] == true,
            keepOpen = true,   -- 一次加好幾個人，不要每點一次就關掉
            onClick = function()
                if have[who:lower()] then
                    Roster.RemoveMember(groupID, who)
                    have[who:lower()] = nil
                else
                    Roster.AddMember(groupID, who, cls)
                    have[who:lower()] = true
                end
            end,
        }
    end
    return items
end
