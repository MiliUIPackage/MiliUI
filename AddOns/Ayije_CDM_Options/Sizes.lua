local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function SetSizeField(key, field, value)
    local current = CDM.db[key]
    local updated = { w = current.w, h = current.h }
    updated[field] = value
    CDM.db[key] = updated
end

local function CreateSizesTab(page, tabId)
    local essentialHeader = UI.CreateHeader(page, L["Essential"])
    essentialHeader:SetPoint("TOPLEFT", 35, -40)

    page.controls.s1 = UI.CreateModernSlider(page, L["Row 1 Width"], 20, 100, CDM.db.sizeEssRow1.w, function(v) SetSizeField("sizeEssRow1", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s1:SetPoint("TOPLEFT", essentialHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s2 = UI.CreateModernSlider(page, L["Row 1 Height"], 20, 100, CDM.db.sizeEssRow1.h, function(v) SetSizeField("sizeEssRow1", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s2:SetPoint("TOPLEFT", page.controls.s1, "BOTTOMLEFT", 0, -10)

    page.controls.s3 = UI.CreateModernSlider(page, L["Row 2 Width"], 20, 100, CDM.db.sizeEssRow2.w, function(v) SetSizeField("sizeEssRow2", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s3:SetPoint("TOPLEFT", page.controls.s2, "BOTTOMLEFT", 0, -10)
    page.controls.s4 = UI.CreateModernSlider(page, L["Row 2 Height"], 20, 100, CDM.db.sizeEssRow2.h, function(v) SetSizeField("sizeEssRow2", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s4:SetPoint("TOPLEFT", page.controls.s3, "BOTTOMLEFT", 0, -10)

    local utilityHeader = UI.CreateHeader(page, L["Utility"])
    utilityHeader:SetPoint("TOPLEFT", page.controls.s4, "BOTTOMLEFT", 0, -15)

    page.controls.s5 = UI.CreateModernSlider(page, L["Width"], 20, 100, CDM.db.sizeUtility.w, function(v) SetSizeField("sizeUtility", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s5:SetPoint("TOPLEFT", utilityHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s6 = UI.CreateModernSlider(page, L["Height"], 20, 100, CDM.db.sizeUtility.h, function(v) SetSizeField("sizeUtility", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s6:SetPoint("TOPLEFT", page.controls.s5, "BOTTOMLEFT", 0, -10)

    local buffHeader = UI.CreateHeader(page, L["Buff"])
    buffHeader:SetPoint("TOPLEFT", page.controls.s6, "BOTTOMLEFT", 0, -15)

    page.controls.s7 = UI.CreateModernSlider(page, L["Width"], 20, 100, CDM.db.sizeBuff.w, function(v) SetSizeField("sizeBuff", "w", v); API:Refresh("LAYOUT") end)
    page.controls.s7:SetPoint("TOPLEFT", buffHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s8 = UI.CreateModernSlider(page, L["Height"], 20, 100, CDM.db.sizeBuff.h, function(v) SetSizeField("sizeBuff", "h", v); API:Refresh("LAYOUT") end)
    page.controls.s8:SetPoint("TOPLEFT", page.controls.s7, "BOTTOMLEFT", 0, -10)
end

API:RegisterConfigTab("sizes", L["Icon Sizes"], CreateSizesTab, 1)
