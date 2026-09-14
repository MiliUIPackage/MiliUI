------------------------------------------------------------
-- 「坐騎」分頁：套用範圍、兩顆快捷鍵、分類編輯器
--
-- 分類編輯器與坐騎選擇器是這一頁專屬的控件，走共用層表單引擎的 `custom` 型別
-- （Libs/MiliUIWidgets/Controls.lua 的逃生門）——不為了它們在共用層長出新型別。
--
-- ⚠ 效能紀律：收藏冊有上千筆，`Mounts.CollectedMounts()` 只有在**選擇器真的
--   打開**的那一刻才會掃第一次，掃完快取（學到新坐騎才作廢）。這一頁的其他
--   地方一律只問「分類裡列出來的那幾隻」。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local S = ns.Secret
local M = ns.Mounts

local tab, scroll, content, refreshers
local editor, editorY
local picker

local WHITE = "Interface\\Buttons\\WHITE8X8"

local CAT_H     = 24        -- 分類標題列
local MOUNT_H   = 20        -- 坐騎列
local ADD_H     = 20        -- 「新增坐騎」列
local SECTION_GAP = 10      -- 分類與分類之間
local BTN_H     = 18
local BTN_GAP   = 4
local ICON      = 16
local GUTTER    = 20        -- 圖示欄；每一列都留，名字才對齊在同一條線上

-- 下拉的項目表：**就地**改內容不換表。W.CreateDropdown 建立時就把這張表的參照
-- 存進 dd.items，換一張新表它是看不到的——所以 wipe ＋ 重填。
local sideItems = { left = {}, right = {} }

