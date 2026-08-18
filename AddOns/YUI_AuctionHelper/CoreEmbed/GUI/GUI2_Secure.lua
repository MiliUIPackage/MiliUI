local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local CreateFrame = CreateFrame
local tinsert = table.insert
local wipe = wipe
local unpack = unpack

local SecurityAPI = YUI.API and YUI.API.Security or YUI.WOW_API or {}

GUI2.Secure = GUI2.Secure or {}
local Secure = GUI2.Secure

Secure.unsafeQueue = Secure.unsafeQueue or {}

local SECURE_KINDS = {
    spell = true,
    item = true,
    toy = true,
    macro = true,
    click = true,
    target = true,
    raidtarget = true,
    worldmarker = true,
    returnhome = true,
    teleporthome = true,
    secure = true,
}

local ACTION_HOST_NOOP = ATTRIBUTE_NOOP or ""
local ACTION_HOST_DEFAULT_CLICKS = { "AnyUp", "AnyDown" }
local ACTION_HOST_ATTRS = {
    "type",
    "macrotext",
    "spell",
    "item",
    "toy",
    "marker",
    "action",
    "clickbutton",
    "unit",
    "target",
    "house-neighborhood-guid",
    "house-guid",
    "house-plot-id",
}

local ACTION_HOST_KEYS = {
    left = { suffix = "1", button = "LeftButton" },
    right = { suffix = "2", button = "RightButton" },
    middle = { suffix = "3", button = "MiddleButton" },
    altLeft = { prefix = "alt-", suffix = "1", button = "LeftButton", modifier = "alt" },
    altRight = { prefix = "alt-", suffix = "2", button = "RightButton", modifier = "alt" },
    shiftLeft = { prefix = "shift-", suffix = "1", button = "LeftButton", modifier = "shift" },
    shiftRight = { prefix = "shift-", suffix = "2", button = "RightButton", modifier = "shift" },
    ctrlLeft = { prefix = "ctrl-", suffix = "1", button = "LeftButton", modifier = "ctrl" },
    ctrlRight = { prefix = "ctrl-", suffix = "2", button = "RightButton", modifier = "ctrl" },
}

local ACTION_HOST_KEY_ORDER = {
    "left", "right", "middle",
    "altLeft", "altRight",
    "shiftLeft", "shiftRight",
    "ctrlLeft", "ctrlRight",
}

local function InLockdown()
    if SecurityAPI.InCombatLockdown then
        return SecurityAPI.InCombatLockdown() and true or false
    end
    if InCombatLockdown then
        return InCombatLockdown() and true or false
    end
    return false
end

local function IsAltDown()
    return IsAltKeyDown and IsAltKeyDown()
end

local function IsShiftDown()
    return IsShiftKeyDown and IsShiftKeyDown()
end

local function IsCtrlDown()
    return IsControlKeyDown and IsControlKeyDown()
end

local function DefaultGetClickKey(actions, button)
    if button == "LeftButton" then
        if IsAltDown() and actions and actions.altLeft then return "altLeft" end
        if IsShiftDown() and actions and actions.shiftLeft then return "shiftLeft" end
        if IsCtrlDown() and actions and actions.ctrlLeft then return "ctrlLeft" end
        return "left"
    elseif button == "RightButton" then
        if IsAltDown() and actions and actions.altRight then return "altRight" end
        if IsShiftDown() and actions and actions.shiftRight then return "shiftRight" end
        if IsCtrlDown() and actions and actions.ctrlRight then return "ctrlRight" end
        return "right"
    elseif button == "MiddleButton" then
        return "middle"
    end
    return nil
end

local function ActionHostAttrName(def, name)
    return (def.prefix or "") .. name .. def.suffix
end

local function ActionHostClearKey(host, def)
    if not host or not def or not host.SetAttribute then return end
    local attrs = host.gui2ActionHostAttrs or ACTION_HOST_ATTRS
    for _, attr in ipairs(attrs) do
        host:SetAttribute(ActionHostAttrName(def, attr), nil)
    end
