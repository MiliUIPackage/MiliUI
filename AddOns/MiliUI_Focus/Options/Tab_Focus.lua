------------------------------------------------------------
-- 「專注目標」分頁：Shift+點擊、自訂快捷鍵、自動團隊標記
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
--
-- ⚠ 鍵盤獨佔一律用「顯示／隱藏一個專用覆蓋層」做，**不要**在按鈕上開關
--   EnableKeyboard / SetPropagateKeyboardInput：
--   * 快捷鍵綁定是掛在最底層的 WorldFrame 上，所以只要有**任何一個**
--     鍵盤啟用又不轉發的框顯示著，全遊戲的快捷鍵（含 ESC）就通通不會觸發。
--     擷取狀態一旦卡住（點了按鈕又跑去點別的地方、或還原那一步失敗），
--     症狀是「設定視窗按 ESC 關不掉、整頁鍵盤沒反應」，完全指不到這一列。
--   * SetPropagateKeyboardInput 從 10.1.5 起在戰鬥中是受限函式，還原那一步
--     有機會直接失敗 —— 換成 Show/Hide 就沒有這個問題：隱藏自己的普通框
--     永遠合法，而文件寫的是「**顯示中**才會擋掉綁定」。
--   結果就是執行期完全不碰那兩支 API，卡不住。
------------------------------------------------------------
local function BuildHotkeyRow(parent, x, y, width)
    local btn = W.CreateButton(parent, "", "normal", 150, 22)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)

    local clearBtn = W.CreateButton(parent, L["Clear"], "normal", 60, 22)
    clearBtn:SetPoint("LEFT", btn, "RIGHT", 6, 0)

    local desc = parent:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontSmall)
    desc:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(width)
    desc:SetJustifyH("LEFT")

    -- 擷取覆蓋層：蓋滿畫面、吃滑鼠也吃鍵盤。蓋滿是刻意的——擷取中點畫面任何
    -- 地方都代表放棄，不會有「以為離開了其實還按著」的中間狀態。
    local capture = CreateFrame("Frame", nil, UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetAllPoints(UIParent)
    capture:EnableMouse(true)
    capture:EnableKeyboard(true)
    capture:Hide()
    local dim = capture:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.25)   -- 淡淡壓一層，讓人知道現在是等按鍵的狀態

    local Refresh, Save

    local function StopCapture()
        capture:Hide()
        Refresh()
    end

    local function StartCapture()
        if capture:IsShown() then return end
        if InCombatLockdown() then
            ns.Print(L["Can't change settings during combat"])
            return
        end
        capture:Show()
        Refresh()
    end

    capture:SetScript("OnShow", function(self)
        -- 只在這裡設一次，而且擋掉戰鬥（10.1.5 起受限）。設不到最多是按到的鍵
        -- 同時觸發原本的綁定，不會卡死鍵盤。
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(false) end
    end)
    capture:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then StopCapture() return end
        if key == "BACKSPACE" or key == "DELETE" then Save(nil) return end
        if Specs.HOTKEY_MODIFIER_ONLY[key] then return end
        Save(Specs.BuildHotkeyString(key))
    end)
    capture:SetScript("OnMouseDown", function(_, mouseButton)
        -- 中鍵／側鍵可以當快捷鍵，左右鍵留給「放棄」
        local key = Specs.HOTKEY_MOUSE[mouseButton]
        if key then Save(Specs.BuildHotkeyString(key)) else StopCapture() end
    end)
    -- 進戰鬥就收掉：戰鬥中還原不了轉發設定，先把框藏起來（隱藏永遠合法）
    capture:RegisterEvent("PLAYER_REGEN_DISABLED")
    capture:SetScript("OnEvent", StopCapture)

    local function HotkeyText()
        local key = ns.db.focus.hotkey
        if not key or key == "" then return "|cff808080" .. L["Not set"] .. "|r" end
        return (GetBindingText and GetBindingText(key)) or key
    end

    function Refresh()
        local capturing = capture:IsShown()
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

    function Save(key)
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

    btn:SetScript("OnClick", function() StartCapture() end)
    -- 分頁切走／視窗關掉都要收：覆蓋層掛在 UIParent 上，不會跟著一起消失
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