------------------------------------------------------------
-- 快捷坐騎的下拉內容
------------------------------------------------------------
local function BuildSideItems(side)
    local dst = sideItems[side]
    wipe(dst)
    local auto = M.AutoPick(side)
    dst[1] = {
        value = "auto",
        text  = auto and string.format(L["MOUNT_AUTO_PICK"], M.Name(auto)) or L["MOUNT_AUTO_NONE"],
    }
    local seen, list = {}, {}
    for _, cat in ipairs(M.Categories()) do
        for _, spellID in ipairs(cat.spells or {}) do
            if not seen[spellID] then
                seen[spellID] = true
                local info = M.Info(spellID)
                -- available：別的陣營的版本不進下拉（選了也召喚不出來）
                if info and info.available and info.name then
                    list[#list + 1] = { value = spellID, text = info.name }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.text < b.text end)
    for i, item in ipairs(list) do dst[i + 1] = item end
    return dst
end

-- 分類編輯器的灰標：這一頁**全部列出**（它是在編目標），所以要說清楚哪幾隻
-- 在這隻角色身上是灰的、為什麼。回 nil ＝ 正常可用，不標。
local function StateTag(info)
    if not info then return L["MOUNT_NOT_COLLECTED"] end
    -- 陣營排在收藏前面：兩個版本都算收藏，說成「未收藏」是錯的訊息
    if not info.factionOK then return L["MOUNT_OTHER_FACTION"] end
    if not info.collected then return L["MOUNT_NOT_COLLECTED"] end
    if info.hidden then return L["MOUNT_NOT_COLLECTED"] end
    return nil
end

local function RefreshAll()
    if not refreshers then return end
    -- 下拉的內容先就地更新，refreshers 裡的 SetSelectedValue 才查得到新項目
    BuildSideItems("left")
    BuildSideItems("right")
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    M.Fire()          -- 方塊圖示與彈出面板靠 listener 重畫
    RefreshAll()
end

------------------------------------------------------------
-- 坐騎選擇器（加坐騎進某個分類）
--
-- 骨架照共用層 W.CreateInputPopup 的遮罩＋彈窗，但內容是清單，所以自己做一份
-- （不改共用層）。掛在設定視窗上——掛 UIParent 會被視窗蓋住。
------------------------------------------------------------
local PICKER_W, PICKER_H, PICKER_ROW_H = 340, 400, 22

-- 打勾：跟共用層的勾選框同一個素材（純白貼圖染色 ＋ 圖集的 alpha 當遮罩，
-- 直接把圖集當貼圖染色會偏暗）。圖集哪天被拿掉是**靜默**失效，所以留退路。
local function MakeCheck(parent)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(12, 12)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("checkmark-minimal") then
        t:SetTexture(WHITE)
        local mask = parent:CreateMaskTexture()
        mask:SetAtlas("checkmark-minimal")
        mask:SetAllPoints(t)
        t:AddMaskTexture(mask)
    else
        t:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    t:SetVertexColor(W.Accent())
    t:Hide()
    return t
end

local AcceptCursorMount          -- 下面定義；PickerRefresh 的列點擊要用到

local function PickerRefresh()
    if not (picker and picker:IsShown()) then return end
    local filter = strtrim((picker.search:GetText() or "")):lower()
    local items = {}
    for _, info in ipairs(M.CollectedMounts()) do
        if filter == "" or info.name:lower():find(filter, 1, true) then
            items[#items + 1] = info
        end
    end
    picker.empty:SetShown(#items == 0)
    picker.list:Update(items, function(row, info)
        row.icon:SetTexture(info.icon or ns.MountPopup.FALLBACK_ICON)
        row.name:SetText(info.name)
        local has = M.HasMount(picker.catIndex, info.spellID)
        row.check:SetShown(has)
        -- 已加入的：打勾（圖示）＋ 強調色（顏色）。兩層訊號，不只靠顏色
        if has then
            row.name:SetTextColor(W.Accent())
        else
            row.name:SetTextColor(0.86, 0.86, 0.86)
        end
        row.btn:SetScript("OnClick", function()
            -- 拖著坐騎放到列上：先當成「放下」處理，不要順手切換這一列
            if GetCursorInfo() then
                AcceptCursorMount()
                return
            end
            if M.HasMount(picker.catIndex, info.spellID) then
                M.RemoveMount(picker.catIndex, info.spellID)
            else
                M.AddMount(picker.catIndex, info.spellID)
            end
            PickerRefresh()
            RefreshAll()
        end)
    end)
end

-- 從收藏冊拖過來：GetCursorInfo 的第一個值是 "mount" 就收
function AcceptCursorMount()
    if not (picker and picker:IsShown() and picker.catIndex) then return end
    local kind, mountID = GetCursorInfo()
    if S.PlainText(kind) ~= "mount" then return end
    mountID = S.PlainNumber(mountID)
    ClearCursor()
    if not mountID then return end
    -- 包 pcall：拖進來的 ID 不如預期時 GetMountInfoByID 會拋錯
    local spellID = S.PlainNumber(select(2, S.SafeCall(C_MountJournal.GetMountInfoByID, mountID)))
    -- 換得回 mountID 才算數：拖進來的東西格式不如預期時，寧可什麼都不做
    if spellID and M.Resolve(spellID) then
        M.AddMount(picker.catIndex, spellID)
        PickerRefresh()
        RefreshAll()
    end
end

local function EnsurePicker()
    if picker then return picker end
    local parent = ns.Options.panel

    local mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = WHITE })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:SetScript("OnMouseUp", function() picker:Hide() end)
    mask:Hide()

    picker = W.CreateFrame(nil, parent, PICKER_W, PICKER_H)
    W.CloseOnEscape(picker)
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    picker:SetFrameLevel(410)
    picker:SetBackdropBorderColor(W.Accent(1))
    picker:SetPoint("CENTER")
    picker:SetScript("OnShow", function() mask:Show() end)
    picker:SetScript("OnHide", function() mask:Hide() end)
    picker:Hide()

    local title = picker:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOPLEFT", 12, -12)
    picker.title = title

    local close = W.CreateButton(picker, "×", "red", 20, 20)
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() picker:Hide() end)

    picker.search = W.CreateEditBox(picker, PICKER_W - 24, 20)
    picker.search:SetPoint("TOPLEFT", 12, -38)
    picker.search:SetScript("OnTextChanged", function() PickerRefresh() end)

    local hint = picker:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetTextColor(0.55, 0.55, 0.55)
    hint:SetPoint("BOTTOMLEFT", 12, 12)
    hint:SetPoint("BOTTOMRIGHT", -12, 12)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["MOUNT_PICKER_DRAG"])

    picker.list = W.CreateRowList(picker, PICKER_W - 24, PICKER_H - 100, PICKER_ROW_H,
        function(row)
            row.check = MakeCheck(row)
            row.check:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(ICON, ICON)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.icon:SetPoint("LEFT", row, "LEFT", 4 + GUTTER, 0)
            row.name = row:CreateFontString(nil, "OVERLAY")
            row.name:SetFontObject(W.fontNormal)
            row.name:SetPoint("LEFT", row, "LEFT", 4 + GUTTER + GUTTER, 0)
            row.name:SetJustifyH("LEFT")
            row.name:SetWordWrap(false)
            -- 整列可點：蓋一顆透明按鈕，不要只讓文字可點
            row.btn = CreateFrame("Button", nil, row)
            row.btn:SetAllPoints()
            row.btn:SetHighlightTexture(WHITE)
            row.btn:GetHighlightTexture():SetVertexColor(W.Accent(0.25))
        end)
    picker.list:SetPoint("TOPLEFT", 12, -64)

    picker.empty = picker:CreateFontString(nil, "OVERLAY")
    picker.empty:SetFontObject(W.fontSmall)
    picker.empty:SetTextColor(0.6, 0.6, 0.6)
    picker.empty:SetPoint("TOPLEFT", 16, -72)
    picker.empty:SetText(L["MOUNT_PICKER_EMPTY"])
    picker.empty:Hide()

    picker:EnableMouse(true)
    picker:SetScript("OnReceiveDrag", AcceptCursorMount)
    picker:SetScript("OnMouseUp", AcceptCursorMount)

    return picker