end

local function ActionHostClearRawAttributes(host)
    if not host or not host.gui2ActionHostRawAttributes then return end
    for attr in pairs(host.gui2ActionHostRawAttributes) do
        host:SetAttribute(attr, nil)
    end
    host.gui2ActionHostRawAttributes = nil
end

local function ActionHostSetRawAttribute(host, attr, value)
    if not host or not attr then return end
    host:SetAttribute(attr, value)
    host.gui2ActionHostRawAttributes = host.gui2ActionHostRawAttributes or {}
    host.gui2ActionHostRawAttributes[attr] = true
end

local function ActionHostApplyAttributes(host, def, action)
    local attrs = action.attributes or action.attrs
    if attrs then
        for attr, value in pairs(attrs) do
            host:SetAttribute(ActionHostAttrName(def, attr), value)
        end
    end

    local rawAttrs = action.rawAttributes or action.rawAttrs
    if rawAttrs then
        for attr, value in pairs(rawAttrs) do
            ActionHostSetRawAttribute(host, attr, value)
        end
    end
end

local function ActionHostApplyNoop(host, def)
    ActionHostClearKey(host, def)
    host:SetAttribute(ActionHostAttrName(def, "type"), host.gui2ActionHostNoopValue or ACTION_HOST_NOOP)
end

local function ActionHostApplySecure(host, def, action)
    ActionHostClearKey(host, def)
    if action.kind == "macro" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "macro")
        host:SetAttribute(ActionHostAttrName(def, "macrotext"), action.macrotext)
    elseif action.kind == "spell" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "spell")
        host:SetAttribute(ActionHostAttrName(def, "spell"), action.spell or action.spellID or action.name)
    elseif action.kind == "item" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "item")
        host:SetAttribute(ActionHostAttrName(def, "item"), action.item or action.itemID)
    elseif action.kind == "toy" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "toy")
        host:SetAttribute(ActionHostAttrName(def, "toy"), action.toy or action.toyID or action.itemID or action.id)
    elseif action.kind == "click" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "click")
        host:SetAttribute(ActionHostAttrName(def, "clickbutton"), action.clickbutton or action.clickButton or action.button)
    elseif action.kind == "target" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "target")
        host:SetAttribute(ActionHostAttrName(def, "target"), action.target or "player")
    elseif action.kind == "raidtarget" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "raidtarget")
        host:SetAttribute(ActionHostAttrName(def, "marker"), action.marker)
        host:SetAttribute(ActionHostAttrName(def, "action"), action.action or "set")
    elseif action.kind == "worldmarker" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "worldmarker")
        host:SetAttribute(ActionHostAttrName(def, "marker"), action.marker)
        host:SetAttribute(ActionHostAttrName(def, "action"), action.action or "set")
    elseif action.kind == "returnhome" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "returnhome")
    elseif action.kind == "teleporthome" then
        host:SetAttribute(ActionHostAttrName(def, "type"), "teleporthome")
    elseif action.kind == "secure" then
        if action.type then
            host:SetAttribute(ActionHostAttrName(def, "type"), action.type)
        end
    end
    ActionHostApplyAttributes(host, def, action)
end

local function ActionHostGetCallback(host, genericKey, ybarKey)
    return host and (host[ybarKey] or host[genericKey])
end

local function SetSurface(frame, surfaceKey)
    if frame.gui2Bg then
        frame.gui2Bg:SetColorTexture(GUI2:GetColor(surfaceKey))
    elseif frame.SetBackdropColor then
        frame:SetBackdropColor(GUI2:GetColor(surfaceKey))
    end
    frame.gui2Surface = surfaceKey
end

