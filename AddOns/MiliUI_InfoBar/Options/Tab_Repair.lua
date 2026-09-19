------------------------------------------------------------
-- 「修裝」分頁：自動修裝的兩個開關 ＋ 耐久面板要顯示哪些修裝道具／玩具／坐騎
--
-- 自動修裝（Core/AutoRepair.lua）在耐久方塊的面板最上面也有同樣兩列，兩邊讀寫
-- 的是同一個 db.repair；面板每次滑過都現讀，所以在這裡切換不必去通知它。
--
-- 清單是這一頁專屬的控件，走共用層表單引擎的 `custom` 型別
-- （Libs/MiliUIWidgets/Controls.lua 的逃生門）——不為了它在共用層長出新型別。
--
-- ⚠ 這一頁跟面板**看的東西不一樣**：面板只畫「擁有且未關掉」的（它是拿來用的），
--   這一頁列出清單上的每一筆（它是在編目標），沒有的那幾筆標灰、勾選框照樣可切
--   —— 玩家可以先把將來不想看到的關掉。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local R = ns.Repair

local tab, scroll, content, refreshers
local list, listY

local ROW_H       = 22
local GROUP_H     = 20
local NOTE_H      = 18
local SECTION_GAP = 10
local ICON        = 16
local CHECK_W     = 18
local GAP         = 6

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

