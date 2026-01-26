local _, ns = ...

local API = {}
ns.API = API

local SliceFrameMixin = {}

function SliceFrameMixin:CreatePieces(n)
    if self.pieces then
        return
    end
    self.pieces = {}
    self.numSlices = n

    for i = 1, n do
        self.pieces[i] = self:CreateTexture(nil, "BORDER")
        self.pieces[i]:ClearAllPoints()
    end

    self:SetCornerSize(16)

    if n == 3 then
        self.pieces[1]:SetPoint("CENTER", self, "LEFT", 0, 0)
        self.pieces[3]:SetPoint("CENTER", self, "RIGHT", 0, 0)
        self.pieces[2]:SetPoint("TOPLEFT", self.pieces[1], "TOPRIGHT", 0, 0)
        self.pieces[2]:SetPoint("BOTTOMRIGHT", self.pieces[3], "BOTTOMLEFT", 0, 0)

        self.pieces[1]:SetTexCoord(0, 0.25, 0, 1)
        self.pieces[2]:SetTexCoord(0.25, 0.75, 0, 1)
        self.pieces[3]:SetTexCoord(0.75, 1, 0, 1)
    elseif n == 9 then
        self.pieces[1]:SetPoint("CENTER", self, "TOPLEFT", 0, 0)
        self.pieces[3]:SetPoint("CENTER", self, "TOPRIGHT", 0, 0)
        self.pieces[7]:SetPoint("CENTER", self, "BOTTOMLEFT", 0, 0)
        self.pieces[9]:SetPoint("CENTER", self, "BOTTOMRIGHT", 0, 0)
        self.pieces[2]:SetPoint("TOPLEFT", self.pieces[1], "TOPRIGHT", 0, 0)
        self.pieces[2]:SetPoint("BOTTOMRIGHT", self.pieces[3], "BOTTOMLEFT", 0, 0)
        self.pieces[4]:SetPoint("TOPLEFT", self.pieces[1], "BOTTOMLEFT", 0, 0)
        self.pieces[4]:SetPoint("BOTTOMRIGHT", self.pieces[7], "TOPRIGHT", 0, 0)
        self.pieces[5]:SetPoint("TOPLEFT", self.pieces[1], "BOTTOMRIGHT", 0, 0)
        self.pieces[5]:SetPoint("BOTTOMRIGHT", self.pieces[9], "TOPLEFT", 0, 0)
        self.pieces[6]:SetPoint("TOPLEFT", self.pieces[3], "BOTTOMLEFT", 0, 0)
        self.pieces[6]:SetPoint("BOTTOMRIGHT", self.pieces[9], "TOPRIGHT", 0, 0)
        self.pieces[8]:SetPoint("TOPLEFT", self.pieces[7], "TOPRIGHT", 0, 0)
        self.pieces[8]:SetPoint("BOTTOMRIGHT", self.pieces[9], "BOTTOMLEFT", 0, 0)

        self.pieces[1]:SetTexCoord(0, 0.25, 0, 0.25)
        self.pieces[2]:SetTexCoord(0.25, 0.75, 0, 0.25)
        self.pieces[3]:SetTexCoord(0.75, 1, 0, 0.25)
        self.pieces[4]:SetTexCoord(0, 0.25, 0.25, 0.75)
        self.pieces[5]:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        self.pieces[6]:SetTexCoord(0.75, 1, 0.25, 0.75)
        self.pieces[7]:SetTexCoord(0, 0.25, 0.75, 1)
        self.pieces[8]:SetTexCoord(0.25, 0.75, 0.75, 1)
        self.pieces[9]:SetTexCoord(0.75, 1, 0.75, 1)
    end
end

function SliceFrameMixin:SetCornerSize(a)
    if self.numSlices == 3 then
        self.pieces[1]:SetSize(a, 2 * a)
        self.pieces[3]:SetSize(a, 2 * a)
    elseif self.numSlices == 9 then
        self.pieces[1]:SetSize(a, a)
        self.pieces[3]:SetSize(a, a)
        self.pieces[7]:SetSize(a, a)
        self.pieces[9]:SetSize(a, a)
    end
end

function SliceFrameMixin:SetCornerSizeByScale(scale)
    self:SetCornerSize(16 * scale)
end

function SliceFrameMixin:SetTexture(tex)
    for i = 1, #self.pieces do
        self.pieces[i]:SetTexture(tex)
    end
end

function SliceFrameMixin:SetDisableSharpening(state)
    for i = 1, #self.pieces do
        self.pieces[i]:SetSnapToPixelGrid(not state)
    end
end

function SliceFrameMixin:SetColor(r, g, b)
    for i = 1, #self.pieces do
        self.pieces[i]:SetVertexColor(r, g, b)
    end
end

function SliceFrameMixin:CoverParent(padding)
    padding = padding or 0
    local parent = self:GetParent()
    if parent then
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "TOPLEFT", -padding, padding)
        self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", padding, -padding)
    end
end

function SliceFrameMixin:ShowBackground(state)
    for _, piece in ipairs(self.pieces) do
        piece:SetShown(state)
    end
end

---Available nine-slice layout styles
local NineSliceLayouts = {
    Dark = true,
}

---Create a nine-slice frame with custom border texture
---@param parent Frame Parent frame to attach the nine-slice to
---@param layoutName? string Layout name from NineSliceLayouts
---@return Frame nineSliceFrame Frame with SliceFrameMixin methods (SetCornerSize, CoverParent, etc.)
function API:CreateNineSliceFrame(parent, layoutName)
    if not (layoutName and NineSliceLayouts[layoutName]) then
        layoutName = "Dark"
    end
    local f = CreateFrame("Frame", nil, parent)
    Mixin(f, SliceFrameMixin)
    f:CreatePieces(9)
    f:SetTexture("Interface/AddOns/CooldownManagerCentered/Media/Art/" .. layoutName)
    f:ClearAllPoints()
    return f
end

function API:RefreshCooldownManager()
    C_Timer.After(0.01, function()
        ns.StyledIcons:RefreshAll()
        ns.CooldownManager.Initialize()
        ns.Stacks:ApplyAllStackFonts()
    end)
end

function API:IsSomeAddOnRestrictionActive()
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
        for i = 0, 4 do
            if C_RestrictedActions.IsAddOnRestrictionActive(i) then
                return true
            end
        end
    end
    return false
end

StaticPopupDialogs["CMC_RELOAD_UI_ASK"] = {
    text = "Some settings won't take effect until you reload the UI. Reload now?",
    button1 = "Reload",
    button2 = "Not now",
    OnAccept = function(self, profileName)
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function API:ShowReloadUIConfirmation()
    StaticPopup_Show("CMC_RELOAD_UI_ASK")
end
