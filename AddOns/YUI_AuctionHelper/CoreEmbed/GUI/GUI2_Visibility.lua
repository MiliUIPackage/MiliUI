do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

local GUI2 = YUI and YUI.GUI2
if not (GUI2 and GUI2.Form) then return end

local max = math.max

local function T(key, fallback)
    local locale = YUI.Locale and YUI.Locale:Get("Core")
    local value = locale and locale[key]
    return value and value ~= key and value or fallback
end

local function NormalizeRule(rule, target)
    local service = YUI.Visibility
    if service and service.NormalizeRule then
        return service:NormalizeRule(rule, target)
    end
    rule = type(rule) == "table" and rule or {}
    target = type(target) == "table" and target or {}
    local sourceHide = type(rule.hide) == "table" and rule.hide or {}
    local targetHide = type(target.hide) == "table" and target.hide or {}
    target.combat = rule.combat == "in" or rule.combat == "out"
        and rule.combat or "any"
    target.mounted = rule.mounted == "mounted"
            or rule.mounted == "unmounted"
        and rule.mounted or "any"
    targetHide.noTarget = sourceHide.noTarget == true
    targetHide.housing = sourceHide.housing == true
    targetHide.skyriding = sourceHide.skyriding == true
    target.hide = targetHide
    return target
end

local function IsSupported(stateKey)
    local api = YUI.API and YUI.API.Visibility
    return not api or not api.IsSupported
        or api.IsSupported(stateKey) == true
end

local function CopyRule(rule, target)
    target = type(target) == "table" and target or {}
    local hide = type(target.hide) == "table" and target.hide or {}
    target.combat = rule.combat
    target.mounted = rule.mounted
    hide.noTarget = rule.hide.noTarget == true
    hide.housing = rule.hide.housing == true
    hide.skyriding = rule.hide.skyriding == true
    target.hide = hide
    return target
end

