------------------------------------------------------------
-- 「設定檔」分頁：設定匯入匯出 ＋ 全部重置
-- 原生 C_EncodingUtil：SerializeCBOR → CompressString → EncodeBase64
-- 前綴帶版本 MILIUF!1!，每步 pcall（參考 Ayije_CDM/Config/ProfileIO.lua）
-- UX：匯入框即時解析、成功才亮按鈕、錯誤顯示在標題
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local WIRE_PREFIX = "MILIUF!1!"

ns.Share = {}
local Share = ns.Share

------------------------------------------------------------
-- 編解碼
------------------------------------------------------------
function Share.Export()
    if not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR) then
        return nil, L["This client build has no C_EncodingUtil"]
    end
    local ok, cbor = pcall(C_EncodingUtil.SerializeCBOR, ns.db)
    if not ok or not cbor then return nil, L["Serialization failed"] end
    local ok2, compressed = pcall(C_EncodingUtil.CompressString, cbor)
    if not ok2 or not compressed then return nil, L["Compression failed"] end
    local ok3, base64 = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not ok3 or not base64 then return nil, L["Encoding failed"] end
    return WIRE_PREFIX .. base64
end

function Share.Decode(text)
    if type(text) ~= "string" then return nil, L["Empty string"] end
    text = text:gsub("%s+", "")
    if text == "" then return nil, L["Empty string"] end
    if text:sub(1, #WIRE_PREFIX) ~= WIRE_PREFIX then
        return nil, L["Wrong prefix (not a MiliUI UF export string)"]
    end
    local payload = text:sub(#WIRE_PREFIX + 1)
    local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, payload)
    if not ok or not compressed then return nil, L["Base64 decode failed"] end
    local ok2, cbor = pcall(C_EncodingUtil.DecompressString, compressed)
    if not ok2 or not cbor then return nil, L["Decompression failed"] end
    local ok3, data = pcall(C_EncodingUtil.DeserializeCBOR, cbor)
    if not ok3 or type(data) ~= "table" then return nil, L["Deserialization failed"] end
    if type(data.schemaVersion) ~= "number" then return nil, L["Missing version field"] end
    if data.schemaVersion > ns.DB_VERSION then
        return nil, L["String comes from a newer version, please update the addon first"]
    end
    return data
end

function Share.Import(data)
    -- 覆寫整份 DB（保底補齊 defaults 交給下次載入的 MergeDefaults）
    wipe(MiliUI_UnitFrames_DB)
    for k, v in pairs(data) do
        MiliUI_UnitFrames_DB[k] = v
    end
    ReloadUI()
end

------------------------------------------------------------
-- 分頁 UI
------------------------------------------------------------
local tab

local function Init()
    if tab then return end
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    ---------------------------------------------------------
    -- 匯出
    ---------------------------------------------------------
    local exportTitle = W.CreateSectionTitle(tab, L["Export"], 320)
    exportTitle:SetPoint("TOPLEFT", 12, -40)

    local exportBox = W.CreateScrollEditBox(tab, 320, 300)
    exportBox:SetPoint("TOPLEFT", 12, -72)

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
    local importTitle = W.CreateSectionTitle(tab, L["Import"], 320)
    importTitle:SetPoint("TOPLEFT", 356, -40)

    local pendingData

    local importBtn = W.CreateButton(tab, L["Import and reload"], "green", 130, 22)
    importBtn:SetEnabled(false)

    local importBox = W.CreateScrollEditBox(tab, 320, 300, function(eb, userChanged)
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
    importBox:SetPoint("TOPLEFT", 356, -72)
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
    note:SetPoint("BOTTOMLEFT", 12, 14)
    note:SetText(L["The export string contains every setting, positions included. \"Import and reload\" only lights up once a valid string is pasted."])

    ---------------------------------------------------------
    -- 重置（原本在「一般」分頁，移過來跟匯入匯出放一起）
    ---------------------------------------------------------
    local resetTitle = W.CreateSectionTitle(tab, L["Reset"], 664)
    resetTitle:SetPoint("TOPLEFT", 12, -414)

    local resetBtn = W.CreateButton(tab, L["Restore all defaults and reload"], "red", 150, 22)
    resetBtn:SetPoint("TOPLEFT", 12, -446)

    local resetConfirm
    resetBtn:SetScript("OnClick", function()
        if not resetConfirm then
            resetConfirm = W.CreateConfirmPopup(ns.Options.panel, 300,
                L["Restore every setting (global, per unit, summons, positions) to its default and reload the UI?"],
                function() ns.DB.ResetAll() end)
        end
        resetConfirm:Show()
    end)

    local resetNote = tab:CreateFontString(nil, "OVERLAY")
    resetNote:SetFontObject(W.fontSmall)
    resetNote:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    resetNote:SetJustifyH("LEFT")
    resetNote:SetText(L["Per-unit reset lives at the bottom of Units > Frame. The /muf reset command does the same thing as this button."])
end

ns.RegisterCallback("ShowOptionsTab", "shareTab", function(id)
    if id ~= "share" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