end

local function OpenPicker(catIndex)
    EnsurePicker()
    picker.catIndex = catIndex
    local cat = M.Categories()[catIndex]
    picker.title:SetText(string.format(L["MOUNT_PICKER_TITLE"], cat and M.CategoryName(cat) or "?"))
    picker.search:SetText("")
    picker:Show()
    PickerRefresh()
end

------------------------------------------------------------
-- 分類編輯器
------------------------------------------------------------
local function EnsurePopups(ed)
    if not ed.namePopup then
        ed.namePopup = W.CreateInputPopup(ns.Options.panel, 320, L["MOUNT_CAT_NEW_TITLE"], {
            { key = "name", label = L["MOUNT_CAT_NAME"], maxLetters = 32 },
        })
    end
    if not ed.deletePopup then
        ed.deletePopup = W.CreateConfirmPopup(ns.Options.panel, 320, "", function()
            if ed.pendingDelete then M.RemoveCategory(ed.pendingDelete) end
            ed.pendingDelete = nil
            RefreshAll()
        end)
    end
    if not ed.resetPopup then
        ed.resetPopup = W.CreateConfirmPopup(ns.Options.panel, 320, L["MOUNT_RESET_CONFIRM"], function()
            M.ResetToDefaults()
            RefreshAll()
        end)
    end
end

