
--LootFinder:AddResult()
function LF:Search()
    self.results = {}
    EJ_SetDifficulty(self.raid_difficult)

    EJ_SetLootFilter(self.class,self.spec)
    --C_EncounterJournal.SetSlotFilter(self.slot)

    self:MPlusSearch()
    self:RaidSearch()
    self:PvPSearch()
end

local statTable = {}
function LF:AddResult(source, name, boss, itemlink)
    local icon = select(5, GetItemInfoInstant(itemlink))

    table.wipe(statTable)
    GetItemStats(itemlink, statTable)

    self.results[#self.results+1] = {
        source = source,
        name = name,
        boss = boss,
        itemlink = itemlink,
        icon = icon,
        mainstat = statTable.ITEM_MOD_STRENGTH_SHORT or statTable.ITEM_MOD_AGILITY_SHORT or statTable.ITEM_MOD_INTELLECT_SHORT or 0,
        crit = statTable.ITEM_MOD_CRIT_RATING_SHORT or 0,
        haste = statTable.ITEM_MOD_HASTE_RATING_SHORT or 0,
        mastery = statTable.ITEM_MOD_MASTERY_RATING_SHORT or 0,
        versality = statTable.ITEM_MOD_VERSATILITY or 0
    }
end