local function ApplyVisualState(button, state)
    state = state or "normal"
    button.gui2State = state

    local surface = "color.control.bg"
    local border = "color.border.default"
    local text = "color.text.primary"

    if state == "selected" or state == "active" then
        surface = "color.control.active"
        border = "color.border.accent"
        text = "color.text.accent"
    elseif state == "hover" then
        surface = "color.control.hover"
        border = "color.border.accent"
    elseif state == "queued" then
        surface = "color.control.active"
        border = "color.state.warning"
        text = "color.state.warning"
    elseif state == "disabled" or state == "blocked" then
        surface = "color.control.disabled"
        border = "color.border.subtle"
        text = "color.text.disabled"
    end

    SetSurface(button, surface)
    GUI2:SetBorderColor(button, border)
    if button.text then
        button.text:SetTextColor(GUI2:GetColor(text))
    end
    if button.icon then
        button.icon:SetAlpha(state == "disabled" and 0.35 or 1)
    end
end

local function CreateActionButtonFrame(parent, opts, secure)
    opts = opts or {}
    local blocked = secure and InLockdown()
    local button

    if blocked then
        button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button.gui2SecureCreateBlocked = true
    elseif secure then
        button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    else
        button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    end

    button:SetSize(opts.width or 150, opts.height or 28)
    Secure:RegisterActionClicks(button, { clicks = opts.clicks or "AnyUp", compatActionClicks = false })
    button.gui2Secure = secure and not blocked
    button.gui2Protected = button.gui2Secure
    button.gui2Action = opts.action

    if button.SetBackdrop then
        GUI2:ApplyBackdrop(button, "color.control.bg")
    else
        local bg = button:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(GUI2:GetColor("color.control.bg"))
        button.gui2Bg = bg
    end
    GUI2:CreateBorder(button, "color.border.default")

    local label = GUI2:CreateText(button, opts.text or "安全动作", "font.size.sm", "color.text.primary")
    label:SetPoint("CENTER")
    button.text = label

    button.SetVisualState = function(self, state)
        ApplyVisualState(self, state)
    end
    button:SetScript("OnEnter", function(self)
        if self.gui2State == "disabled" or self.gui2State == "blocked" then return end
        ApplyVisualState(self, "hover")
    end)
    button:SetScript("OnLeave", function(self)
        if self.gui2State == "queued" then
            ApplyVisualState(self, "queued")
        else
            ApplyVisualState(self, "normal")
        end
    end)

    if blocked then
        label:SetText(opts.blockedText or "Queued until combat ends")
        ApplyVisualState(button, "blocked")
    else
        ApplyVisualState(button, opts.state or "normal")
    end

    return button
end

function Secure:IsSecureAction(action)
    return type(action) == "table" and SECURE_KINDS[action.kind] == true
end

function Secure:GetPendingCount()
    return #self.unsafeQueue
end

function Secure:QueueUnsafeUpdate(component, action, reason)
    tinsert(self.unsafeQueue, {
        component = component,
        action = action,
        reason = reason or "combat lockdown",
    })
    if component and component.SetVisualState then
        component:SetVisualState("queued")
    end
    return false, "queued"
end

function Secure:RegisterActionClicks(button, opts)
    if not button or not button.RegisterForClicks then return end
    opts = opts or {}

    local clicks = opts.clicks
    if opts.compatActionClicks ~= false then
        clicks = opts.compatClicks or ACTION_HOST_DEFAULT_CLICKS
    end

    if type(clicks) == "table" then
        button:RegisterForClicks(unpack(clicks))
    elseif clicks then
        button:RegisterForClicks(clicks)
    else
        button:RegisterForClicks(unpack(ACTION_HOST_DEFAULT_CLICKS))
    end
end

function Secure:ShouldRunActionClick(down, opts)
    opts = opts or {}
    local phase = opts.clickPhase or opts.runOn

    if phase == "both" then
        return true
    elseif phase == "down" then
        return down and true or false
    elseif phase == "up" then
        return not down
    end

    local useOnKeyDown = opts.useOnKeyDown
    if useOnKeyDown == nil and GetCVarBool then
        useOnKeyDown = GetCVarBool("ActionButtonUseKeyDown")
    end

    return (down and true or false) == (useOnKeyDown and true or false)
