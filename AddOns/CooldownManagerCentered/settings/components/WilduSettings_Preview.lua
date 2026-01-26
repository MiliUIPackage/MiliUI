local _, ns = ...

--- WilduSettings_Preview

local WilduSettings = ns.WilduSettings

---@class WilduSettings_Preview
local Preview = {}
WilduSettings.Preview = Preview

local PREVIEW_IMAGE_SIZE = 330
local PREVIEW_PADDING = 16
local BORDER_SHRINK = 3

---@type Frame|nil
local PreviewFrame = nil

---Initialize the preview frame
---@return Frame|nil PreviewFrame The created preview frame or nil if SettingsPanel not available
function Preview:Initialize()
    if PreviewFrame then
        return PreviewFrame
    end

    if not SettingsPanel or not SettingsPanel.CategoryList then
        return nil
    end

    -- Create preview frame attached to settings panel category list
    PreviewFrame = CreateFrame("Frame", "CMC_WilduSettings_PreviewFrame", SettingsPanel.CategoryList)
    PreviewFrame:SetSize(PREVIEW_IMAGE_SIZE + (2 * PREVIEW_PADDING), 100)
    PreviewFrame:SetPoint("TOPRIGHT", SettingsPanel.CategoryList, "TOPRIGHT", -8, 0)
    PreviewFrame:Hide()

    PreviewFrame.image = PreviewFrame:CreateTexture(nil, "ARTWORK")
    PreviewFrame.image:SetPoint("TOP", 0, -PREVIEW_PADDING)
    PreviewFrame.image:SetHeight(PREVIEW_IMAGE_SIZE)
    PreviewFrame.image:SetWidth(PREVIEW_IMAGE_SIZE)
    PreviewFrame.image:SetTexture("Interface/AddOns/CooldownManagerCentered/Media/SettingsPreview/preview.png")
    PreviewFrame.image:SetTexCoord(0, 1, 0, 1)

    -- The mask creates a rounded corner/border effect on the preview image
    local mask = PreviewFrame:CreateMaskTexture(nil, "OVERLAY")
    mask:SetPoint("TOPLEFT", PreviewFrame.image, "TOPLEFT", 0, 0)
    mask:SetPoint("BOTTOMRIGHT", PreviewFrame.image, "BOTTOMRIGHT", 0, 0)
    mask:SetTexture("Interface/AddOns/CooldownManagerCentered/Media/SettingsPreview/PreviewMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    PreviewFrame.image:AddMaskTexture(mask)
    PreviewFrame.mask = mask

    PreviewFrame.text = PreviewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2Outline")
    PreviewFrame.text:SetPoint("TOP", PreviewFrame.image, "BOTTOM", 0, -6)
    PreviewFrame.text:SetJustifyH("LEFT")
    PreviewFrame.text:SetWordWrap(true)
    PreviewFrame.text:SetWidth(PreviewFrame.image:GetWidth() - 12)
    PreviewFrame:SetHeight(PREVIEW_IMAGE_SIZE + PREVIEW_PADDING + PreviewFrame.text:GetHeight() + 20)

    local bg = ns.API:CreateNineSliceFrame(PreviewFrame, "Dark")
    bg:SetCornerSize(28)
    PreviewFrame.Background = bg
    bg:SetFrameLevel(PreviewFrame:GetFrameLevel())
    bg:SetPoint("TOPLEFT", PreviewFrame, "TOPLEFT", BORDER_SHRINK, -BORDER_SHRINK)
    bg:SetPoint("BOTTOMRIGHT", PreviewFrame, "BOTTOMRIGHT", -BORDER_SHRINK, BORDER_SHRINK)

    return PreviewFrame
end

---Get the preview frame, initializing if necessary
---@return Frame|nil PreviewFrame The preview frame or nil if not available
function Preview:GetFrame()
    if not PreviewFrame then
        self:Initialize()
    end
    return PreviewFrame
end

---Show preview for a specific setting variable
---@param variable string The setting variable name to preview
function Preview:ShowForVariable(variable)
    local frame = self:GetFrame()
    if not frame then
        return
    end

    local previewData = WilduSettings.settingPreview[variable]
    if not previewData or not previewData.image then
        frame:Hide()
        return
    end

    frame.image:SetTexture("Interface/AddOns/CooldownManagerCentered/Media/SettingsPreview/" .. previewData.image .. ".png")
    
    if previewData.text then
        frame.text:SetText(previewData.text)
    else
        frame.text:SetText("")
    end

    frame:SetHeight(PREVIEW_IMAGE_SIZE + PREVIEW_PADDING + frame.text:GetHeight() + 20)

    frame:Show()
end

---Hide the preview frame
function Preview:Hide()
    local frame = self:GetFrame()
    if frame then
        frame:Hide()
    end
end

---Set the preview image directly (for custom use cases)
---@param imagePath string Full path to the image texture
---@param description string|nil Optional description text
function Preview:SetImage(imagePath, description)
    local frame = self:GetFrame()
    if not frame then return end

    frame.image:SetTexture(imagePath)

    if description then
        frame.text:SetText(description)
    else
        frame.text:SetText("")
    end

    frame:SetHeight(PREVIEW_IMAGE_SIZE + PREVIEW_PADDING + frame.text:GetHeight() + 20)
    frame:Show()
end

---Update the WilduSettings:SetVariableToPreview function to use the new Preview component
---This maintains backward compatibility with existing code
function WilduSettings:SetVariableToPreview(variable)
    if variable then
        Preview:ShowForVariable(variable)
    else
        Preview:Hide()
    end
end
