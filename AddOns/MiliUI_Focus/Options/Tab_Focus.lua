------------------------------------------------------------
-- 「焦點」分頁：Shift+點擊、自訂快捷鍵、自動團隊標記
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local Specs = ns.Specs

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

local function Apply()
    local f = ns.db.focus
    -- 保險：標記編號被弄成 0 的話補一個（DB.Init 已經擋過一次，這裡是第二道）
    if (f.markIndex or 0) < 1 then f.markIndex = ns.DB.RandomMarkIndex() end
    ns.Focuser.Apply()
    RefreshAll()
end

------------------------------------------------------------
-- 快捷鍵擷取列（共用層沒有這種控件，走 custom）
------------------------------------------------------------
local function BuildHotkeyRow(parent, x, y, width)
    local capturing = false
    local btn = W.CreateButton(parent, "", "normal", 150, 22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)
    btn:RegisterForClicks("AnyUp")   -- 中鍵 / 側鍵也要能綁

    local clearBtn = W.CreateButton(parent, L["Clear"], "normal", 60, 22)
    clearBtn:SetPoint("LEFT", btn, "RIGHT", 6, 0)

    local desc = parent:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(width)
    desc:SetJustifyH("LEFT")

    local function HotkeyText()
        local key = ns.db.focus.hotkey
        if not key or key == "" then return "|cff808080" .. L["Not set"] .. "|r" end
        return (GetBindingText and GetBindingText(key)) or key
    end

    local function Refresh()
        btn:SetText(capturing and ("|cffffe00a" .. L["Press a key..."] .. "|r") or HotkeyText())
        local base = L["Click the button, then press the key you want. Modifiers optional. Esc cancels, Backspace clears."]
        if capturing then
            base = "|cffffe00a" .. L["Press a key..."] .. "|r "
                .. L["Esc cancels, Backspace clears."]
        end
        local key = ns.db.focus.hotkey
        if key and key ~= "" then
            -- 覆寫綁定優先權高於一般綁定，所以原本的功能會被蓋掉，先講清楚
            local action = GetBindingAction and GetBindingAction(key)
            if action and action ~= "" then
                local name = (GetBindingName and GetBindingName(action)) or action
                base = base .. "\n|cffff9900"
                    .. L["This key is currently bound to \"%s\" and will be overridden."]:format(name)
                    .. "|r"
            end
        end
        desc:SetText(base)
    end

    local function StopCapture()
        if not capturing then return end
        capturing = false
        btn:EnableKeyboard(false)
        btn:SetPropagateKeyboardInput(true)
        Refresh()
    end

    local function StartCapture()
        if capturing then return end
        capturing = true
        btn:EnableKeyboard(true)
        btn:SetPropagateKeyboardInput(false)
        Refresh()
    end

    local function Save(key)
        StopCapture()
        if key == "" then key = nil end
        ns.db.focus.hotkey = key
        ns.Focuser.Apply()
        Refresh()
        if key then
            ns.Print(L["Focus hotkey:"], (GetBindingText and GetBindingText(key)) or key)
        else
            ns.Print(L["Focus hotkey:"], L["cleared"])
        end
    end

    btn:SetScript("OnClick", function(_, button)
        if not capturing then
            if button == "LeftButton" then StartCapture() end
            return
        end
        if button == "LeftButton" or button == "RightButton" then
            StopCapture()   -- 再點一次 = 放棄擷取
            return
        end
        local key = Specs.HOTKEY_MOUSE[button]
        if key then Save(Specs.BuildHotkeyString(key)) end
    end)
    btn:SetScript("OnKeyDown", function(_, key)
        if not capturing then return end
        if key == "ESCAPE" then StopCapture() return end
        if key == "BACKSPACE" or key == "DELETE" then Save(nil) return end
        if Specs.HOTKEY_MODIFIER_ONLY[key] then return end
        Save(Specs.BuildHotkeyString(key))
    end)
    btn:HookScript("OnHide", StopCapture)
    clearBtn:SetScript("OnClick", function() Save(nil) end)

    return 62, Refresh
end

local CONTROLS = {
    { type = "header", label = L["Set focus"] },
    { type = "toggle", key = "enabled", label = L["Shift + click sets focus"] },
    { type = "text",   label = L["Shift + left click on any unit frame or nameplate sets it as your focus target."] },
    { type = "custom", label = L["Extra hotkey"], build = BuildHotkeyRow },

    { type = "header", label = L["Auto raid marker"] },
    { type = "toggle", key = "autoMark", label = L["Mark the focus automatically"] },
    { type = "text",   label = L["When the focus changes, put the chosen raid marker on it. Needs lead or assist in a group (not needed on world mobs)."] },
    { type = "dropdown", key = "markIndex", label = L["Marker icon"], items = function() return Specs.MarkItems() end },
    { type = "toggle", key = "noOverwriteMark", label = L["Don't overwrite existing markers"] },
    { type = "text",   label = L["Leave the target alone if it already carries any raid marker (for example a skull the leader placed). Turn this off to always force your own icon."] },
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Focus"])
    local ctx = ns.Controls.MakeCtx(function() return ns.db.focus end, Apply)
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "focusTab", function(id)
    if id ~= "focus" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)

-- 標記切換列在遊戲中換了圖示 → 設定頁開著的話跟著更新
ns.RegisterCallback("SettingsChanged", "focusTab", function()
    if tab and tab:IsShown() then RefreshAll() end
end)