end

function Secure:CreateActionHost(owner, opts)
    if not owner then return nil end
    opts = opts or {}

    local secureHost = opts.secure ~= false
    local inLockdown = opts.inCombat or InLockdown
    if secureHost and inLockdown() then
        return nil, "combat lockdown"
    end

    local host
    if secureHost then
        host = CreateFrame("Button", nil, owner, "SecureActionButtonTemplate")
    elseif GUI2.CreateButtonFrame then
        host = GUI2:CreateButtonFrame(owner)
    else
        host = CreateFrame("Button", nil, owner, "BackdropTemplate")
    end

    host:SetAllPoints(owner)
    if owner.GetFrameLevel then
        host:SetFrameLevel(owner:GetFrameLevel() + (opts.frameLevelOffset or 20))
    end

    self:RegisterActionClicks(host, opts)
    if host.SetAttribute then
        host:SetAttribute("useOnKeyDown", opts.useOnKeyDown)
    end

    host.owner = owner
    host.gui2Owner = opts.owner or owner
    host.gui2SecureHost = secureHost
    host.gui2ActionHostOnEnter = opts.onEnter
    host.gui2ActionHostOnLeave = opts.onLeave
    host.gui2ActionHostAfterClick = opts.afterClick
    host.gui2ActionClickOpts = opts
    host.gui2ActionHostKeys = opts.actionKeys or ACTION_HOST_KEYS
    host.gui2ActionHostKeyOrder = opts.actionKeyOrder or ACTION_HOST_KEY_ORDER
    host.gui2ActionHostSecureKinds = opts.secureKinds or SECURE_KINDS
    host.gui2ActionHostAttrs = opts.actionAttrs or ACTION_HOST_ATTRS
    host.gui2ActionHostNoopValue = opts.noopValue or ACTION_HOST_NOOP
    host.gui2ActionHostGetClickKey = opts.getClickKey or DefaultGetClickKey

    host.SetActions = function(self, actions)
        actions = actions or {}
        local locked = self.gui2SecureHost and inLockdown()
        if locked then
            self.gui2PendingActions = actions
            self.ybarPendingActions = actions
            return false, "combat lockdown"
        end

        self.gui2Actions = actions
        self.ybarActions = actions
        self.gui2CustomActions = {}
        self.ybarCustomActions = self.gui2CustomActions
        self.gui2PendingActions = nil
        self.ybarPendingActions = nil
        if self.SetAttribute then
            self:SetAttribute("useOnKeyDown", opts.useOnKeyDown)
        end
        ActionHostClearRawAttributes(self)

        for _, key in ipairs(self.gui2ActionHostKeyOrder or ACTION_HOST_KEY_ORDER) do
            local def = self.gui2ActionHostKeys[key]
            ActionHostClearKey(self, def)
        end

        for key, action in pairs(actions) do
            local def = self.gui2ActionHostKeys[key]
            if def and type(action) == "table" then
                if action.kind == "custom" then
                    self.gui2CustomActions[key] = action
                    if def.modifier and self.SetAttribute then
                        ActionHostApplyNoop(self, def)
                    end
                elseif action.kind == "noop" then
                    ActionHostApplyNoop(self, def)
                elseif self.gui2ActionHostSecureKinds[action.kind] then
                    ActionHostApplySecure(self, def, action)
                end
            end
        end

        return true
    end

    host.SetActionHostFrameLevel = function(self)
        if self.owner and self.owner.GetFrameLevel then
            self:SetFrameLevel(self.owner:GetFrameLevel() + (opts.frameLevelOffset or 20))
        end
    end

    host:SetScript("OnEnter", function(self)
        local callback = ActionHostGetCallback(self, "gui2ActionHostOnEnter", "ybarOnEnter")
        if callback then
            callback(self, self.owner)
        end
    end)

    host:SetScript("OnLeave", function(self)
        local callback = ActionHostGetCallback(self, "gui2ActionHostOnLeave", "ybarOnLeave")
        if callback then
            callback(self, self.owner)
        end
    end)

    host:SetScript("PreClick", function(self, button, down)
        local actions = self.gui2Actions or self.ybarActions
        local key = self.gui2ActionHostGetClickKey(actions, button)
        self.gui2PendingClickKey = key
        self.ybarPendingClickKey = key

        if not Secure:ShouldRunActionClick(down, self.gui2ActionClickOpts) then
            return
        end

        local action = key and actions and actions[key]
        if action and action.beforeClick then
            action.beforeClick(self, button, self.owner, action, down)
        end
    end)

    host:SetScript("PostClick", function(self, button, down)
        local actions = self.gui2Actions or self.ybarActions
        local key = self.gui2PendingClickKey or self.ybarPendingClickKey or self.gui2ActionHostGetClickKey(actions, button)
        self.gui2PendingClickKey = nil
        self.ybarPendingClickKey = nil

        if not Secure:ShouldRunActionClick(down, self.gui2ActionClickOpts) then
            return
        end

        local action = key and self.gui2CustomActions and self.gui2CustomActions[key]
        if action and action.onClick then
            action.onClick(self, button, self.owner, action, down)
        end

        local secureAction = key and actions and actions[key]
        if secureAction and secureAction.afterClick then
            secureAction.afterClick(self, button, self.owner, secureAction, down)
        end

        local afterClick = ActionHostGetCallback(self, "gui2ActionHostAfterClick", "ybarAfterClick")
        if afterClick then
            afterClick(self, button, self.owner, action or secureAction, down)
        end
    end)

    owner.actionHost = host
    return host
