------------------------------------------------------------
-- MiliUI: Ayije_CDM 等比例字型覆寫
-- 將 CDM.Pixel.FontSize 從像素完美改為等比例縮放
------------------------------------------------------------

-- 保存原始 Pixel.FontSize 的引用
local originalPixelFontSize

local function ProportionalFontSize(desiredPx)
    return desiredPx * (UIParent:GetEffectiveScale() or 1)
end

local function ApplyOverride(CDM)
    if not CDM or not CDM.Pixel or not CDM.Pixel.FontSize then return end
    if not originalPixelFontSize then
        originalPixelFontSize = CDM.Pixel.FontSize
    end
    CDM.Pixel.FontSize = ProportionalFontSize
    if CDM.UpdatePlayerCastBar then
        CDM:UpdatePlayerCastBar()
    end
end

local function RemoveOverride(CDM)
    if not CDM or not CDM.Pixel then return end
    if originalPixelFontSize then
        CDM.Pixel.FontSize = originalPixelFontSize
    end
    if CDM.UpdatePlayerCastBar then
        CDM:UpdatePlayerCastBar()
    end
end

EventUtil.ContinueOnAddOnLoaded("Ayije_CDM", function()
    C_Timer.After(0.6, function()
        if not MiliUI_CastBarEnhanceDB or not MiliUI_CastBarEnhanceDB.proportionalFont then return end
        ApplyOverride(_G["Ayije_CDM"])
    end)
end)

------------------------------------------------------------
-- PUBLIC API（供 Settings toggle 使用）
------------------------------------------------------------
MiliUI_CastBarPixelFont = {
    Apply = function()
        MiliUI_CastBarEnhanceDB.proportionalFont = true
        ApplyOverride(_G["Ayije_CDM"])
    end,
    Remove = function()
        MiliUI_CastBarEnhanceDB.proportionalFont = false
        RemoveOverride(_G["Ayije_CDM"])
    end,
    Toggle = function(enabled)
        if enabled then
            MiliUI_CastBarPixelFont.Apply()
        else
            MiliUI_CastBarPixelFont.Remove()
        end
    end,
}
