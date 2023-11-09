local addonName, addon = ...

local lib = LibStub:GetLibrary("EditModeExpanded-1.0")

local alreadyLoaded

function addon:initBelowMinimapContainer()
    if alreadyLoaded then return end
    local db = addon.db.global
    if db.EMEOptions.UIWidgetBelowMinimapContainerFrame then
        if UIWidgetBelowMinimapContainerFrame then
            alreadyLoaded = true
            UIWidgetBelowMinimapContainerFrame:SetParent(UIParent)
            lib:RegisterFrame(UIWidgetBelowMinimapContainerFrame, "PvP 任務目標", db.UIWidgetBelowMinimapContainerFrame)
            ArenaEnemyFramesContainer:SetParent(UIParent)
            lib:RegisterFrame(ArenaEnemyFramesContainer, "戰場目標", db.ArenaEnemyFramesContainer)
        end
    end
end
