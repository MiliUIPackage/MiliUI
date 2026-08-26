------------------------------------------------------------
-- 「分組」分頁：管理時間軸用的分組變數與名單
--
-- 使用者的流程是「筆記寫變數、開團前分配人」，所以這一頁的主角是**分配**：
-- 每一列右邊那顆「隊友」直接列出目前隊伍成員，點一下加入、再點一下移除，
-- 選單不關（keepOpen），一次把整組排完。打字是備援，不是主要路徑。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W, P = ns.W, ns.P
local Roster, Media = ns.Roster, ns.Media

local ROW_H = 26

local tab, list, addPopup, renamePopup, confirmPopup
local pendingDelete

local function MembersText(group)
    if #group.members == 0 then
        return "|cff707070" .. L["Nobody assigned yet"] .. "|r"
    end
    local parts = {}
    for i, name in ipairs(group.members) do
        parts[i] = Media.ClassColoredName(name, Roster.ClassOf(name))
    end
    return table.concat(parts, "  ")
end

local function Refresh()
    if not list then return end
    list:Update(Roster.Groups(), function(row, group)
        -- ⚠ 列是回收再用的：每一格都要重設，handler 一律讀 row.groupID
        row.groupID = group.id
        row.name:SetText(group.name)
        row.members:SetText(MembersText(group))
    end)
end

local function ShowRowMenu(row)
    local id = row.groupID
    local group = Roster.FindByID(id)
    if not group then return end
    W.Menu.Show({
        { text = group.name, isTitle = true },
        { text = L["Add someone by name..."], onClick = function()
            if not addPopup then
                addPopup = W.CreateInputPopup(ns.Options.panel, 320, L["Add someone"], {
                    { key = "name", label = L["Character name"] },
                })
            end
            addPopup:Open({}, function(values)
                if not Roster.AddMember(row.groupID, values.name) then return false end
            end, L["Add someone"])
        end },
        { text = L["Rename..."], onClick = function()
            if not renamePopup then
                renamePopup = W.CreateInputPopup(ns.Options.panel, 320, L["Rename group"], {
                    { key = "name", label = L["Group name"],
                      hint = L["Notes refer to groups by name, so renaming one leaves older notes pointing at the old name."] },
                })
            end
            local g = Roster.FindByID(row.groupID)
            renamePopup:Open({ name = g and g.name or "" }, function(values)
                if not Roster.RenameGroup(row.groupID, values.name) then return false end
            end)
        end },
        { isSeparator = true },
        { text = L["Clear the roster"], onClick = function()
            local g = Roster.FindByID(row.groupID)
            if not g then return end
            wipe(g.members)
            ns.Fire("RosterChanged")
        end },
        { text = "|cffff5555" .. L["Delete group"] .. "|r", onClick = function()
            if not confirmPopup then
                confirmPopup = W.CreateConfirmPopup(ns.Options.panel, 330, "", function()
                    if pendingDelete then Roster.DeleteGroup(pendingDelete) end
                    pendingDelete = nil
                end)
            end
            pendingDelete = row.groupID
            local g = Roster.FindByID(row.groupID)
            confirmPopup.text:SetText(
                L["Delete \"%s\"? Notes that use it will show the name in grey instead."]
                    :format(g and g.name or "?"))
            confirmPopup:Show()
        end },
    }, row.menuBtn)
end

local function BuildRow(row)
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWidth(120)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.menuBtn = W.CreateButton(row, "...", "normal", 26, ROW_H - 6)
    row.menuBtn:SetPoint("RIGHT", -6, 0)
    row.menuBtn:SetScript("OnClick", function(self) ShowRowMenu(self:GetParent()) end)

    row.addBtn = W.CreateButton(row, L["Teammates"], "accent-hover", 78, ROW_H - 6)
    row.addBtn:SetPoint("RIGHT", row.menuBtn, "LEFT", -4, 0)
    row.addBtn:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        W.Menu.Show(ns.RosterMenu.AddMemberItems(parent.groupID), self)
    end)

    row.members = row:CreateFontString(nil, "OVERLAY")
    row.members:SetFontObject(W.fontSmall)
    row.members:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.members:SetPoint("RIGHT", row.addBtn, "LEFT", -8, 0)
    row.members:SetJustifyH("LEFT")
    row.members:SetWordWrap(false)
end

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, L["Group variables"], ns.Options.FORM_W)
    title:SetPoint("TOPLEFT", 16, -14)

    local desc = tab:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetWidth(ns.Options.FORM_W)
    desc:SetJustifyH("LEFT")
    desc:SetSpacing(3)
    desc:SetText(L["Write your timeline with group variables — {p:Main tank} instead of a name. Before a run, assign this week's players here and every note follows along."])

    list = W.CreateRowList(tab, ns.Options.FORM_W, 250, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)

    local newBtn = W.CreateButton(tab, L["New group"], "accent-hover", 120, 22)
    newBtn:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -10)
    newBtn:SetScript("OnClick", function()
        if not addPopup then
            addPopup = W.CreateInputPopup(ns.Options.panel, 320, L["New group"], {
                { key = "name", label = L["Group name"] },
            })
        end
        addPopup:Open({}, function(values)
            if not Roster.AddGroup(values.name) then return false end
        end, L["New group"])
    end)

    local hint = tab:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetTextColor(0.6, 0.6, 0.6)
    hint:SetPoint("LEFT", newBtn, "RIGHT", 12, 0)
    hint:SetText(L["Groups are shared across your whole account."])
end

ns.RegisterCallback("ShowOptionsTab", "rosterTab", function(id)
    if id ~= "roster" then
        if tab then tab:Hide() end
        return
    end
    Init()
    Refresh()
    tab:Show()
end)

ns.RegisterCallback("RosterChanged", "rosterTab", function()
    if tab and tab:IsShown() then Refresh() end
end)
