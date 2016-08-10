LibS2kMisc
==========

Synopsis:
---------
    -- table extensions

    if table.s2k_is_empty(tab) then
        -- do something
    end

    for i = 1, table.s2k_len(tab) do
        -- do something
    end

    local item_1, item_3, item_7 = table.s2k_select(tab, 1, 3, 7)

    for key, item_1, item_2, item_3 in table.s2k_pairs(tab, true) do
        -- do something
    end

    for item_1, item_2, item_3 in table.s2k_values(tab, true) do
        -- do something
    end

    -- in-game functions

    type, ... = UnitInfoFromGuid(guid)

    text = C_PetJournal.GetSearchFilter()
