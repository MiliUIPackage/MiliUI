------------------------------------------------------------
-- 「設定檔」頁：切換／新增／複製／改名／刪除／恢復預設、依專精自動切換、匯出／匯入
--
-- 全部即時生效，沒有 /reload（換設定檔走 DB.SwitchProfile → ProfileChanged → 引擎重套）。
-- 匯入**一律建成新的一份**，不覆蓋現有的：貼上字串 → 解得開才出現審閱區（名字可改、
-- 撞名自動加序號、帶了哪些條與自訂群組、要不要立刻切換、要不要綁到目前專精）→「匯入」。
-- 編解碼在 Core/DB.lua（DB.EncodeProfile／DB.DecodeProfileString），這裡只管畫面。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

local Options = ns.Options

local FORM_W = Options.PAGE_W - 6

local DECODE_ERRORS = {
    empty   = L["Paste an export string first."],
    prefix  = L["That isn't a MiliUI Cooldown Manager export string."],
    noapi   = L["This client can't decode export strings."],
    base64  = L["The string is damaged (Base64)."],
    inflate = L["The string is damaged (decompression)."],
    cbor    = L["The string is damaged (data)."],
    shape   = L["The string doesn't contain a valid profile."],
    newer   = L["The string comes from a newer version. Update the addon first."],
}

local BAR_LABEL = {
    essential = L["Essential Cooldowns"], utility = L["Utility Cooldowns"],
    buffs = L["Tracked Buffs"], buffbars = L["Tracked Bars"],
}

local function Display(name)
    if name == ns.DB.DEFAULT_PROFILE then return L["Default profile"] end
    return name
end

local function ProfileItems(withNone)
    local items = {}
    if withNone then items[1] = { text = L["(not bound)"], value = "" } end
    for _, name in ipairs(ns.DB.ListProfiles()) do
        local t = Display(name)
        if name == ns.profileName then t = t .. "|cff808080" .. L[" (in use)"] .. "|r" end
        items[#items + 1] = { text = t, value = name }
    end
    return items
end

local function NumSpecs()
    local n = GetNumSpecializations and GetNumSpecializations() or 0
    return type(n) == "number" and n or 0
end

local function SpecName(i)
    local _, name = GetSpecializationInfo(i)
    return type(name) == "string" and name or ("#" .. i)
end

------------------------------------------------------------
-- 設定檔列：下拉 ＋ 一排按鈕
------------------------------------------------------------
local function ProfileRow(page)
    return { type = "custom", label = L["Current profile"], build = function(parent, x, y, width)
        local dd = W.CreateDropdown(parent, 220, {}, function(value)
            if value ~= ns.profileName then ns.DB.SwitchProfile(value) end
            page:Refresh()
        end)
        dd:SetMaxWidth(width)
        dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        return 30, function()
            dd:SetItems(ProfileItems(false))
            dd:SetSelectedValue(ns.profileName)
            dd.text:SetText(Display(ns.profileName))
        end
    end }
end

local function ButtonsRow(page)
    return { type = "custom", label = "", build = function(parent, x, y, width)
        local holder = CreateFrame("Frame", nil, parent)
        holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 4)
        holder:SetSize(width, 22)
        local input, confirmDelete, confirmReset

        local function Ask(title, initial, fn)
            if not input then
                input = W.CreateInputPopup(Options.panel, 320, "",
                    { { key = "name", label = L["Name"], maxLetters = 40 } })
            end
            input:Open({ name = initial }, function(values)
                local ok, why = fn(values.name or "")
                if not ok then
                    ns.Print(why == "exists" and L["A profile with that name already exists."]
                        or L["Type a name first."])
                    return false
                end
                page:Refresh()
            end, title)
        end

        local function B(text, color, onClick)
            local b = W.CreateButton(holder, text, color, 70, 22)
            W.FitButton(b, 70, 22)
            b:SetScript("OnClick", onClick)
            return b
        end
        local new = B(L["New"], "normal", function()
            Ask(L["New profile"], "", function(name)
                local ok, res = ns.DB.CreateProfile(name)
                if ok then ns.DB.SwitchProfile(res) end
                return ok, res
            end)
        end)
        local copy = B(L["Copy"], "normal", function()
            Ask(L["Copy current profile"], Display(ns.profileName) .. " 2", function(name)
                local ok, res = ns.DB.CopyProfile(ns.profileName, name)
                if ok then ns.DB.SwitchProfile(res) end
                return ok, res
            end)
        end)
        local rename = B(L["Rename"], "normal", function()
            Ask(L["Rename profile"], ns.profileName, function(name)
                return ns.DB.RenameProfile(ns.profileName, name)
            end)
        end)
        local del = B(L["Delete"], "red", function()
            if not confirmDelete then
                confirmDelete = W.CreateConfirmPopup(Options.panel, 320, "", function()
                    ns.DB.DeleteProfile(ns.profileName)
                    page:Refresh()
                end)
            end
            confirmDelete.text:SetText(L["Delete profile \"%s\"? Characters and specializations using it go back to the default profile."]
                :format(Display(ns.profileName)))
            confirmDelete:Show()
        end)
        local reset = B(L["Restore defaults"], "red", function()
            if not confirmReset then
                confirmReset = W.CreateConfirmPopup(Options.panel, 320, "", function()
                    ns.DB.ResetProfile()
                    page:Refresh()
                end)
            end
            confirmReset.text:SetText(L["Restore every setting in \"%s\" to its default, custom groups included?"]
                :format(Display(ns.profileName)))
            confirmReset:Show()
        end)
        local buttons = { new, copy, rename, del, reset }
        local _, h = W.FlowLayout(holder, buttons, width, 6, 4, 22)
        holder:SetHeight(h)
        return h + 8, function()
            local isDefault = ns.profileName == ns.DB.DEFAULT_PROFILE
            rename:SetEnabled(not isDefault)
            del:SetEnabled(not isDefault)
        end
    end }
