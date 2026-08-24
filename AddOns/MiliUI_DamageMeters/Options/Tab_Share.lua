------------------------------------------------------------
-- 「設定檔」分頁：設定檔切換 ＋ 匯入匯出 ＋ 全部重置
-- 原生 C_EncodingUtil：SerializeCBOR → CompressString → EncodeBase64
-- 前綴帶版本 MILIDM!1!，每步 pcall
-- UX：匯入框即時解析、成功才亮按鈕、錯誤顯示在標題
-- （骨架照 MiliUI_UnitFrames/Options/Tab_Share.lua）
--
-- ⚠ 這裡的「重置」重置的是**設定**；清掉記錄的戰鬥分段是「一般」分頁那顆
--   （/mdm reset），兩件事不要混在一起。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local WIRE_PREFIX = "MILIDM!1!"

ns.Share = {}
local Share = ns.Share

------------------------------------------------------------
-- 編解碼
------------------------------------------------------------
-- 匯出的是**目前這份設定檔**（外觀 ＋ 每視窗設定 ＋ 位置），不是整個帳號。
-- 帳號層的東西（設定視窗位置、內建統計還原旗標、其他設定檔）不該跟著字串跑——
-- 尤其 builtinRestore 是「這台機器欠著一個 CVar 還原」，帶去別人那裡會替他
-- 打開一個他本來就沒開的東西。
function Share.Export()
    if not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR) then
        return nil, L["This client build has no C_EncodingUtil"]
    end
    local payload = {
        schemaVersion = ns.DB_VERSION,
        profile = ns.db,
    }
    local ok, cbor = pcall(C_EncodingUtil.SerializeCBOR, payload)
    if not ok or not cbor then return nil, L["Serialization failed"] end
    local ok2, compressed = pcall(C_EncodingUtil.CompressString, cbor)
    if not ok2 or not compressed then return nil, L["Compression failed"] end
    local ok3, base64 = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not ok3 or not base64 then return nil, L["Encoding failed"] end
    return WIRE_PREFIX .. base64
end

-- ⚠ 結構也要驗，不能只看版本號。這張表會直接變成一份設定檔，缺了或型別不對的話
-- 錯誤要等到下次開設定面板／登入才炸，那時已經 ReloadUI 過、沒有回頭路。
local function ValidProfile(p)
    if type(p) ~= "table" then return false end
    for k, v in pairs(ns.DB.ProfileDefaults()) do
        if type(p[k]) ~= type(v) then return false end
    end
    return true
end

