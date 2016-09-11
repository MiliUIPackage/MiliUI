local myname, ns = ...

ns.points = {
    --[[ structure:
    [mapFile] = { -- "_terrain1" etc will be stripped from attempts to fetch this
        [coord] = {
            label=[string], -- label: text that'll be the label, optional
            item=[id], -- itemid
            quest=[id], -- will be checked, for whether character already has it
            achievement=[id], -- will be shown in the tooltip
            junk=[bool], -- doesn't count for achievement
            npc=[id], -- related npc id, used to display names in tooltip
            note=[string], -- some text which might be helpful
        },
    },
    --]]
    ["Suramar"] = {
        [30801090] = { quest=43808, label="Moon Guard Stronghold", },
        [21502990] = { quest=42230, label="Falanaar", },
        [42203540] = { quest=43809, label="Tel'anor", },
        [36204710] = { quest=40956, label="Ruins of Elune'eth", },
        [43406070] = { quest=43813, label="Sanctum of Order", },
        [43607910] = { quest=43811, label="Lunastre Estate", },
        [39107630] = { quest=41575, label="Felsoul Hold", },
        [47508200] = { quest=42487, label="Waning Crescent", },
        [64006040] = { quest=44084, label="Twilight Vineyards", },
        -- entrances
        [22903580] = { quest=42230, entrance=true, label="Falanaar (entrance)" },
        [35808210] = { quest=41575, entrance=true, label="Felsoul Hold (entrance)" },
        [27802230] = { quest=43808, entrance=true, label="Moon Guard (entrance)" },
        [42606170] = { quest=43813, entrance=true, label="Sanctum of Order (entrance)" },
    },
}
