------------------------------------------------------------
-- 「藥水清單」分頁：內建預設 ＋ 自訂藥水的開關／刪除／新增
--
-- 這一頁不是表單，所以不走 Controls.Build，直接排在分頁 frame 上；
-- 清單本體是共用層的 W.CreateRowList（列會回收再用）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local ROW_H    = 26
local TOP_AREA = 118        -- 標題＋說明＋按鈕列佔掉的高度

local tab, list, addPopup

-- 物品資料載入完成的監聽者（只在清單分頁看得到時註冊，見 Init）
local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function() ns.RefreshSettingsList() end)

------------------------------------------------------------
-- 一列的樣子：勾選框 ＋ 圖示 ＋ 名稱 ＋ 刪除鈕
--
-- ⚠ 列是回收再用的，所以每個 handler 都讀 row.itemID（更新時才填），
-- 不要在這裡把 itemID 抓進 closure —— 那樣捲動幾次之後按鈕就會動到別筆。
------------------------------------------------------------
local function BuildRow(row)
    row.check = W.CreateCheckButton(row, "", function(checked)
        if row.itemID then ns.SetItemEnabled(row.itemID, checked) end
    end)
    row.check:SetPoint("LEFT", 6, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 10, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFontObject(W.fontNormal)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -34, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.del = W.CreateButton(row, "X", "red", 20, 18)
    row.del:SetPoint("RIGHT", -6, 0)
    row.del:SetScript("OnClick", function()
        if row.itemID then ns.RemoveItem(row.itemID) end
    end)

    -- 工具提示只蓋圖示與名字那一段，蓋整列的話滑到刪除鈕上也會彈出來
    row.hit = CreateFrame("Frame", nil, row)
    row.hit:SetPoint("TOPLEFT", row.icon, "TOPLEFT", 0, 0)
    row.hit:SetPoint("BOTTOMRIGHT", row.name, "BOTTOMRIGHT", 0, 0)
    row.hit:EnableMouse(true)
    row.hit:SetScript("OnEnter", function(self)
        if not row.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(row.itemID)
        GameTooltip:Show()
    end)
    row.hit:SetScript("OnLeave", GameTooltip_Hide)
end

local function RowName(entry)
    local name = C_Item.GetItemNameByID(entry.id) or ("item:" .. entry.id)
    local q = ns.GetQualityLabel(entry.id)   -- 由物品本身的品質推出來
    if q ~= "" then name = name .. " |cff888888(" .. q .. ")|r" end
    if entry.isCustom then name = name .. " |cff66aaff[" .. L["LABEL_CUSTOM"] .. "]|r" end
    return name
end

-- 第一次開啟時物品資料常常還沒進快取，名字會退成 "item:ID"。非同步載入完成後
-- 補上，但要先確認這一列還是同一筆（列會被回收給別的藥水用）。
local function ApplyRowItem(row, entry)
    row.icon:SetTexture((C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)) or ns.FALLBACK_ICON)
    row.name:SetText(RowName(entry))
    if not C_Item.GetItemNameByID(entry.id) and Item and Item.CreateFromItemID then
        local id = entry.id
        Item:CreateFromItemID(id):ContinueOnItemLoad(function()
            if row.itemID == id then ApplyRowItem(row, entry) end
        end)
    end
end

local function UpdateRow(row, entry)
    row.itemID = entry.id
    row.check:SetChecked(entry.enabled and true or false)
    ApplyRowItem(row, entry)
end

------------------------------------------------------------
-- 新增藥水彈窗（輸入物品 ID，或 Shift+點擊物品帶入）
------------------------------------------------------------
local function EnsureAddPopup()
    if addPopup then return addPopup end
    addPopup = W.CreateInputPopup(ns.Options.panel, 380, L["ADD_TITLE"], {
        { key = "id", label = L["ADD_FIELD_ID"], hint = L["ADD_HINT"], maxLetters = 40 },
    })
    return addPopup
end

function ns.ShowAddItemDialog()
    local popup = EnsureAddPopup()
    popup:Open(nil, function(values)
        local text = values.id or ""
        local id = tonumber(text) or tonumber(text:match("item:(%d+)") or "")
        if not id then
            ns.Print(L["ADD_INVALID"])
            return false                     -- 不合法就不關窗，讓玩家直接改
        end
        local ok, reason = ns.AddItem(id)
        if not ok and reason ~= "exists" then
            ns.Print(L["ADD_INVALID"])
            return false
        end
        if reason == "exists" then ns.Print(L["ADD_EXISTS"]) end
    end)
end

-- Shift+點擊任何物品連結 → 填進開著的新增彈窗
hooksecurefunc("HandleModifiedItemClick", function(link)
    if not (addPopup and addPopup:IsShown()) or type(link) ~= "string" then return end
    local id = link:match("item:(%d+)")
    if id then
        addPopup.boxes.id:SetText(id)
        addPopup.boxes.id:SetCursorPosition(0)
    end
end)

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, L["SECTION_LIST"], ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    local desc = tab:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", 18, -46)
    desc:SetWidth(ns.Options.PANEL_W - 40)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["LIST_DESC"])

    local addBtn = W.CreateButton(tab, L["BTN_ADD_ITEM"], "accent", 130, 22)
    addBtn:SetPoint("TOPLEFT", 18, -(TOP_AREA - 30))
    addBtn:SetScript("OnClick", ns.ShowAddItemDialog)

    local restoreBtn = W.CreateButton(tab, L["BTN_RESTORE_DEFAULTS"], "normal", 130, 22)
    restoreBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    restoreBtn:SetScript("OnClick", function() ns.RestoreDefaults() end)

    list = W.CreateRowList(tab, ns.Options.PANEL_W - 36, ns.Options.PANEL_H - TOP_AREA - 12,
        ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", 18, -TOP_AREA)

    -- 物品名稱／圖示是串流進來的，但 ITEM_DATA_LOAD_RESULT 是全域高頻事件，
    -- 只在這一頁真的看得到的時候聽。掛在分頁 frame 上而不是切分頁的 callback：
    -- 直接關掉整個設定視窗時不會派送 ShowOptionsTab，但子框的 OnHide 照樣會跑。
    tab:SetScript("OnShow", function() watcher:RegisterEvent("ITEM_DATA_LOAD_RESULT") end)
    tab:SetScript("OnHide", function() watcher:UnregisterEvent("ITEM_DATA_LOAD_RESULT") end)
end

-- Core 在清單變動後（勾選／新增／刪除／恢復預設）會叫這支。
-- IsVisible 而不是 IsShown：分頁自己是 Show 的，但整個視窗關著的時候不必重畫。
function ns.RefreshSettingsList()
    if not (tab and tab:IsVisible()) then return end
    list:Update(ns.RebuildItemList(), UpdateRow)   -- 純 DB 讀取，戰鬥中也安全
end

ns.RegisterCallback("ShowOptionsTab", "listTab", function(id)
    if id ~= "list" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
    ns.RefreshSettingsList()
end)