local function CreateEditor(parent, x, y, width)
    local ed = CreateFrame("Frame", nil, parent)
    ed:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    ed:SetSize(width, 10)
    ed.catRows, ed.mountRows, ed.addRows = {}, {}, {}

    ------------------------------------------------------------
    -- 元件池（frame 刪不掉，一律重用）
    ------------------------------------------------------------
    local function SizeBtn(b)
        local fs = b:GetFontString()
        local w = fs and math.ceil(fs:GetStringWidth()) + 14 or 40
        b:SetSize(math.max(w, 26), BTN_H)
        return b:GetWidth()
    end

    local function AcquireCatRow(i)
        local row = ed.catRows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, ed)
        row:SetHeight(CAT_H)

        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFontObject(W.fontNormal)
        row.name:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        -- 由右往左：刪除（破壞性，跟其他鈕隔一格）、改名、下移、上移
        row.del = W.CreateButton(row, L["MOUNT_CAT_DELETE"], "red", 50, BTN_H)
        row.del:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.rename = W.CreateButton(row, L["MOUNT_CAT_RENAME"], "normal", 50, BTN_H)
        row.down = W.CreateButton(row, L["MOUNT_CAT_MOVE_DOWN"], "normal", 50, BTN_H)
        row.up = W.CreateButton(row, L["MOUNT_CAT_MOVE_UP"], "normal", 50, BTN_H)

        ed.catRows[i] = row
        return row
    end

    local function AcquireMountRow(i)
        local row = ed.mountRows[i]
        if row then return row end
        row = CreateFrame("Frame", nil, ed)
        row:SetHeight(MOUNT_H)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:SetPoint("LEFT", row, "LEFT", 12, 0)

        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFontObject(W.fontNormal)
        row.name:SetPoint("LEFT", row, "LEFT", 12 + GUTTER, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)

        -- 三態灰標：未收藏／其他陣營／空白（見 Update 裡的 StateTag）
        row.tag = row:CreateFontString(nil, "OVERLAY")
        row.tag:SetFontObject(W.fontSmall)
        row.tag:SetTextColor(0.55, 0.55, 0.55)
        row.tag:SetPoint("RIGHT", row, "RIGHT", -32, 0)
        row.tag:SetJustifyH("RIGHT")

        row.remove = W.CreateButton(row, "×", "normal", 20, BTN_H)
        row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)

        ed.mountRows[i] = row
        return row
    end

    local function AcquireAddRow(i)
        local row = ed.addRows[i]
        if row then return row end
        row = CreateFrame("Button", nil, ed)
        row:SetHeight(ADD_H)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetFontObject(W.fontSmall)
        row.text:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.text:SetText(L["MOUNT_ADD_MOUNT"])
        row.text:SetTextColor(0.6, 0.6, 0.6)
        row:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        row:SetScript("OnLeave", function(self) self.text:SetTextColor(0.6, 0.6, 0.6) end)
        ed.addRows[i] = row
        return row
    end

    ------------------------------------------------------------
    -- 底部：新增分類 ／ 重設為預設（破壞性，隔一段空白）
    ------------------------------------------------------------
    ed.addCat = W.CreateButton(ed, L["MOUNT_CAT_ADD"], "normal", 150, 22)
    ed.addCat:SetScript("OnClick", function()
        EnsurePopups(ed)
        ed.namePopup:Open(nil, function(values)
            local name = strtrim(values.name or "")
            if name == "" then return false end
            M.AddCategory(name)
            RefreshAll()
        end, L["MOUNT_CAT_NEW_TITLE"])
    end)

    ed.reset = W.CreateButton(ed, L["MOUNT_RESET"], "red", 150, 22)
    ed.reset:SetScript("OnClick", function()
        EnsurePopups(ed)
        ed.resetPopup:Show()
    end)

    ------------------------------------------------------------
    -- 重填
    ------------------------------------------------------------
    function ed:Update()
        local catN, mountN, addN = 0, 0, 0
        local y = 0

        for index, cat in ipairs(M.Categories()) do
            catN = catN + 1
            local row = AcquireCatRow(catN)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", ed, "TOPRIGHT", 0, -y)
            row.name:SetText(M.CategoryName(cat))

            local dw = SizeBtn(row.del)
            row.rename:ClearAllPoints()
            -- 刪除跟其他鈕之間多留一格：它是破壞性動作
            row.rename:SetPoint("RIGHT", row.del, "LEFT", -BTN_GAP * 3, 0)
            local rw = SizeBtn(row.rename)
            row.down:ClearAllPoints()
            row.down:SetPoint("RIGHT", row.rename, "LEFT", -BTN_GAP, 0)
            SizeBtn(row.down)
            row.up:ClearAllPoints()
            row.up:SetPoint("RIGHT", row.down, "LEFT", -BTN_GAP, 0)
            SizeBtn(row.up)
            row.name:SetWidth(math.max(60, ed:GetWidth() - dw - rw - 160))

            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #M.Categories())
            row.up:SetScript("OnClick", function() M.MoveCategory(index, -1); RefreshAll() end)
            row.down:SetScript("OnClick", function() M.MoveCategory(index, 1); RefreshAll() end)
            row.rename:SetScript("OnClick", function()
                EnsurePopups(ed)
                ed.namePopup:Open({ name = M.CategoryName(cat) }, function(values)
                    M.RenameCategory(index, values.name)
                    RefreshAll()
                end, L["MOUNT_CAT_RENAME_TITLE"])
            end)
            row.del:SetScript("OnClick", function()
                EnsurePopups(ed)
                ed.pendingDelete = index
                ed.deletePopup.text:SetText(string.format(L["MOUNT_CAT_DELETE_CONFIRM"], M.CategoryName(cat)))
                ed.deletePopup:Show()
            end)
            row:Show()
            y = y + CAT_H

            -- 坐騎列。設定頁**要列**未收藏的（這裡是在編目標，跟面板相反）
            for _, spellID in ipairs(cat.spells or {}) do
                mountN = mountN + 1
                local mr = AcquireMountRow(mountN)
                mr:ClearAllPoints()
                mr:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
                mr:SetPoint("TOPRIGHT", ed, "TOPRIGHT", 0, -y)
                local info = M.Info(spellID)
                mr.icon:SetTexture((info and info.icon) or ns.MountPopup.FALLBACK_ICON)
                -- 夾住寬度：長名字沒有右緣的話會蓋過「未收藏」與移除鈕
                mr.name:SetWidth(math.max(60, ed:GetWidth() - (12 + GUTTER) - 120))
                mr.name:SetText((info and info.name) or ("spell " .. spellID))
                -- 灰標三態。「其他陣營」排在「未收藏」前面：陣營限定的坐騎兩個版本
                -- 都算收藏，只是這隻角色騎不了——說成「未收藏」是錯的訊息。
                local tag = StateTag(info)
                if tag then
                    mr.name:SetTextColor(0.5, 0.5, 0.5)
                    mr.tag:SetText(tag)
                    mr.tag:Show()
                else
                    mr.name:SetTextColor(0.92, 0.92, 0.92)
                    mr.tag:Hide()
                end
                mr.remove:SetScript("OnClick", function()
                    M.RemoveMount(index, spellID)
                    RefreshAll()
                end)
                mr:Show()
                y = y + MOUNT_H
            end

            addN = addN + 1
            local ar = AcquireAddRow(addN)
            ar:ClearAllPoints()
            ar:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
            ar:SetPoint("TOPRIGHT", ed, "TOPRIGHT", 0, -y)
            ar:SetScript("OnClick", function() OpenPicker(index) end)
            ar:Show()
            y = y + ADD_H + SECTION_GAP
        end

        for i = catN + 1, #ed.catRows do ed.catRows[i]:Hide() end
        for i = mountN + 1, #ed.mountRows do ed.mountRows[i]:Hide() end
        for i = addN + 1, #ed.addRows do ed.addRows[i]:Hide() end

        y = y + 6
        ed.addCat:ClearAllPoints()
        ed.addCat:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
        y = y + 22 + 24
        ed.reset:ClearAllPoints()
        ed.reset:SetPoint("TOPLEFT", ed, "TOPLEFT", 0, -y)
        y = y + 22

        ed:SetHeight(y)
        -- 編輯器是這一頁的最後一列，所以整張表單的高度就是「它的上緣 ＋ 自己的高」。
        -- 這樣高度變動不必重建整張表單。
        if content and editorY then
            content:SetHeight(-editorY + y + 20)
            scroll:SetContentHeight(-editorY + y + 20)
        end
    end

    return ed
