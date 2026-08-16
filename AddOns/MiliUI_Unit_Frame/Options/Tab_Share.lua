------------------------------------------------------------
-- 「設定檔」分頁：設定匯入匯出 ＋ 全部重置
-- 原生 C_EncodingUtil：SerializeCBOR → CompressString → EncodeBase64
-- 前綴帶版本 MILIUF!1!，每步 pcall（參考 Ayije_CDM/Config/ProfileIO.lua）
-- UX 抄 Cell：匯入框即時解析、成功才亮按鈕、錯誤顯示在標題
------------------------------------------------------------
local _, ns = ...

local W = ns.W

local WIRE_PREFIX = "MILIUF!1!"

ns.Share = {}
local Share = ns.Share

------------------------------------------------------------
-- 編解碼
------------------------------------------------------------
function Share.Export()
    if not (C_EncodingUtil and C_EncodingUtil.SerializeCBOR) then
        return nil, "此版本客戶端缺少 C_EncodingUtil"
    end
    local ok, cbor = pcall(C_EncodingUtil.SerializeCBOR, ns.db)
    if not ok or not cbor then return nil, "序列化失敗" end
    local ok2, compressed = pcall(C_EncodingUtil.CompressString, cbor)
    if not ok2 or not compressed then return nil, "壓縮失敗" end
    local ok3, base64 = pcall(C_EncodingUtil.EncodeBase64, compressed)
    if not ok3 or not base64 then return nil, "編碼失敗" end
    return WIRE_PREFIX .. base64
end

function Share.Decode(text)
    if type(text) ~= "string" then return nil, "空字串" end
    text = text:gsub("%s+", "")
    if text == "" then return nil, "空字串" end
    if text:sub(1, #WIRE_PREFIX) ~= WIRE_PREFIX then
        return nil, "前綴不符（不是米利頭像的匯出字串）"
    end
    local payload = text:sub(#WIRE_PREFIX + 1)
    local ok, compressed = pcall(C_EncodingUtil.DecodeBase64, payload)
    if not ok or not compressed then return nil, "Base64 解碼失敗" end
    local ok2, cbor = pcall(C_EncodingUtil.DecompressString, compressed)
    if not ok2 or not cbor then return nil, "解壓縮失敗" end
    local ok3, data = pcall(C_EncodingUtil.DeserializeCBOR, cbor)
    if not ok3 or type(data) ~= "table" then return nil, "反序列化失敗" end
    if type(data.schemaVersion) ~= "number" then return nil, "缺少版本欄位" end
    if data.schemaVersion > ns.DB_VERSION then
        return nil, "字串來自較新版本，請先更新插件"
    end
    return data
end

function Share.Import(data)
    -- 覆寫整份 DB（保底補齊 defaults 交給下次載入的 MergeDefaults）
    wipe(MiliUI_UnitFrame_DB)
    for k, v in pairs(data) do
        MiliUI_UnitFrame_DB[k] = v
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
    local exportTitle = W.CreateSectionTitle(tab, "匯出", 320)
    exportTitle:SetPoint("TOPLEFT", 12, -40)

    local exportBox = W.CreateScrollEditBox(tab, 320, 300)
    exportBox:SetPoint("TOPLEFT", 12, -72)

    local exportBtn = W.CreateButton(tab, "產生匯出字串", "accent", 130, 22)
    exportBtn:SetPoint("TOPLEFT", exportBox, "BOTTOMLEFT", 0, -8)
    exportBtn:SetScript("OnClick", function()
        local str, err = Share.Export()
        if str then
            exportBox.editBox:SetText(str)
            exportBox.editBox:HighlightText()
            exportBox.editBox:SetFocus()
            exportTitle.text:SetText("匯出（Ctrl+C 複製）")
        else
            exportTitle.text:SetText("|cffff2222匯出失敗：" .. (err or "?") .. "|r")
        end
    end)

    -- 匯出框內容防改（一改就重新全選，方便複製）
    exportBox.editBox:SetScript("OnChar", function(self)
        self:HighlightText()
    end)

    ---------------------------------------------------------
    -- 匯入
    ---------------------------------------------------------
    local importTitle = W.CreateSectionTitle(tab, "匯入", 320)
    importTitle:SetPoint("TOPLEFT", 356, -40)

    local pendingData

    local importBtn = W.CreateButton(tab, "匯入並重載", "green", 130, 22)
    importBtn:SetEnabled(false)

    local importBox = W.CreateScrollEditBox(tab, 320, 300, function(eb, userChanged)
        if not userChanged then return end
        local data, err = Share.Decode(eb:GetText())
        if data then
            pendingData = data
            importTitle.text:SetText("匯入：|cff44ff44字串有效|r")
            importBtn:SetEnabled(true)
        else
            pendingData = nil
            importBtn:SetEnabled(false)
            if eb:GetText() ~= "" then
                importTitle.text:SetText("匯入：|cffff2222" .. (err or "無效") .. "|r")
            else
                importTitle.text:SetText("匯入")
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
                "匯入會覆寫目前所有設定並重載介面，確定？",
                function() Share.Import(pendingData) end)
        end
        confirm:Show()
    end)

    local note = tab:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetPoint("BOTTOMLEFT", 12, 14)
    note:SetText("匯出字串包含全部設定（含位置）。貼上有效字串後「匯入並重載」才會亮起。")

    ---------------------------------------------------------
    -- 重置（原本在「一般」分頁，移過來跟匯入匯出放一起）
    ---------------------------------------------------------
    local resetTitle = W.CreateSectionTitle(tab, "重置", 664)
    resetTitle:SetPoint("TOPLEFT", 12, -414)

    local resetBtn = W.CreateButton(tab, "全部恢復預設並重載", "red", 150, 22)
    resetBtn:SetPoint("TOPLEFT", 12, -446)

    local resetConfirm
    resetBtn:SetScript("OnClick", function()
        if not resetConfirm then
            resetConfirm = W.CreateConfirmPopup(ns.Options.panel, 300,
                "把所有設定（全域＋每個單位＋召喚物＋位置）恢復成預設值並重新載入介面？",
                function() ns.DB.ResetAll() end)
        end
        resetConfirm:Show()
    end)

    local resetNote = tab:CreateFontString(nil, "OVERLAY")
    resetNote:SetFontObject(W.fontSmall)
    resetNote:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    resetNote:SetJustifyH("LEFT")
    resetNote:SetText("單一單位的重置在「單位」分頁 → 框架 的最下方。指令 /muf reset 等同這顆按鈕。")
end

ns.RegisterCallback("ShowOptionsTab", "shareTab", function(id)
    if id ~= "share" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