end

------------------------------------------------------------
-- 依專精切換
------------------------------------------------------------
local function SpecRows(page)
    local list = {
        { type = "header", label = L["Switch by specialization"] },
        { type = "toggle", label = L["Switch automatically"],
          get = function() return ns.DB.IsSpecProfilesEnabled() end,
          set = function(v) ns.DB.SetSpecProfilesEnabled(v); page:Refresh() end },
    }
    -- 每個專精一列。下拉自己建（custom）：清單要跟著新增／刪除的設定檔變，
    -- 表單引擎的 dropdown 只在建的時候取一次清單
    for i = 1, NumSpecs() do
        list[#list + 1] = { type = "custom", label = SpecName(i), build = function(parent, x, y, width)
            local dd = W.CreateDropdown(parent, 220, {}, function(v)
                ns.DB.SetSpecProfile(i, v ~= "" and v or nil)
                page:Refresh()
            end)
            dd:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
            return 30, function()
                local sv = ns.sv
                local map = sv and sv.specProfiles and sv.specProfiles[ns.DB.CharKey()]
                dd:SetItems(ProfileItems(true))
                dd:SetMaxWidth(width)
                local cur = map and map[i] or ""
                dd:SetSelectedValue(cur)
                if cur ~= "" then dd.text:SetText(Display(cur)) end
                local on = ns.DB.IsSpecProfilesEnabled()
                dd:SetEnabled(on)
                dd:SetAlpha(on and 1 or 0.5)
            end
        end }
    end
    list[#list + 1] = { type = "text",
        label = L["While on, changing specialization switches to the profile bound to it. Unbound specializations keep the current profile."] }
    return list
end

