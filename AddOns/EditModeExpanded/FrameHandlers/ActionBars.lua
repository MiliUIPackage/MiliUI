local addonName, addon = ...

local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

function addon:initActionBars()
    local db = addon.db.global
    if not db.EMEOptions.actionBars then return end
    C_Timer.After(5, function()
        if InCombatLockdown() then return end 
        local bars = {MainMenuBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft, MultiBar5, MultiBar6, MultiBar7}

        for _, bar in ipairs(bars) do
            
            --[[
            -- setting.buttonPadding causes taint to spread and cause issues
            -- another method needed, if its even possible
            lib:RegisterCustomCheckbox(bar, "間距為零", 
                -- on checked
                function()
                    bar.minButtonPadding = 0
                    bar.buttonPadding = 0
                    bar:UpdateGridLayout()
                end,
                
                -- on unchecked
                function()
                    bar.minButtonPadding = 2
                    bar.buttonPadding = 2
                    bar:UpdateGridLayout()
                end,
                
                "OverrideIconPadding"
            )
            --]]
            
            addon:registerSecureFrameHideable(bar)
            
            local alreadyHidden
            lib:RegisterCustomCheckbox(bar, "隱藏巨集/按鍵名稱",
                function()
                    for _, button in pairs(bar.actionButtons) do
                        button.Name:Hide()
                        button.HotKey:Hide()
                    end
                    alreadyHidden = true
                end,
                function()
                    if not alreadyHidden then return end
                    for _, button in pairs(bar.actionButtons) do
                        button.Name:Show()
                        button.HotKey:Show()
                    end
                    alreadyHidden = false
                end,
                "HideMacroName"
            )
        end
    end)
end