------------------------------------------------------------
-- 清單
------------------------------------------------------------
local function CreateList(parent, x, y, width)
    local ed = CreateFrame("Frame", nil, parent)
    ed:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    ed:SetSize(width, 10)
    ed.rows, ed.groups = {}, {}

    ------------------------------------------------------------
    -- 元件池（frame 刪不掉，一律重用）
    ------------------------------------------------------------
    local function AcquireGroup(i)
        local fs = ed.groups[i]
        if fs then return fs end
        fs = W.CreateGroupLabel(ed, "")
        ed.groups[i] = fs
        return fs
    end

    local function AcquireRow(i)
        local row = ed.rows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, ed)
        row:SetHeight(ROW_H)

        -- 勾＝顯示。onChange 建立時就綁死，換的是 row 上的 kind/id
        -- （每次重畫都換一批新 closure 的話，池化就白做了）
        row.check = W.CreateCheckButton(row, nil, function(checked)
            if row.kind and row.id then
                R.SetHidden(row.kind, row.id, not checked)
            end
        end)
        row.check:SetPoint("LEFT", row, "LEFT", 2, 0)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        -- 圖示邊緣那圈留白裁掉（同面板與坐騎分頁）
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:SetPoint("LEFT", row, "LEFT", 2 + CHECK_W + GAP, 0)

        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFontObject(W.fontNormal)
        row.name:SetPoint("LEFT", row, "LEFT", 2 + CHECK_W + GAP + ICON + GAP, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        -- 右側小標：未擁有→灰字說明；道具擁有→數量
        row.tag = row:CreateFontString(nil, "OVERLAY")
        row.tag:SetFontObject(W.fontSmall)
        row.tag:SetTextColor(0.55, 0.55, 0.55)
        row.tag:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.tag:SetJustifyH("RIGHT")

        ed.rows[i] = row
        return row
    end

    -- 「坐騎分頁裡沒有修裝分類」只有一行，不必池化
    local function MountNote()
        if ed.note then return ed.note end
        local fs = ed:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(0.55, 0.55, 0.55)
        fs:SetJustifyH("LEFT")
        fs:SetText(L["REPAIR_MOUNT_CAT_MISSING"])
        ed.note = fs
        return fs
    end

    ------------------------------------------------------------
    -- 重填
    ------------------------------------------------------------
    function ed:Update()
        local entries = R.Entries()
        local rowN, groupN = 0, 0
        local y = 0
        local noteShown = false

        for _, kind in ipairs(R.CATEGORIES) do
            local kindList = entries[kind] or {}
            -- 空的分類整段不畫：一個沒有任何項目的標題讀起來像壞掉
            if #kindList > 0 then
                groupN = groupN + 1
                local label = AcquireGroup(groupN)
                label:ClearAllPoints()
                label:SetPoint("TOPLEFT", ed, "TOPLEFT", 4, -y - 4)
                label:SetText(L["REPAIR_CAT_" .. kind:upper()])
                label:Show()
                y = y + GROUP_H

                if kind == "mount" and entries.mountSeeded then
                    local note = MountNote()
                    note:ClearAllPoints()
                    note:SetPoint("TOPLEFT", ed, "TOPLEFT", 4, -y - 2)
                    note:SetWidth(ed:GetWidth() - 8)
                    note:Show()
                    noteShown = true
                    y = y + NOTE_H
                end

                for _, entry in ipairs(kindList) do
                    rowN = rowN + 1
                    local row = AcquireRow(rowN)
                    row.kind, row.id = entry.kind, entry.id
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
                    row:SetPoint("TOPRIGHT", ed, "TOPRIGHT", 0, -y)

                    row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                    -- 夾住寬度：長名字沒有右緣的話會蓋過右側小標
                    row.name:SetWidth(math.max(60,
                        ed:GetWidth() - (2 + CHECK_W + GAP + ICON + GAP) - 130))
                    row.name:SetText(entry.name or (entry.kind .. " " .. entry.id))

                    -- 沒有的那幾筆名字變暗，但勾選框照樣可切
                    if entry.owned then
                        row.name:SetTextColor(0.92, 0.92, 0.92)
                        if entry.kind == "item" then
                            row.tag:SetText("×" .. entry.count)
                            row.tag:Show()
                        else
                            row.tag:Hide()
                        end
                    else
                        row.name:SetTextColor(0.5, 0.5, 0.5)
                        row.tag:SetText(L["REPAIR_NOT_OWNED"])
                        row.tag:Show()
                    end

                    row.check:SetChecked(not entry.hidden)
                    row:Show()
                    y = y + ROW_H
                end

                y = y + SECTION_GAP
            end
        end

        for i = rowN + 1, #ed.rows do ed.rows[i]:Hide() end
        for i = groupN + 1, #ed.groups do ed.groups[i]:Hide() end
        if ed.note and not noteShown then ed.note:Hide() end

        ed:SetHeight(math.max(y, 10))
        -- 清單是這一頁的最後一列，所以整張表單的高度就是「它的上緣 ＋ 自己的高」。
        -- 這樣項目多寡變動不必重建整張表單（同 Options/Tab_Mounts.lua）。
        if content and listY then
            content:SetHeight(-listY + y + 20)
            scroll:SetContentHeight(-listY + y + 20)
        end
    end

    return ed
end

------------------------------------------------------------
-- 表單
------------------------------------------------------------
local CONTROLS = {
    -- 自動修裝擺最前面：它是會自己發生的行為，而且方塊被玩家收起來之後，
    -- 這裡就是唯一的入口（面板要滑過耐久方塊才長得出來）。
    { type = "header", label = L["SECTION_AUTO_REPAIR"] },
    { type = "toggle", key = "auto",  sub = "repair", label = L["MENU_AUTO_REPAIR"] },
    { type = "text",   label = L["AUTO_REPAIR_DESC"] },
    { type = "toggle", key = "guild", sub = "repair", label = L["MENU_GUILD_REPAIR"] },
    { type = "text",   label = L["GUILD_REPAIR_DESC"] },
    -- ⚠ 撞車警告不能寫成檔案層的 if：LeaPlusDB 是 Leatrix 自己的 SavedVariables，
    --   本檔載入時不保證已經在了。走 custom，build 在「第一次打開分頁」才跑。
    { type = "custom", h = 0, build = function(parent, x, y, width)
        if not ns.AutoRepair.LeatrixConflict() then return 0 end
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetSpacing(3)
        fs:SetText("|cffff9900" .. L["AUTO_REPAIR_LEATRIX_WARN"] .. "|r")
        return math.ceil(fs:GetStringHeight()) + 8
    end },

    { type = "header", label = L["SECTION_REPAIR"] },
    { type = "text",   label = L["REPAIR_DESC"] },
    -- 清單橫跨整張表單（不縮在控件欄裡）：它是一整塊清單，不是一列控件
    { type = "custom", build = function(parent, _, y)
        listY = y
        list = CreateList(parent, 4, y, ns.Options.FORM_W - 14)
        -- 高度回 10 只是佔位：清單自己在 Update 裡把整張表單的高度算好
        return 10, function() list:Update() end
    end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_REPAIR"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, RefreshAll)
    content, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "repairTab", function(id)
    if id ~= "repair" then
        if tab then tab:Hide() end
        -- 分頁關著就不要再收事件（包包一動就重畫整份清單）
        R.RemoveListener("options")
        R.Watch("options", false)
        return
    end
    Init()
    RefreshAll()
    tab:Show()
    R.AddListener("options", RefreshAll)
    R.Watch("options", true)
end)