------------------------------------------------------------
-- 匯出
------------------------------------------------------------
local function ExportRow()
    return { type = "custom", h = 0, build = function(parent, x, y, width)
        local exported = ""
        local left = 4
        local w = FORM_W - left - 10
        local btn = W.CreateButton(parent, L["Generate export string"], "primary", 150, 22)
        W.FitButton(btn, 150, 22)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y - 4)
        local status = parent:CreateFontString(nil, "OVERLAY")
        status:SetFontObject(W.fontSmall)
        status:SetPoint("LEFT", btn, "RIGHT", 10, 0)
        status:SetTextColor(0.65, 0.65, 0.65)
        local box = W.CreateCopyBox(parent, w, 60, function() return exported end, L["Select all"])
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y - 32)
        btn:SetScript("OnClick", function()
            local str, err = ns.DB.EncodeProfile()
            if str then
                exported = str
                status:SetText(L["Copy it with Ctrl+C. It contains this profile only."])
            else
                exported = ""
                status:SetText("|cffff5555" .. (DECODE_ERRORS[err] or tostring(err)) .. "|r")
            end
            box:Refresh()
            if str then
                box.editBox:SetFocus()
                box.editBox:HighlightText()
            end
        end)
        return 32 + box.totalHeight + 6
    end }
end