end

local function ClearAttributes(button)
    if not button or not button.SetAttribute then return end
    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("macrotext1", nil)
    button:SetAttribute("clickbutton", nil)
    button:SetAttribute("target", nil)
end

local function ApplyActionAttributes(button, action)
    if not button or not action then return false end
    if not button.SetAttribute then return false end

    ClearAttributes(button)

    if action.kind == "spell" then
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell1", action.spell or action.spellID or action.name or 6603)
    elseif action.kind == "item" then
        button:SetAttribute("type1", "item")
        button:SetAttribute("item1", action.item or action.itemID or "item:6948")
    elseif action.kind == "macro" then
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", action.macrotext or "/run print('YUI GUI2 macro')")
    elseif action.kind == "click" then
        button:SetAttribute("type1", "click")
        button:SetAttribute("clickbutton", action.clickButton)
    elseif action.kind == "target" then
        button:SetAttribute("type1", "target")
        button:SetAttribute("target", action.target or "player")
    end

    return true
end

function Secure:ApplyAction(button, action)
    action = action or { kind = "custom" }
    button.gui2Action = action

    if action.kind == "custom" then
        ClearAttributes(button)
        button:SetScript("OnClick", action.onClick)
        if button.SetVisualState then
            button:SetVisualState("normal")
        end
        return true
    end

    if InLockdown() then
        return self:QueueUnsafeUpdate(button, action)
    end

    button:SetScript("OnClick", nil)
    local ok = ApplyActionAttributes(button, action)
    if ok and button.SetVisualState then
        button:SetVisualState("normal")
    end
    return ok
end

function Secure:FlushUnsafeQueue()
    if InLockdown() then return false end
    for _, item in ipairs(self.unsafeQueue) do
        if item.component and item.action and not item.component.gui2SecureCreateBlocked then
            self:ApplyAction(item.component, item.action)
        end
    end
    wipe(self.unsafeQueue)
    if self.queueLabel then
        self.queueLabel:SetText("待处理更新：0")
    end
    return true
end

function Secure:CreateSecureActionButton(parent, opts)
    opts = opts or {}
    local action = opts.action or { kind = "macro", macrotext = "/run print('YUI GUI2')" }
    local secure = self:IsSecureAction(action)
    local button = CreateActionButtonFrame(parent, opts, secure)
    button.gui2Component = "SecureActionButton"
    button.SetAction = function(self, nextAction)
        return Secure:ApplyAction(self, nextAction)
    end
    button:SetAction(action)
    return button