end

------------------------------------------------------------
-- 表單
------------------------------------------------------------
local CONTROLS = {
    { type = "header", label = L["SECTION_MOUNT_SCOPE"] },
    { type = "toggle", key = "charSpecific", label = L["MOUNT_CHAR_SPECIFIC"] },
    { type = "text",   label = L["MOUNT_CHAR_SPECIFIC_DESC"] },
    { type = "custom", h = 22, build = function(parent, x, y, width)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(W.Accent(1))
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 5)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        local function refresh()
            if M.IsCharSpecific() then
                fs:SetText(string.format(L["MOUNT_SCOPE_CHAR"], ns.CharKey()))
            else
                fs:SetText(L["MOUNT_SCOPE_SHARED"])
            end
        end
        refresh()
        return 22, refresh
    end },

    { type = "header", label = L["SECTION_MOUNT_KEYS"] },
    { type = "dropdown", key = "left",  label = L["MOUNT_LEFT"],
      items = function() return BuildSideItems("left") end },
    { type = "dropdown", key = "right", label = L["MOUNT_RIGHT"],
      items = function() return BuildSideItems("right") end },
    { type = "text",   label = L["MOUNT_KEYS_DESC"] },

    { type = "header", label = L["SECTION_MOUNT_CATS"] },
    { type = "text",   label = L["MOUNT_CATS_DESC"] },
    -- 編輯器橫跨整張表單（不縮在控件欄裡）：它是一整塊清單，不是一列控件
    { type = "custom", build = function(parent, _, y)
        editorY = y
        editor = CreateEditor(parent, 4, y, ns.Options.FORM_W - 14)
        -- 高度回 10 只是佔位：編輯器自己在 Update 裡把整張表單的高度算好
        return 10, function() editor:Update() end
    end },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["TAB_MOUNTS"])
    local ctx = ns.Controls.MakeCtx(function() return ns.GetDB() end, Apply)

    -- 三個虛擬欄位：它們不是 DB 的一格，讀寫都要轉一手
    --   charSpecific  → Mounts 的 profile 切換（切過去會深拷貝一份）
    --   left / right  → DB 存 nil 代表「自動」，下拉用字串 "auto" 表示
    local baseGet, baseSet = ctx.get, ctx.set
    ctx.get = function(spec)
        if spec.key == "charSpecific" then return M.IsCharSpecific() end
        if spec.key == "left" or spec.key == "right" then
            return M.Profile()[spec.key] or "auto"
        end
        return baseGet(spec)
    end
    ctx.set = function(spec, v)
        if spec.key == "charSpecific" then
            M.SetCharSpecific(v and true or false)
            return
        end
        if spec.key == "left" or spec.key == "right" then
            M.SetAssigned(spec.key, (v ~= "auto") and v or nil)
            return
        end
        baseSet(spec, v)
    end

    content, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "mountsTab", function(id)
    if id ~= "mounts" then
        if tab then tab:Hide() end
        if picker then picker:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