function Share.Decode(text)
    if type(text) ~= "string" then return nil, L["Empty string"] end
    text = text:gsub("%s+", "")
    if text == "" then return nil, L["Empty string"] end
    if text:sub(1, #WIRE_PREFIX) ~= WIRE_PREFIX then
        return nil, L["Wrong prefix (not a MiliUI Damage Meters export string)"]
    end
    local payload = text:sub(#WIRE_PREFIX + 1)
    local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, payload)
    if not ok or not compressed then return nil, L["Base64 decode failed"] end
    local ok2, cbor = pcall(C_EncodingUtil.DecompressString, compressed)
    if not ok2 or not cbor then return nil, L["Decompression failed"] end
    local ok3, data = pcall(C_EncodingUtil.DeserializeCBOR, cbor)
    if not ok3 or type(data) ~= "table" then return nil, L["Deserialization failed"] end
    if type(data.schemaVersion) ~= "number" then return nil, L["Missing version field"] end
    if not ValidProfile(data.profile) then return nil, L["Deserialization failed"] end
    if data.schemaVersion > ns.DB_VERSION then
        return nil, L["String comes from a newer version, please update the addon first"]
    end
    return data
end

-- 只留預設值裡真的存在的頂層鍵，windows 另外抄（它不在預設值裡，見 Core/DB.lua）。
-- 多出來的鍵 MergeDefaults 清不掉（它只補 nil），之後設定分頁會拿著假鍵去跑。
-- windows 也要裁到上限：對方的插件版本可能允許更多視窗，多的那幾份永遠開不出來，
-- 卻會一直躺在 SV 裡。
local function Sanitize(p)
    local out = {}
    for k in pairs(ns.DB.ProfileDefaults()) do
        if p[k] ~= nil then out[k] = p[k] end
    end
    if type(p.windows) == "table" then
        local w = {}
        for i = 1, ns.DB.MAX_WINDOWS do
            if type(p.windows[i]) == "table" then w[i] = p.windows[i] end
        end
        out.windows = w
    end
    return out
end

-- 寫進目前這份設定檔，其他設定檔與帳號層不動
-- （缺的欄位交給下次載入的 MergeDefaults 補齊）
--
-- ⚠ 字串可能來自舊版（Decode 只擋比目前**新**的），所以要補設定檔層的遷移。
-- 只補這一份：帳號層的 schemaVersion 不能降，降了會讓遷移在所有設定檔上重跑。
function Share.Import(data)
    local db = ns.DB.Account()
    local name = db.profileKeys and db.profileKeys[ns.DB.CharKey()]
    if not (name and db.profiles) then return end
    local profile = Sanitize(data.profile)
    ns.DB.MigrateProfile(profile, data.schemaVersion)
    db.profiles[name] = profile
    ReloadUI()
end

------------------------------------------------------------
-- 分頁 UI（面板 700×500）
------------------------------------------------------------
local COL_W  = 320
local COL2_X = 356
local FULL_W = 664

local tab

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    ---------------------------------------------------------
    -- 設定檔
    ---------------------------------------------------------
    local profTitle = W.CreateSectionTitle(tab, L["Profiles"], FULL_W)
    profTitle:SetPoint("TOPLEFT", 12, -40)

    local function ProfileError(msg)
        profTitle.text:SetText("|cffff2222" .. msg .. "|r")
    end

    -- key 是語言無關的（"Default" / "char:角色 - 伺服器"），顯示時才組字
    local function ProfileLabel(name)
        if name == ns.DB.DEFAULT_PROFILE then return L["Shared"] end
        local owner = ns.DB.CharProfileOwner(name)
        if owner then
            -- "米利 - 世界之樹" → 職業色的 "米利-世界之樹"。
            -- 不加「角色專屬」之類的後綴：職業色＋「名字-伺服器」這個形狀本身就跟
            -- 「共用」和自訂名稱分得開了
            local who = (owner:gsub(" %- ", "-"))
            local cls = ns.DB.CharClass(owner)
            local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
            if c then
                -- colorStr 是暴雪現成的 "ffRRGGBB"；沒有就自己組
                who = "|c" .. (c.colorStr or ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255))
                      .. who .. "|r"
            end
            return who
        end
        return name
    end

    -- 展開的清單裡替目前這份加註記。收起來的那行不加（那行本來就只顯示目前這份）
    local function ItemText(name)
        local t = ProfileLabel(name)
        if name == ns.profileName then t = t .. "|cff808080" .. L["(in use)"] .. "|r" end
        return t
    end

    -- 順序：共用 → 自己的角色專屬 → 別隻角色的 → 自訂。
    -- 自己那份還沒建立也要列出來（選了才建，來源由彈窗問）
    local function ProfileItems()
        local charKey = ns.DB.CharProfileKey()
        local items = {
            { text = ItemText(ns.DB.DEFAULT_PROFILE), value = ns.DB.DEFAULT_PROFILE },
            { text = ItemText(charKey), value = charKey },
        }
        local others, customs = {}, {}
        for _, name in ipairs(ns.DB.ListProfiles()) do
            if name ~= ns.DB.DEFAULT_PROFILE and name ~= charKey then
                local t = ns.DB.IsCharProfile(name) and others or customs
                t[#t + 1] = { text = ItemText(name), value = name }
            end
        end
        for _, it in ipairs(others) do items[#items + 1] = it end
        for _, it in ipairs(customs) do items[#items + 1] = it end
        return items
    end

    local nameBox = W.CreateEditBox(tab, 150, 20)
    nameBox:SetPoint("TOPLEFT", 250, -68)

    local pendingSwitch, switchConfirm, seedPopup
    -- 角色專屬**第一次**建立時才問要拿什麼當底。之後就是一份普通設定檔，切過去
    -- 就切過去、不再複製任何東西——想重新來過就把它刪掉再切一次。
    local function AskSeedThenSwitch(charKey)
        if not seedPopup then
            local function Seed(kind)
                return function()
                    ns.DB.SeedCharProfile(kind)
                    ns.DB.SwitchProfile(charKey)
                end
            end
            seedPopup = W.CreateChoicePopup(ns.Options.panel, 380,
                L["Start this character's profile from what?"], {
                    { text = L["Current view"],   onClick = Seed("current") },
                    { text = L["Shared"],         onClick = Seed("shared") },
                    { text = L["Fresh defaults"], color = "red", onClick = Seed("fresh") },
                })
        end
        seedPopup:Show()
    end

    local profDD = W.CreateDropdown(tab, 230, ProfileItems(), function(value)
        if value == ns.profileName then return end
        -- 只有「自己的角色專屬」而且「還沒建立」才問來源
        if value == ns.DB.CharProfileKey()
           and not ns.DB.Account().profiles[value] then
            AskSeedThenSwitch(value)
            return
        end
        pendingSwitch = value
        if not switchConfirm then
            switchConfirm = W.CreateConfirmPopup(ns.Options.panel, 320,
                L["Switch profile? The UI reloads so the meter windows come back with the new settings."],
                function() if pendingSwitch then ns.DB.SwitchProfile(pendingSwitch) end end)
        end
        switchConfirm:Show()
    end)
    profDD:SetPoint("TOPLEFT", 12, -68)

    -- 清單與顯示名要在**每次進分頁**重算，不能只在 Init 算一次：Init 是懶初始化，
    -- 而別的角色可能在這之後才第一次登入（charClasses 多一筆 ⇒ 職業色才對），
    -- 刪除鈕的可用狀態也跟著目前是哪一份走。
    local function SyncProfileWidgets()
        profDD:SetItems(ProfileItems())
        profDD:SetSelectedValue(ns.profileName)
        profDD.text:SetText(ProfileLabel(ns.profileName))
        if tab.__delBtn then
            tab.__delBtn:SetEnabled(ns.profileName ~= ns.DB.DEFAULT_PROFILE)
        end
    end
    tab.__syncProfiles = SyncProfileWidgets

    -- 新建／複製：兩者都是「建立後立刻切過去」（SwitchProfile 會重載）
    local function Make(copyFrom)
        local name = nameBox:GetText()
        local ok, why = ns.DB.CreateProfile(name, copyFrom)
        if ok then
            ns.DB.SwitchProfile((name:gsub("^%s+", ""):gsub("%s+$", "")))
        elseif why == "exists" then
            ProfileError(L["A profile with that name already exists"])
        else
            ProfileError(L["Type a name for the new profile first"])
        end
    end

    local newBtn = W.CreateButton(tab, L["New"], "accent", 64, 20)
    newBtn:SetPoint("TOPLEFT", 408, -68)
    newBtn:SetScript("OnClick", function() Make(nil) end)

    local copyBtn = W.CreateButton(tab, L["Copy"], "accent", 64, 20)
    copyBtn:SetPoint("TOPLEFT", 476, -68)
    copyBtn:SetScript("OnClick", function() Make(ns.profileName) end)

    local delConfirm
    local delBtn = W.CreateButton(tab, L["Delete"], "red", 64, 20)
    delBtn:SetPoint("TOPLEFT", 544, -68)
    -- 掛在 tab 上而不是直接閉包：delBtn 建立得比 SyncProfileWidgets **晚**，
    -- 上面那支拿不到這個 local
    tab.__delBtn = delBtn
    delBtn:SetScript("OnClick", function()
        if ns.profileName == ns.DB.DEFAULT_PROFILE then
            ProfileError(L["The shared profile can't be deleted"])
            return
        end
        if not delConfirm then
            delConfirm = W.CreateConfirmPopup(ns.Options.panel, 320,
                L["Delete the current profile? Characters using it fall back to Shared."],
                function()
                    ns.DB.DeleteProfile(ns.profileName)
                    ns.DB.SwitchProfile(ns.DB.DEFAULT_PROFILE)
                end)
        end
        delConfirm:Show()
    end)

    SyncProfileWidgets()

    local profNote = tab:CreateFontString(nil, "OVERLAY")
    profNote:SetFontObject(W.fontSmall)
    profNote:SetPoint("TOPLEFT", 12, -94)
    profNote:SetWidth(FULL_W)
    profNote:SetJustifyH("LEFT")
    profNote:SetText(L["Every character's own profile is listed here, so you can switch to one another character set up. Export and import below work on the current profile only."])

    ---------------------------------------------------------
    -- 匯出
    ---------------------------------------------------------
    local exportTitle = W.CreateSectionTitle(tab, L["Export"], COL_W)
    exportTitle:SetPoint("TOPLEFT", 12, -118)

    local exportBox = W.CreateScrollEditBox(tab, COL_W, 208)
    exportBox:SetPoint("TOPLEFT", 12, -150)

    local exportBtn = W.CreateButton(tab, L["Generate export string"], "accent", 130, 22)
    exportBtn:SetPoint("TOPLEFT", exportBox, "BOTTOMLEFT", 0, -8)
    exportBtn:SetScript("OnClick", function()
        local str, err = Share.Export()
        if str then
            exportBox.editBox:SetText(str)
            exportBox.editBox:HighlightText()
            exportBox.editBox:SetFocus()
            exportTitle.text:SetText(L["Export (Ctrl+C to copy)"])
        else
            exportTitle.text:SetText("|cffff2222" .. L["Export failed: "] .. (err or "?") .. "|r")
        end
    end)

    -- 匯出框內容防改（一改就重新全選，方便複製）
    exportBox.editBox:SetScript("OnChar", function(self)
        self:HighlightText()
    end)

    ---------------------------------------------------------
    -- 匯入
    ---------------------------------------------------------
    local importTitle = W.CreateSectionTitle(tab, L["Import"], COL_W)
    importTitle:SetPoint("TOPLEFT", COL2_X, -118)

    local pendingData

    local importBtn = W.CreateButton(tab, L["Import and reload"], "green", 130, 22)
    importBtn:SetEnabled(false)

    local importBox = W.CreateScrollEditBox(tab, COL_W, 208, function(eb, userChanged)
        if not userChanged then return end
        local data, err = Share.Decode(eb:GetText())
        if data then
            pendingData = data
            importTitle.text:SetText(L["Import: |cff44ff44string is valid|r"])
            importBtn:SetEnabled(true)
        else
            pendingData = nil
            importBtn:SetEnabled(false)
            if eb:GetText() ~= "" then
                importTitle.text:SetText(L["Import: "] .. "|cffff2222" .. (err or L["invalid"]) .. "|r")
            else
                importTitle.text:SetText(L["Import"])
            end
        end
    end)
    importBox:SetPoint("TOPLEFT", COL2_X, -150)
    importBtn:SetPoint("TOPLEFT", importBox, "BOTTOMLEFT", 0, -8)

    local confirm
    importBtn:SetScript("OnClick", function()
        if not pendingData then return end
        if not confirm then
            confirm = W.CreateConfirmPopup(ns.Options.panel, 300,
                L["Importing overwrites every current setting and reloads the UI. Continue?"],
                function() Share.Import(pendingData) end)
        end
        confirm:Show()
    end)

    local note = tab:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetPoint("TOPLEFT", 12, -396)
    note:SetWidth(FULL_W)
    note:SetJustifyH("LEFT")
    note:SetText(L["The export string contains this profile's settings, window positions included. \"Import and reload\" only lights up once a valid string is pasted."])

    ---------------------------------------------------------
    -- 重置
    ---------------------------------------------------------
    local resetTitle = W.CreateSectionTitle(tab, L["Reset"], FULL_W)
    resetTitle:SetPoint("TOPLEFT", 12, -418)

    local resetBtn = W.CreateButton(tab, L["Restore all defaults and reload"], "red", 150, 22)
    resetBtn:SetPoint("TOPLEFT", 12, -450)

    local resetConfirm
    resetBtn:SetScript("OnClick", function()
        if not resetConfirm then
            resetConfirm = W.CreateConfirmPopup(ns.Options.panel, 340,
                L["Restore this profile (style, windows, positions) to its defaults and reload the UI?"],
                function() ns.DB.ResetAll() end)
        end
        resetConfirm:Show()
    end)

    local resetNote = tab:CreateFontString(nil, "OVERLAY")
    resetNote:SetFontObject(W.fontSmall)
    resetNote:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    resetNote:SetWidth(480)
    resetNote:SetJustifyH("LEFT")
    resetNote:SetText(L["Only this profile is reset; the other profiles are left alone. This is settings only — clearing the recorded segments is \"Reset all segments\" on the General tab."])
end

ns.RegisterCallback("ShowOptionsTab", "shareTab", function(id)
    if id ~= "share" then
        if tab then tab:Hide() end
        return
    end
    Init()
    if tab.__syncProfiles then tab.__syncProfiles() end
    tab:Show()
end)