end

function Secure:CreateSecureIconAction(parent, opts)
    opts = opts or {}
    opts.width = opts.width or 180
    opts.height = opts.height or 36
    local button = self:CreateSecureActionButton(parent, opts)
    button.gui2Component = "SecureIconAction"

    local iconSize = opts.iconSize or 22
    local icon = GUI2:CreateIcon(button, {
        icon = opts.icon,
        size = iconSize,
    })
    icon:SetPoint("LEFT", 6, 0)
    button.icon = icon

    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    button.text:SetPoint("RIGHT", -8, 0)
    button.text:SetJustifyH("LEFT")
    return button
end

function Secure:CreateSecureMenuItem(parent, opts)
    opts = opts or {}
    opts.width = opts.width or 220
    opts.height = opts.height or 28
    local button = self:CreateSecureIconAction(parent, opts)
    button.gui2Component = "SecureMenuItem"
    return button
end

function Secure:CreateSecureActionList(parent, opts)
    opts = opts or {}
    local items = opts.items or {}
    local rowHeight = opts.rowHeight or 34
    local width = opts.width or 260
    local height = opts.height or ((#items * rowHeight) + 16)
    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    frame.gui2Component = "SecureActionList"
    frame.items = {}

    for i, item in ipairs(items) do
        local button = self:CreateSecureMenuItem(frame, {
            width = width - 16,
            height = rowHeight - 6,
            text = item.text,
            icon = item.icon,
            iconSize = item.iconSize or opts.iconSize or 20,
            action = item.action,
        })
        button:SetPoint("TOPLEFT", 8, -8 - ((i - 1) * rowHeight))
        frame.items[i] = button
    end
    return frame
end

local function CreateSection(parent, title, x, y, width, height)
    local panel = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    panel:SetPoint("TOPLEFT", x, y)
    local label = GUI2:CreateText(panel, title, "font.size.lg", "color.text.heading")
    label:SetPoint("TOPLEFT", 12, -10)
    return panel
end

function Secure:RenderLab(parent, lab)
    local width = parent:GetWidth() > 100 and parent:GetWidth() or 920
    lab:RenderHeader(parent, "安全组件（Secure）", "用于安全动作和战斗限制相关交互，重点区分真实安全属性、普通回调和战斗中延后队列。")
    lab:RenderComponentList(parent, "组件清单（Component List）", {
        "安全动作按钮（SecureActionButton）", "安全图标动作（SecureIconAction）",
        "安全菜单项（SecureMenuItem）", "安全动作列表（SecureActionList）",
        "延后队列（UnsafeQueue）", "战斗状态（CombatLockdown）",
    })

    local kinds = CreateSection(parent, "动作类型（Action Kinds）", 18, -88, width - 36, 140)
    local clickTarget
    if not InLockdown() then
        clickTarget = CreateFrame("Button", nil, kinds, "SecureActionButtonTemplate")
        clickTarget:SetSize(1, 1)
        clickTarget:SetPoint("BOTTOMRIGHT", kinds, "BOTTOMRIGHT", -1, 1)
        clickTarget.gui2Protected = true
        clickTarget:SetAttribute("type1", "macro")
        clickTarget:SetAttribute("macrotext1", "/run print('YUI GUI2 click target')")
    end

    local samples = {
        { text = "法术", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", action = { kind = "spell", spellID = 6603 } },
        { text = "物品", icon = "Interface\\Icons\\INV_Misc_Rune_01", action = { kind = "item", item = "item:6948" } },
        { text = "宏命令", icon = "Interface\\Icons\\INV_Misc_Note_01", action = { kind = "macro", macrotext = "/run print('YUI GUI2 macro')" } },
        { text = "点击代理", icon = "Interface\\Icons\\Ability_Marksmanship", action = { kind = "click", clickButton = clickTarget } },
        { text = "目标", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", action = { kind = "target", target = "player" } },
        { text = "普通回调", icon = "Interface\\Icons\\INV_Misc_Gear_01", action = { kind = "custom", onClick = function() if YUI.Print then YUI:Print("GUI2 custom action") end end } },
    }

    for i, sample in ipairs(samples) do
        local button = self:CreateSecureIconAction(kinds, {
            width = 130,
            text = sample.text,
            icon = sample.icon,
            action = sample.action,
        })
        button:SetPoint("TOPLEFT", 14 + (((i - 1) % 3) * 142), -44 - (math.floor((i - 1) / 3) * 42))
    end

    local listPanel = CreateSection(parent, "动作列表（SecureActionList）", 18, -246, 410, 240)
    local list = self:CreateSecureActionList(listPanel, {
        width = 372,
        rowHeight = 30,
        items = {
            { text = "安全法术项", icon = "Interface\\Icons\\Spell_Holy_FlashHeal", action = { kind = "spell", spellID = 6603 } },
            { text = "安全宏命令项", icon = "Interface\\Icons\\INV_Misc_Note_01", action = { kind = "macro", macrotext = "/run print('YUI GUI2 secure macro')" } },
            { text = "普通回调项", icon = "Interface\\Icons\\INV_Misc_Gear_01", action = { kind = "custom", onClick = function() if YUI.Print then YUI:Print("GUI2 custom menu item") end end } },
            { text = "目标玩家项", icon = "Interface\\Icons\\Ability_Hunter_MarkedForDeath", action = { kind = "target", target = "player" } },
        },
    })
    list:SetPoint("TOPLEFT", 14, -34)

    local rules = CreateSection(parent, "战斗更新规则（Combat Rules）", 446, -246, width - 464, 240)
    local combatText = GUI2:CreateText(rules, "战斗锁定：" .. (InLockdown() and "是" or "否"), "font.size.md", InLockdown() and "color.state.warning" or "color.state.success")
    combatText:SetPoint("TOPLEFT", 14, -44)

    local visual = self:CreateSecureActionButton(rules, {
        width = 180,
        text = "仅视觉更新",
        action = { kind = "macro", macrotext = "/run print('visual sample')" },
    })
    visual:SetPoint("TOPLEFT", rules, "TOPLEFT", 14, -72)

    local queueButton = GUI2.Form:CreateButton(rules, {
        width = 180,
        text = "模拟延后队列",
        onClick = function()
            Secure:QueueUnsafeUpdate(visual, { kind = "macro", macrotext = "/run print('queued GUI2 update')" }, "Lab simulation")
            if Secure.queueLabel then
                Secure.queueLabel:SetText("待处理更新：" .. Secure:GetPendingCount())
            end
        end,
    })
    queueButton:SetPoint("TOPLEFT", rules, "TOPLEFT", 14, -118)

    local visualButton = GUI2.Form:CreateButton(rules, {
        width = 180,
        text = "切换视觉状态",
        onClick = function()
            if visual.gui2State == "selected" then
                visual:SetVisualState("normal")
            else
                visual:SetVisualState("selected")
            end
        end,
    })
    visualButton:SetPoint("TOPLEFT", rules, "TOPLEFT", 206, -118)

    local queueLabel = GUI2:CreateText(rules, "待处理更新：" .. self:GetPendingCount(), "font.size.sm", "color.text.secondary")
    queueLabel:SetPoint("TOPLEFT", rules, "TOPLEFT", 14, -144)
    self.queueLabel = queueLabel

    local note = GUI2:CreateText(rules, "战斗中结构性安全属性会延后；颜色、高亮、冷却和数量属于视觉更新。", "font.size.sm", "color.text.secondary")
    note:SetPoint("TOPLEFT", rules, "TOPLEFT", 14, -162)
    note:SetWidth(width - 500)
    note:SetWordWrap(true)
end

if YUI.Event then
    YUI.Event:On("PLAYER_REGEN_ENABLED", "FlushUnsafeQueue", Secure)
end
