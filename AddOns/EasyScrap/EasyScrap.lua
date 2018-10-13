--Easy Scrapper by Motig
LoadAddOn("Blizzard_ScrappingMachineUI")
ScrappingMachineFrame.ScrapButton.SetEnabledBackup = ScrappingMachineFrame.ScrapButton.SetEnabled --To prevent button mashers from scrapping while adding items

EasyScrap = {}
EasyScrap.addonVersion = 13
EasyScrap.saveData = {}

EasyScrap.itemCache = {}
EasyScrap.scrappableItems = {}
EasyScrap.eligibleItems = {}
EasyScrap.ignoredItems = {}
EasyScrap.filteredItems = {}
EasyScrap.queueItems = {}
EasyScrap.itemsInScrapper = {}
EasyScrap.failedItems = {}
EasyScrap.queueItemsToAdd = 0
EasyScrap.scrapInProgress = false
EasyScrap.itemIgnoreList = {}
EasyScrap.mouseInItem = false
EasyScrap.activeFilterID = 0

EasyScrap.defaultSettings = {}
EasyScrap.defaultSettings.defaultFilter = 0

EasyScrap.defaultFilter = {}
EasyScrap.defaultFilter.name = '預設'
EasyScrap.defaultFilter.rules = {{["filterType"] = "equipmentSet",}}

function EasyScrap:initializeSaveData()
    self.saveData = {}
    self.saveData.addonSettings = EasyScrap.defaultSettings
    self.saveData.showWhatsNew = nil
    self.saveData.customFilters = {}
    --self.saveData.addonVersion = EasyScrap.addonVersion
end

function EasyScrap:updateAddonSettings()
    for k,v in pairs(EasyScrap.defaultSettings) do
        if self.saveData.addonSettings[k] == nil then self.saveData.addonSettings[k] = v end
    end
end

BINDING_HEADER_EASYSCRAPHEAD = "快易銷毀"
_G["BINDING_NAME_CLICK EasyScrap_ScrapKeybindFrame:LeftButton"] = "銷毀物品"

local keybindFrame = CreateFrame('Button', 'EasyScrap_ScrapKeybindFrame', nil, 'SecureActionButtonTemplate')
keybindFrame:SetAttribute('type', 'click')
keybindFrame:SetAttribute('clickbutton', ScrappingMachineFrame.ScrapButton)

--Interface\HelpFrame\HelpIcon-ReportAbuse
