function GUI2.Form:CreateVisibilityRuleEditor(parent, opts)
    opts = type(opts) == "table" and opts or {}
    local width = tonumber(opts.width) or 320
    local popupWidth = max(320, tonumber(opts.popupWidth) or width)
    local labelWidth = tonumber(opts.labelWidth) or 104
    local gap = GUI2:GetMetric("layout.gap.inline", 8)
    local popupPadding = 12
    local innerWidth = popupWidth - (popupPadding * 2)
    local controlWidth = max(120, innerWidth - labelWidth - gap)
    local rowHeight = 30
    local checkboxHeight = 26
    local frame = GUI2:CreateButtonFrame(parent, {
        template = "BackdropTemplate",
        width = width,
        height = opts.height or rowHeight,
    })
    GUI2:SkinDropdownButton(frame)
    frame.rule = NormalizeRule(opts.value, {})
    frame.controls = {}
    frame.gui2Disabled = opts.disabled == true
    frame.gui2Refreshing = false
    frame.gui2Context = opts.context

    local overlayParent = _G.UIParent or parent
    local blocker = GUI2:CreateFrame(overlayParent, {
        mouse = true,
        hidden = true,
    })
    blocker:SetAllPoints(overlayParent)
    blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    blocker:SetFrameLevel(719)

    local panel = GUI2:CreatePanel(overlayParent, {
        width = popupWidth,
        height = 238,
        surface = "color.surface.popup",
        border = "color.popup.border",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetFrameLevel(720)
    panel:EnableMouse(true)
    panel:Hide()

    local function AddLabel(text, y)
        local label = GUI2:CreateText(
            panel,
            text,
            "font.size.md",
            "color.text.secondary",
            "LEFT"
        )
        label:SetPoint(
            "TOPLEFT",
            panel,
            "TOPLEFT",
            popupPadding,
            y
        )
        label:SetSize(labelWidth, rowHeight)
        label:SetJustifyV("MIDDLE")
        return label
    end

    local function Commit(field)
        if frame.gui2Refreshing then return end
        frame:RefreshSummary()
        if type(opts.set) == "function" then
            opts.set(frame:GetValue({}), field, frame)
        end
    end

    local combatLabel = AddLabel(T("visibility.combat", "Combat"), -12)
    local combat = self:CreateDropdown(panel, {
        width = controlWidth,
        height = rowHeight,
        value = frame.rule.combat,
        options = {
            { text = T("visibility.combat.any", "Any time"), value = "any" },
            { text = T("visibility.combat.in", "In combat"), value = "in" },
            { text = T("visibility.combat.out", "Out of combat"), value = "out" },
        },
        set = function(value)
            if frame.gui2Refreshing then return end
            frame.rule.combat = value
            Commit("combat")
        end,
    })
    combat:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        popupPadding + labelWidth + gap,
        -12
    )

    local mountedLabel = AddLabel(T("visibility.mounted", "Mounted"), -50)
    local mounted = self:CreateDropdown(panel, {
        width = controlWidth,
        height = rowHeight,
        value = frame.rule.mounted,
        options = {
            { text = T("visibility.mounted.any", "Any state"), value = "any" },
            { text = T("visibility.mounted.yes", "Mounted only"), value = "mounted" },
            { text = T("visibility.mounted.no", "Unmounted only"), value = "unmounted" },
        },
        set = function(value)
            if frame.gui2Refreshing then return end
            frame.rule.mounted = value
            Commit("mounted")
        end,
    })
    mounted:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        popupPadding + labelWidth + gap,
        -50
    )

    local hideLabel = GUI2:CreateText(
        panel,
        T("visibility.extra_hide", "Also hide when"),
        "font.size.sm",
        "color.text.muted",
        "LEFT"
    )
    hideLabel:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        popupPadding + labelWidth + gap,
        -88
    )

    local unsupportedTooltip = T(
        "visibility.unavailable",
        "This condition is unavailable in the current game version."
    )

    local function CreateHideCheckbox(text, field, stateKey, y)
        local checkbox = self:CreateCheckbox(panel, {
            width = controlWidth,
            height = checkboxHeight,
            text = text,
            checked = frame.rule.hide[field] == true,
            tooltip = not IsSupported(stateKey) and unsupportedTooltip or nil,
            set = function(value)
                if frame.gui2Refreshing then return end
                frame.rule.hide[field] = value == true
                Commit("hide." .. field)
            end,
        })
        checkbox:SetPoint(
            "TOPLEFT",
            panel,
            "TOPLEFT",
            popupPadding + labelWidth + gap,
            y
        )
        checkbox.gui2VisibilityStateKey = stateKey
        frame.controls[#frame.controls + 1] = checkbox
        return checkbox
    end

    local noTarget = CreateHideCheckbox(
        T("visibility.hide.no_target", "No target"),
        "noTarget",
        "target",
        -108
    )
    local housing = CreateHideCheckbox(
        T("visibility.hide.housing", "Inside a house or plot"),
        "housing",
        "housing",
        -136
    )
    local skyriding = CreateHideCheckbox(
        T("visibility.hide.skyriding", "While skyriding"),
        "skyriding",
        "skyriding",
        -164
    )
    local petBattle = self:CreateCheckbox(panel, {
        width = controlWidth,
        height = checkboxHeight,
        text = T(
            "visibility.pet_battle_locked",
            "Always hide during pet battles"
        ),
        checked = true,
        disabled = true,
    })
    petBattle:SetPoint(
        "TOPLEFT",
        panel,
        "TOPLEFT",
        popupPadding + labelWidth + gap,
        -202
    )

    frame.combatLabel = combatLabel
    frame.combat = combat
    frame.mountedLabel = mountedLabel
    frame.mounted = mounted
    frame.hideLabel = hideLabel
    frame.noTarget = noTarget
    frame.housing = housing
    frame.skyriding = skyriding
    frame.petBattle = petBattle
    frame.panel = panel
    frame.blocker = blocker

    local function AddSummary(parts, text)
        if text and text ~= "" then parts[#parts + 1] = text end
    end

    function frame:RefreshSummary()
        local parts = {}
        if self.rule.combat == "in" then
            AddSummary(parts, T("visibility.combat.in", "In combat"))
        elseif self.rule.combat == "out" then
            AddSummary(parts, T("visibility.combat.out", "Out of combat"))
        end
        if self.rule.mounted == "mounted" then
            AddSummary(parts, T("visibility.mounted.yes", "Mounted only"))
        elseif self.rule.mounted == "unmounted" then
            AddSummary(parts, T("visibility.mounted.no", "Unmounted only"))
        end
        if self.rule.hide.noTarget == true then
            AddSummary(parts, T("visibility.hide.no_target", "No target"))
        end
        if self.rule.hide.housing == true then
            AddSummary(parts, T(
                "visibility.hide.housing",
                "Inside a house or plot"
            ))
        end
        if self.rule.hide.skyriding == true then
            AddSummary(parts, T("visibility.hide.skyriding", "While skyriding"))
        end

        local summary
        if #parts == 0 then
            summary = T("visibility.summary.unrestricted", "Unrestricted")
        else
            summary = parts[1]
            if parts[2] then summary = summary .. " · " .. parts[2] end
            if #parts > 2 then
                summary = summary .. " · " .. string.format(
                    T("visibility.summary.more", "+%d"),
                    #parts - 2
                )
            end
        end
        self.gui2FullText = summary
        if self.text then self.text:SetText(" " .. summary) end
        return summary
    end

    function frame:IsPanelOpen()
        return self.panel and self.panel:IsShown() == true
    end

    function frame:ClosePanel()
        if self.blocker then self.blocker:Hide() end
        if self.panel then self.panel:Hide() end
        if GUI2.VisibilityRuleOpenEditor == self then
            GUI2.VisibilityRuleOpenEditor = nil
        end
        self:RefreshTheme()
        return true
    end

    function frame:OpenPanel()
        if self.gui2Disabled then return false end
        local openEditor = GUI2.VisibilityRuleOpenEditor
        if openEditor and openEditor ~= self and openEditor.ClosePanel then
            openEditor:ClosePanel()
        end
        self.panel:ClearAllPoints()
        local bottom = self.GetBottom and self:GetBottom()
        if bottom and bottom < self.panel:GetHeight() + 12 then
            self.panel:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
        else
            self.panel:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
        end
        self.blocker:Show()
        self.panel:Show()
        GUI2.VisibilityRuleOpenEditor = self
        if self.bg then GUI2:SetBorderColor(self.bg, "color.border.accent") end
        return true
    end

    function frame:SetContext(context)
        if self.gui2Context == context then return false end
        self:ClosePanel()
        self.gui2Context = context
        return true
    end

    function frame:GetContext()
        return self.gui2Context
    end

    function frame:GetValue(target)
        return CopyRule(self.rule, target)
    end

    function frame:SetValue(rule, silent)
        NormalizeRule(rule, self.rule)
        self.gui2Refreshing = true
        self.combat:SetValue(self.rule.combat, true)
        self.mounted:SetValue(self.rule.mounted, true)
        self.noTarget:SetValue(self.rule.hide.noTarget, true)
        self.housing:SetValue(self.rule.hide.housing, true)
        self.skyriding:SetValue(self.rule.hide.skyriding, true)
        self.petBattle:SetValue(true, true)
        self.gui2Refreshing = false
        self:RefreshSummary()
        if silent ~= true then Commit("rule") end
        return true
    end

    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled == true
        if self.gui2Disabled then self:ClosePanel() end
        self:RefreshCapabilities()
        if self.gui2Disabled then
            if self.Disable then self:Disable() end
        elseif self.Enable then
            self:Enable()
        end
        self:RefreshTheme()
        return true
    end

    function frame:RefreshTheme()
        if self.bg then
            self.bg.gui2Surface = self.gui2Disabled
                and "color.control.disabled" or "color.control.bg"
            GUI2:RefreshPrimitive(self.bg)
            GUI2:SetBorderColor(
                self.bg,
                self.gui2Disabled
                    and "color.border.subtle" or "color.border.default"
            )
        end
        if self.text then
            GUI2:SetTextColorKey(
                self.text,
                self.gui2Disabled
                    and "color.text.disabled" or "color.text.primary"
            )
        end
        if self.arrow then
            GUI2:SetDropdownGlyphColor(
                self.arrow,
                self.gui2Disabled
                    and "color.text.disabled" or "color.accent.primary"
            )
        end
    end

    function frame:RefreshCapabilities()
        self.combat:SetDisabled(
            self.gui2Disabled or not IsSupported("combat")
        )
        self.mounted:SetDisabled(
            self.gui2Disabled or not IsSupported("mounted")
        )
        self.noTarget:SetDisabled(
            self.gui2Disabled or not IsSupported("target")
        )
        self.housing:SetDisabled(
            self.gui2Disabled or not IsSupported("housing")
        )
        self.skyriding:SetDisabled(
            self.gui2Disabled or not IsSupported("skyriding")
        )
        self.petBattle:SetDisabled(true)
        return true
    end

    blocker:SetScript("OnMouseDown", function()
        frame:ClosePanel()
    end)
    frame:SetScript("OnMouseUp", function()
        if frame:IsPanelOpen() then
            frame:ClosePanel()
        else
            frame:OpenPanel()
        end
    end)
    frame:SetScript("OnEnter", function()
        if not frame.gui2Disabled and frame.bg then
            GUI2:SetBorderColor(frame.bg, "color.border.accent")
        end
    end)
    frame:SetScript("OnLeave", function()
        if not frame:IsPanelOpen() then frame:RefreshTheme() end
    end)
    if frame.HookScript then
        frame:HookScript("OnHide", function()
            frame:ClosePanel()
        end)
    end

    frame:RefreshSummary()
    frame:SetDisabled(opts.disabled)
    GUI2:RegisterThemeObject(frame)
    return frame
end
