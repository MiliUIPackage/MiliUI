HandyNotes_Draenor = LibStub("AceAddon-3.0"):GetAddon("HandyNotes_Draenor")

if (UnitFactionGroup("player") == "Alliance") then
    HandyNotes_Draenor.nodes[582] = {
        [49604380] = { 582, "35530", "Lunarfall Egg", "On a wagon", HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil },
        [42405436] = { 582, "35381", "Pippers' Buried Supplies 1", nil, HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil },
        [50704850] = { 582, "35382", "Pippers' Buried Supplies 2", nil, HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil },
        [30802830] = { 582, "35383", "Pippers' Buried Supplies 3", nil, HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil },
        [49197683] = { 582, "35384", "Pippers' Buried Supplies 4", nil, HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil },
        [51800110] = { 582, "35289", "Spark's Stolen Supplies", "In a cave in the lake", HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil }
    }
else
    HandyNotes_Draenor.nodes[590] = {
        [74505620] = { 590, "34937", "Biolante", "Lady Sena's Other Materials Stash", HandyNotes_Draenor.DefaultIcons.Icon_Treasure_Default, HandyNotes_Draenor.DefaultNodeTypes.Treasure, nil }
    }
end