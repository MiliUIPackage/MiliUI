-- Config/TabSizes.lua - Icon Sizes Tab
-- Controls for icon dimensions across different viewers

local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L

local function EnsureTable(key)
    if not CDM.db[key] or type(CDM.db[key]) ~= "table" then
        local d = CDM.defaults[key]
        CDM.db[key] = { w = d.w, h = d.h }
    end
    return CDM.db[key]
end

local function CreateSizesTab(page, tabId)
    local scrollChild = UI.CreateScrollableTab(page, "AyijeCDM_SizesScrollFrame", 780)

    -- Essential
    local essentialHeader = UI.CreateHeader(scrollChild, L["Essential"])
    essentialHeader:SetPoint("TOPLEFT", 0, 0)

    page.controls.s1 = UI.CreateModernSlider(scrollChild, L["Row 1 Width"], 20, 100, CDM.db.sizeEssRow1.w, function(v) CDM.db.sizeEssRow1.w = v; API:RefreshConfig() end)
    page.controls.s1:SetPoint("TOPLEFT", essentialHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s2 = UI.CreateModernSlider(scrollChild, L["Row 1 Height"], 20, 100, CDM.db.sizeEssRow1.h, function(v) CDM.db.sizeEssRow1.h = v; API:RefreshConfig() end)
    page.controls.s2:SetPoint("TOPLEFT", page.controls.s1, "BOTTOMLEFT", 0, -10)

    page.controls.s3 = UI.CreateModernSlider(scrollChild, L["Row 2 Width"], 20, 100, CDM.db.sizeEssRow2.w, function(v) CDM.db.sizeEssRow2.w = v; API:RefreshConfig() end)
    page.controls.s3:SetPoint("TOPLEFT", page.controls.s2, "BOTTOMLEFT", 0, -10)
    page.controls.s4 = UI.CreateModernSlider(scrollChild, L["Row 2 Height"], 20, 100, CDM.db.sizeEssRow2.h, function(v) CDM.db.sizeEssRow2.h = v; API:RefreshConfig() end)
    page.controls.s4:SetPoint("TOPLEFT", page.controls.s3, "BOTTOMLEFT", 0, -10)

    -- Utility
    local utilityHeader = UI.CreateHeader(scrollChild, L["Utility"])
    utilityHeader:SetPoint("TOPLEFT", page.controls.s4, "BOTTOMLEFT", 0, -15)

    page.controls.s5 = UI.CreateModernSlider(scrollChild, L["Width"], 20, 100, CDM.db.sizeUtility.w, function(v) CDM.db.sizeUtility.w = v; API:RefreshConfig() end)
    page.controls.s5:SetPoint("TOPLEFT", utilityHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s6 = UI.CreateModernSlider(scrollChild, L["Height"], 20, 100, CDM.db.sizeUtility.h, function(v) CDM.db.sizeUtility.h = v; API:RefreshConfig() end)
    page.controls.s6:SetPoint("TOPLEFT", page.controls.s5, "BOTTOMLEFT", 0, -10)

    -- Buff
    local buffHeader = UI.CreateHeader(scrollChild, L["Buff"])
    buffHeader:SetPoint("TOPLEFT", page.controls.s6, "BOTTOMLEFT", 0, -15)

    page.controls.s7 = UI.CreateModernSlider(scrollChild, L["Width"], 20, 100, CDM.db.sizeBuff.w, function(v) CDM.db.sizeBuff.w = v; API:RefreshConfig() end)
    page.controls.s7:SetPoint("TOPLEFT", buffHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s8 = UI.CreateModernSlider(scrollChild, L["Height"], 20, 100, CDM.db.sizeBuff.h, function(v) CDM.db.sizeBuff.h = v; API:RefreshConfig() end)
    page.controls.s8:SetPoint("TOPLEFT", page.controls.s7, "BOTTOMLEFT", 0, -10)

    -- Secondary Buff
    local secBuffHeader = UI.CreateHeader(scrollChild, L["Secondary Buff"])
    secBuffHeader:SetPoint("TOPLEFT", page.controls.s8, "BOTTOMLEFT", 0, -15)

    local secSize = EnsureTable("sizeBuffSecondary")
    page.controls.s9 = UI.CreateModernSlider(scrollChild, L["Width"], 20, 100, secSize.w, function(v) EnsureTable("sizeBuffSecondary").w = v; API:RefreshConfig() end)
    page.controls.s9:SetPoint("TOPLEFT", secBuffHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s10 = UI.CreateModernSlider(scrollChild, L["Height"], 20, 100, secSize.h, function(v) EnsureTable("sizeBuffSecondary").h = v; API:RefreshConfig() end)
    page.controls.s10:SetPoint("TOPLEFT", page.controls.s9, "BOTTOMLEFT", 0, -10)

    -- Tertiary Buff
    local tertBuffHeader = UI.CreateHeader(scrollChild, L["Tertiary Buff"])
    tertBuffHeader:SetPoint("TOPLEFT", page.controls.s10, "BOTTOMLEFT", 0, -15)

    local tertSize = EnsureTable("sizeBuffTertiary")
    page.controls.s11 = UI.CreateModernSlider(scrollChild, L["Width"], 20, 100, tertSize.w, function(v) EnsureTable("sizeBuffTertiary").w = v; API:RefreshConfig() end)
    page.controls.s11:SetPoint("TOPLEFT", tertBuffHeader, "BOTTOMLEFT", 0, -15)
    page.controls.s12 = UI.CreateModernSlider(scrollChild, L["Height"], 20, 100, tertSize.h, function(v) EnsureTable("sizeBuffTertiary").h = v; API:RefreshConfig() end)
    page.controls.s12:SetPoint("TOPLEFT", page.controls.s11, "BOTTOMLEFT", 0, -10)
end

API:RegisterConfigTab("sizes", L["Icon Sizes"], CreateSizesTab, 1)
