do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
local GUI = YUI.GUI2
local Tooltip = {}
GUI.Tooltip = Tooltip

local function T(key, fallback)
    local locale = YUI.Locale and YUI.Locale:Get("Core")
    local value = locale and locale[key]
    return value and value ~= key and value or fallback or key
end

local function Color(tone)
    return GUI:GetColor("color.tooltip." .. (tone or "body"))
end

local function Colored(text, tone)
    local r, g, b = Color(tone)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r*255+.5), math.floor(g*255+.5), math.floor(b*255+.5), text)
end

function Tooltip:ColorText(text, tone)
    return Colored(text, tone)
end

function Tooltip:IconText(text, icon)
    if not icon then return text end
    local size = GUI:GetToken("tooltip.icon.size") or 12
    local atlas = type(icon) == "string" and icon:match("^atlas:(.+)$")
    if atlas then return string.format("|A:%s:%d:%d|a %s", atlas, size, size, text) end
    return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s", icon, size, size, text)
end

local buttons = {LeftButton="left", RightButton="right", MiddleButton="middle"}
local modifiers = {ALT="Alt", CTRL="Ctrl", SHIFT="Shift"}
-- 仅格式化文案；不持有 owner、不绑定按键或改变当前 Tooltip。
function Tooltip:FormatAction(spec, settings)
    local parts = {}
    for _, modifier in ipairs(spec.modifiers or {}) do parts[#parts+1] = modifiers[modifier] or modifier end
    if spec.key then
        parts[#parts+1] = modifiers[spec.key] or spec.key
    else
        local key = "tooltip.button." .. (buttons[spec.button or "LeftButton"] or "left")
        parts[#parts+1] = T(key)
    end
    local text = spec.text or (settings and T("tooltip.open_settings")) or ""
    local keys = table.concat(parts, " + ")
    if spec.key and spec.keyAction == "hold" then
        keys = string.format(T("tooltip.key.hold", "Hold %s"), keys)
    elseif spec.key and spec.keyAction == "release" then
        keys = string.format(T("tooltip.key.release", "Release %s"), keys)
    end
    local keyTone = spec.keyTone or (settings and "settings" or "body")
    local textTone = spec.textTone or (settings and "settings" or "action")
    -- 分隔符也跟随按键颜色；嵌套动作染色不依赖 AddLine 的默认颜色。
    return Colored(string.format(T("tooltip.action_format", "%s: %s"), keys, Colored(text, textTone)), keyTone)
end

local function Clear()
    Tooltip.owner, Tooltip.spec = nil, nil
end

function Tooltip:Hide(owner)
    if self.owner ~= owner then return end
    if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
    Clear()
end

local function OwnerHidden(owner) Tooltip:Hide(owner) end

function Tooltip:Show(owner, spec)
    local tip = GameTooltip
    if not owner or not tip or not spec then return end
    if tip.HookScript and not self.hooked then tip:HookScript("OnHide", Clear); self.hooked = true end
    if owner.HookScript and not owner.gui2TooltipOwnerHooked then
        owner:HookScript("OnHide", OwnerHidden)
        owner.gui2TooltipOwnerHooked = true
    end
    tip:SetOwner(owner, spec.anchor or "ANCHOR_RIGHT")
    self.owner, self.spec = owner, spec
    local title = type(spec.title) == "table" and spec.title or {text=spec.title or ""}
    local heading = self:IconText(title.text or "", title.icon)
    if spec.subtitle then
        tip:ClearLines()
        local subtitle = type(spec.subtitle) == "table" and spec.subtitle or {text=spec.subtitle}
        local r,g,b = Color("heading")
        tip:AddDoubleLine(heading, subtitle.text or "", r,g,b,r,g,b)
    else
        local r,g,b = Color("heading")
        tip:SetText(heading,r,g,b)
    end
    -- 标题下方始终留一行空白，包括无正文的提示。
    tip:AddLine(" ")
    local count = 0
    local body = {}
    function body:AddLine(text, tone, icon)
        if not text or text == "" then return end
        local r,g,b = Color(tone)
        tip:AddLine(Tooltip:IconText(text,icon),r,g,b,true)
        count = count + 1
    end
    function body:AddDoubleLine(left,right,leftTone,rightTone)
        local r,g,b = Color(leftTone)
        local rr,rg,rb = Color(rightTone or leftTone)
        -- 原生双列行用左侧文字撑开高度；右列续行也保留一个空格。
        tip:AddDoubleLine(left and left ~= "" and left or " ",right or "",r,g,b,rr,rg,rb)
        count = count + 1
    end
    function body:AddSpace() tip:AddLine(" ") end
    if spec.content then
        local ok, message = pcall(spec.content, body)
        if not ok then self:Hide(owner); error(message, 0) end
    end
    local actions = spec.actions or {}
    if count > 0 and (#actions > 0 or spec.settings or spec.footer) then tip:AddLine(" ") end
    for _, action in ipairs(actions) do body:AddLine(self:FormatAction(action),"action") end
    if spec.settings then body:AddLine(self:FormatAction(spec.settings,true),"settings") end
    if spec.footer then
        local footer = type(spec.footer) == "table" and spec.footer or {text=spec.footer}
        body:AddLine(footer.text,footer.tone or "secondary",footer.icon)
    end
    tip:Show()
end

function Tooltip:Refresh(owner)
    if self.owner == owner and self.spec and GameTooltip and GameTooltip:IsOwned(owner) then
        self:Show(owner,self.spec)
    end
end