------------------------------------------------------------
-- 匯入：貼上 → 審閱 → 匯入
------------------------------------------------------------
local function ImportRow(page)
    return { type = "custom", h = 0, build = function(parent, x, y, width)
        local left = 4
        local w = FORM_W - left - 10
        local pending
        local status = parent:CreateFontString(nil, "OVERLAY")
        status:SetFontObject(W.fontSmall)
        status:SetJustifyH("LEFT")
        status:SetWidth(w)
        status:SetTextColor(0.65, 0.65, 0.65)

        local review = CreateFrame("Frame", nil, parent)
        review:SetSize(w, 150)
        local nameLabel = review:CreateFontString(nil, "OVERLAY")
        nameLabel:SetFontObject(W.fontNormal)
        nameLabel:SetPoint("TOPLEFT", 0, -4)
        nameLabel:SetText(L["Save as"])
        local nameBox = W.CreateEditBox(review, 220, 20)
        nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        nameBox:SetMaxLetters(40)
        local nameNote = review:CreateFontString(nil, "OVERLAY")
        nameNote:SetFontObject(W.fontSmall)
        nameNote:SetTextColor(0.65, 0.65, 0.65)
        nameNote:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -10)
        nameNote:SetWidth(w)
        nameNote:SetJustifyH("LEFT")
        local summary = review:CreateFontString(nil, "OVERLAY")
        summary:SetFontObject(W.fontSmall)
        summary:SetPoint("TOPLEFT", nameNote, "BOTTOMLEFT", 0, -6)
        summary:SetWidth(w)
        summary:SetJustifyH("LEFT")
        local switchCB = W.CreateCheckButton(review, L["Switch to it now"])
        switchCB:SetPoint("TOPLEFT", review, "TOPLEFT", 0, -86)
        local bindCB = W.CreateCheckButton(review, L["Bind it to my current specialization"])
        bindCB:SetPoint("TOPLEFT", review, "TOPLEFT", 0, -110)
        bindCB:SetLabelMaxWidth(w - 30)
        local importBtn = W.CreateButton(review, L["Import"], "primary", 100, 22)
        W.FitButton(importBtn, 100, 22)
        importBtn:SetPoint("TOPLEFT", review, "TOPLEFT", 0, -136)

        local function UpdateNameNote()
            local want = strtrim(nameBox:GetText() or "")
            if want == "" then want = "Imported" end
            local final = ns.DB.UniqueProfileName(want)
            if final ~= want then
                nameNote:SetText(L["That name is taken; it will be saved as \"%s\"."]:format(final))
            else
                nameNote:SetText(L["Imports always create a new profile; nothing existing is overwritten."])
            end
        end
        nameBox:SetScript("OnTextChanged", function(_, user) if user then UpdateNameNote() end end)

        local box
        local function SetPending(data, err, text)
            pending = data
            if data then
                status:SetText("|cff44ff44" .. L["The string is valid. Check the details below, then import."] .. "|r")
                nameBox:SetText(data.name or "Imported")
                nameBox:SetCursorPosition(0)
                UpdateNameNote()
                local builtin, custom = ns.DB.SummarizeProfile(data.profile)
                local names = {}
                for _, k in ipairs(builtin) do names[#names + 1] = BAR_LABEL[k] end
                local line = L["Bars: %s"]:format(#names > 0 and table.concat(names, L[", "]) or L["none"])
                if #custom > 0 then
                    line = line .. "\n" .. L["Custom groups (%d): %s"]:format(#custom, table.concat(custom, L[", "]))
                else
                    line = line .. "\n" .. L["No custom groups."]
                end
                summary:SetText(line)
                switchCB:SetChecked(true)
                bindCB:SetChecked(false)
                bindCB:SetEnabled(ns.specIndex ~= nil)
                review:Show()
            else
                review:Hide()
                if text and text ~= "" then
                    status:SetText("|cffff5555" .. (DECODE_ERRORS[err] or tostring(err)) .. "|r")
                else
                    status:SetText(L["Paste an export string into the box above."])
                end
            end
        end

        box = W.CreateScrollEditBox(parent, w, 70, function(eb, user)
            if not user then return end
            local text = eb:GetText()
            local data, err = ns.DB.DecodeProfileString(text)
            SetPending(data, err, text)
        end)
        box:SetPoint("TOPLEFT", parent, "TOPLEFT", left, y - 4)
        status:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
        review:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -26)

        importBtn:SetScript("OnClick", function()
            if not pending then return end
            local name = ns.DB.ImportProfile(pending.profile, pending.schemaVersion, nameBox:GetText())
            if not name then return end
            if bindCB:GetChecked() and ns.specIndex then
                ns.DB.SetSpecProfilesEnabled(true)
                ns.DB.SetSpecProfile(ns.specIndex, name)
            end
            if switchCB:GetChecked() then ns.DB.SwitchProfile(name) end
            box.editBox:SetText("")
            SetPending(nil)
            status:SetText("|cff44ff44" .. L["Imported as \"%s\"."]:format(Display(name)) .. "|r")
            page:Refresh()
        end)
        SetPending(nil)
        return 4 + 70 + 26 + 160
    end }
end

------------------------------------------------------------
-- 頁面
------------------------------------------------------------
Options.RegisterPage("profile", Options.PageTitle("profile"), function(parent, title)
    local page, y = Options.NewPage(parent, title)
    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", page, "TOPLEFT", Options.PAGE_PAD, y)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    local form

    local controls = {
        { type = "header", label = L["Profiles"] },
        ProfileRow(page),
        ButtonsRow(page),
        { type = "text", label = L["Each profile has its own bars, positions and per-spell settings. Switching applies right away."] },
    }
    for _, s in ipairs(SpecRows(page)) do controls[#controls + 1] = s end
    controls[#controls + 1] = { type = "header", label = L["Export"] }
    controls[#controls + 1] = ExportRow()
    controls[#controls + 1] = { type = "header", label = L["Import"] }
    controls[#controls + 1] = ImportRow(page)

    local ctx = ns.Controls.MakeCtx(function() return {} end, function() end)
    ctx.get = function(spec) return spec.get and spec.get() end
    ctx.set = function(spec, v) if spec.set then spec.set(v) end end

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(FORM_W, 1)
    local height, refreshers = ns.Controls.Build(content, controls, ctx, 4, -4, FORM_W)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    form = refreshers

    function page:Refresh()
        for _, fn in ipairs(form) do fn() end
    end
    page.OnShowPage = page.Refresh
    ns.RegisterCallback("ProfileChanged", "profilePage", function()
        if page:IsVisible() then page:Refresh() end
    end)
    return page
end)
